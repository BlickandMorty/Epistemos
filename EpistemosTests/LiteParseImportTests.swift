import Testing
import Foundation
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

    @Test("the inert importer reports not-wired for a PDF, unsupported for a non-PDF")
    func inertImporter() {
        let importer = InertLiteParsePDFImporter()
        #expect(importer.importToMarkdown(pdfPath: "/docs/paper.pdf") == .notWired)
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
    func liveImporterHonestOnPdf() {
        // Test host has no agent_coreFFI → the fallback. The linked app build exercises
        // the Rust EdgeParse/unpdf engine through the same envelope decoder.
        #expect(LiveLiteParsePDFImporter().importToMarkdown(pdfPath: "/a/paper.pdf") == .notWired)
    }

    @Test("import controller preserves the original PDF via frontmatter")
    func importControllerSourcePDFContract() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/LiteParse/LiteParsePDFImportController.swift")
        #expect(src.contains(#"frontMatter["source_kind"] = "pdf""#))
        #expect(src.contains(#"frontMatter["source_pdf"]"#))
        #expect(src.contains("copyItem"))
        #expect(src.contains("vaultRelativePath(for: sourcePDFURL"))
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
}
