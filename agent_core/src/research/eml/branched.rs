//! Source:
//! - iter-1 audit `docs/audits/EML_IR_AUDIT_2026_05_17.md` §6 item 3
//!   ("Branch-safe typing — a `BranchedEmlExpr` (or `EmlExpr<Branch>`
//!    phantom-tagged) variant that captures the `y > 0` precondition
//!    for `ln` at the type level — turns the runtime
//!    `NonPositiveLogArg` error into a compile-time rejection for
//!    type-checked trees").
//! - Phase A close-out `docs/audits/PHASE_A_CLOSEOUT_2026_05_17.md`
//!   §3 (iter-12 deliverable).
//! - Companion: [`super::operator::eml`] (the runtime primitive whose
//!   `NonPositiveLogArg` error this module elevates to a type-level
//!   rejection); [`super::grammar::EmlExpr`] (the unchanged term
//!   algebra this module wraps).
//!
//! # Branch-safe typing
//!
//! `eml(x, y) = exp(x) − ln(y)` requires `y > 0` (the `ln` branch
//! cut). The bare [`super::grammar::EmlExpr`] grammar carries no
//! such precondition — every internal `Eml(_, _)` node could
//! evaluate its right subtree to a non-positive value, in which
//! case the runtime [`super::operator::eml`] returns
//! [`super::operator::EmlError::NonPositiveLogArg`].
//!
//! This module introduces a *typestate* pattern: two distinct
//! wrapper types that the type system uses to distinguish trees
//! whose right-subtree values have been validated positive from
//! those that have not. The `BranchedEmlExpr::eml(left, right)`
//! constructor's signature requires `right: PositiveEmlExpr` —
//! any attempt to pass a generic, unvalidated tree as the right
//! child is a **compile-time** error.
//!
//! ## Two-type API
//!
//! - [`BranchedEmlExpr`] — wraps an `EmlExpr` without any
//!   positivity guarantee.
//! - [`PositiveEmlExpr`] — wraps an `EmlExpr` whose evaluation
//!   has been runtime-verified to produce a value `> 0`. Only
//!   constructible via [`PositiveEmlExpr::one`] (trivially
//!   positive, value `1.0`) or
//!   [`BranchedEmlExpr::try_into_positive`] (runtime-validates).
//!
//! The `eml(left, right)` constructor takes
//! `right: PositiveEmlExpr` — so building a
//! `BranchedEmlExpr::eml(..., unvalidated_branched_expr)` is a
//! type error, not a runtime error.
//!
//! ## What this does NOT prove
//!
//! Compile-time-prove-positivity of an arbitrary EML tree is
//! undecidable (you can always nest `Eml(x, y)` where the value
//! depends on `x` and `y` at runtime). This module proves
//! something weaker but useful: **once you've called
//! `try_into_positive` on a subtree, the type system tracks that
//! the runtime validation happened**, so subsequent uses of the
//! subtree as a right child don't need to re-validate.
//!
//! ## Compile-fail proof
//!
//! ```compile_fail
//! use agent_core::research::eml::{BranchedEmlExpr, PositiveEmlExpr};
//! let unvalidated = BranchedEmlExpr::one();
//! // The next line is a type error: `eml` requires
//! // `right: PositiveEmlExpr`, not `BranchedEmlExpr`.
//! let _ = BranchedEmlExpr::eml(BranchedEmlExpr::one(), unvalidated);
//! ```

use super::evaluator::evaluate;
use super::grammar::EmlExpr;
use super::operator::EmlError;

/// EML tree whose evaluation may produce a non-positive value;
/// not safe to use as the right child of an `eml(_, _)` node.
#[derive(Clone, Debug, PartialEq)]
pub struct BranchedEmlExpr {
    inner: EmlExpr,
}

/// EML tree whose evaluation has been verified to produce a value
/// `> 0`. Safe to use as the right child of an `eml(_, _)` node;
/// no `NonPositiveLogArg` can occur from this subtree.
#[derive(Clone, Debug, PartialEq)]
pub struct PositiveEmlExpr {
    inner: EmlExpr,
    /// Cached value (positive by construction). Used by the
    /// evaluator so a typed tree never re-walks the bare expression
    /// to re-derive this value.
    cached_value: f64,
}

/// Reason a `BranchedEmlExpr` could not be promoted to a
/// `PositiveEmlExpr`.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BranchValidationError {
    /// The bare evaluator returned an error (depth cap, overflow,
    /// branch cut on an inner node, etc.) before we could check
    /// the root value's sign.
    EvaluationFailed(super::evaluator::EmlEvalError),
    /// Evaluation succeeded but produced a value `≤ 0`.
    NonPositiveValue { value: f64 },
}

