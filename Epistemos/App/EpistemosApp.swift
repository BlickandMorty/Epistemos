import AppKit
import CoreSpotlight
import SwiftData
import SwiftUI
import UserNotifications

// MARK: - App Entry Point

@MainActor
enum WindowPresentationPolicy {
    static let mainWindowMinimumSize = CGSize(width: 720, height: 520)

    static func needsModularZoomBehavior(_ window: NSWindow) -> Bool {
        if window.contentMinSize != mainWindowMinimumSize {
            return true
        }
        if window.collectionBehavior.contains(.fullScreenPrimary)
            || window.collectionBehavior.contains(.fullScreenAuxiliary)
            || window.collectionBehavior.contains(.fullScreenAllowsTiling)
        {
            return true
        }
        guard let zoomButton = window.standardWindowButton(.zoomButton) else {
            return false
        }
        return zoomButton.target !== window || zoomButton.action != #selector(NSWindow.performZoom(_:))
    }

    static func applyModularZoomBehavior(to window: NSWindow) {
        if window.contentMinSize != mainWindowMinimumSize {
            window.contentMinSize = mainWindowMinimumSize
        }

        var collectionBehavior = window.collectionBehavior
        collectionBehavior.remove(.fullScreenPrimary)
        collectionBehavior.remove(.fullScreenAuxiliary)
        collectionBehavior.remove(.fullScreenAllowsTiling)
        if collectionBehavior != window.collectionBehavior {
            window.collectionBehavior = collectionBehavior
        }

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            if zoomButton.target !== window {
                zoomButton.target = window
            }
            if zoomButton.action != #selector(NSWindow.performZoom(_:)) {
                zoomButton.action = #selector(NSWindow.performZoom(_:))
            }
        }
    }
}

@MainActor
final class ModularZoomWindowObserverView: NSView {
    private var applyTask: Task<Void, Never>?
    private static let applyDelay: Duration = .milliseconds(1)

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window, WindowPresentationPolicy.needsModularZoomBehavior(window) {
            WindowPresentationPolicy.applyModularZoomBehavior(to: window)
            return
        }
        schedulePolicyApply()
    }

    deinit {
        applyTask?.cancel()
    }

    func schedulePolicyApply() {
        applyTask?.cancel()
        applyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.applyDelay)
            guard let self, let window = self.window,
                WindowPresentationPolicy.needsModularZoomBehavior(window)
            else { return }
            WindowPresentationPolicy.applyModularZoomBehavior(to: window)
        }
    }
}

struct ModularZoomWindowObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> ModularZoomWindowObserverView {
        ModularZoomWindowObserverView(frame: .zero)
    }

    func updateNSView(_ nsView: ModularZoomWindowObserverView, context: Context) {
        nsView.schedulePolicyApply()
    }
}

@main
struct EpistemosApp: App {
    @NSApplicationDelegateAdaptor(EpistemosAppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        Window("Epistemos", id: "main") {
            RootView(
                databaseError: bootstrap.databaseError,
                onResetDatabase: { bootstrap.resetDatabaseAndRelaunch() }
            )
                .withAppEnvironment(bootstrap)
                .background(ModularZoomWindowObserver().allowsHitTesting(false))
                .onAppear {
                    StatusBar.shared.setup()
                    HologramController.shared.setup(graphState: bootstrap.graphState, queryEngine: bootstrap.queryEngine, modelContainer: bootstrap.modelContainer, physicsCoordinator: bootstrap.physicsCoordinator, dialogueChatState: bootstrap.dialogueChatState)
                    CommandPaletteWindowController.shared.setup(bootstrap: bootstrap)
                }
                // Handle Spotlight deep-links — user tapped a note in Spotlight results
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let pageId = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                    else { return }
                    NoteWindowManager.shared.open(pageId: pageId)
                }
                // Handle Siri Suggestions / NSUserActivity continuations
                .onContinueUserActivity("com.epistemos.openNote") { activity in
                    guard let pageId = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                    else { return }
                    NoteWindowManager.shared.open(pageId: pageId)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    bootstrap.vaultSync.stopWatching(preserveData: true)
                    StatusBar.shared.remove()
                    HologramController.shared.teardown()
                    CommandPaletteWindowController.shared.teardown()
                }
        }
        .defaultSize(width: 1100, height: 720)
        .modelContainer(bootstrap.modelContainer)
        .commands {
            EpistemosCommands(
                ui: bootstrap.uiState, chat: bootstrap.chatState, notesUI: bootstrap.notesUI,
                vaultSync: bootstrap.vaultSync)
        }

