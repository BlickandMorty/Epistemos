import AppKit
#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
import OsaurusCore
#endif
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Module-internal (was file-private): RootView's act transcript export reuses
// `displayContent(for:)` so exported markdown matches the rendered chat (think-block
// stripped, headings de-duped). Intentional export — owner 2026-06-23 unbundle work.
enum ChatPresentationFormatter {
    nonisolated static let userModePrefixRegex = FoundationSafety.regularExpression(
        pattern: #"^\[[A-Z ]+MODE\]\s*"#
    )

    nonisolated static func displayContent(for message: ChatMessage, chatTitle: String? = nil, isFirstAssistantMessage: Bool = false) -> String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.role == .user else {
            let final = UserFacingModelOutput.finalVisibleText(from: trimmed)
            
            // If this is the "large first sentence/heading" the user wants to replace with the title:
            // Strip leading # Heading if it matches the title or if it's the first assistant message
            // following a main title.
            var lines = final.components(separatedBy: .newlines)
            if let first = lines.first, first.hasPrefix("# ") {
                let headingText = first.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                let t = chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // If it matches the chat title OR it's the first assistant message and looks redundant:
                if headingText.caseInsensitiveCompare(t) == .orderedSame || isFirstAssistantMessage {
                    lines.removeFirst()
                    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            return final
        }

        let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let userModePrefixRegex else {
            return trimmed
        }
        return userModePrefixRegex.stringByReplacingMatches(
            in: trimmed,
            range: fullRange,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract the first-line markdown H1 from the original
    /// assistant content when `displayContent` would have stripped
    /// it (first assistant message OR heading matches chat title).
    /// Returns the heading text so the chat row can render it in
    /// the dedicated heading lane without duplicating it in-body.
    /// Per RCA13 RCA2-P2-003 follow-up: real wiring.
    ///
    /// Returns nil when:
    ///   - the original text doesn't start with an H1 (`# `)
    ///   - displayContent wouldn't strip it (i.e. not the first
    ///     assistant message AND heading doesn't match the title) —
    ///     in that case the heading stays in body, no separate lane
    ///   - heading text is empty / very long (likely an inline
    ///     sentence, not a title)
    nonisolated static func heading(
        forAssistantOriginalContent original: String,
        chatTitle: String?,
        isFirstAssistantMessage: Bool
    ) -> String? {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let firstLine: String
        if let firstLineEnd = trimmed.firstIndex(of: "\n") {
            firstLine = String(trimmed[..<firstLineEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            firstLine = trimmed
        }
        guard firstLine.hasPrefix("# "), !firstLine.hasPrefix("## ") else {
            return nil
        }
        let heading = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heading.isEmpty, heading.count <= 120 else { return nil }
        let title = chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let matchesTitle = heading.caseInsensitiveCompare(title) == .orderedSame
        guard isFirstAssistantMessage || matchesTitle else { return nil }
        return heading
    }

    /// Compatibility shim — old single-arg callers default to no
    /// heading. New call sites pass the original message text +
    /// title + first-message flag through.
    nonisolated static func heading(forAssistantText text: String) -> String? {
        nil
    }

    nonisolated static func sourceReferences(
        for message: ChatMessage,
        displayContent: String
    ) -> [AssistantSourceReference] {
        guard message.role == .assistant, !message.isError else { return [] }
        return AssistantSourceReference.extract(
            from: displayContent,
            noteTitles: message.loadedNoteTitles ?? []
        )
    }
}

enum ChatLayout {
    static let messageColumnMaxWidth: CGFloat = 760
    static let mainComposerMaxWidth: CGFloat = 860
    static let mainComposerHorizontalPadding: CGFloat = 10
    static let transcriptSpacing: CGFloat = 28
    static let brainPanelWidth: CGFloat = 420
}

enum ChatStreamingDisplayPolicy {
    static let showsLiveResponseText = true
}

struct ChatTranscriptRow: Identifiable, Sendable {
    let message: ChatMessage
    let originalQuery: String?
    let displayContent: String
    let heading: String?
    let sourceReferences: [AssistantSourceReference]

    var id: String { message.id }
}

nonisolated func makeChatTranscriptRows(from messages: [ChatMessage], chatTitle: String?) -> [ChatTranscriptRow] {
    var lastUserQuery: String?
    var assistantMessageCount = 0
    var rows: [ChatTranscriptRow] = []
    rows.reserveCapacity(messages.count)

    for message in messages {
        if message.role == .user {
            lastUserQuery = message.content
            rows.append(
                ChatTranscriptRow(
                    message: message,
                    originalQuery: nil,
                    displayContent: ChatPresentationFormatter.displayContent(for: message, chatTitle: chatTitle),
                    heading: nil,
                    sourceReferences: []
                )
            )
        } else {
            assistantMessageCount += 1
            let displayContent = ChatPresentationFormatter.displayContent(
                for: message,
                chatTitle: chatTitle,
                isFirstAssistantMessage: assistantMessageCount == 1
            )
            rows.append(
                ChatTranscriptRow(
                    message: message,
                    originalQuery: lastUserQuery,
                    displayContent: displayContent,
                    heading: ChatPresentationFormatter.heading(
                        forAssistantOriginalContent: UserFacingModelOutput.finalVisibleText(
                            from: message.content
                        ),
                        chatTitle: chatTitle,
                        isFirstAssistantMessage: assistantMessageCount == 1
                    ),
                    sourceReferences: ChatPresentationFormatter.sourceReferences(
                        for: message,
                        displayContent: displayContent
                    )
                )
            )
        }
    }

    return rows
}

// MARK: - Chat View
// Full chat interface matching v2's conversation mode.
// Shows when user has submitted a query from landing page.
// Layout: header bar + scrolling messages + input bar.

struct ChatView: View {
    var actUsesOsaurus: Bool = false
    var onSubmitOverride: ((String, EpistemosOperatingMode) -> Void)? = nil
    var onStopOverride: (() -> Void)? = nil
    var isProcessingOverride: Bool? = nil
    var availableOperatingModesOverride: [EpistemosOperatingMode]? = nil
    var composerMode: ChatInputComposerMode = .epistemos
    var showsToolbarControls: Bool = true
    var onOpenActConfiguration: (() -> Void)? = nil

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(PipelineState.self) private var pipeline
    @Environment(InferenceState.self) private var inference
    @Environment(OrchestratorState.self) private var orchestrator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var mainChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    // Default VISIBLE so the context panel (routing, request, loaded notes,
    // tools-this-turn, evidence) is discoverable out of the box — users
    // reported "I can't see the things in the sidebar." It stays fully
    // toggleable and the choice persists, and the panel only renders sections
    // that have data (non-essential ones collapse) so it reads as informative,
    // not cluttered. Populated for every route (cloud + local) because the
    // brain snapshot is captured pre-routing.
    @AppStorage("mainChat.showBrainPanel") private var showBrainPanel = true
    @State private var transcriptRows: [ChatTranscriptRow] = []
    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
    @State private var pendingActPrivacyReview: ActNativePrivacyReviewSheetState?
    @State private var actPrivacyReviewPresenterToken: EpistemosOsaurusNativePrivacyReviewPresenterToken?
    @State private var pendingActSecretPrompt: ActNativeSecretPromptSheetState?
    @State private var pendingActClarifyPrompt: ActNativeClarifyPromptSheetState?
    #endif

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.mainChat) }

    /// Main-chat root background. Per user 2026-05-12: use the theme's
    /// native background color in BOTH light and dark mode so the main
    /// chat shares the same canvas as the Landing page
    /// (`AppWindowBackdropStyle.background(for: theme)` resolves to the
    /// same `theme.resolved.background.color`). The previous near-OLED
    /// dark-mode override (`Color(red: 0.07, ...)`) made the main chat
    /// feel like a separate surface; this change restores theme
    /// continuity.
    private var oledAwareBackground: Color {
        theme.resolved.background.color
    }

    private var supportedOperatingModes: [EpistemosOperatingMode] {
        if let availableOperatingModesOverride { return availableOperatingModesOverride }
        if actUsesOsaurus { return [.agent] }
        return MainChatOperatingModePreference.supportedModes(for: inference)
    }

    private var selectedOperatingMode: EpistemosOperatingMode {
        get {
            if actUsesOsaurus { return .agent }
            return MainChatOperatingModePreference.sanitize(
                EpistemosOperatingMode(rawValue: mainChatOperatingModeRaw) ?? .fast,
                for: inference
            )
        }
        nonmutating set {
            guard !actUsesOsaurus else { return }
            mainChatOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                newValue,
                for: inference
            ).rawValue
        }
    }

    private var effectiveIsProcessing: Bool {
        isProcessingOverride ?? pipeline.isProcessing
    }

    private var operatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { selectedOperatingMode },
            set: { selectedOperatingMode = $0 }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        HStack {
                            Spacer(minLength: 0)
                            LazyVStack(spacing: ChatLayout.transcriptSpacing) {
                                ForEach(transcriptRows) { row in
                                    MessageBubble(
                                        message: row.message,
                                        originalQuery: row.originalQuery,
                                        displayContent: row.displayContent,
                                        heading: row.heading,
                                        sourceReferences: row.sourceReferences,
                                        allowsResubmit: !effectiveIsProcessing,
                                        onResubmit: { query in
                                            submitMainChatQuery(query, operatingMode: selectedOperatingMode)
                                        }
                                    )
                                    .id(row.id)
                                }

                                // 0.33a (owner "prefill/stats"): native TTFT/tokens chip under the
                                // last completed act reply — the telemetry Osaurus showed, recorded via
                                // the side-channel store so it never contaminates the visible text.
                                if actUsesOsaurus, !shouldShowStreamingIndicator,
                                   transcriptRows.last?.message.role == .assistant,
                                   let actStats = ActTurnStatsStore.shared.latest {
                                    ActGenerationStatsChip(stats: actStats)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 4)
                                        .id("act-stats-chip")
                                }

                                if shouldShowStreamingIndicator {
                                    StreamingIndicator(
                                        selectedOperatingMode: selectedOperatingMode,
                                        showsActivityStrip: !actUsesOsaurus
                                    )
                                        .id("streaming-bottom")
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom-anchor")
                            }
                            .frame(maxWidth: ChatLayout.messageColumnMaxWidth)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                    }
                    .contentMargins(.top, 0, for: .scrollContent)
                    .onScrollGeometryChange(
                        for: CGFloat.self,
                        of: { geometry in
                            ScrollStability.distanceToBottom(for: geometry)
                        }
                    ) { _, distanceToBottom in
                        let next = ScrollStability.updatedAutoFollowState(
                            from: autoFollow,
                            distanceToBottom: distanceToBottom
                        )
                        guard next != autoFollow else { return }
                        autoFollow = next
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        guard autoFollow.isFollowingBottom else { return }
                        autoFollow.markProgrammaticScrollToBottom()
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                    .onChange(of: chat.transcriptRevision) { _, _ in
                        transcriptRows = makeChatTranscriptRows(from: chat.messages, chatTitle: chat.chatTitle)
                    }
                    .onChange(of: chat.streamingText) { _, _ in
                        let now = ContinuousClock.now
                        guard autoFollow.isFollowingBottom,
                              (ChatStreamingDisplayPolicy.showsLiveResponseText || !chat.isStreaming),
                              now - lastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                        else { return }
                        lastScrollTime = now
                        autoFollow.markProgrammaticScrollToBottom()
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                    .onAppear {
                        Task { @MainActor in
                            transcriptRows = makeChatTranscriptRows(from: chat.messages, chatTitle: chat.chatTitle)
                            autoFollow.markProgrammaticScrollToBottom()
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                }

                ChatInputBar(
                    onSubmit: { query in
                        submitMainChatQuery(query, operatingMode: selectedOperatingMode)
                    },
                    onDeepResearch: { query in
                        submitMainChatDeepResearch(query, operatingMode: selectedOperatingMode)
                    },
                    onStop: {
                        if let onStopOverride {
                            onStopOverride()
                        } else {
                            chat.stopStreaming()
                        }
                    },
                    isProcessing: effectiveIsProcessing,
                    operatingMode: operatingModeBinding,
                    availableOperatingModes: supportedOperatingModes,
                    composerMode: composerMode,
                    onOpenActConfiguration: onOpenActConfiguration,
                    isContextPanelShown: showBrainPanel,
                    // Owner 2026-06-24: the context-panel toggle moved UP to the toolbar
                    // (actContextPanelToolbarButton, shared AppStorage key) — so it's no longer on the
                    // composer bar. nil → ChatInputBar omits the composer toggle.
                    onToggleContextPanel: nil
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // OWNER 2026-06-23: restore the owner's OLD act side panel. It was hidden on act by
            // a `!actUsesOsaurus` gate — the owner reported "I used to have a side panel on act
            // chat." showBrainPanel defaults true, so dropping the gate brings it back; the act
            // composer's Context button toggles it.
            if showBrainPanel {
                Divider()
                ChatBrainPanelView(
                    snapshot: chat.latestBrainSnapshot,
                    capturedModelInput: chat.latestCapturedModelInput,
                    pendingContextAttachments: chat.pendingContextAttachments,
                    pendingAttachments: chat.pendingAttachments,
                    onClose: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) {
                            showBrainPanel = false
                        }
                    }
                )
                    .frame(width: ChatLayout.brainPanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(oledAwareBackground.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
            if actUsesOsaurus {
                ActComputerUseApprovalOverlay()
                    .padding(.horizontal, 22)
                    .padding(.bottom, 126)
            }
            #endif
        }
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        .sheet(item: $pendingActPrivacyReview) { state in
            ActNativePrivacyReviewSheet(state: state, theme: theme)
                .onDisappear {
                    state.cancelIfNeeded()
                    if pendingActPrivacyReview?.id == state.id {
                        pendingActPrivacyReview = nil
                    }
                }
        }
        .sheet(item: $pendingActSecretPrompt) { state in
            ActNativeSecretPromptSheet(state: state, theme: theme)
                .onDisappear {
                    state.cancelIfNeeded()
                    if pendingActSecretPrompt?.id == state.id {
                        pendingActSecretPrompt = nil
                    }
                }
        }
        .sheet(item: $pendingActClarifyPrompt) { state in
            ActNativeClarifyPromptSheet(state: state, theme: theme)
                .onDisappear {
                    state.cancelIfNeeded()
                    if pendingActClarifyPrompt?.id == state.id {
                        pendingActClarifyPrompt = nil
                    }
                }
        }
        #endif
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9), value: showBrainPanel)
        .onAppear {
            sanitizeStoredOperatingMode()
            syncContextWindowMetrics()
            refreshChatCapability()
            #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
            registerActPrivacyReviewPresenterIfNeeded()
            registerActPromptPresentersIfNeeded()
            #endif
        }
        .onDisappear {
            #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
            unregisterActPrivacyReviewPresenter()
            unregisterActPromptPresenters()
            #endif
        }
        .onChange(of: mainChatOperatingModeRaw) { _, _ in
            sanitizeStoredOperatingMode()
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: inference.preferredChatModelSelection.rawValue) { _, _ in
            sanitizeStoredOperatingMode()
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: inference.activeAIProvider) { _, _ in
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: chat.isAgentExecuting) { _, _ in
            refreshChatCapability()
        }
        .onChange(of: pipeline.isProcessing) { _, _ in
            refreshChatCapability()
        }
        .onChange(of: chat.latestBrainSnapshot) { _, _ in
            refreshChatCapability()
        }
        .navigationTitle("")
        .toolbar {
            if showsToolbarControls {
                if actUsesOsaurus {
                    ToolbarItem(placement: .principal) {
                        chatTitleToolbarContent
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                // Right: chat controls (title + nav handled by toolbar)
                ToolbarItemGroup(placement: .primaryAction) {
                    historyToolbarButton
                    if actUsesOsaurus {
                        actConfigurationToolbarButton
                    } else {
                        brainToolbarButton
                    }
                    miniChatToolbarButton

                    Button(action: exportChat) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export Chat")
                }
            }
        }
    }

    private var chatTitleToolbarContent: some View {
        MotionTitle(
            text: resolvedChatTitle,
            font: .system(size: 16, weight: .semibold, design: .rounded),
            color: ui.theme.textPrimary
        )
            .id(resolvedChatTitle)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: 360)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Chat title")
    }

    private var resolvedChatTitle: String {
        let title = chat.chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? (actUsesOsaurus ? "Act" : "Chat") : title
    }

    private var shouldShowStreamingIndicator: Bool {
        guard effectiveIsProcessing || chat.isStreaming else { return false }
        guard actUsesOsaurus else { return true }
        let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(from: chat.streamingText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !visibleStreamingText.isEmpty
            || !chat.streamingThinking.isEmpty
            || !chat.pendingContentBlocks.isEmpty
    }

    private func exportChat() {
        let lines = chat.messages.map { msg in
            let role = msg.role == .user ? "You" : "Assistant"
            let content = ChatPresentationFormatter.displayContent(for: msg)
            return "## \(role)\n\n\(content)"
        }
        let md = "# Chat Export — \(Date().formatted(date: .abbreviated, time: .omitted))\n\n\(lines.joined(separator: "\n\n---\n\n"))"
        ChatTextExportSupport.save(
            md,
            suggestedFilename: "chat-export-\(Date().formatted(.iso8601.year().month().day())).md",
            contentType: .plainText
        )
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
            historyPopoverContent
                .frame(width: 300, height: 500)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    @ViewBuilder
    private var historyPopoverContent: some View {
        ChatSidebarView()
    }

    private var brainToolbarButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                showBrainPanel.toggle()
            }
        } label: {
            Label(
                showBrainPanel ? "Hide Context" : "Show Context",
                systemImage: "sidebar.right"
            )
        }
        .accessibilityLabel(showBrainPanel ? "Hide context panel" : "Show context panel")
        .help(
            showBrainPanel
                ? "Hide turn context"
                : "Show turn context"
        )
    }

    private var actConfigurationToolbarButton: some View {
        Button {
            if let onOpenActConfiguration {
                onOpenActConfiguration()
            } else {
                NotificationCenter.default.post(name: .showActOsaurusSettings, object: nil)
            }
        } label: {
            Label("Configuration", systemImage: "gearshape")
        }
        .accessibilityLabel("Act Configuration")
        .help("Open Act configuration")
    }

    private var miniChatToolbarButton: some View {
        Button(action: openCurrentChatInMiniChat) {
            Label("Open in Mini Chat", systemImage: "arrow.up.right.square")
        }
        .accessibilityLabel("Open in Mini Chat")
        .help("Open in Mini Chat")
    }

    private func submitMainChatQuery(_ query: String, operatingMode: EpistemosOperatingMode) {
        if let onSubmitOverride {
            onSubmitOverride(query, operatingMode)
            return
        }
        // OWNER 2026-06-23 night (0.40): the act chat runs PURELY through the Osaurus engine —
        // NEVER the deprecated ChatCoordinator "Standard Chat" + 38-tool path (which makes the
        // small local model hallucinate apple.notes and fail). Same direct path MiniChat uses.
        if actUsesOsaurus, LocalAgentLoop.shouldRouteActThroughOsaurus() {
            chat.runActOsaurusTurn(query)
            return
        }
        MainChatSubmissionRouter.submit(
            query,
            operatingMode: operatingMode,
            chat: chat,
            orchestrator: orchestrator,
            inference: inference,
            forceActOsaurus: actUsesOsaurus
        )
    }

    /// DeerFlow 5e-2 — route the composer text to the multi-agent deep-research
    /// path (emits `.deepResearchSubmitted` → `ChatCoordinator.runDeepResearch`)
    /// instead of a normal turn. The composer only exposes its button when
    /// eligible (Pro build + flag on + cloud model).
    private func submitMainChatDeepResearch(_ query: String, operatingMode: EpistemosOperatingMode) {
        chat.submitDeepResearch(query, operatingMode: operatingMode)
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

    private func syncContextWindowMetrics() {
        chat.syncContextWindowMetrics(
            maxTokens: inference.chatSurfaceMaxContextTokens(for: selectedOperatingMode)
        )
    }

    private func openCurrentChatInMiniChat() {
        let preferredMiniChatMode = actUsesOsaurus ? EpistemosOperatingMode.agent : selectedOperatingMode
        if let chatId = chat.activeChatId {
            MiniChatWindowController.shared.openChat(
                chatId,
                preferredOperatingMode: preferredMiniChatMode
            )
        } else {
            MiniChatWindowController.shared.openNewChat(
                preferredOperatingMode: preferredMiniChatMode
            )
        }
    }

    /// Refresh chat.currentCapability to match the active model + runtime
    /// state. Called on appear and whenever the provider / model / agent
    /// execution flags change so the ChatCapabilityPill reads live without
    /// the caller having to touch it by hand.
    ///
    /// IMPORTANT: reads the effective route for the selected operating mode —
    /// NOT activeAIProvider (a cloud-provider preference that can coexist with
    /// a local pick) or a stale preferred picker value. Reading the wrong one
    /// caused the pill to read "Cloud" while a local MLX model was selected in
    /// the composer picker; the pill is a user-facing honesty contract and
    /// must not lie.
    private func refreshChatCapability() {
        if (chat.isAgentExecuting || pipeline.isProcessing),
           let snapshot = chat.latestBrainSnapshot {
            let hasPlannedTools = !snapshot.allowedToolNames.isEmpty
            let isCloudSnapshot = snapshot.providerLabel != "Local MLX"
                && snapshot.providerLabel != "Apple Intelligence"
            chat.currentCapability = ChatCapability.classify(
                isCloudProvider: isCloudSnapshot,
                isAgentExecuting: hasPlannedTools,
                isResearchMode: hasPlannedTools && !isCloudSnapshot,
                isThinkingMode: snapshot.operatingMode == .thinking
            )
            return
        }

        let effectiveSelection = inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)
        let isCloud: Bool
        switch effectiveSelection {
        case .cloud:
            isCloud = true
        case .localMLX, .appleIntelligence:
            isCloud = false
        }
        let toolsModeSelected = selectedOperatingMode == .agent
        chat.currentCapability = ChatCapability.classify(
            isCloudProvider: isCloud,
            isAgentExecuting: toolsModeSelected || chat.isAgentExecuting,
            isResearchMode: false,
            isThinkingMode: selectedOperatingMode == .thinking && !isCloud
        )
    }

    #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
    @MainActor
    private func registerActPrivacyReviewPresenterIfNeeded() {
        guard actUsesOsaurus, actPrivacyReviewPresenterToken == nil else { return }
        actPrivacyReviewPresenterToken = EpistemosOsaurusManagementBridge.registerNativePrivacyReviewPresenter { request in
            await withCheckedContinuation { continuation in
                pendingActPrivacyReview = ActNativePrivacyReviewSheetState(
                    request: request,
                    continuation: continuation
                )
            }
        }
    }

    @MainActor
    private func unregisterActPrivacyReviewPresenter() {
        EpistemosOsaurusManagementBridge.unregisterNativePrivacyReviewPresenter(actPrivacyReviewPresenterToken)
        actPrivacyReviewPresenterToken = nil
        pendingActPrivacyReview?.cancelIfNeeded()
        pendingActPrivacyReview = nil
    }

    @MainActor
    private func registerActPromptPresentersIfNeeded() {
        guard actUsesOsaurus else { return }
        EpistemosOsaurusChatSessionBridge.installNativeSecretPromptPresenter { request in
            await withCheckedContinuation { continuation in
                pendingActSecretPrompt = ActNativeSecretPromptSheetState(
                    request: request,
                    continuation: continuation
                )
            }
        }
        EpistemosOsaurusChatSessionBridge.installNativeClarifyPromptPresenter { request in
            await withCheckedContinuation { continuation in
                pendingActClarifyPrompt = ActNativeClarifyPromptSheetState(
                    request: request,
                    continuation: continuation
                )
            }
        }
    }

    @MainActor
    private func unregisterActPromptPresenters() {
        EpistemosOsaurusChatSessionBridge.installNativeSecretPromptPresenter(nil)
        EpistemosOsaurusChatSessionBridge.installNativeClarifyPromptPresenter(nil)
        pendingActSecretPrompt?.cancelIfNeeded()
        pendingActSecretPrompt = nil
        pendingActClarifyPrompt?.cancelIfNeeded()
        pendingActClarifyPrompt = nil
    }
    #endif
}

// ChatHeaderBar removed — buttons now live in the toolbar (see ChatView.body .toolbar {})

#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
private struct ActComputerUseApprovalOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var queue = ComputerUsePromptQueue.shared
    @State private var approvingRequestID: UUID?

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.mainChat) }

