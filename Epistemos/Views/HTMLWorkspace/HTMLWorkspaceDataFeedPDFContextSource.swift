import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func pdfNoteResults(
        query: String?,
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }

        let context = ModelContext(modelContainer)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let fetchLimit = min(effectiveLimit * 8, HTMLWorkspaceDataFeed.maxLimit * 8)
        let terms = pdfSearchTerms(from: query)
        var descriptor = SDPage.recentDescriptor(limit: fetchLimit)
        descriptor.fetchLimit = fetchLimit

        return ((try? context.fetch(descriptor)) ?? [])
            .compactMap { pdfNoteCandidate(from: $0, terms: terms) }
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, candidate in
                HTMLWorkspaceDataFeedResult(
                    pageID: candidate.pageID,
                    title: candidate.title,
                    snippet: candidate.snippet,
                    rank: max(0.01, 1.0 - Double(index) * 0.01),
                    contextKind: "pdf_note",
                    sourceLabel: candidate.sourceLabel,
                    provenance: candidate.provenance
                )
            }
    }

    static func shouldUsePDFNoteResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedPDFQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("pdf:") || normalizedQuery.hasPrefix("paper:") || normalizedQuery.hasPrefix("arxiv:") {
            return true
        }
        if normalizedQuery.hasPrefix("pdf ") || normalizedQuery.hasPrefix("pdfs ")
            || normalizedQuery.hasPrefix("paper ") || normalizedQuery.hasPrefix("papers ")
            || normalizedQuery.hasPrefix("arxiv ") || normalizedQuery.hasPrefix("arxiv papers ") {
            return true
        }
        return [
            "pdf",
            "pdfs",
            "paper",
            "papers",
            "arxiv",
            "arxiv paper",
            "arxiv papers",
        ].contains(normalizedQuery)
    }

    private struct PDFNoteCandidate {
        var pageID: String
        var title: String
        var snippet: String
        var sourceLabel: String
        var provenance: String
    }

    private static func pdfNoteCandidate(from page: SDPage, terms: [String]) -> PDFNoteCandidate? {
        guard page.templateId == nil, !page.isArchived else { return nil }
        let frontMatter = page.frontMatter
        let sourceKind = normalizedPDFText(frontMatter["source_kind"])
        let sourcePDF = normalizedPDFText(frontMatter["source_pdf"])
        guard sourceKind == "pdf" || !sourcePDF.isEmpty else { return nil }

        let title = normalizedPDFText(page.title).isEmpty ? "Untitled PDF note" : page.title
        let summary = normalizedPDFText(page.summary)
        let bodySnippet = page.normalizedBodySnippet(limit: 420)
        let arxivID = normalizedPDFText(frontMatter["arxiv_id"])

        if !terms.isEmpty {
            let haystack = [
                title,
                summary,
                bodySnippet,
                arxivID,
                sourcePDF,
                frontMatter["authors"],
                frontMatter["categories"],
                frontMatter["published"],
                frontMatter["url"],
            ]
                .map { normalizedPDFText($0).lowercased() }
                .joined(separator: " ")
            guard terms.allSatisfy({ haystack.contains($0) }) else { return nil }
        }

        let snippet = summary.isEmpty ? bodySnippet : summary
        return PDFNoteCandidate(
            pageID: page.id,
            title: title,
            snippet: normalizedPDFText(snippet).isEmpty ? "No PDF-note excerpt available." : snippet,
            sourceLabel: pdfSourceLabel(frontMatter: frontMatter),
            provenance: pdfProvenance(frontMatter: frontMatter)
        )
    }

    private static func pdfSourceLabel(frontMatter: [String: String]) -> String {
        let source = normalizedPDFText(frontMatter["source"])
        let arxivID = normalizedPDFText(frontMatter["arxiv_id"])
        if source == "arxiv" || !arxivID.isEmpty {
            return arxivID.isEmpty ? "arXiv paper" : "arXiv paper: \(arxivID)"
        }
        return "Imported PDF"
    }

    private static func pdfProvenance(frontMatter: [String: String]) -> String {
        let source = normalizedPDFText(frontMatter["source"])
        let producer = source == "arxiv" ? "ArxivIngestService" : "LiteParsePDFImportController"
        let sourcePDF = boundedPDFText(normalizedPDFText(frontMatter["source_pdf"]), limit: 220)
        return [
            producer,
            source,
            normalizedPDFText(frontMatter["source_kind"]),
            normalizedPDFText(frontMatter["arxiv_id"]).isEmpty
                ? ""
                : "arxiv_id:\(normalizedPDFText(frontMatter["arxiv_id"]))",
            sourcePDF.isEmpty ? "" : "source_pdf:\(sourcePDF)",
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private static func pdfSearchTerms(from query: String?) -> [String] {
        var value = normalizedPDFQuery(query)
        for prefix in ["pdf:", "paper:", "arxiv:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        let stopWords: Set<String> = ["pdf", "pdfs", "paper", "papers", "arxiv", "note", "notes"]
        return value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private static func boundedPDFText(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        guard limit > 3 else { return String(value.prefix(limit)) }
        return String(value.prefix(limit - 3)) + "..."
    }

    private static func normalizedPDFQuery(_ value: String?) -> String {
        normalizedPDFText(value).lowercased()
    }

    private static func normalizedPDFText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedPDFText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
