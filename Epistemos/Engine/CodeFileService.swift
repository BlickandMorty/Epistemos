import CryptoKit
import Foundation

// MARK: - CodeFileService
//
// Wave 9.5 + W9.10 base of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 9,
//  cross-ref `epistemos_code_verdict.md` + brain dump 2026-04-26).
//
// Per the user's directive: "I want my AI models to have access to
// create code files just like they can create notes." This service is
// the canonical Swift entry point both the editor UI and the agent
// tool registry call into.
//
// Every successful create / update writes the source file AND the
// .epcache sidecar with full provenance — closing the loop where
// "AI created this file in this run, derived from this thought,
// during this tool call."
//
// Per-action contract:
//   create(...)   → writes source + writes sidecar with .agent or
//                   .human producer + supplied provenance fields
//   read(...)     → returns body + sidecar (sidecar may be nil if the
//                   file pre-existed our indexer)
//   update(...)   → writes source + refreshes sidecar (contentHash +
//                   indexedAt updated; provenance fields preserved)
//   list(...)     → enumerates the code files the indexer knows about
//                   (i.e., those with sidecars under .epcache/code/)
//
// The actual workspace indexer (W9.7) is what populates symbols +
// embeddings + cross-references in the sidecar. This service is the
// CRUD surface; it leaves analysis fields empty on create, and
// preserves them on update.

@MainActor
public final class CodeFileService {

    public enum ServiceError: Error, CustomStringConvertible {
        case nameContainsPathSeparators
        case nameIsEmpty
        case fileAlreadyExists(URL)
        case fileNotFound(URL)
        case sourceWriteFailed(underlying: Error)
        case sidecarWriteFailed(underlying: Error)
        case sidecarReadFailed(underlying: Error)
        case sidecarParseFailed(underlying: Error)
        case pathEscapesVault(URL)
        case reservedCachePath(URL)

        public var description: String {
            switch self {
            case .nameContainsPathSeparators:
                return "CodeFileService: file name must not contain `/` or `\\`"
            case .nameIsEmpty:
                return "CodeFileService: file name is empty"
            case let .fileAlreadyExists(url):
                return "CodeFileService: file already exists at \(url.path)"
            case let .fileNotFound(url):
                return "CodeFileService: file not found at \(url.path)"
            case let .sourceWriteFailed(error):
                return "CodeFileService: failed to write source: \(error)"
            case let .sidecarWriteFailed(error):
                return "CodeFileService: failed to write sidecar: \(error)"
            case let .sidecarReadFailed(error):
                return "CodeFileService: failed to read sidecar: \(error)"
            case let .sidecarParseFailed(error):
                return "CodeFileService: sidecar JSON malformed: \(error)"
            case let .pathEscapesVault(url):
                return "CodeFileService: path escapes vault containment: \(url.path)"
            case let .reservedCachePath(url):
                return "CodeFileService: source path is inside reserved .epcache storage: \(url.path)"
            }
        }
    }

    private struct ContainedSourcePath {
        let url: URL
        let vaultRelativePath: String
    }

    public let vaultRoot: URL
    private let fileManager: FileManager

    public init(vaultRoot: URL, fileManager: FileManager = .default) {
        self.vaultRoot = vaultRoot
        self.fileManager = fileManager
    }

    // MARK: - Create

