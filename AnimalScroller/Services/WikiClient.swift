import Foundation

/// Talks to English Wikipedia's public APIs. No API key is needed, but Wikimedia
/// asks every client to send a descriptive User-Agent with a way to reach the developer.
/// https://meta.wikimedia.org/wiki/User-Agent_policy
struct WikiClient {
    var session: URLSession = .shared
    // TODO: replace the contact URL with a real support page or email before release.
    var userAgent = WikiClient.defaultUserAgent
    static let defaultUserAgent = "AnimalScroller/0.1 (https://github.com/Cromaximum; iOS app)"

    private let restBase = URL(string: "https://en.wikipedia.org/api/rest_v1")!
    private let actionBase = URL(string: "https://en.wikipedia.org/w/api.php")!
    private let wikidataBase = URL(string: "https://www.wikidata.org/w/api.php")!

    enum WikiError: Error { case badResponse(Int), notFound(String) }

    // MARK: Summary (lead text, short description, main image)

    struct Summary: Decodable {
        let title: String
        let description: String?
        let extract: String
        let originalimage: ImageRef?
        let contentURLs: ContentURLs?
        /// Wikidata item of the article, e.g. "Q30197", for the intro fact sheet.
        let wikibaseItem: String?

        struct ImageRef: Decodable { let source: URL; let width: Int; let height: Int }
        struct ContentURLs: Decodable {
            let desktop: Page
            struct Page: Decodable { let page: URL }
        }

        enum CodingKeys: String, CodingKey {
            case title, description, extract, originalimage
            case contentURLs = "content_urls"
            case wikibaseItem = "wikibase_item"
        }

        var pageURL: URL {
            contentURLs?.desktop.page
                ?? URL(string: "https://en.wikipedia.org/wiki/\(title.replacingOccurrences(of: " ", with: "_"))")!
        }
    }

    func summary(title: String) async throws -> Summary {
        let encoded = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? title
        guard let url = URL(string: restBase.absoluteString + "/page/summary/" + encoded) else {
            throw WikiError.notFound(title)
        }
        return try await get(url, as: Summary.self)
    }

    // MARK: Full plain-text article (for fact extraction)

    func plainTextArticle(title: String) async throws -> String {
        let response = try await action(Self.ExtractResponse.self, [
            "action": "query", "prop": "extracts", "titles": title,
            "explaintext": "1", "exsectionformat": "wiki", "redirects": "1",
        ])
        guard let text = response.query.pages.first?.extract else { throw WikiError.notFound(title) }
        return text
    }

    private struct ExtractResponse: Decodable {
        let query: Query
        struct Query: Decodable { let pages: [Page] }
        struct Page: Decodable { let title: String; let extract: String? }
    }

    // MARK: Images used on the article, with licence metadata

    struct ImageInfo {
        let fileTitle: String
        let url: URL
        let width: Int?
        let height: Int?
        let mime: String
        let descriptionURL: URL
        let licenseShortName: String?
        let licenseURL: URL?
        let artistHTML: String?
        let descriptionHTML: String?
    }

    func images(onArticle title: String, limit: Int = 40,
                thumbWidth: Int = ImageSizing.wikimediaThumbWidth) async throws -> [ImageInfo] {
        let response = try await action(ImagesResponse.self, [
            "action": "query", "generator": "images", "titles": title, "redirects": "1",
            "gimlimit": String(limit),
            "prop": "imageinfo", "iiprop": "url|mime|size|extmetadata",
            "iiurlwidth": String(thumbWidth),
            "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|ImageDescription|UsageTerms",
        ])
        return (response.query?.pages ?? []).compactMap { page in
            guard let info = page.imageinfo?.first else { return nil }
            let meta = info.extmetadata ?? [:]
            return ImageInfo(
                fileTitle: page.title,
                url: info.thumburl ?? info.url,
                width: info.thumbwidth ?? info.width,
                height: info.thumbheight ?? info.height,
                mime: info.mime ?? "",
                descriptionURL: info.descriptionurl,
                licenseShortName: meta["LicenseShortName"]?.value,
                licenseURL: meta["LicenseUrl"]?.value.flatMap(URL.init(string:)),
                artistHTML: meta["Artist"]?.value,
                descriptionHTML: meta["ImageDescription"]?.value
            )
        }
    }

