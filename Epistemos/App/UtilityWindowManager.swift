import AppKit
import SwiftData
import SwiftUI

// MARK: - Utility Window Manager
// Manages floating NSPanel windows for utility views (Settings, Notes, Library).
// Each utility gets its own panel instance, created lazily on first show.
// Panels float above the main window and persist across tab switches.

enum UtilityPanel: String, CaseIterable {
    case settings
    case notes
    case library

    var title: String {
        switch self {
        case .settings: "Settings"
        case .notes: "Notes"
        case .library: "Library & Research"
        }
    }

    var icon: String {
        switch self {
        case .settings: "gear"
        case .notes: "pencil.line"
        case .library: "books.vertical"
        }
    }

    var defaultSize: NSSize {
        switch self {
        case .settings: NSSize(width: 520, height: 480)
        case .notes: NSSize(width: 320, height: 600)
        case .library: NSSize(width: 900, height: 660)
        }
    }

    /// Library uses full NSWindow (appears in Window menu / dock).
    /// Notes browser and Settings use floating NSPanel.
    var usesFullWindow: Bool {
        switch self {
        case .library: true
        case .notes, .settings: false
        }
    }
}

@MainActor
final class UtilityWindowManager {
    static let shared = UtilityWindowManager()

    private var panels: [UtilityPanel: NSPanel] = [:]
    private var windows: [UtilityPanel: NSWindow] = [:]

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
        for window in windows.values {
            window.appearance = appearance
            if let bg = background { window.backgroundColor = bg }
        }
        for panel in panels.values {
            panel.appearance = appearance
            if let bg = background { panel.backgroundColor = bg }
        }
        // Also sync note editor windows and command palette
        NoteWindowManager.shared.syncTheme(isDark: isDark)
        CommandPaletteWindowController.shared.syncTheme(isDark: isDark)
    }

    private func windowFor(_ panel: UtilityPanel) -> NSWindow? {
        panel.usesFullWindow ? windows[panel] : panels[panel]
    }

    // MARK: - Panel Creation

    private func getOrCreateWindow(_ kind: UtilityPanel) -> NSWindow {
        // Return existing if available
        if kind.usesFullWindow, let existing = windows[kind] {
            return existing
        } else if !kind.usesFullWindow, let existing = panels[kind] {
            return existing
        }

        let size = kind.defaultSize

        if kind.usesFullWindow {
            // Full NSWindow — appears in Window menu, dock, Mission Control
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = kind.title
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 500, height: 400)
            window.setFrameAutosaveName("epistemos-\(kind.rawValue)")

            // Zoom instead of fullscreen — green button fills screen without entering a Space.
            window.collectionBehavior.remove(.fullScreenPrimary)

            // Unified toolbar for glass chrome
            let toolbar = NSToolbar(identifier: "Window-\(kind.rawValue)")
            window.toolbar = toolbar
            window.toolbarStyle = .unified

            // Center on first show (autosave will override on subsequent launches)
            window.center()

            // Attach SwiftUI content
            if let bootstrap = AppBootstrap.shared {
                let view = contentView(for: kind, bootstrap: bootstrap)
                let host = NSHostingView(rootView: view)
                window.contentView = host
            }

            windows[kind] = window
            return window

        } else {
            // Floating NSPanel for utilities (existing behavior)
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

            // Position offset from center so panels don't stack exactly
            panel.center()
            let offset = CGFloat(panels.count) * 30
            if let frame = panel.screen?.visibleFrame {
                let origin = NSPoint(
                    x: frame.midX - size.width / 2 + offset,
                    y: frame.midY - size.height / 2 - offset
                )
                panel.setFrameOrigin(origin)
            }

            // Attach SwiftUI content
            if let bootstrap = AppBootstrap.shared {
                let view = contentView(for: kind, bootstrap: bootstrap)
                let host = NSHostingView(rootView: view)
                panel.contentView = host
            }

            panels[kind] = panel
            return panel
        }
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
            case .settings: SettingsView()
            case .notes: NotesBrowserView()
            case .library: LibraryView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ui.theme.background)
        .preferredColorScheme(ui.theme.colorScheme)
        .navigationTitle("")
    }
}
