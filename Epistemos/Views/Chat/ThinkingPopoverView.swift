// ThinkingPopoverView.swift
//
// ChatGPT-style "Thinking..." popover that attaches above the streaming
// assistant message bubble. Renders LIVE thinking text while the model
// is still reasoning, collapses into a persistent "Thought for Ns"
// badge once the first answer token arrives.
//
// Pairs with ThinkingTrailView.swift (which is the post-complete
// disclosure group that lives below a finalized message). This one
// is the mid-stream surface; ThinkingTrailView is the record.
//
// 2026-04-18.

import SwiftUI

/// Small pill that surfaces the current thinking state for a streaming
/// assistant turn. When `isThinkingActive` is true, the pill pulses and
/// says "Thinking" — tap opens a popover with the live thinking stream.
/// When the answer begins streaming, it flips to "Thought for Ns" with
/// the live stream frozen as a readable record the user can click back
/// into at any time during the same turn.
struct ThinkingPopoverView: View {
    let thinkingContent: String
    let isThinkingActive: Bool
    let thinkingStartedAt: Date?
    let thinkingEndedAt: Date?

    @State private var isShowingPopover = false

    var body: some View {
        if isThinkingActive {
            popoverButton
                .breathe(amplitude: 0.012, period: 1.4)
        } else {
            popoverButton
        }
    }

    private var popoverButton: some View {
        Button {
            isShowingPopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isThinkingActive ? "brain" : "brain.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.purple.opacity(isThinkingActive ? 0.95 : 0.7))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                if isThinkingActive {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.purple.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background)
            .overlay(border)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
            thinkingPopoverContent
                .frame(minWidth: 360, idealWidth: 480, maxWidth: 640, minHeight: 220, idealHeight: 360, maxHeight: 560)
        }
    }

    // MARK: - Popover body

    private var thinkingPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.purple)
                Text(isThinkingActive ? "Thinking…" : "Thought")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(durationLabel)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.2)

            ScrollView {
                ScrollViewReader { proxy in
                    Text(displayedThinkingContent)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.primary.opacity(0.82))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .id("thinkingBottom")
                        .onChange(of: thinkingContent) { _, _ in
                            if isThinkingActive {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo("thinkingBottom", anchor: .bottom)
                                }
                            }
                        }
                }
            }
            .background(Color.purple.opacity(0.03))
        }
    }

    // MARK: - Labels

    private var label: String {
        if isThinkingActive {
            return "Thinking"
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
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        }
        if seconds < 10 {
            return String(format: "%.1fs", seconds)
        }
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        }
        let minutes = Int(seconds / 60)
        let remainder = Int(seconds.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(remainder)s"
    }

    private var displayedThinkingContent: String {
        thinkingContent.isEmpty
            ? (isThinkingActive
                ? "Waiting for the model's first thought token…"
                : "(No reasoning content was captured.)")
            : thinkingContent
    }

    // MARK: - Styling

    private var background: some View {
        Capsule()
            .fill(Color.purple.opacity(0.10))
    }

    private var border: some View {
        Capsule()
            .strokeBorder(Color.purple.opacity(0.30), lineWidth: 0.75)
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
