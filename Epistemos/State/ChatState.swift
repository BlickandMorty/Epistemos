import Foundation
import Observation
import os

// MARK: - Chat State
// In-memory streaming and message state for the active chat session.
// AppBootstrap persists completed messages to SDChat/SDMessage via SwiftData.

@MainActor @Observable
final class ChatState {
    private let log = Logger(subsystem: "com.epistemos", category: "ChatState")
    // MARK: - Streaming

    var isStreaming = false
    var streamingText = ""
    var activeChatId: String?
    var chatTitle: String?
    var pendingAttachments: [FileAttachment] = []
    var pendingContextAttachments: [ContextAttachment] = []

    // MARK: - In-memory messages (current session)
    var messages: [ChatMessage] = []
    var hasMessages = false
    private(set) var transcriptRevision: UInt = 0

    // MARK: - Context Window Tracking
    var estimatedContextTokens: Int = 0
    var maxContextTokens: Int = 128_000

    var contextUsageFraction: Double {
        guard maxContextTokens > 0 else { return 0 }
        return min(1.0, Double(estimatedContextTokens) / Double(maxContextTokens))
    }

    func recalculateContextEstimate() {
        estimatedContextTokens = messages.reduce(0) { $0 + $1.content.count } / 4
    }

    /// Controls whether the landing page or chat view is shown on the Home panel.
    /// `true` = landing page visible (even if messages exist in memory).
    /// Messages stay alive while the user navigates away and back.
    var showLanding = true

    // MARK: - Incognito
    /// When true, chat messages are kept in-memory only — not persisted to SwiftData.
    var isIncognito = false

    // MARK: - Agent State (Goose-style tool execution tracking)

    /// Active tool executions shown inline in the chat stream.
    var activeToolName: String?
    var pendingContentBlocks: [MessageContentBlock] = []

    /// Whether the agent is currently executing (vs just streaming text).
    var isAgentExecuting = false

    /// Number of agent turns completed in current session.
    var agentTurnCount = 0

    /// The capability tier the current chat turn is operating in. Drives the
    /// ChatCapabilityPill shown inline in the composer and the chat header.
    /// Updated by ChatCoordinator when a turn dispatches (so the user sees
    /// "Agent" light up when a tool-call turn actually begins, not just
    /// because a cloud model is selected). Default `.local` matches the
    /// cold-start state where no provider has been asked yet.
    var currentCapability: ChatCapability = .local

    // MARK: - Vault Context (Ambient)
    /// Page IDs of notes whose full bodies have been loaded into context via @-mentions.
    var loadedNoteIds: Set<String> = []

    /// Titles of notes loaded via @-mentions (for UI chips on messages).
    var loadedNoteTitles: [String] = []

    /// Transient flag — true when the current streaming response is a vault briefing.
    /// Set by AppBootstrap, read by finalizeStreaming to stamp the ChatMessage.
    var isCurrentVaultBriefing = false

    /// Transient: full manifest (with bodies) used only for vault briefing requests.
    /// Set by requestVaultBriefing, consumed and cleared by handleQuery.
    var vaultBriefingManifest: VaultManifest?

    // MARK: - Init

    init() {}

    private func markTranscriptChanged() {
        transcriptRevision &+= 1
    }

    private func releaseStreamingTextStorage() {
        streamingText.removeAll(keepingCapacity: false)
    }

    // MARK: - Error

    var error: String?

    // MARK: - Dependencies

    weak var eventBus: EventBus?

    /// Called when the user presses Stop — allows AppBootstrap to cancel the active pipeline Task.
    var onStopRequested: (@MainActor () -> Void)?

    // MARK: - Chat Management

    func setCurrentChat(_ chatId: String) {
        activeChatId = chatId
    }

    /// Navigate to the landing page without destroying the chat session.
    /// Messages stay alive so the user can return to the same thread.
    func goHome() {
        showLanding = true
    }

    /// Start a fresh chat session. Clears old messages and activeChatId so the
    /// next submitQuery creates a new conversation. Preserves mode preferences.
    func startNewChat() {
        streamBuffer.reset(releaseCapacity: true)

        messages = []
        markTranscriptChanged()
        hasMessages = false
        releaseStreamingTextStorage()
        isStreaming = false
        activeChatId = nil
        chatTitle = nil
        showLanding = false
        pendingAttachments = []
        loadedNoteIds = []
        loadedNoteTitles = []
        pendingContextAttachments = []
        vaultBriefingManifest = nil
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
    }

