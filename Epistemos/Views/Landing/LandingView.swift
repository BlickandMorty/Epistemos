import AppKit
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum LandingCoordinateSpace {
    static let root = "LandingRoot"
}

enum LandingViewStateSync {
    @MainActor
    static func reassertHomeSurface(_ ui: UIState) {
        ui.setActivePanel(.home)
        ui.homeTab = .home
    }
}

private enum LandingInlineCommand: Equatable {
    case quickCapture
    case workspaces
    case saveWorkspace
    case timeMachine

    var minStageHeight: CGFloat {
        switch self {
        case .quickCapture: 350
        case .workspaces: 380
        case .saveWorkspace: 380
        case .timeMachine: 420
        }
    }
}

// MARK: - Landing View
// Clean landing: liquid glass greeting with deliberate command tiles.

struct LandingView: View {
    private static let log = Logger(subsystem: "com.epistemos", category: "LandingView")
    private static let maxLandingFeatureStatusCharacters = 1_200
    private static let maxLandingPDFImportStatusRows = 12
    private static let maxLandingPDFImportStatusLineCharacters = 160
    private static let hiddenGooseHomeSurfaceOpacity = 0.001

    /// Shared blur-fade for surfaces embedded as home pages (Meeting/arXiv/Browser/…),
    /// matching the landing↔graph transition language.
    private static let homePageTransition: AnyTransition = .asymmetric(
        insertion: .modifier(
            active: BlurFade(blur: 14, opacity: 0),
            identity: BlurFade(blur: 0, opacity: 1)
        ),
        removal: .opacity
    )

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(WorkspaceService.self) private var workspaceService
    @Environment(DailyBriefState.self) private var dailyBrief
    @Environment(GraphState.self) private var graphState
    @Environment(ContextualShadowsState.self) private var contextualShadows
    @Environment(AmbientFrequencyPlaybackState.self) private var ambientPlayback
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showWelcomeBack = false
    @State private var presentedWelcomeBack: WelcomeBackInfo?
    @State private var welcomeBackDismissTask: Task<Void, Never>?
    @State private var welcomeBackSyncTask: Task<Void, Never>?

    /// Simulation Mode v1.6 — sheet presentation state for the Farm
    /// (creation wizard, delete confirmation, restore from trash).
    /// Each is nil when not presented; non-nil triggers a `.sheet`
    /// modifier on the body.
    @State private var farmShowingCreate: Bool = false
    @State private var farmEditTarget: CompanionRosterEntry? = nil
    @State private var farmDeleteTarget: CompanionRosterEntry? = nil
    @State private var farmShowingRestore: Bool = false

    // Recent data for Daily Brief context
    @Query(SDPage.recentDescriptor(limit: 50))
    private var allPages: [SDPage]

