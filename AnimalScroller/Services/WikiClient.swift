import Foundation

/// Talks to English Wikipedia's public APIs. No API key is needed, but Wikimedia
/// asks every client to send a descriptive User-Agent with a way to reach the developer.
/// https://meta.wikimedia.org/wiki/User-Agent_policy
struct WikiClient {
    var session: URLSession = .shared
    // TODO: replace the contact URL with a real support page or email before release.
    var userAgent = "AnimalScroller/0.1 (https://github.com/Cromaximum; iOS app)"

    private let restBase = URL(string: "https://en.wikipedia.org/api/rest_v1")!
    private let actionBase = URL(string: "https://en.wikipedia.org/w/api.php")!

    enum WikiError: Error { case badResponse(Int), notFound(String) }

    // MARK: Summary (lead text, short description, main image)

    struct Summary: Decodable {
        let title: String
        let description: String?
        let extract: String
        let originalimage: ImageRef?
        let contentURLs: ContentURLs?

        struct ImageRef: Decodable { let source: URL; let width: Int; let height: Int }
        struct ContentURLs: Decodable {
            let desktop: Page
            struct Page: Decodable { let page: URL }
        }

        enum CodingKeys: String, CodingKey {
            case title, description, extract, originalimage
            case contentURLs = "content_urls"
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

    func images(onArticle title: String, limit: Int = 40, thumbWidth: Int = 1080) async throws -> [ImageInfo] {
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
