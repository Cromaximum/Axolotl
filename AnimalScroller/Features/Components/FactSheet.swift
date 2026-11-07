import SwiftUI

/// The intro board's short fact sheet: "Lives in", "Eats", size and weight rows, each value
/// shown exactly as its source gives it, with the sources named underneath (D-011).
struct FactSheet: View {
    let profile: SpeciesProfile
    /// Fewer rows and lines at accessibility text sizes so the board stays below the animal.
    var maxRows = 4
    var lineLimit = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(Array(profile.rows.prefix(maxRows)), id: \.self) { row in
                    GridRow {
                        Text(row.kind.label.uppercased())
                            .font(Theme.label(11)).tracking(1)
                            .foregroundStyle(Theme.wood)
                        Text(row.text)
                            .font(Theme.body(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(lineLimit)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text(sourceLine)
                .font(Theme.body(10))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.parchment, in: RoundedRectangle(cornerRadius: 10))
    }

    private var sourceLine: String {
        var sources: [String] = []
        if profile.usesWikidata { sources.append("Wikidata (CC0)") }
        if profile.rows.contains(where: { $0.source == .wikipedia }) { sources.append("Wikipedia (CC BY-SA)") }
        return "Sources: " + sources.joined(separator: " · ")
    }
}
