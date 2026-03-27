import Foundation
import PDFKit
import SwiftData

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
    let classification: String  // prose / source_code / technical_docs / mixed_media
    let boilerplateRemoved: UInt64
}

struct ParsedDocument: Sendable, Identifiable {
    let id: UUID
    let sourcePageId: String?  // SDPage.id for provenance tracking (nil for filesystem-only)
    let sourceURL: URL?
    let fileType: DocumentFileType
    let rawText: String        // Original text
    let cleanedText: String    // After boilerplate filtering
    let metadata: DocumentMetadata
}

struct VaultParseResult: Sendable {
    let documents: [ParsedDocument]
    let errors: [(String, String)]  // (identifier, error message)
    let totalItems: Int
    let parsedItems: Int
}

// MARK: - VaultParser

actor VaultParser {

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]
    private static let textExtensions: Set<String> = ["txt", "text"]
    private static let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "ogg", "flac"]

    // MARK: - SDPage-based parsing (primary path for Knowledge Fusion)

    /// Parse all SDPages from SwiftData, applying Rust classifier + boilerplate filter.
    /// This is the main entry point for Knowledge Fusion's data ingestion.
    @MainActor
    func parsePages(_ pages: [SDPage]) -> VaultParseResult {
        var documents: [ParsedDocument] = []
        documents.reserveCapacity(pages.count)

        for page in pages {
            let body = page.loadBody()
            guard !body.isEmpty else { continue }

            // Classify via Rust FFI
            let classification = classifyDocument(content: body)

            // Filter boilerplate via Rust FFI
            let filtered = filterBoilerplate(content: body)

            let cleanedText = filtered.cleaned
            guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let wordCount = cleanedText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count

            let metadata = DocumentMetadata(
                title: page.title,
                createdAt: page.createdAt,
                modifiedAt: page.updatedAt,
                wordCount: wordCount,
                sourceVault: "SwiftData",
                classification: classification.docType,
                boilerplateRemoved: filtered.removedBytes
            )

            documents.append(ParsedDocument(
                id: UUID(),
                sourcePageId: page.id,
                sourceURL: page.filePath.flatMap { URL(fileURLWithPath: $0) },
                fileType: .markdown,
                rawText: body,
                cleanedText: cleanedText,
                metadata: metadata
            ))
        }

        return VaultParseResult(
            documents: documents,
            errors: [],
            totalItems: pages.count,
            parsedItems: documents.count
        )
    }

    // MARK: - Filesystem-based parsing (for vault directory import)

    func parseVault(at directoryURL: URL, vaultName: String? = nil) async -> VaultParseResult {
        let fm = FileManager.default
        let vault = vaultName ?? directoryURL.lastPathComponent

        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return VaultParseResult(documents: [], errors: [(directoryURL.path, "Cannot enumerate directory")], totalItems: 0, parsedItems: 0)
        }

        var fileURLs: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                fileURLs.append(item)
            }
        }

        var documents: [ParsedDocument] = []
        var errors: [(String, String)] = []

        for url in fileURLs {
            do {
                if let doc = try await parseFile(at: url, vault: vault) {
                    documents.append(doc)
                }
            } catch {
                errors.append((url.lastPathComponent, error.localizedDescription))
            }
        }

        return VaultParseResult(
            documents: documents,
            errors: errors,
            totalItems: fileURLs.count,
            parsedItems: documents.count
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
            rawText = ""
        }

        guard !rawText.isEmpty else {
            return ParsedDocument(
                id: UUID(),
                sourcePageId: nil,
                sourceURL: url,
                fileType: fileType,
                rawText: "",
                cleanedText: "",
                metadata: DocumentMetadata(
                    title: url.deletingPathExtension().lastPathComponent,
                    createdAt: nil, modifiedAt: nil, wordCount: 0,
                    sourceVault: vault, classification: "prose", boilerplateRemoved: 0
                )
            )
        }

        // Classify + filter via Rust FFI (must call on MainActor for UniFFI concurrency)
        let classification = await MainActor.run { classifyDocument(content: rawText) }
        let filtered = await MainActor.run { filterBoilerplate(content: rawText) }

        let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let wordCount = filtered.cleaned.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count

        let metadata = DocumentMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            createdAt: resourceValues?.creationDate,
            modifiedAt: resourceValues?.contentModificationDate,
            wordCount: wordCount,
            sourceVault: vault,
            classification: classification.docType,
            boilerplateRemoved: filtered.removedBytes
        )

        return ParsedDocument(
            id: UUID(),
            sourcePageId: nil,
            sourceURL: url,
            fileType: fileType,
            rawText: rawText,
            cleanedText: filtered.cleaned,
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
