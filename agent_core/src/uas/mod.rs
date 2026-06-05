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
pub mod cache_policy_pollution;
pub mod coactivation_tile;
pub mod codec_stage_latency;
pub mod cold_assembly_plan;
pub mod cold_miss_ledger;
pub mod cold_panic_fallback;
pub mod coldstream;
pub mod coldstream_vs_mmap;
pub mod construction_card;
pub mod copy_counter;
pub mod five_planes;
pub mod kind;
pub mod large_model_deferral;
pub mod lattice_state_controller;
pub mod metal_io_feature_gate;
pub mod pattern_boost;
pub mod product_route_review;
pub mod proof_carrying_residency_lease;
pub mod provider_reference;
pub mod provider_route_copy_source_guard;
pub mod reasoning_state_continuity;
pub mod residency_construction_graph;
pub mod residency_lease;
pub mod residency_tier;
pub mod semantic_working_set;
pub mod slab_arena_copy_count;
pub mod small_model_runtime_harness_dry_run;
pub mod small_model_runtime_harness_abortable_runtime_probe;
pub mod small_model_runtime_harness_owner_approved_probe;
pub mod small_model_runtime_harness_safety_plan;
pub mod ssd_wear_budget;
pub mod transport_cancellation;
pub mod transport_trace_answer_packet;
pub mod weight_block;
pub mod witness;

