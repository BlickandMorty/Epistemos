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
//   - W-21 recall rates when a benchmark reporter has recorded them
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
    @State private var refreshTask: Task<Void, Never>?

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
                    ? "EPISTEMOS_VAULT_RECALL_CONTRACT_V1 on (diagnostic trace flag)"
                    : "EPISTEMOS_VAULT_RECALL_CONTRACT_V1 off (chat still records visible traces)"
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: vaultRecallSubstrateLabel,
                productionWired: snapshot.lastBackend == .real,
                falsifierPassed: vaultRecallBenchmarkPassing,
                falsifier: "docs/falsifiers/F-VaultRecall-50_2026_05_17.md",
                wiredToday: vaultRecallWiredToday,
                stillStub: vaultRecallStillStub
            )
            w21MetricChipStrip
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
        .onAppear {
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
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

    private var w21MetricChipStrip: some View {
        HStack(spacing: 6) {
            benchmarkChip(
                title: "Top-1 exact",
                rate: snapshot.recallBenchmark.top1ExactTitleRate,
                threshold: 0.95
            )
            benchmarkChip(
                title: "Top-5 paraphrase",
                rate: snapshot.recallBenchmark.top5ParaphraseRate,
                threshold: 0.95
            )
            benchmarkChip(
                title: "2-note cite",
                rate: snapshot.recallBenchmark.synthesisTwoNoteCitationRate,
                threshold: 0.95
            )
            benchmarkChip(
                title: "Adversarial reject",
                rate: snapshot.recallBenchmark.adversarialRejectRate,
                threshold: 0.95
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                refresh()
            }
        }
    }

    private var lastQueryDetail: String {
        if let err = snapshot.lastErrorDescription, snapshot.lastQueryAt == nil {
            return "Error: \(err)"
        }
        guard let date = snapshot.lastQueryAt else {
            return snapshot.isFlagEnabled
                ? "No queries yet — run a vault search to populate"
                : "No queries yet — run a vault search to populate"
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
        switch snapshot.lastBackend {
        case .real:
            return "\(slugs.joined(separator: ",")) (production search-index trace)"
        case .stub:
            return "\(slugs.joined(separator: ",")) (scaffold trace)"
        case .unknown:
            return "\(slugs.joined(separator: ",")) (unknown trace origin)"
        }
    }

    private var vaultRecallSubstrateLabel: String {
        switch snapshot.lastBackend {
        case .real:
            vaultRecallBenchmarkPassing ? "vault backend + benchmark" : "vault backend observed"
        case .stub:
            "synthetic trace · no backend binding"
        case .unknown:
            "trace not observed"
        }
    }

    private var vaultRecallBenchmarkPassing: Bool {
        let rates = [
            snapshot.recallBenchmark.top1ExactTitleRate,
            snapshot.recallBenchmark.top5ParaphraseRate,
            snapshot.recallBenchmark.synthesisTwoNoteCitationRate,
            snapshot.recallBenchmark.adversarialRejectRate,
        ]
        return rates.allSatisfy { ($0 ?? 0) >= 0.95 }
    }

    private var vaultRecallWiredToday: String {
        switch snapshot.lastBackend {
        case .real:
            return "Vault recall emitted a production backend trace."
        case .stub:
            return "Rust trace scaffold emits synthetic candidates and signal summary."
        case .unknown:
            return "No VaultRecall trace has reached Settings this launch."
        }
    }

    private var vaultRecallStillStub: String {
        "Green blocked unless the trace comes from a real VaultBackend and F-VaultRecall-50 benchmark rates pass."
    }

    private func formatLatency(_ ms: Double) -> String {
        if ms < 1.0 { return String(format: "%.2f ms", ms) }
        if ms < 100.0 { return String(format: "%.1f ms", ms) }
        return String(format: "%.0f ms", ms)
    }

    private func formatRate(_ rate: Double) -> String {
        String(format: "%.0f%%", max(0, min(rate, 1)) * 100)
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

    private func benchmarkChip(title: String, rate: Double?, threshold: Double) -> some View {
        let tint: Color = {
            guard let rate else { return .orange }
            return rate >= threshold ? .green : .red
        }()
        let suffix = rate.map(formatRate) ?? "pending"
        return ChannelStatusPill(title: "\(title): \(suffix)", tint: tint)
    }
}
