import Testing
@testable import Epistemos

@MainActor
struct AgentChatStateTests {

    // MARK: - Session Lifecycle

    @Test func newSessionClearsState() {
        let state = AgentChatState()
        state.messages = [ChatMessage(id: "1", chatId: "s", role: .user, content: "hello")]
        state.hasMessages = true
        state.agentTurnCount = 3

        state.startNewSession()

        #expect(state.messages.isEmpty)
        #expect(!state.hasMessages)
        #expect(state.agentTurnCount == 0)
        #expect(state.activeSessionId != nil)
        #expect(!state.isStreaming)
    }

    // MARK: - Message Submission

    @Test func submitAgentQuery() {
        let state = AgentChatState()
        state.submitAgentQuery("what is Swift?")

        #expect(state.messages.count == 1)
        #expect(state.messages.first?.role == .user)
        #expect(state.messages.first?.content == "what is Swift?")
        #expect(state.hasMessages)
        #expect(state.activeSessionId != nil)
    }

    @Test func submitCreatesSessionIfNeeded() {
        let state = AgentChatState()
        #expect(state.activeSessionId == nil)
        state.submitAgentQuery("test")
        #expect(state.activeSessionId != nil)
    }

    // MARK: - Streaming

    @Test func startStreaming() {
        let state = AgentChatState()
        state.startStreaming()
        #expect(state.isStreaming)
    }

    @Test func stopStreaming() {
        let state = AgentChatState()
        state.startStreaming()
        state.stopStreaming()
        #expect(!state.isStreaming)
    }

    // MARK: - Tool Tracking

    @Test func recordToolUse() {
        let state = AgentChatState()
        state.recordToolUse(id: "tu1", name: "safari_search", inputJson: "{\"query\":\"test\"}")
        #expect(state.activeToolName == "safari_search")
        #expect(state.isAgentExecuting)
    }

    @Test func recordToolResult() {
        let state = AgentChatState()
        state.recordToolUse(id: "tu1", name: "safari_search", inputJson: "{}")
        state.recordToolResult(toolUseId: "tu1", result: "found results", isError: false, durationMs: 150)

        #expect(state.activeToolName == nil)
        #expect(state.toolHistory.count == 1)
        #expect(state.toolHistory.first?.toolName == "safari_search")
        #expect(state.toolHistory.first?.durationMs == 150)
        #expect(!(state.toolHistory.first?.isError ?? true))
    }

    // MARK: - Context Tracking

    @Test func contextUsageFraction() {
        let state = AgentChatState()
        state.estimatedContextTokens = 64_000
        state.maxContextTokens = 128_000
        #expect(abs(state.contextUsageFraction - 0.5) < 0.01)
    }

    @Test func contextUsageClamped() {
        let state = AgentChatState()
        state.estimatedContextTokens = 200_000
        state.maxContextTokens = 128_000
        #expect(state.contextUsageFraction == 1.0)
    }

    // MARK: - Isolation from Main ChatState

    @Test func separateFromMainChatState() {
        let agentChat = AgentChatState()
        let mainChat = ChatState()

        agentChat.submitAgentQuery("agent query")
        #expect(mainChat.messages.isEmpty)
        #expect(!agentChat.messages.isEmpty)
    }

    // MARK: - Clear

    @Test func clearMessages() {
        let state = AgentChatState()
        state.submitAgentQuery("test")
        state.agentTurnCount = 5
        state.toolHistory = [ACCToolExecutionRecord(
            toolName: "test", inputSummary: "", resultSummary: "",
            durationMs: 0, isError: false
        )]

        state.clearMessages()

        #expect(state.messages.isEmpty)
        #expect(!state.hasMessages)
        #expect(state.activeSessionId == nil)
        #expect(state.agentTurnCount == 0)
        #expect(state.toolHistory.isEmpty)
    }

