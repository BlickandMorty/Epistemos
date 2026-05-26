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
    private static let toolsOpenTag = "<tools>"
    private static let toolsCloseTag = "</tools>"
    private static let singleToolOpenTag = "<tool>"
    private static let singleToolCloseTag = "</tool>"
    private static let hiddenTagPairs: [(open: String, close: String)] = [
        ("<scratch_pad>", "</scratch_pad>"),
        ("<think>", "</think>"),
    ]
    private static let prefixCandidates: [String] = [
        exactToolOpenTag,
        malformedToolOpenTag,
        toolCloseTag,
        toolsOpenTag,
        toolsCloseTag,
        singleToolOpenTag,
        singleToolCloseTag,
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
            if let closingRange = Self.leadingControlClosingRange(in: buffer) {
                buffer.removeSubrange(closingRange)
                continue
            }

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
            || buffer.hasPrefix(Self.toolsOpenTag)
            || buffer.hasPrefix(Self.singleToolOpenTag) {
            buffer = ""
            return ""
        }
        let flushed = buffer
        pendingText.append(flushed)
        buffer = ""
        return flushed
    }

    private func consumeLeadingToolCall() -> Detection? {
        if buffer.hasPrefix(Self.toolsOpenTag) {
            return consumeLeadingToolsWrapper()
        }

        if buffer.hasPrefix(Self.singleToolOpenTag) {
            return consumeLeadingSingleToolWrapper()
        }

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

    private func consumeLeadingToolsWrapper() -> Detection? {
        guard let wrapperClose = buffer.range(of: Self.toolsCloseTag) else {
            return nil
        }

        let bodyStart = buffer.index(buffer.startIndex, offsetBy: Self.toolsOpenTag.count)
        guard bodyStart <= wrapperClose.lowerBound else {
            buffer.removeSubrange(..<wrapperClose.upperBound)
            return nil
        }

        let wrapperBody = String(buffer[bodyStart..<wrapperClose.lowerBound])
        buffer.removeSubrange(..<wrapperClose.upperBound)

        return detectionFromToolsWrapperBody(wrapperBody)
    }

    private func consumeLeadingSingleToolWrapper() -> Detection? {
        guard let closeRange = buffer.range(of: Self.singleToolCloseTag) else {
            return nil
        }

        let bodyStart = buffer.index(buffer.startIndex, offsetBy: Self.singleToolOpenTag.count)
        guard bodyStart <= closeRange.lowerBound else {
            buffer.removeSubrange(..<closeRange.upperBound)
            return nil
        }

        let content = String(buffer[bodyStart..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeSubrange(..<closeRange.upperBound)

        return detectionFromToolBody(content)
    }

    private func detectionFromToolsWrapperBody(_ body: String) -> Detection? {
        if let openRange = body.range(of: Self.singleToolOpenTag),
           let closeRange = body.range(
            of: Self.singleToolCloseTag,
            range: openRange.upperBound..<body.endIndex
           ) {
            let content = String(body[openRange.upperBound..<closeRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return detectionFromToolBody(content)
        }

        return detectionFromToolBody(body.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func detectionFromToolBody(_ content: String) -> Detection? {
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

    private static func leadingControlClosingRange(in text: String) -> Range<String.Index>? {
        let closingTags = [
            singleToolCloseTag,
            toolsCloseTag,
            toolCloseTag,
        ] + hiddenTagPairs.map(\.close)

        guard let tag = closingTags.first(where: { text.hasPrefix($0) }) else {
            return nil
        }

        let end = text.index(text.startIndex, offsetBy: tag.count)
        return text.startIndex..<end
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
            toolsOpenTag,
            singleToolOpenTag,
        ] + hiddenTagPairs.map(\.open)
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
