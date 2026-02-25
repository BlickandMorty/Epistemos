import SwiftData
import SwiftUI

/// Panel showing pages with unsaved vault changes (dirty pages).
/// Toggleable from the notes toolbar.
struct VaultChangesPanel: View {
    let allPages: [SDPage]

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync

    private var theme: EpistemosTheme { ui.theme }

    private var dirtyPages: [SDPage] {
        allPages.filter(\.isDirtyVault)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Unsaved Changes")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !dirtyPages.isEmpty {
                    Button("Save All") {
                        vaultSync.saveAllDirtyPages()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if dirtyPages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.success)
                    Text("All notes saved to vault")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(dirtyPages, id: \.id) { page in
                            DirtyPageRow(page: page)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct DirtyPageRow: View {
    let page: SDPage

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)

                if let lastSaved = page.lastSyncedAt {
                    Text("Last saved \(lastSaved, format: .relative(presentation: .named))")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("Never saved to vault")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.warning)
                }
            }

            Spacer()

            Button {
                vaultSync.savePage(pageId: page.id)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Save to vault")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
