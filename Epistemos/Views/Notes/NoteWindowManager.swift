import AppIntents
import AppKit
import CoreSpotlight
import SwiftData
import SwiftUI
import Translation
import UniformTypeIdentifiers
import os

// MARK: - Note Window Manager
// Manages note editor windows as a native macOS tab group.
// Every note opens as a tab using NoteTabShell (navigation) + NoteDetailWorkspaceView (editor).
// Single entry point: open(pageId:) — fetches page, highlights sidebar, opens tab.
// Uses themed glass toolbar (ToolbarGlass.swift) for frosted glass effect with theme tinting.

/// A single item in the wikilink navigation breadcrumb trail.
struct BreadcrumbItem: Identifiable {
    let id: String  // pageId
    var title: String
}

enum NoteTitleDisplay {
    static func resolvedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}

@MainActor
enum NoteWindowChrome {
    static func apply(to window: NSWindow, toolbarIdentifier: String) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        let toolbar = window.toolbar ?? NSToolbar(identifier: toolbarIdentifier)
        if #unavailable(macOS 15.0) {
            toolbar.showsBaselineSeparator = false
        }
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }
}

@MainActor
enum NoteWindowThemeStyler {
    static func themedContentController(
        hostingController: NSHostingController<some View>,
        uiState: UIState
    ) -> NSViewController {
        return NoteWindowBackdropController(hostingController: hostingController, uiState: uiState)
    }

    static func apply(to window: NSWindow, uiState: UIState) {
        window.titlebarAppearsTransparent = true
        if #unavailable(macOS 15.0) {
            window.toolbar?.showsBaselineSeparator = false
        }
        window.toolbarStyle = .unified
        // Tint the window chrome (toolbar / titlebar area) to the theme's
        // editor canvas color so themes with non-system backgrounds (e.g.
        // Nocturne's deep purple-black 0x19141F or Magnolia's pink-cream
        // 0xF7F2F5) don't render macOS's opaque default chrome material
        // on top of an otherwise themed body. With
        // `titlebarAppearsTransparent = true` and `.fullSizeContentView`,
        // the window backgroundColor shows through the title bar area.
        let canvasColor = NSColor(
            NoteWorkspaceSurfaceStyle.canvasBackground(for: uiState.theme)
        )
        window.backgroundColor = canvasColor

        if let controller = window.contentViewController as? NoteWindowBackdropController {
            controller.syncTheme(uiState: uiState)
        } else {
            WindowThemeStyler.removeBackdrop(in: window.contentView)
        }
        WindowThemeStyler.refreshChrome(of: window)
    }
}

@MainActor
final class NoteWindowBackdropController: NSViewController {
    private let hostingController: NSViewController

    init(hostingController: NSViewController, uiState: UIState) {
        self.hostingController = hostingController
        super.init(nibName: nil, bundle: nil)
        addChild(hostingController)
        view = WindowThemeStyler.themedContentView(host: hostingController.view, uiState: uiState)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func syncTheme(uiState: UIState) {
        WindowThemeStyler.applyBackdrop(in: view, uiState: uiState)
    }
}

// MARK: - NoteNavigationState
// Per-tab navigation state for in-place wikilink traversal.
// Owns the breadcrumb stack — first item is the root page, last is current.
// The shell view uses .id(currentPageId) to force NoteDetailWorkspaceView recreation
// on each navigation, giving a fresh @Query and @State.

@MainActor @Observable
final class NoteNavigationState {

    /// The breadcrumb stack — first item is the root page, last is current.
    private(set) var stack: [BreadcrumbItem]

    /// Pages popped by back() — enables forward navigation (Cmd+]).
    /// Cleared on any new push() (new navigation branch).
    private(set) var forwardStack: [BreadcrumbItem] = []

    /// Pending cursor/scroll restore from workspace snapshot. Applied once by Coordinator, then nil'd.
    var pendingEditorRestore: (cursor: Int, scrollFraction: Double)?

