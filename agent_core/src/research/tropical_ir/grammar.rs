//! Source:
//! - Zhang, Naitzat, Lim, "Tropical Geometry of Deep Neural Networks",
//!   arXiv:1805.07091 (ICML 2018). Theorem 5.4: every feedforward
//!   ReLU network computes a tropical rational map; the typed AST
//!   here is the syntactic carrier of that result.
//! - Charisopoulos, Maragos, "A Tropical Approach to Neural Networks
//!   with Piecewise Linear Activations", arXiv:1805.08749 §3 — the
//!   explicit ReLU-to-(max,+) compilation that iter-19+ implements.
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §2.2 + §4.2 — Tropical-IR primitive signature + AST shape.
//! - Phase B1 close-out `docs/audits/PHASE_B1_CLOSEOUT_2026_05_17.md`
//!   §7 — iter-18 plan entry.
//!
//! # Tropical-IR typed AST
//!
//! The (max, +) tropical semiring is defined by:
//!
//! ```text
//! a ⊕ b = max(a, b)       (tropical addition / aggregation)
//! a ⊗ b = a + b           (tropical multiplication / composition)
//! ```
//!
//! This module ships the typed AST that captures arbitrary
//! tropical-rational expressions. Iter-19 adds the evaluator;
//! iter-20+ adds the ReLU-network compilation per
//! Charisopoulos/Maragos §3.
//!
//! ## Grammar
//!
//! ```text
//! TropicalExpr ::= Const(f64)
//!               |  Var(usize)         -- input variable index
//!               |  Max([TropicalExpr])
//!               |  Plus(TropicalExpr, TropicalExpr)
//! ```
//!
//! A `TropicalRational { numerator, denominator }` is a pair of
//! `TropicalExpr` trees representing the formal "ratio" `p ⊘ q`,
//! where `⊘` lifts to standard subtraction in the underlying ℝ
//! (because tropical multiplication is +, the tropical inverse is
//! −; tropical division is standard subtraction). Per
//! Zhang/Naitzat/Lim Thm 5.4 this `TropicalRational` form covers
//! the image of every rational-weight feedforward ReLU network.
//!
//! ## Coexistence with the substrate-floor `super::super::tropical`
//!
//! The pre-existing `agent_core/src/research/tropical.rs` (594 LOC,
//! Wave J B.6.15) defines `TropicalMonomial` + `TropicalPolynomial`
//! — a simpler form than this AST. Both shapes are useful:
//!
//! - `TropicalPolynomial` (substrate): explicit Σ a_i x_i + b
//!   affine summands max-folded; specialized for the
//!   "polynomial-as-max-of-affine" intermediate representation.
//! - `TropicalExpr` (this module): the general-purpose typed AST
//!   that the Phase B2 compilation pipeline targets. Reduces to
//!   `TropicalPolynomial` only when the expression has the
//!   max-of-affine shape.
//!
//! Iter-19's evaluator lowers `TropicalExpr` → f64 directly,
//! independent of the substrate `TropicalPolynomial::evaluate`.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Tropical-semiring expression AST.
///
/// Construction-site invariants the grammar carries:
/// - `Max([])` (empty max) is permitted at the type level — by
///   convention it evaluates to negative infinity (the additive
///   identity of the tropical semiring). [`evaluate`] (iter-19)
///   handles it.
/// - `Var(idx)` references variable index `idx` in an externally-
///   supplied valuation. [`max_var_index`] is the sanity-check.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum TropicalExpr {
    Const(f64),
    Var(usize),
    Max(Vec<TropicalExpr>),
    Plus(Box<TropicalExpr>, Box<TropicalExpr>),
    /// **Scale(s, e) (iter-61 Phase C extension).** Real-number
    /// scalar multiplication: `Scale(s, e)` evaluates to `s * eval(e)`.
    ///
    /// Strictly speaking this is OUTSIDE the (max, +) tropical semiring
    /// — pure tropical multiplication is `+` (Plus). Scale is the
    /// "embedded real-linear weighting" primitive that lets the
    /// Tropical-IR AST capture ReLU layers with non-binary weights
    /// (Zhang/Naitzat/Lim Thm 5.4 for rational weights). The compile
    /// path emits Scale to encode `w * x`; the evaluator does real
    /// multiplication.
    Scale(f64, Box<TropicalExpr>),
}

