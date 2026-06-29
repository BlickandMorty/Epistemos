import AppKit
import SwiftUI

// Phase 1 (Step 3) — native Agent window. Mirrors GooseSurfaceWindowController: a themed, transparent
// titlebar NSWindow hosting AgentSurfaceRootView (native chat shell). Opened from the Landing entry /
// ⌘⇧A in Step 4. Singleton (one Agent window).

@MainActor
final class AgentSurfaceWindowController {
    static let shared = AgentSurfaceWindowController()

    private var window: NSWindow?
    private var observer: NSObjectProtocol?

    func open() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let availability = GooseSurfaceAvailability.current()
        guard availability.isReady else {
            presentUnavailableAlert(message: availability.unavailableMessage)
            return
        }
        guard let bootstrap = AppBootstrap.shared else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Epistemos Agent"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 560, height: 420)

        let view = AgentSurfaceRootView(theme: bootstrap.uiState.theme)
            .preferredColorScheme(bootstrap.uiState.preferredColorScheme)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = .minSize
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = WindowThemeStyler.themedContentView(host: host, uiState: bootstrap.uiState)
        WindowThemeStyler.apply(to: window, uiState: bootstrap.uiState)

        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleClose() }
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleClose() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        window = nil
    }

    private func presentUnavailableAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Epistemos Agent is unavailable"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
