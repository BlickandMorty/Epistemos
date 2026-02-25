import SwiftData
import SwiftUI

// MARK: - MiniChat View
// Floating chat panel with thread tabs + input.

struct MiniChatView: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    @State private var showRecentChats = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            MiniChatTabBar(showRecentChats: $showRecentChats)
            Divider().opacity(0.3)
            if showRecentChats {
                MiniChatRecentChats(showRecentChats: $showRecentChats)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                MiniChatThread()
                    .transition(.opacity)
            }
            Divider().opacity(0.3)
            MiniChatInputBar()
        }
        .animation(Motion.snap, value: showRecentChats)
        .frame(width: 400, height: 520)
        .background {
            if theme.isDark {
                // Dark mode: opaque tinted base + thin glass for depth
                ZStack {
                    theme.background.opacity(0.92)
                    Rectangle().fill(.ultraThinMaterial).opacity(0.3)
                }
            } else {
                // Light mode: solid themed background, no blur
                theme.background
            }
        }
        .onAppear {
            if threadState.chatThreads.isEmpty {
                threadState.createThread(label: "Chat 1")
            }
        }
    }
}

// MARK: - Tab Bar

private struct MiniChatTabBar: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Binding var showRecentChats: Bool

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 0) {
            // Recent chats toggle
            Button {
                withAnimation(Motion.snap) {
                    showRecentChats.toggle()
                }
            } label: {
                Image(systemName: showRecentChats ? "sidebar.left" : "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(showRecentChats ? theme.accent : theme.mutedForeground)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Recent Chats")
            .accessibilityLabel("Recent Chats")

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 4)
                .opacity(0.5)

            // Scrollable thread tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(threadState.chatThreads) { thread in
                        ThreadTab(
                            thread: thread,
                            isActive: thread.id == threadState.activeThreadId
                        )
                        .onTapGesture { threadState.setActiveThread(thread.id) }
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)

            // New thread
            Button {
                let count = threadState.chatThreads.count + 1
                threadState.createThread(label: "Chat \(count)")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("New Chat")
            .accessibilityLabel("New Chat")
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
    }
}

// MARK: - Thread Tab

