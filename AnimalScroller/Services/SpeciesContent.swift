import Foundation

/// Everything the feed needs to know about one species, independent of where it came from.
/// Phase 1 fetches it live from Wikipedia; the concept deck's prebuilt static JSON per
/// species can drop in later as another `SpeciesContentProvider` with the same shape.
struct SpeciesContent: Codable, Hashable {
    let title: String
    let tagline: String?
    let lead: String
    let pageURL: URL
    /// Commons file title of the article's main image, if any.
    let leadImageFileTitle: String?
    let facts: [FactExtractor.Fact]
    let images: [LicensedImage]
}

protocol SpeciesContentProvider: Sendable {
    func content(for species: Species) async throws -> SpeciesContent
}

/// Fetches content live from Wikipedia and Wikimedia Commons and caches it in memory.
actor WikipediaContentProvider: SpeciesContentProvider {
    private let client: WikiClient
    private var cache: [String: SpeciesContent] = [:]

    /// One shared cache for the feed, onboarding tiles and detail sheets.
    static let shared = WikipediaContentProvider()

    init(client: WikiClient = WikiClient()) { self.client = client }

    func content(for species: Species) async throws -> SpeciesContent {
        if let hit = cache[species.wikiTitle] { return hit }

        async let summary = client.summary(title: species.wikiTitle)
        async let article = client.plainTextArticle(title: species.wikiTitle)
        async let imageInfos = client.images(onArticle: species.wikiTitle)

        let s = try await summary
        // A missing article body or image list shouldn't sink the whole species.
        let text = (try? await article) ?? ""
        let infos = (try? await imageInfos) ?? []

        let content = SpeciesContent(
            title: s.title,
            tagline: s.description,
            lead: Self.lead(from: s.extract),
            pageURL: s.pageURL,
            leadImageFileTitle: s.originalimage.map { Self.fileTitle(fromUploadURL: $0.source) },
            facts: FactExtractor.facts(from: text),
            images: ContentPolicy.licensedImages(from: infos)
        )
        cache[species.wikiTitle] = content
        return content
    }

    /// First one or two sentences, kept short enough for the sign.
    static func lead(from extract: String) -> String {
        let sentences = FactExtractor.sentences(in: extract)
        var out = ""
        for s in sentences {
            if out.isEmpty || out.count + s.count < 260 { out += (out.isEmpty ? "" : " ") + s } else { break }
        }
        return out
    }

    /// ".../commons/a/ab/Snow_leopard_portrait.jpg" → "File:Snow leopard portrait.jpg"
    static func fileTitle(fromUploadURL url: URL) -> String {
        let name = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        return "File:" + name.replacingOccurrences(of: "_", with: " ")
    }
}
