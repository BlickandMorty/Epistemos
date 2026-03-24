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

    private var theme: EpistemosTheme { ui.theme }

    struct WindowCard: Identifiable {
        let id: String
        let title: String
        let icon: String
        let kind: String // "note", "chat", "graph"
        var summary: String = ""
        var wordCount: Int = 0
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
            .foregroundStyle(theme.foreground)
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
                    .foregroundStyle(theme.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(theme.accent.opacity(0.12))
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
                    .background(theme.foreground.opacity(0.05), in: Capsule())
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
                .fill(theme.foreground.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.foreground.opacity(0.06))
        }
    }

    // MARK: - Data Collection

    private func buildWindowCards() {
        var cards: [WindowCard] = []

        // Note windows
        for pageId in NoteWindowManager.shared.orderedPageIds() {
            let title = NoteWindowManager.shared.navState(forTab: pageId)?.currentPageTitle ?? "Untitled"
            let body = NoteFileStorage.readBody(pageId: pageId, mapped: true)
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

        // Reduce phase: global synthesis
        await summaryService.generateSummaryNow()
        if let workspace = try? AppBootstrap.shared?.modelContainer.mainContext.fetch(
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
                    VStack(spacing: 8) {
                        Text("Ask about your session or run commands")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textTertiary)
                        Text("Try: \"what am I working on\" \u{2022} \"open note X\" \u{2022} \"summarize my chats\"")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(theme.textTertiary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(commandHistory.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.accent)
                                        .frame(width: 16, height: 16)
                                    Text(entry.query)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.textTertiary)
                                        .frame(width: 16, height: 16)
                                    Text(entry.response)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(theme.textSecondary)
                                        .textSelection(.enabled)
                                }
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
                    .foregroundStyle(theme.accent)

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
                            .font(.system(size: 16))
                            .foregroundStyle(commandInput.isEmpty ? theme.textTertiary : theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(commandInput.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.foreground.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

        // Direct commands: open note, open chat
        if lower.hasPrefix("open note ") || lower.hasPrefix("go to note ") || lower.hasPrefix("show note ") {
            let noteQuery = query.dropFirst(lower.hasPrefix("open note ") ? 10 : (lower.hasPrefix("go to note ") ? 11 : 10))
                .trimmingCharacters(in: .whitespaces)
            if let pageId = findNoteByTitle(String(noteQuery)) {
                NoteWindowManager.shared.open(pageId: pageId)
                commandHistory.append((query: query, response: "Opened note: \(noteQuery)"))
                isRunningCommand = false
                return
            } else {
                commandHistory.append((query: query, response: "Could not find a note matching \"\(noteQuery)\"."))
                isRunningCommand = false
                return
            }
        }

        if lower.hasPrefix("open chat ") || lower.hasPrefix("show chat ") {
            let chatQuery = query.dropFirst(10).trimmingCharacters(in: .whitespaces)
            if let chatId = findChatByTitle(String(chatQuery)) {
                MiniChatWindowController.shared.openChat(chatId)
                commandHistory.append((query: query, response: "Opened chat: \(chatQuery)"))
                isRunningCommand = false
                return
            } else {
                commandHistory.append((query: query, response: "Could not find a chat matching \"\(chatQuery)\"."))
                isRunningCommand = false
                return
            }
        }

        if lower == "open graph" || lower == "show graph" {
            HologramController.shared.show()
            commandHistory.append((query: query, response: "Opened the knowledge graph."))
            isRunningCommand = false
            return
        }

        if lower.hasPrefix("new note") {
            let title = query.dropFirst(8).trimmingCharacters(in: .whitespaces)
            let resolvedTitle = title.isEmpty ? "Untitled" : title
            if let pageId = await AppBootstrap.shared?.vaultSync.createPage(title: resolvedTitle) {
                NoteWindowManager.shared.open(pageId: pageId)
                commandHistory.append((query: query, response: "Created and opened new note: \(resolvedTitle)"))
            }
            isRunningCommand = false
            return
        }

        if lower == "new chat" || lower == "new mini chat" {
            MiniChatWindowController.shared.openNewChat()
            commandHistory.append((query: query, response: "Opened a new mini chat."))
            isRunningCommand = false
            return
        }

        // AI query — ask about the session with full workspace context
        do {
            guard let triage = AppBootstrap.shared?.triageService,
                  let bootstrap = AppBootstrap.shared else {
                commandHistory.append((query: query, response: "AI not available."))
                isRunningCommand = false
                return
            }
            let context = ChatCoordinator.buildWorkspaceAwarenessContext(bootstrap: bootstrap, deepContext: true)
            let prompt = "Context about the user's current workspace:\n\(context)\n\nUser asks: \(query)"
            let response = try await triage.generate(
                prompt: prompt,
                systemPrompt: "You are a workspace assistant embedded in the Session Intelligence panel. Answer questions about the user's current session, open notes, chats, and activity. Be concise (2-3 sentences). If the user asks to navigate somewhere, tell them to use commands like 'open note X' or 'open chat Y'.",
                operation: .ask(query: query),
                contentLength: prompt.count,
                query: query
            )
            commandHistory.append((query: query, response: response.trimmingCharacters(in: .whitespacesAndNewlines)))
        } catch {
            commandHistory.append((query: query, response: "Could not generate response."))
        }
        isRunningCommand = false
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

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = false
        }
    }
}
