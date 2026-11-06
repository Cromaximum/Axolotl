import Foundation

/// What a card needs to know about its place in the feed and the actions it can trigger.
struct CardContext {
    /// 1-based position of this card in its species set, and the set's size.
    let position: Int
    let count: Int
    let isSaved: Bool
    let onSave: () -> Void
    let onInfo: () -> Void
}
