import SwiftUI

// DATA+FINETUNE part (5) MARKETPLACE — the BROWSE surface (rule #8: the owner can
// SEE the marketplace). Lists the available packs (honest gating via
// `FineTunePackRegistry.available`) grouped by kind, each showing source + license
// + gate badge, with an honest empty state. Import/apply is the follow-on (a LoRA
// pack reuses AdapterExporter; a dataset/instruction/knowledge pack feeds the native
// training-data / vault path). MAS-safe: packs are descriptors, never runtime code.
struct FineTuneMarketplaceView: View {

    private var registry: FineTunePackRegistry { FineTunePackCatalog.seededRegistry() }

    // Honest gating: Pro packs only appear in a Pro/dev build, never on the MAS
    // surface (owner #1 — never offer what can't run here).
    private var isPro: Bool {
        #if !EPISTEMOS_APP_STORE
        true
        #else
        false
        #endif
    }
    private var isDev: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    var body: some View {
        let available = registry.available(isPro: isPro, isDev: isDev)
        GroupBox("Data & Fine-Tune Marketplace") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Browse data + fine-tuning packs (datasets, LoRA adapters, instruction & knowledge packs). Each pack is a descriptor with a license and an honest availability gate — importing/applying is a separate, gated step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if available.isEmpty {
                    Text("No packs available here yet. First-party packs and any you import (through the ProvenanceGate) will appear here.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(FineTunePackKind.allCases, id: \.self) { kind in
                        let packs = available.filter { $0.kind == kind }
                        if !packs.isEmpty {
                            Text(kind.displayName)
                                .font(.subheadline.weight(.semibold))
                                .padding(.top, 4)
                            ForEach(packs) { pack in
                                packRow(pack)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    @ViewBuilder
    private func packRow(_ pack: FineTunePack) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(for: pack.kind))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.displayName)
                    .font(.callout.weight(.medium))
                Text(pack.source.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(pack.license)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                    gateBadge(pack.gate)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    private func icon(for kind: FineTunePackKind) -> String {
        switch kind {
        case .dataset: "tablecells"
        case .loraAdapter: "cpu"
        case .instructionPack: "text.book.closed"
        case .knowledgePack: "books.vertical"
        }
    }

    @ViewBuilder
    private func gateBadge(_ gate: FineTunePackGate) -> some View {
        Text(gate.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(gateTint(gate).opacity(0.15), in: Capsule())
            .foregroundStyle(gateTint(gate))
    }

    private func gateTint(_ gate: FineTunePackGate) -> Color {
        switch gate {
        case .free: .green
        case .pro: .blue
        case .dev: .orange
        }
    }
}