    var body: some View {
        if let request = queue.pending.first {
            approvalCard(for: request)
                .frame(maxWidth: 560)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86),
                    value: request.id
                )
                .zIndex(40)
        }
    }

    private func approvalCard(for request: ConfirmRequest) -> some View {
        let preview = request.preview
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: preview.effect))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(effectTint(preview.effect))
                    .frame(width: 24, height: 24)
                    .background(effectTint(preview.effect).opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Computer Use Approval")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text(preview.effect.displayLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer(minLength: 12)

                Text("Touch ID")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.resolved.accent.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.resolved.accent.color.opacity(0.10), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(preview.summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = preview.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if let appName = preview.appName, !appName.isEmpty {
                        metadataChip(appName, systemImage: "macwindow")
                    }
                    if let targetLabel = preview.targetLabel, !targetLabel.isEmpty {
                        metadataChip(targetLabel, systemImage: "scope")
                    }
                    metadataChip(request.toolCallId, systemImage: "number")
                }
                .lineLimit(1)
            }

            HStack(spacing: 10) {
                Button {
                    queue.resolve(id: request.id, approved: false)
                } label: {
                    Label("Deny", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(ActApprovalButtonStyle(theme: theme, role: .secondary))
                .help("Deny this Computer Use action")

                Spacer()

                Button {
                    approve(request)
                } label: {
                    HStack(spacing: 7) {
                        if approvingRequestID == request.id {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "touchid")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text("Approve")
                    }
                    .frame(minWidth: 112, minHeight: 30)
                }
                .buttonStyle(ActApprovalButtonStyle(theme: theme, role: .primary))
                .disabled(approvingRequestID != nil)
                .keyboardShortcut(.defaultAction)
                .help("Approve with device authentication")
            }
        }
        .padding(14)
        .background {
            shape
                .fill(theme.card.opacity(theme.isDark ? 0.94 : 0.90))
                .overlay(shape.fill(.regularMaterial).opacity(theme.isDark ? 0.18 : 0.42))
        }
        .overlay {
            shape.strokeBorder(theme.border.opacity(theme.isDark ? 0.55 : 0.38), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.32 : 0.16), radius: 22, y: 10)
    }

    private func metadataChip(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(theme.resolved.foreground.color.opacity(theme.isDark ? 0.08 : 0.055), in: Capsule())
    }

    private func approve(_ request: ConfirmRequest) {
        approvingRequestID = request.id
        Task { @MainActor in
            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                sovereignRequirement(for: request.preview),
                reason: sovereignReason(for: request.preview)
            ) ?? .denied(.authenticationFailed)
            queue.resolve(id: request.id, approved: outcome == .allowed)
            approvingRequestID = nil
        }
    }

    private func sovereignRequirement(for preview: ActionPreview) -> SovereignGateRequirement {
        let category = SovereignGateCategory(rawValue: "osaurus-computer-use-\(preview.effect.rawValue)")
        switch preview.effect {
        case .read, .navigate:
            return .biometric(category: category, graceDuration: 5 * 60)
        case .edit:
            return .biometric(category: category, graceDuration: 2 * 60)
        case .consequential:
            return .deviceOwnerAuthentication
        }
    }

    private func sovereignReason(for preview: ActionPreview) -> String {
        "Approve Act Computer Use to \(preview.summary)."
    }

    private func iconName(for effect: EffectClass) -> String {
        switch effect {
        case .read:
            return "eye"
        case .navigate:
            return "arrow.up.forward.app"
        case .edit:
            return "pencil"
        case .consequential:
            return "exclamationmark.triangle"
        }
    }

    private func effectTint(_ effect: EffectClass) -> Color {
        switch effect {
        case .read:
            return theme.textSecondary
        case .navigate:
            return theme.resolved.accent.color
        case .edit:
            return Color.orange
        case .consequential:
            return Color.red
        }
    }
}

