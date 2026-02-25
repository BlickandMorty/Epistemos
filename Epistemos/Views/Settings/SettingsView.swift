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
            case .inference:  "cpu"
            case .soar:       "brain"
            case .appearance: "paintpalette"
            case .vault:      "folder"
            case .security:   "lock.shield"
            case .export:     "square.and.arrow.up"
            case .reset:      "trash"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selection {
                case .inference:  InferenceDetailView()
                case .soar:       SOARDetailView()
                case .appearance: AppearanceDetailView()
                case .vault:      VaultDetailView()
                case .security:   SecurityDetailView()
                case .export:     ExportDetailView()
                case .reset:      ResetDetailView()
                case nil:         InferenceDetailView()
                }
            }
            .navigationTitle(selection?.rawValue ?? "Settings")
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
                    Label("Apple Intelligence active — simple queries run on-device automatically", systemImage: "cpu")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.success)
                }

                Picker("Provider", selection: Binding(
                    get: { inference.apiProvider },
                    set: { inference.setApiProvider($0) }
                )) {
                    Text("Anthropic").tag(LLMProviderType.anthropic)
                    Text("OpenAI").tag(LLMProviderType.openai)
                    Text("Google").tag(LLMProviderType.google)
                    Text("Kimi (Moonshot)").tag(LLMProviderType.kimi)
                    Text("Ollama (local)").tag(LLMProviderType.ollama)
                    HStack {
                        Text("Apple Intelligence")
                        if !inference.appleIntelligenceAvailable {
                            Text("· Unavailable")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                    }.tag(LLMProviderType.appleIntelligence)
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
                                .foregroundStyle(status == "Connected" || status == "Saved" ? theme.success : theme.error)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Section("Model") {
                switch inference.apiProvider {
                case .anthropic:
                    Picker("Model", selection: Binding(
                        get: { inference.anthropicModel },
                        set: { inference.setAnthropicModel($0) }
                    )) {
                        ForEach(InferenceState.anthropicModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .openai:
                    Picker("Model", selection: Binding(
                        get: { inference.openaiModel },
                        set: { inference.setOpenAIModel($0) }
                    )) {
                        ForEach(InferenceState.openaiModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .google:
                    Picker("Model", selection: Binding(
                        get: { inference.googleModel },
                        set: { inference.setGoogleModel($0) }
                    )) {
                        ForEach(InferenceState.googleModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .kimi:
                    Picker("Model", selection: Binding(
                        get: { inference.kimiModel },
                        set: { inference.setKimiModel($0) }
                    )) {
                        ForEach(InferenceState.kimiModels, id: \.id) { m in
                            Text(m.name).tag(m.id)
                        }
                    }
                case .ollama:
                    LabeledContent("Base URL") {
                        TextField("http://localhost:11434", text: Binding(
                            get: { inference.ollamaBaseUrl },
                            set: { inference.setOllamaBaseUrl($0) }
                        ))
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: 220)
                    }
                    if inference.ollamaModels.isEmpty {
                        Text("No models found — start Ollama and pull a model")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    } else {
                        Picker("Model", selection: Binding(
                            get: { inference.ollamaModel },
                            set: { inference.setOllamaModel($0) }
                        )) {
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
                    LabeledContent("Status") {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(inference.appleIntelligenceAvailable ? "Available" : "Unavailable")
                                .foregroundStyle(inference.appleIntelligenceAvailable ? theme.success : theme.error)
                                .fontWeight(.medium)
                            if !inference.appleIntelligenceAvailable,
                               let reason = inference.appleIntelligenceUnavailableReason {
                                Text(reason)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textTertiary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    if !inference.appleIntelligenceAvailable {
                        Button("Open System Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.siri")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
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
                Toggle("OOLONG Contradiction Detection", isOn: $soar.soarConfig.contradictionDetection)
                Toggle("Verbose Logging", isOn: $soar.soarConfig.verbose)
            }

            Section("Limits") {
                LabeledContent("Max Iterations") {
                    Stepper("\(soar.soarConfig.maxIterations)", value: $soar.soarConfig.maxIterations, in: 1...5)
                }
                LabeledContent("Stones per Curriculum") {
                    Stepper("\(soar.soarConfig.stonesPerCurriculum)", value: $soar.soarConfig.stonesPerCurriculum, in: 2...5)
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
    private var theme: EpistemosTheme { ui.theme }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ThemePair.allCases, id: \.self) { pair in
                        ThemePairCard(pair: pair, isActive: ui.activePair == pair) {
                            ui.setPair(pair)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            } header: {
                Text("Theme")
            } footer: {
                Text("Each theme has a light and dark side. macOS automatically switches between them when you toggle system appearance.")
                    .font(.caption)
            }

            Section {
                LabeledContent("Active pair") {
                    Text(ui.activePair.displayName)
                        .foregroundStyle(theme.accent)
                        .fontWeight(.medium)
                }
                LabeledContent("Current side") {
                    HStack(spacing: 4) {
                        Image(systemName: ui.isSystemDark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 10))
                        Text(ui.isSystemDark ? "Dark — \(theme.displayName)" : "Light — \(theme.displayName)")
                    }
                    .foregroundStyle(theme.mutedForeground)
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
            }

            Section {
                Picker("Breathe Reminder", selection: Binding(
                    get: { ui.breatheReminder },
                    set: { ui.breatheReminder = $0 }
                )) {
                    ForEach(BreatheReminder.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }

                LabeledContent("Cycles per Session") {
                    Stepper("\(ui.breatheCycles)", value: Binding(
                        get: { ui.breatheCycles },
                        set: { ui.breatheCycles = $0 }
                    ), in: 1...10)
                }

                Button("Start Breathe Session Now") {
                    NSApp.keyWindow?.close()
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.3))
                        ui.startBreathe()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } header: {
                Text("Wellness")
            } footer: {
                Text("4-7-8 breathing: 4s inhale, 7s hold, 8s exhale. Each cycle is 19 seconds.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
        case .classic: ("sun.max", "moon.stars")
        case .warmth:  ("sun.max.fill", "sunset.fill")
        case .ember:   ("leaf", "flame")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: pairIcons.0)
                        .font(.system(size: 14))
                        .foregroundStyle(isActive ? current.accent : current.mutedForeground.opacity(0.5))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(current.textTertiary.opacity(0.6))
                    Image(systemName: pairIcons.1)
                        .font(.system(size: 14))
                        .foregroundStyle(isActive ? current.accent : current.mutedForeground.opacity(0.5))
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
                            selectVaultFolder()
                        }
                        Button("Sync from Vault") {
                            Task {
                                _ = await vaultSync.syncFromVault()
                            }
                        }
                        Button("Disconnect", role: .destructive) {
                            disconnectVault()
                        }
                    }
                } else {
                    Text("No vault connected. Select a folder to sync your markdown notes.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    Button("Select Vault Folder") {
                        selectVaultFolder()
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

                    Text("The search index is kept in sync automatically. Use Rebuild if search results seem stale.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }

                Section("Vault Sync") {
                    Picker("Auto-save to vault", selection: Binding(
                        get: { autoSaveOption(from: vaultSync.autoSaveInterval) },
                        set: { vaultSync.autoSaveInterval = autoSaveSeconds(from: $0) }
                    )) {
                        Text("Off").tag(0)
                        Text("Every 15 seconds").tag(1)
                        Text("Every 30 seconds").tag(2)
                        Text("Every 60 seconds").tag(3)
                        Text("Every 5 minutes").tag(4)
                    }
                    .pickerStyle(.menu)

                    Text("When enabled, unsaved note changes are automatically written to vault .md files at the chosen interval. When off, use ⌘S or the Save button.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Epistemos vault"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: "epistemos.vaultBookmark")
        }

        notesUI.resetForVaultSwitch()
        vaultSync.startWatching(vaultURL: url)
    }

    private func disconnectVault() {
        notesUI.resetForVaultSwitch()
        vaultSync.stopWatching()
        UserDefaults.standard.removeObject(forKey: "epistemos.vaultBookmark")
    }

    private func autoSaveOption(from interval: TimeInterval) -> Int {
        switch interval {
        case 15: return 1
        case 30: return 2
        case 60: return 3
        case 300: return 4
        default: return 0
        }
    }

    private func autoSaveSeconds(from option: Int) -> TimeInterval {
        switch option {
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
                Text("Clear all saved data, conversations, API keys, and settings. Your vault files on disk will not be deleted.")
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
                // Close settings window, then perform reset
                UtilityWindowManager.shared.hide(.settings)
                AppBootstrap.shared?.resetAllData()
            }
        } message: {
            Text("This will delete all conversations, notes data, API keys, and preferences. Your vault files on disk are preserved. This cannot be undone.")
        }
    }
}
