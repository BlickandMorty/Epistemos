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
                        Text(title)
                            .font(.epTitle)
                            .foregroundStyle(theme.foreground)

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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)
                .tracking(0.6)

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
