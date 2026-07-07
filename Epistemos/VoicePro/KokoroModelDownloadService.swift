import CryptoKit
import Foundation
import OSLog

/// Downloads a checked Kokoro Core ML voice bundle from the pinned upstream
/// Hugging Face repository (`mattmireles/kokoro-coreml`) and installs it through
/// the existing `KokoroVoicePackageInstaller`.
///
/// The path is pure `URLSession` + `CryptoKit` + `FileManager` — no Python, no
/// subprocess, no bundled model weights — so it is identical and legal on both
/// the MAS and Pro builds. Every file's SHA-256 is verified against the repo's
/// own `KokoroRuntimeManifest.json` before install, and the installer re-runs
/// the honest gate (`KokoroVoiceGateStatus`) on the staged and finalized bundle,
/// so a corrupt or tampered download can never flip the voice "ready".
@MainActor
@Observable
final class KokoroModelDownloadService {
    static let shared = KokoroModelDownloadService()

    /// Installable quality tiers. Each maps to a `KokoroRuntimeManifest.json`
    /// the upstream repo already ships; the app installs exactly what that
    /// manifest declares.
    nonisolated enum Tier: String, CaseIterable, Sendable, Identifiable {
        /// Starter SDK bundle: all seven duration models + the single 15s bucket.
        case starter
        /// Default hosted bundle; currently matches the upstream starter SDK manifest.
        case standard
        /// Full bundle: every audio-length bucket and the full voice set.
        case highestQuality

        var id: String { rawValue }

        var title: String {
            switch self {
            case .starter: return "Starter"
            case .standard: return "Standard"
            case .highestQuality: return "Highest quality"
            }
        }

        var detail: String {
            switch self {
            case .starter:
                return "Smallest upstream SDK manifest: seven voices and the 15-second decoder. \(approximateSizeLabel)."
            case .standard:
                return "Default upstream manifest; currently matches Starter with seven voices and the 15-second decoder. \(approximateSizeLabel)."
            case .highestQuality:
                return "Every audio-length bucket and the full voice set for the best quality. \(approximateSizeLabel)."
            }
        }

        /// Approximate on-disk size, for the pre-download prompt only.
        var approximateByteCount: Int64 {
            switch self {
            case .starter, .standard: return 477_043_213
            case .highestQuality: return 998_196_322
            }
        }

        var approximateSizeLabel: String {
            "About \(ByteCountFormatter.string(fromByteCount: approximateByteCount, countStyle: .file))"
        }

        /// Repo-relative path of the `KokoroRuntimeManifest.json` for this tier.
        var manifestRepositoryPath: String {
            switch self {
            case .starter: return "sdk/starter/KokoroRuntimeManifest.json"
            case .standard: return "KokoroRuntimeManifest.json"
            case .highestQuality: return "sdk/full/KokoroRuntimeManifest.json"
            }
        }
    }

    enum Phase: Equatable, Sendable {
        case idle
        case preparing
        case downloading(receivedBytes: Int64, totalBytes: Int64)
        case installing
        case installed
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var activeTier: Tier?
    private var runTask: Task<Void, Never>?

    private nonisolated static let repositoryID = "mattmireles/kokoro-coreml"
    private nonisolated static let maxManifestBytes = 512 * 1024
    private nonisolated static let hashChunkBytes = 1 * 1024 * 1024
    private nonisolated static let log = Logger(subsystem: "com.epistemos", category: "Voice.KokoroDownload")

    var isBusy: Bool {
        switch phase {
        case .preparing, .downloading, .installing:
            return true
        case .idle, .installed, .failed:
            return false
        }
    }

    /// Fractional download progress in [0, 1], or nil when not downloading.
    var downloadFraction: Double? {
        guard case let .downloading(received, total) = phase, total > 0 else { return nil }
        return min(1, max(0, Double(received) / Double(total)))
    }

