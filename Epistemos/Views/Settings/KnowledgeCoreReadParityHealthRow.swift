import SwiftUI
import SwiftData

// MARK: - KnowledgeCoreReadParityHealthRow
//
// KC read-side cutover diagnostic. On demand, runs `KnowledgeCoreReadParityProbe`
// over a sample of the active vault's notes and reports KC-vs-live task
// count-parity. Flag-gated behind EPISTEMOS_KNOWLEDGECORE_READ_V0 (default off);
// read-only shadow probe — never mutates app state and never claims a
// production-green cutover. Mirrors `SearchFusionHealthRow` shape.
//
// See docs/plans/KNOWLEDGE_CORE_SHADOW_TO_PRODUCTION_CUTOVER_PLAN_2026_06_13.md.

@MainActor
struct KnowledgeCoreReadParityHealthRow: View {
    @Environment(\.modelContext) private var modelContext

    @State private var report: KnowledgeCoreReadParityReport?
    @State private var isRunning = false
    @State private var lastError: String?

    private var flagEnabled: Bool {
        EpistemosRuntimeFeatureFlags.load().knowledgeCoreReadParityV0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "KC read-parity flag",
                symbol: "flag.fill",
                state: flagEnabled ? .pass : .unavailable,
                detail: flagEnabled
                    ? "EPISTEMOS_KNOWLEDGECORE_READ_V0=1 (shadow probe enabled)"
                    : "EPISTEMOS_KNOWLEDGECORE_READ_V0 unset (probe still runnable on demand)"
            )
            VerifiedFloorChipStrip(
                flag: flagEnabled ? "on" : "off",
                substrate: report != nil ? "probe run" : "not exercised",
                productionWired: false,
                falsifierPassed: false,
                falsifier: "docs/plans/KNOWLEDGE_CORE_SHADOW_TO_PRODUCTION_CUTOVER_PLAN_2026_06_13.md",
                wiredToday: "Shadow probe compares KC vs live task extraction over real vault notes.",
                stillStub: "Shadow-only parity; not a production cutover claim without persistence + sign-off."
            )
            row(
                label: "Last parity run",
                symbol: "checkmark.seal",
                state: parityState,
                detail: parityDetail
            )
            if let lastError {
                row(
                    label: "Last error",
                    symbol: "exclamationmark.triangle",
                    state: .blocked,
                    detail: lastError
                )
            }
            Button {
                runProbe()
            } label: {
                Label(
                    isRunning ? "Running…" : "Run parity check (vault sample)",
                    systemImage: "play.circle"
                )
                .font(.system(size: 12))
            }
            .disabled(isRunning)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Display

    private var parityDetail: String {
        guard let report else { return "No run yet — tap Run to sample the vault" }
        let pct = String(format: "%.0f%%", report.parityRate * 100)
        return "\(report.taskParityMatches)/\(report.noteCount) notes at task-count parity (\(pct)); \(report.divergentNoteCount) divergent"
    }

    private var parityState: SubstrateHealthSignalState {
        guard let report else { return .unavailable }
        if report.noteCount == 0 { return .partial }
        if report.parityRate >= 0.99 { return .pass }
        return report.parityRate >= 0.9 ? .partial : .blocked
    }

    // MARK: - Probe

    private func runProbe() {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil
        Task { @MainActor in
            defer { isRunning = false }

            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
            )
            let pages = Array(((try? modelContext.fetch(descriptor)) ?? []).prefix(25))

            var corpus: [(pageId: String, text: String)] = []
            for page in pages {
                let body = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: page.id,
                    filePath: page.filePath
                )
                if !body.isEmpty {
                    corpus.append((pageId: "kcparity::\(page.id)", text: body))
                }
            }

            guard let bridge = KnowledgeCoreBridge(peerId: 4242) else {
                lastError = "Could not create KnowledgeCoreBridge"
                return
            }

            report = await KnowledgeCoreReadParityProbe.taskParity(
                over: corpus,
                bridge: bridge,
                liveTaskCounts: { text in
                    // Live extractor is @MainActor; summarize inside the actor and
                    // return the Sendable summary so nothing non-Sendable escapes.
                    await MainActor.run {
                        let live = TextCapturePipeline().extractTasks(from: text)
                        return KnowledgeCoreTaskParitySummary(
                            total: live.count,
                            done: live.filter(\.isCompleted).count
                        )
                    }
                }
            )
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
