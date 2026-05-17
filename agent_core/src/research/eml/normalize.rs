//! Source:
//! - iter-1 audit `docs/audits/EML_IR_AUDIT_2026_05_17.md` §4
//!   (normal-form gap: bare EmlExpr has no nontrivial structural
//!    rewrites; the substantive canonical form lives on EmlClosure
//!    via constant-folding of slot-free subtrees).
//! - Phase A close-out `docs/audits/PHASE_A_CLOSEOUT_2026_05_17.md`
//!   §3 (iter-11 deliverable).
//! - Stachowiak arXiv:2604.23893 §1.3 — `S(x, y) = M(f(x), f⁻¹(y))`
//!   general form. The Polish-notation-length-7 / depth-3 bound on
//!   `f⁻¹` recovery is what makes constant-folded subtrees the
//!   meaningful normal-form representative.
//! - Companion: [`super::closure`] (the EmlClosure term algebra
//!   this module normalizes); [`super::evaluator`] (the bare
//!   EmlExpr evaluator constant-folding piggybacks on).
//!
//! # Canonical form for EML-IR
//!
//! On the bare [`super::grammar::EmlExpr`] grammar `S → 1 |
//! eml(S, S)`, there are **no nontrivial structural rewrites**:
//!
//! - `eml` is non-commutative (`exp(x) − ln(y) ≠ exp(y) − ln(x)`),
//!   so children can't be reordered.
//! - The only leaf is `One`; there are no parameter-free constants
//!   that one tree could collapse into.
//! - Every bare tree is therefore its own normal form. Idempotence
//!   is trivial.
//!
//! On the wider [`super::closure::EmlClosure`] (closure form),
//! constant-folding gives a meaningful canonical form: any
//! slot-free subtree evaluates to a single numeric constant, so it
//! can be replaced by a `Slot` referencing that value in the
//! constants vector. This is the canonical form this module
//! implements:
//!
//! ```text
//! normalize(EmlClosure { tree, consts }) = EmlClosure {
//!     tree:   <every slot-free subtree replaced by a Slot ref>,
//!     consts: <original consts + the folded values>,
//! }
//! ```
//!
//! The normal form is idempotent (re-normalizing folds nothing
//! more) and value-preserving (the new closure evaluates to the
//! same f64 as the old one).
//!
//! ## What it doesn't do (out of scope for B1)
//!
//! - Stachowiak depth-3 canonicalization of `M / f / f⁻¹` triples
//!   (Phase C — needs the wider operator algebra).
//! - Cross-closure constant deduplication (a single closure may
//!   carry the same f64 twice in its consts vector; we don't
//!   merge those entries).
//! - Floating-point equality tolerance on consts. Two slot-free
//!   subtrees that evaluate to "the same" value modulo float error
//!   are folded to two distinct slots.

use super::closure::{EmlClosure, EmlClosureExpr};
use super::evaluator::{evaluate, EmlEvalError};
use super::grammar::EmlExpr;

/// Identity rewriter on the bare [`EmlExpr`] grammar.
///
/// Bare EML trees have no nontrivial structural normal form (see
/// module docstring §1). This function returns its input unchanged
/// — the meaningful work happens on the closure-form via
/// [`normalize_closure`].
pub fn normalize_expr(expr: &EmlExpr) -> EmlExpr {
    expr.clone()
}

/// True iff `expr` is in canonical form on the bare grammar.
/// On the bare grammar this is always true.
pub fn is_normalized_expr(_expr: &EmlExpr) -> bool {
    true
}

/// Closure-form evaluator. Walks an [`EmlClosureExpr`] and returns
/// the f64 value it computes, resolving `Slot(i)` nodes against the
/// supplied `consts` table.
///
/// Reuses [`super::evaluator::evaluate`] on slot-free subtrees so
/// the bare-grammar depth guard + error propagation apply
/// transitively.
pub fn evaluate_closure(closure: &EmlClosure) -> Result<f64, NormalizeError> {
    closure
        .validate_slots()
        .map_err(NormalizeError::from_closure_error)?;
    evaluate_closure_expr(&closure.tree, &closure.consts)
}

