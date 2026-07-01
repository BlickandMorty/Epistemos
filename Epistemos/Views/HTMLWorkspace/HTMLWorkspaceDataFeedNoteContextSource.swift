import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func noteResults(
        query: String?,
        searchResults: [SearchResult],
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let boundedResults = Array(searchResults.prefix(effectiveLimit))
        guard !boundedResults.isEmpty else {
            return recentNoteResults(query: query, modelContainer: modelContainer, limit: effectiveLimit)
        }

        let context = modelContainer.map(ModelContext.init)
        return boundedResults.enumerated().map { index, result in
            noteResult(
                searchResult: result,
                page: context.flatMap { notePage(id: result.pageId, context: $0) },
                order: index,
                query: query
            )
        }
    }

    static func shouldUseNoteResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedNoteQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("note:") || normalizedQuery.hasPrefix("notes:") {
            return true
        }
        if normalizedQuery.hasPrefix("note ") || normalizedQuery.hasPrefix("notes ") {
            return true
        }
        return ["note", "notes"].contains(normalizedQuery)
    }

    private static func recentNoteResults(
        query: String?,
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let fetchLimit = min(effectiveLimit * 4, HTMLWorkspaceDataFeed.maxLimit * 4)
        let context = ModelContext(modelContainer)
        let pages = (try? context.fetch(SDPage.recentDescriptor(limit: fetchLimit))) ?? []
        return pages
            .filter(isPlainNotePage)
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, page in
                recentNoteResult(page: page, order: index, query: query)
            }
    }

    private static func noteResult(
        searchResult: SearchResult,
        page: SDPage?,
        order: Int,
        query: String?
    ) -> HTMLWorkspaceDataFeedResult {
        let title = normalizedNoteText(page?.title).isEmpty ? searchResult.title : page?.title ?? searchResult.title
        let summary = normalizedNoteText(page?.summary)
        let bodySnippet = page?.normalizedBodySnippet(limit: 420) ?? ""
        let snippet = [summary, bodySnippet, searchResult.snippet]
            .map(normalizedNoteText)
            .first { !$0.isEmpty } ?? "No note excerpt available."
        return HTMLWorkspaceDataFeedResult(
            pageID: searchResult.pageId,
            title: normalizedNoteText(title).isEmpty ? "Untitled note" : title,
            snippet: snippet,
            rank: max(0.01, min(searchResult.rank, 1.0) - Double(order) * 0.001),
            contextKind: "note",
            sourceLabel: "Note",
            provenance: noteProvenance(page: page, searchResult: searchResult, query: query)
        )
    }

    private static func recentNoteResult(
        page: SDPage,
        order: Int,
        query: String?
    ) -> HTMLWorkspaceDataFeedResult {
        let title = normalizedNoteText(page.title).isEmpty ? "Untitled note" : page.title
        let summary = normalizedNoteText(page.summary)
        let bodySnippet = page.normalizedBodySnippet(limit: 420)
        let snippet = [summary, bodySnippet]
            .map(normalizedNoteText)
            .first { !$0.isEmpty } ?? "No note excerpt available."
        return HTMLWorkspaceDataFeedResult(
            pageID: page.id,
            title: title,
            snippet: snippet,
            rank: max(0.01, 1.0 - Double(order) * 0.01),
            contextKind: "note",
            sourceLabel: "Note",
            provenance: recentNoteProvenance(page: page, query: query)
        )
    }

    private static func notePage(id pageID: String, context: ModelContext) -> SDPage? {
        let trimmedPageID = normalizedNoteText(pageID)
        guard !trimmedPageID.isEmpty else { return nil }
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.id == trimmedPageID }
        )
        descriptor.fetchLimit = 1
        guard let page = try? context.fetch(descriptor).first else { return nil }
        guard !page.isArchived, page.templateId == nil else { return nil }
        return page
    }

    private static func isPlainNotePage(_ page: SDPage) -> Bool {
        guard !page.isArchived, page.templateId == nil else { return false }
        let frontMatter = page.frontMatter
        let source = normalizedNoteText(frontMatter["source"]).lowercased()
        let sourceKind = normalizedNoteText(frontMatter["source_kind"]).lowercased()
        if source == "meeting_stt" || source == "arxiv" || source == "web" { return false }
        if ["audio_transcript", "pdf", "web_clip"].contains(sourceKind) { return false }
        if !normalizedNoteText(frontMatter["captured_at"]).isEmpty { return false }
        if !normalizedNoteText(frontMatter["source_pdf"]).isEmpty { return false }
        if !normalizedNoteText(frontMatter["arxiv_id"]).isEmpty { return false }
        if !normalizedNoteText(frontMatter["source-url"]).isEmpty { return false }
        return true
    }

    private static func noteProvenance(page: SDPage?, searchResult: SearchResult, query: String?) -> String {
        let rank = searchResult.rank.isFinite ? String(format: "%.4f", searchResult.rank) : "unavailable"
        let queryText = normalizedNoteText(query)
        let pageSource = normalizedNoteText(page?.frontMatter["source"])
        let pageSourceKind = normalizedNoteText(page?.frontMatter["source_kind"])
        return [
            page == nil ? "VaultSyncService.searchFullAsync" : "SDPage",
            pageSource,
            pageSourceKind,
            queryText.isEmpty ? "" : "query:\(queryText)",
            "rank:\(rank)",
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private static func recentNoteProvenance(page: SDPage, query: String?) -> String {
        let queryText = normalizedNoteText(query)
        let pageSource = normalizedNoteText(page.frontMatter["source"])
        let pageSourceKind = normalizedNoteText(page.frontMatter["source_kind"])
        return [
            "SDPage",
            "recent-note fallback",
            pageSource,
            pageSourceKind,
            queryText.isEmpty ? "" : "query:\(queryText)",
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private static func normalizedNoteQuery(_ value: String?) -> String {
        normalizedNoteText(value).lowercased()
    }

    private static func normalizedNoteText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedNoteText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
