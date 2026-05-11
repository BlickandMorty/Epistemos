import SwiftUI

// MARK: - Setup Assistant

/// First-run setup wizard that guides the user through essential configuration.
/// Shows automatically on first launch.
/// Steps: 1) Welcome → 2) Vault → 3) Local Model (optional) → 4) Agent Runtime → 5) Done
struct SetupAssistantView: View {
    private static let stepTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)

    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep: SetupStep = .welcome

    let onComplete: () -> Void

    private var stepTransitionAnimation: Animation? {
        reduceMotion ? nil : Self.stepTransition
    }

    private var theme: EpistemosTheme { ui.theme }
    private var bodyFont: Font { .system(size: 12, weight: .regular, design: .monospaced) }
    private var captionFont: Font { .system(size: 10, weight: .medium, design: .monospaced) }

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
            HStack(spacing: 6) {
                ForEach(SetupStep.allCases, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? theme.fontAccent : theme.textTertiary.opacity(0.28))
                        .frame(width: 14, height: 6)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

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
        .frame(width: 620, height: 620)
        .background {
            PixelSetupBackground(theme: theme)
        }
    }

    // MARK: - Welcome

    @ViewBuilder
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            SetupPixelGlyph(kind: .sigil, tint: theme.fontAccent)
            Text("Welcome to Epistemos")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)
            Text("Your local-first knowledge engine. Let's get you set up in a few quick steps.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Get Started") {
                withAnimation(stepTransitionAnimation) { currentStep = .vault }
            }
            .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
        }
        .padding(.vertical, 24)
    }

    // MARK: - Vault

    @ViewBuilder
    private var vaultStep: some View {
        VStack(spacing: 16) {
            SetupPixelGlyph(kind: .vault, tint: .blue)
            Text("Connect Your Vault")
                .font(AppDisplayTypography.font(size: 20))
                .foregroundStyle(theme.fontAccent)
            Text("Choose the folder Epistemos should sync with. The app keeps local note bodies and can import from or sync out to Markdown files in your vault.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            if let url = vaultSync.vaultURL {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(theme.success)
                        .frame(width: 8, height: 8)
                    Text(url.lastPathComponent)
                        .font(captionFont)
                }
                .padding()
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            if let details = vaultSync.visibleVaultImportDetails {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        if vaultSync.vaultImportProgress != nil {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(details.compactStatusMessage)
                            .font(captionFont)
                            .foregroundStyle(theme.textPrimary)
                    }
                    if let fraction = details.progressFraction, vaultSync.vaultImportProgress != nil {
                        ProgressView(value: fraction)
                    }
                    Text(details.inventorySummary)
                        .font(captionFont)
                        .foregroundStyle(theme.textSecondary)
                    Text("Result: \(details.mutationSummary). Diagnostics: \(details.issueSummary).")
                        .font(captionFont)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(12)
                .background(theme.card.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") { withAnimation(stepTransitionAnimation) { currentStep = .model } }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .secondary))
                Button(vaultSync.vaultURL != nil ? "Change Vault" : "Select Vault Folder") {
                    selectVaultFolder()
                }
                .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
                Button("Next") { withAnimation(stepTransitionAnimation) { currentStep = .model } }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
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
            SetupPixelGlyph(kind: .chip, tint: .purple)
            Text("Private Note Intelligence")
                .font(AppDisplayTypography.font(size: 20))
                .foregroundStyle(theme.fontAccent)
            Text("Epistemos can run private note intelligence locally on your Mac. Installing a model enables note chat, summarization, and analysis, but you can skip this for now.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            if hasModel {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(theme.success)
                        .frame(width: 8, height: 8)
                    Text(verbatim: "Local runtime ready (\(runtimeStatusLabel)): \(installedModelLabel)")
                        .font(captionFont)
                }
                .padding()
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                Text("You can install a model later in Settings → Inference.")
                    .font(captionFont)
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") { withAnimation(stepTransitionAnimation) { currentStep = .agentRuntime } }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .secondary))
                if !hasModel {
                    Button("Open Settings → Inference") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
                }
                if hasModel {
                    Button("Next") { withAnimation(stepTransitionAnimation) { currentStep = .agentRuntime } }
                        .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
                }
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Cloud AI Setup

    @ViewBuilder
    private var agentRuntimeStep: some View {
        VStack(spacing: 16) {
            SetupPixelGlyph(kind: .cloud, tint: .blue)
            Text("Cloud AI (Optional)")
                .font(AppDisplayTypography.font(size: 20))
                .foregroundStyle(theme.fontAccent)
            Text("Connect a cloud AI provider for advanced capabilities like tool use, deep research, and extended reasoning. Local models work great on their own.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cloud AI Provider")
                        .font(captionFont)
                        .foregroundStyle(theme.fontAccent)

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
                        showsDismissTip: false,
                        pixelPresentation: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
            }
            .frame(maxHeight: 300)

            HStack(spacing: 12) {
                Button("Skip") {
                    withAnimation(stepTransitionAnimation) { currentStep = .done }
                }
                .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .secondary))

                Button("Finish Setup") {
                    withAnimation(stepTransitionAnimation) { currentStep = .done }
                }
                .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Done

    @ViewBuilder
    private var doneStep: some View {
        VStack(spacing: 20) {
            SetupPixelGlyph(kind: .check, tint: theme.success)
            Text("You're All Set!")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)

            VStack(alignment: .leading, spacing: 8) {
                statusRow("Vault", done: vaultSync.vaultURL != nil)
                statusRow("Local AI", done: inference.hasUsableLocalTextModel)
                statusRow("Cloud AI", done: inference.activeCloudProvider != nil)
            }

            Text("You can change any of these in Settings at any time.")
                .font(captionFont)
                .foregroundStyle(theme.textTertiary)

            Spacer()

            Button("Start Using Epistemos") {
                UserDefaults.standard.set(true, forKey: "epistemos.setupComplete")
                onComplete()
            }
            .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
        }
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func statusRow(_ name: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(done ? theme.success : theme.textTertiary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(name)
                .font(bodyFont)
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

private struct PixelSetupBackground: View {
    let theme: EpistemosTheme

    var body: some View {
        ZStack {
            theme.resolved.background.color
            VStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<10, id: \.self) { column in
                            Rectangle()
                                .fill(theme.fontAccent.opacity((row + column).isMultiple(of: 3) ? 0.045 : 0.02))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(24)
        }
    }
}

private struct SetupPixelGlyph: View {
    enum Kind {
        case sigil
        case vault
        case chip
        case cloud
        case check
    }

    let kind: Kind
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let cell = floor(min(size.width, size.height) / 12)
            let origin = CGPoint(
                x: floor((size.width - cell * 12) / 2),
                y: floor((size.height - cell * 12) / 2)
            )
            for block in blocks {
                let rect = CGRect(
                    x: origin.x + CGFloat(block.x) * cell,
                    y: origin.y + CGFloat(block.y) * cell,
                    width: CGFloat(block.w) * cell,
                    height: CGFloat(block.h) * cell
                )
                context.fill(Path(rect), with: .color(block.isAccent ? .white.opacity(0.75) : tint))
            }
        }
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
    }

    private var blocks: [(x: Int, y: Int, w: Int, h: Int, isAccent: Bool)] {
        switch kind {
        case .sigil:
            [
                (2, 2, 8, 2, false), (2, 4, 2, 6, false), (5, 4, 4, 2, false),
                (5, 7, 3, 2, false), (2, 10, 8, 1, false), (8, 6, 2, 4, false),
                (4, 6, 2, 1, true), (4, 8, 2, 1, true)
            ]
        case .vault:
            [
                (2, 3, 8, 5, false), (1, 8, 10, 2, false), (3, 2, 6, 1, false),
                (3, 4, 6, 1, true), (8, 6, 1, 1, true)
            ]
        case .chip:
            [
                (3, 3, 6, 6, false), (1, 4, 2, 1, false), (1, 7, 2, 1, false),
                (9, 4, 2, 1, false), (9, 7, 2, 1, false), (4, 1, 1, 2, false),
                (7, 1, 1, 2, false), (4, 9, 1, 2, false), (7, 9, 1, 2, false),
                (5, 5, 2, 2, true)
            ]
        case .cloud:
            [
                (3, 5, 7, 3, false), (2, 6, 9, 2, false), (4, 3, 3, 2, false),
                (7, 4, 3, 2, false), (4, 6, 4, 1, true)
            ]
        case .check:
            [
                (2, 6, 2, 2, false), (4, 8, 2, 2, false), (6, 6, 2, 2, false),
                (8, 4, 2, 2, false), (9, 3, 1, 1, false), (4, 8, 1, 1, true)
            ]
        }
    }
}

private struct PixelSetupButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
    }

    let theme: EpistemosTheme
    let prominence: Prominence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(background(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(theme.fontAccent.opacity(0.55), lineWidth: 1)
            )
    }

    private func foreground(isPressed: Bool) -> Color {
        switch prominence {
        case .primary:
            isPressed ? theme.resolved.background.color.opacity(0.75) : theme.resolved.background.color
        case .secondary:
            isPressed ? theme.fontAccent.opacity(0.65) : theme.fontAccent
        }
    }

    private func background(isPressed: Bool) -> Color {
        switch prominence {
        case .primary:
            isPressed ? theme.fontAccent.opacity(0.78) : theme.fontAccent
        case .secondary:
            isPressed ? theme.fontAccent.opacity(0.14) : theme.fontAccent.opacity(0.06)
        }
    }
}
