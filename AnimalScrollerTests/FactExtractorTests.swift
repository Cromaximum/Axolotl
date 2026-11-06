import XCTest
@testable import AnimalScroller

final class FactExtractorTests: XCTestCase {
    let article = """
    The snow leopard is a species of large cat in the genus Panthera native to the mountain ranges of Central and South Asia.

    == Etymology ==
    The Old French word once used for this animal was later applied to a different species entirely, which confuses readers.

    == Description ==
    The snow leopard's tail is 80 to 105 cm long and helps it keep its balance on steep, rocky slopes.
    It has a thick fur coat.
    Snow leopards cannot roar, unlike most other big cats, because of the structure of the larynx.

    == References ==
    Smith, J. (2001). A long reference title that should never be used as a fact in the app at all.
    """

    func testPicksFactsFromGoodSectionsOnly() {
        let facts = FactExtractor.facts(from: article)
        XCTAssertTrue(facts.contains { $0.text.hasPrefix("The snow leopard's tail is 80") })
        XCTAssertTrue(facts.contains { $0.text.hasPrefix("Snow leopards cannot roar") })
        XCTAssertFalse(facts.contains { $0.topic == "References" || $0.topic == "Etymology" })
        XCTAssertFalse(facts.contains { $0.text.hasPrefix("It has") }) // too short and dangling
    }
}
