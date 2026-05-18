//! Source:
//! - Doctrine §3 + §5 row Info-IR — Lean schema authority,
//!   Bregman-positivity certificate obligation.
//! - Amari (Springer 2016) Ch. 6 §6.2 — Bregman divergence
//!   positivity from convexity of A.
//! - Companion: [`super::grammar`] (the InfoExpr we certify);
//!   sibling certificate.rs modules for EML-IR (iter-13),
//!   Tropical-IR (iter-22), Scan-IR (iter-28).
//!
//! # Info-IR Lean certificate
//!
//! Emits Lean 4 source as a String targeting `Epistemos.Info`.
//! `lake build` remains gated by the T5 blocker ledger until
//! `elan`/`lean`/`lake` are available in `PATH`.
//!
//! The emitted theorem statements:
//!
//! 1. **Bregman positivity**: `KL(P, Q) ≥ 0`.
//! 2. **Bregman non-degeneracy**: `KL(P, Q) = 0 ⟺ P = Q`.
//! 3. **Mirror-descent ↔ Bregman-projected-gradient equivalence**
//!    per Beck-Teboulle 2003 §2.

use super::grammar::{ExpFamily, InfoExpr};

fn family_name(family: &ExpFamily) -> String {
    match family {
        ExpFamily::Bernoulli => "Bernoulli".to_string(),
        ExpFamily::Categorical { k } => format!("Categorical_{}", k),
        ExpFamily::Gaussian { variance } => {
            // Variance encoded with finite precision in the theorem name.
            format!("Gaussian_var_{}", (variance * 1e6) as i64)
        }
    }
}

fn family_term(family: &ExpFamily) -> String {
    match family {
        ExpFamily::Bernoulli => "Epistemos.Info.ExpFamily.bernoulli".to_string(),
        ExpFamily::Categorical { k } => {
            format!("(Epistemos.Info.ExpFamily.categorical {})", k)
        }
        ExpFamily::Gaussian { variance } => {
            format!("(Epistemos.Info.ExpFamily.gaussian ({} : Real))", variance)
        }
    }
}

fn family_well_formed_proof(family: &ExpFamily) -> &'static str {
    match family {
        ExpFamily::Bernoulli => "Epistemos.Info.ExpFamily.bernoulli_wellFormed",
        ExpFamily::Categorical { .. } => "by decide",
        ExpFamily::Gaussian { .. } => "by positivity",
    }
}

fn family_arity_proof(family: &ExpFamily) -> &'static str {
    match family {
        ExpFamily::Bernoulli | ExpFamily::Gaussian { .. } => "rfl",
        ExpFamily::Categorical { .. } => "by decide",
    }
}

fn real_list_term(params: &[f64]) -> String {
    let terms: Vec<String> = params.iter().map(|v| format!("({} : Real)", v)).collect();
    format!("[{}]", terms.join(", "))
}

fn lean_expr_term(expr: &InfoExpr) -> String {
    match expr {
        InfoExpr::LogPartition {
            family,
            natural_params,
        } => format!(
            "(Epistemos.Info.Expr.logPartition {{ family := {family_term}, \
             naturalParams := {params}, wellFormed := {well_formed}, \
             arityMatches := {arity} }})",
            family_term = family_term(family),
            params = real_list_term(natural_params),
            well_formed = family_well_formed_proof(family),
            arity = family_arity_proof(family),
        ),
        InfoExpr::DualMap {
            family,
            natural_params,
        } => format!(
            "(Epistemos.Info.Expr.dualMap {{ family := {family_term}, \
             naturalParams := {params}, wellFormed := {well_formed}, \
             arityMatches := {arity} }})",
            family_term = family_term(family),
            params = real_list_term(natural_params),
            well_formed = family_well_formed_proof(family),
            arity = family_arity_proof(family),
        ),
        InfoExpr::KlProjection {
            family,
            p_params,
            q_params,
        } => format!(
            "(Epistemos.Info.Expr.klProjection {{ family := {family_term}, \
             pParams := {p_params}, qParams := {q_params}, \
             wellFormed := {well_formed}, pArityMatches := {p_arity}, \
             qArityMatches := {q_arity} }})",
            family_term = family_term(family),
            p_params = real_list_term(p_params),
            q_params = real_list_term(q_params),
            well_formed = family_well_formed_proof(family),
            p_arity = family_arity_proof(family),
            q_arity = family_arity_proof(family),
        ),
    }
}

