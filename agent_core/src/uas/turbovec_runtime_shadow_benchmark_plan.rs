//! TurboVec runtime shadow benchmark plan.
//!
//! This primitive is still metadata-only. It defines the tiny replay contract a
//! quarantined TurboVec/Eidos adapter must satisfy before compressed retrieval
//! can become evidence for large-local-model context selection. Shadow results
//! are visible proof material only: they cannot mutate routes, inject model
//! context, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_RUNTIME_SHADOW_BENCHMARK_CURSOR: &str = "turbovec_runtime_shadow_benchmark_plan";
pub const TURBOVEC_RUNTIME_SHADOW_BENCHMARK_NEXT_CURSOR: &str =
    "turbovec_quarantine_adapter_microbench_probe";

const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_latency_memory_abstention:result";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const FALLBACK_PREFIX: &str = "fallback:";
const SHADOW_REASON_PREFIX: &str = "shadow:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_FIXTURE_BYTES: u64 = 128 * 1024;
const MAX_TOP_K: u64 = 50;
const MIN_REPLAY_SAMPLE_COUNT: u64 = 30;
const MAX_REPLAY_SAMPLE_COUNT: u64 = 10_000;

// UAS: uas:turbovec-shadow-benchmark:status
// Plane: Verification
// Residency: metadata-only shadow-benchmark status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRuntimeShadowStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-shadow-benchmark:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRuntimeShadowPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-shadow-benchmark:scenario
// Plane: Verification
// Residency: tiny replay scenario class.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRuntimeShadowScenario {
    WarmHitReplay,
    ColdMissReplay,
    CancellationReplay,
    MemoryPressureReplay,
    EmptyAllowlistReplay,
    RecallRegressionReplay,
}

// UAS: uas:turbovec-shadow-benchmark:decision
// Plane: Controller + Verification
// Residency: non-authoritative shadow result.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRuntimeShadowDecision {
    RecordShadowWin,
    RecordShadowLoss,
    CancelAndFallback,
    MemoryAbstain,
    EmptyVisible,
    RecallRegressionFallback,
}

// UAS: uas:turbovec-shadow-benchmark:case
// Plane: Assembly + Controller + Verification
// Residency: planned tiny replay; no runtime/index/model bytes are opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowReplayCase {
    pub case_id: String,
    pub scenario: TurboVecRuntimeShadowScenario,
    pub query_uas_address: UasAddress,
    pub replay_seed: u64,
    pub sample_count: u64,
    pub top_k: u64,
    pub planned_candidate_count: u64,
    pub exact_recall_at_k_micros: u64,
    pub compressed_recall_at_k_micros: u64,
    pub recall_floor_micros: u64,
    pub max_allowed_recall_delta_micros: u64,
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
    pub decision: TurboVecRuntimeShadowDecision,
    pub shadow_win_recorded: bool,
    pub shadow_reason_ref: Option<String>,
    pub fallback_route_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
}

impl TurboVecRuntimeShadowReplayCase {
    pub fn recompute_totals(&mut self) {
        self.planned_total_bytes = self
            .planned_fixture_bytes
            .saturating_add(self.planned_scratch_bytes);
        self.memory_headroom_bytes =
            self.memory_budget_bytes as i64 - self.planned_total_bytes as i64;
    }

    pub fn latency_fits(&self) -> bool {
        self.predicted_p95_latency_micros <= self.latency_budget_micros
            && self.predicted_p99_latency_micros <= self.timeout_micros
    }

    pub fn memory_fits(&self) -> bool {
        self.memory_headroom_bytes >= 0
    }

    pub fn recall_delta_micros(&self) -> u64 {
        self.exact_recall_at_k_micros
            .saturating_sub(self.compressed_recall_at_k_micros)
    }

    pub fn recall_fits(&self) -> bool {
        self.compressed_recall_at_k_micros >= self.recall_floor_micros
            && self.recall_delta_micros() <= self.max_allowed_recall_delta_micros
    }

    pub fn shadow_win_allowed(&self) -> bool {
        self.latency_fits() && self.memory_fits() && self.recall_fits()
    }
}

// UAS: uas:turbovec-shadow-benchmark:policy
// Plane: Controller + Verification
// Residency: fail-closed shadow replay policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowPolicy {
    pub latency_memory_witness_required: bool,
    pub exact_baseline_replay_required: bool,
    pub deterministic_seed_required: bool,
    pub min_sample_count_required: bool,
    pub shadow_only_required: bool,
    pub route_mutation_forbidden: bool,
    pub model_context_injection_forbidden: bool,
    pub fallback_required_for_loss: bool,
    pub cancellation_required: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub compatibility_fence_required: bool,
    pub quarantine_adapter_required_before_runtime: bool,
}

impl TurboVecRuntimeShadowPolicy {
    pub fn fail_closed() -> Self {
        Self {
            latency_memory_witness_required: true,
            exact_baseline_replay_required: true,
            deterministic_seed_required: true,
            min_sample_count_required: true,
            shadow_only_required: true,
            route_mutation_forbidden: true,
            model_context_injection_forbidden: true,
            fallback_required_for_loss: true,
            cancellation_required: true,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            compatibility_fence_required: true,
            quarantine_adapter_required_before_runtime: true,
        }
    }
}

