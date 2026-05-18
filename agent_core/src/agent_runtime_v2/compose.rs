//! `ParaSeq` — sequential composition of two `Para` morphisms.
//!
//! Given `Para<P, A, B>` and `Para<P, B, C>` sharing parameter type `P`,
//! `ParaSeq` runs them in sequence and chains the reverse legs in the
//! categorically natural order: `rev` of the outer (second) stage runs
//! first, then `rev` of the inner (first) stage.
//!
//! The Para reverse-leg invariant **lifts through composition** — both
//! stage outputs remain frozen across the composed `rev`, and the
//! digest-intact check still catches any tampering at either stage.
//! This module's property test is the load-bearing artifact for that
//! claim.

use std::marker::PhantomData;

use super::para::{Para, ParaError, ParaFeedback, ParaOutput, StopReason};

/// Identity Para — forwards `A` unchanged and reports `EndTurn`.
/// Useful as a left/right unit for `ParaSeq` (`Y ∘ id_A = Y` and
/// `id_A ∘ id_A = id_A`) and as a test fixture for the identity law.
pub struct IdentityPara<P> {
    _phantom: PhantomData<P>,
}

impl<P> IdentityPara<P> {
    #[must_use]
    pub const fn new() -> Self {
        Self {
            _phantom: PhantomData,
        }
    }
}

impl<P> Default for IdentityPara<P> {
    fn default() -> Self {
        Self::new()
    }
}

impl<P, A> Para<P, A, A> for IdentityPara<P>
where
    P: Send + Sync,
    A: Send + Sync,
{
    fn fwd(&self, _params: &P, input: A) -> Result<ParaOutput<A>, ParaError> {
        Ok(ParaOutput::new(input, StopReason::EndTurn, None))
    }

    fn rev(&self, _params: &P, _output: &ParaOutput<A>) -> Result<ParaFeedback<P>, ParaError>
    where
        P: Sized,
    {
        // Identity reverse must produce a feedback delta but cannot
        // construct an arbitrary `P` without help. Callers wanting a
        // composable identity provide their own — we deliberately
        // return an error here so misuse surfaces loudly.
        Err(ParaError::Transport(
            "IdentityPara::rev requires P: Default — use a domain-specific identity instead"
                .to_string(),
        ))
    }
}

/// Sequential composition `Y ∘ X`. Stores the two Paras by reference
/// so the caller controls lifetimes; mirrors the `Para` trait's
/// `fwd`/`rev` surface but is not itself a `Para` implementor (its
/// output type is a pair of `ParaOutput`s — a future iteration can
/// add an adapter trait if the dispatcher needs uniform handling).
pub struct ParaSeq<'a, P, A, B, C, X, Y>
where
    X: Para<P, A, B>,
    Y: Para<P, B, C>,
{
    pub first: &'a X,
    pub second: &'a Y,
    _phantom: PhantomData<(P, A, B, C)>,
}

/// Joined output. Holds the inner-stage and outer-stage outputs so the
/// composed `rev` can present both frozen `ParaOutput`s to its caller.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParaSeqOutput<B, C> {
    pub inner: ParaOutput<B>,
    pub outer: ParaOutput<C>,
}

/// Joined feedback. Reverse-leg of the outer stage runs first; the
/// feedback the engine applies is the sum of both stage deltas — but
/// that sum lives outside this layer (engine-decided), so we just
/// surface both deltas in stage order.
#[derive(Debug)]
pub struct ParaSeqFeedback<P> {
    /// Reverse-leg feedback from the *outer* (second) stage. Produced
    /// first because chain rule runs back-to-front.
    pub outer: ParaFeedback<P>,
    /// Reverse-leg feedback from the *inner* (first) stage.
    pub inner: ParaFeedback<P>,
}

