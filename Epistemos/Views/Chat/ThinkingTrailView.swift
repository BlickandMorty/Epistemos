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
    let content: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.purple.opacity(0.7))

                    Text("Reasoning")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("\(wordCount) words")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // Content — collapsible
            if isExpanded {
                Divider().opacity(0.15)

                ScrollView {
                    Text(content)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 300)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.purple.opacity(0.12), lineWidth: 1)
        )
    }

    private var wordCount: Int {
        content.split(separator: " ").count
    }
}
