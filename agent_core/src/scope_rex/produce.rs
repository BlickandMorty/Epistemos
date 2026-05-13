// V6.2 AnswerPacket production caller (2026-05-12)
//
// This module is the first production-side caller of `AnswerPacket::new`
// in agent_core. Before this slice, only test code constructed
// AnswerPackets — the Rust schema sat next to the Swift emitter as a
// dormant mirror. This module bridges the gap by producing a fully-
// populated Rust AnswerPacket from the same runtime signals the Swift
// `AnswerPacketEmitter.turnCompletionStub` already uses, then exposing
// the JSON form via an FFI surface (see `bridge::produce_answer_packet_json`).
//
// What this commit advances:
//
//   AnswerPacket emission ladder state:
//     implemented           ✅ (schema defined since c0c14f98e)
//     emitted               ✅ (Swift ring + audit channel)
//     partially populated   ✅ (attention_mode + interrupt_bucket from
//                              real runtime state per the V6.2
//                              substrate-hook trio 42c12b6fd / f4ab4e321
//                              / 8c05c7f43)
//     populated             ◐  ← *this commit*: Rust-side production
//                              caller exists; emits non-empty claims +
//                              residency. Swift consumer wiring is a
//                              follow-up.
//     rendered (FULL)       ✅ (per-bubble VRMLabelView)
//     canonical-product-surface  ⬜ pending
//
// What this commit does NOT do (scope discipline):
//   - It does NOT replace the Swift `AnswerPacketEmitter.turnCompletionStub`.
//     The Swift stub continues to construct + emit the Swift-side packet
//     for the audit ring; this Rust path stands alongside it as a
//     production caller of the canonical Rust schema. A future commit
//     can switch the Swift emitter to consume the Rust JSON if the
//     parity tests prove out.
//   - It does NOT plumb residency-governor outputs. Each turn emits
//     a single `ResidencySignal::neutral()` placeholder, documented
//     here as a known gap. Real residency signals land when the
//     governor itself wires (W4 + W5).
//
// Honest-handle doctrine: the FFI returns a serialized JSON string, not
// a UniFFI struct, so the Rust schema can evolve (add fields, change
// internals) without forcing every Swift caller to update its decoder
// — the Swift consumer uses `decodeIfPresent` for forward-compat on
// any new fields, same pattern as the cognitive-DAG stats client.

use crate::provenance::ledger::{Claim, ClaimId, ClaimKind, ClaimStatus};
use crate::scope_rex::answer_packet::{
    AnswerPacket, AnswerPacketId, AttentionMode, MutationEnvelopeId, ResidencySignal, VrmLabel,
    WitnessedStateId,
};

/// Inputs to the V6.2 turn-completion packet producer. Mirrors the
/// fields the Swift `AnswerPacketEmitter.turnCompletionStub` collects
/// at `StreamingDelegate.onComplete` time.
#[derive(Debug, Clone, PartialEq)]
pub struct TurnCompletionInputs {
    /// Caller-generated packet id (typically a UUID). Empty string
    /// falls back to a sentinel `"unset-turn"` so the packet is still
    /// well-formed.
    pub packet_id: String,
    /// Provider stop reason (`"end_turn"`, `"tool_use"`, `"max_tokens"`, …).
    pub stop_reason: String,
    /// Output token count for the turn. Used as the body of the
    /// empirical self-witness claim.
    pub output_tokens: u32,
    /// Attention-mode classification for this turn.
    pub attention_mode: AttentionMode,
    /// VRM label to stamp on the packet. Defaults to
    /// `PlausibleButUnverified` if the caller doesn't have a stronger
    /// signal.
    pub vrm_label: VrmLabel,
    /// Identifier of the witnessed-state ledger entry this turn read.
    /// Until the witnessed-state ledger is wired, callers pass a
    /// per-turn placeholder.
    pub witnessed_state_id: String,
    /// Identifier of the mutation envelope this turn produced. Until
    /// the envelope ledger is wired, callers pass a per-turn placeholder.
    pub mutation_envelope_id: String,
    /// Wall-clock millis used to stamp claim creation timestamps.
    pub created_at_ms: i64,
}

impl TurnCompletionInputs {
    /// Smallest well-formed input set. Use the builder-style setters
    /// to override individual fields per turn.
    pub fn default_for_id(packet_id: impl Into<String>) -> Self {
        Self {
            packet_id: packet_id.into(),
            stop_reason: "end_turn".to_string(),
            output_tokens: 0,
            attention_mode: AttentionMode::Unavailable,
            vrm_label: VrmLabel::PlausibleButUnverified,
            witnessed_state_id: "ws-turn".to_string(),
            mutation_envelope_id: "me-turn".to_string(),
            created_at_ms: 0,
        }
    }
}

