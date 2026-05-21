import AppKit
import SwiftData
import SwiftUI

// MARK: - HomeGraphEmbeddedView
//
// Phase 1 (2026-05-20) — embed-in-home graph mode.
//
// Renders the FULL graph experience (Metal canvas + workspace routes +
// search sidebar + node inspector + floating controls + FPS HUD) inline
// inside the home/landing window, replacing the LiquidGreeting whenever:
//
//   - `GraphState.graphViewLocation == .embedded` AND
//   - `UIState.homeContent == .graph`
//
// Both conditions are toggled together by the `Cmd+G` hotkey when the
// user has chosen embedded mode via Settings → Graph → Graph performance.
//
// Why this lives in `Views/Home/` not `Views/Graph/`:
// `Views/Graph/*` is the floating-panel chrome (HologramOverlay-owned
// NSPanels + NSVisualEffectView blur). This view is a pure SwiftUI shell
// that hosts the same chrome views inline inside `LandingView`'s body.
// Naming the directory by its host (Home) keeps the host/content split
// clear: same content, different shell.
//
// ZERO-COPY GUARANTEES:
//   - SwiftUI chrome (GraphFloatingControls, HologramSearchSidebar,
//     HologramNodeInspector, GraphWorkspaceContainer, GraphFPSHUDHostView)
//     is the SAME code used by the floating mini panel. Not forked.
//   - `GraphState` is the singleton — physics, routes, force config,
//     cursor force, FPS measurements all flow through the same instance.
//   - The Metal engine is created per-instance of `MetalGraphNSView`.
//     Because `GraphState.graphViewLocation` picks exactly one mode at a
//     time and the inactive mode is torn down, only one engine is ever
//     allocated + rendering at any moment.
//
// What's TAILORED for the embedded surface:
//   - `theme.background` Color fills the backdrop (NOT NSVisualEffectView).
//     The landing's color shows through directly.
//   - `isOverlayMode = true` on the metal view → Rust engine uses
//     transparent clear color so the SwiftUI Color underneath is visible.
//   - No rounded corner mask (fills the home window's content area).
//   - Top-left "Back" button → returns to greeting via the same Cmd+G
//     toggle, or Esc shortcut.
//
// See `Epistemos/Views/Landing/LandingView.swift` for the content
// router that mounts this view, and `Epistemos/Graph/GraphState.swift`
// for the `GraphViewLocation` enum + persistence.

