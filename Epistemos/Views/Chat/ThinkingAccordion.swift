import SwiftUI

// MARK: - Thinking Accordion
// Collapsible disclosure showing the model's reasoning/thinking process.
// Used in two contexts:
// 1. StreamingIndicator — live reasoning during streaming (auto-expanded)
// 2. MessageBubble — completed messages with persisted reasoning (collapsed by default)

struct ThinkingAccordion: View {
    let reasoningText: String
    let duration: Double?
    let isLive: Bool

    @Environment(UIState.self) private var ui
    @State private var isExpanded: Bool

    private var theme: EpistemosTheme { ui.theme }

    init(reasoningText: String, duration: Double? = nil, isLive: Bool = false) {
        self.reasoningText = reasoningText
        self.duration = duration
        self.isLive = isLive
        // Live reasoning starts expanded; completed messages start collapsed
        self._isExpanded = State(initialValue: isLive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to toggle
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(Motion.quick) { isExpanded.toggle() }
                }

            // Body — collapsible reasoning text
            if isExpanded && !reasoningText.isEmpty {
                Rectangle()
                    .fill(theme.glassBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, Spacing.sm)

                ScrollView {
                    Text(reasoningText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(theme.foreground.opacity(0.65))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(Spacing.md)
                }
                .frame(maxHeight: isLive ? 200 : 300)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.glassBg.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isLive ? theme.accent.opacity(0.2) : theme.glassBorder,
                    lineWidth: 0.5
                )
        )
        .animation(Motion.smooth, value: isExpanded)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            // Brain icon with pulse for live
            Image(systemName: isLive ? "brain" : "brain.filled.head.profile")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isLive ? theme.accent : theme.mutedForeground.opacity(0.6))
                .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: isLive)

            Text(isLive ? "Thinking" : "Thought Process")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isLive ? theme.foreground.opacity(0.8) : theme.mutedForeground.opacity(0.7))

            // Duration badge
            if let dur = duration {
                Text(formatDuration(dur))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.glassBg))
            } else if isLive {
                // Live timer dot
                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
                    .opacity(0.8)
            }

            Spacer()

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.mutedForeground.opacity(0.4))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(mins)m \(secs)s"
        }
    }
}