    @Test func mainChatBrainSnapshotClearsWithConversationReset() {
        let state = ChatState()
        state.setCurrentChat("chat-brain")
        state.captureBrainSnapshot(
            ChatBrainSnapshot(
                capturedAt: Date(timeIntervalSince1970: 0),
                query: "Review this thread",
                resolvedQuery: "Current request:\nReview this thread",
                operatingMode: .agent,
                routeLabel: "Managed agent session",
                routeSummary: "Managed agent session",
                providerLabel: "OpenAI",
                modelLabel: "GPT-5",
                allowedToolNames: ["web_search"],
                loadedNoteTitles: ["Graph Notes"],
                contextAttachments: [
                    ContextAttachment(kind: .note, targetId: "note-1", title: "Graph Notes"),
                ],
                sections: [
                    ChatBrainSection(title: "Workspace Awareness", body: "Recent graph edits"),
                ]
            )
        )

        #expect(state.latestBrainSnapshot?.sections.count == 1)
        state.startNewChat()
        #expect(state.latestBrainSnapshot == nil)
    }

    @Test func mainChatBrainSnapshotUpdatesSectionsForMatchingTurnOnly() {
        let state = ChatState()
        state.setCurrentChat("chat-brain")
        let capturedAt = Date(timeIntervalSince1970: 42)
        state.captureBrainSnapshot(
            ChatBrainSnapshot(
                capturedAt: capturedAt,
                query: "Review this thread",
                resolvedQuery: "Current request:\nReview this thread",
                operatingMode: .agent,
                routeLabel: "Managed agent session",
                routeSummary: "Managed agent session",
                providerLabel: "OpenAI",
                modelLabel: "GPT-5",
                allowedToolNames: ["web_search"],
                loadedNoteTitles: ["Graph Notes"],
                contextAttachments: [],
                sections: [
                    ChatBrainSection(title: "Workspace Awareness", body: "Recent graph edits"),
                ]
            )
        )

        state.updateBrainSnapshotSection(
            ChatBrainSection(title: "Session Wake-Up Context", body: "<session-context>"),
            matchingCapturedAt: capturedAt
        )
        state.updateBrainSnapshotSection(
            ChatBrainSection(title: "Session Wake-Up Context", body: "updated"),
            matchingCapturedAt: capturedAt
        )
        state.updateBrainSnapshotSection(
            ChatBrainSection(title: "Should Not Apply", body: "stale"),
            matchingCapturedAt: Date(timeIntervalSince1970: 43)
        )

        #expect(state.latestBrainSnapshot?.sections.count == 2)
        #expect(
            state.latestBrainSnapshot?.sections.contains(
                ChatBrainSection(title: "Workspace Awareness", body: "Recent graph edits")
            ) == true
        )
        #expect(
            state.latestBrainSnapshot?.sections.contains(
                ChatBrainSection(title: "Session Wake-Up Context", body: "updated")
            ) == true
        )
    }

    // MARK: - Thinking popover lifecycle

    @Test("streaming thinking deltas populate the popover state")
    func appendStreamingThinkingActivatesPopover() {
        let state = AgentChatState()
        state.startStreaming()

        #expect(!state.isThinkingActive)
        #expect(state.streamingThinking.isEmpty)

        state.appendStreamingThinking("considering")
        state.appendStreamingThinking(" options")

        #expect(state.isThinkingActive)
        #expect(state.thinkingStartedAt != nil)
        #expect(state.thinkingEndedAt == nil)
        #expect(state.streamingThinking == "considering options")
    }

    @Test("first text delta closes the thinking phase")
    func firstTextDeltaClosesThinking() {
        let state = AgentChatState()
        state.startStreaming()
        state.appendStreamingThinking("thought")

        #expect(state.isThinkingActive)

        state.appendStreamingText("answer")

        #expect(!state.isThinkingActive)
        #expect(state.thinkingEndedAt != nil)
        #expect(state.streamingThinking == "thought")
    }

    @Test("late reasoning deltas are ignored after the answer has started")
    func lateReasoningDoesNotReopenThinkingAfterAnswerStarts() {
        let state = AgentChatState()
        state.startStreaming()
        state.appendStreamingThinking("thought")
        state.appendStreamingText("answer")

        let capturedThinking = state.streamingThinking
        let endedAt = state.thinkingEndedAt

        state.appendStreamingThinking(" trailing scratchpad")

        #expect(!state.isThinkingActive)
        #expect(state.streamingThinking == capturedThinking)
        #expect(state.thinkingEndedAt == endedAt)
    }

    @Test("inline think tags route into the thinking stream instead of the visible answer")
    func inlineThinkTagsRouteIntoThinkingStream() {
        let state = AgentChatState()
        state.startStreaming()

        state.appendStreamingText("<think>working through the plan</think>Final answer.")
        state.stopStreaming()

        #expect(state.streamingThinking == "working through the plan")
        #expect(state.streamingText == "Final answer.")
        #expect(!state.isThinkingActive)
        #expect(state.thinkingEndedAt != nil)
    }

    @Test("starting a new streaming turn resets stale thinking state")
    func startStreamingResetsThinkingState() {
        let state = AgentChatState()
        state.appendStreamingThinking("prior turn")
        #expect(state.isThinkingActive)

        state.startStreaming()

        #expect(!state.isThinkingActive)
        #expect(state.streamingThinking.isEmpty)
        #expect(state.thinkingStartedAt == nil)
        #expect(state.thinkingEndedAt == nil)
    }

    @Test("starting a new session clears lingering thinking state")
    func startNewSessionResetsThinkingState() {
        let state = AgentChatState()
        state.appendStreamingThinking("carryover")

        state.startNewSession()

        #expect(!state.isThinkingActive)
        #expect(state.streamingThinking.isEmpty)
        #expect(state.thinkingStartedAt == nil)
    }

    // MARK: - Typed error kind plumbing

    @Test("addErrorMessage(from:) classifies the error and attaches the kind")
    func addErrorMessageFromClassifiesKind() {
        let state = AgentChatState()
        state.startNewSession()

        state.addErrorMessage(from: LocalInferenceRoutingError.runtimeUnavailable)

        let msg = state.messages.last
        #expect(msg?.isError == true)
        #expect(msg?.errorKind == .modelNotReady)
    }

    @Test("addErrorMessage(_:kind:) preserves the caller-supplied kind")
    func addErrorMessageWithExplicitKind() {
        let state = AgentChatState()
        state.startNewSession()

        state.addErrorMessage("Your key expired.", kind: .authFailure)

        let msg = state.messages.last
        #expect(msg?.errorKind == .authFailure)
        #expect(msg?.content == "Your key expired.")
    }

    // MARK: - Effective-model badge

    @Test("completeProcessing attaches the resolved model label to the assistant turn")
    func completeProcessingAttachesResolvedModelLabel() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingText("hello")

        state.completeProcessing(mode: .api, resolvedModelLabel: "Claude Sonnet 4.6")

        let message = state.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.resolvedModelLabel == "Claude Sonnet 4.6")
    }

    @Test("completeProcessing persists captured thinking for the finalized turn")
    func completeProcessingPersistsCapturedThinking() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingText("<think>inspect the note graph</think>Answer")

        state.completeProcessing(mode: .api, resolvedModelLabel: "Qwen 3 4B")

        let message = state.messages.last
        #expect(message?.thinkingTrace == "inspect the note graph")
        #expect(message?.thinkingDurationSeconds != nil)
        #expect(state.streamingThinking.isEmpty)
    }

    // MARK: - Empty-stream guard

    @Test("empty streams surface as a readable error instead of a ghost bubble")
    func completeProcessingOnEmptyStreamEmitsError() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()

        state.completeProcessing(mode: .api)

        #expect(state.messages.count == 1)
        let message = state.messages.first
        #expect(message?.role == .assistant)
        #expect(message?.isError == true)
        #expect(message?.content.contains("No response") == true)
        #expect(!state.isStreaming)
    }

    @Test("agent chat recovers a final answer from hidden thinking before surfacing empty-stream error")
    func completeProcessingSalvagesAnswerFromThinkingTrace() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingThinking(
            """
            Thinking Process:
            I should keep the response brief.

            Final Answer:
            The summary is ready.
            """
        )

        state.completeProcessing(mode: .api)

        let message = state.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.isError != true)
        #expect(message?.content == "The summary is ready.")
        #expect(message?.thinkingTrace?.contains("Thinking Process") == true)
    }

    @Test("agent chat preserves thinking-only turns with a readable fallback instead of an empty-stream error")
    func completeProcessingPreservesThinkingOnlyTurns() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingThinking(
            """
            1. Query:
            - Research the note network.

            2. Detailed Analysis with chunk_reduce:
            Input Text: The linked notes.
            Reduce Strategy: Keep the highest-signal passages.
            """
        )

        state.completeProcessing(mode: .api)

        let message = state.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.isError != true)
        #expect(message?.content.contains("never produced a final answer") == true)
        #expect(message?.thinkingTrace?.contains("Detailed Analysis with chunk_reduce") == true)
    }

    @Test("agent chat does not promote native reasoning summaries into the final answer")
    func completeProcessingDoesNotPromoteNativeReasoningSummaryIntoAnswer() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingThinking("What's weaker")

        state.completeProcessing(mode: .api)

        let message = state.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.isError != true)
        #expect(message?.content.contains("never produced a final answer") == true)
        #expect(message?.content != "What's weaker")
        #expect(message?.thinkingTrace == "What's weaker")
    }

    @Test("agent chat interrupted turns preserve thinking-only fallbacks")
    func interruptedProcessingPreservesThinkingOnlyTurns() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingThinking(
            """
            1. Query:
            - Research the note network.

            2. Detailed Analysis with chunk_reduce:
            Input Text: The linked notes.
            Reduce Strategy: Keep the highest-signal passages.
            """
        )

        let completed = state.completeInterruptedProcessing(mode: .api)

        #expect(completed)
        let message = state.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.isError != true)
        #expect(message?.content.contains("never produced a final answer") == true)
        #expect(message?.thinkingTrace?.contains("Detailed Analysis with chunk_reduce") == true)
    }

    @Test("agent chat interrupted turns do not promote native reasoning summaries into the final answer")
    func interruptedProcessingDoesNotPromoteNativeReasoningSummaryIntoAnswer() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingThinking("What's weaker")

        let completed = state.completeInterruptedProcessing(mode: .api)

        #expect(completed)
        let message = state.messages.last
        #expect(message?.content.contains("never produced a final answer") == true)
        #expect(message?.content != "What's weaker")
        #expect(message?.thinkingTrace == "What's weaker")
    }

    @Test("agent chat interrupted turns recover final answers from hidden thinking")
    func interruptedProcessingSalvagesAnswerFromThinkingTrace() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.appendStreamingThinking(
            """
            Thinking Process:
            Keep the response brief.

            Final Answer:
            The summary is ready.
            """
        )

        let completed = state.completeInterruptedProcessing(mode: .api)

        #expect(completed)
        let message = state.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.isError != true)
        #expect(message?.content == "The summary is ready.")
        #expect(message?.thinkingTrace?.contains("Thinking Process") == true)
    }

    @Test("empty text but pending tool-use blocks still commit the turn")
    func completeProcessingPreservesTurnWithOnlyToolBlocks() {
        let state = AgentChatState()
        state.startNewSession()
        state.startStreaming()
        state.recordToolUse(id: "tool-1", name: "read_note", inputJson: "{}")

        state.completeProcessing(mode: .api)

        #expect(state.messages.count == 1)
        #expect(state.messages.first?.isError != true)
    }

    // MARK: - Error Message

    @Test func addErrorMessage() {
        let state = AgentChatState()
        state.startStreaming()
        state.addErrorMessage("Something went wrong")

        #expect(!state.isStreaming)
        #expect(state.messages.count == 1)
        #expect(state.messages.first?.role == .assistant)
        #expect(state.messages.first?.isError ?? false)
    }
}
