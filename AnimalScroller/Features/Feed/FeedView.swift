import SwiftUI

@MainActor
struct FeedView: View {
    let taxonomy: Taxon
    @Environment(PreferencesStore.self) private var prefs
    @State private var model: FeedViewModel
    @State private var showingFilters = false

    init(taxonomy: Taxon) {
        self.taxonomy = taxonomy
        _model = State(initialValue: FeedViewModel(taxonomy: taxonomy))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.forest.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.cards) { card in
                        CardView(card: card)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear { model.cardAppeared(card, prefs: prefs) }
                    }
                    if model.isLoading || model.cards.isEmpty {
                        loadingPage.containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
            .refreshable { model.restart(with: prefs) }

            topBar
        }
        .task { if model.cards.isEmpty { model.restart(with: prefs) } }
        .onChange(of: prefs.feedSignature) { model.restart(with: prefs) }
        .sheet(isPresented: $showingFilters) {
            TaxonomyPickerView(root: taxonomy)
                .presentationDetents([.large])
        }
    }

    private var topBar: some View {
        HStack {
            Text("Animal Scroller")
                .font(Theme.heading(22))
                .foregroundStyle(Theme.parchment)
                .shadow(radius: 4)
            Spacer()
            Button {
                showingFilters = true
            } label: {
                Label("Tree of life", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .foregroundStyle(Theme.amber)
                    .shadow(radius: 4)
            }
            .accessibilityLabel("Filter by tree of life")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    @ViewBuilder private var loadingPage: some View {
        VStack(spacing: 16) {
            if let message = model.emptyMessage {
                Image(systemName: "binoculars").font(.largeTitle)
                Text(message).multilineTextAlignment(.center).font(Theme.body())
                Button("Open filters") { showingFilters = true }
                    .buttonStyle(.borderedProminent).tint(Theme.amber)
            } else {
                ProgressView().tint(Theme.amber)
                Text("Finding the next animal…").font(Theme.body(16))
            }
        }
        .foregroundStyle(Theme.parchment)
        .padding(40)
    }
}

struct CardView: View {
    let card: FeedCard

    var body: some View {
        switch card {
        case .intro(let intro): IntroCardView(card: intro)
        case .fact(let fact): FactCardView(card: fact)
        case .photo(let photo): PhotoCardView(card: photo)
        }
    }
}
