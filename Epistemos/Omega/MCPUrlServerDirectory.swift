import Foundation

/// Plan 3 — honest view and MAS-safe writer for external URL MCP servers.
///
/// The read path mirrors `agent_core/src/mcp/url_servers.rs`
/// (`discover_url_mcp_servers`), which is the single source of truth the Rust
/// bridge forwards into the Claude `mcp_servers` API parameter. The write path
/// is intentionally limited to HTTPS URL-server config entries: no stdio
/// subprocesses, no inline token values, and no fake server rows.
///
/// Tokens are never read or displayed — only whether a server declares auth.
nonisolated enum MCPUrlServerDirectory {
    private struct ConfigEntry: Codable {
        let name: String
        let url: String
        let authorization_token: String?
        let authorization_token_env: String?
    }

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

    /// A writable URL MCP server entry. Token values are deliberately absent:
    /// the config writer only persists the environment-variable key that the
    /// Rust side may resolve at runtime.
    struct WritableEntry: Equatable, Identifiable, Sendable {
        let name: String
        let url: String
        let authorizationTokenEnv: String?

        var id: String { name }

        init(name: String, url: String, authorizationTokenEnv: String? = nil) {
            self.name = name
            self.url = url
            self.authorizationTokenEnv = authorizationTokenEnv
        }
    }

    enum WriteError: LocalizedError, Equatable {
        case emptyName
        case notHTTPS(String)
        case secretBearingURLComponentPresent
        case invalidAuthorizationTokenEnv(String)
        case inlineTokenPresent(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "MCP server name cannot be empty."
            case .notHTTPS:
                return "URL MCP servers must use https:// with a valid host and no embedded credentials."
            case .secretBearingURLComponentPresent:
                return "URL MCP servers cannot include query strings or fragments. Put tokens in authorization_token_env instead."
            case .invalidAuthorizationTokenEnv:
                return "Authorization token environment variable must match [A-Za-z_][A-Za-z0-9_]*."
            case .inlineTokenPresent(let name):
                return "Cannot rewrite MCP server config while \(name) stores an inline authorization_token. Move that secret to authorization_token_env first."
            case .writeFailed(let message):
                return "Could not write MCP server config: \(message)"
            }
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
        guard let entries = try? JSONDecoder().decode([ConfigEntry].self, from: data) else {
            return []
        }
        return entries.compactMap { entry in
            // Rust requires https://. Also reject malformed hosts and embedded
            // userinfo so the UI never displays a URL MCP server that smuggles
            // credentials in the URL itself.
            guard let trimmedURL = try? validatedHTTPSURL(entry.url) else { return nil }
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let declaresAuth =
                (entry.authorization_token_env?.isEmpty == false)
                || (entry.authorization_token?.isEmpty == false)
            return ServerInfo(name: name, url: trimmedURL, declaresAuth: declaresAuth)
        }
    }

    /// Load writable entries from a config file. Existing inline token values
    /// are intentionally dropped, so any subsequent write never re-persists a
    /// secret value.
    static func loadWritableEntries(from configURL: URL) -> [WritableEntry] {
        guard let data = try? Data(contentsOf: configURL),
              let entries = try? JSONDecoder().decode([ConfigEntry].self, from: data) else {
            return []
        }
        return entries.compactMap { entry in
            guard let normalized = try? validatedEntry(WritableEntry(
                name: entry.name,
                url: entry.url,
                authorizationTokenEnv: entry.authorization_token_env
            )) else {
                return nil
            }
            return normalized
        }
    }

    /// Write the global/project URL MCP server config as the bare-array JSON
    /// format consumed by Rust. Duplicate names are normalized idempotently:
    /// the last entry wins, and its position is preserved.
    @discardableResult
    static func write(
        _ entries: [WritableEntry],
        to configURL: URL = globalConfigURL(home: FileManager.default.homeDirectoryForCurrentUser),
        fileManager: FileManager = .default
    ) throws -> [ServerInfo] {
        let normalized = try dedupedEntries(entries)
        let payload = normalized.map { entry in
            ConfigEntry(
                name: entry.name,
                url: entry.url,
                authorization_token: nil,
                authorization_token_env: entry.authorizationTokenEnv
            )
        }
        do {
            try fileManager.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.mcpURLServerEncoder.encode(payload)
            try data.write(to: configURL, options: [.atomic])
            return parse(data)
        } catch let error as WriteError {
            throw error
        } catch {
            throw WriteError.writeFailed(error.localizedDescription)
        }
    }

    /// Install or replace one URL MCP server in the target config.
    @discardableResult
    static func install(
        _ entry: WritableEntry,
        to configURL: URL = globalConfigURL(home: FileManager.default.homeDirectoryForCurrentUser),
        fileManager: FileManager = .default
    ) throws -> [ServerInfo] {
        let normalized = try validatedEntry(entry)
        var entries = try loadMutableEntries(from: configURL)
        if let index = entries.firstIndex(where: { $0.name == normalized.name }) {
            entries[index] = normalized
        } else {
            entries.append(normalized)
        }
        return try write(entries, to: configURL, fileManager: fileManager)
    }

    /// Remove a URL MCP server by name from the target config.
    @discardableResult
    static func uninstall(
        name: String,
        from configURL: URL = globalConfigURL(home: FileManager.default.homeDirectoryForCurrentUser),
        fileManager: FileManager = .default
    ) throws -> [ServerInfo] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw WriteError.emptyName }
        let entries = try loadMutableEntries(from: configURL).filter { $0.name != trimmedName }
        return try write(entries, to: configURL, fileManager: fileManager)
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

    private static func dedupedEntries(_ entries: [WritableEntry]) throws -> [WritableEntry] {
        var result: [WritableEntry] = []
        for entry in entries {
            let normalized = try validatedEntry(entry)
            if let index = result.firstIndex(where: { $0.name == normalized.name }) {
                result[index] = normalized
            } else {
                result.append(normalized)
            }
        }
        return result
    }

    private static func loadMutableEntries(from configURL: URL) throws -> [WritableEntry] {
        guard let data = try? Data(contentsOf: configURL),
              let entries = try? JSONDecoder().decode([ConfigEntry].self, from: data) else {
            return []
        }

        return try entries.map { entry in
            if entry.authorization_token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
                throw WriteError.inlineTokenPresent(name.isEmpty ? "<unnamed>" : name)
            }
            return try validatedEntry(WritableEntry(
                name: entry.name,
                url: entry.url,
                authorizationTokenEnv: entry.authorization_token_env
            ))
        }
    }

    private static func validatedEntry(_ entry: WritableEntry) throws -> WritableEntry {
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WriteError.emptyName }

        let url = try validatedHTTPSURL(entry.url)

        let tokenEnv = entry.authorizationTokenEnv?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        if let tokenEnv, !authEnvKeyAllowed(tokenEnv) {
            throw WriteError.invalidAuthorizationTokenEnv(tokenEnv)
        }

        return WritableEntry(name: name, url: url, authorizationTokenEnv: tokenEnv)
    }

    private static func validatedHTTPSURL(_ rawURL: String) throws -> String {
        let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: url),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil else {
            throw WriteError.notHTTPS(url)
        }
        guard components.percentEncodedQuery == nil,
              components.percentEncodedFragment == nil else {
            throw WriteError.secretBearingURLComponentPresent
        }
        return url
    }

    private static func authEnvKeyAllowed(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first,
              isEnvKeyStart(first) else {
            return false
        }
        return key.unicodeScalars.dropFirst().allSatisfy(isEnvKeyContinuation)
    }

    private static func isEnvKeyStart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
    }

    private static func isEnvKeyContinuation(_ scalar: Unicode.Scalar) -> Bool {
        isEnvKeyStart(scalar) || (48...57).contains(Int(scalar.value))
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension JSONEncoder {
    nonisolated static var mcpURLServerEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
