import Testing
import Foundation

@testable import Epistemos

// SUBSTRATE Phase 0 (owner 2026-06-20, docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md):
// FREEZE the model-handoff seam so the new model (SSM/dual-brain) + the Companion→Osaurus clones
// attach later with ZERO consumer rework. The frozen contract that everything downstream builds
// against: AnswerPacket.attentionMode ∈ {dynamic, static_fallback, unavailable}, honest default
// `unavailable` (a packet NEVER falsely implies dynamic interrupt execution), additive (a missing
// field decodes as unavailable), and wire-parity with the Rust serde mirror (rename_all=snake_case
// in agent_core/src/scope_rex/answer_packet.rs). A deliberate change must update BOTH sides + this
// test in lockstep — that is the whole point of the freeze.
@Suite("Substrate Phase 0 — AnswerPacket model-handoff seam freeze")
struct SubstratePhase0FreezeContractTests {

    // The seam enum is FROZEN to exactly these three wire values. The new model flips packets to
    // `.dynamic` later; until then everything is `static_fallback`/`unavailable`. Renaming or adding
    // a case is a cross-runtime wire break (the Rust serde snake_case variants must match), so this
    // assertion forces the change to be deliberate + paired with the Rust enum.
    @Test("AttentionMode wire values are frozen to {dynamic, static_fallback, unavailable}")
    func attentionModeWireValuesFrozen() {
        let frozen = Set(AttentionMode.allCases.map(\.rawValue))
        #expect(frozen == ["dynamic", "static_fallback", "unavailable"])
        // Each raw value pinned individually (catches a rename even if the case count stays 3).
        #expect(AttentionMode.dynamic.rawValue == "dynamic")
        #expect(AttentionMode.staticFallback.rawValue == "static_fallback")
        #expect(AttentionMode.unavailable.rawValue == "unavailable")
        // Honest default — never falsely dynamic. The new model lands → flips to `.dynamic`.
        #expect(AttentionMode.default == .unavailable)
    }

    // A populated attention_mode round-trips through the wire under the frozen key `attention_mode`
    // (the Rust mirror emits the same key + the same snake_case value).
    @Test("attention_mode round-trips through the wire under the frozen key + value")
    func attentionModeWireRoundTrip() throws {
        let packet = AnswerPacket(
            id: "ap-freeze",
            attentionMode: .staticFallback,
            witnessedStateRef: "ws-freeze",
            mutationEnvelopeRef: "me-freeze"
        )
        let data = try JSONEncoder().encode(packet)
        let wire = String(decoding: data, as: UTF8.self)
        // The frozen wire key + value (must byte-match the Rust serde field + snake_case variant).
        #expect(wire.contains("\"attention_mode\""))
        #expect(wire.contains("\"static_fallback\""))
        // Decodes back to the same mode (no drift across the encode/decode round-trip).
        let decoded = try JSONDecoder().decode(AnswerPacket.self, from: data)
        #expect(decoded.attentionMode == .staticFallback)
    }

    // The additive contract: a legacy wire packet WITHOUT attention_mode decodes as unavailable
    // (not dynamic) — so old packets + future consumers never misread the seam.
    @Test("a packet with no attention_mode decodes as unavailable (additive, never dynamic)")
    func missingAttentionModeIsUnavailable() throws {
        let json = """
        {
          "id": "ap-legacy-freeze",
          "claims": [],
          "residency_signals": [],
          "ui_label": "plausible_but_unverified",
          "witnessed_state_ref": "ws-legacy",
          "mutation_envelope_ref": "me-legacy"
        }
        """
        let packet = try JSONDecoder().decode(AnswerPacket.self, from: Data(json.utf8))
        #expect(packet.attentionMode == .unavailable)
        #expect(packet.attentionMode != .dynamic)
    }
}
