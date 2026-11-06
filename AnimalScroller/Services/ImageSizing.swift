import CoreGraphics
import Foundation

/// How big decoded images should be, and how they are keyed in the memory cache. Pure logic.
enum ImageSizing {
    /// Longest screen edge in pixels of the largest iPhone (6.9", 1320 × 2868). Full-bleed photos
    /// are decoded no larger than this, so one size serves every card and prefetch hits the cache.
    static let fullScreenPixelSize = 2868

    /// Width we ask Wikimedia for. Wikimedia only serves standard thumbnail widths (others get
    /// HTTP 400); 1920 is one, and its 2x rendition (3840) is another. `PhotoQuality.displayURL`
    /// picks between them per photo so tall photos are as tall as the screen.
    static let wikimediaThumbWidth = 1920

    /// Sizes are rounded up to this step so small layout differences reuse one cached decode.
    static let step = 256

    /// Longest edge in pixels for an image drawn in a box of `size` points at `scale`.
    static func maxPixelSize(for size: CGSize, scale: CGFloat) -> Int {
        let longest = max(size.width, size.height) * max(scale, 1)
        guard longest.isFinite, longest > 0 else { return step }
        let pixels = Int(longest.rounded(.up))
        return ((pixels + step - 1) / step) * step
    }

    /// Memory-cache key for one decoded size of one URL.
    static func cacheKey(url: URL, maxPixelSize: Int) -> String {
        "\(maxPixelSize)|\(url.absoluteString)"
    }

    /// Approximate bytes a decoded image holds, used as its memory-cache cost.
    static func decodedCost(width: Int, height: Int, bytesPerPixel: Int = 4) -> Int {
        max(width, 0) * max(height, 0) * bytesPerPixel
    }
}
