import AppKit
import SwiftData
import SwiftUI

// MARK: - Utility Window Manager
// Manages floating NSPanel windows for utility views (Notes browser, Settings).

@MainActor
enum WindowThemeStyler {
    private static let backdropIdentifier = NSUserInterfaceItemIdentifier("EpistemosWindowBackdrop")

    static func themedContentView(
        host: NSView,
        uiState: UIState,
        cornerRadius: CGFloat? = nil
    ) -> NSView {
        let container = NSView(frame: host.frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        if let cornerRadius {
            container.layer?.cornerRadius = cornerRadius
            container.layer?.cornerCurve = .continuous
            container.layer?.masksToBounds = true
        }

        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
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
    case browser
    case browserUsePro
    case meetingNote
    case settings

    static var statusBarPanels: [UtilityPanel] {
        [.notes, .settings]
    }

    var title: String {
        switch self {
        case .notes: "Notes"
        case .browser: "Browser"
        case .browserUsePro: "browser-use Pro"
        case .meetingNote: "Meeting Note"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .notes: "pencil.line"
        case .browser: "safari"
        case .browserUsePro: "network"
        case .meetingNote: "waveform"
        case .settings: "gearshape"
        }
    }

    var defaultSize: NSSize {
        switch self {
        case .notes: NSSize(width: 380, height: 520)
        case .browser: NSSize(width: 1024, height: 720)
        case .browserUsePro: NSSize(width: 1120, height: 760)
        case .meetingNote: NSSize(width: 760, height: 560)
        case .settings: NSSize(width: 900, height: 680)
        }
    }

    var minimumSize: NSSize {
        switch self {
        case .notes: NSSize(width: 300, height: 320)
        case .browser: NSSize(width: 620, height: 420)
        case .browserUsePro: NSSize(width: 720, height: 520)
        case .meetingNote: NSSize(width: 520, height: 420)
        case .settings: NSSize(width: 680, height: 420)
        }
    }

    var maximumSize: NSSize? {
        switch self {
        case .notes: NSSize(width: 520, height: 720)
        case .browser, .browserUsePro, .meetingNote: nil
        case .settings: NSSize(width: 1040, height: 760)
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
        case .browser, .browserUsePro, .meetingNote:
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
        let toolbar = panel.toolbar ?? NSToolbar(identifier: "AgentRuntimeToolbar")
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
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
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
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        let toolbar = panel.toolbar ?? NSToolbar(identifier: "SettingsToolbar")
        if #unavailable(macOS 15.0) {
            toolbar.showsBaselineSeparator = false
        }
        panel.toolbar = toolbar
        panel.toolbarStyle = .unified
    }
}

@MainActor
final class UtilityWindowManager {
    static let shared = UtilityWindowManager()

    private var panels: [UtilityPanel: NSPanel] = [:]
    private var pendingSettingsSection: SettingsView.SettingsSection?

    private init() {}

    // MARK: - Public API

    func show(_ panel: UtilityPanel) {
        let window = getOrCreateWindow(panel)
        if let uiState = AppBootstrap.shared?.uiState {
            WindowThemeStyler.apply(to: window, uiState: uiState)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func showSettings(section: SettingsView.SettingsSection) {
        pendingSettingsSection = section
        show(.settings)
        NotificationCenter.default.post(
            name: .selectSettingsSection,
            object: nil,
            userInfo: [SettingsView.sectionUserInfoKey: section.rawValue]
        )
        pendingSettingsSection = nil
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
        return windowFor(panel)?.isVisible ?? false
    }

    /// Sync appearance of all open utility windows to the current theme.
    /// Call this whenever the theme changes so live windows update immediately.
    func syncTheme(uiState: UIState) {
        for panel in panels.values {
            WindowThemeStyler.apply(to: panel, uiState: uiState)
        }
        NoteWindowManager.shared.syncTheme(uiState: uiState)
        EpdocDocument.syncOpenDocumentThemes(uiState: uiState)
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
        panel.isRestorable = false
        panel.minSize = kind.minimumSize
        if let maxSize = kind.maximumSize {
            panel.maxSize = maxSize
        }
        UtilityPanelChrome.apply(to: panel, kind: kind)

        panel.center()

        // Ensure the window stays within the visible screen area.
        if let screen = panel.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            var frame = panel.frame
            if frame.maxY > visibleFrame.maxY {
                frame.origin.y = visibleFrame.maxY - frame.height
            }
            if frame.minY < visibleFrame.minY {
                frame.origin.y = visibleFrame.minY
            }
            if frame.maxX > visibleFrame.maxX {
                frame.origin.x = visibleFrame.maxX - frame.width
            }
            if frame.minX < visibleFrame.minX {
                frame.origin.x = visibleFrame.minX
            }
            panel.setFrame(frame, display: false)
        }

        if let bootstrap = AppBootstrap.shared {
            let view = contentView(for: kind, bootstrap: bootstrap)
            let host = NSHostingView(rootView: view)
            // Notes and Settings both contain long, scrollable source-list
            // surfaces. Do not let SwiftUI's full content height become the
            // NSPanel minimum size; the explicit UtilityPanel min/default
            // sizes are the window contract.
            if kind == .notes || kind == .settings {
                host.sizingOptions = []
            } else {
                host.sizingOptions = .minSize
            }
            let cornerRadius: CGFloat? = kind == .settings ? 22 : nil
            panel.contentView = WindowThemeStyler.themedContentView(
                host: host,
                uiState: bootstrap.uiState,
                cornerRadius: cornerRadius
            )
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
        ThemedUtilityRoot(kind: kind, bootstrap: bootstrap)
            .initialSettingsSection(pendingSettingsSection)
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
    let bootstrap: AppBootstrap
    var initialSettingsSection: SettingsView.SettingsSection? = nil

    var body: some View {
        Group {
            switch kind {
            case .notes: NotesBrowserView()
            case .browser:
                BrowserView()
            case .browserUsePro:
                BrowserUseWebUIView()
            case .meetingNote:
                MeetingNoteView()
            case .settings:
                SettingsView(initialSelection: initialSettingsSection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .preferredColorScheme(ui.preferredColorScheme)
        .navigationTitle("")
    }
}

private extension ThemedUtilityRoot {
    func initialSettingsSection(_ section: SettingsView.SettingsSection?) -> Self {
        var copy = self
        copy.initialSettingsSection = section
        return copy
    }
}
