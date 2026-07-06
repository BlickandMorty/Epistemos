import Foundation

enum MaterializationState: Sendable {
    case notUbiquitous
    case alreadyLocal
    case downloading
    case failed(Error)
}

actor iCloudMaterializer {
    static let shared = iCloudMaterializer()

    private final class QueryHandle: @unchecked Sendable {
        let query: NSMetadataQuery

        init(_ query: NSMetadataQuery) {
            self.query = query
        }
    }

    private let queryQueue = OperationQueue()
    private var waiters: [String: [CheckedContinuation<Void, Error>]] = [:]
    private var query: NSMetadataQuery?

    init() {
        queryQueue.maxConcurrentOperationCount = 1
    }

    func state(of url: URL) -> MaterializationState {
        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return .notUbiquitous
        }
        guard values.isUbiquitousItem == true else { return .notUbiquitous }

        switch values.ubiquitousItemDownloadingStatus {
        case .some(.current), .some(.downloaded):
            return .alreadyLocal
        case .some(.notDownloaded), .none:
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                return .downloading
            } catch {
                return .failed(error)
            }
        default:
            return .alreadyLocal
        }
    }

    func whenLocal(_ url: URL, timeout: Duration = .seconds(30)) async throws {
        switch state(of: url) {
        case .notUbiquitous, .alreadyLocal:
            return
        case .failed(let error):
            throw error
        case .downloading:
            break
        }

        ensureQueryRunning()
        let key = url.standardizedFileURL.path

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await withCheckedThrowingContinuation { continuation in
                    Task { await self?.enqueueWaiter(key: key, continuation: continuation) }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CancellationError()
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    func evict(_ url: URL) throws {
        try FileManager.default.evictUbiquitousItem(at: url)
    }

    private func enqueueWaiter(key: String, continuation: CheckedContinuation<Void, Error>) {
        if case .alreadyLocal = state(of: URL(fileURLWithPath: key)) {
            continuation.resume()
            return
        }
        waiters[key, default: []].append(continuation)
    }

    private func ensureQueryRunning() {
        guard query == nil else { return }
        let q = NSMetadataQuery()
        q.operationQueue = queryQueue
        q.searchScopes = [
            NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope,
            NSMetadataQueryUbiquitousDocumentsScope,
        ]
        q.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        let queryHandle = QueryHandle(q)

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: q,
            queue: queryQueue
        ) { [weak self, queryHandle] _ in
            guard let self else { return }
            let keys = Self.materializedKeys(in: queryHandle.query)
            self.scheduleMaterializedKeys(keys)
        }

        q.start()
        query = q
    }

    nonisolated private func scheduleMaterializedKeys(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        Task { await handleMaterializedKeys(keys) }
    }

    nonisolated private static func materializedKeys(in q: NSMetadataQuery) -> [String] {
        q.disableUpdates()
        defer { q.enableUpdates() }

        var keys: [String] = []
        keys.reserveCapacity(q.resultCount)
        for i in 0..<q.resultCount {
            guard let item = q.result(at: i) as? NSMetadataItem else { continue }
            guard
                let status = item.value(
                    forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey
                ) as? String,
                status == NSMetadataUbiquitousItemDownloadingStatusCurrent
            else { continue }

            guard let itemURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL
            else { continue }

            keys.append(itemURL.standardizedFileURL.path)
        }
        return keys
    }

    private func handleMaterializedKeys(_ keys: [String]) {
        for key in keys {
            if let pending = waiters.removeValue(forKey: key) {
                pending.forEach { $0.resume() }
            }
        }
    }
}
