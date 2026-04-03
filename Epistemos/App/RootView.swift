import SwiftData
import SwiftUI

enum LandingToolbarGlyphs {
    static let greetingSymbol = "textformat"
}

enum HomeWindowIdentity {
    static let title = "Epistemos"

    static func matches(_ window: NSWindow?) -> Bool {
        window?.title == title
    }
}

// MARK: - Root View
// Top-level container with centered toolbar controls.
// System Liquid Glass toolbar provides the chrome — no custom glass needed.

struct RootView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    /// Set by EpistemosApp when AppBootstrap detected a database error.
    var databaseError: Error?
    /// Callback to reset database and relaunch.
    var onResetDatabase: (() -> Void)?

    @State private var appearanceObserver = SystemAppearanceObserver()
    @State private var showDatabaseAlert = false
    @State private var showGreetingControls = false
    @State private var showWorkspaceSwitcher = false
    @State private var showSessionIntelligence = false
    @State private var showTimeMachine = false


    /// Transition gate: suppresses toolbar reveal during landing→chat animation on Home.
    /// Only delays the *reveal*; hiding is always immediate.
    @State private var homeChatToolbarReady = false

    /// True when Home tab is showing an active chat (not landing).
    private var activeHomeChat: Bool {
        ui.homeTab == .home && !chat.showLanding && !chat.messages.isEmpty
    }

    private var showLandingToolbarControls: Bool {
        chat.showLanding || chat.messages.isEmpty
    }

    /// Canonical toolbar glass visibility — deterministic from app state.
    /// For non-Home tabs: always visible.
    /// For Home landing: always hidden.
    /// For Home chat: gated by `homeChatToolbarReady` to suppress transition flash.
    private var toolbarGlassVisible: Bool {
        if ui.homeTab != .home { return true }
        return activeHomeChat && homeChatToolbarReady
    }

    var body: some View {
        ZStack {
            ContentRouter()
        }
        // Wire the appearance observer — fires on real OS dark/light toggle.
        .onAppear {
            appearanceObserver.onAppearanceChange = { @MainActor isDark in
                ui.isSystemDark = isDark
            }
            appearanceObserver.start()
        }
        .onDisappear {
            appearanceObserver.stop()
        }
        .onChange(of: ui.appearanceSyncKey) { _, _ in
            UtilityWindowManager.shared.syncTheme(uiState: ui)
            HologramController.shared.syncTheme(ui)
        }
        .toolbar {
            // Back button — only during active chat on Home tab
            if ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding {
                ToolbarItem(placement: .navigation) {
                    Button {
                        chat.goHome()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityLabel("Back to Home")
                    .help("Back to Home")
                }
            }
            if showLandingToolbarControls || activeHomeChat {
                ToolbarItem(placement: .principal) {
                    rootToolbarControls
                }
                .sharedBackgroundVisibility(
                    (ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding)
                        ? .hidden : .automatic
                )
            }
        }
        .navigationTitle("")
        // Toolbar glass: hidden on home landing, visible for active home chat.
        // Canonical rule is derived from app state (deterministic).
        // `homeChatToolbarReady` only gates the Home landing→chat reveal to avoid flash.
        .toolbarBackgroundVisibility(
            toolbarGlassVisible ? .automatic : .hidden,
            for: .windowToolbar
        )
        .onChange(of: activeHomeChat) { _, isActive in
            if isActive {
                // Delay reveal until HomeRouter's landing→chat animation settles.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    homeChatToolbarReady = true
                }
            } else {
                // Hide immediately when returning to landing.
                homeChatToolbarReady = false
            }
        }
        // Chat sidebar is now a popover on the toolbar button (above)
        .overlay(alignment: .bottom) {
            if let message = ui.toastMessage {
                ToastOverlay(message: message, type: ui.toastType) {
                    ui.dismissToast()
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: ui.toastMessage)
            }
        }
        .frame(
            minWidth: WindowPresentationPolicy.mainWindowMinimumSize.width,
            minHeight: WindowPresentationPolicy.mainWindowMinimumSize.height
        )
        .background {
            Button(action: openSettingsWindow) {}
                .keyboardShortcut("s", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        // Pause heavy animations when the window is minimized to the Dock.
        // Without this, LiquidGreeting (typewriter loop) keeps running and burns CPU while invisible.
        // Filter by keyWindow to ignore miniaturize events from utility/MiniChat windows.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) {
            note in
            if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                ui.windowOccluded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification))
        { note in
            if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                ui.windowOccluded = false
            }
        }
        // Pause when the home window loses key status to another window (note editor, settings, etc.)
        // This is the primary guard against burning CPU behind other windows.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
            note in
            if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                ui.windowOccluded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
            note in
            if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                ui.windowOccluded = false
            }
        }
        // Also pause when app loses focus entirely (Cmd+Tab away, etc.)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
        ) { _ in
            ui.windowOccluded = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            ui.windowOccluded = false
        }
        // Setup screen — shown after a full reset (covers everything)
        .overlay {
            if ui.needsSetup {
                SetupView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if let issue = vaultSync.recoveryIssue {
                VaultRecoveryOverlay(
                    issue: issue,
                    isRecovering: vaultSync.isRecoveringLocalState,
                    rebuildAction: {
                        guard let vaultURL = issue.snapshot.vaultURL else { return }
                        Task { _ = await vaultSync.recoverFromVault(at: vaultURL) }
                    },
                    chooseVaultAction: {
                        VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                    },
                    disconnectAction: {
                        VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay { workspaceOverlays }
        .background { workspaceKeyboardShortcuts }
        .onKeyPress(.escape) {
            if showWorkspaceSwitcher { showWorkspaceSwitcher = false; return .handled }
            if showSessionIntelligence { showSessionIntelligence = false; return .handled }
            if showTimeMachine { showTimeMachine = false; return .handled }
            return .ignored
        }
        .animation(Motion.smooth, value: showWorkspaceSwitcher)
        .animation(Motion.smooth, value: showSessionIntelligence)
        .animation(Motion.smooth, value: showTimeMachine)
        .onReceive(NotificationCenter.default.publisher(for: .toggleWorkspaceSwitcher)) { _ in
            showWorkspaceSwitcher.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSessionIntelligence)) { _ in
            showSessionIntelligence.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTimeMachine)) { _ in
            showTimeMachine.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSaveWorkspacePanel)) { _ in
            QuitSavePanelController.showSave()
        }
        .animation(Motion.smooth, value: ui.needsSetup)
        .onAppear {
            if databaseError != nil { showDatabaseAlert = true }
        }
        .alert("Database Error", isPresented: $showDatabaseAlert) {
            Button("Continue Empty") { }
            Button("Reset Database", role: .destructive) { onResetDatabase?() }
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text("The database could not be loaded. You can continue with an empty session, reset the database (deletes saved data), or quit.\n\n\(databaseError?.localizedDescription ?? "")")
        }
    }

    @ViewBuilder
    private var workspaceOverlays: some View {
        if showWorkspaceSwitcher {
            WorkspaceSwitcherOverlay(isPresented: $showWorkspaceSwitcher)
        }
        if showSessionIntelligence {
            SessionIntelligenceOverlay(isPresented: $showSessionIntelligence)
        }
        if showTimeMachine {
            TimeMachineView(isPresented: $showTimeMachine)
        }
    }

    @ViewBuilder
    private var workspaceKeyboardShortcuts: some View {
        Button(action: { showWorkspaceSwitcher.toggle() }) {}
            .keyboardShortcut("w", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { showSessionIntelligence.toggle() }) {}
            .keyboardShortcut("r", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { showTimeMachine.toggle() }) {}
            .keyboardShortcut("t", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { QuitSavePanelController.showSave() }) {}
            .keyboardShortcut("s", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)
    }

    private var rootToolbarControls: some View {
        HStack(spacing: 10) {
            if showLandingToolbarControls {
                ControlGroup {
                    settingsToolbarButton
                    landingGreetingToolbarButton
                    historyToolbarButton
                }
            }

            if activeHomeChat {
                modelToolbarButton(title: chat.chatTitle)
            }
        }
        .frame(minWidth: 160, minHeight: 28)
        .fixedSize()
    }

    private var settingsToolbarButton: some View {
        Button(action: openSettingsWindow) {
            Label("Settings", systemImage: "gearshape")
        }
        .accessibilityLabel("Settings")
        .help("Settings (⌘S)")
    }

    private func modelToolbarButton(title: String? = nil) -> some View {
        LocalModelToolbarMenu(
            variant: .toolbar,
            overrideTitle: title,
            overrideFont: title != nil ? Font.system(size: 16, weight: .semibold, design: .rounded) : nil
        )
        .fixedSize()
    }

    private func openSettingsWindow() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate()
    }

    private var landingGreetingToolbarButton: some View {
        Button {
            showGreetingControls.toggle()
        } label: {
            Label("Greeting", systemImage: LandingToolbarGlyphs.greetingSymbol)
        }
        .help("Adjust greeting behavior")
        .popover(isPresented: $showGreetingControls) {
            LandingGreetingControlsView()
                .frame(width: 320)
                .padding(16)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    private var historyToolbarButton: some View {
        @Bindable var ui = ui
        return Button {
            ui.toggleChatSidebar()
        } label: {
            Label("History", systemImage: "sidebar.left")
        }
        .accessibilityLabel("Chat History")
        .help("Chat History (⇧⌘H)")
        .popover(isPresented: $ui.showChatSidebar) {
            ChatSidebarView()
                .frame(width: 300, height: 500)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }
}

struct LocalModelToolbarMenu: View {
    private enum MenuSelection: Identifiable, Equatable {
        case appleIntelligence
        case inProcess(LocalModelDescriptor)
        case cloud(CloudTextModelID)

        var id: String {
            switch self {
            case .appleIntelligence:
                "apple-intelligence"
            case .inProcess(let descriptor):
                "mlx:\(descriptor.id)"
            case .cloud(let model):
                "cloud:\(model.rawValue)"
            }
        }
    }

    var variant: NativeControlVariant = .toolbar
    var overrideTitle: String? = nil
    var overrideFont: Font? = nil
    var operatingMode: Binding<EpistemosOperatingMode>? = nil
    var isTemporaryChatEnabled: Binding<Bool>? = nil

    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(LocalModelManager.self) private var localModelManager
    @State private var isPresented = false
    @State private var showsLocalModels = true
    @State private var showsCloudModels = true

    private var theme: EpistemosTheme { ui.theme }

    private var installedSelectableModels: [LocalModelDescriptor] {
        localModelManager.textDescriptors.filter { descriptor in
            localModelManager.installRecords[descriptor.id] != nil
                && inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor)
        }
    }

    private var selectedDescriptor: LocalModelDescriptor? {
        if case .localQwen(let modelID) = inference.preferredChatModelSelection,
           let descriptor = LocalModelCatalog.descriptor(for: modelID),
           installedSelectableModels.contains(descriptor) {
            return descriptor
        }
        if let modelID = inference.activeLocalTextModelID,
           let descriptor = LocalModelCatalog.descriptor(for: modelID),
           installedSelectableModels.contains(descriptor) {
            return descriptor
        }
        return installedSelectableModels.first
    }

    private var selectedMenuItem: MenuSelection? {
        if inference.preferredChatModelSelection == .appleIntelligence {
            return .appleIntelligence
        }
        if case .cloud(let model) = inference.preferredChatModelSelection {
            return .cloud(model)
        }
        if let descriptor = selectedDescriptor {
            return .inProcess(descriptor)
        }
        return nil
    }

    private var labelText: String {
        if let overrideTitle { return overrideTitle }
        let selectedModelLabel = switch selectedMenuItem {
        case .appleIntelligence:
            "Apple Intelligence"
        case .cloud(let model):
            model.compactDisplayName
        case .inProcess(let descriptor):
            LocalTextModelID(rawValue: descriptor.id)?.compactDisplayName ?? descriptor.displayName
        case nil:
            "Select Model"
        }
        guard let operatingMode else { return selectedModelLabel }
        return "\(selectedModelLabel) \(operatingMode.wrappedValue.displayName)"
    }

    private var labelFont: Font {
        if let overrideFont { return overrideFont }
        switch variant {
        case .toolbar:
            return Font.system(size: 14, weight: .medium)
        case .content:
            return Font.system(size: 13.5, weight: .medium)
        }
    }

    private var disclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: [
                "Apple Intelligence Agent",
                "GPT-5.4 Thinking",
                "Gemini 2.5 Pro Agent",
                "Qwen 35B Thinking",
            ],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var buttonSystemImage: String {
        if isTemporaryChatEnabled?.wrappedValue == true {
            return "eye.slash.fill"
        }
        if let operatingMode {
            return operatingMode.wrappedValue.systemImage
        }
        switch selectedMenuItem {
        case .appleIntelligence:
            return "apple.intelligence"
        case .cloud:
            return "cloud.fill"
        case .inProcess, .none:
            return "memorychip"
        }
    }

    private var selectedModeSummary: String {
        if let operatingMode {
            return operatingMode.wrappedValue.helpText
        }
        return "Choose the model that should power this surface."
    }

    private var noLocalModelsText: String {
        inference.appleIntelligenceAvailable
            ? "Install a local model to add an on-device fallback here."
            : "No supported local models are installed yet."
    }

    var body: some View {
        if overrideTitle != nil {
            titleLabel
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .help(labelText)
                .accessibilityLabel(labelText)
        } else {
            AnchoredPopoverButton(
                title: labelText,
                systemImage: buttonSystemImage,
                isPresented: $isPresented,
                isActive: isTemporaryChatEnabled?.wrappedValue == true,
                variant: variant,
                showsLabelWhenCollapsed: true,
                helpText: selectedModeSummary,
                accessibilityLabel: labelText,
                idealPopoverWidth: variant == .toolbar ? 340 : 360,
                contentPadding: 12,
                stableWidth: disclosureWidth
            ) {
                runtimePopover
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var runtimePopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runtime")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                if let operatingMode {
                    VStack(alignment: .leading, spacing: 8) {
                        popoverSectionTitle("Mode")
                        ForEach(EpistemosOperatingMode.allCases, id: \.rawValue) { option in
                            let isEnabled = inference.availableOperatingModes.contains(option)
                            selectionRow(
                                title: option.displayName,
                                subtitle: modeSubtitle(for: option, isEnabled: isEnabled),
                                systemImage: option.systemImage,
                                isSelected: operatingMode.wrappedValue == option,
                                isEnabled: isEnabled
                            ) {
                                operatingMode.wrappedValue = inference.sanitizedOperatingMode(option)
                                isPresented = false
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    popoverSectionTitle("Models")

                    DisclosureGroup(
                        isExpanded: $showsLocalModels,
                        content: {
                            VStack(alignment: .leading, spacing: 6) {
                                if inference.appleIntelligenceAvailable {
                                    selectionRow(
                                        title: "Apple Intelligence",
                                        subtitle: "Fast on-device work for lightweight requests.",
                                        systemImage: "apple.intelligence",
                                        isSelected: selectedMenuItem == .appleIntelligence
                                    ) {
                                        inference.setPreferredChatModelSelection(.appleIntelligence)
                                        isPresented = false
                                    }
                                }

                                if installedSelectableModels.isEmpty {
                                    Text(noLocalModelsText)
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.textTertiary)
                                        .padding(.leading, 4)
                                        .padding(.top, 2)
                                } else {
                                    ForEach(installedSelectableModels, id: \.id) { model in
                                        selectionRow(
                                            title: LocalTextModelID(rawValue: model.id)?.compactDisplayName ?? model.displayName,
                                            subtitle: localModelSubtitle(for: model),
                                            systemImage: "memorychip",
                                            isSelected: selectedMenuItem == .inProcess(model)
                                        ) {
                                            inference.setPreferredChatModelSelection(.localQwen(model.id))
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        },
                        label: {
                            disclosureTitle(
                                title: "Local Models",
                                subtitle: installedSelectableModels.isEmpty
                                    ? "On-device"
                                    : "\(installedSelectableModels.count) available"
                            )
                        }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        popoverSectionTitle("AI Provider")

                        ForEach(CloudModelProvider.allCases, id: \.rawValue) { provider in
                            let selection = AIProviderSelection(cloudProvider: provider)
                            selectionRow(
                                title: provider.displayName,
                                subtitle: providerSelectionSubtitle(for: provider),
                                systemImage: provider.systemImage,
                                isSelected: inference.activeAIProvider == selection
                            ) {
                                inference.setActiveAIProvider(selection)
                            }
                        }

                        selectionRow(
                            title: "Local Only",
                            subtitle: "Hide cloud models from this picker and stay on-device.",
                            systemImage: "memorychip",
                            isSelected: inference.activeAIProvider == .localOnly
                        ) {
                            inference.setActiveAIProvider(.localOnly)
                        }
                    }

                    DisclosureGroup(
                        isExpanded: $showsCloudModels,
                        content: {
                            VStack(alignment: .leading, spacing: 10) {
                                if let provider = inference.activeCloudProvider {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .center, spacing: 8) {
                                            Image(systemName: provider.systemImage)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(theme.textSecondary)
                                            Text(provider.displayName)
                                                .font(.system(size: 12, weight: .semibold))
                                            Spacer()
                                            Text(inference.cloudValidationState(for: provider).statusBadge)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(theme.textTertiary)
                                        }

                                        Text(inference.cloudValidationState(for: provider).statusText)
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.textTertiary)

                                        ForEach(CloudTextModelID.models(for: provider), id: \.rawValue) { model in
                                            let providerConfigured = inference.configuredCloudProviders.contains(provider)
                                            selectionRow(
                                                title: model.compactDisplayName,
                                                subtitle: cloudModelSubtitle(for: model),
                                                systemImage: provider.systemImage,
                                                isSelected: selectedMenuItem == .cloud(model),
                                                isEnabled: providerConfigured
                                            ) {
                                                inference.setPreferredChatModelSelection(.cloud(model))
                                                isPresented = false
                                            }
                                        }
                                    }
                                    .padding(.top, 2)
                                } else {
                                    Text("Local Only is active. Switch the AI Provider to browse cloud models here.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.textTertiary)
                                        .padding(.leading, 4)
                                }

                                Button("Open Inference Settings") {
                                    openSettings()
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.resolved.accent.color)
                                .padding(.leading, 4)
                            }
                        },
                        label: {
                            disclosureTitle(
                                title: "Cloud Models",
                                subtitle: cloudDisclosureSubtitle
                            )
                        }
                    )
                }

                if let isTemporaryChatEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        popoverSectionTitle("Conversation")
                        selectionRow(
                            title: "Temporary Chat",
                            subtitle: isTemporaryChatEnabled.wrappedValue
                                ? "This conversation stays in memory only and will not be saved."
                                : "Turns off chat persistence for this thread.",
                            systemImage: isTemporaryChatEnabled.wrappedValue ? "eye.slash.fill" : "eye.slash",
                            isSelected: isTemporaryChatEnabled.wrappedValue
                        ) {
                            isTemporaryChatEnabled.wrappedValue.toggle()
                        }
                    }
                }

                Divider()

                Button("Open Settings") {
                    openSettings()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
            }
        }
    }

    @ViewBuilder
    private func popoverSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func disclosureTitle(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
        }
    }

    @ViewBuilder
    private func selectionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: variant == .toolbar ? 12 : 13, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: variant == .toolbar ? 12.5 : 13, weight: .semibold))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.resolved.accent.color)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(NativeCardButtonStyle(cornerRadius: 12))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func modeSubtitle(for option: EpistemosOperatingMode, isEnabled: Bool) -> String {
        guard isEnabled else {
            switch option {
            case .thinking:
                return "This model does not expose verified thinking mode."
            case .agent:
                return "This model cannot run the current visible agent loop."
            case .fast:
                return option.helpText
            }
        }
        return option.helpText
    }

    private func localModelSubtitle(for model: LocalModelDescriptor) -> String {
        guard let modelID = LocalTextModelID(rawValue: model.id) else {
            return "On-device model"
        }

        var features: [String] = []
        if modelID.supportsThinkingMode {
            features.append("Thinking")
        }
        if modelID.canActAsAgent {
            features.append("Agent")
        }
        let featureSummary = features.isEmpty ? "Fast only" : features.joined(separator: " • ")
        return "\(featureSummary) • \(modelID.minimumRecommendedMemoryGB) GB+"
    }

    private func providerSelectionSubtitle(for provider: CloudModelProvider) -> String {
        let status = inference.cloudValidationState(for: provider).statusBadge
        return "\(provider.modelSummary) • \(status)"
    }

    private func cloudModelSubtitle(for model: CloudTextModelID) -> String {
        let provider = model.provider
        let configuration = inference.configuredCloudProviders.contains(provider)
            ? "Ready"
            : "Add key"
        return "\(provider.displayName) • \(configuration)"
    }

    private var cloudDisclosureSubtitle: String {
        guard let provider = inference.activeCloudProvider else {
            return "Local Only"
        }
        let validation = inference.cloudValidationState(for: provider)
        if inference.configuredCloudProviders.contains(provider) {
            return "\(provider.displayName) • \(validation.statusBadge)"
        }
        return "Add a key to unlock"
    }

    private func openSettings() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate()
    }

    @ViewBuilder
    private var titleLabel: some View {
        HStack(spacing: 5) {
            if overrideTitle != nil {
                TypewriterASCIIRippleText(
                    text: labelText,
                    font: labelFont,
                    color: theme.textSecondary,
                    configuration: .init(duration: 0.55, spread: 1.25, waveThreshold: 2.2, characterMultiplier: 2)
                )
            } else {
                ASCIIRippleText(
                    text: labelText,
                    font: labelFont,
                    color: theme.textSecondary,
                    configuration: .init(duration: 0.55, spread: 1.25, waveThreshold: 2.2, characterMultiplier: 2)
                )
            }
        }
        .fixedSize()
    }
}


