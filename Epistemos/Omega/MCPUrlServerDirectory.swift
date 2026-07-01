import Darwin
import Foundation

/// Plan 3 — honest view and MAS-safe writer for external URL MCP servers.
///
/// The read path mirrors `agent_core/src/mcp/url_servers.rs`
/// (`discover_url_mcp_servers`), which is the single source of truth the Rust
/// bridge forwards into the Claude `mcp_servers` API parameter. The write path
/// is intentionally limited to HTTPS URL-server config entries: no stdio
/// subprocesses, no inline token values, and no fake server rows.
///
/// Token values are never read or displayed — only valid env-key auth is surfaced.
nonisolated enum MCPUrlServerDirectory {
    static let maxConfigBytes = 256 * 1024

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
        /// True when the entry declares auth through a valid env-var key.
        /// Inline token values are not treated as active runtime servers.
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
                return MCPUrlServerDirectory.Diagnostics.failureReason(
                    "Cannot rewrite MCP server config while \(name) stores an inline authorization_token. Move that secret to authorization_token_env first.",
                    fallback: "Cannot rewrite MCP server config while an entry stores an inline authorization_token."
                )
            case .writeFailed(let message):
                return MCPUrlServerDirectory.Diagnostics.failureReason(
                    "Could not write MCP server config: \(message)",
                    fallback: "Could not write MCP server config."
                )
            }
        }
    }

    enum Diagnostics {
        static let maxFailureReasonCharacters = 360
        private static let maxDomainCharacters = 96
        private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

        static func externalErrorDescription(_ error: Error, fallback: String) -> String {
            let nsError = error as NSError
            let domain = safeDomain(nsError.domain)
            return failureReason("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
        }

        static func failureReason(_ message: String, fallback: String) -> String {
            let bounded = String(message.prefix(maxFailureReasonCharacters + 32))
            let trimmed = normalizedDisplayText(bounded).trimmingCharacters(in: .whitespacesAndNewlines)
            let description = trimmed.isEmpty ? fallback : trimmed
            guard description.count > maxFailureReasonCharacters else {
                return description
            }
            return String(description.prefix(maxFailureReasonCharacters - 3)) + "..."
        }

        static func safeDomain(_ domain: String) -> String {
            let bounded = String(domain.prefix(maxDomainCharacters + 32))
            let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
            let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
            guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
                return "Error"
            }
            let value = trimmed.isEmpty ? "Error" : trimmed
            guard value.unicodeScalars.allSatisfy({ scalar in
                CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
            }) else {
                return "Error"
            }
            let safeDomain = String(value.prefix(maxDomainCharacters))
            return safeDomain.isEmpty ? "Error" : safeDomain
        }

        static func normalizedDisplayText(_ value: String) -> String {
            var normalized = ""
            normalized.reserveCapacity(value.count)
            var previousWasSeparator = false
            for scalar in value.unicodeScalars {
                let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                    || CharacterSet.controlCharacters.contains(scalar)
                if isSeparator {
                    if !previousWasSeparator {
                        normalized.append(" ")
                        previousWasSeparator = true
                    }
                } else {
                    normalized.unicodeScalars.append(scalar)
                    previousWasSeparator = false
                }
            }
            return normalized
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
        guard data.count <= maxConfigBytes else {
            return []
        }
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
            guard entry.authorization_token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
                return nil
            }
            let tokenEnv = entry.authorization_token_env?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            if let tokenEnv, !authEnvKeyAllowed(tokenEnv) {
                return nil
            }
            let declaresAuth = tokenEnv != nil
            return ServerInfo(name: name, url: trimmedURL, declaresAuth: declaresAuth)
        }
    }

    /// Load writable entries from a config file. Entries with inline token
    /// values are skipped so callers do not treat hidden legacy secrets as
    /// active writable runtime entries.
    static func loadWritableEntries(
        from configURL: URL,
        fileManager: FileManager = .default
    ) -> [WritableEntry] {
        guard let data = try? loadConfigData(from: configURL, fileManager: fileManager),
              let entries = try? JSONDecoder().decode([ConfigEntry].self, from: data) else {
            return []
        }
        return entries.compactMap { entry in
            guard entry.authorization_token?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
                return nil
            }
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
            let configDirectory = configURL.deletingLastPathComponent()
            try rejectConfigPathSymlinkComponents(configDirectory, fileManager: fileManager)
            try fileManager.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true
            )
            try rejectConfigPathSymlinkComponents(configDirectory, fileManager: fileManager)
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: configDirectory.path
            )
            let data = try JSONEncoder.mcpURLServerEncoder.encode(payload)
            guard data.count <= maxConfigBytes else {
                throw WriteError.writeFailed("encoded config exceeds \(maxConfigBytes) bytes")
            }
            try validateWritableConfigTarget(configURL, fileManager: fileManager)
            try writeConfigDataNoFollow(data, to: configURL)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
            return parse(data)
        } catch let error as WriteError {
            throw error
        } catch {
            throw WriteError.writeFailed(
                Diagnostics.externalErrorDescription(error, fallback: "filesystem error")
            )
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
        var entries = try loadMutableEntries(from: configURL, fileManager: fileManager)
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
        let entries = try loadMutableEntries(from: configURL, fileManager: fileManager).filter { $0.name != trimmedName }
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
            guard let data = try? loadConfigData(from: path, fileManager: fileManager) else { continue }
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

    private static func loadMutableEntries(
        from configURL: URL,
        fileManager: FileManager = .default
    ) throws -> [WritableEntry] {
        guard let data = try loadConfigData(from: configURL, fileManager: fileManager) else {
            return []
        }
        guard let entries = try? JSONDecoder().decode([ConfigEntry].self, from: data) else {
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

    private static func loadConfigData(
        from configURL: URL,
        fileManager: FileManager = .default
    ) throws -> Data? {
        try rejectConfigPathSymlinkComponents(configURL.deletingLastPathComponent(), fileManager: fileManager)
        if (try? fileManager.destinationOfSymbolicLink(atPath: configURL.path)) != nil {
            throw WriteError.writeFailed("existing config file is a symbolic link")
        }
        guard fileManager.fileExists(atPath: configURL.path) else {
            return nil
        }
        try validateReadableConfigFile(configURL, fileManager: fileManager)
        guard let data = try readConfigDataNoFollow(from: configURL) else {
            return nil
        }
        guard data.count <= maxConfigBytes else {
            throw WriteError.writeFailed("existing config file exceeds \(maxConfigBytes) bytes")
        }
        return data
    }

    private static func readConfigDataNoFollow(from configURL: URL) throws -> Data? {
        let fd = configURL.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            let capturedErrno = errno
            if capturedErrno == ENOENT {
                return nil
            }
            if capturedErrno == ELOOP {
                throw WriteError.writeFailed("existing config file is a symbolic link")
            }
            throw WriteError.writeFailed("existing config file could not be opened safely")
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw WriteError.writeFailed("existing config file attributes are unavailable")
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw WriteError.writeFailed("existing config file is not a regular file")
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxConfigBytes) else {
            close(fd)
            throw WriteError.writeFailed("existing config file exceeds \(maxConfigBytes) bytes")
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= maxConfigBytes else {
            throw WriteError.writeFailed("existing config file exceeds \(maxConfigBytes) bytes")
        }
        return data
    }

    private static func writeConfigDataNoFollow(_ data: Data, to configURL: URL) throws {
        let fd = configURL.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fd >= 0 else {
            if errno == ELOOP {
                throw WriteError.writeFailed("existing config file is a symbolic link")
            }
            throw WriteError.writeFailed("config file could not be opened safely")
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw WriteError.writeFailed("config file attributes are unavailable")
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw WriteError.writeFailed("config file is not a regular file")
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw WriteError.writeFailed(
                Diagnostics.externalErrorDescription(error, fallback: "filesystem error")
            )
        }
    }

    private static func validateReadableConfigFile(
        _ configURL: URL,
        fileManager: FileManager
    ) throws {
        if (try? fileManager.destinationOfSymbolicLink(atPath: configURL.path)) != nil {
            throw WriteError.writeFailed("existing config file is a symbolic link")
        }

        var fileStatus = stat()
        guard lstat(configURL.path, &fileStatus) == 0 else {
            throw WriteError.writeFailed("existing config file attributes are unavailable")
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            throw WriteError.writeFailed("existing config file is not a regular file")
        }
        guard fileStatus.st_nlink <= 1 else {
            throw WriteError.writeFailed("existing config file has multiple hard links")
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxConfigBytes) else {
            throw WriteError.writeFailed("existing config file exceeds \(maxConfigBytes) bytes")
        }
    }

    private static func validateWritableConfigTarget(
        _ configURL: URL,
        fileManager: FileManager
    ) throws {
        try rejectConfigPathSymlinkComponents(configURL.deletingLastPathComponent(), fileManager: fileManager)
        guard fileManager.fileExists(atPath: configURL.path) else {
            if (try? fileManager.destinationOfSymbolicLink(atPath: configURL.path)) != nil {
                throw WriteError.writeFailed("existing config file is a symbolic link")
            }
            return
        }
        try validateReadableConfigFile(configURL, fileManager: fileManager)
    }

    private static func rejectConfigPathSymlinkComponents(
        _ url: URL,
        fileManager: FileManager
    ) throws {
        if let component = try firstExistingSymlinkComponent(in: url, fileManager: fileManager) {
            throw WriteError.writeFailed(
                "config path must not include symbolic link component \(component.lastPathComponent)"
            )
        }
    }

    private static func firstExistingSymlinkComponent(
        in url: URL,
        fileManager: FileManager
    ) throws -> URL? {
        let standardized = url.standardizedFileURL
        let path = standardized.path
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        var current = path.hasPrefix("/")
            ? URL(fileURLWithPath: "/", isDirectory: true)
            : URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        for component in components {
            current = current.appendingPathComponent(String(component), isDirectory: false)
            var fileStatus = stat()
            guard lstat(current.path, &fileStatus) == 0 else {
                if errno == ENOENT || errno == ENOTDIR {
                    return nil
                }
                throw WriteError.writeFailed("config path could not be inspected safely")
            }
            if (fileStatus.st_mode & S_IFMT) == S_IFLNK,
               !isAllowedSystemSymlinkComponent(current, fileStatus: fileStatus) {
                return current
            }
        }
        return nil
    }

    private static func isAllowedSystemSymlinkComponent(_ url: URL, fileStatus: stat) -> Bool {
        url.deletingLastPathComponent().path == "/" && fileStatus.st_uid == 0
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
