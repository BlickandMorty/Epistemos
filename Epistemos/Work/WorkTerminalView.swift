import SwiftUI
// SwiftTerm (the real PTY terminal view) is Pro-only — it is not linked into the
// App Store (MAS) target, so the import + the NSViewRepresentable that uses
// LocalProcessTerminalView are guarded. On MAS the host falls to the honest
// unavailable view (full-capability terminal is a direct-distribution feature).
#if !EPISTEMOS_APP_STORE
import SwiftTerm
#endif

// WORK = OpenCode shell — the NATIVE terminal view (owner 2026-06-21, Option A).
// Renders OpenCode's REAL terminal TUI in a native macOS terminal emulator
// (SwiftTerm's LocalProcessTerminalView + a real PTY) — NOT an Electron/Tauri web
// GUI, NOT a native rebuild. Themed to the app's flat token-driven monospace discipline.
// Driven by the Seam-A WorkShellLaunchSpec (executable/args/cwd/env) — today the
// inert seam yields no spec, so the host shows an honest placeholder; the EARLY
// de-risk smoke path (owner's named open risk: "can the terminal view render
// natively?") spawns the login shell to prove the native PTY path end-to-end.
// When the OpenCode TUI + lazy Bun engine land, the live shell's launchSpec simply
// points `executable` at `opencode` — this view is unchanged.

#if os(macOS)

/// THEME-RESPONSIVE WORK terminal palette (owner 2026-06-21 §162: "OpenCode must be fully
/// theme-responsive — match EVERY app theme AND respond LIVE to theme changes, incl. custom").
/// Derived from the live `EpistemosTheme` so the terminal tracks the same tokens as the rest of
/// the app; rebuilt on every theme change (UIState is @Observable → the host re-renders → the NSView
/// re-applies). Monospace is kept (a terminal is monospace by definition) but its color follows the
/// theme. A system-color default is provided only as a non-themed fallback for previews/safety.
struct WorkTerminalPalette: Equatable {
    let background: NSColor
    let foreground: NSColor
    let cursor: NSColor
    let font: NSFont

    /// System-color fallback used only when no Epistemos theme is available.
    static let `default` = WorkTerminalPalette(
        background: .textBackgroundColor,
        foreground: .labelColor,
        cursor: .controlAccentColor,
        font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    )

    /// Map the live app theme → terminal colors. The terminal background/foreground follow the
    /// theme's own background/foreground tokens; the cursor follows the accent — so a custom theme
    /// (any palette) drives the terminal too.
    static func from(theme: EpistemosTheme) -> WorkTerminalPalette {
        WorkTerminalPalette(
            background: theme.resolved.background.nsColor,
            foreground: theme.resolved.foreground.nsColor,
            cursor: theme.resolved.accent.nsColor,
            font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        )
    }
}

/// SwiftTerm wants the environment as `["KEY=VALUE"]`, not a dictionary. Pure +
/// deterministically ordered so it's unit-testable without an NSView. Falls back to
/// the process environment when the spec carries none (a bare PTY still needs PATH/HOME).
func workShellEnvironmentArray(_ environment: [String: String]) -> [String] {
    let merged = environment.isEmpty ? ProcessInfo.processInfo.environment : environment
    return merged
        .sorted { $0.key < $1.key }
        .map { "\($0.key)=\($0.value)" }
}

extension WorkShellLaunchSpec {
    /// EARLY de-risk spec (owner's named open risk): the user's login shell rooted at
    /// `workspace`. Proves the native terminal view renders a real PTY before the
    /// OpenCode TUI is vendored. Opt-in only (never the default surface).
    static func smokeLoginShell(workspace: URL) -> WorkShellLaunchSpec {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        return WorkShellLaunchSpec(
            executableURL: URL(fileURLWithPath: shell),
            arguments: ["-l"],
            workingDirectory: workspace,
            environment: [:]   // inherit the process env for a bare smoke shell
        )
    }
}

/// The native terminal NSView, THEME-RESPONSIVE, that spawns the launch spec's process in a PTY.
/// The palette is re-applied on every SwiftUI update so a LIVE theme change (incl. custom) recolors
/// the running terminal without relaunching the process (owner 2026-06-21 §162).
#if !EPISTEMOS_APP_STORE
struct WorkTerminalView: NSViewRepresentable {
    let spec: WorkShellLaunchSpec
    let palette: WorkTerminalPalette

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let term = LocalProcessTerminalView(frame: .zero)
        applyPalette(palette, to: term)
        term.startProcess(
            executable: spec.executableURL.path,
            args: spec.arguments,
            environment: workShellEnvironmentArray(spec.environment),
            execName: nil,
            currentDirectory: spec.workingDirectory.path
        )
        return term
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Re-apply the (possibly changed) theme palette LIVE — recolors the running PTY in place.
        // The PTY process owns its own lifecycle; only the colors/font follow the theme.
        applyPalette(palette, to: nsView)
    }

    private func applyPalette(_ palette: WorkTerminalPalette, to term: LocalProcessTerminalView) {
        term.nativeBackgroundColor = palette.background
        term.nativeForegroundColor = palette.foreground
        term.caretColor = palette.cursor
        term.font = palette.font
    }
}
#endif

/// The honest host: picks the REAL Work shell when it's wired, the opt-in smoke
/// shell when armed for the early de-risk, otherwise an honest placeholder — it NEVER
/// shows a fake terminal. This is the single switch the live runtime flips.
struct WorkTerminalHostView: View {
    /// Workspace the work session is rooted at (the open vault/project dir) — the shell cwd.
    let workspace: URL
    /// The Epistemos APP VAULT the fusion MCP server roots at, so the work agent sees the
    /// app's vault notes + `skills/` as first-class MCP context (0.49b). nil → no active
    /// vault, so fusion is omitted honestly rather than silently using an empty default.
    var epistemosVaultRoot: URL? = nil

