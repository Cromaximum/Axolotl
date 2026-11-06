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
    /// Fossil, skeleton, mount or other real specimen. Set at ingestion by `ContentPolicy`.
    var isFossil: Bool = false

    var id: String { fileTitle }

    /// Landscape photos that would lose the animal in a portrait crop. Shown whole over a blurred fill (D-010).
    var isWide: Bool {
        guard let width, let height, height > 0 else { return false }
        return Double(width) / Double(height) > 1.15
    }
}

/// What extinct-species media really shows, so the app can say what's real (D-010).
enum MediaTag: Hashable {
    case historicalPhoto
    case realFossil
    case reconstruction

    var label: String {
        switch self {
        case .historicalPhoto: "Historical photo"
        case .realFossil: "Real fossil"
        case .reconstruction: "Reconstruction"
        }
    }

    /// Living species never get a tag: they only ever show photographs.
    static func tag(for image: LicensedImage, species: Species) -> MediaTag? {
        if image.isArtwork { return .reconstruction }
        guard species.isExtinct else { return nil }
        if image.isFossil { return .realFossil }
        return .historicalPhoto
    }
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

    /// Where this card sits in its species set, e.g. card 2 of 7.
    var placement: CardPlacement {
        switch self {
        case .intro(let c): c.placement
        case .fact(let c): c.placement
        case .photo(let c): c.placement
        }
    }

    /// The same card with its place in the set filled in. `FeedViewModel` stamps each set.
    func placed(_ placement: CardPlacement) -> FeedCard {
        switch self {
        case .intro(var c): c.placement = placement; return .intro(c)
        case .fact(var c): c.placement = placement; return .fact(c)
        case .photo(var c): c.placement = placement; return .photo(c)
        }
    }

    /// The photo this card shows: hero, fact photo or the photo itself. Used for image
    /// prefetch and for the image saved with a like or a save.
    var primaryImage: LicensedImage? {
        switch self {
        case .intro(let c): c.hero
        case .fact(let c): c.image
        case .photo(let c): c.image
        }
    }
}

/// Position of a card in its species set (1-based) and the set's size.
struct CardPlacement: Hashable {
    let position: Int
    let count: Int

    /// Default before the feed stamps a set.
    static let single = CardPlacement(position: 1, count: 1)
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
    var placement: CardPlacement = .single
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
    /// Photo kept above the fact board so the animal stays in view (D-010).
    let image: LicensedImage?
    var placement: CardPlacement = .single
}

struct PhotoCard: Hashable {
    let entry: SpeciesEntry
    let sequence: Int
    let image: LicensedImage
    var placement: CardPlacement = .single
}
