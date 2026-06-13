import SwiftUI

// MARK: - KnowledgeCoreRuntimeHealthRow
//
// KC cutover Slice 3 diagnostic. Shows whether the in-app KnowledgeCore shadow
// runtime is standing (flag knowledgeCoreRuntimeV0, default off), how many facts
// it currently projects (the first KC read API: graph_engine_kc_fact_counts),
// and that its durable oplog is on disk. Read-only — never mutates app state and
// never claims a production-green cutover. Mirrors KnowledgeCoreReadParityHealthRow.
//
// See docs/plans/KNOWLEDGE_CORE_SHADOW_TO_PRODUCTION_CUTOVER_PLAN_2026_06_13.md.

@MainActor
struct KnowledgeCoreRuntimeHealthRow: View {
    @State private var factCounts: KnowledgeCoreFactCounts?
    @State private var oplogBytes: Int?
    @State private var isRefreshing = false

    private var flagEnabled: Bool {
        EpistemosRuntimeFeatureFlags.load().knowledgeCoreRuntimeV0
    }

    private var runtimeStanding: Bool {
        AppBootstrap.shared?.knowledgeCoreRuntime != nil
    }

    private var oplogPath: String? {
        AppBootstrap.shared?.knowledgeCoreOplogPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "KC runtime flag",
                symbol: "flag.fill",
                state: flagEnabled ? .pass : .unavailable,
                detail: flagEnabled
                    ? "EPISTEMOS_KNOWLEDGECORE_RUNTIME_V0=1 (runtime stands on vault open)"
                    : "EPISTEMOS_KNOWLEDGECORE_RUNTIME_V0 unset (runtime not instantiated)"
            )
            VerifiedFloorChipStrip(
                flag: flagEnabled ? "on" : "off",
                substrate: runtimeStanding ? "runtime live" : "not instantiated",
                productionWired: false,
                falsifierPassed: false,
                falsifier: "docs/plans/KNOWLEDGE_CORE_SHADOW_TO_PRODUCTION_CUTOVER_PLAN_2026_06_13.md",
                wiredToday: "Runtime instantiates + persists + seeds from vault notes when the flag is on.",
                stillStub: "Shadow-only; drives no user-visible surface yet (step 3 = dev-cert run + sign-off)."
            )
            row(
                label: "Runtime instance",
                symbol: "bolt.horizontal.circle",
                state: runtimeStanding ? .pass : .unavailable,
                detail: runtimeStanding
                    ? "KnowledgeCoreShadowRuntime standing for the active vault"
                    : (flagEnabled ? "Flag on but no runtime — open a vault" : "Flag off — no runtime")
            )
            row(
                label: "Projected facts",
                symbol: "square.stack.3d.up",
                state: factState,
                detail: factDetail
            )
            row(
                label: "Durable oplog",
                symbol: "externaldrive.badge.timemachine",
                state: oplogState,
                detail: oplogDetail
            )
            Button {
                refresh()
            } label: {
                Label(
                    isRefreshing ? "Reading…" : "Refresh runtime state",
                    systemImage: "arrow.clockwise"
                )
                .font(.system(size: 12))
            }
            .disabled(isRefreshing || !runtimeStanding)
            .buttonStyle(.bordered)
        }
        .task { refresh() }
    }

    // MARK: - Display

    private var factDetail: String {
        guard runtimeStanding else { return "Runtime not standing" }
        guard let factCounts else { return "Tap Refresh to read fact counts" }
        return "\(factCounts.blocks) blocks · \(factCounts.tasks) tasks · \(factCounts.properties) props · \(factCounts.links) links"
    }

    private var factState: SubstrateHealthSignalState {
        guard runtimeStanding else { return .unavailable }
        guard let factCounts else { return .unavailable }
        return factCounts.total > 0 ? .pass : .partial
    }

    private var oplogDetail: String {
        guard let oplogPath else { return "No active vault" }
        let name = (oplogPath as NSString).lastPathComponent
        guard let oplogBytes else { return "\(name) — size unread" }
        return "\(name) — \(byteString(oplogBytes)) journaled"
    }

    private var oplogState: SubstrateHealthSignalState {
        guard oplogPath != nil else { return .unavailable }
        guard let oplogBytes else { return .unavailable }
        return oplogBytes > 0 ? .pass : .partial
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: - Refresh

    private func refresh() {
        guard !isRefreshing else { return }
        guard let runtime = AppBootstrap.shared?.knowledgeCoreRuntime else {
            factCounts = nil
            oplogBytes = nil
            return
        }
        isRefreshing = true
        Task { @MainActor in
            defer { isRefreshing = false }
            factCounts = await runtime.factCounts()
            if let oplogPath {
                let attrs = try? FileManager.default.attributesOfItem(atPath: oplogPath)
                oplogBytes = (attrs?[.size] as? Int) ?? 0
            } else {
                oplogBytes = nil
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(
        label: String,
        symbol: String,
        state: SubstrateHealthSignalState,
        detail: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: state.symbol)
                .foregroundStyle(state.tint)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
