import SwiftUI

/// PER-CLONE SETTINGS (owner 2026-06-21) — the "Act (Osaurus)" clone's settings surface, reskinned to
/// the app's settings chrome. Act = the full Osaurus engine (OsaurusCore, in-process). This panel
/// surfaces the clone's gate + REAL engine status (`ActOsaurusHealthRow` shows OsaurusCore's live
/// `CoreModelService` status) + how to arm it. The act MODEL selection — incl. the owner's "Epistemos
/// Picks" — lives under Models (shared composer). First per-clone tab; work = OpenCode is next.
/// Standing rule: each clone is its OWN app with its OWN settings — preserved + reachable, not flattened.
struct ActCloneSettingsView: View {
    var body: some View {
        Form {
            Section {
                SettingsDescriptionText(
                    text: "Act runs through the full Osaurus engine in-process (OsaurusCore) — this is Osaurus's "
                    + "own settings surface, reskinned to Epistemos. Arm the act-Osaurus path with "
                    + "EPISTEMOS_ACT_OSAURUS_V0=1 on the Pro / direct-distribution build; the runtime stays "
                    + "honest (no silent cloud route) until it is armed."
                )
                ActOsaurusHealthRow()
            } header: {
                Text("Act = Osaurus engine")
            } footer: {
                Text("Each clone keeps its own settings (work = OpenCode is next). Model selection, including your “Epistemos Picks”, is under Models.")
            }
        }
        .formStyle(.grouped)
    }
}
