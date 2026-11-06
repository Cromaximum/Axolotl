import Foundation

/// Fast lookups over the bundled tree of life, built once in `RootView` and passed down.
///
/// Pure logic, no I/O: node and species lookup by id, the path down to a node, species counts per
/// branch, how a node relates to the current selection, a selection summary, and name search.
/// Everything is computed once in `init`, so list rows don't walk the tree on every redraw.
struct TaxonomyIndex: Sendable {
    /// How a tree node relates to the user's selection.
    enum SelectionState: Hashable, Sendable {
        case unselected
        case selected
        /// Included because an ancestor branch is selected.
        case covered(byID: String)
        /// Not selected itself, but some branch beneath it is.
        case partial
    }

    /// One search result. A species hit selects the branch it sits in (its genus or family).
    struct SearchHit: Identifiable, Hashable, Sendable {
        enum Kind: Hashable, Sendable { case taxon(Taxon.Rank), species }
        let id: String
        let name: String
        let scientificName: String?
        let kind: Kind
        /// Tree nodes above the hit, from the root down.
        let ancestors: [Taxon]
        /// The node a tap toggles: the taxon itself, or the species' closest branch.
        let branchID: String
    }

    private struct Node: Sendable {
        let taxon: Taxon
        let parentID: String?
        /// Pre-order position, for listing things in tree order.
        let order: Int
        let speciesCount: Int
    }

    let root: Taxon
    private var nodes: [String: Node] = [:]
    private var species: [String: SpeciesEntry] = [:]
    /// Species ids in tree order.
    private var speciesOrder: [String] = []

    init(root: Taxon) {
        self.root = root
        var order = 0
        index(root, parentID: nil, ancestors: [], order: &order)
    }

    @discardableResult
    private mutating func index(_ taxon: Taxon, parentID: String?, ancestors: [Taxon], order: inout Int) -> Int {
        let myOrder = order
        order += 1
        let path = ancestors + [taxon]
        var count = 0
        for s in taxon.species ?? [] where species[s.id] == nil {
            species[s.id] = SpeciesEntry(species: s, lineage: path)
            speciesOrder.append(s.id)
            count += 1
        }
        for child in taxon.children ?? [] {
            count += index(child, parentID: taxon.id, ancestors: path, order: &order)
        }
        nodes[taxon.id] = Node(taxon: taxon, parentID: parentID, order: myOrder, speciesCount: count)
        return count
    }

    // MARK: Lookup

    var totalSpecies: Int { speciesOrder.count }
    var speciesIDs: Set<String> { Set(speciesOrder) }

    func node(_ id: String) -> Taxon? { nodes[id]?.taxon }
    func entry(forSpecies id: String) -> SpeciesEntry? { species[id] }
    func speciesCount(_ id: String) -> Int { nodes[id]?.speciesCount ?? 0 }

    /// Nodes from the root down to `id`, inclusive. Empty when the id is unknown.
    func path(to id: String) -> [Taxon] {
        var out: [Taxon] = []
        var current: String? = id
        while let c = current, let node = nodes[c] {
            out.append(node.taxon)
            current = node.parentID
        }
        return out.reversed()
    }

    /// Ancestor ids of a node, nearest first, not including the node.
    private func ancestorIDs(of id: String) -> [String] {
        var out: [String] = []
        var current = nodes[id]?.parentID
        while let c = current {
            out.append(c)
            current = nodes[c]?.parentID
        }
        return out
    }

    // MARK: Selection

    func state(of id: String, selection: Set<String>) -> SelectionState {
        if selection.contains(id) { return .selected }
        if let covering = ancestorIDs(of: id).first(where: { selection.contains($0) }) { return .covered(byID: covering) }
        if selection.contains(where: { ancestorIDs(of: $0).contains(id) }) { return .partial }
        return .unselected
    }

    /// Species the selection covers. An empty selection means everything.
    func speciesCount(selection: Set<String>) -> Int {
        guard !selection.isEmpty else { return totalSpecies }
        return speciesOrder.reduce(0) { n, id in
            n + (selection.isDisjoint(with: species[id]?.lineageIDs ?? []) ? 0 : 1)
        }
    }

    /// The selected branches that still exist in the tree, in tree order.
    func summary(selection: Set<String>) -> [Taxon] {
        selection.compactMap { nodes[$0] }.sorted { $0.order < $1.order }.map(\.taxon)
    }

    // MARK: Search

    /// Nodes and species whose common or scientific name matches `query`, best matches first.
    /// Case and accent insensitive. Exact names rank first, then name prefixes, then word
    /// prefixes, then any substring. Ties go to branches before species, then tree order.
    func search(_ query: String, limit: Int = 50) -> [SearchHit] {
        let q = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return [] }

        var scored: [(score: Int, isSpecies: Bool, order: Int, hit: SearchHit)] = []
        for node in nodes.values where node.parentID != nil {
            let t = node.taxon
            guard let score = Self.score(q, names: [t.name, t.scientificName]) else { continue }
            let hit = SearchHit(id: t.id, name: t.name, scientificName: t.scientificName, kind: .taxon(t.rank),
                                ancestors: Array(path(to: t.id).dropLast()), branchID: t.id)
            scored.append((score, false, node.order, hit))
        }
        for (i, id) in speciesOrder.enumerated() {
            guard let entry = species[id], let branch = entry.lineage.last,
                  let score = Self.score(q, names: [entry.species.commonName, entry.species.scientificName])
            else { continue }
            let hit = SearchHit(id: "species:\(id)", name: entry.species.commonName,
                                scientificName: entry.species.scientificName, kind: .species,
                                ancestors: entry.lineage, branchID: branch.id)
            scored.append((score, true, i, hit))
        }
        return scored
            .sorted { ($0.score, $0.isSpecies ? 1 : 0, $0.order) < ($1.score, $1.isSpecies ? 1 : 0, $1.order) }
            .prefix(limit)
            .map(\.hit)
    }

    /// Lower is better; nil means no match.
    static func score(_ foldedQuery: String, names: [String?]) -> Int? {
        names.compactMap { name -> Int? in
            guard let name else { return nil }
            let n = fold(name)
            if n == foldedQuery { return 0 }
            if n.hasPrefix(foldedQuery) { return 1 }
            let words = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            if words.contains(where: { $0.hasPrefix(foldedQuery) }) { return 2 }
            if n.contains(foldedQuery) { return 3 }
            return nil
        }.min()
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
