import Foundation
import Observation
import os

// MARK: - Note Chat Mode
// Controls how note chat routes queries:
// - auto: TriageService decides (Apple AI for simple, cloud for complex)
// - cloudOnly: bypass triage, use the user's selected cloud API
// - provider: use a specific LLMProviderType regardless of settings

enum NoteChatMode: String, Codable, CaseIterable, Sendable {
    case auto
    case cloudOnly
    case provider

    var label: String {
        switch self {
        case .auto: "Auto"
        case .cloudOnly: "Cloud"
        case .provider: "Manual"
        }
    }

    var icon: String {
        switch self {
        case .auto: "sparkles"
        case .cloudOnly: "cloud"
        case .provider: "server.rack"
        }
    }
}

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
    /// True when AI response text exists in storage (between submit and accept/discard).
    var hasResponse = false

    // MARK: - Chat Mode (persisted to UserDefaults)

    var chatMode: NoteChatMode {
        didSet { UserDefaults.standard.set(chatMode.rawValue, forKey: "noteChatMode") }
    }
    var overrideProvider: LLMProviderType? {
        didSet { UserDefaults.standard.set(overrideProvider?.rawValue, forKey: "noteChatProvider") }
    }

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

    // MARK: - Token Buffering (60ms)

    private var pendingTokens = ""
    private var flushTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?

    init(pageId: String) {
        self.pageId = pageId
        let restoredMode = NoteChatMode(rawValue: UserDefaults.standard.string(forKey: "noteChatMode") ?? "") ?? .auto
        let restoredProvider = LLMProviderType(rawValue: UserDefaults.standard.string(forKey: "noteChatProvider") ?? "")
        // If mode is .provider but the saved provider is gone, fall back to .auto
        if restoredMode == .provider, restoredProvider == nil {
            self.chatMode = .auto
            self.overrideProvider = nil
        } else {
            self.chatMode = restoredMode
            self.overrideProvider = restoredProvider
        }
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
        onTokenFlush?(delta)
        HapticHelper.streamingTick()
    }

    // MARK: - Submit

    func submitQuery(_ query: String, triageService: TriageService, llmService: LLMService) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        responseText = ""
        error = nil
        isStreaming = true
        hasResponse = true
        responseText.reserveCapacity(16_384)

        onStreamStart?(trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let systemPrompt = """
        You are a helpful note assistant embedded in the user's note editor. \
        Answer concisely and helpfully based on the note content below.

        --- NOTE ---
        \(noteBody.prefix(50_000))
        --- END NOTE ---
        """

        let stream: AsyncThrowingStream<String, Error>
        switch chatMode {
        case .auto:
            stream = triageService.stream(
                prompt: trimmed, systemPrompt: systemPrompt,
                operation: .ask(query: trimmed),
                contentLength: noteBody.count, query: trimmed
            )
            log.info("Note chat: auto mode (triage routing)")
        case .cloudOnly:
            stream = llmService.stream(prompt: trimmed, systemPrompt: systemPrompt)
            log.info("Note chat: cloud-only mode")
        case .provider:
            let provider = overrideProvider ?? .anthropic
            stream = llmService.stream(prompt: trimmed, systemPrompt: systemPrompt, provider: provider)
            log.info("Note chat: manual provider (\(provider.displayName))")
        }

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await chunk in stream {
                    self.appendStreamingText(chunk)
                }
                self.flushTokens()
                self.isStreaming = false
                self.log.info("Note chat complete for page \(self.pageId)")
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
    /// .rewrite (0.25) → on-device, .expand (0.50) → cloud, etc.
    func submitQuery(
        _ query: String,
        operation: NotesOperation,
        systemPrompt: String,
        triageService: TriageService
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        responseText = ""
        error = nil
        isStreaming = true
        hasResponse = true
        responseText.reserveCapacity(16_384)

        onStreamStart?(trimmed)

        let noteBody = noteBodyProvider?() ?? ""
        let fullSystemPrompt = """
        \(systemPrompt)

        --- NOTE ---
        \(noteBody.prefix(50_000))
        --- END NOTE ---
        """

        let stream = triageService.stream(
            prompt: trimmed,
            systemPrompt: fullSystemPrompt,
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
                self.isStreaming = false
                self.log.info("Note chat complete for page \(self.pageId)")
            } catch {
                self.flushTokens()
                self.isStreaming = false
                self.error = error.localizedDescription
                self.log.error("Note chat error: \(error.localizedDescription)")
            }
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        flushTokens()
        isStreaming = false
    }

    func acceptResponse() {
        onAccept?()
        hasResponse = false
        responseText = ""
        log.info("Note chat accepted for page \(self.pageId)")
    }

    func discardResponse() {
        onDiscard?()
        hasResponse = false
        responseText = ""
        log.info("Note chat discarded for page \(self.pageId)")
    }

    func clear() {
        stopStreaming()
        inputText = ""
        responseText = ""
        error = nil
        hasResponse = false
    }
}
