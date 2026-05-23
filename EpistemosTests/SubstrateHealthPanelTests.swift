import Foundation
import Testing

@testable import Epistemos

// W6 (Terminal 1 WRV mission) test. Verifies the unified Substrate
// Health panel:
//
//   - Mounts the seven existing substrate health rows (Eidos,
//     VaultRecall, Lattice/WBO, SystemG, F-ULP, ACS, AnswerPacket).
//   - Documents the still-missing UAS row (W-10) as a placeholder so
//     the cluster is self-describing about its gaps.
//   - Is wired into `SettingsView` exactly once and replaces the
//     scattered per-row mounts that used to live in
//     General → Diagnostics.

@Suite("Substrate Health Panel (W6)")
struct SubstrateHealthPanelTests {

    @Test("SubstrateHealthPanel mounts the seven WRV substrate rows")
    func substrateHealthPanelMountsAllSevenRows() throws {
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
    }

    @Test("SubstrateHealthPanel surfaces the missing UAS row as a placeholder")
    func substrateHealthPanelSurfacesMissingUasRow() throws {
        let panel = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SubstrateHealthPanel.swift"
        )

        #expect(panel.contains("UAS-ACS substrate health"))
        #expect(panel.contains("W-10 NOT-STARTED"))
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
