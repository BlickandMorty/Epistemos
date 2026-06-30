import SwiftUI

// Phase 1 (Step 5) — native Agent navigation rail.
//
// Part of the native FIXED FRAME (owner charter): a native rail listing Goose's stable route
// CATEGORIES; selecting one points the embedded GooseWebSurfaceView at that route's web hash. This is
// navigation STRUCTURE only — the actual providers/models/skills/recipes/etc. remain live-enumerated
// inside the WebView (GOLDEN RULE: no inventory is hardcoded here, only the fixed destination map).

nonisolated enum AgentRailDestination: String, CaseIterable, Identifiable, Sendable {
    case hub
    case sessions
    case settings
    case models
    case providers
    case skills
    case recipes
    case extensions
    case scheduler
    case apps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hub: return "Chat"
        case .sessions: return "Sessions"
        case .settings: return "Settings"
        case .models: return "Models"
        case .providers: return "Providers"
        case .skills: return "Skills"
        case .recipes: return "Recipes"
        case .extensions: return "Extensions"
        case .scheduler: return "Scheduler"
        case .apps: return "Apps"
        }
    }

    var systemImage: String {
        switch self {
        case .hub: return "bubble.left.and.bubble.right"
        case .sessions: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        case .models: return "slider.horizontal.3"
        case .providers: return "key"
        case .skills: return "wand.and.stars"
        case .recipes: return "list.bullet.rectangle"
        case .extensions: return "puzzlepiece.extension"
        case .scheduler: return "calendar"
        case .apps: return "square.grid.2x2"
        }
    }

    /// The Goose web SPA hash route this destination points the embedded WebView at (the oracle).
    var webRoute: String {
        switch self {
        case .hub: return "/?"
        case .sessions: return "/sessions"
        case .settings: return "/settings"
        case .models: return "/settings?section=models"
        case .providers: return "/configure-providers"
        case .skills: return "/skills"
        case .recipes: return "/recipes"
        case .extensions: return "/extensions"
        case .scheduler: return "/schedules"
        case .apps: return "/apps"
        }
    }
}

private struct AgentRailSection: Identifiable {
    let id: String
    let title: String
    let destinations: [AgentRailDestination]

    static let all: [AgentRailSection] = [
        AgentRailSection(id: "primary", title: "Goose", destinations: [.hub, .sessions]),
        AgentRailSection(id: "configure", title: "Configure", destinations: [.models, .providers, .settings]),
        AgentRailSection(id: "tools", title: "Tools", destinations: [.skills, .recipes, .extensions, .scheduler, .apps]),
    ]
}

@MainActor
struct AgentNavigationRailView: View {
    @Binding var selection: AgentRailDestination
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            railHeader

            ForEach(AgentRailSection.all) { section in
                VStack(alignment: .leading, spacing: 5) {
                    Text(section.title)
                        .font(GooseSurfaceStyle.captionFont(10, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 1)
                    ForEach(section.destinations) { destination in
                        AgentRailRowView(
                            destination: destination,
                            isSelected: destination == selection,
                            theme: theme
                        ) {
                            withAnimation(.smooth(duration: 0.18)) {
                                selection = destination
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            railFooter
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
        .frame(width: 216)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(railBackground)
    }

    private var railHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.20 : 0.12))
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Epistemos")
                    .font(GooseSurfaceStyle.captionFont(11, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                Text("Goose")
                    .font(GooseSurfaceStyle.bodyFont(16, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var railFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(theme.resolved.accent.color)
                .frame(width: 6, height: 6)
            Text(selection.title)
                .font(GooseSurfaceStyle.captionFont(11, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.055 : 0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.36 : 0.44), lineWidth: 0.6)
        }
    }

    private var railBackground: some View {
        ZStack {
            if theme.isDark {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                Rectangle().fill(.regularMaterial)
            }
            GooseSurfaceStyle.background(for: theme, role: .rail)
                .opacity(theme.isDark ? 0.84 : 0.78)
            LinearGradient(
                colors: [
                    Color.white.opacity(theme.isDark ? 0.04 : 0.26),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

@MainActor
private struct AgentRailRowView: View {
    let destination: AgentRailDestination
    let isSelected: Bool
    let theme: EpistemosTheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)
                Text(destination.title)
                    .font(GooseSurfaceStyle.bodyFont(13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(rowForeground)
        .background(rowBackground)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(destination.title)
    }

    private var rowForeground: Color {
        if isSelected {
            return theme.resolved.accent.color
        }
        if isHovered {
            return theme.resolved.foreground.color
        }
        return theme.mutedForeground
    }

    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            if isSelected {
                shape
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11))
                shape
                    .strokeBorder(theme.resolved.accent.color.opacity(theme.isDark ? 0.25 : 0.16), lineWidth: 0.7)
            } else if isHovered {
                shape
                    .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.07 : 0.045))
            }
        }
    }
}
