import CryptoKit
import Foundation
import Observation
import OSLog

// Plan 1-MAS §2.1/§2.2 — the GGUF download manager: atomic download +
// checksum + resume; delete-on-corrupt; RAM- and disk-gated up front.
// Model revisions and LFS sha256 values are immutable catalog pins, verified
// locally before install. Runtime metadata from mutable `main` is never trusted.
// Weights land in the app container (Application Support/QuickChatModels),
// never Contents/Frameworks — data, not code (§4 2.5.2).

@MainActor
@Observable
final class QuickChatModelDownloadManager: NSObject {
    private nonisolated struct VerificationReceipt: Codable {
        let catalogID: String
        let repository: String
        let revision: String
        let fileName: String
        let byteCount: Int64
        let sha256: String
    }

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
    private var verificationTasks: [String: Task<Void, Never>] = [:]

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
            } else if let candidate = GGUFModelCatalog.unverifiedModelURL(for: entry) {
                guard verificationTasks[entry.id] == nil else { continue }
                states[entry.id] = .verifying
                verifyExistingModel(entry, at: candidate)
            } else if states[entry.id] == nil || states[entry.id] == .installed {
                states[entry.id] = .notInstalled
            }
        }
    }

    func beginDownload(_ entry: GGUFCatalogEntry) {
        guard activeTasks[entry.id] == nil else { return }
        switch state(for: entry) {
        case .installed, .downloading, .verifying:
            return
        case .notInstalled, .failed:
            break
        }

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
        startTask(entry: entry)
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
        verificationTasks.removeValue(forKey: entry.id)?.cancel()
        guard let url = GGUFModelCatalog.unverifiedModelURL(for: entry) else { return }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: Self.verificationReceiptURL(for: url))
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

    private nonisolated static func sha256OfFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            guard !Task.isCancelled else { return false }
            let chunk = handle.readData(ofLength: 8 * 1024 * 1024)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        if Task.isCancelled { throw CancellationError() }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func fileByteCount(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let number = attributes[.size] as? NSNumber else {
            throw CocoaError(.fileReadUnknown)
        }
        return number.int64Value
    }

    private nonisolated static func verificationReceiptURL(for modelURL: URL) -> URL {
        modelURL.appendingPathExtension("receipt.json")
    }

    nonisolated static func hasValidVerificationReceipt(
        for entry: GGUFCatalogEntry,
        modelURL: URL
    ) -> Bool {
        guard let byteCount = try? fileByteCount(at: modelURL),
              byteCount == entry.approxDownloadBytes,
              let data = try? Data(contentsOf: verificationReceiptURL(for: modelURL)),
              let receipt = try? JSONDecoder().decode(VerificationReceipt.self, from: data) else {
            return false
        }
        return receipt.catalogID == entry.id
            && receipt.repository == entry.huggingFaceRepo
            && receipt.revision == entry.revision
            && receipt.fileName == entry.fileName
            && receipt.byteCount == entry.approxDownloadBytes
            && receipt.sha256 == entry.sha256
    }

    private nonisolated static func writeVerificationReceipt(
        for entry: GGUFCatalogEntry,
        modelURL: URL
    ) throws {
        let receipt = VerificationReceipt(
            catalogID: entry.id,
            repository: entry.huggingFaceRepo,
            revision: entry.revision,
            fileName: entry.fileName,
            byteCount: entry.approxDownloadBytes,
            sha256: entry.sha256
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(receipt).write(
            to: verificationReceiptURL(for: modelURL),
            options: .atomic
        )
    }

    private func verifyExistingModel(_ entry: GGUFCatalogEntry, at modelURL: URL) {
        let task = Task.detached(priority: .utility) { [weak self] in
            do {
                let byteCount = try Self.fileByteCount(at: modelURL)
                guard byteCount == entry.approxDownloadBytes else {
                    throw QuickChatDownloadError.unexpectedFileSize(
                        expected: entry.approxDownloadBytes,
                        actual: byteCount
                    )
                }
                let actual = try Self.sha256OfFile(at: modelURL)
                guard actual == entry.sha256 else {
                    throw QuickChatDownloadError.checksumMismatch
                }
                try Self.writeVerificationReceipt(for: entry, modelURL: modelURL)
                await self?.finishExistingVerification(entryID: entry.id, error: nil)
            } catch is CancellationError {
                await self?.finishCancelledExistingVerification(entryID: entry.id)
            } catch {
                try? FileManager.default.removeItem(at: modelURL)
                try? FileManager.default.removeItem(at: Self.verificationReceiptURL(for: modelURL))
                await self?.finishExistingVerification(entryID: entry.id, error: error)
            }
        }
        verificationTasks[entry.id] = task
    }

    private func finishExistingVerification(entryID: String, error: Error?) {
        verificationTasks[entryID] = nil
        if let error {
            states[entryID] = .failed(Self.userCopy(for: error))
        } else {
            states[entryID] = .installed
            Self.log.info("Verified existing GGUF model against its pinned receipt contract: \(entryID, privacy: .public)")
        }
    }

    private func finishCancelledExistingVerification(entryID: String) {
        verificationTasks[entryID] = nil
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
        let expected = entry.sha256
        Task.detached(priority: .userInitiated) {
            do {
                let byteCount = try Self.fileByteCount(at: staging)
                guard byteCount == entry.approxDownloadBytes else {
                    throw QuickChatDownloadError.unexpectedFileSize(
                        expected: entry.approxDownloadBytes,
                        actual: byteCount
                    )
                }
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
                try? FileManager.default.removeItem(at: Self.verificationReceiptURL(for: destination))
                try FileManager.default.moveItem(at: staging, to: destination)
                try Self.writeVerificationReceipt(for: entry, modelURL: destination)
                await MainActor.run { [weak self] in
                    self?.states[entryID] = .installed
                    Self.log.info("Installed \(entry.fileName, privacy: .public) (sha256 verified)")
                }
            } catch {
                try? FileManager.default.removeItem(at: staging)
                await MainActor.run { [weak self] in
                    self?.states[entryID] = .failed(Self.userCopy(for: error))
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
        if (error as NSError).code == NSURLErrorCancelled {
            if case .failed = states[entryID] {
                resumeData[entryID] = nil
            } else if let resume {
                resumeData[entryID] = resume
            }
            return
        }
        resumeData[entryID] = nil
        states[entryID] = .failed(Self.userCopy(for: error))
    }

    private nonisolated static func userCopy(for error: Error) -> String {
        (error as? QuickChatDownloadError)?.userCopy
            ?? "Download failed: \(error.localizedDescription)"
    }
}

nonisolated private enum QuickChatDownloadError: Error {
    case checksumMismatch
    case unexpectedFileSize(expected: Int64, actual: Int64)

    var userCopy: String {
        switch self {
        case .checksumMismatch:
            return "The downloaded file didn't match its published checksum, so it was deleted. Try again."
        case .unexpectedFileSize:
            return "The downloaded file size didn't match the selected model, so it was deleted. Try again."
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
        guard let entryID = downloadTask.taskDescription else { return }
        if let entry = GGUFModelCatalog.entry(id: entryID),
           totalBytesWritten > entry.approxDownloadBytes
            || (totalBytesExpectedToWrite > 0
                && totalBytesExpectedToWrite != entry.approxDownloadBytes) {
            let error = QuickChatDownloadError.unexpectedFileSize(
                expected: entry.approxDownloadBytes,
                actual: max(totalBytesWritten, totalBytesExpectedToWrite)
            )
            downloadTask.cancel()
            Task { @MainActor in
                self.handleFailure(entryID: entryID, error: error, resume: nil)
            }
            return
        }
        guard totalBytesExpectedToWrite > 0 else { return }
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
