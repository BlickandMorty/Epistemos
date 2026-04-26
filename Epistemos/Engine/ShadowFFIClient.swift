import Foundation

// MARK: - ShadowFFIClient
//
// Wave 8.3 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"Concurrency").
//
// Protocol abstraction over the epistemos-shadow Rust crate's C ABI
// surface (`shadow_insert_json`, `shadow_remove_json`,
// `shadow_search_json`, `shadow_flush`, `shadow_stats_json`).
//
// Why a protocol instead of @_silgen_name calls everywhere:
//   - Tests can wire a deterministic stub without spinning up the Rust
//     dylib at unit-test scope.
//   - The W8.4 real-backend swap (Model2Vec + usearch + tantivy + RRF)
//     happens on the Rust side; the Swift surface stays identical.
//   - The eventual UniFFI codegen (W8.4 follow-up) can implement this
//     protocol verbatim — protocol + concrete UniFFI binding is the
//     canonical pattern for testable Swift over Rust crates.

/// Errors the FFI surface can return. Discriminants mirror the Rust
/// `ShadowError::as_code()` values so a Swift caller can `switch` on
/// the exact backend signal.
nonisolated public enum ShadowFFIError: Error, Equatable, Sendable {
    /// Caller passed bad input (null / malformed JSON / unknown
    /// domain). Rust discriminant: -1.
    case invalidInput(detail: String)
    /// Index path lookup miss. Rust discriminant: -2.
    case notFound(docId: String)
    /// Index file IO failure. Rust discriminant: -3.
    case ioFailure(detail: String)
    /// Backend engine failure (Model2Vec / usearch / tantivy
    /// internal). Rust discriminant: -4.
    case backendFailure(detail: String)
    /// Caught a Rust panic at the FFI boundary. Rust discriminant:
    /// -99. Bug — Swift should log + recover.
    case rustPanic
    /// FFI returned an unrecognised numeric code. Forward-compat: a
    /// future Rust version may add new error families.
    case unknownCode(code: Int32)

    /// Decode a Rust C ABI return code into a typed Swift error.
    /// Returns `nil` for code `0` (success).
    public static func from(rustCode code: Int32, detail: String = "") -> ShadowFFIError? {
        switch code {
        case 0:    return nil
        case -1:   return .invalidInput(detail: detail)
        case -2:   return .notFound(docId: detail)
        case -3:   return .ioFailure(detail: detail)
        case -4:   return .backendFailure(detail: detail)
        case -99:  return .rustPanic
        default:   return .unknownCode(code: code)
        }
    }
}

/// Protocol that mirrors the epistemos-shadow C ABI surface in typed
/// Swift terms. The W8.4 real implementation calls
/// `shadow_*_json` via `@_silgen_name`; tests use the stub below.
///
/// Methods are nonisolated so the actor-bound `ShadowSearchService`
/// can call them from its own cooperative executor without an extra
/// hop. The protocol's `Sendable` conformance + the implementations'
/// internal synchronisation cover thread safety.
nonisolated public protocol ShadowFFIClient: Sendable {
    func insert(document: ShadowDocumentDTO) throws -> Void
    func remove(docId: String) throws -> Void
    func search(query: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit]
    func flush() throws -> Void
    func stats() throws -> ShadowStatsDTO
}

/// Plain DTO mirroring the Rust `ShadowDocument` struct field-for-field.
/// Distinct from `ShadowHit` — that's a search result, this is an
/// indexable document.
nonisolated public struct ShadowDocumentDTO: Sendable, Hashable, Codable {
    public let docId: String
    public let title: String
    public let body: String
    public let domain: ShadowDomain

    public init(docId: String, title: String, body: String, domain: ShadowDomain) {
        self.docId = docId
        self.title = title
        self.body = body
        self.domain = domain
    }

    /// Wire format: snake_case keys + domain encoded as
    /// `"note"` / `"chat"` to match Rust's `ShadowDocument`.
    enum CodingKeys: String, CodingKey {
        case docId = "doc_id"
        case title
        case body
        case domain
    }
}

