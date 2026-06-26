import AppKit
import SwiftUI

// Fallback/preview entry for `WorkWebSurfaceView` (the macOS-26 WebView flat Work host + WorkRuntimeSupervisor).
// It stays available while the owner-visible native Work proof is pending and mirrors `MiniChatWindowController`'s
// themed-window setup (NSHostingView + WindowThemeStyler). Opened from the Work settings preview button.
@MainActor
final class WorkWebSurfaceWindowController {
    static let shared = WorkWebSurfaceWindowController()

    private var window: NSWindow?
    private var observer: NSObjectProtocol?

    /// Open the preview window, or focus it if already open (no duplicate windows).
    func open() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let bootstrap = AppBootstrap.shared else { return }

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
        window.minSize = NSSize(width: 480, height: 360)

        let view = WorkWebSurfaceView(theme: bootstrap.uiState.theme, epistemosVaultRoot: bootstrap.vaultSync.vaultURL)
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
