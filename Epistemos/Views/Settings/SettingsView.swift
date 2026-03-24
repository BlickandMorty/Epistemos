import AppKit
import SwiftUI

// MARK: - Settings View
// Mirrors macOS System Settings: NavigationSplitView sidebar → Form-based detail pane.
// Fixed width (680pt), only height is resizable. Sidebar sits in the toolbar area.

struct SettingsView: View {
    @Environment(UIState.self) private var ui
    @State private var selection: SettingsSection? = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case inference = "Inference"
        case knowledgeFusion = "Knowledge Fusion"
        case landing = "Landing"
        case appearance = "Appearance"
        case vault = "Vault"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .inference: "cpu"
            case .knowledgeFusion: "brain.head.profile.fill"
            case .landing: "sparkles.rectangle.stack"
            case .appearance: "paintpalette"
            case .vault: "folder"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 180)
        } detail: {
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        switch selection {
        case .general: GeneralDetailView()
        case .inference: InferenceDetailView()
        case .knowledgeFusion: KnowledgeFusionDetailView()
        case .landing: LandingDetailView()
        case .appearance: AppearanceDetailView()
        case .vault: VaultDetailView()
        case nil: GeneralDetailView()
        }
    }
}

// MARK: - General Detail
// Consolidated: Session + Workspace Summaries + Security info + Reset

