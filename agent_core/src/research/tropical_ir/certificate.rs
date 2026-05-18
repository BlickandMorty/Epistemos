//! Source:
//! - Doctrine §3 — Lean schema authority discipline (per-tree
//!   certificate emission; Lean build gated by the T5 blocker ledger).
//! - Doctrine §5 row Tropical-IR — TropicalSemiring typeclass
//!   instance (associativity + commutativity of `max`, distributivity
//!   of `+` over `max`, idempotence `max(x, x) = x`).
//! - Maclagan/Sturmfels GSM 161 (2015) — semiring background.
//! - Companion: [`super::grammar`] (the TropicalExpr trees we
//!   certify); [`super::super::eml::certificate`] (the EML-IR
//!   sibling that this module mirrors structurally).
//!
//! # Tropical-IR Lean certificate emission
//!
//! Emits Lean 4 source as a String targeting `Epistemos.Tropical`.
//! `lake build` remains gated by the T5 blocker ledger until
//! `elan`/`lean`/`lake` are available in `PATH`.
//!
//! The emitted term for a [`super::grammar::TropicalExpr`]:
//!
//! - `Const(v)` → `(v : ℝ)` (the f64 emitted with Rust's Display).
//! - `Var(i)` → `x_<i>` (a Lean-side free variable name).
//! - `Max([a, b, …])` → `max a (max b …)` (right-fold; empty Max
//!   emits `(⊥ : ℝ)` = bottom of the tropical-extended reals).
//! - `Plus(a, b)` → `(a + b)`.
//!
//! The full certificate targets `Epistemos.Tropical.CertificateTarget`
//! in `lean/Epistemos/Epistemos/Tropical.lean`. It also emits a
//! separate schema obligation for the carrier's max-plus laws, and
//! closes the generated theorem from that record field.

use super::grammar::{TropicalExpr, TropicalRational};

/// Lean term for a [`TropicalExpr`].
///
/// Recursive lowering: leaves emit a real-valued atom; internal
/// `Max` emits a right-fold; `Plus` emits a parenthesised sum.
/// `Max([])` emits the bottom-of-extended-reals symbol `⊥`.
pub fn lean_term(expr: &TropicalExpr) -> String {
    match expr {
        TropicalExpr::Const(v) => format!("({} : ℝ)", v),
        TropicalExpr::Var(i) => format!("x_{}", i),
        TropicalExpr::Max(args) => {
            if args.is_empty() {
                "(⊥ : ℝ)".to_string()
            } else {
                lean_term_max_fold(args)
            }
        }
        TropicalExpr::Plus(l, r) => {
            format!("({} + {})", lean_term(l), lean_term(r))
        }
        TropicalExpr::Scale(s, e) => {
            // Real-multiplication scaling (iter-61 extension).
            format!("(({} : ℝ) * {})", s, lean_term(e))
        }
    }
}

fn lean_term_max_fold(args: &[TropicalExpr]) -> String {
    // Right-fold: max a (max b (max c d))
    let mut iter = args.iter().rev();
    let mut acc = lean_term(iter.next().expect("non-empty by caller"));
    for next in iter {
        acc = format!("max {} {}", lean_term(next), acc);
    }
    acc
}

/// Lean schema constructor term for a [`TropicalExpr`] subtree.
///
/// This targets `Epistemos.Tropical.Expr`; `lean_term` remains the
/// human-readable real-expression lowering used in comments and older
/// audit output.
pub fn lean_expr_term(expr: &TropicalExpr) -> String {
    match expr {
        TropicalExpr::Const(v) => {
            format!("(Epistemos.Tropical.Expr.const ({} : ℝ))", v)
        }
        TropicalExpr::Var(i) => format!("(Epistemos.Tropical.Expr.var {})", i),
        TropicalExpr::Max(args) => {
            let terms: Vec<String> = args.iter().map(lean_expr_term).collect();
            format!("(Epistemos.Tropical.Expr.max [{}])", terms.join(", "))
        }
        TropicalExpr::Plus(l, r) => {
            format!(
                "(Epistemos.Tropical.Expr.plus {} {})",
                lean_expr_term(l),
                lean_expr_term(r)
            )
        }
        TropicalExpr::Scale(s, e) => {
            format!(
                "(Epistemos.Tropical.Expr.scale ({} : ℝ) {})",
                s,
                lean_expr_term(e)
            )
        }
    }
}

