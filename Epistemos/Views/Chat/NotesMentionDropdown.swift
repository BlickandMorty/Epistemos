import SwiftUI

enum NoteMentionChoice: Identifiable {
    case allNotes
    case entry(VaultManifest.ManifestEntry)

    var id: String {
        switch self {
        case .allNotes: "all-notes"
        case .entry(let entry): entry.pageId
        }
    }
}

enum ComposerReferenceChoice: Identifiable {
    case note(NoteMentionChoice)
    case chat(ChatCoordinator.ChatReferenceResult)

    var id: String {
        switch self {
        case .note(let note):
            "note:\(note.id)"
        case .chat(let chat):
            "chat:\(chat.id)"
        }
    }
}

// MARK: - Notes Mention Dropdown
// Floating dropdown triggered by @ in ChatInputBar during Notes Mode.
// Shows filtered note titles from the in-memory VaultManifest.

struct NotesMentionDropdown: View {
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        if results.notes.isEmpty && results.chats.isEmpty {
            Text("No matching notes")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
                .padding(8)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !results.notes.isEmpty {
                    sectionHeader("Notes")
                    ForEach(results.notes) { choice in
                        Button { onSelect(.note(choice)) } label: {
                            noteRow(choice)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !results.chats.isEmpty {
                    if !results.notes.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    sectionHeader("Chats")
                    ForEach(results.chats) { result in
                        Button { onSelect(.chat(result)) } label: {
                            chatRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textTertiary.opacity(0.75))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func noteRow(_ choice: NoteMentionChoice) -> some View {
        switch choice {
        case .allNotes:
            VStack(alignment: .leading, spacing: 2) {
                Text("All Notes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                Text("Use the full vault index for this message")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())

        case .entry(let entry):
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let folder = entry.folderName {
                        Text(folder)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(entry.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private func chatRow(_ result: ChatCoordinator.ChatReferenceResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.attachment.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
            HStack(spacing: 6) {
                if let subtitle = result.attachment.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                if let preview = result.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
