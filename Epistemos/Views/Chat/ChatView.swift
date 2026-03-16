import SwiftUI

enum ChatLayout {
    static let messageColumnMaxWidth: CGFloat = 760
    static let mainComposerMaxWidth: CGFloat = 980
    static let mainComposerHorizontalPadding: CGFloat = 12
}

// MARK: - Chat View
// Full chat interface matching v2's conversation mode.
// Shows when user has submitted a query from landing page.
// Layout: header bar + research mode bar + scrolling messages + input bar.

struct ChatView: View {
    @Environment(ChatState.self) private var chat
    @Environment(PipelineState.self) private var pipeline
    @State private var autoFollow = ScrollAutoFollowState()
    /// Throttles scroll-to-bottom during streaming to ~4 fps instead of per-token.
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    HStack {
                        Spacer(minLength: 0)
                        LazyVStack(spacing: 24) {
                            ForEach(chat.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
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
                    withAnimation(Motion.quick) {
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }
                .onChange(of: chat.streamingText) { _, _ in
                    // Throttle to ~4fps during streaming
                    let now = ContinuousClock.now
                    guard autoFollow.isFollowingBottom,
                          now - lastScrollTime > .milliseconds(250) else { return }
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
    }
}

// ChatHeaderBar removed — buttons now live in the toolbar (see ChatView.body .toolbar {})

// MARK: - Research Mode Control
// One-click mode toggle plus an anchored options popover.
// Preserves the fast workflow while moving secondary explanation into a native popover.

struct ResearchModeControl: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    var variant: NativeControlVariant = .toolbar
    var toggleMorphID: String? = nil
    var optionsMorphID: String? = nil

    @State private var showPopover = false
    @State private var showAbout = false

    private var theme: EpistemosTheme { ui.theme }

    // The 6 passes that run per research query — each with its own specialized focus:
    static let pipelineSteps: [(title: String, detail: String)] = [
        ("Pass 1 — Direct Answer", "Streaming response with evidence hierarchy + source citations (1 API call)"),
        ("Pass 2 — Deep Analysis", "Full analytical math: effect sizes, Bradford Hill, meta-analysis, epistemic tagging — the research powerhouse (1 API call)"),
        ("Pass 3 — Layman Summary", "Translates expert analysis into accessible 5-section breakdown — no math noise, pure clarity (1 API call)"),
        ("Pass 4 — Reflection", "Adversarial self-critique: 6 attack techniques + cognitive bias audit of Pass 2 (1 API call)"),
        ("Pass 5 — Arbitration", "5 independent engines (statistical, causal, Bayesian, meta-analysis, adversarial) each with distinct epistemological lens (1 API call)"),
        ("Pass 6 — Truth Assessment", "Research-backed calibration: CoT-then-Confidence, DINCO-lite cross-check, 7 hard calibration rules (1 API call)"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ExpandingModeButton(
                title: "Research",
                systemImage: chat.isResearchMode ? "flask.fill" : "flask",
                isActive: chat.isResearchMode,
                variant: variant,
                helpText: chat.isResearchMode ? "Research Mode On" : "Enable Research Mode",
                asciiAnimation: .toolbarStatus,
                stableWidth: NativeControlSystem.reservedWidth(for: "Research", variant: variant),
                morphID: toggleMorphID
            ) {
                if chat.isResearchMode {
                    chat.disableResearchMode()
                } else {
                    chat.enableResearchMode()
                }
            }

            AnchoredPopoverButton(
                title: "Options",
                systemImage: "slider.horizontal.3",
                isPresented: $showPopover,
                isActive: chat.isResearchMode,
                variant: variant,
                helpText: "Research Options",
                accessibilityLabel: "Research options",
                idealPopoverWidth: 296,
                stableWidth: NativeControlSystem.reservedWidth(
                    for: "Options",
                    variant: variant,
                    includesDisclosureGlyph: true
                ),
                morphID: optionsMorphID
            ) {
                ResearchModePopoverContent(showAbout: $showAbout)
            }
        }
        .help("Research Mode")
    }
}

private struct ResearchModePopoverContent: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Binding var showAbout: Bool

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        @Bindable var chat = chat

        VStack(alignment: .leading, spacing: 12) {
            Text("Research")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.foreground)

            Picker("Mode", selection: $chat.queryMode) {
                Text(ChatQueryMode.direct.rawValue).tag(ChatQueryMode.direct)
                Text(ChatQueryMode.research.rawValue).tag(ChatQueryMode.research)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.epHeading)
                        .foregroundStyle(theme.accent)
                    Text("API Usage Per Query")
                        .font(.epBodyMedium)
                        .foregroundStyle(theme.foreground)
                }

                HStack(spacing: 6) {
                    Text("1")
                        .font(.epMono)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.success)
                    Text("API call — Chat")
                        .font(.epSmall)
                        .foregroundStyle(theme.textSecondary)
                }

                HStack(spacing: 6) {
                    Text("6")
                        .font(.epMono)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.warning)
                    Text("API calls — Research")
                        .font(.epSmall)
                        .foregroundStyle(theme.textSecondary)
                }

                Text("Research Mode runs 6 sequential passes with distributed analytical scaffolding. Expect 1–3 minutes and roughly 6× the token cost.")
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ToolbarCapsuleButton(
                title: showAbout ? "Hide 6-Pass Breakdown" : "6-Pass Breakdown",
                systemImage: "info.circle",
                variant: .toolbar,
                role: .secondaryGhost,
                isActive: showAbout
            ) {
                showAbout.toggle()
            }

            if showAbout {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(ResearchModeControl.pipelineSteps.enumerated()), id: \.offset) {
                        index,
                        step in
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

                    Text("The 10-stage pipeline runs locally before Pass 1 with zero API calls. Title generation still adds one extra cloud call on the first message.")
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: NativeControlSystem.animation.popoverDuration), value: showAbout)
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
                TaggedMarkdownTextView(
                    content: chat.streamingText,
                    theme: theme
                )
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
