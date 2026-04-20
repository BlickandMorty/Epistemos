import Foundation
import Observation
import os

struct ChatBrainSection: Identifiable, Sendable, Equatable {
    let title: String
    let body: String

    var id: String { title }

    init(title: String, body: String) {
        self.title = title
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ChatBrainSnapshot: Sendable, Equatable {
    let capturedAt: Date
    let query: String
    let resolvedQuery: String
    let operatingMode: EpistemosOperatingMode
    let routeLabel: String
    let routeSummary: String
    let providerLabel: String
    let modelLabel: String?
    let allowedToolNames: [String]
    let loadedNoteTitles: [String]
    let contextAttachments: [ContextAttachment]
    let sections: [ChatBrainSection]

    init(
        capturedAt: Date = Date(),
        query: String,
        resolvedQuery: String,
        operatingMode: EpistemosOperatingMode,
        routeLabel: String,
        routeSummary: String,
        providerLabel: String,
        modelLabel: String?,
        allowedToolNames: [String],
        loadedNoteTitles: [String],
        contextAttachments: [ContextAttachment],
        sections: [ChatBrainSection]
    ) {
        self.capturedAt = capturedAt
        self.query = query
        self.resolvedQuery = resolvedQuery
        self.operatingMode = operatingMode
        self.routeLabel = routeLabel
        self.routeSummary = routeSummary
        self.providerLabel = providerLabel
        self.modelLabel = modelLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowedToolNames = Self.uniquePreservingOrder(
            allowedToolNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        self.loadedNoteTitles = Self.uniquePreservingOrder(
            loadedNoteTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        self.contextAttachments = contextAttachments
        self.sections = sections.filter { !$0.body.isEmpty }
    }

    var hasVisibleContext: Bool {
        !sections.isEmpty
            || !loadedNoteTitles.isEmpty
            || !contextAttachments.isEmpty
            || !allowedToolNames.isEmpty
    }

    func updatingSection(_ section: ChatBrainSection) -> ChatBrainSnapshot {
        var updatedSections = sections.filter { $0.title != section.title }
        updatedSections.append(section)
        return ChatBrainSnapshot(
            capturedAt: capturedAt,
            query: query,
            resolvedQuery: resolvedQuery,
            operatingMode: operatingMode,
            routeLabel: routeLabel,
            routeSummary: routeSummary,
            providerLabel: providerLabel,
            modelLabel: modelLabel,
            allowedToolNames: allowedToolNames,
            loadedNoteTitles: loadedNoteTitles,
            contextAttachments: contextAttachments,
            sections: updatedSections
        )
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        ordered.reserveCapacity(values.count)
        for value in values where !value.isEmpty && seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}

// MARK: - Chat State
// In-memory streaming and message state for the active chat session.
// AppBootstrap persists completed messages to SDChat/SDMessage via SwiftData.

@MainActor @Observable
final class ChatState {
    private let log = Logger(subsystem: "com.epistemos", category: "ChatState")
    // MARK: - Streaming

    var isStreaming = false
    var streamingText = ""
    /// Accumulated thinking-mode deltas for the currently streaming turn.
    /// Populated live as `onThinkingDelta` events arrive so the thinking
    /// popover can render in-flight reasoning (ChatGPT-style). Cleared
    /// when a new turn starts or when the turn completes.
    var streamingThinking = ""
    /// True while the model is in its thinking phase — the popover
    /// trigger is only visible when this is true. Flips false on the
    /// first text delta (thinking closes, answer begins) or when the
    /// turn finalizes without a thinking block.
    var isThinkingActive = false
    /// Timestamp when thinking started this turn. Used to compute a
    /// "Thought for Ns" label on the final collapsed view.
    var thinkingStartedAt: Date?
    /// Timestamp when thinking ended this turn (first text delta).
    var thinkingEndedAt: Date?
    /// Cache-hit fraction captured from the most recent turn's
    /// provider-reported usage. Populated by `recordUsageSnapshot` and
    /// consumed at `completeProcessing` when building the assistant
    /// ChatMessage so the persisted bubble can render a "cache N%"
    /// badge. Nil when the provider didn't report cache tokens.
    var lastTurnCacheHitPercent: Double?
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
        // Rough char-to-token conversion (~4 chars per token) plus static
        // allowances for things the raw `.content` string doesn't capture
        // but that DO fill the model's window:
        //   - pending file attachments (byte size / 4)
        //   - pending @-mentioned context notes (flat per-note estimate
        //     since the body isn't resolved yet on the main actor)
        //   - loaded note titles on completed assistant turns (proxy
        //     for the note bodies that were injected into prior prompts)
        //   - system prompt + tool-schema overhead baseline
        //
        // Previously the counter read only `messages[].content`, so
        // attaching an essay + having the model respond left the meter
        // stuck at "29" — the attached body never counted. This at least
        // makes the meter MOVE on attach, which is the user-visible ask.
        // Exact accounting of already-injected note bodies lands when
        // we persist resolved token counts on ChatMessage (future batch).
        let messageChars = messages.reduce(0) { $0 + $1.content.count }
        let attachmentChars = pendingAttachments.reduce(0) { $0 + $1.size }
        let pendingContextTokensEstimate = pendingContextAttachments.count
            * Self.averageNoteTokenEstimate
        let loadedNoteHistoryTokens = messages.reduce(0) { total, msg in
            total + (msg.loadedNoteTitles?.count ?? 0) * Self.averageNoteTokenEstimate
        }
        let systemOverheadTokens = Self.systemPromptTokenEstimate
        estimatedContextTokens =
            (messageChars + attachmentChars) / 4
            + pendingContextTokensEstimate
            + loadedNoteHistoryTokens
            + systemOverheadTokens
    }

    /// Rough average note body size in tokens. Real vault notes span
    /// 200–5000 tokens; 1500 is the midpoint that keeps the meter
    /// useful without wildly over- or under-counting any single note.
    private static let averageNoteTokenEstimate = 1_500

    /// Baseline tokens the provider sees even on an empty user turn —
    /// system prompt + tool schemas + vault-briefing wrapper. Roughly
    /// constant per provider; 500 is a conservative midpoint.
    private static let systemPromptTokenEstimate = 500

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
    /// Live tool-input JSON for the currently-running tool call. Used by
    /// the composer pill narrator to turn a bare tool name into a
    /// human-readable phrase (e.g., `web_search` + `{"query": "X"}` →
    /// "Searching the web for "X"…"). Cleared on completion / error.
    var activeToolInputJson: String?
    /// Latest plan the agent has committed via the Rust `todo_write`
    /// tool. Sticks around between turns so the user keeps seeing the
    /// plan the model is working against; cleared on new-chat /
    /// new-session, or when the agent explicitly clears via `action:
    /// "clear"`.
    var currentTodos: TodoSnapshot?
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

    /// Per-chat history of context envelopes, keyed by `activeChatId`.
    /// Every completed turn appends its snapshot so the side panel can
    /// show both the most-recent pack AND the cumulative set of notes,
    /// attachments, and routes the user has seen on this thread.
    /// Persists across chat switches — switching back restores the
    /// full history instead of starting over. Capped per chat to
    /// `maxBrainSnapshotsPerChat` so long sessions don't grow unbounded.
    private(set) var brainSnapshotsByChat: [String: [ChatBrainSnapshot]] = [:]

    /// Convenience: the latest snapshot for the currently-active chat,
    /// or nil if the chat hasn't captured one yet. Replaces the old
    /// single-snapshot property while preserving the same callsite
    /// shape the UI uses today.
    var latestBrainSnapshot: ChatBrainSnapshot? {
        guard let chatId = activeChatId else { return nil }
        return brainSnapshotsByChat[chatId]?.last
    }

    /// Full history of context envelopes for the currently-active chat,
    /// oldest → newest. Powers the "accumulate honestly" view of the
    /// transparency panel where the user can scroll through every
    /// turn's context pack.
    var brainSnapshotHistoryForActiveChat: [ChatBrainSnapshot] {
        guard let chatId = activeChatId else { return [] }
        return brainSnapshotsByChat[chatId] ?? []
    }

    /// Max snapshots kept per chat. Chosen so 50 turns of Pro-mode
    /// context stays inspectable without ballooning memory on a user
    /// who leaves a thread open for a week.
    private static let maxBrainSnapshotsPerChat = 50

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
        // Mirror the thinking-popover state cleanup. Every turn boundary
        // that resets streaming text also ends the thinking surface so a
        // fresh turn starts with a clean popover.
        resetThinkingState()
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
        // startNewChat nils the activeChatId and lets the next
        // submitQuery assign a fresh one. The brain-snapshot dict is
        // keyed by chatId so any old chat's history stays put; when
        // the new chatId is created it simply starts with an empty
        // history. No need to mutate the dictionary here.
        vaultBriefingManifest = nil
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
        currentTodos = nil
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
        mode: InferenceMode,
        resolvedModelLabel: String? = nil
    ) {
        guard let chatId = activeChatId else { return }

        // Drain any partial-tag buffer the think-tag router held back
        // waiting for disambiguation (`<thi` … etc.). Must run BEFORE
        // flushStreamingTokens so trailing reasoning lands in the
        // popover and trailing visible text lands in streamingText.
        flushThinkTagRouter()
        // Flush any buffered tokens before reading streamingText
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

        let metadata = consumeStreamingMessageMetadata()
        let completedContentBlocks = completedContentBlocks(for: answerText)

        // Extract structured artifacts (JSON, YAML, code blocks, tables)
        // from the response text. These get rendered as interactive cards.
        let artifacts = ArtifactExtractor.extract(from: answerText)

        // Silent-empty-reply guard: if the stream produced no visible text,
        // no tool-use blocks, and no artifacts, surface a concrete error
        // instead of a ghost assistant bubble the user can't see. This is
        // the classic "UI says done but nothing rendered" black-box symptom.
        let trimmedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasVisibleContent = !trimmedAnswer.isEmpty
            || !(completedContentBlocks?.isEmpty ?? true)
            || !artifacts.isEmpty
        guard hasVisibleContent else {
            log.error("[complete] Empty stream on chatId \(chatId); surfacing as error")
            streamBuffer.reset(releaseCapacity: true)
            releaseStreamingTextStorage()
            isStreaming = false
            pendingContentBlocks = []
            activeToolName = nil
        activeToolInputJson = nil
            isAgentExecuting = false
            addErrorMessage(
                "No response received. The model returned an empty stream — try again or switch models."
            )
            return
        }

        let thinkingTraceForMessage = capturedThinking.isEmpty ? nil : capturedThinking
        let thinkingDuration: Double? = {
            guard let start = thinkingStartedAt else { return nil }
            let end = thinkingEndedAt ?? Date()
            let interval = end.timeIntervalSince(start)
            return interval > 0 ? interval : nil
        }()

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
            contentBlocks: completedContentBlocks,
            resolvedModelLabel: resolvedModelLabel,
            thinkingTrace: thinkingTraceForMessage,
            thinkingDurationSeconds: thinkingDuration,
            cacheHitPercent: lastTurnCacheHitPercent
        )
        lastTurnCacheHitPercent = nil
        log.info("[complete] Appending assistant message \(assistantMessage.id)")
        messages.append(assistantMessage)
        markTranscriptChanged()

        streamBuffer.reset(releaseCapacity: true)
        releaseStreamingTextStorage()
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
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
        activeToolInputJson = nil
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

    func addErrorMessage(_ message: String, kind: UserFacingChatErrorKind? = nil) {
        let chatId = activeChatId ?? UUID().uuidString
        let errorMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: chatId,
            role: .assistant,
            content: message,
            isError: true,
            errorKind: kind
        )
        messages.append(errorMessage)
        markTranscriptChanged()
        streamBuffer.reset(releaseCapacity: true)
        releaseStreamingTextStorage()
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
        isAgentExecuting = false
    }

    /// Convenience: classify an Error through UserFacingChatError and
    /// record both the user-facing copy AND the typed kind so the error
    /// bubble can render a recovery affordance (Open Settings, etc.).
    func addErrorMessage(from error: Error) {
        let kind = UserFacingChatError.classify(error)
        addErrorMessage(UserFacingChatError.message(from: error), kind: kind)
    }

    // MARK: - Streaming

    /// Pending token buffer — accumulated between flushes.
    /// Not @Observable; only `streamingText` triggers SwiftUI updates.
    /// Stream-aware router that pulls inline `<think>…</think>` segments
    /// out of the model's visible text and redirects them to the
    /// thinking popover. Re-created at the start of every turn so tag
    /// state never leaks across turns.
    @ObservationIgnored
    private var thinkTagRouter = ThinkTagStreamRouter()

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
        activeToolInputJson = nil
        isAgentExecuting = false
        // Fresh tag-routing state per turn — partial `<think>` buffers
        // must never carry across turns or they'd misclassify the first
        // chunk of the next response.
        thinkTagRouter = ThinkTagStreamRouter()
        resetThinkingState()
    }

    func stopStreaming() {
        flushStreamingTokens()
        isStreaming = false
        onStopRequested?()
    }

    /// Capture the provider-reported usage snapshot for this turn.
    /// Called from the CloudLLMClient `usageSink` wired by
    /// ChatCoordinator. Computes the cache-hit fraction and stashes
    /// it so `completeProcessing` can stamp the assistant message.
    func recordUsageSnapshot(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int) {
        let cachedInput = max(0, cacheReadTokens)
        let freshInput = max(0, inputTokens)
        let total = freshInput + cachedInput
        guard total > 0, cachedInput > 0 else {
            lastTurnCacheHitPercent = nil
            return
        }
        lastTurnCacheHitPercent = Double(cachedInput) / Double(total)
    }

    /// Flush any partial-tag buffer held by the router at stream end.
    /// If the model closed mid-`<think>` (unlikely for well-formed
    /// emissions), the trailing text lands in the thinking popover
    /// rather than being dropped.
    func flushThinkTagRouter() {
        let emit = thinkTagRouter.flush()
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

    /// Accumulates streaming tokens off-screen while the response is generating.
    /// Live response text is intentionally not flushed into observable UI state unless the
    /// display policy enables it or the buffer grows abnormally large.
    func appendStreamingText(_ text: String) {
        // Route through the think-tag splitter FIRST. Reasoning models
        // like DeepSeek-R1 emit their chain-of-thought inside a
        // `<think>…</think>` block in the visible-text stream — without
        // this routing the reasoning streams into the main bubble, then
        // gets stripped at turn completion and visibly "disappears".
        // Now: text outside tags → visible stream, text inside tags →
        // thinking popover. State flips on opening / closing tags.
        let emit = thinkTagRouter.ingest(text)
        if !emit.thinking.isEmpty {
            appendStreamingThinking(emit.thinking)
        }

        // If the router is still mid-`<think>` we haven't received any
        // actual answer text yet. Don't close the thinking phase on a
        // zero-length visible emission.
        if !emit.visible.isEmpty {
            if isThinkingActive {
                isThinkingActive = false
                thinkingEndedAt = Date()
            }
            streamBuffer.append(emit.visible, scheduleFlush: ChatStreamingDisplayPolicy.showsLiveResponseText)
        }
    }

    /// Accumulate a live thinking delta for the currently streaming turn.
    /// The first thinking delta starts the popover (isThinkingActive = true
    /// + thinkingStartedAt). Subsequent deltas append to streamingThinking
    /// so the popover UI can render the in-flight reasoning live.
    func appendStreamingThinking(_ text: String) {
        if !isThinkingActive {
            isThinkingActive = true
            thinkingStartedAt = Date()
            streamingThinking.removeAll(keepingCapacity: true)
        }
        streamingThinking.append(text)
    }

    /// Reset all thinking-popover state between turns. Called by
    /// finalizeStreaming / clearMessages / startNewChat.
    func resetThinkingState() {
        streamingThinking.removeAll(keepingCapacity: false)
        isThinkingActive = false
        thinkingStartedAt = nil
        thinkingEndedAt = nil
    }

    private func flushStreamingTokens() {
        streamBuffer.flushNow()
    }

    func recordToolUse(id: String, name: String, inputJson: String) {
        let input = Self.decodeToolInput(inputJson)
        pendingContentBlocks.append(.toolUse(id: id, name: name, input: input))
        activeToolInputJson = inputJson
        // Capture the latest plan when the model writes to the `todo`
        // tool so the sticky card can render without waiting for the
        // result echo. Matches both the Rust tool name (`todo`) and the
        // Claude-Code convention (`todo_write`).
        if Self.isTodoWriteTool(name),
           let snapshot = TodoSnapshot.fromToolInput(inputJson) {
            currentTodos = snapshot.isEmpty ? nil : snapshot
        }
        markTranscriptChanged()
    }

    private nonisolated static func isTodoWriteTool(_ name: String) -> Bool {
        switch name.lowercased() {
        case "todo", "todo_write", "todo_update", "todowrite":
            return true
        default:
            return false
        }
    }

    func recordToolResult(toolUseId: String, result: String, isError: Bool) {
        pendingContentBlocks.append(
            .toolResult(toolUseId: toolUseId, content: result, isError: isError)
        )
        activeToolInputJson = nil
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
        recalculateContextEstimate()
    }
    func removeAttachment(_ id: String) {
        pendingAttachments.removeAll { $0.id == id }
        recalculateContextEstimate()
    }

    func addContextAttachment(_ attachment: ContextAttachment) {
        guard !pendingContextAttachments.contains(attachment) else { return }
        pendingContextAttachments.append(attachment)
        recalculateContextEstimate()
    }

    func removeContextAttachment(_ id: String) {
        pendingContextAttachments.removeAll { $0.id == id }
        recalculateContextEstimate()
    }

    func captureBrainSnapshot(_ snapshot: ChatBrainSnapshot) {
        guard let chatId = activeChatId else { return }
        var history = brainSnapshotsByChat[chatId] ?? []
        history.append(snapshot)
        if history.count > Self.maxBrainSnapshotsPerChat {
            history.removeFirst(history.count - Self.maxBrainSnapshotsPerChat)
        }
        brainSnapshotsByChat[chatId] = history
    }

    func updateBrainSnapshotSection(
        _ section: ChatBrainSection,
        matchingCapturedAt capturedAt: Date
    ) {
        guard let chatId = activeChatId,
              var history = brainSnapshotsByChat[chatId],
              let index = history.lastIndex(where: { $0.capturedAt == capturedAt }) else {
            return
        }
        history[index] = history[index].updatingSection(section)
        brainSnapshotsByChat[chatId] = history
    }

    /// Clear the snapshot history for a given chat. Called when the
    /// chat is deleted OR when the user explicitly resets it; switching
    /// chats MUST NOT trigger this (the whole point of the per-chat
    /// dictionary is persistence across switches).
    func clearBrainSnapshotHistory(for chatId: String) {
        brainSnapshotsByChat[chatId] = nil
    }

    // MARK: - Load / Clear

    func loadMessages(_ msgs: [ChatMessage]) {
        messages = msgs
        markTranscriptChanged()
        hasMessages = !msgs.isEmpty
        showLanding = msgs.isEmpty
        pendingAttachments = []
        restoreConversationContext(from: msgs)
        // Brain-snapshot history is keyed by chatId and persisted
        // across chat switches. Do NOT nil it here — that was the old
        // behavior the user explicitly asked to change so the Context
        // panel stays populated when they come back to a thread.
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
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
        // Explicit user action to clear this chat → discard the
        // matching brain-snapshot history. Other chats' snapshots are
        // untouched because the dictionary is keyed by chatId.
        if let chatId { clearBrainSnapshotHistory(for: chatId) }
        vaultBriefingManifest = nil
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
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
