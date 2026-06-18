import Foundation

/// P7.6 — the cowork CONNECTORS panel's data. Maps the well-known connectors
/// (Slack / Gmail / Google Drive / Notion) onto the URL MCP servers that are
/// ACTUALLY wired for the agent (`MCPUrlServerDirectory.discover`). A connector
/// reads "connected" ONLY when a real wired server matches it — never a fake
/// toggle. Unwired connectors surface the real path to wire one (edit the MCP
/// config), honest about the fact that nothing is connected yet.
///
/// Pure + `nonisolated` so the connector↔server matching is unit-testable
/// without the view. Tokens are never read here — only whether the matched
/// server declares auth (which lives in Keychain/env on the Rust side).
nonisolated enum CoworkConnectorDirectory {
    /// A well-known connector the user is likely to want.
    struct Connector: Equatable, Sendable, Identifiable {
        let id: String
        let displayName: String
        let systemImage: String
        /// Lowercased substrings that, found in a wired server's name or host,
        /// identify it as this connector (e.g. "slack" matches a server named
        /// "Slack" or hosted at mcp.slack.com).
        let matchKeywords: [String]
    }

    /// The connector's live status, derived from the wired server set. Holds
    /// only Sendable primitives (not the MainActor-isolated `ServerInfo`) so the
    /// status itself is a clean `nonisolated` value type.
    struct ConnectorStatus: Equatable, Sendable, Identifiable {
        let connector: Connector
        /// The name of the wired MCP server backing this connector, or nil when
        /// none is configured (the honest "not connected" state).
        let wiredServerName: String?
        /// True when the matched server declares auth (token in Keychain/env).
        let declaresAuth: Bool

        var id: String { connector.id }
        var isConnected: Bool { wiredServerName != nil }
    }

    static let slack = Connector(
        id: "slack", displayName: "Slack", systemImage: "number",
        matchKeywords: ["slack"]
    )
    static let gmail = Connector(
        id: "gmail", displayName: "Gmail", systemImage: "envelope",
        matchKeywords: ["gmail", "google mail", "googlemail"]
    )
    static let googleDrive = Connector(
        id: "drive", displayName: "Google Drive", systemImage: "externaldrive",
        matchKeywords: ["drive", "gdrive", "google-drive"]
    )
    static let notion = Connector(
        id: "notion", displayName: "Notion", systemImage: "doc.text",
        matchKeywords: ["notion"]
    )

    /// The well-known connectors, in display order.
    static let known: [Connector] = [slack, gmail, googleDrive, notion]

    /// Resolve each known connector against the wired servers. A connector is
    /// connected only when a real server's name or host contains one of its
    /// keywords (first match wins). Order follows `known`.
    static func statuses(servers: [MCPUrlServerDirectory.ServerInfo]) -> [ConnectorStatus] {
        known.map { connector in
            let match = servers.first { server in
                // Match on the stored name + url (the url embeds the host); the
                // computed `host` is MainActor-isolated under the module's default
                // isolation, so we use the raw url string here.
                let haystack = (server.name + " " + server.url).lowercased()
                return connector.matchKeywords.contains { haystack.contains($0) }
            }
            return ConnectorStatus(
                connector: connector,
                wiredServerName: match?.name,
                declaresAuth: match?.declaresAuth ?? false
            )
        }
    }

    /// Count of connectors currently backed by a wired server.
    static func connectedCount(servers: [MCPUrlServerDirectory.ServerInfo]) -> Int {
        statuses(servers: servers).filter(\.isConnected).count
    }
}
