//! HELIOS V5 Lane 5 (SPECULATIVE_VAULT) workspace member.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 + §3
//! W20/W21/W22 + DOC 0 §0.4:
//!
//! > "Lane 5 SPECULATIVE_VAULT — HCache/KVCrush, ModelSurgery
//! >  (PCF-6), Active Rank-One Runtime (PCF-5), Connectome
//! >  Distillation (T34/PCF-9). Builds with `vault` Cargo feature;
//! >  never ships outside Lane 5 distribution."
//!
//! ## Sub-modules
//!
//! - [`runtime::active_rank_one`] — W21 + PCF-5 (Active Rank-One
//!   Runtime). Per-step component activation; modifies inference
//!   path; Pro-tier only after long burn-in.
//! - [`surgery`] — W20 + PCF-6 (ModelSurgeryEnvelope). Offline-edit
//!   retrain-free distillation envelope; mutates weights; cannot
//!   ship in MAS.
//! - [`cache::hcache`] / [`cache::kvcrush`] — W22 (HCache + KVCrush
//!   experimental tier).
//! - [`distill::connectome`] — PCF-9 (Connectome Distillation);
//!   alternate model file output.
//! - [`runtime::transfer`] — PCF-10 (Interpretability-to-Runtime
//!   Transfer).
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 5 is **vault-only**. NEVER ships in MAS. The crate has no
//! `mas-build` feature; building it requires `--features vault`.

#[cfg(feature = "vault")]
pub mod cache;

#[cfg(feature = "vault")]
pub mod distill;

#[cfg(feature = "vault")]
pub mod runtime;

#[cfg(feature = "vault")]
pub mod surgery;
