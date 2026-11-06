import SwiftUI

/// The page at the end of the feed when there is no card to show yet: a board placeholder while
/// the next species loads, or a board saying why nothing can be shown.
struct FeedStatusView: View {
    let isLoading: Bool
    let notice: FeedNotice?
    let onRetry: () -> Void

    var body: some View {
        if let notice, !isLoading {
            page(for: notice)
        } else {
            BoardPlaceholder()
        }
    }

    private func page(for notice: FeedNotice) -> some View {
        VStack(spacing: 18) {
            Image(systemName: notice == .offline ? "wifi.slash" : "binoculars")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .accessibilityHidden(true)
            BoardPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text(notice == .offline ? "CAN'T REACH WIKIPEDIA" : "NO ANIMALS ON THESE BRANCHES")
                        .font(Theme.label(12)).tracking(1.2)
                        .foregroundStyle(Theme.amber)
                        .accessibilityAddTraits(.isHeader)
                    Text(message(for: notice))
                        .font(Theme.body(17, weight: .semibold))
                        .foregroundStyle(Theme.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Retrying can't help when the filters match nothing; the Tree tab can.
            if notice == .offline {
                Button(action: onRetry) {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .font(Theme.label(17))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Theme.amber, in: Capsule())
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.forest)
    }

    private func message(for notice: FeedNotice) -> String {
        switch notice {
        case .noMatches: "No species match these filters yet. Pick another branch on the Tree tab, or turn on extinct species."
        case .offline: "Check your connection, then try again. You can also pull down to retry."
        }
    }
}
