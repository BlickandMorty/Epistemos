import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func webClipResults(
        query: String?,
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }

        let context = ModelContext(modelContainer)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let fetchLimit = min(effectiveLimit * 8, HTMLWorkspaceDataFeed.maxLimit * 8)
        let terms = webClipSearchTerms(from: query)
        var descriptor = SDPage.recentDescriptor(limit: fetchLimit)
        descriptor.fetchLimit = fetchLimit

        return ((try? context.fetch(descriptor)) ?? [])
            .compactMap { webClipCandidate(from: $0, terms: terms) }
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, candidate in
                HTMLWorkspaceDataFeedResult(
                    pageID: candidate.pageID,
                    title: candidate.title,
                    snippet: candidate.snippet,
                    rank: max(0.01, 1.0 - Double(index) * 0.01),
                    contextKind: "web_clip",
                    sourceLabel: candidate.sourceLabel,
                    provenance: candidate.provenance
                )
            }
    }

    static func shouldUseWebClipResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedWebClipQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("web:") || normalizedQuery.hasPrefix("clip:") || normalizedQuery.hasPrefix("clips:") {
            return true
        }
        if normalizedQuery.hasPrefix("web clip ") || normalizedQuery.hasPrefix("web clips ")
            || normalizedQuery.hasPrefix("webclip ") || normalizedQuery.hasPrefix("clips ") {
            return true
        }
        return [
            "web clip",
            "web clips",
            "webclip",
            "clip",
            "clips",
        ].contains(normalizedQuery)
    }

    private struct WebClipCandidate {
        var pageID: String
        var title: String
        var snippet: String
        var sourceLabel: String
        var provenance: String
    }

    private static func webClipCandidate(from page: SDPage, terms: [String]) -> WebClipCandidate? {
        guard page.templateId == nil, !page.isArchived else { return nil }
        let frontMatter = page.frontMatter
        let source = normalizedWebClipText(frontMatter["source"])
        let sourceKind = normalizedWebClipText(frontMatter["source_kind"])
        guard sourceKind == "web_clip" || (source == "web" && !normalizedWebClipText(frontMatter["source-url"]).isEmpty) else {
            return nil
        }

        let sourceTitle = normalizedWebClipText(frontMatter["source_title"])
        let title = normalizedWebClipText(page.title).isEmpty ? sourceTitle : page.title
        let summary = normalizedWebClipText(page.summary)
        let bodySnippet = page.normalizedBodySnippet(limit: 420)
        let sourceURL = normalizedWebClipText(frontMatter["source-url"])

        if !terms.isEmpty {
            let haystack = [
                title,
                sourceTitle,
                summary,
                bodySnippet,
                sourceURL,
                frontMatter["captured_at"],
            ]
                .map { normalizedWebClipText($0).lowercased() }
                .joined(separator: " ")
            guard terms.allSatisfy({ haystack.contains($0) }) else { return nil }
        }

        let snippet = summary.isEmpty ? bodySnippet : summary
        return WebClipCandidate(
            pageID: page.id,
            title: normalizedWebClipText(title).isEmpty ? "Untitled web clip" : title,
            snippet: normalizedWebClipText(snippet).isEmpty ? "No web-clip excerpt available." : snippet,
            sourceLabel: webClipSourceLabel(sourceURL: sourceURL),
            provenance: webClipProvenance(frontMatter: frontMatter)
        )
    }

    private static func webClipSourceLabel(sourceURL: String) -> String {
        guard let host = URL(string: sourceURL)?.host, !host.isEmpty else {
            return "Web clip"
        }
        return "Web clip: \(host)"
    }

    private static func webClipProvenance(frontMatter: [String: String]) -> String {
        let sourceURL = boundedWebClipText(normalizedWebClipText(frontMatter["source-url"]), limit: 240)
        return [
            "WebClipperMarkdownBuilder",
            normalizedWebClipText(frontMatter["source"]),
            normalizedWebClipText(frontMatter["source_kind"]),
            normalizedWebClipText(frontMatter["captured_at"]).isEmpty
                ? ""
                : "captured_at:\(normalizedWebClipText(frontMatter["captured_at"]))",
            sourceURL.isEmpty ? "" : "url:\(sourceURL)",
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private static func webClipSearchTerms(from query: String?) -> [String] {
        var value = normalizedWebClipQuery(query)
        for prefix in ["web:", "clip:", "clips:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        let stopWords: Set<String> = ["web", "webclip", "clip", "clips", "article", "articles"]
        return value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private static func boundedWebClipText(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        guard limit > 3 else { return String(value.prefix(limit)) }
        return String(value.prefix(limit - 3)) + "..."
    }

    private static func normalizedWebClipQuery(_ value: String?) -> String {
        normalizedWebClipText(value).lowercased()
    }

    private static func normalizedWebClipText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedWebClipText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
