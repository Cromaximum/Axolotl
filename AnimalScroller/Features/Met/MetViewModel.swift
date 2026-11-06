import Foundation
import Observation

/// State for the Met tab: which filter and sort are on, and the tiles they produce.
@Observable @MainActor
final class MetViewModel {
    let index: TaxonomyIndex
    var filter: MetCollection.Filter = .all
    var sort: MetCollection.Sort = .recent

    init(index: TaxonomyIndex) { self.index = index }

    /// Every species met, resolved against the bundled tree. Used for the header count.
    func allItems(entries: [MetStore.Entry], likedIDs: Set<String>) -> [MetCollection.Item] {
        MetCollection.resolve(entries.map(Self.record), index: index, likedIDs: likedIDs)
    }

    func shown(from all: [MetCollection.Item]) -> [MetCollection.Item] {
        MetCollection.sort(MetCollection.filter(all, by: filter), by: sort)
    }

    var emptyMessage: String {
        switch filter {
        case .all: "Nothing here yet. Start scrolling the feed."
        case .saved: "Long-press a card in the feed, or tap the bookmark, to save a species."
        case .liked: "Double-tap a card in the feed, or tap the heart, to like a species."
        case .extinct: "No extinct species met yet. Turn them on in the Tree tab."
        }
    }

    private static func record(_ e: MetStore.Entry) -> MetCollection.Record {
        MetCollection.Record(id: e.id, firstMet: e.firstMet, lastMet: e.lastMet, saved: e.saved,
                             savedAt: e.savedAt, liveSpecies: e.live?.species,
                             liveLineageIDs: e.live?.lineageIDs ?? [], imageURL: e.imageURL)
    }
}