private struct VaultRecoveryOverlay: View {
    let issue: VaultRecoveryIssue
    let isRecovering: Bool
    let rebuildAction: () -> Void
    let chooseVaultAction: () -> Void
    let disconnectAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.26)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Vault Rebuild Needed")
                    .font(.system(size: 22, weight: .semibold))

                Text(issue.detailText)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button(isRecovering ? "Rebuilding…" : "Rebuild Local State") {
                        rebuildAction()
                    }
                    .disabled(isRecovering || !issue.snapshot.isVaultReadable)

                    Button("Choose Vault Folder") {
                        chooseVaultAction()
                    }
                    .disabled(isRecovering)

                    Button("Disconnect Vault", role: .destructive) {
                        disconnectAction()
                    }
                    .disabled(isRecovering)
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
            .padding(32)
        }
    }
}

// MARK: - Home Tab

enum HomeTab: String, CaseIterable {
    case home

    var label: String {
        switch self {
        case .home: "Home"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        }
    }
}

// MARK: - Content Router
// Main window content — Home only.

struct ContentRouter: View {
    var body: some View {
        HomeRouter()
    }
}

// MARK: - Home Router
// Separate view so the Chat/Landing switch doesn't affect the outer ZStack.
// Uses withAnimation at call-site (submitQuery/clearMessages) for the transition.

