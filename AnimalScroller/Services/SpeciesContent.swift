import Foundation

/// Everything the feed needs to know about one species, independent of where it came from.
/// Phase 1 fetches it live from Wikipedia; the concept deck's prebuilt static JSON per
/// species can drop in later as another `SpeciesContentProvider` with the same shape.
/// Also the on-disk cache format (`ContentCachePolicy.Entry`): change it, bump the schema.
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

/// Fetches content live from Wikipedia and Wikimedia Commons. Caching (memory, disk, shared
/// in-flight fetches) is `CachingContentProvider`'s job; `App/` wraps this provider in one.
struct WikipediaContentProvider: SpeciesContentProvider {
    private let client: WikiClient

    init(client: WikiClient) { self.client = client }

    func content(for species: Species) async throws -> SpeciesContent
}

/// Fetches content live from Wikipedia and Wikimedia Commons. Caching (memory, disk, shared
/// in-flight fetches) is `CachingContentProvider`'s job; `App/` wraps this provider in one.
struct WikipediaContentProvider: SpeciesContentProvider {
    private let client: WikiClient

    init(client: WikiClient) { self.client = client }

    /// Transitional: `OnboardingView` and `SpeciesDetailView` still reach for this until W3 moves
    /// them to the injected `speciesContentProvider` (Phase 1.5 W3 step 4). It shares the disk
    /// cache folder with the app's provider. Delete it right after W3's switch lands.
    @available(*, deprecated, message: "Use the injected speciesContentProvider environment value.")
    static let shared: any SpeciesContentProvider = CachingContentProvider(
        upstream: WikipediaContentProvider(client: WikiClient()),
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            .flatMap { CachingContentProvider.prepareDirectory(in: $0, fileManager: .default) })

    func content(for species: Species) async throws -> SpeciesContent {
        async let summary = client.summary(title: species.wikiTitle)
        async let article = client.plainTextArticle(title: species.wikiTitle)
        async let imageInfos = client.images(onArticle: species.wikiTitle)

        let s = try await summary
        // A missing article body or image list shouldn't sink the whole species.
        let text = (try? await article) ?? ""
        let infos = (try? await imageInfos) ?? []

        let leadImage = s.originalimage.map { Self.fileTitle(fromUploadURL: $0.source) }
        return SpeciesContent(
            title: s.title,
            tagline: s.description,
            lead: Self.lead(from: s.extract),
            pageURL: s.pageURL,
            leadImageFileTitle: leadImage,
            facts: FactExtractor.facts(from: text),
            // Best photos first (PhotoQuality); the feed uses them in this order.
            images: ContentPolicy.licensedImages(
                from: infos, leadFileTitle: leadImage,
                subjectNames: [species.scientificName, species.commonName, s.title])
        )
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
