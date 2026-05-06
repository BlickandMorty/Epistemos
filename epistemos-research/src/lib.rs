//! HELIOS V5 Lane 3 (RESEARCH_FRONTIER) workspace member.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 + §3
//! W17/W18/W19 + DOC 0 §0.4:
//!
//! > "Lane 3 RESEARCH_FRONTIER — VPD extraction + Dual Connectome
//! >  Trace + ParamAnchor + QK Edge Anchor + ParamAttributionGraph +
//! >  ComponentRoute. JIT permitted."
//!
//! ## Sub-modules
//!
//! - [`vpd`] — Goodfire-style Variational Parameter Decomposition
//!   substrate (PCF-1..PCF-3, PCF-7, PCF-8). Extracted parameter
//!   anchors + attention-edge anchors + parameter-component graphs +
//!   component routes + dual SPD/SAE traces + sheaf consistency.
//! - [`theorems`] — E1-E7 Epistemos Core Theorem substrate types
//!   (the foundational seven). Includes Chart6 (E1 12-plane bundle),
//!   CellularSheaf (E2), MorphField (E3), WBO7Inequality (E4),
//!   DuplexFusion (E5), Epi_eps (E6), AutogenousKernel (E7).
//! - [`acs`] — Anchored Cognitive Substrate + CMS-X v3 constitutive
//!   field lifts from HELIOS v4 source_docs. Research-tier
//!   architectural anchor.
//! - [`shadow_memory`] — Helios Shadow Memory escalation policy +
//!   Theorem 2.4 (Shadowed Associative State, Conditional) KL
//!   bound substrate (classical analogue of Huang-Kueng-Preskill
//!   2020 / Zhao-Zlokapa-Neven-Babbush-Preskill-McClean-Huang
//!   arXiv:2604.07639). NEVER inherits the quantum advantage.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 is **research-only**. NEVER ships in MAS. The crate has no
//! `mas-build` feature; building it requires `--features research`.

#[cfg(feature = "research")]
pub mod acs;

#[cfg(feature = "research")]
pub mod shadow_memory;

#[cfg(feature = "research")]
pub mod theorems;

#[cfg(feature = "research")]
pub mod vpd;
