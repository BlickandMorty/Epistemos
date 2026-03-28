import AppKit
import CoreText
import SwiftUI

// MARK: - Theme Definition
// 12 themes — 6 light + 6 dark, including neutral and violet Platinum pairs.

enum EpistemosTheme: String, CaseIterable, Codable, Sendable {
    case systemLight = "systemLight"
    case systemDark = "systemDark"
    case light = "light"
    case sunny = "sunny"
    case tan = "tan"
    case magnolia = "magnolia"
    case sunset = "sunset"
    case oled = "oled"
    case ember = "ember"
    case nocturne = "nocturne"
    case platinum = "platinum"      // Classic Mac OS 9 Platinum (light)
    case platinumDark = "platinumDark"  // Beautiful dark variant
    case platinumViolet = "platinumViolet"
    case platinumVioletDark = "platinumVioletDark"

    struct ResolvedColorToken: Equatable, Sendable {
        private enum Storage: Equatable, Sendable {
            case rgba(Double, Double, Double, Double)
            case windowBackground
            case controlBackground(Double)
        }

        private let storage: Storage

        nonisolated static func hex(_ hex: UInt32, opacity: Double = 1.0) -> Self {
            rgba(
                Double((hex >> 16) & 0xFF) / 255.0,
                Double((hex >> 8) & 0xFF) / 255.0,
                Double(hex & 0xFF) / 255.0,
                opacity
            )
        }

        nonisolated static func rgba(_ red: Double, _ green: Double, _ blue: Double, _ opacity: Double = 1.0) -> Self {
            Self(storage: .rgba(red, green, blue, opacity))
        }

        nonisolated static func windowBackground() -> Self {
            Self(storage: .windowBackground)
        }

        nonisolated static func controlBackground(opacity: Double = 1.0) -> Self {
            Self(storage: .controlBackground(opacity))
        }

        nonisolated var color: Color {
            switch storage {
            case let .rgba(red, green, blue, opacity):
                let base = Color(red: red, green: green, blue: blue)
                if opacity == 1.0 {
                    return base
                }
                return base.opacity(opacity)
            case .windowBackground:
                return Color(nsColor: .windowBackgroundColor)
            case let .controlBackground(opacity):
                return Color(nsColor: .controlBackgroundColor).opacity(opacity)
            }
        }

        nonisolated var nsColor: NSColor {
            switch storage {
            case let .rgba(red, green, blue, opacity):
                return NSColor(red: red, green: green, blue: blue, alpha: opacity)
            case .windowBackground:
                return .windowBackgroundColor
            case let .controlBackground(opacity):
                return .controlBackgroundColor.withAlphaComponent(opacity)
            }
        }
    }

    struct ResolvedTheme: Equatable, Sendable {
        let isDark: Bool
        let isPlatinum: Bool
        let usesNativeWindowBlur: Bool
        let background: ResolvedColorToken
        let foregroundHex: UInt32
        let foreground: ResolvedColorToken
        let accent: ResolvedColorToken
        let headingAccentHex: UInt32
        let headingAccent: ResolvedColorToken
        let markdownHeadingAccentHex: UInt32
        let markdownHeadingAccent: ResolvedColorToken
        let preferredMarkdownLinkHex: UInt32?
        let preferredMarkdownLink: ResolvedColorToken?
        let uiAccent: ResolvedColorToken
        let muted: ResolvedColorToken
        let mutedForegroundHex: UInt32
        let mutedForeground: ResolvedColorToken
        let assistantBubbleForegroundHex: UInt32
        let assistantBubbleForeground: ResolvedColorToken
        let assistantBubbleBackgroundHex: UInt32?
        let assistantBubbleBackground: ResolvedColorToken?
        let userBubbleBackgroundHex: UInt32?
        let border: ResolvedColorToken
        let codeType: ResolvedColorToken
        let glassBg: ResolvedColorToken
        let glassBorder: ResolvedColorToken
        let glassHover: ResolvedColorToken
        let floatingSurfaceTint: ResolvedColorToken
        let navPillBg: ResolvedColorToken
        let navBubbleActiveBg: ResolvedColorToken
        let navBubbleActiveText: ResolvedColorToken
        let navBubbleInactiveText: ResolvedColorToken
        let card: ResolvedColorToken
        let chatSurface: ResolvedColorToken
        let userBubbleBg: ResolvedColorToken
        let userBubbleText: ResolvedColorToken
        let nsBackground: ResolvedColorToken

        nonisolated init(
            isDark: Bool,
            isPlatinum: Bool,
            usesNativeWindowBlur: Bool,
            background: ResolvedColorToken,
            foregroundHex: UInt32,
            accent: ResolvedColorToken,
            headingAccentHex: UInt32,
            markdownHeadingAccentHex: UInt32,
            preferredMarkdownLinkHex: UInt32?,
            uiAccent: ResolvedColorToken,
            muted: ResolvedColorToken,
            mutedForegroundHex: UInt32,
            assistantBubbleForegroundHex: UInt32,
            assistantBubbleBackgroundHex: UInt32?,
            userBubbleBackgroundHex: UInt32?,
            border: ResolvedColorToken,
            codeType: ResolvedColorToken,
            glassBg: ResolvedColorToken,
            glassBorder: ResolvedColorToken,
            glassHover: ResolvedColorToken,
            floatingSurfaceTint: ResolvedColorToken,
            navPillBg: ResolvedColorToken,
            navBubbleActiveBg: ResolvedColorToken,
            navBubbleActiveText: ResolvedColorToken,
            navBubbleInactiveText: ResolvedColorToken,
            card: ResolvedColorToken,
            chatSurface: ResolvedColorToken,
            userBubbleBg: ResolvedColorToken,
            userBubbleText: ResolvedColorToken,
            nsBackground: ResolvedColorToken
        ) {
            self.isDark = isDark
            self.isPlatinum = isPlatinum
            self.usesNativeWindowBlur = usesNativeWindowBlur
            self.background = background
            self.foregroundHex = foregroundHex
            self.foreground = .hex(foregroundHex)
            self.accent = accent
            self.headingAccentHex = headingAccentHex
            self.headingAccent = .hex(headingAccentHex)
            self.markdownHeadingAccentHex = markdownHeadingAccentHex
            self.markdownHeadingAccent = .hex(markdownHeadingAccentHex)
            self.preferredMarkdownLinkHex = preferredMarkdownLinkHex
            self.preferredMarkdownLink = preferredMarkdownLinkHex.map { ResolvedColorToken.hex($0) }
            self.uiAccent = uiAccent
            self.muted = muted
            self.mutedForegroundHex = mutedForegroundHex
            self.mutedForeground = .hex(mutedForegroundHex)
            self.assistantBubbleForegroundHex = assistantBubbleForegroundHex
            self.assistantBubbleForeground = .hex(assistantBubbleForegroundHex)
            self.assistantBubbleBackgroundHex = assistantBubbleBackgroundHex
            self.assistantBubbleBackground = assistantBubbleBackgroundHex.map { ResolvedColorToken.hex($0) }
            self.userBubbleBackgroundHex = userBubbleBackgroundHex
            self.border = border
            self.codeType = codeType
            self.glassBg = glassBg
            self.glassBorder = glassBorder
            self.glassHover = glassHover
            self.floatingSurfaceTint = floatingSurfaceTint
            self.navPillBg = navPillBg
            self.navBubbleActiveBg = navBubbleActiveBg
            self.navBubbleActiveText = navBubbleActiveText
            self.navBubbleInactiveText = navBubbleInactiveText
            self.card = card
            self.chatSurface = chatSurface
            self.userBubbleBg = userBubbleBg
            self.userBubbleText = userBubbleText
            self.nsBackground = nsBackground
        }
    }

