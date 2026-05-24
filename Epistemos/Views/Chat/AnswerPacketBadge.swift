import SwiftUI

struct AnswerPacketBadge: View {
    let answerPacketId: String?
    let theme: EpistemosTheme
    var missingPacketConfidence: AnswerPacketConfidence = .blocked

    private var sink: LatestAnswerPacketSink { LatestAnswerPacketSink.shared }

    var body: some View {
        let packet = answerPacketId.flatMap { sink.packet(for: $0) }
        let kind = Self.claimKind(for: packet)
        let confidence = packet.map { Self.confidence(for: $0) } ?? missingPacketConfidence

        HStack(spacing: 4) {
            chip(text: kind.rawValue, icon: kind.iconName, tint: kind.tint)
            chip(text: confidence.rawValue, icon: confidence.iconName, tint: confidence.tint)
        }
        .help(helpText(kind: kind, confidence: confidence, packet: packet))
        .accessibilityLabel("Answer packet: \(kind.rawValue), \(confidence.rawValue)")
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
        packet: AnswerPacket?
    ) -> String {
        guard let packet else {
            return "No AnswerPacket is bound to this row; confidence is blocked."
        }
        return "AnswerPacket \(packet.id): claim kind \(kind.rawValue), confidence \(confidence.rawValue)."
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
