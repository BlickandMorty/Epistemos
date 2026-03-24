import Foundation

// MARK: - Types

enum ChunkType: String, Codable, Sendable {
    case markdown
    case pdf
    case paragraph
}

struct TextChunk: Sendable, Identifiable {
    let id: UUID
    let documentId: UUID
    let chunkIndex: Int
    let text: String
    let heading: String?
    let estimatedTokenCount: Int
    let chunkType: ChunkType
}

// MARK: - DocumentChunker

/// Chunks parsed documents using markdown-header-based splitting (NOT naive
/// recursive character splitting). Research paper mandates header-based chunking
/// because it preserves natural language boundaries.
struct DocumentChunker: Sendable {

    /// Maximum estimated tokens per chunk before splitting at paragraph boundaries.
    private let maxTokens: Int

    /// Minimum word count for a standalone chunk; shorter sections merge forward.
    private let minWords: Int

    /// Target word range for non-markdown (paragraph-based) chunking.
    private let paragraphTargetMin: Int
    private let paragraphTargetMax: Int

    init(
        maxTokens: Int = 1500,
        minWords: Int = 50,
        paragraphTargetMin: Int = 300,
        paragraphTargetMax: Int = 700
    ) {
        self.maxTokens = maxTokens
        self.minWords = minWords
        self.paragraphTargetMin = paragraphTargetMin
        self.paragraphTargetMax = paragraphTargetMax
    }

    // MARK: - Public

    func chunk(document: ParsedDocument) -> [TextChunk] {
        guard !document.rawText.isEmpty else { return [] }

        switch document.fileType {
        case .markdown:
            return chunkMarkdown(document: document)
        case .pdf:
            return chunkByParagraphs(document: document, chunkType: .pdf)
        case .text:
            return chunkByParagraphs(document: document, chunkType: .paragraph)
        case .audio:
            // Audio docs with transcribed text use paragraph chunking
            if document.rawText.isEmpty { return [] }
            return chunkByParagraphs(document: document, chunkType: .paragraph)
        }
    }

    func chunkAll(documents: [ParsedDocument]) -> [TextChunk] {
        documents.flatMap { chunk(document: $0) }
    }

    // MARK: - Markdown Header Chunking

    /// Splits on H2/H3/H4 markdown headings. Each chunk = heading + body until
    /// the next heading of equal or higher level.
    private func chunkMarkdown(document: ParsedDocument) -> [TextChunk] {
        let lines = document.rawText.components(separatedBy: .newlines)
        var rawSections: [(heading: String?, body: String)] = []
        var currentHeading: String? = nil
        var currentLines: [String] = []

        for line in lines {
            if isMarkdownHeading(line) {
                // Flush current section
                let body = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty || currentHeading != nil {
                    rawSections.append((heading: currentHeading, body: body))
                }
                currentHeading = line.trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }
        // Flush last section
        let lastBody = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastBody.isEmpty || currentHeading != nil {
            rawSections.append((heading: currentHeading, body: lastBody))
        }

        // Merge orphan sections (< minWords) with next section
        var merged = mergeOrphanSections(rawSections)

        // Split oversized sections at paragraph boundaries
        var finalSections: [(heading: String?, body: String)] = []
        for section in merged {
            let tokens = estimateTokens(section.body)
            if tokens > maxTokens {
                let splits = splitAtParagraphBoundaries(section.body, maxTokens: maxTokens)
                for (i, split) in splits.enumerated() {
                    let heading = i == 0 ? section.heading : section.heading.map { "\($0) (cont.)" }
                    finalSections.append((heading: heading, body: split))
                }
            } else {
                finalSections.append(section)
            }
        }

        // Remove any empty sections that slipped through
        merged = finalSections.filter { !$0.body.isEmpty }

        return merged.enumerated().map { index, section in
            let fullText: String
            if let heading = section.heading {
                fullText = "\(heading)\n\n\(section.body)"
            } else {
                fullText = section.body
            }
            return TextChunk(
                id: UUID(),
                documentId: document.id,
                chunkIndex: index,
                text: fullText,
                heading: section.heading,
                estimatedTokenCount: estimateTokens(fullText),
                chunkType: .markdown
            )
        }
    }

    // MARK: - Paragraph Chunking (PDF / Plain Text)

    /// Splits on double-newline paragraph boundaries, targeting 300-700 words per chunk.
    private func chunkByParagraphs(document: ParsedDocument, chunkType: ChunkType) -> [TextChunk] {
        let paragraphs = document.rawText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return [] }

        var chunks: [String] = []
        var currentParagraphs: [String] = []
        var currentWordCount = 0

        for paragraph in paragraphs {
            let words = wordCount(paragraph)
            if currentWordCount + words > paragraphTargetMax && currentWordCount >= paragraphTargetMin {
                // Flush current accumulation
                chunks.append(currentParagraphs.joined(separator: "\n\n"))
                currentParagraphs = [paragraph]
                currentWordCount = words
            } else {
                currentParagraphs.append(paragraph)
                currentWordCount += words
            }
        }
        if !currentParagraphs.isEmpty {
            chunks.append(currentParagraphs.joined(separator: "\n\n"))
        }

        return chunks.enumerated().map { index, text in
            TextChunk(
                id: UUID(),
                documentId: document.id,
                chunkIndex: index,
                text: text,
                heading: nil,
                estimatedTokenCount: estimateTokens(text),
                chunkType: chunkType
            )
        }
    }

    // MARK: - Helpers

    private func isMarkdownHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Match ## through #### (H2, H3, H4). Skip H1 (single #) as it's typically the doc title.
        return trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") || trimmed.hasPrefix("#### ")
    }

    private func mergeOrphanSections(_ sections: [(heading: String?, body: String)]) -> [(heading: String?, body: String)] {
        guard sections.count > 1 else { return sections }

        var result: [(heading: String?, body: String)] = []
        var i = 0
        while i < sections.count {
            let section = sections[i]
            let words = wordCount(section.body)

            if words < minWords && i + 1 < sections.count {
                // Merge with next section
                let next = sections[i + 1]
                let mergedBody: String
                if section.body.isEmpty {
                    mergedBody = next.body
                } else {
                    mergedBody = section.body + "\n\n" + next.body
                }
                let mergedHeading = section.heading ?? next.heading
                result.append((heading: mergedHeading, body: mergedBody))
                i += 2
            } else {
                result.append(section)
                i += 1
            }
        }
        return result
    }

    private func splitAtParagraphBoundaries(_ text: String, maxTokens: Int) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n")
        var splits: [String] = []
        var current: [String] = []
        var currentTokens = 0

        for paragraph in paragraphs {
            let tokens = estimateTokens(paragraph)
            if currentTokens + tokens > maxTokens && !current.isEmpty {
                splits.append(current.joined(separator: "\n\n"))
                current = [paragraph]
                currentTokens = tokens
            } else {
                current.append(paragraph)
                currentTokens += tokens
            }
        }
        if !current.isEmpty {
            splits.append(current.joined(separator: "\n\n"))
        }
        return splits
    }

    /// Estimate token count: ~1.3 tokens per word (conservative for English text).
    func estimateTokens(_ text: String) -> Int {
        let words = wordCount(text)
        let estimate = Double(words) * 1.3
        guard estimate.isFinite else { return 0 }
        return Int(estimate)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
