import Foundation

/// A tiered goal for meeting species: every species, one branch of the tree (a phylum, class or
/// order), or one IUCN status. The name shown is the branch name from `taxonomy.json` or the
/// status label, never text written for the badge (D-011).
struct Achievement: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// Every species met.
        case overall
        /// Species met under one bundled tree node.
        case taxon(id: String, rank: Taxon.Rank)
        /// Species met with this conservation status. `.extinct` is the "extinct species" goal.
        case status(ConservationStatus)
    }

    let kind: Kind
    /// Branch name from the taxonomy, or the status label. Empty for `.overall` (the view labels it).
    let name: String
    let scientificName: String?
    /// How many bundled species the group has. Scales the tier targets.
    let groupSize: Int

    /// Which section of the board it belongs to.
    enum Group: Hashable, Sendable {
        case overall, status
        case rank(Taxon.Rank)
    }

    var group: Group {
        switch kind {
        case .overall: .overall
        case .status: .status
        case .taxon(_, let rank): .rank(rank)
        }
    }

    /// Stable across launches; the key in `achievements.v1`.
    var id: String {
        switch kind {
        case .overall: "overall"
        case .taxon(let id, _): "taxon:\(id)"
        case .status(let status): "status:\(status.rawValue)"
        }
    }
}

/// Where the user stands on one achievement.
struct AchievementProgress: Identifiable, Hashable, Sendable {
    let achievement: Achievement
    /// Species met in the group, bundled and live.
    let metCount: Int
    /// Targets already reached, smallest first. Its count is the tier.
    let reachedTargets: [Int]
    /// The next target to aim for. Tiers never run out.
    let nextTarget: Int

    var id: String { achievement.id }
    var tier: Int { reachedTargets.count }
    var previousTarget: Int { reachedTargets.last ?? 0 }

    /// 0...1 progress from the last reached target to the next one.
    var fractionToNext: Double {
        let span = nextTarget - previousTarget
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(metCount - previousTarget) / Double(span)))
    }
}
