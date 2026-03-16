import SwiftUI

enum NativeControlVariant {
    case toolbar
    case content
}

enum NativeControlRole {
    case primaryAction
    case toolbarUtility
    case mode
    case secondaryGhost
    case disclosure
}

enum NativeControlChromePolicy: Equatable {
    case alwaysSurface
    case bareUntilPressed

    func showsSurface(
        isHovered: Bool,
        isPressed: Bool,
        isActive: Bool
    ) -> Bool {
        switch self {
        case .alwaysSurface:
            true
        case .bareUntilPressed:
            isPressed || isActive
        }
    }
}

struct NativeControlVariantMetrics: Equatable {
    let height: CGFloat
    let cornerRadius: CGFloat
    let horizontalPadding: ClosedRange<CGFloat>
    let iconSize: CGFloat
    let labelSpacing: CGFloat
    let fontSize: CGFloat
    let minHitWidth: CGFloat
    let maxLabelWidth: CGFloat
}

struct NativeControlAnimationMetrics: Equatable {
    let hoverDuration: Double
    let pressDuration: Double
    let expansionDuration: Double
    let selectionDuration: Double
    let popoverDuration: Double
    let asciiFrameInterval: TimeInterval
}

enum NativeControlSystem {
    static let toolbar = NativeControlVariantMetrics(
        height: 28,
        cornerRadius: 10,
        horizontalPadding: 8...10,
        iconSize: 13,
        labelSpacing: 6,
        fontSize: 13,
        minHitWidth: 28,
        maxLabelWidth: 92
    )

    static let content = NativeControlVariantMetrics(
        height: 32,
        cornerRadius: 12,
        horizontalPadding: 10...12,
        iconSize: 14,
        labelSpacing: 6,
        fontSize: 13,
        minHitWidth: 32,
        maxLabelWidth: 104
    )

    static let animation = NativeControlAnimationMetrics(
        hoverDuration: 0.12,
        pressDuration: 0.08,
        expansionDuration: 0.18,
        selectionDuration: 0.18,
        popoverDuration: 0.16,
        asciiFrameInterval: 0.045
    )

    static let toolbarPopoverWidthRange: ClosedRange<CGFloat> = 220...360
    static let contentPopoverWidthRange: ClosedRange<CGFloat> = 240...340

    static func metrics(for variant: NativeControlVariant) -> NativeControlVariantMetrics {
        switch variant {
        case .toolbar: toolbar
        case .content: content
        }
    }

    static func popoverWidthRange(for variant: NativeControlVariant) -> ClosedRange<CGFloat> {
        switch variant {
        case .toolbar: toolbarPopoverWidthRange
        case .content: contentPopoverWidthRange
        }
    }

    static func reservedWidth(for title: String, variant: NativeControlVariant) -> CGFloat {
        reservedWidth(for: [title], variant: variant)
    }

    static func reservedWidth(
        for title: String,
        variant: NativeControlVariant,
        includesDisclosureGlyph: Bool
    ) -> CGFloat {
        reservedWidth(
            for: [title],
            variant: variant,
            includesDisclosureGlyph: includesDisclosureGlyph
        )
    }

    static func reservedWidth(
        for titles: [String],
        variant: NativeControlVariant,
        includesDisclosureGlyph: Bool = false
    ) -> CGFloat {
        let metrics = metrics(for: variant)
        let longestTitle = titles.max(by: { $0.count < $1.count }) ?? ""
        let labelEstimate = min(
            metrics.maxLabelWidth,
            ceil(CGFloat(longestTitle.count) * (variant == .toolbar ? 6.0 : 6.8))
        )
        return ceil(
            metrics.horizontalPadding.upperBound * 2
                + metrics.iconSize
                + metrics.labelSpacing
                + labelEstimate
                + (includesDisclosureGlyph ? metrics.iconSize : 0)
        )
    }
}

