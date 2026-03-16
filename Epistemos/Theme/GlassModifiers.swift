import SwiftUI

// MARK: - Liquid Glass Modifiers (macOS 26)

/// Conditionally applies glass (when active) or a flat colored background (when inactive).
struct FlatToGlassModifier: ViewModifier {
    let isActive: Bool
    let flatBackground: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if isActive {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(flatBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// Hover glass: flat background at rest, Liquid Glass on hover.
/// Only the item under the cursor pays the blur cost.
struct HoverGlassModifier: ViewModifier {
    let flatBackground: Color
    let cornerRadius: CGFloat
    let shape: HoverGlassShape

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum HoverGlassShape {
        case roundedRect
        case capsule
    }

    func body(content: Content) -> some View {
        content
            .background {
                if isHovered {
                    switch shape {
                    case .roundedRect:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    case .capsule:
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: Capsule())
                    }
                } else {
                    switch shape {
                    case .roundedRect:
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(flatBackground)
                    case .capsule:
                        Capsule().fill(flatBackground)
                    }
                }
            }
            .onHover { hovering in
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(Motion.smooth) { isHovered = hovering }
                }
            }
    }
}

// MARK: - Apple Intelligence Shimmer Border
/// Animated rainbow gradient border inspired by Apple Intelligence's Writing Tools glow.
/// Flows a spectral gradient around the element's border for a premium, AI-infused feel.

struct SiriGlowBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [
        Color(hue: 0.75, saturation: 0.6, brightness: 0.9),  // purple
        Color(hue: 0.60, saturation: 0.5, brightness: 0.95), // blue
        Color(hue: 0.50, saturation: 0.5, brightness: 0.95), // cyan
        Color(hue: 0.35, saturation: 0.5, brightness: 0.9),  // green
        Color(hue: 0.15, saturation: 0.5, brightness: 0.95), // yellow
        Color(hue: 0.05, saturation: 0.6, brightness: 0.95), // orange
        Color(hue: 0.95, saturation: 0.5, brightness: 0.9),  // pink
        Color(hue: 0.75, saturation: 0.6, brightness: 0.9),  // purple (loop)
    ]

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    // TimelineView at 30Hz — glow rotation doesn't need 60fps.
                    // drawingGroup() rasterizes the gradient+blur to a Metal texture
                    // on GPU instead of CPU-compositing every frame.
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        let elapsed = context.date.timeIntervalSinceReferenceDate
                        let phase = elapsed.truncatingRemainder(dividingBy: 4) / 4 * 360

                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    AngularGradient(
                                        colors: Self.colors,
                                        center: .center,
                                        startAngle: .degrees(phase),
                                        endAngle: .degrees(phase + 360)
                                    ),
                                    lineWidth: lineWidth
                                )
                                .blur(radius: 1)
                                .opacity(0.7)

                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    AngularGradient(
                                        colors: Self.colors,
                                        center: .center,
                                        startAngle: .degrees(phase),
                                        endAngle: .degrees(phase + 360)
                                    ),
                                    lineWidth: lineWidth * 2.5
                                )
                                .blur(radius: 4)
                                .opacity(0.25)
                        }
                        .drawingGroup()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Assistant Surface Chrome

struct AssistantSurfaceMetrics: Equatable {
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let controlRadius: CGFloat
    let borderWidth: CGFloat
    let showsOuterStroke: Bool
    let contentHorizontalPadding: CGFloat
    let contentVerticalPadding: CGFloat
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat

    static let commandPalette = AssistantSurfaceMetrics(
        outerRadius: 30,
        innerRadius: 24,
        controlRadius: 18,
        borderWidth: 0.82,
        showsOuterStroke: true,
        contentHorizontalPadding: 18,
        contentVerticalPadding: 16,
        shadowRadius: 26,
        shadowYOffset: 12
    )

    static let popout = AssistantSurfaceMetrics(
        outerRadius: 30,
        innerRadius: 24,
        controlRadius: 18,
        borderWidth: 0.72,
        showsOuterStroke: true,
        contentHorizontalPadding: 20,
        contentVerticalPadding: 18,
        shadowRadius: 28,
        shadowYOffset: 14
    )
}

struct AssistantSurfaceChrome<Content: View>: View {
    let theme: EpistemosTheme
    let metrics: AssistantSurfaceMetrics
    let content: Content