    nonisolated private static let resolvedCache: [EpistemosTheme: ResolvedTheme] = {
        Dictionary(
            EpistemosTheme.allCases.map { ($0, $0.buildResolved()) },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    nonisolated var resolved: ResolvedTheme {
        guard let resolved = Self.resolvedCache[self] else {
            preconditionFailure("Missing resolved theme cache for \(self)")
        }
        return resolved
    }

    var displayName: String {
        switch self {
        case .systemLight: "System Light"
        case .systemDark: "System Dark"
        case .light:  "White"
        case .sunny:  "Sunny"
        case .tan:    "Tan"
        case .magnolia: "Magnolia"
        case .sunset: "Sunset"
        case .oled:   "OLED"
        case .ember:  "Ember"
        case .nocturne: "Nocturne"
        case .platinum: "Platinum"
        case .platinumDark: "Platinum Dark"
        case .platinumViolet: "Platinum Violet"
        case .platinumVioletDark: "Platinum Violet Dark"
        }
    }

    nonisolated static var nativeDefault: EpistemosTheme {
        SystemAppearanceState.isDark() ? .systemDark : .systemLight
    }

    nonisolated static func systemTheme(for appearance: NSAppearance?) -> EpistemosTheme {
        let bestMatch = appearance?.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua ? .systemDark : .systemLight
    }

    nonisolated var followsSystemAppearance: Bool {
        self == .systemLight || self == .systemDark
    }

    nonisolated func resolvedForAppearance(_ appearance: NSAppearance?) -> EpistemosTheme {
        followsSystemAppearance ? Self.systemTheme(for: appearance) : self
    }

    nonisolated var isDark: Bool {
        resolved.isDark
    }
    
    /// Whether this theme uses Platinum styling (beveled buttons, racing stripes)
    var isPlatinum: Bool {
        resolved.isPlatinum
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var usesNativeWindowBlur: Bool {
        resolved.usesNativeWindowBlur
    }

    nonisolated private func buildResolved() -> ResolvedTheme {
        typealias Token = ResolvedColorToken

        switch self {
        case .systemLight:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: false,
                usesNativeWindowBlur: true,
                background: .windowBackground(),
                foregroundHex: 0x1C1C1E,
                accent: .hex(0x1C1C1E),
                headingAccentHex: 0x1A1A1A,
                markdownHeadingAccentHex: 0x1A1A1A,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0x1C1C1E),
                muted: .controlBackground(),
                mutedForegroundHex: 0x6E6E73,
                assistantBubbleForegroundHex: 0x1C1C1E,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .rgba(0, 0, 0, 0.10),
                codeType: .hex(0x2B8A8A),
                glassBg: .rgba(1, 1, 1, 0.88),
                glassBorder: .rgba(0, 0, 0, 0.08),
                glassHover: .controlBackground(opacity: 0.72),
                floatingSurfaceTint: .hex(0xF4F4F6),
                navPillBg: .hex(0xF2F2F5, opacity: 0.82),
                navBubbleActiveBg: .rgba(0, 0, 0, 0.08),
                navBubbleActiveText: .hex(0x1C1C1E, opacity: 0.90),
                navBubbleInactiveText: .hex(0x6E6E73, opacity: 0.92),
                card: .rgba(1, 1, 1, 0.90),
                chatSurface: .windowBackground(),
                userBubbleBg: .hex(0x1A1A1E),
                userBubbleText: .hex(0xF2F2F7, opacity: 0.92),
                nsBackground: .windowBackground()
            )
        case .systemDark:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: false,
                usesNativeWindowBlur: true,
                background: .windowBackground(),
                foregroundHex: 0xF2F2F7,
                accent: .hex(0xF2F2F7),
                headingAccentHex: 0xF2F2F7,
                markdownHeadingAccentHex: 0xF2F2F7,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xF2F2F7),
                muted: .controlBackground(),
                mutedForegroundHex: 0x98989D,
                assistantBubbleForegroundHex: 0xF2F2F7,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .rgba(1, 1, 1, 0.12),
                codeType: .hex(0x7DB3C4),
                glassBg: .controlBackground(opacity: 0.86),
                glassBorder: .rgba(1, 1, 1, 0.08),
                glassHover: .rgba(1, 1, 1, 0.08),
                floatingSurfaceTint: .hex(0x1E1E22),
                navPillBg: .hex(0x1B1B1F, opacity: 0.90),
                navBubbleActiveBg: .rgba(1, 1, 1, 0.14),
                navBubbleActiveText: .hex(0xF2F2F7, opacity: 0.92),
                navBubbleInactiveText: .hex(0x98989D, opacity: 0.92),
                card: .controlBackground(opacity: 0.92),
                chatSurface: .windowBackground(),
                userBubbleBg: .hex(0x2A2A30),
                userBubbleText: .hex(0xF2F2F7, opacity: 0.92),
                nsBackground: .windowBackground()
            )
        case .light:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .rgba(1, 1, 1),
                foregroundHex: 0x1C1C1E,
                accent: .hex(0x1C1C1E),
                headingAccentHex: 0x1A1A1A,
                markdownHeadingAccentHex: 0x1A1A1A,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0x1C1C1E),
                muted: .hex(0xF0F0F0),
                mutedForegroundHex: 0x4A4A4A,
                assistantBubbleForegroundHex: 0x1C1C1E,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .rgba(0, 0, 0, 0.1),
                codeType: .hex(0x2B8A8A),
                glassBg: .rgba(1, 1, 1, 0.88),
                glassBorder: .rgba(0, 0, 0, 0.08),
                glassHover: .rgba(240.0 / 255.0, 240.0 / 255.0, 240.0 / 255.0, 0.8),
                floatingSurfaceTint: .hex(0xF2F2F2),
                navPillBg: .rgba(240.0 / 255.0, 240.0 / 255.0, 240.0 / 255.0, 0.7),
                navBubbleActiveBg: .rgba(0, 0, 0, 0.08),
                navBubbleActiveText: .hex(0x1C1C1E, opacity: 0.88),
                navBubbleInactiveText: .hex(0x000000, opacity: 0.5),
                card: .rgba(1, 1, 1, 0.92),
                chatSurface: .rgba(1, 1, 1),
                userBubbleBg: .hex(0x1A1A1A),
                userBubbleText: .hex(0xEEEEEE, opacity: 0.92),
                nsBackground: .rgba(1, 1, 1)
            )
        case .sunny:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .hex(0xE8F4FB),
                foregroundHex: 0x233040,
                accent: .hex(0x5B8FC7),
                headingAccentHex: 0xD4A843,
                markdownHeadingAccentHex: 0xD4A843,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0x233040),
                muted: Token.rgba(210.0 / 255.0, 230.0 / 255.0, 245.0 / 255.0, 0.75),
                mutedForegroundHex: 0x5A7A94,
                assistantBubbleForegroundHex: 0x233040,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: Token.rgba(130.0 / 255.0, 170.0 / 255.0, 210.0 / 255.0, 0.28),
                codeType: .hex(0x287878),
                glassBg: Token.rgba(235.0 / 255.0, 245.0 / 255.0, 252.0 / 255.0, 0.75),
                glassBorder: Token.rgba(130.0 / 255.0, 170.0 / 255.0, 210.0 / 255.0, 0.22),
                glassHover: Token.rgba(225.0 / 255.0, 240.0 / 255.0, 252.0 / 255.0, 0.65),
                floatingSurfaceTint: .hex(0xF6FBFE),
                navPillBg: Token.rgba(215.0 / 255.0, 235.0 / 255.0, 250.0 / 255.0, 0.7),
                navBubbleActiveBg: Token.rgba(180.0 / 255.0, 215.0 / 255.0, 245.0 / 255.0, 0.45),
                navBubbleActiveText: .hex(0x233040, opacity: 0.92),
                navBubbleInactiveText: .hex(0x5A7A94, opacity: 0.92),
                card: Token.rgba(235.0 / 255.0, 245.0 / 255.0, 252.0 / 255.0, 0.78),
                chatSurface: Token.rgba(235.0 / 255.0, 245.0 / 255.0, 252.0 / 255.0, 0.72),
                userBubbleBg: .hex(0x5B8FC7),
                userBubbleText: .hex(0x233040),
                nsBackground: .hex(0xE8F4FB)
            )
        case .tan:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .hex(0xF5EFE6),
                foregroundHex: 0x362816,
                accent: .hex(0x8B5E3C),
                headingAccentHex: 0x6B3E1C,
                markdownHeadingAccentHex: 0x6B3E1C,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0x362816),
                muted: .hex(0xEADDCC),
                mutedForegroundHex: 0x9A7A5A,
                assistantBubbleForegroundHex: 0x362816,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .hex(0xC4A882, opacity: 0.35),
                codeType: .hex(0x3A8888),
                glassBg: .hex(0xF0E4D0, opacity: 0.85),
                glassBorder: .hex(0xC4A882, opacity: 0.28),
                glassHover: .hex(0xDFCDB0, opacity: 0.75),
                floatingSurfaceTint: .hex(0xFBF5EB),
                navPillBg: .hex(0xE8D9C0, opacity: 0.78),
                navBubbleActiveBg: .hex(0xC4A07A, opacity: 0.30),
                navBubbleActiveText: .hex(0x362816, opacity: 0.92),
                navBubbleInactiveText: .hex(0x9A7A5A, opacity: 0.85),
                card: .hex(0xEDE0CA, opacity: 0.88),
                chatSurface: .hex(0xF5EFE6),
                userBubbleBg: .hex(0x6B3D1A),
                userBubbleText: .hex(0xF0EBE4, opacity: 0.92),
                nsBackground: .hex(0xF5EFE6)
            )
        case .magnolia:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: false,
                usesNativeWindowBlur: true,
                background: .hex(0xF7F2F5),
                foregroundHex: 0x342E35,
                accent: .hex(0x8E7282),
                headingAccentHex: 0xB86F8D,
                markdownHeadingAccentHex: 0xB86F8D,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0x342E35),
                muted: .hex(0xECE4E9),
                mutedForegroundHex: 0x7E737C,
                assistantBubbleForegroundHex: 0x342E35,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .hex(0xC6BAC3, opacity: 0.42),
                codeType: .hex(0x6D8CA8),
                glassBg: .hex(0xFBF7F9, opacity: 0.88),
                glassBorder: .hex(0xC6BAC3, opacity: 0.30),
                glassHover: .hex(0xE9DEE5, opacity: 0.78),
                floatingSurfaceTint: .hex(0xFEFBFD),
                navPillBg: .hex(0xEFE5EA, opacity: 0.82),
                navBubbleActiveBg: .hex(0xD8C7D1, opacity: 0.42),
                navBubbleActiveText: .hex(0x342E35, opacity: 0.92),
                navBubbleInactiveText: .hex(0x7E737C, opacity: 0.90),
                card: .hex(0xFCF9FB, opacity: 0.92),
                chatSurface: .hex(0xFBF7F9),
                userBubbleBg: .hex(0x6A5F70),
                userBubbleText: .hex(0xF6F0F5, opacity: 0.94),
                nsBackground: .hex(0xF7F2F5)
            )
        case .sunset:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .hex(0x1E1220),
                foregroundHex: 0xE8E0D8,
                accent: .hex(0xD4862B),
                headingAccentHex: 0xF5B84A,
                markdownHeadingAccentHex: 0xF5B84A,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xE8E0D8),
                muted: .hex(0x322030),
                mutedForegroundHex: 0xB09888,
                assistantBubbleForegroundHex: 0xE8E0D8,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .hex(0x3D2838),
                codeType: .hex(0x5EC4C4),
                glassBg: .hex(0x241828, opacity: 0.85),
                glassBorder: .hex(0x3A2434),
                glassHover: .hex(0x342030),
                floatingSurfaceTint: .hex(0x161018),
                navPillBg: .hex(0x1C1022, opacity: 0.8),
                navBubbleActiveBg: .hex(0x3C2434, opacity: 0.75),
                navBubbleActiveText: .hex(0xE8E0D8, opacity: 0.92),
                navBubbleInactiveText: .hex(0xB09888, opacity: 0.92),
                card: .hex(0x241828, opacity: 0.88),
                chatSurface: .hex(0x1E1220),
                userBubbleBg: .hex(0x3A2040),
                userBubbleText: .hex(0xE8E0D8, opacity: 0.90),
                nsBackground: .hex(0x1E1220)
            )
        case .oled:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .hex(0x000000),
                foregroundHex: 0xDADADE,
                accent: .hex(0xDADADE),
                headingAccentHex: 0xFFFFFF,
                markdownHeadingAccentHex: 0xFFFFFF,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xDADADE),
                muted: .hex(0x141414),
                mutedForegroundHex: 0x8A8A8A,
                assistantBubbleForegroundHex: 0xDADADE,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: Token.rgba(48.0 / 255.0, 48.0 / 255.0, 48.0 / 255.0, 0.55),
                codeType: .hex(0x56B6B6),
                glassBg: Token.rgba(16.0 / 255.0, 16.0 / 255.0, 16.0 / 255.0, 0.82),
                glassBorder: Token.rgba(48.0 / 255.0, 48.0 / 255.0, 48.0 / 255.0, 0.32),
                glassHover: Token.rgba(28.0 / 255.0, 28.0 / 255.0, 28.0 / 255.0, 0.7),
                floatingSurfaceTint: .hex(0x2A2A2F),
                navPillBg: Token.rgba(8.0 / 255.0, 8.0 / 255.0, 8.0 / 255.0, 0.85),
                navBubbleActiveBg: Token.rgba(20.0 / 255.0, 20.0 / 255.0, 20.0 / 255.0, 0.7),
                navBubbleActiveText: .hex(0xDADADE, opacity: 0.92),
                navBubbleInactiveText: Token.rgba(180.0 / 255.0, 180.0 / 255.0, 180.0 / 255.0, 0.92),
                card: Token.rgba(18.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0, 0.92),
                chatSurface: .hex(0x000000),
                userBubbleBg: .hex(0x2A2A2A),
                userBubbleText: .hex(0xDADADE, opacity: 0.88),
                nsBackground: .hex(0x000000)
            )
        case .ember:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .hex(0x1C1410),
                foregroundHex: 0xE0D4C8,
                accent: .hex(0xC8762A),
                headingAccentHex: 0xE8A040,
                markdownHeadingAccentHex: 0xE8A040,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xE0D4C8),
                muted: .hex(0x2A1E14),
                mutedForegroundHex: 0xA08060,
                assistantBubbleForegroundHex: 0xE0D4C8,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .hex(0x3A2818),
                codeType: .hex(0x5AACAC),
                glassBg: .hex(0x241A10, opacity: 0.88),
                glassBorder: .hex(0x402C1C),
                glassHover: .hex(0x30201A, opacity: 0.75),
                floatingSurfaceTint: .hex(0x16100C),
                navPillBg: .hex(0x141008, opacity: 0.88),
                navBubbleActiveBg: .hex(0x3A2414, opacity: 0.8),
                navBubbleActiveText: .hex(0xE0D4C8, opacity: 0.92),
                navBubbleInactiveText: .hex(0xA08060, opacity: 0.92),
                card: .hex(0x241A10, opacity: 0.90),
                chatSurface: .hex(0x1C1410),
                userBubbleBg: .hex(0x3C2010),
                userBubbleText: .hex(0xEADED0, opacity: 0.90),
                nsBackground: .hex(0x1C1410)
            )
        case .nocturne:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: false,
                usesNativeWindowBlur: true,
                background: .hex(0x19141F),
                foregroundHex: 0xE7DEE8,
                accent: .hex(0xA8B6D9),
                headingAccentHex: 0xD7A7B6,
                markdownHeadingAccentHex: 0xD7A7B6,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xE7DEE8),
                muted: .hex(0x27212D),
                mutedForegroundHex: 0xA89CA8,
                assistantBubbleForegroundHex: 0xE7DEE8,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .hex(0x3B3243),
                codeType: .hex(0x7DB3C4),
                glassBg: .hex(0x221C2A, opacity: 0.86),
                glassBorder: .hex(0x443A4D),
                glassHover: .hex(0x342B3D, opacity: 0.78),
                floatingSurfaceTint: .hex(0x141019),
                navPillBg: .hex(0x140F18, opacity: 0.90),
                navBubbleActiveBg: .hex(0x3A3046, opacity: 0.78),
                navBubbleActiveText: .hex(0xEEE4EC, opacity: 0.94),
                navBubbleInactiveText: .hex(0xA89CA8, opacity: 0.92),
                card: .hex(0x241E2B, opacity: 0.90),
                chatSurface: .hex(0x19141F),
                userBubbleBg: .hex(0x313444),
                userBubbleText: .hex(0xF2E7EE, opacity: 0.92),
                nsBackground: .hex(0x19141F)
            )
        case .platinum:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: true,
                usesNativeWindowBlur: false,
                background: .hex(0xDEDEDE),
                foregroundHex: 0x000000,
                accent: .hex(0x111111),
                headingAccentHex: 0x111111,
                markdownHeadingAccentHex: 0x111111,
                preferredMarkdownLinkHex: 0x111111,
                uiAccent: .hex(0x111111),
                muted: .hex(0xCCCCCC),
                mutedForegroundHex: 0x555555,
                assistantBubbleForegroundHex: 0x555555,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: 0x111111,
                border: .rgba(0, 0, 0, 0.2),
                codeType: .hex(0x111111),
                glassBg: .hex(0xDDDDDD),
                glassBorder: .rgba(0, 0, 0, 0.1),
                glassHover: .hex(0xCCCCCC),
                floatingSurfaceTint: .hex(0xF4F4F4),
                navPillBg: .hex(0xDDDDDD),
                navBubbleActiveBg: .hex(0x111111),
                navBubbleActiveText: .hex(0xF2F2F2, opacity: 0.94),
                navBubbleInactiveText: .rgba(0, 0, 0, 0.5),
                card: .hex(0xDDDDDD),
                chatSurface: .hex(0xEEEEEE),
                userBubbleBg: .hex(0x111111),
                userBubbleText: .hex(0xF2F2F2, opacity: 0.94),
                nsBackground: .hex(0xDEDEDE)
            )
        case .platinumDark:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: true,
                usesNativeWindowBlur: false,
                background: .hex(0x1E1E24),
                foregroundHex: 0xFFFFFF,
                accent: .hex(0xF2F2F2),
                headingAccentHex: 0xF2F2F2,
                markdownHeadingAccentHex: 0xF2F2F2,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xF2F2F2),
                muted: .hex(0x252530),
                mutedForegroundHex: 0x9090A0,
                assistantBubbleForegroundHex: 0xFFFFFF,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: 0x2A2A38,
                border: .rgba(1, 1, 1, 0.15),
                codeType: .hex(0xF2F2F2),
                glassBg: .hex(0x2D2D38),
                glassBorder: .rgba(1, 1, 1, 0.08),
                glassHover: .hex(0x353545),
                floatingSurfaceTint: .hex(0x17171D),
                navPillBg: .hex(0x2D2D38),
                navBubbleActiveBg: .hex(0xF2F2F2),
                navBubbleActiveText: .hex(0x111111, opacity: 0.88),
                navBubbleInactiveText: .rgba(1, 1, 1, 0.6),
                card: .hex(0x252530),
                chatSurface: .hex(0x2A2A38),
                userBubbleBg: .hex(0x2A2A38),
                userBubbleText: .hex(0xF2F2F2, opacity: 0.94),
                nsBackground: .hex(0x1E1E24)
            )
        case .platinumViolet:
            return ResolvedTheme(
                isDark: false,
                isPlatinum: true,
                usesNativeWindowBlur: false,
                background: .hex(0xDEDEDE),
                foregroundHex: 0x000000,
                accent: .hex(0x000080),
                headingAccentHex: 0x000000,
                markdownHeadingAccentHex: 0x00007B,
                preferredMarkdownLinkHex: 0x00007B,
                uiAccent: .hex(0x000080),
                muted: .hex(0xCCCCCC),
                mutedForegroundHex: 0x555555,
                assistantBubbleForegroundHex: 0x555555,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .rgba(0, 0, 0, 0.2),
                codeType: .hex(0x000080),
                glassBg: .hex(0xDDDDDD),
                glassBorder: .rgba(0, 0, 0, 0.1),
                glassHover: .hex(0xCCCCCC),
                floatingSurfaceTint: .hex(0xF4F4F4),
                navPillBg: .hex(0xDDDDDD),
                navBubbleActiveBg: .hex(0x000080),
                navBubbleActiveText: .rgba(0, 0, 0, 0.7),
                navBubbleInactiveText: .rgba(0, 0, 0, 0.5),
                card: .hex(0xDDDDDD),
                chatSurface: .hex(0xEEEEEE),
                userBubbleBg: .hex(0x000080),
                userBubbleText: .hex(0xF2F2F2, opacity: 0.94),
                nsBackground: .hex(0xDEDEDE)
            )
        case .platinumVioletDark:
            return ResolvedTheme(
                isDark: true,
                isPlatinum: true,
                usesNativeWindowBlur: false,
                background: .hex(0x1E1E24),
                foregroundHex: 0xFFFFFF,
                accent: .hex(0x7B68EE),
                headingAccentHex: 0xFFFFFF,
                markdownHeadingAccentHex: 0x7B68EE,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0x7B68EE),
                muted: .hex(0x252530),
                mutedForegroundHex: 0x9090A0,
                assistantBubbleForegroundHex: 0xFFFFFF,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: .rgba(1, 1, 1, 0.15),
                codeType: .hex(0x7B68EE),
                glassBg: .hex(0x2D2D38),
                glassBorder: .rgba(1, 1, 1, 0.08),
                glassHover: .hex(0x353545),
                floatingSurfaceTint: .hex(0x17171D),
                navPillBg: .hex(0x2D2D38),
                navBubbleActiveBg: .hex(0x6B5DD6),
                navBubbleActiveText: .rgba(1, 1, 1, 0.75),
                navBubbleInactiveText: .rgba(1, 1, 1, 0.6),
                card: .hex(0x252530),
                chatSurface: .hex(0x2A2A38),
                userBubbleBg: .hex(0x7B68EE),
                userBubbleText: .hex(0xF2F2F2, opacity: 0.94),
                nsBackground: .hex(0x1E1E24)
            )
        }
    }

    // MARK: - Core Colors

    nonisolated var foregroundHex: UInt32 {
        resolved.foregroundHex
    }

    nonisolated var headingAccentHex: UInt32 {
        resolved.headingAccentHex
    }

    nonisolated var markdownHeadingAccentHex: UInt32 {
        resolved.markdownHeadingAccentHex
    }

    nonisolated var preferredMarkdownLinkHex: UInt32? {
        resolved.preferredMarkdownLinkHex
    }

    var fontAccent: Color {
        resolved.headingAccent.color
    }

    var markdownHeadingAccent: Color {
        resolved.markdownHeadingAccent.color
    }

    var preferredMarkdownLinkColor: Color? {
        resolved.preferredMarkdownLink?.color
    }

    var preferredMarkdownLinkNSColor: NSColor? {
        resolved.preferredMarkdownLink?.nsColor
    }

    var uiAccent: Color {
        resolved.uiAccent.color
    }

    // MARK: - Surface Colors

    var muted: Color {
        resolved.muted.color
    }

    nonisolated var mutedForegroundHex: UInt32 {
        resolved.mutedForegroundHex
    }

    var mutedForeground: Color { resolved.mutedForeground.color }

    nonisolated var assistantBubbleForegroundHex: UInt32 {
        resolved.assistantBubbleForegroundHex
    }

    var assistantBubbleForeground: Color { resolved.assistantBubbleForeground.color }

    nonisolated var assistantBubbleBackgroundHex: UInt32? {
        resolved.assistantBubbleBackgroundHex
    }

    var assistantBubbleBackground: Color {
        resolved.assistantBubbleBackground?.color ?? .clear
    }

    nonisolated var userBubbleBackgroundHex: UInt32? {
        resolved.userBubbleBackgroundHex
    }

    var border: Color {
        resolved.border.color
    }

    var destructive: Color { Color(hex: 0xC75E5E) }

    // MARK: - Semantic Accent Colors (centralized from scattered hex values)

    var emerald: Color { Color(hex: 0x34D399) }   // Data tags, positive indicators
    var amber: Color   { Color(hex: 0xD4A843) }   // Model tags, warning indicators
    var violet: Color  { Color(hex: 0x9B7DB8) }   // Uncertain tags, neutral
    var coral: Color   { Color(hex: 0xC75E5E) }   // Conflict, error (same as destructive)
    var indigo: Color  { Color(hex: 0x8B7CF6) }   // Research accent, library stats

    // MARK: - Code Token Colors (syntax highlighting)

    var codeKeyword: Color { resolved.accent.color }
    var codeString: Color { emerald }
    var codeNumber: Color { amber }
    var codeComment: Color { mutedForeground }
    var codeFunction: Color { violet }
    var codeType: Color {
        resolved.codeType.color
    }
    var codeProperty: Color { fontAccent }
    var codeConstant: Color { amber }
    var codeTag: Color { resolved.accent.color }
    var codeAttribute: Color { emerald }

    /// Map a CodeToken token_type (UInt8) to an NSColor for syntax highlighting.
    func nsColorForTokenType(_ tokenType: UInt8) -> NSColor {
        switch tokenType {
        case 0:   return NSColor(codeKeyword)    // keyword
        case 1:   return NSColor(codeString)     // string
        case 2:   return NSColor(codeNumber)     // number
        case 3:   return NSColor(codeComment)    // comment
        case 4:   return NSColor(codeFunction)   // function
        case 5:   return NSColor(codeType)       // type
        case 6:   return resolved.foreground.nsColor.withAlphaComponent(0.6) // operator
        case 7:   return resolved.foreground.nsColor.withAlphaComponent(0.5) // punctuation
        case 8:   return resolved.foreground.nsColor     // variable
        case 9:   return NSColor(codeProperty)   // property
        case 10:  return NSColor(codeConstant)   // constant
        case 11:  return NSColor(codeTag)        // tag
        case 12:  return NSColor(codeAttribute)  // attribute
        default:  return resolved.foreground.nsColor     // plain
        }
    }

    // MARK: - Callout Styling

    struct CalloutStyle {
        let accent: NSColor
        let background: NSColor
        let icon: String
    }

    /// Returns callout styling for a callout type ID from the Rust parser.
    /// Type 0 = plain blockquote (no callout). Types 1-9 map to callout categories.
    func calloutColors(typeId: UInt8) -> CalloutStyle? {
        guard typeId > 0 else { return nil }
        let dark = isDark
        let base: NSColor
        let icon: String

        switch typeId {
        case 1: // note, info
            base = NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1)
            icon = "info.circle.fill"
        case 2: // tip, hint, important
            base = NSColor(red: 0.25, green: 0.75, blue: 0.55, alpha: 1)
            icon = "lightbulb.fill"
        case 3: // warning, caution, attention
            base = NSColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 1)
            icon = "exclamationmark.triangle.fill"
        case 4: // success, check, done
            base = NSColor(red: 0.25, green: 0.75, blue: 0.35, alpha: 1)
            icon = "checkmark.circle.fill"
        case 5: // question, help, faq
            base = NSColor(red: 0.65, green: 0.50, blue: 0.90, alpha: 1)
            icon = "questionmark.circle.fill"
        case 6: // quote, cite
            base = NSColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
            icon = "quote.opening"
        case 7: // danger, error, bug, fail
            base = NSColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1)
            icon = "xmark.octagon.fill"
        case 8: // example
            base = NSColor(red: 0.60, green: 0.45, blue: 0.85, alpha: 1)
            icon = "list.clipboard.fill"
        case 9: // abstract, summary, tldr
            base = NSColor(red: 0.30, green: 0.70, blue: 0.85, alpha: 1)
            icon = "doc.text.fill"
        default:
            return nil
        }

        let background = dark ? base.withAlphaComponent(0.07) : base.withAlphaComponent(0.05)
        return CalloutStyle(accent: base, background: background, icon: icon)
    }

    // MARK: - Glass Tokens

    var glassBg: Color {
        resolved.glassBg.color
    }

    var glassBorder: Color {
        resolved.glassBorder.color
    }

    var glassHover: Color {
        resolved.glassHover.color
    }

    var floatingSurfaceTint: Color {
        resolved.floatingSurfaceTint.color
    }

    // MARK: - Nav Pill Colors

    var navPillBg: Color {
        resolved.navPillBg.color
    }

    var navPillBorder: Color { glassBorder }

    var navBubbleActiveBg: Color {
        resolved.navBubbleActiveBg.color
    }

    var navBubbleActiveText: Color {
        resolved.navBubbleActiveText.color
    }

    var navBubbleInactiveText: Color {
        resolved.navBubbleInactiveText.color
    }

    // MARK: - Card / Surface

    var card: Color {
        resolved.card.color
    }

    var chatSurface: Color {
        resolved.chatSurface.color
    }

    // MARK: - Status Colors

    var success: Color { Color(hex: 0x4CAF50) }
    var warning: Color { Color(hex: 0xE5A440) }
    var error: Color   { Color(hex: 0xEF5B5B) }
    var info: Color    { Color(hex: 0x5B8DEF) }

    // MARK: - Convenience

    var textPrimary: Color { resolved.foreground.color }
    var textSecondary: Color { mutedForeground }
    var textTertiary: Color { mutedForeground.opacity(0.7) }
    var chatStrongForeground: Color { isDark ? mutedForeground : resolved.accent.color }
    var hoverOverlay: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04) }
    var glassTint: Color { glassBg }
    var pressedOverlay: Color { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08) }

    var userBubbleBg: Color {
        resolved.userBubbleBg.color
    }

    var userBubbleText: Color {
        resolved.userBubbleText.color
    }

    var sidebarBackground: Color { glassBg }

    // MARK: - NSColor for Window Chrome

    var nsBackground: NSColor {
        resolved.nsBackground.nsColor
    }
}

