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
                    theme.resolved.accent.color.opacity(theme.isDark ? 0.08 : 0.055),
                    Color.clear,
                    theme.resolved.foreground.color.opacity(theme.isDark ? 0.032 : 0.018),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 12) {
                AgentNavigationRailView(selection: $selection, theme: theme)
                webContent
            }
            .padding(.top, 38)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var webContent: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return GooseWebSurfaceView(theme: theme, route: selection.webRoute)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    shape.fill(theme.isDark ? .ultraThinMaterial : .regularMaterial)
                    shape.fill(GooseSurfaceStyle.background(for: theme, role: .content).opacity(theme.isDark ? 0.82 : 0.70))
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.045 : 0.24),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.52 : 0.66), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.24 : 0.11), radius: 24, x: 0, y: 14)
    }
}
