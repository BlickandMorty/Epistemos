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
pub use certificate::{lean_certificate, lean_term};
pub use closure::{EmlClosure, EmlClosureError, EmlClosureExpr};
pub use closure_builders::{
    closure_categorical_log_partition, closure_categorical_softmax_pinned,
    closure_categorical_softmax_slot, closure_exp, closure_kl_bernoulli, closure_ln,
    closure_lse, closure_mul, closure_neg_exp, closure_neg_slot, closure_sigmoid,
    closure_softplus, closure_tanh, closure_zero,
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
