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
}