/// Mirror of `ShadowStats` — aggregate index metrics for the developer
/// panel.
nonisolated public struct ShadowStatsDTO: Sendable, Hashable, Codable {
    public let noteCount: UInt64
    public let chatCount: UInt64
    public let indexSizeBytes: UInt64
    public let lastFlushMsAgo: UInt64

    public init(
        noteCount: UInt64,
        chatCount: UInt64,
        indexSizeBytes: UInt64,
        lastFlushMsAgo: UInt64
    ) {
        self.noteCount = noteCount
        self.chatCount = chatCount
        self.indexSizeBytes = indexSizeBytes
        self.lastFlushMsAgo = lastFlushMsAgo
    }

    enum CodingKeys: String, CodingKey {
        case noteCount = "note_count"
        case chatCount = "chat_count"
        case indexSizeBytes = "index_size_bytes"
        case lastFlushMsAgo = "last_flush_ms_ago"
    }
}

// MARK: - StubShadowFFIClient
//
// In-memory client matching the W8.1 Rust stub backend's semantics.
// Used by HaloController tests, ShadowSearchService tests, and the
// ShadowIndexingService tests so the actor architecture is fully
// covered without depending on the Rust dylib being loadable.

/// In-memory `ShadowFFIClient` used by tests. Behaviour mirrors the
/// Rust `ShadowState` stub (substring-match scoring + per-domain
/// filtering + UTF-8-safe snippet truncation). Thread-safe via an
/// internal serial queue so tests can call from any actor context.
nonisolated public final class StubShadowFFIClient: ShadowFFIClient, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.epistemos.shadow.stub")
    private var docs: [String: ShadowDocumentDTO] = [:]
    private var lastFlush: Date = .distantPast

    public init() {}

    public func insert(document: ShadowDocumentDTO) throws {
        guard !document.docId.isEmpty else {
            throw ShadowFFIError.invalidInput(detail: "doc_id was empty")
        }
        queue.sync { docs[document.docId] = document }
    }

    public func remove(docId: String) throws {
        let removed: Bool = queue.sync {
            docs.removeValue(forKey: docId) != nil
        }
        if !removed {
            throw ShadowFFIError.notFound(docId: docId)
        }
    }

    public func search(query: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return [] }
        let snapshot: [ShadowDocumentDTO] = queue.sync {
            docs.values.filter { $0.domain == domain }
        }
        var hits: [ShadowHit] = snapshot.compactMap { doc in
            let titleLower = doc.title.lowercased()
            let bodyLower = doc.body.lowercased()
            let titleHit = titleLower.contains(q)
            let bodyRange = bodyLower.range(of: q)
            guard titleHit || bodyRange != nil else { return nil }

            var score: Float = 0
            if titleHit { score += 2.0 }
            if let r = bodyRange {
                let bodyLen = max(1, doc.body.count)
                let pos = doc.body.distance(from: doc.body.startIndex, to: r.lowerBound)
                score += 1.0 - Float(pos) / Float(bodyLen)
            }
            if titleLower.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .contains(where: { String($0) == q }) {
                score += 0.5
            }

            let snippet = Self.snippet(from: doc.body, hitRange: bodyRange)
            return ShadowHit(
                id: doc.docId,
                title: doc.title,
                snippet: snippet,
                score: score,
                domain: doc.domain,
                source: "stub-substring"
            )
        }
        hits.sort { $0.score > $1.score }
        if hits.count > limit { hits = Array(hits.prefix(limit)) }
        return hits
    }

    public func flush() throws {
        queue.sync { lastFlush = Date() }
    }

    public func stats() throws -> ShadowStatsDTO {
        queue.sync {
            var noteCount: UInt64 = 0
            var chatCount: UInt64 = 0
            var bytes: UInt64 = 0
            for doc in docs.values {
                bytes &+= UInt64(doc.title.utf8.count + doc.body.utf8.count)
                switch doc.domain {
                case .notes: noteCount &+= 1
                case .chats: chatCount &+= 1
                }
            }
            let elapsedMs = lastFlush == .distantPast
                ? UInt64.max
                : UInt64(max(0, Date().timeIntervalSince(lastFlush) * 1000))
            return ShadowStatsDTO(
                noteCount: noteCount,
                chatCount: chatCount,
                indexSizeBytes: bytes,
                lastFlushMsAgo: elapsedMs
            )
        }
    }

    private static func snippet(from body: String, hitRange: Range<String.Index>?) -> String {
        let max = 160
        if body.count <= max { return body }
        guard let r = hitRange else {
            return String(body.prefix(max))
        }
        let bodyChars = Array(body)
        let center = body.distance(from: body.startIndex, to: r.lowerBound)
        let half = max / 2
        let start = Swift.max(0, center - half)
        let end = Swift.min(bodyChars.count, start + max)
        return String(bodyChars[start..<end])
    }
}
