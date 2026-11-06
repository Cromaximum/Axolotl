import Foundation

/// Where the next species comes from: the bundled hand-picked list or the live catalogue (D-012).
enum FeedSource: Equatable, Sendable {
    case bundled, live
}

/// Pure plan for one load: which sources to try, in order, on each attempt. The view model only
/// follows the plan. Tested in `FeedSourcePlannerTests`.
enum FeedSourcePlanner {
    /// Share of attempts that try the live catalogue while bundled species in scope are unseen.
    static let liveShare = 0.5
    /// Attempts per load before giving up (a species can fail for want of an article or photos).
    static let attempts = 6
    /// Once every bundled species in scope has been met, the first attempts are live-only so the
    /// feed doesn't fall back to repeats while the catalogue still has new species.
    static let liveOnlyAttempts = 4

    /// - Parameters:
    ///   - attempt: 0-based attempt within this load.
    ///   - roll: a uniform random number in 0..<1, passed in so the plan is deterministic in tests.
    static func sources(attempt: Int, liveEnabled: Bool, bundledExhausted: Bool, roll: Double) -> [FeedSource] {
        let lastAttempt = attempt >= attempts - 1
        guard liveEnabled, !lastAttempt, bundledExhausted || roll < liveShare else { return [.bundled] }
        if bundledExhausted && attempt < liveOnlyAttempts { return [.live] }
        return [.live, .bundled]
    }
}
