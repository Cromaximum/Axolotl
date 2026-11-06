import Foundation
import Observation

/// State for the Awards tab and the "tier reached" toast. `RootView` owns one instance and calls
/// `refresh(met:)` whenever a new species is met.
@Observable @MainActor
final class AchievementsViewModel {
    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [AchievementProgress]
    }

    let index: TaxonomyIndex
    private(set) var board: [AchievementProgress] = []
    /// The tier just reached, shown briefly over the tabs.
    private(set) var toast: AchievementProgress?
    /// Achievements with a tier the user hadn't seen when the tab last opened. Highlighted as new.
    private(set) var highlightedIDs: Set<String> = []

    private var hasBaseline = false
    private var toastTask: Task<Void, Never>?
    static let toastDuration: Duration = .seconds(3)

    init(index: TaxonomyIndex) { self.index = index }

    /// Rebuilds the board. After the first call, a tier that went up shows the toast.
    func refresh(met entries: [MetStore.Entry]) {
        let species = MetCollection.resolve(entries.map(Self.record), index: index, likedIDs: [])
            .map(\.entry)
        let new = AchievementBoard.progress(met: species, index: index)
        if hasBaseline, let up = AchievementBoard.newlyReached(from: board, to: new).first {
            show(up)
        }
        board = new
        hasBaseline = true
    }

    func unseenCount(seen: [String: Int]) -> Int { AchievementBoard.unseenTiers(board, seen: seen) }

    /// Called when the Awards tab appears: remembers what was new, then marks it all seen.
    func tabOpened(store: AchievementsStore) {
        highlightedIDs = AchievementBoard.unseenIDs(board, seen: store.seenTiers)
        store.markSeen(Dictionary(board.map { ($0.id, $0.tier) }) { a, _ in a })
    }

    func dismissToast() {
        toastTask?.cancel()
        toast = nil
    }

    var totalTiers: Int { board.reduce(0) { $0 + $1.tier } }

    /// The board's sections, in board order. Statuses keep the scale order; elsewhere started
    /// achievements come first (most species met first).
    var sections: [Section] {
        AchievementBoard.sections(board).map { group, items in
            Section(id: "\(group)", title: Self.title(group), items: items)
        }
    }

    private static func title(_ group: Achievement.Group) -> String {
        switch group {
        case .overall: "All species"
        case .status: "Conservation status"
        case .rank(.phylum): "Phyla"
        case .rank(.class): "Classes"
        case .rank(.order): "Orders"
        case .rank(.family): "Families"
        case .rank(.genus): "Genera"
        case .rank(.kingdom): "Kingdoms"
        }
    }

    private func show(_ progress: AchievementProgress) {
        toastTask?.cancel()
        toast = progress
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.toastDuration)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private static func record(_ e: MetStore.Entry) -> MetCollection.Record {
        MetCollection.Record(id: e.id, firstMet: e.firstMet, lastMet: e.lastMet, saved: e.saved,
                             savedAt: e.savedAt, liveSpecies: e.live?.species,
                             liveLineageIDs: e.live?.lineageIDs ?? [])
    }
}