    /// Create a new code file inside the vault. Picks the extension
    /// from `kind.primaryExtension`; renders boilerplate via
    /// `kind.newFileTemplate(name:)` when `body` is nil.
    ///
    /// `relativeDirectory` is the vault-relative directory under which
    /// the file is created (e.g. `"Sources/Foo"`). Pass `""` for the
    /// vault root.
    @discardableResult
    public func createCodeFile(
        relativeDirectory: String,
        name: String,
        kind: CodeArtifactKind,
        body: String? = nil,
        provenance: CodeProvenance
    ) throws -> URL {
        let validatedName = try Self.validate(name: name)
        let fileURL = try containedCreateURL(
            relativeDirectory: relativeDirectory,
            fileName: "\(validatedName).\(kind.primaryExtension)"
        )

        if fileManager.fileExists(atPath: fileURL.url.path) {
            throw ServiceError.fileAlreadyExists(fileURL.url)
        }
        do {
            try fileManager.createDirectory(
                at: fileURL.url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }

        let resolvedBody = body ?? kind.newFileTemplate(name: validatedName)
        let bodyData = Data(resolvedBody.utf8)
        do {
            try bodyData.write(to: fileURL.url, options: .atomic)
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }

        let sidecar = CodeArtifactSidecar(
            vaultRelativePath: fileURL.vaultRelativePath,
            kind: kind,
            contentHash: Self.contentHash(of: bodyData),
            indexedAt: Self.unixMillis(),
            provenance: provenance
        )
        try writeSidecar(sidecar)
        return fileURL.url
    }

    // MARK: - Read

    /// Read a code file's body + sidecar. Returns `(body, nil)` when
    /// the sidecar is missing — the indexer (W9.7) will write one on
    /// the next pass.
    public func readCodeFile(at fileURL: URL) throws -> (body: String, sidecar: CodeArtifactSidecar?) {
        let contained = try containedExistingSourceURL(fileURL)
        guard fileManager.fileExists(atPath: contained.url.path) else {
            throw ServiceError.fileNotFound(contained.url)
        }
        let bodyData: Data
        do {
            bodyData = try Data(contentsOf: contained.url)
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }
        let body = String(data: bodyData, encoding: .utf8) ?? ""

        let sidecarURL = CodeSidecarPath.sidecarURL(
            forVaultRoot: vaultRoot,
            vaultRelativePath: contained.vaultRelativePath
        )
        if fileManager.fileExists(atPath: sidecarURL.path) {
            do {
                let data = try Data(contentsOf: sidecarURL)
                let sidecar = try JSONDecoder.epdocCanonical.decode(CodeArtifactSidecar.self, from: data)
                return (body, sidecar)
            } catch let error as DecodingError {
                throw ServiceError.sidecarParseFailed(underlying: error)
            } catch {
                throw ServiceError.sidecarReadFailed(underlying: error)
            }
        }
        return (body, nil)
    }

    // MARK: - Update

    /// Overwrite the source file's body + refresh the sidecar's
    /// contentHash + indexedAt. Provenance fields are preserved by
    /// default; pass a non-nil `provenanceOverride` to record a new
    /// "this update came from agent run X" record.
    public func updateCodeFile(
        at fileURL: URL,
        body: String,
        provenanceOverride: CodeProvenance? = nil
    ) throws {
        let contained = try containedExistingSourceURL(fileURL)
        guard fileManager.fileExists(atPath: contained.url.path) else {
            throw ServiceError.fileNotFound(contained.url)
        }
        let bodyData = Data(body.utf8)
        do {
            try bodyData.write(to: contained.url, options: .atomic)
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }

        let kind = CodeArtifactKind.from(fileURL: contained.url)
        let existingSidecar: CodeArtifactSidecar? = (try? readCodeFile(at: contained.url))?.sidecar

        let nextProvenance = provenanceOverride
            ?? existingSidecar?.provenance
            ?? CodeProvenance(producer: .human)

        let sidecar = CodeArtifactSidecar(
            vaultRelativePath: contained.vaultRelativePath,
            kind: kind,
            contentHash: Self.contentHash(of: bodyData),
            indexedAt: Self.unixMillis(),
            provenance: nextProvenance,
            symbols: existingSidecar?.symbols ?? [],
            crossReferences: existingSidecar?.crossReferences ?? [],
            embedding: existingSidecar?.embedding
        )
        try writeSidecar(sidecar)
    }

    // MARK: - List

    /// List every code file the vault knows about by walking
    /// `.epcache/code/` and returning the underlying source URLs.
    /// Optional `kind` filter narrows by language.
    public func listCodeFiles(kind: CodeArtifactKind? = nil) throws -> [URL] {
        let cacheRoot = canonicalVaultRoot()
            .appendingPathComponent(CodeSidecarPath.cacheRoot, isDirectory: true)
            .appendingPathComponent(CodeSidecarPath.codeSubdir, isDirectory: true)
        guard fileManager.fileExists(atPath: cacheRoot.path) else {
            return []
        }
        let entries = (try? fileManager.contentsOfDirectory(at: cacheRoot, includingPropertiesForKeys: nil)) ?? []
        var result: [URL] = []
        for entry in entries where entry.lastPathComponent.hasSuffix(CodeSidecarPath.suffix) {
            guard let data = try? Data(contentsOf: entry),
                  let sidecar = try? JSONDecoder.epdocCanonical.decode(CodeArtifactSidecar.self, from: data) else {
                continue
            }
            if let kind, sidecar.kind != kind { continue }
            let source = try containedSourceURL(forVaultRelativePath: sidecar.vaultRelativePath)
            result.append(source.url)
        }
        return result.sorted { $0.path < $1.path }
    }

    // MARK: - Helpers

    private func writeSidecar(_ sidecar: CodeArtifactSidecar) throws {
        _ = try containedSourceURL(forVaultRelativePath: sidecar.vaultRelativePath)
        let url = CodeSidecarPath.sidecarURL(
            forVaultRoot: canonicalVaultRoot(),
            vaultRelativePath: sidecar.vaultRelativePath
        )
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let json = try JSONEncoder.epdocCanonical.encode(sidecar)
            try json.write(to: url, options: .atomic)
        } catch {
            throw ServiceError.sidecarWriteFailed(underlying: error)
        }
    }

