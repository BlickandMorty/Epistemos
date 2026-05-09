import Foundation
import OSLog

// MARK: - RustShadowFFIClient
//
// W9.21 PR4 — honest-FFI consumer cutover.
//
// This used to bind the legacy global-state surface (`shadow_open_at`,
// `shadow_search_json`, `shadow_insert_json`, ...). The consumer now
// owns an explicit per-instance handle from `shadow_handle_open_at`
// and dispatches every index operation through that handle. The global
// `shadow_warm` entry point remains because warming preloads the shared
// embedder singleton, not a per-vault backend.

@_silgen_name("shadow_handle_open_at")
nonisolated private func shadow_handle_open_at(
    _ path: UnsafePointer<CChar>?
) -> UnsafePointer<UInt8>?

@_silgen_name("shadow_handle_retain")
nonisolated private func shadow_handle_retain(
    _ handle: UnsafePointer<UInt8>?
)

@_silgen_name("shadow_handle_release")
nonisolated private func shadow_handle_release(
    _ handle: UnsafePointer<UInt8>?
)

@_silgen_name("shadow_handle_search")
nonisolated private func shadow_handle_search(
    _ handle: UnsafePointer<UInt8>?,
    _ query: UnsafePointer<CChar>?,
    _ domain: UnsafePointer<CChar>?,
    _ limit: Int,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("shadow_handle_insert")
nonisolated private func shadow_handle_insert(
    _ handle: UnsafePointer<UInt8>?,
    _ docJSON: UnsafePointer<CChar>?
) -> Int32

@_silgen_name("shadow_handle_remove")
nonisolated private func shadow_handle_remove(
    _ handle: UnsafePointer<UInt8>?,
    _ docId: UnsafePointer<CChar>?
) -> Int32

@_silgen_name("shadow_handle_flush")
nonisolated private func shadow_handle_flush(
    _ handle: UnsafePointer<UInt8>?
) -> Int32

@_silgen_name("shadow_handle_stats")
nonisolated private func shadow_handle_stats(
    _ handle: UnsafePointer<UInt8>?,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("shadow_handle_last_timings_json")
nonisolated private func shadow_handle_last_timings_json(
    _ handle: UnsafePointer<UInt8>?,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("shadow_handle_free_string")
nonisolated private func shadow_handle_free_string(
    _ ptr: UnsafeMutablePointer<CChar>?
)

@_silgen_name("shadow_warm")
nonisolated private func shadow_warm() -> Int32

@_silgen_name("etl_queue_stats_json")
nonisolated private func etl_queue_stats_json(
    _ path: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("etl_enqueue_vault_walk_json")
nonisolated private func etl_enqueue_vault_walk_json(
    _ vaultPath: UnsafePointer<CChar>?,
    _ queuePath: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("etl_run_worker_json")
nonisolated private func etl_run_worker_json(
    _ queuePath: UnsafePointer<CChar>?,
    _ maxJobs: UInt64
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("etl_queue_free_string")
nonisolated private func etl_queue_free_string(
    _ ptr: UnsafeMutablePointer<CChar>?
)

@inline(never)
nonisolated private func _shadow_keep_retain_alive() {
    shadow_handle_retain(nil)
}

/// Production `ShadowFFIClient` that talks to the Rust crate via the
/// honest-handle C ABI. Each instance owns one Rust handle and releases
/// it exactly once in `deinit`.
nonisolated public final class RustShadowFFIClient: ShadowFFIClient, @unchecked Sendable {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustShadowFFIClient"
    )

    private let handle: UnsafePointer<UInt8>

    /// Open (or create) a Shadow engine rooted at `path`. The W8.7
    /// AppBootstrap call site uses `<vault>/.epcache/shadow` so the
    /// index sits next to the other per-vault caches.
    public init(path: String) throws {
        let raw: UnsafePointer<UInt8>? = path.withCString { cstr in
            shadow_handle_open_at(cstr)
        }
        guard let raw else {
            Self.log.error(
                "shadow_handle_open_at returned null at \(path, privacy: .public)"
            )
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_open_at returned null at \(path)"
            )
        }
        self.handle = raw
        Self.log.info(
            "shadow_handle_open_at OK at \(path, privacy: .public)"
        )
    }

    deinit {
        shadow_handle_release(handle)
    }

    public func insert(document: ShadowDocumentDTO) throws {
        let data = try Self.encoder.encode(document)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ShadowFFIError.backendFailure(
                detail: "could not stringify ShadowDocumentDTO JSON for \(document.docId)"
            )
        }
        let code = json.withCString { cstr -> Int32 in
            shadow_handle_insert(handle, cstr)
        }
        if let error = ShadowFFIError.from(rustCode: code, detail: document.docId) {
            throw error
        }
    }

    public func remove(docId: String) throws {
        let code = docId.withCString { cstr -> Int32 in
            shadow_handle_remove(handle, cstr)
        }
        if let error = ShadowFFIError.from(rustCode: code, detail: docId) {
            throw error
        }
    }

    public func search(query: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] {
        var errorCode: Int32 = 0
        let cap = max(0, limit)
        let raw: UnsafeMutablePointer<CChar>? = query.withCString { qPtr in
            domain.wireValue.withCString { dPtr in
                shadow_handle_search(handle, qPtr, dPtr, cap, &errorCode)
            }
        }
        guard let cStr = raw else {
            if let typed = ShadowFFIError.from(
                rustCode: errorCode,
                detail: "query=\(query) domain=\(domain.wireValue)"
            ) {
                throw typed
            }
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_search returned null with code 0"
            )
        }
        defer { shadow_handle_free_string(cStr) }
        let json = String(cString: cStr)
        guard let data = json.data(using: .utf8) else {
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_search returned non-UTF8 payload"
            )
        }
        let dtos = try Self.decoder.decode([ShadowHitDTO].self, from: data)
        return dtos.map { $0.toModel() }
    }

    public func flush() throws {
        let code = shadow_handle_flush(handle)
        if let error = ShadowFFIError.from(rustCode: code) {
            throw error
        }
    }

    public func warm() throws {
        let code = shadow_warm()
        if let error = ShadowFFIError.from(rustCode: code) {
            Self.log.error("shadow_warm failed (code \(code))")
            throw error
        }
        Self.log.info("shadow_warm OK")
    }

    public func stats() throws -> ShadowStatsDTO {
        var errorCode: Int32 = 0
        guard let cStr = shadow_handle_stats(handle, &errorCode) else {
            if let typed = ShadowFFIError.from(rustCode: errorCode) {
                throw typed
            }
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_stats returned null with code 0"
            )
        }
        defer { shadow_handle_free_string(cStr) }
        let json = String(cString: cStr)
        guard let data = json.data(using: .utf8) else {
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_stats returned non-UTF8 payload"
            )
        }
        return try Self.decoder.decode(ShadowStatsDTO.self, from: data)
    }

    /// AMBIENT_RECALL_HALO_MASTER_PLAN §4 — read the per-stage timings
    /// of the most recent search through this handle. Returns
    /// `.empty` (all-zero) when no search has run yet, when the FFI
    /// errors, or when the JSON fails to decode — never throws.
    /// Callers (e.g. ShadowSearchService) treat all-zero as
    /// "no signal" and skip OSSignposter emission.
    public func lastSearchTimings() -> ShadowSearchTimings {
        var errorCode: Int32 = 0
        guard let cStr = shadow_handle_last_timings_json(handle, &errorCode) else {
            return .empty
        }
        defer { shadow_handle_free_string(cStr) }
        let json = String(cString: cStr)
        guard let data = json.data(using: .utf8) else {
            return .empty
        }
        return (try? Self.decoder.decode(ShadowSearchTimings.self, from: data)) ?? .empty
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = []
        return e
    }()

    private static let decoder = JSONDecoder()
}

