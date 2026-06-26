import AppKit
import SwiftUI

// Primary in-app entry for the native Epistemos Work surface (WorkEngineSurfaceView): engine picker →
// create/send/stream, recents, queue, permission/question cards, and native tool plumbing. Mirrors
// WorkWebSurfaceWindowController's themed NSWindow setup (NSHostingView + WindowThemeStyler; focus-existing, no
// duplicate windows). Opens from the app menu and Work settings. The workspace is the resolver's ensured dir (the
// runtime needs an existing dir under allowedRoots — no git required).
@MainActor
final class WorkEngineSurfaceWindowController {
    static let shared = WorkEngineSurfaceWindowController()

    private var window: NSWindow?
    private var observer: NSObjectProtocol?

    /// Open the surface window, or focus it if already open (no duplicate windows).
    func open() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let bootstrap = AppBootstrap.shared else { return }
        let repo = WorkOpenGUIWorkspace.ensureDefault()?.path ?? NSTemporaryDirectory()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Epistemos Work"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 520, height: 380)

        let view = WorkEngineSurfaceView(
            theme: bootstrap.uiState.theme,
            repo: repo,
            epistemosVaultRoot: bootstrap.vaultSync.vaultURL)
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
