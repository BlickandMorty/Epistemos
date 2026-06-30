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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .settingsAppleCardChrome(theme: theme, accent: theme.resolved.accent.color)
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
                isDark ? 0.82 : 0.78
            case .sidebar:
                isDark ? 0.84 : 0.80
            case .card:
                isDark ? 0.86 : 0.88
            }
        }

        func materialOpacity(isDark: Bool) -> Double {
            switch self {
            case .page:
                isDark ? 0.16 : 0.12
            case .sidebar:
                isDark ? 0.18 : 0.14
            case .card:
                isDark ? 0.08 : 0.06
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
                4
            }
        }
    }

    let theme: EpistemosTheme
    let role: Role

    private var surfaceColor: Color {
        role == .card
            ? theme.resolved.card.color
            : theme.resolved.background.color
    }

    var body: some View {
        RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
            .fill(surfaceColor.opacity(role.baseOpacity(isDark: theme.isDark)))
            .background {
                RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
                    .fill(surfaceColor.opacity(role.materialOpacity(isDark: theme.isDark)))
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
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        theme.border.opacity(theme.isDark ? 0.28 : 0.24),
                        lineWidth: theme.isDark ? 0.7 : 0.8
                    )
            }
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

struct SettingsDisclosureSection<Content: View>: View {
    @Environment(UIState.self) private var ui
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
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
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                SettingsPixelGlyphBadge(
                    systemImage: systemImage,
                    theme: theme,
                    tint: theme.resolved.accent.color,
                    size: 18
                )
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .settingsAppleCardChrome(theme: theme, accent: theme.resolved.accent.color)
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
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(resolvedTint.opacity(theme.isDark ? 0.16 : 0.12))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(resolvedTint.opacity(theme.isDark ? 0.22 : 0.18), lineWidth: 0.55)

            Image(systemName: systemImage)
                .font(.system(size: size * 0.70, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(resolvedTint)

            HStack {
                Spacer(minLength: 0)
                VStack {
                    Spacer(minLength: 0)
                    pixel(opacity: 0.34)
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

struct SettingsIntegrationBrandBadge: View {
    let brand: IntegrationBrand
    let theme: EpistemosTheme
    var tint: Color?
    var size: CGFloat = 18

    private var resolvedTint: Color {
        tint ?? theme.resolved.accent.color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(resolvedTint.opacity(theme.isDark ? 0.16 : 0.12))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(resolvedTint.opacity(theme.isDark ? 0.22 : 0.18), lineWidth: 0.55)

            IntegrationBrandMarkView(brand: brand, size: size * 0.70)
                .foregroundStyle(resolvedTint)

            HStack {
                Spacer(minLength: 0)
                VStack {
                    Spacer(minLength: 0)
                    pixel(opacity: 0.34)
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
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(
                    theme.border.opacity(theme.isDark ? 0.28 : 0.32),
                    lineWidth: theme.isDark ? 0.75 : 0.9
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

nonisolated enum VerifiedFloorLiveBacking: String, Equatable, Sendable {
    case none
    case ledger
    case dag
}

nonisolated enum VerifiedFloorArtifactBackingPolicy {
    static func isSatisfied(
        path: String,
        fileManager: FileManager = .default
    ) -> Bool {
        guard !path.isEmpty,
              (try? fileManager.destinationOfSymbolicLink(atPath: path)) == nil else {
            return false
        }

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              fileManager.isReadableFile(atPath: path),
              let type = try? fileManager.attributesOfItem(atPath: path)[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }
}

nonisolated struct VerifiedFloorChipEligibility: Equatable, Sendable {
    let productionWired: Bool
    let falsifierPassed: Bool
    let artifactSatisfied: Bool
    let liveBackingSatisfied: Bool

    var greenEligible: Bool {
        productionWired && falsifierPassed && artifactSatisfied && liveBackingSatisfied
    }

    var witnessLabel: String {
        if !artifactSatisfied { return "no artifact" }
        if !liveBackingSatisfied { return "empty" }
        return falsifierPassed ? "PASS" : "pending"
    }
}

struct VerifiedFloorChipStrip: View {
    let flag: String
    let substrate: String
    let productionWired: Bool
    let falsifierPassed: Bool
    let falsifier: String
    let wiredToday: String
    let stillStub: String
    let requiresArtifactAtPath: String?
    let requiresLiveBacking: VerifiedFloorLiveBacking

    init(
        flag: String,
        substrate: String,
        productionWired: Bool,
        falsifierPassed: Bool,
        falsifier: String,
        wiredToday: String,
        stillStub: String,
        requiresArtifactAtPath: String? = nil,
        requiresLiveBacking: VerifiedFloorLiveBacking = .none
    ) {
        self.flag = flag
        self.substrate = substrate
        self.productionWired = productionWired
        self.falsifierPassed = falsifierPassed
        self.falsifier = falsifier
        self.wiredToday = wiredToday
        self.stillStub = stillStub
        self.requiresArtifactAtPath = requiresArtifactAtPath
        self.requiresLiveBacking = requiresLiveBacking
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

    private var eligibility: VerifiedFloorChipEligibility {
        VerifiedFloorChipEligibility(
            productionWired: productionWired,
            falsifierPassed: falsifierPassed,
            artifactSatisfied: artifactSatisfied,
            liveBackingSatisfied: liveBackingSatisfied
        )
    }

    private var greenEligible: Bool {
        eligibility.greenEligible
    }

    private var artifactSatisfied: Bool {
        guard let requiresArtifactAtPath else { return true }
        return VerifiedFloorArtifactBackingPolicy.isSatisfied(path: requiresArtifactAtPath)
    }

    private var liveBackingSatisfied: Bool {
        switch requiresLiveBacking {
        case .none:
            return true
        case .ledger:
            return RustProvenanceLedgerClient.summary().claimCount > 0
        case .dag:
            return RustCognitiveDagClient.stats().nodeCount > 0
        }
    }

    private var substrateTint: Color {
        if greenEligible { return .green }
        return productionWired ? .orange : .secondary
    }

    private var witnessTint: Color {
        if greenEligible { return .green }
        return falsifierPassed ? .orange : .secondary
    }

    private var witnessLabel: String {
        eligibility.witnessLabel
    }

    private var truthTooltip: String {
        [
            "Wired today: \(wiredToday)",
            "Still stub: \(stillStub)",
            "Falsifier: \(falsifier)",
            "Artifact backing: \(requiresArtifactAtPath ?? "not required")",
            "Live backing: \(requiresLiveBacking.rawValue)",
            "Green requires production wiring, primary PASS witness, declared artifact backing, and declared live backing."
        ].joined(separator: "\n")
    }

    var body: some View {
        HStack(spacing: 6) {
            ChannelStatusPill(title: "Flag: \(flag)", tint: flagTint)
            ChannelStatusPill(title: "Substrate: \(substrate)", tint: substrateTint)
            ChannelStatusPill(title: "Witness: \(witnessLabel)", tint: witnessTint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .help(truthTooltip)
        .accessibilityLabel(truthTooltip)
    }
}
