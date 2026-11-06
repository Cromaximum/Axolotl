import SwiftUI

@MainActor
struct FeedView: View {
    let taxonomy: Taxon
    @Environment(PreferencesStore.self) private var prefs
    @Environment(MetStore.self) private var met
    @Environment(LikesStore.self) private var likes
    /// Species id that just got a double-tap like, for the heart burst.
    @State private var burstID: String?
    @State private var model: FeedViewModel
    @State private var detailEntry: SpeciesEntry?
    /// The card actually on screen. `onAppear` also fires for cards the lazy stack builds ahead
    /// of time, so dwell, prefetch and "Species met" key off this instead.
    @State private var visibleCardID: String?

    init(taxonomy: Taxon, catalog: SpeciesCatalog) {
        self.taxonomy = taxonomy
        _model = State(initialValue: FeedViewModel(taxonomy: taxonomy, catalog: catalog))
    }

    var body: some View {
        // Each page fills the whole screen, so the next card never shows behind the tab bar.
        // Card content is padded up by the tab bar's height to stay above it.
        GeometryReader { geo in
            let tabBarInset = geo.safeAreaInsets.bottom
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.cards) { card in
                        CardView(card: card, context: context(for: card))
                            .padding(.bottom, tabBarInset)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .clipped()
                            .onTapGesture(count: 2) { doubleTapLike(card) }
                            .overlay { if burstID == card.id { LikeBurst() } }
                            .onLongPressGesture { toggleSaved(card) }
                    }
                    if model.isLoading || model.cards.isEmpty {
                        loadingPage
                            .padding(.bottom, tabBarInset)
                            .containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $visibleCardID)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
        }
        .background(Theme.forest)
        .onChange(of: model.cards.first?.id) { _, firstID in
            // A restart replaces every card. Start the new feed at its top instead of wherever
            // the old scroll offset happens to land.
            if !model.cards.contains(where: { $0.id == visibleCardID }) { visibleCardID = firstID }
        }
        .onChange(of: visibleCardID) { _, id in
            if let card = model.cards.first(where: { $0.id == id }) { cardBecameVisible(card) }
        }
        .refreshable { model.restart(with: prefs, likes: likes) }
        .task { if model.cards.isEmpty { model.restart(with: prefs, likes: likes) } }
        .onChange(of: prefs.feedSignature) { model.restart(with: prefs, likes: likes) }
        .sheet(item: $detailEntry) { entry in
            SpeciesDetailView(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func context(for card: FeedCard) -> CardContext {
        let pos = model.positions[card.id] ?? (position: 1, count: 1)
        return CardContext(
            position: pos.position,
            count: pos.count,
            isSaved: met.isSaved(card.entry.id),
            isLiked: likes.isLiked(card.entry.id),
            onSave: { toggleSaved(card) },
            onLike: { likes.toggle(card.entry, imageURL: heroURL(for: card)) },
            onInfo: { detailEntry = card.entry }
        )
    }

    /// Any card of a species counts as meeting it: after a filter change the feed can land
    /// past a species' intro card.
    private func cardBecameVisible(_ card: FeedCard) {
        model.cardAppeared(card, prefs: prefs, likes: likes)
        met.recordMet(card.entry.species, imageURL: heroURL(for: card))
    }

    /// Double-tap anywhere on a card likes the species (never unlikes), with a heart burst.
    private func doubleTapLike(_ card: FeedCard) {
        likes.like(card.entry, imageURL: heroURL(for: card))
        burstID = card.id
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if burstID == card.id { burstID = nil }
        }
    }

    private func toggleSaved(_ card: FeedCard) {
        met.toggleSaved(card.entry.species, imageURL: heroURL(for: card))
    }

    private func heroURL(for card: FeedCard) -> URL? {
        switch card {
        case .intro(let c): c.hero?.url
        case .photo(let c): c.image.url
        case .fact(let c): c.image?.url
        }
    }

    @ViewBuilder private var loadingPage: some View {
        VStack(spacing: 16) {
            if let message = model.emptyMessage {
                Image(systemName: "binoculars").font(.largeTitle)
                Text(message).multilineTextAlignment(.center).font(Theme.body())
                Text("Change your branches on the Tree tab.").font(Theme.body(14)).foregroundStyle(Theme.mist)
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
    let context: CardContext

    var body: some View {
        switch card {
        case .intro(let intro): IntroCardView(card: intro, context: context)
        case .fact(let fact): FactCardView(card: fact, context: context)
        case .photo(let photo): PhotoCardView(card: photo, context: context)
        }
    }
}
