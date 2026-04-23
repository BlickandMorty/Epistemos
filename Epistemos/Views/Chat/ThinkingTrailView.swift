// ThinkingTrailView.swift
//
// Collapsible "Reasoning" disclosure group for extended thinking blocks.
// Shows the model's internal reasoning process in a non-intrusive,
// expandable section. Renders between the main response and artifacts.
//
// Supports Anthropic extended thinking and OpenAI reasoning tokens.
//
// 2026-04-06.

import SwiftUI

struct ThinkingTrailView: View {
    @Environment(UIState.self) private var ui

    let content: String
    let durationSeconds: Double?

    init(content: String, durationSeconds: Double? = nil) {
        self.content = content
        self.durationSeconds = durationSeconds
    }

    @State private var isExpanded = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProcessDisclosureHeader(
                title: "Think",
                tone: .thinking,
                isExpanded: isExpanded,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            ) {
                HStack(spacing: 6) {
                    Text(headerLabel)
                        .font(ClaudeAppTypography.monoFont(size: 11, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Text("\(wordCount) words")
                        .font(ClaudeAppTypography.monoFont(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if isExpanded {
                ProcessDisclosureDivider()

                ScrollView {
                    ProcessDisclosureTextBlock(
                        content: content,
                        tone: .thinking
                    )
                        .padding(.top, 4)
                }
                .frame(maxHeight: 300)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var wordCount: Int {
        content.split(separator: " ").count
    }

    /// Header label. Shows "Thought for Ns" when we have a captured
    /// duration (ChatState populates this at turn completion from the
    /// thinkingStartedAt → thinkingEndedAt window), or falls back to
    /// plain "Reasoning" for legacy messages that pre-date the field.
    private var headerLabel: String {
        guard let seconds = durationSeconds, seconds >= 1 else { return "Reasoning" }
        if seconds < 60 {
            return "Thought for \(Int(seconds.rounded()))s"
        }
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60).rounded())
        if remainingSeconds == 0 { return "Thought for \(minutes)m" }
        return "Thought for \(minutes)m \(remainingSeconds)s"
    }
}
