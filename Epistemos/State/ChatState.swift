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
    var activeMessageLayer: String = "raw"
    var activeChatId: String?
    var chatTitle: String?
    var pendingAttachments: [FileAttachment] = []
    var reasoningText = ""
    var reasoningDuration: Double?
    var isReasoning = false

    /// Tracks when a research query started — drives the elapsed timer in ThinkingAccordion.
    var researchStartTime: Date?

    /// Tracks when reasoning started — used to calculate duration on completion.
    private var reasoningStartTime: ContinuousClock.Instant?

    // MARK: - In-memory messages (current session)
    var messages: [ChatMessage] = []
    var hasMessages = false

    /// Controls whether the landing page or chat view is shown on the Home panel.
    /// `true` = landing page visible (even if messages exist in memory).
    /// Messages stay alive so background enrichment can still update them.
    var showLanding = true

    // MARK: - Incognito
    /// When true, chat messages are kept in-memory only — not persisted to SwiftData.
    var isIncognito = false

    // MARK: - Research Mode
    /// When true, queries run the full 6-pass pipeline (Lucid Lens, reflection, arbitration, truth assessment).
    /// When false (regular chat), queries get a direct response + signal-based arbitration only.
    /// Persisted to UserDefaults — this is a user preference, not session state.
    var isResearchMode: Bool {
        didSet { UserDefaults.standard.set(isResearchMode, forKey: "epistemos.researchMode") }
    }

    // MARK: - Notes Mode
    /// When true, chat has full vault context — manifest + @-referenced note bodies.
    /// Can be combined with Research Mode for vault-aware deep analysis.
    var isNotesMode = false

    /// Cached vault manifest built on Notes Mode entry. Cleared when Notes Mode is toggled off.
    var vaultManifest: VaultManifest?

    /// Page IDs of notes whose full bodies have been loaded into context via @-mentions.
    var loadedNoteIds: Set<String> = []

    /// Titles of notes loaded via @-mentions (for UI chips on messages).
    var loadedNoteTitles: [String] = []

    /// Transient flag — true when the current streaming response is a vault briefing.
    /// Set by AppBootstrap, read by finalizeStreaming to stamp the ChatMessage.
    var isCurrentVaultBriefing = false

    /// Enable Notes Mode. Can be combined with Research Mode.
    func enableNotesMode() {
        isNotesMode = true
    }

    /// Disable Notes Mode and clear vault state.
    func disableNotesMode() {
        isNotesMode = false
        vaultManifest = nil
        loadedNoteIds = []
        loadedNoteTitles = []
        isCurrentVaultBriefing = false
    }

    /// Enable Research Mode. Can be combined with Notes Mode.
    func enableResearchMode() {
        isResearchMode = true
    }

    /// Disable Research Mode only.
    func disableResearchMode() {
        isResearchMode = false
    }

    /// Disable all special modes — return to Regular.
    func disableSpecialModes() {
        disableResearchMode()
        disableNotesMode()
    }

    // MARK: - Init

    init() {
        // Migration: research mode was stored in Epistemos domain during rename session
        var research = UserDefaults.standard.bool(forKey: "epistemos.researchMode")
        if !research,
           let oldSuite = UserDefaults(suiteName: "Brainiac.epistemos"),
           oldSuite.bool(forKey: "epistemos.researchMode") {
            research = true
            UserDefaults.standard.set(true, forKey: "epistemos.researchMode")
            oldSuite.removeObject(forKey: "epistemos.researchMode")
        }
        self.isResearchMode = research
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
    /// Messages stay alive so in-flight enrichment can still update them.
    func goHome() {
        showLanding = true
    }

    /// Start a fresh chat session. Clears old messages and activeChatId so the
    /// next submitQuery creates a new conversation. Preserves mode preferences.
    func startNewChat() {
        // Cancel pending token flushes
        streamFlushTask?.cancel()
        streamFlushTask = nil
        reasoningFlushTask?.cancel()
        reasoningFlushTask = nil
        pendingStreamTokens = ""
        pendingReasoningTokens = ""

        messages = []
        hasMessages = false
        streamingText = ""
        isStreaming = false
        reasoningText = ""
        isReasoning = false
        activeChatId = nil
        chatTitle = nil
        showLanding = false
        isNotesMode = false          // Reset — Notes Mode is a one-shot action, not a preference.
        vaultManifest = nil          // Clear stale vault manifest from previous session.
        loadedNoteIds = []
        loadedNoteTitles = []
        // Note: isResearchMode is NOT reset — it's a persisted user preference (stored in UserDefaults).
        // Note: researchStartTime is NOT reset — old enrichment may still be running.
    }

    /// Maximum user query length (chars). Gemini/GPT context windows are large,
    /// but sending excessively long input wastes tokens and can hit API limits.
    private static let maxQueryLength = 50_000

    func submitQuery(_ query: String) {
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
            attachments: pendingAttachments
        )
        messages.append(userMessage)
        hasMessages = true

        pendingAttachments = []
        streamingText = ""
        isStreaming = false
        reasoningText = ""
        reasoningDuration = nil
        isReasoning = false

        eventBus?.emit(.querySubmitted(chatId: ChatId(chatId), query: safeQuery))
    }

    func completeProcessing(
        dualMessage: DualMessage,
        confidence: Double,
        grade: EvidenceGrade,
        mode: InferenceMode,
        truthAssessment: TruthAssessment? = nil,
        isResearchResult: Bool = false
    ) {
        guard let chatId = activeChatId else { return }

        // Flush any buffered tokens before reading streamingText
        flushStreamingTokens()
        flushReasoningTokens()

        // Strip [CONCEPTS: ...] tag if the LLM included it (parsed by EnrichmentController)
        let (_, cleaned) = EnrichmentController.parseConceptsTag(from: streamingText)
        let answerText = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // End reasoning if it's still active (model produced no streaming tokens)
        if isReasoning { endReasoning() }

        // Capture reasoning text + duration onto the completed message
        let reasoning = reasoningText.isEmpty ? nil : reasoningText
        let thinkDuration = reasoningDuration

        // Capture Notes Mode flags for this message, then reset for next turn
        let briefing = isCurrentVaultBriefing
        let noteTitles = loadedNoteTitles.isEmpty ? nil : loadedNoteTitles
        isCurrentVaultBriefing = false
        loadedNoteTitles = []

        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            chatId: chatId,
            role: .assistant,
            content: answerText,
            dualMessage: dualMessage,
            truthAssessment: truthAssessment,
            confidence: confidence,
            evidenceGrade: grade,
            mode: mode,
            reasoningText: reasoning,
            reasoningDuration: thinkDuration,
            isVaultBriefing: briefing,
            loadedNoteTitles: noteTitles,
            isResearchResult: isResearchResult
        )
        log.info("[complete] Appending assistant message \(assistantMessage.id) — isResearchResult=\(isResearchResult) rawAnalysisLen=\(dualMessage.rawAnalysis.count)")
        messages.append(assistantMessage)

        streamingText = ""
        isStreaming = false
        // Note: researchStartTime is NOT cleared here — it persists until enrichment
        // completes so the ThinkingAccordion on the message can keep ticking.
        // Cleared in enrichLastMessage() or clearMessages().
        if !isResearchResult {
            researchStartTime = nil
        }

        eventBus?.emit(.queryCompleted(chatId: ChatId(chatId), messageId: MessageId(assistantMessage.id)))
    }

    /// Update the last message's content (used for post-processing like vault action markers).
    func updateLastMessageContent(_ newContent: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content = newContent
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
        streamingText = ""
        isStreaming = false
    }

    // MARK: - Streaming

    /// Pending token buffer — accumulated between flushes.
    /// Not @Observable; only `streamingText` triggers SwiftUI updates.
    private var pendingStreamTokens = ""
    private var streamFlushTask: Task<Void, Never>?

    /// Pending reasoning buffer.
    private var pendingReasoningTokens = ""
    private var reasoningFlushTask: Task<Void, Never>?

    func startStreaming() { isStreaming = true }

    func stopStreaming() {
        flushStreamingTokens()
        flushReasoningTokens()
        isStreaming = false
        researchStartTime = nil
        onStopRequested?()
    }

    /// Accumulates tokens and flushes to `streamingText` at ~60ms intervals.
    /// This batches 3-5 tokens per SwiftUI update instead of 1:1.
    /// On first token, transitions out of reasoning phase (calculates duration).
    func appendStreamingText(_ text: String) {
        if isReasoning { endReasoning() }
        pendingStreamTokens += text
        guard streamFlushTask == nil else { return }
        streamFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self, !Task.isCancelled else { return }
            self.flushStreamingTokens()
        }
    }

    private func flushStreamingTokens() {
        streamFlushTask?.cancel()
        streamFlushTask = nil
        guard !pendingStreamTokens.isEmpty else { return }
        streamingText += pendingStreamTokens
        pendingStreamTokens = ""
        // Subtle trackpad haptic on each token flush — gives tactile typewriter feel
        HapticHelper.streamingTick()
    }

    // MARK: - Reasoning

    func startReasoning() {
        isReasoning = true
        reasoningStartTime = .now
    }

    /// Ends the reasoning phase, calculating duration from start time.
    private func endReasoning() {
        guard isReasoning else { return }
        if let start = reasoningStartTime {
            let elapsed = ContinuousClock.now - start
            reasoningDuration = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
        }
        isReasoning = false
        reasoningStartTime = nil
    }

    func appendReasoningText(_ text: String) {
        pendingReasoningTokens += text
        guard reasoningFlushTask == nil else { return }
        reasoningFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self, !Task.isCancelled else { return }
            self.flushReasoningTokens()
        }
    }

    private func flushReasoningTokens() {
        reasoningFlushTask?.cancel()
        reasoningFlushTask = nil
        guard !pendingReasoningTokens.isEmpty else { return }
        reasoningText += pendingReasoningTokens
        pendingReasoningTokens = ""
    }

    // MARK: - Attachments

    func addAttachment(_ file: FileAttachment) {
        // Prevent duplicate attachments — match by file URI
        guard !pendingAttachments.contains(where: { $0.uri == file.uri }) else { return }
        pendingAttachments.append(file)
    }
    func removeAttachment(_ id: String) { pendingAttachments.removeAll { $0.id == id } }

    // MARK: - Background Enrichment

    func enrichLastMessage(dualMessage: DualMessage, truthAssessment: TruthAssessment) {
        guard let idx = messages.indices.last(where: { messages[$0].role == .assistant }) else {
            log.warning("[enrich] No assistant message found to enrich")
            return
        }
        let msgId = messages[idx].id
        let hasLayman = dualMessage.laymanSummary != nil
        let rawLen = dualMessage.rawAnalysis.count
        let hasReflection = dualMessage.reflection != nil
        let hasArbitration = dualMessage.arbitration != nil
        log.warning("🔬 [enrich] Enriching message \(msgId) — layman=\(hasLayman) rawLen=\(rawLen) reflection=\(hasReflection) arbitration=\(hasArbitration)")

        // Explicit full-element reassignment — guarantees @Observable property
        // setter fires, avoiding a subtle issue where in-place subscript mutation
        // via _modify may not trigger SwiftUI observation notifications.
        var updated = messages[idx]
        updated.dualMessage = dualMessage
        updated.truthAssessment = truthAssessment
        // Capture elapsed duration before clearing the start time
        if let start = researchStartTime {
            updated.researchDuration = Date().timeIntervalSince(start)
        }
        messages[idx] = updated

        // Enrichment complete — stop the research thinking timer
        researchStartTime = nil
        log.warning("🔬 [enrich] DONE — isResearchResult=\(updated.isResearchResult) layman=\(updated.dualMessage?.laymanSummary != nil) duration=\(updated.researchDuration.map { String(format: "%.1fs", $0) } ?? "nil")")
    }

    // MARK: - Load / Clear

    func loadMessages(_ msgs: [ChatMessage]) {
        messages = msgs
        hasMessages = !msgs.isEmpty
        showLanding = msgs.isEmpty
    }

    func clearMessages() {
        let chatId = activeChatId
        // Cancel pending flushes — we're clearing everything
        streamFlushTask?.cancel()
        streamFlushTask = nil
        reasoningFlushTask?.cancel()
        reasoningFlushTask = nil
        pendingStreamTokens = ""
        pendingReasoningTokens = ""

        messages = []
        hasMessages = false
        streamingText = ""
        isStreaming = false
        reasoningText = ""
        isReasoning = false
        isIncognito = false
        researchStartTime = nil
        showLanding = true
        // Note: isResearchMode is NOT reset here — it's a persisted user preference.
        isNotesMode = false
        vaultManifest = nil
        loadedNoteIds = []
        loadedNoteTitles = []
        activeChatId = nil
        chatTitle = nil

        if let chatId {
            eventBus?.emit(.chatCleared(chatId: ChatId(chatId)))
        }
    }
}
