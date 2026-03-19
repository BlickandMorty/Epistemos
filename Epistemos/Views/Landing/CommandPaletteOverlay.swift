import SwiftData
import SwiftUI

// MARK: - Command Palette Overlay
// Unified global search + floating chat. Replaces both the command palette
// and MiniChat. Starts as a frosted-glass search bar (Option+Space), morphs
// into a tabbed floating chat on query submission (blur-replace transition).
// Context-aware: from landing page → navigates to main chat; from anywhere
// else → inline floating chat with thread tabs.

private enum PaletteMode: Equatable {
    case search
    case chat
}

enum CommandPaletteLayout {
    static let compactWidth: CGFloat = 380
    static let expandedSearchWidth: CGFloat = 430
    static let chatWidth: CGFloat = 470

    static let compactPanelSize = CGSize(width: 460, height: 220)
    static let expandedSearchPanelSize = CGSize(width: 510, height: 460)
    static let chatPanelSize = CGSize(width: 550, height: 660)
}

struct CommandPaletteOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference
    @Environment(GraphState.self) private var graphState

    @Environment(ThreadState.self) private var threadState
    @Environment(TriageService.self) private var triage
    @Environment(\.modelContext) private var modelContext

    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]
    @Query(sort: \SDChat.updatedAt, order: .reverse) private var allChats: [SDChat]

    // MARK: - Search State

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var hasManuallyNavigated = false

    @State private var cachedSearchResults: [LandingCommandItem] = []
    @State private var ftsDebounceTask: Task<Void, Never>?
    @State private var appeared = false
    @FocusState private var isSearchFocused: Bool
    @State private var isExpanded = false

    // MARK: - Chat State

    @State private var mode: PaletteMode = .search
    @State private var activeTabId: String?
    @State private var streamTask: Task<Void, Never>?
    @State private var chatInput = ""
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    @State private var chatAutoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    @FocusState private var isChatFocused: Bool

    private var theme: EpistemosTheme { ui.theme }
    private let surfaceMetrics = AssistantSurfaceMetrics.commandPalette
    private let composerMetrics = AssistantComposerMetrics.compactChat
    private var mentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        ChatCoordinator.searchReferenceResults(
            filter: mentionFilter,
            manifest: AppBootstrap.shared?.ambientManifest,
            chats: allChats,
            threads: threadState.chatThreads
        )
    }
    private var activeContextAttachments: [ContextAttachment] {
        activeThread?.contextAttachments ?? []
    }
    private var lockedScopedPageAttachment: ContextAttachment? {
        guard activeContextAttachments.isEmpty, let page = scopedPage() else { return nil }
        return ContextAttachment(
            kind: .note,
            targetId: page.id,
            title: page.title.isEmpty ? "Untitled" : page.title
        )
    }

    private var showResults: Bool { !searchText.isEmpty }
    private var preferredPaletteWidth: CGFloat {
        if mode == .chat { return CommandPaletteLayout.chatWidth }
        return (showResults || isExpanded)
            ? CommandPaletteLayout.expandedSearchWidth
            : CommandPaletteLayout.compactWidth
    }
    private var preferredPanelSize: CGSize {
        if mode == .chat { return CommandPaletteLayout.chatPanelSize }
        return (showResults || isExpanded)
            ? CommandPaletteLayout.expandedSearchPanelSize
            : CommandPaletteLayout.compactPanelSize
    }

    // MARK: - Body

    var body: some View {
        AssistantSurfaceChrome(theme: theme, metrics: surfaceMetrics) {
            VStack(spacing: 0) {
                searchBar

                ZStack {
                    if mode == .search {
                        if showResults {
                            VStack(spacing: 0) {
                                paletteDivider
                                resultsSection
                            }
                            .transition(.opacity.combined(with: .blurReplace))
                        } else if isExpanded {
                            VStack(spacing: 0) {
                                paletteDivider
                                expandedCommandsSection
                            }
                            .transition(.opacity.combined(with: .blurReplace))
                        }
                    } else {
                        VStack(spacing: 0) {
                            paletteDivider
                            chatTabBar
                            paletteDivider.opacity(0.82)
                            chatSection
                            chatInputBar
                        }
                        .transition(.opacity.combined(with: .blurReplace))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: mode)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
            }
        }
        .frame(width: preferredPaletteWidth)
        .frame(maxHeight: mode == .chat ? .infinity : nil)
        .fixedSize(horizontal: false, vertical: mode == .search)
        .offset(y: appeared ? 0 : -15)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showResults)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appeared)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: preferredPaletteWidth)
        .onAppear {
            Task { @MainActor in
                appeared = true
                syncPaletteSize()
                isSearchFocused = true
                try? await Task.sleep(for: .milliseconds(50))
                if !isSearchFocused { isSearchFocused = true }
            }
        }
        .onChange(of: mode) { _, _ in
            syncPaletteSize()
        }
        .onChange(of: showResults) { _, _ in
            syncPaletteSize()
        }
        .onChange(of: isExpanded) { _, _ in
            syncPaletteSize()
        }
        .onExitCommand { handleEscape() }
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteSwitchToChat)) { _ in
            withAnimation(Motion.smooth) { mode = .chat }
            ensureActiveTab()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                isChatFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteOpenNotePicker)) { _ in
            openNotePicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteAttachAllNotes)) { _ in
            attachVaultContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteDidHide)) { _ in
            isSearchFocused = false
            isChatFocused = false
            isExpanded = false
        }
    }

    private var paletteDivider: some View {
        Rectangle()
            .fill(theme.glassBorder.opacity(theme.isDark ? 0.7 : 0.5))
            .frame(height: 0.5)
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        Group {
            if mode == .chat {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(Motion.smooth) { mode = .search }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            isSearchFocused = true
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(AssistantUtilityButtonStyle(theme: theme))

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: paletteRoutingIcon)
                            .font(.system(size: 10, weight: .medium))
                        Text(inference.routingMode.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .assistantInsetChrome(theme: theme, cornerRadius: 15)

                    if threadState.paletteIsStreaming {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(.bottom, 2)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        sparklesIcon
                            .frame(width: 18, height: 18)

                        TextField("Search or ask anything\u{2026}", text: $searchText)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(theme.foreground)
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)
                            .onSubmit { executeSelected() }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                cachedSearchResults = []
                                selectedIndex = 0
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 12, height: 12)
                            }
                            .buttonStyle(AssistantUtilityButtonStyle(theme: theme))
                            .transition(.scale(scale: 0.5).combined(with: .opacity))

                            AssistantSendButton(
                                theme: theme,
                                isEnabled: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                isProcessing: false,
                                metrics: composerMetrics
                            ) {
                                executeSelected()
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 12, height: 12)
                            }
                            .buttonStyle(AssistantUtilityButtonStyle(theme: theme))
                        }
                    }
                    .padding(.horizontal, composerMetrics.horizontalPadding)
                    .padding(.vertical, composerMetrics.verticalPadding)
                    .assistantInsetChrome(
                        theme: theme,
                        cornerRadius: composerMetrics.cornerRadius,
                        isEmphasized: isSearchFocused || !searchText.isEmpty
                    )

                    if searchText.isEmpty {
                        HStack(spacing: 8) {
                            paletteChip(label: "Chat with Note", icon: "doc.text.magnifyingglass") {
                                switchToChatAndOpenNotePicker()
                            }
                            paletteChip(label: "Chat with Vault", icon: "books.vertical") {
                                switchToChatAndAttachVault()
                            }
                            paletteChip(label: "Note", icon: "doc.badge.plus") {
                                CommandPaletteWindowController.shared.hide()
                                Task { @MainActor in
                                    if let pageId = await vaultSync.createPage(title: "Untitled") {
                                        NoteWindowManager.shared.open(pageId: pageId)
                                    }
                                }
                            }
                            paletteChip(label: "Graph", icon: "circle.grid.3x3") {
                                CommandPaletteWindowController.shared.hide()
                                HologramController.shared.show()
                            }
                            paletteChip(label: "Appearance", icon: "paintpalette") {
                                dismiss()
                                UtilityWindowManager.shared.show(.settings)
                            }
                        }
                        .transition(.opacity.combined(with: .blurReplace))
                    }

                    HStack(spacing: 6) {
                        ExpandingModeButton(
                            title: "Incognito",
                            systemImage: chat.isIncognito ? "eye.slash.fill" : "eye.slash",
                            isActive: chat.isIncognito,
                            variant: .toolbar,
                            helpText: chat.isIncognito ? "Incognito On" : "Enable Incognito",
                            stableWidth: NativeControlSystem.reservedWidth(
                                for: "Incognito",
                                variant: .toolbar
                            )
                        ) {
                            chat.isIncognito.toggle()
                        }

                        Spacer()

                        ASCIIRippleText(
                            text: "\u{2325}Space",
                            font: .system(size: 10, weight: .medium, design: .monospaced),
                            color: theme.textTertiary.opacity(0.6)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    searchResultsView
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 280)
            .onChange(of: selectedIndex) { _, idx in
                withAnimation(Motion.micro) { proxy.scrollTo(idx, anchor: .center) }
            }
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onChange(of: searchText) { _, newText in
            handleSearchChange(newText)
        }
    }

    // MARK: - Expanded Commands

    private var expandedCommandsSection: some View {
        let commands = makeCommands()
        let grouped = Dictionary(grouping: commands) { $0.category }

        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Self.categoryOrder, id: \.self) { category in
                    if let items = grouped[category], !items.isEmpty {
                        HStack(spacing: 6) {
                            Text(category.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.textTertiary.opacity(0.45))
                                .tracking(1.2)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, category == Self.categoryOrder.first ? 2 : 12)
                        .padding(.bottom, 4)

                        ForEach(items) { cmd in
                            SpotlightRow(command: cmd, isSelected: false, theme: theme, style: .plain) {
                                cmd.action()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 320)
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        let results = filteredResults
        let grouped = Dictionary(grouping: results) { $0.category }
        let categoryOrder = orderedCategories(from: grouped)

        return ForEach(categoryOrder, id: \.self) { category in
            if let items = grouped[category], !items.isEmpty {
                HStack(spacing: 6) {
                    Text(category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textTertiary.opacity(0.45))
                        .tracking(1.2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, category == categoryOrder.first ? 2 : 12)
                .padding(.bottom, 4)

                ForEach(items) { cmd in
                    let idx = results.firstIndex(where: { $0.id == cmd.id }) ?? 0
                    SpotlightRow(
                        command: cmd,
                        isSelected: idx == selectedIndex,
                        theme: theme,
                        style: .plain
                    ) {
                        cmd.action()
                    }
                    .id(idx)
                    .onTapGesture {
                        selectedIndex = idx
                        cmd.action()
                    }
                }
            }
        }
    }

    private func orderedCategories(from grouped: [String: [LandingCommandItem]]) -> [String] {
        let searchCategories = ["Notes", "Body Match", "Block Match"]
        let actionCategories = ["Chat"]
        let commandCategories = Self.categoryOrder

        var ordered: [String] = []
        for cat in searchCategories where grouped[cat] != nil { ordered.append(cat) }
        for cat in grouped.keys.sorted() where !searchCategories.contains(cat) && !actionCategories.contains(cat) && !commandCategories.contains(cat) {
            ordered.append(cat)
        }
        for cat in commandCategories where grouped[cat] != nil { ordered.append(cat) }
        for cat in actionCategories where grouped[cat] != nil { ordered.append(cat) }
        return ordered
    }

    // MARK: - Chat Tab Bar

    // MARK: - Mode Picker

    private var paletteModeMenu: some View {
        Menu {
            Button {
                inference.setRoutingMode(.auto)
            } label: {
                Label("Auto", systemImage: "sparkles")
            }

            Button {
                inference.setRoutingMode(.localOnly)
            } label: {
                Label("Local Only", systemImage: "memorychip")
            }
        } label: {
            Image(systemName: paletteRoutingIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(inference.routingMode == .auto ? theme.textTertiary : theme.accent)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(inference.routingMode.displayName)
    }

    private var chatTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(paletteThreads) { thread in
                    Button {
                        withAnimation(Motion.quick) { activeTabId = thread.id }
                        threadState.setActiveThread(thread.id)
                    } label: {
                        Text(thread.label)
                            .font(.system(size: 11, weight: activeTabId == thread.id ? .semibold : .regular))
                            .foregroundStyle(activeTabId == thread.id ? theme.foreground : theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .assistantInsetChrome(
                        theme: theme,
                        cornerRadius: 14,
                        isEmphasized: activeTabId == thread.id
                    )
                }

                Button {
                    let newId = threadState.createThread(type: "palette", label: "Chat \(paletteThreads.count + 1)")
                    withAnimation(Motion.quick) { activeTabId = newId }
                    threadState.setActiveThread(newId)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .assistantInsetChrome(theme: theme, cornerRadius: 14)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let thread = activeThread {
                        if thread.messages.isEmpty && !threadState.paletteIsStreaming {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.3))
                                Text("Start a conversation")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(thread.messages) { msg in
                                PaletteChatBubble(message: msg, theme: theme)
                            }
                        }
                    }

                    if threadState.paletteIsStreaming {
                        VStack(alignment: .leading, spacing: 0) {
                            if threadState.paletteStreamingText.isEmpty {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Thinking\u{2026}")
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.mutedForeground)
                                }
                            } else {
                                MarkdownTextView(
                                    content: threadState.paletteStreamingText + " \u{258D}",
                                    theme: theme
                                )
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
            .frame(maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: ScrollStability.distanceToBottom(for:)
            ) { _, distance in
                let nextState = ScrollStability.updatedAutoFollowState(
                    from: chatAutoFollow,
                    distanceToBottom: distance
                )
                guard nextState != chatAutoFollow else { return }
                chatAutoFollow = nextState
            }
            .onChange(of: activeThread?.messages.count) { _, _ in
                guard chatAutoFollow.isFollowingBottom else { return }
                chatAutoFollow.markProgrammaticScrollToBottom()
                withAnimation(Motion.quick) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: threadState.paletteStreamingText) { _, _ in
                let now = ContinuousClock.now
                guard chatAutoFollow.isFollowingBottom,
                      now - lastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                else { return }
                lastScrollTime = now
                chatAutoFollow.markProgrammaticScrollToBottom()
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onAppear {
                Task { @MainActor in
                    chatAutoFollow.markProgrammaticScrollToBottom()
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        VStack(spacing: 8) {
            ComposerContextShortcutBar(
                noteLabel: "Chat with Note",
                vaultLabel: "Chat with Vault",
                onChatWithNote: openNotePicker,
                onChatWithVault: attachVaultContext
            )

            if !activeContextAttachments.isEmpty || lockedScopedPageAttachment != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activeContextAttachments) { attachment in
                            HStack(spacing: 4) {
                                Image(systemName: iconForContextAttachment(attachment))
                                    .font(.system(size: 10, weight: .medium))
                                Text(attachment.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Button {
                                    threadState.removeActiveThreadContextAttachment(attachment.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.textTertiary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .foregroundStyle(theme.textSecondary)
                        }

                        if let attachment = lockedScopedPageAttachment {
                            HStack(spacing: 4) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10, weight: .medium))
                                Text(attachment.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .foregroundStyle(theme.accent)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            HStack(spacing: 10) {
                // Routing/model picker
                paletteModeMenu

                TextField("Ask anything\u{2026}", text: $chatInput)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.foreground)
                    .focused($isChatFocused)
                    .onSubmit { sendChatMessage() }
                    .onChange(of: chatInput) { _, newValue in
                        if let filter = ComposerReferenceHelpers.mentionFilter(in: newValue) {
                            mentionFilter = filter
                            if !showMentionDropdown { showMentionDropdown = true }
                        } else if showMentionDropdown {
                            showMentionDropdown = false
                        }
                    }

                AssistantSendButton(
                    theme: theme,
                    isEnabled: !chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    isProcessing: threadState.paletteIsStreaming,
                    metrics: composerMetrics
                ) {
                    if threadState.paletteIsStreaming {
                        cancelStream()
                    } else {
                        sendChatMessage()
                    }
                }
            }
            .padding(.horizontal, composerMetrics.horizontalPadding)
            .padding(.vertical, composerMetrics.verticalPadding)
            .assistantGlassInputChrome(
                theme: theme,
                cornerRadius: composerMetrics.cornerRadius,
                isActive: isChatFocused || !chatInput.isEmpty || threadState.paletteIsStreaming || !activeContextAttachments.isEmpty || lockedScopedPageAttachment != nil
            )
        }
        .padding(.top, 10)
        .overlay(alignment: .topLeading) {
            if showMentionDropdown {
                ComposerReferencePopover(
                    results: mentionSearchResults,
                    idealWidth: 320,
                    maxHeight: 300,
                    onSelect: attachMentionReference
                )
            }
        }
    }

    // MARK: - Chat Logic

    private func sendChatMessage() {
        let trimmed = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !threadState.paletteIsStreaming else { return }

        ensureActiveTab()
        guard let tid = activeTabId else { return }

        threadState.addThreadMessage(
            AssistantMessage(role: .user, content: trimmed),
            threadId: tid
        )
        chatInput = ""
        threadState.paletteIsStreaming = true
        threadState.paletteStreamingText = ""

        streamTask = Task { @MainActor in
            defer {
                // Guard: cancelStream() may have already cleared these
                if threadState.paletteIsStreaming {
                    threadState.paletteIsStreaming = false
                }
            }
            do {
                let activeMessages = activeThread?.messages ?? []
                let attachments = activeContextAttachments.isEmpty
                    ? lockedScopedPageAttachment.map { [$0] } ?? []
                    : activeContextAttachments
                let notesContext = await ChatCoordinator.resolveAttachedContext(
                    query: trimmed,
                    attachments: attachments,
                    manifest: AppBootstrap.shared?.ambientManifest,
                    loadedNoteIds: [],
                    loadedNoteTitles: [],
                    includeAllNotesContext: false,
                    findNotesByTitle: { [vaultSync] title in
                        await vaultSync.findNotesByTitle(title)
                    },
                    fetchNoteBodies: { [vaultSync] ids in
                        await vaultSync.fetchNoteBodies(ids: ids)
                    },
                    searchNoteIDs: { [vaultSync] query in
                        await vaultSync.searchIndex(query: query)
                    },
                    fetchChatMessages: { [self] chatID in
                        await MainActor.run {
                            if let thread = threadState.chatThreads.first(where: { $0.id == chatID }) {
                                return thread.messages
                            }
                            guard let chat = allChats.first(where: { $0.id == chatID }) else { return [] }
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

                // Build conversation-aware prompt with thread history
                var promptParts: [String] = []
                if let context = notesContext.context, !context.isEmpty {
                    promptParts.append(context)
                }
                if activeMessages.count > 1 {
                    let history = activeMessages.dropLast().suffix(10)
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

                let stream = triage.streamGeneral(
                    prompt: conversationPrompt,
                    systemPrompt: nil,
                    operation: .chatResponse(query: trimmed),
                    contentLength: contentLength,
                    localReasoningMode: .fast
                )

                for try await chunk in stream {
                    try Task.checkCancellation()
                    accumulated += chunk
                    threadState.paletteStreamingText = accumulated
                }

                // Guard: cancelStream() may have already handled this
                guard threadState.paletteIsStreaming else { return }

                var final = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.paletteStreamingText = ""

                // Parse and execute action markers
                if let page = scopedPage() {
                    final = executeActions(in: final, page: page)
                }

                threadState.addThreadMessage(
                    AssistantMessage(
                        role: .assistant,
                        content: final.isEmpty ? "No response." : final,
                        loadedNoteTitles: notesContext.loadedNoteTitles,
                        contextAttachments: attachments
                    ),
                    threadId: tid
                )

            } catch is CancellationError {
                // cancelStream() already handled UI state — just bail
                return
            } catch {
                // Guard: cancelStream() may have already cleared streaming
                guard threadState.paletteIsStreaming else { return }
                threadState.paletteStreamingText = ""
                threadState.addThreadMessage(
                    AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"),
                    threadId: tid
                )
            }
        }
    }

    private var paletteRoutingIcon: String {
        switch inference.routingMode {
        case .auto: "sparkles"
        case .localOnly: "memorychip"
        }
    }

    private func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        // Immediately clear streaming state so UI unblocks.
        // The cancelled task's defer block will also set this, but it may
        // be blocked waiting on the stream iterator — clear it now.
        let partial = threadState.paletteStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        threadState.paletteStreamingText = ""
        threadState.paletteIsStreaming = false
        if !partial.isEmpty, let tid = activeTabId {
            threadState.addThreadMessage(
                AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"),
                threadId: tid
            )
        }
    }

    private func ensureActiveTab() {
        if activeTabId == nil || paletteThreads.isEmpty {
            let newId = threadState.createThread(type: "palette", label: "Chat 1")
            activeTabId = newId
            threadState.setActiveThread(newId)
            return
        }
        if let activeTabId {
            threadState.setActiveThread(activeTabId)
        }
    }

    private var paletteThreads: [ChatThread] {
        threadState.chatThreads.filter { $0.type == "palette" }
    }

    private var activeThread: ChatThread? {
        guard let id = activeTabId else { return nil }
        return threadState.chatThreads.first { $0.id == id }
    }

    // MARK: - Note Context

    private func scopedPage() -> SDPage? {
        let noteAttachmentID = activeThread?.contextAttachments.first(where: { $0.kind == .note })?.targetId
        guard let targetId = noteAttachmentID ?? activeThread?.pageId else { return nil }
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == targetId })
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Action Parsing

    private func executeActions(in response: String, page: SDPage) -> String {
        var cleaned = response
        var executedActions: [String] = []

        // TAG action
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
                executedActions.append("\u{2705} Added tags: \(newTags.joined(separator: ", "))")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // MOVE action
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
                executedActions.append("\u{2705} Moved to folder: \(folder.name)")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // CREATE action
        if let range = response.range(of: #"\[ACTION:CREATE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let title = marker
                .replacingOccurrences(of: "[ACTION:CREATE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                Task {
                    if let newId = await vaultSync.createPage(title: title) {
                        NoteWindowManager.shared.open(pageId: newId)
                    }
                }
                executedActions.append("\u{2705} Created note: \(title)")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        if !executedActions.isEmpty {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned += "\n\n---\n" + executedActions.joined(separator: "\n")
        }

        return cleaned
    }

    // MARK: - Search Logic

    private func handleSearchChange(_ newText: String) {
        hasManuallyNavigated = false

        if newText.isEmpty {
            ftsDebounceTask?.cancel()
            cachedSearchResults = []
            selectedIndex = 0
            return
        }

        // Title search — always runs first.
        let titleItems = computeTitleResults(for: newText)
        let titlePageIds = Set(titleItems.compactMap { item in
            item.id.hasPrefix("title-") ? String(item.id.dropFirst(6)) : nil
        })
        cachedSearchResults = titleItems

        // FTS body + block search (debounced 150ms).
        ftsDebounceTask?.cancel()
        ftsDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let bodyHits = await vaultSync.searchFullAsync(query: newText, limit: 30)
            guard !Task.isCancelled else { return }
            let blockHits = await vaultSync.searchBlocksAsync(query: newText, limit: 10)
            guard !Task.isCancelled else { return }
            let bodyItems = computeBodyResults(from: bodyHits, excluding: titlePageIds)
            let blockItems = computeBlockResults(from: blockHits, excluding: titlePageIds)
            withAnimation(Motion.quick) {
                cachedSearchResults = titleItems + bodyItems + blockItems
            }
        }

        if !cachedSearchResults.isEmpty {
            selectedIndex = 1
        } else {
            selectedIndex = 0
        }
    }

    // MARK: - Filtered Results

    private var filteredResults: [LandingCommandItem] {
        var base: [LandingCommandItem] = []

        if !searchText.isEmpty {
            let q = searchText
            base.append(
                LandingCommandItem(
                    id: "ask", label: "Ask: \"\(q)\"", icon: "arrow.up.circle", category: "Chat"
                ) { [self] in submitChat(q) })
        }

        base += cachedSearchResults

        let q = searchText.lowercased()
        let filtered = makeCommands().filter {
            $0.label.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
        return base + filtered
    }

    // MARK: - Search Engine

    private func computeTitleResults(for query: String) -> [LandingCommandItem] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()

        // Relevance scoring: exact > prefix > contains > tag match.
        // Within same tier, shorter titles rank higher (closer match).
        let scored: [(page: SDPage, score: Int)] = allPages
            .compactMap { page in
                let title = page.title.lowercased()
                let score: Int
                if title == q {
                    score = 400
                } else if title.hasPrefix(q) {
                    score = 300 - min(title.count, 100)
                } else if title.contains(q) {
                    score = 200 - min(title.count, 100)
                } else if page.tags.contains(where: { $0.lowercased().contains(q) }) {
                    score = 100
                } else {
                    return nil
                }
                return (page, score)
            }
            .sorted { $0.score > $1.score }

        return scored.prefix(10)
            .map { entry in
                let page = entry.page
                let emoji = page.emoji.isEmpty ? "" : "\(page.emoji) "
                let label = "\(emoji)\(page.title.isEmpty ? "Untitled" : page.title)"
                let parts = [
                    "\(page.wordCount)w",
                    page.tags.prefix(2).joined(separator: ", "),
                    relativeDate(page.updatedAt),
                ].filter { !$0.isEmpty }
                let subtitle = parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
                let pageId = page.id
                return LandingCommandItem(
                    id: "title-\(pageId)", label: label, icon: "doc.text",
                    category: "Notes", subtitle: subtitle
                ) { [self] in
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                }
            }
    }

    private func computeBodyResults(from hits: [SearchResult], excluding seenPageIds: Set<String>) -> [LandingCommandItem] {
        guard !hits.isEmpty else { return [] }
        var items: [LandingCommandItem] = []
        let index = pageIndex

        for hit in hits where !seenPageIds.contains(hit.pageId) {
            let pageId = hit.pageId
            let rawSnippet = hit.snippet
                .replacingOccurrences(of: "<b>", with: "")
                .replacingOccurrences(of: "</b>", with: "")

            let page = index[pageId]
            let emoji = page?.emoji ?? ""
            let rawTitle = hit.title.isEmpty ? "Untitled" : hit.title
            let label = emoji.isEmpty ? rawTitle : "\(emoji) \(rawTitle)"

            var subtitleParts: [String] = []
            if let page {
                subtitleParts.append("\(page.wordCount)w")
                subtitleParts.append(relativeDate(page.updatedAt))
            }
            let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " \u{00B7} ")
            let snippet = rawSnippet.isEmpty ? nil : rawSnippet

            items.append(
                LandingCommandItem(
                    id: "fts-\(pageId)", label: label, icon: "doc.text.magnifyingglass",
                    category: "Body Match", subtitle: subtitle, snippet: snippet
                ) { [self] in
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                })
        }

        return items
    }

    private func computeBlockResults(from hits: [BlockSearchResult], excluding seenPageIds: Set<String>) -> [LandingCommandItem] {
        guard !hits.isEmpty else { return [] }
        let index = pageIndex
        var items: [LandingCommandItem] = []

        for hit in hits where !seenPageIds.contains(hit.pageId) {
            let pageId = hit.pageId
            let rawSnippet = hit.snippet
                .replacingOccurrences(of: "<b>", with: "")
                .replacingOccurrences(of: "</b>", with: "")

            let page = index[pageId]
            let pageTitle = page?.title ?? "Untitled"
            let emoji = page?.emoji ?? ""
            let subtitle = emoji.isEmpty ? pageTitle : "\(emoji) \(pageTitle)"

            items.append(
                LandingCommandItem(
                    id: "block-\(hit.blockId)", label: rawSnippet.isEmpty ? "Block" : rawSnippet,
                    icon: "cube.transparent", category: "Block Match",
                    subtitle: subtitle
                ) { [self] in
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                })
        }

        return items
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        let count = filteredResults.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
        hasManuallyNavigated = true
    }

    private func dismiss() {
        cancelStream()
        ftsDebounceTask?.cancel()
        ftsDebounceTask = nil
        mode = .search
        chatInput = ""
        isSearchFocused = false
        searchText = ""
        selectedIndex = 0
        hasManuallyNavigated = false
        isExpanded = false
        cachedSearchResults = []
        CommandPaletteWindowController.shared.hide()
    }

    private func syncPaletteSize() {
        CommandPaletteWindowController.shared.updatePreferredSize(preferredPanelSize)
    }

    private func submitChat(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Always use the palette's own floating chat (ThreadState).
        // Never route to the main landing page ChatState.
        withAnimation(Motion.smooth) {
            mode = .chat
            searchText = ""
            cachedSearchResults = []
        }
        chatInput = trimmed
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            sendChatMessage()
            isChatFocused = true
        }
    }

    private func attachMentionReference(_ choice: ComposerReferenceChoice) {
        ensureActiveTab()
        if let activeTabId {
            threadState.setActiveThread(activeTabId)
        }
        threadState.addActiveThreadContextAttachment(
            ComposerReferenceHelpers.contextAttachment(for: choice)
        )
        chatInput = ComposerReferenceHelpers.removingTrailingMention(from: chatInput)
        showMentionDropdown = false
        mentionFilter = ""
    }

    private func openNotePicker() {
        withAnimation(Motion.smooth) { mode = .chat }
        ensureActiveTab()
        mentionFilter = ""
        showMentionDropdown = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isChatFocused = true
        }
    }

    private func attachVaultContext() {
        withAnimation(Motion.smooth) { mode = .chat }
        ensureActiveTab()
        threadState.addActiveThreadContextAttachment(ComposerReferenceHelpers.allNotesAttachment)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isChatFocused = true
        }
    }

    private func switchToChatAndOpenNotePicker() {
        withAnimation(Motion.smooth) { mode = .chat }
        ensureActiveTab()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            openNotePicker()
        }
    }

    private func switchToChatAndAttachVault() {
        withAnimation(Motion.smooth) { mode = .chat }
        ensureActiveTab()
        attachVaultContext()
    }

    private func handleEscape() {
        if mode == .chat {
            if threadState.paletteIsStreaming {
                cancelStream()
                return
            }
            withAnimation(Motion.smooth) { mode = .search }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                isSearchFocused = true
            }
        } else {
            dismiss()
        }
    }

    private func iconForContextAttachment(_ attachment: ContextAttachment) -> String {
        switch attachment.kind {
        case .note: "doc.text"
        case .chat: "bubble.left.and.bubble.right"
        case .allNotes: "books.vertical"
        }
    }

    private func executeSelected() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !hasManuallyNavigated {
            submitChat(trimmed)
            return
        }
        guard !filteredResults.isEmpty, selectedIndex < filteredResults.count else {
            if !trimmed.isEmpty { submitChat(trimmed) }
            return
        }
        filteredResults[selectedIndex].action()
    }


    // MARK: - Palette UI Components

    private var sparklesIcon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(hue: 0.75, saturation: 0.5, brightness: 0.9),
                        Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                        Color(hue: 0.05, saturation: 0.5, brightness: 0.95),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func paletteChip(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .assistantInsetChrome(theme: theme, cornerRadius: 16)
    }

    // MARK: - Helpers

    private var pageIndex: [String: SDPage] {
        Dictionary(allPages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "1d ago" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }

    private static let categoryOrder = ["Think", "Create", "Navigate", "Tools"]

    private func makeCommands() -> [LandingCommandItem] {
        [
            LandingCommandItem(id: "new-note", label: "New Note", icon: "doc.badge.plus", category: "Create", badge: "\u{2318}N") {
                dismiss()
                Task { if let id = await vaultSync.createPage(title: "New Note") { NoteWindowManager.shared.open(pageId: id) } }
            },
            LandingCommandItem(id: "recent-chats", label: "Open Recent Chats", icon: "clock.arrow.circlepath", category: "Navigate") {
                ui.showChatSidebar = true
                dismiss()
            },
            LandingCommandItem(id: "nav-home", label: "Go Home", icon: "house", category: "Navigate", badge: "\u{2318}1") {
                ui.setActivePanel(.home)
                ui.homeTab = .home
                if let w = NSApp.windows.first(where: { $0.title == "Epistemos" }) { w.makeKeyAndOrderFront(nil) }
                dismiss()
            },
            LandingCommandItem(id: "nav-notes", label: "Open Notes", icon: "note.text", category: "Navigate", badge: "\u{2318}2") {
                UtilityWindowManager.shared.show(.notes); dismiss()
            },
            LandingCommandItem(id: "open-graph", label: "Knowledge Graph", icon: "point.3.connected.trianglepath.dotted", category: "Navigate", badge: "\u{2318}G") {
                HologramController.shared.show(); dismiss()
            },
            LandingCommandItem(id: "nav-settings", label: "Open Settings", icon: "gearshape", category: "Navigate", badge: "\u{2318}S") {
                UtilityWindowManager.shared.show(.settings); dismiss()
            },
            LandingCommandItem(id: "rebuild-graph", label: "Rebuild Graph", icon: "arrow.triangle.2.circlepath", category: "Tools") { [self] in
                dismiss()
                if let ctx = AppBootstrap.shared?.modelContainer.mainContext {
                    graphState.refreshStructuralData(context: ctx); ui.showToast("Graph rebuilt", type: .success)
                }
            },
            LandingCommandItem(id: "import-markdown", label: "Import Markdown", icon: "arrow.down.doc", category: "Tools") { [self] in
                dismiss()
                guard let vaultURL = vaultSync.vaultURL else {
                    ui.showToast("No vault attached \u{2014} set a vault folder in Settings first", type: .warning); return
                }
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true; panel.allowedContentTypes = [.plainText]
                panel.begin { response in
                    guard response == .OK else { return }
                    let urls = panel.urls
                    Task { @MainActor in
                        let count = await VaultImportFileCopier.copy(urls: urls, to: vaultURL)
                        if count > 0 { _ = await vaultSync.syncFromVault(); ui.showToast("Imported \(count) file(s)", type: .success) }
                    }
                }
            },
            LandingCommandItem(id: "open-appearance", label: "Open Appearance Settings", icon: "paintpalette", category: "Tools") {
                UtilityWindowManager.shared.show(.settings)
                dismiss()
            },
        ]
    }
}

enum VaultImportFileCopier {
    nonisolated static func copy(urls: [URL], to destinationDirectory: URL) async -> Int {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            var count = 0

            for url in urls {
                do {
                    try fileManager.copyItem(
                        at: url,
                        to: destinationDirectory.appendingPathComponent(url.lastPathComponent)
                    )
                    count += 1
                } catch {
                    Log.app.error("Import failed for \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            return count
        }.value
    }
}

// MARK: - Palette Chat Bubble

private struct PaletteChatBubble: View {
    let message: AssistantMessage
    let theme: EpistemosTheme

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
                    sources: AssistantSourceReference.extract(from: message.content),
                    theme: theme,
                    compact: true
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Spotlight Row

private struct SpotlightRow: View {
    enum Style {
        case elevated
        case plain
    }

    let command: LandingCommandItem
    let isSelected: Bool
    let theme: EpistemosTheme
    let style: Style
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(command.label)
                        .font(.system(size: 13, weight: style == .plain && (isSelected || isHovered) ? .medium : .regular))
                        .foregroundStyle(labelColor)
                        .lineLimit(1)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(subtitleColor)
                            .lineLimit(1)
                    }

                    if let snippet = command.snippet {
                        Text(snippet)
                            .font(.system(size: 11))
                            .foregroundStyle(snippetColor)
                            .lineLimit(2)
                            .padding(.top, 1)
                    }
                }

                Spacer()

                if let badge = command.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(style == .plain ? badgeColor : (isSelected ? theme.accent : theme.textTertiary.opacity(0.6)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            if isSelected || isHovered {
                Capsule()
                    .fill((isSelected ? theme.accent : theme.textSecondary).opacity(isSelected ? 0.9 : 0.45))
                    .frame(width: 2, height: 22)
            }
        }
        .animation(Motion.quick, value: isSelected)
        .animation(Motion.micro, value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var iconColor: Color {
        switch style {
        case .elevated:
            isSelected ? theme.accent : theme.textSecondary
        case .plain:
            isSelected || isHovered ? theme.accent : theme.textSecondary
        }
    }

    private var labelColor: Color {
        switch style {
        case .elevated:
            theme.foreground
        case .plain:
            isSelected || isHovered ? theme.foreground : theme.textSecondary
        }
    }

    private var subtitleColor: Color {
        switch style {
        case .elevated:
            theme.textTertiary
        case .plain:
            isSelected || isHovered ? theme.textTertiary : theme.textTertiary.opacity(0.8)
        }
    }

    private var snippetColor: Color {
        switch style {
        case .elevated:
            theme.textSecondary.opacity(0.7)
        case .plain:
            theme.textSecondary.opacity(isSelected || isHovered ? 0.72 : 0.62)
        }
    }

    private var badgeColor: Color {
        isSelected || isHovered ? theme.accent : theme.textTertiary.opacity(0.62)
    }
}
