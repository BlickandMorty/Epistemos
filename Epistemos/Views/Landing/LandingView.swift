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

enum LandingSearchLayout {
    static let maxWidth: CGFloat = 640
    static let topRowSpacing: CGFloat = 12
    static let controlRowSpacing: CGFloat = 8
    static let controlRowTopPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 14
    static let cornerRadius: CGFloat = 24
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
    @State private var landingComposerHeight = ChatComposerInputMetrics.minHeight
    @State private var isLandingSearchFocused = false

    private var theme: EpistemosTheme { ui.theme }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }
    private var trimmedLandingSearchText: String {
        landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: LandingSearchLayout.topRowSpacing) {
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
                            .padding(.top, 8)

                        ZStack(alignment: .topLeading) {
                            ChatComposerTextEditor(
                                text: $landingSearchText,
                                height: $landingComposerHeight,
                                isFocused: $isLandingSearchFocused,
                                theme: theme,
                                isProcessing: false
                            ) {
                                submitLandingSearch()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: landingComposerHeight)

                            if landingSearchText.isEmpty {
                                Text("Ask Epistemos\u{2026}")
                                    .font(.system(size: 22, weight: .regular, design: .rounded))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.55))
                                    .padding(.top, ChatComposerInputMetrics.placeholderTopPadding + 1)
                                    .allowsHitTesting(false)
                            }
                        }

                        if !landingSearchText.isEmpty {
                            Button {
                                landingSearchText = ""
                                landingComposerHeight = ChatComposerInputMetrics.minHeight
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(theme.textTertiary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(NativeToolbarButtonStyle())
                            .padding(.top, 4)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }

                    HStack(alignment: .center, spacing: LandingSearchLayout.controlRowSpacing) {
                        HStack(spacing: LandingSearchLayout.controlRowSpacing) {
                            ResearchModeControl(variant: .toolbar)

                            landingProviderMenu
                        }

                        Spacer(minLength: 0)

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
                    .padding(.top, LandingSearchLayout.controlRowTopPadding)
                }
                .padding(.horizontal, LandingSearchLayout.horizontalPadding)
                .padding(.top, LandingSearchLayout.topPadding)
                .padding(.bottom, LandingSearchLayout.bottomPadding)
                .assistantGlassInputChrome(
                    theme: theme,
                    cornerRadius: LandingSearchLayout.cornerRadius,
                    isActive: isLandingSearchFocused || !trimmedLandingSearchText.isEmpty
                )
                .siriGlow(
                    cornerRadius: LandingSearchLayout.cornerRadius,
                    lineWidth: 1.5,
                    isActive: isLandingSearchFocused
                )
                .frame(maxWidth: LandingSearchLayout.maxWidth)
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

    private var landingProviderMenu: some View {
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
            HStack(spacing: 6) {
                Image(systemName: inference.apiProvider.iconName)
                    .font(.system(size: 12, weight: .semibold))
                Text(inference.apiProvider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .assistantInsetChrome(theme: theme, cornerRadius: 11)
        }
        .menuStyle(.borderlessButton)
        .help("Provider")
        .accessibilityLabel("Provider")
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
        landingComposerHeight = ChatComposerInputMetrics.minHeight
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
    let x: CGFloat
    let y: CGFloat
    let startTime: TimeInterval
    let radiusScale: CGFloat

    init(x: CGFloat, y: CGFloat, startTime: TimeInterval, radiusScale: CGFloat = 1) {
        self.x = x
        self.y = y
        self.startTime = startTime
        self.radiusScale = radiusScale
    }

    init(column: Int, row: Int, startTime: TimeInterval, radiusScale: CGFloat = 1) {
        self.init(x: CGFloat(column), y: CGFloat(row), startTime: startTime, radiusScale: radiusScale)
    }
}

struct LandingASCIIWakeFieldConfiguration: Equatable {
    var frameInterval: TimeInterval = 1.0 / 120.0
    var interpolationStep: CGFloat = 0.4
    var duration: TimeInterval = 1.14
    var initialRadius: CGFloat = 0.62
    var maxRadius: CGFloat = 7.6
    var growthExponent: CGFloat = 1.18
    var peakProgress: CGFloat = 0.68
    var endRadius: CGFloat = 0.4
    var contractionExponent: CGFloat = 0.72
    var boundaryThickness: CGFloat = 1.15
    var scrambleCharacters = ASCIIRippleConfiguration().characters
    var surfaceCharacters: [Character] = Array(repeating: "·", count: 32)
    var restingSurfaceOpacity: Double = 0
    var maxTrailCount = 176
    var streamTailLength: CGFloat = 3.4
    var streamLongDragDistance: CGFloat = 4.8
    var streamVelocityReference: CGFloat = 26
    var streamCoreRadiusBoost: CGFloat = 0.72
    var streamAdaptiveStepBoost: CGFloat = 0.45
    var streamBubbleStride = 3
    var streamBubbleOffset: CGFloat = 1.15
    var streamBubbleBacktrack: CGFloat = 0.72
    var streamBubbleRadiusScale: CGFloat = 0.56
    var streamBubbleFastScaleBoost: CGFloat = 0.32
    var streamSwingMaxOffset: CGFloat = 0.72
    var streamSwingCycles: CGFloat = 1.18
    var streamHeadAgeBoost: TimeInterval = 0.1
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
    struct ResolvedTrail: Equatable {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let radiusSquared: CGFloat
        let revealRadius: CGFloat
        let minColumn: Int
        let maxColumn: Int
        let minRow: Int
        let maxRow: Int
        let scramblePhase: Int
    }

    struct TrailPoint: Equatable {
        let x: CGFloat
        let y: CGFloat
    }

    struct TrailSample: Equatable {
        let point: TrailPoint
        let radiusScale: CGFloat
        let ageOffset: TimeInterval

        init(point: TrailPoint, radiusScale: CGFloat, ageOffset: TimeInterval = 0) {
            self.point = point
            self.radiusScale = radiusScale
            self.ageOffset = ageOffset
        }
    }

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

    static func hasActiveTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> Bool {
        for trail in trails where now - trail.startTime < configuration.duration {
            return true
        }
        return false
    }

    static func prunedTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [LandingASCIIWakeTrail] {
        guard !trails.isEmpty else { return [] }

        var output: [LandingASCIIWakeTrail] = []
        output.reserveCapacity(trails.count)
        for trail in trails where now - trail.startTime < configuration.duration {
            output.append(trail)
        }
        return output
    }

    static func nextTrailCleanupDelay(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> TimeInterval? {
        var nextDelay: TimeInterval?

        for trail in trails {
            let delay = trail.startTime + configuration.duration - now
            guard delay > 0 else { continue }
            if let currentDelay = nextDelay {
                if delay < currentDelay {
                    nextDelay = delay
                }
            } else {
                nextDelay = delay
            }
        }

        return nextDelay
    }

    static func interpolatedPath(
        from start: TrailPoint,
        to end: TrailPoint,
        maxStep: CGFloat = 0.4
    ) -> [TrailPoint] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else { return [] }

        let steps = max(Int(ceil(distance / max(maxStep, 0.05))), 1)
        var output: [TrailPoint] = []
        output.reserveCapacity(steps)

        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = TrailPoint(
                x: start.x + deltaX * progress,
                y: start.y + deltaY * progress
            )
            if output.last != point {
                output.append(point)
            }
        }

        return output
    }

    static func streamInterpolationStep(
        distance: CGFloat,
        eventDelta: TimeInterval?,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let intensity = streamIntensity(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        let baseStep = max(configuration.interpolationStep, 0.05)
        return baseStep * (1 + intensity * configuration.streamAdaptiveStepBoost)
    }

    static func streamPath(
        from start: TrailPoint,
        to end: TrailPoint,
        maxStep: CGFloat = 0.4,
        tailLength: CGFloat
    ) -> [TrailPoint] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else { return [end] }

        let step = max(maxStep, 0.05)
        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        let tailSteps = max(Int(ceil(max(tailLength, 0) / step)), 0)
        let movementPoints = interpolatedPath(from: start, to: end, maxStep: step)
        var output: [TrailPoint] = []
        output.reserveCapacity(tailSteps + movementPoints.count + 1)

        if tailSteps > 0 {
            for stepIndex in stride(from: tailSteps, through: 1, by: -1) {
                let tailDistance = CGFloat(stepIndex) * step
                let point = TrailPoint(
                    x: end.x - normalizedX * tailDistance,
                    y: end.y - normalizedY * tailDistance
                )
                if output.last != point {
                    output.append(point)
                }
            }
        }

        for point in movementPoints {
            if output.last != point {
                output.append(point)
            }
        }
        if output.last != end {
            output.append(end)
        }

        return output
    }

    static func streamTrailSamples(
        from start: TrailPoint,
        to end: TrailPoint,
        eventDelta: TimeInterval? = nil,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [TrailSample] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else {
            return [.init(point: end, radiusScale: 1)]
        }

        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        let normalX = -normalizedY
        let normalY = normalizedX
        let intensity = streamIntensity(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        let interpolationStep = streamInterpolationStep(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        // Extend tail during intense drags to maintain water continuity
        let dynamicTailLength = configuration.streamTailLength * (1 + intensity * 0.5)
        let swingAmplitude = configuration.streamSwingMaxOffset * intensity
        let headAgeOffset = configuration.streamHeadAgeBoost * Double(intensity)
        let path = streamPath(
            from: start,
            to: end,
            maxStep: interpolationStep,
            tailLength: dynamicTailLength
        )
        var output: [TrailSample] = []
        output.reserveCapacity(path.count + path.count / max(configuration.streamBubbleStride, 1))

        let bubbleStride = max(configuration.streamBubbleStride, 2)
        var bubbleOrdinal = 0
        let progressDivisor = CGFloat(max(path.count - 1, 1))
        for (index, point) in path.enumerated() {
            let progress = CGFloat(index) / progressDivisor
            let swingTaper = sqrt(progress)
            let swing = sin(progress * .pi * configuration.streamSwingCycles) * swingAmplitude * swingTaper
            let streamPoint = TrailPoint(
                x: point.x + normalX * swing,
                y: point.y + normalY * swing
            )
            let streamRadiusScale = 1 + configuration.streamCoreRadiusBoost * intensity * progress
            let streamAgeOffset = headAgeOffset * Double(progress)

            if output.last?.point != streamPoint
                || output.last?.radiusScale != streamRadiusScale
                || output.last?.ageOffset != streamAgeOffset {
                output.append(
                    .init(
                        point: streamPoint,
                        radiusScale: streamRadiusScale,
                        ageOffset: streamAgeOffset
                    )
                )
            }

            guard index >= 2, index < path.count - 1, index.isMultiple(of: bubbleStride) else { continue }
            let side: CGFloat = bubbleOrdinal.isMultiple(of: 2) ? 1 : -1
            bubbleOrdinal += 1

            // Add swing to bubbles during intense movement for "water splash" effect
            let bubbleSwing = sin(progress * .pi * configuration.streamSwingCycles * 1.5) * swingAmplitude * 0.5 * intensity
            let bubblePoint = TrailPoint(
                x: streamPoint.x - normalizedX * configuration.streamBubbleBacktrack + normalX * side * configuration.streamBubbleOffset + normalX * bubbleSwing,
                y: streamPoint.y - normalizedY * configuration.streamBubbleBacktrack + normalY * side * configuration.streamBubbleOffset + normalY * bubbleSwing
            )
            // Ensure minimum bubble size during intense movement (prevents "tiny bubble" issue)
            let minBubbleScale: CGFloat = 0.4 + (intensity * 0.3)
            let bubbleRadiusScale = max(minBubbleScale, configuration.streamBubbleRadiusScale
                * (1 + configuration.streamBubbleFastScaleBoost * intensity))
            let bubbleAgeOffset = headAgeOffset * Double(max(progress - 0.1, 0))
            output.append(
                .init(
                    point: bubblePoint,
                    radiusScale: bubbleRadiusScale,
                    ageOffset: bubbleAgeOffset
                )
            )
        }

        return output
    }

    private static func streamIntensity(
        distance: CGFloat,
        eventDelta: TimeInterval?,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let distanceFactor = min(max(distance / max(configuration.streamLongDragDistance, 0.1), 0), 1)
        guard let eventDelta else { return distanceFactor }

        let safeDelta = max(CGFloat(eventDelta), 1.0 / 240.0)
        let velocity = distance / safeDelta
        let velocityFactor = min(max(velocity / max(configuration.streamVelocityReference, 0.1), 0), 1)
        return max(distanceFactor, velocityFactor)
    }

    static func clampedTrailSamples(
        _ rawSamples: [TrailSample],
        columns: Int,
        rows: Int
    ) -> [TrailSample] {
        guard !rawSamples.isEmpty else { return [] }

        let maxColumn = CGFloat(max(columns - 1, 0))
        let maxRow = CGFloat(max(rows - 1, 0))
        var output: [TrailSample] = []
        output.reserveCapacity(rawSamples.count)

        for rawSample in rawSamples {
            let sample = TrailSample(
                point: TrailPoint(
                    x: max(0, min(maxColumn, rawSample.point.x)),
                    y: max(0, min(maxRow, rawSample.point.y))
                ),
                radiusScale: rawSample.radiusScale,
                ageOffset: rawSample.ageOffset
            )
            if output.last != sample {
                output.append(sample)
            }
        }

        return output
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

    static func resolvedTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration,
        columns: Int,
        rows: Int
    ) -> [ResolvedTrail] {
        guard !trails.isEmpty, columns > 0, rows > 0 else { return [] }

        var output: [ResolvedTrail] = []
        output.reserveCapacity(trails.count)

        for trail in trails {
            let age = now - trail.startTime
            guard age >= 0, age < configuration.duration else { continue }

            let progress = age / configuration.duration
            let radius = radius(progress: progress, configuration: configuration) * trail.radiusScale
            guard radius > 0 else { continue }

            let boundaryThickness = max(0.35, configuration.boundaryThickness * max(trail.radiusScale, 0.7))
            let scrambleShellThickness = max(boundaryThickness, radius * 0.15)
            let revealRadius = max(0, radius - scrambleShellThickness)
            let minColumn = max(0, Int(floor(trail.x - radius)))
            let maxColumn = min(columns - 1, Int(ceil(trail.x + radius)))
            let minRow = max(0, Int(floor(trail.y - radius)))
            let maxRow = min(rows - 1, Int(ceil(trail.y + radius)))
            guard minColumn <= maxColumn, minRow <= maxRow else { continue }

            output.append(
                ResolvedTrail(
                    x: trail.x,
                    y: trail.y,
                    radius: radius,
                    radiusSquared: radius * radius,
                    revealRadius: revealRadius,
                    minColumn: minColumn,
                    maxColumn: maxColumn,
                    minRow: minRow,
                    maxRow: maxRow,
                    scramblePhase: Int(age / 0.035)
                )
            )
        }

        return output
    }

    static func overlayText(
        layout: LandingASCIIWakeFieldLayout,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> String {
        let activeTrails = resolvedTrails(
            trails,
            now: now,
            configuration: configuration,
            columns: layout.columns,
            rows: layout.rows
        )
        guard !activeTrails.isEmpty else {
            return layout.blankText
        }

        var output = layout.blankCharacters
        var bestStrengths = Array(
            repeating: -CGFloat.greatestFiniteMagnitude,
            count: output.count
        )

        for trail in activeTrails {
            for row in trail.minRow...trail.maxRow {
                let dy = CGFloat(row) - trail.y
                let dySquared = dy * dy
                let rowBase = row * (layout.columns + 1)

                for column in trail.minColumn...trail.maxColumn {
                    let dx = CGFloat(column) - trail.x
                    let distanceSquared = dx * dx + dySquared
                    guard distanceSquared < trail.radiusSquared else { continue }

                    let distance = sqrt(distanceSquared)
                    let characterIndex = rowBase + column

                    if distance >= trail.revealRadius {
                        let strength = trail.radius - distance
                        guard strength > bestStrengths[characterIndex] else { continue }
                        bestStrengths[characterIndex] = strength
                        let scrambleIndex = Int((distance - trail.revealRadius) * 11) + trail.scramblePhase
                        output[characterIndex] = configuration.scrambleCharacters[scrambleIndex % configuration.scrambleCharacters.count]
                    } else {
                        let strength = trail.revealRadius - distance
                        guard strength > bestStrengths[characterIndex] else { continue }
                        bestStrengths[characterIndex] = strength
                        output[characterIndex] = layout.hiddenCharacters[characterIndex]
                    }
                }
            }
        }

        return String(output)
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
    @State private var lastHoverPoint: LandingASCIIWakeFieldEngine.TrailPoint?
    @State private var lastHoverTime: TimeInterval?
    @State private var trailCleanupTask: Task<Void, Never>?

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
                if configuration.restingSurfaceOpacity > 0 {
                    Text(layout.surfaceText)
                        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(theme.textTertiary.opacity(configuration.restingSurfaceOpacity))
                }

                if shouldAnimate, !trails.isEmpty {
                    TimelineView(.animation(minimumInterval: configuration.frameInterval)) { context in
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
                    let point = LandingASCIIWakeFieldEngine.TrailPoint(
                        x: max(0, min(CGFloat(columns - 1), (location.x - 26) / charWidth)),
                        y: max(0, min(CGFloat(rows - 1), (location.y - 22) / lineHeight))
                    )
                    let now = Date.timeIntervalSinceReferenceDate
                    if let lastHoverPoint, lastHoverPoint != point {
                        let eventDelta = lastHoverTime.map { now - $0 }
                        let rawSamples = LandingASCIIWakeFieldEngine.streamTrailSamples(
                            from: lastHoverPoint,
                            to: point,
                            eventDelta: eventDelta,
                            configuration: configuration
                        )
                        appendTrailSamples(rawSamples, now: now, columns: columns, rows: rows)
                    } else if lastHoverPoint == nil {
                        appendTrailSamples(
                            [LandingASCIIWakeFieldEngine.TrailSample(point: point, radiusScale: 1)],
                            now: now,
                            columns: columns,
                            rows: rows
                        )
                    }
                    lastHoverPoint = point
                    lastHoverTime = now
                case .ended:
                    lastHoverPoint = nil
                    lastHoverTime = nil
                }
            }
            .onChange(of: shouldAnimate) { _, newValue in
                guard !newValue else { return }
                trails.removeAll(keepingCapacity: false)
                lastHoverPoint = nil
                lastHoverTime = nil
                trailCleanupTask?.cancel()
                trailCleanupTask = nil
            }
        }
        .onDisappear {
            trailCleanupTask?.cancel()
            trailCleanupTask = nil
        }
        .allowsHitTesting(true)
    }

    private func appendTrailSamples(
        _ rawSamples: [LandingASCIIWakeFieldEngine.TrailSample],
        now: TimeInterval,
        columns: Int,
        rows: Int
    ) {
        let samples = LandingASCIIWakeFieldEngine.clampedTrailSamples(
            rawSamples,
            columns: columns,
            rows: rows
        )
        guard !samples.isEmpty else { return }

        trails = LandingASCIIWakeFieldEngine.prunedTrails(
            trails,
            now: now,
            configuration: configuration
        )

        let timeStride = min(0.01, configuration.duration / Double(max(samples.count * 5, 1)))
        trails.reserveCapacity(max(trails.count + samples.count, configuration.maxTrailCount))
        for (index, sample) in samples.enumerated() {
            trails.append(
                LandingASCIIWakeTrail(
                    x: sample.point.x,
                    y: sample.point.y,
                    startTime: now - timeStride * Double(samples.count - index - 1) - sample.ageOffset,
                    radiusScale: sample.radiusScale
                )
            )
        }
        if trails.count > configuration.maxTrailCount {
            trails.removeFirst(trails.count - configuration.maxTrailCount)
        }
        scheduleTrailCleanup()
    }

    private func rebuildLayout(columns: Int, rows: Int) {
        layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: vocabulary,
            columns: columns,
            rows: rows,
            configuration: configuration
        )
    }

    private func scheduleTrailCleanup() {
        trailCleanupTask?.cancel()

        let now = Date.timeIntervalSinceReferenceDate
        guard let delay = LandingASCIIWakeFieldEngine.nextTrailCleanupDelay(
            trails,
            now: now,
            configuration: configuration
        ) else {
            trailCleanupTask = nil
            return
        }

        trailCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(max(Int(ceil(delay * 1000)), 1)))
            guard !Task.isCancelled else { return }

            trails = LandingASCIIWakeFieldEngine.prunedTrails(
                trails,
                now: Date.timeIntervalSinceReferenceDate,
                configuration: configuration
            )

            if trails.isEmpty {
                trailCleanupTask = nil
            } else {
                scheduleTrailCleanup()
            }
        }
    }
}
