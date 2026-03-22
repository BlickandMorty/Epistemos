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
        switch self {
        case .systemLight, .light, .sunny, .tan, .magnolia, .platinum, .platinumViolet: false
        case .systemDark, .sunset, .oled, .ember, .nocturne, .platinumDark, .platinumVioletDark: true
        }
    }
    
    /// Whether this theme uses Platinum styling (beveled buttons, racing stripes)
    var isPlatinum: Bool {
        switch self {
        case .platinum, .platinumDark, .platinumViolet, .platinumVioletDark: true
        default: false
        }
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var usesNativeWindowBlur: Bool {
        self == .systemLight || self == .systemDark || self == .magnolia || self == .nocturne
    }
    private var isSystemDefaultToken: Bool { self == .systemLight || self == .systemDark }

    // MARK: - Core Colors

    var background: Color {
        if isSystemDefaultToken {
            return Color(nsColor: .windowBackgroundColor)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return .white
        case .sunny:  return Color(hex: 0xE8F4FB)
        case .tan:    return Color(hex: 0xF5EFE6)
        case .magnolia: return Color(hex: 0xF7F2F5)
        case .sunset: return Color(hex: 0x1E1220)
        case .oled:   return Color(hex: 0x000000)
        case .ember:  return Color(hex: 0x1C1410)
        case .nocturne: return Color(hex: 0x19141F)
        case .platinum, .platinumViolet:
            return Color(hex: 0xDEDEDE)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x1E1E24)
        }
    }

    nonisolated var foregroundHex: UInt32 {
        if self == .systemLight { return 0x1C1C1E }
        if self == .systemDark { return 0xF2F2F7 }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return 0x1C1C1E
        case .sunny:  return 0x233040
        case .tan:    return 0x362816
        case .magnolia: return 0x342E35
        case .sunset: return 0xE8E0D8
        case .oled:   return 0xDADADE
        case .ember:  return 0xE0D4C8
        case .nocturne: return 0xE7DEE8
        case .platinum, .platinumViolet: return 0x000000
        case .platinumDark, .platinumVioletDark: return 0xFFFFFF
        }
    }

    var foreground: Color { Color(hex: foregroundHex) }

    var accent: Color {
        if self == .systemLight { return Color(hex: 0x1C1C1E) }
        if self == .systemDark { return Color(hex: 0xF2F2F7) }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(hex: 0x1C1C1E)
        case .sunny:  return Color(hex: 0x5B8FC7)
        case .tan:    return Color(hex: 0x8B5E3C)
        case .magnolia: return Color(hex: 0x8E7282)
        case .sunset: return Color(hex: 0xD4862B)
        case .oled:   return Color(hex: 0xDADADE)
        case .ember:  return Color(hex: 0xC8762A)
        case .nocturne: return Color(hex: 0xA8B6D9)
        case .platinum: return Color(hex: 0x111111)
        case .platinumDark: return Color(hex: 0xF2F2F2)
        case .platinumViolet: return Color(hex: 0x000080)
        case .platinumVioletDark: return Color(hex: 0x7B68EE)
        }
    }

    nonisolated var headingAccentHex: UInt32 {
        if self == .systemLight { return 0x1A1A1A }
        if self == .systemDark { return 0xF2F2F7 }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return 0x1A1A1A
        case .sunny:  return 0xD4A843
        case .tan:    return 0x6B3E1C
        case .magnolia: return 0xB86F8D
        case .sunset: return 0xF5B84A
        case .oled:   return 0xFFFFFF
        case .ember:  return 0xE8A040
        case .nocturne: return 0xD7A7B6
        case .platinum: return 0x111111
        case .platinumDark: return 0xF2F2F2
        case .platinumViolet: return 0x000000
        case .platinumVioletDark: return 0xFFFFFF
        }
    }

    nonisolated var markdownHeadingAccentHex: UInt32 {
        switch self {
        case .platinum:
            0x111111
        case .platinumDark:
            0xF2F2F2
        case .platinumViolet:
            0x00007B
        case .platinumVioletDark:
            0x7B68EE
        default:
            headingAccentHex
        }
    }

    nonisolated var preferredMarkdownLinkHex: UInt32? {
        switch self {
        case .platinum, .platinumViolet:
            markdownHeadingAccentHex
        default:
            nil
        }
    }

    var fontAccent: Color {
        Color(hex: headingAccentHex)
    }

    var markdownHeadingAccent: Color {
        Color(hex: markdownHeadingAccentHex)
    }

    var preferredMarkdownLinkColor: Color? {
        guard let preferredMarkdownLinkHex else { return nil }
        return Color(hex: preferredMarkdownLinkHex)
    }

    var preferredMarkdownLinkNSColor: NSColor? {
        guard let preferredMarkdownLinkHex else { return nil }
        return NSColor(Color(hex: preferredMarkdownLinkHex))
    }

    var uiAccent: Color {
        if self == .systemLight { return Color(hex: 0x1C1C1E) }
        if self == .systemDark { return Color(hex: 0xF2F2F7) }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(hex: 0x1C1C1E)
        case .sunny:  return Color(hex: 0x233040)
        case .tan:    return Color(hex: 0x362816)
        case .magnolia: return Color(hex: 0x342E35)
        case .sunset: return Color(hex: 0xE8E0D8)
        case .oled:   return Color(hex: 0xDADADE)
        case .ember:  return Color(hex: 0xE0D4C8)
        case .nocturne: return Color(hex: 0xE7DEE8)
        case .platinum: return Color(hex: 0x111111)
        case .platinumDark: return Color(hex: 0xF2F2F2)
        case .platinumViolet: return Color(hex: 0x000080)
        case .platinumVioletDark: return Color(hex: 0x7B68EE)
        }
    }

    // MARK: - Surface Colors

    var muted: Color {
        if isSystemDefaultToken {
            return Color(nsColor: .controlBackgroundColor)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(hex: 0xF0F0F0)
        case .sunny:  return Color(red: 210/255, green: 230/255, blue: 245/255).opacity(0.75)
        case .tan:    return Color(hex: 0xEADDCC)
        case .magnolia: return Color(hex: 0xECE4E9)
        case .sunset: return Color(hex: 0x322030)
        case .oled:   return Color(hex: 0x141414)
        case .ember:  return Color(hex: 0x2A1E14)
        case .nocturne: return Color(hex: 0x27212D)
        case .platinum, .platinumViolet:
            return Color(hex: 0xCCCCCC)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x252530)
        }
    }

    nonisolated var mutedForegroundHex: UInt32 {
        if self == .systemLight { return 0x6E6E73 }
        if self == .systemDark { return 0x98989D }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return 0x4A4A4A
        case .sunny:  return 0x5A7A94
        case .tan:    return 0x9A7A5A
        case .magnolia: return 0x7E737C
        case .sunset: return 0xB09888
        case .oled:   return 0x8A8A8A
        case .ember:  return 0xA08060
        case .nocturne: return 0xA89CA8
        case .platinum, .platinumViolet: return 0x555555
        case .platinumDark, .platinumVioletDark: return 0x9090A0
        }
    }

    var mutedForeground: Color { Color(hex: mutedForegroundHex) }

    nonisolated var assistantBubbleForegroundHex: UInt32 {
        switch self {
        case .platinum, .platinumViolet:
            mutedForegroundHex
        default:
            foregroundHex
        }
    }

    var assistantBubbleForeground: Color { Color(hex: assistantBubbleForegroundHex) }

    nonisolated var assistantBubbleBackgroundHex: UInt32? {
        nil
    }

    var assistantBubbleBackground: Color {
        guard let assistantBubbleBackgroundHex else { return .clear }
        return Color(hex: assistantBubbleBackgroundHex)
    }

    nonisolated var userBubbleBackgroundHex: UInt32? {
        switch self {
        case .platinum:
            0x111111
        case .platinumDark:
            0x2A2A38
        default:
            nil
        }
    }

    var border: Color {
        if self == .systemLight { return Color.black.opacity(0.10) }
        if self == .systemDark { return Color.white.opacity(0.12) }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 0, green: 0, blue: 0).opacity(0.1)
        case .sunny:  return Color(red: 130/255, green: 170/255, blue: 210/255).opacity(0.28)
        case .tan:    return Color(hex: 0xC4A882).opacity(0.35)
        case .magnolia: return Color(hex: 0xC6BAC3).opacity(0.42)
        case .sunset: return Color(hex: 0x3D2838)
        case .oled:   return Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.55)
        case .ember:  return Color(hex: 0x3A2818)
        case .nocturne: return Color(hex: 0x3B3243)
        case .platinum, .platinumViolet: return Color.black.opacity(0.2)
        case .platinumDark, .platinumVioletDark: return Color.white.opacity(0.15)
        }
    }

    var destructive: Color { Color(hex: 0xC75E5E) }

    // MARK: - Semantic Accent Colors (centralized from scattered hex values)

    var emerald: Color { Color(hex: 0x34D399) }   // Data tags, positive indicators
    var amber: Color   { Color(hex: 0xD4A843) }   // Model tags, warning indicators
    var violet: Color  { Color(hex: 0x9B7DB8) }   // Uncertain tags, neutral
    var coral: Color   { Color(hex: 0xC75E5E) }   // Conflict, error (same as destructive)
    var indigo: Color  { Color(hex: 0x8B7CF6) }   // Research accent, library stats

    // MARK: - Code Token Colors (syntax highlighting)

    var codeKeyword: Color { accent }
    var codeString: Color { emerald }
    var codeNumber: Color { amber }
    var codeComment: Color { mutedForeground }
    var codeFunction: Color { violet }
    var codeType: Color {
        if self == .systemLight { return Color(hex: 0x2B8A8A) }
        if self == .systemDark { return Color(hex: 0x7DB3C4) }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(hex: 0x2B8A8A)
        case .sunny:  return Color(hex: 0x287878)
        case .tan:    return Color(hex: 0x3A8888)
        case .magnolia: return Color(hex: 0x6D8CA8)
        case .sunset: return Color(hex: 0x5EC4C4)
        case .oled:   return Color(hex: 0x56B6B6)
        case .ember:  return Color(hex: 0x5AACAC)
        case .nocturne: return Color(hex: 0x7DB3C4)
        case .platinum: return Color(hex: 0x111111)
        case .platinumDark: return Color(hex: 0xF2F2F2)
        case .platinumViolet: return Color(hex: 0x000080)
        case .platinumVioletDark: return Color(hex: 0x7B68EE)
        }
    }
    var codeProperty: Color { fontAccent }
    var codeConstant: Color { amber }
    var codeTag: Color { accent }
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
        case 6:   return NSColor(foreground).withAlphaComponent(0.6) // operator
        case 7:   return NSColor(foreground).withAlphaComponent(0.5) // punctuation
        case 8:   return NSColor(foreground)     // variable
        case 9:   return NSColor(codeProperty)   // property
        case 10:  return NSColor(codeConstant)   // constant
        case 11:  return NSColor(codeTag)        // tag
        case 12:  return NSColor(codeAttribute)  // attribute
        default:  return NSColor(foreground)     // plain
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
        if self == .systemLight {
            return Color.white.opacity(0.88)
        }
        if self == .systemDark {
            return Color(nsColor: .controlBackgroundColor).opacity(0.86)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.88)
        case .sunny:  return Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.75)
        case .tan:    return Color(hex: 0xF0E4D0).opacity(0.85)
        case .magnolia: return Color(hex: 0xFBF7F9).opacity(0.88)
        case .sunset: return Color(hex: 0x241828).opacity(0.85)
        case .oled:   return Color(red: 16/255, green: 16/255, blue: 16/255).opacity(0.82)
        case .ember:  return Color(hex: 0x241A10).opacity(0.88)
        case .nocturne: return Color(hex: 0x221C2A).opacity(0.86)
        case .platinum, .platinumViolet:
            return Color(hex: 0xDDDDDD)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x2D2D38)
        }
    }

    var glassBorder: Color {
        if self == .systemLight { return Color.black.opacity(0.08) }
        if self == .systemDark { return Color.white.opacity(0.08) }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 0, green: 0, blue: 0).opacity(0.08)
        case .sunny:  return Color(red: 130/255, green: 170/255, blue: 210/255).opacity(0.22)
        case .tan:    return Color(hex: 0xC4A882).opacity(0.28)
        case .magnolia: return Color(hex: 0xC6BAC3).opacity(0.30)
        case .sunset: return Color(hex: 0x3A2434)
        case .oled:   return Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.32)
        case .ember:  return Color(hex: 0x402C1C)
        case .nocturne: return Color(hex: 0x443A4D)
        case .platinum, .platinumViolet: return Color.black.opacity(0.1)
        case .platinumDark, .platinumVioletDark: return Color.white.opacity(0.08)
        }
    }

    var glassHover: Color {
        if self == .systemLight {
            return Color(nsColor: .controlBackgroundColor).opacity(0.72)
        }
        if self == .systemDark {
            return Color.white.opacity(0.08)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.8)
        case .sunny:  return Color(red: 225/255, green: 240/255, blue: 252/255).opacity(0.65)
        case .tan:    return Color(hex: 0xDFCDB0).opacity(0.75)
        case .magnolia: return Color(hex: 0xE9DEE5).opacity(0.78)
        case .sunset: return Color(hex: 0x342030)
        case .oled:   return Color(red: 28/255, green: 28/255, blue: 28/255).opacity(0.7)
        case .ember:  return Color(hex: 0x30201A).opacity(0.75)
        case .nocturne: return Color(hex: 0x342B3D).opacity(0.78)
        case .platinum, .platinumViolet:
            return Color(hex: 0xCCCCCC)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x353545)
        }
    }

    var floatingSurfaceTint: Color {
        if self == .systemLight { return Color(hex: 0xF4F4F6) }
        if self == .systemDark { return Color(hex: 0x1E1E22) }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:
            return Color(hex: 0xF2F2F2)
        case .sunny:
            return Color(hex: 0xF6FBFE)
        case .tan:
            return Color(hex: 0xFBF5EB)
        case .magnolia:
            return Color(hex: 0xFEFBFD)
        case .sunset:
            return Color(hex: 0x161018)
        case .oled:
            return Color(hex: 0x2A2A2F)
        case .ember:
            return Color(hex: 0x16100C)
        case .nocturne:
            return Color(hex: 0x141019)
        case .platinum, .platinumViolet:
            return Color(hex: 0xF4F4F4)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x17171D)
        }
    }

    // MARK: - Nav Pill Colors

    var navPillBg: Color {
        if self == .systemLight {
            return Color(hex: 0xF2F2F5).opacity(0.82)
        }
        if self == .systemDark {
            return Color(hex: 0x1B1B1F).opacity(0.90)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.7)
        case .sunny:  return Color(red: 215/255, green: 235/255, blue: 250/255).opacity(0.7)
        case .tan:    return Color(hex: 0xE8D9C0).opacity(0.78)
        case .magnolia: return Color(hex: 0xEFE5EA).opacity(0.82)
        case .sunset: return Color(hex: 0x1C1022).opacity(0.8)
        case .oled:   return Color(red: 8/255, green: 8/255, blue: 8/255).opacity(0.85)
        case .ember:  return Color(hex: 0x141008).opacity(0.88)
        case .nocturne: return Color(hex: 0x140F18).opacity(0.90)
        case .platinum, .platinumViolet:
            return Color(hex: 0xDDDDDD)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x2D2D38)
        }
    }

    var navPillBorder: Color { glassBorder }

    var navBubbleActiveBg: Color {
        if self == .systemLight {
            return Color.black.opacity(0.08)
        }
        if self == .systemDark {
            return Color.white.opacity(0.14)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 0, green: 0, blue: 0).opacity(0.08)
        case .sunny:  return Color(red: 180/255, green: 215/255, blue: 245/255).opacity(0.45)
        case .tan:    return Color(hex: 0xC4A07A).opacity(0.30)
        case .magnolia: return Color(hex: 0xD8C7D1).opacity(0.42)
        case .sunset: return Color(hex: 0x3C2434).opacity(0.75)
        case .oled:   return Color(red: 20/255, green: 20/255, blue: 20/255).opacity(0.7)
        case .ember:  return Color(hex: 0x3A2414).opacity(0.8)
        case .nocturne: return Color(hex: 0x3A3046).opacity(0.78)
        case .platinum: return Color(hex: 0x111111)
        case .platinumDark: return Color(hex: 0xF2F2F2)
        case .platinumViolet: return Color(hex: 0x000080)
        case .platinumVioletDark: return Color(hex: 0x6B5DD6)
        }
    }

    var navBubbleActiveText: Color {
        if self == .systemLight {
            return Color(hex: 0x1C1C1E).opacity(0.90)
        }
        if self == .systemDark {
            return Color(hex: 0xF2F2F7).opacity(0.92)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(hex: 0x1C1C1E).opacity(0.88)
        case .sunny:  return Color(hex: 0x233040).opacity(0.92)
        case .tan:    return Color(hex: 0x362816).opacity(0.92)
        case .magnolia: return Color(hex: 0x342E35).opacity(0.92)
        case .sunset: return Color(hex: 0xE8E0D8).opacity(0.92)
        case .oled:   return Color(hex: 0xDADADE).opacity(0.92)
        case .ember:  return Color(hex: 0xE0D4C8).opacity(0.92)
        case .nocturne: return Color(hex: 0xEEE4EC).opacity(0.94)
        case .platinum: return Color(hex: 0xF2F2F2).opacity(0.94)
        case .platinumDark: return Color(hex: 0x111111).opacity(0.88)
        case .platinumViolet: return Color.black.opacity(0.7)
        case .platinumVioletDark: return Color.white.opacity(0.75)
        }
    }

    var navBubbleInactiveText: Color {
        if self == .systemLight {
            return Color(hex: 0x6E6E73).opacity(0.92)
        }
        if self == .systemDark {
            return Color(hex: 0x98989D).opacity(0.92)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(hex: 0x000000).opacity(0.5)
        case .sunny:  return Color(hex: 0x5A7A94).opacity(0.92)
        case .tan:    return Color(hex: 0x9A7A5A).opacity(0.85)
        case .magnolia: return Color(hex: 0x7E737C).opacity(0.90)
        case .sunset: return Color(hex: 0xB09888).opacity(0.92)
        case .oled:   return Color(red: 180/255, green: 180/255, blue: 180/255).opacity(0.92)
        case .ember:  return Color(hex: 0xA08060).opacity(0.92)
        case .nocturne: return Color(hex: 0xA89CA8).opacity(0.92)
        case .platinum, .platinumViolet: return Color.black.opacity(0.5)
        case .platinumDark, .platinumVioletDark: return Color.white.opacity(0.6)
        }
    }

    // MARK: - Card / Surface

    var card: Color {
        if self == .systemLight {
            return Color.white.opacity(0.90)
        }
        if self == .systemDark {
            return Color(nsColor: .controlBackgroundColor).opacity(0.92)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.92)
        case .sunny:  return Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.78)
        case .tan:    return Color(hex: 0xEDE0CA).opacity(0.88)
        case .magnolia: return Color(hex: 0xFCF9FB).opacity(0.92)
        case .sunset: return Color(hex: 0x241828).opacity(0.88)
        case .oled:   return Color(red: 18/255, green: 18/255, blue: 18/255).opacity(0.92)
        case .ember:  return Color(hex: 0x241A10).opacity(0.90)
        case .nocturne: return Color(hex: 0x241E2B).opacity(0.90)
        case .platinum, .platinumViolet:
            return Color(hex: 0xDDDDDD)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x252530)
        }
    }

    var chatSurface: Color {
        if isSystemDefaultToken {
            return Color(nsColor: .windowBackgroundColor)
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return .white
        case .sunny:  return Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.72)
        case .tan:    return Color(hex: 0xF5EFE6)
        case .magnolia: return Color(hex: 0xFBF7F9)
        case .sunset: return Color(hex: 0x1E1220)
        case .oled:   return Color(hex: 0x000000)
        case .ember:  return Color(hex: 0x1C1410)
        case .nocturne: return Color(hex: 0x19141F)
        case .platinum, .platinumViolet:
            return Color(hex: 0xEEEEEE)
        case .platinumDark, .platinumVioletDark:
            return Color(hex: 0x2A2A38)
        }
    }

    // MARK: - Status Colors

    var success: Color { Color(hex: 0x4CAF50) }
    var warning: Color { Color(hex: 0xE5A440) }
    var error: Color   { Color(hex: 0xEF5B5B) }
    var info: Color    { Color(hex: 0x5B8DEF) }

    // MARK: - Convenience

    var textPrimary: Color { foreground }
    var textSecondary: Color { mutedForeground }
    var textTertiary: Color { mutedForeground.opacity(0.7) }
    var chatStrongForeground: Color { isDark ? mutedForeground : accent }
    var hoverOverlay: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04) }
    var glassTint: Color { glassBg }
    var pressedOverlay: Color { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08) }

    var userBubbleBg: Color {
        if let userBubbleBackgroundHex {
            return Color(hex: userBubbleBackgroundHex)
        }
        if self == .systemLight {
            return Color(hex: 0x1A1A1E)
        }
        if self == .systemDark {
            return Color(hex: 0x2A2A30)
        }
        return switch self {
        case .tan:    Color(hex: 0x6B3D1A)
        case .sunset: Color(hex: 0x3A2040)
        case .oled:   Color(hex: 0x2A2A2A)
        case .ember:  Color(hex: 0x3C2010)
        case .light:  Color(hex: 0x1A1A1A)
        case .magnolia: Color(hex: 0x6A5F70)
        case .nocturne: Color(hex: 0x313444)
        default:      accent
        }
    }

    var userBubbleText: Color {
        if isSystemDefaultToken {
            return Color(hex: 0xF2F2F7).opacity(0.92)
        }
        switch self {
        case .platinum, .platinumDark, .platinumViolet, .platinumVioletDark:
            return Color(hex: 0xF2F2F2).opacity(0.94)
        case .tan:    return Color(hex: 0xF0EBE4).opacity(0.92)
        case .light:  return Color(hex: 0xEEEEEE).opacity(0.92)
        case .oled:   return Color(hex: 0xDADADE).opacity(0.88)
        case .ember:  return Color(hex: 0xEADED0).opacity(0.90)
        case .sunset: return Color(hex: 0xE8E0D8).opacity(0.90)
        case .magnolia: return Color(hex: 0xF6F0F5).opacity(0.94)
        case .nocturne: return Color(hex: 0xF2E7EE).opacity(0.92)
        default:      return foreground
        }
    }

    var sidebarBackground: Color { glassBg }

    // MARK: - NSColor for Window Chrome

    var nsBackground: NSColor {
        if isSystemDefaultToken {
            return .windowBackgroundColor
        }
        switch self {
        case .systemLight, .systemDark:
            preconditionFailure("System themes are handled before switch")
        case .light:  return .white
        case .sunny:  return NSColor(red: 0xE8/255, green: 0xF4/255, blue: 0xFB/255, alpha: 1)
        case .tan:    return NSColor(red: 0xF5/255, green: 0xEF/255, blue: 0xE6/255, alpha: 1)
        case .magnolia: return NSColor(red: 0xF7/255, green: 0xF2/255, blue: 0xF5/255, alpha: 1)
        case .sunset: return NSColor(red: 0x1E/255, green: 0x12/255, blue: 0x20/255, alpha: 1)
        case .oled:   return .black
        case .ember:  return NSColor(red: 0x1C/255, green: 0x14/255, blue: 0x10/255, alpha: 1)
        case .nocturne: return NSColor(red: 0x19/255, green: 0x14/255, blue: 0x1F/255, alpha: 1)
        case .platinum, .platinumViolet:
            return NSColor(red: 0xDE/255, green: 0xDE/255, blue: 0xDE/255, alpha: 1)
        case .platinumDark, .platinumVioletDark:
            return NSColor(red: 0x1E/255, green: 0x1E/255, blue: 0x24/255, alpha: 1)
        }
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
    private static let orphanBracketRegex = try! NSRegularExpression(
        pattern: "\\[[A-Z][A-Z ]+\\](?!\\()"
    )
    private static let markdownLinkDestinationRegex = try! NSRegularExpression(
        pattern: #"\[[^\]]+\]\((https?://[^\s\)]+)\)"#
    )
    private static let urlDetector = try! NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    static func cleanedText(_ text: String) -> String {
        orphanBracketRegex.stringByReplacingMatches(
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
        let excludedRanges = markdownLinkDestinationRegex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ).map { $0.range(at: 1) }
        let matches = urlDetector.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )
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
