#if !EPISTEMOS_APP_STORE
import Foundation

/// One OpenCode chat row, grouped by session directory. The donor's finer
/// worktree level is deferred (honest simplification).
struct ProAgentChatRow: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let directory: String
    let updatedAtSeconds: Double
}

/// Result of an OpenCode all-chats load. `anyFailed` distinguishes a genuine
/// "no chats" from a fetch FAILURE — a silent `[]` on failure would tell the
/// user their chats vanished.
struct ProAgentChatListResult {
    let rows: [ProAgentChatRow]
    let anyFailed: Bool
}

/// Fetches the OpenCode session list straight from the supervised web server via
/// the donor's own /api/experimental/session. No webview involvement — the sheet
/// is native chrome and works even while the SPA streams.
enum ProAgentChatListFetcher {
    static func fetchRows(uiBaseURL: URL) async -> ProAgentChatListResult {
        let opencode = await fetchOpencodeRows(uiBaseURL: uiBaseURL)
        return ProAgentChatListResult(
            rows: (opencode ?? []).sorted { $0.updatedAtSeconds > $1.updatedAtSeconds },
            anyFailed: opencode == nil
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
        return ProAgentChatListDecoder.opencodeRows(from: payload)
    }
}

enum ProAgentChatListDecoder {
    private static let maxIdentifierCharacters = 160
    private static let maxTitleCharacters = 180
    private static let maxDirectoryCharacters = 1_024

    static func opencodeRows(from payload: Any) -> [ProAgentChatRow] {
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
            guard let id = clean(item["id"] as? String, limit: maxIdentifierCharacters) else { return nil }
            let time = item["time"] as? [String: Any]
            let updated = double(time?["updated"]) ?? 0
            return ProAgentChatRow(
                id: id,
                title: clean(item["title"] as? String, limit: maxTitleCharacters) ?? "Untitled",
                directory: clean(item["directory"] as? String, limit: maxDirectoryCharacters) ?? "",
                updatedAtSeconds: updated
            )
        }
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            value
        case let value as Int:
            Double(value)
        default:
            nil
        }
    }

    private static func clean(_ value: String?, limit: Int) -> String? {
        let bounded = String((value ?? "").prefix(limit + 32))
        var output = ""
        output.reserveCapacity(bounded.count)
        var previousWasWhitespace = false
        for scalar in bounded.unicodeScalars where !CharacterSet.controlCharacters.contains(scalar) {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !previousWasWhitespace {
                    output.append(" ")
                    previousWasWhitespace = true
                }
            } else {
                output.unicodeScalars.append(scalar)
                previousWasWhitespace = false
            }
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard limit > 3, trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 3)) + "..."
    }
}
#endif
