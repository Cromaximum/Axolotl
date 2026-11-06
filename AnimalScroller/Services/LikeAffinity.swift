import Foundation

/// Turns liked species into interest per taxon id, which `SpeciesPicker` adds to dwell-time
/// affinity for tailored picks. Pure, so it is unit-tested (`LikesTests`).
///
/// A like credits the species' close relatives most (same genus, then family) and its wider
/// branches a little, so the feed shows more animals *like* the one you liked rather than the
/// same animal again. Discovery picks ignore likes, so the ~30% surprise share (D-001) stays.
enum LikeAffinity {
    struct Step: Codable, Hashable, Sendable {
        let id: String
        let rank: Taxon.Rank
    }

    static func weight(for rank: Taxon.Rank) -> Double {
        switch rank {
        case .genus: 2.5
        case .family: 2.0
        case .order: 1.0
        case .class: 0.4
        case .kingdom, .phylum: 0
        }
    }

    static func affinity(lineages: [[Step]]) -> [String: Double] {
        var out: [String: Double] = [:]
        for lineage in lineages {
            for step in lineage where weight(for: step.rank) > 0 {
                out[step.id, default: 0] += weight(for: step.rank)
            }
        }
        return out
    }

    static func steps(for entry: SpeciesEntry) -> [Step] {
        entry.lineage.map { Step(id: $0.id, rank: $0.rank) }
    }
}
