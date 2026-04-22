import Foundation
import Observation
import os

struct ChatBrainSection: Identifiable, Sendable, Equatable, Codable {
    let title: String
    let body: String

    var id: String { title }

    init(title: String, body: String) {
        self.title = title
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ChatBrainSnapshot: Sendable, Equatable, Codable {
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

struct CapturedModelInput: Sendable, Equatable {
    let capturedAt: Date
    let runtimeLabel: String
    let systemPrompt: String?
    let userPrompt: String
    let messageHistory: String?
    let toolDefinitionsJSON: String?

    init(
        capturedAt: Date = Date(),
        runtimeLabel: String,
        systemPrompt: String?,
        userPrompt: String,
        messageHistory: String?,
        toolDefinitionsJSON: String?
    ) {
        self.capturedAt = capturedAt
        self.runtimeLabel = runtimeLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedSystemPrompt = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.systemPrompt = trimmedSystemPrompt?.isEmpty == true ? nil : trimmedSystemPrompt

        self.userPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedHistory = messageHistory?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.messageHistory = trimmedHistory?.isEmpty == true ? nil : trimmedHistory

        let trimmedToolDefinitions = toolDefinitionsJSON?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toolDefinitionsJSON = trimmedToolDefinitions?.isEmpty == true ? nil : trimmedToolDefinitions
    }
}

enum StreamingReasoningTraceBuffer {
    static let postAnswerDisplaySeparator = "After-answer thought:\n"

    private static func deltaToAppend(current: String, incoming: String) -> String {
        guard !incoming.isEmpty else { return "" }
        guard !current.isEmpty else { return incoming }
        if incoming == current || current.hasSuffix(incoming) {
            return ""
        }
        if incoming.hasPrefix(current) {
            return String(incoming.dropFirst(current.count))
        }
        return incoming
    }

    static func append(
        _ text: String,
        streamingThinking: inout String,
        postAnswerThinking: inout String,
        hasStartedVisibleAnswer: Bool,
        isThinkingActive: inout Bool,
        thinkingStartedAt: inout Date?,
        thinkingEndedAt: inout Date?
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isThinkingActive || thinkingStartedAt != nil || !trimmed.isEmpty else { return }

        if thinkingStartedAt == nil {
            thinkingStartedAt = .now
            streamingThinking.removeAll(keepingCapacity: true)
            postAnswerThinking.removeAll(keepingCapacity: true)
        }

        let textToAppend = deltaToAppend(current: streamingThinking, incoming: text)
        guard !textToAppend.isEmpty else { return }

        if hasStartedVisibleAnswer {
            if isThinkingActive {
                isThinkingActive = false
            }
            if postAnswerThinking.isEmpty {
                if !streamingThinking.isEmpty {
                    streamingThinking.append("\n\n")
                }
                streamingThinking.append(postAnswerDisplaySeparator)
            }
            postAnswerThinking.append(textToAppend)
            thinkingEndedAt = .now
        } else {
            thinkingEndedAt = nil
        }

        streamingThinking.append(textToAppend)
    }

    static func append(
        _ text: String,
        streamingThinking: inout String,
        postAnswerThinking: inout String,
        hasStartedVisibleAnswer: Bool,
        thinkingStartedAt: inout Date?,
        thinkingEndedAt: inout Date?
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard thinkingStartedAt != nil || !trimmed.isEmpty else { return }

        if thinkingStartedAt == nil {
            thinkingStartedAt = .now
            streamingThinking.removeAll(keepingCapacity: true)
            postAnswerThinking.removeAll(keepingCapacity: true)
        }

        let textToAppend = deltaToAppend(current: streamingThinking, incoming: text)
        guard !textToAppend.isEmpty else { return }

        if hasStartedVisibleAnswer {
            if postAnswerThinking.isEmpty {
                if !streamingThinking.isEmpty {
                    streamingThinking.append("\n\n")
                }
                streamingThinking.append(postAnswerDisplaySeparator)
            }
            postAnswerThinking.append(textToAppend)
            thinkingEndedAt = .now
        } else {
            thinkingEndedAt = nil
        }

        streamingThinking.append(textToAppend)
    }
}

// MARK: - Chat State
// In-memory streaming and message state for the active chat session.
// AppBootstrap persists completed messages to SDChat/SDMessage via SwiftData.

@MainActor @Observable
final class ChatState {
    private static let reasoningFirstAnswerHold: Duration = .milliseconds(450)
    private let log = Logger(subsystem: "com.epistemos", category: "ChatState")
    // MARK: - Streaming

    var isStreaming = false
    var streamingText = ""
    /// Accumulated thinking-mode deltas for the currently streaming turn.
    /// Populated live as `onThinkingDelta` events arrive so the thinking
    /// popover can render in-flight reasoning (ChatGPT-style). Cleared
    /// when a new turn starts or when the turn completes.
    var streamingThinking = ""
    private var postAnswerThinking = ""
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
    /// Timestamp when the first visible answer token arrived this turn.
    /// Used to hold the initial answer very briefly after a real thinking
    /// phase so the UI shows "thinking, then answer" instead of both at once.
    var visibleAnswerStartedAt: Date?
    /// Cache-hit fraction captured from the most recent turn's
    /// provider-reported usage. Populated by `recordUsageSnapshot` and
    /// consumed at `completeProcessing` when building the assistant
    /// ChatMessage so the persisted bubble can render a "cache N%"
    /// badge. Nil when the provider didn't report cache tokens.
    var lastTurnCacheHitPercent: Double?
    var activeChatId: String?
    private var interruptedAssistantMessageIDs: Set<String> = []
    var chatTitle: String?
    var pendingAttachments: [FileAttachment] = []
    var pendingContextAttachments: [ContextAttachment] = []
    var pendingComposerDraft: String?
    private(set) var pendingComposerDraftRevision: UInt = 0
    var pendingGraphChatRequest: GraphChatRequest?
    private var pendingSlashCommand: ACCSlashCommand?

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

    func syncContextWindowMetrics(maxTokens: Int? = nil) {
        if let maxTokens {
            self.maxContextTokens = max(1, maxTokens)
        }
        recalculateContextEstimate()
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

    /// Per-chat history of the final, fully assembled model inputs the
    /// pipeline actually sent to the runtime. Kept alongside the higher-level
    /// brain snapshots so the transparency pane can show both the planning
    /// view and the post-assembly truth.
    private(set) var capturedModelInputsByChat: [String: [CapturedModelInput]] = [:]

    var latestCapturedModelInput: CapturedModelInput? {
        guard let chatId = activeChatId else { return nil }
        return capturedModelInputsByChat[chatId]?.last
    }

    private static let maxCapturedModelInputsPerChat = 50

    /// Transient flag — true when the current streaming response is a vault briefing.
    /// Set by AppBootstrap, read by finalizeStreaming to stamp the ChatMessage.
    var isCurrentVaultBriefing = false

    /// Transient: full manifest (with bodies) used only for vault briefing requests.
    /// Set by requestVaultBriefing, consumed and cleared by handleQuery.
    var vaultBriefingManifest: VaultManifest?

    // MARK: - Init

    init() {
        loadPersistedBrainSnapshotsFromDisk()
    }

    // MARK: - Brain-snapshot disk persistence
    //
    // `brainSnapshotsByChat` is the per-chat context-envelope history the
    // right-side context panel renders. Pre-Pass-6 it lived in @Observable
    // memory only, so app relaunch wiped it. This section mirrors it to a
    // single JSON file under ApplicationSupport. Writes are debounced so
    // rapid-fire capture bursts during streaming don't thrash the disk.

    private nonisolated static let brainSnapshotPersistenceDebounceNanos: UInt64 = 2_000_000_000

    private var brainSnapshotPersistenceTask: Task<Void, Never>?

    nonisolated static func brainSnapshotsPersistenceURL() -> URL {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        let dir = appSupport.appendingPathComponent("Epistemos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("brain_snapshots.json", isDirectory: false)
    }

    private func loadPersistedBrainSnapshotsFromDisk() {
        let url = Self.brainSnapshotsPersistenceURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([String: [ChatBrainSnapshot]].self, from: data) else {
            return
        }
        brainSnapshotsByChat = decoded
    }

    private func scheduleBrainSnapshotPersistence() {
        brainSnapshotPersistenceTask?.cancel()
        let snapshot = brainSnapshotsByChat
        let url = Self.brainSnapshotsPersistenceURL()
        let debounceNanos = Self.brainSnapshotPersistenceDebounceNanos
        brainSnapshotPersistenceTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: debounceNanos)
            if Task.isCancelled { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    func primeComposerDraft(_ draft: String) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        pendingComposerDraft = trimmed
        pendingComposerDraftRevision &+= 1
    }

    func consumePendingComposerDraft() -> String? {
        let trimmed = pendingComposerDraft?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingComposerDraft = nil
        return trimmed?.isEmpty == true ? nil : trimmed
    }

    func primeGraphChatRequest(_ request: GraphChatRequest) {
        pendingGraphChatRequest = request
    }

    func consumePendingGraphChatRequest() -> GraphChatRequest? {
        let request = pendingGraphChatRequest
        pendingGraphChatRequest = nil
        return request
    }

    func serializedConversationHistory(
        maxCharacters: Int,
        maxMessages: Int
    ) -> String? {
        guard maxCharacters > 0, maxMessages > 0 else { return nil }

        let priorMessages = messages.dropLast()
        guard !priorMessages.isEmpty else { return nil }

        let recentMessages = Array(priorMessages.suffix(maxMessages))
        let perMessageBudget = max(160, min(2_000, maxCharacters / max(1, recentMessages.count)))
        var blocks: [String] = []
        var usedCharacters = 0

        for message in recentMessages.reversed() {
            let block = serializedConversationHistoryBlock(
                for: message,
                maxCharacters: perMessageBudget
            )
            guard !block.isEmpty else { continue }

            let separatorCost = blocks.isEmpty ? 0 : 2
            guard usedCharacters + separatorCost + block.count <= maxCharacters else { break }
            usedCharacters += separatorCost + block.count
            blocks.insert(block, at: 0)
        }

        guard !blocks.isEmpty else { return nil }
        return blocks.joined(separator: "\n\n")
    }

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
        pendingGraphChatRequest = nil
        pendingSlashCommand = nil
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
        interruptedAssistantMessageIDs = []
        syncContextWindowMetrics()
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
        syncContextWindowMetrics()
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

    func queuePendingSlashCommand(_ command: ACCSlashCommand?) {
        pendingSlashCommand = command
    }

    func consumePendingSlashCommand() -> ACCSlashCommand? {
        defer { pendingSlashCommand = nil }
        return pendingSlashCommand
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
        syncContextWindowMetrics()
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
            let salvagedFromThinking = UserFacingModelOutput
                .salvagedAnswerFromThinkingTrace(from: capturedThinking) ?? ""
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

        // Suppress the thinking trace when it's near-identical to the
        // answer. OpenAI's reasoning summaries for simple queries can
        // naturally mirror the output text, causing the thinking bubble
        // to show the same content as the answer — which looks broken.
        // Dedup threshold: if 80%+ of the thinking appears verbatim in
        // the answer (or vice versa), suppress the thinking display.
        let thinkingTraceForMessage: String? = {
            guard !capturedThinking.isEmpty else { return nil }
            let trimmedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAnswer.isEmpty else { return capturedThinking }
            let shorter = min(capturedThinking.count, trimmedAnswer.count)
            let longer = max(capturedThinking.count, trimmedAnswer.count)
            guard shorter > 0, longer > 0 else { return capturedThinking }
            // Quick check: if lengths are very similar and prefix matches
            let prefixLen = min(200, shorter)
            let thinkingPrefix = String(capturedThinking.prefix(prefixLen)).lowercased()
            let answerPrefix = String(trimmedAnswer.prefix(prefixLen)).lowercased()
            if thinkingPrefix == answerPrefix && Double(shorter) / Double(longer) > 0.8 {
                return nil  // Content is duplicated — suppress thinking bubble
            }
            return capturedThinking
        }()
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
        interruptedAssistantMessageIDs.remove(assistantMessage.id)
        markTranscriptChanged()
        syncContextWindowMetrics()

        streamBuffer.reset(releaseCapacity: true)
        releaseStreamingTextStorage()
        isStreaming = false
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
        isAgentExecuting = false
        resetThinkingState()
        thinkTagRouter = ThinkTagStreamRouter()
        eventBus?.emit(.queryCompleted(chatId: ChatId(chatId), messageId: MessageId(assistantMessage.id)))
    }

    @discardableResult
    func completeCancelledProcessing(
        messageId: String = UUID().uuidString,
        mode: InferenceMode,
        resolvedModelLabel: String? = nil
    ) -> Bool {
        flushThinkTagRouter()
        flushStreamingTokens()

        let capturedThinking = streamingThinking.trimmingCharacters(in: .whitespacesAndNewlines)
        var answerText = UserFacingModelOutput.finalVisibleText(from: streamingText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if answerText.isEmpty, !capturedThinking.isEmpty {
            let salvagedFromThinking = UserFacingModelOutput
                .salvagedAnswerFromThinkingTrace(from: capturedThinking) ?? ""
            if !salvagedFromThinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                answerText = salvagedFromThinking.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let fallback = UserFacingModelOutput.incompleteReasoningFallback(from: capturedThinking) {
                answerText = fallback
            }
        }
        let metadata = consumeStreamingMessageMetadata()
        let completedContentBlocks = completedContentBlocks(for: answerText)
        let artifacts = ArtifactExtractor.extract(from: answerText)
        let trimmedAnswer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasVisibleContent = !trimmedAnswer.isEmpty
            || !(completedContentBlocks?.isEmpty ?? true)
            || !artifacts.isEmpty
        let thinkingDuration: Double? = {
            guard let start = thinkingStartedAt else { return nil }
            let end = thinkingEndedAt ?? Date()
            let interval = end.timeIntervalSince(start)
            return interval > 0 ? interval : nil
        }()

        defer {
            streamBuffer.reset(releaseCapacity: true)
            releaseStreamingTextStorage()
            isStreaming = false
            pendingContentBlocks = []
            activeToolName = nil
            activeToolInputJson = nil
            isAgentExecuting = false
            lastTurnCacheHitPercent = nil
            resetThinkingState()
            thinkTagRouter = ThinkTagStreamRouter()
        }

        guard let chatId = activeChatId, hasVisibleContent else { return false }

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
            thinkingTrace: capturedThinking.isEmpty ? nil : capturedThinking,
            thinkingDurationSeconds: thinkingDuration,
            cacheHitPercent: lastTurnCacheHitPercent
        )
        messages.append(assistantMessage)
        interruptedAssistantMessageIDs.insert(assistantMessage.id)
        markTranscriptChanged()
        syncContextWindowMetrics()
        return true
    }

    /// Update the last message's content (used for post-processing like vault action markers).
    func updateLastMessageContent(_ newContent: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content = newContent
        markTranscriptChanged()
        syncContextWindowMetrics()
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
        syncContextWindowMetrics()
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
    private var userFacingStreamRouter = UserFacingStreamRouter()

    @ObservationIgnored
    private var hasStartedVisibleAnswer = false

    @ObservationIgnored
    private var hasExplicitThinkingTrace = false

    @ObservationIgnored
    private lazy var streamBuffer = DisplayPacedTextBuffer { [weak self] delta in
        self?.streamingText += delta
    }

    @ObservationIgnored
    private var deferredVisibleAnswerBuffer = ""

    @ObservationIgnored
    private var deferredVisibleAnswerTask: Task<Void, Never>?

    @ObservationIgnored
    private var deferredVisibleAnswerRevision: UInt = 0

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
            appendStreamingThinking(emit.thinking, explicit: true)
        }
        routeVisibleStreamingText(emit.visible, scheduleFlush: true)
        routeVisibleStreamingText(userFacingStreamRouter.flush().visible, scheduleFlush: true)
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
            appendStreamingThinking(emit.thinking, explicit: true)
        }
        if hasExplicitThinkingTrace, !hasStartedVisibleAnswer {
            routeVisibleStreamingText(
                emit.visible,
                scheduleFlush: ChatStreamingDisplayPolicy.showsLiveResponseText
            )
            return
        }
        let visibleEmit = userFacingStreamRouter.ingest(emit.visible)
        if !visibleEmit.thinking.isEmpty {
            appendStreamingThinking(visibleEmit.thinking)
        }
        routeVisibleStreamingText(
            visibleEmit.visible,
            scheduleFlush: ChatStreamingDisplayPolicy.showsLiveResponseText
        )
    }

    /// Accumulate a live thinking delta for the currently streaming turn.
    /// The first thinking delta starts the popover (isThinkingActive = true
    /// + thinkingStartedAt). Subsequent deltas append to streamingThinking
    /// so the popover UI can render the in-flight reasoning live.
    func appendStreamingThinking(_ text: String, explicit: Bool = false) {
        if hasStartedVisibleAnswer {
            if thinkingEndedAt == nil {
                thinkingEndedAt = visibleAnswerStartedAt ?? Date()
            }
            return
        }
        if explicit {
            hasExplicitThinkingTrace = true
        }
        if !hasStartedVisibleAnswer, !isThinkingActive {
            isThinkingActive = true
        }
        StreamingReasoningTraceBuffer.append(
            text,
            streamingThinking: &streamingThinking,
            postAnswerThinking: &postAnswerThinking,
            hasStartedVisibleAnswer: hasStartedVisibleAnswer,
            isThinkingActive: &isThinkingActive,
            thinkingStartedAt: &thinkingStartedAt,
            thinkingEndedAt: &thinkingEndedAt
        )
    }

    /// Reset all thinking-popover state between turns. Called by
    /// finalizeStreaming / clearMessages / startNewChat.
    func resetThinkingState() {
        streamingThinking.removeAll(keepingCapacity: false)
        postAnswerThinking.removeAll(keepingCapacity: false)
        isThinkingActive = false
        thinkingStartedAt = nil
        thinkingEndedAt = nil
        visibleAnswerStartedAt = nil
        hasStartedVisibleAnswer = false
        hasExplicitThinkingTrace = false
        userFacingStreamRouter.reset()
        deferredVisibleAnswerTask?.cancel()
        deferredVisibleAnswerTask = nil
        deferredVisibleAnswerBuffer.removeAll(keepingCapacity: false)
    }

    private func routeVisibleStreamingText(_ text: String, scheduleFlush: Bool) {
        guard !text.isEmpty else { return }
        let shouldHoldFirstAnswer = thinkingStartedAt != nil && !hasStartedVisibleAnswer
        if shouldHoldFirstAnswer || !deferredVisibleAnswerBuffer.isEmpty {
            if visibleAnswerStartedAt == nil {
                visibleAnswerStartedAt = Date()
            }
            hasStartedVisibleAnswer = true
            if isThinkingActive {
                isThinkingActive = false
                thinkingEndedAt = visibleAnswerStartedAt
            } else if thinkingEndedAt == nil {
                thinkingEndedAt = visibleAnswerStartedAt
            }
            deferredVisibleAnswerBuffer.append(text)
            scheduleDeferredVisibleAnswerFlush(scheduleFlush: scheduleFlush)
            return
        }
        hasStartedVisibleAnswer = true
        if visibleAnswerStartedAt == nil {
            visibleAnswerStartedAt = Date()
        }
        if isThinkingActive {
            isThinkingActive = false
            thinkingEndedAt = visibleAnswerStartedAt
        }
        streamBuffer.append(text, scheduleFlush: scheduleFlush)
    }

    private func flushStreamingTokens() {
        flushDeferredVisibleAnswerBuffer(scheduleFlush: false)
        streamBuffer.flushNow()
    }

    func overrideStreamingAnswerForCompletion(_ text: String) {
        deferredVisibleAnswerTask?.cancel()
        deferredVisibleAnswerTask = nil
        deferredVisibleAnswerBuffer.removeAll(keepingCapacity: false)
        streamBuffer.reset()
        streamingText = text
        hasStartedVisibleAnswer = true
        if visibleAnswerStartedAt == nil {
            visibleAnswerStartedAt = Date()
        }
        if isThinkingActive {
            isThinkingActive = false
            thinkingEndedAt = visibleAnswerStartedAt
        } else if thinkingEndedAt == nil {
            thinkingEndedAt = visibleAnswerStartedAt
        }
    }

    private func scheduleDeferredVisibleAnswerFlush(scheduleFlush: Bool) {
        deferredVisibleAnswerRevision &+= 1
        let revision = deferredVisibleAnswerRevision
        deferredVisibleAnswerTask?.cancel()
        deferredVisibleAnswerTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.reasoningFirstAnswerHold)
            } catch {
                return
            }
            guard let self, self.deferredVisibleAnswerRevision == revision else { return }
            self.flushDeferredVisibleAnswerBuffer(scheduleFlush: scheduleFlush)
        }
    }

