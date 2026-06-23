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

    @Test("resolver finds bin/opencode when the build-time vendor lands it (the goes-LIVE path)")
    func resolverFindsVendoredRuntime() throws {
        let fm = FileManager.default
        let res = fm.temporaryDirectory.appendingPathComponent("epi-oc-\(ProcessInfo.processInfo.globallyUniqueString)")
        let bin = res.appendingPathComponent("opencode-runtime/bin", isDirectory: true)
        try fm.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: res) }

        // No binary yet → nil (honest inert).
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: res) == nil)
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: nil) == nil)

        // Drop an EXECUTABLE opencode (what build-opencode-runtime.sh vendors) → resolver finds it.
        let oc = bin.appendingPathComponent("opencode")
        fm.createFile(atPath: oc.path, contents: Data("#!/bin/sh\n".utf8),
                      attributes: [.posixPermissions: 0o755])
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: res)?.lastPathComponent == "opencode")

        // A NON-executable file is not accepted (honest — must be a runnable binary).
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: oc.path)
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: res) == nil)
    }

    @Test("resolver falls back to the FLATTENED Resources-root layout (built-bundle reality, iter32)")
    func resolverFindsFlattenedRuntime() throws {
        let fm = FileManager.default
        let res = fm.temporaryDirectory.appendingPathComponent("epi-ocflat-\(ProcessInfo.processInfo.globallyUniqueString)")
        try fm.createDirectory(at: res, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: res) }

        // No structured opencode-runtime/bin AND no flattened binary → nil (honest inert).
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: res) == nil)

        // The synchronized resource copy flattens the runtime to <Resources>/opencode (no bin/ dir).
        // bun + omega_mcp_stdio land beside it; the resolver must still go LIVE off the flattened path.
        let flatOC = res.appendingPathComponent("opencode")
        fm.createFile(atPath: flatOC.path, contents: Data("#!/bin/sh\n".utf8),
                      attributes: [.posixPermissions: 0o755])
        let resolved = WorkOpenCodeRuntime.resolveRuntimeURL(inResources: res)
        #expect(resolved?.lastPathComponent == "opencode")
        // PATH co-location: the flattened resolver's parent dir IS <Resources>, where bun also lives,
        // so shellEnvironment prepends it and `opencode serve` finds its sibling bun.
        let env = WorkOpenCodeRuntime.shellEnvironment(base: ["PATH": "/usr/bin"], runtimeURL: resolved)
        #expect(env["PATH"] == "\(res.path):/usr/bin")
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

    @Test("fusion config registers omega_mcp_stdio as a local MCP server with the vault root (§720)")
    func fusionConfigRegistersVaultServer() throws {
        let json = WorkOpenCodeRuntime.openCodeConfigJSON(
            stdioServerPath: "/Apps/Epistemos.app/Contents/Resources/opencode-runtime/bin/omega_mcp_stdio",
            vaultRoot: "/Users/me/Vault")
        let v = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let mcp = v["mcp"] as! [String: Any]
        let server = mcp["epistemos-vault"] as! [String: Any]
        #expect(server["type"] as? String == "local")
        #expect(server["enabled"] as? Bool == true)
        #expect((server["command"] as? [String])?.first?.hasSuffix("omega_mcp_stdio") == true)
        #expect((server["environment"] as? [String: String])?["EPISTEMOS_VAULT_ROOT"] == "/Users/me/Vault")
    }

    @Test("launchSpec wires OPENCODE_CONFIG when the stdio fusion server is bundled (source-guarded)")
    func launchSpecWiresFusion() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")
        #expect(src.contains("bundledMcpServerURL()"))
        #expect(src.contains("OPENCODE_CONFIG"))
        #expect(src.contains("writeFusionConfig("))
    }

    @Test("kill-on-idle window is configured (lazy-launch, kill-on-idle lifecycle)")
    func idlePolicy() {
        #expect(WorkOpenCodeRuntime.idleTimeout > 0)
        #expect(WorkOpenCodeRuntime.loopbackHost == "127.0.0.1")
    }
}
