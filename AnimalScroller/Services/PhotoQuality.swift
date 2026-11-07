import Foundation

/// Ranks a species' freely licensed Commons photos so the feed leads with the best ones:
/// big originals, portrait or near-portrait frames that fill a phone screen, close-ups where the
/// animal is clearly the subject, and photos the Commons community has assessed (Featured,
/// Quality, Valued, Picture of the Year). Also picks which Wikimedia rendition to download so the
/// photo is sharp full screen. Pure logic; `ContentPolicy.licensedImages` calls it at ingestion.
///
/// Licences, junk filtering and artwork labelling stay in `ContentPolicy`: a score only reorders
/// photos that are already allowed.
enum PhotoQuality {

    // MARK: Screen

    /// Pixel size of the largest iPhone screen (6.9", 1320 × 2868), portrait.
    static let screenPixelWidth = 1320
    static let screenPixelHeight = ImageSizing.fullScreenPixelSize

    /// Wider than this (width / height) and `FullBleedImage` shows the photo whole over a blurred
    /// fill instead of cropping it to fill the screen. Same value as `LicensedImage.isWide`.
    static let wideRatio = 1.15

    // MARK: Size thresholds (on the original file's pixels)

    /// Photos this big look sharp full screen. Below it they only make the cut when a species
    /// has fewer than `minimumStrictPhotos` that do (see `ContentPolicy.licensedImages`).
    static let strictMinLongSide = 1200
    static let strictMinShortSide = 800
    /// Never shown below this, whatever else the species has.
    static let relaxedMinLongSide = 640
    static let relaxedMinShortSide = 400
    /// A species needs at least this many sharp photos before softer ones are dropped.
    static let minimumStrictPhotos = 2

    static func isStrictlySharp(width: Int, height: Int) -> Bool {
        max(width, height) >= strictMinLongSide && min(width, height) >= strictMinShortSide
    }

    static func isRelaxedSharp(width: Int, height: Int) -> Bool {
        max(width, height) >= relaxedMinLongSide && min(width, height) >= relaxedMinShortSide
    }

    // MARK: Which rendition to download

    /// Standard Wikimedia thumbnail widths we use. Since 2025 Wikimedia only serves a fixed set
    /// of thumbnail widths (https://www.mediawiki.org/wiki/Common_thumbnail_sizes); others get
    /// HTTP 400. 1920 is the width `WikiClient` asks for; its 2x rendition is 3840 (or the
    /// original when the original is smaller).
    static let standardWidth = ImageSizing.wikimediaThumbWidth
    static let largeWidth = 3840
    /// Originals bigger than this are never downloaded; the standard thumbnail is used instead.
    static let maxOriginalBytes = 15 * 1024 * 1024
    /// Upscaling a photo by up to ~11% is invisible on a phone, so the standard thumbnail is kept
    /// when it reaches 90% of what the screen needs.
    static let upscaleTolerance = 0.9

    /// Pixel width a photo needs so it is not upscaled on the biggest screen. Tall and
    /// near-square photos are cropped to fill the screen, so they must be as tall as it; wide
    /// photos are shown whole across it, so they only need its width.
    static func neededWidth(width: Int, height: Int) -> Int {
        guard width > 0, height > 0 else { return screenPixelWidth }
        let ratio = Double(width) / Double(height)
        if ratio > wideRatio { return screenPixelWidth }
        return max(screenPixelWidth, Int((Double(screenPixelHeight) * ratio).rounded(.up)))
    }

    /// The URL to load: the 1920 px thumbnail when that is enough (or the original is no bigger),
    /// otherwise the 2x rendition (3840 px, or the original if it is smaller and not huge).
    /// - Parameters:
    ///   - standardURL: Commons' 1920 px rendition (Commons returns the original when it is smaller).
    ///   - largeURL: Commons' 2x rendition (`responsiveUrls["2"]`), if any.
    ///   - bytes: size of the original file.
    static func displayURL(width: Int, height: Int, bytes: Int?, standardURL: URL, largeURL: URL?) -> URL {
        guard width > standardWidth, let largeURL else { return standardURL }
        let needed = Double(neededWidth(width: width, height: height)) * upscaleTolerance
        guard needed > Double(standardWidth) else { return standardURL }
        // When the original is under 3840 px wide, the 2x rendition is the original file itself.
        let largeIsOriginal = width <= largeWidth
        if largeIsOriginal, let bytes, bytes > maxOriginalBytes { return standardURL }
        return largeURL
    }

    // MARK: Score

    /// Everything the score looks at. Text fields are matched case-insensitively.
    struct Signals {
        var fileTitle: String
        var width: Int
        var height: Int
        var mime: String = "image/jpeg"
        /// Commons assessments, e.g. ["quality", "featured", "valued", "potd", "poty"].
        var assessments: Set<String> = []
        var categories: [String] = []
        var description: String? = nil
        /// The species article's own lead image (chosen by Wikipedia editors).
        var isLead: Bool = false
        /// Scientific and common name of the species, to tell photos of it from photos of its habitat.
        var subjectNames: [String] = []
    }

