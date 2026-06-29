import Foundation
import SwiftData

nonisolated protocol ArxivPDFDownloading: Sendable {
    /// Returns a caller-owned temporary PDF file. `ArxivIngestService` removes it
    /// after copying it into the vault.
    func download(from url: URL) async throws -> URL
}

nonisolated struct URLSessionArxivPDFDownloader: ArxivPDFDownloading {
    static let maxDownloadedPDFBytes = 128 * 1024 * 1024

    func download(from url: URL) async throws -> URL {
        guard let downloadURL = ArxivPDFURLPolicy.normalizedAllowedURL(url) else {
            throw ArxivIngestError.downloadFailed(ArxivPDFURLPolicy.rejectedMessage)
        }

        let (fileURL, response) = try await URLSession.shared.download(from: downloadURL)
        try Self.validateDownloadResponse(response, downloadedFileURL: fileURL)
        return try Self.prepareDownloadedPDF(from: fileURL)
    }

    static func validateDownloadResponse(
        _ response: URLResponse,
        downloadedFileURL fileURL: URL
    ) throws {
        guard let http = response as? HTTPURLResponse else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("download response was not HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("HTTP \(http.statusCode)")
        }
        guard let finalURL = http.url,
              ArxivPDFURLPolicy.isAllowedHTTPSResponse(finalURL) else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed(ArxivPDFURLPolicy.rejectedFinalURLMessage)
        }
    }

    static func prepareDownloadedPDF(from fileURL: URL) throws -> URL {
        try validateDownloadedFileEnvelope(fileURL)
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

    private static func validateDownloadedFileEnvelope(_ fileURL: URL) throws {
        let fileManager = FileManager.default
        if (try? fileManager.destinationOfSymbolicLink(atPath: fileURL.path)) != nil {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded file is not a regular file")
        }

        do {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                try? fileManager.removeItem(at: fileURL)
                throw ArxivIngestError.downloadFailed("downloaded file is not a regular file")
            }
            guard let fileSize = values.fileSize else {
                try? fileManager.removeItem(at: fileURL)
                throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF size")
            }
            guard fileSize <= maxDownloadedPDFBytes else {
                try? fileManager.removeItem(at: fileURL)
                throw ArxivIngestError.downloadFailed("downloaded PDF exceeds 128 MiB limit")
            }
        } catch let error as ArxivIngestError {
            throw error
        } catch {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF: \(error.localizedDescription)")
        }
    }
}

