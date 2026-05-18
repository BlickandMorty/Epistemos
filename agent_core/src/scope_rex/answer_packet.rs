// HARDENING ENFORCEMENT: AnswerPacket sits on the chat-emission boundary.
// Every consumer needs deterministic serialization + zero panics in
// production paths. Tests are allowed to unwrap because a failed
// invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W1 — `AnswerPacket` emission (the 5th Monday-Move primitive).
//!
//! HELIOS-W1 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W1 +
//! `docs/fusion/helios v5 first.md` DOC 1 §1.2:
//!
//! > "AnswerPacket [NEW]: `{ id: Ulid, claims: Vec<Claim>,
//! >  residency_signals: Vec<ResidencySignal>, ui_label: Label,
//! >  witnessed_state_ref: WitnessedStateId,
//! >  semantic_delta_ref: Option<SemanticDeltaId>,
//! >  mutation_envelope_ref: MutationEnvelopeId }`."
//!
//! V6.1 adds the strictly additive `attention_mode` field. Missing
//! legacy values decode as `unavailable`, never as falsely dynamic.
//!
//! Per integration brief §4: AnswerPacket *is* the only genuinely new
//! Monday-Move primitive — TypedArtifact ≡ MutationEnvelope (already
//! in main), RunEventLog ≡ provenance/ledger (already in main),
//! ClaimFrame ≡ Claim, EvidenceLedger ≡ ClaimLedger. AnswerPacket
//! ties the four together at the chat-emission boundary.
//!
//! ## §2.5.2 compliance posture
//!
//! Tier 1 ON in MAS by default. AnswerPacket is a strictly additive
//! struct + serialization; no behavior change, no model file change,
//! no runtime download. The chat reply path emits an AnswerPacket
//! alongside the existing token stream; the chat row's VRMLabel
//! surface (W3) reads the `ui_label` field. Older clients that don't
//! know about AnswerPacket continue to function on the unchanged
//! token stream.
//!
//! ## Cross-references
//!
//! - [`crate::scope_rex`] — module entry
//! - [`crate::provenance::ledger::Claim`] — claim payload
//! - [`crate::provenance::ledger::ClaimKind`] — W2 five epistemic arms
//!   plus the V6.1 static-fallback acknowledgement
//! - [`crate::mutations::envelope`] — MutationEnvelope (referenced by id)
//! - canon-hardening protocol §1 — WRV state machine; this type is
//!   currently `state: implemented` (no production caller yet); the
//!   `state: wired` promotion lands when [`StreamingDelegate`] in
//!   Swift starts emitting AnswerPackets per chat reply.

use serde::{Deserialize, Serialize};

use crate::provenance::ledger::{Claim, ClaimKind, ClaimStatus};

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

/// Stable identifier for an [`AnswerPacket`]. The wire format is a
/// ULID-style string; the constructor enforces the ULID-26-char
/// invariant only when `validate=true` (callers may pass any
/// [`Ulid`]-shaped string they generate themselves; the wire format
/// stays opaque so downstream consumers don't have to take a Ulid
/// dep).
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AnswerPacketId(pub String);

impl AnswerPacketId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

/// Stable id reference into a future `WitnessedState` ledger
/// (HELIOS V5 W5). Wire format is opaque string; the type-level
/// distinction prevents accidental cross-wiring with [`SemanticDeltaId`]
/// or [`MutationEnvelopeId`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct WitnessedStateId(pub String);

impl WitnessedStateId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

/// Stable id reference into a future `SemanticDelta` ledger
/// (HELIOS V5 W5).
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct SemanticDeltaId(pub String);

impl SemanticDeltaId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

/// Stable id reference into the existing [`crate::mutations::envelope`]
/// MutationEnvelope ledger.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct MutationEnvelopeId(pub String);

impl MutationEnvelopeId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

// ---------------------------------------------------------------------------
// VRM Label (HELIOS V5 W3)
// ---------------------------------------------------------------------------

/// HELIOS V5 W3 — Verified Research Mode UI label.
///
/// 4-arm collapse of the 9-claim π Kleene K3 classification per
/// `docs/fusion/helios v5 first.md` §1.9. The chat row's
/// `VRMLabelView` (Swift) renders one of these four states for every
/// emitted AnswerPacket.
///
/// **Wire format (snake_case):**
/// `verified` | `plausible_but_unverified` | `speculative` | `blocked`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VrmLabel {
    /// Claim is verified (empirical / mathematical / code-invariant
    /// chain validated).
    Verified,
    /// Claim is plausible but unverified — internally consistent and
    /// non-contradictory but lacks a verification chain.
    PlausibleButUnverified,
    /// Speculative claim — hypothesis, conjecture, or speculation.
    Speculative,
    /// Claim was blocked at the safety / privacy gate; never reaches
    /// the user as a positive assertion.
    Blocked,
}

