import Foundation
import CryptoKit
import HuggingFace

actor ModelDownloadManager: LocalModelArtifactInstalling {
    private let fileManager = FileManager.default
    private let session: URLSession
    private let checksumChunkSize = 8 * 1024 * 1024

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 4 * 60 * 60
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            // Drop the default 20 MB-mem / 150 MB-disk URL cache —
            // we already opt out of cache reads via the policy above,
            // and HF model downloads are GB-scale (no benefit) but
            // would still anchor the cache header table in memory.
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    func install(
        descriptor: LocalModelDescriptor,
        paths: LocalModelPaths,
        progressHandler: (@MainActor @Sendable (Progress) -> Void)?
    ) async throws -> LocalModelInstallRecord {
        try paths.ensureBaseDirectories(fileManager: fileManager)

        guard let repoID = Repo.ID(rawValue: descriptor.id) else {
            throw LocalModelManagerError.unknownModel(descriptor.id)
        }
        let stagingDirectory = paths.uniqueStagingDirectory(for: descriptor)
        let activeDirectory = paths.activeDirectory(for: descriptor)
        let cache = HubCache(cacheDirectory: paths.hubDirectory(for: descriptor.kind))
        let client = makeClient(cache: cache)
        let requestedGlobs = Array(
            Set(descriptor.matchingGlobs + ["model.safetensors"])
        ).sorted()

        var activated = false
        defer {
            if !activated, fileManager.fileExists(atPath: stagingDirectory.path) {
                do {
                    try fileManager.removeItem(at: stagingDirectory)
                } catch {
                    Log.engine.error(
                        "ModelDownloadManager: failed to clean staging directory \(stagingDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        _ = try await client.downloadSnapshot(
            of: repoID,
            kind: .model,
            to: stagingDirectory,
            revision: descriptor.revision,
            matching: requestedGlobs,
            progressHandler: progressHandler
        )

        let snapshot = try verifySnapshot(at: stagingDirectory, descriptor: descriptor)
        let checksumVerification = try await verifyChecksums(
            for: snapshot.weightFiles,
            in: stagingDirectory,
            descriptor: descriptor,
            repoID: repoID,
            client: client
        )
        let directorySize = try byteSize(of: stagingDirectory)
        try fileManager.createDirectory(
            at: activeDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: activeDirectory.path) {
            _ = try fileManager.replaceItemAt(activeDirectory, withItemAt: stagingDirectory)
        } else {
            try fileManager.moveItem(at: stagingDirectory, to: activeDirectory)
        }
        activated = true

        return LocalModelInstallRecord(
            modelID: descriptor.id,
            kind: descriptor.kind,
            activeDirectoryPath: activeDirectory.path,
            revision: descriptor.revision,
            installedAt: Date(),
            sizeBytes: directorySize,
            checksumVerification: checksumVerification
        )
    }

    private func makeClient(cache: HubCache) -> HubClient {
        return HubClient(session: session, cache: cache)
    }

    /// The weight-file extension for a runtime. GGUF models are a single self-contained
    /// `.gguf` file; MLX / Transformers models ship sharded `.safetensors`. Counting only
    /// `.safetensors` made a complete GGUF download look weightless → a false
    /// "invalid/corrupted" reject (the artifact-validation hardening regression that broke
    /// GGUF installs). Pure + static so it is unit-testable without the actor / filesystem.
    nonisolated static func weightFileExtension(for runtimeKind: BackendRuntimeKind) -> String {
        runtimeKind == .gguf ? "gguf" : "safetensors"
    }

    /// Whether a runtime requires the HuggingFace sidecar files (`config.json` + a tokenizer).
    /// A GGUF file embeds its config + tokenizer, so a GGUF repo legitimately ships neither —
    /// requiring them falsely rejects a complete GGUF download. MLX/Transformers still need them.
    nonisolated static func requiresSidecarConfigAndTokenizer(for runtimeKind: BackendRuntimeKind) -> Bool {
        runtimeKind != .gguf
    }

    private func verifySnapshot(at directory: URL, descriptor: LocalModelDescriptor) throws -> SnapshotValidation {
        // Allow both full 40-char SHA revisions and branch names like "main"
        let isValidRevision = descriptor.revision == "main"
            || descriptor.revision.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil
        guard isValidRevision else {
            throw LocalModelManagerError.invalidInstall(descriptor.id)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        let runtimeKind = descriptor.runtimeKind
        let weightFiles = try modelWeightFiles(in: directory, runtimeKind: runtimeKind)
        let hasWeights = !weightFiles.isEmpty

        // GGUF: a present, non-empty `.gguf` weight IS a complete install (config + tokenizer
        // are embedded). Requiring the safetensors-era sidecars here is what reported a good
        // GGUF download as "corrupted / not complete".
        guard Self.requiresSidecarConfigAndTokenizer(for: runtimeKind) else {
            guard hasWeights else {
                throw LocalModelManagerError.invalidInstall(descriptor.id)
            }
            return SnapshotValidation(weightFiles: weightFiles)
        }

        let hasConfig = contents.contains { $0.lastPathComponent == "config.json" }
        let hasTokenizer = contents.contains { url in
            [
                "tokenizer.json",
                "tokenizer.model",
                "vocab.json",
            ].contains(url.lastPathComponent)
        }

        guard hasConfig, hasWeights, hasTokenizer else {
            throw LocalModelManagerError.invalidInstall(descriptor.id)
        }
        return SnapshotValidation(weightFiles: weightFiles)
    }

    private func modelWeightFiles(in directory: URL, runtimeKind: BackendRuntimeKind) throws -> [URL] {
        let weightExtension = Self.weightFileExtension(for: runtimeKind)
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == weightExtension else { continue }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { continue }
            files.append(file)
        }
        return files
    }

    private func verifyChecksums(
        for weightFiles: [URL],
        in directory: URL,
        descriptor: LocalModelDescriptor,
        repoID: Repo.ID,
        client: HubClient
    ) async throws -> LocalModelChecksumVerification {
        var verifiedCount = 0
        for file in weightFiles {
            let relativePath = try repositoryRelativePath(for: file, in: directory)
            let metadata: File
            do {
                metadata = try await client.getFile(
                    at: relativePath,
                    in: repoID,
                    kind: .model,
                    revision: descriptor.revision
                )
            } catch {
                return .unverifiedChecksum(
                    reason: "Remote SHA256/LFS checksum metadata could not be read for downloaded weight files."
                )
            }
            guard metadata.exists,
                  metadata.isLFS,
                  let expectedSHA256 = metadata.etag.flatMap(normalizedSHA256Hex) else {
                return .unverifiedChecksum(
                    reason: "No SHA256/LFS checksum metadata was available for downloaded weight files."
                )
            }

            let actualSHA256 = try sha256Hex(for: file)
            guard actualSHA256 == expectedSHA256 else {
                throw LocalModelManagerError.checksumMismatch(
                    modelID: descriptor.id,
                    file: relativePath
                )
            }
            verifiedCount += 1
        }

        guard verifiedCount == weightFiles.count, verifiedCount > 0 else {
            return .unverifiedChecksum(
                reason: "No SHA256/LFS checksum metadata was available for downloaded weight files."
            )
        }
        return .verifiedSHA256(fileCount: verifiedCount)
    }

    private func repositoryRelativePath(for file: URL, in directory: URL) throws -> String {
        let rootPath = directory.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            throw LocalModelManagerError.invalidInstall(directory.lastPathComponent)
        }
        return String(filePath.dropFirst(prefix.count))
    }

    private func normalizedSHA256Hex(_ etag: String) -> String? {
        var normalized = etag.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("W/") {
            normalized = String(normalized.dropFirst(2))
        }
        if normalized.hasPrefix("\""), normalized.hasSuffix("\"") {
            normalized = String(normalized.dropFirst().dropLast())
        }
        normalized = normalized.lowercased()
        guard normalized.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            return nil
        }
        return normalized
    }

    private func sha256Hex(for file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: checksumChunkSize) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func byteSize(of directory: URL) throws -> Int64 {
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        )
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

private struct SnapshotValidation: Sendable {
    let weightFiles: [URL]
}
