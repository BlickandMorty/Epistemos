#if !EPISTEMOS_APP_STORE
import SwiftUI

extension Notification.Name {
    /// Pill -> surface: present the native all-chats sheet (owner signature).
    static let epistemosProAgentAllChats = Notification.Name("EpistemosProAgentAllChats")
}

/// One merged row (§0.3): both engines, engine-badged, grouped by directory.
/// goose rows carry directory grouping only — no branch/worktree (capability
/// truth §0.6). v1 grouping note: opencode rows group by session directory;
/// the donor's finer worktree level is deferred (honest simplification).
struct ProAgentChatRow: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let directory: String
    let updatedAtSeconds: Double
    let engine: String // "opencode" | "goose"
}

/// Fetches the merged session list straight from the supervised web server:
/// opencode via the donor's own /api/experimental/session, goose via the
/// adapter's durable /goose-index. No webview involvement — the sheet is
/// native chrome and works even while the SPA streams.
/// Result of a merged all-chats load. `anyFailed` distinguishes a genuine
/// "no chats" (both sources returned empty) from a fetch FAILURE (a transient
/// web-server/goose blip) — a silent `[]` on failure would tell the user their
/// chats vanished (CLAUDE.md: "distinguish fetch failure from empty success").
struct ProAgentChatListResult {
    let rows: [ProAgentChatRow]
    let anyFailed: Bool
}

enum ProAgentChatListFetcher {
    static func fetchMergedRows(uiBaseURL: URL) async -> ProAgentChatListResult {
        async let opencodeRows = fetchOpencodeRows(uiBaseURL: uiBaseURL)
        async let gooseRows = fetchGooseRows(uiBaseURL: uiBaseURL)
        let opencode = await opencodeRows
        let goose = await gooseRows
        // nil = the fetch FAILED (network/non-200/parse). An opencode-only run
        // returns goose == [] (404 => not configured), which is NOT a failure.
        let merged = (opencode ?? []) + (goose ?? [])
        return ProAgentChatListResult(
            rows: merged.sorted { $0.updatedAtSeconds > $1.updatedAtSeconds },
            anyFailed: opencode == nil || goose == nil
        )
    }

    /// nil = fetch failed (surface an error); [] = loaded, genuinely empty.
    private static func fetchOpencodeRows(uiBaseURL: URL) async -> [ProAgentChatRow]? {
        var components = URLComponents(
            url: uiBaseURL.appendingPathComponent("api/experimental/session"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "archived", value: "false"),
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        // nil on any transport/status/parse failure — do NOT masquerade a
        // failed fetch as an empty session list.
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) else { return nil }
        // The endpoint answers either a bare array or {sessions:[...]}-ish
        // envelopes depending on version; accept both shapes tolerantly.
        let items: [[String: Any]]
        if let array = payload as? [[String: Any]] {
            items = array
        } else if let object = payload as? [String: Any],
                  let array = (object["sessions"] ?? object["data"]) as? [[String: Any]] {
            items = array
        } else {
            items = []
        }
        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let engine = (item["version"] as? String) == "goose" ? "goose" : "opencode"
            let time = item["time"] as? [String: Any]
            let updated = (time?["updated"] as? Double) ?? (time?["updated"] as? Int).map(Double.init) ?? 0
            return ProAgentChatRow(
                id: id,
                title: (item["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled",
                directory: (item["directory"] as? String) ?? "",
                updatedAtSeconds: updated,
                engine: engine
            )
        }
    }

    /// nil = fetch failed; [] = loaded empty OR goose not configured (404).
    private static func fetchGooseRows(uiBaseURL: URL) async -> [ProAgentChatRow]? {
        var request = URLRequest(url: uiBaseURL.appendingPathComponent("goose-index"))
        request.timeoutInterval = 4
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        // 404 => the goose proxy isn't registered (opencode-only run): a valid
        // empty, NOT a failure. Any other non-200 or a parse error IS a failure.
        if http.statusCode == 404 { return [] }
        guard http.statusCode == 200,
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let updatedMs = (item["updatedAt"] as? Double) ?? (item["updatedAt"] as? Int).map(Double.init) ?? 0
            return ProAgentChatRow(
                id: id,
                title: (item["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "goose session",
                directory: (item["workingDir"] as? String) ?? "",
                updatedAtSeconds: updatedMs / 1000,
                engine: "goose"
            )
        }
    }
}

/// The native all-chats sheet (owner signature): merged, engine-badged,
/// directory-grouped. Selecting a row posts the selectSession chrome intent —
/// the SPA switches sessions client-side; the URL is never reloaded (§13.5).
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
                if row.engine == "goose" {
                    Text("goose")
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel("goose engine")
                }
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
        let result = await ProAgentChatListFetcher.fetchMergedRows(uiBaseURL: uiBaseURL)
        rows = result.rows
        loadFailed = result.anyFailed
        isLoading = false
    }
}
#endif
