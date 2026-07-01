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
    enum Tier: String, CaseIterable, Sendable, Identifiable {
        /// Starter bundle: all seven duration models + the single 15s bucket.
        case standard
        /// Full bundle: every audio-length bucket and the full voice set.
        case highestQuality

        var id: String { rawValue }

        var title: String {
            switch self {
            case .standard: return "Standard"
            case .highestQuality: return "Highest quality"
            }
        }

        var detail: String {
            switch self {
            case .standard:
                return "Faster download, all seven duration models and the 15-second decoder. About 0.5 GB."
            case .highestQuality:
                return "Every audio-length bucket and the full voice set for the best quality. About 1 GB."
            }
        }

        /// Approximate on-disk size, for the pre-download prompt only.
        var approximateByteCount: Int64 {
            switch self {
            case .standard: return 500_000_000
            case .highestQuality: return 1_050_000_000
            }
        }

        /// Repo-relative path of the `KokoroRuntimeManifest.json` for this tier.
        var manifestRepositoryPath: String {
            switch self {
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

        let manifestData = try await fetchData(
            repositoryPath: tier.manifestRepositoryPath,
            revision: "main",
            maxBytes: maxManifestBytes
        )
        guard let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] else {
            throw DownloadError.invalidManifest
        }
        let revision = (manifest["hf_revision"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "main"
        let declaredFiles = try declaredFiles(from: manifest)
        guard !declaredFiles.isEmpty else { throw DownloadError.invalidManifest }
        let totalBytes = declaredFiles.reduce(Int64(0)) { $0 + $1.bytes }

        let stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("kokoro-download-\(UUID().uuidString)", isDirectory: true)
        let stagingModelDirectory = stagingRoot.appendingPathComponent(
            KokoroVoiceGateStatus.modelDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingModelDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }

        try manifestData.write(
            to: stagingModelDirectory.appendingPathComponent(KokoroVoiceGateStatus.manifestFileName)
        )

        var received: Int64 = 0
        progress(received, totalBytes)
        for file in declaredFiles {
            try Task.checkCancellation()
            let destination = stagingModelDirectory.appendingPathComponent(file.relativePath, isDirectory: false)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let digest = try await downloadFile(
                repositoryPath: file.relativePath,
                revision: revision,
                destination: destination,
                fileManager: fileManager
            )
            guard digest == file.sha256 else {
                throw DownloadError.checksumMismatch(file.relativePath)
            }
            received += file.bytes
            progress(received, totalBytes)
        }

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
    ) async throws -> Data {
        let url = try resolveURL(repositoryPath: repositoryPath, revision: revision)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DownloadError.httpFailure(repositoryPath)
        }
        guard data.count <= maxBytes else { throw DownloadError.invalidManifest }
        return data
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

    nonisolated private static func declaredFiles(from manifest: [String: Any]) throws -> [DeclaredFile] {
        var files: [DeclaredFile] = []

        func append(path: String, bytes bytesValue: Any?, sha shaValue: Any?) throws {
            guard let bytes = int64Value(bytesValue), bytes > 0,
                  let sha = (shaValue as? String)?.lowercased(), !sha.isEmpty else {
                throw DownloadError.invalidManifest
            }
            files.append(DeclaredFile(relativePath: path, bytes: bytes, sha256: sha))
        }

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
                try append(path: "\(packagePath)/\(relative)", bytes: file["bytes"], sha: file["sha256"])
            }
        }

        guard let voices = manifest["voices"] as? [[String: Any]], !voices.isEmpty else {
            throw DownloadError.invalidManifest
        }
        for voice in voices {
            guard let path = voice["path"] as? String else { throw DownloadError.invalidManifest }
            try append(path: path, bytes: voice["bytes"], sha: voice["sha256"])
        }

        guard let runtimeAssets = manifest["runtime_assets"] as? [String: Any] else {
            throw DownloadError.invalidManifest
        }
        for key in ["vocab", "hnsf_weights"] {
            guard let asset = runtimeAssets[key] as? [String: Any], let path = asset["path"] as? String else {
                throw DownloadError.invalidManifest
            }
            try append(path: path, bytes: asset["bytes"], sha: asset["sha256"])
        }

        return files
    }

    nonisolated private static func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? Int64 { return number }
        if let number = value as? Int { return Int64(number) }
        if let number = value as? NSNumber { return number.int64Value }
        return nil
    }
}