    /// Higher is better. Roughly 0 for an ordinary usable photo; Featured, big, portrait close-ups
    /// of the species score 100+. Ties keep the article's order.
    static func score(_ s: Signals) -> Double {
        var score = 0.0
        score += assessmentScore(s.assessments)
        score += resolutionScore(width: s.width, height: s.height)
        score += shapeScore(width: s.width, height: s.height)
        if s.isLead { score += 20 }
        if s.mime == "image/png" { score -= 5 }   // usually video stills, scans or graphics

        let titleText = normalized(s.fileTitle)
        let categoryText = s.categories.map(normalized).joined(separator: " | ")
        let descriptionText = normalized(s.description ?? "")
        let allText = [titleText, categoryText, descriptionText].joined(separator: " | ")
        // Words in the species' own names never count against it ("Northern fur seal").
        let subjectWords = tokens(s.subjectNames.map(normalized).joined(separator: " "))
        let words = tokens(allText).subtracting(subjectWords)

        if !s.subjectNames.isEmpty {
            let names = s.subjectNames.map(normalized).filter { $0.count >= 3 }
            let genus = s.subjectNames.first.map(normalized)?.split(separator: " ").first.map { String($0) }
            let mentions = names.contains { allText.contains($0) }
                || (genus.map { $0.count >= 4 && tokens(allText).contains($0) } ?? false)
            if mentions { score += 15 } else if !s.categories.isEmpty { score -= 10 }
        }
        if matches(closeUpPhrases, closeUpWords, text: allText, words: words) { score += 15 }
        if matches(distantPhrases, distantWords, text: allText, words: words) { score -= 15 }
        if matches(specimenPhrases, specimenWords, text: allText, words: words) { score -= 20 }
        if matches(flawPhrases, [], text: categoryText + " | " + titleText, words: []) { score -= 20 }
        return score
    }

    /// Featured and Picture of the Year are Commons' strictest bars; Quality images are
    /// technically excellent; Valued images are the best illustration of their subject.
    static func assessmentScore(_ assessments: Set<String>) -> Double {
        var score = 0.0
        if assessments.contains("featured") { score += 40 }
        if assessments.contains("poty") || assessments.contains("potd") { score += 10 }
        if assessments.contains("quality") { score += 25 }
        if assessments.contains("valued") { score += 15 }
        return score
    }

    /// 0 at the strict minimum, rising to 30 for a short side of 3000 px or more.
    static func resolutionScore(width: Int, height: Int) -> Double {
        let short = Double(min(width, height))
        guard short > 0 else { return -30 }
        let floor = Double(strictMinShortSide), top = 3000.0
        if short < floor { return -30 * (1 - short / floor) - 10 }
        return 30 * min(1, log(short / floor) / log(top / floor))
    }

    /// Portrait fills the phone with no crop; near-square fills it with a side crop; wide photos
    /// are shown smaller over a blurred fill, so they rank lower.
    static func shapeScore(width: Int, height: Int) -> Double {
        guard width > 0, height > 0 else { return 0 }
        let ratio = Double(width) / Double(height)
        switch ratio {
        case ..<0.4: return 0           // very tall strips crop badly
        case ..<0.85: return 25         // portrait: fills the screen
        case ..<wideRatio: return 15    // near-square: fills with a modest crop
        case ..<1.6: return 0           // 4:3, 3:2: shown whole over a blur
        default: return -15             // panoramas: the animal ends up small
        }
    }

    /// Commons assessments field ("quality|featured|valued") as a set of lower-case tokens.
    static func assessments(from raw: String?) -> Set<String> {
        Set((raw ?? "").lowercased().split(separator: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty })
    }

    /// Commons categories field ("A|B|C") as a list.
    static func categories(from raw: String?) -> [String] {
        (raw ?? "").split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: Word lists

    /// Commons categories like "Panthera uncia heads", "Felidae looking at viewer", "Portraits of
    /// birds", or file names with "close-up" or "head" mean the animal fills the frame.
    private static let closeUpPhrases = ["close-up", "close up", "closeup", "looking at viewer", "looking at camera",
                                         "front view", "macro photograph"]
    private static let closeUpWords: Set<String> = ["head", "heads", "portrait", "portraits", "face", "faces",
                                                    "closeups", "macro"]

    /// The animal is small in the frame, or not the subject.
    private static let distantPhrases = ["white background", "in habitat", "aerial view", "aerial photograph"]
    private static let distantWords: Set<String> = ["habitat", "habitats", "landscape", "landscapes", "scenery",
                                                    "flock", "flocks", "herd", "herds", "colony", "colonies",
                                                    "enclosure", "enclosures", "tracks", "footprint", "footprints",
                                                    "scat", "droppings", "egg", "eggs", "feather", "feathers",
                                                    "hunter", "hunters", "trophy", "circus"]

    /// Dead or preserved animals: fine for extinct species (real fossils are labelled), but a
    /// living species should lead with the living animal.
    private static let specimenPhrases = ["natural history", "museum specimen", "mounted specimen"]
    private static let specimenWords: Set<String> = ["skull", "skulls", "skeleton", "skeletons", "specimen",
                                                     "specimens", "taxidermy", "taxidermied", "stuffed",
                                                     "museum", "mwnh", "dead", "carcass", "roadkill", "pelt", "fur",
                                                     "skin", "skins", "bones"]

    /// Commons maintenance categories that flag technical problems.
    private static let flawPhrases = ["inappropriate jpeg compression", "low quality", "blurry", "out of focus",
                                      "watermark", "images with borders", "upscaled", "still images of youtube",
                                      "images from youtube", "screenshots", "video stills"]

    // MARK: Helpers

    static func normalized(_ text: String) -> String {
        var t = text.lowercased().replacingOccurrences(of: "_", with: " ")
        if t.hasPrefix("file:") { t.removeFirst(5) }
        return t
    }

    static func tokens(_ text: String) -> Set<String> {
        Set(text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
    }

    private static func matches(_ phrases: [String], _ words: Set<String>, text: String, words tokens: Set<String>) -> Bool {
        phrases.contains { text.contains($0) } || !words.isDisjoint(with: tokens)
    }
}
