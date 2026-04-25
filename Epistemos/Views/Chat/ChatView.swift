import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum ChatPresentationFormatter {
    nonisolated static let userModePrefixRegex = FoundationSafety.regularExpression(
        pattern: #"^\[[A-Z ]+MODE\]\s*"#
    )

    nonisolated static func displayContent(for message: ChatMessage, chatTitle: String? = nil, isFirstAssistantMessage: Bool = false) -> String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.role == .user else {
            let final = UserFacingModelOutput.finalVisibleText(from: trimmed)
            
            // If this is the "large first sentence/heading" the user wants to replace with the title:
            // Strip leading # Heading if it matches the title or if it's the first assistant message
            // following a main title.
            var lines = final.components(separatedBy: .newlines)
            if let first = lines.first, first.hasPrefix("# ") {
                let headingText = first.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                let t = chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // If it matches the chat title OR it's the first assistant message and looks redundant:
                if headingText.caseInsensitiveCompare(t) == .orderedSame || isFirstAssistantMessage {
                    lines.removeFirst()
                    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            return final
        }

        let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let userModePrefixRegex else {
            return trimmed
        }
        return userModePrefixRegex.stringByReplacingMatches(
            in: trimmed,
            range: fullRange,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func heading(forAssistantText text: String) -> String? {
        return nil
    }

    nonisolated static func sourceReferences(
        for message: ChatMessage,
        displayContent: String
    ) -> [AssistantSourceReference] {
        guard message.role == .assistant, !message.isError else { return [] }
        return AssistantSourceReference.extract(
            from: displayContent,
            noteTitles: message.loadedNoteTitles ?? []
        )
    }
}

enum ChatLayout {
    static let messageColumnMaxWidth: CGFloat = 760
    static let mainComposerMaxWidth: CGFloat = 860
    static let mainComposerHorizontalPadding: CGFloat = 10
    static let transcriptSpacing: CGFloat = 28
    static let brainPanelWidth: CGFloat = 388
}

enum ChatStreamingDisplayPolicy {
    static let showsLiveResponseText = true
}

struct ChatTranscriptRow: Identifiable, Sendable {
    let message: ChatMessage
    let originalQuery: String?
    let displayContent: String
    let heading: String?
    let sourceReferences: [AssistantSourceReference]

    var id: String { message.id }
}

nonisolated func makeChatTranscriptRows(from messages: [ChatMessage], chatTitle: String?) -> [ChatTranscriptRow] {
    var lastUserQuery: String?
    var assistantMessageCount = 0
    var rows: [ChatTranscriptRow] = []
    rows.reserveCapacity(messages.count)

    for message in messages {
        if message.role == .user {
            lastUserQuery = message.content
            rows.append(
                ChatTranscriptRow(
                    message: message,
                    originalQuery: nil,
                    displayContent: ChatPresentationFormatter.displayContent(for: message, chatTitle: chatTitle),
                    heading: nil,
                    sourceReferences: []
                )
            )
        } else {
            assistantMessageCount += 1
            let displayContent = ChatPresentationFormatter.displayContent(
                for: message,
                chatTitle: chatTitle,
                isFirstAssistantMessage: assistantMessageCount == 1
            )
            rows.append(
                ChatTranscriptRow(
                    message: message,
                    originalQuery: lastUserQuery,
                    displayContent: displayContent,
                    heading: ChatPresentationFormatter.heading(forAssistantText: displayContent),
                    sourceReferences: ChatPresentationFormatter.sourceReferences(
                        for: message,
                        displayContent: displayContent
                    )
                )
            )
        }
    }

    return rows
}

// MARK: - Chat View
// Full chat interface matching v2's conversation mode.
// Shows when user has submitted a query from landing page.
// Layout: header bar + scrolling messages + input bar.

struct ChatView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(PipelineState.self) private var pipeline
    @Environment(InferenceState.self) private var inference
    @Environment(OrchestratorState.self) private var orchestrator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var mainChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    @AppStorage("mainChat.showBrainPanel") private var showBrainPanel = false
    @State private var transcriptRows: [ChatTranscriptRow] = []
    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    private var theme: EpistemosTheme { ui.theme }

    /// Near-OLED dark grey in dark mode, landing-matched paper white in light mode.
    /// Applied as the root background so main chat reads like a deep dark
    /// surface when dark, but falls back to the same light canvas as Home.
    private var oledAwareBackground: Color {
        theme.isDark ? Color(red: 0.07, green: 0.07, blue: 0.07) : theme.resolved.background.color
    }

    private var supportedOperatingModes: [EpistemosOperatingMode] {
        MainChatOperatingModePreference.supportedModes(for: inference)
    }

    private var selectedOperatingMode: EpistemosOperatingMode {
        get {
            MainChatOperatingModePreference.sanitize(
                EpistemosOperatingMode(rawValue: mainChatOperatingModeRaw) ?? .fast,
                for: inference
            )
        }
        nonmutating set {
            mainChatOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                newValue,
                for: inference
            ).rawValue
        }
    }

    private var operatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { selectedOperatingMode },
            set: { selectedOperatingMode = $0 }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        HStack {
                            Spacer(minLength: 0)
                            LazyVStack(spacing: ChatLayout.transcriptSpacing) {
                                ForEach(transcriptRows) { row in
                                    MessageBubble(
                                        message: row.message,
                                        originalQuery: row.originalQuery,
                                        displayContent: row.displayContent,
                                        heading: row.heading,
                                        sourceReferences: row.sourceReferences,
                                        allowsResubmit: !pipeline.isProcessing,
                                        onResubmit: { query in
                                            submitMainChatQuery(query, operatingMode: selectedOperatingMode)
                                        }
                                    )
                                    .id(row.id)
                                }

                                if pipeline.isProcessing || chat.isStreaming {
                                    StreamingIndicator(selectedOperatingMode: selectedOperatingMode)
                                        .id("streaming-bottom")
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom-anchor")
                            }
                            .frame(maxWidth: ChatLayout.messageColumnMaxWidth)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                    }
                    .contentMargins(.top, 0, for: .scrollContent)
                    .onScrollGeometryChange(
                        for: Bool.self,
                        of: { geometry in
                            ScrollStability.followMode(for: geometry, from: autoFollow)
                        }
                    ) { _, isFollowingBottom in
                        guard isFollowingBottom != autoFollow.isFollowingBottom else { return }
                        autoFollow.setFollowingBottom(isFollowingBottom)
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        guard autoFollow.isFollowingBottom else { return }
                        autoFollow.markProgrammaticScrollToBottom()
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                    .onChange(of: chat.transcriptRevision) { _, _ in
                        transcriptRows = makeChatTranscriptRows(from: chat.messages, chatTitle: chat.chatTitle)
                    }
                    .onChange(of: chat.streamingText) { _, _ in
                        let now = ContinuousClock.now
                        guard autoFollow.isFollowingBottom,
                              (ChatStreamingDisplayPolicy.showsLiveResponseText || !chat.isStreaming),
                              now - lastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                        else { return }
                        lastScrollTime = now
                        autoFollow.markProgrammaticScrollToBottom()
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                    .onAppear {
                        Task { @MainActor in
                            transcriptRows = makeChatTranscriptRows(from: chat.messages, chatTitle: chat.chatTitle)
                            autoFollow.markProgrammaticScrollToBottom()
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                }

                ChatInputBar(
                    onSubmit: { query in
                        submitMainChatQuery(query, operatingMode: selectedOperatingMode)
                    },
                    onStop: {
                        chat.stopStreaming()
                    },
                    isProcessing: pipeline.isProcessing,
                    operatingMode: operatingModeBinding,
                    availableOperatingModes: supportedOperatingModes
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showBrainPanel {
                Divider()
                ChatBrainPanelView(
                    snapshot: chat.latestBrainSnapshot,
                    capturedModelInput: chat.latestCapturedModelInput,
                    pendingContextAttachments: chat.pendingContextAttachments,
                    pendingAttachments: chat.pendingAttachments
                )
                    .frame(width: ChatLayout.brainPanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(oledAwareBackground.ignoresSafeArea())
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9), value: showBrainPanel)
        .onAppear {
            sanitizeStoredOperatingMode()
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: mainChatOperatingModeRaw) { _, _ in
            sanitizeStoredOperatingMode()
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: inference.preferredChatModelSelection.rawValue) { _, _ in
            sanitizeStoredOperatingMode()
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: inference.activeAIProvider) { _, _ in
            syncContextWindowMetrics()
            refreshChatCapability()
        }
        .onChange(of: chat.isAgentExecuting) { _, _ in
            refreshChatCapability()
        }
        .onChange(of: pipeline.isProcessing) { _, _ in
            refreshChatCapability()
        }
        .onChange(of: chat.latestBrainSnapshot) { _, _ in
            refreshChatCapability()
        }
        .navigationTitle("")
        .toolbar {
            // Right: chat controls (title + nav handled by toolbar)
            ToolbarItemGroup(placement: .primaryAction) {
                historyToolbarButton
                brainToolbarButton
                miniChatToolbarButton
                
                Button(action: exportChat) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export Chat")

            }
        }
    }

    private func exportChat() {
        let lines = chat.messages.map { msg in
            let role = msg.role == .user ? "You" : "Assistant"
            let content = ChatPresentationFormatter.displayContent(for: msg)
            return "## \(role)\n\n\(content)"
        }
        let md = "# Chat Export — \(Date().formatted(date: .abbreviated, time: .omitted))\n\n\(lines.joined(separator: "\n\n---\n\n"))"
        ChatTextExportSupport.save(
            md,
            suggestedFilename: "chat-export-\(Date().formatted(.iso8601.year().month().day())).md",
            contentType: .plainText
        )
    }
    private var historyToolbarButton: some View {
        @Bindable var ui = ui
        return Button {
            ui.toggleChatSidebar()
        } label: {
            Label("History", systemImage: "sidebar.left")
        }
        .accessibilityLabel("Chat History")
        .help("Chat History (⇧⌘H)")
        .popover(isPresented: $ui.showChatSidebar) {
            ChatSidebarView()
                .frame(width: 300, height: 500)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    private var brainToolbarButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                showBrainPanel.toggle()
            }
        } label: {
            Label(
                showBrainPanel ? "Hide Context" : "Show Context",
                systemImage: "sidebar.right"
            )
        }
        .accessibilityLabel(showBrainPanel ? "Hide context panel" : "Show context panel")
        .help(
            showBrainPanel
                ? "Hide turn context"
                : "Show turn context"
        )
    }

    private var miniChatToolbarButton: some View {
        Button(action: openCurrentChatInMiniChat) {
            Label("Open in Mini Chat", systemImage: "arrow.up.right.square")
        }
        .accessibilityLabel("Open in Mini Chat")
        .help("Open in Mini Chat")
    }

    private func submitMainChatQuery(_ query: String, operatingMode: EpistemosOperatingMode) {
        MainChatSubmissionRouter.submit(
            query,
            operatingMode: operatingMode,
            chat: chat,
            orchestrator: orchestrator,
            inference: inference
        )
    }

    private func sanitizeStoredOperatingMode() {
        let sanitized = MainChatOperatingModePreference.sanitize(
            EpistemosOperatingMode(rawValue: mainChatOperatingModeRaw) ?? .fast,
            for: inference
        )
        if sanitized.rawValue != mainChatOperatingModeRaw {
            mainChatOperatingModeRaw = sanitized.rawValue
        }
    }

    private func syncContextWindowMetrics() {
        chat.syncContextWindowMetrics(
            maxTokens: inference.chatSurfaceMaxContextTokens(for: selectedOperatingMode)
        )
    }

    private func openCurrentChatInMiniChat() {
        if let chatId = chat.activeChatId {
            MiniChatWindowController.shared.openChat(chatId)
        } else {
            MiniChatWindowController.shared.openNewChat()
        }
    }

    /// Refresh chat.currentCapability to match the active model + runtime
    /// state. Called on appear and whenever the provider / model / agent
    /// execution flags change so the ChatCapabilityPill reads live without
    /// the caller having to touch it by hand.
    ///
    /// IMPORTANT: reads preferredChatModelSelection (the model the next
    /// turn will ACTUALLY run on) — NOT activeAIProvider (a cloud-provider
    /// preference that can coexist with a local pick). Reading the wrong
    /// one caused the pill to read "Cloud" while a local MLX model was
    /// selected in the composer picker; the pill is a user-facing honesty
    /// contract and must not lie.
    private func refreshChatCapability() {
        if (chat.isAgentExecuting || pipeline.isProcessing),
           let snapshot = chat.latestBrainSnapshot {
            let hasPlannedTools = !snapshot.allowedToolNames.isEmpty
            let isCloudSnapshot = snapshot.providerLabel != "Local MLX"
                && snapshot.providerLabel != "Apple Intelligence"
            chat.currentCapability = ChatCapability.classify(
                isCloudProvider: isCloudSnapshot,
                isAgentExecuting: hasPlannedTools,
                isResearchMode: hasPlannedTools && !isCloudSnapshot,
                isThinkingMode: snapshot.operatingMode == .thinking
            )
            return
        }

        let effectiveSelection = inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)
        let isCloud: Bool
        switch effectiveSelection {
        case .cloud:
            isCloud = true
        case .localMLX, .appleIntelligence:
            isCloud = false
        }
        let toolsModeSelected = selectedOperatingMode == .agent
        chat.currentCapability = ChatCapability.classify(
            isCloudProvider: isCloud,
            isAgentExecuting: toolsModeSelected || chat.isAgentExecuting,
            isResearchMode: false,
            isThinkingMode: selectedOperatingMode == .thinking && !isCloud
        )
    }
}

// ChatHeaderBar removed — buttons now live in the toolbar (see ChatView.body .toolbar {})

// MARK: - Streaming Indicator

private struct StreamingIndicator: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(PipelineState.self) private var pipeline
    @Environment(InferenceState.self) private var inference
    let selectedOperatingMode: EpistemosOperatingMode

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        streamingView
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            let selection = inference.effectiveChatSurfaceSelection(for: selectedOperatingMode)
            let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(from: chat.streamingText)
            let finalStreamingText = UserFacingModelOutput.finalVisibleText(from: chat.streamingText)
            let expectsThinkingUI =
                selectedOperatingMode.capturesReasoningTrace
                && selection.supportsThinking
                && (
                    (pipeline.isProcessing && !chat.isStreaming)
                        || (chat.isStreaming && visibleStreamingText.isEmpty)
                )

            // Big visible status strip: "🔎 Searching the web for 'X'"
            // / "🧠 Thinking 12s" / "✍️ Writing reply…". Pops in the
            // moment the stream starts and swaps live as the phase
            // changes — first thing the user sees so tool use + thinking
            // is never a black box.
            if chat.isStreaming || chat.isAgentExecuting {
                LiveActivityStrip(
                    toolName: chat.isAgentExecuting ? chat.activeToolName : nil,
                    toolInputJson: chat.activeToolInputJson,
                    isThinkingActive: expectsThinkingUI || chat.isThinkingActive,
                    thinkingStartedAt: chat.thinkingStartedAt,
                    isStreaming: chat.isStreaming
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ChatGPT-style inline thinking panel — shown above the
            // streaming response whenever we have either an active
            // thinking phase OR captured thinking text from this turn.
            // Collapses into a "Thought for Ns" chip as soon as the
            // first answer token arrives, persists until the turn
            // finalizes into a ChatMessage.
            if expectsThinkingUI || chat.isThinkingActive || !chat.streamingThinking.isEmpty {
                ThinkingPopoverView(
                    thinkingContent: chat.streamingThinking,
                    isThinkingActive: expectsThinkingUI || chat.isThinkingActive,
                    thinkingStartedAt: chat.thinkingStartedAt,
                    thinkingEndedAt: chat.thinkingEndedAt
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ToolExecutionPreviewList(
                blocks: chat.pendingContentBlocks,
                isStreaming: chat.isStreaming
            )

            if ChatStreamingDisplayPolicy.showsLiveResponseText, !visibleStreamingText.isEmpty {
                TaggedMarkdownTextView(
                    content: visibleStreamingText + (chat.isStreaming ? " ▍" : ""),
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !chat.isStreaming, !finalStreamingText.isEmpty {
                TaggedMarkdownTextView(content: finalStreamingText, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pipeline.isProcessing && !chat.isStreaming && !chat.isAgentExecuting {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading \(inference.activeChatModelDisplayName)…")
                        .font(ClaudeAppTypography.userFont(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .assistantInsetChrome(theme: theme, cornerRadius: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatBrainPanelView: View {
    @Environment(UIState.self) private var ui
    let snapshot: ChatBrainSnapshot?
    let capturedModelInput: CapturedModelInput?
    let pendingContextAttachments: [ContextAttachment]
    let pendingAttachments: [FileAttachment]

    private var theme: EpistemosTheme { ui.theme }

    private var hasPendingContext: Bool {
        !pendingContextAttachments.isEmpty || !pendingAttachments.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if hasPendingContext {
                    // Pre-submit preview — removals still happen in the
                    // composer pill row so the panel stays read-only.
                    section(title: "READY TO SEND", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(pendingContextAttachments) { attachment in
                                detailRow(
                                    attachment.title,
                                    attachment.subtitle ?? attachment.kind.rawValue.capitalized
                                )
                            }
                            ForEach(pendingAttachments) { attachment in
                                detailRow(
                                    attachment.name,
                                    attachment.type.rawValue.capitalized,
                                    valueMonospaced: true
                                )
                            }
                        }
                    }
                }

                if let snapshot {
                    section(title: "ROUTING", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow("Route", snapshot.routeLabel)
                            detailRow("Summary", snapshot.routeSummary)
                            detailRow("Runtime", snapshot.providerLabel, valueMonospaced: true)
                            detailRow(
                                "Model",
                                snapshot.modelLabel ?? "Unknown",
                                valueMonospaced: true
                            )
                            detailRow("Mode", snapshot.operatingMode.displayName)
                            detailRow(
                                "Captured",
                                snapshot.capturedAt.formatted(date: .abbreviated, time: .standard)
                            )
                        }
                    }

                    section(title: "REQUEST", defaultExpanded: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            bodyBlock(snapshot.query)
                            if snapshot.resolvedQuery != snapshot.query {
                                Divider().opacity(0.4)
                                detailRow("Resolved", "After explicit-context cleanup and routing")
                                bodyBlock(snapshot.resolvedQuery)
                            }
                        }
                    }

                    if !snapshot.contextAttachments.isEmpty {
                        section(title: "EXPLICIT ATTACHMENTS", defaultExpanded: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(snapshot.contextAttachments) { attachment in
                                    detailRow(
                                        attachment.title,
                                        attachment.subtitle ?? attachment.kind.rawValue.capitalized
                                    )
                                }
                            }
                        }
                    }

                    if !snapshot.loadedNoteTitles.isEmpty {
                        section(title: "LOADED NOTES", defaultExpanded: true) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(snapshot.loadedNoteTitles, id: \.self) { title in
                                    Text(title)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    if !snapshot.allowedToolNames.isEmpty {
                        section(title: "TOOLS THIS TURN", defaultExpanded: false) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(snapshot.allowedToolNames, id: \.self) { tool in
                                    HStack(spacing: 6) {
                                        Text("▸")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(theme.textTertiary)
                                        Text(tool)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(theme.textSecondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }

                    if let capturedModelInput {
                        section(title: "MODEL INPUT", defaultExpanded: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRow(
                                    "Runtime",
                                    capturedModelInput.runtimeLabel,
                                    valueMonospaced: true
                                )
                                Divider().opacity(0.4)
                                detailRow("User", "User prompt")
                                bodyBlock(capturedModelInput.userPrompt)

                                if let systemPrompt = capturedModelInput.systemPrompt {
                                    Divider().opacity(0.4)
                                    detailRow("System", "System prompt")
                                    bodyBlock(systemPrompt)
                                }

                                if let messageHistory = capturedModelInput.messageHistory {
                                    Divider().opacity(0.4)
                                    detailRow("History", "Conversation before wrapping")
                                    bodyBlock(messageHistory)
                                }

                                if let toolDefinitionsJSON = capturedModelInput.toolDefinitionsJSON {
                                    Divider().opacity(0.4)
                                    detailRow("Tools", "Tool definitions sent this turn")
                                    bodyBlock(toolDefinitionsJSON)
                                }
                            }
                        }
                    }

                    ForEach(snapshot.sections) { sectionBlock in
                        section(title: sectionBlock.title.uppercased(), defaultExpanded: false) {
                            bodyBlock(sectionBlock.body)
                        }
                    }
                } else if !hasPendingContext {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MODEL CONTEXT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(theme.textTertiary)
                            .padding(.top, 4)
                        Text("After you send, this shows the notes, files, tools, and routing for that turn. Use @ or attachments to preview context first.")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 8)
        }
        .background(theme.resolved.background.color)
    }

    /// Collapsible section header styled like Claude Code's sidebar —
    /// small uppercase heading with tracking, chevron disclosure, no
    /// card chrome, thin divider underneath.
    @ViewBuilder
    private func section<Content: View>(
        title: String,
        defaultExpanded: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        BrainPanelSection(
            title: title,
            defaultExpanded: defaultExpanded,
            theme: theme,
            content: content
        )
    }

    @ViewBuilder
    private func detailRow(
        _ label: String,
        _ value: String,
        valueMonospaced: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(
                    valueMonospaced
                        ? .system(size: 11, design: .monospaced)
                        : .system(size: 12)
                )
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func bodyBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

/// Claude Code-style section: uppercase tracked header, chevron on the
/// right, no card chrome, thin bottom divider. Manages its own expand
/// state; the row is one big Button so the whole line is the tap target.
private struct BrainPanelSection<Content: View>: View {
    let title: String
    let defaultExpanded: Bool
    let theme: EpistemosTheme
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool?

    private var expanded: Bool {
        isExpanded ?? defaultExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    isExpanded = !expanded
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if expanded {
                content()
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.opacity(0.35))
                .frame(height: 0.5)
        }
    }
}
