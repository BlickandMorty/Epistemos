import SwiftUI

/// PER-CLONE SETTINGS (owner 2026-06-21) — the "Work (OpenCode)" clone's settings surface, reskinned to
/// the app's settings chrome. Work = the full OpenCode shell (real terminal TUI in a native terminal
/// view, Option A) with Goose/Hermes/OpenClaw fused beneath. This panel surfaces the clone's gates +
/// REAL seam status (`WorkOpenCodeShellHealthRow` = the OpenCode shell seam; `WorkBackendHealthRow` = the
/// Goose engine seam) AND mounts the actual native terminal host (`WorkTerminalHostView`) so the terminal
/// infrastructure is REACHABLE, not a dead component — it shows an honest placeholder until armed, and a
/// real PTY when the smoke/runtime is present. Second per-clone tab (after "Act (Osaurus)").
/// Standing rule: each clone is its OWN app with its OWN settings — preserved + reachable, not flattened.
struct WorkCloneSettingsView: View {
    /// The workspace the work terminal roots at — the user's home by default (the smoke shell / OpenCode
    /// TUI launches here). A real work session passes the open vault/project dir.
    private var workspaceURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    var body: some View {
        Form {
            Section {
                SettingsDescriptionText(
                    text: "Work runs OpenCode's real terminal TUI in a native terminal view (Option A — the "
                    + "real terminal UI, not a web GUI), with Goose/Hermes/OpenClaw fused beneath and the "
                    + "in-process RustLSP wired as code-intelligence tools. Arm the shell with "
                    + "EPISTEMOS_WORK_OPENCODE_V0=1 on the Pro / direct-distribution build; it stays honestly "
                    + "INERT until the OpenCode runtime is bundled (no fake terminal)."
                )
                WorkOpenCodeShellHealthRow()
                WorkBackendHealthRow()
            } header: {
                Text("Work = OpenCode shell")
            } footer: {
                Text("Each clone keeps its own settings. The Goose engine fuses beneath the OpenCode shell; one runtime of record per mode.")
            }

            #if os(macOS)
            Section {
                WorkTerminalHostView(workspace: workspaceURL)
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } header: {
                Text("Native terminal")
            } footer: {
                Text("The real native terminal view (SwiftTerm/PTY). Shows an honest placeholder until armed; set EPISTEMOS_WORK_TERMINAL_SMOKE=1 to preview a real login-shell PTY in the themed terminal.")
            }
            #endif
        }
        .formStyle(.grouped)
    }
}
