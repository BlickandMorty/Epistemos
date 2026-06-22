import SwiftUI

// Visible gate surface for the Osaurus Act seam (rule #8 — the owner can SEE it).
// ALWAYS-compiled; renders the honest ActOsaurusGateStatus (incl. "Pro only" on the
// MAS build). Mirrors NightBrainLoRAHealthRow / DeepResearchHealthRow.
struct ActOsaurusHealthRow: View {
    private var status: ActOsaurusGateStatus.Status { ActOsaurusGateStatus.status() }
    @State private var osaurusCoreStatus: String?
    // In-app toggle state (owner §806). Seeded from the resolved arm-state so the switch reflects reality on
    // open; flipping it writes the UserDefaults override the router resolves — act switches live, no relaunch.
    @State private var actOsaurusOn: Bool = ActOsaurusGateStatus.resolvedActive()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.isActive ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
                    .foregroundStyle(status.isActive ? Color.green : Color.secondary)
                Text(status.headline)
                    .font(.callout.weight(.medium))
                    .motionReveal()  // motion triad: blur-reveal on a display-only title (owner 2026-06-21)
                Spacer(minLength: 0)
            }
            Text(status.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            #if !EPISTEMOS_APP_STORE
            // Owner §806: the EASY in-app toggle so Act-through-Osaurus can be experienced without setting an
            // env var + relaunching. Writes the gate override (override > env > off); the router resolves it
            // live so flipping this switches Act for the next turn. Pro builds only (Osaurus is Pro-gated).
            Toggle(isOn: Binding(
                get: { actOsaurusOn },
                set: { newValue in
                    actOsaurusOn = newValue
                    ActOsaurusGateStatus.setOverride(newValue)
                }
            )) {
                Text("Use Osaurus for Act (experimental)")
                    .font(.caption.weight(.medium))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.top, 2)

            // Pro builds only: when both the Act-Osaurus flag AND the osaurus-pattern
            // local server are enabled, show the REAL OpenAI-compatible endpoint Act
            // would drive (honest — never shown unless the server is actually enabled).
            if status.isActive, let endpoint = ActOsaurusBridgeFactory.resolve().openAICompatibleEndpoint {
                Text("OpenAI-compatible endpoint: \(endpoint.absoluteString)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            // REAL linked-OsaurusCore engine status (CoreModelService.resolveStatus) — the act
            // surface reflects the ACTUAL engine, not a stub. Hidden when OsaurusCore isn't linked.
            if let osaurusCoreStatus {
                Text(osaurusCoreStatus)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            #endif
        }
        #if !EPISTEMOS_APP_STORE
        .task { osaurusCoreStatus = await ActOsaurusBridgeFactory.resolve().osaurusCoreStatusDescription() }
        #endif
    }
}