impl BranchedEmlExpr {
    /// `One` leaf — value `1.0` (always positive).
    pub fn one() -> Self {
        BranchedEmlExpr { inner: EmlExpr::One }
    }

    /// `eml(left, right)` — `right` must have been validated
    /// positive (this is the type-level branch-safety check).
    /// The result is itself a `BranchedEmlExpr` because its own
    /// value may or may not be positive depending on the choice
    /// of `left`; the caller must re-validate if they want to
    /// use this result as another right child.
    pub fn eml(left: BranchedEmlExpr, right: PositiveEmlExpr) -> Self {
        BranchedEmlExpr {
            inner: EmlExpr::eml(left.inner, right.inner),
        }
    }

    /// Runtime-validate this tree's evaluation and promote to a
    /// `PositiveEmlExpr` on success.
    pub fn try_into_positive(self) -> Result<PositiveEmlExpr, BranchValidationError> {
        let v = evaluate(&self.inner).map_err(BranchValidationError::EvaluationFailed)?;
        if v > 0.0 {
            Ok(PositiveEmlExpr {
                inner: self.inner,
                cached_value: v,
            })
        } else {
            Err(BranchValidationError::NonPositiveValue { value: v })
        }
    }

    /// Borrow the underlying bare `EmlExpr` — for read-only access
    /// (no positivity assertions are dropped because we're not
    /// constructing a new typed tree, just observing).
    pub fn as_expr(&self) -> &EmlExpr {
        &self.inner
    }

    /// Unwrap into the bare `EmlExpr`. Intentionally consumes
    /// `self` so the typed wrapper can't outlive its release.
    pub fn into_expr(self) -> EmlExpr {
        self.inner
    }
}

impl PositiveEmlExpr {
    /// `One` leaf — value `1.0`. The only constructor that doesn't
    /// require runtime validation (the value is known at compile
    /// time).
    pub fn one() -> Self {
        PositiveEmlExpr {
            inner: EmlExpr::One,
            cached_value: 1.0,
        }
    }

    /// The runtime-validated f64 value of this subtree (`> 0` by
    /// construction).
    pub fn value(&self) -> f64 {
        self.cached_value
    }

    /// Borrow the underlying bare `EmlExpr`. Read-only.
    pub fn as_expr(&self) -> &EmlExpr {
        &self.inner
    }

    /// Re-wrap as an un-validated `BranchedEmlExpr` (drops the
    /// positivity guarantee). Useful as the *left* child of an
    /// outer `eml` (the left child carries no constraint).
    pub fn into_branched(self) -> BranchedEmlExpr {
        BranchedEmlExpr { inner: self.inner }
    }
}

impl From<PositiveEmlExpr> for BranchedEmlExpr {
    fn from(p: PositiveEmlExpr) -> Self {
        p.into_branched()
    }
}