private struct ActApprovalButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    let theme: EpistemosTheme
    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .background(backgroundColor(configuration.isPressed), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.8)
            }
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return Color.white
        case .secondary:
            return theme.textSecondary
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return theme.resolved.accent.color.opacity(0.28)
        case .secondary:
            return theme.border.opacity(0.52)
        }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch role {
        case .primary:
            return theme.resolved.accent.color.opacity(isPressed ? 0.74 : 0.94)
        case .secondary:
            return theme.resolved.foreground.color.opacity(isPressed ? 0.10 : 0.055)
        }
    }
}

@MainActor
private final class ActNativeSecretPromptSheetState: ObservableObject, Identifiable {
    let id = UUID()
    let request: EpistemosOsaurusNativeSecretPromptRequest
    @Published var value = ""
    private var continuation: CheckedContinuation<EpistemosOsaurusNativeSecretPromptDecision, Never>?

    init(
        request: EpistemosOsaurusNativeSecretPromptRequest,
        continuation: CheckedContinuation<EpistemosOsaurusNativeSecretPromptDecision, Never>
    ) {
        self.request = request
        self.continuation = continuation
    }

    var canSubmit: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        resolve(.provided(trimmed))
    }

    func cancel() {
        resolve(.canceled)
    }

    func cancelIfNeeded() {
        guard continuation != nil else { return }
        cancel()
    }

    private func resolve(_ decision: EpistemosOsaurusNativeSecretPromptDecision) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: decision)
    }
}

