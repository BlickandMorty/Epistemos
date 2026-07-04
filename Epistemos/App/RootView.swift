import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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

    /// Lock the window's AppKit appearance (and the toolbar's, if present)
    /// to the in-app theme. This is what eliminates the brief flash of an
    /// old theme at the title bar during the landing → main-chat
    /// transition: without this, the title bar paints via the SYSTEM
    /// appearance until the SwiftUI toolbar background materializes (the
    /// 350 ms reveal gate at the bottom of `rootContent`). With an
    /// explicit `NSAppearance(named: …)` set, the title bar always
    /// matches `ui.theme.isDark`.
    @MainActor
    static func applyAppearance(to window: NSWindow, isDark: Bool) {
        let target: NSAppearance? = NSAppearance(named: isDark ? .darkAqua : .aqua)
        if window.appearance != target {
            window.appearance = target
        }
        if let toolbar = window.toolbar, let _ = toolbar.identifier as String? {
            // NSToolbar inherits appearance from its window, so no extra
            // assignment is needed — but stamping the window covers both
            // the title bar and the toolbar surface in one assignment.
            _ = toolbar
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

enum HomeWindowInputFocus {
    @MainActor
    static func restoreAfterOverlayDismiss() {
        NSApp.keyWindow?.makeFirstResponder(nil)

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(20))
            } catch {
                return
            }

            HomeWindowIdentity.surfaceHomeWindow()
            NSApp.windows.first(where: HomeWindowIdentity.matches)?.makeFirstResponder(nil)
        }
    }
}

enum AppWindowBackdropStyle {
    /// Eighth-pass+2 fix (2026-05-13): the window backdrop ALWAYS routes
    /// through `surfaceVariant(.mainChat)` so it matches whatever surface
    /// the active view is painting. Landing + main chat both map to the
    /// same variant via `surfaceVariant`'s policy:
    ///   .platinumVioletDark → .nocturne for both .landing + .mainChat
    ///   .oled                → .oled    for both .landing + .mainChat
    ///   everything else      → identity
    /// so a single resolution covers both surfaces and eliminates the
    /// "top bar flickers a different theme" the user reported during
    /// landing → main-chat transition. Previously the backdrop painted
    /// the RAW `theme.resolved.background` while landing/chat views
    /// painted their surface-variant colors; on Platinum-violet-dark
    /// the raw theme (purple) and the variant (nocturne grey) differ,
    /// so the system toolbar glass — which tints from the window
    /// background — briefly leaked the purple hue during the SwiftUI
    /// transition before the variant repainted.
    nonisolated static func backgroundToken(
        for theme: EpistemosTheme
    ) -> EpistemosTheme.ResolvedColorToken {
        theme.surfaceVariant(.mainChat).resolved.background
    }

    nonisolated static func background(for theme: EpistemosTheme) -> Color {
        backgroundToken(for: theme).color
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
    let themeIsDark: Bool

    func makeNSView(context: Context) -> HomeWindowIdentityObserverView {
        let v = HomeWindowIdentityObserverView()
        v.themeIsDark = themeIsDark
        return v
    }

    func updateNSView(_ nsView: HomeWindowIdentityObserverView, context: Context) {
        nsView.themeIsDark = themeIsDark
        nsView.applyWindowIdentity()
    }
}

private final class HomeWindowIdentityObserverView: NSView {
    /// Latest in-app theme darkness flag, pushed from SwiftUI on every
    /// theme change. Stamped onto the window's AppKit appearance so the
    /// title bar / toolbar surface never paints with the system
    /// appearance during the landing → main-chat transition.
    var themeIsDark: Bool = false {
        didSet {
            guard themeIsDark != oldValue else { return }
            applyWindowIdentity()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowIdentity()
    }

    func applyWindowIdentity() {
        guard let window else { return }
        HomeWindowIdentity.apply(to: window)
        HomeWindowIdentity.applyAppearance(to: window, isDark: themeIsDark)
    }
}

// MARK: - Root View
// Top-level container with centered toolbar controls.
// System Liquid Glass toolbar provides the chrome — no custom glass needed.

struct RootView: View {
    @Environment(UIState.self) private var ui
    @Environment(GraphState.self) private var graphState
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    /// Set by EpistemosApp when AppBootstrap detected a database error.
    var databaseError: Error?
    /// Callback to reset database and relaunch.
    var onResetDatabase: (() -> Void)?
    @Binding var showQuickCapture: Bool

    @State private var appearanceObserver = SystemAppearanceObserver()
    @State private var showDatabaseAlert = false
    @State private var showGreetingControls = false
    @State private var showWorkspaceSwitcher = false
    @State private var showTimeMachine = false

    /// Transition gate: suppresses toolbar reveal during landing→chat animation on Home.
    /// Only delays the *reveal*; hiding is always immediate.
    @State private var homeChatToolbarReady = false