private enum NativeControlPalette {
    static func fill(
        theme: EpistemosTheme,
        role: NativeControlRole,
        isActive: Bool,
        isHovered: Bool,
        isPressed: Bool
    ) -> Color {
        if isActive {
            switch role {
            case .primaryAction:
                return theme.accent.opacity(theme.isDark ? 0.24 : 0.16)
            case .toolbarUtility, .mode, .secondaryGhost, .disclosure:
                return theme.accent.opacity(theme.isDark ? 0.18 : 0.10)
            }
        }
        if isPressed {
            return theme.foreground.opacity(theme.isDark ? 0.09 : 0.06)
        }
        if isHovered {
            return theme.foreground.opacity(theme.isDark ? 0.075 : 0.05)
        }
        switch role {
        case .primaryAction:
            return theme.foreground.opacity(theme.isDark ? 0.08 : 0.05)
        case .toolbarUtility, .mode, .secondaryGhost, .disclosure:
            return theme.foreground.opacity(theme.isDark ? 0.045 : 0.03)
        }
    }

    static func stroke(
        theme: EpistemosTheme,
        role: NativeControlRole,
        isActive: Bool,
        isHovered: Bool
    ) -> Color {
        if isActive {
            return theme.accent.opacity(theme.isDark ? 0.22 : 0.14)
        }
        if isHovered {
            return theme.foreground.opacity(theme.isDark ? 0.10 : 0.07)
        }
        switch role {
        case .primaryAction:
            return theme.foreground.opacity(theme.isDark ? 0.09 : 0.06)
        case .toolbarUtility, .mode, .secondaryGhost, .disclosure:
            return theme.foreground.opacity(theme.isDark ? 0.075 : 0.05)
        }
    }

    static func foreground(
        theme: EpistemosTheme,
        role: NativeControlRole,
        isActive: Bool,
        isHovered: Bool,
        isEnabled: Bool
    ) -> Color {
        guard isEnabled else {
            return theme.textTertiary.opacity(0.75)
        }
        if isActive {
            switch role {
            case .primaryAction:
                return theme.foreground
            case .toolbarUtility, .mode, .secondaryGhost, .disclosure:
                return theme.accent
            }
        }
        if isHovered {
            return theme.foreground
        }
        switch role {
        case .primaryAction:
            return theme.foreground.opacity(0.92)
        case .toolbarUtility, .mode, .secondaryGhost, .disclosure:
            return theme.textSecondary
        }
    }

    static func shadowOpacity(
        isActive: Bool,
        isHovered: Bool,
        isPressed: Bool
    ) -> Double {
        if isPressed { return 0.015 }
        if isActive { return 0.045 }
        if isHovered { return 0.025 }
        return 0
    }
}

private struct NativeCapsuleButtonStyle: ButtonStyle {
    let theme: EpistemosTheme
    let variant: NativeControlVariant
    let role: NativeControlRole
    let isActive: Bool
    let chromePolicy: NativeControlChromePolicy
    let morphID: String?

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let metrics = NativeControlSystem.metrics(for: variant)
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        let fillColor = NativeControlPalette.fill(
            theme: theme,
            role: role,
            isActive: isActive,
            isHovered: isHovered,
            isPressed: configuration.isPressed
        )
        let strokeColor = NativeControlPalette.stroke(
            theme: theme,
            role: role,
            isActive: isActive,
            isHovered: isHovered
        )
        let foregroundColor = NativeControlPalette.foreground(
            theme: theme,
            role: role,
            isActive: isActive,
            isHovered: isHovered,
            isEnabled: isEnabled
        )
        let showsSurface = chromePolicy.showsSurface(
            isHovered: isHovered,
            isPressed: configuration.isPressed,
            isActive: isActive
        )

