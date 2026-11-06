import SwiftUI

@MainActor
struct FeedView: View {
    let taxonomy: Taxon
    @Environment(PreferencesStore.self) private var prefs
    @Environment(MetStore.self) private var met
    @Environment(LikesStore.self) private var likes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Card id that just got a double-tap like, for the heart burst.
    @State private var burstID: String?
    /// Last like or save, for the toast and haptics. A new value each time, so repeats still fire.
    @State private var feedback: FeedFeedback?
    @State private var model: FeedViewModel
    @State private var detailEntry: SpeciesEntry?

    init(taxonomy: Taxon, catalog: SpeciesCatalog, provider: SpeciesContentProvider, images: ImageLoading) {
        self.taxonomy = taxonomy
        _model = State(initialValue: FeedViewModel(taxonomy: taxonomy, catalog: catalog,
                                                   provider: provider, images: images))
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(model.cards) { card in
                    page(for: card)
                }
                if model.isLoading || model.cards.isEmpty {
                    FeedStatusView(isLoading: model.isLoading, message: model.emptyMessage, onRetry: restart)
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Theme.forest)
        .overlay(alignment: .bottom) { toast }
        .sensoryFeedback(trigger: feedback) { _, new in new?.haptic }
        .refreshable { restart() }
        .task { if model.cards.isEmpty { restart() } }
        .onChange(of: prefs.feedSignature) { restart() }
        .sheet(item: $detailEntry) { entry in
            SpeciesDetailView(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// One full-screen card, with its gestures, feedback and VoiceOver actions.
    private func page(for card: FeedCard) -> some View {
        let context = context(for: card)
        let staticCards = reduceMotion
        return CardView(card: card, context: context)
            .containerRelativeFrame([.horizontal, .vertical])
            .clipped()
            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                content
                    .scaleEffect(phase.isIdentity || staticCards ? 1 : 0.94)
                    .opacity(phase.isIdentity ? 1 : 0.55)
            }
            .onAppear { cardAppeared(card) }
            // Simultaneous, so single taps on the board and buttons aren't held back
            // waiting to see whether a second tap follows.
            .simultaneousGesture(TapGesture(count: 2).onEnded { doubleTapLike(card) })
            .onLongPressGesture { toggleSaved(card) }
            .overlay { if burstID == card.id { LikeBurst() } }
            .accessibilityElement(children: .contain)
            .accessibilityActions {
                Button(context.isLiked ? "Unlike" : "Like", action: context.onLike)
                Button(context.isSaved ? "Unsave" : "Save", action: context.onSave)
                Button("Species details", action: context.onInfo)
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
            onLike: { toggleLike(card) },
            onInfo: { detailEntry = card.entry }
        )
    }

    private func restart() {
        model.restart(with: prefs, likes: likes)
    }

    private func cardAppeared(_ card: FeedCard) {
        model.cardAppeared(card, prefs: prefs, likes: likes)
        if case .intro(let intro) = card {
            met.recordMet(intro.entry.species, imageURL: intro.hero?.url)
        }
    }

    /// Double-tap anywhere on a card likes the species (never unlikes), with a heart burst.
    private func doubleTapLike(_ card: FeedCard) {
        let wasLiked = likes.isLiked(card.entry.id)
        likes.like(card.entry, imageURL: heroURL(for: card))
        if !wasLiked { feedback = FeedFeedback(kind: .liked) }
        burstID = card.id
        Task {
            try? await Task.sleep(for: Theme.Motion.feedbackHold)
            if burstID == card.id { burstID = nil }
        }
    }

    private func toggleLike(_ card: FeedCard) {
        likes.toggle(card.entry, imageURL: heroURL(for: card))
        feedback = FeedFeedback(kind: likes.isLiked(card.entry.id) ? .liked : .unliked)
    }

    private func toggleSaved(_ card: FeedCard) {
        met.toggleSaved(card.entry.species, imageURL: heroURL(for: card))
        show(FeedFeedback(kind: met.isSaved(card.entry.id) ? .saved : .unsaved))
    }

    /// Sets the feedback (haptic and toast), announces it to VoiceOver, and clears the toast later.
    private func show(_ new: FeedFeedback) {
        withAnimation(reduceMotion ? Theme.Motion.fade : Theme.Motion.settle) { feedback = new }
        if let message = new.message { AccessibilityNotification.Announcement(message).post() }
        Task {
            try? await Task.sleep(for: Theme.Motion.feedbackHold)
            if feedback == new { withAnimation(Theme.Motion.fade) { feedback = nil } }
        }
    }

    @ViewBuilder private var toast: some View {
        if let message = feedback?.message {
            FeedbackToast(message: message, systemImage: feedback?.icon ?? "bookmark")
                .padding(.bottom, 24)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func heroURL(for card: FeedCard) -> URL? {
        switch card {
        case .intro(let c): c.hero?.url
        case .photo(let c): c.image.url
        case .fact(let c): c.image?.url
        }
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
