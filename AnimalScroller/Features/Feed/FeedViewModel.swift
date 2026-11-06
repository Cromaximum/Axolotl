import Foundation
import Observation

@Observable
@MainActor
final class FeedViewModel {
    private(set) var cards: [FeedCard] = []
    private(set) var isLoading = false
    private(set) var emptyMessage: String?

    private let taxonomy: Taxon
    private let provider: SpeciesContentProvider
    private var picker = SpeciesPicker()
    private var sequence = 0
    private var loadTask: Task<Void, Never>?
    /// Bumped on restart so a cancelled load can't touch the new feed.
    private var generation = 0
    private var currentEntry: SpeciesEntry?
    private var enteredCurrentAt = Date()

    /// Keep this many cards queued below the one on screen.
    private let prefetchDistance = 6

    /// Position of each card in its species set (1-based) and the set's size.
    private(set) var positions: [String: (position: Int, count: Int)] = [:]

    private let catalog: SpeciesCatalog

    init(taxonomy: Taxon,
         catalog: SpeciesCatalog,
         provider: SpeciesContentProvider = WikipediaContentProvider.shared) {
        self.taxonomy = taxonomy
        self.provider = provider
        self.catalog = catalog
    }

    func restart(with prefs: PreferencesStore, likes: LikesStore) {
        loadTask?.cancel()
        generation += 1
        isLoading = false
        cards = []
        positions = [:]
        emptyMessage = nil
        picker.discoveryShare = prefs.surpriseMe ? 0.3 : 0
        loadMore(prefs: prefs, likes: likes)
    }

    func cardAppeared(_ card: FeedCard, prefs: PreferencesStore, likes: LikesStore) {
        if currentEntry?.id != card.entry.id {
            if let previous = currentEntry {
                picker.recordDwell(on: previous, seconds: Date().timeIntervalSince(enteredCurrentAt))
            }
            currentEntry = card.entry
            enteredCurrentAt = Date()
        }
        if let index = cards.firstIndex(of: card), cards.count - index <= prefetchDistance {
            loadMore(prefs: prefs, likes: likes)
        }
    }

    private func loadMore(prefs: PreferencesStore, likes: LikesStore) {
        guard !isLoading else { return }
        // Likes steer tailored picks from the very next species, without restarting the feed.
        picker.likeAffinity = likes.affinity

        let everything = taxonomy.allSpecies().filter { prefs.allowsExtinctStatus($0.species) }
        let tailored = taxonomy.species(selectedIDs: prefs.selectedTaxonIDs)
            .filter { prefs.allowsExtinctStatus($0.species) }

        let live = prefs.liveCatalog
        let split = LiveCatalogRules.split(branches: LiveCatalogRules.searchableBranches(in: taxonomy),
                                           root: taxonomy, selectedIDs: prefs.selectedTaxonIDs)
        let liveInside = split.inside
        let liveOutside = prefs.surpriseMe ? split.outside : []

        guard !tailored.isEmpty || (prefs.surpriseMe && !everything.isEmpty) || (live && !liveInside.isEmpty) else {
            emptyMessage = "No species match these filters yet. Try another branch or turn on extinct species."
            return
        }
        let allowArtwork = prefs.showArtwork
        let filter = prefs.catalogFilter

        isLoading = true
        let myGeneration = generation
        loadTask = Task {
            defer { if generation == myGeneration { isLoading = false } }
            // Try a few species in case one has no usable article or images. FeedSourcePlanner
            // decides which source each attempt uses; this loop only follows it.
            for attempt in 0..<FeedSourcePlanner.attempts {
                guard !Task.isCancelled, generation == myGeneration else { return }
                let bundledPool = tailored.isEmpty ? everything : tailored
                let sources = FeedSourcePlanner.sources(
                    attempt: attempt, liveEnabled: live,
                    bundledExhausted: bundledPool.isEmpty || picker.hasSeenAll(bundledPool),
                    roll: Double.random(in: 0..<1))

                var entry: SpeciesEntry?
                for source in sources where entry == nil {
                    switch source {
                    case .live: entry = await nextLive(inside: liveInside, outside: liveOutside, filter: filter, prefs: prefs)
                    case .bundled: entry = picker.next(tailored: tailored, everything: everything)
                    }
                }
                guard let chosen = entry else { continue }
                if await show(chosen, allowArtwork: allowArtwork, generation: myGeneration) { return }
            }
            if cards.isEmpty { emptyMessage = "Couldn't reach Wikipedia. Check your connection and pull to retry." }
        }
    }

    /// One species from the live catalogue, or nil if this branch had nothing good enough.
    private func nextLive(inside: [Taxon], outside: [Taxon], filter: CatalogExtinctFilter,
                          prefs: PreferencesStore) async -> SpeciesEntry? {
        var rng = SystemRandomNumberGenerator()
        guard let pick = picker.pickBranch(inside: inside, outside: outside, using: &rng),
              let path = taxonomy.path(to: pick.branch.id) else { return nil }
        do {
            let candidates = try await catalog.candidates(branchPath: path, filter: filter)
            guard let candidate = picker.choose(from: candidates, tailored: !pick.isDiscovery, using: &rng) else {
                picker.recordBranchMiss(pick.branch)
                return nil
            }
            let entry = await catalog.finalize(candidate, filter: filter)
            // The real IUCN status is only known now; re-apply the extinct filter with it.
            guard prefs.allowsExtinctStatus(entry.species) else { return nil }
            picker.markShown(entry)
            return entry
        } catch {
            picker.recordBranchMiss(pick.branch)
            return nil
        }
    }

    /// Fetches content and appends the species' cards. True when done (shown, or the feed moved on).
    private func show(_ entry: SpeciesEntry, allowArtwork: Bool, generation myGeneration: Int) async -> Bool {
        do {
            let content = try await provider.content(for: entry.species)
            guard !Task.isCancelled, generation == myGeneration else { return true }
            guard LiveCatalogRules.isShowable(content, species: entry.species, allowArtwork: allowArtwork) else {
                return false
            }
            sequence += 1
            let set = FeedComposer.cards(for: entry, content: content,
                                         sequence: sequence, allowArtwork: allowArtwork)
            guard !set.isEmpty else { return false }
            for (i, card) in set.enumerated() { positions[card.id] = (i + 1, set.count) }
            cards.append(contentsOf: set)
            return true
        } catch {
            return false
        }
    }
}
