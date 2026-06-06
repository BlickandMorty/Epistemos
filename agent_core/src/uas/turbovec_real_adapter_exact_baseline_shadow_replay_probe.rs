//! TurboVec real-adapter exact-baseline shadow-replay probe.
//!
//! This primitive consumes the clean-room adapter plan and turns it into a
//! stricter shadow-replay contract. It is still metadata-only: it does not
//! import TurboVec, build an adapter, open an index, load model bytes, inject
//! model context, mutate routes, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_CURSOR: &str =
    "turbovec_quarantine_real_adapter_exact_baseline_shadow_replay_probe";
pub const TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_product_graph_no_contamination_probe";

const CLEAN_ROOM_PLAN_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_clean_room_adapter_plan_probe:result";
const CLEAN_ROOM_PLAN_ADDRESS_PREFIX: &str = "turbovec_real_adapter_clean_room_adapter_plan_probe:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const PLAN_REF_PREFIX: &str = "clean_room_plan:turbovec-adapter:";
const QUERY_REF_PREFIX: &str = "query:turbovec-real-adapter:";
const EXACT_BASELINE_REF_PREFIX: &str = "app_cold_store:exact_baseline:turbovec-real-adapter:";
const SOURCE_CARD_REF_PREFIX: &str = "source_card:turbovec-shadow-replay:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-shadow-replay:";
const FALLBACK_REF_PREFIX: &str = "fallback:turbovec-shadow-replay:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-shadow-replay:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-shadow-replay:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-shadow-replay:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-shadow-replay:";
const MAX_METADATA_BYTES: u64 = 384 * 1024;
const MAX_FIXTURE_BYTES: u64 = 128 * 1024;
const MAX_PLANNED_REPLAY_BYTES: u64 = 256 * 1024;
const MIN_SAMPLE_COUNT: u64 = 32;
const MAX_SAMPLE_COUNT: u64 = 10_000;
const MAX_TOP_K: u64 = 50;
const RECALL_FLOOR_MICROS: u64 = 900_000;
const MAX_ALLOWED_DELTA_MICROS: u64 = 80_000;
const UPSTREAM_MOTIF_SOURCE_BYTES: u64 = 184_472;

// UAS: uas:turbovec-real-adapter-shadow:status
// Plane: Verification
// Residency: metadata-only shadow replay status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterShadowReplayStatus {
    MetadataOnlyShadowReplay,
    RuntimeCandidate,
    ProductCandidate,
}

// UAS: uas:turbovec-real-adapter-shadow:tier
// Plane: Verification
// Residency: T1/L1 metadata proof only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterShadowReplayTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-shadow:scenario
// Plane: Verification
// Residency: held-out replay case class.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterShadowReplayScenario {
    WarmExactHit,
    ColdMissFallback,
    CancellationFallback,
    MemoryPressureAbstain,
    EmptyAllowlistVisible,
    PrivacyDeniedFallback,
    RecallRegressionFallback,
}

// UAS: uas:turbovec-real-adapter-shadow:decision
// Plane: Controller + Verification
// Residency: shadow-only replay decision.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterShadowReplayDecision {
    RecordShadowWin,
    RecordShadowLoss,
    CancelAndFallback,
    MemoryAbstain,
    EmptyVisible,
    PrivacyFallback,
    RecallRegressionFallback,
}

// UAS: uas:turbovec-real-adapter-shadow:case
// Plane: Assembly + Controller + Verification
// Residency: metadata-only shadow replay case; no runtime bytes are opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterShadowReplayCase {
    pub case_id: String,
    pub scenario: TurboVecRealAdapterShadowReplayScenario,
    pub decision: TurboVecRealAdapterShadowReplayDecision,
    pub query_ref: String,
    pub clean_room_plan_ref: String,
    pub replay_seed: u64,
    pub sample_count: u64,
    pub top_k: u64,
    pub exact_baseline_external_ids: Vec<u64>,
    pub approximate_result_external_ids: Vec<u64>,
    pub allowed_external_ids: Vec<u64>,
    pub denied_external_ids: Vec<u64>,
    pub exact_recall_at_k_micros: u64,
    pub compressed_recall_at_k_micros: u64,
    pub recall_floor_micros: u64,
    pub max_allowed_delta_micros: u64,
    pub predicted_p50_latency_micros: u64,
    pub predicted_p95_latency_micros: u64,
    pub predicted_p99_latency_micros: u64,
    pub latency_budget_micros: u64,
    pub timeout_micros: u64,
    pub cancellation_deadline_micros: u64,
    pub planned_fixture_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub planned_total_bytes: u64,
    pub memory_budget_bytes: u64,
    pub memory_headroom_bytes: i64,
    pub exact_baseline_ref: String,
    pub fallback_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub shadow_win_recorded: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
}

impl TurboVecRealAdapterShadowReplayCase {
    pub fn recompute_totals(&mut self) {
        self.planned_total_bytes = self
            .planned_fixture_bytes
            .saturating_add(self.planned_scratch_bytes);
        self.memory_headroom_bytes =
            self.memory_budget_bytes as i64 - self.planned_total_bytes as i64;
    }

    pub fn recall_delta_micros(&self) -> u64 {
        self.exact_recall_at_k_micros
            .saturating_sub(self.compressed_recall_at_k_micros)
    }

