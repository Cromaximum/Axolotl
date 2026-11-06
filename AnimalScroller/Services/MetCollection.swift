import Foundation

/// The "Species met" collection: turns stored ids into displayable species, then filters and
/// sorts them. Pure logic, no I/O and no store types: the Met view model maps `MetStore` entries
/// to `Record`s and passes the liked ids in.
enum MetCollection {
    /// What the store keeps for one species: ids, dates and flags (no names for bundled species).
    struct Record: Hashable, Sendable {
        let id: String
        var firstMet: Date
        var lastMet: Date
        var saved: Bool
        var savedAt: Date?
        /// Only for live-catalogue species that aren't in `taxonomy.json`.
        var liveSpecies: Species?
        var liveLineageIDs: [String] = []
    }

    /// One tile in the grid.
    struct Item: Identifiable, Hashable, Sendable {
        let entry: SpeciesEntry
        let firstMet: Date
        let lastMet: Date
        let saved: Bool
        let savedAt: Date?
        let liked: Bool
        var id: String { entry.id }
    }

    enum Filter: String, CaseIterable, Identifiable, Sendable {
        case all, saved, liked, extinct
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .saved: "Saved"
            case .liked: "Liked"
            case .extinct: "Extinct"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable, Sendable {
        case recent, firstMet, name, group
        var id: String { rawValue }
        var label: String {
            switch self {
            case .recent: "Recently seen"
            case .firstMet: "First met"
            case .name: "Name (A to Z)"
            case .group: "Group"
            }
        }
    }

    /// Bundled species are looked up in the index, so regenerated data always wins. A stored live
    /// record is used only when the index doesn't know the id. Ids neither knows are dropped.
    static func resolve(_ records: [Record], index: TaxonomyIndex, likedIDs: Set<String>) -> [Item] {
        records.compactMap { r in
            let entry: SpeciesEntry
            if let bundled = index.entry(forSpecies: r.id) {
                entry = bundled
            } else if let live = r.liveSpecies {
                let lineage = r.liveLineageIDs.compactMap { index.node($0) }
                entry = SpeciesEntry(species: live, lineage: lineage)
            } else {
                return nil
            }
            return Item(entry: entry, firstMet: r.firstMet, lastMet: r.lastMet, saved: r.saved,
                        savedAt: r.savedAt, liked: likedIDs.contains(r.id))
        }
    }

    static func filter(_ items: [Item], by filter: Filter) -> [Item] {
        switch filter {
        case .all: items
        case .saved: items.filter(\.saved)
        case .liked: items.filter(\.liked)
        case .extinct: items.filter(\.entry.species.isExtinct)
        }
    }

    /// Stable: ties keep the order they came in. Names compare like Finder does.
    static func sort(_ items: [Item], by sort: Sort) -> [Item] {
        let indexed = Array(items.enumerated())
        func byName(_ a: Item, _ b: Item) -> ComparisonResult {
            a.entry.species.commonName.localizedStandardCompare(b.entry.species.commonName)
        }
        let sorted = indexed.sorted { lhs, rhs in
            let a = lhs.element, b = rhs.element
            switch sort {
            case .recent:
                if a.lastMet != b.lastMet { return a.lastMet > b.lastMet }
            case .firstMet:
                if a.firstMet != b.firstMet { return a.firstMet < b.firstMet }
            case .name:
                let c = byName(a, b)
                if c != .orderedSame { return c == .orderedAscending }
            case .group:
                let ga = a.entry.className ?? "\u{10FFFF}", gb = b.entry.className ?? "\u{10FFFF}"
                let g = ga.localizedStandardCompare(gb)
                if g != .orderedSame { return g == .orderedAscending }
                let c = byName(a, b)
                if c != .orderedSame { return c == .orderedAscending }
            }
            return lhs.offset < rhs.offset
        }
        return sorted.map(\.element)
    }
}
