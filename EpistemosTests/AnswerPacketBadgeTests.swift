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

    private func packet(
        claims: [Claim],
        label: VRMLabel = .plausibleButUnverified
    ) -> AnswerPacket {
        AnswerPacket(
            id: "packet-test",
            claims: claims,
            uiLabel: label,
            witnessedStateRef: "state:test",
            mutationEnvelopeRef: "packet-test"
        )
    }

    private func claim(kind: ClaimKind) -> Claim {
        Claim(
            id: "claim-\(kind.rawValue)",
            text: "test",
            status: .active,
            createdAtMs: 0,
            kind: kind
        )
    }
}
