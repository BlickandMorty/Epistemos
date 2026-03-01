import SwiftData
import SwiftUI

// MARK: - Root View
// Top-level container with system toolbar navigation.
// Segmented picker in .toolbar(.principal).
// System Liquid Glass toolbar provides the chrome — no custom glass needed.

struct RootView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
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

            // Main content — lazy panels, instant swap
            ContentRouter()
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
            // Back button — only during active chat
            ToolbarItem(placement: .navigation) {
                if ui.activePanel == .home && !chat.messages.isEmpty && !chat.showLanding {
                    Button {
                        chat.goHome()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityLabel("Back to Home")
                    .help("Back to Home")
                }
            }
            // Chat sidebar toggle — always visible on Home panel
            ToolbarItem(placement: .primaryAction) {
                if ui.activePanel == .home {
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
        // Toolbar glass: hidden on landing, visible during active chat.
        // Uses delayed flag to prevent flash during landing→chat transition.
        .toolbarBackgroundVisibility(
            showToolbarGlass ? .automatic : .hidden,
            for: .windowToolbar
        )
        .onChange(of: !chat.messages.isEmpty) { _, hasMessages in
            if hasMessages && !chat.showLanding {
                // Delay showing glass until the transition animation completes
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showToolbarGlass = true
                }
            } else {
                showToolbarGlass = false
            }
        }
        .onChange(of: chat.showLanding) { _, isLanding in
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
        .overlay {
            if ui.breatheActive {
                BreatheOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: ui.breatheActive)
        // Global command palette — Spotlight-style overlay from any panel via Cmd+S
        .overlay {
            if ui.isCommandPaletteVisible {
                // Dismiss backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { ui.dismissCommandPalette() }

                CommandPaletteOverlay()
                    .frame(width: 560, height: 400)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(Motion.smooth, value: ui.isCommandPaletteVisible)
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

// MARK: - Content Router
// Main window content — Home (chat/landing) only.
// Notes, Library, and Research Hub are separate windows via UtilityWindowManager.

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
        ui.theme.background
            .ignoresSafeArea()
    }
}

// MARK: - Breathe Overlay
// Full-screen 4-7-8 breathing guide with animated ring.
// Phases: Inhale (4s) → Hold (7s) → Exhale (8s) = 19s per cycle.
// After all cycles, shows completion state with "Remind me in…" picker.

struct BreatheOverlay: View {
    @Environment(UIState.self) private var ui

    // Animation state
    @State private var phase: BreathePhase = .entering
    @State private var ringScale: CGFloat = 0.4
    @State private var currentCycle = 1
    @State private var countdown = 4
    @State private var showCompletion = false
    @State private var overlayOpacity: Double = 0

    // Reminder state (shown after completion)
    @State private var selectedReminder: BreatheReminder = .off

    private var totalCycles: Int { ui.breatheCycles }

    var body: some View {
        ZStack {
            // Dark scrim
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            if showCompletion {
                completionView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                breathingView
                    .transition(.opacity)
            }
        }
        .opacity(overlayOpacity)
        .onAppear {
            selectedReminder = ui.breatheReminder
            withAnimation(.easeIn(duration: 0.6)) { overlayOpacity = 1 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                await runBreathingCycles()
            }
        }
        .onKeyPress(.escape) {
            dismissBreathe()
            return .handled
        }
    }

    // MARK: - Breathing View

    private var breathingView: some View {
        VStack(spacing: 40) {
            // Phase label
            Text(phase.label)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: phase)

            // Animated ring
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.06), .clear],
                            center: .center,
                            startRadius: 60,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(ringScale)

                // Ring
                Circle()
                    .stroke(.white.opacity(0.35), lineWidth: 2)
                    .frame(width: 180, height: 180)
                    .scaleEffect(ringScale)

                // Inner fill
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 176, height: 176)
                    .scaleEffect(ringScale)

                // Countdown
                Text("\(countdown)")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: countdown)
            }

            // Cycle counter
            Text("Cycle \(currentCycle) of \(totalCycles)")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))

            // Tap to exit hint
            Text("press esc to exit")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.top, 20)
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 32) {
            // Checkmark
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.white.opacity(0.7))

            Text("Session Complete")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text("\(totalCycles) cycles · \(totalCycles * 19)s")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))

            // Remind me picker
            VStack(spacing: 12) {
                Text("Remind me in")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 8) {
                    ForEach(BreatheReminder.allCases) { option in
                        Button {
                            selectedReminder = option
                            ui.breatheReminder = option
                        } label: {
                            Text(option.label)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(
                                    selectedReminder == option ? .white : .white.opacity(0.5)
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(
                                            selectedReminder == option
                                                ? .white.opacity(0.15)
                                                : .white.opacity(0.05))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 8)

            // Done button
            Button {
                dismissBreathe()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 120, height: 40)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Breathing Engine

    @MainActor
    private func runBreathingCycles() async {
        for cycle in 1...totalCycles {
            currentCycle = cycle
            guard ui.breatheActive else { return }

            // ── Inhale (4s) ──
            phase = .inhale
            countdown = 4
            withAnimation(.easeInOut(duration: 4.0)) { ringScale = 1.0 }
            for sec in stride(from: 4, through: 1, by: -1) {
                guard ui.breatheActive else { return }
                countdown = sec
                try? await Task.sleep(for: .seconds(1))
            }

            guard ui.breatheActive else { return }

            // ── Hold (7s) ──
            phase = .hold
            countdown = 7
            for sec in stride(from: 7, through: 1, by: -1) {
                guard ui.breatheActive else { return }
                countdown = sec
                try? await Task.sleep(for: .seconds(1))
            }

            guard ui.breatheActive else { return }

            // ── Exhale (8s) ──
            phase = .exhale
            countdown = 8
            withAnimation(.easeInOut(duration: 8.0)) { ringScale = 0.4 }
            for sec in stride(from: 8, through: 1, by: -1) {
                guard ui.breatheActive else { return }
                countdown = sec
                try? await Task.sleep(for: .seconds(1))
            }
        }

        // All cycles complete → show completion
        guard ui.breatheActive else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            showCompletion = true
        }
    }

    private func dismissBreathe() {
        withAnimation(.easeOut(duration: 0.5)) { overlayOpacity = 0 }
        // Schedule next reminder if set
        ui.scheduleBreatheReminder()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            ui.stopBreathe()
        }
    }
}

// MARK: - Breathe Phase

private enum BreathePhase {
    case entering, inhale, hold, exhale

    var label: String {
        switch self {
        case .entering: "Get ready…"
        case .inhale: "Breathe In"
        case .hold: "Hold"
        case .exhale: "Breathe Out"
        }
    }
}

// MARK: - Breathe Reminder

enum BreatheReminder: String, CaseIterable, Identifiable, Codable {
    case off = "off"
    case thirtyMin = "30min"
    case oneHour = "1hr"
    case twoHours = "2hr"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .thirtyMin: "30 min"
        case .oneHour: "1 hr"
        case .twoHours: "2 hr"
        }
    }

    var minutes: Int {
        switch self {
        case .off: 0
        case .thirtyMin: 30
        case .oneHour: 60
        case .twoHours: 120
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
