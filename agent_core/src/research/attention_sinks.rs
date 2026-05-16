//! Source:
//! - Xiao et al., "Efficient Streaming Language Models with Attention
//!   Sinks", arXiv:2309.17453 — first systematic characterization of
//!   the "sink" phenomenon: a small set of early tokens disproportionately
//!   absorb attention mass, and removing them collapses model quality
//!   on streaming inputs.
//! - Wang-Liang, "Mamba is the Koopman", ICLR 2025 (referenced in
//!   `helios v3.md` Part I Pillar IV) — recasts SSM A-matrix dynamics
//!   as a Koopman operator on the model's state space. The
//!   "attention-sinks-as-spectral-feature" view says sinks correspond
//!   to dominant eigenvalues of the attention block's effective
//!   transfer operator.
//! - Companion to [`super::koopman`] — this module realizes the
//!   `KoopmanConsequence::AttentionSinksSpectral` consequence (was
//!   "NOT-STARTED" prior to iter 84).
//!
//! # Wave J B.6.14 — Attention-sinks spectral substrate
//!
//! Substrate floor owns:
//!
//! - `AttentionSpectrum` — typed envelope around a non-empty Vec of
//!   non-negative f64 eigenvalues sorted descending.
//! - `detect_sinks(spectrum, dominance)` — every eigenvalue whose
//!   magnitude is at least `dominance × median` is reported as a sink
//!   index. Returns indices into the input spectrum.
//! - `sink_strength(spectrum)` — `λ_max / median(λ)`. Higher = more
//!   sink-like; ≈1.0 means uniform spectrum (no sinks).
//!
//! Production wires this to actual attention-matrix eigen-decomposition
//! (which lives one layer up, in the Metal kernel that runs the
//! attention block). The substrate floor here is the math + the
//! verdict surface so the upstream code links against a typed contract
//! today.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AttentionSpectrum {
    eigenvalues_descending: Vec<f64>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AttentionSinkError {
    EmptySpectrum,
    NegativeEigenvalue { index: usize, value: f64 },
    NonFiniteEigenvalue { index: usize },
    NotSortedDescending { at: usize },
    DominanceOutOfRange { value: f64 },
}

impl AttentionSpectrum {
    /// Construct + validate: non-empty, all finite, all ≥ 0, sorted
    /// descending. Returns a typed error if any invariant fails.
    pub fn new(values: Vec<f64>) -> Result<Self, AttentionSinkError> {
        if values.is_empty() {
            return Err(AttentionSinkError::EmptySpectrum);
        }
        for (i, &v) in values.iter().enumerate() {
            if !v.is_finite() {
                return Err(AttentionSinkError::NonFiniteEigenvalue { index: i });
            }
            if v < 0.0 {
                return Err(AttentionSinkError::NegativeEigenvalue { index: i, value: v });
            }
        }
        for i in 1..values.len() {
            if values[i] > values[i - 1] {
                return Err(AttentionSinkError::NotSortedDescending { at: i });
            }
        }
        Ok(Self { eigenvalues_descending: values })
    }

    pub fn len(&self) -> usize {
        self.eigenvalues_descending.len()
    }

    pub fn as_slice(&self) -> &[f64] {
        &self.eigenvalues_descending
    }

    /// Median of the spectrum. With an even count, average of the two
    /// middle values; with an odd count, the middle value.
    pub fn median(&self) -> f64 {
        let n = self.eigenvalues_descending.len();
        if n % 2 == 1 {
            self.eigenvalues_descending[n / 2]
        } else {
            let lo = self.eigenvalues_descending[n / 2];
            let hi = self.eigenvalues_descending[n / 2 - 1];
            0.5 * (lo + hi)
        }
    }

    /// Largest eigenvalue (index 0 because the spectrum is sorted
    /// descending).
    pub fn max(&self) -> f64 {
        self.eigenvalues_descending[0]
    }
}

/// Return the indices of all eigenvalues whose magnitude is at least
/// `dominance × median`. `dominance` must be > 1.0 to filter anything
/// (1.0 returns every value ≥ median, which is half of them by
/// construction). Substrate-floor production default is 4.0 per
/// Xiao et al.'s empirical observation that sink-token attention
/// scores are typically ≥ 4× the median.
pub fn detect_sinks(
    spectrum: &AttentionSpectrum,
    dominance: f64,
) -> Result<Vec<usize>, AttentionSinkError> {
    if !dominance.is_finite() || dominance <= 0.0 {
        return Err(AttentionSinkError::DominanceOutOfRange { value: dominance });
    }
    let threshold = dominance * spectrum.median();
    let mut indices = Vec::new();
    for (i, &v) in spectrum.eigenvalues_descending.iter().enumerate() {
        if v >= threshold {
            indices.push(i);
        }
    }
    Ok(indices)
}

/// `λ_max / median(λ)`. Reports how dominated the spectrum is by its
/// top eigenvalue. ≈1.0 = uniform; ≫1.0 = strongly sink-shaped.
/// Returns `f64::INFINITY` if the median is 0.
pub fn sink_strength(spectrum: &AttentionSpectrum) -> f64 {
    let med = spectrum.median();
    if med == 0.0 {
        return f64::INFINITY;
    }
    spectrum.max() / med
}