    /// Fallback ID — the root page this tab was opened with.
    let rootPageId: String

    /// The page currently displayed in this tab.
    var currentPageId: String {
        stack.last?.id ?? rootPageId
    }

    var currentPageTitle: String? {
        stack.last?.title
    }

    /// True when there's a navigation trail worth showing (2+ items or forward history).
    var hasBreadcrumb: Bool { stack.count > 1 || !forwardStack.isEmpty }

    /// True when back navigation is possible (2+ items in stack).
    var canGoBack: Bool { stack.count > 1 }

    /// True when forward navigation is possible (items in forward stack).
    var canGoForward: Bool { !forwardStack.isEmpty }

    init(rootPageId: String, rootTitle: String) {
        self.rootPageId = rootPageId
        self.stack = [BreadcrumbItem(id: rootPageId, title: rootTitle)]
    }

    /// Push a new page onto the navigation stack (wikilink click).
    /// Clears forward history — new navigation branch.
    func push(pageId: String, title: String) {
        guard !pageId.isEmpty else { return }
        guard pageId != currentPageId else { return }
        // If already in the stack, truncate to that point instead of duplicating.
        if let existingIndex = stack.firstIndex(where: { $0.id == pageId }) {
            stack = Array(stack[...existingIndex])
        } else {
            stack.append(BreadcrumbItem(id: pageId, title: title))
        }
        forwardStack.removeAll()
    }

    /// Navigate back one level. Returns the new current page ID, or nil if already at root.
    @discardableResult
    func back() -> String? {
        guard stack.count > 1 else { return nil }
        forwardStack.append(stack.removeLast())
        return currentPageId
    }

    /// Navigate forward one level. Returns the new current page ID, or nil if no forward history.
    @discardableResult
    func forward() -> String? {
        guard let item = forwardStack.popLast() else { return nil }
        stack.append(item)
        return currentPageId
    }

    /// Navigate to a breadcrumb item — truncates the stack to that point.
    /// Items after the target are moved to forward stack.
    func navigateTo(pageId: String) {
        guard let index = stack.firstIndex(where: { $0.id == pageId }) else { return }
        let removed = stack[(index + 1)...]
        forwardStack.append(contentsOf: removed.reversed())
        stack = Array(stack[...index])
    }

    /// Update a breadcrumb title when the page is renamed.
    func syncTitle(pageId: String, title: String) {
        if let idx = stack.firstIndex(where: { $0.id == pageId }) {
            guard stack[idx].title != title else { return }
            stack[idx].title = title
        }
        if let idx = forwardStack.firstIndex(where: { $0.id == pageId }) {
            forwardStack[idx].title = title
        }
    }

    @discardableResult
    func retargetCurrentPage(
        missingPageId: String,
        replacementPageId: String,
        replacementTitle: String
    ) -> Bool {
        guard stack.last?.id == missingPageId else { return false }
        guard !replacementPageId.isEmpty else { return false }

        let resolvedTitle = NoteTitleDisplay.resolvedTitle(replacementTitle)
        stack.removeLast()
        forwardStack.removeAll()

        if let existingIndex = stack.firstIndex(where: { $0.id == replacementPageId }) {
            stack = Array(stack[...existingIndex])
            syncTitle(pageId: replacementPageId, title: resolvedTitle)
        } else {
            stack.append(BreadcrumbItem(id: replacementPageId, title: resolvedTitle))
        }
        return true
    }