private struct HomeRouter: View {
    @Environment(ChatState.self) private var chat

    /// Show chat when messages exist AND user hasn't navigated to landing.
    private var showChat: Bool { !chat.messages.isEmpty && !chat.showLanding }

    var body: some View {
        ZStack {
            if showChat {
                ChatView()
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else {
                LandingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            }
        }
        .animation(Motion.smooth, value: showChat)
    }
}

// MARK: - Wallpaper

struct WallpaperView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        ui.wallpaperBackground
            .ignoresSafeArea()
    }
}

private struct LandingGreetingControlsView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        VStack(alignment: .leading, spacing: 14) {
            Text("Greeting")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Animate typewriter", isOn: $ui.landingGreetingTypewriterEnabled)

            Text("Custom greetings and timing live in Settings > Landing.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Setup View
// Full-screen welcome shown after a Reset Everything.
// Minimal: logo, welcome message, "Get Started" to dismiss.

struct SetupView: View {
    @Environment(UIState.self) private var ui

    @State private var overlayOpacity: Double = 0
    @State private var displayText = ""
    @State private var typingDone = false
    @State private var buttonOpacity: Double = 0

    private var theme: EpistemosTheme { ui.theme }
    private let fullText = "Welcome to Epistemos..."
    private var retroFont: Font { AppDisplayTypography.font(size: 38) }

    var body: some View {
        ZStack {
            // Solid background
            theme.resolved.background.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Typewriter greeting — RetroGaming font, same style as LiquidGreeting
                HStack(alignment: .center, spacing: 0) {
                    Text(displayText)
                        .font(retroFont)
                        .foregroundStyle(theme.fontAccent)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .frame(minHeight: 80)
                .shadow(color: theme.fontAccent.opacity(0.12), radius: 8)

                Spacer()
                    .frame(height: 60)

                // "press me to start" — fades in after typing completes
                Button {
                    withAnimation(Motion.smooth) {
                        ui.needsSetup = false
                    }
                } label: {
                    Text("press me to start")
                        .font(AppDisplayTypography.font(size: 14))
                        .foregroundStyle(theme.fontAccent.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(theme.fontAccent.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .opacity(buttonOpacity)

                Spacer()

                // Subtitle at the bottom
                Text("install a local qwen model in Settings to get started")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .opacity(buttonOpacity)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(overlayOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { overlayOpacity = 1 }
        }
        .task {
            if ui.displayMode.reducesASCIIAnimations {
                displayText = fullText
                typingDone = true
                buttonOpacity = 1
                return
            }

            // Small initial delay
            try? await Task.sleep(for: .milliseconds(600))

            // Type out the full text — same natural timing as LiquidGreeting
            for i in 1...fullText.count {
                guard !Task.isCancelled else { break }
                displayText = String(fullText.prefix(i))

                let ch = displayText.last ?? " "
                var delay: Double = Double.random(in: 50...80)

                if ".!?".contains(ch) { delay += Double.random(in: 200...400) }
                else if ",;:".contains(ch) { delay += Double.random(in: 80...160) }
                else if ch == " " && Double.random(in: 0...1) < 0.08 { delay += Double.random(in: 60...120) }

                // Natural stutter
                if Double.random(in: 0...1) < 0.10 { delay += Double.random(in: 120...250) }
                if Double.random(in: 0...1) < 0.03 { delay += Double.random(in: 350...600) }

                if i <= 2 { delay += 100 }

                try? await Task.sleep(for: .milliseconds(Int(delay)))
            }

            // Typing done — fade in the button
            typingDone = true
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeIn(duration: 0.8)) {
                buttonOpacity = 1
            }
        }
    }
}
