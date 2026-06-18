import SwiftUI

/// P5.H A1 (EML-2, visible determinism) — read-only row showing whether the
/// ConfidenceRouter EML route fusion is active. Reads the SAME function the
/// router consults (`ConfidenceRouter.emlRouteFusionEnabled()`), so it never
/// claims a fusion the router isn't applying. Sibling to EmlRerankGateHealthRow
/// (the EML-3 retrieval surface) and DeterministicSchemaGateHealthRow.
public struct EmlRouteFusionHealthRow: View {
    public init() {}

    private var isActive: Bool { ConfidenceRouter.emlRouteFusionEnabled() }

    public var body: some View {
        let active = isActive
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: active ? "arrow.triangle.branch.circle.fill" : "arrow.triangle.branch.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(active ? Color.green : Color.secondary)
                Text(active ? "EML route fusion: ON" : "EML route fusion: off (opt-in)")
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(active
                 ? "Local-vs-cloud routing fuses confidence × complexity-headroom into one EML energy (1/(confidence+ε) − ln(headroom+1)); a request that scrapes past every individual gate but is jointly weak on BOTH axes defers to cloud. Byte-identical to the Rust vault re-rank key."
                 : "Set EPISTEMOS_EML_ROUTE_V1=1 to add the fused confidence×complexity confirmation to local-agent routing. Off by default → routing is unchanged.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
