//! TurboVec latency, memory, and abstention envelope plan.
//!
//! This primitive follows exact-baseline recall quality with a fail-closed
//! budget envelope. A compressed TurboVec/Eidos cache may only feed future
//! large-local-model context when the planned query stays inside latency,
//! timeout, cancellation, memory, and uncertainty bounds. Otherwise it must
//! visibly abstain and fall back without mutating route policy.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_LATENCY_MEMORY_ABSTENTION_CURSOR: &str =
    "turbovec_latency_memory_abstention_plan";
pub const TURBOVEC_LATENCY_MEMORY_ABSTENTION_NEXT_CURSOR: &str =
    "turbovec_runtime_shadow_benchmark_plan";

const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_recall_quality_exact_baseline:result";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const FALLBACK_PREFIX: &str = "fallback:";
const ABSTAIN_PREFIX: &str = "abstain:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_FIXTURE_BYTES: u64 = 128 * 1024;
const MAX_TOP_K: u64 = 50;
const MAX_UNCERTAINTY_MICROS: u64 = 350_000;

// UAS: uas:turbovec-latency-memory:status
// Plane: Verification
// Residency: metadata-only envelope status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecLatencyMemoryStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-latency-memory:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecLatencyMemoryPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-latency-memory:decision
// Plane: Controller + Verification
// Residency: use or visible abstention before route/context selection.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRetrievalEnvelopeDecision {
    UseCompressedCache,
    AbstainTimeoutRisk,
    AbstainMemoryRisk,
    AbstainUncertaintyRisk,
    EmptyAllowedVisible,
}

// UAS: uas:turbovec-latency-memory:case-kind
// Plane: Verification
// Residency: tiny synthetic budget case class.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRetrievalEnvelopeCaseKind {
    FastUse,
    TimeoutAbstain,
    MemoryAbstain,
    UncertaintyAbstain,
    EmptyVisible,
}

// UAS: uas:turbovec-latency-memory:case
// Plane: Assembly + Controller + Verification
// Residency: planned retrieval budget; no runtime/index bytes are opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRetrievalEnvelopeCase {
    pub case_id: String,
    pub case_kind: TurboVecRetrievalEnvelopeCaseKind,
    pub query_uas_address: UasAddress,
    pub top_k: u64,
    pub planned_candidate_count: u64,
    pub planned_index_page_count: u64,
    pub planned_index_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub planned_result_bytes: u64,
    pub planned_total_bytes: u64,
    pub memory_budget_bytes: u64,
    pub memory_headroom_bytes: i64,
    pub latency_budget_micros: u64,
    pub predicted_p50_latency_micros: u64,
    pub predicted_p95_latency_micros: u64,
    pub predicted_p99_latency_micros: u64,
    pub timeout_micros: u64,
    pub cancellation_deadline_micros: u64,
    pub uncertainty_micros: u64,
    pub recall_quality_ref: String,
    pub recall_floor_micros: u64,
    pub declared_recall_at_k_micros: u64,
    pub decision: TurboVecRetrievalEnvelopeDecision,
    pub selected_for_context: bool,
    pub abstention_reason_ref: Option<String>,
    pub fallback_route_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub route_mutation_allowed: bool,
}

impl TurboVecRetrievalEnvelopeCase {
    pub fn recompute_totals(&mut self) {
        self.planned_total_bytes = self
            .planned_index_bytes
            .saturating_add(self.planned_scratch_bytes)
            .saturating_add(self.planned_result_bytes);
        self.memory_headroom_bytes =
            self.memory_budget_bytes as i64 - self.planned_total_bytes as i64;
    }

    pub fn exceeds_latency_budget(&self) -> bool {
        self.predicted_p95_latency_micros > self.latency_budget_micros
            || self.predicted_p99_latency_micros > self.timeout_micros
    }

    pub fn exceeds_memory_budget(&self) -> bool {
        self.memory_headroom_bytes < 0
    }

    pub fn exceeds_uncertainty_budget(&self) -> bool {
        self.uncertainty_micros > MAX_UNCERTAINTY_MICROS
    }

    pub fn must_abstain(&self) -> bool {
        self.exceeds_latency_budget()
            || self.exceeds_memory_budget()
            || self.exceeds_uncertainty_budget()
            || matches!(
                self.decision,
                TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible
            )
    }
}

