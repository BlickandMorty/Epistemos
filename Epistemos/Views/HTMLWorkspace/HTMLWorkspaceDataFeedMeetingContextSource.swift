import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func meetingNoteResults(
        query: String?,
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }

        let context = ModelContext(modelContainer)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let fetchLimit = min(effectiveLimit * 8, HTMLWorkspaceDataFeed.maxLimit * 8)
        var descriptor = SDPage.recentDescriptor(limit: fetchLimit)
        descriptor.fetchLimit = fetchLimit
        let terms = meetingSearchTerms(from: query)

        return ((try? context.fetch(descriptor)) ?? [])
            .compactMap { meetingNoteCandidate(from: $0, terms: terms) }
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, candidate in
                HTMLWorkspaceDataFeedResult(
                    pageID: candidate.pageID,
                    title: candidate.title,
                    snippet: candidate.snippet,
                    rank: max(0.01, 1.0 - Double(index) * 0.01),
                    contextKind: "meeting_note",
                    sourceLabel: candidate.sourceLabel,
                    provenance: candidate.provenance
                )
            }
    }

    static func shouldUseMeetingNoteResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedMeetingQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("meeting:") || normalizedQuery.hasPrefix("meetings:") {
            return true
        }
        if normalizedQuery.hasPrefix("meeting ") || normalizedQuery.hasPrefix("meetings ")
            || normalizedQuery.hasPrefix("meeting note ") || normalizedQuery.hasPrefix("meeting notes ") {
            return true
        }
        return [
            "meeting",
            "meetings",
            "meeting note",
            "meeting notes",
            "meeting transcript",
            "meeting transcripts",
        ].contains(normalizedQuery)
    }

    private struct MeetingNoteCandidate {
        var pageID: String
        var title: String
        var snippet: String
        var sourceLabel: String
        var provenance: String
    }

    private static func meetingNoteCandidate(from page: SDPage, terms: [String]) -> MeetingNoteCandidate? {
        guard page.templateId == nil, !page.isArchived else { return nil }
        let frontMatter = page.frontMatter
        let source = normalizedMeetingText(frontMatter["source"])
        let sourceKind = normalizedMeetingText(frontMatter["source_kind"])
        guard source == "meeting_stt" || sourceKind == "audio_transcript" else { return nil }

        let title = normalizedMeetingText(page.title).isEmpty ? "Untitled meeting note" : page.title
        let summary = normalizedMeetingText(page.summary)
        let bodySnippet = page.normalizedBodySnippet(limit: 420)
        let snippet = summary.isEmpty ? bodySnippet : summary

        if !terms.isEmpty {
            let haystack = [
                title,
                summary,
                bodySnippet,
                frontMatter["captured_at"],
                frontMatter["audio_source"],
                frontMatter["stt_engine"],
            ]
                .map { normalizedMeetingText($0).lowercased() }
                .joined(separator: " ")
            guard terms.allSatisfy({ haystack.contains($0) }) else { return nil }
        }

        return MeetingNoteCandidate(
            pageID: page.id,
            title: title,
            snippet: normalizedMeetingText(snippet).isEmpty ? "No meeting-note excerpt available." : snippet,
            sourceLabel: "Meeting note",
            provenance: meetingProvenance(frontMatter: frontMatter)
        )
    }

    private static func meetingProvenance(frontMatter: [String: String]) -> String {
        [
            "TextCapturePipeline",
            normalizedMeetingText(frontMatter["source"]),
            normalizedMeetingText(frontMatter["source_kind"]),
            normalizedMeetingText(frontMatter["captured_at"]).isEmpty
                ? ""
                : "captured_at:\(normalizedMeetingText(frontMatter["captured_at"]))",
            normalizedMeetingText(frontMatter["duration_seconds"]).isEmpty
                ? ""
                : "duration_seconds:\(normalizedMeetingText(frontMatter["duration_seconds"]))",
            normalizedMeetingText(frontMatter["stt_engine"]),
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private static func meetingSearchTerms(from query: String?) -> [String] {
        var value = normalizedMeetingQuery(query)
        for prefix in ["meeting:", "meetings:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        let stopWords: Set<String> = ["meeting", "meetings", "note", "notes", "transcript", "transcripts"]
        return value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private static func normalizedMeetingQuery(_ value: String?) -> String {
        normalizedMeetingText(value).lowercased()
    }

    private static func normalizedMeetingText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedMeetingText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
