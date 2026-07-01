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

        let oversizedMarkdown = String(
            repeating: "m",
            count: LiteParseImportEnvelope.maxMarkdownCharacters + 1
        )
        #expect(
            LiteParseImportEnvelope.decode(#"{"ok":true,"markdown":""# + oversizedMarkdown + #""}"#)
                == .failed(LiteParseImportEnvelope.markdownTooLargeMessage)
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

        let oversizedError = String(
            repeating: "e",
            count: LiteParseImportEnvelope.maxErrorMessageCharacters + 37
        )
        let boundedError = String(oversizedError.prefix(LiteParseImportEnvelope.maxErrorMessageCharacters))
        #expect(
            LiteParseImportEnvelope.decode(#"{"ok":false,"error":""# + oversizedError + #""}"#)
                == .failed(boundedError)
        )
    }

    @Test("import diagnostics redact path-leaking external errors")
    func importDiagnosticsRedactPathLeakingExternalErrors() {
        let privatePath = "/private/var/folders/secret/paper.pdf"
        let error = NSError(
            domain: privatePath,
            code: 13,
            userInfo: [NSLocalizedDescriptionKey: "permission denied while opening \(privatePath)"]
        )
        let message = LiteParseImportDiagnostics.failureMessage("PDF import failed", error: error)
        let inspection = LiteParseImportDiagnostics.inspectionFailure(error)

        #expect(message.contains("PDF import failed"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=13"))
        #expect(message.count <= LiteParseImportDiagnostics.maxFailureReasonCharacters)
        #expect(!message.contains(privatePath))
        #expect(!message.contains("permission denied"))
        #expect(!inspection.contains(privatePath))
        #expect(!inspection.contains("permission denied"))

        let longDomain = String(repeating: "d", count: 200)
        let longDomainMessage = LiteParseImportDiagnostics.failureMessage(
            "PDF import failed",
            error: NSError(domain: longDomain, code: 7)
        )
        #expect(longDomainMessage.contains("domain=\(String(longDomain.prefix(96)))"))
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

        let oversizedEnvelope = String(
            repeating: "{",
            count: LiteParseImportEnvelope.maxEnvelopeCharacters + 1
        )
        #expect(
            LiteParseImportEnvelope.decode(oversizedEnvelope)
                == .failed(LiteParseImportEnvelope.envelopeTooLargeMessage)
        )
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
        let explicitTextFile = root.appendingPathComponent("paper.txt")
        try Data("%PDF-1.7\n".utf8).write(to: explicitTextFile)

        let importer = InertLiteParsePDFImporter()
        #expect(importer.importToMarkdown(pdfPath: extensionlessPDF.path) == .notWired)
        #expect(importer.importToMarkdown(pdfPath: htmlNamedPDF.path) == .failed(LiteParsePDFSignature.invalidPDFBodyMessage))
        guard case .unsupported = importer.importToMarkdown(pdfPath: explicitTextFile.path) else {
            Issue.record("an explicit non-PDF extension must stay unsupported even if the file body has PDF magic")
            return
        }
        guard case .unsupported = importer.importToMarkdown(pdfPath: "/docs/book.docx") else {
            Issue.record("a non-PDF must be .unsupported (never shelled out)")
            return
        }
    }

    @Test("the Swift PDF preflight rejects unsafe local PDF paths before FFI")
    func swiftPDFPreflightRejectsUnsafeLocalPDFPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-preflight-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let emptyPDF = root.appendingPathComponent("empty.pdf")
        try Data().write(to: emptyPDF)

        let oversizedPDF = root.appendingPathComponent("oversized.pdf")
        try Data("%PDF-1.7\n".utf8).write(to: oversizedPDF)
        let oversizedHandle = try FileHandle(forWritingTo: oversizedPDF)
        defer { try? oversizedHandle.close() }
        try oversizedHandle.truncate(atOffset: UInt64(LiteParsePDFSignature.maxPDFBytes + 1))

        let targetPDF = root.appendingPathComponent("target.pdf")
        let symlinkPDF = root.appendingPathComponent("linked.pdf")
        let hardlinkedPDF = root.appendingPathComponent("hardlinked.pdf")
        try Data("%PDF-1.7\n".utf8).write(to: targetPDF)
        try FileManager.default.createSymbolicLink(at: symlinkPDF, withDestinationURL: targetPDF)
        let hardlinkSupported = (try? FileManager.default.linkItem(at: targetPDF, to: hardlinkedPDF)) != nil

        let importer = InertLiteParsePDFImporter()
        #expect(importer.importToMarkdown(pdfPath: emptyPDF.path) == .failed(LiteParsePDFSignature.emptyPDFMessage))
        #expect(importer.importToMarkdown(pdfPath: oversizedPDF.path) == .failed(LiteParsePDFSignature.tooLargePDFMessage))
        #expect(importer.importToMarkdown(pdfPath: symlinkPDF.path) == .failed(LiteParsePDFSignature.nonRegularPDFMessage))
        if hardlinkSupported {
            #expect(importer.importToMarkdown(pdfPath: hardlinkedPDF.path) == .failed(LiteParsePDFSignature.nonRegularPDFMessage))
        }

        guard case .unreadable = LiteParsePDFSignature.fileStartsWithPDFMagic(symlinkPDF.path) else {
            Issue.record("PDF magic helper must reject a final symlink without following it")
            return
        }
        if hardlinkSupported {
            guard case .unreadable(LiteParsePDFSignature.nonRegularPDFMessage) = LiteParsePDFSignature.fileStartsWithPDFMagic(hardlinkedPDF.path) else {
                Issue.record("PDF magic helper must reject a hardlinked source PDF")
                return
            }
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
        let affordance = try loadMirroredSourceTextFile("Epistemos/LiteParse/ViewOriginalPDFAffordance.swift")
        #expect(src.contains(#"frontMatter["source_kind"] = "pdf""#))
        #expect(src.contains(#"frontMatter["source_pdf"]"#))
        #expect(src.contains("sourcePDFRelativePath: files.sourcePDFRelativePath"))
        let sharedIO = try loadMirroredSourceTextFile("Epistemos/LiteParse/LiteParseImport.swift")
        #expect(src.contains("Plan3ImportFileIO.copyFileContents"))
        #expect(src.contains("Plan3ImportFileIO.writeData"))
        #expect(src.contains("LiteParsePDFSignature.validationFailure(forPath: pdfPath)"))
        #expect(src.contains("importer.importToMarkdown(pdfPath: urls.pdfURL.path)"))
        #expect(!src.contains("importer.importToMarkdown(pdfPath: pdfPath)"))
        #expect(src.contains("LiteParseImportDiagnostics.failureMessage"))
        #expect(!src.contains("error.localizedDescription"))
        #expect(src.contains("Task.detached(priority: .userInitiated)"))
        #expect(src.contains("materializeImportedFiles"))
        #expect(src.contains("Plan3ImportFileIO.reservePairedFileURLs"))
        #expect(sharedIO.contains("openValidatedPDFForReading"))
        #expect(sharedIO.contains("LiteParseImportDiagnostics.inspectionFailure"))
        #expect(!sharedIO.contains("error.localizedDescription"))
        #expect(sharedIO.contains("O_RDONLY | O_NOFOLLOW | O_CLOEXEC"))
        #expect(sharedIO.contains("seek(toOffset: 0)"))
        #expect(sharedIO.contains("O_NOFOLLOW"))
        #expect(sharedIO.contains("O_EXCL"))
        #expect(sharedIO.contains("maxPDFBytes"))
        #expect(sharedIO.contains("pathExtension.caseInsensitiveCompare(\"pdf\")"))
        #expect(sharedIO.contains("maxMarkdownCharacters"))
        #expect(sharedIO.contains("maxEnvelopeCharacters"))
        #expect(sharedIO.contains("maxErrorMessageCharacters"))
        #expect(sharedIO.contains("String(domain.prefix(maxDomainCharacters + 16))"))
        #expect(sharedIO.contains("String(message.prefix(maxFailureReasonCharacters + 32))"))
        #expect(sharedIO.contains("maxFailureReasonCharacters - 3"))
        #expect(sharedIO.contains("let boundedJSON = String(json.prefix(maxEnvelopeCharacters + 1))"))
        #expect(sharedIO.contains("String(error.prefix(maxErrorMessageCharacters + 32))"))
        #expect(sharedIO.contains("destinationOfSymbolicLink"))
        #expect(sharedIO.contains("fileStatus.st_size > 0"))
        #expect(sharedIO.contains("UInt64(fileStatus.st_size) <= UInt64(maxPDFBytes)"))
        #expect(sharedIO.contains("fileStatus.st_nlink == 1"))
        #expect(sharedIO.contains("[nonRegularPDFMessage, emptyPDFMessage, tooLargePDFMessage].contains(message)"))
        #expect(sharedIO.contains("maxReservationAttempts"))
        #expect(sharedIO.contains("String(baseName.prefix(maxBaseNameLength + 64))"))
        #expect(src.contains("Plan3VaultPath.vaultRelativePath(for: urls.pdfURL"))
        #expect(viewer.contains("maxSearchQueryLength"))
        #expect(viewer.contains("maxSearchResults"))
        #expect(viewer.contains("maxFileNameDisplayCharacters"))
        #expect(viewer.contains("LiteParsePDFSignature.fileStartsWithPDFMagic(url.path)"))
        #expect(viewer.contains("String(searchText.prefix(Self.maxSearchQueryLength + 32))"))
        #expect(viewer.contains("String(fileName.prefix(maxFileNameDisplayCharacters + 32))"))
        #expect(viewer.contains("String(trimmed.prefix(maxFileNameDisplayCharacters - 3))"))
        #expect(viewer.contains("maxOutlineDepth"))
        #expect(viewer.contains("maxOutlineItems"))
        #expect(viewer.contains("maxOutlineNodes"))
        #expect(viewer.contains("maxOutlineTitleLength"))
        #expect(viewer.contains("max(0, outline.numberOfChildren)"))
        #expect(viewer.contains("String(title.prefix(maxOutlineTitleLength + 32))"))
        #expect(viewer.contains("maxAnnotationPages"))
        #expect(viewer.contains("min(document.pageCount, maxAnnotationPages)"))
        #expect(viewer.contains("String($0.prefix(maxAnnotationTitleLength + 32))"))
        #expect(viewer.contains("title: displayTitle"))
        #expect(viewer.contains("visitedNodeCount"))
        #expect(viewer.contains("@Environment(UIState.self)"))
        #expect(viewer.contains("sourcePDFSeparator"))
        #expect(viewer.contains("private var searchFieldBackground: Color"))
        #expect(viewer.contains("ui.theme.surfaceVariant(.other).resolved.card.color.opacity"))
        #expect(viewer.contains(".textFieldStyle(.plain)"))
        #expect(viewer.contains("ToolbarCapsuleButton("))
        #expect(viewer.contains("NativeCardButtonStyle(cornerRadius: 6)"))
        #expect(!viewer.contains("Divider()"))
        #expect(!viewer.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!viewer.contains(".buttonStyle(.plain)"))
        #expect(!viewer.contains(".foregroundStyle(.secondary)"))
        #expect(affordance.contains("LiteParseSourcePDFLink.resolve"))
        #expect(affordance.contains("maxRelativePathCharacters"))
        #expect(affordance.contains("String(rawRelativePath.prefix(maxRelativePathCharacters + 1))"))
        #expect(affordance.contains("pathParts.contains(where:"))
        #expect(affordance.contains("ToolbarCapsuleButton("))
        #expect(affordance.contains(#"title: "View original PDF""#))
        #expect(affordance.contains("role: .toolbarUtility"))
        #expect(affordance.contains("Self.displayFileName(originalPDFURL.lastPathComponent)"))
        #expect(!affordance.contains(".buttonStyle(.plain)"))
        #expect(!affordance.contains(".buttonStyle(.borderless)"))
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
        #expect(codepack.contains("runs the parser against that copied vault PDF path"))
        #expect(codepack.contains("512 MiB"))
        #expect(codepack.contains("bounded domain/code diagnostics"))
        #expect(codepack.contains("raw messages are bounded before trimming"))
        #expect(codepack.contains("sidebar status display values are control/whitespace-normalized before alert rendering"))
        #expect(codepack.contains("ellipsis stays inside the configured cap"))
        #expect(codepack.contains("filename ellipsis stays inside the configured cap"))
        #expect(codepack.contains("no-follow signature helper before PDFKit opens the URL"))
        #expect(capabilities.contains("PDF→Markdown import now has a real Plan 3 parser path"))
        #expect(capabilities.contains("test-linking condition, not the shipped MAS parser state"))
        #expect(capabilities.contains("raw localized filesystem descriptions"))
        #expect(capabilities.contains("raw messages bounded before trimming"))
        #expect(capabilities.contains("sidebar status display values control/whitespace-normalized before alert rendering"))
        #expect(capabilities.contains("filename ellipsis inside configured caps"))
        #expect(capabilities.contains("import status reports the copied `source_pdf` path"))
        #expect(capabilities.contains("parser runs against the revalidated vault copy"))
        #expect(capabilities.contains("revalidates no-follow `%PDF-`"))
        #expect(cargo.contains(#"mas-build = ["edgeparse-pdf", "parser-unpdf"]"#))
        #expect(rust.contains("doc.source_path = None"))
        #expect(rust.contains("symlink_metadata"))
        #expect(rust.contains("metadata.nlink() == 1"))
        #expect(rust.contains("std::fs::hard_link"))
        #expect(rust.contains("open_pdf_for_preflight"))
        #expect(rust.contains("OpenOptionsExt"))
        #expect(rust.contains("custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)"))
        #expect(rust.contains("let opened_metadata = file"))
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
        try Data("%PDF- fake".utf8).write(to: pdf)
        try Data("<html>not a paper</html>".utf8).write(to: htmlNamedPDF)
        try Data("%PDF- outside".utf8).write(to: outside)
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
            "Imported PDFs/./paper.pdf",
            "Imported PDFs//paper.pdf",
            "Imported PDFs/../../outside.pdf",
            "Imported PDFs/missing.pdf",
            "Imported PDFs/rate-limit.pdf",
            "Imported PDFs/linked-outside.pdf",
            String(repeating: "a", count: 4_200) + ".pdf",
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

        let longName = String(repeating: "x", count: 300)
        #expect(Plan3ImportFileIO.safeImportBaseName(longName).count == 180)
        #expect(Plan3ImportFileIO.safeImportBaseName("  \(longName)\n").count == 180)
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
        try Data("%PDF- source".utf8).write(to: source)
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

    @Test("reserved import writes reject hard-linked reservations")
    func reservedImportWritesRejectHardLinkedReservations() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-hardlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let reserved = root.appendingPathComponent("reserved.md")
        let alias = root.appendingPathComponent("alias.md")
        try Data().write(to: reserved)
        try FileManager.default.linkItem(at: reserved, to: alias)

        do {
            try Plan3ImportFileIO.writeData(Data("new markdown".utf8), toReservedFile: reserved)
            Issue.record("Expected markdown write to reject a hard-linked reservation")
        } catch {}

        #expect((try? Data(contentsOf: reserved)) == Data())
        #expect((try? Data(contentsOf: alias)) == Data())
    }

    @Test("reserved import copy revalidates source PDF on the copied file descriptor")
    func reservedImportCopyRevalidatesSourcePDFOnCopiedFileDescriptor() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-source-envelope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let validSource = root.appendingPathComponent("source.pdf")
        let nonPDFSource = root.appendingPathComponent("source-html.pdf")
        let oversizedSource = root.appendingPathComponent("oversized.pdf")
        let symlinkSource = root.appendingPathComponent("linked.pdf")
        let hardlinkedSource = root.appendingPathComponent("hardlinked.pdf")
        let reservedPDF = root.appendingPathComponent("reserved.pdf")

        try Data("%PDF- source".utf8).write(to: validSource)
        try Data("<html>not a paper</html>".utf8).write(to: nonPDFSource)
        try Data("%PDF- large".utf8).write(to: oversizedSource)
        let oversizedHandle = try FileHandle(forWritingTo: oversizedSource)
        try oversizedHandle.truncate(atOffset: UInt64(LiteParsePDFSignature.maxPDFBytes + 1))
        try oversizedHandle.close()
        try FileManager.default.createSymbolicLink(at: symlinkSource, withDestinationURL: validSource)
        let hardlinkSupported = (try? FileManager.default.linkItem(at: validSource, to: hardlinkedSource)) != nil

        func expectCopyRejected(from source: URL) throws {
            try Data().write(to: reservedPDF)
            do {
                try Plan3ImportFileIO.copyFileContents(from: source, toReservedFile: reservedPDF)
                Issue.record("Expected source copy to reject \(source.lastPathComponent)")
            } catch {}
            #expect((try? Data(contentsOf: reservedPDF)) == Data())
        }

        try expectCopyRejected(from: nonPDFSource)
        try expectCopyRejected(from: oversizedSource)
        try expectCopyRejected(from: symlinkSource)
        if hardlinkSupported {
            try expectCopyRejected(from: hardlinkedSource)
            try FileManager.default.removeItem(at: hardlinkedSource)
        }

        try Plan3ImportFileIO.copyFileContents(from: validSource, toReservedFile: reservedPDF)
        #expect((try? Data(contentsOf: reservedPDF)) == Data("%PDF- source".utf8))
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
        try Data("%PDF- fake".utf8).write(to: sourcePDF)
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

        guard case .imported(_, _, let outcomeSourcePDFRelative) = outcome else {
            Issue.record("Expected PDF import to create a note, got \(String(describing: outcome))")
            return
        }

        let page = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)
        let filePath = try #require(page.filePath)
        let noteBaseName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        let sourcePDFRelative = try #require(page.frontMatter["source_pdf"])
        #expect(outcomeSourcePDFRelative == sourcePDFRelative)
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
    @Test("import controller parses the copied vault PDF")
    func importControllerParsesCopiedVaultPDF() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("liteparse-import-copy-parse-\(UUID().uuidString)")
        let vault = root.appendingPathComponent("Vault")
        let importDir = vault.appendingPathComponent(LiteParsePDFImportController.importDirectory, isDirectory: true)
        let sourcePDF = root.appendingPathComponent("paper.pdf")
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try Data("%PDF- source copy".utf8).write(to: sourcePDF)
        defer { try? FileManager.default.removeItem(at: root) }

        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let importer = VaultCopyOnlyLiteParseImporter(
            originalPath: sourcePDF.standardizedFileURL.path,
            expectedDirectoryPath: importDir.standardizedFileURL.path
        )

        let outcome = await LiteParsePDFImportController.importPage(
            pdfPath: sourcePDF.path,
            vaultURL: vault,
            modelContext: context,
            graphState: nil,
            importer: importer
        )

        guard case .imported(_, _, let sourcePDFRelativePath) = outcome else {
            Issue.record("Expected PDF import to parse the copied vault PDF, got \(String(describing: outcome))")
            return
        }

        let copiedPDF = vault.appendingPathComponent(sourcePDFRelativePath)
        let note = try #require(try context.fetch(FetchDescriptor<SDPage>()).first)
        let notePath = try #require(note.filePath)
        let noteText = try String(contentsOfFile: notePath, encoding: .utf8)

        #expect(copiedPDF.deletingLastPathComponent().standardizedFileURL.path == importDir.standardizedFileURL.path)
        #expect((try? Data(contentsOf: copiedPDF)) == Data("%PDF- source copy".utf8))
        #expect(noteText.contains("Copied-vault-path body."))
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
        try Data("%PDF- fake".utf8).write(to: sourcePDF)
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
        try Data("%PDF- fake".utf8).write(to: sourcePDF)
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
        try Data("%PDF- fake".utf8).write(to: sourcePDF)
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

private struct VaultCopyOnlyLiteParseImporter: LiteParsePDFImporter {
    let originalPath: String
    let expectedDirectoryPath: String

    func importToMarkdown(pdfPath: String) -> LiteParseImportResult {
        let pdfURL = URL(fileURLWithPath: pdfPath).standardizedFileURL
        guard pdfURL.path != originalPath else {
            return .failed("importer received the original source path")
        }
        guard pdfURL.deletingLastPathComponent().path == expectedDirectoryPath else {
            return .failed("importer did not receive the vault copy path")
        }
        guard let data = try? Data(contentsOf: pdfURL),
              data.starts(with: Data("%PDF-".utf8)) else {
            return .failed("importer received an invalid PDF copy")
        }
        return .markdown("# Parsed\n\nCopied-vault-path body.")
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
