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

enum ComposerReferenceHelpers {
    static func mentionFilter(in text: String) -> String? {
        guard let atIndex = text.lastIndex(of: "@") else { return nil }
        let suffix = text[text.index(after: atIndex)...]
        guard !suffix.contains("]"),
              !suffix.contains(where: \.isWhitespace) else { return nil }
        return String(suffix)
    }

    static func removingTrailingMention(from text: String) -> String {
        guard let atIndex = text.lastIndex(of: "@") else { return text }
        return String(text[..<atIndex])
    }

    static var allNotesAttachment: ContextAttachment {
        ContextAttachment(
            kind: .allNotes,
            targetId: ChatCoordinator.allNotesMentionToken,
            title: "All Notes",
            subtitle: "Vault"
        )
    }

    static func contextAttachment(for choice: ComposerReferenceChoice) -> ContextAttachment {
        switch choice {
        case .note(let noteChoice):
            switch noteChoice {
            case .allNotes:
                allNotesAttachment
            case .entry(let entry):
                ContextAttachment(
                    kind: .note,
                    targetId: entry.pageId,
                    title: entry.title,
                    subtitle: entry.folderName
                )
            }
        case .chat(let result):
            result.attachment
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

struct ComposerContextShortcutBar: View {
    let noteLabel: String
    let vaultLabel: String
    let onChatWithNote: () -> Void
    let onChatWithVault: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 8) {
            actionButton(
                title: noteLabel,
                icon: "doc.text.magnifyingglass",
                action: onChatWithNote
            )
            actionButton(
                title: vaultLabel,
                icon: "books.vertical",
                action: onChatWithVault
            )
            Spacer(minLength: 0)
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .assistantInsetChrome(theme: theme, cornerRadius: 15)
    }
}

struct ComposerReferencePopover: View {
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void
    let idealWidth: CGFloat
    let maxHeight: CGFloat

    init(
        results: ChatCoordinator.ReferenceSearchResults,
        idealWidth: CGFloat = 320,
        maxHeight: CGFloat = 300,
        onSelect: @escaping (ComposerReferenceChoice) -> Void
    ) {
        self.results = results
        self.onSelect = onSelect
        self.idealWidth = idealWidth
        self.maxHeight = maxHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(idealWidth, max(220, proxy.size.width - 12))

            ScrollView(.vertical, showsIndicators: false) {
                NotesMentionDropdown(
                    results: results,
                    onSelect: onSelect
                )
                .padding(.vertical, 6)
            }
            .frame(width: width, alignment: .topLeading)
            .frame(maxHeight: maxHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.14), radius: 12, y: -2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(y: -8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight + 12, alignment: .topLeading)
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
