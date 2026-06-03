//! UAS - Unified Address Space.
//!
//! UAS is the identity/address fabric. Cold residency belongs to ColdStore /
//! ResidencyGovernor, while `AcsAnchor` remains the anchored coordinate and
//! provenance object.
//!
//! Current source:
//! - `docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md`.
//! - `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`.
//! - `docs/audits/NAMESPACE_AND_ARCHITECTURE_CLARITY_AUDIT_2026_05_31.md`.
//!
//! # Phase B.G.B1 status
//!
//! | Iter | Slice | Status |
//! |---|---|---|
//! | 21 | `UasAddress` + `UasKind` placeholder | landed |
//! | 22 | `UasKind` full variant set (T1 review pending) | this iter |
//! | 23 | `residency_tier.rs` (§4.G three-tier shipping policy) | landed |
//! | 24 | `ResidencyLease` (TTL + drop semantics) | landed |
//! | 25 | SCOPE-Rex witness emission round-trip test | landed |
//! | 26 | push beat + git-show signature verification | pending |
//!
//! Every UAS-addressed artifact (vault note, graph node, KV page, model
//! component, agent trace, tool result, AnswerPacket, TriFusionBlock)
//! carries a `UasAddress` that lookup resolves regardless of residency (RAM
//! hot, RAM warm, SSD cold, or gated provider route).

pub mod acs_anchor;
pub mod address;
pub mod anchor_registry;
pub mod app_cold_store;
pub mod coactivation_tile;
pub mod construction_card;
pub mod copy_counter;
pub mod five_planes;
pub mod kind;
pub mod pattern_boost;
pub mod provider_reference;
pub mod residency_construction_graph;
pub mod residency_lease;
pub mod residency_tier;
pub mod semantic_working_set;
pub mod weight_block;
pub mod witness;

pub use acs_anchor::{AcsAnchor, AcsAnchorPlaneProjection};
pub use address::{UasAddress, UasAddressParseError};
pub use anchor_registry::AcsAnchorRegistry;
pub use app_cold_store::{
    AppColdStorePlacement, AppColdStoreRouteCard, AppColdStoreRouteCardError,
    AppColdStoreRouteCardTotals, AppColdStoreUnit,
};
pub use coactivation_tile::{
    CoactivationTile, CoactivationTileError, CoactivationTileUnit, CoactivationTileUnitKind,
};
pub use construction_card::{
    ConstructionBudget, ConstructionCard, ConstructionCardError, ProStatus, ProductBuild,
};
pub use five_planes::{RuntimePlane, FIVE_RUNTIME_PLANES};
pub use kind::UasKind;
pub use pattern_boost::{
    AssemblyPageRun, ColdRoutePolicyPatch, ColdRoutePolicyPatchError, UasAssemblyGenome,
    UasAssemblyGenomeError,
};
pub use provider_reference::{
    ProviderReferenceKind, ProviderReferenceManifest, ProviderReferenceManifestError,
    ReferenceDataSentClass, ReferenceEvidenceScope, ReferenceRetentionClaim,
};
pub use residency_construction_graph::{
    AssemblyScore, CoactivationEdge, ColdMissRecord, IncompatibilityEdge,
    ResidencyConstructionBudget, ResidencyConstructionGraph, ResidencyConstructionGraphError,
    ResidencyConstructionUnit, VerifierEdge,
};
pub use residency_lease::ResidencyLease;
pub use residency_tier::ResidencyTier;
pub use semantic_working_set::{
    ColdFaultTrace, EvidenceNeed, KVByteBudgetCard, LayoutPatch, LayoutPatchPromotionStatus,
    MmapResidencyFence, PrefetchWindow, PrivacyClass, ResidencyPageTableEntry,
    SemanticWorkingSetError, SemanticWorkingSetPlan, SemanticWorkingSetPlanStatus,
    SemanticWorkingSetUnit, SemanticWorkingSetViolation, SourceCard, SourceNoPoisonStatus,
    SourceSignalEdge, SourceSignalGraph, SourceSignalType, SourceToResidencyPatch,
    SourceToResidencyPatchKind, SourceToResidencyPromotionStatus, TaskWorkingSetQuery,
    VerifierNeed, WorkingSetOracleBaselineScore, WorkingSetOracleCard, WorkingSetOracleScore,
    WorkingSetOracleStatus, WorkingSetStorageTier, WorkingSetTotals, WorkingSetUnitKind,
};
pub use weight_block::{
    ByteRange, ResidencyBudget, ResidencyPlan, ResidencyPlanError, ResidencyPlanStatus,
    ResidencyPlanTotals, ResidencyPlanViolation, WeightBlockEncoding, WeightBlockIrChart,
    WeightBlockManifest, WeightBlockManifestError, WeightBlockResidencyClass, GIB,
    RANGE_HASH_CHUNK_BYTES,
};
