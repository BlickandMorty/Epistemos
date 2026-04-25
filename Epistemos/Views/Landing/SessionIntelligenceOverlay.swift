import SwiftData
import SwiftUI

enum SessionIntelligenceNoteLookup {
    nonisolated static func candidateTitles(in text: String) -> [String] {
        var candidates: [String] = []
        var seen: Set<String> = []

        func append(_ raw: String) {
            let candidate = normalizeCandidate(raw)
            guard candidate.count > 1 else { return }
            let key = candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { return }
            candidates.append(candidate)
        }

        for match in captureMatches(pattern: bracketedCommandPattern(), in: text) {
            append(match)
        }

        for match in captureMatches(pattern: quotedTitlePattern(), in: text) {
            append(match)
        }

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let lowercasedLine = trimmedLine.lowercased()
            for prefix in commandPrefixes() {
                guard let prefixRange = lowercasedLine.range(of: prefix) else { continue }
                let startOffset = lowercasedLine.distance(from: lowercasedLine.startIndex, to: prefixRange.upperBound)
                let startIndex = trimmedLine.index(trimmedLine.startIndex, offsetBy: startOffset)
                append(String(trimmedLine[startIndex...]))
            }
        }

        return candidates
    }

    private nonisolated static func quotedTitlePattern() -> String {
        #"[\"'“”]([^\"'“”\n]{2,160})[\"'“”]"#
    }

    private nonisolated static func bracketedCommandPattern() -> String {
        #"\[(?:CREATE_NOTE|OPEN_NOTE|NAVIGATE_GRAPH|CLOSE_NOTE):\s*(.+?)\]"#
    }

    private nonisolated static func commandPrefixes() -> [String] {
        [
            "created and opened note: ",
            "created and opened: ",
            "opened note: ",
            "closed note: ",
            "open note ",
            "close note ",
            "summarize note ",
            "write to note ",
            "show note ",
            "navigate to note ",
            "reveal note ",
            "reveal "
        ]
    }

    private nonisolated static func captureMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[captureRange])
        }
    }

    private nonisolated static func normalizeCandidate(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”[]"))

        let lowercased = cleaned.lowercased()
        for suffix in [" in the graph", " in graph"] where lowercased.hasSuffix(suffix) {
            cleaned.removeLast(suffix.count)
            break
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

nonisolated struct SessionIntelligenceChatGroup: Equatable, Sendable {
    let chatId: String
    let snippets: [String]
}

enum SessionIntelligenceChatSummary {
    nonisolated static func orderedGroups(
        from groups: [String: [String]],
        limit: Int
    ) -> [SessionIntelligenceChatGroup] {
        guard limit > 0 else { return [] }

        return groups
            .map { SessionIntelligenceChatGroup(chatId: $0.key, snippets: $0.value) }
            .sorted { lhs, rhs in
                if lhs.snippets.count != rhs.snippets.count {
                    return lhs.snippets.count > rhs.snippets.count
                }
                return lhs.chatId < rhs.chatId
            }
            .prefix(limit)
            .map { $0 }
    }
}

private enum SessionIntelligenceOverlayTiming {
    nonisolated static func notePresentationDelay() -> Duration { .milliseconds(100) }
    nonisolated static func dismissDelay() -> Duration { .milliseconds(150) }
}

// MARK: - Session Intelligence Overlay
// Full-screen overlay triggered by Cmd+Ctrl+R. Shows a visual map of all open windows
// with per-window AI summaries typed progressively, followed by a global synthesis.
// Uses the Map-Reduce pipeline from WorkspaceSummaryService.

struct SessionIntelligenceOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool

    @State private var windowCards: [WindowCard] = []
    @State private var globalSynthesis = ""
    @State private var isGenerating = true
    @State private var appeared = false
    @State private var actionStatusMessage = ""
    @State private var generationTask: Task<Void, Never>?

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

                sessionActionSection
            }
            .frame(width: 680, height: 460)
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
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { appeared = true }
            buildWindowCards()
            generationTask?.cancel()
            generationTask = Task { @MainActor in
                await generateIntelligence()
            }
        }
        .onDisappear {
            generationTask?.cancel()
            generationTask = nil
        }
    }

    private var sessionActionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Workspace Snapshot")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)

                Text(sessionSnapshotLine)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button("Save Session Note") {
                    Task {
                        actionStatusMessage = await createSessionNote()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Open Notes") {
                    UtilityWindowManager.shared.show(.notes)
                    actionStatusMessage = "Opened notes browser."
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(HologramController.shared.isVisible ? "Focus Graph" : "Open Graph") {
                    if HologramController.shared.isVisible {
                        HologramController.shared.show()
                        actionStatusMessage = "Focused the knowledge graph."
                    } else {
                        HologramController.shared.show()
                        actionStatusMessage = "Opened the knowledge graph."
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            if !actionStatusMessage.isEmpty {
                Text(actionStatusMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private var sessionSnapshotLine: String {
        let noteCount = windowCards.filter { $0.kind == "note" }.count
        let chatCount = windowCards.filter { $0.kind == "chat" || $0.kind == "mini chat" }.count
        let graphCount = windowCards.filter { $0.kind.contains("graph") }.count

        var parts: [String] = []
        if noteCount > 0 { parts.append("\(noteCount) note\(noteCount == 1 ? "" : "s")") }
        if chatCount > 0 { parts.append("\(chatCount) chat\(chatCount == 1 ? "" : "s")") }
        if graphCount > 0 { parts.append("knowledge graph") }

        if parts.isEmpty {
            return "No active notes or chats are open right now."
        }

        return "Live workspace overview of \(parts.joined(separator: ", ")). Use the actions below to export or jump into the surfaces you already have open."
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

        if let mainChatCard = activeMainChatCard() {
            cards.append(mainChatCard)
        }

        // Mini chats
        for chatId in MiniChatWindowController.shared.openChatIds {
            cards.append(openMiniChatCard(for: chatId))
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

    private func activeMainChatCard() -> WindowCard? {
        guard let chatState = AppBootstrap.shared?.chatState,
              !chatState.messages.isEmpty || chatState.isStreaming else {
            return nil
        }

        let title = chatState.chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedTitle = title.isEmpty ? "Main Chat" : title
        let summary = ChatPreviewText.preview(
            for: chatState.messages,
            streamingText: chatState.isStreaming ? chatState.streamingText : nil
        ) ?? ChatPreviewText.emptyPreview

        return WindowCard(
            id: "chat-main",
            title: resolvedTitle,
            icon: "bubble.left.and.text.bubble.right.fill",
            kind: "chat",
            summary: summary
        )
    }

    private func currentBody(for pageId: String) -> String {
        NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
    }

    private func openMiniChatCard(for chatId: String) -> WindowCard {
        let title = openMiniChatTitle(for: chatId)
        let summary = openMiniChatSummary(for: chatId)
        return WindowCard(
            id: "chat-\(chatId)",
            title: title,
            icon: "bubble.left.and.bubble.right.fill",
            kind: "mini chat",
            summary: summary
        )
    }

    private func openMiniChatTitle(for chatId: String) -> String {
        if let threadTitle = AppBootstrap.shared?.threadState.miniChatSession(id: chatId)?.label
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !threadTitle.isEmpty {
            return threadTitle
        }

        guard let context = AppBootstrap.shared?.modelContainer.mainContext else {
            return "Mini Chat"
        }

        let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatId })
        let persisted: SDChat?
        do {
            persisted = try context.fetch(descriptor).first
        } catch {
            Log.app.error(
                "SessionIntelligenceOverlay: failed to fetch mini chat title for \(String(chatId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return "Mini Chat"
        }
        let title = persisted?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Mini Chat" : title
    }

    private func openMiniChatSummary(for chatId: String) -> String {
        if let threadState = AppBootstrap.shared?.threadState,
           let thread = threadState.miniChatSession(id: chatId),
           let preview = ChatPreviewText.preview(
            for: thread,
            streamingText: threadState.miniChatIsStreaming(chatID: chatId)
                ? threadState.miniChatStreamingText(chatID: chatId)
                : nil
           ) {
            return preview
        }

        guard let context = AppBootstrap.shared?.modelContainer.mainContext else {
            return ChatPreviewText.emptyPreview
        }

        let descriptor = FetchDescriptor<SDChat>(predicate: #Predicate { $0.id == chatId })
        let persisted: SDChat?
        do {
            persisted = try context.fetch(descriptor).first
        } catch {
            Log.app.error(
                "SessionIntelligenceOverlay: failed to fetch mini chat summary for \(String(chatId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return ChatPreviewText.emptyPreview
        }
        guard let persisted else {
            return ChatPreviewText.emptyPreview
        }

        return ChatPreviewText.preview(for: persisted) ?? ChatPreviewText.emptyPreview
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
        } else if let summary = latestAutoSavedWorkspaceSummary() {
            globalSynthesis = summary
        }

        isGenerating = false
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

        let chatCards = windowCards.filter { $0.kind == "chat" || $0.kind == "mini chat" }
        if !chatCards.isEmpty {
            content += "## Open Chats\n"
            for card in chatCards {
                content += "- **\(card.title)**: \(card.summary.isEmpty ? ChatPreviewText.emptyPreview : card.summary)\n"
            }
            content += "\n"
        }

        // AI summary
        if let summary = latestAutoSavedWorkspaceSummary(in: bootstrap.modelContainer.mainContext) {
            content += "## AI Summary\n\(summary)\n\n"
        }

        // Create the note
        if let pageId = await bootstrap.vaultSync.createPage(
            title: "Session Summary",
            body: content,
            allowVaultSelectionPrompt: true
        ) {
            NoteWindowManager.shared.open(pageId: pageId)
            return "Created session summary note with \(content.count) characters. Opened in a new tab."
        }
        return "Failed to create session note."
    }

    private func createAndOpenNote(title: String, body: String? = nil) async -> String? {
        guard let bootstrap = AppBootstrap.shared else { return nil }

        let pageId: String?
        if let body {
            pageId = await bootstrap.vaultSync.createPage(
                title: title,
                body: body,
                allowVaultSelectionPrompt: true
            )
        } else {
            pageId = await bootstrap.vaultSync.createPage(
                title: title,
                allowVaultSelectionPrompt: true
            )
        }

        guard let pageId else { return nil }
        do {
            try bootstrap.modelContainer.mainContext.save()
        } catch {
            Log.app.error(
                "SessionIntelligenceOverlay: failed to save created session note \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        guard await pause(SessionIntelligenceOverlayTiming.notePresentationDelay()) else { return nil }
        NoteWindowManager.shared.open(pageId: pageId)
        return pageId
    }

    private func latestAutoSavedWorkspaceSummary(in context: ModelContext? = AppBootstrap.shared?.modelContainer.mainContext) -> String? {
        guard let context else { return nil }

        var descriptor = FetchDescriptor<SDWorkspace>(
            predicate: #Predicate<SDWorkspace> { $0.isAutoSave == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let workspace: SDWorkspace?
        do {
            workspace = try context.fetch(descriptor).first
        } catch {
            Log.app.error(
                "SessionIntelligenceOverlay: failed to fetch autosaved workspace summary: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        guard let workspace, !workspace.summary.isEmpty else {
            return nil
        }
        return workspace.summary
    }

    private func pause(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            Log.app.error(
                "SessionIntelligenceOverlay: timing pause failed: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    private func dismiss() {
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.15)) { appeared = false }
        generationTask?.cancel()
        generationTask = nil
        if reduceMotion {
            isPresented = false
            return
        }
        Task { @MainActor in
            guard await pause(SessionIntelligenceOverlayTiming.dismissDelay()) else { return }
            isPresented = false
        }
    }
}
