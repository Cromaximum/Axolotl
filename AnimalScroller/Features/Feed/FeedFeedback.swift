import SwiftUI

/// The last like or save in the feed, driving its haptic and (for saves) a short toast.
/// Each value gets its own id, so liking twice in a row still triggers feedback twice.
struct FeedFeedback: Equatable {
    enum Kind { case liked, unliked, saved, unsaved }

    let kind: Kind
    let id = UUID()

    /// Agreed in the PR #13 design review: light impact on like, success on save,
    /// selection on unsave (and unlike). No haptic per page.
    var haptic: SensoryFeedback {
        switch kind {
        case .liked: .impact(weight: .light)
        case .saved: .success
        case .unliked, .unsaved: .selection
        }
    }

    /// Toast text. Likes already show on the heart, so they get no toast.
    var message: String? {
        switch kind {
        case .saved: "Saved to Met"
        case .unsaved: "Removed from Met"
        case .liked, .unliked: nil
        }
    }

    var icon: String { kind == .saved ? "bookmark.fill" : "bookmark.slash" }
}

/// A small parchment capsule near the bottom of the feed, like a tag clipped to the board.
struct FeedbackToast: View {
    let message: String
    let systemImage: String

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(Theme.label(14))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.parchment, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.wood, lineWidth: 2))
            .foregroundStyle(Theme.ink)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true) // announced when shown instead
    }
}
