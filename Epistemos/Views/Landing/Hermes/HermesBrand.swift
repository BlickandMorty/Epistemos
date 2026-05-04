import SwiftUI

/// Single source of truth for Hermes Agent visual identity. Swap these
/// values when canonical NousResearch brand assets are confirmed per
/// `docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md`.
nonisolated enum HermesBrand {
    private static let displayFontName = "Inter-SemiBold"
    private static let bodyFontName = "Inter-Regular"
    private static let monoFontName = "JetBrainsMono-Regular"

    static let primary = Color(hex: 0x7C3AED)
    static let primaryMuted = Color(hex: 0xA78BFA)
    static let ink = Color.white
    static let surface = Color(hex: 0x0F0B1F)

    static func display(_ size: CGFloat) -> Font {
        .custom(displayFontName, size: size).weight(.semibold)
    }

    static func mono(_ size: CGFloat) -> Font {
        .custom(monoFontName, size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom(bodyFontName, size: size)
    }

    static let agentTitle = "Hermes Agent"
    static let runtimeBadge = "powered by Hermes"
}