private struct GeneralDetailView: View {
    @Environment(UIState.self) private var ui
    @State private var restoreLastSession = UserDefaults.standard.bool(
        forKey: "epistemos.restoreLastSession"
    )
    @State private var showSaveOnQuit: Bool = {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "epistemos.showSaveOnQuitDialog") == nil
            ? true : defaults.bool(forKey: "epistemos.showSaveOnQuitDialog")
    }()
    @State private var summaryInterval: WorkspaceSummaryService.SummaryInterval = {
        let raw = UserDefaults.standard.string(forKey: "epistemos.summaryInterval") ?? "15m"
        return WorkspaceSummaryService.SummaryInterval(rawValue: raw) ?? .fifteenMinutes
    }()
    @State private var workspaces: [SDWorkspace] = []
    @State private var renamingWorkspace: SDWorkspace?
    @State private var renameText = ""
    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section("Session") {
                Toggle("Restore last session on launch", isOn: $restoreLastSession)
                    .onChange(of: restoreLastSession) { _, newValue in
                        AppBootstrap.shared?.workspaceService.restoreLastSession = newValue
                    }
                Toggle("Show save dialog on quit", isOn: $showSaveOnQuit)
                    .onChange(of: showSaveOnQuit) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "epistemos.showSaveOnQuitDialog")
                    }
            }

            Section("Workspace Summaries") {
                Picker("Auto-summarize interval", selection: $summaryInterval) {
                    ForEach(WorkspaceSummaryService.SummaryInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: summaryInterval) { _, newValue in
                    AppBootstrap.shared?.workspaceSummaryService.summaryInterval = newValue
                }
                Text("AI-generated summaries describe what you're working on. Runs entirely on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Saved Workspaces") {
                if workspaces.isEmpty {
                    Text("No saved workspaces yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workspaces, id: \.id) { workspace in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workspace.name)
                                    .font(.body)
                                Text(workspace.updatedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Load") {
                                AppBootstrap.shared?.workspaceService.loadWorkspace(workspace)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Rename") {
                                renameText = workspace.name
                                renamingWorkspace = workspace
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            Button(role: .destructive) {
                                AppBootstrap.shared?.workspaceService.deleteWorkspace(workspace)
                                refreshWorkspaces()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("Data Protection") {
                LabeledContent("Local models") {
                    Text("Stored in Application Support")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                LabeledContent("Apple Intelligence") {
                    Text("On-device only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Sandbox") {
                    Text("Enabled")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section("Reset") {
                Text("Clear all saved data, conversations, local model state, and settings. Vault files on disk are preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Everything", role: .destructive) {
                    showResetAlert = true
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshWorkspaces() }
        .alert("Rename Workspace", isPresented: Binding(
            get: { renamingWorkspace != nil },
            set: { if !$0 { renamingWorkspace = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let ws = renamingWorkspace {
                    AppBootstrap.shared?.workspaceService.renameWorkspace(ws, to: renameText)
                    refreshWorkspaces()
                }
                renamingWorkspace = nil
            }
            Button("Cancel", role: .cancel) { renamingWorkspace = nil }
        }
        .alert("Reset Everything?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                AppBootstrap.shared?.resetAllData()
            }
        } message: {
            Text("This will delete all conversations, notes data, local model state, and preferences. Vault files on disk are preserved. This cannot be undone.")
        }
    }

    private func refreshWorkspaces() {
        workspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
    }
}

// MARK: - Landing Detail

private struct LandingDetailView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui

        Form {
            Section("Greeting Behavior") {
                Toggle("Animate typewriter", isOn: $ui.landingGreetingTypewriterEnabled)

                Picker("Greeting Sources", selection: $ui.landingGreetingSourceMode) {
                    ForEach(LandingGreetingSourceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(ui.landingGreetingSourceMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Greeting Library") {
                if ui.landingCustomGreetings.isEmpty {
                    ContentUnavailableView(
                        "No Custom Greetings",
                        systemImage: "text.badge.plus",
                        description: Text("Add your own greetings and timing.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(ui.landingCustomGreetings) { greeting in
                        LandingGreetingEditorRow(
                            greeting: greeting,
                            isFirst: ui.landingCustomGreetings.first?.id == greeting.id,
                            isLast: ui.landingCustomGreetings.last?.id == greeting.id
                        )
                    }
                }

                Button {
                    ui.addLandingGreeting()
                } label: {
                    Label("Add Greeting", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct LandingGreetingEditorRow: View {
    @Environment(UIState.self) private var ui

    let greeting: LandingGreetingEntry
    let isFirst: Bool
    let isLast: Bool

    private var durationRange: ClosedRange<Double> {
        LandingGreetingEntry.minimumDurationSeconds...LandingGreetingEntry.maximumDurationSeconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { greeting.isEnabled },
                        set: { ui.updateLandingGreetingEnabled(id: greeting.id, isEnabled: $0) }
                    )
                )
                .labelsHidden()

                TextField(
                    "Greeting text",
                    text: Binding(
                        get: { greeting.text },
                        set: { ui.updateLandingGreetingText(id: greeting.id, text: $0) }
                    )
                )

                Button(action: { ui.moveLandingGreeting(id: greeting.id, by: -1) }) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)

                Button(action: { ui.moveLandingGreeting(id: greeting.id, by: 1) }) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(isLast)

                Button(role: .destructive, action: { ui.removeLandingGreeting(id: greeting.id) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Text("Duration")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(
                    "",
                    value: Binding(
                        get: { greeting.durationSeconds },
                        set: { ui.updateLandingGreetingDuration(id: greeting.id, durationSeconds: $0) }
                    ),
                    format: .number.precision(.fractionLength(1))
                )
                .frame(width: 54)

                Text("s")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Stepper(
                    "",
                    value: Binding(
                        get: { greeting.durationSeconds },
                        set: { ui.updateLandingGreetingDuration(id: greeting.id, durationSeconds: $0) }
                    ),
                    in: durationRange,
                    step: 0.2
                )
                .labelsHidden()

                Spacer()

                Text(greeting.isEnabled ? "Enabled" : "Disabled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(greeting.isEnabled ? .secondary : .tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Inference Detail

private struct InferenceDetailView: View {
    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(LocalModelManager.self) private var localModelManager

    @State private var showLocalModelManager = false
    @State private var tokenCapEnabled = false
    @State private var tokenCapDraft: Int = 2000
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var googleKey = ""

    private var theme: EpistemosTheme { ui.theme }
    private var activeLocalModelDisplayName: String {
        return inference.activeLocalTextModelDisplayName
    }

    var body: some View {
        Form {
            Section("Routing") {
                Picker(
                    "Routing Mode",
                    selection: Binding(
                        get: { inference.routingMode },
                        set: { inference.setRoutingMode($0) }
                    )
                ) {
                    ForEach(LocalRoutingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(inference.routingMode.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if inference.appleIntelligenceAvailable {
                    Label(
                        "Apple Intelligence available for lightweight on-device work",
                        systemImage: "apple.intelligence"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.success)
                } else if let reason = inference.appleIntelligenceUnavailableReason, !reason.isEmpty {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.warning)
                }
            }

            Section("Local AI") {
                LabeledContent("Hardware") {
                    Text(localModelManager.hardwareSummary)
                        .font(.system(size: 12, design: .monospaced))
                }
                LabeledContent("Installed") {
                    Text(inference.localModelInstallStateSummary.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                LabeledContent("Active Tier") {
                    Text(activeLocalModelDisplayName)
                        .font(.system(size: 12, weight: .medium))
                }
                LabeledContent("Storage") {
                    Text(ByteCountFormatter.string(fromByteCount: localModelManager.totalInstalledStorageBytes, countStyle: .file))
                        .font(.system(size: 12, design: .monospaced))
                }

                Picker(
                    "Active Local Model",
                    selection: Binding(
                        get: { inference.preferredLocalTextModelID },
                        set: { inference.setPreferredLocalTextModelID($0) }
                    )
                ) {
                    ForEach(
                        localModelManager.textDescriptors.filter {
                            localModelManager.installRecords[$0.id] != nil
                                || inference.hardwareCapabilitySnapshot.supports(descriptor: $0)
                        },
                        id: \.id
                    ) { descriptor in
                        Text(descriptor.displayName).tag(descriptor.id)
                    }
                }

                if let fallback = localModelManager.missingConstrainedFallbackDescriptor {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Install \(fallback.displayName) as a lighter fallback for constrained conditions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Install Constrained Fallback") {
                            Task { try? await localModelManager.install(modelID: fallback.id) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Button("Manage Local Models") {
                    showLocalModelManager = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.small)
            }

            Section("Cloud AI") {
                cloudKeyRow(title: "OpenAI", text: $openAIKey, provider: .openAI)
                cloudKeyRow(title: "Anthropic", text: $anthropicKey, provider: .anthropic)
                cloudKeyRow(title: "Google", text: $googleKey, provider: .google)

                Text("API keys are stored in the Apple Data Protection Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Response Tokens") {
                LabeledContent("Cap") {
                    HStack(spacing: 8) {
                        Toggle("", isOn: $tokenCapEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                        Text(tokenCapEnabled ? "\(tokenCapDraft)" : "Unlimited")
                            .font(.system(size: 12))
                            .foregroundStyle(tokenCapEnabled ? .primary : .secondary)
                        if tokenCapEnabled {
                            Stepper("", value: $tokenCapDraft, in: 500...32000, step: 500)
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
            }
        }
        .formStyle(.grouped)
        .onAppear {
            Task { @MainActor in
                let saved = inference.chatOutputTokens
                tokenCapEnabled = saved > 0
                if saved > 0 { tokenCapDraft = saved }
                openAIKey = inference.apiKey(for: .openAI) ?? ""
                anthropicKey = inference.apiKey(for: .anthropic) ?? ""
                googleKey = inference.apiKey(for: .google) ?? ""
            }
        }
        .sheet(isPresented: $showLocalModelManager) {
            LocalModelManagerSheet()
                .frame(minWidth: 620, minHeight: 480)
        }
    }

    @ViewBuilder
    private func cloudKeyRow(
        title: String,
        text: Binding<String>,
        provider: CloudModelProvider
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                SecureField("Not Set", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)
                Button("Save") {
                    _ = inference.setAPIKey(text.wrappedValue, for: provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Clear") {
                    text.wrappedValue = ""
                    _ = inference.setAPIKey("", for: provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

private struct LocalModelManagerSheet: View {
    @Environment(LocalModelManager.self) private var localModelManager
    @Environment(InferenceState.self) private var inference
    @Environment(UIState.self) private var ui

    var body: some View {
        NavigationStack {
            Form {
                if let error = localModelManager.lastErrorMessage, !error.isEmpty {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(ui.theme.warning)
                    }
                }

                Section("Text Models") {
                    ForEach(localModelManager.textDescriptors, id: \.id) { descriptor in
                        LocalModelRow(descriptor: descriptor)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Local Models")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Refresh") {
                        localModelManager.refreshFromDisk()
                    }
                }
            }
        }
    }
}

private struct LocalModelRow: View {
    @Environment(LocalModelManager.self) private var localModelManager
    @Environment(InferenceState.self) private var inference

    let descriptor: LocalModelDescriptor

    private var state: LocalModelPresentationState {
        localModelManager.presentationState(for: descriptor)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(descriptor.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    if descriptor.id == localModelManager.recommendedTextModelID {
                        Text("Recommended")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if descriptor.id == localModelManager.constrainedFallbackTextModelID {
                        Text("Fallback")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(state.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(descriptor.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(descriptor.familyName)
                    Text(descriptor.approximateDownloadLabel)
                    Text("Min \(descriptor.minimumRecommendedMemoryGB) GB")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

                if case .installing(let progress) = state {
                    ProgressView(value: progress)
                        .controlSize(.small)
                        .frame(maxWidth: 200)
                } else if case .blocked(let reason) = state {
                    Text(blockedGuidance(for: reason))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            switch state {
            case .installed:
                Button("Delete") {
                    try? localModelManager.uninstall(modelID: descriptor.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            case .installing:
                ProgressView()
                    .controlSize(.small)
            case .blocked:
                blockedAction
            case .available:
                Button("Install") {
                    Task { try? await localModelManager.install(modelID: descriptor.id) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var blockedAction: some View {
        if localModelManager.installErrors[descriptor.id] != nil {
            Button("Retry") {
                Task { try? await localModelManager.install(modelID: descriptor.id) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if !inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) {
            Label("Unsupported", systemImage: "memorychip.slash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func blockedGuidance(for reason: String) -> String {
        if localModelManager.installErrors[descriptor.id] != nil {
            return reason
        }
        if !inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) {
            return "This Mac does not have enough unified memory for this model."
        }
        return reason
    }
}

// MARK: - Appearance Detail

private struct AppearanceDetailView: View {
    @Environment(UIState.self) private var ui
    @State private var regularModeDraft = false
    @State private var pendingDisplayMode: AppDisplayMode?
    @State private var showDisplayModeAlert = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        AppearanceDetailContainer(
            regularModeDraft: $regularModeDraft,
            showDisplayModeAlert: $showDisplayModeAlert,
            ui: ui,
            theme: theme,
            onSelectDisplayMode: scheduleDisplayModeChange,
            onCancelDisplayRestart: resetDisplayModeDraft,
            onApplyDisplayRestart: applyPendingDisplayModeChange
        )
    }

    private func scheduleDisplayModeChange(_ nextMode: AppDisplayMode) {
        pendingDisplayMode = nextMode
        showDisplayModeAlert = true
    }

    private func resetDisplayModeDraft() {
        regularModeDraft = ui.displayMode == .regular
        pendingDisplayMode = nil
    }

    private func applyPendingDisplayModeChange() {
        if let pendingDisplayMode {
            AppBootstrap.shared?.applyDisplayModeAndRelaunch(pendingDisplayMode)
        }
        pendingDisplayMode = nil
    }
}

private struct AppearanceDetailContainer: View {
    @Binding var regularModeDraft: Bool
    @Binding var showDisplayModeAlert: Bool
    let ui: UIState
    let theme: EpistemosTheme
    let onSelectDisplayMode: (AppDisplayMode) -> Void
    let onCancelDisplayRestart: () -> Void
    let onApplyDisplayRestart: () -> Void

    var body: some View {
        configuredForm
    }

    private var configuredForm: AnyView {
        let base = AnyView(
            appearanceForm
            .formStyle(.grouped)
            .onAppear {
                Task { @MainActor in
                    regularModeDraft = ui.displayMode == .regular
                }
            }
            .onChange(of: ui.displayMode) { _, mode in
                regularModeDraft = mode == .regular
            }
        )
        return AnyView(
            base.alert("Restart to Apply Display Mode?", isPresented: $showDisplayModeAlert) {
                Button("Cancel", role: .cancel, action: onCancelDisplayRestart)
                Button("Restart Now", action: onApplyDisplayRestart)
            } message: {
                Text("Epistemos will relaunch to rebuild style caches. Your vault and saved data stay intact.")
            }
        )
    }

    private var appearanceForm: some View {
        Form {
            AppearanceSystemSection(theme: theme)
            AppearanceDisplayModeSection(
                regularModeDraft: $regularModeDraft,
                currentMode: ui.displayMode,
                onToggle: onSelectDisplayMode
            )
        }
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
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.general")!
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } header: {
            Text("System")
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

            Text("Uses standard system fonts, simplifies the landing greeting, and reduces animations. Restart required.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Display Mode")
        }
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
                            .font(.system(size: 11, design: .monospaced))
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
                            VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                        }
                        .controlSize(.small)
                        Button("Sync from Vault") {
                            Task { _ = await vaultSync.syncFromVault() }
                        }
                        .controlSize(.small)
                        Button("Disconnect", role: .destructive) {
                            VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
                        }
                        .controlSize(.small)
                    }
                } else {
                    Text("No vault connected. Select a folder to sync your markdown notes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Select Vault Folder") {
                        VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .controlSize(.small)
                }
            }

            if vaultSync.vaultURL != nil {
                Section("Search Index") {
                    HStack(spacing: 8) {
                        Button("Rebuild Index") {
                            vaultSync.rebuildIndex()
                        }
                        .disabled(vaultSync.isIndexing)
                        .controlSize(.small)

                        if vaultSync.isIndexing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Rebuilding...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                    Text("When enabled, unsaved note changes are automatically written to vault .md files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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

// MARK: - Knowledge Fusion Detail

private struct KnowledgeFusionDetailView: View {
    private var vm: KnowledgeFusionViewModel { .shared }

    var body: some View {
        Form {
            Section("Train") {
                TrainOnVaultView()
            }

            Section("Adapters") {
                HStack {
                    Text("Active Adapter")
                    Spacer()
                    AdapterSelectorView()
                }
                TrainingHistoryView()
            }

            Section("Feedback") {
                FeedbackIndicatorView()
                if let stats = vm.feedbackStats {
                    LabeledContent("Accepts this week", value: "\(stats.totalAccepts)")
                    LabeledContent("Rejects this week", value: "\(stats.totalRejects)")
                }
            }
        }
        .formStyle(.grouped)
        .environment(vm)
        .task {
            if let bootstrap = AppBootstrap.shared {
                vm.configure(triageService: bootstrap.triageService)
            }
            await vm.loadState()
        }
    }
}
