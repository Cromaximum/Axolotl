import SwiftUI

/// Onboarding on first run, then the Feed / Tree / Met tabs.
struct RootView: View {
    let taxonomy: Taxon
    let catalog: SpeciesCatalog
    /// Lookups over the bundled tree, built once and shared by the Tree, Met and onboarding screens.
    @State private var index: TaxonomyIndex
    @Environment(PreferencesStore.self) private var prefs
    @Environment(MetStore.self) private var met
    @Environment(\.speciesContentProvider) private var contentProvider
    @Environment(\.imageLoader) private var images

    init(taxonomy: Taxon, catalog: SpeciesCatalog) {
        self.taxonomy = taxonomy
        self.catalog = catalog
        _index = State(initialValue: TaxonomyIndex(root: taxonomy))
    }

    var body: some View {
        Group {
            if prefs.hasOnboarded {
                TabView {
                    FeedView(taxonomy: taxonomy, catalog: catalog, provider: contentProvider, images: images)
                        .tabItem { Label("Feed", systemImage: "rectangle.portrait") }
                    TaxonomyPickerView(index: index)
                        .tabItem { Label("Tree", systemImage: "point.3.connected.trianglepath.dotted") }
                    MetView(index: index)
                        .tabItem { Label("Met", systemImage: "square.grid.2x2") }
                }
                .tint(Theme.amber)
                .toolbarBackground(Theme.forest, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            } else {
                OnboardingView(index: index)
            }
        }
        // Saved live species that the bundled tree now covers drop their stored copy (met.v2).
        .onAppear { met.forgetCopies(of: index.speciesIDs) }
    }
}
