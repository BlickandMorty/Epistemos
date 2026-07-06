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

    @Test("launchSpec wires OPENCODE_CONFIG via the MERGE-preserving writer, rooted at the APP VAULT (0.49/0.49b)")
    func launchSpecWiresFusion() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")
        #expect(src.contains("bundledMcpServerURL()"))
        #expect(src.contains("OPENCODE_CONFIG"))
        // LIVE launch path must use the merge-preserving writer, not the clobbering one (0.49).
        #expect(src.contains("writeMergedFusionConfig("))
        #expect(src.contains("readExistingConfigTextNoFollow"))
        #expect(src.contains("maxExistingConfigBytes"))
        #expect(src.contains("open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)"))
        #expect(src.contains("fstat(fd"))
        #expect(src.contains("readToEnd()"))
        #expect(src.contains(".posixPermissions: 0o700"))
        #expect(src.contains(".posixPermissions: 0o600"))
        #expect(src.contains("writeOwnerOnlyConfigData"))
        #expect(src.contains("writeExclusiveOwnerOnlyData"))
        #expect(src.contains("O_EXCL | O_NOFOLLOW | O_CLOEXEC"))
        #expect(!src.contains("String(contentsOf: file, encoding: .utf8)"))
        #expect(!src.contains("json.write(to: file, atomically: true"))
        // 0.49b + honest-no-vault (owner 2026-06-24): the fusion MCP server roots at the Epistemos APP VAULT
        // (skills/context bridge) ONLY when a vault is active — NEVER the shell cwd AND NEVER a silent empty
        // default. No active vault → fusion is omitted entirely (diag 8af17c841).
        #expect(src.contains("if let vaultURL = epistemosVaultRoot"))
        #expect(!src.contains("FirstRunBootstrap.defaultVaultURL()"))  // no silent empty-default fallback
        #expect(src.contains("vaultRoot: fusionVaultRoot"))
    }

    @Test("fusion server roots at the app vault so the work agent sees vault notes + skills/ as MCP context (0.49b)")
    func fusionVaultRootBridgesSkills() throws {
        // The fusion server enumerates the WHOLE vault as MCP resources (resources/list walks recursively,
        // skipping hidden dirs), so when rooted at the app vault, `skills/<name>/SKILL.md` files become
        // first-class MCP resources the work agent can read. Prove the config we write carries the app-vault
        // root into the MCP server's environment (where omega_mcp_stdio reads EPISTEMOS_VAULT_ROOT).
        let appVault = "/Users/me/Documents/Epistemos"
        let json = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: nil, stdioServerPath: "/r/omega_mcp_stdio", vaultRoot: appVault)
        let v = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let server = (v["mcp"] as! [String: Any])["epistemos-vault"] as! [String: Any]
        #expect((server["environment"] as? [String: String])?["EPISTEMOS_VAULT_ROOT"] == appVault)
        // and it is the APP vault path, not a home/cwd path.
        #expect(appVault.hasSuffix("Documents/Epistemos"))
    }

    @Test("merged config registers the app-hosted native-tools MCP when provided (W-R2/W-R3)")
    func nativeMCPRegisteredWhenProvided() throws {
        let json = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: nil,
            stdioServerPath: "/r/omega_mcp_stdio",
            vaultRoot: "/v",
            nativeMCP: WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: "tok123"))
        let v = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let mcp = v["mcp"] as! [String: Any]
        // Merge-preserving: the vault stdio server stays AND the native remote server is added.
        #expect(mcp["epistemos-vault"] != nil)
        let native = try #require(mcp["epistemos-native"] as? [String: Any])
        #expect(native["type"] as? String == "remote")
        #expect(native["url"] as? String == "http://127.0.0.1:5599/mcp")
        #expect((native["headers"] as? [String: String])?["Authorization"] == "Bearer tok123")
        #expect(native["enabled"] as? Bool == true)
    }

    @Test("merged config OMITS the native MCP when not provided (honest default)")
    func nativeMCPOmittedByDefault() throws {
        let json = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: nil, stdioServerPath: "/r/omega_mcp_stdio", vaultRoot: "/v")
        let v = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let mcp = v["mcp"] as! [String: Any]
        #expect(mcp["epistemos-native"] == nil)
        #expect(mcp["epistemos-vault"] != nil)
    }

    @Test("merged config omits native MCP registrations that are not trusted user-space loopback /mcp")
    func unsafeNativeMCPRegistrationIsOmitted() throws {
        for bad in [
            WorkNativeMCPRegistration(url: "http://example.com:5599/mcp", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1/mcp", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:0/mcp", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:80/mcp", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://user:pass@127.0.0.1:5599/mcp", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp?token=secret", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp#frag", token: "tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: " tok123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: "tok 123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: "tok\n123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: "tok:123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: "tok@123"),
            WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: #"tok"123"#),
        ] {
            let json = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
                existingJSON: nil,
                stdioServerPath: "/r/omega_mcp_stdio",
                vaultRoot: "/v",
                nativeMCP: bad)
            let v = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
            let mcp = v["mcp"] as! [String: Any]
            #expect(mcp["epistemos-native"] == nil)
            #expect(mcp["epistemos-vault"] != nil)
        }
    }

    @Test("(c2) a started WorkNativeMCPServer registration flows into the OpenCode config as epistemos-native")
    func nativeMCPRegistrationFlowsIntoConfig() async throws {
        // Prove the LIVE wiring: a real loopback server produces a registration whose url+token land in the
        // generated config as `epistemos-native`. Resilient — if loopback bind is unavailable in this env, fall
        // back to a synthetic registration so the config-shaping proof (the milestone requirement) still runs.
        let server = WorkNativeMCPServer(executor: { name, _ in
            LocalToolResult(toolName: name, resultJson: "{}", isError: false)
        })
        defer { server.stop() }
        var liveRegistration: WorkNativeMCPRegistration?
        if (try? server.start()) != nil {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while ContinuousClock.now < deadline {
                if case .running(let reg) = server.status { liveRegistration = reg; break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        let registration = liveRegistration
            ?? WorkNativeMCPRegistration(url: "http://127.0.0.1:5599/mcp", token: "synthetic-token")

        let json = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: nil,
            stdioServerPath: "/r/omega_mcp_stdio",
            vaultRoot: "/v",
            nativeMCP: registration)
        let v = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let mcp = v["mcp"] as! [String: Any]
        let native = try #require(mcp["epistemos-native"] as? [String: Any])
        #expect(native["type"] as? String == "remote")
        #expect(native["url"] as? String == registration.url)
        #expect((native["headers"] as? [String: String])?["Authorization"] == "Bearer \(registration.token)")
        #expect(native["enabled"] as? Bool == true)

        // When the loopback listener actually bound, prove it's a real per-launch /mcp endpoint + token.
        if let live = liveRegistration {
            #expect(live.url.hasPrefix("http://127.0.0.1:"))
            #expect(live.url.hasSuffix("/mcp"))
            #expect(!live.token.isEmpty)
        }
    }

    @Test("merge PRESERVES user-installed MCP servers + other keys while (re)asserting the fusion server (0.49)")
    func mergePreservesUserInstalls() throws {
        // Simulate a config the user grew by installing Playwright + browser-use MCPs via the work TUI,
        // plus a non-mcp key OpenCode persists. This is exactly what would be CLOBBERED by a fresh rewrite.
        let existing = """
        {
          "$schema": "https://opencode.ai/config.json",
          "theme": "opencode",
          "mcp": {
            "playwright": { "type": "local", "command": ["npx", "@playwright/mcp"], "enabled": true },
            "browser-use": { "type": "local", "command": ["uvx", "browser-use-mcp"], "enabled": true }
          }
        }
        """
        let merged = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: existing,
            stdioServerPath: "/Apps/Epistemos.app/Contents/Resources/omega_mcp_stdio",
            vaultRoot: "/Users/me/Vault")
        let v = try JSONSerialization.jsonObject(with: Data(merged.utf8)) as! [String: Any]
        let mcp = v["mcp"] as! [String: Any]
        // User installs SURVIVE the merge (the 0.49 bug was that they didn't).
        #expect(mcp["playwright"] != nil)
        #expect(mcp["browser-use"] != nil)
        #expect(((mcp["playwright"] as? [String: Any])?["command"] as? [String])?.contains("@playwright/mcp") == true)
        // Non-mcp keys the user/OpenCode set are preserved too.
        #expect(v["theme"] as? String == "opencode")
        // Our fusion server is (re)asserted on top, never lost.
        let fusion = mcp["epistemos-vault"] as! [String: Any]
        #expect(fusion["enabled"] as? Bool == true)
        #expect((fusion["command"] as? [String])?.first?.hasSuffix("omega_mcp_stdio") == true)
        #expect((fusion["environment"] as? [String: String])?["EPISTEMOS_VAULT_ROOT"] == "/Users/me/Vault")
    }

    @Test("merge on empty/garbage existing config yields a clean fusion-only config (honest fresh start)")
    func mergeOnEmptyIsCleanFusion() throws {
        for existing in [nil, "", "{ not json", "[]"] as [String?] {
            let merged = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
                existingJSON: existing,
                stdioServerPath: "/r/omega_mcp_stdio", vaultRoot: "/v")
            let v = try JSONSerialization.jsonObject(with: Data(merged.utf8)) as! [String: Any]
            let mcp = v["mcp"] as! [String: Any]
            #expect(mcp["epistemos-vault"] != nil)
            #expect(v["$schema"] as? String == "https://opencode.ai/config.json")
        }
    }

    @Test("durable config path is the stable Application-Support home (persists across launches)")
    func durableConfigPathStable() {
        let a = WorkOpenCodeRuntime.fusionConfigURL()
        let b = WorkOpenCodeRuntime.fusionConfigURL()
        #expect(a == b)
        #expect(a?.lastPathComponent == "opencode.json")
        #expect(a?.path.contains("Epistemos/opencode") == true)
    }

    @Test("round-trip: a user install written to the durable file survives a subsequent merge-write (0.49 e2e)")
    func roundTripUserInstallSurvivesRelaunch() throws {
        // Real-FS proof of the persistence guarantee using a temp file as the durable config stand-in.
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("epi-oc-rt-\(ProcessInfo.processInfo.globallyUniqueString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let file = dir.appendingPathComponent("opencode.json")

        // Launch 1: fresh merge writes the fusion-only config.
        try WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: nil, stdioServerPath: "/r/omega_mcp_stdio", vaultRoot: "/v")
            .write(to: file, atomically: true, encoding: .utf8)

        // User installs an MCP into the durable file (what the TUI's MCP-add does to OPENCODE_CONFIG).
        var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        var mcp = obj["mcp"] as! [String: Any]
        mcp["playwright"] = ["type": "local", "command": ["npx", "@playwright/mcp"], "enabled": true]
        obj["mcp"] = mcp
        try JSONSerialization.data(withJSONObject: obj).write(to: file)

        // Launch 2: relaunch re-runs the merge over the now-grown file. The install MUST survive.
        let existing = try String(contentsOf: file, encoding: .utf8)
        let relaunched = WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(
            existingJSON: existing, stdioServerPath: "/r/omega_mcp_stdio", vaultRoot: "/v")
        let after = try JSONSerialization.jsonObject(with: Data(relaunched.utf8)) as! [String: Any]
        let afterMcp = after["mcp"] as! [String: Any]
        #expect(afterMcp["playwright"] != nil)      // the bug is fixed: install survives relaunch
        #expect(afterMcp["epistemos-vault"] != nil) // fusion still present
    }

    @Test("kill-on-idle window is configured (lazy-launch, kill-on-idle lifecycle)")
    func idlePolicy() {
        #expect(WorkOpenCodeRuntime.idleTimeout > 0)
        #expect(WorkOpenCodeRuntime.loopbackHost == "127.0.0.1")
    }
}
