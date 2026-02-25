import SwiftUI

// MARK: - Theme Definition
// 6 themes — 3 light (White, Sunny, Tan) + 3 dark (Sunset, OLED, Ember).

enum EpistemosTheme: String, CaseIterable, Codable, Sendable {
    case light = "light"
    case sunny = "sunny"
    case tan = "tan"
    case sunset = "sunset"
    case oled = "oled"
    case ember = "ember"

    var displayName: String {
        switch self {
        case .light:  "White"
        case .sunny:  "Sunny"
        case .tan:    "Tan"
        case .sunset: "Sunset"
        case .oled:   "OLED"
        case .ember:  "Ember"
        }
    }

    var isDark: Bool {
        switch self {
        case .light, .sunny, .tan: false
        case .sunset, .oled, .ember: true
        }
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }

    // MARK: - Core Colors

    var background: Color {
        switch self {
        case .light:  .white
        case .sunny:  Color(hex: 0xE8F4FB)
        case .tan:    Color(hex: 0xF5EFE6)
        case .sunset: Color(hex: 0x1E1220)
        case .oled:   Color(hex: 0x000000)
        case .ember:  Color(hex: 0x1C1410)
        }
    }

    var foreground: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E)
        case .sunny:  Color(hex: 0x233040)
        case .tan:    Color(hex: 0x362816)
        case .sunset: Color(hex: 0xE8E0D8)
        case .oled:   Color(hex: 0xDADADE)
        case .ember:  Color(hex: 0xE0D4C8)
        }
    }

    var accent: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E)
        case .sunny:  Color(hex: 0x5B8FC7)
        case .tan:    Color(hex: 0x8B5E3C)
        case .sunset: Color(hex: 0xD4862B)
        case .oled:   Color(hex: 0xDADADE)
        case .ember:  Color(hex: 0xC8762A)
        }
    }

    var fontAccent: Color {
        switch self {
        case .light:  Color(hex: 0x1A1A1A)
        case .sunny:  Color(hex: 0xD4A843)
        case .tan:    Color(hex: 0x6B3E1C)
        case .sunset: Color(hex: 0xF5B84A)
        case .oled:   Color(hex: 0xFFFFFF)
        case .ember:  Color(hex: 0xE8A040)
        }
    }

    var uiAccent: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E)
        case .sunny:  Color(hex: 0x233040)
        case .tan:    Color(hex: 0x362816)
        case .sunset: Color(hex: 0xE8E0D8)
        case .oled:   Color(hex: 0xDADADE)
        case .ember:  Color(hex: 0xE0D4C8)
        }
    }

    // MARK: - Surface Colors

    var muted: Color {
        switch self {
        case .light:  Color(hex: 0xF0F0F0)
        case .sunny:  Color(red: 210/255, green: 230/255, blue: 245/255).opacity(0.75)
        case .tan:    Color(hex: 0xEADDCC)
        case .sunset: Color(hex: 0x322030)
        case .oled:   Color(hex: 0x141414)
        case .ember:  Color(hex: 0x2A1E14)
        }
    }

    var mutedForeground: Color {
        switch self {
        case .light:  Color(hex: 0x4A4A4A)
        case .sunny:  Color(hex: 0x5A7A94)
        case .tan:    Color(hex: 0x9A7A5A)
        case .sunset: Color(hex: 0xB09888)
        case .oled:   Color(hex: 0x8A8A8A)
        case .ember:  Color(hex: 0xA08060)
        }
    }

    var border: Color {
        switch self {
        case .light:  Color(red: 0, green: 0, blue: 0).opacity(0.1)
        case .sunny:  Color(red: 130/255, green: 170/255, blue: 210/255).opacity(0.28)
        case .tan:    Color(hex: 0xC4A882).opacity(0.35)
        case .sunset: Color(hex: 0x3D2838)
        case .oled:   Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.55)
        case .ember:  Color(hex: 0x3A2818)
        }
    }

    var destructive: Color { Color(hex: 0xC75E5E) }

    // MARK: - Semantic Accent Colors (centralized from scattered hex values)

    var emerald: Color { Color(hex: 0x34D399) }   // Data tags, positive indicators
    var amber: Color   { Color(hex: 0xD4A843) }   // Model tags, warning indicators
    var violet: Color  { Color(hex: 0x9B7DB8) }   // Uncertain tags, neutral
    var coral: Color   { Color(hex: 0xC75E5E) }   // Conflict, error (same as destructive)
    var indigo: Color  { Color(hex: 0x8B7CF6) }   // Research accent, library stats

    // MARK: - Glass Tokens

    var glassBg: Color {
        switch self {
        case .light:  Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.88)
        case .sunny:  Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.75)
        case .tan:    Color(hex: 0xF0E4D0).opacity(0.85)
        case .sunset: Color(hex: 0x241828).opacity(0.85)
        case .oled:   Color(red: 16/255, green: 16/255, blue: 16/255).opacity(0.82)
        case .ember:  Color(hex: 0x241A10).opacity(0.88)
        }
    }

    var glassBorder: Color {
        switch self {
        case .light:  Color(red: 0, green: 0, blue: 0).opacity(0.08)
        case .sunny:  Color(red: 130/255, green: 170/255, blue: 210/255).opacity(0.22)
        case .tan:    Color(hex: 0xC4A882).opacity(0.28)
        case .sunset: Color(hex: 0x3A2434)
        case .oled:   Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.32)
        case .ember:  Color(hex: 0x402C1C)
        }
    }

    var glassHover: Color {
        switch self {
        case .light:  Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.8)
        case .sunny:  Color(red: 225/255, green: 240/255, blue: 252/255).opacity(0.65)
        case .tan:    Color(hex: 0xDFCDB0).opacity(0.75)
        case .sunset: Color(hex: 0x342030)
        case .oled:   Color(red: 28/255, green: 28/255, blue: 28/255).opacity(0.7)
        case .ember:  Color(hex: 0x30201A).opacity(0.75)
        }
    }

    // MARK: - Nav Pill Colors

    var navPillBg: Color {
        switch self {
        case .light:  Color(red: 240/255, green: 240/255, blue: 240/255).opacity(0.7)
        case .sunny:  Color(red: 215/255, green: 235/255, blue: 250/255).opacity(0.7)
        case .tan:    Color(hex: 0xE8D9C0).opacity(0.78)
        case .sunset: Color(hex: 0x1C1022).opacity(0.8)
        case .oled:   Color(red: 8/255, green: 8/255, blue: 8/255).opacity(0.85)
        case .ember:  Color(hex: 0x141008).opacity(0.88)
        }
    }

    var navPillBorder: Color { glassBorder }

    var navBubbleActiveBg: Color {
        switch self {
        case .light:  Color(red: 0, green: 0, blue: 0).opacity(0.08)
        case .sunny:  Color(red: 180/255, green: 215/255, blue: 245/255).opacity(0.45)
        case .tan:    Color(hex: 0xC4A07A).opacity(0.30)
        case .sunset: Color(hex: 0x3C2434).opacity(0.75)
        case .oled:   Color(red: 20/255, green: 20/255, blue: 20/255).opacity(0.7)
        case .ember:  Color(hex: 0x3A2414).opacity(0.8)
        }
    }

    var navBubbleActiveText: Color {
        switch self {
        case .light:  Color(hex: 0x1C1C1E).opacity(0.88)
        case .sunny:  Color(hex: 0x233040).opacity(0.92)
        case .tan:    Color(hex: 0x362816).opacity(0.92)
        case .sunset: Color(hex: 0xE8E0D8).opacity(0.92)
        case .oled:   Color(hex: 0xDADADE).opacity(0.92)
        case .ember:  Color(hex: 0xE0D4C8).opacity(0.92)
        }
    }

    var navBubbleInactiveText: Color {
        switch self {
        case .light:  Color(hex: 0x000000).opacity(0.5)
        case .sunny:  Color(hex: 0x5A7A94).opacity(0.92)
        case .tan:    Color(hex: 0x9A7A5A).opacity(0.85)
        case .sunset: Color(hex: 0xB09888).opacity(0.92)
        case .oled:   Color(red: 180/255, green: 180/255, blue: 180/255).opacity(0.92)
        case .ember:  Color(hex: 0xA08060).opacity(0.92)
        }
    }

    // MARK: - Card / Surface

    var card: Color {
        switch self {
        case .light:  Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.92)
        case .sunny:  Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.78)
        case .tan:    Color(hex: 0xEDE0CA).opacity(0.88)
        case .sunset: Color(hex: 0x241828).opacity(0.88)
        case .oled:   Color(red: 18/255, green: 18/255, blue: 18/255).opacity(0.92)
        case .ember:  Color(hex: 0x241A10).opacity(0.90)
        }
    }

    var chatSurface: Color {
        switch self {
        case .light:  .white
        case .sunny:  Color(red: 235/255, green: 245/255, blue: 252/255).opacity(0.72)
        case .tan:    Color(hex: 0xF5EFE6)
        case .sunset: Color(hex: 0x1E1220)
        case .oled:   Color(hex: 0x000000)
        case .ember:  Color(hex: 0x1C1410)
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
        default:      foreground
        }
    }

    var sidebarBackground: Color { glassBg }
}

// MARK: - Theme Pair

enum ThemePair: String, CaseIterable, Codable, Sendable {
    case classic = "classic"
    case warmth  = "warmth"
    case ember   = "ember"

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .warmth:  "Warmth"
        case .ember:   "Ember"
        }
    }

    var description: String {
        switch self {
        case .classic: "White · OLED"
        case .warmth:  "Sunny · Sunset"
        case .ember:   "Tan · Ember"
        }
    }

    var lightTheme: EpistemosTheme {
        switch self {
        case .classic: .light
        case .warmth:  .sunny
        case .ember:   .tan
        }
    }

    var darkTheme: EpistemosTheme {
        switch self {
        case .classic: .oled
        case .warmth:  .sunset
        case .ember:   .ember
        }
    }

    func resolved(isDark: Bool) -> EpistemosTheme {
        isDark ? darkTheme : lightTheme
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
}
