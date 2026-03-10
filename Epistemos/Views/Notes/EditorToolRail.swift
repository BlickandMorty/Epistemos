import SwiftUI

// MARK: - EditorToolRail
// Right-side floating tool rail for the prose editor. Shows formatting shortcuts
// and an AI writing tools button. Inspired by screenshot reference (NotePlan-style
// editor rail) but adapted to Epistemos' theme language.
//
// Appears as a vertical pill of icon buttons on the right edge of the editor.
// AI button opens a popover with writing tool actions routed through the existing
// NoteChatState / TriageService infrastructure.

struct EditorToolRail: View {
    let pageId: String
    @Environment(UIState.self) private var ui
    @State private var showAIMenu = false

    var body: some View {
        VStack(spacing: 2) {
            // Heading
            railButton(icon: "textformat.size", tooltip: "Heading") {
                post(op: "heading")
            }

            // Checkbox / Task
            railButton(icon: "checklist", tooltip: "Task List") {
                post(op: "taskList")
            }

            // Bullet list
            railButton(icon: "list.bullet", tooltip: "Bullet List") {
                post(op: "bulletList")
            }

            // Numbered list
            railButton(icon: "list.number", tooltip: "Numbered List") {
                post(op: "numberedList")
            }

            Divider()
                .frame(width: 20)
                .padding(.vertical, 2)

            // Bold
            railButton(icon: "bold", tooltip: "Bold") {
                post(op: "bold")
            }

            // Italic
            railButton(icon: "italic", tooltip: "Italic") {
                post(op: "italic")
            }

            // Inline code
            railButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code") {
                post(op: "inlineCode")
            }

            // Quote
            railButton(icon: "text.quote", tooltip: "Quote") {
                post(op: "quote")
            }

            Divider()
                .frame(width: 20)
                .padding(.vertical, 2)

            // Table
            railButton(icon: "tablecells", tooltip: "Table") {
                post(op: "table")
            }

            // Code block
            railButton(icon: "curlybraces", tooltip: "Code Block") {
                post(op: "codeBlock")
            }

            // Divider
            railButton(icon: "minus", tooltip: "Divider") {
                post(op: "divider")
            }

            Divider()
                .frame(width: 20)
                .padding(.vertical, 2)

            // AI Writing Tools
            railButton(icon: "sparkles", tooltip: "AI Writing Tools") {
                showAIMenu.toggle()
            }
            .popover(isPresented: $showAIMenu, arrowEdge: .leading) {
                AIWritingToolsMenu(pageId: pageId) {
                    showAIMenu = false
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .frame(width: 36)
    }

    private func railButton(
        icon: String,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func post(op: String) {
        NotificationCenter.default.post(
            name: Notification.Name("EpistemosEditorToolRailAction"),
            object: nil,
            userInfo: ["operation": op, "pageId": pageId]
        )
    }
}

// MARK: - AI Writing Tools Menu

struct AIWritingToolsMenu: View {
    let pageId: String
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                aiActionButton("Proofread", icon: "magnifyingglass", op: "proofread")
                aiActionButton("Rewrite", icon: "arrow.triangle.2.circlepath", op: "rewrite")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Tone options
            VStack(alignment: .leading, spacing: 2) {
                toneRow(icon: "face.smiling", title: "Friendly", op: "rewrite_friendly")
                toneRow(icon: "briefcase", title: "Professional", op: "rewrite_professional")
                toneRow(icon: "text.badge.minus", title: "Concise", op: "rewrite_concise")
            }
            .padding(.vertical, 6)

            Divider()

            // Transform options
            VStack(alignment: .leading, spacing: 2) {
                toneRow(icon: "text.quote", title: "Summary", op: "summarize")
                toneRow(icon: "list.bullet.rectangle", title: "Key Points", op: "keyPoints")
                toneRow(icon: "list.bullet", title: "List", op: "toList")
                toneRow(icon: "tablecells", title: "Table", op: "toTable")
            }
            .padding(.vertical, 6)

            Divider()

            // Compose
            toneRow(icon: "pencil.line", title: "Compose\u{2026}", op: "continue")
                .padding(.vertical, 6)
        }
        .frame(width: 200)
    }

    private func aiActionButton(_ title: String, icon: String, op: String) -> some View {
        Button {
            postAI(op: op)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        }
        .buttonStyle(.plain)
    }

    private func toneRow(icon: String, title: String, op: String) -> some View {
        Button {
            postAI(op: op)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func postAI(op: String) {
        NotificationCenter.default.post(
            name: Notification.Name("EpistemosAIOperation"),
            object: nil,
            userInfo: ["operation": op, "pageId": pageId]
        )
    }
}
