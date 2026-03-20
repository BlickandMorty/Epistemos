import AppKit
import SwiftUI

// MARK: - Settings View
// Presented as a standalone macOS Settings window (LucidApp.swift registers the Settings scene).
// Layout mirrors macOS System Settings: NavigationSplitView sidebar → Form-based detail pane.

struct SettingsView: View {
    @Environment(UIState.self) private var ui
    @State private var selection: SettingsSection? = .inference

    enum SettingsSection: String, CaseIterable, Identifiable {
        case inference = "Inference"
        case landing = "Landing"
        case appearance = "Appearance"
        case vault = "Vault"
        case security = "Security"
        case export = "Export"
        case reset = "Reset"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .inference: "cpu"
            case .landing: "sparkles.rectangle.stack"
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
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .safeAreaPadding(.top, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            settingsDetail
        }
        .navigationSplitViewStyle(.balanced)
        .ignoresSafeArea(.container, edges: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                sidebarToggleButton
            }
        }
    }

    @ViewBuilder
    private var settingsDetail: some View {
        Group {
            switch selection {
            case .inference: InferenceDetailView()
            case .landing: LandingDetailView()
            case .appearance: AppearanceDetailView()
            case .vault: VaultDetailView()
            case .security: SecurityDetailView()
            case .export: ExportDetailView()
            case .reset: ResetDetailView()
            case nil: InferenceDetailView()
            }
        }
        .safeAreaPadding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sidebarToggleButton: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
        .help("Toggle Sidebar")
    }

    private func toggleSidebar() {
        guard !NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil),
              let firstResponder = NSApp.keyWindow?.firstResponder else {
            return
        }
        _ = firstResponder.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// MARK: - Landing Detail

private struct LandingDetailView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui

        Form {
            Section("Cursor Animation") {
                Picker("Cursor Visibility", selection: $ui.landingCursorVisibilityMode) {
                    ForEach(LandingCursorVisibilityMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(ui.landingCursorVisibilityMode.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Greeting Behavior") {
                Toggle("Animate typewriter", isOn: $ui.landingGreetingTypewriterEnabled)

                Picker("Greeting Sources", selection: $ui.landingGreetingSourceMode) {
                    ForEach(LandingGreetingSourceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(ui.landingGreetingSourceMode.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Greeting Library") {
                if ui.landingCustomGreetings.isEmpty {
                    ContentUnavailableView(
                        "No Custom Greetings",
                        systemImage: "text.badge.plus",
                        description: Text(
                            "Add your own phrases and per-greeting timing here. Defaults stay active unless you switch to Custom Only."
                        )
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

    private var theme: EpistemosTheme { ui.theme }

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
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)

                if inference.appleIntelligenceAvailable {
                    Label(
                        "Apple Intelligence is available for lightweight on-device work in Auto mode",
                        systemImage: "apple.intelligence"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(theme.success)
                } else if let reason = inference.appleIntelligenceUnavailableReason, !reason.isEmpty {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.warning)
                }
            }

            Section("Local AI") {
                LabeledContent("Hardware") {
                    Text(localModelManager.hardwareSummary)
                        .font(.system(size: 13, design: .monospaced))
                }

                LabeledContent("Installed") {
                    Text(inference.localModelInstallStateSummary.displayName)
                        .font(.system(size: 13, weight: .medium))
                }

                LabeledContent("Active Tier") {
                    Text(inference.activeLocalTextModelDisplayName)
                        .font(.system(size: 13, weight: .medium))
                }

                LabeledContent("Storage") {
                    Text(ByteCountFormatter.string(fromByteCount: localModelManager.totalInstalledStorageBytes, countStyle: .file))
                        .font(.system(size: 13, design: .monospaced))
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

                Text("Epistemos keeps AI on-device. Epistemos uses the exact Qwen tier you select and sends plain single-pass local requests by default. If that tier is unavailable, choose or install another supported tier.")
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)

                if let fallback = localModelManager.missingConstrainedFallbackDescriptor {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If you want a lighter manual fallback for constrained conditions, also install \(fallback.displayName).")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)

                        Button("Install Constrained Fallback") {
                            Task {
                                try? await localModelManager.install(modelID: fallback.id)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button("Manage Local Models") {
                    showLocalModelManager = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
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
            Task { @MainActor in
                let saved = inference.chatOutputTokens
                tokenCapEnabled = saved > 0
                if saved > 0 { tokenCapDraft = saved }
            }
        }
        .sheet(isPresented: $showLocalModelManager) {
            LocalModelManagerSheet()
                .frame(minWidth: 700, minHeight: 520)
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
                            .font(.system(size: 11))
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
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
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
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text(descriptor.familyName)
                    Text(descriptor.approximateDownloadLabel)
                    Text("Min \(descriptor.minimumRecommendedMemoryGB) GB")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

                if case .installing(let progress) = state {
                    ProgressView(value: progress)
                        .controlSize(.small)
                        .frame(maxWidth: 220)
                } else if case .blocked(let reason) = state {
                    Text(blockedGuidance(for: reason))
                        .font(.system(size: 11))
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
            case .installing:
                ProgressView()
                    .controlSize(.small)
            case .blocked:
                blockedAction
            case .available:
                Button("Install") {
                    Task {
                        try? await localModelManager.install(modelID: descriptor.id)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var blockedAction: some View {
        if localModelManager.installErrors[descriptor.id] != nil {
            Button("Retry") {
                Task {
                    try? await localModelManager.install(modelID: descriptor.id)
                }
            }
            .buttonStyle(.borderedProminent)
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
            .scrollContentBackground(.hidden)
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
                LabeledContent("Local models") {
                    Text("Stored in Application Support")
                        .foregroundStyle(theme.success)
                        .font(.system(size: 12))
                }
                LabeledContent("Apple Intelligence") {
                    Text("On-device only")
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
                    "Clear all saved data, conversations, local model state, and settings. Your vault files on disk will not be deleted."
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
                "This will delete all conversations, notes data, local model state, and preferences. Your vault files on disk are preserved. This cannot be undone."
            )
        }
    }
}
