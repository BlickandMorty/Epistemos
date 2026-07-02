import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let epistemosGooseNativeNavigate = Notification.Name("EpistemosGooseNativeNavigate")
    static let epistemosGooseNativeChromeIntent = Notification.Name("EpistemosGooseNativeChromeIntent")
    static let epistemosGooseWebRouteDidChange = Notification.Name("EpistemosGooseWebRouteDidChange")
    static let epistemosGooseChromeSnapshotDidChange = Notification.Name("EpistemosGooseChromeSnapshotDidChange")
}

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
    @State private var activeGooseWebPath = "/"
    @State private var activeGooseSessionTitle = ""
    @State private var activeGooseIsStreaming = false
    @State private var activeGooseThemePreference = "system"

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
            // The landing greeting/settings pill is for the landing page only.
            // Goose gets its own native toolbar Home affordance below so the
            // WebView remains unoccluded.
            && ui.homeContent != .goose
    }

    private var showGooseToolbarControls: Bool {
        ui.homeTab == .home && ui.homeContent == .goose
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
        if showGooseToolbarControls { return true }
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
        .modifier(GooseNativeChromeRootSynchronization(
            isGooseSurfaceActive: showGooseToolbarControls,
            activeGooseWebPath: $activeGooseWebPath,
            activeGooseSessionTitle: $activeGooseSessionTitle,
            activeGooseIsStreaming: $activeGooseIsStreaming,
            activeGooseThemePreference: $activeGooseThemePreference,
            synchronizeWindowTitle: synchronizeGooseWindowTitle
        ))
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
                || showGooseToolbarControls
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
            if showGooseToolbarControls {
                GooseNativeNavBar(
                    activePath: activeGooseWebPath,
                    sessionTitle: activeGooseSessionTitle,
                    isStreaming: activeGooseIsStreaming,
                    themePreference: activeGooseThemePreference,
                    theme: ui.theme,
                    onReturnHome: returnFromGooseToHome,
                    onNavigate: navigateGooseWeb,
                    onNewChat: newGooseChat,
                    onSessionAction: sendGooseSessionAction,
                    onThemeChange: setGooseTheme
                )
            } else if showLandingToolbarControls || showEmbeddedGraphToolbarControls {
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
        .frame(minWidth: showGooseToolbarControls ? GooseNativeChromeMetrics.barWidth : 160, minHeight: 30)
        .fixedSize()
    }

    private var settingsToolbarButton: some View {
        Button(action: openContextualSettingsWindow) {
            Label("Settings", systemImage: "gearshape")
        }
        .accessibilityLabel("Settings")
        .help("Settings (⌘S)")
    }

    private var gooseHomeToolbarButton: some View {
        Button(action: returnFromGooseToHome) {
            Label {
                Text("Home")
                    .font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel("Back to Home")
        .help("Back to Home")
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

    private func returnFromGooseToHome() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            ui.homeContent = .greeting
        }
    }

    private func navigateGooseWeb(to path: String) {
        let normalizedPath = GooseNativeRouteItem.normalized(path)
        activeGooseWebPath = normalizedPath
        NotificationCenter.default.post(
            name: .epistemosGooseNativeChromeIntent,
            object: nil,
            userInfo: ["type": GooseNativeChromeIntent.navigate, "path": normalizedPath]
        )
    }

    private func newGooseChat() {
        activeGooseWebPath = "/"
        NotificationCenter.default.post(
            name: .epistemosGooseNativeChromeIntent,
            object: nil,
            userInfo: ["type": GooseNativeChromeIntent.newChat]
        )
    }

    private func sendGooseSessionAction(_ action: GooseNativeSessionAction) {
        NotificationCenter.default.post(
            name: .epistemosGooseNativeChromeIntent,
            object: nil,
            userInfo: ["type": action.intentType]
        )
    }

    private func setGooseTheme(_ preference: GooseNativeThemePreference) {
        activeGooseThemePreference = preference.rawValue
        NotificationCenter.default.post(
            name: .epistemosGooseNativeChromeIntent,
            object: nil,
            userInfo: ["type": GooseNativeChromeIntent.setTheme, "theme": preference.rawValue]
        )
    }

    private func synchronizeGooseWindowTitle() {
        let title: String
        if showGooseToolbarControls {
            title = activeGooseWebPathOnly == "/pair" && !activeGooseSessionTitle.isEmpty
                ? activeGooseSessionTitle
                : "Goose"
        } else {
            title = HomeWindowIdentity.title
        }
        guard let window = NSApp.windows.first(where: HomeWindowIdentity.matches) else { return }
        if window.title != title {
            window.title = title
        }
    }

    private var activeGooseWebPathOnly: String {
        activeGooseWebPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
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

private struct GooseNativeChromeRootSynchronization: ViewModifier {
    let isGooseSurfaceActive: Bool
    @Binding var activeGooseWebPath: String
    @Binding var activeGooseSessionTitle: String
    @Binding var activeGooseIsStreaming: Bool
    @Binding var activeGooseThemePreference: String
    let synchronizeWindowTitle: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .epistemosGooseWebRouteDidChange)) { note in
                handleGooseWebRouteChange(note)
            }
            .onReceive(NotificationCenter.default.publisher(for: .epistemosGooseChromeSnapshotDidChange)) { note in
                handleGooseChromeSnapshot(note)
            }
            .onChange(of: isGooseSurfaceActive) { _, _ in
                synchronizeWindowTitle()
            }
            .onChange(of: activeGooseSessionTitle) { _, _ in
                synchronizeWindowTitle()
            }
            .onChange(of: activeGooseWebPath) { _, _ in
                synchronizeWindowTitle()
            }
    }

    private func handleGooseWebRouteChange(_ note: Notification) {
        guard let rawPath = note.userInfo?["path"] as? String else { return }
        activeGooseWebPath = GooseNativeRouteItem.normalized(rawPath)
    }

    private func handleGooseChromeSnapshot(_ note: Notification) {
        if let rawPath = note.userInfo?["route"] as? String {
            activeGooseWebPath = GooseNativeRouteItem.normalized(rawPath)
        }
        if let title = note.userInfo?["sessionTitle"] as? String {
            activeGooseSessionTitle = title
        }
        if let isStreaming = note.userInfo?["isStreaming"] as? Bool {
            activeGooseIsStreaming = isStreaming
        }
        if let themePreference = note.userInfo?["themePreference"] as? String {
            activeGooseThemePreference = themePreference
        }
    }
}