    /// The old Epistemos-native chat surface has been removed from Home.
    private var activeHomeChat: Bool {
        false
    }

    private var embeddedHomeGraphContentVisible: Bool {
        ui.homeTab == .home && ui.homeContent == .graph
    }

    private var embeddedHomeGraphCanvasVisible: Bool {
        embeddedHomeGraphContentVisible && graphState.currentRoute.isCanvas
    }

    private var embeddedHomeGraphNoteVisible: Bool {
        guard embeddedHomeGraphContentVisible else { return false }
        if case .note = graphState.currentRoute { return true }
        return false
    }

    private var showLandingToolbarControls: Bool {
        ui.homeTab == .home
            && !embeddedHomeGraphContentVisible
    }

    private var showEmbeddedGraphToolbarControls: Bool {
        embeddedHomeGraphCanvasVisible
    }

    /// Canonical toolbar glass visibility — deterministic from app state.
    /// For non-Home tabs: always visible.
    /// For Home landing: always hidden.
    /// For Home chat: gated by `homeChatToolbarReady` to suppress transition flash.
    private var toolbarGlassVisible: Bool {
        if ui.homeTab != .home { return true }
        if embeddedHomeGraphContentVisible {
            return embeddedHomeGraphNoteVisible
        }
        return activeHomeChat && homeChatToolbarReady
    }

    var body: some View {
        rootContent
            .modifier(RootWindowLifecycle(ui: ui))
            .modifier(RootWorkspaceEvents(
                showWorkspaceSwitcher: $showWorkspaceSwitcher,
                showTimeMachine: $showTimeMachine,
                showQuickCapture: $showQuickCapture
            ))
            .commandPaletteHost()
    }

