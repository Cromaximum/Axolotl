import XCTest
@testable import AnimalScroller

final class AchievementsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "AchievementsStoreTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testSeenTiersPersistAndNeverGoDown() {
        let store = AchievementsStore(defaults: defaults)
        XCTAssertEqual(store.seenTiers, [:])
        store.markSeen(["overall": 2, "taxon:aves": 1])
        store.markSeen(["overall": 1])
        XCTAssertEqual(store.seenTiers, ["overall": 2, "taxon:aves": 1])
        XCTAssertEqual(AchievementsStore(defaults: defaults).seenTiers, ["overall": 2, "taxon:aves": 1])
    }

    func testCorruptDataStartsFresh() {
        defaults.set(Data("nope".utf8), forKey: AchievementsStore.key)
        XCTAssertEqual(AchievementsStore(defaults: defaults).seenTiers, [:])
    }
}