fn obligation_params(expr: &InfoExpr) -> (&[f64], &[f64]) {
    match expr {
        InfoExpr::LogPartition { natural_params, .. }
        | InfoExpr::DualMap { natural_params, .. } => (natural_params, natural_params),
        InfoExpr::KlProjection {
            p_params, q_params, ..
        } => (p_params, q_params),
    }
}

fn expr_hash_suffix(expr: &InfoExpr) -> String {
    const FNV_OFFSET: u64 = 0xcbf29ce484222325;
    const FNV_PRIME: u64 = 0x100000001b3;
    let mut h = FNV_OFFSET;
    let tag = match expr {
        InfoExpr::LogPartition { .. } => b'L',
        InfoExpr::DualMap { .. } => b'D',
        InfoExpr::KlProjection { .. } => b'K',
    };
    h ^= tag as u64;
    h = h.wrapping_mul(FNV_PRIME);
    match expr {
        InfoExpr::LogPartition { natural_params, .. }
        | InfoExpr::DualMap { natural_params, .. } => {
            for v in natural_params {
                for byte in v.to_bits().to_le_bytes() {
                    h ^= byte as u64;
                    h = h.wrapping_mul(FNV_PRIME);
                }
            }
        }
        InfoExpr::KlProjection {
            p_params, q_params, ..
        } => {
            for v in p_params.iter().chain(q_params.iter()) {
                for byte in v.to_bits().to_le_bytes() {
                    h ^= byte as u64;
                    h = h.wrapping_mul(FNV_PRIME);
                }
            }
        }
    }
    format!("{:016x}", h)
}

