import SwiftUI

// MARK: - Page Shell
// Reusable page container matching v2's PageShell pattern.
// Icon + title + subtitle + scroll content.

struct PageShell<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    @Environment(UIState.self) private var ui

    init(icon: String, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(theme.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        TypewriterHeading(
                            text: title,
                            role: .pageTitle,
                            color: theme.fontAccent
                        )

                        if let subtitle {
                            Text(subtitle)
                                .font(.epCaption)
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
                .padding(.top, Spacing.xxl)

                // Content
                content
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TypewriterHeading: View {
    let text: String
    let role: AppHeadingRole
    let color: Color
    var animateOnAppear: Bool? = nil
    var animationKey: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui
    @State private var displayText = ""
    @State private var cursorVisible = false
    @State private var animationRun = 0

    private var taskID: String {
        "\(animationKey ?? text)|\(reduceMotion)|\(animationRun)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Text(displayText)
                .font(role.font)
                .foregroundStyle(color)

            if cursorVisible {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color.opacity(0.85))
                    .frame(width: 3, height: max(12, role.fontSize * 0.82))
                    .transition(.opacity)
            }
        }
        .onAppear {
            animationRun += 1
        }
        .onChange(of: text) { _, newText in
            guard animationKey != nil else { return }
            displayText = newText
        }
        .task(id: taskID) {
            await animateIfNeeded()
        }
    }

    @MainActor
    private func animateIfNeeded() async {
        let shouldAnimate = animateOnAppear ?? role.animatesOnFirstAppearance
        guard shouldAnimate, !reduceMotion, !ui.displayMode.reducesASCIIAnimations else {
            displayText = text
            cursorVisible = false
            return
        }

        displayText = ""
        cursorVisible = true
        try? await Task.sleep(for: .milliseconds(50))

        for character in text {
            guard !Task.isCancelled else { return }
            displayText.append(character)
            try? await Task.sleep(for: .milliseconds(25))
        }

        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .milliseconds(500))
        cursorVisible = false
    }
}

struct AccentTitleBar: View {
    let title: String
    let icon: String?
    var role: AppHeadingRole = .pageTitle
    var animateOnAppear = true

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: role == .pageTitle ? 16 : 14, weight: .medium))
                    .foregroundStyle(theme.fontAccent.opacity(0.88))
            }

            TypewriterHeading(
                text: title,
                role: role,
                color: theme.fontAccent,
                animateOnAppear: animateOnAppear
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    theme.fontAccent.opacity(theme.isDark ? 0.20 : 0.14),
                    theme.fontAccent.opacity(theme.isDark ? 0.08 : 0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.fontAccent.opacity(theme.isDark ? 0.30 : 0.24))
                .frame(height: 1)
        }
    }
}

// MARK: - Glass Section
// Titled section with glass background. Used across Analytics, Research, Library.

struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(AppHeadingRole.section.font)
                .foregroundStyle(theme.fontAccent)
                .textCase(.uppercase)
                .tracking(AppHeadingRole.section.tracking)

            content
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 14)
    }
}

// MARK: - Research Tab Bar
// Generic glass pill tab bar used by Library, Research, Analytics.

struct ResearchTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var active: Tab
    let icon: (Tab) -> String
    let label: (Tab) -> String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                TabPill(
                    icon: icon(tab),
                    label: label(tab),
                    isActive: active == tab
                ) {
                    withAnimation(Motion.quick) { active = tab }
                }
            }
        }
        .padding(3)
        .hoverGlassCapsule(flatBackground: theme.card)
    }
}

private struct TabPill: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? theme.accent : (isHovered ? theme.foreground : theme.mutedForeground))
            .background {
                if isActive {
                    Capsule()
                        .fill(theme.accent.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contentShape(Capsule())
    }
}

// MARK: - Flow Layout
// Reusable flow layout for concept badges and tags.

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .init(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
