import SwiftUI

// MARK: - SearchFusionHealthRow
//
// RRF Fusion Phase 6 settings diagnostic — read-only status rows for
// the cross-index RRF fusion query (`SearchIndexService.fusedSearch`).
// Mirrors `EditorBundleHealthRow` shape so the Settings sheet has a
// consistent diagnostic vocabulary.
//
// Surfaces:
//   - flag state (EPISTEMOS_RRF_FUSION_V1)
//   - last-query latency
//   - p95 latency over the most recent ~200 samples
//   - last-query hit count (per source)
//   - total queries served this process
//   - last error (if any)
//
// Reads from `SearchFusionMetrics.shared` which is updated by
// `SearchIndexService.fusedSearch` / `fusedSearchAsync`. Refresh is
// event-driven through `SearchFusionMetrics.didChangeNotification`.
// No instrumentation is needed at the UI side beyond this view.

@MainActor
public struct SearchFusionHealthRow: View {

    @State private var snapshot: SearchFusionMetrics.Snapshot

    public init() {
        // Initialize with the live snapshot so first paint isn't blank.
        self._snapshot = State(initialValue: SearchFusionMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "RRF Fusion flag",
                symbol: "flag.fill",
                state: snapshot.isFlagEnabled ? .pass : .unavailable,
                detail: snapshot.isFlagEnabled
                    ? "EPISTEMOS_RRF_FUSION_V1=1 (enabled)"
                    : "EPISTEMOS_RRF_FUSION_V1 unset (legacy per-index path)"
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: snapshot.sampleCount > 0 ? "metrics live" : "not exercised",
                productionWired: snapshot.sampleCount > 0,
                falsifierPassed: false,
                falsifier: "docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md",
                wiredToday: "Search fusion metrics report observed queries and latency.",
                stillStub: "Metrics alone are not a production-green retrieval claim without a primary PASS witness."
            )
            row(
                label: "Last query",
                symbol: "clock",
                state: lastQueryState,
                detail: lastQueryDetail
            )
            row(
                label: "p95 latency",
                symbol: "chart.line.uptrend.xyaxis",
                state: p95State,
                detail: p95Detail
            )
            row(
                label: "Hit distribution",
                symbol: "square.stack.3d.up",
                state: hitDistributionState,
                detail: hitDistributionDetail
            )
            if let err = snapshot.lastErrorDescription {
                row(
                    label: "Last error",
                    symbol: "exclamationmark.triangle",
                    state: displayErrorState(for: err),
                    detail: displayErrorDetail(for: err)
                )
            }
        }
        .onAppear {
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: SearchFusionMetrics.didChangeNotification,
            object: SearchFusionMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    /// Re-probe the metrics. Called on view appearance and whenever
    /// `SearchFusionMetrics` publishes a change.
    public func refresh() {
        snapshot = SearchFusionMetrics.shared.snapshot()
    }

    // MARK: - Display helpers

    private var lastQueryDetail: String {
        if let err = snapshot.lastErrorDescription, snapshot.lastQueryAt == nil {
            return displayErrorDetail(for: err)
        }
        guard let date = snapshot.lastQueryAt else {
            return snapshot.isFlagEnabled
                ? "No queries yet — run a search to populate metrics"
                : "Flag off — fusion path not exercised"
        }
        let elapsed = formatLatency(snapshot.lastLatencyMs)
        let ago = Self.relativeTime(date)
        return "\(elapsed) (\(ago)) — \(snapshot.totalQueries) total"
    }

    private var p95Detail: String {
        guard snapshot.sampleCount > 0 else {
            return "0 samples"
        }
        let value = formatLatency(snapshot.p95LatencyMs)
        return "\(value) over \(snapshot.sampleCount) samples"
    }

    private var hitDistributionDetail: String {
        guard !snapshot.hitsBySource.isEmpty else {
            return snapshot.lastQueryAt == nil ? "(no recent query)" : "(zero-hit result)"
        }
        let parts = snapshot.hitsBySource
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
        return parts.joined(separator: " ")
    }

    private var lastQueryState: SubstrateHealthSignalState {
        if let err = snapshot.lastErrorDescription {
            return displayErrorState(for: err)
        }
        if snapshot.lastQueryAt != nil { return .pass }
        return snapshot.isFlagEnabled ? .partial : .unavailable
    }

    private var p95State: SubstrateHealthSignalState {
        guard snapshot.sampleCount > 0 else {
            return snapshot.isFlagEnabled ? .partial : .unavailable
        }
        // Healthy = under the 30 ms p95 budget from the user mission
        // brief (`docs/RRF_FUSION_PROMPT.md` Phase 5 perf gate).
        return snapshot.p95LatencyMs <= 30.0 ? .pass : .blocked
    }

    private var hitDistributionState: SubstrateHealthSignalState {
        if let err = snapshot.lastErrorDescription {
            return displayErrorState(for: err)
        }
        guard snapshot.lastQueryAt != nil else {
            return snapshot.isFlagEnabled ? .partial : .unavailable
        }
        return .pass
    }

    private func displayErrorState(for error: String) -> SubstrateHealthSignalState {
        isReadableBlocksSchemaBootstrapError(error) ? .partial : .blocked
    }

    private func displayErrorDetail(for error: String) -> String {
        if isReadableBlocksSchemaBootstrapError(error) {
            return "Readable-blocks FTS index not initialized — run vault sync/index rebuild"
        }
        return error
    }

    private func isReadableBlocksSchemaBootstrapError(_ error: String) -> Bool {
        error.localizedCaseInsensitiveContains("no such table: readable_blocks_fts")
            || error.localizedCaseInsensitiveContains("no such table: main.readable_blocks_fts")
    }

    private func formatLatency(_ ms: Double) -> String {
        if ms < 1.0 {
            return String(format: "%.2f ms", ms)
        }
        if ms < 100.0 {
            return String(format: "%.1f ms", ms)
        }
        return String(format: "%.0f ms", ms)
    }

    private static func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3_600))h ago"
    }

    @ViewBuilder
    private func row(label: String, symbol: String, state: SubstrateHealthSignalState, detail: String) -> some View {
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
                    .lineLimit(1)
                    .truncationMode(.middle)
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

#if DEBUG
#Preview("SearchFusionHealthRow — fresh") {
    SearchFusionMetrics.shared.reset()
    return SearchFusionHealthRow()
        .padding()
        .frame(width: 480)
}
#endif
