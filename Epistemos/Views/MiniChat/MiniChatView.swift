import SwiftData
import SwiftUI

private enum MiniChatLayout {
    static let messageColumnMaxWidth: CGFloat = 560
    static let composerMaxWidth: CGFloat = 620
    static let userBubbleMaxWidth: CGFloat = 360
    static let toolbarHeight: CGFloat = 36
}

// MARK: - MiniChat View
// Floating single-thread chat panel with input.

struct MiniChatView: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Environment(\.modelContext) private var modelContext
    @Query(SDChat.recentChatsDescriptor) private var recentChats: [SDChat]
    @State private var showRecentChats = false
    @State private var appliedInitialContextAttachment = false

    let chatID: String
    let initialContextAttachment: ContextAttachment?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            miniChatHeader
            if showRecentChats {
                MiniChatRecentChatsList(recentChats: recentChats) {
                    showRecentChats = false
                }
            } else {
                MiniChatThread(chatID: chatID)
                miniChatDivider
                MiniChatInputBar(chatID: chatID)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 36) // leave room for traffic lights; glass extends behind them
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            theme.resolved.foreground.color.opacity(theme.isDark ? 0.10 : 0.12),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(theme.isDark ? 0.45 : 0.22), radius: 28, y: 12)
                .ignoresSafeArea()
        )
        .onAppear {
            Task { @MainActor in
                loadMiniChatSessionIfNeeded()
            }
        }
    }

    private var miniChatHeader: some View {
        HStack(spacing: 10) {
            if showRecentChats {
                Button(action: { showRecentChats = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Back")
            }

            Text(showRecentChats ? "Recent Chats" : activeTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.resolved.foreground.color)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button(action: { showRecentChats = true }) {
                Label("Recent Chats", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Recent Chats")

            Button(action: { MiniChatWindowController.shared.openNewChat() }) {
                Label("Add Chat", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Add Chat")
        }
        .frame(height: MiniChatLayout.toolbarHeight)
    }

    private var activeTitle: String {
        threadState.miniChatSession(id: chatID)?.label ?? "Mini Chat"
    }

    private var miniChatDivider: some View {
        Rectangle()
            .fill(theme.glassBorder.opacity(theme.isDark ? 0.72 : 0.5))
            .frame(height: 0.5)
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
    }

    private func loadMiniChatSessionIfNeeded() {
        let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatID })
        let chat: SDChat?
        do {
            chat = try modelContext.fetch(descriptor).first
        } catch {
            Log.pipeline.error(
                "MiniChatView: failed to fetch persisted mini chat \(chatID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            threadState.ensureMiniChatSession(id: chatID)
            applyInitialContextAttachmentIfNeeded()
            return
        }

        if let chat {
            let current = threadState.miniChatSession(id: chatID)
            let needsRestore = current == nil
                || current?.messages.isEmpty == true
                || current?.contextAttachments.isEmpty == true
            guard needsRestore else {
                MiniChatWindowController.shared.updateWindowTitle(chatID: chat.id, title: current?.label ?? chat.title)
                return
            }
            threadState.upsertMiniChatSession(
                id: chat.id,
                label: chat.title,
                pageId: chat.linkedPageId,
                messages: chat.sortedMessages.map { message in
                    AssistantMessage(
                        id: message.id,
                        role: MessageRole(rawValue: message.role) ?? .assistant,
                        content: message.content,
                        thinkingTrace: message.thinkingTrace,
                        thinkingDurationSeconds: message.thinkingDurationSeconds,
                        loadedNoteTitles: message.chatMessage(chatId: chat.id).loadedNoteTitles,
                        contextAttachments: message.chatMessage(chatId: chat.id).contextAttachments,
                        createdAt: message.createdAt
                    )
                }
            )
            MiniChatWindowController.shared.updateWindowTitle(chatID: chat.id, title: chat.title)
            applyInitialContextAttachmentIfNeeded()
            return
        }
        threadState.ensureMiniChatSession(id: chatID)
        applyInitialContextAttachmentIfNeeded()
    }

    private func applyInitialContextAttachmentIfNeeded() {
        guard !appliedInitialContextAttachment, let initialContextAttachment else { return }
        appliedInitialContextAttachment = true
        let existingAttachments = threadState.miniChatSession(id: chatID)?.contextAttachments ?? []
        guard !existingAttachments.contains(initialContextAttachment) else { return }
        threadState.addMiniChatContextAttachment(initialContextAttachment, chatID: chatID)
    }
}

// MARK: - Thread View

private struct MiniChatThread: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    let chatID: String

    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    private var theme: EpistemosTheme { ui.theme }

    private var miniChatThread: ChatThread? {
        threadState.miniChatSession(id: chatID)
    }

    private var hasContent: Bool {
        if let thread = miniChatThread, !thread.messages.isEmpty { return true }
        return threadState.miniChatIsStreaming(chatID: chatID)
    }

    var body: some View {
        Group {
            if hasContent {
                ScrollViewReader { proxy in
                    ScrollView {
                        HStack {
                            Spacer(minLength: 0)
                            LazyVStack(spacing: ChatLayout.transcriptSpacing) {
                                if let thread = miniChatThread {
                                    ForEach(thread.messages) { msg in
                                        MiniChatBubble(message: msg)
                                            .frame(maxWidth: .infinity)
                                            .id(msg.id)
                                    }
                                }

                                if threadState.miniChatIsStreaming(chatID: chatID) {
                                    let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(
                                        from: threadState.miniChatStreamingText(chatID: chatID)
                                    )
                                    let streamingThinking = threadState.miniChatStreamingThinking(chatID: chatID)
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    MiniChatAssistantBubbleChrome {
                                        VStack(alignment: .leading, spacing: Spacing.md) {
                                            if visibleStreamingText.isEmpty {
                                                AssistantTypingIndicatorDots(
                                                    theme: theme,
                                                    accent: theme.resolved.accent.color
                                                )
                                            } else {
                                                TaggedMarkdownTextView(
                                                    content: visibleStreamingText + " ▍",
                                                    theme: theme
                                                )
                                                .textSelection(.enabled)
                                            }

                                            if !streamingThinking.isEmpty {
                                                ThinkingTrailView(content: streamingThinking)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("streaming")
                                }

                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .frame(maxWidth: MiniChatLayout.messageColumnMaxWidth)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, 18)
                    }
                    .onScrollGeometryChange(
                        for: CGFloat.self,
                        of: ScrollStability.distanceToBottom(for:)
                    ) { _, distance in
                        let nextState = ScrollStability.updatedAutoFollowState(
                            from: autoFollow,
                            distanceToBottom: distance
                        )
                        guard nextState != autoFollow else { return }
                        autoFollow = nextState
                    }
                    .onChange(of: miniChatThread?.messages.count) { _, _ in
                        guard autoFollow.isFollowingBottom else { return }
                        autoFollow.markProgrammaticScrollToBottom()
                        withAnimation(Motion.quick) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: threadState.miniChatStreamingText(chatID: chatID)) { _, _ in
                        let now = ContinuousClock.now
                        guard autoFollow.isFollowingBottom,
                              now - lastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                        else { return }
                        lastScrollTime = now
                        autoFollow.markProgrammaticScrollToBottom()
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    .onAppear {
                        Task { @MainActor in
                            autoFollow.markProgrammaticScrollToBottom()
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            } else {
                Text("Mini Chat")
                    .font(AppDisplayTypography.font(size: 34))
                    .foregroundStyle(theme.fontAccent.opacity(theme.isDark ? 0.94 : 0.9))
                    .shadow(
                        color: theme.isDark ? theme.fontAccent.opacity(0.12) : .clear,
                        radius: 8
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MiniChatRecentChatsList: View {
    let recentChats: [SDChat]
    let onSelect: () -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(recentChats, id: \.id) { chat in
                    Button {
                        MiniChatWindowController.shared.openChat(chat.id)
                        onSelect()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(chat.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.resolved.foreground.color)
                                    .lineLimit(1)
                                Spacer(minLength: 12)
                                Text(chat.updatedAt.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(theme.mutedForeground)
                            }

                            if let preview = preview(for: chat) {
                                Text(preview)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundStyle(theme.mutedForeground)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(theme.border.opacity(0.8), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func preview(for chat: SDChat) -> String? {
        ChatPreviewText.preview(for: chat)
    }
}

// MARK: - Chat Bubble

private struct MiniChatAssistantBubbleChrome<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        AssistantTranscriptChrome {
            content
        }
    }
}

private struct MiniChatBubble: View {
    let message: AssistantMessage

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var isUser: Bool { message.role == .user }

    var body: some View {
        let displayContent = message.role == .assistant
            ? UserFacingModelOutput.finalVisibleText(from: message.content)
            : message.content
        if isUser {
            TaggedMarkdownTextView(
                content: displayContent,
                theme: theme,
                rippleStyle: .none,
                foregroundOverride: theme.userBubbleText
            )
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: MiniChatLayout.userBubbleMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            MiniChatAssistantBubbleChrome {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    TaggedMarkdownTextView(content: displayContent, theme: theme)
                        .textSelection(.enabled)

                    if let thinkingTrace = message.thinkingTrace?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !thinkingTrace.isEmpty {
                        ThinkingTrailView(
                            content: thinkingTrace,
                            durationSeconds: message.thinkingDurationSeconds
                        )
                    }

                    AssistantSourcesFooter(
                        sources: AssistantSourceReference.extract(
                            from: displayContent,
                            noteTitles: message.loadedNoteTitles ?? []
                        ),
                        theme: theme,
                        compact: true
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MiniChatNoteSnapshot: Equatable {
    let title: String
    let tags: [String]
    let body: String

    init(title: String, tags: [String] = [], body: String) {
        self.title = title
        self.tags = tags
        self.body = body
    }

    init(title: String, tags: [String] = [], bodyProvider: () -> String) {
        self.init(title: title, tags: tags, body: bodyProvider())
    }

    @MainActor init(page: SDPage) {
        self.init(page: page, preferredBody: nil)
    }

    @MainActor init(page: SDPage, preferredBody: String?) {
        let body = preferredBody ?? NoteWindowManager.shared.currentBody(for: page.id)
        self.init(title: page.title, tags: page.tags, body: body)
    }

    var hasBody: Bool {
        !body.isEmpty
    }

    var lowercasedBody: String {
        body.lowercased()
    }

    var shortSnippet: String {
        String(body.prefix(300))
    }

    var promptSnippet: String {
        String(body.prefix(2000))
    }
}

@MainActor
final class MiniChatSnapshotStore {
    private var snapshots: [String: MiniChatNoteSnapshot] = [:]

    func snapshot(for page: SDPage, preferredBody: String? = nil) -> MiniChatNoteSnapshot {
        if let preferredBody {
            let snapshot = MiniChatNoteSnapshot(page: page, preferredBody: preferredBody)
            snapshots[page.id] = snapshot
            return snapshot
        }
        if let cached = snapshots[page.id] {
            return cached
        }
        let snapshot = MiniChatNoteSnapshot(page: page)
        snapshots[page.id] = snapshot
        return snapshot
    }
}

struct MiniChatSearchCandidate {
    let id: String
    let title: String
    private let cachedSnapshot: MiniChatNoteSnapshot?
    private let snapshotProvider: (() -> MiniChatNoteSnapshot)?

    init(id: String, title: String, bodyProvider: @escaping () -> String) {
        self.id = id
        self.title = title
        self.cachedSnapshot = nil
        self.snapshotProvider = {
            MiniChatNoteSnapshot(title: title, bodyProvider: bodyProvider)
        }
    }

    init(id: String, title: String, snapshot: MiniChatNoteSnapshot) {
        self.id = id
        self.title = title
        self.cachedSnapshot = snapshot
        self.snapshotProvider = nil
    }

    init(page: SDPage, snapshotStore: MiniChatSnapshotStore, preferredBody: String? = nil) {
        id = page.id
        title = page.title
        cachedSnapshot = nil
        snapshotProvider = {
            snapshotStore.snapshot(for: page, preferredBody: preferredBody)
        }
    }

    func snapshot() -> MiniChatNoteSnapshot {
        if let cachedSnapshot {
            return cachedSnapshot
        }
        return snapshotProvider?() ?? MiniChatNoteSnapshot(title: title, body: "")
    }
}

enum MiniChatVaultSearch {
    static func snippets(
        query: String,
        activeId: String?,
        pages: [MiniChatSearchCandidate]
    ) -> [(title: String, snippet: String)] {
        let terms = query.lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 }

        guard !terms.isEmpty else { return [] }

        var snapshots: [String: MiniChatNoteSnapshot] = [:]
        snapshots.reserveCapacity(pages.count)

        func snapshot(for candidate: MiniChatSearchCandidate) -> MiniChatNoteSnapshot {
            if let cached = snapshots[candidate.id] {
                return cached
            }
            let created = candidate.snapshot()
            snapshots[candidate.id] = created
            return created
        }

        var matches = pages.filter { candidate in
            guard candidate.id != activeId else { return false }
            let title = candidate.title.lowercased()
            return terms.contains { title.contains($0) }
        }

        if matches.count < 3 {
            let titleIds = Set(matches.map(\.id))
            let bodyMatches = pages.prefix(30).filter { candidate in
                guard candidate.id != activeId, !titleIds.contains(candidate.id) else { return false }
                let body = snapshot(for: candidate).lowercasedBody
                return terms.contains { body.contains($0) }
            }
            matches.append(contentsOf: bodyMatches)
        }

        return Array(matches.prefix(3).map { candidate in
            let page = snapshot(for: candidate)
            return (title: candidate.title, snippet: page.shortSnippet)
        })
    }
}

// MARK: - Input Bar

private struct MiniChatInputBar: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Environment(TriageService.self) private var triage
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference
    @Environment(\.modelContext) private var modelContext
    @AppStorage("epistemos.miniChatOperatingMode")
    private var operatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @State private var text = ""
    @State private var isProcessing = false
    @State private var streamTask: Task<Void, Never>?
    @State private var isFocused = false
    @State private var composerHeight = ChatComposerInputMetrics.minHeight

    // @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""
    @State private var mentionPickerAutofocus = false
    @State private var referencePopoverStyle: ComposerReferencePopoverStyle = .mention
    @State private var referenceSearch = ComposerReferenceSearchState()
    @State private var snapshotStore = MiniChatSnapshotStore()

    let chatID: String

    private var theme: EpistemosTheme { ui.theme }
    private var composerAccentColor: Color { theme.resolved.accent.color }
    private let composerMetrics = AssistantComposerMetrics.compactChat
    private var supportedOperatingModes: [EpistemosOperatingMode] {
        let modes = inference.availableOperatingModes.filter { $0 != .agent }
        return modes.isEmpty ? [.fast] : modes
    }
    private func sanitizedMiniChatOperatingMode(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        guard supportedOperatingModes.contains(mode) else {
            return supportedOperatingModes.first ?? .fast
        }
        return mode
    }
    private var selectedOperatingMode: EpistemosOperatingMode {
        get {
            sanitizedMiniChatOperatingMode(
                EpistemosOperatingMode(rawValue: operatingModeRaw) ?? .fast
            )
        }
        nonmutating set {
            operatingModeRaw = sanitizedMiniChatOperatingMode(newValue).rawValue
        }
    }
    private var operatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { selectedOperatingMode },
            set: { selectedOperatingMode = $0 }
        )
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    private var composerIsActive: Bool {
        isFocused || canSend || isProcessing || !activeContextAttachments.isEmpty
    }
    private var composerStatusPhase: AssistantComposerStatusPhase {
        AssistantComposerStatusPhase.resolve(
            isActive: isProcessing || threadState.miniChatIsStreaming(chatID: chatID),
            streamingText: threadState.miniChatStreamingText(chatID: chatID)
        )
    }
    private var composerHaloStyle: AssistantComposerHaloStyle? {
        AssistantComposerHaloStyle.resolve(for: composerStatusPhase)
    }
    private var composerStatusLabelState: AssistantComposerStatusLabelState? {
        AssistantComposerStatusLabelState.resolve(
            inputText: text,
            phase: composerStatusPhase,
            idleText: ComposerAttachmentEntryHints.mainChatPlaceholder,
            showsIdleLabel: false,
            analyzingText: "Loading \(inference.activeChatModelDisplayName)…"
        )
    }
    private var composerTextAreaHeight: CGFloat {
        max(ChatComposerInputMetrics.minHeight, composerHeight)
    }

    private var miniChatThread: ChatThread? {
        threadState.miniChatSession(id: chatID)
    }

    private var trimmedMentionFilter: String {
        mentionFilter.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var ambientManifest: VaultManifest? {
        vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest
    }

    private var activeContextAttachments: [ContextAttachment] {
        miniChatThread?.contextAttachments ?? []
    }

    private var explicitScopedPageID: String? {
        if let attachedPageID = activeContextAttachments.first(where: { $0.kind == .note })?.targetId {
            return attachedPageID
        }
        return miniChatThread?.pageId
    }

    private var mentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        guard showMentionDropdown else {
            return ChatCoordinator.ReferenceSearchResults(
                notes: [], chats: [], vaultTitle: nil, vaultNoteCount: 0,
                isInventoryComplete: true, query: "", indexedMatchedNoteIDs: [],
                indexedNoteSnippetsByPageID: [:]
            )
        }
        let shouldSearchChats = !trimmedMentionFilter.isEmpty
        return ChatCoordinator.searchReferenceResults(
            filter: trimmedMentionFilter,
            manifest: ambientManifest,
            chats: shouldSearchChats ? recentChats() : [],
            threads: shouldSearchChats ? threadState.chatThreads : [],
            indexedNoteIDs: referenceSearch.indexedNoteIDs,
            indexedNoteSnippets: referenceSearch.indexedNoteSnippetsByPageID
        )
    }

    private var composerControlResetKey: String {
        supportedOperatingModes.map(\.rawValue).joined(separator: "|")
            + "::"
            + inference.activeChatModelDisplayName
    }

    var body: some View {
        VStack(spacing: 8) {
            if explicitScopedPageID != nil, activePage() != nil, !isProcessing {
                quickActions
            }

            if !activeContextAttachments.isEmpty {
                composerAttachmentChips
            }

            VStack(alignment: .leading, spacing: 0) {
                composerTextArea

                HStack(alignment: .center, spacing: MainChatComposerLayout.controlRowSpacing) {
                    ComposerControlStrip(spacing: 8, resetKey: composerControlResetKey) {
                        LocalModelToolbarMenu(
                            variant: .toolbar,
                            operatingMode: operatingModeBinding,
                            availableOperatingModes: supportedOperatingModes
                        )
                            .accessibilityLabel("Chat model")
                    }

                    Spacer(minLength: 4)

                    // Capability pill — shared signal across main/mini/note/graph
                    // chat. Mini chat doesn't own a full ChatState, so the
                    // capability is derived inline from the active provider +
                    // whether this composer is currently mid-stream. Agent tier
                    // is reserved for the main-chat surface today (mini chat
                    // doesn't drive the agent loop directly).
                    ChatCapabilityPill(
                        capability: ChatCapability.classify(
                            isCloudProvider: {
                                switch inference.preferredChatModelSelection {
                                case .cloud: true
                                case .localMLX, .appleIntelligence: false
                                }
                            }(),
                            isAgentExecuting: false,
                            isResearchMode: false,
                            isThinkingMode: false
                        )
                    )

                    AssistantSendButton(
                        theme: theme,
                        isEnabled: canSend,
                        isProcessing: isProcessing,
                        metrics: composerMetrics
                    ) {
                        if isProcessing {
                            cancelStream()
                        } else {
                            send()
                        }
                    }
                    .help(isProcessing ? "Stop" : "Send")
                    .accessibilityLabel(isProcessing ? "Stop generating" : "Send message")
                }
                .padding(.top, MainChatComposerLayout.controlRowTopPadding)
            }
            .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
            .padding(.top, MainChatComposerLayout.topPadding)
            .padding(.bottom, MainChatComposerLayout.bottomPadding)
            .assistantComposerChrome(
                theme: theme,
                metrics: composerMetrics,
                isActive: composerIsActive
            )
            .background {
                AssistantComposerOuterHalo(
                    style: composerHaloStyle,
                    accent: composerAccentColor,
                    cornerRadius: composerMetrics.cornerRadius,
                    animatesContinuously: false
                )
            }
        }
        .frame(maxWidth: MiniChatLayout.composerMaxWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            sanitizeStoredOperatingMode()
        }
        .onDisappear {
            cancelStream()
        }
        .onChange(of: inference.supportsThinkingOperatingMode) { _, _ in
            sanitizeStoredOperatingMode()
        }
        .overlay(alignment: .topLeading) {
            if showMentionDropdown {
                ComposerReferencePopover(
                    isPresented: $showMentionDropdown,
                    results: mentionSearchResults,
                    query: $mentionFilter,
                    manifest: ambientManifest,
                    modelContext: modelContext,
                    idealWidth: referencePopoverStyle.idealWidth,
                    maxHeight: referencePopoverStyle.maxHeight,
                    style: referencePopoverStyle,
                    autofocusSearchField: mentionPickerAutofocus,
                    onDismiss: dismissReferencePopover,
                    onSelect: attachMentionReference
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var composerTextArea: some View {
        ChatComposerTextEditor(
            text: $text,
            height: $composerHeight,
            isFocused: $isFocused,
            theme: theme,
            isProcessing: isProcessing
        ) {
            send()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: composerHeight)
        .accessibilityLabel("Mini chat message input")
        .overlay(alignment: .topLeading) {
            if let labelState = composerStatusLabelState {
                AssistantAnimatedStatusLabel(
                    state: labelState,
                    accent: composerAccentColor,
                    phase: composerStatusPhase,
                    theme: theme,
                    font: .system(size: 16, weight: .regular, design: .rounded),
                    haloStyle: composerHaloStyle
                )
                .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                .padding(.leading, ChatComposerInputMetrics.horizontalInset)
            }
        }
        .overlay(alignment: .topLeading) {
            if text.isEmpty && composerStatusLabelState == nil {
                Text(ComposerAttachmentEntryHints.mainChatPlaceholder)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.mutedForeground.opacity(0.55))
                    .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                    .padding(.leading, ChatComposerInputMetrics.horizontalInset)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: composerTextAreaHeight, alignment: .topLeading)
        .onChange(of: text) { _, newVal in
            if let filter = ComposerReferenceHelpers.mentionFilter(in: newVal) {
                referencePopoverStyle = .mention
                mentionFilter = filter
                mentionPickerAutofocus = false
                if !showMentionDropdown { showMentionDropdown = true }
            } else if showMentionDropdown {
                showMentionDropdown = false
                referencePopoverStyle = .mention
                mentionPickerAutofocus = false
                referenceSearch.reset()
            }
        }
        .onChange(of: mentionFilter) { _, newValue in
            updateMentionReferenceSearch(filter: newValue)
        }
    }

    private func sanitizeStoredOperatingMode() {
        let sanitized = sanitizedMiniChatOperatingMode(
            EpistemosOperatingMode(rawValue: operatingModeRaw) ?? .fast
        )
        if sanitized.rawValue != operatingModeRaw {
            operatingModeRaw = sanitized.rawValue
        }
    }

    private func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> [T]? {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Log.pipeline.error(
                "MiniChatView: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> T? {
        fetchAll(descriptor, label: label)?.first
    }

    private var composerAttachmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(activeContextAttachments) { attachment in
                    HStack(spacing: 4) {
                        Image(systemName: attachment.systemImageName)
                            .font(.epSmall)
                        Text(attachment.title)
                            .font(.epSmall)
                            .lineLimit(1)
                        Button {
                            threadState.removeMiniChatContextAttachment(attachment.id, chatID: chatID)
                            persistMiniChatSession()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.epSmall)
                                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.mutedForeground.opacity(0.08), in: Capsule())
                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                QuickActionChip(icon: "tag", label: "Auto-tag", color: theme.resolved.accent.color) {
                    runQuickAction(.autoTag)
                }
                QuickActionChip(icon: "doc.text.magnifyingglass", label: "Summarize", color: .orange) {
                    runQuickAction(.summarize)
                }
                QuickActionChip(icon: "link", label: "Find Related", color: .purple) {
                    runQuickAction(.findRelated)
                }
                QuickActionChip(icon: "square.and.pencil", label: "Create From This", color: .green) {
                    runQuickAction(.createFromNote)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Active Page

    private func activePage() -> SDPage? {
        guard let pageId = explicitScopedPageID else { return nil }
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        return fetchFirst(descriptor, label: "active mini chat page \(pageId)")
    }

    // MARK: - Vault Search

    /// Search the vault for notes relevant to the query.
    /// Two-pass: title-only filter first (cheap), then body for a small subset.
    /// Avoids loading all externally-stored body blobs into memory.
    private func searchVault(query: String) -> [(title: String, snippet: String)] {
        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        guard let pages = fetchAll(descriptor, label: "mini chat vault search pages") else { return [] }
        return MiniChatVaultSearch.snippets(
            query: query,
            activeId: explicitScopedPageID,
            pages: pages.map { page in
                MiniChatSearchCandidate(
                    page: page,
                    snapshotStore: snapshotStore,
                    preferredBody: preferredBodySnapshot(for: page)
                )
            }
        )
    }

    private func preferredBodySnapshot(for page: SDPage) -> String? {
        if let liveEditor = NoteEditorViewFinder.findEditorTextView(for: page.id)?.string {
            return liveEditor
        }
        return nil
    }

    // MARK: - Quick Action Execution

    private enum QuickAction { case autoTag, summarize, findRelated, createFromNote }

    private func runQuickAction(_ action: QuickAction) {
        guard let page = activePage(), !isProcessing else { return }
        let snapshot = snapshotStore.snapshot(
            for: page,
            preferredBody: preferredBodySnapshot(for: page)
        )
        let pageTitle = snapshot.title
        let snippet = snapshot.promptSnippet

        let actionLabel: String
        let prompt: String

        switch action {
        case .autoTag:
            let existing = page.tags.joined(separator: ", ")
            actionLabel = "Auto-tag"
            prompt = """
            Suggest 3-5 short lowercase tags for this note.
            Return the first line as:
            tags: tag1, tag2, tag3

            Current tags: [\(existing.isEmpty ? "none" : existing)]

            # \(pageTitle)
            \(snippet)
            """
        case .summarize:
            actionLabel = "Summarize"
            prompt = """
            Summarize this note in 4-6 sentences. Capture the key ideas, arguments, and open questions.

            # \(pageTitle)
            \(snippet)
            """
        case .findRelated:
            let vault = searchVault(query: pageTitle)
            let searchResults = vault.isEmpty ? "" : "\n\n## Search Results\n" + vault.map { "- **\($0.title)**: \($0.snippet)" }.joined(separator: "\n")
            actionLabel = "Find Related"
            prompt = """
            Find connections between this note and these search results. Identify:
            1. directly related notes
            2. surprising connections
            3. gaps or missing follow-ups

            Be specific about what connects them.

            ## Current Note: \(pageTitle)
            \(snippet)\(searchResults)
            """
        case .createFromNote:
            actionLabel = "Create From Note"
            prompt = """
            Based on this note, suggest one follow-up note to write.
            Format:
            Title: [title]
            Outline:
            - point 1
            - point 2
            - point 3

            Then explain briefly why this note would be useful.

            # \(pageTitle)
            \(snippet)
            """
        }

        // Show action as user message
        threadState.addMiniChatMessage(
            AssistantMessage(role: .user, content: "✨ \(actionLabel): \(pageTitle)"),
            chatID: chatID
        )
        persistMiniChatSession()
        isProcessing = true
        threadState.setMiniChatStreaming(true, chatID: chatID)
        threadState.setMiniChatStreamingText("", chatID: chatID)
        threadState.clearMiniChatStreamingThinking(chatID: chatID)

        streamTask = Task {
            defer {
                isProcessing = false
                threadState.setMiniChatStreaming(false, chatID: chatID)
            }
            do {
                let contentLength = prompt.count
                var accumulated = ""

                for try await chunk in triage.streamGeneral(
                    prompt: prompt, systemPrompt: nil,
                    operation: .brainstorm,
                    contentLength: contentLength,
                    operatingMode: selectedOperatingMode,
                    localSurface: .miniChat,
                    reasoningSink: { delta in
                        threadState.appendMiniChatStreamingThinking(delta, chatID: chatID)
                    }
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    threadState.setMiniChatStreamingText(accumulated, chatID: chatID)
                }

                let final = UserFacingModelOutput.finalVisibleText(from: accumulated)
                let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)

                // Auto-apply certain actions
                if action == .autoTag {
                    applyAutoTags(from: final, page: page)
                } else if action == .summarize {
                    page.summary = String(final.prefix(500))
                    page.updatedAt = .now
                }

                threadState.addMiniChatMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: final.isEmpty ? "No response generated." : final,
                        thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace
                    ),
                    chatID: chatID
                )
                persistMiniChatSession()

            } catch is CancellationError {
                let partial = UserFacingModelOutput.finalVisibleText(
                    from: threadState.miniChatStreamingText(chatID: chatID)
                )
                let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)
                if !partial.isEmpty {
                    threadState.addMiniChatMessage(
                        AssistantMessage(
                            role: .assistant,
                            content: partial + "\n\n*[Cancelled]*",
                            thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace
                        ),
                        chatID: chatID
                    )
                    persistMiniChatSession()
                }
            } catch {
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)
                threadState.addMiniChatMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: UserFacingChatError.message(from: error)
                    ),
                    chatID: chatID
                )
                persistMiniChatSession()
            }
        }
    }

    /// Parse "tags: foo, bar, baz" from AI response and apply to page
    private func applyAutoTags(from response: String, page: SDPage) {
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.hasPrefix("tags:") || lower.hasPrefix("**tags:**") || lower.hasPrefix("- tags:") {
                let raw = line
                    .replacingOccurrences(of: "**tags:**", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "tags:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "- ", with: "")
                let tags = raw.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty && $0.count < 30 }

                let newTags = tags.filter { !page.tags.contains($0) }
                if !newTags.isEmpty {
                    page.tags.append(contentsOf: newTags)
                    page.updatedAt = .now
                }
                return
            }
        }
    }

    // MARK: - Send with Streaming + Action Detection

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        threadState.addMiniChatMessage(AssistantMessage(role: .user, content: trimmed), chatID: chatID)
        refreshMiniChatLabel(using: trimmed)
        persistMiniChatSession()
        text = ""
        composerHeight = ChatComposerInputMetrics.minHeight
        isProcessing = true
        threadState.setMiniChatStreaming(true, chatID: chatID)
        threadState.setMiniChatStreamingText("", chatID: chatID)
        threadState.clearMiniChatStreamingThinking(chatID: chatID)

        streamTask = Task {
            defer {
                isProcessing = false
                threadState.setMiniChatStreaming(false, chatID: chatID)
            }
            do {
                let page = activePage()
                let currentThread = threadState.miniChatSession(id: chatID)
                let attachments = currentThread?.contextAttachments ?? []

                let notesContext: ChatCoordinator.AttachedContextResolution
                if ChatCoordinator.queryContainsExplicitNoteContext(trimmed) || !attachments.isEmpty {
                    notesContext = await ChatCoordinator.resolveAttachedContext(
                        query: trimmed,
                        attachments: attachments,
                        manifest: ambientManifest,
                        includeAllNotesContext: false,
                        findNotesByTitle: { title in
                            await vaultSync.findNotesByTitle(title)
                        },
                        fetchNoteBodies: { ids in
                            await vaultSync.fetchNoteBodies(ids: ids)
                        },
                        searchNoteIDs: { query in
                            await vaultSync.searchIndex(query: query)
                        },
                        fetchChatMessages: { [self] chatID in
                            await MainActor.run {
                                if let thread = threadState.chatThreads.first(where: { $0.id == chatID }) {
                                    return thread.messages
                                }
                                let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatID })
                                guard let chat = fetchFirst(
                                    descriptor,
                                    label: "mini chat attached chat \(chatID)"
                                ) else { return [] }
                                return chat.sortedMessages.map { message in
                                    AssistantMessage(
                                        role: message.role == "user" ? .user : .assistant,
                                        content: message.content,
                                        createdAt: message.createdAt
                                    )
                                }
                            }
                        }
                    )
                } else {
                    notesContext = .init(
                        context: nil,
                        cleanedQuery: trimmed,
                        loadedNoteIds: [],
                        loadedNoteTitles: []
                    )
                }
                threadState.updateMiniChatLoadedNotes(
                    ids: notesContext.loadedNoteIds,
                    titles: notesContext.loadedNoteTitles,
                    chatID: chatID
                )

                // Build conversation-aware prompt from thread history
                let allMessages = threadState.miniChatSession(id: chatID)?.messages ?? []

                var promptParts: [String] = []
                if let context = notesContext.context {
                    promptParts.append(context)
                }
                if allMessages.count > 1 {
                    let history = allMessages.dropLast().suffix(10)
                    let historyText = history.map { msg in
                        msg.role == .user ? "User: \(msg.content)" : "Assistant: \(msg.content)"
                    }.joined(separator: "\n\n")
                    promptParts.append(historyText)
                    promptParts.append("User: \(notesContext.cleanedQuery)")
                } else {
                    promptParts.append(notesContext.cleanedQuery)
                }
                let conversationPrompt = promptParts.joined(separator: "\n\n")

                let contentLength = conversationPrompt.count
                var accumulated = ""

                for try await chunk in triage.streamGeneral(
                    prompt: conversationPrompt,
                    systemPrompt: nil,
                    operation: .chatResponse(query: trimmed),
                    contentLength: contentLength,
                    operatingMode: selectedOperatingMode,
                    localSurface: .miniChat,
                    reasoningSink: { delta in
                        threadState.appendMiniChatStreamingThinking(delta, chatID: chatID)
                    }
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    threadState.setMiniChatStreamingText(accumulated, chatID: chatID)
                }

                var final = UserFacingModelOutput.finalVisibleText(from: accumulated)
                let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)

                // Parse and execute any action markers
                if let page {
                    final = executeActions(in: final, page: page)
                }

                threadState.addMiniChatMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: final.isEmpty ? "No response generated." : final,
                        thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace,
                        loadedNoteTitles: notesContext.loadedNoteTitles,
                        contextAttachments: attachments
                    ),
                    chatID: chatID
                )
                persistMiniChatSession()

            } catch is CancellationError {
                let partial = UserFacingModelOutput.finalVisibleText(
                    from: threadState.miniChatStreamingText(chatID: chatID)
                )
                let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)
                if !partial.isEmpty {
                    threadState.addMiniChatMessage(
                        AssistantMessage(
                            role: .assistant,
                            content: partial + "\n\n*[Cancelled]*",
                            thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace
                        ),
                        chatID: chatID
                    )
                    persistMiniChatSession()
                }
            } catch {
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)
                threadState.addMiniChatMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: UserFacingChatError.message(from: error)
                    ),
                    chatID: chatID
                )
                persistMiniChatSession()
            }
        }
    }

    // MARK: - Action Parsing & Execution

    /// Parse [ACTION:...] markers from AI response, execute them, and return cleaned text.
    private func executeActions(in response: String, page: SDPage) -> String {
        var cleaned = response
        var executedActions: [String] = []

        // TAG action: [ACTION:TAG tag1, tag2, tag3]
        if let range = response.range(of: #"\[ACTION:TAG\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let tagsRaw = marker
                .replacingOccurrences(of: "[ACTION:TAG ", with: "")
                .replacingOccurrences(of: "]", with: "")
            let tags = tagsRaw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 30 }
            let newTags = tags.filter { !page.tags.contains($0) }
            if !newTags.isEmpty {
                page.tags.append(contentsOf: newTags)
                page.updatedAt = .now
                executedActions.append("✅ Added tags: \(newTags.joined(separator: ", "))")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // MOVE action: [ACTION:MOVE FolderName]
        if let range = response.range(of: #"\[ACTION:MOVE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let folderName = marker
                .replacingOccurrences(of: "[ACTION:MOVE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            let folderDescriptor = FetchDescriptor<SDFolder>()
            if let folders = fetchAll(folderDescriptor, label: "mini chat move folders"),
               let folder = folders.first(where: { $0.name.lowercased() == folderName.lowercased() }) {
                page.folder = folder
                page.updatedAt = .now
                executedActions.append("✅ Moved to folder: \(folder.name)")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // CREATE action: [ACTION:CREATE Title of New Note]
        if let range = response.range(of: #"\[ACTION:CREATE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let title = marker
                .replacingOccurrences(of: "[ACTION:CREATE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                Task {
                    if let newId = await vaultSync.createPage(title: title) {
                        executedActions.append("✅ Created note: \(title)")
                        NoteWindowManager.shared.open(pageId: newId)
                    }
                }
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // Append action confirmations
        if !executedActions.isEmpty {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned += "\n\n---\n" + executedActions.joined(separator: "\n")
        }

        return cleaned
    }

    private func attachMentionReference(_ choice: ComposerReferenceChoice) {
        threadState.addMiniChatContextAttachment(
            ComposerReferenceHelpers.contextAttachment(for: choice),
            chatID: chatID
        )
        persistMiniChatSession()
        text = ComposerReferenceHelpers.removingTrailingMention(from: text)
        showMentionDropdown = false
        referencePopoverStyle = .mention
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func dismissReferencePopover() {
        showMentionDropdown = false
        mentionPickerAutofocus = false
    }

    private func updateMentionReferenceSearch(filter: String) {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            referenceSearch.reset()
            return
        }
        referenceSearch.update(
            filter: trimmed,
            manifest: ambientManifest,
            vaultSync: vaultSync
        )
    }

    private func recentChats() -> [SDChat] {
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = 20
        return fetchAll(descriptor, label: "recent mini chats") ?? []
    }

    private func refreshMiniChatLabel(using prompt: String) {
        guard let index = threadState.chatThreads.firstIndex(where: { $0.id == chatID })
        else { return }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let compact = trimmed.replacingOccurrences(of: "\n", with: " ")
        threadState.chatThreads[index].label = String(compact.prefix(36))
        MiniChatWindowController.shared.updateWindowTitle(chatID: chatID, title: threadState.chatThreads[index].label)
    }

    private func persistMiniChatSession() {
        guard let thread = threadState.miniChatSession(id: chatID) else { return }

        let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatID })
        let chat: SDChat
        let existing = fetchFirst(descriptor, label: "persisted mini chat session \(chatID)")
        let wasExisting = existing != nil
        if let existing {
            chat = existing
        } else {
            let created = SDChat(title: thread.label, chatType: thread.pageId == nil ? "chat" : "notes")
            created.id = chatID
            modelContext.insert(created)
            chat = created
        }

        let originalTitle = chat.title
        let originalChatType = chat.chatType
        let originalLinkedPageId = chat.linkedPageId
        let originalUpdatedAt = chat.updatedAt
        let originalMessages = chat.messages ?? []

        chat.title = thread.label
        chat.chatType = thread.pageId == nil ? "chat" : "notes"
        chat.linkedPageId = thread.pageId
        chat.updatedAt = thread.messages.last?.createdAt ?? .now

        for message in chat.messages ?? [] {
            modelContext.delete(message)
        }

        let newMessages = thread.messages.map { message in
            let stored = SDMessage(role: message.role.rawValue, content: message.content)
            stored.id = message.id
            stored.createdAt = message.createdAt
            stored.thinkingTrace = message.thinkingTrace
            stored.thinkingDurationSeconds = message.thinkingDurationSeconds
            stored.updatePresentationSnapshot(
                attachments: [],
                loadedNoteTitles: message.loadedNoteTitles,
                contextAttachments: message.contextAttachments
            )
            stored.chat = chat
            return stored
        }
        chat.messages = newMessages

        do {
            try modelContext.save()
            MiniChatWindowController.shared.updateWindowTitle(chatID: chatID, title: thread.label)
        } catch {
            chat.title = originalTitle
            chat.chatType = originalChatType
            chat.linkedPageId = originalLinkedPageId
            chat.updatedAt = originalUpdatedAt

            for message in newMessages {
                modelContext.delete(message)
            }

            if wasExisting {
                for message in originalMessages {
                    modelContext.insert(message)
                    message.chat = chat
                }
                chat.messages = originalMessages
                MiniChatWindowController.shared.updateWindowTitle(chatID: chatID, title: originalTitle)
            } else {
                modelContext.delete(chat)
            }
            Log.pipeline.error("Failed to persist mini chat session \(self.chatID): \(error.localizedDescription)")
        }
    }

    private func cancelStream() {
        let partial = UserFacingModelOutput.finalVisibleText(
            from: threadState.miniChatStreamingText(chatID: chatID)
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        isProcessing = false
        threadState.setMiniChatStreaming(false, chatID: chatID)
        threadState.setMiniChatStreamingText("", chatID: chatID)
        threadState.clearMiniChatStreamingThinking(chatID: chatID)
        streamTask?.cancel()
        streamTask = nil
        if !partial.isEmpty {
            threadState.addMiniChatMessage(
                AssistantMessage(
                    role: .assistant,
                    content: partial,
                    thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace
                ),
                chatID: chatID
            )
            persistMiniChatSession()
        }
    }
}

// MARK: - Quick Action Chip

private struct QuickActionChip: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? color : theme.mutedForeground.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
