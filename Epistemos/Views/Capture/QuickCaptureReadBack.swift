import Foundation

// SS-QC (D) auto read-back — pure sentence extraction, deliberately split out so it is testable in
// isolation (the finicky part of auto-on-type read-back). The view layer debounces + dedups; this
// only answers "what is the last fully-completed sentence right now?".
enum QuickCaptureReadBack {
    /// The last terminator-completed sentence in `text`, trimmed; `nil` if none is complete yet —
    /// so auto read-back waits for a full sentence and never speaks a half-typed fragment.
    nonisolated static func lastCompletedSentence(in text: String) -> String? {
        // Local (not a static) so it stays nonisolated under the module's MainActor default isolation.
        let terminators: Set<Character> = [".", "!", "?", "…"]
        guard let lastTerm = text.lastIndex(where: { terminators.contains($0) }) else { return nil }
        let sentenceEnd = text.index(after: lastTerm)
        let head = text[..<lastTerm]
        let start = head.lastIndex(where: { terminators.contains($0) })
            .map { text.index(after: $0) } ?? text.startIndex
        let sentence = text[start..<sentenceEnd].trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? nil : sentence
    }
}
