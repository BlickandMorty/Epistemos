import SwiftUI

@MainActor
public struct SubstrateHealthPanel: View {
    public init() {}

    @State private var showFoundation = true
    @State private var showRetrieval = true
    @State private var showHonesty = true
    @State private var showTools = true
    @State private var healthClock = SubstrateHealthClock()

    public var body: some View {
        Form {
            SettingsDescriptionText(
                text: """
                Epistemos Foundation is the app-side IP that stays native: search, \
                citation grounding, vault memory, tools/MCP, provenance, and \
                verification. Generation engines live in Goose/OpenGUI/OpenCode-style \
                surfaces, so this panel exposes only foundation features and health.
                """
            )

            Section("Foundation Features", isExpanded: $showFoundation) {
                foundationFeature(
                    title: "Skills, Tools, and MCP",
                    detail: "Native capability plane exposed to Work/OpenCode and future Goose/OpenGUI bridges through the app-owned tool layer."
                )
                foundationFeature(
                    title: "Halo, Shadow, and Fast Search",
                    detail: "Vault recall, RRF search fusion, Eidos citation grounding, and editor indexing."
                )
                foundationFeature(
                    title: "Provenance and Answer Witnesses",
                    detail: "AnswerPacket, RunEventLog, ClaimLedger-style records, falsifier artifacts, and replayable audit traces."
                )
                foundationFeature(
                    title: "Vault Memory",
                    detail: "App-side recall/context features that serve surfaces without owning generation or training."
                )
                foundationFeature(
                    title: "Sovereign Safety",
                    detail: "SovereignGate, privacy boundaries, capability checks, and signed-action guardrails."
                )
            }

            Section("Retrieval and Indexing", isExpanded: $showRetrieval) {
                SettingsDescriptionText(
                    text: "Read-only health for app-side retrieval, citations, editor assets, and cross-index search."
                )
                EidosHealthRow()
                VaultRecallHealthRow()
                SearchFusionHealthRow()
                EmlRerankGateHealthRow()
                EditorBundleHealthRow()
            }

            Section("Honesty and Provenance", isExpanded: $showHonesty) {
                SettingsDescriptionText(
                    text: "Verification surfaces that make native actions and answers inspectable without owning a model runtime."
                )
                AnswerPacketHealthRow()
                FalsifierArtifactsHealthRow()
                FUlpHealthRow()
                LatticeWBOHealthRow()
                SubstrateDriftMonitorHealthRow()
            }

            Section("Tools and Surface Bridge", isExpanded: $showTools) {
                SettingsDescriptionText(
                    text: "Native app capabilities that Goose/OpenGUI/OpenCode-style surfaces can call through the app-owned bridge."
                )
                DeterministicSchemaGateHealthRow()
                WorkOpenCodeShellHealthRow()
                WorkBackendHealthRow()
                LiteParseImportHealthRow()
                LiteParseSettingsImportRow()
            }
        }
        .formStyle(.grouped)
        .environment(healthClock)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: SubstrateHealthClock.defaultPollInterval)
                await healthClock.tickWithUnifiedRefresh()
            }
        }
    }

    private func foundationFeature(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(detail)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: Rectangle())
        .overlay {
            Rectangle()
                .stroke(.secondary.opacity(0.14), lineWidth: 0.75)
        }
    }
}
