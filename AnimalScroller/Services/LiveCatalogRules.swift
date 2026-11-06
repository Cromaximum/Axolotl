import Foundation

/// Pure rules for the live species catalogue: which GBIF species are good enough to show,
/// how they slot into the tree of life, and how their names and statuses are sourced.
/// No I/O here, so every rule is unit-tested (`LiveCatalogTests`).
///
/// Zero AI content (D-011): every value a live species shows comes straight from a source.
/// Common name = English Wikipedia article title. Scientific name and lineage = GBIF Backbone.
/// IUCN status = Wikidata P141. Nothing is written or guessed by the app.
enum LiveCatalogRules {
    /// Articles shorter than this are usually stubs with too little to make fact cards from.
    static let minArticleLength = 5_000
    /// How many GBIF names we check against Wikipedia per request (Wikipedia allows 50).
    static let batchSize = 40

    /// Should a GBIF species become a feed candidate, given what Wikipedia has for it?
    static func accepts(_ usage: GBIFClient.NameUsage, probe: WikiClient.ArticleProbe) -> Bool {
        guard usage.rank == nil || usage.rank == "SPECIES",
              usage.taxonomicStatus == nil || usage.taxonomicStatus == "ACCEPTED",
              usage.kingdom == nil || usage.kingdom == "Animalia",
              let title = probe.title, !probe.isDisambiguation,
              probe.freeImage != nil,
              probe.length >= minArticleLength
        else { return false }
        // Rule 1: one specific species. A species name that redirects to its genus or family
        // article (common for poorly known species) would show a broad group instead.
        if probe.wasRedirected {
            let groupNames = [usage.genus, usage.family, usage.order].compactMap { $0?.lowercased() }
            let bare = baseTitle(title).lowercased()
            if groupNames.contains(bare) { return false }
            if bare.hasPrefix("list of") { return false }
        }
        if let desc = probe.shortDescription?.lowercased(),
           desc.hasPrefix("genus") || desc.hasPrefix("family") || desc.contains("disambiguation") {
            return false
        }
        return true
    }

    /// The common name we show: the English Wikipedia article title, minus any disambiguator
    /// ("Kakapo", "Puma (animal)" → "Puma"). When the article is titled with the scientific name,
    /// that's what we show; we never invent a common name.
    static func commonName(articleTitle: String) -> String {
        baseTitle(articleTitle)
    }

    static func baseTitle(_ title: String) -> String {
        guard let open = title.range(of: " ("), title.hasSuffix(")") else { return title }
        return String(title[..<open.lowerBound])
    }

    /// Wikipedia's own short description sometimes marks fossil species ("Extinct species of
    /// shark"). Only a *filter* signal (keeps fossils out of "Living only"); never shown as a status.
    static func looksExtinct(shortDescription: String?) -> Bool {
        guard let d = shortDescription?.lowercased() else { return false }
        return d.contains("extinct") || d.contains("fossil") || d.contains("prehistoric")
    }

    /// Wikidata items for the IUCN categories (values of property P141).
    static func status(wikidataItem id: String) -> ConservationStatus? {
        switch id {
        case "Q211005": .leastConcern
        case "Q719675": .nearThreatened
        case "Q278113": .vulnerable
        // Wikidata has two items for Endangered; most species use the newer Q96377276.
        case "Q11394", "Q96377276": .endangered
        case "Q219127": .criticallyEndangered
        case "Q239509": .extinctInWild
        case "Q237350": .extinct
        case "Q3245245": .dataDeficient
        default: nil
        }
    }

    /// Status shown on the IUCN bar. Only sourced values: Wikidata P141 first, then GBIF's extinct
    /// flag (on the record, or because we asked GBIF for `isExtinct=true`). Otherwise Not Evaluated.
    /// Never derived from keywords (D-011).
    static func resolvedStatus(wikidata: ConservationStatus?, gbifExtinct: Bool?,
                               requestedExtinctOnly: Bool) -> ConservationStatus {
        if let wikidata { return wikidata }
        if gbifExtinct == true || requestedExtinctOnly { return .extinct }
        return .notEvaluated
    }

