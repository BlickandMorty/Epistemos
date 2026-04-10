import SwiftUI

// MARK: - Model Profile Creation Sheet (v2)

/// Multi-step creation wizard for new model profiles.
/// Supports both local models (with fine-tuning) and cloud models.
struct ModelProfileCreationSheet: View {
    let profileManager: ModelProfileManager
    @Environment(\.dismiss) private var dismiss

    @State private var step: CreationStep = .chooseType
    @State private var profileType: ProfileType = .local
    @State private var displayName = ""
    @State private var selectedModel = ""
    @State private var selectedVault = "personal"
    @State private var vaultDisplayName = "Personal"
    @State private var cloudProvider = "claude_sonnet"

    enum CreationStep: Int {
        case chooseType, configure, confirm
    }

    enum ProfileType: String {
        case local, cloud
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Model Profile")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Steps
            VStack(spacing: 16) {
                switch step {
                case .chooseType:
                    typeSelectionView
                case .configure:
                    configurationView
                case .confirm:
                    confirmationView
                }
            }
            .padding()

            Spacer()

            // Navigation
            HStack {
                if step.rawValue > 0 {
                    Button("Back") {
                        step = CreationStep(rawValue: step.rawValue - 1) ?? .chooseType
                    }
                }
                Spacer()
                if step == .confirm {
                    Button("Create") { createProfile() }
                        .buttonStyle(.borderedProminent)
                        .disabled(displayName.isEmpty)
                } else {
                    Button("Next") {
                        step = CreationStep(rawValue: step.rawValue + 1) ?? .confirm
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 420, height: 380)
    }

    // MARK: - Step Views

    private var typeSelectionView: some View {
        VStack(spacing: 12) {
            Text("What kind of model?")
                .font(.title3)

            HStack(spacing: 12) {
                TypeCard(
                    title: "Local Model",
                    subtitle: "On-device inference with fine-tuning",
                    icon: "cpu.fill",
                    isSelected: profileType == .local
                ) { profileType = .local }

                TypeCard(
                    title: "Cloud Model",
                    subtitle: "API-based (Claude, Perplexity)",
                    icon: "cloud.fill",
                    isSelected: profileType == .cloud
                ) { profileType = .cloud }
            }
        }
    }

    private var configurationView: some View {
        Form {
            TextField("Profile Name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            if profileType == .local {
                Picker("Base Model", selection: $selectedModel) {
                    Text("Qwen 3.5 4B").tag("qwen3.5-4b")
                    Text("Gemma 4 4B").tag("gemma4-4b")
                    Text("SmolLM3 3B").tag("smollm3-3b")
                    Text("Mistral 7B").tag("mistral-7b")
                }
            } else {
                Picker("Provider", selection: $cloudProvider) {
                    Text("Claude Sonnet 4.6").tag("claude_sonnet")
                    Text("Claude Opus 4.6").tag("claude_opus")
                    Text("Claude Haiku 4.5").tag("claude_haiku")
                    Text("Perplexity Sonar Pro").tag("perplexity")
                }
            }

            Picker("Vault", selection: $selectedVault) {
                Text("Personal").tag("personal")
                Text("Work").tag("work")
                Text("Research").tag("research")
            }
        }
    }

    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirm Profile")
                .font(.title3)

            GroupBox {
                LabeledContent("Name", value: displayName.isEmpty ? "(untitled)" : displayName)
                LabeledContent("Type", value: profileType == .local ? "Local" : "Cloud")
                LabeledContent("Model", value: profileType == .local ? selectedModel : cloudProvider)
                LabeledContent("Vault", value: vaultDisplayName)
                if profileType == .local {
                    LabeledContent("Fine-tuning", value: "Available")
                }
            }
        }
    }

    // MARK: - Actions

    private func createProfile() {
        if profileType == .local {
            _ = profileManager.createLocalProfile(
                displayName: displayName,
                modelIdentifier: selectedModel,
                vaultIdentityKey: selectedVault,
                vaultDisplayName: vaultDisplayName
            )
        } else {
            _ = profileManager.createCloudProfile(
                displayName: displayName,
                cloudProvider: cloudProvider,
                vaultIdentityKey: selectedVault,
                vaultDisplayName: vaultDisplayName
            )
        }
        dismiss()
    }
}

// MARK: - Type Card

private struct TypeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
