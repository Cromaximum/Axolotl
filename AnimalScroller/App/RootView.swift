import SwiftUI

/// Onboarding on first run, then the Feed / Tree / Met / Awards tabs, with the "tier reached"
/// toast over them.
struct RootView: View {
    let taxonomy: Taxon
    let catalog: SpeciesCatalog
    /// Lookups over the bundled tree, built once and shared by the Tree, Met and onboarding screens.
    @State private var index: TaxonomyIndex
    /// Shared by the Awards tab and the "tier reached" toast.
    @State private var achievements: AchievementsViewModel
    @Environment(PreferencesStore.self) private var prefs
    @Environment(MetStore.self) private var met
    @Environment(AchievementsStore.self) private var achievementsStore
    @Environment(\.speciesContentProvider) private var contentProvider
    @Environment(\.imageLoader) private var images

    init(taxonomy: Taxon, catalog: SpeciesCatalog) {
        self.taxonomy = taxonomy
        self.catalog = catalog
        let index = TaxonomyIndex(root: taxonomy)
        _index = State(initialValue: index)
        _achievements = State(initialValue: AchievementsViewModel(index: index))
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
                    AchievementsView(model: achievements)
                        .tabItem { Label("Awards", systemImage: "rosette") }
                        .badge(achievements.unseenCount(seen: achievementsStore.seenTiers))
                }
                .tint(Theme.amber)
                .toolbarBackground(Theme.forest, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .overlay(alignment: .top) {
                    if let toast = achievements.toast {
                        AchievementToastView(progress: toast) { achievements.dismissToast() }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(Theme.Motion.settle, value: achievements.toast?.id)
            } else {
                OnboardingView(index: index, provider: contentProvider)
            }
        }
        // Saved live species that the bundled tree now covers drop their stored copy (met.v2).
        .onAppear {
            met.forgetCopies(of: index.speciesIDs)
            achievements.refresh(met: met.entries)
        }
        // A new species can raise a tier; only the count matters, not repeat sightings.
        .onChange(of: met.entries.count) { achievements.refresh(met: met.entries) }
    }
}