// MARK: - Theme Pair

enum ThemePair: String, CaseIterable, Codable, Sendable {
    case magnolia = "magnolia"
    case classic = "classic"
    case warmth  = "warmth"
    case ember   = "ember"
    case platinum = "platinum"
    case platinumViolet = "platinumViolet"

    var displayName: String {
        switch self {
        case .magnolia: "Magnolia"
        case .classic: "Classic"
        case .warmth:  "Warmth"
        case .ember:   "Ember"
        case .platinum: "Platinum"
        case .platinumViolet: "Platinum Violet"
        }
    }

    var description: String {
        switch self {
        case .magnolia: "Magnolia · Nocturne"
        case .classic: "White · OLED"
        case .warmth:  "Sunny · Sunset"
        case .ember:   "Tan · Ember"
        case .platinum: "Platinum · Platinum Dark"
        case .platinumViolet: "Platinum Violet · Platinum Violet Dark"
        }
    }

    var lightTheme: EpistemosTheme {
        switch self {
        case .magnolia: .magnolia
        case .classic: .light
        case .warmth:  .sunny
        case .ember:   .tan
        case .platinum: .platinum
        case .platinumViolet: .platinumViolet
        }
    }

    var darkTheme: EpistemosTheme {
        switch self {
        case .magnolia: .nocturne
        case .classic: .oled
        case .warmth:  .sunset
        case .ember:   .ember
        case .platinum: .platinumDark
        case .platinumViolet: .platinumVioletDark
        }
    }

