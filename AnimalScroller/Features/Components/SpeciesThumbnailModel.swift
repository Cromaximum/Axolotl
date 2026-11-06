import CoreGraphics
import Foundation
import Observation

/// Loads one species' hero image for a small tile (Met grid, onboarding tiles): content from the
/// injected provider, the hero chosen by `HeroImage`, then a decode sized to the tile from the
/// injected image loader. Views only draw `phase`.
@Observable
@MainActor
final class SpeciesThumbnailModel {
    enum Phase {
        case loading
        case loaded(CGImage, LicensedImage)
        case unavailable
    }

    private(set) var phase: Phase = .loading
    /// The chosen hero, once content has loaded (onboarding's full-screen welcome draws it whole).
    private(set) var hero: LicensedImage?
    private var loadedKey: String?

    /// - Parameter maxPixelSize: longest edge to decode at; nil skips decoding (hero only).
    func load(_ species: Species, allowArtwork: Bool, maxPixelSize: Int?,
              provider: any SpeciesContentProvider, images: any ImageLoading) async {
        let key = "\(species.id)|\(allowArtwork)|\(maxPixelSize ?? 0)"
        if loadedKey == key, case .loaded = phase { return }
        loadedKey = key
        do {
            let content = try await provider.content(for: species)
            guard !Task.isCancelled, loadedKey == key else { return }
            guard let pick = HeroImage.pick(from: content, species: species, allowArtwork: allowArtwork) else {
                phase = .unavailable
                return
            }
            hero = pick
            guard let maxPixelSize else { return }
            if let cached = images.cachedImage(for: pick.url, maxPixelSize: maxPixelSize) {
                phase = .loaded(cached, pick)
                return
            }
            let image = try await images.image(for: pick.url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled, loadedKey == key else { return }
            phase = .loaded(image, pick)
        } catch {
            guard !Task.isCancelled, loadedKey == key else { return }
            phase = .unavailable
        }
    }
}
