import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Daily Brief State
// Manages the daily brief overlay: generation, loading, and auto-save.
// Extracted from UIState to keep UI state focused on navigation and chrome.

@MainActor @Observable
final class DailyBriefState {
    /// When true, the Daily Brief overlay is presented (blurred background + animated answer).
    var showDailyBrief = false

    /// The LLM's response to the daily brief prompt. Empty while loading.
    var dailyBriefContent = ""

    /// True while the LLM is generating the daily brief answer.
    var isDailyBriefLoading = false

    /// Callback wired by AppBootstrap — calls the triage service to generate the brief.
    var onDailyBriefGenerate: (@MainActor @Sendable (String) async -> String?)?

    /// Callback wired by AppBootstrap — persists daily brief content as a note in the "Daily Briefs" folder.
    var onDailyBriefSave: (@MainActor @Sendable (String) async -> Void)?

    private var dailyBriefTask: Task<Void, Never>?

    func requestDailyBrief(prompt: String) {
        showDailyBrief = true
        isDailyBriefLoading = true
        dailyBriefContent = ""

        dailyBriefTask?.cancel()
        dailyBriefTask = Task {
            if let result = await onDailyBriefGenerate?(prompt) {
                guard !Task.isCancelled else { return }
                withAnimation(Motion.smooth) {
                    dailyBriefContent = result
                    isDailyBriefLoading = false
                }
                // Auto-save to notes
                await onDailyBriefSave?(result)
            } else {
                isDailyBriefLoading = false
                dailyBriefContent = "Unable to generate a brief."
            }
        }
    }

    func dismissDailyBrief() {
        dailyBriefTask?.cancel()
        dailyBriefTask = nil
        withAnimation(Motion.smooth) {
            showDailyBrief = false
        }
        // Cleanup after animation completes
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            dailyBriefContent = ""
            isDailyBriefLoading = false
        }
    }

    // MARK: - Prompt Builders

    static func recentContextNotes(
        pages: [SDPage],
        limit: Int = 18
    ) -> [(page: SDPage, body: String)] {
        pages.compactMap { page in
            guard page.templateId == nil else { return nil }
            let body = page.loadBody(mapped: true)
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return (page, body)
        }
        .prefix(limit)
        .map { $0 }
    }

    static func normalizedSnippet(from body: String, limit: Int) -> String {
        String(body.prefix(limit))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds the daily brief prompt from recent pages and chats.
    /// Shared by LandingView and CommandPaletteOverlay.
    static func buildBriefPrompt(pages: [SDPage], chats: [SDChat]) -> String {
        var context: [String] = []

        let recentNotes = recentContextNotes(pages: pages)

        if !recentNotes.isEmpty {
            var notesSection = "## Recent Notes (\(recentNotes.count) most recent)\n"
            for note in recentNotes {
                let snippet = normalizedSnippet(from: note.body, limit: 500)
                let tags = note.page.tags.isEmpty ? "" : " [tags: \(note.page.tags.joined(separator: ", "))]"
                let daysSinceEdit =
                    Calendar.current.dateComponents([.day], from: note.page.updatedAt, to: .now).day ?? 0
                let freshness = daysSinceEdit == 0 ? "today" : daysSinceEdit == 1 ? "yesterday" : "\(daysSinceEdit)d ago"
                let emoji = note.page.emoji.isEmpty ? "" : "\(note.page.emoji) "
                notesSection +=
                    "- **\(emoji)\(note.page.title.isEmpty ? "Untitled" : note.page.title)**\(tags) (\(note.page.wordCount) words, edited \(freshness)): \(snippet)…\n"
            }

            let totalWords = recentNotes.reduce(0) { $0 + $1.page.wordCount }
            let allTags = recentNotes.flatMap(\.page.tags)
            let tagFreq = Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
                .sorted { $0.value > $1.value }
                .prefix(8)
                .map { "\($0.key) (\($0.value))" }
            if !tagFreq.isEmpty {
                notesSection += "\nTop tags: \(tagFreq.joined(separator: ", ")) | Total words across notes: \(totalWords)\n"
            }
            context.append(notesSection)
        }

        let recentChats = chats.prefix(12)

        if !recentChats.isEmpty {
            var chatsSection = "## Recent Conversations (\(recentChats.count) most recent)\n"
            for chatItem in recentChats {
                let msgs = chatItem.sortedMessages
                let msgCount = msgs.count
                let daysSinceChat =
                    Calendar.current.dateComponents([.day], from: chatItem.updatedAt, to: .now).day ?? 0
                let freshness = daysSinceChat == 0 ? "today" : daysSinceChat == 1 ? "yesterday" : "\(daysSinceChat)d ago"
                let lastUserMsg = msgs.last { $0.role == "user" }?.content.prefix(300) ?? ""
                let lastAssistantSnippet = msgs.last { $0.role == "assistant" }?.content.prefix(200) ?? ""
                let userSnippet = String(lastUserMsg)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let assistantSnippet = String(lastAssistantSnippet)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                chatsSection +=
                    "- **\(chatItem.title)** (\(msgCount) msgs, \(freshness))\n"
                if !userSnippet.isEmpty {
                    chatsSection += "  Q: \(userSnippet)…\n"
                }
                if !assistantSnippet.isEmpty {
                    chatsSection += "  A: \(assistantSnippet)…\n"
                }
            }
            context.append(chatsSection)
        }

        if let manifest = AppBootstrap.shared?.ambientManifest {
            context.append(manifest.asManifestOnly())
        }

        let contextBlock = context.isEmpty ? "" : """

            Here is my recent activity and vault overview:

            \(context.joined(separator: "\n"))
            """

        return """
            Summarize my recent notes and conversations into a short daily brief.

            Include:
            - the main threads I am actively working on
            - notable recent changes or repeated topics
            - open loops or unfinished work
            - 3-5 concrete next steps

            Be direct. Reference specific note titles or conversations when useful. Do not add roleplay, hidden reasoning, or preamble.
            \(contextBlock)
            """
    }
}
