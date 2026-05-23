import SwiftUI

// MARK: - VaultRecallHealthRow
//
// Wiring #2 (T21 Vault Recall Contract -> ResourceService) settings
// diagnostic. Mirrors `EidosHealthRow` / `SearchFusionHealthRow` shape
// so the Settings sheet keeps a consistent diagnostic vocabulary
// across retrieval surfaces.
//
// Surfaces:
//   - flag state (`EPISTEMOS_VAULT_RECALL_CONTRACT_V1` UserDefaults / env)
//   - last query latency + p95 over ~200 samples
//   - last candidates retained + signal summary (Lexical / Semantic /
//     Graph / Recency / Mmr presence chips)
//   - all-chatter-fallback warning if `strip_query_chatter` emptied the
//     query (downstream consumers treat this as Weak evidence)
//   - last error (if any)
//
// Reads from `VaultRecallMetrics.shared`. Refresh is event-driven via
// `VaultRecallMetrics.didChangeNotification` — no polling needed.

@MainActor
public struct VaultRecallHealthRow: View {

    @State private var snapshot: VaultRecallMetrics.Snapshot

    public init() {
        self._snapshot = State(initialValue: VaultRecallMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Vault recall contract flag",
                symbol: "flag.fill",
                ok: snapshot.isFlagEnabled,
                detail: snapshot.isFlagEnabled
                    ? "EPISTEMOS_VAULT_RECALL_CONTRACT_V1 on (synthetic trace emission)"
                    : "EPISTEMOS_VAULT_RECALL_CONTRACT_V1 off (no trace emission)"
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: "stub trace",
                substrateTint: .orange
            )
            row(
                label: "Last query",
                symbol: "clock",
                ok: snapshot.lastQueryAt != nil && snapshot.lastErrorDescription == nil,
                detail: lastQueryDetail
            )
            row(
                label: "p95 latency",
                symbol: "chart.line.uptrend.xyaxis",
                ok: snapshot.sampleCount > 0 && snapshot.p95LatencyMs <= 50.0,
                detail: p95Detail
            )
            row(
                label: "Signal coverage",
                symbol: "antenna.radiowaves.left.and.right",
                ok: !snapshot.lastSignalSummary.isEmpty || !snapshot.isFlagEnabled,
                detail: signalCoverageDetail
            )
            if snapshot.lastAllChatterFallback {
                row(
                    label: "Chatter fallback fired",
                    symbol: "exclamationmark.bubble",
                    ok: false,
                    detail: "Query reduced to empty after chatter strip — treat as Weak evidence"
                )
            }
            if let err = snapshot.lastErrorDescription {
                row(
                    label: "Last error",
                    symbol: "exclamationmark.triangle",
                    ok: false,
                    detail: err
                )
            }
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: VaultRecallMetrics.didChangeNotification,
            object: VaultRecallMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = VaultRecallMetrics.shared.snapshot()
    }

    private var lastQueryDetail: String {
        if let err = snapshot.lastErrorDescription, snapshot.lastQueryAt == nil {
            return "Error: \(err)"
        }
        guard let date = snapshot.lastQueryAt else {
            return snapshot.isFlagEnabled
                ? "No queries yet — run a vault search to populate"
                : "Flag off — contract path not exercised"
        }
        let elapsed = formatLatency(snapshot.lastLatencyMs)
        let ago = Self.relativeTime(date)
        return "\(elapsed) (\(ago)) — \(snapshot.totalQueries) total, retained=\(snapshot.lastCandidatesRetained)"
    }

    private var p95Detail: String {
        guard snapshot.sampleCount > 0 else { return "0 samples" }
        return "\(formatLatency(snapshot.p95LatencyMs)) over \(snapshot.sampleCount) samples"
    }

    private var signalCoverageDetail: String {
        guard !snapshot.lastSignalSummary.isEmpty else {
            return snapshot.lastQueryAt == nil ? "(no query yet)" : "no signals emitted"
        }
        let slugs = snapshot.lastSignalSummary.map { $0.rawValue }.sorted()
        return "\(slugs.joined(separator: ",")) (synthetic; no vault retrieval yet)"
    }

    private func formatLatency(_ ms: Double) -> String {
        if ms < 1.0 { return String(format: "%.2f ms", ms) }
        if ms < 100.0 { return String(format: "%.1f ms", ms) }
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
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
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
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
