//! `Para<P, A, B>` — parametric morphism with frozen output and forensic
//! reverse leg.
//!
//! ## Why a Para?
//!
//! The acceptance bar (§4 T11) calls for a `Para<P, A, B>` with `fwd` and
//! `rev`. The categorical motivation is that an executor is a function
//! parametrized by `P` (parameters: blueprint + capabilities) that maps
//! input `A` (mission packet) to output `B` (answer packet). The reverse
//! leg `rev` produces parameter feedback (telemetry, ledger writes, budget
//! debit) *without ever mutating the forward output*.
//!
//! ## The reverse-leg invariant
//!
//! `rev` MUST NOT mutate `stop_reason` or any other field of `ParaOutput`.
//! This is enforced two ways:
//!
//! 1. **Compile-time** — `rev` takes `&ParaOutput<B>` (a shared reference).
//!    There is no `&mut` path through the trait surface.
//! 2. **Runtime forensic** — every `ParaOutput` carries a frozen BLAKE3
//!    digest over its canonical bytes (`stop_reason_digest`). Callers (and
//!    the property test in `tests::reverse_leg_invariants`) recompute the
//!    digest after `rev` and assert equality.
//!
//! The digest is BLAKE3 over the canonical-bytes encoding of `stop_reason`
//! plus the `thinking_block_digest` (so the "thinking blocks hash-identical"
//! invariant from the acceptance bar is wired into the same forensic path).

use std::fmt::Debug;

use serde::{Deserialize, Serialize};

/// Stop reason for a v2 executor run. Mirrors the Claude / OpenAI
/// `stop_reason` taxonomy but in a provider-neutral shape. Once a
/// `ParaOutput` is constructed, the stop reason is frozen and the reverse
/// leg cannot mutate it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StopReason {
    /// Agent decided to end the turn (canonical successful termination).
    EndTurn,
    /// Agent emitted a tool call and is awaiting tool result.
    ToolUse,
    /// Provider truncated at max tokens.
    MaxTokens,
    /// Provider returned a refusal.
    Refusal,
    /// WBO budget exhausted mid-run — see `wbo6::` for the budget shape.
    BudgetExhausted,
    /// Macaroon verification failed or capability scope rejected the call.
    CapabilityDenied,
    /// Executor error (transport, parse, etc.).
    Error,
}

impl StopReason {
    /// Canonical bytes for hashing. Stable across `serde_json` versions
    /// because the variant set is closed and the names are fixed.
    #[must_use]
    pub const fn canonical_bytes(self) -> &'static [u8] {
        match self {
            Self::EndTurn => b"end_turn",
            Self::ToolUse => b"tool_use",
            Self::MaxTokens => b"max_tokens",
            Self::Refusal => b"refusal",
            Self::BudgetExhausted => b"budget_exhausted",
            Self::CapabilityDenied => b"capability_denied",
            Self::Error => b"error",
        }
    }
}

/// Forward-leg output. The `stop_reason_digest` and `thinking_digest`
/// fields are forensic checksums: callers recompute them after `rev` and
/// assert equality. The digests are computed at construction time and
/// never mutated.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParaOutput<B> {
    pub value: B,
    pub stop_reason: StopReason,
    /// Optional thinking-block content (Claude `thinking` blocks +
    /// signature). Preserved verbatim across the run; the digest below
    /// captures its bytes so the "thinking blocks hash-identical"
    /// invariant is checkable in O(1).
    pub thinking: Option<Vec<u8>>,
    /// BLAKE3 over `stop_reason.canonical_bytes()` and the optional
    /// thinking-block bytes. Frozen at construction.
    pub stop_reason_digest: [u8; 32],
    /// BLAKE3 over `thinking` bytes alone (zero hash when `thinking` is
    /// `None`). Frozen at construction.
    pub thinking_digest: [u8; 32],
}

