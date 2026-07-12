import SwiftUI
import UIKit

/// FlexUp design tokens. Calm, warm, minimal — lots of whitespace, one
/// accent, rounded everything. Adapts to light and dark automatically.
enum Theme {
    static let background = Color(light: 0xF7F6F2, dark: 0x0F0F0E)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1A)
    static let ink = Color(light: 0x1D1C18, dark: 0xF2F1EC)
    static let inkSubtle = Color(light: 0x83806F, dark: 0x9C998F)
    static let accent = Color(light: 0x2F6D53, dark: 0x6FBF97)
    static let accentSoft = Color(light: 0xE4EFE9, dark: 0x24352C)
    static let amber = Color(light: 0xB07A22, dark: 0xE0AE5C)
    static let amberSoft = Color(light: 0xF6EDDC, dark: 0x3A2F1B)
    static let danger = Color(light: 0xB0503E, dark: 0xE08A78)

    static let cornerRadius: CGFloat = 22
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

extension Font {
    static func flexTitle() -> Font { .system(.largeTitle, design: .rounded, weight: .bold) }
    static func flexHeading() -> Font { .system(.title2, design: .rounded, weight: .bold) }
    static func flexSection() -> Font { .system(.title3, design: .rounded, weight: .semibold) }
    static func flexBody() -> Font { .system(.body, design: .rounded) }
    static func flexBodyBold() -> Font { .system(.body, design: .rounded, weight: .semibold) }
    static func flexCaption() -> Font { .system(.caption, design: .rounded, weight: .medium) }
}
