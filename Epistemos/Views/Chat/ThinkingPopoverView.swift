// ThinkingPopoverView.swift
//
// Legacy file name kept for compatibility, but this is now an INLINE
// live-thinking panel that renders inside the streaming assistant turn
// instead of opening a detached popover. While the model is reasoning,
// the panel defaults expanded; once answer text begins, it collapses to
// a "Thought for Ns" chip that can be reopened on demand.
//
// Pairs with ThinkingTrailView.swift, which remains the post-complete
// persisted reasoning record on finalized messages.
//
// 2026-04-20.

import SwiftUI

/// Small inline panel that surfaces the current thinking state for a
/// streaming assistant turn. The legacy type name stays because call
/// sites already reference it, but it no longer uses a detached popover.
struct ThinkingPopoverView: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let thinkingContent: String
    let isThinkingActive: Bool
    let thinkingStartedAt: Date?
    let thinkingEndedAt: Date?

    @State private var isExpanded = true

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        panel
            .onChange(of: isThinkingActive) { _, active in
                if active {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isExpanded = true
                    }
                } else {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                        isExpanded = false
                    }
                }
            }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProcessDisclosureHeader(
                title: "Think",
                tone: .thinking,
                isExpanded: isExpanded,
                action: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                }
            ) {
                Text(label)
                    .font(ClaudeAppTypography.monoFont(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            } trailing: {
                if isThinkingActive {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(ProcessDisclosureTone.thinking.tint(theme: theme).opacity(0.82))
                }
            }
            .help(helpText)
            .accessibilityLabel(accessibilityLabel)

            if isExpanded {
                ProcessDisclosureDivider()

                ScrollView {
                    ScrollViewReader { proxy in
                        ProcessDisclosureTextBlock(
                            content: displayedThinkingContent,
                            tone: .thinking
                        )
                            .padding(.top, 4)
                            .id("thinkingBottom")
                            .onChange(of: thinkingContent) { _, _ in
                                guard isThinkingActive else { return }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                                    proxy.scrollTo("thinkingBottom", anchor: .bottom)
                                }
                            }
                    }
                }
                .frame(maxHeight: 300)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .modifier(ThinkingPulse(active: isThinkingActive))
    }

    // MARK: - Labels

    private var label: String {
        if isThinkingActive {
            return durationSeconds.map { "Thinking \(formatSeconds($0))" } ?? "Thinking"
        }
        return "Thought" + (durationSeconds.map { " for \(formatSeconds($0))" } ?? "")
    }

    private var helpText: String {
        isThinkingActive
            ? "Open live thinking stream"
            : "Show the model's reasoning for this turn"
    }

    private var accessibilityLabel: Text {
        if isThinkingActive {
            return Text("Model is thinking. Tap to open the live reasoning stream.")
        }
        if let seconds = durationSeconds {
            return Text("Model thought for \(formatSeconds(seconds)). Tap to read the reasoning.")
        }
        return Text("Model reasoning. Tap to read.")
    }

    private var durationLabel: String {
        guard let seconds = durationSeconds else { return "" }
        return formatSeconds(seconds)
    }

    private var durationSeconds: Double? {
        guard let start = thinkingStartedAt else { return nil }
        let end = thinkingEndedAt ?? Date()
        let interval = end.timeIntervalSince(start)
        return interval >= 0 ? interval : nil
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0ms" }
        let safeSeconds = max(0, seconds)
        if safeSeconds < 1 {
            return String(format: "%.0fms", safeSeconds * 1000)
        }
        if safeSeconds < 10 {
            return String(format: "%.1fs", safeSeconds)
        }
        if safeSeconds < 60 {
            return String(format: "%.0fs", safeSeconds)
        }
        let minutes = Int(safeSeconds / 60)
        let remainder = Int(safeSeconds.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(remainder)s"
    }

    private var displayedThinkingContent: String {
        thinkingContent.isEmpty
            ? (isThinkingActive
                ? "Waiting for the model's first thought token…"
                : "(No reasoning content was captured.)")
            : thinkingContent
    }
}

private struct ThinkingPulse: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.breathe(amplitude: 0.012, period: 1.4)
        } else {
            content
        }
    }
}

#Preview("Thinking active") {
    ThinkingPopoverView(
        thinkingContent: "Let me break this down step by step. First, I'll consider the user's intent — they want a concise summary. Second, I need to weigh tradeoffs between brevity and completeness.",
        isThinkingActive: true,
        thinkingStartedAt: Date().addingTimeInterval(-3.5),
        thinkingEndedAt: nil
    )
    .padding()
    .environment(UIState())
}

#Preview("Thought complete") {
    ThinkingPopoverView(
        thinkingContent: "Let me break this down step by step. First, I'll consider the user's intent — they want a concise summary. Second, I need to weigh tradeoffs between brevity and completeness. Final decision: lead with the summary and append two sentences of detail.",
        isThinkingActive: false,
        thinkingStartedAt: Date().addingTimeInterval(-12),
        thinkingEndedAt: Date()
    )
    .padding()
    .environment(UIState())
}
