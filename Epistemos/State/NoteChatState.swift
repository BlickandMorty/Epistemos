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
    /// Per-note chat history.
    var messages: [AssistantMessage] = []

    // MARK: - Callbacks (wired by Coordinator)

    /// Insert the AI response divider into storage when streaming starts.
    var onStreamStart: ((_ query: String) -> Void)?
    /// Append streaming tokens to end of storage.
    var onTokenFlush: ((_ delta: String) -> Void)?
    /// Strip the divider, keep response text inline.
    var onAccept: (() -> Void)?
    /// Delete everything from the divider onward.
    var onDiscard: (() -> Void)?
    /// Read the current note body from storage.
    var noteBodyProvider: (() -> String)?
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
        if !self.useResponsePanel {
            self.onTokenFlush?(delta)
        }
        self.emitStreamingHapticIfNeeded()
    }
    @ObservationIgnored private var lastStreamingHapticAt: Date?
    @ObservationIgnored private var streamingTask: Task<Void, Never>?
    @ObservationIgnored private var streamingTaskToken = UUID()

    init(pageId: String) {
        self.pageId = pageId
    }

    func appendStreamingText(_ text: String) {
        streamBuffer.append(text)
    }

    private func flushTokens() {
        streamBuffer.flushNow()
    }

    private func resetStreamBuffer() {
        streamBuffer.reset()
        lastStreamingHapticAt = nil
    }

    private func emitStreamingHapticIfNeeded(now: Date = .now) {
        if let lastStreamingHapticAt, now.timeIntervalSince(lastStreamingHapticAt) < 0.12 {
            return
        }
        lastStreamingHapticAt = now
        HapticHelper.streamingTick()
    }

    // MARK: - Submit

    func submitQuery(_ query: String, triageService: TriageService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        replacePendingResponseIfNeeded()

        messages.append(AssistantMessage(role: .user, content: trimmed))
        inputText = ""
        resetStreamBuffer()
        responseText = ""
        error = nil
        isStreaming = true
        hasResponse = true
        useResponsePanel = true
        responseText.reserveCapacity(16_384)

        AppBootstrap.shared?.activityTracker.recordChatMessage(chatId: pageId, snippet: trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))

        indexCurrentNoteForInstantRecall(noteBody)
        let recallContext = instantRecallContext(for: trimmed)

        // Build prompt with conversation history for follow-ups
        let history = conversationHistoryPrompt()
        let fullPrompt = buildPrompt(
            noteSnippet: noteSnippet,
            recallContext: recallContext,
            history: history,
            query: trimmed
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
        streamingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.streamingTaskToken == taskToken {
                    self.streamingTask = nil
                }
            }
            do {
                for try await chunk in stream {
                    self.appendStreamingText(chunk)
                }
                self.flushTokens()
                guard !Task.isCancelled else {
                    self.isStreaming = false
                    return
                }
                self.isStreaming = false
                let final = UserFacingModelOutput.finalVisibleText(from: self.responseText)
                self.responseText = final
                if !final.isEmpty {
                    self.messages.append(AssistantMessage(role: .assistant, content: final))
                }
            } catch is CancellationError {
                self.flushTokens()
                self.isStreaming = false
            } catch {
                self.flushTokens()
                self.isStreaming = false
                self.error = error.localizedDescription
                self.log.error("Note chat error: \(error.localizedDescription)")
            }
        }
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

        messages.append(AssistantMessage(role: .user, content: trimmed))
        inputText = ""
        resetStreamBuffer()
        responseText = ""
        error = nil
        isStreaming = true
        hasResponse = true
        useResponsePanel = false
        responseText.reserveCapacity(16_384)

        onStreamStart?(trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))
        let fullPrompt: String
        if noteSnippet.isEmpty {
            fullPrompt = "Request: \(trimmed)"
        } else {
            fullPrompt = """
            Note content:
            \(noteSnippet)

            Request: \(trimmed)
            """
        }

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
        streamingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.streamingTaskToken == taskToken {
                    self.streamingTask = nil
                }
            }
            do {
                for try await chunk in stream {
                    self.appendStreamingText(chunk)
                }
                self.flushTokens()
                guard !Task.isCancelled else {
                    self.isStreaming = false
                    return
                }
                self.isStreaming = false
                let final = UserFacingModelOutput.finalVisibleText(from: self.responseText)
                self.responseText = final
                if !final.isEmpty {
                    self.messages.append(AssistantMessage(role: .assistant, content: final))
                }
                self.log.info("Note chat complete for page \(self.pageId)")
            } catch is CancellationError {
                self.flushTokens()
                self.isStreaming = false
            } catch {
                self.flushTokens()
                self.isStreaming = false
                self.error = error.localizedDescription
                self.log.error("Note chat error: \(error.localizedDescription)")
            }
        }
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
        query: String
    ) -> String {
        var sections: [String] = []
        sections.reserveCapacity(4)

        if !noteSnippet.isEmpty {
            sections.append("Note content:\n\(noteSnippet)")
        }
        if !recallContext.isEmpty {
            sections.append("Related notes from instant recall:\n\(recallContext)")
        }
        if !history.isEmpty {
            sections.append(history)
        }

        if sections.isEmpty {
            return query
        }

        sections.append("User: \(query)")
        return sections.joined(separator: "\n\n")
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
        flushTokens()
        isStreaming = false
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
        resetStreamBuffer()
        hasResponse = false
        useResponsePanel = false
        responseText = ""
    }

    func discardResponse() {
        if !useResponsePanel {
            onDiscard?()
        }
        resetStreamBuffer()
        hasResponse = false
        useResponsePanel = false
        responseText = ""
    }

    func clear() {
        stopStreaming()
        if hasResponse {
            discardResponse()
        } else {
            resetStreamBuffer()
            responseText = ""
            useResponsePanel = false
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
        guard let sdChat = (try? context.fetch(descriptor))?.first else { return }
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
        if let existingId = persistedChatId,
           let existing = try? context.fetch(
               FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == existingId })
           ).first {
            sdChat = existing
            sdChat.title = noteTitle.isEmpty ? "Untitled" : noteTitle
            sdChat.updatedAt = .now
            // Remove old messages and replace
            for msg in sdChat.messages ?? [] {
                context.delete(msg)
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
