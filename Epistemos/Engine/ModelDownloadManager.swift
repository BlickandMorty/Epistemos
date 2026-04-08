import Foundation
import HuggingFace

actor ModelDownloadManager: LocalModelArtifactInstalling {
    private let fileManager = FileManager.default
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 4 * 60 * 60
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
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

        var activated = false
        defer {
            if !activated, fileManager.fileExists(atPath: stagingDirectory.path) {
                try? fileManager.removeItem(at: stagingDirectory)
            }
        }

        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        _ = try await client.downloadSnapshot(
            of: repoID,
            kind: .model,
            to: stagingDirectory,
            revision: descriptor.revision,
            matching: descriptor.matchingGlobs,
            progressHandler: progressHandler
        )

        try verifySnapshot(at: stagingDirectory, descriptor: descriptor)
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
            sizeBytes: directorySize
        )
    }

    private func makeClient(cache: HubCache) -> HubClient {
        return HubClient(session: session, cache: cache)
    }

    private func verifySnapshot(at directory: URL, descriptor: LocalModelDescriptor) throws {
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

        let hasConfig = contents.contains { $0.lastPathComponent == "config.json" }
        let hasWeights = contents.contains { url in
            guard url.pathExtension == "safetensors" else { return false }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return size > 0
        }
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
