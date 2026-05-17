//! Source:
//! - iter-1 audit `docs/audits/EML_IR_AUDIT_2026_05_17.md` §3
//!   ("Open design question for B1": sibling-type `EmlClosure { tree,
//!    consts }` chosen over `Const(f64)` variant on `EmlExpr` to keep
//!    the canonical term algebra `S → 1 | eml(S, S)` clean).
//! - Phase B1 entry-slice plan `docs/audits/PHASE_A_CLOSEOUT_2026_05_17.md`
//!   §3 (iter-10 deliverable).
//! - Stachowiak arXiv:2604.23893 §1.3 — general form `S(x, y) =
//!   M(f(x), f⁻¹(y))` motivates a parameterizable surface above the
//!   canonical term algebra.
//!
//! # EML closure-form term algebra
//!
//! Real elementary functions take numeric arguments. The canonical
//! [`super::grammar::EmlExpr`] grammar is parameter-free (only the
//! terminal `1`), so on its own it represents only the closure of
//! `1` under `eml` — a small constant subset of `ℝ`. To represent
//! an *elementary function of one or more variables*, we lift the
//! tree to a closure form where leaves are either:
//!
//! - the canonical `1`, or
//! - a `Slot(idx)` referencing a numeric constant carried alongside
//!   the tree in [`EmlClosure::consts`].
//!
//! The wrapping struct [`EmlClosure`] holds `(tree, consts)`; the
//! tree references `consts` by index. The canonical-form rewriter
//! (lands iter-11) operates on the bare [`EmlExpr`] grammar without
//! ever seeing a slot — constants are opaque to normalization. This
//! preserves the Stachowiak structural decomposition.
//!
//! Going from a closure back to a bare `EmlExpr` is only well-defined
//! when the closure carries no slots (`consts.is_empty()`).
//! [`EmlClosureExpr::try_into_bare_expr`] enforces that.

use super::grammar::EmlExpr;
use serde::{Deserialize, Serialize};

/// Closure-form term: extends `EmlExpr` with numeric slots.
///
/// Slot indices must be `< consts.len()` in the parent [`EmlClosure`]
/// — see [`EmlClosure::validate_slots`].
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum EmlClosureExpr {
    One,
    Slot(u32),
    Eml(Box<EmlClosureExpr>, Box<EmlClosureExpr>),
}

impl EmlClosureExpr {
    /// `One` leaf — the canonical constant.
    pub fn one() -> Self {
        EmlClosureExpr::One
    }

    /// Slot referencing the index-th constant in the parent closure's
    /// `consts` vector.
    pub fn slot(idx: u32) -> Self {
        EmlClosureExpr::Slot(idx)
    }

    /// `eml(left, right)` internal node.
    pub fn eml(left: EmlClosureExpr, right: EmlClosureExpr) -> Self {
        EmlClosureExpr::Eml(Box::new(left), Box::new(right))
    }

    /// Highest slot index appearing anywhere in this tree, or `None`
    /// if the tree contains no slots. Used by
    /// [`EmlClosure::validate_slots`].
    pub fn max_slot(&self) -> Option<u32> {
        match self {
            EmlClosureExpr::One => None,
            EmlClosureExpr::Slot(i) => Some(*i),
            EmlClosureExpr::Eml(l, r) => match (l.max_slot(), r.max_slot()) {
                (None, None) => None,
                (Some(a), None) | (None, Some(a)) => Some(a),
                (Some(a), Some(b)) => Some(a.max(b)),
            },
        }
    }

    /// True if the tree contains no `Slot` nodes.
    pub fn is_slot_free(&self) -> bool {
        match self {
            EmlClosureExpr::One => true,
            EmlClosureExpr::Slot(_) => false,
            EmlClosureExpr::Eml(l, r) => l.is_slot_free() && r.is_slot_free(),
        }
    }

