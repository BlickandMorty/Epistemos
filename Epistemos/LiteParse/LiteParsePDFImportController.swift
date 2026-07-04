import Foundation
import SwiftData

// R-LITEPARSE — import a PDF as a Markdown note (owner 2026-06-19). Converts the PDF via
// the live liteparse FFI importer; on a real markdown result it creates an SDPage note
// in the vault by MIRRORING the proven file-first pattern of CodeFileCreationController
// (write the .md into the vault, then an SDPage with filePath + needsVaultSync=false) so
// it never guesses the vault-sync contract. HONEST: a non-PDF / not-wired / failed
// conversion creates NO note and returns the reason — never a fake/empty note. Real
// markdown (and so a real note) arrives from the Plan 3 EdgeParse/unpdf parser stack.
@MainActor
enum LiteParsePDFImportController {
    nonisolated static let importDirectory = "Imported PDFs"
    nonisolated private static let cancelledMessage = "PDF import was cancelled."

    enum Outcome: Equatable {
        case imported(pageID: String, title: String, sourcePDFRelativePath: String)
        case rejected(LiteParseImportResult)
    }

    static func importPage(
        pdfPath: String,
        vaultURL: URL,
        modelContext: ModelContext,
        graphState: GraphState?,
        importer: LiteParsePDFImporter = LiveLiteParsePDFImporter(),
        parsePDFOnImport: Bool = LiteParseImportSettings.parsePDFOnImport()
    ) async -> Outcome {
        guard parsePDFOnImport else {
            return .rejected(.failed("PDF parsing is disabled in Settings. The original PDF was not converted."))
        }

        let preparedImport: PreparedPDFImport
        do {
            try Task.checkCancellation()
            preparedImport = try await runDetachedCancellable {
                try materializeImportedFiles(
                    pdfPath: pdfPath,
                    vaultURL: vaultURL,
                    importer: importer
                )
            }
        } catch is CancellationError {
            return .rejected(.failed(Self.cancelledMessage))
        } catch {
            return .rejected(.failed(LiteParseImportDiagnostics.failureMessage("PDF import failed", error: error)))
        }
        guard case let .materialized(files) = preparedImport else {
            if case let .rejected(result) = preparedImport {
                return .rejected(result) // honest — no note created
            }
            return .rejected(.failed("PDF import failed."))
        }

        do {
            try Task.checkCancellation()
        } catch {
            removeMaterializedFiles(files)
            return .rejected(.failed(Self.cancelledMessage))
        }

        let page = SDPage(title: files.noteURL.deletingPathExtension().lastPathComponent, emoji: "📄")
        page.format = "markdown"
        page.filePath = files.noteURL.standardizedFileURL.path
        page.subfolder = importDirectory
        page.saveBody(files.markdown)
        page.wordCount = files.markdown.split(whereSeparator: \.isWhitespace).count
        page.lastSyncedBodyHash = SDPage.bodyHash(files.markdown)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        var frontMatter = page.frontMatter
        frontMatter["source_kind"] = "pdf"
        frontMatter["source_pdf"] = files.sourcePDFRelativePath
        page.frontMatter = frontMatter

        modelContext.insert(page)
        do {
            try Task.checkCancellation()
            try modelContext.save()
            graphState?.needsRefresh = true
            // GAP-1 (audit 2026-07-03): imports set needsVaultSync=false, which skips the
            // export-path search index — so the imported note is unfindable in content
            // search until relaunch. Index it directly now (saveBody wrote the body sync).
            if let searchService = AppBootstrap.shared?.vaultSync.searchService {
                try? searchService.upsert(
                    id: page.id,
                    title: page.title,
                    body: NoteFileStorage.readBody(pageId: page.id),
                    tags: page.tags.joined(separator: " "),
                    updatedAt: page.updatedAt
                )
            }
            SpotlightIndexer.index(page)  // INT-3: donate to Spotlight too (macOS system search)
            return .imported(
                pageID: page.id,
                title: page.title,
                sourcePDFRelativePath: files.sourcePDFRelativePath
            )
        } catch is CancellationError {
            modelContext.delete(page)
            removeMaterializedFiles(files)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.failed(Self.cancelledMessage))
        } catch {
            modelContext.delete(page)
            removeMaterializedFiles(files)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.failed(LiteParseImportDiagnostics.failureMessage("Couldn't save the imported note", error: error)))
        }
    }

    nonisolated private static func materializeImportedFiles(
        pdfPath: String,
        vaultURL: URL,
        importer: LiteParsePDFImporter
    ) throws -> PreparedPDFImport {
        try Task.checkCancellation()
        if let failure = LiteParsePDFSignature.validationFailure(forPath: pdfPath) {
            return .rejected(failure)
        }

        let baseName = ((pdfPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let title = baseName.isEmpty ? "Imported PDF" : baseName
        let dirURL = vaultURL.appendingPathComponent(importDirectory, isDirectory: true)
        var selectedURLs: (noteURL: URL, pdfURL: URL)?
        var createdImportDirectory = false
        var keepMaterializedFiles = false
        defer {
            if !keepMaterializedFiles {
                if let selectedURLs {
                    removeMaterializedURLs(noteURL: selectedURLs.noteURL, pdfURL: selectedURLs.pdfURL)
                }
                if createdImportDirectory {
                    try? FileManager.default.removeItem(at: dirURL)
                }
            }
        }

        do {
            try Task.checkCancellation()
            let importDirectoryExisted = FileManager.default.fileExists(atPath: dirURL.path)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            createdImportDirectory = !importDirectoryExisted
            guard Plan3VaultPath.resolvesInsideVault(dirURL, in: vaultURL) else {
                return .rejected(.failed("Couldn't write the note file: \(Plan3VaultPath.outsideVaultMessage)"))
            }
            try Task.checkCancellation()
            let urls = try Plan3ImportFileIO.reservePairedFileURLs(directory: dirURL, baseName: title)
            selectedURLs = urls
            guard
                let sourcePDFRelativePath = Plan3VaultPath.vaultRelativePath(for: urls.pdfURL, in: vaultURL),
                Plan3VaultPath.resolvesInsideVault(urls.noteURL, in: vaultURL),
                Plan3VaultPath.resolvesInsideVault(urls.pdfURL, in: vaultURL)
            else {
                return .rejected(.failed("Couldn't write the note file: \(Plan3VaultPath.outsideVaultMessage)"))
            }
            try Task.checkCancellation()
            try Plan3ImportFileIO.copyFileContents(from: URL(fileURLWithPath: pdfPath), toReservedFile: urls.pdfURL)
            try Task.checkCancellation()
            let result = importer.importToMarkdown(pdfPath: urls.pdfURL.path)
            try Task.checkCancellation()
            guard case let .markdown(markdown) = result else {
                return .rejected(result)
            }
            try Plan3ImportFileIO.writeData(Data(markdown.utf8), toReservedFile: urls.noteURL)
            try Task.checkCancellation()
            keepMaterializedFiles = true
            return .materialized(
                LiteParseMaterializedImportFiles(
                    markdown: markdown,
                    noteURL: urls.noteURL,
                    pdfURL: urls.pdfURL,
                    sourcePDFRelativePath: sourcePDFRelativePath
                )
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .rejected(.failed(LiteParseImportDiagnostics.failureMessage("Couldn't write the note file", error: error)))
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

    nonisolated private static func removeMaterializedFiles(_ files: LiteParseMaterializedImportFiles) {
        removeMaterializedURLs(noteURL: files.noteURL, pdfURL: files.pdfURL)
    }

    nonisolated private static func removeMaterializedURLs(noteURL: URL, pdfURL: URL) {
        try? FileManager.default.removeItem(at: noteURL)
        try? FileManager.default.removeItem(at: pdfURL)
    }

}

private enum PreparedPDFImport: Sendable {
    case materialized(LiteParseMaterializedImportFiles)
    case rejected(LiteParseImportResult)
}

private struct LiteParseMaterializedImportFiles: Sendable {
    let markdown: String
    let noteURL: URL
    let pdfURL: URL
    let sourcePDFRelativePath: String
}
