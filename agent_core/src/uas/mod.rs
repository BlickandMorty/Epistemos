//! UAS — Unified Active Substrate.
//!
//! Source:
//! - `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G hierarchy LOCK
//!   (BODY layer: "identity != residency; every artifact addressable independent
//!   of where it lives").
//! - Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §1 umbrella name LOCK + §2 hierarchy LOCK + §5 register rows #1 / #2 / #3.
//! - Phase B blueprint: `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md` §2.1
//!   iters 21-26.
//!
//! # Phase B.G.B1 status
//!
//! | Iter | Slice | Status |
//! |---|---|---|
//! | 21 | `UasAddress` + `UasKind` placeholder | landed |
//! | 22 | `UasKind` full variant set (T1 review pending) | this iter |
//! | 23 | `residency_tier.rs` (§4.G three-tier shipping policy) | pending |
//! | 24 | `ResidencyLease` (TTL + drop semantics) | pending |
//! | 25 | SCOPE-Rex witness emission round-trip test | pending |
//! | 26 | push beat + git-show signature verification | pending |
//!
//! Every UAS-addressed artifact (vault note · graph node · KV page · model
//! component · agent trace · tool result · AnswerPacket · TriFusionBlock)
//! carries a `UasAddress` that lookup resolves regardless of residency (RAM
//! hot · RAM warm · SSD cold · cloud).

pub mod acs_anchor;
pub mod address;
pub mod anchor_registry;
pub mod app_cold_store;
pub mod construction_card;
pub mod copy_counter;
pub mod five_planes;
pub mod kind;
pub mod provider_reference;
pub mod residency_lease;
pub mod residency_tier;
pub mod weight_block;
pub mod witness;

pub use acs_anchor::{AcsAnchor, AcsAnchorPlaneProjection};
pub use address::{UasAddress, UasAddressParseError};
pub use anchor_registry::AcsAnchorRegistry;
pub use app_cold_store::{
    AppColdStorePlacement, AppColdStoreRouteCard, AppColdStoreRouteCardError,
    AppColdStoreRouteCardTotals, AppColdStoreUnit,
};
pub use construction_card::{
    ConstructionBudget, ConstructionCard, ConstructionCardError, ProStatus, ProductBuild,
};
pub use five_planes::{RuntimePlane, FIVE_RUNTIME_PLANES};
pub use kind::UasKind;
pub use provider_reference::{
    ProviderReferenceKind, ProviderReferenceManifest, ProviderReferenceManifestError,
    ReferenceDataSentClass, ReferenceEvidenceScope, ReferenceRetentionClaim,
};
pub use residency_lease::ResidencyLease;
pub use residency_tier::ResidencyTier;
pub use weight_block::{
    ByteRange, ResidencyBudget, ResidencyPlan, ResidencyPlanError, ResidencyPlanStatus,
    ResidencyPlanTotals, ResidencyPlanViolation, WeightBlockEncoding, WeightBlockIrChart,
    WeightBlockManifest, WeightBlockManifestError, WeightBlockResidencyClass, GIB,
    RANGE_HASH_CHUNK_BYTES,
};
