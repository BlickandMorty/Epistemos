//! WBO-6 budget accounting for hot-path drift checks.
//!
//! This is the canonical Epistemos re-derivation of GPT research
//! `helios-core/src/inequality.rs` against the in-tree substrate. It is a
//! budget surface, not a scientific proof: callers record measured drift and
//! ask whether it fits within the six-term budget described in
//! `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md`.

use crate::resonance::ResonanceSignatureCore;
use serde::{Deserialize, Serialize};

/// WBO-6 terms in canonical doctrine order.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Wbo6Term {
    /// `T_W` - weight/runtime perturbation.
    WeightRuntime,
    /// `T_K` - KV/cache compression and restore.
    KvCache,
    /// `T_R` - Resonance signature overhead.
    Resonance,
    /// `T_Q` - quantization approximation.
    Quantization,
    /// `T_S` - substrate / side-effect boundary.
    SubstrateBoundary,
    /// `T_SE` - Sovereign / security enforcement.
    SovereignSecurity,
}

impl Wbo6Term {
    pub const ALL: [Wbo6Term; 6] = [
        Wbo6Term::WeightRuntime,
        Wbo6Term::KvCache,
        Wbo6Term::Resonance,
        Wbo6Term::Quantization,
        Wbo6Term::SubstrateBoundary,
        Wbo6Term::SovereignSecurity,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            Wbo6Term::WeightRuntime => "T_W",
            Wbo6Term::KvCache => "T_K",
            Wbo6Term::Resonance => "T_R",
            Wbo6Term::Quantization => "T_Q",
            Wbo6Term::SubstrateBoundary => "T_S",
            Wbo6Term::SovereignSecurity => "T_SE",
        }
    }
}

/// The six additive terms before the softmax contraction factor.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Wbo6Terms {
    pub term_w: f64,
    pub term_k: f64,
    pub term_r: f64,
    pub term_q: f64,
    pub term_s: f64,
    pub term_se: f64,
}

impl Wbo6Terms {
    pub const fn zero() -> Self {
        Self {
            term_w: 0.0,
            term_k: 0.0,
            term_r: 0.0,
            term_q: 0.0,
            term_s: 0.0,
            term_se: 0.0,
        }
    }

    pub fn new(
        term_w: f64,
        term_k: f64,
        term_r: f64,
        term_q: f64,
        term_s: f64,
        term_se: f64,
    ) -> Result<Self, Wbo6Error> {
        let terms = Self {
            term_w,
            term_k,
            term_r,
            term_q,
            term_s,
            term_se,
        };
        terms.validate()?;
        Ok(terms)
    }

    pub fn from_pairs(pairs: impl IntoIterator<Item = (Wbo6Term, f64)>) -> Result<Self, Wbo6Error> {
        let mut terms = Self::zero();
        for (term, value) in pairs {
            terms.set(term, value)?;
        }
        Ok(terms)
    }

    pub fn set(&mut self, term: Wbo6Term, value: f64) -> Result<(), Wbo6Error> {
        validate_term(value)?;
        match term {
            Wbo6Term::WeightRuntime => self.term_w = value,
            Wbo6Term::KvCache => self.term_k = value,
            Wbo6Term::Resonance => self.term_r = value,
            Wbo6Term::Quantization => self.term_q = value,
            Wbo6Term::SubstrateBoundary => self.term_s = value,
            Wbo6Term::SovereignSecurity => self.term_se = value,
        }
        Ok(())
    }

    pub const fn get(self, term: Wbo6Term) -> f64 {
        match term {
            Wbo6Term::WeightRuntime => self.term_w,
            Wbo6Term::KvCache => self.term_k,
            Wbo6Term::Resonance => self.term_r,
            Wbo6Term::Quantization => self.term_q,
            Wbo6Term::SubstrateBoundary => self.term_s,
            Wbo6Term::SovereignSecurity => self.term_se,
        }
    }

    pub const fn sum(self) -> f64 {
        self.term_w + self.term_k + self.term_r + self.term_q + self.term_s + self.term_se
    }

    pub fn validate(self) -> Result<(), Wbo6Error> {
        for term in Wbo6Term::ALL {
            validate_term(self.get(term))?;
        }
        Ok(())
    }
}

impl Default for Wbo6Terms {
    fn default() -> Self {
        Self::zero()
    }
}

/// WBO-6 budget evaluator with the canonical 1/2 leading constant.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Wbo6Budget {
    pub terms: Wbo6Terms,
    pub leading_constant: f64,
    pub tolerance: f64,
}

impl Wbo6Budget {
    pub const DEFAULT_LEADING_CONSTANT: f64 = 0.5;
    pub const DEFAULT_TOLERANCE: f64 = 1.0e-12;

    pub fn new(terms: Wbo6Terms) -> Self {
        Self {
            terms,
            leading_constant: Self::DEFAULT_LEADING_CONSTANT,
            tolerance: Self::DEFAULT_TOLERANCE,
        }
    }