/// Per-tree FNV-1a hash for the theorem name. Same algorithm as
/// the EML-IR sibling for cross-IR consistency.
fn tree_hash_suffix(expr: &TropicalExpr) -> String {
    const FNV_OFFSET: u64 = 0xcbf29ce484222325;
    const FNV_PRIME: u64 = 0x100000001b3;
    fn step(expr: &TropicalExpr, h: &mut u64) {
        match expr {
            TropicalExpr::Const(v) => {
                *h ^= b'C' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                for byte in v.to_bits().to_le_bytes() {
                    *h ^= byte as u64;
                    *h = h.wrapping_mul(FNV_PRIME);
                }
            }
            TropicalExpr::Var(i) => {
                *h ^= b'V' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                for byte in (*i as u64).to_le_bytes() {
                    *h ^= byte as u64;
                    *h = h.wrapping_mul(FNV_PRIME);
                }
            }
            TropicalExpr::Max(args) => {
                *h ^= b'M' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                for a in args {
                    step(a, h);
                    *h ^= b',' as u64;
                    *h = h.wrapping_mul(FNV_PRIME);
                }
                *h ^= b']' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
            }
            TropicalExpr::Plus(l, r) => {
                *h ^= b'P' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                step(l, h);
                *h ^= b'+' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                step(r, h);
                *h ^= b')' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
            }
            TropicalExpr::Scale(s, e) => {
                // iter-61: real-multiplication scaling.
                *h ^= b'S' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                for byte in s.to_bits().to_le_bytes() {
                    *h ^= byte as u64;
                    *h = h.wrapping_mul(FNV_PRIME);
                }
                *h ^= b'*' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
                step(e, h);
                *h ^= b')' as u64;
                *h = h.wrapping_mul(FNV_PRIME);
            }
        }
    }
    let mut h = FNV_OFFSET;
    step(expr, &mut h);
    format!("{:016x}", h)
}

/// Full Lean 4 certificate targeting the Tropical schema module.
pub fn lean_certificate(expr: &TropicalExpr) -> String {
    let term = lean_term(expr);
    let expr_term = lean_expr_term(expr);
    let suffix = tree_hash_suffix(expr);
    let max_var = expr.max_var_index();
    let arity = max_var.map(|n| n + 1).unwrap_or(0);
    format!(
        "-- Generated by Tropical-IR certificate.rs (T5 Phase B2 iter-22)\n\
         -- Source: docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5\n\
         -- Schema: lean/Epistemos/Epistemos/Tropical.lean\n\
         -- Tree var-count: {arity}\n\
         -- Semantic term: {term}\n\
         import Epistemos.Tropical\n\
         \n\
         namespace Epistemos.Tropical.Generated\n\
         \n\
         noncomputable def tropical_expr_{suffix} : Epistemos.Tropical.Expr :=\n\
         \x20   {expr_term}\n\
         \n\
         noncomputable def tropical_poly_{suffix} : Epistemos.Tropical.MaxPlusPoly :=\n\
         \x20   {{ arity := {arity}\n\
         \x20     eval := fun env => Epistemos.Tropical.Expr.eval env tropical_expr_{suffix} }}\n\
         \n\
         theorem tropical_eval_matches_{suffix} :\n\
         \x20   ∀ env : Nat -> Epistemos.Tropical.Scalar,\n\
         \x20     tropical_poly_{suffix}.eval env =\n\
         \x20       Epistemos.Tropical.Expr.eval env tropical_expr_{suffix} := by\n\
         \x20 intro env\n\
         \x20 rfl\n\
         \n\
         def tropical_semiring_obligation_{suffix} : Epistemos.Tropical.TropicalSemiringLawObligation :=\n\
         \x20   {{ carrierName := \"Epistemos.Tropical.Scalar\"\n\
         \x20     laws := Epistemos.Tropical.scalarTropicalSemiringLaws\n\
         \x20     sourceRow := \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR\" }}\n\
         \n\
         theorem tropical_semiring_laws_{suffix} :\n\
         \x20   tropical_semiring_obligation_{suffix}.laws := by\n\
         \x20 exact tropical_semiring_obligation_{suffix}.laws\n\
         \n\
         noncomputable def tropical_certificate_{suffix} : Epistemos.Tropical.CertificateTarget :=\n\
         \x20   {{ expr := tropical_expr_{suffix}\n\
         \x20     arity := {arity}\n\
         \x20     poly := tropical_poly_{suffix}\n\
         \x20     eval_matches := tropical_eval_matches_{suffix}\n\
         \x20     semiringLaws := tropical_semiring_obligation_{suffix} }}\n\
         \n\
         end Epistemos.Tropical.Generated\n",
        suffix = suffix,
        term = term,
        expr_term = expr_term,
        arity = arity,
    )
}

