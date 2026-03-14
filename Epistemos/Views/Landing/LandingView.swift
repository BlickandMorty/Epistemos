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
        text.uppercased()
    }

    static func keyMinWidth(for text: String?) -> CGFloat? {
        guard let text, text.count > 1 else { return nil }
        return multiCharacterKeyMinWidth
    }
}

// MARK: - Landing View
// Clean landing: liquid glass greeting with shortcut hints.
// Search/command palette is now a global overlay (CommandPaletteOverlay)
// shown from any panel via Cmd+S — no longer embedded here.

struct LandingView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(DailyBriefState.self) private var dailyBrief
    @Environment(InferenceState.self) private var inference

    // Recent data for Daily Brief context
    @Query(SDPage.recentDescriptor(limit: 50))
    private var allPages: [SDPage]

    @Query(sort: \SDChat.updatedAt, order: .reverse)
    private var allChats: [SDChat]

    // Inline search state
    @State private var showingSearch = false
    @State private var landingSearchText = ""
    @FocusState private var isLandingSearchFocused: Bool

    private var theme: EpistemosTheme { ui.theme }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }
    private var landingWakeVocabulary: [String] {
        LandingASCIIWakeFieldEngine.normalizedVocabulary(
            from: [
                "Epistemos",
                "Research",
                "Knowledge Graph",
                "Command Palette",
                "New Note",
                "Daily Brief",
                "Apple Intelligence",
                "Sources",
                "Claims",
                "Concepts",
                "Questions",
            ] + allPages.prefix(36).map(\.title)
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Greeting Mode ──
            // Blurs and fades when Daily Brief or inline search is active.
            greetingContent
                .blur(radius: (showingBrief || showingSearch) ? 20 : 0)
                .opacity((showingBrief || showingSearch) ? 0 : 1)
                .allowsHitTesting(!showingBrief && !showingSearch)

            // ── Inline Search Mode ──
            // Click anywhere on landing → greeting blur-replaces into search bar.
            if showingSearch {
                landingSearchContent
                    .transition(.opacity.combined(with: .blurReplace))
            }

            // ── Daily Brief Mode ──
            // Fades in on top of the blurred greeting.
            if showingBrief {
                dailyBriefContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Motion.smooth, value: showingBrief)
        .animation(Motion.smooth, value: showingSearch)
        .background {
            // Hidden ⌘N shortcut — creates new note and teleports there
            Button(action: { createAndOpenNote() }) {}
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            // Hidden ⌘I shortcut — quick idea capture
            Button(action: { captureQuickIdea() }) {}
                .keyboardShortcut("i", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

        }
        .onKeyPress(.escape) {
            if showingSearch {
                dismissLandingSearch()
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

    // MARK: - Greeting Content (normal landing state)

    private var greetingContent: some View {
        ZStack {
            LandingASCIIWakeField(vocabulary: landingWakeVocabulary, theme: theme)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 36) {
                    LiquidGreeting(retractNow: .constant(false))
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Shortcut hints
                HStack(spacing: LandingShortcutDisplay.shortcutRowSpacing) {
                    CommandHint(icon: "magnifyingglass", label: "Click to search", theme: theme) {
                        activateLandingSearch()
                    }
                    .springEntrance(index: 0, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "N", label: "New Note", theme: theme) {
                        createAndOpenNote()
                    }
                    .springEntrance(index: 1, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "option", key: "Space", label: "Palette", theme: theme) {
                        Task { @MainActor in
                            CommandPaletteWindowController.shared.show()
                        }
                    }
                    .springEntrance(index: 2, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "2", label: "Notes", theme: theme) {
                        UtilityWindowManager.shared.show(.notes)
                    }
                    .springEntrance(index: 3, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "G", label: "Graph", theme: theme) {
                        HologramController.shared.toggle()
                    }
                    .help("Graph overlay (\u{2318}G).")
                    .springEntrance(index: 4, stagger: 0.08)
                }
                .padding(.bottom, 28)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { activateLandingSearch() }
    }

    // MARK: - Landing Search Content (replaces greeting in-place)

    private var landingSearchContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
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

                    TextField("Ask Epistemos\u{2026}", text: $landingSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundStyle(theme.foreground)
                        .focused($isLandingSearchFocused)
                        .onSubmit { submitLandingSearch() }

                    if !landingSearchText.isEmpty {
                        Button {
                            landingSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }

                    // Research Mode toggle
                    Button {
                        if chat.isResearchMode { chat.disableResearchMode() } else { chat.enableResearchMode() }
                    } label: {
                        Image(systemName: chat.isResearchMode ? "flask.fill" : "flask")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(chat.isResearchMode ? theme.accent : theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(chat.isResearchMode ? theme.accent.opacity(0.15) : .clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(chat.isResearchMode ? "Research Mode: ON" : "Research Mode: OFF")

                    // API provider picker
                    Menu {
                        ForEach(LLMProviderType.allCases, id: \.self) { provider in
                            Button {
                                inference.apiProvider = provider
                            } label: {
                                HStack {
                                    Image(systemName: provider.iconName)
                                    Text(provider.displayName)
                                    if inference.apiProvider == provider {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: inference.apiProvider.iconName)
                                .font(.system(size: 10, weight: .medium))
                            Text(inference.apiProvider.displayName)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.foreground.opacity(0.06), in: Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .siriGlow(cornerRadius: 20, lineWidth: 1.5, isActive: isLandingSearchFocused)
                .frame(maxWidth: 600)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                // Quick action chips
                HStack(spacing: 10) {
                    landingChip(label: "New Note", icon: "doc.badge.plus") {
                        dismissLandingSearch()
                        createAndOpenNote()
                    }
                    landingChip(label: "Quick Idea", icon: "lightbulb") {
                        dismissLandingSearch()
                        captureQuickIdea()
                    }
                    landingChip(label: "Vault Briefing", icon: "book.pages") {
                        dismissLandingSearch()
                        chat.startNewChat()
                        ui.setActivePanel(.home)
                        AppBootstrap.shared?.requestVaultBriefing(chatState: chat)
                    }
                    landingChip(label: "Daily Brief", icon: "newspaper.fill") {
                        dismissLandingSearch()
                        let prompt = DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: Array(allChats))
                        dailyBrief.requestDailyBrief(prompt: prompt)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.xxl)

            Spacer()

            // Hint to dismiss
            Text("Press Esc to go back")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textTertiary.opacity(0.4))
                .padding(.bottom, 28)
        }
    }

    private func landingChip(label: String, icon: String, action: @escaping () -> Void) -> some View {
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

    private func activateLandingSearch() {
        guard !showingBrief else { return }
        showingSearch = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isLandingSearchFocused = true
        }
    }

    private func dismissLandingSearch() {
        showingSearch = false
        landingSearchText = ""
        isLandingSearchFocused = false
    }

    private func submitLandingSearch() {
        let trimmed = landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dismissLandingSearch()
        chat.startNewChat()
        chat.submitQuery(trimmed)
        ui.setActivePanel(.home)
    }

    // MARK: - Daily Brief Content (replaces greeting in-place)

    private var dailyBriefContent: some View {
        VStack(spacing: 0) {
            // Title — RetroGaming font, centered under nav bar
            Text("daily brief")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)
                .shadow(color: theme.fontAccent.opacity(0.12), radius: 8)
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
                    Text(
                        dailyBrief.isDeepBrief
                            ? "Deep analysis in progress…" : "Scanning your notes & conversations…"
                    )
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
                    .background(Capsule().fill(theme.foreground.opacity(0.06)))
                }
                .buttonStyle(.plain)

                // "Go Deeper" button — visible only after initial brief loads, before deep mode
                if !dailyBrief.isDailyBriefLoading && !dailyBrief.isDeepBrief
                    && !dailyBrief.dailyBriefContent.isEmpty
                {
                    Button {
                        dailyBrief.requestGoDeep(prompt: buildGoDeepPrompt())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("Go Deeper")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(theme.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createAndOpenNote() {
        Task {
            if let pageId = await vaultSync.createPage(title: "New Note") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    private func captureQuickIdea() {
        Task {
            if let pageId = await vaultSync.createPage(title: "New Idea", emoji: "💡") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    // MARK: - Daily Brief Prompt

    private func buildDailyBriefPrompt() -> String {
        DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: Array(allChats))
    }

    // MARK: - Go Deeper Prompt (metadata-rich)

    /// Builds an enriched prompt with full note/chat metadata for deep multi-perspective analysis.
    private func buildGoDeepPrompt() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        var sections: [String] = []

        // ── Note metadata with rich stats ──
        let activeNotes =
            allPages
            .filter { $0.templateId == nil && !$0.isArchived }
            .prefix(15)

        if !activeNotes.isEmpty {
            var notesSection = "## Notes Inventory (sorted by most recently edited)\n\n"
            for note in activeNotes {
                let daysSinceEdit =
                    Calendar.current.dateComponents([.day], from: note.updatedAt, to: .now).day ?? 0
                let daysSinceCreated =
                    Calendar.current.dateComponents([.day], from: note.createdAt, to: .now).day ?? 0
                let tags = note.tags.isEmpty ? "none" : note.tags.joined(separator: ", ")
                let emoji = note.emoji.isEmpty ? "" : "\(note.emoji) "

                notesSection += """
                    - **\(emoji)\(note.title.isEmpty ? "Untitled" : note.title)**
                      Words: \(note.wordCount) | Tags: \(tags) | Created: \(dateFormatter.string(from: note.createdAt)) (\(daysSinceCreated)d ago) | Last edited: \(dateFormatter.string(from: note.updatedAt)) (\(daysSinceEdit)d ago)\n
                    """
            }

            // Aggregate stats
            let totalWords = activeNotes.reduce(0) { $0 + $1.wordCount }
            let allTags = activeNotes.flatMap(\.tags)
            let tagFreq = Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { "\($0.key) (\($0.value))" }
            let longestNote = activeNotes.max(by: { $0.wordCount < $1.wordCount })

            notesSection += "\n### Aggregate Note Stats\n"
            notesSection += "- Total notes: \(activeNotes.count) | Total words: \(totalWords)\n"
            if let longest = longestNote {
                notesSection +=
                    "- Longest note: \"\(longest.title)\" (\(longest.wordCount) words)\n"
            }
            if !tagFreq.isEmpty {
                notesSection += "- Top tags by frequency: \(tagFreq.joined(separator: ", "))\n"
            }

            sections.append(notesSection)
        }

        // ── Chat metadata with analysis scores ──
        let recentChats = allChats.prefix(10)

        if !recentChats.isEmpty {
            var chatsSection = "## Conversation History (sorted by most recent)\n\n"
            for chatItem in recentChats {
                let msgs = chatItem.sortedMessages
                let msgCount = msgs.count
                let daysSinceChat =
                    Calendar.current.dateComponents([.day], from: chatItem.updatedAt, to: .now).day
                    ?? 0
                let isResearch = chatItem.hasDeepResearch == true

                // Extract last assistant confidence + grade
                let lastAssistant = msgs.last { $0.role == "assistant" }
                let confidence =
                    lastAssistant?.confidenceScore.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
                let grade = lastAssistant?.evidenceGrade ?? "—"

                // Last user query snippet
                let lastUserQuery = msgs.last { $0.role == "user" }?.content.prefix(120) ?? ""
                let snippet = String(lastUserQuery).replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                chatsSection += """
                    - **\(chatItem.title)**\(isResearch ? " 🔬" : "")
                      Messages: \(msgCount) | Confidence: \(confidence) | Grade: \(grade) | \(dateFormatter.string(from: chatItem.updatedAt)) (\(daysSinceChat)d ago)
                      Last query: \(snippet.isEmpty ? "(none)" : "\(snippet)…")\n
                    """
            }

            // Chat aggregate
            let totalMsgs = recentChats.reduce(0) {
                $0 + ($1.messages?.count ?? 0)
            }
            let researchCount = recentChats.filter { $0.hasDeepResearch == true }.count
            chatsSection += "\n### Aggregate Chat Stats\n"
            chatsSection +=
                "- Total conversations: \(recentChats.count) | Total messages: \(totalMsgs)\n"
            chatsSection += "- Research chats: \(researchCount)\n"

            sections.append(chatsSection)
        }

        // ── Cross-reference ──
        let noteTagSet = Set(allPages.prefix(15).flatMap(\.tags))
        let chatTitles = allChats.prefix(10).map { $0.title.lowercased() }
        let overlaps = noteTagSet.filter { tag in
            chatTitles.contains { $0.contains(tag) }
        }
        if !overlaps.isEmpty {
            sections.append(
                "## Cross-References\nTags that also appear in chat titles: **\(overlaps.sorted().joined(separator: ", "))**"
            )
        }

        let contextBlock =
            sections.isEmpty
            ? ""
            : """

            Here is the full metadata from my knowledge base for deep analysis:

            \(sections.joined(separator: "\n\n"))
            """

        return """
            Perform a deep multi-perspective analysis of my knowledge base. \
            You have full metadata below — word counts, dates, tags, confidence scores, evidence grades. \
            Use ALL of this data to produce a rigorous synthesis:

            1. **Statistical Patterns** — What do the numbers (word counts, edit frequency, message counts, confidence scores) reveal about my activity?
            2. **Thematic Clusters** — Group my notes and chats into emergent themes. What clusters form naturally?
            3. **Temporal Evolution** — How has my focus shifted? What appeared recently vs. weeks ago? What was abandoned?
            4. **Knowledge Gaps** — Based on what I'm researching, what adjacent topics am I missing?
            5. **Unexpected Connections** — Find non-obvious links between seemingly unrelated notes and conversations.

            End with 3-5 provocative questions I should consider based on the patterns you see.

            Format: Use ### headers for each perspective. Use **bold** for emphasis. Be specific — cite actual \
            note titles, chat topics, dates, word counts, and scores. This should feel like a research briefing, \
            not a summary.
            \(contextBlock)
            """
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
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
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
                    .fill(theme.accent.opacity(0.13))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.foreground.opacity(0.06))
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

private struct CommandHint: View {
    var modIcon: String? = nil
    var icon: String? = nil
    var key: String? = nil
    let label: String
    let theme: EpistemosTheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                if modIcon != nil || key != nil {
                    HStack(spacing: 3) {
                        if let modIcon {
                            Image(systemName: modIcon)
                                .font(.system(size: 10, weight: .medium))
                        }
                        if let key {
                            Text(key)
                                .font(AppDisplayTypography.font(size: LandingShortcutDisplay.fontSize))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.horizontal, LandingShortcutDisplay.keyHorizontalPadding)
                    .padding(.vertical, LandingShortcutDisplay.keyVerticalPadding)
                    .frame(minWidth: LandingShortcutDisplay.keyMinWidth(for: key))
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        RoundedRectangle(
                            cornerRadius: LandingShortcutDisplay.keyCornerRadius,
                            style: .continuous
                        )
                        .fill(theme.card.opacity(theme.isDark ? 0.62 : 0.96))
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: LandingShortcutDisplay.keyCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(
                            isHovered ? theme.fontAccent.opacity(0.65) : theme.border.opacity(0.9),
                            lineWidth: 1
                        )
                    )
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(LandingShortcutDisplay.label(label))
                    .font(AppDisplayTypography.font(size: LandingShortcutDisplay.fontSize))
                    .padding(.leading, (key != nil || modIcon != nil || icon != nil) ? 4 : 0)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .contentShape(Rectangle())
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? theme.fontAccent : theme.textTertiary.opacity(0.5))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }
}

struct LandingASCIIWakeTrail: Equatable {
    let column: Int
    let row: Int
    let startTime: TimeInterval
}

struct LandingASCIIWakeFieldConfiguration: Equatable {
    var duration: TimeInterval = 1.0
    var initialRadius: CGFloat = 0.42
    var maxRadius: CGFloat = 7.5
    var growthExponent: CGFloat = 1.3
    var peakProgress: CGFloat = 0.76
    var endRadius: CGFloat = 0.35
    var contractionExponent: CGFloat = 0.7
    var boundaryThickness: CGFloat = 1.25
    var scrambleCharacters = ASCIIRippleConfiguration().characters
    var surfaceCharacters: [Character] = Array("··················──············")
    var maxTrailCount = 36
}

struct LandingASCIIWakeFieldLayout: Equatable {
    struct CellPosition: Equatable {
        let column: Int
        let row: Int
    }

    let columns: Int
    let rows: Int
    let hiddenCharacters: [Character]
    let surfaceCharacters: [Character]
    let blankCharacters: [Character]
    let cellPositions: [CellPosition?]

    var hiddenText: String { String(hiddenCharacters) }
    var surfaceText: String { String(surfaceCharacters) }
    var blankText: String { String(blankCharacters) }
}

enum LandingASCIIWakeFieldEngine {
    static func normalizedVocabulary(from values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for value in values {
            let trimmed = value
                .uppercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let capped = String(trimmed.prefix(40))
            guard seen.insert(capped).inserted else { continue }
            output.append(capped)
        }

        if output.isEmpty {
            return ["EPISTEMOS", "RESEARCH", "KNOWLEDGE GRAPH", "NEW NOTE", "COMMAND PALETTE"]
        }

        return output
    }

    static func layout(
        vocabulary: [String],
        columns: Int,
        rows: Int,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> LandingASCIIWakeFieldLayout {
        let safeColumns = max(columns, 1)
        let safeRows = max(rows, 1)
        let requiredCells = safeColumns * safeRows
        let stream = Array((normalizedVocabulary(from: vocabulary).joined(separator: " · ") + " · "))
        let hiddenStream = stream.isEmpty ? Array("EPISTEMOS · ") : stream

        var hidden: [Character] = []
        hidden.reserveCapacity(requiredCells + safeRows - 1)

        var surface: [Character] = []
        surface.reserveCapacity(requiredCells + safeRows - 1)

        var blanks: [Character] = []
        blanks.reserveCapacity(requiredCells + safeRows - 1)

        var positions: [LandingASCIIWakeFieldLayout.CellPosition?] = []
        positions.reserveCapacity(requiredCells + safeRows - 1)

        var hiddenIndex = 0
        for row in 0..<safeRows {
            for column in 0..<safeColumns {
                hidden.append(hiddenStream[hiddenIndex % hiddenStream.count])
                surface.append(configuration.surfaceCharacters[(row * safeColumns + column) % configuration.surfaceCharacters.count])
                blanks.append(" ")
                positions.append(.init(column: column, row: row))
                hiddenIndex += 1
            }
            if row < safeRows - 1 {
                hidden.append("\n")
                surface.append("\n")
                blanks.append("\n")
                positions.append(nil)
            }
        }

        return LandingASCIIWakeFieldLayout(
            columns: safeColumns,
            rows: safeRows,
            hiddenCharacters: hidden,
            surfaceCharacters: surface,
            blankCharacters: blanks,
            cellPositions: positions
        )
    }

    static func activeTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [LandingASCIIWakeTrail] {
        trails.filter { now - $0.startTime < configuration.duration }
    }

    static func radius(
        progress: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        let peak = min(max(configuration.peakProgress, 0.05), 0.95)

        if clamped <= peak {
            let normalized = CGFloat(clamped / peak)
            let shaped = pow(normalized, configuration.growthExponent)
            return configuration.initialRadius + shaped * (configuration.maxRadius - configuration.initialRadius)
        }

        let tailProgress = CGFloat((clamped - peak) / (1 - peak))
        let shaped = pow(tailProgress, configuration.contractionExponent)
        return configuration.maxRadius - shaped * (configuration.maxRadius - configuration.endRadius)
    }

    static func overlayText(
        layout: LandingASCIIWakeFieldLayout,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> String {
        let active = activeTrails(trails, now: now, configuration: configuration)
        guard !active.isEmpty else { return layout.blankText }

        var output = layout.blankCharacters

        for index in layout.hiddenCharacters.indices {
            guard let position = layout.cellPositions[index] else { continue }
            let style = cellStyle(
                at: position,
                now: now,
                trails: active,
                configuration: configuration
            )
            switch style {
            case .hidden:
                continue
            case .revealed:
                output[index] = layout.hiddenCharacters[index]
            case .scrambled(let scrambleIndex):
                output[index] = configuration.scrambleCharacters[scrambleIndex % configuration.scrambleCharacters.count]
            }
        }

        return String(output)
    }

    private enum CellStyle {
        case hidden
        case revealed
        case scrambled(Int)
    }

    private static func cellStyle(
        at position: LandingASCIIWakeFieldLayout.CellPosition,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CellStyle {
        var bestReveal = false
        var bestScramble: Int?
        var bestStrength: CGFloat = -.greatestFiniteMagnitude

        for trail in trails {
            let age = now - trail.startTime
            guard age >= 0, age < configuration.duration else { continue }

            let progress = age / configuration.duration
            let radius = radius(progress: progress, configuration: configuration)
            let dx = CGFloat(position.column - trail.column)
            let dy = CGFloat(position.row - trail.row)
            let distance = sqrt(dx * dx + dy * dy)
            guard distance <= radius + configuration.boundaryThickness else { continue }

            let edgeDistance = abs(distance - radius)
            let strength = radius - distance

            if edgeDistance <= configuration.boundaryThickness {
                let scrambleIndex = Int(distance * 7) + Int(age / 0.035)
                if strength > bestStrength {
                    bestStrength = strength
                    bestReveal = false
                    bestScramble = scrambleIndex
                }
            } else if distance < radius {
                if strength > bestStrength {
                    bestStrength = strength
                    bestReveal = true
                    bestScramble = nil
                }
            }
        }

        if bestReveal {
            return .revealed
        }
        if let bestScramble {
            return .scrambled(bestScramble)
        }
        return .hidden
    }
}

private struct LandingASCIIWakeField: View {
    let vocabulary: [String]
    let theme: EpistemosTheme

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var layout = LandingASCIIWakeFieldLayout(
        columns: 1,
        rows: 1,
        hiddenCharacters: [" "],
        surfaceCharacters: ["·"],
        blankCharacters: [" "],
        cellPositions: [.init(column: 0, row: 0)]
    )
    @State private var trails: [LandingASCIIWakeTrail] = []
    @State private var lastPoint: LandingASCIIWakeFieldLayout.CellPosition?

    private let configuration = LandingASCIIWakeFieldConfiguration()
    private let fontSize: CGFloat = 11
    private let lineSpacing: CGFloat = 3

    private var charWidth: CGFloat { fontSize * 0.64 }
    private var lineHeight: CGFloat { fontSize + lineSpacing + 2 }
    private var shouldAnimate: Bool { !reduceMotion && !ui.windowOccluded }

    var body: some View {
        GeometryReader { proxy in
            let columns = max(Int(proxy.size.width / charWidth), 12)
            let rows = max(Int(proxy.size.height / lineHeight), 10)

            ZStack(alignment: .topLeading) {
                Text(layout.surfaceText)
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .lineSpacing(lineSpacing)
                    .foregroundStyle(theme.textTertiary.opacity(theme.isDark ? 0.11 : 0.08))

                if shouldAnimate {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        Text(
                            LandingASCIIWakeFieldEngine.overlayText(
                                layout: layout,
                                now: context.date.timeIntervalSinceReferenceDate,
                                trails: trails,
                                configuration: configuration
                            )
                        )
                        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(theme.fontAccent.opacity(theme.isDark ? 0.26 : 0.18))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .mask(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.9),
                        .white,
                        .white.opacity(0.9),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .contentShape(Rectangle())
            .onAppear {
                rebuildLayout(columns: columns, rows: rows)
            }
            .onChange(of: columns) { _, newValue in
                rebuildLayout(columns: newValue, rows: rows)
            }
            .onChange(of: rows) { _, newValue in
                rebuildLayout(columns: columns, rows: newValue)
            }
            .onChange(of: vocabulary) { _, _ in
                rebuildLayout(columns: columns, rows: rows)
            }
            .onContinuousHover { phase in
                guard shouldAnimate else { return }
                switch phase {
                case .active(let location):
                    let point = LandingASCIIWakeFieldLayout.CellPosition(
                        column: max(0, min(columns - 1, Int((location.x - 26) / charWidth))),
                        row: max(0, min(rows - 1, Int((location.y - 22) / lineHeight)))
                    )
                    guard point != lastPoint else { return }
                    lastPoint = point
                    trails.append(
                        LandingASCIIWakeTrail(
                            column: point.column,
                            row: point.row,
                            startTime: Date.timeIntervalSinceReferenceDate
                        )
                    )
                    if trails.count > configuration.maxTrailCount {
                        trails.removeFirst(trails.count - configuration.maxTrailCount)
                    }
                case .ended:
                    lastPoint = nil
                }
            }
            .task(id: shouldAnimate) {
                guard shouldAnimate else {
                    trails.removeAll(keepingCapacity: false)
                    return
                }
                while !Task.isCancelled {
                    trails = LandingASCIIWakeFieldEngine.activeTrails(
                        trails,
                        now: Date.timeIntervalSinceReferenceDate,
                        configuration: configuration
                    )
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func rebuildLayout(columns: Int, rows: Int) {
        layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: vocabulary,
            columns: columns,
            rows: rows,
            configuration: configuration
        )
    }
}
