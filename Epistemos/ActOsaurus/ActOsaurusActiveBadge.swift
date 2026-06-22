import SwiftUI

/// P0-B (owner 2026-06-22): a VISIBLE, CLICKABLE indicator that the act surface is
/// genuinely powered by the Osaurus engine. After the option-(b) pivot the old UI
/// looked identical, so the owner felt Osaurus was "gone" — this surfaces it (and
/// begins "bring Osaurus's controls into the old UI"). Shown ONLY when act actually
/// routes through Osaurus (`shouldRouteActThroughOsaurus`, Pro; honest — never on
/// the MAS/old-MLX path). Clicking opens an engine panel showing the LIVE Osaurus
/// status (`CoreModelService.resolveStatus()` via the bridge: unset / unavailable +
/// reason / available + model) — visible Osaurus presence + the P0-A diagnostic in
/// one place. The fuller set of Osaurus's distinctive controls is the larger follow-on.
struct ActOsaurusActiveBadge: View {
    @State private var engineStatus: String?
    @State private var showPanel = false

    var body: some View {
        Button {
            showPanel.toggle()
        } label: {
            Label("Osaurus", systemImage: "bolt.horizontal.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
        .help("Act is powered by the Osaurus engine — click for the live engine status.")
        .accessibilityLabel("Osaurus engine — act is Osaurus-powered")
        .popover(isPresented: $showPanel, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Osaurus engine", systemImage: "bolt.horizontal.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(engineStatus ?? "Resolving engine status…")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Act runs on the Osaurus engine with your selected model.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: 340, alignment: .leading)
        }
        .task {
            engineStatus = await ActOsaurusBridgeFactory.resolve().osaurusCoreStatusDescription()
        }
    }
}
