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
        let mentionSource = try loadRepoTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")
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

        #expect(chatInputSource.contains("return ChatCoordinator.searchReferenceResults("))
        // Phase R.4 backfill: ChatInputBar now passes the active vault
        // ID so the attachment carries a canonical `vault://{...}/note/{...}`
        // URI. We match the new signature (with vaultId) to pin the
        // wiring in place; the older no-vaultId form is still live in
        // MiniChat and Landing until those sites migrate.
        #expect(chatInputSource.contains(
            "ComposerReferenceHelpers.contextAttachment(\n"
            + "                for: choice,\n"
            + "                vaultId: vaultId\n"
            + "            )"
        ))

        #expect(mentionSource.contains("case .allNotes:"))
        #expect(mentionSource.contains("static var allNotesAttachment: ContextAttachment"))

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

    @Test("chat stop handlers clear active streaming UI immediately")
    func chatStopHandlersClearActiveStreamingUIImmediately() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let mainChatSource = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")
        let coordinatorSource = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")

        #expect(miniChatSource.contains("private func cancelStream() {"))
        #expect(miniChatSource.contains("isProcessing = false"))
        #expect(miniChatSource.contains("threadState.setMiniChatStreaming(false, chatID: chatID)"))
        #expect(miniChatSource.contains("threadState.setMiniChatStreamingText(\"\", chatID: chatID)"))
        #expect(miniChatSource.contains("streamTask?.cancel()"))
        #expect(miniChatSource.contains("AppBootstrap.shared?.queryTask?.cancel()"))
        #expect(mainChatSource.contains("if pipeline.isProcessing || chat.isStreaming"))
        #expect(!mainChatSource.contains("if chat.isStreaming || !chat.streamingText.isEmpty"))
        #expect(coordinatorSource.contains("pipelineService.cancelActiveRun()"))
    }

    @Test("mini chat shows an explicit loading-model label before first visible token")
    func miniChatShowsExplicitLoadingModelLabel() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(miniChatSource.contains("@Environment(InferenceState.self) private var inference"))
        #expect(miniChatSource.contains("analyzingText: \"Loading \\(inference.activeChatModelDisplayName)…\""))
    }

    @Test("mini chat keeps streaming output on the filtered user-facing text path")
    func miniChatStreamingPathKeepsReasoningOutOfVisibleOutput() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let triageSource = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(miniChatSource.contains("UserFacingModelOutput.streamingVisibleText("))
        #expect(miniChatSource.contains("let final = UserFacingModelOutput.finalVisibleText(from: accumulated)"))
        #expect(miniChatSource.contains("let partial = UserFacingModelOutput.finalVisibleText("))
        #expect(miniChatSource.contains("for try await chunk in triage.streamGeneral("))
        #expect(triageSource.contains("private func userFacingStream("))
        #expect(triageSource.contains("UserFacingModelOutput.streamingVisibleText(from: rawText)"))
        #expect(triageSource.contains("let finalVisibleText = UserFacingModelOutput.finalVisibleText(from: rawText)"))
    }

    @Test("mini chat escalates tool-worthy turns through the shared coordinator path")
    func miniChatEscalatesToolWorthyTurnsThroughSharedCoordinatorPath() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let coordinatorSource = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")

        #expect(miniChatSource.contains("private func shouldUseSharedCoordinator(for query: String) -> Bool"))
        #expect(miniChatSource.contains("let shouldUseSharedCoordinator = shouldUseSharedCoordinator(for: trimmed)"))
        #expect(miniChatSource.contains("try await runSharedCoordinatorTurn("))
        #expect(miniChatSource.contains("mirrorSharedCoordinatorState("))
        #expect(coordinatorSource.contains("func handleMiniChatQuery("))
    }

    @Test("mini chat preserves reasoning traces for assistant turns")
    func miniChatPreservesReasoningTracesForAssistantTurns() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let threadStateSource = try loadRepoTextFile("Epistemos/State/ThreadState.swift")
        let messageSource = try loadRepoTextFile("Epistemos/Models/SDMessage.swift")

        #expect(miniChatSource.contains("reasoningSink: { delta in"))
        #expect(miniChatSource.contains("threadState.appendMiniChatStreamingThinking(delta, chatID: chatID)"))
        #expect(miniChatSource.contains("ThinkingTrailView("))
        #expect(miniChatSource.contains("message.thinkingTrace"))
        #expect(threadStateSource.contains("private var miniChatStreamingThinkingByID: [String: String] = [:]"))
        #expect(threadStateSource.contains("func appendMiniChatStreamingThinking(_ delta: String, chatID: String)"))
        #expect(messageSource.contains("var thinkingTrace: String?"))
        #expect(messageSource.contains("var thinkingDurationSeconds: Double?"))
    }

    @Test("mini chat shared coordinator preserves tool blocks and live tool activity")
    func miniChatSharedCoordinatorPreservesToolBlocksAndLiveToolActivity() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let threadStateSource = try loadRepoTextFile("Epistemos/State/ThreadState.swift")
        let chatTypesSource = try loadRepoTextFile("Epistemos/Models/ChatTypes.swift")
        let messageSource = try loadRepoTextFile("Epistemos/Models/SDMessage.swift")

        #expect(chatTypesSource.contains("var contentBlocks: [MessageContentBlock]?"))
        #expect(miniChatSource.contains("ToolExecutionPreviewList(blocks: contentBlocks)"))
        #expect(miniChatSource.contains("contentBlocks: restoredMessage.contentBlocks"))
        #expect(miniChatSource.contains("contentBlocks: message.contentBlocks"))
        #expect(miniChatSource.contains("threadState.setMiniChatActiveTool("))
        #expect(miniChatSource.contains("threadState.setMiniChatPendingContentBlocks("))
        #expect(threadStateSource.contains("private var miniChatPendingContentBlocksByID"))
        #expect(threadStateSource.contains("private var miniChatActiveToolNameByID"))
        #expect(threadStateSource.contains("func setMiniChatPendingContentBlocks("))
        #expect(threadStateSource.contains("func setMiniChatActiveTool("))
        #expect(messageSource.contains("func setContentBlocks(_ blocks: [MessageContentBlock]?)"))
        #expect(miniChatSource.contains("stored.setContentBlocks(message.contentBlocks)"))
    }

    @Test("mini chat exposes shared tools modes without routing into Omega")
    func miniChatExposesSharedToolsModesWithoutOmega() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(miniChatSource.contains("private var supportedOperatingModes: [EpistemosOperatingMode]"))
        #expect(!miniChatSource.contains("filter { $0 != .agent }"))
        #expect(miniChatSource.contains("availableOperatingModes("))
        #expect(miniChatSource.contains("for: inference.preferredChatModelSelection"))
        #expect(miniChatSource.contains("availableOperatingModes: supportedOperatingModes"))
        #expect(miniChatSource.contains("case .agent, .pro:"))
        #expect(miniChatSource.contains(".onChange(of: inference.preferredChatModelSelection.rawValue)"))
        #expect(!miniChatSource.contains("UtilityWindowManager.shared.show(.omega)"))
        #expect(!miniChatSource.contains("await orchestrator.submitTask"))
    }

    @Test("mini chat capability pill treats explicit tools mode as tools instead of thinking")
    func miniChatCapabilityPillTreatsExplicitToolsModeAsTools() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(miniChatSource.contains("let toolsModeSelected = selectedOperatingMode == .agent"))
        #expect(miniChatSource.contains("isAgentExecuting: toolsModeSelected || isUsingSharedCoordinator || draftCapabilityPrediction.predicted == .agent"))
        #expect(miniChatSource.contains("isThinkingMode: selectedOperatingMode == .thinking"))
    }

    @Test("mini chat scroll follow uses shared bool hysteresis instead of rewriting state every geometry tick")
    func miniChatScrollFollowUsesSharedBoolHysteresis() throws {
        let miniChatSource = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(miniChatSource.contains(".onScrollGeometryChange("))
        #expect(miniChatSource.contains("for: Bool.self"))
        #expect(miniChatSource.contains("ScrollStability.followMode(for: geometry, from: autoFollow)"))
        #expect(miniChatSource.contains("guard isFollowingBottom != autoFollow.isFollowingBottom else { return }"))
        #expect(miniChatSource.contains("autoFollow.setFollowingBottom(isFollowingBottom)"))
        #expect(!miniChatSource.contains("for: CGFloat.self"))
        #expect(!miniChatSource.contains("ScrollStability.distanceToBottom(for:)"))
        #expect(!miniChatSource.contains("autoFollow = nextState"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
