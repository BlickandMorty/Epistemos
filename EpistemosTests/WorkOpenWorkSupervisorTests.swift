import Foundation
import Testing
@testable import Epistemos

@Suite("Work OpenWork supervisor — worker launch helpers")
struct WorkOpenWorkSupervisorTests {
    @Test("workerArguments builds the loopback worker argv with token + workspace")
    func workerArgs() {
        let args = WorkOpenWorkSupervisor.workerArguments(
            port: 8787, token: "tok-1", vaultRoot: URL(fileURLWithPath: "/v"))
        #expect(args.contains("--host") && args.contains("127.0.0.1"))
        #expect(args.contains("--port") && args.contains("8787"))
        #expect(args.contains("--cors") && args.contains("*"))
        #expect(args.contains("--token") && args.contains("tok-1"))
        #expect(args.contains("--workspace") && args.contains("/v"))
        // Auto-approval: the worker defaults to manual, which would 403 every embedded agent write (no approval UI).
        #expect(args.contains("--approval") && args.contains("auto"))
    }

    @Test("workerArguments omits --workspace when no vault")
    func workerArgsNoVault() {
        let args = WorkOpenWorkSupervisor.workerArguments(port: 8787, token: "t", vaultRoot: nil)
        #expect(!args.contains("--workspace"))
    }

    @Test("parseListeningURL extracts + normalizes the base URL to localhost (ATS-safe)")
    func parseListening() {
        let url = WorkOpenWorkSupervisor.parseListeningURL(
            from: "OpenWork server listening on http://127.0.0.1:8787")
        #expect(url?.absoluteString == "http://localhost:8787")
    }

