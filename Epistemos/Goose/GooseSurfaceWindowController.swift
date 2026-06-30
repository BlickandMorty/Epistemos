import AppKit
import SwiftUI

@MainActor
final class GooseSurfaceWindowController {
    static let shared = GooseSurfaceWindowController()

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
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Epistemos Goose"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 760, height: 520)
        window.appearance = NSAppearance(named: bootstrap.uiState.theme.isDark ? .darkAqua : .aqua)

        let view = GooseWebSurfaceView(theme: bootstrap.uiState.theme)
            .preferredColorScheme(bootstrap.uiState.preferredColorScheme)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = .minSize
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = host
        WindowThemeStyler.refreshChrome(of: window)

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
        alert.messageText = "Epistemos Goose is unavailable"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
