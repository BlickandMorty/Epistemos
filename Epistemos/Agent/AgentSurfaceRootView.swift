import SwiftUI

// Phase 1 — native Agent shell root.
//
// Per the owner charter (2026-06-27) and the loop directive, NATIVE = FIXED FRAME ONLY: the window
// (AgentSurfaceWindowController) + (Step 5) a native nav rail. The content slot hosts Goose's
// reskinned WebView — chat, providers, settings, sessions, skills, recipes, extensions, scheduler,
// and every other Goose feature STAY in the WebView. No Goose feature is reimplemented natively.
//
// This MVP mounts the WebView content slot; Step 5 adds AgentNavigationRailView on the leading edge
// to drive route navigation within this same window. Permission / elicitation pop-ups are already
// native (forwarded by the WebView's GooseWebNativePromptBridge).

@MainActor
struct AgentSurfaceRootView: View {
    let theme: EpistemosTheme

    var body: some View {
        GooseWebSurfaceView(theme: theme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
