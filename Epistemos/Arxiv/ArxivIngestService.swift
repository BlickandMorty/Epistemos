import Darwin
import Foundation
import os
import SwiftData

// ARX-IDX-1 (audit 2026-07-04): diagnostics for the best-effort post-ingest search-index upsert.
private let arxivIngestLog = Logger(subsystem: "com.epistemos.app", category: "arxiv-ingest")

nonisolated protocol ArxivPDFDownloading: Sendable {
    /// Returns a caller-owned temporary PDF file. `ArxivIngestService` removes it
    /// after copying it into the vault.
    func download(from url: URL) async throws -> URL
}

nonisolated struct URLSessionArxivPDFDownloader: ArxivPDFDownloading {
    static let maxDownloadedPDFBytes = 128 * 1024 * 1024

    // RES-3 (audit 2026-07-03): the PDF download used `URLSession.shared`, whose default
    // `timeoutIntervalForResource` is 7 days — a stalled or trickling arXiv response could
    // keep an ingest row spinning effectively forever (the metadata fetch in ArxivClient
    // already caps at 15s, so this was an inconsistency). A dedicated ephemeral session
    // bounds it: 60s idle-between-bytes cap + a 300s hard ceiling per download. The enforced
    // 128 MiB max PDF still fits a slow-but-live link (~3.5 Mbps) inside that ceiling; a
    // stalled one now fails fast. Task cancellation still cancels the in-flight transfer.
    private static let downloadSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = false
        config.urlCache = nil
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }()

    func download(from url: URL) async throws -> URL {
        guard let downloadURL = ArxivPDFURLPolicy.normalizedAllowedURL(url) else {
            throw ArxivIngestError.downloadFailed(ArxivPDFURLPolicy.rejectedMessage)
        }

        let (fileURL, response) = try await Self.downloadSession.download(from: downloadURL)
        try Self.validateDownloadResponse(response, requestURL: downloadURL, downloadedFileURL: fileURL)
        return try Self.prepareDownloadedPDF(from: fileURL)
    }

    static func validateDownloadResponse(
        _ response: URLResponse,
        requestURL: URL,
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
              Self.isExpectedPDFResponse(finalURL, requestURL: requestURL) else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed(ArxivPDFURLPolicy.rejectedFinalURLMessage)
        }
    }

    private static func isExpectedPDFResponse(_ responseURL: URL, requestURL: URL) -> Bool {
        guard ArxivPDFURLPolicy.isAllowedHTTPSResponse(responseURL),
              let normalizedResponse = ArxivPDFURLPolicy.normalizedAllowedURL(responseURL),
              let normalizedRequest = ArxivPDFURLPolicy.normalizedAllowedURL(requestURL) else {
            return false
        }
        return normalizedResponse.absoluteString == normalizedRequest.absoluteString
    }

    static func prepareDownloadedPDF(from fileURL: URL) throws -> URL {
        try validateDownloadedPDF(fileURL)

        let pdfURL = preparedPDFURL(for: fileURL)
        guard pdfURL.standardizedFileURL != fileURL.standardizedFileURL else {
            return fileURL
        }

        do {
            try FileManager.default.moveItem(at: fileURL, to: pdfURL)
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed(
                "could not prepare downloaded PDF: \(ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "filesystem error"))"
            )
        }
        do {
            try validateDownloadedPDF(pdfURL)
            return pdfURL
        } catch {
            try? FileManager.default.removeItem(at: pdfURL)
            throw error
        }
    }

    private static func validateDownloadedPDF(_ fileURL: URL) throws {
        try validateDownloadedFileEnvelope(fileURL)
        switch LiteParsePDFSignature.fileStartsWithPDFMagic(fileURL.path) {
        case .match:
            return
        case .mismatch:
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded file is not a PDF (%PDF- header missing)")
        case .unreadable(let message):
            try? FileManager.default.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF: \(message)")
        }
    }

    private static func preparedPDFURL(for fileURL: URL) -> URL {
        guard fileURL.pathExtension.caseInsensitiveCompare("pdf") != .orderedSame else {
            return fileURL
        }
        let directoryURL = fileURL.deletingLastPathComponent()
        let rawBaseName = fileURL.deletingPathExtension().lastPathComponent
        let baseName = rawBaseName.isEmpty ? "download" : rawBaseName
        return directoryURL.appendingPathComponent("\(baseName)-\(UUID().uuidString).pdf", isDirectory: false)
    }

    private static func validateDownloadedFileEnvelope(_ fileURL: URL) throws {
        let fileManager = FileManager.default
        if (try? fileManager.destinationOfSymbolicLink(atPath: fileURL.path)) != nil {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded file is not a regular file")
        }

        let fd = fileURL.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            let capturedErrno = errno
            try? fileManager.removeItem(at: fileURL)
            if capturedErrno == ELOOP {
                throw ArxivIngestError.downloadFailed("downloaded file is not a regular file")
            }
            let message = String(cString: strerror(capturedErrno))
            throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF: \(message)")
        }
        defer { _ = close(fd) }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let capturedErrno = errno
            try? fileManager.removeItem(at: fileURL)
            let message = String(cString: strerror(capturedErrno))
            throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF: \(message)")
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded file is not a regular file")
        }
        guard fileStatus.st_nlink == 1 else {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded file is not a regular file")
        }
        guard fileStatus.st_size >= 0 else {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("could not inspect downloaded PDF size")
        }
        guard UInt64(fileStatus.st_size) <= UInt64(maxDownloadedPDFBytes) else {
            try? fileManager.removeItem(at: fileURL)
            throw ArxivIngestError.downloadFailed("downloaded PDF exceeds 128 MiB limit")
        }
    }
}