    @discardableResult
    func discardCurrentPageIfMissing(_ missingPageId: String) -> Bool {
        guard stack.count > 1 else { return false }
        guard stack.last?.id == missingPageId else { return false }
        stack.removeLast()
        forwardStack.removeAll()
        return true
    }
}

@MainActor
final class NoteWindowManager {
    static let shared = NoteWindowManager()
    static let noteTabbingIdentifier = "epistemos-note-tabs"
    static let noteDefaultFrameSize = NSSize(width: 1110, height: 740)
    // 2026-05-19: dropped from 960×620 → 400×300 per user direction so
    // opening a note doesn't force the window to grow. Users can now
    // resize note windows freely; the inner SwiftUI surface declares its
    // own 400×300 fallback (NoteDetailWorkspaceView).
    static let noteMinimumFrameSize = NSSize(width: 400, height: 300)

    // All note windows — one per page, displayed as tabs
    private var windows: [String: NSWindow] = [:]
    private var observers: [String: any NSObjectProtocol] = [:]
    private let tabDelegate = NoteTabDelegate()
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "NoteWindow")

    /// Per-tab navigation states — tracks in-place wikilink navigation.
    /// Key = root tab pageId, Value = NoteNavigationState for that tab.
    private var navigationStates: [String: NoteNavigationState] = [:]

    private init() {}

    static func firstAvailableNoteTabGroupWindow(
        excluding excludedWindow: NSWindow? = nil,
        requireVisible: Bool = true,
        windows: [NSWindow] = NSApp.windows
    ) -> NSWindow? {
        windows.first { candidate in
            if let excludedWindow, candidate === excludedWindow {
                return false
            }
            guard candidate.tabbingIdentifier == noteTabbingIdentifier else {
                return false
            }
            if requireVisible, !candidate.isVisible {
                return false
            }
            return true
        }
    }

    // MARK: - Navigation State Registration

    func registerNavState(_ state: NoteNavigationState, forTab tabPageId: String) {
        navigationStates[tabPageId] = state
    }

    func unregisterNavState(forTab tabPageId: String) {
        navigationStates.removeValue(forKey: tabPageId)
    }

    /// The page currently displayed in the tab (may differ from root if user navigated via wikilinks).
    func currentPageId(forTab tabPageId: String) -> String {
        navigationStates[tabPageId]?.currentPageId ?? tabPageId
    }

    var hasOpenNoteWindows: Bool {
        !windows.isEmpty
    }

    // MARK: - Open Note (Single Entry Point)

