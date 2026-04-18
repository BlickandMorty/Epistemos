import SwiftUI

// DEPRECATED (fused chat, 2026-04-18): this view is no longer shown in the
// default UI. As of commit 3d83f377 the landing Chat/Agent picker was
// removed and main chat auto-promotes to the Rust agent_core loop via
// MainChatSubmissionRouter.autoPromotedMode when the pre-submit intent
// classifier detects agent-tier work on an OpenAI/Anthropic backend.
//
// The only live render path is RootView's homeSurfaceRoute == .agent
// branch, which is gated on AgentCommandCenterState.isPresented — and
// nothing in the UI calls .present() anymore. The branch is kept as a
// programmatic safety net.
//
// Delete candidate once we've let the fused chat bake for a release or
// two without regressions. Keep the symbol until then so any stale
// external references (plugins, accessibility scripts, future restore
// points) continue to resolve.
private enum AgentChatLayout {
    static let messageColumnMaxWidth: CGFloat = ChatLayout.messageColumnMaxWidth
    static let transcriptSpacing: CGFloat = ChatLayout.transcriptSpacing
    static let contentHorizontalPadding: CGFloat = 28
    static let contentTopPadding: CGFloat = 14
    static let composerBottomPadding: CGFloat = 18
    static let controlRowMaxWidth: CGFloat = ChatLayout.mainComposerMaxWidth
    static let emptyStateMaxWidth: CGFloat = 760
    static let quickActionSpacing: CGFloat = 14
    static let inspectorWidth: CGFloat = 404
}

struct AgentChatView: View {
    @Environment(UIState.self) private var ui
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(AgentChatState.self) private var agentChat

    @State private var autoFollow = ChatScrollFollowPolicy.defaultAutoFollowState
    @State private var transcriptRows: [ChatTranscriptRow] = []
    @State private var lastScrollTime: ContinuousClock.Instant = .now

    private var theme: EpistemosTheme { ui.theme }

    private var showsInspectorPanel: Bool {
        if case .expanded = accState.inspectorState {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                pageControlsRow

                if agentChat.messages.isEmpty && !agentChat.isStreaming {
                    emptyState
                } else {
                    transcriptView
                }

                CommandBarView()
                    .padding(.horizontal, ChatLayout.mainComposerHorizontalPadding)
                    .padding(.bottom, AgentChatLayout.composerBottomPadding)
                    .frame(maxWidth: ChatLayout.mainComposerMaxWidth)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsInspectorPanel {
                Divider()
                inspectorRail
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.resolved.background.color.ignoresSafeArea())
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: showsInspectorPanel)
        .onAppear {
            if agentChat.activeSessionId == nil && agentChat.messages.isEmpty {
                agentChat.startNewSession()
            }
            transcriptRows = makeChatTranscriptRows(from: agentChat.messages, chatTitle: "Agent")

            if accState.presentationMode == .standard, showsInspectorPanel, agentChat.messages.isEmpty {
                accState.inspectorState = .collapsed
            }
        }
        .onChange(of: agentChat.messages.count) { _, _ in
            transcriptRows = makeChatTranscriptRows(from: agentChat.messages, chatTitle: "Agent")
        }
    }

