//! Source:
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.26 (KV implantation +
//!   Glass Pipe + weight surgery) + §3.36 (SAE Cognition Observatory — AUC 0.90).
//! - `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`
//!   — KVCacheImplanter / WeightPatcher / ActivationInterceptor primary spec.
//! - `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md`
//!   — ANE honesty boundaries (cannot see SRAM / per-core / instruction trace).
//!
//! # Wave J2 — Cognition Observatory + KV implantation lane
//!
//! Four sub-features per §3.26 + §3.36, all NOT-STARTED at session start:
//!
//! 1. **KV implantation** ([`kv_implant`]) — KVCacheImplanter / KvCacheSnapshot /
//!    LayerKVSnapshot. Direct memory inspection + targeted restore.
//! 2. **Glass Pipe** ([`glass_pipe`]) — ActivationInterceptor, injected Metal
//!    compute kernel + ring buffer + atomic write index. (NOT-STARTED here.)
//! 3. **Weight Surgery** ([`weight_patcher`]) — qProj/kProj/vProj/oProj/gate/
//!    up/down/embed/lmHead targeted patching. (NOT-STARTED here.)
//! 4. **SAE Cognition Observatory** ([`sae`]) — sparse-autoencoder feature
//!    monitoring on residual stream, AUC 0.90 hallucination-detection bar.
//!    (NOT-STARTED here.)
//!
//! ## Doctrine pin (per §3.36)
//!
//! "Doctrine acceptance bar: AUC 0.90 on a held-out factual subset. This is
//! the pin that distinguishes the SAE Cognition Observatory from generic
//! 'SAE name-drop' — the row only counts as shipped when an SAE actually
//! achieves AUC ≥ 0.90 on a vault-domain validation set. Below 0.90 =
//! research, not gate."
//!
//! Substrate floor in this iteration: KV implantation only. Sub-features
//! 2-4 land in subsequent J2 iters.

pub mod glass_pipe;
pub mod kv_implant;
pub mod sae;
pub mod weight_patcher;

pub use glass_pipe::{GlassPipe, GlassPipeError, GlassPipeReadout};
pub use kv_implant::{
    KvCacheImplanter, KvCacheSnapshot, KvDtype, KvImplantError, KvShape,
    LayerKVSnapshot, MockKvCacheImplanter,
};
pub use sae::{
    auc_roc, evaluate_against_gate, FeatureId, LabeledScore, SaeAucError, SaeVerdict,
    ValidationSet, SAE_DOCTRINE_AUC_BAR,
};
pub use weight_patcher::{
    MockWeightPatcher, WeightPatch, WeightPatchError, WeightPatcher, WeightSnapshot,
    WeightTarget,
};