impl<B> ParaOutput<B> {
    /// Construct a frozen output. The two digests are computed once and
    /// then never recomputed by the runtime — only by forensic checks.
    pub fn new(value: B, stop_reason: StopReason, thinking: Option<Vec<u8>>) -> Self {
        let thinking_digest = thinking
            .as_deref()
            .map(blake3::hash)
            .map_or([0u8; 32], |h| *h.as_bytes());
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"agent_runtime_v2.para.stop_reason\n");
        hasher.update(stop_reason.canonical_bytes());
        hasher.update(b"\nthinking\n");
        hasher.update(&thinking_digest);
        let stop_reason_digest = *hasher.finalize().as_bytes();
        Self {
            value,
            stop_reason,
            thinking,
            stop_reason_digest,
            thinking_digest,
        }
    }

    /// Recompute the digest from scratch and compare. Returns true iff
    /// `stop_reason` + `thinking` haven't been tampered with. The runtime
    /// calls this immediately after every `Para::rev` invocation; any
    /// mismatch is a contract violation.
    #[must_use]
    pub fn digest_intact(&self) -> bool {
        let recomputed_thinking = self
            .thinking
            .as_deref()
            .map(blake3::hash)
            .map_or([0u8; 32], |h| *h.as_bytes());
        if recomputed_thinking != self.thinking_digest {
            return false;
        }
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"agent_runtime_v2.para.stop_reason\n");
        hasher.update(self.stop_reason.canonical_bytes());
        hasher.update(b"\nthinking\n");
        hasher.update(&recomputed_thinking);
        *hasher.finalize().as_bytes() == self.stop_reason_digest
    }
}

/// Feedback signal returned by `rev`. The engine decides whether to apply
/// the delta to the next-iteration parameters; `rev` itself MUST NOT
/// mutate them in place.
#[derive(Debug, Clone)]
pub struct ParaFeedback<P> {
    pub delta: P,
}

/// Reverse-leg / forward-leg errors. Kept as a small closed enum so the
/// trait doesn't drag in unrelated error types.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParaError {
    BudgetExhausted,
    CapabilityDenied,
    MalformedToolCall,
    Transport(String),
}

/// `Para<P, A, B>` — typed parametric morphism with forensic reverse leg.
///
/// Implementors are executors (LocalMLX, Anthropic, OpenAI, MCP, ProCLI).
/// The trait surface is deliberately tiny:
///
/// - `fwd(params, input)` runs the executor and returns a `ParaOutput`.
/// - `rev(params, &output)` produces a `ParaFeedback` without mutating
///   the output. The shared reference makes the no-mutation rule
///   compile-enforced; the digest makes it forensically auditable.
pub trait Para<P, A, B>: Send + Sync {
    /// Forward leg.
    fn fwd(&self, params: &P, input: A) -> Result<ParaOutput<B>, ParaError>;
    /// Reverse leg. MUST NOT mutate the output (compile-enforced).
    /// Returns the feedback delta to apply to `P` on the next run.
    fn rev(&self, params: &P, output: &ParaOutput<B>) -> Result<ParaFeedback<P>, ParaError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Toy Para used by the invariant tests below. Captures the forward
    /// output and gives the reverse leg every excuse to misbehave.
    struct ToyExecutor;

    impl Para<u32, &'static str, String> for ToyExecutor {
        fn fwd(&self, _params: &u32, input: &'static str) -> Result<ParaOutput<String>, ParaError> {
            Ok(ParaOutput::new(
                input.to_string(),
                StopReason::EndTurn,
                Some(b"thinking-block-bytes".to_vec()),
            ))
        }

