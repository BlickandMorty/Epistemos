//! Source:
//! - Lu/DeepONet arXiv:1910.03193 Thm 2 — operator universality.
//!   `G(u)(y) ≈ Σ_k branch_k(u) · trunk_k(y)`. The AST below
//!   captures the branch / trunk decomposition + the bilinear
//!   inner product.
//! - Li/FNO arXiv:2010.08895 §3 — Fourier-kernel lowering (FFT +
//!   spectral multiply + IFFT). [`KernelTransform::Fourier`]
//!   carries the modes count `m` so the trunk-side acts spectrally
//!   on the first `m` Fourier modes.
//! - Doctrine §4.4 — Operator-IR Rust crate-module shape.
//!
//! # Operator-IR typed AST
//!
//! Minimal MVP: each of `branch` and `trunk` is a single
//! [`LinearNetwork`] (one affine layer). DeepONet's universality
//! result requires multi-layer non-linear networks; iter-37 lays
//! the DeepONet baseline evaluator on top of single-layer affines
//! (sufficient to verify the bilinear-output structure) and
//! iter-38 adds the Fourier kernel.

use serde::{Deserialize, Serialize};

/// Single affine layer: `y = weights · x + biases`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LinearNetwork {
    /// `weights[i][j]` — i = output row, j = input column.
    pub weights: Vec<Vec<f64>>,
    /// `biases[i]` — i = output row.
    pub biases: Vec<f64>,
}

/// Construction-validation error for a [`LinearNetwork`].
#[derive(Clone, Debug, PartialEq)]
pub enum LinearNetworkError {
    NonRectangular { expected_cols: usize, actual_cols: usize, row: usize },
    BiasShapeMismatch { expected: usize, actual: usize },
    NonFiniteWeight { row: usize, col: usize, value: f64 },
    NonFiniteBias { row: usize, value: f64 },
    Empty,
}

impl LinearNetwork {
    /// Construct + validate.
    pub fn new(
        weights: Vec<Vec<f64>>,
        biases: Vec<f64>,
    ) -> Result<Self, LinearNetworkError> {
        if weights.is_empty() {
            return Err(LinearNetworkError::Empty);
        }
        if biases.len() != weights.len() {
            return Err(LinearNetworkError::BiasShapeMismatch {
                expected: weights.len(),
                actual: biases.len(),
            });
        }
        let expected_cols = weights[0].len();
        for (row_idx, row) in weights.iter().enumerate() {
            if row.len() != expected_cols {
                return Err(LinearNetworkError::NonRectangular {
                    expected_cols,
                    actual_cols: row.len(),
                    row: row_idx,
                });
            }
            for (col_idx, &w) in row.iter().enumerate() {
                if !w.is_finite() {
                    return Err(LinearNetworkError::NonFiniteWeight {
                        row: row_idx,
                        col: col_idx,
                        value: w,
                    });
                }
            }
        }
        for (row, &b) in biases.iter().enumerate() {
            if !b.is_finite() {
                return Err(LinearNetworkError::NonFiniteBias { row, value: b });
            }
        }
        Ok(LinearNetwork { weights, biases })
    }

    pub fn input_dim(&self) -> usize {
        self.weights[0].len()
    }
    pub fn output_dim(&self) -> usize {
        self.weights.len()
    }
}

/// Kernel transform applied on the trunk side. `Identity` is the
/// DeepONet baseline; `Fourier { modes }` is the FNO Fourier-kernel
/// lowering (iter-38).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum KernelTransform {
    Identity,
    Fourier { modes: usize },
}

impl KernelTransform {
    pub fn modes(&self) -> Option<usize> {
        match self {
            KernelTransform::Identity => None,
            KernelTransform::Fourier { modes } => Some(*modes),
        }
    }
}

/// Operator-IR expression. Branch / trunk decomposition with an
/// optional spectral kernel transform on the trunk side.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OperatorExpr {
    pub branch: LinearNetwork,
    pub trunk: LinearNetwork,
    pub kernel: KernelTransform,
}

/// Construction-validation error.
#[derive(Clone, Debug, PartialEq)]
pub enum OperatorExprError {
    /// Branch and trunk output dims must match (they form the
    /// inner-product sum in DeepONet's `G(u)(y) ≈ Σ_k branch_k(u)·
    /// trunk_k(y)`).
    OutputDimMismatch { branch_dim: usize, trunk_dim: usize },
    /// Fourier kernel `modes` must be ≤ trunk's output dim.
    FourierModesTooLarge { modes: usize, trunk_output_dim: usize },
    LinearNetwork(LinearNetworkError),
}

