import SwiftData
import SwiftUI

// MARK: - Root View
// Top-level container with system toolbar navigation.
// Segmented picker in .toolbar(.principal).
// System Liquid Glass toolbar provides the chrome — no custom glass needed.

struct RootView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(InferenceState.self) private var inference
    @Environment(VaultSyncService.self) private var vaultSync

    /// Set by EpistemosApp when AppBootstrap detected a database error.
    var databaseError: Error?
    /// Callback to reset database and relaunch.
    var onResetDatabase: (() -> Void)?

    @State private var appearanceObserver = SystemAppearanceObserver()
    /// Delayed flag — prevents toolbar glass from flashing during landing→chat transition.
    @State private var showToolbarGlass = false
    @State private var showDatabaseAlert = false

    var body: some View {
        ZStack {
            // Background wallpaper (theme-dependent)
            WallpaperView()

            // Main content — tab-switched panels
            ContentRouter(homeTab: ui.homeTab)
        }
        // Drive preferred color scheme from the resolved theme.
        // This ensures Ember/OLED/Sunset stay dark even when system is in light mode.
        .preferredColorScheme(ui.theme.colorScheme)
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
        .onChange(of: ui.theme) { _, _ in
            UtilityWindowManager.shared.syncTheme(isDark: ui.theme.isDark)
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
            // Principal: model label during active chat, pill picker otherwise
            ToolbarItem(placement: .principal) {
                PrincipalToolbarContent()
            }
            .sharedBackgroundVisibility(
                (ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding)
                    ? .hidden : .automatic
            )
            // Chat sidebar toggle — only on Home tab
            ToolbarItem(placement: .primaryAction) {
                if ui.homeTab == .home {
                    @Bindable var ui = ui
                    Button {
                        ui.toggleChatSidebar()
                    } label: {
                        Label("History", systemImage: "sidebar.left")
                    }
                    .accessibilityLabel("Chat History")
                    .help("Chat History (⇧⌘H)")
                    .popover(isPresented: $ui.showChatSidebar) {
                        ChatSidebarView()
                            .frame(width: 300, height: 500)
                            .preferredColorScheme(ui.theme.colorScheme)
                    }
                }
            }
        }
        .navigationTitle("")
        // Toolbar glass: hidden on home landing, visible for chat/library/settings.
        .toolbarBackgroundVisibility(
            showToolbarGlass ? .automatic : .hidden,
            for: .windowToolbar
        )
        .onChange(of: ui.homeTab) { _, tab in
            if tab != .home {
                showToolbarGlass = true
            } else if chat.showLanding || chat.messages.isEmpty {
                showToolbarGlass = false
            }
        }
        .onChange(of: !chat.messages.isEmpty) { _, hasMessages in
            guard ui.homeTab == .home else { return }
            if hasMessages && !chat.showLanding {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showToolbarGlass = true
                }
            } else {
                showToolbarGlass = false
            }
        }
        .onChange(of: chat.showLanding) { _, isLanding in
            guard ui.homeTab == .home else { return }
            if isLanding {
                showToolbarGlass = false
            } else if !chat.messages.isEmpty {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showToolbarGlass = true
                }
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
        // Activated via Option+Space from any app, or Cmd+S in-app.
        // Glass Box overlay removed — research runs in regular chat
        .frame(minWidth: 900, minHeight: 600)
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
}

// MARK: - Home Tab

enum HomeTab: String, CaseIterable {
    case home, library, settings

    var label: String {
        switch self {
        case .home: "Home"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .settings: "gear"
        }
    }
}

// MARK: - Principal Toolbar Content

private struct PrincipalToolbarContent: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(InferenceState.self) private var inference

    private var showModelLabel: Bool {
        ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding
    }

    private var availableProviders: [LLMProviderType] {
        var providers: [LLMProviderType] = [.anthropic, .openai, .google, .kimi]
        if inference.ollamaAvailable { providers.append(.ollama) }
        return providers
    }

    var body: some View {
        if showModelLabel {
            Menu {
                // Current provider's models
                let models = inference.availableModels
                if !models.isEmpty {
                    ForEach(models, id: \.id) { m in
                        Button {
                            inference.setActiveModel(m.id)
                        } label: {
                            HStack {
                                Text(m.name)
                                if m.id == inference.activeModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(m.id == inference.activeModel)
                    }
                    Divider()
                }

                // Switch provider
                Menu("Switch Provider") {
                    ForEach(availableProviders, id: \.self) { p in
                        Button {
                            inference.setApiProvider(p)
                            if inference.needsApiKey && inference.apiKey.isEmpty {
                                ui.showToast("No API key for \(p.displayName) — set it in Settings", type: .warning)
                            }
                        } label: {
                            Label(p.displayName, systemImage: p.iconName)
                        }
                        .disabled(p == inference.apiProvider)
                    }
                }
            } label: {
                Text("\(inference.apiProvider.displayName) · \(inference.activeModelDisplayName)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            @Bindable var uiBindable = ui
            Picker("", selection: $uiBindable.homeTab) {
                ForEach(HomeTab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 108)
        }
    }
}

// MARK: - Content Router
// Main window content — switches between Home, Library, and Settings.

struct ContentRouter: View {
    var homeTab: HomeTab

    var body: some View {
        switch homeTab {
        case .home:
            HomeRouter()
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
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
        ui.theme.background
            .ignoresSafeArea()
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
    private var retroFont: Font { .custom("RetroGaming", size: 38) }

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
                        .font(.custom("RetroGaming", size: 14))
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
