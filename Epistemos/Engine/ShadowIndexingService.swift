import Foundation
import OSLog

// MARK: - ShadowIndexingService
//
// Wave 8.3 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"Concurrency").
//
// Per the V1 decision: "Indexing service: actor. Owns the dirty queue.
// Batches saves. Persists to .usearch and Tantivy on idle."
//
// This actor coalesces back-to-back document mutations into batched
// FFI calls so a flurry of edits doesn't translate to a flurry of
// `shadow_insert_json` round-trips. Idle persistence (`shadow_flush`)
// runs on a 500 ms debounce per the V1 budget.

/// Pending operation in the dirty queue. Insert + remove are a small
/// set so an enum is the right representation; later operations (e.g.
/// bulk reindex) can be added as new cases.
nonisolated public enum ShadowIndexingOp: Sendable, Hashable {
    case insert(document: ShadowDocumentDTO)
    case remove(docId: String)

    /// The doc_id this op targets — used by the queue's coalescer to
    /// drop earlier ops on the same id when a newer one supersedes it.
    public var docId: String {
        switch self {
        case .insert(let d): return d.docId
        case .remove(let id): return id
        }
    }
}

/// Idle persistence policy. The default 500 ms matches the V1 decision
/// §"Persistence" — `TransactionObserver` drives the dirty queue with
/// 500 ms debounce.
nonisolated public struct ShadowIndexingPolicy: Sendable, Hashable {
    public let flushDebounceMs: Int
    /// Max number of ops to coalesce before forcing a flush regardless
    /// of debounce. Prevents unbounded memory growth under sustained
    /// edit pressure.
    public let maxBatchSize: Int

    public init(flushDebounceMs: Int = 500, maxBatchSize: Int = 256) {
        self.flushDebounceMs = flushDebounceMs
        self.maxBatchSize = maxBatchSize
    }

    public static let `default` = ShadowIndexingPolicy()
}

/// Actor-isolated indexing service that owns the dirty queue and the
/// batched flush cadence. Designed so a typical editing session never
/// blocks the @MainActor controller — every queued op returns
/// immediately; the actual FFI work happens on the actor's
/// cooperative executor.
public actor ShadowIndexingService {
    private let client: any ShadowFFIClient
    private let policy: ShadowIndexingPolicy
    private let log = Logger(subsystem: "com.epistemos", category: "ShadowIndexingService")

    /// Pending ops keyed by doc_id so a later op on the same id
    /// supersedes an earlier one (coalescing).
    private var pending: [String: ShadowIndexingOp] = [:]
    private var flushTask: Task<Void, Never>?
    private var lastFlushAt: Date = .distantPast

    /// Cumulative counts of FFI calls made since process start. Used
    /// by tests + the developer panel to verify batching behaviour.
    public private(set) var totalInserts: Int = 0
    public private(set) var totalRemoves: Int = 0
    public private(set) var totalFlushes: Int = 0

    public init(
        client: any ShadowFFIClient,
        policy: ShadowIndexingPolicy = .default
    ) {
        self.client = client
        self.policy = policy
    }

    /// Enqueue an insert. Returns immediately; the actual FFI call
    /// happens on the next batched flush.
    public func enqueueInsert(_ document: ShadowDocumentDTO) {
        pending[document.docId] = .insert(document: document)
        scheduleFlush()
    }

    /// Enqueue a remove. Returns immediately; coalesces with any
    /// pending insert on the same doc_id (the remove wins).
    public func enqueueRemove(docId: String) {
        pending[docId] = .remove(docId: docId)
        scheduleFlush()
    }

    /// Force a flush of all pending ops. Used at app shutdown / explicit
    /// "Save" / before the V1 reliability gate verifies the on-disk index.
    public func flushNow() async {
        flushTask?.cancel()
        flushTask = nil
        await drain()
    }

    /// Drain the dirty queue into the FFI client. Errors are logged
    /// and recorded; one failed op doesn't block subsequent ops on
    /// other doc_ids.
    private func drain() async {
        // Snapshot + clear to release the queue while we run the FFI.
        let snapshot = Array(pending.values)
        pending.removeAll(keepingCapacity: true)

        for op in snapshot {
            do {
                switch op {
                case .insert(let doc):
                    try client.insert(document: doc)
                    totalInserts += 1
                case .remove(let id):
                    do {
                        try client.remove(docId: id)
                    } catch ShadowFFIError.notFound {
                        // Idempotent: removing a doc that was never
                        // inserted is fine in the dirty-queue context.
                    }
                    totalRemoves += 1
                }
            } catch {
                log.warning("shadow op failed: \(String(describing: op), privacy: .public) → \(String(describing: error), privacy: .public)")
            }
        }

        do {
            try client.flush()
            totalFlushes += 1
            lastFlushAt = Date()
        } catch {
            log.warning("shadow flush failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Schedule a debounced flush. If the pending count exceeds the
    /// max-batch-size cap, force a flush immediately (back-pressure).
    private func scheduleFlush() {
        if pending.count >= policy.maxBatchSize {
            flushTask?.cancel()
            flushTask = Task { [weak self] in
                await self?.drain()
            }
            return
        }
        if flushTask?.isCancelled == false {
            // Already scheduled — no-op so back-to-back enqueues
            // don't pile up timer tasks.
            return
        }
        let delay = UInt64(policy.flushDebounceMs) * 1_000_000
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            if Task.isCancelled { return }
            await self?.drain()
        }
    }
}
