import Foundation
import os

// MARK: - V2 Final Lane: Cognitive DAG observability Swift client
//
// Read-only Swift bridge to the global `agent_core::cognitive_dag::storage::
// InMemoryDagStore` instance maintained inside agent_core. Wired via the
// FFI exports added in `agent_core/src/bridge.rs` (cognitive_dag_stats_json).
//
// **Doctrine note** (cognitive DAG doctrine §10): the DAG runs alongside
// the seven existing subsystems through Phase 8.A-G; Phase 8.H flips
// authority. This client is READ-ONLY — Swift can observe DAG content
// but cannot write to it. Writes happen through the four DagMirror impls
// (Skills/Procedural/Provenance/Companion) wired into the Rust write
// paths. This is the doctrine-safe minimal surface that removes the
// cognitive_dag module's orphan status from the app's perspective ahead
// of the Phase 8.H authority flip.

/// Decoded shape of `cognitive_dag_stats_json()`.
nonisolated struct RustCognitiveDagStats: Sendable, Equatable, Decodable {
    let nodeCount: UInt64
    let edgeCount: UInt64
    /// Hex-encoded BLAKE3 merkle root over the entire DAG (64 chars when
    /// non-empty). Empty stores produce all-zero merkle roots — the
    /// canonical "no content yet" signal.
    let merkleRootHex: String
    let schemaVersion: UInt32

    enum CodingKeys: String, CodingKey {
        case nodeCount = "node_count"
        case edgeCount = "edge_count"
        case merkleRootHex = "merkle_root_hex"
        case schemaVersion = "schema_version"
    }

    static let empty = RustCognitiveDagStats(
        nodeCount: 0,
        edgeCount: 0,
        merkleRootHex: String(repeating: "0", count: 64),
        schemaVersion: 0
    )

    /// True when the DAG has no content yet (the merkle root is the
    /// all-zero canonical "empty" hash).
    var isEmpty: Bool {
        nodeCount == 0 && edgeCount == 0
    }
}

/// Read-only Swift client for the global Rust cognitive DAG. Falls back
/// to `.empty` stats on FFI failure; never throws to the caller.
nonisolated enum RustCognitiveDagClient {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustCognitiveDagClient"
    )

    /// Fetch the current DAG stats. Cheap O(1)-per-counter + one BLAKE3
    /// walk over the snapshot. Safe to call from any thread (the
    /// underlying store is RwLock-protected).
    static func stats() -> RustCognitiveDagStats {
        #if canImport(agent_coreFFI)
        do {
            let json = try cognitiveDagStatsJson()
            return try JSONDecoder().decode(
                RustCognitiveDagStats.self,
                from: Data(json.utf8)
            )
        } catch {
            log.error("Cognitive DAG stats FFI failed (\(String(describing: error), privacy: .public)); returning empty")
            return .empty
        }
        #else
        return .empty
        #endif
    }
}
