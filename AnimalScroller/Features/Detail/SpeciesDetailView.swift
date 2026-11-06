import SwiftUI

/// Opened from ⓘ (or by tapping an intro board or a collection tile): everything about one
/// species, plus every source and credit.
struct SpeciesDetailView: View {
    let entry: SpeciesEntry
    var provider: SpeciesContentProvider = WikipediaContentProvider.shared
    @Environment(PreferencesStore.self) private var prefs
    @State private var content: SpeciesContent?
    @State private var failed = false

    private var species: Species { entry.species }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(species.commonName).font(Theme.heading(32)).foregroundStyle(Theme.parchment)
                        Text(species.scientificName).font(Theme.body(15).italic()).foregroundStyle(Theme.amber)
                    }
                    Text(entry.lineage.compactMap { $0.scientificName ?? $0.name }.joined(separator: " › "))
                        .font(Theme.body(12)).foregroundStyle(Theme.mist)

                    quickFacts

                    if let content {
                        if let first = content.facts.first { DidYouKnowBox(text: first.text) }
                        if !content.lead.isEmpty {
                            Text(content.lead).font(Theme.body(16)).foregroundStyle(Theme.parchment)
                        }
                        moreFacts(content)
                        credits(content)
                    } else if failed {
                        Text("Couldn't load details. Check your connection.")
                            .font(Theme.body(14)).foregroundStyle(Theme.mist)
                    } else {
                        ProgressView().tint(Theme.amber).frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.forest)
        .overlay(alignment: .top) { Rectangle().fill(Theme.wood).frame(height: 4) }
        .task {
            do { content = try await provider.content(for: species) } catch { failed = true }
        }
    }

    private var hero: LicensedImage? {
        guard let content else { return nil }
        let artworkOK = prefs.showArtwork && species.isExtinct
        let usable = content.images.filter { artworkOK || !$0.isArtwork }
        return usable.first { $0.fileTitle == content.leadImageFileTitle } ?? usable.first
    }

    @ViewBuilder private var header: some View {
        ZStack(alignment: .bottomLeading) {
            if let hero {
                FullBleedImage(image: hero, wideCenter: 0.5)
                HStack {
                    if let tag = MediaTag.tag(for: hero, species: species) { MediaTagChip(tag: tag) }
                    CreditChip(attribution: hero.attribution)
                }
                .padding(14)
            } else {
                Theme.boardGreen
            }
        }
        .frame(height: 300)
        .clipped()
    }

    private var quickFacts: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            factTile("Status", species.statusLabel)
            factTile("Class", entry.className ?? "–")
            factTile("Order", entry.orderName ?? "–")
            factTile("Family", entry.familyName ?? "–")
            if let tagline = content?.tagline {
                factTile("In a phrase", tagline.capitalizedFirst)
            }
        }
    }

    private func factTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Theme.label(10)).tracking(1).foregroundStyle(Theme.mist)
            Text(value).font(Theme.body(14).weight(.semibold)).foregroundStyle(Theme.parchment)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(Theme.boardGreen, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private func moreFacts(_ content: SpeciesContent) -> some View {
        let rest = content.facts.dropFirst()
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("MORE FACTS").font(Theme.label(11)).tracking(1.2).foregroundStyle(Theme.amber)
                ForEach(Array(rest), id: \.self) { fact in
                    Text("• \(fact.text)").font(Theme.body(15)).foregroundStyle(Theme.parchment)
                }
            }
        }
    }

    private func credits(_ content: SpeciesContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCES").font(Theme.label(11)).tracking(1.2).foregroundStyle(Theme.amber)
            Link("Text: Wikipedia, \"\(content.title)\", CC BY-SA 4.0", destination: content.pageURL)
                .font(Theme.body(13))
            if let key = species.gbifKey, let url = URL(string: "https://www.gbif.org/species/\(key)") {
                Link("Name and classification: GBIF Backbone Taxonomy, CC BY 4.0", destination: url)
                    .font(Theme.body(13))
                Text("Conservation status: Wikidata (CC0), when listed. Otherwise shown as Not Evaluated.")
                    .font(Theme.body(12)).foregroundStyle(Theme.mist)
            }
            ForEach(content.images.filter { !$0.isArtwork || species.isExtinct }) { image in
                CreditChip(attribution: image.attribution)
            }
            Text("Tap any credit to open the original.")
                .font(Theme.body(12)).foregroundStyle(Theme.mist)
        }
        .tint(Theme.parchment)
    }
}
