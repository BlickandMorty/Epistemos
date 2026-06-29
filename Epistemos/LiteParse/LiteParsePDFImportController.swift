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

    enum Outcome: Equatable {
        case imported(pageID: String, title: String)
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

        let preparedImport = await Task.detached(priority: .userInitiated) {
            materializeImportedFiles(
                pdfPath: pdfPath,
                vaultURL: vaultURL,
                importer: importer
            )
        }.value
        guard case let .materialized(files) = preparedImport else {
            if case let .rejected(result) = preparedImport {
                return .rejected(result) // honest — no note created
            }
            return .rejected(.failed("PDF import failed."))
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
            try modelContext.save()
            graphState?.needsRefresh = true
            return .imported(pageID: page.id, title: page.title)
        } catch {
            modelContext.delete(page)
            try? FileManager.default.removeItem(at: files.noteURL)
            try? FileManager.default.removeItem(at: files.pdfURL)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.failed("Couldn't save the imported note: \(error.localizedDescription)"))
        }
    }

    nonisolated private static func materializeImportedFiles(
        pdfPath: String,
        vaultURL: URL,
        importer: LiteParsePDFImporter
    ) -> PreparedPDFImport {
        let result = importer.importToMarkdown(pdfPath: pdfPath)
        guard case let .markdown(markdown) = result else {
            return .rejected(result)
        }

        let baseName = ((pdfPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let title = baseName.isEmpty ? "Imported PDF" : baseName
        let dirURL = vaultURL.appendingPathComponent(importDirectory, isDirectory: true)
        var selectedURLs: (noteURL: URL, pdfURL: URL)?

        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            guard Plan3VaultPath.resolvesInsideVault(dirURL, in: vaultURL) else {
                return .rejected(.failed("Couldn't write the note file: \(Plan3VaultPath.outsideVaultMessage)"))
            }
            let urls = try Plan3ImportFileIO.reservePairedFileURLs(directory: dirURL, baseName: title)
            selectedURLs = urls
            guard
                let sourcePDFRelativePath = Plan3VaultPath.vaultRelativePath(for: urls.pdfURL, in: vaultURL),
                Plan3VaultPath.resolvesInsideVault(urls.noteURL, in: vaultURL),
                Plan3VaultPath.resolvesInsideVault(urls.pdfURL, in: vaultURL)
            else {
                return .rejected(.failed("Couldn't write the note file: \(Plan3VaultPath.outsideVaultMessage)"))
            }
            try Plan3ImportFileIO.copyFileContents(from: URL(fileURLWithPath: pdfPath), toReservedFile: urls.pdfURL)
            try Data(markdown.utf8).write(to: urls.noteURL, options: .atomic)
            return .materialized(
                LiteParseMaterializedImportFiles(
                    markdown: markdown,
                    noteURL: urls.noteURL,
                    pdfURL: urls.pdfURL,
                    sourcePDFRelativePath: sourcePDFRelativePath
                )
            )
        } catch {
            if let selectedURLs {
                try? FileManager.default.removeItem(at: selectedURLs.noteURL)
                try? FileManager.default.removeItem(at: selectedURLs.pdfURL)
            }
            return .rejected(.failed("Couldn't write the note file: \(error.localizedDescription)"))
        }
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
