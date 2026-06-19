import Foundation

// R-LITEPARSE — the Swift PDF-import result model + the FFI-envelope decoder + the
// importer seam (owner 2026-06-19). The Rust `liteparse_pdf_to_markdown` FFI returns a
// JSON envelope (`{"ok":true,"markdown":…}` on success, `{"ok":false,"error":…}` on
// failure); this decodes it into a typed result the note-sidebar import surface renders
// HONESTLY — never a fake/empty note. INERT importer until the binding includes
// `liteparse_pdf_to_markdown` (one more build-agent-core.sh) + the native PDFium vendor
// (S2) lands; then a live importer calls the FFI + reuses this decoder verbatim.

/// The honest outcome of a PDF→Markdown import.
enum LiteParseImportResult: Equatable {
    case markdown(String)
    case notWired
    case unsupported(String)
    case failed(String)
}

enum LiteParseImportEnvelope {
    /// Decode the `liteparse_pdf_to_markdown` FFI JSON envelope into a typed result.
    /// Unreadable output is an honest `.failed`, never a fabricated note.
    static func decode(_ json: String) -> LiteParseImportResult {
        guard
            let data = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .failed("Unreadable response from the PDF engine.")
        }
        if (obj["ok"] as? Bool) == true, let markdown = obj["markdown"] as? String {
            return .markdown(markdown)
        }
        let error = (obj["error"] as? String) ?? "PDF conversion failed."
        let lower = error.lowercased()
        if lower.contains("not wired") { return .notWired }
        if lower.contains("unsupported format") { return .unsupported(error) }
        return .failed(error)
    }
}

/// Converts a local PDF to Markdown. An implementation NEVER returns a fabricated note —
/// only a real conversion or an honest failure result.
protocol LiteParsePDFImporter: Sendable {
    func importToMarkdown(pdfPath: String) -> LiteParseImportResult
}

/// INERT importer — until the `liteparse_pdf_to_markdown` FFI is in the binding AND the
/// native PDFium engine is vendored (S2), every import honestly reports `.notWired` (a
/// PDF) or `.unsupported` (a non-PDF — Office/image need external binaries, never shelled
/// out). The live importer that calls the FFI is the follow-on; it reuses
/// `LiteParseImportEnvelope.decode`.
struct InertLiteParsePDFImporter: LiteParsePDFImporter {
    func importToMarkdown(pdfPath: String) -> LiteParseImportResult {
        guard pdfPath.lowercased().hasSuffix(".pdf") else {
            return .unsupported("Only PDF is supported here (Office/image formats need external binaries — out of scope).")
        }
        return .notWired
    }
}
