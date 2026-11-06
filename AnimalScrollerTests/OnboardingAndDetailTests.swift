import XCTest
@testable import AnimalScroller

/// Pure parts of the onboarding and detail view models.
final class OnboardingAndDetailTests: XCTestCase {
    func testOnboardingPicksBecomeBranches() {
        let p = OnboardingViewModel.preferences(for: [.mammals, .birds])
        XCTAssertEqual(p.selectedTaxonIDs, ["mammalia", "aves"])
        XCTAssertFalse(p.extinctOnly)
    }

    func testFossilsAloneMeansExtinctFromTheWholeTree() {
        XCTAssertEqual(OnboardingViewModel.preferences(for: [.fossils]).extinctOnly, true)
        XCTAssertEqual(OnboardingViewModel.preferences(for: [.fossils]).selectedTaxonIDs, [])
        XCTAssertFalse(OnboardingViewModel.preferences(for: [.fossils, .surprise]).extinctOnly)
        XCTAssertFalse(OnboardingViewModel.preferences(for: [.fossils, .mammals]).extinctOnly)
        XCTAssertFalse(OnboardingViewModel.preferences(for: []).extinctOnly)
    }

    func testDetailSourcesForBundledSpecies() {
        let species = TreeFixture.species("Fennec fox", "Vulpes zerda")
        let sources = SpeciesDetailViewModel.sources(for: species, content: nil)
        XCTAssertEqual(sources.count, 1)
        XCTAssertNil(sources[0].url)
    }

    func testDetailSourcesForLiveSpeciesLinkGBIFAndTheArticle() {
        var species = TreeFixture.species("Clouded leopard", "Neofelis nebulosa")
        species.gbifKey = 5219
        let content = SpeciesContent(title: "Clouded leopard", tagline: nil, lead: "",
                                     pageURL: URL(string: "https://en.wikipedia.org/wiki/Clouded_leopard")!,
                                     leadImageFileTitle: nil, facts: [], images: [])
        let sources = SpeciesDetailViewModel.sources(for: species, content: content)
        XCTAssertEqual(sources.map(\.url?.host), ["en.wikipedia.org", "www.gbif.org", nil])
    }
}
