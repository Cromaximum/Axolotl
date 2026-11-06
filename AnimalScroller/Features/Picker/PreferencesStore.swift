import Foundation
import Observation

/// The user's filter choices, persisted in UserDefaults.
@Observable
final class PreferencesStore {
    /// Selected nodes of the tree of life. Empty means the whole animal kingdom.
    var selectedTaxonIDs: Set<String> { didSet { save() } }
    var includeExtinct: Bool { didSet { save() } }
    /// Only meaningful when `includeExtinct` is on.
    var extinctOnly: Bool { didSet { save() } }
    /// Paleoart reconstructions of extinct species (always labelled). Living species never show artwork.
    var showArtwork: Bool { didSet { save() } }
    /// Mix in random species from outside the selected branches.
    var surpriseMe: Bool { didSet { save() } }

    private let defaults: UserDefaults
    private static let key = "preferences.v1"

    private struct Stored: Codable {
        var selectedTaxonIDs: Set<String> = []
        var includeExtinct = true
        var extinctOnly = false
        var showArtwork = true
        var surpriseMe = true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()
        selectedTaxonIDs = stored.selectedTaxonIDs
        includeExtinct = stored.includeExtinct
        extinctOnly = stored.extinctOnly
        showArtwork = stored.showArtwork
        surpriseMe = stored.surpriseMe
    }

    /// A value that changes whenever anything affecting the feed changes.
    var feedSignature: String {
        "\(selectedTaxonIDs.sorted())|\(includeExtinct)|\(extinctOnly)|\(showArtwork)|\(surpriseMe)"
    }

    func allowsExtinctStatus(_ species: Species) -> Bool {
        if !includeExtinct { return !species.isExtinct }
        if extinctOnly { return species.isExtinct }
        return true
    }

    /// Toggling a node selects its whole branch and folds away any now-redundant child selections.
    func toggle(_ taxon: Taxon) {
        if selectedTaxonIDs.contains(taxon.id) {
            selectedTaxonIDs.remove(taxon.id)
        } else {
            selectedTaxonIDs.subtract(taxon.descendantIDs)
            selectedTaxonIDs.insert(taxon.id)
        }
    }

    private func save() {
        let stored = Stored(selectedTaxonIDs: selectedTaxonIDs, includeExtinct: includeExtinct,
                            extinctOnly: extinctOnly, showArtwork: showArtwork, surpriseMe: surpriseMe)
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: Self.key) }
    }
}
