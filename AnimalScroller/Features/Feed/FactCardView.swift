import SwiftUI

/// Photo on top so the face stays in view; one number or one sentence on the board below (D-010).
struct FactCardView: View {
    let card: FactCard
    let context: CardContext
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let image = card.image {
                        FullBleedImage(image: image, wideCenter: 0.5)
                        CreditChip(attribution: image.attribution)
                            .padding(CardInsets.side)
                    } else {
                        Theme.boardGreen
                    }
                }
                .frame(height: geo.size.height * 0.52)
                .clipped()

                board
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Theme.forest)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.wood).frame(height: 5) }
            }
        }
        .background(Theme.forest)
        .overlay(alignment: .top) {
            HStack(alignment: .top) {
                NamePill(name: card.entry.species.commonName, position: context.position, count: context.count)
                Spacer()
                LikeButton(isLiked: context.isLiked, action: context.onLike)
            }
            .padding(.horizontal, CardInsets.side)
            .padding(.top, CardInsets.top)
        }
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(heading)
                .font(Theme.label(11)).tracking(1.2)
                .foregroundStyle(Theme.amber)
                .accessibilityLabel(spokenHeading)
                .accessibilityAddTraits(.isHeader)
            if let number = FactFormatting.leadingNumber(in: card.text) {
                Text(number)
                    .font(Theme.heading(64))
                    .foregroundStyle(Theme.amber)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityHidden(true) // the sentence below says it
            }
            Text(card.text)
                .font(Theme.heading(22))
                .foregroundStyle(Theme.parchment)
                .minimumScaleFactor(0.7)
                // The board sits below the photo; at huge sizes the fact truncates rather than
                // pushing into it. The full text is in the detail sheet.
                .lineLimit(typeSize.isAccessibilitySize ? 6 : nil)
            Spacer(minLength: 8)
            Button(action: context.onInfo) {
                Text("\(card.entry.species.scientificName) · Source: Wikipedia")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.mist)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens species details")
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, CardInsets.bottom + 8)
    }

    private var spokenHeading: String {
        ["Did you know?", card.topic].compactMap { $0 }.joined(separator: ", ")
    }

    private var heading: String {
        var h = "DID YOU KNOW?"
        if let topic = card.topic { h += " · \(topic.uppercased())" }
        return h
    }
}

enum FactFormatting {
    /// The first stand-out number in a fact ("12", "1,000", "3.5"), to show large. Ignores years
    /// written as plain four-digit numbers between 1000 and 2100, which read badly on their own.
    static func leadingNumber(in text: String) -> String? {
        guard let range = text.range(of: #"\d[\d,]*(\.\d+)?"#, options: .regularExpression) else { return nil }
        let token = String(text[range])
        if token.count == 4, let year = Int(token), (1000...2100).contains(year) { return nil }
        return token
    }
}
