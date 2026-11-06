import XCTest
@testable import AnimalScroller

/// Likes: persisted, and they steer tailored picks toward relatives of liked species.
final class LikesTests: XCTestCase {
    private func family(_ id: String) -> Taxon {
        Taxon(id: id, name: id, scientificName: id, rank: .family, children: nil, species: nil)
    }

    private func entries(_ fam: String, _ n: Int) -> [SpeciesEntry] {
        let f = family(fam)
        return (0..<n).map {
            SpeciesEntry(species: Species(wikiTitle: "\(fam)\($0)", commonName: "", scientificName: "", status: .leastConcern),
                         lineage: [f])
        }
    }

    func testAffinityCreditsCloseRelativesMost() {
        let lineage: [LikeAffinity.Step] = [.init(id: "mammalia", rank: .class), .init(id: "carnivora", rank: .order),
                                            .init(id: "felidae", rank: .family), .init(id: "gbif-genus-panthera", rank: .genus)]
        let a = LikeAffinity.affinity(lineages: [lineage, lineage])
        XCTAssertEqual(a["felidae"], 4.0)
        XCTAssertGreaterThan(a["gbif-genus-panthera"]!, a["felidae"]!)
        XCTAssertGreaterThan(a["carnivora"]!, a["mammalia"]!)
    }

    func testLikesTiltTailoredPicksTowardLikedFamily() {
        let cats = entries("felidae", 20), dogs = entries("canidae", 20)
        var picker = SpeciesPicker(discoveryShare: 0)
        picker.likeAffinity = LikeAffinity.affinity(lineages: [[.init(id: "felidae", rank: .family)]])
        var rng = SeededRNG(state: 11)
        var catPicks = 0
        for _ in 0..<400 {
            if picker.next(tailored: cats + dogs, everything: cats + dogs, using: &rng)!.id.hasPrefix("felidae") { catPicks += 1 }
        }
        XCTAssertGreaterThan(Double(catPicks) / 400, 0.6, "a like should clearly tilt the mix")
        XCTAssertLessThan(Double(catPicks) / 400, 0.95, "but never shut other families out")
    }

    func testLikesNeverAffectDiscoveryShare() {
        let mine = entries("felidae", 30), other = entries("aves", 30)
        var picker = SpeciesPicker(discoveryShare: 0.3)
        picker.likeAffinity = ["felidae": 50]
        var rng = SeededRNG(state: 5)
        var outside = 0
        for _ in 0..<1000 {
            if picker.next(tailored: mine, everything: mine + other, using: &rng)!.id.hasPrefix("aves") { outside += 1 }
        }
        XCTAssertEqual(Double(outside) / 1000, 0.3, accuracy: 0.05)
    }

    func testLikedBranchIsSearchedMoreOften() {
        let a = family("felidae"), b = family("canidae")
        var picker = SpeciesPicker(discoveryShare: 0)
        picker.likeAffinity = ["felidae": 4]
        var rng = SeededRNG(state: 9)
        var hits = 0
        for _ in 0..<500 {
            if picker.pickBranch(inside: [a, b], outside: [], using: &rng)!.branch.id == "felidae" { hits += 1 }
        }
        XCTAssertGreaterThan(hits, 300)
    }

    func testStorePersistsAndDoubleTapNeverUnlikes() {
        let defaults = UserDefaults(suiteName: "LikesTests-\(UUID().uuidString)")!
        let store = LikesStore(defaults: defaults)
        let entry = entries("felidae", 1)[0]
        store.like(entry, imageURL: nil)
        store.like(entry, imageURL: nil)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.affinity["felidae"], LikeAffinity.weight(for: .family))

        let reloaded = LikesStore(defaults: defaults)
        XCTAssertTrue(reloaded.isLiked(entry.id))
        reloaded.toggle(entry, imageURL: nil)
        XCTAssertFalse(reloaded.isLiked(entry.id))
        XCTAssertTrue(reloaded.affinity.isEmpty)
    }
}