    pub fn recall_fits(&self) -> bool {
        self.compressed_recall_at_k_micros >= self.recall_floor_micros
            && self.recall_delta_micros() <= self.max_allowed_delta_micros
            && self.compressed_recall_at_k_micros == recall_at_k_micros(self)
    }

    pub fn latency_fits(&self) -> bool {
        self.predicted_p50_latency_micros <= self.predicted_p95_latency_micros
            && self.predicted_p95_latency_micros <= self.latency_budget_micros
            && self.predicted_p99_latency_micros <= self.timeout_micros
    }

    pub fn memory_fits(&self) -> bool {
        self.memory_headroom_bytes >= 0
    }

    pub fn shadow_win_allowed(&self) -> bool {
        self.recall_fits() && self.latency_fits() && self.memory_fits()
    }
}

// UAS: uas:turbovec-real-adapter-shadow:policy
// Plane: Controller + Verification
// Residency: fail-closed replay policy before live route use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterShadowReplayPolicy {
    pub clean_room_adapter_plan_required: bool,
    pub exact_app_cold_store_baseline_required: bool,
    pub held_out_replay_required: bool,
    pub deterministic_seed_required: bool,
    pub uas_allowlist_before_rank_required: bool,
    pub denied_ids_excluded: bool,
    pub fallback_required_for_loss: bool,
    pub cancellation_required: bool,
    pub memory_abstention_required: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub compatibility_fence_required: bool,
    pub no_product_graph_mutation: bool,
    pub no_route_authority: bool,
    pub no_model_context_injection: bool,
    pub no_runtime_execution: bool,
}

impl TurboVecRealAdapterShadowReplayPolicy {
    pub fn fail_closed() -> Self {
        Self {
            clean_room_adapter_plan_required: true,
            exact_app_cold_store_baseline_required: true,
            held_out_replay_required: true,
            deterministic_seed_required: true,
            uas_allowlist_before_rank_required: true,
            denied_ids_excluded: true,
            fallback_required_for_loss: true,
            cancellation_required: true,
            memory_abstention_required: true,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            compatibility_fence_required: true,
            no_product_graph_mutation: true,
            no_route_authority: true,
            no_model_context_injection: true,
            no_runtime_execution: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-shadow:byte-ledger
// Plane: Verification
// Residency: metadata-only shadow replay byte accounting.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterShadowReplayByteLedger {
    pub upstream_motif_source_bytes_cited: u64,
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub planned_replay_bytes: u64,
    pub additional_raw_source_bytes_inspected: u64,
    pub exact_baseline_bytes_opened: u64,
    pub index_bytes_opened: u64,
    pub index_bytes_loaded: u64,
    pub adapter_build_count: u64,
    pub benchmark_run_count: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_model_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
    pub product_graph_mutation_count: u64,
}

impl TurboVecRealAdapterShadowReplayByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        planned_replay_bytes: u64,
    ) -> Result<Self, TurboVecRealAdapterShadowReplayError> {
        if metadata_bytes_read > MAX_METADATA_BYTES
            || fixture_bytes_read > MAX_FIXTURE_BYTES
            || planned_replay_bytes > MAX_PLANNED_REPLAY_BYTES
        {
            return Err(TurboVecRealAdapterShadowReplayError::MetadataBudgetExceeded);
        }
        Ok(Self {
            upstream_motif_source_bytes_cited: UPSTREAM_MOTIF_SOURCE_BYTES,
            metadata_bytes_read,
            fixture_bytes_read,
            planned_replay_bytes,
            additional_raw_source_bytes_inspected: 0,
            exact_baseline_bytes_opened: 0,
            index_bytes_opened: 0,
            index_bytes_loaded: 0,
            adapter_build_count: 0,
            benchmark_run_count: 0,
            allocated_runtime_bytes: 0,
            runtime_model_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
            product_graph_mutation_count: 0,
        })
    }
}

// UAS: uas:turbovec-real-adapter-shadow:proof-refs
// Plane: Verification
// Residency: visible non-promotion proof handles.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterShadowReplayProofRefs {
    pub source_card_ref: String,
    pub no_product_graph_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-real-adapter-shadow:set
// Plane: Assembly + Controller + Verification
// Residency: deterministic metadata-only shadow replay set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterExactBaselineShadowReplayProbeSet {
    pub upstream_clean_room_plan_witness_ref: String,
    pub upstream_clean_room_plan_address: UasAddress,
    pub source_url: String,
    pub pinned_revision: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecRealAdapterShadowReplayStatus,
    pub tier: TurboVecRealAdapterShadowReplayTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub cases: Vec<TurboVecRealAdapterShadowReplayCase>,
    pub policy: TurboVecRealAdapterShadowReplayPolicy,
    pub proof_refs: TurboVecRealAdapterShadowReplayProofRefs,
    pub byte_ledger: TurboVecRealAdapterShadowReplayByteLedger,
    pub hidden_route_authority: bool,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub set_address: UasAddress,
}

