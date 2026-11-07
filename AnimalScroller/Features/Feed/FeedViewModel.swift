import Foundation
import Observation
import os

/// Why the feed has no card to show right now. `FeedView` turns it into the empty or offline page.
enum FeedNotice: Equatable {
    /// The chosen branches and extinct toggles leave nothing to show.
    case noMatches
    /// Nothing could be loaded, most likely because Wikipedia couldn't be reached.
    case offline
}

@Observable
@MainActor
final class FeedViewModel {
    private(set) var cards: [FeedCard] = []
    private(set) var notice: FeedNotice?
    var isLoading: Bool { !loadTasks.isEmpty }

    private let taxonomy: Taxon
    private let provider: SpeciesContentProvider
    private let images: ImageLoading
    private let catalog: SpeciesCatalog
    private var picker = SpeciesPicker()
    private var sequence = 0
    /// Species loads in flight, by load id. Up to `maxParallelLoads` at once.
    private var loadTasks: [Int: Task<Void, Never>] = [:]
    private var nextLoadID = 0
    private var prefetchTask: Task<Void, Never>?
    /// Bumped on restart so a cancelled load can't touch the new feed.
    private var generation = 0
    private var currentEntry: SpeciesEntry?
    private var currentIndex = 0
    private var enteredCurrentAt = Date()
    private var restartedAt = Date()
    /// "No. N met" badge numbers handed out this session, by species set (`setKey`).
    private var firstMeetings: [String: Int] = [:]

    /// Start loading more species when this few cards are left below the one on screen.
    private let prefetchDistance = 6
    /// Species fetched at the same time. Two halves time to first card without hammering Wikipedia.
    private let maxParallelLoads = 2
    /// Photos decoded ahead of the card on screen.
    private let imagePrefetchCount = 3

    private static let log = Logger(subsystem: "com.cromaximum.animalscroller", category: "feed")
    private static let signposter = OSSignposter(subsystem: "com.cromaximum.animalscroller", category: "feed")

    init(taxonomy: Taxon, catalog: SpeciesCatalog, provider: SpeciesContentProvider, images: ImageLoading) {
        self.taxonomy = taxonomy
        self.catalog = catalog
        self.provider = provider
        self.images = images
    }

    // MARK: Intents

    func restart(with prefs: PreferencesStore, likes: LikesStore) {
        loadTasks.values.forEach { $0.cancel() }
        loadTasks = [:]
        prefetchTask?.cancel()
        generation += 1
        cards = []
        notice = nil
        currentIndex = 0
        restartedAt = Date()
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
        guard let index = cards.firstIndex(of: card) else { return }
        currentIndex = index
        prefetchImages(after: index)
        if cards.count - index <= prefetchDistance {
            loadMore(prefs: prefs, likes: likes)
        }
    }

    /// Adds the species to Met. If this is the first time, remembers its "No. N met" number so
    /// the intro keeps its badge after the meeting is recorded.
    func recordMeeting(_ card: FeedCard, in met: MetStore) {
        let key = Self.setKey(card)
        if let number = FeedNavigation.firstMeetingNumber(for: key, known: firstMeetings,
                                                          alreadyMet: met.hasMet(card.entry.id),
                                                          metCount: met.entries.count) {
            firstMeetings[key] = number
        }
        met.recordMet(card.entry)
    }

    /// The "No. N met" number for a species set the user is meeting for the first time, or nil.
    func firstMeetingNumber(for card: FeedCard, met: MetStore) -> Int? {
        FeedNavigation.firstMeetingNumber(for: Self.setKey(card), known: firstMeetings,
                                          alreadyMet: met.hasMet(card.entry.id),
                                          metCount: met.entries.count)
    }

    /// Where "Next animal" jumps to: the next species' intro, once it has loaded.
    func nextSetStart(after card: FeedCard) -> FeedCard? {
        FeedNavigation.nextSetStart(after: card.id, in: cards)
    }

    private static func setKey(_ card: FeedCard) -> String { "\(card.entry.id)#\(card.sequence)" }

    // MARK: Loading

    /// Everything one species load needs, captured from the preferences when it starts.
    private struct LoadPlan {
        let tailored: [SpeciesEntry]
        let everything: [SpeciesEntry]
        let live: Bool
        let liveInside: [Taxon]
        let liveOutside: [Taxon]
        let allowArtwork: Bool
        let filter: CatalogExtinctFilter
    }

