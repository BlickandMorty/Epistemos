import Foundation
import OSLog

// MARK: - RustShadowFFIClient
//
// Wave 8.4.h — production `ShadowFFIClient` impl that talks to the
// `epistemos_shadow` Rust crate's C ABI surface
// (`shadow_insert_json`, `shadow_remove_json`, `shadow_search_json`,
//  `shadow_flush`, `shadow_stats_json`, `shadow_open_at`,
//  `shadow_free_string`).
//
// The C ABI lives in `epistemos-shadow/src/lib.rs` and is linked via
// the `-lepistemos_shadow` flag in `project.yml` + `project.pbxproj`.
// All entry points are wrapped in `catch_unwind` on the Rust side so a
// panic crosses the FFI as code -99 (rustPanic) instead of UBing the
// Swift process.
//
// Idempotence: `shadow_open_at(path)` may be called multiple times —
// it replaces the live RealBackend in the global RwLock. The Swift
// bootstrap calls it once on launch with the vault root + "shadow"
// suffix; subsequent FFI calls hit the persistent RealBackend.
//
// Thread safety: every entry point is `nonisolated`. The Rust side
// uses parking_lot::RwLock around the backend handle so concurrent
// calls from the cooperative thread pool are safe.

@_silgen_name("shadow_insert_json")
nonisolated private func shadow_insert_json(_ docJSON: UnsafePointer<CChar>?) -> Int32

@_silgen_name("shadow_remove_json")
nonisolated private func shadow_remove_json(_ docId: UnsafePointer<CChar>?) -> Int32

@_silgen_name("shadow_search_json")
nonisolated private func shadow_search_json(
    _ query: UnsafePointer<CChar>?,
    _ domain: UnsafePointer<CChar>?,
    _ limit: UInt32
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("shadow_flush")
nonisolated private func shadow_flush() -> Int32

@_silgen_name("shadow_stats_json")
nonisolated private func shadow_stats_json() -> UnsafeMutablePointer<CChar>?

@_silgen_name("shadow_free_string")
nonisolated private func shadow_free_string(_ ptr: UnsafeMutablePointer<CChar>?)

@_silgen_name("shadow_open_at")
nonisolated private func shadow_open_at(_ path: UnsafePointer<CChar>?) -> Int32

/// Production `ShadowFFIClient` that talks to the Rust crate via C
/// ABI. The W8.7 bootstrap path constructs one of these and passes
/// it to `ShadowIndexingService` + `ShadowSearchService`.
///
/// The class itself holds no mutable state — the backend lives behind
/// the C ABI in Rust's parking_lot::RwLock — so it's `Sendable` via
/// `@unchecked` (the protocol can't reach inside Rust to prove it).
nonisolated public final class RustShadowFFIClient: ShadowFFIClient, @unchecked Sendable {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustShadowFFIClient"
    )

    public init() {}

    /// Open / re-open the global RealBackend at `path`. Must be
    /// called once at app start before any other entry point. The
    /// W8.7 AppBootstrap call site uses `<vault>/.epcache/shadow` so
    /// the index sits next to the other per-vault caches.
    public static func openAt(path: String) throws {
        let code = path.withCString { cstr -> Int32 in
            shadow_open_at(cstr)
        }
        if let error = ShadowFFIError.from(rustCode: code, detail: path) {
            log.error(
                "shadow_open_at failed (code \(code)) at \(path, privacy: .public)"
            )
            throw error
        }
        log.info("shadow_open_at OK at \(path, privacy: .public)")
    }

    public func insert(document: ShadowDocumentDTO) throws {
        let data = try Self.encoder.encode(document)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ShadowFFIError.backendFailure(
                detail: "could not stringify ShadowDocumentDTO JSON for \(document.docId)"
            )
        }
        let code = json.withCString { cstr -> Int32 in
            shadow_insert_json(cstr)
        }
        if let error = ShadowFFIError.from(rustCode: code, detail: document.docId) {
            throw error
        }
    }

    public func remove(docId: String) throws {
        let code = docId.withCString { cstr -> Int32 in
            shadow_remove_json(cstr)
        }
        if let error = ShadowFFIError.from(rustCode: code, detail: docId) {
            throw error
        }
    }

    public func search(query: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] {
        let cap = UInt32(max(0, min(limit, Int(UInt32.max))))
        let raw: UnsafeMutablePointer<CChar>? = query.withCString { qPtr in
            domain.wireValue.withCString { dPtr in
                shadow_search_json(qPtr, dPtr, cap)
            }
        }
        guard let cStr = raw else {
            // FFI returned null — backend signalled failure (logged in
            // Rust). Surface as backend failure so callers can fall
            // through to "no hits" without a panic.
            throw ShadowFFIError.backendFailure(
                detail: "shadow_search_json returned null for query=\(query) domain=\(domain.wireValue)"
            )
        }
        defer { shadow_free_string(cStr) }
        let json = String(cString: cStr)
        guard let data = json.data(using: .utf8) else {
            throw ShadowFFIError.backendFailure(
                detail: "shadow_search_json returned non-UTF8 payload"
            )
        }
        let dtos = try Self.decoder.decode([ShadowHitDTO].self, from: data)
        return dtos.map { $0.toModel() }
    }

    public func flush() throws {
        let code = shadow_flush()
        if let error = ShadowFFIError.from(rustCode: code) {
            throw error
        }
    }

    public func stats() throws -> ShadowStatsDTO {
        guard let cStr = shadow_stats_json() else {
            throw ShadowFFIError.backendFailure(
                detail: "shadow_stats_json returned null"
            )
        }
        defer { shadow_free_string(cStr) }
        let json = String(cString: cStr)
        guard let data = json.data(using: .utf8) else {
            throw ShadowFFIError.backendFailure(
                detail: "shadow_stats_json returned non-UTF8 payload"
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

