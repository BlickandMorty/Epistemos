import AppKit
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum LandingShortcutDisplay {
    static let fontSize: CGFloat = 12
    static let keyHorizontalPadding: CGFloat = 7
    static let keyVerticalPadding: CGFloat = 4
    static let keyCornerRadius: CGFloat = 7
    static let multiCharacterKeyMinWidth: CGFloat = 48
    static let shortcutRowSpacing: CGFloat = 12

    static func label(_ text: String) -> String {
        text.lowercased()
    }

    static func font(weight: Font.Weight = .medium) -> Font {
        AppDisplayTypography.font(size: fontSize, weight: weight, allowDisplayFont: false)
    }

    static func nsFont(weight: NSFont.Weight = .medium) -> NSFont {
        AppDisplayTypography.regularUIFont(size: fontSize, weight: weight)
    }

    static func keyMinWidth(for text: String?) -> CGFloat? {
        guard let text, text.count > 1 else { return nil }
        return multiCharacterKeyMinWidth
    }
}

enum LandingSearchLayout {
    static let maxWidth: CGFloat = 900
    static let stageWidth: CGFloat = 760
    static let searchLineWidth: CGFloat = 720
    static let topRowSpacing: CGFloat = 14
    static let controlRowSpacing: CGFloat = 8
    static let controlRowTopPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 18
    static let cornerRadius: CGFloat = 24
    static let inputFontSize: CGFloat = 24
    static let inputMinHeight: CGFloat = ChatComposerInputMetrics.minHeight(for: inputFontSize)
}

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
// Clean landing: liquid glass greeting with shortcut hints.

struct LandingView: View {
    private static let log = Logger(subsystem: "com.epistemos", category: "LandingView")

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(ChatState.self) private var chat
    @Environment(InferenceState.self) private var inference
    @Environment(OrchestratorState.self) private var orchestrator
    @Environment(AgentCommandCenterState.self) private var agentCommandCenter
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(WorkspaceService.self) private var workspaceService
    @Environment(DailyBriefState.self) private var dailyBrief
    @Environment(GraphState.self) private var graphState
    @Environment(ContextualShadowsState.self) private var contextualShadows
    @Environment(AmbientFrequencyPlaybackState.self) private var ambientPlayback
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var mainChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue

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