@MainActor
struct HomeGraphEmbeddedView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(QueryEngine.self) private var queryEngine
    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Inspector state — owned by this view, mirrors HologramOverlay's
    /// pattern. Replays node selection from `graphState.selectedNodeId`
    /// via the standard binding in `HologramNodeInspector`.
    @State private var inspectorState = NodeInspectorState()

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.landing) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. Theme-tinted background — the LANDING color shows through
            //    the Metal canvas's transparent clear color. No blur. We
            //    reuse `AppWindowBackdropStyle.background(for:)` so the
            //    embedded graph's backdrop is byte-identical to what
            //    `LandingView.landingBackdrop` paints when the greeting
            //    is showing. Switching modes feels continuous because
            //    the canvas color never changes — only what sits on top.
            AppWindowBackdropStyle.background(for: theme)
                .ignoresSafeArea()

            // 2. Metal canvas — fills the entire content area, transparent
            //    over the theme background. Hosts its own engine instance.
            MetalGraphRepresentable(
                graphState: graphState,
                isDarkTheme: theme.isDark
            )
            .ignoresSafeArea()

            // 3. Route overlay (note / folder pages). On `.canvas` route
            //    this is hidden so mouse events fall through to the
            //    metal canvas. Same isolation as HologramOverlay.
            if !graphState.currentRoute.isCanvas {
                GraphWorkspaceContainer()
                    .transition(.opacity)
            }

            // 4. Search sidebar — left edge, top-aligned.
            HStack(alignment: .top, spacing: 0) {
                HologramSearchSidebar(
                    inspectorState: inspectorState,
                    modelContext: modelContext,
                    onSelectNode: { nodeId in
                        graphState.selectNode(nodeId)
                    }
                )
                .padding(.leading, 16)
                .padding(.top, 16)
                Spacer(minLength: 0)
            }

            // 5. Inspector — right edge, top-aligned, only when a node
            //    is selected. Matches the floating-panel layout.
            if graphState.selectedNodeId != nil {
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: 0)
                    HologramNodeInspector(
                        inspectorState: inspectorState,
                        modelContext: modelContext
                    )
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // 6. Floating controls capsule — bottom-center.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                GraphFloatingControls()
                    .padding(.bottom, 24)
            }

            // 7. FPS HUD — bottom-trailing. The host view internally
            //    branches on `graphFPSHUDEnabled` so we always mount
            //    it; it draws EmptyView when the toggle is off.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    GraphFPSHUDHostView()
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }

            // 8. Back-to-greeting button — top-leading.
            backButton
                .padding(.leading, 16)
                .padding(.top, 16)
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.25),
            value: graphState.currentRoute
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.25),
            value: graphState.selectedNodeId
        )
        .onKeyPress(.escape) {
            returnToGreeting()
            return .handled
        }
        .onAppear { handleAppear() }
        .onDisappear { handleDisappear() }
    }

    // MARK: - Back affordance

    private var backButton: some View {
        Button(action: returnToGreeting) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Home")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(theme.glassBg.opacity(0.78))
            )
            .overlay(
                Capsule().strokeBorder(theme.glassBorder, lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(theme.isDark ? 0.18 : 0.06),
                radius: 4,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .help("Return to home greeting (⌘G or Esc)")
    }

    // MARK: - Lifecycle

    private func returnToGreeting() {
        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.1)
        ) {
            ui.homeContent = .greeting
        }
    }

    private func handleAppear() {
        // Sync the Rust engine's theme palette to the landing theme. The
        // setLightMode call inside MetalGraphRepresentable handles the
        // light/dark switch; this hook is here for future per-theme
        // tweaks (cursor color, label palette overrides, etc.).
        graphState.startOverlayPhysicsCycle()
    }

    private func handleDisappear() {
        // Stop the overlay physics cycle so the engine can quiesce when
        // the user returns to the greeting. Mirrors HologramOverlay.hide().
        graphState.cancelOverlayPhysicsCycle()
    }
}

// MARK: - MetalGraphRepresentable

/// `NSViewRepresentable` wrapper around `MetalGraphNSView`. Each instance
/// of this view owns its own engine — exclusive with the floating mini
/// panel's instance because `GraphState.graphViewLocation` picks exactly
/// one host at a time.
@MainActor
private struct MetalGraphRepresentable: NSViewRepresentable {
    let graphState: GraphState
    let isDarkTheme: Bool

    func makeNSView(context: Context) -> MetalGraphNSView {
        let view = MetalGraphNSView(frame: .zero)
        view.graphState = graphState
        if let bootstrap = AppBootstrap.shared {
            view.physicsCoordinator = bootstrap.physicsCoordinator
            view.dialogueChatState = bootstrap.dialogueChatState
        }
        view.uiState = AppBootstrap.shared?.uiState
        // 1) transparent clear color — landing background shows through
        view.isOverlayMode = true
        // 2) full backing-scale resolution + canvas-style input flow
        view.isMiniMode = true
        // 3) light/dark palette sync
        view.setLightMode(!isDarkTheme)
        view.autoresizingMask = [.width, .height]
        // The graph data commit happens automatically on the first
        // render tick via `renderFrame`'s `graphInitialRenderBootstrapState`
        // when `graphState.isLoaded == true`. No manual kick needed —
        // `GraphState` already holds the loaded nodes/edges across host
        // switches.
        return view
    }

    func updateNSView(_ nsView: MetalGraphNSView, context: Context) {
        // Theme can flip mid-session; re-apply the light/dark palette.
        nsView.setLightMode(!isDarkTheme)
    }
}
