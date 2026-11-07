import Foundation

/// What a card needs to know about its place in the feed and the actions it can trigger.
struct CardContext {
    /// 1-based position of this card in its species set, and the set's size.
    let position: Int
    let count: Int
    let isSaved: Bool
    let isLiked: Bool
    let onSave: () -> Void
    /// Heart button: likes or unlikes the species. Likes steer the tailored picks.
    let onLike: () -> Void
    let onInfo: () -> Void
    /// Common name of the next species once its cards have loaded, for the "Next" chip.
    var nextSpeciesName: String? = nil
    /// Jumps to the next species' intro. Nil until the next species has loaded.
    var onSkip: (() -> Void)? = nil
    /// "No. N met": set on the intro when this is the first time the user meets the species.
    var firstMeetingNumber: Int? = nil
    /// First run only: the intro shows "Swipe up for more" until the first swipe.
    var showsSwipeHint = false
}