    func resolved(isDark: Bool) -> EpistemosTheme {
        isDark ? darkTheme : lightTheme
    }

    /// Dock icon selection is handled by the AppIcon asset catalog variants.
    func dockIconResourceName(isDark _: Bool) -> String? {
        nil
    }
}

// MARK: - Color Hex Initializer

extension Color {
    nonisolated init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Spacing & Padding

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Typography (7 tokens)

enum AppHeadingRole: Sendable {
    case pageTitle
    case h1
    case h2
    case h3
    case section
    case chatTitle

    nonisolated var fontName: String { AppDisplayTypography.fontName }

    var fontSize: CGFloat {
        switch self {
        case .pageTitle: 28
        case .h1: 26
        case .h2: 20
        case .h3: 16
        case .section: 12
        case .chatTitle: 28
        }
    }

    var topPadding: CGFloat {
        switch self {
        case .pageTitle, .section, .chatTitle: 0
        case .h1: 16
        case .h2: 12
        case .h3: 8
        }
    }

    var tracking: CGFloat {
        switch self {
        case .section: 0.8
        default: 0
        }
    }

    var animatesOnFirstAppearance: Bool {
        switch self {
        case .pageTitle: true
        default: false
        }
    }

    var font: Font {
        AppDisplayTypography.font(
            size: fontSize,
            allowDisplayFont: self == .h1 || self == .pageTitle || self == .chatTitle
        )
    }