    /// Maximum user query length (chars). Local context windows are large enough,
    /// but sending excessively long input wastes tokens and can hit local context limits.
    private static let maxQueryLength = 50_000

    func submitQuery(
        _ query: String,
        operatingMode: EpistemosOperatingMode = .fast
    ) {
        // Guard against excessively long input — truncate silently rather than crash.
        let safeQuery = query.count > Self.maxQueryLength
            ? String(query.prefix(Self.maxQueryLength))
            : query

        // Show the chat view (hide landing page)
        showLanding = false

        let chatId = activeChatId ?? {
            let id = UUID().uuidString
            activeChatId = id
            return id
        }()

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: chatId,
            role: .user,
            content: safeQuery,
            attachments: pendingAttachments,
            contextAttachments: pendingContextAttachments.isEmpty ? nil : pendingContextAttachments
        )
        messages.append(userMessage)
        markTranscriptChanged()
        hasMessages = true

        pendingAttachments = []
        streamBuffer.reset(releaseCapacity: true)
        releaseStreamingTextStorage()
        isStreaming = false

        eventBus?.emit(
            .querySubmitted(
                chatId: ChatId(chatId),
                query: safeQuery,
                operatingMode: operatingMode
            )
        )
    }

    func appendLocalMessage(
        role: MessageRole,
        content: String,
        isError: Bool = false,
        loadedNoteTitles: [String]? = nil,
        contextAttachments: [ContextAttachment]? = nil
    ) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        showLanding = false

        let chatId = activeChatId ?? {
            let id = UUID().uuidString
            activeChatId = id
            return id
        }()

        messages.append(
            ChatMessage(
                chatId: chatId,
                role: role,
                content: trimmed,
                isError: isError,
                loadedNoteTitles: loadedNoteTitles,
                contextAttachments: contextAttachments
            )
        )
        markTranscriptChanged()
        hasMessages = true
    }

    func completeProcessing(
        messageId: String = UUID().uuidString,
        mode: InferenceMode
    ) {
        guard let chatId = activeChatId else { return }

        // Flush any buffered tokens before reading streamingText
        flushStreamingTokens()

        let answerText = UserFacingModelOutput.finalVisibleText(from: streamingText)

        let metadata = consumeStreamingMessageMetadata()
        let completedContentBlocks = completedContentBlocks(for: answerText)

        // Extract structured artifacts (JSON, YAML, code blocks, tables)
        // from the response text. These get rendered as interactive cards.
        let artifacts = ArtifactExtractor.extract(from: answerText)

        let assistantMessage = ChatMessage(
            id: messageId,
            chatId: chatId,
            role: .assistant,
            content: answerText,
            mode: mode,
            isVaultBriefing: metadata.briefing,
            loadedNoteTitles: metadata.noteTitles,
            contextAttachments: metadata.contextAttachments,
            artifacts: artifacts,
            contentBlocks: completedContentBlocks
        )
        log.info("[complete] Appending assistant message \(assistantMessage.id)")
        messages.append(assistantMessage)
        markTranscriptChanged()

        streamBuffer.reset(releaseCapacity: true)
        releaseStreamingTextStorage()
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
        eventBus?.emit(.queryCompleted(chatId: ChatId(chatId), messageId: MessageId(assistantMessage.id)))
    }

    @discardableResult
    func completeCancelledProcessing(
        messageId: String = UUID().uuidString,
        mode: InferenceMode
    ) -> Bool {
        flushStreamingTokens()

        let answerText = UserFacingModelOutput.finalVisibleText(from: streamingText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = consumeStreamingMessageMetadata()
        let completedContentBlocks = completedContentBlocks(for: answerText)

        defer {
            streamBuffer.reset(releaseCapacity: true)
            releaseStreamingTextStorage()
            isStreaming = false
            pendingContentBlocks = []
            activeToolName = nil
            isAgentExecuting = false
        }

        guard let chatId = activeChatId, !answerText.isEmpty else { return false }

        let assistantMessage = ChatMessage(
            id: messageId,
            chatId: chatId,
            role: .assistant,
            content: answerText,
            mode: mode,
            isVaultBriefing: metadata.briefing,
            loadedNoteTitles: metadata.noteTitles,
            contextAttachments: metadata.contextAttachments,
            contentBlocks: completedContentBlocks
        )
        messages.append(assistantMessage)
        markTranscriptChanged()
        return true
    }

    /// Update the last message's content (used for post-processing like vault action markers).
    func updateLastMessageContent(_ newContent: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content = newContent
        markTranscriptChanged()
    }

    // MARK: - Error Messages

    func addErrorMessage(_ message: String) {
        let chatId = activeChatId ?? UUID().uuidString
        let errorMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: chatId,
            role: .assistant,
            content: message,
            isError: true
        )
        messages.append(errorMessage)
        markTranscriptChanged()
        streamBuffer.reset(releaseCapacity: true)
        releaseStreamingTextStorage()
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
    }

    // MARK: - Streaming

    /// Pending token buffer — accumulated between flushes.
    /// Not @Observable; only `streamingText` triggers SwiftUI updates.
    @ObservationIgnored
    private lazy var streamBuffer = DisplayPacedTextBuffer { [weak self] delta in
        self?.streamingText += delta
    }

    func startStreaming() {
        isStreaming = true
        streamBuffer.reset()
        streamingText.reserveCapacity(16_384)
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
    }

    func stopStreaming() {
        flushStreamingTokens()
        isStreaming = false
        onStopRequested?()
    }

    /// Accumulates streaming tokens off-screen while the response is generating.
    /// Live response text is intentionally not flushed into observable UI state unless the
    /// display policy enables it or the buffer grows abnormally large.
    func appendStreamingText(_ text: String) {
        streamBuffer.append(text, scheduleFlush: ChatStreamingDisplayPolicy.showsLiveResponseText)
    }

    private func flushStreamingTokens() {
        streamBuffer.flushNow()
    }

    func recordToolUse(id: String, name: String, inputJson: String) {
        let input = Self.decodeToolInput(inputJson)
        pendingContentBlocks.append(.toolUse(id: id, name: name, input: input))
        markTranscriptChanged()
    }

    func recordToolResult(toolUseId: String, result: String, isError: Bool) {
        pendingContentBlocks.append(
            .toolResult(toolUseId: toolUseId, content: result, isError: isError)
        )
        markTranscriptChanged()
    }

    private func completedContentBlocks(for answerText: String) -> [MessageContentBlock]? {
        var completedContentBlocks = pendingContentBlocks
        if !answerText.isEmpty {
            completedContentBlocks.append(.text(answerText))
        }
        return completedContentBlocks.isEmpty ? nil : completedContentBlocks
    }

    private nonisolated static func decodeToolInput(_ inputJson: String) -> [String: JSONValue] {
        guard let data = inputJson.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            Logger(subsystem: "com.epistemos", category: "ChatState.ToolInput")
                .error("ChatState: failed to decode tool input JSON; preserving raw payload")
            return ["raw": .string(inputJson)]
        }
        return decoded
    }

    private func consumeStreamingMessageMetadata() -> (
        briefing: Bool,
        noteTitles: [String]?,
        contextAttachments: [ContextAttachment]?
    ) {
        let metadata = (
            briefing: isCurrentVaultBriefing,
            noteTitles: loadedNoteTitles.isEmpty ? nil : loadedNoteTitles,
            contextAttachments: pendingContextAttachments.isEmpty ? nil : pendingContextAttachments
        )
        isCurrentVaultBriefing = false
        loadedNoteTitles = []
        return metadata
    }

    // MARK: - Attachments

    func addAttachment(_ file: FileAttachment) {
        // Prevent duplicate attachments — match by file URI
        guard !pendingAttachments.contains(where: { $0.uri == file.uri }) else { return }
        pendingAttachments.append(file)
    }
    func removeAttachment(_ id: String) { pendingAttachments.removeAll { $0.id == id } }

    func addContextAttachment(_ attachment: ContextAttachment) {
        guard !pendingContextAttachments.contains(attachment) else { return }
        pendingContextAttachments.append(attachment)
    }

    func removeContextAttachment(_ id: String) {
        pendingContextAttachments.removeAll { $0.id == id }
    }

    // MARK: - Load / Clear

    func loadMessages(_ msgs: [ChatMessage]) {
        messages = msgs
        markTranscriptChanged()
        hasMessages = !msgs.isEmpty
        showLanding = msgs.isEmpty
        pendingAttachments = []
        restoreConversationContext(from: msgs)
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
    }

    func clearMessages() {
        let chatId = activeChatId
        streamBuffer.reset(releaseCapacity: true)

        messages = []
        markTranscriptChanged()
        hasMessages = false
        releaseStreamingTextStorage()
        isStreaming = false
        isIncognito = false
        showLanding = true
        pendingAttachments = []
        pendingContextAttachments = []
        loadedNoteIds = []
        loadedNoteTitles = []
        vaultBriefingManifest = nil
        pendingContentBlocks = []
        activeToolName = nil
        isAgentExecuting = false
        activeChatId = nil
        chatTitle = nil

        if let chatId {
            eventBus?.emit(.chatCleared(chatId: ChatId(chatId)))
        }
    }

    private func restoreConversationContext(from messages: [ChatMessage]) {
        guard let lastMessage = messages.last else {
            pendingContextAttachments = []
            loadedNoteIds = []
            loadedNoteTitles = []
            return
        }

        pendingContextAttachments = lastMessage.contextAttachments ?? []
        loadedNoteIds = Set(
            pendingContextAttachments.compactMap { attachment in
                attachment.kind == .note ? attachment.targetId : nil
            }
        )

        guard !pendingContextAttachments.isEmpty else {
            loadedNoteTitles = []
            return
        }

        var restoredTitles = lastMessage.loadedNoteTitles ?? []
        for attachment in pendingContextAttachments where attachment.kind == .note && !restoredTitles.contains(attachment.title) {
            restoredTitles.append(attachment.title)
        }
        loadedNoteTitles = restoredTitles
    }
}

