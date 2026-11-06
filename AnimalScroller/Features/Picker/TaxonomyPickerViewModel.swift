import Foundation
import Observation

/// State for the Tree tab: the search text and its results, plus row and summary state read from
/// the prebuilt `TaxonomyIndex`. The selection itself lives in `PreferencesStore`.
@Observable @MainActor
final class TaxonomyPickerViewModel {
    let index: TaxonomyIndex

    /// Bound to `.searchable`. Searching the bundled tree is a few hundred string compares, so it
    /// runs on every keystroke without a debounce.
    var query = "" {
        didSet { results = index.search(query) }
    }
    private(set) var results: [TaxonomyIndex.SearchHit] = []

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(index: TaxonomyIndex) { self.index = index }

    var topLevel: [Taxon] { index.root.outlineChildren ?? [] }

    func state(of id: String, selection: Set<String>) -> TaxonomyIndex.SelectionState {
        index.state(of: id, selection: selection)
    }

    func speciesCount(_ id: String) -> Int { index.speciesCount(id) }

    func summary(selection: Set<String>) -> [Taxon] { index.summary(selection: selection) }

    /// Display name of a node, for "Included by <branch>".
    func name(of id: String) -> String { index.node(id)?.name ?? "" }

    /// "Mammals › Carnivorans" style path for a search hit, skipping the root.
    func pathText(_ hit: TaxonomyIndex.SearchHit) -> String {
        hit.ancestors.dropFirst().map(\.name).joined(separator: " › ")
    }

    /// Footer under the summary.
    func coverageText(selection: Set<String>, liveCatalog: Bool) -> String {
        let n = index.speciesCount(selection: selection)
        if selection.isEmpty {
            return liveCatalog ? "Everything: \(n) hand-picked species, plus the full catalogue."
                               : "Everything: all \(n) species."
        }
        return liveCatalog ? "\(n) hand-picked species in your branches, plus the full catalogue."
                           : "\(n) species in your branches."
    }

    /// Toggles the branch a search hit points at, or a tree row.
    func toggle(_ id: String, in prefs: PreferencesStore) {
        guard let taxon = index.node(id) else { return }
        prefs.toggle(taxon)
    }
}