impl TurboVecRealAdapterExactBaselineShadowReplayProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_clean_room_plan_address: UasAddress,
        cases: Vec<TurboVecRealAdapterShadowReplayCase>,
        policy: TurboVecRealAdapterShadowReplayPolicy,
        proof_refs: TurboVecRealAdapterShadowReplayProofRefs,
        byte_ledger: TurboVecRealAdapterShadowReplayByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecRealAdapterShadowReplayStatus,
        tier: TurboVecRealAdapterShadowReplayTier,
        hidden_route_authority: bool,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecRealAdapterShadowReplayError> {
        let mut sorted_cases = cases;
        sorted_cases.sort_by(|left, right| left.case_id.cmp(&right.case_id));
        let organs = vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ];
        let mut set = Self {
            upstream_clean_room_plan_witness_ref: CLEAN_ROOM_PLAN_WITNESS_REF.to_string(),
            upstream_clean_room_plan_address,
            source_url: SOURCE_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            product_build,
            pro_status,
            status,
            tier,
            organs,
            cases: sorted_cases,
            policy,
            proof_refs,
            byte_ledger,
            hidden_route_authority,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
            set_address: UasAddress::new(
                UasKind::Other(
                    "turbovec_real_adapter_exact_baseline_shadow_replay_probe".to_string(),
                ),
                b"pending",
                1_779_040_906_000,
            ),
        };
        set.validate()?;
        let digest = exact_baseline_shadow_replay_digest(&set);
        set.set_address = UasAddress::new(
            UasKind::Other("turbovec_real_adapter_exact_baseline_shadow_replay_probe".to_string()),
            digest.as_bytes(),
            1_779_040_906_000,
        );
        Ok(set)
    }

    pub fn metrics(&self) -> TurboVecRealAdapterShadowReplayMetrics {
        let mut metrics = TurboVecRealAdapterShadowReplayMetrics {
            case_count: self.cases.len() as u64,
            upstream_motif_source_bytes_cited: self.byte_ledger.upstream_motif_source_bytes_cited,
            metadata_bytes_read: self.byte_ledger.metadata_bytes_read,
            fixture_bytes_read: self.byte_ledger.fixture_bytes_read,
            planned_replay_bytes: self.byte_ledger.planned_replay_bytes,
            additional_raw_source_bytes_inspected: self
                .byte_ledger
                .additional_raw_source_bytes_inspected,
            exact_baseline_bytes_opened: self.byte_ledger.exact_baseline_bytes_opened,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
            index_bytes_loaded: self.byte_ledger.index_bytes_loaded,
            adapter_build_count: self.byte_ledger.adapter_build_count,
            benchmark_run_count: self.byte_ledger.benchmark_run_count,
            allocated_runtime_bytes: self.byte_ledger.allocated_runtime_bytes,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            product_graph_mutation_count: self.byte_ledger.product_graph_mutation_count,
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
            route_mutation_count: u64::from(self.route_mutation_allowed),
            model_context_injection_count: u64::from(self.model_context_injected),
            ..TurboVecRealAdapterShadowReplayMetrics::default()
        };
        for case in &self.cases {
            match case.scenario {
                TurboVecRealAdapterShadowReplayScenario::WarmExactHit => {
                    metrics.warm_exact_hit_count += 1
                }
                TurboVecRealAdapterShadowReplayScenario::ColdMissFallback => {
                    metrics.cold_miss_fallback_count += 1
                }
                TurboVecRealAdapterShadowReplayScenario::CancellationFallback => {
                    metrics.cancellation_fallback_count += 1
                }
                TurboVecRealAdapterShadowReplayScenario::MemoryPressureAbstain => {
                    metrics.memory_pressure_abstain_count += 1
                }
                TurboVecRealAdapterShadowReplayScenario::EmptyAllowlistVisible => {
                    metrics.empty_allowlist_visible_count += 1
                }
                TurboVecRealAdapterShadowReplayScenario::PrivacyDeniedFallback => {
                    metrics.privacy_denied_fallback_count += 1
                }
                TurboVecRealAdapterShadowReplayScenario::RecallRegressionFallback => {
                    metrics.recall_regression_fallback_count += 1
                }
            }
            if case.shadow_win_recorded {
                metrics.shadow_win_count += 1;
            }
            if case.shadow_win_recorded && !case.shadow_win_allowed() {
                metrics.invalid_shadow_win_count += 1;
            }
            if matches!(
                case.decision,
                TurboVecRealAdapterShadowReplayDecision::RecordShadowLoss
                    | TurboVecRealAdapterShadowReplayDecision::CancelAndFallback
                    | TurboVecRealAdapterShadowReplayDecision::MemoryAbstain
                    | TurboVecRealAdapterShadowReplayDecision::PrivacyFallback
                    | TurboVecRealAdapterShadowReplayDecision::RecallRegressionFallback
            ) {
                metrics.fallback_case_count += 1;
            }
            if case.memory_headroom_bytes < metrics.min_memory_headroom_bytes {
                metrics.min_memory_headroom_bytes = case.memory_headroom_bytes;
            }
            if case.recall_delta_micros() > metrics.max_recall_delta_micros {
                metrics.max_recall_delta_micros = case.recall_delta_micros();
            }
        }
        metrics
    }

    fn validate(&self) -> Result<(), TurboVecRealAdapterShadowReplayError> {
        if self.upstream_clean_room_plan_witness_ref != CLEAN_ROOM_PLAN_WITNESS_REF
            || !self
                .upstream_clean_room_plan_address
                .to_string()
                .starts_with(CLEAN_ROOM_PLAN_ADDRESS_PREFIX)
        {
            return Err(TurboVecRealAdapterShadowReplayError::UpstreamPlanNotBound);
        }
        if self.source_url != SOURCE_URL || self.pinned_revision != PINNED_REVISION {
            return Err(TurboVecRealAdapterShadowReplayError::BadSourceIdentity);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.status != TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay
            || self.tier != TurboVecRealAdapterShadowReplayTier::T1L1Metadata
        {
            return Err(TurboVecRealAdapterShadowReplayError::PromotionBoundaryViolation);
        }
        for organ in [
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ] {
            if !self.organs.contains(&organ) {
                return Err(TurboVecRealAdapterShadowReplayError::MissingRequiredOrgan(
                    organ,
                ));
            }
        }
        validate_policy(&self.policy)?;
        validate_cases(&self.cases)?;
        validate_proofs(&self.proof_refs)?;
        validate_bytes(&self.byte_ledger)?;
        if self.hidden_route_authority
            || self.product_capability_promoted
            || self.route_mutation_allowed
            || self.model_context_injected
            || self.hidden_cloud_fallback_allowed
            || self.live_large_model_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(TurboVecRealAdapterShadowReplayError::ClaimBoundaryViolation);
        }
        Ok(())
    }
}

