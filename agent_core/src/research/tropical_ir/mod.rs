//! # Tropical-IR module — driver-prompt SCOPE LOCK path
//!
//! Phase B2 lands the typed-AST + normal-form + lowering split per
//! doctrine §2.2 and §4.2. **Iter-17 minimum: this directory module
//! exists, re-exports the substrate-floor public surface from the
//! pre-existing flat `super::tropical`, and satisfies the driver-
//! prompt SCOPE LOCK requirement for `agent_core/src/research/
//! tropical_ir/`.**
//!
//! ## Why the reverse shim (vs the iter-6 plan's forward shim)
//!
//! The iter-6 reconciliation plan
//! (`docs/audits/TROPICAL_IR_RECONCILIATION_PLAN_2026_05_17.md` §3)
//! called for moving the flat 594-LOC `tropical.rs` content into
//! 4 split files under `tropical_ir/` and leaving a thin re-export
//! shim at the flat location. Iter-17 inverts: keep the flat file
//! intact, ship a thin `pub use super::tropical::*;` shim from the
//! new directory module.
//!
//! Reasons:
//! 1. **Disk pressure.** /Users/jojo/Downloads/ is at ~100% capacity.
//!    Renaming + splitting forces a full cargo rebuild (~2 min,
//!    incremental disk usage). The reverse shim is a touch-1-file
//!    addition.
//! 2. **Functional equivalence.** Both paths
//!    `crate::research::tropical::TropicalPolynomial` and
//!    `crate::research::tropical_ir::TropicalPolynomial` resolve to
//!    the same type via re-export. Rust handles this without name
//!    conflict.
//! 3. **The granular split** (Phase B2 acceptance bar requires
//!    `grammar.rs` / `operator.rs` / `compile.rs`) **lands at
//!    iter-18+** when the typed-AST extension (TropicalExpr,
//!    TropicalRational) goes into the new file. At that point the
//!    re-export shim flips direction back to the iter-6 plan form.
//!
//! ## Source-citation chain
//!
//! Inherits from `super::tropical` head-comment (lines 1-10):
//! Zhang/Naitzat/Lim arXiv:1805.07091 (Thm 5.4) + Maclagan/Sturmfels
//! GSM 161 (2015) + V6.1 §"Terminal B" Phase B.6.15.

//! ## Usage example
//!
//! Compile a binary-weight ReLU layer to TropicalExpr trees,
//! evaluate, and verify byte-equality against a direct ReLU oracle.
//!
//! ```
//! use agent_core::research::tropical_ir::{
//!     compile_relu_layer, evaluate, evaluate_relu_layer_directly,
//!     BinaryReluLayer,
//! };
//!
//! // Single-output ReLU layer: y = max(0, x_0 + x_1 + 0.5).
//! let layer = BinaryReluLayer::new(vec![vec![1, 1]], vec![0.5]).unwrap();
//! let trees = compile_relu_layer(&layer);
//!
//! // Compiled output bit-equal to direct evaluator.
//! let x = vec![1.0, -0.25];
//! let direct = evaluate_relu_layer_directly(&layer, &x);
//! let compiled = evaluate(&trees[0], &x).unwrap();
//! assert_eq!(direct[0].to_bits(), compiled.to_bits());
//! assert!((direct[0] - 1.25).abs() < 1e-12);
//! ```

pub mod certificate;
pub mod compile;
pub mod evaluator;
pub mod grammar;

pub use certificate::{
    lean_certificate as tropical_lean_certificate,
    lean_certificate_rational as tropical_lean_certificate_rational,
    lean_term as tropical_lean_term,
};
pub use compile::{
    compile_max_pool, compile_min_pool, compile_real_relu_layer,
    compile_relu_layer, evaluate_max_pool_directly, evaluate_min_pool_directly,
    evaluate_real_relu_layer_directly, evaluate_relu_layer_directly,
    BinaryReluLayer, BinaryReluLayerError, RealReluLayer, RealReluLayerError,
};
pub use evaluator::{
    compile_tropical_polynomial, evaluate, evaluate_rational, min_plus_convolution,
    min_plus_inner_product, min_plus_matrix_col_min, min_plus_matrix_min_fold,
    min_plus_matrix_min_pointwise, min_plus_matrix_multiply,
    min_plus_matrix_row_min, min_plus_matrix_vector,
    min_plus_pairwise_min,
    min_plus_vector_argmin_value, min_plus_vector_min,
    min_plus_vector_scalar_min,
    min_plus_zero, tropical_argmax_idx, tropical_argmin_idx, tropical_convolution,
    tropical_chebyshev_distance, tropical_smooth_chebyshev_distance,
    tropical_constant_matrix, tropical_diagonal_matrix, tropical_distance_matrix,
    tropical_l1_distance,
    tropical_matrix_diagonal,
    tropical_eigenvalue_estimate, tropical_identity_matrix,
    tropical_identity_matrix_scaled,
    tropical_inner_product, tropical_matrix_max_fold,
    tropical_matrix_max_pointwise, tropical_matrix_multiply, tropical_matrix_power,
    tropical_matrix_col_max, tropical_matrix_kleene_partial,
    tropical_matrix_negate, tropical_matrix_row_max, tropical_matrix_scalar_add,
    tropical_min_polynomial, tropical_min_polynomial_argmin_at,
    tropical_min_polynomial_argmin_value_at,
    tropical_matrix_trace, tropical_matrix_transpose, tropical_matrix_vector,
    tropical_vector_amplitude,
    tropical_vector_argmax_value, tropical_vector_argmin_argmax_indices,
    tropical_vector_max, tropical_vector_min_max_pair,
    tropical_vector_negate, tropical_vector_pairwise_add,
    tropical_vector_recenter, tropical_vector_scalar_add,
    tropical_vector_scalar_max,
    tropical_norm_max, tropical_pairwise_max,
    tropical_smooth_amplitude, tropical_smooth_inner_product,
    tropical_smooth_max, tropical_smooth_min,
    tropical_log_softmax, tropical_log_softmin,
    tropical_softmax, tropical_softmax_cross_entropy,
    tropical_softmax_entropy, tropical_softmax_kl_divergence,
    tropical_softmin, tropical_softmin_entropy,
    tropical_norm_min, tropical_one,
    tropical_outer_sum, tropical_polynomial, tropical_polynomial_argmax_at,
    tropical_polynomial_argmax_value_at,
    tropical_smooth_min_polynomial, tropical_smooth_polynomial,
    tropical_zero,
    tropical_zero_matrix, TropicalEvalError,
};
pub use grammar::{TropicalExpr, TropicalRational};
pub use super::tropical::*;
