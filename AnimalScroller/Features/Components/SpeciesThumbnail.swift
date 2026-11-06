import SwiftUI

/// A species' hero photo cropped to fill a small tile. Shimmers while loading, board green when
/// there's no usable image. Decorative: the tile around it carries the accessibility label and
/// the credit is in the detail sheet the tile opens.
struct SpeciesThumbnail: View {
    let species: Species
    var allowArtwork = false

    @Environment(\.speciesContentProvider) private var provider
    @Environment(\.imageLoader) private var images
    @Environment(\.displayScale) private var scale
    @State private var model = SpeciesThumbnailModel()

    var body: some View {
        GeometryReader { geo in
            Group {
                switch model.phase {
                case .loaded(let cgImage, _):
                    Image(decorative: cgImage, scale: 1).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                        .clipped()
                case .unavailable:
                    Theme.boardGreen
                case .loading:
                    ShimmerFill()
                }
            }
            .task(id: "\(species.id)|\(allowArtwork)|\(Int(geo.size.width))x\(Int(geo.size.height))") {
                guard geo.size.width > 0, geo.size.height > 0 else { return }
                await model.load(species, allowArtwork: allowArtwork,
                                 maxPixelSize: ImageSizing.maxPixelSize(for: geo.size, scale: scale),
                                 provider: provider, images: images)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
