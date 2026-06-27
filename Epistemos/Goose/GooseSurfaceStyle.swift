import AppKit
import SwiftUI

enum GooseSurfaceStyle {
    enum SurfaceRole {
        case canvas
        case rail
    }

    static func background(for theme: EpistemosTheme, role: SurfaceRole = .canvas) -> Color {
        Color(nsColor: backgroundNSColor(for: theme, role: role))
    }

    static func backgroundNSColor(for theme: EpistemosTheme, role: SurfaceRole = .canvas) -> NSColor {
        let token: EpistemosTheme.ResolvedColorToken = role == .canvas
            ? theme.resolved.chatSurface
            : theme.resolved.card
        let base = token.nsColor.usingColorSpace(.sRGB) ?? token.nsColor
        let target: NSColor = theme.isDark ? .black : .white
        let fraction: CGFloat = role == .canvas
            ? (theme.isDark ? 0.05 : 0.03)
            : (theme.isDark ? 0.02 : 0.02)
        return base.blended(withFraction: fraction, of: target) ?? base
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("JetBrainsMono-Regular", size: size).weight(weight)
    }
}
