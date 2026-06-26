import SwiftUI

// Native unified-diff renderer for an edit/write tool card (the file changes opencode produced — from the history
// projector's WorkHistoryPart.fileDiffs). Flat/compact OpenCode-TUI minimal: boxy, monospace, theme tokens, no donor
// chrome. Line-tints added (+) / removed (-) / hunk (@@) / file-header (---/+++) lines; everything else is context.
// Pure presentation of a self-describing unified-diff string (filename lives in the ---/+++ header).
struct WorkDiffText: View {
    let diff: String
    var theme: EpistemosTheme = .nativeDefault
    var maxLines: Int = 40   // guard against a huge diff dominating the transcript

    private struct DiffLine: Identifiable { let id: Int; let text: String; let kind: Kind
        enum Kind { case added, removed, hunk, header, context } }

    private var lines: [DiffLine] {
        diff.split(separator: "\n", omittingEmptySubsequences: false).prefix(maxLines).enumerated().map { index, raw in
            let text = String(raw)
            let kind: DiffLine.Kind
            if text.hasPrefix("+++") || text.hasPrefix("---") { kind = .header }
            else if text.hasPrefix("@@") { kind = .hunk }
            else if text.hasPrefix("+") { kind = .added }
            else if text.hasPrefix("-") { kind = .removed }
            else { kind = .context }
            return DiffLine(id: index, text: text, kind: kind)
        }
    }

    private var truncated: Bool { diff.split(separator: "\n", omittingEmptySubsequences: false).count > maxLines }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
                Text(line.text.isEmpty ? " " : line.text)
                    .font(WorkPixelFont.body(11))
                    .foregroundStyle(color(line.kind))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if truncated {
                Text("… diff truncated").font(WorkPixelFont.body(9)).foregroundStyle(theme.textTertiary)
            }
        }
        .padding(6)
        .textSelection(.enabled)
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border.opacity(0.6), lineWidth: 0.6))
    }

    private func color(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added: return WorkSurfaceStyle.diffAdded(for: theme)
        case .removed: return WorkSurfaceStyle.diffRemoved(for: theme)
        case .hunk: return WorkSurfaceStyle.diffHunk(for: theme)
        case .header: return theme.mutedForeground
        case .context: return theme.mutedForeground.opacity(0.85)
        }
    }
}

#Preview {
    WorkDiffText(diff: "--- a/Work.swift\n+++ b/Work.swift\n@@ -1,3 +1,3 @@\n context line\n-let old = 1\n+let new = 2\n more context")
        .frame(width: 360).padding()
}
