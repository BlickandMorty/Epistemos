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
        guard let bootstrap = AppBootstrap.shared else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Epistemos Goose"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 620, height: 420)

        let view = GooseWebSurfaceView(theme: bootstrap.uiState.theme)
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
}