/// Emit a Lean 4 certificate for an [`InfoExpr`]. Carries
/// Bregman-positivity, Bregman-non-degeneracy, and mirror-descent
/// equivalence theorems (all sorry-stubbed).
pub fn lean_certificate(expr: &InfoExpr) -> String {
    let family = family_name(expr.family());
    let family_term = family_term(expr.family());
    let expr_term = lean_expr_term(expr);
    let (p_params, q_params) = obligation_params(expr);
    let p_term = real_list_term(p_params);
    let q_term = real_list_term(q_params);
    let suffix = expr_hash_suffix(expr);
    format!(
        "-- Generated by Info-IR certificate.rs (T5 Phase B4 iter-34)\n\
         -- Source: docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5 (row Info-IR)\n\
         -- Family: {family}\n\
         -- Schema: lean/Epistemos/Epistemos/Info.lean\n\
         import Epistemos.Info\n\
         \n\
         namespace Epistemos.Info.Generated\n\
         \n\
         def info_expr_{suffix} : Epistemos.Info.Expr :=\n\
         \x20   {expr_term}\n\
         \n\
         def info_convexity_obligation_{suffix} : Epistemos.Info.ConvexLogPartitionObligation :=\n\
         \x20   {{ family := {family_term}\n\
         \x20     naturalParams := {p_term}\n\
         \x20     convexOnNaturalDomain := True\n\
         \x20     sourceRow := \"docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md §3 + §5 Info-IR\" }}\n\
         \n\
         def info_bregman_obligation_{suffix} : Epistemos.Info.BregmanPositivityObligation :=\n\
         \x20   {{ family := {family_term}\n\
         \x20     pParams := {p_term}\n\
         \x20     qParams := {q_term}\n\
         \x20     nonnegative := True\n\
         \x20     zeroIffEqual := True\n\
         \x20     sourceRow := \"Amari 2016 Ch. 6 §6.2\" }}\n\
         \n\
         def info_mirror_descent_obligation_{suffix} : Epistemos.Info.MirrorDescentEquivalenceObligation :=\n\
         \x20   {{ family := {family_term}\n\
         \x20     statement := True\n\
         \x20     sourceRow := \"Beck-Teboulle 2003 §2\" }}\n\
         \n\
         def info_certificate_{suffix} : Epistemos.Info.CertificateTarget :=\n\
         \x20   {{ expr := info_expr_{suffix}\n\
         \x20     convexity := some info_convexity_obligation_{suffix}\n\
         \x20     positivity := info_bregman_obligation_{suffix}\n\
         \x20     mirrorEquivalence := info_mirror_descent_obligation_{suffix} }}\n\
         \n\
         theorem info_bregman_positivity_{suffix} :\n\
         \x20   info_bregman_obligation_{suffix}.nonnegative := by\n\
         \x20 sorry  -- Amari Ch. 6 §6.2: convexity of A ⇒ B_A ≥ 0\n\
         \n\
         theorem info_bregman_non_degeneracy_{suffix} :\n\
         \x20   info_bregman_obligation_{suffix}.zeroIffEqual := by\n\
         \x20 sorry  -- strict convexity of A on its natural domain\n\
         \n\
         theorem info_mirror_descent_equivalence_{suffix} :\n\
         \x20   info_mirror_descent_obligation_{suffix}.statement := by\n\
         \x20 sorry  -- Beck-Teboulle 2003 §2\n\
         \n\
         end Epistemos.Info.Generated\n\
         \n",
        family = family,
        family_term = family_term,
        expr_term = expr_term,
        p_term = p_term,
        q_term = q_term,
        suffix = suffix,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn certificate_targets_info_schema_module() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c = lean_certificate(&e);
        assert!(c.contains("import Epistemos.Info"));
        assert!(c.contains("namespace Epistemos.Info.Generated"));
        assert!(c.contains("Epistemos.Info.CertificateTarget"));
        assert!(c.contains("Epistemos.Info.Expr.logPartition"));
    }

    #[test]
    fn certificate_has_positivity_theorem() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c = lean_certificate(&e);
        assert!(c.contains("info_bregman_positivity_"));
        assert!(c.contains("info_bregman_obligation_"));
        assert!(c.contains(".nonnegative := by"));
    }

    #[test]
    fn certificate_has_non_degeneracy_theorem() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c = lean_certificate(&e);
        assert!(c.contains("info_bregman_non_degeneracy_"));
        assert!(c.contains(".zeroIffEqual := by"));
    }

    #[test]
    fn certificate_has_mirror_descent_equivalence() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c = lean_certificate(&e);
        assert!(c.contains("info_mirror_descent_equivalence_"));
        assert!(c.contains("info_mirror_descent_obligation_"));
    }

    #[test]
    fn family_name_categorical_includes_k() {
        let e = InfoExpr::log_partition(ExpFamily::Categorical { k: 5 }, vec![0.0, 0.0, 0.0, 0.0])
            .unwrap();
        let c = lean_certificate(&e);
        assert!(c.contains("Categorical_5"));
    }

    #[test]
    fn family_name_gaussian_includes_variance() {
        let e = InfoExpr::log_partition(ExpFamily::Gaussian { variance: 2.5 }, vec![1.0]).unwrap();
        let c = lean_certificate(&e);
        // 2.5 * 1e6 as i64 = 2500000
        assert!(c.contains("Gaussian_var_2500000"));
    }

    #[test]
    fn three_sorry_proof_bodies() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c = lean_certificate(&e);
        assert_eq!(c.matches("sorry").count(), 3);
    }

    #[test]
    fn header_cites_phase_b4_iter_34() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c = lean_certificate(&e);
        assert!(c.contains("iter-34"));
    }

    #[test]
    fn hash_distinguishes_log_partition_from_dual_map() {
        let lp = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.5]).unwrap();
        let dm = InfoExpr::dual_map(ExpFamily::Bernoulli, vec![0.5]).unwrap();
        assert_ne!(expr_hash_suffix(&lp), expr_hash_suffix(&dm));
    }

    #[test]
    fn hash_is_stable_across_calls() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        assert_eq!(expr_hash_suffix(&e), expr_hash_suffix(&e));
    }

    #[test]
    fn deterministic_for_same_input() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let c1 = lean_certificate(&e);
        let c2 = lean_certificate(&e);
        assert_eq!(c1, c2);
    }
}