    pub fn with_tolerance(mut self, tolerance: f64) -> Result<Self, Wbo6Error> {
        validate_term(tolerance)?;
        self.tolerance = tolerance;
        Ok(self)
    }

    pub fn bound(self) -> Result<f64, Wbo6Error> {
        validate_term(self.leading_constant)?;
        validate_term(self.tolerance)?;
        self.terms.validate()?;
        Ok(self.leading_constant * self.terms.sum())
    }

    pub fn evaluate(self, measured_drift: f64) -> Result<Wbo6Evaluation, Wbo6Error> {
        validate_term(measured_drift)?;
        let bound = self.bound()?;
        let accepted_bound = bound + self.tolerance;
        Ok(Wbo6Evaluation {
            measured_drift,
            bound,
            margin: accepted_bound - measured_drift,
            passed: measured_drift <= accepted_bound,
        })
    }
}

impl Default for Wbo6Budget {
    fn default() -> Self {
        Self::new(Wbo6Terms::zero())
    }
}

/// Output of a single WBO-6 gate evaluation.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Wbo6Evaluation {
    pub measured_drift: f64,
    pub bound: f64,
    pub margin: f64,
    pub passed: bool,
}

/// Errors are explicit so callers cannot silently clamp invalid budgets.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum Wbo6Error {
    InvalidTerm,
    EmptyDistribution,
    DimensionMismatch { reference: usize, candidate: usize },
    InvalidProbability,
}

/// Seed `T_R` reservation for a Core-compatible Resonance signature.
pub const CORE_RESONANCE_TERM_R: f64 = 1.0e-6;

/// Budget terms consumed by the current Core Resonance seed.
///
/// Blocked signatures get a zero display budget because they must not cross the
/// user-visible boundary.
pub fn resonance_core_budget_terms(signature: &ResonanceSignatureCore) -> Wbo6Terms {
    if signature.passes_truth_invariant() && signature.is_core_compatible() {
        Wbo6Terms::from_pairs([(Wbo6Term::Resonance, CORE_RESONANCE_TERM_R)])
            .expect("constant Core Resonance budget is finite and nonnegative")
    } else {
        Wbo6Terms::zero()
    }
}

/// Numerically stable softmax for finite logit slices.
pub fn softmax(logits: &[f64]) -> Result<Vec<f64>, Wbo6Error> {
    if logits.is_empty() {
        return Err(Wbo6Error::EmptyDistribution);
    }
    if logits.iter().any(|value| !value.is_finite()) {
        return Err(Wbo6Error::InvalidProbability);
    }

    let max_logit = logits.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    let mut exps = Vec::with_capacity(logits.len());
    let mut sum = 0.0;
    for value in logits {
        let exp = (*value - max_logit).exp();
        exps.push(exp);
        sum += exp;
    }
    if !sum.is_finite() || sum <= 0.0 {
        return Err(Wbo6Error::InvalidProbability);
    }
    Ok(exps.into_iter().map(|value| value / sum).collect())
}

/// KL divergence `D_KL(reference || candidate)` for probability vectors.
///
/// Inputs may be unnormalized nonnegative weights; they are normalized before
/// the KL sum. Zero candidate probability is floored to keep the diagnostic
/// finite while still heavily penalizing the candidate.
pub fn kl_divergence(reference: &[f64], candidate: &[f64]) -> Result<f64, Wbo6Error> {
    let reference = normalize_distribution(reference)?;
    let candidate = normalize_distribution(candidate)?;
    if reference.len() != candidate.len() {
        return Err(Wbo6Error::DimensionMismatch {
            reference: reference.len(),
            candidate: candidate.len(),
        });
    }

    let eps = 1.0e-12_f64;
    Ok(reference
        .iter()
        .zip(candidate.iter())
        .map(|(p, q)| {
            if *p <= eps {
                0.0
            } else {
                let qq = (*q).max(eps);
                p * (p / qq).ln()
            }
        })
        .sum())
}

pub fn kl_divergence_from_logits(
    reference_logits: &[f64],
    candidate_logits: &[f64],
) -> Result<f64, Wbo6Error> {
    let reference = softmax(reference_logits)?;
    let candidate = softmax(candidate_logits)?;
    kl_divergence(&reference, &candidate)
}

fn normalize_distribution(values: &[f64]) -> Result<Vec<f64>, Wbo6Error> {
    if values.is_empty() {
        return Err(Wbo6Error::EmptyDistribution);
    }
    if values
        .iter()
        .any(|value| !value.is_finite() || *value < 0.0)
    {
        return Err(Wbo6Error::InvalidProbability);
    }
    let sum: f64 = values.iter().sum();
    if !sum.is_finite() || sum <= 0.0 {
        return Err(Wbo6Error::InvalidProbability);
    }
    Ok(values.iter().map(|value| value / sum).collect())
}

fn validate_term(value: f64) -> Result<(), Wbo6Error> {
    if value.is_finite() && value >= 0.0 {
        Ok(())
    } else {
        Err(Wbo6Error::InvalidTerm)
    }
}
