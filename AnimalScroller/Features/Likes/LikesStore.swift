import Foundation
import Observation

/// Species the user liked (heart button or double-tap). Persisted in UserDefaults under `likes.v1`.
/// Separate from saves in `MetStore`: a save is a bookmark to come back to; a like is a signal
/// that steers which species the feed picks next (see `LikeAffinity`).
@Observable
final class LikesStore {
    struct Entry: Codable, Identifiable, Hashable {
        /// Species.wikiTitle
        let id: String
        var commonName: String
        var scientificName: String
        var isExtinct: Bool
        /// Lineage ids and ranks at the time of the like, so live-catalogue species (not in the
        /// bundled tree) still steer the feed after a relaunch.
        var lineage: [LikeAffinity.Step]
        var imageURL: URL?
        var likedAt: Date
    }

    /// Most recent first.
    private(set) var entries: [Entry] = []
    /// Interest per taxon id, recomputed on every change.
    private(set) var affinity: [String: Double] = [:]

    private let defaults: UserDefaults
    static let key = "likes.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        recompute()
    }

    func isLiked(_ id: String) -> Bool { entries.contains { $0.id == id } }

    func toggle(_ entry: SpeciesEntry, imageURL: URL?) {
        if isLiked(entry.id) { unlike(entry.id) } else { like(entry, imageURL: imageURL) }
    }

    /// Double-tap only ever likes, never unlikes.
    func like(_ entry: SpeciesEntry, imageURL: URL?) {
        guard !isLiked(entry.id) else { return }
        let s = entry.species
        entries.insert(Entry(id: s.id, commonName: s.commonName, scientificName: s.scientificName,
                             isExtinct: s.isExtinct, lineage: LikeAffinity.steps(for: entry),
                             imageURL: imageURL, likedAt: Date()), at: 0)
        changed()
    }

    func unlike(_ id: String) {
        entries.removeAll { $0.id == id }
        changed()
    }

    private func changed() {
        recompute()
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }

    private func recompute() {
        affinity = LikeAffinity.affinity(lineages: entries.map(\.lineage))
    }
}
