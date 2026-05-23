import Foundation
import Testing
@testable import Epistemos

// Wiring #3 (T17B lattice/WBO → oplog) Swift integration test.
// Verifies the WRV "Verified" bar for the Swift side:
//
//   - `LatticeWBOBridge.snapshot()` returns a decoded
//     `LatticeWBOStats` from the Rust accountant.
//   - The snapshot's `tier` is the canonical L0RamHot name.
//   - The snapshot's `falsifier` is F-WBO-DriftLedger.
//   - `appendsAccounted` is monotone non-decreasing across reads.
//
// Note: This test asserts the SHAPE of the snapshot, not its content.
// The Rust integration test `agent_core/tests/oplog_lattice_wbo.rs`
// exercises the always-on counter contract end-to-end against an
// actual `OpLog::append` call.

@Suite("Lattice/WBO Wiring #3")
struct LatticeWBOWiringTests {

    @Test("LatticeWBOBridge.snapshot returns decoded stats with canonical tier + falsifier")
    func latticeWBOBridgeReturnsDecodedStats() throws {
        let snap = try #require(LatticeWBOBridge.snapshot(),
                                "FFI snapshot must not fail under normal conditions")
        #expect(snap.tier == "L0 RAM hot",
                "tier name must come from ResidencyTier::L0RamHot.canonical_name()")
        #expect(snap.falsifier.contains("WBO") || snap.falsifier.contains("DriftLedger"),
                "falsifier must identify the F-WBO-DriftLedger coverage")
    }

    @Test("Snapshot is monotone — appendsAccounted never decreases across reads")
    func latticeWBOSnapshotIsMonotone() throws {
        let a = try #require(LatticeWBOBridge.snapshot())
        let b = try #require(LatticeWBOBridge.snapshot())
        #expect(b.appendsAccounted >= a.appendsAccounted,
                "lattice/WBO accountant is always-on accumulation — counter must be monotone")
    }
}