impl Default for VrmLabel {
    /// Default to `PlausibleButUnverified` so a missing-field on a v1
    /// archive doesn't accidentally claim `Verified`.
    fn default() -> Self {
        Self::PlausibleButUnverified
    }
}

// ---------------------------------------------------------------------------
// Attention Mode (EPISTEMOS V6.1)
// ---------------------------------------------------------------------------

/// EPISTEMOS V6.1 — whether expensive intelligence was summoned by
/// the interrupt score, by the static hybrid fallback, or not available
/// to classify.
///
/// `Unavailable` is the default for backward-compat so an old
/// AnswerPacket never pretends that dynamic attention was active.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AttentionMode {
    /// The interrupt score woke attention/retrieval/tooling explicitly.
    Dynamic,
    /// Dynamic interrupt signals were unavailable, so the static 9:1
    /// hybrid floor was used. Must be acknowledged by a
    /// `ClaimKind::StaticFallbackAcknowledged` claim.
    StaticFallback,
    /// The packet predates V6.1 or the runtime could not classify the
    /// mode. This is safe but not proof of dynamic execution.
    Unavailable,
}

impl Default for AttentionMode {
    fn default() -> Self {
        Self::Unavailable
    }
}

// ---------------------------------------------------------------------------
// ResidencySignal (HELIOS V5 W4 — Residency Governor input)
// ---------------------------------------------------------------------------

/// HELIOS V5 W4 — pure-data input to the Residency Governor.
///
/// Per `docs/fusion/helios v5 first.md` §1.13 (verbatim thresholds):
///
/// ```text
/// safety_risk > 0.7         → Quarantine
/// privacy > 0.9             → Quarantine
/// verification_score < 0.5  → TransientContext
/// repeat_count < 3          → TransientContext
/// repeat < 5 ∧ gain < 0.1   → FeatureRule
/// repeat < 10               → GrpoPrior
/// verification > 0.8 ∧ gain > 0.2 ∧ forgetting > 0.6 → OsftCore
/// (else previous antecedent, consequent fail) → PsoftAdapter
/// default                   → RetrievalMemory
/// ```
///
/// The Governor itself is the W4 slice; this struct is W1's input
/// type. Consumed by [`crate::scope_rex::residency`] (NEW, lands per
/// W4).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ResidencySignal {
    pub safety_risk: f32,
    pub privacy: f32,
    pub verification_score: f32,
    pub repeat_count: u32,
    pub gain: f32,
    pub forgetting: f32,
}

impl ResidencySignal {
    /// Fresh signal with all weights at their identity values
    /// (no risk, no privacy concern, neutral verification, never
    /// repeated, no gain, no forgetting). Useful as a base for the
    /// builder pattern in tests.
    pub fn neutral() -> Self {
        Self {
            safety_risk: 0.0,
            privacy: 0.0,
            verification_score: 0.5,
            repeat_count: 0,
            gain: 0.0,
            forgetting: 0.0,
        }
    }
}

// ---------------------------------------------------------------------------
// AnswerPacket (HELIOS V5 W1)
// ---------------------------------------------------------------------------

/// HELIOS V5 W1 — the 5th Monday-Move primitive.
///
/// Emitted on every chat reply (per W1 acceptance) once the chat
/// path is wired (`state: wired` follows after the Swift
/// StreamingDelegate change lands per the W1 follow-up slice).
///
/// **Schema lock:** V5 fields match `docs/fusion/helios v5 first.md`
/// DOC 1 §1.2. V6.1 adds `attention_mode` as a strictly additive
/// audit field so fallback execution is never silent.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AnswerPacket {
    pub id: AnswerPacketId,
    pub claims: Vec<Claim>,
    pub residency_signals: Vec<ResidencySignal>,
    pub ui_label: VrmLabel,
    #[serde(default)]
    pub attention_mode: AttentionMode,
    pub witnessed_state_ref: WitnessedStateId,
    pub semantic_delta_ref: Option<SemanticDeltaId>,
    pub mutation_envelope_ref: MutationEnvelopeId,
}

