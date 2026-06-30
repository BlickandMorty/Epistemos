import SwiftUI

// Phase 1 (Step 5) — native Agent navigation rail.
//
// Part of the native FIXED FRAME (owner charter): a native rail listing Goose's stable route
// CATEGORIES; selecting one points the embedded GooseWebSurfaceView at that route's web hash. This is
// navigation STRUCTURE only — the actual providers/models/skills/recipes/etc. remain live-enumerated
// inside the WebView (GOLDEN RULE: no inventory is hardcoded here, only the fixed destination map).

nonisolated enum AgentRailDestination: String, CaseIterable, Identifiable, Sendable {
    case hub
    case launcher
    case sessions
    case settings
    case models
    case providers
    case permission
    case skills
    case recipes
    case extensions
    case scheduler
    case apps

    var id: String { rawValue }

    static let launcherDestinations: [AgentRailDestination] = [
        .hub,
        .sessions,
        .models,
        .providers,
        .permission,
        .settings,
        .skills,
        .recipes,
        .extensions,
        .scheduler,
        .apps,
    ]

    var title: String {
        switch self {
        case .hub: return "Chat"
        case .launcher: return "Launcher"
        case .sessions: return "Sessions"
        case .settings: return "Settings"
        case .models: return "Models"
        case .providers: return "Providers"
        case .permission: return "Tool rules"
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
        case .launcher: return "sparkles.rectangle.stack"
        case .sessions: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        case .models: return "slider.horizontal.3"
        case .providers: return "key"
        case .permission: return "checkmark.shield"
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
        case .launcher: return "/launcher"
        case .sessions: return "/sessions"
        case .settings: return "/settings"
        case .models: return "/settings?section=models"
        case .providers: return "/configure-providers"
        case .permission: return "/permission"
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
        AgentRailSection(id: "primary", title: "Goose", destinations: [.hub, .launcher, .sessions]),
        AgentRailSection(id: "configure", title: "Configure", destinations: [.models, .providers, .permission, .settings]),
        AgentRailSection(id: "tools", title: "Tools", destinations: [.skills, .recipes, .extensions, .scheduler, .apps]),
    ]
}

@MainActor
struct AgentNavigationRailView: View {
    @Binding var selection: AgentRailDestination
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            railHeader

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(AgentRailSection.all) { section in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(section.title)
                                .font(GooseSurfaceStyle.captionFont(10, weight: .medium))
                                .foregroundStyle(theme.textTertiary)
                                .padding(.horizontal, 12)
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
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: 0)

            railFooter
        }
        .padding(.top, 12)
        .padding(.horizontal, 9)
        .padding(.bottom, 12)
        .frame(width: 198)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            railBackground
                .clipShape(railShape)
        }
        .overlay {
            railShape
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.42 : 0.58), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 10)
    }

    private var railHeader: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11))
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Epistemos agent")
                    .font(GooseSurfaceStyle.captionFont(10, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                Text("Goose")
                    .font(GooseSurfaceStyle.bodyFont(15, weight: .semibold))
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
            Text("Viewing \(selection.title)")
                .font(GooseSurfaceStyle.captionFont(10, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.052 : 0.032))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.36 : 0.44), lineWidth: 0.6)
        }
    }

    private var railShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    private var railBackground: some View {
        ZStack {
            if theme.isDark {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                Rectangle().fill(.regularMaterial)
            }
            GooseSurfaceStyle.background(for: theme, role: .rail)
                .opacity(theme.isDark ? 0.78 : 0.66)
            LinearGradient(
                colors: [
                    Color.white.opacity(theme.isDark ? 0.05 : 0.24),
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
                Capsule(style: .continuous)
                    .fill(isSelected ? theme.resolved.accent.color : Color.clear)
                    .frame(width: 3, height: 16)
                Image(systemName: destination.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)
                Text(destination.title)
                    .font(GooseSurfaceStyle.bodyFont(13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 33)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(rowForeground)
        .background(rowBackground)
        .animation(.smooth(duration: 0.18), value: isSelected)
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
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return ZStack {
            if isSelected {
                shape
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.15 : 0.09))
                shape
                    .strokeBorder(theme.resolved.accent.color.opacity(theme.isDark ? 0.23 : 0.14), lineWidth: 0.7)
            } else if isHovered {
                shape
                    .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.066 : 0.04))
            }
        }
    }
}
