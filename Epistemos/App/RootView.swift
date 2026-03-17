import SwiftData
import SwiftUI

enum LandingToolbarGlyphs {
    static let greetingSymbol = "textformat"

    static func cursorSymbol(animationEnabled: Bool) -> String {
        animationEnabled ? "cursorarrow.motionlines" : "cursorarrow"
    }
}

// MARK: - Root View
// Top-level container with centered toolbar controls.
// System Liquid Glass toolbar provides the chrome — no custom glass needed.

struct RootView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(InferenceState.self) private var inference
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    /// Set by EpistemosApp when AppBootstrap detected a database error.
    var databaseError: Error?
    /// Callback to reset database and relaunch.
    var onResetDatabase: (() -> Void)?

    @State private var appearanceObserver = SystemAppearanceObserver()
    @State private var showDatabaseAlert = false
    @State private var showLandingCursorControls = false
    @State private var showLandingGreetingControls = false

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

    private var availableProviders: [LLMProviderType] {
        var providers: [LLMProviderType] = [.anthropic, .openai, .google, .kimi]
        if inference.ollamaAvailable { providers.append(.ollama) }
        return providers
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
            // Background wallpaper (theme-dependent)
            WallpaperView()

            ContentRouter()
        }
        // Drive preferred color scheme from the resolved theme.
        // This ensures Ember/OLED/Sunset stay dark even when system is in light mode.
        .preferredColorScheme(ui.preferredColorScheme)
        // Wire the appearance observer — fires on real OS dark/light toggle.
        .onAppear {
            appearanceObserver.onAppearanceChange = { @MainActor isDark in
                ui.isSystemDark = isDark
            }
            appearanceObserver.start()

            // Restore vault from saved bookmark (requires NSApp to be alive)
            vaultSync.restoreVaultFromBookmark()
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
            ToolbarItem(placement: .navigation) {
                if ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding {
                    Button {
                        chat.goHome()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityLabel("Back to Home")
                    .help("Back to Home")
                }
            }
            ToolbarItem(placement: .principal) {
                rootToolbarControls
            }
            .sharedBackgroundVisibility(
                (ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding)
                    ? .hidden : .automatic
            )
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
        // Command palette is now a global floating NSPanel (CommandPaletteWindowController).
        // Activated via Option+Space from any app.
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
            if let w = note.object as? NSWindow, w == NSApp.keyWindow || w.isMainWindow {
                ui.windowOccluded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification))
        { note in
            if let w = note.object as? NSWindow, w == NSApp.keyWindow || w.isMainWindow {
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

    private var rootToolbarControls: some View {
        HStack(spacing: 10) {
            settingsToolbarButton

            if showLandingToolbarControls {
                landingGreetingToolbarButton
                landingCursorToolbarButton
            }

            if activeHomeChat {
                modelToolbarButton
            }

            historyToolbarButton
        }
        .fixedSize()
    }

    private var settingsToolbarButton: some View {
        Button(action: openSettingsWindow) {
            Label("Settings", systemImage: "gearshape")
        }
        .accessibilityLabel("Settings")
        .help("Settings (⌘S)")
    }

    private var modelToolbarButton: some View {
        Menu {
            let models = inference.availableModels
            if !models.isEmpty {
                ForEach(models, id: \.id) { model in
                    Button {
                        inference.setActiveModel(model.id)
                    } label: {
                        HStack {
                            Text(model.name)
                            if model.id == inference.activeModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(model.id == inference.activeModel)
                }
                Divider()
            }

            Menu("Switch Provider") {
                ForEach(availableProviders, id: \.self) { provider in
                    Button {
                        inference.setApiProvider(provider)
                        if inference.needsApiKey && inference.apiKey.isEmpty {
                            ui.showToast("No API key for \(provider.displayName) — set it in Settings", type: .warning)
                        }
                    } label: {
                        Label(provider.displayName, systemImage: provider.iconName)
                    }
                    .disabled(provider == inference.apiProvider)
                }
            }
        } label: {
            ASCIIRippleText(
                text: "\(inference.apiProvider.displayName) · \(inference.activeModelDisplayName)",
                font: .system(size: 14, weight: .medium),
                color: .secondary
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func openSettingsWindow() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate()
    }

    private var landingCursorToolbarButton: some View {
        Button {
            showLandingCursorControls.toggle()
        } label: {
            Label("Cursor FX", systemImage: LandingToolbarGlyphs.cursorSymbol(animationEnabled: ui.landingCursorAnimationEnabled))
        }
        .accessibilityLabel(
            ui.landingCursorAnimationEnabled
                ? "Disable landing cursor animation"
                : "Enable landing cursor animation"
        )
        .help(
            ui.landingCursorAnimationEnabled
                ? "Adjust landing cursor animation"
                : "Landing cursor animation is off"
        )
        .popover(isPresented: $showLandingCursorControls) {
            LandingCursorControlsView()
                .frame(width: 320)
                .padding(16)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    private var landingGreetingToolbarButton: some View {
        Button {
            showLandingGreetingControls.toggle()
        } label: {
            Label("Greeting FX", systemImage: LandingToolbarGlyphs.greetingSymbol)
        }
        .accessibilityLabel(
            ui.landingGreetingTypewriterEnabled || ui.landingGreetingASCIIEnabled
                ? "Adjust landing greeting animation"
                : "Landing greeting animation is off"
        )
        .help(
            ui.landingGreetingTypewriterEnabled || ui.landingGreetingASCIIEnabled
                ? "Adjust landing greeting animation"
                : "Landing greeting animation is off"
        )
        .popover(isPresented: $showLandingGreetingControls) {
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
                    .transition(.opacity.combined(with: .blurReplace))
            } else {
                LandingView()
                    .transition(.opacity.combined(with: .blurReplace))
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
            Text("Greeting Animation")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Enable typewriter", isOn: $ui.landingGreetingTypewriterEnabled)
            if ui.landingGreetingTypewriterEnabled {
                Picker("Version", selection: $ui.landingGreetingTypewriterVersion) {
                    ForEach(LandingGreetingTypewriterVersion.allCases, id: \.self) { version in
                        Text(version.displayName).tag(version)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Toggle("Enable ASCII ripple", isOn: $ui.landingGreetingASCIIEnabled)
            if ui.landingGreetingASCIIEnabled {
                Toggle("ASCII on hover only", isOn: $ui.landingGreetingASCIIHoverEnabled)
                    .padding(.leading, 12)
                    .font(.system(size: 12))
            }

            LandingAnimationSliderRow(
                title: "ASCII intensity",
                value: $ui.landingGreetingIntensity,
                range: 0...1,
                labels: ("Calm", "Expressive")
            )

            LandingAnimationSliderRow(
                title: "Character variety",
                value: $ui.landingGreetingCharacterVariety,
                range: 0...1,
                labels: ("Focused", "Dense")
            )

            LandingAnimationSliderRow(
                title: "Typing pace",
                value: $ui.landingGreetingPace,
                range: 0...1,
                labels: ("Fast", "Calm")
            )

            Button("Reset Greeting Defaults") {
                ui.landingGreetingTypewriterEnabled = LandingGreetingAnimationPolicy.defaultTypewriterEnabled
                ui.landingGreetingASCIIEnabled = LandingGreetingAnimationPolicy.defaultASCIIEnabled
                ui.landingGreetingASCIIHoverEnabled = LandingGreetingAnimationPolicy.defaultASCIIHoverEnabled
                ui.landingGreetingTypewriterVersion = LandingGreetingAnimationPolicy.defaultTypewriterVersion
                ui.landingGreetingIntensity = LandingGreetingAnimationPolicy.defaultIntensity
                ui.landingGreetingCharacterVariety = LandingGreetingAnimationPolicy.defaultVariety
                ui.landingGreetingPace = LandingGreetingAnimationPolicy.defaultPace
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct LandingCursorControlsView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        VStack(alignment: .leading, spacing: 14) {
            Text("Cursor Animation")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Enable cursor animation", isOn: $ui.landingCursorAnimationEnabled)

            LandingAnimationSliderRow(
                title: "Response",
                value: $ui.landingCursorResponse,
                range: 0...1,
                labels: ("Heavy", "Snappy")
            )

            LandingAnimationSliderRow(
                title: "Spread",
                value: $ui.landingCursorSpread,
                range: 0...1,
                labels: ("Tight", "Wide")
            )

            LandingAnimationSliderRow(
                title: "Trail",
                value: $ui.landingCursorTrail,
                range: 0...1,
                labels: ("Short", "Long")
            )

            Button("Reset Cursor Defaults") {
                ui.landingCursorAnimationEnabled = LandingCursorAnimationPolicy.defaultValue
                ui.landingCursorResponse = LandingWakeFieldPolicy.defaultResponse
                ui.landingCursorSpread = LandingWakeFieldPolicy.defaultSpread
                ui.landingCursorTrail = LandingWakeFieldPolicy.defaultTrail
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct LandingAnimationSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let labels: (String, String)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int(round(value * 100)))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)

            HStack {
                Text(labels.0)
                Spacer()
                Text(labels.1)
            }
            .font(.system(size: 11, weight: .medium))
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
    @State private var cursorVisible = true
    @State private var typingDone = false
    @State private var buttonOpacity: Double = 0

    private var theme: EpistemosTheme { ui.theme }
    private let fullText = "Welcome to Epistemos..."
    private var retroFont: Font { AppDisplayTypography.font(size: 38) }

    var body: some View {
        ZStack {
            // Solid background
            theme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Typewriter greeting — RetroGaming font, same style as LiquidGreeting
                HStack(alignment: .center, spacing: 0) {
                    Text(displayText)
                        .font(retroFont)
                        .foregroundStyle(theme.fontAccent)
                        .fixedSize(horizontal: true, vertical: true)

                    // Block cursor
                    Rectangle()
                        .fill(theme.fontAccent.opacity(0.85))
                        .frame(width: 10, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .opacity(cursorVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: cursorVisible)
                        .padding(.leading, 2)
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
                Text("set up your API keys in Settings to get started")
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
                cursorVisible = false
                typingDone = true
                buttonOpacity = 1
                return
            }
            // Start cursor blink
            let blinkTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    cursorVisible.toggle()
                }
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

            // Keep blink alive until view disappears. withTaskCancellationHandler
            // ensures blinkTask is cancelled even if the parent .task is cancelled.
            await withTaskCancellationHandler {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                }
            } onCancel: {
                blinkTask.cancel()
            }
        }
    }
}