    // Inline search state
    @State private var showingSearchPopover = false
    @State private var landingSearchText = ""
    @State private var landingComposerHeight: CGFloat = LandingSearchLayout.inputMinHeight
    @State private var isLandingSearchFocused = false
    @State private var showLandingMentionDropdown = false
    @State private var landingMentionFilter = ""
    @State private var landingMentionKeyboardIndex = 0
    @State private var landingMentionPickerAutofocus = false
    @State private var showLandingSlashMenu = false
    @State private var landingSlashFilter = ""
    @State private var landingSlashKeyboardIndex = 0
    @State private var selectedLandingSlashCommand: ACCSlashCommand?
    @State private var landingReferencePopoverStyle: ComposerReferencePopoverStyle = .mention
    @State private var landingReferenceSearch = ComposerReferenceSearchState()
    @State private var landingContextAttachments: [ContextAttachment] = []
    @State private var landingFileAttachments: [FileAttachment] = []
    @State private var landingToolsExpanded = false
    @State private var landingSearchLabelHovered = false
    @State private var landingVoiceDraftPrefix: String?
    @State private var landingRecallDebounceBox = ChatRecallDebounceBox()
    @State private var landingSearchRevealFrame = 0
    @State private var landingSearchRevealTask: Task<Void, Never>?
    @State private var landingGreetingReturnFrame = 4
    @State private var landingGreetingReturnTask: Task<Void, Never>?
    @State private var activeLandingInlineCommand: LandingInlineCommand?
    @State private var showingNewCodeFileSheet = false
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.landing) }
    private var landingInlineCommandSurfaceTheme: EpistemosTheme {
        LandingCommandThemeTreatment.resolve(for: theme).chromeTheme(for: theme)
    }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }
    private var showingOverlay: Bool { showingBrief || showWelcomeBack }
    private var showingLandingStageCommand: Bool {
        showingSearchPopover || activeLandingInlineCommand != nil
    }
    private var landingRecallScopeID: String {
        "landing:\(chat.activeChatId ?? "draft")"
    }
    private var landingRecallPayload: ContextualShadowsState.RecallPayload {
        contextualShadows.payload(kind: .chat, originDocId: landingRecallScopeID)
    }
    private var landingStageMinHeight: CGFloat {
        if showingSearchPopover {
            return landingToolsExpanded ? 330 : 250
        }
        return activeLandingInlineCommand?.minStageHeight ?? 220
    }
    private var trimmedLandingSearchText: String {
        landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var landingSearchAttachmentHint: String {
        ComposerAttachmentEntryHints.landingPlaceholder
    }
    private var landingSearchPlaceholder: String {
        if let name = AppBootstrap.shared?.companionState.activeAgentName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ask \(name)..."
        }
        return "Ask Epistemos..."
    }
    private var ambientManifest: VaultManifest? {
        vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest
    }
    private var supportedOperatingModes: [EpistemosOperatingMode] {
        MainChatOperatingModePreference.supportedModes(for: inference)
    }
    private var supportedLandingSlashCommands: [ACCSlashCommand] {
        ACCSlashCommand.availableCommands(
            for: MainChatOperatingModePreference.supportedModes(
                for: inference,
                availableModes: supportedOperatingModes
            )
        )
    }
    private var activeSelectedLandingSlashCommand: ACCSlashCommand? {
        guard let selectedLandingSlashCommand,
              supportedLandingSlashCommands.contains(selectedLandingSlashCommand) else {
            return nil
        }
        return selectedLandingSlashCommand
    }
    private var filteredLandingSlashCommands: [ACCSlashCommand] {
        SlashCommandPopover.filteredCommands(
            commands: supportedLandingSlashCommands,
            filter: landingSlashFilter
        )
    }
    private var highlightedLandingSlashCommand: ACCSlashCommand? {
        guard !filteredLandingSlashCommands.isEmpty else { return nil }
        return filteredLandingSlashCommands[
            clampedLandingKeyboardIndex(
                landingSlashKeyboardIndex,
                count: filteredLandingSlashCommands.count
            )
        ]
    }

    private var incognitoBinding: Binding<Bool> {
        Binding(
            get: { chat.isIncognito },
            set: { chat.isIncognito = $0 }
        )
    }
    private var selectedOperatingMode: EpistemosOperatingMode {
        get {
            MainChatOperatingModePreference.sanitize(
                EpistemosOperatingMode(rawValue: mainChatOperatingModeRaw) ?? .fast,
                for: inference
            )
        }
        nonmutating set {
            mainChatOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                newValue,
                for: inference
            ).rawValue
        }
    }
    private var landingIsCloudSelection: Bool {
        switch inference.preferredChatModelSelection {
        case .cloud: true
        case .localMLX, .appleIntelligence: false
        }
    }
    private var landingEffectiveCapability: ChatCapability {
        if chat.isAgentExecuting {
            return chat.currentCapability
        }
        guard !trimmedLandingSearchText.isEmpty else {
            return chat.currentCapability
        }
        return ChatCapability.predictIntent(
            text: trimmedLandingSearchText,
            isCloudProvider: landingIsCloudSelection
        ).predicted
    }
    private var landingAttachmentCount: Int {
        landingContextAttachments.count + landingFileAttachments.count
    }
    private var landingAllNotesContextAttached: Bool {
        landingContextAttachments.contains { $0.kind == .allNotes }
    }
    private var operatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { selectedOperatingMode },
            set: { selectedOperatingMode = $0 }
        )
    }
    private var landingMentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        ChatCoordinator.searchReferenceResults(
            filter: landingMentionFilter,
            manifest: ambientManifest,
            chats: recentChats(limit: 20),
            threads: AppBootstrap.shared?.threadState.chatThreads ?? [],
            indexedNoteIDs: landingReferenceSearch.indexedNoteIDs,
            indexedNoteSnippets: landingReferenceSearch.indexedNoteSnippetsByPageID
        )
    }
    private var landingMentionKeyboardChoices: [ComposerReferenceChoice] {
        ComposerReferenceKeyboardSelection.choices(
            from: landingMentionSearchResults,
            style: landingReferencePopoverStyle
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            landingBackdrop
                .zIndex(-1)
                .allowsHitTesting(false)

            // ── Background Tap Layer ──
            // Click anywhere on empty landing area opens the search popover.
            // Greeting shortcut buttons sit above this at zIndex 1 and handle
            // their own clicks first, so only background taps fall through.
            // Suppressed while any overlay (brief / welcome back / search) is
            // up so it can't re-trigger search when user taps the scrim.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !showingOverlay else { return }
                    if showingLandingStageCommand {
                        dismissLandingStageCommand()
                        return
                    }
                    activateLandingSearch()
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
                        .opacity.combined(with: .scale(scale: 0.94))
                    )
                    .zIndex(1)
            case .graph:
                HomeGraphEmbeddedView()
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.94))
                    )
                    .zIndex(1)
            }

            // Agent dock — hidden when the embedded graph is up so it
            // doesn't compete with the graph's right-side inspector.
            if ui.homeContent == .greeting && !showingLandingStageCommand {
                landingAgentDock
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
                    .onTapGesture { dismissFarmAgentEditor() }
                    .zIndex(3.5)

                CompanionCreationFlow(
                    companionState: bootstrap.companionState,
                    theme: theme,
                    editingEntry: farmEditTarget,
                    availableBrains: agentCommandCenter.availableBrains,
                    availableTools: agentCommandCenter.availableTools,
                    onDismiss: dismissFarmAgentEditor
                )
                .transition(.opacity)
                .zIndex(4)
            }

            // ── Daily Brief Mode ──
            // Fades in on top of the blurred greeting.
            if showingBrief {
                dailyBriefContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(3)
            }

            // ── Welcome Back Mode ──
            // Shows after workspace auto-restore with session summary.
            if showWelcomeBack, let info = presentedWelcomeBack {
                welcomeBackContent(info: info)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: LandingCoordinateSpace.root)
        .animation(reduceMotion ? nil : Motion.smooth, value: showingBrief)
        .animation(reduceMotion ? nil : Motion.smooth, value: showWelcomeBack)
        // Landing-wave emergence: snappier spring (response 0.18, damping 0.78)
        // chosen per user feedback that the prior Motion.smooth curve felt
        // "lack luster." Bar pops out, slight overshoot, quick settle.
        // Suppressed entirely under Reduce Motion.
        .animation(
            reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.78),
            value: showingSearchPopover
        )
        // 2026-05-20 Phase 1 — home content router cross-fade. The
        // 0.42s / 0.84 damping spring matches Apple's view-transition
        // feel (App Switcher push, Notification Center reveal): a
        // brief overshoot, no bounce, lands clean. Greeting fades +
        // scales OUT while the embedded graph fades + scales IN, both
        // simultaneously (the cross-fade is what makes it feel native).
        .animation(
            reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.1),
            value: ui.homeContent
        )
        .onAppear {
            LandingViewStateSync.reassertHomeSurface(ui)
            sanitizeStoredOperatingMode()
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
        .onChange(of: inference.preferredChatModelSelection.rawValue) { _, _ in
            sanitizeStoredOperatingMode()
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
            showingSearchPopover = false
            onLandingPopoverDisappear()
            landingSearchRevealTask?.cancel()
            landingSearchRevealTask = nil
            landingGreetingReturnTask?.cancel()
            landingGreetingReturnTask = nil
            activeLandingInlineCommand = nil
        }
        .background {
            // Hidden ⌘N shortcut — creates new note and teleports there
            Button(action: {
                HapticHelper.homeCommand(.newNote)
                createAndOpenNote()
            }) {}
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            Button(action: {
                HapticHelper.homeCommand(.document)
                createAndOpenDocument()
            }) {}
                .keyboardShortcut("n", modifiers: [.command, .option])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            Button(action: {
                HapticHelper.homeCommand(.miniChat)
                MiniChatWindowController.shared.openNewChat()
            }) {}
                .keyboardShortcut("3", modifiers: .command)
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
            if ui.showChatSidebar {
                ui.dismissChatSidebar()
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

            landingPixelCommands
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, 28)
        }
    }

    private var landingGreetingStage: some View {
        ZStack {
            LiquidGreeting(
                retractNow: .constant(false),
                searchMode: showingLandingStageCommand,
                searchText: ""
            )
            .landingGreetingReturnReveal(frame: landingGreetingReturnFrame, theme: theme)
            .opacity(showingLandingStageCommand && landingSearchRevealFrame > 0 ? 0 : 1)
            .allowsHitTesting(false)

            if showingSearchPopover {
                landingStageRevealContainer(accent: theme.resolved.accent.color) {
                    landingSearchInlineStage
                }
                    .landingSearchStepReveal(frame: landingSearchRevealFrame, theme: theme)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if let command = activeLandingInlineCommand {
                landingStageRevealContainer(accent: theme.resolved.accent.color) {
                    landingInlineCommandStage(for: command)
                }
                    .landingSearchStepReveal(frame: landingSearchRevealFrame, theme: theme)
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

    private var landingSearchInlineStage: some View {
        landingSearchStageTools
            .frame(
                width: LandingSearchLayout.stageWidth,
                height: landingToolsExpanded ? 328 : 236
            )
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
                title: "search",
                shortcut: "click",
                glyph: .search,
                theme: theme,
                accent: theme.resolved.accent.color,
                haptic: .search,
                isActive: showingSearchPopover,
                action: { activateLandingSearch(playHaptic: false) }
            )
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
                title: "mini chat",
                shortcut: "\u{2318}3",
                glyph: .chat,
                theme: theme,
                accent: Color(hex: 0x62B7C7),
                haptic: .miniChat
            ) {
                MiniChatWindowController.shared.openNewChat()
            }
            PixelLandingCommandTile(
                title: "new doc",
                shortcut: "\u{2325}\u{2318}N",
                glyph: .document,
                theme: theme,
                accent: Color(hex: 0xC985D8),
                haptic: .document,
                action: createAndOpenDocument
            )
            PixelLandingCommandTile(
                title: "new code",
                shortcut: "\u{2325}\u{2318}C",
                glyph: .document,
                theme: theme,
                accent: Color(hex: 0x8C7AF5),
                haptic: .document
            ) {
                showingNewCodeFileSheet = true
            }
            PixelLandingCommandTile(
                title: "html workspace",
                shortcut: "\u{2325}\u{2318}H",
                glyph: .workspace,
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

    private var landingAgentDock: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer(minLength: 0)
                if let bootstrap = AppBootstrap.shared {
                    LandingFarmView(
                        companionState: bootstrap.companionState,
                        theme: theme,
                        isAnimationActive: false,
                        onCreate: presentFarmAgentCreate,
                        onOpenTrash: { farmShowingRestore = true },
                        onRequestEdit: presentFarmAgentEdit,
                        onRequestDelete: { entry in farmDeleteTarget = entry },
                        onStartChat: startFarmAgentChat
                    )
                    .padding(.top, 24)
                    .padding(.trailing, 28)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var landingSearchStageTools: some View {
        VStack(spacing: 13) {
            landingSearchInputLine
                .zIndex(2)

            HStack(spacing: 12) {
                landingSearchBrainTool
                landingSearchToolsToggle
            }
            .frame(maxWidth: LandingSearchLayout.searchLineWidth)
            .zIndex(3)

            if landingToolsExpanded {
                landingSearchExpandedToolRow
                    .zIndex(3)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(width: LandingSearchLayout.stageWidth)
        .animation(reduceMotion ? nil : Motion.micro, value: landingToolsExpanded)
    }

    private var landingSearchBrainTool: some View {
        ChatBrainPickerMenu(
            operatingMode: operatingModeBinding,
            availableOperatingModes: supportedOperatingModes,
            isTemporaryChatEnabled: incognitoBinding,
            preferSplitToolbarControls: false
        )
        .controlSize(.regular)
        .fixedSize()
    }

    private var landingSearchCommandTool: some View {
        LandingStageToolTile(
            title: activeSelectedLandingSlashCommand.map { "/\($0.rawValue)" } ?? "Command",
            systemImage: "command",
            theme: theme,
            accent: Color(hex: 0x7E8CE0),
            action: openLandingSlashCommandMenu
        )
        .help(activeSelectedLandingSlashCommand?.helpText ?? "Open slash commands")
    }

    private var landingSearchMentionTool: some View {
        LandingStageToolTile(
            title: "Mention",
            systemImage: "at",
            theme: theme,
            accent: Color(hex: 0x62B7C7),
            action: insertLandingMentionToken
        )
        .help("Reference a note or chat")
    }

    private var landingSearchAttachTool: some View {
        LandingStageToolTile(
            title: "Attach",
            systemImage: "paperclip",
            theme: theme,
            accent: Color(hex: 0x4C8DFF),
            action: openLandingFilePicker
        )
        .help("Attach a file")
    }

    private var landingSearchSavedTool: some View {
        LandingStageToolTile(
            title: chat.isIncognito ? "Temporary" : "Saved",
            systemImage: chat.isIncognito ? "eye.slash.fill" : "tray.full",
            theme: theme,
            accent: Color(hex: 0x4FB477),
            isActive: chat.isIncognito
        ) {
            incognitoBinding.wrappedValue.toggle()
        }
        .help(chat.isIncognito ? "Temporary chat is on" : "Save this chat")
    }

    private var landingSearchToolsToggle: some View {
        LandingStageToolTile(
            title: landingToolsExpanded ? "Less" : "Tools",
            systemImage: "wand.and.stars",
            theme: theme,
            accent: Color(hex: 0xC985D8),
            isActive: landingToolsExpanded
        ) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                landingToolsExpanded.toggle()
            }
        }
        .help(landingToolsExpanded ? "Hide secondary tools" : "Show secondary tools")
    }

    private var landingSearchSendTool: some View {
        AssistantSendButton(
            theme: theme,
            isEnabled: !trimmedLandingSearchText.isEmpty,
            isProcessing: false,
            metrics: .compactChat
        ) {
            submitLandingSearch()
        }
        .help("Send")
        .accessibilityLabel("Send prompt")
    }

    private var landingSearchExpandedToolRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                landingSearchCommandTool
                landingSearchMentionTool
                landingSearchAttachTool
                landingSearchSavedTool
            }
            .frame(maxWidth: LandingSearchLayout.searchLineWidth)

            HStack(spacing: 10) {
                LandingStageToolTile(
                    title: landingAllNotesContextAttached
                        ? "All Notes"
                        : landingAttachmentCount == 0
                            ? "All Notes"
                            : "\(landingAttachmentCount) Attached",
                    systemImage: landingAllNotesContextAttached ? "books.vertical.fill" : "books.vertical",
                    theme: theme,
                    accent: Color(hex: 0xE0A53C),
                    isActive: landingAllNotesContextAttached,
                    action: toggleLandingAllNotesContext
                )
                .help(landingAllNotesContextAttached ? "Remove all-notes context" : "Attach all notes")

                LandingStageToolShell(theme: theme, accent: Color(hex: 0xD96B7E)) {
                    ChatCapabilityPill(capability: landingEffectiveCapability)
                }

                LandingStageToolShell(theme: theme, accent: Color(hex: 0x62B7C7)) {
                    if #available(macOS 26.0, *) {
                        VoiceInputButton(
                            style: .iconWithPulse,
                            autoStopOnSilence: VoicePreferences.shared.dictationAutoStop == .auto,
                            onPartial: { partial in
                                applyLandingVoicePartial(partial)
                            },
                            onFinal: { final in
                                commitLandingVoiceTranscript(final)
                            }
                        )
                    } else {
                        ComposerMicButton { transcript in
                            commitLandingVoiceTranscript(transcript)
                        }
                    }
                }

                if contextualShadows.isEnabled, landingRecallPayload.hasPanelPayload {
                    LandingStageToolShell(theme: theme, accent: theme.fontAccent) {
                        ContextualShadowsButton(scopeKind: .chat, scopeID: landingRecallScopeID)
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: LandingSearchLayout.searchLineWidth)
        }
    }

    private struct LandingStageToolTile: View {
        let title: String
        let systemImage: String
        let theme: EpistemosTheme
        let accent: Color
        var isActive = false
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                LandingStageToolLabel(
                    title: title,
                    systemImage: systemImage,
                    theme: theme,
                    accent: accent,
                    isActive: isActive
                )
            }
            .buttonStyle(.plain)
        }
    }

    private struct LandingStageToolShell<Content: View>: View {
        let theme: EpistemosTheme
        let accent: Color
        @ViewBuilder let content: () -> Content

        var body: some View {
            content()
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(minHeight: 34)
                .foregroundStyle(theme.textSecondary.opacity(theme.isDark ? 0.86 : 0.78))
                .contentShape(Rectangle())
        }
    }

    private struct LandingStageToolLabel: View {
        let title: String
        let systemImage: String
        let theme: EpistemosTheme
        let accent: Color
        let isActive: Bool

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(accent.opacity(isActive ? 1 : 0.86))
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary.opacity(isActive ? 0.92 : (theme.isDark ? 0.78 : 0.68)))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(minHeight: 34)
            .overlay(alignment: .bottom) {
                if isActive {
                    Rectangle()
                        .fill(accent.opacity(theme.isDark ? 0.62 : 0.48))
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private var landingSearchInputLine: some View {
        VStack(spacing: 8) {
            landingInlineContextChips

            HStack(alignment: .center, spacing: 12) {
                PixelGlyph(kind: .search, accent: theme.resolved.accent.color)
                    .frame(width: 30, height: 30)
                    .scaleEffect(landingSearchLabelHovered || isLandingSearchFocused ? 1.06 : 1)

                ZStack(alignment: .topLeading) {
                    ChatComposerTextEditor(
                        text: $landingSearchText,
                        height: $landingComposerHeight,
                        isFocused: $isLandingSearchFocused,
                        theme: theme,
                        fontSize: LandingSearchLayout.inputFontSize,
                        isProcessing: false,
                        onCommand: { selector, modifierFlags in
                            handleLandingComposerCommand(selector, modifierFlags: modifierFlags)
                        }
                    ) {
                        submitLandingSearch()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: landingComposerHeight)
                    .frame(
                        minHeight: LandingSearchLayout.inputMinHeight,
                        alignment: .topLeading
                    )
                    .onExitCommand { dismissLandingSearch() }
                    .onChange(of: landingSearchText) { _, newValue in
                        handleLandingSearchTextChange(newValue)
                    }
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(40))
                            isLandingSearchFocused = true
                        }
                    }
                    .accessibilityLabel("Landing search input")
                    .accessibilityHint(landingSearchAttachmentHint)

                    if landingSearchText.isEmpty {
                        Text(ComposerAttachmentEntryHints.mainChatPlaceholder + "  Auto-routes when your prompt needs tools or a longer run.")
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.textSecondary.opacity(theme.isDark ? 0.34 : 0.28))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                            .padding(.leading, ChatComposerInputMetrics.horizontalInset)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }

                Spacer(minLength: 0)

                Text("esc")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary.opacity(0.70))
                    .padding(.trailing, 2)

                landingSearchSendTool
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: LandingSearchLayout.searchLineWidth)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.glassBg.opacity(theme.isDark ? 0.18 : 0.10))
                    .opacity(landingSearchLabelHovered || isLandingSearchFocused ? 1 : 0.34)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        theme.fontAccent.opacity(
                            landingSearchLabelHovered || isLandingSearchFocused
                                ? (theme.isDark ? 0.18 : 0.22)
                                : (theme.isDark ? 0.08 : 0.11)
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: theme.isDark
                    ? Color.black.opacity(landingSearchLabelHovered || isLandingSearchFocused ? 0.20 : 0.08)
                    : theme.fontAccent.opacity(landingSearchLabelHovered || isLandingSearchFocused ? 0.12 : 0.04),
                radius: landingSearchLabelHovered || isLandingSearchFocused ? 16 : 8,
                x: 0,
                y: landingSearchLabelHovered || isLandingSearchFocused ? 8 : 3
            )
            .scaleEffect(landingSearchLabelHovered ? 1.012 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture { isLandingSearchFocused = true }
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.16)) {
                    landingSearchLabelHovered = hovering
                }
            }
            .popover(isPresented: $showLandingSlashMenu, arrowEdge: .top) {
                SlashCommandPopover(
                    commands: supportedLandingSlashCommands,
                    filter: landingSlashFilter,
                    selectedCommand: highlightedLandingSlashCommand,
                    onSelect: { command in
                        applyLandingSlashCommand(command)
                    }
                )
            }
            .overlay(alignment: .topLeading) {
                if showLandingMentionDropdown {
                    ComposerReferencePopover(
                        isPresented: $showLandingMentionDropdown,
                        results: landingMentionSearchResults,
                        query: $landingMentionFilter,
                        manifest: ambientManifest,
                        modelContext: modelContext,
                        idealWidth: landingReferencePopoverStyle.idealWidth,
                        maxHeight: landingReferencePopoverStyle.maxHeight,
                        style: landingReferencePopoverStyle,
                        autofocusSearchField: landingMentionPickerAutofocus,
                        onDismiss: dismissLandingReferencePopover,
                        onSelect: attachLandingMentionReference
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                ContextualShadowsPanel(
                    scopeKind: .chat,
                    scopeID: landingRecallScopeID,
                    presentation: .landing,
                    onOpen: openLandingContextualShadowHit
                )
                    .padding(.leading, 42)
                    .padding(.top, 74)
                    .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var landingInlineContextChips: some View {
        if !landingContextAttachments.isEmpty || !landingFileAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(landingContextAttachments) { attachment in
                        landingContextChip(
                            title: attachment.title,
                            systemImage: attachment.systemImageName,
                            isWarning: false
                        ) {
                            removeLandingContextAttachment(attachment.id)
                        }
                        .help("Attached \(attachment.title)")
                    }

                    ForEach(landingFileAttachments) { attachment in
                        let isSupported = inference.chatSurfaceSupportedFileTypes(
                            for: selectedOperatingMode
                        ).contains(attachment.type)
                        landingContextChip(
                            title: attachment.name,
                            systemImage: landingIconForType(attachment.type),
                            isWarning: !isSupported
                        ) {
                            removeLandingFileAttachment(attachment.id)
                        }
                        .help(isSupported ? attachment.name : "Current model doesn't support \(attachment.type.rawValue) files")
                    }
                }
                .padding(.horizontal, Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Attached references")
        }
    }

    private func landingContextChip(
        title: String,
        systemImage: String,
        isWarning: Bool,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            if isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
            }
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(title)")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            isWarning ? Color.orange.opacity(0.12) : theme.textSecondary.opacity(0.08),
            in: Capsule()
        )
        .foregroundStyle(isWarning ? Color.orange : theme.textSecondary)
    }

    private func insertLandingMentionToken() {
        if !landingSearchText.hasSuffix("@") {
            if !landingSearchText.isEmpty,
               landingSearchText.last?.isWhitespace == false {
                landingSearchText.append(" ")
            }
            landingSearchText.append("@")
        }
        handleLandingSearchTextChange(landingSearchText)
        isLandingSearchFocused = true
    }

    private func activateLandingSearch(playHaptic: Bool = true) {
        guard !showingBrief && !showWelcomeBack else { return }
        if showingSearchPopover {
            isLandingSearchFocused = true
            return
        }
        if playHaptic {
            HapticHelper.homeCommand(.search)
        }
        if activeLandingInlineCommand != nil {
            dismissLandingInlineCommand(animateGreetingReturn: false)
        }
        landingSearchRevealFrame = 0
        landingGreetingReturnTask?.cancel()
        landingGreetingReturnTask = nil
        landingGreetingReturnFrame = 0
        landingToolsExpanded = false
        showingSearchPopover = true
        runLandingSearchReveal()
        Task { @MainActor in
            await Task.yield()
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch is CancellationError {
                return
            } catch {
                Self.log.error(
                    "LandingView: failed to schedule landing search focus: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            guard showingSearchPopover else { return }
            isLandingSearchFocused = true
        }
    }

    private func showLandingInlineCommand(_ command: LandingInlineCommand) {
        guard !showingBrief && !showWelcomeBack else { return }
        if showingSearchPopover {
            dismissLandingSearch(animateGreetingReturn: false)
        }
        landingSearchRevealFrame = 0
        landingGreetingReturnTask?.cancel()
        landingGreetingReturnTask = nil
        landingGreetingReturnFrame = 0
        activeLandingInlineCommand = command
        runLandingSearchReveal()
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
        if showingSearchPopover {
            dismissLandingSearch()
        } else {
            dismissLandingInlineCommand()
        }
    }

    private func dismissLandingInlineCommand(animateGreetingReturn: Bool = true) {
        activeLandingInlineCommand = nil
        landingSearchRevealTask?.cancel()
        landingSearchRevealTask = nil
        landingSearchRevealFrame = 0
        if animateGreetingReturn {
            runLandingGreetingReturnReveal()
        }
        HomeWindowInputFocus.restoreAfterOverlayDismiss()
    }

    private func runLandingSearchReveal() {
        landingSearchRevealTask?.cancel()
        landingSearchRevealTask = Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(220))
            }
            await PixelStepMotion.playLandingSearchReveal(reduceMotion: reduceMotion) { frame in
                landingSearchRevealFrame = frame
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

    private func handleLandingSearchTextChange(_ newValue: String) {
        refreshLandingSlashMenu(for: newValue)
        scheduleLandingContextualShadowsRecall(for: newValue)
        if let filter = ComposerReferenceHelpers.mentionFilter(in: newValue) {
            landingReferencePopoverStyle = .mention
            landingMentionFilter = filter
            landingMentionKeyboardIndex = 0
            landingMentionPickerAutofocus = false
            showLandingMentionDropdown = true
            updateLandingReferenceSearch(filter: filter)
        } else {
            showLandingMentionDropdown = false
            landingReferencePopoverStyle = .mention
            landingMentionKeyboardIndex = 0
            landingMentionPickerAutofocus = false
            landingMentionFilter = ""
            landingReferenceSearch.reset()
        }
    }

    private func scheduleLandingContextualShadowsRecall(for snapshotText: String) {
        landingRecallDebounceBox.task?.cancel()
        guard contextualShadows.isEnabled else { return }
        guard let bootstrap = AppBootstrap.shared else { return }
        let instantRecall = bootstrap.instantRecallService
        let searchIndexService = bootstrap.vaultSync.searchService
        let activeChatId = chat.activeChatId
        let scopeID = landingRecallScopeID
        let originId = activeChatId.flatMap(UUID.init(uuidString:)) ?? UUID()
        let state = contextualShadows
        landingRecallDebounceBox.task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let snapshot = RecallContextSnapshot(
                text: snapshotText,
                kind: .chat,
                originId: originId,
                originDocId: scopeID
            )
            state.requestRecall(
                snapshot: snapshot,
                instantRecall: instantRecall,
                searchIndexService: searchIndexService
            )
        }
    }

    private func refreshLandingSlashMenu(for newValue: String) {
        let trimmedLeading = newValue.drop(while: \.isWhitespace)
        guard trimmedLeading.first == "/" else {
            if showLandingSlashMenu {
                showLandingSlashMenu = false
                landingSlashFilter = ""
                landingSlashKeyboardIndex = 0
            }
            return
        }
        let afterSlash = String(trimmedLeading.dropFirst())
        if !afterSlash.isEmpty {
            selectedLandingSlashCommand = nil
        }
        if afterSlash.contains(where: { $0.isWhitespace || $0.isNewline }) {
            showLandingSlashMenu = false
            landingSlashFilter = ""
            landingSlashKeyboardIndex = 0
            return
        }
        landingSlashFilter = afterSlash
        landingSlashKeyboardIndex = 0
        showLandingSlashMenu = true
    }

    private func applyLandingSlashCommand(_ command: ACCSlashCommand) {
        selectedOperatingMode = MainChatOperatingModePreference.sanitize(
            command.defaultOperatingMode,
            for: inference,
            availableModes: supportedOperatingModes
        )
        selectedLandingSlashCommand = command

        let leadingWhitespace = landingSearchText.prefix { $0.isWhitespace }
        let afterLeading = landingSearchText.dropFirst(leadingWhitespace.count)
        if afterLeading.hasPrefix("/") {
            let slug = "/" + command.rawValue
            if afterLeading.hasPrefix(slug) {
                let suffix = afterLeading.dropFirst(slug.count)
                landingSearchText = String(leadingWhitespace) + suffix
            } else {
                let afterSlash = afterLeading.dropFirst()
                let partialEnd = afterSlash.firstIndex(where: { $0.isWhitespace }) ?? afterSlash.endIndex
                let remainder = afterSlash[partialEnd...]
                landingSearchText = String(leadingWhitespace) + String(remainder)
            }
        }

        if trimmedLandingSearchText.isEmpty {
            landingSearchText = command.suggestedPrompt
        }

        showLandingSlashMenu = false
        landingSlashFilter = ""
        landingSlashKeyboardIndex = 0
        isLandingSearchFocused = true
    }

    private func openLandingSlashCommandMenu() {
        guard !supportedLandingSlashCommands.isEmpty else { return }
        landingSlashFilter = ""
        landingSlashKeyboardIndex = 0
        showLandingSlashMenu = true
        isLandingSearchFocused = true
    }

    private func handleLandingComposerCommand(
        _ selector: Selector,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard let command = ChatComposerKeyHandling.overlayCommand(
            for: selector,
            modifierFlags: modifierFlags
        ) else {
            return false
        }

        if showLandingMentionDropdown {
            return handleLandingMentionOverlayCommand(command)
        }
        if showLandingSlashMenu {
            return handleLandingSlashOverlayCommand(command)
        }
        return false
    }

    private func handleLandingMentionOverlayCommand(_ command: ChatComposerOverlayCommand) -> Bool {
        let choices = landingMentionKeyboardChoices
        switch command {
        case .moveDown:
            guard !choices.isEmpty else { return true }
            landingMentionKeyboardIndex = clampedLandingKeyboardIndex(
                landingMentionKeyboardIndex + 1,
                count: choices.count
            )
            return true
        case .moveUp:
            guard !choices.isEmpty else { return true }
            landingMentionKeyboardIndex = clampedLandingKeyboardIndex(
                landingMentionKeyboardIndex - 1,
                count: choices.count
            )
            return true
        case .confirm:
            guard !choices.isEmpty else { return true }
            attachLandingMentionReference(
                choices[
                    clampedLandingKeyboardIndex(
                        landingMentionKeyboardIndex,
                        count: choices.count
                    )
                ]
            )
            return true
        case .cancel:
            dismissLandingReferencePopover()
            return true
        }
    }

    private func handleLandingSlashOverlayCommand(_ command: ChatComposerOverlayCommand) -> Bool {
        let commands = filteredLandingSlashCommands
        switch command {
        case .moveDown:
            guard !commands.isEmpty else { return true }
            landingSlashKeyboardIndex = clampedLandingKeyboardIndex(
                landingSlashKeyboardIndex + 1,
                count: commands.count
            )
            return true
        case .moveUp:
            guard !commands.isEmpty else { return true }
            landingSlashKeyboardIndex = clampedLandingKeyboardIndex(
                landingSlashKeyboardIndex - 1,
                count: commands.count
            )
            return true
        case .confirm:
            guard !commands.isEmpty else { return true }
            applyLandingSlashCommand(
                commands[
                    clampedLandingKeyboardIndex(
                        landingSlashKeyboardIndex,
                        count: commands.count
                    )
                ]
            )
            return true
        case .cancel:
            showLandingSlashMenu = false
            landingSlashFilter = ""
            landingSlashKeyboardIndex = 0
            return true
        }
    }

    private func clampedLandingKeyboardIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }


    /// Fired when the native NSPopover finishes its close animation. Resets
    /// the composer state the same way an explicit Esc/dismiss would, without
    /// re-triggering the popover close (`showingSearchPopover` is already
    /// false by the time `onDisappear` runs).
    private func onLandingPopoverDisappear() {
        landingSearchText = ""
        landingComposerHeight = LandingSearchLayout.inputMinHeight
        isLandingSearchFocused = false
        showLandingMentionDropdown = false
        showLandingSlashMenu = false
        landingSlashFilter = ""
        landingSlashKeyboardIndex = 0
        selectedLandingSlashCommand = nil
        landingReferencePopoverStyle = .mention
        landingMentionFilter = ""
        landingMentionKeyboardIndex = 0
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
        landingContextAttachments = []
        landingFileAttachments = []
        landingToolsExpanded = false
        landingVoiceDraftPrefix = nil
        landingRecallDebounceBox.task?.cancel()
        landingRecallDebounceBox.task = nil
        landingSearchRevealTask?.cancel()
        landingSearchRevealTask = nil
        landingSearchRevealFrame = 0
    }

    private func dismissLandingSearch(animateGreetingReturn: Bool = true) {
        showingSearchPopover = false
        landingSearchText = ""
        landingComposerHeight = LandingSearchLayout.inputMinHeight
        isLandingSearchFocused = false
        showLandingMentionDropdown = false
        showLandingSlashMenu = false
        landingSlashFilter = ""
        landingSlashKeyboardIndex = 0
        selectedLandingSlashCommand = nil
        landingReferencePopoverStyle = .mention
        landingMentionFilter = ""
        landingMentionKeyboardIndex = 0
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
        landingContextAttachments = []
        landingFileAttachments = []
        landingToolsExpanded = false
        landingVoiceDraftPrefix = nil
        landingRecallDebounceBox.task?.cancel()
        landingRecallDebounceBox.task = nil
        landingSearchRevealTask?.cancel()
        landingSearchRevealTask = nil
        landingSearchRevealFrame = 0
        if animateGreetingReturn {
            runLandingGreetingReturnReveal()
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
                Self.log.error(
                    "LandingView: failed to schedule welcome-back presentation: \(error.localizedDescription, privacy: .public)"
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

    private func submitLandingSearch() {
        if showLandingMentionDropdown {
            _ = handleLandingMentionOverlayCommand(.confirm)
            return
        }
        if showLandingSlashMenu {
            _ = handleLandingSlashOverlayCommand(.confirm)
            return
        }

        let trimmed = landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let attachments = landingContextAttachments
        let fileAttachments = landingFileAttachments
        let slashCommand = activeSelectedLandingSlashCommand
        dismissLandingSearch()
        chat.startNewChat()
        for attachment in fileAttachments {
            chat.addAttachment(attachment)
        }
        for attachment in attachments {
            chat.addContextAttachment(attachment)
        }
        chat.queuePendingSlashCommand(slashCommand)
        applyActiveLandingAgentRuntimePreference()
        ui.setActivePanel(.home)
        MainChatSubmissionRouter.submit(
            trimmed,
            operatingMode: selectedOperatingMode,
            chat: chat,
            orchestrator: orchestrator,
            inference: inference
        )
    }

    private func presentFarmAgentCreate() {
        farmEditTarget = nil
        farmShowingCreate = true
    }

    private func presentFarmAgentEdit(_ entry: CompanionRosterEntry) {
        farmShowingCreate = false
        farmEditTarget = entry
    }

    private func startFarmAgentChat(_ entry: CompanionRosterEntry) {
        AppBootstrap.shared?.companionState.activate(entry.id)
        if supportedOperatingModes.contains(.agent) {
            selectedOperatingMode = .agent
        }
        applyLandingAgentRuntimePreference(for: entry)
        selectedLandingSlashCommand = nil
        if !showingSearchPopover {
            landingSearchText = ""
        }
        HapticHelper.homeCommand(.agent)
        activateLandingSearch(playHaptic: false)
    }

    private func dismissFarmAgentEditor() {
        farmShowingCreate = false
        farmEditTarget = nil
    }

    private func applyActiveLandingAgentRuntimePreference() {
        guard let entry = AppBootstrap.shared?.companionState.activeAgentEntry else { return }
        applyLandingAgentRuntimePreference(for: entry)
    }

    private func applyLandingAgentRuntimePreference(for entry: CompanionRosterEntry) {
        switch entry.agentModelChoice {
        case .autoConstellation:
            return
        case .local(let modelID, _):
            inference.setPreferredChatModelSelection(.localMLX(modelID))
        case .cloud(let providerRaw, _):
            guard let provider = CloudModelProvider(rawValue: providerRaw) else { return }
            if let model = preferredLandingCloudModel(for: provider) {
                inference.setPreferredChatModelSelection(.cloud(model))
            } else {
                inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
            }
        case .appleIntelligence:
            inference.setPreferredChatModelSelection(.appleIntelligence)
        }
    }

    private func preferredLandingCloudModel(for provider: CloudModelProvider) -> CloudTextModelID? {
        let models = CloudTextModelID.models(for: provider)
        return models.first { $0.supportedOperatingModes.contains(.agent) } ?? models.first
    }

    private func sanitizeStoredOperatingMode() {
        let sanitized = MainChatOperatingModePreference.sanitize(
            EpistemosOperatingMode(rawValue: mainChatOperatingModeRaw) ?? .fast,
            for: inference
        )
        if sanitized.rawValue != mainChatOperatingModeRaw {
            mainChatOperatingModeRaw = sanitized.rawValue
        }
    }

    private func attachLandingMentionReference(_ choice: ComposerReferenceChoice) {
        // Phase R.4 — mirror of ChatInputBar / MiniChat: thread the
        // active vault's stable ID so the attachment gets a canonical
        // `vault://{vaultId}/note/{relativePath}` manifest at pick time.
        let vaultId = vaultSync.vaultURL?.lastPathComponent
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: choice,
            vaultId: vaultId
        )
        if !landingContextAttachments.contains(attachment) {
            landingContextAttachments.append(attachment)
        }
        landingSearchText = ComposerReferenceHelpers.removingTrailingMention(from: landingSearchText)
        showLandingMentionDropdown = false
        landingReferencePopoverStyle = .mention
        landingMentionFilter = ""
        landingMentionKeyboardIndex = 0
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
        preserveLandingSearchSurfaceAfterAttachment()
    }

    private func preserveLandingSearchSurfaceAfterAttachment() {
        guard showingSearchPopover else { return }
        landingSearchRevealTask?.cancel()
        landingSearchRevealTask = nil
        landingSearchRevealFrame = max(landingSearchRevealFrame, 5)
    }

    private func dismissLandingReferencePopover() {
        showLandingMentionDropdown = false
        landingMentionKeyboardIndex = 0
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
    }

    private func removeLandingContextAttachment(_ id: String) {
        landingContextAttachments.removeAll { $0.id == id }
    }

    private func removeLandingFileAttachment(_ id: String) {
        let removedURIs = landingFileAttachments
            .filter { $0.id == id }
            .map(\.uri)
        landingFileAttachments.removeAll { $0.id == id }
        landingContextAttachments.removeAll { attachment in
            guard attachment.kind == .file else { return false }
            return removedURIs.contains(attachment.targetId)
        }
    }

    private func toggleLandingAllNotesContext() {
        let attachment = ComposerReferenceHelpers.allNotesAttachment
        if landingAllNotesContextAttached {
            removeLandingContextAttachment(attachment.id)
        } else if !landingContextAttachments.contains(attachment) {
            landingContextAttachments.append(attachment)
        }
        preserveLandingSearchSurfaceAfterAttachment()
        isLandingSearchFocused = true
    }

    private func openLandingFilePicker() {
        Task { @MainActor in
            await Task.yield()

            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            var allowedTypes: [UTType] = [.pdf, .plainText, .png, .jpeg, .json, .commaSeparatedText]
            if let markdownType = UTType(filenameExtension: "md") {
                allowedTypes.insert(markdownType, at: 2)
            }
            panel.allowedContentTypes = allowedTypes
            panel.canChooseDirectories = false

            let urls = await presentLandingFilePicker(panel)
            guard !urls.isEmpty else {
                isLandingSearchFocused = true
                return
            }

            let attachments = await FileAttachmentBuilder.buildAll(from: urls)
            for attachment in attachments where !landingFileAttachments.contains(where: { $0.uri == attachment.uri }) {
                landingFileAttachments.append(attachment)
            }

            for url in urls {
                guard let contextAttachment = ComposerReferenceHelpers.fileContextAttachment(
                    for: url,
                    displayName: url.lastPathComponent
                ) else { continue }
                if !landingContextAttachments.contains(contextAttachment) {
                    landingContextAttachments.append(contextAttachment)
                }
            }
            preserveLandingSearchSurfaceAfterAttachment()
            isLandingSearchFocused = true
        }
    }

    @MainActor
    private func presentLandingFilePicker(_ panel: NSOpenPanel) async -> [URL] {
        await withCheckedContinuation { continuation in
            let handler: (NSApplication.ModalResponse) -> Void = { response in
                continuation.resume(returning: response == .OK ? panel.urls : [])
            }

            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                panel.beginSheetModal(for: window, completionHandler: handler)
            } else {
                panel.begin(completionHandler: handler)
            }
        }
    }

    private func landingIconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .csv: "tablecells"
        case .text: "doc.text"
        case .other: "paperclip"
        }
    }

    private func applyLandingVoicePartial(_ partial: String) {
        if landingVoiceDraftPrefix == nil {
            landingVoiceDraftPrefix = landingSearchText
        }
        let prefix = landingVoiceDraftPrefix ?? ""
        let trimmedPartial = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPartial.isEmpty {
            landingSearchText = prefix
        } else if prefix.isEmpty {
            landingSearchText = trimmedPartial
        } else if prefix.last?.isWhitespace == true {
            landingSearchText = prefix + trimmedPartial
        } else {
            landingSearchText = prefix + " " + trimmedPartial
        }
        handleLandingSearchTextChange(landingSearchText)
    }

    private func commitLandingVoiceTranscript(_ transcript: String) {
        if let prefix = landingVoiceDraftPrefix {
            landingSearchText = prefix
        }
        landingVoiceDraftPrefix = nil
        appendLandingComposerText(transcript)
    }

    private func appendLandingComposerText(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if landingSearchText.isEmpty {
            landingSearchText = text
        } else if landingSearchText.last?.isWhitespace == true {
            landingSearchText += text
        } else {
            landingSearchText += " " + text
        }
        handleLandingSearchTextChange(landingSearchText)
        isLandingSearchFocused = true
    }

    private func openLandingContextualShadowHit(_ hit: ContextualShadowsState.RecallHit) {
        switch hit.kind {
        case .note:
            NoteWindowManager.shared.open(pageId: hit.id)
        case .chat:
            MiniChatWindowController.shared.openChat(hit.id)
        }
        contextualShadows.closePanel(kind: .chat, originDocId: landingRecallScopeID)
    }

    private func updateLandingReferenceSearch(filter: String) {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            landingReferenceSearch.reset()
            return
        }
        landingReferenceSearch.update(
            filter: trimmed,
            manifest: ambientManifest,
            vaultSync: vaultSync
        )
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
                    Self.log.error(
                        "LandingView: failed to save welcome-back summary note: \(error.localizedDescription, privacy: .public)"
                    )
                }
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch is CancellationError {
                    // Continue opening the created note even if the pacing delay is cancelled.
                } catch {
                    Self.log.error(
                        "LandingView: failed to wait before opening welcome-back summary note: \(error.localizedDescription, privacy: .public)"
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
            if let pageId = await vaultSync.createPage(title: "New Note", allowVaultSelectionPrompt: true) {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    private func createAndOpenDocument() {
        do {
            try NSDocumentController.shared.createUntitledEpdocDocument(in: vaultSync.vaultURL)
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func createAndOpenHTMLWorkspace() {
        guard vaultSync.vaultURL != nil else {
            VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
            return
        }
        do {
            try NSDocumentController.shared.createUntitledHTMLWorkspaceDocument(in: vaultSync.vaultURL)
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func createAndOpenCodeFile(_ request: CodeFileCreationRequest) {
        guard let vaultURL = vaultSync.vaultURL else {
            VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
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
        DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: recentChats(limit: 12))
    }

    private func recentChats(limit: Int) -> [SDChat] {
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = limit
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Self.log.error("LandingView: failed to fetch recent chats: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - Landing Command Item

struct LandingCommandItem: Identifiable {
    let id: String
    let label: String
    let icon: String
    let category: String
    var subtitle: String? = nil
    var snippet: String? = nil
    var badge: String? = nil
    var contextActions: [ContextAction] = []
    let action: () -> Void

    struct ContextAction {
        let label: String
        let icon: String
        let action: () -> Void
    }
}

// MARK: - Landing Command Row

struct LandingCommandRow: View {
    let command: LandingCommandItem
    let isSelected: Bool
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isSelected ? theme.resolved.accent.color : theme.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.label)
                        .font(.epBody)
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.epSmall)
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let badge = command.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(theme.glassTint)
                        )
                } else {
                    Text(command.category)
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(0.13))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.resolved.foreground.color.opacity(0.06))
            }
        }
        .animation(reduceMotion ? nil : Motion.micro, value: isSelected)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : Motion.micro) { isHovered = hovering }
        }
        .contextMenu {
            if !command.contextActions.isEmpty {
                ForEach(Array(command.contextActions.enumerated()), id: \.offset) { _, ctx in
                    Button {
                        ctx.action()
                    } label: {
                        Label(ctx.label, systemImage: ctx.icon)
                    }
                }
            }
        }
    }
}