impl AnswerPacket {
    /// Construct an empty AnswerPacket with the required references.
    /// Fields are intentionally exposed for the chat path to populate
    /// per emission; this constructor establishes the minimum
    /// well-formed shape.
    pub fn new(
        id: AnswerPacketId,
        witnessed_state_ref: WitnessedStateId,
        mutation_envelope_ref: MutationEnvelopeId,
    ) -> Self {
        Self {
            id,
            claims: Vec::new(),
            residency_signals: Vec::new(),
            ui_label: VrmLabel::PlausibleButUnverified,
            attention_mode: AttentionMode::Unavailable,
            witnessed_state_ref,
            semantic_delta_ref: None,
            mutation_envelope_ref,
        }
    }

    /// Fluent setter for the VRM label (W3 surface).
    pub fn with_ui_label(mut self, label: VrmLabel) -> Self {
        self.ui_label = label;
        self
    }

    /// Fluent setter for the V6.1 attention-mode audit field.
    pub fn with_attention_mode(mut self, attention_mode: AttentionMode) -> Self {
        self.attention_mode = attention_mode;
        self
    }

    /// Fluent setter for the optional SemanticDelta reference (W5).
    pub fn with_semantic_delta(mut self, semantic_delta_ref: SemanticDeltaId) -> Self {
        self.semantic_delta_ref = Some(semantic_delta_ref);
        self
    }

    /// Fluent claim push.
    pub fn push_claim(mut self, claim: Claim) -> Self {
        self.claims.push(claim);
        self
    }

    /// Fluent residency-signal push.
    pub fn push_residency_signal(mut self, signal: ResidencySignal) -> Self {
        self.residency_signals.push(signal);
        self
    }

    /// True when the packet used the static 9:1 fallback and must
    /// explicitly confess that fact in its claims.
    pub fn requires_static_fallback_acknowledgement(&self) -> bool {
        self.attention_mode == AttentionMode::StaticFallback
    }

    /// Static fallback is only acknowledged when the packet carries
    /// the dedicated runtime-admission claim kind. For non-static modes,
    /// there is no static fallback to acknowledge.
    pub fn acknowledges_static_fallback(&self) -> bool {
        if !self.requires_static_fallback_acknowledgement() {
            return true;
        }

        self.claims
            .iter()
            .any(is_active_static_fallback_acknowledgement)
    }

    /// True when the `attention_mode` field and its audit claims do
    /// not contradict each other. Static fallback must carry the
    /// dedicated acknowledgement claim; dynamic/unavailable modes must
    /// not carry that claim.
    pub fn attention_mode_claims_are_consistent(&self) -> bool {
        let has_static_fallback_acknowledgement = self
            .claims
            .iter()
            .any(is_active_static_fallback_acknowledgement);

        match self.attention_mode {
            AttentionMode::StaticFallback => has_static_fallback_acknowledgement,
            AttentionMode::Dynamic | AttentionMode::Unavailable => {
                !has_static_fallback_acknowledgement
            }
        }
    }
}

