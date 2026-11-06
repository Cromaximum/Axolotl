import Foundation

/// Talks to the GBIF species API (https://techdocs.gbif.org/en/openapi/v1/species).
/// The GBIF Backbone Taxonomy is our master species list: about 2.5 million accepted names,
/// built on the Catalogue of Life plus other expert checklists, with one clean
/// kingdom › phylum › class › order › family › genus classification per species, and a free,
/// keyless API. Licence: CC BY 4.0 (credited on the species detail sheet).
///
/// We only use names and classification from GBIF. We deliberately do NOT use GBIF's
/// `iucnRedListCategory` endpoint: the IUCN Red List data behind it is licensed for
/// non-commercial use only, and the app runs ads (D-007). Conservation status comes from
/// Wikidata (CC0) instead.
struct GBIFClient: Sendable {
    var session: URLSession = .shared
    var userAgent = WikiClient.defaultUserAgent

    /// GBIF Backbone Taxonomy dataset.
    static let backboneDatasetKey = "d7dddbf4-2cf0-4f39-9b2a-bb099caae36c"
    /// GBIF search refuses offsets beyond this window.
    static let maxSearchWindow = 100_000

    private let base = URL(string: "https://api.gbif.org/v1")!

    enum GBIFError: Error { case badResponse(Int) }

    /// One accepted name from the backbone.
    struct NameUsage: Decodable, Hashable, Sendable {
        let key: Int
        let scientificName: String?
        /// Name without author, e.g. "Panthera uncia".
        let canonicalName: String?
        let rank: String?
        let taxonomicStatus: String?
        let kingdom: String?
        let phylum: String?
        let `class`: String?
        let order: String?
        let family: String?
        let genus: String?
        /// Present only when a source checklist recorded it.
        let extinct: Bool?

        init(key: Int, canonicalName: String?, rank: String? = "SPECIES", taxonomicStatus: String? = "ACCEPTED",
             kingdom: String? = "Animalia", phylum: String? = nil, class cls: String? = nil, order: String? = nil,
             family: String? = nil, genus: String? = nil, extinct: Bool? = nil) {
            self.key = key
            self.scientificName = canonicalName
            self.canonicalName = canonicalName
            self.rank = rank
            self.taxonomicStatus = taxonomicStatus
            self.kingdom = kingdom
            self.phylum = phylum
            self.class = cls
            self.order = order
            self.family = family
            self.genus = genus
            self.extinct = extinct
        }

        /// Classification name at a rank, if GBIF has one.
        func name(at rank: Taxon.Rank) -> String? {
            switch rank {
            case .kingdom: kingdom
            case .phylum: phylum
            case .class: self.class
            case .order: order
            case .family: family
            case .genus: genus
            }
        }
    }

    struct SearchPage: Decodable, Sendable {
        let count: Int?
        let results: [NameUsage]
    }

    private struct Match: Decodable {
        let usageKey: Int?
        let matchType: String?
    }

    /// Backbone key for a higher taxon such as "Felidae" (family), or nil if GBIF has no exact match.
    func key(forName name: String, rank: Taxon.Rank) async throws -> Int? {
        let match = try await get("species/match", [
            "name": name, "rank": rank.rawValue.uppercased(), "kingdom": "Animalia", "strict": "true",
        ], as: Match.self)
        guard let type = match.matchType, type != "NONE", type != "HIGHERRANK" else { return nil }
        return match.usageKey
    }

    /// Accepted species under a higher taxon. Pass `limit: 0` to read only `count`.
    /// - Parameter extinctOnly: true asks GBIF for species flagged extinct. We never ask for
    ///   `isExtinct=false`, because most living species carry no flag at all.
    func species(under higherTaxonKey: Int, extinctOnly: Bool, offset: Int, limit: Int) async throws -> SearchPage {
        var params = [
            "datasetKey": Self.backboneDatasetKey,
            "highertaxonKey": String(higherTaxonKey),
            "rank": "SPECIES",
            "status": "ACCEPTED",
            "offset": String(offset),
            "limit": String(limit),
        ]
        if extinctOnly { params["isExtinct"] = "true" }
        return try await get("species/search", params, as: SearchPage.self)
    }

    private func get<T: Decodable>(_ path: String, _ params: [String: String], as type: T.Type) async throws -> T {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw GBIFError.badResponse(code) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
