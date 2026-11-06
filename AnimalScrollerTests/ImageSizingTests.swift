import XCTest
@testable import AnimalScroller

final class ImageSizingTests: XCTestCase {
    func testRoundsUpToStep() {
        // 393 × 852 pt at 3x = 2556 px longest edge → next 256 step is 2560.
        XCTAssertEqual(ImageSizing.maxPixelSize(for: CGSize(width: 393, height: 852), scale: 3), 2560)
        XCTAssertEqual(ImageSizing.maxPixelSize(for: CGSize(width: 100, height: 100), scale: 2), 256)
    }

    func testLandscapeUsesWidth() {
        XCTAssertEqual(ImageSizing.maxPixelSize(for: CGSize(width: 800, height: 300), scale: 2), 1792)
    }

    func testDegenerateSizesFallBackToOneStep() {
        XCTAssertEqual(ImageSizing.maxPixelSize(for: .zero, scale: 3), ImageSizing.step)
        XCTAssertEqual(ImageSizing.maxPixelSize(for: CGSize(width: 10, height: 10), scale: 0), 256)
    }

    func testCacheKeyDependsOnURLAndSize() {
        let a = URL(string: "https://upload.wikimedia.org/a.jpg")!
        let b = URL(string: "https://upload.wikimedia.org/b.jpg")!
        XCTAssertEqual(ImageSizing.cacheKey(url: a, maxPixelSize: 512), ImageSizing.cacheKey(url: a, maxPixelSize: 512))
        XCTAssertNotEqual(ImageSizing.cacheKey(url: a, maxPixelSize: 512), ImageSizing.cacheKey(url: a, maxPixelSize: 1024))
        XCTAssertNotEqual(ImageSizing.cacheKey(url: a, maxPixelSize: 512), ImageSizing.cacheKey(url: b, maxPixelSize: 512))
    }

    func testDecodedCost() {
        XCTAssertEqual(ImageSizing.decodedCost(width: 10, height: 20), 800)
        XCTAssertEqual(ImageSizing.decodedCost(width: -1, height: 20), 0)
    }
}
