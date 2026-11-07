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
    /// The card actually on screen. `onAppear` also fires for cards the lazy stack builds ahead
    /// of time, so dwell, prefetch and "Species met" key off this instead (#15).
    @State private var visibleCardID: String?

    init(taxonomy: Taxon, catalog: SpeciesCatalog, provider: SpeciesContentProvider, images: ImageLoading) {
        self.taxonomy = taxonomy
        _model = State(initialValue: FeedViewModel(taxonomy: taxonomy, catalog: catalog,
                                                   provider: provider, images: images))
    }

    var body: some View {
        // Each page fills the whole screen, so the next card never peeks out behind the tab bar.
        // Card content is padded up by the tab bar's height to stay above it.
        GeometryReader { geo in
            let tabBarInset = geo.safeAreaInsets.bottom
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.cards) { card in
                        page(for: card, bottomInset: tabBarInset)
                    }
                    if model.isLoading || model.cards.isEmpty {
                        FeedStatusView(isLoading: model.isLoading, notice: model.notice, onRetry: restart)
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
    private func page(for card: FeedCard, bottomInset: CGFloat) -> some View {
        let context = context(for: card)
        let staticCards = reduceMotion
        return CardView(card: card, context: context)
            .padding(.bottom, bottomInset)
            .containerRelativeFrame([.horizontal, .vertical])
            .clipped()
            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                content
                    .scaleEffect(phase.isIdentity || staticCards ? 1 : 0.94)
                    .opacity(phase.isIdentity ? 1 : 0.55)
            }
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
        var context = CardContext(
            position: card.placement.position,
            count: card.placement.count,
            isSaved: met.isSaved(card.entry.id),
            isLiked: likes.isLiked(card.entry.id),
            onSave: { toggleSaved(card) },
            onLike: { toggleLike(card) },
            onInfo: { detailEntry = card.entry }
        )
        if let next = model.nextSetStart(after: card) {
            context.nextSpeciesName = next.entry.species.commonName
            context.onSkip = { skip(to: next) }
        }
        if case .intro = card {
            context.firstMeetingNumber = model.firstMeetingNumber(for: card, met: met)
            context.showsSwipeHint = !prefs.hasSeenSwipeHint && card.id == model.cards.first?.id
        }
        return context
    }

    /// "Next animal": scrolls past the rest of this species' set to the next intro.
    private func skip(to next: FeedCard) {
        withAnimation(reduceMotion ? nil : Theme.Motion.settle) { visibleCardID = next.id }
    }

    private func restart() {
        model.restart(with: prefs, likes: likes)
    }

    /// Any card of a species counts as meeting it: after a filter change the feed can land
    /// past a species' intro card.
    private func cardBecameVisible(_ card: FeedCard) {
        model.cardAppeared(card, prefs: prefs, likes: likes)
        model.recordMeeting(card, in: met)
        // The first swipe (or skip) past the first card retires the "Swipe up" hint for good.
        if !prefs.hasSeenSwipeHint, card.id != model.cards.first?.id { prefs.hasSeenSwipeHint = true }
    }

    /// Double-tap anywhere on a card likes the species (never unlikes), with a heart burst.
    private func doubleTapLike(_ card: FeedCard) {
        let wasLiked = likes.isLiked(card.entry.id)
        likes.like(card.entry, imageURL: card.primaryImage?.url)
        if !wasLiked { feedback = FeedFeedback(kind: .liked) }
        burstID = card.id
        Task {
            try? await Task.sleep(for: Theme.Motion.feedbackHold)
            if burstID == card.id { burstID = nil }
        }
    }

    private func toggleLike(_ card: FeedCard) {
        likes.toggle(card.entry, imageURL: card.primaryImage?.url)
        feedback = FeedFeedback(kind: likes.isLiked(card.entry.id) ? .liked : .unliked)
    }

    private func toggleSaved(_ card: FeedCard) {
        met.toggleSaved(card.entry, imageURL: card.primaryImage?.url)
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
