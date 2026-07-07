import Foundation

// WORK = OpenCode shell — Seam A contract (owner 2026-06-21). The seam the native
// terminal view drives against to launch the REAL OpenCode TUI in a PTY. Pure +
// ALWAYS-compiled (no SwiftTerm / PTY / OpenCode dependency here) so it links on
// every build; the heavy runtime (SwiftTerm terminal view, lazy Bun engine,
// vendored OpenCode) plugs into this contract behind the Pro gate. Mirrors the
// ActOsaurusBridge / WorkBackend seam shape: an honest-inert default that NEVER
// fakes a terminal, and a `live` flag that is true only when a real shell can launch.

/// What the native terminal view needs to spawn the OpenCode TUI in a PTY: the
/// executable, its arguments, the workspace cwd, and the environment (which will
/// carry the loopback Bun-engine endpoint once the lazy launcher lands). A pure
/// value type — no process is started by constructing it.
struct WorkShellLaunchSpec: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let workingDirectory: URL
    let environment: [String: String]
}

enum WorkShellError: Error, Equatable {
    /// The shell is not wired/armed — returned instead of faking a terminal.
    case notWired(String)
    /// The OpenCode binary / Bun engine is not present on disk yet.
    case runtimeMissing(String)
}

/// The seam WORK mode's native terminal view drives against. `isReady` is an HONEST
/// gate — true only when a real OpenCode shell can actually launch; the inert seam
/// reports false and refuses, it never returns a bogus launch spec.
protocol WorkOpenCodeShell: Sendable {
    /// True only when a real OpenCode TUI + Bun engine are present AND the seam is
    /// armed. Never reports ready for the inert seam.
    var isReady: Bool { get }
    /// The PTY launch spec for an OpenCode session rooted at `workspace` (the shell cwd).
    /// `epistemosVaultRoot` is the APP VAULT the fusion MCP server roots at (so the work
    /// agent sees the app's vault notes + `skills/` as first-class MCP context, 0.49b) —
    /// decoupled from the shell cwd. nil → NO active vault: the bundled shell OMITS fusion
    /// entirely (no OPENCODE_CONFIG / EPISTEMOS_VAULT_ROOT) so the MCP server honestly
    /// reports no vault — it NEVER silently roots at an empty default vault (owner 2026-06-24
    /// "make the no-vault state honest"; diag 8af17c841). Throws an HONEST WorkShellError
    /// when the shell is not wired or the runtime is absent — never a fake terminal.
    /// `nativeMCP` (W-R2/W-R3, 2026-06-24): when the app-hosted native-tools MCP server is live, its loopback
    /// registration so the bundled shell asserts `epistemos-native` in the OpenCode config (the FULL native tool
    /// surface incl. computer-use). nil → omitted (honest; OpenCode then sees only the `epistemos-vault` stdio
    /// server). Threaded but always nil until (c2) constructs+starts the server and supplies it at the call site.
    func launchSpec(
        workspace: URL, epistemosVaultRoot: URL?, nativeMCP: WorkNativeMCPRegistration?
    ) throws -> WorkShellLaunchSpec
}

extension WorkOpenCodeShell {
    /// Back-compatible convenience: no explicit app vault → NO fusion (the honest no-vault
    /// path; the bundled shell omits OPENCODE_CONFIG / EPISTEMOS_VAULT_ROOT rather than
    /// rooting at an empty default vault). Preserves the old call shape for the smoke shell + tests.
    func launchSpec(workspace: URL) throws -> WorkShellLaunchSpec {
        try launchSpec(workspace: workspace, epistemosVaultRoot: nil, nativeMCP: nil)
    }

    /// Back-compatible convenience for callers that don't (yet) supply a native-MCP registration — forwards
    /// `nativeMCP: nil` (the app-hosted MCP is omitted from the OpenCode config until (c2) wires it). Preserves
    /// the existing 2-arg call shape (WorkTerminalView.realShellSpec, tests).
    func launchSpec(workspace: URL, epistemosVaultRoot: URL?) throws -> WorkShellLaunchSpec {
        try launchSpec(workspace: workspace, epistemosVaultRoot: epistemosVaultRoot, nativeMCP: nil)
    }
}

/// The honest-inert default: reports not-ready and refuses to produce a launch spec.
/// The state until the OpenCode TUI + Bun engine are vendored and the native terminal
/// view is wired. Mirrors InertWorkBackend / InertActOsaurusBridge.
struct InertWorkOpenCodeShell: WorkOpenCodeShell {
    var isReady: Bool { false }

    func launchSpec(
        workspace: URL, epistemosVaultRoot: URL?, nativeMCP: WorkNativeMCPRegistration?
    ) throws -> WorkShellLaunchSpec {
        throw WorkShellError.notWired(
            "Epistemos Work runtime is unavailable on this build. No fake terminal is launched."
        )
    }
}

/// Resolves the active OpenCode shell seam. Honest by construction: returns the inert
/// shell unless the Pro build has both the flag armed AND (eventually) a real runtime.
/// Today it always returns inert — the live shell lands with the terminal view + Bun
/// launcher. Centralizing resolution here (mirrors ActOsaurusBridgeFactory) means the
/// follow-on wires ONE site, not every caller.
nonisolated enum WorkOpenCodeShellFactory {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> WorkOpenCodeShell {
        #if EPISTEMOS_APP_STORE
        return InertWorkOpenCodeShell()
        #else
        // WORK = OPENCODE IS THE WORK SURFACE (owner 2026-06-22, parallel to Act): NO experimental
        // opt-in toggle. Go LIVE whenever the OpenCode runtime is actually bundled on disk — which it is
        // (build-opencode-runtime.sh vendors the pinned OpenCode + Bun into Resources/opencode-runtime at build
        // time). The old experimental opt-in gate is no longer a precondition; work is the real surface, not an
        // opt-in. Honest fallback: if the runtime is somehow absent, stay inert (the
        // health row shows the placeholder) — never a fake terminal.
        _ = environment
        guard let runtimeURL = WorkOpenCodeRuntime.bundledRuntimeURL() else {
            return InertWorkOpenCodeShell()
        }
        return BundledWorkOpenCodeShell(runtimeURL: runtimeURL)
        #endif
    }
}
