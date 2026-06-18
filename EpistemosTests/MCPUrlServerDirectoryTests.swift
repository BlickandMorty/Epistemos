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
}