    private struct ImagesResponse: Decodable {
        let query: Query?
        struct Query: Decodable { let pages: [Page] }
        struct Page: Decodable { let title: String; let imageinfo: [Info]? }
        struct Info: Decodable {
            let url: URL
            let thumburl: URL?
            let width: Int?, height: Int?
            let thumbwidth: Int?, thumbheight: Int?
            let mime: String?
            let descriptionurl: URL
            let extmetadata: [String: MetaValue]?
        }
        /// extmetadata values are usually strings but occasionally numbers; tolerate both.
        struct MetaValue: Decodable {
            let value: String?
            enum CodingKeys: String, CodingKey { case value }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                if let s = try? c.decode(String.self, forKey: .value) { value = s }
                else if let n = try? c.decode(Double.self, forKey: .value) { value = String(n) }
                else { value = nil }
            }
        }
    }

    // MARK: Batch article check (live species catalogue)

    /// What English Wikipedia has for one scientific name, after following redirects.
    struct ArticleProbe: Hashable, Sendable {
        /// The name we asked about, e.g. "Panthera uncia".
        let requestedName: String
        /// Final article title after redirects, e.g. "Snow leopard". Nil when there is no article.
        let title: String?
        let wasRedirected: Bool
        /// Article size in bytes; a cheap proxy for how well covered (and well known) the species is.
        let length: Int
        /// Lead image file name, set only when that image is freely licensed (on Commons).
        let freeImage: String?
        let shortDescription: String?
        let wikidataID: String?
        let isDisambiguation: Bool
    }

    /// Looks up to 50 scientific names in one request. Names with no article come back with a nil title.
    func probeArticles(forNames names: [String]) async throws -> [ArticleProbe] {
        let batch = Array(names.prefix(50))
        guard !batch.isEmpty else { return [] }
        let response = try await action(ProbeResponse.self, [
            "action": "query", "titles": batch.joined(separator: "|"), "redirects": "1",
            "prop": "pageprops|info",
            "ppprop": "page_image_free|wikibase_item|wikibase-shortdesc|disambiguation",
        ])
        let query = response.query
        let normalized = Dictionary((query?.normalized ?? []).map { ($0.from, $0.to) }) { a, _ in a }
        let redirects = Dictionary((query?.redirects ?? []).map { ($0.from, $0.to) }) { a, _ in a }
        let pages = Dictionary((query?.pages ?? []).map { ($0.title, $0) }) { a, _ in a }
        return batch.map { name in
            let normal = normalized[name] ?? name
            let target = redirects[normal] ?? normal
            guard let page = pages[target], page.missing != true, page.invalid != true else {
                return ArticleProbe(requestedName: name, title: nil, wasRedirected: false, length: 0,
                                    freeImage: nil, shortDescription: nil, wikidataID: nil, isDisambiguation: false)
            }
            let props = page.pageprops ?? [:]
            return ArticleProbe(requestedName: name, title: page.title, wasRedirected: redirects[normal] != nil,
                                length: page.length ?? 0, freeImage: props["page_image_free"],
                                shortDescription: props["wikibase-shortdesc"], wikidataID: props["wikibase_item"],
                                isDisambiguation: props["disambiguation"] != nil)
        }
    }

    private struct ProbeResponse: Decodable {
        let query: Query?
        struct Query: Decodable {
            let normalized: [FromTo]?
            let redirects: [FromTo]?
            let pages: [Page]?
        }
        struct FromTo: Decodable { let from: String; let to: String }
        struct Page: Decodable {
            let title: String
            let missing: Bool?
            let invalid: Bool?
            let length: Int?
            let pageprops: [String: String]?
        }
    }

    // MARK: Conservation status from Wikidata (CC0)

    /// IUCN status (Wikidata property P141) of a Wikidata item, e.g. "Q30197" → .vulnerable.
    func conservationStatus(wikidataID: String) async throws -> ConservationStatus? {
        var components = URLComponents(url: wikidataBase, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "wbgetclaims"),
            URLQueryItem(name: "entity", value: wikidataID),
            URLQueryItem(name: "property", value: "P141"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let response = try await get(components.url!, as: ClaimsResponse.self)
        let claims = response.claims?["P141"] ?? []
        let best = claims.first { $0.rank == "preferred" } ?? claims.first { $0.rank != "deprecated" }
        return best?.mainsnak.datavalue?.value.id.flatMap(LiveCatalogRules.status(wikidataItem:))
    }

    private struct ClaimsResponse: Decodable {
        let claims: [String: [Claim]]?
        struct Claim: Decodable {
            let rank: String?
            let mainsnak: Snak
        }
        struct Snak: Decodable { let datavalue: DataValue? }
        struct DataValue: Decodable {
            let value: ItemValue
            struct ItemValue: Decodable { let id: String? }
        }
    }

    // MARK: Plumbing

    private func action<T: Decodable>(_ type: T.Type, _ params: [String: String]) async throws -> T {
        var components = URLComponents(url: actionBase, resolvingAgainstBaseURL: false)!
        components.queryItems = (params.merging(["format": "json", "formatversion": "2", "origin": "*"]) { a, _ in a })
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await get(components.url!, as: type)
    }

    private func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw WikiError.badResponse(code) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