    nonisolated static func markdownRole(level: Int) -> AppHeadingRole? {
        switch level {
        case 1: .h1
        case 2: .h2
        case 3: .h3
        default: nil
        }
    }
}

enum AppDisplayMode: String, CaseIterable, Sendable, Identifiable {
    nonisolated static let defaultsKey = "epistemos.display.mode"

    case opulent
    case regular

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .opulent: "Opulent"
        case .regular: "Regular"
        }
    }

    nonisolated var usesDisplayFont: Bool { self == .opulent }
    nonisolated var reducesASCIIAnimations: Bool { self == .regular }

    nonisolated static func current(defaults: UserDefaults = .standard) -> AppDisplayMode {
        guard
            let rawValue = defaults.string(forKey: defaultsKey),
            let mode = AppDisplayMode(rawValue: rawValue)
        else {
            return .opulent
        }
        return mode
    }
}

enum AppDisplayTypography: Sendable {
    nonisolated static let displayFontName = "RetroGaming"

    nonisolated static var currentMode: AppDisplayMode {
        AppDisplayMode.current()
    }

    nonisolated static func regularUIFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let uiType: CTFontUIFontType = weight >= .semibold ? .emphasizedSystem : .system
        guard let ctFont = CTFontCreateUIFontForLanguage(uiType, size, nil) else {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        return ctFont as NSFont
    }

