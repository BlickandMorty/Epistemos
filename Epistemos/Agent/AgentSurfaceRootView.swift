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
        HStack(spacing: 0) {
            AgentNavigationRailView(selection: $selection, theme: theme)
            Divider().overlay(theme.border.opacity(0.5))
            GooseWebSurfaceView(theme: theme, route: selection.webRoute)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
