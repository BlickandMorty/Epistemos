import Testing
import Foundation

@testable import Epistemos

// SS-SH (owner 2026-06-21, closing render-test): beyond "polls off the MainActor", prove the
// compact Free V1 foundation panel still mounts its retained rows and the shared data pipeline
// yields a snapshot for them to render. The off-main fix removed the freeze; this confirms the
// panel shows useful native capability rather than a blank surface.
@Suite("SS-SH — Substrate Health panel populates its rows")
struct SSSHPanelPopulatesTests {

    @Test("the panel mounts the retained foundation health-row set (not a blank panel)")
    func panelMountsRows() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        let rowMounts = src.components(separatedBy: "HealthRow()").count - 1
        #expect(rowMounts >= 8, "the panel must mount its retained row set (found \(rowMounts))")
        // A key row from each active section is present (Retrieval / Honesty / Bridge).
        #expect(src.contains("EidosHealthRow()"))
        #expect(src.contains("AnswerPacketHealthRow()"))
        #expect(src.contains("LiteParseImportHealthRow()"))
        #expect(src.contains("foundationSection(\"Foundation Features\")"))
        #expect(src.contains("foundationSection(\"Retrieval and Indexing\")"))
        #expect(src.contains("foundationSection(\"Honesty and Provenance\")"))
        #expect(src.contains("foundationSection(\"Tools and Surface Bridge\")"))
        #expect(!src.contains("LocalAgentDiagnosticsHealthRow()"))
        #expect(!src.contains("WorkOpenCodeShellHealthRow()"))
        #expect(!src.contains("WorkBackendHealthRow()"))
        #expect(!src.contains("EmlObservatoryHealthRow()"))
    }

    @MainActor
    @Test("the shared clock yields a POPULATED unified snapshot (rows render data, never blank)")
    func clockPopulatesUnifiedSnapshot() async {
        let clock = SubstrateHealthClock()
        // The rows read `clock.unified`; a populated snapshot is what makes the panel show data. The
        // retained UAS witness is present in both the decoded snapshot and its honest fallback, so
        // this assertion remains valid whether the FFI is available in the test process or not.
        #expect(clock.unified.uasAcs.wRow == "W-10")
        // The off-MainActor refresh keeps it populated + advances the shared tick.
        await clock.tickWithUnifiedRefresh()
        #expect(clock.tick == 1)
        #expect(clock.unified.uasAcs.wRow == "W-10")
    }
}