    /// Live species weren't reviewed by a person, so their content must carry at least one image
    /// the card may show and two facts, or the species is skipped. Bundled species always show.
    static func isShowable(_ content: SpeciesContent, species: Species, allowArtwork: Bool) -> Bool {
        guard species.isLive else { return true }
        let usable = content.images.filter { !$0.isArtwork || (species.isExtinct && allowArtwork) }
        return !usable.isEmpty && content.facts.count >= 2
    }

    /// Lineage for a live species: the bundled path down to the branch we searched, then any
    /// bundled descendants that match GBIF's classification, then GBIF-only nodes (shown by
    /// scientific name) for the remaining ranks down to genus.
    static func lineage(branchPath: [Taxon], usage: GBIFClient.NameUsage) -> [Taxon] {
        guard var current = branchPath.last else { return [] }
        var path = branchPath
        for rank in Taxon.Rank.allCases where rank.depth > current.rank.depth {
            guard let name = usage.name(at: rank), !name.isEmpty else { continue }
            if let sub = current.path(toDescendant: { $0.rank == rank && $0.scientificName?.lowercased() == name.lowercased() }) {
                path += sub
                current = sub.last!
            } else {
                let node = Taxon(id: syntheticID(rank: rank, name: name), name: name, scientificName: name,
                                 rank: rank, children: nil, species: nil)
                path.append(node)
                current = node
            }
        }
        return path
    }

    /// Stable id for a taxon that isn't in the bundled tree, so likes and dwell time on it
    /// still count across sessions.
    static func syntheticID(rank: Taxon.Rank, name: String) -> String {
        "gbif-\(rank.rawValue)-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    /// Bundled tree nodes worth searching GBIF under. Kingdom and phylum are too broad: a random
    /// page of arthropods is nearly all beetles with no Wikipedia article.
    static func searchableBranches(in root: Taxon) -> [Taxon] {
        var out: [Taxon] = []
        func walk(_ t: Taxon) {
            if t.rank.depth >= Taxon.Rank.class.depth, t.scientificName != nil { out.append(t) }
            t.children?.forEach(walk)
        }
        walk(root)
        return out
    }

    /// Splits branches into those inside the user's selection (tailored) and the rest (discovery).
    /// Ancestors of a selected node are left out of both so discovery never lands back inside it.
    static func split(branches: [Taxon], root: Taxon, selectedIDs: Set<String>) -> (inside: [Taxon], outside: [Taxon]) {
        guard !selectedIDs.isEmpty else { return (branches, []) }
        var inside: [Taxon] = [], outside: [Taxon] = []
        for b in branches {
            let lineage = root.path(to: b.id)?.map(\.id) ?? [b.id]
            if !selectedIDs.isDisjoint(with: lineage) {
                inside.append(b)
            } else if !selectedIDs.contains(where: { b.descendantIDs.contains($0) }) {
                outside.append(b)
            }
        }
        // A selected kingdom or phylum has no searchable node of its own; its children cover it.
        return (inside, outside)
    }

    /// A random page offset within GBIF's search window.
    static func randomOffset<R: RandomNumberGenerator>(count: Int, limit: Int, using rng: inout R) -> Int {
        let window = min(count, GBIFClient.maxSearchWindow)
        guard window > limit else { return 0 }
        return Int.random(in: 0...(window - limit), using: &rng)
    }

    /// Popularity weight from article length: longer articles are usually better-known species.
    static func popularity(articleLength: Int) -> Double {
        min(max(Double(articleLength) / Double(minArticleLength), 1).squareRoot(), 4)
    }
}

extension Taxon.Rank: CaseIterable {
    static var allCases: [Taxon.Rank] { [.kingdom, .phylum, .class, .order, .family, .genus] }

    /// 0 for kingdom, 5 for genus.
    var depth: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

extension Taxon {
    /// Nodes from the root to the node with this id, inclusive.
    func path(to id: String) -> [Taxon]? {
        if self.id == id { return [self] }
        for child in children ?? [] {
            if let sub = child.path(to: id) { return [self] + sub }
        }
        return nil
    }

    /// Nodes below this one (not including it) down to the first descendant matching `predicate`.
    func path(toDescendant predicate: (Taxon) -> Bool) -> [Taxon]? {
        for child in children ?? [] {
            if predicate(child) { return [child] }
            if let sub = child.path(toDescendant: predicate) { return [child] + sub }
        }
        return nil
    }
}