        configuration.label
            .frame(minHeight: metrics.height)
            .foregroundStyle(foregroundColor)
            .background {
                if showsSurface {
                    shape
                        .fill(fillColor)
                        .overlay {
                            shape
                                .strokeBorder(strokeColor, lineWidth: 0.55)
                        }
                        .overlay {
                            shape
                                .strokeBorder(
                                    .white.opacity(theme.isDark ? 0.035 : 0.11),
                                    lineWidth: 0.35
                                )
                                .padding(1)
                        }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.988 : 1.0)
            .shadow(
                color: .black.opacity(
                    showsSurface
                        ? NativeControlPalette.shadowOpacity(
                            isActive: isActive,
                            isHovered: isHovered,
                            isPressed: configuration.isPressed
                        )
                        : 0
                ),
                radius: isActive ? 6 : 4,
                y: isActive ? 2 : 1
            )
            .animation(
                .easeInOut(duration: NativeControlSystem.animation.pressDuration),
                value: configuration.isPressed
            )
            .animation(
                .easeInOut(duration: NativeControlSystem.animation.hoverDuration),
                value: isHovered
            )
            .onHover { isHovered = $0 }
            .toolbarMorphInteractionSync(
                id: morphID,
                isHovered: isHovered,
                isPressed: configuration.isPressed
            )
            .opacity(isEnabled ? 1 : 0.48)
    }
}

struct ToolbarCapsuleButton: View {
    let title: String?
    let systemImage: String
    var variant: NativeControlVariant = .toolbar
    var role: NativeControlRole = .toolbarUtility
    var isActive = false
    var chromePolicy: NativeControlChromePolicy = .bareUntilPressed
    var helpText: String? = nil
    var accessibilityLabel: String? = nil
    var morphID: String? = nil
    let action: () -> Void

    @Environment(UIState.self) private var ui

    private var metrics: NativeControlVariantMetrics {
        NativeControlSystem.metrics(for: variant)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.labelSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: metrics.iconSize, weight: .semibold))

                if let title {
                    Text(title)
                        .font(.system(size: metrics.fontSize, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, title == nil ? metrics.horizontalPadding.lowerBound : metrics.horizontalPadding.upperBound)
            .frame(minWidth: metrics.minHitWidth)
        }
        .buttonStyle(
            NativeCapsuleButtonStyle(
                theme: ui.theme,
                variant: variant,
                role: role,
                isActive: isActive,
                chromePolicy: chromePolicy,
                morphID: morphID
            )
        )
        .toolbarMorphItem(id: morphID, isActive: isActive)
        .help(helpText ?? title ?? "")
        .accessibilityLabel(accessibilityLabel ?? title ?? helpText ?? "")
    }
}

struct ExpandingModeButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    var activeTitle: String? = nil
    var variant: NativeControlVariant = .toolbar
    var helpText: String? = nil
    var accessibilityLabel: String? = nil
    var asciiAnimation: ASCIIControlAnimationSet? = nil
    var asciiFont: Font = .system(size: 11, weight: .medium, design: .monospaced)
    var stableWidth: CGFloat? = nil
    var expandsOnHover = true
    var chromePolicy: NativeControlChromePolicy = .bareUntilPressed
    var morphID: String? = nil
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    @State private var asciiPhase: ASCIIControlPhase = .inactive
    @State private var phaseTask: Task<Void, Never>?

    private var metrics: NativeControlVariantMetrics {
        NativeControlSystem.metrics(for: variant)
    }

    private var currentTitle: String {
        isActive ? (activeTitle ?? title) : title
    }

    private var showsExpandedContent: Bool {
        isActive || asciiPhase != .inactive || (expandsOnHover && isHovered)
    }

    private var minimumControlWidth: CGFloat {
        guard showsExpandedContent, let stableWidth else { return metrics.minHitWidth }
        return max(metrics.minHitWidth, stableWidth)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.labelSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: metrics.iconSize, weight: .semibold))

                if showsExpandedContent {
                    Text(currentTitle)
                        .font(.system(size: metrics.fontSize, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                if let asciiAnimation, asciiPhase != .inactive {
                    ASCIIStateBadge(
                        phase: asciiPhase,
                        animationSet: asciiAnimation,
                        font: asciiFont,
                        color: ui.theme.textTertiary
                    )
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, showsExpandedContent ? metrics.horizontalPadding.upperBound : metrics.horizontalPadding.lowerBound)
            .frame(minWidth: minimumControlWidth, alignment: .leading)
        }
        .buttonStyle(
            NativeCapsuleButtonStyle(
                theme: ui.theme,
                variant: variant,
                role: .mode,
                isActive: isActive,
                chromePolicy: chromePolicy,
                morphID: morphID
            )
        )
        .toolbarMorphItem(
            id: morphID,
            isActive: isActive,
            revealProgress: showsExpandedContent ? 1 : 0
        )
        .help(helpText ?? currentTitle)
        .accessibilityLabel(accessibilityLabel ?? currentTitle)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .animation(.easeInOut(duration: NativeControlSystem.animation.expansionDuration), value: showsExpandedContent)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: NativeControlSystem.animation.hoverDuration)) {
                isHovered = hovering
            }
        }
        .onAppear {
            asciiPhase = isActive ? .active : .inactive
        }
        .onChange(of: isActive) { _, active in
            syncASCIIPhase(isActive: active)
        }
        .onDisappear {
            phaseTask?.cancel()
        }
    }

    private func syncASCIIPhase(isActive: Bool) {
        phaseTask?.cancel()
        guard let asciiAnimation else {
            asciiPhase = isActive ? .active : .inactive
            return
        }
        if isActive {
            asciiPhase = .arming
            phaseTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(asciiAnimation.duration(for: .arming)))
                guard !Task.isCancelled else { return }
                asciiPhase = .active
            }
        } else {
            guard asciiPhase != .inactive else { return }
            asciiPhase = .cooling
            phaseTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(asciiAnimation.duration(for: .cooling)))
                guard !Task.isCancelled else { return }
                asciiPhase = .inactive
            }
        }
    }
}

