import SwiftUI

/// An edge-to-edge photo (D-010).
/// Tall photos fill the screen and are anchored to the top so the animal's head stays in the
/// upper part of the frame. Wide photos are shown whole across the upper part of the screen,
/// over a blurred copy of themselves, instead of being cropped to a sliver.
/// Images come decoded and cached from the injected `ImageLoading` (W1), not `AsyncImage`.
@MainActor
struct FullBleedImage: View {
    let image: LicensedImage
    /// Fraction of the height the wide photo is centred in. 0.4 keeps it above a bottom board.
    var wideCenter: CGFloat = 0.4

    @Environment(\.imageLoader) private var loader
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = RemoteImageModel()

    var body: some View {
        let phase = model.displayPhase(for: image.url, loader: loader)
        GeometryReader { geo in
            Group {
                switch phase {
                case .loaded(let cgImage):
                    picture(Image(decorative: cgImage, scale: 1), in: geo.size)
                        .transition(.opacity)
                case .failed:
                    Theme.boardGreen.overlay(Image(systemName: "photo").font(.largeTitle)
                        .foregroundStyle(Theme.mist))
                case .loading:
                    Theme.boardGreen.overlay(ProgressView().tint(Theme.amber))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeIn(duration: 0.2), value: phase.isLoaded)
        .task(id: image.url) { await model.load(image.url, using: loader) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(image.caption ?? "Photo")
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func picture(_ picture: Image, in size: CGSize) -> some View {
        if image.isWide {
            ZStack(alignment: .top) {
                picture.resizable().scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .blur(radius: 40).opacity(0.55).clipped()
                picture.resizable().scaledToFit()
                    .frame(width: size.width)
                    .position(x: size.width / 2, y: size.height * wideCenter)
            }
        } else {
            picture.resizable().scaledToFill()
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipped()
        }
    }
}