@MainActor
enum MainChatSubmissionRouter {
    static func submit(
        _ query: String,
        operatingMode: EpistemosOperatingMode,
        chat: ChatState,
        orchestrator: OrchestratorState,
        inference: InferenceState? = nil
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let effectiveMode = inference.map {
            autoPromotedMode(
                from: operatingMode,
                query: trimmed,
                inference: $0
            )
        } ?? operatingMode

        switch effectiveMode {
        case .agent:
            // Agent mode now routes through the main chat pipeline with cloud
            // providers + Rust agent_core tool execution. No separate panel needed.
            chat.submitQuery(trimmed, operatingMode: effectiveMode)

        case .fast, .thinking, .pro:
            chat.submitQuery(trimmed, operatingMode: effectiveMode)
        }
    }

    /// Auto-promote: if the user's prompt reads as agent work AND they're
    /// on a cloud provider that supports the agent tier (OpenAI / Anthropic
    /// only), flip an explicit .fast/.thinking/.pro request into .agent so
    /// the turn actually runs through the Rust agent_core loop with tools.
    /// Never auto-downgrades — if the user picked .agent explicitly we
    /// honor it. Never promotes Google / Z.AI / Kimi / MiniMax / DeepSeek
    /// because their tool-calling either diverges from the Claude/OpenAI
    /// shape the agent loop expects (Gemini) or isn't offered at all
    /// (Perplexity-class search models). Local providers can never
    /// promote — enforced downstream by AgentError::LocalProviderNotAllowed.
    static func autoPromotedMode(
        from requested: EpistemosOperatingMode,
        query: String,
        inference: InferenceState
    ) -> EpistemosOperatingMode {
        if requested == .agent { return requested }

        guard let cloud = inference.activeAIProvider.cloudProvider,
              cloud.supportsAgentTier else {
            return requested
        }

        let prediction = ChatCapability.predictIntent(
            text: query,
            isCloudProvider: true
        )

        return prediction.predicted == .agent ? .agent : requested
    }
}

