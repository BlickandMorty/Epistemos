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
//! - [`cms_v2`] — Constitutive Moral Substrate v2 (April 2026).
//!   Six defense-in-depth layers, three-tier moral structure
//!   (hard / soft / meta), six unresolvable problems. Cites Brophy
//!   arXiv:2506.00415 (Wide Reflective Equilibrium), Curry et al.
//!   2019 (seven-culture universals), Arditi et al. NeurIPS 2024
//!   (refusal direction).
//! - [`ternary_kernel`] — Ternary Core with Residual Islands typed
//!   substrate: Trit alphabet, 16-trits-per-u32 packing convention,
//!   three-backend triad (Dense/MLX/BitnetReference/TernaryMetal),
//!   9 fragile-dense layers + 4 ternary hot-path layers, residual-
//!   island layer formula. Architectural envelope around the W12/
//!   W13/W14 MSL kernels.
//! - [`theorem_status`] — 5-arm status legend (P/EV/EB/C/DROP) +
//!   7-arm paper-safe label taxonomy + FOUNDATIONAL_SEVEN const
//!   table mapping E1..E7 → status + label per the hardened canon
//!   `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md`.
//! - [`v6_1`] — V6.1 Final Synthesis Lock canon: AttentionMode
//!   reframed as Interrupt (not Substrate) per the V5→V6→V6.1 arc;
//!   four-arm CanonLock chain; six-axis V6_1Axis slogan;
//!   `VERIFIED_FLOOR_ANCHOR = "ac8c6d28"` (immutable, carry-forward).
//! - [`sherry`] — Sherry 1.25-bit packing substrate per Hong Huang
//!   et al. (Jan 2026; Tencent/AngelSlim). 3:4 sparsity blocks of 4
//!   weights packed into 5 bits saturating C(4,3)·2³ = 32-config
//!   space. Pack/unpack round-trip + 3:4 contract enforcement.
//! - [`mas_capability_lattice`] — DeploymentTier (MAS / Pro /
//!   Research) × Capability (12-arm) availability lattice per the
//!   `mac_store_edition.md` MAS-First Focus Doctrine. CAPABILITY_LATTICE
//!   const table with 12 canonical rows; doctrine invariants (MAS
//!   baseline must ship; risky surfaces never in MAS; Pro widens MAS).
//! - [`engram`] — Engram hash-table substrate per
//!   `epistemos_resonance_gate.md` §2.2 (DeepSeek V4 inspired).
//!   Static-knowledge O(1) lookup separated from dynamic-reasoning
//!   compute. Sparsity Allocation Law heuristic at ~22% (NOT
//!   theorem) split via `sparsity_allocation_split()`.
//! - [`mathematical_pillars`] — Five mathematical pillars taxonomy
//!   per `epistemos_definitive_master.md` §"PART I". Wyner-Ziv +
//!   Babai/GPTQ + Softmax-½-Lipschitz + Test-Time Regression +
//!   eml-universal. Each pillar has anchor citation + Master
//!   Inequality role. All five are Status::P.
//! - [`self_evolving_l_se`] — L_SE Self-Evolving Extension
//!   substrate per `epistemos_definitive_master.md` §"PART IV".
//!   Hybrid Titans-MAC online + SEAL-DoRA nightly. Surprise
//!   gradient as unified confidence signal across L0..L4 + L_SE
//!   itself. T_SE drift bound parameters for the Master Inequality.
//! - [`validation_thresholds`] — 7 canonical validation thresholds
//!   per `epistemos_definitive_master.md` §"PART VI" §1. KL <
//!   0.05; compression ≥ 10×; top-k recall ≥ 0.95; L4 escalation
//!   < 5%; RAM ≤ 12 GB; decode ≥ 20 tok/s; SSM-Tx gap ≤ 5pp.
//!   `check_all()` returns failing thresholds.
//! - [`falsifier_actions`] — Per-term falsifier actions for the
//!   Master Inequality (WBO-6) per `epistemos_definitive_master.md`
//!   §"PART VI" §2. 6-term `InequalityTerm` × 9-arm
//!   `FalsifierAction` mapping with primary + optional secondary
//!   fallback per term.
//! - [`cross_domain_lens`] — "5 names, one substance" koan from
//!   `helios_v3.md` Part VII: residual stream = prediction error =
//!   surprise gradient = Koopman mode = free cumulant. Plus
//!   `TSafetyBound` parallel safety inequality (CMS-X v3 lives ON
//!   TOP of Helios, not inside the substrate).
//! - [`wbo_generations`] — Master Inequality WBO-5 → WBO-6 → WBO-7
//!   evolution. WBO-5 (compass artifact) ⊂ WBO-6 (definitive
//!   master) ⊂ WBO-7 (V5 canon, current). Per-generation
//!   `term_names()` + `term_count()` + `lock_date()` + `anchor_source()`.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 is **research-only**. NEVER ships in MAS. The crate has no
//! `mas-build` feature; building it requires `--features research`.

#[cfg(feature = "research")]
pub mod acs;

#[cfg(feature = "research")]
pub mod cms_v2;

#[cfg(feature = "research")]
pub mod cross_domain_lens;

#[cfg(feature = "research")]
pub mod engram;

#[cfg(feature = "research")]
pub mod falsifier_actions;

#[cfg(feature = "research")]
pub mod mas_capability_lattice;

#[cfg(feature = "research")]
pub mod mathematical_pillars;

#[cfg(feature = "research")]
pub mod self_evolving_l_se;

#[cfg(feature = "research")]
pub mod validation_thresholds;

#[cfg(feature = "research")]
pub mod wbo_generations;

#[cfg(feature = "research")]
pub mod shadow_memory;

#[cfg(feature = "research")]
pub mod sherry;

#[cfg(feature = "research")]
pub mod ternary_kernel;

#[cfg(feature = "research")]
pub mod theorem_status;

#[cfg(feature = "research")]
pub mod theorems;

#[cfg(feature = "research")]
pub mod v6_1;

#[cfg(feature = "research")]
pub mod vpd;
