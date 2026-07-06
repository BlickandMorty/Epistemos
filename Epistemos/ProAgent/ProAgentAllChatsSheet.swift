#if !EPISTEMOS_APP_STORE
import SwiftUI

extension Notification.Name {
    /// Pill -> surface: present the native all-chats sheet (owner signature).
    static let epistemosProAgentAllChats = Notification.Name("EpistemosProAgentAllChats")
}

/// The native all-chats sheet (owner signature): OpenCode sessions grouped by
/// directory. Selecting a row posts the selectSession chrome intent — the SPA
/// switches sessions client-side; the URL is never reloaded (§13.5).
struct ProAgentAllChatsSheet: View {
    let theme: EpistemosTheme
    let uiBaseURL: URL?
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    @State private var rows: [ProAgentChatRow] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    private var groupedRows: [(directory: String, rows: [ProAgentChatRow])] {
        let groups = Dictionary(grouping: rows) { $0.directory }
        return groups
            .map { (directory: $0.key, rows: $0.value.sorted { $0.updatedAtSeconds > $1.updatedAtSeconds }) }
            .sorted { lhs, rhs in
                (lhs.rows.first?.updatedAtSeconds ?? 0) > (rhs.rows.first?.updatedAtSeconds ?? 0)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All Chats")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textPrimary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().opacity(0.4)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty && loadFailed {
                // A fetch FAILED (not a genuine empty) — say so + offer retry,
                // rather than telling the user they have no chats.
                VStack(spacing: 10) {
                    Text("Couldn't load chats.")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textPrimary.opacity(0.7))
                    Button("Retry") { Task { await reload() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                Text("No chats yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textPrimary.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2, pinnedViews: []) {
                        ForEach(groupedRows, id: \.directory) { group in
                            Text(group.directory.isEmpty ? "No project" : displayName(for: group.directory))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.textPrimary.opacity(0.45))
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                                .padding(.bottom, 2)
                            ForEach(group.rows) { row in
                                rowView(row)
                            }
                        }
                    }
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(width: 420, height: 480)
        .task { await reload() }
    }

    private func rowView(_ row: ProAgentChatRow) -> some View {
        Button {
            onSelect(row.id)
        } label: {
            HStack(spacing: 8) {
                Text(row.title)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textPrimary.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }

    private func displayName(for directory: String) -> String {
        URL(fileURLWithPath: directory).lastPathComponent
    }

    private func reload() async {
        guard let uiBaseURL else {
            isLoading = false
            return
        }
        isLoading = true
        let result = await ProAgentChatListFetcher.fetchRows(uiBaseURL: uiBaseURL)
        rows = result.rows
        loadFailed = result.anyFailed
        isLoading = false
    }
}
#endif
