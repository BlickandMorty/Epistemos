import SwiftData
import SwiftUI

// MARK: - MiniChat View
// Floating single-thread chat panel with input.

struct MiniChatView: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    private var theme: EpistemosTheme { ui.theme }
    private let surfaceMetrics = AssistantSurfaceMetrics.popout

    var body: some View {
        AssistantSurfaceChrome(theme: theme, metrics: surfaceMetrics) {
            VStack(spacing: 0) {
                MiniChatThread()
                miniChatDivider
                MiniChatInputBar()
            }
        }
        .frame(width: 400, height: 520)
        .onAppear {
            Task { @MainActor in
                threadState.ensureMiniChatThread()
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

// MARK: - Thread View

private struct MiniChatThread: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState

    private var theme: EpistemosTheme { ui.theme }

    private var miniChatThread: ChatThread? {
        threadState.miniChatThread()
    }

    private var hasContent: Bool {
        if let thread = miniChatThread, !thread.messages.isEmpty { return true }
        return threadState.miniChatIsStreaming
    }

    var body: some View {
        Group {
            if hasContent {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if let thread = miniChatThread {
                                ForEach(thread.messages) { msg in
                                    MiniChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }

                            // Live streaming bubble
                            if threadState.miniChatIsStreaming {
                                let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(
                                    from: threadState.miniChatStreamingText
                                )
                                VStack(alignment: .leading, spacing: 0) {
                                    if visibleStreamingText.isEmpty {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text("Responding…")
                                                .font(.system(size: 12))
                                                .foregroundStyle(theme.mutedForeground)
                                        }
                                    } else {
                                        MarkdownTextView(content: visibleStreamingText + " ▍", theme: theme)
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
                    .onChange(of: miniChatThread?.messages.count) { _, _ in
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
        let displayContent = message.role == .assistant
            ? UserFacingModelOutput.finalVisibleText(from: message.content)
            : message.content
        if isUser {
            HStack {
                Spacer(minLength: 24)
                Text(displayContent)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)
                    .textSelection(.enabled)
                    .padding(.vertical, 2)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MarkdownTextView(content: displayContent, theme: theme)
                    .font(.system(size: 13))
                    .textSelection(.enabled)

                AssistantSourcesFooter(
                    sources: AssistantSourceReference.extract(
                        from: displayContent,
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

    private var miniChatThread: ChatThread? {
        threadState.miniChatThread()
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
                            threadState.removeMiniChatContextAttachment(attachment.id)
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
        threadState.addMiniChatMessage(AssistantMessage(role: .user, content: "✨ \(actionLabel): \(pageTitle)"))
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

                let final = UserFacingModelOutput.finalVisibleText(from: accumulated)
                threadState.miniChatStreamingText = ""

                // Auto-apply certain actions
                if action == .autoTag {
                    applyAutoTags(from: final, page: page)
                } else if action == .summarize {
                    page.summary = String(final.prefix(500))
                    page.updatedAt = .now
                }

                threadState.addMiniChatMessage(AssistantMessage(
                    role: .assistant,
                    content: final.isEmpty ? "No response generated." : final
                ))

            } catch is CancellationError {
                let partial = UserFacingModelOutput.finalVisibleText(from: threadState.miniChatStreamingText)
                threadState.miniChatStreamingText = ""
                if !partial.isEmpty {
                    threadState.addMiniChatMessage(AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"))
                }
            } catch {
                threadState.miniChatStreamingText = ""
                threadState.addMiniChatMessage(AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
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

        threadState.addMiniChatMessage(AssistantMessage(role: .user, content: trimmed))
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
                let page = activePage()
                let currentThread = threadState.miniChatThread()
                let attachments = currentThread?.contextAttachments ?? []

                let notesContext: ChatCoordinator.AttachedContextResolution
                if ChatCoordinator.queryContainsExplicitNoteContext(trimmed) || !attachments.isEmpty {
                    notesContext = await ChatCoordinator.resolveAttachedContext(
                        query: trimmed,
                        attachments: attachments,
                        manifest: AppBootstrap.shared?.ambientManifest,
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
                    titles: notesContext.loadedNoteTitles
                )

                // Build conversation-aware prompt from thread history
                let allMessages = threadState.miniChatThread()?.messages ?? []

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

                var final = UserFacingModelOutput.finalVisibleText(from: accumulated)
                threadState.miniChatStreamingText = ""

                // Parse and execute any action markers
                if let page {
                    final = executeActions(in: final, page: page)
                }

                threadState.addMiniChatMessage(AssistantMessage(
                    role: .assistant,
                    content: final.isEmpty ? "No response generated." : final,
                    loadedNoteTitles: notesContext.loadedNoteTitles,
                    contextAttachments: attachments
                ))

            } catch is CancellationError {
                let partial = UserFacingModelOutput.finalVisibleText(from: threadState.miniChatStreamingText)
                threadState.miniChatStreamingText = ""
                if !partial.isEmpty {
                    threadState.addMiniChatMessage(AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"))
                }
            } catch {
                threadState.miniChatStreamingText = ""
                threadState.addMiniChatMessage(AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
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
        threadState.addMiniChatContextAttachment(
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
        threadState.addMiniChatContextAttachment(ComposerReferenceHelpers.allNotesAttachment)
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
