import XCTest
@testable import AnimalScroller

final class AchievementBoardTests: XCTestCase {
    private let index = TaxonomyIndex(root: TreeFixture.root)

    private func met(_ titles: [String]) -> [SpeciesEntry] { titles.compactMap { index.entry(forSpecies: $0) } }

    func testAchievementsComeFromTheTreeAndStatuses() {
        let ids = AchievementBoard.achievements(index: index).map(\.id)
        // Amphibians has one species, under the minimum group size of 3.
        XCTAssertEqual(ids, ["overall", "status:EX", "status:CR", "status:VU", "status:LC",
                             "taxon:mammalia", "taxon:carnivora"])
        let mammals = AchievementBoard.achievements(index: index).first { $0.id == "taxon:mammalia" }
        XCTAssertEqual(mammals?.name, "Mammals")
        XCTAssertEqual(mammals?.groupSize, 3)
    }

    func testMetSpeciesCountTowardsEveryBranchAndStatus() {
        let board = AchievementBoard.progress(met: met(["Snow leopard", "Fennec fox", "Axolotl", "Snow leopard"]),
                                              index: index)
        let counts = Dictionary(uniqueKeysWithValues: board.map { ($0.id, $0.metCount) })
        XCTAssertEqual(counts["overall"], 3)
        XCTAssertEqual(counts["taxon:mammalia"], 2)
        XCTAssertEqual(counts["taxon:carnivora"], 2)
        XCTAssertEqual(counts["status:VU"], 1)
        XCTAssertEqual(counts["status:CR"], 1)
        XCTAssertEqual(counts["status:EX"], 0)
    }

    func testLiveSpeciesCountThroughTheirBundledBranches() {
        var live = TreeFixture.species("Clouded leopard", "Neofelis nebulosa", .vulnerable)
        live.gbifKey = 42
        let entry = SpeciesEntry(species: live, lineage: index.path(to: "felidae"))
        let board = AchievementBoard.progress(met: [entry], index: index)
        XCTAssertEqual(board.first { $0.id == "taxon:carnivora" }?.metCount, 1)
        XCTAssertEqual(board.first { $0.id == "status:VU" }?.metCount, 1)

        // A live species with no sourced status doesn't count as Not Evaluated or anything else.
        var unknown = TreeFixture.species("Mystery cat", "Felis ignota", .notEvaluated)
        unknown.gbifKey = 43
        let board2 = AchievementBoard.progress(met: [SpeciesEntry(species: unknown, lineage: [])], index: index)
        XCTAssertEqual(board2.first { $0.id == "overall" }?.metCount, 1)
        XCTAssertTrue(board2.filter { $0.id.hasPrefix("status:") }.allSatisfy { $0.metCount == 0 })
    }

    func testNewlyReachedAndUnseen() {
        let before = AchievementBoard.progress(met: [], index: index)
        let after = AchievementBoard.progress(met: met(["Snow leopard"]), index: index)
        let up = AchievementBoard.newlyReached(from: before, to: after).map(\.id)
        XCTAssertEqual(Set(up), ["overall", "status:VU", "taxon:mammalia", "taxon:carnivora"])
        XCTAssertTrue(AchievementBoard.newlyReached(from: after, to: after).isEmpty)

        XCTAssertEqual(AchievementBoard.unseenTiers(after, seen: [:]), 4)
        XCTAssertEqual(AchievementBoard.unseenTiers(after, seen: ["overall": 1, "status:VU": 1]), 2)
        XCTAssertEqual(AchievementBoard.unseenIDs(after, seen: ["overall": 1]),
                       ["status:VU", "taxon:mammalia", "taxon:carnivora"])
    }

    func testSectionsKeepStatusOrderAndPutStartedFirst() {
        let board = AchievementBoard.progress(met: met(["Axolotl"]), index: index)
        let sections = AchievementBoard.sections(board)
        XCTAssertEqual(sections.map { $0.0 }, [.overall, .status, .rank(.class), .rank(.order)])
        // Statuses stay in scale order even though only CR has a species met.
        XCTAssertEqual(sections[1].1.map { $0.id }, ["status:EX", "status:CR", "status:VU", "status:LC"])
    }
}
