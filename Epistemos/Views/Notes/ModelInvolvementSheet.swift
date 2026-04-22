import SwiftUI
import SwiftData

/// Pass 11 — Per-model "involvement" view.
///
/// Given a `modelID`, shows every substantive `SDMessage` whose
/// `authoredByModelID` matches — i.e. the full contribution history
/// of that specific model across every chat, worker session, and
/// note in this vault. Fulfils the user's
/// "each involvement an AI has should be saved" ask: a permanent
/// memory of everything that model has authored.
///
/// Kept intentionally lightweight: the `@Query` with `#Predicate` is
/// the whole retrieval; no in-memory crawl of chats, no per-row disk
/// scans, no observers. The list shows the most-recent contributions
/// first.
struct ModelInvolvementSheet: View {
    let modelID: String

    @Environment(\.dismiss) private var dismiss
    @Query(
        sort: [SortDescriptor(\SDMessage.createdAt, order: .reverse)]
    )
    private var allMessages: [SDMessage]

    /// Filtered on the Swift side to keep the `@Query` predicate free
    /// of the `modelID` capture (SwiftData `#Predicate` captures string
    /// constants but not view-state at initializer time without some
    /// ceremony). Message counts are small enough that a simple
    /// `filter(_:)` is not a perf concern in a sheet.
    private var contributions: [SDMessage] {
        allMessages.filter { $0.authoredByModelID == modelID }
    }

    private var prettyModelName: String {
        // Reuse the same mapping logic the sidebar entry uses so the
        // sheet title matches the row the user clicked.
        ModelVaultEntry(url: URL(fileURLWithPath: "/tmp/\(modelID)")).displayName
    }

    var body: some View {
        NavigationStack {
            Group {
                if contributions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No contributions yet from \(prettyModelName).")
                            .font(.headline)
                        Text("Turns this model authors will show up here automatically.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(contributions, id: \.id) { message in
                                ModelInvolvementRow(message: message)
                            }
                        } header: {
                            Text("\(contributions.count) contribution\(contributions.count == 1 ? "" : "s")")
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(prettyModelName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 520)
    }
}

private struct ModelInvolvementRow: View {
    let message: SDMessage

    private var chatTitle: String {
        message.chat?.title ?? "Untitled chat"
    }

    private var roleLabel: String {
        switch message.role {
        case "user": return "User"
        case "assistant": return "Assistant"
        case "system": return "System"
        default: return message.role.capitalized
        }
    }

    private var preview: String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 240 { return trimmed }
        return String(trimmed.prefix(240)) + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(chatTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(message.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(preview)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(6)
            HStack(spacing: 6) {
                Text(roleLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                if let provider = message.authoredByProviderID,
                   !provider.isEmpty {
                    Text(provider)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