    init(
        theme: EpistemosTheme,
        metrics: AssistantSurfaceMetrics = .commandPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.metrics = metrics
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, metrics.contentHorizontalPadding)
            .padding(.vertical, metrics.contentVerticalPadding)
            .background {
                AssistantSurfaceBackground(theme: theme, metrics: metrics)
            }
            .clipShape(RoundedRectangle(cornerRadius: metrics.outerRadius, style: .continuous))
            .overlay {
                if metrics.showsOuterStroke {
                    AssistantSurfaceStroke(theme: theme, metrics: metrics)
                }
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.18 : 0.08), radius: 8, y: 3)
            .shadow(
                color: .black.opacity(theme.isDark ? 0.26 : 0.10),
                radius: metrics.shadowRadius,
                x: 0,
                y: metrics.shadowYOffset
            )
    }
}

struct AssistantInsetChrome: ViewModifier {
    let theme: EpistemosTheme
    let cornerRadius: CGFloat
    let isEmphasized: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.isDark ? theme.muted.opacity(isEmphasized ? 0.82 : 0.64) : theme.muted.opacity(isEmphasized ? 0.72 : 0.54))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                theme.glassBorder.opacity(isEmphasized ? 0.9 : 0.68),
                                lineWidth: 0.6
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: max(cornerRadius - 3, 0), style: .continuous)
                            .strokeBorder(
                                .white.opacity(theme.isDark ? (isEmphasized ? 0.08 : 0.05) : (isEmphasized ? 0.34 : 0.22)),
                                lineWidth: 0.5
                            )
                            .padding(1.2)
                    }
            }
    }
}

struct AssistantGlassInputChrome: ViewModifier {
    let theme: EpistemosTheme
    let cornerRadius: CGFloat
    let isActive: Bool

    private let metrics = AssistantGlassInputMetrics.default
    private var prefersNativeAssistantGlass: Bool {
        theme.usesNativeWindowBlur || theme == .light || theme == .oled
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                if prefersNativeAssistantGlass, metrics.prefersGlassEffect {
                    shape
                        .fill(.white.opacity(0.001))
                        .glassEffect(.regular.interactive(), in: shape)
                } else if theme.isDark {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(theme.background.opacity(0.48))
                    }
                } else {
                    ZStack {
                        shape.fill(.regularMaterial)
                        shape.fill(theme.background.opacity(0.12))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    theme.glassBorder.opacity(
                        isActive ? metrics.activeBorderOpacity : metrics.idleBorderOpacity
                    ),
                    lineWidth: 0.55
                )
            }
            .overlay {
                shape
                    .strokeBorder(
                        .white.opacity(theme.isDark ? 0.05 : 0.16),
                        lineWidth: 0.4
                    )
                    .padding(1)
            }
            .shadow(
                color: .black.opacity(metrics.shadowOpacity),
                radius: metrics.shadowRadius,
                x: 0,
                y: metrics.shadowYOffset
            )
    }
}

struct AssistantGlassInputMetrics: Equatable {
    let prefersGlassEffect: Bool
    let tintOpacity: Double
    let activeBorderOpacity: Double
    let idleBorderOpacity: Double
    let highlightOpacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat

    static let `default` = AssistantGlassInputMetrics(
        prefersGlassEffect: true,
        tintOpacity: 0,
        activeBorderOpacity: 0.56,
        idleBorderOpacity: 0.38,
        highlightOpacity: 0.04,
        shadowOpacity: 0.11,
        shadowRadius: 18,
        shadowYOffset: 8
    )
}

struct AssistantComposerMetrics: Equatable {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
    let sendButtonSize: CGFloat
    let sendIconSize: CGFloat

    static let mainChat = AssistantComposerMetrics(
        cornerRadius: 16,
        borderWidth: 0.6,
        horizontalPadding: 12,
        verticalPadding: 7,
        shadowRadius: 18,
        shadowYOffset: 8,
        sendButtonSize: 32,
        sendIconSize: 12
    )

    static let compactChat = AssistantComposerMetrics(
        cornerRadius: 22,
        borderWidth: 0.62,
        horizontalPadding: 14,
        verticalPadding: 10,
        shadowRadius: 20,
        shadowYOffset: 9,
        sendButtonSize: 36,
        sendIconSize: 14
    )
}

struct AssistantSourceChromeMetrics: Equatable {
    let chipCornerRadius: CGFloat
    let chipBorderWidth: CGFloat
    let popoverCornerRadius: CGFloat
    let popoverBorderWidth: CGFloat
    let popoverShadowRadius: CGFloat
    let popoverShadowYOffset: CGFloat

    static let `default` = AssistantSourceChromeMetrics(
        chipCornerRadius: 14,
        chipBorderWidth: 0.55,
        popoverCornerRadius: 18,
        popoverBorderWidth: 0.65,
        popoverShadowRadius: 18,
        popoverShadowYOffset: 10
    )
}

