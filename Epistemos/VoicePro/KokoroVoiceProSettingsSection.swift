import AppKit
import SwiftUI

nonisolated enum KokoroVoiceProSettingsModel {
    enum RuntimeChoice: String, CaseIterable, Identifiable, Sendable {
        case textToSpeechUnavailable
        case kokoroNeural

        var id: String { rawValue }

        var title: String {
            switch self {
            case .textToSpeechUnavailable:
                return "TTS unavailable"
            case .kokoroNeural:
                return "Kokoro neural voice"
            }
        }
    }

    struct Presentation: Equatable, Sendable {
        let selectedRuntime: RuntimeChoice
        let proRuntimeEnabled: Bool
        let headline: String
        let detail: String
        let badgeTitle: String
        let packageEvidenceSummary: String?
    }

    static func presentation(for status: KokoroVoiceGateStatus.Status) -> Presentation {
        switch status.state {
        case .packageReady:
            return Presentation(
                selectedRuntime: .textToSpeechUnavailable,
                proRuntimeEnabled: false,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: "Package ready",
                packageEvidenceSummary: status.packageEvidence?.settingsSummary
            )
        case .missingModel:
            return Presentation(
                selectedRuntime: .textToSpeechUnavailable,
                proRuntimeEnabled: false,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: "Model required",
                packageEvidenceSummary: nil
            )
        case .unavailable:
            return Presentation(
                selectedRuntime: .textToSpeechUnavailable,
                proRuntimeEnabled: false,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: "Unavailable",
                packageEvidenceSummary: nil
            )
        }
    }
}

@MainActor
struct KokoroVoiceProSettingsSection: View {
    @Environment(UIState.self) private var ui
    @State private var status = KokoroVoiceGateStatus.status()
    @State private var installMessage: String?
    @State private var isInstalling = false
    @State private var isRemoving = false

    private var theme: EpistemosTheme {
        ui.theme
    }

    private var isBusy: Bool {
        isInstalling || isRemoving
    }

    private var mutedTint: Color {
        theme.resolved.mutedForeground.color
    }

    private func badgeTint(for presentation: KokoroVoiceProSettingsModel.Presentation) -> Color {
        presentation.proRuntimeEnabled
            ? theme.resolved.accent.color
            : theme.resolved.headingAccent.color
    }

    var body: some View {
        let presentation = KokoroVoiceProSettingsModel.presentation(for: status)
        let badgeTint = badgeTint(for: presentation)

        Section("Voice Pro") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.badge.sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(mutedTint)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Kokoro-82M")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(presentation.badgeTitle)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(badgeTint.opacity(theme.isDark ? 0.18 : 0.12))
                            )
                            .foregroundStyle(badgeTint)
                    }

                    Picker("Runtime", selection: .constant(presentation.selectedRuntime)) {
                        ForEach(KokoroVoiceProSettingsModel.RuntimeChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!presentation.proRuntimeEnabled)

                    Text(presentation.headline)
                        .font(.caption.weight(.semibold))
                    Text(presentation.detail)
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                        .fixedSize(horizontal: false, vertical: true)

                    if let packageEvidenceSummary = presentation.packageEvidenceSummary {
                        Text(packageEvidenceSummary)
                            .font(.caption)
                            .foregroundStyle(mutedTint)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let installMessage {
                        Text(installMessage)
                            .font(.caption)
                            .foregroundStyle(mutedTint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 10) {
                ToolbarCapsuleButton(
                    title: isInstalling ? "Installing" : "Install Package",
                    systemImage: "square.and.arrow.down",
                    role: .primaryAction,
                    chromePolicy: .alwaysSurface,
                    helpText: "Install a checked local Kokoro package",
                    accessibilityLabel: "Install a checked local Kokoro package"
                ) {
                    choosePackageForInstall()
                }
                .disabled(isBusy)

                if status.state == .packageReady {
                    ToolbarCapsuleButton(
                        title: isRemoving ? "Removing" : "Remove Package",
                        systemImage: "trash",
                        role: .toolbarUtility,
                        chromePolicy: .alwaysSurface,
                        helpText: "Remove the installed local Kokoro package",
                        accessibilityLabel: "Remove the installed local Kokoro package"
                    ) {
                        removeInstalledPackage()
                    }
                    .disabled(isBusy)
                }

                ToolbarCapsuleButton(
                    title: "Refresh",
                    systemImage: "arrow.clockwise",
                    role: .toolbarUtility,
                    chromePolicy: .alwaysSurface,
                    helpText: "Refresh Pro voice status",
                    accessibilityLabel: "Refresh Pro voice status"
                ) {
                    status = KokoroVoiceGateStatus.status()
                }
                .disabled(isBusy)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func choosePackageForInstall() {
        guard !isBusy else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Install"
        panel.message = "Choose \(KokoroVoiceGateStatus.modelDirectoryName) or its parent folder."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        installPackage(from: url)
    }

    private func installPackage(from url: URL) {
        guard !isBusy else { return }

        isInstalling = true
        installMessage = "Checking local Kokoro package..."
        let gainedSecurityScope = url.startAccessingSecurityScopedResource()

        Task { @MainActor in
            defer {
                if gainedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
                isInstalling = false
            }

            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try KokoroVoicePackageInstaller.installCheckedPackage(from: url)
                }.value
                status = result.status
                installMessage = installedPackageMessage(for: result.status)
            } catch {
                installMessage = KokoroVoicePackageInstaller.statusMessage(for: error)
                status = KokoroVoiceGateStatus.status()
            }
        }
    }

    private func removeInstalledPackage() {
        guard !isBusy else { return }

        isRemoving = true
        installMessage = "Removing local Kokoro package..."

        Task { @MainActor in
            defer {
                isRemoving = false
            }

            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try KokoroVoicePackageInstaller.removeInstalledPackage()
                }.value
                status = result.status
                installMessage = VoiceCapturePresentationBounds.statusMessage(
                    "Removed local Kokoro package. \(result.status.headline)",
                    fallback: "Kokoro package removed."
                )
            } catch {
                installMessage = KokoroVoicePackageInstaller.statusMessage(for: error)
                status = KokoroVoiceGateStatus.status()
            }
        }
    }

    private func installedPackageMessage(for status: KokoroVoiceGateStatus.Status) -> String {
        if let evidence = status.packageEvidence {
            return VoiceCapturePresentationBounds.statusMessage(
                "Installed checked Kokoro package. \(evidence.settingsSummary)",
                fallback: "Kokoro package installed."
            )
        }

        return VoiceCapturePresentationBounds.statusMessage(
            "Installed checked Kokoro package. \(status.headline)",
            fallback: "Kokoro package installed."
        )
    }
}

#if DEBUG
#Preview("KokoroVoiceProSettingsSection") {
    Form {
        KokoroVoiceProSettingsSection()
    }
    .environment(UIState())
    .frame(width: 540, height: 260)
}
#endif
