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
    /// Set once the welcome and starting-point screens have been completed.
    var hasOnboarded: Bool { didSet { save() } }
    /// Look beyond the bundled list: find species in the GBIF Backbone and build their cards live.
    var liveCatalog: Bool { didSet { save() } }

    private let defaults: UserDefaults
    private static let key = "preferences.v1"

    private struct Stored: Codable {
        var selectedTaxonIDs: Set<String> = []
        var includeExtinct = true
        var extinctOnly = false
        var showArtwork = true
        var surpriseMe = true
        var hasOnboarded = false
        var liveCatalog = true

        init() {}

        // Every field is optional on decode so adding a field never wipes older saved preferences.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Stored()
            selectedTaxonIDs = try c.decodeIfPresent(Set<String>.self, forKey: .selectedTaxonIDs) ?? d.selectedTaxonIDs
            includeExtinct = try c.decodeIfPresent(Bool.self, forKey: .includeExtinct) ?? d.includeExtinct
            extinctOnly = try c.decodeIfPresent(Bool.self, forKey: .extinctOnly) ?? d.extinctOnly
            showArtwork = try c.decodeIfPresent(Bool.self, forKey: .showArtwork) ?? d.showArtwork
            surpriseMe = try c.decodeIfPresent(Bool.self, forKey: .surpriseMe) ?? d.surpriseMe
            hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? d.hasOnboarded
            liveCatalog = try c.decodeIfPresent(Bool.self, forKey: .liveCatalog) ?? d.liveCatalog
        }
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
        hasOnboarded = stored.hasOnboarded
        liveCatalog = stored.liveCatalog
    }

    /// The three-way switch on the Tree screen, stored as the two existing flags.
    enum ExtinctMode: String, CaseIterable, Identifiable {
        case livingOnly, includeExtinct, extinctOnly
        var id: String { rawValue }
        var label: String {
            switch self {
            case .livingOnly: "Living only"
            case .includeExtinct: "Include extinct"
            case .extinctOnly: "Extinct only"
            }
        }
    }

    var extinctMode: ExtinctMode {
        get {
            if !includeExtinct { return .livingOnly }
            return extinctOnly ? .extinctOnly : .includeExtinct
        }
        set {
            includeExtinct = newValue != .livingOnly
            extinctOnly = newValue == .extinctOnly
        }
    }

    /// A value that changes whenever anything affecting the feed changes.
    var feedSignature: String {
        "\(selectedTaxonIDs.sorted())|\(includeExtinct)|\(extinctOnly)|\(showArtwork)|\(surpriseMe)|\(liveCatalog)"
    }

    var catalogFilter: CatalogExtinctFilter {
        switch extinctMode {
        case .livingOnly: .livingOnly
        case .includeExtinct: .any
        case .extinctOnly: .extinctOnly
        }
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
        var stored = Stored()
        stored.selectedTaxonIDs = selectedTaxonIDs
        stored.includeExtinct = includeExtinct
        stored.extinctOnly = extinctOnly
        stored.showArtwork = showArtwork
        stored.surpriseMe = surpriseMe
        stored.hasOnboarded = hasOnboarded
        stored.liveCatalog = liveCatalog
        if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: Self.key) }
    }
}