enum AssistantSourceKind: String, Hashable {
    case note
    case link
}

struct AssistantSourceReference: Identifiable, Equatable, Hashable {
    let kind: AssistantSourceKind
    let title: String
    let subtitle: String
    let url: URL?

    var id: String {
        if let url {
            return "\(kind.rawValue):\(url.absoluteString.lowercased())"
        }
        return "\(kind.rawValue):\(title.lowercased())"
    }

    private static let markdownLinkRegex = try! NSRegularExpression(
        pattern: #"\[([^\]]+)\]\((https?://[^\s\)]+)\)"#
    )
    private static let rawURLRegex = try! NSRegularExpression(
        pattern: #"https?://[^\s\)\]>\"']+"#
    )

    static func extract(from text: String, noteTitles: [String] = []) -> [AssistantSourceReference] {
        var results: [AssistantSourceReference] = []
        var seen = Set<String>()

        for title in noteTitles {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let source = AssistantSourceReference(
                kind: .note,
                title: trimmed,
                subtitle: "Vault note",
                url: nil
            )
            guard seen.insert(source.id).inserted else { continue }
            results.append(source)
        }

        let nsText = text as NSString

        for match in markdownLinkRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard match.numberOfRanges == 3 else { continue }
            let title = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let urlString = sanitizedURLString(nsText.substring(with: match.range(at: 2)))
            guard let url = URL(string: urlString) else { continue }

            let source = AssistantSourceReference(
                kind: .link,
                title: title.isEmpty ? linkTitle(for: url) : title,
                subtitle: hostTitle(for: url),
                url: url
            )
            guard seen.insert(source.id).inserted else { continue }
            results.append(source)
        }

        for match in rawURLRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let urlString = sanitizedURLString(nsText.substring(with: match.range))
            guard let url = URL(string: urlString) else { continue }

            let source = AssistantSourceReference(
                kind: .link,
                title: linkTitle(for: url),
                subtitle: hostTitle(for: url),
                url: url
            )
            guard seen.insert(source.id).inserted else { continue }
            results.append(source)
        }

        return results
    }

    private static func sanitizedURLString(_ string: String) -> String {
        string.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
    }

    private static func hostTitle(for url: URL) -> String {
        let host = url.host ?? url.absoluteString
        return host.replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }

    private static func linkTitle(for url: URL) -> String {
        let components = url.pathComponents.filter { $0 != "/" }
        if let last = components.last, !last.isEmpty {
            let cleaned = last
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            if !cleaned.isEmpty { return cleaned }
        }
        return hostTitle(for: url)
    }
}

struct AssistantSendButton: View {
    let theme: EpistemosTheme
    let isEnabled: Bool
    let isProcessing: Bool
    let metrics: AssistantComposerMetrics
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isProcessing ? "stop.fill" : "arrow.up")
                .font(.system(size: metrics.sendIconSize, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: metrics.sendButtonSize, height: metrics.sendButtonSize)
                .background {
                    Circle()
                        .fill(fillColor)
                        .overlay {
                            Circle()
                                .strokeBorder(borderColor, lineWidth: 0.6)
                        }
                }
                .shadow(
                    color: .black.opacity(isEnabled || isProcessing ? (theme.isDark ? 0.26 : 0.12) : 0),
                    radius: 10,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isHovered && (isEnabled || isProcessing) ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled && !isProcessing)
        .onHover { hovering in
            withAnimation(Motion.micro) { isHovered = hovering }
        }
    }

    private var fillColor: Color {
        if isProcessing {
            return theme.foreground.opacity(theme.isDark ? 0.18 : 0.1)
        }
        if isEnabled {
            return theme.foreground.opacity(theme.isDark ? 0.94 : 0.92)
        }
        return theme.muted.opacity(theme.isDark ? 0.74 : 0.5)
    }

    private var iconColor: Color {
        if isProcessing {
            return theme.accent
        }
        if isEnabled {
            return theme.background.opacity(theme.isDark ? 0.95 : 0.98)
        }
        return theme.textTertiary.opacity(0.75)
    }

    private var borderColor: Color {
        if isEnabled || isProcessing {
            return .white.opacity(theme.isDark ? 0.12 : 0.2)
        }
        return theme.glassBorder.opacity(0.35)
    }
}

struct AssistantComposerChrome: ViewModifier {
    let theme: EpistemosTheme
    let metrics: AssistantComposerMetrics
    let isActive: Bool
    private var prefersNativeAssistantGlass: Bool {
        theme.usesNativeWindowBlur || theme == .light || theme == .oled
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)

