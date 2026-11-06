import CoreGraphics
import ImageIO
import XCTest
@testable import AnimalScroller

final class ImagePipelineTests: XCTestCase {
    override func tearDown() {
        StubImageProtocol.reset()
        super.tearDown()
    }

    func testDownsampleCapsLongestEdge() throws {
        let data = try XCTUnwrap(Self.pngData(width: 400, height: 200))
        let image = try XCTUnwrap(ImagePipeline.downsample(data, maxPixelSize: 100))
        XCTAssertEqual(max(image.width, image.height), 100)
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 50)
    }

    func testDownsampleRejectsNonImageData() {
        XCTAssertNil(ImagePipeline.downsample(Data("not an image".utf8), maxPixelSize: 100))
    }

    func testCachesAndSharesOneFetch() async throws {
        StubImageProtocol.body = try XCTUnwrap(Self.pngData(width: 64, height: 64))
        let pipeline = ImagePipeline(session: Self.stubSession(), userAgent: "test", fullScreenPixelSize: 256)
        let url = URL(string: "https://stub.test/cat.png")!

        async let first = pipeline.image(for: url, maxPixelSize: 256)
        async let second = pipeline.image(for: url, maxPixelSize: 256)
        _ = try await (first, second)
        _ = try await pipeline.image(for: url, maxPixelSize: 256)

        XCTAssertEqual(StubImageProtocol.requestCount, 1)
        XCTAssertNotNil(pipeline.cachedImage(for: url, maxPixelSize: 256))
        XCTAssertNil(pipeline.cachedImage(for: url, maxPixelSize: 512))
    }

    func testPrefetchFillsCache() async throws {
        StubImageProtocol.body = try XCTUnwrap(Self.pngData(width: 32, height: 32))
        let pipeline = ImagePipeline(session: Self.stubSession(), userAgent: "test", fullScreenPixelSize: 256)
        let urls = (1...3).map { URL(string: "https://stub.test/\($0).png")! }

        await pipeline.prefetch(urls, maxPixelSize: 256)

        for url in urls { XCTAssertNotNil(pipeline.cachedImage(for: url, maxPixelSize: 256)) }
        XCTAssertEqual(StubImageProtocol.requestCount, 3)
    }

    func testHTTPErrorThrows() async {
        StubImageProtocol.statusCode = 404
        let pipeline = ImagePipeline(session: Self.stubSession(), userAgent: "test")
        do {
            _ = try await pipeline.image(for: URL(string: "https://stub.test/missing.png")!, maxPixelSize: 256)
            XCTFail("expected an error")
        } catch {}
    }

    // MARK: Helpers

    private static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubImageProtocol.self]
        return URLSession(configuration: config)
    }

    /// A plain grey test bitmap encoded as PNG. Generated in code; no real content.
    static func pngData(width: Int, height: Int) -> Data? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

/// Serves `body` for every request and counts requests. Test-only.
final class StubImageProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _count = 0
    static var body = Data()
    static var statusCode = 200

    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return _count }

    static func reset() {
        lock.lock(); _count = 0; lock.unlock()
        body = Data()
        statusCode = 200
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock(); Self._count += 1; Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode,
                                       httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
