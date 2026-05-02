import Foundation
import os

/// Production scheduler shell for projecting committed mutation envelopes into
/// the Rust OpLog. Projection semantics stay inside `MutationOpLogProjector`;
/// this type only owns path resolution, lazy client creation, and coalescing.
nonisolated final class MutationOpLogProjectionWorker: @unchecked Sendable {
    private static let log = Logger(subsystem: "com.epistemos", category: "MutationOpLogProjectionWorker")

    private let eventStore: EventStore
    private let databaseURL: URL
    private let actorID: String
    private let workerID: String
    private let defaultBatchLimit: Int
    private let leaseDuration: TimeInterval
    private let retryDelay: TimeInterval
    private let maxAttempts: Int?
    private let stateLock = NSLock()
    private var drainInFlight = false

    init(
        eventStore: EventStore,
        databaseURL: URL,
        actorID: String = "epistemos-mutation-oplog",
        workerID: String = "mutation-oplog-projection-worker",
        defaultBatchLimit: Int = 100,
        leaseDuration: TimeInterval = 30,
        retryDelay: TimeInterval = 60,
        maxAttempts: Int? = 5
    ) {
        self.eventStore = eventStore
        self.databaseURL = databaseURL
        self.actorID = actorID
        self.workerID = workerID
        self.defaultBatchLimit = Self.normalizedBatchLimit(defaultBatchLimit)
        self.leaseDuration = leaseDuration
        self.retryDelay = retryDelay
        self.maxAttempts = maxAttempts
    }

    static func databaseURL(applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("mutation-oplog.sqlite", isDirectory: false)
    }

    func drainOnce(limit: Int? = nil) throws -> MutationOpLogProjectionResult {
        let client = try makeOpLogClient()
        let projector = MutationOpLogProjector(
            eventStore: eventStore,
            opLog: client,
            workerID: workerID,
            leaseDuration: leaseDuration,
            retryDelay: retryDelay,
            maxAttempts: maxAttempts
        )
        return try projector.projectPending(limit: Self.normalizedBatchLimit(limit ?? defaultBatchLimit))
    }

    func scheduleDrain(
        reason: String,
        priority: TaskPriority = .utility
    ) {
        guard beginDrain() else {
            Self.log.debug(
                "OpLog projection drain coalesced for \(reason, privacy: .public)"
            )
            return
        }

        Task.detached(priority: priority) { [self] in
            defer { finishDrain() }

            do {
                let result = try drainOnce()
                guard result.scanned > 0 else { return }
                Self.log.info(
                    """
                    OpLog projection drain \(reason, privacy: .public) scanned \
                    \(result.scanned, privacy: .public), appended \
                    \(result.appended, privacy: .public), marked \
                    \(result.marked, privacy: .public)
                    """
                )
            } catch {
                Self.log.error(
                    "OpLog projection drain \(reason, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func makeOpLogClient() throws -> RustOpLogFFIClient {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return try RustOpLogFFIClient(databaseURL: databaseURL, actorID: actorID)
    }

    private func beginDrain() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !drainInFlight else { return false }
        drainInFlight = true
        return true
    }

    private func finishDrain() {
        stateLock.lock()
        drainInFlight = false
        stateLock.unlock()
    }

    private static func normalizedBatchLimit(_ limit: Int) -> Int {
        min(max(1, limit), 10_000)
    }
}
