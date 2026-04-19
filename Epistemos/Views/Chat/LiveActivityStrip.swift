import SwiftUI

/// Prominent status strip rendered at the top of the in-flight
/// assistant bubble. Shows what the model is *doing right now* in
/// plain English so the user doesn't sit staring at a spinner
/// wondering if anything is happening.
///
/// Precedence (only one strip renders at a time; most-active wins):
///   1. Tool in flight — "🔎 Searching the web for 'X'"
///   2. Thinking active — "🧠 Thinking…" with a wall-clock timer
///   3. Default streaming — "✍️ Writing reply…"
///
/// Complements the composer pill + the inline ToolExecutionPreviewCard:
/// the pill is a small steady-state signal, the cards show full detail
/// + streaming result, this strip is the first thing the user sees
/// pop in at the TOP of the bubble so tool activity is unmissable.
struct LiveActivityStrip: View {
    let toolName: String?
    let toolInputJson: String?
    let isThinkingActive: Bool
    let thinkingStartedAt: Date?
    let isStreaming: Bool

    var body: some View {
        HStack(spacing: 8) {
            icon
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(phrase)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if showsTimer, let start = thinkingStartedAt {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    Text(duration(start, now: context.date))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            ProgressView()
                .controlSize(.mini)
                .tint(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - Derived

    private var phrase: String {
        if let tool = toolName, !tool.isEmpty {
            return ToolActivityNarrator.phrase(name: tool, inputJson: toolInputJson)
                ?? "Running a tool…"
        }
        if isThinkingActive {
            return "Thinking…"
        }
        return "Writing reply…"
    }

    private var icon: Image {
        if toolName != nil {
            return Image(systemName: "wrench.and.screwdriver")
        }
        if isThinkingActive {
            return Image(systemName: "brain")
        }
        return Image(systemName: "pencil.line")
    }

    private var tint: Color {
        if toolName != nil { return .orange }
        if isThinkingActive { return .purple }
        return .blue
    }

    private var showsTimer: Bool {
        toolName == nil && isThinkingActive
    }

    private func duration(_ start: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        if elapsed < 60 { return "\(elapsed)s" }
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        if seconds == 0 { return "\(minutes)m" }
        return "\(minutes)m \(seconds)s"
    }
}
