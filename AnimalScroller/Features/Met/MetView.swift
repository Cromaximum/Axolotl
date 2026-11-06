import SwiftUI

/// "Species met": a collection of every species the user has scrolled past, with filters for
/// saved, liked and extinct species and a sort menu. Tapping a tile opens the detail sheet.
struct MetView: View {
    @Environment(MetStore.self) private var met
    @Environment(LikesStore.self) private var likes
    @State private var model: MetViewModel
    @State private var detailEntry: SpeciesEntry?

    init(index: TaxonomyIndex) {
        _model = State(initialValue: MetViewModel(index: index))
    }

    var body: some View {
        @Bindable var model = model
        let all = model.allItems(entries: met.entries, likedIDs: Set(likes.entries.map(\.id)))
        let shown = model.shown(from: all)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(count: all.count)
                Picker("Show", selection: $model.filter) {
                    ForEach(MetCollection.Filter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if shown.isEmpty {
                    Text(model.emptyMessage)
                        .font(Theme.body(15)).foregroundStyle(Theme.mist)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                        ForEach(shown) { item in
                            Button { detailEntry = item.entry } label: { MetTile(item: item) }
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

    private func header(count: Int) -> some View {
        @Bindable var model = model
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your collection").font(Theme.body(13)).foregroundStyle(Theme.mist)
                Text("Species met · \(count)").font(Theme.heading(30)).foregroundStyle(Theme.parchment)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Menu {
                Picker("Sort by", selection: $model.sort) {
                    ForEach(MetCollection.Sort.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(Theme.amber)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Sort")
            .accessibilityValue(model.sort.label)
        }
    }
}

/// One photo tile. Its identity is the species id, so the grid doesn't reload photos when the
/// filter or sort changes.
private struct MetTile: View {
    let item: MetCollection.Item

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.imageURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() }
                else { Theme.boardGreen }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 140)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            Text(item.entry.species.commonName)
                .font(Theme.label(11))
                .foregroundStyle(Theme.parchment)
                .lineLimit(2)
                .padding(6)
            HStack(spacing: 4) {
                if item.liked { Image(systemName: "heart.fill") }
                if item.saved { Image(systemName: "bookmark.fill") }
            }
            .foregroundStyle(Theme.amber)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens details")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        var parts = [item.entry.species.commonName]
        if item.saved { parts.append("Saved") }
        if item.liked { parts.append("Liked") }
        return parts.joined(separator: ", ")
    }
}
