import XCTest
@testable import AnimalScroller

final class CachingContentProviderTests: XCTestCase {
    private var directory: URL!
    private let species = Species(wikiTitle: "Test species", commonName: "Test species",
                                  scientificName: "Testus testus", status: .leastConcern)

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        directory = try XCTUnwrap(CachingContentProvider.prepareDirectory(in: root, fileManager: .default))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    func testSecondCallIsAMemoryHit() async throws {
        let upstream = FakeProvider()
        let cache = CachingContentProvider(upstream: upstream, directory: directory)
        _ = try await cache.content(for: species)
        _ = try await cache.content(for: species)
        let calls = await upstream.calls
        XCTAssertEqual(calls, 1)
    }

    func testRelaunchIsADiskHit() async throws {
        let first = FakeProvider()
        _ = try await CachingContentProvider(upstream: first, directory: directory).content(for: species)

        let second = FakeProvider()
        let content = try await CachingContentProvider(upstream: second, directory: directory).content(for: species)
        let calls = await second.calls
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(content.title, species.wikiTitle)
    }

    func testConcurrentCallsFetchOnce() async throws {
        let upstream = FakeProvider(delay: .milliseconds(100))
        let cache = CachingContentProvider(upstream: upstream, directory: nil)
        async let a = cache.content(for: species)
        async let b = cache.content(for: species)
        _ = try await (a, b)
        let calls = await upstream.calls
        XCTAssertEqual(calls, 1)
    }

    func testStaleIsRefetched() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
        _ = try await CachingContentProvider(upstream: FakeProvider(), directory: directory,
                                             now: { clock.now }).content(for: species)
        clock.now = clock.now.addingTimeInterval(ContentCachePolicy.freshFor + 1)

        let upstream = FakeProvider()
        _ = try await CachingContentProvider(upstream: upstream, directory: directory,
                                             now: { clock.now }).content(for: species)
        let calls = await upstream.calls
        XCTAssertEqual(calls, 1)
    }

    func testStaleBeatsOffline() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
        _ = try await CachingContentProvider(upstream: FakeProvider(), directory: directory,
                                             now: { clock.now }).content(for: species)
        clock.now = clock.now.addingTimeInterval(ContentCachePolicy.freshFor * 3)

        let offline = FakeProvider(fails: true)
        let content = try await CachingContentProvider(upstream: offline, directory: directory,
                                                       now: { clock.now }).content(for: species)
        XCTAssertEqual(content.title, species.wikiTitle)
    }

    func testOfflineWithNoCacheThrows() async {
        let cache = CachingContentProvider(upstream: FakeProvider(fails: true), directory: directory)
        do {
            _ = try await cache.content(for: species)
            XCTFail("expected an error")
        } catch {}
    }

    func testPrepareDirectoryRemovesOldVersions() throws {
        let root = directory.deletingLastPathComponent()
        let old = root.appendingPathComponent("species-content.v0", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        _ = CachingContentProvider.prepareDirectory(in: root, fileManager: .default)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    // MARK: Fakes

    static func sampleContent(title: String) -> SpeciesContent {
        SpeciesContent(title: title, tagline: nil, lead: "Lead.", pageURL: URL(string: "https://example.org")!,
                       leadImageFileTitle: nil, facts: [], images: [])
    }

    private actor FakeProvider: SpeciesContentProvider {
        private(set) var calls = 0
        let delay: Duration
        let fails: Bool

        init(delay: Duration = .zero, fails: Bool = false) {
            self.delay = delay
            self.fails = fails
        }

        func content(for species: Species) async throws -> SpeciesContent {
            calls += 1
            if delay > .zero { try await Task.sleep(for: delay) }
            if fails { throw URLError(.notConnectedToInternet) }
            return CachingContentProviderTests.sampleContent(title: species.wikiTitle)
        }
    }

    private final class TestClock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }
}