    @Test("parseListeningURL ignores non-listening lines")
    func parseNonListening() {
        #expect(WorkOpenWorkSupervisor.parseListeningURL(from: "Client token: abc") == nil)
        #expect(WorkOpenWorkSupervisor.parseListeningURL(from: "starting up") == nil)
        #expect(WorkOpenWorkSupervisor.parseListeningURL(
            from: "OpenWork server listening on https://127.0.0.1:8787") == nil)
        #expect(WorkOpenWorkSupervisor.parseListeningURL(
            from: "OpenWork server listening on http://example.com:8787") == nil)
        #expect(WorkOpenWorkSupervisor.parseListeningURL(
            from: "OpenWork server listening on http://127.0.0.1:8788") == nil)
        #expect(WorkOpenWorkSupervisor.parseListeningURL(
            from: "OpenWork server listening on http://127.0.0.1:8787/api") == nil)
    }

    @Test("workerEnvironment turns managed OpenCode ON + points at the bundled binary + PATH")
    func workerEnv() {
        let env = WorkOpenWorkSupervisor.workerEnvironment(
            opencodeBin: "/x/bin/opencode", base: ["PATH": "/usr/bin"])
        #expect(env["OPENWORK_MANAGE_OPENCODE"] == "1")  // the switch the worker checks to spawn managed OpenCode
        #expect(env["OPENWORK_OPENCODE_BIN"] == "/x/bin/opencode")
        #expect(env["PATH"] == "/x/bin:/usr/bin")
        // No bundled binary: still turns managed OpenCode ON (worker falls back to its own `opencode` lookup).
        let noBin = WorkOpenWorkSupervisor.workerEnvironment(opencodeBin: nil, base: ["PATH": "/usr/bin"])
        #expect(noBin["OPENWORK_MANAGE_OPENCODE"] == "1")
        #expect(noBin["OPENWORK_OPENCODE_BIN"] == nil)
        #expect(noBin["PATH"] == "/usr/bin")
        #expect(WorkOpenWorkSupervisor.workerEnvironment(
            opencodeBin: "/x/bin/opencode", base: [:])["PATH"] == "/x/bin")
    }

    @Test("fallback process supervisors surface unexpected child exits instead of staying falsely running")
    func processExitHandlersAreWired() throws {
        let worker = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenWorkSupervisor.swift")
        let runtime = try loadMirroredSourceTextFile("Epistemos/Work/WorkRuntimeSupervisor.swift")

        for src in [worker, runtime] {
            #expect(src.contains("proc.terminationHandler"))
            #expect(src.contains("handleProcessExit(statusCode: process.terminationStatus)"))
            #expect(src.contains("case .starting:"))
            #expect(src.contains("case .running:"))
            #expect(src.contains("exited unexpectedly"))
            #expect(src.contains("WorkServerDiagnostics.statusMessage("))
            #expect(!src.contains("error.localizedDescription"))
            #expect(!src.contains("String(describing: error)"))
        }
    }

    @Test("nativeMCPRegistrationBody builds the worker POST body for epistemos-native (remote MCP)")
    func nativeMCPRegistrationBody() throws {
        let data = try #require(WorkOpenWorkSupervisor.nativeMCPRegistrationBody(
            url: "http://localhost:9123/mcp", token: "ntok-7"))
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "epistemos-native")
        let config = try #require(json["config"] as? [String: Any])
        // Remote shape the worker's validateMcpConfig accepts (type+http url); headers carry the bearer token.
        #expect(config["type"] as? String == "remote")
        #expect(config["url"] as? String == "http://localhost:9123/mcp")
        #expect(config["enabled"] as? Bool == true)
        let headers = try #require(config["headers"] as? [String: String])
        #expect(headers["Authorization"] == "Bearer ntok-7")
    }

    @Test("nativeMCPRegistrationBody rejects unsafe native MCP registrations")
    func nativeMCPRegistrationBodyRejectsUnsafeRegistrations() {
        for bad in [
            ("http://localhost:9123/mcp", "  "),
            ("https://localhost:9123/mcp", "ntok"),
            ("http://localhost:9123/not-mcp", "ntok"),
            ("http://localhost.evil.example:9123/mcp", "ntok"),
            ("http://example.com:9123/mcp", "ntok"),
            ("http://localhost/mcp", "ntok"),
            ("http://localhost:0/mcp", "ntok"),
            ("http://localhost:80/mcp", "ntok"),
        ] {
            #expect(WorkOpenWorkSupervisor.nativeMCPRegistrationBody(url: bad.0, token: bad.1) == nil)
        }
    }

    @Test("workspaceID matches by path (trailing-slash tolerant)")
    func workspaceIDByPath() {
        let json = Data("""
        {"workspaces":[{"id":"ws_aaa","path":"/Users/x/vault"},{"id":"ws_bbb","path":"/other"}]}
        """.utf8)
        #expect(WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: json, matchingPath: "/Users/x/vault") == "ws_aaa")
        #expect(WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: json, matchingPath: "/Users/x/vault/") == "ws_aaa")
        #expect(WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: json, matchingPath: "/other") == "ws_bbb")
    }

    @Test("workspaceID falls back to the only entry when path differs (single-vault worker)")
    func workspaceIDSingleFallback() {
        let json = Data("""
        {"workspaces":[{"id":"ws_only","path":"/private/var/folders/abc/vault"}]}
        """.utf8)
        #expect(WorkOpenWorkSupervisor.workspaceID(
            fromWorkspacesJSON: json, matchingPath: "/var/folders/abc/vault") == "ws_only")
    }

    @Test("workspaceID returns nil on no-match (multi) and malformed input")
    func workspaceIDNilCases() {
        let multi = Data("""
        {"workspaces":[{"id":"ws_a","path":"/a"},{"id":"ws_b","path":"/b"}]}
        """.utf8)
        #expect(WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: multi, matchingPath: "/nope") == nil)
        #expect(WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: Data("not json".utf8), matchingPath: "/a") == nil)
        #expect(WorkOpenWorkSupervisor.workspaceID(fromWorkspacesJSON: Data("{}".utf8), matchingPath: "/a") == nil)
    }
}
