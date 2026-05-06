//! HELIOS V5 E1-E7 Epistemos Core Theorem substrate types.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §C
//! + `docs/HELIOS_V5_DOC_0_INDEX.md` §0.2:
//!
//! - **E1** Density Theorem (12-plane bundle X = A_1 × ⋯ × A_6 ⊂ ℂ⁶)
//! - **E2** Ultrametric-Sheaf Gluing (cellular sheaf F_q over patch
//!   graph G_q, locally compatible patch states = Γ(G_q, F_q) = ker δ⁰)
//! - **E3** Storage-Disaggregated Morph Field
//! - **E4** UST-1.5 / WBO-7 Master Inequality
//! - **E5** Duplex Fusion (architecture-level error envelope)
//! - **E6** Error-Enriched Convergence (Epi_ε category)
//! - **E7** Autogenous Kernel Identity (c_W ≃ c_C in Epi_ε within ULP)

pub mod e1_density;
pub mod e2_sheaf_gluing;
pub mod e3_morph_field;
pub mod e4_wbo7;
pub mod e5_duplex_fusion;
pub mod e6_epi_epsilon;
pub mod e7_kernel_identity;
