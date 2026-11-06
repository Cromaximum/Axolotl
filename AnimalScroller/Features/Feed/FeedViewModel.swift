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

    init(taxonomy: Taxon, provider: SpeciesContentProvider = WikipediaContentProvider()) {
        self.taxonomy = taxonomy
        self.provider = provider
    }

    func restart(with prefs: PreferencesStore) {
        loadTask?.cancel()
        generation += 1
        isLoading = false
        cards = []
        emptyMessage = nil
        picker.discoveryShare = prefs.surpriseMe ? 0.3 : 0
        loadMore(prefs: prefs)
    }

    func cardAppeared(_ card: FeedCard, prefs: PreferencesStore) {
        if currentEntry?.id != card.entry.id {
            if let previous = currentEntry {
                picker.recordDwell(on: previous, seconds: Date().timeIntervalSince(enteredCurrentAt))
            }
            currentEntry = card.entry
            enteredCurrentAt = Date()
        }
        if let index = cards.firstIndex(of: card), cards.count - index <= prefetchDistance {
            loadMore(prefs: prefs)
        }
    }

    private func loadMore(prefs: PreferencesStore) {
        guard !isLoading else { return }
        let everything = taxonomy.allSpecies().filter { prefs.allowsExtinctStatus($0.species) }
        let tailored = taxonomy.species(selectedIDs: prefs.selectedTaxonIDs)
            .filter { prefs.allowsExtinctStatus($0.species) }
        guard !tailored.isEmpty || (prefs.surpriseMe && !everything.isEmpty) else {
            emptyMessage = "No species match these filters yet. Try another branch or turn on extinct species."
            return
        }
        let allowArtwork = prefs.showArtwork

        isLoading = true
        let myGeneration = generation
        loadTask = Task {
            defer { if generation == myGeneration { isLoading = false } }
            // Try a few species in case one has no usable article or images.
            for _ in 0..<4 {
                guard !Task.isCancelled,
                      let entry = picker.next(tailored: tailored, everything: everything) else { return }
                do {
                    let content = try await provider.content(for: entry.species)
                    guard !Task.isCancelled, generation == myGeneration else { return }
                    sequence += 1
                    let set = FeedComposer.cards(for: entry, content: content,
                                                 sequence: sequence, allowArtwork: allowArtwork)
                    cards.append(contentsOf: set)
                    return
                } catch {
                    continue
                }
            }
            if cards.isEmpty { emptyMessage = "Couldn't reach Wikipedia. Check your connection and pull to retry." }
        }
    }
}
