import Testing
import Foundation
@testable import Epistemos

/// SS-SH (owner: "the substrate health page is still glitched, it is not working in
/// settings"). Verified root: ~15 per-row high-frequency pollers each ran a SYNCHRONOUS Rust
/// FFI round-trip ON the MainActor — a single slow/contended call froze the whole
/// panel ("never block @MainActor"). This slice moves the 6 rows that share the
/// unified snapshot off the MainActor (the FFI + decode run on a detached task);
/// the remaining bridge-specific rows are a documented follow-on.
@Suite("Substrate health off-MainActor poll (SS-SH)")
struct SubstrateHealthOffMainTests {

    @Test("the unified client exposes an off-MainActor snapshot fetch")
    func clientHasOffMainSnapshot() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthSupport.swift"
        )
        #expect(src.contains("static func snapshotAsync() async -> SubstrateHealthUnifiedSnapshot"))
        // FFI + JSON decode run on a detached background task (off the MainActor).
        #expect(src.contains("await Task.detached { snapshot() }.value"))
    }

    // SS-SH dedup (corrected 2026-06-21): the 6 rows no longer each fetch — they read ONE shared
    // snapshot from SubstrateHealthClock, and the single off-MainActor fetch lives
    // in the clock driver. (The prior assertion that each ROW calls `snapshotAsync()` went stale
    // after the clock migration — compiled, but failed when run; a DONE-RE-AUDIT catch.)
    @Test("every unified-snapshot health row reads the ONE shared clock snapshot (no per-row FFI)")
    func unifiedRowsReadSharedClock() throws {
        let rows = [
            "CognitiveDagCountsHealthRow",
            "CognitiveWeightClassHealthRow",
            "EmlObservatoryHealthRow",
            "PlanePlacementHealthRow",
            "UasAcsHealthRow",
            "SubstrateDriftMonitorHealthRow",
        ]
        for row in rows {
            let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/\(row).swift")
            #expect(src.contains("healthClock?.unified"), "\(row) does not read the shared clock snapshot")
            // No per-row off-main fetch — the clock is the single fetcher now.
            #expect(
                !src.contains("await SubstrateHealthUnifiedClient.snapshotAsync()"),
                "\(row) still does its own snapshotAsync; the clock should be the single fetcher")
            // The old synchronous on-MainActor assignment is gone.
            #expect(
                !src.contains("snapshot = SubstrateHealthUnifiedClient.snapshot()"),
                "\(row) still calls the synchronous FFI on the MainActor")
        }
        // The single off-MainActor fetch lives in the clock driver, once per tick.
        let clock = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthClock.swift")
        #expect(clock.contains("unified = await SubstrateHealthUnifiedClient.snapshotAsync()"))
    }

    @Test("UasAcs health row loads its UAS gates off the MainActor (the residual per-tick sync read)")
    func uasAcsGateLoadOffMain() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/UasAcsHealthRow.swift")
        // The per-tick gate load (copyCount + anchorLookup file reads) runs on a detached task —
        // it was the one remaining synchronous read on the main thread in the panel.
        #expect(src.contains("await Task.detached { UasAcsGateSnapshot.load() }.value"))
        // The old synchronous on-main per-tick load is gone from the poll block.
        #expect(!src.contains("gates = UasAcsGateSnapshot.load()"))
    }

    @Test("LatticeWBO health row fetches its Rust FFI off the MainActor (phase 2)")
    func latticeOffMain() throws {
        let lattice = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/LatticeWBOHealthRow.swift"
        )
        #expect(lattice.contains("await Task.detached { LatticeWBOBridge.snapshot() }.value"))
        #expect(!lattice.contains("if let snap = LatticeWBOBridge.snapshot() {"))
    }
}
