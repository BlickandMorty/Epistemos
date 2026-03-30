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

    /// Controls whether the landing page or chat view is shown on the Home panel.
    /// `true` = landing page visible (even if messages exist in memory).
    /// Messages stay alive while the user navigates away and back.
    var showLanding = true

    // MARK: - Incognito
    /// When true, chat messages are kept in-memory only — not persisted to SwiftData.
    var isIncognito = false

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
        streamBuffer.reset()

        messages = []
        markTranscriptChanged()
        hasMessages = false
        streamingText = ""
        isStreaming = false
        activeChatId = nil
        chatTitle = nil
        showLanding = false
        loadedNoteIds = []
        loadedNoteTitles = []
        pendingContextAttachments = []
        vaultBriefingManifest = nil
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
        streamingText = ""
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

        // Capture Notes Mode flags for this message, then reset for next turn
        let briefing = isCurrentVaultBriefing
        let noteTitles = loadedNoteTitles.isEmpty ? nil : loadedNoteTitles
        let contextAttachments = pendingContextAttachments.isEmpty ? nil : pendingContextAttachments
        isCurrentVaultBriefing = false
        loadedNoteTitles = []

        let assistantMessage = ChatMessage(
            id: messageId,
            chatId: chatId,
            role: .assistant,
            content: answerText,
            mode: mode,
            isVaultBriefing: briefing,
            loadedNoteTitles: noteTitles,
            contextAttachments: contextAttachments
        )
        log.info("[complete] Appending assistant message \(assistantMessage.id)")
        messages.append(assistantMessage)
        markTranscriptChanged()

        streamingText = ""
        isStreaming = false
        eventBus?.emit(.queryCompleted(chatId: ChatId(chatId), messageId: MessageId(assistantMessage.id)))
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
        streamingText = ""
        isStreaming = false
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
    }

    func clearMessages() {
        let chatId = activeChatId
        streamBuffer.reset()

        messages = []
        markTranscriptChanged()
        hasMessages = false
        streamingText = ""
        isStreaming = false
        isIncognito = false
        showLanding = true
        loadedNoteIds = []
        loadedNoteTitles = []
        vaultBriefingManifest = nil
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
        showOmegaPanel: () -> Void = { UtilityWindowManager.shared.show(.omega) }
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let contextAttachments = chat.pendingContextAttachments.isEmpty
            ? nil
            : chat.pendingContextAttachments

        switch operatingMode {
        case .agent:
            chat.appendLocalMessage(
                role: .user,
                content: trimmed,
                contextAttachments: contextAttachments
            )
            if let handoffMessage = operatingMode.handoffMessage {
                chat.appendLocalMessage(role: .assistant, content: handoffMessage)
            }
            showOmegaPanel()
            Task {
                await orchestrator.submitTask(trimmed)
            }

        case .fast, .thinking:
            chat.submitQuery(trimmed, operatingMode: operatingMode)
        }
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

    func reset() {
        flushTask?.cancel()
        flushTask = nil
        pendingText.removeAll(keepingCapacity: true)
    }
}