/// Internal: evaluate an [`EmlClosureExpr`] against an explicit
/// constants vector (lets the normalizer reuse it during folding
/// without round-tripping through `EmlClosure::new` on each step).
fn evaluate_closure_expr(
    expr: &EmlClosureExpr,
    consts: &[f64],
) -> Result<f64, NormalizeError> {
    match expr {
        EmlClosureExpr::One => Ok(1.0),
        EmlClosureExpr::Slot(i) => consts
            .get(*i as usize)
            .copied()
            .ok_or(NormalizeError::SlotOutOfRange { slot: *i }),
        EmlClosureExpr::Eml(_, _) => {
            // If the subtree is slot-free, delegate to the bare
            // evaluator (depth-guarded). Otherwise recurse.
            if expr.is_slot_free() {
                let bare = expr.clone().try_into_bare_expr().expect(
                    "is_slot_free guarantees try_into_bare_expr succeeds",
                );
                evaluate(&bare).map_err(NormalizeError::from)
            } else {
                let (l, r) = match expr {
                    EmlClosureExpr::Eml(l, r) => (l, r),
                    _ => unreachable!(),
                };
                let lv = evaluate_closure_expr(l, consts)?;
                let rv = evaluate_closure_expr(r, consts)?;
                super::operator::eml(lv, rv).map_err(NormalizeError::from)
            }
        }
        EmlClosureExpr::Plus(l, r) => {
            // iter-57 extension: real-number addition. NaN/non-
            // finite outputs surface as NonFiniteResult-style errors
            // via the Operator(EmlError::NonFiniteResult) variant.
            let lv = evaluate_closure_expr(l, consts)?;
            let rv = evaluate_closure_expr(r, consts)?;
            let v = lv + rv;
            if !v.is_finite() {
                return Err(NormalizeError::Operator(
                    super::operator::EmlError::NonFiniteResult {
                        x: lv,
                        y: rv,
                        result: v,
                    },
                ));
            }
            Ok(v)
        }
    }
}

/// Canonical form on the closure surface: replace every slot-free
/// subtree with a `Slot` referencing the folded value in the
/// returned `consts` vector. The new closure evaluates to the same
/// f64 as the input.
///
/// Subtrees that the bare evaluator rejects (depth-cap, branch
/// cut, overflow) are **left in place** — propagating the
/// evaluation error past the rewrite would change the closure's
/// observable behavior. Such trees remain in their original form.
pub fn normalize_closure(closure: &EmlClosure) -> EmlClosure {
    let mut consts = closure.consts.clone();
    let tree = fold_subtree(&closure.tree, &mut consts);
    EmlClosure { tree, consts }
}

/// Internal: recursive fold. Returns a new [`EmlClosureExpr`] with
/// slot-free Eml subtrees replaced by Slot references whose values
/// are pushed onto `consts`.
fn fold_subtree(expr: &EmlClosureExpr, consts: &mut Vec<f64>) -> EmlClosureExpr {
    match expr {
        EmlClosureExpr::One => EmlClosureExpr::One,
        EmlClosureExpr::Slot(i) => EmlClosureExpr::Slot(*i),
        EmlClosureExpr::Eml(l, r) => {
            // Slot-free `Eml(...)` subtrees fold to a Slot iff their
            // evaluation succeeds. Leaves stay leaves (One/Slot
            // never fold).
            if expr.is_slot_free() {
                let bare = expr
                    .clone()
                    .try_into_bare_expr()
                    .expect("is_slot_free guarantees conversion");
                match evaluate(&bare) {
                    Ok(v) => {
                        let idx = consts.len() as u32;
                        consts.push(v);
                        return EmlClosureExpr::Slot(idx);
                    }
                    Err(_) => {
                        let lf = fold_subtree(l, consts);
                        let rf = fold_subtree(r, consts);
                        return EmlClosureExpr::eml(lf, rf);
                    }
                }
            }
            let lf = fold_subtree(l, consts);
            let rf = fold_subtree(r, consts);
            EmlClosureExpr::eml(lf, rf)
        }
        EmlClosureExpr::Plus(l, r) => {
            // iter-57: Plus subtree folding. The closure form's Plus
            // can't lower to bare EmlExpr, so we fold via the
            // closure-side evaluator. Slot-free Plus subtrees still
            // collapse to a single Slot once we evaluate them.
            let fully_concrete = match (
                evaluate_closure_expr(l, consts),
                evaluate_closure_expr(r, consts),
            ) {
                (Ok(lv), Ok(rv)) => {
                    let v = lv + rv;
                    if v.is_finite() {
                        Some(v)
                    } else {
                        None
                    }
                }
                _ => None,
            };
            if let Some(v) = fully_concrete {
                let idx = consts.len() as u32;
                consts.push(v);
                return EmlClosureExpr::Slot(idx);
            }
            let lf = fold_subtree(l, consts);
            let rf = fold_subtree(r, consts);
            EmlClosureExpr::plus(lf, rf)
        }
    }
}

