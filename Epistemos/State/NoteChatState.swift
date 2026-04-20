import Foundation
import Observation
import SwiftData
import os

enum NoteChatInlineResponse {
    nonisolated static let divider = "\n\n<!-- ai-response -->\n\n"

    nonisolated static func dividerRange(in text: String) -> Range<String.Index>? {
        text.range(of: divider, options: .backwards)
    }

    nonisolated static func editTouchesDivider(in text: String, affectedRange: NSRange) -> Bool {
        guard let range = dividerRange(in: text) else { return false }
        let dividerRange = NSRange(range, in: text)

        if affectedRange.length == 0 {
            let insertionPoint = affectedRange.location
            return insertionPoint > dividerRange.location
                && insertionPoint < dividerRange.location + dividerRange.length
        }

        return NSIntersectionRange(affectedRange, dividerRange).length > 0
    }
}

enum NoteChatToolbarStatusPhase: Equatable {
    case idle
    case analyzing
    case typing
}

// MARK: - Note Chat State (v2 — Simplified)
// Per-note AI chat state. One instance per open note tab.
// Manages a single query → response cycle with display-paced token buffering.
//
// Architecture:
// - AI text is appended directly to NSTextStorage below a hidden divider.
// - The streamed response body stays editable; only the divider region is protected.
// - Accept strips the divider, keeping response text as part of the note.
// - Discard deletes everything from the divider onward.

@MainActor @Observable
final class NoteChatState {
    private enum StreamingPresentation {
        case responsePanel
        case inlinePending
        case inlineAutoCommit
    }

    private let log = Logger(subsystem: "com.epistemos", category: "NoteChat")

    let pageId: String

    // MARK: - UI State

    var inputText = ""
    var isStreaming = false
    var responseText = ""
    var error: String?
    /// True when AI response text exists (between submit and accept/discard).
    var hasResponse = false
    /// True when response displays in the slide-up panel (free-text queries).
    /// False when response is inline in storage (context menu operations).
    var useResponsePanel = false
    var toolbarStatusPhase: NoteChatToolbarStatusPhase = .idle
    /// Per-note chat history.
    var messages: [AssistantMessage] = []

    // MARK: - Callbacks (wired by Coordinator)

    /// Insert the AI response divider into storage when streaming starts.
    var onStreamStart: ((_ query: String) -> Void)?
    /// Append streaming tokens to end of storage.
    var onTokenFlush: ((_ delta: String) -> Void)?
    /// Signals that inline streaming has fully flushed and its undo group can close.
    var onStreamFinish: (() -> Void)?
    /// Strip the divider, keep response text inline.
    var onAccept: (() -> Void)?
    /// Delete everything from the divider onward.
    var onDiscard: (() -> Void)?
    /// Replace the inline response body with a sanitized final version before accept/discard.
    var onReplaceInlineResponse: ((_ text: String) -> Void)?
    /// Read the current note body from storage.
    var noteBodyProvider: (() -> String)?
    /// Write a full replacement body to the active editor.
    /// Uses shouldChangeText → replaceCharacters → didChangeText for undo support.
    var noteBodyWriter: ((String) -> Void)?
    /// Replace a 1-indexed line range in the active editor.
    /// Uses shouldChangeText → replaceCharacters → didChangeText for undo support.
    var noteRangeWriter: ((ClosedRange<Int>, String) -> Void)?
    /// Provides the current GraphState for graph context injection.
    /// Set by the workspace view when the chat is created.
    var graphStateProvider: (() -> GraphState?)?
    /// Insert text at the current cursor position (panel mode accept).
    var onInsertAtCursor: ((_ text: String) -> Void)?
    /// Test hook for overriding instant recall indexing.
    @ObservationIgnored var instantRecallIndexer: ((_ noteId: String, _ text: String) -> Void)?
    /// Test hook for overriding instant recall retrieval.
    @ObservationIgnored var instantRecallSearcher: ((_ query: String, _ topK: Int) -> [InstantRecallResult])?

    // MARK: - Token Buffering

