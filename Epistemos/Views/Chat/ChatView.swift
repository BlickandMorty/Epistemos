import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

    var id: String { message.id }
}

nonisolated func makeChatTranscriptRows(from messages: [ChatMessage]) -> [ChatTranscriptRow] {
    var lastUserQuery: String?
    var rows: [ChatTranscriptRow] = []
    rows.reserveCapacity(messages.count)

    for message in messages {
        if message.role == .user {
            lastUserQuery = message.content
            rows.append(ChatTranscriptRow(message: message, originalQuery: nil))
        } else {
            rows.append(ChatTranscriptRow(message: message, originalQuery: lastUserQuery))
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
    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    private var theme: EpistemosTheme { ui.theme }
    private var transcriptRows: [ChatTranscriptRow] {
        makeChatTranscriptRows(from: chat.messages)
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
                                    allowsResubmit: !pipeline.isProcessing,
                                    onResubmit: { query in
                                        chat.submitQuery(query)
                                    }
                                )
                                .id(row.id)
                            }

                            // Streaming indicator
                            if chat.isStreaming || !chat.streamingText.isEmpty {
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
                        autoFollow.markProgrammaticScrollToBottom()
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }
            }

            // Input bar
            ChatInputBar(
                onSubmit: { query in
                    chat.submitQuery(query)
                },
                onStop: {
                    chat.stopStreaming()
                },
                isProcessing: pipeline.isProcessing
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .toolbar {
            // Right: chat controls (title + nav handled by toolbar)
            ToolbarItemGroup(placement: .primaryAction) {
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
            return "## \(role)\n\n\(msg.content)"
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
}

// ChatHeaderBar removed — buttons now live in the toolbar (see ChatView.body .toolbar {})

// MARK: - Streaming Indicator

private struct StreamingIndicator: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @State private var dotPhase = 0

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        // Streaming text + reasoning shown identically for regular and research mode.
        // Research enrichment cards appear on the completed message (non-blocking).
        streamingView
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Reasoning accordion — shown when reasoning is active or has content
            if chat.isReasoning || !chat.reasoningText.isEmpty {
                ThinkingAccordion(
                    reasoningText: chat.reasoningText,
                    duration: chat.reasoningDuration,
                    isLive: chat.isReasoning
                )
            }

            if ChatStreamingDisplayPolicy.showsLiveResponseText, !chat.streamingText.isEmpty {
                TaggedMarkdownTextView(
                    content: chat.streamingText + (chat.isStreaming ? " ▍" : ""),
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !chat.isStreaming, !chat.streamingText.isEmpty {
                TaggedMarkdownTextView(content: chat.streamingText, theme: theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !chat.isReasoning {
                // Thinking dots — only when not in reasoning phase
                HStack(spacing: 4) {
                    Text("Thinking")
                        .font(.epCaption)
                        .foregroundStyle(theme.mutedForeground.opacity(0.6))
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(theme.accent.opacity(i <= dotPhase ? 0.8 : 0.2))
                            .frame(width: 4, height: 4)
                    }
                }
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { break }
                        dotPhase = (dotPhase + 1) % 3
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .assistantInsetChrome(theme: theme, cornerRadius: 20, isEmphasized: chat.isReasoning)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
