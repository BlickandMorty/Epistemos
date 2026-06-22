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
}

/// The LIVE OpenCode work shell — resolves a real launch spec pointing at the bundled
/// `opencode` TUI rooted at the workspace. Only ever constructed when the runtime is
/// actually bundled (the factory checks), so `isReady` is honestly true here.
struct BundledWorkOpenCodeShell: WorkOpenCodeShell {
    let runtimeURL: URL

    var isReady: Bool { true }

    func launchSpec(workspace: URL) throws -> WorkShellLaunchSpec {
        WorkShellLaunchSpec(
            executableURL: runtimeURL,
            arguments: [],   // bare `opencode` launches the TUI in the cwd
            workingDirectory: workspace,
            environment: WorkOpenCodeRuntime.shellEnvironment(runtimeURL: runtimeURL)
        )
    }
}