    private func loadMore(prefs: PreferencesStore, likes: LikesStore) {
        guard loadTasks.count < maxParallelLoads else { return }
        // Likes steer tailored picks from the very next species, without restarting the feed.
        picker.likeAffinity = likes.affinity

        let everything = taxonomy.allSpecies().filter { prefs.allowsExtinctStatus($0.species) }
        let tailored = taxonomy.species(selectedIDs: prefs.selectedTaxonIDs)
            .filter { prefs.allowsExtinctStatus($0.species) }
        let split = LiveCatalogRules.split(branches: LiveCatalogRules.searchableBranches(in: taxonomy),
                                           root: taxonomy, selectedIDs: prefs.selectedTaxonIDs)
        let plan = LoadPlan(tailored: tailored, everything: everything, live: prefs.liveCatalog,
                            liveInside: split.inside, liveOutside: prefs.surpriseMe ? split.outside : [],
                            allowArtwork: prefs.showArtwork, filter: prefs.catalogFilter)

        guard !tailored.isEmpty || (prefs.surpriseMe && !everything.isEmpty)
                || (plan.live && !plan.liveInside.isEmpty) else {
            notice = .noMatches
            return
        }
        while loadTasks.count < maxParallelLoads {
            startLoad(plan, prefs: prefs)
        }
    }

    private func startLoad(_ plan: LoadPlan, prefs: PreferencesStore) {
        let id = nextLoadID
        nextLoadID += 1
        let myGeneration = generation
        // Runs on the main actor; it can't start before this assignment finishes.
        loadTasks[id] = Task {
            await loadOneSpecies(plan, prefs: prefs, generation: myGeneration)
            guard generation == myGeneration else { return }
            loadTasks[id] = nil
            if loadTasks.isEmpty, cards.isEmpty, notice == nil { notice = .offline }
        }
    }

    /// Tries a few species in case one has no usable article or images. FeedSourcePlanner
    /// decides which source each attempt uses; this loop only follows it.
    private func loadOneSpecies(_ plan: LoadPlan, prefs: PreferencesStore, generation myGeneration: Int) async {
        for attempt in 0..<FeedSourcePlanner.attempts {
            guard !Task.isCancelled, generation == myGeneration else { return }
            let bundledPool = plan.tailored.isEmpty ? plan.everything : plan.tailored
            let sources = FeedSourcePlanner.sources(
                attempt: attempt, liveEnabled: plan.live,
                bundledExhausted: bundledPool.isEmpty || picker.hasSeenAll(bundledPool),
                roll: Double.random(in: 0..<1))

            var entry: SpeciesEntry?
            for source in sources where entry == nil {
                switch source {
                case .live:
                    entry = await nextLive(inside: plan.liveInside, outside: plan.liveOutside,
                                           filter: plan.filter, prefs: prefs)
                case .bundled:
                    entry = picker.next(tailored: plan.tailored, everything: plan.everything)
                }
            }
            guard let chosen = entry else { continue }
            if await show(chosen, allowArtwork: plan.allowArtwork, generation: myGeneration) { return }
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
        let signpost = Self.signposter.beginInterval("Species content", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("Species content", signpost) }
        do {
            let content = try await provider.content(for: entry.species)
            guard !Task.isCancelled, generation == myGeneration else { return true }
            guard LiveCatalogRules.isShowable(content, species: entry.species, allowArtwork: allowArtwork) else {
                return false
            }
            sequence += 1
            let composed = FeedComposer.cards(for: entry, content: content,
                                              sequence: sequence, allowArtwork: allowArtwork)
            guard !composed.isEmpty else { return false }
            let set = composed.enumerated().map { i, card in
                card.placed(CardPlacement(position: i + 1, count: composed.count))
            }
            if cards.isEmpty {
                let ms = Int(Date().timeIntervalSince(restartedAt) * 1000)
                Self.log.info("Time to first card: \(ms) ms")
            }
            cards.append(contentsOf: set)
            // The new set's intro photo is decoded before the user gets there.
            prefetch(set.prefix(2).compactMap { $0.primaryImage?.url })
            if cards.count - currentIndex <= imagePrefetchCount + 1 { prefetchImages(after: currentIndex) }
            return true
        } catch {
            return false
        }
    }

    // MARK: Image prefetch

    private func prefetchImages(after index: Int) {
        prefetch(cards.dropFirst(index + 1).prefix(imagePrefetchCount).compactMap { $0.primaryImage?.url })
    }

    private func prefetch(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let images = images
        prefetchTask = Task { await images.prefetch(urls, maxPixelSize: images.fullScreenPixelSize) }
    }
}
