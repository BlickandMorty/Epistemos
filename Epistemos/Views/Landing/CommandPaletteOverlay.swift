import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Command Palette Overlay
// Global Gemini-style command palette — shown from any panel via Cmd+S.
// Fullscreen blur backdrop with centered glass search panel.
// Executes commands, searches vault, submits chat queries.

struct CommandPaletteOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference
    @Environment(GraphState.self) private var graphState
    @Environment(QueryEngine.self) private var queryEngine
    @Environment(DailyBriefState.self) private var dailyBrief

    // Vault search — in-memory title filter from SwiftData @Query
    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]
    @Query(sort: \SDChat.updatedAt, order: .reverse) private var allChats: [SDChat]

    // Search state
    @State private var searchText = ""
    @State private var inlineSelectedIndex = 0
    @State private var hasManuallyNavigated = false
    @State private var searchHighlightTask: Task<Void, Never>?
    @State private var cachedSearchResults: [LandingCommandItem] = []
    @State private var ftsDebounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private var theme: EpistemosTheme { ui.theme }

    // MARK: - Body

    var body: some View {
        searchPanel
            .onAppear {
                // Focus after the transition settles
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.15))
                    isSearchFocused = true
                }
            }
    }

    // MARK: - Search Panel

    private var searchPanel: some View {
        VStack(spacing: 0) {
            promptArea
            toolsRow

            Rectangle()
                .fill(theme.glassBorder)
                .frame(height: 0.5)

            inlineCommandList
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: theme.accent.opacity(0.06), radius: 24, y: 0)
        .shadow(color: .black.opacity(theme.isDark ? 0.25 : 0.06), radius: 8, y: 4)
    }

    // MARK: - Prompt Area

    private var promptArea: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField("Ask anything or type a command...", text: $searchText, axis: .vertical)
                .font(.epBody)
                .foregroundStyle(theme.foreground)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isSearchFocused)
                .onSubmit { executeSelected() }

            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    executeSelected()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help("Send")
                .accessibilityLabel("Send")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Tools Row

    private var toolsRow: some View {
        HStack(spacing: 8) {
            Button {
                handleUpload()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Attach a file")
            .accessibilityLabel("Attach a file")

            // Research mode toggle — oval pill button (can combine with Notes)
            Button {
                withAnimation(Motion.quick) {
                    if chat.isResearchMode {
                        chat.disableResearchMode()
                    } else {
                        chat.enableResearchMode()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: chat.isResearchMode ? "flask.fill" : "flask")
                        .font(.system(size: 10, weight: .medium))
                    Text("Research")
                        .font(.system(size: 11, weight: chat.isResearchMode ? .semibold : .regular))
                }
                .foregroundStyle(chat.isResearchMode ? theme.accent : theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            chat.isResearchMode
                                ? theme.accent.opacity(0.12) : theme.glassTint.opacity(0.5))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            chat.isResearchMode ? theme.accent.opacity(0.3) : theme.glassBorder,
                            lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help(chat.isResearchMode ? "Research Mode On — full pipeline" : "Enable Research Mode")
            .accessibilityLabel(chat.isResearchMode ? "Research mode on" : "Enable research mode")

            // Incognito toggle
            Button {
                withAnimation(Motion.quick) { chat.isIncognito.toggle() }
            } label: {
                Image(systemName: chat.isIncognito ? "eye.slash.fill" : "eye.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(chat.isIncognito ? theme.accent : theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(chat.isIncognito ? "Incognito On" : "Enable Incognito")
            .accessibilityLabel(chat.isIncognito ? "Incognito on" : "Incognito off")

            ProviderDropdown()

            Spacer()

            Text("esc")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(theme.glassTint))
                .onTapGesture { dismiss() }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 8)
    }

    // MARK: - Inline Command List

    /// Combined list: search results + synchronous command filtering.
    /// Search results (Rust FFI + SwiftData) are computed synchronously via cachedSearchResults.
    /// Command filtering is cheap and stays synchronous.
    private var inlineFilteredCommands: [LandingCommandItem] {
        var base: [LandingCommandItem] = []

        // Graph query routing: `?` or `/query` prefix → QueryEngine (cheap string check)
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
                    ) { [self] in
                        executeGraphQuery(q)
                    })
            }
        }

        // Always show "Ask" option when there's text — this is what Enter
        // triggers by default (via hasManuallyNavigated check in executeSelected).
        if !searchText.isEmpty {
            let q = searchText
            base.append(
                LandingCommandItem(
                    id: "ask", label: "Ask: \"\(q)\"", icon: "arrow.up.circle", category: "Chat"
                ) {
                    submitChat(q)
                })
        }

        // Append debounced search results (graph + vault)
        base += cachedSearchResults

        let commands = makeCommands()
        if searchText.isEmpty {
            return base + commands + recentNoteItems
        }
        let q = searchText.lowercased()
        let filtered = commands.filter {
            $0.label.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
        return base + filtered
    }

    /// Computes graph search results instantly (Rust FFI, sub-1ms).
    private func computeGraphResults(for query: String) -> (items: [LandingCommandItem], seenPageIds: Set<String>) {
        guard !query.isEmpty else { return ([], []) }
        var items: [LandingCommandItem] = []
        var seenPageIds = Set<String>()

        // Graph-powered search: Rust FST + 5-tier fuzzy scoring (titles + labels)
        let index = pageIndex
        if graphState.isLoaded {
            let hits = graphState.rustSearch(query: query, limit: 20)
            for hit in hits {
                let node = hit.node
                let icon = node.type == .note ? "doc.text" : node.type.icon
                let category = node.type == .note ? "Notes" : node.type.displayName
                let nodeId = node.id
                let sourceId = node.sourceId
                if node.type == .note, let sid = sourceId { seenPageIds.insert(sid) }

                // Enrich note results with metadata
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

                items.append(
                    LandingCommandItem(
                        id: "graph-\(nodeId)", label: label, icon: icon,
                        category: category, subtitle: subtitle
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

    /// Computes FTS5 body search results (SQLite, debounced to 150ms).
    private func computeBodyResults(for query: String, excluding seenPageIds: Set<String>) -> [LandingCommandItem] {
        guard !query.isEmpty else { return [] }
        var items: [LandingCommandItem] = []
        let index = pageIndex

        let bodyHits = vaultSync.searchFull(query: query, limit: 20)
        for hit in bodyHits where !seenPageIds.contains(hit.pageId) {
            let pageId = hit.pageId
            let snippet = hit.snippet
                .replacingOccurrences(of: "<b>", with: "")
                .replacingOccurrences(of: "</b>", with: "")

            let page = index[pageId]
            let emoji = page?.emoji ?? ""
            let rawTitle = hit.title.isEmpty ? "Untitled" : hit.title
            let label = emoji.isEmpty ? rawTitle : "\(emoji) \(rawTitle)"

            // Enrich with word count + relative date
            var subtitleParts: [String] = []
            if let page {
                subtitleParts.append("\(page.wordCount)w")
                subtitleParts.append(relativeDate(page.updatedAt))
            }
            if !snippet.isEmpty { subtitleParts.append(snippet) }
            let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " \u{00B7} ")

            items.append(
                LandingCommandItem(
                    id: "fts-\(pageId)", label: label, icon: "doc.text.magnifyingglass",
                    category: "Body Match", subtitle: subtitle
                ) { [self] in
                    dismiss()
                    NoteWindowManager.shared.open(pageId: pageId)
                })
        }

        return items
    }

    private var inlineCommandList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if searchText.isEmpty {
                        // Grouped display with section headers
                        groupedCommandsView
                    } else {
                        ForEach(Array(inlineFilteredCommands.enumerated()), id: \.element.id) {
                            index, cmd in
                            LandingCommandRow(command: cmd, isSelected: index == inlineSelectedIndex) {
                                cmd.action()
                            }
                            .id(index)
                            .onTapGesture {
                                inlineSelectedIndex = index
                                cmd.action()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
            .onChange(of: inlineSelectedIndex) { _, newValue in
                withAnimation(Motion.micro) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .onKeyPress(.upArrow) {
            inlineMoveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            inlineMoveSelection(by: 1)
            return .handled
        }
        .onChange(of: searchText) { _, newText in
            // Reset navigation intent — user is still typing
            hasManuallyNavigated = false

            // Clear search results immediately on empty
            if newText.isEmpty {
                searchHighlightTask?.cancel()
                cachedSearchResults = []
                inlineSelectedIndex = 0
                graphState.searchHighlight("")
                return
            }

            // Graph results: instant (Rust FFI, sub-1ms)
            let (graphItems, seenIds) = computeGraphResults(for: newText)
            cachedSearchResults = graphItems

            // FTS5 body search: debounced 150ms (SQLite disk I/O)
            ftsDebounceTask?.cancel()
            ftsDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                let bodyItems = computeBodyResults(for: newText, excluding: seenIds)
                cachedSearchResults = graphItems + bodyItems
            }

            // Default-select the first note/graph result instead of the "Ask" item.
            // The "Ask" item is always at index 0 (or 1 if graph query prefix);
            // jump past it so matching notes get the highlight.
            if !cachedSearchResults.isEmpty {
                // First search result follows the "Ask" item (and optional graph-query item)
                let askOffset = (newText.hasPrefix("?") || newText.hasPrefix("/query ")) ? 2 : 1
                inlineSelectedIndex = askOffset
            } else {
                inlineSelectedIndex = 0
            }

            // Debounce graph highlight FFI call (150ms) — this is visual only
            searchHighlightTask?.cancel()
            searchHighlightTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                graphState.searchHighlight(newText)
            }
        }
    }

    /// Grouped command display with small section headers (shown when idle).
    private var groupedCommandsView: some View {
        let commands = inlineFilteredCommands
        let grouped = Dictionary(grouping: commands) { $0.category }

        return ForEach(Self.categoryOrder, id: \.self) { category in
            if let items = grouped[category], !items.isEmpty {
                // Section header
                Text(category)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, items == grouped[Self.categoryOrder.first!] ? 8 : 16)
                    .padding(.bottom, 4)

                ForEach(items) { cmd in
                    let idx = commands.firstIndex(where: { $0.id == cmd.id }) ?? 0
                    LandingCommandRow(command: cmd, isSelected: idx == inlineSelectedIndex) {
                        cmd.action()
                    }
                    .id(idx)
                    .onTapGesture {
                        inlineSelectedIndex = idx
                        cmd.action()
                    }
                }
            }
        }
    }

    private func inlineMoveSelection(by delta: Int) {
        let count = inlineFilteredCommands.count
        guard count > 0 else { return }
        inlineSelectedIndex = (inlineSelectedIndex + delta + count) % count
        hasManuallyNavigated = true
    }

    // MARK: - Actions

    private func dismiss() {
        isSearchFocused = false
        searchText = ""
        inlineSelectedIndex = 0
        hasManuallyNavigated = false
        searchHighlightTask?.cancel()
        cachedSearchResults = []
        graphState.searchHighlight("")
        CommandPaletteWindowController.shared.hide()
    }

    private func submitChat(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Start a fresh chat — don't append to any existing conversation
        chat.startNewChat()
        chat.submitQuery(trimmed)
        dismiss()
        ui.setActivePanel(.home)
    }

    private func executeSelected() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If user typed text and hit Enter without arrow-navigating,
        // always submit as chat — don't accidentally open a note.
        if !trimmed.isEmpty && !hasManuallyNavigated {
            submitChat(trimmed)
            return
        }

        guard !inlineFilteredCommands.isEmpty, inlineSelectedIndex < inlineFilteredCommands.count
        else {
            if !trimmed.isEmpty { submitChat(trimmed) }
            return
        }
        inlineFilteredCommands[inlineSelectedIndex].action()
    }

    private func executeGraphQuery(_ query: String) {
        queryEngine.execute(query: query)
        dismiss()
        // Open graph overlay to show results in the Query tab
        HologramController.shared.show()
    }

    private func captureIdea(type: NoteIdea.IdeaType) {
        let content = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = content.isEmpty
            ? (type == .idea ? "New Idea" : "Brain Dump")
            : String(content.prefix(60))
        let emoji = type == .idea ? "💡" : "🧠"

        dismiss()
        Task {
            if let pageId = await vaultSync.createPage(title: title, body: content, emoji: emoji) {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    private func handleUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.pdf, .plainText, .png, .jpeg, .json, .commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                searchText = "Analyze this file: \(url.lastPathComponent)"
            }
        }
    }

    // MARK: - Page Index (for enriched search results)

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

    // MARK: - Recent Notes (idle display)

    /// 5 most recently edited notes, shown as quick-open items when palette is idle.
    private var recentNoteItems: [LandingCommandItem] {
        allPages
            .filter { $0.templateId == nil && !$0.isArchived }
            .prefix(5)
            .map { page in
                let emoji = page.emoji.isEmpty ? "" : "\(page.emoji) "
                let title = page.title.isEmpty ? "Untitled" : page.title
                let parts = [
                    "\(page.wordCount)w",
                    page.tags.prefix(2).joined(separator: ", "),
                    relativeDate(page.updatedAt),
                ].filter { !$0.isEmpty }
                let subtitle = parts.joined(separator: " \u{00B7} ")
                let pageId = page.id

                return LandingCommandItem(
                    id: "recent-\(pageId)", label: "\(emoji)\(title)", icon: "doc.text",
                    category: "Recent Notes", subtitle: subtitle
                ) {
                    CommandPaletteWindowController.shared.hide()
                    NoteWindowManager.shared.open(pageId: pageId)
                }
            }
    }

    // MARK: - Commands

    /// Category order for grouped idle display.
    private static let categoryOrder = ["Think", "Create", "Navigate", "Tools", "Recent Notes"]

    private func makeCommands() -> [LandingCommandItem] {
        [
            // ── Think ──
            LandingCommandItem(
                id: "daily-brief", label: "Daily Brief", icon: "newspaper.fill",
                category: "Think"
            ) { [self] in
                dismiss()
                ui.setActivePanel(.home)
                let prompt = DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: Array(allChats))
                dailyBrief.requestDailyBrief(prompt: prompt)
            },
            LandingCommandItem(
                id: "breathe", label: "Breathe Now", icon: "wind",
                category: "Think"
            ) {
                ui.startBreathe()
                dismiss()
            },

            // ── Create ──
            LandingCommandItem(
                id: "new-note", label: "New Note", icon: "doc.badge.plus",
                category: "Create", badge: "\u{2318}N"
            ) {
                dismiss()
                Task {
                    if let pageId = await vaultSync.createPage(title: "New Note") {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            },
            LandingCommandItem(
                id: "quick-idea", label: "Quick Idea", icon: "lightbulb",
                category: "Create", badge: "\u{2318}I"
            ) { [self] in
                captureIdea(type: .idea)
            },
            LandingCommandItem(
                id: "brain-dump", label: "Brain Dump", icon: "brain",
                category: "Create"
            ) { [self] in
                captureIdea(type: .brainDump)
            },
            LandingCommandItem(
                id: "new-chat", label: "New Chat", icon: "plus.bubble",
                category: "Create"
            ) { [self] in
                dismiss()
                chat.startNewChat()
                ui.setActivePanel(.home)
            },

            // ── Navigate ──
            LandingCommandItem(
                id: "nav-home", label: "Go Home", icon: "house",
                category: "Navigate", badge: "\u{2318}1"
            ) {
                ui.setActivePanel(.home)
                if let main = NSApp.windows.first(where: { $0.title == "Epistemos" }) {
                    main.makeKeyAndOrderFront(nil)
                }
                dismiss()
            },
            LandingCommandItem(
                id: "nav-notes", label: "Open Notes", icon: "note.text",
                category: "Navigate", badge: "\u{2318}2"
            ) {
                UtilityWindowManager.shared.show(.notes)
                dismiss()
            },
            LandingCommandItem(
                id: "nav-library", label: "Open Library", icon: "books.vertical",
                category: "Navigate", badge: "\u{2318}3"
            ) {
                UtilityWindowManager.shared.show(.library)
                dismiss()
            },
            LandingCommandItem(
                id: "open-graph", label: "Knowledge Graph",
                icon: "point.3.connected.trianglepath.dotted",
                category: "Navigate", badge: "\u{2318}G"
            ) {
                HologramController.shared.show()
                dismiss()
            },
            LandingCommandItem(
                id: "mini-chat", label: "Mini Chat",
                icon: "bubble.left.and.bubble.right",
                category: "Navigate", badge: "\u{21E7}\u{2318}M"
            ) {
                MiniChatWindowController.shared.toggle()
                dismiss()
            },
            LandingCommandItem(
                id: "nav-settings", label: "Open Settings", icon: "gearshape",
                category: "Navigate", badge: "\u{2318},"
            ) {
                UtilityWindowManager.shared.show(.settings)
                dismiss()
            },

            // ── Tools ──
            LandingCommandItem(
                id: "rebuild-graph", label: "Rebuild Graph",
                icon: "arrow.triangle.2.circlepath",
                category: "Tools"
            ) { [self] in
                dismiss()
                if let context = AppBootstrap.shared?.modelContainer.mainContext {
                    graphState.refreshStructuralData(context: context)
                    ui.showToast("Graph rebuilt", type: .success)
                }
            },
            LandingCommandItem(
                id: "import-markdown", label: "Import Markdown",
                icon: "arrow.down.doc",
                category: "Tools"
            ) { [self] in
                dismiss()
                guard let vaultURL = vaultSync.vaultURL else {
                    ui.showToast("No vault attached — set a vault folder in Settings first", type: .warning)
                    return
                }
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.allowedContentTypes = [.plainText]
                panel.begin { response in
                    guard response == .OK else { return }
                    Task { @MainActor in
                        var count = 0
                        for url in panel.urls {
                            let dest = vaultURL.appendingPathComponent(url.lastPathComponent)
                            do {
                                try FileManager.default.copyItem(at: url, to: dest)
                                count += 1
                            } catch {
                                Log.app.error("Import failed for \(url.lastPathComponent): \(error.localizedDescription)")
                            }
                        }
                        if count > 0 {
                            _ = await vaultSync.syncFromVault()
                            ui.showToast("Imported \(count) file(s)", type: .success)
                        }
                    }
                }
            },
            LandingCommandItem(
                id: "toggle-theme", label: "Toggle Theme", icon: "paintpalette",
                category: "Tools"
            ) {
                ui.cycleTheme()
                dismiss()
            },
        ]
    }
}
