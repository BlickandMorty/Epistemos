//! WBO-6 bound accounting.

/// Individual WBO-6 terms before the leading softmax contraction factor.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WBOTerms {
    pub term_w: f32,
    pub term_k: f32,
    pub term_r: f32,
    pub term_q: f32,
    pub term_s: f32,
    pub term_se: f32,
}

impl WBOTerms {
    #[must_use]
    pub const fn zero() -> Self {
        Self { term_w: 0.0, term_k: 0.0, term_r: 0.0, term_q: 0.0, term_s: 0.0, term_se: 0.0 }
    }

    #[must_use]
    pub fn sum(self) -> f32 {
        self.term_w + self.term_k + self.term_r + self.term_q + self.term_s + self.term_se
    }

    #[must_use]
    pub fn all_finite_nonnegative(self) -> bool {
        [self.term_w, self.term_k, self.term_r, self.term_q, self.term_s, self.term_se]
            .into_iter()
            .all(|v| v.is_finite() && v >= 0.0)
    }
}

/// WBO-6 tracker with the softmax 1/2 leading constant.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WBOSix {
    pub terms: WBOTerms,
    pub leading_constant: f32,
    pub tolerance: f32,
}

impl Default for WBOSix {
    fn default() -> Self {
        Self { terms: WBOTerms::zero(), leading_constant: 0.5, tolerance: 1.0e-6 }
    }
}

impl WBOSix {
    #[must_use]
    pub const fn new(terms: WBOTerms) -> Self {
        Self { terms, leading_constant: 0.5, tolerance: 1.0e-6 }
    }

    #[must_use]
    pub fn total_bound(self) -> f32 {
        self.leading_constant * self.terms.sum()
    }

    pub fn assert_within_bound(self, measured_kl: f32) -> Result<(), InequalityError> {
        if !self.terms.all_finite_nonnegative() || !measured_kl.is_finite() || measured_kl < 0.0 {
            return Err(InequalityError::InvalidInput);
        }
        let bound = self.total_bound() + self.tolerance;
        if measured_kl <= bound {
            Ok(())
        } else {
            Err(InequalityError::Exceeded { measured: measured_kl, bound })
        }
    }

    #[must_use]
    pub fn with_term_w(mut self, value: f32) -> Self { self.terms.term_w = value.max(0.0); self }
    #[must_use]
    pub fn with_term_k(mut self, value: f32) -> Self { self.terms.term_k = value.max(0.0); self }
    #[must_use]
    pub fn with_term_r(mut self, value: f32) -> Self { self.terms.term_r = value.max(0.0); self }
    #[must_use]
    pub fn with_term_q(mut self, value: f32) -> Self { self.terms.term_q = value.max(0.0); self }
    #[must_use]
    pub fn with_term_s(mut self, value: f32) -> Self { self.terms.term_s = value.max(0.0); self }
    #[must_use]
    pub fn with_term_se(mut self, value: f32) -> Self { self.terms.term_se = value.max(0.0); self }
}

/// Error produced by WBO gate evaluation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum InequalityError {
    InvalidInput,
    Exceeded { measured: f32, bound: f32 },
}

/// KL divergence for probability vectors.
#[must_use]
pub fn kl_divergence(reference: &[f32], candidate: &[f32]) -> f32 {
    assert_eq!(reference.len(), candidate.len(), "KL dimension mismatch");
    let eps = 1.0e-12_f32;
    reference
        .iter()
        .zip(candidate.iter())
        .map(|(p, q)| {
            let pp = (*p).max(eps);
            let qq = (*q).max(eps);
            pp * (pp / qq).ln()
        })
        .sum()
}

#[cfg(test)]
mod tests {
    use super::{kl_divergence, WBOSix, WBOTerms};

    #[test]
    fn total_bound_has_half_constant() {
        let wbo = WBOSix::new(WBOTerms { term_w: 1.0, term_k: 1.0, term_r: 1.0, term_q: 1.0, term_s: 1.0, term_se: 1.0 });
        assert_eq!(wbo.total_bound(), 3.0);
    }

    #[test]
    fn kl_zero_for_identical_distributions() {
        assert!(kl_divergence(&[0.25, 0.75], &[0.25, 0.75]) < 1.0e-6);
    }

    #[test]
    fn bound_accepts_inside_values() {
        let wbo = WBOSix::new(WBOTerms { term_w: 0.1, term_k: 0.1, term_r: 0.1, term_q: 0.1, term_s: 0.1, term_se: 0.1 });
        assert!(wbo.assert_within_bound(0.2).is_ok());
    }
}