    nonisolated static func isRegularUIFont(_ font: NSFont) -> Bool {
        font.fontName.hasPrefix(".SFNS") || font.fontName.hasPrefix(".AppleSystemUIFont")
    }

    nonisolated static var fontName: String {
        currentMode.usesDisplayFont
            ? displayFontName
            : regularUIFont(size: NSFont.systemFontSize).fontName
    }

    static func font(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        allowDisplayFont: Bool = true
    ) -> Font {
        if allowDisplayFont && currentMode.usesDisplayFont {
            .custom(displayFontName, size: size)
        } else if design == .default {
            Font(regularUIFont(size: size, weight: nsWeight(for: weight)))
        } else {
            .system(size: size, weight: weight, design: design)
        }
    }

    nonisolated static func nsFont(
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        allowDisplayFont: Bool = true
    ) -> NSFont {
        if allowDisplayFont && currentMode.usesDisplayFont {
            NSFont(name: displayFontName, size: size)
                ?? NSFont.systemFont(ofSize: size, weight: weight)
        } else {
            regularUIFont(size: size, weight: weight)
        }
    }

    nonisolated static func isDisplayFont(_ font: NSFont) -> Bool {
        font.fontName.contains(displayFontName)
    }

    nonisolated static func preservingFamilyFont(
        from font: NSFont,
        size: CGFloat,
        bold: Bool = false,
        italic: Bool = false
    ) -> NSFont {
        let manager = NSFontManager.shared
        var resolved = isDisplayFont(font)
            ? nsFont(size: size, weight: bold ? .bold : .regular)
            : isRegularUIFont(font)
                ? regularUIFont(size: size, weight: bold ? .bold : .regular)
            : font.withSize(size)

        if bold {
            resolved = manager.convert(resolved, toHaveTrait: .boldFontMask)
        }
        if italic {
            resolved = manager.convert(resolved, toHaveTrait: .italicFontMask)
        }

        return resolved
    }

