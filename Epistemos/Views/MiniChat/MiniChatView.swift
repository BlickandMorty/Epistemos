import AppKit
#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
import OsaurusCore
#endif
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum MiniChatLayout {
    static let messageColumnMaxWidth: CGFloat = 560
    static let composerMaxWidth: CGFloat = 620
    static let userBubbleMaxWidth: CGFloat = 360
    static let toolbarHeight: CGFloat = 36
}

enum MiniChatOperatingModePreference {
    static let defaultsKey = "epistemos.miniChatOperatingMode"

    static func setPreferredMode(_ mode: EpistemosOperatingMode?) {
        guard let mode else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
    }

    static func preferredMode() -> EpistemosOperatingMode? {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return nil }
        return EpistemosOperatingMode(rawValue: raw)
    }
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
        miniChatLegacyBody
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { @MainActor in
                loadMiniChatSessionIfNeeded()
            }
        }
    }

    private var miniChatLegacyBody: some View {
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
        .padding(.top, 36)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Frosted-glass stack per user 2026-05-12: keep a real blur
            // layer (ultraThinMaterial = the lightest macOS blur) but
            // overlay a colored tint so the glass reads as a frost color,
            // not just a window-content blur. The tint reduces the
            // visible "blurriness" by hiding more of the background while
            // the blur itself still softens edges underneath. White frost
            // in light mode (0.55 opacity), darker frost in dark mode
            // (0.32 opacity — dark frost reads heavier so it can sit at
            // lower opacity and still feel anchored).
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            theme.isDark
                                ? Color.black.opacity(0.32)
                                : Color.white.opacity(0.55)
                        )
                )
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

            Button(action: openCurrentChatInMain) {
                Label("Open in Main Chat", systemImage: "arrow.down.left.square")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Open this chat in Main Chat")

            Button(action: { showRecentChats = true }) {
                Label("Recent Chats", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Recent Chats")

            Button(action: { MiniChatWindowController.shared.openNewChat(preferredOperatingMode: .agent) }) {
                Label("Add Chat", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Add Chat")
            // SS-CLEAN dedup (2026-06-21): the mini-chat tool panel lives in the composer
            // (MiniChatInputBar.toolPanelButton — the canonical P7.5 capability explorer WITH skill-run,
            // main-chat parity). An earlier SS-VIS-sweep addition here duplicated it as an inferior
            // header button (no skill-run); removed so mini-chat shows ONE tool panel, not two.
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
                    let restoredMessage = message.chatMessage(chatId: chat.id)
                    return AssistantMessage(
                        id: restoredMessage.id,
                        role: restoredMessage.role,
                        content: restoredMessage.content,
                        contentBlocks: restoredMessage.contentBlocks,
                        authoredByProviderID: restoredMessage.authoredByProviderID,
                        authoredByModelID: restoredMessage.authoredByModelID,
                        thinkingTrace: restoredMessage.thinkingTrace,
                        thinkingDurationSeconds: restoredMessage.thinkingDurationSeconds,
                        loadedNoteTitles: restoredMessage.loadedNoteTitles,
                        contextAttachments: restoredMessage.contextAttachments,
                        createdAt: restoredMessage.createdAt
                    )
                }
            )
            MiniChatWindowController.shared.updateWindowTitle(chatID: chat.id, title: chat.title)
            applyInitialContextAttachmentIfNeeded()
            return
        }
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        if loadActOsaurusTranscriptIfAvailable() {
            applyInitialContextAttachmentIfNeeded()
            return
        }
        #endif
        threadState.ensureMiniChatSession(id: chatID)
        applyInitialContextAttachmentIfNeeded()
    }

    #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
    @discardableResult
    private func loadActOsaurusTranscriptIfAvailable() -> Bool {
        guard let sessionId = UUID(uuidString: chatID),
              let transcript = EpistemosOsaurusSessionBridge.loadTranscript(id: sessionId)
        else { return false }

        let messages = transcript.messages.compactMap { message -> AssistantMessage? in
            switch message.role {
            case .user:
                return AssistantMessage(
                    id: message.id.uuidString,
                    role: .user,
                    content: message.content,
                    createdAt: message.createdAt ?? .now
                )
            case .assistant:
                return AssistantMessage(
                    id: message.id.uuidString,
                    role: .assistant,
                    content: ActOsaurusVisibleStreamFilter.visibleStoredText(from: message.content),
                    authoredByProviderID: "act",
                    authoredByModelID: transcript.selectedModel,
                    thinkingTrace: message.thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : message.thinking,
                    thinkingDurationSeconds: message.thinkingDuration,
                    createdAt: message.createdAt ?? message.completedAt ?? .now
                )
            case .tool, .system:
                return nil
            }
        }

        let label = transcript.title.trimmingCharacters(in: .whitespacesAndNewlines)
        threadState.upsertMiniChatSession(
            id: transcript.id.uuidString,
            label: label.isEmpty ? "Act" : label,
            pageId: nil,
            messages: messages
        )
        MiniChatWindowController.shared.updateWindowTitle(
            chatID: transcript.id.uuidString,
            title: label.isEmpty ? "Act" : label
        )
        return true
    }

    #endif

    private func applyInitialContextAttachmentIfNeeded() {
        guard !appliedInitialContextAttachment, let initialContextAttachment else { return }
        appliedInitialContextAttachment = true
        let existingAttachments = threadState.miniChatSession(id: chatID)?.contextAttachments ?? []
        guard !existingAttachments.contains(initialContextAttachment) else { return }
        threadState.addMiniChatContextAttachment(initialContextAttachment, chatID: chatID)
    }

    private func openCurrentChatInMain() {
        if persistedMiniChatExists(chatID) {
            AppBootstrap.shared?.loadChat(chatId: chatID)
            HomeWindowIdentity.surfaceHomeWindow()
            return
        }

        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        if let sessionId = UUID(uuidString: chatID),
           EpistemosOsaurusSessionBridge.loadTranscript(id: sessionId) != nil {
            NotificationCenter.default.post(name: .openActOsaurusSession, object: sessionId)
            HomeWindowIdentity.surfaceHomeWindow()
            return
        }
        #endif
        AppBootstrap.shared?.loadChat(chatId: chatID)
        HomeWindowIdentity.surfaceHomeWindow()
    }

    private func persistedMiniChatExists(_ chatID: String) -> Bool {
        let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatID })
        do {
            return try modelContext.fetch(descriptor).first != nil
        } catch {
            Log.pipeline.error(
                "MiniChatView: failed to check persisted mini chat \(chatID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}

// MARK: - Thread View

private struct MiniChatThread: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                                    let pendingToolBlocks = threadState.miniChatPendingContentBlocks(chatID: chatID)
                                    let activeToolName = threadState.miniChatActiveToolName(chatID: chatID)
                                    let activeToolInputJson = threadState.miniChatActiveToolInputJson(chatID: chatID)
                                    MiniChatAssistantBubbleChrome {
                                        VStack(alignment: .leading, spacing: Spacing.md) {
                                            LiveActivityStrip(
                                                toolName: activeToolName,
                                                toolInputJson: activeToolInputJson,
                                                isThinkingActive: visibleStreamingText.isEmpty && !streamingThinking.isEmpty,
                                                thinkingStartedAt: nil,
                                                isStreaming: true
                                            )

                                            if !pendingToolBlocks.isEmpty {
                                                ToolExecutionPreviewList(
                                                    blocks: pendingToolBlocks,
                                                    isStreaming: true
                                                )
                                            }

                                            if !visibleStreamingText.isEmpty {
                                                TaggedMarkdownTextView(
                                                    content: visibleStreamingText + " ▍",
                                                    theme: theme
                                                )
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
                    .onChange(of: miniChatThread?.messages.count) { _, _ in
                        guard autoFollow.isFollowingBottom else { return }
                        autoFollow.markProgrammaticScrollToBottom()
                        withAnimation(reduceMotion ? nil : Motion.quick) {
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
    private var persistedThinking: String? {
        if let trace = message.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trace.isEmpty {
            return trace
        }
        return message.contentBlocks?.thinkingContent
    }

    var body: some View {
        let displayContent = message.role == .assistant
            ? UserFacingModelOutput.finalVisibleText(from: message.content)
            : message.content
        if isUser {
            TaggedMarkdownTextView(
                content: displayContent,
                theme: theme,
                rippleStyle: .none,
                foregroundOverride: theme.userBubbleText,
                typographyRole: .user
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: MiniChatLayout.userBubbleMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            MiniChatAssistantBubbleChrome {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let contentBlocks = message.contentBlocks {
                        ToolExecutionPreviewList(blocks: contentBlocks)
                    }

                    TaggedMarkdownTextView(content: displayContent, theme: theme)

                    if let thinkingTrace = persistedThinking,
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
    @Environment(AgentCommandCenterState.self) private var agentCommandCenter
    @Environment(MCPBridge.self) private var mcpBridge
    @Environment(ContextualShadowsState.self) private var contextualShadows
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @AppStorage(MiniChatOperatingModePreference.defaultsKey)
    private var operatingModeRaw = EpistemosOperatingMode.fast.rawValue
    /// Owner 2026-06-18: mini chat's model picker is a flat inline pixel-art
    /// panel expanding in-flow above the composer controls — not a popover.
    @State private var showInlineRuntimePicker = false
    @State private var text = ""
    @State private var isProcessing = false
    @State private var isUsingSharedCoordinator = false
    @State private var streamTask: Task<Void, Never>?
    @State private var isFocused = false
    @State private var composerHeight = ChatComposerInputMetrics.minHeight

    // @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""
    @State private var mentionKeyboardIndex = 0
    @State private var mentionPickerAutofocus = false
    @State private var referencePopoverStyle: ComposerReferencePopoverStyle = .mention
    @State private var referenceSearch = ComposerReferenceSearchState()
    @State private var snapshotStore = MiniChatSnapshotStore()
    @State private var recallDebounceBox = ChatRecallDebounceBox()
    @State private var pendingFileAttachments: [FileAttachment] = []
    @State private var showPermissionGrantPopover = false
    @State private var showSlashMenu = false
    /// P7.5 — in-chat tool/skill capability panel parity with Main chat (P2.1/P2.4).
    @State private var showToolPanel = false
    @State private var slashFilter = ""
    @State private var slashKeyboardIndex = 0
    @State private var selectedSlashItem: ComposerSlashCommandItem?

    let chatID: String

    private static let sharedCoordinatorTurnTimeoutSeconds = 90.0

    private var theme: EpistemosTheme { ui.theme }
    private var composerAccentColor: Color { theme.resolved.accent.color }
    private let composerMetrics = AssistantComposerMetrics.mainChat
    private var placeholderText: String {
        isOsaurusActMode
            ? "Ask Act… Type / for commands, tools, models, or agents."
            : ComposerAttachmentEntryHints.mainChatPlaceholder
    }
    /// Owner 2026-06-18 (mini-chat parity): mini must offer the SAME operating
    /// modes as MAIN chat — Fast/Think/Code plus Act when an agent route exists —
    /// not the narrower per-model BASE set. Previously this used
    /// `availableOperatingModes(for: preferredChatModelSelection)` (base caps
    /// only), so `sanitizedMiniChatOperatingMode` would REVERT Act even when the
    /// inline panel offered it (the panel checks the broad set). Reuse the shared
    /// main-chat source so the two surfaces can never drift; honest gating is
    /// already baked into `availableOperatingModes` (Act only with a real route).
    private var supportedOperatingModes: [EpistemosOperatingMode] {
        var modes = MainChatOperatingModePreference.supportedModes(for: inference)
        if LocalAgentLoop.shouldRouteActThroughOsaurus(), !modes.contains(.agent) {
            modes.append(.agent)
        }
        return modes
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
        isProcessing
            || (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && selectedRuntimeReady
                && localRuntimeMemoryBlocker == nil)
    }

    private var selectedRuntimeReady: Bool {
        if isOsaurusActMode { return true }
        return inference.isChatSurfaceRuntimeReady(for: selectedOperatingMode)
    }

    private var isOsaurusActMode: Bool {
        selectedOperatingMode == .agent && LocalAgentLoop.shouldRouteActThroughOsaurus()
    }

    /// P7.5 — chat-surface parity: MiniChat reuses the same honest local-runtime
    /// memory blocker as the Main chat (P1.4). Shared logic on `InferenceState`,
    /// so this is parity, not a fork — Send disables + a banner shows when the
    /// selected local model can't load, never a silent route to another model.
    private var localRuntimeMemoryBlocker: String? {
        if isOsaurusActMode { return nil }
        return inference.localChatModelMemoryBlocker(for: selectedOperatingMode)
    }

    /// P7.5 — Fast effort visibility parity with Main chat (P1.9).
    private var fastEffortHint: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let complexity = QueryAnalyzer.analyze(query: trimmed).complexity
        return inference.fastEffortRouteReason(
            forComplexity: complexity,
            operatingMode: selectedOperatingMode
        )
    }

    private var composerIsActive: Bool {
        isFocused
            || canSend
            || isProcessing
            || !activeContextAttachments.isEmpty
            || !pendingFileAttachments.isEmpty
            || selectedSlashItem != nil
    }
    private var composerStatusPhase: AssistantComposerStatusPhase {
        AssistantComposerStatusPhase.resolve(
            isActive: isProcessing || threadState.miniChatIsStreaming(chatID: chatID),
            streamingText: threadState.miniChatStreamingText(chatID: chatID)
        )
    }
    private var composerStatusLabelState: AssistantComposerStatusLabelState? {
        AssistantComposerStatusLabelState.resolve(
            inputText: text,
            phase: composerStatusPhase,
            idleText: placeholderText,
            showsIdleLabel: false,
            analyzingText: "Loading \(inference.activeChatModelDisplayName)…"
        )
    }
    private var composerTextAreaHeight: CGFloat {
        max(ChatComposerInputMetrics.minHeight, composerHeight)
    }

    private var contextualRecallScopeID: String {
        "mini-chat:\(chatID)"
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

    private var mentionKeyboardChoices: [ComposerReferenceChoice] {
        ComposerReferenceKeyboardSelection.choices(
            from: mentionSearchResults,
            style: referencePopoverStyle
        )
    }

    private var supportedSlashCommands: [ACCSlashCommand] {
        ACCSlashCommand.availableCommands(for: supportedOperatingModes)
    }

    private var supportedSlashItems: [ComposerSlashCommandItem] {
        if isOsaurusActMode {
            return ActOsaurusSlashCommand.allCases.map(ComposerSlashCommandItem.osaurus)
                + agentCommandCenter.availableSkills.map(ComposerSlashCommandItem.skill)
        }
        return ComposerSlashCommandItem.all(
            commands: supportedSlashCommands,
            skills: agentCommandCenter.availableSkills
        )
    }

    private var filteredSlashItems: [ComposerSlashCommandItem] {
        SlashCommandPopover.filteredItems(
            items: supportedSlashItems,
            filter: slashFilter
        )
    }

    private var highlightedSlashItem: ComposerSlashCommandItem? {
        guard !filteredSlashItems.isEmpty else { return nil }
        return filteredSlashItems[clamped(slashKeyboardIndex, count: filteredSlashItems.count)]
    }

    private var activeSelectedSlashItem: ComposerSlashCommandItem? {
        if let selectedSlashItem,
           supportedSlashItems.contains(selectedSlashItem) {
            return selectedSlashItem
        }

        let result = CommandInputParser.parse(
            text,
            availableSkills: agentCommandCenter.availableSkills,
            availableSlashCommands: supportedSlashCommands
        )
        guard let token = result.slashToken else {
            return nil
        }
        let item = ComposerSlashCommandItem(token: token)
        return supportedSlashItems.contains(item) ? item : nil
    }

    private var activeSelectedSlashToken: ParsedSlashToken? {
        activeSelectedSlashItem?.token
    }

    private var showsToolPanelButton: Bool {
        true
    }

    private var enabledAppToolNames: Set<String> {
        Set(agentCommandCenter.enabledToolNames.map(AgentToolNameAliases.canonical))
    }

    private var hasEnabledAppTools: Bool {
        !enabledAppToolNames.isEmpty
    }

    private var managedToolRuntimeVaultPath: String {
        FoundationSafety.managedToolRuntimeVaultDirectory(
            preferredVaultPath: vaultSync.vaultURL?.path
        ).path
    }

    private func refreshExecutionCatalogsIfNeeded(force: Bool = false) {
        agentCommandCenter.refreshExecutionCatalogsIfNeeded(
            from: mcpBridge,
            vaultPath: managedToolRuntimeVaultPath,
            force: force
        )
    }

    private var currentAccessPlan: ComposerCurrentAccessPlan {
        ComposerCurrentAccessPlan(
            vaultURL: vaultSync.vaultURL,
            contextAttachments: activeContextAttachments,
            fileAttachments: pendingFileAttachments,
            compiledAllowedToolNames: Array(enabledAppToolNames).sorted()
        )
    }

    private var permissionGrantRows: [ComposerResourceGrantRow] {
        currentAccessPlan.rows
    }

    private var permissionSummaryText: String {
        currentAccessPlan.summaryText
    }

    private var composerControlResetKey: String {
        supportedOperatingModes.map(\.rawValue).joined(separator: "|")
            + "::"
            + inference.activeChatModelDisplayName
            + "::"
            + (selectedSlashItem?.id ?? "none")
    }

    private var isCloudProviderSelection: Bool {
        switch inference.effectiveChatSurfaceSelection(for: selectedOperatingMode) {
        case .cloud:
            return true
        case .localMLX, .appleIntelligence:
            return false
        }
    }

    private var draftCapabilityPrediction: IntentPrediction {
        ChatCapability.predictIntent(
            text: text,
            isCloudProvider: isCloudProviderSelection
        )
    }

    private var composerCapability: ChatCapability {
        let toolsModeSelected = selectedOperatingMode == .agent
        return ChatCapability.classify(
            isCloudProvider: isCloudProviderSelection,
            isAgentExecuting: toolsModeSelected || isUsingSharedCoordinator || draftCapabilityPrediction.predicted == .agent,
            isResearchMode: draftCapabilityPrediction.predicted == .research,
            isThinkingMode: selectedOperatingMode == .thinking
        )
    }

    private var composerPillDetail: String? {
        if let activeTool = threadState.miniChatActiveToolName(chatID: chatID),
           !activeTool.isEmpty {
            return ToolActivityNarrator.phrase(
                name: activeTool,
                inputJson: threadState.miniChatActiveToolInputJson(chatID: chatID)
            )
        }

        if hasEnabledAppTools {
            return "\(enabledAppToolNames.count) app tools"
        }

        return ComposerModelToolTruth.detail(
            for: inference.effectiveChatSurfaceSelection(for: selectedOperatingMode),
            capability: composerCapability
        )
    }

    private var cloudSurfaceSupportsAgentTier: Bool {
        guard case .cloud(let model) = inference.effectiveChatSurfaceSelection(for: selectedOperatingMode) else {
            return false
        }
        return model.provider.supportsAgentTier
    }

    private var needsSharedToolRouteWarning: Bool {
        guard !isProcessing, !isUsingSharedCoordinator else { return false }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard isCloudProviderSelection, !cloudSurfaceSupportsAgentTier else { return false }
        return draftCapabilityPrediction.predicted == .agent
            || draftCapabilityPrediction.predicted == .research
    }

    var body: some View {
        VStack(spacing: 8) {
            if explicitScopedPageID != nil, activePage() != nil, !isProcessing {
                quickActions
            }

            if !activeContextAttachments.isEmpty || !pendingFileAttachments.isEmpty {
                composerAttachmentChips
            }

            if pendingFileAttachments.contains(where: { $0.type == .image }),
               !inference.chatSurfaceSupportsVision(for: selectedOperatingMode) {
                imageAttachmentWarning
            }

            permissionVisibilityChip
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 0) {
                composerTextArea
                    .onChange(of: text) { _, newValue in
                        refreshSlashMenu(for: newValue)
                    }
                    .popover(isPresented: $showSlashMenu, arrowEdge: .top) {
                        SlashCommandPopover(
                            items: supportedSlashItems,
                            filter: slashFilter,
                            selectedItem: highlightedSlashItem,
                            onSelect: { item in
                                applySlashItem(item)
                            }
                        )
                    }

                // P7.5 — honest memory blocker (P1.4 parity). Disables Send +
                // explains, never a silent swap.
                if let memoryBlocker = localRuntimeMemoryBlocker {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(memoryBlocker)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if let fastEffortHint {
                    // P7.5 — Fast effort visibility (P1.9 parity).
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(fastEffortHint)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                }

                if needsSharedToolRouteWarning {
                    sharedToolRouteWarningBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Owner 2026-06-18: flat inline pixel-art model picker in-flow,
                // replacing the single-button LocalModelToolbarMenu popover.
                if showInlineRuntimePicker {
                        InlineRuntimePickerPanel(
                            inference: inference,
                            operatingMode: operatingModeBinding,
                            onPicked: {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    showInlineRuntimePicker = false
                                }
                            },
                            onOpenSettings: { openSettings() },
                            showsSettingsFooter: true,
                            showsOsaurusModelSection: isOsaurusActMode
                        )
                    .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(alignment: .center, spacing: MainChatComposerLayout.controlRowSpacing) {
                    ComposerControlStrip(spacing: 8, resetKey: composerControlResetKey) {
                        inlineRuntimePickerTrigger
                        if !supportedSlashItems.isEmpty {
                            slashButton
                        }
                        if let activeSelectedSlashItem {
                            selectedSlashPill(for: activeSelectedSlashItem)
                        }
                        attachButton
                        if showsToolPanelButton {
                            toolPanelButton
                        }
                    }

                    Spacer(minLength: 4)

                    ChatCapabilityPill(
                        capability: composerCapability,
                        detail: composerPillDetail
                    )

                    ContextualShadowsButton(scopeKind: .chat, scopeID: contextualRecallScopeID)

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
        }
        .frame(maxWidth: MiniChatLayout.composerMaxWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            agentCommandCenter.refreshSkillCatalog()
            sanitizeStoredOperatingMode()
        }
        .onDisappear {
            recallDebounceBox.task?.cancel()
            cancelStream()
        }
        .onChange(of: inference.supportsThinkingOperatingMode) { _, _ in
            sanitizeStoredOperatingMode()
        }
        .onChange(of: inference.preferredChatModelSelection.rawValue) { _, _ in
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
        .overlay(alignment: .bottomTrailing) {
            ContextualShadowsPanel(
                scopeKind: .chat,
                scopeID: contextualRecallScopeID,
                presentation: .chat,
                onOpen: openContextualShadowHit
            )
            .padding(.trailing, 12)
            .padding(.bottom, 50)
        }
    }

    private var sharedToolRouteWarningBanner: some View {
        Button {
            inference.setActiveAIProvider(.openAI)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cloud.bolt.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.orange)
                Text("This needs tools. Tap to switch to OpenAI before sending from Mini Chat.")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.72))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.orange.opacity(theme.isDark ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(theme.isDark ? 0.30 : 0.24), lineWidth: 0.75)
        )
        .padding(.top, 6)
        .accessibilityLabel(
            "Switch to OpenAI before sending from Mini Chat. This prompt needs tools but the selected cloud model does not support the tool tier."
        )
        .accessibilityAddTraits(.isButton)
    }

    private var composerTextArea: some View {
        ChatComposerTextEditor(
            text: $text,
            height: $composerHeight,
            isFocused: $isFocused,
            theme: theme,
            isProcessing: isProcessing,
            onCommand: { selector, modifierFlags in
                handleComposerCommand(selector, modifierFlags: modifierFlags)
            }
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
                    phase: composerStatusPhase,
                    theme: theme,
                    font: .system(size: 16, weight: .regular, design: .rounded),
                    activeFont: .custom(AppDisplayTypography.displayFontName, size: 12)
                )
                .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                .padding(.leading, ChatComposerInputMetrics.horizontalInset)
            }
        }
        .overlay(alignment: .topLeading) {
            if text.isEmpty && composerStatusLabelState == nil {
                Text(placeholderText)
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
            scheduleContextualShadowsRecall(for: newVal)
            if let filter = ComposerReferenceHelpers.mentionFilter(in: newVal) {
                referencePopoverStyle = .mention
                mentionFilter = filter
                mentionKeyboardIndex = 0
                mentionPickerAutofocus = false
                if !showMentionDropdown { showMentionDropdown = true }
            } else if showMentionDropdown {
                showMentionDropdown = false
                referencePopoverStyle = .mention
                mentionKeyboardIndex = 0
                mentionPickerAutofocus = false
                referenceSearch.reset()
            }
        }
        .onChange(of: mentionFilter) { _, newValue in
            updateMentionReferenceSearch(filter: newValue)
        }
    }

    private func scheduleContextualShadowsRecall(for snapshotText: String) {
        // SS-IR (owner 2026-06-20): recall is scoped to the EDITORS (Epdoc + TK2), NOT mini-chat.
        // Stop feeding Surface B here — cancel any pending query + clear the mini-chat-scope payload
        // so no recall chrome appears. The recall brain stays; only this surface stops feeding it.
        recallDebounceBox.task?.cancel()
        contextualShadows.closePanel(kind: .chat, originDocId: contextualRecallScopeID)
    }

    private func openContextualShadowHit(_ hit: ContextualShadowsState.RecallHit) {
        switch hit.kind {
        case .note:
            NoteWindowManager.shared.open(pageId: hit.id)
        case .chat:
            MiniChatWindowController.shared.openChat(hit.id)
        }
        contextualShadows.closePanel(kind: .chat, originDocId: contextualRecallScopeID)
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

                ForEach(pendingFileAttachments) { attachment in
                    let isSupported = inference.chatSurfaceSupportedFileTypes(
                        for: selectedOperatingMode
                    ).contains(attachment.type)
                    HStack(spacing: 4) {
                        if !isSupported {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                        Image(systemName: iconForType(attachment.type))
                            .font(.epSmall)
                        Text(attachment.name)
                            .font(.epSmall)
                            .lineLimit(1)
                        Button {
                            removePendingFileAttachment(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.epSmall)
                                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (isSupported ? theme.mutedForeground.opacity(0.08) : Color.orange.opacity(0.1)),
                        in: Capsule()
                    )
                    .foregroundStyle(isSupported ? theme.mutedForeground.opacity(0.7) : .orange)
                    .help(isSupported ? attachment.name : "Current model doesn't support \(attachment.type.rawValue) files")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var imageAttachmentWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text("Current model doesn't support images. Switch to a vision-capable model to use image attachments.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: MiniChatLayout.composerMaxWidth, alignment: .leading)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var permissionVisibilityChip: some View {
        Button {
            showPermissionGrantPopover.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                Text(permissionSummaryText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.mutedForeground.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.45), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPermissionGrantPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stored Resource Grants")
                    .font(.headline)

                Text("Removing an attachment revokes the corresponding scoped resource grant immediately for this mini chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(permissionGrantRows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: row.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.resolved.accent.color)
                                .frame(width: 16, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            if row.isRevocable {
                                Button("Revoke") {
                                    revokePermissionGrant(row.id)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))
                            }
                        }

                        if row.id != permissionGrantRows.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 340, alignment: .leading)
        }
        .accessibilityLabel("Current resource grants")
    }

    private var attachButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "plus",
            variant: .toolbar,
            helpText: "Attach File",
            accessibilityLabel: "Attach file"
        ) {
            openFilePicker()
        }
        .disabled(isProcessing)
    }

    /// P7.5 — the shared in-chat capability explorer (tools + MCP + skills),
    /// parity with Main chat (P2.1/P2.4). Honest: the toggles gate the same
    /// AgentCommandCenterState the shared-coordinator tools path reads, and
    /// running a skill primes the composer with its real `/identifier` slash
    /// token (which MiniChat's slash menu already executes).
    private var toolPanelButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "slider.horizontal.3",
            variant: .toolbar,
            isActive: !agentCommandCenter.disabledToolNames.isEmpty,
            helpText: "Agent tools — turn capabilities on or off for this chat",
            accessibilityLabel: "Agent tools"
        ) {
            openToolPanel()
        }
        .disabled(isProcessing)
        .popover(isPresented: $showToolPanel, arrowEdge: .top) {
            AgentToolTogglePanel(
                agentCommandCenter: agentCommandCenter,
                theme: theme,
                onRunSkill: { skill in runSkillFromPanel(skill) }
            )
        }
    }

    private func openToolPanel() {
        if agentCommandCenter.availableTools.isEmpty {
            refreshExecutionCatalogsIfNeeded()
        } else {
            agentCommandCenter.refreshSkillCatalog()
        }
        showToolPanel.toggle()
    }

    private func runSkillFromPanel(_ skill: SkillDiscoveryEntry) {
        showToolPanel = false
        let invocation = "/\(skill.identifier) "
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = invocation
        } else if !text.hasPrefix("/") {
            text = invocation + text
        }
        isFocused = true
    }

    /// Owner 2026-06-18: trigger for the flat inline runtime picker (replaces the
    /// single-button LocalModelToolbarMenu popover), labelled with the active tier.
    private var inlineRuntimePickerTrigger: some View {
        ToolbarCapsuleButton(
            title: currentTierShortLabel,
            systemImage: "cpu",
            variant: .toolbar,
            isActive: showInlineRuntimePicker,
            helpText: isOsaurusActMode
                ? "Pick the Act model inside the Epistemos picker"
                : "Pick the Epistemos brain — Fast / Think / Code",
            accessibilityLabel: "Model picker, \(currentTierShortLabel)"
        ) {
            withAnimation(.easeInOut(duration: 0.16)) {
                showInlineRuntimePicker.toggle()
            }
        }
    }

    private var currentTierShortLabel: String {
        switch operatingModeBinding.wrappedValue {
        case .fast: return "Fast"
        case .thinking: return "Think"
        case .pro: return "Code"
        case .agent: return "Act"
        }
    }

    private var slashButton: some View {
        ToolbarCapsuleButton(
            title: "/",
            systemImage: "command",
            variant: .toolbar,
            helpText: "Commands",
            accessibilityLabel: "Open commands"
        ) {
            openSlashCommandMenu()
        }
        .disabled(isProcessing)
    }

    private func selectedSlashPill(for item: ComposerSlashCommandItem) -> some View {
        ToolbarCapsuleButton(
            title: "/\(item.rawValue)",
            systemImage: item.icon,
            variant: .toolbar,
            helpText: item.helpText,
            accessibilityLabel: "Selected command \(item.displayName)"
        ) {
            selectedSlashItem = nil
        }
        .disabled(isProcessing)
    }

    private func openFilePicker() {
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

            let urls = await presentFilePicker(panel)
            guard !urls.isEmpty else { return }

            let attachments = await FileAttachmentBuilder.buildAll(from: urls)
            for attachment in attachments {
                appendPendingFileAttachment(attachment)
            }

            for url in urls {
                guard let contextAttachment = ComposerReferenceHelpers.fileContextAttachment(
                    for: url,
                    displayName: url.lastPathComponent
                ) else { continue }
                threadState.addMiniChatContextAttachment(contextAttachment, chatID: chatID)
            }
            persistMiniChatSession()
        }
    }

    @MainActor
    private func presentFilePicker(_ panel: NSOpenPanel) async -> [URL] {
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

    private func appendPendingFileAttachment(_ attachment: FileAttachment) {
        guard !pendingFileAttachments.contains(where: { $0.uri == attachment.uri }) else { return }
        pendingFileAttachments.append(attachment)
    }

    private func removePendingFileAttachment(_ id: String) {
        guard let attachment = pendingFileAttachments.first(where: { $0.id == id }) else { return }
        pendingFileAttachments.removeAll { $0.id == id }
        if let url = URL(string: attachment.uri) {
            threadState.removeMiniChatContextAttachment("file:\(url.absoluteString)", chatID: chatID)
            persistMiniChatSession()
        }
    }

    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .other: return "paperclip"
        }
    }

    private func revokePermissionGrant(_ id: String) {
        if id.hasPrefix("context:"), let contextID = id.split(separator: ":", maxSplits: 1).last {
            threadState.removeMiniChatContextAttachment(String(contextID), chatID: chatID)
            persistMiniChatSession()
            return
        }
        if id.hasPrefix("file:"), let fileID = id.split(separator: ":", maxSplits: 1).last {
            removePendingFileAttachment(String(fileID))
        }
    }

    private func refreshSlashMenu(for newValue: String) {
        let trimmedLeading = newValue.drop(while: \.isWhitespace)
        guard trimmedLeading.first == "/" else {
            if showSlashMenu {
                showSlashMenu = false
                slashFilter = ""
                slashKeyboardIndex = 0
            }
            return
        }

        let afterSlash = String(trimmedLeading.dropFirst())
        if !afterSlash.isEmpty {
            selectedSlashItem = nil
        }
        if afterSlash.contains(where: { $0.isWhitespace || $0.isNewline }) {
            showSlashMenu = false
            slashFilter = ""
            slashKeyboardIndex = 0
            return
        }
        slashFilter = afterSlash
        slashKeyboardIndex = 0
        showSlashMenu = true
    }

    private func applySlashItem(_ item: ComposerSlashCommandItem) {
        if applyImmediateOsaurusCommand(item) {
            return
        }
        if let command = item.command {
            selectedOperatingMode = command.defaultOperatingMode
        }
        selectedSlashItem = item

        let leadingWhitespace = text.prefix { $0.isWhitespace }
        let afterLeading = text.dropFirst(leadingWhitespace.count)
        if afterLeading.hasPrefix("/") {
            let slug = "/" + item.rawValue
            if afterLeading.hasPrefix(slug) {
                let suffix = afterLeading.dropFirst(slug.count)
                text = String(leadingWhitespace) + suffix
            } else {
                let afterSlash = afterLeading.dropFirst()
                let partialEnd = afterSlash.firstIndex(where: { $0.isWhitespace }) ?? afterSlash.endIndex
                let remainder = afterSlash[partialEnd...]
                text = String(leadingWhitespace) + String(remainder)
            }
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let suggestedPrompt = item.suggestedPrompt {
            text = suggestedPrompt
        }

        showSlashMenu = false
        slashFilter = ""
        slashKeyboardIndex = 0
    }

    private func applyImmediateOsaurusCommand(_ item: ComposerSlashCommandItem) -> Bool {
        guard isOsaurusActMode,
              let command = item.osaurusCommand else { return false }

        switch command {
        case .clear:
            MiniChatWindowController.shared.openNewChat(preferredOperatingMode: .agent)
            text = ""
            selectedSlashItem = nil
        case .model:
            withAnimation(.easeInOut(duration: 0.16)) {
                showInlineRuntimePicker = true
            }
            selectedSlashItem = nil
        case .tools:
            openToolPanel()
            selectedSlashItem = nil
        case .configure:
            openSettings()
            NotificationCenter.default.post(name: .showActOsaurusSettings, object: nil)
            selectedSlashItem = nil
        case .agent, .help:
            selectedSlashItem = item
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggestedPrompt = item.suggestedPrompt {
                text = suggestedPrompt
            }
        }

        showSlashMenu = false
        slashFilter = ""
        slashKeyboardIndex = 0
        isFocused = true
        return true
    }

    private func openSlashCommandMenu() {
        guard !supportedSlashItems.isEmpty else { return }
        slashFilter = ""
        slashKeyboardIndex = 0
        showSlashMenu = true
        isFocused = true
    }

    private func handleComposerCommand(
        _ selector: Selector,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard let command = ChatComposerKeyHandling.overlayCommand(
            for: selector,
            modifierFlags: modifierFlags
        ) else {
            return false
        }

        if showMentionDropdown {
            return handleMentionOverlayCommand(command)
        }
        if showSlashMenu {
            return handleSlashOverlayCommand(command)
        }
        return false
    }

    private func handleMentionOverlayCommand(_ command: ChatComposerOverlayCommand) -> Bool {
        let choices = mentionKeyboardChoices
        switch command {
        case .moveDown:
            guard !choices.isEmpty else { return true }
            mentionKeyboardIndex = clamped(mentionKeyboardIndex + 1, count: choices.count)
            return true
        case .moveUp:
            guard !choices.isEmpty else { return true }
            mentionKeyboardIndex = clamped(mentionKeyboardIndex - 1, count: choices.count)
            return true
        case .confirm:
            guard !choices.isEmpty else { return true }
            attachMentionReference(choices[clamped(mentionKeyboardIndex, count: choices.count)])
            return true
        case .cancel:
            dismissReferencePopover()
            return true
        }
    }

    private func handleSlashOverlayCommand(_ command: ChatComposerOverlayCommand) -> Bool {
        let items = filteredSlashItems
        switch command {
        case .moveDown:
            guard !items.isEmpty else { return true }
            slashKeyboardIndex = clamped(slashKeyboardIndex + 1, count: items.count)
            return true
        case .moveUp:
            guard !items.isEmpty else { return true }
            slashKeyboardIndex = clamped(slashKeyboardIndex - 1, count: items.count)
            return true
        case .confirm:
            guard !items.isEmpty else { return true }
            applySlashItem(items[clamped(slashKeyboardIndex, count: items.count)])
            return true
        case .cancel:
            showSlashMenu = false
            slashFilter = ""
            slashKeyboardIndex = 0
            return true
        }
    }

    private func clamped(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
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
        threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
        threadState.setMiniChatPendingContentBlocks([], chatID: chatID)

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
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
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
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
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
        if showMentionDropdown {
            _ = handleMentionOverlayCommand(.confirm)
            return
        }
        if showSlashMenu {
            _ = handleSlashOverlayCommand(.confirm)
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing, selectedRuntimeReady,
              localRuntimeMemoryBlocker == nil else { return }
        let fileAttachments = pendingFileAttachments
        let requestedSlashToken = activeSelectedSlashToken
        refreshExecutionCatalogsForNativeIntent(
            trimmed,
            fileAttachments: fileAttachments,
            requestedSlashToken: requestedSlashToken
        )

        if isOsaurusActMode {
            runActPromptInMiniChat(trimmed, fileAttachments: fileAttachments)
            clearComposerAfterSubmit()
            return
        }

        threadState.addMiniChatMessage(AssistantMessage(role: .user, content: trimmed), chatID: chatID)
        refreshMiniChatLabel(using: trimmed)
        persistMiniChatSession()
        clearComposerAfterSubmit()
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
                let shouldUseSharedCoordinator = shouldUseSharedCoordinator(
                    for: trimmed,
                    fileAttachments: fileAttachments,
                    requestedSlashToken: requestedSlashToken
                )

                if shouldUseSharedCoordinator {
                    try await runSharedCoordinatorTurn(
                        query: trimmed,
                        attachments: attachments,
                        fileAttachments: fileAttachments,
                        requestedSlashToken: requestedSlashToken,
                        page: page
                    )
                    return
                }

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
                        fetchHTMLWorkspaceContext: { attachments in
                            await MainActor.run {
                                HTMLWorkspacePatchRouter.contextPack(for: attachments)
                            }
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
                                        authoredByProviderID: message.authoredByProviderID,
                                        authoredByModelID: message.authoredByModelID,
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
                if let fileAttachmentContext = ChatCoordinator.buildFileAttachmentContext(
                    from: fileAttachments,
                    supportsVision: inference.chatSurfaceSupportsVision(for: selectedOperatingMode)
                ) {
                    promptParts.append(fileAttachmentContext)
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
                final = HTMLWorkspacePatchRouter.applyPatchCommands(
                    in: final,
                    attachments: attachments
                ).visibleResponse

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
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
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
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
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

    private func submitActPromptInMainChat(_ prompt: String, fileAttachments: [FileAttachment]) {
        let request = ActOsaurusPromptRequest(
            text: prompt,
            contextAttachments: activeContextAttachments,
            fileAttachments: fileAttachments,
            sessionId: UUID(uuidString: chatID)
        )
        NotificationCenter.default.post(name: .submitActOsaurusPrompt, object: request)
        HomeWindowIdentity.surfaceHomeWindow()
    }

    private func runActPromptInMiniChat(_ prompt: String, fileAttachments: [FileAttachment]) {
        let attachments = activeContextAttachments
        let requestedModelID = requestedActModelID()

        threadState.addMiniChatMessage(
            AssistantMessage(
                role: .user,
                content: prompt,
                contextAttachments: attachments.isEmpty ? nil : attachments
            ),
            chatID: chatID
        )
        refreshMiniChatLabel(using: prompt)
        persistMiniChatSession()

        isProcessing = true
        threadState.setMiniChatStreaming(true, chatID: chatID)
        threadState.setMiniChatStreamingText("", chatID: chatID)
        threadState.clearMiniChatStreamingThinking(chatID: chatID)
        threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
        threadState.setMiniChatPendingContentBlocks([], chatID: chatID)

        streamTask = Task {
            var accumulated = ""
            var pendingBlocks: [MessageContentBlock] = []

            defer {
                isProcessing = false
                threadState.setMiniChatStreaming(false, chatID: chatID)
            }

            do {
                let resolved = await resolveActMiniChatContext(
                    prompt: prompt,
                    attachments: attachments
                )
                threadState.updateMiniChatLoadedNotes(
                    ids: resolved.loadedNoteIds,
                    titles: resolved.loadedNoteTitles,
                    chatID: chatID
                )

                let conversationPrompt = buildActMiniChatPrompt(
                    cleanedPrompt: resolved.cleanedQuery,
                    resolvedContext: resolved.context,
                    attachments: attachments,
                    fileAttachments: fileAttachments
                )

                guard let actEventStream = SharedActInference.actEventStreamIfArmed(
                    prompt: conversationPrompt,
                    systemPrompt: nil,
                    maxTokens: 2_048,
                    reasoningMode: .thinking,
                    modelID: requestedModelID
                ) else {
                    throw AgentRuntimeError(
                        message: "Act's Osaurus engine is not available for Mini Chat in this build."
                    )
                }

                for try await event in actEventStream {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .textDelta(let text):
                        accumulated += text
                        threadState.setMiniChatStreamingText(accumulated, chatID: chatID)
                    case .thinkingDelta(let text):
                        threadState.appendMiniChatStreamingThinking(text, chatID: chatID)
                    case .toolStarted(let id, let name, let inputJson):
                        pendingBlocks.append(
                            .toolUse(
                                id: id,
                                name: name,
                                input: decodeMiniChatToolInput(inputJson)
                            )
                        )
                        threadState.setMiniChatActiveTool(name: name, inputJson: inputJson, chatID: chatID)
                        threadState.setMiniChatPendingContentBlocks(pendingBlocks, chatID: chatID)
                    case .toolCompleted(let id, let result, let isError):
                        pendingBlocks.append(
                            .toolResult(toolUseId: id, content: result, isError: isError)
                        )
                        threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                        threadState.setMiniChatPendingContentBlocks(pendingBlocks, chatID: chatID)
                    case .generationStats:
                        // 0.33a: telemetry is recorded to ActTurnStatsStore upstream (SharedActInference);
                        // no visible-text effect here.
                        break
                    }
                }

                let final = UserFacingModelOutput.finalVisibleText(from: accumulated)
                let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)

                var completedBlocks = pendingBlocks
                if !final.isEmpty {
                    completedBlocks.append(.text(final))
                }

                threadState.addMiniChatMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: final.isEmpty ? "No response generated." : final,
                        contentBlocks: completedBlocks.isEmpty ? nil : completedBlocks,
                        authoredByProviderID: "act",
                        authoredByModelID: requestedModelID,
                        thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace,
                        loadedNoteTitles: resolved.loadedNoteTitles,
                        contextAttachments: attachments.isEmpty ? nil : attachments
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
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
                if !partial.isEmpty || !pendingBlocks.isEmpty {
                    if !partial.isEmpty {
                        pendingBlocks.append(.text(partial))
                    }
                    threadState.addMiniChatMessage(
                        AssistantMessage(
                            role: .assistant,
                            content: partial,
                            contentBlocks: pendingBlocks.isEmpty ? nil : pendingBlocks,
                            authoredByProviderID: "act",
                            authoredByModelID: requestedModelID,
                            thinkingTrace: thinkingTrace.isEmpty ? nil : thinkingTrace
                        ),
                        chatID: chatID
                    )
                    persistMiniChatSession()
                }
            } catch {
                threadState.setMiniChatStreamingText("", chatID: chatID)
                threadState.clearMiniChatStreamingThinking(chatID: chatID)
                threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
                threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
                threadState.addMiniChatMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: UserFacingChatError.message(from: error),
                        authoredByProviderID: "act",
                        authoredByModelID: requestedModelID
                    ),
                    chatID: chatID
                )
                persistMiniChatSession()
            }
        }
    }

    private func requestedActModelID() -> String? {
        switch inference.effectiveChatSurfaceSelection(for: selectedOperatingMode) {
        case .localMLX(let modelID):
            return modelID
        case .cloud, .appleIntelligence:
            return nil
        }
    }

    private func resolveActMiniChatContext(
        prompt: String,
        attachments: [ContextAttachment]
    ) async -> ChatCoordinator.AttachedContextResolution {
        guard ChatCoordinator.queryContainsExplicitNoteContext(prompt) || !attachments.isEmpty else {
            return .init(
                context: nil,
                cleanedQuery: prompt,
                loadedNoteIds: [],
                loadedNoteTitles: []
            )
        }

        return await ChatCoordinator.resolveAttachedContext(
            query: prompt,
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
            fetchHTMLWorkspaceContext: { attachments in
                await MainActor.run {
                    HTMLWorkspacePatchRouter.contextPack(for: attachments)
                }
            },
            fetchChatMessages: { chatID in
                await MainActor.run {
                    threadState.chatThreads
                        .first(where: { $0.id == chatID })?
                        .messages ?? []
                }
            }
        )
    }

    private func buildActMiniChatPrompt(
        cleanedPrompt: String,
        resolvedContext: String?,
        attachments: [ContextAttachment],
        fileAttachments: [FileAttachment]
    ) -> String {
        var promptParts: [String] = []
        if let resolvedContext {
            promptParts.append(resolvedContext)
        }
        if let fileAttachmentContext = ChatCoordinator.buildFileAttachmentContext(
            from: fileAttachments,
            supportsVision: inference.chatSurfaceSupportsVision(for: selectedOperatingMode)
        ) {
            promptParts.append(fileAttachmentContext)
        }

        let history = (threadState.miniChatSession(id: chatID)?.messages ?? [])
            .dropLast()
            .suffix(10)
        if !history.isEmpty {
            promptParts.append(
                history.map { message in
                    message.role == .user
                        ? "User: \(message.content)"
                        : "Assistant: \(message.content)"
                }
                .joined(separator: "\n\n")
            )
        }

        promptParts.append(cleanedPrompt)
        return promptParts.joined(separator: "\n\n")
    }

    private func decodeMiniChatToolInput(_ inputJson: String) -> [String: JSONValue] {
        guard let data = inputJson.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data)
        else {
            return ["raw": .string(inputJson)]
        }
        return decoded
    }

    private func clearComposerAfterSubmit() {
        text = ""
        composerHeight = ChatComposerInputMetrics.minHeight
        pendingFileAttachments = []
        selectedSlashItem = nil
        showMentionDropdown = false
        showSlashMenu = false
        slashFilter = ""
        slashKeyboardIndex = 0
        referencePopoverStyle = .mention
        mentionKeyboardIndex = 0
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func shouldUseSharedCoordinator(
        for query: String,
        fileAttachments: [FileAttachment] = [],
        requestedSlashToken: ParsedSlashToken? = nil
    ) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if !fileAttachments.isEmpty || requestedSlashToken != nil {
            return true
        }

        let prediction = ChatCapability.predictIntent(
            text: trimmed,
            isCloudProvider: isCloudProviderSelection
        )
        if hasEnabledAppTools,
           ChatCoordinator.queryContainsExplicitNoteWriteOperation(trimmed)
            || ChatCoordinator.queryContainsExplicitFileOperation(trimmed)
            || prediction.predicted == .agent
            || prediction.predicted == .research {
            return true
        }

        switch selectedOperatingMode {
        case .agent, .pro:
            return true
        case .fast, .thinking:
            break
        }

        switch prediction.predicted {
        case .agent, .research:
            return true
        case .local, .thinking, .cloud:
            return false
        }
    }

    private func refreshExecutionCatalogsForNativeIntent(
        _ query: String,
        fileAttachments: [FileAttachment],
        requestedSlashToken: ParsedSlashToken?
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let prediction = ChatCapability.predictIntent(
            text: trimmed,
            isCloudProvider: isCloudProviderSelection
        )
        guard requestedSlashToken != nil
            || !fileAttachments.isEmpty
            || ChatCoordinator.queryContainsExplicitNoteWriteOperation(trimmed)
            || ChatCoordinator.queryContainsExplicitFileOperation(trimmed)
            || prediction.predicted == .agent
            || prediction.predicted == .research
        else { return }

        refreshExecutionCatalogsIfNeeded()
    }

    private func runSharedCoordinatorTurn(
        query: String,
        attachments: [ContextAttachment],
        fileAttachments: [FileAttachment],
        requestedSlashToken: ParsedSlashToken?,
        page: SDPage?
    ) async throws {
        guard let bootstrap = AppBootstrap.shared else {
            throw AgentRuntimeError(message: "Mini chat couldn't access the shared chat runtime.")
        }

        let bridgeState = bridgeChatState(
            attachments: attachments,
            fileAttachments: fileAttachments,
            requestedSlashToken: requestedSlashToken
        )
        let baselineMessageCount = bridgeState.messages.count
        isUsingSharedCoordinator = true
        defer { isUsingSharedCoordinator = false }

        bootstrap.coordinator.handleMiniChatQuery(
            query,
            chatState: bridgeState,
            operatingMode: selectedOperatingMode
        )

        guard let bridgeTask = bootstrap.queryTask else {
            throw AgentRuntimeError(message: "Mini chat couldn't start the shared tools path.")
        }

        let mirrorTask = Task {
            while !Task.isCancelled {
                mirrorSharedCoordinatorState(bridgeState)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        defer { mirrorTask.cancel() }

        do {
            try await withTimeout(seconds: Self.sharedCoordinatorTurnTimeoutSeconds) {
                await bridgeTask.value
            }
        } catch is TimeoutError {
            bridgeTask.cancel()
            bootstrap.queryTask?.cancel()
            mirrorSharedCoordinatorState(bridgeState)
            throw AgentRuntimeError(
                message: "Mini chat tools took too long, so I stopped this turn. Try a narrower request or attach the exact workspace or note."
            )
        }
        mirrorSharedCoordinatorState(bridgeState)
        finalizeSharedCoordinatorTurn(
            from: bridgeState,
            baselineMessageCount: baselineMessageCount,
            attachments: attachments,
            page: page
        )
    }

    private func bridgeChatState(
        attachments: [ContextAttachment],
        fileAttachments: [FileAttachment],
        requestedSlashToken: ParsedSlashToken?
    ) -> ChatState {
        let bridgeState = ChatState()
        let existingMessages = threadState.miniChatSession(id: chatID)?.messages ?? []

        bridgeState.setCurrentChat(chatID)
        bridgeState.chatTitle = miniChatThread?.label
        bridgeState.messages = existingMessages.map { message in
            ChatMessage(
                id: message.id,
                chatId: chatID,
                role: message.role,
                content: message.content,
                createdAt: message.createdAt,
                loadedNoteTitles: message.loadedNoteTitles,
                contextAttachments: message.contextAttachments,
                contentBlocks: message.contentBlocks,
                authoredByProviderID: message.authoredByProviderID,
                authoredByModelID: message.authoredByModelID,
                thinkingTrace: message.thinkingTrace,
                thinkingDurationSeconds: message.thinkingDurationSeconds
            )
        }
        bridgeState.hasMessages = !bridgeState.messages.isEmpty
        bridgeState.pendingContextAttachments = attachments
        bridgeState.pendingAttachments = fileAttachments
        if let lastUserIndex = bridgeState.messages.lastIndex(where: { $0.role == .user }) {
            bridgeState.messages[lastUserIndex].attachments = fileAttachments
            bridgeState.messages[lastUserIndex].contextAttachments = attachments.isEmpty ? nil : attachments
        }
        bridgeState.queuePendingSlashToken(requestedSlashToken)
        if let thread = miniChatThread {
            bridgeState.loadedNoteIds = Set(thread.loadedNoteIds)
            bridgeState.loadedNoteTitles = thread.loadedNoteTitles
        }
        return bridgeState
    }

    private func mirrorSharedCoordinatorState(_ bridgeState: ChatState) {
        threadState.setMiniChatStreaming(true, chatID: chatID)
        threadState.setMiniChatStreamingText(bridgeState.streamingText, chatID: chatID)
        threadState.setMiniChatStreamingThinking(bridgeState.streamingThinking, chatID: chatID)
        threadState.setMiniChatActiveTool(
            name: bridgeState.activeToolName,
            inputJson: bridgeState.activeToolInputJson,
            chatID: chatID
        )
        threadState.setMiniChatPendingContentBlocks(
            bridgeState.pendingContentBlocks,
            chatID: chatID
        )
        threadState.updateMiniChatLoadedNotes(
            ids: bridgeState.loadedNoteIds,
            titles: bridgeState.loadedNoteTitles,
            chatID: chatID
        )
    }

    private func finalizeSharedCoordinatorTurn(
        from bridgeState: ChatState,
        baselineMessageCount: Int,
        attachments: [ContextAttachment],
        page: SDPage?
    ) {
        threadState.setMiniChatStreamingText("", chatID: chatID)
        threadState.clearMiniChatStreamingThinking(chatID: chatID)
        threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
        threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
        threadState.updateMiniChatLoadedNotes(
            ids: bridgeState.loadedNoteIds,
            titles: bridgeState.loadedNoteTitles,
            chatID: chatID
        )

        let newMessages = bridgeState.messages.dropFirst(baselineMessageCount)
        guard let assistant = newMessages.last(where: { $0.role == .assistant }) else {
            persistMiniChatSession()
            return
        }

        var finalContent: String
        if let page {
            finalContent = executeActions(in: assistant.content, page: page)
        } else {
            finalContent = assistant.content
        }
        finalContent = HTMLWorkspacePatchRouter.applyPatchCommands(
            in: finalContent,
            attachments: attachments
        ).visibleResponse

        let finalMessage = AssistantMessage(
            id: assistant.id,
            role: .assistant,
            content: finalContent,
            contentBlocks: assistant.contentBlocks,
            authoredByProviderID: assistant.authoredByProviderID,
            authoredByModelID: assistant.authoredByModelID,
            thinkingTrace: assistant.thinkingTrace,
            thinkingDurationSeconds: assistant.thinkingDurationSeconds,
            loadedNoteTitles: assistant.loadedNoteTitles ?? bridgeState.loadedNoteTitles,
            contextAttachments: assistant.contextAttachments ?? attachments,
            createdAt: assistant.createdAt
        )

        if threadState.miniChatSession(id: chatID)?.messages.last?.id != finalMessage.id {
            threadState.addMiniChatMessage(finalMessage, chatID: chatID)
        }
        persistMiniChatSession()
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
        // Phase R.4 — mirror of ChatInputBar: pass the active vault's
        // stable ID so the `ContextAttachment` gets populated with a
        // canonical `vault://{vaultId}/note/{relativePath}` URI at
        // pick time. Powers the R.5 grant parser + (future) tool-check
        // gate. `lastPathComponent` matches
        // `AppBootstrap.initializeRustResourceServiceIfReady` so both
        // ends of the FFI agree on the vault identity.
        let vaultId = vaultSync.vaultURL?.lastPathComponent
        threadState.addMiniChatContextAttachment(
            ComposerReferenceHelpers.contextAttachment(
                for: choice,
                vaultId: vaultId
            ),
            chatID: chatID
        )
        persistMiniChatSession()
        text = ComposerReferenceHelpers.removingTrailingMention(from: text)
        showMentionDropdown = false
        referencePopoverStyle = .mention
        mentionKeyboardIndex = 0
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func dismissReferencePopover() {
        showMentionDropdown = false
        mentionKeyboardIndex = 0
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
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
            stored.authoredByProviderID = message.authoredByProviderID
            stored.authoredByModelID = message.authoredByModelID
            stored.thinkingTrace = message.thinkingTrace
            stored.thinkingDurationSeconds = message.thinkingDurationSeconds
            stored.setContentBlocks(message.contentBlocks)
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
        let usedSharedCoordinator = isUsingSharedCoordinator
        let partial = UserFacingModelOutput.finalVisibleText(
            from: threadState.miniChatStreamingText(chatID: chatID)
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let thinkingTrace = threadState.miniChatStreamingThinking(chatID: chatID)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        isProcessing = false
        threadState.setMiniChatStreaming(false, chatID: chatID)
        threadState.setMiniChatStreamingText("", chatID: chatID)
        threadState.clearMiniChatStreamingThinking(chatID: chatID)
        threadState.setMiniChatActiveTool(name: nil, inputJson: nil, chatID: chatID)
        threadState.setMiniChatPendingContentBlocks([], chatID: chatID)
        if usedSharedCoordinator {
            AppBootstrap.shared?.queryTask?.cancel()
            isUsingSharedCoordinator = false
        } else {
            streamTask?.cancel()
            streamTask = nil
        }
        if !usedSharedCoordinator, !partial.isEmpty {
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
