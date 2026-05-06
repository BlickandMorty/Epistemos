import Foundation
import os

// MARK: - V2 Lane 1: Rust Provenance Ledger Swift Client
//
// Read-only Swift bridge to the legacy Rust
// `agent_core::provenance::ledger::ClaimLedger` instance maintained inside
// agent_core. Wired via the FFI exports added in `agent_core/src/bridge.rs`
// (provenance_ledger_summary_json, provenance_ledger_recent_events_json,
// provenance_ledger_snapshot_json).
//
// **Doctrine note.** This is intentionally read-only and no longer the visible
// authority for live provenance counts. Phase 8 mirror writes flow to the
// Cognitive DAG (`RustCognitiveDagClient`); keeping this bridge preserves the
// scaffold without creating a second write target.
//
// Consumed by `ProvenanceConsoleProjectionService` only as legacy context
// alongside the DAG-authoritative Rust provenance projection.

/// One row in the Rust ledger summary, decoded from
/// `provenance_ledger_summary_json()`.
nonisolated struct RustProvenanceLedgerSummary: Sendable, Equatable, Decodable {
    let claimCount: UInt64
    let evidenceCount: UInt64
    let eventCount: UInt64

    enum CodingKeys: String, CodingKey {
        case claimCount = "claim_count"
        case evidenceCount = "evidence_count"
        case eventCount = "event_count"
    }

    static let empty = RustProvenanceLedgerSummary(
        claimCount: 0,
        evidenceCount: 0,
        eventCount: 0
    )
}

/// One ledger event surfaced to Swift. Mirrors the
/// `agent_core::provenance::ledger::LedgerEvent` serde shape — but the FFI
/// returns the raw JSON so we can iterate the shape over time without
/// breaking the Swift consumer. We decode just the common envelope fields
/// (sequence + kind + raw JSON) so the UI can render a generic event row.
nonisolated struct RustProvenanceLedgerEvent: Sendable, Equatable {
    let sequence: UInt64
    let kind: String
    let summary: String
}

/// Read-only Swift client for the legacy global Rust `ClaimLedger`. Falls
/// back to `.empty` summary + empty event list when the FFI is not linked or
/// when the FFI call errors — never throws to the caller, never blocks the UI.
nonisolated enum RustProvenanceLedgerClient {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustProvenanceLedgerClient"
    )

    /// Fetch the current legacy ledger summary. Cheap O(1) FFI call. Safe to
    /// call from any thread; the underlying ledger is `RwLock`-protected on
    /// the Rust side.
    static func summary() -> RustProvenanceLedgerSummary {
        #if canImport(agent_coreFFI)
        do {
            let json = try provenanceLedgerSummaryJson()
            let decoded = try JSONDecoder().decode(
                RustProvenanceLedgerSummary.self,
                from: Data(json.utf8)
            )
            return decoded
        } catch {
            log.error("Provenance ledger summary FFI failed (\(String(describing: error), privacy: .public)); returning empty")
            return .empty
        }
        #else
        return .empty
        #endif
    }

    /// Fetch up to `limit` recent events (newest first). Bounded at 1000
    /// by the Rust side regardless of `limit`. Returns empty array on FFI
    /// failure.
    static func recentEvents(limit: UInt32 = 40) -> [RustProvenanceLedgerEvent] {
        #if canImport(agent_coreFFI)
        do {
            let json = try provenanceLedgerRecentEventsJson(limit: limit)
            return try decodeEvents(from: json)
        } catch {
            log.error("Provenance ledger events FFI failed (\(String(describing: error), privacy: .public)); returning empty")
            return []
        }
        #else
        return []
        #endif
    }

    #if canImport(agent_coreFFI)
    /// The FFI returns an array of `LedgerEvent` JSON objects. We don't
    /// pull in a full Swift mirror of every variant — the UI only needs
    /// `sequence` + a `kind` discriminator + a stable summary string. Keep
    /// the decoder loose so future Rust-side variant additions don't
    /// silently break the consumer.
    private static func decodeEvents(from json: String) throws -> [RustProvenanceLedgerEvent] {
        guard let data = json.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        var out: [RustProvenanceLedgerEvent] = []
        out.reserveCapacity(array.count)
        for entry in array {
            let sequence = (entry["sequence"] as? UInt64)
                ?? UInt64(entry["sequence"] as? Int ?? 0)
            // The serde-tagged enum produces `{"kind":"variant_name", ...}`.
            let kind = (entry["kind"] as? String) ?? "unknown"
            // Render a one-line summary by stable-sorting the remaining keys
            // and joining `key=value` pairs. Keeps the UI deterministic
            // without requiring a per-variant Swift mirror.
            let pairs = entry
                .filter { $0.key != "kind" }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\(stringify($0.value))" }
            let summary = pairs.joined(separator: ", ")
            out.append(RustProvenanceLedgerEvent(
                sequence: sequence,
                kind: kind,
                summary: summary
            ))
        }
        return out
    }

    private static func stringify(_ value: Any) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let b as Bool: return b ? "true" : "false"
        case let arr as [Any]:
            return "[" + arr.map { stringify($0) }.joined(separator: ",") + "]"
        case let dict as [String: Any]:
            let pairs = dict.sorted { $0.key < $1.key }
                .map { "\($0.key):\(stringify($0.value))" }
            return "{" + pairs.joined(separator: ",") + "}"
        default:
            return "\(value)"
        }
    }
    #endif
}
