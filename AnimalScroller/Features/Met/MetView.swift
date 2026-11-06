import SwiftUI

/// "Species met": a collection of every species the user has scrolled past.
struct MetView: View {
    let taxonomy: Taxon
    @Environment(MetStore.self) private var met
    @State private var filter: Filter = .all
    @State private var detailEntry: SpeciesEntry?

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", saved = "Saved", extinct = "Extinct"
        var id: String { rawValue }
    }

    private var entriesByID: [String: SpeciesEntry] {
        Dictionary(taxonomy.allSpecies().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var shown: [MetStore.Entry] {
        switch filter {
        case .all: met.entries
        case .saved: met.entries.filter(\.saved)
        case .extinct: met.entries.filter(\.isExtinct)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your collection").font(Theme.body(13)).foregroundStyle(Theme.mist)
                    Text("Species met · \(met.entries.count)").font(Theme.heading(30)).foregroundStyle(Theme.parchment)
                }
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if shown.isEmpty {
                    Text(filter == .saved ? "Long-press a card in the feed, or tap the bookmark, to save a species."
                                          : "Nothing here yet. Start scrolling the feed.")
                        .font(Theme.body(15)).foregroundStyle(Theme.mist)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(shown) { item in
                            Button { detailEntry = entriesByID[item.id] } label: { tile(item) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                Text("Every species you scroll past is added here. Long-press in the feed to save one.")
                    .font(Theme.body(12)).foregroundStyle(Theme.mist)
            }
            .padding(16)
        }
        .background(Theme.forest)
        .sheet(item: $detailEntry) { entry in
            SpeciesDetailView(entry: entry).presentationDragIndicator(.visible)
        }
    }

    private func tile(_ item: MetStore.Entry) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.imageURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() }
                else { Theme.boardGreen }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 140)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            Text(item.commonName)
                .font(Theme.label(11))
                .foregroundStyle(Theme.parchment)
                .lineLimit(2)
                .padding(6)
            if item.saved {
                Image(systemName: "bookmark.fill").foregroundStyle(Theme.amber)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}
