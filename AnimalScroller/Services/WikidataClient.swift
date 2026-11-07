import Foundation

/// Reads Wikidata (CC0) statements for a species' intro fact sheet. Raw HTTP only; turning
/// statements into rows is `SpeciesProfileBuilder`'s job.
struct WikidataClient {
    var session: URLSession = .shared
    var userAgent = WikiClient.defaultUserAgent
    private let base = URL(string: "https://www.wikidata.org/w/api.php")!

    /// Item ids per list property worth labelling (the sheet shows at most three).
    static let maxItemsPerProperty = 6

    /// Statements for `SpeciesProfileBuilder.properties` plus English labels of the items they
    /// point to (places, foods, roles). Two requests.
    func profileInput(itemID: String) async throws -> SpeciesProfileBuilder.Input {
        let entity = try await entities([itemID], props: "claims")[itemID]
        var claims: [String: [SpeciesProfileBuilder.Claim]] = [:]
        for property in SpeciesProfileBuilder.properties {
            claims[property] = (entity?.claims?[property] ?? []).map(\.builderClaim)
        }
        var wanted: [String] = []
        for list in claims.values {
            wanted += list.compactMap(\.itemID).prefix(Self.maxItemsPerProperty)
            wanted += list.flatMap(\.roleIDs)
        }
        var labels: [String: String] = [:]
        let ids = Array(Set(wanted)).sorted()
        for start in stride(from: 0, to: ids.count, by: 50) {
            let batch = Array(ids[start..<min(start + 50, ids.count)])
            for (id, item) in try await entities(batch, props: "labels") {
                if let label = item.labels?["en"]?.value { labels[id] = label }
            }
        }
        return .init(wikidataID: itemID, claims: claims, labels: labels)
    }

    private func entities(_ ids: [String], props: String) async throws -> [String: Entity] {
        guard !ids.isEmpty else { return [:] }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "wbgetentities"),
            URLQueryItem(name: "ids", value: ids.joined(separator: "|")),
            URLQueryItem(name: "props", value: props),
            URLQueryItem(name: "languages", value: "en"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw WikiClient.WikiError.badResponse(code) }
        return try JSONDecoder().decode(EntitiesResponse.self, from: data).entities ?? [:]
    }

    // MARK: Response shape (only the parts we read)

    private struct EntitiesResponse: Decodable { let entities: [String: Entity]? }

    private struct Entity: Decodable {
        let claims: [String: [Statement]]?
        let labels: [String: Label]?
        struct Label: Decodable { let value: String }
    }

    private struct Statement: Decodable {
        let rank: String?
        let mainsnak: Snak
        let qualifiers: [String: [Snak]]?

        var builderClaim: SpeciesProfileBuilder.Claim {
            let value = mainsnak.datavalue?.value
            return .init(itemID: value?.id, amount: value?.amount,
                         unitID: value?.unit.flatMap { $0.components(separatedBy: "/").last },
                         roleIDs: (qualifiers?["P3831"] ?? []).compactMap { $0.datavalue?.value?.id },
                         rank: rank ?? "normal")
        }
    }

    private struct Snak: Decodable { let datavalue: DataValue? }

    /// `value` is an object for items and quantities, a string for other types: those decode to nil.
    private struct DataValue: Decodable {
        let value: Value?
        enum CodingKeys: String, CodingKey { case value }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try? container.decode(Value.self, forKey: .value)
        }
    }

    private struct Value: Decodable {
        let id: String?
        let amount: String?
        let unit: String?
    }
}
