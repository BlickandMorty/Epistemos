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
    /// Accumulated thinking-mode deltas for the currently streaming agent turn.
    /// Populated live as `onThinkingDelta` events arrive so the agent surface
    /// can show an in-flight "Thinking…" popover just like main chat does,
    /// rather than appearing frozen during the reasoning phase. Cleared when
    /// a new agent turn starts or when a turn completes.
    var streamingThinking = ""
    /// True while the agent is in its thinking phase. Flips to false on the
    /// first text delta (thinking closes, answer begins) or when the turn
    /// finalizes without a thinking block.
    var isThinkingActive = false
    /// Timestamp when thinking started this turn.
    var thinkingStartedAt: Date?
    /// Timestamp when thinking ended this turn (first text delta).
    var thinkingEndedAt: Date?

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

    /// Editable document mirrored into the plan inspector tab.
    var planDocumentText: String = ""

    /// Last completed assistant response, used to sync plan-like output into the side panel.
    var lastCompletedAssistantResponse: String?

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

    @ObservationIgnored
    private var lastAutoPlanDocumentText: String?

    @ObservationIgnored
    private var lastPlanDocumentSeed: AgentPlanDocumentSeed?

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
        resetPlanDocument()
        estimatedContextTokens = 0
        resetThinkingState()
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
        lastCompletedAssistantResponse = nil
    }

    // MARK: - Streaming

    func startStreaming() {
        isStreaming = true
        streamBuffer.reset()
        streamingText.reserveCapacity(16_384)
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
        resetThinkingState()
    }

    func appendStreamingText(_ text: String) {
        // First text delta closes the thinking phase — the popover flips
        // from the live "Thinking…" pulse to the persisted "Thought for Ns"
        // summary badge on the agent surface.
        if isThinkingActive {
            isThinkingActive = false
            thinkingEndedAt = Date()
        }
        streamBuffer.append(text, scheduleFlush: true)
    }

    /// Accumulate a live thinking delta for the streaming agent turn.
    /// The first delta starts the popover (isThinkingActive = true +
    /// thinkingStartedAt); subsequent deltas append to streamingThinking so
    /// the UI can render the reasoning live instead of a blank spinner.
    func appendStreamingThinking(_ text: String) {
        if !isThinkingActive {
            isThinkingActive = true
            thinkingStartedAt = Date()
            streamingThinking.removeAll(keepingCapacity: true)
        }
        streamingThinking.append(text)
    }

    /// Reset all thinking-popover state between turns.
    func resetThinkingState() {
        streamingThinking.removeAll(keepingCapacity: false)
        isThinkingActive = false
        thinkingStartedAt = nil
        thinkingEndedAt = nil
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
        lastCompletedAssistantResponse = answerText

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
        lastCompletedAssistantResponse = nil
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
        resetPlanDocument()
        estimatedContextTokens = 0
    }

    // MARK: - Plan Document

    func seedPlanDocument(_ seed: AgentPlanDocumentSeed) {
        lastPlanDocumentSeed = seed
        executionPlanSummary = seed.summary
        applyAutoPlanDocument(
            AgentPlanDocumentBuilder.makeDocument(seed: seed)
        )
    }

    func absorbAgentResponseIntoPlanDocument(_ response: String) {
        guard let candidate = AgentPlanDocumentBuilder.extractPlanCandidate(from: response) else { return }
        applyAutoPlanDocument(
            AgentPlanDocumentBuilder.makeDocument(
                seed: lastPlanDocumentSeed,
                planCandidate: candidate
            )
        )
    }

    func userEditedPlanDocument(_ text: String) {
        planDocumentText = text
    }

    private func resetPlanDocument() {
        planDocumentText = ""
        lastAutoPlanDocumentText = nil
        lastPlanDocumentSeed = nil
        lastCompletedAssistantResponse = nil
    }

    private func applyAutoPlanDocument(_ text: String) {
        let normalizedCurrent = planDocumentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAuto = lastAutoPlanDocumentText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNext = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNext.isEmpty else { return }
        guard normalizedCurrent.isEmpty || normalizedCurrent == normalizedAuto else { return }
        planDocumentText = text
        lastAutoPlanDocumentText = text
    }

    // MARK: - Helpers

    private nonisolated static func decodeToolInput(_ inputJson: String) -> [String: JSONValue] {
        guard let data = inputJson.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            Logger(subsystem: "com.epistemos", category: "AgentChatState.ToolInput")
                .error("AgentChatState: failed to decode tool input JSON; preserving raw payload")
            return ["raw": .string(inputJson)]
        }
        return decoded
    }
}
