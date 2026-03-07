import SwiftUI

// MARK: - Note Chat Bar
// Starts as a small bubble pinned to the bottom of the note editor.
// Tap to expand into the full chat bar with message history.
// Scrolling down in the note collapses it back to the bubble.
// Responses appear in a slide-up glass panel with markdown rendering.

struct NoteChatBar: View {
    @Environment(NoteChatState.self) private var noteChat
    @Environment(TriageService.self) private var triageService
    @Environment(LLMService.self) private var llmService
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 6) {
            // Slide-up response panel (free-text queries)
            if noteChat.useResponsePanel && noteChat.hasResponse && noteChat.isBarExpanded {
                responsePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Inline accept/discard (context menu operations)
            if noteChat.hasResponse, !noteChat.isStreaming, !noteChat.useResponsePanel {
                acceptDiscardRow
            }

            // Error display
            if let error = noteChat.error {
                errorRow(error)
            }

            // Bubble or expanded bar
            if noteChat.isBarExpanded {
                expandedBar
                    .transition(.opacity)
            } else {
                chatBubble
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Collapsed Bubble

    private var chatBubble: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                noteChat.isBarExpanded = true
            }
        } label: {
            ZStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.accent)

                // Unread indicator when there are messages
                if !noteChat.messages.isEmpty {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 10, y: -10)
                }
            }
            .frame(width: 44, height: 44)
            .glassEffect(.regular, in: Circle())
        }
        .buttonStyle(.plain)
        .physicsPress()
        .help("Open chat")
    }

    // MARK: - Expanded Bar

    private var expandedBar: some View {
        VStack(spacing: 0) {
            // Recent messages (compact, scrollable)
            if !noteChat.messages.isEmpty && !noteChat.hasResponse {
                recentMessages
            }

            inputRow
        }
    }

    // MARK: - Recent Messages

    private var recentMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(noteChat.messages.suffix(10)) { msg in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: msg.role == .user ? "person.fill" : "sparkles")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(msg.role == .user ? theme.textTertiary : theme.accent)
                                .frame(width: 14, alignment: .center)
                                .padding(.top, 3)

                            if msg.role == .user {
                                Text(msg.content)
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(2)
                            } else {
                                Text(msg.content)
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.foreground)
                                    .lineLimit(3)
                            }
                        }
                        .id(msg.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 120)
            .onAppear {
                if let last = noteChat.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 4)
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            @Bindable var chat = noteChat

            // Mode picker
            modePickerButton

            TextField("Ask about this note\u{2026}", text: $chat.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.epBody)
                .lineLimit(1...4)
                .foregroundStyle(theme.foreground)
                .onKeyPress(phases: .down) { keyPress in
                    if keyPress.key == .return, keyPress.modifiers.contains(.command) {
                        submit()
                        return .handled
                    }
                    return .ignored
                }

            // Send or Stop button
            if noteChat.isStreaming {
                Button {
                    noteChat.stopStreaming()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.error)
                }
                .buttonStyle(.plain)
                .help("Stop generation")
            } else {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            noteChat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? theme.textTertiary : .accentColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(noteChat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send (\u{2318}Enter)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .siriGlow(cornerRadius: 22, lineWidth: 1.2, isActive: noteChat.isStreaming)
    }

    // MARK: - Response Panel

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accent)
                Text("Response")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.foreground)

                Spacer()

                if noteChat.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(noteChat.responseText, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy response")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().opacity(0.3)

            // Response content
            ScrollView {
                if noteChat.responseText.isEmpty && noteChat.isStreaming {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Thinking\u{2026}")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                } else {
                    MarkdownTextView(
                        content: noteChat.responseText + (noteChat.isStreaming ? " \u{258D}" : ""),
                        theme: theme
                    )
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .padding(14)
                }
            }
            .frame(maxHeight: 280)

            // Accept / Discard buttons
            if !noteChat.isStreaming {
                Divider().opacity(0.3)

                HStack(spacing: 8) {
                    Button {
                        noteChat.acceptResponse()
                    } label: {
                        Label("Insert into note", systemImage: "text.insert")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(theme.accent)
                    .physicsPress()

                    Button {
                        noteChat.discardResponse()
                    } label: {
                        Label("Discard", systemImage: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .physicsPress()

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .siriGlow(cornerRadius: 16, lineWidth: 1.2, isActive: noteChat.isStreaming)
    }

    // MARK: - Mode Picker

    private var modePickerButton: some View {
        Menu {
            Button {
                noteChat.chatMode = .auto
                noteChat.overrideProvider = nil
            } label: {
                Label("Auto (Apple AI + Cloud)", systemImage: "sparkles")
            }

            Button {
                noteChat.chatMode = .cloudOnly
                noteChat.overrideProvider = nil
            } label: {
                Label("Cloud Only", systemImage: "cloud")
            }

            Divider()

            ForEach(availableProviders, id: \.self) { provider in
                Button {
                    noteChat.chatMode = .provider
                    noteChat.overrideProvider = provider
                } label: {
                    Label(provider.displayName, systemImage: providerIcon(provider))
                }
            }
        } label: {
            Image(systemName: currentModeIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(noteChat.chatMode == .auto ? theme.textTertiary : theme.accent)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(currentModeHelp)
    }

    private var currentModeIcon: String {
        switch noteChat.chatMode {
        case .auto: return "sparkles"
        case .cloudOnly: return "cloud.fill"
        case .provider:
            return providerIcon(noteChat.overrideProvider ?? .anthropic)
        }
    }

    private var currentModeHelp: String {
        switch noteChat.chatMode {
        case .auto: return "Auto: Apple AI for simple, cloud for complex"
        case .cloudOnly: return "Cloud Only: uses your selected API"
        case .provider:
            return "Manual: \(noteChat.overrideProvider?.displayName ?? "Anthropic")"
        }
    }

    private var availableProviders: [LLMProviderType] {
        LLMProviderType.allCases.filter { $0 != .appleIntelligence }
    }

    private func providerIcon(_ provider: LLMProviderType) -> String {
        switch provider {
        case .anthropic: "a.circle"
        case .openai: "circle.hexagongrid"
        case .google: "g.circle"
        case .kimi: "k.circle"
        case .ollama: "desktopcomputer"
        case .appleIntelligence: "apple.logo"
        }
    }

    // MARK: - Accept / Discard (inline mode)

    private var acceptDiscardRow: some View {
        HStack(spacing: 8) {
            Button {
                noteChat.acceptResponse()
            } label: {
                Label("Keep in note", systemImage: "checkmark")
                    .font(.epCaption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: Capsule())
            .physicsPress()

            Button {
                noteChat.discardResponse()
            } label: {
                Label("Discard", systemImage: "xmark")
                    .font(.epCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: Capsule())
            .physicsPress()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Error

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(theme.error)

            Text(message)
                .font(.epSmall)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)

            Spacer()

            Button { noteChat.error = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: - Actions

    private func submit() {
        noteChat.submitQuery(noteChat.inputText, triageService: triageService, llmService: llmService)
    }
}