struct ModeChipOption<Value: Hashable>: Hashable {
    let value: Value
    let title: String
    let systemImage: String?
}

struct ModeChipGroup<Value: Hashable>: View {
    let options: [ModeChipOption<Value>]
    @Binding var selection: Value
    var variant: NativeControlVariant = .toolbar

    @Environment(UIState.self) private var ui

    private var metrics: NativeControlVariantMetrics {
        NativeControlSystem.metrics(for: variant)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: NativeControlSystem.animation.selectionDuration)) {
                        selection = option.value
                    }
                } label: {
                    HStack(spacing: metrics.labelSpacing) {
                        if let systemImage = option.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: metrics.iconSize - 1, weight: .semibold))
                        }
                        Text(option.title)
                            .font(.system(size: metrics.fontSize, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, metrics.horizontalPadding.upperBound)
                    .frame(minWidth: metrics.minHitWidth)
                }
                .buttonStyle(
                    NativeCapsuleButtonStyle(
                        theme: ui.theme,
                        variant: variant,
                        role: .mode,
                        isActive: selection == option.value,
                        chromePolicy: .alwaysSurface,
                        morphID: nil
                    )
                )
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
    }
}

struct AnchoredPopoverButton<PopoverContent: View>: View {
    let title: String
    let systemImage: String
    @Binding var isPresented: Bool
    var isActive = false
    var variant: NativeControlVariant = .toolbar
    var showsLabelWhenCollapsed = false
    var helpText: String? = nil
    var accessibilityLabel: String? = nil
    var idealPopoverWidth: CGFloat? = nil
    var contentPadding: CGFloat = 14
    var stableWidth: CGFloat? = nil
    var expandsOnHover = true
    var chromePolicy: NativeControlChromePolicy = .bareUntilPressed
    var morphID: String? = nil
    @ViewBuilder let popoverContent: () -> PopoverContent

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var metrics: NativeControlVariantMetrics {
        NativeControlSystem.metrics(for: variant)
    }

    private var showsExpandedContent: Bool {
        showsLabelWhenCollapsed || isPresented || isActive || (expandsOnHover && isHovered)
    }

