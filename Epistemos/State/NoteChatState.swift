import Foundation
import Observation
import SwiftData
import os

// MARK: - Note Chat State (v2 — Simplified)
// Per-note AI chat state. One instance per open note tab.
// Manages a single query → response cycle with 60ms token buffering.
//
// Architecture:
// - AI text is appended directly to NSTextStorage below a --- divider.
// - No zone protection, no divider offset tracking, no multi-turn headers.
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

    // MARK: - Token Buffering (60ms)

    private var pendingTokens = ""
    private var flushTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?

    init(pageId: String) {
        self.pageId = pageId
    }

    func appendStreamingText(_ text: String) {
        pendingTokens += text
        if pendingTokens.utf8.count > 65_536 {
            flushTokens()
            return
        }
        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard let self, !Task.isCancelled else { return }
            self.flushTokens()
        }
    }

    private func flushTokens() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingTokens.isEmpty else { return }
        let delta = pendingTokens
        pendingTokens = ""
        responseText += delta
        if !useResponsePanel { onTokenFlush?(delta) }
        HapticHelper.streamingTick()
    }

    // MARK: - Submit

    func submitQuery(_ query: String, triageService: TriageService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(AssistantMessage(role: .user, content: trimmed))
        inputText = ""
        responseText = ""
        error = nil
        isStreaming = true
        hasResponse = true
        useResponsePanel = true
        responseText.reserveCapacity(16_384)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))
        // Build prompt with conversation history for follow-ups
        let history = conversationHistoryPrompt()
        let fullPrompt: String
        if history.isEmpty {
            fullPrompt = noteSnippet.isEmpty
                ? trimmed
                : "Note content:\n\(noteSnippet)\n\nQuestion: \(trimmed)"
        } else {
            fullPrompt = noteSnippet.isEmpty
                ? "\(history)\n\nUser: \(trimmed)"
                : "Note content:\n\(noteSnippet)\n\n\(history)\n\nUser: \(trimmed)"
        }

        let stream = triageService.stream(
            prompt: fullPrompt,
            systemPrompt: nil,
            operation: .ask(query: trimmed),
            contentLength: noteBody.count,
            query: trimmed
        )
        log.info("Note chat: shared routing (\(triageService.lastDecision?.label ?? "pending"))")

        streamingTask = Task { [weak self] in
            guard let self else { return }
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
        systemPrompt: String,
        triageService: TriageService
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(AssistantMessage(role: .user, content: trimmed))
        inputText = ""
        responseText = ""
        error = nil
        isStreaming = true
        hasResponse = true
        useResponsePanel = false
        responseText.reserveCapacity(16_384)

        onStreamStart?(trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let noteSnippet = String(noteBody.prefix(4000))
        _ = systemPrompt
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

        let stream = triageService.stream(
            prompt: fullPrompt,
            systemPrompt: nil,
            operation: operation,
            contentLength: noteBody.count,
            query: trimmed
        )

        streamingTask = Task { [weak self] in
            guard let self else { return }
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

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        flushTokens()
        isStreaming = false
    }

    func acceptResponse() {
        if useResponsePanel {
            onInsertAtCursor?(responseText)
        } else {
            onAccept?()
        }
        hasResponse = false
        useResponsePanel = false
        responseText = ""
    }

    func discardResponse() {
        if !useResponsePanel {
            onDiscard?()
        }
        hasResponse = false
        useResponsePanel = false
        responseText = ""
    }

    func clear() {
        stopStreaming()
        inputText = ""
        responseText = ""
        error = nil
        hasResponse = false
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
