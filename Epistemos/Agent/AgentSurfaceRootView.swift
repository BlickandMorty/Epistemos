import SwiftUI

// Phase 1 — native Agent window frame with Goose as the primary UI.
//
// Keep the native shell out of Goose's navigation path: the embedded Goose WebView owns chat,
// settings, sessions, skills, recipes, extensions, scheduler, apps, and its own sidebar. The native
// app still owns the macOS window and native permission / elicitation pop-ups forwarded by the
// WebView bridge, but it does not stack a second route rail around Goose.

@MainActor
struct AgentSurfaceRootView: View {
    let theme: EpistemosTheme

    var body: some View {
        GooseWebSurfaceView(theme: theme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }
}
