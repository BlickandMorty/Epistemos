import Observation
import SwiftUI

// UAS: vault-recall/provenance-trace-sink
// Plane: RuntimePlane::Projection
// Residency: ResidencyTier::CurrentApp
@MainActor
@Observable
final class VaultRecallTraceSink {
    static let shared = VaultRecallTraceSink()

    private var tracesByAnswerPacketId: [String: VaultRecallTrace] = [:]
    private var tracesByMessageId: [String: VaultRecallTrace] = [:]
    private let maxEntries = 64

    private init() {}

    func record(messageId: String, answerPacketId: String?, trace: VaultRecallTrace) {
        let cleanMessageId = messageId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanMessageId.isEmpty {
            tracesByMessageId[cleanMessageId] = trace
        }
        if let cleanPacketId = answerPacketId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cleanPacketId.isEmpty {
            tracesByAnswerPacketId[cleanPacketId] = trace
        }
        trimIfNeeded()
    }

    func trace(answerPacketId: String?, messageId: String?) -> VaultRecallTrace? {
        if let cleanPacketId = answerPacketId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cleanPacketId.isEmpty,
           let trace = tracesByAnswerPacketId[cleanPacketId] {
            return trace
        }
        if let cleanMessageId = messageId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cleanMessageId.isEmpty {
            return tracesByMessageId[cleanMessageId]
        }
        return nil
    }

    private func trimIfNeeded() {
        guard tracesByMessageId.count > maxEntries || tracesByAnswerPacketId.count > maxEntries else { return }
        tracesByMessageId = Dictionary(tracesByMessageId.suffix(maxEntries), uniquingKeysWith: { _, latest in latest })
        tracesByAnswerPacketId = Dictionary(tracesByAnswerPacketId.suffix(maxEntries), uniquingKeysWith: { _, latest in latest })
    }
}

struct VaultRecallProvenanceCard: View {
    let trace: VaultRecallTrace?
    let loadedNoteTitles: [String]
    let sourceCount: Int
    let theme: EpistemosTheme
    var compact = false