impl TropicalExpr {
    /// Constant leaf.
    pub fn constant(v: f64) -> Self {
        TropicalExpr::Const(v)
    }

    /// Variable leaf referencing valuation slot `idx`.
    pub fn var(idx: usize) -> Self {
        TropicalExpr::Var(idx)
    }

    /// `Max` (tropical addition / aggregation) over a vector of
    /// summands.
    pub fn max(args: Vec<TropicalExpr>) -> Self {
        TropicalExpr::Max(args)
    }

    /// `Plus` (tropical multiplication / composition).
    pub fn plus(a: TropicalExpr, b: TropicalExpr) -> Self {
        TropicalExpr::Plus(Box::new(a), Box::new(b))
    }

    /// `Scale(s, e)` — real-number scalar multiplication
    /// (iter-61 Phase C extension).
    pub fn scale(s: f64, e: TropicalExpr) -> Self {
        TropicalExpr::Scale(s, Box::new(e))
    }

    /// Tree depth: leaves are depth 0; `Max([])` is depth 0;
    /// `Max([…])` is `1 + max(child_depths)`; `Plus(a, b)` is
    /// `1 + max(a.depth(), b.depth())`.
    pub fn depth(&self) -> usize {
        match self {
            TropicalExpr::Const(_) | TropicalExpr::Var(_) => 0,
            TropicalExpr::Max(args) => {
                args.iter().map(|a| a.depth()).max().map(|d| d + 1).unwrap_or(0)
            }
            TropicalExpr::Plus(l, r) => 1 + l.depth().max(r.depth()),
            TropicalExpr::Scale(_, e) => 1 + e.depth(),
        }
    }

    /// Node count (every constructor and leaf counts as 1).
    pub fn size(&self) -> usize {
        match self {
            TropicalExpr::Const(_) | TropicalExpr::Var(_) => 1,
            TropicalExpr::Max(args) => 1 + args.iter().map(|a| a.size()).sum::<usize>(),
            TropicalExpr::Plus(l, r) => 1 + l.size() + r.size(),
            TropicalExpr::Scale(_, e) => 1 + e.size(),
        }
    }

    /// `true` iff no `Var` nodes appear in the tree.
    pub fn is_closed(&self) -> bool {
        match self {
            TropicalExpr::Const(_) => true,
            TropicalExpr::Var(_) => false,
            TropicalExpr::Max(args) => args.iter().all(|a| a.is_closed()),
            TropicalExpr::Plus(l, r) => l.is_closed() && r.is_closed(),
            TropicalExpr::Scale(_, e) => e.is_closed(),
        }
    }

    /// Highest variable index appearing in the tree, or `None` if
    /// the tree is closed (no `Var` nodes). Used to validate that
    /// a valuation vector passed to `evaluate` is wide enough.
    pub fn max_var_index(&self) -> Option<usize> {
        match self {
            TropicalExpr::Const(_) => None,
            TropicalExpr::Var(i) => Some(*i),
            TropicalExpr::Max(args) => {
                args.iter().filter_map(|a| a.max_var_index()).max()
            }
            TropicalExpr::Plus(l, r) => match (l.max_var_index(), r.max_var_index()) {
                (None, None) => None,
                (Some(a), None) | (None, Some(a)) => Some(a),
                (Some(a), Some(b)) => Some(a.max(b)),
            },
            TropicalExpr::Scale(_, e) => e.max_var_index(),
        }
    }
}

impl fmt::Display for TropicalExpr {
    /// Human-readable form for debugging:
    /// - `Const(v)` → `"v"` (Rust's f64 Display).
    /// - `Var(i)` → `"x_i"`.
    /// - `Max([a, b, …])` → `"max(a, b, …)"` (empty Max → `"max()"`).
    /// - `Plus(a, b)` → `"(a + b)"`.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TropicalExpr::Const(v) => write!(f, "{}", v),
            TropicalExpr::Var(i) => write!(f, "x_{}", i),
            TropicalExpr::Max(args) => {
                write!(f, "max(")?;
                for (i, a) in args.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{}", a)?;
                }
                write!(f, ")")
            }
            TropicalExpr::Plus(l, r) => write!(f, "({} + {})", l, r),
            TropicalExpr::Scale(s, e) => write!(f, "({} * {})", s, e),
        }
    }
}

