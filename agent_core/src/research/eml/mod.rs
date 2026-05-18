//! Source:
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` §1.1 +
//!   §"Terminal B" Phase B.0 — THE Monday deliverable per Foundation
//!   Doc Part X. **AnswerPacket schema does NOT ship until F-ULP-Oracle
//!   passes.** No claim envelope without a verified arithmetic floor.
//! - Odrzywołek, "Liouvillian-elementary universality of `eml(x,y) =
//!   exp(x) − ln(y)`", arXiv:2603.21852 — universality proof on the
//!   Liouvillian-solvable subdomain.
//! - Stachowiak, "Abelian-group + functional-inverse decomposition for
//!   EML", arXiv:2604.23893 — structural decomposition.
//! - Carney, "Inexpressibility in Exp-Minus-Log", arXiv:2605.01636 —
//!   universality fence: every EML-expressible number is computable,
//!   so Chaitin's Ω_U is inexpressible. Companion to the Smith
//!   quintic counter-construction below (algebraic-side fence) on the
//!   computability side. T5 Phase B1 iter-9 closure of the open
//!   citation gap flagged at the iter-1 audit §6 item 7.
//!
//! # Wave J Phase B.0 — F-ULP-Oracle substrate (the Monday priority)
//!
//! Six sub-tasks per V6.1 integration §"Terminal B" B.0.x. Iter 35
//! lands the in-tree pieces (B.0.3 partial — Metal stub; B.0.4 —
//! ULP fixture harness). Three sub-tasks require operations outside
//! the autonomous-loop scope (network fetch + Lean toolchain + git
//! submodule add) and are deferred to user / a manual setup pass:
//!
//! - **B.0.1 (deferred)**: Vendor `cool-japan/oxieml` (MIT) into
//!   `epikernel-eml-ir/` as path-dep submodule, read-only. Needs
//!   `git submodule add` + network access.
//! - **B.0.2 (deferred)**: Vendor `tomdif/eml-lean` (claims 0-sorry)
//!   into `epikernel-lean/vendored/`. Verify via `lake build` + grep.
//!   Needs Lean 4 toolchain + network.
//! - **B.0.3 (substrate floor — this iter)**: `morph_eval_reduced.metal
//!   v0.1` lands in `Epistemos/Shaders/`. Only `exp`, `ln`, and the
//!   fused intrinsic `eml(x, y) = exp(x) − ln(y)` are implemented.
//! - **B.0.4 (substrate floor — this iter)**: ULP fixture harness in
//!   [`ulp_oracle`]. Production-scale 412k log-sampled + 2048 stress
//!   points runs separately; the substrate-floor harness exposes the
//!   structure + a small 1024-point smoke run so the path is wired.
//! - **B.0.5 (deferred)**: Lean toolchain pin verification against
//!   `leanprover-community.github.io/mathlib4`. Current public Lean is
//!   4.25.0 (2025-11-14); locked stack 4.29.1 needs verification.
//! - **B.0.6 (GATE)**: AnswerPacket schema freeze blocked until B.0.4
//!   passes. Substrate floor here lands the gate flag + the check
//!   that future schema-freeze logic must call before declaring
//!   AnswerPacket frozen. The actual schema definition lives outside
//!   this module.
//!
//! ## Hard fence (per §1.2)
//!
//! EML universality is over the Liouvillian-solvable subdomain ONLY.
//! Smith's quintic counter-construction bounds every "EML for
//! everything" claim. Every EML publication MUST state this.
//!
//! ## Usage example
//!
//! Typical EML-IR pipeline: build an [`EmlExpr`] tree, lift into the
//! [`BranchedEmlExpr`] typestate, runtime-validate positivity, then
//! evaluate or emit a Lean certificate.
//!
//! ```
//! use agent_core::research::eml::{
//!     evaluate, lean_certificate, BranchedEmlExpr, EmlExpr, PositiveEmlExpr,
//! };
//!
//! // 1. Build a bare tree: eml(1, 1) = exp(1) - ln(1) = e
//! let tree = EmlExpr::eml(EmlExpr::One, EmlExpr::One);
//!
//! // 2. Evaluate via the bare evaluator.
//! let value = evaluate(&tree).unwrap();
//! assert!((value - std::f64::consts::E).abs() < 1e-12);
//!
//! // 3. Lift through the branch-safe typestate.
//! let branched = BranchedEmlExpr::eml(
//!     BranchedEmlExpr::one(),
//!     PositiveEmlExpr::one(),
//! );
//! let positive = branched.try_into_positive().unwrap();
//! assert_eq!(positive.value(), value);
//!
//! // 4. Emit a Lean 4 certificate (sorry-stubbed proof body; Phase C typechecks).
//! let cert = lean_certificate(&positive);
//! assert!(cert.contains("eml_branch_safe_"));
//! assert!(cert.contains("Real.exp"));
//! ```
//!
//! See also `agent_core/tests/eml_ir_corpus_round_trip.rs` for the
//! 100-fn elementary corpus with ≥ 80% round-trip closure (§4.I:906
//! acceptance), and `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//! for the doctrine.

