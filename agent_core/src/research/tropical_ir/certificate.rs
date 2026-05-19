//! Source:
//! - Doctrine §3 — Lean schema authority discipline (per-tree
//!   certificate emission; explicit-PATH Lean build recorded in the
//!   T5 blocker ledger).
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
//! The committed schema module built with explicit `~/.elan/bin`
//! PATH, and obligations were sharpened through iter-696 with zero
//! sorries in committed Lean sources.
//! Generated semiring-law proof bodies expose schema witness
//! binders; future rational-form strengthening remains tracked
//! separately.
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
        "-- Generated by Tropical-IR certificate.rs (T5 Phase B2 iter-22; Lean-first iter-604)\n\
         -- Source: docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5\n\
         -- Schema: lean/Epistemos/Epistemos/Tropical.lean\n\
         -- Schema module built with explicit ~/.elan/bin PATH; obligations sharpened through iter-696.\n\
         -- Generated semiring law proof exposes schema witness.\n\
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
         theorem tropical_semiring_laws_{suffix}\n\
         \x20   (semiringLawWitness : tropical_semiring_obligation_{suffix}.laws) :\n\
         \x20   tropical_semiring_obligation_{suffix}.laws := by\n\
         \x20 exact semiringLawWitness\n\
         \n\
         noncomputable def tropical_certificate_{suffix} : Epistemos.Tropical.CertificateTarget :=\n\
         \x20   {{ expr := tropical_expr_{suffix}\n\
         \x20     arity := {arity}\n\
         \x20     poly := tropical_poly_{suffix}\n\
         \x20     eval_matches := tropical_eval_matches_{suffix}\n\
         \x20     semiringLaws := tropical_semiring_obligation_{suffix} }}\n\
         \n\
         theorem tropical_certificate_eval_matches_{suffix} :\n\
         \x20   ∀ env : Nat -> Epistemos.Tropical.Scalar,\n\
         \x20     tropical_certificate_{suffix}.poly.eval env =\n\
         \x20       Epistemos.Tropical.Expr.eval env tropical_certificate_{suffix}.expr := by\n\
         \x20 intro env\n\
         \x20 exact Epistemos.Tropical.CertificateTarget.evalMatches tropical_certificate_{suffix} env\n\
         \n\
         theorem tropical_certificate_semiring_laws_{suffix} :\n\
         \x20   tropical_certificate_{suffix}.semiringLaws = tropical_semiring_obligation_{suffix} := by\n\
         \x20 exact Epistemos.Tropical.CertificateTarget.semiringLawsMatch\n\
         \x20   tropical_certificate_{suffix}\n\
         \x20   tropical_semiring_obligation_{suffix}\n\
         \x20   rfl\n\
         \n\
         theorem tropical_certificate_semiring_law_witness_{suffix}\n\
         \x20   (semiringLawWitness : tropical_certificate_{suffix}.semiringLaws.laws) :\n\
         \x20   tropical_certificate_{suffix}.semiringLaws.laws := by\n\
         \x20 exact Epistemos.Tropical.CertificateTarget.semiringLawsCarry\n\
         \x20   tropical_certificate_{suffix} semiringLawWitness\n\
         \n\
         end Epistemos.Tropical.Generated\n",
        suffix = suffix,
        term = term,
        expr_term = expr_term,
        arity = arity,
    )
}

