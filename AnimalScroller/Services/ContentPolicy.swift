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

    static func isJunk(fileTitle: String) -> Bool {
        let t = fileTitle.lowercased()
        return junkWords.contains { t.contains($0) }
    }

    static func isArtwork(fileTitle: String, description: String?) -> Bool {
        let haystack = (fileTitle + " " + (description ?? "")).lowercased()
        return artworkWords.contains { haystack.contains($0) }
    }

    /// Turns raw API image info into licensed images, dropping anything not allowed.
    static func licensedImages(from infos: [WikiClient.ImageInfo]) -> [LicensedImage] {
        infos.compactMap { info in
            guard allowedMimeTypes.contains(info.mime),
                  !isJunk(fileTitle: info.fileTitle),
                  isAllowedLicense(info.licenseShortName),
                  (info.width ?? 600) >= 400
            else { return nil }
            let description = info.descriptionHTML.map(HTMLText.plain)
            return LicensedImage(
                fileTitle: info.fileTitle,
                url: info.url,
                width: info.width,
                height: info.height,
                caption: description.flatMap { $0.isEmpty ? nil : String($0.prefix(200)) },
                attribution: Attribution(
                    title: info.fileTitle,
                    author: info.artistHTML.map(HTMLText.plain).flatMap { $0.isEmpty ? nil : $0 },
                    license: info.licenseShortName ?? "Unknown",
                    licenseURL: info.licenseURL,
                    sourceURL: info.descriptionURL
                ),
                isArtwork: isArtwork(fileTitle: info.fileTitle, description: description)
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
