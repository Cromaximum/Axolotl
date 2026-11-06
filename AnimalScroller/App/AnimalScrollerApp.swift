import SwiftUI

@main
struct AnimalScrollerApp: App {
    @State private var preferences = PreferencesStore()
    @State private var met = MetStore()
    @State private var likes = LikesStore()
    private let taxonomy = TaxonomyLoader.loadBundled()
    /// The live species catalogue (D-012). One instance for the app, injected down to the feed.
    private let catalog: SpeciesCatalog = LiveSpeciesCatalog()
    /// Decoded, downsampled photos with a memory cache (W1). One instance for the app.
    private let images: ImageLoading
    /// Wikipedia content behind a memory + disk cache (W1). One instance for the app.
    private let contentProvider: SpeciesContentProvider

    init() {
        // The disk cache for raw responses (JSON and image bytes). Decoded images live in the
        // pipeline's own memory cache, so the URL cache's memory part stays small.
        let urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
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
                .environment(\.imageLoader, images)
                .environment(\.speciesContentProvider, contentProvider)
                .preferredColorScheme(.dark)
        }
    }
}
