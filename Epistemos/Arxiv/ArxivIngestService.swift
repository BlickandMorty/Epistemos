import Foundation
import SwiftData

nonisolated protocol ArxivPDFDownloading: Sendable {
    /// Returns a caller-owned temporary PDF file. `ArxivIngestService` removes it
    /// after copying it into the vault.
    func download(from url: URL) async throws -> URL
}

nonisolated struct URLSessionArxivPDFDownloader: ArxivPDFDownloading {
    func download(from url: URL) async throws -> URL {
        let (fileURL, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("HTTP \(http.statusCode)")
        }
        return try Self.prepareDownloadedPDF(from: fileURL)
    }

    static func prepareDownloadedPDF(from fileURL: URL) throws -> URL {
        switch LiteParsePDFSignature.fileStartsWithPDFMagic(fileURL.path) {
        case .match:
            break
        case .mismatch:
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded file is not a PDF (%PDF- header missing)")
        case .unreadable(let message):
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF: \(message)")
        }

        let pdfURL = fileURL.deletingPathExtension().appendingPathExtension("pdf")
        guard pdfURL.standardizedFileURL != fileURL.standardizedFileURL else {
            return fileURL
        }

        try? FileManager.default.removeItem(at: pdfURL)
        do {
            try FileManager.default.moveItem(at: fileURL, to: pdfURL)
            return pdfURL
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("could not prepare downloaded PDF: \(error.localizedDescription)")
        }
    }
}

nonisolated enum ArxivIngestError: LocalizedError, Equatable, Sendable {
    case downloadFailed(String)
    case pdfImportRejected(LiteParseImportResult)
    case fileWriteFailed(String)
    case modelSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "Could not download the arXiv PDF: \(message)"
        case .pdfImportRejected(let result):
            return "Could not convert the arXiv PDF: \(Self.reason(for: result))"
        case .fileWriteFailed(let message):
            return "Could not write the arXiv note: \(message)"
        case .modelSaveFailed(let message):
            return "Could not save the arXiv note: \(message)"
        }
    }

    private static func reason(for result: LiteParseImportResult) -> String {
        switch result {
        case .markdown:
            return "ok"
        case .notWired:
            return "PDF parser bridge is unavailable in this build."
        case .unsupported(let message), .failed(let message):
            return message
        }
    }
}

@MainActor
enum ArxivIngestService {
    nonisolated static let importDirectory = "arXiv"

    enum Outcome: Equatable {
        case imported(pageID: String, title: String)
        case rejected(ArxivIngestError)
    }

