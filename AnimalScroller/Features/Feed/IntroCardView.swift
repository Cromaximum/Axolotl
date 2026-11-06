import SwiftUI

/// The opening card of each species set, styled like a zoo enclosure sign.
struct IntroCardView: View {
    let card: IntroCard
    private var species: Species { card.entry.species }

    var body: some View {
        ZStack {
            Theme.forest
            VStack(spacing: 0) {
                    heroImage
                    BoardPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            lineageLine
                            Text(species.commonName)
                                .font(Theme.heading(40))
                                .foregroundStyle(Theme.parchment)
                                .minimumScaleFactor(0.6)
                            Text(species.scientificName)
                                .font(Theme.body(20).italic())
                                .foregroundStyle(Theme.parchment.opacity(0.85))
                            if let tagline = card.tagline {
                                Text(tagline.capitalizedFirst)
                                    .font(Theme.label(14))
                                    .foregroundStyle(Theme.amber)
                            }
                            Text(card.lead)
                                .font(Theme.body(17))
                                .foregroundStyle(Theme.parchment)
                                .lineLimit(5)
                            if let fact = card.didYouKnow {
                                DidYouKnowBox(text: fact)
                            }
                            ConservationScale(status: species.status)
                            HStack {
                                AttributionBadge(attribution: card.textAttribution, label: "Text")
                                if let hero = card.hero {
                                    AttributionBadge(attribution: hero.attribution, label: "Photo")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, -40)   // sign overlaps the bottom of the photo
                    Spacer(minLength: 24)
            }
        }
    }

    @ViewBuilder private var heroImage: some View {
        if let hero = card.hero {
            AsyncImage(url: hero.url, transaction: .init(animation: .easeIn)) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Theme.boardGreen.overlay(ProgressView().tint(Theme.amber))
                }
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if hero.isArtwork { ArtworkTag().padding(.top, 70).padding(.trailing, 16) }
            }
        } else {
            Color.clear.frame(height: 120)
        }
    }

    private var lineageLine: some View {
        let names = [card.entry.className, card.entry.orderName, card.entry.familyName].compactMap { $0 }
        return Text(names.joined(separator: " › ").uppercased())
            .font(Theme.label(11))
            .tracking(1.2)
            .foregroundStyle(Theme.parchment.opacity(0.7))
    }
}

struct DidYouKnowBox: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Did you know?", systemImage: "lightbulb.fill")
                .font(Theme.label(13))
                .foregroundStyle(Theme.wood)
            Text(text)
                .font(Theme.body(16))
                .foregroundStyle(Theme.ink)
                .lineLimit(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.parchment, in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.amber).frame(width: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

/// The IUCN Red List bar found on most zoo signs: LC NT VU EN CR EW EX.
struct ConservationScale: View {
    let status: ConservationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONSERVATION STATUS: \(status.label.uppercased())")
                .font(Theme.label(11))
                .tracking(1)
                .foregroundStyle(Theme.parchment.opacity(0.8))
            HStack(spacing: 4) {
                ForEach(ConservationStatus.scale, id: \.self) { step in
                    Text(step.rawValue)
                        .font(Theme.label(12))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .foregroundStyle(step == status ? Theme.ink : Theme.parchment.opacity(0.6))
                        .background(step == status ? Theme.amber : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Conservation status: \(status.label)")
    }
}

struct ArtworkTag: View {
    var body: some View {
        Text("ARTIST RECONSTRUCTION")
            .font(Theme.label(10))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.amber, in: Capsule())
            .foregroundStyle(Theme.ink)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
