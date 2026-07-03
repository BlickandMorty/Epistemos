import AppKit
import SwiftUI

// UAS: landing/command-theme-treatment
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
enum LandingCommandThemeTreatment: Equatable {
    case platinumBlock
    case classicNative
    case emberHybrid

    static func resolve(for theme: EpistemosTheme) -> Self {
        if AppCustomTheme.isActive {
            return .classicNative
        }
        switch theme.themePair {
        case .platinumViolet:
            return .platinumBlock
        case .classic:
            return .classicNative
        case .ember:
            return .emberHybrid
        case .custom:
            return .classicNative
        }
    }

    func chromeTheme(for theme: EpistemosTheme) -> EpistemosTheme {
        theme
    }

    var hoverAnimation: Animation {
        switch self {
        case .platinumBlock:
            return .interpolatingSpring(stiffness: 260, damping: 23)
        case .classicNative:
            return .spring(response: 0.26, dampingFraction: 0.86)
        case .emberHybrid:
            return .spring(response: 0.24, dampingFraction: 0.80)
        }
    }
}

// UAS: landing/command-typography
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
enum LandingCommandTypography {
    static func heroFontName(for theme: EpistemosTheme) -> String {
        if AppCustomTheme.isActive {
            return AppDisplayTypography.storedHeadingFontOverride(level: 1)
                ?? AppDisplayTypography.matrixDisplayFontName
        }
        switch theme.themePair {
        // Owner request 2026-07-03 (revised): Ember, Classic AND Platinum all share
        // Ember's landing-greeting hero font + the uppercase/lowercase case combo.
        // (Platinum previously kept its own matrix display face; owner asked for it
        // to match the others in both light and dark.)
        case .classic, .ember, .platinumViolet:
            return theme.displayFontName
        case .custom:
            return AppDisplayTypography.storedHeadingFontOverride(level: 1)
                ?? AppDisplayTypography.matrixDisplayFontName
        }
    }

    static func h2h3FontName(for theme: EpistemosTheme) -> String {
        theme.headingFontName(level: 2)
    }

    static func panelTitleFont(size: CGFloat, theme: EpistemosTheme) -> Font {
        let fontName = size >= 24 ? theme.displayFontName : h2h3FontName(for: theme)
        return Font.custom(fontName, size: size)
    }

    static func commandFont(size: CGFloat = 12, treatment _: LandingCommandThemeTreatment, theme _: EpistemosTheme) -> Font {
        return .system(size: size, weight: .semibold, design: .rounded)
    }
}

enum PixelGlyphKind {
    case capture
    case clock
    case workspace
    case save
    case search
    case notes
    case chat
    case document
    case code
    case html
    case graph
    case agent

    var systemImageName: String {
        switch self {
        case .capture: "square.and.pencil"
        case .clock: "clock.arrow.circlepath"
        case .workspace: "rectangle.3.group"
        case .save: "tray.and.arrow.down"
        case .search: "magnifyingglass"
        case .notes: "note.text"
        case .chat: "message"
        case .document: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .html: "curlybraces.square"
        case .graph: "network"
        case .agent: "person.crop.circle.badge.checkmark"
        }
    }
}

struct PixelPanelBackground: View {
    let theme: EpistemosTheme

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.regularMaterial)
            Self.panelSurface(for: theme)
                .opacity(theme.isDark ? 0.88 : 0.92)
            LinearGradient(
                colors: [
                    Color.white.opacity(theme.isDark ? 0.06 : 0.34),
                    Color.white.opacity(theme.isDark ? 0.02 : 0.10),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(theme.resolved.accent.color)
                .frame(height: 3)
        }
    }

    static func panelSurface(for theme: EpistemosTheme) -> Color {
        tunedSurface(for: theme, role: .panel)
    }

    static func actionSurface(for theme: EpistemosTheme) -> Color {
        tunedSurface(for: theme, role: .action)
    }

    static func actionHoverSurface(for theme: EpistemosTheme) -> Color {
        tunedSurface(for: theme, role: .hover)
    }

    private enum SurfaceRole {
        case panel
        case action
        case hover

        var darkenFraction: CGFloat {
            switch self {
            case .panel: 0.10
            case .action: 0.14
            case .hover: 0.08
            }
        }

        var customLightenFraction: CGFloat {
            switch self {
            case .panel: 0.18
            case .action: 0.12
            case .hover: 0.24
            }
        }
    }

    private static func tunedSurface(for theme: EpistemosTheme, role: SurfaceRole) -> Color {
        if theme.isDark {
            return blendedSurface(for: theme, fraction: role.darkenFraction, target: .black)
        }

        switch theme.themePair {
        case .platinumViolet:
            switch role {
            case .panel: return Color.white.opacity(0.98)
            case .action: return Color(hex: 0xF6F7FB).opacity(0.97)
            case .hover: return Color.white
            }
        case .classic:
            switch role {
            case .panel: return Color(hex: 0xECEEF2).opacity(0.98)
            case .action: return Color(hex: 0xE4E7EC).opacity(0.98)
            case .hover: return Color(hex: 0xF3F5F8).opacity(0.98)
            }
        case .ember:
            switch role {
            case .panel: return Color(hex: 0xD6B07A).opacity(0.98)
            case .action: return Color(hex: 0xC99A62).opacity(0.98)
            case .hover: return Color(hex: 0xE1BE88).opacity(0.98)
            }
        case .custom:
            return blendedSurface(for: theme, fraction: role.customLightenFraction, target: .white)
        }
    }

    private static func blendedSurface(for theme: EpistemosTheme, fraction: CGFloat, target: NSColor) -> Color {
        let base = theme.resolved.background.nsColor.usingColorSpace(.sRGB) ?? theme.resolved.background.nsColor
        return Color(nsColor: base.blended(withFraction: fraction, of: target) ?? base)
    }
}

