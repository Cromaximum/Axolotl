import SwiftUI

@main
struct AnimalScrollerApp: App {
    @State private var preferences = PreferencesStore()
    @State private var met = MetStore()
    @State private var likes = LikesStore()
    private let taxonomy = TaxonomyLoader.loadBundled()

    init() {
        // Generous on-disk cache so scrolling back and re-visiting animals is cheap.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView(taxonomy: taxonomy)
                .environment(preferences)
                .environment(met)
                .environment(likes)
                .preferredColorScheme(.dark)
        }
    }
}
