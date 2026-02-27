import Foundation
import os

// MARK: - Citation Extractor
// Parses citations, references, URLs, and DOIs from LLM responses and notes.
// Used by chat completion hooks and note scanning to auto-populate the research library.
//
// Extraction strategy (priority order):
// 1. Structured reference sections (## Sources & References, ## References, etc.)
// 2. Numbered/bulleted reference lists anywhere in text
// 3. Inline DOIs (doi.org/... or DOI: ...)
// 4. Inline URLs to known academic domains (arxiv, scholar, pubmed, etc.)

enum CitationExtractor {

    // MARK: - Public API

    /// Extract citations from text and return SavedPaper objects ready for the library.
    /// `source` identifies origin: "chat", "minichat", "note-scan", "research".
    /// `originChatId` / `originNoteTitle` optionally stamp provenance for library navigation.
    static func extract(from text: String, source: String,
                        originChatId: String? = nil, originNoteTitle: String? = nil) -> [SavedPaper] {
        var results: [SavedPaper] = []

        // 1. Parse structured reference section
        results.append(contentsOf: parseReferenceSection(text, source: source,
                                                          originChatId: originChatId,
                                                          originNoteTitle: originNoteTitle))

        // 2. Extract standalone DOIs not already captured
        let doiPapers = extractDOIs(text, source: source,
                                     originChatId: originChatId, originNoteTitle: originNoteTitle)
        for paper in doiPapers {
            if !results.contains(where: { $0.doi == paper.doi }) {
                results.append(paper)
            }
        }

        // 3. Extract academic URLs not already captured
        let urlPapers = extractAcademicURLs(text, source: source,
                                             originChatId: originChatId, originNoteTitle: originNoteTitle)
        for paper in urlPapers {
            if !results.contains(where: { $0.url == paper.url }) {
                results.append(paper)
            }
        }

        // Deduplicate by normalized title
        var seen = Set<String>()
        results = results.filter { paper in
            let key = paper.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        Log.research.info("📚 CitationExtractor: found \(results.count) citations from \(source, privacy: .public)")
        return results
    }

    // MARK: - Reference Section Parser

    /// Finds sections like "## Sources & References" or "## References" and parses list items.
    private static func parseReferenceSection(_ text: String, source: String,
                                               originChatId: String? = nil,
                                               originNoteTitle: String? = nil) -> [SavedPaper] {
        // Match heading patterns: ## Sources, ## References, **Sources**, etc.
        let headingPattern = #"(?:^|\n)(?:#{1,3}\s+|(?:\*\*))(?:Sources?(?:\s*(?:&|and)\s*References?)?|References?|Bibliography|Works?\s*Cited)(?:\*\*)?[:\s]*\n"#
        guard let headingRange = text.range(of: headingPattern, options: .regularExpression) else {
            return []
        }

        // Extract everything after the heading until the next heading or end of text
        let afterHeading = String(text[headingRange.upperBound...])
        let sectionEnd = afterHeading.range(of: #"\n#{1,3}\s+"#, options: .regularExpression)
        let section = if let sectionEnd {
            String(afterHeading[..<sectionEnd.lowerBound])
        } else {
            afterHeading
        }

        // Parse each list item (-, *, numbered)
        let lines = section.components(separatedBy: "\n")
        var papers: [SavedPaper] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip empty lines and non-list lines
            guard !trimmed.isEmpty else { continue }
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•")
                    || trimmed.first?.isNumber == true
            else { continue }

            // Strip list marker
            var content = trimmed
            if let dotRange = content.range(of: #"^[\d]+[.)]\s*"#, options: .regularExpression) {
                content = String(content[dotRange.upperBound...])
            } else if content.hasPrefix("-") || content.hasPrefix("*") || content.hasPrefix("•") {
                content = String(content.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            guard !content.isEmpty else { continue }

            let paper = parseReferenceLine(content, source: source,
                                             originChatId: originChatId, originNoteTitle: originNoteTitle)
            papers.append(paper)
        }

        return papers
    }

    /// Parse a single reference line into a SavedPaper.
    /// Handles common formats:
    ///   - Author(s) (Year). "Title." Journal. DOI/URL
    ///   - [Title](URL) — Author, Year
    ///   - Title. Author et al., Year
    private static func parseReferenceLine(_ line: String, source: String,
                                              originChatId: String? = nil,
                                              originNoteTitle: String? = nil) -> SavedPaper {
        var title = ""
        var authors = ""
        var year: String?
        var doi: String?
        var url: String?

        // Extract URL if present
        if let urlMatch = line.range(of: #"https?://[^\s\)\]>]+"#, options: .regularExpression) {
            url = String(line[urlMatch])
            // Check if URL is a DOI
            if let url, let doiPart = url.range(of: #"doi\.org/(.+)"#, options: .regularExpression) {
                doi = String(url[doiPart.lowerBound...])
            }
        }

        // Extract DOI if present (standalone)
        if doi == nil, let doiMatch = line.range(of: #"(?:DOI:\s*|doi:\s*)?(10\.\d{4,}/[^\s,;]+)"#, options: .regularExpression) {
            doi = String(line[doiMatch])
        }

        // Extract year (4-digit number between 1900-2099)
        if let yearMatch = line.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) {
            year = String(line[yearMatch])
        }

        // Try markdown link format: [Title](URL)
        if let linkMatch = line.range(of: #"\[([^\]]+)\]\(([^\)]+)\)"#, options: .regularExpression) {
            let linkText = String(line[linkMatch])
            if let titleRange = linkText.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
                let raw = String(linkText[titleRange])
                title = String(raw.dropFirst().dropLast()) // Remove [ ]
            }
            if url == nil, let urlRange = linkText.range(of: #"\(([^\)]+)\)"#, options: .regularExpression) {
                let raw = String(linkText[urlRange])
                url = String(raw.dropFirst().dropLast()) // Remove ( )
            }
        }

        // Try quoted title: "Title" or "Title"
        if title.isEmpty,
           let quoteMatch = line.range(of: #"[""\u{201C}]([^""\u{201D}]+)[""\u{201D}]"#, options: .regularExpression) {
            let raw = String(line[quoteMatch])
            title = String(raw.dropFirst().dropLast())
        }

        // Try italic title: *Title*
        if title.isEmpty,
           let italicMatch = line.range(of: #"\*([^*]+)\*"#, options: .regularExpression) {
            let raw = String(line[italicMatch])
            title = String(raw.dropFirst().dropLast())
        }

        // Fallback: use the entire line (cleaned) as title
        if title.isEmpty {
            // Strip URL, DOI, year from the line and use remainder
            var cleaned = line
            if let urlRange = url.flatMap({ cleaned.range(of: $0) }) {
                cleaned.removeSubrange(urlRange)
            }
            // Remove markdown link syntax
            cleaned = cleaned.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
            cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;-–—")))
            title = cleaned.isEmpty ? line : cleaned
        }

        // Extract authors: text before year or before title in quotes
        let beforeTitle = line.components(separatedBy: title).first ?? ""
        let authorCandidate = beforeTitle
            .replacingOccurrences(of: #"\(\d{4}\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;-–—()")))
        if !authorCandidate.isEmpty && authorCandidate.count < 200 {
            authors = authorCandidate
        }

        // Clean up title
        title = title
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;\"'*")))