private struct PixelPanelModifier: ViewModifier {
    let theme: EpistemosTheme
    var surface: Color?

    func body(content: Content) -> some View {
        switch LandingCommandThemeTreatment.resolve(for: theme) {
        case .platinumBlock:
            platinumPixelPanel(content)
        case .classicNative:
            classicNativePanel(content)
        case .emberHybrid:
            emberHybridPanel(content)
        }
    }

    private func platinumPixelPanel(_ content: Content) -> some View {
        let panelSurface = surface ?? PixelPanelBackground.panelSurface(for: theme)
        return content
            .background {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.regularMaterial)
                    panelSurface
                        .opacity(theme.isDark ? 0.88 : 0.92)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.06 : 0.30),
                            Color.white.opacity(theme.isDark ? 0.02 : 0.08),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Rectangle()
                        .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.84 : 0.74))
                        .frame(height: 3)
                }
            }
            .clipShape(Rectangle())
            .overlay {
                Rectangle()
                    .stroke(pixelPanelStrokeColor(for: theme), lineWidth: pixelPanelStrokeWidth(for: theme))
            }
            .compositingGroup()
            .shadow(
                color: theme.resolved.accent.color.opacity(theme.isDark ? 0.10 : 0.08),
                radius: theme.isDark ? 12 : 16,
                x: 0,
                y: theme.isDark ? 8 : 10
            )
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.28 : 0.18),
                radius: 0,
                x: theme.isDark ? 4 : 6,
                y: theme.isDark ? 4 : 6
            )
    }

    private func classicNativePanel(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return content
            .background {
                ZStack {
                    shape.fill(surface ?? classicNativePanelSurface)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.08 : 0.48),
                            Color.white.opacity(0.02),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
            }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(
                        Color.white.opacity(theme.isDark ? 0.10 : 0.72),
                        lineWidth: 0.8
                    )
                    .blendMode(.screen)
                shape
                    .strokeBorder(
                        Color.black.opacity(theme.isDark ? 0.24 : 0.08),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.28 : 0.12),
                radius: theme.isDark ? 28 : 34,
                x: 0,
                y: theme.isDark ? 18 : 22
            )
    }

    private func emberHybridPanel(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return content
            .background {
                ZStack(alignment: .top) {
                    shape.fill(surface ?? emberHybridPanelSurface)
                    LinearGradient(
                        colors: [
                            theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11),
                            Color(hex: 0xC99A62).opacity(theme.isDark ? 0.12 : 0.08),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.42 : 0.30))
                        .frame(width: 108, height: 3)
                        .padding(.top, 10)
                }
            }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(theme.resolved.accent.color.opacity(theme.isDark ? 0.22 : 0.16), lineWidth: 0.8)
                shape
                    .strokeBorder(Color.white.opacity(theme.isDark ? 0.04 : 0.28), lineWidth: 0.5)
                    .blendMode(.screen)
            }
            .shadow(
                color: Color(hex: 0x5E2E16).opacity(theme.isDark ? 0.28 : 0.16),
                radius: 24,
                x: 0,
                y: 16
            )
    }

    private var classicNativePanelSurface: Color {
        if theme.isDark {
            return Color(hex: 0x202024).opacity(0.98)
        }
        return Color.white.opacity(0.98)
    }

    private var emberHybridPanelSurface: Color {
        if theme.isDark {
            return Color(hex: 0x241915).opacity(0.98)
        }
        return Color(hex: 0xF7EFE3).opacity(0.98)
    }

    private func pixelPanelStrokeWidth(for theme: EpistemosTheme) -> CGFloat {
        theme.isDark ? 1 : 1.5
    }

    private func pixelPanelStrokeColor(for theme: EpistemosTheme) -> Color {
        theme.textPrimary.opacity(theme.isDark ? 0.24 : 0.34)
    }
}

