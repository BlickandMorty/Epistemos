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
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        observeScreenChanges()
    }

    // MARK: - Toggle

    func toggle() {
        ensureConfiguredFromSharedBootstrap()
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
        // Always open full overlay. The mini-panel is still available
        // via the minimize button but auto-starting minimized is removed
        // per user request 2026-04-04.
        overlay?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func show() {
        ensureConfiguredFromSharedBootstrap()
        ensureOverlay()
        prepareOverlayForGlobalMode()
        graphState?.startOverlayPhysicsCycle()
        presentFullOverlay()
    }

    /// Reveals a specific note in the graph overlay (page mode, focused on the node).
    func revealPage(_ pageId: String) {
        let interval = Log.graphPerf.beginInterval("revealPage")
        defer { Log.graphPerf.endInterval("revealPage", interval) }

        ensureConfiguredFromSharedBootstrap()
        ensureOverlay()
        guard let graphState,
              let node = graphState.store.node(bySourceId: pageId, type: .note) else {
            show()
            return
        }
        prepareOverlayForGlobalMode(centering: node.id)
        graphState.startOverlayPhysicsCycle()
        presentFullOverlay()
    }

    /// Reveals a first-class `.epdoc` artifact in the global graph.
    ///
    /// `.epdoc` packages project into the persistent graph as `.document`
    /// nodes, not legacy `.note` nodes. Opening the global graph from a
    /// document window should therefore center the document's artifact node
    /// instead of dropping the user onto an unfocused vault-wide graph.
    func revealDocument(_ documentSourceId: String) {
        let interval = Log.graphPerf.beginInterval("revealDocument")
        defer { Log.graphPerf.endInterval("revealDocument", interval) }

        ensureConfiguredFromSharedBootstrap()
        ensureOverlay(autoLoadGraph: false)
        graphState?.startOverlayPhysicsCycle()
        presentFullOverlay()

        Task { @MainActor in
            await self.loadGraphForDocumentRevealIfNeeded()
            guard let graphState = self.graphState,
                  let node = graphState.store.node(bySourceId: documentSourceId, type: .document)
            else {
                self.prepareOverlayForGlobalMode()
                self.graphState?.requestRecommit()
                return
            }
            self.prepareOverlayForGlobalMode(centering: node.id)
            graphState.focusOnNode(node.id, depth: GraphOverlayModePolicy.focusDepth)
            graphState.requestModeSync()
            graphState.requestFilterSync()
            graphState.requestRecommit()
        }
    }

    func hide() {
        graphState?.cancelOverlayPhysicsCycle()
        overlay?.hide()
        // Clean up ephemeral page-mode nodes.
        prepareOverlayForGlobalMode()
    }

    func minimize() {
        overlay?.minimize()
    }

    /// Pop the inspector in/out of the graph panel.
    /// External → embedded → external. See `HologramOverlay`.
    func toggleInspectorEmbedded() {
        overlay?.toggleInspectorEmbedded()
    }

    func syncTheme(_ uiState: UIState) {
        overlay?.syncTheme(uiState: uiState)
    }

    var isVisible: Bool {
        overlay?.isVisible ?? false
    }

    var isMinimized: Bool {
        overlay?.isMinimized ?? false
    }

    private var hasActiveVault: Bool {
        AppBootstrap.shared?.vaultSync.vaultURL != nil
    }

    // MARK: - Overlay Lifecycle

    private func ensureConfiguredFromSharedBootstrap() {
        guard graphState == nil, let bootstrap = AppBootstrap.shared else { return }
        setup(
            graphState: bootstrap.graphState,
            queryEngine: bootstrap.queryEngine,
            modelContainer: bootstrap.modelContainer,
            physicsCoordinator: bootstrap.physicsCoordinator,
            dialogueChatState: bootstrap.dialogueChatState
        )
    }

    private func ensureOverlay(autoLoadGraph: Bool = true) {
        guard overlay == nil, let graphState else { return }
        let interval = Log.graphPerf.beginInterval("ensureOverlay")

        if autoLoadGraph, !hasActiveVault {
            graphState.resetForVaultLifecycle()
        }

        // Load graph data on first access without blocking the first overlay show.
        if autoLoadGraph, hasActiveVault, !graphState.isLoaded, let modelContainer {
            let loadInterval = Log.graphPerf.beginInterval("loadGraph")
            graphState.shouldSnapNextGlobalRecommitCamera = true
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
        if autoLoadGraph, hasActiveVault, needsRefresh, let modelContainer {
            Task {
                let refreshInterval = Log.graphPerf.beginInterval("refreshStructuralData")
                let refreshedIncrementally = await graphState.refreshStructuralDataAsync(container: modelContainer)
                if !refreshedIncrementally {
                    graphState.shouldSnapNextGlobalRecommitCamera = true
                    graphState.requestRecommit()
                }
                Log.graphPerf.endInterval("refreshStructuralData", refreshInterval)
            }
        }
    }

    private func loadGraphForDocumentRevealIfNeeded() async {
        guard let graphState, let modelContainer else { return }
        guard hasActiveVault else {
            graphState.resetForVaultLifecycle()
            return
        }
        if !graphState.isLoaded {
            graphState.shouldSnapNextGlobalRecommitCamera = true
            await graphState.loadGraph(container: modelContainer)
            return
        }
        guard graphState.needsRefresh else { return }
        let refreshedIncrementally = await graphState.refreshStructuralDataAsync(container: modelContainer)
        if !refreshedIncrementally {
            graphState.shouldSnapNextGlobalRecommitCamera = true
            graphState.requestRecommit()
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

    private func presentFullOverlay() {
        if overlay?.isMinimized == true {
            overlay?.restore()
        } else {
            overlay?.show()
        }
        NSApp.activate(ignoringOtherApps: true)
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