private enum GooseNativeChromeIntent {
    static let navigate = "navigate"
    static let newChat = "newChat"
    static let openSessionNotes = "openSessionNotes"
    static let renameSession = "renameSession"
    static let duplicateSession = "duplicateSession"
    static let viewSessionJson = "viewSessionJson"
    static let setTheme = "setTheme"
}

private enum GooseNativeSessionAction: String, CaseIterable, Identifiable {
    case openSessionNotes
    case renameSession
    case duplicateSession
    case viewSessionJson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openSessionNotes: "Session Notes"
        case .renameSession: "Rename"
        case .duplicateSession: "Duplicate"
        case .viewSessionJson: "View JSON"
        }
    }

    var systemImage: String {
        switch self {
        case .openSessionNotes: "note.text"
        case .renameSession: "pencil"
        case .duplicateSession: "doc.on.doc"
        case .viewSessionJson: "curlybraces.square"
        }
    }

    var intentType: String {
        switch self {
        case .openSessionNotes: GooseNativeChromeIntent.openSessionNotes
        case .renameSession: GooseNativeChromeIntent.renameSession
        case .duplicateSession: GooseNativeChromeIntent.duplicateSession
        case .viewSessionJson: GooseNativeChromeIntent.viewSessionJson
        }
    }
}

private enum GooseNativeThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "slider.horizontal.3"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

private enum GooseNativeChromeMetrics {
    static let barWidth: CGFloat = 910
    static let barHeight: CGFloat = 44
    static let navSlotWidth: CGFloat = 42
    static let navSlotHeight: CGFloat = 38
    static let leadingWidth: CGFloat = 116
    static let titleWidth: CGFloat = 190
    static let iconSize: CGFloat = 16.5
    static let maxExpandedWidth: CGFloat = 112
    static let routeLabelCharacterWidth: CGFloat = 6.6
}

private struct GooseNativeNavBar: View {
    let activePath: String
    let sessionTitle: String
    let isStreaming: Bool
    let themePreference: String
    let theme: EpistemosTheme
    let onReturnHome: () -> Void
    let onNavigate: (String) -> Void
    let onNewChat: () -> Void
    let onSessionAction: (GooseNativeSessionAction) -> Void
    let onThemeChange: (GooseNativeThemePreference) -> Void

