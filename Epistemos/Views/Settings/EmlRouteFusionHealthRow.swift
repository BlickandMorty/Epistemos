import SwiftUI

/// P5.H A1 (EML-2) — read-only row for the EML route-fusion primitive. HONEST
/// STATUS: the fusion lives in `ConfidenceRouter.route()`, which is a tested but
/// LEGACY surface — never instantiated in production (the live route decision is
/// `TriageService.InferencePolicyEngine.shouldAutoRouteToCloud`, which is
/// complexity-only with no confidence signal to fuse). So the flag arms a
/// tested, parity-locked primitive that is NOT yet wired into the live path — it
/// has no runtime routing effect today. This row says exactly that rather than
/// claim a fusion the runtime isn't doing. (EML-3 retrieval re-rank IS live —
/// see EmlRerankGateHealthRow; this EML-2 routing primitive awaits a live seam.)
public struct EmlRouteFusionHealthRow: View {
    public init() {}

    private var armed: Bool { ConfidenceRouter.emlRouteFusionEnabled() }

    public var body: some View {
        let armed = armed
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(armed ? "EML route fusion: armed (not yet live)" : "EML route fusion: tested primitive (off)")
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(armed
                 ? "EPISTEMOS_EML_ROUTE_V1 is set, but the fusion lives in ConfidenceRouter — a tested, parity-locked primitive (confidence×complexity → one EML energy) that is NOT yet wired into the live route decision (TriageService is complexity-only). No runtime routing effect until a confidence signal + live seam land."
                 : "A tested, parity-locked confidence×complexity routing primitive (ConfidenceRouter), not yet in the live route path (TriageService). EPISTEMOS_EML_ROUTE_V1 arms it but has no runtime effect until wired.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