// UAS: uas:turbovec-real-adapter-shadow:metrics
// Plane: Verification
// Residency: artifact axes for shadow replay proof.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecRealAdapterShadowReplayMetrics {
    pub case_count: u64,
    pub warm_exact_hit_count: u64,
    pub cold_miss_fallback_count: u64,
    pub cancellation_fallback_count: u64,
    pub memory_pressure_abstain_count: u64,
    pub empty_allowlist_visible_count: u64,
    pub privacy_denied_fallback_count: u64,
    pub recall_regression_fallback_count: u64,
    pub shadow_win_count: u64,
    pub invalid_shadow_win_count: u64,
    pub fallback_case_count: u64,
    pub min_memory_headroom_bytes: i64,
    pub max_recall_delta_micros: u64,
    pub upstream_motif_source_bytes_cited: u64,
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub planned_replay_bytes: u64,
    pub additional_raw_source_bytes_inspected: u64,
    pub exact_baseline_bytes_opened: u64,
    pub index_bytes_opened: u64,
    pub index_bytes_loaded: u64,
    pub adapter_build_count: u64,
    pub benchmark_run_count: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_model_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
    pub product_graph_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
}

// UAS: uas:turbovec-real-adapter-shadow:error
// Plane: Verification
// Residency: validation failures for unsafe shadow replay states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecRealAdapterShadowReplayError {
    UpstreamPlanNotBound,
    BadSourceIdentity,
    PromotionBoundaryViolation,
    MissingRequiredOrgan(TurboVecIndexOrgan),
    UnsafePolicy,
    TooFewCases,
    MissingScenario(TurboVecRealAdapterShadowReplayScenario),
    DuplicateCaseId(String),
    InvalidCase(String),
    InvalidRecall(String),
    InvalidDecision(String),
    RuntimeOrIndexNotDeferred,
    BadProofRef(String),
    WeakVisibleSummary,
    MetadataBudgetExceeded,
    ClaimBoundaryViolation,
}

impl fmt::Display for TurboVecRealAdapterShadowReplayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UpstreamPlanNotBound => write!(f, "upstream clean-room adapter plan not bound"),
            Self::BadSourceIdentity => write!(f, "source URL or pinned revision mismatch"),
            Self::PromotionBoundaryViolation => write!(f, "shadow replay attempted promotion"),
            Self::MissingRequiredOrgan(organ) => write!(f, "missing required organ {organ:?}"),
            Self::UnsafePolicy => write!(f, "shadow replay policy is not fail-closed"),
            Self::TooFewCases => write!(f, "too few shadow replay cases"),
            Self::MissingScenario(scenario) => write!(f, "missing scenario {scenario:?}"),
            Self::DuplicateCaseId(id) => write!(f, "duplicate case id {id}"),
            Self::InvalidCase(id) => write!(f, "invalid replay case {id}"),
            Self::InvalidRecall(id) => write!(f, "invalid recall accounting for {id}"),
            Self::InvalidDecision(id) => write!(f, "invalid shadow decision for {id}"),
            Self::RuntimeOrIndexNotDeferred => {
                write!(f, "runtime or index bytes were not deferred")
            }
            Self::BadProofRef(value) => write!(f, "bad proof ref {value}"),
            Self::WeakVisibleSummary => write!(f, "visible summary lacks required caveats"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::ClaimBoundaryViolation => {
                write!(f, "hidden authority or product claim attempted")
            }
        }
    }
}

impl std::error::Error for TurboVecRealAdapterShadowReplayError {}

fn validate_policy(
    policy: &TurboVecRealAdapterShadowReplayPolicy,
) -> Result<(), TurboVecRealAdapterShadowReplayError> {
    if policy.clean_room_adapter_plan_required
        && policy.exact_app_cold_store_baseline_required
        && policy.held_out_replay_required
        && policy.deterministic_seed_required
        && policy.uas_allowlist_before_rank_required
        && policy.denied_ids_excluded
        && policy.fallback_required_for_loss
        && policy.cancellation_required
        && policy.memory_abstention_required
        && policy.answer_packet_required
        && policy.run_event_log_required
        && policy.rollback_required
        && policy.compatibility_fence_required
        && policy.no_product_graph_mutation
        && policy.no_route_authority
        && policy.no_model_context_injection
        && policy.no_runtime_execution
    {
        Ok(())
    } else {
        Err(TurboVecRealAdapterShadowReplayError::UnsafePolicy)
    }
}