    /// Convert back to a bare [`EmlExpr`] iff the tree is slot-free.
    /// Returns `None` if any `Slot` node appears.
    pub fn try_into_bare_expr(self) -> Option<EmlExpr> {
        match self {
            EmlClosureExpr::One => Some(EmlExpr::One),
            EmlClosureExpr::Slot(_) => None,
            EmlClosureExpr::Eml(l, r) => {
                let lb = l.try_into_bare_expr()?;
                let rb = r.try_into_bare_expr()?;
                Some(EmlExpr::eml(lb, rb))
            }
        }
    }

    /// Tree depth (canonical form preserves the same recursion as
    /// `EmlExpr::depth` — slots count as depth-0 leaves).
    pub fn depth(&self) -> usize {
        match self {
            EmlClosureExpr::One | EmlClosureExpr::Slot(_) => 0,
            EmlClosureExpr::Eml(l, r) => 1 + l.depth().max(r.depth()),
        }
    }
}

impl From<EmlExpr> for EmlClosureExpr {
    /// Lift a bare `EmlExpr` into the closure-form term algebra. No
    /// slots introduced; the closure that wraps this would carry
    /// `consts == &[]`.
    fn from(e: EmlExpr) -> Self {
        match e {
            EmlExpr::One => EmlClosureExpr::One,
            EmlExpr::Eml(l, r) => EmlClosureExpr::eml((*l).into(), (*r).into()),
        }
    }
}

/// `EmlClosureExpr` paired with a constant table.
///
/// The tree's `Slot(idx)` nodes index into `consts`. The pair is
/// **valid** iff every slot index in the tree is `< consts.len()`
/// ([`EmlClosure::validate_slots`]).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EmlClosure {
    pub tree: EmlClosureExpr,
    pub consts: Vec<f64>,
}

/// Validation error for closure construction.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum EmlClosureError {
    /// A slot index in the tree exceeds the constant table size.
    SlotOutOfRange { slot: u32, consts_len: usize },
}

impl EmlClosure {
    /// Construct a closure with explicit validation. Returns
    /// `SlotOutOfRange` if any slot in `tree` references an index
    /// `≥ consts.len()`.
    pub fn new(tree: EmlClosureExpr, consts: Vec<f64>) -> Result<Self, EmlClosureError> {
        if let Some(max) = tree.max_slot() {
            if (max as usize) >= consts.len() {
                return Err(EmlClosureError::SlotOutOfRange {
                    slot: max,
                    consts_len: consts.len(),
                });
            }
        }
        Ok(EmlClosure { tree, consts })
    }

    /// Lift a bare [`EmlExpr`] into an empty-constants closure.
    /// Always succeeds (no slots → no validation work).
    pub fn from_bare(e: EmlExpr) -> Self {
        EmlClosure {
            tree: e.into(),
            consts: Vec::new(),
        }
    }

    /// `true` iff the closure carries no constants and the tree is
    /// slot-free. Such a closure is round-trippable to a bare
    /// `EmlExpr` via [`EmlClosureExpr::try_into_bare_expr`].
    pub fn is_bare(&self) -> bool {
        self.consts.is_empty() && self.tree.is_slot_free()
    }

