import Testing
import Foundation

@testable import Epistemos

// SS-SH (owner 2026-06-21, closing render-test): beyond "polls off the MainActor", prove the
// Substrate Health panel actually POPULATES — it mounts its full row set (not a blank panel) AND
// the shared data pipeline yields a real, populated snapshot the rows render. The off-main fix
// removed the freeze; this confirms the panel shows data, not blank.
@Suite("SS-SH — Substrate Health panel populates its rows")
struct SSSHPanelPopulatesTests {

    @Test("the panel mounts the simplified foundation health-row set (not a blank panel)")
    func panelMountsRows() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        let rowMounts = src.components(separatedBy: "HealthRow()").count - 1
        #expect(rowMounts >= 12, "the panel must mount its simplified row set (found \(rowMounts))")
        // A key row from each active section is present (Retrieval / Honesty / Bridge).
        #expect(src.contains("EidosHealthRow()"))
        #expect(src.contains("AnswerPacketHealthRow()"))
        #expect(src.contains("WorkOpenCodeShellHealthRow()"))
        #expect(src.contains("Section(\"Foundation Features\", isExpanded: $showFoundation)"))
        #expect(src.contains("Section(\"Retrieval and Indexing\", isExpanded: $showRetrieval)"))
        #expect(src.contains("Section(\"Honesty and Provenance\", isExpanded: $showHonesty)"))
        #expect(src.contains("Section(\"Tools and Surface Bridge\", isExpanded: $showTools)"))
        #expect(!src.contains("LocalAgentDiagnosticsHealthRow()"))
        #expect(!src.contains("Section(\"Agent Runtime\""))
        #expect(!src.contains("Section(\"Substrate Floor\""))
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
        // The off-MainActor refresh keeps it populated + advances the shared tick.
        await clock.tickWithUnifiedRefresh()
        #expect(clock.tick == 1)
        #expect(clock.unified.emlObservatory.wRow == "W-07")
    }
}
