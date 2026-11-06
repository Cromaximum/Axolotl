import XCTest
@testable import AnimalScroller

final class MetStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "MetStoreTests"
    private var clock = Date(timeIntervalSince1970: 2_000_000)

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func makeStore() -> MetStore { MetStore(defaults: defaults, now: { [unowned self] in self.clock }) }

    private func entry(_ title: String, live: Bool = false) -> SpeciesEntry {
        var s = TreeFixture.species(title, "Sci \(title)")
        if live { s.gbifKey = 7 }
        return SpeciesEntry(species: s, lineage: [TreeFixture.root, TreeFixture.mammalia])
    }

    func testBundledSpeciesKeepOnlyIDsAndDates() {
        let store = makeStore()
        store.recordMet(entry("Snow leopard"))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertNil(store.entries[0].live)
        XCTAssertEqual(store.entries[0].firstMet, clock)
    }

    func testLiveSpeciesKeepTheirRecordAndLineage() {
        let store = makeStore()
        store.recordMet(entry("Clouded leopard", live: true))
        XCTAssertEqual(store.entries[0].live?.lineageIDs, ["animalia", "mammalia"])
        // The deprecated forwarder passes no lineage and must not erase it.
        store.recordMet(SpeciesEntry(species: entry("Clouded leopard", live: true).species, lineage: []))
        XCTAssertEqual(store.entries[0].live?.lineageIDs, ["animalia", "mammalia"])
    }

    func testToggleSavedKeepsFirstMetAndPersists() {
        let store = makeStore()
        store.recordMet(entry("Axolotl"))
        let first = clock
        clock += 100
        store.toggleSaved(entry("Axolotl"))
        XCTAssertTrue(store.isSaved("Axolotl"))
        XCTAssertEqual(store.entries[0].firstMet, first)
        XCTAssertEqual(store.entries[0].savedAt, clock)

        let reloaded = makeStore()
        XCTAssertTrue(reloaded.isSaved("Axolotl"))
        XCTAssertEqual(reloaded.entries[0].firstMet, first)
    }

    func testRecordMetUpdatesLastMet() {
        let store = makeStore()
        store.recordMet(entry("Axolotl"))
        clock += 60
        store.recordMet(entry("Axolotl"))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].lastMet, clock)
        XCTAssertLessThan(store.entries[0].firstMet, store.entries[0].lastMet)
    }

    func testMigratesV1AndForgetsBundledCopies() throws {
        let v1 = """
        [{"id":"Axolotl","commonName":"Axolotl","scientificName":"Ambystoma mexicanum","isExtinct":false,
          "firstMet":100,"saved":true},
         {"id":"Dodo","commonName":"Dodo","scientificName":"Raphus cucullatus","isExtinct":true,
          "imageURL":"https://upload.wikimedia.org/x.jpg","firstMet":50,"saved":false},
         {"broken":true}]
        """
        defaults.set(Data(v1.utf8), forKey: MetStore.legacyKey)

        let store = makeStore()
        XCTAssertNil(defaults.data(forKey: MetStore.legacyKey))
        XCTAssertNotNil(defaults.data(forKey: MetStore.key))
        XCTAssertEqual(store.entries.map(\.id), ["Axolotl", "Dodo"])
        XCTAssertTrue(store.isSaved("Axolotl"))
        XCTAssertEqual(store.entries[0].lastMet, store.entries[0].firstMet)
        XCTAssertEqual(store.entries[1].live?.species.status, .extinct)
        XCTAssertEqual(store.entries[0].live?.species.status, .notEvaluated, "never infer a status")

        store.forgetCopies(of: ["Axolotl"])
        XCTAssertNil(store.entries[0].live)
        XCTAssertNotNil(store.entries[1].live)
        XCTAssertNil(makeStore().entries[0].live)
    }

    func testV2DecodeToleratesMissingFields() {
        let v2 = #"[{"id":"Axolotl","firstMet":10}]"#
        defaults.set(Data(v2.utf8), forKey: MetStore.key)
        let store = makeStore()
        XCTAssertEqual(store.entries.first?.lastMet, store.entries.first?.firstMet)
        XCTAssertEqual(store.isSaved("Axolotl"), false)
    }
}
