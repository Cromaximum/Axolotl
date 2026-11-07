import Foundation

/// Pure rules for moving around the feed and for the small moments on top of it:
/// where "Next animal" jumps to, and which number a first meeting gets.
enum FeedNavigation {
    /// The first card of the next species set after `cardID`: the intro of the next animal.
    /// Nil when the card isn't in the feed or the next species hasn't loaded yet.
    /// Sets are told apart by `sequence`, so the same species shown again later still counts as
    /// a new set.
    static func nextSetStart(after cardID: String, in cards: [FeedCard]) -> FeedCard? {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let current = cards[index].sequence
        return cards[(index + 1)...].first { $0.sequence != current }
    }

    /// The badge number for a species met for the first time ("No. 143 met"), or nil if the user
    /// had already met it before this feed showed it. `known` holds the numbers handed out in
    /// this session, so the badge stays put after the meeting is recorded.
    static func firstMeetingNumber(for id: String, known: [String: Int],
                                   alreadyMet: Bool, metCount: Int) -> Int? {
        if let number = known[id] { return number }
        return alreadyMet ? nil : metCount + 1
    }
}
