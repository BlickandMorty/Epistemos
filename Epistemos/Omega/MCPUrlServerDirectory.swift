import Foundation

/// P2.3 — honest, read-only view of the external (URL) MCP servers that are
/// ACTUALLY wired for the agent. This mirrors `agent_core/src/mcp/url_servers.rs`
/// (`discover_url_mcp_servers`), which is the single source of truth the Rust
/// bridge forwards into the Claude `mcp_servers` API parameter — so what this
/// surfaces is exactly what the live agent can reach, never a fake server row.
///
/// We deliberately do NOT expose an add/enable/disable mutation here: servers are
/// configured by editing the JSON files below (and stdio/subprocess MCP servers
/// are Pro-only and MAS-forbidden). Surfacing the wired set read-only is the
/// honest first step; a Pro config-file editor is a separate, gated follow-up.
///
/// Tokens are never read or displayed — only whether a server declares auth.
enum MCPUrlServerDirectory {
    /// One configured URL MCP server, projected for honest display.
    struct ServerInfo: Equatable, Identifiable, Sendable {
        let name: String
        let url: String
        /// True when the entry declares auth (an env-var key or an inline token).
        /// The token value itself is never surfaced.
        let declaresAuth: Bool

        var id: String { name }

        /// Host shown in the UI (never the full URL with any query/secrets).
        var host: String {
            URLComponents(string: url)?.host ?? url
        }
    }

    /// Config locations, mirroring the Rust discovery order (project wins over
    /// global). Injectable for tests.
    static func projectConfigURL(cwd: URL) -> URL {
        cwd.appendingPathComponent(".epistemos").appendingPathComponent("mcp_url_servers.json")
    }

    static func globalConfigURL(home: URL) -> URL {
        home.appendingPathComponent(".config")
            .appendingPathComponent("mcp")
            .appendingPathComponent("url_servers.json")
    }

    /// Parse a single config file's JSON (a bare array of entries) into the
    /// validated, display-projected servers. Pure — no filesystem — so the
    /// format contract with the Rust side is unit-testable. Invalid entries
    /// (non-https url, missing fields) are dropped, matching `entry_to_config`.
    static func parse(_ data: Data) -> [ServerInfo] {
        struct Entry: Decodable {
            let name: String
            let url: String
            let authorization_token: String?
            let authorization_token_env: String?
        }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return entries.compactMap { entry in
            let trimmedURL = entry.url.trimmingCharacters(in: .whitespacesAndNewlines)
            // Rust requires https:// — match it so we never show a server the
            // agent would reject.
            guard trimmedURL.hasPrefix("https://") else { return nil }
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let declaresAuth =
                (entry.authorization_token_env?.isEmpty == false)
                || (entry.authorization_token?.isEmpty == false)
            return ServerInfo(name: name, url: trimmedURL, declaresAuth: declaresAuth)
        }
    }

    /// The wired URL MCP servers, project file appended over global, deduped by
    /// name (project wins) — exactly the Rust dedupe order. Returns an empty list
    /// when the files are absent or unreadable (e.g. the MAS sandbox can't reach
    /// `~/.config`), which is the honest "none wired" state.
    static func discover(
        fileManager: FileManager = .default,
        cwd: URL? = nil,
        home: URL? = nil
    ) -> [ServerInfo] {
        let projectCWD = cwd ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let homeDir = home ?? fileManager.homeDirectoryForCurrentUser
        let paths = [projectConfigURL(cwd: projectCWD), globalConfigURL(home: homeDir)]

        var seen: Set<String> = []
        var result: [ServerInfo] = []
        for path in paths {
            guard let data = try? Data(contentsOf: path) else { continue }
            for server in parse(data) where seen.insert(server.name).inserted {
                result.append(server)
            }
        }
        return result
    }
}
