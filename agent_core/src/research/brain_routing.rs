//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.5 — Sinkhorn-projected routing matrix
//!   `B* ∈ Birkhoff_n` + Brain(τ) reconstruction rule + 4 product modes.
//! - Sinkhorn, R., "A Relationship Between Arbitrary Positive Matrices
//!   and Doubly Stochastic Matrices", Ann. Math. Stat. 35(2), 1964 —
//!   canonical alternating-normalization theorem.
//! - Cuturi, M., "Sinkhorn Distances: Lightspeed Computation of
//!   Optimal Transport", NeurIPS 2013, arXiv:1306.0895 — the
//!   entropy-regularized OT formulation the routing layer uses.
//! - Birkhoff, G., "Three Observations on Linear Algebra", Univ. Nac.
//!   Tucumán Rev. 5, 1946 — the doubly-stochastic / permutation
//!   matrix correspondence (Birkhoff polytope).
//!
//! # Wave J B.6.5 — Brain(τ) routing substrate
//!
//! The routing layer ships two primitives:
//!
//! 1. [`sinkhorn_project`] — given a positive `n × n` matrix, project
//!    onto the Birkhoff polytope (doubly stochastic matrices: all row
//!    sums and column sums = 1). Uses Sinkhorn-Knopp alternating
//!    row/column normalization until row and column sums converge to
//!    within tolerance.
//! 2. [`ProductMode`] — the 4-mode taxonomy:
//!    - VRM (Variable-Rate Memory) — canon-doctrine.
//!    - Observatory — partial / introspection-only.
//!    - Brain Time Machine — NOT-STARTED, time-travel replay.
//!    - Harness Evolution — substrate-evolution mode.
//!
//! The Brain(τ) reconstruction rule (materialized checkpoint +
//! semantic deltas → reconstructed Brain at time τ) is the next
//! layer up; substrate floor here owns just the routing + product-mode
//! enum that reconstruction consumes.

use serde::{Deserialize, Serialize};

/// 4 product modes per driver §5 Phase B.6.5.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ProductMode {
    /// Variable-Rate Memory — canon-doctrine mode.
    Vrm,
    /// Observatory — partial / introspection-only mode.
    Observatory,
    /// Brain Time Machine — NOT-STARTED.
    BrainTimeMachine,
    /// Harness Evolution — substrate-evolution mode.
    HarnessEvolution,
}

