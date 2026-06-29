import SwiftUI

// Phase 1 (Step 3) — native Agent shell root.
//
// Owns the per-window goose serve supervisor + the native chat session controller, and switches
// hub → session canvas on the first prompt. The connection is the SAME shared-server pattern the
// WebView surface uses (its own supervisor instance; a second WS to goose serve, NOT a second spawn
// of the engine beyond the standard per-surface supervisor). Long-tail nav routes (Skills/Recipes/…)
// will mount an embedded GooseWebSurfaceView via the hybrid content router in a later Step-3/5 slice;
// this MVP delivers the native chat loop (hub → session → stream).

@MainActor
struct AgentSurfaceRootView: View {
    let theme: EpistemosTheme

    @State private var supervisor = GooseRuntimeSupervisor()
    @State private var controller = AgentSessionController()
    @State private var secretKey = GooseRuntimeSupervisor.randomSecretKey()
    @State private var didStartSession = false

    var body: some View {
        Group {
            if didStartSession {
                AgentSessionCanvasView(controller: controller, theme: theme)
            } else {
                AgentHubView(theme: theme, isReady: isReady, onSubmit: submit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { supervisor.start(secretKey: secretKey) }
        .onChange(of: supervisor.status) { _, status in
            if case .running(let connection) = status {
                controller.start(connection: connection)
            }
        }
        .onDisappear {
            let controller = controller
            let supervisor = supervisor
            Task { await controller.stop() }
            supervisor.stop()
        }
    }

    private var isReady: Bool {
        switch controller.status {
        case .ready, .streaming: return true
        case .idle, .connecting, .failed: return false
        }
    }

    private func submit(_ text: String) {
        controller.send(text)
        didStartSession = true
    }
}
