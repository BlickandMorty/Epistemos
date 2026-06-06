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
pub mod compressed_model_source_card_intake;
pub mod compressed_route_answer_packet_dry_run;
pub mod construction_card;
pub mod copy_counter;
pub mod five_planes;
pub mod gemma_qat_local_runtime_candidate_card;
pub mod kind;
pub mod large_model_deferral;
pub mod lattice_state_controller;
pub mod metal_io_feature_gate;
pub mod model_inventory_candidate;
pub mod pattern_boost;
pub mod product_route_review;
pub mod proof_carrying_residency_lease;
pub mod proprietary_compression_provenance_gate;
pub mod provider_reference;
pub mod provider_route_copy_source_guard;
pub mod qat_model_route_card_memory_preflight;
pub mod reasoning_state_continuity;
pub mod residency_construction_graph;
pub mod residency_lease;
pub mod residency_tier;
pub mod semantic_working_set;
pub mod slab_arena_copy_count;
pub mod small_compressed_model_live_harness_preflight;
pub mod small_compressed_model_local_runtime_command_card;
pub mod small_compressed_model_model_path_readiness_card;
pub mod small_compressed_model_owner_approval_runtime_gate;
pub mod small_compressed_model_runtime_probe_proof_envelope;
pub mod small_model_runtime_harness_abortable_runtime_probe;
pub mod small_model_runtime_harness_answer_packet_runtime_probe;
pub mod small_model_runtime_harness_dry_run;
pub mod small_model_runtime_harness_first_token_runtime_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_answer_packet_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_capability_recheck;
pub mod small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_live_probe;
pub mod small_model_runtime_harness_fresh_product_runtime_safety_lease;
pub mod small_model_runtime_harness_fresh_product_runtime_wrv_probe;
pub mod small_model_runtime_harness_logged_runtime_smoke;
pub mod small_model_runtime_harness_owner_approved_probe;
pub mod small_model_runtime_harness_product_answer_packet_live_probe;
pub mod small_model_runtime_harness_product_route_capability_recheck;
pub mod small_model_runtime_harness_product_wrv_probe;
pub mod small_model_runtime_harness_safety_plan;
pub mod ssd_wear_budget;
pub mod transport_cancellation;
pub mod transport_trace_answer_packet;
pub mod turbovec_eidos_compressed_index_plan;
pub mod turbovec_filter_before_rank_privacy_gate;
pub mod turbovec_stable_external_id_registry_plan;
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
pub use compressed_route_answer_packet_dry_run::{
    CompressedRouteAnswerPacketDryRun, CompressedRouteAnswerPacketDryRunSet,
    CompressedRouteAnswerPacketError, CompressedRouteAnswerPacketMetrics,
    CompressedRouteAnswerPacketRefs, CompressedRouteByteLedger, CompressedRoutePacketStatus,
    CompressedRoutePromotionTier, COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_CURSOR,
    COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_NEXT_CURSOR,
};
pub use compressed_model_source_card_intake::{
    CompressedModelFormat, CompressedModelOrgan, CompressedModelPromotionTier,
    CompressedModelRuntimeLane, CompressedModelSourceByteScope, CompressedModelSourceCard,
    CompressedModelSourceCardError, CompressedModelSourceCardIntake,
    CompressedModelSourceCardKind, CompressedModelSourceCardMetrics,
    CompressedModelSourceProofRefs, COMPRESSED_MODEL_SOURCE_CARD_INTAKE_CURSOR,
    COMPRESSED_MODEL_SOURCE_CARD_INTAKE_NEXT_CURSOR,
};
pub use construction_card::{
    ConstructionBudget, ConstructionCard, ConstructionCardError, ProStatus, ProductBuild,
};
pub use five_planes::{RuntimePlane, FIVE_RUNTIME_PLANES};
pub use gemma_qat_local_runtime_candidate_card::{
    GemmaQatCandidateBand, GemmaQatCandidateError, GemmaQatCandidateMetrics, GemmaQatFormat,
    GemmaQatLocalRuntimeCandidateCard, GemmaQatLocalRuntimeCandidateSet,
    GemmaQatMemoryEnvelope, GemmaQatModelSize, GemmaQatPromotionTier, GemmaQatProofRefs,
    GemmaQatRuntimeLane, GEMMA_QAT_LOCAL_RUNTIME_CANDIDATE_CARD_CURSOR,
    GEMMA_QAT_LOCAL_RUNTIME_CANDIDATE_CARD_NEXT_CURSOR,
};
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
pub use model_inventory_candidate::{
    ModelInventoryByteScope, ModelInventoryCandidateCard, ModelInventoryCandidateSet,
    ModelInventoryClaimLimit, ModelInventoryEvidenceKind, ModelInventoryHashClaim,
    ModelInventoryMetadataStatus, ModelInventoryMetrics, ModelInventoryProofRefs,
    ModelInventorySidecarPolicy, ModelInventoryValidationError,
    MODEL_INVENTORY_ZERO_BYTE_CANDIDATE_CARDS_CURSOR,
    MODEL_INVENTORY_ZERO_BYTE_CANDIDATE_CARDS_NEXT_CURSOR,
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
pub use qat_model_route_card_memory_preflight::{
    QatModelRouteCardMemoryPreflight, QatModelRouteCardMemoryPreflightSet, QatRouteAdmission,
    QatRouteMemoryBudget, QatRoutePreflightError, QatRoutePreflightMetrics,
    QatRoutePromotionTier, QatRouteProofRefs, QatRouteRuntimeLane,
    QAT_MODEL_ROUTE_CARD_MEMORY_PREFLIGHT_CURSOR,
    QAT_MODEL_ROUTE_CARD_MEMORY_PREFLIGHT_NEXT_CURSOR,
};
pub use proprietary_compression_provenance_gate::{
    ProprietaryCompressionAllowedAction, ProprietaryCompressionBehaviorKind,
    ProprietaryCompressionByteScope, ProprietaryCompressionExtractedBehavior,
    ProprietaryCompressionImportMode, ProprietaryCompressionLicenseClass,
    ProprietaryCompressionProofRefs, ProprietaryCompressionProvenanceError,
    ProprietaryCompressionProvenanceGate, ProprietaryCompressionProvenanceMetrics,
    ProprietaryCompressionSourceKind, ProprietaryCompressionSourceOverlay,
    PROPRIETARY_COMPRESSION_PROVENANCE_GATE_CURSOR,
    PROPRIETARY_COMPRESSION_PROVENANCE_GATE_NEXT_CURSOR,
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
pub use small_compressed_model_live_harness_preflight::{
    SmallCompressedHarnessAdmission, SmallCompressedHarnessBytePlan,
    SmallCompressedHarnessPreflightError, SmallCompressedHarnessPreflightMetrics,
    SmallCompressedHarnessPromotionTier, SmallCompressedHarnessProofRefs,
    SmallCompressedModelLiveHarnessPreflightCandidate,
    SmallCompressedModelLiveHarnessPreflightSet,
    SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_CURSOR,
    SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_NEXT_CURSOR,
};
pub use small_compressed_model_local_runtime_command_card::{
    SmallCompressedLocalRuntimeCommandByteLedger, SmallCompressedLocalRuntimeCommandCardError,
    SmallCompressedLocalRuntimeCommandMetrics, SmallCompressedLocalRuntimeCommandRefs,
    SmallCompressedLocalRuntimeCommandRole, SmallCompressedModelLocalRuntimeCommandCard,
    SmallCompressedModelLocalRuntimeCommandCardSet,
    SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_CURSOR,
    SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_NEXT_CURSOR,
};
pub use small_compressed_model_model_path_readiness_card::{
    SmallCompressedModelModelPathReadinessCard, SmallCompressedModelModelPathReadinessCardSet,
    SmallCompressedModelPathByteLedger, SmallCompressedModelPathMetrics,
    SmallCompressedModelPathReadinessError, SmallCompressedModelPathRefs,
    SmallCompressedModelPathStatus, SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_CURSOR,
    SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_NEXT_CURSOR,
};
pub use small_compressed_model_owner_approval_runtime_gate::{
    SmallCompressedModelOwnerApprovalRuntimeGate,
    SmallCompressedModelOwnerApprovalRuntimeGateSet,
    SmallCompressedOwnerApprovalByteLedger, SmallCompressedOwnerApprovalGateError,
    SmallCompressedOwnerApprovalGateMetrics, SmallCompressedOwnerApprovalRefs,
    SmallCompressedOwnerApprovalStatus,
    SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_CURSOR,
    SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_NEXT_CURSOR,
};
pub use small_compressed_model_runtime_probe_proof_envelope::{
    required_phases as required_small_compressed_runtime_probe_phases,
    SmallCompressedRuntimeProbeByteLedger, SmallCompressedRuntimeProbeEnvelopeError,
    SmallCompressedRuntimeProbeEnvelopeMetrics, SmallCompressedRuntimeProbeEnvelopeStatus,
    SmallCompressedRuntimeProbePhase, SmallCompressedRuntimeProbeProofEnvelope,
    SmallCompressedRuntimeProbeProofEnvelopeSet, SmallCompressedRuntimeProbeRefs,
    SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_CURSOR,
    SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_NEXT_CURSOR,
};
pub use slab_arena_copy_count::{
    SlabArenaAllocationSample, SlabArenaCopyCountError, SlabArenaCopyCountMetrics,
    SlabArenaCopyCountWitness, SlabArenaCopyEvent, SlabArenaLease, SlabArenaPlan, SlabArenaSurface,
    SlabCopyClass, SLAB_ARENA_COPY_COUNT_CURSOR, SLAB_ARENA_COPY_COUNT_NEXT_CURSOR,
};
pub use small_model_runtime_harness_abortable_runtime_probe::{
    SmallModelAbortableRuntimeProbePhase, SmallModelAbortableRuntimeProbeRun,
    SmallModelAbortableRuntimeProbeSurface, SmallModelRuntimeHarnessAbortableProbeError,
    SmallModelRuntimeHarnessAbortableProbeMetrics, SmallModelRuntimeHarnessAbortableProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_answer_packet_runtime_probe::{
    redacted_first_token_run_event_log, required_answer_packet_runtime_probe_phases,
    SmallModelAnswerPacketRuntimeProbePacket, SmallModelAnswerPacketRuntimeProbePhase,
    SmallModelAnswerPacketRuntimeProbeSurface, SmallModelRuntimeHarnessAnswerPacketProbeError,
    SmallModelRuntimeHarnessAnswerPacketProbeMetrics,
    SmallModelRuntimeHarnessAnswerPacketProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_dry_run::{
    SmallModelDryRunPhase, SmallModelDryRunRecord, SmallModelDryRunSurface,
    SmallModelRuntimeHarnessDryRunError, SmallModelRuntimeHarnessDryRunMetrics,
    SmallModelRuntimeHarnessDryRunWitness, SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR,
};
pub use small_model_runtime_harness_first_token_runtime_probe::{
    required_phases as required_first_token_runtime_probe_phases,
    SmallModelFirstTokenRuntimeProbePhase, SmallModelFirstTokenRuntimeProbeRun,
    SmallModelFirstTokenRuntimeProbeSurface, SmallModelRuntimeHarnessFirstTokenProbeError,
    SmallModelRuntimeHarnessFirstTokenProbeMetrics, SmallModelRuntimeHarnessFirstTokenProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_answer_packet_probe::{
    redacted_fresh_product_runtime_run_event_log,
    required_fresh_product_runtime_answer_packet_probe_phases,
    SmallModelFreshProductRuntimeAnswerPacketPacket,
    SmallModelFreshProductRuntimeAnswerPacketPhase,
    SmallModelFreshProductRuntimeAnswerPacketProbeError,
    SmallModelFreshProductRuntimeAnswerPacketProbeMetrics,
    SmallModelFreshProductRuntimeAnswerPacketProbeWitness,
    SmallModelFreshProductRuntimeAnswerPacketSurface,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_capability_recheck::{
    fresh_product_runtime_capability_recheck_metadata_budget_bytes,
    required_fresh_product_runtime_capability_blockers,
    required_fresh_product_runtime_capability_recheck_phases,
    SmallModelFreshProductRuntimeCapabilityRecheckError,
    SmallModelFreshProductRuntimeCapabilityRecheckMetrics,
    SmallModelFreshProductRuntimeCapabilityRecheckPhase,
    SmallModelFreshProductRuntimeCapabilityRecheckWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe::{
    fresh_product_runtime_l3_capability_closeout_metadata_budget_bytes,
    required_fresh_product_runtime_l3_capability_closeout_blockers,
    required_fresh_product_runtime_l3_capability_closeout_phases,
    SmallModelFreshProductRuntimeL3CapabilityCloseoutError,
    SmallModelFreshProductRuntimeL3CapabilityCloseoutMetrics,
    SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase,
    SmallModelFreshProductRuntimeL3CapabilityCloseoutWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe::{
    fresh_product_runtime_l3_log_correlation_metadata_budget_bytes,
    required_fresh_product_runtime_l3_log_correlation_phases,
    SmallModelFreshProductRuntimeL3LogCorrelationError,
    SmallModelFreshProductRuntimeL3LogCorrelationMetrics,
    SmallModelFreshProductRuntimeL3LogCorrelationPhase,
    SmallModelFreshProductRuntimeL3LogCorrelationRecord,
    SmallModelFreshProductRuntimeL3LogCorrelationWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe::{
    fresh_product_runtime_l3_manual_runtime_verification_metadata_budget_bytes,
    required_fresh_product_runtime_l3_manual_runtime_verification_phases,
    SmallModelFreshProductRuntimeL3ManualRuntimeObservation,
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError,
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationMetrics,
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase,
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe::{
    fresh_product_runtime_l3_release_audit_preflight_metadata_budget_bytes,
    fresh_product_runtime_l3_release_audit_preflight_skill_path,
    required_fresh_product_runtime_l3_release_audit_preflight_blockers,
    required_fresh_product_runtime_l3_release_audit_preflight_phases,
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightError,
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightMetrics,
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightPhase,
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe::{
    fresh_product_runtime_l3_release_audit_automated_checks_metadata_budget_bytes,
    fresh_product_runtime_l3_release_audit_automated_checks_skill_path,
    required_fresh_product_runtime_l3_release_audit_automated_check_blockers,
    required_fresh_product_runtime_l3_release_audit_automated_check_phases,
    required_fresh_product_runtime_l3_release_audit_automated_checks,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksMetrics,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe::{
    fresh_product_runtime_l3_release_audit_zero_fail_metadata_budget_bytes,
    fresh_product_runtime_l3_release_audit_zero_fail_skill_path,
    required_fresh_product_runtime_l3_release_audit_zero_fail_blockers,
    required_fresh_product_runtime_l3_release_audit_zero_fail_phases,
    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError,
    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailMetrics,
    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase,
    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_live_probe::{
    fresh_product_runtime_live_probe_max_first_token_ms,
    fresh_product_runtime_live_probe_max_load_ms, fresh_product_runtime_live_probe_max_total_ms,
    fresh_product_runtime_live_probe_metadata_budget_bytes,
    fresh_product_runtime_live_probe_route_authority,
    required_fresh_product_runtime_live_probe_phases, SmallModelFreshProductRuntimeLiveProbeError,
    SmallModelFreshProductRuntimeLiveProbeMetrics, SmallModelFreshProductRuntimeLiveProbePhase,
    SmallModelFreshProductRuntimeLiveProbeRecord, SmallModelFreshProductRuntimeLiveProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_safety_lease::{
    fresh_product_runtime_safety_lease_max_deadline_ms,
    fresh_product_runtime_safety_lease_max_model_budget_bytes,
    fresh_product_runtime_safety_lease_max_runtime_budget_bytes,
    fresh_product_runtime_safety_lease_metadata_budget_bytes,
    fresh_product_runtime_safety_lease_route_authority,
    required_fresh_product_runtime_safety_lease_ids,
    required_fresh_product_runtime_safety_lease_phases, SmallModelFreshProductRuntimeSafetyLease,
    SmallModelFreshProductRuntimeSafetyLeaseError, SmallModelFreshProductRuntimeSafetyLeaseMetrics,
    SmallModelFreshProductRuntimeSafetyLeasePhase, SmallModelFreshProductRuntimeSafetyLeaseWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_fresh_product_runtime_wrv_probe::{
    fresh_product_runtime_wrv_metadata_budget_bytes, required_fresh_product_runtime_wrv_phases,
    SmallModelFreshProductRuntimeWrvMetrics, SmallModelFreshProductRuntimeWrvPhase,
    SmallModelFreshProductRuntimeWrvProbeError, SmallModelFreshProductRuntimeWrvSourceRef,
    SmallModelFreshProductRuntimeWrvSurface, SmallModelFreshProductRuntimeWrvTestRef,
    SmallModelFreshProductRuntimeWrvWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_WRV_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_WRV_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_logged_runtime_smoke::{
    SmallModelLoggedRuntimeSmokePhase, SmallModelLoggedRuntimeSmokeRun,
    SmallModelLoggedRuntimeSmokeSurface, SmallModelRuntimeHarnessLoggedSmokeError,
    SmallModelRuntimeHarnessLoggedSmokeMetrics, SmallModelRuntimeHarnessLoggedSmokeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_owner_approved_probe::{
    SmallModelOwnerProbeLease, SmallModelOwnerProbePhase, SmallModelOwnerProbeSurface,
    SmallModelRuntimeHarnessOwnerProbeError, SmallModelRuntimeHarnessOwnerProbeMetrics,
    SmallModelRuntimeHarnessOwnerProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_product_answer_packet_live_probe::{
    product_answer_packet_live_metadata_budget_bytes, required_product_answer_packet_live_phases,
    SmallModelProductAnswerPacketLiveMetrics, SmallModelProductAnswerPacketLivePhase,
    SmallModelProductAnswerPacketLiveProbeError, SmallModelProductAnswerPacketLiveSurface,
    SmallModelProductAnswerPacketLiveWitness,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR,
};
pub use small_model_runtime_harness_product_route_capability_recheck::{
    product_route_capability_recheck_metadata_budget_bytes,
    required_product_route_capability_blockers, required_product_route_capability_recheck_phases,
    SmallModelProductRouteCapabilityBlocker, SmallModelProductRouteCapabilityRecheckError,
    SmallModelProductRouteCapabilityRecheckMetrics, SmallModelProductRouteCapabilityRecheckPhase,
    SmallModelProductRouteCapabilityRecheckWitness,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR,
};
pub use small_model_runtime_harness_product_wrv_probe::{
    product_wrv_metadata_budget_bytes, required_product_wrv_phases, SmallModelProductWrvMetrics,
    SmallModelProductWrvPhase, SmallModelProductWrvProbeError, SmallModelProductWrvSourceRef,
    SmallModelProductWrvSurface, SmallModelProductWrvTestRef, SmallModelProductWrvWitness,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR,
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
pub use turbovec_eidos_compressed_index_plan::{
    TurboVecAllowlistPrivacyPolicy, TurboVecEidosCompressedIndexPlan,
    TurboVecEidosCompressedIndexPlanSet, TurboVecExternalIdPolicy, TurboVecIndexByteLedger,
    TurboVecIndexOrgan, TurboVecIndexPlanError, TurboVecIndexPlanMetrics,
    TurboVecIndexPlanStatus, TurboVecIndexPromotionTier, TurboVecIndexProofRefs,
    TurboVecRebuildPolicy, TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_CURSOR,
    TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_NEXT_CURSOR,
};
pub use turbovec_filter_before_rank_privacy_gate::{
    TurboVecAccessDecision, TurboVecAllowlistCompilation, TurboVecCandidateEvidence,
    TurboVecFilterBeforeRankByteLedger, TurboVecFilterBeforeRankError,
    TurboVecFilterBeforeRankMetrics, TurboVecFilterBeforeRankPlan,
    TurboVecFilterBeforeRankPlanSet, TurboVecFilterBeforeRankPolicy,
    TurboVecFilterBeforeRankPromotionTier, TurboVecFilterBeforeRankProofRefs,
    TurboVecFilterBeforeRankScenario, TurboVecFilterBeforeRankStatus,
    TurboVecFilterFixtureKind, TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_CURSOR,
    TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_NEXT_CURSOR,
};
pub use turbovec_stable_external_id_registry_plan::{
    stable_external_id_for_uas, TurboVecStableExternalIdByteLedger,
    TurboVecStableExternalIdCollisionLedgerEntry,
    TurboVecStableExternalIdCollisionResolution, TurboVecStableExternalIdEntry,
    TurboVecStableExternalIdLifecycle, TurboVecStableExternalIdPromotionTier,
    TurboVecStableExternalIdProofRefs, TurboVecStableExternalIdRegistryError,
    TurboVecStableExternalIdRegistryMetrics, TurboVecStableExternalIdRegistryPlan,
    TurboVecStableExternalIdRegistryPlanSet, TurboVecStableExternalIdRegistryPolicy,
    TurboVecStableExternalIdRegistryStatus, TurboVecStableExternalIdSource,
    TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_CURSOR,
    TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_NEXT_CURSOR,
};
pub use weight_block::{
    ByteRange, ResidencyBudget, ResidencyPlan, ResidencyPlanError, ResidencyPlanStatus,
    ResidencyPlanTotals, ResidencyPlanViolation, WeightBlockEncoding, WeightBlockIrChart,
    WeightBlockManifest, WeightBlockManifestError, WeightBlockResidencyClass, GIB,
    RANGE_HASH_CHUNK_BYTES,
};