/// Build a fully-populated AnswerPacket from a turn-completion's
/// runtime inputs. Returns the packet by value; the FFI surface
/// (`bridge::produce_answer_packet_json`) wraps this and serializes
/// to JSON for cross-runtime consumption.
///
/// Claims produced (every turn carries at least the self-witness):
///   1. Empirical self-witness: "turn completed: N tokens, stop=S"
///   2. Empirical tool-use observation (only when stop_reason == "tool_use")
///   3. StaticFallbackAcknowledged (only when attention_mode == StaticFallback)
///      — required by `AnswerPacket::acknowledges_static_fallback` for
///      doctrine consistency. Omitting this would emit a malformed
///      packet that fails the consistency check.
///
/// Residency signal: one `ResidencySignal::neutral()` per turn.
/// Documented placeholder until the Residency Governor (W4) lands.
pub fn produce_turn_completion_packet(inputs: TurnCompletionInputs) -> AnswerPacket {
    let packet_id = if inputs.packet_id.is_empty() {
        AnswerPacketId::new("unset-turn")
    } else {
        AnswerPacketId::new(inputs.packet_id.clone())
    };

    let mut packet = AnswerPacket::new(
        packet_id,
        WitnessedStateId::new(if inputs.witnessed_state_id.is_empty() {
            "ws-turn".to_string()
        } else {
            inputs.witnessed_state_id.clone()
        }),
        MutationEnvelopeId::new(if inputs.mutation_envelope_id.is_empty() {
            "me-turn".to_string()
        } else {
            inputs.mutation_envelope_id.clone()
        }),
    )
    .with_attention_mode(inputs.attention_mode)
    .with_ui_label(inputs.vrm_label);

    // (1) Empirical self-witness — every turn carries one.
    let self_witness = Claim {
        id: ClaimId::new(format!("{}::self-witness", packet.id.0)),
        text: format!(
            "turn completed: {} output tokens, stop_reason={}",
            inputs.output_tokens, inputs.stop_reason
        ),
        status: ClaimStatus::Active,
        created_at_ms: inputs.created_at_ms,
        kind: ClaimKind::Empirical,
    };
    packet = packet.push_claim(self_witness);

    // (2) Empirical tool-use observation — when the provider returned
    // tool_use, the agent is requesting an external tool. Record as a
    // claim so audit consumers can correlate AnswerPacket emission
    // with tool execution.
    if inputs.stop_reason == "tool_use" {
        let tool_witness = Claim {
            id: ClaimId::new(format!("{}::tool-use", packet.id.0)),
            text: "agent requested tool execution at turn boundary".to_string(),
            status: ClaimStatus::Active,
            created_at_ms: inputs.created_at_ms,
            kind: ClaimKind::Empirical,
        };
        packet = packet.push_claim(tool_witness);
    }

    // (3) Static-fallback acknowledgement — REQUIRED when attention_mode
    // is StaticFallback. Without this claim, the packet fails
    // `AnswerPacket::acknowledges_static_fallback` and is malformed.
    if inputs.attention_mode == AttentionMode::StaticFallback {
        let ack = Claim {
            id: ClaimId::new(format!("{}::static-fallback-ack", packet.id.0)),
            text:
                "static 9:1 hybrid attention floor used (dynamic interrupt signals unavailable)"
                    .to_string(),
            status: ClaimStatus::Active,
            created_at_ms: inputs.created_at_ms,
            kind: ClaimKind::StaticFallbackAcknowledged,
        };
        packet = packet.push_claim(ack);
    }

    // Residency signal — neutral placeholder until the Residency
    // Governor lands (W4). Emitting a real signal would lie about a
    // sampling path that doesn't exist yet; the neutral signal is the
    // honest "I have no opinion" answer the doctrine prescribes.
    packet = packet.push_residency_signal(ResidencySignal::neutral());

    packet
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_turn_produces_well_formed_packet_with_self_witness() {
        let inputs = TurnCompletionInputs::default_for_id("test-1");
        let pkt = produce_turn_completion_packet(inputs);
        assert_eq!(pkt.id.0, "test-1");
        assert_eq!(pkt.attention_mode, AttentionMode::Unavailable);
        assert_eq!(pkt.ui_label, VrmLabel::PlausibleButUnverified);
        assert_eq!(pkt.claims.len(), 1);
        assert_eq!(pkt.claims[0].kind, ClaimKind::Empirical);
        assert!(pkt.claims[0].text.contains("turn completed"));
        assert_eq!(pkt.residency_signals.len(), 1);
        // Default residency is neutral — verification_score = 0.5.
        assert!((pkt.residency_signals[0].verification_score - 0.5).abs() < 1e-6);
    }

    #[test]
    fn tool_use_stop_emits_two_empirical_claims() {
        let mut inputs = TurnCompletionInputs::default_for_id("test-2");
        inputs.stop_reason = "tool_use".to_string();
        inputs.output_tokens = 120;
        let pkt = produce_turn_completion_packet(inputs);
        assert_eq!(pkt.claims.len(), 2);
        assert!(pkt.claims.iter().all(|c| c.kind == ClaimKind::Empirical));
        assert!(pkt.claims.iter().any(|c| c.text.contains("tool execution")));
    }

    #[test]
    fn static_fallback_emits_ack_claim_and_passes_consistency() {
        let mut inputs = TurnCompletionInputs::default_for_id("test-3");
        inputs.attention_mode = AttentionMode::StaticFallback;
        let pkt = produce_turn_completion_packet(inputs);
        // Self-witness + StaticFallbackAcknowledged.
        assert_eq!(pkt.claims.len(), 2);
        assert!(
            pkt.claims
                .iter()
                .any(|c| c.kind == ClaimKind::StaticFallbackAcknowledged),
            "static fallback turn must emit a StaticFallbackAcknowledged claim"
        );
        // Doctrine-consistency invariant: the packet must satisfy the
        // acknowledgement check, otherwise it's malformed.
        assert!(pkt.attention_mode_claims_are_consistent());
        assert!(pkt.acknowledges_static_fallback());
    }

    #[test]
    fn dynamic_attention_does_not_emit_static_ack_claim() {
        let mut inputs = TurnCompletionInputs::default_for_id("test-4");
        inputs.attention_mode = AttentionMode::Dynamic;
        let pkt = produce_turn_completion_packet(inputs);
        assert_eq!(pkt.claims.len(), 1);
        assert_eq!(pkt.claims[0].kind, ClaimKind::Empirical);
        assert!(
            !pkt.claims
                .iter()
                .any(|c| c.kind == ClaimKind::StaticFallbackAcknowledged),
            "dynamic attention must not emit a StaticFallbackAcknowledged claim"
        );
        // Consistency check still passes (no ack required for dynamic).
        assert!(pkt.attention_mode_claims_are_consistent());
    }

    #[test]
    fn empty_packet_id_falls_back_to_unset_turn_sentinel() {
        // Defensive: if the caller passes an empty id, the constructor
        // substitutes a sentinel rather than producing an unidentified
        // packet. Audit consumers can filter on this id to detect
        // misconfigured callers.
        let mut inputs = TurnCompletionInputs::default_for_id("test-5");
        inputs.packet_id = "".to_string();
        let pkt = produce_turn_completion_packet(inputs);
        assert_eq!(pkt.id.0, "unset-turn");
    }

    #[test]
    fn empty_witness_and_envelope_ids_fall_back_to_sentinels() {
        let mut inputs = TurnCompletionInputs::default_for_id("test-6");
        inputs.witnessed_state_id = "".to_string();
        inputs.mutation_envelope_id = "".to_string();
        let pkt = produce_turn_completion_packet(inputs);
        assert_eq!(pkt.witnessed_state_ref.0, "ws-turn");
        assert_eq!(pkt.mutation_envelope_ref.0, "me-turn");
    }

    #[test]
    fn produced_packet_serializes_to_json_with_required_fields() {
        // Smoke test: the production caller's output must serialize to
        // the canonical AnswerPacket JSON shape so the Swift consumer
        // can decode it on the same Codable contract.
        let inputs = TurnCompletionInputs {
            packet_id: "test-7".to_string(),
            stop_reason: "end_turn".to_string(),
            output_tokens: 250,
            attention_mode: AttentionMode::Dynamic,
            vrm_label: VrmLabel::Verified,
            witnessed_state_id: "ws-7".to_string(),
            mutation_envelope_id: "me-7".to_string(),
            created_at_ms: 1715000000000,
        };
        let pkt = produce_turn_completion_packet(inputs);
        let json = serde_json::to_string(&pkt).expect("AnswerPacket must serialize");
        assert!(json.contains("\"id\""), "missing id field");
        assert!(json.contains("\"claims\""), "missing claims field");
        assert!(
            json.contains("\"residency_signals\""),
            "missing residency_signals field"
        );
        assert!(json.contains("\"ui_label\""));
        assert!(json.contains("\"attention_mode\":\"dynamic\""));
        assert!(json.contains("\"witnessed_state_ref\""));
        assert!(json.contains("\"mutation_envelope_ref\""));
    }
}
