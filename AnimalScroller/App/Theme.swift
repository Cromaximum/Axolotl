import SwiftUI

/// Visual language borrowed from zoo information boards: framed panels,
/// earthy greens and sand tones, bold rounded headings, a "Did you know?"
/// call-out, and a conservation-status scale.
enum Theme {
    // Palette agreed with the concept deck.
    static let forest = Color(hex: 0x14261F)        // app background
    static let boardGreen = Color(hex: 0x1F3B2F)    // sign panel
    static let wood = Color(hex: 0x6B4A2B)          // sign frame
    static let parchment = Color(hex: 0xF5F0E6)     // fact boxes, light panels
    static let amber = Color(hex: 0xE2A13B)         // accents, "Did you know?"
    static let ink = Color(hex: 0x1E1B16)
    static let mist = Color(hex: 0xC9D6CF)          // secondary text

    /// PostScript names of the bundled OFL fonts in `Resources/Fonts` (listed under `UIAppFonts`
    /// in `project.yml`). The odd names come from the upstream files; don't rename them.
    /// `ThemeFontTests` checks every one loads.
    enum FontName: String, CaseIterable {
        case headingMedium = "FredokaLight-Medium"
        case heading = "FredokaLight-SemiBold"
        case body = "NunitoSans12ptExtraLight12pt-Regular"
        case bodySemiBold = "NunitoSans12ptExtraLight12pt-SemiBold"
        case bodyBold = "NunitoSans12ptExtraLight12pt-Bold"
        case bodyExtraBold = "NunitoSans12ptExtraLight12pt-ExtraBold"
    }

    /// Nunito Sans faces. Pick a face instead of `.weight(...)`, which custom fonts ignore.
    enum BodyWeight {
        case regular, semibold, bold, extraBold
        var fontName: FontName {
            switch self {
            case .regular: .body
            case .semibold: .bodySemiBold
            case .bold: .bodyBold
            case .extraBold: .bodyExtraBold
            }
        }
    }

    // All text styles scale with Dynamic Type (`relativeTo:`).
    static func heading(_ size: CGFloat) -> Font {
        .custom(FontName.heading.rawValue, size: size, relativeTo: .largeTitle)
    }
    static func body(_ size: CGFloat = 19, weight: BodyWeight = .regular) -> Font {
        .custom(weight.fontName.rawValue, size: size, relativeTo: .body)
    }
    static func label(_ size: CGFloat = 12) -> Font {
        .custom(FontName.bodyBold.rawValue, size: size, relativeTo: .caption)
    }
    /// Scientific names are italic by convention. The bundled Nunito Sans has no italic face,
    /// so these use the system italic until one is added (architect, PR #13).
    static func scientific(_ size: CGFloat = 15) -> Font {
        .system(size: size).italic()
    }

    /// Motion constants, so every card animates the same way. Callers check Reduce Motion.
    enum Motion {
        static let pop = Animation.spring(duration: 0.35, bounce: 0.4)
        static let settle = Animation.spring(duration: 0.3)
        static let fade = Animation.easeInOut(duration: 0.2)
        static let shimmer = Animation.linear(duration: 1.4).repeatForever(autoreverses: false)
        /// How long the like burst and the save toast stay up.
        static let feedbackHold: Duration = .milliseconds(900)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
