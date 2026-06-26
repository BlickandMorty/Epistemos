import SwiftUI

// Visible status surface for WORK = OpenCode (rule #8 — the owner can SEE it).
// ALWAYS-compiled. Work is the REAL surface now (owner 2026-06-22, parallel to
// Act): no experimental opt-in toggle — the shell goes live whenever the
// OpenCode runtime is bundled (it is, via build-opencode-runtime.sh). This row
// reports the HONEST live/inert state from the ACTUAL factory resolution, not a gate.
struct WorkOpenCodeShellHealthRow: View {
    private var shellReady: Bool { WorkOpenCodeShellFactory.resolve().isReady }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: shellReady ? "terminal.fill" : "terminal")
                    .foregroundStyle(shellReady ? Color.green : Color.secondary)
                // Motion triad — the WORK status TITLE gets the FULL ontology (ASCII typewriter + blur),
                // strongest in WORK/OpenCode (owner 2026-06-21 §329). Display-only, reduce-motion-safe.
                MotionTitle(
                    text: shellReady ? "Epistemos Work: runtime live" : "Epistemos Work: runtime not bundled",
                    font: .callout.weight(.medium),
                    color: shellReady ? .green : .secondary
                )
                Spacer(minLength: 0)
            }
            // HONEST runtime state from the real factory — no gate, no opt-in. Live = the vendored OpenCode TUI
            // + Bun engine are bundled in Resources; inert = the runtime isn't linked on this build (the App
            // Store sandbox is Pro-gated for the SwiftTerm terminal + the runtime). Never "live" when inert.
            Text(shellReady
                 ? "The bundled default runtime is live. Work stays inside Epistemos chrome and keeps the app's vault/tool context."
                 : "The bundled runtime isn't linked on this build (App Store / MAS is Pro-gated for the SwiftTerm terminal + runtime). Epistemos Work stays honestly inert — no fake terminal.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
