import AppKit
import SwiftData
import SwiftUI

// MARK: - Utility Window Manager
// Manages floating NSPanel windows for utility views (Notes browser).
// Library and Settings now live in the home window via HomeTab.

enum UtilityPanel: String, CaseIterable {
    case notes

    var title: String { "Notes" }
    var icon: String { "pencil.line" }
    var defaultSize: NSSize { NSSize(width: 320, height: 600) }
    var usesFullWindow: Bool { false }
}

@MainActor
final class UtilityWindowManager {
    static let shared = UtilityWindowManager()

    private var panels: [UtilityPanel: NSPanel] = [:]

    private init() {}

    // MARK: - Public API

    func show(_ panel: UtilityPanel) {
        let window = getOrCreateWindow(panel)
        // Sync window chrome (titlebar, toolbar) and background to current theme
        if let theme = AppBootstrap.shared?.uiState.theme {
            window.backgroundColor = NSColor(theme.background)
            window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
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
            // Sync window chrome to current theme before showing
            if let theme = AppBootstrap.shared?.uiState.theme {
                window.backgroundColor = NSColor(theme.background)
                window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
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
        let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        let background = AppBootstrap.shared.map { NSColor($0.uiState.theme.background) }
        for panel in panels.values {
            panel.appearance = appearance
            if let bg = background { panel.backgroundColor = bg }
        }
        // Also sync note editor windows and command palette
        if let theme = AppBootstrap.shared?.uiState.theme {
            NoteWindowManager.shared.syncTheme(theme: theme)
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
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = kind.title
        panel.isMovableByWindowBackground = true
        panel.level = .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 400, height: 300)

        let toolbar = NSToolbar(identifier: "Utility-\(kind.rawValue)")
        panel.toolbar = toolbar
        panel.toolbarStyle = .unifiedCompact
        panel.titleVisibility = .hidden

        panel.center()

        if let bootstrap = AppBootstrap.shared {
            let view = contentView(for: kind, bootstrap: bootstrap)
            let host = NSHostingView(rootView: view)
            panel.contentView = host
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
