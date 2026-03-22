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

enum NativeControlSystem {
    static let toolbar = NativeControlVariantMetrics(
        height: 26,
        cornerRadius: 8,
        horizontalPadding: 7...9,
        iconSize: 12,
        labelSpacing: 5,
        fontSize: 12.5,
        minHitWidth: 26,
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

    static func metrics(for variant: NativeControlVariant) -> NativeControlVariantMetrics {
        switch variant {
        case .toolbar: toolbar
        case .content: content
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
                return theme.accent.opacity(theme.isDark ? 0.14 : 0.08)
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
            return theme.accent.opacity(theme.isDark ? 0.16 : 0.10)
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
}

private struct NativeCapsuleButtonStyle: ButtonStyle {
    let theme: EpistemosTheme
    let variant: NativeControlVariant
    let role: NativeControlRole
    let isActive: Bool
    let chromePolicy: NativeControlChromePolicy

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let metrics = NativeControlSystem.metrics(for: variant)
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        let showsSurface = chromePolicy.showsSurface(
            isHovered: isHovered,
            isPressed: configuration.isPressed,
            isActive: isActive
        )

        configuration.label
            .frame(minHeight: metrics.height)
            .foregroundStyle(
                NativeControlPalette.foreground(
                    theme: theme,
                    role: role,
                    isActive: isActive,
                    isHovered: isHovered,
                    isEnabled: isEnabled
                )
            )
            .background {
                if showsSurface {
                    shape
                        .fill(
                            NativeControlPalette.fill(
                                theme: theme,
                                role: role,
                                isActive: isActive,
                                isHovered: isHovered,
                                isPressed: configuration.isPressed
                            )
                        )
                        .overlay {
                            shape.strokeBorder(
                                NativeControlPalette.stroke(
                                    theme: theme,
                                    role: role,
                                    isActive: isActive,
                                    isHovered: isHovered
                                ),
                                lineWidth: 0.55
                            )
                        }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.988 : 1.0)
            .shadow(
                color: .black.opacity(showsSurface ? (isActive ? 0.035 : 0.02) : 0),
                radius: isActive ? 4 : 3,
                y: 1
            )
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
            .opacity(isEnabled ? 1 : 0.48)
    }
}

// MARK: - Native Button Styles
// Three reusable ButtonStyles that encapsulate hover state internally.
// Replace the pattern of @State isHovered + .onHover + manual backgrounds.

/// Plain SF Symbol button. No background at rest, subtle highlight on press.
/// Used for: toolbar actions, message toolbar, settings icon buttons.
struct NativeToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered || configuration.isPressed ? .primary : .secondary)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .shadow(color: .black.opacity(isHovered ? 0.06 : 0), radius: isHovered ? 4 : 0, y: 2)
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

struct ToolbarCapsuleButton: View {
    let title: String?
    let systemImage: String
    var variant: NativeControlVariant = .toolbar
    var role: NativeControlRole = .toolbarUtility
    var isActive = false
    var chromePolicy: NativeControlChromePolicy = .bareUntilPressed
    var helpText: String? = nil
    var accessibilityLabel: String? = nil
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
            .padding(
                .horizontal,
                title == nil ? metrics.horizontalPadding.lowerBound : metrics.horizontalPadding.upperBound
            )
            .frame(minWidth: metrics.minHitWidth)
        }
        .buttonStyle(
            NativeCapsuleButtonStyle(
                theme: ui.theme,
                variant: variant,
                role: role,
                isActive: isActive,
                chromePolicy: chromePolicy
            )
        )
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
    var stableWidth: CGFloat? = nil
    var expandsOnHover = true
    var chromePolicy: NativeControlChromePolicy = .bareUntilPressed
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var metrics: NativeControlVariantMetrics {
        NativeControlSystem.metrics(for: variant)
    }

    private var currentTitle: String {
        isActive ? (activeTitle ?? title) : title
    }

    private var showsExpandedContent: Bool {
        isActive || (expandsOnHover && isHovered)
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
            }
            .padding(
                .horizontal,
                showsExpandedContent
                    ? metrics.horizontalPadding.upperBound
                    : metrics.horizontalPadding.lowerBound
            )
            .frame(minWidth: minimumControlWidth, alignment: .leading)
        }
        .buttonStyle(
            NativeCapsuleButtonStyle(
                theme: ui.theme,
                variant: variant,
                role: .mode,
                isActive: isActive,
                chromePolicy: chromePolicy
            )
        )
        .help(helpText ?? currentTitle)
        .accessibilityLabel(accessibilityLabel ?? currentTitle)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .animation(.easeInOut(duration: 0.18), value: showsExpandedContent)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
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
            withAnimation(.easeInOut(duration: 0.16)) {
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
            .padding(
                .horizontal,
                showsExpandedContent
                    ? metrics.horizontalPadding.upperBound
                    : metrics.horizontalPadding.lowerBound
            )
            .frame(minWidth: minimumControlWidth, alignment: .leading)
        }
        .buttonStyle(
            NativeCapsuleButtonStyle(
                theme: ui.theme,
                variant: variant,
                role: .disclosure,
                isActive: isPresented || isActive,
                chromePolicy: chromePolicy
            )
        )
        .help(helpText ?? title)
        .accessibilityLabel(accessibilityLabel ?? title)
        .animation(.easeInOut(duration: 0.18), value: showsExpandedContent)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            popoverContent()
                .padding(contentPadding)
                .frame(
                    minWidth: variant == .toolbar ? 220 : 240,
                    idealWidth: idealPopoverWidth ?? (variant == .toolbar ? 280 : 300),
                    maxWidth: variant == .toolbar ? 360 : 340,
                    alignment: .leading
                )
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }
}
