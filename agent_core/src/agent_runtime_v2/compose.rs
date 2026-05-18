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

    /// Stage 3: takes a String label, returns the byte length of it.
    /// Used by the triple-composition associativity test.
    struct LabelLenStage;
    impl Para<u32, String, usize> for LabelLenStage {
        fn fwd(&self, _p: &u32, input: String) -> Result<ParaOutput<usize>, ParaError> {
            Ok(ParaOutput::new(
                input.len(),
                StopReason::EndTurn,
                Some(b"label-len-thinking".to_vec()),
            ))
        }
        fn rev(
            &self,
            _p: &u32,
            output: &ParaOutput<usize>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            let _ = output.value;
            Ok(ParaFeedback { delta: 4 })
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
    fn every_para_seq_output_field_is_identity_load_bearing() {
        // Phase 1 hardening — fourteenth leg of the identity-pin
        // pattern. ParaSeqOutput<B, C> has 2 fields (inner, outer);
        // each must participate in PartialEq derivation. The
        // composed forward leg returns these as a pair; downstream
        // consumers (engine feedback application) compare composed
        // outputs by full equality. A silent #[serde(skip)] /
        // PartialEq override dropping either field would silently
        // collapse distinct composed outputs.
        let seq = ParaSeq::new(&LenStage, &LabelStage);
        let base = seq.fwd(&0, "hello").expect("fwd ok");

        // Mutate inner.value → equality breaks via inner participation.
        let mut diff_inner = base.clone();
        diff_inner.inner.value += 1;
        assert_ne!(diff_inner, base, "inner must participate in PartialEq");

        // Mutate outer.value → equality breaks via outer participation.
        let mut diff_outer = base.clone();
        diff_outer.outer.value.push_str("!");
        assert_ne!(diff_outer, base, "outer must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base.clone(), base);
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
    fn triple_composition_value_associativity_holds_for_happy_path() {
        // Phase 1 hardening — ParaSeq is not itself a Para (its output
        // is a paired ParaSeqOutput<B,C>, not a ParaOutput<C>), so we
        // can't compose three Paras into a single nested ParaSeq
        // expression. But the SEMANTIC associativity ((A∘B)∘C ≡
        // A∘(B∘C)) is still observable: the final-stage value, stop
        // reason, and thinking digest must match regardless of which
        // pair we group with ParaSeq first.
        //
        // Left grouping:  (LenStage ∘ LabelStage) then run LabelLenStage manually.
        // Right grouping: LenStage manually then (LabelStage ∘ LabelLenStage).
        //
        // We assert byte-equal value, stop_reason, and thinking_digest
        // at the C-stage output between the two groupings.

        // Left grouping.
        let seq_left = ParaSeq::new(&LenStage, &LabelStage);
        let left_inner = seq_left.fwd(&0, "hello").expect("left seq fwd ok");
        let left_outer_c = LabelLenStage
            .fwd(&0, left_inner.outer.value.clone())
            .expect("left stage3 fwd ok");

        // Right grouping.
        let right_a = LenStage.fwd(&0, "hello").expect("right stage1 fwd ok");
        let seq_right = ParaSeq::new(&LabelStage, &LabelLenStage);
        let right_outer = seq_right
            .fwd(&0, right_a.value)
            .expect("right seq fwd ok");

        // Final C-stage value must be byte-equal.
        assert_eq!(left_outer_c.value, right_outer.outer.value);
        // Final stop_reason must be byte-equal (StopReason is Copy +
        // PartialEq; the per-variant canonical byte form is what
        // the digest hashes).
        assert_eq!(left_outer_c.stop_reason, right_outer.outer.stop_reason);
        // Thinking digest must be byte-equal — proves the C stage
        // produced the same thinking-block payload regardless of
        // grouping. This is the strongest associativity bar we can
        // assert without the dispatcher unifying ParaSeq into a Para.
        assert_eq!(left_outer_c.thinking_digest, right_outer.outer.thinking_digest);
        // And both terminal outputs must still pass the digest_intact
        // forensic gate (no silent mutation in either path).
        assert!(left_outer_c.digest_intact());
        assert!(right_outer.outer.digest_intact());
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

    /// Configurable stage that lets the test pick which StopReason
    /// to emit. Used by the 7×7 matrix test.
    struct ConfigurableStage<I, O> {
        out: O,
        reason: StopReason,
        _i: PhantomData<I>,
    }
    impl<I, O> ConfigurableStage<I, O> {
        fn new(out: O, reason: StopReason) -> Self {
            Self {
                out,
                reason,
                _i: PhantomData,
            }
        }
    }
    impl<I: Send + Sync, O: Clone + Send + Sync> Para<u32, I, O> for ConfigurableStage<I, O> {
        fn fwd(&self, _p: &u32, _input: I) -> Result<ParaOutput<O>, ParaError> {
            Ok(ParaOutput::new(self.out.clone(), self.reason, None))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<O>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Ok(ParaFeedback { delta: 0 })
        }
    }

    #[test]
    fn para_seq_handles_all_7x7_stop_reason_combinations() {
        // Phase 1 hardening — combinatorial matrix: 7 StopReason
        // variants × 7 = 49 combinations of inner/outer stop. For
        // each combination, the composed fwd must succeed and the
        // resulting ParaSeqOutput must carry the correct stops on
        // each leg. When the two stops differ, their digests differ;
        // when they match, the digests match too.
        let all = [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ];
        for &inner_reason in &all {
            for &outer_reason in &all {
                let inner = ConfigurableStage::<&'static str, usize>::new(0, inner_reason);
                let outer = ConfigurableStage::<usize, String>::new("done".to_string(), outer_reason);
                let seq = ParaSeq::new(&inner, &outer);
                let out = seq
                    .fwd(&0, "input")
                    .expect("any-stop combo must produce a valid composed output");
                assert_eq!(out.inner.stop_reason, inner_reason);
                assert_eq!(out.outer.stop_reason, outer_reason);
                assert!(out.inner.digest_intact());
                assert!(out.outer.digest_intact());
                if inner_reason == outer_reason {
                    assert_eq!(out.inner.stop_reason_digest, out.outer.stop_reason_digest);
                } else {
                    assert_ne!(out.inner.stop_reason_digest, out.outer.stop_reason_digest);
                }
            }
        }
    }

    /// Outer stage whose rev returns Err — used to short-circuit
    /// before inner.rev runs.
    struct OuterRevFails;
    impl Para<u32, usize, String> for OuterRevFails {
        fn fwd(&self, _p: &u32, _input: usize) -> Result<ParaOutput<String>, ParaError> {
            Ok(ParaOutput::new(
                "outer-ok".to_string(),
                StopReason::EndTurn,
                None,
            ))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<String>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Err(ParaError::Transport("outer rev refuses".into()))
        }
    }

    /// Inner stage whose rev panics if reached.
    struct InnerRevMustNotBeCalled;
    impl Para<u32, &'static str, usize> for InnerRevMustNotBeCalled {
        fn fwd(&self, _p: &u32, _input: &'static str) -> Result<ParaOutput<usize>, ParaError> {
            Ok(ParaOutput::new(0, StopReason::EndTurn, None))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<usize>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            panic!("inner.rev must not be called when outer.rev short-circuits");
        }
    }

    #[test]
    fn para_seq_short_circuits_on_outer_rev_error() {
        // Mirror of the fwd short-circuit: composed rev runs outer
        // first (chain rule); if outer.rev fails, inner.rev MUST NOT
        // run. The panic in InnerRevMustNotBeCalled would fire if
        // the short-circuit is missing — absence of panic proves it.
        let seq = ParaSeq::new(&InnerRevMustNotBeCalled, &OuterRevFails);
        let out = seq.fwd(&0, "input").expect("fwd ok");
        let err = seq.rev(&0, &out).expect_err("outer rev refuses");
        assert!(
            matches!(err, ParaError::Transport(ref s) if s == "outer rev refuses"),
            "expected Transport(\"outer rev refuses\"), got {err:?}"
        );
    }

    /// Inner stage whose rev returns Err — used to pin propagation
    /// of the inner-rev error after outer.rev succeeds.
    struct InnerRevFails;
    impl Para<u32, &'static str, usize> for InnerRevFails {
        fn fwd(&self, _p: &u32, _input: &'static str) -> Result<ParaOutput<usize>, ParaError> {
            Ok(ParaOutput::new(0, StopReason::EndTurn, None))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<usize>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Err(ParaError::Transport("inner rev refuses".into()))
        }
    }

    /// Outer stage whose rev succeeds normally — paired with
    /// InnerRevFails to prove the composed rev propagates the inner
    /// error AFTER outer.rev produced its feedback.
    struct OuterRevSucceeds;
    impl Para<u32, usize, String> for OuterRevSucceeds {
        fn fwd(&self, _p: &u32, _input: usize) -> Result<ParaOutput<String>, ParaError> {
            Ok(ParaOutput::new(
                "outer-ok".to_string(),
                StopReason::EndTurn,
                None,
            ))
        }
        fn rev(
            &self,
            _p: &u32,
            _output: &ParaOutput<String>,
        ) -> Result<ParaFeedback<u32>, ParaError> {
            Ok(ParaFeedback { delta: 99 })
        }
    }

    #[test]
    fn para_seq_propagates_inner_rev_error_after_outer_rev_succeeds() {
        // Phase 1 hardening — symmetric companion to
        // para_seq_short_circuits_on_outer_rev_error. Composed rev
        // runs outer first (chain rule); if outer.rev SUCCEEDS but
        // inner.rev returns Err, the composed rev must:
        //   (1) surface the inner.rev error verbatim,
        //   (2) drop the outer.rev feedback silently (the `?` on
        //       inner abandons the outer ParaFeedback) — the caller
        //       sees no half-returned ParaSeqFeedback.
        //
        // Without this pin, a future refactor that swapped the chain
        // order (inner.rev first, then outer.rev) would silently
        // change which side surfaces first AND change which
        // side's side-effects accumulate before failure. Both
        // matter for engine-decided feedback application.
        let seq = ParaSeq::new(&InnerRevFails, &OuterRevSucceeds);
        let out = seq.fwd(&0, "hello").expect("fwd ok");
        // outer.rev would produce delta=99 if it ran; assert below it
        // never reaches the caller because inner.rev errors.
        let err = seq.rev(&0, &out).expect_err("inner rev refuses");
        assert!(
            matches!(err, ParaError::Transport(ref s) if s == "inner rev refuses"),
            "expected Transport(\"inner rev refuses\"), got {err:?}"
        );
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
    fn identity_para_fwd_standalone_echoes_input_value_with_intact_digest() {
        // Phase 1 hardening — IdentityPara forward leg is THE
        // canonical identity morphism: fwd(p, a) must return
        // ParaOutput{value: a, stop_reason: EndTurn, thinking: None}.
        // The existing tests exercise IdentityPara only through
        // ParaSeq composition; this pins the standalone semantics
        // so a future refactor that puts logic in IdentityPara::fwd
        // (e.g. wrapping thinking with metadata) surfaces at PR
        // review rather than silently breaking identity-law tests.
        let id = IdentityPara::<u32>::new();
        let out = id.fwd(&0, 42usize).expect("identity fwd ok");
        assert_eq!(out.value, 42);
        assert_eq!(out.stop_reason, StopReason::EndTurn);
        assert!(out.thinking.is_none(), "IdentityPara must produce no thinking");
        assert_eq!(out.thinking_digest, [0u8; 32]);
        assert!(out.digest_intact());

        // Try a non-Copy value too — String — to prove the move
        // works without cloning or stringification.
        let id_str = IdentityPara::<u32>::new();
        let s = "hello world".to_string();
        let out_s = id_str.fwd(&0, s.clone()).expect("identity fwd string ok");
        assert_eq!(out_s.value, s);
        assert!(out_s.digest_intact());
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
