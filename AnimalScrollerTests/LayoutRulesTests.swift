import XCTest
@testable import AnimalScroller

/// Logic behind the D-010 layout rules and the new stores.
final class LayoutRulesTests: XCTestCase {
    private func image(_ title: String, w: Int = 1080, h: Int = 1440, artwork: Bool = false, caption: String? = nil) -> LicensedImage {
        let fossil = ContentPolicy.isFossil(fileTitle: title, description: caption)
        return LicensedImage(fileTitle: title, url: URL(string: "https://example.org/x.jpg")!, width: w, height: h,
                      caption: caption,
                      attribution: Attribution(title: title, author: "A", license: "CC BY 4.0", licenseURL: nil,
                                               sourceURL: URL(string: "https://example.org")!),
                      isArtwork: artwork, isFossil: fossil)
    }

    private let living = Species(wikiTitle: "Okapi", commonName: "Okapi", scientificName: "Okapia johnstoni", status: .endangered)
    private let extinct = Species(wikiTitle: "Thylacine", commonName: "Thylacine", scientificName: "Thylacinus cynocephalus", status: .extinct)

    func testWideDetection() {
        XCTAssertTrue(image("a", w: 1600, h: 900).isWide)
        XCTAssertFalse(image("b", w: 900, h: 1200).isWide)
        XCTAssertFalse(image("c", w: 1000, h: 1000).isWide)
    }

    func testMediaTags() {
        XCTAssertNil(MediaTag.tag(for: image("File:Okapi.jpg"), species: living))
        XCTAssertEqual(MediaTag.tag(for: image("File:Thylacine 1933.jpg"), species: extinct), .historicalPhoto)
        XCTAssertEqual(MediaTag.tag(for: image("File:Thylacine skeleton.jpg"), species: extinct), .realFossil)
        XCTAssertEqual(MediaTag.tag(for: image("File:Thylacine restoration.jpg", artwork: true), species: extinct), .reconstruction)
    }

    func testCaptionsAreCutOnlyAtSentenceBoundaries() {
        XCTAssertEqual(ContentPolicy.wholeSentenceCaption("A thylacine at Hobart Zoo."), "A thylacine at Hobart Zoo.")
        let long = "First sentence about the specimen. " + String(repeating: "Second sentence goes on and on ", count: 10) + "end."
        XCTAssertEqual(ContentPolicy.wholeSentenceCaption(long), "First sentence about the specimen.")
        XCTAssertNil(ContentPolicy.wholeSentenceCaption(String(repeating: "word ", count: 60)))
    }

    func testLeadingNumber() {
        XCTAssertEqual(FactFormatting.leadingNumber(in: "Its eyes carry at least 12 kinds of colour receptor."), "12")
        XCTAssertEqual(FactFormatting.leadingNumber(in: "It can weigh up to 1,200 kg."), "1,200")
        XCTAssertNil(FactFormatting.leadingNumber(in: "The last one died in 1936 in Hobart."))
        XCTAssertNil(FactFormatting.leadingNumber(in: "It cannot roar."))
    }

    func testFactCardsCarryAPhoto() {
        let taxon = Taxon(id: "f", name: "F", scientificName: nil, rank: .family, children: nil, species: nil)
        let entry = SpeciesEntry(species: living, lineage: [taxon])
        let content = SpeciesContent(title: "Okapi", tagline: nil, lead: "Lead.",
                                     pageURL: URL(string: "https://en.wikipedia.org/wiki/Okapi")!,
                                     leadImageFileTitle: "File:0.jpg",
                                     facts: (0..<4).map { .init(topic: nil, text: "Fact \($0).") },
                                     images: (0..<3).map { image("File:\($0).jpg") })
        let cards = FeedComposer.cards(for: entry, content: content, sequence: 1, allowArtwork: false)
        let facts = cards.compactMap { card -> FactCard? in
            guard case .fact(let f) = card else { return nil }
            return f
        }
        XCTAssertFalse(facts.isEmpty)
        XCTAssertTrue(facts.allSatisfy { $0.image != nil })
    }

    func testPreferencesKeepOldDataWhenFieldsAreAdded() {
        let defaults = UserDefaults(suiteName: "test.prefs.\(UUID().uuidString)")!
        // Shape saved by the first version, before hasOnboarded existed.
        let old = #"{"selectedTaxonIDs":["aves"],"includeExtinct":false,"extinctOnly":false,"showArtwork":true,"surpriseMe":false}"#
        defaults.set(Data(old.utf8), forKey: "preferences.v1")
        let prefs = PreferencesStore(defaults: defaults)
        XCTAssertEqual(prefs.selectedTaxonIDs, ["aves"])
        XCTAssertFalse(prefs.surpriseMe)
        XCTAssertFalse(prefs.hasOnboarded)
        XCTAssertEqual(prefs.extinctMode, .livingOnly)
        prefs.extinctMode = .extinctOnly
        XCTAssertTrue(prefs.includeExtinct && prefs.extinctOnly)
    }

    func testMetStoreRecordsOnceAndSaves() {
        let defaults = UserDefaults(suiteName: "test.met.\(UUID().uuidString)")!
        let store = MetStore(defaults: defaults)
        store.recordMet(living, imageURL: nil)
        store.recordMet(living, imageURL: URL(string: "https://example.org/okapi.jpg"))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertNotNil(store.entries[0].imageURL)
        store.toggleSaved(living, imageURL: nil)
        XCTAssertTrue(MetStore(defaults: defaults).isSaved("Okapi"))
    }
}
