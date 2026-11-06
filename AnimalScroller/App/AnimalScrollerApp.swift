import SwiftUI

@main
struct AnimalScrollerApp: App {
    @State private var preferences = PreferencesStore()
    @State private var met = MetStore()
    @State private var likes = LikesStore()
    private let taxonomy = TaxonomyLoader.loadBundled()
    /// The live species catalogue (D-012). One instance for the app, injected down to the feed.
    private let catalog: SpeciesCatalog = LiveSpeciesCatalog()

    init() {
        // Generous on-disk cache so scrolling back and re-visiting animals is cheap.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView(taxonomy: taxonomy, catalog: catalog)
                .environment(preferences)
                .environment(met)
                .environment(likes)
                .preferredColorScheme(.dark)
        }
    }
}
