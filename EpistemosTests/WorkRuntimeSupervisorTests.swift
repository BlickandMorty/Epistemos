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
        #expect(env["PATH"]?.hasPrefix("/Runtime/opencode-runtime/bin:/usr/bin") == true)
        #expect(env["OPENCODE_SERVER_USERNAME"] == "user")
        #expect(env["OPENCODE_SERVER_PASSWORD"] == "secret")
    }

    @Test("child env drops unsafe inherited values and replaces inherited auth")
    func processEnvironmentDropsUnsafeInheritedValuesAndReplacesAuth() {
        let oversized = String(
            repeating: "x",
            count: WorkRuntimeSupervisor.maxSubprocessEnvironmentValueCharacters + 1
        )
        let binary = URL(fileURLWithPath: "/Runtime/opencode-runtime/bin/opencode")
        let auth = WorkRuntimeAuth(username: "fresh-user", password: "fresh-secret")
        let env = WorkRuntimeSupervisor.processEnvironment(
            runtimeBinary: binary,
            auth: auth,
            base: [
                "PATH": "/custom/bin:relative/bin:.:/usr/bin:/custom/bin",
                "HOME": "relative/home",
                "USER": "bad\0actor",
                "LANG": oversized,
                "LC_ALL": "en_US.UTF-8",
                "TMPDIR": "/tmp/work",
                "TERM": "xterm-256color",
                "OPENCODE_SERVER_USERNAME": "stale-user",
                "OPENCODE_SERVER_PASSWORD": "stale-secret",
                "OPENAI_API_KEY": "secret-token",
                "NODE_OPTIONS": "--require /tmp/inject.js",
                "DYLD_INSERT_LIBRARIES": "/tmp/inject.dylib",
            ]
        )

        let path = env["PATH"] ?? ""
        #expect(path.hasPrefix("/Runtime/opencode-runtime/bin:/custom/bin:/usr/bin"))
        #expect(path.count <= WorkRuntimeSupervisor.maxSubprocessPathCharacters)
        #expect(path.components(separatedBy: ":").filter { $0 == "/custom/bin" }.count == 1)
        #expect(!path.components(separatedBy: ":").contains("relative/bin"))
        #expect(!path.components(separatedBy: ":").contains("."))
        #expect(!path.contains(oversized))
        #expect(env["LC_ALL"] == "en_US.UTF-8")
        #expect(env["TMPDIR"] == "/tmp/work")
        #expect(env["TERM"] == "xterm-256color")
        #expect(env["OPENCODE_SERVER_USERNAME"] == "fresh-user")
        #expect(env["OPENCODE_SERVER_PASSWORD"] == "fresh-secret")
        #expect(env["HOME"] == nil)
        #expect(env["USER"] == nil)
        #expect(env["LANG"] == nil)
        #expect(env["OPENAI_API_KEY"] == nil)
        #expect(env["NODE_OPTIONS"] == nil)
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)

        let manyBinaryDirectories = (0..<(WorkRuntimeSupervisor.maxSubprocessPathEntries + 20))
            .map { URL(fileURLWithPath: "/Runtime/bin-\($0)") }
        let capped = WorkSubprocessEnvironment.childEnvironment(
            binaryDirectories: manyBinaryDirectories,
            base: ["PATH": "/usr/bin", "HOME": "/Users/me"]
        )
        #expect(capped["PATH"]?.components(separatedBy: ":").count == WorkRuntimeSupervisor.maxSubprocessPathEntries)
    }

    @Test("launch failures route through bounded diagnostics")
    func launchFailuresRouteThroughBoundedDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Work/WorkRuntimeSupervisor.swift")

        #expect(source.contains("WorkServerDiagnostics.statusMessage("))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
    }
}
