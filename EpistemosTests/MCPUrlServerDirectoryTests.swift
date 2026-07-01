import Testing
import Foundation
@testable import Epistemos

/// P2.3 — locks the URL MCP server config parser against the Rust source of
/// truth (`agent_core/src/mcp/url_servers.rs`). What the chat surfaces must be
/// exactly the servers the Rust bridge forwards: https-only, name+url required,
/// auth declared only when a valid env field is present (never an inline token value),
/// and an empty list when nothing is configured.
@Suite("MCP URL server directory")
struct MCPUrlServerDirectoryTests {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test("parses a valid https server and projects host + auth flag")
    func parsesValidServer() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [
          { "name": "linear", "url": "https://mcp.linear.app/sse", "authorization_token_env": "LINEAR_MCP_TOKEN" }
        ]
        """))
        #expect(servers.count == 1)
        let s = servers[0]
        #expect(s.name == "linear")
        #expect(s.url == "https://mcp.linear.app/sse")
        #expect(s.host == "mcp.linear.app")
        #expect(s.declaresAuth)
    }

    @Test("drops non-https and nameless entries (matches Rust entry_to_config)")
    func dropsInvalidEntries() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [
          { "name": "insecure", "url": "http://example.com/mcp" },
          { "name": "missing-host", "url": "https:///mcp" },
          { "name": "userinfo", "url": "https://token@example.com/mcp" },
          { "name": "", "url": "https://example.com/mcp" },
          { "name": "ok", "url": "https://good.example.com/mcp" }
        ]
        """))
        #expect(servers.map(\.name) == ["ok"])
    }

    @Test("drops URL servers with query strings or fragments")
    func dropsSecretBearingURLComponents() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [
          { "name": "query", "url": "https://example.com/mcp?token=abc123" },
          { "name": "fragment", "url": "https://example.com/mcp#token=abc123" },
          { "name": "ok", "url": "https://good.example.com/mcp" }
        ]
        """))
        #expect(servers.map(\.name) == ["ok"])
    }

    @Test("a server with no auth fields declares no auth")
    func noAuthDeclared() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [ { "name": "open", "url": "https://open.example.com/mcp" } ]
        """))
        #expect(servers.count == 1)
        #expect(!servers[0].declaresAuth)
    }

    @Test("inline authorization_token entries are hidden from the forwarded runtime surface")
    func inlineTokenEntriesAreHiddenFromRuntimeSurface() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [ { "name": "inline", "url": "https://t.example.com/mcp", "authorization_token": "secret" } ]
        """))
        #expect(servers.isEmpty)
    }

    @Test("invalid authorization_token_env keys are hidden from the forwarded runtime surface")
    func invalidAuthorizationTokenEnvKeysAreHiddenFromRuntimeSurface() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [ { "name": "open", "url": "https://open.example.com/mcp", "authorization_token_env": "TOKEN-NAME" } ]
        """))
        #expect(servers.isEmpty)
    }

    @Test("malformed / empty JSON yields no servers (honest empty state, never a crash)")
    func malformedYieldsEmpty() {
        #expect(MCPUrlServerDirectory.parse(data("not json")).isEmpty)
        #expect(MCPUrlServerDirectory.parse(data("[]")).isEmpty)
        #expect(MCPUrlServerDirectory.parse(Data()).isEmpty)
    }

    @Test("parser rejects oversized config bodies before decode")
    func parserRejectsOversizedConfigBodies() {
        let json = """
        [
          {
            "name": "oversized",
            "url": "https://oversized.example.com/mcp",
            "authorization_token_env": "\(String(repeating: "A", count: MCPUrlServerDirectory.maxConfigBytes))"
          }
        ]
        """
        let body = data(json)

        #expect(body.count > MCPUrlServerDirectory.maxConfigBytes)
        #expect(MCPUrlServerDirectory.parse(body).isEmpty)
    }

    @Test("discover dedupes by name with the project file winning over global")
    func discoverProjectWinsOverGlobal() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("mcp-dir-test-\(UUID().uuidString)")
        let cwd = root.appendingPathComponent("project")
        let home = root.appendingPathComponent("home")
        let projectCfg = MCPUrlServerDirectory.projectConfigURL(cwd: cwd)
        let globalCfg = MCPUrlServerDirectory.globalConfigURL(home: home)
        try fm.createDirectory(at: projectCfg.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: globalCfg.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // Both define "shared"; project should win. Global also has "globalonly".
        try data("""
        [ { "name": "shared", "url": "https://project.example.com/mcp" } ]
        """).write(to: projectCfg)
        try data("""
        [ { "name": "shared", "url": "https://global.example.com/mcp" },
          { "name": "globalonly", "url": "https://only.example.com/mcp" } ]
        """).write(to: globalCfg)

        let servers = MCPUrlServerDirectory.discover(cwd: cwd, home: home)
        #expect(servers.map(\.name) == ["shared", "globalonly"])
        let shared = try #require(servers.first { $0.name == "shared" })
        #expect(shared.host == "project.example.com")  // project won
    }

    @Test("discover returns empty when no config files exist")
    func discoverEmptyWhenAbsent() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-absent-\(UUID().uuidString)")
        let servers = MCPUrlServerDirectory.discover(
            cwd: root.appendingPathComponent("p"),
            home: root.appendingPathComponent("h")
        )
        #expect(servers.isEmpty)
    }

    @Test("discover does not follow symlinked config files")
    func discoverRejectsSymlinkedConfig() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("mcp-symlink-discover-\(UUID().uuidString)")
        let cwd = root.appendingPathComponent("project")
        let home = root.appendingPathComponent("home")
        let projectCfg = MCPUrlServerDirectory.projectConfigURL(cwd: cwd)
        let outsideCfg = root.appendingPathComponent("outside-url-servers.json")
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: projectCfg.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data("""
        [ { "name": "outside", "url": "https://outside.example.com/mcp" } ]
        """).write(to: outsideCfg)
        try fm.createSymbolicLink(at: projectCfg, withDestinationURL: outsideCfg)

        let servers = MCPUrlServerDirectory.discover(cwd: cwd, home: home)
        #expect(servers.isEmpty)
    }

    @Test("install writes bare-array https config without token values")
    func installWritesConfigWithoutTokenValues() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-write-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let servers = try MCPUrlServerDirectory.install(
            MCPUrlServerDirectory.WritableEntry(
                name: "context7",
                url: "https://mcp.context7.com/mcp",
                authorizationTokenEnv: "CONTEXT7_API_KEY"
            ),
            to: config
        )

        #expect(servers.map(\.name) == ["context7"])
        #expect(servers[0].declaresAuth)
        let raw = try String(contentsOf: config, encoding: .utf8)
        #expect(raw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("["))
        #expect(raw.contains("\"authorization_token_env\" : \"CONTEXT7_API_KEY\""))
        #expect(!raw.contains("authorization_token\""))

        let configMode = try #require(
            (try FileManager.default.attributesOfItem(atPath: config.path)[.posixPermissions] as? NSNumber)?.intValue
        )
        let directoryMode = try #require(
            (try FileManager.default.attributesOfItem(atPath: config.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber)?.intValue
        )
        #expect(configMode & 0o777 == 0o600)
        #expect(directoryMode & 0o777 == 0o700)
    }

    @Test("install replaces by name without duplicating")
    func installReplacesByName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-replace-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try MCPUrlServerDirectory.install(
            MCPUrlServerDirectory.WritableEntry(name: "docs", url: "https://old.example.com/mcp"),
            to: config
        )
        let servers = try MCPUrlServerDirectory.install(
            MCPUrlServerDirectory.WritableEntry(name: "docs", url: "https://new.example.com/mcp"),
            to: config
        )

        #expect(servers.count == 1)
        #expect(servers[0].url == "https://new.example.com/mcp")
    }

    @Test("writer rejects non-https URL MCP servers")
    func writerRejectsNonHTTPS() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-reject-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(throws: MCPUrlServerDirectory.WriteError.notHTTPS("http://bad.example.com/mcp")) {
            try MCPUrlServerDirectory.install(
                MCPUrlServerDirectory.WritableEntry(name: "bad", url: "http://bad.example.com/mcp"),
                to: config
            )
        }
    }

    @Test("writer rejects malformed HTTPS URLs and embedded credentials")
    func writerRejectsMalformedHTTPSAndUserinfo() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-reject-malformed-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        for url in ["https:///mcp", "https://token@example.com/mcp", "https://user:pass@example.com/mcp"] {
            #expect(throws: MCPUrlServerDirectory.WriteError.notHTTPS(url)) {
                try MCPUrlServerDirectory.install(
                    MCPUrlServerDirectory.WritableEntry(name: "bad", url: url),
                    to: config
                )
            }
        }
    }

    @Test("writer rejects query strings and fragments without echoing secrets")
    func writerRejectsSecretBearingURLComponents() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-reject-secret-bearing-url-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        for url in ["https://example.com/mcp?token=abc123", "https://example.com/mcp#token=abc123"] {
            do {
                try MCPUrlServerDirectory.install(
                    MCPUrlServerDirectory.WritableEntry(name: "bad", url: url),
                    to: config
                )
                Issue.record("Expected query/fragment URL component to be rejected")
            } catch let error as MCPUrlServerDirectory.WriteError {
                #expect(error == .secretBearingURLComponentPresent)
                #expect(error.errorDescription?.contains("abc123") == false)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test("writer accepts only process environment shaped token keys")
    func writerRejectsInvalidAuthorizationTokenEnvKeys() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-reject-env-key-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try MCPUrlServerDirectory.install(
            MCPUrlServerDirectory.WritableEntry(
                name: "good",
                url: "https://good.example.com/mcp",
                authorizationTokenEnv: "_TOKEN_9"
            ),
            to: config
        )

        for key in ["1TOKEN", "TOKEN NAME", "TOKEN-NAME", "TOKEN\nNAME", "TØKEN"] {
            #expect(throws: MCPUrlServerDirectory.WriteError.invalidAuthorizationTokenEnv(key)) {
                try MCPUrlServerDirectory.install(
                    MCPUrlServerDirectory.WritableEntry(
                        name: "bad-\(key)",
                        url: "https://bad.example.com/mcp",
                        authorizationTokenEnv: key
                    ),
                    to: config
                )
            }
        }
    }

    @Test("writer validation diagnostics do not echo rejected secret values")
    func writerDiagnosticsDoNotEchoRejectedSecretValues() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-redacted-diagnostics-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        for entry in [
            MCPUrlServerDirectory.WritableEntry(name: "bad-url", url: "https://abc123@example.com/mcp"),
            MCPUrlServerDirectory.WritableEntry(name: "bad-query", url: "https://example.com/mcp?token=abc123"),
            MCPUrlServerDirectory.WritableEntry(
                name: "bad-env",
                url: "https://example.com/mcp",
                authorizationTokenEnv: "abc123-secret"
            ),
        ] {
            do {
                try MCPUrlServerDirectory.install(entry, to: config)
                Issue.record("Expected invalid URL MCP entry to be rejected")
            } catch let error as MCPUrlServerDirectory.WriteError {
                #expect(error.errorDescription?.contains("abc123") == false)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test("writer diagnostics redact path-leaking external errors")
    func writerDiagnosticsRedactPathLeakingExternalErrors() {
        let privatePath = "/private/var/folders/mcp/url_servers.json"
        let error = NSError(
            domain: privatePath,
            code: 21,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
        let message = MCPUrlServerDirectory.Diagnostics.externalErrorDescription(
            error,
            fallback: "filesystem error"
        )

        #expect(message.contains("filesystem error"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=21"))
        #expect(message.count <= MCPUrlServerDirectory.Diagnostics.maxFailureReasonCharacters)
        #expect(!message.contains(privatePath))
        #expect(!message.contains("failed to open"))
    }

    @Test("extensions settings status routes MCP server failures through diagnostics")
    func extensionsSettingsStatusRoutesMCPServerFailuresThroughDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ExtensionsDetailView.swift")
        let directory = try loadMirroredSourceTextFile("Epistemos/Omega/MCPUrlServerDirectory.swift")
        let rustURLServers = try loadMirroredSourceTextFile("agent_core/src/mcp/url_servers.rs")
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_EXTENSIBILITY_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")

        #expect(source.contains("nonisolated enum MCPServerSettingsStatus"))
        #expect(source.contains("MCPServerSettingsStatus.message(for: error"))
        #expect(source.contains("MCPUrlServerDirectory.Diagnostics.externalErrorDescription"))
        #expect(!source.contains("return .failure(error.localizedDescription)"))
        #expect(directory.contains("enum Diagnostics"))
        #expect(directory.contains("Diagnostics.externalErrorDescription(error, fallback: \"filesystem error\")"))
        #expect(directory.contains(".posixPermissions: 0o700"))
        #expect(directory.contains(".posixPermissions: 0o600"))
        #expect(directory.contains("rejectConfigPathSymlinkComponents"))
        #expect(directory.contains("firstExistingSymlinkComponent"))
        #expect(directory.contains("config path could not be inspected safely"))
        #expect(directory.contains("lstat"))
        #expect(directory.contains("S_IFLNK"))
        #expect(!directory.contains("throw WriteError.writeFailed(error.localizedDescription)"))
        #expect(rustURLServers.contains("const MAX_CONFIG_BYTES: usize = 256 * 1024"))
        #expect(rustURLServers.contains("libc::O_NOFOLLOW"))
        #expect(rustURLServers.contains("validated_https_url"))
        #expect(rustURLServers.contains("reqwest::Url::parse"))
        #expect(rustURLServers.contains("parsed.username().is_empty()"))
        #expect(rustURLServers.contains("parsed.query().is_some()"))
        #expect(rustURLServers.contains("is_ascii_alphabetic"))
        #expect(rustURLServers.contains("if authorization_token_env.is_some_and(|key| !auth_env_key_allowed(key))"))
        #expect(!rustURLServers.contains("url.starts_with(\"https://\")"))
        #expect(!rustURLServers.contains(#"!key.contains('=') && !key.contains('\0')"#))
        #expect(!rustURLServers.contains(".or(entry.authorization_token)"))
        #expect(codepack.contains("MCP server settings status text"))
        #expect(capabilities.contains("MCP server settings status text"))
    }

    @Test("uninstall removes only the named server")
    func uninstallRemovesNamedServer() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-uninstall-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try MCPUrlServerDirectory.write([
            MCPUrlServerDirectory.WritableEntry(name: "one", url: "https://one.example.com/mcp"),
            MCPUrlServerDirectory.WritableEntry(name: "two", url: "https://two.example.com/mcp"),
        ], to: config)

        let servers = try MCPUrlServerDirectory.uninstall(name: "one", from: config)
        #expect(servers.map(\.name) == ["two"])
    }

    @Test("install refuses to rewrite configs that contain inline token values")
    func installRefusesInlineTokenRewrite() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-inline-token-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        try FileManager.default.createDirectory(
            at: config.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let original = """
        [
          {
            "name": "secret-server",
            "url": "https://secret.example.com/mcp",
            "authorization_token": "do-not-drop"
          }
        ]
        """
        try data(original).write(to: config)

        #expect(throws: MCPUrlServerDirectory.WriteError.inlineTokenPresent("secret-server")) {
            try MCPUrlServerDirectory.install(
                MCPUrlServerDirectory.WritableEntry(
                    name: "context7",
                    url: "https://mcp.context7.com/mcp"
                ),
                to: config
            )
        }

        let raw = try String(contentsOf: config, encoding: .utf8)
        #expect(raw.contains("\"authorization_token\": \"do-not-drop\""))
        #expect(!raw.contains("context7"))
    }

    @Test("load writable entries skips inline token configs")
    func loadWritableEntriesSkipsInlineTokenConfigs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp-load-inline-token-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        try FileManager.default.createDirectory(
            at: config.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try data("""
        [
          {
            "name": "inline",
            "url": "https://inline.example.com/mcp",
            "authorization_token": "do-not-load"
          },
          {
            "name": "env",
            "url": "https://env.example.com/mcp",
            "authorization_token_env": "ENV_TOKEN"
          }
        ]
        """).write(to: config)

        let entries = MCPUrlServerDirectory.loadWritableEntries(from: config)
        #expect(entries.map(\.name) == ["env"])
    }

    @Test("install refuses to rewrite symlinked config files")
    func installRefusesSymlinkedConfigRewrite() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("mcp-symlink-rewrite-\(UUID().uuidString)")
        let config = root.appendingPathComponent("url_servers.json")
        let outside = root.appendingPathComponent("outside-url-servers.json")
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try data("""
        [ { "name": "outside", "url": "https://outside.example.com/mcp" } ]
        """).write(to: outside)
        try fm.createSymbolicLink(at: config, withDestinationURL: outside)

        #expect(throws: MCPUrlServerDirectory.WriteError.writeFailed("existing config file is a symbolic link")) {
            try MCPUrlServerDirectory.install(
                MCPUrlServerDirectory.WritableEntry(
                    name: "context7",
                    url: "https://mcp.context7.com/mcp"
                ),
                to: config
            )
        }

        let raw = try String(contentsOf: outside, encoding: .utf8)
        #expect(raw.contains("outside.example.com"))
        #expect(!raw.contains("context7"))
    }

    @Test("install refuses symlinked config directories")
    func installRefusesSymlinkedConfigDirectories() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("mcp-symlink-directory-\(UUID().uuidString)")
        let outside = root.appendingPathComponent("outside-config", isDirectory: true)
        let linkedDirectory = root.appendingPathComponent("linked-config", isDirectory: true)
        let config = linkedDirectory.appendingPathComponent("url_servers.json", isDirectory: false)
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: linkedDirectory, withDestinationURL: outside)

        do {
            _ = try MCPUrlServerDirectory.install(
                MCPUrlServerDirectory.WritableEntry(
                    name: "context7",
                    url: "https://mcp.context7.com/mcp"
                ),
                to: config
            )
            Issue.record("Expected symlinked MCP config directory to be rejected")
        } catch let error as MCPUrlServerDirectory.WriteError {
            #expect(error.errorDescription?.contains("symbolic link component linked-config") == true)
            #expect(error.errorDescription?.contains(outside.path) == false)
        }

        #expect(!fm.fileExists(atPath: outside.appendingPathComponent("url_servers.json").path))
    }
}
