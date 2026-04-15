import Foundation
import Observation
import os

// MARK: - Agent Chat State
// Dedicated message history and streaming state for Agent Command Center sessions.
// This is SEPARATE from ChatState — the Agent home is its own surface with its own
// conversation thread, per PLAN_V2 line 169. Agent sessions produce tool calls,
// execution plans, and multi-turn agent loops that differ from lightweight main chat.

@MainActor @Observable
final class AgentChatState {
    private let log = Logger(subsystem: "com.epistemos", category: "AgentChatState")

    // MARK: - Streaming

    var isStreaming = false
    var streamingText = ""

    // MARK: - Session Identity

    var activeSessionId: String?

    // MARK: - In-memory messages (current agent session)

    var messages: [ChatMessage] = []
    var hasMessages = false

    // MARK: - Agent-Specific State

    /// Active tool executions shown inline in the agent response stream.
    var activeToolName: String?

    /// Pending content blocks (tool uses and results) for the current response.
    var pendingContentBlocks: [MessageContentBlock] = []

    /// Whether the agent is currently executing (vs just streaming text).
    var isAgentExecuting = false

    /// Number of agent turns completed in current session.
    var agentTurnCount = 0

    /// Tool execution history for this session (feeds inspector Execution tab).
    var toolHistory: [ACCToolExecutionRecord] = []

    /// Execution plan summary from the overseer (feeds inspector Plan tab).
    var executionPlanSummary: String?

    // MARK: - Context Tracking

    var estimatedContextTokens: Int = 0
    var maxContextTokens: Int = 128_000

    var contextUsageFraction: Double {
        guard maxContextTokens > 0 else { return 0 }
        return min(1.0, Double(estimatedContextTokens) / Double(maxContextTokens))
    }

    // MARK: - Dependencies

    weak var eventBus: EventBus?

    /// Called when the user presses Stop.
    var onStopRequested: (@MainActor () -> Void)?

    // MARK: - Streaming Buffer

    @ObservationIgnored
    private lazy var streamBuffer = DisplayPacedTextBuffer { [weak self] delta in
        self?.streamingText += delta
    }

    // MARK: - Init

    init() {}

    // MARK: - Session Lifecycle

    /// Start a new agent session. Creates a fresh session ID and clears prior state.
    func startNewSession() {
        streamBuffer.reset(releaseCapacity: true)
        messages = []
        hasMessages = false
        streamingText.removeAll(keepingCapacity: false)
        isStreaming = false
        activeSessionId = UUID().uuidString
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
        agentTurnCount = 0
        toolHistory = []
        executionPlanSummary = nil
        estimatedContextTokens = 0
        log.info("[AgentChat] New session: \(self.activeSessionId ?? "nil")")
    }

    // MARK: - Message Management

    func submitAgentQuery(_ query: String) {
        let sessionId = activeSessionId ?? {
            let id = UUID().uuidString
            activeSessionId = id
            return id
        }()

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: sessionId,
            role: .user,
            content: query
        )
        messages.append(userMessage)
        hasMessages = true
        streamBuffer.reset(releaseCapacity: true)
        streamingText.removeAll(keepingCapacity: false)
        isStreaming = false
    }

    // MARK: - Streaming

    func startStreaming() {
        isStreaming = true
        streamBuffer.reset()
        streamingText.reserveCapacity(16_384)
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
    }

    func appendStreamingText(_ text: String) {
        streamBuffer.append(text, scheduleFlush: true)
    }

    func stopStreaming() {
        flushStreamingTokens()
        isStreaming = false
        onStopRequested?()
    }

    private func flushStreamingTokens() {
        streamBuffer.flushNow()
    }

    // MARK: - Tool Tracking

    func recordToolUse(id: String, name: String, inputJson: String) {
        activeToolName = name
        isAgentExecuting = true
        pendingContentBlocks.append(.toolUse(
            id: id,
            name: name,
            input: Self.decodeToolInput(inputJson)
        ))
    }

    func recordToolResult(toolUseId: String, result: String, isError: Bool, durationMs: UInt64) {
        pendingContentBlocks.append(.toolResult(
            toolUseId: toolUseId,
            content: result,
            isError: isError
        ))

        // Add to history for inspector
        let toolName = activeToolName ?? "unknown"
        toolHistory.append(ACCToolExecutionRecord(
            toolName: toolName,
            inputSummary: String(result.prefix(200)),
            resultSummary: String(result.prefix(200)),
            durationMs: durationMs,
            isError: isError
        ))

        activeToolName = nil
    }

    // MARK: - Completion

    func completeProcessing(mode: InferenceMode) {
        guard let sessionId = activeSessionId else { return }
        flushStreamingTokens()

        let answerText = UserFacingModelOutput.finalVisibleText(from: streamingText)

        var completedBlocks = pendingContentBlocks
        if !answerText.isEmpty {
            completedBlocks.append(.text(answerText))
        }

        let artifacts = ArtifactExtractor.extract(from: answerText)

        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: sessionId,
            role: .assistant,
            content: answerText,
            mode: mode,
            artifacts: artifacts,
            contentBlocks: completedBlocks.isEmpty ? nil : completedBlocks
        )

        messages.append(assistantMessage)
        hasMessages = true
        agentTurnCount += 1

        // Reset streaming state
        streamBuffer.reset(releaseCapacity: true)
        streamingText.removeAll(keepingCapacity: false)
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false

        // Update context estimate
        estimatedContextTokens = messages.reduce(0) { $0 + $1.content.count } / 4

        log.info("[AgentChat] Completed turn \(self.agentTurnCount) in session \(sessionId)")
    }

    // MARK: - Error

    func addErrorMessage(_ message: String) {
        let sessionId = activeSessionId ?? UUID().uuidString
        let errorMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: sessionId,
            role: .assistant,
            content: message,
            isError: true
        )
        messages.append(errorMessage)
        hasMessages = true
        streamBuffer.reset(releaseCapacity: true)
        streamingText.removeAll(keepingCapacity: false)
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
    }

    // MARK: - Clear

    func clearMessages() {
        streamBuffer.reset(releaseCapacity: true)
        messages = []
        hasMessages = false
        streamingText.removeAll(keepingCapacity: false)
        isStreaming = false
        activeSessionId = nil
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
        agentTurnCount = 0
        toolHistory = []
        executionPlanSummary = nil
        estimatedContextTokens = 0
    }

    // MARK: - Helpers

    private nonisolated static func decodeToolInput(_ inputJson: String) -> [String: JSONValue] {
        guard let data = inputJson.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return ["raw": .string(inputJson)]
        }
        return decoded
    }
}