    private var backend: VaultRecallBackend {
        trace.map(VaultRecallBridge.detectedBackend(from:)) ?? .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: 6) {
                Image(systemName: headerIconName)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                Text(headerTitle)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                Spacer(minLength: 0)
                if let trace {
                    Text("\(trace.candidatesRetained)/\(trace.candidatePoolSize) retained")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }
            .foregroundStyle(theme.textSecondary)

            if let trace {
                traceSummary(trace)
                if !compact {
                    ForEach(Array(trace.candidates.prefix(3).enumerated()), id: \.offset) { _, candidate in
                        candidateLine(candidate)
                    }
                }
            } else if !loadedNoteTitles.isEmpty || sourceCount > 0 {
                Text("Loaded \(max(loadedNoteTitles.count, sourceCount)) cited note\(max(loadedNoteTitles.count, sourceCount) == 1 ? "" : "s"); trace unavailable for this row.")
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No vault notes were loaded for this answer.")
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 7 : 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.055 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.32 : 0.22), lineWidth: 0.7)
        )
        .help(helpText)
    }

    private func traceSummary(_ trace: VaultRecallTrace) -> some View {
        HStack(spacing: 5) {
            VaultRecallSurfaceChip(text: backendLabel, tint: backendTint, theme: theme)
            if let tier = trace.ladderTier, !tier.isEmpty {
                VaultRecallSurfaceChip(text: tier, tint: theme.textSecondary, theme: theme)
            }
            if let pageGather = trace.pageGather {
                VaultRecallSurfaceChip(text: "page_gather", tint: .orange, theme: theme)
                if let schedule = pageGather.scheduleLabel {
                    VaultRecallSurfaceChip(text: schedule, tint: .orange, theme: theme)
                }
                VaultRecallSurfaceChip(text: "\(pageGather.deferredFalsifier) pending", tint: .orange, theme: theme)
            }
            ForEach(trace.signalSummary.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { signal in
                VaultRecallSurfaceChip(text: signal.rawValue, tint: theme.resolved.accent.color, theme: theme)
            }
            if trace.allChatterFallback {
                VaultRecallSurfaceChip(text: "weak query", tint: .orange, theme: theme)
            }
        }
    }

    private func candidateLine(_ candidate: VaultRecallCandidate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(candidate.title?.isEmpty == false ? candidate.title! : candidate.path)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color)
                .lineLimit(1)
            Text(candidate.selectionReason)
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(2)
        }
    }

    private var headerTitle: String {
        guard let trace else {
            return loadedNoteTitles.isEmpty && sourceCount == 0
                ? "No vault retrieval"
                : "Vault trace unavailable"
        }
        switch backend {
        case .real:
            return trace.candidatesRetained == 0 ? "Vault retrieval checked" : "Vault provenance"
        case .stub:
            return "Vault trace scaffold"
        case .unknown:
            return "Vault trace unknown"
        }
    }

    private var headerIconName: String {
        guard trace != nil else {
            return loadedNoteTitles.isEmpty && sourceCount == 0
                ? "slash.circle"
                : "exclamationmark.triangle"
        }
        switch backend {
        case .real:
            return "checkmark.shield"
        case .stub:
            return "wrench.and.screwdriver"
        case .unknown:
            return "questionmark.diamond"
        }
    }

    private var backendLabel: String {
        switch backend {
        case .real:
            return "real path"
        case .stub:
            return "scaffold"
        case .unknown:
            return "unknown"
        }
    }

    private var backendTint: Color {
        switch backend {
        case .real:
            return theme.resolved.accent.color
        case .stub:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var helpText: String {
        guard let trace else {
            return loadedNoteTitles.isEmpty
                ? "No vault retrieval trace is attached to this row."
                : "This row has loaded note titles but no stored recall trace."
        }
        let tier = trace.ladderTier ?? "unknown"
        if let pageGather = trace.pageGather {
            let schedule = pageGather.scheduleLabel.map { " Schedule: \($0)." } ?? ""
            return "Vault recall trace: \(tier), \(trace.candidatesRetained) retained from \(trace.candidatePoolSize). PageGather escalation observed from \(pageGather.source);\(schedule) \(pageGather.deferredFalsifier) measurement is pending."
        }
        return "Vault recall trace: \(tier), \(trace.candidatesRetained) retained from \(trace.candidatePoolSize)."
    }
}

struct VaultRecallCandidateChipStrip: View {
    let candidate: VaultRecallCandidate?
    let fallbackText: String?
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 5) {
            if let candidate {
                ForEach(candidate.signals.map(\.signal).uniquedSignals(), id: \.self) { signal in
                    VaultRecallSurfaceChip(text: signal.rawValue, tint: theme.resolved.accent.color, theme: theme)
                }
                VaultRecallSurfaceChip(text: candidate.selectionReason, tint: theme.textSecondary, theme: theme)
            } else if let fallbackText, !fallbackText.isEmpty {
                VaultRecallSurfaceChip(text: fallbackText, tint: theme.textSecondary, theme: theme)
            }
        }
    }
}

struct VaultRecallHaloProvenance: View {
    let hit: ShadowHit
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 5) {
            VaultRecallSurfaceChip(text: hit.source.isEmpty ? hit.domain.rawValue : hit.source, tint: theme.textSecondary, theme: theme)
            VaultRecallSurfaceChip(text: "score \(Int(max(0, min(hit.score, 1)) * 100))%", tint: theme.resolved.accent.color, theme: theme)
            if let vault = hit.originVaultKey, !vault.isEmpty {
                VaultRecallSurfaceChip(text: vault, tint: theme.textTertiary, theme: theme)
            }
        }
    }
}

struct VaultRecallSurfaceChip: View {
    let text: String
    let tint: Color
    let theme: EpistemosTheme

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(theme.isDark ? 0.16 : 0.10)))
    }
}

private extension Array where Element == VaultRecallSignal {
    func uniquedSignals() -> [VaultRecallSignal] {
        var seen = Set<VaultRecallSignal>()
        return filter { seen.insert($0).inserted }
    }
}
