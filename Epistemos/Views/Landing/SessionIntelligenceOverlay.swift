import SwiftData
import SwiftUI

// MARK: - Session Intelligence Overlay
// Full-screen overlay triggered by Cmd+Ctrl+R. Shows a visual map of all open windows
// with per-window AI summaries typed progressively, followed by a global synthesis.
// Uses the Map-Reduce pipeline from WorkspaceSummaryService.

struct SessionIntelligenceOverlay: View {
    @Environment(UIState.self) private var ui
    @Binding var isPresented: Bool

    @State private var windowCards: [WindowCard] = []
    @State private var globalSynthesis = ""
    @State private var isGenerating = true
    @State private var appeared = false
    @State private var commandInput = ""
    @State private var commandResponse = ""
    @State private var isRunningCommand = false
    @State private var commandHistory: [(query: String, response: String)] = []
    @State private var chatModel: ChatModelChoice = .local

    private var theme: EpistemosTheme { ui.theme }

    struct WindowCard: Identifiable {
        let id: String
        let title: String
        let icon: String
        let kind: String // "note", "chat", "graph"
        var summary: String = ""
        var wordCount: Int = 0
    }

    enum ChatModelChoice: String, CaseIterable {
        case local = "Qwen 2B"
        case appleAI = "Apple AI"

        var icon: String {
            switch self {
            case .local: "cpu"
            case .appleAI: "apple.intelligence"
            }
        }
    }

    private var scrimColor: Color { theme.isDark ? .black : .gray }
    private var scrimOpacity: Double { theme.isDark ? 0.4 : 0.2 }
    private var panelShadow: Color { theme.isDark ? .black.opacity(0.3) : .black.opacity(0.1) }
    private var panelStroke: Color { theme.isDark ? .white.opacity(0.08) : .black.opacity(0.06) }

