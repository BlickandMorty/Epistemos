import AppKit
import CoreText
import SwiftUI

// MARK: - Theme Definition
// 9 themes — 4 light + 5 dark. Platinum Violet is the default pair.

/// Surface tag used by `EpistemosTheme.surfaceVariant(_:)` so we can
/// scope theme overrides to specific screens (landing / main chat) per
/// user 2026-05-10. Everything else stays on the canonical theme.
enum ThemeSurface: Sendable {
    case landing
    case mainChat
    case other
}

enum EpistemosTheme: String, CaseIterable, Codable, Sendable {
    case systemLight = "systemLight"
    case systemDark = "systemDark"
    case light = "light"
    case sunny = "sunny"
    case tan = "tan"
    case sunset = "sunset"
    case oled = "oled"
    /// Internal-only Classic dark variant that lifts the pure
    /// 0x000000 OLED background to a near-OLED dark grey for
    /// non-hero surfaces (Notes, Epdoc, Settings, Graph chrome)
    /// per user direction 2026-05-13: OLED is reserved for the
    /// landing greeting + main chat where the deep black reads
    /// best; everywhere else gets a softer dark grey so embedded
    /// content (note bodies, settings rows, graph panels) doesn't
    /// punch a hole through the window.
    ///
    /// Not exposed in user-facing pickers — `ThemePair.classic`
    /// still maps to `.oled` for the dark theme; `oledSoft` is
    /// reached only through `surfaceVariant(.other)`.
    case oledSoft = "oledSoft"
    case ember = "ember"
    case nocturne = "nocturne"
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

    // MARK: - Xcode Code Editor Colors (extracted from Default Dark/Light .xccolortheme plists)

    // @unchecked: NSColor is thread-safe for reads; instances are created once as static lets.
    struct XcodeCodeColors: @unchecked Sendable {
        let keyword: NSColor
        let string: NSColor
        let number: NSColor
        let comment: NSColor
        let function: NSColor
        let type: NSColor
        let op: NSColor
        let punctuation: NSColor
        let variable: NSColor
        let property: NSColor
        let constant: NSColor
        let tag: NSColor
        let attribute: NSColor
        let editorBackground: NSColor
        let editorForeground: NSColor
        let currentLineHighlight: NSColor
        let insertionPoint: NSColor
        let selection: NSColor
        let gutterBackground: NSColor
        let gutterForeground: NSColor
        let gutterForegroundActive: NSColor
        let gutterSeparator: NSColor

        /// Xcode Default (Dark) — direct .xccolortheme plist extraction
        static let defaultDark = XcodeCodeColors(
            keyword:              NSColor(srgbRed: 0.988, green: 0.373, blue: 0.639, alpha: 1), // #FC5FA3
            string:               NSColor(srgbRed: 0.122, green: 0.914, blue: 0.024, alpha: 1), // #1FE906
            number:               NSColor(srgbRed: 0.588, green: 0.527, blue: 0.961, alpha: 1), // #9686F5
            comment:              NSColor(srgbRed: 0.424, green: 0.475, blue: 0.525, alpha: 1), // #6C7986
            function:             NSColor(srgbRed: 0.800, green: 1.000, blue: 0.608, alpha: 1), // #CCFF9B
            type:                 NSColor(srgbRed: 0.510, green: 0.812, blue: 0.945, alpha: 1), // #82CFF1
            op:                   NSColor(srgbRed: 0.875, green: 0.875, blue: 0.878, alpha: 0.7), // foreground 70%
            punctuation:          NSColor(srgbRed: 0.875, green: 0.875, blue: 0.878, alpha: 0.5), // foreground 50%
            variable:             NSColor(srgbRed: 0.306, green: 0.694, blue: 0.800, alpha: 1), // #4EB1CC
            property:             NSColor(srgbRed: 0.514, green: 0.788, blue: 0.737, alpha: 1), // #83C9BC
            constant:             NSColor(srgbRed: 0.839, green: 0.769, blue: 0.333, alpha: 1), // #D6C455
            tag:                  NSColor(srgbRed: 0.992, green: 0.561, blue: 0.247, alpha: 1), // #FD8F3F
            attribute:            NSColor(srgbRed: 0.459, green: 0.706, blue: 0.573, alpha: 1), // #75B492
            editorBackground:     NSColor(srgbRed: 0.122, green: 0.122, blue: 0.141, alpha: 1), // #1F1F24
            editorForeground:     NSColor(srgbRed: 0.875, green: 0.875, blue: 0.878, alpha: 1), // #DFDFE0
            currentLineHighlight: NSColor(srgbRed: 0.137, green: 0.145, blue: 0.169, alpha: 1), // #23252B
            insertionPoint:       .white,
            selection:            NSColor(srgbRed: 0.318, green: 0.357, blue: 0.439, alpha: 0.6), // #515B70 @ 60%
            gutterBackground:     NSColor(srgbRed: 0.122, green: 0.122, blue: 0.141, alpha: 1), // match editor
            gutterForeground:     NSColor(srgbRed: 0.875, green: 0.875, blue: 0.878, alpha: 0.33),
            gutterForegroundActive: NSColor(srgbRed: 0.875, green: 0.875, blue: 0.878, alpha: 1),
            gutterSeparator:      NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
        )