        // Knowledge Graph uses a full-screen hologram overlay (HologramController),
        // not a SwiftUI Window scene. Toggle with Cmd+Shift+G.
    }
}

// MARK: - App Delegate (Dock Menu + Native Hooks)

final class EpistemosAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var mainWindowObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeMainNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didDeminiaturizeNotification,
        ]

        mainWindowObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let window = note.object as? NSWindow else { return }
                Task { @MainActor in
                    Self.applyMainWindowPolicyIfNeeded(to: window)
                }
            }
        }

        UNUserNotificationCenter.current().delegate = self

        Task { @MainActor in
            NSApp.windows.forEach(Self.applyMainWindowPolicyIfNeeded(to:))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let center = NotificationCenter.default
        mainWindowObservers.forEach(center.removeObserver)
        mainWindowObservers.removeAll()
    }

    @MainActor
    private static func applyMainWindowPolicyIfNeeded(to window: NSWindow) {
        guard window.title == "Epistemos" else { return }
        WindowPresentationPolicy.applyModularZoomBehavior(to: window)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let chatId = response.notification.request.content.userInfo["chatId"] as? String else {
            return
        }

        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            AppBootstrap.shared?.loadChat(chatId: chatId)
            if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                main.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Native macOS dock menu — right-click the dock icon for quick actions.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let newNote = NSMenuItem(
            title: "New Note", action: #selector(dockNewNote), keyEquivalent: "")
        newNote.image = NSImage(systemSymbolName: "plus.square", accessibilityDescription: "New Note")
        newNote.target = self
        menu.addItem(newNote)

        let search = NSMenuItem(
            title: "Search Notes", action: #selector(dockSearch), keyEquivalent: "")
        search.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        search.target = self
        menu.addItem(search)

        menu.addItem(.separator())

        let miniChat = NSMenuItem(
            title: "Toggle Mini Chat", action: #selector(dockMiniChat), keyEquivalent: "")
        miniChat.image = NSImage(
            systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "Mini Chat")
        miniChat.target = self
        menu.addItem(miniChat)

        return menu
    }

    @objc private func dockNewNote() {
        Task { @MainActor in
            guard let vaultSync = AppBootstrap.shared?.vaultSync else { return }
            if let pageId = await vaultSync.createPage(title: "Untitled") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
            NSApp.activate()
        }
    }

    @objc private func dockSearch() {
        Task { @MainActor in
            CommandPaletteWindowController.shared.show()
        }
    }

    @objc private func dockMiniChat() {
        Task { @MainActor in
            CommandPaletteWindowController.shared.toggleChatMode()
        }
    }
}

// MARK: - Keyboard Commands

struct EpistemosCommands: Commands {
    let ui: UIState
    let chat: ChatState
    let notesUI: NotesUIState
    let vaultSync: VaultSyncService
    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Show Home") {
                chat.goHome()
                ui.homeTab = .home
                ui.setActivePanel(.home)
                NSApp.activate()
                if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                    main.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Show Notes") { UtilityWindowManager.shared.show(.notes) }
                .keyboardShortcut("2", modifiers: .command)

            Button("Knowledge Graph") {
                HologramController.shared.toggle()
            }
            .keyboardShortcut("g", modifiers: .command)

            Divider()

            Button("Open Settings") {
                UtilityWindowManager.shared.show(.settings)
                NSApp.activate()
            }

            Divider()

            Button("Toggle Mini Chat") {
                CommandPaletteWindowController.shared.toggleChatMode()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                Task { @MainActor in
                    if let pageId = await vaultSync.createPage(title: "Untitled") {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Search") {
                CommandPaletteWindowController.shared.show()
            }
            .keyboardShortcut(.space, modifiers: .option)
        }

        CommandGroup(replacing: .appVisibility) {
            Button("Go Home") {
                chat.goHome()
                ui.setActivePanel(.home)
                ui.homeTab = .home
                NSApp.activate()
                if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                    main.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("h", modifiers: .command)

            Button("Hide Others") {
                NSApp.hideOtherApplications(nil)
            }
            .keyboardShortcut("h", modifiers: [.command, .option])

            Button("Show All") {
                NSApp.unhideAllApplications(nil)
            }
        }
    }
}
