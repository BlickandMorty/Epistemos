import Foundation
import Testing

@testable import Epistemos

// W6 (Terminal 1 WRV mission) test. Verifies the unified Substrate
// Health panel:
//
//   - Mounts the legacy substrate health rows plus the Terminal D
//     unified floor rows.
//   - Mounts the T14 UAS plane-placement row so the cluster surfaces
//     live per-plane DAG counts from the Rust FFI snapshot.
//   - Is wired into `SettingsView` exactly once and replaces the
//     scattered per-row mounts that used to live in
//     General → Diagnostics.

@Suite("Substrate Health Panel (W6)")
struct SubstrateHealthPanelTests {

    @Test("SubstrateHealthPanel mounts the WRV substrate rows")
    func substrateHealthPanelMountsSubstrateRows() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )

        #expect(panel.contains("EidosHealthRow()"))
        #expect(panel.contains("VaultRecallHealthRow()"))
        #expect(panel.contains("LatticeWBOHealthRow()"))
        #expect(panel.contains("SystemGHealthRow()"))
        #expect(panel.contains("FUlpHealthRow()"))
        #expect(panel.contains("ACSAdmissionHealthRow()"))
        #expect(panel.contains("FalsifierArtifactsHealthRow()"))
        #expect(panel.contains("AnswerPacketHealthRow()"))
        #expect(panel.contains("EmlObservatoryHealthRow()"))
        #expect(panel.contains("UasAcsHealthRow()"))
        #expect(panel.contains("CognitiveDagCountsHealthRow()"))
        #expect(panel.contains("CognitiveWeightClassHealthRow()"))
        #expect(panel.contains("SubstrateDriftMonitorHealthRow()"))
    }

    @Test("SubstrateHealthPanel mounts the UAS plane-placement witness row")
    func substrateHealthPanelMountsPlanePlacementRow() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/PlanePlacementHealthRow.swift"
        )

        #expect(panel.contains("PlanePlacementHealthRow()"))
        #expect(panel.contains("F-ACS-AnchorLookup_2026_05_24.md"))
        #expect(row.contains("SubstrateHealthUnifiedClient.snapshot()"))
        #expect(row.contains("return p.planeFieldsWired ? \"read-only counts\""))
        #expect(row.contains("state=\\(p.stateCount) episodic=\\(p.episodicCount) assembly=\\(p.assemblyCount)"))
    }

    @Test("D-prime rows keep chip strips and W-30 badges conservative")
    func dPrimeRowsKeepChipStripsConservative() throws {
        let answerPacket = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/AnswerPacketHealthRow.swift"
        )
        let planePlacement = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/PlanePlacementHealthRow.swift"
        )
        let cognitiveWeight = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/CognitiveWeightClassHealthRow.swift"
        )
        let components = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsSurfaceComponents.swift"
        )
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")

        #expect(answerPacket.contains("session ring only"))
        #expect(answerPacket.contains("falsifierPassed: false"))
        #expect(planePlacement.contains("falsifierPassed: false"))
        #expect(components.contains("private var substrateTint: Color"))
        #expect(components.contains("return productionWired ? .orange : .secondary"))
        #expect(cognitiveWeight.contains("badge only"))
        #expect(bridge.contains("\"class\": \"policy_grade\", \"range\": \"0.86-1.00\", \"policy_authority\": false"))
    }

    @Test("UAS ACS row reads measured artifact gates without turning runtime adapter green")
    func uasAcsRowReadsMeasuredArtifactGatesConservatively() throws {
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/UasAcsHealthRow.swift"
        )

        #expect(row.contains("UasAcsGateSnapshot.load()"))
        #expect(row.contains("artifacts/falsifiers/uas_copy_count/result.json"))
        #expect(row.contains("artifacts/falsifiers/acs_anchor_lookup/result.json"))
        #expect(row.contains("F-UAS-CopyCount"))
        #expect(row.contains("F-ACS-AnchorLookup"))
        #expect(row.contains("MAS runtime adapter pending"))
        #expect(!row.contains("harness passed; production registry adapter pending"),
                "Measured artifact PASS should be distinct from production adapter wiring.")
    }

    @Test("Local agent diagnostics surfaces the capability-ceiling cursor without duplicating runtime routes")
    func localAgentDiagnosticsSurfacesCapabilityCeilingCursor() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )
        let row = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/LocalAgentDiagnosticsHealthRow.swift"
        )

        #expect(panel.contains("LocalAgentDiagnosticsHealthRow()"))
        #expect(row.contains("CapabilityCeilingHealthSnapshot.load()"))
        #expect(row.contains("artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json"))
        #expect(row.contains("artifacts/falsifiers/kv_direct_gate/result.json"))
        #expect(row.contains("docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json"))
        #expect(row.contains("artifacts/falsifiers/architecture_pending_work_guard/result.json"))
        #expect(row.contains("docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json"))
        #expect(row.contains("artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json"))
        #expect(row.contains("Heavy long-context opt-in"))
        #expect(row.contains("heavy_long_context_guard_present"))
        #expect(row.contains("EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1"))
        #expect(row.contains("missing_fp16_or_provider_reference"))
        #expect(row.contains("canonical red"))
        #expect(row.contains("best_required_context_candidate_repo_id"))
        #expect(row.contains("high_duplicate_risk_count"))
        #expect(row.contains("preserve-before-new-work risk"))
        #expect(row.contains("deferred candidate"))
        #expect(row.contains("canonical MLX KV-Direct"))
    }

    @Test("SettingsView mounts SubstrateHealthPanel exactly once in Diagnostics")
    func settingsViewMountsSubstrateHealthPanel() throws {
        let settings = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsView.swift"
        )

        let mountCount = settings.components(separatedBy: "SubstrateHealthPanel()").count - 1
        #expect(mountCount == 1, "SubstrateHealthPanel must be mounted exactly once")
    }

    @Test("SettingsView no longer mounts the substrate rows individually outside the panel")
    func settingsViewDoesNotDoubleMountSubstrateRows() throws {
        let settings = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsView.swift"
        )

        // Each of these rows must now be mounted *only* through the
        // panel — not via a direct invocation in SettingsView.
        let directMounts: [String] = [
            "                EidosHealthRow()",
            "                VaultRecallHealthRow()",
            "                LatticeWBOHealthRow()",
            "                SystemGHealthRow()",
            "                FUlpHealthRow()",
            "                ACSAdmissionHealthRow()",
            "                AnswerPacketHealthRow()",
        ]
        for direct in directMounts {
            #expect(!settings.contains(direct),
                    "SettingsView still mounts \(direct.trimmingCharacters(in: .whitespaces)) outside the panel — duplicate render hazard")
        }
    }
}
