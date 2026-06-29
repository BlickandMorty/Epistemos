import SwiftUI

// Phase 1 (Step 3) — native render of `AgentTranscript`.
//
// Read-only: the reducer (AgentTranscript) is the source of truth; this view only renders its parts.
// Each part kind gets a distinct visual treatment so thinking ≠ answer ≠ tool ≠ user (charter:
// thinking is never visually merged into the answer stream). No WebView. Tool cards show only
// {title, kind, status} — no diff hunks (Round 2 §4).

@MainActor
struct AgentTranscriptView: View {
    let transcript: AgentTranscript
    let theme: EpistemosTheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(transcript.parts) { part in
                        AgentPartView(part: part, theme: theme)
                            .id(part.id)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: transcript.parts.last?.id) { _, lastID in
                guard let lastID else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}

private struct AgentPartView: View {
    let part: AgentPart
    let theme: EpistemosTheme

    var body: some View {
        switch part.kind {
        case .user:
            labeledText(part.text, label: "You", color: theme.resolved.accent.color)
        case .answer:
            Text(part.text)
                .font(GooseSurfaceStyle.bodyFont(13))
                .foregroundStyle(theme.resolved.foreground.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .thinking:
            VStack(alignment: .leading, spacing: 3) {
                Text("Thinking")
                    .font(GooseSurfaceStyle.bodyFont(9, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                Text(part.text)
                    .font(GooseSurfaceStyle.bodyFont(12))
                    .italic()
                    .foregroundStyle(theme.textTertiary)
                    .textSelection(.enabled)
            }
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                Rectangle().fill(theme.border.opacity(0.6)).frame(width: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .tool:
            toolCard(part.tool)
        case .error:
            labeledText(part.text, label: "Error", color: .red)
        }
    }

    @ViewBuilder
    private func labeledText(_ text: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(GooseSurfaceStyle.bodyFont(9, weight: .semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
            Text(text)
                .font(GooseSurfaceStyle.bodyFont(13))
                .foregroundStyle(theme.resolved.foreground.color)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func toolCard(_ tool: AgentToolPart?) -> some View {
        if let tool {
            HStack(spacing: 8) {
                Image(systemName: toolIcon(tool.kind))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                Text(tool.title)
                    .font(GooseSurfaceStyle.bodyFont(11, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(statusLabel(tool.status))
                    .font(GooseSurfaceStyle.bodyFont(9, weight: .semibold))
                    .foregroundStyle(statusColor(tool.status))
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Rectangle().fill(theme.resolved.card.color.opacity(0.6)))
            .overlay(Rectangle().stroke(theme.border.opacity(0.5), lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toolIcon(_ kind: GooseACPToolKind?) -> String {
        switch kind {
        case .read: return "doc.text"
        case .edit: return "pencil"
        case .delete: return "trash"
        case .move: return "arrow.right.doc.on.clipboard"
        case .search: return "magnifyingglass"
        case .execute: return "terminal"
        case .think: return "brain"
        case .fetch: return "arrow.down.circle"
        case .switchMode: return "arrow.triangle.2.circlepath"
        case .other, .none: return "wrench.and.screwdriver"
        }
    }

    private func statusLabel(_ status: GooseACPToolCallStatus?) -> String {
        switch status {
        case .pending: return "pending"
        case .inProgress: return "running"
        case .completed: return "done"
        case .failed: return "failed"
        case .none: return ""
        }
    }

    private func statusColor(_ status: GooseACPToolCallStatus?) -> Color {
        switch status {
        case .failed: return .red
        case .completed: return theme.resolved.accent.color
        default: return theme.textTertiary
        }
    }
}