    var body: some View {
        ZStack {
            scrimColor.opacity(appeared ? scrimOpacity : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Session Intelligence")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }

                    // Model picker
                    Picker("", selection: $chatModel) {
                        ForEach(ChatModelChoice.allCases, id: \.self) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)

                    Text("esc to close")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider().opacity(0.3)

                // Window map
                ScrollView {
                    VStack(spacing: 12) {
                        // Window cards grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 12)], spacing: 12) {
                            ForEach(Array(windowCards.enumerated()), id: \.element.id) { index, card in
                                windowCardView(card)
                                    .springEntrance(index: index, stagger: 0.06)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        // Global synthesis
                        if !globalSynthesis.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider().opacity(0.2)

                                Text("Session Focus")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                                    .padding(.horizontal, 24)

                                TypewriterPlainText(content: globalSynthesis)
                                    .font(.system(size: 14.5, weight: .regular))
                                    .foregroundStyle(theme.fontAccent.opacity(0.85))
                                    .italic()
                                    .lineSpacing(5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 260)

                Divider().opacity(0.3)

                // Command chat — main interaction area
                commandChatSection
                    .frame(minHeight: 180)
            }
            .frame(width: 680, height: 580)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: panelShadow, radius: 24, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(panelStroke)
            }
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
            .foregroundStyle(theme.resolved.foreground.color)
        }
        .background {
            Button(action: { dismiss() }) {}
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            buildWindowCards()
            Task { await generateIntelligence() }
        }
    }

    // MARK: - Window Card View

    private func windowCardView(_ card: WindowCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: card.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(theme.resolved.accent.color.opacity(0.12))
                    )

                Text(card.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Spacer()

                Text(card.kind)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.resolved.foreground.color.opacity(0.05), in: Capsule())
            }

            if card.wordCount > 0 {
                Text("\(card.wordCount) words")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }

            if !card.summary.isEmpty {
                Text(card.summary)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
                    .italic()
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.resolved.foreground.color.opacity(0.06))
        }
        .physicsHover(.subtle)
    }

    // MARK: - Data Collection

    private func buildWindowCards() {
        var cards: [WindowCard] = []

        // Note windows
        for pageId in NoteWindowManager.shared.orderedPageIds() {
            let title = NoteWindowManager.shared.navState(forTab: pageId)?.currentPageTitle ?? "Untitled"
            let body = currentBody(for: pageId)
            let wordCount = body.split(separator: " ").count
            cards.append(WindowCard(
                id: "note-\(pageId)", title: title, icon: "doc.text.fill",
                kind: "note", wordCount: wordCount
            ))
        }

        // Mini chats
        for chatId in MiniChatWindowController.shared.openChatIds {
            cards.append(WindowCard(
                id: "chat-\(chatId)", title: "Mini Chat", icon: "bubble.left.and.bubble.right.fill",
                kind: "chat"
            ))
        }

        // Graph
        if HologramController.shared.isVisible {
            let nodeCount = AppBootstrap.shared?.graphState.store.nodes.count ?? 0
            cards.append(WindowCard(
                id: "graph", title: "Knowledge Graph",
                icon: "point.3.connected.trianglepath.dotted",
                kind: HologramController.shared.isMinimized ? "mini graph" : "graph",
                wordCount: nodeCount
            ))
        }

        windowCards = cards
    }

    private func currentBody(for pageId: String) -> String {
        NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
    }

    // MARK: - AI Generation (Map-Reduce)

    private func generateIntelligence() async {
        guard let summaryService = AppBootstrap.shared?.workspaceSummaryService else {
            isGenerating = false
            return
        }

        // Map phase: per-window summaries
        let perWindow = await summaryService.generatePerWindowSummaries()

        // Apply per-window summaries to cards
        for (title, summary) in perWindow {
            if let idx = windowCards.firstIndex(where: { $0.title == title }) {
                windowCards[idx].summary = summary
            }
        }

        // Reduce phase: global synthesis (use returning variant to avoid stale DB read race)
        if let freshSummary = await summaryService.generateSummaryNowReturning() {
            globalSynthesis = freshSummary
        } else if let workspace = try? AppBootstrap.shared?.modelContainer.mainContext.fetch(
            FetchDescriptor<SDWorkspace>(predicate: #Predicate<SDWorkspace> { $0.isAutoSave == true })
        ).first {
            globalSynthesis = workspace.summary
        }

        isGenerating = false
    }

    // MARK: - Command Chat

    private var commandChatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chat history
            ScrollView {
                if commandHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Session Intelligence Chat")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)

                        VStack(alignment: .leading, spacing: 4) {
                            commandHintRow("open note X", "Navigate to a note")
                            commandHintRow("new note Title", "Create and open a note")
                            commandHintRow("save session as note", "Export this session to a note")
                            commandHintRow("summarize note X", "AI summary of a specific note")
                            commandHintRow("write to note X: text", "Append text to a note")
                            commandHintRow("reveal X", "Show note in knowledge graph")
                            commandHintRow("activity", "View session stats")
                            commandHintRow("close all", "Close all windows")
                        }

                        Text("Or ask anything — the AI has full context of your session.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(theme.textTertiary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(commandHistory.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(theme.resolved.accent.color))
                                    Text(entry.query)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.textSecondary)
                                        .frame(width: 20, height: 20)
                                        .background(Circle().fill(theme.resolved.foreground.color.opacity(0.06)))
                                    Text(entry.response)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(theme.textSecondary)
                                        .textSelection(.enabled)
                                }
                                .padding(10)
                                .background(theme.resolved.foreground.color.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Input
            HStack(spacing: 10) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.resolved.accent.color)

                TextField("Ask about your session, or command: \"open note X\", \"show chat Y\"...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))
                    .onSubmit { Task { await executeCommand() } }

                if isRunningCommand {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else {
                    Button {
                        Task { await executeCommand() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(commandInput.isEmpty ? theme.textTertiary : theme.resolved.accent.color)
                    }
                    .buttonStyle(.plain)
                    .disabled(commandInput.isEmpty)
                    .physicsHover(.subtle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.resolved.foreground.color.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    private func executeCommand() async {
        let query = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        commandInput = ""
        isRunningCommand = true

        let lower = query.lowercased()

        // — Note commands —
        if let result = await handleNoteCommand(lower, original: query) {
            commandHistory.append((query: query, response: result))
            isRunningCommand = false
            return
        }

        // — Chat commands —
        if let result = await handleChatCommand(lower, original: query) {
            commandHistory.append((query: query, response: result))
            isRunningCommand = false
            return
        }

        // — Graph commands —
        if let result = handleGraphCommand(lower) {
            commandHistory.append((query: query, response: result))
            isRunningCommand = false
            return
        }

        // — Window/UI commands —
        if let result = handleUICommand(lower) {
            commandHistory.append((query: query, response: result))
            isRunningCommand = false
            return
        }

        // — Session commands —
        if let result = await handleSessionCommand(lower, original: query) {
            commandHistory.append((query: query, response: result))
            isRunningCommand = false
            return
        }

        // — AI query (anything else) —
        let result = await runAIQuery(query)
        commandHistory.append((query: query, response: result))
        isRunningCommand = false
    }

    // MARK: - Command Handlers

    private func handleNoteCommand(_ lower: String, original: String) async -> String? {
        // Open note
        for prefix in ["open note ", "go to note ", "show note "] {
            if lower.hasPrefix(prefix) {
                let name = original.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                if let pageId = findNoteByTitle(name) {
                    NoteWindowManager.shared.open(pageId: pageId)
                    return "Opened note: \(name)"
                }
                return "No note matching \"\(name)\". Try a different title."
            }
        }

        // Create note
        if lower.hasPrefix("new note ") || lower.hasPrefix("create note ") {
            let title = original.dropFirst(lower.hasPrefix("new note ") ? 9 : 12).trimmingCharacters(in: .whitespaces)
            let resolvedTitle = title.isEmpty ? "Untitled" : title
            if let pageId = await AppBootstrap.shared?.vaultSync.createPage(title: resolvedTitle) {
                // Save context before opening window to ensure SwiftData sees the new page
                try? AppBootstrap.shared?.modelContainer.mainContext.save()
                try? await Task.sleep(for: .milliseconds(100))
                NoteWindowManager.shared.open(pageId: pageId)
                return "Created and opened: \(resolvedTitle)"
            }
            return "Failed to create note."
        }

        // Create note WITH content (from session)
        if lower.hasPrefix("save session as note") || lower.hasPrefix("export session") || lower.hasPrefix("create session note") {
            return await createSessionNote()
        }

        // Write to note
        if lower.hasPrefix("write to note ") || lower.hasPrefix("append to note ") {
            let rest = original.dropFirst(lower.hasPrefix("write to note ") ? 14 : 15)
            let parts = rest.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return "Usage: write to note Title: content to append" }
            let title = parts[0].trimmingCharacters(in: .whitespaces)
            let content = parts[1].trimmingCharacters(in: .whitespaces)
            if let pageId = findNoteByTitle(title) {
                let existing = currentBody(for: pageId)
                NoteFileStorage.writeBody(pageId: pageId, content: existing + "\n\n" + content)
                return "Appended to \"\(title)\"."
            }
            return "No note matching \"\(title)\"."
        }

        // Close note
        if lower.hasPrefix("close note ") {
            let name = original.dropFirst(11).trimmingCharacters(in: .whitespaces)
            if let pageId = findNoteByTitle(name) {
                NoteWindowManager.shared.closeWindowDisplaying(pageId: pageId)
                return "Closed note: \(name)"
            }
            return "No open note matching \"\(name)\"."
        }

        // List notes
        if lower == "list notes" || lower == "my notes" || lower == "open notes" {
            let titles = NoteWindowManager.shared.orderedPageIds().compactMap {
                NoteWindowManager.shared.navState(forTab: $0)?.currentPageTitle ?? "Untitled"
            }
            return titles.isEmpty ? "No notes open." : "Open notes: \(titles.joined(separator: ", "))"
        }

        // Summarize a specific note
        if lower.hasPrefix("summarize note ") {
            let name = original.dropFirst(15).trimmingCharacters(in: .whitespaces)
            if let pageId = findNoteByTitle(name) {
                let body = currentBody(for: pageId)
                let snippet = String(body.prefix(600))
                do {
                    let summary = try await AppleIntelligenceService.shared.generate(
                        prompt: "Summarize this document in 2-3 sentences:\n\n\(snippet)",
                        systemPrompt: "You are a document summarizer."
                    )
                    return summary.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    return "Could not summarize."
                }
            }
            return "No note matching \"\(name)\"."
        }

        return nil
    }

    private func handleChatCommand(_ lower: String, original: String) async -> String? {
        for prefix in ["open chat ", "show chat "] {
            if lower.hasPrefix(prefix) {
                let name = original.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                if let chatId = findChatByTitle(name) {
                    MiniChatWindowController.shared.openChat(chatId)
                    return "Opened chat: \(name)"
                }
                return "No chat matching \"\(name)\"."
            }
        }

        if lower == "new chat" || lower == "new mini chat" {
            MiniChatWindowController.shared.openNewChat()
            return "Opened a new mini chat."
        }

        if lower == "list chats" || lower == "my chats" {
            let ids = MiniChatWindowController.shared.openChatIds
            return ids.isEmpty ? "No mini chats open." : "\(ids.count) mini chat\(ids.count == 1 ? "" : "s") open."
        }

        if lower == "close all chats" {
            MiniChatWindowController.shared.closeAll()
            return "Closed all mini chats."
        }

        return nil
    }

    private func handleGraphCommand(_ lower: String) -> String? {
        if lower == "open graph" || lower == "show graph" {
            HologramController.shared.show()
            return "Opened the knowledge graph."
        }
        if lower == "hide graph" || lower == "close graph" {
            HologramController.shared.hide()
            return "Closed the knowledge graph."
        }
        if lower == "minimize graph" {
            HologramController.shared.minimize()
            return "Minimized the graph."
        }
        if lower.hasPrefix("reveal ") || lower.hasPrefix("find in graph ") {
            let name = lower.hasPrefix("reveal ") ? String(lower.dropFirst(7)) : String(lower.dropFirst(14))
            if let pageId = findNoteByTitle(name) {
                HologramController.shared.revealPage(pageId)
                return "Revealing \"\(name)\" in the knowledge graph."
            }
            return "No note matching \"\(name)\" to reveal."
        }
        if lower == "graph stats" {
            let nodes = AppBootstrap.shared?.graphState.store.nodes.count ?? 0
            let edges = AppBootstrap.shared?.graphState.store.edges.count ?? 0
            return "Graph: \(nodes) nodes, \(edges) edges."
        }
        return nil
    }

    private func handleUICommand(_ lower: String) -> String? {
        if lower == "show settings" || lower == "open settings" {
            UtilityWindowManager.shared.show(.settings)
            return "Opened settings."
        }
        if lower == "show notes" || lower == "open notes browser" {
            UtilityWindowManager.shared.show(.notes)
            return "Opened notes browser."
        }
        if lower == "go home" || lower == "home" {
            AppBootstrap.shared?.chatState.goHome()
            AppBootstrap.shared?.uiState.setActivePanel(.home)
            return "Navigated home."
        }
        if lower == "close all" || lower == "close everything" {
            NoteWindowManager.shared.resetForVaultRebuild()
            MiniChatWindowController.shared.closeAll()
            UtilityWindowManager.shared.hide(.notes)
            UtilityWindowManager.shared.hide(.settings)
            HologramController.shared.hide()
            return "Closed all windows and panels."
        }
        if lower == "save workspace" {
            AppBootstrap.shared?.workspaceService.autoSave()
            return "Workspace saved."
        }
        return nil
    }

    private func handleSessionCommand(_ lower: String, original: String) async -> String? {
        // Save session as a note
        if lower.hasPrefix("save session as note") || lower == "export session" || lower == "create session note" {
            return await createSessionNote()
        }
        // Activity stats
        if lower == "activity" || lower == "stats" || lower == "session stats" {
            guard let tracker = AppBootstrap.shared?.activityTracker else { return "No tracker." }
            let digest = tracker.buildDigest(since: tracker.trackingStartedAt ?? Date())
            var lines: [String] = ["Session: \(digest.sessionDurationMinutes) minutes"]
            for note in digest.editedNotes {
                lines.append("Edited \"\(note.title)\": \(note.changedParagraphCount)/\(note.totalParagraphs) paragraphs")
            }
            if digest.chatMessageCount > 0 {
                lines.append("\(digest.chatMessageCount) chat messages")
            }
            return lines.joined(separator: "\n")
        }
        // Summarize chats
        if lower.contains("summarize") && (lower.contains("chat") || lower.contains("conversation")) {
            return await summarizeChats()
        }
        return nil
    }

    // MARK: - Chat Summarization

    private func summarizeChats() async -> String {
        guard let bootstrap = AppBootstrap.shared else { return "App not ready." }
        let context = bootstrap.modelContainer.mainContext

        // Get today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        // Query EventStore for chat events today
        let events = EventStore.shared?.events(from: startOfDay, to: Date()) ?? []
        let chatEvents = events.filter { $0.kind == "chat_message" }

        guard !chatEvents.isEmpty else {
            return "No chat messages found today."
        }

        // Group by chatId and extract snippets
        var chatGroups: [String: [String]] = [:]
        for event in chatEvents {
            if let data = event.payload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chatId = json["chatId"] as? String,
               let snippet = json["snippet"] as? String {
                chatGroups[chatId, default: []].append(snippet)
            }
        }

        guard !chatGroups.isEmpty else {
            return "\(chatEvents.count) chat events found but could not parse details."
        }

        // Build a brief summary
        var summaryParts: [String] = []
        for (chatId, snippets) in chatGroups.prefix(10) {
            // Try to find the chat title
            let targetId = chatId
            let chatDesc = FetchDescriptor<SDChat>(
                predicate: #Predicate<SDChat> { $0.id == targetId }
            )
            let chatTitle = (try? context.fetch(chatDesc).first?.title) ?? "Chat"
            let preview = snippets.prefix(3).joined(separator: " | ")
            summaryParts.append("**\(chatTitle)** (\(snippets.count) messages): \(String(preview.prefix(120)))")
        }

        return "Today's chats (\(chatGroups.count) conversation\(chatGroups.count == 1 ? "" : "s"), \(chatEvents.count) messages):\n" + summaryParts.joined(separator: "\n")
    }

    // MARK: - Create Session Note

    private func createSessionNote() async -> String {
        guard let bootstrap = AppBootstrap.shared else { return "App not ready." }

        // Build note content from session data
        var content = "# Session Summary\n\n"
        content += "**Date:** \(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))\n\n"

        // Open notes
        let noteIds = NoteWindowManager.shared.orderedPageIds()
        if !noteIds.isEmpty {
            content += "## Open Notes\n"
            for pageId in noteIds {
                let title = NoteWindowManager.shared.navState(forTab: pageId)?.currentPageTitle ?? "Untitled"
                let body = currentBody(for: pageId)
                let wordCount = body.split(separator: " ").count
                content += "- **\(title)** (\(wordCount) words)\n"
            }
            content += "\n"
        }

        // Activity
        let digest = bootstrap.activityTracker.buildDigest(since: bootstrap.activityTracker.trackingStartedAt ?? Date())
        if !digest.editedNotes.isEmpty {
            content += "## Edits\n"
            for note in digest.editedNotes {
                content += "- \(note.title): \(note.changedParagraphCount)/\(note.totalParagraphs) paragraphs changed\n"
            }
            content += "\n"
        }

        // AI summary
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        if let ws = try? bootstrap.modelContainer.mainContext.fetch(FetchDescriptor(predicate: predicate)).first,
           !ws.summary.isEmpty {
            content += "## AI Summary\n\(ws.summary)\n\n"
        }

        // Chat history from command panel
        if !commandHistory.isEmpty {
            content += "## Session Chat\n"
            for entry in commandHistory {
                content += "**You:** \(entry.query)\n**AI:** \(entry.response)\n\n"
            }
        }

        // Create the note
        if let pageId = await bootstrap.vaultSync.createPage(title: "Session Summary", body: content) {
            NoteWindowManager.shared.open(pageId: pageId)
            return "Created session summary note with \(content.count) characters. Opened in a new tab."
        }
        return "Failed to create session note."
    }

    // MARK: - AI Query with Action Extraction

    private func runAIQuery(_ query: String) async -> String {
        guard let bootstrap = AppBootstrap.shared else { return "AI not available." }

        // First: try to detect intent and execute directly (smarter than exact prefix)
        let lower = query.lowercased()

        // "create me a note" / "make a note called X" / "please create the note"
        if lower.contains("create") && lower.contains("note") || lower.contains("make") && lower.contains("note") {
            // Extract title from query
            var title = "Session Note"
            if let range = query.range(of: "(?:called|titled|title|named)\\s+[\"']?(.+?)[\"']?$", options: .regularExpression, range: query.startIndex..<query.endIndex) {
                title = String(query[range]).replacingOccurrences(of: "called ", with: "").replacingOccurrences(of: "titled ", with: "").replacingOccurrences(of: "title ", with: "").replacingOccurrences(of: "named ", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            } else if lower.contains("session") {
                return await createSessionNote()
            }
            if let pageId = await bootstrap.vaultSync.createPage(title: title) {
                try? bootstrap.modelContainer.mainContext.save()
                try? await Task.sleep(for: .milliseconds(100))
                NoteWindowManager.shared.open(pageId: pageId)
                return "Created and opened note: \"\(title)\""
            }
            return "Failed to create note."
        }

        // "open it" / "open that" / "go to it" — open the last mentioned note/chat
        if (lower == "open it" || lower == "open that" || lower.contains("open it up") || lower.contains("please open")) {
            // Try to find the last note title mentioned in chat history
            for entry in commandHistory.reversed() {
                let combined = entry.query + " " + entry.response
                if let pageId = extractAndFindNote(from: combined) {
                    NoteWindowManager.shared.open(pageId: pageId)
                    return "Opened the note."
                }
            }
            return "Not sure which note to open. Try: open note <title>"
        }

        // "summarize everything" / "give me a summary"
        if lower.contains("summarize") && (lower.contains("everything") || lower.contains("all") || lower.contains("session")) {
            return await createSessionNote()
        }

        // Fall through to AI
        let context = ChatCoordinator.buildWorkspaceAwarenessContext(bootstrap: bootstrap, deepContext: true)

        // List available notes for the AI to reference
        let noteList = NoteWindowManager.shared.orderedPageIds().compactMap {
            NoteWindowManager.shared.navState(forTab: $0)?.currentPageTitle
        }.joined(separator: ", ")

        let prompt = """
        Context about the user's current workspace:
        \(context)

        Available notes: \(noteList)

        User asks: \(query)

        IMPORTANT: If the user asks you to create a note, open a note, or perform an action, respond with the action result. You have the ability to create notes, open notes, navigate the app. Be direct and helpful. If you need to suggest a command, format it as: [CMD: command here]
        """

        let systemPrompt = """
        You are a workspace assistant with full control over Epistemos. Answer concisely.
        When you want to perform an action, output EXACTLY one of these commands on its own line:
        [CREATE_NOTE: title] — Create a new note with the given title
        [OPEN_NOTE: title] — Open an existing note by title
        [NAVIGATE_GRAPH: nodeId] — Reveal a node in the knowledge graph
        [CLOSE_NOTE: title] — Close a note window
        [SAVE_SESSION] — Save the session as a note
        You may include natural language before or after the command. Always include the command when performing an action.
        """

        do {
            let response: String
            switch chatModel {
            case .appleAI:
                response = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt, systemPrompt: systemPrompt
                )
            case .local:
                response = try await bootstrap.triageService.generate(
                    prompt: prompt, systemPrompt: systemPrompt,
                    operation: .ask(query: query), contentLength: prompt.count, query: query
                )
            }

            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract and execute bracketed commands from AI response
            let actionResult = await extractAndExecuteActions(from: cleaned)
            if let actionResult {
                let textWithoutCommands = cleaned.replacingOccurrences(
                    of: "\\[\\w+(?:_\\w+)*:\\s*.+?\\]|\\[SAVE_SESSION\\]",
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                let display = textWithoutCommands.isEmpty ? actionResult : textWithoutCommands + "\n" + actionResult
                return display
            }

            // Legacy: also check [CMD: ...] format
            if let cmdRange = cleaned.range(of: "\\[CMD:\\s*(.+?)\\]", options: .regularExpression) {
                let cmd = String(cleaned[cmdRange])
                    .replacingOccurrences(of: "[CMD: ", with: "")
                    .replacingOccurrences(of: "[CMD:", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                commandInput = cmd
                let textWithoutCmd = cleaned.replacingOccurrences(of: String(cleaned[cmdRange]), with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                Task { await executeCommand() }
                return textWithoutCmd.isEmpty ? "Executing: \(cmd)" : textWithoutCmd
            }

            return cleaned
        } catch {
            return "Could not generate response."
        }
    }

    /// Parse bracketed commands like [CREATE_NOTE: title], [OPEN_NOTE: title], etc. and execute them.
    private func extractAndExecuteActions(from text: String) async -> String? {
        // Match patterns like [CREATE_NOTE: My Title] or [SAVE_SESSION]
        let pattern = "\\[(\\w+(?:_\\w+)*)(?::\\s*(.+?))?\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        guard let actionRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let action = String(text[actionRange]).uppercased()
        let argument: String
        if match.range(at: 2).location != NSNotFound,
           let argumentRange = Range(match.range(at: 2), in: text) {
            argument = String(text[argumentRange]).trimmingCharacters(in: .whitespaces)
        } else {
            argument = ""
        }

        switch action {
        case "CREATE_NOTE":
            let title = argument.isEmpty ? "Untitled" : argument
            guard let bootstrap = AppBootstrap.shared else { return "App not ready." }
            if let pageId = await bootstrap.vaultSync.createPage(title: title) {
                try? bootstrap.modelContainer.mainContext.save()
                try? await Task.sleep(for: .milliseconds(100))
                NoteWindowManager.shared.open(pageId: pageId)
                return "Created and opened: \"\(title)\""
            }
            return "Failed to create note."

        case "OPEN_NOTE":
            if let pageId = findNoteByTitle(argument) {
                NoteWindowManager.shared.open(pageId: pageId)
                return "Opened note: \"\(argument)\""
            }
            return "No note matching \"\(argument)\"."

        case "NAVIGATE_GRAPH":
            if let pageId = findNoteByTitle(argument) {
                HologramController.shared.revealPage(pageId)
                return "Revealing \"\(argument)\" in the graph."
            }
            return "No note matching \"\(argument)\" to reveal."

        case "CLOSE_NOTE":
            if let pageId = findNoteByTitle(argument) {
                NoteWindowManager.shared.closeWindowDisplaying(pageId: pageId)
                return "Closed note: \"\(argument)\""
            }
            return "No open note matching \"\(argument)\"."

        case "SAVE_SESSION":
            return await createSessionNote()

        default:
            return nil
        }
    }

    /// Try to find a note title mentioned in text and return its pageId.
    private func extractAndFindNote(from text: String) -> String? {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return nil }
        let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []
        // Check if any note title appears in the text
        for page in pages where !page.title.isEmpty {
            if text.localizedCaseInsensitiveContains(page.title) {
                return page.id
            }
        }
        return nil
    }

    private func findNoteByTitle(_ title: String) -> String? {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return nil }
        let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []
        let lower = title.lowercased()
        return pages.first(where: { $0.title.lowercased().contains(lower) })?.id
    }

    private func findChatByTitle(_ title: String) -> String? {
        guard let context = AppBootstrap.shared?.modelContainer.mainContext else { return nil }
        let chats = (try? context.fetch(FetchDescriptor<SDChat>())) ?? []
        let lower = title.lowercased()
        return chats.first(where: { $0.title.lowercased().contains(lower) })?.id
    }

    private func commandHintRow(_ command: String, _ desc: String) -> some View {
        HStack(spacing: 10) {
            Text(command)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.resolved.accent.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.resolved.accent.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .frame(width: 200, alignment: .leading)
            Text(desc)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = false
        }
    }
}
