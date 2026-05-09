import AppKit

enum GraphOverlayPanelPresentation {
    case immersiveOverlay
    case floatingPanel
}

/// NSPanel subclass for the graph overlay.
/// Uses .nonactivatingPanel to avoid stealing focus from the main window.
/// Full-screen immersive mode can float independently above system chrome,
/// while mini/inspector panels stay attached to the app window.
final class GraphOverlayPanel: NSPanel {
    /// Window-local key handling hook used by the graph overlay for Escape /
    /// Cmd-W dismissal. Keeping this on the panel avoids installing app-wide
    /// NSEvent monitors, which can trip Input Monitoring/TCC during launch.
    var keyEventHandler: ((NSEvent) -> Bool)?

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
        isReleasedWhenClosed = false
        isRestorable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        // Prevent the panel from appearing in the Window menu or Exposé.
        isExcludedFromWindowsMenu = true
        applyPresentation(.floatingPanel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func keyDown(with event: NSEvent) {
        if keyEventHandler?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    func applyPresentation(_ presentation: GraphOverlayPanelPresentation) {
        switch presentation {
        case .immersiveOverlay:
            level = .screenSaver
            hasShadow = false
            collectionBehavior = [
                .moveToActiveSpace,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
        case .floatingPanel:
            level = .floating
            hasShadow = true
            collectionBehavior = [
                .moveToActiveSpace,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
        }
    }
}
