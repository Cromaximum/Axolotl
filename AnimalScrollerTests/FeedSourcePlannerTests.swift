import XCTest
@testable import AnimalScroller

final class FeedSourcePlannerTests: XCTestCase {
    func testLiveOffAlwaysBundled() {
        for attempt in 0..<FeedSourcePlanner.attempts {
            XCTAssertEqual(FeedSourcePlanner.sources(attempt: attempt, liveEnabled: false, bundledExhausted: true, roll: 0), [.bundled])
        }
    }

    func testAboutHalfLiveWhileBundledUnseen() {
        XCTAssertEqual(FeedSourcePlanner.sources(attempt: 0, liveEnabled: true, bundledExhausted: false, roll: 0.2), [.live, .bundled])
        XCTAssertEqual(FeedSourcePlanner.sources(attempt: 0, liveEnabled: true, bundledExhausted: false, roll: 0.7), [.bundled])
    }

    func testLiveOnlyOnceBundledExhaustedThenFallsBack() {
        XCTAssertEqual(FeedSourcePlanner.sources(attempt: 0, liveEnabled: true, bundledExhausted: true, roll: 0.9), [.live])
        XCTAssertEqual(FeedSourcePlanner.sources(attempt: 4, liveEnabled: true, bundledExhausted: true, roll: 0.9), [.live, .bundled])
        XCTAssertEqual(FeedSourcePlanner.sources(attempt: FeedSourcePlanner.attempts - 1, liveEnabled: true,
                                                 bundledExhausted: true, roll: 0), [.bundled],
                       "the last attempt always uses the bundled list so the feed never runs dry offline")
    }
}
