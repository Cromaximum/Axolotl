import SwiftUI

/// A full-bleed licensed photo with its credit always visible.
struct PhotoCardView: View {
    let card: PhotoCard

    var body: some View {
        ZStack {
            Color.black
            AsyncImage(url: card.image.url, transaction: .init(animation: .easeIn)) { phase in
                switch phase {
                case .success(let image):
                    // Blurred fill behind letterboxed images, so portrait and landscape both look full-screen.
                    // The fill lives in a background so its natural (wider than the screen) size can't
                    // stretch the card; the scaledToFit image sets the layout size.
                    image.resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            image.resizable().scaledToFill().blur(radius: 30).opacity(0.5)
                        }
                        .clipped()
                case .failure:
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                default:
                    ProgressView().tint(Theme.amber)
                }
            }
        }
        .overlay(alignment: .bottomLeading) { caption }
        .overlay(alignment: .topTrailing) {
            if card.image.isArtwork { ArtworkTag().padding(.top, 70).padding(.trailing, 16) }
        }
        .clipped()
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.entry.species.commonName)
                .font(Theme.heading(24))
            if let text = card.image.caption {
                Text(text).font(Theme.body(14)).lineLimit(2).opacity(0.85)
            }
            AttributionBadge(attribution: card.image.attribution, label: "Photo")
        }
        .foregroundStyle(Theme.parchment)
        .padding(20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
    }
}