    private var rootContent: some View {
        ZStack {
            // Pre-paint the window background so transitions from landing
            // into chat don't briefly flash the old theme surface at the
            // title bar. Use the selected semantic theme in both appearances.
            // `allowsHitTesting(false)` is CRITICAL — without it the Color
            // swallows clicks, breaking every button on the window.
            AppWindowBackdropStyle.background(for: ui.theme)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ContentRouter()
        }
        .background(HomeWindowIdentityObserver(themeIsDark: ui.theme.isDark))
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: activeHomeChat)
        .onAppear(perform: handleAppearanceOnAppear)
        .onDisappear {
            appearanceObserver.stop()
        }
        .onChange(of: ui.readableFontsEnabled) { _, _ in
            // Observing the preference here redraws typography live without
            // restarting the app or resetting graph/navigation view identity.
        }
        .onChange(of: ui.appearanceSyncKey) { _, _ in
            UtilityWindowManager.shared.syncTheme(uiState: ui)
            HologramController.shared.syncTheme(ui)
        }
        .toolbar {
            // Back button — only present for future active home-chat routing.
            if !embeddedHomeGraphContentVisible && ui.homeTab == .home && activeHomeChat {
                ToolbarItem(placement: .navigation) {
                    Button {
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityLabel("Back to Home")
                    .help("Back to Home")
                }
            }
            if showLandingToolbarControls
                || showEmbeddedGraphToolbarControls
                || (!embeddedHomeGraphContentVisible && activeHomeChat)
            {
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
        .overlay(alignment: .top) {
            if vaultSync.isIndexing || vaultSync.vaultActivityMessage != nil {
                VaultActivityStatusOverlay(
                    message: vaultSync.vaultActivityMessage ?? "Loading vault...",
                    progress: vaultSync.vaultImportProgress
                )
                .padding(.top, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
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
        .overlay {
            if let databaseError {
                DatabaseRecoveryOverlay(
                    error: databaseError,
                    resetAction: requestDatabaseResetAuthorization,
                    quitAction: { NSApp.terminate(nil) }
                )
                .transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: ui.needsSetup)
        .onAppear(perform: handleDatabaseCheck)
        .alert("Database Recovery Required", isPresented: $showDatabaseAlert) {
            Button("Reset Database", role: .destructive) {
                requestDatabaseResetAuthorization()
            }
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text("The database could not be loaded. This recovery session is not durable. Normal notes, chat, capture, vault sync, and .epdoc writes are blocked until the database is reset or repaired.\n\n\(databaseError?.localizedDescription ?? "")")
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
            guard ui.isSystemDark != isDark else { return }
            ui.isSystemDark = isDark
        }
        appearanceObserver.start()
    }

    private var rootToolbarControls: some View {
        HStack(spacing: 10) {
            if showLandingToolbarControls || showEmbeddedGraphToolbarControls {
                // Keep the pill mounted on the graph — a principal ToolbarItem is load-bearing
                // for the window's curved corners. Settings and greeting controls remain on
                // the restored landing toolbar.
                ControlGroup {
                    settingsToolbarButton
                    if !embeddedHomeGraphContentVisible {
                        landingGreetingToolbarButton
                    }
                }
                .animation(.easeOut(duration: 0.28), value: embeddedHomeGraphContentVisible)
            }

        }
        .frame(minWidth: 160, minHeight: 30)
        .fixedSize()
    }

    private var settingsToolbarButton: some View {
        Button(action: openContextualSettingsWindow) {
            Label("Settings", systemImage: "gearshape")
        }
        .accessibilityLabel("Settings")
        .help("Settings (⌘S)")
    }

    @ViewBuilder
    private func modelToolbarButton(title: String? = nil) -> some View {
        let resolvedTitle = title ?? "Epistemos"
        MotionTitle(
            text: resolvedTitle,
            font: .system(size: 16, weight: .semibold, design: .rounded),
            color: ui.theme.textPrimary
        )
            .id(resolvedTitle)
            .lineLimit(1)
            .truncationMode(.middle)
            .fixedSize()
            .accessibilityLabel("Chat title")
    }

    private func openSettingsWindow() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate()
    }

    private func openContextualSettingsWindow() {
        openSettingsWindow()
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

}

private struct DatabaseRecoveryOverlay: View {
    let error: Error
    let resetAction: () -> Void
    let quitAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database Recovery Required")
                        .font(.system(size: 22, weight: .semibold))

                    Text("This recovery session is not durable.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)

                    Text("Notes, chat, capture, vault sync, and .epdoc writes are disabled until the database is reset or the store is repaired and Epistemos is relaunched.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(error.localizedDescription)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button("Reset Database", role: .destructive) {
                        resetAction()
                    }

                    Button("Quit") {
                        quitAction()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 28, y: 12)
            .padding(32)
        }
    }
}


private struct VaultActivityStatusOverlay: View {
    let message: String
    let progress: VaultImportProgressSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                if let fraction = progress?.progressFraction {
                    ProgressView(value: fraction)
                        .frame(width: 92)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let progress {
                Text("\(progress.mutationSummary) · \(progress.inventorySummary)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .accessibilityLabel(message)
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

private struct ContentRouter: View {
    var body: some View {
        if RuntimeAuditRootFlags.rootShellMinimalContentEnabled {
            AuditRootShellMinimalContentView()
        } else {
            HomeRouter()
        }
    }
}

// MARK: - Home Router
// Separate view so the mode switch doesn't affect the outer ZStack.

private struct HomeRouter: View {
    var body: some View {
        LandingView()
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
    private var displayFont: Font { AppDisplayTypography.font(size: 38) }

    var body: some View {
        ZStack {
            // Solid background
            theme.resolved.background.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Typewriter greeting — app display font, same style as LiquidGreeting
                HStack(alignment: .center, spacing: 0) {
                    Text(displayText)
                        .font(displayFont)
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
                        UserDefaults.standard.set(true, forKey: "epistemos.setupComplete")
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
                Text("connect your vault in Settings to get started")
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
    @Binding var showTimeMachine: Bool
    @Binding var showQuickCapture: Bool

    func body(content: Content) -> some View {
        content
            .overlay { workspaceOverlays }
            .background { workspaceKeyboardShortcuts }
            .onKeyPress(.escape, action: handleEscapeKeyPress)
            .animation(nil, value: showWorkspaceSwitcher)
            .animation(nil, value: showTimeMachine)
            .animation(nil, value: showQuickCapture)
            .onReceive(NotificationCenter.default.publisher(for: .toggleWorkspaceSwitcher)) { _ in
                showWorkspaceSwitcher.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleTimeMachine)) { _ in
                showTimeMachine.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showSaveWorkspacePanel)) { _ in
                QuitSavePanelController.showSave()
            }
    }

    private func handleEscapeKeyPress() -> KeyPress.Result {
        if showQuickCapture { showQuickCapture = false; HomeWindowInputFocus.restoreAfterOverlayDismiss(); return .handled }
        if showWorkspaceSwitcher { showWorkspaceSwitcher = false; return .handled }
        if showTimeMachine { showTimeMachine = false; return .handled }
        return .ignored
    }

    @ViewBuilder
    private var workspaceOverlays: some View {
        if showWorkspaceSwitcher {
            WorkspaceSwitcherOverlay(isPresented: $showWorkspaceSwitcher)
        }
        if showTimeMachine {
            TimeMachineView(isPresented: $showTimeMachine)
        }
        if showQuickCapture {
            QuickCaptureView(isPresented: $showQuickCapture)
        }
    }

    @ViewBuilder
    private var workspaceKeyboardShortcuts: some View {
        Button(action: { showWorkspaceSwitcher.toggle() }) {}
            .keyboardShortcut("w", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { showTimeMachine.toggle() }) {}
            .keyboardShortcut("t", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { QuitSavePanelController.showSave() }) {}
            .keyboardShortcut("s", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)
    }
}
