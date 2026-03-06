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

struct CommandPaletteOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference
    @Environment(GraphState.self) private var graphState
    @Environment(QueryEngine.self) private var queryEngine
    @Environment(DailyBriefState.self) private var dailyBrief
    @Environment(ThreadState.self) private var threadState
    @Environment(TriageService.self) private var triage
    @Environment(LLMService.self) private var llmService
    @Environment(ResearchState.self) private var researchState
    @Environment(EventBus.self) private var eventBus
    @Environment(\.modelContext) private var modelContext

    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]
    @Query(sort: \SDChat.updatedAt, order: .reverse) private var allChats: [SDChat]

    // MARK: - Search State

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var hasManuallyNavigated = false
    @State private var searchHighlightTask: Task<Void, Never>?
    @State private var cachedSearchResults: [LandingCommandItem] = []
    @State private var ftsDebounceTask: Task<Void, Never>?
    @State private var appeared = false
    @FocusState private var isSearchFocused: Bool
    @State private var retractNow = false
    @State private var isTypewriterVisible = true
    @State private var animationPhase: AnimationPhase = .squished

    private enum AnimationPhase {
        case squished
        case revealing
        case revealed
    }

    // MARK: - Chat State

    @State private var mode: PaletteMode = .search
    @State private var activeTabId: String?
    @State private var streamTask: Task<Void, Never>?
    @State private var chatInput = ""
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    @State private var paletteChatMode: NoteChatMode = {
        NoteChatMode(rawValue: UserDefaults.standard.string(forKey: "paletteChatMode") ?? "") ?? .auto
    }()
    @State private var paletteOverrideProvider: LLMProviderType? = {
        LLMProviderType(rawValue: UserDefaults.standard.string(forKey: "paletteProvider") ?? "")
    }()
    @FocusState private var isChatFocused: Bool

    private var theme: EpistemosTheme { ui.theme }

    private var showResults: Bool { !searchText.isEmpty }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            ZStack {
                if mode == .search {
                    if showResults {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(theme.border.opacity(0.3))
                                .frame(height: 0.5)

                            resultsSection
                        }
                        .transition(.opacity.combined(with: .blurReplace))
                    }
                } else {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(theme.border.opacity(0.3))
                            .frame(height: 0.5)

                        chatTabBar

                        Rectangle()
                            .fill(theme.border.opacity(0.2))
                            .frame(height: 0.5)

                        chatSection
                        chatInputBar
                    }
                    .transition(.opacity.combined(with: .blurReplace))
                }
            }
            .animation(Motion.smooth, value: mode)
        }
        .frame(width: 640)
        .frame(maxHeight: mode == .chat ? .infinity : nil)
        .fixedSize(horizontal: false, vertical: mode == .search)
        .background {
            ZStack {
                if theme.isDark {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.background.opacity(0.55))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.glassBg)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                // Inner top highlight
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(theme.isDark ? 0.15 : 0.5),
                                .white.opacity(0),
                            ],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.border.opacity(theme.isDark ? 0.4 : 0.25), lineWidth: 1)
        }
        // Tighter, closer shadow — less dramatic
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(theme.isDark ? 0.15 : 0.06), radius: 6, x: 0, y: 2)
        .shadow(color: .black.opacity(theme.isDark ? 0.22 : 0.08), radius: 12, x: 0, y: 4)
        // Squish-then-reveal animation (video game UI style)
        .scaleEffect(
            x: animationPhase == .squished ? 0.85 : (animationPhase == .revealing ? 1.02 : 1.0),
            y: animationPhase == .squished ? 0.75 : (animationPhase == .revealing ? 1.05 : 1.0)
        )
        .opacity(animationPhase == .squished ? 0 : 1)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .animation(Motion.smooth, value: showResults)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: animationPhase)
        .onAppear {
            // Start squished, then animate through phases
            animationPhase = .squished
            Task { @MainActor in
                // Phase 1: Hold squished briefly
                try? await Task.sleep(for: .milliseconds(30))
                animationPhase = .revealing
                // Phase 2: Overshoot settle
                try? await Task.sleep(for: .milliseconds(180))
                animationPhase = .revealed
            }
            // Aggressive focus handling — multiple attempts with increasing delays
            isSearchFocused = true
            Task { @MainActor in
                for delayMs in [50, 100, 200, 350] {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                    if !isSearchFocused { isSearchFocused = true }
                    // Also try to claim first responder through window
                    NotificationCenter.default.post(name: .commandPaletteClaimFocus, object: nil)
                }
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteDidHide)) { _ in
            isSearchFocused = false
            isChatFocused = false
            retractNow = false
            isTypewriterVisible = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            if mode == .chat {
                Button {
                    withAnimation(Motion.smooth) { mode = .search }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        isSearchFocused = true
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(theme.muted.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Provider badge
                HStack(spacing: 4) {
                    Image(systemName: paletteChatMode == .auto ? "sparkles" : (paletteOverrideProvider?.iconName ?? inference.apiProvider.iconName))
                        .font(.system(size: 10, weight: .medium))
                    Text(paletteChatMode == .auto ? "Auto" : (paletteOverrideProvider?.displayName ?? inference.apiProvider.displayName))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.muted.opacity(0.4), in: Capsule())

                if threadState.paletteIsStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        sparklesIcon

                        // Input container with guaranteed tappable area
                        ZStack(alignment: .leading) {
                            // Invisible background to ensure full area is tappable
                            Color.clear
                                .frame(minWidth: 200, maxWidth: .infinity, minHeight: 30)
                            
                            // TextField always present and tappable
                            TextField("", text: $searchText)
                                .font(.custom("RetroGaming", size: 16))
                                .foregroundStyle(theme.foreground)
                                .textFieldStyle(.plain)
                                .focused($isSearchFocused)
                                .onSubmit { executeSelected() }
                            
                            // Placeholder hint (visible when empty and greeting hidden)
                            if searchText.isEmpty && !isTypewriterVisible {
                                Text("Search or ask anything…")
                                    .font(.custom("RetroGaming", size: 16))
                                    .foregroundStyle(theme.textTertiary)
                                    .allowsHitTesting(false)
                            }
                            
                            // Greeting overlays the field but doesn't block touches
                            if isTypewriterVisible && searchText.isEmpty {
                                LiquidGreeting(
                                    compact: true,
                                    retractNow: $retractNow,
                                    onRetractComplete: {
                                        guard !searchText.isEmpty else { return }
                                        withAnimation(Motion.quick) {
                                            isTypewriterVisible = false
                                        }
                                    }
                                )
                                .transition(.opacity)
                                .allowsHitTesting(false) // Clicks pass through to TextField
                                .fixedSize() // Prevent greeting from expanding ZStack
                            }
                        }
                        .frame(minWidth: 200, maxWidth: .infinity, minHeight: 30)
                        .contentShape(Rectangle()) // Ensure entire area is tappable

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                cachedSearchResults = []
                                selectedIndex = 0
                                graphState.searchHighlight("")
                                graphState.setSearchActive(false)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                            .animation(Motion.quick, value: searchText.isEmpty)
                        }
                    }
                    .frame(height: 30)
                    .onChange(of: searchText) { oldValue, newValue in
                        if oldValue.isEmpty && !newValue.isEmpty && isTypewriterVisible {
                            retractNow = true
                        }
                        if newValue.isEmpty {
                            retractNow = false
                            if !isTypewriterVisible {
                                withAnimation(Motion.smooth) {
                                    isTypewriterVisible = true
                                }
                            }
                        }
                    }

                    if isTypewriterVisible && searchText.isEmpty {
                        HStack(spacing: 8) {
                            paletteChip(label: "Open Graph", icon: "network") {
                                CommandPaletteWindowController.shared.hide()
                                HologramController.shared.show()
                            }
                            paletteChip(label: "Open Notes", icon: "note.text") {
                                CommandPaletteWindowController.shared.hide()
                                UtilityWindowManager.shared.show(.notes)
                            }
                            paletteChip(label: "New Note", icon: "doc.badge.plus") {
                                CommandPaletteWindowController.shared.hide()
                                Task { @MainActor in
                                    if let pageId = await vaultSync.createPage(title: "Untitled") {
                                        NoteWindowManager.shared.open(pageId: pageId)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .blurReplace))
                    }

                    HStack(spacing: 4) {
                        Button {
                            if chat.isResearchMode { chat.disableResearchMode() } else { chat.enableResearchMode() }
                        } label: {
                            Image(systemName: chat.isResearchMode ? "flask.fill" : "flask")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(chat.isResearchMode ? theme.accent : theme.textTertiary)
                                .frame(width: 24, height: 24)
                                .background(chat.isResearchMode ? theme.accent.opacity(0.15) : .clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(chat.isResearchMode ? "Research Mode: ON (full pipeline)" : "Research Mode: OFF (direct chat)")

                        Button {
                            chat.isIncognito.toggle()
                        } label: {
                            Image(systemName: chat.isIncognito ? "eye.slash.fill" : "eye.slash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(chat.isIncognito ? .orange : theme.textTertiary)
                                .frame(width: 24, height: 24)
                                .background(chat.isIncognito ? Color.orange.opacity(0.15) : .clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(chat.isIncognito ? "Incognito: ON (not saved)" : "Incognito: OFF")

                        Spacer()

                        Text("\u{2325}Space")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.textTertiary.opacity(0.5))
                    }
                    .padding(.top, 6)
                }
                .animation(Motion.smooth, value: isTypewriterVisible)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    searchResultsView
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
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
                        theme: theme
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
        let searchCategories = ["Notes", "Body Match", "Block Match", "Graph"]
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

    // MARK: - Mode / Provider Picker

    private var paletteModeMenu: some View {
        Menu {
            Button {
                paletteChatMode = .auto
                paletteOverrideProvider = nil
                UserDefaults.standard.set("auto", forKey: "paletteChatMode")
            } label: {
                Label("Auto (Apple AI + Cloud)", systemImage: "sparkles")
            }

            Button {
                paletteChatMode = .cloudOnly
                paletteOverrideProvider = nil
                UserDefaults.standard.set("cloudOnly", forKey: "paletteChatMode")
            } label: {
                Label("Cloud Only", systemImage: "cloud")
            }

            Divider()

            ForEach(LLMProviderType.allCases.filter({ $0 != .appleIntelligence }), id: \.self) { provider in
                Button {
                    paletteChatMode = .provider
                    paletteOverrideProvider = provider
                    UserDefaults.standard.set("provider", forKey: "paletteChatMode")
                    UserDefaults.standard.set(provider.rawValue, forKey: "paletteProvider")
                } label: {
                    Label(provider.displayName, systemImage: provider.iconName)
                }
            }
        } label: {
            Image(systemName: paletteChatMode == .auto ? "sparkles" : (paletteOverrideProvider?.iconName ?? inference.apiProvider.iconName))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(paletteChatMode == .auto ? theme.textTertiary : theme.accent)
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(paletteChatMode == .auto ? "Auto routing" : (paletteOverrideProvider?.displayName ?? "Cloud"))
    }

    private var chatTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(paletteThreads) { thread in
                    Button {
                        withAnimation(Motion.quick) { activeTabId = thread.id }
                    } label: {
                        Text(thread.label)
                            .font(.system(size: 11, weight: activeTabId == thread.id ? .semibold : .regular))
                            .foregroundStyle(activeTabId == thread.id ? theme.accent : theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background {
                        if activeTabId == thread.id {
                            Capsule().fill(theme.accent.opacity(0.12))
                        }
                    }
                }

                Button {
                    let newId = threadState.createThread(type: "palette", label: "Chat \(paletteThreads.count + 1)")
                    withAnimation(Motion.quick) { activeTabId = newId }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
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
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: activeThread?.messages.count) { _, _ in
                withAnimation(Motion.quick) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: threadState.paletteStreamingText) { _, _ in
                let now = ContinuousClock.now
                guard now - lastScrollTime > .milliseconds(250) else { return }
                lastScrollTime = now
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            // Note context indicator
            if let page = activePage() {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 8))
                    Text("Referencing: \(page.title.isEmpty ? "Untitled" : page.title)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(theme.accent.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            HStack(spacing: 8) {
                // Model/API picker
                paletteModeMenu

                TextField("Ask anything\u{2026}", text: $chatInput)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.foreground)
                    .focused($isChatFocused)
                    .onSubmit { sendChatMessage() }

                if threadState.paletteIsStreaming {
                    Button {
                        cancelStream()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendChatMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? theme.mutedForeground.opacity(0.35)
                                    : theme.accent
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
                // Build context from active note + vault
                var contextParts: [String] = []
                let page = activePage()

                if let page {
                    let body = page.loadBody()
                    if !body.isEmpty {
                        contextParts.append("## Active Note: \(page.title)\nTags: [\(page.tags.joined(separator: ", "))]\n\(String(body.prefix(2000)))")
                    }
                }

                let vaultSnippets = searchVault(query: trimmed)
                if !vaultSnippets.isEmpty {
                    let snippetText = vaultSnippets.map { "- **\($0.title)**: \($0.snippet)" }.joined(separator: "\n")
                    contextParts.append("## Related Notes from Vault\n\(snippetText)")
                }

                if let manifest = AppBootstrap.shared?.ambientManifest {
                    contextParts.append(manifest.asManifestOnly())
                }

                // Build folder list for move actions
                var folderNames: [String] = []
                let folderDescriptor = FetchDescriptor<SDFolder>(sortBy: [SortDescriptor(\.sortOrder)])
                if let folders = try? modelContext.fetch(folderDescriptor) {
                    folderNames = folders.map(\.name)
                }

                // Multi-turn conversation history
                let activeMessages = activeThread?.messages ?? []
                let hasHistory = activeMessages.count > 1
                let conversationNote = hasHistory
                    ? " The user's message includes recent conversation history formatted as 'User:' and 'Assistant:' turns. Respond only to the latest User message, using prior turns for context."
                    : ""

                // Context-aware system prompt
                let systemPrompt: String
                if contextParts.isEmpty {
                    systemPrompt = "You are Epistemos, a research assistant. Answer clearly and helpfully. Use markdown formatting.\(conversationNote)"
                } else {
                    let actionInstructions = page != nil ? """

                    ## Vault Actions
                    When the user asks to modify a note (tag, move, rename, etc.), include an action marker at the END of your response:
                    - To add tags: `[ACTION:TAG tag1, tag2, tag3]`
                    - To move to folder: `[ACTION:MOVE FolderName]`
                    - To create a new note: `[ACTION:CREATE Title of New Note]`
                    Available folders: [\(folderNames.joined(separator: ", "))]
                    Only include an action marker if the user explicitly asks to modify something. Otherwise just answer normally.
                    """ : ""

                    systemPrompt = """
                    You are Epistemos, a research assistant with access to the user's notes vault. \
                    Reference the user's notes naturally when relevant — quote specific content, \
                    connect ideas across notes, or point out things the user might not have noticed. \
                    Answer clearly and helpfully. Use markdown formatting.\(conversationNote)\(actionInstructions)

                    \(contextParts.joined(separator: "\n\n"))
                    """
                }

                // Build conversation-aware prompt with thread history
                let conversationPrompt: String
                if activeMessages.count > 1 {
                    let history = activeMessages.dropLast().suffix(10)
                    let historyText = history.map { msg in
                        msg.role == .user ? "User: \(msg.content)" : "Assistant: \(msg.content)"
                    }.joined(separator: "\n\n")
                    conversationPrompt = "\(historyText)\n\nUser: \(trimmed)"
                } else {
                    conversationPrompt = trimmed
                }

                let contentLength = conversationPrompt.count + contextParts.joined().count
                var accumulated = ""

                let stream: AsyncThrowingStream<String, Error>
                switch paletteChatMode {
                case .auto:
                    stream = triage.streamGeneral(
                        prompt: conversationPrompt,
                        systemPrompt: systemPrompt,
                        operation: .chatResponse(query: trimmed),
                        contentLength: contentLength
                    )
                case .cloudOnly:
                    stream = llmService.stream(prompt: conversationPrompt, systemPrompt: systemPrompt)
                case .provider:
                    let provider = paletteOverrideProvider ?? inference.apiProvider
                    stream = llmService.stream(prompt: conversationPrompt, systemPrompt: systemPrompt, provider: provider)
                }

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
                if let page {
                    final = executeActions(in: final, page: page)
                }

                threadState.addThreadMessage(
                    AssistantMessage(role: .assistant, content: final.isEmpty ? "No response." : final),
                    threadId: tid
                )

                // Auto-extract citations
                saveCitations(from: final)
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

    private func activePage() -> SDPage? {
        guard let pageId = notesUI.activePageId else { return nil }
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Vault Search

    private func searchVault(query: String) -> [(title: String, snippet: String)] {
        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        guard let pages = try? modelContext.fetch(descriptor) else { return [] }

        let terms = query.lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 }
        guard !terms.isEmpty else { return [] }

        let activeId = notesUI.activePageId

        // Pass 1: title match (cheap)
        var matches = pages.filter { page in
            guard page.id != activeId else { return false }
            let title = page.title.lowercased()
            return terms.contains { title.contains($0) }
        }

        // Pass 2: body match for a small subset if few title hits
        if matches.count < 3 {
            let titleIds = Set(matches.map(\.id))
            let candidates = pages.prefix(30).filter {
                $0.id != activeId && !titleIds.contains($0.id)
            }
            let bodyMatches = candidates.filter { page in
                let body = page.loadBody().lowercased()
                return terms.contains { body.contains($0) }
            }
            matches.append(contentsOf: bodyMatches)
        }

        return Array(matches
            .prefix(3)
            .map { (title: $0.title, snippet: String($0.loadBody().prefix(300))) })
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

    // MARK: - Citation Extraction

    private func saveCitations(from text: String) {
        let papers = CitationExtractor.extract(from: text, source: "palette")
        guard !papers.isEmpty else { return }
        for paper in papers {
            researchState.addSavedPaper(paper)
        }
        eventBus.emitToast("Added \(papers.count) source\(papers.count == 1 ? "" : "s") to library", type: .info)
    }

    // MARK: - Search Logic

    private func handleSearchChange(_ newText: String) {
        hasManuallyNavigated = false

        if newText.isEmpty {
            searchHighlightTask?.cancel()
            ftsDebounceTask?.cancel()
            cachedSearchResults = []
            selectedIndex = 0
            graphState.searchHighlight("")
            graphState.setSearchActive(false)
            return
        }

        // Structured query mode: route ? prefix through QueryEngine
        if newText.hasPrefix("?") {
            ftsDebounceTask?.cancel()
            searchHighlightTask?.cancel()
            cachedSearchResults = computeStructuredQueryResults(for: newText)
            let askOffset = cachedSearchResults.isEmpty ? 0 : 2
            selectedIndex = askOffset
            return
        }

        // Title search is the guaranteed backbone — always runs first, never excluded.
        // Graph search adds fuzzy/typo-tolerant matches but skips note nodes
        // already covered by title search (avoids duplicate rows).
        let titleItems = computeTitleResults(for: newText, excluding: [])
        let titlePageIds = Set(titleItems.compactMap { item in
            item.id.hasPrefix("title-") ? String(item.id.dropFirst(6)) : nil
        })
        let (graphItems, graphPageIds) = computeGraphResults(for: newText, excludingPageIds: titlePageIds)
        cachedSearchResults = titleItems + graphItems

        ftsDebounceTask?.cancel()
        ftsDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let seenPageIds = titlePageIds.union(graphPageIds)
            let bodyItems = computeBodyResults(for: newText, excluding: seenPageIds)
            let blockItems = computeBlockResults(for: newText, excluding: seenPageIds)
            withAnimation(Motion.quick) {
                cachedSearchResults = titleItems + graphItems + bodyItems + blockItems
            }
        }

        if !cachedSearchResults.isEmpty {
            let askOffset = newText.hasPrefix("/query ") ? 2 : 1
            selectedIndex = askOffset
        } else {
            selectedIndex = 0
        }

        searchHighlightTask?.cancel()
        searchHighlightTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            graphState.searchHighlight(newText)
            graphState.setSearchActive(!newText.isEmpty)
        }
    }

    // MARK: - Filtered Results

    private var filteredResults: [LandingCommandItem] {
        var base: [LandingCommandItem] = []

        if searchText.hasPrefix("?") || searchText.hasPrefix("/query ") {
            let queryText = searchText.hasPrefix("?")
                ? String(searchText.dropFirst()).trimmingCharacters(in: .whitespaces)
                : String(searchText.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if !queryText.isEmpty {
                let q = queryText
                base.append(
                    LandingCommandItem(
                        id: "graph-query", label: "Graph Query: \"\(q)\"",
                        icon: "sparkle.magnifyingglass", category: "Graph"
                    ) { [self] in executeGraphQuery(q) })
            }
        }

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

    private func computeGraphResults(for query: String, excludingPageIds: Set<String> = []) -> (items: [LandingCommandItem], seenPageIds: Set<String>) {
        guard !query.isEmpty else { return ([], []) }
        var items: [LandingCommandItem] = []
        var seenPageIds = Set<String>()

        let index = pageIndex
        if graphState.isLoaded {
            let hits = graphState.rustSearch(query: query, limit: 20)
            for hit in hits {
                let node = hit.node
                let icon = node.type == .note ? "doc.text" : node.type.icon
                let category = node.type == .note ? "Notes" : node.type.displayName
                let nodeId = node.id
                let sourceId = node.sourceId
                if node.type == .note, let sid = sourceId {
                    seenPageIds.insert(sid)
                    // Skip note nodes already covered by title search
                    if excludingPageIds.contains(sid) { continue }
                }

                var label = node.label
                var subtitle: String?
                if node.type == .note, let sid = sourceId, let page = index[sid] {
                    if !page.emoji.isEmpty { label = "\(page.emoji) \(node.label)" }
                    let parts = [
                        "\(page.wordCount)w",
                        page.tags.prefix(2).joined(separator: ", "),
                        relativeDate(page.updatedAt),
                    ].filter { !$0.isEmpty }
                    subtitle = parts.joined(separator: " \u{00B7} ")
                }

                var contextActions: [LandingCommandItem.ContextAction] = []
                if node.type == .note, let pid = sourceId {
                    contextActions.append(.init(label: "Open in Notes", icon: "doc.text") { [self] in
                        dismiss()
                        NoteWindowManager.shared.open(pageId: pid)
                    })
                    contextActions.append(.init(label: "Reveal in Graph", icon: "point.3.connected.trianglepath.dotted") { [self] in
                        dismiss()
                        HologramController.shared.show()
                        graphState.selectNode(nodeId)
                        graphState.mode = .page(nodeId: nodeId)
                        graphState.focusOnNode(nodeId, depth: 2)
                        graphState.requestRecommit()
                    })
                } else {
                    contextActions.append(.init(label: "Reveal in Graph", icon: "point.3.connected.trianglepath.dotted") { [self] in
                        dismiss()
                        HologramController.shared.show()
                        graphState.selectNode(nodeId)
                        graphState.pendingCenterNodeId = nodeId
                    })
                }

                items.append(
                    LandingCommandItem(
                        id: "graph-\(nodeId)", label: label, icon: icon,
                        category: category, subtitle: subtitle,
                        contextActions: contextActions
                    ) { [self] in
                        dismiss()
                        if node.type == .note, let pageId = sourceId {
                            NoteWindowManager.shared.open(pageId: pageId)
                        } else {
                            HologramController.shared.show()
                            graphState.selectNode(nodeId)
                            graphState.pendingCenterNodeId = nodeId
                        }
                    })
            }
        }

        return (items, seenPageIds)
    }

    private func computeTitleResults(for query: String, excluding graphPageIds: Set<String>) -> [LandingCommandItem] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()

        // Relevance scoring: exact > prefix > contains > tag match.
        // Within same tier, shorter titles rank higher (closer match).
        let scored: [(page: SDPage, score: Int)] = allPages
            .filter { !graphPageIds.contains($0.id) }
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
                let contextActions: [LandingCommandItem.ContextAction] = [
                    .init(label: "Open in Notes", icon: "doc.text") { [self] in
                        dismiss()
                        NoteWindowManager.shared.open(pageId: pageId)
                    },
                    .init(label: "Reveal in Graph", icon: "point.3.connected.trianglepath.dotted") { [self] in
                        dismiss()
                        if let node = graphState.store.node(bySourceId: pageId, type: .note) {
                            HologramController.shared.show()
                            graphState.selectNode(node.id)
                            graphState.mode = .page(nodeId: node.id)
                            graphState.focusOnNode(node.id, depth: 2)
                            graphState.requestRecommit()
                        }
                    },
                ]
                return LandingCommandItem(
                    id: "title-\(pageId)", label: label, icon: "doc.text",
                    category: "Notes", subtitle: subtitle,
                    contextActions: contextActions
                ) { [self] in
                    // Navigate the graph to this note's node (for mini graph companion).
                    if let node = graphState.store.node(bySourceId: pageId, type: .note) {
                        graphState.selectNode(node.id)
                        graphState.focusOnNode(node.id, depth: 2)
                        graphState.requestRecommit()
                    }
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                }
            }
    }

    private func computeBodyResults(for query: String, excluding seenPageIds: Set<String>) -> [LandingCommandItem] {
        guard !query.isEmpty else { return [] }
        var items: [LandingCommandItem] = []
        let index = pageIndex

        let bodyHits = vaultSync.searchFull(query: query, limit: 30)
        for hit in bodyHits where !seenPageIds.contains(hit.pageId) {
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

            let contextActions: [LandingCommandItem.ContextAction] = [
                .init(label: "Open in Notes", icon: "doc.text") { [self] in
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                },
                .init(label: "Reveal in Graph", icon: "point.3.connected.trianglepath.dotted") { [self] in
                    dismiss()
                    if let node = graphState.store.node(bySourceId: pageId, type: .note) {
                        HologramController.shared.show()
                        graphState.selectNode(node.id)
                        graphState.mode = .page(nodeId: node.id)
                        graphState.focusOnNode(node.id, depth: 2)
                        graphState.requestRecommit()
                    }
                },
            ]
            items.append(
                LandingCommandItem(
                    id: "fts-\(pageId)", label: label, icon: "doc.text.magnifyingglass",
                    category: "Body Match", subtitle: subtitle, snippet: snippet,
                    contextActions: contextActions
                ) { [self] in
                    // Navigate the graph to this note's node (for mini graph companion).
                    if let node = graphState.store.node(bySourceId: pageId, type: .note) {
                        graphState.selectNode(node.id)
                        graphState.focusOnNode(node.id, depth: 2)
                        graphState.requestRecommit()
                    }
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                })
        }

        return items
    }

    private func computeBlockResults(for query: String, excluding seenPageIds: Set<String>) -> [LandingCommandItem] {
        guard query.count >= 2,
              let svc = vaultSync.searchService else { return [] }

        let hits: [BlockSearchResult]
        do { hits = try svc.searchBlocks(query: query, limit: 10) }
        catch { return [] }

        let index = pageIndex
        var items: [LandingCommandItem] = []

        for hit in hits {
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

    private func computeStructuredQueryResults(for input: String) -> [LandingCommandItem] {
        queryEngine.execute(query: input)
        guard let result = queryEngine.currentResult else { return [] }

        let index = pageIndex
        var items: [LandingCommandItem] = []

        for node in result.nodes.prefix(30) {
            let nodeId = node.id
            let sourceId = node.sourceId
            let nodeType = node.type

            var label = node.label
            var subtitle = nodeType.displayName
            let icon = nodeType.icon

            if nodeType == .note, let sid = sourceId, let page = index[sid] {
                if !page.emoji.isEmpty { label = "\(page.emoji) \(label)" }
                let parts = [
                    "\(page.wordCount)w",
                    page.tags.prefix(2).joined(separator: ", "),
                    relativeDate(page.updatedAt),
                ].filter { !$0.isEmpty }
                subtitle = parts.joined(separator: " \u{00B7} ")
            }

            if let snippet = node.snippet {
                subtitle = snippet
            }

            var contextActions: [LandingCommandItem.ContextAction] = []
            if nodeType == .note, let pid = sourceId {
                contextActions.append(.init(label: "Open in Notes", icon: "doc.text") { [self] in
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pid)
                })
            }
            contextActions.append(.init(label: "Reveal in Graph", icon: "point.3.connected.trianglepath.dotted") { [self] in
                dismiss()
                HologramController.shared.show()
                graphState.selectNode(nodeId)
                if nodeType == .note, sourceId != nil {
                    graphState.mode = .page(nodeId: nodeId)
                    graphState.focusOnNode(nodeId, depth: 2)
                    graphState.requestRecommit()
                } else {
                    graphState.pendingCenterNodeId = nodeId
                }
            })

            items.append(
                LandingCommandItem(
                    id: "sq-\(nodeId)", label: label, icon: icon,
                    category: "Query Result", subtitle: subtitle,
                    contextActions: contextActions
                ) { [self] in
                    dismiss()
                    if nodeType == .note, let pageId = sourceId {
                        NoteWindowManager.shared.open(pageId: pageId)
                    } else {
                        HologramController.shared.show()
                        graphState.selectNode(nodeId)
                        graphState.pendingCenterNodeId = nodeId
                    }
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
        searchHighlightTask?.cancel()
        searchHighlightTask = nil
        mode = .search
        chatInput = ""
        isSearchFocused = false
        searchText = ""
        selectedIndex = 0
        hasManuallyNavigated = false
        cachedSearchResults = []
        graphState.searchHighlight("")
        graphState.setSearchActive(false)
        CommandPaletteWindowController.shared.hide()
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

    private func executeGraphQuery(_ query: String) {
        queryEngine.execute(query: query)
        dismiss()
        HologramController.shared.show()
    }

    private func captureIdea(type: NoteIdea.IdeaType) {
        let content = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = content.isEmpty
            ? (type == .idea ? "New Idea" : "Brain Dump")
            : String(content.prefix(60))
        let emoji = type == .idea ? "\u{1F4A1}" : "\u{1F9E0}"
        dismiss()
        Task {
            if let pageId = await vaultSync.createPage(title: title, body: content, emoji: emoji) {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
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
            .padding(.vertical, 7)
            .background {
                Capsule().fill(theme.foreground.opacity(0.06))
            }
        }
        .buttonStyle(.plain)
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
            LandingCommandItem(id: "daily-brief", label: "Daily Brief", icon: "newspaper.fill", category: "Think") { [self] in
                dismiss(); ui.setActivePanel(.home)
                let prompt = DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: Array(allChats))
                dailyBrief.requestDailyBrief(prompt: prompt)
            },
            LandingCommandItem(id: "vault-briefing", label: "Vault Briefing", icon: "book.pages", category: "Think") { [self] in
                dismiss()
                chat.startNewChat()
                ui.setActivePanel(.home)
                AppBootstrap.shared?.requestVaultBriefing(chatState: chat)
            },
            LandingCommandItem(id: "breathe", label: "Breathe Now", icon: "wind", category: "Think") {
                ui.startBreathe(); dismiss()
            },
            LandingCommandItem(id: "new-note", label: "New Note", icon: "doc.badge.plus", category: "Create", badge: "\u{2318}N") {
                dismiss()
                Task { if let id = await vaultSync.createPage(title: "New Note") { NoteWindowManager.shared.open(pageId: id) } }
            },
            LandingCommandItem(id: "quick-idea", label: "Quick Idea", icon: "lightbulb", category: "Create", badge: "\u{2318}I") { [self] in
                captureIdea(type: .idea)
            },
            LandingCommandItem(id: "brain-dump", label: "Brain Dump", icon: "brain", category: "Create") { [self] in
                captureIdea(type: .brainDump)
            },
            LandingCommandItem(id: "new-chat", label: "New Chat", icon: "plus.bubble", category: "Create") { [self] in
                dismiss(); chat.startNewChat(); ui.setActivePanel(.home)
            },
            LandingCommandItem(id: "nav-home", label: "Go Home", icon: "house", category: "Navigate", badge: "\u{2318}1") {
                ui.setActivePanel(.home)
                if let w = NSApp.windows.first(where: { $0.title == "Epistemos" }) { w.makeKeyAndOrderFront(nil) }
                dismiss()
            },
            LandingCommandItem(id: "nav-notes", label: "Open Notes", icon: "note.text", category: "Navigate", badge: "\u{2318}2") {
                UtilityWindowManager.shared.show(.notes); dismiss()
            },
            LandingCommandItem(id: "nav-library", label: "Open Library", icon: "books.vertical", category: "Navigate", badge: "\u{2318}3") {
                UtilityWindowManager.shared.show(.library); dismiss()
            },
            LandingCommandItem(id: "open-graph", label: "Knowledge Graph", icon: "point.3.connected.trianglepath.dotted", category: "Navigate", badge: "\u{2318}G") {
                HologramController.shared.show(); dismiss()
            },
            LandingCommandItem(id: "nav-settings", label: "Open Settings", icon: "gearshape", category: "Navigate", badge: "\u{2318},") {
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
                    Task { @MainActor in
                        var count = 0
                        for url in panel.urls {
                            do { try FileManager.default.copyItem(at: url, to: vaultURL.appendingPathComponent(url.lastPathComponent)); count += 1 }
                            catch { Log.app.error("Import failed for \(url.lastPathComponent): \(error.localizedDescription)") }
                        }
                        if count > 0 { _ = await vaultSync.syncFromVault(); ui.showToast("Imported \(count) file(s)", type: .success) }
                    }
                }
            },
            LandingCommandItem(id: "toggle-theme", label: "Toggle Theme", icon: "paintpalette", category: "Tools") {
                ui.cycleTheme(); dismiss()
            },
        ]
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
                    .foregroundStyle(theme.userBubbleText)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                MarkdownTextView(content: message.content, theme: theme)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Spotlight Row

private struct SpotlightRow: View {
    let command: LandingCommandItem
    let isSelected: Bool
    let theme: EpistemosTheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.15) : theme.muted.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: command.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(command.label)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }

                    if let snippet = command.snippet {
                        Text(snippet)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary.opacity(0.7))
                            .lineLimit(2)
                            .padding(.top, 1)
                    }
                }

                Spacer()

                if let badge = command.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? theme.accent : theme.textTertiary.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isSelected ? theme.accent.opacity(0.08) : theme.muted.opacity(0.5))
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.accent.opacity(0.1))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.hoverOverlay)
            }
        }
        .animation(Motion.quick, value: isSelected)
        .animation(Motion.micro, value: isHovered)
        .onHover { isHovered = $0 }
    }
}