// UAS: uas:turbovec-latency-memory:policy
// Plane: Controller + Verification
// Residency: fail-closed budget policy before route use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecLatencyMemoryAbstentionPolicy {
    pub recall_quality_witness_required: bool,
    pub exact_baseline_quality_required: bool,
    pub latency_budget_required: bool,
    pub p95_must_fit_latency_budget: bool,
    pub p99_must_fit_timeout: bool,
    pub memory_budget_required: bool,
    pub positive_headroom_required_for_use: bool,
    pub timeout_required: bool,
    pub cancellation_required: bool,
    pub cancellation_must_precede_timeout: bool,
    pub uncertainty_abstention_required: bool,
    pub fallback_route_required: bool,
    pub empty_result_answer_packet_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub hidden_route_authority_allowed: bool,
    pub compressed_score_can_mutate_route: bool,
}

impl TurboVecLatencyMemoryAbstentionPolicy {
    pub fn fail_closed() -> Self {
        Self {
            recall_quality_witness_required: true,
            exact_baseline_quality_required: true,
            latency_budget_required: true,
            p95_must_fit_latency_budget: true,
            p99_must_fit_timeout: true,
            memory_budget_required: true,
            positive_headroom_required_for_use: true,
            timeout_required: true,
            cancellation_required: true,
            cancellation_must_precede_timeout: true,
            uncertainty_abstention_required: true,
            fallback_route_required: true,
            empty_result_answer_packet_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            hidden_route_authority_allowed: false,
            compressed_score_can_mutate_route: false,
        }
    }
}

