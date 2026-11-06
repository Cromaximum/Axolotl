import XCTest
@testable import AnimalScroller

final class TaxonomyIndexTests: XCTestCase {
    private let index = TaxonomyIndex(root: TreeFixture.root)

    func testCountsMatchAllSpecies() {
        XCTAssertEqual(index.totalSpecies, TreeFixture.root.allSpecies().count)
        XCTAssertEqual(index.speciesCount("carnivora"), 3)
        XCTAssertEqual(index.speciesCount("felidae"), 2)
        XCTAssertEqual(index.speciesCount("amphibia"), 1)
        XCTAssertEqual(index.speciesCount("missing"), 0)
    }

    func testPathAndLookup() {
        XCTAssertEqual(index.path(to: "felidae").map(\.id), ["animalia", "mammalia", "carnivora", "felidae"])
        XCTAssertEqual(index.path(to: "missing"), [])
        XCTAssertEqual(index.entry(forSpecies: "Axolotl")?.lineageIDs, ["animalia", "amphibia", "ambystomatidae"])
        XCTAssertNil(index.entry(forSpecies: "Unknown"))
    }

    func testSelectionStates() {
        let sel: Set<String> = ["carnivora"]
        XCTAssertEqual(index.state(of: "carnivora", selection: sel), .selected)
        XCTAssertEqual(index.state(of: "felidae", selection: sel), .covered(byID: "carnivora"))
        XCTAssertEqual(index.state(of: "mammalia", selection: sel), .partial)
        XCTAssertEqual(index.state(of: "animalia", selection: sel), .partial)
        XCTAssertEqual(index.state(of: "amphibia", selection: sel), .unselected)
    }

    func testSpeciesCountForSelection() {
        XCTAssertEqual(index.speciesCount(selection: []), 4)
        XCTAssertEqual(index.speciesCount(selection: ["felidae", "amphibia"]), 3)
    }

    func testSummaryIsInTreeOrderAndSkipsUnknownIDs() {
        XCTAssertEqual(index.summary(selection: ["amphibia", "gone", "canidae"]).map(\.id), ["canidae", "amphibia"])
    }

    func testSearchByCommonScientificAndAccentInsensitive() {
        XCTAssertEqual(index.search("cats").first?.id, "felidae")
        XCTAssertEqual(index.search("FELID").first?.id, "felidae")
        XCTAssertEqual(index.search("uncia").first?.id, "species:Snow leopard")
        XCTAssertEqual(index.search("fénnec").first?.id, "species:Fennec fox")
        XCTAssertEqual(index.search("   "), [])
        XCTAssertEqual(index.search("zzz"), [])
    }

    func testSpeciesHitSelectsItsBranch() {
        let hit = index.search("axolotl").first
        XCTAssertEqual(hit?.branchID, "ambystomatidae")
        XCTAssertEqual(hit?.kind, .species)
    }

    func testSearchRanksExactThenPrefixThenWordThenSubstring() {
        // "Mole salamanders" matches "sala" on a word prefix; nothing has it as a name prefix.
        XCTAssertEqual(TaxonomyIndex.score("dogs", names: ["Dogs"]), 0)
        XCTAssertEqual(TaxonomyIndex.score("do", names: ["Dogs"]), 1)
        XCTAssertEqual(TaxonomyIndex.score("sala", names: ["mole salamanders"]), 2)
        XCTAssertEqual(TaxonomyIndex.score("lama", names: ["mole salamanders"]), 3)
        XCTAssertNil(TaxonomyIndex.score("x", names: [nil, "dogs"]))
    }

    func testResultsAreOrderedByScore() {
        let hits = index.search("a")
        let scores = hits.map { TaxonomyIndex.score("a", names: [$0.name, $0.scientificName]) ?? 99 }
        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(scores, scores.sorted())
    }

    func testRootIsNotASearchResult() {
        XCTAssertFalse(index.search("animals").contains { $0.id == "animalia" })
    }
}
