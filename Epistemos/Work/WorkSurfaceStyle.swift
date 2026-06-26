import AppKit
import SwiftUI

// Epistemos-owned Work palette. The Work surface keeps its flat, dense,
// OpenCode-like character, but every fill/tint is derived from the active app
// theme instead of hardcoded warm RGB values.
enum WorkSurfaceStyle {
    enum SurfaceRole {
        case canvas
        case rail
        case popover
        case toolCard
    }

    static func background(for theme: EpistemosTheme, role: SurfaceRole = .canvas) -> Color {
        Color(nsColor: backgroundNSColor(for: theme, role: role))
    }

    static func diffAdded(for theme: EpistemosTheme) -> Color {
        theme.emerald
    }

    static func diffRemoved(for theme: EpistemosTheme) -> Color {
        theme.coral
    }

    static func diffHunk(for theme: EpistemosTheme) -> Color {
        theme.resolved.accent.color.opacity(0.82)
    }

    static func backgroundNSColor(for theme: EpistemosTheme, role: SurfaceRole = .canvas) -> NSColor {
        let token: EpistemosTheme.ResolvedColorToken
        switch role {
        case .canvas:
            token = theme.resolved.chatSurface
        case .rail:
            token = theme.resolved.card
        case .popover:
            token = theme.resolved.card
        case .toolCard:
            token = theme.resolved.muted
        }

        let base = token.nsColor.usingColorSpace(.sRGB) ?? token.nsColor
        let target: NSColor = theme.isDark ? .black : .white
        let fraction: CGFloat
        switch role {
        case .canvas:
            fraction = theme.isDark ? 0.05 : 0.03
        case .rail:
            fraction = theme.isDark ? 0.02 : 0.02
        case .popover:
            fraction = theme.isDark ? 0.06 : 0.04
        case .toolCard:
            fraction = theme.isDark ? 0.02 : 0.015
        }

        return base.blended(withFraction: fraction, of: target) ?? base
    }
}
