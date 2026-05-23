import AppKit
import SwiftUI

enum PixelGlyphKind {
    case capture
    case clock
    case workspace
    case save
    case search
    case notes
    case chat
    case document
    case graph

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
        case .graph: "network"
        }
    }
}

struct PixelPanelBackground: View {
    let theme: EpistemosTheme

    var body: some View {
        ZStack(alignment: .top) {
            Self.panelSurface(for: theme)
            Rectangle()
                .fill(theme.resolved.accent.color)
                .frame(height: 3)
        }
    }

    static func panelSurface(for theme: EpistemosTheme) -> Color {
        solidSurface(for: theme, fraction: theme.isDark ? 0.04 : 0.045)
    }

    static func actionSurface(for theme: EpistemosTheme) -> Color {
        solidSurface(for: theme, fraction: theme.isDark ? 0.05 : 0.08)
    }

    static func actionHoverSurface(for theme: EpistemosTheme) -> Color {
        solidSurface(for: theme, fraction: theme.isDark ? 0.085 : 0.13)
    }

    private static func solidSurface(for theme: EpistemosTheme, fraction: CGFloat) -> Color {
        let base = theme.resolved.background.nsColor.usingColorSpace(.sRGB) ?? theme.resolved.background.nsColor
        let target = theme.isDark ? NSColor.white : NSColor.black
        return Color(nsColor: base.blended(withFraction: fraction, of: target) ?? base)
    }
}

private struct PixelPanelModifier: ViewModifier {
    let theme: EpistemosTheme
    var surface: Color?

    func body(content: Content) -> some View {
        content
            .background {
                if let surface {
                    ZStack(alignment: .top) {
                        surface
                        Rectangle()
                            .fill(theme.resolved.accent.color)
                            .frame(height: 3)
                    }
                } else {
                    PixelPanelBackground(theme: theme)
                }
            }
            .clipShape(Rectangle())
            .overlay {
                Rectangle()
                    .stroke(pixelPanelStrokeColor(for: theme), lineWidth: pixelPanelStrokeWidth(for: theme))
            }
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.28 : 0.18),
                radius: 0,
                x: theme.isDark ? 4 : 6,
                y: theme.isDark ? 4 : 6
            )
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
    static func playHoverReveal(reduceMotion: Bool, setFrame: @escaping (Int) -> Void) async {
        if reduceMotion {
            setFrame(4)
            return
        }
        for frame in [1, 2, 3, 4] {
            setFrame(frame)
            try? await Task.sleep(for: hoverFrameDelay)
        }
    }

    @MainActor
    static func playHoverDismiss(reduceMotion: Bool, setFrame: @escaping (Int) -> Void) async {
        if reduceMotion {
            setFrame(0)
            return
        }
        for frame in [2, 1, 0] {
            setFrame(frame)
            try? await Task.sleep(for: hoverFrameDelay)
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

    static func hoverExpansionProgress(for frame: Int) -> CGFloat {
        switch frame {
        case ...0: 0
        case 1: 0.38
        case 2: 0.82
        case 3: 0.94
        default: 1
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
            font: AppDisplayTypography.font(size: size, isDark: theme.isDark),
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
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var pressFrame = 0

    private var commandFont: Font {
        Font(AppDisplayTypography.regularUIFont(size: 12, weight: .semibold))
    }

    var body: some View {
        Button(action: triggerAction) {
            dormantCommandLabel
                .opacity(isHovered ? 1 : 0.62)
                .background { commandHoverChrome }
                .overlay { commandHoverStroke }
                .shadow(
                    color: isHovered ? Color.black.opacity(theme.isDark ? 0.18 : 0.10) : .clear,
                    radius: isHovered ? 14 : 0,
                    x: 0,
                    y: isHovered ? 7 : 0
                )
                .offset(y: isHovered ? -3 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 52, alignment: .leading)
                .contentShape(Rectangle())
                .scaleEffect(PixelStepMotion.scale(for: pressFrame == 0 ? 3 : pressFrame))
                .offset(y: PixelStepMotion.yOffset(for: pressFrame == 0 ? 3 : pressFrame))
                .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover(perform: handleHover)
        .help(shortcut.map { "\(title) (\($0))" } ?? title)
    }

    private var dormantCommandLabel: some View {
        HStack(spacing: 8) {
            PixelGlyph(kind: glyph, accent: accent)
                .frame(width: 23, height: 23)
                .opacity(isHovered ? 1 : 0.82)

            dormantCommandTitle
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dormantCommandTitle: some View {
        Text(title)
            .font(commandFont)
            .foregroundStyle(isHovered ? theme.textPrimary : theme.textPrimary.opacity(theme.isDark ? 0.78 : 0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    @ViewBuilder
    private var commandHoverChrome: some View {
        if isHovered {
            Capsule()
                .fill(theme.glassBg.opacity(theme.isDark ? 0.34 : 0.24))
                .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    @ViewBuilder
    private var commandHoverStroke: some View {
        if isHovered {
            Capsule()
                .strokeBorder(accent.opacity(theme.isDark ? 0.16 : 0.22), lineWidth: 0.7)
        }
    }

    private func triggerAction() {
        HapticHelper.homeCommand(haptic)
        Task { @MainActor in
            await PixelStepMotion.play(reduceMotion: reduceMotion) { frame in
                pressFrame = frame
            }
            pressFrame = 0
            action()
        }
    }

    private func handleHover(_ hovering: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.16)) {
            isHovered = hovering
        }
    }
}
