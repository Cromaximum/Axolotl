import XCTest
@testable import AnimalScroller

final class SpeciesProfileBuilderTests: XCTestCase {
    typealias Claim = SpeciesProfileBuilder.Claim

    private func input(_ claims: [String: [Claim]], labels: [String: String] = [:]) -> SpeciesProfileBuilder.Input {
        .init(wikidataID: "Q30197", claims: claims, labels: labels)
    }

    func testBuildsRowsFromWikidataInOrder() {
        let profile = SpeciesProfileBuilder.profile(input: input([
            "P2067": [Claim(amount: "+55", unitID: "Q11570"), Claim(amount: "+25", unitID: "Q11570")],
            "P9714": [Claim(itemID: "Q1"), Claim(itemID: "Q2"), Claim(itemID: "Q3"), Claim(itemID: "Q4")],
            "P1034": [Claim(itemID: "Q10")],
            "P2043": [Claim(amount: "+1.3", unitID: "Q11573")],
        ], labels: ["Q1": "Mongolia", "Q2": "Nepal", "Q3": "India", "Q4": "Bhutan", "Q10": "Siberian ibex"]),
            article: "")
        XCTAssertEqual(profile?.rows.map(\.kind), [.livesIn, .eats, .length, .weight])
        XCTAssertEqual(profile?.rows.map(\.text), ["Mongolia, Nepal, India", "Siberian ibex", "1.3 m", "25–55 kg"])
        XCTAssertTrue(profile?.rows.allSatisfy { $0.source == .wikidata } ?? false)
        XCTAssertEqual(profile?.wikidataID, "Q30197")
    }

    func testSkipsNonAdultAndDeprecatedValues() {
        let text = SpeciesProfileBuilder.quantity("P2067", units: SpeciesProfileBuilder.massUnits, input([
            "P2067": [Claim(amount: "+6", unitID: "Q41803", roleIDs: ["Q5"]),
                      Claim(amount: "+32.5", unitID: "Q41803"),
                      Claim(amount: "+99", unitID: "Q41803", rank: "deprecated")],
        ], labels: ["Q5": "newborn"]))
        XCTAssertEqual(text, "32.5 g")
    }

    func testPrefersPreferredStatementsAndSkipsUnknownUnitsAndUnlabelledItems() {
        XCTAssertEqual(SpeciesProfileBuilder.itemList(["P1034"], input([
            "P1034": [Claim(itemID: "Q1"), Claim(itemID: "Q2", rank: "preferred")],
        ], labels: ["Q1": "Grass", "Q2": "Krill"])), "Krill")
        XCTAssertNil(SpeciesProfileBuilder.itemList(["P1034"], input(["P1034": [Claim(itemID: "Q9")]])))
        XCTAssertNil(SpeciesProfileBuilder.quantity("P2067", units: SpeciesProfileBuilder.massUnits,
                                                    input(["P2067": [Claim(amount: "+3", unitID: "Q999")]])))
    }

    let article = """
    == Description ==
    It is a large animal with thick fur.
    Adults weigh 25 to 55 kg (55 to 121 lb).
    The body is 75 to 150 cm long, with a long tail.

    == Distribution and habitat ==
    The snow leopard lives in the mountains of Central and South Asia.

    == Diet ==
    The snow leopard is a carnivore and actively hunts its prey, mostly wild sheep and goats, over long distances in steep terrain.
    """

    func testFallsBackToShortVerbatimSentences() {
        let profile = SpeciesProfileBuilder.profile(input: nil, article: article)!
        let byKind = Dictionary(uniqueKeysWithValues: profile.rows.map { ($0.kind, $0) })
        XCTAssertEqual(byKind[.livesIn]?.text, "The snow leopard lives in the mountains of Central and South Asia.")
        XCTAssertEqual(byKind[.weight]?.text, "Adults weigh 25 to 55 kg (55 to 121 lb).")
        XCTAssertEqual(byKind[.size]?.text, "The body is 75 to 150 cm long, with a long tail.")
        XCTAssertNil(byKind[.eats], "the diet sentence is longer than the limit, so no row")
        for row in profile.rows {
            XCTAssertEqual(row.source, .wikipedia)
            XCTAssertTrue(article.contains(row.text), "verbatim (D-011)")
            XCTAssertLessThanOrEqual(row.text.count, SpeciesProfileBuilder.maxSentenceLength)
        }
        XCTAssertNil(profile.wikidataID)
    }

    func testWikidataWinsOverTheArticleAndNothingMeansNoSheet() {
        let profile = SpeciesProfileBuilder.profile(
            input: input(["P2067": [Claim(amount: "+40", unitID: "Q11570")]]), article: article)!
        XCTAssertEqual(profile.rows.first { $0.kind == .weight }?.text, "40 kg")
        XCTAssertEqual(profile.rows.filter { $0.kind == .weight }.count, 1)
        XCTAssertNil(SpeciesProfileBuilder.profile(input: input([:]), article: ""))
    }

    func testComposerShowsTheSheetAndKeepsEveryFactForCards() {
        let taxon = Taxon(id: "felidae", name: "Cats", scientificName: "Felidae", rank: .family, children: nil, species: nil)
        let entry = SpeciesEntry(species: Species(wikiTitle: "Snow leopard", commonName: "Snow leopard",
                                                  scientificName: "Panthera uncia", status: .vulnerable),
                                 lineage: [taxon])
        func image(_ n: Int) -> LicensedImage {
            LicensedImage(fileTitle: "File:\(n).jpg", url: URL(string: "https://example.org/\(n).jpg")!,
                          width: 1080, height: 720, caption: nil,
                          attribution: Attribution(title: "File:\(n).jpg", author: nil, license: "CC BY 4.0",
                                                   licenseURL: nil, sourceURL: URL(string: "https://example.org")!),
                          isArtwork: false)
        }
        var content = SpeciesContent(title: "Snow leopard", tagline: nil, lead: "Lead.",
                                     pageURL: URL(string: "https://en.wikipedia.org/wiki/Snow_leopard")!,
                                     leadImageFileTitle: "File:0.jpg",
                                     facts: [.init(topic: "Diet", text: "Fact A."), .init(topic: "Diet", text: "Fact B.")],
                                     images: (0..<5).map(image))
        content.profile = SpeciesProfile(rows: [.init(kind: .weight, text: "40 kg", source: .wikidata)], wikidataID: "Q30197")
        let cards = FeedComposer.cards(for: entry, content: content, sequence: 1, allowArtwork: false)
        guard case .intro(let intro) = cards[0] else { return XCTFail() }
        XCTAssertNotNil(intro.profile)
        XCTAssertNil(intro.didYouKnow)
        let factTexts = cards.compactMap { card -> String? in
            guard case .fact(let f) = card else { return nil }
            return f.text
        }
        XCTAssertEqual(factTexts, ["Fact A.", "Fact B."])
    }
}
