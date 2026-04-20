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
    /// Live tool-input JSON for the currently-running tool call — mirrors
    /// ChatState.activeToolInputJson so the agent surface can drive the
    /// same ToolActivityNarrator (web_search → "Searching the web for
    /// 'X'…" etc.). Cleared on completion / error.
    var activeToolInputJson: String?

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

    @ObservationIgnored
    private var thinkTagRouter = ThinkTagStreamRouter()

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
        activeToolInputJson = nil
        isAgentExecuting = false
        agentTurnCount = 0
        toolHistory = []
        executionPlanSummary = nil
        resetPlanDocument()
        estimatedContextTokens = 0
        resetThinkingState()
        thinkTagRouter = ThinkTagStreamRouter()
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
        activeToolInputJson = nil
        isAgentExecuting = false
        resetThinkingState()
        thinkTagRouter = ThinkTagStreamRouter()
    }

    func appendStreamingText(_ text: String) {
        let emit = thinkTagRouter.ingest(text)
        if !emit.thinking.isEmpty {
            appendStreamingThinking(emit.thinking)
        }

        if !emit.visible.isEmpty {
            if isThinkingActive {
                isThinkingActive = false
                thinkingEndedAt = Date()
            }
            streamBuffer.append(emit.visible, scheduleFlush: true)
        }
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

    /// Convenience: classify an Error through UserFacingChatError and
    /// record both the user-facing copy AND the typed kind.
    func addErrorMessage(from error: Error) {
        let kind = UserFacingChatError.classify(error)
        addErrorMessage(UserFacingChatError.message(from: error), kind: kind)
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

    private func flushThinkTagRouter() {
        let emit = thinkTagRouter.flush()
        if !emit.thinking.isEmpty {
            appendStreamingThinking(emit.thinking)
        }
        if !emit.visible.isEmpty {
            if isThinkingActive {
                isThinkingActive = false
                thinkingEndedAt = Date()
            }
            streamBuffer.append(emit.visible, scheduleFlush: false)
        }
    }

    // MARK: - Tool Tracking

    func recordToolUse(id: String, name: String, inputJson: String) {
        activeToolName = name
        activeToolInputJson = inputJson
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
        activeToolInputJson = nil
    }

    // MARK: - Completion

    func completeProcessing(mode: InferenceMode, resolvedModelLabel: String? = nil) {
        guard let sessionId = activeSessionId else { return }
        flushThinkTagRouter()
        flushStreamingTokens()

        let capturedThinking = streamingThinking.trimmingCharacters(in: .whitespacesAndNewlines)
        var answerText = UserFacingModelOutput.finalVisibleText(from: streamingText)
        if answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !capturedThinking.isEmpty {
            let salvagedFromThinking = UserFacingModelOutput.finalVisibleText(from: capturedThinking)
            if !salvagedFromThinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                answerText = salvagedFromThinking
            } else if let fallback = UserFacingModelOutput.incompleteReasoningFallback(from: capturedThinking) {
                answerText = fallback
            }
        }
        let thinkingDurationSeconds: Double? = {
            guard let start = thinkingStartedAt else { return nil }
            let end = thinkingEndedAt ?? Date()
            let duration = end.timeIntervalSince(start)
            return duration >= 0 ? duration : nil
        }()

        var completedBlocks = pendingContentBlocks
        if !answerText.isEmpty {
            completedBlocks.append(.text(answerText))
        }

        let artifacts = ArtifactExtractor.extract(from: answerText)

        // Silent-empty-reply guard: a turn with no text, no tool-use blocks,
        // and no artifacts has nothing for the user to see. Surface a
        // concrete error rather than a ghost assistant bubble.
        let trimmedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasVisibleContent = !trimmedAnswer.isEmpty
            || !completedBlocks.isEmpty
            || !artifacts.isEmpty
        guard hasVisibleContent else {
            log.error("[AgentChat] Empty stream in session \(sessionId); surfacing as error")
            streamBuffer.reset(releaseCapacity: true)
            streamingText.removeAll(keepingCapacity: false)
            isStreaming = false
            pendingContentBlocks = []
            activeToolName = nil
            activeToolInputJson = nil
            isAgentExecuting = false
            addErrorMessage(
                "No response received. The agent returned an empty stream — try again or switch models."
            )
            return
        }

        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: sessionId,
            role: .assistant,
            content: answerText,
            mode: mode,
            artifacts: artifacts,
            contentBlocks: completedBlocks.isEmpty ? nil : completedBlocks,
            resolvedModelLabel: resolvedModelLabel,
            thinkingTrace: capturedThinking.isEmpty ? nil : capturedThinking,
            thinkingDurationSeconds: thinkingDurationSeconds
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
        activeToolInputJson = nil
        isAgentExecuting = false
        resetThinkingState()
        thinkTagRouter = ThinkTagStreamRouter()

        // Update context estimate
        estimatedContextTokens = messages.reduce(0) { $0 + $1.content.count } / 4

        log.info("[AgentChat] Completed turn \(self.agentTurnCount) in session \(sessionId)")
    }

    @discardableResult
    func completeInterruptedProcessing(
        mode: InferenceMode,
        resolvedModelLabel: String? = nil
    ) -> Bool {
        guard let sessionId = activeSessionId else { return false }
        flushThinkTagRouter()
        flushStreamingTokens()

        let capturedThinking = streamingThinking.trimmingCharacters(in: .whitespacesAndNewlines)
        var answerText = UserFacingModelOutput.finalVisibleText(from: streamingText)
        if answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !capturedThinking.isEmpty {
            let salvagedFromThinking = UserFacingModelOutput.finalVisibleText(from: capturedThinking)
            if !salvagedFromThinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                answerText = salvagedFromThinking
            } else if let fallback = UserFacingModelOutput.incompleteReasoningFallback(from: capturedThinking) {
                answerText = fallback
            }
        }
        let thinkingDurationSeconds: Double? = {
            guard let start = thinkingStartedAt else { return nil }
            let end = thinkingEndedAt ?? Date()
            let duration = end.timeIntervalSince(start)
            return duration >= 0 ? duration : nil
        }()

        var completedBlocks = pendingContentBlocks
        if !answerText.isEmpty {
            completedBlocks.append(.text(answerText))
        }

        let artifacts = ArtifactExtractor.extract(from: answerText)
        let trimmedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasVisibleContent = !trimmedAnswer.isEmpty
            || !completedBlocks.isEmpty
            || !artifacts.isEmpty

        defer {
            streamBuffer.reset(releaseCapacity: true)
            streamingText.removeAll(keepingCapacity: false)
            isStreaming = false
            pendingContentBlocks = []
            activeToolName = nil
            activeToolInputJson = nil
            isAgentExecuting = false
            resetThinkingState()
            thinkTagRouter = ThinkTagStreamRouter()
        }

        guard hasVisibleContent else { return false }

        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: sessionId,
            role: .assistant,
            content: answerText,
            mode: mode,
            artifacts: artifacts,
            contentBlocks: completedBlocks.isEmpty ? nil : completedBlocks,
            resolvedModelLabel: resolvedModelLabel,
            thinkingTrace: capturedThinking.isEmpty ? nil : capturedThinking,
            thinkingDurationSeconds: thinkingDurationSeconds
        )

        messages.append(assistantMessage)
        hasMessages = true
        agentTurnCount += 1
        lastCompletedAssistantResponse = answerText
        estimatedContextTokens = messages.reduce(0) { $0 + $1.content.count } / 4
        return true
    }

    // MARK: - Error

    func addErrorMessage(_ message: String, kind: UserFacingChatErrorKind? = nil) {
        let sessionId = activeSessionId ?? UUID().uuidString
        let errorMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: sessionId,
            role: .assistant,
            content: message,
            isError: true,
            errorKind: kind
        )
        messages.append(errorMessage)
        hasMessages = true
        streamBuffer.reset(releaseCapacity: true)
        streamingText.removeAll(keepingCapacity: false)
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
        isAgentExecuting = false
        lastCompletedAssistantResponse = nil
        resetThinkingState()
        thinkTagRouter = ThinkTagStreamRouter()
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
        activeToolInputJson = nil
        isAgentExecuting = false
        agentTurnCount = 0
        toolHistory = []
        executionPlanSummary = nil
        resetPlanDocument()
        estimatedContextTokens = 0
        resetThinkingState()
        thinkTagRouter = ThinkTagStreamRouter()
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
