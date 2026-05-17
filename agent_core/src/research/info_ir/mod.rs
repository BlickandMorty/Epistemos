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

pub mod certificate;
pub mod evaluator;
pub mod grammar;
pub mod mirror_descent;

pub use certificate::lean_certificate as info_lean_certificate;

pub use evaluator::{
    dual_map, evaluate_dual_map, evaluate_scalar, kl_divergence, log_partition,
    InfoEvalError,
};
pub use grammar::{ExpFamily, InfoExpr, InfoExprError};
pub use mirror_descent::{
    logistic_regression_step, logistic_regression_trajectory, mirror_descent_step,
};
