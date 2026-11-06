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
    private var recent: [String] = []
    private let recentWindow = 12

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
        seenCounts[choice.id, default: 0] += 1
        recent.append(choice.id)
        if recent.count > recentWindow { recent.removeFirst() }
        return choice
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

    private func weightedPick<R: RandomNumberGenerator>(from pool: [SpeciesEntry], tailored: Bool, using rng: inout R) -> SpeciesEntry {
        let recentSet = Set(recent)
        let weights = pool.map { entry -> Double in
            if recentSet.contains(entry.id) && pool.count > recentSet.count { return 0 }
            // Strongly favour species the user has never seen: the goal is meeting new animals.
            let novelty = 1.0 / Double(1 + 3 * seenCounts[entry.id, default: 0])
            let interest = tailored ? entry.lineageIDs.reduce(0) { $0 + affinity[$1, default: 0] } : 0
            return novelty * (1 + min(interest, 4))
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return pool.randomElement(using: &rng)! }
        var roll = Double.random(in: 0..<total, using: &rng)
        for (entry, w) in zip(pool, weights) {
            roll -= w
            if roll < 0 { return entry }
        }
        return pool.last!
    }
}
