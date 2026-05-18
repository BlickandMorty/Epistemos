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
