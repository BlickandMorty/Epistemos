import SwiftUI

// MARK: - Model Vaults Settings
// Exposes the Cloud Knowledge Distillation system to users.
// Each cloud provider gets a compiled "vault" of knowledge from
// the user's notes — domain map, concept index, active context.

struct ModelVaultsSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isRebuilding = false
    @State private var lastRebuildDate: Date?
    @State private var conceptCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Vaults")
                        .font(.title2.weight(.semibold))

                    Text("Knowledge vaults compile your notes into structured context for each AI provider. This helps Claude, GPT, and Gemini understand your domain, writing style, and active projects.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Vault Status
                GroupBox("Vault Status") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Last compiled", systemImage: "clock")
                            Spacer()
                            if let date = lastRebuildDate {
                                Text(date, style: .relative)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Never")
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        HStack {
                            Label("Concepts indexed", systemImage: "lightbulb")
                            Spacer()
                            Text("\(conceptCount)")
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Button {
                            rebuildVaults()
                        } label: {
                            HStack {
                                if isRebuilding {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Rebuilding...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Rebuild All Vaults")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRebuilding)
                    }
                    .padding(4)
                }

                // Per-Provider Vaults
                GroupBox("Provider Vaults") {
                    VStack(alignment: .leading, spacing: 8) {
                        VaultRow(provider: "Claude (Anthropic)", icon: "brain.head.profile", status: .compiled)
                        Divider()
                        VaultRow(provider: "GPT (OpenAI)", icon: "sparkles.rectangle.stack", status: .compiled)
                        Divider()
                        VaultRow(provider: "Gemini (Google)", icon: "diamond", status: .compiled)
                        Divider()
                        VaultRow(provider: "Local (Qwen/Gemma)", icon: "memorychip", status: .compiled)
                    }
                    .padding(4)
                }

                // Vault Files
                GroupBox("Compiled Files") {
                    VStack(alignment: .leading, spacing: 8) {
                        VaultFileRow(name: "knowledge_profile.md", description: "Domain map, entity graph, writing style")
                        Divider()
                        VaultFileRow(name: "concept_index.md", description: "Top 50-100 concepts from your vault")
                        Divider()
                        VaultFileRow(name: "active_context.md", description: "Rolling 7-day activity window")
                        Divider()
                        VaultFileRow(name: "instructions.md", description: "Your preferences and conventions")
                    }
                    .padding(4)
                }

                // NightBrain Integration
                GroupBox("Background Compilation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Auto-compile on note changes", isOn: .constant(true))
                            .disabled(true)

                        Text("Vaults are automatically recompiled when you edit notes. NightBrain handles this in the background.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(4)
                }
            }
            .padding(24)
        }
    }

    private func rebuildVaults() {
        isRebuilding = true
        Task {
            if let service = AppBootstrap.shared?.cloudKnowledgeDistillationService {
                _ = try? await service.rebuildAllModelVaults()
            }
            lastRebuildDate = Date()
            isRebuilding = false
        }
    }
}

// MARK: - Vault Row

private struct VaultRow: View {
    let provider: String
    let icon: String
    let status: VaultStatus

    enum VaultStatus {
        case compiled, outdated, missing
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(provider)
                .font(.body)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(status == .compiled ? .green : status == .outdated ? .orange : .red)
                    .frame(width: 8, height: 8)
                Text(status == .compiled ? "Compiled" : status == .outdated ? "Outdated" : "Missing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Vault File Row

private struct VaultFileRow: View {
    let name: String
    let description: String

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.monospaced())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }
}
