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

pub mod certificate;
pub mod evaluator;
pub mod fourier_kernel;
pub mod grammar;

pub use certificate::lean_certificate as operator_lean_certificate;
pub use evaluator::{evaluate_linear, evaluate_operator_at, OperatorEvalError};
pub use fourier_kernel::{dft, fno_spectral_block, idft_real};
pub use grammar::{
    KernelTransform, LinearNetwork, LinearNetworkError, OperatorExpr,
    OperatorExprError,
};
