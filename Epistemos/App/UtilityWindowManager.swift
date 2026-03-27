import AppKit
import SwiftData
import SwiftUI

// MARK: - Utility Window Manager
// Manages floating NSPanel windows for utility views (Notes browser, Settings).

@MainActor
enum WindowThemeStyler {
    private static let backdropIdentifier = NSUserInterfaceItemIdentifier("EpistemosWindowBackdrop")

    static func themedContentView(host: NSView, uiState: UIState) -> NSView {
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

        applyBackdrop(in: container, uiState: uiState)
        return container
    }

    static func apply(to window: NSWindow, uiState: UIState) {
        // Let macOS handle appearance automatically (Liquid Glass, dark/light mode)
        window.appearance = nil
        window.backgroundColor = .windowBackgroundColor
        applyBackdrop(in: window.contentView, uiState: uiState)
        refreshChrome(of: window)
    }

    static func refreshChrome(of window: NSWindow) {
        window.contentView?.needsDisplay = true
        window.contentView?.displayIfNeeded()
        window.contentViewController?.view.needsDisplay = true
        window.contentViewController?.view.displayIfNeeded()
        window.contentView?.superview?.needsDisplay = true
        window.contentView?.superview?.displayIfNeeded()
        window.standardWindowButton(.closeButton)?.superview?.needsDisplay = true
        window.standardWindowButton(.closeButton)?.superview?.displayIfNeeded()
        window.toolbar?.validateVisibleItems()
        window.invalidateShadow()
    }

    static func applyBackdrop(in root: NSView?, uiState: UIState) {
        guard let root else { return }

        if uiState.usesNativeWindowBlur {
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
            effectView.appearance = nil
            effectView.material = .underWindowBackground
        } else {
            removeBackdrop(in: root)
        }
    }

    static func removeBackdrop(in root: NSView?) {
        guard let root else { return }
        backdropView(in: root)?.removeFromSuperview()
    }

    private static func backdropView(in root: NSView) -> NSVisualEffectView? {
        root.subviews.first(where: { $0.identifier == backdropIdentifier }) as? NSVisualEffectView
    }
}

enum UtilityPanel: String, CaseIterable {
    case notes
    case omega
    case settings

    var title: String {
        switch self {
        case .notes: "Notes"
        case .omega: "Omega"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .notes: "pencil.line"
        case .omega: "cpu"
        case .settings: "gearshape"
        }
    }

    var defaultSize: NSSize {
        switch self {
        case .notes: NSSize(width: 320, height: 600)
        case .omega: NSSize(width: 480, height: 700)
        case .settings: NSSize(width: 900, height: 680)
        }
    }

    var minimumSize: NSSize {
        switch self {
        case .notes: NSSize(width: 400, height: 300)
        case .omega: NSSize(width: 400, height: 400)
        case .settings: NSSize(width: 680, height: 420)
        }
    }

    var maximumSize: NSSize? {
        switch self {
        case .settings: NSSize(width: 680, height: 10000) // Fixed width, flexible height
        default: nil
        }
    }

    var usesFullWindow: Bool { false }
}

enum UtilityPanelChrome {
    @MainActor
    static func apply(to panel: NSPanel, kind: UtilityPanel) {
        switch kind {
        case .notes:
            applySidebarChrome(to: panel)
        case .omega:
            applyOmegaChrome(to: panel)
        case .settings:
            applySettingsChrome(to: panel)
        }
    }

    @MainActor
    static func applyOmegaChrome(to panel: NSPanel) {
        panel.styleMask.insert(.fullSizeContentView)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        let toolbar = panel.toolbar ?? NSToolbar(identifier: "OmegaToolbar")
        if #unavailable(macOS 15.0) {
            toolbar.showsBaselineSeparator = false
        }
        panel.toolbar = toolbar
        panel.toolbarStyle = .unified
    }

    @MainActor
    static func applySidebarChrome(to panel: NSPanel) {
        panel.styleMask.insert(.fullSizeContentView)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        let toolbar = panel.toolbar ?? NSToolbar(identifier: "NotesSidebarToolbar")
        panel.toolbar = toolbar
        panel.toolbarStyle = .unifiedCompact
    }

    @MainActor
    static func applySettingsChrome(to panel: NSPanel) {
        panel.styleMask.insert(.fullSizeContentView)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        // Ensure proper rounded corners like macOS System Settings
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        let toolbar = panel.toolbar ?? NSToolbar(identifier: "SettingsToolbar")
        if #unavailable(macOS 15.0) {
            toolbar.showsBaselineSeparator = false
        }
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
        if let uiState = AppBootstrap.shared?.uiState {
            WindowThemeStyler.apply(to: window, uiState: uiState)
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
            if let uiState = AppBootstrap.shared?.uiState {
                WindowThemeStyler.apply(to: window, uiState: uiState)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    func isVisible(_ panel: UtilityPanel) -> Bool {
        windowFor(panel)?.isVisible ?? false
    }

    /// Sync appearance of all open utility windows to the current theme.
    /// Call this whenever the theme changes so live windows update immediately.
    func syncTheme(uiState: UIState) {
        for panel in panels.values {
            WindowThemeStyler.apply(to: panel, uiState: uiState)
        }
        NoteWindowManager.shared.syncTheme(uiState: uiState)
        MiniChatWindowController.shared.syncTheme(uiState: uiState)
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
        panel.level = .normal
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        panel.minSize = kind.minimumSize
        if let maxSize = kind.maximumSize {
            panel.maxSize = maxSize
        }
        UtilityPanelChrome.apply(to: panel, kind: kind)

        panel.center()

        if let bootstrap = AppBootstrap.shared {
            let view = contentView(for: kind, bootstrap: bootstrap)
            let host = NSHostingView(rootView: view)
            panel.contentView = WindowThemeStyler.themedContentView(host: host, uiState: bootstrap.uiState)
            WindowThemeStyler.apply(to: panel, uiState: bootstrap.uiState)
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
/// re-renders this body whenever system appearance changes.
private struct ThemedUtilityRoot: View {
    @Environment(UIState.self) private var ui
    let kind: UtilityPanel

    var body: some View {
        Group {
            switch kind {
            case .notes: NotesBrowserView()
            case .omega: OmegaPanel()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .preferredColorScheme(ui.preferredColorScheme)
        .navigationTitle("")
    }
}
