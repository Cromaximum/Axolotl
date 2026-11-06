import SwiftUI

/// Visual language borrowed from zoo information boards: framed panels,
/// earthy greens and sand tones, bold condensed headings, a "Did you know?"
/// call-out, and a conservation-status scale.
enum Theme {
    // Palette agreed with the concept deck.
    static let forest = Color(hex: 0x14261F)        // app background
    static let boardGreen = Color(hex: 0x1F3B2F)    // sign panel
    static let wood = Color(hex: 0x6B4A2B)          // sign frame
    static let parchment = Color(hex: 0xF5F0E6)     // fact boxes, light panels
    static let amber = Color(hex: 0xE2A13B)         // accents, "Did you know?"
    static let ink = Color(hex: 0x1E1B16)

    // Fredoka (headings) and Nunito Sans (body) are OFL fonts; add the .ttf files to
    // Resources/Fonts and list them under UIAppFonts. Until then these fall back to
    // the system font automatically.
    static func heading(_ size: CGFloat) -> Font { .custom("Fredoka-SemiBold", size: size, relativeTo: .largeTitle) }
    static func body(_ size: CGFloat = 19) -> Font { .custom("NunitoSans-Regular", size: size, relativeTo: .body) }
    static func label(_ size: CGFloat = 12) -> Font { .custom("NunitoSans-Bold", size: size, relativeTo: .caption) }
}

/// A framed board panel, like the signs mounted on enclosure railings.
struct BoardPanel<Content: View>: View {
    var fill: Color = Theme.boardGreen
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.wood, lineWidth: 6)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