    private func containedCreateURL(
        relativeDirectory: String,
        fileName: String
    ) throws -> ContainedSourcePath {
        let normalizedDirectory = try normalizedVaultRelativeDirectory(relativeDirectory)
        let parent = canonicalVaultRoot()
            .appendingPathComponent(normalizedDirectory, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let candidate = parent
            .appendingPathComponent(fileName, isDirectory: false)
            .standardizedFileURL
        return try containedSourceURL(candidate)
    }

    private func containedExistingSourceURL(_ fileURL: URL) throws -> ContainedSourcePath {
        try containedSourceURL(fileURL.resolvingSymlinksInPath().standardizedFileURL)
    }

    private func containedSourceURL(forVaultRelativePath vaultRelativePath: String) throws -> ContainedSourcePath {
        let normalizedPath = try normalizedVaultRelativePath(vaultRelativePath)
        let candidate = canonicalVaultRoot()
            .appendingPathComponent(normalizedPath, isDirectory: false)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return try containedSourceURL(candidate)
    }

    private func containedSourceURL(_ candidate: URL) throws -> ContainedSourcePath {
        let root = canonicalVaultRoot()
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let relative = try vaultRelativePath(for: resolved, root: root)
        if isReservedCacheSourcePath(relative) {
            throw ServiceError.reservedCachePath(resolved)
        }
        return ContainedSourcePath(url: resolved, vaultRelativePath: relative)
    }

    private func vaultRelativePath(for fileURL: URL, root: URL) throws -> String {
        let rootPath = root.path
        let filePath = fileURL.standardizedFileURL.path
        if filePath == rootPath {
            return ""
        }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            throw ServiceError.pathEscapesVault(fileURL)
        }
        return String(filePath.dropFirst(prefix.count))
    }

    private func canonicalVaultRoot() -> URL {
        vaultRoot.resolvingSymlinksInPath().standardizedFileURL
    }

    private func normalizedVaultRelativeDirectory(_ path: String) throws -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        return try normalizedVaultRelativePath(trimmed, allowEmpty: true)
    }

    private func normalizedVaultRelativePath(
        _ path: String,
        allowEmpty: Bool = false
    ) throws -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if allowEmpty { return "" }
            throw ServiceError.pathEscapesVault(vaultRoot)
        }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("\\") {
            throw ServiceError.pathEscapesVault(URL(fileURLWithPath: trimmed))
        }
        let rawComponents = trimmed.split { character in
            character == "/" || character == "\\"
        }.map(String.init)
        var components: [String] = []
        for component in rawComponents {
            if component == "." { continue }
            if component == ".." {
                throw ServiceError.pathEscapesVault(vaultRoot.appendingPathComponent(trimmed))
            }
            components.append(component)
        }
        let normalized = components.joined(separator: "/")
        if isReservedCacheSourcePath(normalized) {
            throw ServiceError.reservedCachePath(vaultRoot.appendingPathComponent(normalized))
        }
        return normalized
    }

    private func isReservedCacheSourcePath(_ relativePath: String) -> Bool {
        relativePath == CodeSidecarPath.cacheRoot
            || relativePath.hasPrefix(CodeSidecarPath.cacheRoot + "/")
    }

    private static func validate(name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ServiceError.nameIsEmpty }
        if trimmed.contains("/") || trimmed.contains("\\") {
            throw ServiceError.nameContainsPathSeparators
        }
        return trimmed
    }

    private static func contentHash(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func unixMillis() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
    }
}
