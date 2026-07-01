import Darwin
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

nonisolated enum LiteParseImportDiagnostics {
    static let maxFailureReasonCharacters = 320
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func failureMessage(_ prefix: String, error: Error) -> String {
        bounded("\(prefix): \(errorSummary(error))", fallback: prefix)
    }

    static func inspectionFailure(_ error: Error) -> String {
        errorSummary(error)
    }

    private static func errorSummary(_ error: Error) -> String {
        let nsError = error as NSError
        let domain = sanitizedDomain(nsError.domain)
        return "failure domain=\(domain) code=\(nsError.code)"
    }

    private static func sanitizedDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 16))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let safeDomain = String(value.prefix(maxDomainCharacters))
        return safeDomain.isEmpty ? "Error" : safeDomain
    }

    private static func bounded(_ message: String, fallback: String) -> String {
        let bounded = String(message.prefix(maxFailureReasonCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxFailureReasonCharacters else {
            return value
        }
        return String(value.prefix(maxFailureReasonCharacters - 3)) + "..."
    }
}

nonisolated enum LiteParseImportEnvelope {
    static let emptyMarkdownMessage = "PDF conversion produced no readable Markdown."
    static let markdownTooLargeMessage = "PDF conversion produced Markdown that is too large to import safely."
    static let envelopeTooLargeMessage = "PDF engine response is too large to read safely."
    static let maxMarkdownCharacters = 8 * 1024 * 1024
    static let maxEnvelopeCharacters = maxMarkdownCharacters + (1024 * 1024)
    static let maxErrorMessageCharacters = 1024

    /// Decode the `liteparse_pdf_to_markdown` FFI JSON envelope into a typed result.
    /// Unreadable output is an honest `.failed`, never a fabricated note.
    static func decode(_ json: String) -> LiteParseImportResult {
        let boundedJSON = String(json.prefix(maxEnvelopeCharacters + 1))
        guard boundedJSON.count <= maxEnvelopeCharacters else {
            return .failed(envelopeTooLargeMessage)
        }
        guard
            let data = boundedJSON.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .failed("Unreadable response from the PDF engine.")
        }
        if (obj["ok"] as? Bool) == true, let markdown = obj["markdown"] as? String {
            guard markdown.count <= maxMarkdownCharacters else {
                return .failed(markdownTooLargeMessage)
            }
            guard markdownIsSubstantive(markdown) else {
                return .failed(emptyMarkdownMessage)
            }
            return .markdown(markdown)
        }
        let error = boundedErrorMessage((obj["error"] as? String) ?? "PDF conversion failed.")
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

    private static func boundedErrorMessage(_ error: String) -> String {
        let bounded = String(error.prefix(maxErrorMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? "PDF conversion failed." : trimmed
        guard value.count > maxErrorMessageCharacters else { return value }
        return String(value.prefix(maxErrorMessageCharacters))
    }
}

nonisolated enum LiteParsePDFSignature {
    private static let pdfMagic = Array("%PDF-".utf8)
    static let maxPDFBytes = 512 * 1024 * 1024
    static let unsupportedPDFMessage = "Only PDF is supported here (Office/image formats need external binaries — out of scope)."
    static let invalidPDFBodyMessage = "The file does not start with %PDF-, so it is not a PDF."
    static let nonRegularPDFMessage = "PDF path is not a regular file."
    static let emptyPDFMessage = "PDF file is empty."
    static let tooLargePDFMessage = "PDF is too large to parse safely (512 MiB limit)."

    static func validationFailure(forPath path: String) -> LiteParseImportResult? {
        let pathExtension = URL(fileURLWithPath: path).pathExtension
        let hasPDFExtension = pathExtension.caseInsensitiveCompare("pdf") == .orderedSame
        guard hasPDFExtension || pathExtension.isEmpty else {
            return .unsupported(unsupportedPDFMessage)
        }
        if let envelopeFailure = fileEnvelopeFailure(forPath: path, hasPDFExtension: hasPDFExtension) {
            return envelopeFailure
        }
        switch fileStartsWithPDFMagic(path) {
        case .match:
            return nil
        case .mismatch:
            return .failed(invalidPDFBodyMessage)
        case .unreadable(let message):
            if [nonRegularPDFMessage, emptyPDFMessage, tooLargePDFMessage].contains(message) {
                return .failed(message)
            }
            return hasPDFExtension
                ? .failed("Could not inspect the PDF file: \(message)")
                : .unsupported(unsupportedPDFMessage)
        }
    }

    private static func fileEnvelopeFailure(forPath path: String, hasPDFExtension: Bool) -> LiteParseImportResult? {
        let fileManager = FileManager.default
        if (try? fileManager.destinationOfSymbolicLink(atPath: path)) != nil {
            return .failed(nonRegularPDFMessage)
        }

        do {
            let values = try URL(fileURLWithPath: path).resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                return .failed(nonRegularPDFMessage)
            }
            guard let fileSize = values.fileSize else {
                return .failed("Could not inspect the PDF file: file size is unavailable")
            }
            if fileSize == 0 {
                return .failed(emptyPDFMessage)
            }
            if fileSize > maxPDFBytes {
                return .failed(tooLargePDFMessage)
            }
            return nil
        } catch {
            return hasPDFExtension
                ? .failed("Could not inspect the PDF file: \(LiteParseImportDiagnostics.inspectionFailure(error))")
                : .unsupported(unsupportedPDFMessage)
        }
    }

    static func fileStartsWithPDFMagic(_ path: String) -> PDFMagicCheck {
        let fd = path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return .unreadable("file is not readable")
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let message = String(cString: strerror(errno))
            close(fd)
            return .unreadable(message)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            return .unreadable(nonRegularPDFMessage)
        }
        guard fileStatus.st_size > 0 else {
            close(fd)
            return .unreadable(emptyPDFMessage)
        }
        guard UInt64(fileStatus.st_size) <= UInt64(maxPDFBytes) else {
            close(fd)
            return .unreadable(tooLargePDFMessage)
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }

        do {
            let data = try handle.read(upToCount: pdfMagic.count) ?? Data()
            return Array(data) == pdfMagic ? .match : .mismatch
        } catch {
            return .unreadable(LiteParseImportDiagnostics.inspectionFailure(error))
        }
    }

    static func openValidatedPDFForReading(path: String) throws -> FileHandle {
        let fd = path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw pdfReadError(nonRegularPDFMessage, errnoCode: errno)
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let capturedErrno = errno
            close(fd)
            throw pdfReadError("Could not inspect the PDF file.", errnoCode: capturedErrno)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw pdfReadError(nonRegularPDFMessage, errnoCode: EFTYPE)
        }
        guard fileStatus.st_size > 0 else {
            close(fd)
            throw pdfReadError(emptyPDFMessage, errnoCode: EINVAL)
        }
        guard UInt64(fileStatus.st_size) <= UInt64(maxPDFBytes) else {
            close(fd)
            throw pdfReadError(tooLargePDFMessage, errnoCode: EFBIG)
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            let data = try handle.read(upToCount: pdfMagic.count) ?? Data()
            guard Array(data) == pdfMagic else {
                try? handle.close()
                throw pdfReadError(invalidPDFBodyMessage, errnoCode: EINVAL)
            }
            try handle.seek(toOffset: 0)
            return handle
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func pdfReadError(_ message: String, errnoCode: Int32) -> NSError {
        NSError(
            domain: "LiteParsePDFSignature",
            code: Int(errnoCode),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
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

nonisolated enum Plan3ImportFileIO {
    private static let fallbackBaseName = "Imported PDF"
    private static let maxBaseNameLength = 180
    private static let maxReservationAttempts = 10_000

    /// Atomically reserves a paired `<baseName>.md` + `<baseName>.pdf`.
    static func reservePairedFileURLs(
        directory: URL,
        baseName: String
    ) throws -> (noteURL: URL, pdfURL: URL) {
        let safe = safeImportBaseName(baseName)
        var candidateBaseName = safe
        var counter = 2
        for _ in 0..<maxReservationAttempts {
            try Task.checkCancellation()
            let noteURL = directory.appendingPathComponent("\(candidateBaseName).md")
            let pdfURL = directory.appendingPathComponent("\(candidateBaseName).pdf")
            if try reserveEmptyFile(at: noteURL) {
                do {
                    if try reserveEmptyFile(at: pdfURL) {
                        return (noteURL: noteURL, pdfURL: pdfURL)
                    }
                    try? FileManager.default.removeItem(at: noteURL)
                } catch {
                    try? FileManager.default.removeItem(at: noteURL)
                    throw error
                }
            }
            candidateBaseName = "\(safe) \(counter)"
            counter += 1
        }
        throw fileIOError("could not reserve import filenames", errnoCode: EEXIST)
    }

    static func safeImportBaseName(_ baseName: String) -> String {
        let boundedBaseName = String(baseName.prefix(maxBaseNameLength + 64))
        let normalized = boundedBaseName.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) ? " " : String(scalar)
        }.joined()
        var safe = normalized
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: " -")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        repeat {
            let before = safe
            safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
            while safe.hasPrefix(".") {
                safe.removeFirst()
            }
            safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
            if safe == before { break }
        } while true
        if safe.isEmpty {
            return fallbackBaseName
        }
        return String(safe.prefix(maxBaseNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func copyFileContents(from sourceURL: URL, toReservedFile destinationURL: URL) throws {
        let source = try LiteParsePDFSignature.openValidatedPDFForReading(path: sourceURL.path)
        defer { try? source.close() }

        let destination = try openReservedFileForWriting(destinationURL)
        defer { try? destination.close() }
        try destination.truncate(atOffset: 0)

        while true {
            try Task.checkCancellation()
            let chunk = try source.read(upToCount: 1_048_576) ?? Data()
            guard !chunk.isEmpty else { break }
            try destination.write(contentsOf: chunk)
        }
        try destination.synchronize()
    }

    static func writeData(_ data: Data, toReservedFile destinationURL: URL) throws {
        let destination = try openReservedFileForWriting(destinationURL)
        defer { try? destination.close() }
        try destination.truncate(atOffset: 0)
        try destination.write(contentsOf: data)
        try destination.synchronize()
    }

    private static func openReservedFileForWriting(_ url: URL) throws -> FileHandle {
        let fd = url.path.withCString { path in
            open(path, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw fileIOError("could not open reserved \(url.lastPathComponent)", errnoCode: errno)
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let capturedErrno = errno
            close(fd)
            throw fileIOError("could not inspect reserved \(url.lastPathComponent)", errnoCode: capturedErrno)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw fileIOError("reserved \(url.lastPathComponent) is not a regular file", errnoCode: EFTYPE)
        }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    private static func reserveEmptyFile(at url: URL) throws -> Bool {
        let fd = url.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(0o600))
        }
        guard fd < 0 else {
            close(fd)
            return true
        }
        if errno == EEXIST { return false }
        throw fileIOError("could not reserve \(url.lastPathComponent)", errnoCode: errno)
    }

    private static func fileIOError(_ prefix: String, errnoCode: Int32) -> NSError {
        let err = String(cString: strerror(errnoCode))
        return NSError(
            domain: "Plan3ImportFileIO",
            code: Int(errnoCode),
            userInfo: [NSLocalizedDescriptionKey: "\(prefix): \(err)"]
        )
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
