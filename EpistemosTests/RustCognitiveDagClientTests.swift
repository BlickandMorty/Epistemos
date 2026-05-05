import Testing
@testable import Epistemos

/// V2 Final Lane verification tests for the Rust→Swift cognitive DAG
/// observability bridge. Proves the FFI surface added in
/// `agent_core/src/bridge.rs` (`cognitive_dag_stats_json`) is reachable
/// from Swift and decodes into the typed `RustCognitiveDagStats` mirror.
///
/// The DAG starts empty in a fresh process (no mirrors auto-invoke yet
/// — that's Phase 8.E continuation work). These tests assert FFI shape
/// stability, not specific node counts.
@Suite("Rust Cognitive DAG Client (V2 final lane)")
struct RustCognitiveDagClientTests {

    @Test("stats returns a valid RustCognitiveDagStats even for an empty DAG")
    func statsReturnsValidStructForEmptyDag() {
        let stats = RustCognitiveDagClient.stats()
        // The DAG may be empty if no mirror writes have happened (the
        // doctrine-expected state for Phase 8.A-G); merkle root is the
        // canonical all-zero hash for an empty store, which is exactly
        // 64 hex chars.
        #expect(stats.merkleRootHex.count == 64)
        #expect(stats.schemaVersion >= 1)
    }

    @Test("empty fallback stats is structurally sane")
    func emptyFallbackStatsIsStructurallySane() {
        let empty = RustCognitiveDagStats.empty
        #expect(empty.nodeCount == 0)
        #expect(empty.edgeCount == 0)
        #expect(empty.merkleRootHex == String(repeating: "0", count: 64))
        #expect(empty.isEmpty)
    }

    @Test("isEmpty reflects node/edge counts")
    func isEmptyReflectsCounts() {
        let nonEmpty = RustCognitiveDagStats(
            nodeCount: 1,
            edgeCount: 0,
            merkleRootHex: String(repeating: "a", count: 64),
            schemaVersion: 1
        )
        #expect(!nonEmpty.isEmpty)

        let alsoNonEmpty = RustCognitiveDagStats(
            nodeCount: 0,
            edgeCount: 1,
            merkleRootHex: String(repeating: "b", count: 64),
            schemaVersion: 1
        )
        #expect(!alsoNonEmpty.isEmpty)

        let empty = RustCognitiveDagStats(
            nodeCount: 0,
            edgeCount: 0,
            merkleRootHex: String(repeating: "0", count: 64),
            schemaVersion: 1
        )
        #expect(empty.isEmpty)
    }
}