    /// Open a note by ID — fetches the page, highlights in sidebar, opens as tab.
    /// Single entry point for sidebar / command palette note opens.
    /// Wikilink navigation uses NoteNavigationState.push() instead.
    func open(pageId: String) {
        guard let bootstrap = AppBootstrap.shared else { return }
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        let page: SDPage
        do {
            guard let fetched = try bootstrap.modelContainer.mainContext.fetch(descriptor).first else {
                Log.app.error("NoteWindowManager: failed to open missing page \(pageId, privacy: .public)")
                return
            }
            page = fetched
        } catch {
            Log.app.error("NoteWindowManager: failed to fetch page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        bootstrap.notesUI.openPage(pageId)
        openWindow(for: page)

        // When a note is focused, dismiss the notes browser sidebar popover
        // and pause the graph overlay so editor scroll/typing stays fluid.
        // The user can reopen either on demand; this only auto-clears them on
        // a note-open transition, not during routine note switching.
        UtilityWindowManager.shared.hide(.notes)
        if HologramController.shared.isVisible {
            HologramController.shared.hide()
        }

        // Donate Spotlight activity async — never block note opening on indexing.
        let pageId = page.id
        let pageTitle = page.title
        let pageTags = page.tags
        Task { @MainActor [weak self] in
            self?.donateNoteActivity(pageId: pageId, title: pageTitle, tags: pageTags)
        }
    }

    /// Donates an NSUserActivity for Spotlight Suggestions.
    /// Decoupled from SDPage to avoid SwiftData faults during donation.
    private func donateNoteActivity(pageId: String, title: String, tags: [String]) {
        let activity = NSUserActivity(activityType: "com.epistemos.openNote")
        activity.title = title
        activity.isEligibleForSearch = true
        activity.persistentIdentifier = pageId
        activity.userInfo = [CSSearchableItemActivityIdentifier: pageId]

        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = title
        attributes.contentDescription =
            tags.isEmpty
            ? "Note in Epistemos"
            : "Tags: \(tags.joined(separator: ", "))"
        activity.contentAttributeSet = attributes

        activeUserActivity = activity
        activity.becomeCurrent()
    }

    /// Tracks the current NSUserActivity so it stays alive while the note window is open.
    private var activeUserActivity: NSUserActivity?

    // MARK: - Tab Windows

    /// Open a note in a new tab window. If already open, bring to front.
    func openWindow(for page: SDPage) {
        // If window already exists for this page, bring to front
        if let existing = windows[page.id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        guard let bootstrap = AppBootstrap.shared else {
            Self.log.error("AppBootstrap not available — cannot open note window")
            return
        }

        let pageTitle = NoteTitleDisplay.resolvedTitle(page.title)

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.noteDefaultFrameSize.width,
                height: Self.noteDefaultFrameSize.height
            ),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = pageTitle
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = Self.noteMinimumFrameSize
        window.setFrameAutosaveName("note-\(page.id)")
        normalizeNoteWindowFrame(window)
        WindowPresentationPolicy.applyModularZoomBehavior(to: window)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = Self.noteTabbingIdentifier
        window.delegate = tabDelegate

        let editorView = NoteTabShell(pageId: page.id, pageTitle: pageTitle)
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
        let hostingController = NSHostingController(rootView: editorView)
        hostingController.sceneBridgingOptions = [.all]
        window.contentViewController = NoteWindowThemeStyler.themedContentController(
            hostingController: hostingController,
            uiState: bootstrap.uiState
        )
        
        NoteWindowChrome.apply(to: window, toolbarIdentifier: "NoteEditor")

        NoteWindowThemeStyler.apply(to: window, uiState: bootstrap.uiState)

        let pageId = page.id
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                self?.handleWindowClose(window, pageId: pageId)
            }
        }
        observers[page.id] = observer

        if let existingWindow = Self.firstAvailableNoteTabGroupWindow(excluding: window) {
            existingWindow.addTabbedWindow(window, ordered: .above)
        }
        window.makeKeyAndOrderFront(nil)
        windows[page.id] = window

        Self.log.info("Opened note tab for: \(page.title, privacy: .public)")
        AppBootstrap.shared?.activityTracker.recordNoteOpened(pageId: page.id, title: page.title)
    }

    static func sanitizedNoteWindowFrame(proposedFrame: NSRect, visibleFrame: NSRect) -> NSRect {
        let minWidth = min(noteMinimumFrameSize.width, visibleFrame.width)
        let minHeight = min(noteMinimumFrameSize.height, visibleFrame.height)
        let defaultWidth = min(noteDefaultFrameSize.width, visibleFrame.width)
        let defaultHeight = min(noteDefaultFrameSize.height, visibleFrame.height)

        let needsReset = proposedFrame.width < minWidth || proposedFrame.height < minHeight

        var frame = needsReset
            ? NSRect(
                x: visibleFrame.midX - defaultWidth / 2,
                y: visibleFrame.midY - defaultHeight / 2,
                width: defaultWidth,
                height: defaultHeight
            )
            : proposedFrame

        frame.size.width = min(max(frame.width, minWidth), visibleFrame.width)
        frame.size.height = min(max(frame.height, minHeight), visibleFrame.height)
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        return frame.integral
    }

    private func normalizeNoteWindowFrame(_ window: NSWindow) {
        guard let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let sanitized = Self.sanitizedNoteWindowFrame(
            proposedFrame: window.frame,
            visibleFrame: visibleFrame
        )
        guard sanitized != window.frame else { return }
        window.setFrame(sanitized, display: false)
    }