impl<'a, P, A, B, C, X, Y> ParaSeq<'a, P, A, B, C, X, Y>
where
    X: Para<P, A, B>,
    Y: Para<P, B, C>,
    B: Clone,
{
    pub fn new(first: &'a X, second: &'a Y) -> Self {
        Self {
            first,
            second,
            _phantom: PhantomData,
        }
    }

    /// Composed forward leg: `first.fwd(p, a) → b`, then
    /// `second.fwd(p, b.value) → c`. Both `ParaOutput`s are kept so
    /// the composed `rev` can hand both back as shared references.
    pub fn fwd(&self, params: &P, input: A) -> Result<ParaSeqOutput<B, C>, ParaError> {
        let inner = self.first.fwd(params, input)?;
        // We pass the inner value to the outer stage's fwd; the inner
        // ParaOutput is preserved verbatim. B: Clone bound lets the
        // outer stage consume an owned B without disturbing the inner
        // output's value field.
        let outer = self.second.fwd(params, inner.value.clone())?;
        Ok(ParaSeqOutput { inner, outer })
    }

    /// Composed reverse leg: outer.rev runs first (chain rule),
    /// then inner.rev. Both invocations take `&ParaOutput` so neither
    /// stage's `stop_reason` or `thinking` is mutable — the
    /// compile-time guarantee lifts through composition.
    pub fn rev(
        &self,
        params: &P,
        output: &ParaSeqOutput<B, C>,
    ) -> Result<ParaSeqFeedback<P>, ParaError> {
        let outer = self.second.rev(params, &output.outer)?;
        let inner = self.first.rev(params, &output.inner)?;
        Ok(ParaSeqFeedback { outer, inner })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime_v2::para::{ParaOutput, StopReason};

    /// Stage 1: takes &str, returns its length.
    struct LenStage;
    impl Para<u32, &'static str, usize> for LenStage {
        fn fwd(&self, _p: &u32, input: &'static str) -> Result<ParaOutput<usize>, ParaError> {
            Ok(ParaOutput::new(
                input.len(),
                StopReason::EndTurn,
                Some(b"len-thinking".to_vec()),
            ))
        }
        fn rev(
            &self,
            _p: &u32,
            output: &ParaOutput<usize>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            // Forensic-friendly: read only.
            let _ = output.value;
            Ok(ParaFeedback { delta: 1 })
        }
    }

    /// Stage 2: takes a length, returns "len=N".
    struct LabelStage;
    impl Para<u32, usize, String> for LabelStage {
        fn fwd(&self, _p: &u32, input: usize) -> Result<ParaOutput<String>, ParaError> {
            Ok(ParaOutput::new(
                format!("len={input}"),
                StopReason::EndTurn,
                Some(b"label-thinking".to_vec()),
            ))
        }
        fn rev(
            &self,
            _p: &u32,
            output: &ParaOutput<String>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            let _ = output.value.len();
            Ok(ParaFeedback { delta: 2 })
        }
    }

    #[test]
    fn composed_forward_chains_values() {
        let seq = ParaSeq::new(&LenStage, &LabelStage);
        let out = seq.fwd(&0, "hello").expect("fwd ok");
        assert_eq!(out.inner.value, 5);
        assert_eq!(out.outer.value, "len=5");
        assert_eq!(out.inner.stop_reason, StopReason::EndTurn);
        assert_eq!(out.outer.stop_reason, StopReason::EndTurn);
        assert!(out.inner.digest_intact());
        assert!(out.outer.digest_intact());
    }

    #[test]
    fn composed_reverse_leg_cannot_mutate_either_stop_reason() {
        // The §4 T11 reverse-leg-cannot-mutate-stop_reason invariant
        // must LIFT through Para composition. Snapshot both stage
        // digests, run composed rev, assert both intact.
        let seq = ParaSeq::new(&LenStage, &LabelStage);
        let out = seq.fwd(&0, "hello").expect("fwd ok");
        let inner_sr = out.inner.stop_reason_digest;
        let inner_th = out.inner.thinking_digest;
        let outer_sr = out.outer.stop_reason_digest;
        let outer_th = out.outer.thinking_digest;
        let fb = seq.rev(&0, &out).expect("rev ok");
        assert_eq!(fb.inner.delta, 1);
        assert_eq!(fb.outer.delta, 2);
        assert_eq!(out.inner.stop_reason_digest, inner_sr);
        assert_eq!(out.inner.thinking_digest, inner_th);
        assert_eq!(out.outer.stop_reason_digest, outer_sr);
        assert_eq!(out.outer.thinking_digest, outer_th);
        assert!(out.inner.digest_intact());
        assert!(out.outer.digest_intact());
    }

    /// A failing-fwd stage used to prove ParaSeq short-circuits on
    /// inner-stage error before invoking the outer stage.
    struct FailingFwd;
    impl Para<u32, &'static str, usize> for FailingFwd {
        fn fwd(&self, _p: &u32, _input: &'static str) -> Result<ParaOutput<usize>, ParaError> {
            Err(ParaError::Transport("inner fwd refuses".into()))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<usize>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Ok(ParaFeedback { delta: 0 })
        }
    }

    /// A stage that panics if its fwd is ever called — used to prove
    /// the outer stage is NOT invoked when the inner returns Err.
    struct MustNotBeCalled;
    impl Para<u32, usize, String> for MustNotBeCalled {
        fn fwd(&self, _p: &u32, _input: usize) -> Result<ParaOutput<String>, ParaError> {
            panic!("outer stage must not be called when inner Err short-circuits");
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<String>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Ok(ParaFeedback { delta: 0 })
        }
    }

    #[test]
    fn para_seq_short_circuits_on_inner_fwd_error() {
        // §3.5 deep-hardening edge case: composed fwd must NOT invoke
        // outer.fwd when inner.fwd returned Err. MustNotBeCalled
        // panics if reached; absence of panic proves the short-circuit.
        let seq = ParaSeq::new(&FailingFwd, &MustNotBeCalled);
        let err = seq.fwd(&0, "hello").expect_err("inner fwd refuses");
        assert!(
            matches!(err, ParaError::Transport(ref s) if s == "inner fwd refuses"),
            "expected Transport(\"inner fwd refuses\"), got {err:?}"
        );
    }

    #[test]
    fn identity_left_unit_preserves_inner_stage_values_and_digests() {
        // Identity law (left unit, for the forward direction):
        // ParaSeq(IdentityPara, LenStage).fwd(p, a) ≅ LenStage.fwd(p, a)
        // in the sense that the OUTER output of the composed forward
        // matches what LenStage alone would produce.
        let id = IdentityPara::<u32>::new();
        let seq = ParaSeq::new(&id, &LenStage);
        let out = seq.fwd(&0, "hello").expect("fwd ok");
        // Inner (id) just echoes the input
        assert_eq!(out.inner.value, "hello");
        assert_eq!(out.inner.stop_reason, StopReason::EndTurn);
        // Outer (LenStage) sees the echoed value and computes len=5
        assert_eq!(out.outer.value, 5);
        assert_eq!(out.outer.stop_reason, StopReason::EndTurn);
        // Stand-alone LenStage produces the same outer
        let stand_alone = LenStage.fwd(&0, "hello").expect("fwd ok");
        assert_eq!(stand_alone.value, out.outer.value);
        assert_eq!(stand_alone.stop_reason, out.outer.stop_reason);
        assert_eq!(stand_alone.thinking_digest, out.outer.thinking_digest);
    }

    /// Outer stage that always reports BudgetExhausted (rather than
    /// EndTurn) to exercise the composed-output stop-reason path.
    struct BudgetExhaustedStage;
    impl Para<u32, usize, String> for BudgetExhaustedStage {
        fn fwd(&self, _p: &u32, _input: usize) -> Result<ParaOutput<String>, ParaError> {
            Ok(ParaOutput::new(
                "out-of-budget".to_string(),
                StopReason::BudgetExhausted,
                Some(b"budget-exhausted-thinking".to_vec()),
            ))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<String>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Ok(ParaFeedback { delta: 0 })
        }
    }

    /// Compile-time helper: this function only compiles if `T: Send +
    /// Sync`. Used by the Send/Sync bound test below to assert
    /// statically that `ParaSeq` lifts the trait bounds of its stages.
    fn assert_send_sync<T: Send + Sync>() {}

    #[test]
    fn para_seq_is_send_sync_when_stages_are() {
        // Phase 1 hardening — `ParaSeq` must be `Send + Sync` so the
        // executor pool can ship it across worker threads. The two
        // stages (`LenStage`, `LabelStage`) are zero-sized + Send +
        // Sync, so the composed `ParaSeq` reference must inherit
        // both. assert_send_sync is a const-style probe — if `ParaSeq`
        // ever loses Send/Sync (e.g. via a non-Send field), this
        // test fails to compile.
        assert_send_sync::<ParaSeq<'_, u32, &'static str, usize, String, LenStage, LabelStage>>();
    }

    #[test]
    fn composed_outer_stop_reason_propagates_to_seq_output() {
        // Phase 1 hardening — when the outer stage reports a non-
        // EndTurn stop (BudgetExhausted), the ParaSeqOutput must
        // carry that stop_reason verbatim on its outer leg, while
        // the inner leg keeps its own EndTurn. Proves the composed
        // output does not flatten / collapse stop reasons.
        let seq = ParaSeq::new(&LenStage, &BudgetExhaustedStage);
        let out = seq.fwd(&0, "hello").expect("fwd ok");
        assert_eq!(out.inner.stop_reason, StopReason::EndTurn);
        assert_eq!(out.outer.stop_reason, StopReason::BudgetExhausted);
        assert!(out.inner.digest_intact());
        assert!(out.outer.digest_intact());
        assert_ne!(out.inner.stop_reason_digest, out.outer.stop_reason_digest);
    }

    #[test]
    fn composed_thinking_blocks_remain_hash_identical_across_stages() {
        let seq = ParaSeq::new(&LenStage, &LabelStage);
        let out = seq.fwd(&0, "abc").expect("fwd ok");
        let inner_th_independent = *blake3::hash(b"len-thinking").as_bytes();
        let outer_th_independent = *blake3::hash(b"label-thinking").as_bytes();
        assert_eq!(out.inner.thinking_digest, inner_th_independent);
        assert_eq!(out.outer.thinking_digest, outer_th_independent);
    }
}
