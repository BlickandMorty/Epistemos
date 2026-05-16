//! Source:
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
//!   §"Terminal B" Phase B.6.17 — T-Substrate-Independence /
//!   F-BZ-Substrate-Independence. The theoretical claim: a
//!   well-specified computation produces the same answer on every
//!   supported substrate up to a documented numeric tolerance.
//! - Companion to [`super::ane_direct`] (J8) and [`super::ternary::backend`]
//!   (J1 3-backend trait) — both predicate their A/B/C correctness
//!   stories on this same invariant.
//!
//! # Wave J B.6.17 — Substrate-independence checker
//!
//! Substrate floor for the F-BZ-Substrate-Independence falsifier:
//! given a `Computation` and `N` substrate implementations, run all
//! `N` on the same input and report the maximum pairwise divergence.
//! Pass iff every pair is within the caller-supplied tolerance.
//!
//! The substrate-floor focus is on the **divergence metric** + the
//! **per-pair table** so callers can diagnose which (substrate_a,
//! substrate_b) pair drifted. Concrete substrate impls live in their
//! respective siblings — this module owns only the cross-backend
//! correctness harness.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Substrate {
    Cpu,
    Gpu,
    Ane,
    /// In-memory mock used in tests.
    Mock,
}

impl Substrate {
    pub const fn code(self) -> &'static str {
        match self {
            Substrate::Cpu => "cpu",
            Substrate::Gpu => "gpu",
            Substrate::Ane => "ane",
            Substrate::Mock => "mock",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SubstrateOutput {
    pub substrate: Substrate,
    pub output: Vec<f32>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PairwiseDivergence {
    pub a: Substrate,
    pub b: Substrate,
    pub max_abs_diff: f32,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SubstrateIndependenceReport {
    pub n_substrates: usize,
    pub max_divergence: f32,
    pub tolerance: f32,
    pub within_tolerance: bool,
    pub per_pair: Vec<PairwiseDivergence>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SubstrateError {
    EmptyOutputs,
    OutputLengthMismatch { a: Substrate, a_len: usize, b: Substrate, b_len: usize },
    NonPositiveTolerance { tol: f32 },
    DuplicateSubstrate { substrate: Substrate },
}

/// Compute the max-abs pairwise divergence across `N` substrate outputs.
/// Returns the report; caller checks `within_tolerance`.
pub fn check_substrate_independence(
    outputs: &[SubstrateOutput],
    tolerance: f32,
) -> Result<SubstrateIndependenceReport, SubstrateError> {
    if outputs.is_empty() {
        return Err(SubstrateError::EmptyOutputs);
    }
    if tolerance <= 0.0 {
        return Err(SubstrateError::NonPositiveTolerance { tol: tolerance });
    }
    let mut seen: std::collections::HashSet<Substrate> = Default::default();
    for o in outputs {
        if !seen.insert(o.substrate) {
            return Err(SubstrateError::DuplicateSubstrate { substrate: o.substrate });
        }
    }
    let first_len = outputs[0].output.len();
    for o in &outputs[1..] {
        if o.output.len() != first_len {
            return Err(SubstrateError::OutputLengthMismatch {
                a: outputs[0].substrate,
                a_len: first_len,
                b: o.substrate,
                b_len: o.output.len(),
            });
        }
    }
    let mut per_pair = Vec::new();
    let mut max_div: f32 = 0.0;
    for i in 0..outputs.len() {
        for j in (i + 1)..outputs.len() {
            let mut diff: f32 = 0.0;
            for k in 0..first_len {
                let d = (outputs[i].output[k] - outputs[j].output[k]).abs();
                if d > diff {
                    diff = d;
                }
            }
            per_pair.push(PairwiseDivergence {
                a: outputs[i].substrate,
                b: outputs[j].substrate,
                max_abs_diff: diff,
            });
            if diff > max_div {
                max_div = diff;
            }
        }
    }
    Ok(SubstrateIndependenceReport {
        n_substrates: outputs.len(),
        max_divergence: max_div,
        tolerance,
        within_tolerance: max_div <= tolerance,
        per_pair,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn out(s: Substrate, v: Vec<f32>) -> SubstrateOutput {
        SubstrateOutput { substrate: s, output: v }
    }

    #[test]
    fn four_substrates_distinct() {
        let set: std::collections::HashSet<_> =
            [Substrate::Cpu, Substrate::Gpu, Substrate::Ane, Substrate::Mock]
                .iter()
                .copied()
                .collect();
        assert_eq!(set.len(), 4);
    }

    #[test]
    fn substrate_codes_stable() {
        assert_eq!(Substrate::Cpu.code(), "cpu");
        assert_eq!(Substrate::Gpu.code(), "gpu");
        assert_eq!(Substrate::Ane.code(), "ane");
        assert_eq!(Substrate::Mock.code(), "mock");
    }

    #[test]
    fn empty_outputs_errors() {
        let err = check_substrate_independence(&[], 0.01).unwrap_err();
        assert_eq!(err, SubstrateError::EmptyOutputs);
    }

    #[test]
    fn non_positive_tolerance_rejected() {
        let outputs = vec![out(Substrate::Cpu, vec![1.0])];
        let err = check_substrate_independence(&outputs, 0.0).unwrap_err();
        assert_eq!(err, SubstrateError::NonPositiveTolerance { tol: 0.0 });
    }

    #[test]
    fn duplicate_substrate_rejected() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0]),
            out(Substrate::Cpu, vec![1.0]),
        ];
        let err = check_substrate_independence(&outputs, 0.01).unwrap_err();
        assert_eq!(err, SubstrateError::DuplicateSubstrate { substrate: Substrate::Cpu });
    }

    #[test]
    fn length_mismatch_errors() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0, 2.0]),
            out(Substrate::Gpu, vec![1.0]),
        ];
        let err = check_substrate_independence(&outputs, 0.01).unwrap_err();
        assert_eq!(
            err,
            SubstrateError::OutputLengthMismatch {
                a: Substrate::Cpu,
                a_len: 2,
                b: Substrate::Gpu,
                b_len: 1,
            }
        );
    }

    #[test]
    fn identical_outputs_yield_zero_divergence() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0, 2.0, 3.0]),
            out(Substrate::Gpu, vec![1.0, 2.0, 3.0]),
            out(Substrate::Ane, vec![1.0, 2.0, 3.0]),
        ];
        let r = check_substrate_independence(&outputs, 1e-6).unwrap();
        assert_eq!(r.max_divergence, 0.0);
        assert!(r.within_tolerance);
        assert_eq!(r.per_pair.len(), 3);
    }

    #[test]
    fn small_divergence_within_tolerance() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0_f32]),
            out(Substrate::Gpu, vec![1.0001_f32]),
        ];
        let r = check_substrate_independence(&outputs, 1e-3).unwrap();
        assert!(r.within_tolerance);
        assert!(r.max_divergence > 0.0);
    }

    #[test]
    fn large_divergence_exceeds_tolerance() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0_f32]),
            out(Substrate::Gpu, vec![5.0_f32]),
        ];
        let r = check_substrate_independence(&outputs, 1e-3).unwrap();
        assert!(!r.within_tolerance);
        assert!((r.max_divergence - 4.0).abs() < 1e-6);
    }

    #[test]
    fn per_pair_count_is_n_choose_2() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0]),
            out(Substrate::Gpu, vec![1.0]),
            out(Substrate::Ane, vec![1.0]),
            out(Substrate::Mock, vec![1.0]),
        ];
        let r = check_substrate_independence(&outputs, 1e-6).unwrap();
        assert_eq!(r.per_pair.len(), 6);
    }

    #[test]
    fn max_divergence_tracks_worst_pair() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0_f32]),
            out(Substrate::Gpu, vec![1.1_f32]),
            out(Substrate::Ane, vec![5.0_f32]),
        ];
        let r = check_substrate_independence(&outputs, 1e-3).unwrap();
        // Cpu vs Ane: 4.0; Gpu vs Ane: 3.9; Cpu vs Gpu: 0.1 → max = 4.0
        assert!((r.max_divergence - 4.0).abs() < 1e-6);
    }

    #[test]
    fn report_roundtrips_through_serde_json() {
        let outputs = vec![
            out(Substrate::Cpu, vec![1.0]),
            out(Substrate::Gpu, vec![1.0]),
        ];
        let r = check_substrate_independence(&outputs, 1e-6).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: SubstrateIndependenceReport = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn single_substrate_trivially_independent() {
        let outputs = vec![out(Substrate::Cpu, vec![1.0, 2.0, 3.0])];
        let r = check_substrate_independence(&outputs, 1e-6).unwrap();
        assert_eq!(r.n_substrates, 1);
        assert_eq!(r.max_divergence, 0.0);
        assert!(r.within_tolerance);
        assert_eq!(r.per_pair.len(), 0);
    }
}
