import SwiftUI

// Visible gate surface for the Work backend seam.
// ALWAYS-compiled; renders the honest WorkBackendGateStatus (incl. "Pro only" on
// the MAS build).
struct WorkBackendHealthRow: View {
    private var status: WorkBackendGateStatus.Status { WorkBackendGateStatus.status() }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.isActive ? "hammer.circle.fill" : "hammer.circle")
                    .foregroundStyle(status.isActive ? Color.green : Color.secondary)
                // Motion triad — the secondary work-engine status TITLE gets the same ASCII-typewriter+blur
                // ontology as its OpenCode shell sibling (both work seams consistent; strongest in WORK,
                // owner 2026-06-21 §329). Tasteful: the two work-status titles, not a broad sweep.
                MotionTitle(text: status.headline, font: .callout.weight(.medium),
                            color: status.isActive ? .green : .secondary)
                Spacer(minLength: 0)
            }
            Text(status.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
