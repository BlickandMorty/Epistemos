import AppKit
import SwiftData
import SwiftUI

// MARK: - App Entry Point

@main
struct EpistemosApp: App {
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        Window("Epistemos", id: "main") {
            RootView()
                .environment(bootstrap.uiState)
                .environment(bootstrap.chatState)
                .environment(bootstrap.pipelineState)
                .environment(bootstrap.notesUI)
                .environment(bootstrap.researchState)
                .environment(bootstrap.soarState)
                .environment(bootstrap.eventBus)
                .environment(bootstrap.inferenceState)
                .environment(bootstrap.llmService)
                .environment(bootstrap.triageService)
                .environment(bootstrap.researchService)
                .environment(bootstrap.vaultSync)
                .environment(bootstrap.dailyBriefState)
                .environment(bootstrap.threadState)
                .onAppear {
                    StatusBar.shared.setup()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    bootstrap.vaultSync.stopWatching(preserveData: true)
                    StatusBar.shared.remove()
                }
        }
        .modelContainer(bootstrap.modelContainer)
        .commands {
            EpistemosCommands(
                ui: bootstrap.uiState, chat: bootstrap.chatState, notesUI: bootstrap.notesUI,
                vaultSync: bootstrap.vaultSync)
        }

        Window("Knowledge Graph", id: "graph") {
            GraphWindowView()
        }
        .modelContainer(bootstrap.modelContainer)
        .defaultSize(width: 1000, height: 700)
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
