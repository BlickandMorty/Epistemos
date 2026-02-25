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

            // Recent Chats — horizontal card strip
            if !allChats.isEmpty {
                recentChatsStrip
                    .padding(.bottom, 28)
            }

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

    // MARK: - Recent Chats Strip

    private var recentChatsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Text("Recent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textTertiary.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()
            }
            .padding(.horizontal, 4)

            // Horizontal card strip — last 5 chats
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allChats.prefix(5), id: \.id) { sdChat in
                        RecentChatCard(sdChat: sdChat) {
                            loadChatIntoSession(sdChat)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - Actions

    private func loadChatIntoSession(_ sdChat: SDChat) {
        let sorted = sdChat.sortedMessages
        let messages = sorted.map { msg in
            let dual = msg.dualMessageData.flatMap {
                try? JSONDecoder().decode(DualMessage.self, from: $0)
            }
            let isResearch = dual?.laymanSummary != nil
            return ChatMessage(
                id: msg.id,
                chatId: sdChat.id,
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content,
                dualMessage: dual,
                truthAssessment: msg.truthAssessmentData.flatMap {
                    try? JSONDecoder().decode(TruthAssessment.self, from: $0)
                },
                confidence: msg.confidenceScore,
                evidenceGrade: msg.evidenceGrade.flatMap { EvidenceGrade(rawValue: $0) },
                mode: msg.inferenceMode.flatMap { InferenceMode(rawValue: $0) },
                createdAt: msg.createdAt,
                isResearchResult: isResearch
            )
        }
        chat.setCurrentChat(sdChat.id)
        chat.chatTitle = sdChat.title
        chat.loadMessages(messages)
        ui.setActivePanel(.home)
    }

    private func createAndOpenNote() {
        Task {
            if let pageId = await vaultSync.createPage(title: "New Note") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    // MARK: - Daily Brief Prompt

    /// Builds a context-rich prompt that includes recent notes and chat history
    /// so the LLM can give a truly personalized daily brief.
    private func buildDailyBriefPrompt() -> String {
        var context: [String] = []

        // ── Recent notes (titles + first ~200 chars of body) ──
        let recentNotes =
            allPages
            .filter {
                $0.templateId == nil
                    && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .prefix(8)

        if !recentNotes.isEmpty {
            var notesSection = "## My Recent Notes\n"
            for note in recentNotes {
                let snippet = String(note.body.prefix(200))
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let tags = note.tags.isEmpty ? "" : " [tags: \(note.tags.joined(separator: ", "))]"
                notesSection +=
                    "- **\(note.title.isEmpty ? "Untitled" : note.title)**\(tags): \(snippet)...\n"
            }
            context.append(notesSection)
        }

        // ── Recent chat conversations (titles + last user message) ──
        let recentChats = allChats.prefix(6)

        if !recentChats.isEmpty {
            var chatsSection = "## My Recent Conversations\n"
            for chatItem in recentChats {
                let lastUserMsg =
                    chatItem.sortedMessages
                    .last { $0.role == "user" }?
                    .content
                    .prefix(150) ?? ""
                let snippet = String(lastUserMsg)
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                chatsSection +=
                    "- **\(chatItem.title)**: \(snippet.isEmpty ? "(no messages)" : "\(snippet)...")\n"
            }
            context.append(chatsSection)
        }

        let contextBlock =
            context.isEmpty
            ? ""
            : """

            Here is context from my recent activity to personalize this brief:

            \(context.joined(separator: "\n"))
            """

        return """
            Give me my personalized daily brief. \
            Scan through my recent notes and conversations below, then:
            1. Summarize the key themes and topics I've been exploring
            2. Highlight any surprising connections between different notes or conversations
            3. Suggest 2-3 research questions or next steps based on what I've been working on
            4. Flag anything that seems incomplete or worth revisiting

            Format: Write in flowing prose with **bold** for emphasis. Use minimal headings — \
            at most 2-3 short section breaks. Keep it conversational and warm but substantive. \
            Use bullet points sparingly, only for the action items at the end.
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

// MARK: - Recent Chat Card
// Compact card for the landing page's recent chats strip.
// Glass-backed with title, preview, and relative timestamp.

private struct RecentChatCard: View {
    let sdChat: SDChat
    let onSelect: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    /// Last assistant message preview (truncated).
    private var previewText: String {
        let msgs = sdChat.sortedMessages
        guard let last = msgs.last(where: { $0.role == "assistant" }) else {
            // Fall back to last user message
            if let userMsg = msgs.last(where: { $0.role == "user" }) {
                let content = userMsg.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return content.count > 80 ? String(content.prefix(80)) + "…" : content
            }
            return "Empty conversation"
        }
        let content = last.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return "Empty response" }
        return content.count > 80 ? String(content.prefix(80)) + "…" : content
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Title row
                HStack(spacing: 4) {
                    if sdChat.hasDeepResearch == true {
                        Image(systemName: "flask")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.accent.opacity(0.7))
                    }
                    Text(sdChat.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                }

                // Preview
                Text(previewText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                // Timestamp
                Text(sdChat.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textTertiary.opacity(0.5))
            }
            .padding(12)
            .frame(width: 200, height: 96, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            theme.foreground.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}
