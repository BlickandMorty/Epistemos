import Foundation

// R-LITEPARSE — the Swift PDF-import result model + the FFI-envelope decoder + the
// importer seam (owner 2026-06-19). The Rust `liteparse_pdf_to_markdown` FFI returns a
// JSON envelope (`{"ok":true,"markdown":…}` on success, `{"ok":false,"error":…}` on
// failure); this decodes it into a typed result the note-sidebar import surface renders
// HONESTLY — never a fake/empty note. The live importer calls the Plan 3 Rust parser
// stack through this same FFI envelope when `agent_coreFFI` is linked; test hosts without
// that binding fall back to the inert importer.

/// The honest outcome of a PDF→Markdown import.
nonisolated enum LiteParseImportResult: Equatable, Sendable {
    case markdown(String)
    case notWired
    case unsupported(String)
    case failed(String)
}

nonisolated enum LiteParseImportEnvelope {
    static let emptyMarkdownMessage = "PDF conversion produced no readable Markdown."

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
            guard markdownIsSubstantive(markdown) else {
                return .failed(emptyMarkdownMessage)
            }
            return .markdown(markdown)
        }
        let error = (obj["error"] as? String) ?? "PDF conversion failed."
        let lower = error.lowercased()
        if lower.contains("not wired") { return .notWired }
        if lower.contains("unsupported format") { return .unsupported(error) }
        return .failed(error)
    }

    private static func markdownIsSubstantive(_ markdown: String) -> Bool {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed.localizedCaseInsensitiveCompare("*No content extracted.*") != .orderedSame
    }
}

nonisolated enum LiteParsePDFSignature {
    private static let pdfMagic = Array("%PDF-".utf8)
    static let unsupportedPDFMessage = "Only PDF is supported here (Office/image formats need external binaries — out of scope)."
    static let invalidPDFBodyMessage = "The file does not start with %PDF-, so it is not a PDF."

    static func validationFailure(forPath path: String) -> LiteParseImportResult? {
        let hasPDFExtension = path.lowercased().hasSuffix(".pdf")
        switch fileStartsWithPDFMagic(path) {
        case .match:
            return nil
        case .mismatch:
            return .failed(invalidPDFBodyMessage)
        case .unreadable(let message):
            return hasPDFExtension
                ? .failed("Could not inspect the PDF file: \(message)")
                : .unsupported(unsupportedPDFMessage)
        }
    }

    static func fileStartsWithPDFMagic(_ path: String) -> PDFMagicCheck {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return .unreadable("file is not readable")
        }
        defer { try? handle.close() }

        do {
            let data = try handle.read(upToCount: pdfMagic.count) ?? Data()
            return Array(data) == pdfMagic ? .match : .mismatch
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }
}

nonisolated enum PDFMagicCheck: Equatable, Sendable {
    case match
    case mismatch
    case unreadable(String)
}

nonisolated enum Plan3VaultPath {
    static let outsideVaultMessage = "Import destination resolves outside the vault."

    static func vaultRelativePath(for fileURL: URL, in vaultURL: URL) -> String? {
        let lexicalVault = vaultURL.standardizedFileURL
        let lexicalFile = fileURL.standardizedFileURL
        let lexicalVaultPath = directoryPrefix(for: lexicalVault)
        guard lexicalFile.path.hasPrefix(lexicalVaultPath) else {
            return nil
        }

        let resolvedVault = lexicalVault.resolvingSymlinksInPath()
        let resolvedFile = resolvedURLForContainment(lexicalFile)
        let resolvedVaultPath = directoryPrefix(for: resolvedVault)
        guard resolvedFile.path.hasPrefix(resolvedVaultPath) else {
            return nil
        }

        return String(lexicalFile.path.dropFirst(lexicalVaultPath.count))
    }

    static func resolvesInsideVault(_ fileURL: URL, in vaultURL: URL) -> Bool {
        vaultRelativePath(for: fileURL, in: vaultURL) != nil
    }

    private static func directoryPrefix(for url: URL) -> String {
        url.path.hasSuffix("/") ? url.path : url.path + "/"
    }

    private static func resolvedURLForContainment(_ url: URL) -> URL {
        var existing = url.standardizedFileURL
        var missingPathComponents: [String] = []

        while !FileManager.default.fileExists(atPath: existing.path) {
            let parent = existing.deletingLastPathComponent()
            guard parent.path != existing.path else { break }
            missingPathComponents.insert(existing.lastPathComponent, at: 0)
            existing = parent
        }

        return missingPathComponents.reduce(existing.resolvingSymlinksInPath()) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }.standardizedFileURL
    }
}

/// Converts a local PDF to Markdown. An implementation NEVER returns a fabricated note —
/// only a real conversion or an honest failure result.
nonisolated protocol LiteParsePDFImporter: Sendable {
    func importToMarkdown(pdfPath: String) -> LiteParseImportResult
}

/// INERT importer — for the unit-test host (which doesn't link `agent_coreFFI`) and as
/// the honest default before the binding has the FFI. A PDF → `.notWired`, a non-PDF →
/// `.unsupported` (never shelled out).
nonisolated struct InertLiteParsePDFImporter: LiteParsePDFImporter {
    func importToMarkdown(pdfPath: String) -> LiteParseImportResult {
        if let failure = LiteParsePDFSignature.validationFailure(forPath: pdfPath) {
            return failure
        }
        return .notWired
    }
}

/// LIVE importer — calls the Rust `liteparse_pdf_to_markdown` FFI and decodes its
/// envelope with the same `LiteParseImportEnvelope.decode`. PDF-only scope is enforced
/// BEFORE the FFI (a non-PDF is never passed down). On a test host without
/// `agent_coreFFI` it falls back to the inert behavior so it still compiles + runs.
nonisolated struct LiveLiteParsePDFImporter: LiteParsePDFImporter {
    func importToMarkdown(pdfPath: String) -> LiteParseImportResult {
        if let failure = LiteParsePDFSignature.validationFailure(forPath: pdfPath) {
            return failure
        }
        #if canImport(agent_coreFFI)
        return LiteParseImportEnvelope.decode(liteparsePdfToMarkdown(pdfPath: pdfPath))
        #else
        return .notWired
        #endif
    }
}
