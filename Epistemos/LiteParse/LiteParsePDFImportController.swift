import Foundation
import SwiftData

// R-LITEPARSE — import a PDF as a Markdown note (owner 2026-06-19). Converts the PDF via
// the live liteparse FFI importer; on a real markdown result it creates an SDPage note
// in the vault by MIRRORING the proven file-first pattern of CodeFileCreationController
// (write the .md into the vault, then an SDPage with filePath + needsVaultSync=false) so
// it never guesses the vault-sync contract. HONEST: a non-PDF / not-wired / failed
// conversion creates NO note and returns the reason — never a fake/empty note. Real
// markdown (and so a real note) arrives once S2's native PDFium vendor lands; until then
// the engine returns `.notWired`.
@MainActor
enum LiteParsePDFImportController {
    static let importDirectory = "Imported PDFs"

    enum Outcome: Equatable {
        case imported(pageID: String, title: String)
        case rejected(LiteParseImportResult)
    }

    static func importPage(
        pdfPath: String,
        vaultURL: URL,
        modelContext: ModelContext,
        graphState: GraphState?,
        importer: LiteParsePDFImporter = LiveLiteParsePDFImporter()
    ) -> Outcome {
        let result = importer.importToMarkdown(pdfPath: pdfPath)
        guard case let .markdown(markdown) = result else {
            return .rejected(result) // honest — no note created
        }

        let baseName = ((pdfPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let title = baseName.isEmpty ? "Imported PDF" : baseName

        // File-first (mirrors CodeFileCreationController): write the .md into the vault.
        let dirURL = vaultURL.appendingPathComponent(importDirectory, isDirectory: true)
        let fileURL = uniqueFileURL(directory: dirURL, baseName: title)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            try Data(markdown.utf8).write(to: fileURL, options: .atomic)
        } catch {
            return .rejected(.failed("Couldn't write the note file: \(error.localizedDescription)"))
        }

        let page = SDPage(title: fileURL.deletingPathExtension().lastPathComponent, emoji: "📄")
        page.format = "markdown"
        page.filePath = fileURL.standardizedFileURL.path
        page.subfolder = importDirectory
        page.saveBody(markdown)
        page.wordCount = markdown.split(whereSeparator: \.isWhitespace).count
        page.lastSyncedBodyHash = SDPage.bodyHash(markdown)
        page.lastSyncedAt = .now
        page.needsVaultSync = false

        modelContext.insert(page)
        do {
            try modelContext.save()
            graphState?.needsRefresh = true
            return .imported(pageID: page.id, title: page.title)
        } catch {
            modelContext.delete(page)
            try? FileManager.default.removeItem(at: fileURL)
            NoteFileStorage.deleteBody(pageId: page.id)
            return .rejected(.failed("Couldn't save the imported note: \(error.localizedDescription)"))
        }
    }

    /// A non-colliding `<baseName>.md` (then `<baseName> 2.md`, …) in `directory`.
    private static func uniqueFileURL(directory: URL, baseName: String) -> URL {
        let safe = baseName.replacingOccurrences(of: "/", with: "-")
        var candidate = directory.appendingPathComponent("\(safe).md")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(safe) \(counter).md")
            counter += 1
        }
        return candidate
    }
}