impl ProductMode {
    pub const ALL: [ProductMode; 4] = [
        ProductMode::Vrm,
        ProductMode::Observatory,
        ProductMode::BrainTimeMachine,
        ProductMode::HarnessEvolution,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            ProductMode::Vrm => "vrm",
            ProductMode::Observatory => "observatory",
            ProductMode::BrainTimeMachine => "brain_time_machine",
            ProductMode::HarnessEvolution => "harness_evolution",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SinkhornError {
    NotSquare { rows: usize, cols: usize },
    EmptyMatrix,
    NonPositiveEntry { row: usize, col: usize, value: f32 },
    NonPositiveTolerance { tol: f32 },
    NotConverged { max_iter: usize, final_residual: f32 },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SinkhornResult {
    pub doubly_stochastic: Vec<Vec<f32>>,
    pub iterations: usize,
    pub final_residual: f32,
}

/// Project an `n × n` positive matrix onto the Birkhoff polytope via
/// Sinkhorn-Knopp alternating row/column normalization. Returns the
/// doubly stochastic projection + iteration count + final residual
/// (max deviation of any row or column sum from 1).
///
/// `max_iter` and `tolerance` control the alternating-normalization
/// loop. Typical values: 100 iterations + tolerance 1e-6 converge for
/// well-conditioned positive matrices.
pub fn sinkhorn_project(
    matrix: &[Vec<f32>],
    max_iter: usize,
    tolerance: f32,
) -> Result<SinkhornResult, SinkhornError> {
    let n = matrix.len();
    if n == 0 {
        return Err(SinkhornError::EmptyMatrix);
    }
    for (i, row) in matrix.iter().enumerate() {
        if row.len() != n {
            return Err(SinkhornError::NotSquare { rows: n, cols: row.len() });
        }
        for (j, &v) in row.iter().enumerate() {
            if v <= 0.0 {
                return Err(SinkhornError::NonPositiveEntry { row: i, col: j, value: v });
            }
        }
    }
    if tolerance <= 0.0 {
        return Err(SinkhornError::NonPositiveTolerance { tol: tolerance });
    }

    let mut m: Vec<Vec<f32>> = matrix.iter().map(|r| r.clone()).collect();
    let mut residual = f32::INFINITY;
    let mut iter_count = 0;

    for it in 0..max_iter {
        for r in 0..n {
            let s: f32 = m[r].iter().sum();
            for c in 0..n {
                m[r][c] /= s;
            }
        }
        for c in 0..n {
            let s: f32 = (0..n).map(|r| m[r][c]).sum();
            for r in 0..n {
                m[r][c] /= s;
            }
        }
        let mut max_dev: f32 = 0.0;
        for r in 0..n {
            let s: f32 = m[r].iter().sum();
            let dev = (s - 1.0).abs();
            if dev > max_dev {
                max_dev = dev;
            }
        }
        for c in 0..n {
            let s: f32 = (0..n).map(|r| m[r][c]).sum();
            let dev = (s - 1.0).abs();
            if dev > max_dev {
                max_dev = dev;
            }
        }
        residual = max_dev;
        iter_count = it + 1;
        if residual < tolerance {
            return Ok(SinkhornResult {
                doubly_stochastic: m,
                iterations: iter_count,
                final_residual: residual,
            });
        }
    }
    Err(SinkhornError::NotConverged {
        max_iter,
        final_residual: residual,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn four_distinct_product_modes() {
        let s: std::collections::HashSet<_> = ProductMode::ALL.iter().copied().collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn product_mode_codes_are_stable() {
        assert_eq!(ProductMode::Vrm.code(), "vrm");
        assert_eq!(ProductMode::Observatory.code(), "observatory");
        assert_eq!(ProductMode::BrainTimeMachine.code(), "brain_time_machine");
        assert_eq!(ProductMode::HarnessEvolution.code(), "harness_evolution");
    }

    #[test]
    fn empty_matrix_errors() {
        let err = sinkhorn_project(&[], 100, 1e-6).unwrap_err();
        assert_eq!(err, SinkhornError::EmptyMatrix);
    }

    #[test]
    fn non_square_errors() {
        let m = vec![vec![1.0_f32, 2.0], vec![3.0]];
        let err = sinkhorn_project(&m, 100, 1e-6).unwrap_err();
        assert_eq!(err, SinkhornError::NotSquare { rows: 2, cols: 1 });
    }

    #[test]
    fn non_positive_entry_errors() {
        let m = vec![vec![1.0_f32, 0.0], vec![1.0, 1.0]];
        let err = sinkhorn_project(&m, 100, 1e-6).unwrap_err();
        assert_eq!(
            err,
            SinkhornError::NonPositiveEntry { row: 0, col: 1, value: 0.0 }
        );
    }

    #[test]
    fn non_positive_tolerance_errors() {
        let m = vec![vec![1.0_f32, 1.0], vec![1.0, 1.0]];
        let err = sinkhorn_project(&m, 100, 0.0).unwrap_err();
        assert_eq!(err, SinkhornError::NonPositiveTolerance { tol: 0.0 });
    }

    #[test]
    fn uniform_matrix_already_doubly_stochastic_when_normalized() {
        // n=2, all entries = 1; after row-norm each row sums to 1
        // (entries 0.5); after col-norm each col already sums to 1.
        let m = vec![vec![1.0_f32, 1.0], vec![1.0, 1.0]];
        let r = sinkhorn_project(&m, 100, 1e-6).unwrap();
        for row in &r.doubly_stochastic {
            assert!(approx(row.iter().sum::<f32>(), 1.0, 1e-6));
        }
        for c in 0..2 {
            let col_sum: f32 = (0..2).map(|i| r.doubly_stochastic[i][c]).sum();
            assert!(approx(col_sum, 1.0, 1e-6));
        }
    }

    #[test]
    fn skewed_matrix_converges_to_doubly_stochastic() {
        let m = vec![
            vec![5.0_f32, 1.0, 1.0],
            vec![1.0, 5.0, 1.0],
            vec![1.0, 1.0, 5.0],
        ];
        let r = sinkhorn_project(&m, 200, 1e-6).unwrap();
        for row in &r.doubly_stochastic {
            assert!(approx(row.iter().sum::<f32>(), 1.0, 1e-5));
        }
        for c in 0..3 {
            let col_sum: f32 = (0..3).map(|i| r.doubly_stochastic[i][c]).sum();
            assert!(approx(col_sum, 1.0, 1e-5));
        }
        assert!(r.final_residual < 1e-5);
    }

    #[test]
    fn iteration_count_finite_and_below_max() {
        let m = vec![vec![1.0_f32, 1.0], vec![1.0, 1.0]];
        let r = sinkhorn_project(&m, 100, 1e-6).unwrap();
        assert!(r.iterations > 0);
        assert!(r.iterations <= 100);
    }

    #[test]
    fn result_roundtrips_through_serde_json() {
        let m = vec![vec![1.0_f32, 1.0], vec![1.0, 1.0]];
        let r = sinkhorn_project(&m, 100, 1e-6).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: SinkhornResult = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn one_by_one_identity_converges_immediately() {
        let m = vec![vec![7.0_f32]];
        let r = sinkhorn_project(&m, 10, 1e-6).unwrap();
        assert!(approx(r.doubly_stochastic[0][0], 1.0, 1e-6));
    }

    #[test]
    fn product_mode_serializes_through_serde_json() {
        let p = ProductMode::Vrm;
        let json = serde_json::to_string(&p).unwrap();
        let back: ProductMode = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn permutation_matrix_is_already_doubly_stochastic() {
        // Permutation has one 1 per row/col; sinkhorn should preserve.
        // Use small positive ε to satisfy positivity check.
        let eps = 1e-6_f32;
        let m = vec![
            vec![1.0 - eps, eps],
            vec![eps, 1.0 - eps],
        ];
        let r = sinkhorn_project(&m, 100, 1e-6).unwrap();
        // After Sinkhorn it stays near the original perm.
        assert!(r.doubly_stochastic[0][0] > 0.95);
        assert!(r.doubly_stochastic[1][1] > 0.95);
    }
}
