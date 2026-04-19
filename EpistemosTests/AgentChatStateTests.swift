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
