import SwiftUI

// MARK: - Settings View
// Presented as a standalone macOS Settings window (LucidApp.swift registers the Settings scene).
// Layout mirrors macOS System Settings: NavigationSplitView sidebar → Form-based detail pane.

struct SettingsView: View {
    @Environment(UIState.self) private var ui
    @State private var selection: SettingsSection? = .inference

    enum SettingsSection: String, CaseIterable, Identifiable {
        case inference = "Inference"
        case soar = "SOAR"
        case appearance = "Appearance"
        case vault = "Vault"
        case security = "Security"
        case export = "Export"
        case reset = "Reset"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .inference: "cpu"
            case .soar: "brain"
            case .appearance: "paintpalette"
            case .vault: "folder"
            case .security: "lock.shield"
            case .export: "square.and.arrow.up"
            case .reset: "trash"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selection {
                case .inference: InferenceDetailView()
                case .soar: SOARDetailView()
                case .appearance: AppearanceDetailView()
                case .vault: VaultDetailView()
                case .security: SecurityDetailView()
                case .export: ExportDetailView()
                case .reset: ResetDetailView()
                case nil: InferenceDetailView()
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

// MARK: - Inference Detail

private struct InferenceDetailView: View {
    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(LLMService.self) private var llmService

    @State private var apiKeyDraft = ""
    @State private var apiKeyVisible = false
    @State private var connectionStatus: String? = nil
    @State private var isTesting = false
    /// Tracks whether the user has enabled a custom token cap.
    @State private var tokenCapEnabled = false
    /// Draft token value for the stepper (kept in sync with inference.chatOutputTokens).
    @State private var tokenCapDraft: Int = 2000

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section("Provider") {
                // Apple Intelligence status
                if inference.appleIntelligenceAvailable {
                    Label(
                        "Apple Intelligence active — simple queries run on-device automatically",
                        systemImage: "cpu"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(theme.success)
                }

                Picker(
                    "Provider",
                    selection: Binding(
                        get: { inference.apiProvider },
                        set: { inference.setApiProvider($0) }
                    )
                ) {
                    Text("Anthropic").tag(LLMProviderType.anthropic)
                    Text("OpenAI").tag(LLMProviderType.openai)
                    Text("Google").tag(LLMProviderType.google)
                    Text("Kimi (Moonshot)").tag(LLMProviderType.kimi)
                    Text("Ollama (local)").tag(LLMProviderType.ollama)
                }
                .pickerStyle(.radioGroup)
            }

            if inference.needsApiKey {
                Section("API Key") {
                    LabeledContent("Key") {
                        HStack(spacing: 8) {
                            if apiKeyVisible {
                                TextField(inference.activeKeyPlaceholder, text: $apiKeyDraft)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(maxWidth: 260)
                            } else {
                                SecureField(inference.activeKeyPlaceholder, text: $apiKeyDraft)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(maxWidth: 260)
                            }
                            Button(apiKeyVisible ? "Hide" : "Show") {
                                apiKeyVisible.toggle()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    HStack(spacing: Spacing.sm) {
                        Button("Save Key") {
                            inference.setApiKey(apiKeyDraft)
                            connectionStatus = "Saved"
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                        .disabled(apiKeyDraft == inference.apiKey)

                        Button("Test Connection") {
                            isTesting = true
                            connectionStatus = nil
                            Task {
                                let previousKey = inference.apiKey
                                if apiKeyDraft != previousKey {
                                    inference.setApiKey(apiKeyDraft)
                                }
                                let result = await llmService.testConnection()
                                isTesting = false
                                connectionStatus = result.success ? "Connected" : result.message
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(apiKeyDraft.isEmpty || isTesting)

                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let status = connectionStatus {
                            Text(status)
                                .font(.system(size: 11))
                                .foregroundStyle(
                                    status == "Connected" || status == "Saved"
                                        ? theme.success : theme.error
                                )
                                .lineLimit(1)
                        }
                    }
                }
            }

            Section("Model") {
                switch inference.apiProvider {
                case .anthropic:
                    Picker(
                        "Model",
                        selection: Binding(
                            get: { inference.anthropicModel },
                            set: { inference.setAnthropicModel($0) }
                        )
                    ) {
                        ForEach(InferenceState.anthropicModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .openai:
                    Picker(
                        "Model",
                        selection: Binding(
                            get: { inference.openaiModel },
                            set: { inference.setOpenAIModel($0) }
                        )
                    ) {
                        ForEach(InferenceState.openaiModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .google:
                    Picker(
                        "Model",
                        selection: Binding(
                            get: { inference.googleModel },
                            set: { inference.setGoogleModel($0) }
                        )
                    ) {
                        ForEach(InferenceState.googleModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .kimi:
                    Picker(
                        "Model",
                        selection: Binding(
                            get: { inference.kimiModel },
                            set: { inference.setKimiModel($0) }
                        )
                    ) {
                        ForEach(InferenceState.kimiModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .ollama:
                    LabeledContent("Base URL") {
                        TextField(
                            "http://localhost:11434",
                            text: Binding(
                                get: { inference.ollamaBaseUrl },
                                set: { inference.setOllamaBaseUrl($0) }
                            )
                        )
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: 220)
                    }
                    if inference.ollamaModels.isEmpty {
                        Text("No models found — start Ollama and pull a model")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    } else {
                        Picker(
                            "Model",
                            selection: Binding(
                                get: { inference.ollamaModel },
                                set: { inference.setOllamaModel($0) }
                            )
                        ) {
                            ForEach(inference.ollamaModels, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                    }
                    HStack {
                        Circle()
                            .fill(inference.ollamaAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(inference.ollamaAvailable ? "Connected" : "Not available")
                            .font(.system(size: 11))
                    }
                case .appleIntelligence:
                    // Apple Intelligence is the always-on triage layer, not a standalone provider.
                    // If somehow selected (stale UserDefaults), show status + redirect.
                    Text(
                        "Apple Intelligence runs automatically alongside your cloud provider. Select a cloud provider above."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                }
            }

            Section("Response Tokens") {
                LabeledContent("Cap") {
                    HStack(spacing: 10) {
                        Toggle("Limit output tokens", isOn: $tokenCapEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text(tokenCapEnabled ? "Custom: \(tokenCapDraft)" : "Unlimited")
                            .font(.system(size: 13))
                            .foregroundStyle(tokenCapEnabled ? .primary : .secondary)
                        if tokenCapEnabled {
                            Stepper(
                                "",
                                value: $tokenCapDraft,
                                in: 500...32000,
                                step: 500
                            )
                            .labelsHidden()
                        }
                    }
                }
                .onChange(of: tokenCapEnabled) { _, enabled in
                    inference.setChatOutputTokens(enabled ? tokenCapDraft : 0)
                }
                .onChange(of: tokenCapDraft) { _, value in
                    if tokenCapEnabled { inference.setChatOutputTokens(value) }
                }
                Text(
                    tokenCapEnabled
                        ? "Responses are capped at \(tokenCapDraft) tokens (~\(tokenCapDraft * 4 / 1000)k characters)."
                        : "Responses use the model's full output capacity (up to ~16k tokens). No artificial cap."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("API Cost Tracking") {
                let cost = CostTracker.shared

                LabeledContent("Today's Calls") {
                    Text("\(cost.todayUsage.callCount)")
                        .font(.system(size: 13, design: .monospaced))
                }
                LabeledContent("Input Tokens") {
                    Text(formatTokenCount(cost.todayUsage.inputTokens))
                        .font(.system(size: 13, design: .monospaced))
                }
                LabeledContent("Output Tokens") {
                    Text(formatTokenCount(cost.todayUsage.outputTokens))
                        .font(.system(size: 13, design: .monospaced))
                }
                LabeledContent("Est. Cost") {
                    Text("$\(String(format: "%.4f", cost.todayUsage.estimatedCostUSD))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(cost.budgetExceeded ? .red : .primary)
                }

                if !cost.providerBreakdown.isEmpty {
                    ForEach(
                        Array(
                            cost.providerBreakdown.keys.sorted(by: { $0.rawValue < $1.rawValue })),
                        id: \.self
                    ) { provider in
                        if let usage = cost.providerBreakdown[provider], usage.callCount > 0 {
                            LabeledContent(provider.rawValue.capitalized) {
                                Text(
                                    "\(usage.callCount) calls · $\(String(format: "%.4f", usage.estimatedCostUSD))"
                                )
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                LabeledContent("Daily Budget") {
                    HStack(spacing: 8) {
                        if cost.dailyBudgetUSD > 0 {
                            Text("$\(String(format: "%.2f", cost.dailyBudgetUSD))")
                                .font(.system(size: 13, design: .monospaced))
                        } else {
                            Text("Unlimited")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Stepper("", value: Bindable(cost).dailyBudgetUSD, in: 0...100, step: 0.50)
                            .labelsHidden()
                    }
                }

                HStack {
                    if cost.budgetExceeded {
                        Label(
                            "Budget exceeded — API calls paused",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Reset") { cost.resetToday() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            apiKeyDraft = inference.apiKey
            let saved = inference.chatOutputTokens
            tokenCapEnabled = saved > 0
            if saved > 0 { tokenCapDraft = saved }
        }
        .onChange(of: inference.apiProvider) {
            apiKeyDraft = inference.apiKey
            connectionStatus = nil
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - SOAR Detail

private struct SOARDetailView: View {
    @Environment(SOARState.self) private var soar

    var body: some View {
        @Bindable var soar = soar
        Form {
            Section {
                Toggle("SOAR Engine", isOn: $soar.soarConfig.enabled)
            } footer: {
                Text("Self-Organizing Adaptive Reasoning")
                    .font(.caption)
            }

            Section("Detection") {
                Toggle("Auto-detect Edge of Learnability", isOn: $soar.soarConfig.autoDetect)
                Toggle(
                    "OOLONG Contradiction Detection", isOn: $soar.soarConfig.contradictionDetection)
                Toggle("Verbose Logging", isOn: $soar.soarConfig.verbose)
            }

            Section("Limits") {
                LabeledContent("Max Iterations") {
                    Stepper(
                        "\(soar.soarConfig.maxIterations)", value: $soar.soarConfig.maxIterations,
                        in: 1...5)
                }
                LabeledContent("Stones per Curriculum") {
                    Stepper(
                        "\(soar.soarConfig.stonesPerCurriculum)",
                        value: $soar.soarConfig.stonesPerCurriculum, in: 2...5)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Appearance Detail

private struct AppearanceDetailView: View {
    @Environment(UIState.self) private var ui
    @State private var customThemesEnabledDraft = false
    @State private var selectedPairDraft: ThemePair = .classic
    @State private var pendingThemeMode: ThemeMode?
    @State private var pendingThemePair: ThemePair?
    @State private var showThemeRestartAlert = false
    @State private var regularModeDraft = false
    @State private var pendingDisplayMode: AppDisplayMode?
    @State private var showDisplayModeAlert = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        AppearanceDetailContainer(
            customThemesEnabledDraft: $customThemesEnabledDraft,
            selectedPairDraft: $selectedPairDraft,
            regularModeDraft: $regularModeDraft,
            showThemeRestartAlert: $showThemeRestartAlert,
            showDisplayModeAlert: $showDisplayModeAlert,
            ui: ui,
            theme: theme,
            onToggleCustomThemes: scheduleThemeModeChange,
            onSelectThemePair: scheduleThemePairChange,
            onSelectDisplayMode: scheduleDisplayModeChange,
            onCancelThemeRestart: resetThemeDrafts,
            onApplyThemeRestart: applyPendingThemeChange,
            onCancelDisplayRestart: resetDisplayModeDraft,
            onApplyDisplayRestart: applyPendingDisplayModeChange
        )
    }

    private func scheduleThemeModeChange(_ enabled: Bool) {
        pendingThemeMode = enabled ? .custom : .systemDefault
        pendingThemePair = selectedPairDraft
        showThemeRestartAlert = true
    }

    private func scheduleThemePairChange(_ pair: ThemePair) {
        guard selectedPairDraft != pair else { return }
        selectedPairDraft = pair
        pendingThemeMode = customThemesEnabledDraft ? .custom : .systemDefault
        pendingThemePair = pair
        showThemeRestartAlert = true
    }

    private func scheduleDisplayModeChange(_ nextMode: AppDisplayMode) {
        pendingDisplayMode = nextMode
        showDisplayModeAlert = true
    }

    private func resetThemeDrafts() {
        customThemesEnabledDraft = ui.customThemesEnabled
        selectedPairDraft = ui.activePair
        pendingThemeMode = nil
        pendingThemePair = nil
    }

    private func resetDisplayModeDraft() {
        regularModeDraft = ui.displayMode == .regular
        pendingDisplayMode = nil
    }

    private func applyPendingThemeChange() {
        let nextMode = pendingThemeMode ?? (customThemesEnabledDraft ? .custom : .systemDefault)
        let nextPair = pendingThemePair ?? selectedPairDraft
        if let bootstrap = AppBootstrap.shared {
            bootstrap.applyThemePreferencesAndRelaunch(mode: nextMode, pair: nextPair)
        } else {
            ui.setPair(nextPair)
            ui.setThemeMode(nextMode)
        }
        pendingThemeMode = nil
        pendingThemePair = nil
    }

    private func applyPendingDisplayModeChange() {
        if let pendingDisplayMode {
            AppBootstrap.shared?.applyDisplayModeAndRelaunch(pendingDisplayMode)
        }
        pendingDisplayMode = nil
    }
}

private struct AppearanceDetailContainer: View {
    @Binding var customThemesEnabledDraft: Bool
    @Binding var selectedPairDraft: ThemePair
    @Binding var regularModeDraft: Bool
    @Binding var showThemeRestartAlert: Bool
    @Binding var showDisplayModeAlert: Bool
    let ui: UIState
    let theme: EpistemosTheme
    let onToggleCustomThemes: (Bool) -> Void
    let onSelectThemePair: (ThemePair) -> Void
    let onSelectDisplayMode: (AppDisplayMode) -> Void
    let onCancelThemeRestart: () -> Void
    let onApplyThemeRestart: () -> Void
    let onCancelDisplayRestart: () -> Void
    let onApplyDisplayRestart: () -> Void

    var body: some View {
        configuredForm
    }

    private var configuredForm: AnyView {
        let base = AnyView(
            appearanceForm
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .onAppear {
                customThemesEnabledDraft = ui.customThemesEnabled
                selectedPairDraft = ui.activePair
                regularModeDraft = ui.displayMode == .regular
            }
            .onChange(of: ui.themeMode) { _, mode in
                customThemesEnabledDraft = mode == .custom
            }
            .onChange(of: ui.activePair) { _, pair in
                selectedPairDraft = pair
            }
            .onChange(of: ui.displayMode) { _, mode in
                regularModeDraft = mode == .regular
            }
        )
        let themeAlerted = AnyView(
            base.alert("Restart to Apply Theme Change?", isPresented: $showThemeRestartAlert) {
                Button("Cancel", role: .cancel, action: onCancelThemeRestart)
                Button("Restart Now", action: onApplyThemeRestart)
            } message: {
                Text(
                    "Epistemos will relaunch to clear theme-era chrome workarounds and rebuild material caches safely."
                )
            }
        )
        return AnyView(
            themeAlerted.alert("Restart to Apply Display Mode?", isPresented: $showDisplayModeAlert) {
                Button("Cancel", role: .cancel, action: onCancelDisplayRestart)
                Button("Restart Now", action: onApplyDisplayRestart)
            } message: {
                Text(
                    "Epistemos will relaunch to rebuild style caches and reload fonts safely. Your vault and saved data stay intact."
                )
            }
        )
    }

    private var appearanceForm: some View {
        Form {
            AppearanceSystemSection(
                theme: theme
            )
            AppearanceDisplayModeSection(
                regularModeDraft: $regularModeDraft,
                currentMode: ui.displayMode,
                onToggle: onSelectDisplayMode
            )
        }
    }
}

private struct AppearanceThemeModeSection: View {
    @Binding var customThemesEnabledDraft: Bool
    let isCustomThemesEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Section {
            Toggle("Enable Custom Themes", isOn: $customThemesEnabledDraft)
                .toggleStyle(.switch)
                .onChange(of: customThemesEnabledDraft) { _, enabled in
                    guard enabled != isCustomThemesEnabled else { return }
                    onToggle(enabled)
                }

            Text("Default appearance uses native Apple materials, translucency, and system chrome.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Themes")
        }
    }
}

private struct AppearanceThemePairSection: View {
    let selectedPairDraft: ThemePair
    let customThemesEnabledDraft: Bool
    let onSelect: (ThemePair) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(ThemePair.allCases, id: \.self) { pair in
                    ThemePairCard(
                        pair: pair,
                        isActive: customThemesEnabledDraft && selectedPairDraft == pair
                    ) {
                        onSelect(pair)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
            .disabled(!customThemesEnabledDraft)
            .opacity(customThemesEnabledDraft ? 1 : 0.45)
        } header: {
            Text("Custom Theme Pair")
        } footer: {
            Text(themeFooterText)
                .font(.caption)
        }
    }

    private var themeFooterText: String {
        customThemesEnabledDraft
            ? "Each custom theme includes a light and dark side. Restart applies the pair cleanly and clears cached chrome."
            : "Custom themes are optional. Leave them off to keep the native system appearance."
    }
}

private struct AppearanceSystemSection: View {
    let theme: EpistemosTheme

    var body: some View {
        Section {
            LabeledContent("Appearance") {
                Text("Follows macOS")
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            LabeledContent("Custom themes") {
                Text("Removed")
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            Button("Open System Settings → Appearance") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.general")!
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } header: {
            Text("System")
        } footer: {
            Text("Epistemos now uses native system appearance everywhere. Theme switching has been removed to reduce chrome complexity and regressions.")
                .font(.caption)
        }
    }
}

private struct AppearanceDisplayModeSection: View {
    @Binding var regularModeDraft: Bool
    let currentMode: AppDisplayMode
    let onToggle: (AppDisplayMode) -> Void

    var body: some View {
        Section {
            Toggle("Regular Mode", isOn: $regularModeDraft)
                .toggleStyle(.switch)
                .onChange(of: regularModeDraft) { _, enabled in
                    let nextMode: AppDisplayMode = enabled ? .regular : .opulent
                    guard nextMode != currentMode else { return }
                    onToggle(nextMode)
                }

            Text(
                "Uses standard system fonts for display text, simplifies the landing greeting, and reduces non-ripple ASCII animation. Restart required."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text("Display Mode")
        }
    }
}

// MARK: - Theme Pair Card

private struct ThemePairCard: View {
    let pair: ThemePair
    let isActive: Bool
    let action: () -> Void

    @Environment(UIState.self) private var ui
    private var current: EpistemosTheme { ui.theme }

    private var pairIcons: (String, String) {
        switch pair {
        case .magnolia: ("camera.macro", "moon.stars.fill")
        case .classic: ("sun.max", "moon.stars")
        case .warmth: ("sun.max.fill", "sunset.fill")
        case .ember: ("leaf", "flame")
        case .platinum: ("square.grid.2x2", "square.grid.2x2")
        case .platinumViolet: ("square.grid.2x2", "sparkles")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: pairIcons.0)
                        .font(.system(size: 14))
                        .foregroundStyle(
                            isActive ? current.accent : current.mutedForeground.opacity(0.5))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(current.textTertiary.opacity(0.6))
                    Image(systemName: pairIcons.1)
                        .font(.system(size: 14))
                        .foregroundStyle(
                            isActive ? current.accent : current.mutedForeground.opacity(0.5))
                }

                Text(pair.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? current.foreground : current.textSecondary)

                Text(pair.description)
                    .font(.system(size: 10))
                    .foregroundStyle(current.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isActive ? current.accent.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isActive ? current.accent.opacity(0.35) : current.border,
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vault Detail

private struct VaultDetailView: View {
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section("Connection") {
                if let url = vaultSync.vaultURL {
                    LabeledContent("Path") {
                        Text(url.path)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vaultSync.isWatching ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(vaultSync.isWatching ? "Connected" : "Disconnected")
                                .font(.system(size: 12))
                        }
                    }
                    HStack(spacing: Spacing.md) {
                        Button("Change Vault") {
                            VaultConnectionActions.selectVaultFolder(
                                notesUI: notesUI,
                                vaultSync: vaultSync
                            )
                        }
                        Button("Sync from Vault") {
                            Task {
                                _ = await vaultSync.syncFromVault()
                            }
                        }
                        Button("Disconnect", role: .destructive) {
                            VaultConnectionActions.disconnect(
                                notesUI: notesUI,
                                vaultSync: vaultSync
                            )
                        }
                    }
                } else {
                    Text("No vault connected. Select a folder to sync your markdown notes.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    Button("Select Vault Folder") {
                        VaultConnectionActions.selectVaultFolder(
                            notesUI: notesUI,
                            vaultSync: vaultSync
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }
            }

            if vaultSync.vaultURL != nil {
                Section("Search Index") {
                    HStack(spacing: 8) {
                        Button("Rebuild Index") {
                            vaultSync.rebuildIndex()
                        }
                        .disabled(vaultSync.isIndexing)

                        if vaultSync.isIndexing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Rebuilding…")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    Text(
                        "The search index is kept in sync automatically. Use Rebuild if search results seem stale."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                }

                Section("Vault Sync") {
                    Picker(
                        "Auto-save to vault",
                        selection: Binding(
                            get: { autoSaveOption(from: vaultSync.autoSaveInterval) },
                            set: { vaultSync.autoSaveInterval = autoSaveSeconds(from: $0) }
                        )
                    ) {
                        Text("Off").tag(0)
                        Text("Every 5 seconds").tag(5)
                        Text("Every 15 seconds").tag(1)
                        Text("Every 30 seconds").tag(2)
                        Text("Every 60 seconds").tag(3)
                        Text("Every 5 minutes").tag(4)
                    }
                    .pickerStyle(.menu)

                    Text(
                        "When enabled, unsaved note changes are automatically written to vault .md files at the chosen interval. When off, use ⌘S or the Save button."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func autoSaveOption(from interval: TimeInterval) -> Int {
        switch interval {
        case 5: return 5
        case 15: return 1
        case 30: return 2
        case 60: return 3
        case 300: return 4
        default: return 0
        }
    }

    private func autoSaveSeconds(from option: Int) -> TimeInterval {
        switch option {
        case 5: return 5
        case 1: return 15
        case 2: return 30
        case 3: return 60
        case 4: return 300
        default: return 0
        }
    }
}

// MARK: - Security Detail

private struct SecurityDetailView: View {
    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section("Data Protection") {
                LabeledContent("API keys") {
                    Text("Stored in macOS Keychain")
                        .foregroundStyle(theme.success)
                        .font(.system(size: 12))
                }
                LabeledContent("Keychain access") {
                    Text("Available after first unlock")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground)
                }
                LabeledContent("Sandbox") {
                    Text("Enabled")
                        .foregroundStyle(theme.success)
                        .font(.system(size: 12))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Export Detail

private struct ExportDetailView: View {
    @Environment(UIState.self) private var ui
    @State private var selectedFormat = "JSON"
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section("Data") {
                LabeledContent("Signals", value: "0")
                LabeledContent("Papers", value: "0")
                LabeledContent("Messages", value: "0")
                LabeledContent("Snapshots", value: "0")
            }

            Section("Format") {
                Picker("Format", selection: $selectedFormat) {
                    Text("JSON").tag("JSON")
                    Text("CSV").tag("CSV")
                    Text("Markdown").tag("Markdown")
                    Text("BibTeX").tag("BibTeX")
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Button("Export All Data") {}
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Reset Detail

private struct ResetDetailView: View {
    @Environment(UIState.self) private var ui
    @State private var showAlert = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section {
                Text(
                    "Clear all saved data, conversations, API keys, and settings. Your vault files on disk will not be deleted."
                )
                .foregroundStyle(.secondary)

                Button("Reset Everything", role: .destructive) {
                    showAlert = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("Reset Everything?", isPresented: $showAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                AppBootstrap.shared?.resetAllData()
            }
        } message: {
            Text(
                "This will delete all conversations, notes data, API keys, and preferences. Your vault files on disk are preserved. This cannot be undone."
            )
        }
    }
}
