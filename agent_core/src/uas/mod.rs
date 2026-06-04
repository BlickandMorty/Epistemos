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
pub mod cold_assembly_plan;
pub mod cold_miss_ledger;
pub mod coldstream;
pub mod construction_card;
pub mod copy_counter;
pub mod five_planes;
pub mod kind;
pub mod large_model_deferral;
pub mod lattice_state_controller;
pub mod pattern_boost;
pub mod proof_carrying_residency_lease;
pub mod provider_reference;
pub mod provider_route_copy_source_guard;
pub mod reasoning_state_continuity;
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
pub use cold_assembly_plan::{
    ColdAssemblyBaseline, ColdAssemblyPlan, ColdAssemblyPlanError, ColdAssemblyTileRef,
    ColdAssemblyTileRole,
};
pub use cold_miss_ledger::{ColdMissLedger, ColdMissLedgerEntry, ColdMissLedgerError};
pub use coldstream::{
    ColdStreamAuthority, ColdStreamCachePolicy, ColdStreamDestination, ColdStreamError,
    ColdStreamPageRun, ColdStreamPriority, ColdStreamTransportManifest, ColdStreamTransportTrace,
};
pub use construction_card::{
    ConstructionBudget, ConstructionCard, ConstructionCardError, ProStatus, ProductBuild,
};
pub use five_planes::{RuntimePlane, FIVE_RUNTIME_PLANES};
pub use kind::UasKind;
pub use large_model_deferral::{
    LargeModelActiveLane, LargeModelDeferralError, LargeModelDeferredLane,
    LargeModelProviderDeferralCard, LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
};
pub use lattice_state_controller::{
    LatticeControllerBaseline, LatticeRouteAction, LatticeStateController,
    LatticeStateControllerError,
};
pub use pattern_boost::{
    AssemblyPageRun, ColdRoutePolicyPatch, ColdRoutePolicyPatchError, UasAssemblyGenome,
    UasAssemblyGenomeError,
};
pub use proof_carrying_residency_lease::{
    authorize_cold_byte_wake, AuthorizedColdByteWake, ProofCarryingResidencyLease,
    ProofCarryingResidencyLeaseError,
};
pub use provider_reference::{
    ProviderReferenceKind, ProviderReferenceManifest, ProviderReferenceManifestError,
    ReferenceDataSentClass, ReferenceEvidenceScope, ReferenceRetentionClaim,
};
pub use provider_route_copy_source_guard::{
    ProviderRouteCopyClaim, ProviderRouteCopySourceError, ProviderRouteCopySourceGuard,
    ProviderRouteCopySourceMetrics, ProviderRouteCopySurface, ProviderRouteSourceKind,
    PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR, PROVIDER_ROUTE_COPY_SOURCE_NEXT_CURSOR,
};
pub use reasoning_state_continuity::{
    PreservedStateKind, ReasoningStateBaseline, ReasoningStateContinuityCard,
    ReasoningStateContinuityError, StatePrivacyClass,
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
