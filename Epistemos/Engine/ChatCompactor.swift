// ChatCompactor.swift
//
// Context compaction for long conversations. Triggers at 80% of context
// window capacity, summarizes older messages using a small model (Haiku/mini),
// preserves recent messages verbatim.
//
// Head-tail strategy: keep system + first N turns (task context) + last M turns
// (recent work). Compress the middle into a summary. Iterative — fold old
// summaries into new ones rather than discarding.
//
// 2026-04-06.

import Foundation

// MARK: - Chat Compactor

enum ChatCompactor {
    /// Rough token estimation: ~4 chars per token for English text.
    static func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    /// Check if compaction should trigger (>80% of context window used).
    static func shouldCompact(
        messages: [ChatMessage],
        contextLimit: Int
    ) -> Bool {
        let estimated = messages.reduce(0) { $0 + estimateTokens($1.content) }
        return Double(estimated) / Double(contextLimit) > 0.80
    }

    /// The summarization prompt used to compress older messages.
    static let summarizationPrompt = """
    You are summarizing a conversation for context preservation.
    Compress the following messages into a concise summary that preserves:
    - All decisions made and their rationale
    - All file edits applied and their locations
    - Key facts and constraints established
    - Open questions and next steps
    Output only the summary, no commentary.
    """

    /// Compact messages by summarizing older turns and keeping recent ones verbatim.
    ///
    /// - Parameters:
    ///   - messages: Full message history
    ///   - summarize: Closure that sends the older messages to a small model for summarization
    /// - Returns: Compacted message array with a summary message replacing older turns
    static func compact(
        messages: [ChatMessage],
        summarize: ([ChatMessage]) async throws -> String
    ) async throws -> [ChatMessage] {
        // Keep last 8 messages (4 turns) verbatim
        let recentCount = min(8, messages.count)
        let recent = Array(messages.suffix(recentCount))
        let older = Array(messages.dropLast(recentCount))

        guard !older.isEmpty else { return messages }

        let summary = try await summarize(older)

        // Build a system message with the summary
        let summaryMessage = ChatMessage(
            role: .system,
            content: "[Context summary]\n\(summary)"
        )

        return [summaryMessage] + recent
    }

    /// Check if a message is a previous compaction summary (for iterative folding).
    static func isCompactionSummary(_ message: ChatMessage) -> Bool {
        message.role == .system && message.content.hasPrefix("[Context summary]")
    }
}