pub use acs_anchor::{AcsAnchor, AcsAnchorPlaneProjection};
pub use address::{UasAddress, UasAddressParseError};
pub use anchor_registry::AcsAnchorRegistry;
pub use app_cold_store::{
    AppColdStorePlacement, AppColdStoreRouteCard, AppColdStoreRouteCardError,
    AppColdStoreRouteCardTotals, AppColdStoreUnit,
};
pub use cache_policy_pollution::{
    CachePolicyLane, CachePolicyMetrics, CachePolicyPollutionError, CachePolicyPollutionWitness,
    CachePolicySurface, CachePolicyTrial, CACHE_POLICY_POLLUTION_CURSOR,
    CACHE_POLICY_POLLUTION_NEXT_CURSOR,
};
pub use coactivation_tile::{
    CoactivationTile, CoactivationTileError, CoactivationTileUnit, CoactivationTileUnitKind,
};
pub use codec_stage_latency::{
    CodecStageLane, CodecStageLatencyError, CodecStageLatencyMetrics, CodecStageLatencyWitness,
    CodecStageRecord, CodecStageSurface, CODEC_STAGE_LATENCY_CURSOR,
    CODEC_STAGE_LATENCY_NEXT_CURSOR,
};
pub use cold_assembly_plan::{
    ColdAssemblyBaseline, ColdAssemblyPlan, ColdAssemblyPlanError, ColdAssemblyTileRef,
    ColdAssemblyTileRole,
};
pub use cold_miss_ledger::{ColdMissLedger, ColdMissLedgerEntry, ColdMissLedgerError};
pub use cold_panic_fallback::{
    ColdFallbackRoute, ColdPanicFallbackError, ColdPanicFallbackMetrics, ColdPanicFallbackRun,
    ColdPanicFallbackWitness, ColdPanicSurface, COLD_PANIC_FALLBACK_CURSOR,
    COLD_PANIC_FALLBACK_NEXT_CURSOR,
};
pub use coldstream::{
    ColdStreamAuthority, ColdStreamCachePolicy, ColdStreamDestination, ColdStreamError,
    ColdStreamPageRun, ColdStreamPriority, ColdStreamTransportManifest, ColdStreamTransportTrace,
};
pub use coldstream_vs_mmap::{
    ColdStreamBaselineKind, ColdStreamBaselineRow, ColdStreamVsMmapError, ColdStreamVsMmapFixture,
    ColdStreamVsMmapMetrics, ColdStreamVsMmapSurface, ColdStreamVsMmapWitness,
    COLDSTREAM_VS_MMAP_CURSOR, COLDSTREAM_VS_MMAP_NEXT_CURSOR,
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
pub use metal_io_feature_gate::{
    MetalFeatureStatus, MetalIoFeatureDecision, MetalIoFeatureGateError, MetalIoFeatureGateMetrics,
    MetalIoFeatureGateWitness, MetalIoFeatureSurface, MetalIoLane, METAL_IO_FEATURE_GATE_CURSOR,
    METAL_IO_FEATURE_GATE_NEXT_CURSOR,
};
pub use pattern_boost::{
    AssemblyPageRun, ColdRoutePolicyPatch, ColdRoutePolicyPatchError, UasAssemblyGenome,
    UasAssemblyGenomeError,
};
pub use product_route_review::{
    ProductRouteRedRoute, ProductRouteReviewDecision, ProductRouteReviewError,
    ProductRouteReviewMetrics, ProductRouteReviewPacket, ProductRouteReviewSurface,
    PRODUCT_ROUTE_REVIEW_CURSOR, PRODUCT_ROUTE_REVIEW_NEXT_CURSOR,
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
pub use slab_arena_copy_count::{
    SlabArenaAllocationSample, SlabArenaCopyCountError, SlabArenaCopyCountMetrics,
    SlabArenaCopyCountWitness, SlabArenaCopyEvent, SlabArenaLease, SlabArenaPlan, SlabArenaSurface,
    SlabCopyClass, SLAB_ARENA_COPY_COUNT_CURSOR, SLAB_ARENA_COPY_COUNT_NEXT_CURSOR,
};
pub use small_model_runtime_harness_dry_run::{
    SmallModelDryRunPhase, SmallModelDryRunRecord, SmallModelDryRunSurface,
    SmallModelRuntimeHarnessDryRunError, SmallModelRuntimeHarnessDryRunMetrics,
    SmallModelRuntimeHarnessDryRunWitness, SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR,
};
pub use small_model_runtime_harness_abortable_runtime_probe::{
    SmallModelAbortableRuntimeProbePhase, SmallModelAbortableRuntimeProbeRun,
    SmallModelAbortableRuntimeProbeSurface, SmallModelRuntimeHarnessAbortableProbeError,
    SmallModelRuntimeHarnessAbortableProbeMetrics,
    SmallModelRuntimeHarnessAbortableProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_owner_approved_probe::{
    SmallModelOwnerProbeLease, SmallModelOwnerProbePhase, SmallModelOwnerProbeSurface,
    SmallModelRuntimeHarnessOwnerProbeError, SmallModelRuntimeHarnessOwnerProbeMetrics,
    SmallModelRuntimeHarnessOwnerProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_safety_plan::{
    SmallModelHarnessLane, SmallModelHarnessSafetySurface, SmallModelHarnessStage,
    SmallModelRuntimeHarnessSafetyError, SmallModelRuntimeHarnessSafetyMetrics,
    SmallModelRuntimeHarnessSafetyPlan, SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR,
};
pub use ssd_wear_budget::{
    SsdWearBudgetError, SsdWearBudgetMetrics, SsdWearBudgetPlan, SsdWearBudgetSurface,
    SsdWearBudgetWitness, SSD_WEAR_BUDGET_CURSOR, SSD_WEAR_BUDGET_NEXT_CURSOR,
};
pub use transport_cancellation::{
    TransportCancellationError, TransportCancellationMetrics, TransportCancellationRun,
    TransportCancellationState, TransportCancellationSurface, TransportCancellationWitness,
    TRANSPORT_CANCELLATION_CURSOR, TRANSPORT_CANCELLATION_NEXT_CURSOR,
};
pub use transport_trace_answer_packet::{
    TransportTraceAnswerPacketError, TransportTraceAnswerPacketFrame,
    TransportTraceAnswerPacketMetrics, TransportTraceAnswerPacketSurface,
    TransportTraceAnswerPacketWitness, TransportTraceVisibilityLane,
    TRANSPORT_TRACE_ANSWER_PACKET_CURSOR, TRANSPORT_TRACE_ANSWER_PACKET_NEXT_CURSOR,
};
pub use weight_block::{
    ByteRange, ResidencyBudget, ResidencyPlan, ResidencyPlanError, ResidencyPlanStatus,
    ResidencyPlanTotals, ResidencyPlanViolation, WeightBlockEncoding, WeightBlockIrChart,
    WeightBlockManifest, WeightBlockManifestError, WeightBlockResidencyClass, GIB,
    RANGE_HASH_CHUNK_BYTES,
};
