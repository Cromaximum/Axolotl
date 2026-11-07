import SwiftUI

/// The animal, and almost nothing else (D-010). Name pill and credit hug the edges; extinct
/// species get a media tag and a caption on a lower-third scrim.
struct PhotoCardView: View {
    let card: PhotoCard
    let context: CardContext
    @Environment(\.dynamicTypeSize) private var typeSize
    private var species: Species { card.entry.species }
    private var tag: MediaTag? { MediaTag.tag(for: card.image, species: species) }
    /// While pinching, the chips and rail fade so the animal fills the screen.
    @State private var isZooming = false

    var body: some View {
        ZStack {
            Color.black
            FullBleedImage(image: card.image)
                .pinchToZoom(isZooming: $isZooming)
            if showsCaption { LowerThirdScrim().opacity(chromeOpacity) }
        }
        .overlay(alignment: .top) { topRow.opacity(chromeOpacity) }
        .overlay(alignment: .trailing) {
            ActionRail(isLiked: context.isLiked, isSaved: context.isSaved,
                       shareURL: card.image.attribution.sourceURL,
                       onLike: context.onLike, onSave: context.onSave, onInfo: context.onInfo)
                .padding(.trailing, 12)
                .padding(.top, 160)
                .opacity(chromeOpacity)
        }
        .overlay(alignment: .bottomLeading) { bottom.opacity(chromeOpacity) }
        .animation(Theme.Motion.fade, value: isZooming)
    }

    private var chromeOpacity: Double { isZooming ? 0 : 1 }

    /// Living species: animal only. Extinct: say what the picture is.
    private var showsCaption: Bool { tag != nil && card.image.caption != nil }

    private var topRow: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                if let tag { MediaTagChip(tag: tag) }
                else { NamePill(name: species.commonName, position: context.position, count: context.count) }
                Spacer()
                if tag != nil { CreditChip(attribution: card.image.attribution) }
            }
            if let onSkip = context.onSkip {
                NextAnimalChip(name: context.nextSpeciesName, action: onSkip)
            }
        }
        .padding(.horizontal, CardInsets.side)
        .padding(.top, CardInsets.top)
    }

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsCaption, let caption = card.image.caption {
                Text("\(species.scientificName) · \(context.position) of \(context.count)".uppercased())
                    .font(Theme.label(11)).tracking(1)
                    .foregroundStyle(Theme.amber)
                    .accessibilityLabel("\(species.scientificName), card \(context.position) of \(context.count)")
                Text(caption)
                    .font(Theme.body(20, weight: .semibold))
                    .foregroundStyle(Theme.parchment)
                    // Stays on the lower-third scrim (D-010), so it gets fewer lines at huge text sizes.
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 4)
                    .padding(.trailing, 60)
            } else {
                CreditChip(attribution: card.image.attribution)
            }
        }
        .padding(.horizontal, CardInsets.side)
        .padding(.bottom, CardInsets.bottom)
    }
}