// MARK: - Command Hint (Landing Shortcuts)

private struct CommandHintSpec {
    var modIcon: String? = nil
    var icon: String? = nil
    var key: String? = nil
    let label: String
}

private struct CommandHintLabel: View {
    let spec: CommandHintSpec
    let theme: EpistemosTheme
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 2) {
            if spec.modIcon != nil || spec.key != nil {
                HStack(spacing: 3) {
                    if let modIcon = spec.modIcon {
                         Image(systemName: modIcon)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    if let key = spec.key {
                        Text(key)
                            .font(LandingShortcutDisplay.font())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, LandingShortcutDisplay.keyHorizontalPadding)
                .padding(.vertical, LandingShortcutDisplay.keyVerticalPadding)
                .frame(minWidth: LandingShortcutDisplay.keyMinWidth(for: spec.key))
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    RoundedRectangle(
                        cornerRadius: LandingShortcutDisplay.keyCornerRadius,
                        style: .continuous
                    )
                    .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.08 : 0.06))
                )
            } else if let icon = spec.icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(LandingShortcutDisplay.label(spec.label))
                .font(LandingShortcutDisplay.font())
                .padding(.leading, (spec.key != nil || spec.modIcon != nil || spec.icon != nil) ? 4 : 0)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct CommandHint: View {
    var modIcon: String? = nil
    var icon: String? = nil
    var key: String? = nil
    let label: String
    let theme: EpistemosTheme
    let action: () -> Void

    @State private var isHovered = false

    private var spec: CommandHintSpec {
        CommandHintSpec(modIcon: modIcon, icon: icon, key: key, label: label)
    }

    var body: some View {
        Button(action: action) {
            CommandHintLabel(spec: spec, theme: theme, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .hoverGlass(flatBackground: .clear, cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4)
    }
}

private struct HoverRevealCommandHint: View {
    let primary: CommandHintSpec
    let secondary: CommandHintSpec
    let theme: EpistemosTheme
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            commandButton(spec: primary, action: primaryAction)

            if isHovered {
                commandButton(spec: secondary, action: secondaryAction)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private func commandButton(
        spec: CommandHintSpec,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CommandHintLabel(spec: spec, theme: theme, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .hoverGlass(flatBackground: .clear, cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4)
    }
}
