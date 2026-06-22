import SwiftUI

/// P0-B (owner 2026-06-22): a VISIBLE indicator that the act surface is genuinely
/// powered by the Osaurus engine. After the option-(b) pivot the old UI looked
/// identical, so the owner felt Osaurus was "gone" — this surfaces it. Shown only
/// when act ACTUALLY routes through Osaurus (`shouldRouteActThroughOsaurus`, Pro;
/// honest — never claims Osaurus on the MAS/old-MLX path). The tooltip carries the
/// LIVE OsaurusCore engine status (`CoreModelService.resolveStatus()` via the
/// bridge), which doubles as the P0-A diagnostic (unset / unavailable + reason /
/// available). This is the indicator step of P0-B; bringing Osaurus's distinctive
/// controls/landing into the old UI is the larger follow-on.
struct ActOsaurusActiveBadge: View {
    @State private var engineStatus: String?

    var body: some View {
        Label("Osaurus", systemImage: "bolt.horizontal.circle.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .help(engineStatus ?? "Act is powered by the Osaurus engine.")
            .accessibilityLabel("Act is powered by Osaurus")
            .task {
                engineStatus = await ActOsaurusBridgeFactory.resolve().osaurusCoreStatusDescription()
            }
    }
}
