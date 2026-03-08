import AppKit
import Combine
import os
import SwiftData

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
        // Global hotkey (⌘G) is now registered in CommandPaletteWindowController
        // alongside all other global hotkeys. No duplicate monitors needed.
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

        // Auto-enter page mode if a note window is active.
        if let pageId = AppBootstrap.shared?.notesUI.activePageId,
           let graphState,
           let modelContainer,
           let node = graphState.store.node(bySourceId: pageId, type: .note) {
            graphState.mode = .page(nodeId: node.id)

            // Extract quotes, sources, wikilinks from the note body as ephemeral nodes.
            graphState.buildPageSubgraph(for: pageId, context: modelContainer.mainContext)

            // Focus on the page node + its neighbors (including new ephemeral nodes).
            graphState.focusOnNode(node.id, depth: 2)

            // Pass note window for anchor positioning + live tracking.
            let noteWindow = NoteWindowManager.shared.window(for: pageId)
            overlay?.show(noteWindow: noteWindow)
        } else {
            // No active note — global mode.
            graphState?.mode = .global
            graphState?.clearFocus()
            overlay?.show()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func show() {
        ensureOverlay()
        overlay?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Reveals a specific note in the graph overlay (page mode, focused on the node).
    func revealPage(_ pageId: String) {
        let interval = Log.graphPerf.beginInterval("revealPage")
        defer { Log.graphPerf.endInterval("revealPage", interval) }

        ensureOverlay()
        guard let graphState, let modelContainer,
              let node = graphState.store.node(bySourceId: pageId, type: .note) else {
            show()
            return
        }
        graphState.mode = .page(nodeId: node.id)
        graphState.buildPageSubgraph(for: pageId, context: modelContainer.mainContext)
        graphState.focusOnNode(node.id, depth: 2)

        // Only request full recommit if the engine hasn't committed yet.
        // Otherwise the page subgraph was built incrementally (pendingNodeAdds/EdgeAdds)
        // and the filter change (focusOn) is applied by the render loop's filter sync.
        // This avoids an O(N) clear+rebuild for what is a local graph operation.
        if graphState.engineHandle == nil {
            graphState.requestRecommit()
        } else {
            graphState.requestFilterSync()
        }

        let noteWindow = NoteWindowManager.shared.window(for: pageId)
        overlay?.show(noteWindow: noteWindow)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        overlay?.hide()
        // Clean up ephemeral page-mode nodes.
        graphState?.cleanupEphemeralNodes()
        graphState?.clearFocus()
        graphState?.mode = .global
    }

    var isVisible: Bool {
        overlay?.isVisible ?? false
    }

    // MARK: - Overlay Lifecycle

    private func ensureOverlay() {
        guard overlay == nil, let graphState else { return }
        let interval = Log.graphPerf.beginInterval("ensureOverlay")

        // Load graph data on first access if not already loaded.
        if !graphState.isLoaded, let modelContainer {
            let loadInterval = Log.graphPerf.beginInterval("loadGraph")
            graphState.loadGraph(context: modelContainer.mainContext)
            Log.graphPerf.endInterval("loadGraph", loadInterval)
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
                await graphState.refreshStructuralDataAsync(container: modelContainer)
                graphState.requestRecommit()
                Log.graphPerf.endInterval("refreshStructuralData", refreshInterval)
            }
        }
    }

    // MARK: - Screen Changes

    /// Re-position overlay when screens change (resolution, arrangement, external display).
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let overlay = self.overlay, overlay.isVisible else { return }
            // Re-show on the new active screen.
            overlay.show()
        }
    }

    // MARK: - Teardown

    func teardown() {
        // Global hotkey monitors are managed by CommandPaletteWindowController.
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        overlay?.forceClose()
        overlay = nil
    }

    // No deinit needed — this is a singleton. Call teardown() explicitly at app termination.
}