    @State private var landingStageRevealFrame = 0
    @State private var landingStageRevealTask: Task<Void, Never>?
    @State private var landingGreetingReturnFrame = 4
    @State private var landingGreetingReturnTask: Task<Void, Never>?
    @State private var activeLandingInlineCommand: LandingInlineCommand?
    @State private var showingNewCodeFileSheet = false
    @State private var showingArxivSearch = false
    @State private var landingFeatureStatusMessage: String?
    @State private var showingLandingFeatureStatus = false
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.landing) }
    private var landingInlineCommandSurfaceTheme: EpistemosTheme {
        LandingCommandThemeTreatment.resolve(for: theme).chromeTheme(for: theme)
    }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }
    private var showingOverlay: Bool { showingBrief || showWelcomeBack }
    private var isGooseHomeSurfaceVisible: Bool { ui.homeContent == .goose }
    private var gooseHomeSurfaceOpacity: Double {
        isGooseHomeSurfaceVisible ? 1 : Self.hiddenGooseHomeSurfaceOpacity
    }
    private var showingLandingStageCommand: Bool {
        activeLandingInlineCommand != nil
    }
    private var landingStageMinHeight: CGFloat {
        return activeLandingInlineCommand?.minStageHeight ?? 220
    }

    /// ALWAYS mount + PRE-WARM the persistent embedded Goose surface from first render
    /// (owner: "goose is always loaded; nav should feel instant"). The runtime spawn is
    /// now off the main actor (GooseRuntimeSupervisor), so warming at launch no longer
    /// freezes startup; an unstaged runtime just renders a harmless placeholder. Latching
    /// this to a once-checked availability flag was why the prewarm never actually warmed
    /// (isReady was false at onAppear → the layer never mounted → every nav was cold). (hang-trace 2026-07-01)
    @State private var gooseSurfacePrewarmEnabled = true

    // MARK: - Body

    var body: some View {
        ZStack {
            landingBackdrop
                .zIndex(-1)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !showingOverlay else { return }
                    if showingLandingStageCommand {
                        dismissLandingStageCommand()
                    }
                }
                .allowsHitTesting(!showingOverlay)
                .zIndex(0)

            // ── Home Content Router (Phase 1 — embed-in-home) ──
            // When `ui.homeContent == .greeting` (default), the landing
            // shows the LiquidGreeting + command-hint dock as it always
            // has. When the user presses Cmd+G AND
            // `GraphState.graphViewLocation == .embedded`, this flips to
            // `.graph` and we cross-fade the greeting OUT and the
            // embedded graph IN. Same Apple-spring used for both.
            switch ui.homeContent {
            case .greeting:
                greetingContent
                    .blur(radius: showingOverlay ? 4 : 0)
                    .opacity(showingOverlay ? 0.7 : 1)
                    .allowsHitTesting(!showingOverlay)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .modifier(
                                active: BlurFade(blur: 18, opacity: 0),
                                identity: BlurFade(blur: 0, opacity: 1)
                            )
                        )
                    )
                    .zIndex(1)
            case .graph:
                HomeGraphEmbeddedView()
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: BlurFade(blur: 14, opacity: 0),
                                identity: BlurFade(blur: 0, opacity: 1)
                            ),
                            removal: .opacity
                        )
                    )
                    .zIndex(1)
            case .meeting:
                // Feature surfaces embedded as home PAGES (owner: animate to a
                // page in the home window, like the old chat) — not utility windows.
                HomeEmbeddedPage(title: "Meeting") { MeetingNoteView() }
                    .transition(Self.homePageTransition).zIndex(1)
            case .arxiv:
                HomeEmbeddedPage(title: "arXiv") { ArxivSearchView() }
                    .transition(Self.homePageTransition).zIndex(1)
            case .browser:
                HomeEmbeddedPage(title: "Browser") { BrowserView() }
                    .transition(Self.homePageTransition).zIndex(1)
            case .browserUsePro:
                HomeEmbeddedPage(title: "Browser-Use Pro") { BrowserUseWebUIView() }
                    .transition(Self.homePageTransition).zIndex(1)
            case .goose:
                // Rendered by the persistent pre-warmed Goose layer below (kept
                // alive so navigation is instant). This case only holds the slot.
                Color.clear.zIndex(1)
            }

            // Persistent, PRE-WARMED Goose surface (owner: "load fully at app start,
            // ready, no hang"). Mounted ONCE whenever Goose is staged so its runtime
            // stays warm across navigations; hidden until homeContent == .goose. It
            // warms in the background while the user is still on the landing page.
            if gooseSurfacePrewarmEnabled || ui.homeContent == .goose {
                // `|| homeContent == .goose` ensures the surface always mounts when
                // navigated to (Cmd+3 / a late-ready Goose), never a blank page even if
                // the prewarm flag was resolved false at onAppear. (thermo-nuclear 2026-07-01)
                HomeEmbeddedPage(title: "Goose") {
                    if AgentSurface.isEnabled() {
                        AgentSurfaceRootView(theme: ui.theme)
                    } else {
                        GooseWebSurfaceView(theme: ui.theme)
                    }
                }
                .opacity(gooseHomeSurfaceOpacity)
                .allowsHitTesting(isGooseHomeSurfaceVisible)
                .accessibilityHidden(!isGooseHomeSurfaceVisible)
                .zIndex(5)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }

            // Companion dock — hidden when the embedded graph is up so it
            // doesn't compete with the graph's right-side inspector.
            if ui.homeContent == .greeting && !showingLandingStageCommand {
                landingCompanionDock
                    .opacity(showingOverlay ? 0.45 : 1)
                    .allowsHitTesting(!showingOverlay)
                    .transition(.opacity)
                    .zIndex(2)
            }

            if ui.homeContent == .greeting, ambientPlayback.isRunning {
                VStack {
                    HStack {
                        landingAmbientFrequencyMediaChip
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 26)
                .padding(.leading, 28)
                .padding(.trailing, 28)
                .opacity(showingOverlay ? 0.45 : 1)
                .allowsHitTesting(!showingOverlay)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(2.5)
            }

            if (farmShowingCreate || farmEditTarget != nil), let bootstrap = AppBootstrap.shared {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissFarmCompanionEditor() }
                    .zIndex(3.5)

                CompanionCreationFlow(
                    companionState: bootstrap.companionState,
                    theme: theme,
                    editingEntry: farmEditTarget,
                    onDismiss: dismissFarmCompanionEditor
                )
                .transition(.opacity)
                .zIndex(4)
            }

            // ── Daily Brief Mode ──
            // Fades in on top of the blurred greeting.
            if showingBrief {
                dailyBriefContent
                    // SS-ALIVE: blur-fade overlay (no .scale fold) — cohesive with the
                    // app's one transition language (RootView Landing↔Chat / SS-AN homepage).
                    .transition(.blurFade())
                .zIndex(3)
            }

            // ── Welcome Back Mode ──
            // Shows after workspace auto-restore with session summary.
            if showWelcomeBack, let info = presentedWelcomeBack {
                welcomeBackContent(info: info)
                    // SS-ALIVE: blur-fade overlay (no .scale fold) — cohesive with the
                    // app's one transition language (RootView Landing↔Chat / SS-AN homepage).
                    .transition(.blurFade())
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: LandingCoordinateSpace.root)
        // SS-ALIVE: flat easeOut driver (no spring overshoot) to match the blur-fade feel.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: showingBrief)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: showWelcomeBack)
        // SS-AN: one flat, fast easeOut owns the home↔graph timing — no spring overshoot
        // (which popped) and no .scale (which folded the page). The greeting/buttons blur
        // away (removal) and the graph blurs in (insertion) via BlurFade: an Apple-style
        // blur-replace. reduceMotion → no animation (instant swap).
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.28),
            value: ui.homeContent
        )
        .onAppear {
            LandingViewStateSync.reassertHomeSurface(ui)
            scheduleWelcomeBackPresentationIfNeeded()
        }
        // Phase 1 — graphViewLocation mid-session flip handler. When the
        // user changes Settings → Graph → Graph view location while the
        // embedded graph is up, snap `ui.homeContent` back to `.greeting`
        // so the next ⌘G press opens the newly-chosen host from a clean
        // state. (If they flipped TO `.miniPanel`, the embedded graph
        // would otherwise stay visible behind a new floating panel.)
        .onReceive(
            NotificationCenter.default.publisher(for: .graphViewLocationDidChange)
        ) { _ in
            if ui.homeContent == .graph {
                withAnimation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.1)
                ) {
                    ui.homeContent = .greeting
                }
            }
        }
        .onChange(of: workspaceService.welcomeBack?.displayText ?? "") { _, _ in
            scheduleWelcomeBackSync()
        }
        .onDisappear {
            welcomeBackDismissTask?.cancel()
            welcomeBackDismissTask = nil
            welcomeBackSyncTask?.cancel()
            welcomeBackSyncTask = nil
            showWelcomeBack = false
            presentedWelcomeBack = nil
            landingStageRevealTask?.cancel()
            landingStageRevealTask = nil
            landingGreetingReturnTask?.cancel()
            landingGreetingReturnTask = nil
            activeLandingInlineCommand = nil
        }
        .background {
            // Hidden Cmd-N shortcut creates a Markdown note, then asks which surface to open.
            Button(action: {
                HapticHelper.homeCommand(.newNote)
                createAndOpenNote()
            }) {}
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            // Hidden ⌘G shortcut — graph toggle. Branches on
            // `graphState.graphViewLocation`:
            //   - `.miniPanel`: existing behavior (floating panel toggle)
            //   - `.embedded`: flips `ui.homeContent` between
            //     `.greeting` and `.graph` for the inline embed.
            Button(action: {
                HapticHelper.homeCommand(.graph)
                toggleGraphForCurrentLocation()
            }) {}
                .keyboardShortcut("g", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            // Hidden ⌘I shortcut — open Quick Capture immediately
            Button(action: {
                HapticHelper.homeCommand(.capture)
                openQuickCapture()
            }) {}
                .keyboardShortcut("i", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

        }
        .onKeyPress(.escape) {
            if showingLandingStageCommand {
                dismissLandingStageCommand()
                return .handled
            }
            if showWelcomeBack {
                dismissWelcomeBack()
                return .handled
            }
            if showingBrief {
                dailyBrief.dismissDailyBrief()
                return .handled
            }
            return .ignored
        }
        // Companion Farm sheets — destructive/restore actions still route through their own
        // canonical state surface (CompanionState + SovereignGate).
        .sheet(item: $farmDeleteTarget) { entry in
            if let bootstrap = AppBootstrap.shared {
                CompanionDeleteSheet(
                    entry: entry,
                    companionState: bootstrap.companionState,
                    sovereignGate: bootstrap.sovereignGate,
                    theme: theme,
                    onDismiss: { farmDeleteTarget = nil }
                )
            }
        }
        .sheet(isPresented: $farmShowingRestore) {
            if let bootstrap = AppBootstrap.shared {
                CompanionRestoreSheet(
                    companionState: bootstrap.companionState,
                    sovereignGate: bootstrap.sovereignGate,
                    theme: theme,
                    onDismiss: { farmShowingRestore = false }
                )
            }
        }
        .sheet(isPresented: $showingNewCodeFileSheet) {
            CodeFileCreationSheet(theme: theme) { request in
                createAndOpenCodeFile(request)
            }
        }
        .sheet(isPresented: $showingArxivSearch) {
            ArxivSearchView()
        }
        .alert("Plan 3 Feature", isPresented: $showingLandingFeatureStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(landingFeatureStatusMessage ?? "")
        }
    }

    private var landingBackdrop: some View {
        AppWindowBackdropStyle.background(for: theme)
            .ignoresSafeArea()
    }

    private var landingAmbientFrequencyMediaChip: some View {
        Button {
            UtilityWindowManager.shared.show(.settings)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.20 : 0.14))
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.resolved.accent.color)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ambientPlayback.landingMediaTitle)
                        .font(AppDisplayTypography.font(size: 12, weight: .semibold, allowDisplayFont: false))
                        .foregroundStyle(theme.textPrimary.opacity(theme.isDark ? 0.94 : 0.84))
                        .lineLimit(1)
                    Text(ambientPlayback.landingMediaSubtitle)
                        .font(AppDisplayTypography.font(size: 10, weight: .medium, allowDisplayFont: false))
                        .foregroundStyle(theme.textSecondary.opacity(theme.isDark ? 0.82 : 0.66))
                        .lineLimit(1)
                }

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary.opacity(0.72))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: 260, alignment: .leading)
            .background {
                Capsule()
                    .fill(theme.glassBg.opacity(theme.isDark ? 0.30 : 0.20))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                theme.resolved.accent.color.opacity(theme.isDark ? 0.24 : 0.18),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(
                        color: theme.resolved.accent.color.opacity(theme.isDark ? 0.16 : 0.10),
                        radius: 18,
                        y: 8
                    )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ambient Frequencies are playing")
        .help("Open Ambient Frequencies settings")
    }

    // MARK: - Greeting Content (normal landing state)

    private var greetingContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: showingLandingStageCommand ? 24 : 0)

            VStack(spacing: 18) {
                landingGreetingStage
            }
            .padding(.horizontal, Spacing.xxl)
            .allowsHitTesting(showingLandingStageCommand)

            Spacer(minLength: showingLandingStageCommand ? 42 : 0)

            VStack(spacing: 10) {
                landingFeatureShortcuts
                landingPixelCommands
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.bottom, 28)
        }
    }

    private var landingGreetingStage: some View {
        ZStack {
            LiquidGreeting(
                theme: theme,
                windowOccluded: ui.windowOccluded,
                typewriterEnabled: ui.landingGreetingTypewriterEnabled,
                retractNow: .constant(false),
                searchMode: showingLandingStageCommand,
                searchText: ""
            )
            .landingGreetingReturnReveal(frame: landingGreetingReturnFrame, theme: theme)
            .opacity(showingLandingStageCommand && landingStageRevealFrame > 0 ? 0 : 1)
            .allowsHitTesting(false)

            if let command = activeLandingInlineCommand {
                landingStageRevealContainer(accent: theme.resolved.accent.color) {
                    landingInlineCommandStage(for: command)
                }
                    .landingSearchStepReveal(frame: landingStageRevealFrame, theme: theme)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: landingStageMinHeight)
    }

    private func landingStageRevealContainer<Content: View>(
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
            LandingStageCommandPeak(accent: accent, theme: theme)
                .padding(.top, 5)
        }
    }

    @ViewBuilder
    private func landingInlineCommandStage(for command: LandingInlineCommand) -> some View {
        Group {
            switch command {
            case .quickCapture:
                QuickCaptureView(isPresented: landingInlineCommandBinding(for: .quickCapture))
                    .frame(width: 560, height: 340)
            case .workspaces:
                WorkspaceSwitcherOverlay(
                    isPresented: landingInlineCommandBinding(for: .workspaces),
                    presentation: .inline
                )
                .frame(width: 520, height: 370)
            case .saveWorkspace:
                SaveWorkspaceInlineView(isPresented: landingInlineCommandBinding(for: .saveWorkspace))
                    .frame(width: 480, height: 370)
            case .timeMachine:
                TimeMachineView(isPresented: landingInlineCommandBinding(for: .timeMachine))
                    .frame(width: 760, height: 410)
            }
        }
        .preferredColorScheme(landingInlineCommandSurfaceTheme.colorScheme)
    }

    private var landingPixelCommands: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 136, maximum: 176), spacing: 8)],
            spacing: 8
        ) {
            PixelLandingCommandTile(
                title: "quick capture",
                shortcut: "\u{2318}\u{21E7}N",
                glyph: .capture,
                theme: theme,
                accent: Color(hex: 0x4FB477),
                haptic: .capture,
                isActive: activeLandingInlineCommand == .quickCapture,
                action: { showLandingInlineCommand(.quickCapture) }
            )
            PixelLandingCommandTile(
                title: "goose",
                shortcut: "\u{2318}3",
                glyph: .agent,
                theme: theme,
                accent: theme.resolved.accent.color,
                haptic: .agent,
                action: openEpistemosGoose
            )
            PixelLandingCommandTile(
                title: "workspaces",
                shortcut: "^\u{2318}W",
                glyph: .workspace,
                theme: theme,
                accent: Color(hex: 0x4C8DFF),
                haptic: .workspace,
                isActive: activeLandingInlineCommand == .workspaces
            ) {
                showLandingInlineCommand(.workspaces)
            }
            PixelLandingCommandTile(
                title: "save workspace",
                shortcut: "^\u{2318}S",
                glyph: .save,
                theme: theme,
                accent: Color(hex: 0xE0A53C),
                haptic: .save,
                isActive: activeLandingInlineCommand == .saveWorkspace
            ) {
                showLandingInlineCommand(.saveWorkspace)
            }
            PixelLandingCommandTile(
                title: "time machine",
                shortcut: "^\u{2318}T",
                glyph: .clock,
                theme: theme,
                accent: Color(hex: 0xCF6F5F),
                haptic: .timeMachine,
                isActive: activeLandingInlineCommand == .timeMachine
            ) {
                showLandingInlineCommand(.timeMachine)
            }
            PixelLandingCommandTile(
                title: "notes",
                shortcut: "\u{2318}2",
                glyph: .notes,
                theme: theme,
                accent: Color(hex: 0x7E8CE0),
                haptic: .notes
            ) {
                UtilityWindowManager.shared.show(.notes)
            }
            PixelLandingCommandTile(
                title: "new note",
                shortcut: "\u{2318}N",
                glyph: .document,
                theme: theme,
                accent: Color(hex: 0x8ABF5D),
                haptic: .newNote,
                action: createAndOpenNote
            )
            PixelLandingCommandTile(
                title: "new code",
                shortcut: "\u{2325}\u{2318}C",
                glyph: .code,
                theme: theme,
                accent: Color(hex: 0x8C7AF5),
                haptic: .document
            ) {
                showingNewCodeFileSheet = true
            }
            PixelLandingCommandTile(
                title: "html workspace",
                shortcut: "\u{2325}\u{2318}H",
                glyph: .html,
                theme: theme,
                accent: Color(hex: 0xB37A3F),
                haptic: .workspace,
                action: createAndOpenHTMLWorkspace
            )
            PixelLandingCommandTile(
                title: graphState.graphViewLocation == .embedded ? "home graph" : "graph",
                shortcut: "\u{2318}G",
                glyph: .graph,
                theme: theme,
                accent: Color(hex: 0xD96B7E),
                haptic: .graph,
                action: toggleGraphForCurrentLocation
            )
        }
        .frame(maxWidth: 900)
    }

    private var landingFeatureShortcuts: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 136, maximum: 176), spacing: 8)],
            spacing: 8
        ) {
            ForEach(LandingFeatureButton.allCases) { feature in
                LandingFeatureButtonTile(feature: feature, theme: theme) {
                    performLandingFeatureButton(feature)
                }
            }
        }
        .frame(maxWidth: 900)
    }

    private func performLandingFeatureButton(_ feature: LandingFeatureButton) {
        guard feature.isAvailableInThisBuild else {
            presentLandingFeatureStatus(feature.unavailableMessage)
            return
        }

        switch feature {
        case .pdfImport:
            runLandingPDFImport()
        case .arxiv:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { ui.homeContent = .arxiv }
        case .provenance:
            UtilityWindowManager.shared.showSettings(section: .provenance)
        case .extensions, .vaultMCP:
            UtilityWindowManager.shared.showSettings(section: .skills)
        case .voice:
            UtilityWindowManager.shared.showSettings(section: .voice)
        case .browser:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { ui.homeContent = .browser }
        case .browserUsePro:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { ui.homeContent = .browserUsePro }
        case .meetingNote:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                ui.homeContent = .meeting
            }
        }
    }

    private func runLandingPDFImport() {
        guard let vaultURL = vaultSync.vaultURL else {
            presentLandingFeatureStatus("Connect a vault first, then import.")
            return
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Import"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let urls = panel.urls

        Task { @MainActor in
            var imported = 0
            var lines: [String] = []
            for url in urls {
                let gainedSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if gainedSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let outcome = await LiteParsePDFImportController.importPage(
                    pdfPath: url.path,
                    vaultURL: vaultURL,
                    modelContext: modelContext,
                    graphState: graphState
                )
                switch outcome {
                case .imported(_, let title, let sourcePDFRelativePath):
                    imported += 1
                    lines.append(Self.boundedLandingPDFImportStatusLine("✓ \(title) - Source PDF: \(sourcePDFRelativePath)"))
                case .rejected(let result):
                    lines.append(Self.boundedLandingPDFImportStatusLine(
                        "✗ \(url.lastPathComponent): \(landingPDFImportReason(for: result))"
                    ))
                }
            }
            presentLandingFeatureStatus(
                landingPDFImportSummary(imported: imported, total: urls.count, lines: lines)
            )
        }
    }

    private func presentLandingFeatureStatus(_ message: String) {
        landingFeatureStatusMessage = Self.boundedLandingFeatureStatus(message)
        showingLandingFeatureStatus = true
    }

    private func landingPDFImportSummary(imported: Int, total: Int, lines: [String]) -> String {
        let visibleLines = Array(lines.prefix(Self.maxLandingPDFImportStatusRows))
        var message = "Imported \(imported)/\(total)."
        if !visibleLines.isEmpty {
            message += "\n" + visibleLines.joined(separator: "\n")
        }
        let hiddenCount = max(0, lines.count - visibleLines.count)
        if hiddenCount > 0 {
            message += "\n+\(hiddenCount) more files"
        }
        return Self.boundedLandingFeatureStatus(message)
    }

    private static func boundedLandingFeatureStatus(_ message: String) -> String {
        rawBoundedLandingStatus(
            message,
            limit: maxLandingFeatureStatusCharacters,
            fallback: "Feature status unavailable."
        )
    }

    private static func boundedLandingPDFImportStatusLine(_ message: String) -> String {
        rawBoundedLandingStatus(
            message,
            limit: maxLandingPDFImportStatusLineCharacters,
            fallback: "PDF import status unavailable."
        )
    }

    private static func rawBoundedLandingStatus(
        _ value: String,
        limit: Int,
        fallback: String
    ) -> String {
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = LandingFeatureButtonTextPolicy.normalizedDisplayText(clipped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func landingPDFImportReason(for result: LiteParseImportResult) -> String {
        switch result {
        case .markdown:
            return "ok"
        case .notWired:
            return "PDF parser bridge is unavailable in this build."
        case .unsupported(let message), .failed(let message):
            return message
        }
    }

    private var landingCompanionDock: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer(minLength: 0)
                if let bootstrap = AppBootstrap.shared {
                    LandingFarmView(
                        companionState: bootstrap.companionState,
                        theme: theme,
                        isAnimationActive: false,
                        onCreate: presentFarmCompanionCreate,
                        onOpenTrash: { farmShowingRestore = true },
                        onRequestEdit: presentFarmCompanionEdit,
                        onRequestDelete: { entry in farmDeleteTarget = entry }
                    )
                    .padding(.top, 24)
                    .padding(.trailing, 28)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func showLandingInlineCommand(_ command: LandingInlineCommand) {
        guard !showingBrief && !showWelcomeBack else { return }
        landingStageRevealFrame = 0
        landingGreetingReturnTask?.cancel()
        landingGreetingReturnTask = nil
        landingGreetingReturnFrame = 0
        activeLandingInlineCommand = command
        runLandingStageReveal()
    }

    private func landingInlineCommandBinding(for command: LandingInlineCommand) -> Binding<Bool> {
        Binding(
            get: { activeLandingInlineCommand == command },
            set: { isPresented in
                if isPresented {
                    showLandingInlineCommand(command)
                } else if activeLandingInlineCommand == command {
                    dismissLandingInlineCommand()
                }
            }
        )
    }

    private func dismissLandingStageCommand() {
        dismissLandingInlineCommand()
    }

    private func dismissLandingInlineCommand(animateGreetingReturn: Bool = true) {
        activeLandingInlineCommand = nil
        landingStageRevealTask?.cancel()
        landingStageRevealTask = nil
        landingStageRevealFrame = 0
        if animateGreetingReturn {
            runLandingGreetingReturnReveal()
        }
        HomeWindowInputFocus.restoreAfterOverlayDismiss()
    }

    private func runLandingStageReveal() {
        landingStageRevealTask?.cancel()
        landingStageRevealTask = Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(220))
            }
            await PixelStepMotion.playLandingSearchReveal(reduceMotion: reduceMotion) { frame in
                landingStageRevealFrame = frame
            }
        }
    }

    private func runLandingGreetingReturnReveal() {
        landingGreetingReturnTask?.cancel()
        landingGreetingReturnFrame = 0
        landingGreetingReturnTask = Task { @MainActor in
            await PixelStepMotion.playLandingGreetingReturnReveal(reduceMotion: reduceMotion) { frame in
                landingGreetingReturnFrame = frame
            }
        }
    }

    private func scheduleWelcomeBackPresentationIfNeeded() {
        guard !showWelcomeBack, presentedWelcomeBack == nil else { return }
        guard let info = workspaceService.welcomeBack,
              !info.displayText.isEmpty else { return }

        welcomeBackDismissTask?.cancel()
        welcomeBackDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch is CancellationError {
                return
            } catch {
                let message = LandingDiagnostics.logMessage(
                    for: error,
                    fallback: "LandingView: failed to schedule welcome-back presentation"
                )
                Self.log.error(
                    "\(message, privacy: .public)"
                )
                return
            }

            guard let info = workspaceService.welcomeBack,
                  !info.displayText.isEmpty else {
                welcomeBackDismissTask = nil
                return
            }

            presentedWelcomeBack = info
            showWelcomeBack = true
            welcomeBackDismissTask = nil
            // Do NOT auto-dismiss — persist until user interacts (ESC, click, or button)
        }
    }

    private func scheduleWelcomeBackSync() {
        welcomeBackSyncTask?.cancel()
        welcomeBackSyncTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(60))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            syncWelcomeBackPresentation()
            welcomeBackSyncTask = nil
        }
    }

    private func syncWelcomeBackPresentation() {
        guard let info = workspaceService.welcomeBack,
              !info.displayText.isEmpty else {
            welcomeBackDismissTask?.cancel()
            welcomeBackDismissTask = nil
            if showWelcomeBack {
                showWelcomeBack = false
            }
            if presentedWelcomeBack != nil {
                presentedWelcomeBack = nil
            }
            return
        }

        if showWelcomeBack || presentedWelcomeBack != nil {
            guard presentedWelcomeBack?.displayText != info.displayText || !showWelcomeBack else { return }
            presentedWelcomeBack = info
            if !showWelcomeBack {
                showWelcomeBack = true
            }
        } else {
            scheduleWelcomeBackPresentationIfNeeded()
        }
    }

    private func presentFarmCompanionCreate() {
        farmEditTarget = nil
        farmShowingCreate = true
    }

    private func presentFarmCompanionEdit(_ entry: CompanionRosterEntry) {
        farmShowingCreate = false
        farmEditTarget = entry
    }

    private func dismissFarmCompanionEditor() {
        farmShowingCreate = false
        farmEditTarget = nil
    }

    // MARK: - Welcome Back Content

    private func welcomeBackContent(info: WelcomeBackInfo) -> some View {
        GeometryReader { proxy in
            let panelWidth = min(max(proxy.size.width - 64, 360), 760)
            let panelHeight = min(max(proxy.size.height - 140, 420), 560)

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { dismissWelcomeBack() }

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        PixelGlyph(kind: .workspace, accent: theme.resolved.accent.color, isActive: true)
                            .frame(width: 26, height: 26)

                        PixelPanelTitle(text: "Welcome Back", theme: theme, size: 17)

                        Spacer(minLength: 16)

                        Text("resume checkpoint")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.mutedForeground.opacity(theme.isDark ? 0.62 : 0.58))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                    Rectangle()
                        .fill(theme.textPrimary.opacity(theme.isDark ? 0.12 : 0.10))
                        .frame(height: 1)

                    HStack(spacing: 8) {
                        welcomeBackStatPill(
                            systemImage: "doc.text",
                            value: "\(info.noteCount)",
                            title: "notes"
                        )
                        welcomeBackStatPill(
                            systemImage: "message",
                            value: "\(info.chatCount)",
                            title: "chats"
                        )
                        welcomeBackStatPill(
                            systemImage: "network",
                            value: info.graphWasOpen ? "on" : "off",
                            title: "graph"
                        )
                        welcomeBackStatPill(
                            systemImage: "clock",
                            value: "\(info.sessionMinutes)m",
                            title: "session"
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                    ScrollView {
                        TypewriterPlainText(
                            content: info.displayText,
                            slowRate: 1,
                            mediumRate: 4,
                            fastRate: 10
                        )
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineSpacing(6)
                        .foregroundStyle(theme.textPrimary.opacity(theme.isDark ? 0.92 : 0.82))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 14)
                            Rectangle()
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 22)
                        }
                    }

                    Rectangle()
                        .fill(theme.textPrimary.opacity(theme.isDark ? 0.12 : 0.10))
                        .frame(height: 1)

                    HStack(spacing: 10) {
                        welcomeBackActionButton("Continue", systemImage: "arrow.right", isPrimary: true) {
                            dismissWelcomeBack()
                        }

                        welcomeBackActionButton("Save Note", systemImage: "doc.badge.plus") {
                            saveWelcomeBackAsNote(info: info)
                        }

                        welcomeBackActionButton("Workspaces", systemImage: "rectangle.3.group") {
                            dismissWelcomeBack()
                            NotificationCenter.default.post(name: .toggleWorkspaceSwitcher, object: nil)
                        }

                        Spacer(minLength: 8)

                        Text("esc / click outside")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.mutedForeground.opacity(0.34))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .frame(width: panelWidth, height: panelHeight)
                .pixelPanel(theme: theme, surface: welcomeBackPanelSurface(for: theme))
                .contentShape(Rectangle())
            }
        }
    }

    private func welcomeBackStatPill(systemImage: String, value: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color.opacity(theme.isDark ? 0.78 : 0.72))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary.opacity(theme.isDark ? 0.88 : 0.76))
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(theme.mutedForeground.opacity(theme.isDark ? 0.62 : 0.52))
        }
        .frame(minWidth: 90, minHeight: 30)
        .padding(.horizontal, 10)
        .background(theme.textPrimary.opacity(theme.isDark ? 0.06 : 0.045))
        .overlay {
            Rectangle()
                .stroke(theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.08), lineWidth: 1)
        }
    }

    private func welcomeBackActionButton(
        _ title: String,
        systemImage: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isPrimary
                    ? theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.14)
                    : theme.textPrimary.opacity(theme.isDark ? 0.055 : 0.04)
            )
            .foregroundStyle(
                isPrimary
                    ? theme.resolved.accent.color
                    : theme.textPrimary.opacity(theme.isDark ? 0.82 : 0.68)
            )
            .overlay {
                Rectangle()
                    .stroke(
                        isPrimary
                            ? theme.resolved.accent.color.opacity(theme.isDark ? 0.22 : 0.18)
                            : theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.08),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func welcomeBackPanelSurface(for theme: EpistemosTheme) -> Color {
        let base = theme.resolved.background.nsColor.usingColorSpace(.sRGB) ?? theme.resolved.background.nsColor
        let accent = theme.resolved.accent.nsColor.usingColorSpace(.sRGB) ?? base
        let target = theme.isDark
            ? (base.blended(withFraction: 0.10, of: NSColor.white) ?? base)
            : (base.blended(withFraction: 0.08, of: accent) ?? base)
        return Color(nsColor: target)
    }

    private func dismissWelcomeBack() {
        welcomeBackDismissTask?.cancel()
        welcomeBackDismissTask = nil
        welcomeBackSyncTask?.cancel()
        welcomeBackSyncTask = nil
        showWelcomeBack = false
        presentedWelcomeBack = nil
        workspaceService.welcomeBack = nil
    }

    private func saveWelcomeBackAsNote(info: WelcomeBackInfo) {
        Task { @MainActor in
            guard let bootstrap = AppBootstrap.shared else { return }
            let title = "Session Summary — \(Date.now.formatted(.dateTime.month(.abbreviated).day().year()))"
            var body = "# \(title)\n\n"
            if !info.displayText.isEmpty {
                body += "## Summary\n\(info.displayText)\n\n"
            }
            if !info.userNote.isEmpty {
                body += "## Session Note\n\(info.userNote)\n\n"
            }
            if !info.editedNoteTitles.isEmpty {
                body += "## Edited Notes\n" + info.editedNoteTitles.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
            }
            body += "## Stats\n"
            if info.noteCount > 0 { body += "- \(info.noteCount) notes open\n" }
            if info.chatCount > 0 { body += "- \(info.chatCount) chats\n" }
            if info.sessionMinutes > 0 { body += "- \(info.sessionMinutes) minutes\n" }

            if let pageId = await bootstrap.vaultSync.createPage(
                title: title,
                body: body,
                allowVaultSelectionPrompt: true
            ) {
                do {
                    try bootstrap.modelContainer.mainContext.save()
                } catch {
                    let message = LandingDiagnostics.logMessage(
                        for: error,
                        fallback: "LandingView: failed to save welcome-back summary note"
                    )
                    Self.log.error(
                        "\(message, privacy: .public)"
                    )
                }
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch is CancellationError {
                    // Continue opening the created note even if the pacing delay is cancelled.
                } catch {
                    let message = LandingDiagnostics.logMessage(
                        for: error,
                        fallback: "LandingView: failed to wait before opening welcome-back summary note"
                    )
                    Self.log.error(
                        "\(message, privacy: .public)"
                    )
                }
                NoteWindowManager.shared.open(pageId: pageId)
            }
            dismissWelcomeBack()
        }
    }

    // MARK: - Daily Brief Content (replaces greeting in-place)

    private var dailyBriefContent: some View {
        VStack(spacing: 0) {
            // Title — app display font, centered under nav bar
            Text("daily brief")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)
                .shadow(color: theme.isDark ? theme.fontAccent.opacity(0.12) : .clear, radius: 8)
                .padding(.top, 28)
                .padding(.bottom, 4)

            // Subtitle date
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                .padding(.bottom, 16)

            // Scrollable brief content
            if dailyBrief.isDailyBriefLoading {
                Spacer()
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(theme.fontAccent.opacity(0.6))
                    Text("Scanning your notes & conversations…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    GenUIDispatcher.shared.render(dailyBriefPayload)
                        .frame(maxWidth: 580, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                }
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black], startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 16)
                        Rectangle()
                        LinearGradient(
                            colors: [.black, .clear], startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 24)
                    }
                }
            }

            // Action buttons row
            HStack(spacing: 12) {
                // Back button
                Button {
                    dailyBrief.dismissDailyBrief()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .medium))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.resolved.foreground.color.opacity(0.06)))
                }
                .buttonStyle(.plain)

            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dailyBriefPayload: GenUIPayload {
        GenUIPayload.markdownCard(
            title: "Daily Brief",
            dailyBrief.dailyBriefContent,
            id: "landing-daily-brief",
            metadata: ["surface": "landing-daily-brief"]
        )
    }

    // MARK: - Actions

    /// Cmd+G dispatcher. Branches on `graphState.graphViewLocation` so
    /// the same hotkey opens whichever graph host the user has chosen
    /// in Settings → Graph → Graph view location:
    ///
    ///   - `.miniPanel`: existing behavior — toggles the floating
    ///     hologram overlay via `HologramController`.
    ///   - `.embedded`: toggles `ui.homeContent` between `.greeting`
    ///     and `.graph`, with a spring cross-fade animation.
    ///
    /// Phase 1 — when the user switches the setting mid-session, the
    /// `graphViewLocationDidChange` notification observer wired in
    /// `onAppear` snaps `ui.homeContent` back to `.greeting` so the
    /// home window is in a known state before the next press.
    private func toggleGraphForCurrentLocation() {
        KnowledgeGraphShortcutDispatcher.toggle(reduceMotion: reduceMotion)
    }

    private func createAndOpenNote() {
        Task {
            await NoteCreationCoordinator.createAndOpen(
                vaultSync: vaultSync,
                title: "New Note"
            )
        }
    }

    private func createAndOpenHTMLWorkspace() {
        do {
            try NSDocumentController.shared.createUntitledHTMLWorkspaceDocument(in: vaultSync.vaultURL)
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func openEpistemosGoose() {
        let availability = GooseSurfaceAvailability.current()
        guard availability.isReady else {
            let message = availability.unavailableMessage.isEmpty
                ? "Epistemos Goose is unavailable."
                : availability.unavailableMessage
            ui.showToast(message, type: .warning)
            return
        }

        // Owner: Goose animates to a PAGE in the home window (like the old chat),
        // not a separate window. The .goose branch in the home-content router hosts
        // AgentSurfaceRootView / GooseWebSurfaceView per AgentSurface.isEnabled().
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            ui.homeContent = .goose
        }
    }

    private func createAndOpenCodeFile(_ request: CodeFileCreationRequest) {
        guard let vaultURL = vaultSync.vaultURL else {
            ui.showToast("Select a vault before creating code files.", type: .warning)
            UtilityWindowManager.shared.show(.notes)
            return
        }
        do {
            let pageId = try CodeFileCreationController.createPage(
                request: request,
                vaultURL: vaultURL,
                modelContext: modelContext,
                graphState: graphState
            )
            NoteWindowManager.shared.open(pageId: pageId)
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func openQuickCapture() {
        showLandingInlineCommand(.quickCapture)
    }

    // MARK: - Daily Brief Prompt

    private func buildDailyBriefPrompt() -> String {
        DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: [])
    }
}
