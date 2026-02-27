import SwiftData
import SwiftUI

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

    // Recent data for Daily Brief context
    @Query(SDPage.recentDescriptor(limit: 50))
    private var allPages: [SDPage]

    @Query(sort: \SDChat.updatedAt, order: .reverse)
    private var allChats: [SDChat]

    private var theme: EpistemosTheme { ui.theme }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Greeting Mode ──
            // Blurs and fades when the Daily Brief is active.
            greetingContent
                .blur(radius: showingBrief ? 20 : 0)
                .opacity(showingBrief ? 0 : 1)
                .allowsHitTesting(!showingBrief)

            // ── Daily Brief Mode ──
            // Fades in on top of the blurred greeting.
            if showingBrief {
                dailyBriefContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Motion.smooth, value: showingBrief)
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
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 36) {
                LiquidGreeting()
            }
            .allowsHitTesting(false)
            .padding(.horizontal, Spacing.xxl)

            Spacer()

            // Daily Brief — branded wallpaper button
            DailyBriefButton {
                dailyBrief.requestDailyBrief(prompt: buildDailyBriefPrompt())
            }
            .padding(.bottom, 24)

            // Shortcut hints
            HStack(spacing: 16) {
                // ⌘S to search
                HStack(spacing: 3) {
                    Image(systemName: "command")
                    Text("S")
                    Text("Search")
                        .padding(.leading, 2)
                }
                .onTapGesture { ui.toggleCommandPalette() }

                Circle()
                    .fill(theme.textTertiary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // ⌘N new note
                HStack(spacing: 3) {
                    Image(systemName: "command")
                    Text("N")
                    Text("New Note")
                        .padding(.leading, 2)
                }
                .onTapGesture { createAndOpenNote() }

                Circle()
                    .fill(theme.textTertiary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // ⌘I Quick Idea
                HStack(spacing: 3) {
                    Image(systemName: "command")
                    Text("I")
                    Text("Idea")
                        .padding(.leading, 2)
                }
                .onTapGesture { captureQuickIdea() }

                Circle()
                    .fill(theme.textTertiary.opacity(0.3))
                    .frame(width: 3, height: 3)

                // ⌘2 Notes
                HStack(spacing: 3) {
                    Image(systemName: "command")
                    Text("2")
                    Text("Notes")
                        .padding(.leading, 2)
                }
                .onTapGesture { UtilityWindowManager.shared.show(.notes) }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(theme.textTertiary.opacity(0.5))
            .padding(.bottom, 28)
        }
    }

    // MARK: - Daily Brief Content (replaces greeting in-place)

    private var dailyBriefContent: some View {
        VStack(spacing: 0) {
            // Title — RetroGaming font, centered under nav bar
            Text("daily brief")
                .font(.custom("RetroGaming", size: 24))
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

    /// Builds a comprehensive prompt with deep vault context for a productivity-grade daily brief.
    private func buildDailyBriefPrompt() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        var context: [String] = []

        // ── Recent notes with rich metadata + longer snippets ──
        let recentNotes =
            allPages
            .filter {
                $0.templateId == nil
                    && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .prefix(18)

        if !recentNotes.isEmpty {
            var notesSection = "## Recent Notes (\(recentNotes.count) most recent)\n"
            for note in recentNotes {
                let snippet = String(note.body.prefix(500))
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let tags = note.tags.isEmpty ? "" : " [tags: \(note.tags.joined(separator: ", "))]"
                let daysSinceEdit =
                    Calendar.current.dateComponents([.day], from: note.updatedAt, to: .now).day ?? 0
                let freshness = daysSinceEdit == 0 ? "today" : daysSinceEdit == 1 ? "yesterday" : "\(daysSinceEdit)d ago"
                let emoji = note.emoji.isEmpty ? "" : "\(note.emoji) "
                notesSection +=
                    "- **\(emoji)\(note.title.isEmpty ? "Untitled" : note.title)**\(tags) (\(note.wordCount) words, edited \(freshness)): \(snippet)…\n"
            }

            // Aggregate stats for pattern detection
            let totalWords = recentNotes.reduce(0) { $0 + $1.wordCount }
            let allTags = recentNotes.flatMap(\.tags)
            let tagFreq = Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
                .sorted { $0.value > $1.value }
                .prefix(8)
                .map { "\($0.key) (\($0.value))" }
            if !tagFreq.isEmpty {
                notesSection += "\nTop tags: \(tagFreq.joined(separator: ", ")) | Total words across notes: \(totalWords)\n"
            }
            context.append(notesSection)
        }

        // ── Recent chat conversations with richer context ──
        let recentChats = allChats.prefix(12)

        if !recentChats.isEmpty {
            var chatsSection = "## Recent Conversations (\(recentChats.count) most recent)\n"
            for chatItem in recentChats {
                let msgs = chatItem.sortedMessages
                let msgCount = msgs.count
                let daysSinceChat =
                    Calendar.current.dateComponents([.day], from: chatItem.updatedAt, to: .now).day ?? 0
                let freshness = daysSinceChat == 0 ? "today" : daysSinceChat == 1 ? "yesterday" : "\(daysSinceChat)d ago"
                let isResearch = chatItem.hasDeepResearch == true

                // Get last user query and last assistant response for topic understanding
                let lastUserMsg = msgs.last { $0.role == "user" }?.content.prefix(300) ?? ""
                let lastAssistantSnippet = msgs.last { $0.role == "assistant" }?.content.prefix(200) ?? ""
                let userSnippet = String(lastUserMsg)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let assistantSnippet = String(lastAssistantSnippet)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                chatsSection +=
                    "- **\(chatItem.title)**\(isResearch ? " [research]" : "") (\(msgCount) msgs, \(freshness))\n"
                if !userSnippet.isEmpty {
                    chatsSection += "  Q: \(userSnippet)…\n"
                }
                if !assistantSnippet.isEmpty {
                    chatsSection += "  A: \(assistantSnippet)…\n"
                }
            }
            context.append(chatsSection)
        }

        // ── Vault manifest for full vault awareness ──
        if let manifest = AppBootstrap.shared?.ambientManifest {
            context.append(manifest.asManifestOnly())
        }

        let contextBlock =
            context.isEmpty
            ? ""
            : """

            Here is my full recent activity and vault overview for deep analysis:

            \(context.joined(separator: "\n"))
            """

        return """
            Generate my daily brief — a deep, actionable intelligence report on my knowledge work. \
            Analyze everything below comprehensively, then produce:

            ### What I'm Working On
            Identify the 3-5 major threads of work/research I'm currently engaged in. For each thread, \
            explain what stage it's at (just starting, deep in progress, wrapping up, stalled).

            ### Key Insights & Connections
            Find the most interesting connections between my notes and conversations. Surface patterns I \
            might not have noticed — thematic overlaps, conceptual tensions, evolving perspectives. \
            Be specific: cite actual note titles and conversation topics.

            ### Open Loops & Incomplete Work
            Flag anything that looks started but unfinished, questions I asked but didn't follow up on, \
            notes that seem like fragments of larger ideas. These are my highest-priority knowledge debts.

            ### Recommended Actions
            Based on all the above, give me 4-6 concrete next steps I should take today. Prioritize by \
            impact. Each action should reference a specific note, conversation, or topic.

            ### Emerging Themes
            Step back and describe the bigger picture — what intellectual territory am I mapping? How do \
            my different projects and interests connect at a higher level?

            Format: Use **bold** for note titles and key concepts. Write in substantive prose — \
            this should read like a research analyst's morning brief, not a bulleted summary. \
            Be warm but rigorous. Reference specific content to prove you've actually read everything.
            \(contextBlock)
            """
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
                $0 + ($0 == 0 ? 0 : 0) + ($1.messages?.count ?? 0)
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
    let action: () -> Void
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

                Text(command.label)
                    .font(.epBody)
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text(command.category)
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
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
    }
}
