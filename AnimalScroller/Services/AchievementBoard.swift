import Foundation

/// Builds the achievement board from the species the user has met. Pure logic, no I/O.
///
/// Achievements come from the bundled tree, so their names are taxonomy names (D-011):
/// one for every species, one per phylum, class and order with at least `minimumGroupSize`
/// bundled species, and one per IUCN status that some bundled species has (Not Evaluated and
/// Data Deficient are left out). A met species counts towards every branch in its lineage, and
/// live-catalogue species count too, through the bundled branches above them.
enum AchievementBoard {
    static let ranks: [Taxon.Rank] = [.phylum, .class, .order]
    static let minimumGroupSize = 3
    static let statuses: [ConservationStatus] = [
        .extinct, .extinctInWild, .criticallyEndangered, .endangered, .vulnerable, .nearThreatened, .leastConcern,
    ]

    /// Every achievement the bundled tree offers, overall first, then statuses, then ranks in tree order.
    static func achievements(index: TaxonomyIndex) -> [Achievement] {
        var out = [Achievement(kind: .overall, name: "", scientificName: nil, groupSize: index.totalSpecies)]
        let statusCounts = Dictionary(grouping: index.allEntries, by: \.species.status).mapValues(\.count)
        for status in statuses {
            let n = statusCounts[status] ?? 0
            if n > 0 { out.append(Achievement(kind: .status(status), name: status.label, scientificName: nil, groupSize: n)) }
        }
        for rank in ranks {
            for taxon in index.taxa(rank: rank) {
                let n = index.speciesCount(taxon.id)
                guard n >= minimumGroupSize else { continue }
                out.append(Achievement(kind: .taxon(id: taxon.id, rank: rank), name: taxon.name,
                                       scientificName: taxon.scientificName, groupSize: n))
            }
        }
        return out
    }

    /// Progress on every achievement, in the order `achievements(index:)` lists them.
    /// - Parameter met: species met, each counted once (duplicates by id are ignored).
    static func progress(met: [SpeciesEntry], index: TaxonomyIndex) -> [AchievementProgress] {
        var seen = Set<String>()
        var byTaxon: [String: Int] = [:]
        var byStatus: [ConservationStatus: Int] = [:]
        for entry in met where seen.insert(entry.id).inserted {
            for id in Set(entry.lineageIDs) { byTaxon[id, default: 0] += 1 }
            if entry.species.hasKnownStatus { byStatus[entry.species.status, default: 0] += 1 }
        }
        return achievements(index: index).map { a in
            let count: Int
            switch a.kind {
            case .overall: count = seen.count
            case .taxon(let id, _): count = byTaxon[id] ?? 0
            case .status(let status): count = byStatus[status] ?? 0
            }
            return AchievementTiers.progress(for: a, metCount: count)
        }
    }

    /// Groups a board into sections in the order they first appear. Statuses keep the scale
    /// order; in other sections achievements with more species met come first, ties in tree order.
    static func sections(_ board: [AchievementProgress]) -> [(Achievement.Group, [AchievementProgress])] {
        var order: [Achievement.Group] = []
        var groups: [Achievement.Group: [(offset: Int, item: AchievementProgress)]] = [:]
        for (i, item) in board.enumerated() {
            let g = item.achievement.group
            if groups[g] == nil { order.append(g) }
            groups[g, default: []].append((i, item))
        }
        return order.map { g in
            let items = groups[g] ?? []
            guard g != .status else { return (g, items.map(\.item)) }
            let sorted = items.sorted { a, b in
                if a.item.metCount != b.item.metCount { return a.item.metCount > b.item.metCount }
                return a.offset < b.offset
            }
            return (g, sorted.map(\.item))
        }
    }

    /// Achievements whose tier went up between two boards, biggest new target first.
    static func newlyReached(from old: [AchievementProgress], to new: [AchievementProgress]) -> [AchievementProgress] {
        let before = Dictionary(old.map { ($0.id, $0.tier) }) { a, _ in a }
        return new
            .filter { $0.tier > (before[$0.id] ?? 0) }
            .sorted { $0.previousTarget > $1.previousTarget }
    }

    /// Tiers reached that the user hasn't seen yet, given the highest tier seen per achievement id.
    static func unseenTiers(_ board: [AchievementProgress], seen: [String: Int]) -> Int {
        board.reduce(0) { $0 + max(0, $1.tier - (seen[$1.id] ?? 0)) }
    }

    /// Ids whose tier is above what the user has seen.
    static func unseenIDs(_ board: [AchievementProgress], seen: [String: Int]) -> Set<String> {
        Set(board.filter { $0.tier > (seen[$0.id] ?? 0) }.map(\.id))
    }
}
