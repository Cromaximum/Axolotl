import CoreGraphics
import Foundation
import ImageIO

/// Loads remote images decoded and ready to draw. Views and view models take this protocol;
/// the concrete `ImagePipeline` is created once in `App/`.
protocol ImageLoading: Sendable {
    /// Size full-bleed photos are decoded at. Prefetch uses the same size so it hits the cache.
    var fullScreenPixelSize: Int { get }
    /// A decoded image no larger than `maxPixelSize` on its longest edge.
    func image(for url: URL, maxPixelSize: Int) async throws -> CGImage
    /// Already-decoded image, if it's in memory. Synchronous so a card can draw without a flash.
    func cachedImage(for url: URL, maxPixelSize: Int) -> CGImage?
    /// Fetches and decodes images ahead of time. Failures are ignored.
    func prefetch(_ urls: [URL], maxPixelSize: Int) async
}

/// Fetches images through an injected `URLSession` (memory-only cache: photos never touch disk, D-020),
/// downsamples them off the main thread with ImageIO, keeps decoded images in a cost-limited
/// memory cache that iOS trims under memory pressure, and shares one fetch per image.
actor ImagePipeline: ImageLoading {
    enum PipelineError: Error { case badResponse(Int), undecodable }

    nonisolated let fullScreenPixelSize: Int
    private let session: URLSession
    private let userAgent: String
    /// Thread-safe, which lets `cachedImage` stay synchronous and nonisolated.
    private nonisolated let memory = DecodedImageCache()
    private var inFlight: [String: Task<CGImage, Error>] = [:]

    init(session: URLSession, userAgent: String,
         fullScreenPixelSize: Int = ImageSizing.fullScreenPixelSize,
         memoryLimitBytes: Int = 160 * 1024 * 1024) {
        self.session = session
        self.userAgent = userAgent
        self.fullScreenPixelSize = fullScreenPixelSize
        memory.cache.totalCostLimit = memoryLimitBytes
    }

    nonisolated func cachedImage(for url: URL, maxPixelSize: Int) -> CGImage? {
        memory.cache.object(forKey: ImageSizing.cacheKey(url: url, maxPixelSize: maxPixelSize) as NSString)
    }

    func image(for url: URL, maxPixelSize: Int) async throws -> CGImage {
        if let hit = cachedImage(for: url, maxPixelSize: maxPixelSize) { return hit }
        let key = ImageSizing.cacheKey(url: url, maxPixelSize: maxPixelSize)
        if let running = inFlight[key] { return try await running.value }

        let session = session, userAgent = userAgent
        let task = Task { try await Self.fetch(url, maxPixelSize: maxPixelSize, session: session, userAgent: userAgent) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let image = try await task.value
        memory.cache.setObject(image, forKey: key as NSString,
                         cost: ImageSizing.decodedCost(width: image.width, height: image.height))
        return image
    }

    func prefetch(_ urls: [URL], maxPixelSize: Int) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls where cachedImage(for: url, maxPixelSize: maxPixelSize) == nil {
                group.addTask { _ = try? await self.image(for: url, maxPixelSize: maxPixelSize) }
            }
        }
    }

    /// Runs off the actor: nonisolated async work goes to the shared executor.
    private static func fetch(_ url: URL, maxPixelSize: Int, session: URLSession,
                              userAgent: String) async throws -> CGImage {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard (200..<300).contains(code) else { throw PipelineError.badResponse(code) }
        guard let image = downsample(data, maxPixelSize: maxPixelSize) else { throw PipelineError.undecodable }
        return image
    }

    /// Decodes `data` straight to a bitmap no larger than `maxPixelSize`, without ever holding
    /// the full-size image in memory. Honours EXIF orientation.
    static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as [CFString: Any] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

/// `NSCache` is documented as thread-safe; this box states that to the compiler.
private final class DecodedImageCache: @unchecked Sendable {
    let cache = NSCache<NSString, CGImage>()
}
