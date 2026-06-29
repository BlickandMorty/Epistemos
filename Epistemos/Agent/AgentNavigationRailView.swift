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
        case .providers: return "/configure-providers"
        case .skills: return "/skills"
        case .recipes: return "/recipes"
        case .extensions: return "/extensions"
        case .scheduler: return "/schedules"
        case .apps: return "/apps"
        }
    }
}

@MainActor
struct AgentNavigationRailView: View {
    @Binding var selection: AgentRailDestination
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(AgentRailDestination.allCases) { destination in
                railRow(destination)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(width: 188)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(GooseSurfaceStyle.background(for: theme, role: .rail))
    }

    @ViewBuilder
    private func railRow(_ destination: AgentRailDestination) -> some View {
        let isSelected = destination == selection
        Button { selection = destination } label: {
            HStack(spacing: 9) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(destination.title)
                    .font(GooseSurfaceStyle.bodyFont(12, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? theme.resolved.accent.color : theme.resolved.foreground.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? theme.resolved.accent.color.opacity(0.14) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
