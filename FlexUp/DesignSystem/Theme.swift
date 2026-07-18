import SwiftUI
import UIKit

/// FlexUp design tokens. Warm cream canvas, deep navy ink, huge black
/// display type, monospaced uppercase taglines, ink pill buttons.
/// Calm and confident — adapts to light and dark automatically.
enum Theme {
    static let background = Color(light: 0xF4F0E6, dark: 0x121211)
    static let card = Color(light: 0xFFFFFF, dark: 0x1D1D1B)
    static let ink = Color(light: 0x1C2733, dark: 0xF1EFE8)
    static let inkSubtle = Color(light: 0x7D7A6E, dark: 0x9C998F)
    static let accent = Color(light: 0x2F6D53, dark: 0x6FBF97)
    static let accentSoft = Color(light: 0xE1EAE1, dark: 0x24352C)
    static let amber = Color(light: 0xB07A22, dark: 0xE0AE5C)
    static let amberSoft = Color(light: 0xF3E9D5, dark: 0x3A2F1B)
    static let danger = Color(light: 0xB0503E, dark: 0xE08A78)

    static let cornerRadius: CGFloat = 24
}

extension Color {
    /// Build a dynamic color from light/dark hex values (0xRRGGBB).
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension CommitmentStatus {
    var tint: Color {
        switch self {
        case .scheduled: Theme.inkSubtle
        case .confirmed: Theme.accent
        case .completed: Theme.accent
        case .missed: Theme.danger
        case .rescheduled: Theme.amber
        }
    }
}

// MARK: - Typography
//
// Three voices, used everywhere:
//  1. Display — huge, black-weight, uppercase. Screen titles, hero numbers.
//  2. Mono — monospaced uppercase eyebrows and taglines ("YOUR GAME. YOUR JOURNEY.")
//  3. Body — quiet system text for everything else.

extension Font {
    /// Huge black display type for screen titles and hero moments.
    static func flexDisplay(_ size: CGFloat = 38) -> Font {
        .system(size: size, weight: .black)
    }

    /// Big heavy numerals for stats.
    static func flexStat(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .heavy)
    }

    /// Monospaced eyebrow/tagline text. Pair with .tracking(2) and uppercase.
    static func flexMono(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static func flexTitle() -> Font { .system(size: 34, weight: .black) }
    static func flexHeading() -> Font { .system(.title2, weight: .heavy) }
    static func flexSection() -> Font { .system(.title3, weight: .bold) }
    static func flexBody() -> Font { .system(.body) }
    static func flexBodyBold() -> Font { .system(.body, weight: .semibold) }
    static func flexCaption() -> Font { .system(.caption, weight: .medium) }
}