nonisolated enum ArxivIngestError: LocalizedError, Equatable, Sendable {
    case cancelled
    case downloadFailed(String)
    case pdfImportRejected(LiteParseImportResult)
    case fileWriteFailed(String)
    case modelSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "arXiv ingest was cancelled."
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
            try Task.checkCancellation()
            downloadedPDF = try await downloader.download(from: paper.pdfURL)
        } catch is CancellationError {
            return .rejected(.cancelled)
        } catch let error as ArxivIngestError {
            return .rejected(error)
        } catch {
            return .rejected(.downloadFailed(error.localizedDescription))
        }
        defer { try? FileManager.default.removeItem(at: downloadedPDF) }

        let parseResult: LiteParseImportResult
        do {
            try Task.checkCancellation()
            parseResult = try await runDetachedCancellable {
                try Task.checkCancellation()
                return importer.importToMarkdown(pdfPath: downloadedPDF.path)
            }
            try Task.checkCancellation()
        } catch is CancellationError {
            return .rejected(.cancelled)
        } catch {
            return .rejected(.pdfImportRejected(.failed(error.localizedDescription)))
        }
        guard case .markdown(let markdown) = parseResult else {
            return .rejected(.pdfImportRejected(parseResult))
        }

        let note = ArxivNoteDraft(paper: paper, parsedMarkdown: markdown)
        let materializedFiles: MaterializedImportFiles
        do {
            try Task.checkCancellation()
            materializedFiles = try await materializeImportedFiles(
                note: note,
                downloadedPDF: downloadedPDF,
                vaultURL: vaultURL)
            try Task.checkCancellation()
        } catch is CancellationError {
            return .rejected(.cancelled)
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

        do {
            try Task.checkCancellation()
        } catch {
            removeMaterializedFiles(materializedFiles)
            return .rejected(.cancelled)
        }

        modelContext.insert(page)
        do {
            try modelContext.save()
            graphState?.needsRefresh = true
            return .imported(pageID: page.id, title: page.title)
        } catch {
            modelContext.delete(page)
            removeMaterializedFiles(materializedFiles)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.modelSaveFailed(error.localizedDescription))
        }
    }

    private static func materializeImportedFiles(
        note: ArxivNoteDraft,
        downloadedPDF: URL,
        vaultURL: URL
    ) async throws -> MaterializedImportFiles {
        try await runDetachedCancellable {
            let dirURL = vaultURL.appendingPathComponent(importDirectory, isDirectory: true)
            var selectedURLs: (noteURL: URL, pdfURL: URL)?

            do {
                try Task.checkCancellation()
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                guard Plan3VaultPath.resolvesInsideVault(dirURL, in: vaultURL) else {
                    throw ArxivIngestError.fileWriteFailed(Plan3VaultPath.outsideVaultMessage)
                }
                try Task.checkCancellation()
                let urls = try Plan3ImportFileIO.reservePairedFileURLs(directory: dirURL, baseName: note.safeBaseName)
                selectedURLs = urls
                guard
                    let sourcePDFRelativePath = Plan3VaultPath.vaultRelativePath(for: urls.pdfURL, in: vaultURL),
                    Plan3VaultPath.resolvesInsideVault(urls.noteURL, in: vaultURL),
                    Plan3VaultPath.resolvesInsideVault(urls.pdfURL, in: vaultURL)
                else {
                    throw ArxivIngestError.fileWriteFailed(Plan3VaultPath.outsideVaultMessage)
                }
                try Task.checkCancellation()
                try Plan3ImportFileIO.copyFileContents(from: downloadedPDF, toReservedFile: urls.pdfURL)
                try Task.checkCancellation()
                try Plan3ImportFileIO.writeData(Data(note.markdownBody.utf8), toReservedFile: urls.noteURL)
                try Task.checkCancellation()
                return MaterializedImportFiles(
                    noteURL: urls.noteURL,
                    pdfURL: urls.pdfURL,
                    sourcePDFRelativePath: sourcePDFRelativePath)
            } catch is CancellationError {
                if let selectedURLs {
                    removeMaterializedURLs(noteURL: selectedURLs.noteURL, pdfURL: selectedURLs.pdfURL)
                }
                throw CancellationError()
            } catch let error as ArxivIngestError {
                if let selectedURLs {
                    removeMaterializedURLs(noteURL: selectedURLs.noteURL, pdfURL: selectedURLs.pdfURL)
                }
                throw error
            } catch {
                if let selectedURLs {
                    removeMaterializedURLs(noteURL: selectedURLs.noteURL, pdfURL: selectedURLs.pdfURL)
                }
                throw ArxivIngestError.fileWriteFailed(error.localizedDescription)
            }
        }
    }

    nonisolated private static func runDetachedCancellable<Value: Sendable>(
        priority: TaskPriority = .userInitiated,
        operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let task = Task.detached(priority: priority) {
            try operation()
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    nonisolated private static func removeMaterializedFiles(_ files: MaterializedImportFiles) {
        removeMaterializedURLs(noteURL: files.noteURL, pdfURL: files.pdfURL)
    }

    nonisolated private static func removeMaterializedURLs(noteURL: URL, pdfURL: URL) {
        try? FileManager.default.removeItem(at: noteURL)
        try? FileManager.default.removeItem(at: pdfURL)
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
