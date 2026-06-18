import SwiftUI

/// P8.5 (visible determinism) — an honest, read-only row showing whether the
/// P8.1 deterministic schema gate is enforcing typed-schema validation of tool
/// calls. Reads `DeterministicSchemaGateStatus`, which mirrors the SAME env flag
/// the in-process Rust gate (`agent_core` ToolRegistry.execute) reads — so this
/// never claims enforcement the runtime isn't doing.
public struct DeterministicSchemaGateHealthRow: View {
    public init() {}

    private var status: DeterministicSchemaGateStatus.Status {
        DeterministicSchemaGateStatus.status()
    }

    public var body: some View {
        let status = status
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.isActive ? "checkmark.seal.fill" : "seal")
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
