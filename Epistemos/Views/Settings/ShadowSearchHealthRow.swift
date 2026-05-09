import SwiftUI

// MARK: - ShadowSearchHealthRow
//
// Read-only Settings diagnostic for the Halo/Shadow search bridge.
// The row is intentionally driven by `ShadowSearchDiagnostics` instead
// of calling the backend from Settings; opening Settings must not poke
// the Shadow index or turn a latent backend issue into launch work.

@MainActor
public struct ShadowSearchHealthRow: View {
    @State private var snapshot: ShadowSearchDiagnostics.Snapshot

    public init() {
        self._snapshot = State(initialValue: ShadowSearchDiagnostics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Shadow backend",
                symbol: snapshot.isDegraded ? "exclamationmark.triangle.fill" : "magnifyingglass.circle.fill",
                ok: !snapshot.isDegraded,
                detail: backendDetail
            )
            row(
                label: "Last search",
                symbol: "clock",
                ok: !snapshot.isDegraded && snapshot.totalSearches > 0,
                detail: lastSearchDetail
            )
            row(
                label: "Failure budget",
                symbol: "waveform.path.ecg",
                ok: snapshot.consecutiveFailures == 0,
                detail: failureDetail
            )
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: ShadowSearchDiagnostics.didChangeNotification,
            object: ShadowSearchDiagnostics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = ShadowSearchDiagnostics.shared.snapshot()
    }

    private var backendDetail: String {
        if snapshot.totalSearches == 0 {
            return "No Shadow searches observed this launch"
        }
        if snapshot.isDegraded {
            return "Degraded: \(snapshot.lastFailureClass ?? "unknown_error")"
        }
        return "Operational"
    }

    private var lastSearchDetail: String {
        guard snapshot.totalSearches > 0 else {
            return "Run Halo/search to populate metrics"
        }
        let domain = snapshot.lastDomain ?? "unknown"
        let hits = snapshot.lastHitCount.map(String.init) ?? "0"
        let latency = formatLatency(snapshot.lastLatencyMs ?? 0)
        if let lastFailureAt = snapshot.lastFailureAt,
           snapshot.lastFailureClass != nil,
           snapshot.isDegraded {
            return "\(domain) failure \(Self.relativeTime(lastFailureAt)) in \(latency)"
        }
        return "\(domain) \(hits) hit(s) in \(latency)"
    }

    private var failureDetail: String {
        guard snapshot.totalFailures > 0 else {
            return "0 failures"
        }
        let streak = snapshot.consecutiveFailures
        let total = snapshot.totalFailures
        let suffix = snapshot.lastFailureClass.map { " last=\($0)" } ?? ""
        return "\(streak) consecutive / \(total) total\(suffix)"
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

#if DEBUG
#Preview("ShadowSearchHealthRow") {
    ShadowSearchHealthRow()
        .padding()
        .frame(width: 480)
}
#endif
