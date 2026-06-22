import SwiftUI

// Visible gate surface for the WORK = OpenCode shell seam (rule #8 — the owner can
// SEE it). ALWAYS-compiled; renders the honest WorkOpenCodeShellGateStatus (incl.
// "Pro only" on the MAS build) plus the seam's HONEST readiness (false until the
// native terminal view + Bun engine + vendored OpenCode land). Mirrors
// WorkBackendHealthRow / ActOsaurusHealthRow.
struct WorkOpenCodeShellHealthRow: View {
    private var status: WorkOpenCodeShellGateStatus.Status { WorkOpenCodeShellGateStatus.status() }
    private var shellReady: Bool { WorkOpenCodeShellFactory.resolve().isReady }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.isActive ? "terminal.fill" : "terminal")
                    .foregroundStyle(status.isActive ? Color.green : Color.secondary)
                // Motion triad — the WORK status TITLE gets the FULL ontology (ASCII typewriter + blur),
                // strongest in WORK/OpenCode (owner 2026-06-21 §329). Reusable MotionTitle, font-adaptive
                // (callout), display-only, reduce-motion-safe.
                MotionTitle(text: status.headline, font: .callout.weight(.medium),
                            color: status.isActive ? .green : .secondary)
                Spacer(minLength: 0)
            }
            Text(status.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // HONEST runtime state: even when the gate is ARMED, the shell is INERT
            // until the terminal view + Bun engine + OpenCode vendor land. Never says
            // "live" for the inert seam.
            if status.isActive {
                Text(shellReady
                     ? "Shell runtime: live (OpenCode TUI + Bun engine present)."
                     : "Shell runtime: armed but INERT — native terminal view, lazy Bun engine, and vendored OpenCode TUI are the follow-on. No fake terminal is shown.")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
