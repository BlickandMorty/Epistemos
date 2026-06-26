import SwiftUI

/// Epistemos Work's integrated settings surface. Work = a full coding runtime in a native terminal view,
/// with engine layers fused beneath Epistemos chrome. This panel surfaces the runtime gates + REAL seam status and mounts
/// the actual native terminal host (`WorkTerminalHostView`) so the terminal
/// infrastructure is REACHABLE, not a dead component — it shows an honest placeholder until armed, and a
/// real PTY when the smoke/runtime is present. Engine-specific controls stay reachable from Epistemos Settings rather
/// than becoming a separate settings island.
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
                    text: "Epistemos Work runs the active coding runtime in native app chrome, with code-intelligence "
                    + "and app-tool bridges behind it. The Pro / direct-distribution build uses bundled runtimes when available; until then, "
                    + "the shell stays honestly inert rather than showing a fake terminal."
                )
                WorkOpenCodeShellHealthRow()
                WorkBackendHealthRow()
            } header: {
                Text("Epistemos Work runtime")
            } footer: {
                Text("Settings stay in Epistemos. Engine names stay in pickers and diagnostics; Epistemos owns the app tools, vault context, and native chrome.")
            }

            #if os(macOS)
            Section {
                WorkTerminalHostView(workspace: workspaceURL)
                    .frame(minHeight: 220)
                    .clipShape(Rectangle())
            } header: {
                Text("Native terminal")
            } footer: {
                Text("The native terminal host stays in place. It shows the themed runtime when available and an honest inactive state otherwise.")
            }
            #endif

            #if os(macOS)
            Section {
                Button("Open Epistemos Work preview") {
                    WorkWebSurfaceWindowController.shared.open()
                }
            } header: {
                Text("Work preview")
            } footer: {
                Text("A theme-aware native WebView preview over the local runtime supervisor. It shows an honest placeholder until the bundled Work surface is available.")
            }
            #endif

            #if os(macOS)
            Section {
                Button("Open Epistemos Work") {
                    WorkEngineSurfaceWindowController.shared.open()
                }
            } header: {
                Text("Epistemos Work")
            } footer: {
                Text("Pick an engine, create/send/stream a session, and keep recents, permissions, diffs, and Epistemos vault tools in native UI. Runtime identities stay in the picker and diagnostics.")
            }
            #endif
        }
        .formStyle(.grouped)
    }
}
