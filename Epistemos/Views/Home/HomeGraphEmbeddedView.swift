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
//   - The resolved background token fills the backdrop (NOT NSVisualEffectView).
//     The landing's color shows through directly.
//   - `isOverlayMode = true` on the metal view → Rust engine uses
//     transparent clear color so the SwiftUI Color underneath is visible.
//   - Canvas fills the home window; workspace routes add the same 28pt
//     continuous rounded boundary used by the mini graph panel.
//   - The bottom graph toolbar Close action returns to the greeting, and
//     Esc keeps the same shortcut path.
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
    @Environment(\.scenePhase) private var scenePhase

    /// Inspector state — owned by this view, mirrors HologramOverlay's
    /// pattern. Replays node selection from `graphState.selectedNodeId`
    /// via the standard binding in `HologramNodeInspector`.
    @State private var inspectorState = NodeInspectorState()
    @State private var controlsOffset: CGSize = .zero
    @State private var controlsDragAnchor: CGSize = .zero
    @State private var embeddedRouteFreezeSnapshot: Bool?
    @State private var embeddedGraphBridge = EmbeddedGraphMetalBridge()
    @State private var embeddedCanvasReady = false
    @State private var embeddedCanvasStartTask: Task<Void, Never>?

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
                isDarkTheme: theme.isDark,
                shouldRenderCanvas: shouldRenderCanvas,
                graphBridge: embeddedGraphBridge
            )
            .ignoresSafeArea()
            .allowsHitTesting(shouldRenderCanvas)

            // 3. Route overlay (note / folder pages). On `.canvas` route
            //    this is hidden so mouse events fall through to the
            //    metal canvas. Same isolation as HologramOverlay.
            embeddedWorkspaceRoute

            // 4. Search sidebar — canvas-only graph chrome.
            if graphState.currentRoute.isCanvas {
                HStack(alignment: .top, spacing: 0) {
                    HologramSearchSidebar(
                        inspectorState: inspectorState,
                        modelContext: modelContext,
                        onRevealNode: { nodeId in
                            revealEmbeddedNode(nodeId)
                        }
                    )
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(true)
            }

            // 5. Inspector — attached to the selected node, using the same
            //    compact inspector body as the floating graph.
            embeddedAttachedInspector

            // 6. Floating controls capsule — bottom-center.
            if graphState.currentRoute.isCanvas {
                embeddedFloatingControls
            }

            // 7. FPS HUD — bottom-trailing. The host view internally
            //    branches on `graphFPSHUDEnabled` so we always mount
            //    it; it draws EmptyView when the toggle is off.
            if graphState.currentRoute.isCanvas {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        GraphFPSHUDHostView()
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
            }

        }
        .environment(\.graphSurfacePresentation, .embeddedHome)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.25),
            value: graphState.selectedNodeId
        )
        .onKeyPress(.escape) {
            returnToGreeting()
            return .handled
        }
        .onChange(of: graphState.currentRoute) { _, newRoute in
            syncEmbeddedRouteState(newRoute)
        }
        .onChange(of: graphState.selectedNodeId) { _, newId in
            syncEmbeddedInspectorSelection(nodeId: newId)
        }
        .onChange(of: scenePhase) { _, _ in
            syncEmbeddedRouteState(graphState.currentRoute)
        }
        .onAppear { handleAppear() }
        .onDisappear { handleDisappear() }
    }

    @ViewBuilder
    private var embeddedWorkspaceRoute: some View {
        if !graphState.currentRoute.isCanvas {
            GraphWorkspaceContainer()
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
        }
    }

    private var shouldRenderCanvas: Bool {
        graphState.currentRoute.isCanvas && scenePhase == .active && embeddedCanvasReady
    }

    private var embeddedInspectorSize: CGSize {
        CGSize(width: 320, height: 500)
    }

    @ViewBuilder
    private var embeddedAttachedInspector: some View {
        if graphState.currentRoute.isCanvas, graphState.selectedNodeId != nil {
            GeometryReader { proxy in
                let frame = embeddedInspectorFrame(in: proxy.size)
                HologramNodeInspector(
                    inspectorState: inspectorState,
                    modelContext: modelContext
                )
                .frame(
                    width: embeddedInspectorSize.width,
                    height: embeddedInspectorSize.height,
                    alignment: .topLeading
                )
                .position(x: frame.midX, y: frame.midY)
                .transition(.opacity)
                .animation(
                    reduceMotion ? nil : .smooth(duration: 0.18),
                    value: graphState.selectedNodeId
                )
            }
        }
    }

    private func embeddedInspectorFrame(in size: CGSize) -> CGRect {
        let margin: CGFloat = 16
        let gap: CGFloat = 20
        let width = min(embeddedInspectorSize.width, max(160, size.width - margin * 2))
        let height = min(embeddedInspectorSize.height, max(160, size.height - margin * 2))

        let anchor: CGPoint
        if let appKitPoint = graphState.selectedNodeScreenPoint {
            anchor = CGPoint(x: appKitPoint.x, y: size.height - appKitPoint.y)
        } else {
            anchor = CGPoint(x: size.width * 0.55, y: size.height * 0.45)
        }

        var x = anchor.x + gap
        if x + width > size.width - margin {
            x = anchor.x - width - gap
        }
        let minX = margin
        let maxX = max(minX, size.width - width - margin)
        x = min(max(x, minX), maxX)

        var y = anchor.y - height * 0.28
        let minY = margin
        let maxY = max(minY, size.height - height - margin)
        y = min(max(y, minY), maxY)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private var embeddedFloatingControls: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                GraphFloatingControls()
                    .offset(controlsOffset)
                    .gesture(controlsDragGesture)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 24)
        }
    }

    private var controlsDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                controlsOffset = CGSize(
                    width: controlsDragAnchor.width + value.translation.width,
                    height: controlsDragAnchor.height + value.translation.height
                )
            }
            .onEnded { _ in
                controlsDragAnchor = controlsOffset
            }
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

    private func revealEmbeddedNode(_ nodeId: String) {
        guard graphState.store.nodes[nodeId] != nil else {
            graphState.requestGraphRebuild()
            return
        }

        if !graphState.currentRoute.isCanvas {
            graphState.returnToCanvas()
        }

        graphState.cleanupEphemeralNodes()
        graphState.mode = .global
        graphState.clearFocus()
        graphState.requestModeSync()
        graphState.selectNode(nodeId)
        graphState.pendingCenterNodeId = nodeId
        syncEmbeddedInspectorSelection(nodeId: nodeId)
        embeddedGraphBridge.isolateNode(nodeId)
    }

    private func syncEmbeddedInspectorSelection(nodeId: String?) {
        guard let nodeId else {
            inspectorState.clearSelection()
            return
        }
        guard let node = graphState.store.nodes[nodeId] else {
            inspectorState.clearSelection()
            graphState.requestGraphRebuild()
            return
        }
        inspectorState.selectNode(node, store: graphState.store, modelContext: modelContext)
    }

    private func handleAppear() {
        // Sync the Rust engine's theme palette to the landing theme. The
        // setLightMode call inside MetalGraphRepresentable handles the
        // light/dark switch; this hook is here for future per-theme
        // tweaks (cursor color, label palette overrides, etc.).
        embeddedCanvasReady = false
        syncEmbeddedRouteState(graphState.currentRoute)
    }

    private func handleDisappear() {
        // Stop the overlay physics cycle so the engine can quiesce when
        // the user returns to the greeting. Mirrors HologramOverlay.hide().
        embeddedCanvasStartTask?.cancel()
        embeddedCanvasStartTask = nil
        embeddedCanvasReady = false
        restoreEmbeddedRouteFreezeIfNeeded()
        graphState.cancelOverlayPhysicsCycle()
    }

    private func syncEmbeddedRouteState(_ route: GraphWorkspaceRoute) {
        if route.isCanvas, scenePhase == .active {
            restoreEmbeddedRouteFreezeIfNeeded()
            scheduleEmbeddedCanvasStart()
        } else {
            embeddedCanvasStartTask?.cancel()
            embeddedCanvasStartTask = nil
            embeddedCanvasReady = false
            if embeddedRouteFreezeSnapshot == nil {
                embeddedRouteFreezeSnapshot = graphState.isPhysicsFrozen
            }
            if !graphState.isPhysicsFrozen {
                graphState.isPhysicsFrozen = true
                graphState.physicsFrozenVersion += 1
            }
            graphState.cancelOverlayPhysicsCycle()
        }
    }

    private func scheduleEmbeddedCanvasStart() {
        guard !embeddedCanvasReady else { return }
        graphState.cancelOverlayPhysicsCycle()
        // SS-AN: ready IMMEDIATELY — no 420ms gate. The old delay left the graph blank
        // during the transition, then popped. The blur-replace transition (BlurFade) now
        // provides the visual ramp as the canvas comes up.
        embeddedCanvasReady = true
        graphState.startOverlayPhysicsCycle()
    }

    private func restoreEmbeddedRouteFreezeIfNeeded() {
        guard let wasFrozen = embeddedRouteFreezeSnapshot else { return }
        embeddedRouteFreezeSnapshot = nil
        guard graphState.isPhysicsFrozen != wasFrozen else { return }
        graphState.isPhysicsFrozen = wasFrozen
        graphState.physicsFrozenVersion += 1
    }
}

