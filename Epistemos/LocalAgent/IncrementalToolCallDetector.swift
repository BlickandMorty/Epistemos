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

    private static let exactToolOpenTag = "<tool_call>"
    private static let malformedToolOpenTag = "<tool_call<"
    private static let toolCloseTag = "</tool_call>"
    private static let hiddenTagPairs: [(open: String, close: String)] = [
        ("<scratch_pad>", "</scratch_pad>"),
        ("<think>", "</think>"),
    ]
    private static let prefixCandidates: [String] = [
        exactToolOpenTag,
        malformedToolOpenTag,
        toolCloseTag,
    ] + hiddenTagPairs.flatMap { [$0.open, $0.close] }

    private var buffer = ""
    /// Non-tool-call text accumulated during `.scanning` (for UI display).
    private(set) var pendingText = ""

    // MARK: - Public API

    /// Feed a chunk of tokens. Returns a `Detection` if a complete
    /// `<tool_call>...</tool_call>` block was found in or completed by this chunk.
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

    private func consumeLeadingToolCall() -> Detection? {
        let bodyStartOffset: Int

        if buffer.hasPrefix(Self.exactToolOpenTag) {
            bodyStartOffset = Self.exactToolOpenTag.count
        } else if buffer.hasPrefix(Self.malformedToolOpenTag) {
            bodyStartOffset = Self.exactToolOpenTag.dropLast().count
        } else {
            return nil
        }

        guard let closeRange = buffer.range(of: Self.toolCloseTag) else {
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
        let markers = [exactToolOpenTag, malformedToolOpenTag] + hiddenTagPairs.map(\.open)
        return markers.compactMap { text.range(of: $0)?.lowerBound }.min()
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
