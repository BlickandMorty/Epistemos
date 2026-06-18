import SwiftUI

/// P5.H (visible determinism) — read-only row showing whether the EML vault
/// re-rank is enforcing the BM25+coverage fusion. Reads `EmlRerankGateStatus`,
/// which mirrors the SAME env flag the in-process Rust re-rank (vault.rs) reads,
/// so it never claims a re-rank the runtime isn't doing.
public struct EmlRerankGateHealthRow: View {
    public init() {}

    private var status: EmlRerankGateStatus.Status { EmlRerankGateStatus.status() }

    public var body: some View {
        let status = status
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.isActive ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(status.isActive ? Color.green : Color.secondary)
                Text(status.headline)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(status.detail)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
