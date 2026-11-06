import Foundation

/// Who made a piece of content and under what licence. Every card carries one.
struct Attribution: Hashable, Codable {
    /// Wikipedia article title or Commons file title.
    let title: String
    let author: String?
    /// Short licence name, e.g. "CC BY-SA 4.0" or "Public domain".
    let license: String
    let licenseURL: URL?
    /// Page the content came from (article or file description page).
    let sourceURL: URL

    var shortCredit: String {
        if let author, !author.isEmpty { return "\(author) · \(license)" }
        return license
    }

    static func wikipediaText(title: String, pageURL: URL) -> Attribution {
        Attribution(
            title: title,
            author: "Wikipedia contributors",
            license: "CC BY-SA 4.0",
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/"),
            sourceURL: pageURL
        )
    }
}

struct LicensedImage: Hashable, Codable, Identifiable {
    /// Commons file title, e.g. "File:Snow leopard.jpg".
    let fileTitle: String
    let url: URL
    let width: Int?
    let height: Int?
    let caption: String?
    let attribution: Attribution
    /// Drawing, painting, life restoration, model, etc. rather than a photograph.
    let isArtwork: Bool

    var id: String { fileTitle }
}

/// One full-screen page in the feed.
enum FeedCard: Identifiable, Hashable {
    /// The zoo-sign style board that introduces a species.
    case intro(IntroCard)
    /// A "Did you know?" fact.
    case fact(FactCard)
    case photo(PhotoCard)

    var id: String {
        switch self {
        case .intro(let c): "intro-\(c.entry.id)-\(c.sequence)"
        case .fact(let c): "fact-\(c.entry.id)-\(c.sequence)-\(c.index)"
        case .photo(let c): "photo-\(c.entry.id)-\(c.sequence)-\(c.image.id)"
        }
    }

    var entry: SpeciesEntry {
        switch self {
        case .intro(let c): c.entry
        case .fact(let c): c.entry
        case .photo(let c): c.entry
        }
    }
}

struct IntroCard: Hashable {
    let entry: SpeciesEntry
    /// Position of this species in the session, so the same animal can reappear later.
    let sequence: Int
    /// Wikipedia short description, e.g. "Species of big cat".
    let tagline: String?
    /// Opening sentence(s) of the article.
    let lead: String
    /// Headline fact for the sign's "Did you know?" box.
    let didYouKnow: String?
    let hero: LicensedImage?
    let textAttribution: Attribution
}

struct FactCard: Hashable {
    let entry: SpeciesEntry
    let sequence: Int
    let index: Int
    let total: Int
    /// Section of the article the fact came from, e.g. "Diet", shown as the board heading.
    let topic: String?
    let text: String
    let attribution: Attribution
}

struct PhotoCard: Hashable {
    let entry: SpeciesEntry
    let sequence: Int
    let image: LicensedImage
}
