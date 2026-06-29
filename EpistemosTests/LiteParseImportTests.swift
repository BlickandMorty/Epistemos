import Testing
import Foundation
import SwiftData
@testable import Epistemos

/// R-LITEPARSE — the PDF-import bridge: decodes the Rust `liteparse_pdf_to_markdown` FFI
/// JSON envelope into a typed result + the inert importer. This is the verifiable bridge
/// the note-sidebar import button uses; the live FFI call reuses this exact decoder.
@Suite("LiteParse PDF import (envelope decode + seam)")
struct LiteParseImportTests {

    @Test("decodes a success envelope to markdown")
    func decodesMarkdown() {
        // `##"…"##` so the `"#` inside `"# Title` doesn't close the raw string early.
        let result = LiteParseImportEnvelope.decode(##"{"ok":true,"markdown":"# Title\n\nbody"}"##)
        #expect(result == .markdown("# Title\n\nbody"))
        #expect(
            LiteParseImportEnvelope.decode(#"{"ok":true,"markdown":"   "}"#)
                == .failed(LiteParseImportEnvelope.emptyMarkdownMessage)
        )
        #expect(
            LiteParseImportEnvelope.decode(#"{"ok":true,"markdown":"*No content extracted.*"}"#)
                == .failed(LiteParseImportEnvelope.emptyMarkdownMessage)
        )
    }

    @Test("decodes the engine-not-wired error to .notWired")
    func decodesNotWired() {
        let result = LiteParseImportEnvelope.decode(#"{"ok":false,"error":"LiteParse PDF engine not wired"}"#)
        #expect(result == .notWired)
    }

    @Test("decodes an unsupported-format error to .unsupported")
    func decodesUnsupported() {
        let result = LiteParseImportEnvelope.decode(#"{"ok":false,"error":"unsupported format 'docx' — only PDF on the MAS path"}"#)
        guard case .unsupported = result else {
            Issue.record("expected .unsupported, got \(result)")
            return
        }
    }

    @Test("decodes a generic failure honestly")
    func decodesFailed() {
        let result = LiteParseImportEnvelope.decode(#"{"ok":false,"error":"page 3 is corrupt"}"#)
        #expect(result == .failed("page 3 is corrupt"))
    }

    @Test("unreadable output is an honest failure, never a fabricated note")
    func decodesGarbage() {
        let result = LiteParseImportEnvelope.decode("not json at all")
        guard case .failed = result else {
            Issue.record("expected .failed, got \(result)")
            return
        }
        // crucially NOT a markdown note
        if case .markdown = result { Issue.record("unreadable output must never decode to a note") }
    }

    @Test("the inert importer accepts PDF bytes without trusting extension")
    func inertImporter() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-signature-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let extensionlessPDF = root.appendingPathComponent("CFNetworkDownload_temp")
        try Data("%PDF-1.7\n".utf8).write(to: extensionlessPDF)
        let htmlNamedPDF = root.appendingPathComponent("paper.pdf")
        try Data("<html>not a paper</html>".utf8).write(to: htmlNamedPDF)

        let importer = InertLiteParsePDFImporter()
        #expect(importer.importToMarkdown(pdfPath: extensionlessPDF.path) == .notWired)
        #expect(importer.importToMarkdown(pdfPath: htmlNamedPDF.path) == .failed(LiteParsePDFSignature.invalidPDFBodyMessage))
        guard case .unsupported = importer.importToMarkdown(pdfPath: "/docs/book.docx") else {
            Issue.record("a non-PDF must be .unsupported (never shelled out)")
            return
        }
    }

    @Test("the live importer enforces PDF-only BEFORE the FFI (non-PDF never passed down)")
    func liveImporterRejectsNonPdf() {
        guard case .unsupported = LiveLiteParsePDFImporter().importToMarkdown(pdfPath: "/a/scan.png") else {
            Issue.record("a non-PDF must be .unsupported, never passed to the FFI")
            return
        }
    }

    @Test("the live importer is honest on a PDF when the FFI is absent")
    func liveImporterHonestOnPdf() throws {
        // Test host has no agent_coreFFI → the fallback. The linked app build exercises
        // the Rust EdgeParse/unpdf engine through the same envelope decoder.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-live-importer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let pdf = root.appendingPathComponent("paper.pdf")
        try Data("%PDF-1.7\n".utf8).write(to: pdf)
        #expect(LiveLiteParsePDFImporter().importToMarkdown(pdfPath: pdf.path) == .notWired)
    }

    @Test("import controller preserves the original PDF via frontmatter")
    func importControllerSourcePDFContract() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LiteParse/LiteParsePDFImportController.swift")
        let viewer = try loadMirroredSourceTextFile("Epistemos/LiteParse/SourcePDFViewer.swift")
        #expect(src.contains(#"frontMatter["source_kind"] = "pdf""#))
        #expect(src.contains(#"frontMatter["source_pdf"]"#))
        let sharedIO = try loadMirroredSourceTextFile("Epistemos/LiteParse/LiteParseImport.swift")
        #expect(src.contains("Plan3ImportFileIO.copyFileContents"))
        #expect(src.contains("Plan3ImportFileIO.writeData"))
        #expect(src.contains("Task.detached(priority: .userInitiated)"))
        #expect(src.contains("materializeImportedFiles"))
        #expect(src.contains("Plan3ImportFileIO.reservePairedFileURLs"))
        #expect(sharedIO.contains("O_NOFOLLOW"))
        #expect(sharedIO.contains("O_EXCL"))
        #expect(src.contains("Plan3VaultPath.vaultRelativePath(for: urls.pdfURL"))
        #expect(viewer.contains("maxSearchQueryLength"))
        #expect(viewer.contains("maxSearchResults"))
        #expect(viewer.contains("maxOutlineDepth"))
        #expect(viewer.contains("maxOutlineItems"))
        #expect(viewer.contains("maxOutlineNodes"))
        #expect(viewer.contains("visitedNodeCount"))
    }

    @Test("Plan 3 EdgeParse docs describe the shipped parser state")
    func plan3EdgeParseDocsDescribeShippedParserState() throws {
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_EDGEPARSE_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let cargo = try loadMirroredSourceTextFile("agent_core/Cargo.toml")
        let rust = try loadMirroredSourceTextFile("agent_core/src/liteparse.rs")

        #expect(codepack.contains("shipped code"))
        #expect(codepack.contains("agent_core/src/liteparse.rs"))
        #expect(codepack.contains(#"mas-build = ["edgeparse-pdf", "parser-unpdf"]"#))
        #expect(codepack.contains("source_pdf=<vault-relative path>"))
        #expect(codepack.contains("off-main import materialization, paired Markdown/PDF basenames"))
        #expect(capabilities.contains("PDF→Markdown import now has a real Plan 3 parser path"))
        #expect(capabilities.contains("test-linking condition, not the shipped MAS parser state"))
        #expect(cargo.contains(#"mas-build = ["edgeparse-pdf", "parser-unpdf"]"#))
        #expect(rust.contains("doc.source_path = None"))
        #expect(rust.contains("unpdf::Unpdf::new()"))

        for stale in [
            "clone-ready code",
            "[INFERRED] = bind at vendor time",
            "new `agent_core/src/pdf_parse.rs`",
            "mas-build=[]",
            "EdgeParse public API symbols are the integration seam",
        ] where codepack.contains(stale) {
            Issue.record("EdgeParse codepack still contains stale phrase: \(stale)")
        }
        for stale in [
            "you CANNOT parse a PDF→md",
            "NOT in `default`",
            "hidden behind\n`EPISTEMOS_LITEPARSE_PDF_V0`",
        ] where capabilities.contains(stale) {
            Issue.record("Plan 3 capabilities still contains stale phrase: \(stale)")
        }
    }

    @Test("PDF import preferences default to parse parsed-note flow")
    func importSettingsDefaults() {
        let suiteName = "LiteParseImportSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(LiteParseImportSettings.parsePDFOnImport(defaults: defaults))
        #expect(LiteParseImportSettings.defaultOpenForImportedPDF(defaults: defaults) == .parsedNote)
        defaults.set(false, forKey: LiteParseImportSettings.parsePDFOnImportKey)
        defaults.set("originalPDF", forKey: LiteParseImportSettings.defaultOpenForImportedPDFKey)
        #expect(!LiteParseImportSettings.parsePDFOnImport(defaults: defaults))
        #expect(LiteParseImportSettings.defaultOpenForImportedPDF(defaults: defaults) == .originalPDF)
    }

    @Test("source PDF links resolve only inside the vault")
    func sourcePDFLinksResolveOnlyInsideVault() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-source-pdf-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault", isDirectory: true)
        let imported = vault.appendingPathComponent("Imported PDFs", isDirectory: true)
        let pdf = imported.appendingPathComponent("paper.pdf")
        let htmlNamedPDF = imported.appendingPathComponent("rate-limit.pdf")
        let outside = root.appendingPathComponent("outside.pdf")
        let symlink = imported.appendingPathComponent("linked-outside.pdf")
        try FileManager.default.createDirectory(at: imported, withIntermediateDirectories: true)
        try Data("%PDF fake".utf8).write(to: pdf)
        try Data("<html>not a paper</html>".utf8).write(to: htmlNamedPDF)
        try Data("%PDF outside".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)
        defer { try? FileManager.default.removeItem(at: root) }

        let resolved = LiteParseSourcePDFLink.resolve(
            vaultURL: vault,
            relativePath: "Imported PDFs/paper.pdf"
        )
        #expect(resolved == pdf.standardizedFileURL)

        for rejected in [
            "",
            "/tmp/paper.pdf",
            "../outside.pdf",
            "Imported PDFs/../../outside.pdf",
            "Imported PDFs/missing.pdf",
            "Imported PDFs/rate-limit.pdf",
            "Imported PDFs/linked-outside.pdf",
        ] {
            #expect(LiteParseSourcePDFLink.resolve(vaultURL: vault, relativePath: rejected) == nil)
        }
    }

    @Test("import file reservation never creates hidden basename pairs")
    func importFileReservationAvoidsHiddenBaseNames() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-hidden-name-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let hidden = try Plan3ImportFileIO.reservePairedFileURLs(directory: root, baseName: ".hidden")
        #expect(hidden.noteURL.lastPathComponent == "hidden.md")
        #expect(hidden.pdfURL.lastPathComponent == "hidden.pdf")

        let empty = try Plan3ImportFileIO.reservePairedFileURLs(directory: root, baseName: ".")
        #expect(empty.noteURL.lastPathComponent == "Imported PDF.md")
        #expect(empty.pdfURL.lastPathComponent == "Imported PDF.pdf")
    }

