import Foundation
import Observation

/// State for first-run onboarding: which step is showing, the hero photos for the welcome screen
/// and the starting-point tiles (through the injected provider), and turning the picked tiles
/// into feed preferences.
@Observable @MainActor
final class OnboardingViewModel {
    /// Wiki title of the species behind the welcome screen. An id, not content: the name and
    /// photo are looked up from the taxonomy and Wikipedia.
    static let welcomeSpeciesID = "Shoebill"

    let index: TaxonomyIndex
    private let provider: any SpeciesContentProvider
    var step = 0
    var picked: Set<StartingPoint> = []
    /// Hero image per species id, filled in as content arrives. Used for the welcome photo and
    /// the photo-credits list.
    private(set) var heroes: [String: LicensedImage] = [:]

    init(index: TaxonomyIndex, provider: any SpeciesContentProvider) {
        self.index = index
        self.provider = provider
    }

    var welcomeHero: LicensedImage? { heroes[Self.welcomeSpeciesID] }

    /// Species ids shown on the welcome screen and the tiles, in display order.
    var photoSpeciesIDs: [String] { [Self.welcomeSpeciesID] + StartingPoint.allCases.map(\.photoSpecies) }

    func species(for id: String) -> Species? { index.entry(forSpecies: id)?.species }

    /// Credits for every photo on the onboarding screens, in display order, without repeats.
    var credits: [LicensedImage] {
        var seen = Set<String>()
        return photoSpeciesIDs.compactMap { heroes[$0] }.filter { seen.insert($0.id).inserted }
    }

    /// Loads all onboarding heroes in parallel. Missing species or failed fetches leave a gap
    /// (the tile shows board green), never an error.
    func loadHeroes() async {
        let wanted = photoSpeciesIDs.compactMap { species(for: $0) }.filter { heroes[$0.id] == nil }
        await withTaskGroup(of: (String, LicensedImage?).self) { group in
            for s in wanted {
                group.addTask { [provider] in
                    let content = try? await provider.content(for: s)
                    return (s.id, content.flatMap { HeroImage.pick(from: $0, species: s, allowArtwork: false) })
                }
            }
            for await (id, hero) in group {
                if let hero { heroes[id] = hero }
            }
        }
    }

    func toggle(_ point: StartingPoint) {
        if picked.contains(point) { picked.remove(point) } else { picked.insert(point) }
    }

    /// Writes the picked tiles into the preferences and finishes onboarding.
    func finish(into prefs: PreferencesStore) {
        let p = Self.preferences(for: picked)
        prefs.selectedTaxonIDs = p.selectedTaxonIDs
        prefs.includeExtinct = true
        prefs.extinctOnly = p.extinctOnly
        prefs.surpriseMe = true
        prefs.hasOnboarded = true
    }

    /// Pure mapping from tiles to preferences. Only "Fossil life" picked (with no branch and no
    /// "Surprise me") means extinct species from the whole tree.
    nonisolated static func preferences(for picks: Set<StartingPoint>) -> (selectedTaxonIDs: Set<String>, extinctOnly: Bool) {
        let branches = Set(picks.compactMap(\.taxonID))
        let extinctOnly = picks.contains(.fossils) && branches.isEmpty && !picks.contains(.surprise)
        return (branches, extinctOnly)
    }
}