    /// Cross-check: every slot in the tree must reference a valid
    /// `consts` index. Idempotent (this is exactly the check
    /// [`Self::new`] runs).
    pub fn validate_slots(&self) -> Result<(), EmlClosureError> {
        if let Some(max) = self.tree.max_slot() {
            if (max as usize) >= self.consts.len() {
                return Err(EmlClosureError::SlotOutOfRange {
                    slot: max,
                    consts_len: self.consts.len(),
                });
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_leaf_is_slot_free() {
        assert!(EmlClosureExpr::one().is_slot_free());
    }

    #[test]
    fn slot_leaf_is_not_slot_free() {
        assert!(!EmlClosureExpr::slot(0).is_slot_free());
    }

    #[test]
    fn one_has_no_max_slot() {
        assert_eq!(EmlClosureExpr::one().max_slot(), None);
    }

    #[test]
    fn slot_max_is_index() {
        assert_eq!(EmlClosureExpr::slot(7).max_slot(), Some(7));
    }

    #[test]
    fn eml_max_slot_takes_max_of_subtrees() {
        let e = EmlClosureExpr::eml(EmlClosureExpr::slot(3), EmlClosureExpr::slot(5));
        assert_eq!(e.max_slot(), Some(5));
    }

    #[test]
    fn mixed_eml_max_slot_skips_one_leaves() {
        let e = EmlClosureExpr::eml(EmlClosureExpr::one(), EmlClosureExpr::slot(2));
        assert_eq!(e.max_slot(), Some(2));
    }

    #[test]
    fn depth_matches_eml_expr_when_slot_free() {
        let bare = EmlExpr::eml(EmlExpr::One, EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        let lifted: EmlClosureExpr = bare.clone().into();
        assert_eq!(bare.depth(), lifted.depth());
    }

    #[test]
    fn from_emlexpr_preserves_one() {
        let lifted: EmlClosureExpr = EmlExpr::One.into();
        assert_eq!(lifted, EmlClosureExpr::One);
    }

    #[test]
    fn try_into_bare_expr_works_on_slot_free_tree() {
        let lifted: EmlClosureExpr =
            EmlExpr::eml(EmlExpr::One, EmlExpr::One).into();
        let back = lifted.try_into_bare_expr();
        assert_eq!(
            back,
            Some(EmlExpr::eml(EmlExpr::One, EmlExpr::One))
        );
    }

    #[test]
    fn try_into_bare_expr_fails_on_slotted_tree() {
        let with_slot = EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
        assert_eq!(with_slot.try_into_bare_expr(), None);
    }

    #[test]
    fn closure_new_rejects_slot_out_of_range() {
        let tree = EmlClosureExpr::slot(5);
        let err = EmlClosure::new(tree, vec![1.0]).unwrap_err();
        assert_eq!(
            err,
            EmlClosureError::SlotOutOfRange {
                slot: 5,
                consts_len: 1,
            }
        );
    }

    #[test]
    fn closure_new_accepts_slot_in_range() {
        let tree = EmlClosureExpr::slot(2);
        let c = EmlClosure::new(tree, vec![1.0, 2.0, 3.0]).unwrap();
        assert_eq!(c.consts, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn closure_new_accepts_slot_free_tree_with_empty_consts() {
        let tree = EmlClosureExpr::eml(EmlClosureExpr::one(), EmlClosureExpr::one());
        let c = EmlClosure::new(tree, Vec::new()).unwrap();
        assert!(c.is_bare());
    }

    #[test]
    fn from_bare_is_always_bare() {
        let c = EmlClosure::from_bare(EmlExpr::eml(EmlExpr::One, EmlExpr::One));
        assert!(c.is_bare());
        assert_eq!(c.consts, Vec::<f64>::new());
    }

    #[test]
    fn validate_slots_matches_new_check() {
        // Hand-construct an invalid closure (skipping `new`'s check)
        // to verify validate_slots catches the same error.
        let invalid = EmlClosure {
            tree: EmlClosureExpr::slot(9),
            consts: vec![1.0],
        };
        let err = invalid.validate_slots().unwrap_err();
        assert!(matches!(err, EmlClosureError::SlotOutOfRange { .. }));
    }

    #[test]
    fn closure_round_trips_through_serde_json() {
        let tree = EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
        let c = EmlClosure::new(tree, vec![std::f64::consts::PI]).unwrap();
        let json = serde_json::to_string(&c).unwrap();
        let back: EmlClosure = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    #[test]
    fn closure_is_bare_false_when_slot_present() {
        let c = EmlClosure {
            tree: EmlClosureExpr::slot(0),
            consts: vec![2.71828],
        };
        assert!(!c.is_bare());
    }

    #[test]
    fn closure_is_bare_false_when_consts_nonempty_but_no_slots() {
        // Carrying unused constants is allowed but not "bare".
        let c = EmlClosure {
            tree: EmlClosureExpr::one(),
            consts: vec![1.0],
        };
        assert!(!c.is_bare());
    }
}
