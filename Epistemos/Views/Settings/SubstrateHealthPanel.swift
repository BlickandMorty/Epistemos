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

    // Owner 2026-06-18: the 18 stacked health rows blew out the window height.
    // The three sections are now collapsible (macOS 14+ Section(isExpanded:));
    // the 10-row "Substrate Floor" section defaults COLLAPSED so the panel
    // opens compact. Nothing is removed — every row is one click away.
    @State private var showRetrieval = true
    @State private var showAgentRuntime = true
    @State private var showSubstrateFloor = false

    public var body: some View {
        Form {
            Section("Retrieval and Indexing", isExpanded: $showRetrieval) {
                SettingsDescriptionText(
                    text: "Read-only substrate health for retrieval, citations, editor assets, and cross-index search."
                )
                surface(falsifier: "docs/falsifiers/F_EIDOS_CLOSED_CITATION_2026_05_18.md", wRow: "W-46", weight: .heavy) {
                    EidosHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-VaultRecall-50_2026_05_17.md", wRow: "W-21", weight: .heavy) {
                    VaultRecallHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md", wRow: "W-20", weight: .medium) {
                    SearchFusionHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md", wRow: "W-29", weight: .medium) {
                    EditorBundleHealthRow()
                }
            }

            Section("Agent Runtime", isExpanded: $showAgentRuntime) {
                SettingsDescriptionText(
                    text: "Local model routing, System G status, and per-turn AnswerPacket witness channels."
                )
                surface(falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md", wRow: "W-17", weight: .medium) {
                    LocalAgentDiagnosticsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md", wRow: "W-11", weight: .medium) {
                    ActiveConstellationRow()
                }
                surface(falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md", wRow: "W-15", weight: .extreme) {
                    SystemGHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ULP-Oracle_2026_05_17.md", wRow: "W-14", weight: .heavy) {
                    AnswerPacketHealthRow()
                }
            }

            Section("Substrate Floor", isExpanded: $showSubstrateFloor) {
                SettingsDescriptionText(
                    text: "Witness rows for arithmetic, WBO accounting, EML observability, UAS/ACS, and DAG placement."
                )
                surface(falsifier: "docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md", wRow: "T23B", weight: .medium) {
                    FalsifierArtifactsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ULP-Oracle_2026_05_17.md", wRow: "W-40", weight: .extreme) {
                    FUlpHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-33", weight: .heavy) {
                    LatticeWBOHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md", wRow: "W-25", weight: .extreme) {
                    ACSAdmissionHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ULP-Oracle_2026_05_17.md", wRow: "W-07", weight: .extreme) {
                    EmlObservatoryHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-UAS-CopyCount_2026_05_24.md", wRow: "W-10", weight: .extreme) {
                    UasAcsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md", wRow: "W-26", weight: .heavy) {
                    CognitiveDagCountsHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F-ACS-AnchorLookup_2026_05_24.md", wRow: "W-24/W-28/T14", weight: .extreme) {
                    PlanePlacementHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-30", weight: .medium) {
                    CognitiveWeightClassHealthRow()
                }
                surface(falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md", wRow: "W-33", weight: .heavy) {
                    SubstrateDriftMonitorHealthRow()
                }
            }
        }
    }

    @ViewBuilder
    private func surface<Content: View>(
        falsifier: String,
        wRow: String,
        weight: SettingsCognitiveWeightClass,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
            HStack(spacing: 8) {
                SettingsCognitiveWeightClassBadge(weight: weight)
                SubstrateFalsifierLink(path: falsifier, wRow: wRow)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 2)
    }
}

// UAS: settings/cognitive-weight-class-badge
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
@MainActor
private enum SettingsCognitiveWeightClass: String {
    case light = "W1"
    case medium = "W2"
    case heavy = "W3"
    case extreme = "W4"

    var label: String {
        switch self {
        case .light: return "light"
        case .medium: return "medium"
        case .heavy: return "heavy"
        case .extreme: return "extreme"
        }
    }

    var tint: Color {
        switch self {
        case .light: return .secondary
        case .medium: return .blue
        case .heavy: return .orange
        case .extreme: return .red
        }
    }

    var help: String {
        "\(rawValue) \(label) cognitive weight class - advisory W-30 badge, not policy enforcement"
    }
}

// UAS: settings/cognitive-weight-class-badge
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
@MainActor
private struct SettingsCognitiveWeightClassBadge: View {
    let weight: SettingsCognitiveWeightClass

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "scalemass")
                .font(.system(size: 9, weight: .semibold))
            Text("\(weight.rawValue) \(weight.label)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(weight.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(weight.tint.opacity(0.10), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(weight.tint.opacity(0.30), lineWidth: 0.75)
        }
        .help(weight.help)
        .accessibilityLabel(weight.help)
    }
}
