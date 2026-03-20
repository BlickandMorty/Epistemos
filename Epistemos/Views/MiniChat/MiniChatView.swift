import SwiftData
import SwiftUI

// MARK: - MiniChat View
// Floating chat panel with thread tabs + input.

struct MiniChatView: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    @State private var showRecentChats = false

    private var theme: EpistemosTheme { ui.theme }
    private let surfaceMetrics = AssistantSurfaceMetrics.popout

    var body: some View {
        AssistantSurfaceChrome(theme: theme, metrics: surfaceMetrics) {
            VStack(spacing: 0) {
                MiniChatTabBar(showRecentChats: $showRecentChats)
                miniChatDivider
                if showRecentChats {
                    MiniChatRecentChats(showRecentChats: $showRecentChats)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    MiniChatThread()
                        .transition(.opacity)
                }
                miniChatDivider
                MiniChatInputBar()
            }
        }
        .animation(Motion.snap, value: showRecentChats)
        .frame(width: 400, height: 520)
        .onAppear {
            Task { @MainActor in
                guard threadState.chatThreads.isEmpty else { return }
                threadState.createThread(label: "Chat 1")
            }
        }
    }

    private var miniChatDivider: some View {
        Rectangle()
            .fill(theme.glassBorder.opacity(theme.isDark ? 0.72 : 0.5))
            .frame(height: 0.5)
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
    }
}

// MARK: - Tab Bar

private struct MiniChatTabBar: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Binding var showRecentChats: Bool

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 0) {
            // Recent chats toggle
            Button {
                withAnimation(Motion.snap) {
                    showRecentChats.toggle()
                }
            } label: {
                Image(systemName: showRecentChats ? "sidebar.left" : "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(showRecentChats ? theme.foreground : theme.mutedForeground)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(AssistantUtilityButtonStyle(theme: theme))
            .help("Recent Chats")
            .accessibilityLabel("Recent Chats")

            Rectangle()
                .fill(theme.glassBorder.opacity(0.55))
                .frame(width: 0.5, height: 18)
                .padding(.horizontal, 8)

            // Scrollable thread tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(threadState.chatThreads) { thread in
                        ThreadTab(
                            thread: thread,
                            isActive: thread.id == threadState.activeThreadId
                        )
                        .onTapGesture { threadState.setActiveThread(thread.id) }
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)

            // New thread
            Button {
                let count = threadState.chatThreads.count + 1
                threadState.createThread(label: "Chat \(count)")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(AssistantUtilityButtonStyle(theme: theme))
            .help("New Chat")
            .accessibilityLabel("New Chat")
        }
        .padding(.horizontal, 2)
        .frame(height: 42)
    }
}

// MARK: - Thread Tab