        fn rev(
            &self,
            _params: &u32,
            output: &ParaOutput<String>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            // Reverse leg may *read* output freely.
            let _ = output.value.len();
            let _ = output.stop_reason;
            // It returns a feedback delta — never mutates the output.
            Ok(ParaFeedback { delta: 1 })
        }
    }

    #[test]
    fn para_trait_and_implementor_carry_send_sync_bounds_compile_pin() {
        // Phase 1 hardening — compile-time Send+Sync pin for the
        // Para trait surface and its canonical test implementor.
        // Companion to iter-136 (AgentRuntimeV2Capability) +
        // iter-137 (MutationWriter) Send+Sync pins.
        //
        // The Para trait is declared `Send + Sync` because executors
        // are shipped across worker threads (dispatch pool). The
        // existing compose::para_seq_is_send_sync_when_stages_are
        // pins ParaSeq's inheritance but not Para's own bound
        // directly. A future refactor dropping Send+Sync from Para
        // (e.g., to allow a !Send local-only executor) would compile-
        // fail right here at the trait-object probe.
        fn assert_send_sync<T: Send + Sync + ?Sized>() {}
        assert_send_sync::<dyn Para<u32, &'static str, String>>();
        assert_send_sync::<ToyExecutor>();
    }

    #[test]
    fn stop_reason_canonical_bytes_is_const_fn_compile_pin() {
        // Phase 1 hardening (promotion + pin) — StopReason::canonical_bytes
        // is a pure-match returning `&'static [u8]`. The canonical pattern
        // across the codebase for similar match-only-on-Copy-enum helpers
        // (BudgetTerm::code, AgentEventErrorKind::code, VariantTier::code,
        // LocalAgentCapabilityTier::code) is `pub const fn`. canonical_bytes
        // was missed during the initial round; this commit promotes it
        // and pins the annotation in a const-context probe.
        //
        // The function feeds into the BLAKE3 stop_reason_digest computation
        // (para.rs §ParaOutput::new); making it const-callable lets a
        // future const-time helper precompute digest fragments at compile
        // time without changing runtime behaviour.
        //
        // Companion to iter-100 / iter-101 / iter-102 / iter-103 / iter-104
        // const-context pins.
        const END_TURN: &[u8] = StopReason::EndTurn.canonical_bytes();
        const TOOL_USE: &[u8] = StopReason::ToolUse.canonical_bytes();
        const MAX_TOKENS: &[u8] = StopReason::MaxTokens.canonical_bytes();
        const REFUSAL: &[u8] = StopReason::Refusal.canonical_bytes();
        const BUDGET: &[u8] = StopReason::BudgetExhausted.canonical_bytes();
        const CAP_DEN: &[u8] = StopReason::CapabilityDenied.canonical_bytes();
        const ERROR: &[u8] = StopReason::Error.canonical_bytes();

        // Runtime asserts keep the const items live.
        assert_eq!(END_TURN, b"end_turn");
        assert_eq!(TOOL_USE, b"tool_use");
        assert_eq!(MAX_TOKENS, b"max_tokens");
        assert_eq!(REFUSAL, b"refusal");
        assert_eq!(BUDGET, b"budget_exhausted");
        assert_eq!(CAP_DEN, b"capability_denied");
        assert_eq!(ERROR, b"error");
    }

    #[test]
    fn stop_reason_unknown_serde_string_fails_to_deserialise() {
        // Phase 1 hardening — closed-taxonomy guardrail symmetric to
        // mode::unknown_mode_string_fails_to_deserialise (iter-71) and
        // event::agent_event_unknown_event_type_tag_fails_to_deserialise
        // (iter-73). StopReason is embedded inside AgentEvent::Stop,
        // AnswerPacket, and ParaOutput; replay parity across all three
        // sites depends on rejecting unknown strings.
        //
        // 7 valid variants: end_turn, tool_use, max_tokens, refusal,
        // budget_exhausted, capability_denied, error. Anything else
        // must fail.
        for bad in [
            "\"completed\"",          // adjacent vocabulary
            "\"finished\"",
            "\"halted\"",
            "\"END_TURN\"",           // case variants
            "\"EndTurn\"",
            "\"endTurn\"",
            "\"Tool_Use\"",
            "\"tool-use\"",           // kebab-case (not snake_case)
            "\"max-tokens\"",
            "\"timeout\"",            // legacy / OpenAI-style vocab
            "\"length\"",
            "\"stop\"",
            "\"\"",
        ] {
            let r: Result<StopReason, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown stop_reason string {bad} must fail to deserialise"
            );
        }
        // Sanity: every valid variant still round-trips (so the
        // negatives above aren't masking broader serde breakage).
        for (variant, expected) in [
            (StopReason::EndTurn, "\"end_turn\""),
            (StopReason::ToolUse, "\"tool_use\""),
            (StopReason::MaxTokens, "\"max_tokens\""),
            (StopReason::Refusal, "\"refusal\""),
            (StopReason::BudgetExhausted, "\"budget_exhausted\""),
            (StopReason::CapabilityDenied, "\"capability_denied\""),
            (StopReason::Error, "\"error\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected, "variant {variant:?} drifted serde form");
            let back: StopReason = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn stop_reason_canonical_bytes_are_unique_per_variant() {
        // Phase 1 hardening — canonical-bytes stability: every
        // variant's canonical_bytes() output must be unique. If two
        // variants shared a bytes representation, the
        // stop_reason_digest would collide across distinct stop
        // reasons and break replay parity.
        use std::collections::HashSet;
        let variants = [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ];
        let unique: HashSet<&[u8]> = variants.iter().map(|v| v.canonical_bytes()).collect();
        assert_eq!(
            unique.len(),
            variants.len(),
            "every StopReason variant must have a unique canonical_bytes encoding"
        );
    }

    #[test]
    fn stop_reason_canonical_bytes_are_not_prefix_of_each_other() {
        // Belt-and-braces: even if all variants are unique, a future
        // binary-codec that uses canonical_bytes as a length-prefixed
        // identifier would still be ambiguous if one variant's bytes
        // are a prefix of another's. Lock that out now.
        let variants = [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ];
        for &a in &variants {
            for &b in &variants {
                if a == b {
                    continue;
                }
                let ab = a.canonical_bytes();
                let bb = b.canonical_bytes();
                assert!(
                    !ab.starts_with(bb) && !bb.starts_with(ab),
                    "canonical_bytes of {a:?} and {b:?} must not be prefixes of each other"
                );
            }
        }
    }

    #[test]
    fn para_error_partial_eq_distinguishes_variants_and_payloads() {
        // Phase 1 hardening — ParaError derives PartialEq + Eq;
        // two equal Transport(_) values must compare equal, but
        // distinct payloads must not. Pin the contract for
        // matches!-based audit checks.
        assert_eq!(ParaError::BudgetExhausted, ParaError::BudgetExhausted);
        assert_eq!(ParaError::CapabilityDenied, ParaError::CapabilityDenied);
        assert_ne!(ParaError::BudgetExhausted, ParaError::CapabilityDenied);
        // Transport(_) — same payload equals, different payloads don't.
        let t_a = ParaError::Transport("conn closed".to_string());
        let t_a2 = ParaError::Transport("conn closed".to_string());
        let t_b = ParaError::Transport("EOF".to_string());
        assert_eq!(t_a, t_a2);
        assert_ne!(t_a, t_b);
        assert_ne!(t_a, ParaError::BudgetExhausted);
    }

    #[test]
    fn para_error_transport_debug_includes_inner_string_for_audit_greps() {
        // Phase 1 hardening — Transport(_) carries a String; the
        // Debug repr MUST include the inner string so audit greps
        // can pull out the failure context. A future refactor that
        // hides the inner string (e.g. via a custom Debug impl)
        // would silently strip diagnostic info.
        let cases = ["conn closed", "EOF reading SSE", "TLS handshake failed: 0x42"];
        for msg in cases {
            let err = ParaError::Transport(msg.to_string());
            let dbg = format!("{err:?}");
            assert!(dbg.starts_with("Transport("), "got {dbg}");
            assert!(
                dbg.contains(msg),
                "Debug repr {dbg} must include inner string {msg}"
            );
        }
    }

    #[test]
    fn para_error_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit dashboards print Debug repr of
        // ParaError variants. Pin each one's leading discriminant
        // so a maintainer rename surfaces at PR review (audit log
        // greps would silently break otherwise).
        assert_eq!(format!("{:?}", ParaError::BudgetExhausted), "BudgetExhausted");
        assert_eq!(format!("{:?}", ParaError::CapabilityDenied), "CapabilityDenied");
        assert_eq!(format!("{:?}", ParaError::MalformedToolCall), "MalformedToolCall");
        let transport = ParaError::Transport("conn closed".into());
        let dbg = format!("{transport:?}");
        assert!(dbg.starts_with("Transport("), "got {dbg}");
        assert!(dbg.contains("conn closed"));
    }

    #[test]
    fn every_para_output_field_is_identity_load_bearing() {
        // Phase 1 hardening — seventh leg of the identity-pin
        // pattern (AgentBlueprint 5, AnswerPacket 7, MissionPacket 3,
        // ToolCall 2, MutationEnvelope 3, LocalAgentCapability 10,
        // ParaOutput 5). ParaOutput<B> has 5 fields:
        //   value, stop_reason, thinking, stop_reason_digest,
        //   thinking_digest
        // The digests are computed at construction time and stored,
        // so mutating ONLY a non-digest field doesn't update them
        // — but the equality check still breaks (because the
        // mutated non-digest field differs). And mutating ONLY a
        // digest field also breaks equality without touching the
        // backing fields.
        //
        // A silent #[serde(skip)] or PartialEq override that
        // dropped any one of the 5 fields would silently let
        // distinct outputs compare equal AND collapse the forensic
        // audit chain (digest tamper detection vs. payload tamper
        // detection rely on independent equality of each field).
        let base: ParaOutput<String> =
            ParaOutput::new("hello".to_string(), StopReason::EndTurn, Some(b"think".to_vec()));

        let mut diff_value = base.clone();
        diff_value.value.push_str("X");
        assert_ne!(diff_value, base, "value must participate in PartialEq");

        let mut diff_stop = base.clone();
        diff_stop.stop_reason = StopReason::Refusal;
        assert_ne!(diff_stop, base, "stop_reason must participate in PartialEq");

        let mut diff_thinking = base.clone();
        if let Some(t) = diff_thinking.thinking.as_mut() {
            t.push(b'!');
        }
        assert_ne!(diff_thinking, base, "thinking must participate in PartialEq");

        let mut diff_sr_digest = base.clone();
        diff_sr_digest.stop_reason_digest[0] ^= 0xFF;
        assert_ne!(
            diff_sr_digest, base,
            "stop_reason_digest must participate in PartialEq"
        );

        let mut diff_th_digest = base.clone();
        diff_th_digest.thinking_digest[0] ^= 0xFF;
        assert_ne!(
            diff_th_digest, base,
            "thinking_digest must participate in PartialEq"
        );

        // Sanity preserved.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn para_output_clone_preserves_digests_bitwise() {
        // Phase 1 hardening — replay parity: ParaOutput::clone must
        // copy stop_reason_digest and thinking_digest bit-for-bit.
        // A future #[derive(Clone)] replacement that recomputes
        // these from scratch would break replay reproducibility.
        let exec = ToyExecutor;
        let original = exec.fwd(&0, "hello").expect("fwd ok");
        let cloned = original.clone();
        assert_eq!(cloned.stop_reason_digest, original.stop_reason_digest);
        assert_eq!(cloned.thinking_digest, original.thinking_digest);
        assert_eq!(cloned.stop_reason, original.stop_reason);
        assert_eq!(cloned.value, original.value);
        assert_eq!(cloned.thinking, original.thinking);
        assert!(cloned.digest_intact());
    }

    #[test]
    fn para_output_none_thinking_vs_empty_some_thinking_produce_distinct_digests() {
        // Phase 1 hardening — thinking-digest distinguishability.
        // `thinking: None` is encoded as the zero hash; `thinking:
        // Some(vec![])` (empty bytes) is encoded as blake3 of empty
        // input — which is NOT zero. These two states must remain
        // distinguishable through thinking_digest so a replay can
        // tell apart "no thinking content at all" vs "empty
        // thinking block" (the latter is what a provider sends
        // when the assistant has thinking enabled but produced
        // none for a turn). Both must still pass digest_intact.
        let none_out: ParaOutput<u32> =
            ParaOutput::new(0, StopReason::EndTurn, None);
        let empty_some_out: ParaOutput<u32> =
            ParaOutput::new(0, StopReason::EndTurn, Some(vec![]));
        assert_eq!(none_out.thinking_digest, [0u8; 32]);
        assert_ne!(
            empty_some_out.thinking_digest, [0u8; 32],
            "Some(empty) must NOT digest to zero — empty-bytes blake3 ≠ zero"
        );
        assert_ne!(none_out.thinking_digest, empty_some_out.thinking_digest);
        // And both still pass forensic intactness.
        assert!(none_out.digest_intact());
        assert!(empty_some_out.digest_intact());
        // Stop-reason digests differ too (because thinking_digest
        // is fed into the stop_reason hasher).
        assert_ne!(none_out.stop_reason_digest, empty_some_out.stop_reason_digest);
    }

    #[test]
    fn stop_reason_digest_domain_separation_prefix_is_pinned_for_replay_parity() {
        // Phase 1 hardening — replay-parity-critical domain-separation
        // prefix. ParaOutput::new feeds an exact byte string into
        // blake3 before stop_reason canonical bytes: "agent_runtime_v2.para.stop_reason\n"
        // + canonical_bytes(stop_reason) + "\nthinking\n" + thinking_digest.
        // A silent typo or rename would silently fork every replay
        // digest. Pin by independently computing the digest of a
        // known fixture (EndTurn, thinking=None) and comparing.
        let out: ParaOutput<()> = ParaOutput::new((), StopReason::EndTurn, None);
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"agent_runtime_v2.para.stop_reason\n");
        hasher.update(StopReason::EndTurn.canonical_bytes());
        hasher.update(b"\nthinking\n");
        hasher.update(&[0u8; 32]); // thinking_digest for None
        let expected = *hasher.finalize().as_bytes();
        assert_eq!(
            out.stop_reason_digest, expected,
            "stop_reason_digest prefix/shape drift breaks replay parity",
        );
    }

    #[test]
    fn fwd_output_digest_is_intact_immediately() {
        let exec = ToyExecutor;
        let out = exec.fwd(&0, "hello").expect("fwd ok");
        assert_eq!(out.stop_reason, StopReason::EndTurn);
        assert!(out.digest_intact());
    }

    #[test]
    fn reverse_leg_cannot_mutate_stop_reason() {
        // The §4 T11 invariant: "reverse leg cannot mutate stop reason".
        // Compile-time enforcement: `rev` takes `&ParaOutput`, so any
        // attempt to assign to `output.stop_reason` would fail to build.
        // Runtime forensic check: digest comparison before vs after rev.
        let exec = ToyExecutor;
        let out = exec.fwd(&0, "hello").expect("fwd ok");
        let digest_before = out.stop_reason_digest;
        let thinking_before = out.thinking_digest;
        let _feedback = exec.rev(&0, &out).expect("rev ok");
        assert_eq!(
            out.stop_reason_digest, digest_before,
            "rev mutated stop_reason_digest — Para contract violated"
        );
        assert_eq!(
            out.thinking_digest, thinking_before,
            "rev mutated thinking_digest — thinking-blocks-hash-identical invariant violated"
        );
        assert!(
            out.digest_intact(),
            "post-rev digest_intact() must remain true"
        );
    }

    #[test]
    fn thinking_blocks_round_trip_with_identical_hash() {
        let exec = ToyExecutor;
        let out = exec.fwd(&0, "hi").expect("fwd ok");
        let thinking = out.thinking.as_deref().expect("toy emits thinking bytes");
        let independent_hash = *blake3::hash(thinking).as_bytes();
        assert_eq!(
            independent_hash, out.thinking_digest,
            "thinking-block digest must match an independent BLAKE3 recompute"
        );
    }

    #[test]
    fn thinking_blocks_preserved_across_n_tool_hops() {
        // Phase 1 deep hardening — user's explicit hardening list:
        // "across N tool_use ↔ tool_result hops, signatures intact,
        //  content array byte-equal, no element reordering, no
        //  signature loss even on retry / cancel / mid-stream-error".
        //
        // Construct a chain of N=5 ParaOutputs that simulate a 5-hop
        // tool_use → tool_result → tool_use → ... sequence. Each
        // carries the SAME thinking bytes (the canonical preservation
        // contract). After every hop assert digest_intact and that
        // the thinking_digest matches an independent BLAKE3 recompute.
        const N: usize = 5;
        let thinking = b"sig:0xCAFEBABE thinking-chain preserved\0".to_vec();
        let independent_digest = *blake3::hash(&thinking).as_bytes();

        // Even StopReason variants alternate hop-by-hop — none of
        // them should affect the thinking_digest preservation.
        let hop_stop_reasons = [
            StopReason::ToolUse,
            StopReason::ToolUse,
            StopReason::ToolUse,
            StopReason::ToolUse,
            StopReason::EndTurn,
        ];

        let mut last_thinking_digest: Option<[u8; 32]> = None;
        for hop in 0..N {
            let out = ParaOutput::new(
                format!("hop-{hop}"),
                hop_stop_reasons[hop],
                Some(thinking.clone()),
            );
            assert!(out.digest_intact(), "hop {hop}: digest not intact");
            assert_eq!(
                out.thinking_digest, independent_digest,
                "hop {hop}: thinking_digest drifted from independent recompute"
            );
            if let Some(prev) = last_thinking_digest {
                assert_eq!(
                    out.thinking_digest, prev,
                    "hop {hop}: thinking_digest changed across the hop chain"
                );
            }
            last_thinking_digest = Some(out.thinking_digest);
        }
    }

    #[test]
    fn thinking_blocks_preserved_after_mid_stream_error_recovery() {
        // Simulate the "no signature loss even on ... mid-stream-error"
        // sub-clause: an error hop is interleaved with normal hops;
        // the thinking_digest must survive the error variant
        // unchanged.
        let thinking = b"error-recovery thinking sig".to_vec();
        let independent = *blake3::hash(&thinking).as_bytes();
        let normal = ParaOutput::new(
            "ok".to_string(),
            StopReason::ToolUse,
            Some(thinking.clone()),
        );
        let errored = ParaOutput::new(
            "err".to_string(),
            StopReason::Error,
            Some(thinking.clone()),
        );
        let recovered = ParaOutput::new(
            "after-err".to_string(),
            StopReason::EndTurn,
            Some(thinking.clone()),
        );
        for out in [&normal, &errored, &recovered] {
            assert!(out.digest_intact());
            assert_eq!(out.thinking_digest, independent);
        }
        // All three independently land on the same thinking_digest —
        // the StopReason variant has no effect on thinking preservation.
        assert_eq!(normal.thinking_digest, errored.thinking_digest);
        assert_eq!(errored.thinking_digest, recovered.thinking_digest);
    }

    #[test]
    fn forged_thinking_digest_caught_by_digest_intact() {
        // Adversarial: an attacker constructs a ParaOutput whose
        // thinking bytes don't match the stored thinking_digest
        // (e.g. swapping thinking bytes mid-flight while hoping the
        // digest passes through unnoticed). digest_intact() must
        // catch this — the thinking_digest is recomputed from the
        // actual bytes and compared.
        let exec = ToyExecutor;
        let mut out = exec.fwd(&0, "x").expect("fwd ok");
        // Mutate the thinking bytes WITHOUT recomputing the digests.
        // (The frozen-output semantics make this impossible through
        // the trait surface; we simulate the breach by mutating the
        // owned local directly.)
        if let Some(t) = out.thinking.as_mut() {
            t[0] ^= 0xFF;
        }
        assert!(
            !out.digest_intact(),
            "forged thinking bytes must invalidate the digest"
        );
    }

    #[test]
    fn tampered_thinking_digest_field_alone_caught_even_with_intact_bytes() {
        // Phase 1 hardening — adversarial fixture targeting the
        // load-bearing early-return guard in digest_intact() at the
        // `if recomputed_thinking != self.thinking_digest` line.
        //
        // Symmetric to forged_thinking_digest_caught_by_digest_intact
        // (which mutates the bytes), this fixture mutates the
        // STORED thinking_digest field ALONE, leaving bytes +
        // stop_reason_digest untouched. Without the early-return
        // guard, digest_intact() would still recompute the correct
        // stop_reason_digest from the (untouched) bytes — and the
        // tampered thinking_digest would slip through unnoticed.
        //
        // This pins the guard: without it, the attack "I want a
        // ParaOutput whose recorded thinking_digest disagrees with
        // the bytes but whose stop_reason_digest still verifies"
        // would succeed.
        let mut out: ParaOutput<u32> =
            ParaOutput::new(0, StopReason::EndTurn, Some(b"intact-bytes".to_vec()));
        // Sanity: starts intact.
        assert!(out.digest_intact());
        // Mutate the stored thinking_digest alone — flip one bit.
        out.thinking_digest[0] ^= 0xFF;
        // stop_reason_digest is UNCHANGED. thinking bytes are UNCHANGED.
        // The only breach is the recorded thinking_digest field.
        assert!(
            !out.digest_intact(),
            "tampered thinking_digest field must invalidate digest_intact even when bytes + \
             stop_reason_digest are intact (load-bearing early-return guard)"
        );
    }

    #[test]
    fn tampered_stop_reason_digest_field_alone_caught() {
        // Phase 1 hardening — second leg of the digest-field
        // adversarial pair. Mutate stop_reason_digest field ALONE,
        // leaving bytes + thinking_digest + stop_reason variant
        // intact. The hasher recompute must catch the breach via
        // the final equality check.
        let mut out: ParaOutput<u32> =
            ParaOutput::new(0, StopReason::EndTurn, Some(b"intact".to_vec()));
        assert!(out.digest_intact());
        out.stop_reason_digest[31] ^= 0xFF;
        assert!(
            !out.digest_intact(),
            "tampered stop_reason_digest field must invalidate digest_intact"
        );
    }

    #[test]
    fn tampering_with_stop_reason_breaks_digest() {
        // Forensic-path coverage: if a future refactor swaps the shared
        // reference for `&mut`, the digest-intact check still catches the
        // breach. We simulate the breach manually by mutating a clone.
        let exec = ToyExecutor;
        let mut out = exec.fwd(&0, "hi").expect("fwd ok");
        // Direct mutation only possible on this owned local — proves the
        // forensic path catches the breach even when the type system is
        // bypassed.
        out.stop_reason = StopReason::Refusal;
        assert!(
            !out.digest_intact(),
            "mutating stop_reason must invalidate the digest"
        );
    }
}
