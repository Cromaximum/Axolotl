import XCTest
@testable import AnimalScroller

final class MetCollectionTests: XCTestCase {
    private let index = TaxonomyIndex(root: TreeFixture.root)
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func record(_ id: String, first: TimeInterval, last: TimeInterval? = nil, saved: Bool = false,
                        live: Species? = nil, lineage: [String] = []) -> MetCollection.Record {
        MetCollection.Record(id: id, firstMet: t0 + first, lastMet: t0 + (last ?? first), saved: saved,
                             savedAt: nil, liveSpecies: live, liveLineageIDs: lineage, imageURL: nil)
    }

    func testResolveUsesBundledDataOverStoredCopy() {
        let stale = TreeFixture.species("Axolotl", "Old name", .notEvaluated)
        let items = MetCollection.resolve([record("Axolotl", first: 0, live: stale)], index: index, likedIDs: [])
        XCTAssertEqual(items.first?.entry.species.scientificName, "Ambystoma mexicanum")
        XCTAssertEqual(items.first?.entry.lineageIDs, ["animalia", "amphibia", "ambystomatidae"])
    }

    func testResolveKeepsLiveSpeciesAndDropsUnknownIDs() {
        var live = TreeFixture.species("Clouded leopard", "Neofelis nebulosa")
        live.gbifKey = 42
        let items = MetCollection.resolve([record("Clouded leopard", first: 0, live: live, lineage: ["animalia", "mammalia", "gone"]),
                                           record("Nobody", first: 1)],
                                          index: index, likedIDs: ["Clouded leopard"])
        XCTAssertEqual(items.map(\.id), ["Clouded leopard"])
        XCTAssertEqual(items[0].entry.lineageIDs, ["animalia", "mammalia"])
        XCTAssertEqual(items[0].entry.className, "Mammals")
        XCTAssertTrue(items[0].liked)
    }

    private var sample: [MetCollection.Item] {
        MetCollection.resolve([record("Snow leopard", first: 10, last: 50, saved: true),
                               record("Axolotl", first: 20, last: 30),
                               record("Smilodon fatalis", first: 30, last: 40),
                               record("Fennec fox", first: 5, last: 60)],
                              index: index, likedIDs: ["Axolotl", "Fennec fox"])
    }

    func testFilters() {
        XCTAssertEqual(MetCollection.filter(sample, by: .all).count, 4)
        XCTAssertEqual(MetCollection.filter(sample, by: .saved).map(\.id), ["Snow leopard"])
        XCTAssertEqual(MetCollection.filter(sample, by: .liked).map(\.id), ["Axolotl", "Fennec fox"])
        XCTAssertEqual(MetCollection.filter(sample, by: .extinct).map(\.id), ["Smilodon fatalis"])
    }

    func testSorts() {
        XCTAssertEqual(MetCollection.sort(sample, by: .recent).map(\.id),
                       ["Fennec fox", "Snow leopard", "Smilodon fatalis", "Axolotl"])
        XCTAssertEqual(MetCollection.sort(sample, by: .firstMet).map(\.id),
                       ["Fennec fox", "Snow leopard", "Axolotl", "Smilodon fatalis"])
        XCTAssertEqual(MetCollection.sort(sample, by: .name).map(\.id),
                       ["Axolotl", "Fennec fox", "Smilodon fatalis", "Snow leopard"])
        // Amphibians before Mammals, then by name inside each class.
        XCTAssertEqual(MetCollection.sort(sample, by: .group).map(\.id),
                       ["Axolotl", "Fennec fox", "Smilodon fatalis", "Snow leopard"])
    }

    func testSortIsStableOnTies() {
        let same = MetCollection.resolve([record("Snow leopard", first: 0), record("Axolotl", first: 0)],
                                         index: index, likedIDs: [])
        XCTAssertEqual(MetCollection.sort(same, by: .recent).map(\.id), ["Snow leopard", "Axolotl"])
    }
}