    private let routeItems = GooseNativeRouteItem.webRoutes

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onReturnHome) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Epistemos")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(width: GooseNativeChromeMetrics.leadingWidth, height: GooseNativeChromeMetrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("Back to Epistemos")
            .accessibilityLabel("Back to Epistemos")

            Divider()
                .frame(height: 22)
                .opacity(0.34)

            HStack(spacing: 2) {
                ForEach(routeItems) { item in
                    GooseNativeNavButton(
                        title: item.label,
                        systemImage: item.systemImage,
                        isActive: item.isActive(activePath),
                        theme: theme,
                        action: { onNavigate(item.path) }
                    )
                }
            }

            Divider()
                .frame(height: 22)
                .opacity(0.34)

            GooseNativeSessionTitle(title: sessionTitle, theme: theme)

            GooseNativeStreamingStatusLight(isStreaming: isStreaming, theme: theme)

            GooseNativeIconButton(
                title: "New Chat",
                systemImage: "plus",
                theme: theme,
                action: onNewChat
            )

            GooseNativeSessionActionsMenu(
                theme: theme,
                hasSession: !sessionTitle.isEmpty,
                onSessionAction: onSessionAction
            )

            GooseNativeThemeMenu(
                selection: GooseNativeThemePreference(rawValue: themePreference) ?? .system,
                theme: theme,
                onThemeChange: onThemeChange
            )
        }
        .frame(width: GooseNativeChromeMetrics.barWidth, height: GooseNativeChromeMetrics.barHeight)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Goose native chrome")
    }
}

private struct GooseNativeRouteItem: Identifiable, Equatable {
    let id: String
    let label: String
    let path: String
    let systemImage: String

    static let webRoutes: [GooseNativeRouteItem] = [
        GooseNativeRouteItem(id: "home", label: "Home", path: "/", systemImage: "house"),
        GooseNativeRouteItem(id: "chat", label: "Chat", path: "/pair", systemImage: "message"),
        GooseNativeRouteItem(id: "recipes", label: "Recipes", path: "/recipes", systemImage: "doc.text"),
        GooseNativeRouteItem(id: "skills", label: "Skills", path: "/skills", systemImage: "bolt"),
        GooseNativeRouteItem(id: "apps", label: "Apps", path: "/apps", systemImage: "macwindow"),
        GooseNativeRouteItem(id: "scheduler", label: "Scheduler", path: "/schedules", systemImage: "calendar"),
        GooseNativeRouteItem(id: "extensions", label: "Extensions", path: "/extensions", systemImage: "puzzlepiece.extension"),
        GooseNativeRouteItem(id: "history", label: "History", path: "/sessions", systemImage: "clock.arrow.circlepath"),
        GooseNativeRouteItem(id: "settings", label: "Settings", path: "/settings", systemImage: "gearshape"),
    ]

    static func normalized(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        let bounded = String(trimmed.prefix(GooseWebSurfaceView.maxGooseRouteCharacters))
        return bounded.hasPrefix("/") ? bounded : "/\(bounded)"
    }

    func isActive(_ currentPath: String) -> Bool {
        let normalizedCurrent = Self.normalized(currentPath)
        let pathOnly = normalizedCurrent.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        if path == "/" {
            return pathOnly == "/"
        }
        return pathOnly == path || pathOnly.hasPrefix("\(path)/")
    }
}

private struct GooseNativeNavButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let theme: EpistemosTheme
    let action: () -> Void

    @State private var isHovered = false
    @State private var typedText = ""
    @State private var cursorVisible = false
    @State private var hoverIntentTask: Task<Void, Never>?
    @State private var typewriterTask: Task<Void, Never>?

    private var expanded: Bool {
        isActive || isHovered
    }

    private var expandedWidth: CGFloat {
        min(
            GooseNativeChromeMetrics.maxExpandedWidth,
            max(76, 43 + CGFloat(title.count) * GooseNativeChromeMetrics.routeLabelCharacterWidth)
        )
    }

    private var labelText: String {
        if isActive { return title }
        return isHovered ? typedText : ""
    }

    private var foreground: Color {
        if isActive {
            return theme.resolved.foreground.color
        }
        return theme.textPrimary.opacity(isHovered ? 0.96 : 0.78)
    }

    private var iconColor: Color {
        isActive ? theme.fontAccent : foreground
    }

    private var background: Color {
        if isActive {
            return theme.fontAccent.opacity(theme.isDark ? 0.18 : 0.14)
        }
        if isHovered {
            return theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.075)
        }
        return .clear
    }

    var body: some View {
        ZStack {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: GooseNativeChromeMetrics.iconSize, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(
                        width: GooseNativeChromeMetrics.navSlotWidth,
                        height: GooseNativeChromeMetrics.navSlotHeight
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            if expanded {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .font(.system(size: GooseNativeChromeMetrics.iconSize, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 19, height: 19)

                    HStack(spacing: 2) {
                        Text(labelText)
                            .font(AppDisplayTypography.font(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true)
                        if isHovered && !isActive && cursorVisible {
                            GooseNativeTypewriterCursor(color: theme.fontAccent)
                        }
                    }
                    .foregroundStyle(foreground)
                }
                .padding(.horizontal, 12)
                .frame(width: expandedWidth, height: GooseNativeChromeMetrics.navSlotHeight)
                .background(background, in: Capsule())
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .frame(width: GooseNativeChromeMetrics.navSlotWidth, height: GooseNativeChromeMetrics.navSlotHeight)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.25), value: expanded)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .animation(.easeOut(duration: 0.16), value: isActive)
        .onHover { hovering in
            hovering ? beginHoverIntent() : endHover()
        }
        .onChange(of: isActive) { _, _ in
            resetHoverState()
        }
        .onDisappear {
            cancelHoverWork()
        }
    }

    private func beginHoverIntent() {
        guard !isActive else { return }
        hoverIntentTask?.cancel()
        hoverIntentTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            isHovered = true
            startTypewriter()
        }
    }

    private func endHover() {
        guard !isActive else { return }
        resetHoverState()
    }

    private func resetHoverState() {
        cancelHoverWork()
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.18)) {
            isHovered = false
            typedText = ""
            cursorVisible = false
        }
    }

    private func cancelHoverWork() {
        hoverIntentTask?.cancel()
        hoverIntentTask = nil
        typewriterTask?.cancel()
        typewriterTask = nil
    }

    private func startTypewriter() {
        typewriterTask?.cancel()
        typedText = ""
        cursorVisible = true
        let characters = Array(title)
        typewriterTask = Task { @MainActor in
            for index in characters.indices {
                guard !Task.isCancelled else { return }
                typedText.append(characters[index])
                try? await Task.sleep(for: .milliseconds(35))
            }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            cursorVisible = false
        }
    }
}

