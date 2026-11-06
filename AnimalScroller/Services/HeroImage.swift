import Foundation

/// Which licensed image stands for a species outside the feed (detail header, Met tiles,
/// onboarding tiles). Pure logic; the same rule `FeedComposer` uses for the intro card, so a
/// species looks the same everywhere.
enum HeroImage {
    /// Reconstructions only for extinct species and only when the user allows them (D-010). Then
    /// the article's lead image, else the first real photo, else anything usable.
    static func pick(from content: SpeciesContent, species: Species, allowArtwork: Bool) -> LicensedImage? {
        let usable = usableImages(content, species: species, allowArtwork: allowArtwork)
        return usable.first { $0.fileTitle == content.leadImageFileTitle }
            ?? usable.first { !$0.isArtwork }
            ?? usable.first
    }

    /// Images this species may show under the user's artwork setting.
    static func usableImages(_ content: SpeciesContent, species: Species, allowArtwork: Bool) -> [LicensedImage] {
        let artworkOK = allowArtwork && species.isExtinct
        return content.images.filter { artworkOK || !$0.isArtwork }
    }
}
