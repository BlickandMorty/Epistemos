import AppKit
import SwiftData
import SwiftUI

@MainActor
final class MiniChatWindowController {
    static let shared = MiniChatWindowController()

    private static let minimumContentSize = CGSize(width: 320, height: 340)
    private let tabDelegate = MiniChatTabDelegate()
    private var windows: [String: NSWindow] = [:]
    private var observers: [String: any NSObjectProtocol] = [:]

    private init() {}

    func toggle() {
        if windows.values.contains(where: \.isVisible) {
            openNewChat()
        } else {
            show()
        }
    }

    func show() {
        if let window = windows.values.first {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        openNewChat()
    }

    func hide() {
        for window in windows.values {
            window.orderOut(nil)
        }
    }

    func closeAll() {
        for observer in observers.values {
            NotificationCenter.default.removeObserver(observer)
        }
        let openWindows = Array(windows.values)
        observers.removeAll()
        windows.removeAll()
        for window in openWindows {
            window.close()
        }
    }

    func openNewChat(attaching attachment: ContextAttachment? = nil) {
        let resolvedAttachment: ContextAttachment?
        if let attachment {
            resolvedAttachment = attachment
        } else if let bootstrap = AppBootstrap.shared {
            resolvedAttachment = activeNoteAttachment(in: bootstrap)
        } else {
            resolvedAttachment = nil
        }
        openChat(UUID().uuidString, initialContextAttachment: resolvedAttachment)
    }

    func openChat(_ chatID: String) {
        openChat(chatID, initialContextAttachment: nil)
    }

    func openChat(_ chatID: String, initialContextAttachment: ContextAttachment?) {
        if let existing = windows[chatID] {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        guard let bootstrap = AppBootstrap.shared else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Mini Chat"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.moveToActiveSpace]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 320, height: 340)
        window.maxSize = NSSize(width: 1600, height: 1400)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "epistemos-mini-chat-tabs"
        window.delegate = tabDelegate
        WindowPresentationPolicy.applyModularZoomBehavior(
            to: window,
            minimumContentSize: Self.minimumContentSize
        )

        let toolbar = NSToolbar(identifier: "MiniChatToolbar")
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden

        let view = MiniChatView(chatID: chatID, initialContextAttachment: initialContextAttachment)
            .withAppEnvironment(bootstrap)
            .modelContainer(bootstrap.modelContainer)
            .preferredColorScheme(bootstrap.uiState.preferredColorScheme)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = .minSize
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = WindowThemeStyler.themedContentView(host: host, uiState: bootstrap.uiState)
        WindowThemeStyler.apply(to: window, uiState: bootstrap.uiState)

        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self?.handleWindowClose(window, chatID: chatID)
            }
        }
        observers[chatID] = observer

        if let existingWindow = windows.values.first {
            existingWindow.addTabbedWindow(window, ordered: .above)
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        windows[chatID] = window
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Workspace Capture

    /// All currently open mini chat IDs.
    var openChatIds: [String] { Array(windows.keys) }

    func updateWindowTitle(chatID: String, title: String) {
        guard let window = windows[chatID] else { return }
        window.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Mini Chat" : title
    }

    func syncTheme(uiState: UIState) {
        for window in windows.values {
            WindowThemeStyler.apply(to: window, uiState: uiState)
        }
    }

    private func handleWindowClose(_ window: NSWindow, chatID: String) {
        if let observer = observers.removeValue(forKey: chatID) {
            NotificationCenter.default.removeObserver(observer)
        }
        windows.removeValue(forKey: chatID)
        if !window.isVisible {
            AppBootstrap.shared?.threadState.setMiniChatStreaming(false, chatID: chatID)
        }
    }

    private func activeNoteAttachment(in bootstrap: AppBootstrap) -> ContextAttachment? {
        guard let pageID = bootstrap.notesUI.activePageId else { return nil }
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageID })
        guard let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first else { return nil }
        return ComposerReferenceHelpers.noteAttachment(pageID: page.id, title: page.title)
    }
}

private final class MiniChatTabDelegate: NSObject, NSWindowDelegate {
    @MainActor func newWindowForTab(_ sender: NSWindow) {
        MiniChatWindowController.shared.openNewChat()
    }
}