/// Tropical rational expression: `numerator ⊘ denominator` in the
/// (max, +) semiring. Per Zhang/Naitzat/Lim Thm 5.4, every
/// feedforward ReLU network's input-output map is representable
/// as a `TropicalRational`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TropicalRational {
    pub numerator: TropicalExpr,
    pub denominator: TropicalExpr,
}

impl fmt::Display for TropicalRational {
    /// `"(numerator) / (denominator)"`.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({}) / ({})", self.numerator, self.denominator)
    }
}

impl TropicalRational {
    /// Construct a rational.
    pub fn new(numerator: TropicalExpr, denominator: TropicalExpr) -> Self {
        TropicalRational {
            numerator,
            denominator,
        }
    }

    /// `true` iff both numerator and denominator are
    /// variable-free.
    pub fn is_closed(&self) -> bool {
        self.numerator.is_closed() && self.denominator.is_closed()
    }

    /// Highest variable index appearing anywhere in the rational.
    pub fn max_var_index(&self) -> Option<usize> {
        match (
            self.numerator.max_var_index(),
            self.denominator.max_var_index(),
        ) {
            (None, None) => None,
            (Some(a), None) | (None, Some(a)) => Some(a),
            (Some(a), Some(b)) => Some(a.max(b)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn const_leaf_depth_is_zero() {
        assert_eq!(TropicalExpr::constant(3.5).depth(), 0);
    }

    #[test]
    fn var_leaf_depth_is_zero() {
        assert_eq!(TropicalExpr::var(7).depth(), 0);
    }

    #[test]
    fn empty_max_has_depth_zero() {
        assert_eq!(TropicalExpr::max(vec![]).depth(), 0);
    }

    #[test]
    fn nonempty_max_adds_one_to_max_child_depth() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(2.0)),
        ]);
        // Max([Const, Plus(Var, Const)]) → 1 + max(0, 1) = 2
        assert_eq!(e.depth(), 2);
    }

    #[test]
    fn plus_adds_one_to_max_subtree() {
        let e = TropicalExpr::plus(
            TropicalExpr::constant(1.0),
            TropicalExpr::max(vec![TropicalExpr::var(0), TropicalExpr::var(1)]),
        );
        // Plus(Const, Max([Var, Var])) → 1 + max(0, 1) = 2
        assert_eq!(e.depth(), 2);
    }

    #[test]
    fn size_counts_every_node_once() {
        // Plus(Const, Max([Var, Const])) → 1 + 1 + (1 + 1 + 1) = 5
        let e = TropicalExpr::plus(
            TropicalExpr::constant(0.0),
            TropicalExpr::max(vec![
                TropicalExpr::var(0),
                TropicalExpr::constant(1.0),
            ]),
        );
        assert_eq!(e.size(), 5);
    }

    #[test]
    fn const_only_tree_is_closed() {
        let e = TropicalExpr::plus(
            TropicalExpr::constant(1.0),
            TropicalExpr::max(vec![TropicalExpr::constant(2.0)]),
        );
        assert!(e.is_closed());
    }

    #[test]
    fn var_anywhere_makes_tree_open() {
        let e = TropicalExpr::plus(
            TropicalExpr::constant(1.0),
            TropicalExpr::max(vec![TropicalExpr::var(3)]),
        );
        assert!(!e.is_closed());
    }

    #[test]
    fn max_var_index_returns_largest_var() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::var(0),
            TropicalExpr::plus(TropicalExpr::var(2), TropicalExpr::var(5)),
            TropicalExpr::var(1),
        ]);
        assert_eq!(e.max_var_index(), Some(5));
    }

    #[test]
    fn max_var_index_none_for_closed_tree() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::constant(2.0),
        ]);
        assert_eq!(e.max_var_index(), None);
    }

    #[test]
    fn rational_new_carries_both_subtrees() {
        let n = TropicalExpr::constant(3.0);
        let d = TropicalExpr::var(0);
        let r = TropicalRational::new(n.clone(), d.clone());
        assert_eq!(r.numerator, n);
        assert_eq!(r.denominator, d);
    }

    #[test]
    fn rational_is_closed_when_both_sides_closed() {
        let r = TropicalRational::new(
            TropicalExpr::constant(1.0),
            TropicalExpr::max(vec![TropicalExpr::constant(2.0)]),
        );
        assert!(r.is_closed());
    }

    #[test]
    fn rational_open_when_either_side_open() {
        let r = TropicalRational::new(
            TropicalExpr::constant(1.0),
            TropicalExpr::var(0),
        );
        assert!(!r.is_closed());
    }

    #[test]
    fn rational_max_var_index_takes_max_of_both() {
        let r = TropicalRational::new(
            TropicalExpr::var(3),
            TropicalExpr::plus(TropicalExpr::var(7), TropicalExpr::constant(1.0)),
        );
        assert_eq!(r.max_var_index(), Some(7));
    }

    #[test]
    fn expr_round_trips_through_serde_json() {
        let e = TropicalExpr::plus(
            TropicalExpr::max(vec![
                TropicalExpr::constant(1.0),
                TropicalExpr::var(0),
            ]),
            TropicalExpr::constant(-2.5),
        );
        let json = serde_json::to_string(&e).unwrap();
        let back: TropicalExpr = serde_json::from_str(&json).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn rational_round_trips_through_serde_json() {
        let r = TropicalRational::new(
            TropicalExpr::constant(1.0),
            TropicalExpr::var(0),
        );
        let json = serde_json::to_string(&r).unwrap();
        let back: TropicalRational = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    // ── Display impl (iter-51) ─────────────────────────────────────

    #[test]
    fn display_const_uses_f64() {
        assert_eq!(format!("{}", TropicalExpr::constant(3.5)), "3.5");
    }

    #[test]
    fn display_var_uses_x_i_form() {
        assert_eq!(format!("{}", TropicalExpr::var(7)), "x_7");
    }

    #[test]
    fn display_plus_parenthesizes() {
        let e = TropicalExpr::plus(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        assert_eq!(format!("{}", e), "(x_0 + 1)");
    }

    #[test]
    fn display_empty_max() {
        let e = TropicalExpr::max(vec![]);
        assert_eq!(format!("{}", e), "max()");
    }

    #[test]
    fn display_two_arg_max() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::var(0),
            TropicalExpr::var(1),
        ]);
        assert_eq!(format!("{}", e), "max(x_0, x_1)");
    }

    #[test]
    fn display_nested() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::plus(
                TropicalExpr::var(0),
                TropicalExpr::constant(1.0),
            ),
            TropicalExpr::constant(2.0),
        ]);
        assert_eq!(format!("{}", e), "max((x_0 + 1), 2)");
    }

    #[test]
    fn display_tropical_rational() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        assert_eq!(format!("{}", r), "(x_0) / (1)");
    }

    // ── Scale variant (iter-61 Phase C extension) ─────────────────

    #[test]
    fn scale_leaf_depth_is_one() {
        // Scale(0.5, Var(0)) is one level deeper than Var(0).
        let e = TropicalExpr::scale(0.5, TropicalExpr::var(0));
        assert_eq!(e.depth(), 1);
    }

    #[test]
    fn scale_size_counts_the_scale_node() {
        let e = TropicalExpr::scale(2.0, TropicalExpr::var(0));
        assert_eq!(e.size(), 2); // Scale + Var
    }

    #[test]
    fn scale_is_open_when_inner_has_var() {
        let e = TropicalExpr::scale(2.0, TropicalExpr::var(0));
        assert!(!e.is_closed());
    }

    #[test]
    fn scale_is_closed_when_inner_is_constant() {
        let e = TropicalExpr::scale(2.0, TropicalExpr::constant(1.0));
        assert!(e.is_closed());
    }

    #[test]
    fn scale_max_var_index_inherits_from_inner() {
        let e = TropicalExpr::scale(3.0, TropicalExpr::var(7));
        assert_eq!(e.max_var_index(), Some(7));
    }

    #[test]
    fn display_scale() {
        let e = TropicalExpr::scale(2.5, TropicalExpr::var(0));
        assert_eq!(format!("{}", e), "(2.5 * x_0)");
    }

    #[test]
    fn scale_round_trips_through_serde_json() {
        let e = TropicalExpr::scale(
            1.5,
            TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(2.0)),
        );
        let json = serde_json::to_string(&e).unwrap();
        let back: TropicalExpr = serde_json::from_str(&json).unwrap();
        assert_eq!(e, back);
    }
}
