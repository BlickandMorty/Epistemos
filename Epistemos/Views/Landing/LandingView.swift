import OSLog
import SwiftData
import SwiftUI

enum LandingShortcutDisplay {
    static let fontSize: CGFloat = 12
    static let keyHorizontalPadding: CGFloat = 7
    static let keyVerticalPadding: CGFloat = 4
    static let keyCornerRadius: CGFloat = 7
    static let multiCharacterKeyMinWidth: CGFloat = 48
    static let shortcutRowSpacing: CGFloat = 12

    static func label(_ text: String) -> String {
        text
    }

    static func font(weight: Font.Weight = .medium) -> Font {
        .system(size: fontSize, weight: weight, design: .rounded)
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
    static let topRowSpacing: CGFloat = 14
    static let controlRowSpacing: CGFloat = 8
    static let controlRowTopPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 18
    static let cornerRadius: CGFloat = 24
    static let inputFontSize: CGFloat = 22
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

// MARK: - Landing View
// Clean landing: liquid glass greeting with shortcut hints.

struct LandingView: View {
    private static let log = Logger(subsystem: "com.epistemos", category: "LandingView")

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(InferenceState.self) private var inference
    @Environment(OrchestratorState.self) private var orchestrator
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(DailyBriefState.self) private var dailyBrief
    @Environment(\.modelContext) private var modelContext
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var mainChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue

    @State private var showWelcomeBack = false
    @State private var welcomeBackDismissTask: Task<Void, Never>?

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
    @State private var landingMentionPickerAutofocus = false
    @State private var landingReferencePopoverStyle: ComposerReferencePopoverStyle = .mention
    @State private var landingReferenceSearch = ComposerReferenceSearchState()
    @State private var landingContextAttachments: [ContextAttachment] = []
    /// Last tap location on the landing background. The appKitPopover anchors
    /// its arrow at this point so the popover opens right where the cursor is.
    @State private var landingTapLocation: CGPoint? = nil

    private var theme: EpistemosTheme { ui.theme }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }
    private var showingOverlay: Bool { showingBrief || showWelcomeBack }
    private var trimmedLandingSearchText: String {
        landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var landingSearchPlaceholder: String {
        ComposerAttachmentEntryHints.landingPlaceholder
    }
    private var landingSearchAccent: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: 0.75, saturation: 0.5, brightness: 0.9),
                Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                Color(hue: 0.05, saturation: 0.5, brightness: 0.95),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    private var ambientManifest: VaultManifest? {
        vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest
    }
    private var supportedOperatingModes: [EpistemosOperatingMode] {
        MainChatOperatingModePreference.supportedModes(for: inference)
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
            // Tap background — captures the tap location and hosts the
            // NSPopover anchor so the popover arrow points at the cursor.
            // The whole layer is gated off while a popover / overlay is open
            // (controlled by `.allowsHitTesting` on the shape below) so it
            // never swallows Esc / outside-click dismissal paths.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    guard !showingOverlay && !showingSearchPopover else { return }
                    landingTapLocation = location
                    activateLandingSearch()
                }
                .allowsHitTesting(!showingOverlay && !showingSearchPopover)
                .appKitPopover(
                    isPresented: $showingSearchPopover,
                    location: landingTapLocation
                ) {
                    Group {
                        if let bootstrap = AppBootstrap.shared {
                            landingSearchPopoverContent
                                .frame(idealWidth: 560, maxWidth: 620)
                                .padding(18)
                                .withAppEnvironment(bootstrap)
                                .modelContainer(bootstrap.modelContainer)
                        } else {
                            landingSearchPopoverContent
                                .frame(idealWidth: 560, maxWidth: 620)
                                .padding(18)
                        }
                    }
                    .onExitCommand { dismissLandingSearch() }
                    .onDisappear { onLandingPopoverDisappear() }
                }
                .zIndex(0)

            // ── Greeting Mode ──
            // Blurs and fades when Daily Brief or Welcome Back is active.
            greetingContent
                .blur(radius: showingOverlay ? 4 : 0)
                .opacity((showingOverlay || showingSearchPopover) ? 0.7 : 1)
                .allowsHitTesting(!showingOverlay && !showingSearchPopover)
                .zIndex(1)

            // ── Daily Brief Mode ──
            // Fades in on top of the blurred greeting.
            if showingBrief {
                dailyBriefContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(3)
            }

            // ── Welcome Back Mode ──
            // Shows after workspace auto-restore with session summary.
            if showWelcomeBack, let info = AppBootstrap.shared?.workspaceService.welcomeBack {
                welcomeBackContent(info: info)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: LandingCoordinateSpace.root)
        .animation(Motion.smooth, value: showingBrief)
        .animation(Motion.smooth, value: showWelcomeBack)
        .animation(Motion.smooth, value: showingSearchPopover)
        .onAppear {
            LandingViewStateSync.reassertHomeSurface(ui)
            sanitizeStoredOperatingMode()
            scheduleWelcomeBackPresentationIfNeeded()
        }
        .onChange(of: inference.preferredChatModelSelection.rawValue) { _, _ in
            sanitizeStoredOperatingMode()
        }
        .onDisappear {
            welcomeBackDismissTask?.cancel()
            welcomeBackDismissTask = nil
        }
        .background {
            // Hidden ⌘N shortcut — creates new note and teleports there
            Button(action: { createAndOpenNote() }) {}
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            Button(action: { MiniChatWindowController.shared.openNewChat() }) {}
                .keyboardShortcut("3", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            // Hidden ⌘I shortcut — open Quick Capture immediately
            Button(action: { openQuickCapture() }) {}
                .keyboardShortcut("i", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

        }
        .onKeyPress(.escape) {
            if showingSearchPopover {
                dismissLandingSearch()
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
    }

    private var landingBackdrop: some View {
        Color.clear
            .ignoresSafeArea()
    }

    // MARK: - Greeting Content (normal landing state)

    private var greetingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 36) {
                LiquidGreeting(retractNow: .constant(false))
            }
            .padding(.horizontal, Spacing.xxl)
            .allowsHitTesting(false)

            Spacer()

                // Intelligence row (workspace & session commands)
                HStack(spacing: LandingShortcutDisplay.shortcutRowSpacing) {
                    CommandHint(modIcon: "control", key: "\u{2318}W", label: "Workspaces", theme: theme) {
                        NotificationCenter.default.post(name: .toggleWorkspaceSwitcher, object: nil)
                    }
                    .springEntrance(index: 0, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "control", key: "\u{2318}S", label: "Save Workspace", theme: theme) {
                        NotificationCenter.default.post(name: .showSaveWorkspacePanel, object: nil)
                    }
                    .springEntrance(index: 1, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "control", key: "\u{2318}R", label: "Session Intelligence", theme: theme) {
                        NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)
                    }
                    .springEntrance(index: 2, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "control", key: "\u{2318}T", label: "Time Machine", theme: theme) {
                        NotificationCenter.default.post(name: .toggleTimeMachine, object: nil)
                    }
                    .springEntrance(index: 3, stagger: 0.08)
                }
                .padding(.bottom, 12)

                // Core shortcut hints
                HStack(spacing: LandingShortcutDisplay.shortcutRowSpacing) {
                    CommandHint(icon: "magnifyingglass", label: "Click to search", theme: theme) {
                        activateLandingSearch()
                    }
                    .springEntrance(index: 0, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    HoverRevealCommandHint(
                        primary: .init(modIcon: "command", key: "2", label: "Notes"),
                        secondary: .init(modIcon: "command", key: "N", label: "New Note"),
                        theme: theme,
                        primaryAction: {
                            UtilityWindowManager.shared.show(.notes)
                        },
                        secondaryAction: {
                            createAndOpenNote()
                        }
                    )
                    .springEntrance(index: 1, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "3", label: "Mini Chat", theme: theme) {
                        MiniChatWindowController.shared.openNewChat()
                    }
                    .springEntrance(index: 2, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "⇧N", label: "Quick Capture", theme: theme) {
                        openQuickCapture()
                    }
                    .springEntrance(index: 3, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "S", label: "Settings", theme: theme) {
                        UtilityWindowManager.shared.show(.settings)
                    }
                    .springEntrance(index: 4, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "G", label: "Graph", theme: theme) {
                        HologramController.shared.toggle()
                    }
                    .springEntrance(index: 5, stagger: 0.08)

                }
                .padding(.bottom, 28)
            }
    }

    // MARK: - Landing Search Content (Compact for Popover)
    
    private var landingSearchPopoverContent: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Landing Chat")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text("Start a lightweight chat from anywhere on the landing page.")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("ESC")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.textSecondary.opacity(0.06), in: Capsule())
            }

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    // One submission path, one visible chat, all modes.