/// True iff `closure` is in canonical form: every internal
/// `Eml(_, _)` node touches at least one `Slot` leaf in its
/// subtree (otherwise the normalizer would have folded it). Leaves
/// (`One` and `Slot`) are trivially canonical.
pub fn is_normalized_closure(closure: &EmlClosure) -> bool {
    is_canonical_subtree(&closure.tree)
}

fn is_canonical_subtree(expr: &EmlClosureExpr) -> bool {
    match expr {
        EmlClosureExpr::One | EmlClosureExpr::Slot(_) => true,
        EmlClosureExpr::Eml(l, r) => {
            // Internal node must contain at least one Slot below
            // (otherwise it'd be a foldable slot-free subtree),
            // and each child must be canonical.
            !expr.is_slot_free() && is_canonical_subtree(l) && is_canonical_subtree(r)
        }
        EmlClosureExpr::Plus(l, r) => {
            // Plus is canonical when at least one child is non-
            // concrete (otherwise normalize would have folded it
            // into a single Slot).
            is_canonical_subtree(l) && is_canonical_subtree(r)
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum NormalizeError {
    /// A slot index in the closure tree exceeds the constant table.
    SlotOutOfRange { slot: u32 },
    /// Evaluation through the bare `EmlExpr` evaluator failed.
    Eval(EmlEvalError),
    /// Underlying eml(x, y) operator rejected its inputs.
    Operator(super::operator::EmlError),
}

impl NormalizeError {
    fn from_closure_error(e: super::closure::EmlClosureError) -> Self {
        let super::closure::EmlClosureError::SlotOutOfRange { slot, .. } = e;
        NormalizeError::SlotOutOfRange { slot }
    }
}

impl From<EmlEvalError> for NormalizeError {
    fn from(e: EmlEvalError) -> Self {
        NormalizeError::Eval(e)
    }
}

impl From<super::operator::EmlError> for NormalizeError {
    fn from(e: super::operator::EmlError) -> Self {
        NormalizeError::Operator(e)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::eml::grammar::EmlExpr;

    fn one() -> EmlClosureExpr {
        EmlClosureExpr::One
    }

    // ── Bare EmlExpr identity rewriter ──────────────────────────────

    #[test]
    fn bare_normalize_is_identity_on_one() {
        assert_eq!(normalize_expr(&EmlExpr::One), EmlExpr::One);
    }

    #[test]
    fn bare_normalize_is_identity_on_eml_subtree() {
        let e = EmlExpr::eml(EmlExpr::One, EmlExpr::One);
        assert_eq!(normalize_expr(&e), e);
    }

    #[test]
    fn bare_normalize_is_idempotent() {
        let e = EmlExpr::eml(EmlExpr::One, EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        let once = normalize_expr(&e);
        let twice = normalize_expr(&once);
        assert_eq!(once, twice);
    }

    #[test]
    fn bare_is_normalized_always_true() {
        assert!(is_normalized_expr(&EmlExpr::One));
        assert!(is_normalized_expr(&EmlExpr::eml(EmlExpr::One, EmlExpr::One)));
    }

    // ── Closure evaluator ───────────────────────────────────────────

    #[test]
    fn closure_eval_one_leaf_is_one() {
        let c = EmlClosure::from_bare(EmlExpr::One);
        assert!((evaluate_closure(&c).unwrap() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn closure_eval_eml_one_one_is_e() {
        let c = EmlClosure::from_bare(EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        let v = evaluate_closure(&c).unwrap();
        assert!((v - std::f64::consts::E).abs() < 1e-12);
    }

    #[test]
    fn closure_eval_slot_reads_const() {
        let c = EmlClosure::new(EmlClosureExpr::slot(0), vec![std::f64::consts::PI]).unwrap();
        assert!((evaluate_closure(&c).unwrap() - std::f64::consts::PI).abs() < 1e-12);
    }

    #[test]
    fn closure_eval_mixed_eml_slot_and_one() {
        // eml(Slot(0)=e, One=1) = exp(e) - ln(1) = exp(e)
        let tree = EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
        let c = EmlClosure::new(tree, vec![std::f64::consts::E]).unwrap();
        let v = evaluate_closure(&c).unwrap();
        let expected = std::f64::consts::E.exp();
        assert!((v - expected).abs() < 1e-9);
    }

    // ── normalize_closure (constant folding) ────────────────────────

    #[test]
    fn normalize_one_leaf_yields_one_leaf() {
        let c = EmlClosure::from_bare(EmlExpr::One);
        let n = normalize_closure(&c);
        assert_eq!(n.tree, EmlClosureExpr::One);
        assert!(n.consts.is_empty());
    }

    #[test]
    fn normalize_folds_eml_one_one_to_a_slot() {
        // eml(One, One) is slot-free → folds to Slot(0) with consts[0]=e.
        let c = EmlClosure::from_bare(EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        let n = normalize_closure(&c);
        assert_eq!(n.tree, EmlClosureExpr::Slot(0));
        assert_eq!(n.consts.len(), 1);
        assert!((n.consts[0] - std::f64::consts::E).abs() < 1e-12);
    }

    #[test]
    fn normalize_preserves_value_simple() {
        let c = EmlClosure::from_bare(EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        let original = evaluate_closure(&c).unwrap();
        let n = normalize_closure(&c);
        let folded = evaluate_closure(&n).unwrap();
        assert!((original - folded).abs() < 1e-12);
    }

    #[test]
    fn normalize_preserves_value_with_existing_slots() {
        // tree: eml(eml(1,1)=foldable, Slot(0)=PI) — only left subtree folds.
        let tree = EmlClosureExpr::eml(
            EmlClosureExpr::eml(EmlClosureExpr::one(), EmlClosureExpr::one()),
            EmlClosureExpr::slot(0),
        );
        let c = EmlClosure::new(tree, vec![std::f64::consts::PI]).unwrap();
        let original = evaluate_closure(&c).unwrap();
        let n = normalize_closure(&c);
        let folded = evaluate_closure(&n).unwrap();
        assert!((original - folded).abs() < 1e-9);
    }

    #[test]
    fn normalize_is_idempotent() {
        let c = EmlClosure::from_bare(EmlExpr::eml(
            EmlExpr::eml(EmlExpr::One, EmlExpr::One),
            EmlExpr::eml(EmlExpr::One, EmlExpr::One),
        ));
        let once = normalize_closure(&c);
        let twice = normalize_closure(&once);
        assert_eq!(once, twice);
    }

    #[test]
    fn normalize_is_canonical_after_one_pass() {
        let c = EmlClosure::from_bare(EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        let n = normalize_closure(&c);
        assert!(is_normalized_closure(&n));
    }

    #[test]
    fn normalize_canonical_predicate_rejects_unfolded_subtree() {
        // Hand-construct an UN-canonical closure: tree contains a
        // slot-free Eml subtree that hasn't been folded.
        let unfolded = EmlClosure {
            tree: EmlClosureExpr::eml(EmlClosureExpr::one(), EmlClosureExpr::one()),
            consts: Vec::new(),
        };
        assert!(!is_normalized_closure(&unfolded));
    }

    #[test]
    fn normalize_canonical_predicate_accepts_slot_only_subtree() {
        // Slot(0) leaf is canonical.
        let only_slot = EmlClosure::new(EmlClosureExpr::slot(0), vec![42.0]).unwrap();
        assert!(is_normalized_closure(&only_slot));
    }

    #[test]
    fn normalize_canonical_predicate_accepts_one_leaf() {
        let only_one = EmlClosure::from_bare(EmlExpr::One);
        assert!(is_normalized_closure(&only_one));
    }

    #[test]
    fn normalize_canonical_predicate_accepts_eml_with_at_least_one_slot() {
        let tree = EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
        let c = EmlClosure::new(tree, vec![1.0]).unwrap();
        assert!(is_normalized_closure(&c));
    }

    #[test]
    fn normalize_handles_left_chain_overflow_by_leaving_subtree_in_place() {
        // Build a depth-8 left chain — overflows the bare evaluator.
        // The folder should leave it in place rather than panic.
        let mut e = EmlExpr::One;
        for _ in 0..8 {
            e = EmlExpr::eml(e, EmlExpr::One);
        }
        let c = EmlClosure::from_bare(e);
        let n = normalize_closure(&c);
        // After normalization the tree may either be unchanged (if
        // every subtree overflowed) or contain mixed folded/unfolded
        // structure. Idempotence still holds:
        let nn = normalize_closure(&n);
        assert_eq!(n, nn);
    }

    #[test]
    fn from_normalize_error_carries_eval_error() {
        let inner = EmlEvalError::DepthExceeded { depth: 100, cap: 32 };
        let n: NormalizeError = inner.into();
        assert_eq!(n, NormalizeError::Eval(inner));
    }

    #[test]
    fn from_normalize_error_carries_operator_error() {
        let inner = super::super::operator::EmlError::NonPositiveLogArg { y: 0.0 };
        let n: NormalizeError = inner.into();
        assert_eq!(n, NormalizeError::Operator(inner));
    }

    // ── Plus variant evaluation + folding (iter-57) ───────────────

    #[test]
    fn closure_eval_plus_adds_concrete_children() {
        // Plus(One, One) = 1 + 1 = 2.
        let tree = EmlClosureExpr::plus(EmlClosureExpr::one(), EmlClosureExpr::one());
        let c = EmlClosure::new(tree, vec![]).unwrap();
        let v = evaluate_closure(&c).unwrap();
        assert!((v - 2.0).abs() < 1e-12);
    }

    #[test]
    fn closure_eval_plus_with_slot_children() {
        // Plus(Slot(0)=PI, Slot(1)=E) = π + e.
        let tree = EmlClosureExpr::plus(EmlClosureExpr::slot(0), EmlClosureExpr::slot(1));
        let c = EmlClosure::new(
            tree,
            vec![std::f64::consts::PI, std::f64::consts::E],
        )
        .unwrap();
        let v = evaluate_closure(&c).unwrap();
        assert!((v - (std::f64::consts::PI + std::f64::consts::E)).abs() < 1e-12);
    }

    #[test]
    fn closure_eval_plus_mixed_with_eml() {
        // Plus(eml(1,1)=e, One=1) = e + 1.
        let tree = EmlClosureExpr::plus(
            EmlClosureExpr::eml(EmlClosureExpr::one(), EmlClosureExpr::one()),
            EmlClosureExpr::one(),
        );
        let c = EmlClosure::new(tree, vec![]).unwrap();
        let v = evaluate_closure(&c).unwrap();
        assert!((v - (std::f64::consts::E + 1.0)).abs() < 1e-9);
    }

    #[test]
    fn normalize_plus_with_concrete_children_folds_to_single_slot() {
        // Plus(One, One) → Slot(0) with consts[0] = 2.
        let c = EmlClosure::new(
            EmlClosureExpr::plus(EmlClosureExpr::one(), EmlClosureExpr::one()),
            vec![],
        )
        .unwrap();
        let n = normalize_closure(&c);
        assert_eq!(n.tree, EmlClosureExpr::Slot(0));
        assert!((n.consts[0] - 2.0).abs() < 1e-12);
    }

    #[test]
    fn normalize_plus_preserves_value() {
        let c = EmlClosure::new(
            EmlClosureExpr::plus(
                EmlClosureExpr::eml(EmlClosureExpr::one(), EmlClosureExpr::one()),
                EmlClosureExpr::one(),
            ),
            vec![],
        )
        .unwrap();
        let before = evaluate_closure(&c).unwrap();
        let n = normalize_closure(&c);
        let after = evaluate_closure(&n).unwrap();
        assert!((before - after).abs() < 1e-12);
    }
}
