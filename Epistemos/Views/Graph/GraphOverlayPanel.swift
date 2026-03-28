import AppKit

/// NSPanel subclass for the graph overlay.
/// Uses .nonactivatingPanel to avoid stealing focus from the main window.
/// Set as a child window of the main app window for proper z-ordering,
/// Mission Control behavior, and fullscreen transitions.
final class GraphOverlayPanel: NSPanel {

    /// In mini mode, the panel should accept key for graph interactions.
    /// In full-screen overlay mode, it should also accept key (for search, Esc dismiss).
    override var canBecomeKey: Bool { true }

    /// Never become main — the main window should always stay main.
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        level = .floating
        isReleasedWhenClosed = false
        isRestorable = false
        hidesOnDeactivate = false
        // The Secret Sauce — this single property fixes 80% of "weirdness":
        // .moveToActiveSpace  — follows user between Spaces
        // .fullScreenAuxiliary — stays visible in fullscreen
        // .ignoresCycle        — excluded from ⌘~ window cycling
        // .stationary          — don't auto-move on Exposé/Mission Control
        collectionBehavior = [
            .moveToActiveSpace,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        // Prevent the panel from appearing in the Window menu or Exposé.
        isExcludedFromWindowsMenu = true
    }

    required init?(coder: NSCoder) { fatalError() }
}
