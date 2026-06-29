import SwiftUI

// Phase 1 (Step 3) — native session canvas: header + transcript + composer, wired to the
// AgentSessionController. This is the native chat loop's view layer (no WebView). Permission /
// elicitation sheet presentation is added when those native sheets are ported (later in Step 3).

@MainActor
struct AgentSessionCanvasView: View {
    let controller: AgentSessionController
    let theme: EpistemosTheme

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            AgentSessionHeaderView(status: controller.status, theme: theme)
            Divider().overlay(theme.border.opacity(0.5))
            AgentTranscriptView(transcript: controller.transcript, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().overlay(theme.border.opacity(0.5))
            AgentComposerBar(
                text: $draft,
                isStreaming: controller.status == .streaming,
                theme: theme,
                onSend: { controller.send($0) },
                onCancel: { controller.cancel() }
            )
        }
        .background(GooseSurfaceStyle.background(for: theme, role: .canvas))
    }
}

@MainActor
struct AgentSessionHeaderView: View {
    let status: AgentSessionController.Status
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 8) {
            Text("Goose")
                .font(GooseSurfaceStyle.bodyFont(12, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color)
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(GooseSurfaceStyle.bodyFont(10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var statusText: String {
        switch status {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .ready: return "Ready"
        case .streaming: return "Streaming…"
        case .failed(let message): return "Error: \(message)"
        }
    }

    private var statusColor: Color {
        switch status {
        case .ready, .streaming: return theme.resolved.accent.color
        case .failed: return .red
        case .idle, .connecting: return theme.textTertiary
        }
    }
}

@MainActor
struct AgentComposerBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let theme: EpistemosTheme
    let onSend: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message Goose…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(GooseSurfaceStyle.bodyFont(13))
                .foregroundStyle(theme.resolved.foreground.color)
                .lineLimit(1...6)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Rectangle().fill(theme.resolved.chatSurface.color.opacity(0.85)))
                .overlay(Rectangle().stroke(theme.border.opacity(0.55), lineWidth: 1))
                .onSubmit(submit)

            if isStreaming {
                composerButton(system: "stop.fill", tint: .red, action: onCancel)
                    .help("Cancel")
            } else {
                composerButton(
                    system: "arrow.up.circle.fill",
                    tint: theme.resolved.accent.color,
                    action: submit
                )
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
                .help("Send")
            }
        }
        .padding(12)
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        let value = trimmed
        guard !value.isEmpty else { return }
        onSend(value)
        text = ""
    }

    @ViewBuilder
    private func composerButton(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }
}