@MainActor
private final class EmbeddedGraphMetalBridge {
    private weak var view: MetalGraphNSView?

    func attach(_ view: MetalGraphNSView) {
        self.view = view
    }

    func isolateNode(_ nodeId: String) {
        guard let view, !view.isHidden else { return }
        view.isolateNode(nodeId)
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
    let shouldRenderCanvas: Bool
    let graphBridge: EmbeddedGraphMetalBridge

    final class Coordinator {
        private var lastShouldRenderCanvas: Bool?

        func syncVisibility(_ shouldRenderCanvas: Bool, view: MetalGraphNSView) {
            let visibilityChanged = lastShouldRenderCanvas != shouldRenderCanvas
            lastShouldRenderCanvas = shouldRenderCanvas

            if shouldRenderCanvas {
                if visibilityChanged || view.isHidden || view.alphaValue < 1.0 {
                    view.isHidden = false
                    view.resumeEngine()
                    // SS-AN: no separate AppKit alpha fade — set alpha to 1 immediately and
                    // let SwiftUI's blur-replace own the single fade. The 0.32s AppKit fade
                    // racing the 0.28s SwiftUI fade was the main flicker source.
                    view.alphaValue = 1.0
                }
            } else if visibilityChanged || !view.isHidden || view.alphaValue > 0.0 {
                view.pauseEngine()
                view.alphaValue = 0.0
                view.isHidden = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MetalGraphNSView {
        let view = MetalGraphNSView(frame: .zero)
        view.graphState = graphState
        if let bootstrap = AppBootstrap.shared {
            view.physicsCoordinator = bootstrap.physicsCoordinator
        }
        view.uiState = AppBootstrap.shared?.uiState
        // 1) transparent clear color — landing background shows through
        view.isOverlayMode = true
        // 2) full backing-scale resolution + canvas-style input flow
        view.isMiniMode = true
        view.usesClickSelectionFallback = true
        // 3) light/dark palette sync
        view.setLightMode(!isDarkTheme)
        view.autoresizingMask = [.width, .height]
        // The graph data commit happens automatically on the first
        // render tick via `renderFrame`'s `graphInitialRenderBootstrapState`
        // when `graphState.isLoaded == true`. No manual kick needed —
        // `GraphState` already holds the loaded nodes/edges across host
        // switches.
        graphBridge.attach(view)
        context.coordinator.syncVisibility(shouldRenderCanvas, view: view)
        return view
    }

    func updateNSView(_ nsView: MetalGraphNSView, context: Context) {
        // Theme can flip mid-session; re-apply the light/dark palette.
        nsView.setLightMode(!isDarkTheme)
        graphBridge.attach(nsView)
        context.coordinator.syncVisibility(shouldRenderCanvas, view: nsView)
    }
}
