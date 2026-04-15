import SwiftUI

// MARK: - Command Bar View
// Floating glass input field with inline brain picker, active /mode badge,
// @mention chips, and multiline text input.

struct CommandBarView: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(AgentChatState.self) private var agentChat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var isInputFocused: Bool
    @State private var placeholderRunID = 0
    @State private var placeholderVisibleCount = 0
    @State private var placeholderAccentProgress = 0.0
    @State private var placeholderBreathes = false

    private let terminalInset = Color(red: 0.115, green: 0.116, blue: 0.116)
    private let terminalBorder = Color.white.opacity(0.10)
    private let mutedTerminalText = Color.white.opacity(0.54)
    private let placeholderText = "Type / for commands"

    var body: some View {
        @Bindable var state = accState

        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                BrainPickerMenu()

                if let token = accState.activeSlashToken {
                    slashTokenBadge(token)
                }

                Spacer()

                Text("⌘J")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(mutedTerminalText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
                            .padding(.leading, 1)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $state.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .accessibilityLabel("Agent command input")
                        .onSubmit {
                            submitCommand()
                        }
                }

                Button {
                    if agentChat.isStreaming {
                        agentChat.stopStreaming()
                    } else {
                        submitCommand()
                    }
                } label: {
                    Image(systemName: agentChat.isStreaming ? "stop.fill" : "return")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            accState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !agentChat.isStreaming
                                ? mutedTerminalText.opacity(0.36)
                                : Color.white.opacity(0.72)
                        )
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(accState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !agentChat.isStreaming)
                .help(agentChat.isStreaming ? "Stop" : "Send (Return)")
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(terminalInset)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isInputFocused
                                    ? Color.white.opacity(0.18)
                                    : terminalBorder,
                                lineWidth: 1
                            )
                    }
            }
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
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
                .foregroundStyle(mutedTerminalText.opacity(0.86))
                .opacity(1.0 - placeholderAccentProgress)

            Text(text)
                .foregroundStyle(placeholderSyntaxGradient)
                .opacity(placeholderAccentProgress)
        }
        .font(.system(size: 14, weight: .regular, design: .monospaced))
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
        .foregroundStyle(Color.white.opacity(0.72))
        .background(Color.white.opacity(0.055), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(terminalBorder, lineWidth: 0.5)
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
                    .foregroundStyle(mutedTerminalText.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.white.opacity(0.68))
        .background(Color.white.opacity(0.055), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(terminalBorder, lineWidth: 0.5)
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