// MARK: - ShadowHit Codable
//
// `ShadowHit` lives in Epistemos/Models/HaloState.swift and conforms
// to `Hashable`, but not yet `Codable`. The
// search FFI returns `Vec<ShadowHit>` JSON so we need a decoder.
// Rather than retroactively conform `ShadowHit` itself (and risk the
// project-wide ripple), we wrap it in a thin DTO and project to the
// public type in `RustShadowFFIClient.search`. The wire format
// matches the Rust `ShadowHit` field names / casing.

nonisolated private struct ShadowHitDTO: Decodable {
    let id: String
    let title: String
    let snippet: String
    let score: Float
    let domain: ShadowDomain
    let source: String

    enum CodingKeys: String, CodingKey {
        case id = "doc_id"
        case title
        case snippet
        case score
        case domain
        case source
    }

    nonisolated func toModel() -> ShadowHit {
        ShadowHit(
            id: id,
            title: title,
            snippet: snippet,
            score: score,
            domain: domain,
            source: source
        )
    }
}

// MARK: - RustEtlQueueStatsClient

nonisolated public struct EtlQueueStatsSnapshot: Codable, Equatable, Sendable {
    public let available: Bool
    public let total: UInt64
    public let pending: UInt64
    public let running: UInt64
    public let done: UInt64
    public let failed: UInt64
    public let killed: UInt64
    public let active: UInt64
    public let completed: UInt64
    public let error: String?

    public init(
        available: Bool,
        total: UInt64,
        pending: UInt64,
        running: UInt64,
        done: UInt64,
        failed: UInt64,
        killed: UInt64,
        active: UInt64,
        completed: UInt64,
        error: String?
    ) {
        self.available = available
        self.total = total
        self.pending = pending
        self.running = running
        self.done = done
        self.failed = failed
        self.killed = killed
        self.active = active
        self.completed = completed
        self.error = error
    }

    public static func unavailable(_ error: String) -> Self {
        Self(
            available: false,
            total: 0,
            pending: 0,
            running: 0,
            done: 0,
            failed: 0,
            killed: 0,
            active: 0,
            completed: 0,
            error: error
        )
    }
}

