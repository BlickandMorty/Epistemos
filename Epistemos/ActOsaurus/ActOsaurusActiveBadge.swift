import SwiftUI
// OsaurusCore is Pro-only — guard the import with the BUILD-CONFIG condition (bare
// `canImport` can be true on MAS via shared DerivedData; the badge is hidden on MAS
// anyway). Used only to read the owner's registered Osaurus model stack.
#if !EPISTEMOS_APP_STORE
import OsaurusCore
#endif

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
    @State private var osaurusModels: [String] = []
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

                if !osaurusModels.isEmpty {
                    Divider()
                    // P0-B model stack: the owner's models that the Osaurus engine can
                    // serve in act (registered through the model bridge).
                    Text("Your Osaurus models (\(osaurusModels.count))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(osaurusModels.prefix(8), id: \.self) { id in
                        Text("• \(id)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: 340, alignment: .leading)
        }
        .task {
            // OsaurusCore engine status is a Pro-only seam (ActOsaurusBridgeFactory
            // lives inside `#if !EPISTEMOS_APP_STORE`). On MAS the badge is never shown
            // anyway (gated on shouldRouteActThroughOsaurus), so skip the fetch there
            // and keep the struct compiling on the App Store target.
            #if !EPISTEMOS_APP_STORE
            engineStatus = await ActOsaurusBridgeFactory.resolve().osaurusCoreStatusDescription()
            osaurusModels = EpistemosModelBridge.providedModelIds()
            #endif
        }
    }
}