        return SavedPaper(
            title: title,
            authors: authors,
            year: year,
            doi: doi,
            url: url,
            source: source,
            originChatId: originChatId,
            originNoteTitle: originNoteTitle
        )
    }

    // MARK: - DOI Extraction

    private static func extractDOIs(_ text: String, source: String,
                                      originChatId: String? = nil,
                                      originNoteTitle: String? = nil) -> [SavedPaper] {
        let doiPattern = #"(?:https?://(?:dx\.)?doi\.org/|DOI:\s*|doi:\s*)(10\.\d{4,}/[^\s,;\]\)]+)"#
        guard let regex = try? NSRegularExpression(pattern: doiPattern, options: .caseInsensitive) else { return [] }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let doiRange = match.range(at: 1)
            let doi = nsText.substring(with: doiRange)
            return SavedPaper(
                title: "DOI: \(doi)",
                authors: "",
                doi: doi,
                url: "https://doi.org/\(doi)",
                source: source,
                originChatId: originChatId,
                originNoteTitle: originNoteTitle
            )
        }
    }

    // MARK: - Academic URL Extraction

    private static let academicDomains = [
        "arxiv.org", "scholar.google", "pubmed.ncbi", "doi.org",
        "semanticscholar.org", "jstor.org", "springer.com", "nature.com",
        "sciencedirect.com", "wiley.com", "researchgate.net", "ssrn.com",
        "ncbi.nlm.nih.gov", "ieee.org", "acm.org", "plos.org",
    ]

    private static func extractAcademicURLs(_ text: String, source: String,
                                              originChatId: String? = nil,
                                              originNoteTitle: String? = nil) -> [SavedPaper] {
        let urlPattern = #"https?://[^\s\)\]>,\"']+"#
        guard let regex = try? NSRegularExpression(pattern: urlPattern) else { return [] }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.compactMap { match in
            let urlStr = nsText.substring(with: match.range)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
            guard academicDomains.contains(where: { urlStr.contains($0) }) else { return nil }
            // Try to extract a readable title from the URL path
            let title = readableTitleFromURL(urlStr) ?? urlStr
            return SavedPaper(
                title: title,
                authors: "",
                url: urlStr,
                source: source,
                originChatId: originChatId,
                originNoteTitle: originNoteTitle
            )
        }
    }

    /// Attempt to extract a readable title from an academic URL path.
    private static func readableTitleFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let lastComponent = url.lastPathComponent
        guard !lastComponent.isEmpty, lastComponent != "/" else { return nil }
        // Convert dashes/underscores to spaces, drop file extensions
        var title = lastComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        if let dotRange = title.range(of: #"\.[a-z]{2,4}$"#, options: .regularExpression) {
            title = String(title[..<dotRange.lowerBound])
        }
        return title.isEmpty ? nil : title
    }
}