@MainActor
final class DisplayPacedTextBuffer {
    private let flushInterval: Duration
    private let flushThresholdBytes: Int
    private let onFlush: (String) -> Void

    private var pendingText = ""
    private var flushTask: Task<Void, Never>?

    init(
        flushInterval: Duration = .milliseconds(16),
        flushThresholdBytes: Int = 65_536,
        onFlush: @escaping (String) -> Void
    ) {
        self.flushInterval = flushInterval
        self.flushThresholdBytes = flushThresholdBytes
        self.onFlush = onFlush
        pendingText.reserveCapacity(16_384)
    }

    func append(_ text: String, scheduleFlush: Bool = true) {
        pendingText += text
        if pendingText.utf8.count > flushThresholdBytes {
            flushNow()
            return
        }
        guard scheduleFlush, flushTask == nil else { return }
        let interval = flushInterval
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: interval)
            guard let self, !Task.isCancelled else { return }
            self.flushNow()
        }
    }

    func flushNow() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingText.isEmpty else { return }
        let delta = pendingText
        pendingText.removeAll(keepingCapacity: true)
        onFlush(delta)
    }

    func reset(releaseCapacity: Bool = false) {
        flushTask?.cancel()
        flushTask = nil
        pendingText.removeAll(keepingCapacity: !releaseCapacity)
    }
}