    private func flushDeferredVisibleAnswerBuffer(scheduleFlush: Bool) {
        deferredVisibleAnswerTask?.cancel()
        deferredVisibleAnswerTask = nil
        guard !deferredVisibleAnswerBuffer.isEmpty else { return }
        let buffered = deferredVisibleAnswerBuffer
        deferredVisibleAnswerBuffer.removeAll(keepingCapacity: true)
        streamBuffer.append(buffered, scheduleFlush: scheduleFlush)
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
        syncContextWindowMetrics()
    }
    func removeAttachment(_ id: String) {
        pendingAttachments.removeAll { $0.id == id }
        syncContextWindowMetrics()
    }

    func addContextAttachment(_ attachment: ContextAttachment) {
        guard !pendingContextAttachments.contains(attachment) else { return }
        pendingContextAttachments.append(attachment)
        syncContextWindowMetrics()
    }

    func removeContextAttachment(_ id: String) {
        pendingContextAttachments.removeAll { $0.id == id }
        syncContextWindowMetrics()
    }

    func captureBrainSnapshot(_ snapshot: ChatBrainSnapshot) {
        guard let chatId = activeChatId else { return }
        var history = brainSnapshotsByChat[chatId] ?? []
        history.append(snapshot)
        if history.count > Self.maxBrainSnapshotsPerChat {
            history.removeFirst(history.count - Self.maxBrainSnapshotsPerChat)
        }
        brainSnapshotsByChat[chatId] = history
        scheduleBrainSnapshotPersistence()
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
        scheduleBrainSnapshotPersistence()
    }

