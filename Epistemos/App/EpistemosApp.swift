import AppKit
import CoreSpotlight
import SwiftData
import SwiftUI
import UserNotifications

// MARK: - App Entry Point

@MainActor
enum WindowPresentationPolicy {
    static let mainWindowMinimumSize = CGSize(width: 720, height: 520)

    static func needsModularZoomBehavior(
        _ window: NSWindow,
        minimumContentSize: CGSize = mainWindowMinimumSize
    ) -> Bool {
        if window.contentMinSize != minimumContentSize {
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

    static func applyModularZoomBehavior(
        to window: NSWindow,
        minimumContentSize: CGSize = mainWindowMinimumSize
    ) {
        if window.contentMinSize != minimumContentSize {
            window.contentMinSize = minimumContentSize
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
        if let window {
            // Main window always uses opaque adaptive background (never transparent)
            window.appearance = nil
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor

            if WindowPresentationPolicy.needsModularZoomBehavior(window) {
                WindowPresentationPolicy.applyModularZoomBehavior(to: window)
                return
            }
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

private struct LaunchIntegrityGateView<Content: View>: View {
    private enum Phase {
        case checking
        case ready
    }

    @State private var phase: Phase = .checking
    @State private var didStartGate = false

    let bootstrap: AppBootstrap
    let content: () -> Content

    var body: some View {
        Group {
            switch phase {
            case .checking:
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Verifying vault integrity...")
                        .font(.headline)
                    Text("Epistemos is validating local note storage before opening your workspace.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            case .ready:
                content()
            }
        }
        .task { @MainActor in
            guard !didStartGate else { return }
            didStartGate = true

            let report = await bootstrap.performStartupIntegrityCheck()
            if !report.shouldBlockAutomaticVaultRestore {
                bootstrap.vaultSync.restoreVaultFromBookmark()
            }

            phase = .ready
        }
    }
}

@main
struct EpistemosApp: App {
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    @NSApplicationDelegateAdaptor(EpistemosAppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()
    @AppStorage("epistemos.setupComplete") private var setupComplete = false

    var body: some Scene {
        Window("Epistemos", id: "main") {
            LaunchIntegrityGateView(bootstrap: bootstrap) {
                RootView(
                    databaseError: bootstrap.databaseError,
                    onResetDatabase: { bootstrap.resetDatabaseAndRelaunch() }
                )
                    .withAppEnvironment(bootstrap)
                    .sheet(isPresented: Binding(
                        get: { !setupComplete },
                        set: { if !$0 { setupComplete = true } }
                    )) {
                        SetupAssistantView {
                            setupComplete = true
                        }
                        .withAppEnvironment(bootstrap)
                    }
                    .background(ModularZoomWindowObserver().allowsHitTesting(false))
                    .onAppear {
                        guard !Self.isRunningTests else { return }
                        StatusBar.shared.setup()
                        HologramController.shared.setup(graphState: bootstrap.graphState, queryEngine: bootstrap.queryEngine, modelContainer: bootstrap.modelContainer, physicsCoordinator: bootstrap.physicsCoordinator, dialogueChatState: bootstrap.dialogueChatState)
                        // Restore last session after UI settles, then start tracking
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            bootstrap.workspaceService.autoRestore()
                            bootstrap.activityTracker.startTracking()
                            bootstrap.workspaceSummaryService.startAutoSummaryLoop()
                            bootstrap.workspaceService.startAutoSave()
                            // Generate a fresh welcome-back summary if workspace was restored
                            if bootstrap.workspaceService.welcomeBack != nil {
                                Task { @MainActor in
                                    await bootstrap.workspaceSummaryService.generateSummaryNow()
                                    // Update welcome-back with the fresh summary
                                    let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
                                    if let ws = try? bootstrap.modelContainer.mainContext.fetch(
                                        FetchDescriptor(predicate: predicate)
                                    ).first, !ws.summary.isEmpty {
                                        bootstrap.workspaceService.welcomeBack?.intentSummary = ws.summary
                                    }
                                }
                            }
                        }
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
                        // Teardown handled by EpistemosAppDelegate.applicationShouldTerminate / applicationWillTerminate
                    }
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
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var mainWindowObservers: [NSObjectProtocol] = []
    private var didTeardown = false
    private var quitObserver: NSObjectProtocol?
    private static let showQuitDialogKey = "epistemos.showSaveOnQuitDialog"

    private static var canConfigureUserNotificationCenter: Bool {
        let bundleURL = Bundle.main.bundleURL
        return bundleURL.pathExtension == "app"
            || bundleURL.deletingLastPathComponent().pathExtension == "app"
    }

    var showSaveOnQuitDialogEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: Self.showQuitDialogKey) == nil
            ? true
            : defaults.bool(forKey: Self.showQuitDialogKey)
    }

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

        if Self.canConfigureUserNotificationCenter {
            UNUserNotificationCenter.current().delegate = self
        }

        Task { @MainActor in
            NSApp.windows.forEach(Self.applyMainWindowPolicyIfNeeded(to:))
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard showSaveOnQuitDialogEnabled else {
            performTeardown()
            return .terminateNow
        }
        let hasOpenNotes = !NoteWindowManager.shared.orderedPageIds().isEmpty
        let hasOpenChats = !MiniChatWindowController.shared.openChatIds.isEmpty
        guard hasOpenNotes || hasOpenChats else {
            performTeardown()
            return .terminateNow
        }

        // Show a floating save panel above ALL windows (note editors, mini chats, etc.).
        // Borderless panel with frosted glass blur and rounded corners.
        QuitSavePanelController.showQuitSave { [weak self] shouldQuit in
            if shouldQuit {
                self?.performTeardown()
                NSApp.reply(toApplicationShouldTerminate: true)
            } else {
                NSApp.reply(toApplicationShouldTerminate: false)
            }
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Idempotent fallback — performTeardown guards against double calls
        performTeardown()
        let center = NotificationCenter.default
        mainWindowObservers.forEach(center.removeObserver)
        mainWindowObservers.removeAll()
    }

    private func performTeardown() {
        guard !didTeardown else { return }
        didTeardown = true
        guard !Self.isRunningTests else {
            StatusBar.shared.remove()
            HologramController.shared.teardown()
            return
        }
        guard let bootstrap = AppBootstrap.shared else { return }
        bootstrap.activityTracker.stopTracking()
        bootstrap.workspaceSummaryService.stopAutoSummaryLoop()
        bootstrap.workspaceService.stopAutoSave()
        bootstrap.workspaceService.autoSave()
        bootstrap.vaultSync.stopWatching(preserveData: true)
        StatusBar.shared.remove()
        HologramController.shared.teardown()
    }

    // Save-on-quit dialog is now handled via WorkspaceSavePanel (SwiftUI overlay).
    // The panel posts .proceedWithQuit when the user confirms, which triggers performTeardown + reply.

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

        let miniChat = NSMenuItem(
            title: "New Mini Chat", action: #selector(dockMiniChat), keyEquivalent: "")
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

    @objc private func dockMiniChat() {
        Task { @MainActor in
            MiniChatWindowController.shared.openNewChat()
        }
    }
}

// MARK: - Keyboard Commands

extension Notification.Name {
    static let toggleWorkspaceSwitcher = Notification.Name("epistemos.toggleWorkspaceSwitcher")
    static let toggleSessionIntelligence = Notification.Name("epistemos.toggleSessionIntelligence")
    static let toggleTimeMachine = Notification.Name("epistemos.toggleTimeMachine")
    static let showSaveWorkspacePanel = Notification.Name("epistemos.showSaveWorkspacePanel")
    static let showQuitSavePanel = Notification.Name("epistemos.showQuitSavePanel")
    static let proceedWithQuit = Notification.Name("epistemos.proceedWithQuit")
}

struct EpistemosCommands: Commands {
    let ui: UIState
    let chat: ChatState
    let notesUI: NotesUIState
    let vaultSync: VaultSyncService
    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Save Workspace...") {
                NotificationCenter.default.post(name: .showSaveWorkspacePanel, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button("Switch Workspace  \u{2303}\u{2318}W") {
                NotificationCenter.default.post(name: .toggleWorkspaceSwitcher, object: nil)
            }

            Button("Session Intelligence  \u{2303}\u{2318}R") {
                NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)
            }
        }

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

            Button("New Mini Chat") {
                MiniChatWindowController.shared.openNewChat()
            }
            .keyboardShortcut("3", modifiers: .command)

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

            Button("New Mini Chat") {
                MiniChatWindowController.shared.openNewChat()
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

    // Save workspace UI is now handled via WorkspaceSavePanel (SwiftUI overlay).
}
