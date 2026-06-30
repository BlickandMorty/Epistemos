import Foundation
import Testing
@testable import Epistemos

@Suite("Work Runtime Supervisor")
struct WorkRuntimeSupervisorTests {
    @Test("serve argv pins the runtime to loopback (no --cors)")
    func serveArgumentsPinLoopback() {
        let args = WorkRuntimeSupervisor.serveArguments(host: "127.0.0.1")
        #expect(args == ["serve", "--hostname", "127.0.0.1"])
        #expect(!args.contains("--cors"))
    }

    @Test("listening line parses to the loopback base URL; non-listening lines are nil")
    func parsesListeningURL() {
        let url = WorkRuntimeSupervisor.parseListeningURL(
            from: "opencode server listening on http://127.0.0.1:4096")
        #expect(url == URL(string: "http://127.0.0.1:4096"))
        // Trailing punctuation is stripped.
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "listening at http://127.0.0.1:5050/.")
            == URL(string: "http://127.0.0.1:5050"))
        // A line without "listening" is ignored even if it has a URL.
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "fetched http://127.0.0.1:4096/x") == nil)
        // A "listening" line with no URL is nil.
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "server is listening") == nil)
        // Listening lines are loopback-only, HTTP-only, user-space-port-only, and must be base URLs.
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "listening on https://127.0.0.1:4096") == nil)
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "listening on http://example.com:4096") == nil)
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "listening on http://127.0.0.1:80") == nil)
        #expect(WorkRuntimeSupervisor.parseListeningURL(from: "listening on http://127.0.0.1:4096/api") == nil)
    }

    @Test("health URL targets /global/health")
    func healthURLIsGlobalHealth() {
        let base = URL(string: "http://127.0.0.1:4096")!
        #expect(WorkRuntimeSupervisor.healthURL(base: base)
            == URL(string: "http://127.0.0.1:4096/global/health"))
    }

    @Test("loopback basic-auth header is base64(user:pass)")
    func basicAuthHeader() {
        let auth = WorkRuntimeAuth(username: "u", password: "p")
        // base64("u:p") == "dTpw"
        #expect(auth.basicAuthHeaderValue == "Basic dTpw")
    }

    @Test("child env prepends the runtime bin dir to PATH and injects per-launch creds")
    func processEnvironmentWiresPathAndCreds() {
        let binary = URL(fileURLWithPath: "/Runtime/opencode-runtime/bin/opencode")
        let auth = WorkRuntimeAuth(username: "user", password: "secret")
        let env = WorkRuntimeSupervisor.processEnvironment(
            runtimeBinary: binary, auth: auth, base: ["PATH": "/usr/bin"])
        #expect(env["PATH"] == "/Runtime/opencode-runtime/bin:/usr/bin")
        #expect(env["OPENCODE_SERVER_USERNAME"] == "user")
        #expect(env["OPENCODE_SERVER_PASSWORD"] == "secret")
    }

    @Test("launch failures route through bounded diagnostics")
    func launchFailuresRouteThroughBoundedDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Work/WorkRuntimeSupervisor.swift")

        #expect(source.contains("WorkServerDiagnostics.statusMessage("))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
    }
}
