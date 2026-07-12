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
                selectedRuntime: status.isReady ? .kokoroNeural : .textToSpeechUnavailable,
                proRuntimeEnabled: status.isReady,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: status.isReady ? "Ready" : "Package ready",
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

nonisolated enum KokoroVoiceInstallPresentation {
    static let voiceSystemImage = "waveform"
    static let installSystemImage = "arrow.down.circle"
    static let sheetTitle = "Install Kokoro Voice"
    static let sheetSubtitle = "Kokoro-82M read-aloud"
    static let readyStatus = "Kokoro read-aloud is ready."
    static let unavailableLabel = "Install voice"
    static let unavailableAccessibilityLabel = "Install Kokoro voice"
    static let starterInstallTitle = "Install Starter Voice"
    static let highestQualityInstallTitle = "Install Highest Quality Voice"

    static func installHelp(statusMessage: String) -> String {
        "Install Kokoro voice to read aloud. \(statusMessage)"
    }

    static func installTitle(for tier: KokoroModelDownloadService.Tier) -> String {
        switch tier {
        case .starter:
            return starterInstallTitle
        case .standard:
            return "Install Standard Voice"
        case .highestQuality:
            return highestQualityInstallTitle
        }
    }

    static func installHelp(for tier: KokoroModelDownloadService.Tier) -> String {
        "Download and install the \(tier.title.lowercased()) Kokoro voice package. \(tier.approximateSizeLabel)."
    }
}

@MainActor
struct KokoroVoiceDownloadControls: View {
    @Environment(UIState.self) private var ui
    @Binding var selectedTier: KokoroModelDownloadService.Tier

    let isDisabled: Bool
    let idleButtonTitle: String
    let idleButtonHelp: String
    let idleButtonAccessibilityLabel: String
    let onDownload: () -> Void

    private var downloader: KokoroModelDownloadService { KokoroModelDownloadService.shared }

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Quality", selection: $selectedTier) {
                ForEach(KokoroModelDownloadService.Tier.allCases) { tier in
                    Text(tier.title).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            .disabled(downloader.isBusy || isDisabled)

            Text(selectedTier.detail)
                .font(.caption)
                .foregroundStyle(mutedTint)
                .fixedSize(horizontal: false, vertical: true)

            switch downloader.phase {
            case .idle, .installed, .failed:
                ToolbarCapsuleButton(
                    title: actionButtonTitle,
                    systemImage: "arrow.down.circle",
                    role: .primaryAction,
                    chromePolicy: .alwaysSurface,
                    helpText: actionButtonHelp,
                    accessibilityLabel: actionButtonHelp
                ) {
                    onDownload()
                }
                .disabled(downloader.isBusy || isDisabled)
            case .preparing:
                Label("Preparing...", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(mutedTint)
            case let .downloading(received, total):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: downloader.downloadFraction ?? 0)
                    Text("Downloading \(Self.megabytes(received)) of \(Self.megabytes(total))")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                }
            case .installing:
                Label("Installing...", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(mutedTint)
            }

            if downloader.isBusy {
                ToolbarCapsuleButton(
                    title: "Cancel",
                    systemImage: "xmark.circle",
                    role: .toolbarUtility,
                    chromePolicy: .alwaysSurface,
                    helpText: "Cancel Kokoro voice download",
                    accessibilityLabel: "Cancel Kokoro voice download"
                ) {
                    downloader.cancel()
                }
                .disabled(!downloader.isBusy)
            }

            if case let .failed(message) = downloader.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionButtonTitle: String {
        if case .failed = downloader.phase {
            return "Retry \(selectedTier.title) Voice"
        }
        return idleButtonTitle
    }

    private var actionButtonHelp: String {
        if case .failed = downloader.phase {
            return "Retry downloading and installing the \(selectedTier.title.lowercased()) Kokoro voice package. \(selectedTier.approximateSizeLabel)."
        }
        return idleButtonAccessibilityLabel.isEmpty ? idleButtonHelp : idleButtonAccessibilityLabel
    }

    private static func megabytes(_ bytes: Int64) -> String {
        String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }
}

@MainActor
struct KokoroVoiceInstallPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UIState.self) private var ui

    @State private var status = KokoroVoiceGateStatus.status()
    @State private var selectedTier: KokoroModelDownloadService.Tier = .starter

    private var downloader: KokoroModelDownloadService { KokoroModelDownloadService.shared }

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    private var statusText: String {
        if EpistemosSpeechSynthesizer.isTextToSpeechAvailable() {
            return KokoroVoiceInstallPresentation.readyStatus
        }
        return EpistemosSpeechSynthesizer.textToSpeechStatusMessage()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: KokoroVoiceInstallPresentation.voiceSystemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ui.theme.resolved.accent.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(KokoroVoiceInstallPresentation.sheetTitle)
                        .font(.headline)
                    Text(KokoroVoiceInstallPresentation.sheetSubtitle)
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                }

                Spacer(minLength: 0)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "xmark",
                    role: .toolbarUtility,
                    chromePolicy: .bareUntilPressed,
                    helpText: "Close",
                    accessibilityLabel: "Close"
                ) {
                    dismiss()
                }
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(mutedTint)
                .fixedSize(horizontal: false, vertical: true)

            KokoroVoiceDownloadControls(
                selectedTier: $selectedTier,
                isDisabled: EpistemosSpeechSynthesizer.isTextToSpeechAvailable(),
                idleButtonTitle: installButtonTitle,
                idleButtonHelp: installButtonHelp,
                idleButtonAccessibilityLabel: installButtonHelp
            ) {
                downloader.startInstall(tier: selectedTier)
            }

            if EpistemosSpeechSynthesizer.isTextToSpeechAvailable() {
                ToolbarCapsuleButton(
                    title: "Done",
                    systemImage: "checkmark.circle",
                    role: .primaryAction,
                    chromePolicy: .alwaysSurface,
                    helpText: "Close Kokoro voice installer",
                    accessibilityLabel: "Close Kokoro voice installer"
                ) {
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 430)
        .onAppear {
            status = KokoroVoiceGateStatus.status()
            EpistemosSpeechSynthesizer.logTextToSpeechReadiness(context: "kokoro-install-prompt")
        }
        .onChange(of: downloader.phase) { _, newPhase in
            switch newPhase {
            case .installed, .idle, .failed:
                status = KokoroVoiceGateStatus.status()
            case .preparing, .downloading, .installing:
                break
            }
        }
    }

    private var installButtonTitle: String {
        status.state == .packageReady
            ? "Replace \(selectedTier.title) Voice"
            : KokoroVoiceInstallPresentation.installTitle(for: selectedTier)
    }

    private var installButtonHelp: String {
        status.state == .packageReady
            ? "Download and replace the installed Kokoro voice with the \(selectedTier.title.lowercased()) package. \(selectedTier.approximateSizeLabel)."
            : KokoroVoiceInstallPresentation.installHelp(for: selectedTier)
    }
}

