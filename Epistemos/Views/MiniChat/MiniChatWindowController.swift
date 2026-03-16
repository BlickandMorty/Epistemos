import AppKit
import SwiftData
import SwiftUI

// MARK: - MiniChat Window Controller
// Manages a floating NSPanel that stays above all windows (.floating level).
// Non-activating so the user's focus stays in their current app.

@MainActor
final class MiniChatWindowController: NSWindowController {

    static let shared = MiniChatWindowController()

    private var isConfigured = false

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 580),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "MiniChat"
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 320, height: 400)
        panel.maxSize = NSSize(width: 700, height: 900)
        WindowPresentationPolicy.applyModularZoomBehavior(to: panel)

        // Unified toolbar gives rounded corners matching the main window
        let toolbar = NSToolbar(identifier: "MiniChatToolbar")
        panel.toolbar = toolbar
        panel.toolbarStyle = .unified
        panel.titleVisibility = .hidden

        panel.center()
        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(bootstrap: AppBootstrap) {
        let view = MiniChatView()
            .padding(22)
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
            .preferredColorScheme(bootstrap.uiState.preferredColorScheme)
        let host = NSHostingView(rootView: view)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        window?.contentView = WindowThemeStyler.themedContentView(host: host, uiState: bootstrap.uiState)
        if let window {
            WindowThemeStyler.apply(to: window, uiState: bootstrap.uiState)
        }

        isConfigured = true
    }

    func toggle() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func show() { showPanel() }
    func hide() { window?.orderOut(nil) }

    /// Sync NSPanel appearance and background to the current theme.
    func syncTheme(isDark: Bool) {
        guard let window else { return }
        if let uiState = AppBootstrap.shared?.uiState {
            WindowThemeStyler.apply(to: window, uiState: uiState)
        }
    }

    private func showPanel() {
        // Auto-configure on first show — NSPanel always creates a default contentView,
        // so we track configuration state with a flag instead of checking contentView == nil.
        if !isConfigured, let bootstrap = AppBootstrap.shared {
            configure(bootstrap: bootstrap)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
