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

    func testRejectsSentencesThatNeedContext() {
        XCTAssertNil(FactExtractor.score("As a result, the population fell to fewer than 2,000 animals by the year 1990."))
        XCTAssertNil(FactExtractor.score("Later, the cubs leave their mother at around 18 to 22 months of age in the wild."))
        XCTAssertNil(FactExtractor.score("Some of these animals travel more than 40 km in a single night while hunting prey."))
    }

    func testRejectsCitationsListsAndTaxonomy() {
        XCTAssertNil(FactExtractor.score("Smith et al. measured 40 animals and found adults weighed 30 to 55 kg in the wild."))
        XCTAssertNil(FactExtractor.score("The diet includes ibex, marmots, pikas, hares, voles, birds and occasionally livestock."))
        XCTAssertNil(FactExtractor.score("The diet has three parts: wild sheep, smaller mammals and occasional livestock kills."))
        XCTAssertNil(FactExtractor.score("The snow leopard is a species of large cat in the genus Panthera native to Asia."))
        XCTAssertNil(FactExtractor.score("Hunting behaviour is described below in more detail, with notes on the seasons."))
    }

    func testPrefersMeasurementsAndPenalisesHedging() {
        let measured = FactExtractor.score("Snow leopards can leap up to 15 m in a single bound across rocky mountain slopes.")
        let vague = FactExtractor.score("Snow leopards are thought to leap quite far across the rocky mountain slopes of Asia.")
        XCTAssertNotNil(measured)
        XCTAssertNotNil(vague)
        XCTAssertGreaterThan(measured!, vague!)
        XCTAssertTrue(FactExtractor.hasMeasurement("The tail is 80 to 105 cm long."))
        XCTAssertTrue(FactExtractor.hasMeasurement("About 40% of cubs survive."))
        XCTAssertFalse(FactExtractor.hasMeasurement("It was seen in 2001 in Asia."))
    }

    func testDropsNearDuplicateFacts() {
        let text = """
        == Description ==
        The snow leopard's tail is 80 to 105 cm long and helps it keep its balance on rocky slopes.

        == Behaviour ==
        The snow leopard's long tail is 80 to 105 cm long and helps it keep its balance on slopes.
        """
        let facts = FactExtractor.facts(from: text)
        XCTAssertEqual(facts.count, 1)
    }

    func testFactsAreVerbatimSentencesFromTheArticle() {
        for fact in FactExtractor.facts(from: article) {
            XCTAssertTrue(article.contains(fact.text), "Fact text must be copied verbatim (D-011)")
        }
    }
}
