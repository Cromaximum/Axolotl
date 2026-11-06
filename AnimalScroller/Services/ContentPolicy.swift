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

    /// Words in a file name that mean the image is not a picture of the animal.
    private static let junkWords = [
        "map", "range", "distribution", "status_iucn", "status iucn", "logo", "icon", "flag",
        "stamp", "coin", "banknote", "symbol", "chart", "graph", "phylogen", "cladogram",
        "skull_comparison", "size_comparison", "size comparison", "scale", "commons-logo",
        "wikispecies", "wiktionary", "red_pencil", "question_book", "ambox",
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

    static func isJunk(fileTitle: String) -> Bool {
        let t = fileTitle.lowercased()
        return junkWords.contains { t.contains($0) }
    }

    static func isArtwork(fileTitle: String, description: String?) -> Bool {
        let haystack = (fileTitle + " " + (description ?? "")).lowercased()
        return artworkWords.contains { haystack.contains($0) }
    }

    // MARK: Size and duplicates

    /// Narrower than this (after Commons scales to at most 1080 px wide) looks soft full screen.
    static let minImageWidth = 640
    static let minShortSide = 400
    /// Panoramas and tall strips lose the animal in any phone crop.
    static let maxAspectRatio = 2.6

    /// Unknown sizes pass, as before: Commons almost always reports them.
    static func isSharpEnough(width: Int?, height: Int?) -> Bool {
        guard let width else { return true }
        guard width >= minImageWidth else { return false }
        guard let height, height > 0 else { return true }
        guard min(width, height) >= minShortSide else { return false }
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

    /// Turns raw API image info into licensed images, dropping anything not allowed.
    static func licensedImages(from infos: [WikiClient.ImageInfo]) -> [LicensedImage] {
        infos.compactMap { info in
            guard allowedMimeTypes.contains(info.mime),
                  !isJunk(fileTitle: info.fileTitle),
                  isAllowedLicense(info.licenseShortName),
                  isSharpEnough(width: info.width, height: info.height)
            else { return nil }
            let description = info.descriptionHTML.map(HTMLText.plain)
            return LicensedImage(
                fileTitle: info.fileTitle,
                url: info.url,
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
                isArtwork: isArtwork(fileTitle: info.fileTitle, description: description),
                isFossil: isFossil(fileTitle: info.fileTitle, description: description)
            )
        }
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
