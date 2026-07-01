import AppKit
import SwiftUI

enum GooseSurfaceStyle {
    enum SurfaceRole {
        case canvas
        case rail
        case content
    }

    static func background(for theme: EpistemosTheme, role: SurfaceRole = .canvas) -> Color {
        Color(nsColor: backgroundNSColor(for: theme, role: role))
    }

    static func backgroundNSColor(for theme: EpistemosTheme, role: SurfaceRole = .canvas) -> NSColor {
        let token: EpistemosTheme.ResolvedColorToken = switch role {
        case .canvas, .content:
            theme.resolved.chatSurface
        case .rail:
            theme.resolved.card
        }
        let base = token.nsColor.usingColorSpace(.sRGB) ?? token.nsColor
        let target = theme.resolved.background.nsColor.usingColorSpace(.sRGB) ?? theme.resolved.background.nsColor
        let fraction: CGFloat = switch role {
        case .canvas:
            theme.isDark ? 0.08 : 0.04
        case .rail:
            theme.isDark ? 0.03 : 0.02
        case .content:
            theme.isDark ? 0.04 : 0.015
        }
        return base.blended(withFraction: fraction, of: target) ?? base
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func captionFont(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