private struct ThreadTab: View {
    let thread: ChatThread
    let isActive: Bool

    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 4) {
            Text(thread.label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? theme.foreground : theme.mutedForeground)
                .lineLimit(1)
                .frame(maxWidth: 90)

            Button {
                threadState.closeThread(thread.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close tab")
            .opacity(isActive || isHovered ? 1 : 0)
            .animation(Motion.quick, value: isActive || isHovered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill((isActive ? theme.accent : theme.textSecondary).opacity(isActive || isHovered ? 0.85 : 0))
                .frame(height: 1)
        }
        .animation(Motion.quick, value: isActive)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Thread View

private struct MiniChatThread: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState

    private var theme: EpistemosTheme { ui.theme }

    private var activeThread: ChatThread? {
        threadState.activeThread()
    }

    private var hasContent: Bool {
        if let thread = activeThread, !thread.messages.isEmpty { return true }
        return threadState.miniChatIsStreaming
    }

    var body: some View {
        Group {
            if hasContent {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if let thread = activeThread {
                                ForEach(thread.messages) { msg in
                                    MiniChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }

                            // Live streaming bubble
                            if threadState.miniChatIsStreaming {
                                VStack(alignment: .leading, spacing: 0) {
                                    if threadState.miniChatStreamingText.isEmpty {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text("Thinking…")
                                                .font(.system(size: 12))
                                                .foregroundStyle(theme.mutedForeground)
                                        }
                                    } else {
                                        MarkdownTextView(content: threadState.miniChatStreamingText + " ▍", theme: theme)
                                            .font(.system(size: 13))
                                            .textSelection(.enabled)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("streaming")
                            }

                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 16)
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
                    .onChange(of: activeThread?.messages.count) { _, _ in
                        guard autoFollow.isFollowingBottom else { return }
                        autoFollow.markProgrammaticScrollToBottom()
                        withAnimation(Motion.quick) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: threadState.miniChatStreamingText) { _, _ in
                        // Throttle to ~4fps during streaming (matches ChatView)
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
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(theme.mutedForeground.opacity(0.3))
                    Text("Start a conversation")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chat Bubble

private struct MiniChatBubble: View {
    let message: AssistantMessage

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var isUser: Bool { message.role == .user }

    var body: some View {
        if isUser {
            HStack {
                Spacer(minLength: 24)
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MarkdownTextView(content: message.content, theme: theme)
                    .font(.system(size: 13))
                    .textSelection(.enabled)

                AssistantSourcesFooter(
                    sources: AssistantSourceReference.extract(
                        from: message.content,
                        noteTitles: message.loadedNoteTitles ?? []
                    ),
                    theme: theme,
                    compact: true
                )
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

    init(page: SDPage) {
        self.init(page: page, preferredBody: nil)
    }

    init(page: SDPage, preferredBody: String?) {
        if let preferredBody {
            self.init(title: page.title, tags: page.tags, body: preferredBody)
        } else {
            self.init(title: page.title, tags: page.tags) {
                page.loadBody()
            }
        }
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
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var isProcessing = false
    @State private var streamTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    // @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""
    @State private var mentionPickerAutofocus = false
    @State private var referenceSearch = ComposerReferenceSearchState()
    @State private var snapshotStore = MiniChatSnapshotStore()

    private var theme: EpistemosTheme { ui.theme }
    private let composerMetrics = AssistantComposerMetrics.compactChat

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    private var activeContextAttachments: [ContextAttachment] {
        threadState.activeThread()?.contextAttachments ?? []
    }

    private var explicitScopedPageID: String? {
        if let attachedPageID = activeContextAttachments.first(where: { $0.kind == .note })?.targetId {
            return attachedPageID
        }
        return threadState.activeThread()?.pageId
    }

    private var mentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        ChatCoordinator.searchReferenceResults(
            filter: mentionFilter,
            manifest: AppBootstrap.shared?.ambientManifest,
            chats: recentChats(),
            threads: threadState.chatThreads,
            indexedNoteIDs: referenceSearch.indexedNoteIDs,
            indexedNoteSnippets: referenceSearch.indexedNoteSnippetsByPageID
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            ComposerContextShortcutBar(
                noteLabel: "Chat with Note",
                vaultLabel: "Chat with Vault",
                onChatWithNote: openNotePicker,
                onChatWithVault: attachVaultContext
            )

            // Quick action chips when a note is active
            if explicitScopedPageID != nil, activePage() != nil, !isProcessing {
                quickActions
            }

            if !activeContextAttachments.isEmpty {
                composerAttachmentChips
            }

            HStack(spacing: 10) {
                TextField("Ask anything...", text: $text, axis: .vertical)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .writingToolsBehavior(.limited)
                    .foregroundStyle(theme.foreground)
                    .onSubmit { send() }
                    .onChange(of: text) { _, newVal in
                        if let filter = ComposerReferenceHelpers.mentionFilter(in: newVal) {
                            mentionFilter = filter
                            mentionPickerAutofocus = false
                            if !showMentionDropdown { showMentionDropdown = true }
                        } else if showMentionDropdown {
                            showMentionDropdown = false
                            mentionPickerAutofocus = false
                            referenceSearch.reset()
                        }
                    }
                    .onChange(of: mentionFilter) { _, newValue in
                        updateMentionReferenceSearch(filter: newValue)
                    }

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
            .padding(.horizontal, composerMetrics.horizontalPadding)
            .padding(.vertical, composerMetrics.verticalPadding)
            .assistantGlassInputChrome(
                theme: theme,
                cornerRadius: composerMetrics.cornerRadius,
                isActive: isFocused || canSend || isProcessing || !activeContextAttachments.isEmpty
            )
        }
        .overlay(alignment: .topLeading) {
            if showMentionDropdown {
                ComposerReferencePopover(
                    results: mentionSearchResults,
                    query: $mentionFilter,
                    idealWidth: 560,
                    maxHeight: 420,
                    autofocusSearchField: mentionPickerAutofocus,
                    onSelect: attachMentionReference
                )
            }
        }
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
                            threadState.removeActiveThreadContextAttachment(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.epSmall)
                                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.interactive(), in: Capsule())
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
                QuickActionChip(icon: "tag", label: "Auto-tag", color: theme.accent) {
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
        return try? modelContext.fetch(descriptor).first
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
        guard let pages = try? modelContext.fetch(descriptor) else { return [] }
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
        return PageStoragePool.shared.bodyText(for: page.id)
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
        threadState.addThreadMessage(AssistantMessage(role: .user, content: "✨ \(actionLabel): \(pageTitle)"))
        isProcessing = true
        threadState.miniChatIsStreaming = true
        threadState.miniChatStreamingText = ""

        streamTask = Task {
            defer {
                isProcessing = false
                threadState.miniChatIsStreaming = false
            }
            do {
                let contentLength = prompt.count
                var accumulated = ""

                for try await chunk in triage.streamGeneral(
                    prompt: prompt, systemPrompt: nil,
                    operation: .brainstorm, contentLength: contentLength
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    threadState.miniChatStreamingText = accumulated
                }

                let final = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""

                // Auto-apply certain actions
                if action == .autoTag {
                    applyAutoTags(from: final, page: page)
                } else if action == .summarize {
                    page.summary = String(final.prefix(500))
                    page.updatedAt = .now
                }

                threadState.addThreadMessage(AssistantMessage(
                    role: .assistant,
                    content: final.isEmpty ? "No response generated." : final
                ))

            } catch is CancellationError {
                let partial = threadState.miniChatStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""
                if !partial.isEmpty {
                    threadState.addThreadMessage(AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"))
                }
            } catch {
                threadState.miniChatStreamingText = ""
                threadState.addThreadMessage(AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
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

        threadState.addThreadMessage(AssistantMessage(role: .user, content: trimmed))
        text = ""
        isProcessing = true
        threadState.miniChatIsStreaming = true
        threadState.miniChatStreamingText = ""

        streamTask = Task {
            defer {
                isProcessing = false
                threadState.miniChatIsStreaming = false
            }
            do {
                // Build context from active note + vault search
                let page = activePage()
                let currentThread = threadState.activeThread()

                let notesContext = await ChatCoordinator.resolveAttachedContext(
                    query: trimmed,
                    attachments: currentThread?.contextAttachments ?? [],
                    manifest: AppBootstrap.shared?.ambientManifest,
                    loadedNoteIds: Set(currentThread?.loadedNoteIds ?? []),
                    loadedNoteTitles: currentThread?.loadedNoteTitles ?? [],
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
                            guard let chat = try? modelContext.fetch(descriptor).first else { return [] }
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
                threadState.updateActiveThreadLoadedNotes(
                    ids: notesContext.loadedNoteIds,
                    titles: notesContext.loadedNoteTitles
                )

                // Build conversation-aware prompt from thread history
                let activeThread = threadState.chatThreads.first { $0.id == threadState.activeThreadId }
                let allMessages = activeThread?.messages ?? []

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
                    contentLength: contentLength
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    threadState.miniChatStreamingText = accumulated
                }

                var final = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""

                // Parse and execute any action markers
                if let page {
                    final = executeActions(in: final, page: page)
                }

                threadState.addThreadMessage(AssistantMessage(
                    role: .assistant,
                    content: final.isEmpty ? "No response generated." : final,
                    loadedNoteTitles: notesContext.loadedNoteTitles,
                    contextAttachments: currentThread?.contextAttachments
                ))

            } catch is CancellationError {
                let partial = threadState.miniChatStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""
                if !partial.isEmpty {
                    threadState.addThreadMessage(AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"))
                }
            } catch {
                threadState.miniChatStreamingText = ""
                threadState.addThreadMessage(AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
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
            if let folders = try? modelContext.fetch(folderDescriptor),
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
        threadState.addActiveThreadContextAttachment(
            ComposerReferenceHelpers.contextAttachment(for: choice)
        )
        text = ComposerReferenceHelpers.removingTrailingMention(from: text)
        showMentionDropdown = false
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func openNotePicker() {
        mentionFilter = ""
        mentionPickerAutofocus = true
        showMentionDropdown = true
        isFocused = true
        referenceSearch.reset()
    }

    private func attachVaultContext() {
        threadState.addActiveThreadContextAttachment(ComposerReferenceHelpers.allNotesAttachment)
    }

    private func updateMentionReferenceSearch(filter: String) {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            referenceSearch.reset()
            return
        }
        referenceSearch.update(
            filter: trimmed,
            manifest: AppBootstrap.shared?.ambientManifest,
            vaultSync: vaultSync
        )
    }

    private func recentChats() -> [SDChat] {
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = 20
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
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

// MARK: - Recent Chats Drawer

private struct MiniChatRecentChats: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Environment(\.modelContext) private var modelContext
    @Binding var showRecentChats: Bool
    @State private var mainChats: [SDChat] = []

    private var theme: EpistemosTheme { ui.theme }

    // Show existing mini-chat threads
    private var recentThreads: [ChatThread] {
        threadState.chatThreads.filter { !$0.messages.isEmpty }
    }

    private var hasContent: Bool {
        !recentThreads.isEmpty || !mainChats.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !hasContent {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(theme.mutedForeground.opacity(0.3))
                    Text("No saved chats")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Main chat history (persisted via SwiftData)
                        if !mainChats.isEmpty {
                            HStack {
                                Text("MAIN CHATS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                            ForEach(mainChats, id: \.id) { sdChat in
                                MainChatRow(sdChat: sdChat) {
                                    loadSDChatIntoThread(sdChat)
                                }
                                Divider()
                                    .padding(.leading, 16)
                                    .opacity(0.4)
                            }
                        }

                        // Mini-chat threads
                        if !recentThreads.isEmpty {
                            HStack {
                                Text("QUICK CHATS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                            ForEach(recentThreads) { thread in
                                RecentChatRow(thread: thread) {
                                    threadState.setActiveThread(thread.id)
                                    withAnimation { showRecentChats = false }
                                }
                                Divider()
                                    .padding(.leading, 16)
                                    .opacity(0.4)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadMainChats() }
    }

    private func loadMainChats() {
        var descriptor = FetchDescriptor<SDChat>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        mainChats = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadSDChatIntoThread(_ sdChat: SDChat) {
        let sorted = sdChat.sortedMessages
        let messages = sorted.map { msg in
            AssistantMessage(
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content,
                createdAt: msg.createdAt
            )
        }
        let threadId = threadState.createThread(type: "chat", label: sdChat.title)
        for msg in messages {
            threadState.addThreadMessage(msg, threadId: threadId)
        }
        threadState.setActiveThread(threadId)
        withAnimation { showRecentChats = false }
    }
}

private struct MainChatRow: View {
    let sdChat: SDChat
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    private var messageCount: Int { sdChat.sortedMessages.count }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sdChat.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    if let last = sdChat.sortedMessages.last {
                        Text(last.content.prefix(60))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(relativeDate(sdChat.updatedAt))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Text("\(messageCount) msgs")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovered ? theme.foreground.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .onHover { isHovered = $0 }
    }

    private func relativeDate(_ date: Date) -> String {
        let diff = Date.now.timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 604800 { return "\(Int(diff / 86400))d ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct RecentChatRow: View {
    let thread: ChatThread
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    if let lastMsg = thread.messages.last {
                        Text(lastMsg.content.prefix(60))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(thread.messages.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovered ? theme.foreground.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .onHover { isHovered = $0 }
    }
}
