import XCTest
@testable import AnimalScroller

final class ContentCachePolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshness() {
        XCTAssertTrue(ContentCachePolicy.isFresh(fetchedAt: now, now: now))
        XCTAssertTrue(ContentCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-6 * 86_400), now: now))
        XCTAssertFalse(ContentCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-8 * 86_400), now: now))
        // Clock moved backwards a lot: treat as stale rather than trusting it forever.
        XCTAssertFalse(ContentCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(3_600), now: now))
    }

    func testFileNamesAreStableSafeAndDistinct() {
        let titles = ["Snow leopard", "AC/DC", "Ærø", String(repeating: "x", count: 400), "Snow leopard "]
        let names = titles.map(ContentCachePolicy.fileName(forWikiTitle:))
        XCTAssertEqual(Set(names).count, titles.count)
        for name in names {
            XCTAssertEqual(name.count, 21) // 16 hex + ".json"
            XCTAssertFalse(name.contains("/"))
        }
        XCTAssertEqual(ContentCachePolicy.fileName(forWikiTitle: "Snow leopard"),
                       ContentCachePolicy.fileName(forWikiTitle: "Snow leopard"))
    }

    func testUsableNeedsSchemaAndTitle() {
        let content = CachingContentProviderTests.sampleContent(title: "A")
        let good = ContentCachePolicy.Entry(schema: ContentCachePolicy.schema, wikiTitle: "A", fetchedAt: now, content: content)
        let oldSchema = ContentCachePolicy.Entry(schema: ContentCachePolicy.schema + 1, wikiTitle: "A", fetchedAt: now, content: content)
        XCTAssertTrue(ContentCachePolicy.isUsable(good, wikiTitle: "A"))
        XCTAssertFalse(ContentCachePolicy.isUsable(good, wikiTitle: "B"))
        XCTAssertFalse(ContentCachePolicy.isUsable(oldSchema, wikiTitle: "A"))
    }

    func testOutdatedDirectories() {
        XCTAssertFalse(ContentCachePolicy.isOutdatedDirectory(named: ContentCachePolicy.directoryName))
        XCTAssertTrue(ContentCachePolicy.isOutdatedDirectory(named: "species-content.v0"))
        XCTAssertFalse(ContentCachePolicy.isOutdatedDirectory(named: "Snapshots"))
    }
}
