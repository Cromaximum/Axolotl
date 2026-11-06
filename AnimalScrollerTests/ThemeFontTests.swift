import UIKit
import XCTest
@testable import AnimalScroller

/// Catches a font file missing from `UIAppFonts` or a wrong PostScript name in `Theme.FontName`.
/// Without this, SwiftUI silently falls back to the system font.
final class ThemeFontTests: XCTestCase {
    func testEveryBundledFontLoads() {
        for name in Theme.FontName.allCases {
            XCTAssertNotNil(UIFont(name: name.rawValue, size: 17), "\(name.rawValue) did not load")
        }
    }
}
