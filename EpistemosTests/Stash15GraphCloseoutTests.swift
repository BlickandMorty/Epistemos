import Foundation
import Testing

@Suite("Stash 15 Graph Closeout")
struct Stash15GraphCloseoutTests {
    @Test("closeout records stash 15 as preserved not active recovery")
    func closeoutRecordsStash15AsPreservedNotActiveRecovery() throws {
        let closeout = try loadMirroredSourceTextFile(
            "docs/audits/STASH15_GRAPH_CLOSEOUT_2026_05_26.md"
        )
        let ledger = try loadMirroredSourceTextFile(
            "docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md"
        )
        let recoveryStatus = try loadMirroredSourceTextFile(
            "docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md"
        )
        let livingIndex = try loadMirroredSourceTextFile(
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md"
        )

        #expect(closeout.contains("stash@{15}"))
        #expect(closeout.contains("closed for current product graph recovery"))
        #expect(closeout.contains("not safe to\nrestore onto current `main`"))
        #expect(ledger.contains("`stash@{15}` - graph filter/physics selected-expansion WIP"))
        #expect(ledger.contains("historical graph/performance donor reference"))
        #expect(recoveryStatus.contains("no longer an active recovery queue item"))
        #expect(livingIndex.contains("`stash@{15}` graph/filter recovery is closed"))
        #expect(!livingIndex.contains("non-closed stashes (`stash@{15}`"))
        #expect(!recoveryStatus.contains("**Graph WIP audit:** mine `stash@{15}`"))
    }

    @Test("current graph performance guardrails remain named in source")
    func currentGraphPerformanceGuardrailsRemainNamedInSource() throws {
        let graphState = try loadMirroredSourceTextFile("Epistemos/Graph/GraphState.swift")
        let forces = try loadMirroredSourceTextFile("graph-engine/src/forces.rs")
        let simulation = try loadMirroredSourceTextFile("graph-engine/src/simulation.rs")
        let graphAudit = try loadMirroredSourceTextFile(
            "EpistemosTests/GraphPhysicsSettingsAuditTests.swift"
        )

        #expect(graphState.contains("selectedPreset=gravityWell, linkDistance=500, centerStrength=0"))
        #expect(graphState.contains("selectedPhysicsPreset = .gravityWell"))
        #expect(graphState.contains("linkDistance = 500.0"))
        #expect(graphState.contains("centerStrength = 0.0"))
        #expect(graphState.contains("enableFluidDynamics = false"))
        #expect(forces.contains("focused_link_extends_selected_neighbor_distance"))
        #expect(simulation.contains("Selected focus only changes direct selected-neighborhood rest distance"))
        #expect(simulation.contains("if let Some(root) = self.selected_focus_root"))
        #expect(simulation.contains("} else {\n            forces::force_link("))
        #expect(graphAudit.contains("Graph selection sync restores neighborhood focus from every selection surface"))
        #expect(graphAudit.contains("select_node_syncs_selection_and_neighborhood_focus"))
    }
}
