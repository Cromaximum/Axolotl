import XCTest
@testable import AnimalScroller

/// Deterministic RNG so selection tests are repeatable.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class SpeciesPickerTests: XCTestCase {
    private func entries(_ prefix: String, _ n: Int) -> [SpeciesEntry] {
        let family = Taxon(id: prefix, name: prefix, scientificName: nil, rank: .family, children: nil, species: nil)
        return (0..<n).map {
            SpeciesEntry(species: Species(wikiTitle: "\(prefix)\($0)", commonName: "", scientificName: "", status: .leastConcern),
                         lineage: [family])
        }
    }

    func testMixesTailoredAndDiscoveryRoughly70_30() {
        let mine = entries("mine", 30), other = entries("other", 30)
        var picker = SpeciesPicker(discoveryShare: 0.3)
        var rng = SeededRNG(state: 42)
        var outside = 0
        for _ in 0..<1000 {
            let pick = picker.next(tailored: mine, everything: mine + other, using: &rng)!
            if pick.id.hasPrefix("other") { outside += 1 }
        }
        XCTAssertEqual(Double(outside) / 1000, 0.3, accuracy: 0.05)
    }

    func testPrefersUnseenAndAvoidsRecentRepeats() {
        let mine = entries("mine", 20)
        var picker = SpeciesPicker(discoveryShare: 0)
        var rng = SeededRNG(state: 7)
        var firstTwenty: [String] = []
        for _ in 0..<12 { firstTwenty.append(picker.next(tailored: mine, everything: mine, using: &rng)!.id) }
        XCTAssertEqual(Set(firstTwenty).count, 12, "no repeats inside the recent window")
    }

    func testNeverReturnsBroadGroups() {
        // The picker only ever hands back SpeciesEntry values; this guards the empty case.
        var picker = SpeciesPicker()
        XCTAssertNil(picker.next(tailored: [], everything: []))
    }

    /// Species under class > order > family, so variety rules can be checked.
    private func tree(_ cls: String, orders: Int, familiesPerOrder: Int, speciesPerFamily: Int) -> [SpeciesEntry] {
        let c = Taxon(id: cls, name: cls, scientificName: nil, rank: .class, children: nil, species: nil)
        var out: [SpeciesEntry] = []
        for o in 0..<orders {
            let order = Taxon(id: "\(cls)-o\(o)", name: "", scientificName: nil, rank: .order, children: nil, species: nil)
            for f in 0..<familiesPerOrder {
                let family = Taxon(id: "\(cls)-o\(o)-f\(f)", name: "", scientificName: nil, rank: .family, children: nil, species: nil)
                for n in 0..<speciesPerFamily {
                    out.append(SpeciesEntry(species: Species(wikiTitle: "\(family.id)-s\(n)", commonName: "", scientificName: "",
                                                             status: .leastConcern),
                                            lineage: [c, order, family]))
                }
            }
        }
        return out
    }

    func testNeverTheSameFamilyBackToBack() {
        let pool = tree("mammals", orders: 3, familiesPerOrder: 3, speciesPerFamily: 6)
        var picker = SpeciesPicker(discoveryShare: 0.3)
        var rng = SeededRNG(state: 11)
        var lastFamily: String?
        for _ in 0..<1000 {
            let pick = picker.next(tailored: pool, everything: pool, using: &rng)!
            let family = pick.lineage.last!.id
            XCTAssertNotEqual(family, lastFamily)
            lastFamily = family
        }
    }

    func testFallsBackWhenOnlyOneFamilyIsLeft() {
        let pool = tree("mammals", orders: 1, familiesPerOrder: 1, speciesPerFamily: 5)
        var picker = SpeciesPicker(discoveryShare: 0)
        var rng = SeededRNG(state: 3)
        for _ in 0..<20 { XCTAssertNotNil(picker.next(tailored: pool, everything: pool, using: &rng)) }
    }

    func testDiscoveryGivesSmallClassesAFairShare() {
        let big = tree("big", orders: 4, familiesPerOrder: 4, speciesPerFamily: 4)      // 64 species
        let small = tree("small", orders: 1, familiesPerOrder: 2, speciesPerFamily: 2)  // 4 species
        var rng = SeededRNG(state: 5)
        var fromSmall = 0
        // First pick of 1,000 fresh feeds, so novelty and recent-repeat rules don't interfere.
        for _ in 0..<1000 {
            var picker = SpeciesPicker(discoveryShare: 1)
            let pick = picker.next(tailored: [], everything: big + small, using: &rng)!
            if pick.lineage.first!.id == "small" { fromSmall += 1 }
        }
        // Uniform over species would give about 6% (4 of 68); the square-root spread gives about 20%.
        XCTAssertGreaterThan(fromSmall, 120)
    }

    func testDefaultDiscoveryShareIs30Percent() {
        XCTAssertEqual(SpeciesPicker().discoveryShare, 0.3)
    }
}
