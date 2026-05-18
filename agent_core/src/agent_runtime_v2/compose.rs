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

use super::para::{Para, ParaError, ParaFeedback, ParaOutput};

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
