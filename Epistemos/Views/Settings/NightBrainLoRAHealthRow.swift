import SwiftUI

/// DATA + FINETUNE part (4) visible surface — read-only row showing whether Night
/// Brain's native idle LoRA fine-tune is armed. Reads `NightBrainLoRAGateStatus`
/// (the SAME flag the idle decision reads), so it never claims a capability the
/// runtime isn't offering. Sibling to DeepResearchHealthRow / EmlRerankGateHealthRow.
public struct NightBrainLoRAHealthRow: View {
    public init() {}

    private var status: NightBrainLoRAGateStatus.Status { NightBrainLoRAGateStatus.status() }

    public var body: some View {
        let status = status
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.isActive ? "moon.stars.fill" : "moon.stars")
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
