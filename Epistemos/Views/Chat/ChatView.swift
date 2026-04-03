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
    @AppStorage("epistemos.mainChatOperatingMode")
    private var operatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    @State private var transcriptRows: [ChatTranscriptRow] = []
    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    private var theme: EpistemosTheme { ui.theme }
    private var selectedOperatingMode: EpistemosOperatingMode {
        inference.sanitizedOperatingMode(
            EpistemosOperatingMode(rawValue: operatingModeRaw) ?? .fast
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
                onSubmit: { query, operatingMode in
                    submitMainChatQuery(query, operatingMode: operatingMode)
                },
                onStop: {
                    chat.stopStreaming()
                },
                isProcessing: pipeline.isProcessing
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .onAppear {
            sanitizeStoredOperatingMode()
        }
        .onChange(of: inference.supportsThinkingOperatingMode) { _, _ in
            sanitizeStoredOperatingMode()
        }
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

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "chat-export-\(Date().formatted(.iso8601.year().month().day())).md"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do { try md.write(to: url, atomically: true, encoding: .utf8) }
                catch { Log.app.error("Chat export failed: \(error.localizedDescription)") }
            }
        }
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
            orchestrator: orchestrator
        )
    }

    private func openCurrentChatInMiniChat() {
        if let chatId = chat.activeChatId {
            MiniChatWindowController.shared.openChat(chatId)
        } else {
            MiniChatWindowController.shared.openNewChat()
        }
    }

    private func sanitizeStoredOperatingMode() {
        let sanitized = inference.sanitizedOperatingMode(
            EpistemosOperatingMode(rawValue: operatingModeRaw) ?? .fast
        )
        if sanitized.rawValue != operatingModeRaw {
            operatingModeRaw = sanitized.rawValue
        }
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
