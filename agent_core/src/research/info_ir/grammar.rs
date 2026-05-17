//! Source:
//! - Amari (Springer 2016) Ch. 2 — exponential families are
//!   parameterized by their natural parameters θ ∈ ℝ^d with
//!   log-partition function A(θ). Dual coordinates η = ∇A(θ) are
//!   the mean parameters.
//! - Doctrine §4.5 — Info-IR Rust crate-module shape.
//!
//! # Info-IR typed AST
//!
//! Three primitives per doctrine §2.5:
//!
//! - `LogPartition { family, natural_params: Vec<f64> }` —
//!   the cumulant function `A(θ)` of an exponential family.
//! - `DualMap { family, natural_params: Vec<f64> }` —
//!   the mean parametrization `η = ∇A(θ)`.
//! - `KlProjection { family, p_params, q_params }` —
//!   Bregman projection of distribution `P` onto a constraint set
//!   anchored by `Q`. In information geometry, KL(P || Q) is the
//!   Bregman divergence induced by A.
//!
//! Phase B4 ships Bernoulli + Categorical + Gaussian as named
//! variants. Each carries the parametrization arity invariant
//! enforced by [`InfoExpr::validate`].

use serde::{Deserialize, Serialize};

/// Exponential family tag. Carries the family's structural
/// parameters (e.g. number of categories for Categorical) but NOT
/// the natural parameters — those live on [`InfoExpr`] nodes.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum ExpFamily {
    /// Bernoulli: scalar natural parameter θ ∈ ℝ; log-partition
    /// A(θ) = ln(1 + exp(θ)); dual η = sigmoid(θ).
    Bernoulli,
    /// Categorical with `k` categories: natural parameter
    /// θ ∈ ℝ^{k-1} (one component pinned to 0 for identifiability).
    Categorical { k: usize },
    /// Gaussian with known variance σ² > 0: scalar natural parameter
    /// θ = μ / σ²; log-partition A(θ) = σ²θ²/2.
    Gaussian { variance: f64 },
}

impl ExpFamily {
    /// Expected natural-parameter arity for this family.
    /// - Bernoulli: 1 (the scalar θ).
    /// - Categorical{k}: k - 1 (one component pinned for
    ///   identifiability).
    /// - Gaussian: 1.
    pub fn natural_param_arity(&self) -> usize {
        match self {
            ExpFamily::Bernoulli => 1,
            ExpFamily::Categorical { k } => {
                if *k == 0 {
                    0
                } else {
                    k - 1
                }
            }
            ExpFamily::Gaussian { .. } => 1,
        }
    }

    /// `true` iff this is a well-formed family carrier
    /// (Categorical k ≥ 2, Gaussian variance > 0).
    pub fn is_well_formed(&self) -> bool {
        match self {
            ExpFamily::Bernoulli => true,
            ExpFamily::Categorical { k } => *k >= 2,
            ExpFamily::Gaussian { variance } => *variance > 0.0 && variance.is_finite(),
        }
    }
}

/// Info-IR expression. Three primitive nodes covering log-partition,
/// dual map, and KL projection.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum InfoExpr {
    LogPartition {
        family: ExpFamily,
        natural_params: Vec<f64>,
    },
    DualMap {
        family: ExpFamily,
        natural_params: Vec<f64>,
    },
    KlProjection {
        family: ExpFamily,
        p_params: Vec<f64>,
        q_params: Vec<f64>,
    },
}

/// Construction-validation error.
#[derive(Clone, Debug, PartialEq)]
pub enum InfoExprError {
    FamilyMalformed { family: ExpFamily },
    ArityMismatch { family: ExpFamily, expected: usize, actual: usize },
    NonFiniteParam { idx: usize, value: f64 },
}

impl InfoExpr {
    /// Build a [`InfoExpr::LogPartition`] with eager validation.
    pub fn log_partition(
        family: ExpFamily,
        natural_params: Vec<f64>,
    ) -> Result<Self, InfoExprError> {
        check_family_and_arity(&family, natural_params.len())?;
        check_finite(&natural_params)?;
        Ok(InfoExpr::LogPartition {
            family,
            natural_params,
        })
    }

    /// Build a [`InfoExpr::DualMap`] with eager validation.
    pub fn dual_map(
        family: ExpFamily,
        natural_params: Vec<f64>,
    ) -> Result<Self, InfoExprError> {
        check_family_and_arity(&family, natural_params.len())?;
        check_finite(&natural_params)?;
        Ok(InfoExpr::DualMap {
            family,
            natural_params,
        })
    }

    /// Build a [`InfoExpr::KlProjection`] with eager validation
    /// (both p_params and q_params).
    pub fn kl_projection(
        family: ExpFamily,
        p_params: Vec<f64>,
        q_params: Vec<f64>,
    ) -> Result<Self, InfoExprError> {
        check_family_and_arity(&family, p_params.len())?;
        check_family_and_arity(&family, q_params.len())?;
        check_finite(&p_params)?;
        check_finite(&q_params)?;
        Ok(InfoExpr::KlProjection {
            family,
            p_params,
            q_params,
        })
    }

    /// Get the family tag.
    pub fn family(&self) -> &ExpFamily {
        match self {
            InfoExpr::LogPartition { family, .. } => family,
            InfoExpr::DualMap { family, .. } => family,
            InfoExpr::KlProjection { family, .. } => family,
        }
    }

