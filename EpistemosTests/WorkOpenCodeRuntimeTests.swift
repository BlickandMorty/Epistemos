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
    @Test("runtime resolution is honestly nil when NO binary is vendored (no fake present)")
    func runtimeAbsentByDefault() throws {
        // "Honestly absent" is the resolver's behavior on a runtime-FREE resources dir — assert it
        // against a controlled empty dir (NOT `.main`, which legitimately bundles the vendored runtime
        // once build-opencode-runtime.sh has staged it; iter32 made the resolver honestly find it,
        // including the flattened Resources-root layout). No fake "present" for an empty dir.
        let fm = FileManager.default
        let empty = fm.temporaryDirectory.appendingPathComponent("epi-oc-empty-\(ProcessInfo.processInfo.globallyUniqueString)")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: empty) }
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: empty) == nil)
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: nil) == nil)
        // If `.main` resolves a runtime, it must honestly be an executable named "opencode" (never a fake).
        if let main = WorkOpenCodeRuntime.bundledRuntimeURL(bundle: .main) {
            #expect(main.lastPathComponent == "opencode")
            #expect(fm.isExecutableFile(atPath: main.path))
        }
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

    @Test("factory readiness HONESTLY mirrors the bundled runtime (live iff present; always inert on MAS)")
    func factoryHonestlyMirrorsBundledRuntime() {
        let shell = WorkOpenCodeShellFactory.resolve(
            environment: [WorkOpenCodeShellGateStatus.flagName: "1"]
        )
        #if EPISTEMOS_APP_STORE
        // MAS: the OpenCode sidecar is Pro-only → always inert, never faked live.
        #expect(shell.isReady == false)
        #else
        // Pro/direct-dist: the factory is LIVE iff the runtime is ACTUALLY bundled (resolved via the
        // structured `opencode-runtime/bin/` layout OR the flattened Resources-root fallback, iter32) —
        // honest, never faked. Tie the assertion to the real bundle state so it holds whether or not
        // build-opencode-runtime.sh has vendored the runtime into this test host.
        #expect(shell.isReady == (WorkOpenCodeRuntime.bundledRuntimeURL() != nil))
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
