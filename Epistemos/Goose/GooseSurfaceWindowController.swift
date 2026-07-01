import AppKit
import Combine
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
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 760, height: 520)
        applyWindowTheme(window, theme: bootstrap.uiState.theme)

        let view = GooseSurfaceHostedRootView(uiState: bootstrap.uiState) { [weak self, weak window] theme in
            guard let self, let window else { return }
            self.applyWindowTheme(window, theme: theme)
        }
        let host = NSHostingView(rootView: view)
        host.sizingOptions = .minSize
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.isOpaque = false
        host.layer?.cornerRadius = 18
        host.layer?.cornerCurve = .continuous
        host.layer?.masksToBounds = true
        window.contentView = host
        window.contentView?.superview?.wantsLayer = true
        window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.superview?.layer?.isOpaque = false
        window.contentView?.superview?.layer?.cornerRadius = 18
        window.contentView?.superview?.layer?.cornerCurve = .continuous
        window.contentView?.superview?.layer?.masksToBounds = true

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

    private func applyWindowTheme(_ window: NSWindow, theme: EpistemosTheme) {
        window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
        WindowThemeStyler.refreshChrome(of: window)
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

@MainActor
private struct GooseSurfaceHostedRootView: View {
    let uiState: UIState
    let onThemeChange: (EpistemosTheme) -> Void

    var body: some View {
        let theme = uiState.theme
        GooseWebSurfaceView(theme: theme)
            .preferredColorScheme(uiState.preferredColorScheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onAppear {
                onThemeChange(theme)
            }
            .onChange(of: theme) { _, newTheme in
                onThemeChange(newTheme)
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .epistemosCustomThemeDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                // Re-tint the native window in lock-step with the WebView when the custom palette
                // changes: the `theme` enum is unchanged, so onChange(of:) alone can't fire here.
                onThemeChange(uiState.theme)
            }
    }
}
