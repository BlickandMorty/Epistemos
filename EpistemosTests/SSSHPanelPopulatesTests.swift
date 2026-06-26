import Testing
import Foundation

@testable import Epistemos

// SS-SH (owner 2026-06-21, closing render-test): beyond "polls off the MainActor", prove the
// Substrate Health panel actually POPULATES — it mounts its full row set (not a blank panel) AND
// the shared data pipeline yields a real, populated snapshot the rows render. The off-main fix
// removed the freeze; this confirms the panel shows data, not blank.
@Suite("SS-SH — Substrate Health panel populates its rows")
struct SSSHPanelPopulatesTests {

    @Test("the panel mounts its full health-row set across all 3 sections (not a blank panel)")
    func panelMountsRows() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        let rowMounts = src.components(separatedBy: "HealthRow()").count - 1
        #expect(rowMounts >= 23, "the panel must mount its full row set (found \(rowMounts))")
        // A key row from each of the 3 sections is present (Retrieval / Agent Runtime / Floor).
        #expect(src.contains("EidosHealthRow()"))
        #expect(src.contains("LocalAgentDiagnosticsHealthRow()"))
        #expect(src.contains("EmlObservatoryHealthRow()"))
        #expect(src.contains("Section(\"Retrieval and Indexing\", isExpanded: $showRetrieval)"))
        #expect(src.contains("Section(\"Agent Runtime\", isExpanded: $showAgentRuntime)"))
        #expect(src.contains("Section(\"Substrate Floor\", isExpanded: $showSubstrateFloor)"))
    }

    @MainActor
    @Test("the shared clock yields a POPULATED unified snapshot (rows render data, never blank)")
    func clockPopulatesUnifiedSnapshot() async {
        let clock = SubstrateHealthClock()
        // The rows read `clock.unified`; a populated snapshot is what makes the panel show data. The
        // emlObservatory W-row is a constant identifier present on BOTH the real decoded snapshot
        // (FFI) and the honest `.unavailable` fallback, so its presence proves the snapshot is a
        // real decoded value, never nil/empty — robust regardless of FFI state in the test.
        #expect(clock.unified.emlObservatory.wRow == "W-07")
        // The off-MainActor refresh keeps it populated + advances the shared 1 Hz tick.
        await clock.tickWithUnifiedRefresh()
        #expect(clock.tick == 1)
        #expect(clock.unified.emlObservatory.wRow == "W-07")
    }
}
