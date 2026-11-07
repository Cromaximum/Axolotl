import Foundation
import Observation

/// Which achievement tiers the user has already seen, so the Awards tab can badge new ones.
/// Persisted in UserDefaults under `achievements.v1` as `[achievement id: highest tier seen]`.
///
/// Progress itself is never stored: it is worked out from `MetStore` and the bundled tree each
/// time (`AchievementBoard`), so regenerated data or new tier rules never leave stale awards.
@Observable
final class AchievementsStore {
    private(set) var seenTiers: [String: Int] = [:]

    private let defaults: UserDefaults
    static let key = "achievements.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            seenTiers = decoded
        }
    }

    /// Records each id's tier as seen. Never lowers a tier already seen.
    func markSeen(_ tiers: [String: Int]) {
        var changed = false
        for (id, tier) in tiers where tier > (seenTiers[id] ?? 0) {
            seenTiers[id] = tier
            changed = true
        }
        if changed, let data = try? JSONEncoder().encode(seenTiers) { defaults.set(data, forKey: Self.key) }
    }
}
