import SwiftUI

/// A framed board panel, like the signs mounted on enclosure railings.
struct BoardPanel<Content: View>: View {
    var fill: Color = Theme.boardGreen
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.wood, lineWidth: 6)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }
}