fn validate_cases(
    cases: &[TurboVecRealAdapterShadowReplayCase],
) -> Result<(), TurboVecRealAdapterShadowReplayError> {
    if cases.len() < 7 {
        return Err(TurboVecRealAdapterShadowReplayError::TooFewCases);
    }
    let mut ids = HashSet::with_capacity(cases.len());
    let scenarios = cases
        .iter()
        .map(|case| case.scenario)
        .collect::<BTreeSet<_>>();
    for required in [
        TurboVecRealAdapterShadowReplayScenario::WarmExactHit,
        TurboVecRealAdapterShadowReplayScenario::ColdMissFallback,
        TurboVecRealAdapterShadowReplayScenario::CancellationFallback,
        TurboVecRealAdapterShadowReplayScenario::MemoryPressureAbstain,
        TurboVecRealAdapterShadowReplayScenario::EmptyAllowlistVisible,
        TurboVecRealAdapterShadowReplayScenario::PrivacyDeniedFallback,
        TurboVecRealAdapterShadowReplayScenario::RecallRegressionFallback,
    ] {
        if !scenarios.contains(&required) {
            return Err(TurboVecRealAdapterShadowReplayError::MissingScenario(
                required,
            ));
        }
    }
    for case in cases {
        if !ids.insert(case.case_id.as_str()) {
            return Err(TurboVecRealAdapterShadowReplayError::DuplicateCaseId(
                case.case_id.clone(),
            ));
        }
        validate_case(case)?;
    }
    Ok(())
}

fn validate_case(
    case: &TurboVecRealAdapterShadowReplayCase,
) -> Result<(), TurboVecRealAdapterShadowReplayError> {
    if case.case_id.trim().is_empty()
        || !case.query_ref.starts_with(QUERY_REF_PREFIX)
        || !case.clean_room_plan_ref.starts_with(PLAN_REF_PREFIX)
        || !case
            .exact_baseline_ref
            .starts_with(EXACT_BASELINE_REF_PREFIX)
        || !case.fallback_ref.starts_with(FALLBACK_REF_PREFIX)
        || !case.rollback_ref.starts_with(ROLLBACK_REF_PREFIX)
        || !case.run_event_log_ref.starts_with(RUN_EVENT_LOG_REF_PREFIX)
        || !case.answer_packet_ref.starts_with(ANSWER_PACKET_REF_PREFIX)
        || case.replay_seed == 0
        || case.sample_count < MIN_SAMPLE_COUNT
        || case.sample_count > MAX_SAMPLE_COUNT
        || case.top_k == 0
        || case.top_k > MAX_TOP_K
        || case.recall_floor_micros != RECALL_FLOOR_MICROS
        || case.max_allowed_delta_micros != MAX_ALLOWED_DELTA_MICROS
        || case.cancellation_deadline_micros == 0
        || case.timeout_micros == 0
        || case.cancellation_deadline_micros > case.timeout_micros
        || case.predicted_p50_latency_micros > case.predicted_p95_latency_micros
        || case.predicted_p95_latency_micros > case.predicted_p99_latency_micros
        || case.planned_total_bytes != case.planned_fixture_bytes + case.planned_scratch_bytes
        || case.memory_headroom_bytes
            != case.memory_budget_bytes as i64 - case.planned_total_bytes as i64
        || case.route_mutation_allowed
        || case.model_context_injected
    {
        return Err(TurboVecRealAdapterShadowReplayError::InvalidCase(
            case.case_id.clone(),
        ));
    }
    let allowed = case
        .allowed_external_ids
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    let denied = case
        .denied_external_ids
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    if has_duplicates(&case.exact_baseline_external_ids)
        || has_duplicates(&case.approximate_result_external_ids)
        || has_duplicates(&case.allowed_external_ids)
        || case
            .approximate_result_external_ids
            .iter()
            .any(|id| !allowed.contains(id) || denied.contains(id))
        || case
            .exact_baseline_external_ids
            .iter()
            .any(|id| denied.contains(id))
    {
        return Err(TurboVecRealAdapterShadowReplayError::InvalidRecall(
            case.case_id.clone(),
        ));
    }
    if case.compressed_recall_at_k_micros != recall_at_k_micros(case) {
        return Err(TurboVecRealAdapterShadowReplayError::InvalidRecall(
            case.case_id.clone(),
        ));
    }
    validate_decision(case)
}

