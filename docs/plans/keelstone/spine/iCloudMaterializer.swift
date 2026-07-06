//
//  iCloudMaterializer.swift
//  Epistemos — KEELSTONE spine
//
//  ⚠️ THIS FILE EXISTS TO REPLACE A LANDMINE.
//
//  One of the source dossiers proposed materializing an undownloaded iCloud file
//  like this:
//
//      try FileManager.default.startDownloadingUbiquitousItem(at: url)
//      while url.resourceValues(...).ubiquitousItemDownloadingStatus != .current {
//          Thread.sleep(forTimeInterval: 0.1)   // ⬅ blocking poll, up to 15s
//      }
//
//  Do not ship that. Blocking a thread (worse, a coordination queue) for up to
//  15 seconds while holding file interest is exactly the pattern that gets a
//  suspended process watchdog-killed, beachballs the UI if it ever touches the
//  main actor, and burns a coordination slot the sync daemon may need. The
//  correct macOS pattern is asynchronous: kick the download, then let
//  NSMetadataQuery tell you when it's local. No spinning.
//
//  Detection of a dataless placeholder uses URLResourceValues:
//    .isUbiquitousItemKey                 — is this an iCloud item at all
//    .ubiquitousItemDownloadingStatusKey  — .current / .downloaded / .notDownloaded
//
//  KEELSTONE-REVIEW (2026-07-06) — fixes applied to the original skeleton:
//   1. SCOPE BUG: NSMetadataQueryUbiquitousDocumentsScope only covers the app's
//      OWN iCloud container. Epistemos vaults are USER-SELECTED folders — an
//      iCloud Drive vault is an "external document" reached via a security-
//      scoped bookmark, which needs
//      NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope. Both scopes
//      are now set (own-container future-proofing + external documents).
//   2. Correctness note: even if whenLocal times out or the query misses,
//      hydration completion writes real bytes → FSEvents fires a change → the
//      reconciler retries. whenLocal is a LATENCY optimization; correctness
//      never depends on it.
//   3. evictUbiquitousItem must NOT be called from inside an active
//      NSFileCoordinator block (self-deadlock) — evict() stays outside
//      coordination, as documented.
//

import Foundation

public enum MaterializationState: Sendable {
    case notUbiquitous     // plain local file — read it directly
    case alreadyLocal      // ubiquitous and .current — read it directly
    case downloading       // request issued; completion arrives async
    case failed(Error)
}

public actor iCloudMaterializer {

    private let queryQueue = OperationQueue()
    // standardized path -> continuations awaiting that file becoming local
    private var waiters: [String: [CheckedContinuation<Void, Error>]] = [:]
    private var query: NSMetadataQuery?

    public init() {
        queryQueue.maxConcurrentOperationCount = 1
    }

    /// Non-blocking probe. Reader code calls this first; only `.downloading`
    /// requires awaiting `whenLocal`.
    public func state(of url: URL) -> MaterializationState {
        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
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

    /// Await a file becoming local, WITHOUT polling. Backed by NSMetadataQuery
    /// change notifications. Times out so a stuck iCloud item can't wedge a
    /// reconcile forever — but the timeout doesn't block a thread, it just
    /// resumes the awaiting Task with a failure.
    public func whenLocal(_ url: URL, timeout: Duration = .seconds(30)) async throws {
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
                throw CancellationError() // timeout path — no thread was blocked
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    private func enqueueWaiter(key: String, continuation: CheckedContinuation<Void, Error>) {
        // Re-check under actor isolation in case it landed between probe and enqueue.
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
        // KEELSTONE-REVIEW: user-selected iCloud Drive vaults are EXTERNAL
        // documents (reached via security-scoped bookmark) — the external-
        // documents scope is what actually covers them. Own-container scope
        // kept for any future app-container documents.
        q.searchScopes = [
            NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope,
            NSMetadataQueryUbiquitousDocumentsScope
        ]
        q.predicate = NSPredicate(
            format: "%K LIKE '*'", NSMetadataItemFSNameKey
        )

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: q,
            queue: queryQueue
        ) { [weak self] note in
            Task { await self?.handleQueryUpdate(note) }
        }

        q.start()
        query = q
    }

    private func handleQueryUpdate(_ note: Notification) {
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }

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

            let key = itemURL.standardizedFileURL.path
            if let pending = waiters.removeValue(forKey: key) {
                pending.forEach { $0.resume() }
            }
        }
    }

    /// Free local blocks for an item. Call OUTSIDE any coordination block.
    public func evict(_ url: URL) throws {
        try FileManager.default.evictUbiquitousItem(at: url)
    }
}
