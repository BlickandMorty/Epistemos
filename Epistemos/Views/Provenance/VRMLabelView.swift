import Foundation
import AppKit
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
            ToolbarCapsuleButton(
                title: label.shortLabel,
                systemImage: symbol(for: label),
                role: controlRole(for: label),
                isActive: true,
                chromePolicy: .alwaysSurface,
                helpText: "Show provenance lineage",
                accessibilityLabel: label.accessibilityLabel
            ) {
                isLineagePinned.toggle()
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

    private func controlRole(for label: VRMLabel) -> NativeControlRole {
        switch label {
        case .verified:
            return .primaryAction
        case .plausibleButUnverified:
            return .toolbarUtility
        case .speculative:
            return .mode
        case .blocked:
            return .secondaryGhost
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

nonisolated enum VRMLineageDisplayBounds {
    static let maxDisplayedClaims = 20
    static let maxMetadataCharacters = 160
    static let maxClaimTextCharacters = 360

    static func metadata(_ value: String) -> String {
        capped(value, limit: maxMetadataCharacters)
    }

    static func claimText(_ value: String) -> String {
        capped(value, limit: maxClaimTextCharacters)
    }

    static func displayedClaims(_ claims: [Claim]) -> [Claim] {
        Array(claims.prefix(maxDisplayedClaims))
    }

    static func verificationScore(_ signals: [ResidencySignal]) -> Float? {
        signals
            .map(\.verificationScore)
            .filter(\.isFinite)
            .map { min(1, max(0, $0)) }
            .max()
    }

    private static func capped(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 32))
        let trimmed = normalizedDisplayText(bounded).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        guard limit > 3 else {
            return String(trimmed.prefix(limit))
        }
        return String(trimmed.prefix(limit - 3)) + "..."
    }

    private static func normalizedDisplayText(_ value: String) -> String {
        var result = String()
        result.reserveCapacity(value.count)
        var pendingSpace = false

        for scalar in value.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar) {
                pendingSpace = true
                continue
            }

            if pendingSpace, !result.isEmpty {
                result.append(" ")
            }
            result.unicodeScalars.append(scalar)
            pendingSpace = false
        }

        return result
    }
}

nonisolated struct VRMLineageExport: Codable, Equatable, Sendable {
    let schema: String
    let packetId: String
    let honestLabel: VRMLabel
    let modelLabel: String?
    let tierLabel: String?
    let acceptedAtMs: Int64?
    let generatedAtMs: Int64?
    let verificationScore: Float?
    let claims: [Claim]
    let residencySignals: [ResidencySignal]
    let attentionMode: AttentionMode
    let interruptBucket: InterruptBucket
    let witnessedStateRef: String
    let semanticDeltaRef: String?
    let mutationEnvelopeRef: String

    enum CodingKeys: String, CodingKey {
        case schema
        case packetId = "packet_id"
        case honestLabel = "honest_label"
        case modelLabel = "model_label"
        case tierLabel = "tier_label"
        case acceptedAtMs = "accepted_at_ms"
        case generatedAtMs = "generated_at_ms"
        case verificationScore = "verification_score"
        case claims
        case residencySignals = "residency_signals"
        case attentionMode = "attention_mode"
        case interruptBucket = "interrupt_bucket"
        case witnessedStateRef = "witnessed_state_ref"
        case semanticDeltaRef = "semantic_delta_ref"
        case mutationEnvelopeRef = "mutation_envelope_ref"
    }

    static func make(
        packet: AnswerPacket,
        modelLabel: String?,
        tierLabel: String?,
        acceptedAt: Date?
    ) -> VRMLineageExport? {
        guard let honestLabel = VRMLabel.honestLabel(for: packet) else { return nil }
        return VRMLineageExport(
            schema: "epistemos.vrm_lineage.v1",
            packetId: packet.id,
            honestLabel: honestLabel,
            modelLabel: modelLabel,
            tierLabel: tierLabel,
            acceptedAtMs: acceptedAt.map(Self.millisecondsSinceEpoch),
            generatedAtMs: packet.activeClaims.map(\.createdAtMs).max(),
            verificationScore: VRMLineageDisplayBounds.verificationScore(packet.residencySignals),
            claims: packet.activeClaims,
            residencySignals: packet.residencySignals,
            attentionMode: packet.attentionMode,
            interruptBucket: packet.interruptBucket,
            witnessedStateRef: packet.witnessedStateRef,
            semanticDeltaRef: packet.semanticDeltaRef,
            mutationEnvelopeRef: packet.mutationEnvelopeRef
        )
    }

    func encodedJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"schema":"epistemos.vrm_lineage.v1","error":"encoding_failed"}"#
        }
        return string
    }

    private static func millisecondsSinceEpoch(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    }
}

