import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func recentChatResults(
        query: String?,
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }

        let context = ModelContext(modelContainer)
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = min(200, max(HTMLWorkspaceDataFeed.clampedLimit(limit) * 6, 24))
        let chats = (try? context.fetch(descriptor)) ?? []
        let terms = chatSearchTerms(from: query)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)

        return chats
            .compactMap { recentChatCandidate(from: $0, terms: terms) }
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, candidate in
                HTMLWorkspaceDataFeedResult(
                    pageID: candidate.chatID,
                    title: candidate.title,
                    snippet: candidate.snippet,
                    rank: max(0.01, 1.0 - Double(index) * 0.01),
                    contextKind: "recent_chat",
                    sourceLabel: candidate.sourceLabel,
                    provenance: candidate.provenance
                )
            }
    }

    static func shouldUseRecentChatResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedChatQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("chat:") || normalizedQuery.hasPrefix("chats:") {
            return true
        }
        if normalizedQuery.hasPrefix("chat ") || normalizedQuery.hasPrefix("chats ")
            || normalizedQuery.hasPrefix("recent chat ") || normalizedQuery.hasPrefix("recent chats ") {
            return true
        }
        return [
            "chat",
            "chats",
            "recent chat",
            "recent chats",
            "chat transcript",
            "chat transcripts",
        ].contains(normalizedQuery)
    }

    private struct RecentChatCandidate {
        var chatID: String
        var title: String
        var snippet: String
        var sourceLabel: String
        var provenance: String
    }

    // HW-CHAT-1 (audit 2026-07-04): hoisted — was allocated fresh per candidate row. The enclosing
    // enum is MainActor-isolated (unmarked under MainActor-default) + recentChatCandidate runs on
    // MainActor, so a plain static formatter is concurrency-safe (no nonisolated(unsafe) needed).
    private static let chatUpdatedAtISO8601 = ISO8601DateFormatter()

    private static func recentChatCandidate(from chat: SDChat, terms: [String]) -> RecentChatCandidate? {
        let title = normalizedChatText(chat.title).isEmpty ? "Untitled chat" : chat.title
        let preview = ChatPreviewText.preview(for: chat) ?? ""
        let snippet = normalizedChatText(preview)
        guard !snippet.isEmpty else { return nil }

        if !terms.isEmpty {
            let haystack = [title, chat.chatType, snippet]
                .map { normalizedChatText($0).lowercased() }
                .joined(separator: " ")
            guard terms.allSatisfy({ haystack.contains($0) }) else { return nil }
        }

        let provenanceParts = [
            "SDChat",
            normalizedChatText(chat.chatType),
            "updated_at:\(Self.chatUpdatedAtISO8601.string(from: chat.updatedAt))",
        ].filter { !$0.isEmpty }
        return RecentChatCandidate(
            chatID: chat.id,
            title: title,
            snippet: snippet,
            sourceLabel: "Recent chat",
            provenance: provenanceParts.joined(separator: " / ")
        )
    }

    private static func chatSearchTerms(from query: String?) -> [String] {
        var value = normalizedChatQuery(query)
        for prefix in ["chat:", "chats:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        let stopWords: Set<String> = ["chat", "chats", "recent", "transcript", "transcripts"]
        return value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private static func normalizedChatQuery(_ value: String?) -> String {
        normalizedChatText(value).lowercased()
    }

    private static func normalizedChatText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedChatText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