private struct ActNativeSecretPromptSheet: View {
    @ObservedObject var state: ActNativeSecretPromptSheetState
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ActNativePromptHeader(
                icon: "lock.fill",
                title: state.request.description,
                subtitle: "Stored in the Act agent Keychain.",
                theme: theme
            )

            Text(state.request.instructions)
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                Text(state.request.key)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)

                SecureField("Paste secret", text: $state.value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(actPromptInputBackground)
                    .overlay(actPromptInputBorder)
                    .onSubmit { state.submit() }
            }

            HStack(spacing: 10) {
                Button {
                    state.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(minWidth: 92, minHeight: 30)
                }
                .buttonStyle(ActApprovalButtonStyle(theme: theme, role: .secondary))
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    state.submit()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .frame(minWidth: 94, minHeight: 30)
                }
                .buttonStyle(ActApprovalButtonStyle(theme: theme, role: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!state.canSubmit)
            }
        }
        .padding(16)
        .frame(width: 470)
        .background(actPromptPanelBackground)
        .overlay(actPromptPanelBorder)
        .shadow(color: .black.opacity(theme.isDark ? 0.34 : 0.18), radius: 24, y: 12)
    }

    private var actPromptPanelBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(theme.card.opacity(theme.isDark ? 0.96 : 0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(theme.isDark ? 0.14 : 0.36)
            )
    }

    private var actPromptPanelBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(theme.border.opacity(theme.isDark ? 0.56 : 0.42), lineWidth: 0.8)
    }

    private var actPromptInputBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.07 : 0.045))
    }

    private var actPromptInputBorder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(theme.border.opacity(0.48), lineWidth: 0.75)
    }
}

