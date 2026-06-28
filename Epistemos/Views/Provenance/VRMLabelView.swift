import Foundation
import SwiftUI

struct ChatMessageVRMLabelView: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .assistant,
           let packetID = message.answerPacketId,
           let packet = LatestAnswerPacketSink.shared.packet(for: packetID) {
            VRMLabelView(
                packet: packet,
                modelLabel: message.resolvedModelLabel,
                tierLabel: message.mode?.rawValue,
                acceptedAt: message.createdAt
            )
        }
    }
}

struct VRMLabelView: View {
    let packet: AnswerPacket
    let modelLabel: String?
    let tierLabel: String?
    let acceptedAt: Date?

    @State private var isHoveringLineage = false
    @State private var isLineagePinned = false

    private var showsLineage: Binding<Bool> {
        Binding {
            isHoveringLineage || isLineagePinned
        } set: { isPresented in
            if !isPresented {
                isHoveringLineage = false
                isLineagePinned = false
            }
        }
    }

    init(
        packet: AnswerPacket,
        modelLabel: String? = nil,
        tierLabel: String? = nil,
        acceptedAt: Date? = nil
    ) {
        self.packet = packet
        self.modelLabel = modelLabel
        self.tierLabel = tierLabel
        self.acceptedAt = acceptedAt
    }

    private var label: VRMLabel? {
        VRMLabel.honestLabel(for: packet)
    }

    var body: some View {
        if let label {
            Button {
                isLineagePinned.toggle()
            } label: {
                Label(label.shortLabel, systemImage: symbol(for: label))
                    .font(.caption2.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint(for: label))
            .background(tint(for: label).opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(tint(for: label).opacity(0.28), lineWidth: 0.75)
            }
            .accessibilityLabel(label.accessibilityLabel)
            .onHover { hovering in
                isHoveringLineage = hovering
            }
            .popover(isPresented: showsLineage, arrowEdge: .bottom) {
                VRMLineageCard(
                    packet: packet,
                    label: label,
                    modelLabel: modelLabel,
                    tierLabel: tierLabel,
                    acceptedAt: acceptedAt
                )
            }
        }
    }

    private func tint(for label: VRMLabel) -> Color {
        switch label {
        case .verified: return .green
        case .plausibleButUnverified: return .orange
        case .speculative: return .purple
        case .blocked: return .red
        }
    }

    private func symbol(for label: VRMLabel) -> String {
        switch label {
        case .verified: return "checkmark.shield"
        case .plausibleButUnverified: return "shield.lefthalf.filled"
        case .speculative: return "questionmark.diamond"
        case .blocked: return "xmark.octagon"
        }
    }
}

private struct VRMLineageCard: View {
    let packet: AnswerPacket
    let label: VRMLabel
    let modelLabel: String?
    let tierLabel: String?
    let acceptedAt: Date?

    private var generatedAt: Date? {
        packet.claims
            .map(\.createdAtMs)
            .max()
            .map { Date(timeIntervalSince1970: TimeInterval($0) / 1000.0) }
    }

    private var verificationScore: Float? {
        packet.residencySignals.map(\.verificationScore).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.secondary)
                Text(label.shortLabel)
                    .font(.headline)
                Spacer(minLength: 0)
            }

            metadataGrid

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Claims")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if packet.claims.isEmpty {
                    Text("No active provenance claims.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(packet.claims, id: \.id) { claim in
                        ClaimLineageRow(claim: claim)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
    }

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 5) {
            metadataRow("Model", modelLabel ?? "unknown")
            metadataRow("Tier", tierLabel ?? "unknown")
            metadataRow("Verification", formattedVerificationScore)
            metadataRow("Generated", generatedAt.map(Self.formatDate) ?? "unknown")
            metadataRow("Accepted", acceptedAt.map(Self.formatDate) ?? "unknown")
        }
        .font(.caption)
    }

    private var formattedVerificationScore: String {
        guard let verificationScore else { return "unknown" }
        return String(format: "%.2f", Double(verificationScore))
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .lineLimit(2)
        }
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct ClaimLineageRow: View {
    let claim: Claim

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(statusTint)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(claim.kind.rawValue)
                        .font(.caption.weight(.semibold))
                    Text(claim.status.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if claim.hasEvidenceAnchor {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Anchored evidence")
                    }
                }
                Text(claim.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var statusTint: Color {
        switch claim.status {
        case .active: return .green
        case .atRisk, .needsRevalidation: return .orange
        case .retracted: return .red
        }
    }
}
