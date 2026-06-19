import SwiftUI

// Visible gate surface for the Osaurus Act seam (rule #8 — the owner can SEE it).
// ALWAYS-compiled; renders the honest ActOsaurusGateStatus (incl. "Pro only" on the
// MAS build). Mirrors NightBrainLoRAHealthRow / DeepResearchHealthRow.
struct ActOsaurusHealthRow: View {
    private var status: ActOsaurusGateStatus.Status { ActOsaurusGateStatus.status() }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.isActive ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
                    .foregroundStyle(status.isActive ? Color.green : Color.secondary)
                Text(status.headline)
                    .font(.callout.weight(.medium))
                Spacer(minLength: 0)
            }
            Text(status.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            #if !EPISTEMOS_APP_STORE
            // Pro builds only: when both the Act-Osaurus flag AND the osaurus-pattern
            // local server are enabled, show the REAL OpenAI-compatible endpoint Act
            // would drive (honest — never shown unless the server is actually enabled).
            if status.isActive, let endpoint = ActOsaurusBridgeFactory.resolve().openAICompatibleEndpoint {
                Text("OpenAI-compatible endpoint: \(endpoint.absoluteString)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            #endif
        }
    }
}