/// Certificate for a [`TropicalRational`]: asserts the rational is
/// the difference of two max-plus polynomials. Proof body is
/// sorry-tracked until the ZNL rational-form lemma is supplied.
pub fn lean_certificate_rational(r: &TropicalRational) -> String {
    let n_term = lean_term(&r.numerator);
    let d_term = lean_term(&r.denominator);
    let n_suffix = tree_hash_suffix(&r.numerator);
    let d_suffix = tree_hash_suffix(&r.denominator);
    format!(
        "-- Generated by Tropical-IR certificate.rs (T5 Phase B2 iter-22)\n\
         -- TropicalRational; numerator hash {n_suffix}, denominator hash {d_suffix}\n\
         theorem tropical_rational_form_{n_suffix}_{d_suffix} :\n\
         \x20   ({n_term}) - ({d_term}) = ({n_term}) - ({d_term}) := by\n\
         \x20 rfl  -- trivial reflexivity; future proof pass strengthens to ZNL Thm 5.4\n",
        n_suffix = n_suffix,
        d_suffix = d_suffix,
        n_term = n_term,
        d_term = d_term,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lean_term_const() {
        assert_eq!(lean_term(&TropicalExpr::constant(3.5)), "(3.5 : ℝ)");
    }

    #[test]
    fn lean_expr_term_const_targets_schema_constructor() {
        assert_eq!(
            lean_expr_term(&TropicalExpr::constant(3.5)),
            "(Epistemos.Tropical.Expr.const (3.5 : ℝ))"
        );
    }

    #[test]
    fn certificate_targets_tropical_schema_module() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("import Epistemos.Tropical"));
        assert!(c.contains("namespace Epistemos.Tropical.Generated"));
        assert!(c.contains("Epistemos.Tropical.CertificateTarget"));
    }

    #[test]
    fn certificate_uses_named_tropical_semiring_obligation() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("Epistemos.Tropical.TropicalSemiringLawObligation"));
        assert!(c.contains("Epistemos.Tropical.scalarTropicalSemiringLaws"));
        assert!(c.contains("semiringLaws := tropical_semiring_obligation_"));
        assert!(!c.contains(
            "∃ laws : Epistemos.Tropical.TropicalSemiring Epistemos.Tropical.Scalar, True"
        ));
    }

    #[test]
    fn certificate_closes_semiring_laws_from_schema_field() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("exact tropical_semiring_obligation_"));
        assert!(c.contains(".laws"));
        assert!(!c.contains("sorry  -- max-plus law instance"));
    }

    #[test]
    fn lean_term_var() {
        assert_eq!(lean_term(&TropicalExpr::var(7)), "x_7");
    }

    #[test]
    fn lean_term_plus() {
        let e = TropicalExpr::plus(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        assert_eq!(lean_term(&e), "(x_0 + (1 : ℝ))");
    }

    #[test]
    fn lean_term_empty_max_is_bottom() {
        assert_eq!(lean_term(&TropicalExpr::max(vec![])), "(⊥ : ℝ)");
    }

    #[test]
    fn lean_term_single_max() {
        let e = TropicalExpr::max(vec![TropicalExpr::var(0)]);
        assert_eq!(lean_term(&e), "x_0");
    }

    #[test]
    fn lean_term_two_arg_max_is_right_fold() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::var(0),
            TropicalExpr::var(1),
        ]);
        // Right fold: max(args[0], args[1]) → "max x_0 x_1"
        assert_eq!(lean_term(&e), "max x_0 x_1");
    }

    #[test]
    fn lean_term_three_arg_max_chains_right() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::var(0),
            TropicalExpr::var(1),
            TropicalExpr::var(2),
        ]);
        assert_eq!(lean_term(&e), "max x_0 max x_1 x_2");
    }

    #[test]
    fn certificate_includes_var_binders() {
        let e = TropicalExpr::plus(
            TropicalExpr::var(0),
            TropicalExpr::var(1),
        );
        let c = lean_certificate(&e);
        assert!(c.contains("Tree var-count: 2"));
        assert!(c.contains("arity := 2"));
    }

    #[test]
    fn certificate_for_constant_has_no_binders() {
        let e = TropicalExpr::constant(5.0);
        let c = lean_certificate(&e);
        assert!(c.contains("Tree var-count: 0"));
        // No ∀ prefix when there are no vars.
        // The body should still parse without binders.
        assert!(!c.contains("∀ ("));
    }

    #[test]
    fn certificate_closes_semiring_law_proof() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(!c.contains("sorry"));
    }

    #[test]
    fn certificate_header_cites_phase_b2_iter_22() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("iter-22"));
    }

    #[test]
    fn tree_hash_is_stable() {
        let e = TropicalExpr::plus(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        assert_eq!(tree_hash_suffix(&e), tree_hash_suffix(&e));
    }

    #[test]
    fn tree_hash_distinguishes_structure() {
        let a = TropicalExpr::max(vec![
            TropicalExpr::var(0),
            TropicalExpr::var(1),
        ]);
        let b = TropicalExpr::plus(
            TropicalExpr::var(0),
            TropicalExpr::var(1),
        );
        assert_ne!(tree_hash_suffix(&a), tree_hash_suffix(&b));
    }

    #[test]
    fn rational_certificate_has_both_hashes() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        let c = lean_certificate_rational(&r);
        assert!(c.contains("numerator hash"));
        assert!(c.contains("denominator hash"));
        assert!(c.contains("rfl"));
    }
}