    /// Reverse lookup: find the pageId for a given window.
    func pageId(for window: NSWindow) -> String? {
        windows.first(where: { $0.value === window })?.key
    }

    /// Forward lookup: find the NSWindow for a given pageId.
    func window(for pageId: String) -> NSWindow? {
        windows[pageId]
    }

    private func handleWindowClose(_ window: NSWindow, pageId: String) {
        if let observer = observers.removeValue(forKey: pageId) {
            NotificationCenter.default.removeObserver(observer)
        }
        windows.removeValue(forKey: pageId)
        navigationStates.removeValue(forKey: pageId)
        if windows.isEmpty {
            activeUserActivity?.resignCurrent()
            activeUserActivity = nil
        }
        AppBootstrap.shared?.activityTracker.recordNoteClosed(pageId: pageId, title: window.title)
    }

    // MARK: - Version Tab (Read-Only)

    /// Open a past version of a note as a read-only tab next to existing note tabs.
    func openVersionTab(title: String, body: String, date: Date) {
        guard let bootstrap = AppBootstrap.shared else { return }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: date)

        let view = ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let windowTitle = NoteTitleDisplay.resolvedTitle(title)
        window.title = "\(windowTitle) — \(dateStr)"
        window.contentViewController = NoteWindowThemeStyler.themedContentController(
            hostingController: hostingController,
            uiState: bootstrap.uiState
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 400, height: 300)
        
        NoteWindowChrome.apply(to: window, toolbarIdentifier: "NoteEditor")
        NoteWindowThemeStyler.apply(to: window, uiState: bootstrap.uiState)

        // Zoom instead of fullscreen
        WindowPresentationPolicy.applyModularZoomBehavior(to: window)

        // Join the note tab group
        window.tabbingMode = .preferred
        window.tabbingIdentifier = Self.noteTabbingIdentifier

        // Add as tab next to existing note windows
        if let existingWindow = Self.firstAvailableNoteTabGroupWindow(excluding: window) {
            existingWindow.addTabbedWindow(window, ordered: .above)
        }
        window.makeKeyAndOrderFront(nil)

        // Track with a unique key so it gets cleaned up
        let key = "version-\(UUID().uuidString)"
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                self?.handleWindowClose(window, pageId: key)
            }
        }
        observers[key] = observer
        windows[key] = window

        Self.log.info(
            "Opened version tab: \(windowTitle, privacy: .public) (\(dateStr, privacy: .public))")
    }

    /// Sync appearance of all note windows to the current theme.
    func syncTheme(uiState: UIState) {
        for w in windows.values {
            NoteWindowThemeStyler.apply(to: w, uiState: uiState)
        }
    }

    func closeWindowDisplaying(pageId: String) {
        let rootPageIds = windows.keys.filter { rootPageId in
            rootPageId == pageId || navigationStates[rootPageId]?.currentPageId == pageId
        }
        for rootPageId in rootPageIds {
            windows[rootPageId]?.close()
        }
    }

    // MARK: - Workspace Capture

    /// All currently open page IDs (unordered).
    var openPageIds: [String] { Array(windows.keys) }

    /// Page IDs in tab-bar order (uses NSWindow.tabbedWindows).
    func orderedPageIds() -> [String] {
        guard let firstWindow = windows.values.first,
              let tabbedWindows = firstWindow.tabbedWindows else {
            return Array(windows.keys)
        }
        return tabbedWindows.compactMap { pageId(for: $0) }
    }

    /// Navigation state for a tab (breadcrumb + forward stacks).
    func navState(forTab tabPageId: String) -> NoteNavigationState? {
        navigationStates[tabPageId]
    }

    /// Read cursor position and scroll fraction from the live NSTextView in a note window.
    func editorState(for pageId: String) -> (cursor: Int, scrollFraction: Double)? {
        guard let window = windows[pageId] else { return nil }
        guard let textView = Self.findTextView(in: window.contentView) else { return nil }
        let cursor = textView.selectedRange().location
        let scroll: Double
        if let scrollView = textView.enclosingScrollView,
           let docHeight = scrollView.documentView?.bounds.height, docHeight > 0 {
            scroll = scrollView.contentView.bounds.origin.y / docHeight
        } else {
            scroll = 0
        }
        return (cursor, scroll)
    }

    /// Read the current body text from the live NSTextView when a note window is open.
    func editorBody(for pageId: String) -> String? {
        guard let window = windows[pageId] else { return nil }
        return Self.findTextView(in: window.contentView)?.string
    }

    /// Prefer the live editor body for an open note window, then fall back to the persisted body file.
    func currentBody(for pageId: String, mapped: Bool = false) -> String {
        editorBody(for: pageId) ?? NoteFileStorage.readBody(pageId: pageId, mapped: mapped, fast: !mapped)
    }

    private static func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let tv = view as? NSTextView { return tv }
        for sub in view.subviews {
            if let found = findTextView(in: sub) { return found }
        }
        return nil
    }

    func resetForVaultRebuild() {
        let openWindows = Array(windows.values)
        for observer in observers.values {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        windows.removeAll()
        navigationStates.removeAll()
        activeUserActivity?.resignCurrent()
        activeUserActivity = nil
        for window in openWindows {
            window.close()
        }
    }
}