        /// Xcode Default (Light) — derived counterpart
        static let defaultLight = XcodeCodeColors(
            keyword:              NSColor(srgbRed: 0.678, green: 0.239, blue: 0.643, alpha: 1), // #AD3DA4
            string:               NSColor(srgbRed: 0.769, green: 0.102, blue: 0.086, alpha: 1), // #C41A16
            number:               NSColor(srgbRed: 0.110, green: 0.000, blue: 0.812, alpha: 1), // #1C00CF
            comment:              NSColor(srgbRed: 0.361, green: 0.431, blue: 0.455, alpha: 1), // #5C6E74
            function:             NSColor(srgbRed: 0.180, green: 0.427, blue: 0.557, alpha: 1), // #2E6D8E
            type:                 NSColor(srgbRed: 0.243, green: 0.600, blue: 0.624, alpha: 1), // #3E999F
            op:                   NSColor(srgbRed: 0.110, green: 0.110, blue: 0.125, alpha: 0.7),
            punctuation:          NSColor(srgbRed: 0.110, green: 0.110, blue: 0.125, alpha: 0.5),
            variable:             NSColor(srgbRed: 0.153, green: 0.306, blue: 0.396, alpha: 1), // #274E65
            property:             NSColor(srgbRed: 0.243, green: 0.502, blue: 0.529, alpha: 1), // #3E8087
            constant:             NSColor(srgbRed: 0.165, green: 0.165, blue: 0.647, alpha: 1), // #2A2AA5
            tag:                  NSColor(srgbRed: 0.388, green: 0.220, blue: 0.125, alpha: 1), // #633820
            attribute:            NSColor(srgbRed: 0.718, green: 0.224, blue: 0.600, alpha: 1), // #B73999
            editorBackground:     .white,
            editorForeground:     NSColor(srgbRed: 0.110, green: 0.110, blue: 0.125, alpha: 1), // #1C1C20
            currentLineHighlight: NSColor(srgbRed: 0.925, green: 0.961, blue: 1.000, alpha: 1), // #ECF5FF
            insertionPoint:       .black,
            selection:            NSColor.selectedTextBackgroundColor,
            gutterBackground:     NSColor(srgbRed: 0.961, green: 0.961, blue: 0.961, alpha: 1), // #F5F5F5
            gutterForeground:     NSColor(srgbRed: 0.651, green: 0.651, blue: 0.651, alpha: 1), // #A6A6A6
            gutterForegroundActive: NSColor(srgbRed: 0.157, green: 0.157, blue: 0.157, alpha: 1), // #282828
            gutterSeparator:      NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08)
        )
    }

    @MainActor var xcodeColors: XcodeCodeColors {
        isDark ? .defaultDark : .defaultLight
    }

    nonisolated private static let resolvedCache: [EpistemosTheme: ResolvedTheme] = {
        Dictionary(
            EpistemosTheme.allCases.map { ($0, $0.buildResolved()) },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    nonisolated var resolved: ResolvedTheme {
        Self.resolvedCache[self] ?? buildResolved()
    }

    var displayName: String {
        switch self {
        case .systemLight: "System Light"
        case .systemDark: "System Dark"
        case .light:  "White"
        case .sunny:  "Sunny"
        case .tan:    "Tan"
        case .sunset: "Sunset"
        case .oled:   "OLED"
        case .oledSoft: "OLED Soft"
        case .ember:  "Ember"
        case .nocturne: "Nocturne"
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

    /// Surface-scoped theme variant. Per user direction 2026-05-10/05-13:
    /// some dark themes need to lift their pure-black hero palette into a
    /// softer dark grey on non-hero surfaces (notes, settings, graph
    /// chrome) so embedded content doesn't punch a hole through the
    /// window.
    ///
    /// - `.platinumVioletDark` → `.nocturne` on landing + main chat,
    ///   stays violet platinum elsewhere.
    /// - `.oled` → stays pure OLED on landing + main chat (deep black
    ///   hero), softens to `.oledSoft` on every other surface (near-OLED
    ///   dark grey 0x0F0F11 background).
    /// - Every other theme is identity.
    nonisolated func surfaceVariant(_ surface: ThemeSurface) -> EpistemosTheme {
        switch self {
        case .platinumVioletDark:
            switch surface {
            case .landing, .mainChat: return .nocturne
            case .other: return self
            }
        case .oled:
            switch surface {
            case .landing, .mainChat: return .oled
            case .other: return .oledSoft
            }
        default:
            return self
        }
    }

    nonisolated var isDark: Bool {
        resolved.isDark
    }

    /// Whether this theme uses Platinum styling (beveled buttons, racing stripes)
    var isPlatinum: Bool {
        resolved.isPlatinum
    }

    /// Reverse map an `EpistemosTheme` to the user-facing `ThemePair`
    /// it belongs to. Used by the per-theme display-font + heading-
    /// font resolution so the landing hero, H1-H3, and other display
    /// surfaces pick the right typeface per (themePair, isDark) cell.
    ///
    /// Themes that aren't part of a pair (system / nocturne /
    /// retired sunny+sunset) fall back to `.classic` so they still
    /// resolve a sane font.
    nonisolated var themePair: ThemePair {
        switch self {
        case .platinumViolet, .platinumVioletDark: return .platinumViolet
        case .light, .oled, .oledSoft: return .classic
        case .tan, .ember: return .ember
        case .systemLight, .systemDark, .sunny, .sunset, .nocturne:
            return .classic
        }
    }

    /// Display (hero) font name resolved by (themePair, isDark).
    /// Per user direction 2026-05-13 (eighth pass):
    ///   Classic       → RetroGaming across BOTH modes
    ///                   (Coral retired — user feedback: "i actually
    ///                   kinda rlly odnt like it")
    ///   Ember         → ColorBasic-Regular across both modes (case-
    ///                   driven box glyphs via `boxedLabelText`)
    ///   Platinum      → MatrixTypeDisplay-Regular across both modes
    nonisolated var displayFontName: String {
        switch themePair {
        case .classic:        return AppDisplayTypography.legacyDisplayFontName
        case .platinumViolet: return "MatrixTypeDisplay-Regular"
        case .ember:          return "ColorBasic-Regular"
        }
    }

    /// H1-H3 heading font name resolved by (themePair, isDark).
    /// Eighth pass: Classic = RetroGaming on BOTH light + dark.
    /// Ember stays on ChonkyPixels in both modes. Platinum stays
    /// on MatrixType.
    nonisolated var headingFontName: String {
        switch themePair {
        case .classic:        return AppDisplayTypography.legacyDisplayFontName
        case .platinumViolet: return "MatrixTypeDisplay-Regular"
        case .ember:          return "ChonkyPixels"
        }
    }

    /// CSS `font-family` value injected into the Tiptap notes editor as
    /// `--epdoc-display-font`. Matches the chat side: each theme's H1-H3
    /// in the WebView use the same intrinsic face as `headingFontName`
    /// (Classic → "Retro Gaming", Platinum → "MatrixTypeDisplay",
    /// Ember → "ChonkyPixels"). Replaces the pre-2026-05-19 Coral / Retro
    /// light-vs-dark scheme. The @font-face declarations live in
    /// `js-editor/src/editor.css`; the .ttf bytes are served by the
    /// EpdocEditorBridge URL-scheme handler from the macOS bundle.
    nonisolated var epdocDisplayFontFamily: String {
        let primary: String
        switch themePair {
        case .classic:        primary = "Retro Gaming"
        case .platinumViolet: primary = "MatrixTypeDisplay"
        case .ember:          primary = "ChonkyPixels"
        }
        return "\"\(primary)\", -apple-system, BlinkMacSystemFont, \"SF Pro Display\", system-ui, sans-serif"
    }

    /// Node-title font for the graph node inspector main heading.
    /// On Ember = ChonkyPixels (clean pixels, no case-driven boxes).
    /// Classic = RetroGaming on BOTH modes (eighth pass).
    nonisolated var nodeTitleFontName: String {
        switch themePair {
        case .classic:        return AppDisplayTypography.legacyDisplayFontName
        case .platinumViolet: return "MatrixTypeDisplay-Regular"
        case .ember:          return "ChonkyPixels"
        }
    }

    /// Caption font for footer/metadata text (e.g. note word count,
    /// "model-derived" badge, shortcut hints). Ember = MatrixTypeDisplay
    /// to avoid case-driven boxes on a small caption. Classic =
    /// RetroGaming on BOTH modes (eighth pass).
    nonisolated var captionFontName: String {
        switch themePair {
        case .classic:        return AppDisplayTypography.legacyDisplayFontName
        case .platinumViolet: return "MatrixTypeDisplay-Regular"
        case .ember:          return "MatrixTypeDisplay-Regular"
        }
    }

    /// Panel font name — used for graph node-inspector pop-ups
    /// (summary / relationships / profile section titles + node
    /// labels + preview heading text).
    ///
    /// On Ember the panel font intentionally stays on
    /// ColorBasic-Regular (not the H1-H3 RetroByte) so panel labels
    /// can switch to the BOXED glyph form by being lowercased before
    /// render. See `boxedLabelText(_:)`. On Classic + Platinum it
    /// mirrors `headingFontName` like before.
    nonisolated var panelFontName: String {
        switch themePair {
        case .ember: return "ColorBasic-Regular"
        default:     return headingFontName
        }
    }

    /// 2026-05-13 fifth pass — Ember-only case transforms.
    ///
    /// Ember's hero/panel face (ColorBasic-Regular) ships TWO glyph
    /// styles in one font: uppercase letters render as plain pixel
    /// outlines, lowercase letters render as white-on-black boxed
    /// glyphs. So the case of the input string drives the visual
    /// "regular vs box" choice without changing fonts.
    ///
    /// `boxedLabelText(_:)` lowercases the text on Ember (= boxes on
    /// render) and leaves it unchanged on every other theme. Used by:
    ///   - LiquidGreeting line 2 "Researcher" / "to start a conversation"
    ///   - Graph node-inspector section header title (Profile /
    ///     Summary / Relationships)
    ///   - Graph PinnedInspectorPanel node label
    ///   - Graph first-open title (already lowercased upstream; this
    ///     helper just protects the invariant for future call sites)
    nonisolated func boxedLabelText(_ text: String) -> String {
        themePair == .ember ? text.lowercased() : text
    }

    /// Counterpart of `boxedLabelText`: uppercases on Ember so the
    /// text renders with the plain (no-box) glyph form. Used by:
    ///   - LiquidGreeting line 1 "Greetings," / "Click anywhere"
    nonisolated func plainLabelText(_ text: String) -> String {
        themePair == .ember ? text.uppercased() : text
    }

    /// Whether the active theme prefers ALL-CAPS rendering for the
    /// stacked hero and H1-H3 headings. Retired 2026-05-13.
    nonisolated var prefersUppercaseDisplay: Bool {
        false
    }

    /// Whether chat-message H1 markdown headings should render in
    /// ALL CAPS (styling only — font + color preserved). Ember-pair
    /// only per user direction 2026-05-19; mirrors the user's
    /// preferred reading rhythm without altering H1's ChonkyPixels
    /// glyph treatment.
    nonisolated var uppercaseH1Display: Bool {
        themePair == .ember
    }

    /// Scalar applied to H1-H3 point sizes across all heading display
    /// contexts: chat-message markdown, the Tiptap notes-editor CSS
    /// variables, the auto-extracted chat heading lane, and the
    /// ProseEditor live-editor headings. Per user direction 2026-05-19,
    /// RetroGaming (Classic) and MatrixTypeDisplay (Platinum Violet)
    /// render visibly larger than Ember's ChonkyPixels at the same
    /// point size; an initial 15 % shrink wasn't aggressive enough, so
    /// the current value is 0.72 (28 % shrink). Ember stays on 1.0 —
    /// its sizes are the canonical target.
    nonisolated var headingSizeMultiplier: CGFloat {
        switch themePair {
        case .classic, .platinumViolet: return 0.72
        case .ember: return 1.0
        }
    }

    /// Notes-matching H2/H3 typography for chat-message markdown.
    /// Returns `nil` on themes that keep the canonical chat heading
    /// look. Ember-pair only per user direction 2026-05-19: chat
    /// H2/H3 reuse Ember's intrinsic heading face (ChonkyPixels — the
    /// same font H1 uses) but adopt the notes editor's H2/H3 point
    /// sizes (31 / 19) and weights (heavy / semibold) so the chat
    /// heading hierarchy mirrors the in-WebView editor's visual
    /// rhythm without introducing Coral Pixels.
    nonisolated func notesMatchingHeadingSpec(
        level: Int
    ) -> NotesMatchingHeadingSpec? {
        guard themePair == .ember, (2...3).contains(level) else {
            return nil
        }
        let size: CGFloat = level == 2 ? 31 : 19
        let weight: Font.Weight = level == 2 ? .heavy : .semibold
        return NotesMatchingHeadingSpec(
            fontName: headingFontName,
            size: size,
            weight: weight
        )
    }

    /// Whether H1-H3 headings should render with a glow on this
    /// theme. Dark mode already glows on every theme via the existing
    /// shadow pipeline; Platinum light mode gets a matching brown
    /// glow per user direction 2026-05-13 to mirror the dark-mode
    /// look ("classic retro Mac pixel words that are brown").
    nonisolated var headingGlows: Bool {
        if isDark { return true }
        switch themePair {
        case .platinumViolet: return true
        case .classic, .ember: return false
        }
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
        case .oledSoft:
            // RCA finalization 2026-05-13: near-OLED dark grey
            // palette for non-hero Classic-dark surfaces (Notes,
            // Settings, Graph chrome). Background lifts from
            // 0x000000 to 0x0F0F11 so embedded surfaces don't
            // punch a hole; muted + card layers nudge up a couple
            // of stops to keep separation visible. Foreground +
            // accents inherit from OLED so the typographic feel
            // stays continuous.
            return ResolvedTheme(
                isDark: true,
                isPlatinum: false,
                usesNativeWindowBlur: false,
                background: .hex(0x0F0F11),
                foregroundHex: 0xDADADE,
                accent: .hex(0xDADADE),
                headingAccentHex: 0xF4F4F4,
                markdownHeadingAccentHex: 0xF4F4F4,
                preferredMarkdownLinkHex: nil,
                uiAccent: .hex(0xDADADE),
                muted: .hex(0x1A1A1D),
                mutedForegroundHex: 0x9A9AA0,
                assistantBubbleForegroundHex: 0xDADADE,
                assistantBubbleBackgroundHex: nil,
                userBubbleBackgroundHex: nil,
                border: Token.rgba(58.0 / 255.0, 58.0 / 255.0, 62.0 / 255.0, 0.55),
                codeType: .hex(0x56B6B6),
                glassBg: Token.rgba(24.0 / 255.0, 24.0 / 255.0, 27.0 / 255.0, 0.82),
                glassBorder: Token.rgba(58.0 / 255.0, 58.0 / 255.0, 62.0 / 255.0, 0.32),
                glassHover: Token.rgba(36.0 / 255.0, 36.0 / 255.0, 40.0 / 255.0, 0.7),
                floatingSurfaceTint: .hex(0x2E2E33),
                navPillBg: Token.rgba(18.0 / 255.0, 18.0 / 255.0, 22.0 / 255.0, 0.85),
                navBubbleActiveBg: Token.rgba(32.0 / 255.0, 32.0 / 255.0, 36.0 / 255.0, 0.7),
                navBubbleActiveText: .hex(0xDADADE, opacity: 0.92),
                navBubbleInactiveText: Token.rgba(180.0 / 255.0, 180.0 / 255.0, 184.0 / 255.0, 0.92),
                card: Token.rgba(28.0 / 255.0, 28.0 / 255.0, 32.0 / 255.0, 0.92),
                chatSurface: .hex(0x0F0F11),
                userBubbleBg: .hex(0x33333A),
                userBubbleText: .hex(0xDADADE, opacity: 0.88),
                nsBackground: .hex(0x0F0F11)
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
    /// Uses exact Xcode Default Dark/Light palette extracted from .xccolortheme plists.
    @MainActor
    func nsColorForTokenType(_ tokenType: UInt8) -> NSColor {
        let xc = xcodeColors
        switch tokenType {
        case 0:   return xc.keyword      // keyword — hot pink (dark) / magenta (light)
        case 1:   return xc.string       // string — bright green (dark) / deep red (light)
        case 2:   return xc.number       // number — purple (dark) / blue (light)
        case 3:   return xc.comment      // comment — slate gray
        case 4:   return xc.function     // function — lime (dark) / steel blue (light)
        case 5:   return xc.type         // type — sky blue (dark) / teal (light)
        case 6:   return xc.op           // operator — foreground at 70%
        case 7:   return xc.punctuation  // punctuation — foreground at 50%
        case 8:   return xc.variable     // variable — steel blue-cyan
        case 9:   return xc.property     // property — seafoam
        case 10:  return xc.constant     // constant — warm gold
        case 11:  return xc.tag          // tag/macro — orange
        case 12:  return xc.attribute    // attribute — green (dark) / pink-violet (light)
        default:  return xc.editorForeground // plain text
        }
    }

    @MainActor
    func nsColorForSyntaxKind(_ kindId: UInt16) -> NSColor {
        let xc = xcodeColors
        switch kindId {
        case 1:  return xc.comment     // "comment"
        case 2:  return xc.string      // "string"
        case 3:  return xc.number      // "number"
        case 4:  return xc.constant    // "constant"
        case 5:  return xc.keyword     // "escape"
        case 6:  return xc.type        // "type"
        case 7:  return xc.variable    // "variable"
        case 8:  return xc.property    // "property"
        case 9:  return xc.function    // "function.def"
        case 10: return xc.function    // "function.call"
        case 11: return xc.tag        // "macro"
        case 12: return xc.attribute  // "attribute"
        default: return xc.editorForeground
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
        // Per user 2026-05-12: dark mode user bubble flips to white so
        // the on-right message stands out clearly against the now-theme-
        // native chat background (which is no longer near-OLED). Light
        // mode keeps its per-theme bubble color since the user only
        // flagged the dark-mode bubble.
        isDark ? Color.white : resolved.userBubbleBg.color
    }

    var userBubbleText: Color {
        // Pair the dark-mode white bubble with black text for readability.
        // Light mode keeps its per-theme text color.
        isDark ? Color.black : resolved.userBubbleText.color
    }

    var sidebarBackground: Color { glassBg }

    // MARK: - NSColor for Window Chrome

    var nsBackground: NSColor {
        resolved.nsBackground.nsColor
    }
}

// MARK: - Theme Pair

enum ThemePair: String, CaseIterable, Codable, Sendable {
    case platinumViolet = "platinumViolet"
    case classic = "classic"
    case ember   = "ember"

    var displayName: String {
        switch self {
        case .platinumViolet: "Platinum Violet"
        case .classic: "Classic"
        case .ember:   "Ember"
        }
    }

    var description: String {
        switch self {
        case .platinumViolet: "Platinum Violet · Platinum Violet Dark"
        case .classic: "White · OLED"
        case .ember:   "Tan · Ember"
        }
    }

    var lightTheme: EpistemosTheme {
        switch self {
        case .platinumViolet: .platinumViolet
        case .classic: .light
        case .ember:   .tan
        }
    }

    var darkTheme: EpistemosTheme {
        switch self {
        case .platinumViolet: .platinumVioletDark
        case .classic: .oled
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

/// Concrete font / size / weight bundle for chat-message H2/H3 that
/// want to mirror the Tiptap notes editor (Ember pair only as of
/// 2026-05-19). Returned by `EpistemosTheme.notesMatchingHeadingSpec`.
struct NotesMatchingHeadingSpec: Sendable {
    let fontName: String
    let size: CGFloat
    let weight: Font.Weight
}

enum AppHeadingRole: Sendable {
    case pageTitle
    case h1
    case h2
    case h3
    case section
    case chatTitle

    nonisolated var fontName: String {
        switch self {
        case .pageTitle, .h1, .h2, .h3, .chatTitle:
            AppDisplayTypography.displayFontName
        case .section:
            AppDisplayTypography.fontName
        }
    }

    nonisolated var fontSize: CGFloat {
        switch self {
        case .pageTitle: 34
        case .h1: 32
        case .h2: 26
        case .h3: 18
        case .section: 12
        case .chatTitle: 34
        }
    }

    nonisolated var topPadding: CGFloat {
        switch self {
        case .pageTitle, .section, .chatTitle: 0
        case .h1: 16
        case .h2: 12
        case .h3: 8
        }
    }

    nonisolated var tracking: CGFloat {
        switch self {
        case .section: 0.8
        default: 0
        }
    }

    nonisolated var animatesOnFirstAppearance: Bool {
        switch self {
        case .pageTitle: true
        default: false
        }
    }

    nonisolated var font: Font {
        switch self {
        case .pageTitle, .h1, .h2, .h3, .chatTitle:
            AppDisplayTypography.font(size: fontSize)
        case .section:
            AppDisplayTypography.font(size: fontSize, allowDisplayFont: false)
        }
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

enum AppDisplayTypography: Sendable {
    nonisolated static let legacyDisplayModeDefaultsKey = "epistemos.display.mode"
    nonisolated static let readableFontsDefaultsKey = "epistemos.typography.readableFontsEnabled"
    nonisolated static let coralDisplayFontName = "CoralPixels-Regular"
    nonisolated static let legacyDisplayFontName = "RetroGaming"
    nonisolated static let monoFontName = "JetBrainsMono-Regular"
    nonisolated static let readableFontRegularName = "AvenirNext-Regular"
    nonisolated static let readableFontMediumName = "AvenirNext-Medium"
    nonisolated static let readableFontSemiboldName = "AvenirNext-DemiBold"
    nonisolated static let readableFontBoldName = "AvenirNext-Bold"
    nonisolated static let coralDisplayFontScale: CGFloat = 1.1
    nonisolated static let legacyDisplayFontScale: CGFloat = 1.0

    nonisolated static var displayFontName: String {
        displayFontName(isDark: SystemAppearanceState.isDark())
    }

    nonisolated static var displayFontScale: CGFloat {
        displayFontScale(isDark: SystemAppearanceState.isDark())
    }

    /// Theme-pair-aware display font resolver. Per user direction
    /// 2026-05-13 (third pass): the active theme pair determines the
    /// hero font globally so any theme-agnostic call site
    /// (`AppDisplayTypography.font(size:)`,
    /// `AppDisplayTypography.displayFontName`) returns the right
    /// face for whichever theme the user is on.
    ///
    /// Reads `epistemos.theme.pair` from UserDefaults so the resolver
    /// doesn't require a theme parameter at every call site. Falls
    /// back to Platinum Violet when the key is missing or unknown so
    /// first-launch users see the v1 default app theme immediately.
    /// The `isDark` parameter is ignored — each theme's identity face
    /// holds across both modes per the user's eighth-pass direction.
    /// Theme-pair-aware display font resolver. Reads
    /// `epistemos.theme.pair` from UserDefaults so theme-agnostic
    /// callers (RootView hero, LandingView, NoteDetailWorkspaceView,
    /// ChatInputBar pill, AppHeadingRole.font, etc.) pick the active
    /// theme's identity face without each call site needing a theme
    /// parameter.
    ///
    /// Eighth pass 2026-05-13: Classic = RetroGaming on BOTH light + dark
    /// (CoralPixels retired per user feedback: "i actually kinda rlly
    /// odnt like it"). Ember + Platinum keep their identity face across
    /// both modes.
    nonisolated static func displayFontName(isDark: Bool) -> String {
        let raw = UserDefaults.standard.string(forKey: "epistemos.theme.pair") ?? ""
        switch raw {
        case "platinumViolet": return "MatrixTypeDisplay-Regular"
        case "ember":          return "ColorBasic-Regular"
        case "classic":        return legacyDisplayFontName
        default:               return "MatrixTypeDisplay-Regular"
        }
    }

    nonisolated static func graphLabelAtlasResourceName(isDark: Bool) -> String {
        // Per user 2026-05-12: graph node labels use the JetBrainsMono
        // monospace SDF atlas in BOTH light and dark mode (the "before"
        // identity). The dark-only `sdf_labels_retro` (RetroGaming) and
        // light-only `sdf_labels_coral` (CoralPixels) atlases remain
        // bundled for any future per-theme override but the default
        // graph identity is the monospaced v1 atlas.
        _ = isDark
        return "sdf_labels"
    }

    nonisolated static func displayFontScale(isDark: Bool) -> CGFloat {
        // Eighth pass 2026-05-13: Classic is RetroGaming (legacy)
        // across BOTH modes now, so the scale is unified too.
        _ = isDark
        return legacyDisplayFontScale
    }

    nonisolated static func readableFontsEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: readableFontsDefaultsKey) != nil {
            return defaults.bool(forKey: readableFontsDefaultsKey)
        }
        return defaults.string(forKey: legacyDisplayModeDefaultsKey) == "regular"
    }

    nonisolated static func setReadableFontsEnabled(
        _ enabled: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: readableFontsDefaultsKey)
        defaults.removeObject(forKey: legacyDisplayModeDefaultsKey)
    }

    nonisolated static func regularUIFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let fontName: String = if weight >= .bold {
            readableFontBoldName
        } else if weight >= .semibold {
            readableFontSemiboldName
        } else if weight >= .medium {
            readableFontMediumName
        } else {
            readableFontRegularName
        }
        if let font = NSFont(name: fontName, size: size) {
            return font
        }
        let uiType: CTFontUIFontType = weight >= .semibold ? .emphasizedSystem : .system
        guard let ctFont = CTFontCreateUIFontForLanguage(uiType, size, nil) else {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        return ctFont as NSFont
    }

    nonisolated static func isRegularUIFont(_ font: NSFont) -> Bool {
        font.fontName.hasPrefix("AvenirNext")
            || font.fontName.hasPrefix(".SFNS")
            || font.fontName.hasPrefix(".AppleSystemUIFont")
    }

    nonisolated static var fontName: String {
        readableFontsEnabled()
            ? regularUIFont(size: NSFont.systemFontSize).fontName
            : displayFontName
    }

    nonisolated static func font(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        isDark: Bool? = nil,
        allowDisplayFont: Bool = true
    ) -> Font {
        let resolvedIsDark = isDark ?? SystemAppearanceState.isDark()
        if allowDisplayFont && !readableFontsEnabled() {
            return Font.custom(
                displayFontName(isDark: resolvedIsDark),
                size: displayFontSize(for: size, isDark: resolvedIsDark)
            )
        } else if design == .default {
            return Font(regularUIFont(size: size, weight: nsWeight(for: weight)))
        } else {
            return Font.system(size: size, weight: weight, design: design)
        }
    }

    /// Theme-aware heading font for H1-H3 (RCA finalization 2026-05-13).
    /// Routes through `EpistemosTheme.headingFontName` so each
    /// ThemePair picks its own light-mode H1-H3 typeface
    /// (Platinum → MatrixTypeDisplay, Classic → CoralPixels, Ember →
    /// DotempDemo-8bit). Dark mode falls back to the legacy
    /// RetroGaming face on every theme.
    nonisolated static func headingFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        theme: EpistemosTheme,
        allowDisplayFont: Bool = true
    ) -> Font {
        let resolvedIsDark = theme.isDark
        if allowDisplayFont && !readableFontsEnabled() {
            return Font.custom(
                theme.headingFontName,
                size: displayFontSize(for: size, isDark: resolvedIsDark)
            )
        } else {
            return Font(regularUIFont(size: size, weight: nsWeight(for: weight)))
        }
    }

    /// Theme-aware panel font for graph node-inspector pop-ups and
    /// similar secondary panel chrome (RCA finalization 2026-05-13).
    /// Routes through `EpistemosTheme.panelFontName` — Classic uses
    /// ChonkyPixels, others reuse their heading face.
    nonisolated static func panelFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        theme: EpistemosTheme,
        allowDisplayFont: Bool = true
    ) -> Font {
        let resolvedIsDark = theme.isDark
        if allowDisplayFont && !readableFontsEnabled() {
            return Font.custom(
                theme.panelFontName,
                size: displayFontSize(for: size, isDark: resolvedIsDark)
            )
        } else {
            return Font(regularUIFont(size: size, weight: nsWeight(for: weight)))
        }
    }

    nonisolated static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(monoFontName, size: size).weight(weight)
    }

    nonisolated static func monoUIFont(
        size: CGFloat,
        weight: NSFont.Weight = .regular
    ) -> NSFont {
        NSFont(name: monoFontName, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    nonisolated static func nsFont(
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        isDark: Bool? = nil,
        allowDisplayFont: Bool = true
    ) -> NSFont {
        let resolvedIsDark = isDark ?? SystemAppearanceState.isDark()
        if allowDisplayFont && !readableFontsEnabled() {
            return NSFont(
                name: displayFontName(isDark: resolvedIsDark),
                size: displayFontSize(for: size, isDark: resolvedIsDark)
            )
                ?? NSFont.systemFont(ofSize: size, weight: weight)
        } else {
            return regularUIFont(size: size, weight: weight)
        }
    }

    /// Theme-aware NSFont resolver for H1-H3 in the live note editor
    /// (TextKit `NSTextView`). 2026-05-13 follow-up: the existing
    /// `nsFont(size:weight:isDark:)` returns the hero face (which on
    /// Ember is ColorBasic-Regular = case-driven box glyphs). Notes
    /// headings should instead use `theme.headingFontName` (Ember →
    /// ChonkyPixels, Classic → CoralPixels/RetroGaming, Platinum →
    /// MatrixTypeDisplay-Regular) — matching the SwiftUI
    /// `MarkdownTextView` + `TaggedMarkdownTextView` chat heading
    /// paths that already go through
    /// `AppDisplayTypography.headingFont(size:weight:theme:)`.
    nonisolated static func nsHeadingFont(
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        theme: EpistemosTheme,
        allowDisplayFont: Bool = true
    ) -> NSFont {
        let resolvedIsDark = theme.isDark
        if allowDisplayFont && !readableFontsEnabled() {
            return NSFont(
                name: theme.headingFontName,
                size: displayFontSize(for: size, isDark: resolvedIsDark)
            )
                ?? NSFont.systemFont(ofSize: size, weight: weight)
        } else {
            return regularUIFont(size: size, weight: weight)
        }
    }

    nonisolated static func isDisplayFont(_ font: NSFont) -> Bool {
        isPrimaryDisplayFont(font) || isLegacyDisplayFont(font)
    }

    nonisolated static func isPrimaryDisplayFont(_ font: NSFont) -> Bool {
        font.fontName.contains(coralDisplayFontName)
    }

    nonisolated static func isLegacyDisplayFont(_ font: NSFont) -> Bool {
        font.fontName.contains(legacyDisplayFontName)
    }

    nonisolated static func displayFontSize(for size: CGFloat) -> CGFloat {
        displayFontSize(for: size, isDark: SystemAppearanceState.isDark())
    }

    nonisolated static func displayFontSize(for size: CGFloat, isDark: Bool) -> CGFloat {
        size * displayFontScale(isDark: isDark)
    }

    nonisolated static func preservingFamilyFont(
        from font: NSFont,
        size: CGFloat,
        bold: Bool = false,
        italic: Bool = false
    ) -> NSFont {
        let manager = NSFontManager.shared
        let weight: NSFont.Weight = bold ? .bold : .regular
        var resolved: NSFont
        if isPrimaryDisplayFont(font) {
            resolved = nsFont(size: size, weight: weight, isDark: false)
        } else if isLegacyDisplayFont(font) {
            resolved = nsFont(size: size, weight: weight, isDark: true)
        } else if isRegularUIFont(font) {
            resolved = regularUIFont(size: size, weight: weight)
        } else {
            resolved = font.withSize(size)
        }

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

enum ClaudeAppTypography: Sendable {
    static func assistantFont(size: CGFloat) -> Font {
        Font(assistantUIFont(size: size))
    }

    static func userFont(size: CGFloat) -> Font {
        Font(userUIFont(size: size))
    }

    static func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font(monoUIFont(size: size, weight: nsWeight(for: weight)))
    }

    nonisolated static func monoUIFont(
        size: CGFloat,
        weight: NSFont.Weight = .regular
    ) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    nonisolated static func assistantUIFont(size: CGFloat) -> NSFont {
        monoUIFont(size: size, weight: .regular)
    }

    nonisolated static func noteAssistantUIFont(size: CGFloat) -> NSFont {
        AppDisplayTypography.nsFont(size: size, weight: .regular)
    }

    nonisolated static func userUIFont(size: CGFloat) -> NSFont {
        monoUIFont(size: size, weight: .medium)
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
        linkForegroundColor: Color? = nil,
        strongFont: Font? = nil
    ) -> Text {
        if let attributed = attributedString(
            text,
            strongFontSize: strongFontSize,
            strongForegroundColor: strongForegroundColor,
            linkForegroundColor: linkForegroundColor,
            strongFont: strongFont
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
        linkForegroundColor: Color? = nil,
        strongFont: Font? = nil
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
            foregroundColor: strongForegroundColor,
            strongFont: strongFont
        )
        applyLinkForegroundColor(to: &attributed, foregroundColor: linkForegroundColor)
        return attributed
    }

    static func applyDisplayStrongEmphasis(
        to attributed: inout AttributedString,
        fontSize: CGFloat,
        foregroundColor: Color? = nil,
        strongFont: Font? = nil
    ) {
        _ = fontSize
        let strongRuns = attributed.runs.compactMap { run -> (Range<AttributedString.Index>, InlinePresentationIntent)? in
            guard let intent = run.inlinePresentationIntent, intent.contains(.stronglyEmphasized) else {
                return nil
            }
            return (run.range, intent)
        }

        for (range, _) in strongRuns {
            if let strongFont {
                attributed[range].font = strongFont
            }
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
