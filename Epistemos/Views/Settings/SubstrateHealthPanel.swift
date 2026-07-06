import SwiftUI

@MainActor
public struct SubstrateHealthPanel: View {
    public init() {}

    @State private var healthClock = SubstrateHealthClock()

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                foundationSection("Foundation Features") {
                    foundationFeature(
                        title: "Skills, Tools, and MCP",
                        detail: "Native capability plane exposed through app-owned tools and bridge contracts."
                    )
                    foundationFeature(
                        title: "Halo, Shadow, and Fast Search",
                        detail: "Vault recall, RRF search fusion, Eidos citation grounding, and editor indexing."
                    )
                    foundationFeature(
                        title: "Provenance and Answer Witnesses",
                        detail: "AnswerPacket, RunEventLog, falsifier artifacts, and replayable audit traces."
                    )
                    foundationFeature(
                        title: "Vault Memory",
                        detail: "App-side recall and context features that serve surfaces without owning generation."
                    )
                    foundationFeature(
                        title: "Sovereign Safety",
                        detail: "SovereignGate, privacy boundaries, capability checks, and signed-action guardrails."
                    )
                }

                foundationSection("Retrieval and Indexing") {
                    EidosHealthRow()
                    VaultRecallHealthRow()
                    SearchFusionHealthRow()
                    EditorBundleHealthRow()
                    FrictionHealthRow()
                }

                foundationSection("Honesty and Provenance") {
                    AnswerPacketHealthRow()
                    FalsifierArtifactsHealthRow()
                }

                foundationSection("Tools and Surface Bridge") {
                    // Plan 1-MAS June surface diagnostics (MAS-only).
                    JuneAgentHealthRow()
                    LiteParseImportHealthRow()
                    LiteParseSettingsImportRow()
                }
            }
            .padding(18)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .environment(healthClock)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: SubstrateHealthClock.defaultPollInterval)
                await healthClock.tickWithUnifiedRefresh()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Epistemos Foundation")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
            SettingsDescriptionText(
                text: """
                App-side IP that stays native: search, citation grounding, vault memory, \
                tools/MCP, provenance, and verification. Generation engines live in \
                surface-specific bridges such as June, Experimental, and OpenCode-style tools.
                """
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: Rectangle())
        .overlay {
            Rectangle().stroke(.secondary.opacity(0.14), lineWidth: 0.75)
        }
    }

    private func foundationSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.55), in: Rectangle())
        .overlay {
            Rectangle().stroke(.secondary.opacity(0.12), lineWidth: 0.75)
        }
    }

    private func foundationFeature(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            SettingsDescriptionText(
                text: detail
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: Rectangle())
        .overlay {
            Rectangle()
                .stroke(.secondary.opacity(0.14), lineWidth: 0.75)
        }
    }
}
