import SwiftUI
import UniformTypeIdentifiers

enum ChatLayout {
    static let messageColumnMaxWidth: CGFloat = 760
    static let mainComposerMaxWidth: CGFloat = 940
    static let mainComposerHorizontalPadding: CGFloat = 12
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
// Layout: header bar + research mode bar + scrolling messages + input bar.

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
                        LazyVStack(spacing: 24) {
                            ForEach(transcriptRows) { row in
                                MessageBubble(
                                    message: row.message,
                                    originalQuery: row.originalQuery,
                                    allowsResubmit: !pipeline.isProcessing,
                                    onResubmit: { chat.submitQuery($0) }
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
                    for: CGFloat.self,
                    of: ScrollStability.distanceToBottom(for:)
                ) { _, distance in
                    let nextState = ScrollStability.updatedAutoFollowState(
                        from: autoFollow,
                        distanceToBottom: distance
                    )
                    guard nextState != autoFollow else { return }
                    autoFollow = nextState
                }
                .onChange(of: chat.messages.count) { _, _ in
                    guard autoFollow.isFollowingBottom else { return }
                    autoFollow.markProgrammaticScrollToBottom()
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
                .onChange(of: chat.streamingText) { _, _ in
                    // Throttle to ~4fps during streaming
                    let now = ContinuousClock.now
                    guard autoFollow.isFollowingBottom,
                          now - lastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                    else { return }
                    lastScrollTime = now
                    autoFollow.markProgrammaticScrollToBottom()
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
                .onAppear {
                    autoFollow.markProgrammaticScrollToBottom()
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
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
        .animation(Motion.smooth, value: pipeline.isProcessing)
        .navigationTitle("")
        .toolbar {
            // Right: chat controls (title + nav handled by toolbar)
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: exportChat) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export Chat")

                if chat.isResearchMode {
                    ResearchHintButton()
                }
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

// MARK: - Research Mode Control

struct ResearchModeControl: View {
    @Environment(ChatState.self) private var chat
    var variant: NativeControlVariant = .toolbar

    static let showsSecondaryOptionsBox = false

    var body: some View {
        ExpandingModeButton(
            title: "Research",
            systemImage: chat.isResearchMode ? "flask.fill" : "flask",
            isActive: chat.isResearchMode,
            variant: variant,
            helpText: chat.isResearchMode ? "Research Mode On" : "Enable Research Mode",
            stableWidth: NativeControlSystem.reservedWidth(for: "Research", variant: variant)
        ) {
            if chat.isResearchMode {
                chat.disableResearchMode()
            } else {
                chat.enableResearchMode()
            }
        }
        .help("Research Mode")
    }
}

// MARK: - Research Hint Button
// Toolbar button — tap to see API cost + About Lucid Lens pipeline info.
// Honest about how many API calls each query uses.

private struct ResearchHintButton: View {
    @Environment(UIState.self) private var ui
    @State private var showPopover = false
    @State private var showAbout = false

    private var theme: EpistemosTheme { ui.theme }

    // The 6 passes that run per research query — each with its own specialized focus:
    private static let pipelineSteps: [(title: String, detail: String)] = [
        ("Pass 1 — Direct Answer", "Streaming response with evidence hierarchy + source citations (1 API call)"),
        ("Pass 2 — Deep Analysis", "Full analytical math: effect sizes, Bradford Hill, meta-analysis, epistemic tagging — the research powerhouse (1 API call)"),
        ("Pass 3 — Layman Summary", "Translates expert analysis into accessible 5-section breakdown — no math noise, pure clarity (1 API call)"),
        ("Pass 4 — Reflection", "Adversarial self-critique: 6 attack techniques + cognitive bias audit of Pass 2 (1 API call)"),
        ("Pass 5 — Arbitration", "5 independent engines (statistical, causal, Bayesian, meta-analysis, adversarial) each with distinct epistemological lens (1 API call)"),
        ("Pass 6 — Truth Assessment", "Research-backed calibration: CoT-then-Confidence, DINCO-lite cross-check, 7 hard calibration rules (1 API call)"),
    ]

    var body: some View {
        Button { showPopover.toggle() } label: {
            Label("Research", systemImage: "lightbulb.max")
        }
        .help("About Research Mode")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // API cost breakdown
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.epHeading)
                            .foregroundStyle(theme.accent)
                        Text("API Usage Per Query")
                            .font(.epBodyMedium)
                            .foregroundStyle(theme.foreground)
                    }

                    // Regular mode
                    HStack(spacing: 6) {
                        Text("1")
                            .font(.epMono)
                            .fontWeight(.bold)
                            .foregroundStyle(theme.success)
                        Text("API call — Regular Mode")
                            .font(.epSmall)
                            .foregroundStyle(theme.textSecondary)
                    }

                    // Research mode
                    HStack(spacing: 6) {
                        Text("6")
                            .font(.epMono)
                            .fontWeight(.bold)
                            .foregroundStyle(theme.warning)
                        Text("API calls — Research Mode")
                            .font(.epSmall)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Text("Research Mode runs 6 sequential passes with distributed analytical scaffolding. Each pass carries only the math it needs. Expect 1–3 minutes and 6× the token cost.")
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(theme.glassBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)

                // About — expandable pipeline breakdown
                // Always rendered (never if/else) to avoid NSPopover resize crash.
                // Visibility controlled via opacity + frame height clipping.
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        showAbout.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.epCaption)
                                .foregroundStyle(theme.accent.opacity(0.7))

                            Text("6-Pass Breakdown")
                                .font(.epCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.foreground.opacity(0.85))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.epSmall)
                                .fontWeight(.bold)
                                .foregroundStyle(theme.textTertiary)
                                .rotationEffect(.degrees(showAbout ? 90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(Self.pipelineSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(theme.accent.opacity(0.12))
                                        .frame(width: 24, height: 24)
                                    Text("\(index + 1)")
                                        .font(.epMono)
                                        .fontWeight(.bold)
                                        .foregroundStyle(theme.accent)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(step.title)
                                        .font(.epSmall)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(theme.foreground)
                                    Text(step.detail)
                                        .font(.epSmall)
                                        .foregroundStyle(theme.textTertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        // Additional context
                        Text("Each pass carries only the math it needs — Pass 2 owns the heavy analytical scaffolding, while Passes 3–6 focus on their specific role without instruction noise. The 10-stage pipeline runs locally before Pass 1 (0 API calls). Title generation adds +1 call on first message.")
                            .font(.epSmall)
                            .foregroundStyle(theme.textTertiary.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .padding(.top, showAbout ? 10 : 0)
                    .frame(maxHeight: showAbout ? .infinity : 0)
                    .clipped()
                    .opacity(showAbout ? 1 : 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .padding(.bottom, 4)
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .preferredColorScheme(theme.colorScheme)
        }
    }
}

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

            if !chat.streamingText.isEmpty {
                Text(chat.streamingText)
                    .font(.epBody)
                    .foregroundStyle(theme.foreground)
                    .textSelection(.enabled)
                    .lineSpacing(3)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