    /// Begin downloading + installing `tier`. No-op while a run is in flight.
    func startInstall(tier: Tier) {
        guard !isBusy else { return }
        // Downloading is the user's explicit opt-in: enable the voice gate so
        // the installed bundle turns text-to-speech on (both MAS and Pro).
        FeatureGateOverride.set(true, forKey: KokoroVoiceGateStatus.flagName)
        activeTier = tier
        phase = .preparing
        runTask = Task { [weak self] in
            await self?.run(tier: tier)
        }
    }

    /// Cancel an in-flight run and return to idle.
    func cancel() {
        runTask?.cancel()
        runTask = nil
        if isBusy {
            phase = .idle
        }
        activeTier = nil
    }

    private func run(tier: Tier) async {
        let reportProgress: @Sendable (Int64, Int64) -> Void = { [weak self] received, total in
            Task { @MainActor in
                guard let self, self.isBusy else { return }
                self.phase = .downloading(receivedBytes: received, totalBytes: total)
            }
        }
        let reportInstalling: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                guard let self, self.isBusy else { return }
                self.phase = .installing
            }
        }

        do {
            _ = try await Self.downloadAndInstall(
                tier: tier,
                progress: reportProgress,
                installing: reportInstalling
            )
            phase = .installed
        } catch is CancellationError {
            phase = .idle
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Kokoro voice download failed."
            Self.log.error("Kokoro download failed: \(message, privacy: .public)")
            phase = .failed(message)
        }
        runTask = nil
        activeTier = nil
    }

    // MARK: - Worker (nonisolated: keeps hashing + file IO off the main actor)

    private struct DeclaredFile: Sendable {
        let relativePath: String
        let bytes: Int64
        let sha256: String
    }

    private struct ManifestDownload: Sendable {
        let data: Data
        let resolvedRevision: String?
    }

    enum DownloadError: Error, LocalizedError {
        case invalidManifest
        case invalidURL(String)
        case httpFailure(String)
        case checksumMismatch(String)

        var errorDescription: String? {
            switch self {
            case .invalidManifest:
                return "The Kokoro voice manifest could not be read."
            case .invalidURL(let path):
                return "The Kokoro download address was invalid (\(path))."
            case .httpFailure(let path):
                return "A Kokoro voice file could not be downloaded (\(path))."
            case .checksumMismatch(let path):
                return "A downloaded Kokoro file failed verification (\(path))."
            }
        }
    }

    @discardableResult
    nonisolated private static func downloadAndInstall(
        tier: Tier,
        progress: @escaping @Sendable (Int64, Int64) -> Void,
        installing: @escaping @Sendable () -> Void
    ) async throws -> KokoroVoiceGateStatus.Status {
        let fileManager = FileManager.default

        let manifestDownload = try await fetchData(
            repositoryPath: tier.manifestRepositoryPath,
            revision: "main",
            maxBytes: maxManifestBytes
        )
        guard var manifest = try? JSONSerialization.jsonObject(with: manifestDownload.data) as? [String: Any] else {
            throw DownloadError.invalidManifest
        }
        let revision = manifestDownload.resolvedRevision ?? "main"

        let requiredFiles = try requiredFiles(from: manifest)
        let voiceObjects = (manifest["voices"] as? [[String: Any]]) ?? []
        let voiceFiles = try voiceEntries(voiceObjects)
        guard voiceFiles.contains(where: { $0.relativePath == KokoroVoiceGateStatus.starterVoicePath }) else {
            throw DownloadError.invalidManifest
        }
        let totalBytes = (requiredFiles + voiceFiles).reduce(Int64(0)) { $0 + $1.bytes }

        let stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("kokoro-download-\(UUID().uuidString)", isDirectory: true)
        let stagingModelDirectory = stagingRoot.appendingPathComponent(
            KokoroVoiceGateStatus.modelDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingModelDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        var received: Int64 = 0
        progress(received, totalBytes)

        // Model packages + runtime assets are mandatory.
        for file in requiredFiles {
            try Task.checkCancellation()
            try await downloadVerified(file, revision: revision, into: stagingModelDirectory, fileManager: fileManager)
            received += file.bytes
            progress(received, totalBytes)
        }

        // Voices are best-effort: some upstream voices the manifest lists may not
        // exist at the pinned revision, so skip a missing non-starter voice rather
        // than fail the whole install. The starter voice (af_heart) is required.
        var installedVoicePaths = Set<String>()
        for file in voiceFiles {
            try Task.checkCancellation()
            do {
                try await downloadVerified(file, revision: revision, into: stagingModelDirectory, fileManager: fileManager)
                installedVoicePaths.insert(file.relativePath)
            } catch {
                if file.relativePath == KokoroVoiceGateStatus.starterVoicePath { throw error }
                log.notice("Skipping unavailable Kokoro voice \(file.relativePath, privacy: .public)")
            }
            received += file.bytes
            progress(received, totalBytes)
        }

        // Write a manifest that declares exactly the voices we installed, so the
        // installer's honest gate (which checks every declared file is present)
        // stays consistent even when some upstream voices were unavailable.
        manifest["voices"] = voiceObjects.filter { object in
            (object["path"] as? String).map(installedVoicePaths.contains) ?? false
        }
        let finalManifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        try finalManifestData.write(
            to: stagingModelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        )

        try Task.checkCancellation()
        installing()
        let result = try KokoroVoicePackageInstaller.installCheckedPackage(from: stagingRoot)
        return result.status
    }

    nonisolated private static func downloadFile(
        repositoryPath: String,
        revision: String,
        destination: URL,
        fileManager: FileManager
    ) async throws -> String {
        let url = try resolveURL(repositoryPath: repositoryPath, revision: revision)
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DownloadError.httpFailure(repositoryPath)
        }
        let digest = try sha256Hex(ofFileAt: temporaryURL)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        return digest
    }

    nonisolated private static func fetchData(
        repositoryPath: String,
        revision: String,
        maxBytes: Int
    ) async throws -> ManifestDownload {
        let url = try resolveURL(repositoryPath: repositoryPath, revision: revision)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DownloadError.httpFailure(repositoryPath)
        }
        guard data.count <= maxBytes else { throw DownloadError.invalidManifest }
        let resolvedRevision = resolvedRepositoryRevision(from: http)
        return ManifestDownload(data: data, resolvedRevision: resolvedRevision)
    }

    nonisolated private static func resolvedRepositoryRevision(from response: HTTPURLResponse) -> String? {
        if let header = response.value(forHTTPHeaderField: "X-Repo-Commit"),
           isHexSHA(header) {
            return header
        }
        guard let pathComponents = response.url?.pathComponents else {
            return nil
        }
        let repositoryComponents = repositoryID.split(separator: "/").map(String.init)
        guard repositoryComponents.count == 2 else { return nil }
        for index in pathComponents.indices {
            let nextIndex = pathComponents.index(after: index)
            guard nextIndex < pathComponents.endIndex,
                  pathComponents[index] == repositoryComponents[0],
                  pathComponents[nextIndex] == repositoryComponents[1] else {
                continue
            }
            let revisionIndex = pathComponents.index(after: nextIndex)
            guard revisionIndex < pathComponents.endIndex else { return nil }
            let candidate = pathComponents[revisionIndex]
            return isHexSHA(candidate) ? candidate : nil
        }
        return nil
    }

    nonisolated private static func isHexSHA(_ value: String) -> Bool {
        value.utf8.count == 40 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
        }
    }

    nonisolated private static func resolveURL(repositoryPath: String, revision: String) throws -> URL {
        let encodedPath = repositoryPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { segment in
                String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
            }
            .joined(separator: "/")
        let string = "https://huggingface.co/\(repositoryID)/resolve/\(revision)/\(encodedPath)"
        guard let url = URL(string: string) else {
            throw DownloadError.invalidURL(repositoryPath)
        }
        return url
    }

    nonisolated private static func sha256Hex(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: hashChunkBytes) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func downloadVerified(
        _ file: DeclaredFile,
        revision: String,
        into modelDirectory: URL,
        fileManager: FileManager
    ) async throws {
        let destination = modelDirectory.appendingPathComponent(file.relativePath, isDirectory: false)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let digest = try await downloadFileWithMainFallback(
            repositoryPath: file.relativePath,
            revision: revision,
            destination: destination,
            fileManager: fileManager
        )
        guard digest == file.sha256 else {
            throw DownloadError.checksumMismatch(file.relativePath)
        }
    }

    nonisolated private static func downloadFileWithMainFallback(
        repositoryPath: String,
        revision: String,
        destination: URL,
        fileManager: FileManager
    ) async throws -> String {
        do {
            return try await downloadFile(
                repositoryPath: repositoryPath,
                revision: revision,
                destination: destination,
                fileManager: fileManager
            )
        } catch DownloadError.httpFailure where revision != "main" {
            // The manifest is fetched from `main`, but Hugging Face resolve-cache
            // headers can briefly disagree with blob availability. Retry `main`;
            // checksum verification below still rejects stale or tampered bytes.
            log.notice("Retrying Kokoro file from main after resolved revision miss: \(repositoryPath, privacy: .public)")
            return try await downloadFile(
                repositoryPath: repositoryPath,
                revision: "main",
                destination: destination,
                fileManager: fileManager
            )
        }
    }

    nonisolated private static func requiredFiles(from manifest: [String: Any]) throws -> [DeclaredFile] {
        var files: [DeclaredFile] = []
        guard let packages = manifest["model_packages"] as? [[String: Any]], !packages.isEmpty else {
            throw DownloadError.invalidManifest
        }
        for package in packages {
            guard let packagePath = package["path"] as? String,
                  let packageFiles = package["files"] as? [[String: Any]] else {
                throw DownloadError.invalidManifest
            }
            for file in packageFiles {
                guard let relative = file["path"] as? String else { throw DownloadError.invalidManifest }
                files.append(try declaredFile(path: "\(packagePath)/\(relative)", bytes: file["bytes"], sha: file["sha256"]))
            }
        }
        guard let runtimeAssets = manifest["runtime_assets"] as? [String: Any] else {
            throw DownloadError.invalidManifest
        }
        for key in ["vocab", "hnsf_weights"] {
            guard let asset = runtimeAssets[key] as? [String: Any], let path = asset["path"] as? String else {
                throw DownloadError.invalidManifest
            }
            files.append(try declaredFile(path: path, bytes: asset["bytes"], sha: asset["sha256"]))
        }
        return files
    }

    nonisolated private static func voiceEntries(_ voiceObjects: [[String: Any]]) throws -> [DeclaredFile] {
        guard !voiceObjects.isEmpty else { throw DownloadError.invalidManifest }
        return try voiceObjects.map { object in
            guard let path = object["path"] as? String else { throw DownloadError.invalidManifest }
            return try declaredFile(path: path, bytes: object["bytes"], sha: object["sha256"])
        }
    }

    nonisolated private static func declaredFile(path: String, bytes: Any?, sha: Any?) throws -> DeclaredFile {
        guard let byteCount = int64Value(bytes), byteCount > 0,
              let digest = (sha as? String)?.lowercased(), !digest.isEmpty else {
            throw DownloadError.invalidManifest
        }
        return DeclaredFile(relativePath: path, bytes: byteCount, sha256: digest)
    }

    nonisolated private static func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? Int64 { return number }
        if let number = value as? Int { return Int64(number) }
        if let number = value as? NSNumber { return number.int64Value }
        return nil
    }
}