/// Certificate for a [`TropicalRational`]: targets the Lean
/// `RationalForm` schema row and carries a named representation
/// obligation for later ZNL rational-form strengthening.
pub fn lean_certificate_rational(r: &TropicalRational) -> String {
    let n_expr = lean_expr_term(&r.numerator);
    let d_expr = lean_expr_term(&r.denominator);
    let n_suffix = tree_hash_suffix(&r.numerator);
    let d_suffix = tree_hash_suffix(&r.denominator);
    let suffix = format!("{n_suffix}_{d_suffix}");
    format!(
        "-- Generated by Tropical-IR certificate.rs (T5 Phase B2 iter-22; Lean-first iter-614)\n\
         -- Source: docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5\n\
         -- Schema: lean/Epistemos/Epistemos/Tropical.lean\n\
         -- TropicalRational schema: numerator hash {n_suffix}, denominator hash {d_suffix}\n\
         -- Rational hash obligations carried through Lean schema fields as of T5 iter-933.\n\
         import Epistemos.Tropical\n\
         \n\
         namespace Epistemos.Tropical.Generated\n\
         \n\
         noncomputable def tropical_rational_num_{suffix} : Epistemos.Tropical.Expr :=\n\
         \x20   {n_expr}\n\
         \n\
         noncomputable def tropical_rational_den_{suffix} : Epistemos.Tropical.Expr :=\n\
         \x20   {d_expr}\n\
         \n\
         noncomputable def tropical_rational_form_{suffix} : Epistemos.Tropical.RationalForm :=\n\
         \x20   {{ numerator := tropical_rational_num_{suffix}\n\
         \x20     denominator := tropical_rational_den_{suffix} }}\n\
         \n\
         noncomputable def tropical_rational_obligation_{suffix} :\n\
         \x20   Epistemos.Tropical.RationalRepresentationObligation tropical_rational_form_{suffix} :=\n\
         \x20   -- sourceRow := \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\"\n\
         \x20   Epistemos.Tropical.RationalRepresentationObligation.refl\n\
         \x20     tropical_rational_form_{suffix}\n\
         \x20     \"{n_suffix}\"\n\
         \x20     \"{d_suffix}\"\n\
         \x20     \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\"\n\
         \n\
         theorem tropical_rational_numerator_shape_{suffix}\n\
         \x20   (numeratorShapeWitness : tropical_rational_obligation_{suffix}.numeratorShape) :\n\
         \x20   tropical_rational_form_{suffix}.numerator = tropical_rational_form_{suffix}.numerator := by\n\
         \x20 exact numeratorShapeWitness\n\
         \n\
         theorem tropical_rational_denominator_shape_{suffix}\n\
         \x20   (denominatorShapeWitness : tropical_rational_obligation_{suffix}.denominatorShape) :\n\
         \x20   tropical_rational_form_{suffix}.denominator = tropical_rational_form_{suffix}.denominator := by\n\
         \x20 exact denominatorShapeWitness\n\
         \n\
         theorem tropical_rational_obligation_hash_fields_{suffix} :\n\
         \x20   tropical_rational_obligation_{suffix}.numeratorHash = \"{n_suffix}\" ∧\n\
         \x20     tropical_rational_obligation_{suffix}.denominatorHash = \"{d_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalRepresentationObligation.hashFieldsMatch\n\
         \x20   tropical_rational_obligation_{suffix}\n\
         \x20   \"{n_suffix}\"\n\
         \x20   \"{d_suffix}\"\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_obligation_numerator_hash_{suffix} :\n\
         \x20   tropical_rational_obligation_{suffix}.numeratorHash = \"{n_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalRepresentationObligation.numeratorHashMatches\n\
         \x20   tropical_rational_obligation_{suffix}\n\
         \x20   \"{n_suffix}\"\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_obligation_denominator_hash_{suffix} :\n\
         \x20   tropical_rational_obligation_{suffix}.denominatorHash = \"{d_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalRepresentationObligation.denominatorHashMatches\n\
         \x20   tropical_rational_obligation_{suffix}\n\
         \x20   \"{d_suffix}\"\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_obligation_source_row_{suffix} :\n\
         \x20   tropical_rational_obligation_{suffix}.sourceRow =\n\
         \x20     \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\" := by\n\
         \x20 exact Epistemos.Tropical.RationalRepresentationObligation.sourceRowMatches\n\
         \x20   tropical_rational_obligation_{suffix}\n\
         \x20   \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\"\n\
         \x20   rfl\n\
         \n\
         noncomputable def tropical_rational_certificate_{suffix} : Epistemos.Tropical.RationalCertificateTarget :=\n\
         \x20   {{ rational := tropical_rational_form_{suffix}\n\
         \x20     numeratorHash := \"{n_suffix}\"\n\
         \x20     denominatorHash := \"{d_suffix}\"\n\
         \x20     representation := tropical_rational_obligation_{suffix} }}\n\
         \n\
         theorem tropical_rational_certificate_hash_fields_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.numeratorHash = \"{n_suffix}\" ∧\n\
         \x20     tropical_rational_certificate_{suffix}.denominatorHash = \"{d_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.hashFieldsMatch\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   \"{n_suffix}\" \"{d_suffix}\" rfl rfl\n\
         \n\
         theorem tropical_rational_certificate_numerator_hash_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.numeratorHash = \"{n_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.numeratorHashMatches\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   \"{n_suffix}\"\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_certificate_denominator_hash_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.denominatorHash = \"{d_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.denominatorHashMatches\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   \"{d_suffix}\"\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_certificate_representation_hash_fields_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.representation.numeratorHash =\n\
         \x20       tropical_rational_certificate_{suffix}.numeratorHash ∧\n\
         \x20     tropical_rational_certificate_{suffix}.representation.denominatorHash =\n\
         \x20       tropical_rational_certificate_{suffix}.denominatorHash := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.representationHashFieldsMatch\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_certificate_representation_hash_values_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.representation.numeratorHash = \"{n_suffix}\" ∧\n\
         \x20     tropical_rational_certificate_{suffix}.representation.denominatorHash = \"{d_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.representationHashFieldsCarry\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   \"{n_suffix}\"\n\
         \x20   \"{d_suffix}\"\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_certificate_source_row_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.representation.sourceRow =\n\
         \x20     \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\" := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.sourceRowMatches\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\"\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_certificate_target_hashes_from_representation_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.numeratorHash = \"{n_suffix}\" ∧\n\
         \x20     tropical_rational_certificate_{suffix}.denominatorHash = \"{d_suffix}\" := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.targetHashFieldsFromRepresentation\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   \"{n_suffix}\"\n\
         \x20   \"{d_suffix}\"\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \x20   rfl\n\
         \n\
         theorem tropical_rational_certificate_representation_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.representation = tropical_rational_obligation_{suffix} := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.representationMatches\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \x20   tropical_rational_obligation_{suffix}\n\
         \x20   rfl\n\
         \n\
         noncomputable def tropical_rational_certificate_representation_obligation_{suffix} :\n\
         \x20   Epistemos.Tropical.RationalRepresentationObligation\n\
         \x20     tropical_rational_certificate_{suffix}.rational := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.representationCarries\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \n\
         theorem tropical_rational_certificate_numerator_shape_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.rational.numerator =\n\
         \x20     tropical_rational_certificate_{suffix}.rational.numerator := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.numeratorShape\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \n\
         theorem tropical_rational_certificate_denominator_shape_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.rational.denominator =\n\
         \x20     tropical_rational_certificate_{suffix}.rational.denominator := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.denominatorShape\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \n\
         theorem tropical_rational_certificate_shapes_{suffix} :\n\
         \x20   tropical_rational_certificate_{suffix}.rational.numerator = tropical_rational_certificate_{suffix}.rational.numerator ∧\n\
         \x20     tropical_rational_certificate_{suffix}.rational.denominator = tropical_rational_certificate_{suffix}.rational.denominator := by\n\
         \x20 exact Epistemos.Tropical.RationalCertificateTarget.representationShapes\n\
         \x20   tropical_rational_certificate_{suffix}\n\
         \n\
         end Epistemos.Tropical.Generated\n",
        n_suffix = n_suffix,
        d_suffix = d_suffix,
        suffix = suffix,
        n_expr = n_expr,
        d_expr = d_expr,
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
        assert!(c.contains("(semiringLawWitness :"));
        assert!(c.contains("exact semiringLawWitness"));
        assert!(!c.contains("exact tropical_semiring_obligation_"));
        assert!(c.contains(".laws"));
        assert!(!c.contains("sorry  -- max-plus law instance"));
    }

    #[test]
    fn certificate_projects_target_semiring_obligation() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("theorem tropical_certificate_semiring_laws_"));
        assert!(c.contains(".semiringLaws = tropical_semiring_obligation_"));
        assert!(c.contains("Epistemos.Tropical.CertificateTarget.semiringLawsMatch"));
    }

    #[test]
    fn certificate_projects_target_semiring_law_witness() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("theorem tropical_certificate_semiring_law_witness_"));
        assert!(c.contains("exact Epistemos.Tropical.CertificateTarget.semiringLawsCarry"));
        assert!(c.contains("tropical_certificate_"));
    }

    #[test]
    fn certificate_projects_target_eval_match() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains("theorem tropical_certificate_eval_matches_"));
        assert!(c.contains("Epistemos.Tropical.CertificateTarget.evalMatches"));
        assert!(c.contains("tropical_certificate_"));
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
    fn certificate_header_tracks_schema_build_and_closed_semiring_obligation() {
        let c = lean_certificate(&TropicalExpr::constant(0.0));
        assert!(c.contains(
            "Schema module built with explicit ~/.elan/bin PATH; obligations sharpened through iter-696"
        ));
        assert!(c.contains("Generated semiring law proof exposes schema witness"));
        assert!(!c.contains("lake build remains gated"));
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
        assert!(c.contains(
            "Rational hash obligations carried through Lean schema fields as of T5 iter-933"
        ));
        assert!(c.contains("theorem tropical_rational_certificate_hash_fields_"));
        assert!(c.contains("Epistemos.Tropical.RationalCertificateTarget.hashFieldsMatch"));
        assert!(c.contains("theorem tropical_rational_certificate_numerator_hash_"));
        assert!(c.contains("Epistemos.Tropical.RationalCertificateTarget.numeratorHashMatches"));
        assert!(c.contains("theorem tropical_rational_certificate_denominator_hash_"));
        assert!(c.contains(
            "Epistemos.Tropical.RationalCertificateTarget.denominatorHashMatches"
        ));
    }

    #[test]
    fn rational_certificate_targets_tropical_schema_module() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        let c = lean_certificate_rational(&r);
        assert!(c.contains("import Epistemos.Tropical"));
        assert!(c.contains("Epistemos.Tropical.RationalForm"));
        assert!(c.contains("Epistemos.Tropical.RationalCertificateTarget"));
        assert!(c.contains("Epistemos.Tropical.Expr.var 0"));
        assert!(!c.contains("-- TropicalRational;"));
    }

    #[test]
    fn rational_certificate_uses_named_representation_obligation() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        let c = lean_certificate_rational(&r);
        assert!(c.contains("Epistemos.Tropical.RationalRepresentationObligation"));
        assert!(c.contains("def tropical_rational_obligation_"));
        assert!(c.contains("Epistemos.Tropical.RationalRepresentationObligation.refl"));
        assert!(c.contains("sourceRow := \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §5 Tropical-IR rational-form\""));
        assert!(c.contains("representation := tropical_rational_obligation_"));
        assert!(c.contains(".numeratorHash"));
        assert!(c.contains(".denominatorHash"));
        assert!(c.contains("theorem tropical_rational_obligation_hash_fields_"));
        assert!(c.contains("Epistemos.Tropical.RationalRepresentationObligation.hashFieldsMatch"));
        assert!(c.contains("theorem tropical_rational_obligation_numerator_hash_"));
        assert!(c.contains(
            "Epistemos.Tropical.RationalRepresentationObligation.numeratorHashMatches"
        ));
        assert!(c.contains("theorem tropical_rational_obligation_denominator_hash_"));
        assert!(c.contains(
            "Epistemos.Tropical.RationalRepresentationObligation.denominatorHashMatches"
        ));
        assert!(c.contains("theorem tropical_rational_obligation_source_row_"));
        assert!(c.contains(
            "Epistemos.Tropical.RationalRepresentationObligation.sourceRowMatches"
        ));
        assert!(c.contains("(numeratorShapeWitness :"));
        assert!(c.contains("exact numeratorShapeWitness"));
        assert!(c.contains("(denominatorShapeWitness :"));
        assert!(c.contains("exact denominatorShapeWitness"));
        assert!(!c.contains("exact tropical_rational_obligation_"));
        assert!(!c.contains("numeratorShape := rfl"));
        assert!(!c.contains("form_matches := tropical_rational_form_matches_"));
    }

    #[test]
    fn rational_certificate_projects_representation_target() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        let c = lean_certificate_rational(&r);
        assert!(c.contains("theorem tropical_rational_certificate_representation_"));
        assert!(c.contains(".representation = tropical_rational_obligation_"));
        assert!(c.contains("Epistemos.Tropical.RationalCertificateTarget.representationMatches"));
        assert!(c.contains("theorem tropical_rational_certificate_representation_hash_fields_"));
        assert!(c.contains(
            "Epistemos.Tropical.RationalCertificateTarget.representationHashFieldsMatch"
        ));
        assert!(c.contains("theorem tropical_rational_certificate_representation_hash_values_"));
        assert!(c.contains(
            "Epistemos.Tropical.RationalCertificateTarget.representationHashFieldsCarry"
        ));
        assert!(c.contains("theorem tropical_rational_certificate_source_row_"));
        assert!(c.contains("Epistemos.Tropical.RationalCertificateTarget.sourceRowMatches"));
        assert!(c.contains(
            "theorem tropical_rational_certificate_target_hashes_from_representation_"
        ));
        assert!(c.contains(
            "Epistemos.Tropical.RationalCertificateTarget.targetHashFieldsFromRepresentation"
        ));
    }

    #[test]
    fn rational_certificate_carries_representation_obligation_target() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        let c = lean_certificate_rational(&r);
        assert!(c.contains("def tropical_rational_certificate_representation_obligation_"));
        assert!(c.contains(
            "exact Epistemos.Tropical.RationalCertificateTarget.representationCarries"
        ));
        assert!(c.contains("tropical_rational_certificate_"));
    }

    #[test]
    fn rational_certificate_carries_target_shapes() {
        let r = TropicalRational::new(
            TropicalExpr::var(0),
            TropicalExpr::constant(1.0),
        );
        let c = lean_certificate_rational(&r);
        assert!(c.contains("theorem tropical_rational_certificate_numerator_shape_"));
        assert!(c.contains("exact Epistemos.Tropical.RationalCertificateTarget.numeratorShape"));
        assert!(c.contains("theorem tropical_rational_certificate_denominator_shape_"));
        assert!(c.contains("exact Epistemos.Tropical.RationalCertificateTarget.denominatorShape"));
        assert!(c.contains("theorem tropical_rational_certificate_shapes_"));
        assert!(c.contains("exact Epistemos.Tropical.RationalCertificateTarget.representationShapes"));
        assert!(c.contains("tropical_rational_certificate_"));
    }
}
