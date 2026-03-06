import Foundation
import Observation

/// Manages AI chat for the FFT-style graph dialogue box.
/// One shared instance — only one dialogue active at a time.
/// Architecture mirrors NoteChatState's streaming/buffering pattern
/// but targets a multi-message conversation instead of inline editor insertion.
@MainActor @Observable
final class DialogueChatState {

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        var text: String

        enum Role { case user, assistant }
    }

    // MARK: - Public State

    var messages: [Message] = []
    var inputText = ""
    var isStreaming = false
    var activeNodeId: String?
    var activeNodeLabel = ""
    var revealedCharCount = 0

    // MARK: - Callbacks

    /// Drives mouth animation via FFI when streaming starts/stops.
    var onStreamingChanged: ((Bool) -> Void)?

    // MARK: - Private

    private var streamingTask: Task<Void, Never>?
    private var pendingTokens = ""
    private var flushTask: Task<Void, Never>?
    private var typewriterTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func open(nodeId: String, label: String) {
        if activeNodeId == nodeId { return }
        activeNodeId = nodeId
        activeNodeLabel = label
        messages = []
        inputText = ""
        isStreaming = false
        revealedCharCount = 0
        messages.append(Message(role: .assistant, text: "What's up?"))
        startTypewriter()
    }

    func close() {
        streamingTask?.cancel()
        flushTask?.cancel()
        typewriterTask?.cancel()
        activeNodeId = nil
        isStreaming = false
    }

    // MARK: - Query

    func submitQuery(
        noteBody: String,
        linkedNodeLabels: [String],
        triageService: TriageService
    ) {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        inputText = ""

        messages.append(Message(role: .user, text: query))
        messages.append(Message(role: .assistant, text: ""))
        revealedCharCount = 0

        let systemPrompt = buildSystemPrompt(noteBody: noteBody, linkedNodeLabels: linkedNodeLabels)

        isStreaming = true
        onStreamingChanged?(true)

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = triageService.stream(
                    prompt: query,
                    systemPrompt: systemPrompt,
                    operation: .ask(query: query),
                    contentLength: noteBody.count,
                    query: query
                )
                for try await chunk in stream {
                    self.appendStreamingText(chunk)
                }
                self.flushTokens()
            } catch {
                self.flushTokens()
                if !Task.isCancelled, !self.messages.isEmpty {
                    self.messages[self.messages.count - 1].text += "\n[Error: \(error.localizedDescription)]"
                }
            }
            self.isStreaming = false
            self.onStreamingChanged?(false)
        }
    }

    // MARK: - Token Buffering (60ms, matches NoteChatState)

    private func appendStreamingText(_ text: String) {
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
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].text += delta
        startTypewriter()
    }

    // MARK: - Typewriter (~30 chars/sec)

    private func startTypewriter() {
        typewriterTask?.cancel()
        let totalChars = messages.last?.text.count ?? 0
        guard revealedCharCount < totalChars else { return }
        typewriterTask = Task { @MainActor [weak self] in
            while let self, self.revealedCharCount < (self.messages.last?.text.count ?? 0) {
                self.revealedCharCount += 1
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(noteBody: String, linkedNodeLabels: [String]) -> String {
        """
        You are "\(activeNodeLabel)", a character in a knowledge graph.
        Your personality comes from your content:

        --- CONTENT ---
        \(noteBody.prefix(50_000))
        --- END ---

        You speak in character. Be playful and helpful.
        Your connections: \(linkedNodeLabels.joined(separator: ", "))
        The user is your creator. Help them learn and remember your content.
        Keep responses concise (2-3 sentences unless asked for more).
        """
    }
}
