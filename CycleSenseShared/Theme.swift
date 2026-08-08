import SwiftUI

/// Blush Journal design system: warm cream surfaces, dusty-rose accents,
/// serif headers, soft shadows. Visual identity only — no logic.
enum Theme {
    // MARK: Surfaces
    static let background = Color(hex: 0xFFF7F2)
    static let card = Color(hex: 0xFFFDFB)

    // MARK: Accent
    /// Primary action / selected state.
    static let primary = Color(hex: 0xC9705E)

    // MARK: Block tints
    static let pink = Color(hex: 0xF9E8E2)
    static let rose = Color(hex: 0xF9E0DA)
    static let sand = Color(hex: 0xF5EAE2)
    static let lavender = Color(hex: 0xEFE7F2)
    static let sage = Color(hex: 0xEAF0EA)
    static let peach = Color(hex: 0xF9EDE4)

    // MARK: Text
    static let ink = Color(hex: 0x7A4A44)
    static let body = Color(hex: 0x8A5A50)
    static let soft = Color(hex: 0xB98A7E)

    // MARK: Type
    static func title(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    // MARK: Shape
    static let cardRadius: CGFloat = 22
    static let blockRadius: CGFloat = 16
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// Standard cozy card: white-cream surface, rounded, blush shadow.
    func cozyCard() -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .shadow(color: Theme.primary.opacity(0.12), radius: 14, x: 0, y: 6)
    }
}
