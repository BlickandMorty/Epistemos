import Foundation
import Testing
@testable import Epistemos

@Suite("Chat Presentation")
struct ChatPresentationTests {
    @Test("streaming chat preserves late reasoning outside the visible answer")
    @MainActor func streamingChatPreservesLateReasoningOutsideVisibleAnswer() {
        let chatState = ChatState()
        chatState.submitQuery("Analyze this.")
        chatState.startStreaming()

        chatState.appendStreamingThinking("Compare the core claims.")
        chatState.appendStreamingText("## Analysis\n\nThe note distinguishes prediction from inevitability.")
        chatState.appendStreamingThinking("Keep the caveat with the final framing.")
        chatState.stopStreaming()

        #expect(
            chatState.streamingThinking ==
                "Compare the core claims.\n\nAfter-answer thought:\nKeep the caveat with the final framing."
        )
        #expect(
            chatState.streamingText ==
                "## Analysis\n\nThe note distinguishes prediction from inevitability."
        )
        #expect(!chatState.isThinkingActive)
        #expect(chatState.thinkingStartedAt != nil)
        #expect(chatState.thinkingEndedAt != nil)
    }

    @Test("transcript rows precompute assistant presentation metadata")
    func transcriptRowsPrecomputeAssistantPresentationMetadata() {
        let messages = [
            ChatMessage(chatId: "chat", role: .user, content: "How does this work?"),
            ChatMessage(
                chatId: "chat",
                role: .assistant,
                content: """
                Sure, here's the answer in brief.

                See [Paper](https://example.com/paper) for details.
                """,
                loadedNoteTitles: ["Field Notes"]
            ),
        ]

        let rows = makeChatTranscriptRows(from: messages, chatTitle: nil)

        #expect(rows.count == 2)
        #expect(rows[0].displayContent == "How does this work?")
        #expect(rows[0].heading == nil)
        #expect(rows[0].sourceReferences.isEmpty)
        #expect(rows[1].originalQuery == "How does this work?")
        #expect(rows[1].heading == nil)
        #expect(rows[1].sourceReferences.count == 2)
        #expect(rows[1].sourceReferences[0].kind == AssistantSourceKind.note)
        #expect(rows[1].sourceReferences[0].title == "Field Notes")
        #expect(rows[1].sourceReferences[1].url?.absoluteString == "https://example.com/paper")
    }

    @Test("markdown block cache reuses repeated content")
    func markdownBlockCacheReusesRepeatedContent() {
        TaggedMarkdownTextView.resetBlockCacheForTesting()

        let content = """
        ## Title

        Paragraph

        - one
        - two
        """

        let firstCount = TaggedMarkdownTextView.cachedBlockCount(for: content)
        let firstStats = TaggedMarkdownTextView.blockCacheStatsForTesting()
        let secondCount = TaggedMarkdownTextView.cachedBlockCount(for: content)
        let secondStats = TaggedMarkdownTextView.blockCacheStatsForTesting()

        #expect(firstCount == 4)
        #expect(secondCount == firstCount)
        #expect(firstStats.hits == 0)
        #expect(firstStats.misses == 1)
        #expect(secondStats.hits == 1)
        #expect(secondStats.misses == 1)
    }

    @Test("chat markdown parser preserves nested and task list metadata")
    func chatMarkdownParserPreservesNestedAndTaskListMetadata() {
        let content = """
        - Top level
          - Nested bullet
        - [x] Completed task
        1. First step
          2. Nested step
        """

        let blocks = TaggedMarkdownTextView.debugBlockSummaries(for: content)

        #expect(blocks == [
            "bullet@0:Top level",
            "bullet@1:Nested bullet",
            "check@0:true:Completed task",
            "numbered@0:1.:First step",
            "numbered@1:2.:Nested step",
        ])
    }

    @Test("chat markdown groups consecutive list items into one tight render run")
    func chatMarkdownGroupsConsecutiveListItemsIntoOneRenderRun() {
        let content = """
        Intro paragraph

        - One
        - Two
        - [ ] Three
        1. Four
        """

        let renderUnits = TaggedMarkdownTextView.debugRenderUnitSummaries(for: content)

        #expect(renderUnits == [
            "paragraph",
            "list:4",
        ])
    }

    @Test("chat H1 and H2 markdown keep the retro display font path")
    func chatH1AndH2MarkdownKeepTheRetroDisplayFontPath() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/TaggedMarkdownTextView.swift")

        #expect(source.contains("if level == 1 || level == 2"))
        #expect(source.contains("return .custom(AppDisplayTypography.displayFontName, size: fontSize)"))
    }

    @Test("chat typography references Claude's Anthropic font families")
    func chatTypographyReferencesClaudesAnthropicFontFamilies() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(source.contains("\"Anthropic Serif\""))
        #expect(source.contains("\"Anthropic Sans\""))
    }

    @Test("artifact cards expose a rendered versus markdown presentation toggle")
    func artifactCardsExposeARenderedVersusMarkdownPresentationToggle() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ArtifactBlockView.swift")

        #expect(source.contains("MarkdownDocumentModeToggle(mode: documentPresentationModeBinding)"))
        #expect(source.contains("case .csv, .table, .markdown:"))
        #expect(source.contains("rawSourceContent"))
    }

    @Test("chat export surfaces use the shared text export helper instead of silent raw writes")
    func chatExportSurfacesUseSharedTextExportHelper() throws {
        let messageSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let artifactSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ArtifactBlockView.swift")
        let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

        #expect(messageSource.contains("ChatTextExportSupport.save("))
        #expect(artifactSource.contains("ChatTextExportSupport.save("))
        #expect(chatViewSource.contains("ChatTextExportSupport.save("))
        #expect(!messageSource.contains("try? fullContent.write(to: url"))
        #expect(!artifactSource.contains("try? content.write(to: url"))
        #expect(!chatViewSource.contains("try md.write(to: url"))
    }

    @Test("tool preview cards auto-expand while running and preserve manual toggles")
    func toolPreviewCardsAutoExpandWhileRunningAndPreserveManualToggles() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")

        #expect(source.contains("@State private var isExpanded: Bool"))
        #expect(source.contains("@State private var userManuallyToggled = false"))
        #expect(source.contains("self._isExpanded = State(initialValue: isActivelyRunning)"))
        #expect(source.contains("userManuallyToggled = true"))
    }

    @Test("chat brain picker keeps the shared main-chat operating mode preference key")
    func chatBrainPickerKeepsSharedOperatingModePreferenceKey() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")

        #expect(source.contains("enum MainChatOperatingModePreference"))
        #expect(source.contains("static let defaultsKey = \"epistemos.mainChatOperatingMode\""))
    }

    @Test("chat brain picker delegates the runtime UI to the shared local model toolbar menu")
    func chatBrainPickerDelegatesToSharedRuntimePopover() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")

        #expect(source.contains("operatingMode: Binding<EpistemosOperatingMode>?"))
        #expect(source.contains("availableOperatingModes: [EpistemosOperatingMode]?"))
        #expect(source.contains("LocalModelToolbarMenu("))
        #expect(!source.contains("Menu {"))
    }

    @Test("shared local model toolbar exposes split toolbar controls for mode model and routing")
    func localModelToolbarUsesSplitToolbarControls() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(source.contains("splitToolbarControls"))
        #expect(source.contains("modePopover"))
        #expect(source.contains("modelPopover"))
        #expect(source.contains("routingPopover"))
        #expect(source.contains("temporaryChatButton"))
    }

    @Test("shared local model toolbar exposes effort and native capability controls when supported")
    func localModelToolbarExposesEffortAndNativeCapabilityControls() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(source.contains("supportsRuntimeEffortButton"))
        #expect(source.contains("supportsProviderNativeControlsButton"))
        #expect(source.contains("effortPopover"))
        #expect(source.contains("nativeControlsPopover"))
        #expect(source.contains("effortButtonTitle"))
        #expect(source.contains("nativeControlsButtonTitle"))
    }

    @Test("chat capability surfaces avoid repeatForever pulse loops")
    func chatCapabilitySurfacesAvoidRepeatForeverPulseLoops() throws {
        let pillSource = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ChatCapabilityPill.swift")
        let thinkingSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ThinkingPopoverView.swift")

        #expect(!pillSource.contains("repeatForever("))
        #expect(!thinkingSource.contains("repeatForever("))
        #expect(pillSource.contains(".breathe("))
        #expect(thinkingSource.contains(".breathe("))
    }

    @Test("live thinking surface is inline rather than a detached popover")
    func liveThinkingSurfaceIsInlineRatherThanDetachedPopover() throws {
        let thinkingSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ThinkingPopoverView.swift")

        #expect(!thinkingSource.contains(".popover("))
        #expect(thinkingSource.contains("if isExpanded {"))
        #expect(thinkingSource.contains(".frame(maxHeight: 300)"))
    }

    @Test("main chat exposes a toggleable context side panel for transparency")
    func mainChatExposesAToggleableBrainSidePanelForContextTransparency() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

        #expect(source.contains("@State private var showBrainPanel = false"))
        #expect(source.contains("ChatBrainPanelView("))
        #expect(source.contains("chat.latestBrainSnapshot"))
        // Toolbar label uses "Context" (clear) rather than the opaque
        // "Brain" jargon the panel shipped with initially.
        #expect(source.contains("\"Hide Context\""))
        #expect(source.contains("\"Show Context\""))
    }

    @Test("streaming indicator shows an explicit loading-model state before first token")
    func streamingIndicatorShowsLoadingModelState() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

        #expect(source.contains("@Environment(PipelineState.self) private var pipeline"))
        #expect(source.contains("@Environment(InferenceState.self) private var inference"))
        #expect(source.contains("pipeline.isProcessing && !chat.isStreaming && !chat.isAgentExecuting"))
        #expect(source.contains("Text(\"Loading \\(inference.activeChatModelDisplayName)…\")"))
        #expect(source.contains(".foregroundStyle(theme.textSecondary)"))
    }

    @Test("cache badge copy calls out provider prompt caching rather than implying local runtime cache")
    func cacheBadgeCopyCallsOutProviderPromptCaching() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")

        #expect(source.contains("provider prompt cache"))
        #expect(source.contains("cloud and local providers"))
    }

    @Test("chat runtime popover keeps a single settings entry point")
    func chatRuntimePopoverKeepsASingleSettingsEntryPoint() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let openSettingsCount = source.components(separatedBy: "Button(\"Open Settings\")").count - 1

        #expect(openSettingsCount == 1)
    }

    @Test("inference settings local AI section avoids redundant tier rows and noisy per-model warnings")
    func inferenceSettingsAvoidRedundantTierRowsAndPerModelWarnings() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(!source.contains("LabeledContent(\"Active Tier\")"))
        #expect(!source.contains("model.releasePickerVisibilityReason"))
    }

    @Test("local model UI separates chat memory, model file size, and this-mac memory copy")
    func localModelUISeparatesChatMemoryFromFileSizeAndHardware() throws {
        let rootSource = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let aboutSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ModelAboutSheet.swift")
        let infrastructureSource = try loadMirroredSourceTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")

        #expect(rootSource.contains("minimumRecommendedInteractiveMemoryGB"))
        #expect(settingsSource.contains("minimumRecommendedInteractiveMemoryGB"))
        #expect(settingsSource.contains("localModelManager.hardwareSummary"))
        #expect(aboutSource.contains("specRow(\"Chat Memory\""))
        #expect(aboutSource.contains("specRow(\"Model Files\""))
        #expect(infrastructureSource.contains("\"This Mac: \\(inference.hardwareCapabilitySnapshot.roundedMemoryGB) GB unified memory\""))
        #expect(infrastructureSource.contains("\"Needs \\(model.minimumRecommendedInteractiveMemoryGB) GB for chat\""))
    }

    @Test("cloud model about sheet shows purpose guidance and readable token scales")
    func cloudModelAboutSheetShowsPurposeGuidanceAndReadableTokenScales() throws {
        let aboutSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ModelAboutSheet.swift")

        #expect(aboutSource.contains("specRow(\"Best For\", value: model.aboutSheetPurposeSummary)"))
        #expect(aboutSource.contains("String(format: \"%.1fK tokens\", Double(tokens) / 1_000)"))
        #expect(aboutSource.contains("return \"\\(tokens) tokens\""))
    }

    @Test("agent command bar shows an explicit loading-model state before first token")
    func agentCommandBarShowsLoadingModelState() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/AgentCommandCenter/CommandBarView.swift")

        #expect(source.contains("private var isLoadingModel: Bool"))
        #expect(source.contains("agentChat.streamingThinking"))
        #expect(source.contains("private var activeBrainLoadingLabel: String"))
        #expect(source.contains("Text(isLoadingModel ? activeBrainLoadingLabel : \"Running\")"))
    }

    @Test("chat text export support writes content and throws for unwritable destinations")
    func chatTextExportSupportWritesContentAndThrowsForUnwritableDestinations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "chat-export-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("message.md")
        try ChatTextExportSupport.write("export body", to: fileURL)

        let written = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(written == "export body")

        #expect(throws: CocoaError.self) {
            try ChatTextExportSupport.write("should fail", to: directory)
        }
    }

    @Test("chat sidebar delete only clears the active session after a saved delete and surfaces failures")
    func chatSidebarDeleteDefersClearingUntilSaveSucceeds() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")

        let saveRange = try #require(source.range(of: "try modelContext.save()"))
        let clearRange = try #require(source.range(of: "chat.clearMessages()"))

        #expect(!source.contains("modelContext.rollback()"))
        #expect(source.contains("modelContext.insert(sdChat)"))
        #expect(source.contains("sdChat.messages = originalMessages"))
        #expect(source.contains("deleteErrorMessage = error.localizedDescription"))
        #expect(source.contains(".alert(\"Couldn't Delete Chat\""))
        #expect(saveRange.lowerBound < clearRange.lowerBound)
    }
}
