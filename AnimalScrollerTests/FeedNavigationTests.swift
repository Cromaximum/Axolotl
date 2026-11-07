import XCTest
@testable import AnimalScroller

final class FeedNavigationTests: XCTestCase {
    private func entry(_ title: String) -> SpeciesEntry {
        SpeciesEntry(species: TreeFixture.species(title, "Sci \(title)"), lineage: [TreeFixture.root])
    }

    private func image(_ n: Int) -> LicensedImage {
        LicensedImage(fileTitle: "File:\(n).jpg", url: URL(string: "https://example.org/\(n).jpg")!,
                      width: 1080, height: 1920, caption: nil,
                      attribution: Attribution(title: "File:\(n).jpg", author: "A", license: "CC BY 4.0",
                                               licenseURL: nil, sourceURL: URL(string: "https://example.org")!),
                      isArtwork: false)
    }

    private func set(_ title: String, sequence: Int, photos: Int) -> [FeedCard] {
        let e = entry(title)
        let intro = IntroCard(entry: e, sequence: sequence, tagline: nil, lead: "Lead.", didYouKnow: nil,
                              hero: image(sequence * 100),
                              textAttribution: Attribution.wikipediaText(
                                title: title, pageURL: URL(string: "https://en.wikipedia.org/wiki/X")!))
        return [.intro(intro)] + (0..<photos).map {
            .photo(PhotoCard(entry: e, sequence: sequence, image: image(sequence * 100 + $0 + 1)))
        }
    }

    func testNextSetStartIsTheNextSpeciesIntro() {
        let cards = set("Okapi", sequence: 1, photos: 3) + set("Shoebill", sequence: 2, photos: 2)
        for card in cards.prefix(4) {
            XCTAssertEqual(FeedNavigation.nextSetStart(after: card.id, in: cards)?.id, cards[4].id)
        }
        XCTAssertNil(FeedNavigation.nextSetStart(after: cards[4].id, in: cards),
                     "the next species hasn't loaded yet")
        XCTAssertNil(FeedNavigation.nextSetStart(after: "missing", in: cards))
    }

    func testSameSpeciesShownAgainIsStillANewSet() {
        let cards = set("Okapi", sequence: 1, photos: 1) + set("Okapi", sequence: 5, photos: 1)
        XCTAssertEqual(FeedNavigation.nextSetStart(after: cards[0].id, in: cards)?.id, cards[2].id)
    }

    func testFirstMeetingNumber() {
        // Never met: next number after everything met so far.
        XCTAssertEqual(FeedNavigation.firstMeetingNumber(for: "a#1", known: [:], alreadyMet: false, metCount: 42), 43)
        // Met before this session: no badge.
        XCTAssertNil(FeedNavigation.firstMeetingNumber(for: "a#1", known: [:], alreadyMet: true, metCount: 42))
        // Met just now in this set: the badge keeps its number.
        XCTAssertEqual(FeedNavigation.firstMeetingNumber(for: "a#1", known: ["a#1": 43], alreadyMet: true, metCount: 43), 43)
        // The same species in a later set: no second badge.
        XCTAssertNil(FeedNavigation.firstMeetingNumber(for: "a#7", known: ["a#1": 43], alreadyMet: true, metCount: 50))
    }

    func testMetStoreHasMet() {
        let defaults = UserDefaults(suiteName: "test.nav.\(UUID().uuidString)")!
        let met = MetStore(defaults: defaults)
        XCTAssertFalse(met.hasMet(entry("Okapi").id))
        met.recordMet(entry("Okapi"))
        XCTAssertTrue(met.hasMet(entry("Okapi").id))
    }

    func testSwipeHintFlagPersistsAndDefaultsOff() {
        let defaults = UserDefaults(suiteName: "test.hint.\(UUID().uuidString)")!
        // Saved before the flag existed: decodes, hint not seen yet.
        defaults.set(Data(#"{"selectedTaxonIDs":[],"hasOnboarded":true}"#.utf8), forKey: "preferences.v1")
        let prefs = PreferencesStore(defaults: defaults)
        XCTAssertTrue(prefs.hasOnboarded)
        XCTAssertFalse(prefs.hasSeenSwipeHint)
        prefs.hasSeenSwipeHint = true
        XCTAssertTrue(PreferencesStore(defaults: defaults).hasSeenSwipeHint)
    }
}