    private nonisolated static func nsWeight(for weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

enum InlineMarkdownStyler {
    private static let orphanBracketRegex = FoundationSafety.regularExpression(
        pattern: "\\[[A-Z][A-Z ]+\\](?!\\()"
    )
    private static let markdownLinkDestinationRegex = FoundationSafety.regularExpression(
        pattern: #"\[[^\]]+\]\((https?://[^\s\)]+)\)"#
    )
    private static let urlDetector = FoundationSafety.dataDetector(
        types: .link
    )

    static func cleanedText(_ text: String) -> String {
        guard let orphanBracketRegex else { return text }
        return orphanBracketRegex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: ""
        )
    }

    static func text(_ text: String, strongFontSize: CGFloat? = nil) -> Text {
        Self.text(
            text,
            strongFontSize: strongFontSize,
            strongForegroundColor: nil,
            linkForegroundColor: nil
        )
    }

    static func text(
        _ text: String,
        strongFontSize: CGFloat? = nil,
        strongForegroundColor: Color?,
        linkForegroundColor: Color? = nil
    ) -> Text {
        if let attributed = attributedString(
            text,
            strongFontSize: strongFontSize,
            strongForegroundColor: strongForegroundColor,
            linkForegroundColor: linkForegroundColor
        ) {
            return Text(attributed)
        }
        return Text(cleanedText(text))
    }

    static func attributedString(_ text: String, strongFontSize: CGFloat? = nil) -> AttributedString? {
        Self.attributedString(
            text,
            strongFontSize: strongFontSize,
            strongForegroundColor: nil,
            linkForegroundColor: nil
        )
    }

    static func attributedString(
        _ text: String,
        strongFontSize: CGFloat? = nil,
        strongForegroundColor: Color?,
        linkForegroundColor: Color? = nil
    ) -> AttributedString? {
        let cleaned = cleanedText(text)
        let linkified = linkifyRawURLs(in: cleaned)
        guard var attributed = try? AttributedString(
            markdown: linkified,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return nil
        }
        guard let strongFontSize else { return attributed }
        applyDisplayStrongEmphasis(
            to: &attributed,
            fontSize: strongFontSize,
            foregroundColor: strongForegroundColor
        )
        applyLinkForegroundColor(to: &attributed, foregroundColor: linkForegroundColor)
        return attributed
    }

    static func applyDisplayStrongEmphasis(
        to attributed: inout AttributedString,
        fontSize: CGFloat,
        foregroundColor: Color? = nil
    ) {
        _ = fontSize
        let strongRuns = attributed.runs.compactMap { run -> (Range<AttributedString.Index>, InlinePresentationIntent)? in
            guard let intent = run.inlinePresentationIntent, intent.contains(.stronglyEmphasized) else {
                return nil
            }
            return (run.range, intent)
        }

        for (range, _) in strongRuns {
            if let foregroundColor {
                attributed[range].foregroundColor = foregroundColor
            }
        }
    }

    static func applyLinkForegroundColor(
        to attributed: inout AttributedString,
        foregroundColor: Color? = nil
    ) {
        guard let foregroundColor else { return }
        let linkRuns = attributed.runs.compactMap { run -> Range<AttributedString.Index>? in
            run.link != nil ? run.range : nil
        }

        for range in linkRuns {
            attributed[range].foregroundColor = foregroundColor
        }
    }

    private static func linkifyRawURLs(in text: String) -> String {
        let nsText = text as NSString
        let excludedRanges = markdownLinkDestinationRegex?.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ).map { $0.range(at: 1) } ?? []
        guard let matches = urlDetector?.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) else {
            return text
        }
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            guard shouldAutolink(match.range, in: nsText, excludedRanges: excludedRanges) else { continue }
            let rawURL = nsText.substring(with: match.range)
            mutable.replaceCharacters(in: match.range, with: "<\(rawURL)>")
        }

        return mutable as String
    }

    private static func shouldAutolink(
        _ range: NSRange,
        in text: NSString,
        excludedRanges: [NSRange]
    ) -> Bool {
        guard !excludedRanges.contains(where: { NSIntersectionRange($0, range).length > 0 }) else {
            return false
        }

        let lowerIndex = range.location - 1
        let upperIndex = range.location + range.length
        guard lowerIndex >= 0, upperIndex < text.length else { return true }

        let lowerCharacter = text.substring(with: NSRange(location: lowerIndex, length: 1))
        let upperCharacter = text.substring(with: NSRange(location: upperIndex, length: 1))
        return !(lowerCharacter == "<" && upperCharacter == ">")
    }
}

