import Foundation
import OSLog

// MARK: - RustShadowFFIClient
//
// W9.21 PR4 — Honest-FFI consumer cutover.
//
// This file used to bind the legacy global-state surface
// (`shadow_open_at`, `shadow_search_json`, `shadow_insert_json`,
// `shadow_remove_json`, `shadow_flush`, `shadow_stats_json`) which
// opened a `RwLock<Option<Arc<RealBackend>>>` global in the Rust
// crate. Per `docs/plan/03_EXECUTION_MAP.md` §W9.21 (and Doctrine
// §6 #14 "no orphan scaffolding"), the consumer now holds an
// explicit per-instance handle obtained from
// `shadow_handle_open_at` and dispatches every operation through
// the handle FFI. This closes the longest orphan-scaffold pattern
// in the codebase: PR1 (`dcc5521f`) shipped the honest_handle.rs
// module, PR2 (`b2e4899d`) covered substrate-rt + substrate-core +
// syntax-core, PR4 (this commit) wires the Swift consumer.
//
// Honest-handle FFI surface (epistemos-shadow/src/honest_handle.rs):
//   - shadow_handle_open_at(path)          → *const ShadowEngineHandle
//   - shadow_handle_retain(handle)         → ()
//   - shadow_handle_release(handle)        → ()
//   - shadow_handle_search(handle, q, d, n, &err) → *mut c_char
//   - shadow_handle_insert(handle, doc_json)      → i32
//   - shadow_handle_remove(handle, doc_id)        → i32
//   - shadow_handle_flush(handle)                 → i32
//   - shadow_handle_stats(handle, &err)           → *mut c_char
//   - shadow_handle_free_string(ptr)              → ()
//
// Lifecycle:
//   - `init(path:)` calls `shadow_handle_open_at`. Refcount starts
//     at 1; the Swift instance owns the strong reference.
//   - `deinit` calls `shadow_handle_release`. When the Swift
//     instance is destroyed, the inner Rust `Arc<RealBackend>` is
//     dropped (refcount → 0).
//   - Two `RustShadowFFIClient` instances over the same path open
//     two independent backends. Per the W8.7 bootstrap design,
//     there's exactly one client per vault, instantiated in
//     `AppBootstrap.initializeShadowBackendIfReady`.
//
// Thread safety:
//   - The handle is sealed inside the Rust `Arc<RealBackend>`,
//     which uses `parking_lot::RwLock` (write) + `RwLock::read`
//     internally for index access. Concurrent FFI calls from
//     different cooperative-thread-pool threads are safe.
//   - The Swift class is `@unchecked Sendable` because the only
//     stored property (`handle`) is `let` and not mutated after
//     `init`. Rust enforces synchronization on all reads through
//     the handle.
//
// Rust panic = code -99: every entry point on the Rust side wraps
// its body in `catch_unwind` so a panic crosses the FFI as
// `ShadowError::Panic` (discriminant -99) instead of UBing the
// Swift host. Swift's `ShadowFFIError.from(rustCode:)` decodes -99
// to `.rustPanic` so callers can log + recover.

// MARK: - Honest-handle FFI bindings
//
// The opaque handle type is a forward declaration on the Swift side
// — Swift never sees the inner Rust struct. Operations take a
// raw `UnsafePointer<UInt8>?` instead of `OpaquePointer` so the
// `@_silgen_name` ABI lines up exactly with the Rust `extern "C"`
// signatures (`*const ShadowEngineHandle` is a raw pointer in C).

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

@_silgen_name("shadow_handle_free_string")
nonisolated private func shadow_handle_free_string(
    _ ptr: UnsafeMutablePointer<CChar>?
)

// Suppress the "unused" warning when only some callers reference
// retain (the production app does not currently retain handles —
// they're held by exactly one owner per vault). The export is
// available for future callers (e.g. background ETL jobs that share
// a handle with the foreground search service).
@inline(never)
nonisolated private func _shadow_keep_retain_alive() {
    shadow_handle_retain(nil)
}

/// Production `ShadowFFIClient` that talks to the Rust crate via the
/// honest-handle C ABI. Each instance owns a refcount-1
/// `*const ShadowEngineHandle` from PR1's `shadow_handle_open_at`;
/// the handle is released exactly once on `deinit`.
///
/// The W8.7 bootstrap path constructs one of these per vault and
/// passes it to `ShadowIndexingService` + `ShadowSearchService`.
nonisolated public final class RustShadowFFIClient: ShadowFFIClient, @unchecked Sendable {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustShadowFFIClient"
    )

    /// The opaque Rust handle. Set exactly once in `init` (post-open
    /// success) and not mutated afterwards. Released exactly once in
    /// `deinit`. Non-optional so call sites never have to nil-check.
    private let handle: UnsafePointer<UInt8>

    /// Open (or create) a Shadow engine rooted at `path`. Returns a
    /// new instance whose refcount is 1; the Swift instance owns the
    /// strong reference. Calling `init` twice with the same `path`
    /// produces two independent backends sharing the on-disk index
    /// (subject to the same multi-process-write caveats as before —
    /// the production app instantiates exactly one client per vault).
    ///
    /// The W8.7 AppBootstrap call site uses `<vault>/.epcache/shadow`
    /// so the index sits next to the other per-vault caches.
    ///
    /// Throws `ShadowFFIError.backendFailure` if the Rust side returns
    /// a null pointer (HuggingFace download failed, tantivy directory
    /// could not be created, etc.). The exact root cause is logged
    /// on the Rust side; Swift only sees a backendFailure with the
    /// path detail.
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
            "shadow_handle_open_at OK at \(path, privacy: .public) (handle initialised)"
        )
    }

    deinit {
        // SAFETY: `handle` is non-null (init ensures it; otherwise we
        // would have thrown). `shadow_handle_release` is safe to call
        // exactly once per `init`-returned pointer. After this call
        // the underlying Rust Arc strong count is 0 and the inner
        // `RealBackend` drops.
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
        let raw: UnsafeMutablePointer<CChar>? = query.withCString { qPtr in
            domain.wireValue.withCString { dPtr in
                shadow_handle_search(handle, qPtr, dPtr, limit, &errorCode)
            }
        }
        guard let cStr = raw else {
            // Honest FFI populates errorCode on the failure path (null
            // handle, malformed UTF-8, backend internal). Surface a
            // typed error so callers can decide between retry and
            // graceful degradation.
            if let typed = ShadowFFIError.from(
                rustCode: errorCode,
                detail: "query=\(query) domain=\(domain.wireValue)"
            ) {
                throw typed
            }
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_search returned null with code 0 — backend bug"
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

    public func stats() throws -> ShadowStatsDTO {
        var errorCode: Int32 = 0
        guard let cStr = shadow_handle_stats(handle, &errorCode) else {
            if let typed = ShadowFFIError.from(rustCode: errorCode) {
                throw typed
            }
            throw ShadowFFIError.backendFailure(
                detail: "shadow_handle_stats returned null with code 0 — backend bug"
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

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = []
        return e
    }()

    private static let decoder = JSONDecoder()
}

// MARK: - ShadowHit Codable
//
// `ShadowHit` lives in Epistemos/Models/HaloState.swift and the W8.1
// scaffold conforms it to `Hashable`, but not yet `Codable`. The
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