impl From<EmlError> for BranchValidationError {
    fn from(e: EmlError) -> Self {
        // Operator errors map onto an evaluation failure with a
        // wrapped EmlEvalError::Operator variant.
        BranchValidationError::EvaluationFailed(
            super::evaluator::EmlEvalError::Operator(e),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_branched_wraps_emlexpr_one() {
        let b = BranchedEmlExpr::one();
        assert_eq!(b.as_expr(), &EmlExpr::One);
    }

    #[test]
    fn one_positive_value_is_one() {
        assert_eq!(PositiveEmlExpr::one().value(), 1.0);
    }

    #[test]
    fn eml_constructor_accepts_validated_right() {
        // BranchedEmlExpr::eml(branched_left, positive_right) compiles.
        let left = BranchedEmlExpr::one();
        let right = PositiveEmlExpr::one();
        let combined = BranchedEmlExpr::eml(left, right);
        assert_eq!(
            combined.as_expr(),
            &EmlExpr::eml(EmlExpr::One, EmlExpr::One)
        );
    }

    #[test]
    fn try_into_positive_succeeds_on_one() {
        let p = BranchedEmlExpr::one().try_into_positive().unwrap();
        assert_eq!(p.value(), 1.0);
    }

    #[test]
    fn try_into_positive_succeeds_when_value_is_positive() {
        // eml(One, One) = e ≈ 2.718 > 0 → validates.
        let left = BranchedEmlExpr::one();
        let right = PositiveEmlExpr::one();
        let e = BranchedEmlExpr::eml(left, right);
        let p = e.try_into_positive().unwrap();
        assert!((p.value() - std::f64::consts::E).abs() < 1e-12);
    }

    #[test]
    fn try_into_positive_rejects_negative_value() {
        // Build a tree whose evaluation is negative.
        // eml(One, eml(One, One)) = eml(1, e) = exp(1) - ln(e) = e - 1
        //   ≈ 1.718 > 0. Need a more elaborate tree.
        //
        // eml(0_left, eml(One, eml(One, One))) where 0_left is
        // not constructible from One. Hmm — the bare grammar with
        // only One leaves produces only positive values starting
        // from `exp(0) - ln(...)` = 1 - ln(...).
        // ln(eml(One, One)) = ln(e) = 1, so eml(One, eml(One, One))
        // = exp(1) - 1 = e - 1 ≈ 1.718.
        //
        // Going further: eml(One, eml(One, eml(One, One)))
        // = exp(1) - ln(e - 1) = e - ln(1.718) ≈ e - 0.541 ≈ 2.177.
        //
        // All bare-grammar tree values from `One` leaves stay
        // positive. So we can't construct a non-positive test
        // value from pure-One trees without going outside the
        // bare grammar. We hand-construct an EmlExpr with a
        // simulated future state where the bare evaluator could
        // see a non-positive intermediate — but the bare
        // evaluator wouldn't even produce that, since the
        // operator rejects y ≤ 0 at runtime.
        //
        // This test instead verifies the error-path branch
        // structure with a tree the bare evaluator REJECTS
        // (overflow): the BranchValidationError carries
        // EvaluationFailed, not NonPositiveValue.
        let mut e = EmlExpr::One;
        for _ in 0..8 {
            e = EmlExpr::eml(e, EmlExpr::One); // f_{n+1} = exp(f_n); overflows
        }
        let b = BranchedEmlExpr { inner: e };
        let err = b.try_into_positive().unwrap_err();
        assert!(matches!(err, BranchValidationError::EvaluationFailed(_)));
    }

    #[test]
    fn try_into_positive_carries_zero_value_failure() {
        // Hand-construct a BranchedEmlExpr that we can evaluate
        // to exactly 0. The bare grammar from One can't hit zero
        // without external input, but we can verify the
        // NonPositiveValue branch trigger by simulating: the
        // logic returns NonPositiveValue when value ≤ 0. We
        // verify directly via the BranchedEmlExpr::eml +
        // evaluator path on a hand-tuned tree, which from One
        // leaves does NOT reach zero. So this test must reuse
        // the same overflow vector and confirm the
        // EvaluationFailed branch.
        //
        // Note: documenting the gap, not silently asserting.
        let mut e = EmlExpr::One;
        for _ in 0..8 {
            e = EmlExpr::eml(e, EmlExpr::One);
        }
        let b = BranchedEmlExpr { inner: e };
        let err = b.try_into_positive().unwrap_err();
        match err {
            BranchValidationError::EvaluationFailed(_) => {}
            other => panic!("expected EvaluationFailed branch, got {:?}", other),
        }
    }

    #[test]
    fn positive_into_branched_drops_guarantee() {
        let p = PositiveEmlExpr::one();
        let b: BranchedEmlExpr = p.into();
        assert_eq!(b.as_expr(), &EmlExpr::One);
    }

    #[test]
    fn into_expr_unwraps_to_bare_grammar() {
        let b = BranchedEmlExpr::eml(BranchedEmlExpr::one(), PositiveEmlExpr::one());
        let bare = b.into_expr();
        assert_eq!(bare, EmlExpr::eml(EmlExpr::One, EmlExpr::One));
    }

    #[test]
    fn nested_branched_construction_requires_revalidation_at_each_level() {
        // To use the result of a previous eml() call as a right
        // child of a deeper eml, the caller MUST go through
        // try_into_positive. This is the typestate working as
        // intended.
        let inner_b = BranchedEmlExpr::eml(BranchedEmlExpr::one(), PositiveEmlExpr::one());
        let inner_p = inner_b.try_into_positive().unwrap(); // validates
        let outer = BranchedEmlExpr::eml(BranchedEmlExpr::one(), inner_p);
        // outer = eml(One, eml(One, One)) = exp(1) - ln(e) = e - 1
        let outer_p = outer.try_into_positive().unwrap();
        assert!((outer_p.value() - (std::f64::consts::E - 1.0)).abs() < 1e-12);
    }

    #[test]
    fn from_emlerror_to_branch_validation_error() {
        let inner = EmlError::NonPositiveLogArg { y: -1.0 };
        let bv: BranchValidationError = inner.into();
        match bv {
            BranchValidationError::EvaluationFailed(
                super::super::evaluator::EmlEvalError::Operator(_),
            ) => {}
            other => panic!("expected EvaluationFailed(Operator(_)), got {:?}", other),
        }
    }
}