@MainActor
struct KokoroVoiceProSettingsSection: View {
    @Environment(UIState.self) private var ui
    @State private var status = KokoroVoiceGateStatus.status()
    @State private var installMessage: String?
    @State private var isInstalling = false
    @State private var isRemoving = false
    @State private var selectedDownloadTier: KokoroModelDownloadService.Tier = .starter

    private var downloader: KokoroModelDownloadService { KokoroModelDownloadService.shared }

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

    private var downloadButtonTitle: String {
        if status.state == .packageReady {
            return "Download & Replace Voice"
        }
        return selectedDownloadTier == .highestQuality
            ? KokoroVoiceInstallPresentation.highestQualityInstallTitle
            : KokoroVoiceInstallPresentation.installTitle(for: selectedDownloadTier)
    }

    private var downloadButtonHelp: String {
        if status.state == .packageReady {
            return "Download and replace the installed Kokoro voice quality"
        }
        return KokoroVoiceInstallPresentation.installHelp(for: selectedDownloadTier)
    }

    var body: some View {
        let presentation = KokoroVoiceProSettingsModel.presentation(for: status)
        let badgeTint = badgeTint(for: presentation)

        Section("Kokoro Voice") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: KokoroVoiceInstallPresentation.voiceSystemImage)
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

            KokoroVoiceDownloadControls(
                selectedTier: $selectedDownloadTier,
                isDisabled: isBusy,
                idleButtonTitle: downloadButtonTitle,
                idleButtonHelp: downloadButtonHelp,
                idleButtonAccessibilityLabel: downloadButtonHelp
            ) {
                downloader.startInstall(tier: selectedDownloadTier)
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
                    helpText: "Refresh Kokoro voice status",
                    accessibilityLabel: "Refresh Kokoro voice status"
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
        .onAppear {
            EpistemosSpeechSynthesizer.logTextToSpeechReadiness(context: "voice-settings-kokoro-section")
        }
        .onChange(of: downloader.phase) { _, newPhase in
            if case .installed = newPhase {
                status = KokoroVoiceGateStatus.status()
                installMessage = installedPackageMessage(for: status)
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