    @ObservationIgnored
    private lazy var streamBuffer = DisplayPacedTextBuffer { [weak self] delta in
        guard let self else { return }
        self.responseText += delta
        switch self.streamingPresentation {
        case .responsePanel:
            if !self.useResponsePanel {
                self.onTokenFlush?(delta)
            }
        case .inlinePending:
            self.onTokenFlush?(delta)
        case .inlineAutoCommit:
            let visibleDelta = self.visibleToolbarInlineDelta(for: self.responseText)
            if !visibleDelta.isEmpty {
                self.toolbarStatusPhase = .typing
                self.onTokenFlush?(visibleDelta)
            }
        }
        self.emitStreamingHapticIfNeeded()
    }
    @ObservationIgnored private var lastStreamingHapticAt: Date?
    @ObservationIgnored private var streamingTask: Task<Void, Never>?
    @ObservationIgnored private var streamingTaskToken = UUID()
    @ObservationIgnored private var streamingPresentation: StreamingPresentation = .responsePanel
    @ObservationIgnored private var streamedInlineVisibleText = ""
    @ObservationIgnored private var thinkTagRouter = ThinkTagStreamRouter()

    init(pageId: String) {
        self.pageId = pageId
    }

    func appendStreamingText(_ text: String) {
        let emit = thinkTagRouter.ingest(text)
        guard !emit.visible.isEmpty else { return }
        streamBuffer.append(emit.visible)
    }

    private func flushTokens() {
        streamBuffer.flushNow()
    }

    private func flushThinkTagRouter() {
        let emit = thinkTagRouter.flush()
        guard !emit.visible.isEmpty else { return }
        streamBuffer.append(emit.visible, scheduleFlush: false)
    }

    private func resetStreamBuffer(releaseCapacity: Bool = false) {
        streamBuffer.reset(releaseCapacity: releaseCapacity)
        lastStreamingHapticAt = nil
    }

    private func clearResponseTextBuffer() {
        responseText.removeAll(keepingCapacity: false)
    }

    private func emitStreamingHapticIfNeeded(now: Date = .now) {
        if let lastStreamingHapticAt, now.timeIntervalSince(lastStreamingHapticAt) < 0.12 {
            return
        }
        lastStreamingHapticAt = now
        HapticHelper.streamingTick()
    }

    private func visibleToolbarInlineDelta(for rawResponse: String) -> String {
        let visibleText = UserFacingModelOutput.streamingVisibleText(from: rawResponse)
        guard !visibleText.isEmpty else { return "" }
        guard visibleText.hasPrefix(streamedInlineVisibleText) else { return "" }
        let start = visibleText.index(visibleText.startIndex, offsetBy: streamedInlineVisibleText.count)
        streamedInlineVisibleText = visibleText
        return String(visibleText[start...])
    }

    private func beginSubmission(
        trimmed: String,
        presentation: StreamingPresentation,
        startInlineStream: Bool
    ) {
        messages.append(AssistantMessage(role: .user, content: trimmed))
        inputText = ""
        resetStreamBuffer(releaseCapacity: true)
        clearResponseTextBuffer()
        error = nil
        isStreaming = true
        hasResponse = true
        useResponsePanel = presentation == .responsePanel
        toolbarStatusPhase = presentation == .inlineAutoCommit ? .analyzing : .idle
        responseText.reserveCapacity(16_384)
        streamingPresentation = presentation
        streamedInlineVisibleText = ""
        thinkTagRouter = ThinkTagStreamRouter()

        if startInlineStream {
            onStreamStart?(trimmed)
        }
    }

    private func finishStreamingTaskIfNeeded(taskToken: UUID, usesInlineResponse: Bool) {
        if usesInlineResponse {
            onStreamFinish?()
        }
        if streamingTaskToken == taskToken {
            streamingTask = nil
        }
    }

    private func finalizeResponseText() -> String {
        isStreaming = false
        let final = UserFacingModelOutput.finalVisibleText(from: responseText)
        responseText = final
        if !useResponsePanel {
            onReplaceInlineResponse?(final)
        }
        return final
    }