    @Test("reserved import writes reject final symlink destinations")
    func reservedImportWritesRejectFinalSymlinkDestinations() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-final-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.pdf")
        let outside = root.appendingPathComponent("outside.txt")
        let pdfSymlink = root.appendingPathComponent("reserved.pdf")
        let markdownSymlink = root.appendingPathComponent("reserved.md")
        try Data("%PDF source".utf8).write(to: source)
        try Data("outside original".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: pdfSymlink, withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: markdownSymlink, withDestinationURL: outside)

        do {
            try Plan3ImportFileIO.copyFileContents(from: source, toReservedFile: pdfSymlink)
            Issue.record("Expected copied PDF write to reject a final symlink destination")
        } catch {}

        do {
            try Plan3ImportFileIO.writeData(Data("new markdown".utf8), toReservedFile: markdownSymlink)
            Issue.record("Expected markdown write to reject a final symlink destination")
        } catch {}

        let outsideText = try String(contentsOf: outside, encoding: .utf8)
        #expect(outsideText == "outside original")
    }

    @MainActor
    @Test("import controller keeps duplicate note and source PDF basenames paired")
    func importControllerKeepsDuplicateNoteAndSourcePDFBasenamesPaired() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-collision-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let importDir = vault.appendingPathComponent(LiteParsePDFImportController.importDirectory, isDirectory: true)
        let sourcePDF = root.appendingPathComponent("paper.pdf")
        try FileManager.default.createDirectory(at: importDir, withIntermediateDirectories: true)
        try Data("existing imported note".utf8).write(to: importDir.appendingPathComponent("paper.md"))
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let outcome = await LiteParsePDFImportController.importPage(
            pdfPath: sourcePDF.path,
            vaultURL: vault,
            modelContext: context,
            graphState: nil,
            importer: FakeLiteParseImporter(result: .markdown("# Parsed\n\nConverted body."))
        )

        guard case .imported = outcome else {
            Issue.record("Expected PDF import to create a note, got \(String(describing: outcome))")
            return
        }

        let page = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)
        let filePath = try #require(page.filePath)
        let noteBaseName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        let sourcePDFRelative = try #require(page.frontMatter["source_pdf"])
        let sourcePDFBaseName = vault
            .appendingPathComponent(sourcePDFRelative)
            .deletingPathExtension()
            .lastPathComponent
        let noteText = try String(contentsOfFile: filePath, encoding: .utf8)

        #expect(page.subfolder == LiteParsePDFImportController.importDirectory)
        #expect(page.frontMatter["source_kind"] == "pdf")
        #expect(sourcePDFRelative.hasPrefix("Imported PDFs/"))
        #expect(noteBaseName == "paper 2")
        #expect(sourcePDFBaseName == noteBaseName)
        #expect(noteText.contains("Converted body."))
        #expect(FileManager.default.fileExists(atPath: importDir.appendingPathComponent("paper 2.md").path))
        #expect(FileManager.default.fileExists(atPath: importDir.appendingPathComponent("paper 2.pdf").path))
    }

    @MainActor
    @Test("concurrent import controller writes distinct paired source PDFs")
    func concurrentImportControllerKeepsPairedFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-concurrent-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let sourcePDF = root.appendingPathComponent("paper.pdf")
        let importDir = vault.appendingPathComponent(LiteParsePDFImportController.importDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let importer = BarrierLiteParseImporter(expectedCalls: 2)

        let firstTask = Task { @MainActor in
            await LiteParsePDFImportController.importPage(
                pdfPath: sourcePDF.path,
                vaultURL: vault,
                modelContext: context,
                graphState: nil,
                importer: importer
            )
        }
        let secondTask = Task { @MainActor in
            await LiteParsePDFImportController.importPage(
                pdfPath: sourcePDF.path,
                vaultURL: vault,
                modelContext: context,
                graphState: nil,
                importer: importer
            )
        }

        let firstOutcome = await firstTask.value
        let secondOutcome = await secondTask.value
        guard case .imported = firstOutcome, case .imported = secondOutcome else {
            Issue.record("Expected both PDF imports to import, got \(firstOutcome) and \(secondOutcome)")
            return
        }

        let files = try FileManager.default.contentsOfDirectory(at: importDir, includingPropertiesForKeys: nil)
        let mdBases = Set(files.filter { $0.pathExtension == "md" }.map { $0.deletingPathExtension().lastPathComponent })
        let pdfBases = Set(files.filter { $0.pathExtension == "pdf" }.map { $0.deletingPathExtension().lastPathComponent })
        let pages = try context.fetch(FetchDescriptor<SDPage>())

        #expect(pages.count == 2)
        #expect(mdBases.count == 2)
        #expect(pdfBases.count == 2)
        #expect(mdBases == pdfBases)
        for page in pages {
            let filePath = try #require(page.filePath)
            let noteBaseName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
            let sourcePDFRelative = try #require(page.frontMatter["source_pdf"])
            let sourcePDFBaseName = vault
                .appendingPathComponent(sourcePDFRelative)
                .deletingPathExtension()
                .lastPathComponent
            #expect(noteBaseName == sourcePDFBaseName)
        }
    }

    @MainActor
    @Test("import controller rejects a symlinked import directory")
    func importControllerRejectsSymlinkedImportDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-symlink-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let outside = root.appendingPathComponent("Outside", isDirectory: true)
        let importLink = vault.appendingPathComponent(LiteParsePDFImportController.importDirectory, isDirectory: true)
        let sourcePDF = root.appendingPathComponent("paper.pdf")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: importLink, withDestinationURL: outside)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let outcome = await LiteParsePDFImportController.importPage(
            pdfPath: sourcePDF.path,
            vaultURL: vault,
            modelContext: context,
            graphState: nil,
            importer: FakeLiteParseImporter(result: .markdown("# Parsed\n\nConverted body."))
        )

        guard case .rejected(.failed(let message)) = outcome else {
            Issue.record("Expected symlinked import directory to be rejected, got \(String(describing: outcome))")
            return
        }

        #expect(message.contains(Plan3VaultPath.outsideVaultMessage))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("paper.md").path))
        #expect(!FileManager.default.fileExists(atPath: outside.appendingPathComponent("paper.pdf").path))
    }

    @MainActor
    @Test("cancelled import controller does not materialize a vault note")
    func importControllerCancellationDoesNotMaterializeVaultNote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-cancel-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let sourcePDF = root.appendingPathComponent("paper.pdf")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("%PDF fake".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let task = Task { @MainActor in
            await LiteParsePDFImportController.importPage(
                pdfPath: sourcePDF.path,
                vaultURL: vault,
                modelContext: context,
                graphState: nil,
                importer: SlowLiteParseImporter(delay: 0.12)
            )
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()

        let outcome = await task.value
        guard case .rejected(.failed(let message)) = outcome else {
            Issue.record("Expected cancelled import to be rejected, got \(String(describing: outcome))")
            return
        }

        #expect(message.localizedCaseInsensitiveContains("cancelled"))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: vault.appendingPathComponent(LiteParsePDFImportController.importDirectory).path))
    }
}

private struct FakeLiteParseImporter: LiteParsePDFImporter {
    let result: LiteParseImportResult

    func importToMarkdown(pdfPath _: String) -> LiteParseImportResult {
        result
    }
}

private final class BarrierLiteParseImporter: LiteParsePDFImporter, @unchecked Sendable {
    private let expectedCalls: Int
    private let lock = NSLock()
    private let release = DispatchSemaphore(value: 0)
    private var calls = 0

    init(expectedCalls: Int) {
        self.expectedCalls = expectedCalls
    }

    func importToMarkdown(pdfPath _: String) -> LiteParseImportResult {
        lock.lock()
        calls += 1
        let shouldRelease = calls == expectedCalls
        lock.unlock()

        if shouldRelease {
            for _ in 0..<expectedCalls {
                release.signal()
            }
        }
        _ = release.wait(timeout: .now() + .seconds(2))
        return .markdown("# Parsed\n\nConverted body.")
    }
}

private struct SlowLiteParseImporter: LiteParsePDFImporter {
    let delay: TimeInterval

    func importToMarkdown(pdfPath _: String) -> LiteParseImportResult {
        Thread.sleep(forTimeInterval: delay)
        return .markdown("# Parsed\n\nConverted after cancellation.")
    }
}
