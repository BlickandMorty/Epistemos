import SwiftUI

struct NoteWritingToolsMenu: View {
    let pageId: String
    let dismiss: () -> Void

    @State private var instruction = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Describe your change", text: $instruction)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                aiActionButton("Proofread", icon: "magnifyingglass", op: "proofread")
                aiActionButton("Rewrite", icon: "arrow.triangle.2.circlepath", op: "rewrite")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                menuRow(icon: "face.smiling", title: "Friendly", op: "rewrite_friendly")
                menuRow(icon: "briefcase", title: "Professional", op: "rewrite_professional")
                menuRow(icon: "text.badge.minus", title: "Concise", op: "rewrite_concise")
            }
            .padding(.vertical, 6)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                menuRow(icon: "text.quote", title: "Summary", op: "summarize")
                menuRow(icon: "list.bullet.rectangle", title: "Key Points", op: "keyPoints")
                menuRow(icon: "list.bullet", title: "List", op: "toList")
                menuRow(icon: "tablecells", title: "Table", op: "toTable")
            }
            .padding(.vertical, 6)

            Divider()

            menuRow(icon: "pencil.line", title: "Compose…", op: "continue")
                .padding(.vertical, 6)
        }
        .frame(width: 240)
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

    private func menuRow(icon: String, title: String, op: String) -> some View {
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
        var userInfo: [String: String] = ["operation": op, "pageId": pageId]
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            userInfo["instruction"] = trimmed
        }
        NotificationCenter.default.post(
            name: Notification.Name("EpistemosAIOperation"),
            object: nil,
            userInfo: userInfo
        )
    }
}