// UAS: uas:turbovec-shadow-benchmark:byte-ledger
// Plane: Verification
// Residency: metadata-only proof boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowByteLedger {
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub planned_replay_bytes: u64,
    pub opened_index_bytes: u64,
    pub loaded_index_bytes: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecRuntimeShadowByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        planned_replay_bytes: u64,
    ) -> Result<Self, TurboVecRuntimeShadowError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
            return Err(TurboVecRuntimeShadowError::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            });
        }
        Ok(Self {
            metadata_bytes_read,
            fixture_bytes_read,
            planned_replay_bytes,
            opened_index_bytes: 0,
            loaded_index_bytes: 0,
            allocated_runtime_bytes: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        })
    }
}

// UAS: uas:turbovec-shadow-benchmark:proof-refs
// Plane: Verification
// Residency: visible witness surfaces for non-promotion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-shadow-benchmark:plan
// Plane: Assembly + Controller + Verification
// Residency: metadata-only shadow replay plan.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowBenchmarkPlan {
    pub plan_id: String,
    pub upstream_latency_memory_address: UasAddress,
    pub upstream_latency_memory_witness_ref: String,
    pub status: TurboVecRuntimeShadowStatus,
    pub promotion_tier: TurboVecRuntimeShadowPromotionTier,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecRuntimeShadowPolicy,
    pub replay_cases: Vec<TurboVecRuntimeShadowReplayCase>,
    pub byte_ledger: TurboVecRuntimeShadowByteLedger,
    pub proof_refs: TurboVecRuntimeShadowProofRefs,
    pub hidden_route_authority: bool,
    pub product_capability_promoted: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-shadow-benchmark:plan-set
// Plane: Verification
// Residency: deterministic set-level witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowBenchmarkPlanSet {
    pub set_address: UasAddress,
    pub upstream_latency_memory_address: UasAddress,
    pub upstream_latency_memory_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecRuntimeShadowStatus,
    pub promotion_tier: TurboVecRuntimeShadowPromotionTier,
    pub plans: Vec<TurboVecRuntimeShadowBenchmarkPlan>,
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub product_capability_promoted: bool,
}

