import SwiftUI

// Phase 1 (Step 5) — native Agent shell root: FIXED native frame = nav rail + content slot.
//
// Per the owner charter (2026-06-27) / loop directive, NATIVE = FIXED frame only: the window
// (AgentSurfaceWindowController) + this native nav rail. The content slot hosts Goose's reskinned
// WebView — chat, providers, settings, sessions, skills, recipes, extensions, scheduler, apps, and
// every other Goose feature STAY in the WebView (no native reimplementation). The rail selection
// drives the embedded WebView's route; the SPA still owns its content. Permission / elicitation
// pop-ups are already native (forwarded by the WebView's GooseWebNativePromptBridge).

@MainActor
struct AgentSurfaceRootView: View {
    let theme: EpistemosTheme

    @State private var selection: AgentRailDestination = .hub

    var body: some View {
        ZStack {
            GooseSurfaceStyle.background(for: theme)
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    theme.resolved.accent.color.opacity(theme.isDark ? 0.10 : 0.07),
                    Color.clear,
                    theme.resolved.foreground.color.opacity(theme.isDark ? 0.04 : 0.025),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                AgentNavigationRailView(selection: $selection, theme: theme)
                contentDivider
                webContent
            }
            .padding(.top, 38)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        theme.glassBorder.opacity(theme.isDark ? 0.58 : 0.72),
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
            .padding(.vertical, 12)
            .padding(.trailing, 10)
    }

    private var webContent: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return GooseWebSurfaceView(theme: theme, route: selection.webRoute)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GooseSurfaceStyle.background(for: theme, role: .content))
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.58 : 0.76), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.22 : 0.10), radius: 18, x: 0, y: 10)
    }
}