pub const DEFAULT_SINK_DOMINANCE: f64 = 4.0;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_spectrum_rejected() {
        assert_eq!(
            AttentionSpectrum::new(vec![]).unwrap_err(),
            AttentionSinkError::EmptySpectrum
        );
    }

    #[test]
    fn negative_eigenvalue_rejected() {
        assert!(matches!(
            AttentionSpectrum::new(vec![1.0, -0.5]).unwrap_err(),
            AttentionSinkError::NegativeEigenvalue { .. }
        ));
    }

    #[test]
    fn nan_eigenvalue_rejected() {
        assert!(matches!(
            AttentionSpectrum::new(vec![1.0, f64::NAN]).unwrap_err(),
            AttentionSinkError::NonFiniteEigenvalue { .. }
        ));
    }

    #[test]
    fn infinite_eigenvalue_rejected() {
        assert!(matches!(
            AttentionSpectrum::new(vec![f64::INFINITY]).unwrap_err(),
            AttentionSinkError::NonFiniteEigenvalue { .. }
        ));
    }

    #[test]
    fn unsorted_eigenvalues_rejected() {
        assert!(matches!(
            AttentionSpectrum::new(vec![1.0, 5.0, 2.0]).unwrap_err(),
            AttentionSinkError::NotSortedDescending { .. }
        ));
    }

    #[test]
    fn well_formed_spectrum_constructs() {
        let s = AttentionSpectrum::new(vec![5.0, 3.0, 1.0]).unwrap();
        assert_eq!(s.len(), 3);
        assert_eq!(s.max(), 5.0);
    }

    #[test]
    fn median_odd_count() {
        let s = AttentionSpectrum::new(vec![10.0, 5.0, 1.0]).unwrap();
        assert!((s.median() - 5.0).abs() < 1e-12);
    }

    #[test]
    fn median_even_count() {
        let s = AttentionSpectrum::new(vec![10.0, 6.0, 4.0, 2.0]).unwrap();
        // Sorted desc: 10, 6, 4, 2; n=4, lo=index 2 (4.0), hi=index 1 (6.0)
        assert!((s.median() - 5.0).abs() < 1e-12);
    }

    #[test]
    fn detect_sinks_at_4x_median() {
        // median = 1.0; 4× threshold = 4.0. Only the 8.0 qualifies.
        let s = AttentionSpectrum::new(vec![8.0, 3.0, 1.0, 0.5, 0.2]).unwrap();
        let sinks = detect_sinks(&s, 4.0).unwrap();
        assert_eq!(sinks, vec![0]);
    }

    #[test]
    fn detect_sinks_multiple() {
        // median = 1.0; 4× threshold = 4.0. 10.0 and 5.0 both qualify
        // (5.0 ≥ 4.0).
        let s = AttentionSpectrum::new(vec![10.0, 5.0, 1.0, 0.5, 0.1]).unwrap();
        let sinks = detect_sinks(&s, 4.0).unwrap();
        assert_eq!(sinks, vec![0, 1]);
    }

    #[test]
    fn detect_sinks_none_when_uniform() {
        // Uniform spectrum: every eigenvalue ≈ 1.0; median = 1.0; 4×
        // threshold = 4.0; nothing qualifies.
        let s = AttentionSpectrum::new(vec![1.0, 1.0, 1.0, 1.0, 1.0]).unwrap();
        let sinks = detect_sinks(&s, 4.0).unwrap();
        assert!(sinks.is_empty());
    }

    #[test]
    fn detect_sinks_invalid_dominance_rejected() {
        let s = AttentionSpectrum::new(vec![1.0]).unwrap();
        assert!(detect_sinks(&s, -1.0).is_err());
        assert!(detect_sinks(&s, 0.0).is_err());
        assert!(detect_sinks(&s, f64::NAN).is_err());
    }

    #[test]
    fn sink_strength_uniform_spectrum_near_one() {
        let s = AttentionSpectrum::new(vec![1.0, 1.0, 1.0]).unwrap();
        assert!((sink_strength(&s) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn sink_strength_dominated_spectrum_large() {
        let s = AttentionSpectrum::new(vec![100.0, 1.0, 1.0]).unwrap();
        assert!((sink_strength(&s) - 100.0).abs() < 1e-12);
    }

    #[test]
    fn sink_strength_zero_median_infinite() {
        let s = AttentionSpectrum::new(vec![1.0, 0.0, 0.0]).unwrap();
        assert!(sink_strength(&s).is_infinite());
    }

    #[test]
    fn default_dominance_is_four() {
        assert_eq!(DEFAULT_SINK_DOMINANCE, 4.0);
    }

    #[test]
    fn spectrum_roundtrips_through_serde_json() {
        let s = AttentionSpectrum::new(vec![5.0, 3.0, 1.0]).unwrap();
        let json = serde_json::to_string(&s).unwrap();
        let back: AttentionSpectrum = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }
}
