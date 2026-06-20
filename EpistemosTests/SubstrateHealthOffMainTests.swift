import Testing
import Foundation
@testable import Epistemos

/// SS-SH (owner: "the substrate health page is still glitched, it is not working in
/// settings"). Verified root: ~15 per-row 1Hz pollers each ran a SYNCHRONOUS Rust
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

    @Test("every unified-snapshot health row polls off the MainActor (no synchronous FFI on main)")
    func unifiedRowsFetchOffMain() throws {
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
            #expect(
                src.contains("await SubstrateHealthUnifiedClient.snapshotAsync()"),
                "\(row) does not fetch off the MainActor"
            )
            // The old synchronous on-MainActor fetch is gone.
            #expect(
                !src.contains("snapshot = SubstrateHealthUnifiedClient.snapshot()"),
                "\(row) still calls the synchronous FFI on the MainActor"
            )
        }
    }

    @Test("LocalAgentDiagnostics health row fetches its FFI off the MainActor (phase 2)")
    func localAgentDiagnosticsOffMain() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/LocalAgentDiagnosticsHealthRow.swift"
        )
        // The 1Hz poll's two nonisolated FFI reads run on a detached task, not on main.
        #expect(src.contains("await Task.detached { LocalAgentDiagnostics.snapshot() }.value"))
        #expect(src.contains("await Task.detached { CapabilityCeilingHealthSnapshot.load() }.value"))
        // The old synchronous on-MainActor fetch is gone.
        #expect(!src.contains("snapshot = LocalAgentDiagnostics.snapshot()"))
    }
}
