import SwiftUI

// MARK: - Setup Assistant

/// First-run setup wizard that guides the user through essential configuration.
/// Shows automatically on first launch.
/// Steps: 1) Welcome → 2) Vault → 3) Local Model (optional) → 4) Agent Runtime → 5) Done
struct SetupAssistantView: View {
    private static let stepTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)

    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference

    @State private var currentStep: SetupStep = .welcome

    let onComplete: () -> Void

    private var selectedCloudSetupProvider: CloudModelProvider {
        inference.activeCloudProvider ?? .google
    }

    private var cloudSetupProviderBinding: Binding<CloudModelProvider> {
        Binding(
            get: { selectedCloudSetupProvider },
            set: { inference.setActiveAIProvider(AIProviderSelection(cloudProvider: $0)) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(SetupStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Content
            Group {
                switch currentStep {
                case .welcome: welcomeStep
                case .vault: vaultStep
                case .model: modelStep
                case .agentRuntime: agentRuntimeStep
                case .done: doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Welcome

    @ViewBuilder
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Epistemos")
                .font(.title.bold())
            Text("Your local-first knowledge engine. Let's get you set up in a few quick steps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Get Started") {
                withAnimation(Self.stepTransition) { currentStep = .vault }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Vault

    @ViewBuilder
    private var vaultStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            Text("Connect Your Vault")
                .font(.title2.bold())
            Text("Choose the folder Epistemos should sync with. The app keeps local note bodies and can import from or sync out to Markdown files in your vault.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let url = vaultSync.vaultURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(url.lastPathComponent)
                        .font(.subheadline.bold())
                }
                .padding()
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack(spacing: 12) {
                if vaultSync.vaultURL != nil {
                    Button("Skip") { withAnimation(Self.stepTransition) { currentStep = .model } }
                        .buttonStyle(.bordered)
                }
                Button(vaultSync.vaultURL != nil ? "Change Vault" : "Select Vault Folder") {
                    selectVaultFolder()
                }
                .buttonStyle(.borderedProminent)
                Button("Next") { withAnimation(Self.stepTransition) { currentStep = .model } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vaultSync.vaultURL == nil)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Model

    @ViewBuilder
    private var modelStep: some View {
        let hasModel = inference.hasUsableLocalTextModel
        let runtimeStatusLabel = inference.localModelInstallStateSummary.displayName
        let installedModelLabel = inference.activeLocalTextModelDisplayName

        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 40))
                .foregroundStyle(.purple)
            Text("Private Note Intelligence")
                .font(.title2.bold())
            Text("Epistemos can run private note intelligence locally on your Mac. Installing a model enables note chat, summarization, and analysis, but you can skip this for now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if hasModel {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(verbatim: "Local runtime ready (\(runtimeStatusLabel)): \(installedModelLabel)")
                        .font(.caption)
                }
                .padding()
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("You can install a model later in Settings → Inference.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") { withAnimation(Self.stepTransition) { currentStep = .agentRuntime } }
                    .buttonStyle(.bordered)
                if !hasModel {
                    Button("Open Settings → Inference") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if hasModel {
                    Button("Next") { withAnimation(Self.stepTransition) { currentStep = .agentRuntime } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Cloud AI Setup

    @ViewBuilder
    private var agentRuntimeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            Text("Cloud AI (Optional)")
                .font(.title2.bold())
            Text("Connect a cloud AI provider for advanced capabilities like tool use, deep research, and extended reasoning. Local models work great on their own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Cloud AI Provider")
                    .font(.subheadline.weight(.semibold))

                Picker("Cloud AI Provider", selection: cloudSetupProviderBinding) {
                    ForEach(CloudModelProvider.preferredOrder, id: \.rawValue) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)

                CloudProviderSetupCard(
                    provider: selectedCloudSetupProvider,
                    title: "Connect \(selectedCloudSetupProvider.displayName)",
                    message: selectedCloudSetupProvider.setupHelpText,
                    footer: selectedCloudSetupProvider.supportsAccountConnection
                        ? "Start with the provider account flow here. Expand Legacy API Key only if you intentionally want the manual fallback."
                        : "This provider uses the direct API route in Epistemos today. Open the provider portal, create a key, then use Paste + Save.",
                    showsDismissTip: false
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") {
                    withAnimation(Self.stepTransition) { currentStep = .done }
                }
                .buttonStyle(.bordered)

                Button("Next") {
                    withAnimation(Self.stepTransition) { currentStep = .done }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Done

    @ViewBuilder
    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("You're All Set!")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 8) {
                statusRow("Vault", done: vaultSync.vaultURL != nil)
                statusRow("Local AI", done: inference.hasUsableLocalTextModel)
                statusRow("Cloud AI", done: inference.activeCloudProvider != nil)
            }

            Text("You can change any of these in Settings at any time.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Start Using Epistemos") {
                UserDefaults.standard.set(true, forKey: "epistemos.setupComplete")
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func statusRow(_ name: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(name)
                .font(.subheadline)
        }
    }

    private func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Epistemos vault"
        panel.prompt = "Use as Vault"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        VaultConnectionActions.connectSelectedVault(url: url, vaultSync: vaultSync)
    }
}

// MARK: - Setup Step

enum SetupStep: Int, CaseIterable, Comparable {
    case welcome = 0
    case vault = 1
    case model = 2
    case agentRuntime = 3
    case done = 4

    static func < (lhs: SetupStep, rhs: SetupStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
