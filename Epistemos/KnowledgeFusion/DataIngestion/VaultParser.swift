import Foundation
import PDFKit

// MARK: - Types

enum DocumentFileType: String, Codable, Sendable {
    case markdown
    case pdf
    case text
    case audio
}

struct DocumentMetadata: Sendable {
    let title: String
    let createdAt: Date?
    let modifiedAt: Date?
    let wordCount: Int
    let sourceVault: String
}

struct ParsedDocument: Sendable, Identifiable {
    let id: UUID
    let sourceURL: URL
    let fileType: DocumentFileType
    let rawText: String
    let metadata: DocumentMetadata
}

struct VaultParseResult: Sendable {
    let documents: [ParsedDocument]
    let errors: [(URL, String)]
    let totalFiles: Int
    let parsedFiles: Int
}

// MARK: - VaultParser

actor VaultParser {

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]
    private static let textExtensions: Set<String> = ["txt", "text"]
    private static let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "ogg", "flac"]

    func parseVault(at directoryURL: URL, vaultName: String? = nil) async -> VaultParseResult {
        let fm = FileManager.default
        let vault = vaultName ?? directoryURL.lastPathComponent

        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return VaultParseResult(documents: [], errors: [(directoryURL, "Cannot enumerate directory")], totalFiles: 0, parsedFiles: 0)
        }

        var fileURLs: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                fileURLs.append(item)
            }
        }

        var documents: [ParsedDocument] = []
        var errors: [(URL, String)] = []

        for url in fileURLs {
            do {
                if let doc = try await parseFile(at: url, vault: vault) {
                    documents.append(doc)
                }
            } catch {
                errors.append((url, error.localizedDescription))
            }
        }

        return VaultParseResult(
            documents: documents,
            errors: errors,
            totalFiles: fileURLs.count,
            parsedFiles: documents.count
        )
    }

    private func parseFile(at url: URL, vault: String) async throws -> ParsedDocument? {
        let ext = url.pathExtension.lowercased()
        let fileType = classifyExtension(ext)

        guard let fileType else { return nil }

        let rawText: String
        switch fileType {
        case .markdown, .text:
            rawText = try String(contentsOf: url, encoding: .utf8)
        case .pdf:
            rawText = try extractPDFText(from: url)
        case .audio:
            // Audio files are returned with empty rawText;
            // AudioTranscriber handles transcription separately.
            rawText = ""
        }

        let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let wordCount = rawText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count

        let metadata = DocumentMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            createdAt: resourceValues?.creationDate,
            modifiedAt: resourceValues?.contentModificationDate,
            wordCount: wordCount,
            sourceVault: vault
        )

        return ParsedDocument(
            id: UUID(),
            sourceURL: url,
            fileType: fileType,
            rawText: rawText,
            metadata: metadata
        )
    }

    private func classifyExtension(_ ext: String) -> DocumentFileType? {
        if Self.markdownExtensions.contains(ext) { return .markdown }
        if Self.textExtensions.contains(ext) { return .text }
        if ext == "pdf" { return .pdf }
        if Self.audioExtensions.contains(ext) { return .audio }
        return nil
    }

    private func extractPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw VaultParserError.pdfLoadFailed(url)
        }
        var pages: [String] = []
        pages.reserveCapacity(document.pageCount)
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let text = page.string {
                pages.append(text)
            }
        }
        return pages.joined(separator: "\n\n")
    }
}

enum VaultParserError: Error, LocalizedError {
    case pdfLoadFailed(URL)

    var errorDescription: String? {
        switch self {
        case .pdfLoadFailed(let url):
            return "Failed to load PDF: \(url.lastPathComponent)"
        }
    }
}
