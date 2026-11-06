import SwiftUI

/// A full-screen "Did you know?" board.
struct FactCardView: View {
    let card: FactCard

    var body: some View {
        ZStack {
            Theme.forest
            VStack(spacing: 20) {
                Spacer()
                BoardPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Label("Did you know?", systemImage: "lightbulb.fill")
                                .font(Theme.label(14))
                                .foregroundStyle(Theme.amber)
                            Spacer()
                            Text("\(card.index) of \(card.total)")
                                .font(Theme.label(12))
                                .foregroundStyle(Theme.parchment.opacity(0.6))
                        }
                        if let topic = card.topic {
                            Text(topic.uppercased())
                                .font(Theme.label(11))
                                .tracking(1.2)
                                .foregroundStyle(Theme.parchment.opacity(0.7))
                        }
                        Text(card.text)
                            .font(Theme.heading(28))
                            .foregroundStyle(Theme.parchment)
                            .minimumScaleFactor(0.7)
                        Divider().overlay(Theme.wood)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.entry.species.commonName).font(Theme.label(14))
                                Text(card.entry.species.scientificName).font(Theme.body(13).italic())
                            }
                            .foregroundStyle(Theme.parchment)
                            Spacer()
                            AttributionBadge(attribution: card.attribution, label: "Source")
                        }
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
            }
        }
    }
}
