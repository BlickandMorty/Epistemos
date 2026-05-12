import Foundation
import Testing

@testable import Epistemos

@Suite("Chat Presentation")
struct ChatPresentationTests {
  private var repoRootURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func repoFileExists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(
      atPath: repoRootURL.appendingPathComponent(relativePath).path
    )
  }

  @Test("streaming chat suppresses late reasoning once the visible answer has started")
  @MainActor func streamingChatSuppressesLateReasoningAfterAnswerStarts() {
    let chatState = ChatState()
    chatState.submitQuery("Analyze this.")
    chatState.startStreaming()

    chatState.appendStreamingThinking("Compare the core claims.")
    chatState.appendStreamingText(
      "## Analysis\n\nThe note distinguishes prediction from inevitability.")
    chatState.appendStreamingThinking("Keep the caveat with the final framing.")
    chatState.stopStreaming()

    #expect(chatState.streamingThinking == "Compare the core claims.")
    #expect(
      chatState.streamingText
        == "## Analysis\n\nThe note distinguishes prediction from inevitability."
    )
    #expect(!chatState.isThinkingActive)
    #expect(chatState.thinkingStartedAt != nil)
    #expect(chatState.thinkingEndedAt != nil)
  }

  @Test("streaming chat holds the first visible answer briefly after thinking")
  @MainActor func streamingChatHoldsFirstVisibleAnswerBrieflyAfterThinking() async {
    let chatState = ChatState()
    chatState.submitQuery("Analyze this.")
    chatState.startStreaming()

    chatState.appendStreamingThinking("Compare the core claims.")
    chatState.appendStreamingText("The note distinguishes prediction from inevitability.")

    #expect(chatState.streamingText.isEmpty)

    try? await Task.sleep(for: .milliseconds(650))

    #expect(
      chatState.streamingText
        == "The note distinguishes prediction from inevitability."
    )
  }

  @Test("streaming chat deduplicates a final reasoning snapshot after streamed reasoning deltas")
  @MainActor func streamingChatDeduplicatesFinalReasoningSnapshot() {
    let chatState = ChatState()
    chatState.submitQuery("Analyze this.")
    chatState.startStreaming()

    chatState.appendStreamingThinking("Checking the note")
    chatState.appendStreamingThinking(" structure")
    chatState.appendStreamingThinking("Checking the note structure")

    #expect(chatState.streamingThinking == "Checking the note structure")
  }

  @Test("session wake-up preview lock errors are shown as a calm temporary unavailability message")
  func sessionWakeUpPreviewLockErrorsUseHumanCopy() {
    let body = ChatCoordinator.sessionWakeUpPreviewBody(
      forErrorDescription: """
        Epistemos.AgentErrorFfi.AgentError(message: "Failed to open vault: index error: Failed to acquire Lockfile: LockBusy. Some(\\"Failed to acquire index lock. If you are using a regular directory, this means there is already an `IndexWriter` working on this `Directory`, in this process or in a different process.\\")")
        """
    )

    #expect(
      body
        == "Temporarily unavailable while the vault index is busy. This preview will refresh automatically."
    )
  }

  @Test("chat state can override the final visible answer before completion")
  @MainActor func chatStateCanOverrideTheFinalVisibleAnswerBeforeCompletion() {
    let chatState = ChatState()
    chatState.submitQuery("Find the note.")
    chatState.startStreaming()

    chatState.appendStreamingThinking("Trying the vault read.")
    chatState.appendStreamingText("Pretend success.")
    chatState.overrideStreamingAnswerForCompletion(
      "I couldn't verify that vault note read here."
    )

    #expect(chatState.streamingText == "I couldn't verify that vault note read here.")
    #expect(!chatState.isThinkingActive)
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

    #expect(
      blocks == [
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

    #expect(
      renderUnits == [
        "paragraph",
        "list:4",
      ])
  }

  @Test("chat markdown uses display typography for H1 through H3")
  func chatMarkdownUsesDisplayFontHierarchy() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/TaggedMarkdownTextView.swift")

    #expect(source.contains("if (1...3).contains(level) {"))
    #expect(source.contains("return AppDisplayTypography.font(size: fontSize, weight: weight, isDark: theme.isDark)"))
    #expect(source.contains("} else if (4...5).contains(level) {"))
    #expect(source.contains("return AppDisplayTypography.font(size: fontSize, weight: weight, allowDisplayFont: false)"))
    #expect(source.contains("return ClaudeAppTypography.monoFont(size: fontSize, weight: weight)"))
  }

  @Test("main chat light mode uses the landing background token")
  func mainChatLightModeUsesTheLandingBackgroundToken() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(!source.contains("retroMistLightChatBackground"))
    #expect(
      source.contains(
        "theme.isDark ? Color(red: 0.07, green: 0.07, blue: 0.07) : theme.resolved.background.color"
      ))
  }

  @Test("main chat composer light mode matches the landing background token")
  func mainChatComposerLightModeMatchesTheLandingBackgroundToken() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")

    #expect(!source.contains("seaGlassLightComposerBackground"))
    #expect(source.contains("lightModeSurfaceTint: theme.resolved.background.color"))
  }

  @Test("chat typography uses a softer monospaced body stack instead of Anthropic families")
  func chatTypographyUsesASofterMonospacedBodyStackInsteadOfAnthropicFamilies() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")

    #expect(source.contains("static func monoUIFont("))
    #expect(source.contains("NSFont.monospacedSystemFont(ofSize: size, weight: weight)"))
    #expect(source.contains("monoUIFont(size: size, weight: .regular)"))
    #expect(source.contains("monoUIFont(size: size, weight: .medium)"))
    #expect(!source.contains("\"Anthropic Serif\""))
    #expect(!source.contains("\"Anthropic Sans\""))
  }

  @Test("process disclosure detail blocks preserve multiline tool and thinking content")
  func processDisclosureDetailBlocksPreserveMultilineContent() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ProcessDisclosureViews.swift")

    #expect(!source.contains("ScrollView(.horizontal"))
    #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
  }

  @Test("chat markdown keeps paragraphs, lists, quotes, and code blocks vertically expanded")
  func chatMarkdownKeepsBlocksVerticallyExpanded() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/TaggedMarkdownTextView.swift")

    #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
    #expect(source.contains("Text(code)"))
  }

  @Test("main chat prompt style prefers reflective prose over outline-heavy answers")
  func mainChatPromptStylePrefersReflectiveProseOverOutlineHeavyAnswers() throws {
    let triageSource = try loadMirroredSourceTextFile("Epistemos/Engine/TriageService.swift")
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    let prosePreference =
      "Prefer flowing prose over outlines and bullet lists unless the user asks for structure or the material truly needs it."
    let reflectiveVoice =
      "Aim for a conversational, reflective voice that feels like thinking with the user, not lecturing at them."
    let provenanceGuardrail =
      "If the user asks you to find, open, summarize, copy, or edit a vault note, only say you found or read it after the vault lookup actually succeeded."
    let blockedLookupGuardrail =
      "If a required tool lookup is blocked, denied, or unreadable, say that plainly and stop instead of pretending the lookup succeeded."

    #expect(triageSource.contains(prosePreference))
    #expect(triageSource.contains(reflectiveVoice))
    #expect(triageSource.contains(provenanceGuardrail))
    #expect(triageSource.contains(blockedLookupGuardrail))
    #expect(coordinatorSource.contains("ChatResponseStyleGuide.mainChatSystemInstruction"))
    #expect(!coordinatorSource.contains("You are Epistemos Agent."))
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
    let artifactSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Chat/ArtifactBlockView.swift")
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

  @Test("main chat keeps tools mode visible and auto-promotes tool-heavy drafts")
  func mainChatKeepsToolsModeVisibleAndAutoPromotesToolHeavyDrafts() throws {
    let pickerSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Chat/ChatBrainPickerMenu.swift")
    let inputSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
    let capabilitySource = try loadMirroredSourceTextFile(
      "Epistemos/Engine/AgentHarness/ChatCapability.swift")
    let inferenceSource = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

    #expect(!pickerSource.contains("let visibleModes = modes.filter { $0 != .agent }"))
    #expect(pickerSource.contains("return modes.isEmpty ? [.fast] : modes"))
    #expect(
      inputSource.contains(
        "This needs tools. Tap to switch to OpenAI and keep it in the main chat."))
    #expect(inputSource.contains("Switch to OpenAI and keep this in the main chat with tools."))
    #expect(inputSource.contains("Auto-routes when your prompt needs tools or a longer run."))
    #expect(inputSource.contains("if predictedCapability == .agent"))
    #expect(inputSource.contains("operatingMode.wrappedValue = .agent"))
    #expect(capabilitySource.contains("case .agent: \"Tools\""))
    #expect(inferenceSource.contains("case .agent: \"Tools\""))
  }

  @Test("main chat runtime copy stays fused even when tools runs fail")
  func mainChatRuntimeCopyStaysFusedDuringToolFailures() throws {
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
    let legacyStateSource = try loadMirroredSourceTextFile("Epistemos/State/AgentChatState.swift")

    #expect(
      coordinatorSource.contains(
        "No response received. The tools run ended before a final answer was produced."))
    #expect(
      coordinatorSource.contains(
        "description: \"This chat requested \\(name) during a tools run.\""))
    #expect(
      !coordinatorSource.contains(
        "No response received. The agent stream ended before a final answer was produced."))
    #expect(
      !coordinatorSource.contains(
        "description: \"Agent requested \\(name) during local agent execution.\""))
    #expect(
      legacyStateSource.contains(
        "No response received. The tools run returned an empty stream — try again or switch models."
      ))
    #expect(
      !legacyStateSource.contains(
        "No response received. The agent returned an empty stream — try again or switch models."))
  }

  @Test("live chat route labels and summaries avoid stale agent and local only wording")
  func liveChatRouteLabelsAndSummariesStayFused() throws {
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")
    let diagnosticsSource = try loadMirroredSourceTextFile(
      "Epistemos/State/CommandCenterDiagnostics.swift")
    let overseerSource = try loadMirroredSourceTextFile("Epistemos/Engine/OverseerProtocol.swift")
    let compilerSource = try loadMirroredSourceTextFile(
      "Epistemos/Engine/CommandCenterRequestCompiler.swift")

    #expect(coordinatorSource.contains("return \"Direct Chat\""))
    #expect(coordinatorSource.contains("return \"Planned Tools\""))
    #expect(coordinatorSource.contains("return \"Managed Tools\""))
    #expect(!coordinatorSource.contains("return \"Local Only\""))
    #expect(!coordinatorSource.contains("return \"Managed Tools Session\""))

    #expect(diagnosticsSource.contains("case \"local_only\": return \"Direct Chat\""))
    #expect(
      diagnosticsSource.contains("case \"overseer_local_execution\": return \"Planned Tools\""))
    #expect(diagnosticsSource.contains("case \"managed_agent_session\": return \"Managed Tools\""))
    #expect(!diagnosticsSource.contains("case \"local_only\": return \"Local Only\""))

    #expect(overseerSource.contains("Answer directly in this chat without tools."))
    #expect(overseerSource.contains("Use a bounded tools plan in this chat."))
    #expect(
      overseerSource.contains(
        "Use the managed tools runtime for long-running external orchestration."))
    #expect(!overseerSource.contains("Escalate to the managed agent path"))
    #expect(!overseerSource.contains("Agent: /"))
    #expect(!overseerSource.contains("Agent: skill"))
    #expect(!overseerSource.contains("Agent: agent mode"))

    #expect(compilerSource.contains("summary: \"Tools: compile failed — \\(reason)\""))
    #expect(!compilerSource.contains("summary: \"Agent: compile failed — \\(reason)\""))
  }

  @Test("tool and thinking activity stay visible during streaming and after completion")
  func toolAndThinkingActivityStayVisibleAcrossTheTurn() throws {
    let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")
    let bubbleSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
    let stateSource = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    #expect(chatViewSource.contains("LiveActivityStrip("))
    #expect(chatViewSource.contains("ThinkingPopoverView("))
    #expect(chatViewSource.contains("ToolExecutionPreviewList("))
    #expect(chatViewSource.contains("blocks: chat.pendingContentBlocks"))

    #expect(bubbleSource.contains("ToolExecutionPreviewList(blocks: contentBlocks)"))

    #expect(stateSource.contains("pendingContentBlocks.append(.toolUse"))
    #expect(stateSource.contains("contentBlocks: completedContentBlocks"))

    #expect(
      coordinatorSource.contains(
        "chatState.recordToolUse(id: id, name: name, inputJson: inputJson)"))
    #expect(
      coordinatorSource.contains(
        "chatState.recordToolResult(toolUseId: id, result: result, isError: isError)"))
    #expect(coordinatorSource.contains("chatState.recordToolUse("))
    #expect(coordinatorSource.contains("chatState.recordToolResult("))
  }

  @Test(
    "main chat brain snapshots keep the visible mode even when the hidden tool runtime escalates")
  func mainChatBrainSnapshotsKeepTheVisibleMode() throws {
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    #expect(coordinatorSource.contains("operatingMode: operatingMode"))
    #expect(
      !coordinatorSource.contains(
        """
        let brainSnapshot = buildMainChatBrainSnapshot(
            originalQuery: query,
            resolvedQuery: effectiveQuery,
            operatingMode: effectiveOperatingMode,
        """
      )
    )
  }

  @Test("main chat brain snapshots reflect the runtime path that actually executed")
  func mainChatBrainSnapshotsReflectExecutedRuntimePath() throws {
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    #expect(
      coordinatorSource.contains(
        "let snapshotRouteContext = Self.mainChatBrainSnapshotRouteContext("))
    #expect(
      coordinatorSource.contains(
        "routeLabel: Self.mainChatRouteLabel(for: snapshotRouteContext.route)"))
    #expect(coordinatorSource.contains("routeSummary: snapshotRouteContext.summary"))
    #expect(coordinatorSource.contains("allowedToolNames: snapshotRouteContext.allowedToolNames"))
    #expect(
      coordinatorSource.contains(
        "return (route: nil, summary: \"Standard chat turn\", allowedToolNames: directToolNames)"))
  }

  @Test("main chat capability refresh stays honest during hidden local tool turns")
  func mainChatCapabilityRefreshStaysHonestDuringHiddenLocalToolTurns() throws {
    let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")
    let capabilitySource = try loadMirroredSourceTextFile(
      "Epistemos/Engine/AgentHarness/ChatCapability.swift")

    #expect(chatViewSource.contains(".onChange(of: pipeline.isProcessing)"))
    #expect(chatViewSource.contains(".onChange(of: chat.latestBrainSnapshot)"))
    #expect(chatViewSource.contains("let hasPlannedTools = !snapshot.allowedToolNames.isEmpty"))
    #expect(capabilitySource.contains("if isAgentExecuting {"))
    #expect(
      capabilitySource.contains(
        "Tools are active: web, files, long runs, and approval-gated actions may be in play."))
  }

  @Test("idle main chat capability stays on Tools when Tools mode is selected")
  func idleMainChatCapabilityStaysOnToolsWhenToolsModeIsSelected() throws {
    let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(
      chatViewSource.contains(
        "let effectiveSelection = inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)"
      ))
    #expect(chatViewSource.contains("let toolsModeSelected = selectedOperatingMode == .agent"))
    #expect(chatViewSource.contains("isAgentExecuting: toolsModeSelected || chat.isAgentExecuting"))
  }

  @Test("brain inspector labels the per-turn tool allowlist explicitly")
  func brainInspectorLabelsPerTurnToolAllowlistExplicitly() throws {
    let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(chatViewSource.contains("section(title: \"TOOLS THIS TURN\""))
    #expect(!chatViewSource.contains("section(title: \"THIS TURN'S TOOLS\""))
  }

  @Test("brain inspector renders the final assembled model input")
  func brainInspectorRendersFinalAssembledModelInput() throws {
    let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(chatViewSource.contains("capturedModelInput"))
    #expect(chatViewSource.contains("section(title: \"MODEL INPUT\""))
    #expect(chatViewSource.contains("detailRow(\"System\", \"System prompt\")"))
    #expect(chatViewSource.contains("detailRow(\"History\", \"Conversation before wrapping\")"))
    #expect(chatViewSource.contains("detailRow(\"Tools\", \"Tool definitions sent this turn\")"))
  }

  @Test("main chat composer exposes a dedicated slash trigger")
  func mainChatComposerExposesADedicatedSlashTrigger() throws {
    let inputSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")

    #expect(inputSource.contains("slashButton"))
    #expect(inputSource.contains("openSlashCommandMenu()"))
    #expect(inputSource.contains("helpText: \"Commands\""))
    #expect(inputSource.contains("title: \"/\""))
    #expect(inputSource.contains("supportedSlashCommands"))
    #expect(inputSource.contains("text = command.suggestedPrompt"))
    #expect(inputSource.contains("activeSelectedSlashCommand"))
    #expect(inputSource.contains("chat.queuePendingSlashCommand(activeSelectedSlashCommand)"))
  }

  @Test("brain inspector keeps empty and section copy short")
  func brainInspectorKeepsEmptyAndSectionCopyShort() throws {
    let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")
    let bubbleSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")

    #expect(chatViewSource.contains("Text(\"MODEL CONTEXT\")"))
    #expect(
      chatViewSource.contains(
        "Text(\"After you send, this shows the notes, files, tools, and routing for that turn. Use @ or attachments to preview context first.\")"
      ))
    #expect(
      bubbleSource.contains(
        "ProcessDisclosureDetailBlock(title: \"INPUT\", content: planDetail, tone: detailTone)"))
    #expect(!bubbleSource.contains("toolSection(title: \"Planned Action\", content: planDetail)"))
    #expect(!bubbleSource.contains("toolSection(title: \"Input\", content: planDetail)"))
  }

  @Test("chat coordinator captures final model input for direct and managed tool turns")
  func chatCoordinatorCapturesFinalModelInputForContextPanel() throws {
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    #expect(coordinatorSource.contains("modelInputCaptureHandler: { captured in"))
    #expect(coordinatorSource.contains("chatState.captureModelInput(captured)"))
    #expect(
      coordinatorSource.contains(
        "runtimeLabel: self.inferenceState.effectiveModelLabel(for: surfaceOperatingMode)"
      )
    )
    #expect(coordinatorSource.contains("toolDefinitionsJSON: Self.encodedToolDefinitionsJSON"))
  }

  @Test("managed chat context panel captures tool schemas from the live Rust registry")
  func managedChatContextPanelUsesRuntimeToolRegistry() throws {
    let coordinatorSource = try loadMirroredSourceTextFile("Epistemos/App/ChatCoordinator.swift")

    #expect(coordinatorSource.contains("ToolTierBridge("))
    #expect(coordinatorSource.contains("allowedToolNames: allowedTools"))
    #expect(
      !coordinatorSource.contains("OmegaToolRegistry.all.first(where: { $0.name == toolName })"))
  }

  @Test("main chat composer consumes primed fused-chat drafts from chat state")
  func mainChatComposerConsumesPrimedDrafts() throws {
    let inputSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
    let chatStateSource = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")

    #expect(chatStateSource.contains("var pendingComposerDraft: String?"))
    #expect(chatStateSource.contains("var pendingComposerDraftRevision: UInt = 0"))
    #expect(chatStateSource.contains("func primeComposerDraft(_ draft: String)"))
    #expect(chatStateSource.contains("func consumePendingComposerDraft() -> String?"))
    #expect(inputSource.contains("chat.pendingComposerDraftRevision"))
    #expect(inputSource.contains("chat.consumePendingComposerDraft()"))
  }

  @Test("graph chat handoff survives fusion by storing pending graph context on chat state")
  func fusedGraphChatHandoffStoresPendingContextOnChatState() throws {
    let chatStateSource = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")

    #expect(chatStateSource.contains("var pendingGraphChatRequest: GraphChatRequest?"))
    #expect(chatStateSource.contains("func primeGraphChatRequest(_ request: GraphChatRequest)"))
    #expect(chatStateSource.contains("func consumePendingGraphChatRequest() -> GraphChatRequest?"))
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
    let pillSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Shared/ChatCapabilityPill.swift")
    let thinkingSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Chat/ThinkingPopoverView.swift")

    #expect(!pillSource.contains("repeatForever("))
    #expect(!thinkingSource.contains("repeatForever("))
    #expect(pillSource.contains(".breathe("))
    #expect(thinkingSource.contains(".breathe("))
  }

  @Test("live thinking surface is inline rather than a detached popover")
  func liveThinkingSurfaceIsInlineRatherThanDetachedPopover() throws {
    let thinkingSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Chat/ThinkingPopoverView.swift")

    #expect(!thinkingSource.contains(".popover("))
    #expect(thinkingSource.contains("if isExpanded {"))
    #expect(thinkingSource.contains(".frame(maxHeight: 300)"))
  }

  @Test("thinking and tool surfaces share the minimal disclosure chrome")
  func thinkingAndToolSurfacesShareTheMinimalDisclosureChrome() throws {
    let streamingThinkingSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Chat/ThinkingPopoverView.swift")
    let persistedThinkingSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Chat/ThinkingTrailView.swift")
    let bubbleSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
    let activitySource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/LiveActivityStrip.swift")

    #expect(streamingThinkingSource.contains("ProcessDisclosureHeader("))
    #expect(!streamingThinkingSource.contains(".assistantInsetChrome("))
    #expect(persistedThinkingSource.contains("ProcessDisclosureHeader("))
    #expect(!persistedThinkingSource.contains(".background(.ultraThinMaterial"))
    #expect(bubbleSource.contains("ProcessDisclosureHeader("))
    #expect(bubbleSource.contains("ProcessDisclosureDetailBlock("))
    #expect(activitySource.contains("ProcessDisclosureHeader("))
  }

  @Test("main chat exposes a toggleable context side panel for transparency")
  func mainChatExposesAToggleableBrainSidePanelForContextTransparency() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(source.contains("@AppStorage(\"mainChat.showBrainPanel\") private var showBrainPanel = false"))
    #expect(source.contains("ChatBrainPanelView("))
    #expect(source.contains("chat.latestBrainSnapshot"))
    // Toolbar label uses "Context" (clear) rather than the opaque
    // "Brain" jargon the panel shipped with initially.
    #expect(source.contains("\"Hide Context\""))
    #expect(source.contains("\"Show Context\""))
  }

  @Test("main chat keeps the context window meter synced on appear and model changes")
  func mainChatKeepsTheContextWindowMeterSyncedOnAppearAndModelChanges() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(source.contains("syncContextWindowMetrics()"))
    #expect(source.contains("chat.syncContextWindowMetrics("))
    #expect(
      source.contains(
        "maxTokens: inference.chatSurfaceMaxContextTokens(for: selectedOperatingMode)"))
    #expect(source.contains(".onChange(of: mainChatOperatingModeRaw)"))
    #expect(source.contains(".onChange(of: inference.preferredChatModelSelection.rawValue)"))
    #expect(source.contains(".onChange(of: inference.activeAIProvider)"))
  }

  @Test("thinking lane appears before the first reasoning token on reasoning-capable turns")
  func thinkingLaneAppearsBeforeFirstReasoningTokenOnReasoningCapableTurns() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

    #expect(source.contains("let expectsThinkingUI ="))
    #expect(source.contains("selection.supportsThinking"))
    #expect(source.contains("selectedOperatingMode.capturesReasoningTrace"))
    #expect(
      source.contains(
        "if expectsThinkingUI || chat.isThinkingActive || !chat.streamingThinking.isEmpty {"))
  }

  @Test(
    "local thinking prompt explicitly asks models to emit hidden reasoning for the separate thinking panel"
  )
  func localThinkingPromptExplicitlyRequestsHiddenReasoningForThinkingPanel() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Engine/TriageService.swift")

    #expect(source.contains("emit that reasoning inside <think>...</think> tags"))
    #expect(source.contains("separate thinking panel"))
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

  @Test(
    "cache badge copy calls out provider prompt caching rather than implying local runtime cache")
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

  @Test(
    "inference settings local AI section avoids redundant tier rows and noisy per-model warnings")
  func inferenceSettingsAvoidRedundantTierRowsAndPerModelWarnings() throws {
    let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

    #expect(!source.contains("LabeledContent(\"Active Tier\")"))
    #expect(!source.contains("model.releasePickerVisibilityReason"))
  }

  @Test("local model UI separates chat memory, model file size, and this-mac memory copy")
  func localModelUISeparatesChatMemoryFromFileSizeAndHardware() throws {
    let rootSource = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
    let settingsSource = try loadMirroredSourceTextFile(
      "Epistemos/Views/Settings/SettingsView.swift")
    let aboutSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ModelAboutSheet.swift")
    let infrastructureSource = try loadMirroredSourceTextFile(
      "Epistemos/Engine/LocalModelInfrastructure.swift")

    #expect(rootSource.contains("minimumRecommendedInteractiveMemoryGB"))
    #expect(settingsSource.contains("minimumRecommendedInteractiveMemoryGB"))
    #expect(settingsSource.contains("localModelManager.hardwareSummary"))
    #expect(aboutSource.contains("specRow(\"Chat Memory\""))
    #expect(aboutSource.contains("specRow(\"Model Files\""))
    #expect(
      infrastructureSource.contains(
        "\"This Mac: \\(inference.hardwareCapabilitySnapshot.roundedMemoryGB) GB unified memory\""))
    #expect(
      infrastructureSource.contains(
        "\"Needs \\(model.minimumRecommendedInteractiveMemoryGB) GB for chat\""))
  }

  @Test("cloud model about sheet shows purpose guidance and readable token scales")
  func cloudModelAboutSheetShowsPurposeGuidanceAndReadableTokenScales() throws {
    let aboutSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ModelAboutSheet.swift")

    #expect(aboutSource.contains("specRow(\"Best For\", value: model.aboutSheetPurposeSummary)"))
    #expect(aboutSource.contains("String(format: \"%.1fK tokens\", Double(tokens) / 1_000)"))
    #expect(aboutSource.contains("return \"\\(tokens) tokens\""))
  }

  @Test("legacy agent command bar file is removed after fusion")
  func legacyAgentCommandBarFileIsRemovedAfterFusion() {
    #expect(!repoFileExists("Epistemos/Views/AgentCommandCenter/CommandBarView.swift"))
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

  @Test(
    "chat sidebar delete only clears the active session after a saved delete and surfaces failures")
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