@MainActor
private final class ActNativeClarifyPromptSheetState: ObservableObject, Identifiable {
    let id = UUID()
    let request: EpistemosOsaurusNativeClarifyPromptRequest
    @Published var selectedOptions: Set<String> = []
    @Published var customAnswer = ""
    private var continuation: CheckedContinuation<EpistemosOsaurusNativeClarifyPromptDecision, Never>?

    init(
        request: EpistemosOsaurusNativeClarifyPromptRequest,
        continuation: CheckedContinuation<EpistemosOsaurusNativeClarifyPromptDecision, Never>
    ) {
        self.request = request
        self.continuation = continuation
    }

    var canSubmit: Bool {
        !resolvedAnswer.isEmpty
    }

    var resolvedAnswer: String {
        let typed = customAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        let ordered = request.options.filter { selectedOptions.contains($0) }
        return ordered.joined(separator: ", ")
    }

    func tapOption(_ option: String) {
        if request.allowMultiple {
            if selectedOptions.contains(option) {
                selectedOptions.remove(option)
            } else {
                selectedOptions.insert(option)
            }
        } else {
            selectedOptions = [option]
        }
    }

    func submit() {
        let answer = resolvedAnswer
        guard !answer.isEmpty else { return }
        resolve(.answered(answer))
    }

    func cancel() {
        resolve(.canceled)
    }

    func cancelIfNeeded() {
        guard continuation != nil else { return }
        cancel()
    }

    private func resolve(_ decision: EpistemosOsaurusNativeClarifyPromptDecision) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: decision)
    }
}

private struct ActNativeClarifyPromptSheet: View {
    @ObservedObject var state: ActNativeClarifyPromptSheetState
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ActNativePromptHeader(
                icon: "questionmark.bubble.fill",
                title: "Act needs a detail",
                subtitle: "Answer this follow-up to continue the same Act run.",
                theme: theme
            )

