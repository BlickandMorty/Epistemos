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
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var mainChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    @State private var transcriptRows: [ChatTranscriptRow] = []
    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    private var theme: EpistemosTheme { ui.theme }

    /// OLED-black in dark mode, theme background in light mode.
    /// Applied as the root background so main chat reads like the terminal
    /// aesthetic when dark, but stays on-theme when light.
    private var oledAwareBackground: Color {
        theme.isDark ? Color.black : theme.resolved.background.color
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
        VStack(spacing: 0) {
            // Message list
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

                            // Streaming indicator
                            if pipeline.isProcessing || chat.isStreaming {
                                StreamingIndicator()
                                    .id("streaming-bottom")
                            }

                            // Anchor for scroll-to-bottom
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
                    // Throttle to ~4fps during streaming for "smooth" feel
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

            // Input bar
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
        .background(oledAwareBackground.ignoresSafeArea())
        .onAppear {
            sanitizeStoredOperatingMode()
            refreshChatCapability()
        }
        .onChange(of: inference.preferredChatModelSelection.rawValue) { _, _ in
            sanitizeStoredOperatingMode()
            refreshChatCapability()
        }
        .onChange(of: inference.activeAIProvider) { _, _ in
            refreshChatCapability()
        }
        .onChange(of: chat.isAgentExecuting) { _, _ in
            refreshChatCapability()
        }
        .navigationTitle("")
        .toolbar {
            // Right: chat controls (title + nav handled by toolbar)
            ToolbarItemGroup(placement: .primaryAction) {
                historyToolbarButton
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
        let isCloud: Bool
        switch inference.preferredChatModelSelection {
        case .cloud:
            isCloud = true
        case .localMLX, .appleIntelligence:
            isCloud = false
        }
        chat.currentCapability = ChatCapability.classify(
            isCloudProvider: isCloud,
            isAgentExecuting: chat.isAgentExecuting,
            isResearchMode: false,
            isThinkingMode: false
        )
    }
}

// ChatHeaderBar removed — buttons now live in the toolbar (see ChatView.body .toolbar {})

// MARK: - Streaming Indicator

private struct StreamingIndicator: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        streamingView
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // ChatGPT-style thinking popover — shown above the streaming
            // response whenever we have either an active thinking phase
            // OR captured thinking text from this turn. Collapses into a
            // "Thought for Ns" badge as soon as the first answer token
            // arrives, persists until the turn finalizes into a ChatMessage.
            if chat.isThinkingActive || !chat.streamingThinking.isEmpty {
                ThinkingPopoverView(
                    thinkingContent: chat.streamingThinking,
                    isThinkingActive: chat.isThinkingActive,
                    thinkingStartedAt: chat.thinkingStartedAt,
                    thinkingEndedAt: chat.thinkingEndedAt
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ToolExecutionPreviewList(
                blocks: chat.pendingContentBlocks,
                isStreaming: chat.isStreaming
            )

            let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(from: chat.streamingText)
            let finalStreamingText = UserFacingModelOutput.finalVisibleText(from: chat.streamingText)

            if ChatStreamingDisplayPolicy.showsLiveResponseText, !visibleStreamingText.isEmpty {
                TaggedMarkdownTextView(
                    content: visibleStreamingText + (chat.isStreaming ? " ▍" : ""),
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !chat.isStreaming, !finalStreamingText.isEmpty {
                TaggedMarkdownTextView(content: finalStreamingText, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                AssistantTypingIndicatorDots(
                    theme: theme,
                    accent: theme.resolved.accent.color
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .assistantInsetChrome(theme: theme, cornerRadius: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
