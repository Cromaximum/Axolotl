import SwiftUI

@main
struct AnimalScrollerApp: App {
    @State private var preferences = PreferencesStore()
    @State private var met = MetStore()
    @State private var likes = LikesStore()
    @State private var achievements = AchievementsStore()
    private let taxonomy = TaxonomyLoader.loadBundled()
    /// The live species catalogue (D-012). One instance for the app, injected down to the feed.
    private let catalog: SpeciesCatalog = LiveSpeciesCatalog()
    /// Decoded, downsampled photos with a memory cache (W1). One instance for the app.
    private let images: ImageLoading
    /// Wikipedia content behind a memory + disk cache (W1). One instance for the app.
    private let contentProvider: SpeciesContentProvider

    init() {
        // Photos are never written to the phone's storage (Maxwell, 2026-11-06, D-020). HTTP
        // responses are cached in memory only, decoded photos live in the image pipeline's memory
        // cache, and the disk cache from earlier builds (which held image bytes) is wiped on launch.
        // Species text (no image files) is still cached on disk by CachingContentProvider.
        URLCache.shared.removeAllCachedResponses()
        let urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 0)
        URLCache.shared = urlCache
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        let session = URLSession(configuration: configuration)

        images = ImagePipeline(session: session, userAgent: WikiClient.defaultUserAgent)

        var wiki = WikiClient()
        wiki.session = session
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        contentProvider = CachingContentProvider(
            upstream: WikipediaContentProvider(client: wiki),
            directory: caches.flatMap { CachingContentProvider.prepareDirectory(in: $0, fileManager: .default) })
    }

    var body: some Scene {
        WindowGroup {
            RootView(taxonomy: taxonomy, catalog: catalog)
                .environment(preferences)
                .environment(met)
                .environment(likes)
                .environment(achievements)
                .environment(\.imageLoader, images)
                .environment(\.speciesContentProvider, contentProvider)
                .preferredColorScheme(.dark)
        }
    }
}
