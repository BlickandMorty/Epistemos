import AppKit
import Combine
import os
import SwiftData

enum GraphOverlayModePolicy {
    static let pageModeEnabled = false
    static let focusDepth = 3
}

// MARK: - HologramController
// Singleton that manages the hologram overlay lifecycle and global hotkey.
//
// Hotkey: Cmd+G (toggles overlay on/off)
//
// Uses both global + local event monitors for complete coverage:
// - Global monitor: fires when another app is frontmost
// - Local monitor:  fires when Epistemos is frontmost
//
// The overlay window is created once and reused (show/hide, not create/destroy).

@MainActor
final class HologramController {

    static let shared = HologramController()

    private var overlay: HologramOverlay?
    private var graphState: GraphState?
    private var queryEngine: QueryEngine?
    private var modelContainer: ModelContainer?
    private var physicsCoordinator: PhysicsCoordinator?
    private var dialogueChatState: DialogueChatState?

    // Screen-change observer.
    private var screenObserver: Any?

    private init() {}

    // MARK: - Setup

    /// Call once at app launch with the shared GraphState and ModelContainer.
    func setup(graphState: GraphState, queryEngine: QueryEngine, modelContainer: ModelContainer, physicsCoordinator: PhysicsCoordinator? = nil, dialogueChatState: DialogueChatState? = nil) {
        self.graphState = graphState
        self.queryEngine = queryEngine
        self.modelContainer = modelContainer
        self.physicsCoordinator = physicsCoordinator
        self.dialogueChatState = dialogueChatState
        // Provide a ModelContext for interactive graph mutations (node/edge creation).
        graphState.modelContext = modelContainer.mainContext
        observeScreenChanges()
    }

    // MARK: - Toggle

    func toggle() {
        // If minimized, Cmd+G restores to full overlay.
        if overlay?.isMinimized == true {
            overlay?.restore()
            return
        }

        if overlay?.isVisible == true {
            hide()
            return
        }

        ensureOverlay()
        prepareOverlayForGlobalMode()
        graphState?.startOverlayPhysicsCycle()
        overlay?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func show() {
        ensureOverlay()
        prepareOverlayForGlobalMode()
        graphState?.startOverlayPhysicsCycle()
        overlay?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Reveals a specific note in the graph overlay (page mode, focused on the node).
    func revealPage(_ pageId: String) {
        let interval = Log.graphPerf.beginInterval("revealPage")
        defer { Log.graphPerf.endInterval("revealPage", interval) }

        ensureOverlay()
        guard let graphState,
              let node = graphState.store.node(bySourceId: pageId, type: .note) else {
            show()
            return
        }
        prepareOverlayForGlobalMode(centering: node.id)
        graphState.startOverlayPhysicsCycle()
        overlay?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        graphState?.cancelOverlayPhysicsCycle()
        overlay?.hide()
        // Clean up ephemeral page-mode nodes.
        prepareOverlayForGlobalMode()
    }

    func syncTheme(_ uiState: UIState) {
        overlay?.syncTheme(uiState: uiState)
    }

    var isVisible: Bool {
        overlay?.isVisible ?? false
    }

    // MARK: - Overlay Lifecycle

    private func ensureOverlay() {
        guard overlay == nil, let graphState else { return }
        let interval = Log.graphPerf.beginInterval("ensureOverlay")

        // Load graph data on first access without blocking the first overlay show.
        if !graphState.isLoaded, let modelContainer {
            let loadInterval = Log.graphPerf.beginInterval("loadGraph")
            Task(priority: .utility) {
                await graphState.loadGraph(container: modelContainer)
                Log.graphPerf.endInterval("loadGraph", loadInterval)
            }
        }

        // Capture refresh need before creating overlay — deferred to avoid blocking first show.
        let needsRefresh = graphState.needsRefresh

        overlay = HologramOverlay(graphState: graphState, queryEngine: queryEngine ?? QueryEngine(), modelContainer: modelContainer, physicsCoordinator: physicsCoordinator, dialogueChatState: dialogueChatState)
        Log.graphPerf.endInterval("ensureOverlay", interval)

        // Run structural refresh AFTER overlay exists so the graph shows immediately.
        // Uses async path to run GraphBuilder on a background thread.
        if needsRefresh, let modelContainer {
            Task {
                let refreshInterval = Log.graphPerf.beginInterval("refreshStructuralData")
                let refreshedIncrementally = await graphState.refreshStructuralDataAsync(container: modelContainer)
                if !refreshedIncrementally {
                    graphState.requestRecommit()
                }
                Log.graphPerf.endInterval("refreshStructuralData", refreshInterval)
            }
        }
    }

    private func prepareOverlayForGlobalMode(centering nodeId: String? = nil) {
        guard let graphState else { return }
        graphState.cleanupEphemeralNodes()
        graphState.mode = .global
        graphState.requestModeSync()
        graphState.clearFocus()
        graphState.requestFilterSync()
        graphState.selectNode(nodeId)
        graphState.pendingCenterNodeId = nodeId
    }

    // MARK: - Screen Changes

    /// Re-position overlay when screens change (resolution, arrangement, external display).
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let overlay = self.overlay, overlay.isVisible else { return }
                // Re-show on the new active screen.
                overlay.show()
            }
        }
    }

    // MARK: - Teardown

    func teardown() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        graphState?.cancelOverlayPhysicsCycle()
        overlay?.forceClose()
        overlay = nil
    }

    // No deinit needed — this is a singleton. Call teardown() explicitly at app termination.
}
