import Foundation

/// Phase 1 rules for what content may appear in the app.
/// Only freely licensed media is shown, and every item keeps its attribution.
enum ContentPolicy {

    // MARK: Licences

    /// True for public domain, CC0, CC BY and CC BY-SA (any version).
    /// Rejects NonCommercial, NoDerivatives, fair use, GFDL-only and unknown licences.
    static func isAllowedLicense(_ shortName: String?) -> Bool {
        guard let raw = shortName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        let name = raw.lowercased()
        // NonCommercial is out because the app is ad-supported; NoDerivatives because we crop.
        if name.contains("-nc") || name.contains(" nc") || name.contains("noncommercial") { return false }
        if name.contains("-nd") || name.contains(" nd") || name.contains("noderiv") { return false }
        if name.contains("fair use") || name.contains("non-free") { return false }
        if name == "cc0" || name.hasPrefix("cc0 ") || name.contains("cc zero") { return true }
        if name.hasPrefix("public domain") || name == "pd" || name.hasPrefix("pd-") || name.hasPrefix("pd ") { return true }
        if name.hasPrefix("cc by") || name.hasPrefix("cc-by") { return true }
        return false
    }

    // MARK: Image suitability

    static let allowedMimeTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]

    /// Phrases in a file name that mean the image is not a picture of the animal. Matched
    /// anywhere in the name (underscores read as spaces).
    private static let junkPhrases = [
        "distribution", "status iucn", "phylogen", "cladogram", "skull comparison", "size comparison",
        "commons-logo", "wikispecies", "wiktionary", "red pencil", "question book", "ambox",
        "range map", "life cycle", "lifecycle", "anatomy", "x-ray", "ct scan", "diagram", "scale bar",
    ]
    /// Short words that mean the same, matched as whole words only, so "Orange-bellied parrot",
    /// "photograph" and "Mountain" are not caught by "range", "graph" and "map".
    private static let junkWords: Set<String> = [
        "map", "maps", "range", "logo", "icon", "flag", "stamp", "stamps", "coin", "coins", "banknote",
        "symbol", "chart", "graph", "infographic", "xray", "radiograph", "micrograph",
    ]
    /// Commons categories that mean the same ("Panthera uncia distribution maps", "Cladograms
    /// of Pantherinae", "Snow leopards on banknotes", "OOUI icons"). Whole words only.
    private static let junkCategoryWords: Set<String> = [
        "map", "maps", "diagram", "diagrams", "cladogram", "cladograms", "chart", "charts", "graphs",
        "banknote", "banknotes", "stamp", "stamps", "coin", "coins", "logo", "logos", "icon", "icons",
        "flag", "flags", "infographics", "screenshots", "radiographs", "micrographs",
    ]
    /// Commons categories that mark artwork. Whole words only, so maintenance categories such
    /// as "Media missing infobox template" don't trip on "plate".
    private static let artworkCategoryWords: Set<String> = [
        "illustrations", "illustration", "drawings", "paintings", "woodcuts", "engravings", "lithographs",
        "paleoart", "palaeoart", "restorations", "reconstructions", "sculptures", "statues", "artworks",
        "watercolors", "watercolours", "renders", "renderings", "cartoons", "clipart",
    ]

    /// Words that mark an image as artwork or a reconstruction rather than a photograph.
    private static let artworkWords = [
        "reconstruction", "restoration", "life restoration", "paleoart", "palaeoart",
        "artist", "illustration", "drawing", "painting", "lithograph", "engraving",
        "plate", "watercolour", "watercolor", "render", "3d model", "sculpture", "statue",
        "diagram", "skeletal", "sketch", "cartoon", "clipart",
        // Commons descriptions are often not in English. Stems for Spanish, French, German,
        // Italian and Portuguese: reconstrucción/reconstrução/Rekonstruktion/ricostruzione,
        // restauración, ilustración/illustrazione, dibujo, dessin, Zeichnung, disegno, pintura,
        // peinture, Gemälde, paleoarte.
        "reconstru", "rekonstru", "ricostru", "restaura", "ilustra", "illustra", "dibujo",
        "desenho", "dessin", "zeichnung", "disegno", "pintura", "peinture", "gemälde", "dipinto",
        "paleoarte", "paléoart", "paläokunst", "künstler", "artiste", "artista",
    ]

    /// Words that mark a real specimen: fossils, skeletons, mounts, museum casts.
    private static let fossilWords = [
        "fossil", "specimen", "skeleton", "skull", "holotype", "paratype", "cast", "mount",
        "bones", "subfossil", "museum", "amber", "imprint", "slab",
    ]

    static func isFossil(fileTitle: String, description: String?) -> Bool {
        let haystack = (fileTitle + " " + (description ?? "")).lowercased()
        return fossilWords.contains { haystack.contains($0) }
    }

    /// Commons description, kept verbatim but cut only at a sentence boundary (D-011): as many
    /// whole sentences as fit in `limit` characters. If even the first sentence is longer, there
    /// is no caption rather than a cut one.
    static func wholeSentenceCaption(_ text: String, limit: Int = 200) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= limit { return trimmed }
        var out = ""
        for sentence in FactExtractor.sentences(in: trimmed) {
            let next = out.isEmpty ? sentence : out + " " + sentence
            if next.count > limit { break }
            out = next
        }
        return out.isEmpty ? nil : out
    }

    static func isJunk(fileTitle: String, categories: [String] = []) -> Bool {
        let t = PhotoQuality.normalized(fileTitle)
        if junkPhrases.contains(where: { t.contains($0) }) { return true }
        if !junkWords.isDisjoint(with: PhotoQuality.tokens(t)) { return true }
        let categoryWords = PhotoQuality.tokens(categories.map(PhotoQuality.normalized).joined(separator: " "))
        return !junkCategoryWords.isDisjoint(with: categoryWords)
    }

    static func isArtwork(fileTitle: String, description: String?, categories: [String] = []) -> Bool {
        let haystack = (fileTitle + " " + (description ?? "")).lowercased()
        if artworkWords.contains(where: { haystack.contains($0) }) { return true }
        let categoryWords = PhotoQuality.tokens(categories.map(PhotoQuality.normalized).joined(separator: " "))
        return !artworkCategoryWords.isDisjoint(with: categoryWords)
    }

    // MARK: Size and duplicates

    /// Panoramas and tall strips lose the animal in any phone crop.
    static let maxAspectRatio = 2.6

    /// Original file is at least `PhotoQuality`'s relaxed minimum and not a strip. Unknown sizes
    /// pass: Commons almost always reports them.
    static func isSharpEnough(width: Int?, height: Int?) -> Bool {
        guard let width, let height, width > 0, height > 0 else { return true }
        guard PhotoQuality.isRelaxedSharp(width: width, height: height) else { return false }
        let ratio = Double(width) / Double(height)
        return ratio <= maxAspectRatio && ratio >= 1 / maxAspectRatio
    }

    /// Words Commons uploaders add to a crop, edit or re-encode of an existing file.
    private static let variantWords: Set<String> = [
        "crop", "cropped", "edit", "edited", "retouched", "rotated", "denoised", "adjusted",
        "brightened", "straightened", "derivative", "modified", "version", "alt", "jpg", "jpeg",
        "png", "webp", "tif", "tiff",
    ]

    /// Name with the "File:" prefix, extension, punctuation and variant words removed, so
    /// "File:Snow leopard (cropped).jpg" and "File:Snow_leopard.png" match.
    static func duplicateKey(fileTitle: String) -> String {
        var name = fileTitle.lowercased()
        if name.hasPrefix("file:") { name.removeFirst(5) }
        if let dot = name.lastIndex(of: ".") { name = String(name[..<dot]) }
        let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !variantWords.contains($0) }
        return words.isEmpty ? fileTitle.lowercased() : words.joined(separator: " ")
    }

    /// Drops near-duplicate files (crops, edits and re-encodes of one photo), keeping the
    /// preferred file (the article's lead image) when it is one of them. Order is kept.
    static func distinctImages(_ images: [LicensedImage], preferring preferred: String?) -> [LicensedImage] {
        var keeper: [String: String] = [:]   // duplicate key -> file title kept
        let ranked = images.filter { $0.fileTitle == preferred } + images.filter { $0.fileTitle != preferred }
        for image in ranked {
            let key = duplicateKey(fileTitle: image.fileTitle)
            if keeper[key] == nil { keeper[key] = image.fileTitle }
        }
        let kept = Set(keeper.values)
        var seen = Set<String>()
        return images.filter { kept.contains($0.fileTitle) && seen.insert($0.fileTitle).inserted }
    }

    /// Turns raw API image info into licensed images, dropping anything not allowed, then ranks
    /// them best first with `PhotoQuality` (the order the feed uses them in) and points each at
    /// the Wikimedia rendition that is sharp full screen. When a species has at least
    /// `PhotoQuality.minimumStrictPhotos` sharp photos, softer ones are dropped.
    /// - Parameters:
    ///   - leadFileTitle: the article's lead image, which ranks higher (editors chose it).
    ///   - subjectNames: scientific then common name, to tell photos of the animal from its habitat.
    static func licensedImages(from infos: [WikiClient.ImageInfo], leadFileTitle: String? = nil,
                               subjectNames: [String] = []) -> [LicensedImage] {
        let ranked: [(image: LicensedImage, score: Double, strict: Bool)] = infos.compactMap { info in
            let categories = PhotoQuality.categories(from: info.categories)
            guard allowedMimeTypes.contains(info.mime),
                  !isJunk(fileTitle: info.fileTitle, categories: categories),
                  isAllowedLicense(info.licenseShortName),
                  isSharpEnough(width: info.width, height: info.height)
            else { return nil }
            let description = info.descriptionHTML.map(HTMLText.plain)
            let width = info.width ?? 0, height = info.height ?? 0
            let known = width > 0 && height > 0
            let url = known
                ? PhotoQuality.displayURL(width: width, height: height, bytes: info.bytes,
                                          standardURL: info.url, largeURL: info.largeURL)
                : info.url
            let image = LicensedImage(
                fileTitle: info.fileTitle,
                url: url,
                width: info.width,
                height: info.height,
                caption: description.flatMap { wholeSentenceCaption($0) },
                attribution: Attribution(
                    title: info.fileTitle,
                    author: info.artistHTML.map(HTMLText.plain).flatMap { $0.isEmpty ? nil : $0 },
                    license: info.licenseShortName ?? "Unknown",
                    licenseURL: info.licenseURL,
                    sourceURL: info.descriptionURL
                ),
                isArtwork: isArtwork(fileTitle: info.fileTitle, description: description, categories: categories),
                isFossil: isFossil(fileTitle: info.fileTitle, description: description)
            )
            let score = known ? PhotoQuality.score(.init(
                fileTitle: info.fileTitle, width: width, height: height, mime: info.mime,
                assessments: PhotoQuality.assessments(from: info.assessments), categories: categories,
                description: description, isLead: info.fileTitle == leadFileTitle, subjectNames: subjectNames
            )) : 0
            let strict = !known || PhotoQuality.isStrictlySharp(width: width, height: height)
            return (image, score, strict)
        }
        let strictCount = ranked.filter { $0.strict }.count
        let kept = strictCount >= PhotoQuality.minimumStrictPhotos ? ranked.filter { $0.strict } : ranked
        // Stable sort: equal scores keep the article's order.
        return kept.enumerated()
            .sorted { ($0.element.score, -$0.offset) > ($1.element.score, -$1.offset) }
            .map { $0.element.image }
    }
}

/// Commons metadata (Artist, ImageDescription) arrives as HTML fragments.
enum HTMLText {
    static func plain(_ html: String) -> String {
        var s = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
                        "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
