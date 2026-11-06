import SwiftUI

/// Onboarding on first run, then the Feed / Tree / Met tabs.
struct RootView: View {
    let taxonomy: Taxon
    let catalog: SpeciesCatalog
    @Environment(PreferencesStore.self) private var prefs
    @Environment(\.speciesContentProvider) private var contentProvider
    @Environment(\.imageLoader) private var images

    var body: some View {
        if prefs.hasOnboarded {
            TabView {
                FeedView(taxonomy: taxonomy, catalog: catalog, provider: contentProvider, images: images)
                    .tabItem { Label("Feed", systemImage: "rectangle.portrait") }
                TaxonomyPickerView(root: taxonomy)
                    .tabItem { Label("Tree", systemImage: "point.3.connected.trianglepath.dotted") }
                MetView(taxonomy: taxonomy)
                    .tabItem { Label("Met", systemImage: "square.grid.2x2") }
            }
            .tint(Theme.amber)
            .toolbarBackground(Theme.forest, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        } else {
            OnboardingView(taxonomy: taxonomy)
        }
    }
}
