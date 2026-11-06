import SwiftUI

@main
struct AnimalScrollerApp: App {
    @State private var preferences = PreferencesStore()
    private let taxonomy = TaxonomyLoader.loadBundled()

    init() {
        // Generous on-disk cache so scrolling back and re-visiting animals is cheap.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            FeedView(taxonomy: taxonomy)
                .environment(preferences)
                .preferredColorScheme(.dark)
        }
    }
}