extension Font {
    static let epTitle: Font = .system(size: 22, weight: .semibold, design: .default)
    static let epHeading: Font = .system(size: 16, weight: .semibold, design: .default)
    static let epBody: Font = .system(size: 15, weight: .regular, design: .default)
    static let epBodyMedium: Font = .system(size: 15, weight: .medium, design: .default)
    static let epCaption: Font = .system(size: 12, weight: .regular, design: .default)
    static let epSmall: Font = .system(size: 11, weight: .regular, design: .default)
    static let epMono: Font = .system(size: 13, weight: .regular, design: .monospaced)
}


// MARK: - Motion Constants

enum Motion {
    static let quick: Animation = .spring(response: 0.16, dampingFraction: 0.88)
    static let page: Animation = .spring(response: 0.30, dampingFraction: 0.90)
    static let snap: Animation = .spring(response: 0.20, dampingFraction: 0.88)
    static let smooth: Animation = .spring(response: 0.26, dampingFraction: 0.90)
    static let micro: Animation = .spring(response: 0.10, dampingFraction: 0.92)

    // NOTE: ambientPulse intentionally OMITTED from v3.
    // v2's .repeatForever caused 70% idle CPU (Pitfall #10).
    // Use Task-based animation loops instead.

    // Physics UI springs — complement the base 5 with interaction-specific curves.
    static let settle: Animation = .spring(response: 0.35, dampingFraction: 0.65)    // underdamped: slight overshoot on settle
    static let sharp: Animation = .spring(response: 0.12, dampingFraction: 0.78)     // decisive snap with hint of bounce
    static let elastic: Animation = .spring(response: 0.40, dampingFraction: 0.55)   // playful: entrances/exits only
    static let inertial: Animation = .spring(response: 0.50, dampingFraction: 0.85)  // heavy: panel slides, window drag settle

    // Breathing timer rate — NOT a SwiftUI Animation.
    // Used by CADisplayLink/Timer-driven ambient effects (block gutter indent guides).
    static let breathRate: TimeInterval = 1.0 / 30.0
}
