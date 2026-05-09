import AppKit
import SwiftData
import SwiftUI

enum LandingToolbarGlyphs {
    static let greetingSymbol = "textformat"
}

enum HomeWindowIdentity {
    static let title = "Epistemos"
    static let sceneIdentifier = "main"

    static func matches(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window.identifier?.rawValue == sceneIdentifier
            || window.title == title
    }

    static func apply(to window: NSWindow) {
        if window.identifier?.rawValue != sceneIdentifier {
            window.identifier = NSUserInterfaceItemIdentifier(sceneIdentifier)
        }
    }

    @MainActor
    static func surfaceHomeWindow() {
        NSApp.activate(ignoringOtherApps: true)
        guard let mainWindow = NSApp.windows.first(where: matches) else { return }
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        mainWindow.orderFrontRegardless()
        mainWindow.makeKeyAndOrderFront(nil)

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }

            guard let mainWindow = NSApp.windows.first(where: matches) else { return }
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.orderFrontRegardless()
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }
}

enum RootViewDestructiveActionSovereignGate {
    enum Target: Equatable {
        case databaseReset
        case vaultDisconnect
    }

    static func requirement(for _: Target) -> SovereignGateRequirement {
        .deviceOwnerAuthentication
    }

    static func reason(for target: Target) -> String {
        switch target {
        case .databaseReset:
            "Reset database and delete saved data."
        case .vaultDisconnect:
            "Disconnect vault from this workspace."
        }
    }
}

private struct HomeWindowIdentityObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> HomeWindowIdentityObserverView {
        HomeWindowIdentityObserverView()
    }

    func updateNSView(_ nsView: HomeWindowIdentityObserverView, context: Context) {
        nsView.applyWindowIdentity()
    }
}

