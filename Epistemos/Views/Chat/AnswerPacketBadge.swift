import SwiftUI

struct AnswerPacketBadge: View {
    let answerPacketId: String?
    let theme: EpistemosTheme
    var missingPacketConfidence: AnswerPacketConfidence = .blocked

    @State private var showsSubstrateDetail = false

    private var sink: LatestAnswerPacketSink { LatestAnswerPacketSink.shared }

    var body: some View {
        let packet = answerPacketId.flatMap { sink.packet(for: $0) }
        let kind = Self.claimKind(for: packet)
        let confidence = packet.map { Self.confidence(for: $0) } ?? missingPacketConfidence
        let substrateSummary = Self.substrateSummary(for: packet)

        HStack(spacing: 4) {
            chip(text: kind.rawValue, icon: kind.iconName, tint: kind.tint)
            chip(text: confidence.rawValue, icon: confidence.iconName, tint: confidence.tint)
        }
        .contentShape(Capsule())
        .onTapGesture {
            if packet != nil {
                showsSubstrateDetail = true
            }
        }
        .popover(isPresented: $showsSubstrateDetail, arrowEdge: .bottom) {
            AnswerPacketSubstrateDetailPopover(packet: packet, theme: theme)
                .frame(width: 340)
        }
        .help(helpText(kind: kind, confidence: confidence, packet: packet, substrateSummary: substrateSummary))
        .accessibilityLabel("Answer packet: \(kind.rawValue), \(confidence.rawValue)")
        .accessibilityHint("Click for UAS address, ACS anchor, plane, and residency details")
    }

    static func claimKind(for packet: AnswerPacket?) -> AnswerPacketClaimKind {
        guard let packet else { return .speculative }
        let kinds = packet.claims.map(\.kind)
        guard !kinds.isEmpty else { return .speculative }
        let nonStatic = kinds.filter { $0 != .staticFallbackAcknowledged }
        if nonStatic.count > 1 { return .synthesis }
        switch nonStatic.first ?? kinds[0] {
        case .empirical:
            return .empirical
        case .mathematical, .codeInvariant:
            return .mathematical
        case .causal:
            return .causal
        case .speculative, .staticFallbackAcknowledged:
            return .speculative
        }
    }

    static func confidence(for packet: AnswerPacket) -> AnswerPacketConfidence {
        switch packet.uiLabel {
        case .verified:
            return .verified
        case .plausibleButUnverified:
            return .plausible
        case .speculative:
            return .speculative
        case .blocked:
            return .blocked
        }
    }

    static func substrateClaims(for packet: AnswerPacket?) -> [Claim] {
        packet?.claims.filter { $0.uasAddress != nil || $0.acsAnchor != nil } ?? []
    }

    static func substrateSummary(for packet: AnswerPacket?) -> String {
        guard let packet else { return "No AnswerPacket bound." }
        let claimCount = substrateClaims(for: packet).count
        let residencyCount = packet.residencySignals.count
        if claimCount == 0, residencyCount == 0 {
            return "No UAS, ACS anchor, or residency detail on this packet."
        }
        return "\(claimCount) anchored claim\(claimCount == 1 ? "" : "s") · \(residencyCount) residency signal\(residencyCount == 1 ? "" : "s")"
    }

    private func chip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(tint.opacity(theme.isDark ? 0.14 : 0.10))
                .overlay(
                    Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.5)
                )
        )
    }

    private func helpText(
        kind: AnswerPacketClaimKind,
        confidence: AnswerPacketConfidence,
        packet: AnswerPacket?,
        substrateSummary: String
    ) -> String {
        guard let packet else {
            return "No AnswerPacket is bound to this row; confidence is blocked."
        }
        return "AnswerPacket \(packet.id): claim kind \(kind.rawValue), confidence \(confidence.rawValue). \(substrateSummary)"
    }
}

private struct AnswerPacketSubstrateDetailPopover: View {
    let packet: AnswerPacket?
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Substrate Detail")
                    .font(.headline)
                Spacer()
                if let packet {
                    Text(packet.id.prefix(8))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if let packet {
                detailBody(packet)
            } else {
                Text("No AnswerPacket is attached to this row.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func detailBody(_ packet: AnswerPacket) -> some View {
        let anchoredClaims = AnswerPacketBadge.substrateClaims(for: packet)
        if anchoredClaims.isEmpty {
            Text("No UAS address or ACS anchor is attached to this packet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(anchoredClaims.prefix(5).enumerated()), id: \.element.id) { _, claim in
                    claimDetail(claim)
                }
                if anchoredClaims.count > 5 {
                    Text("+ \(anchoredClaims.count - 5) more anchored claim\(anchoredClaims.count == 6 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if !packet.residencySignals.isEmpty {
            Divider()
            Text("\(packet.residencySignals.count) residency signal\(packet.residencySignals.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
            ForEach(Array(packet.residencySignals.prefix(3).enumerated()), id: \.offset) { index, signal in
                Text("r\(index + 1) verify \(signal.verificationScore, format: .number.precision(.fractionLength(2))) · privacy \(signal.privacy, format: .number.precision(.fractionLength(2))) · gain \(signal.gain, format: .number.precision(.fractionLength(2)))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func claimDetail(_ claim: Claim) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(claim.kind.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.resolved.accent.color)
            if let address = claim.uasAddress {
                detailLine("UAS", "\(address.kind) · \(address.hash.prefix(12))")
            }
            if let anchor = claim.acsAnchor {
                detailLine("ACS", "\(anchor.anchorId.prefix(12)) · \(anchor.theoremId)")
                detailLine("Plane", anchor.plane.displayName)
                detailLine("Residency", anchor.residency.displayName)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.resolved.foreground.color.opacity(theme.isDark ? 0.06 : 0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

enum AnswerPacketClaimKind: String, Sendable, CaseIterable {
    case synthesis
    case empirical
    case mathematical
    case causal
    case speculative

    var iconName: String {
        switch self {
        case .synthesis: "arrow.triangle.merge"
        case .empirical: "chart.xyaxis.line"
        case .mathematical: "function"
        case .causal: "point.3.connected.trianglepath.dotted"
        case .speculative: "questionmark.diamond"
        }
    }

    var tint: Color {
        switch self {
        case .synthesis: .blue
        case .empirical: .green
        case .mathematical: .indigo
        case .causal: .orange
        case .speculative: .purple
        }
    }
}

enum AnswerPacketConfidence: String, Sendable, CaseIterable {
    case verified
    case plausible
    case speculative
    case blocked

    var iconName: String {
        switch self {
        case .verified: "checkmark.seal.fill"
        case .plausible: "questionmark.circle"
        case .speculative: "sparkles"
        case .blocked: "exclamationmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .verified: .green
        case .plausible: .secondary
        case .speculative: .purple
        case .blocked: .red
        }
    }
}
