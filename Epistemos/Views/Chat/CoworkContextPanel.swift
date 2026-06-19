import SwiftUI

// REOPENED CONTEXT (P7.6, owner 2026-06-19): a REAL, visible CONTEXT panel — what's
// actually in the model's context for this chat, aggregated from REAL run telemetry
// (context-window usage, @-mentioned context notes, file attachments, files the
// agent touched this run), with an HONEST empty state. Replaces the scattered tiny
// composer strips ("only shows when tools were used"). Reachable from chat by
// tapping the context badge; reads ChatState from the environment.
struct CoworkContextPanel: View {
    @Environment(ChatState.self) private var chat

    private var contextNotes: [ContextAttachment] { chat.pendingContextAttachments }
    private var fileAttachments: [FileAttachment] { chat.pendingAttachments }
    private var filesTouched: [CoworkRunContext.TouchedFile] {
        // File mutation is MAS-forbidden → naturally empty outside Pro (gate explicit).
        guard ToolSurfacePolicy.resolvedDistribution(.currentBuild) != .coreAppStore else { return [] }
        return CoworkRunContext.filesTouched(
            in: chat.messages.last(where: { $0.role == .assistant })?.contentBlocks
        )
    }
    private var hasAttachments: Bool {
        !contextNotes.isEmpty || !fileAttachments.isEmpty || !filesTouched.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Context")
                .font(.headline)

            contextWindowRow

            if hasAttachments {
                if !contextNotes.isEmpty {
                    sectionHeader("Context notes", systemImage: "text.quote")
                    ForEach(contextNotes) { note in
                        row(title: note.title, subtitle: note.subtitle, systemImage: "note.text")
                    }
                }
                if !fileAttachments.isEmpty {
                    sectionHeader("Files", systemImage: "paperclip")
                    ForEach(fileAttachments) { file in
                        row(title: file.name, subtitle: byteText(file.size), systemImage: "doc")
                    }
                }
                if !filesTouched.isEmpty {
                    sectionHeader("Files touched this run", systemImage: "pencil")
                    ForEach(filesTouched) { file in
                        row(title: file.fileName, subtitle: file.action.verb, systemImage: "pencil.circle")
                    }
                }
            } else {
                Text("Nothing attached yet. Mention a note with @ or attach a file — and any files the agent touches this run will show up here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rows

    private var contextWindowRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Context window", systemImage: "rectangle.compress.vertical")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("~\(tokenText(chat.estimatedContextTokens)) / \(tokenText(chat.maxContextTokens)) · \(Int((chat.contextUsageFraction * 100).rounded()))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(chat.contextUsageFraction, 0), 1))
                .tint(usageTint)
        }
    }

    private var usageTint: Color {
        switch chat.contextUsageFraction {
        case ..<0.5: .green
        case 0.5..<0.75: .yellow
        default: .orange
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
    }

    private func row(title: String, subtitle: String?, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func tokenText(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
    }

    private func byteText(_ size: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
