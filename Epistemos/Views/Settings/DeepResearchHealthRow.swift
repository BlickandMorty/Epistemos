import SwiftUI

/// DeerFlow slice 5b (visible surface) — read-only row showing whether the
/// multi-agent deep-research run is armed. Reads `DeepResearchGateStatus`, which
/// mirrors the SAME env flag the in-process Rust `deep_research` reads, so it
/// never claims a capability the runtime isn't offering. Sibling to
/// EmlRerankGateHealthRow / DeterministicSchemaGateHealthRow.
public struct DeepResearchHealthRow: View {
    public init() {}

    private var status: DeepResearchGateStatus.Status { DeepResearchGateStatus.status() }

    public var body: some View {
        let status = status
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.isActive ? "person.3.sequence.fill" : "person.3.sequence")
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