// MARK: - Tab Delegate
// Handles the native macOS tab bar + button — creates a new untitled note as a tab.
// Also syncs activePageId when the user switches between tabs.

private final class NoteTabDelegate: NSObject, NSWindowDelegate {
    @MainActor func newWindowForTab(_ sender: NSWindow) {
        Task { @MainActor in
            guard let vaultSync = AppBootstrap.shared?.vaultSync else { return }
            if let pageId = await vaultSync.createPage(title: "Untitled", allowVaultSelectionPrompt: true) {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    @MainActor func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
            let pageId = NoteWindowManager.shared.pageId(for: window)
        else { return }
        AppBootstrap.shared?.notesUI.openPage(
            NoteWindowManager.shared.currentPageId(forTab: pageId))
    }
}

// MARK: - Note Tab Shell
// Thin wrapper that owns NoteNavigationState for in-tab wikilink navigation.
// Renders NoteDetailWorkspaceView. Uses .id(currentPageId) to force
// full view recreation on navigation (fresh @Query, @State, NoteChatState).

private struct NoteTabShell: View {
    @State private var navState: NoteNavigationState

    init(pageId: String, pageTitle: String) {
        _navState = State(
            initialValue: NoteNavigationState(
                rootPageId: pageId, rootTitle: pageTitle
            ))
    }

    var body: some View {
        NoteDetailWorkspaceView(pageId: navState.currentPageId)
            .id(navState.currentPageId)
            .environment(navState)
        .onChange(of: navState.currentPageId) { _, newPageId in
            // Sync window title to the currently displayed page.
            let targetId = newPageId
            if let window = NSApp.keyWindow {
                let desc = FetchDescriptor<SDPage>(
                    predicate: #Predicate<SDPage> { $0.id == targetId }
                )
                if let context = AppBootstrap.shared?.modelContainer.mainContext {
                    do {
                        if let page = try context.fetch(desc).first {
                            window.title = NoteTitleDisplay.resolvedTitle(page.title)
                        } else {
                            Log.app.error("NoteWindowManager: missing page title for tab \(targetId, privacy: .public)")
                        }
                    } catch {
                        Log.app.error("NoteWindowManager: failed to fetch page title for tab \(targetId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            AppBootstrap.shared?.notesUI.openPage(newPageId)
        }
        .onAppear {
            NoteWindowManager.shared.registerNavState(navState, forTab: navState.rootPageId)
        }
        .onDisappear {
            NoteWindowManager.shared.unregisterNavState(forTab: navState.rootPageId)
        }
    }
}
