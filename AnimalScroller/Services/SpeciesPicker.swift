import Foundation

/// Chooses the next species for the feed: mostly tailored to the branches the
/// user picked and the ones they linger on, with a share of random discovery
/// picks from elsewhere in the tree. Always returns a single specific species.
struct SpeciesPicker {
    /// Share of picks drawn from outside the user's selection (the "surprise" picks).
    var discoveryShare: Double = 0.3

    private(set) var seenCounts: [String: Int] = [:]
    /// Interest per taxon id, built from how long the user stays on each species.
    private(set) var affinity: [String: Double] = [:]
    /// Interest per taxon id from the species the user liked (see `LikeAffinity`). Persisted by
    /// `LikesStore` and handed in before each pick, so likes steer the feed across launches.
    var likeAffinity: [String: Double] = [:]
    /// Live-catalogue branches that recently came back empty, so we try them less.
    private(set) var branchMisses: [String: Int] = [:]
    private var recent: [String] = []
    private let recentWindow = 12
    /// Lineage ids of the species shown last, so the next pick can avoid its family and order.
    private var lastFamilyID: String?
    private var lastOrderID: String?

    init(discoveryShare: Double = 0.3) {
        self.discoveryShare = discoveryShare
    }

    /// - Parameters:
    ///   - tailored: species inside the user's selected branches (after extinct filtering).
    ///   - everything: every species allowed by the extinct filter, used for discovery picks.
    mutating func next<R: RandomNumberGenerator>(
        tailored: [SpeciesEntry],
        everything: [SpeciesEntry],
        using rng: inout R
    ) -> SpeciesEntry? {
        let tailoredIDs = Set(tailored.map(\.id))
        let outside = everything.filter { !tailoredIDs.contains($0.id) }

        let useDiscovery = !outside.isEmpty && (tailored.isEmpty || Double.random(in: 0..<1, using: &rng) < discoveryShare)
        let pool = useDiscovery ? outside : tailored
        guard !pool.isEmpty else { return nil }

        let choice = weightedPick(from: pool, tailored: !useDiscovery, using: &rng)
        markShown(choice)
        return choice
    }

    /// Records that a species is going on screen. `next` does this itself; call it for live picks.
    mutating func markShown(_ entry: SpeciesEntry) {
        seenCounts[entry.id, default: 0] += 1
        recent.append(entry.id)
        if recent.count > recentWindow { recent.removeFirst() }
        lastFamilyID = Self.id(of: .family, in: entry)
        lastOrderID = Self.id(of: .order, in: entry)
    }

    /// Has the user been shown every species in this pool at least once?
    func hasSeenAll(_ pool: [SpeciesEntry]) -> Bool {
        !pool.isEmpty && pool.allSatisfy { seenCounts[$0.id, default: 0] > 0 }
    }

    // MARK: Live catalogue

    /// Chooses which branch of the tree to search the live catalogue under. Tailored picks favour
    /// branches the user liked or lingered on; discovery picks are uniform, as in `next`.
    mutating func pickBranch<R: RandomNumberGenerator>(
        inside: [Taxon], outside: [Taxon], using rng: inout R
    ) -> (branch: Taxon, isDiscovery: Bool)? {
        let useDiscovery = !outside.isEmpty && (inside.isEmpty || Double.random(in: 0..<1, using: &rng) < discoveryShare)
        let pool = useDiscovery ? outside : inside
        guard !pool.isEmpty else { return nil }
        let weights = pool.map { b -> Double in
            let penalty = 1.0 / Double(1 + branchMisses[b.id, default: 0])
            let interest = useDiscovery ? 0 : affinity[b.id, default: 0] + likeAffinity[b.id, default: 0]
            return penalty * (1 + min(interest, Self.interestCap))
        }
        return (Self.roll(pool, weights: weights, using: &rng), useDiscovery)
    }

    mutating func recordBranchMiss(_ branch: Taxon) { branchMisses[branch.id, default: 0] += 1 }

    /// Chooses among live candidates: unseen first, then interest, then how well known the species is.
    mutating func choose<R: RandomNumberGenerator>(
        from candidates: [LiveCandidate], tailored: Bool, using rng: inout R
    ) -> LiveCandidate? {
        let recentSet = Set(recent)
        let fresh = candidates.filter { !recentSet.contains($0.entry.id) }
        guard !fresh.isEmpty else { return nil }
        let base = fresh.map { c in
            weight(for: c.entry, tailored: tailored) * LiveCatalogRules.popularity(articleLength: c.articleLength)
        }
        let weights = withVariety(base, entries: fresh.map(\.entry), tailored: tailored)
        return Self.roll(fresh, weights: weights, using: &rng)
    }

