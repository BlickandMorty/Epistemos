import SwiftUI

// MARK: - Model Profile Detail View (v2)

/// Full detail view for a model profile showing vault, adapters,
/// inference settings, graph configuration, and usage statistics.
struct ModelProfileDetailView: View {
    let profile: SDModelProfile
    let profileManager: ModelProfileManager

    @State private var editedTemperature: Double
    @State private var editedTopP: Double
    @State private var editedMaxTokens: Int
    @State private var editedThinking: Bool

    init(profile: SDModelProfile, profileManager: ModelProfileManager) {
        self.profile = profile
        self.profileManager = profileManager
        _editedTemperature = State(initialValue: profile.temperature)
        _editedTopP = State(initialValue: profile.topP)
        _editedMaxTokens = State(initialValue: profile.maxOutputTokens)
        _editedThinking = State(initialValue: profile.thinkingEnabled)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Vault
                vaultSection

                // Adapters (local models only)
                if profile.supportsFinetuning {
                    Divider()
                    adaptersSection
                }

                Divider()

                // Inference Settings
                inferenceSection

                Divider()

                // Statistics
                statsSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.isCloudModel ? "cloud.fill" : "cpu.fill")
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.title2.bold())
                HStack(spacing: 6) {
                    Text(profile.isCloudModel ? "Cloud" : "Local")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    Text(profile.modelIdentifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if profileManager.activeProfile?.id == profile.id {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var vaultSection: some View {
        GroupBox("Vault") {
            LabeledContent("Knowledge Base") {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                    Text(profile.vaultDisplayName)
                }
            }
            LabeledContent("Vault Key", value: profile.vaultIdentityKey)
        }
    }

    private var adaptersSection: some View {
        GroupBox("Fine-Tuned Adapters") {
            if profile.adapterIds.isEmpty {
                Text("No adapters trained yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(profile.adapterIds, id: \.self) { adapterId in
                    HStack {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .foregroundStyle(.purple)
                        Text(adapterId.prefix(8))
                            .font(.caption.monospaced())
                        Spacer()
                        if profile.activeAdapterId == adapterId {
                            Text("Active")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            Button("Train New Adapter") {
                // Navigate to Knowledge Fusion training view
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
    }

    private var inferenceSection: some View {
        GroupBox("Inference Settings") {
            VStack(spacing: 8) {
                LabeledContent("Temperature") {
                    Slider(value: $editedTemperature, in: 0...2, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.1f", editedTemperature))
                        .font(.caption.monospaced())
                        .frame(width: 30)
                }

                LabeledContent("Top-P") {
                    Slider(value: $editedTopP, in: 0...1, step: 0.05)
                        .frame(width: 150)
                    Text(String(format: "%.2f", editedTopP))
                        .font(.caption.monospaced())
                        .frame(width: 40)
                }

                LabeledContent("Max Tokens") {
                    Picker("", selection: $editedMaxTokens) {
                        Text("1024").tag(1024)
                        Text("2048").tag(2048)
                        Text("4096").tag(4096)
                        Text("8192").tag(8192)
                    }
                    .frame(width: 100)
                }

                Toggle("Thinking Mode", isOn: $editedThinking)
            }
        }
    }

    private var statsSection: some View {
        GroupBox("Usage") {
            LabeledContent("Conversations", value: "\(profile.conversationCount)")
            LabeledContent("Tokens Processed", value: formatTokens(profile.totalTokensProcessed))
            LabeledContent("Created", value: profile.createdAt.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Last Active", value: profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
