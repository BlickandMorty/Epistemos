import SwiftUI

// MARK: - Note Chat Bar
// Always-visible composition bar pinned to the bottom of the note editor.
// No toggle, no orb — just a text field that's always ready.
// Accept/Discard appear after response completes. SiriGlow indicates streaming.
// Mode picker (left of text field): Auto / Cloud / Manual provider selection.

struct NoteChatBar: View {
    @Environment(NoteChatState.self) private var noteChat
    @Environment(TriageService.self) private var triageService
    @Environment(LLMService.self) private var llmService
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 6) {
            // Accept/Discard when response is complete
            if noteChat.hasResponse, !noteChat.isStreaming {
                acceptDiscardRow
            }

            // Error display
            if let error = noteChat.error {
                errorRow(error)
            }

            // Input bar — always visible
            inputRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            @Bindable var chat = noteChat

            // Mode picker — compact icon button with menu
            modePickerButton

            TextField("Ask about this note…", text: $chat.inputText, axis: .vertical)
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
                .help("Send (⌘Enter)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 500)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .siriGlow(cornerRadius: 22, lineWidth: 1.2, isActive: noteChat.isStreaming)
    }

    // MARK: - Mode Picker

    private var modePickerButton: some View {
        Menu {
            // Auto mode — TriageService decides (Apple AI + Cloud)
            Button {
                noteChat.chatMode = .auto
                noteChat.overrideProvider = nil
            } label: {
                Label("Auto (Apple AI + Cloud)", systemImage: "sparkles")
            }

            // Cloud only — bypass triage, use selected cloud API
            Button {
                noteChat.chatMode = .cloudOnly
                noteChat.overrideProvider = nil
            } label: {
                Label("Cloud Only", systemImage: "cloud")
            }

            Divider()

            // Specific provider selection
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

    // MARK: - Accept / Discard

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