nonisolated public struct EtlQueueDispatchSnapshot: Codable, Equatable, Sendable {
    public let available: Bool
    public let total: UInt64
    public let queued: UInt64
    public let skipped: UInt64
    public let error: String?

    public init(
        available: Bool,
        total: UInt64,
        queued: UInt64,
        skipped: UInt64,
        error: String?
    ) {
        self.available = available
        self.total = total
        self.queued = queued
        self.skipped = skipped
        self.error = error
    }

    public static func unavailable(_ error: String) -> Self {
        Self(
            available: false,
            total: 0,
            queued: 0,
            skipped: 0,
            error: error
        )
    }
}

nonisolated public struct EtlQueueWorkerSnapshot: Codable, Equatable, Sendable {
    public let available: Bool
    public let requested: UInt64
    public let attempted: UInt64
    public let succeeded: UInt64
    public let failed: UInt64
    public let pendingBefore: UInt64
    public let pendingAfter: UInt64
    public let doneAfter: UInt64
    public let failedAfter: UInt64
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case available
        case requested
        case attempted
        case succeeded
        case failed
        case pendingBefore = "pending_before"
        case pendingAfter = "pending_after"
        case doneAfter = "done_after"
        case failedAfter = "failed_after"
        case error
    }

    public init(
        available: Bool,
        requested: UInt64,
        attempted: UInt64,
        succeeded: UInt64,
        failed: UInt64,
        pendingBefore: UInt64,
        pendingAfter: UInt64,
        doneAfter: UInt64,
        failedAfter: UInt64,
        error: String?
    ) {
        self.available = available
        self.requested = requested
        self.attempted = attempted
        self.succeeded = succeeded
        self.failed = failed
        self.pendingBefore = pendingBefore
        self.pendingAfter = pendingAfter
        self.doneAfter = doneAfter
        self.failedAfter = failedAfter
        self.error = error
    }

    public static func unavailable(_ error: String) -> Self {
        Self(
            available: false,
            requested: 0,
            attempted: 0,
            succeeded: 0,
            failed: 0,
            pendingBefore: 0,
            pendingAfter: 0,
            doneAfter: 0,
            failedAfter: 0,
            error: error
        )
    }
}

nonisolated public enum RustEtlQueueStatsClient {
    public static func stats(path: String) -> EtlQueueStatsSnapshot {
        let raw = path.withCString { cPath in
            etl_queue_stats_json(cPath)
        }
        guard let cString = raw else {
            return .unavailable("etl_queue_stats_json returned null")
        }
        defer { etl_queue_free_string(cString) }
        let json = String(cString: cString)
        guard let data = json.data(using: .utf8) else {
            return .unavailable("etl_queue_stats_json returned non-UTF8 payload")
        }
        do {
            return try decoder.decode(EtlQueueStatsSnapshot.self, from: data)
        } catch {
            return .unavailable("failed to decode ETL queue stats: \(error.localizedDescription)")
        }
    }

    private static let decoder = JSONDecoder()
}

nonisolated public enum RustEtlQueueWorkerClient {
    public static func run(queuePath: String, maxJobs: UInt64) -> EtlQueueWorkerSnapshot {
        let raw = queuePath.withCString { queueCString in
            etl_run_worker_json(queueCString, maxJobs)
        }
        guard let cString = raw else {
            return .unavailable("etl_run_worker_json returned null")
        }
        defer { etl_queue_free_string(cString) }
        let json = String(cString: cString)
        guard let data = json.data(using: .utf8) else {
            return .unavailable("etl_run_worker_json returned non-UTF8 payload")
        }
        do {
            return try decoder.decode(EtlQueueWorkerSnapshot.self, from: data)
        } catch {
            return .unavailable("failed to decode ETL worker result: \(error.localizedDescription)")
        }
    }

    private static let decoder = JSONDecoder()
}

nonisolated public enum RustEtlQueueDispatchClient {
    public static func enqueueVaultWalk(vaultPath: String, queuePath: String) -> EtlQueueDispatchSnapshot {
        let raw = vaultPath.withCString { vaultCString in
            queuePath.withCString { queueCString in
                etl_enqueue_vault_walk_json(vaultCString, queueCString)
            }
        }
        guard let cString = raw else {
            return .unavailable("etl_enqueue_vault_walk_json returned null")
        }
        defer { etl_queue_free_string(cString) }
        let json = String(cString: cString)
        guard let data = json.data(using: .utf8) else {
            return .unavailable("etl_enqueue_vault_walk_json returned non-UTF8 payload")
        }
        do {
            return try decoder.decode(EtlQueueDispatchSnapshot.self, from: data)
        } catch {
            return .unavailable("failed to decode ETL queue dispatch: \(error.localizedDescription)")
        }
    }

    private static let decoder = JSONDecoder()
}
