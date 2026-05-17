//! # Operator-IR — neural-operator substrate (DeepONet + FNO)
//!
//! Source:
//! - Lu, Jin, Karniadakis, "Learning nonlinear operators via DeepONet
//!   based on the universal approximation theorem of operators",
//!   arXiv:1910.03193 (Nat. Mach. Intell. 2021). Thm 2 universality.
//! - Li, Kovachki, Azizzadenesheli, Liu, Bhattacharya, Stuart,
//!   Anandkumar, "Fourier Neural Operator for Parametric Partial
//!   Differential Equations", arXiv:2010.08895 (ICLR 2021). §3 the
//!   Fourier-kernel lowering.
//! - Doctrine §2.4 + §4.4 — Operator-IR primitive signature + crate-
//!   module shape.
//! - Phase B4 close-out `docs/audits/PHASE_B4_CLOSEOUT_2026_05_17.md`
//!   §6 — iter-36 plan entry.

//! ## Usage example
//!
//! Build a small Operator-IR with Identity and Fourier kernels;
//! evaluate at a single (branch, trunk) point.
//!
//! ```
//! use agent_core::research::operator_ir::{
//!     evaluate_operator_at, KernelTransform, LinearNetwork, OperatorExpr,
//! };
//!
//! // 2-in × 3-out branch and trunk; dim consistency enforced by `new`.
//! let net = LinearNetwork::new(
//!     vec![vec![1.0, 0.0], vec![0.0, 1.0], vec![1.0, 1.0]],
//!     vec![0.0, 0.0, 0.0],
//! ).unwrap();
//!
//! let op = OperatorExpr::new(
//!     net.clone(), net, KernelTransform::Identity,
//! ).unwrap();
//!
//! // branch([2, 3]) = [2, 3, 5]; trunk([4, 1]) = [4, 1, 5];
//! // dot product = 2*4 + 3*1 + 5*5 = 36.
//! let v = evaluate_operator_at(&op, &[2.0, 3.0], &[4.0, 1.0]).unwrap();
//! assert_eq!(v, 36.0);
//! ```

pub mod certificate;
pub mod evaluator;
pub mod fourier_kernel;
pub mod grammar;

pub use certificate::lean_certificate as operator_lean_certificate;
pub use evaluator::{
    apply_dropout, apply_layer_norm, apply_linear_sequence,
    apply_linear_sequence_with_activation, apply_residual_mlp_block,
    apply_softmax, compose_linear_layers, evaluate_linear, evaluate_operator_at,
    evaluate_with_residual, transpose_linear_layer, OperatorEvalError,
};
pub use fourier_kernel::{dft, fno_spectral_block, idft_real};
pub use grammar::{
    KernelTransform, LinearNetwork, LinearNetworkError, OperatorExpr,
    OperatorExprError,
};
