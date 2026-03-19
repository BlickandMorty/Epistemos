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
    private static func isMentionTriggerBoundary(_ character: Character) -> Bool {
        !(character.isLetter || character.isNumber || character == "_" || character == "." || character == "-")
    }

    private static func activeMentionRange(in text: String) -> Range<String.Index>? {
        guard let atIndex = text.lastIndex(of: "@") else { return nil }
        if atIndex > text.startIndex {
            let previous = text[text.index(before: atIndex)]
            guard isMentionTriggerBoundary(previous) else { return nil }
        }

        let suffixStart = text.index(after: atIndex)
        let suffix = text[suffixStart...]
        guard !suffix.contains("]"),
              !suffix.contains("\n"),
              !suffix.contains("\r") else { return nil }
        return atIndex..<text.endIndex
    }

    static func mentionFilter(in text: String) -> String? {
        guard let range = activeMentionRange(in: text) else { return nil }
        return String(text[range].dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removingTrailingMention(from text: String) -> String {
        guard let range = activeMentionRange(in: text) else { return text }
        return String(text[..<range.lowerBound])
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

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    init(
        results: ChatCoordinator.ReferenceSearchResults,
        idealWidth: CGFloat = 380,
        maxHeight: CGFloat = 340,
        onSelect: @escaping (ComposerReferenceChoice) -> Void
    ) {
        self.results = results
        self.onSelect = onSelect
        self.idealWidth = idealWidth
        self.maxHeight = maxHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(idealWidth, max(260, proxy.size.width - 8))

            VStack(alignment: .leading, spacing: 0) {
                popoverHeader
                Divider()
                    .overlay(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.28))

                ScrollView(.vertical, showsIndicators: false) {
                    NotesMentionDropdown(
                        results: results,
                        onSelect: onSelect
                    )
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: maxHeight - 62, alignment: .topLeading)

                if results.vaultNoteCount > 0 {
                    Divider()
                        .overlay(theme.glassBorder.opacity(theme.isDark ? 0.4 : 0.24))
                    footerHint
                }
            }
            .frame(width: width, alignment: .topLeading)
            .frame(maxHeight: maxHeight, alignment: .topLeading)
            .assistantPopoverChrome(theme: theme)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(y: -8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight + 12, alignment: .topLeading)
    }

    private var popoverHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: results.query.isEmpty ? "books.vertical.fill" : "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent.opacity(0.92))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(results.query.isEmpty ? "Browse Note Context" : "Search Notes and Chats")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(popoverSubtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var popoverSubtitle: String {
        if results.query.isEmpty {
            return "Attach a note, search your vault, or bring the whole index into this turn."
        }
        return "Searching titles, folders, tags, and snippets for “\(results.query)”."
    }

    private var footerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text("Rich matches come from your vault inventory and recent note excerpts.")
                .font(.system(size: 10.5))
                .foregroundStyle(theme.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if results.vaultNoteCount > 0 {
                    vaultSummaryHeader
                }

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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No matching notes or chats", systemImage: "sparkle.magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.foreground)
            Text(results.vaultNoteCount > 0
                 ? "Search checks note titles, folders, tags, and snippets across your vault."
                 : "Attach a vault to browse notes here, or keep typing to search chats.")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vaultSummaryHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(results.vaultTitle ?? "Vault")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(vaultSummaryText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if !results.isInventoryComplete {
                Text("Partial")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.foreground.opacity(0.06)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var vaultSummaryText: String {
        if results.query.isEmpty {
            return "Browse \(results.vaultNoteCount) notes or attach the whole vault as context."
        }
        return "Matching across titles, folders, tags, and snippets in \(results.vaultNoteCount) notes."
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textTertiary.opacity(0.75))
            .tracking(0.5)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func noteRow(_ choice: NoteMentionChoice) -> some View {
        switch choice {
        case .allNotes:
            rowChrome {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.accent.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.12)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("All Notes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(1)
                        Text("Use the full vault index for this message.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(theme.textTertiary)
                        if results.vaultNoteCount > 0 {
                            Text("\(results.vaultNoteCount) notes")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.foreground.opacity(0.06)))
                        }
                    }
                }
            }

        case .entry(let entry):
            rowChrome {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let folder = entry.folderName, !folder.isEmpty {
                            Label(folder, systemImage: "folder")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                        Text(entry.updatedAt.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary.opacity(0.7))
                    }

                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(theme.textSecondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(theme.foreground.opacity(0.06)))
                            }
                        }
                    }

                    if !entry.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.snippet)
                            .font(.system(size: 10.5))
                            .foregroundStyle(theme.textTertiary.opacity(0.88))
                            .lineLimit(results.query.isEmpty ? 1 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func chatRow(_ result: ChatCoordinator.ChatReferenceResult) -> some View {
        rowChrome {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.attachment.title)
                    .font(.system(size: 12, weight: .semibold))
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
        }
    }

    private func rowChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.foreground.opacity(theme.isDark ? 0.08 : 0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.32 : 0.20), lineWidth: 0.75)
                    }
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