    mutating func next(tailored: [SpeciesEntry], everything: [SpeciesEntry]) -> SpeciesEntry? {
        var rng = SystemRandomNumberGenerator()
        return next(tailored: tailored, everything: everything, using: &rng)
    }

    /// Records engagement. `seconds` is time spent on the species' cards.
    mutating func recordDwell(on entry: SpeciesEntry, seconds: TimeInterval) {
        let signal = min(seconds, 60) / 60  // 0...1
        // Credit the family most, the order a bit, the class a little.
        for taxon in entry.lineage {
            let weight: Double = switch taxon.rank {
            case .family, .genus: 1.0
            case .order: 0.5
            case .class: 0.2
            default: 0.0
            }
            affinity[taxon.id, default: 0] += signal * weight
        }
    }

    /// Caps how far dwell time and likes can tilt a pick, so the feed never collapses onto one family.
    static let interestCap = 6.0

    /// Novelty × interest. Interest (dwell + likes) only applies to tailored picks.
    func weight(for entry: SpeciesEntry, tailored: Bool) -> Double {
        // Strongly favour species the user has never seen: the goal is meeting new animals.
        let novelty = 1.0 / Double(1 + 3 * seenCounts[entry.id, default: 0])
        let interest = tailored
            ? entry.lineageIDs.reduce(0) { $0 + affinity[$1, default: 0] + likeAffinity[$1, default: 0] }
            : 0
        return novelty * (1 + min(interest, Self.interestCap))
    }

    private func weightedPick<R: RandomNumberGenerator>(from pool: [SpeciesEntry], tailored: Bool, using rng: inout R) -> SpeciesEntry {
        let recentSet = Set(recent)
        // Discovery spreads across the tree: each class gets a share that grows only with the
        // square root of its size, so a small class isn't drowned out by one with many species.
        let classSizes: [String: Int] = tailored ? [:] : Dictionary(pool.map { (Self.id(of: .class, in: $0) ?? "", 1) }, uniquingKeysWith: +)
        let base = pool.map { entry -> Double in
            if recentSet.contains(entry.id) && pool.count > recentSet.count { return 0 }
            let spread = tailored ? 1 : 1 / Double(classSizes[Self.id(of: .class, in: entry) ?? "", default: 1]).squareRoot()
            return weight(for: entry, tailored: tailored) * spread
        }
        return Self.roll(pool, weights: withVariety(base, entries: pool, tailored: tailored), using: &rng)
    }

    /// Penalty for the same order as the last species.
    static let sameOrderFactor = 0.5

    /// No two species from the same family back to back, and fewer from the same order. Falls
    /// back to the plain weights only when every candidate shares the last family.
    ///
    /// Likes win over variety (D-013): on tailored picks a family or order the user liked is
    /// exempt, so liking a cat can still bring two cats in a row. Discovery picks ignore likes,
    /// so the rule always applies there.
    func withVariety(_ weights: [Double], entries: [SpeciesEntry], tailored: Bool) -> [Double] {
        func isLiked(_ id: String?) -> Bool {
            guard tailored, let id else { return false }
            return likeAffinity[id, default: 0] > 0
        }
        let varied = zip(weights, entries).map { w, entry -> Double in
            let family = Self.id(of: .family, in: entry)
            let order = Self.id(of: .order, in: entry)
            if let lastFamilyID, family == lastFamilyID, !isLiked(family) { return 0 }
            if let lastOrderID, order == lastOrderID, !isLiked(order) { return w * Self.sameOrderFactor }
            return w
        }
        return varied.contains { $0 > 0 } ? varied : weights
    }

    /// Deepest node of this rank: Wikidata nests some classes (birds, Aves, sit inside Reptilia),
    /// and the narrower one is the meaningful group for variety.
    private static func id(of rank: Taxon.Rank, in entry: SpeciesEntry) -> String? {
        entry.lineage.last { $0.rank == rank }?.id
    }

    private static func roll<T, R: RandomNumberGenerator>(_ pool: [T], weights: [Double], using rng: inout R) -> T {
        let total = weights.reduce(0, +)
        guard total > 0 else { return pool.randomElement(using: &rng)! }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (item, w) in zip(pool, weights) {
            roll -= w
            if roll < 0 { return item }
        }
        return pool.last!
    }
}