    private var pageControlsRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Agent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textTertiary)

            if agentChat.isStreaming {
                Label(
                    agentChat.isAgentExecuting ? "Running tools" : "Thinking",
                    systemImage: agentChat.isAgentExecuting ? "hammer" : "sparkles"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(theme.muted.opacity(theme.isDark ? 0.78 : 0.42), in: Capsule())
            }

            Spacer(minLength: 16)

            ControlGroup {
                Button {
                    startNewAgentSession()
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .help("New Chat")

                Button {
                    toggleInspectorPanel()
                } label: {
                    Label(showsInspectorPanel ? "Hide Details" : "Show Details", systemImage: "sidebar.right")
                }
                .help(showsInspectorPanel ? "Hide Details" : "Show Details")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(4)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(theme.border.opacity(0.6), lineWidth: 0.6)
            }
        }
        .controlSize(.small)
        .frame(maxWidth: AgentChatLayout.controlRowMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AgentChatLayout.contentHorizontalPadding)
        .padding(.top, AgentChatLayout.contentTopPadding)
        .padding(.bottom, agentChat.messages.isEmpty && !agentChat.isStreaming ? 28 : 10)
    }

    private var emptyState: some View {
        ScrollView {
            HStack {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start with a focused task.")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)

                        Text("Use the agent when you want note-aware research, multi-step work, or focused changes. Start with a specialist preset or type directly into the composer.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick starts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)

                        quickActionGrid
                    }

                    launchGuidanceCard
                }
                .frame(maxWidth: AgentChatLayout.emptyStateMaxWidth, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AgentChatLayout.contentHorizontalPadding)
            .padding(.top, 40)
            .padding(.bottom, 36)
        }
    }

    private var quickActionGrid: some View {
        ViewThatFits(in: .horizontal) {
            quickActionGridLayout(
                columns: [
                    GridItem(.flexible(), spacing: AgentChatLayout.quickActionSpacing),
                    GridItem(.flexible(), spacing: AgentChatLayout.quickActionSpacing),
                ]
            )
            quickActionGridLayout(columns: [GridItem(.flexible())])
        }
    }

    private func quickActionGridLayout(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AgentChatLayout.quickActionSpacing) {
            ForEach(ACCSlashCommand.featuredAgentQuickActions, id: \.self) { command in
                quickActionButton(command)
            }
        }
    }

    private func quickActionButton(_ command: ACCSlashCommand) -> some View {
        Button {
            accState.applySpecialist(command)
            accState.primeInput("/\(command.rawValue) ")
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 28, height: 28)
                    .background(
                        theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("/\(command.rawValue)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(command.helpText)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.55), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
    }

    private var launchGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Chat first, details when needed", systemImage: "sidebar.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            Text("Plans, note context, and execution detail stay in the side panel, so the page can stay focused on the working thread.")
                .font(.system(size: 13))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.border.opacity(0.55), lineWidth: 0.6)
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HStack {
                    Spacer(minLength: 0)

                    LazyVStack(spacing: AgentChatLayout.transcriptSpacing) {
                        ForEach(transcriptRows) { row in
                            MessageBubble(
                                message: row.message,
                                originalQuery: row.originalQuery,
                                displayContent: row.displayContent,
                                heading: row.heading,
                                sourceReferences: row.sourceReferences,
                                allowsResubmit: !agentChat.isStreaming,
                                onResubmit: { query in
                                    accState.primeInput(query)
                                }
                            )
                            .id(row.id)
                        }

                        if agentChat.isStreaming {
                            AgentStreamingIndicator()
                                .id("agent-streaming-bottom")
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("agent-bottom-anchor")
                    }
                    .frame(maxWidth: AgentChatLayout.messageColumnMaxWidth)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AgentChatLayout.contentHorizontalPadding)
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
            .onChange(of: agentChat.messages.count) { _, _ in
                guard autoFollow.isFollowingBottom else { return }
                autoFollow.markProgrammaticScrollToBottom()
                proxy.scrollTo("agent-bottom-anchor", anchor: .bottom)
            }
            .onChange(of: agentChat.streamingText) { _, _ in
                let now = ContinuousClock.now
                guard autoFollow.isFollowingBottom,
                      (ChatStreamingDisplayPolicy.showsLiveResponseText || !agentChat.isStreaming),
                      now - lastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                else { return }
                lastScrollTime = now
                autoFollow.markProgrammaticScrollToBottom()
                proxy.scrollTo("agent-bottom-anchor", anchor: .bottom)
            }
            .onAppear {
                Task { @MainActor in
                    autoFollow.markProgrammaticScrollToBottom()
                    proxy.scrollTo("agent-bottom-anchor", anchor: .bottom)
                }
            }
        }
    }

    private var inspectorRail: some View {
        VStack(spacing: 0) {
            InspectorPanelView()
        }
        .frame(width: AgentChatLayout.inspectorWidth)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func toggleInspectorPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch accState.inspectorState {
            case .collapsed:
                accState.inspectorState = .expanded(.plan)
            case .expanded:
                accState.inspectorState = .collapsed
            }
        }
    }

    private func startNewAgentSession() {
        agentChat.startNewSession()
        accState.clearInput()
        accState.diagnostics = CommandCenterExecutionDiagnostics()
    }
}

private struct AgentStreamingIndicator: View {
    @Environment(UIState.self) private var ui
    @Environment(AgentChatState.self) private var agentChat

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ToolExecutionPreviewList(
                blocks: agentChat.pendingContentBlocks,
                isStreaming: agentChat.isStreaming
            )

            let visibleStreamingText = UserFacingModelOutput.streamingVisibleText(from: agentChat.streamingText)
            let finalStreamingText = UserFacingModelOutput.finalVisibleText(from: agentChat.streamingText)

            if ChatStreamingDisplayPolicy.showsLiveResponseText, !visibleStreamingText.isEmpty {
                TaggedMarkdownTextView(
                    content: visibleStreamingText + (agentChat.isStreaming ? " ▍" : ""),
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !agentChat.isStreaming, !finalStreamingText.isEmpty {
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
        .assistantInsetChrome(theme: theme, cornerRadius: 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
