import SwiftUI
import ScreenCaptureKit

// MARK: - Setup Assistant

/// First-run setup wizard that guides the user through essential configuration.
/// Shows automatically when key requirements aren't met (no vault, no model, no permissions).
/// Steps: 1) Welcome → 2) Vault → 3) Local Model → 4) Permissions → 5) Done
struct SetupAssistantView: View {
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference

    @State private var currentStep: SetupStep = .welcome
    @State private var isCheckingPermissions = false
    @State private var accessibilityGranted = false
    @State private var screenRecordingGranted = false

    let onComplete: () -> Void

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
                case .permissions: permissionsStep
                case .done: doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
        }
        .frame(width: 520, height: 440)
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
                withAnimation { currentStep = .vault }
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
            Text("Choose a folder where your notes live (or will live). This is your knowledge vault — all notes are stored as Markdown files.")
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
                    Button("Skip") { withAnimation { currentStep = .model } }
                        .buttonStyle(.bordered)
                }
                Button(vaultSync.vaultURL != nil ? "Change Vault" : "Select Vault Folder") {
                    selectVaultFolder()
                }
                .buttonStyle(.borderedProminent)
                Button("Next") { withAnimation { currentStep = .model } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vaultSync.vaultURL == nil)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Model

    @ViewBuilder
    private var modelStep: some View {
        let hasModel = !inference.installedLocalTextModelIDs.isEmpty

        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 40))
                .foregroundStyle(.purple)
            Text("Local AI Model")
                .font(.title2.bold())
            Text("Epistemos runs AI locally on your Mac. The recommended model (Qwen 3.5 4B) provides fast, private intelligence for note analysis and the Omega agent.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if hasModel {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Model installed: \(inference.effectiveLocalTextModelID)")
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
                Button("Skip") { withAnimation { currentStep = .permissions } }
                    .buttonStyle(.bordered)
                if !hasModel {
                    Button("Open Settings → Inference") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        // User will install from settings, then come back
                    }
                    .buttonStyle(.borderedProminent)
                }
                if hasModel {
                    Button("Next") { withAnimation { currentStep = .permissions } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Permissions

    @ViewBuilder
    private var permissionsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("System Permissions")
                .font(.title2.bold())
            Text("The Omega agent needs Accessibility (for UI automation) and Screen Recording (for screen capture). These are optional — Epistemos works without them, but Omega will be limited.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                permissionRow(
                    name: "Accessibility",
                    icon: "hand.tap",
                    granted: accessibilityGranted
                ) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                permissionRow(
                    name: "Screen Recording",
                    icon: "rectangle.dashed.badge.record",
                    granted: screenRecordingGranted
                ) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding()
            .background(.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isCheckingPermissions {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") { withAnimation { currentStep = .done } }
                    .buttonStyle(.bordered)
                Button("Refresh") {
                    Task { await checkPermissions() }
                }
                .buttonStyle(.bordered)
                Button("Next") { withAnimation { currentStep = .done } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 24)
        .task { await refreshPermissions() }
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
                statusRow("Local Model", done: !inference.installedLocalTextModelIDs.isEmpty)
                statusRow("Accessibility", done: accessibilityGranted)
                statusRow("Screen Recording", done: screenRecordingGranted)
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

    private func permissionRow(name: String, icon: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
            Text(name)
                .font(.subheadline)
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

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
        vaultSync.persistVaultSelection(url)
        vaultSync.startWatching(vaultURL: url)
    }

    private func refreshPermissions() async {
        isCheckingPermissions = true
        let status = OmegaPermissions.checkAccessibility()
        accessibilityGranted = status
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            screenRecordingGranted = true
        } catch {
            screenRecordingGranted = false
        }
        isCheckingPermissions = false
    }
}

// MARK: - Setup Step

enum SetupStep: Int, CaseIterable, Comparable {
    case welcome = 0
    case vault = 1
    case model = 2
    case permissions = 3
    case done = 4

    static func < (lhs: SetupStep, rhs: SetupStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
