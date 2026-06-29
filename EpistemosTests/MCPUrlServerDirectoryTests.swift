import Testing
import Foundation
@testable import Epistemos

/// P2.3 — locks the URL MCP server config parser against the Rust source of
/// truth (`agent_core/src/mcp/url_servers.rs`). What the chat surfaces must be
/// exactly the servers the Rust bridge forwards: https-only, name+url required,
/// auth declared only when a token/env field is present (never the token value),
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

    @Test("a server with no auth fields declares no auth")
    func noAuthDeclared() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [ { "name": "open", "url": "https://open.example.com/mcp" } ]
        """))
        #expect(servers.count == 1)
        #expect(!servers[0].declaresAuth)
    }

    @Test("an inline authorization_token also counts as declared auth")
    func inlineTokenDeclaresAuth() {
        let servers = MCPUrlServerDirectory.parse(data("""
        [ { "name": "inline", "url": "https://t.example.com/mcp", "authorization_token": "secret" } ]
        """))
        #expect(servers.count == 1)
        #expect(servers[0].declaresAuth)
    }

    @Test("malformed / empty JSON yields no servers (honest empty state, never a crash)")
    func malformedYieldsEmpty() {
        #expect(MCPUrlServerDirectory.parse(data("not json")).isEmpty)
        #expect(MCPUrlServerDirectory.parse(data("[]")).isEmpty)
        #expect(MCPUrlServerDirectory.parse(Data()).isEmpty)
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
}
