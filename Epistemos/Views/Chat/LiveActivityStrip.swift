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
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let toolName: String?
    let toolInputJson: String?
    let isThinkingActive: Bool
    let thinkingStartedAt: Date?
    let isStreaming: Bool

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProcessDisclosureHeader(title: statusBadgeTitle, tone: tone) {
                phraseLabel
            } trailing: {
                HStack(spacing: 8) {
                    if showsTimer, let start = thinkingStartedAt {
                        TimelineView(.periodic(from: start, by: 1)) { context in
                            Text(duration(start, now: context.date))
                                .font(ClaudeAppTypography.monoFont(size: 11))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    ProgressView()
                        .controlSize(.mini)
                        .tint(tint)
                }
            }

            ProcessDisclosureDivider()
        }
    }

    // MARK: - Derived

    @ViewBuilder
    private var phraseLabel: some View {
        if reduceMotion {
            activityText(phrase)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 4.0)) { context in
                activityText(animatedPhrase(at: context.date))
            }
        }
    }

    private func activityText(_ text: String) -> some View {
        Text(text)
            .font(ClaudeAppTypography.monoFont(size: 12, weight: .medium))
            .foregroundStyle(theme.resolved.foreground.color)
            .lineLimit(1)
    }

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

    private var statusBadgeTitle: String {
        if toolName != nil { return "TOOL" }
        if isThinkingActive { return "THINK" }
        return "WRITE"
    }

    private var tone: ProcessDisclosureTone {
        if toolName != nil { return .tool }
        if isThinkingActive { return .thinking }
        return .write
    }

    private var tint: Color {
        if toolName != nil { return .orange }
        if isThinkingActive { return .purple }
        return .blue
    }

    private var showsTimer: Bool {
        toolName == nil && isThinkingActive
    }

    private func animatedPhrase(at date: Date) -> String {
        let base = phrase
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dotCount = Int((date.timeIntervalSinceReferenceDate * 2.2).truncatingRemainder(dividingBy: 3)) + 1
        return base + String(repeating: ".", count: dotCount)
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
