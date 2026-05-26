import SwiftUI

struct SettingsSurfaceCard<Content: View>: View {
    @Environment(UIState.self) private var ui
    private let content: Content
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .settingsAppleCardChrome(theme: theme, accent: theme.resolved.accent.color)
    }
}

struct SettingsDisclosureSection<Content: View>: View {
    @Environment(UIState.self) private var ui
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding private var isExpanded: Bool
    private let content: Content
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(.top, 8)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12))
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.resolved.accent.color)
                    }
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct SettingsThemedBlurBackdrop: View {
    enum Role {
        case page
        case sidebar
        case card

        func baseOpacity(isDark: Bool) -> Double {
            switch self {
            case .page:
                isDark ? 0.72 : 0.66
            case .sidebar:
                isDark ? 0.78 : 0.72
            case .card:
                isDark ? 0.84 : 0.80
            }
        }

        func materialOpacity(isDark: Bool) -> Double {
            switch self {
            case .page:
                isDark ? 0.40 : 0.34
            case .sidebar:
                isDark ? 0.46 : 0.38
            case .card:
                isDark ? 0.52 : 0.46
            }
        }

        func accentOpacity(isDark: Bool) -> Double {
            switch self {
            case .page:
                isDark ? 0.030 : 0.035
            case .sidebar:
                isDark ? 0.040 : 0.045
            case .card:
                isDark ? 0.055 : 0.060
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .page, .sidebar:
                0
            case .card:
                8
            }
        }
    }

    let theme: EpistemosTheme
    let role: Role

    var body: some View {
        RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
            .fill(theme.resolved.background.color.opacity(role.baseOpacity(isDark: theme.isDark)))
            .background {
                RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
                    .fill(theme.resolved.background.color.opacity(role.materialOpacity(isDark: theme.isDark)))
                    .background(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(role.accentOpacity(isDark: theme.isDark)))
            }
            .overlay {
                if theme.usesNativeWindowBlur {
                    RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
                        .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.035 : 0.028))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous))
                }
            }
    }
}

struct SettingsAppleCardChrome: ViewModifier {
    let theme: EpistemosTheme
    let accent: Color

    func body(content: Content) -> some View {
        content
            .background {
                SettingsThemedBlurBackdrop(theme: theme, role: .card)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        theme.border.opacity(theme.isDark ? 0.24 : 0.30),
                        lineWidth: theme.isDark ? 0.6 : 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.24 : 0.10),
                radius: theme.isDark ? 14 : 18,
                x: 0,
                y: theme.isDark ? 7 : 9
            )
    }
}

struct SettingsFeaturedPixelPanel<Content: View>: View {
    let theme: EpistemosTheme
    private let content: Content

    init(theme: EpistemosTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .pixelPanel(theme: theme)
    }
}

struct SettingsPixelGlyphBadge: View {
    let systemImage: String
    let theme: EpistemosTheme
    var tint: Color?
    var size: CGFloat = 18

    private var resolvedTint: Color {
        tint ?? theme.resolved.accent.color
    }

    var body: some View {
        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.70, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(resolvedTint)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    pixel(opacity: 0.34)
                    Spacer(minLength: 0)
                    pixel(opacity: 0.58)
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    pixel(opacity: 0.42)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func pixel(opacity: Double) -> some View {
        Rectangle()
            .fill(resolvedTint.opacity(theme.isDark ? opacity * 0.78 : opacity))
            .frame(width: 3, height: 3)
    }
}

struct SettingsBlurGroupBoxStyle: GroupBoxStyle {
    let theme: EpistemosTheme

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background {
            SettingsThemedBlurBackdrop(theme: theme, role: .card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    theme.border.opacity(theme.isDark ? 0.20 : 0.26),
                    lineWidth: theme.isDark ? 0.6 : 0.8
                )
        }
    }
}

extension View {
    func settingsAppleCardChrome(theme: EpistemosTheme, accent: Color) -> some View {
        modifier(SettingsAppleCardChrome(theme: theme, accent: accent))
    }

    func settingsThemedBlurPage(theme: EpistemosTheme) -> some View {
        scrollContentBackground(.hidden)
            .groupBoxStyle(SettingsBlurGroupBoxStyle(theme: theme))
            .background {
                SettingsThemedBlurBackdrop(theme: theme, role: .page)
                    .ignoresSafeArea()
            }
    }
}

struct ChannelStatusPill: View {
    @Environment(UIState.self) private var ui
    let title: String
    let tint: Color
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(theme.isDark ? 0.14 : 0.10))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(tint.opacity(theme.isDark ? 0.24 : 0.34), lineWidth: theme.isDark ? 0.75 : 1)
            }
    }
}

struct VerifiedFloorChipStrip: View {
    let flag: String
    let substrate: String
    let substrateTint: Color
    let falsifier: String?

    init(
        flag: String,
        substrate: String,
        substrateTint: Color,
        falsifier: String? = nil
    ) {
        self.flag = flag
        self.substrate = substrate
        self.substrateTint = substrateTint
        self.falsifier = falsifier
    }

    private var flagTint: Color {
        switch flag {
        case "on":
            .green
        case "off":
            .red
        default:
            .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ChannelStatusPill(title: "Flag: \(flag)", tint: flagTint)
            ChannelStatusPill(title: "Substrate: \(substrate)", tint: substrateTint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .help(helpText)
    }

    private var helpText: String {
        if let falsifier, !falsifier.isEmpty {
            return "What's wired today / what's still stub / falsifier: artifacts/falsifiers/\(falsifier)/result.json."
        }
        return "What's wired today / what's still stub / no production falsifier is attached to this chip strip."
    }
}
