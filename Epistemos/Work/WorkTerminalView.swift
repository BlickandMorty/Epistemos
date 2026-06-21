import SwiftUI
import SwiftTerm

// WORK = OpenCode shell — the NATIVE terminal view (owner 2026-06-21, Option A).
// Renders OpenCode's REAL terminal TUI in a native macOS terminal emulator
// (SwiftTerm's LocalProcessTerminalView + a real PTY) — NOT an Electron/Tauri web
// GUI, NOT a native rebuild. Themed to the app's cream/ink monospace discipline.
// Driven by the Seam-A WorkShellLaunchSpec (executable/args/cwd/env) — today the
// inert seam yields no spec, so the host shows an honest placeholder; the EARLY
// de-risk smoke path (owner's named open risk: "can the terminal view render
// natively?") spawns the login shell to prove the native PTY path end-to-end.
// When the OpenCode TUI + lazy Bun engine land, the live shell's launchSpec simply
// points `executable` at `opencode` — this view is unchanged.

#if os(macOS)

/// The app's WORK terminal palette — cream paper + ink, monospace — matching the
/// chat-reskin discipline (the full theme-responsive pass is a tracked follow-on).
enum WorkTerminalTheme {
    static let background = NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.92, alpha: 1.0) // cream paper
    static let foreground = NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.11, alpha: 1.0) // ink
    static let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
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

/// The native terminal NSView, themed, that spawns the launch spec's process in a PTY.
struct WorkTerminalView: NSViewRepresentable {
    let spec: WorkShellLaunchSpec

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let term = LocalProcessTerminalView(frame: .zero)
        term.nativeBackgroundColor = WorkTerminalTheme.background
        term.nativeForegroundColor = WorkTerminalTheme.foreground
        term.font = WorkTerminalTheme.font
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
        // The PTY process owns its own lifecycle; nothing to push on SwiftUI updates.
    }
}

/// The honest host: picks the REAL OpenCode shell when it's wired, the opt-in smoke
/// shell when armed for the early de-risk, otherwise an honest placeholder — it NEVER
/// shows a fake terminal. This is the single switch the live runtime flips.
struct WorkTerminalHostView: View {
    /// Workspace the work session is rooted at (the open vault/project dir).
    let workspace: URL

    private var gate: WorkOpenCodeShellGateStatus.Status { WorkOpenCodeShellGateStatus.status() }
    private var shell: WorkOpenCodeShell { WorkOpenCodeShellFactory.resolve() }
    private var smokeEnabled: Bool {
        WorkOpenCodeShellGateStatus.isEnabled(ProcessInfo.processInfo.environment["EPISTEMOS_WORK_TERMINAL_SMOKE"])
    }

    var body: some View {
        if let liveSpec = try? realShellSpec() {
            WorkTerminalView(spec: liveSpec)
        } else if smokeEnabled {
            // Owner's EARLY de-risk: a real login-shell PTY in the themed native view.
            WorkTerminalView(spec: .smokeLoginShell(workspace: workspace))
        } else {
            WorkTerminalUnavailableView(detail: gate.detail)
        }
    }

    /// The live OpenCode launch spec — nil/throws until the runtime is wired (honest).
    private func realShellSpec() throws -> WorkShellLaunchSpec {
        guard shell.isReady else { throw WorkShellError.notWired("inert") }
        return try shell.launchSpec(workspace: workspace)
    }
}

/// Honest placeholder shown when no real terminal can launch — themed, never faked.
struct WorkTerminalUnavailableView: View {
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Work terminal not wired yet")
                .font(.callout.weight(.medium))
                .motionReveal()  // motion triad: display-only title
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: WorkTerminalTheme.background))
    }
}

#endif
