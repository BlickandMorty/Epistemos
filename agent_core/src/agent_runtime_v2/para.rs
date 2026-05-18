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
    pub fn canonical_bytes(self) -> &'static [u8] {
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
