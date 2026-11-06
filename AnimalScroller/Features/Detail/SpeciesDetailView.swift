import SwiftUI

/// Opened from ⓘ (or by tapping an intro board or a collection tile): everything about one
/// species, in sections, plus every source and credit and a link to the full article.
struct SpeciesDetailView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(\.speciesContentProvider) private var provider
    @State private var model: SpeciesDetailViewModel

    init(entry: SpeciesEntry) {
        _model = State(initialValue: SpeciesDetailViewModel(entry: entry))
    }

    private var species: Species { model.species }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHeader(hero: model.hero(showArtwork: prefs.showArtwork), species: species)
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(species.commonName).font(Theme.heading(32)).foregroundStyle(Theme.parchment)
                            .accessibilityAddTraits(.isHeader)
                        Text(species.scientificName).font(Theme.body(15).italic()).foregroundStyle(Theme.amber)
                    }
                    quickFacts
                    switch model.phase {
                    case .loaded(let content):
                        loaded(content)
                    case .failed:
                        failure
                    case .loading:
                        ProgressView().tint(Theme.amber).frame(maxWidth: .infinity)
                            .accessibilityLabel("Loading details")
                    }
                    classification
                }
                .padding(20)
            }
        }
        .background(Theme.forest)
        .overlay(alignment: .top) { Rectangle().fill(Theme.wood).frame(height: 4) }
        .task { await model.load(using: provider) }
    }

    @ViewBuilder private func loaded(_ content: SpeciesContent) -> some View {
        if let fact = model.headlineFact { DidYouKnowBox(text: fact) }
        if !content.lead.isEmpty {
            DetailSection(title: "About") {
                Text(content.lead).font(Theme.body(16)).foregroundStyle(Theme.parchment)
            }
        }
        if !model.moreFacts.isEmpty {
            DetailSection(title: "More facts") {
                ForEach(model.moreFacts, id: \.self) { fact in
                    Text("• \(fact)").font(Theme.body(15)).foregroundStyle(Theme.parchment)
                }
            }
        }
        Link(destination: content.pageURL) {
            Label("Read the full article on Wikipedia", systemImage: "safari")
                .font(Theme.label(15))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.amber, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Theme.ink)
        }
        sources
    }

    private var failure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load details. Check your connection.")
                .font(Theme.body(14)).foregroundStyle(Theme.mist)
            Button("Try again") { Task { await model.load(using: provider) } }
                .font(Theme.label(15))
                .foregroundStyle(Theme.amber)
                .frame(minHeight: 44)
        }
    }

    private var quickFacts: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            FactTile(label: "Status", value: species.statusLabel)
            FactTile(label: "Class", value: model.entry.className ?? "–")
            FactTile(label: "Order", value: model.entry.orderName ?? "–")
            FactTile(label: "Family", value: model.entry.familyName ?? "–")
            if let tagline = model.content?.tagline {
                FactTile(label: "Wikipedia says", value: tagline)
            }
        }
    }

    @ViewBuilder private var classification: some View {
        if !model.lineageText.isEmpty {
            DetailSection(title: "Classification") {
                Text(model.lineageText).font(Theme.body(13)).foregroundStyle(Theme.mist)
            }
        }
    }

    private var sources: some View {
        DetailSection(title: "Sources") {
            ForEach(model.textSources) { source in
                if let url = source.url {
                    Link(source.label, destination: url).font(Theme.body(13))
                } else {
                    Text(source.label).font(Theme.body(12)).foregroundStyle(Theme.mist)
                }
            }
            ForEach(model.imageCredits(showArtwork: prefs.showArtwork)) { image in
                CreditChip(attribution: image.attribution)
            }
            Text("Tap any credit to open the original.")
                .font(Theme.body(12)).foregroundStyle(Theme.mist)
        }
        .tint(Theme.parchment)
    }
}

private struct DetailHeader: View {
    let hero: LicensedImage?
    let species: Species

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let hero {
                FullBleedImage(image: hero, wideCenter: 0.5)
                HStack {
                    if let tag = MediaTag.tag(for: hero, species: species) { MediaTagChip(tag: tag) }
                    CreditChip(attribution: hero.attribution)
                }
                .padding(14)
            } else {
                ShimmerFill()
            }
        }
        .frame(height: 300)
        .clipped()
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(Theme.label(11)).tracking(1.2).foregroundStyle(Theme.amber)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

private struct FactTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Theme.label(10)).tracking(1).foregroundStyle(Theme.mist)
            Text(value).font(Theme.body(14).weight(.semibold)).foregroundStyle(Theme.parchment)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(Theme.boardGreen, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
