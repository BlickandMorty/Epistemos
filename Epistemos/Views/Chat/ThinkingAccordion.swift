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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(Motion.quick) { isExpanded.toggle() }
                }

            if isExpanded && !reasoningText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if isLive {
                            liveStatusStrip
                        }

                        Text(reasoningText)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(theme.foreground.opacity(0.74))
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 14)
                }
                .frame(maxHeight: isLive ? 220 : 300)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .assistantInsetChrome(theme: theme, cornerRadius: 18, isEmphasized: isLive || isExpanded)
        .animation(Motion.smooth, value: isExpanded)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            thinkingOrb

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isLive ? "Thinking" : "Thought for")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.foreground)

                    if let badge = durationBadgeText {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isLive ? theme.accent : theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(theme.glassBg.opacity(theme.isDark ? 0.78 : 0.95)))
                    }
                }

                Text(isLive ? "Live model deliberation" : "Model reasoning captured for this answer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if isLive && !reduceMotion {
                TimelineView(.periodic(from: .now, by: 0.9)) { context in
                    let phase = Int(context.date.timeIntervalSinceReferenceDate) % 3
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(theme.accent.opacity(index <= phase ? 0.92 : 0.22))
                                .frame(width: index == phase ? 16 : 8, height: 5)
                        }
                    }
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var thinkingOrb: some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.12))
                .frame(width: 28, height: 28)

            Circle()
                .strokeBorder(theme.accent.opacity(0.28), lineWidth: 0.8)
                .frame(width: 28, height: 28)

            Image(systemName: isLive ? "sparkles" : "brain.head.profile")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isLive ? theme.accent : theme.foreground.opacity(0.8))
                .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: isLive && !reduceMotion)
        }
    }

    private var liveStatusStrip: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.accent)

            Text("Streaming model reasoning as it arrives")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.glassBg.opacity(theme.isDark ? 0.66 : 0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(0.85), lineWidth: 0.6)
        )
    }

    private var durationBadgeText: String? {
        if let duration {
            return formatDuration(duration)
        }
        guard isLive else { return nil }
        return "Live"
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