    /// Re-validate (idempotent — `new`-style constructors already
    /// validate eagerly).
    pub fn validate(&self) -> Result<(), InfoExprError> {
        match self {
            InfoExpr::LogPartition { family, natural_params }
            | InfoExpr::DualMap { family, natural_params } => {
                check_family_and_arity(family, natural_params.len())?;
                check_finite(natural_params)
            }
            InfoExpr::KlProjection { family, p_params, q_params } => {
                check_family_and_arity(family, p_params.len())?;
                check_family_and_arity(family, q_params.len())?;
                check_finite(p_params)?;
                check_finite(q_params)
            }
        }
    }
}

fn check_family_and_arity(
    family: &ExpFamily,
    actual: usize,
) -> Result<(), InfoExprError> {
    if !family.is_well_formed() {
        return Err(InfoExprError::FamilyMalformed {
            family: family.clone(),
        });
    }
    let expected = family.natural_param_arity();
    if actual != expected {
        return Err(InfoExprError::ArityMismatch {
            family: family.clone(),
            expected,
            actual,
        });
    }
    Ok(())
}

fn check_finite(params: &[f64]) -> Result<(), InfoExprError> {
    for (idx, &v) in params.iter().enumerate() {
        if !v.is_finite() {
            return Err(InfoExprError::NonFiniteParam { idx, value: v });
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bernoulli_arity_is_one() {
        assert_eq!(ExpFamily::Bernoulli.natural_param_arity(), 1);
    }

    #[test]
    fn categorical_arity_is_k_minus_one() {
        assert_eq!(ExpFamily::Categorical { k: 3 }.natural_param_arity(), 2);
        assert_eq!(ExpFamily::Categorical { k: 10 }.natural_param_arity(), 9);
    }

    #[test]
    fn gaussian_arity_is_one() {
        assert_eq!(ExpFamily::Gaussian { variance: 1.0 }.natural_param_arity(), 1);
    }

    #[test]
    fn well_formed_predicate() {
        assert!(ExpFamily::Bernoulli.is_well_formed());
        assert!(ExpFamily::Categorical { k: 2 }.is_well_formed());
        assert!(ExpFamily::Categorical { k: 5 }.is_well_formed());
        assert!(!ExpFamily::Categorical { k: 0 }.is_well_formed());
        assert!(!ExpFamily::Categorical { k: 1 }.is_well_formed());
        assert!(ExpFamily::Gaussian { variance: 1.0 }.is_well_formed());
        assert!(!ExpFamily::Gaussian { variance: 0.0 }.is_well_formed());
        assert!(!ExpFamily::Gaussian { variance: -1.0 }.is_well_formed());
        assert!(!ExpFamily::Gaussian { variance: f64::NAN }.is_well_formed());
    }

    #[test]
    fn log_partition_bernoulli_valid() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.5]).unwrap();
        assert_eq!(*e.family(), ExpFamily::Bernoulli);
    }

    #[test]
    fn log_partition_arity_mismatch_rejected() {
        let err =
            InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.5, 1.0]).unwrap_err();
        assert!(matches!(err, InfoExprError::ArityMismatch { expected: 1, actual: 2, .. }));
    }

    #[test]
    fn categorical_3_takes_2_params() {
        let e = InfoExpr::log_partition(
            ExpFamily::Categorical { k: 3 },
            vec![0.1, -0.2],
        )
        .unwrap();
        assert_eq!(*e.family(), ExpFamily::Categorical { k: 3 });
    }

    #[test]
    fn non_finite_param_rejected() {
        let err =
            InfoExpr::log_partition(ExpFamily::Bernoulli, vec![f64::NAN]).unwrap_err();
        assert!(matches!(err, InfoExprError::NonFiniteParam { .. }));
    }

    #[test]
    fn malformed_family_rejected() {
        let err = InfoExpr::log_partition(ExpFamily::Categorical { k: 1 }, vec![])
            .unwrap_err();
        assert!(matches!(err, InfoExprError::FamilyMalformed { .. }));
    }

    #[test]
    fn dual_map_validates_like_log_partition() {
        assert!(InfoExpr::dual_map(ExpFamily::Bernoulli, vec![0.0]).is_ok());
        assert!(
            InfoExpr::dual_map(ExpFamily::Bernoulli, vec![0.0, 0.0]).is_err()
        );
    }

    #[test]
    fn kl_projection_validates_both_sides() {
        let ok = InfoExpr::kl_projection(
            ExpFamily::Bernoulli,
            vec![0.5],
            vec![0.0],
        );
        assert!(ok.is_ok());

        let err = InfoExpr::kl_projection(
            ExpFamily::Bernoulli,
            vec![0.5],
            vec![0.0, 1.0],
        );
        assert!(err.is_err());
    }

    #[test]
    fn validate_idempotent_after_constructor() {
        let e = InfoExpr::log_partition(ExpFamily::Bernoulli, vec![1.5]).unwrap();
        assert!(e.validate().is_ok());
    }

    #[test]
    fn round_trips_through_serde_json() {
        let e = InfoExpr::kl_projection(
            ExpFamily::Categorical { k: 4 },
            vec![0.1, 0.2, -0.3],
            vec![0.0, 0.0, 0.0],
        )
        .unwrap();
        let json = serde_json::to_string(&e).unwrap();
        let back: InfoExpr = serde_json::from_str(&json).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn family_getter_returns_correct_variant() {
        let lp = InfoExpr::log_partition(ExpFamily::Gaussian { variance: 1.0 }, vec![0.0]).unwrap();
        assert_eq!(*lp.family(), ExpFamily::Gaussian { variance: 1.0 });

        let dm = InfoExpr::dual_map(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        assert_eq!(*dm.family(), ExpFamily::Bernoulli);

        let kl = InfoExpr::kl_projection(
            ExpFamily::Categorical { k: 2 },
            vec![0.1],
            vec![0.2],
        ).unwrap();
        assert_eq!(*kl.family(), ExpFamily::Categorical { k: 2 });
    }
}