                    if !landingContextAttachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(landingContextAttachments) { attachment in
                                    HStack(spacing: 4) {
                                        Image(systemName: attachment.systemImageName)
                                            .font(.system(size: 10, weight: .medium))
                                        Text(attachment.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        Button {
                                            removeLandingContextAttachment(attachment.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(theme.textTertiary.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(theme.textSecondary.opacity(0.08), in: Capsule())
                                    .foregroundStyle(theme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: LandingSearchLayout.controlRowTopPadding) {
                        // Single unified control strip: tool/runtime work
                        // stays in the same chat via the capability pill
                        // and auto-router.
                        landingChatSpecificControls

                        HStack(alignment: .top, spacing: LandingSearchLayout.topRowSpacing) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(landingSearchAccent)
                                .padding(.top, 8)

                            ZStack(alignment: .topLeading) {
                                ChatComposerTextEditor(
                                    text: $landingSearchText,
                                    height: $landingComposerHeight,
                                    isFocused: $isLandingSearchFocused,
                                    theme: theme,
                                    fontSize: LandingSearchLayout.inputFontSize,
                                    isProcessing: false
                                ) {
                                    submitLandingSearch()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: landingComposerHeight)
                                .frame(
                                    minHeight: LandingSearchLayout.inputMinHeight,
                                    alignment: .topLeading
                                )
                                .onChange(of: landingSearchText) { _, newValue in
                                    if let filter = ComposerReferenceHelpers.mentionFilter(in: newValue) {
                                        landingReferencePopoverStyle = .mention
                                        landingMentionFilter = filter
                                        landingMentionPickerAutofocus = false
                                        if !showLandingMentionDropdown {
                                            showLandingMentionDropdown = true
                                        }
                                    } else if showLandingMentionDropdown {
                                        showLandingMentionDropdown = false
                                        landingReferencePopoverStyle = .mention
                                        landingMentionPickerAutofocus = false
                                        landingReferenceSearch.reset()
                                    }
                                }
                                .onChange(of: landingMentionFilter) { _, newValue in
                                    updateLandingReferenceSearch(filter: newValue)
                                }

                                if landingSearchText.isEmpty {
                                    Text(landingSearchPlaceholder)
                                        .font(
                                            .system(
                                                size: LandingSearchLayout.inputFontSize,
                                                weight: .regular
                                            )
                                        )
                                        .foregroundStyle(theme.mutedForeground.opacity(0.55))
                                        .padding(.top, ChatComposerInputMetrics.verticalInset)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        HStack(spacing: LandingSearchLayout.controlRowSpacing) {
                            Text("Use `@` to pull notes and recent chats into the prompt.")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textTertiary)

                            Spacer(minLength: 0)

                            if !landingSearchText.isEmpty {
                                Button {
                                    landingSearchText = ""
                                    landingComposerHeight = LandingSearchLayout.inputMinHeight
                                    showLandingMentionDropdown = false
                                    landingMentionFilter = ""
                                    landingReferenceSearch.reset()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.textTertiary)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(NativeToolbarButtonStyle())
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }

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
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var landingChatSpecificControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ChatBrainPickerMenu(
                    operatingMode: operatingModeBinding,
                    availableOperatingModes: supportedOperatingModes,
                    isTemporaryChatEnabled: incognitoBinding
                )
                Spacer(minLength: 0)
            }

            if chat.isIncognito {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 11, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Temporary Chat")
                            .font(.system(size: 11, weight: .semibold))
                        Text("The next chat starts in memory only and will not be saved.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(theme.resolved.accent.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.resolved.accent.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.resolved.accent.color.opacity(0.14), lineWidth: 0.8)
                }
            }
        }
    }

    private func activateLandingSearch() {
        guard !showingBrief && !showWelcomeBack else { return }
        if showingSearchPopover {
            isLandingSearchFocused = true
            return
        }
        showingSearchPopover = true
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


    /// Fired when the native NSPopover finishes its close animation. Resets
    /// the composer state the same way an explicit Esc/dismiss would, without
    /// re-triggering the popover close (`showingSearchPopover` is already
    /// false by the time `onDisappear` runs).
    private func onLandingPopoverDisappear() {
        landingSearchText = ""
        landingComposerHeight = LandingSearchLayout.inputMinHeight
        isLandingSearchFocused = false
        showLandingMentionDropdown = false
        landingReferencePopoverStyle = .mention
        landingMentionFilter = ""
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
    }

    private func dismissLandingSearch() {
        showingSearchPopover = false
        landingSearchText = ""
        landingComposerHeight = LandingSearchLayout.inputMinHeight
        isLandingSearchFocused = false
        showLandingMentionDropdown = false
        landingReferencePopoverStyle = .mention
        landingMentionFilter = ""
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
        landingContextAttachments = []
    }

    private func scheduleWelcomeBackPresentationIfNeeded() {
        guard let info = AppBootstrap.shared?.workspaceService.welcomeBack,
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

            guard AppBootstrap.shared?.workspaceService.welcomeBack != nil else {
                welcomeBackDismissTask = nil
                return
            }

            showWelcomeBack = true
            welcomeBackDismissTask = nil
            // Do NOT auto-dismiss — persist until user interacts (ESC, click, or button)
        }
    }

    private func submitLandingSearch() {
        let trimmed = landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let attachments = landingContextAttachments
        dismissLandingSearch()
        chat.startNewChat()
        for attachment in attachments {
            chat.addContextAttachment(attachment)
        }
        ui.setActivePanel(.home)
        MainChatSubmissionRouter.submit(
            trimmed,
            operatingMode: selectedOperatingMode,
            chat: chat,
            orchestrator: orchestrator,
            inference: inference
        )
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
        landingMentionPickerAutofocus = false
        landingReferenceSearch.reset()
    }

    private func dismissLandingReferencePopover() {
        showLandingMentionDropdown = false
        landingMentionPickerAutofocus = false
    }

    private func removeLandingContextAttachment(_ id: String) {
        landingContextAttachments.removeAll { $0.id == id }
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
        VStack(spacing: 0) {
            Text("welcome back")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)
                .shadow(color: theme.isDark ? theme.fontAccent.opacity(0.12) : .clear, radius: 8)
                .padding(.top, 28)
                .padding(.bottom, 4)

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                .padding(.bottom, 16)

            ScrollView {
                TypewriterPlainText(content: info.displayText)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(theme.fontAccent.opacity(0.85))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: 580, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            }
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 16)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 24)
                }
            }

            HStack(spacing: 12) {
                Button {
                    dismissWelcomeBack()
                } label: {
                    Text("Continue")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.resolved.foreground.color.opacity(0.06), in: Capsule())
                        .foregroundStyle(theme.fontAccent.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button {
                    saveWelcomeBackAsNote(info: info)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Save as Note")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.resolved.accent.color.opacity(0.12), in: Capsule())
                    .foregroundStyle(theme.resolved.accent.color)
                }
                .buttonStyle(.plain)

                Text("click or press ESC to dismiss")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(theme.mutedForeground.opacity(0.3))
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismissWelcomeBack() }
        }
    }

    private func dismissWelcomeBack() {
        welcomeBackDismissTask?.cancel()
        welcomeBackDismissTask = nil
        showWelcomeBack = false
        AppBootstrap.shared?.workspaceService.welcomeBack = nil
    }

    private func saveWelcomeBackAsNote(info: WelcomeBackInfo) {
        Task { @MainActor in
            guard let bootstrap = AppBootstrap.shared else { return }
            let title = "Session Summary — \(Date.now.formatted(.dateTime.month(.abbreviated).day().year()))"
            var body = "# \(title)\n\n"
            if !info.sanitizedIntentSummary.isEmpty {
                body += "## Summary\n\(info.sanitizedIntentSummary)\n\n"
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
            // Title — RetroGaming font, centered under nav bar
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
                    TypewriterPlainText(content: dailyBrief.dailyBriefContent)
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundStyle(theme.fontAccent.opacity(0.85))
                        .lineSpacing(5)
                        .textSelection(.enabled)
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

    // MARK: - Actions

    private func createAndOpenNote() {
        Task {
            if let pageId = await vaultSync.createPage(title: "New Note", allowVaultSelectionPrompt: true) {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    private func openQuickCapture() {
        NotificationCenter.default.post(name: .showQuickCapture, object: nil)
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
        .animation(Motion.micro, value: isSelected)
        .onHover { hovering in
            withAnimation(Motion.micro) { isHovered = hovering }
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
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
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
