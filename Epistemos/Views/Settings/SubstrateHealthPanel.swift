import SwiftUI

// MARK: - SubstrateHealthPanel
//
// Terminal D / T22 / W-29: a single Settings surface for substrate
// health. The panel composes the existing WRV rows plus the missing
// Terminal D rows. Green is reserved for production-wired or truly
// reachable state; fixture, status-only, and dependency rows stay
// orange/red until their backend witnesses are real.

@MainActor
public struct SubstrateHealthPanel: View {

    public init() {}

    public var body: some View {
        Form {
            Section("Retrieval and Indexing") {
                SettingsDescriptionText(
                    text: "Read-only substrate health for retrieval, citations, editor assets, and cross-index search."
                )
                surface(falsifier: "docs/falsifiers/F_EIDOS_CLOSED_CITATION_2026_05_18.md", wRow: "W-46") {
                    EidosHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-VaultRecall-50_2026_05_17.md", wRow: "W-21") {
                    VaultRecallHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md", wRow: "W-20") {
                    SearchFusionHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md", wRow: "W-29") {
                    EditorBundleHealthRow()
                }
            }

            Section("Agent Runtime") {
                SettingsDescriptionText(
                    text: "Local model routing, System G status, and per-turn AnswerPacket witness channels."
                )
                surface(falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md", wRow: "W-17") {
                    LocalAgentDiagnosticsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md", wRow: "W-11") {
                    ActiveConstellationRow()
                }
                surface(falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md", wRow: "W-15") {
                    SystemGHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-14") {
                    AnswerPacketHealthRow()
                }
            }

            Section("Substrate Floor") {
                SettingsDescriptionText(
                    text: "Witness rows for arithmetic, WBO accounting, EML observability, UAS/ACS, and DAG placement."
                )
                surface(falsifier: "docs/falsifiers/F-ULP-Oracle_2026_05_17.md", wRow: "W-40") {
                    FUlpHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-33") {
                    LatticeWBOHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md", wRow: "W-25") {
                    ACSAdmissionHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ULP-Oracle_2026_05_17.md", wRow: "W-07") {
                    EmlObservatoryHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md", wRow: "W-10") {
                    UasAcsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md", wRow: "W-26") {
                    CognitiveDagCountsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ACS-AnchorLookup_2026_05_24.md", wRow: "W-24/W-28/T14") {
                    PlanePlacementHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-30") {
                    CognitiveWeightClassHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-33") {
                    SubstrateDriftMonitorHealthRow()
                }
            }
        }
    }

    @ViewBuilder
    private func surface<Content: View>(
        falsifier: String,
        wRow: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
            SubstrateFalsifierLink(path: falsifier, wRow: wRow)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 2)
    }
}
