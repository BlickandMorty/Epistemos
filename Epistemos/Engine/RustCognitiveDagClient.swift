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
// *storage* authority (DAG becomes the canonical write target with no
// parallel writes to legacy subsystems). This client is READ-ONLY —
// Swift can observe DAG content but cannot write to it. Writes happen
// through the four DagMirror impls (Skills/Procedural/Provenance/
// Companion) wired into the Rust write paths.
//
// Note: this is the *storage* authority. The *console display* authority
// is already the Cognitive DAG today — see
// `ProvenanceConsoleProjectionService.swift` where the live snapshot reads
// from the DAG and the legacy ClaimLedger appears only as compatibility
// context. RCA2-P2-013 fix-pass distinguishes these two layers.
//
// This is the doctrine-safe minimal surface that removes the
// cognitive_dag module's orphan status from the app's perspective ahead
// of the Phase 8.H storage-authority flip.

/// Decoded shape of `cognitive_dag_stats_json()`.
nonisolated struct RustCognitiveDagStats: Sendable, Equatable, Decodable {
    let nodeCount: UInt64
    let edgeCount: UInt64
    /// V6.2 §1.4 substrate hook (2026-05-12): the number of
    /// `EdgeKind::Contradicts` edges in the DAG. Used by
    /// `SheafResidualSubstrateObserver` to feed InterruptScore's
    /// sheafResidual input. Backward-compatible default 0 lets old
    /// FFI builds + tests decode without breaking — pre-2026-05-12
    /// JSON omitted this field.
    let contradictsEdgeCount: UInt64
    /// Hex-encoded BLAKE3 merkle root over the entire DAG (64 chars when
    /// non-empty). Empty stores produce all-zero merkle roots — the
    /// canonical "no content yet" signal.
    let merkleRootHex: String
    let schemaVersion: UInt32

    enum CodingKeys: String, CodingKey {
        case nodeCount = "node_count"
        case edgeCount = "edge_count"
        case contradictsEdgeCount = "contradicts_edge_count"
        case merkleRootHex = "merkle_root_hex"
        case schemaVersion = "schema_version"
    }

    init(
        nodeCount: UInt64,
        edgeCount: UInt64,
        contradictsEdgeCount: UInt64,
        merkleRootHex: String,
        schemaVersion: UInt32
    ) {
        self.nodeCount = nodeCount
        self.edgeCount = edgeCount
        self.contradictsEdgeCount = contradictsEdgeCount
        self.merkleRootHex = merkleRootHex
        self.schemaVersion = schemaVersion
    }

    /// 4-arg compatibility initializer for callers that pre-date the
    /// `contradictsEdgeCount` field (2026-05-12). Defaults the new
    /// field to 0 so legacy unit tests don't need updating. New
    /// production code should use the 5-arg initializer above.
    init(
        nodeCount: UInt64,
        edgeCount: UInt64,
        merkleRootHex: String,
        schemaVersion: UInt32
    ) {
        self.init(
            nodeCount: nodeCount,
            edgeCount: edgeCount,
            contradictsEdgeCount: 0,
            merkleRootHex: merkleRootHex,
            schemaVersion: schemaVersion
        )
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nodeCount = try c.decode(UInt64.self, forKey: .nodeCount)
        edgeCount = try c.decode(UInt64.self, forKey: .edgeCount)
        // Backward-compat: pre-2026-05-12 JSON did not emit this field.
        contradictsEdgeCount = try c.decodeIfPresent(UInt64.self, forKey: .contradictsEdgeCount) ?? 0
        merkleRootHex = try c.decode(String.self, forKey: .merkleRootHex)
        schemaVersion = try c.decode(UInt32.self, forKey: .schemaVersion)
    }

    static let empty = RustCognitiveDagStats(
        nodeCount: 0,
        edgeCount: 0,
        contradictsEdgeCount: 0,
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
