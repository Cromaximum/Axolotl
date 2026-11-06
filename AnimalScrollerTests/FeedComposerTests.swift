import XCTest
@testable import AnimalScroller

final class FeedComposerTests: XCTestCase {
    private let taxon = Taxon(id: "felidae", name: "Cats", scientificName: "Felidae", rank: .family, children: nil, species: nil)
    private var entry: SpeciesEntry {
        SpeciesEntry(species: Species(wikiTitle: "Snow leopard", commonName: "Snow leopard",
                                      scientificName: "Panthera uncia", status: .vulnerable),
                     lineage: [taxon])
    }

    private func image(_ n: Int, artwork: Bool = false) -> LicensedImage {
        LicensedImage(fileTitle: "File:\(n).jpg", url: URL(string: "https://example.org/\(n).jpg")!,
                      width: 1080, height: 720, caption: nil,
                      attribution: Attribution(title: "File:\(n).jpg", author: "A", license: "CC BY 4.0",
                                               licenseURL: nil, sourceURL: URL(string: "https://example.org")!),
                      isArtwork: artwork)
    }

    private func content(facts: Int, images: Int, artwork: Int = 0) -> SpeciesContent {
        SpeciesContent(title: "Snow leopard", tagline: "Species of big cat", lead: "Lead.",
                       pageURL: URL(string: "https://en.wikipedia.org/wiki/Snow_leopard")!,
                       leadImageFileTitle: "File:0.jpg",
                       facts: (0..<facts).map { .init(topic: "Description", text: "Fact \($0).") },
                       images: (0..<images).map { image($0) } + (0..<artwork).map { image(100 + $0, artwork: true) })
    }

    func testStartsWithIntroAndNeverPutsTwoFactsTogether() {
        for (f, i) in [(10, 2), (2, 10), (0, 5), (5, 0), (6, 6), (1, 1)] {
            let cards = FeedComposer.cards(for: entry, content: content(facts: f, images: i), sequence: 1, allowArtwork: false)
            guard case .intro = cards.first else { return XCTFail("first card must be intro") }
            XCTAssertLessThanOrEqual(cards.count - 1, FeedComposer.maxItems)
            for (a, b) in zip(cards, cards.dropFirst()) {
                if case .fact = a, case .fact = b { XCTFail("two facts in a row for \(f) facts, \(i) images") }
            }
        }
    }

    func testHeroIsLeadImageAndNotRepeated() {
        let cards = FeedComposer.cards(for: entry, content: content(facts: 3, images: 4), sequence: 1, allowArtwork: false)
        guard case .intro(let intro) = cards[0] else { return XCTFail() }
        XCTAssertEqual(intro.hero?.fileTitle, "File:0.jpg")
        XCTAssertEqual(intro.didYouKnow, "Fact 0.")
        let photoTitles: [String] = cards.compactMap { card -> String? in
            guard case .photo(let p) = card else { return nil }
            return p.image.fileTitle
        }
        XCTAssertFalse(photoTitles.contains("File:0.jpg"))
    }

    func testArtworkOnlyForExtinctSpeciesWhenAllowed() {
        let c = content(facts: 2, images: 1, artwork: 3)
        let extinct = SpeciesEntry(species: Species(wikiTitle: "Smilodon", commonName: "Smilodon",
                                                    scientificName: "Smilodon fatalis", status: .extinct),
                                   lineage: [taxon])
        let without = FeedComposer.cards(for: extinct, content: c, sequence: 1, allowArtwork: false)
        let with = FeedComposer.cards(for: extinct, content: c, sequence: 1, allowArtwork: true)
        let living = FeedComposer.cards(for: entry, content: c, sequence: 1, allowArtwork: true)
        func artworkCount(_ cards: [FeedCard]) -> Int {
            cards.filter { card in
                guard case .photo(let p) = card else { return false }
                return p.image.isArtwork
            }.count
        }
        XCTAssertEqual(artworkCount(without), 0)
        XCTAssertEqual(artworkCount(with), 3)
        XCTAssertEqual(artworkCount(living), 0)
    }
}
