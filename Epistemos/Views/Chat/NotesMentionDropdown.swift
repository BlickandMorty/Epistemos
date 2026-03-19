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

// MARK: - Notes Mention Dropdown
// Floating dropdown triggered by @ in ChatInputBar during Notes Mode.
// Shows filtered note titles from the in-memory VaultManifest.

struct NotesMentionDropdown: View {
    let entries: [VaultManifest.ManifestEntry]
    let filter: String
    let onSelect: (NoteMentionChoice) -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var filtered: [NoteMentionChoice] {
        var results: [NoteMentionChoice] = []
        let normalizedFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedFilter.isEmpty || "all notes".contains(normalizedFilter) || "all".contains(normalizedFilter) {
            results.append(.allNotes)
        }

        if filter.isEmpty {
            results.append(contentsOf: entries.prefix(8).map(NoteMentionChoice.entry))
            return results
        }

        let q = filter.lowercased()
        results.append(contentsOf: entries.filter { $0.title.lowercased().contains(q) }.prefix(8).map(NoteMentionChoice.entry))
        return results
    }

    var body: some View {
        if filtered.isEmpty {
            Text("No matching notes")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
                .padding(8)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filtered) { choice in
                    Button { onSelect(choice) } label: {
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
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