extension View {
    func pixelPanel(theme: EpistemosTheme, surface: Color? = nil) -> some View {
        modifier(PixelPanelModifier(theme: theme, surface: surface))
    }

    func pixelStepAppear(frame: Int) -> some View {
        modifier(PixelStepAppearModifier(frame: frame))
    }
}

enum PixelStepMotion {
    static let frameDelay: Duration = .milliseconds(42)
    static let hoverFrameDelay: Duration = .milliseconds(34)

    @MainActor
    static func play(reduceMotion: Bool, setFrame: @escaping (Int) -> Void) async {
        if reduceMotion {
            setFrame(3)
            return
        }

        for frame in [1, 2, 3] {
            setFrame(frame)
            try? await Task.sleep(for: frameDelay)
        }
    }

    static func scale(for frame: Int) -> CGFloat {
        switch frame {
        case 0: 0.94
        case 1: 1.035
        case 2: 0.985
        default: 1.0
        }
    }

    static func yOffset(for frame: Int) -> CGFloat {
        switch frame {
        case 0: 8
        case 1: -2
        case 2: 1
        default: 0
        }
    }

    @MainActor
    static func playLandingSearchReveal(reduceMotion: Bool, setFrame: @escaping (Int) -> Void) async {
        if reduceMotion {
            setFrame(5)
            return
        }
        for frame in [1, 2, 3, 4, 5] {
            setFrame(frame)
            try? await Task.sleep(for: hoverFrameDelay)
        }
    }

    @MainActor
    static func playLandingGreetingReturnReveal(reduceMotion: Bool, setFrame: @escaping (Int) -> Void) async {
        if reduceMotion {
            setFrame(4)
            return
        }
        for frame in [1, 2, 3, 4] {
            setFrame(frame)
            try? await Task.sleep(for: hoverFrameDelay)
        }
    }

    static func landingSearchRevealScale(for frame: Int) -> CGFloat {
        switch frame {
        case ...0: 0.94
        case 1: 1.035
        case 2: 0.982
        case 3: 1.012
        default: 1
        }
    }

    static func landingSearchRevealYOffset(for frame: Int) -> CGFloat {
        switch frame {
        case ...0: 10
        case 1: -4
        case 2: 2
        default: 0
        }
    }

    static func landingSearchRevealBlur(for frame: Int) -> CGFloat {
        switch frame {
        case ...0: 8
        case 1: 3
        case 2: 1
        default: 0
        }
    }

    static func landingGreetingReturnScale(for frame: Int) -> CGFloat {
        switch frame {
        case ...0: 0.965
        case 1: 1.025
        case 2: 0.992
        default: 1
        }
    }

    static func landingGreetingReturnBlur(for frame: Int) -> CGFloat {
        switch frame {
        case ...0: 5
        case 1: 2
        default: 0
        }
    }
}

struct PixelPanelTitle: View {
    let text: String
    let theme: EpistemosTheme
    var size: CGFloat = 15

    var body: some View {
        TypewriterASCIIRippleText(
            text: text,
            font: LandingCommandTypography.panelTitleFont(size: size, theme: theme),
            color: theme.fontAccent,
            shadowColor: theme.isDark ? theme.fontAccent.opacity(0.10) : .clear,
            shadowRadius: theme.isDark ? 5 : 0,
            configuration: .init(duration: 0.42, spread: 1.05, waveThreshold: 2.0, characterMultiplier: 1),
            typingSpeed: 0.018,
            initialDelay: 0.035
        )
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
}

struct PixelCommandTypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    let accent: Color

