import SwiftUI

/// The opening card of each species set: the animal full-bleed, and a zoo-board sign at the
/// bottom with its names, lineage, a "Did you know?" fact and the IUCN status bar (D-003, D-010).
struct IntroCardView: View {
    let card: IntroCard
    let context: CardContext
    @Environment(\.dynamicTypeSize) private var typeSize
    private var species: Species { card.entry.species }
    /// At accessibility text sizes the board shows less, so it stays below the animal (D-010).
    /// Everything it drops is in the detail sheet, one tap away.
    private var compact: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Theme.forest
                if let hero = card.hero {
                    FullBleedImage(image: hero, wideCenter: 0.3)
                }
                board
                    .frame(maxHeight: geo.size.height * CardInsets.maxBoardShare, alignment: .bottom)
                    .padding(.horizontal, 10)
                    .padding(.bottom, CardInsets.bottom)
                    .onTapGesture(perform: context.onInfo)
            }
        }
        .overlay(alignment: .top) { topRow }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            if let hero = card.hero, let tag = MediaTag.tag(for: hero, species: species) {
                MediaTagChip(tag: tag)
            } else {
                ProgressDashes(position: context.position, count: context.count)
                    .padding(.top, 10)
            }
            Spacer()
            if let hero = card.hero { CreditChip(attribution: hero.attribution) }
            LikeButton(isLiked: context.isLiked, action: context.onLike)
        }
        .padding(.horizontal, CardInsets.side)
        .padding(.top, CardInsets.top)
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(species.commonName)
                .font(Theme.heading(36))
                .foregroundStyle(Theme.parchment)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Text(species.scientificName)
                .font(Theme.scientific(15))
                .foregroundStyle(Theme.amber)
                .lineLimit(compact ? 1 : 2)
            Text(lineage)
                .font(Theme.body(12))
                .foregroundStyle(Theme.mist)
                .lineLimit(compact ? 1 : 2)
            if let fact = card.didYouKnow {
                DidYouKnowBox(text: fact, lineLimit: compact ? 2 : 4)
            } else if !card.lead.isEmpty {
                Text(card.lead).font(Theme.body(15)).foregroundStyle(Theme.parchment).lineLimit(compact ? 2 : 4)
            }
            if species.hasKnownStatus && !compact { ConservationScale(status: species.status) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.boardGreen, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.wood, lineWidth: 6))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens species details")
        .accessibilityAction(.default, context.onInfo)
    }

    private var lineage: String {
        [card.entry.className, card.entry.orderName, card.entry.familyName]
            .compactMap { $0 }.joined(separator: " › ")
    }
}
