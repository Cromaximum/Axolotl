import CoreGraphics
import Foundation
import os
import SwiftUI

/// Environment values for the app's shared services. `App/` sets the real ones at the root.
/// The defaults never reach the network: they fail and log a fault, so a missing injection
/// shows up immediately instead of silently creating a second client (architecture rule 3).
extension EnvironmentValues {
    var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }

    var speciesContentProvider: any SpeciesContentProvider {
        get { self[SpeciesContentProviderKey.self] }
        set { self[SpeciesContentProviderKey.self] = newValue }
    }
}

private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoading = UnavailableImageLoader()
}

private struct SpeciesContentProviderKey: EnvironmentKey {
    static let defaultValue: any SpeciesContentProvider = UnavailableContentProvider()
}

private let environmentLog = Logger(subsystem: "com.cromaximum.animalscroller", category: "environment")

private enum UnavailableService: Error { case notInjected(String) }

private struct UnavailableImageLoader: ImageLoading {
    var fullScreenPixelSize: Int { ImageSizing.fullScreenPixelSize }

    func image(for url: URL, maxPixelSize: Int) async throws -> CGImage {
        environmentLog.fault("imageLoader was not injected; set it in App/")
        throw UnavailableService.notInjected("imageLoader")
    }

    func cachedImage(for url: URL, maxPixelSize: Int) -> CGImage? { nil }
    func prefetch(_ urls: [URL], maxPixelSize: Int) async {}
}

private struct UnavailableContentProvider: SpeciesContentProvider {
    func content(for species: Species) async throws -> SpeciesContent {
        environmentLog.fault("speciesContentProvider was not injected; set it in App/")
        throw UnavailableService.notInjected("speciesContentProvider")
    }
}
