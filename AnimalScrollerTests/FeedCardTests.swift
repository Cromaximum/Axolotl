import XCTest
@testable import AnimalScroller

final class FeedCardTests: XCTestCase {
    private let entry = SpeciesEntry(
        species: Species(wikiTitle: "Test species", commonName: "Test species",
                         scientificName: "Testus testus", status: .leastConcern),
        lineage: [])

    private func image(_ name: String) -> LicensedImage {
        LicensedImage(fileTitle: "File:\(name).jpg", url: URL(string: "https://example.org/\(name).jpg")!,
                      width: 800, height: 1000, caption: nil,
                      attribution: Attribution(title: "File:\(name).jpg", author: "A", license: "CC BY 4.0",
                                               licenseURL: nil, sourceURL: URL(string: "https://example.org")!),
                      isArtwork: false)
    }

    private var credit: Attribution { .wikipediaText(title: "Test species", pageURL: URL(string: "https://example.org")!) }

    func testPlacementDefaultsToSingleAndCanBeStamped() {
        let card = FeedCard.photo(PhotoCard(entry: entry, sequence: 1, image: image("a")))
        XCTAssertEqual(card.placement, .single)

        let placed = card.placed(CardPlacement(position: 3, count: 5))
        XCTAssertEqual(placed.placement, CardPlacement(position: 3, count: 5))
        XCTAssertEqual(placed.id, card.id, "placement must not change identity")
    }

    func testPlacementOnEveryKind() {
        let cards: [FeedCard] = [
            .intro(IntroCard(entry: entry, sequence: 1, tagline: nil, lead: "", didYouKnow: nil,
                             hero: nil, textAttribution: credit)),
            .fact(FactCard(entry: entry, sequence: 1, index: 0, total: 1, topic: nil, text: "",
                           attribution: credit, image: nil)),
            .photo(PhotoCard(entry: entry, sequence: 1, image: image("b"))),
        ]
        for card in cards {
            XCTAssertEqual(card.placed(CardPlacement(position: 2, count: 3)).placement.position, 2)
        }
    }

    func testPrimaryImage() {
        let hero = image("hero")
        XCTAssertEqual(FeedCard.intro(IntroCard(entry: entry, sequence: 1, tagline: nil, lead: "",
                                                didYouKnow: nil, hero: hero, textAttribution: credit)).primaryImage, hero)
        XCTAssertNil(FeedCard.fact(FactCard(entry: entry, sequence: 1, index: 0, total: 1, topic: nil, text: "",
                                            attribution: credit, image: nil)).primaryImage)
        XCTAssertEqual(FeedCard.photo(PhotoCard(entry: entry, sequence: 1, image: hero)).primaryImage, hero)
    }
}