    var body: some View {
        TypewriterASCIIRippleText(
            text: text,
            font: font,
            color: color,
            shadowColor: accent.opacity(0.12),
            shadowRadius: 4,
            configuration: .init(duration: 0.34, spread: 0.72, waveThreshold: 1.55, characterMultiplier: 1),
            typingSpeed: 0.014,
            initialDelay: 0.02
        )
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct PixelStepAppearModifier: ViewModifier {
    let frame: Int

    func body(content: Content) -> some View {
        content
            .scaleEffect(PixelStepMotion.scale(for: frame))
            .offset(y: PixelStepMotion.yOffset(for: frame))
            .opacity(frame == 0 ? 0 : 1)
    }
}

private struct LandingSearchStepRevealModifier: ViewModifier {
    let frame: Int
    let theme: EpistemosTheme

    private var revealOpacity: Double {
        frame <= 0 ? 0 : 1
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(PixelStepMotion.landingSearchRevealScale(for: frame))
            .offset(y: PixelStepMotion.landingSearchRevealYOffset(for: frame))
            .opacity(revealOpacity)
            .shadow(
                color: theme.isDark
                    ? Color.clear
                    : theme.fontAccent.opacity(0.08),
                radius: theme.isDark || frame <= 0 ? 0 : 7,
                x: 0,
                y: 0
            )
    }
}

extension View {
    func landingSearchStepReveal(frame: Int, theme: EpistemosTheme) -> some View {
        modifier(LandingSearchStepRevealModifier(frame: frame, theme: theme))
    }
}

private struct LandingGreetingReturnRevealModifier: ViewModifier {
    let frame: Int
    let theme: EpistemosTheme

    func body(content: Content) -> some View {
        content
            .scaleEffect(PixelStepMotion.landingGreetingReturnScale(for: frame))
            .blur(radius: PixelStepMotion.landingGreetingReturnBlur(for: frame))
            .opacity(frame <= 0 ? 0.72 : 1)
            .shadow(
                color: theme.fontAccent.opacity(frame <= 0 ? 0 : (theme.isDark ? 0.18 : 0.12)),
                radius: frame <= 0 ? 0 : 10,
                x: 0,
                y: 0
            )
    }
}

extension View {
    func landingGreetingReturnReveal(frame: Int, theme: EpistemosTheme) -> some View {
        modifier(LandingGreetingReturnRevealModifier(frame: frame, theme: theme))
    }
}

// UAS: landing/stage-command-peak
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
struct LandingStageCommandPeak: View {
    let accent: Color
    let theme: EpistemosTheme

    var body: some View {
        Group {
            switch LandingCommandThemeTreatment.resolve(for: theme) {
            case .platinumBlock:
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(accent.opacity(theme.isDark ? 0.84 : 0.70))
                        .frame(width: 56, height: 4)
                    Rectangle()
                        .fill(accent.opacity(theme.isDark ? 0.72 : 0.58))
                        .frame(width: 36, height: 4)
                    Rectangle()
                        .fill(accent.opacity(theme.isDark ? 0.60 : 0.48))
                        .frame(width: 18, height: 4)
                }
            case .classicNative:
                VStack(spacing: 3) {
                    Capsule()
                        .fill(accent.opacity(theme.isDark ? 0.40 : 0.30))
                        .frame(width: 60, height: 3)
                    Capsule()
                        .fill(Color.white.opacity(theme.isDark ? 0.16 : 0.42))
                        .frame(width: 34, height: 2)
                }
                .shadow(color: accent.opacity(theme.isDark ? 0.12 : 0.08), radius: 8, x: 0, y: 2)
            case .emberHybrid:
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent.opacity(theme.isDark ? 0.64 : 0.48))
                        .frame(width: 54, height: 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(hex: 0xC99A62).opacity(theme.isDark ? 0.34 : 0.28))
                        .frame(width: 28, height: 3)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct PixelGlyph: View {
    let kind: PixelGlyphKind
    let accent: Color
    var isActive = false

    var body: some View {
        ZStack {
            if isActive {
                Rectangle()
                    .fill(accent.opacity(0.12))
                Rectangle()
                    .stroke(accent.opacity(0.48), lineWidth: 1)
            }

            Image(systemName: kind.systemImageName)
                .font(.system(size: isActive ? 15 : 14, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)

            if isActive {
                VStack {
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(accent.opacity(0.72))
                            .frame(width: 3, height: 3)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct PixelLandingCommandTile: View {
    let title: String
    let shortcut: String?
    let glyph: PixelGlyphKind
    let theme: EpistemosTheme
    let accent: Color
    let haptic: HomeCommandHapticStyle
    var brand: IntegrationBrand? = nil
    var isActive = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var pressFrame = 0

    private var lowercasedTitle: String {
        title.lowercased()
    }

    private var isLit: Bool {
        isHovered || isActive
    }

    private var treatment: LandingCommandThemeTreatment {
        LandingCommandThemeTreatment.resolve(for: theme)
    }

    private var commandFont: Font {
        LandingCommandTypography.commandFont(size: 12, treatment: treatment, theme: theme)
    }

    private var restingCommandTextColor: Color {
        switch treatment {
        case .classicNative:
            return theme.textPrimary.opacity(theme.isDark ? 0.84 : 0.72)
        case .platinumBlock:
            return theme.textPrimary.opacity(theme.isDark ? 0.78 : 0.72)
        case .emberHybrid:
            return theme.textPrimary.opacity(theme.isDark ? 0.82 : 0.76)
        }
    }

    private var activeCommandTextColor: Color {
        switch treatment {
        case .classicNative:
            return theme.textPrimary.opacity(theme.isDark ? 0.96 : 0.88)
        case .platinumBlock:
            return theme.fontAccent
        case .emberHybrid:
            return accent.opacity(theme.isDark ? 0.96 : 0.90)
        }
    }

    private var typewriterAccentColor: Color {
        switch treatment {
        case .classicNative, .emberHybrid:
            return accent
        case .platinumBlock:
            return theme.resolved.accent.color
        }
    }

    var body: some View {
        Button(action: triggerAction) {
            dormantCommandLabel
                .opacity(isLit ? 1 : (treatment == .classicNative ? 0.78 : 0.62))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 52, alignment: .leading)
                .contentShape(Rectangle())
                .scaleEffect(PixelStepMotion.scale(for: pressFrame == 0 ? 3 : pressFrame))
                .offset(y: PixelStepMotion.yOffset(for: pressFrame == 0 ? 3 : pressFrame))
                .animation(reduceMotion ? nil : treatment.hoverAnimation, value: isLit)
        }
        .buttonStyle(.plain)
        .zIndex(isActive || isHovered ? 10 : 0)
        .onHover(perform: handleHover)
        .help(shortcut.map { "\(title) (\($0))" } ?? title)
    }

    private var dormantCommandLabel: some View {
        HStack(spacing: treatment == .classicNative ? 9 : 8) {
            commandGlyph
                .frame(width: 23, height: 23)
                .opacity(isLit ? 1 : 0.82)

            dormantCommandTitle
            Spacer(minLength: 6)

            if let brand {
                IntegrationBrandMarkView(brand: brand, size: 15)
                    .foregroundStyle(accent.opacity(isLit ? 0.96 : 0.72))
                    .opacity(isLit ? 1 : 0.86)
                    .frame(width: 18, height: 18)
            }
        }
        .padding(.horizontal, treatment == .classicNative ? 12 : 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            if treatment == .platinumBlock, isLit {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.regularMaterial)
                    PixelPanelBackground.actionSurface(for: theme)
                        .opacity(theme.isDark ? 0.88 : 0.92)
                    accent.opacity(theme.isDark ? 0.12 : 0.08)
                    Rectangle()
                        .fill(accent.opacity(theme.isDark ? 0.62 : 0.44))
                        .frame(height: 3)
                }
            }
        }
        .overlay {
            if treatment == .platinumBlock, isLit {
                Rectangle()
                    .stroke(theme.textPrimary.opacity(theme.isDark ? 0.22 : 0.30), lineWidth: 1)
            }
        }
        .shadow(
            color: treatment == .platinumBlock && isLit
                ? Color.black.opacity(theme.isDark ? 0.24 : 0.14)
                : Color.clear,
            radius: 0,
            x: treatment == .platinumBlock && isLit ? 3 : 0,
            y: treatment == .platinumBlock && isLit ? 3 : 0
        )
    }

    @ViewBuilder
    private var commandGlyph: some View {
        switch treatment {
        case .classicNative:
            Image(systemName: glyph.systemImageName)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(accent.opacity(isLit ? 1 : 0.88))
        case .platinumBlock:
            PixelGlyph(kind: glyph, accent: accent)
        case .emberHybrid:
            PixelGlyph(kind: glyph, accent: accent)
        }
    }

    private var dormantCommandTitle: some View {
        Group {
            if isLit {
                PixelCommandTypewriterText(
                    text: lowercasedTitle,
                    font: commandFont,
                    color: activeCommandTextColor,
                    accent: typewriterAccentColor
                )
            } else {
                Text(lowercasedTitle)
                    .font(commandFont)
                    .foregroundStyle(restingCommandTextColor)
            }
        }
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private func triggerAction() {
        HapticHelper.homeCommand(haptic)
        pressFrame = 0
        action()
    }

    private func handleHover(_ hovering: Bool) {
        withAnimation(reduceMotion ? nil : treatment.hoverAnimation) {
            isHovered = hovering
        }
    }
}
