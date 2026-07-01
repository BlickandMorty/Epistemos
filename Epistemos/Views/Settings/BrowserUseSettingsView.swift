import SwiftUI

private struct BrowserUseSettingsInputChrome: ViewModifier {
    let theme: EpistemosTheme
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.caption)
            .foregroundStyle(theme.resolved.foreground.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: maxWidth)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(theme.resolved.card.color.opacity(theme.isDark ? 0.34 : 0.58))
            }
    }
}

struct BrowserUseSettingsView: View {
    @Environment(UIState.self) private var ui
    private let settingsStore = BrowserUseSettingsStore()
    private let secretStore = BrowserUseSecretStore()
    @State private var status = BrowserUseProGateStatus.status()
    @State private var manifestURL = BrowserUseProGateStatus.defaultManifestURL()
    @State private var manifest: BrowserUseVendorManifest?
    @State private var manifestReadError: String?
    @State private var settings = BrowserUseSettings.default
    @State private var persistedSettings = BrowserUseSettings.default
    @State private var settingsReadError: String?
    @State private var settingsSaveMessage: String?
    @State private var secretPresence: Set<BrowserUseSecretBinding> = []
    @State private var secretDrafts: [BrowserUseSecretBinding: String] = [:]
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }
    private var foregroundTint: Color { theme.resolved.foreground.color }
    private var mutedTint: Color { theme.resolved.mutedForeground.color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                gateCard
                sourceCard
                packagingCard
                settingsContractCard
                providerSettingsCard
                browserSettingsCard
                runtimeSettingsCard
                secretSettingsCard
                boundaryCard
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .task {
            refresh()
        }
    }

    private var headerCard: some View {
        SettingsSurfaceCard {
            HStack(alignment: .top, spacing: 14) {
                IntegrationBrandMarkView(brand: .browserUse, size: 32)
                    .foregroundStyle(mutedTint)

                VStack(alignment: .leading, spacing: 8) {
                    Text("browser-use Pro")
                        .font(.headline)
                    Text("Developer ID automation lane for the vendored browser-use Chromium robot. The App Store Browser tab stays a separate, human-driven WKWebView.")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ChannelStatusPill(title: "Pro only", tint: statusTint(.warning))
                        ChannelStatusPill(title: "Chromium/CDP", tint: statusTint(.muted))
                        ChannelStatusPill(title: "Separate browser", tint: statusTint(.info))
                    }
                }
                Spacer()
                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "arrow.clockwise",
                    role: .toolbarUtility,
                    helpText: "Refresh browser-use Pro status",
                    accessibilityLabel: "Refresh browser-use Pro status"
                ) {
                    refresh()
                }
            }
        }
    }

    private var gateCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Gate Status")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(
                        title: status.isActive ? "Ready" : "Inactive",
                        tint: status.isActive ? statusTint(.ready) : statusTint(.warning)
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(status.headline)
                        .font(.subheadline.weight(.semibold))
                    Text(status.detail)
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ChannelStatusPill(title: BrowserUseProGateStatus.flagName, tint: statusTint(.muted))
            }
        }
    }

    private var sourceCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Vendored Source")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(title: "Full clone required", tint: statusTint(.info))
                }

                if let manifest {
                    ForEach(manifest.components, id: \.name) { component in
                        HStack(alignment: .top, spacing: 12) {
                            IntegrationBrandMarkView(brand: .browserUse, size: 22)
                                .foregroundStyle(mutedTint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(component.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(component.repo) @ \(component.commit.prefix(12))")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(mutedTint)
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                                Text(sourceComponentPackageVersion(component))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(mutedTint)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            ChannelStatusPill(title: component.license, tint: statusTint(.muted))
                            ChannelStatusPill(
                                title: component.fullClone ? "full clone" : "partial",
                                tint: component.fullClone ? statusTint(.ready) : statusTint(.problem)
                            )
                            ChannelStatusPill(title: "\(component.fileCount) files", tint: statusTint(.info))
                        }
                        if component.name != manifest.components.last?.name {
                            rowGap
                        }
                    }
                } else {
                    statusMessage(
                        title: "Vendor manifest unavailable",
                        detail: manifestReadError ?? "No browser-use manifest was found in the app bundle or source tree.",
                        tint: statusTint(.warning)
                    )
                }
            }
        }
    }

    private var packagingCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Pro Payload Packaging")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(
                        title: manifest?.isProPayloadStaged == true ? "Staged" : "Not staged",
                        tint: manifest?.isProPayloadStaged == true ? statusTint(.ready) : statusTint(.warning)
                    )
                }

                if let manifest {
                    packagingPathListRow(
                        "agent-browser adapter",
                        artifact: manifest.packagingArtifacts.agentBrowserAdapter,
                        readyStatus: BrowserUseVendorManifest.PackagingArtifacts.agentBrowserAdapterReadyStatus
                    )
                    rowGap
                    packagingRow(
                        "build-pro-payload.sh",
                        artifact: manifest.packagingArtifacts.buildScript,
                        readyStatus: BrowserUseVendorManifest.PackagingArtifacts.buildScriptReadyStatus
                    )
                    rowGap
                    packagingRow(
                        "BUILD_MANIFEST.json",
                        artifact: manifest.packagingArtifacts.buildManifest,
                        readyStatus: BrowserUseVendorManifest.PackagingArtifacts.buildManifestReadyStatus
                    )
                    rowGap
                    packagingRow(
                        "requirements.lock",
                        artifact: manifest.packagingArtifacts.requirementsLock,
                        readyStatus: BrowserUseVendorManifest.PackagingArtifacts.requirementsLockReadyStatus
                    )
                    rowGap
                    packagingRow(
                        "wheels",
                        artifact: manifest.packagingArtifacts.wheelhouse,
                        readyStatus: BrowserUseVendorManifest.PackagingArtifacts.wheelhouseReadyStatus
                    )
                    rowGap
                    packagingRow(
                        "Playwright Chromium",
                        artifact: manifest.packagingArtifacts.playwrightChromium,
                        readyStatus: BrowserUseVendorManifest.PackagingArtifacts.playwrightChromiumReadyStatus
                    )
                } else {
                    statusMessage(
                        title: "Packaging state unknown",
                        detail: "The manifest must be readable before the Pro payload can be considered staged.",
                        tint: statusTint(.warning)
                    )
                }
            }
        }
    }

    private var settingsContractCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Settings Contract")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(title: "Env renderer", tint: statusTint(.info))
                    ChannelStatusPill(title: "Keychain secrets", tint: statusTint(.ready))
                }

                settingsFactRow(
                    "Default LLM",
                    value: settings.providers.defaultLLM,
                    detail: "Preserves the web-ui DEFAULT_LLM selector."
                )
                rowGap
                settingsFactRow(
                    "Privacy defaults",
                    value: "Telemetry off, cloud sync off, version checks off",
                    detail: "Epistemos writes the browser-use environment from explicit settings at Pro launch."
                )
                rowGap
                settingsFactRow(
                    "Browser profile",
                    value: "\(settings.browser.resolution), CDP \(settings.browser.debuggingHost):\(settings.browser.debuggingPort)",
                    detail: "Keeps browser path, user data, own-browser, CDP, and browser-use executable settings."
                )
                rowGap
                settingsFactRow(
                    "Secret bindings",
                    value: "\(secretPresence.count)/\(BrowserUseSecretBinding.allCases.count) Keychain environment keys stored",
                    detail: "Provider keys, cloud keys, proxy credentials, AWS credentials, and VNC password are not stored in manifests."
                )
                rowGap
                settingsFactRow(
                    "Non-secret settings",
                    value: "\(BrowserUseEnvironmentRenderer.dictionary(settings.nonSecretEnvironmentPairs).count) environment keys",
                    detail: "Saved as BrowserUsePro settings JSON and rendered with Keychain secrets into a launch-time .env."
                )

                if let settingsReadError {
                    rowGap
                    statusMessage(title: "Settings load failed", detail: settingsReadError, tint: statusTint(.warning))
                }

                if let settingsSaveMessage {
                    rowGap
                    statusMessage(title: "Settings", detail: settingsSaveMessage, tint: statusTint(.info))
                }

                HStack(spacing: 10) {
                    ToolbarCapsuleButton(
                        title: "Save Settings",
                        systemImage: "checkmark.circle",
                        role: .primaryAction,
                        chromePolicy: .alwaysSurface,
                        helpText: "Save browser-use Pro settings",
                        accessibilityLabel: "Save browser-use Pro settings"
                    ) {
                        saveSettings()
                    }

                    ToolbarCapsuleButton(
                        title: "Reload",
                        systemImage: "arrow.clockwise",
                        role: .toolbarUtility,
                        chromePolicy: .alwaysSurface,
                        helpText: "Reload browser-use Pro settings",
                        accessibilityLabel: "Reload browser-use Pro settings"
                    ) {
                        loadSettings()
                    }

                    ToolbarCapsuleButton(
                        title: "Reset",
                        systemImage: "arrow.counterclockwise",
                        role: .secondaryGhost,
                        chromePolicy: .bareUntilPressed,
                        helpText: "Reset browser-use Pro settings to defaults",
                        accessibilityLabel: "Reset browser-use Pro settings to defaults"
                    ) {
                        settings = .default
                        settingsSaveMessage = "Defaults staged. Save to write them."
                    }
                }
            }
        }
    }

    private var providerSettingsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Provider Settings", detail: "Non-secret browser-use provider endpoints and default model lane.")

                Picker("Default LLM", selection: binding(\.providers.defaultLLM)) {
                    ForEach(defaultLLMOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)

                settingTextField("OpenAI endpoint", text: binding(\.providers.openAIEndpoint))
                settingTextField("Anthropic endpoint", text: binding(\.providers.anthropicEndpoint))
                settingTextField("Google endpoint", text: binding(\.providers.googleEndpoint))
                settingTextField("Azure OpenAI endpoint", text: binding(\.providers.azureOpenAIEndpoint))
                settingTextField("Azure API version", text: binding(\.providers.azureOpenAIAPIVersion))
                settingTextField("DeepSeek endpoint", text: binding(\.providers.deepSeekEndpoint))
                settingTextField("Mistral endpoint", text: binding(\.providers.mistralEndpoint))
                settingTextField("Ollama endpoint", text: binding(\.providers.ollamaEndpoint))
                settingTextField("Alibaba endpoint", text: binding(\.providers.alibabaEndpoint))
                settingTextField("ModelScope endpoint", text: binding(\.providers.modelScopeEndpoint))
                settingTextField("Moonshot endpoint", text: binding(\.providers.moonshotEndpoint))
                settingTextField("Unbound endpoint", text: binding(\.providers.unboundEndpoint))
                settingTextField("SiliconFlow endpoint", text: binding(\.providers.siliconFlowEndpoint))
                settingTextField("IBM endpoint", text: binding(\.providers.ibmEndpoint))
                settingTextField("Grok endpoint", text: binding(\.providers.grokEndpoint))
                settingTextField("AWS region", text: binding(\.providers.awsRegion))
                settingTextField("AWS default region", text: binding(\.providers.awsDefaultRegion))
            }
        }
    }

    private var browserSettingsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Browser Settings", detail: "Chromium/CDP and profile controls passed to browser-use.")

                settingTextField("Browser path", text: binding(\.browser.browserPath))
                settingTextField("Browser user data", text: binding(\.browser.browserUserData))
                settingTextField("Debugging host", text: binding(\.browser.debuggingHost))
                Stepper("Debugging port: \(settings.browser.debuggingPort)", value: binding(\.browser.debuggingPort), in: 1...65535)
                Toggle("Keep browser open", isOn: binding(\.browser.keepBrowserOpen))
                Toggle("Use own browser", isOn: binding(\.browser.useOwnBrowser))
                settingTextField("Browser CDP URL", text: binding(\.browser.browserCDP))
                Stepper("Resolution width: \(settings.browser.resolutionWidth)", value: binding(\.browser.resolutionWidth), in: 320...7680, step: 10)
                Stepper("Resolution height: \(settings.browser.resolutionHeight)", value: binding(\.browser.resolutionHeight), in: 240...4320, step: 10)
                Stepper("Resolution depth: \(settings.browser.resolutionDepth)", value: binding(\.browser.resolutionDepth), in: 8...64)
                settingTextField("browser-use executable path", text: binding(\.browser.executablePath))
                Toggle("Headless", isOn: binding(\.browser.headless))
                settingTextField("browser-use user data dir", text: binding(\.browser.userDataDirectory))
            }
        }
    }

    private var runtimeSettingsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Runtime Settings", detail: "Logging, cloud endpoints, privacy flags, and proxy values.")

                Toggle("Anonymized telemetry", isOn: binding(\.runtime.anonymizedTelemetry))
                Picker("Logging level", selection: binding(\.runtime.loggingLevel)) {
                    ForEach(loggingLevelOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                settingTextField("Debug log file", text: binding(\.runtime.debugLogFile))
                settingTextField("Info log file", text: binding(\.runtime.infoLogFile))
                settingTextField("CDP logging level", text: binding(\.runtime.cdpLoggingLevel))
                settingTextField("Cloud API URL", text: binding(\.runtime.cloudAPIURL))
                settingTextField("Cloud UI URL", text: binding(\.runtime.cloudUIURL))
                settingTextField("Cloud base URL", text: binding(\.runtime.cloudBaseURL))
                Toggle("Cloud sync", isOn: binding(\.runtime.cloudSync))
                Toggle("Version check", isOn: binding(\.runtime.versionCheck))
                settingTextField("Proxy server", text: binding(\.runtime.proxyServer))
                settingTextField("No proxy", text: binding(\.runtime.noProxy))
            }
        }
    }

    private var secretSettingsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Keychain Secrets", detail: "Only non-empty drafts are written. Use Clear to remove an existing secret.")

                ForEach(BrowserUseSecretBinding.allCases, id: \.rawValue) { binding in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(secretDisplayName(binding))
                                .font(.subheadline.weight(.semibold))
                            Text(binding.environmentName)
                                .font(.caption.monospaced())
                                .foregroundStyle(mutedTint)
                        }
                        Spacer()
                        ChannelStatusPill(
                            title: secretPresence.contains(binding) ? "stored" : "not set",
                            tint: secretPresence.contains(binding) ? statusTint(.ready) : statusTint(.muted)
                        )
                        SecureField(
                            secretPresence.contains(binding) ? "Replace value" : "Add value",
                            text: secretDraftBinding(for: binding)
                        )
                        .modifier(BrowserUseSettingsInputChrome(theme: theme, maxWidth: 240))
                        ToolbarCapsuleButton(
                            title: nil,
                            systemImage: "trash",
                            role: .secondaryGhost,
                            helpText: "Clear \(binding.environmentName)",
                            accessibilityLabel: "Clear \(binding.environmentName)"
                        ) {
                            clearSecret(binding)
                        }
                        .disabled(!secretPresence.contains(binding) && secretDrafts[binding, default: ""].isEmpty)
                    }
                    if binding != BrowserUseSecretBinding.allCases.last {
                        rowGap
                    }
                }
            }
        }
    }

    private var boundaryCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Boundary")
                    .font(.headline)

                boundaryRow(
                    symbol: "safari",
                    title: "Native Browser tab",
                    detail: "Human-driven WKWebView for App Store builds. browser-use does not drive it."
                )
                boundaryRow(
                    symbol: "terminal",
                    title: "Pro runtime",
                    detail: "Python, Playwright, Chromium, and subprocess launch remain outside the MAS path."
                )
                boundaryRow(
                    symbol: "key",
                    title: "Secrets",
                    detail: "Provider keys, browser-use cloud keys, and proxy credentials belong in Keychain, not manifests or logs."
                )
            }
        }
    }

    @ViewBuilder
    private func packagingPathListRow(
        _ title: String,
        artifact: BrowserUseVendorManifest.PackagingPathListArtifact,
        readyStatus: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(artifact.expectedPaths.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(mutedTint)
                    .textSelection(.enabled)
                if let notes = artifact.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            ChannelStatusPill(
                title: artifact.status,
                tint: packagingStatusTint(artifact.status, readyStatus: readyStatus)
            )
        }
    }

    @ViewBuilder
    private func packagingRow(
        _ title: String,
        artifact: BrowserUseVendorManifest.PackagingArtifact,
        readyStatus: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(artifact.expectedPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(mutedTint)
                    .textSelection(.enabled)
                if let metadata = packagingArtifactMetadata(artifact) {
                    Text(metadata)
                        .font(.caption.monospaced())
                        .foregroundStyle(mutedTint)
                        .textSelection(.enabled)
                }
                if let notes = artifact.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            ChannelStatusPill(
                title: artifact.status,
                tint: packagingStatusTint(artifact.status, readyStatus: readyStatus)
            )
        }
    }

    private func boundaryRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18, height: 18)
                .foregroundStyle(mutedTint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsFactRow(_ title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .frame(width: 18, height: 18)
                .foregroundStyle(mutedTint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(foregroundTint)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rowGap: some View {
        Color.clear.frame(height: 4)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(mutedTint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingTextField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(title, text: text)
                .modifier(BrowserUseSettingsInputChrome(theme: theme, maxWidth: 520))
        }
    }

    private func statusMessage(title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(mutedTint)
            }
        }
    }

    private func refresh() {
        status = BrowserUseProGateStatus.status()
        manifestURL = BrowserUseProGateStatus.defaultManifestURL()
        guard let manifestURL else {
            manifest = nil
            manifestReadError = nil
            return
        }

        do {
            manifest = try BrowserUseVendorManifest.load(from: manifestURL)
            manifestReadError = nil
        } catch {
            manifest = nil
            manifestReadError = BrowserUseDiagnostics.statusMessage(for: error, fallback: "manifest read failed")
        }
        loadSettings()
    }

    private func statusTint(_ tone: BrowserUseStatusTone) -> Color {
        tone.color(in: theme)
    }

    private func packagingStatusTint(_ status: String, readyStatus: String) -> Color {
        status == readyStatus ? statusTint(.ready) : statusTint(.warning)
    }

    private func packagingArtifactMetadata(_ artifact: BrowserUseVendorManifest.PackagingArtifact) -> String? {
        var values: [String] = []
        if let fileCount = artifact.fileCount {
            values.append("file_count=\(fileCount)")
        }
        if let chromiumRevision = artifact.chromiumRevision {
            values.append("chromium_revision=\(chromiumRevision)")
        }
        if let headlessShellRevision = artifact.headlessShellRevision {
            values.append("headless_shell_revision=\(headlessShellRevision)")
        }
        if let ffmpegRevision = artifact.ffmpegRevision {
            values.append("ffmpeg_revision=\(ffmpegRevision)")
        }
        return values.isEmpty ? nil : values.joined(separator: "\n")
    }

    private func sourceComponentPackageVersion(_ component: BrowserUseVendorManifest.Component) -> String {
        if let packageVersion = component.packageVersion {
            return "package_version=\(packageVersion)"
        }
        return "package_version=null"
    }

    private func loadSettings() {
        do {
            let loadedSettings = try settingsStore.load()
            settings = loadedSettings
            persistedSettings = loadedSettings
            settingsReadError = nil
            settingsSaveMessage = nil
        } catch {
            settings = .default
            persistedSettings = .default
            settingsReadError = BrowserUseDiagnostics.statusMessage(for: error, fallback: "settings load failed")
        }

        secretPresence = Set(BrowserUseSecretBinding.allCases.filter { secretStore.load($0) != nil })
        secretDrafts = [:]
    }

    private func saveSettings() {
        if let problem = BrowserUseSettingsValidation.problem(in: settings) {
            settingsSaveMessage = BrowserUseDiagnostics.statusMessage(
                "Settings invalid: \(problem)",
                fallback: "settings invalid"
            )
            return
        }

        do {
            try settingsStore.save(settings)
            persistedSettings = settings
            var failedSecretNames: [String] = []
            var failedSecretDrafts: [BrowserUseSecretBinding: String] = [:]
            for (binding, value) in secretDrafts where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !secretStore.save(value, for: binding) {
                    failedSecretNames.append(binding.environmentName)
                    failedSecretDrafts[binding] = value
                }
            }
            secretPresence = Set(BrowserUseSecretBinding.allCases.filter { secretStore.load($0) != nil })
            secretDrafts = failedSecretDrafts
            let environmentMessage = renderEnvironmentFileMessage(using: settings)
            if failedSecretNames.isEmpty {
                settingsSaveMessage = joinedStatusMessages(
                    "Saved browser-use Pro settings.",
                    environmentMessage
                )
            } else {
                settingsSaveMessage = joinedStatusMessages(
                    "Saved settings, but Keychain rejected: \(failedSecretNames.joined(separator: ", "))",
                    environmentMessage
                )
            }
        } catch {
            settingsSaveMessage = BrowserUseDiagnostics.statusMessage(for: error, fallback: "settings save failed")
        }
    }

    private func clearSecret(_ binding: BrowserUseSecretBinding) {
        secretStore.delete(binding)
        secretDrafts[binding] = ""
        secretPresence.remove(binding)
        settingsSaveMessage = joinedStatusMessages(
            "Cleared \(binding.environmentName).",
            renderEnvironmentFileMessage(using: persistedSettings)
        )
    }

    private func renderEnvironmentFileMessage(using environmentSettings: BrowserUseSettings) -> String {
        guard let paths = BrowserUseRuntimePaths.defaultPaths() else {
            return "Runtime .env not rendered because the browser-use Pro payload is not installed."
        }

        do {
            try BrowserUseEnvironmentFileWriter.write(
                BrowserUseEnvironmentRenderer.render(settings: environmentSettings, secretStore: secretStore),
                to: paths.environmentFileURL
            )
            return "Runtime .env refreshed."
        } catch {
            return "Runtime .env refresh failed: \(BrowserUseDiagnostics.statusMessage(for: error, fallback: "environment write failed"))"
        }
    }

    private func joinedStatusMessages(_ values: String...) -> String {
        let joined = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return BrowserUseDiagnostics.statusMessage(joined, fallback: "browser-use settings status")
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<BrowserUseSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    private func secretDraftBinding(for binding: BrowserUseSecretBinding) -> Binding<String> {
        Binding(
            get: { secretDrafts[binding, default: ""] },
            set: { secretDrafts[binding] = $0 }
        )
    }

    private var defaultLLMOptions: [String] {
        [
            "openai",
            "anthropic",
            "google",
            "azure_openai",
            "deepseek",
            "mistral",
            "ollama",
            "alibaba",
            "modelscope",
            "moonshot",
            "unbound",
            "siliconflow",
            "ibm",
            "grok",
        ]
    }

    private var loggingLevelOptions: [String] {
        ["debug", "info", "warning", "error", "critical"]
    }

    private func secretDisplayName(_ binding: BrowserUseSecretBinding) -> String {
        binding.environmentName
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