    private var minimumControlWidth: CGFloat {
        guard showsExpandedContent, let stableWidth else { return metrics.minHitWidth }
        return max(metrics.minHitWidth, stableWidth)
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: NativeControlSystem.animation.popoverDuration)) {
                isPresented.toggle()
            }
        } label: {
            HStack(spacing: metrics.labelSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: metrics.iconSize, weight: .semibold))

                if showsExpandedContent {
                    Text(title)
                        .font(.system(size: metrics.fontSize, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: max(metrics.iconSize - 3, 9), weight: .bold))
                    .foregroundStyle(ui.theme.textTertiary)
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
            .padding(.horizontal, showsExpandedContent ? metrics.horizontalPadding.upperBound : metrics.horizontalPadding.lowerBound)
            .frame(minWidth: minimumControlWidth, alignment: .leading)
        }
        .buttonStyle(
            NativeCapsuleButtonStyle(
                theme: ui.theme,
                variant: variant,
                role: .disclosure,
                isActive: isPresented || isActive,
                chromePolicy: chromePolicy,
                morphID: morphID
            )
        )
        .toolbarMorphItem(
            id: morphID,
            isActive: isPresented || isActive,
            revealProgress: showsExpandedContent ? 1 : 0
        )
        .help(helpText ?? title)
        .accessibilityLabel(accessibilityLabel ?? title)
        .animation(.easeInOut(duration: NativeControlSystem.animation.expansionDuration), value: showsExpandedContent)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: NativeControlSystem.animation.hoverDuration)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            popoverContent()
                .padding(contentPadding)
                .frame(
                    minWidth: NativeControlSystem.popoverWidthRange(for: variant).lowerBound,
                    idealWidth: idealPopoverWidth
                        ?? (NativeControlSystem.popoverWidthRange(for: variant).lowerBound
                            + NativeControlSystem.popoverWidthRange(for: variant).upperBound) / 2,
                    maxWidth: NativeControlSystem.popoverWidthRange(for: variant).upperBound,
                    alignment: .leading
                )
                .preferredColorScheme(ui.theme.colorScheme)
        }
    }
}

struct NativeToolbarToggle: View {
    let title: String
    var systemImage: String? = nil
    @Binding var isOn: Bool
    var variant: NativeControlVariant = .toolbar

    private var controlSize: ControlSize {
        switch variant {
        case .toolbar: .mini
        case .content: .small
        }
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: NativeControlSystem.metrics(for: variant).labelSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .toggleStyle(.switch)
        .controlSize(controlSize)
    }
}

// MARK: - Native Button Styles
// Three reusable ButtonStyles that encapsulate hover state internally.
// Replace the pattern of @State isHovered + .onHover + manual backgrounds.

/// Plain SF Symbol button. No background at rest, subtle highlight on press.
/// Used for: toolbar actions, message toolbar, settings icon buttons.
struct NativeToolbarButtonStyle: ButtonStyle {
    var chromePolicy: NativeControlChromePolicy = .bareUntilPressed
    var isActive = false

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let showsSurface = chromePolicy.showsSurface(
            isHovered: isHovered,
            isPressed: configuration.isPressed,
            isActive: isActive
        )
        configuration.label
            .foregroundStyle(isHovered || configuration.isPressed ? .primary : .secondary)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(showsSurface ? Color.primary.opacity(configuration.isPressed ? 0.08 : 0.06) : .clear)
            )
            .shadow(
                color: .black.opacity(showsSurface ? 0.06 : 0),
                radius: showsSurface ? 4 : 0,
                y: showsSurface ? 2 : 0
            )
            .animation(Motion.sharp, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Themed variant that uses EpistemosTheme colors.
struct ThemedToolbarButtonStyle: ButtonStyle {
    let theme: EpistemosTheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isHovered || configuration.isPressed ? theme.accent : theme.accent.opacity(0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? theme.accent.opacity(0.1) : .clear)
            )
            .animation(Motion.micro, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
            .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Capsule pill button. Outline at rest, filled when active or hovered.
/// Used for: nav pills, filter chips, tag chips, toggle buttons.
struct NativePillButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .primary

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? activeColor : (isHovered ? .primary : .secondary))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background {
                if isActive {
                    Capsule()
                        .fill(activeColor.opacity(0.12))
                } else if isHovered {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                } else {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Motion.micro, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// Rounded rect card button. Subtle background fill on hover.
/// Used for: list items, sidebar items, cards, command palette rows.
struct NativeCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isHovered || configuration.isPressed
                            ? Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04)
                            : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.04 : 0), radius: isHovered ? 3 : 0, y: 1)
            .animation(Motion.sharp, value: configuration.isPressed)
            .animation(Motion.micro, value: isHovered)
            .onHover { isHovered = $0 }
    }
}
