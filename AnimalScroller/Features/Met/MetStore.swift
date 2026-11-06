import Foundation
import Observation

/// Every species the user has scrolled past, plus the ones they saved. Persisted in UserDefaults.
@Observable
final class MetStore {
    struct Entry: Codable, Identifiable, Hashable {
        /// Species.wikiTitle
        let id: String
        var commonName: String
        var scientificName: String
        var isExtinct: Bool
        /// Licensed hero image shown on the collection tile.
        var imageURL: URL?
        var firstMet: Date
        var saved: Bool
    }

    /// Most recently met first.
    private(set) var entries: [Entry] = []

    private let defaults: UserDefaults
    private static let key = "met.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
    }

    func isSaved(_ id: String) -> Bool { entries.first { $0.id == id }?.saved ?? false }

    /// Called when a species' intro card is shown. Keeps the first-met date and saved flag.
    func recordMet(_ species: Species, imageURL: URL?) {
        if let i = entries.firstIndex(where: { $0.id == species.id }) {
            if entries[i].imageURL == nil { entries[i].imageURL = imageURL; save() }
            return
        }
        entries.insert(Entry(id: species.id, commonName: species.commonName,
                             scientificName: species.scientificName, isExtinct: species.isExtinct,
                             imageURL: imageURL, firstMet: Date(), saved: false), at: 0)
        save()
    }

    func toggleSaved(_ species: Species, imageURL: URL?) {
        recordMet(species, imageURL: imageURL)
        guard let i = entries.firstIndex(where: { $0.id == species.id }) else { return }
        entries[i].saved.toggle()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }
}
