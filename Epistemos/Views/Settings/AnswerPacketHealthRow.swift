import SwiftUI

// MARK: - AnswerPacketHealthRow
//
// V6.2 first-rendered surface for the AnswerPacket audit channel.
// Mirrors `EditorBundleHealthRow` / `SearchFusionHealthRow` shape so
// Settings → General → Diagnostics has a consistent diagnostic
// vocabulary.
//
// Per `docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md`
// + `docs/fusion/helios v6.2.md` §1.3 + §3: every completed chat turn
// emits an AnswerPacket. Today the packet is recorded in the bounded
// ring on `AnswerPacketEmitter.shared`; this row makes that ring
// **observable from the UI**, advancing the V6.2 promotion ladder:
//
//   state: implemented → schema only
//   state: emitted     → turn-completion stub recorded
//   state: partially populated → attention_mode + interruptBucket sampled
//   state: rendered (PARTIAL) ← THIS ROW
//   state: rendered (FULL)    → VRMLabelView per message bubble (follow-on)
//   state: canonical-product-surface → MAS-shippable audit channel
//
// This row exposes:
//   - lifetime count (total packets emitted this process)
//   - ring depth (last N packets retained)
//   - latest packet's attentionMode + interruptBucket + uiLabel
//   - last emit timestamp + relative age
//
// Refresh model:
//   - Initial snapshot on appear (so first paint isn't blank).
//   - Event-driven via `AnswerPacketEmitter.didEmitNotification`,
//     posted on the main queue from inside the actor's `emit()`.
//   - No polling. No timer.

@MainActor
public struct AnswerPacketHealthRow: View {

    @State private var snapshot: AnswerPacketEmitter.Snapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        // Initialize with an empty snapshot so first paint isn't blank;
        // .onAppear pulls the live one before the user notices.
        self._snapshot = State(
            initialValue: AnswerPacketEmitter.Snapshot(
                count: 0,
                totalEmitted: 0,
                firstEmittedAt: nil,
                lastEmittedAt: nil,
                latest: nil,
                modeCounts: [:],
                bucketCounts: [:]
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Emit channel",
                symbol: "antenna.radiowaves.left.and.right",
                ok: snapshot.totalEmitted > 0,
                detail: emitChannelDetail
            )
            row(
                label: "Audit ring",
                symbol: "tray.full",
                ok: snapshot.count > 0,
                detail: "\(snapshot.count) / \(AnswerPacketEmitter.maxRingSize) packets retained"
            )
            if let latest = snapshot.latest {
                row(
                    label: "Latest packet",
                    symbol: "checkmark.shield",
                    ok: true,
                    detail: latestPacketDetail(latest)
                )
                row(
                    label: "Last emit",
                    symbol: "clock",
                    ok: true,
                    detail: lastEmitDetail
                )
                // Histogram rows — per-mode + per-bucket distributions
                // give the user a quick visual on whether the runtime
                // is hitting all V6.2 §1.4 attention modes and §1.5
                // bucket regions, or stuck in a single state.
                if !snapshot.modeCounts.isEmpty {
                    row(
                        label: "By attention mode",
                        symbol: "chart.bar.horizontal",
                        ok: true,
                        detail: modeHistogramDetail
                    )
                }
                if !snapshot.bucketCounts.isEmpty {
                    row(
                        label: "By interrupt bucket",
                        symbol: "chart.bar.fill",
                        ok: true,
                        detail: bucketHistogramDetail
                    )
                }
            } else {
                row(
                    label: "Latest packet",
                    symbol: "tray",
                    ok: false,
                    detail: "No packets yet — send a chat message to populate."
                )
            }
        }
        .onAppear { refresh() }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: AnswerPacketEmitter.didEmitNotification,
                object: AnswerPacketEmitter.shared
            )
        ) { _ in
            refresh()
        }
    }

    /// Pull the current snapshot from the actor. Hops async; debounced
    /// by reusing a single in-flight `refreshTask`.
    public func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            let next = await AnswerPacketEmitter.shared.snapshot()
            // Avoid pointless redraws when nothing changed.
            if next != snapshot {
                snapshot = next
            }
        }
    }

    // MARK: - Display helpers

    private var emitChannelDetail: String {
        if snapshot.totalEmitted == 0 {
            return "Idle — no chat turns completed this session."
        }
        return "\(snapshot.totalEmitted) packets emitted this session."
    }

    private func latestPacketDetail(_ packet: AnswerPacket) -> String {
        var parts: [String] = []
        parts.append("mode=\(packet.attentionMode.rawValue)")
        parts.append("bucket=\(packet.interruptBucket.rawValue)")
        parts.append("label=\(packet.uiLabel.rawValue)")
        return parts.joined(separator: " · ")
    }

    private var lastEmitDetail: String {
        guard let date = snapshot.lastEmittedAt else {
            return "Never"
        }
        return Self.relativeTime(date)
    }

    /// `dynamic: 12 · static_fallback: 5 · unavailable: 1` style.
    /// Ordered by canonical AttentionMode declaration so the row
    /// reads stably across sessions.
    private var modeHistogramDetail: String {
        let order: [AttentionMode] = [.dynamic, .staticFallback, .unavailable]
        let parts: [String] = order.compactMap { mode in
            guard let count = snapshot.modeCounts[mode], count > 0 else { return nil }
            return "\(mode.rawValue): \(count)"
        }
        return parts.isEmpty ? "no signal yet" : parts.joined(separator: " · ")
    }

    /// `low: 8 · medium: 6 · high: 2 · unavailable: 1` style.
    /// Ordered by V6.2 §1.5 calibration corpus (LOW < MED < HIGH).
    private var bucketHistogramDetail: String {
        let order: [InterruptBucket] = [.low, .medium, .high, .unavailable]
        let parts: [String] = order.compactMap { bucket in
            guard let count = snapshot.bucketCounts[bucket], count > 0 else { return nil }
            return "\(bucket.rawValue): \(count)"
        }
        return parts.isEmpty ? "no signal yet" : parts.joined(separator: " · ")
    }

    // MARK: - Row primitive (matches SearchFusionHealthRow / EditorBundleHealthRow)

    @ViewBuilder
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(ok ? Color.green : Color.secondary)
                .frame(width: 16, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }

    // Match SearchFusionHealthRow's relative-time helper exactly so the
    // diagnostic vocabulary is consistent across rows.
    private static func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 {
            return "\(Int(interval))s ago"
        }
        if interval < 3_600 {
            return "\(Int(interval / 60))m ago"
        }
        if interval < 86_400 {
            return "\(Int(interval / 3_600))h ago"
        }
        return "\(Int(interval / 86_400))d ago"
    }
}

#if DEBUG
#Preview("AnswerPacketHealthRow — empty") {
    AnswerPacketHealthRow()
        .padding()
        .frame(width: 360)
}
#endif
