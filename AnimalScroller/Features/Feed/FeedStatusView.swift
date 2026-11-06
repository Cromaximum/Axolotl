import SwiftUI

/// The page at the end of the feed when there is no card to show yet: a board placeholder while
/// the next species loads, or a friendly message with Try again.
///
/// `message` is `FeedViewModel.emptyMessage` for now and is shown as is (never matched on).
/// When W1's `FeedNotice` lands this takes the notice and picks the empty or offline layout.
struct FeedStatusView: View {
    let isLoading: Bool
    let message: String?
    let onRetry: () -> Void

    var body: some View {
        if let message, !isLoading {
            notice(message)
        } else {
            BoardPlaceholder()
        }
    }

    private func notice(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "binoculars")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .accessibilityHidden(true)
            BoardPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NO ANIMALS RIGHT NOW")
                        .font(Theme.label(12)).tracking(1.2)
                        .foregroundStyle(Theme.amber)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(Theme.body(17, weight: .semibold))
                        .foregroundStyle(Theme.parchment)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.forest)
    }
}