            Text(state.request.question)
                .font(.system(size: 13))
                .foregroundStyle(theme.resolved.foreground.color)
                .fixedSize(horizontal: false, vertical: true)

            if !state.request.options.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.request.options, id: \.self) { option in
                        Button {
                            state.tapOption(option)
                            if !state.request.allowMultiple {
                                state.submit()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: state.selectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(state.selectedOptions.contains(option) ? theme.resolved.accent.color : theme.textTertiary)
                                Text(option)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.resolved.foreground.color)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(
                                        state.selectedOptions.contains(option)
                                            ? theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11)
                                            : theme.resolved.foreground.color.opacity(theme.isDark ? 0.06 : 0.035)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(
                                        state.selectedOptions.contains(option)
                                            ? theme.resolved.accent.color.opacity(0.42)
                                            : theme.border.opacity(0.36),
                                        lineWidth: 0.75
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TextField(state.request.options.isEmpty ? "Type your answer" : "Or type a custom answer", text: $state.customAnswer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(actPromptInputBackground)
                .overlay(actPromptInputBorder)
                .onSubmit { state.submit() }

            HStack(spacing: 10) {
                Button {
                    state.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(minWidth: 92, minHeight: 30)
                }
                .buttonStyle(ActApprovalButtonStyle(theme: theme, role: .secondary))
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    state.submit()
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                        .frame(minWidth: 104, minHeight: 30)
                }
                .buttonStyle(ActApprovalButtonStyle(theme: theme, role: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!state.canSubmit)
            }
        }
        .padding(16)
        .frame(width: 500)
        .background(actPromptPanelBackground)
        .overlay(actPromptPanelBorder)
        .shadow(color: .black.opacity(theme.isDark ? 0.34 : 0.18), radius: 24, y: 12)
    }

    private var actPromptPanelBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(theme.card.opacity(theme.isDark ? 0.96 : 0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(theme.isDark ? 0.14 : 0.36)
            )
    }

    private var actPromptPanelBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(theme.border.opacity(theme.isDark ? 0.56 : 0.42), lineWidth: 0.8)
    }

    private var actPromptInputBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.07 : 0.045))
    }

    private var actPromptInputBorder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(theme.border.opacity(0.48), lineWidth: 0.75)
    }
}

private struct ActNativePromptHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 28, height: 28)
                .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

@MainActor
private final class ActNativePrivacyReviewSheetState: ObservableObject, Identifiable {
    let id = UUID()
    let requestID: UUID
    let sessionId: String
    @Published var rows: [EpistemosOsaurusNativePrivacyReviewEntity]
    @Published var alwaysApprove: Bool
    @Published var selectedRowID: UUID?
    private var continuation: CheckedContinuation<EpistemosOsaurusNativePrivacyReviewDecision, Never>?

    init(
        request: EpistemosOsaurusNativePrivacyReviewRequest,
        continuation: CheckedContinuation<EpistemosOsaurusNativePrivacyReviewDecision, Never>
    ) {
        requestID = request.id
        sessionId = request.sessionId
        rows = request.entities
        alwaysApprove = request.alwaysApprove
        selectedRowID = request.entities.first?.id
        self.continuation = continuation
    }

    var approvedCount: Int {
        rows.filter(\.approved).count
    }

    var skippedCount: Int {
        rows.count - approvedCount
    }

    var allSkipped: Bool {
        !rows.isEmpty && approvedCount == 0
    }

    var selectedRow: EpistemosOsaurusNativePrivacyReviewEntity? {
        guard let selectedRowID else { return rows.first }
        return rows.first(where: { $0.id == selectedRowID }) ?? rows.first
    }

    func setApproved(_ id: UUID, to approved: Bool) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].approved = approved
    }

    func approveAll() {
        for index in rows.indices {
            rows[index].approved = true
        }
    }

    func skipAll() {
        for index in rows.indices {
            rows[index].approved = false
        }
    }

    func select(_ id: UUID) {
        selectedRowID = id
    }

    func approve() {
        resolve(.approved(rows: rows, alwaysApprove: alwaysApprove))
    }

    func cancel() {
        resolve(.canceled)
    }

    func cancelIfNeeded() {
        guard continuation != nil else { return }
        cancel()
    }

    private func resolve(_ decision: EpistemosOsaurusNativePrivacyReviewDecision) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: decision)
    }
}

