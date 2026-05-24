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
        #expect(row.contains("return p.planeFieldsWired ? \"five-plane counts\""))
        #expect(row.contains("state=\\(p.stateCount) episodic=\\(p.episodicCount) assembly=\\(p.assemblyCount)"))
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