        content
            .background {
                if prefersNativeAssistantGlass {
                    shape
                        .fill(.white.opacity(0.001))
                        .glassEffect(.regular.interactive(), in: shape)
                } else if theme.isDark {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(theme.background.opacity(0.58))
                    }
                } else {
                    ZStack {
                        shape.fill(.regularMaterial)
                        shape.fill(theme.background.opacity(0.16))
                    }
                }
            }
            .overlay {
                shape
                    .strokeBorder(
                        theme.glassBorder.opacity(isActive ? 0.7 : 0.52),
                        lineWidth: metrics.borderWidth
                    )
            }
            .overlay {
                shape
                    .strokeBorder(
                        .white.opacity(theme.isDark ? 0.06 : 0.18),
                        lineWidth: 0.45
                    )
                    .padding(1.1)
            }
            .shadow(
                color: .black.opacity(theme.isDark ? 0.16 : 0.08),
                radius: metrics.shadowRadius,
                x: 0,
                y: metrics.shadowYOffset
            )
    }
}

struct AssistantPopoverChrome: ViewModifier {
    let theme: EpistemosTheme
    let metrics: AssistantSourceChromeMetrics

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: metrics.popoverCornerRadius, style: .continuous)

        content
            .background {
                if theme.usesNativeWindowBlur {
                    shape
                        .fill(theme.glassBg.opacity(theme.isDark ? 0.76 : 0.86))
                        .glassEffect(.regular.interactive(), in: shape)
                } else if theme.isDark {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(theme.background.opacity(0.78))
                    }
                } else {
                    ZStack {
                        shape.fill(.regularMaterial)
                        shape.fill(theme.glassBg.opacity(0.92))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    theme.glassBorder.opacity(theme.isDark ? 0.72 : 0.48),
                    lineWidth: metrics.popoverBorderWidth
                )
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.22 : 0.1), radius: metrics.popoverShadowRadius, y: metrics.popoverShadowYOffset)
    }
}

struct AssistantUtilityButtonStyle: ButtonStyle {
    let theme: EpistemosTheme
    let cornerRadius: CGFloat