private struct ActNativePrivacyReviewSheet: View {
    @ObservedObject var state: ActNativePrivacyReviewSheetState
    let theme: EpistemosTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            toolbar
            HSplitView {
                rowsList
                    .frame(minWidth: 300, idealWidth: 340)
                contextPreview
                    .frame(minWidth: 340, idealWidth: 440)
            }
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 840, minHeight: 460, idealHeight: 520)
        .background(theme.resolved.background.color)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 30, height: 30)
                .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Review redactions")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Text("Choose what Act should replace before this request leaves the local privacy filter.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("Approve All") {
                state.approveAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Skip All") {
                state.skipAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var rowsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(state.rows) { row in
                    reviewRow(row)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func reviewRow(_ row: EpistemosOsaurusNativePrivacyReviewEntity) -> some View {
        let selected = state.selectedRowID == row.id
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName(for: row.categoryRawValue))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 22, height: 22)
                .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(row.original)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text("\(categoryLabel(for: row.categoryRawValue)) -> \(row.placeholderToken)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(1)

            Toggle(
                "",
                isOn: Binding(
                    get: { state.rows.first(where: { $0.id == row.id })?.approved ?? row.approved },
                    set: { state.setApproved(row.id, to: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? theme.resolved.accent.color.opacity(0.10) : theme.card.opacity(theme.isDark ? 0.54 : 0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? theme.resolved.accent.color.opacity(0.50) : theme.border.opacity(0.40), lineWidth: selected ? 1.2 : 0.8)
        }
        .contentShape(Rectangle())
        .onTapGesture { state.select(row.id) }
    }

    @ViewBuilder
    private var contextPreview: some View {
        if let row = state.selectedRow {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: iconName(for: row.categoryRawValue))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.resolved.accent.color)
                        .frame(width: 26, height: 26)
                        .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.original)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(row.placeholderToken)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.resolved.accent.color)
                    }
                    Spacer()
                }

                Text("Preview")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)

                ScrollView {
                    Text(scrubbedPreview(for: row))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(theme.resolved.foreground.color.opacity(theme.isDark ? 0.06 : 0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.border.opacity(0.36), lineWidth: 0.8)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView("No redactions", systemImage: "hand.raised")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $state.alwaysApprove) {
                Text("Always approve in this conversation")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
            }
            .toggleStyle(.checkbox)

            if state.allSkipped {
                Label("Every detection is skipped. Sending will include the original text.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            HStack(spacing: 12) {
                Text("\(state.approvedCount) approved - \(state.skippedCount) skipped")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button("Cancel") {
                    state.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(state.allSkipped ? "Send Anyway" : "Send") {
                    state.approve()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(state.allSkipped ? .red : theme.resolved.accent.color)
                .keyboardShortcut(state.allSkipped ? nil : .defaultAction)
            }
        }
        .padding(20)
    }

    private func scrubbedPreview(for row: EpistemosOsaurusNativePrivacyReviewEntity) -> String {
        let source = row.containingText?.isEmpty == false ? row.containingText ?? "" : row.original
        let peers = state.rows
            .filter { $0.containingText == row.containingText && $0.approved }
            .sorted { $0.original.count > $1.original.count }
        return peers.reduce(source) { partial, peer in
            partial.replacingOccurrences(of: peer.original, with: peer.placeholderToken)
        }
    }

    private func categoryLabel(for rawValue: String) -> String {
        switch rawValue {
        case "accountNumber": return "Account"
        case "address": return "Address"
        case "email": return "Email"
        case "person": return "Person"
        case "phone": return "Phone"
        case "url": return "URL"
        case "date": return "Date"
        case "secret": return "Secret"
        default: return rawValue
        }
    }

    private func iconName(for rawValue: String) -> String {
        switch rawValue {
        case "accountNumber": return "creditcard.fill"
        case "address": return "house.fill"
        case "email": return "envelope.fill"
        case "person": return "person.fill"
        case "phone": return "phone.fill"
        case "url": return "link"
        case "date": return "calendar"
        case "secret": return "key.fill"
        default: return "hand.raised.fill"
        }
    }
}
#endif

// MARK: - Streaming Indicator

private struct StreamingIndicator: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(PipelineState.self) private var pipeline
    @Environment(InferenceState.self) private var inference
    let selectedOperatingMode: EpistemosOperatingMode
    var showsActivityStrip = true

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        streamingView
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            let selection = inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)
            let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(from: chat.streamingText)
            let finalStreamingText = UserFacingModelOutput.finalVisibleText(from: chat.streamingText)
            let expectsThinkingUI =
                selectedOperatingMode.capturesReasoningTrace
                && selection.supportsThinking
                && (
                    (pipeline.isProcessing && !chat.isStreaming)
                        || (chat.isStreaming && visibleStreamingText.isEmpty)
                )

            // Big visible status strip: "🔎 Searching the web for 'X'"
            // / "🧠 Thinking 12s" / "✍️ Writing reply…". Pops in the
            // moment the stream starts and swaps live as the phase
            // changes — first thing the user sees so tool use + thinking
            // is never a black box.
            if showsActivityStrip && (chat.isStreaming || chat.isAgentExecuting) {
                LiveActivityStrip(
                    toolName: chat.isAgentExecuting ? chat.activeToolName : nil,
                    toolInputJson: chat.activeToolInputJson,
                    isThinkingActive: expectsThinkingUI || chat.isThinkingActive,
                    thinkingStartedAt: chat.thinkingStartedAt,
                    isStreaming: chat.isStreaming
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if ChatStreamingDisplayPolicy.showsLiveResponseText, !visibleStreamingText.isEmpty {
                AssistantInlineTranscriptView(
                    rawContent: chat.streamingText,
                    displayContent: visibleStreamingText + (chat.isStreaming ? " ▍" : ""),
                    contentBlocks: chat.pendingContentBlocks,
                    persistedThinking: chat.streamingThinking,
                    thinkingDurationSeconds: nil,
                    isStreaming: chat.isStreaming,
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if expectsThinkingUI || chat.isThinkingActive || !chat.streamingThinking.isEmpty || !chat.pendingContentBlocks.isEmpty {
                AssistantInlineTranscriptView(
                    rawContent: chat.streamingText,
                    displayContent: "",
                    contentBlocks: chat.pendingContentBlocks,
                    persistedThinking: chat.streamingThinking,
                    thinkingDurationSeconds: nil,
                    isStreaming: chat.isStreaming,
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !chat.isStreaming, !finalStreamingText.isEmpty {
                AssistantInlineTranscriptView(
                    rawContent: chat.streamingText,
                    displayContent: finalStreamingText,
                    contentBlocks: chat.pendingContentBlocks,
                    persistedThinking: chat.streamingThinking,
                    thinkingDurationSeconds: nil,
                    isStreaming: false,
                    theme: theme
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pipeline.isProcessing && !chat.isStreaming && !chat.isAgentExecuting {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading \(inference.activeChatModelDisplayName)…")
                        .font(ClaudeAppTypography.userFont(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .assistantInsetChrome(theme: theme, cornerRadius: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatBrainPanelView: View {
    @Environment(UIState.self) private var ui
    let snapshot: ChatBrainSnapshot?
    let capturedModelInput: CapturedModelInput?
    let pendingContextAttachments: [ContextAttachment]
    let pendingAttachments: [FileAttachment]
    /// Owner 2026-06-24: the right-side context panel needs an in-panel CLOSE button (it was only toggleable
    /// from the composer/toolbar). nil → header omitted (back-compat).
    var onClose: (() -> Void)? = nil

    private var theme: EpistemosTheme { ui.theme }

    private var hasPendingContext: Bool {
        !pendingContextAttachments.isEmpty || !pendingAttachments.isEmpty
    }

    /// Header with a title + close (X) button so the panel can be dismissed directly (owner-requested).
    @ViewBuilder
    private var panelHeader: some View {
        if let onClose {
            HStack(spacing: 8) {
                Text("Context")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close context panel")
                .accessibilityLabel("Close context panel")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider().opacity(0.4)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if hasPendingContext {
                    // Pre-submit preview — removals still happen in the
                    // composer pill row so the panel stays read-only.
                    section(title: "READY TO SEND", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(pendingContextAttachments) { attachment in
                                detailRow(
                                    attachment.title,
                                    attachment.subtitle ?? attachment.kind.rawValue.capitalized
                                )
                            }
                            ForEach(pendingAttachments) { attachment in
                                detailRow(
                                    attachment.name,
                                    attachment.type.rawValue.capitalized,
                                    valueMonospaced: true
                                )
                            }
                        }
                    }
                }

                if let snapshot {
                    section(title: "ROUTING", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow("Route", snapshot.routeLabel)
                            detailRow("Summary", snapshot.routeSummary)
                            detailRow("Runtime", snapshot.providerLabel, valueMonospaced: true)
                            detailRow(
                                "Model",
                                snapshot.modelLabel ?? "Unknown",
                                valueMonospaced: true
                            )
                            detailRow("Mode", snapshot.operatingMode.displayName)
                            detailRow(
                                "Captured",
                                snapshot.capturedAt.formatted(date: .abbreviated, time: .standard)
                            )
                        }
                    }

                    section(title: "REQUEST", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            bodyBlock(snapshot.query)
                            if snapshot.resolvedQuery != snapshot.query {
                                Divider().opacity(0.4)
                                detailRow("Resolved", "After explicit-context cleanup and routing")
                                bodyBlock(snapshot.resolvedQuery)
                            }
                        }
                    }

                    if !snapshot.contextAttachments.isEmpty {
                        section(title: "EXPLICIT ATTACHMENTS", defaultExpanded: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(snapshot.contextAttachments) { attachment in
                                    detailRow(
                                        attachment.title,
                                        attachment.subtitle ?? attachment.kind.rawValue.capitalized
                                    )
                                }
                            }
                        }
                    }

                    if !snapshot.loadedNoteTitles.isEmpty {
                        section(title: "LOADED NOTES", defaultExpanded: true) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(snapshot.loadedNoteTitles, id: \.self) { title in
                                    Text(title)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    if !snapshot.allowedToolNames.isEmpty {
                        section(title: "TOOLS THIS TURN", defaultExpanded: false) {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(snapshot.allowedToolNames, id: \.self) { tool in
                                    HStack(spacing: 7) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(theme.textTertiary)
                                        Text(tool)
                                            .font(panelBodyFont(size: 12))
                                            .foregroundStyle(theme.textSecondary)
                                            .textSelection(.enabled)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer(minLength: 0)
                                        copyButton(text: tool, label: "Copy tool name")
                                    }
                                    .contextMenu {
                                        Button("Copy Tool Name") {
                                            copyToPasteboard(tool)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let capturedModelInput {
                        section(title: "MODEL INPUT", defaultExpanded: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRow(
                                    "Runtime",
                                    capturedModelInput.runtimeLabel,
                                    valueMonospaced: true
                                )
                                Divider().opacity(0.4)
                                detailRow("User", "User prompt")
                                bodyBlock(capturedModelInput.userPrompt)

                                if let systemPrompt = capturedModelInput.systemPrompt {
                                    Divider().opacity(0.4)
                                    detailRow("System", "System prompt")
                                    bodyBlock(systemPrompt)
                                }

                                if let messageHistory = capturedModelInput.messageHistory {
                                    Divider().opacity(0.4)
                                    detailRow("History", "Conversation before wrapping")
                                    bodyBlock(messageHistory)
                                }

                                if let toolDefinitionsJSON = capturedModelInput.toolDefinitionsJSON {
                                    Divider().opacity(0.4)
                                    detailRow("Tools", "Tool definitions sent this turn")
                                    bodyBlock(toolDefinitionsJSON)
                                }
                            }
                        }
                    }

                    ForEach(snapshot.sections) { sectionBlock in
                        section(title: sectionBlock.title.uppercased(), defaultExpanded: false) {
                            bodyBlock(sectionBlock.body)
                        }
                    }

                    // Evidence intake surfaces both Eidos and VaultRecall
                    // so vault lookups do not look idle just because the
                    // citation validator has not run on that launch.
                    section(title: "EVIDENCE INTAKE", defaultExpanded: true) {
                        EidosRetrievedSection()
                    }
                } else if !hasPendingContext {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MODEL CONTEXT")
                            .font(panelHeadingFont(size: 9.5, level: 2))
                            .tracking(0.8)
                            .foregroundStyle(theme.textTertiary)
                            .padding(.top, 4)
                        Text("After you send, this shows the notes, files, tools, and routing for that turn. Use @ or attachments to preview context first.")
                            .font(panelBodyFont(size: 12))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 8)
            }
        }
        .background(theme.resolved.background.color)
    }

    /// Collapsible section header styled like Claude Code's sidebar —
    /// small uppercase heading with tracking, chevron disclosure, no
    /// card chrome, thin divider underneath.
    @ViewBuilder
    private func section<Content: View>(
        title: String,
        defaultExpanded: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        BrainPanelSection(
            title: title,
            defaultExpanded: defaultExpanded,
            theme: theme,
            content: content
        )
    }

    @ViewBuilder
    private func detailRow(
        _ label: String,
        _ value: String,
        valueMonospaced: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(panelBodyFont(size: 11.5, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 84, alignment: .leading)
            HStack(alignment: .top, spacing: 6) {
                Text(value)
                    .font(valueMonospaced ? panelMonoFont(size: 11.5) : panelBodyFont(size: 12.5))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                copyButton(text: value, label: "Copy \(label)")
                    .padding(.top, 1)
            }
        }
        .contextMenu {
            Button("Copy \(label)") {
                copyToPasteboard(value)
            }
        }
    }

    @ViewBuilder
    private func bodyBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(text)
                .font(panelBodyFont(size: 12.5))
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            copyButton(text: text, label: "Copy text")
                .padding(.top, 1)
        }
        .contextMenu {
            Button("Copy Text") {
                copyToPasteboard(text)
            }
        }
    }

    private func panelBodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppDisplayTypography.font(size: size, weight: weight, allowDisplayFont: false)
    }

    private func panelMonoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        AppDisplayTypography.monoFont(size: size, weight: weight)
    }

    private func panelHeadingFont(size: CGFloat, level: Int) -> Font {
        AppDisplayTypography.headingFont(size: size, weight: .semibold, theme: theme, level: level)
    }

    @ViewBuilder
    private func copyButton(text: String, label: String) -> some View {
        Button {
            copyToPasteboard(text)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(theme.textTertiary.opacity(0.76))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Claude Code-style section: uppercase tracked header, chevron on the
/// right, no card chrome, thin bottom divider. Manages its own expand
/// state; the row is one big Button so the whole line is the tap target.
private struct BrainPanelSection<Content: View>: View {
    let title: String
    let defaultExpanded: Bool
    let theme: EpistemosTheme
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool?

    private var expanded: Bool {
        isExpanded ?? defaultExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    isExpanded = !expanded
                }
            } label: {
                HStack {
                    Text(title)
                        .font(AppDisplayTypography.headingFont(size: 9.5, weight: .semibold, theme: theme, level: 2))
                        .tracking(0.8)
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if expanded {
                content()
                    .padding(12)
                    .brainPanelFlatCard(theme: theme)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.opacity(0.35))
                .frame(height: 0.5)
        }
    }
}

private struct BrainPanelFlatCardModifier: ViewModifier {
    let theme: EpistemosTheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(theme.card.opacity(theme.isDark ? 0.58 : 0.72))
                    shape.fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.022 : 0.012))
                }
            }
            .overlay {
                shape.strokeBorder(theme.border.opacity(theme.isDark ? 0.52 : 0.42), lineWidth: 0.75)
            }
    }
}

private extension View {
    func brainPanelFlatCard(theme: EpistemosTheme) -> some View {
        modifier(BrainPanelFlatCardModifier(theme: theme))
    }
}