    static func ingest(
        paper: ArxivPaper,
        vaultURL: URL,
        modelContext: ModelContext,
        graphState: GraphState?,
        importer: LiteParsePDFImporter = LiveLiteParsePDFImporter(),
        downloader: ArxivPDFDownloading = URLSessionArxivPDFDownloader()
    ) async -> Outcome {
        let downloadedPDF: URL
        do {
            downloadedPDF = try await downloader.download(from: paper.pdfURL)
        } catch let error as ArxivIngestError {
            return .rejected(error)
        } catch {
            return .rejected(.downloadFailed(error.localizedDescription))
        }
        defer { try? FileManager.default.removeItem(at: downloadedPDF) }

        let parseResult = await Task.detached(priority: .userInitiated) {
            importer.importToMarkdown(pdfPath: downloadedPDF.path)
        }.value
        guard case .markdown(let markdown) = parseResult else {
            return .rejected(.pdfImportRejected(parseResult))
        }

        let note = ArxivNoteDraft(paper: paper, parsedMarkdown: markdown)
        let materializedFiles: MaterializedImportFiles
        do {
            materializedFiles = try await materializeImportedFiles(
                note: note,
                downloadedPDF: downloadedPDF,
                vaultURL: vaultURL)
        } catch let error as ArxivIngestError {
            return .rejected(error)
        } catch {
            return .rejected(.fileWriteFailed(error.localizedDescription))
        }

        let page = SDPage(title: materializedFiles.noteURL.deletingPathExtension().lastPathComponent, emoji: "📄")
        page.format = "markdown"
        page.filePath = materializedFiles.noteURL.standardizedFileURL.path
        page.subfolder = importDirectory
        page.saveBody(note.markdownBody)
        page.wordCount = note.markdownBody.split(whereSeparator: \.isWhitespace).count
        page.lastSyncedBodyHash = SDPage.bodyHash(note.markdownBody)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        var frontMatter = note.frontMatter
        frontMatter["source_pdf"] = materializedFiles.sourcePDFRelativePath
        page.frontMatter = frontMatter

        modelContext.insert(page)
        do {
            try modelContext.save()
            graphState?.needsRefresh = true
            return .imported(pageID: page.id, title: page.title)
        } catch {
            modelContext.delete(page)
            try? FileManager.default.removeItem(at: materializedFiles.noteURL)
            try? FileManager.default.removeItem(at: materializedFiles.pdfURL)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.modelSaveFailed(error.localizedDescription))
        }
    }

    private static func materializeImportedFiles(
        note: ArxivNoteDraft,
        downloadedPDF: URL,
        vaultURL: URL
    ) async throws -> MaterializedImportFiles {
        try await Task.detached(priority: .userInitiated) {
            let dirURL = vaultURL.appendingPathComponent(importDirectory, isDirectory: true)
            var selectedURLs: (noteURL: URL, pdfURL: URL)?

            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                guard Plan3VaultPath.resolvesInsideVault(dirURL, in: vaultURL) else {
                    throw ArxivIngestError.fileWriteFailed(Plan3VaultPath.outsideVaultMessage)
                }
                let urls = uniquePairedFileURLs(directory: dirURL, baseName: note.safeBaseName)
                selectedURLs = urls
                guard
                    let sourcePDFRelativePath = Plan3VaultPath.vaultRelativePath(for: urls.pdfURL, in: vaultURL),
                    Plan3VaultPath.resolvesInsideVault(urls.noteURL, in: vaultURL)
                else {
                    throw ArxivIngestError.fileWriteFailed(Plan3VaultPath.outsideVaultMessage)
                }
                try FileManager.default.copyItem(at: downloadedPDF, to: urls.pdfURL)
                try Data(note.markdownBody.utf8).write(to: urls.noteURL, options: .atomic)
                return MaterializedImportFiles(
                    noteURL: urls.noteURL,
                    pdfURL: urls.pdfURL,
                    sourcePDFRelativePath: sourcePDFRelativePath)
            } catch let error as ArxivIngestError {
                if let selectedURLs {
                    try? FileManager.default.removeItem(at: selectedURLs.noteURL)
                    try? FileManager.default.removeItem(at: selectedURLs.pdfURL)
                }
                throw error
            } catch {
                if let selectedURLs {
                    try? FileManager.default.removeItem(at: selectedURLs.noteURL)
                    try? FileManager.default.removeItem(at: selectedURLs.pdfURL)
                }
                throw ArxivIngestError.fileWriteFailed(error.localizedDescription)
            }
        }.value
    }

    nonisolated private static func uniquePairedFileURLs(directory: URL, baseName: String) -> (noteURL: URL, pdfURL: URL) {
        let safe = baseName.replacingOccurrences(of: "/", with: "-")
        var candidateBaseName = safe
        var counter = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(candidateBaseName).md").path)
            || FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(candidateBaseName).pdf").path) {
            candidateBaseName = "\(safe) \(counter)"
            counter += 1
        }
        return (
            noteURL: directory.appendingPathComponent("\(candidateBaseName).md"),
            pdfURL: directory.appendingPathComponent("\(candidateBaseName).pdf")
        )
    }

}

private struct MaterializedImportFiles: Sendable {
    let noteURL: URL
    let pdfURL: URL
    let sourcePDFRelativePath: String
}

nonisolated struct ArxivNoteDraft: Equatable, Sendable {
    let paper: ArxivPaper
    let parsedMarkdown: String

    var safeBaseName: String {
        let title = paper.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: " -")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortTitle = String(title.prefix(92)).trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = paper.shortID.isEmpty ? "arxiv" : paper.shortID
        return shortTitle.isEmpty ? suffix : "\(shortTitle) (\(suffix))"
    }

    var markdownBody: String {
        """
        # \(paper.title)

        arXiv: [\(paper.shortID)](\(paper.id))

        Authors: \(authorsLabel)

        Published: \(publishedLabel)

        Categories: \(categoriesLabel)

        PDF: \(paper.pdfURL.absoluteString)

        ## Abstract

        \(paper.summary)

        ## Parsed Full Text

        \(parsedMarkdown)
        """
    }

    var frontMatter: [String: String] {
        [
            "source": "arxiv",
            "source_kind": "pdf",
            "arxiv_id": paper.shortID,
            "authors": authorsLabel,
            "published": publishedLabel,
            "categories": categoriesLabel,
            "url": paper.id,
        ]
    }

    private var authorsLabel: String {
        paper.authors.joined(separator: "; ")
    }

    private var categoriesLabel: String {
        paper.categories.joined(separator: ", ")
    }

    private var publishedLabel: String {
        guard let published = paper.published else { return "" }
        return ISO8601DateFormatter.arxivIngest.string(from: published)
    }
}

private extension ISO8601DateFormatter {
    nonisolated static var arxivIngest: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
