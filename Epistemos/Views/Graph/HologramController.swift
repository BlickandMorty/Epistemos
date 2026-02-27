import AppKit
import Combine
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
    private var modelContainer: ModelContainer?

    // Event monitors.
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // Screen-change observer.
    private var screenObserver: Any?

    private init() {}

    // MARK: - Setup

    /// Call once at app launch with the shared GraphState and ModelContainer.
    func setup(graphState: GraphState, modelContainer: ModelContainer) {
        self.graphState = graphState
        self.modelContainer = modelContainer
        registerHotkey()
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

        // Load graph data on first access if not already loaded.
        if !graphState.isLoaded, let modelContainer {
            graphState.loadGraph(context: modelContainer.mainContext)
        }

        // Refresh structural data if notes changed since last graph build.
        if graphState.needsRefresh, let modelContainer {
            graphState.refreshStructuralData(context: modelContainer.mainContext)
        }

        overlay = HologramOverlay(graphState: graphState, modelContainer: modelContainer)
    }

    // MARK: - Global Hotkey (Cmd+G)

    private static let hotkeyKeyCode: UInt16 = 5 // 'G' key

    private func isHotkeyEvent(_ event: NSEvent) -> Bool {
        guard event.keyCode == Self.hotkeyKeyCode else { return false }
        let required: NSEvent.ModifierFlags = [.command]
        // Check that Cmd is held and no other modifiers (except function keys).
        let cleaned = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        return cleaned == required
    }

    private func registerHotkey() {
        // Global monitor: catches hotkey from any app.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.isHotkeyEvent(event) {
                Task { @MainActor in
                    self.toggle()
                }
            }
        }

        // Local monitor: catches hotkey when Epistemos is frontmost.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isHotkeyEvent(event) {
                Task { @MainActor in
                    self.toggle()
                }
                return nil // Consume the event.
            }
            return event
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
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        globalMonitor = nil
        localMonitor = nil
        screenObserver = nil
        overlay?.hide()
        overlay = nil
    }

    // No deinit needed — this is a singleton. Call teardown() explicitly at app termination.
}
