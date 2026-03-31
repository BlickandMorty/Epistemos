import Foundation

/// Incrementally detects `<tool_call>...</tool_call>` tags in a streaming token
/// sequence. Emits a `Detection` the instant the closing tag completes, enabling
/// the caller to fire the tool action and cancel remaining generation.
///
/// Thread-safety: callers must serialize access (the `onToken` callback in
/// `LocalAgentLoop` is already sequential). Marked `@unchecked Sendable` to
/// allow capture in `@Sendable` closures.
nonisolated final class IncrementalToolCallDetector: @unchecked Sendable {

    struct Detection: Sendable {
        let toolCall: LocalAgentLoop.ParsedToolCall
        /// Raw text between the `<tool_call>` and `</tool_call>` tags.
        let rawContent: String
    }

    // MARK: - State Machine

    private enum State {
        /// Scanning for the `<tool_call>` open tag.
        case scanning
        /// Accumulating body content; scanning for `</tool_call>` close tag.
        case accumulating
    }

    private static let openTag = Array("<tool_call>".unicodeScalars.map { Character($0) })   // 11 chars
    private static let closeTag = Array("</tool_call>".unicodeScalars.map { Character($0) }) // 12 chars

    private var state: State = .scanning
    /// How many characters of the current tag we have matched so far.
    private var tagMatchIndex = 0
    /// Body content accumulated between open and close tags.
    private var bodyBuffer = ""
    /// Non-tool-call text accumulated during `.scanning` (for UI display).
    private(set) var pendingText = ""

    // MARK: - Public API

    /// Feed a chunk of tokens. Returns a `Detection` if a complete
    /// `<tool_call>...</tool_call>` block was found in or completed by this chunk.
    func feed(_ chunk: String) -> Detection? {
        for char in chunk {
            switch state {
            case .scanning:
                if char == Self.openTag[tagMatchIndex] {
                    tagMatchIndex += 1
                    if tagMatchIndex == Self.openTag.count {
                        // Full open tag matched — transition to accumulating.
                        state = .accumulating
                        tagMatchIndex = 0
                        bodyBuffer = ""
                    }
                } else {
                    // Mismatch: flush any partially-matched tag chars as pending text.
                    if tagMatchIndex > 0 {
                        pendingText.append(contentsOf: Self.openTag.prefix(tagMatchIndex))
                        tagMatchIndex = 0
                    }
                    pendingText.append(char)
                }

            case .accumulating:
                if char == Self.closeTag[tagMatchIndex] {
                    tagMatchIndex += 1
                    if tagMatchIndex == Self.closeTag.count {
                        // Full close tag matched — we have a complete tool call.
                        tagMatchIndex = 0
                        state = .scanning

                        let content = bodyBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                        bodyBuffer = ""

                        let parsed = ToolCallParser.parse(content)
                        guard let first = parsed.first else { continue }

                        return Detection(
                            toolCall: LocalAgentLoop.ParsedToolCall(
                                name: first.name,
                                argumentsJson: first.argumentsJson
                            ),
                            rawContent: content
                        )
                    }
                } else {
                    // Mismatch: the partially-matched close tag chars were actually body.
                    if tagMatchIndex > 0 {
                        bodyBuffer.append(contentsOf: Self.closeTag.prefix(tagMatchIndex))
                        tagMatchIndex = 0
                    }
                    bodyBuffer.append(char)
                }
            }
        }
        return nil
    }

    /// Reset to initial state for a new generation turn.
    func reset() {
        state = .scanning
        tagMatchIndex = 0
        bodyBuffer = ""
        pendingText = ""
    }
}