private struct ThreadTab: View {
    let thread: ChatThread
    let isActive: Bool

    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 4) {
            Text(thread.label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? theme.foreground : theme.mutedForeground)
                .lineLimit(1)
                .frame(maxWidth: 90)

            Button {
                threadState.closeThread(thread.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close tab")
            .opacity(isActive || isHovered ? 1 : 0)
            .animation(Motion.quick, value: isActive || isHovered)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isActive
                ? theme.accent.opacity(0.15)
                : (isHovered ? theme.foreground.opacity(0.06) : Color.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? theme.accent.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .animation(Motion.quick, value: isActive)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Thread View

private struct MiniChatThread: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState

    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    private var theme: EpistemosTheme { ui.theme }

    private var activeThread: ChatThread? {
        threadState.chatThreads.first { $0.id == threadState.activeThreadId }
    }

    private var hasContent: Bool {
        if let thread = activeThread, !thread.messages.isEmpty { return true }
        return threadState.miniChatIsStreaming
    }

    var body: some View {
        Group {
            if hasContent {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if let thread = activeThread {
                                ForEach(thread.messages) { msg in
                                    MiniChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }

                            // Live streaming bubble
                            if threadState.miniChatIsStreaming {
                                VStack(alignment: .leading, spacing: 0) {
                                    if threadState.miniChatStreamingText.isEmpty {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text("Thinking…")
                                                .font(.system(size: 12))
                                                .foregroundStyle(theme.mutedForeground)
                                        }
                                    } else {
                                        MarkdownTextView(content: threadState.miniChatStreamingText + " ▍", theme: theme)
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
                    .onChange(of: activeThread?.messages.count) { _, _ in
                        withAnimation(Motion.quick) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: threadState.miniChatStreamingText) { _, _ in
                        // Throttle to ~4fps during streaming (matches ChatView)
                        let now = ContinuousClock.now
                        guard now - lastScrollTime > .milliseconds(250) else { return }
                        lastScrollTime = now
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(theme.mutedForeground.opacity(0.3))
                    Text("Start a conversation")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chat Bubble

private struct MiniChatBubble: View {
    let message: AssistantMessage

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

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

// MARK: - Input Bar

private struct MiniChatInputBar: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Environment(NotesUIState.self) private var notesUI
    @Environment(TriageService.self) private var triage
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var isProcessing = false
    @State private var streamTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var theme: EpistemosTheme { ui.theme }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Quick action chips when a note is active
            if notesUI.activePageId != nil, activePage() != nil, !isProcessing {
                quickActions
            }

            // Note context indicator
            if notesUI.activePageId != nil, let page = activePage() {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.accent)
                    Text("Referencing: \(page.title.isEmpty ? "Untitled" : page.title)")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }

            HStack(spacing: 8) {
                TextField("Ask anything...", text: $text, axis: .vertical)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .writingToolsBehavior(.limited)
                    .foregroundStyle(theme.foreground)
                    .onSubmit { send() }

                if isProcessing {
                    Button {
                        cancelStream()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Stop")
                    .accessibilityLabel("Stop generating")
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(canSend ? theme.accent : theme.mutedForeground.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .help("Send")
                    .accessibilityLabel("Send message")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                QuickActionChip(icon: "tag", label: "Auto-tag", color: theme.accent) {
                    runQuickAction(.autoTag)
                }
                QuickActionChip(icon: "doc.text.magnifyingglass", label: "Summarize", color: .orange) {
                    runQuickAction(.summarize)
                }
                QuickActionChip(icon: "link", label: "Find Related", color: .purple) {
                    runQuickAction(.findRelated)
                }
                QuickActionChip(icon: "square.and.pencil", label: "Create From This", color: .green) {
                    runQuickAction(.createFromNote)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Active Page

    private func activePage() -> SDPage? {
        guard let pageId = notesUI.activePageId else { return nil }
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Vault Search

    /// Search the vault for notes relevant to the query.
    /// Two-pass: title-only filter first (cheap), then body for a small subset.
    /// Avoids loading all externally-stored body blobs into memory.
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

        // Pass 1: title-only (no body access)
        var matches = pages.filter { page in
            guard page.id != activeId else { return false }
            let title = page.title.lowercased()
            return terms.contains { title.contains($0) }
        }

        // Pass 2: if few title matches, check body for a small subset
        if matches.count < 3 {
            let titleIds = Set(matches.map(\.id))
            let candidates = pages.prefix(30).filter {
                $0.id != activeId && !titleIds.contains($0.id)
            }
            let bodyMatches = candidates.filter { page in
                let body = page.body.lowercased()
                return terms.contains { body.contains($0) }
            }
            matches.append(contentsOf: bodyMatches)
        }

        return Array(matches
            .prefix(3)
            .map { (title: $0.title, snippet: String($0.body.prefix(300))) })
    }

    // MARK: - Quick Action Execution

    private enum QuickAction { case autoTag, summarize, findRelated, createFromNote }

    private func runQuickAction(_ action: QuickAction) {
        guard let page = activePage(), !isProcessing else { return }
        let pageTitle = page.title
        let snippet = String(page.body.prefix(2000))

        let actionLabel: String
        let prompt: String
        let systemPrompt: String

        switch action {
        case .autoTag:
            let existing = page.tags.joined(separator: ", ")
            actionLabel = "Auto-tag"
            prompt = "Suggest 3-5 tags for this note. Current tags: [\(existing.isEmpty ? "none" : existing)]\n\n# \(pageTitle)\n\(snippet)"
            systemPrompt = """
            You are a note organizer. Suggest short, lowercase tags (1-2 words each). \
            Return your suggestions as a comma-separated list on the first line, then optionally explain briefly. \
            Format: tags: tag1, tag2, tag3
            """
        case .summarize:
            actionLabel = "Summarize"
            prompt = "Summarize this note:\n\n# \(pageTitle)\n\(snippet)"
            systemPrompt = "Produce a concise summary (3-5 sentences). Capture key ideas, arguments, and open questions."
        case .findRelated:
            let vault = searchVault(query: pageTitle)
            let vaultContext = vault.isEmpty ? "No related notes found." : vault.map { "- **\($0.title)**: \($0.snippet)" }.joined(separator: "\n")
            actionLabel = "Find Related"
            prompt = "Find connections between this note and related notes in the vault.\n\n## Current Note: \(pageTitle)\n\(snippet)\n\n## Other Notes\n\(vaultContext)"
            systemPrompt = "Identify thematic connections, contrasts, and potential cross-references between the notes. Be specific about what connects them."
        case .createFromNote:
            actionLabel = "Create From Note"
            prompt = "Based on this note, suggest a good follow-up note to write. Provide a title and a brief outline.\n\n# \(pageTitle)\n\(snippet)"
            systemPrompt = "Suggest one follow-up note with a clear title and 3-5 bullet outline. Format: Title: [title]\\nOutline:\\n- point 1\\n- point 2"
        }

        // Show action as user message
        threadState.addThreadMessage(AssistantMessage(role: .user, content: "✨ \(actionLabel): \(pageTitle)"))
        isProcessing = true
        threadState.miniChatIsStreaming = true
        threadState.miniChatStreamingText = ""

        streamTask = Task {
            defer {
                isProcessing = false
                threadState.miniChatIsStreaming = false
            }
            do {
                let contentLength = prompt.count
                var accumulated = ""

                for try await chunk in triage.streamGeneral(
                    prompt: prompt, systemPrompt: systemPrompt,
                    operation: .brainstorm, contentLength: contentLength
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    threadState.miniChatStreamingText = accumulated
                }

                let final = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""

                // Auto-apply certain actions
                if action == .autoTag {
                    applyAutoTags(from: final, page: page)
                } else if action == .summarize {
                    page.summary = String(final.prefix(500))
                    page.updatedAt = .now
                }

                threadState.addThreadMessage(AssistantMessage(
                    role: .assistant,
                    content: final.isEmpty ? "No response generated." : final
                ))
            } catch is CancellationError {
                let partial = threadState.miniChatStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""
                if !partial.isEmpty {
                    threadState.addThreadMessage(AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"))
                }
            } catch {
                threadState.miniChatStreamingText = ""
                threadState.addThreadMessage(AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
            }
        }
    }

    /// Parse "tags: foo, bar, baz" from AI response and apply to page
    private func applyAutoTags(from response: String, page: SDPage) {
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.hasPrefix("tags:") || lower.hasPrefix("**tags:**") || lower.hasPrefix("- tags:") {
                let raw = line
                    .replacingOccurrences(of: "**tags:**", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "tags:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "- ", with: "")
                let tags = raw.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty && $0.count < 30 }

                let newTags = tags.filter { !page.tags.contains($0) }
                if !newTags.isEmpty {
                    page.tags.append(contentsOf: newTags)
                    page.updatedAt = .now
                }
                return
            }
        }
    }

    // MARK: - Send with Streaming + Action Detection

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        threadState.addThreadMessage(AssistantMessage(role: .user, content: trimmed))
        text = ""
        isProcessing = true
        threadState.miniChatIsStreaming = true
        threadState.miniChatStreamingText = ""

        streamTask = Task {
            defer {
                isProcessing = false
                threadState.miniChatIsStreaming = false
            }
            do {
                // Build context from active note + vault search
                var contextParts: [String] = []
                let page = activePage()

                if let page, !page.body.isEmpty {
                    contextParts.append("## Active Note: \(page.title)\nTags: [\(page.tags.joined(separator: ", "))]\n\(String(page.body.prefix(2000)))")
                }

                let vaultSnippets = searchVault(query: trimmed)
                if !vaultSnippets.isEmpty {
                    let snippetText = vaultSnippets.map { "- **\($0.title)**: \($0.snippet)" }.joined(separator: "\n")
                    contextParts.append("## Related Notes from Vault\n\(snippetText)")
                }

                // Build folder list for move actions
                var folderNames: [String] = []
                let folderDescriptor = FetchDescriptor<SDFolder>(sortBy: [SortDescriptor(\.sortOrder)])
                if let folders = try? modelContext.fetch(folderDescriptor) {
                    folderNames = folders.map(\.name)
                }

                // Check if this is a multi-turn conversation
                let hasHistory = {
                    let thread = threadState.chatThreads.first { $0.id == threadState.activeThreadId }
                    return (thread?.messages.count ?? 0) > 1
                }()
                let conversationNote = hasHistory
                    ? " The user's message includes recent conversation history formatted as 'User:' and 'Assistant:' turns. Respond only to the latest User message, using prior turns for context."
                    : ""

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

                // Build conversation-aware prompt from thread history
                let activeThread = threadState.chatThreads.first { $0.id == threadState.activeThreadId }
                let allMessages = activeThread?.messages ?? []

                let conversationPrompt: String
                if allMessages.count > 1 {
                    let history = allMessages.dropLast().suffix(10)
                    let historyText = history.map { msg in
                        msg.role == .user ? "User: \(msg.content)" : "Assistant: \(msg.content)"
                    }.joined(separator: "\n\n")
                    conversationPrompt = "\(historyText)\n\nUser: \(trimmed)"
                } else {
                    conversationPrompt = trimmed
                }

                let contentLength = conversationPrompt.count + contextParts.joined().count
                var accumulated = ""

                for try await chunk in triage.streamGeneral(
                    prompt: conversationPrompt,
                    systemPrompt: systemPrompt,
                    operation: .chatResponse(query: trimmed),
                    contentLength: contentLength
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    threadState.miniChatStreamingText = accumulated
                }

                var final = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""

                // Parse and execute any action markers
                if let page {
                    final = executeActions(in: final, page: page)
                }

                threadState.addThreadMessage(AssistantMessage(
                    role: .assistant,
                    content: final.isEmpty ? "No response generated." : final
                ))
            } catch is CancellationError {
                let partial = threadState.miniChatStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
                threadState.miniChatStreamingText = ""
                if !partial.isEmpty {
                    threadState.addThreadMessage(AssistantMessage(role: .assistant, content: partial + "\n\n*[Cancelled]*"))
                }
            } catch {
                threadState.miniChatStreamingText = ""
                threadState.addThreadMessage(AssistantMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Action Parsing & Execution

    /// Parse [ACTION:...] markers from AI response, execute them, and return cleaned text.
    private func executeActions(in response: String, page: SDPage) -> String {
        var cleaned = response
        var executedActions: [String] = []

        // TAG action: [ACTION:TAG tag1, tag2, tag3]
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
                executedActions.append("✅ Added tags: \(newTags.joined(separator: ", "))")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // MOVE action: [ACTION:MOVE FolderName]
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
                executedActions.append("✅ Moved to folder: \(folder.name)")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // CREATE action: [ACTION:CREATE Title of New Note]
        if let range = response.range(of: #"\[ACTION:CREATE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let title = marker
                .replacingOccurrences(of: "[ACTION:CREATE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                Task {
                    if let newId = await vaultSync.createPage(title: title) {
                        executedActions.append("✅ Created note: \(title)")
                        NoteWindowManager.shared.open(pageId: newId)
                    }
                }
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // Append action confirmations
        if !executedActions.isEmpty {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned += "\n\n---\n" + executedActions.joined(separator: "\n")
        }

        return cleaned
    }

    private func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
    }
}

// MARK: - Quick Action Chip

private struct QuickActionChip: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? color : theme.mutedForeground.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isHovered ? color.opacity(0.12) : theme.foreground.opacity(0.04))
            )
            .overlay(
                Capsule().stroke(isHovered ? color.opacity(0.2) : theme.foreground.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recent Chats Drawer

private struct MiniChatRecentChats: View {
    @Environment(UIState.self) private var ui
    @Environment(ThreadState.self) private var threadState
    @Environment(\.modelContext) private var modelContext
    @Binding var showRecentChats: Bool
    @State private var mainChats: [SDChat] = []

    private var theme: EpistemosTheme { ui.theme }

    // Show existing mini-chat threads
    private var recentThreads: [ChatThread] {
        threadState.chatThreads.filter { !$0.messages.isEmpty }
    }

    private var hasContent: Bool {
        !recentThreads.isEmpty || !mainChats.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !hasContent {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(theme.mutedForeground.opacity(0.3))
                    Text("No saved chats")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Main chat history (persisted via SwiftData)
                        if !mainChats.isEmpty {
                            HStack {
                                Text("MAIN CHATS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                            ForEach(mainChats, id: \.id) { sdChat in
                                MainChatRow(sdChat: sdChat) {
                                    loadSDChatIntoThread(sdChat)
                                }
                                Divider()
                                    .padding(.leading, 16)
                                    .opacity(0.4)
                            }
                        }

                        // Mini-chat threads
                        if !recentThreads.isEmpty {
                            HStack {
                                Text("QUICK CHATS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.mutedForeground.opacity(0.7))
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                            ForEach(recentThreads) { thread in
                                RecentChatRow(thread: thread) {
                                    threadState.setActiveThread(thread.id)
                                    withAnimation { showRecentChats = false }
                                }
                                Divider()
                                    .padding(.leading, 16)
                                    .opacity(0.4)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadMainChats() }
    }

    private func loadMainChats() {
        var descriptor = FetchDescriptor<SDChat>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        mainChats = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadSDChatIntoThread(_ sdChat: SDChat) {
        let sorted = sdChat.sortedMessages
        let messages = sorted.map { msg in
            AssistantMessage(
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content,
                createdAt: msg.createdAt
            )
        }
        let threadId = threadState.createThread(type: "chat", label: sdChat.title)
        for msg in messages {
            threadState.addThreadMessage(msg, threadId: threadId)
        }
        threadState.setActiveThread(threadId)
        withAnimation { showRecentChats = false }
    }
}

private struct MainChatRow: View {
    let sdChat: SDChat
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    private var messageCount: Int { sdChat.sortedMessages.count }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sdChat.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    if let last = sdChat.sortedMessages.last {
                        Text(last.content.prefix(60))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(relativeDate(sdChat.updatedAt))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Text("\(messageCount) msgs")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovered ? theme.foreground.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .onHover { isHovered = $0 }
    }

    private func relativeDate(_ date: Date) -> String {
        let diff = Date.now.timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 604800 { return "\(Int(diff / 86400))d ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct RecentChatRow: View {
    let thread: ChatThread
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    if let lastMsg = thread.messages.last {
                        Text(lastMsg.content.prefix(60))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.mutedForeground)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(thread.messages.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovered ? theme.foreground.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .onHover { isHovered = $0 }
    }
}
