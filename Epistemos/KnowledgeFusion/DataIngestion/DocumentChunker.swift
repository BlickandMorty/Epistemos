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
    let sourcePageId: String?  // SDPage.id for provenance
    let chunkIndex: Int
    let text: String
    let heading: String?
    let hierarchy: String      // Heading hierarchy path (e.g. "# Top > ## Sub > ### Detail")
    let estimatedTokenCount: Int
    let chunkType: ChunkType
}

/// Decoded chunk from Rust FFI JSON output.
private struct RustChunk: Decodable {
    let chunk_index: Int
    let text: String
    let heading: String
    let hierarchy: String
    let estimated_tokens: UInt64
}

// MARK: - DocumentChunker

/// Chunks parsed documents using the Rust-side markdown header chunker.
/// Markdown documents are chunked via `chunk_document()` FFI which splits on H1-H4
/// headers, preserves heading hierarchy, enforces 50-2048 token bounds, and uses
/// the dual-bound token estimator.
/// PDF/text documents use paragraph-based chunking (300-700 words).
struct DocumentChunker: Sendable {

    /// Target word range for non-markdown (paragraph-based) chunking.
    private let paragraphTargetMin: Int
    private let paragraphTargetMax: Int

    init(
        paragraphTargetMin: Int = 300,
        paragraphTargetMax: Int = 700
    ) {
        self.paragraphTargetMin = paragraphTargetMin
        self.paragraphTargetMax = paragraphTargetMax
    }

    // MARK: - Public

    func chunk(document: ParsedDocument) -> [TextChunk] {
        let text = document.cleanedText
        guard !text.isEmpty else { return [] }

        switch document.fileType {
        case .markdown:
            return chunkMarkdownViaRust(document: document)
        case .pdf:
            return chunkByParagraphs(document: document, chunkType: .pdf)
        case .text, .audio:
            if text.isEmpty { return [] }
            return chunkByParagraphs(document: document, chunkType: .paragraph)
        }
    }

    func chunkAll(documents: [ParsedDocument]) -> [TextChunk] {
        documents.flatMap { chunk(document: $0) }
    }

    // MARK: - Rust-backed Markdown Chunking

    /// Delegates to the Rust `chunk_document()` FFI for header-based splitting.
    private func chunkMarkdownViaRust(document: ParsedDocument) -> [TextChunk] {
        let result = chunkDocument(content: document.cleanedText)

        guard result.chunkCount > 0 else { return [] }

        // Decode JSON chunks from Rust
        guard let data = result.chunksJson.data(using: .utf8),
              let rustChunks = try? JSONDecoder().decode([RustChunk].self, from: data)
        else {
            // Fallback: return entire document as single chunk
            return [TextChunk(
                id: UUID(),
                documentId: document.id,
                sourcePageId: document.sourcePageId,
                chunkIndex: 0,
                text: document.cleanedText,
                heading: nil,
                hierarchy: "",
                estimatedTokenCount: Int(result.totalTokens),
                chunkType: .markdown
            )]
        }

        return rustChunks.map { rc in
            TextChunk(
                id: UUID(),
                documentId: document.id,
                sourcePageId: document.sourcePageId,
                chunkIndex: rc.chunk_index,
                text: rc.text,
                heading: rc.heading.isEmpty ? nil : rc.heading,
                hierarchy: rc.hierarchy,
                estimatedTokenCount: Int(rc.estimated_tokens),
                chunkType: .markdown
            )
        }
    }

    // MARK: - Paragraph Chunking (PDF / Plain Text)

    /// Splits on double-newline paragraph boundaries, targeting 300-700 words per chunk.
    private func chunkByParagraphs(document: ParsedDocument, chunkType: ChunkType) -> [TextChunk] {
        let text = document.cleanedText
        let paragraphs = text
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

        return chunks.enumerated().map { index, chunkText in
            TextChunk(
                id: UUID(),
                documentId: document.id,
                sourcePageId: document.sourcePageId,
                chunkIndex: index,
                text: chunkText,
                heading: nil,
                hierarchy: "",
                estimatedTokenCount: Int(estimateTokens(content:chunkText)),
                chunkType: chunkType
            )
        }
    }

    // MARK: - Helpers

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