// UAS: uas:turbovec-latency-memory:byte-ledger
// Plane: Verification
// Residency: metadata-only proof boundary; planned bytes may be nonzero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecLatencyMemoryByteLedger {
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub planned_index_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub planned_result_bytes: u64,
    pub opened_index_bytes: u64,
    pub loaded_index_bytes: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecLatencyMemoryByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        planned_index_bytes: u64,
        planned_scratch_bytes: u64,
        planned_result_bytes: u64,
    ) -> Result<Self, TurboVecLatencyMemoryError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
            return Err(TurboVecLatencyMemoryError::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            });
        }
        Ok(Self {
            metadata_bytes_read,
            fixture_bytes_read,
            planned_index_bytes,
            planned_scratch_bytes,
            planned_result_bytes,
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

// UAS: uas:turbovec-latency-memory:proof-refs
// Plane: Verification
// Residency: visible witness surfaces for non-promotion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecLatencyMemoryProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-latency-memory:plan
// Plane: Assembly + Controller + Verification
// Residency: metadata-only envelope; no runtime or index bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecLatencyMemoryAbstentionPlan {
    pub plan_id: String,
    pub upstream_recall_quality_address: UasAddress,
    pub upstream_recall_quality_witness_ref: String,
    pub status: TurboVecLatencyMemoryStatus,
    pub promotion_tier: TurboVecLatencyMemoryPromotionTier,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecLatencyMemoryAbstentionPolicy,
    pub envelope_cases: Vec<TurboVecRetrievalEnvelopeCase>,
    pub byte_ledger: TurboVecLatencyMemoryByteLedger,
    pub proof_refs: TurboVecLatencyMemoryProofRefs,
    pub hidden_route_authority: bool,
    pub product_capability_promoted: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-latency-memory:plan-set
// Plane: Verification
// Residency: deterministic set-level witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecLatencyMemoryAbstentionPlanSet {
    pub set_address: UasAddress,
    pub upstream_recall_quality_address: UasAddress,
    pub upstream_recall_quality_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecLatencyMemoryStatus,
    pub promotion_tier: TurboVecLatencyMemoryPromotionTier,
    pub plans: Vec<TurboVecLatencyMemoryAbstentionPlan>,
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub product_capability_promoted: bool,
}

// UAS: uas:turbovec-latency-memory:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecLatencyMemoryMetrics {
    pub plan_count: u64,
    pub case_count: u64,
    pub fast_use_case_count: u64,
    pub timeout_abstention_case_count: u64,
    pub memory_abstention_case_count: u64,
    pub uncertainty_abstention_case_count: u64,
    pub empty_visible_case_count: u64,
    pub selected_case_count: u64,
    pub abstention_case_count: u64,
    pub invalid_selected_case_count: u64,
    pub abstention_without_reason_count: u64,
    pub fallback_missing_count: u64,
    pub timeout_violation_count: u64,
    pub memory_violation_count: u64,
    pub uncertainty_violation_count: u64,
    pub max_planned_total_bytes: u64,
    pub min_memory_headroom_bytes: i64,
    pub max_predicted_p99_latency_micros: u64,
    pub opened_index_bytes: u64,
    pub loaded_index_bytes: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecLatencyMemoryAbstentionPlanSet {
    pub fn from_plans(
        upstream_recall_quality_address: UasAddress,
        mut plans: Vec<TurboVecLatencyMemoryAbstentionPlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecLatencyMemoryStatus,
        promotion_tier: TurboVecLatencyMemoryPromotionTier,
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        product_capability_promoted: bool,
    ) -> Result<Self, TurboVecLatencyMemoryError> {
        plans.sort_by(|left, right| left.plan_id.cmp(&right.plan_id));
        validate_set_inputs(
            &upstream_recall_quality_address,
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
            validate_plan(plan, &upstream_recall_quality_address)?;
        }

        let set_address =
            deterministic_set_address(&plans, metadata_bytes_read, fixture_bytes_read);
        Ok(Self {
            set_address,
            upstream_recall_quality_address,
            upstream_recall_quality_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
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

    pub fn metrics(&self) -> TurboVecLatencyMemoryMetrics {
        let mut metrics = TurboVecLatencyMemoryMetrics {
            plan_count: self.plans.len() as u64,
            min_memory_headroom_bytes: i64::MAX,
            ..TurboVecLatencyMemoryMetrics::default()
        };

        for plan in &self.plans {
            metrics.opened_index_bytes += plan.byte_ledger.opened_index_bytes;
            metrics.loaded_index_bytes += plan.byte_ledger.loaded_index_bytes;
            metrics.allocated_runtime_bytes += plan.byte_ledger.allocated_runtime_bytes;
            metrics.runtime_bytes_loaded += plan.byte_ledger.runtime_bytes_loaded;
            metrics.model_bytes_loaded += plan.byte_ledger.model_bytes_loaded;
            metrics.provider_calls_made += plan.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += plan.byte_ledger.copied_product_file_count;

            for case in &plan.envelope_cases {
                metrics.case_count += 1;
                metrics.max_planned_total_bytes = metrics
                    .max_planned_total_bytes
                    .max(case.planned_total_bytes);
                metrics.min_memory_headroom_bytes = metrics
                    .min_memory_headroom_bytes
                    .min(case.memory_headroom_bytes);
                metrics.max_predicted_p99_latency_micros = metrics
                    .max_predicted_p99_latency_micros
                    .max(case.predicted_p99_latency_micros);
                match case.case_kind {
                    TurboVecRetrievalEnvelopeCaseKind::FastUse => metrics.fast_use_case_count += 1,
                    TurboVecRetrievalEnvelopeCaseKind::TimeoutAbstain => {
                        metrics.timeout_abstention_case_count += 1
                    }
                    TurboVecRetrievalEnvelopeCaseKind::MemoryAbstain => {
                        metrics.memory_abstention_case_count += 1
                    }
                    TurboVecRetrievalEnvelopeCaseKind::UncertaintyAbstain => {
                        metrics.uncertainty_abstention_case_count += 1
                    }
                    TurboVecRetrievalEnvelopeCaseKind::EmptyVisible => {
                        metrics.empty_visible_case_count += 1
                    }
                }
                if case.selected_for_context {
                    metrics.selected_case_count += 1;
                }
                if case.must_abstain() {
                    metrics.abstention_case_count += 1;
                    if case.abstention_reason_ref.is_none() {
                        metrics.abstention_without_reason_count += 1;
                    }
                    if case.selected_for_context {
                        metrics.invalid_selected_case_count += 1;
                    }
                }
                if case.exceeds_latency_budget() {
                    metrics.timeout_violation_count += 1;
                }
                if case.exceeds_memory_budget() {
                    metrics.memory_violation_count += 1;
                }
                if case.exceeds_uncertainty_budget() {
                    metrics.uncertainty_violation_count += 1;
                }
                if !case.fallback_route_ref.starts_with(FALLBACK_PREFIX) {
                    metrics.fallback_missing_count += 1;
                }
            }
        }

        if metrics.min_memory_headroom_bytes == i64::MAX {
            metrics.min_memory_headroom_bytes = 0;
        }
        metrics
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: TurboVecLatencyMemoryAbstentionPlan validation error.
// Plane: Verification.
// Residency: Metadata-only diagnostic; no index/model/runtime bytes.
pub enum TurboVecLatencyMemoryError {
    MissingUpstreamRecallQuality,
    MissingUpstreamWitness,
    BadUpstreamCursor,
    EmptyPlans,
    DuplicatePlanId(String),
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecLatencyMemoryStatus),
    BadPromotionTier(TurboVecLatencyMemoryPromotionTier),
    MetadataBudgetExceeded {
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
    },
    SetPromotionAllowed,
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    MissingField {
        field: &'static str,
        plan_id: String,
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

impl fmt::Display for TurboVecLatencyMemoryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamRecallQuality => write!(f, "missing upstream recall-quality plan"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream witness ref"),
            Self::BadUpstreamCursor => write!(f, "bad upstream recall-quality cursor"),
            Self::EmptyPlans => write!(f, "TurboVec latency/memory plan set is empty"),
            Self::DuplicatePlanId(id) => {
                write!(f, "duplicate latency/memory plan id `{id}`")
            }
            Self::BadProductBuild(build) => {
                write!(f, "bad product build for latency/memory plan: {build:?}")
            }
            Self::BadProStatus(status) => {
                write!(f, "bad ProStatus for latency/memory plan: {status:?}")
            }
            Self::BadStatus(status) => write!(f, "bad latency/memory status: {status:?}"),
            Self::BadPromotionTier(tier) => {
                write!(f, "bad latency/memory promotion tier: {tier:?}")
            }
            Self::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            } => write!(
                f,
                "metadata budget exceeded: metadata={metadata_bytes_read} fixture={fixture_bytes_read}"
            ),
            Self::SetPromotionAllowed => {
                write!(f, "latency/memory set promoted product capability")
            }
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(
                f,
                "field `{field}` value `{value}` must start with `{expected}`"
            ),
            Self::MissingField { field, plan_id } => {
                write!(f, "plan `{plan_id}` missing required field `{field}`")
            }
            Self::InvalidOrgans(plan_id) => write!(f, "plan `{plan_id}` missing required organs"),
            Self::InvalidPolicy(reason) => write!(f, "invalid latency/memory policy: {reason}"),
            Self::EmptyCases(plan_id) => write!(f, "plan `{plan_id}` has no envelope cases"),
            Self::DuplicateCaseId(id) => write!(f, "duplicate latency/memory case id `{id}`"),
            Self::MissingCaseCoverage(plan_id) => {
                write!(f, "plan `{plan_id}` missing envelope case coverage")
            }
            Self::InvalidCase { case_id, reason } => {
                write!(f, "invalid latency/memory case `{case_id}`: {reason}")
            }
            Self::RuntimeOrIndexNotDeferred(id) => {
                write!(
                    f,
                    "plan `{id}` opened/allocated runtime, model, provider, or index bytes"
                )
            }
            Self::HiddenAuthority(id) => write!(f, "plan `{id}` allows hidden route authority"),
            Self::ProductPromotionAllowed(id) => {
                write!(f, "plan `{id}` promoted product capability")
            }
            Self::LiveLargeModelClaimed(id) => {
                write!(f, "plan `{id}` claimed live large-model capability")
            }
            Self::SsdAsRamClaimed(id) => write!(f, "plan `{id}` claimed SSD as RAM"),
        }
    }
}

impl std::error::Error for TurboVecLatencyMemoryError {}

fn validate_set_inputs(
    upstream_recall_quality_address: &UasAddress,
    plans: &[TurboVecLatencyMemoryAbstentionPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecLatencyMemoryStatus,
    promotion_tier: &TurboVecLatencyMemoryPromotionTier,
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
    product_capability_promoted: bool,
) -> Result<(), TurboVecLatencyMemoryError> {
    if !matches!(
        upstream_recall_quality_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_recall_quality_exact_baseline_plan"
    ) {
        return Err(TurboVecLatencyMemoryError::BadUpstreamCursor);
    }
    if plans.is_empty() {
        return Err(TurboVecLatencyMemoryError::EmptyPlans);
    }
    if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
        return Err(TurboVecLatencyMemoryError::MetadataBudgetExceeded {
            metadata_bytes_read,
            fixture_bytes_read,
        });
    }
    if product_capability_promoted {
        return Err(TurboVecLatencyMemoryError::SetPromotionAllowed);
    }
    if !matches!(product_build, ProductBuild::Pro) {
        return Err(TurboVecLatencyMemoryError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if !matches!(pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecLatencyMemoryError::BadProStatus(pro_status.clone()));
    }
    if !matches!(status, TurboVecLatencyMemoryStatus::MetadataOnlyPlan) {
        return Err(TurboVecLatencyMemoryError::BadStatus(*status));
    }
    if !matches!(
        promotion_tier,
        TurboVecLatencyMemoryPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecLatencyMemoryError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    let mut ids = HashSet::with_capacity(plans.len());
    for plan in plans {
        if !ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecLatencyMemoryError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(
    plan: &TurboVecLatencyMemoryAbstentionPlan,
    upstream_recall_quality_address: &UasAddress,
) -> Result<(), TurboVecLatencyMemoryError> {
    require_nonempty(&plan.plan_id, "plan_id", &plan.plan_id)?;
    if plan.upstream_recall_quality_address != *upstream_recall_quality_address {
        return Err(TurboVecLatencyMemoryError::MissingUpstreamRecallQuality);
    }
    require_prefix(
        "upstream_recall_quality_witness_ref",
        &plan.upstream_recall_quality_witness_ref,
        UPSTREAM_WITNESS_REF,
    )?;
    if !matches!(plan.product_build, ProductBuild::Pro) {
        return Err(TurboVecLatencyMemoryError::BadProductBuild(
            plan.product_build.clone(),
        ));
    }
    if !matches!(plan.pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecLatencyMemoryError::BadProStatus(
            plan.pro_status.clone(),
        ));
    }
    if !matches!(plan.status, TurboVecLatencyMemoryStatus::MetadataOnlyPlan) {
        return Err(TurboVecLatencyMemoryError::BadStatus(plan.status));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecLatencyMemoryPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecLatencyMemoryError::BadPromotionTier(
            plan.promotion_tier,
        ));
    }
    validate_organs(plan)?;
    validate_policy(&plan.policy)?;
    validate_cases(plan)?;
    validate_byte_ledger(plan)?;
    validate_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if plan.hidden_route_authority
        || plan.policy.hidden_route_authority_allowed
        || plan.policy.compressed_score_can_mutate_route
    {
        return Err(TurboVecLatencyMemoryError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.product_capability_promoted {
        return Err(TurboVecLatencyMemoryError::ProductPromotionAllowed(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_large_model_claimed {
        return Err(TurboVecLatencyMemoryError::LiveLargeModelClaimed(
            plan.plan_id.clone(),
        ));
    }
    if plan.ssd_as_ram_claimed {
        return Err(TurboVecLatencyMemoryError::SsdAsRamClaimed(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_organs(
    plan: &TurboVecLatencyMemoryAbstentionPlan,
) -> Result<(), TurboVecLatencyMemoryError> {
    let organs: HashSet<TurboVecIndexOrgan> = plan.organs.iter().copied().collect();
    for required in [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ] {
        if !organs.contains(&required) {
            return Err(TurboVecLatencyMemoryError::InvalidOrgans(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecLatencyMemoryAbstentionPolicy,
) -> Result<(), TurboVecLatencyMemoryError> {
    if !policy.recall_quality_witness_required
        || !policy.exact_baseline_quality_required
        || !policy.latency_budget_required
        || !policy.p95_must_fit_latency_budget
        || !policy.p99_must_fit_timeout
        || !policy.memory_budget_required
        || !policy.positive_headroom_required_for_use
        || !policy.timeout_required
        || !policy.cancellation_required
        || !policy.cancellation_must_precede_timeout
        || !policy.uncertainty_abstention_required
        || !policy.fallback_route_required
        || !policy.empty_result_answer_packet_required
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.compatibility_fence_required
    {
        return Err(TurboVecLatencyMemoryError::InvalidPolicy(
            "required fail-closed policy bit missing".to_string(),
        ));
    }
    if policy.hidden_route_authority_allowed || policy.compressed_score_can_mutate_route {
        return Err(TurboVecLatencyMemoryError::InvalidPolicy(
            "hidden route authority or score mutation is not allowed".to_string(),
        ));
    }
    Ok(())
}

fn validate_cases(
    plan: &TurboVecLatencyMemoryAbstentionPlan,
) -> Result<(), TurboVecLatencyMemoryError> {
    if plan.envelope_cases.is_empty() {
        return Err(TurboVecLatencyMemoryError::EmptyCases(plan.plan_id.clone()));
    }
    let mut ids = HashSet::with_capacity(plan.envelope_cases.len());
    let kinds: HashSet<TurboVecRetrievalEnvelopeCaseKind> = plan
        .envelope_cases
        .iter()
        .map(|case| case.case_kind)
        .collect();
    for required in [
        TurboVecRetrievalEnvelopeCaseKind::FastUse,
        TurboVecRetrievalEnvelopeCaseKind::TimeoutAbstain,
        TurboVecRetrievalEnvelopeCaseKind::MemoryAbstain,
        TurboVecRetrievalEnvelopeCaseKind::UncertaintyAbstain,
        TurboVecRetrievalEnvelopeCaseKind::EmptyVisible,
    ] {
        if !kinds.contains(&required) {
            return Err(TurboVecLatencyMemoryError::MissingCaseCoverage(
                plan.plan_id.clone(),
            ));
        }
    }
    for case in &plan.envelope_cases {
        if !ids.insert(case.case_id.clone()) {
            return Err(TurboVecLatencyMemoryError::DuplicateCaseId(
                case.case_id.clone(),
            ));
        }
        validate_case(case)?;
    }
    Ok(())
}

fn validate_case(case: &TurboVecRetrievalEnvelopeCase) -> Result<(), TurboVecLatencyMemoryError> {
    require_nonempty(&case.case_id, "case_id", &case.case_id)?;
    for (field, value, prefix) in [
        (
            "recall_quality_ref",
            &case.recall_quality_ref,
            FALSIFIER_PREFIX,
        ),
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
    if case.top_k == 0 || case.top_k > MAX_TOP_K {
        return invalid_case(case, "top_k must be in 1..=50");
    }
    if case.planned_candidate_count == 0
        && !matches!(
            case.decision,
            TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible
        )
    {
        return invalid_case(case, "non-empty decisions require candidates");
    }
    if case
        .planned_index_bytes
        .saturating_add(case.planned_scratch_bytes)
        .saturating_add(case.planned_result_bytes)
        != case.planned_total_bytes
    {
        return invalid_case(case, "planned byte total is inconsistent");
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
    if case.recall_floor_micros < 850_000 || case.recall_floor_micros > 1_000_000 {
        return invalid_case(case, "recall floor must remain an exact-baseline floor");
    }
    if case.declared_recall_at_k_micros < case.recall_floor_micros && !case.must_abstain() {
        return invalid_case(case, "below-floor recall requires abstention");
    }
    let should_abstain = case.must_abstain();
    match case.decision {
        TurboVecRetrievalEnvelopeDecision::UseCompressedCache => {
            if should_abstain {
                return invalid_case(case, "use decision violates budget or uncertainty");
            }
            if !case.selected_for_context {
                return invalid_case(case, "use decision must be explicitly selected");
            }
            if case.abstention_reason_ref.is_some() {
                return invalid_case(case, "use decision cannot carry abstention reason");
            }
        }
        TurboVecRetrievalEnvelopeDecision::AbstainTimeoutRisk => {
            require_abstention(case)?;
            if !case.exceeds_latency_budget() {
                return invalid_case(case, "timeout abstention needs latency or timeout risk");
            }
        }
        TurboVecRetrievalEnvelopeDecision::AbstainMemoryRisk => {
            require_abstention(case)?;
            if !case.exceeds_memory_budget() {
                return invalid_case(case, "memory abstention needs negative headroom");
            }
        }
        TurboVecRetrievalEnvelopeDecision::AbstainUncertaintyRisk => {
            require_abstention(case)?;
            if !case.exceeds_uncertainty_budget() {
                return invalid_case(case, "uncertainty abstention needs high uncertainty");
            }
        }
        TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible => {
            require_abstention(case)?;
            if case.planned_candidate_count != 0 || case.selected_for_context {
                return invalid_case(case, "empty visible case cannot return context");
            }
        }
    }
    if case.route_mutation_allowed {
        return invalid_case(case, "case allows route mutation");
    }
    Ok(())
}

fn require_abstention(
    case: &TurboVecRetrievalEnvelopeCase,
) -> Result<(), TurboVecLatencyMemoryError> {
    if case.selected_for_context {
        return invalid_case(case, "abstention case selected context");
    }
    let Some(reason) = case.abstention_reason_ref.as_ref() else {
        return invalid_case(case, "abstention reason is required");
    };
    if !reason.starts_with(ABSTAIN_PREFIX) {
        return invalid_case(case, "abstention reason prefix is invalid");
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecLatencyMemoryAbstentionPlan,
) -> Result<(), TurboVecLatencyMemoryError> {
    if plan.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || plan.byte_ledger.fixture_bytes_read > MAX_FIXTURE_BYTES
    {
        return Err(TurboVecLatencyMemoryError::MetadataBudgetExceeded {
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
        return Err(TurboVecLatencyMemoryError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    plan_id: &str,
    refs: &TurboVecLatencyMemoryProofRefs,
) -> Result<(), TurboVecLatencyMemoryError> {
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
            return Err(TurboVecLatencyMemoryError::MissingField { field, plan_id: id });
        }
        require_prefix(field, value, prefix)?;
    }
    Ok(())
}

fn invalid_case(
    case: &TurboVecRetrievalEnvelopeCase,
    reason: &str,
) -> Result<(), TurboVecLatencyMemoryError> {
    Err(TurboVecLatencyMemoryError::InvalidCase {
        case_id: case.case_id.clone(),
        reason: reason.to_string(),
    })
}

fn require_nonempty(
    value: &str,
    field: &'static str,
    plan_id: &str,
) -> Result<(), TurboVecLatencyMemoryError> {
    if value.trim().is_empty() {
        return Err(TurboVecLatencyMemoryError::MissingField {
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
) -> Result<(), TurboVecLatencyMemoryError> {
    if !value.starts_with(expected) {
        return Err(TurboVecLatencyMemoryError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        });
    }
    Ok(())
}

fn deterministic_set_address(
    plans: &[TurboVecLatencyMemoryAbstentionPlan],
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
) -> UasAddress {
    let mut parts = vec![
        format!("metadata={metadata_bytes_read}"),
        format!("fixture={fixture_bytes_read}"),
    ];
    for plan in plans {
        parts.push(format!("plan={}", plan.plan_id));
        let mut case_parts = plan
            .envelope_cases
            .iter()
            .map(|case| {
                format!(
                    "{}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}|{:?}|{}",
                    case.case_id,
                    case.case_kind,
                    case.top_k,
                    case.planned_candidate_count,
                    case.planned_total_bytes,
                    case.memory_budget_bytes,
                    case.latency_budget_micros,
                    case.predicted_p95_latency_micros,
                    case.predicted_p99_latency_micros,
                    case.uncertainty_micros,
                    case.decision,
                    case.selected_for_context
                )
            })
            .collect::<Vec<_>>();
        case_parts.sort();
        parts.extend(case_parts);
    }
    UasAddress::new(
        UasKind::Other(TURBOVEC_LATENCY_MEMORY_ABSTENTION_CURSOR.to_string()),
        sha256_hex(parts.join("\n").as_bytes()).as_bytes(),
        1_779_039_500_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_recall_quality_exact_baseline_plan".to_string()),
            b"upstream-recall-quality",
            1_779_039_400_000,
        )
    }

    fn query(label: &str) -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_latency_memory_query".to_string()),
            label.as_bytes(),
            1_779_039_500_000,
        )
    }

    fn case(
        case_id: &str,
        kind: TurboVecRetrievalEnvelopeCaseKind,
        decision: TurboVecRetrievalEnvelopeDecision,
    ) -> TurboVecRetrievalEnvelopeCase {
        let mut envelope = TurboVecRetrievalEnvelopeCase {
            case_id: case_id.to_string(),
            case_kind: kind,
            query_uas_address: query(case_id),
            top_k: 8,
            planned_candidate_count: 64,
            planned_index_page_count: 4,
            planned_index_bytes: 32_768,
            planned_scratch_bytes: 16_384,
            planned_result_bytes: 4_096,
            planned_total_bytes: 0,
            memory_budget_bytes: 256 * 1024,
            memory_headroom_bytes: 0,
            latency_budget_micros: 12_000,
            predicted_p50_latency_micros: 4_000,
            predicted_p95_latency_micros: 9_000,
            predicted_p99_latency_micros: 18_000,
            timeout_micros: 25_000,
            cancellation_deadline_micros: 20_000,
            uncertainty_micros: 120_000,
            recall_quality_ref: format!("falsifier:recall-quality:{case_id}"),
            recall_floor_micros: 900_000,
            declared_recall_at_k_micros: 950_000,
            decision,
            selected_for_context: matches!(
                decision,
                TurboVecRetrievalEnvelopeDecision::UseCompressedCache
            ),
            abstention_reason_ref: None,
            fallback_route_ref: format!("fallback:eidos-exact:{case_id}"),
            rollback_ref: format!("rollback:turbovec-latency:{case_id}"),
            run_event_log_ref: format!("run_event_log:turbovec-latency:{case_id}"),
            answer_packet_ref: format!("answer_packet:turbovec-latency:{case_id}"),
            route_mutation_allowed: false,
        };
        match decision {
            TurboVecRetrievalEnvelopeDecision::AbstainTimeoutRisk => {
                envelope.predicted_p99_latency_micros = 40_000;
                envelope.selected_for_context = false;
                envelope.abstention_reason_ref = Some(format!("abstain:timeout:{case_id}"));
            }
            TurboVecRetrievalEnvelopeDecision::AbstainMemoryRisk => {
                envelope.memory_budget_bytes = 32_000;
                envelope.selected_for_context = false;
                envelope.abstention_reason_ref = Some(format!("abstain:memory:{case_id}"));
            }
            TurboVecRetrievalEnvelopeDecision::AbstainUncertaintyRisk => {
                envelope.uncertainty_micros = 800_000;
                envelope.selected_for_context = false;
                envelope.abstention_reason_ref = Some(format!("abstain:uncertainty:{case_id}"));
            }
            TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible => {
                envelope.planned_candidate_count = 0;
                envelope.planned_index_page_count = 0;
                envelope.planned_index_bytes = 0;
                envelope.planned_scratch_bytes = 8_192;
                envelope.selected_for_context = false;
                envelope.abstention_reason_ref = Some(format!("abstain:empty:{case_id}"));
            }
            TurboVecRetrievalEnvelopeDecision::UseCompressedCache => {}
        }
        envelope.recompute_totals();
        envelope
    }

    fn plan(upstream: UasAddress) -> TurboVecLatencyMemoryAbstentionPlan {
        TurboVecLatencyMemoryAbstentionPlan {
            plan_id: "turbovec_latency_memory_abstention".to_string(),
            upstream_recall_quality_address: upstream,
            upstream_recall_quality_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            status: TurboVecLatencyMemoryStatus::MetadataOnlyPlan,
            promotion_tier: TurboVecLatencyMemoryPromotionTier::T1L1Metadata,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            policy: TurboVecLatencyMemoryAbstentionPolicy::fail_closed(),
            envelope_cases: vec![
                case(
                    "fast_use",
                    TurboVecRetrievalEnvelopeCaseKind::FastUse,
                    TurboVecRetrievalEnvelopeDecision::UseCompressedCache,
                ),
                case(
                    "timeout_abstain",
                    TurboVecRetrievalEnvelopeCaseKind::TimeoutAbstain,
                    TurboVecRetrievalEnvelopeDecision::AbstainTimeoutRisk,
                ),
                case(
                    "memory_abstain",
                    TurboVecRetrievalEnvelopeCaseKind::MemoryAbstain,
                    TurboVecRetrievalEnvelopeDecision::AbstainMemoryRisk,
                ),
                case(
                    "uncertainty_abstain",
                    TurboVecRetrievalEnvelopeCaseKind::UncertaintyAbstain,
                    TurboVecRetrievalEnvelopeDecision::AbstainUncertaintyRisk,
                ),
                case(
                    "empty_visible",
                    TurboVecRetrievalEnvelopeCaseKind::EmptyVisible,
                    TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible,
                ),
            ],
            byte_ledger: TurboVecLatencyMemoryByteLedger::metadata_only(
                24_000, 16_000, 96_000, 64_000, 16_000,
            )
            .unwrap(),
            proof_refs: TurboVecLatencyMemoryProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-LatencyMemoryAbstention".to_string(),
                rollback_ref: "rollback:turbovec-latency-memory".to_string(),
                run_event_log_ref: "run_event_log:turbovec-latency-memory".to_string(),
                answer_packet_ref: "answer_packet:turbovec-latency-memory".to_string(),
                compatibility_fence_ref: "compat:turbovec-latency-memory".to_string(),
            },
            hidden_route_authority: false,
            product_capability_promoted: false,
            live_large_model_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn build_set(
        upstream: UasAddress,
        plans: Vec<TurboVecLatencyMemoryAbstentionPlan>,
    ) -> Result<TurboVecLatencyMemoryAbstentionPlanSet, TurboVecLatencyMemoryError> {
        TurboVecLatencyMemoryAbstentionPlanSet::from_plans(
            upstream,
            plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecLatencyMemoryStatus::MetadataOnlyPlan,
            TurboVecLatencyMemoryPromotionTier::T1L1Metadata,
            28_000,
            18_000,
            false,
        )
    }

    #[test]
    fn accepts_latency_memory_plan_and_deterministic_address() {
        let upstream = upstream_address();
        let plan = plan(upstream.clone());
        let mut reversed = plan.clone();
        reversed.envelope_cases.reverse();
        let set = build_set(upstream.clone(), vec![plan]).unwrap();
        let reversed_set = build_set(upstream, vec![reversed]).unwrap();

        assert_eq!(set.set_address, reversed_set.set_address);
        let metrics = set.metrics();
        assert_eq!(metrics.case_count, 5);
        assert_eq!(metrics.selected_case_count, 1);
        assert_eq!(metrics.abstention_case_count, 4);
        assert_eq!(metrics.invalid_selected_case_count, 0);
    }

    #[test]
    fn rejects_timeout_risk_selected_for_context() {
        let upstream = upstream_address();
        let mut plan = plan(upstream.clone());
        let case = &mut plan.envelope_cases[1];
        case.selected_for_context = true;
        assert!(build_set(upstream, vec![plan]).is_err());
    }

    #[test]
    fn rejects_memory_overrun_as_use_decision() {
        let upstream = upstream_address();
        let mut plan = plan(upstream.clone());
        let case = &mut plan.envelope_cases[0];
        case.memory_budget_bytes = 1;
        case.recompute_totals();
        assert!(build_set(upstream, vec![plan]).is_err());
    }

    #[test]
    fn rejects_hidden_authority_product_promotion_and_bytes() {
        let upstream = upstream_address();

        let mut hidden = plan(upstream.clone());
        hidden.hidden_route_authority = true;
        assert!(build_set(upstream.clone(), vec![hidden]).is_err());

        let mut promoted = plan(upstream.clone());
        promoted.product_capability_promoted = true;
        assert!(build_set(upstream.clone(), vec![promoted]).is_err());

        let mut bytes = plan(upstream.clone());
        bytes.byte_ledger.opened_index_bytes = 1;
        assert!(build_set(upstream, vec![bytes]).is_err());
    }
}
