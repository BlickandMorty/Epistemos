import Testing
@testable import Epistemos

@Suite("AnswerPacket attention-mode invariants")
struct AnswerPacketAttentionModeTests {
    @Test("missing attention_mode decodes as unavailable")
    func missingAttentionModeDecodesAsUnavailable() throws {
        let json = """
        {
          "id": "ap-legacy",
          "claims": [],
          "residency_signals": [],
          "ui_label": "plausible_but_unverified",
          "witnessed_state_ref": "ws-legacy",
          "mutation_envelope_ref": "me-legacy"
        }
        """

        let packet = try JSONDecoder().decode(AnswerPacket.self, from: Data(json.utf8))

        #expect(packet.attentionMode == .unavailable)
        #expect(packet.requiresStaticFallbackAcknowledgement == false)
        #expect(packet.acknowledgesStaticFallback == true)
    }

    @Test("static fallback requires explicit acknowledgement claim")
    func staticFallbackRequiresExplicitAcknowledgementClaim() {
        let unacknowledged = AnswerPacket(
            id: "ap-static",
            attentionMode: .staticFallback,
            witnessedStateRef: "ws-static",
            mutationEnvelopeRef: "me-static"
        )

        #expect(unacknowledged.requiresStaticFallbackAcknowledgement == true)
        #expect(unacknowledged.acknowledgesStaticFallback == false)
        #expect(unacknowledged.attentionModeClaimsAreConsistent == false)

        let acknowledged = AnswerPacket(
            id: "ap-static",
            claims: [
                Claim(
                    id: "claim-static-fallback",
                    text: "static 9:1 fallback engaged because dynamic interrupt signals were unavailable",
                    status: .active,
                    createdAtMs: 1_745_000_000_000,
                    kind: .staticFallbackAcknowledged
                ),
            ],
            attentionMode: .staticFallback,
            witnessedStateRef: "ws-static",
            mutationEnvelopeRef: "me-static"
        )

        #expect(acknowledged.requiresStaticFallbackAcknowledgement == true)
        #expect(acknowledged.acknowledgesStaticFallback == true)
        #expect(acknowledged.attentionModeClaimsAreConsistent == true)
    }

    @Test("static fallback acknowledgement claim is forbidden outside static fallback")
    func staticFallbackAcknowledgementClaimIsForbiddenOutsideStaticFallback() {
        let contradictory = AnswerPacket(
            id: "ap-dynamic",
            claims: [
                Claim(
                    id: "claim-static-fallback",
                    text: "static 9:1 fallback engaged because dynamic interrupt signals were unavailable",
                    status: .active,
                    createdAtMs: 1_745_000_000_000,
                    kind: .staticFallbackAcknowledged
                ),
            ],
            attentionMode: .dynamic,
            witnessedStateRef: "ws-dynamic",
            mutationEnvelopeRef: "me-dynamic"
        )

        #expect(contradictory.requiresStaticFallbackAcknowledgement == false)
        #expect(contradictory.acknowledgesStaticFallback == true)
        #expect(contradictory.attentionModeClaimsAreConsistent == false)
    }
}
