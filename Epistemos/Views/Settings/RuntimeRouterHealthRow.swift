import SwiftUI

// MARK: - RuntimeRouterHealthRow (Phase 2 Terminal T1 — 2026-05-24)
//
// Diagnostics row that surfaces the multi-lane router's per-lane
// activity. Renders:
//   * A chip strip — one chip per known lane, color-coded by tier
//     (CurrentApp = green, VerifiedFloor = blue, CapabilityCeiling =
//     purple), with the lane's enable state (filled = on, hollow =
//     off) and the per-lane accept tally over the lifetime of the
//     session.
//   * Last-100 ring: a compact horizontal bar of the most recent
//     verdicts (accept = filled lane color, escalate = hollow,
//     reject = red dash).
//   * Per-lane escalation count summary.
//
// Doctrine: this row is the "what just happened in the router?"
// honest signal that lets the user verify the acceptance gate
// "MLX flippable OFF without breaking chat — escalations logged".
// Mirrors the visual rhythm of `RuntimeTruthHealthRow` (the universal
// "what's running now" row) without overlapping its content.

@MainActor
public struct RuntimeRouterHealthRow: View {
    @State private var router = RuntimeRouter.shared

    public init() {}

    public var body: some View {
        Section("Runtime Router") {
            VStack(alignment: .leading, spacing: 10) {
                summaryRow
                stage2ReadinessRow
                Divider()
                Text("Chip strip — per lane")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                chipStrip
                Divider()
                Text("Last \(RuntimeRouterMetrics.ringCapacity) verdicts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ringBar
                if !router.escalationLog.isEmpty {
                    Divider()
                    DisclosureGroup("Escalation log (\(router.escalationLog.count))") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(recentEscalationEntries.enumerated()), id: \.offset) { _, entry in
                                    Text(entry)
                                        .font(.system(.caption2, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 140)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            stat(label: "Verdicts", value: "\(router.metrics.totalCount)")
            stat(label: "Escalations", value: "\(totalEscalations)")
            stat(label: "Rejects", value: "\(router.metrics.rejectCount)")
            stat(label: "Parity", value: parityValue)
            Spacer()
        }
    }

    /// STAGE-2 promotion readiness — the precise green-light for the authoritative-lane flip
    /// (owner 2026-06-21 "flip if parityRate is solid"), replacing the eyeballed "rising-toward-
    /// 100%". READY only once parity clears the sample + rate floors (RuntimeRouterStage2Readiness);
    /// otherwise the honest reason it isn't ready yet.
    private var stage2ReadinessRow: some View {
        let ready = RuntimeRouterStage2Readiness.isReady(
            parityObservations: router.metrics.parityObservations,
            parityRate: router.metrics.parityRate
        )
        return HStack(spacing: 6) {
            Image(systemName: ready ? "checkmark.seal.fill" : "hourglass")
                .font(.caption)
                .foregroundStyle(ready ? Color.green : Color.secondary)
            Text("STAGE-2: " + RuntimeRouterStage2Readiness.summary(
                parityObservations: router.metrics.parityObservations,
                parityRate: router.metrics.parityRate
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// SUBSTRATE Phase 1 STAGE 1b observe-only parity: the fraction of turns the router agreed
    /// with the live path's lane choice. "—" until the shadow has observed a turn (the
    /// EPISTEMOS_RUNTIMEROUTER_LIVE_V0 flag is OFF by default, so this stays "—" until armed). A
    /// rising-toward-100% value is the green light for STAGE 2 (making the router authoritative).
    private var parityValue: String {
        guard let rate = router.metrics.parityRate else { return "—" }
        return "\(Int((rate * 100).rounded()))% (\(router.metrics.parityObservations))"
    }

    private var chipStrip: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 6)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(RuntimeLane.knownLanes, id: \.stableID) { lane in
                let tally = router.metrics.tally(for: lane)
                let enabled = router.isLaneEnabled(lane)
                HStack(spacing: 6) {
                    Circle()
                        .fill(enabled ? chipColor(for: lane) : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(chipColor(for: lane), lineWidth: enabled ? 0 : 1)
                        )
                    Text(lane.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(tally.accepts)/\(tally.escalations)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.08))
                )
            }
        }
    }

    private var ringBar: some View {
        let entries = router.metrics.ring
        return Group {
            if entries.isEmpty {
                Text("No verdicts recorded this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 1) {
                    ForEach(entries) { entry in
                        verdictCell(entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func verdictCell(_ entry: RuntimeRouterMetrics.VerdictEntry) -> some View {
        Rectangle()
            .fill(verdictColor(for: entry))
            .frame(width: 6, height: 16)
            .overlay(
                Group {
                    if entry.kind == .escalate {
                        Rectangle()
                            .stroke(chipColor(for: entry.lane), lineWidth: 1)
                    }
                }
            )
            .help(verdictTooltip(entry))
    }

    private func verdictColor(for entry: RuntimeRouterMetrics.VerdictEntry) -> Color {
        switch entry.kind {
        case .accept:
            return chipColor(for: entry.lane)
        case .escalate:
            return Color.clear
        case .reject:
            return .red
        }
    }

    private func verdictTooltip(_ entry: RuntimeRouterMetrics.VerdictEntry) -> String {
        var parts: [String] = [
            entry.kind.rawValue,
            entry.lane.stableID,
            entry.role.rawValue,
        ]
        if let detail = entry.detail {
            parts.append(detail)
        }
        return parts.joined(separator: " · ")
    }

    private func chipColor(for lane: RuntimeLane) -> Color {
        switch lane {
        case .mlx: return .green
        case .gguf: return .teal
        case .appleIntelligence: return .blue
        case .cloud(let provider):
            switch provider {
            case "claude": return .orange
            case "openai": return .indigo
            case "gemini": return .yellow
            case "perplexity": return .pink
            default: return .purple
            }
        case .stub: return .gray
        }
    }

    private var totalEscalations: Int {
        router.metrics.escalationsByLane.values.reduce(0, +)
    }

    private var recentEscalationEntries: [String] {
        let log = router.escalationLog
        if log.count <= 50 { return log }
        return Array(log.suffix(50))
    }

    @ViewBuilder
    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}
