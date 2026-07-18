import Foundation

/// Local UTF-8 source-file storage for files inside the active vault.
nonisolated public final class CodeFileService: @unchecked Sendable {
    public enum ServiceError: Error, CustomStringConvertible, LocalizedError {
        case nameContainsPathSeparators
        case nameIsEmpty
        case fileAlreadyExists(URL)
        case fileNotFound(URL)
        case sourceWriteFailed(underlying: Error)
        case sourceVerificationFailed(URL)
        case sourceIsNotUTF8(URL)
        case pathEscapesVault(URL)
        case reservedCachePath(URL)

        public var description: String {
            switch self {
            case .nameContainsPathSeparators:
                "CodeFileService: file name must not contain a path separator"
            case .nameIsEmpty:
                "CodeFileService: file name is empty"
            case let .fileAlreadyExists(url):
                "CodeFileService: file already exists at \(url.path)"
            case let .fileNotFound(url):
                "CodeFileService: file not found at \(url.path)"
            case let .sourceWriteFailed(error):
                "CodeFileService: failed to write source: \(error)"
            case let .sourceVerificationFailed(url):
                "CodeFileService: source write verification failed at \(url.path)"
            case let .sourceIsNotUTF8(url):
                "CodeFileService: source is not valid UTF-8 at \(url.path)"
            case let .pathEscapesVault(url):
                "CodeFileService: path escapes vault containment: \(url.path)"
            case let .reservedCachePath(url):
                "CodeFileService: source path is inside reserved vault storage: \(url.path)"
            }
        }

        public var errorDescription: String? { description }
    }

    public let vaultRoot: URL
    private let fileManager: FileManager

    public init(vaultRoot: URL, fileManager: FileManager = .default) {
        self.vaultRoot = vaultRoot
        self.fileManager = fileManager
    }

    public static func readCodeFileAsync(at fileURL: URL, vaultRoot: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try CodeFileService(vaultRoot: vaultRoot).readCodeFile(at: fileURL)
        }.value
    }

    public static func updateCodeFileAsync(
        at fileURL: URL,
        vaultRoot: URL,
        body: String
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try CodeFileService(vaultRoot: vaultRoot).updateCodeFile(at: fileURL, body: body)
        }.value
    }

    @discardableResult
    public func createCodeFile(
        relativeDirectory: String,
        name: String,
        kind: CodeArtifactKind,
        body: String? = nil
    ) throws -> URL {
        let validatedName = try Self.validate(name: name)
        let fileURL = try containedCreateURL(
            relativeDirectory: relativeDirectory,
            fileName: "\(validatedName).\(kind.primaryExtension)"
        )
        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw ServiceError.fileAlreadyExists(fileURL)
        }
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let content = body ?? kind.newFileTemplate(name: validatedName)
            try AtomicVaultWriter.writeSynchronously(content, to: fileURL)
            try verifySourceWrite(Data(content.utf8), at: fileURL)
            return fileURL
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }
    }

    public func readCodeFile(at fileURL: URL) throws -> String {
        let contained = try containedSourceURL(fileURL)
        guard fileManager.fileExists(atPath: contained.path) else {
            throw ServiceError.fileNotFound(contained)
        }
        do {
            let data = try Data(contentsOf: contained)
            guard let body = String(data: data, encoding: .utf8) else {
                throw ServiceError.sourceIsNotUTF8(contained)
            }
            return body
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }
    }

    public func updateCodeFile(at fileURL: URL, body: String) throws {
        let contained = try containedSourceURL(fileURL)
        guard fileManager.fileExists(atPath: contained.path) else {
            throw ServiceError.fileNotFound(contained)
        }
        do {
            try AtomicVaultWriter.writeSynchronously(body, to: contained)
            try verifySourceWrite(Data(body.utf8), at: contained)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }
    }

    private func containedCreateURL(relativeDirectory: String, fileName: String) throws -> URL {
        let directory = try normalizedVaultRelativePath(relativeDirectory, allowEmpty: true)
        return try containedSourceURL(
            canonicalVaultRoot()
                .appendingPathComponent(directory, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
        )
    }

    private func containedSourceURL(_ candidate: URL) throws -> URL {
        let root = canonicalVaultRoot()
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = root.path
        let filePath = resolved.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            throw ServiceError.pathEscapesVault(resolved)
        }
        let relativePath = String(filePath.dropFirst(prefix.count))
        guard relativePath != ".epcache", !relativePath.hasPrefix(".epcache/") else {
            throw ServiceError.reservedCachePath(resolved)
        }
        return resolved
    }

    private func normalizedVaultRelativePath(_ path: String, allowEmpty: Bool) throws -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if allowEmpty { return "" }
            throw ServiceError.pathEscapesVault(vaultRoot)
        }
        guard !trimmed.hasPrefix("/"), !trimmed.hasPrefix("\\") else {
            throw ServiceError.pathEscapesVault(URL(fileURLWithPath: trimmed))
        }
        let components = trimmed.split(whereSeparator: { $0 == "/" || $0 == "\\" })
        guard components.allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw ServiceError.pathEscapesVault(vaultRoot.appendingPathComponent(trimmed))
        }
        return components.joined(separator: "/")
    }

    private func canonicalVaultRoot() -> URL {
        vaultRoot.resolvingSymlinksInPath().standardizedFileURL
    }

    private func verifySourceWrite(_ expected: Data, at url: URL) throws {
        let written: Data
        do {
            written = try Data(contentsOf: url)
        } catch {
            throw ServiceError.sourceWriteFailed(underlying: error)
        }
        guard written == expected else {
            throw ServiceError.sourceVerificationFailed(url)
        }
    }

    private static func validate(name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.nameIsEmpty }
        guard !trimmed.contains("/"), !trimmed.contains("\\") else {
            throw ServiceError.nameContainsPathSeparators
        }
        return trimmed
    }
}