fn validate_decision(
    case: &TurboVecRealAdapterShadowReplayCase,
) -> Result<(), TurboVecRealAdapterShadowReplayError> {
    match case.decision {
        TurboVecRealAdapterShadowReplayDecision::RecordShadowWin => {
            if !matches!(
                case.scenario,
                TurboVecRealAdapterShadowReplayScenario::WarmExactHit
            ) || !case.shadow_win_recorded
                || !case.shadow_win_allowed()
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
        TurboVecRealAdapterShadowReplayDecision::RecordShadowLoss => {
            if case.shadow_win_recorded
                || case.recall_fits()
                || case.fallback_ref.len() <= FALLBACK_REF_PREFIX.len()
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
        TurboVecRealAdapterShadowReplayDecision::CancelAndFallback => {
            if case.shadow_win_recorded
                || !matches!(
                    case.scenario,
                    TurboVecRealAdapterShadowReplayScenario::CancellationFallback
                )
                || case.predicted_p99_latency_micros <= case.timeout_micros
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
        TurboVecRealAdapterShadowReplayDecision::MemoryAbstain => {
            if case.shadow_win_recorded
                || !matches!(
                    case.scenario,
                    TurboVecRealAdapterShadowReplayScenario::MemoryPressureAbstain
                )
                || case.memory_fits()
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
        TurboVecRealAdapterShadowReplayDecision::EmptyVisible => {
            if case.shadow_win_recorded
                || !matches!(
                    case.scenario,
                    TurboVecRealAdapterShadowReplayScenario::EmptyAllowlistVisible
                )
                || !case.allowed_external_ids.is_empty()
                || !case.approximate_result_external_ids.is_empty()
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
        TurboVecRealAdapterShadowReplayDecision::PrivacyFallback => {
            if case.shadow_win_recorded
                || !matches!(
                    case.scenario,
                    TurboVecRealAdapterShadowReplayScenario::PrivacyDeniedFallback
                )
                || case.denied_external_ids.is_empty()
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
        TurboVecRealAdapterShadowReplayDecision::RecallRegressionFallback => {
            if case.shadow_win_recorded
                || !matches!(
                    case.scenario,
                    TurboVecRealAdapterShadowReplayScenario::RecallRegressionFallback
                )
                || case.recall_fits()
            {
                return Err(TurboVecRealAdapterShadowReplayError::InvalidDecision(
                    case.case_id.clone(),
                ));
            }
        }
    }
    Ok(())
}

fn validate_proofs(
    refs: &TurboVecRealAdapterShadowReplayProofRefs,
) -> Result<(), TurboVecRealAdapterShadowReplayError> {
    for (value, prefix) in [
        (&refs.source_card_ref, SOURCE_CARD_REF_PREFIX),
        (&refs.no_product_graph_ref, NO_PRODUCT_GRAPH_REF_PREFIX),
        (&refs.rollback_ref, ROLLBACK_REF_PREFIX),
        (&refs.run_event_log_ref, RUN_EVENT_LOG_REF_PREFIX),
        (&refs.answer_packet_ref, ANSWER_PACKET_REF_PREFIX),
        (&refs.compatibility_fence_ref, COMPATIBILITY_REF_PREFIX),
    ] {
        if !value.starts_with(prefix) {
            return Err(TurboVecRealAdapterShadowReplayError::BadProofRef(
                value.clone(),
            ));
        }
    }
    let summary = refs.visible_summary.to_ascii_lowercase();
    if refs.visible_summary.len() < 520
        || !summary.contains("exact-baseline")
        || !summary.contains("shadow replay")
        || !summary.contains("large local model")
        || !summary.contains("no hidden route authority")
        || !summary.contains("no live dense 70b")
        || !summary.contains("answerpacket")
    {
        return Err(TurboVecRealAdapterShadowReplayError::WeakVisibleSummary);
    }
    Ok(())
}

fn validate_bytes(
    ledger: &TurboVecRealAdapterShadowReplayByteLedger,
) -> Result<(), TurboVecRealAdapterShadowReplayError> {
    if ledger.upstream_motif_source_bytes_cited != UPSTREAM_MOTIF_SOURCE_BYTES
        || ledger.metadata_bytes_read == 0
        || ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || ledger.fixture_bytes_read == 0
        || ledger.fixture_bytes_read > MAX_FIXTURE_BYTES
        || ledger.planned_replay_bytes == 0
        || ledger.planned_replay_bytes > MAX_PLANNED_REPLAY_BYTES
        || ledger.additional_raw_source_bytes_inspected != 0
        || ledger.exact_baseline_bytes_opened != 0
        || ledger.index_bytes_opened != 0
        || ledger.index_bytes_loaded != 0
        || ledger.adapter_build_count != 0
        || ledger.benchmark_run_count != 0
        || ledger.allocated_runtime_bytes != 0
        || ledger.runtime_model_bytes_loaded != 0
        || ledger.model_bytes_loaded != 0
        || ledger.provider_calls_made != 0
        || ledger.copied_product_file_count != 0
        || ledger.product_graph_mutation_count != 0
    {
        return Err(TurboVecRealAdapterShadowReplayError::RuntimeOrIndexNotDeferred);
    }
    Ok(())
}

pub fn recall_at_k_micros(case: &TurboVecRealAdapterShadowReplayCase) -> u64 {
    if case.top_k == 0 || case.exact_baseline_external_ids.is_empty() {
        return 0;
    }
    let exact = case
        .exact_baseline_external_ids
        .iter()
        .take(case.top_k as usize)
        .copied()
        .collect::<BTreeSet<_>>();
    if exact.is_empty() {
        return 0;
    }
    let hits = case
        .approximate_result_external_ids
        .iter()
        .take(case.top_k as usize)
        .filter(|id| exact.contains(id))
        .count() as u64;
    hits.saturating_mul(1_000_000) / exact.len() as u64
}

fn has_duplicates(values: &[u64]) -> bool {
    let mut seen = HashSet::with_capacity(values.len());
    values.iter().any(|value| !seen.insert(*value))
}

pub fn exact_baseline_shadow_replay_digest(
    set: &TurboVecRealAdapterExactBaselineShadowReplayProbeSet,
) -> String {
    let mut cases = set.cases.clone();
    cases.sort_by(|left, right| left.case_id.cmp(&right.case_id));
    sha256_hex(
        serde_json::to_string(&serde_json::json!({
            "upstream_clean_room_plan_witness_ref": set.upstream_clean_room_plan_witness_ref,
            "upstream_clean_room_plan_address": set.upstream_clean_room_plan_address.to_string(),
            "source_url": set.source_url,
            "pinned_revision": set.pinned_revision,
            "product_build": set.product_build,
            "pro_status": set.pro_status,
            "status": set.status,
            "tier": set.tier,
            "organs": set.organs,
            "cases": cases,
            "policy": set.policy,
            "proof_refs": set.proof_refs,
            "byte_ledger": set.byte_ledger,
            "hidden_route_authority": set.hidden_route_authority,
            "product_capability_promoted": set.product_capability_promoted,
            "route_mutation_allowed": set.route_mutation_allowed,
            "model_context_injected": set.model_context_injected,
            "hidden_cloud_fallback_allowed": set.hidden_cloud_fallback_allowed,
            "live_large_model_claimed": set.live_large_model_claimed,
            "ssd_as_ram_claimed": set.ssd_as_ram_claimed,
        }))
        .unwrap_or_default()
        .as_bytes(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_clean_room_adapter_plan_probe".to_string()),
            b"accepted-adapter-plan",
            1_779_040_905_000,
        )
    }

    fn ids(start: u64, count: u64) -> Vec<u64> {
        (start..start + count).collect()
    }

    fn case(
        case_id: &str,
        scenario: TurboVecRealAdapterShadowReplayScenario,
        decision: TurboVecRealAdapterShadowReplayDecision,
        exact: Vec<u64>,
        approx: Vec<u64>,
        allowed: Vec<u64>,
    ) -> TurboVecRealAdapterShadowReplayCase {
        let denied = ids(9_000, 3);
        let exact_recall_at_k_micros = if exact.is_empty() { 0 } else { 1_000_000 };
        let mut replay = TurboVecRealAdapterShadowReplayCase {
            case_id: case_id.to_string(),
            scenario,
            decision,
            query_ref: format!("{QUERY_REF_PREFIX}{case_id}"),
            clean_room_plan_ref: format!("{PLAN_REF_PREFIX}exact-baseline-shadow-replay"),
            replay_seed: 1_700 + case_id.len() as u64,
            sample_count: 64,
            top_k: 5,
            exact_baseline_external_ids: exact,
            approximate_result_external_ids: approx,
            allowed_external_ids: allowed,
            denied_external_ids: denied,
            exact_recall_at_k_micros,
            compressed_recall_at_k_micros: 0,
            recall_floor_micros: RECALL_FLOOR_MICROS,
            max_allowed_delta_micros: MAX_ALLOWED_DELTA_MICROS,
            predicted_p50_latency_micros: 4_000,
            predicted_p95_latency_micros: 8_000,
            predicted_p99_latency_micros: 11_000,
            latency_budget_micros: 12_000,
            timeout_micros: 18_000,
            cancellation_deadline_micros: 16_000,
            planned_fixture_bytes: 8_192,
            planned_scratch_bytes: 16_384,
            planned_total_bytes: 0,
            memory_budget_bytes: 64_000,
            memory_headroom_bytes: 0,
            exact_baseline_ref: format!("{EXACT_BASELINE_REF_PREFIX}{case_id}"),
            fallback_ref: format!("{FALLBACK_REF_PREFIX}{case_id}"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}{case_id}"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}{case_id}"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}{case_id}"),
            shadow_win_recorded: matches!(
                decision,
                TurboVecRealAdapterShadowReplayDecision::RecordShadowWin
            ),
            route_mutation_allowed: false,
            model_context_injected: false,
        };
        replay.recompute_totals();
        replay.compressed_recall_at_k_micros = recall_at_k_micros(&replay);
        replay
    }

    fn cases() -> Vec<TurboVecRealAdapterShadowReplayCase> {
        let mut warm = case(
            "warm_exact_hit",
            TurboVecRealAdapterShadowReplayScenario::WarmExactHit,
            TurboVecRealAdapterShadowReplayDecision::RecordShadowWin,
            ids(1, 5),
            ids(1, 5),
            ids(1, 8),
        );
        warm.shadow_win_recorded = true;

        let cold = case(
            "cold_miss_fallback",
            TurboVecRealAdapterShadowReplayScenario::ColdMissFallback,
            TurboVecRealAdapterShadowReplayDecision::RecordShadowLoss,
            ids(11, 5),
            vec![11, 16],
            ids(11, 8),
        );

        let mut cancel = case(
            "cancellation_fallback",
            TurboVecRealAdapterShadowReplayScenario::CancellationFallback,
            TurboVecRealAdapterShadowReplayDecision::CancelAndFallback,
            ids(21, 5),
            ids(21, 5),
            ids(21, 8),
        );
        cancel.predicted_p99_latency_micros = 21_000;

        let mut memory = case(
            "memory_pressure_abstain",
            TurboVecRealAdapterShadowReplayScenario::MemoryPressureAbstain,
            TurboVecRealAdapterShadowReplayDecision::MemoryAbstain,
            ids(31, 5),
            ids(31, 5),
            ids(31, 8),
        );
        memory.memory_budget_bytes = 12_000;
        memory.recompute_totals();

        let empty = case(
            "empty_allowlist_visible",
            TurboVecRealAdapterShadowReplayScenario::EmptyAllowlistVisible,
            TurboVecRealAdapterShadowReplayDecision::EmptyVisible,
            Vec::new(),
            Vec::new(),
            Vec::new(),
        );

        let privacy = case(
            "privacy_denied_fallback",
            TurboVecRealAdapterShadowReplayScenario::PrivacyDeniedFallback,
            TurboVecRealAdapterShadowReplayDecision::PrivacyFallback,
            ids(41, 5),
            vec![41, 42],
            ids(41, 8),
        );

        let regression = case(
            "recall_regression_fallback",
            TurboVecRealAdapterShadowReplayScenario::RecallRegressionFallback,
            TurboVecRealAdapterShadowReplayDecision::RecallRegressionFallback,
            ids(51, 5),
            vec![51, 52, 56],
            ids(51, 8),
        );

        vec![warm, cold, cancel, memory, empty, privacy, regression]
    }

    fn proofs() -> TurboVecRealAdapterShadowReplayProofRefs {
        TurboVecRealAdapterShadowReplayProofRefs {
            source_card_ref: format!("{SOURCE_CARD_REF_PREFIX}accepted"),
            no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}accepted"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}accepted"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}accepted"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}accepted"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}accepted"),
            visible_summary: "This exact-baseline shadow replay contract keeps the clean-room TurboVec adapter plan as proposal-only evidence for large local model working sets. It requires AppColdStore exact-baseline comparison, UAS allowlist-before-rank filtering, deterministic held-out replay, cancellation, latency and memory abstention, rollback, RunEventLog, and AnswerPacket visibility. It has no hidden route authority, no live dense 70B claim, no benchmark authority, no adapter build, no product graph mutation, no source import, no runtime bytes, and no L2/L3 product promotion before later witnesses prove real runtime behavior."
                .to_string(),
        }
    }

    fn accepted() -> Result<
        TurboVecRealAdapterExactBaselineShadowReplayProbeSet,
        TurboVecRealAdapterShadowReplayError,
    > {
        TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
            upstream(),
            cases(),
            TurboVecRealAdapterShadowReplayPolicy::fail_closed(),
            proofs(),
            TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)?,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
    }

    #[test]
    fn accepts_exact_baseline_shadow_replay() {
        let set = accepted().expect("accepted shadow replay");
        let metrics = set.metrics();
        assert_eq!(metrics.case_count, 7);
        assert_eq!(metrics.shadow_win_count, 1);
        assert_eq!(metrics.invalid_shadow_win_count, 0);
        assert_eq!(metrics.exact_baseline_bytes_opened, 0);
        assert_eq!(metrics.product_graph_mutation_count, 0);
    }

    #[test]
    fn address_is_deterministic_when_cases_reordered() {
        let left = accepted().expect("accepted shadow replay");
        let mut reversed_cases = cases();
        reversed_cases.reverse();
        let right = TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
            upstream(),
            reversed_cases,
            TurboVecRealAdapterShadowReplayPolicy::fail_closed(),
            proofs(),
            TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)
                .expect("byte ledger"),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("reordered shadow replay");
        assert_eq!(left.set_address, right.set_address);
    }

    #[test]
    fn rejects_bad_recall_and_authority() {
        let mut bad = cases();
        bad[0].approximate_result_external_ids.push(9_000);
        bad[0].compressed_recall_at_k_micros = recall_at_k_micros(&bad[0]);
        assert!(matches!(
            TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
                upstream(),
                bad,
                TurboVecRealAdapterShadowReplayPolicy::fail_closed(),
                proofs(),
                TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)
                    .expect("byte ledger"),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecRealAdapterShadowReplayError::InvalidRecall(_))
        ));

        assert!(matches!(
            TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
                upstream(),
                cases(),
                TurboVecRealAdapterShadowReplayPolicy::fail_closed(),
                proofs(),
                TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)
                    .expect("byte ledger"),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                true,
                false,
                true,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecRealAdapterShadowReplayError::ClaimBoundaryViolation)
        ));
    }

    #[test]
    fn rejects_runtime_bytes_and_promotion() {
        let mut ledger =
            TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)
                .expect("byte ledger");
        ledger.index_bytes_opened = 1;
        assert!(matches!(
            TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
                upstream(),
                cases(),
                TurboVecRealAdapterShadowReplayPolicy::fail_closed(),
                proofs(),
                ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecRealAdapterShadowReplayError::RuntimeOrIndexNotDeferred)
        ));

        assert!(matches!(
            TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
                upstream(),
                cases(),
                TurboVecRealAdapterShadowReplayPolicy::fail_closed(),
                proofs(),
                TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)
                    .expect("byte ledger"),
                ProductBuild::Mas,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecRealAdapterShadowReplayError::PromotionBoundaryViolation)
        ));
    }
}
