import SwiftUI

/// An edge-to-edge photo (D-010).
/// Tall photos fill the screen and are anchored to the top so the animal's head stays in the
/// upper part of the frame. Wide photos are shown whole across the upper part of the screen,
/// over a blurred copy of themselves, instead of being cropped to a sliver.
struct FullBleedImage: View {
    let image: LicensedImage
    /// Fraction of the height the wide photo is centred in. 0.4 keeps it above a bottom board.
    var wideCenter: CGFloat = 0.4

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: image.url, transaction: .init(animation: .easeIn(duration: 0.2))) { phase in
                switch phase {
                case .success(let picture):
                    if image.isWide {
                        ZStack(alignment: .top) {
                            picture.resizable().scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .blur(radius: 40).opacity(0.55).clipped()
                            picture.resizable().scaledToFit()
                                .frame(width: geo.size.width)
                                .position(x: geo.size.width / 2, y: geo.size.height * wideCenter)
                        }
                    } else {
                        picture.resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                    }
                case .failure:
                    Theme.boardGreen.overlay(Image(systemName: "photo").font(.largeTitle)
                        .foregroundStyle(Theme.mist))
                default:
                    Theme.boardGreen.overlay(ProgressView().tint(Theme.amber))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .accessibilityLabel(image.caption ?? "Photo")
    }
}