// UAS: uas:turbovec-shadow-benchmark:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecRuntimeShadowMetrics {
    pub plan_count: u64,
    pub case_count: u64,
    pub warm_hit_case_count: u64,
    pub cold_miss_case_count: u64,
    pub cancellation_case_count: u64,
    pub memory_pressure_case_count: u64,
    pub empty_allowlist_case_count: u64,
    pub recall_regression_case_count: u64,
    pub shadow_win_count: u64,
    pub fallback_case_count: u64,
    pub invalid_win_count: u64,
    pub missing_reason_count: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub min_sample_count: u64,
    pub max_predicted_p99_latency_micros: u64,
    pub max_planned_total_bytes: u64,
    pub min_memory_headroom_bytes: i64,
    pub max_recall_delta_micros: u64,
    pub opened_index_bytes: u64,
    pub loaded_index_bytes: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecRuntimeShadowBenchmarkPlanSet {
    pub fn from_plans(
        upstream_latency_memory_address: UasAddress,
        mut plans: Vec<TurboVecRuntimeShadowBenchmarkPlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecRuntimeShadowStatus,
        promotion_tier: TurboVecRuntimeShadowPromotionTier,
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        product_capability_promoted: bool,
    ) -> Result<Self, TurboVecRuntimeShadowError> {
        plans.sort_by(|left, right| left.plan_id.cmp(&right.plan_id));
        validate_set_inputs(
            &upstream_latency_memory_address,
            &plans,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            metadata_bytes_read,
            fixture_bytes_read,
            product_capability_promoted,
        )?;
        for plan in &plans {
            validate_plan(plan, &upstream_latency_memory_address)?;
        }
        let set_address =
            deterministic_set_address(&plans, metadata_bytes_read, fixture_bytes_read);
        Ok(Self {
            set_address,
            upstream_latency_memory_address,
            upstream_latency_memory_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            plans,
            metadata_bytes_read,
            fixture_bytes_read,
            product_capability_promoted,
        })
    }

    pub fn metrics(&self) -> TurboVecRuntimeShadowMetrics {
        let mut metrics = TurboVecRuntimeShadowMetrics {
            plan_count: self.plans.len() as u64,
            min_sample_count: u64::MAX,
            min_memory_headroom_bytes: i64::MAX,
            ..TurboVecRuntimeShadowMetrics::default()
        };
        for plan in &self.plans {
            metrics.opened_index_bytes += plan.byte_ledger.opened_index_bytes;
            metrics.loaded_index_bytes += plan.byte_ledger.loaded_index_bytes;
            metrics.allocated_runtime_bytes += plan.byte_ledger.allocated_runtime_bytes;
            metrics.runtime_bytes_loaded += plan.byte_ledger.runtime_bytes_loaded;
            metrics.model_bytes_loaded += plan.byte_ledger.model_bytes_loaded;
            metrics.provider_calls_made += plan.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += plan.byte_ledger.copied_product_file_count;

            for case in &plan.replay_cases {
                metrics.case_count += 1;
                metrics.min_sample_count = metrics.min_sample_count.min(case.sample_count);
                metrics.max_predicted_p99_latency_micros = metrics
                    .max_predicted_p99_latency_micros
                    .max(case.predicted_p99_latency_micros);
                metrics.max_planned_total_bytes = metrics
                    .max_planned_total_bytes
                    .max(case.planned_total_bytes);
                metrics.min_memory_headroom_bytes = metrics
                    .min_memory_headroom_bytes
                    .min(case.memory_headroom_bytes);
                metrics.max_recall_delta_micros = metrics
                    .max_recall_delta_micros
                    .max(case.recall_delta_micros());
                match case.scenario {
                    TurboVecRuntimeShadowScenario::WarmHitReplay => {
                        metrics.warm_hit_case_count += 1
                    }
                    TurboVecRuntimeShadowScenario::ColdMissReplay => {
                        metrics.cold_miss_case_count += 1
                    }
                    TurboVecRuntimeShadowScenario::CancellationReplay => {
                        metrics.cancellation_case_count += 1
                    }
                    TurboVecRuntimeShadowScenario::MemoryPressureReplay => {
                        metrics.memory_pressure_case_count += 1
                    }
                    TurboVecRuntimeShadowScenario::EmptyAllowlistReplay => {
                        metrics.empty_allowlist_case_count += 1
                    }
                    TurboVecRuntimeShadowScenario::RecallRegressionReplay => {
                        metrics.recall_regression_case_count += 1
                    }
                }
                if case.shadow_win_recorded {
                    metrics.shadow_win_count += 1;
                    if !case.shadow_win_allowed()
                        || !matches!(
                            case.decision,
                            TurboVecRuntimeShadowDecision::RecordShadowWin
                        )
                    {
                        metrics.invalid_win_count += 1;
                    }
                }
                if !matches!(
                    case.decision,
                    TurboVecRuntimeShadowDecision::RecordShadowWin
                ) {
                    metrics.fallback_case_count += 1;
                    if case.shadow_reason_ref.is_none() {
                        metrics.missing_reason_count += 1;
                    }
                }
                if case.route_mutation_allowed {
                    metrics.route_mutation_count += 1;
                }
                if case.model_context_injected {
                    metrics.model_context_injection_count += 1;
                }
            }
        }
        if metrics.min_sample_count == u64::MAX {
            metrics.min_sample_count = 0;
        }
        if metrics.min_memory_headroom_bytes == i64::MAX {
            metrics.min_memory_headroom_bytes = 0;
        }
        metrics
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: TurboVecRuntimeShadowBenchmarkPlan validation error.
// Plane: Verification.
// Residency: Metadata-only diagnostic; no index/model/runtime bytes.
pub enum TurboVecRuntimeShadowError {
    BadUpstreamCursor,
    MissingUpstreamLatencyMemory,
    EmptyPlans,
    DuplicatePlanId(String),
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecRuntimeShadowStatus),
    BadPromotionTier(TurboVecRuntimeShadowPromotionTier),
    MetadataBudgetExceeded {
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
    },
    SetPromotionAllowed,
    MissingField {
        field: &'static str,
        plan_id: String,
    },
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    InvalidOrgans(String),
    InvalidPolicy(String),
    EmptyCases(String),
    DuplicateCaseId(String),
    MissingCaseCoverage(String),
    InvalidCase {
        case_id: String,
        reason: String,
    },
    RuntimeOrIndexNotDeferred(String),
    HiddenAuthority(String),
    ProductPromotionAllowed(String),
    LiveLargeModelClaimed(String),
    SsdAsRamClaimed(String),
}

impl fmt::Display for TurboVecRuntimeShadowError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "bad upstream latency/memory cursor"),
            Self::MissingUpstreamLatencyMemory => write!(f, "missing upstream latency/memory plan"),
            Self::EmptyPlans => write!(f, "TurboVec shadow benchmark plan set is empty"),
            Self::DuplicatePlanId(id) => write!(f, "duplicate shadow plan id `{id}`"),
            Self::BadProductBuild(build) => {
                write!(f, "bad product build for shadow benchmark: {build:?}")
            }
            Self::BadProStatus(status) => {
                write!(f, "bad ProStatus for shadow benchmark: {status:?}")
            }
            Self::BadStatus(status) => write!(f, "bad shadow benchmark status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad shadow benchmark tier: {tier:?}"),
            Self::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            } => write!(
                f,
                "metadata budget exceeded: metadata={metadata_bytes_read} fixture={fixture_bytes_read}"
            ),
            Self::SetPromotionAllowed => write!(f, "shadow benchmark set promoted capability"),
            Self::MissingField { field, plan_id } => {
                write!(f, "plan `{plan_id}` missing field `{field}`")
            }
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(
                f,
                "field `{field}` value `{value}` must start with `{expected}`"
            ),
            Self::InvalidOrgans(plan_id) => write!(f, "plan `{plan_id}` missing required organs"),
            Self::InvalidPolicy(reason) => write!(f, "invalid shadow policy: {reason}"),
            Self::EmptyCases(plan_id) => write!(f, "plan `{plan_id}` has no replay cases"),
            Self::DuplicateCaseId(id) => write!(f, "duplicate shadow case id `{id}`"),
            Self::MissingCaseCoverage(plan_id) => {
                write!(f, "plan `{plan_id}` missing replay scenario coverage")
            }
            Self::InvalidCase { case_id, reason } => {
                write!(f, "invalid shadow replay case `{case_id}`: {reason}")
            }
            Self::RuntimeOrIndexNotDeferred(id) => write!(
                f,
                "plan `{id}` opened/allocated runtime, model, provider, or index bytes"
            ),
            Self::HiddenAuthority(id) => write!(f, "plan `{id}` allows hidden route authority"),
            Self::ProductPromotionAllowed(id) => write!(f, "plan `{id}` promoted capability"),
            Self::LiveLargeModelClaimed(id) => {
                write!(f, "plan `{id}` claimed live large-model capability")
            }
            Self::SsdAsRamClaimed(id) => write!(f, "plan `{id}` claimed SSD as RAM"),
        }
    }
}