    // Live app theme — reading it makes the terminal recolor on EVERY theme change (incl. custom),
    // since UIState is @Observable (owner 2026-06-21 §162, fully theme-responsive).
    @Environment(UIState.self) private var ui

    private var gate: WorkOpenCodeShellGateStatus.Status { WorkOpenCodeShellGateStatus.status() }
    private var shell: WorkOpenCodeShell { WorkOpenCodeShellFactory.resolve() }
    private var smokeEnabled: Bool {
        WorkOpenCodeShellGateStatus.isEnabled(ProcessInfo.processInfo.environment["EPISTEMOS_WORK_TERMINAL_SMOKE"])
    }
    private var palette: WorkTerminalPalette { WorkTerminalPalette.from(theme: ui.theme) }

    // 0.46 (slow-start hardening): cache the resolved live launch spec so it is computed ONCE per workspace
    // off the synchronous render path — NOT on every `body` evaluation. Previously `try? realShellSpec()` ran
    // in `body`, so each theme/palette re-render redid `launchSpec` → `writeMergedFusionConfig` (read + JSON
    // parse + merge + atomic disk write) on the MainActor. That repeated main-thread I/O is gone; the work
    // surface also now shows an honest "starting" state while the spec resolves instead of a blank/placeholder.
    @State private var resolvedSpec: WorkShellLaunchSpec?
    @State private var resolvedForWorkspace: URL?
    @State private var resolveError: String?

    var body: some View {
        #if !EPISTEMOS_APP_STORE
        Group {
            if let spec = resolvedSpec {
                WorkTerminalView(spec: spec, palette: palette)
                    // 0.48b-part2: a REAL work session just launched → record it as a "worker" row in the unified
                    // recent-chats store so it shows in the popover's Work section + can be reopened. Marker only
                    // (PTY has no message thread); keyed by workspace path so re-opening updates one row.
                    .onAppear { persistWorkSessionMarker() }
            } else if smokeEnabled {
                // Owner's EARLY de-risk: a real login-shell PTY in the themed native view.
                WorkTerminalView(spec: .smokeLoginShell(workspace: workspace), palette: palette)
            } else if let resolveError {
                WorkTerminalUnavailableView(detail: resolveError, palette: palette)
            } else if shell.isReady {
                // Live shell IS ready; the spec (incl. the one-time fusion-config write) is resolving off the
                // render path — show an honest "starting" state, not the not-wired placeholder. 0.46.
                WorkTerminalStartingView(palette: palette)
            } else {
                WorkTerminalUnavailableView(detail: gate.detail, palette: palette)
            }
        }
        .task(id: workspace) {
            // Resolve the live launch spec ONCE per workspace (this is where the fusion-config disk write
            // happens now — not per render). Re-resolve only when the workspace actually changes.
            if resolvedSpec == nil || resolvedForWorkspace != workspace {
                resolvedForWorkspace = workspace
                resolveError = nil
                do {
                    resolvedSpec = try await realShellSpec()
                } catch {
                    resolvedSpec = nil
                    resolveError = WorkServerDiagnostics.statusMessage(
                        for: error,
                        fallback: "Couldn't start Epistemos Work terminal"
                    )
                }
            }
        }
        #else
        // MAS: the SwiftTerm-backed PTY view is Pro-only — show the honest
        // unavailable placeholder (never a faked terminal).
        WorkTerminalUnavailableView(detail: gate.detail, palette: palette)
        #endif
    }

    /// 0.48b-part2: upsert the opened work session into the unified SDChat recent-chats store (Work section).
    private func persistWorkSessionMarker() {
        let name = workspace.lastPathComponent
        let title = name.isEmpty ? "Work" : "Work · \(name)"
        AppBootstrap.shared?.persistWorkSession(id: "work:\(workspace.path)", title: title)
    }

    /// The live OpenCode launch spec — nil/throws until the runtime is wired (honest). (c2, 2026-06-24): starts
    /// the app-hosted native-tools MCP server BEFORE OpenCode config generation and passes its loopback
    /// registration so the generated config asserts `epistemos-native` (the FULL native tool surface). nil
    /// (server can't bind / not ready) → `epistemos-native` is honestly omitted; the shell still launches.
    private func realShellSpec() async throws -> WorkShellLaunchSpec {
        guard shell.isReady else { throw WorkShellError.notWired("inert") }
        let nativeMCP = await WorkNativeMCPHost.shared.startAndAwaitRegistration(vaultRoot: epistemosVaultRoot)
        return try shell.launchSpec(
            workspace: workspace, epistemosVaultRoot: epistemosVaultRoot, nativeMCP: nativeMCP)
    }
}

/// Honest transient state while the live work shell's launch spec resolves (0.46) — immediate themed feedback
/// instead of a blank surface, so opening Work never looks frozen during the one-time spec resolution.
struct WorkTerminalStartingView: View {
    let palette: WorkTerminalPalette

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(Color(nsColor: palette.foreground))
            Text("Starting work terminal…")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color(nsColor: palette.foreground).opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: palette.background))
    }
}

/// Honest placeholder shown when no real terminal can launch — theme-driven, never faked.
struct WorkTerminalUnavailableView: View {
    let detail: String
    let palette: WorkTerminalPalette

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundStyle(Color(nsColor: palette.foreground).opacity(0.55))
            Text("Epistemos Work terminal unavailable")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color(nsColor: palette.foreground))
                .motionReveal()  // motion triad: display-only title
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color(nsColor: palette.foreground).opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: palette.background))
    }
}

#endif
