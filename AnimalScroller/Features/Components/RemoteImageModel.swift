import CoreGraphics
import Foundation
import Observation

/// State for one remote image on screen. Owned by `FullBleedImage`; asks the injected
/// `ImageLoading` for a decoded image so the view only draws.
@Observable
@MainActor
final class RemoteImageModel {
    enum Phase {
        case loading
        case loaded(CGImage)
        case failed

        var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
    }

    private(set) var phase: Phase = .loading
    private var loadedURL: URL?

    /// What to draw now: the loaded image for `url`, or one already decoded in memory
    /// (prefetched), so a card that scrolls into view never flashes a placeholder.
    func displayPhase(for url: URL, loader: ImageLoading) -> Phase {
        if loadedURL == url, case .loaded = phase { return phase }
        if let cached = loader.cachedImage(for: url, maxPixelSize: loader.fullScreenPixelSize) {
            return .loaded(cached)
        }
        return loadedURL == url ? phase : .loading
    }

    func load(_ url: URL, using loader: ImageLoading) async {
        if loadedURL == url, case .loaded = phase { return }
        loadedURL = url
        if let cached = loader.cachedImage(for: url, maxPixelSize: loader.fullScreenPixelSize) {
            phase = .loaded(cached)
            return
        }
        phase = .loading
        do {
            let image = try await loader.image(for: url, maxPixelSize: loader.fullScreenPixelSize)
            guard !Task.isCancelled, loadedURL == url else { return }
            phase = .loaded(image)
        } catch {
            guard !Task.isCancelled, loadedURL == url else { return }
            phase = .failed
        }
    }
}
