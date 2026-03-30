import Foundation
import Testing

@Suite("MiniChat View Audit")
struct MiniChatViewAuditTests {
    @Test("mini chat uses native window tabs instead of an in-view tab strip")
    func miniChatUsesNativeWindowTabsInsteadOfAnInViewTabStrip() throws {
        let viewSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let controllerSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(!viewSource.contains("MiniChatTabBar"))
        #expect(!viewSource.contains("threadState.miniChatThreads()"))
        #expect(viewSource.contains("@State private var showRecentChats = false"))
        #expect(viewSource.contains("MiniChatRecentChatsList(recentChats: recentChats)"))
        #expect(controllerSource.contains("window.tabbingMode = .preferred"))
        #expect(controllerSource.contains("window.tabbingIdentifier = \"epistemos-mini-chat-tabs\""))
        #expect(controllerSource.contains("existingWindow.addTabbedWindow(window, ordered: .above)"))
        #expect(controllerSource.contains("func openChat("))
        #expect(controllerSource.contains("func openNewChat(attaching attachment: ContextAttachment? = nil)"))
    }

    @Test("recent mini chat selection restores persisted chat history instead of leaving a blank shell")
    func recentMiniChatSelectionRestoresPersistedChatHistory() throws {
        let viewSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let controllerSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(controllerSource.contains("func openChat(_ chatID: String)"))
        #expect(!controllerSource.contains("ensureMiniChatSession(id: chatID)"))
        #expect(viewSource.contains("let current = threadState.miniChatSession(id: chatID)"))
        #expect(viewSource.contains("let needsRestore = current == nil"))
        #expect(viewSource.contains("threadState.upsertMiniChatSession("))
        #expect(viewSource.contains("threadState.ensureMiniChatSession(id: chatID)"))
    }

    @Test("new mini chats can inherit the active note as removable context")
    func newMiniChatsCanInheritTheActiveNoteAsRemovableContext() throws {
        let viewSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let controllerSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(viewSource.contains("let initialContextAttachment: ContextAttachment?"))
        #expect(viewSource.contains("@State private var appliedInitialContextAttachment = false"))
        #expect(viewSource.contains("applyInitialContextAttachmentIfNeeded()"))
        #expect(viewSource.contains("threadState.addMiniChatContextAttachment(initialContextAttachment, chatID: chatID)"))
        #expect(controllerSource.contains("activeNoteAttachment(in: bootstrap)"))
        #expect(controllerSource.contains("MiniChatView(chatID: chatID, initialContextAttachment: initialContextAttachment)"))
    }

    @Test("fragile note attachment wiring stays connected from notes into full and mini chats")
    func fragileNoteAttachmentWiringStaysConnectedFromNotesIntoChats() throws {
        let noteWorkspaceSource = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let controllerSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let chatInputSource = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let threadStateSource = try loadRepoTextFile("Epistemos/State/ThreadState.swift")

        #expect(noteWorkspaceSource.contains("private var noteChatContextAttachment: ContextAttachment?"))
        #expect(noteWorkspaceSource.contains("MiniChatWindowController.shared.openNewChat(attaching: noteChatContextAttachment)"))

        #expect(controllerSource.contains("func openNewChat(attaching attachment: ContextAttachment? = nil)"))
        #expect(controllerSource.contains("resolvedAttachment = activeNoteAttachment(in: bootstrap)"))
        #expect(controllerSource.contains("openChat(UUID().uuidString, initialContextAttachment: resolvedAttachment)"))
        #expect(controllerSource.contains("let view = MiniChatView(chatID: chatID, initialContextAttachment: initialContextAttachment)"))

        #expect(miniChatSource.contains("applyInitialContextAttachmentIfNeeded()"))
        #expect(miniChatSource.contains("threadState.addMiniChatContextAttachment(initialContextAttachment, chatID: chatID)"))
        #expect(miniChatSource.contains("return ChatCoordinator.searchReferenceResults("))
        #expect(miniChatSource.contains("ComposerReferenceHelpers.contextAttachment(for: choice)"))
        #expect(miniChatSource.contains("ComposerReferenceHelpers.allNotesAttachment"))

        #expect(chatInputSource.contains("return ChatCoordinator.searchReferenceResults("))
        #expect(chatInputSource.contains("chat.addContextAttachment(ComposerReferenceHelpers.contextAttachment(for: choice))"))
        #expect(chatInputSource.contains("chat.addContextAttachment(ComposerReferenceHelpers.allNotesAttachment)"))

        #expect(threadStateSource.contains("let threadID = ensureMiniChatSession(id: chatID)"))
        #expect(threadStateSource.contains("if chatThreads[index].contextAttachments.contains(attachment) { return }"))
        #expect(threadStateSource.contains("chatThreads[index].contextAttachments.append(attachment)"))
    }

    @Test("chat model picker includes Apple Intelligence alongside local models")
    func chatModelPickerIncludesAppleIntelligenceAlongsideLocalModels() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let inferenceState = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(rootView.contains("Apple Intelligence"))
        #expect(rootView.contains("setPreferredChatModelSelection("))
        #expect(inferenceState.contains("enum ChatModelSelection"))
        #expect(inferenceState.contains("case appleIntelligence"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
