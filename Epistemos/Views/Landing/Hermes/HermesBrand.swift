import SwiftUI

/// Single source of truth for Hermes Agent visual identity. Swap these
/// values when canonical NousResearch brand assets are confirmed per
/// `docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md`.
///
/// Font resolution note: the bundled Inter binary is the variable font.
/// Both `Inter-Regular.ttf` and `Inter-SemiBold.ttf` in `Resources/Fonts/`
/// carry the same PostScript name `InterVariable`, so
/// `.custom("Inter-Regular", …)` / `.custom("Inter-SemiBold", …)` silently
/// fall back to the system font — SwiftUI looks up the PostScript name,
/// not the file name. Use the variable font's actual PSName + the
/// `.weight()` modifier to pick a weight axis. Asserted by
/// `EpistemosTests/HermesBrandFontResolutionTests` which reads the
/// PSName directly from each .ttf binary.
nonisolated enum HermesBrand {
    private static let interVariableFontName = "InterVariable"
    private static let monoFontName = "JetBrainsMono-Regular"

    static let primary = Color(hex: 0x7C3AED)
    static let primaryMuted = Color(hex: 0xA78BFA)
    static let ink = Color.white
    static let surface = Color(hex: 0x0F0B1F)

    static func display(_ size: CGFloat) -> Font {
        .custom(interVariableFontName, size: size).weight(.semibold)
    }

    static func mono(_ size: CGFloat) -> Font {
        .custom(monoFontName, size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom(interVariableFontName, size: size).weight(.regular)
    }

    static let agentTitle = "Hermes Agent"
    static let runtimeBadge = "powered by Hermes"
}
