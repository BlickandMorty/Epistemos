//! HELIOS V5 SCOPE-Rex full surface — Tier 1 / Tier 2 / Tier 3 module.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §G,
//! the full Σ-signature is:
//!
//! ```text
//! Σ(x) = [τ truth, δ direction, π prime/composite/gap,
//!         ρ resonance, κ KAM, η evidence, λ residency]
//! ```
//!
//! - **Core (τ + π + λ)**: SHIPPED at `agent_core/src/resonance/{tau,pi,lambda}.rs`.
//!   Same module path; this `scope_rex` module references but does not re-host.
//! - **Pro (+δ + ρ)**: NEW; lands in `delta.rs` + `rho.rs` (gated `pro-build`).
//! - **Research (+κ + η)**: NEW; lands in `kappa.rs` + `eta.rs` (gated
//!   `research`).
//!
//! Sub-modules under this `scope_rex` namespace ship Tier-1 surface
//! pieces that bind those rings together — currently:
//!
//! - [`answer_packet`] — HELIOS V5 W1 (the 5th Monday-Move primitive,
//!   the only genuinely new one per integration brief §4)
//! - [`residency`] — HELIOS V5 W4 Residency Governor pure function
//!   (lands in a follow-up slice)
//! - [`btm_semantic`] — HELIOS V5 W5 Semantic Brain Time Machine V1.5
//!   (lands in a follow-up slice)
//! - [`metal::asa_index`] — HELIOS V5 W6 Active-Support Atlas indexing
//!   (lands in a follow-up slice)
//!
//! ## Cross-references
//!
//! - DOC 0 INDEX `docs/HELIOS_V5_DOC_0_INDEX.md` §0.1 (concept-to-doc
//!   map), §0.5 (reading order), §0.6 (glossary)
//! - v2 plan `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W1
//! - v5.2 source canon `docs/fusion/helios v5 updated.md` PART 4 W1
//! - canon-hardening protocol §1 (WRV state machine) — every type
//!   below is `state: implemented` until a downstream caller wires it
//!   (`state: wired`), an integration test exercises it
//!   (`state: reachable`), and the chat row surfaces its UI
//!   (`state: visible`)

pub mod answer_packet;
