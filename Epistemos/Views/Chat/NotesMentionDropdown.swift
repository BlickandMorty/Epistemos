import SwiftUI

// MARK: - Notes Mention Dropdown
// Floating dropdown triggered by @ in ChatInputBar during Notes Mode.
// Shows filtered note titles from the in-memory VaultManifest.

struct NotesMentionDropdown: View {
    let entries: [VaultManifest.ManifestEntry]
    let filter: String
    let onSelect: (VaultManifest.ManifestEntry) -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var filtered: [VaultManifest.ManifestEntry] {
        if filter.isEmpty { return Array(entries.prefix(8)) }
        let q = filter.lowercased()
        return Array(entries.filter { $0.title.lowercased().contains(q) }.prefix(8))
    }

    var body: some View {
        if filtered.isEmpty {
            Text("No matching notes")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
                .padding(8)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filtered) { entry in
                    Button { onSelect(entry) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if let folder = entry.folderName {
                                    Text(folder)
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                Text(entry.updatedAt.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.textTertiary.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