    func captureModelInput(_ input: CapturedModelInput) {
        guard let chatId = activeChatId else { return }
        var history = capturedModelInputsByChat[chatId] ?? []
        history.append(input)
        if history.count > Self.maxCapturedModelInputsPerChat {
            history.removeFirst(history.count - Self.maxCapturedModelInputsPerChat)
        }
        capturedModelInputsByChat[chatId] = history
    }

    /// Clear the snapshot history for a given chat. Called when the
    /// chat is deleted OR when the user explicitly resets it; switching
    /// chats MUST NOT trigger this (the whole point of the per-chat
    /// dictionary is persistence across switches).
    func clearBrainSnapshotHistory(for chatId: String) {
        brainSnapshotsByChat[chatId] = nil
        scheduleBrainSnapshotPersistence()
    }

    func clearCapturedModelInputHistory(for chatId: String) {
        capturedModelInputsByChat[chatId] = nil
    }

    // MARK: - Load / Clear

    func loadMessages(_ msgs: [ChatMessage]) {
        messages = msgs
        markTranscriptChanged()
        hasMessages = !msgs.isEmpty
        showLanding = msgs.isEmpty
        pendingAttachments = []
        interruptedAssistantMessageIDs = Set(
            msgs.filter(Self.looksLikeInterruptedCheckpoint).map(\.id)
        )
        restoreConversationContext(from: msgs)
        // Brain-snapshot history is keyed by chatId and persisted
        // across chat switches. Do NOT nil it here — that was the old
        // behavior the user explicitly asked to change so the Context
        // panel stays populated when they come back to a thread.
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
        isAgentExecuting = false
        syncContextWindowMetrics()
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
        if let chatId {
            clearBrainSnapshotHistory(for: chatId)
            clearCapturedModelInputHistory(for: chatId)
        }
        vaultBriefingManifest = nil
        pendingContentBlocks = []
        activeToolName = nil
        activeToolInputJson = nil
        isAgentExecuting = false
        activeChatId = nil
        chatTitle = nil
        interruptedAssistantMessageIDs = []
        syncContextWindowMetrics()

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

    private func serializedConversationHistoryBlock(
        for message: ChatMessage,
        maxCharacters: Int
    ) -> String {
        let roleLabel = message.role == .user ? "User" : "Assistant"
        var lines = ["\(roleLabel): \(Self.truncatedHistoryText(message.content, limit: maxCharacters))"]

        if isInterruptedReasoningCheckpoint(message),
           let trace = message.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trace.isEmpty {
            lines.append(
                "Assistant reasoning checkpoint: \(Self.truncatedHistoryText(trace, limit: maxCharacters))"
            )
        }

        return lines.joined(separator: "\n")
    }

    private func isInterruptedReasoningCheckpoint(_ message: ChatMessage) -> Bool {
        interruptedAssistantMessageIDs.contains(message.id) || Self.looksLikeInterruptedCheckpoint(message)
    }

    private static func looksLikeInterruptedCheckpoint(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant,
              let trace = message.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trace.isEmpty else {
            return false
        }

        return message.content.localizedCaseInsensitiveContains("never produced a final answer")
    }

    private static func truncatedHistoryText(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
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
