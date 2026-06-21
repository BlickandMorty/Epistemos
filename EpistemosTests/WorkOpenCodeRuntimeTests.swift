import Testing
import Foundation
@testable import Epistemos

/// WORK = OpenCode shell — bundled-runtime resolver + lazy lifecycle (owner 2026-06-21).
/// Verifies the live-resolver is HONEST (inert until the OpenCode runtime is actually
/// bundled — no fake "present", no spawn against a missing binary), that the loopback
/// env is pinned host-private, and that the live shell yields a real launch spec. The
/// connective piece that turns the Seam-A contract + native terminal view LIVE the
/// moment OpenCode is vendored into Resources.
@Suite("Work = OpenCode shell — bundled runtime resolver")
struct WorkOpenCodeRuntimeTests {
    @Test("bundled runtime is honestly absent until OpenCode is vendored (no fake present)")
    func runtimeAbsentByDefault() {
        // The test bundle has no opencode-runtime/bin/opencode → must be nil.
        #expect(WorkOpenCodeRuntime.bundledRuntimeURL(bundle: .main) == nil)
    }

    @Test("shell env pins the server to loopback (host-private, never exposed)")
    func envPinsLoopback() {
        let env = WorkOpenCodeRuntime.shellEnvironment(base: ["PATH": "/usr/bin"], runtimeURL: nil)
        #expect(env["OPENCODE_HOST"] == "127.0.0.1")
        #expect(env["OPENCODE_PORT"] == String(WorkOpenCodeRuntime.defaultPort))
        #expect(env["PATH"] == "/usr/bin")   // no runtime → PATH untouched
    }

    @Test("bundled runtime prepends its bin dir to PATH (TUI finds its own Bun first)")
    func envPrependsRuntimeBin() {
        let runtime = URL(fileURLWithPath: "/Apps/Epistemos.app/Contents/Resources/opencode-runtime/bin/opencode")
        let env = WorkOpenCodeRuntime.shellEnvironment(base: ["PATH": "/usr/bin"], runtimeURL: runtime)
        #expect(env["PATH"] == "/Apps/Epistemos.app/Contents/Resources/opencode-runtime/bin:/usr/bin")
    }

    @Test("live shell yields a real launch spec rooted at the workspace, pinned loopback")
    func liveShellSpec() throws {
        let runtime = URL(fileURLWithPath: "/Apps/Epistemos.app/Contents/Resources/opencode-runtime/bin/opencode")
        let shell = BundledWorkOpenCodeShell(runtimeURL: runtime)
        #expect(shell.isReady == true)
        let ws = URL(fileURLWithPath: "/tmp/work-ws")
        let spec = try shell.launchSpec(workspace: ws)
        #expect(spec.executableURL == runtime)        // the bundled opencode TUI
        #expect(spec.workingDirectory == ws)          // rooted at the open workspace
        #expect(spec.environment["OPENCODE_HOST"] == "127.0.0.1")
    }

    @Test("factory stays INERT when armed but the runtime is absent (honest — no fake live)")
    func factoryHonestWhenRuntimeAbsent() {
        // Armed flag but no bundled runtime in the test bundle → must resolve inert.
        let shell = WorkOpenCodeShellFactory.resolve(
            environment: [WorkOpenCodeShellGateStatus.flagName: "1"]
        )
        #if EPISTEMOS_APP_STORE
        #expect(shell.isReady == false)
        #else
        #expect(shell.isReady == false)   // armed, but runtime absent → inert, never faked live
        #endif
    }

    @Test("kill-on-idle window is configured (lazy-launch, kill-on-idle lifecycle)")
    func idlePolicy() {
        #expect(WorkOpenCodeRuntime.idleTimeout > 0)
        #expect(WorkOpenCodeRuntime.loopbackHost == "127.0.0.1")
    }
}