impl OperatorExpr {
    /// Construct + validate dimensional consistency.
    pub fn new(
        branch: LinearNetwork,
        trunk: LinearNetwork,
        kernel: KernelTransform,
    ) -> Result<Self, OperatorExprError> {
        if branch.output_dim() != trunk.output_dim() {
            return Err(OperatorExprError::OutputDimMismatch {
                branch_dim: branch.output_dim(),
                trunk_dim: trunk.output_dim(),
            });
        }
        if let KernelTransform::Fourier { modes } = &kernel {
            if *modes > trunk.output_dim() {
                return Err(OperatorExprError::FourierModesTooLarge {
                    modes: *modes,
                    trunk_output_dim: trunk.output_dim(),
                });
            }
        }
        Ok(OperatorExpr {
            branch,
            trunk,
            kernel,
        })
    }

    /// Common output dim of branch + trunk (the `p` in DeepONet
    /// `G(u)(y) ≈ Σ_{k=1}^p branch_k(u) · trunk_k(y)`).
    pub fn output_dim(&self) -> usize {
        self.branch.output_dim()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn linear_2_to_3() -> LinearNetwork {
        LinearNetwork::new(
            vec![
                vec![1.0, 0.0],
                vec![0.0, 1.0],
                vec![1.0, 1.0],
            ],
            vec![0.0, 0.0, 0.0],
        )
        .unwrap()
    }

    #[test]
    fn linear_network_new_validates_dims() {
        let l = linear_2_to_3();
        assert_eq!(l.input_dim(), 2);
        assert_eq!(l.output_dim(), 3);
    }

    #[test]
    fn linear_network_empty_rejected() {
        let err = LinearNetwork::new(vec![], vec![]).unwrap_err();
        assert_eq!(err, LinearNetworkError::Empty);
    }

    #[test]
    fn linear_network_bias_mismatch_rejected() {
        let err = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![]).unwrap_err();
        assert_eq!(
            err,
            LinearNetworkError::BiasShapeMismatch {
                expected: 1,
                actual: 0,
            }
        );
    }

    #[test]
    fn linear_network_non_rectangular_rejected() {
        let err = LinearNetwork::new(
            vec![vec![1.0, 0.0], vec![1.0]],
            vec![0.0, 0.0],
        )
        .unwrap_err();
        assert!(matches!(
            err,
            LinearNetworkError::NonRectangular { .. }
        ));
    }

    #[test]
    fn linear_network_non_finite_weight_rejected() {
        let err = LinearNetwork::new(vec![vec![f64::NAN]], vec![0.0]).unwrap_err();
        assert!(matches!(err, LinearNetworkError::NonFiniteWeight { .. }));
    }

    #[test]
    fn linear_network_non_finite_bias_rejected() {
        let err =
            LinearNetwork::new(vec![vec![1.0]], vec![f64::INFINITY]).unwrap_err();
        assert!(matches!(err, LinearNetworkError::NonFiniteBias { .. }));
    }

    #[test]
    fn kernel_transform_modes_getter() {
        assert_eq!(KernelTransform::Identity.modes(), None);
        assert_eq!(KernelTransform::Fourier { modes: 4 }.modes(), Some(4));
    }

    #[test]
    fn operator_new_validates_matching_output_dims() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap();
        assert_eq!(op.output_dim(), 3);
    }

    #[test]
    fn operator_rejects_mismatched_output_dims() {
        let branch = linear_2_to_3();
        let trunk = LinearNetwork::new(vec![vec![1.0, 0.0]], vec![0.0]).unwrap(); // out = 1
        let err =
            OperatorExpr::new(branch, trunk, KernelTransform::Identity).unwrap_err();
        assert_eq!(
            err,
            OperatorExprError::OutputDimMismatch {
                branch_dim: 3,
                trunk_dim: 1,
            }
        );
    }

    #[test]
    fn operator_rejects_fourier_modes_too_large() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let err = OperatorExpr::new(
            branch,
            trunk,
            KernelTransform::Fourier { modes: 5 },
        )
        .unwrap_err();
        assert!(matches!(
            err,
            OperatorExprError::FourierModesTooLarge { .. }
        ));
    }

    #[test]
    fn operator_accepts_fourier_modes_within_range() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(
            branch,
            trunk,
            KernelTransform::Fourier { modes: 2 },
        )
        .unwrap();
        assert_eq!(op.output_dim(), 3);
        assert_eq!(op.kernel.modes(), Some(2));
    }

    #[test]
    fn round_trips_through_serde_json() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(
            branch,
            trunk,
            KernelTransform::Fourier { modes: 2 },
        )
        .unwrap();
        let json = serde_json::to_string(&op).unwrap();
        let back: OperatorExpr = serde_json::from_str(&json).unwrap();
        assert_eq!(op, back);
    }

    #[test]
    fn output_dim_equals_branch_output_dim() {
        let branch = linear_2_to_3();
        let trunk = linear_2_to_3();
        let op = OperatorExpr::new(
            branch.clone(),
            trunk,
            KernelTransform::Identity,
        )
        .unwrap();
        assert_eq!(op.output_dim(), branch.output_dim());
    }
}