pub mod branched;
pub mod certificate;
pub mod closure;
pub mod closure_builders;
pub mod evaluator;
pub mod gate;
pub mod grammar;
pub mod normalize;
pub mod operator;
pub mod ulp_oracle;

pub use branched::{BranchValidationError, BranchedEmlExpr, PositiveEmlExpr};
pub use certificate::{lean_certificate, lean_expr_term, lean_term};
pub use closure::{EmlClosure, EmlClosureError, EmlClosureExpr};
pub use closure_builders::{
    closure_bernoulli_log_prob_one, closure_bernoulli_log_prob_zero,
    closure_categorical_cross_entropy, closure_categorical_kl_from_probs,
    closure_categorical_log_partition, closure_categorical_log_prob_pinned,
    closure_softmax_cross_entropy_from_logits,
    closure_categorical_log_prob_slot, closure_categorical_softmax_pinned,
    closure_softplus_of,
    closure_categorical_softmax_slot,
    closure_cross_entropy_bernoulli, closure_cross_entropy_bernoulli_of,
    closure_entropy_bernoulli, closure_entropy_categorical, closure_exp,
    closure_gaussian_dual_map, closure_gaussian_log_likelihood,
    closure_gaussian_log_partition,
    closure_bernoulli_kl_from_probs, closure_chi_squared_bernoulli,
    closure_kl_bernoulli,
    closure_exponential_jeffreys_divergence,
    closure_kl_categorical, closure_kl_exponential, closure_kl_gaussian,
    closure_kl_normal_full, closure_kl_normal_zero_mean,
    closure_kl_geometric, closure_kl_poisson, closure_kl_uniform, closure_ln,
    closure_poisson_jeffreys_divergence,
    closure_glu, closure_inverse, closure_inverse_temperature_scaling,
    closure_lse, closure_mish, closure_mul, closure_neg, closure_neg_exp,
    closure_reglu,
    closure_neg_log_likelihood_categorical_pinned,
    closure_neg_log_likelihood_categorical_slot, closure_neg_slot,
    closure_complementary_sigmoid, closure_complementary_sigmoid_of,
    closure_sigmoid, closure_sigmoid_of,
    closure_abs, closure_affine, closure_attention_score, closure_center,
    closure_cosine_similarity, closure_dice_coefficient, closure_dice_loss,
    closure_dot_product, closure_exp_of,
    closure_adam_step, closure_arithmetic_mean, closure_bias_corrected_ema,
    closure_binary_cross_entropy_from_probs,
    closure_geometric_mean, closure_harmonic_mean,
    closure_log_addexp, closure_log_addexp_of,
    closure_log_cosh, closure_log_cosh_of,
    closure_log_sigmoid, closure_log_sigmoid_complement,
    closure_log_sigmoid_of,
    closure_logistic_loss,
    closure_complement_prob, closure_cube, closure_diff_squared,
    closure_log_ratio, closure_odds, closure_one_hot_select,
    closure_step_size_decay,
    closure_exponential_log_likelihood, closure_geometric_log_likelihood,
    closure_laplace_kl_same_scale, closure_laplace_log_likelihood,
    closure_pareto_jeffreys_same_x_min,
    closure_pareto_kl_same_x_min, closure_pareto_log_likelihood,
    closure_poisson_log_likelihood, closure_polynomial, closure_polynomial_of,
    closure_uniform_log_likelihood,
    closure_product_slots,
    closure_scaled_squared_distance, closure_sum_slots,
    closure_weighted_mse_loss,
    closure_gelu_sigmoid_approx, closure_l1_distance, closure_l1_norm,
    closure_l2_norm_squared,
    closure_l2_penalty,
    closure_linear_form, closure_mse_loss,
    closure_squared_cosine_similarity, closure_squared_error,
    closure_squared_error_of,
    closure_layer_norm, closure_logit, closure_rbf_kernel,
    closure_residual_add, closure_sigmoid_scaled, closure_squared_distance,
    closure_silu, closure_smooth_max, closure_smooth_min, closure_softplus_scaled,
    closure_softmax_temperature_pinned, closure_softmax_temperature_slot,
    closure_standardize,
    closure_smooth_relu, closure_softplus, closure_softplus_inverse,
    closure_sqrt_of, closure_squared, closure_squared_of, closure_swiglu,
    closure_swish,
    closure_swish_scaled, closure_tanh, closure_tanh_of, closure_zero,
};
pub use evaluator::{evaluate, EmlEvalError, MAX_EVAL_DEPTH};
pub use gate::{check_answer_packet_freeze_allowed, GateError, GateStatus};
pub use grammar::{eml_grammar_root, EmlExpr};
pub use normalize::{
    evaluate_closure, is_normalized_closure, is_normalized_expr, normalize_closure,
    normalize_expr, NormalizeError,
};
pub use operator::{eml, EmlError};
pub use ulp_oracle::{
    run_smoke_oracle, UlpOracleError, UlpOracleReport, UlpToleranceFp16, SMOKE_SAMPLE_COUNT,
};
