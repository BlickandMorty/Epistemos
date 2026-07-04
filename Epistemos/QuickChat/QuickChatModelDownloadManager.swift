import CryptoKit
import Foundation
import Observation
import OSLog

// Plan 1-MAS §2.1/§2.2 — the GGUF download manager: atomic download +
// checksum + resume; delete-on-corrupt; RAM- and disk-gated up front.
// Checksums are pinned from the SAME origin as the artifact (the Hugging
// Face LFS metadata for the exact file) and verified locally before install.
// Weights land in the app container (Application Support/QuickChatModels),
// never Contents/Frameworks — data, not code (§4 2.5.2).

@MainActor
@Observable
final class QuickChatModelDownloadManager: NSObject {
    enum ModelState: Equatable {
        case notInstalled
        case downloading(progress: Double)
        case verifying
        case installed
        case failed(String)
    }

    private static let log = Logger(subsystem: "com.epistemos", category: "QuickChatDownload")

    private(set) var states: [String: ModelState] = [:]

    private var session: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var resumeData: [String: Data] = [:]
    private var expectedDigests: [String: String] = [:]

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        refreshInstalledStates()
    }

    func state(for entry: GGUFCatalogEntry) -> ModelState {
        states[entry.id] ?? .notInstalled
    }

    func refreshInstalledStates() {
        for entry in GGUFModelCatalog.entries {
            if GGUFModelCatalog.installedURL(for: entry) != nil {
                states[entry.id] = .installed
            } else if states[entry.id] == nil || states[entry.id] == .installed {
                states[entry.id] = .notInstalled
            }
        }
    }

    func beginDownload(_ entry: GGUFCatalogEntry) {
        guard activeTasks[entry.id] == nil else { return }
        if case .installed = state(for: entry) { return }

        // Honest gates BEFORE any bytes move (§2.2).
        if let ramProblem = GGUFModelCatalog.ramGate(for: entry) {
            states[entry.id] = .failed(ramProblem.userCopy)
            return
        }
        if let diskProblem = Self.diskGate(for: entry) {
            states[entry.id] = .failed(diskProblem)
            return
        }

        states[entry.id] = .downloading(progress: 0)
        Task { [self] in
            do {
                if expectedDigests[entry.id] == nil {
                    expectedDigests[entry.id] = try await fetchPublishedSHA256(for: entry)
                }
            } catch {
                Self.log.warning("No published sha256 for \(entry.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                states[entry.id] = .failed("Couldn't verify this model's published checksum. Try again.")
                return
            }
            startTask(entry: entry)
        }
    }

    func cancelDownload(_ entry: GGUFCatalogEntry) {
        guard let task = activeTasks[entry.id] else { return }
        task.cancel { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resumeData[entry.id] = data
                self.activeTasks[entry.id] = nil
                self.states[entry.id] = .notInstalled
            }
        }
    }

    func deleteInstalledModel(_ entry: GGUFCatalogEntry) {
        guard let url = GGUFModelCatalog.installedURL(for: entry) else { return }
        try? FileManager.default.removeItem(at: url)
        states[entry.id] = .notInstalled
    }

    // MARK: - Internals

    private func startTask(entry: GGUFCatalogEntry) {
        let task: URLSessionDownloadTask
        if let data = resumeData.removeValue(forKey: entry.id) {
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.downloadTask(with: entry.downloadURL)
        }
        task.taskDescription = entry.id
        activeTasks[entry.id] = task
        task.resume()
    }

    /// The published sha256 for the exact file, from the HF tree metadata.
    private func fetchPublishedSHA256(for entry: GGUFCatalogEntry) async throws -> String {
        struct TreeEntry: Decodable {
            struct LFS: Decodable { let oid: String }
            let path: String
            let lfs: LFS?
        }
        let (data, response) = try await URLSession.shared.data(from: entry.metadataURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let tree = try JSONDecoder().decode([TreeEntry].self, from: data)
        guard let match = tree.first(where: { $0.path == entry.fileName }), let lfs = match.lfs else {
            throw URLError(.resourceUnavailable)
        }
        return lfs.oid.lowercased()
    }

    private nonisolated static func sha256OfFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 8 * 1024 * 1024)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func diskGate(for entry: GGUFCatalogEntry) -> String? {
        guard let directory = try? GGUFModelCatalog.modelsDirectory(),
              let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let available = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        let needed = Int64(Double(entry.approxDownloadBytes) * 1.1)
        guard available < needed else { return nil }
        let neededGB = Double(needed) / 1_073_741_824
        return String(format: "Not enough free disk space — this model needs about %.1f GB.", neededGB)
    }

    fileprivate func handleFinishedDownload(entryID: String, movedTo staging: URL) {
        guard let entry = GGUFModelCatalog.entry(id: entryID) else { return }
        activeTasks[entryID] = nil
        states[entryID] = .verifying
        let expected = expectedDigests[entryID]
        Task.detached(priority: .userInitiated) {
            do {
                guard let expected else { throw URLError(.secureConnectionFailed) }
                let actual = try Self.sha256OfFile(at: staging)
                guard actual == expected else {
                    // Delete-on-corrupt (§2.1).
                    try? FileManager.default.removeItem(at: staging)
                    throw QuickChatDownloadError.checksumMismatch
                }
                let destination = try GGUFModelCatalog.modelsDirectory()
                    .appendingPathComponent(entry.fileName)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: staging, to: destination)
                await MainActor.run { [weak self] in
                    self?.states[entryID] = .installed
                    Self.log.info("Installed \(entry.fileName, privacy: .public) (sha256 verified)")
                }
            } catch {
                try? FileManager.default.removeItem(at: staging)
                let message = (error as? QuickChatDownloadError)?.userCopy
                    ?? "Download failed: \(error.localizedDescription)"
                await MainActor.run { [weak self] in
                    self?.states[entryID] = .failed(message)
                }
            }
        }
    }

    fileprivate func handleProgress(entryID: String, fraction: Double) {
        if case .downloading = states[entryID] ?? .notInstalled {
            states[entryID] = .downloading(progress: fraction)
        }
    }

    fileprivate func handleFailure(entryID: String, error: Error, resume: Data?) {
        activeTasks[entryID] = nil
        if let resume {
            resumeData[entryID] = resume
        }
        if (error as NSError).code == NSURLErrorCancelled { return }
        states[entryID] = .failed("Download failed: \(error.localizedDescription)")
    }
}

nonisolated private enum QuickChatDownloadError: Error {
    case checksumMismatch

    var userCopy: String {
        switch self {
        case .checksumMismatch:
            return "The downloaded file didn't match its published checksum, so it was deleted. Try again."
        }
    }
}

extension QuickChatModelDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let entryID = downloadTask.taskDescription else { return }
        // The delegate's temp file dies when this method returns — move it
        // synchronously to our own staging path first (atomic, same volume).
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("qc-model-\(entryID)-\(UUID().uuidString).part")
        do {
            try FileManager.default.moveItem(at: location, to: staging)
        } catch {
            Task { @MainActor in
                self.handleFailure(entryID: entryID, error: error, resume: nil)
            }
            return
        }
        Task { @MainActor in
            self.handleFinishedDownload(entryID: entryID, movedTo: staging)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let entryID = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.handleProgress(entryID: entryID, fraction: fraction)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, let entryID = task.taskDescription else { return }
        let resume = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        Task { @MainActor in
            self.handleFailure(entryID: entryID, error: error, resume: resume)
        }
    }
}