nonisolated enum ArxivIngestDiagnostics {
    static let maxFailureReasonCharacters = 360

    static func failureReason(_ message: String, fallback: String) -> String {
        let bounded = String(message.prefix(maxFailureReasonCharacters + 32))
        let trimmed = ArxivSearchDiagnostics.normalizedDisplayText(bounded)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmed.isEmpty ? fallback : trimmed
        guard description.count > maxFailureReasonCharacters else {
            return description
        }
        return (String(description.prefix(maxFailureReasonCharacters - 3)) + "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func externalErrorDescription(_ error: Error, fallback: String) -> String {
        let nsError = error as NSError
        let domain = ArxivSearchDiagnostics.safeDomain(nsError.domain)
        return failureReason("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
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
            return "Could not download the arXiv PDF: \(ArxivIngestDiagnostics.failureReason(message, fallback: "download failed"))"
        case .pdfImportRejected(let result):
            return "Could not convert the arXiv PDF: \(Self.reason(for: result))"
        case .fileWriteFailed(let message):
            return "Could not write the arXiv note: \(ArxivIngestDiagnostics.failureReason(message, fallback: "file write failed"))"
        case .modelSaveFailed(let message):
            return "Could not save the arXiv note: \(ArxivIngestDiagnostics.failureReason(message, fallback: "model save failed"))"
        }
    }

    private static func reason(for result: LiteParseImportResult) -> String {
        switch result {
        case .markdown:
            return "ok"
        case .notWired:
            return "PDF parser bridge is unavailable in this build."
        case .unsupported(let message), .failed(let message):
            return ArxivIngestDiagnostics.failureReason(message, fallback: "PDF import failed")
        }
    }
}

@MainActor
enum ArxivIngestService {
    nonisolated static let importDirectory = "arXiv"

    enum Outcome: Equatable {
        case imported(pageID: String, title: String, sourcePDFRelativePath: String)
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
            return .rejected(.downloadFailed(
                ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "download failed")
            ))
        }
        defer { try? FileManager.default.removeItem(at: downloadedPDF) }

        let parseResult: LiteParseImportResult
        do {
            try Task.checkCancellation()
            // RES-2 (audit 2026-07-03): bound the synchronous, uncancellable liteparse FFI so a
            // pathological/corrupt PDF can't hang the ingest row forever — on timeout the parse
            // is abandoned (runs to completion off-task and is discarded) and we reject cleanly.
            parseResult = try await LiteParsePDFConversion.importToMarkdown(
                using: importer,
                pdfPath: downloadedPDF.path)
            try Task.checkCancellation()
        } catch is CancellationError {
            return .rejected(.cancelled)
        } catch is LiteParsePDFConversion.TimedOut {
            return .rejected(.pdfImportRejected(.failed(
                "arXiv PDF conversion timed out — the file may be corrupt or unusually complex."
            )))
        } catch {
            return .rejected(.pdfImportRejected(.failed(
                ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "PDF import failed")
            )))
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
            return .rejected(.fileWriteFailed(
                ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "file write failed")
            ))
        }

        let page = SDPage(title: materializedFiles.noteURL.deletingPathExtension().lastPathComponent, emoji: "📄")
        page.format = "markdown"
        page.filePath = materializedFiles.noteURL.standardizedFileURL.path
        page.subfolder = importDirectory
        page.updateBodyDerivedState(from: note.markdownBody)
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

        // DATA-IMPORT-1 (unbounded pass): import into a DEDICATED child context so its save()
        // flushes ONLY the imported page — never a concurrent editor's unsaved edit that happens
        // to be pending in the shared context, and a mid-import save-failure can't orphan pages
        // or drop that edit. The new page is still visible to the shared context's @Query via the
        // store. UNVERIFIED headless: the race + cross-context visibility need an in-app import
        // spot-check before trusting.
        let importContext = ModelContext(modelContext.container)
        importContext.autosaveEnabled = false
        importContext.insert(page)
        do {
            try importContext.save()
            graphState?.needsRefresh = true
            // GAP-1 (audit 2026-07-03): imports set needsVaultSync=false, which skips the
            // export-path search index — so a saved paper is unfindable in content search
            // until relaunch. Index it directly now (saveBody wrote the body sync).
            if let searchService = AppBootstrap.shared?.vaultSync.searchService {
                // ARX-IDX-1 (audit 2026-07-04): use the markdown already in hand instead of a
                // synchronous body-file disk read here (this runs on @MainActor, and the body was
                // written to disk milliseconds ago — the read is redundant); and log on
                // failure instead of swallowing it with try? (a silent failure re-opens the GAP-1
                // symptom — the paper is unfindable in content search until relaunch/reindex).
                do {
                    try searchService.upsert(
                        id: page.id,
                        title: page.title,
                        body: note.markdownBody,
                        tags: page.tags.joined(separator: " "),
                        updatedAt: page.updatedAt
                    )
                } catch {
                    arxivIngestLog.warning("arXiv note search-index upsert failed: \(error, privacy: .public)")
                }
            }
            SpotlightIndexer.index(page)  // INT-3: donate to Spotlight too (macOS system search)
            // GAP-RECALL-1 (audit 2026-07-04): imports also skip the vault-sync export path that
            // indexes notes into instant/ambient recall (VaultSyncService), so an imported paper
            // wasn't recallable until a rebuild. Index it now — same lineage as GAP-1 (FTS) + INT-3
            // (Spotlight); the body is in hand (no extra disk read).
            AppBootstrap.shared?.instantRecallService.indexNote(noteId: page.id, text: note.markdownBody)
            // FSRS (opt-in): enroll the imported paper into spaced-repetition review IF the user
            // turned it on in Settings. OFF by default — auto-enrolling every import is a product
            // choice, so it's gated on epistemos.fsrs.autoEnroll (default false).
            if UserDefaults.standard.bool(forKey: "epistemos.fsrs.autoEnroll") {
                _ = await FSRSDecayStore.shared.ensure(noteId: page.id)
            }
            return .imported(
                pageID: page.id,
                title: page.title,
                sourcePDFRelativePath: materializedFiles.sourcePDFRelativePath
            )
        } catch {
            importContext.delete(page)
            removeMaterializedFiles(materializedFiles)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.modelSaveFailed(
                ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "model save failed")
            ))
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
                throw ArxivIngestError.fileWriteFailed(
                    ArxivIngestDiagnostics.externalErrorDescription(error, fallback: "file write failed")
                )
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
    static let maxTitleCharacters = 512
    static let maxAbstractCharacters = 8 * 1024
    static let maxAuthorsLabelCharacters = 2_048
    static let maxCategoriesLabelCharacters = 512
    static let maxSourceURLCharacters = 512

    let paper: ArxivPaper
    let parsedMarkdown: String

    var safeBaseName: String {
        let title = titleLabel
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: " -")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortTitle = String(title.prefix(92)).trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = paper.shortID.isEmpty ? "arxiv" : paper.shortID
        return shortTitle.isEmpty ? suffix : "\(shortTitle) (\(suffix))"
    }

    var markdownBody: String {
        """
        # \(titleLabel)

        arXiv: [\(paper.shortID)](\(sourceURLLabel))

        Authors: \(authorsLabel)

        Published: \(publishedLabel)

        Categories: \(categoriesLabel)

        PDF: \(pdfURLLabel)

        ## Abstract

        \(summaryLabel)

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
            "url": sourceURLLabel,
        ]
    }

    private var titleLabel: String {
        Self.bounded(paper.title, limit: Self.maxTitleCharacters, fallback: "Untitled arXiv paper")
    }

    private var summaryLabel: String {
        Self.bounded(paper.summary, limit: Self.maxAbstractCharacters, fallback: "")
    }

    private var authorsLabel: String {
        Self.bounded(
            Self.normalizedListLabel(paper.authors, separator: "; "),
            limit: Self.maxAuthorsLabelCharacters,
            fallback: ""
        )
    }

    private var categoriesLabel: String {
        Self.bounded(
            Self.normalizedListLabel(paper.categories, separator: ", "),
            limit: Self.maxCategoriesLabelCharacters,
            fallback: ""
        )
    }

    private var publishedLabel: String {
        guard let published = paper.published else { return "" }
        return ISO8601DateFormatter.arxivIngest.string(from: published)
    }

    private var sourceURLLabel: String {
        Self.bounded(paper.id, limit: Self.maxSourceURLCharacters, fallback: "")
    }

    private var pdfURLLabel: String {
        Self.bounded(paper.pdfURL.absoluteString, limit: Self.maxSourceURLCharacters, fallback: "")
    }

    private static func bounded(_ value: String, limit: Int, fallback: String) -> String {
        let bounded = String(value.prefix(limit + 32))
        let trimmed = ArxivSearchDiagnostics.normalizedDisplayText(bounded)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmed.isEmpty ? fallback : trimmed
        guard description.count > limit else { return description }
        return (String(description.prefix(limit - 3)) + "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedListLabel(_ values: [String], separator: String) -> String {
        values
            .map {
                ArxivSearchDiagnostics.normalizedDisplayText($0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}

private extension ISO8601DateFormatter {
    // ARX-PERF-2 (audit 2026-07-04): static LET (was a computed var that allocated a formatter per
    // access). ISO8601DateFormatter parse is thread-safe; nonisolated(unsafe) matches the pattern.
    nonisolated(unsafe) static let arxivIngest: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
