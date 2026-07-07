import Testing
import Foundation
@testable import Epistemos

/// WORK = OpenCode shell — Seam A (owner 2026-06-21). Locks the honest-inert contract
/// for the OpenCode terminal-shell seam: a runtime-presence gate, an inert default that NEVER
/// fakes a terminal (refuses with an honest error), a centralized factory, and a
/// visible health row. Mirrors the other work/act seam tests. This is the
/// foundation the native terminal view (SwiftTerm/PTY) + lazy Bun engine + vendored
/// OpenCode TUI plug into.
@Suite("Work = OpenCode shell — Seam A (honest-inert)")
struct WorkOpenCodeShellSeamTests {
    @Test("factory ignores the retired opt-in gate and mirrors only bundled runtime presence")
    func factoryIgnoresRetiredOptInGate() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeShell.swift")
        let retiredGateTypeName = "WorkOpenCodeShell" + "GateStatus"
        #expect(!src.contains(retiredGateTypeName))
        #expect(src.contains("WorkOpenCodeRuntime.bundledRuntimeURL()"))
        #expect(src.contains("#if EPISTEMOS_APP_STORE"))

        let shell = WorkOpenCodeShellFactory.resolve(environment: ["EPISTEMOS_WORK_OPENCODE_V0": "0"])
        let bundledRuntimeIsPresent = WorkOpenCodeRuntime.bundledRuntimeURL(bundle: .main) != nil
        #if EPISTEMOS_APP_STORE
        #expect(shell.isReady == false)
        #else
        #expect(shell.isReady == bundledRuntimeIsPresent)
        #endif
    }

    @Test("inert shell never fakes a terminal — not ready, refuses the launch spec")
    func inertShellRefuses() {
        let shell = InertWorkOpenCodeShell()
        #expect(shell.isReady == false)
        #expect(throws: WorkShellError.self) {
            _ = try shell.launchSpec(workspace: URL(fileURLWithPath: "/tmp"))
        }
    }

    @Test("factory goes live exactly when the bundled runtime is present")
    func factoryHonest() {
        let shell = WorkOpenCodeShellFactory.resolve(environment: [:])
        let bundledRuntimeIsPresent = WorkOpenCodeRuntime.bundledRuntimeURL(bundle: .main) != nil
        #expect(shell.isReady == bundledRuntimeIsPresent)
        let armed = WorkOpenCodeShellFactory.resolve(environment: ["EPISTEMOS_WORK_OPENCODE_V0": "1"])
        #expect(armed.isReady == bundledRuntimeIsPresent)
    }

    @Test("launch spec is a pure value type — constructing it starts no process")
    func launchSpecIsPureValue() {
        let spec = WorkShellLaunchSpec(
            executableURL: URL(fileURLWithPath: "/usr/bin/opencode"),
            arguments: ["tui"],
            workingDirectory: URL(fileURLWithPath: "/tmp/work"),
            environment: ["OPENCODE_ENGINE": "http://127.0.0.1:0"]
        )
        #expect(spec.arguments == ["tui"])
        #expect(spec.environment["OPENCODE_ENGINE"]?.contains("127.0.0.1") == true)
    }

    @Test("visible health row exists (rule #8 — the owner can SEE the seam) + is wired")
    func healthRowVisibleAndWired() throws {
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkOpenCodeShellHealthRow.swift")
        #expect(row.contains("struct WorkOpenCodeShellHealthRow"))
        // The row was refactored (owner 2026-06-22) to report the HONEST live/inert state from the
        // ACTUAL factory resolution. Assert the real source of truth it now wires to.
        #expect(row.contains("WorkOpenCodeShellFactory.resolve()"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("WorkOpenCodeShellHealthRow()"))
    }

    // MARK: - Fusion config + honest runtime gating (directive 2: Goose/Hermes/OpenClaw
    // fuse BENEATH the OpenCode shell via the omega_mcp_stdio MCP transport)

    @Test("fusion config registers the omega_mcp_stdio MCP server with the vault root (engines fuse via MCP)")
    func fusionConfigRegistersVaultMCPServer() throws {
        let json = WorkOpenCodeRuntime.openCodeConfigJSON(
            stdioServerPath: "/opt/epistemos/bin/omega_mcp_stdio",
            vaultRoot: "/Users/me/Vault")
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let server = (obj?["mcp"] as? [String: Any])?["epistemos-vault"] as? [String: Any]
        #expect(obj?["$schema"] as? String == "https://opencode.ai/config.json")
        #expect(server?["type"] as? String == "local")
        #expect(server?["command"] as? [String] == ["/opt/epistemos/bin/omega_mcp_stdio"])
        #expect((server?["environment"] as? [String: String])?["EPISTEMOS_VAULT_ROOT"] == "/Users/me/Vault")
        #expect(server?["enabled"] as? Bool == true)
    }

    @Test("runtime resolver is honest: nil with no Resources + nil while the launcher is absent (inert until vendored)")
    func runtimeResolverHonestlyNilUntilVendored() {
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: nil) == nil)
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epi-work-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: emptyDir) == nil)
    }

    @Test("runtime resolver returns the launcher once it is vendored (present + executable)")
    func runtimeResolverFindsLauncherWhenPresent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epi-work-rt-\(UUID().uuidString)", isDirectory: true)
        let binDir = root.appendingPathComponent("opencode-runtime/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        let launcher = binDir.appendingPathComponent("opencode")
        FileManager.default.createFile(
            atPath: launcher.path, contents: Data("#!/bin/sh\n".utf8),
            attributes: [.posixPermissions: 0o755])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: root)?.path == launcher.path)
    }

    @Test("shell env pins OpenCode to loopback + prepends the bundled bin dir only when the runtime is present")
    func shellEnvPinsLoopbackAndPath() {
        let noRuntime = WorkOpenCodeRuntime.shellEnvironment(base: ["PATH": "/usr/bin"], runtimeURL: nil)
        #expect(noRuntime["OPENCODE_HOST"] == "127.0.0.1")
        #expect(noRuntime["OPENCODE_PORT"] == "4096")
        #expect(noRuntime["PATH"] == "/usr/bin")   // unchanged when no runtime is vendored

        let rtURL = URL(fileURLWithPath: "/opt/epistemos/opencode-runtime/bin/opencode")
        let withRuntime = WorkOpenCodeRuntime.shellEnvironment(base: ["PATH": "/usr/bin"], runtimeURL: rtURL)
        #expect(withRuntime["PATH"]?.hasPrefix("/opt/epistemos/opencode-runtime/bin:") == true)
    }
}
