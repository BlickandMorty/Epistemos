//! # Info-IR — exponential-family inference + Bregman geometry
//!
//! Source:
//! - Amari, "Information Geometry and Its Applications", Springer
//!   (2016), ISBN 978-4-431-55977-1. Ch. 2 (exponential families +
//!   dual coordinates) + Ch. 6 (Bregman divergences).
//! - Beck, Teboulle, "Mirror descent and nonlinear projected
//!   subgradient methods for convex optimization", Operations
//!   Research Letters 31:167-175 (2003). Mirror-descent ↔
//!   Bregman-projection equivalence.
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §2.5 + §4.5 — Info-IR primitive signature + lowering targets.
//! - Phase B3 close-out `docs/audits/PHASE_B3_CLOSEOUT_2026_05_17.md`
//!   §6 — iter-30 plan entry.
//!
//! ## T2 coordination
//!
//! Per driver-prompt COORDINATION: "T2 uses Info-IR for
//! AnswerPacket.confidence". Info-IR exports the typed
//! `KlProjection` primitive that T2 wires into the AnswerPacket
//! confidence-labeling code path. Phase B4 MVP delivers the typed
//! primitive + evaluator + Lean cert; T2's wiring lands when B4
//! closes.

//! ## Usage example
//!
//! Bernoulli log-partition, dual map (sigmoid), KL divergence, and a
//! single-step logistic-regression gradient step.
//!
//! ```
//! use agent_core::research::info_ir::{
//!     dual_map, kl_divergence, log_partition, logistic_regression_step, ExpFamily,
//! };
//!
//! // A(0) = ln(1 + exp(0)) = ln 2 ≈ 0.6931.
//! let a = log_partition(&ExpFamily::Bernoulli, &[0.0]);
//! assert!((a - 2.0_f64.ln()).abs() < 1e-12);
//!
//! // η(0) = sigmoid(0) = 0.5.
//! let eta = dual_map(&ExpFamily::Bernoulli, &[0.0]);
//! assert!((eta[0] - 0.5).abs() < 1e-12);
//!
//! // KL(p, p) = 0.
//! let kl = kl_divergence(&ExpFamily::Bernoulli, &[0.5], &[0.5]);
//! assert!(kl.abs() < 1e-12);
//!
//! // Logistic-regression step.
//! let theta = vec![0.0, 0.0];
//! let x = vec![1.0, 1.0];
//! let next = logistic_regression_step(&theta, &x, 1.0, 0.1);
//! // sigmoid(0) - 1 = -0.5; θ - 0.1 * -0.5 * 1 = 0.05 each.
//! assert!((next[0] - 0.05).abs() < 1e-12);
//! ```

pub mod certificate;
pub mod evaluator;
pub mod grammar;
pub mod mirror_descent;

pub use certificate::lean_certificate as info_lean_certificate;

pub use evaluator::{
    bayes_error_rate, bhattacharyya_coefficient, bhattacharyya_distance,
    binary_entropy, binary_jensen_shannon_divergence,
    binary_kl_divergence, binary_total_variation_distance,
    categorical_entropy_from_probs, chi_squared_divergence,
    chi_squared_from_probs, collision_entropy, cross_entropy,
    cross_entropy_from_probs,
    conditional_entropy, effective_sample_size_from_weights, entropy_diff,
    entropy_ratio, fano_inequality_rhs,
    is_valid_joint_distribution,
    gini_impurity, hellinger_squared_from_probs, is_valid_probability_vector,
    joint_entropy, js_distance, js_from_probs,
    kl_from_probs, kl_to_uniform, min_entropy, mode_index, mode_probability,
    normalized_entropy, perplexity, pinsker_kl_lower_bound,
    hill_number_from_probs,
    renyi_divergence_from_probs, renyi_entropy_from_probs,
    tsallis_entropy_from_probs,
    dual_map, entropy, evaluate_dual_map,
    evaluate_scalar, fisher_information, fisher_rao_distance, gaussian_kl_full,
    gaussian_log_pdf, gaussian_pdf, hellinger_distance, js_divergence,
    kl_divergence, log_partition, mutual_information,
    mean_to_natural, symmetric_kl, total_variation_distance,
    total_variation_from_probs, uniform_entropy, InfoEvalError,
};
pub use grammar::{ExpFamily, InfoExpr, InfoExprError};
pub use mirror_descent::{
    logistic_regression_step, logistic_regression_trajectory, mirror_descent_step,
};