    private func resolveInlineAutoCommitResponse() {
        guard streamingPresentation == .inlineAutoCommit, hasResponse else {
            toolbarStatusPhase = .idle
            return
        }

        let final = finalizeResponseText()
        if !final.isEmpty {
            acceptResponse()
            messages.append(AssistantMessage(role: .assistant, content: final))
        } else {
            discardResponse()
        }
    }

    private func startStreamingTask(
        stream: AsyncThrowingStream<String, Error>,
        taskToken: UUID,
        usesInlineResponse: Bool
    ) {
        let autoCommitInlineResponse = streamingPresentation == .inlineAutoCommit
        streamingTask = Task { [weak self] in
            guard let self else { return }
            defer { self.finishStreamingTaskIfNeeded(taskToken: taskToken, usesInlineResponse: usesInlineResponse) }
            do {
                for try await chunk in stream {
                    self.appendStreamingText(chunk)
                }
                self.flushThinkTagRouter()
                self.flushTokens()
                guard !Task.isCancelled else {
                    self.isStreaming = false
                    self.resolveInlineAutoCommitResponse()
                    return
                }

                if autoCommitInlineResponse {
                    self.resolveInlineAutoCommitResponse()
                } else {
                    let final = self.finalizeResponseText()
                    if !final.isEmpty {
                        self.messages.append(AssistantMessage(role: .assistant, content: final))
                    }
                }
            } catch is CancellationError {
                self.flushThinkTagRouter()
                self.flushTokens()
                self.isStreaming = false
                self.resolveInlineAutoCommitResponse()
            } catch {
                self.flushThinkTagRouter()
                self.flushTokens()
                self.isStreaming = false
                self.error = error.localizedDescription
                self.log.error("Note chat error: \(error.localizedDescription)")
                self.resolveInlineAutoCommitResponse()
            }
        }
    }

    private func resetStreamingPresentationState() {
        streamingPresentation = .responsePanel
        streamedInlineVisibleText = ""
        toolbarStatusPhase = .idle
    }

    // MARK: - Submit

    func submitQuery(_ query: String, triageService: TriageService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        replacePendingResponseIfNeeded()
        beginSubmission(trimmed: trimmed, presentation: .responsePanel, startInlineStream: false)

        AppBootstrap.shared?.activityTracker.recordChatMessage(chatId: pageId, snippet: trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))

        indexCurrentNoteForInstantRecall(noteBody)
        let recallContext = instantRecallContext(for: trimmed)

        // Build prompt with conversation history for follow-ups
        let history = conversationHistoryPrompt()
        let requestLine = "Request: \(trimmed)"
        let fullPrompt = buildPrompt(
            noteSnippet: noteSnippet,
            recallContext: recallContext,
            history: history,
            requestLine: requestLine
        )

        let stream: AsyncThrowingStream<String, Error>
        if let reasoning = AppBootstrap.shared?.reasoningLoopService, reasoning.config.enabled {
            stream = reasoning.streamWithReasoning(
                prompt: fullPrompt, systemPrompt: nil,
                operation: .ask(query: trimmed),
                contentLength: noteBody.count, query: trimmed
            )
            log.info("Note chat: reasoning loop enabled")
        } else {
            stream = triageService.stream(
                prompt: fullPrompt, systemPrompt: nil,
                operation: .ask(query: trimmed),
                contentLength: noteBody.count, query: trimmed
            )
            log.info("Note chat: shared routing (\(triageService.lastDecision?.label ?? "pending"))")
        }