private struct VRMLineageCard: View {
    let packet: AnswerPacket
    let label: VRMLabel
    let modelLabel: String?
    let tierLabel: String?
    let acceptedAt: Date?

    @Environment(UIState.self) private var ui
    @State private var didCopyLineage = false

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    private var generatedAt: Date? {
        packet.activeClaims
            .map(\.createdAtMs)
            .max()
            .map { Date(timeIntervalSince1970: TimeInterval($0) / 1000.0) }
    }

    private var verificationScore: Float? {
        VRMLineageDisplayBounds.verificationScore(packet.residencySignals)
    }

    private var displayedClaims: [Claim] {
        VRMLineageDisplayBounds.displayedClaims(packet.activeClaims)
    }

    private var omittedClaimCount: Int {
        max(0, packet.activeClaims.count - displayedClaims.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(mutedTint)
                Text(label.shortLabel)
                    .font(.headline)
                Spacer(minLength: 0)
                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: didCopyLineage ? "checkmark" : "doc.on.doc",
                    role: .toolbarUtility,
                    isActive: didCopyLineage,
                    helpText: "Copy lineage JSON",
                    accessibilityLabel: didCopyLineage ? "Copied lineage JSON" : "Copy lineage JSON"
                ) {
                    copyLineageExport()
                }
            }

            metadataGrid

            Color.clear.frame(height: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Claims")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(mutedTint)
                if packet.activeClaims.isEmpty {
                    Text("No active provenance claims.")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                } else {
                    ForEach(displayedClaims, id: \.id) { claim in
                        ClaimLineageRow(claim: claim, packetID: packet.id)
                    }
                    if omittedClaimCount > 0 {
                        Text("\(omittedClaimCount) additional claims omitted from display.")
                            .font(.caption2)
                            .foregroundStyle(mutedTint)
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
                .foregroundStyle(mutedTint)
                .frame(width: 72, alignment: .leading)
            Text(VRMLineageDisplayBounds.metadata(value))
                .lineLimit(2)
        }
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private func copyLineageExport() {
        guard let export = VRMLineageExport.make(
            packet: packet,
            modelLabel: modelLabel,
            tierLabel: tierLabel,
            acceptedAt: acceptedAt
        ) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(export.encodedJSONString(), forType: .string)
        didCopyLineage = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            didCopyLineage = false
        }
    }
}

private struct ClaimLineageRow: View {
    let claim: Claim
    let packetID: String

    @Environment(UIState.self) private var ui

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

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
                        .foregroundStyle(mutedTint)
                    if claim.isVerifiedByAnchor(forPacketID: packetID) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(mutedTint)
                            .accessibilityLabel("Packet-bound verification anchor")
                    } else if claim.hasUasAddress {
                        Image(systemName: "number")
                            .font(.caption2)
                            .foregroundStyle(mutedTint)
                            .accessibilityLabel("UAS address")
                    }
                }
                Text(VRMLineageDisplayBounds.claimText(claim.text))
                    .font(.caption2)
                    .foregroundStyle(mutedTint)
                    .lineLimit(3)
            }
        }
    }

    private var statusTint: Color {
        switch claim.status {
        case .active:
            return ui.theme.resolved.accent.color
        case .atRisk, .needsRevalidation:
            return ui.theme.resolved.headingAccent.color
        case .retracted:
            return ui.theme.resolved.mutedForeground.color
        }
    }
}
