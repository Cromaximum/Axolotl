import XCTest
@testable import AnimalScroller

/// Rules for the live species catalogue (GBIF Backbone → Wikipedia → Wikidata).
final class LiveCatalogTests: XCTestCase {
    // A small bundled tree: Animalia › Chordata › Mammalia › Carnivora › Felidae
    private let felidae = Taxon(id: "felidae", name: "Cats", scientificName: "Felidae", rank: .family, children: nil, species: nil)
    private lazy var carnivora = Taxon(id: "carnivora", name: "Carnivorans", scientificName: "Carnivora", rank: .order, children: [felidae], species: nil)
    private lazy var mammalia = Taxon(id: "mammalia", name: "Mammals", scientificName: "Mammalia", rank: .class, children: [carnivora], species: nil)
    private let aves = Taxon(id: "aves", name: "Birds", scientificName: "Aves", rank: .class, children: nil, species: nil)
    private lazy var chordata = Taxon(id: "chordata", name: "Chordates", scientificName: "Chordata", rank: .phylum, children: [mammalia, aves], species: nil)
    private lazy var root = Taxon(id: "animalia", name: "Animals", scientificName: "Animalia", rank: .kingdom, children: [chordata], species: nil)

    private let snowLeopard = GBIFClient.NameUsage(key: 5219436, canonicalName: "Panthera uncia", phylum: "Chordata",
                                                    class: "Mammalia", order: "Carnivora", family: "Felidae", genus: "Panthera")

    private func probe(_ name: String, title: String? = "Snow leopard", redirected: Bool = true, length: Int = 60_000,
                       image: String? = "Snow leopard.jpg", desc: String? = "Species of big cat",
                       disambiguation: Bool = false) -> WikiClient.ArticleProbe {
        WikiClient.ArticleProbe(requestedName: name, title: title, wasRedirected: redirected, length: length,
                                freeImage: image, shortDescription: desc, wikidataID: "Q30197",
                                isDisambiguation: disambiguation)
    }

    func testAcceptsWellCoveredSpecies() {
        XCTAssertTrue(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia")))
    }

    func testRejectsMissingStubbyOrUnillustratedArticles() {
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", title: nil)))
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", length: 1_200)))
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", image: nil)),
                       "the lead image must be freely licensed")
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", disambiguation: true)))
    }

    func testRejectsSpeciesThatRedirectToABroadGroup() {
        // Rule 1: one specific species. A species name redirecting to its genus article is a group.
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", title: "Panthera")))
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", title: "Felidae")))
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", title: "List of felids")))
        XCTAssertFalse(LiveCatalogRules.accepts(snowLeopard, probe: probe("Panthera uncia", desc: "Genus of cats")))
    }

    func testCommonNameIsTheArticleTitleVerbatim() {
        // D-011: names come from Wikipedia, never written by the app.
        XCTAssertEqual(LiveCatalogRules.commonName(articleTitle: "Snow leopard"), "Snow leopard")
        XCTAssertEqual(LiveCatalogRules.commonName(articleTitle: "Cougar (animal)"), "Cougar")
        XCTAssertEqual(LiveCatalogRules.commonName(articleTitle: "Panthera uncia"), "Panthera uncia")
    }

    func testStatusComesFromWikidataOrIsNotEvaluated() {
        XCTAssertEqual(LiveCatalogRules.status(wikidataItem: "Q278113"), .vulnerable)
        XCTAssertEqual(LiveCatalogRules.status(wikidataItem: "Q237350"), .extinct)
        XCTAssertEqual(LiveCatalogRules.status(wikidataItem: "Q11394"), .endangered)
        XCTAssertEqual(LiveCatalogRules.status(wikidataItem: "Q96377276"), .endangered)
        XCTAssertNil(LiveCatalogRules.status(wikidataItem: "Q42"))
        XCTAssertEqual(LiveCatalogRules.resolvedStatus(wikidata: .endangered, gbifExtinct: nil,
                                                       requestedExtinctOnly: false), .endangered)
        XCTAssertEqual(LiveCatalogRules.resolvedStatus(wikidata: nil, gbifExtinct: nil,
                                                       requestedExtinctOnly: false), .notEvaluated)
        XCTAssertEqual(LiveCatalogRules.resolvedStatus(wikidata: nil, gbifExtinct: true,
                                                       requestedExtinctOnly: false), .extinct)
        XCTAssertEqual(LiveCatalogRules.resolvedStatus(wikidata: nil, gbifExtinct: nil,
                                                       requestedExtinctOnly: true), .extinct,
                       "species GBIF returned for isExtinct=true")
    }

    func testUnsourcedLiveStatusIsShownAsUnknown() {
        let unsourced = Species(wikiTitle: "X", commonName: "X", scientificName: "X x", status: .notEvaluated, gbifKey: 1)
        XCTAssertFalse(unsourced.hasKnownStatus)
        XCTAssertEqual(unsourced.statusLabel, "Unknown")
        let sourced = Species(wikiTitle: "Y", commonName: "Y", scientificName: "Y y", status: .vulnerable, gbifKey: 2)
        XCTAssertEqual(sourced.statusLabel, "Vulnerable")
    }

