import SwiftUI

/// Photo on top so the face stays in view; the sentence on the board below, with its key number
/// highlighted where it sits so it is never read without its words (D-010).
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
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .top) {
                    NamePill(name: card.entry.species.commonName, position: context.position, count: context.count)
                    Spacer()
                    LikeButton(isLiked: context.isLiked, action: context.onLike)
                }
                if let onSkip = context.onSkip {
                    NextAnimalChip(name: context.nextSpeciesName, action: onSkip)
                }
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
            Text(FactFormatting.highlighted(card.text, color: Theme.amber))
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
    private static let numberWithWord = try! NSRegularExpression(
        pattern: #"\d[\d,]*(?:\.\d+)?(?:\s?(?:%|°[CF]?|[A-Za-zµ]+(?:/[A-Za-z]+)?))?"#
    )

    /// The first stand-out number in a fact plus the word right after it ("40 metres",
    /// "1,200 kg", "12 kinds"), so the highlight always carries its meaning. Skips years written
    /// as plain four-digit numbers between 1000 and 2100.
    static func highlightRange(in text: String) -> Range<String.Index>? {
        let all = NSRange(text.startIndex..., in: text)
        for match in numberWithWord.matches(in: text, range: all) {
            guard let range = Range(match.range, in: text) else { continue }
            let digits = text[range].prefix { $0.isNumber }
            if digits.count == 4, text[range].count == 4 || text[range].dropFirst(4).first == " ",
               let year = Int(digits), (1000...2100).contains(year) { continue }
            return range
        }
        return nil
    }

    /// The fact, verbatim, with the highlight range in bold amber (D-011: styling only).
    static func highlighted(_ text: String, color: Color) -> AttributedString {
        var out = AttributedString(text)
        guard let range = highlightRange(in: text),
              let lower = AttributedString.Index(range.lowerBound, within: out),
              let upper = AttributedString.Index(range.upperBound, within: out) else { return out }
        out[lower..<upper].foregroundColor = color
        out[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        return out
    }
}
