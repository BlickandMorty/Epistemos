import SwiftUI

// MARK: - Theme Definition
// 8 themes — 4 light (White, Sunny, Tan, Magnolia) + 4 dark (Sunset, OLED, Ember, Nocturne).

enum EpistemosTheme: String, CaseIterable, Codable, Sendable {
    case light = "light"
    case sunny = "sunny"
    case tan = "tan"
    case magnolia = "magnolia"
    case sunset = "sunset"
    case oled = "oled"
    case ember = "ember"
    case nocturne = "nocturne"

    var displayName: String {
        switch self {
        case .light:  "White"
        case .sunny:  "Sunny"
        case .tan:    "Tan"
        case .magnolia: "Magnolia"
        case .sunset: "Sunset"
        case .oled:   "OLED"
        case .ember:  "Ember"
        case .nocturne: "Nocturne"
        }
    }

    var isDark: Bool {
        switch self {
        case .light, .sunny, .tan, .magnolia: false
        case .sunset, .oled, .ember, .nocturne: true
        }
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var usesNativeWindowBlur: Bool { self == .magnolia || self == .nocturne }

    // MARK: - Core Colors

    var background: Color {
        switch self {
        case .light:  .white
        case .sunny:  Color(hex: 0xE8F4FB)
        case .tan:    Color(hex: 0xF5EFE6)
        case .magnolia: Color(hex: 0xF7F2F5)
        case .sunset: Color(hex: 0x1E1220)
        case .oled:   Color(hex: 0x000000)
        case .ember:  Color(hex: 0x1C1410)
        case .nocturne: Color(hex: 0x19141F)
        }
    }

    var foreground: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E)
        case .sunny:  Color(hex: 0x233040)
        case .tan:    Color(hex: 0x362816)
        case .magnolia: Color(hex: 0x342E35)
        case .sunset: Color(hex: 0xE8E0D8)
        case .oled:   Color(hex: 0xDADADE)
        case .ember:  Color(hex: 0xE0D4C8)
        case .nocturne: Color(hex: 0xE7DEE8)
        }
    }

    var accent: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E)
        case .sunny:  Color(hex: 0x5B8FC7)
        case .tan:    Color(hex: 0x8B5E3C)
        case .magnolia: Color(hex: 0x8E7282)
        case .sunset: Color(hex: 0xD4862B)
        case .oled:   Color(hex: 0xDADADE)
        case .ember:  Color(hex: 0xC8762A)
        case .nocturne: Color(hex: 0xA8B6D9)
        }
    }

    var fontAccent: Color {
        switch self {
        case .light:  Color(hex: 0x1A1A1A)
        case .sunny:  Color(hex: 0xD4A843)
        case .tan:    Color(hex: 0x6B3E1C)
        case .magnolia: Color(hex: 0x6E7E97)
        case .sunset: Color(hex: 0xF5B84A)
        case .oled:   Color(hex: 0xFFFFFF)
        case .ember:  Color(hex: 0xE8A040)
        case .nocturne: Color(hex: 0xD7A7B6)
        }
    }

    var uiAccent: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E)
        case .sunny:  Color(hex: 0x233040)
        case .tan:    Color(hex: 0x362816)
        case .magnolia: Color(hex: 0x342E35)
        case .sunset: Color(hex: 0xE8E0D8)
        case .oled:   Color(hex: 0xDADADE)
        case .ember:  Color(hex: 0xE0D4C8)
        case .nocturne: Color(hex: 0xE7DEE8)
        }
    }

    // MARK: - Surface Colors

    var muted: Color {
        switch self {
        case .light:  Color(hex: 0xF0F0F0)
        case .sunny:  Color(red: 210/255, green: 230/255, blue: 245/255).opacity(0.75)
        case .tan:    Color(hex: 0xEADDCC)
        case .magnolia: Color(hex: 0xECE4E9)
        case .sunset: Color(hex: 0x322030)
        case .oled:   Color(hex: 0x141414)
        case .ember:  Color(hex: 0x2A1E14)
        case .nocturne: Color(hex: 0x27212D)
        }
    }

    var mutedForeground: Color {
        switch self {
        case .light:  Color(hex: 0x4A4A4A)
        case .sunny:  Color(hex: 0x5A7A94)
        case .tan:    Color(hex: 0x9A7A5A)
        case .magnolia: Color(hex: 0x7E737C)
        case .sunset: Color(hex: 0xB09888)
        case .oled:   Color(hex: 0x8A8A8A)
        case .ember:  Color(hex: 0xA08060)
        case .nocturne: Color(hex: 0xA89CA8)
        }
    }

    var border: Color {
        switch self {
        case .light:  Color(red: 0, green: 0, blue: 0).opacity(0.1)
        case .sunny:  Color(red: 130/255, green: 170/255, blue: 210/255).opacity(0.28)
        case .tan:    Color(hex: 0xC4A882).opacity(0.35)
        case .magnolia: Color(hex: 0xC6BAC3).opacity(0.42)
        case .sunset: Color(hex: 0x3D2838)
        case .oled:   Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.55)
        case .ember:  Color(hex: 0x3A2818)
        case .nocturne: Color(hex: 0x3B3243)
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
        switch self {
        case .light:  Color(hex: 0x2B8A8A)
        case .sunny:  Color(hex: 0x287878)
        case .tan:    Color(hex: 0x3A8888)
        case .magnolia: Color(hex: 0x6D8CA8)
        case .sunset: Color(hex: 0x5EC4C4)
        case .oled:   Color(hex: 0x56B6B6)
        case .ember:  Color(hex: 0x5AACAC)
        case .nocturne: Color(hex: 0x7DB3C4)
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
        switch self {
        case .light:  Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.88)
        case .sunny:  Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.75)
        case .tan:    Color(hex: 0xF0E4D0).opacity(0.85)
        case .magnolia: Color(hex: 0xFBF7F9).opacity(0.88)
        case .sunset: Color(hex: 0x241828).opacity(0.85)
        case .oled:   Color(red: 16/255, green: 16/255, blue: 16/255).opacity(0.82)
        case .ember:  Color(hex: 0x241A10).opacity(0.88)
        case .nocturne: Color(hex: 0x221C2A).opacity(0.86)
        }
    }

    var glassBorder: Color {
        switch self {
        case .light:  Color(red: 0, green: 0, blue: 0).opacity(0.08)
        case .sunny:  Color(red: 130/255, green: 170/255, blue: 210/255).opacity(0.22)
        case .tan:    Color(hex: 0xC4A882).opacity(0.28)
        case .magnolia: Color(hex: 0xC6BAC3).opacity(0.30)
        case .sunset: Color(hex: 0x3A2434)
        case .oled:   Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.32)
        case .ember:  Color(hex: 0x402C1C)
        case .nocturne: Color(hex: 0x443A4D)
        }
    }

    var glassHover: Color {
        switch self {
        case .light:  Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.8)
        case .sunny:  Color(red: 225/255, green: 240/255, blue: 252/255).opacity(0.65)
        case .tan:    Color(hex: 0xDFCDB0).opacity(0.75)
        case .magnolia: Color(hex: 0xE9DEE5).opacity(0.78)
        case .sunset: Color(hex: 0x342030)
        case .oled:   Color(red: 28/255, green: 28/255, blue: 28/255).opacity(0.7)
        case .ember:  Color(hex: 0x30201A).opacity(0.75)
        case .nocturne: Color(hex: 0x342B3D).opacity(0.78)
        }
    }

    // MARK: - Nav Pill Colors

    var navPillBg: Color {
        switch self {
        case .light:  Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.7)
        case .sunny:  Color(red: 215/255, green: 235/255, blue: 250/255).opacity(0.7)
        case .tan:    Color(hex: 0xE8D9C0).opacity(0.78)
        case .magnolia: Color(hex: 0xEFE5EA).opacity(0.82)
        case .sunset: Color(hex: 0x1C1022).opacity(0.8)
        case .oled:   Color(red: 8/255, green: 8/255, blue: 8/255).opacity(0.85)
        case .ember:  Color(hex: 0x141008).opacity(0.88)
        case .nocturne: Color(hex: 0x140F18).opacity(0.90)
        }
    }

    var navPillBorder: Color { glassBorder }

    var navBubbleActiveBg: Color {
        switch self {
        case .light:  Color(red: 0, green: 0, blue: 0).opacity(0.08)
        case .sunny:  Color(red: 180/255, green: 215/255, blue: 245/255).opacity(0.45)
        case .tan:    Color(hex: 0xC4A07A).opacity(0.30)
        case .magnolia: Color(hex: 0xD8C7D1).opacity(0.42)
        case .sunset: Color(hex: 0x3C2434).opacity(0.75)
        case .oled:   Color(red: 20/255, green: 20/255, blue: 20/255).opacity(0.7)
        case .ember:  Color(hex: 0x3A2414).opacity(0.8)
        case .nocturne: Color(hex: 0x3A3046).opacity(0.78)
        }
    }

    var navBubbleActiveText: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E).opacity(0.88)
        case .sunny:  Color(hex: 0x233040).opacity(0.92)
        case .tan:    Color(hex: 0x362816).opacity(0.92)
        case .magnolia: Color(hex: 0x342E35).opacity(0.92)
        case .sunset: Color(hex: 0xE8E0D8).opacity(0.92)
        case .oled:   Color(hex: 0xDADADE).opacity(0.92)
        case .ember:  Color(hex: 0xE0D4C8).opacity(0.92)
        case .nocturne: Color(hex: 0xEEE4EC).opacity(0.94)
        }
    }

    var navBubbleInactiveText: Color {
        switch self {
        case .light:  Color(hex: 0x000000).opacity(0.5)
        case .sunny:  Color(hex: 0x5A7A94).opacity(0.92)
        case .tan:    Color(hex: 0x9A7A5A).opacity(0.85)
        case .magnolia: Color(hex: 0x7E737C).opacity(0.90)
        case .sunset: Color(hex: 0xB09888).opacity(0.92)
        case .oled:   Color(red: 180/255, green: 180/255, blue: 180/255).opacity(0.92)
        case .ember:  Color(hex: 0xA08060).opacity(0.92)
        case .nocturne: Color(hex: 0xA89CA8).opacity(0.92)
        }
    }

    // MARK: - Card / Surface

    var card: Color {
        switch self {
        case .light:  Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.92)
        case .sunny:  Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.78)
        case .tan:    Color(hex: 0xEDE0CA).opacity(0.88)
        case .magnolia: Color(hex: 0xFCF9FB).opacity(0.92)
        case .sunset: Color(hex: 0x241828).opacity(0.88)
        case .oled:   Color(red: 18/255, green: 18/255, blue: 18/255).opacity(0.92)
        case .ember:  Color(hex: 0x241A10).opacity(0.90)
        case .nocturne: Color(hex: 0x241E2B).opacity(0.90)
        }
    }

    var chatSurface: Color {
        switch self {
        case .light:  .white
        case .sunny:  Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.72)
        case .tan:    Color(hex: 0xF5EFE6)
        case .magnolia: Color(hex: 0xFBF7F9)
        case .sunset: Color(hex: 0x1E1220)
        case .oled:   Color(hex: 0x000000)
        case .ember:  Color(hex: 0x1C1410)
        case .nocturne: Color(hex: 0x19141F)
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
    var hoverOverlay: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04) }
    var glassTint: Color { glassBg }
    var pressedOverlay: Color { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08) }

    var userBubbleBg: Color {
        switch self {
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
        switch self {
        case .tan:    Color(hex: 0xF0EBE4).opacity(0.92)
        case .light:  Color(hex: 0xEEEEEE).opacity(0.92)
        case .oled:   Color(hex: 0xDADADE).opacity(0.88)
        case .ember:  Color(hex: 0xEADED0).opacity(0.90)
        case .sunset: Color(hex: 0xE8E0D8).opacity(0.90)
        case .magnolia: Color(hex: 0xF6F0F5).opacity(0.94)
        case .nocturne: Color(hex: 0xF2E7EE).opacity(0.92)
        default:      foreground
        }
    }

    var sidebarBackground: Color { glassBg }

    // MARK: - NSColor for Window Chrome

    var nsBackground: NSColor {
        switch self {
        case .light:  .white
        case .sunny:  NSColor(red: 0xE8/255, green: 0xF4/255, blue: 0xFB/255, alpha: 1)
        case .tan:    NSColor(red: 0xF5/255, green: 0xEF/255, blue: 0xE6/255, alpha: 1)
        case .magnolia: NSColor(red: 0xF7/255, green: 0xF2/255, blue: 0xF5/255, alpha: 1)
        case .sunset: NSColor(red: 0x1E/255, green: 0x12/255, blue: 0x20/255, alpha: 1)
        case .oled:   .black
        case .ember:  NSColor(red: 0x1C/255, green: 0x14/255, blue: 0x10/255, alpha: 1)
        case .nocturne: NSColor(red: 0x19/255, green: 0x14/255, blue: 0x1F/255, alpha: 1)
        }
    }
}

// MARK: - Theme Pair

enum ThemePair: String, CaseIterable, Codable, Sendable {
    case magnolia = "magnolia"
    case classic = "classic"
    case warmth  = "warmth"
    case ember   = "ember"

    var displayName: String {
        switch self {
        case .magnolia: "Magnolia"
        case .classic: "Classic"
        case .warmth:  "Warmth"
        case .ember:   "Ember"
        }
    }

    var description: String {
        switch self {
        case .magnolia: "Magnolia · Nocturne"
        case .classic: "White · OLED"
        case .warmth:  "Sunny · Sunset"
        case .ember:   "Tan · Ember"
        }
    }

    var lightTheme: EpistemosTheme {
        switch self {
        case .magnolia: .magnolia
        case .classic: .light
        case .warmth:  .sunny
        case .ember:   .tan
        }
    }

    var darkTheme: EpistemosTheme {
        switch self {
        case .magnolia: .nocturne
        case .classic: .oled
        case .warmth:  .sunset
        case .ember:   .ember
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
    init(hex: UInt32) {
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