    func testShortDescriptionIsOnlyAFilterSignal() {
        // "Extinct" in Wikipedia's short description keeps a fossil out of Living only, but is
        // never shown as an IUCN category (D-011: shown values must be sourced).
        XCTAssertTrue(LiveCatalogRules.looksExtinct(shortDescription: "Extinct species of shark"))
        XCTAssertFalse(LiveCatalogRules.looksExtinct(shortDescription: "Species of big cat"))
    }

    func testQualityGateOnlyAppliesToLiveSpecies() {
        let photo = LicensedImage(fileTitle: "File:A.jpg", url: URL(string: "https://example.org/a.jpg")!, width: 1080,
                                  height: 1440, caption: nil,
                                  attribution: Attribution(title: "A", author: "A", license: "CC BY 4.0", licenseURL: nil,
                                                           sourceURL: URL(string: "https://example.org")!),
                                  isArtwork: false)
        let art = LicensedImage(fileTitle: "File:B.jpg", url: photo.url, width: 1080, height: 1440, caption: nil,
                                attribution: photo.attribution, isArtwork: true)
        func content(images: [LicensedImage], facts: Int) -> SpeciesContent {
            SpeciesContent(title: "X", tagline: nil, lead: "", pageURL: URL(string: "https://en.wikipedia.org/wiki/X")!,
                           leadImageFileTitle: nil,
                           facts: (0..<facts).map { FactExtractor.Fact(topic: nil, text: "Fact \($0).") },
                           images: images)
        }
        let bundled = Species(wikiTitle: "X", commonName: "X", scientificName: "X x", status: .leastConcern)
        let live = Species(wikiTitle: "X", commonName: "X", scientificName: "X x", status: .leastConcern, gbifKey: 1)
        let fossil = Species(wikiTitle: "X", commonName: "X", scientificName: "X x", status: .extinct, gbifKey: 2)

        XCTAssertTrue(LiveCatalogRules.isShowable(content(images: [], facts: 0), species: bundled, allowArtwork: true))
        XCTAssertTrue(LiveCatalogRules.isShowable(content(images: [photo], facts: 2), species: live, allowArtwork: true))
        XCTAssertFalse(LiveCatalogRules.isShowable(content(images: [photo], facts: 1), species: live, allowArtwork: true))
        XCTAssertFalse(LiveCatalogRules.isShowable(content(images: [art], facts: 3), species: live, allowArtwork: true),
                       "living species never show artwork, so artwork alone doesn't count")
        XCTAssertTrue(LiveCatalogRules.isShowable(content(images: [art], facts: 3), species: fossil, allowArtwork: true))
        XCTAssertFalse(LiveCatalogRules.isShowable(content(images: [art], facts: 3), species: fossil, allowArtwork: false))
    }

    func testLineageReusesBundledNodesThenAddsGBIFNodes() {
        let path = root.path(to: "mammalia")!
        let lineage = LiveCatalogRules.lineage(branchPath: path, usage: snowLeopard)
        XCTAssertEqual(lineage.map(\.id), ["animalia", "chordata", "mammalia", "carnivora", "felidae", "gbif-genus-panthera"])
        XCTAssertEqual(lineage.last?.name, "Panthera", "GBIF-only nodes show their scientific name, not an invented one")

        let wolf = GBIFClient.NameUsage(key: 5219173, canonicalName: "Canis lupus", class: "Mammalia",
                                        order: "Carnivora", family: "Canidae", genus: "Canis")
        let wolfLineage = LiveCatalogRules.lineage(branchPath: path, usage: wolf)
        XCTAssertEqual(wolfLineage.map(\.id), ["animalia", "chordata", "mammalia", "carnivora", "gbif-family-canidae", "gbif-genus-canis"])
    }

    func testBranchesSkipKingdomAndPhylumAndSplitBySelection() {
        let branches = LiveCatalogRules.searchableBranches(in: root)
        XCTAssertEqual(Set(branches.map(\.id)), ["mammalia", "carnivora", "felidae", "aves"])

        let all = LiveCatalogRules.split(branches: branches, root: root, selectedIDs: [])
        XCTAssertEqual(all.inside.count, 4)
        XCTAssertTrue(all.outside.isEmpty)

        let cats = LiveCatalogRules.split(branches: branches, root: root, selectedIDs: ["felidae"])
        XCTAssertEqual(cats.inside.map(\.id), ["felidae"])
        XCTAssertEqual(cats.outside.map(\.id), ["aves"], "ancestors of the selection are never discovery branches")
    }

    func testRandomOffsetStaysInsideGBIFWindow() {
        var rng = SeededRNG(state: 3)
        for _ in 0..<200 {
            let o = LiveCatalogRules.randomOffset(count: 400_000, limit: 40, using: &rng)
            XCTAssertTrue((0...(GBIFClient.maxSearchWindow - 40)).contains(o))
        }
        XCTAssertEqual(LiveCatalogRules.randomOffset(count: 12, limit: 40, using: &rng), 0)
    }
}
