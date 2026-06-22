import Foundation

// WORK = OpenCode shell — the bundled-runtime resolver + lazy lifecycle (owner
// 2026-06-21). OpenCode ships as a BUNDLED in-app runtime (Bun/Node) — owner-
// authorized for the WORK path (addendum §110-111, "set in stone": MAS non-
// restrictive, notarized direct-distribution; this sidecar is EXPLICIT, Pro-gated,
// and VISIBLE via the health row — never a hidden/default sidecar on the chat/act
// path). Option A: the native terminal view spawns the bundled `opencode` TUI in a
// PTY; the TUI self-manages its loopback Bun server (`opencode serve`, 127.0.0.1),
// so the "lazy Bun engine / kill-on-idle" lifecycle = the PTY process lifecycle
// (SwiftTerm kills it on terminal-view teardown).
//
// HONEST: the bundled runtime is ABSENT until OpenCode is vendored into Resources.
// Until then `bundledRuntimeURL()` is nil, the shell stays inert, and nothing
// launches — no fake terminal, no spawn against a missing binary. The moment the
// vendored bundle is dropped in, the resolver goes LIVE with zero further wiring.

nonisolated enum WorkOpenCodeRuntime {
    /// Loopback only — the OpenCode server is NEVER exposed off-host.
    static let loopbackHost = "127.0.0.1"
    /// `opencode serve` default port (the TUI self-serves here).
    static let defaultPort = 4096
    /// Kill-on-idle window for the work runtime (owner: lazy-launch, kill-on-idle).
    static let idleTimeout: TimeInterval = 300

    /// Where the bundled OpenCode runtime launcher lives once vendored + bundled into
    /// the signed .app. Honest nil until then (no fake "present").
    static func bundledRuntimeURL(bundle: Bundle = .main) -> URL? {
        resolveRuntimeURL(inResources: bundle.resourceURL)
    }

    /// Pure resolver (testable without a real Bundle): the `opencode-runtime/bin/opencode` launcher under a
    /// Resources dir, IFF it exists + is executable. nil when the resources dir is nil or the binary is absent
    /// (honest — the build-time `build-opencode-runtime.sh` vendor lands it; until then the shell stays inert).
    static func resolveRuntimeURL(inResources resources: URL?) -> URL? {
        guard let resources else { return nil }
        let launcher = resources
            .appendingPathComponent("opencode-runtime", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("opencode")
        return FileManager.default.isExecutableFile(atPath: launcher.path) ? launcher : nil
    }

    /// The PTY environment for the OpenCode TUI: inherit the process env (PATH/HOME a
    /// PTY needs) and pin the server to loopback. Pure + testable. When the runtime is
    /// vendored, the bundled Bun's bin dir is prepended to PATH here.
    static func shellEnvironment(
        base: [String: String] = ProcessInfo.processInfo.environment,
        runtimeURL: URL?
    ) -> [String: String] {
        var env = base
        // Pin OpenCode's server to loopback (defense-in-depth even though it defaults
        // to 127.0.0.1) — the work server is host-private.
        env["OPENCODE_HOST"] = loopbackHost
        env["OPENCODE_PORT"] = String(defaultPort)
        if let runtimeURL {
            // Prepend the bundled runtime's bin dir so the TUI finds its own Bun/node
            // toolchain ahead of any system install.
            let binDir = runtimeURL.deletingLastPathComponent().path
            let existing = env["PATH"] ?? ""
            env["PATH"] = existing.isEmpty ? binDir : "\(binDir):\(existing)"
        }
        return env
    }

    /// The bundled `omega_mcp_stdio` MCP server (next to `bin/opencode`) — the FUSION transport that gives
    /// OpenCode's work agent the app's vault tools. nil until vendored (built+staged by the build script).
    static func bundledMcpServerURL(bundle: Bundle = .main) -> URL? {
        guard let resources = bundle.resourceURL else { return nil }
        let server = resources
            .appendingPathComponent("opencode-runtime", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("omega_mcp_stdio")
        return FileManager.default.isExecutableFile(atPath: server.path) ? server : nil
    }

    /// The OpenCode config (opencode.json) that FUSES the app's vault tools into the work TUI: registers the
    /// bundled `omega_mcp_stdio` as a local MCP server with the vault root in its environment. OpenCode reads
    /// it via `OPENCODE_CONFIG`. Pure + testable (owner §720 "Goose/etc fuse beneath OpenCode" — via MCP).
    static func openCodeConfigJSON(stdioServerPath: String, vaultRoot: String) -> String {
        let config: [String: Any] = [
            "$schema": "https://opencode.ai/config.json",
            "mcp": [
                "epistemos-vault": [
                    "type": "local",
                    "command": [stdioServerPath],
                    "environment": ["EPISTEMOS_VAULT_ROOT": vaultRoot],
                    "enabled": true,
                ],
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    /// Write the fusion config to an app-managed path (Application Support), returning its path for
    /// `OPENCODE_CONFIG`. nil on failure (the caller then launches the TUI without fusion — honest, not fatal).
    static func writeFusionConfig(_ json: String) -> String? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = support.appendingPathComponent("Epistemos/opencode", isDirectory: true)
        let file = dir.appendingPathComponent("opencode.json")
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try json.write(to: file, atomically: true, encoding: .utf8)
            return file.path
        } catch {
            return nil
        }
    }
}

/// The LIVE OpenCode work shell — resolves a real launch spec pointing at the bundled
/// `opencode` TUI rooted at the workspace. Only ever constructed when the runtime is
/// actually bundled (the factory checks), so `isReady` is honestly true here.
struct BundledWorkOpenCodeShell: WorkOpenCodeShell {
    let runtimeURL: URL

    var isReady: Bool { true }

    func launchSpec(workspace: URL) throws -> WorkShellLaunchSpec {
        var environment = WorkOpenCodeRuntime.shellEnvironment(runtimeURL: runtimeURL)
        // FUSION (owner §720): when the bundled omega_mcp_stdio server is present, write an OpenCode config
        // that registers it (with the workspace as the vault root) + point OpenCode at it via OPENCODE_CONFIG,
        // so the work TUI auto-fuses the app's vault tools. Best-effort: a write failure just omits the fusion
        // (the TUI still launches honestly), never blocks the shell.
        if let serverURL = WorkOpenCodeRuntime.bundledMcpServerURL() {
            let configJSON = WorkOpenCodeRuntime.openCodeConfigJSON(
                stdioServerPath: serverURL.path, vaultRoot: workspace.path)
            if let configPath = WorkOpenCodeRuntime.writeFusionConfig(configJSON) {
                environment["OPENCODE_CONFIG"] = configPath
                environment["EPISTEMOS_VAULT_ROOT"] = workspace.path
            }
        }
        return WorkShellLaunchSpec(
            executableURL: runtimeURL,
            arguments: [],   // bare `opencode` launches the TUI in the cwd
            workingDirectory: workspace,
            environment: environment
        )
    }
}
