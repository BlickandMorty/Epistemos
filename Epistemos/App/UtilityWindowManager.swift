import AppKit
import SwiftData
import SwiftUI

// MARK: - Utility Window Manager
// Manages floating NSPanel windows for utility views (Notes browser).
// Library and Settings now live in the home window via HomeTab.

@MainActor
enum WindowThemeStyler {
    private static let backdropIdentifier = NSUserInterfaceItemIdentifier("EpistemosWindowBackdrop")

    static func themedContentView(host: NSView, theme: EpistemosTheme) -> NSView {
        let container = NSView(frame: host.frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        applyBackdrop(in: container, theme: theme)
        return container
    }

    static func apply(to window: NSWindow, theme: EpistemosTheme) {
        window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
        if theme.usesNativeWindowBlur {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = theme.nsBackground
        }
        applyBackdrop(in: window.contentView, theme: theme)
    }

    private static func applyBackdrop(in root: NSView?, theme: EpistemosTheme) {
        guard let root else { return }

        if theme.usesNativeWindowBlur {
            let effectView: NSVisualEffectView
            if let existing = backdropView(in: root) {
                effectView = existing
            } else {
                let newEffect = NSVisualEffectView(frame: root.bounds)
                newEffect.autoresizingMask = [.width, .height]
                newEffect.identifier = backdropIdentifier
                newEffect.state = .active
                newEffect.blendingMode = .behindWindow
                if let first = root.subviews.first {
                    root.addSubview(newEffect, positioned: .below, relativeTo: first)
                } else {
                    root.addSubview(newEffect)
                }
                effectView = newEffect
            }
            effectView.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
            effectView.material = .underWindowBackground
        } else {
            backdropView(in: root)?.removeFromSuperview()
        }
    }

    private static func backdropView(in root: NSView) -> NSVisualEffectView? {
        root.subviews.first(where: { $0.identifier == backdropIdentifier }) as? NSVisualEffectView
    }
}

enum UtilityPanel: String, CaseIterable {
    case notes

    var title: String { "Notes" }
    var icon: String { "pencil.line" }
    var defaultSize: NSSize { NSSize(width: 320, height: 600) }
    var usesFullWindow: Bool { false }
}

enum UtilityPanelChrome {
    @MainActor
    static func applySidebarChrome(to panel: NSPanel) {
        panel.styleMask.insert(.fullSizeContentView)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        let toolbar = panel.toolbar ?? NSToolbar(identifier: "NotesSidebarToolbar")
        toolbar.showsBaselineSeparator = false
        panel.toolbar = toolbar
        panel.toolbarStyle = .unifiedCompact
    }
}

@MainActor
final class UtilityWindowManager {
    static let shared = UtilityWindowManager()

    private var panels: [UtilityPanel: NSPanel] = [:]

    private init() {}

    // MARK: - Public API

    func show(_ panel: UtilityPanel) {
        let window = getOrCreateWindow(panel)
        if let theme = AppBootstrap.shared?.uiState.theme {
            WindowThemeStyler.apply(to: window, theme: theme)
        }
        window.makeKeyAndOrderFront(nil)
    }

    func hide(_ panel: UtilityPanel) {
        windowFor(panel)?.orderOut(nil)
    }

    func toggle(_ panel: UtilityPanel) {
        let window = getOrCreateWindow(panel)
        if window.isVisible {
            window.orderOut(nil)
        } else {
            if let theme = AppBootstrap.shared?.uiState.theme {
                WindowThemeStyler.apply(to: window, theme: theme)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    func isVisible(_ panel: UtilityPanel) -> Bool {
        windowFor(panel)?.isVisible ?? false
    }

    /// Sync appearance of all open utility windows to the current theme.
    /// Call this whenever the theme changes so live windows update immediately.
    func syncTheme(isDark: Bool) {
        if let theme = AppBootstrap.shared?.uiState.theme {
            for panel in panels.values {
                WindowThemeStyler.apply(to: panel, theme: theme)
            }
            NoteWindowManager.shared.syncTheme(theme: theme)
            MiniChatWindowController.shared.syncTheme(isDark: isDark)
        }
        CommandPaletteWindowController.shared.syncTheme(isDark: isDark)
    }

    private func windowFor(_ panel: UtilityPanel) -> NSWindow? {
        panels[panel]
    }

    // MARK: - Panel Creation

    private func getOrCreateWindow(_ kind: UtilityPanel) -> NSWindow {
        if let existing = panels[kind] {
            return existing
        }

        let size = kind.defaultSize
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = kind.title
        panel.isMovableByWindowBackground = true
        panel.level = .normal
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 400, height: 300)
        UtilityPanelChrome.applySidebarChrome(to: panel)

        panel.center()

        if let bootstrap = AppBootstrap.shared {
            let view = contentView(for: kind, bootstrap: bootstrap)
            let host = NSHostingView(rootView: view)
            panel.contentView = WindowThemeStyler.themedContentView(host: host, theme: bootstrap.uiState.theme)
            WindowThemeStyler.apply(to: panel, theme: bootstrap.uiState.theme)
        }

        panels[kind] = panel
        return panel
    }

    // MARK: - Content Views

    private func contentView(for kind: UtilityPanel, bootstrap: AppBootstrap) -> some View {
        // ThemedUtilityRoot is a View struct whose body re-reads UIState each render cycle.
        // This ensures background + colorScheme are reactive — plain function calls bake values
        // in at call time and never update when the theme changes.
        ThemedUtilityRoot(kind: kind)
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
    }
}

// MARK: - Themed Root

/// View struct wrapper so `background` and `preferredColorScheme` are evaluated inside
/// SwiftUI's render cycle. Because `ui` uses `@Environment` + `@Observable`, SwiftUI
/// re-renders this body whenever `uiState.activePair` or `uiState.isSystemDark` changes.
private struct ThemedUtilityRoot: View {
    @Environment(UIState.self) private var ui
    let kind: UtilityPanel

    var body: some View {
        Group {
            switch kind {
            case .notes: NotesBrowserView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ui.theme.background)
        .preferredColorScheme(ui.theme.colorScheme)
        .navigationTitle("")
    }
}