        let taskToken = UUID()
        streamingTaskToken = taskToken
        let usesInlineResponse = !useResponsePanel
        startStreamingTask(stream: stream, taskToken: taskToken, usesInlineResponse: usesInlineResponse)
    }

    func submitToolbarQuery(_ query: String, triageService: TriageService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        replacePendingResponseIfNeeded()
        beginSubmission(trimmed: trimmed, presentation: .inlineAutoCommit, startInlineStream: true)

        AppBootstrap.shared?.activityTracker.recordChatMessage(chatId: pageId, snippet: trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))

        indexCurrentNoteForInstantRecall(noteBody)
        let recallContext = instantRecallContext(for: trimmed)

        let history = conversationHistoryPrompt()
        let requestLine = "Request: \(trimmed)"
        let fullPrompt = buildPrompt(
            noteSnippet: noteSnippet,
            recallContext: recallContext,
            history: history,
            requestLine: requestLine
        )

        let stream: AsyncThrowingStream<String, Error>
        if let reasoning = AppBootstrap.shared?.reasoningLoopService, reasoning.config.enabled {
            stream = reasoning.streamWithReasoning(
                prompt: fullPrompt, systemPrompt: nil,
                operation: .ask(query: trimmed),
                contentLength: noteBody.count, query: trimmed
            )
            log.info("Note chat toolbar: reasoning loop enabled")
        } else {
            stream = triageService.stream(
                prompt: fullPrompt, systemPrompt: nil,
                operation: .ask(query: trimmed),
                contentLength: noteBody.count, query: trimmed
            )
            log.info("Note chat toolbar: shared routing (\(triageService.lastDecision?.label ?? "pending"))")
        }

        let taskToken = UUID()
        streamingTaskToken = taskToken
        startStreamingTask(stream: stream, taskToken: taskToken, usesInlineResponse: true)
    }

    /// Submit with a specific operation for proper triage routing.
    /// Each operation routes through the correct complexity tier:
    /// .rewrite (0.25) → Apple Intelligence, .expand (0.50) → local Qwen, etc.
    func submitQuery(
        _ query: String,
        operation: NotesOperation,
        triageService: TriageService
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        replacePendingResponseIfNeeded()
        beginSubmission(trimmed: trimmed, presentation: .inlinePending, startInlineStream: true)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))
        let requestLine = "Request: \(trimmed)"
        let fullPrompt = buildPrompt(
            noteSnippet: noteSnippet,
            recallContext: "",
            history: "",
            requestLine: requestLine
        )

        let stream: AsyncThrowingStream<String, Error>
        if let reasoning = AppBootstrap.shared?.reasoningLoopService, reasoning.config.enabled {
            stream = reasoning.streamWithReasoning(
                prompt: fullPrompt, systemPrompt: nil,
                operation: operation,
                contentLength: noteBody.count, query: trimmed
            )
        } else {
            stream = triageService.stream(
                prompt: fullPrompt, systemPrompt: nil,
                operation: operation,
                contentLength: noteBody.count, query: trimmed
            )
        }

        let taskToken = UUID()
        streamingTaskToken = taskToken
        let usesInlineResponse = !useResponsePanel
        startStreamingTask(stream: stream, taskToken: taskToken, usesInlineResponse: usesInlineResponse)
    }

    /// Build a conversation history string from prior messages (excluding the just-appended user message).
    private func conversationHistoryPrompt() -> String {
        // messages already has the new user message at the end — exclude it
        let prior = messages.dropLast()
        guard !prior.isEmpty else { return "" }
        return prior.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n\n")
    }

    private func indexCurrentNoteForInstantRecall(_ noteBody: String) {
        if let instantRecallIndexer {
            instantRecallIndexer(pageId, noteBody)
            return
        }
        guard let recall = AppBootstrap.shared?.instantRecallService, recall.isReady else { return }
        recall.indexNote(noteId: pageId, text: noteBody)
    }

    private func instantRecallResults(for query: String, topK: Int = 4) -> [InstantRecallResult] {
        guard !query.isEmpty else { return [] }
        if let instantRecallSearcher {
            return instantRecallSearcher(query, topK)
        }
        guard let recall = AppBootstrap.shared?.instantRecallService, recall.isReady else { return [] }
        return recall.search(queryText: query, topK: topK)
    }

    private func instantRecallContext(for query: String) -> String {
        let currentNoteSnippet = recallSnippet(from: noteBodyProvider?() ?? "")
        let matches = curatedInstantRecallMatches(for: query, currentNoteSnippet: currentNoteSnippet)

        return matches.map { result in
            let snippet = recallSnippet(from: result.text)
            return "- [\(result.docId)] \(snippet)"
        }.joined(separator: "\n")
    }

    private func curatedInstantRecallMatches(
        for query: String,
        currentNoteSnippet: String,
        maxItems: Int = 3
    ) -> [InstantRecallResult] {
        let currentSnippetKey = recallDeduplicationKey(for: currentNoteSnippet)
        var seenSnippetKeys = Set<String>()
        seenSnippetKeys.reserveCapacity(maxItems + 1)
        if !currentSnippetKey.isEmpty {
            seenSnippetKeys.insert(currentSnippetKey)
        }

        var curated: [InstantRecallResult] = []
        curated.reserveCapacity(maxItems)

        for result in instantRecallResults(for: query, topK: maxItems * 3) {
            guard result.docId != pageId, result.score.isFinite, result.score > 0 else { continue }

            let snippet = recallSnippet(from: result.text)
            let snippetKey = recallDeduplicationKey(for: snippet)
            guard !snippetKey.isEmpty else { continue }
            guard seenSnippetKeys.insert(snippetKey).inserted else { continue }

            curated.append(result)
            if curated.count == maxItems {
                break
            }
        }

        return curated
    }

    private func buildPrompt(
        noteSnippet: String,
        recallContext: String,
        history: String,
        requestLine: String
    ) -> String {
        var sections: [String] = []
        sections.reserveCapacity(5)

        sections.append("""
        <assistant_contract>
        You are a helpful assistant embedded in a note editor.
        The note content provided in the prompt is the exact live document the user is editing right now.
        Do not ask the user to paste the note again unless the prompt explicitly says content is missing.
        Answer the user's request directly and concisely.
        Do not summarize the note unless explicitly asked.
        Focus on the user's specific request.
        </assistant_contract>
        """)

        if !noteSnippet.isEmpty {
            sections.append("""
            <current_note_contract>
            The note content below is the current live document. Treat it as the primary source of truth for this request.
            Do not ask the user to paste the note again unless some required content is missing from the prompt.
            </current_note_contract>
            """)
            sections.append("<note>\n\(noteSnippet)\n</note>")
        }

        // Graph context: inject the current note's neighborhood from the
        // knowledge graph so the model understands the note's position in
        // the user's knowledge structure. This is the "beyond native"
        // differentiator — the model sees connections, not just content.
        let graphContext = buildGraphContext()
        if !graphContext.isEmpty {
            sections.append("knowledge_graph:\n\(graphContext)")
        }

        if !recallContext.isEmpty {
            sections.append("<related_notes>\n\(recallContext)\n</related_notes>")
        }
        if !history.isEmpty {
            sections.append("<conversation_history>\n\(history)\n</conversation_history>")
        }

        sections.append(requestLine)
        return sections.joined(separator: "\n\n")
    }

    /// Build a compact graph neighborhood description for the current note.
    /// Includes: node type, label, and edge types for immediate neighbors.
    /// Capped at ~20 neighbors to stay within token budget.
    private func buildGraphContext() -> String {
        guard let graphState = graphStateProvider?() else { return "" }
        let store = graphState.store

        // Find the node for this note
        guard let node = store.node(bySourceId: pageId, type: .note) else { return "" }
        guard let neighbors = store.adjacency[node.id], !neighbors.isEmpty else { return "" }

        // YAML format — 54% higher reasoning accuracy, ~10% fewer tokens than XML
        var lines: [String] = []
        lines.append("  current_note: \"\(node.label)\"")
        lines.append("  total_connections: \(neighbors.count)")
        lines.append("  neighbors:")

        let neighborNodes = neighbors.compactMap { store.nodes[$0] }
            .sorted { $0.weight > $1.weight }
            .prefix(20)

        for neighbor in neighborNodes {
            lines.append("    - type: \(neighbor.type.displayName)")
            lines.append("      title: \"\(neighbor.label)\"")
        }

        if neighbors.count > 20 {
            lines.append("  # + \(neighbors.count - 20) more connections")
        }

        return lines.joined(separator: "\n")
    }

    private func recallSnippet(from text: String, limit: Int = 220) -> String {
        let condensed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard condensed.count > limit else { return condensed }
        let cutoff = condensed.index(condensed.startIndex, offsetBy: limit)
        return "\(condensed[..<cutoff])..."
    }

    private func recallDeduplicationKey(for text: String) -> String {
        recallSnippet(from: text, limit: 160).lowercased()
    }

    func stopStreaming() {
        streamingTaskToken = UUID()
        streamingTask?.cancel()
        streamingTask = nil
        flushThinkTagRouter()
        flushTokens()
        isStreaming = false
        resolveInlineAutoCommitResponse()
    }

    private func replacePendingResponseIfNeeded() {
        guard hasResponse else { return }
        if isStreaming {
            stopStreaming()
        }
        discardResponse()
    }

    func acceptResponse() {
        if useResponsePanel {
            onInsertAtCursor?(responseText)
        } else {
            onAccept?()
        }
        resetStreamBuffer(releaseCapacity: true)
        hasResponse = false
        useResponsePanel = false
        clearResponseTextBuffer()
        thinkTagRouter = ThinkTagStreamRouter()
        resetStreamingPresentationState()
    }

    func discardResponse() {
        if !useResponsePanel {
            onDiscard?()
        }
        resetStreamBuffer(releaseCapacity: true)
        hasResponse = false
        useResponsePanel = false
        clearResponseTextBuffer()
        thinkTagRouter = ThinkTagStreamRouter()
        resetStreamingPresentationState()
    }

    func clear() {
        stopStreaming()
        if hasResponse {
            discardResponse()
        } else {
            resetStreamBuffer(releaseCapacity: true)
            clearResponseTextBuffer()
            useResponsePanel = false
            thinkTagRouter = ThinkTagStreamRouter()
            resetStreamingPresentationState()
        }
        inputText = ""
        error = nil
    }

    // MARK: - Persistence

    /// ID of the persisted SDChat for this note (set after first save or load).
    private var persistedChatId: String?

    /// Load persisted messages from SwiftData on appear.
    func loadPersistedMessages(_ context: ModelContext) {
        let pid = pageId
        var descriptor = FetchDescriptor<SDChat>(
            predicate: #Predicate { $0.linkedPageId == pid && $0.chatType == "notes" },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let sdChat: SDChat
        do {
            guard let fetchedChat = try context.fetch(descriptor).first else { return }
            sdChat = fetchedChat
        } catch {
            log.error(
                "Failed to load persisted note chat for page \(self.pageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        persistedChatId = sdChat.id
        let sorted = sdChat.sortedMessages
        messages = sorted.map {
            AssistantMessage(
                id: $0.id,
                role: $0.role == "user" ? .user : .assistant,
                content: $0.content,
                createdAt: $0.createdAt
            )
        }
    }

    /// Persist current messages to SwiftData after streaming completes.
    func persistMessages(_ context: ModelContext, noteTitle: String) {
        guard !messages.isEmpty else { return }

        let sdChat: SDChat
        if let existingId = persistedChatId {
            do {
                if let existing = try context.fetch(
                    FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == existingId })
                ).first {
                    sdChat = existing
                    sdChat.title = noteTitle.isEmpty ? "Untitled" : noteTitle
                    sdChat.updatedAt = .now
                    for msg in sdChat.messages ?? [] {
                        context.delete(msg)
                    }
                } else {
                    sdChat = SDChat(
                        title: noteTitle.isEmpty ? "Untitled" : noteTitle,
                        chatType: "notes"
                    )
                    sdChat.linkedPageId = pageId
                    context.insert(sdChat)
                    persistedChatId = sdChat.id
                }
            } catch {
                log.error(
                    "Failed to fetch existing persisted note chat \(existingId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return
            }
        } else {
            sdChat = SDChat(title: noteTitle.isEmpty ? "Untitled" : noteTitle, chatType: "notes")
            sdChat.linkedPageId = pageId
            context.insert(sdChat)
            persistedChatId = sdChat.id
        }

        for msg in messages {
            let sdMsg = SDMessage(role: msg.role == .user ? "user" : "assistant", content: msg.content)
            sdMsg.id = msg.id
            sdMsg.createdAt = msg.createdAt
            sdMsg.chat = sdChat
            context.insert(sdMsg)
        }

        do { try context.save() }
        catch { log.error("Failed to persist note chat: \(error.localizedDescription)") }
    }
}