impl std::error::Error for TurboVecRuntimeShadowError {}

fn validate_set_inputs(
    upstream_latency_memory_address: &UasAddress,
    plans: &[TurboVecRuntimeShadowBenchmarkPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecRuntimeShadowStatus,
    promotion_tier: &TurboVecRuntimeShadowPromotionTier,
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
    product_capability_promoted: bool,
) -> Result<(), TurboVecRuntimeShadowError> {
    if !matches!(
        upstream_latency_memory_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_latency_memory_abstention_plan"
    ) {
        return Err(TurboVecRuntimeShadowError::BadUpstreamCursor);
    }
    if plans.is_empty() {
        return Err(TurboVecRuntimeShadowError::EmptyPlans);
    }
    if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
        return Err(TurboVecRuntimeShadowError::MetadataBudgetExceeded {
            metadata_bytes_read,
            fixture_bytes_read,
        });
    }
    if product_capability_promoted {
        return Err(TurboVecRuntimeShadowError::SetPromotionAllowed);
    }
    if !matches!(product_build, ProductBuild::Pro) {
        return Err(TurboVecRuntimeShadowError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if !matches!(pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecRuntimeShadowError::BadProStatus(pro_status.clone()));
    }
    if !matches!(status, TurboVecRuntimeShadowStatus::MetadataOnlyPlan) {
        return Err(TurboVecRuntimeShadowError::BadStatus(*status));
    }
    if !matches!(
        promotion_tier,
        TurboVecRuntimeShadowPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecRuntimeShadowError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    let mut ids = HashSet::with_capacity(plans.len());
    for plan in plans {
        if !ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecRuntimeShadowError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(
    plan: &TurboVecRuntimeShadowBenchmarkPlan,
    upstream_latency_memory_address: &UasAddress,
) -> Result<(), TurboVecRuntimeShadowError> {
    require_nonempty(&plan.plan_id, "plan_id", &plan.plan_id)?;
    if plan.upstream_latency_memory_address != *upstream_latency_memory_address {
        return Err(TurboVecRuntimeShadowError::MissingUpstreamLatencyMemory);
    }
    require_prefix(
        "upstream_latency_memory_witness_ref",
        &plan.upstream_latency_memory_witness_ref,
        UPSTREAM_WITNESS_REF,
    )?;
    if !matches!(plan.product_build, ProductBuild::Pro) {
        return Err(TurboVecRuntimeShadowError::BadProductBuild(
            plan.product_build.clone(),
        ));
    }
    if !matches!(plan.pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecRuntimeShadowError::BadProStatus(
            plan.pro_status.clone(),
        ));
    }
    if !matches!(plan.status, TurboVecRuntimeShadowStatus::MetadataOnlyPlan) {
        return Err(TurboVecRuntimeShadowError::BadStatus(plan.status));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecRuntimeShadowPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecRuntimeShadowError::BadPromotionTier(
            plan.promotion_tier,
        ));
    }
    validate_organs(plan)?;
    validate_policy(&plan.policy)?;
    validate_cases(plan)?;
    validate_byte_ledger(plan)?;
    validate_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if plan.hidden_route_authority {
        return Err(TurboVecRuntimeShadowError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.product_capability_promoted {
        return Err(TurboVecRuntimeShadowError::ProductPromotionAllowed(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_large_model_claimed {
        return Err(TurboVecRuntimeShadowError::LiveLargeModelClaimed(
            plan.plan_id.clone(),
        ));
    }
    if plan.ssd_as_ram_claimed {
        return Err(TurboVecRuntimeShadowError::SsdAsRamClaimed(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_organs(
    plan: &TurboVecRuntimeShadowBenchmarkPlan,
) -> Result<(), TurboVecRuntimeShadowError> {
    let organs: HashSet<TurboVecIndexOrgan> = plan.organs.iter().copied().collect();
    for required in [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ] {
        if !organs.contains(&required) {
            return Err(TurboVecRuntimeShadowError::InvalidOrgans(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_policy(policy: &TurboVecRuntimeShadowPolicy) -> Result<(), TurboVecRuntimeShadowError> {
    if !policy.latency_memory_witness_required
        || !policy.exact_baseline_replay_required
        || !policy.deterministic_seed_required
        || !policy.min_sample_count_required
        || !policy.shadow_only_required
        || !policy.route_mutation_forbidden
        || !policy.model_context_injection_forbidden
        || !policy.fallback_required_for_loss
        || !policy.cancellation_required
        || !policy.answer_packet_required
        || !policy.run_event_log_required
        || !policy.rollback_required
        || !policy.compatibility_fence_required
        || !policy.quarantine_adapter_required_before_runtime
    {
        return Err(TurboVecRuntimeShadowError::InvalidPolicy(
            "required fail-closed policy bit missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_cases(
    plan: &TurboVecRuntimeShadowBenchmarkPlan,
) -> Result<(), TurboVecRuntimeShadowError> {
    if plan.replay_cases.is_empty() {
        return Err(TurboVecRuntimeShadowError::EmptyCases(plan.plan_id.clone()));
    }
    let kinds: HashSet<TurboVecRuntimeShadowScenario> =
        plan.replay_cases.iter().map(|case| case.scenario).collect();
    for required in [
        TurboVecRuntimeShadowScenario::WarmHitReplay,
        TurboVecRuntimeShadowScenario::ColdMissReplay,
        TurboVecRuntimeShadowScenario::CancellationReplay,
        TurboVecRuntimeShadowScenario::MemoryPressureReplay,
        TurboVecRuntimeShadowScenario::EmptyAllowlistReplay,
        TurboVecRuntimeShadowScenario::RecallRegressionReplay,
    ] {
        if !kinds.contains(&required) {
            return Err(TurboVecRuntimeShadowError::MissingCaseCoverage(
                plan.plan_id.clone(),
            ));
        }
    }
    let mut ids = HashSet::with_capacity(plan.replay_cases.len());
    for case in &plan.replay_cases {
        if !ids.insert(case.case_id.clone()) {
            return Err(TurboVecRuntimeShadowError::DuplicateCaseId(
                case.case_id.clone(),
            ));
        }
        validate_case(case)?;
    }
    Ok(())
}

fn validate_case(case: &TurboVecRuntimeShadowReplayCase) -> Result<(), TurboVecRuntimeShadowError> {
    require_nonempty(&case.case_id, "case_id", &case.case_id)?;
    for (field, value, prefix) in [
        (
            "fallback_route_ref",
            &case.fallback_route_ref,
            FALLBACK_PREFIX,
        ),
        ("rollback_ref", &case.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &case.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &case.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
    ] {
        require_prefix(field, value, prefix)?;
    }
    if case.replay_seed == 0 {
        return invalid_case(case, "deterministic replay seed is required");
    }
    if case.sample_count > MAX_REPLAY_SAMPLE_COUNT {
        return invalid_case(case, "sample count exceeds shadow replay ceiling");
    }
    if case.sample_count < MIN_REPLAY_SAMPLE_COUNT
        && !matches!(
            case.scenario,
            TurboVecRuntimeShadowScenario::EmptyAllowlistReplay
        )
    {
        return invalid_case(case, "non-empty shadow replay sample count is too low");
    }
    if case.top_k == 0 || case.top_k > MAX_TOP_K {
        return invalid_case(case, "top_k must be in 1..=50");
    }
    if case.planned_candidate_count == 0
        && !matches!(
            case.scenario,
            TurboVecRuntimeShadowScenario::EmptyAllowlistReplay
        )
    {
        return invalid_case(case, "non-empty scenarios require candidates");
    }
    if case
        .planned_fixture_bytes
        .saturating_add(case.planned_scratch_bytes)
        != case.planned_total_bytes
    {
        return invalid_case(case, "planned shadow byte total is inconsistent");
    }
    if case.memory_budget_bytes == 0
        || case.latency_budget_micros == 0
        || case.timeout_micros == 0
        || case.cancellation_deadline_micros == 0
    {
        return invalid_case(
            case,
            "memory, latency, timeout, and cancellation are required",
        );
    }
    if case.cancellation_deadline_micros > case.timeout_micros {
        return invalid_case(case, "cancellation deadline must not exceed timeout");
    }
    if case.predicted_p50_latency_micros == 0
        || case.predicted_p95_latency_micros == 0
        || case.predicted_p99_latency_micros == 0
        || case.predicted_p50_latency_micros > case.predicted_p95_latency_micros
        || case.predicted_p95_latency_micros > case.predicted_p99_latency_micros
    {
        return invalid_case(case, "latency percentiles must be nonzero and ordered");
    }
    if case.exact_recall_at_k_micros > 1_000_000
        || case.compressed_recall_at_k_micros > 1_000_000
        || case.recall_floor_micros < 850_000
        || case.recall_floor_micros > 1_000_000
    {
        return invalid_case(case, "recall micros must stay inside exact-baseline bounds");
    }
    if case.route_mutation_allowed {
        return invalid_case(case, "shadow replay allows route mutation");
    }
    if case.model_context_injected {
        return invalid_case(case, "shadow replay injects model context");
    }
    if !matches!(
        case.decision,
        TurboVecRuntimeShadowDecision::RecordShadowWin
    ) && case.shadow_win_recorded
    {
        return invalid_case(case, "non-win shadow replay recorded a win");
    }
    match case.decision {
        TurboVecRuntimeShadowDecision::RecordShadowWin => {
            if !matches!(case.scenario, TurboVecRuntimeShadowScenario::WarmHitReplay) {
                return invalid_case(case, "only warm-hit replay may record the first shadow win");
            }
            if !case.shadow_win_recorded || !case.shadow_win_allowed() {
                return invalid_case(case, "shadow win lacks recall/latency/memory support");
            }
            if case.shadow_reason_ref.is_some() {
                return invalid_case(case, "shadow win cannot carry a fallback reason");
            }
        }
        TurboVecRuntimeShadowDecision::RecordShadowLoss => {
            require_shadow_reason(case)?;
            if case.shadow_win_recorded {
                return invalid_case(case, "shadow loss recorded a win");
            }
        }
        TurboVecRuntimeShadowDecision::CancelAndFallback => {
            require_shadow_reason(case)?;
            if case.latency_fits() {
                return invalid_case(case, "cancellation replay needs timeout pressure");
            }
        }
        TurboVecRuntimeShadowDecision::MemoryAbstain => {
            require_shadow_reason(case)?;
            if case.memory_fits() {
                return invalid_case(case, "memory abstention needs negative headroom");
            }
        }
        TurboVecRuntimeShadowDecision::EmptyVisible => {
            require_shadow_reason(case)?;
            if case.planned_candidate_count != 0 || case.shadow_win_recorded {
                return invalid_case(case, "empty allowlist cannot produce context");
            }
        }
        TurboVecRuntimeShadowDecision::RecallRegressionFallback => {
            require_shadow_reason(case)?;
            if case.recall_fits() {
                return invalid_case(
                    case,
                    "recall regression needs below-floor or high-delta recall",
                );
            }
        }
    }
    Ok(())
}

fn require_shadow_reason(
    case: &TurboVecRuntimeShadowReplayCase,
) -> Result<(), TurboVecRuntimeShadowError> {
    let Some(reason) = case.shadow_reason_ref.as_ref() else {
        return invalid_case(case, "shadow fallback reason is required");
    };
    if !reason.starts_with(SHADOW_REASON_PREFIX) {
        return invalid_case(case, "shadow reason prefix is invalid");
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecRuntimeShadowBenchmarkPlan,
) -> Result<(), TurboVecRuntimeShadowError> {
    if plan.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || plan.byte_ledger.fixture_bytes_read > MAX_FIXTURE_BYTES
    {
        return Err(TurboVecRuntimeShadowError::MetadataBudgetExceeded {
            metadata_bytes_read: plan.byte_ledger.metadata_bytes_read,
            fixture_bytes_read: plan.byte_ledger.fixture_bytes_read,
        });
    }
    if plan.byte_ledger.opened_index_bytes > 0
        || plan.byte_ledger.loaded_index_bytes > 0
        || plan.byte_ledger.allocated_runtime_bytes > 0
        || plan.byte_ledger.runtime_bytes_loaded > 0
        || plan.byte_ledger.model_bytes_loaded > 0
        || plan.byte_ledger.provider_calls_made > 0
        || plan.byte_ledger.copied_product_file_count > 0
    {
        return Err(TurboVecRuntimeShadowError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    plan_id: &str,
    refs: &TurboVecRuntimeShadowProofRefs,
) -> Result<(), TurboVecRuntimeShadowError> {
    let id = plan_id.to_string();
    for (field, value, prefix) in [
        ("falsifier_ref", &refs.falsifier_ref, FALSIFIER_PREFIX),
        ("rollback_ref", &refs.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &refs.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &refs.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            &refs.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
        ),
    ] {
        if value.trim().is_empty() {
            return Err(TurboVecRuntimeShadowError::MissingField { field, plan_id: id });
        }
        require_prefix(field, value, prefix)?;
    }
    Ok(())
}

fn invalid_case(
    case: &TurboVecRuntimeShadowReplayCase,
    reason: &str,
) -> Result<(), TurboVecRuntimeShadowError> {
    Err(TurboVecRuntimeShadowError::InvalidCase {
        case_id: case.case_id.clone(),
        reason: reason.to_string(),
    })
}

fn require_nonempty(
    value: &str,
    field: &'static str,
    plan_id: &str,
) -> Result<(), TurboVecRuntimeShadowError> {
    if value.trim().is_empty() {
        return Err(TurboVecRuntimeShadowError::MissingField {
            field,
            plan_id: plan_id.to_string(),
        });
    }
    Ok(())
}

fn require_prefix(
    field: &'static str,
    value: &str,
    expected: &'static str,
) -> Result<(), TurboVecRuntimeShadowError> {
    if !value.starts_with(expected) {
        return Err(TurboVecRuntimeShadowError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        });
    }
    Ok(())
}

fn deterministic_set_address(
    plans: &[TurboVecRuntimeShadowBenchmarkPlan],
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
) -> UasAddress {
    let mut parts = vec![
        format!("metadata={metadata_bytes_read}"),
        format!("fixture={fixture_bytes_read}"),
    ];
    for plan in plans {
        parts.push(format!("plan={}", plan.plan_id));
        let mut replay_parts = plan
            .replay_cases
            .iter()
            .map(|case| {
                format!(
                    "{}|{:?}|{}|{}|{}|{}|{}|{}|{}|{:?}|{}",
                    case.case_id,
                    case.scenario,
                    case.replay_seed,
                    case.sample_count,
                    case.planned_candidate_count,
                    case.compressed_recall_at_k_micros,
                    case.predicted_p95_latency_micros,
                    case.predicted_p99_latency_micros,
                    case.planned_total_bytes,
                    case.decision,
                    case.shadow_win_recorded
                )
            })
            .collect::<Vec<_>>();
        replay_parts.sort();
        parts.extend(replay_parts);
    }
    UasAddress::new(
        UasKind::Other(TURBOVEC_RUNTIME_SHADOW_BENCHMARK_CURSOR.to_string()),
        sha256_hex(parts.join("\n").as_bytes()).as_bytes(),
        1_779_039_600_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_latency_memory_abstention_plan".to_string()),
            b"upstream-latency-memory",
            1_779_039_500_000,
        )
    }

    fn query(label: &str) -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_shadow_replay_query".to_string()),
            label.as_bytes(),
            1_779_039_600_000,
        )
    }

    fn replay_case(
        case_id: &str,
        scenario: TurboVecRuntimeShadowScenario,
        decision: TurboVecRuntimeShadowDecision,
    ) -> TurboVecRuntimeShadowReplayCase {
        let mut case = TurboVecRuntimeShadowReplayCase {
            case_id: case_id.to_string(),
            scenario,
            query_uas_address: query(case_id),
            replay_seed: 42,
            sample_count: 64,
            top_k: 8,
            planned_candidate_count: 32,
            exact_recall_at_k_micros: 960_000,
            compressed_recall_at_k_micros: 940_000,
            recall_floor_micros: 900_000,
            max_allowed_recall_delta_micros: 60_000,
            predicted_p50_latency_micros: 4_000,
            predicted_p95_latency_micros: 9_000,
            predicted_p99_latency_micros: 18_000,
            latency_budget_micros: 12_000,
            timeout_micros: 25_000,
            cancellation_deadline_micros: 20_000,
            planned_fixture_bytes: 24_576,
            planned_scratch_bytes: 16_384,
            planned_total_bytes: 0,
            memory_budget_bytes: 96 * 1024,
            memory_headroom_bytes: 0,
            decision,
            shadow_win_recorded: matches!(decision, TurboVecRuntimeShadowDecision::RecordShadowWin),
            shadow_reason_ref: None,
            fallback_route_ref: format!("fallback:turbovec-shadow:{case_id}"),
            rollback_ref: format!("rollback:turbovec-shadow:{case_id}"),
            run_event_log_ref: format!("run_event_log:turbovec-shadow:{case_id}"),
            answer_packet_ref: format!("answer_packet:turbovec-shadow:{case_id}"),
            route_mutation_allowed: false,
            model_context_injected: false,
        };
        match decision {
            TurboVecRuntimeShadowDecision::RecordShadowWin => {}
            TurboVecRuntimeShadowDecision::RecordShadowLoss => {
                case.shadow_reason_ref = Some(format!("shadow:loss:{case_id}"));
            }
            TurboVecRuntimeShadowDecision::CancelAndFallback => {
                case.predicted_p99_latency_micros = 40_000;
                case.shadow_reason_ref = Some(format!("shadow:cancel:{case_id}"));
            }
            TurboVecRuntimeShadowDecision::MemoryAbstain => {
                case.planned_fixture_bytes = 96_000;
                case.planned_scratch_bytes = 64_000;
                case.memory_budget_bytes = 128_000;
                case.shadow_reason_ref = Some(format!("shadow:memory:{case_id}"));
            }
            TurboVecRuntimeShadowDecision::EmptyVisible => {
                case.planned_candidate_count = 0;
                case.sample_count = 1;
                case.planned_fixture_bytes = 0;
                case.shadow_reason_ref = Some(format!("shadow:empty:{case_id}"));
            }
            TurboVecRuntimeShadowDecision::RecallRegressionFallback => {
                case.compressed_recall_at_k_micros = 760_000;
                case.shadow_reason_ref = Some(format!("shadow:recall:{case_id}"));
            }
        }
        case.recompute_totals();
        case
    }

    fn plan(upstream: UasAddress) -> TurboVecRuntimeShadowBenchmarkPlan {
        TurboVecRuntimeShadowBenchmarkPlan {
            plan_id: "turbovec_runtime_shadow_benchmark".to_string(),
            upstream_latency_memory_address: upstream,
            upstream_latency_memory_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            status: TurboVecRuntimeShadowStatus::MetadataOnlyPlan,
            promotion_tier: TurboVecRuntimeShadowPromotionTier::T1L1Metadata,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            policy: TurboVecRuntimeShadowPolicy::fail_closed(),
            replay_cases: vec![
                replay_case(
                    "warm_hit",
                    TurboVecRuntimeShadowScenario::WarmHitReplay,
                    TurboVecRuntimeShadowDecision::RecordShadowWin,
                ),
                replay_case(
                    "cold_miss",
                    TurboVecRuntimeShadowScenario::ColdMissReplay,
                    TurboVecRuntimeShadowDecision::RecordShadowLoss,
                ),
                replay_case(
                    "cancel",
                    TurboVecRuntimeShadowScenario::CancellationReplay,
                    TurboVecRuntimeShadowDecision::CancelAndFallback,
                ),
                replay_case(
                    "memory",
                    TurboVecRuntimeShadowScenario::MemoryPressureReplay,
                    TurboVecRuntimeShadowDecision::MemoryAbstain,
                ),
                replay_case(
                    "empty",
                    TurboVecRuntimeShadowScenario::EmptyAllowlistReplay,
                    TurboVecRuntimeShadowDecision::EmptyVisible,
                ),
                replay_case(
                    "recall_regression",
                    TurboVecRuntimeShadowScenario::RecallRegressionReplay,
                    TurboVecRuntimeShadowDecision::RecallRegressionFallback,
                ),
            ],
            byte_ledger: TurboVecRuntimeShadowByteLedger::metadata_only(28_000, 20_000, 96_000)
                .unwrap(),
            proof_refs: TurboVecRuntimeShadowProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-RuntimeShadowBenchmarkPlan".to_string(),
                rollback_ref: "rollback:turbovec-shadow".to_string(),
                run_event_log_ref: "run_event_log:turbovec-shadow".to_string(),
                answer_packet_ref: "answer_packet:turbovec-shadow".to_string(),
                compatibility_fence_ref: "compat:turbovec-shadow".to_string(),
            },
            hidden_route_authority: false,
            product_capability_promoted: false,
            live_large_model_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn build_set(
        upstream: UasAddress,
        plans: Vec<TurboVecRuntimeShadowBenchmarkPlan>,
    ) -> Result<TurboVecRuntimeShadowBenchmarkPlanSet, TurboVecRuntimeShadowError> {
        TurboVecRuntimeShadowBenchmarkPlanSet::from_plans(
            upstream,
            plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRuntimeShadowStatus::MetadataOnlyPlan,
            TurboVecRuntimeShadowPromotionTier::T1L1Metadata,
            30_000,
            24_000,
            false,
        )
    }

    #[test]
    fn accepts_shadow_plan_and_deterministic_address() {
        let upstream = upstream_address();
        let plan = plan(upstream.clone());
        let mut reversed = plan.clone();
        reversed.replay_cases.reverse();
        let set = build_set(upstream.clone(), vec![plan]).unwrap();
        let reversed_set = build_set(upstream, vec![reversed]).unwrap();

        assert_eq!(set.set_address, reversed_set.set_address);
        let metrics = set.metrics();
        assert_eq!(metrics.case_count, 6);
        assert_eq!(metrics.shadow_win_count, 1);
        assert_eq!(metrics.fallback_case_count, 5);
        assert_eq!(metrics.invalid_win_count, 0);
    }

    #[test]
    fn rejects_low_sample_shadow_win() {
        let upstream = upstream_address();
        let mut plan = plan(upstream.clone());
        plan.replay_cases[0].sample_count = 3;
        assert!(build_set(upstream, vec![plan]).is_err());
    }

    #[test]
    fn rejects_shadow_route_or_context_authority() {
        let upstream = upstream_address();

        let mut route = plan(upstream.clone());
        route.replay_cases[0].route_mutation_allowed = true;
        assert!(build_set(upstream.clone(), vec![route]).is_err());

        let mut context = plan(upstream.clone());
        context.replay_cases[0].model_context_injected = true;
        assert!(build_set(upstream, vec![context]).is_err());
    }

    #[test]
    fn rejects_runtime_bytes_and_product_promotion() {
        let upstream = upstream_address();

        let mut bytes = plan(upstream.clone());
        bytes.byte_ledger.allocated_runtime_bytes = 1;
        assert!(build_set(upstream.clone(), vec![bytes]).is_err());

        let mut promoted = plan(upstream.clone());
        promoted.product_capability_promoted = true;
        assert!(build_set(upstream, vec![promoted]).is_err());
    }
}
