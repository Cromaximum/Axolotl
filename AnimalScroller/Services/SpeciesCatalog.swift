import Foundation

/// A live species the catalogue found, ready for the picker.
struct LiveCandidate: Hashable, Sendable {
    let entry: SpeciesEntry
    let articleLength: Int
    let wikidataID: String?
    let shortDescription: String?
    let gbifExtinct: Bool?
}

enum CatalogExtinctFilter: Sendable {
    case any, livingOnly, extinctOnly
}

/// Somewhere to find species beyond the bundled list.
protocol SpeciesCatalog: Sendable {
    /// Species under one branch of the bundled tree that are good enough to show.
    /// - Parameter branchPath: bundled nodes from the root down to the branch.
    func candidates(branchPath: [Taxon], filter: CatalogExtinctFilter) async throws -> [LiveCandidate]
    /// Fills in the conservation status of the picked candidate (one extra request, so only for the pick).
    func finalize(_ candidate: LiveCandidate, filter: CatalogExtinctFilter) async -> SpeciesEntry
}

/// The live catalogue: GBIF Backbone Taxonomy for names and classification, English Wikipedia
/// to check each name has a real, well-illustrated article, Wikidata for IUCN status.
///
/// Per call: one GBIF search for a random page of ~40 accepted species under the branch, then one
/// batched Wikipedia query for all 40 names. Two cheap requests usually yield a few good species.
actor LiveSpeciesCatalog: SpeciesCatalog {
    static let shared = LiveSpeciesCatalog()

    private let gbif: GBIFClient
    private let wiki: WikiClient
    /// Bundled taxon id → GBIF key (nil when GBIF has no exact match).
    private var keys: [String: Int?] = [:]
    /// "key|extinctOnly" → number of species GBIF has there.
    private var counts: [String: Int] = [:]

    init(gbif: GBIFClient = GBIFClient(), wiki: WikiClient = WikiClient()) {
        self.gbif = gbif
        self.wiki = wiki
    }

    enum CatalogError: Error { case unknownBranch, emptyBranch }

    func candidates(branchPath: [Taxon], filter: CatalogExtinctFilter) async throws -> [LiveCandidate] {
        guard let branch = branchPath.last, let sci = branch.scientificName else { throw CatalogError.unknownBranch }
        guard let key = try await key(for: branch, scientificName: sci) else { throw CatalogError.unknownBranch }

        let extinctOnly = filter == .extinctOnly
        let countKey = "\(key)|\(extinctOnly)"
        let limit = LiveCatalogRules.batchSize
        let count: Int
        if let cached = counts[countKey] {
            count = cached
        } else {
            count = try await gbif.species(under: key, extinctOnly: extinctOnly, offset: 0, limit: 0).count ?? 0
            counts[countKey] = count
        }
        guard count > 0 else { throw CatalogError.emptyBranch }

        var rng = SystemRandomNumberGenerator()
        let offset = LiveCatalogRules.randomOffset(count: count, limit: limit, using: &rng)
        let page = try await gbif.species(under: key, extinctOnly: extinctOnly, offset: offset, limit: limit)
        let usages = page.results.filter { $0.canonicalName != nil }
        if filter == .livingOnly, usages.allSatisfy({ $0.extinct == true }) { return [] }

        let probes = try await wiki.probeArticles(forNames: usages.compactMap(\.canonicalName))
        let byName = Dictionary(probes.map { ($0.requestedName, $0) }) { a, _ in a }

        return usages.compactMap { usage -> LiveCandidate? in
            guard let name = usage.canonicalName, let probe = byName[name],
                  LiveCatalogRules.accepts(usage, probe: probe), let title = probe.title else { return nil }
            if filter == .livingOnly,
               usage.extinct == true || LiveCatalogRules.looksExtinct(shortDescription: probe.shortDescription) {
                return nil
            }
            let provisional = LiveCatalogRules.resolvedStatus(
                wikidata: nil, gbifExtinct: usage.extinct, shortDescription: probe.shortDescription,
                requestedExtinctOnly: extinctOnly)
            let species = Species(wikiTitle: title,
                                  commonName: LiveCatalogRules.commonName(articleTitle: title),
                                  scientificName: name, status: provisional, gbifKey: usage.key)
            return LiveCandidate(entry: SpeciesEntry(species: species,
                                                     lineage: LiveCatalogRules.lineage(branchPath: branchPath, usage: usage)),
                                 articleLength: probe.length, wikidataID: probe.wikidataID,
                                 shortDescription: probe.shortDescription, gbifExtinct: usage.extinct)
        }
    }

    func finalize(_ candidate: LiveCandidate, filter: CatalogExtinctFilter) async -> SpeciesEntry {
        var wikidata: ConservationStatus?
        if let id = candidate.wikidataID {
            wikidata = try? await wiki.conservationStatus(wikidataID: id)
        }
        let s = candidate.entry.species
        let status = LiveCatalogRules.resolvedStatus(
            wikidata: wikidata, gbifExtinct: candidate.gbifExtinct,
            shortDescription: candidate.shortDescription, requestedExtinctOnly: filter == .extinctOnly)
        let species = Species(wikiTitle: s.wikiTitle, commonName: s.commonName,
                              scientificName: s.scientificName, status: status, gbifKey: s.gbifKey)
        return SpeciesEntry(species: species, lineage: candidate.entry.lineage)
    }

    private func key(for branch: Taxon, scientificName: String) async throws -> Int? {
        if let cached = keys[branch.id] { return cached }
        let key = try await gbif.key(forName: scientificName, rank: branch.rank)
        keys[branch.id] = .some(key)
        return key
    }
}