    init(theme: EpistemosTheme, cornerRadius: CGFloat = 14) {
        self.theme = theme
        self.cornerRadius = cornerRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(theme.textSecondary)
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.muted.opacity(configuration.isPressed ? 0.88 : 0.58))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(theme.glassBorder.opacity(0.62), lineWidth: 0.55)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct AssistantSourcesFooter: View {
    let sources: [AssistantSourceReference]
    let theme: EpistemosTheme
    var compact = false

    private let metrics = AssistantSourceChromeMetrics.default

    private var displayedSources: ArraySlice<AssistantSourceReference> {
        sources.prefix(compact ? 4 : 6)
    }

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                    Text("Sources")
                        .font(.system(size: compact ? 10 : 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                    if sources.count > displayedSources.count {
                        Text("+\(sources.count - displayedSources.count)")
                            .font(.system(size: compact ? 10 : 11, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textTertiary.opacity(0.72))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayedSources) { source in
                            AssistantSourceChip(
                                source: source,
                                theme: theme,
                                metrics: metrics,
                                compact: compact
                            )
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }
}

private struct AssistantSourceChip: View {
    let source: AssistantSourceReference
    let theme: EpistemosTheme
    let metrics: AssistantSourceChromeMetrics
    let compact: Bool

    @Environment(\.openURL) private var openURL
    @State private var isHovered = false
    @State private var isPinned = false
    @State private var showsPreview = false

    var body: some View {
        Button(action: activate) {
            HStack(spacing: 6) {
                Image(systemName: source.kind == .note ? "doc.text" : "link")
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundStyle(source.kind == .note ? theme.accent.opacity(0.8) : theme.textSecondary)

                Text(source.title)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 10 : 11)
            .padding(.vertical, compact ? 6 : 7)
            .background {
                RoundedRectangle(cornerRadius: metrics.chipCornerRadius, style: .continuous)
                    .fill(theme.card.opacity(isHovered ? 0.88 : 0.64))
                    .overlay {
                        RoundedRectangle(cornerRadius: metrics.chipCornerRadius, style: .continuous)
                            .strokeBorder(
                                theme.glassBorder.opacity(isHovered ? 0.7 : 0.5),
                                lineWidth: metrics.chipBorderWidth
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .help(source.subtitle)
        .popover(isPresented: $showsPreview, arrowEdge: .top) {
            AssistantSourcePreviewCard(source: source, theme: theme, metrics: metrics)
                .padding(14)
        }
        .onHover { hovering in
            withAnimation(Motion.micro) { isHovered = hovering }
            if hovering {
                showsPreview = true
            } else if !isPinned {
                showsPreview = false
            }
        }
    }

    private func activate() {
        if let url = source.url {
            isPinned = false
            showsPreview = false
            openURL(url)
        } else {
            isPinned.toggle()
            showsPreview = isPinned
        }
    }
}

private struct AssistantSourcePreviewCard: View {
    let source: AssistantSourceReference
    let theme: EpistemosTheme
    let metrics: AssistantSourceChromeMetrics

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: source.kind == .note ? "doc.text.fill" : "globe")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(source.kind == .note ? theme.accent : theme.foreground)

                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(2)
                    Text(source.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if let url = source.url {
                Text(url.absoluteString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(2)

                Button {
                    openURL(url)
                } label: {
                    Label("Open Source", systemImage: "arrow.up.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .assistantInsetChrome(theme: theme, cornerRadius: 12, isEmphasized: true)
            } else {
                Text("Loaded from the vault context for this answer.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 280, alignment: .leading)
        .assistantPopoverChrome(theme: theme, metrics: metrics)
    }
}

private struct AssistantSurfaceBackground: View {
    let theme: EpistemosTheme
    let metrics: AssistantSurfaceMetrics
    private var prefersNativeAssistantGlass: Bool {
        theme.usesNativeWindowBlur || theme == .light || theme == .oled
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.outerRadius, style: .continuous)

        if prefersNativeAssistantGlass {
            shape
                .fill(theme.floatingSurfaceTint.opacity(theme.isDark ? 0.30 : 0.82))
                .glassEffect(.regular.interactive(), in: shape)
        } else if theme.isDark {
            ZStack {
                shape
                    .fill(.ultraThinMaterial)
                shape
                    .fill(theme.floatingSurfaceTint.opacity(0.28))
            }
        } else {
            ZStack {
                shape
                    .fill(.regularMaterial)
                shape
                    .fill(theme.floatingSurfaceTint.opacity(0.90))
            }
        }
    }
}

private struct AssistantSurfaceStroke: View {
    let theme: EpistemosTheme
    let metrics: AssistantSurfaceMetrics

    var body: some View {
        RoundedRectangle(cornerRadius: metrics.outerRadius, style: .continuous)
            .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.86 : 0.72), lineWidth: metrics.borderWidth)
    }
}

// MARK: - View Extensions

extension View {
    func flatToGlass(
        isActive: Bool,
        flatBackground: Color,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(FlatToGlassModifier(isActive: isActive, flatBackground: flatBackground, cornerRadius: cornerRadius))
    }

    func hoverGlass(
        flatBackground: Color,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(HoverGlassModifier(flatBackground: flatBackground, cornerRadius: cornerRadius, shape: .roundedRect))
    }

    func hoverGlassCapsule(
        flatBackground: Color
    ) -> some View {
        modifier(HoverGlassModifier(flatBackground: flatBackground, cornerRadius: 0, shape: .capsule))
    }

    func siriGlow(
        cornerRadius: CGFloat = 12,
        lineWidth: CGFloat = 1.5,
        isActive: Bool = true
    ) -> some View {
        modifier(SiriGlowBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth, isActive: isActive))
    }

    func assistantInsetChrome(
        theme: EpistemosTheme,
        cornerRadius: CGFloat = 18,
        isEmphasized: Bool = false
    ) -> some View {
        modifier(AssistantInsetChrome(theme: theme, cornerRadius: cornerRadius, isEmphasized: isEmphasized))
    }

    func assistantGlassInputChrome(
        theme: EpistemosTheme,
        cornerRadius: CGFloat = 18,
        isActive: Bool = true
    ) -> some View {
        modifier(AssistantGlassInputChrome(theme: theme, cornerRadius: cornerRadius, isActive: isActive))
    }

    func assistantComposerChrome(
        theme: EpistemosTheme,
        metrics: AssistantComposerMetrics = .mainChat,
        isActive: Bool = true
    ) -> some View {
        modifier(AssistantComposerChrome(theme: theme, metrics: metrics, isActive: isActive))
    }

    func assistantPopoverChrome(
        theme: EpistemosTheme,
        metrics: AssistantSourceChromeMetrics = .default
    ) -> some View {
        modifier(AssistantPopoverChrome(theme: theme, metrics: metrics))
    }
}
