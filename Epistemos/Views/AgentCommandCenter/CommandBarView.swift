import SwiftUI

// MARK: - Command Bar View
// Floating glass input field with inline brain picker, active /mode badge,
// @mention chips, and multiline text input.

struct CommandBarView: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(AgentChatState.self) private var agentChat
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var isInputFocused: Bool
    @State private var placeholderRunID = 0
    @State private var placeholderVisibleCount = 0
    @State private var placeholderAccentProgress = 0.0
    @State private var placeholderBreathes = false

    private let placeholderText = "Research notes, plan work, or make a focused change"
    private let composerMetrics = AssistantComposerMetrics.mainChat
    private var theme: EpistemosTheme { ui.theme }
    private var mutedText: Color { theme.textTertiary }
    private var composerIsActive: Bool {
        isInputFocused || !accState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentChat.isStreaming
    }
    private var haloStyle: AssistantComposerHaloStyle? {
        AssistantComposerHaloStyle.resolve(
            for: agentChat.isAgentExecuting ? .analyzing : (agentChat.isStreaming ? .typing : .idle)
        )
    }

    var body: some View {
        @Bindable var state = accState

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                BrainPickerMenu()

                if let token = accState.activeSlashToken {
                    slashTokenBadge(token)
                }

                Spacer(minLength: 0)

                if agentChat.isStreaming {
                    Text("Running")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.resolved.accent.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.muted.opacity(theme.isDark ? 0.75 : 0.42), in: Capsule())
                }
            }

            if let preset = accState.activeSpecialistPreset {
                specialistHarnessStrip(for: preset)
            }

            if !accState.activeMentions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(accState.activeMentions) { mention in
                            mentionChip(mention)
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .leading) {
                    if accState.inputText.isEmpty {
                        animatedPlaceholder
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $state.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .accessibilityLabel("Agent command input")
                        .onSubmit {
                            submitCommand()
                        }
                }

                AssistantSendButton(
                    theme: theme,
                    isEnabled: !accState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentChat.isStreaming,
                    isProcessing: agentChat.isStreaming,
                    metrics: composerMetrics
                ) {
                    if agentChat.isStreaming {
                        agentChat.stopStreaming()
                    } else {
                        submitCommand()
                    }
                }
                .disabled(accState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !agentChat.isStreaming)
                .help(agentChat.isStreaming ? "Stop" : "Send (Return)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .assistantComposerChrome(
                theme: theme,
                metrics: composerMetrics,
                isActive: composerIsActive
            )
            .background {
                AssistantComposerOuterHalo(
                    style: haloStyle,
                    accent: theme.resolved.accent.color,
                    cornerRadius: composerMetrics.cornerRadius,
                    animatesContinuously: false
                )
            }
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)

            if accState.suggestionMenuState != .hidden {
                SuggestionPopoverView()
                    .frame(maxWidth: 420, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task(id: placeholderRunID) {
            await runPlaceholderReveal()
        }
        .onChange(of: accState.inputText) { oldValue, newValue in
            if newValue.isEmpty && !oldValue.isEmpty {
                placeholderRunID += 1
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Harness Strip

    private func specialistHarnessStrip(for preset: ACCSlashCommand) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Harness preset", systemImage: preset.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)

                Text(preset.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)

                Button {
                    accState.clearSpecialistPreset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear harness preset")
            }

            if let focus = accState.harnessFocusLine {
                Text(focus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let posture = accState.harnessPostureLine {
                Text(posture)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            theme.muted.opacity(theme.isDark ? 0.72 : 0.32),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.border.opacity(0.6), lineWidth: 0.7)
        }
    }

    // MARK: - Animated Placeholder

    @ViewBuilder
    private var animatedPlaceholder: some View {
        let visibleText = String(placeholderText.prefix(placeholderVisibleCount))
        let base = placeholderStack(visibleText)

        if placeholderBreathes {
            base.breathe(amplitude: 0.0025, period: 3.6)
        } else {
            base
        }
    }

    private func placeholderStack(_ text: String) -> some View {
        ZStack(alignment: .leading) {
            Text(text)
                .foregroundStyle(mutedText.opacity(0.92))
                .opacity(1.0 - placeholderAccentProgress)

            Text(text)
                .foregroundStyle(placeholderSyntaxGradient)
                .opacity(placeholderAccentProgress)
        }
        .font(.system(size: 16, weight: .regular))
        .lineLimit(1)
        .accessibilityHidden(true)
    }

    private var placeholderSyntaxGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.35, blue: 0.48),
                Color(red: 0.42, green: 0.78, blue: 0.52),
                Color(red: 0.42, green: 0.56, blue: 0.96),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @MainActor
    private func runPlaceholderReveal() async {
        guard accState.inputText.isEmpty else { return }

        placeholderBreathes = false
        placeholderAccentProgress = 0

        if reduceMotion {
            placeholderVisibleCount = placeholderText.count
            placeholderBreathes = true
            return
        }

        placeholderVisibleCount = 0
        try? await Task.sleep(for: .milliseconds(90))

        for index in 1...placeholderText.count {
            guard !Task.isCancelled, accState.inputText.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.04)) {
                placeholderVisibleCount = index
            }
            try? await Task.sleep(for: .milliseconds(24))
        }

        guard !Task.isCancelled, accState.inputText.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.55)) {
            placeholderAccentProgress = 1
        }
        try? await Task.sleep(for: .milliseconds(560))

        guard !Task.isCancelled, accState.inputText.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.72)) {
            placeholderAccentProgress = 0
        }
        try? await Task.sleep(for: .milliseconds(720))

        guard !Task.isCancelled, accState.inputText.isEmpty else { return }
        placeholderBreathes = true
    }

    // MARK: - Slash Token Badge

    private func slashTokenBadge(_ token: ParsedSlashToken) -> some View {
        HStack(spacing: 4) {
            Image(systemName: token.icon)
                .font(.system(size: 10, weight: .semibold))
            Text("/\(token.displayName)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(theme.textSecondary)
        .background(theme.muted.opacity(theme.isDark ? 0.82 : 0.45), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(theme.border.opacity(0.7), lineWidth: 0.6)
        }
        .onTapGesture {
            accState.activeSlashToken = nil
        }
    }

    // MARK: - Mention Chip

    private func mentionChip(_ mention: ACCContextMention) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "at")
                .font(.system(size: 9, weight: .bold))
            Text(mention.resolvedLabel)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Button {
                accState.activeMentions.removeAll { $0.id == mention.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(theme.textSecondary)
        .background(theme.muted.opacity(theme.isDark ? 0.82 : 0.45), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(theme.border.opacity(0.7), lineWidth: 0.6)
        }
    }

    // MARK: - Submit

    private func submitCommand() {
        let trimmed = accState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Build the normalized command request
        let request = accState.buildCommandRequest()

        // Submit to the agent chat
        agentChat.submitAgentQuery(request.query)

        // Clear input state
        accState.clearInput()

        // The actual inference pipeline dispatch is handled by ChatCoordinator
        if let bootstrap = AppBootstrap.shared {
            let pipeline = bootstrap.coordinator.pipelineService
            bootstrap.coordinator.chatCoordinator.handleCommandCenterSubmission(
                query: request.query,
                slashToken: request.slashToken,
                mentions: request.mentions,
                toolRestrictions: accState.enabledToolNames,
                brainOverride: accState.selectedBrain,
                pipeline: pipeline,
                agentChat: agentChat,
                accState: accState
            )
        }
    }
}
