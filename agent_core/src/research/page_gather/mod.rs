//! Page-Gather + Shadow-first paging substrate-floor.
//!
//! Source:
//! - Driver §4.G hierarchy: Shadow-first paging = "SENSORY FILTER —
//!   sketch → residual → exact escalation; INT8 sketch dot-product on
//!   Metal for cheap routing."
//! - F-ShadowFirst-PageEscalation falsifier `docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md`
//!   §2 (HeliosPage three-stage shape) + §3 (escalation policy + KL drift
//!   ≤ 0.06 acceptance).
//! - F-PageGather-M2Pro falsifier `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md`
//!   §2 (Metal kernel scatter/gather; ≥ 70% MEASURED M2 Pro STREAM).
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.4 (B.G.B4 F-ShadowFirst harness) + §2.5 (B.G.B5 F-PageGather
//!   Metal kernel).
//!
//! # Phase B.G.B4 substrate scope
//!
//! Lands the HeliosPage three-stage type surface (iter 43) +
//! sketch-topk + residual-rescore + escalation-policy (iters 44-45) +
//! synthetic-corpus integration harness (iter 46).
//!
//! Production (B.G.B5 / Phase C):
//! - Metal kernel for scatter/gather at 256/512/1024 MB working sets.
//! - IOSurface integration for UMA-shared buffers.
//! - SSD mmap for exact-page reads.
//!
//! Substrate-floor (this module):
//! - CPU-only scalar reference.
//! - In-memory backing for all three tiers (sketch / residual / exact).

pub mod escalation_policy;
pub mod helios_page;
pub mod residual_rescore;
pub mod sketch_topk;

pub use escalation_policy::{
    EscalationError, EscalationPolicy, EscalationThresholds, EscalationVerdict,
};
pub use helios_page::{
    ExactCodec, ExactPageHandle, HeliosPage, HeliosPageError, ResidualBlock,
};
pub use residual_rescore::{residual_rescore, ResidualRescoreError};
pub use sketch_topk::{int8_inner_product, sketch_top_k, SketchTopKError};
