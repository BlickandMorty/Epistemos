import Foundation

/// Incrementally detects local-agent tool wrappers in a streaming token
/// sequence. Emits a `Detection` the instant the wrapper completes, enabling
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

    private static let exactToolOpenTag = "<tool_call>"
    private static let malformedToolOpenTag = "<tool_call<"
    private static let toolCloseTag = "</tool_call>"
    private static let phiToolOpenTag = "<|tool_call|>"
    private static let phiToolCloseTag = "</|tool_call|>"
    private static let mistralToolCallsTag = "[TOOL_CALLS]"
    private static let hiddenTagPairs: [(open: String, close: String)] = [
        ("<scratch_pad>", "</scratch_pad>"),
        ("<think>", "</think>"),
    ]
    private static let prefixCandidates: [String] = [
        exactToolOpenTag,
        malformedToolOpenTag,
        toolCloseTag,
        phiToolOpenTag,
        phiToolCloseTag,
        mistralToolCallsTag,
    ] + hiddenTagPairs.flatMap { [$0.open, $0.close] }

    private var buffer = ""
    /// Non-tool-call text accumulated during `.scanning` (for UI display).
    private(set) var pendingText = ""

    // MARK: - Public API

    /// Feed a chunk of tokens. Returns a `Detection` if a complete
    /// local-agent tool wrapper was found in or completed by this chunk.
    func feed(_ chunk: String) -> Detection? {
        guard !chunk.isEmpty else { return nil }
        buffer.append(chunk)

        while !buffer.isEmpty {
            if let hiddenRange = Self.leadingHiddenRange(in: buffer) {
                buffer.removeSubrange(hiddenRange)
                continue
            }

            if let detection = consumeLeadingToolCall() {
                return detection
            }

            if let detection = consumeLeadingMistralToolCalls() {
                return detection
            }

            if let nextTagIndex = Self.nextInterestingTagIndex(in: buffer),
               nextTagIndex > buffer.startIndex {
                pendingText.append(String(buffer[..<nextTagIndex]))
                buffer.removeSubrange(..<nextTagIndex)
                continue
            }

            if let nextTagIndex = Self.nextInterestingTagIndex(in: buffer),
               nextTagIndex == buffer.startIndex {
                // The current buffer begins with an incomplete tag; wait for more tokens.
                break
            }

            let partialLength = Self.trailingPartialPrefixLength(in: buffer)
            let flushCount = buffer.count - partialLength
            guard flushCount > 0 else { break }
            let flushIndex = buffer.index(buffer.startIndex, offsetBy: flushCount)
            pendingText.append(String(buffer[..<flushIndex]))
            buffer.removeSubrange(..<flushIndex)
        }

        return nil
    }

    /// Reset to initial state for a new generation turn.
    func reset() {
        buffer = ""
        pendingText = ""
    }

    /// Drain any text the detector was holding in its read-ahead buffer
    /// when the upstream stream ends without a complete tool-call.
    ///
    /// Why this exists: `feed(_:)` deliberately holds back trailing
    /// characters that COULD be the start of a known tag (e.g. a lone
    /// `<`, or `<sc` mid-disambiguation of `<scratch_pad>`). Under
    /// normal streaming this is correct: we wait for the next chunk
    /// to disambiguate. But when the stream ends naturally (model
    /// signals EOF, no tool call invoked), those held-back characters
    /// were silently dropped, truncating summaries / chat answers at
    /// a deterministic offset (anywhere a `<` appeared near the end
    /// of the model's output).
    ///
    /// Privacy semantics:
    /// - If the buffer starts with an OPENED hidden tag whose close
    ///   never arrived (`<scratch_pad>...` / `<think>...`), drop the
    ///   whole buffer: emitting the model's internal scratchpad would
    ///   leak chain-of-thought into the visible UI.
    /// - If the buffer starts with an unclosed `<tool_call>` open,
    ///   drop it: that's a malformed tool invocation, not user-visible
    ///   text.
    /// - Otherwise the buffer is plaintext that happened to end
    ///   on a tag-prefix-candidate; emit it.
    ///
    /// Returns the flushed visible text (also appended to `pendingText`
    /// so the same `pendingText` delta-emit pattern in
    /// `LocalAgentLoop` continues to work).
    func flushOnStreamEnd() -> String {
        guard !buffer.isEmpty else { return "" }
        // Privacy: don't leak hidden-tag bodies.
        for pair in Self.hiddenTagPairs where buffer.hasPrefix(pair.open) {
            buffer = ""
            return ""
        }
        // Don't surface a malformed tool invocation as user text.
        if buffer.hasPrefix(Self.exactToolOpenTag)
            || buffer.hasPrefix(Self.malformedToolOpenTag)
            || buffer.hasPrefix(Self.phiToolOpenTag)
            || buffer.hasPrefix(Self.mistralToolCallsTag) {
            buffer = ""
            return ""
        }
        let flushed = buffer
        pendingText.append(flushed)
        buffer = ""
        return flushed
    }

    private func consumeLeadingToolCall() -> Detection? {
        let bodyStartOffset: Int
        let closeTag: String

        if buffer.hasPrefix(Self.exactToolOpenTag) {
            bodyStartOffset = Self.exactToolOpenTag.count
            closeTag = Self.toolCloseTag
        } else if buffer.hasPrefix(Self.malformedToolOpenTag) {
            bodyStartOffset = Self.exactToolOpenTag.dropLast().count
            closeTag = Self.toolCloseTag
        } else if buffer.hasPrefix(Self.phiToolOpenTag) {
            bodyStartOffset = Self.phiToolOpenTag.count
            closeTag = Self.phiToolCloseTag
        } else {
            return nil
        }

        guard let closeRange = buffer.range(of: closeTag) else {
            return nil
        }

        let bodyStart = buffer.index(buffer.startIndex, offsetBy: bodyStartOffset)
        guard bodyStart <= closeRange.lowerBound else {
            buffer.removeSubrange(..<closeRange.upperBound)
            return nil
        }

        let content = String(buffer[bodyStart..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeSubrange(..<closeRange.upperBound)

        let parsed = ToolCallParser.parse(content)
        guard let first = parsed.first else {
            return nil
        }

        return Detection(
            toolCall: LocalAgentLoop.ParsedToolCall(
                name: first.name,
                argumentsJson: first.argumentsJson
            ),
            rawContent: content
        )
    }

    private func consumeLeadingMistralToolCalls() -> Detection? {
        guard buffer.hasPrefix(Self.mistralToolCallsTag) else { return nil }

        let bodyStart = buffer.index(buffer.startIndex, offsetBy: Self.mistralToolCallsTag.count)
        let body = String(buffer[bodyStart...])
        guard let fragment = Self.completeJsonFragment(in: body) else {
            return nil
        }

        let consumedLength = Self.mistralToolCallsTag.count
            + body.distance(from: body.startIndex, to: fragment.end)
        let consumedEnd = buffer.index(buffer.startIndex, offsetBy: consumedLength)
        buffer.removeSubrange(..<consumedEnd)

        let parsed = ToolCallParser.parse(fragment.content)
        guard let first = parsed.first else { return nil }

        return Detection(
            toolCall: LocalAgentLoop.ParsedToolCall(
                name: first.name,
                argumentsJson: first.argumentsJson
            ),
            rawContent: fragment.content
        )
    }

    private static func leadingHiddenRange(in text: String) -> Range<String.Index>? {
        for pair in hiddenTagPairs {
            guard text.hasPrefix(pair.open),
                  let closeRange = text.range(of: pair.close) else {
                continue
            }
            return text.startIndex..<closeRange.upperBound
        }
        return nil
    }

    private static func nextInterestingTagIndex(in text: String) -> String.Index? {
        let markers = [
            exactToolOpenTag,
            malformedToolOpenTag,
            phiToolOpenTag,
            mistralToolCallsTag,
        ] + hiddenTagPairs.map(\.open)
        return markers.compactMap { text.range(of: $0)?.lowerBound }.min()
    }

    private static func completeJsonFragment(in text: String) -> (content: String, end: String.Index)? {
        var cursor = text.startIndex
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex,
              text[cursor] == "{" || text[cursor] == "[" else {
            return nil
        }

        let start = cursor
        var stack: [Character] = [text[cursor]]
        var isInsideString = false
        var isEscaped = false
        cursor = text.index(after: cursor)

        while cursor < text.endIndex {
            let character = text[cursor]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                cursor = text.index(after: cursor)
                continue
            }

            switch character {
            case "\"":
                isInsideString = true
            case "{", "[":
                stack.append(character)
            case "}":
                guard stack.last == "{" else { return nil }
                stack.removeLast()
            case "]":
                guard stack.last == "[" else { return nil }
                stack.removeLast()
            default:
                break
            }

            let next = text.index(after: cursor)
            if stack.isEmpty {
                return (String(text[start..<next]), next)
            }
            cursor = next
        }

        return nil
    }

    private static func trailingPartialPrefixLength(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        for length in stride(from: min(text.count, longestPrefixCandidateLength - 1), through: 1, by: -1) {
            let suffixStart = text.index(text.endIndex, offsetBy: -length)
            let suffix = String(text[suffixStart...])
            if prefixCandidates.contains(where: { $0.hasPrefix(suffix) }) {
                return length
            }
        }

        return 0
    }

    private static var longestPrefixCandidateLength: Int {
        prefixCandidates.map(\.count).max() ?? 0
    }
}