private struct GooseNativeSessionTitle: View {
    let title: String
    let theme: EpistemosTheme

    private var resolvedTitle: String {
        title.isEmpty ? "No active session" : title
    }

    var body: some View {
        Text(resolvedTitle)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(title.isEmpty ? theme.mutedForeground : theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: GooseNativeChromeMetrics.titleWidth, alignment: .leading)
            .help(resolvedTitle)
            .accessibilityLabel("Session title: \(resolvedTitle)")
    }
}

private struct GooseNativeStreamingStatusLight: View {
    let isStreaming: Bool
    let theme: EpistemosTheme
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isStreaming ? theme.fontAccent : theme.mutedForeground.opacity(0.36))
            .frame(width: 8, height: 8)
            .scaleEffect(isStreaming && pulse ? 1.35 : 1)
            .opacity(isStreaming ? (pulse ? 0.95 : 0.52) : 0.5)
            .frame(width: 16, height: GooseNativeChromeMetrics.navSlotHeight)
            .help(isStreaming ? "Goose is streaming" : "Goose is idle")
            .accessibilityLabel(isStreaming ? "Streaming" : "Idle")
            .onAppear { updatePulse(isStreaming) }
            .onChange(of: isStreaming) { _, value in updatePulse(value) }
    }

    private func updatePulse(_ streaming: Bool) {
        if streaming {
            pulse = false
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
        }
    }
}

private struct GooseNativeIconButton: View {
    let title: String
    let systemImage: String
    let theme: EpistemosTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: GooseNativeChromeMetrics.iconSize, weight: .semibold))
                .frame(width: GooseNativeChromeMetrics.navSlotWidth, height: GooseNativeChromeMetrics.navSlotHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary.opacity(0.82))
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct GooseNativeSessionActionsMenu: View {
    let theme: EpistemosTheme
    let hasSession: Bool
    let onSessionAction: (GooseNativeSessionAction) -> Void

    var body: some View {
        Menu {
            ForEach(GooseNativeSessionAction.allCases) { action in
                Button {
                    onSessionAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .disabled(!hasSession)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: GooseNativeChromeMetrics.iconSize, weight: .semibold))
                .frame(width: GooseNativeChromeMetrics.navSlotWidth, height: GooseNativeChromeMetrics.navSlotHeight)
                .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(theme.textPrimary.opacity(hasSession ? 0.82 : 0.42))
        .help("Session actions")
        .accessibilityLabel("Session actions")
    }
}

private struct GooseNativeThemeMenu: View {
    let selection: GooseNativeThemePreference
    let theme: EpistemosTheme
    let onThemeChange: (GooseNativeThemePreference) -> Void

    var body: some View {
        Menu {
            ForEach(GooseNativeThemePreference.allCases) { preference in
                Button {
                    onThemeChange(preference)
                } label: {
                    Label(preference.title, systemImage: preference.systemImage)
                }
            }
        } label: {
            Image(systemName: selection.systemImage)
                .font(.system(size: GooseNativeChromeMetrics.iconSize, weight: .semibold))
                .frame(width: GooseNativeChromeMetrics.navSlotWidth, height: GooseNativeChromeMetrics.navSlotHeight)
                .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(theme.textPrimary.opacity(0.82))
        .help("Goose theme")
        .accessibilityLabel("Goose theme")
    }
}

private struct GooseNativeTypewriterCursor: View {
    let color: Color
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1.5, height: 11)
            .opacity(visible ? 1 : 0.18)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    visible = false
                }
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
