import Testing
@testable import Epistemos

@Suite("AnswerPacketBadge W-27")
struct AnswerPacketBadgeTests {
    @Test("multiple non-static claims render as synthesis")
    func multipleClaimsRenderSynthesis() {
        let packet = packet(
            claims: [
                claim(kind: .empirical),
                claim(kind: .causal),
            ],
            label: .verified
        )

        #expect(AnswerPacketBadge.claimKind(for: packet) == .synthesis)
        #expect(AnswerPacketBadge.confidence(for: packet) == .verified)
    }

    @Test("single claim kinds map to the visible five-arm taxonomy")
    func singleClaimKindsMapToVisibleTaxonomy() {
        #expect(AnswerPacketBadge.claimKind(for: packet(claims: [claim(kind: .empirical)])) == .empirical)
        #expect(AnswerPacketBadge.claimKind(for: packet(claims: [claim(kind: .mathematical)])) == .mathematical)
        #expect(AnswerPacketBadge.claimKind(for: packet(claims: [claim(kind: .codeInvariant)])) == .mathematical)
        #expect(AnswerPacketBadge.claimKind(for: packet(claims: [claim(kind: .causal)])) == .causal)
        #expect(AnswerPacketBadge.claimKind(for: packet(claims: [claim(kind: .speculative)])) == .speculative)
    }

    @Test("missing packet stays speculative and blocked instead of false green")
    func missingPacketIsNotPromoted() {
        #expect(AnswerPacketBadge.claimKind(for: nil) == .speculative)
    }

    @Test("substrate detail summarizes UAS ACS anchor and residency signals")
    func substrateDetailSummarizesAnchorsAndResidency() {
        let packet = packet(
            claims: [
                claim(
                    kind: .empirical,
                    uasAddress: UasAddress(kind: "claim", hash: "abcdef1234567890", createdAtMs: 42),
                    acsAnchor: AcsAnchor(
                        anchorId: "anchor-123456",
                        theoremId: "T14",
                        plane: .verification,
                        residency: .verifiedFloor,
                        salience: 0.8
                    )
                ),
                claim(kind: .speculative),
            ],
            residencySignals: [.neutral],
            label: .verified
        )

        #expect(AnswerPacketBadge.substrateClaims(for: packet).count == 1)
        #expect(AnswerPacketBadge.substrateSummary(for: packet) == "1 anchored claim · 1 residency signal")
    }

    @Test("AnswerPacketBadge exposes compact substrate popover source")
    func badgeExposesCompactSubstratePopoverSource() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/AnswerPacketBadge.swift")

        #expect(source.contains("AnswerPacketSubstrateDetailPopover"))
        #expect(source.contains("UAS address, ACS anchor, plane, and residency details"))
        #expect(source.contains("substrateSummary(for: packet)"))
        #expect(source.contains("anchor.plane.displayName"))
        #expect(source.contains("anchor.residency.displayName"))
    }

    private func packet(
        claims: [Claim],
        residencySignals: [ResidencySignal] = [],
        label: VRMLabel = .plausibleButUnverified
    ) -> AnswerPacket {
        AnswerPacket(
            id: "packet-test",
            claims: claims,
            residencySignals: residencySignals,
            uiLabel: label,
            witnessedStateRef: "state:test",
            mutationEnvelopeRef: "packet-test"
        )
    }

    private func claim(
        kind: ClaimKind,
        uasAddress: UasAddress? = nil,
        acsAnchor: AcsAnchor? = nil
    ) -> Claim {
        Claim(
            id: "claim-\(kind.rawValue)",
            text: "test",
            status: .active,
            createdAtMs: 0,
            kind: kind,
            uasAddress: uasAddress,
            acsAnchor: acsAnchor
        )
    }
}
