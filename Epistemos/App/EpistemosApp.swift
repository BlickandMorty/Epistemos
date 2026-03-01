import AppKit
import SwiftData
import SwiftUI

// MARK: - App Entry Point

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
                .onAppear {
                    StatusBar.shared.setup()
                    HologramController.shared.setup(graphState: bootstrap.graphState, queryEngine: bootstrap.queryEngine, modelContainer: bootstrap.modelContainer)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    bootstrap.vaultSync.stopWatching(preserveData: true)
                    StatusBar.shared.remove()
                    HologramController.shared.teardown()
                }
        }
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

final class EpistemosAppDelegate: NSObject, NSApplicationDelegate {

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
            AppBootstrap.shared?.uiState.toggleCommandPalette()
            NSApp.activate()
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func dockMiniChat() {
        Task { @MainActor in
            MiniChatWindowController.shared.toggle()
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
                ui.setActivePanel(.home)
                NSApp.activate()
                if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                    main.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Show Notes") { UtilityWindowManager.shared.show(.notes) }
                .keyboardShortcut("2", modifiers: .command)

            Button("Show Library & Research") { UtilityWindowManager.shared.show(.library) }
                .keyboardShortcut("3", modifiers: .command)

            Button("Knowledge Graph") {
                HologramController.shared.toggle()
            }
            .keyboardShortcut("g", modifiers: .command)

            Divider()

            Button("Open Settings") { UtilityWindowManager.shared.show(.settings) }
                .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Toggle Mini Chat") {
                MiniChatWindowController.shared.toggle()
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
                ui.toggleCommandPalette()
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandGroup(replacing: .appVisibility) {
            Button("Go Home") {
                chat.goHome()
                ui.setActivePanel(.home)
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