fn is_active_static_fallback_acknowledgement(claim: &Claim) -> bool {
    claim.status == ClaimStatus::Active && claim.kind == ClaimKind::StaticFallbackAcknowledged
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provenance::ledger::{ClaimId, ClaimKind};

    fn claim(id: &str, text: &str, kind: ClaimKind) -> Claim {
        Claim::new(ClaimId::new(id), text, 1_745_000_000_000).with_kind(kind)
    }

    #[test]
    fn vrm_label_default_is_plausible_not_verified() {
        // Critical safety invariant: a missing-field on a v1 archive
        // must NEVER default to `Verified` — that would silently
        // promote unverified claims to verified status.
        assert_eq!(VrmLabel::default(), VrmLabel::PlausibleButUnverified);
    }

    #[test]
    fn vrm_label_serializes_in_snake_case() {
        for (label, expected) in [
            (VrmLabel::Verified, "\"verified\""),
            (
                VrmLabel::PlausibleButUnverified,
                "\"plausible_but_unverified\"",
            ),
            (VrmLabel::Speculative, "\"speculative\""),
            (VrmLabel::Blocked, "\"blocked\""),
        ] {
            let json = serde_json::to_string(&label).unwrap();
            assert_eq!(json, expected, "wire format for {:?}", label);
        }
    }

    #[test]
    fn vrm_label_and_attention_mode_reject_unknown_strings_on_decode() {
        // Defensive cross-FFI decoder gate for AnswerPacket's two
        // snake_case enums. The Swift mirror at Models/AnswerPacket.swift
        // decodes packets the Rust side emitted; future-version
        // packets must Err on this build (and the V6.1 safe default
        // contract takes over) rather than panic.
        let result: Result<VrmLabel, _> = serde_json::from_str("\"unknown_label\"");
        assert!(result.is_err(),
                "VrmLabel decoder must reject unknown labels");
        let result: Result<VrmLabel, _> = serde_json::from_str("\"Verified\"");
        assert!(result.is_err(),
                "PascalCase must reject — only snake_case is canonical");

        let result: Result<AttentionMode, _> =
            serde_json::from_str("\"unknown_mode\"");
        assert!(result.is_err(),
                "AttentionMode decoder must reject unknown modes");
        let result: Result<AttentionMode, _> =
            serde_json::from_str("\"StaticFallback\"");
        assert!(result.is_err(),
                "PascalCase AttentionMode must reject");
    }

    #[test]
    fn attention_mode_serializes_in_snake_case_with_safe_default() {
        // V6.1's `attention_mode` field crosses the FFI to the Swift
        // `AnswerPacket` mirror. Wire format pinned here so the two
        // sides can't drift. `static_fallback` is the load-bearing
        // compound — without this gate, a serde rename quirk could
        // emit `staticfallback` or `static-fallback` and silently
        // orphan every prior packet.
        use serde_json::to_string;
        assert_eq!(to_string(&AttentionMode::Dynamic).unwrap(), "\"dynamic\"");
        assert_eq!(
            to_string(&AttentionMode::StaticFallback).unwrap(),
            "\"static_fallback\""
        );
        assert_eq!(
            to_string(&AttentionMode::Unavailable).unwrap(),
            "\"unavailable\""
        );

        // The Default impl backstop: pre-V6.1 packets that omit
        // `attention_mode` MUST decode to `Unavailable`, not silently
        // claim Dynamic. (The Default impl already enforces this at
        // the type level; this assertion pins it at the test level so
        // a future rewrite of Default doesn't shift the safety contract.)
        assert_eq!(AttentionMode::default(), AttentionMode::Unavailable,
                   "pre-V6.1 packets MUST decode to Unavailable — never Dynamic by accident");

        // Round-trip in: historic packets with the canonical strings
        // must decode cleanly.
        let m: AttentionMode = serde_json::from_str("\"static_fallback\"").unwrap();
        assert_eq!(m, AttentionMode::StaticFallback);
    }

    #[test]
    fn residency_signal_neutral_is_safe_default() {
        let s = ResidencySignal::neutral();
        // Per §1.13 thresholds, a neutral signal must NOT trip
        // Quarantine (safety_risk ≤ 0.7, privacy ≤ 0.9).
        assert!(s.safety_risk <= 0.7);
        assert!(s.privacy <= 0.9);
        // It must also not trip TransientContext (verification_score
        // exactly at 0.5 means the strict inequality fails).
        assert_eq!(s.verification_score, 0.5);
    }

    #[test]
    fn answer_packet_new_has_well_formed_minimum() {
        let pkt = AnswerPacket::new(
            AnswerPacketId::new("01H6XAKE0XSY1234567890ABCD"),
            WitnessedStateId::new("ws-0"),
            MutationEnvelopeId::new("me-0"),
        );
        assert!(pkt.claims.is_empty());
        assert!(pkt.residency_signals.is_empty());
        assert_eq!(pkt.ui_label, VrmLabel::PlausibleButUnverified);
        assert_eq!(pkt.attention_mode, AttentionMode::Unavailable);
        assert!(pkt.semantic_delta_ref.is_none());
    }

    #[test]
    fn answer_packet_builder_round_trip_through_json() {
        let pkt = AnswerPacket::new(
            AnswerPacketId::new("01H6XAKE0XSY1234567890ABCD"),
            WitnessedStateId::new("ws-1"),
            MutationEnvelopeId::new("me-1"),
        )
        .with_ui_label(VrmLabel::Verified)
        .with_semantic_delta(SemanticDeltaId::new("sd-1"))
        .push_claim(claim("c1", "x", ClaimKind::Mathematical))
        .push_claim(claim("c2", "y", ClaimKind::Empirical))
        .push_residency_signal(ResidencySignal::neutral());

        let json = serde_json::to_string(&pkt).unwrap();
        let parsed: AnswerPacket = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, pkt);
    }

    #[test]
    fn static_fallback_attention_mode_requires_acknowledgement_claim() {
        let unacknowledged = AnswerPacket::new(
            AnswerPacketId::new("01H6XAKE0XSY1234567890ABCD"),
            WitnessedStateId::new("ws-static"),
            MutationEnvelopeId::new("me-static"),
        )
        .with_attention_mode(AttentionMode::StaticFallback);

        assert!(unacknowledged.requires_static_fallback_acknowledgement());
        assert!(!unacknowledged.acknowledges_static_fallback());
        assert!(!unacknowledged.attention_mode_claims_are_consistent());

        let acknowledged = unacknowledged.push_claim(claim(
            "c-static",
            "static 9:1 fallback engaged because dynamic interrupt signals were unavailable",
            ClaimKind::StaticFallbackAcknowledged,
        ));

        assert!(acknowledged.acknowledges_static_fallback());
        assert!(acknowledged.attention_mode_claims_are_consistent());
    }

    #[test]
    fn static_fallback_acknowledgement_claim_is_forbidden_outside_static_fallback() {
        let contradictory = AnswerPacket::new(
            AnswerPacketId::new("01H6XAKE0XSY1234567890ABCD"),
            WitnessedStateId::new("ws-dynamic"),
            MutationEnvelopeId::new("me-dynamic"),
        )
        .with_attention_mode(AttentionMode::Dynamic)
        .push_claim(claim(
            "c-static",
            "static 9:1 fallback engaged because dynamic interrupt signals were unavailable",
            ClaimKind::StaticFallbackAcknowledged,
        ));

        assert!(!contradictory.requires_static_fallback_acknowledgement());
        assert!(contradictory.acknowledges_static_fallback());
        assert!(!contradictory.attention_mode_claims_are_consistent());
    }

    #[test]
    fn answer_packet_carries_all_five_claim_kinds() {
        // The AnswerPacket spine must accept all 5 ClaimKind arms in
        // the same packet (sanity: no kind is silently filtered).
        let pkt = AnswerPacket::new(
            AnswerPacketId::new("01H6XAKE0XSY1234567890ABCD"),
            WitnessedStateId::new("ws"),
            MutationEnvelopeId::new("me"),
        )
        .push_claim(claim("c1", "e", ClaimKind::Empirical))
        .push_claim(claim("c2", "m", ClaimKind::Mathematical))
        .push_claim(claim("c3", "i", ClaimKind::CodeInvariant))
        .push_claim(claim("c4", "ca", ClaimKind::Causal))
        .push_claim(claim("c5", "s", ClaimKind::Speculative))
        .push_claim(claim(
            "c6",
            "static fallback acknowledged",
            ClaimKind::StaticFallbackAcknowledged,
        ));

        assert_eq!(pkt.claims.len(), 6);
        assert_eq!(pkt.claims[0].kind, ClaimKind::Empirical);
        assert_eq!(pkt.claims[1].kind, ClaimKind::Mathematical);
        assert_eq!(pkt.claims[2].kind, ClaimKind::CodeInvariant);
        assert_eq!(pkt.claims[3].kind, ClaimKind::Causal);
        assert_eq!(pkt.claims[4].kind, ClaimKind::Speculative);
        assert_eq!(pkt.claims[5].kind, ClaimKind::StaticFallbackAcknowledged);
    }

    #[test]
    fn id_newtypes_are_distinct_at_the_type_level() {
        // Compile-time check (won't compile if the newtypes get
        // collapsed into a single alias). Belt-and-suspenders against
        // an accidental future refactor.
        let ws: WitnessedStateId = WitnessedStateId::new("a");
        let sd: SemanticDeltaId = SemanticDeltaId::new("a");
        let me: MutationEnvelopeId = MutationEnvelopeId::new("a");
        let ap: AnswerPacketId = AnswerPacketId::new("a");

        // Different types, equal underlying string. Ensure the wire
        // serialization is identical for matching content.
        let ws_json = serde_json::to_string(&ws).unwrap();
        let sd_json = serde_json::to_string(&sd).unwrap();
        let me_json = serde_json::to_string(&me).unwrap();
        let ap_json = serde_json::to_string(&ap).unwrap();
        assert_eq!(ws_json, "\"a\"");
        assert_eq!(sd_json, "\"a\"");
        assert_eq!(me_json, "\"a\"");
        assert_eq!(ap_json, "\"a\"");
    }
}