private final class HomeWindowIdentityObserverView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowIdentity()
    }

    func applyWindowIdentity() {
        guard let window else { return }
        HomeWindowIdentity.apply(to: window)
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
        ui.homeTab == .home
            && !chat.showLanding
            && !chat.messages.isEmpty
    }

    private var showLandingToolbarControls: Bool {
        ui.homeTab == .home
            && (chat.showLanding || chat.messages.isEmpty)
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
        rootContent
            .modifier(RootWindowLifecycle(ui: ui))
            .modifier(RootWorkspaceEvents(
                showWorkspaceSwitcher: $showWorkspaceSwitcher,
                showSessionIntelligence: $showSessionIntelligence,
                showTimeMachine: $showTimeMachine
            ))
    }

    private var rootContent: some View {
        ZStack {
            // Pre-paint the window background so transitions from landing
            // into chat don't briefly flash the old theme surface at
            // the title bar. Dark mode = OLED black, light mode = theme bg.
            // `allowsHitTesting(false)` is CRITICAL — without it the Color
            // swallows clicks, breaking every button on the window.
            (ui.theme.isDark ? Color.black : ui.theme.resolved.background.color)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ContentRouter()
        }
        .background(HomeWindowIdentityObserver())
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: activeHomeChat)
        .onAppear(perform: handleAppearanceOnAppear)
        .onDisappear {
            appearanceObserver.stop()
        }
        .onChange(of: ui.appearanceSyncKey) { _, _ in
            UtilityWindowManager.shared.syncTheme(uiState: ui)
            HologramController.shared.syncTheme(ui)
        }
        .toolbar {
            // Back button — only during active chat on Home tab
            if ui.homeTab == .home && activeHomeChat {
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
                    (ui.homeTab == .home && activeHomeChat)
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
        // Setup screen — shown after a full reset (covers everything)
        .overlay {
            if ui.needsSetup {
                SetupView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if let issue = vaultSync.recoveryIssue,
               issue.blocksWorkspaceInteraction {
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
        .animation(Motion.smooth, value: ui.needsSetup)
        .onAppear(perform: handleDatabaseCheck)
        .alert("Database Error", isPresented: $showDatabaseAlert) {
            Button("Continue Empty") { }
            Button("Reset Database", role: .destructive) {
                requestDatabaseResetAuthorization()
            }
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text("The database could not be loaded. You can continue with an empty session, reset the database (deletes saved data), or quit.\n\n\(databaseError?.localizedDescription ?? "")")
        }
    }

    private func requestDatabaseResetAuthorization() {
        let target = RootViewDestructiveActionSovereignGate.Target.databaseReset

        Task { @MainActor in
            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                RootViewDestructiveActionSovereignGate.requirement(for: target),
                reason: RootViewDestructiveActionSovereignGate.reason(for: target)
            ) ?? .denied(.authenticationFailed)

            guard outcome == .allowed else {
                if databaseError != nil {
                    showDatabaseAlert = true
                }
                return
            }

            onResetDatabase?()
        }
    }

    private func handleDatabaseCheck() {
        if databaseError != nil {
            showDatabaseAlert = true
        }
    }

    private func handleAppearanceOnAppear() {
        appearanceObserver.onAppearanceChange = { @MainActor isDark in
            ui.isSystemDark = isDark
        }
        appearanceObserver.start()
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

    @ViewBuilder
    private func modelToolbarButton(title: String? = nil) -> some View {
        Text(title ?? chat.chatTitle ?? "")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(ui.theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
            .fixedSize()
            .accessibilityLabel("Chat title")
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

    private enum SplitToolbarPopover: Hashable {
        case mode
        case model
        case routing
        case effort
        case nativeControls
    }

    var variant: NativeControlVariant = .toolbar
    var overrideTitle: String? = nil
    var overrideFont: Font? = nil
    var operatingMode: Binding<EpistemosOperatingMode>? = nil
    var availableOperatingModes: [EpistemosOperatingMode]? = nil
    var isTemporaryChatEnabled: Binding<Bool>? = nil
    /// Main chat passes `true` so the composer gets the full split
    /// toolbar (Mode · Model · Routing · Effort · Native Controls).
    /// Landing, mini chat, note chat, and graph chat leave this `false`
    /// so the surface shows one compact popover trigger ("Fast · Qwen")
    /// instead of five separate buttons. Routing/effort/native controls
    /// only make sense on main chat; the other surfaces delegate to
    /// Settings for those.
    var preferSplitToolbarControls: Bool = false

    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(LocalModelManager.self) private var localModelManager
    @State private var isPresented = false
    @State private var activeSplitPopover: SplitToolbarPopover?
    @State private var showsLocalModels = false
    @State private var showsCloudProviderOptions = false
    @State private var showsActiveCloudModelOptions = false
    @State private var aboutSelection: ChatModelSelection?
    @State private var localModelSubtitleCache: [String: String] = [:]

    private var theme: EpistemosTheme { ui.theme }

    private var installedSelectableModels: [LocalModelDescriptor] {
        let selectableIDs = Set(inference.releaseSelectableInstalledLocalTextModelIDs)
        return localModelManager.textDescriptors.filter { descriptor in
            selectableIDs.contains(descriptor.id)
        }
    }

    private var installableSelectableModels: [LocalModelDescriptor] {
        let shippedModelIDs = Set(LocalModelCatalog.shippedModelIDs)
        return localModelManager.textDescriptors.filter { descriptor in
            localModelManager.installRecords[descriptor.id] == nil
                && shippedModelIDs.contains(descriptor.id)
                && inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor)
                && (LocalTextModelID(rawValue: descriptor.id)?.isReleaseValidatedForInteractiveChat ?? true)
        }
    }

    private var selectedDescriptor: LocalModelDescriptor? {
        if case .localMLX(let modelID) = inference.preferredChatModelSelection,
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

    private var usesAutomaticCloudRoute: Bool {
        inference.chatAutoRouteActive
    }

    private var automaticRouteSummary: String {
        if let operatingMode {
            return inference.chatSurfaceRouteDescription(for: operatingMode.wrappedValue).summary
        }
        if let provider = inference.preferredAutoRouteCloudProvider {
            return "Fast stays local-first, while higher-capability chat modes can escalate through \(provider.displayName)."
        }
        return "Connect a cloud provider to let higher-capability chat modes escalate beyond the local runtime."
    }

    private var displayedCloudProvider: CloudModelProvider? {
        inference.activeCloudProvider ?? inference.preferredAutoRouteCloudProvider
    }

    private var usesSplitToolbarControls: Bool {
        preferSplitToolbarControls && operatingMode != nil && overrideTitle == nil
    }

    private var currentOperatingMode: EpistemosOperatingMode? {
        operatingMode.map { sanitizedDisplayedOperatingMode($0.wrappedValue) }
    }

    private var currentRouteDescription: ChatSurfaceRouteDescription? {
        guard let currentOperatingMode else { return nil }
        return inference.chatSurfaceRouteDescription(for: currentOperatingMode)
    }

    private var currentEffectiveSelection: ChatModelSelection? {
        guard let currentOperatingMode else { return nil }
        return inference.effectiveChatSurfaceSelection(for: currentOperatingMode)
    }

    private var currentRuntimeNeedsSetup: Bool {
        guard let currentOperatingMode else { return false }
        return !inference.isChatSurfaceRuntimeReady(for: currentOperatingMode)
    }

    private var runtimeSetupSummary: String {
        "Install a local model, connect a cloud provider, or enable Apple Intelligence before sending."
    }

    private var currentEffectiveCloudModel: CloudTextModelID? {
        guard case .cloud(let model) = currentEffectiveSelection else { return nil }
        return model
    }

    private var currentDisplayedReasoningTier: ChatReasoningTier {
        guard let currentOperatingMode else { return inference.chatReasoningTier }
        return inference.sanitizedReasoningTier(
            inference.chatReasoningTier,
            for: currentOperatingMode
        )
    }

    private var supportsRuntimeEffortButton: Bool {
        guard let currentOperatingMode,
              !inference.availableReasoningTiers(for: currentOperatingMode).isEmpty,
              let model = currentEffectiveCloudModel else {
            return false
        }
        return model.supportsNativeReasoningEffortControl
    }

    private var supportsProviderNativeControlsButton: Bool {
        currentEffectiveCloudModel?.supportsProviderNativeFeatureControls ?? false
    }

    private var labelText: String {
        if let overrideTitle { return overrideTitle }
        if let operatingMode,
           !inference.isChatSurfaceRuntimeReady(for: operatingMode.wrappedValue) {
            return "\(operatingMode.wrappedValue.displayName) · Set Up Model"
        }
        let selectedModelLabel: String
        if let operatingMode {
            selectedModelLabel = inference.chatSurfaceRouteDescription(
                for: operatingMode.wrappedValue
            ).headline
        } else if usesAutomaticCloudRoute {
            selectedModelLabel = "Auto Route"
        } else {
            selectedModelLabel = switch selectedMenuItem {
            case .appleIntelligence:
                "Apple Intelligence"
            case .cloud(let model):
                model.compactDisplayName
            case .inProcess(let descriptor):
                LocalTextModelID(rawValue: descriptor.id)?.compactDisplayName ?? descriptor.displayName
            case nil:
                "Select Model"
            }
        }
        guard let operatingMode else { return selectedModelLabel }
        return "\(operatingMode.wrappedValue.displayName) · \(selectedModelLabel)"
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
                "Apple Intelligence Tools",
                "GPT-5.4 Thinking",
                "GPT-5.4 Pro",
                "Gemini 2.5 Pro Tools",
                "Qwen 35B Thinking",
            ],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var modeDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: displayedOperatingModes.map(\.displayName),
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var modelDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: [
                "Apple Intelligence",
                "GPT-5.4",
                "Qwen 34B",
                "DeepSeek R1 7B",
                "Auto Route",
            ],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var effortDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: ["Standard", "Extended", "Extra High", "Heavy", "Max"],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var nativeControlsDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: ["OpenAI", "Claude", "Google"],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var buttonSystemImage: String {
        if isTemporaryChatEnabled?.wrappedValue == true {
            return "eye.slash.fill"
        }
        if currentRuntimeNeedsSetup {
            return "exclamationmark.triangle"
        }
        if let operatingMode {
            return operatingMode.wrappedValue.systemImage
        }
        if usesAutomaticCloudRoute {
            return "arrow.triangle.branch"
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

    private var modelButtonTitle: String {
        if currentRuntimeNeedsSetup {
            return "Set Up Model"
        }
        return currentRouteDescription?.headline ?? labelText
    }

    private var modelButtonSystemImage: String {
        if currentRuntimeNeedsSetup {
            return "exclamationmark.triangle"
        }
        return currentRouteDescription?.systemImage ?? buttonSystemImage
    }

    private var routeButtonTitle: String {
        if currentRuntimeNeedsSetup {
            return "No Model"
        }
        guard let route = currentRouteDescription else { return "Routing" }
        if route.usesAutomaticRouting {
            return "Auto Route"
        }
        switch route.selection {
        case .cloud:
            return "Cloud Route"
        case .appleIntelligence, .localMLX:
            return "Local Route"
        }
    }

    private var effortButtonTitle: String {
        guard let currentOperatingMode else { return "Effort" }
        return inference.reasoningTierLabel(
            for: currentDisplayedReasoningTier,
            operatingMode: currentOperatingMode
        )
    }

    private var nativeControlsButtonTitle: String {
        guard let provider = currentEffectiveCloudModel?.provider else { return "Native" }
        return inference.runtimeControlTitle(for: provider)
    }

    private var nativeControlsButtonSystemImage: String {
        currentEffectiveCloudModel?.provider.systemImage ?? "slider.horizontal.3"
    }

    private var selectedModeSummary: String {
        if currentRuntimeNeedsSetup {
            return runtimeSetupSummary
        }
        if let operatingMode {
            return inference.chatSurfaceRouteDescription(for: operatingMode.wrappedValue).summary
        }
        if usesAutomaticCloudRoute {
            return automaticRouteSummary
        }
        return "Choose the model that should power this surface."
    }

    private var noLocalModelsText: String {
        if inference.releaseHiddenInstalledLocalTextModelCount > 0 {
            return "\(inference.releaseHiddenInstalledLocalTextModelCount) installed local model\(inference.releaseHiddenInstalledLocalTextModelCount == 1 ? " is" : "s are") hidden from the release picker because they are not release-ready yet."
        }
        return inference.appleIntelligenceAvailable
            ? "Apple Intelligence is available, but the prepared or installed local runtime becomes the primary path as soon as it is ready."
            : "No supported local runtimes are available yet."
    }

    private var localModelSubtitleInputsFingerprint: String {
        let visibleModelIDs = (installedSelectableModels + installableSelectableModels)
            .map(\.id)
            .sorted()
            .joined(separator: ",")
        let preparedOrInstalledIDs = inference.installedLocalTextModelIDs
            .union(inference.preparedLocalTextModelIDs)
            .sorted()
            .joined(separator: ",")
        return "\(visibleModelIDs)|\(preparedOrInstalledIDs)"
    }

    private var qwen3UnifiedPickerPairAvailableForSubtitles: Bool {
        let preparedOrInstalledIDs = inference.installedLocalTextModelIDs
            .union(inference.preparedLocalTextModelIDs)
        return preparedOrInstalledIDs.contains(LocalTextModelID.qwen3_4B4Bit.rawValue)
            && preparedOrInstalledIDs.contains(LocalTextModelID.qwen3_4BThinking25074Bit.rawValue)
    }

    @MainActor
    private func sanitizeReleaseLocalSelectionIfNeeded() {
        guard case .localMLX(let modelID) = inference.preferredChatModelSelection,
              let model = LocalTextModelID(rawValue: modelID),
              !model.isReleaseValidatedForInteractiveChat,
              let fallback = inference.releaseSelectableInstalledLocalTextModelIDs.first else {
            return
        }
        inference.setPreferredChatModelSelection(.localMLX(fallback))
    }

    @MainActor
    private func syncReasoningTierToDisplayedModeIfNeeded() {
        guard let currentOperatingMode else { return }
        let sanitized = inference.sanitizedReasoningTier(
            inference.chatReasoningTier,
            for: currentOperatingMode
        )
        guard sanitized != inference.chatReasoningTier else { return }
        inference.setChatReasoningTier(sanitized, for: currentOperatingMode)
    }

    @MainActor
    private func syncModelPickerDisclosureState() {
        switch selectedMenuItem {
        case .appleIntelligence, .inProcess:
            showsLocalModels = true
            showsCloudProviderOptions = false
            showsActiveCloudModelOptions = false
        case .cloud:
            showsLocalModels = false
            showsCloudProviderOptions = true
            showsActiveCloudModelOptions = true
        case nil:
            showsLocalModels = false
            showsCloudProviderOptions = false
            showsActiveCloudModelOptions = false
        }
    }

    @MainActor
    private func refreshLocalModelSubtitleCache() {
        let qwen3UnifiedPickerPairAvailable = qwen3UnifiedPickerPairAvailableForSubtitles
        var subtitles: [String: String] = [:]
        for model in installedSelectableModels + installableSelectableModels {
            subtitles[model.id] = Self.staticLocalModelSubtitle(
                for: model,
                qwen3UnifiedPickerPairAvailable: qwen3UnifiedPickerPairAvailable
            )
        }
        localModelSubtitleCache = subtitles
    }

    private var displayedOperatingModes: [EpistemosOperatingMode] {
        let modes = availableOperatingModes ?? inference.availableOperatingModes
        return modes.isEmpty ? [.fast] : modes
    }

    private func sanitizedDisplayedOperatingMode(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        guard displayedOperatingModes.contains(mode) else {
            return displayedOperatingModes.first ?? .fast
        }
        return mode
    }

    private func popoverBinding(_ popover: SplitToolbarPopover) -> Binding<Bool> {
        Binding(
            get: { activeSplitPopover == popover },
            set: { isPresented in
                activeSplitPopover = isPresented ? popover : nil
            }
        )
    }

    var body: some View {
        Group {
            if overrideTitle != nil {
                titleLabel
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .help(labelText)
                    .accessibilityLabel(labelText)
            } else if usesSplitToolbarControls {
                splitToolbarControls
            } else {
                // When the surface opted out of split toolbar controls
                // (mini/note/graph chat), size the single popover button to
                // fit the actual label rather than reserving worst-case
                // "Apple Intelligence Agent" width. The stable-width
                // reservation still applies when a split-toolbar caller
                // falls through this branch (e.g. via `overrideTitle`).
                let usesCompactNaturalWidth = operatingMode != nil
                    && overrideTitle == nil
                    && !preferSplitToolbarControls
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
                    stableWidth: usesCompactNaturalWidth ? nil : disclosureWidth
                ) {
                    runtimePopover
                }
                .fixedSize()
            }
        }
        .task(id: inference.preferredChatModelSelection.rawValue) {
            sanitizeReleaseLocalSelectionIfNeeded()
            syncModelPickerDisclosureState()
        }
        .task(id: currentOperatingMode?.rawValue ?? "none") {
            syncReasoningTierToDisplayedModeIfNeeded()
        }
        .task(id: activeSplitPopover == .model) {
            guard activeSplitPopover == .model else { return }
            syncModelPickerDisclosureState()
        }
        .task(id: localModelSubtitleInputsFingerprint) {
            refreshLocalModelSubtitleCache()
        }
    }

    @ViewBuilder
    private var splitToolbarControls: some View {
        HStack(spacing: 6) {
            if let operatingMode = currentOperatingMode {
                AnchoredPopoverButton(
                    title: operatingMode.displayName,
                    systemImage: operatingMode.systemImage,
                    isPresented: popoverBinding(.mode),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: operatingMode.helpText,
                    accessibilityLabel: "\(operatingMode.displayName) mode",
                    idealPopoverWidth: variant == .toolbar ? 300 : 320,
                    contentPadding: 12,
                    stableWidth: modeDisclosureWidth
                ) {
                    modePopover
                }
                .fixedSize()
            }

            AnchoredPopoverButton(
                title: modelButtonTitle,
                systemImage: modelButtonSystemImage,
                isPresented: popoverBinding(.model),
                isActive: false,
                variant: variant,
                showsLabelWhenCollapsed: true,
                helpText: selectedModeSummary,
                accessibilityLabel: "\(modelButtonTitle) model",
                idealPopoverWidth: variant == .toolbar ? 340 : 360,
                contentPadding: 12,
                stableWidth: modelDisclosureWidth
            ) {
                modelPopover
            }
            .fixedSize()

            AnchoredPopoverButton(
                title: routeButtonTitle,
                systemImage: "arrow.triangle.branch",
                isPresented: popoverBinding(.routing),
                isActive: false,
                variant: variant,
                showsLabelWhenCollapsed: false,
                helpText: selectedModeSummary,
                accessibilityLabel: routeButtonTitle,
                idealPopoverWidth: variant == .toolbar ? 340 : 360,
                contentPadding: 12
            ) {
                routingPopover
            }
            .fixedSize()

            if supportsRuntimeEffortButton {
                AnchoredPopoverButton(
                    title: effortButtonTitle,
                    systemImage: "slider.horizontal.3",
                    isPresented: popoverBinding(.effort),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: "Adjust model-native reasoning effort for this mode.",
                    accessibilityLabel: "\(effortButtonTitle) effort",
                    idealPopoverWidth: variant == .toolbar ? 280 : 300,
                    contentPadding: 12,
                    stableWidth: effortDisclosureWidth
                ) {
                    effortPopover
                }
                .fixedSize()
            }

            if supportsProviderNativeControlsButton {
                AnchoredPopoverButton(
                    title: nativeControlsButtonTitle,
                    systemImage: nativeControlsButtonSystemImage,
                    isPresented: popoverBinding(.nativeControls),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: "Provider-native controls for the current cloud model.",
                    accessibilityLabel: "\(nativeControlsButtonTitle) controls",
                    idealPopoverWidth: variant == .toolbar ? 320 : 340,
                    contentPadding: 12,
                    stableWidth: nativeControlsDisclosureWidth
                ) {
                    nativeControlsPopover
                }
                .fixedSize()
            }

            if isTemporaryChatEnabled != nil {
                temporaryChatButton
            }

            settingsButton
        }
    }

    @ViewBuilder
    private var modePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let operatingMode = currentOperatingMode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mode")
                        .font(.system(size: 13, weight: .semibold))
                    Text(operatingMode.helpText)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(displayedOperatingModes, id: \.rawValue) { option in
                    selectionRow(
                        title: option.displayName,
                        subtitle: modeSubtitle(for: option, isEnabled: true),
                        systemImage: option.systemImage,
                        isSelected: currentOperatingMode == option,
                        isEnabled: true
                    ) {
                        if let operatingMode {
                            let sanitizedMode = sanitizedDisplayedOperatingMode(option)
                            operatingMode.wrappedValue = sanitizedMode
                            inference.setChatReasoningTier(
                                inference.chatReasoningTier,
                                for: sanitizedMode
                            )
                        }
                        activeSplitPopover = nil
                    }
                }
            }
        }
        .animation(
            .easeInOut(duration: 0.15),
            value: displayedOperatingModes.map(\.rawValue).joined(separator: "|")
        )
    }

    @ViewBuilder
    private var modelPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    popoverSectionTitle("Models")
                    localModelsDisclosure(closeAction: {
                        activeSplitPopover = nil
                    })

                    pickerCloudSection
                }

            }
        }
        .frame(width: 320, height: 380, alignment: .topLeading)
        .popover(item: $aboutSelection) { selection in
            ModelAboutSheet(selection: selection)
        }
    }

    @ViewBuilder
    private var routingPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Routing")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                routingSection
            }
        }
    }

    @ViewBuilder
    private var effortPopover: some View {
        if let currentOperatingMode,
           let model = currentEffectiveCloudModel {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reasoning Effort")
                        .font(.system(size: 13, weight: .semibold))
                    Text(
                        "\(inference.runtimeProviderDisplayName(for: model.provider)) controls for \(currentOperatingMode.displayName) mode."
                    )
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(inference.availableReasoningTiers(for: currentOperatingMode), id: \.self) { tier in
                        selectionRow(
                            title: inference.reasoningTierLabel(
                                for: tier,
                                operatingMode: currentOperatingMode
                            ),
                            subtitle: tier.summary,
                            systemImage: currentOperatingMode.systemImage,
                            isSelected: currentDisplayedReasoningTier == tier,
                            isEnabled: true
                        ) {
                            inference.setChatReasoningTier(tier, for: currentOperatingMode)
                            activeSplitPopover = nil
                        }
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var nativeControlsPopover: some View {
        if let model = currentEffectiveCloudModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(nativeControlsButtonTitle) Controls")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Provider-native options for \(model.displayName).")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }

                    providerNativeControls(for: model)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var temporaryChatButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: isTemporaryChatEnabled?.wrappedValue == true ? "eye.slash.fill" : "eye.slash",
            variant: variant,
            role: .toolbarUtility,
            isActive: isTemporaryChatEnabled?.wrappedValue == true,
            helpText: isTemporaryChatEnabled?.wrappedValue == true
                ? "Temporary chat is on"
                : "Temporary chat is off",
            accessibilityLabel: "Temporary chat"
        ) {
            isTemporaryChatEnabled?.wrappedValue.toggle()
        }
    }

    @ViewBuilder
    private func providerNativeControls(for model: CloudTextModelID) -> some View {
        switch model.provider {
        case .openAI:
            VStack(alignment: .leading, spacing: 10) {
                if model.supportsNativeReasoningEffortControl,
                   let currentOperatingMode,
                   !inference.availableReasoningTiers(for: currentOperatingMode).isEmpty {
                    SettingsDescriptionText(
                        text: "Use the Effort button for Low, Medium, High, or Extra High Codex effort. OpenAI tool toggles live here."
                    )
                }
                Toggle(
                    "Enable Web Search",
                    isOn: Binding(
                        get: { inference.openAIWebSearchEnabled },
                        set: { inference.setOpenAIWebSearchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Code Interpreter",
                    isOn: Binding(
                        get: { inference.openAICodeInterpreterEnabled },
                        set: { inference.setOpenAICodeInterpreterEnabled($0) }
                    )
                )
            }

        case .anthropic:
            VStack(alignment: .leading, spacing: 10) {
                if model.supportsNativeReasoningEffortControl {
                    SettingsDescriptionText(
                        text: "Use the Effort button for Low, Medium, High, or Max adaptive thinking effort. Adaptive Thinking can still be disabled entirely for Anthropic chat turns."
                    )
                }
                if !model.nativeReasoningModes.isEmpty {
                    Toggle(
                        "Enable Adaptive Thinking",
                        isOn: Binding(
                            get: { inference.anthropicAdaptiveThinkingEnabled },
                            set: { inference.setAnthropicAdaptiveThinkingEnabled($0) }
                        )
                    )
                }
                Toggle(
                    "Enable Web Search",
                    isOn: Binding(
                        get: { inference.anthropicWebSearchEnabled },
                        set: { inference.setAnthropicWebSearchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Web Fetch (single URL)",
                    isOn: Binding(
                        get: { inference.anthropicWebFetchEnabled },
                        set: { inference.setAnthropicWebFetchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Code Execution (Python sandbox)",
                    isOn: Binding(
                        get: { inference.anthropicCodeExecutionEnabled },
                        set: { inference.setAnthropicCodeExecutionEnabled($0) }
                    )
                )
            }

        case .google:
            VStack(alignment: .leading, spacing: 10) {
                if model.supportsNativeReasoningEffortControl,
                   let currentOperatingMode,
                   !inference.availableReasoningTiers(for: currentOperatingMode).isEmpty {
                    SettingsDescriptionText(
                        text: "Use the Effort button for \(currentOperatingMode.displayName.lowercased()) thinking depth. Grounding lives here."
                    )
                }
                Toggle(
                    "Enable Grounding with Google Search",
                    isOn: Binding(
                        get: { inference.googleGroundingEnabled },
                        set: { inference.setGoogleGroundingEnabled($0) }
                    )
                )
            }

        case .zai, .kimi, .minimax, .deepseek:
            EmptyView()
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "gearshape",
            variant: variant,
            role: .toolbarUtility,
            isActive: false,
            helpText: "Open AI settings",
            accessibilityLabel: "AI settings"
        ) {
            openSettings()
            activeSplitPopover = nil
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
                        ForEach(displayedOperatingModes, id: \.rawValue) { option in
                            selectionRow(
                                title: option.displayName,
                                subtitle: modeSubtitle(for: option, isEnabled: true),
                                systemImage: option.systemImage,
                                isSelected: operatingMode.wrappedValue == option,
                                isEnabled: true
                            ) {
                                let sanitizedMode = sanitizedDisplayedOperatingMode(option)
                                operatingMode.wrappedValue = sanitizedMode
                                inference.setChatReasoningTier(
                                    inference.chatReasoningTier,
                                    for: sanitizedMode
                                )
                                isPresented = false
                            }
                        }
                    }
                    .animation(
                        .easeInOut(duration: 0.15),
                        value: displayedOperatingModes.map(\.rawValue).joined(separator: "|")
                    )
                }

                routingSection

                VStack(alignment: .leading, spacing: 8) {
                    popoverSectionTitle("Models")
                    localModelsDisclosure(closeAction: {
                        isPresented = false
                    })

                    // Cloud section — drastically simplified. Picker shows
                    // ONE cloud row (the user's preferred cloud model),
                    // never the full multi-provider + multi-model catalog.
                    // To change which cloud model is preferred, users go
                    // to Settings → Inference. Two things only here:
                    //   1. A single selectable row for the preferred cloud
                    //      model (tap to switch the next turn to cloud)
                    //   2. A "Change in Settings" link
                    // If no cloud provider is configured, show a compact
                    // hint linking to setup.
                    pickerCloudSection
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
        .popover(item: $aboutSelection) { selection in
            ModelAboutSheet(selection: selection)
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

    private var localModelsDisclosureSubtitle: String {
        if installableSelectableModels.isEmpty {
            return installedSelectableModels.isEmpty
                ? "On-device"
                : "\(installedSelectableModels.count) installed"
        }
        return "\(installedSelectableModels.count) installed • \(installableSelectableModels.count) available"
    }

    @ViewBuilder
    private func localModelsDisclosure(
        closeAction: @escaping () -> Void
    ) -> some View {
        DisclosureGroup(
            isExpanded: $showsLocalModels,
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    localModelRows(closeAction: closeAction)
                }
            },
            label: {
                disclosureTitle(
                    title: "Local Models",
                    subtitle: localModelsDisclosureSubtitle
                )
            }
        )
    }

    @ViewBuilder
    private func localModelRows(
        closeAction: @escaping () -> Void
    ) -> some View {
        if inference.appleIntelligenceAvailable {
            selectionRow(
                title: "Apple Intelligence",
                subtitle: "Optional Apple on-device runtime for simple fallback work.",
                systemImage: "apple.intelligence",
                isSelected: selectedMenuItem == .appleIntelligence
            ) {
                inference.setPreferredChatModelSelection(.appleIntelligence)
                closeAction()
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
                HStack(spacing: 0) {
                    selectionRow(
                        title: inference.localModelPickerDisplayName(for: model.id),
                        subtitle: localModelSubtitle(for: model),
                        systemImage: "memorychip",
                        isSelected: selectedMenuItem == .inProcess(model)
                    ) {
                        inference.setPreferredChatModelSelection(.localMLX(model.id))
                        closeAction()
                    }

                    Button {
                        aboutSelection = .localMLX(model.id)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Model details")
                }
            }
        }

        if !installableSelectableModels.isEmpty {
            Divider()
                .padding(.vertical, 4)

            ForEach(installableSelectableModels, id: \.id) { model in
                selectionRow(
                    title: inference.localModelPickerDisplayName(for: model.id),
                    subtitle: "Available to install • \(localModelSubtitle(for: model))",
                    systemImage: "arrow.down.circle",
                    isSelected: false
                ) {
                    openSettings()
                    closeAction()
                }
            }
        }
    }

    @ViewBuilder
    private var cloudProviderSelectionRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(CloudModelProvider.preferredOrder, id: \.rawValue) { provider in
                let selection = AIProviderSelection(cloudProvider: provider)
                selectionRow(
                    title: provider.displayName,
                    subtitle: providerSelectionSubtitle(for: provider),
                    systemImage: provider.systemImage,
                    isSelected: displayedCloudProvider == provider
                ) {
                    inference.setCloudModelsEnabled(true)
                    inference.setActiveAIProvider(selection)
                }
            }

            selectionRow(
                title: "Local Only",
                subtitle: "Keep chat on-device. Auto-route can only escalate again after you reactivate a cloud workspace.",
                systemImage: "memorychip",
                isSelected: inference.activeAIProvider == .localOnly && displayedCloudProvider == nil
            ) {
                inference.setChatAutoRouteToCloud(false)
                inference.setActiveAIProvider(.localOnly)
            }
        }
    }

    @ViewBuilder
    private var routingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            popoverSectionTitle("Routing")

            if let operatingMode {
                routeSummaryCard(for: inference.chatSurfaceRouteDescription(for: operatingMode.wrappedValue))
            }

            Toggle(isOn: Binding(
                get: { inference.cloudAutoFallback },
                set: { inference.setCloudAutoFallback($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fallback on failure")
                    Text("If the chosen cloud model errors, try the fallback chain instead of surfacing the first failure immediately.")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func routeSummaryCard(for route: ChatSurfaceRouteDescription) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: route.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 14, height: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(route.operatingMode.displayName) -> \(route.headline)")
                    .font(.system(size: 12, weight: .semibold))
                Text(route.summary)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.muted.opacity(theme.isDark ? 0.28 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border.opacity(0.45), lineWidth: 0.6)
        )
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
            case .pro:
                return "This model does not expose a verified pro-grade cloud route."
            case .agent:
                return "This model cannot run the current visible tools/runtime path."
            case .fast:
                return option.helpText
            }
        }
        return option.helpText
    }

    private func localModelSubtitle(for model: LocalModelDescriptor) -> String {
        localModelSubtitleCache[model.id] ?? Self.staticLocalModelSubtitle(
            for: model,
            qwen3UnifiedPickerPairAvailable: false
        )
    }

    private static func staticLocalModelSubtitle(
        for model: LocalModelDescriptor,
        qwen3UnifiedPickerPairAvailable: Bool
    ) -> String {
        guard let modelID = LocalTextModelID(rawValue: model.id) else {
            return "On-device model"
        }

        var features: [String] = []
        let supportsThinking = modelID.supportsThinkingMode
            || (qwen3UnifiedPickerPairAvailable && modelID == .qwen3_4B4Bit)
        if supportsThinking {
            features.append("Thinking")
        }
        if modelID.canRunLocalAgentLoop {
            features.append("Tools")
        }
        let featureSummary = features.isEmpty ? "Fast only" : features.joined(separator: " • ")
        return "\(featureSummary) • Chat \(modelID.minimumRecommendedInteractiveMemoryGB) GB+"
    }

    private func providerSelectionSubtitle(for provider: CloudModelProvider) -> String {
        let status = inference.configuredCloudProviders.contains(provider)
            ? inference.cloudValidationState(for: provider).statusBadge
            : (provider.supportsAccountConnection ? "Account setup" : "API key setup")
        return "\(provider.modelSummary) • \(status)"
    }

    private func cloudModelSubtitle(for model: CloudTextModelID) -> String {
        let provider = model.provider
        let routeSummary = inference.chatAutoRouteToCloud
            ? "Used when the stack escalates"
            : "Runs directly when selected"
        let configuration = inference.configuredCloudProviders.contains(provider)
            ? "Ready"
            : "Finish setup"
        return "\(provider.displayName) • \(routeSummary) • \(configuration)"
    }

    /// Cloud provider + model controls rendered in the runtime popover.
    /// When auto-route is on, choosing a cloud model configures the
    /// escalation target without forcing the current chat off local.
    @ViewBuilder
    private var pickerCloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            popoverSectionTitle("Cloud")

            if inference.isCloudPickBlockedByFocus {
                // AR4 (Wave 14 Focus filters) — surface the
                // `forceLocalModelsOnly` axis so the user knows their
                // active Focus is suppressing cloud picks; the actual
                // collapse to local happens in `setPreferredChatModelSelection`.
                Label("Focus: Local-only — cloud picks fall back to local",
                      systemImage: "moon.zzz")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(theme.textSecondary.opacity(0.06), in: Capsule())
            }

            DisclosureGroup(
                isExpanded: $showsCloudProviderOptions,
                content: { cloudProviderSelectionRows },
                label: {
                    disclosureTitle(
                        title: "Cloud Provider",
                        subtitle: cloudProviderDisclosureSubtitle
                    )
                }
            )

            if let provider = displayedCloudProvider,
               inference.configuredCloudProviders.contains(provider) {
                DisclosureGroup(
                    isExpanded: $showsActiveCloudModelOptions,
                    content: {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(inference.cloudModels(for: provider), id: \.rawValue) { model in
                                selectionRow(
                                    title: model.displayName,
                                    subtitle: cloudModelSubtitle(for: model),
                                    systemImage: provider.systemImage,
                                    isSelected: isCloudModelSelected(model)
                                ) {
                                    // Always commit the user's explicit pick to
                                    // `preferredChatModelSelection` so the next
                                    // turn actually routes to this cloud model.
                                    // Previously the auto-route branch only
                                    // updated `preferredCloudModel` (the
                                    // auto-route default), leaving the chat
                                    // primary on whatever local model the user
                                    // had previously selected — that's the
                                    // "I picked GPT-5.4 but got DeepSeek R1 7B
                                    // memory error" regression users hit on
                                    // 2026-04-20. Also refresh the
                                    // auto-route cloud preference so the
                                    // chosen model is the fallback when the
                                    // user later switches back to local.
                                    inference.setCloudModelsEnabled(true)
                                    inference.setPreferredCloudModel(model)
                                    inference.setPreferredChatModelSelection(.cloud(model))
                                    isPresented = false
                                }
                            }
                        }
                    },
                    label: {
                        disclosureTitle(
                            title: "Cloud Model",
                            subtitle: cloudAccessSubtitle
                        )
                    }
                )
            } else {
                Text("Connect a cloud provider in Settings → Inference to give the chat stack a cloud escalation path.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, 4)
            }

        }
    }

    private func isCloudModelSelected(_ model: CloudTextModelID) -> Bool {
        if inference.chatAutoRouteToCloud {
            return inference.preferredCloudModel(for: model.provider) == model
        }
        return selectedMenuItem == .cloud(model)
    }

    private var cloudAccessSubtitle: String {
        guard let provider = displayedCloudProvider else {
            return "Local Only"
        }
        let preferredModel = inference.preferredCloudModel(for: provider)
        let validation = inference.cloudValidationState(for: provider)
        if inference.configuredCloudProviders.contains(provider) {
            return "\(preferredModel.compactDisplayName) • \(validation.statusBadge)"
        }
        return "Finish setup to unlock"
    }

    private var cloudProviderDisclosureSubtitle: String {
        guard let provider = displayedCloudProvider else {
            return "Choose a provider"
        }
        if inference.configuredCloudProviders.contains(provider) {
            return "\(provider.displayName) • Active stack"
        }
        if provider.supportsAccountConnection {
            return "\(provider.displayName) • Account first"
        }
        return "\(provider.displayName) • API key"
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
    @State private var isVaultDisconnectAuthorizationInFlight = false

    let issue: VaultRecoveryIssue
    let isRecovering: Bool
    let rebuildAction: () -> Void
    let chooseVaultAction: () -> Void
    let disconnectAction: () -> Void

    private func requestVaultDisconnectAuthorization() {
        guard !isVaultDisconnectAuthorizationInFlight else { return }

        let target = RootViewDestructiveActionSovereignGate.Target.vaultDisconnect
        isVaultDisconnectAuthorizationInFlight = true

        Task { @MainActor in
            defer { isVaultDisconnectAuthorizationInFlight = false }

            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                RootViewDestructiveActionSovereignGate.requirement(for: target),
                reason: RootViewDestructiveActionSovereignGate.reason(for: target)
            ) ?? .denied(.authenticationFailed)

            guard outcome == .allowed else { return }

            disconnectAction()
        }
    }

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
                        requestVaultDisconnectAuthorization()
                    }
                    .disabled(isRecovering || isVaultDisconnectAuthorizationInFlight)
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

private enum RuntimeAuditRootFlags {
    static let rootShellMinimalContentKey = "EPI_HOME_WINDOW_ROOT_SHELL_MINIMAL_CONTENT"

    static var rootShellMinimalContentEnabled: Bool {
        ProcessInfo.processInfo.environment[rootShellMinimalContentKey] == "1"
    }
}

private struct AuditRootShellMinimalContentView: View {
    var body: some View {
        VStack {
            Button("test") {
                RuntimeDiagnostics.recordLifecycleEvent("root_shell_button_pressed")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentRouter: View {
    var body: some View {
        if RuntimeAuditRootFlags.rootShellMinimalContentEnabled {
            AuditRootShellMinimalContentView()
        } else {
            HomeRouter()
        }
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

                let safeDelay = delay.isFinite ? max(0, delay) : 0
                try? await Task.sleep(for: .milliseconds(Int(safeDelay)))
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

private struct RootWindowLifecycle: ViewModifier {
    let ui: UIState

    func body(content: Content) -> some View {
        content
            .onAppear {
                updateWindowOcclusion()
                Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(150))
                    } catch {
                        return
                    }
                    updateWindowOcclusion()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                updateWindowOcclusion()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                updateWindowOcclusion()
            }
    }

    private func updateWindowOcclusion(window: NSWindow? = nil) {
        let homeWindow = window ?? NSApp.windows.first(where: HomeWindowIdentity.matches)
        guard let homeWindow else {
            ui.windowOccluded = true
            return
        }
        ui.windowOccluded = !NSApp.isActive
            || !homeWindow.isVisible
            || homeWindow.isMiniaturized
            || !homeWindow.isKeyWindow
    }
}

private struct RootWorkspaceEvents: ViewModifier {
    @Binding var showWorkspaceSwitcher: Bool
    @Binding var showSessionIntelligence: Bool
    @Binding var showTimeMachine: Bool

    func body(content: Content) -> some View {
        content
            .overlay { workspaceOverlays }
            .background { workspaceKeyboardShortcuts }
            .onKeyPress(.escape, action: handleEscapeKeyPress)
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
    }

    private func handleEscapeKeyPress() -> KeyPress.Result {
        if showWorkspaceSwitcher { showWorkspaceSwitcher = false; return .handled }
        if showSessionIntelligence { showSessionIntelligence = false; return .handled }
        if showTimeMachine { showTimeMachine = false; return .handled }
        return .ignored
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
}
