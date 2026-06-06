//! TurboVec recall-quality exact-baseline plan.
//!
//! This primitive is the first recall-quality gate after stable external IDs,
//! filter-before-rank privacy, and crash-safe persistence. It proves that a
//! TurboVec/Eidos compressed cache must be compared with exact AppColdStore
//! baselines, must abstain when approximate recall misses the floor, and must
//! never mutate large-local-model routes by raw score.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_CURSOR: &str =
    "turbovec_recall_quality_exact_baseline_plan";
pub const TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_NEXT_CURSOR: &str =
    "turbovec_latency_memory_abstention_plan";

const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_crash_safe_persistent_index:result";
const APP_COLD_STORE_EXACT_PREFIX: &str = "app_cold_store:exact_baseline:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_FIXTURE_BYTES: u64 = 128 * 1024;
const MAX_TOP_K: u64 = 50;

// UAS: uas:turbovec-recall-quality:status
// Plane: Verification
// Residency: metadata-only recall-quality plan status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRecallQualityStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-recall-quality:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRecallQualityPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-recall-quality:query-kind
// Plane: Verification
// Residency: tiny synthetic held-out query class.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRecallQueryKind {
    ExactHit,
    PrivateDeletedExcluded,
    DuplicateSourceDeduped,
    RecallMissAbstains,
    EmptyAllowedVisible,
}

// UAS: uas:turbovec-recall-quality:query
// Plane: Verification
// Residency: exact baseline vs approximate result fixture.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRecallQueryFixture {
    pub query_id: String,
    pub query_kind: TurboVecRecallQueryKind,
    pub query_uas_address: UasAddress,
    pub top_k: u64,
    pub exact_baseline_external_ids: Vec<u64>,
    pub approximate_result_external_ids: Vec<u64>,
    pub allowed_external_ids: Vec<u64>,
    pub deleted_external_ids: Vec<u64>,
    pub private_external_ids: Vec<u64>,
    pub unknown_external_ids: Vec<u64>,
    pub deduped_duplicate_source_count: u64,
    pub exact_baseline_ref: String,
    pub exact_baseline_is_exhaustive: bool,
    pub recall_floor_micros: u64,
    pub declared_recall_at_k_micros: u64,
    pub fallback_on_miss_required: bool,
    pub fallback_on_miss_present: bool,
    pub visible_answer_packet_on_empty: bool,
    pub route_mutation_allowed: bool,
    pub latency_budget_micros: u64,
    pub measured_latency_micros: u64,
    pub planned_memory_bytes: u64,
    pub opened_index_bytes: u64,
    pub loaded_index_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub fallback_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

// UAS: uas:turbovec-recall-quality:policy
// Plane: Controller + Verification
// Residency: fail-closed quality policy before route use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRecallQualityPolicy {
    pub exact_app_cold_store_baseline_required: bool,
    pub held_out_query_pack_required: bool,
    pub privacy_gate_required: bool,
    pub crash_safe_persistence_required: bool,
    pub result_subset_of_allowlist_required: bool,
    pub deleted_private_unknown_excluded: bool,
    pub duplicate_source_dedup_required: bool,
    pub recall_floor_micros: u64,
    pub miss_must_abstain_or_fallback: bool,
    pub empty_result_answer_packet_required: bool,
    pub latency_budget_declared: bool,
    pub memory_ledger_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub eidos_score_can_select_route: bool,
    pub hidden_route_authority_allowed: bool,
}

impl TurboVecRecallQualityPolicy {
    pub fn exact_baseline_gate(recall_floor_micros: u64) -> Self {
        Self {
            exact_app_cold_store_baseline_required: true,
            held_out_query_pack_required: true,
            privacy_gate_required: true,
            crash_safe_persistence_required: true,
            result_subset_of_allowlist_required: true,
            deleted_private_unknown_excluded: true,
            duplicate_source_dedup_required: true,
            recall_floor_micros,
            miss_must_abstain_or_fallback: true,
            empty_result_answer_packet_required: true,
            latency_budget_declared: true,
            memory_ledger_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            eidos_score_can_select_route: false,
            hidden_route_authority_allowed: false,
        }
    }
}

// UAS: uas:turbovec-recall-quality:byte-ledger
// Plane: Verification
// Residency: metadata-only proof boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRecallQualityByteLedger {
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub exact_baseline_bytes_opened: u64,
    pub index_bytes_opened: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecRecallQualityByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
    ) -> Result<Self, TurboVecRecallQualityError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
            return Err(TurboVecRecallQualityError::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            });
        }
        Ok(Self {
            metadata_bytes_read,
            fixture_bytes_read,
            exact_baseline_bytes_opened: 0,
            index_bytes_opened: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        })
    }
}

// UAS: uas:turbovec-recall-quality:proof-refs
// Plane: Verification
// Residency: visible witness surfaces for non-promotion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRecallQualityProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-recall-quality:plan
// Plane: Assembly + Verification
// Residency: metadata-only recall quality plan.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRecallQualityExactBaselinePlan {
    pub plan_id: String,
    pub upstream_persistent_index_address: UasAddress,
    pub upstream_persistent_index_witness_ref: String,
    pub status: TurboVecRecallQualityStatus,
    pub promotion_tier: TurboVecRecallQualityPromotionTier,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecRecallQualityPolicy,
    pub query_fixtures: Vec<TurboVecRecallQueryFixture>,
    pub byte_ledger: TurboVecRecallQualityByteLedger,
    pub proof_refs: TurboVecRecallQualityProofRefs,
    pub hidden_route_authority: bool,
    pub product_capability_promoted: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-recall-quality:plan-set
// Plane: Verification
// Residency: deterministic set-level witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRecallQualityExactBaselinePlanSet {
    pub set_address: UasAddress,
    pub upstream_persistent_index_address: UasAddress,
    pub upstream_persistent_index_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecRecallQualityStatus,
    pub promotion_tier: TurboVecRecallQualityPromotionTier,
    pub plans: Vec<TurboVecRecallQualityExactBaselinePlan>,
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub product_capability_promoted: bool,
}

// UAS: uas:turbovec-recall-quality:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecRecallQualityMetrics {
    pub plan_count: u64,
    pub query_count: u64,
    pub exact_hit_query_count: u64,
    pub private_deleted_excluded_query_count: u64,
    pub duplicate_source_deduped_query_count: u64,
    pub recall_miss_abstained_query_count: u64,
    pub empty_allowed_visible_query_count: u64,
    pub below_floor_without_fallback_count: u64,
    pub forbidden_result_count: u64,
    pub duplicate_result_count: u64,
    pub worst_non_empty_recall_micros: u64,
    pub all_pass_or_abstain: bool,
    pub exact_baseline_bytes_opened: u64,
    pub index_bytes_opened: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecRecallQualityExactBaselinePlanSet {
    pub fn from_plans(
        upstream_persistent_index_address: UasAddress,
        mut plans: Vec<TurboVecRecallQualityExactBaselinePlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecRecallQualityStatus,
        promotion_tier: TurboVecRecallQualityPromotionTier,
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        product_capability_promoted: bool,
    ) -> Result<Self, TurboVecRecallQualityError> {
        plans.sort_by(|left, right| left.plan_id.cmp(&right.plan_id));
        validate_set_inputs(
            &upstream_persistent_index_address,
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
            validate_plan(plan, &upstream_persistent_index_address)?;
        }

        let set_address =
            deterministic_set_address(&plans, metadata_bytes_read, fixture_bytes_read);
        Ok(Self {
            set_address,
            upstream_persistent_index_address,
            upstream_persistent_index_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
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

    pub fn metrics(&self) -> TurboVecRecallQualityMetrics {
        let mut metrics = TurboVecRecallQualityMetrics {
            plan_count: self.plans.len() as u64,
            all_pass_or_abstain: true,
            worst_non_empty_recall_micros: 1_000_000,
            ..TurboVecRecallQualityMetrics::default()
        };

        for plan in &self.plans {
            metrics.exact_baseline_bytes_opened += plan.byte_ledger.exact_baseline_bytes_opened;
            metrics.index_bytes_opened += plan.byte_ledger.index_bytes_opened;
            metrics.index_bytes_loaded += plan.byte_ledger.index_bytes_loaded;
            metrics.runtime_bytes_loaded += plan.byte_ledger.runtime_bytes_loaded;
            metrics.model_bytes_loaded += plan.byte_ledger.model_bytes_loaded;
            metrics.provider_calls_made += plan.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += plan.byte_ledger.copied_product_file_count;

            for query in &plan.query_fixtures {
                metrics.query_count += 1;
                match query.query_kind {
                    TurboVecRecallQueryKind::ExactHit => metrics.exact_hit_query_count += 1,
                    TurboVecRecallQueryKind::PrivateDeletedExcluded => {
                        metrics.private_deleted_excluded_query_count += 1
                    }
                    TurboVecRecallQueryKind::DuplicateSourceDeduped => {
                        metrics.duplicate_source_deduped_query_count += 1
                    }
                    TurboVecRecallQueryKind::RecallMissAbstains => {
                        metrics.recall_miss_abstained_query_count += 1
                    }
                    TurboVecRecallQueryKind::EmptyAllowedVisible => {
                        metrics.empty_allowed_visible_query_count += 1
                    }
                }

                if !query.exact_baseline_external_ids.is_empty() {
                    metrics.worst_non_empty_recall_micros = metrics
                        .worst_non_empty_recall_micros
                        .min(recall_at_k_micros(query));
                }
                if recall_at_k_micros(query) < query.recall_floor_micros
                    && !query.fallback_on_miss_present
                {
                    metrics.below_floor_without_fallback_count += 1;
                    metrics.all_pass_or_abstain = false;
                }
                if contains_duplicate(&query.approximate_result_external_ids) {
                    metrics.duplicate_result_count += 1;
                    metrics.all_pass_or_abstain = false;
                }
                let forbidden = forbidden_result_count(query);
                metrics.forbidden_result_count += forbidden;
                if forbidden > 0 {
                    metrics.all_pass_or_abstain = false;
                }
            }
        }

        metrics
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: TurboVecRecallQualityExactBaselinePlan validation error.
// Plane: Verification.
// Residency: Metadata-only diagnostic; no exact-baseline/index/model/runtime bytes.
pub enum TurboVecRecallQualityError {
    MissingUpstreamPersistentIndex,
    MissingUpstreamWitness,
    BadUpstreamCursor,
    EmptyPlans,
    DuplicatePlanId(String),
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecRecallQualityStatus),
    BadPromotionTier(TurboVecRecallQualityPromotionTier),
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
    EmptyQueries(String),
    DuplicateQueryId(String),
    MissingQueryCoverage(String),
    InvalidQuery {
        query_id: String,
        reason: String,
    },
    RuntimeOrIndexNotDeferred(String),
    HiddenAuthority(String),
    ProductPromotionAllowed(String),
    LiveLargeModelClaimed(String),
    SsdAsRamClaimed(String),
}

impl fmt::Display for TurboVecRecallQualityError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamPersistentIndex => write!(f, "missing upstream persistent index"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream witness ref"),
            Self::BadUpstreamCursor => write!(f, "bad upstream persistent-index cursor"),
            Self::EmptyPlans => write!(f, "TurboVec recall-quality plan set is empty"),
            Self::DuplicatePlanId(id) => write!(f, "duplicate recall-quality plan id `{id}`"),
            Self::BadProductBuild(build) => write!(f, "bad product build for recall-quality plan: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad ProStatus for recall-quality plan: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad recall-quality status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad recall-quality promotion tier: {tier:?}"),
            Self::MetadataBudgetExceeded { metadata_bytes_read, fixture_bytes_read } => write!(
                f,
                "metadata budget exceeded: metadata={metadata_bytes_read} fixture={fixture_bytes_read}"
            ),
            Self::SetPromotionAllowed => write!(f, "recall-quality set promoted product capability"),
            Self::BadPrefix { field, value, expected } => {
                write!(f, "field `{field}` value `{value}` must start with `{expected}`")
            }
            Self::MissingField { field, plan_id } => {
                write!(f, "plan `{plan_id}` missing required field `{field}`")
            }
            Self::InvalidOrgans(plan_id) => write!(f, "plan `{plan_id}` missing required organs"),
            Self::InvalidPolicy(reason) => write!(f, "invalid recall-quality policy: {reason}"),
            Self::EmptyQueries(plan_id) => write!(f, "plan `{plan_id}` has no query fixtures"),
            Self::DuplicateQueryId(id) => write!(f, "duplicate recall-quality query id `{id}`"),
            Self::MissingQueryCoverage(plan_id) => write!(f, "plan `{plan_id}` missing query coverage"),
            Self::InvalidQuery { query_id, reason } => {
                write!(f, "invalid recall-quality query `{query_id}`: {reason}")
            }
            Self::RuntimeOrIndexNotDeferred(id) => {
                write!(f, "plan `{id}` opened/loaded runtime, model, provider, or index bytes")
            }
            Self::HiddenAuthority(id) => write!(f, "plan `{id}` allows hidden route authority"),
            Self::ProductPromotionAllowed(id) => write!(f, "plan `{id}` promoted product capability"),
            Self::LiveLargeModelClaimed(id) => write!(f, "plan `{id}` claimed live large-model capability"),
            Self::SsdAsRamClaimed(id) => write!(f, "plan `{id}` claimed SSD as RAM"),
        }
    }
}

impl std::error::Error for TurboVecRecallQualityError {}

pub fn recall_at_k_micros(query: &TurboVecRecallQueryFixture) -> u64 {
    if query.exact_baseline_external_ids.is_empty() {
        return if query.approximate_result_external_ids.is_empty()
            && query.visible_answer_packet_on_empty
        {
            1_000_000
        } else {
            0
        };
    }
    let baseline: HashSet<u64> = query.exact_baseline_external_ids.iter().copied().collect();
    let returned = query
        .approximate_result_external_ids
        .iter()
        .take(query.top_k as usize)
        .filter(|id| baseline.contains(id))
        .count() as u64;
    returned.saturating_mul(1_000_000) / baseline.len() as u64
}

fn validate_set_inputs(
    upstream_persistent_index_address: &UasAddress,
    plans: &[TurboVecRecallQualityExactBaselinePlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecRecallQualityStatus,
    promotion_tier: &TurboVecRecallQualityPromotionTier,
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
    product_capability_promoted: bool,
) -> Result<(), TurboVecRecallQualityError> {
    if !matches!(
        upstream_persistent_index_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_crash_safe_persistent_index_plan"
    ) {
        return Err(TurboVecRecallQualityError::BadUpstreamCursor);
    }
    if plans.is_empty() {
        return Err(TurboVecRecallQualityError::EmptyPlans);
    }
    if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
        return Err(TurboVecRecallQualityError::MetadataBudgetExceeded {
            metadata_bytes_read,
            fixture_bytes_read,
        });
    }
    if product_capability_promoted {
        return Err(TurboVecRecallQualityError::SetPromotionAllowed);
    }
    if !matches!(product_build, ProductBuild::Pro) {
        return Err(TurboVecRecallQualityError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if !matches!(pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecRecallQualityError::BadProStatus(pro_status.clone()));
    }
    if !matches!(status, TurboVecRecallQualityStatus::MetadataOnlyPlan) {
        return Err(TurboVecRecallQualityError::BadStatus(*status));
    }
    if !matches!(
        promotion_tier,
        TurboVecRecallQualityPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecRecallQualityError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    let mut ids = HashSet::with_capacity(plans.len());
    for plan in plans {
        if !ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecRecallQualityError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(
    plan: &TurboVecRecallQualityExactBaselinePlan,
    upstream_persistent_index_address: &UasAddress,
) -> Result<(), TurboVecRecallQualityError> {
    require_nonempty(&plan.plan_id, "plan_id", &plan.plan_id)?;
    if plan.upstream_persistent_index_address != *upstream_persistent_index_address {
        return Err(TurboVecRecallQualityError::MissingUpstreamPersistentIndex);
    }
    require_prefix(
        "upstream_persistent_index_witness_ref",
        &plan.upstream_persistent_index_witness_ref,
        UPSTREAM_WITNESS_REF,
    )?;
    if !matches!(plan.product_build, ProductBuild::Pro) {
        return Err(TurboVecRecallQualityError::BadProductBuild(
            plan.product_build.clone(),
        ));
    }
    if !matches!(plan.pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecRecallQualityError::BadProStatus(
            plan.pro_status.clone(),
        ));
    }
    if !matches!(plan.status, TurboVecRecallQualityStatus::MetadataOnlyPlan) {
        return Err(TurboVecRecallQualityError::BadStatus(plan.status));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecRecallQualityPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecRecallQualityError::BadPromotionTier(
            plan.promotion_tier,
        ));
    }
    validate_organs(plan)?;
    validate_policy(&plan.policy)?;
    validate_queries(plan)?;
    validate_byte_ledger(plan)?;
    validate_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if plan.hidden_route_authority
        || plan.policy.eidos_score_can_select_route
        || plan.policy.hidden_route_authority_allowed
    {
        return Err(TurboVecRecallQualityError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.product_capability_promoted {
        return Err(TurboVecRecallQualityError::ProductPromotionAllowed(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_large_model_claimed {
        return Err(TurboVecRecallQualityError::LiveLargeModelClaimed(
            plan.plan_id.clone(),
        ));
    }
    if plan.ssd_as_ram_claimed {
        return Err(TurboVecRecallQualityError::SsdAsRamClaimed(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_organs(
    plan: &TurboVecRecallQualityExactBaselinePlan,
) -> Result<(), TurboVecRecallQualityError> {
    let organs: HashSet<TurboVecIndexOrgan> = plan.organs.iter().copied().collect();
    for required in [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ] {
        if !organs.contains(&required) {
            return Err(TurboVecRecallQualityError::InvalidOrgans(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_policy(policy: &TurboVecRecallQualityPolicy) -> Result<(), TurboVecRecallQualityError> {
    if !policy.exact_app_cold_store_baseline_required
        || !policy.held_out_query_pack_required
        || !policy.privacy_gate_required
        || !policy.crash_safe_persistence_required
        || !policy.result_subset_of_allowlist_required
        || !policy.deleted_private_unknown_excluded
        || !policy.duplicate_source_dedup_required
        || !policy.miss_must_abstain_or_fallback
        || !policy.empty_result_answer_packet_required
        || !policy.latency_budget_declared
        || !policy.memory_ledger_required
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.compatibility_fence_required
    {
        return Err(TurboVecRecallQualityError::InvalidPolicy(
            "required fail-closed policy bit missing".to_string(),
        ));
    }
    if policy.recall_floor_micros < 850_000 || policy.recall_floor_micros > 1_000_000 {
        return Err(TurboVecRecallQualityError::InvalidPolicy(
            "recall floor must be between 0.85 and 1.0".to_string(),
        ));
    }
    if policy.eidos_score_can_select_route || policy.hidden_route_authority_allowed {
        return Err(TurboVecRecallQualityError::InvalidPolicy(
            "hidden route authority is not allowed".to_string(),
        ));
    }
    Ok(())
}

fn validate_queries(
    plan: &TurboVecRecallQualityExactBaselinePlan,
) -> Result<(), TurboVecRecallQualityError> {
    if plan.query_fixtures.is_empty() {
        return Err(TurboVecRecallQualityError::EmptyQueries(
            plan.plan_id.clone(),
        ));
    }
    let mut ids = HashSet::with_capacity(plan.query_fixtures.len());
    let kinds: HashSet<TurboVecRecallQueryKind> = plan
        .query_fixtures
        .iter()
        .map(|query| query.query_kind)
        .collect();
    for required in [
        TurboVecRecallQueryKind::ExactHit,
        TurboVecRecallQueryKind::PrivateDeletedExcluded,
        TurboVecRecallQueryKind::DuplicateSourceDeduped,
        TurboVecRecallQueryKind::RecallMissAbstains,
        TurboVecRecallQueryKind::EmptyAllowedVisible,
    ] {
        if !kinds.contains(&required) {
            return Err(TurboVecRecallQualityError::MissingQueryCoverage(
                plan.plan_id.clone(),
            ));
        }
    }
    for query in &plan.query_fixtures {
        if !ids.insert(query.query_id.clone()) {
            return Err(TurboVecRecallQualityError::DuplicateQueryId(
                query.query_id.clone(),
            ));
        }
        validate_query(query, &plan.policy)?;
    }
    Ok(())
}

fn validate_query(
    query: &TurboVecRecallQueryFixture,
    policy: &TurboVecRecallQualityPolicy,
) -> Result<(), TurboVecRecallQualityError> {
    require_nonempty(&query.query_id, "query_id", &query.query_id)?;
    require_prefix(
        "exact_baseline_ref",
        &query.exact_baseline_ref,
        APP_COLD_STORE_EXACT_PREFIX,
    )?;
    for (field, value, prefix) in [
        ("fallback_ref", &query.fallback_ref, FALSIFIER_PREFIX),
        ("rollback_ref", &query.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &query.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &query.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
    ] {
        require_prefix(field, value, prefix)?;
    }
    if query.top_k == 0 || query.top_k > MAX_TOP_K {
        return invalid_query(query, "top_k must be in 1..=50");
    }
    if query.approximate_result_external_ids.len() as u64 > query.top_k {
        return invalid_query(query, "result count exceeds top_k");
    }
    if query.recall_floor_micros != policy.recall_floor_micros {
        return invalid_query(query, "query recall floor must match policy");
    }
    if !query.exact_baseline_is_exhaustive {
        return invalid_query(query, "exact baseline must be exhaustive");
    }
    if query.latency_budget_micros == 0 {
        return invalid_query(query, "latency budget must be declared");
    }
    if query.planned_memory_bytes == 0 {
        return invalid_query(query, "planned memory bytes must be declared");
    }
    if query.opened_index_bytes > 0
        || query.loaded_index_bytes > 0
        || query.runtime_bytes_loaded > 0
        || query.model_bytes_loaded > 0
        || query.provider_calls_made > 0
    {
        return invalid_query(query, "runtime/index/model/provider bytes must remain zero");
    }
    for (name, values) in [
        (
            "exact_baseline_external_ids",
            &query.exact_baseline_external_ids,
        ),
        (
            "approximate_result_external_ids",
            &query.approximate_result_external_ids,
        ),
        ("allowed_external_ids", &query.allowed_external_ids),
    ] {
        if contains_duplicate(values) {
            return invalid_query(query, &format!("{name} contains duplicate IDs"));
        }
    }
    let allowed: HashSet<u64> = query.allowed_external_ids.iter().copied().collect();
    let deleted: HashSet<u64> = query.deleted_external_ids.iter().copied().collect();
    let private: HashSet<u64> = query.private_external_ids.iter().copied().collect();
    let unknown: HashSet<u64> = query.unknown_external_ids.iter().copied().collect();
    for result_id in &query.approximate_result_external_ids {
        if !allowed.contains(result_id) {
            return invalid_query(query, "result escaped allowlist");
        }
        if deleted.contains(result_id) || private.contains(result_id) || unknown.contains(result_id)
        {
            return invalid_query(query, "result contains deleted/private/unknown ID");
        }
    }
    for baseline_id in &query.exact_baseline_external_ids {
        if deleted.contains(baseline_id)
            || private.contains(baseline_id)
            || unknown.contains(baseline_id)
        {
            return invalid_query(query, "exact baseline contains forbidden ID");
        }
    }
    let calculated = recall_at_k_micros(query);
    if query.declared_recall_at_k_micros != calculated {
        return invalid_query(
            query,
            "declared recall does not match exact baseline calculation",
        );
    }
    if calculated < policy.recall_floor_micros
        && (!query.fallback_on_miss_required || !query.fallback_on_miss_present)
    {
        return invalid_query(query, "below-floor recall did not abstain/fallback");
    }
    if query.exact_baseline_external_ids.is_empty()
        && (!query.approximate_result_external_ids.is_empty()
            || !query.visible_answer_packet_on_empty)
    {
        return invalid_query(
            query,
            "empty exact result must emit visible empty AnswerPacket",
        );
    }
    if query.route_mutation_allowed {
        return invalid_query(query, "query allows route mutation");
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecRecallQualityExactBaselinePlan,
) -> Result<(), TurboVecRecallQualityError> {
    if plan.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || plan.byte_ledger.fixture_bytes_read > MAX_FIXTURE_BYTES
    {
        return Err(TurboVecRecallQualityError::MetadataBudgetExceeded {
            metadata_bytes_read: plan.byte_ledger.metadata_bytes_read,
            fixture_bytes_read: plan.byte_ledger.fixture_bytes_read,
        });
    }
    if plan.byte_ledger.exact_baseline_bytes_opened > 0
        || plan.byte_ledger.index_bytes_opened > 0
        || plan.byte_ledger.index_bytes_loaded > 0
        || plan.byte_ledger.runtime_bytes_loaded > 0
        || plan.byte_ledger.model_bytes_loaded > 0
        || plan.byte_ledger.provider_calls_made > 0
        || plan.byte_ledger.copied_product_file_count > 0
    {
        return Err(TurboVecRecallQualityError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    plan_id: &str,
    refs: &TurboVecRecallQualityProofRefs,
) -> Result<(), TurboVecRecallQualityError> {
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
            return Err(TurboVecRecallQualityError::MissingField { field, plan_id: id });
        }
        require_prefix(field, value, prefix)?;
    }
    Ok(())
}

fn invalid_query(
    query: &TurboVecRecallQueryFixture,
    reason: &str,
) -> Result<(), TurboVecRecallQualityError> {
    Err(TurboVecRecallQualityError::InvalidQuery {
        query_id: query.query_id.clone(),
        reason: reason.to_string(),
    })
}

fn require_nonempty(
    value: &str,
    field: &'static str,
    plan_id: &str,
) -> Result<(), TurboVecRecallQualityError> {
    if value.trim().is_empty() {
        return Err(TurboVecRecallQualityError::MissingField {
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
) -> Result<(), TurboVecRecallQualityError> {
    if !value.starts_with(expected) {
        return Err(TurboVecRecallQualityError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        });
    }
    Ok(())
}

fn contains_duplicate(values: &[u64]) -> bool {
    let mut seen = HashSet::with_capacity(values.len());
    values.iter().any(|value| !seen.insert(*value))
}

fn forbidden_result_count(query: &TurboVecRecallQueryFixture) -> u64 {
    let allowed: HashSet<u64> = query.allowed_external_ids.iter().copied().collect();
    let deleted: HashSet<u64> = query.deleted_external_ids.iter().copied().collect();
    let private: HashSet<u64> = query.private_external_ids.iter().copied().collect();
    let unknown: HashSet<u64> = query.unknown_external_ids.iter().copied().collect();
    query
        .approximate_result_external_ids
        .iter()
        .filter(|id| {
            !allowed.contains(id)
                || deleted.contains(id)
                || private.contains(id)
                || unknown.contains(id)
        })
        .count() as u64
}

fn deterministic_set_address(
    plans: &[TurboVecRecallQualityExactBaselinePlan],
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
) -> UasAddress {
    let mut parts = vec![
        format!("metadata={metadata_bytes_read}"),
        format!("fixture={fixture_bytes_read}"),
    ];
    for plan in plans {
        parts.push(format!("plan={}", plan.plan_id));
        let mut query_parts = plan
            .query_fixtures
            .iter()
            .map(|query| {
                let mut exact = query.exact_baseline_external_ids.clone();
                let mut approximate = query.approximate_result_external_ids.clone();
                let mut allowed = query.allowed_external_ids.clone();
                exact.sort_unstable();
                approximate.sort_unstable();
                allowed.sort_unstable();
                format!(
                    "{}|{:?}|{}|{}|{:?}|{:?}|{:?}|{}|{}",
                    query.query_id,
                    query.query_kind,
                    query.top_k,
                    query.exact_baseline_ref,
                    exact,
                    approximate,
                    allowed,
                    query.declared_recall_at_k_micros,
                    query.fallback_on_miss_present
                )
            })
            .collect::<Vec<_>>();
        query_parts.sort();
        parts.extend(query_parts);
    }
    UasAddress::new(
        UasKind::Other(TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_CURSOR.to_string()),
        sha256_hex(parts.join("\n").as_bytes()).as_bytes(),
        1_779_039_400_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::stable_external_id_for_uas;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_crash_safe_persistent_index_plan".to_string()),
            b"upstream-persistent-index",
            1_779_039_300_000,
        )
    }

    fn source(label: &str) -> UasAddress {
        UasAddress::new(
            UasKind::Other("eidos_app_cold_store_source".to_string()),
            label.as_bytes(),
            1_779_039_400_000,
        )
    }

    fn ids(labels: &[&str]) -> Vec<u64> {
        labels
            .iter()
            .map(|label| stable_external_id_for_uas(&source(label)))
            .collect()
    }

    fn query(
        query_id: &str,
        kind: TurboVecRecallQueryKind,
        exact: Vec<u64>,
        approximate: Vec<u64>,
        allowed: Vec<u64>,
    ) -> TurboVecRecallQueryFixture {
        let mut query = TurboVecRecallQueryFixture {
            query_id: query_id.to_string(),
            query_kind: kind,
            query_uas_address: source(&format!("query:{query_id}")),
            top_k: 10,
            exact_baseline_external_ids: exact,
            approximate_result_external_ids: approximate,
            allowed_external_ids: allowed,
            deleted_external_ids: ids(&[&format!("deleted:{query_id}")]),
            private_external_ids: ids(&[&format!("private:{query_id}")]),
            unknown_external_ids: ids(&[&format!("unknown:{query_id}")]),
            deduped_duplicate_source_count: 0,
            exact_baseline_ref: format!("app_cold_store:exact_baseline:{query_id}"),
            exact_baseline_is_exhaustive: true,
            recall_floor_micros: 900_000,
            declared_recall_at_k_micros: 1_000_000,
            fallback_on_miss_required: false,
            fallback_on_miss_present: false,
            visible_answer_packet_on_empty: false,
            route_mutation_allowed: false,
            latency_budget_micros: 10_000,
            measured_latency_micros: 0,
            planned_memory_bytes: 16_384,
            opened_index_bytes: 0,
            loaded_index_bytes: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            fallback_ref: format!("falsifier:F-TurboVec-RecallQualityExactBaseline:{query_id}"),
            rollback_ref: format!("rollback:turbovec_recall_quality:{query_id}"),
            run_event_log_ref: format!("run_event_log:turbovec_recall_quality:{query_id}"),
            answer_packet_ref: format!("answer_packet:turbovec_recall_quality:{query_id}"),
        };
        query.declared_recall_at_k_micros = recall_at_k_micros(&query);
        query
    }

    fn accepted_plan(upstream: UasAddress) -> TurboVecRecallQualityExactBaselinePlan {
        let exact_ids = ids(&["exact-a", "exact-b"]);
        let private_safe = ids(&["private-safe"]);
        let duplicate = ids(&["duplicate-source"]);
        let miss = ids(&["miss-a", "miss-b"]);
        let mut queries = vec![
            query(
                "exact_hit",
                TurboVecRecallQueryKind::ExactHit,
                exact_ids.clone(),
                exact_ids.clone(),
                exact_ids,
            ),
            query(
                "private_deleted_excluded",
                TurboVecRecallQueryKind::PrivateDeletedExcluded,
                private_safe.clone(),
                private_safe.clone(),
                private_safe,
            ),
            query(
                "duplicate_source_deduped",
                TurboVecRecallQueryKind::DuplicateSourceDeduped,
                duplicate.clone(),
                duplicate.clone(),
                duplicate,
            ),
            query(
                "recall_miss_abstains",
                TurboVecRecallQueryKind::RecallMissAbstains,
                miss.clone(),
                vec![miss[0]],
                miss,
            ),
            query(
                "empty_allowed_visible",
                TurboVecRecallQueryKind::EmptyAllowedVisible,
                vec![],
                vec![],
                vec![],
            ),
        ];
        queries[2].deduped_duplicate_source_count = 1;
        queries[3].fallback_on_miss_required = true;
        queries[3].fallback_on_miss_present = true;
        queries[3].declared_recall_at_k_micros = recall_at_k_micros(&queries[3]);
        queries[4].visible_answer_packet_on_empty = true;
        queries[4].declared_recall_at_k_micros = recall_at_k_micros(&queries[4]);

        TurboVecRecallQualityExactBaselinePlan {
            plan_id: "turbovec_recall_quality_exact_baseline".to_string(),
            upstream_persistent_index_address: upstream,
            upstream_persistent_index_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            status: TurboVecRecallQualityStatus::MetadataOnlyPlan,
            promotion_tier: TurboVecRecallQualityPromotionTier::T1L1Metadata,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            policy: TurboVecRecallQualityPolicy::exact_baseline_gate(900_000),
            query_fixtures: queries,
            byte_ledger: TurboVecRecallQualityByteLedger::metadata_only(20_000, 12_000).unwrap(),
            proof_refs: TurboVecRecallQualityProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-RecallQualityExactBaseline:test".to_string(),
                rollback_ref: "rollback:turbovec_recall_quality:test".to_string(),
                run_event_log_ref: "run_event_log:turbovec_recall_quality:test".to_string(),
                answer_packet_ref: "answer_packet:turbovec_recall_quality:test".to_string(),
                compatibility_fence_ref: "compat:turbovec_recall_quality:test".to_string(),
            },
            hidden_route_authority: false,
            product_capability_promoted: false,
            live_large_model_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn build_set(
        upstream: UasAddress,
        plans: Vec<TurboVecRecallQualityExactBaselinePlan>,
    ) -> Result<TurboVecRecallQualityExactBaselinePlanSet, TurboVecRecallQualityError> {
        TurboVecRecallQualityExactBaselinePlanSet::from_plans(
            upstream,
            plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRecallQualityStatus::MetadataOnlyPlan,
            TurboVecRecallQualityPromotionTier::T1L1Metadata,
            20_000,
            12_000,
            false,
        )
    }

    #[test]
    fn accepts_recall_quality_plan_and_deterministic_address() {
        let upstream = upstream_address();
        let plan = accepted_plan(upstream.clone());
        let set = build_set(upstream.clone(), vec![plan.clone()]).unwrap();
        let mut reversed = plan;
        reversed.query_fixtures.reverse();
        for query in &mut reversed.query_fixtures {
            query.approximate_result_external_ids.reverse();
            query.allowed_external_ids.reverse();
        }
        let set_reversed = build_set(upstream, vec![reversed]).unwrap();
        assert_eq!(set.set_address, set_reversed.set_address);
        let metrics = set.metrics();
        assert_eq!(metrics.query_count, 5);
        assert_eq!(metrics.forbidden_result_count, 0);
        assert_eq!(metrics.below_floor_without_fallback_count, 0);
        assert!(metrics.all_pass_or_abstain);
    }

    #[test]
    fn rejects_recall_miss_without_visible_fallback() {
        let upstream = upstream_address();
        let mut plan = accepted_plan(upstream.clone());
        let miss = plan
            .query_fixtures
            .iter_mut()
            .find(|query| query.query_kind == TurboVecRecallQueryKind::RecallMissAbstains)
            .unwrap();
        miss.fallback_on_miss_present = false;
        assert!(build_set(upstream, vec![plan]).is_err());
    }

    #[test]
    fn rejects_forbidden_results_and_duplicate_ids() {
        let upstream = upstream_address();
        let mut private_plan = accepted_plan(upstream.clone());
        let private = private_plan.query_fixtures[1].private_external_ids[0];
        private_plan.query_fixtures[1]
            .approximate_result_external_ids
            .push(private);
        private_plan.query_fixtures[1]
            .allowed_external_ids
            .push(private);
        private_plan.query_fixtures[1].declared_recall_at_k_micros =
            recall_at_k_micros(&private_plan.query_fixtures[1]);
        assert!(build_set(upstream.clone(), vec![private_plan]).is_err());

        let mut duplicate_plan = accepted_plan(upstream.clone());
        let duplicate = duplicate_plan.query_fixtures[0].approximate_result_external_ids[0];
        duplicate_plan.query_fixtures[0]
            .approximate_result_external_ids
            .push(duplicate);
        assert!(build_set(upstream, vec![duplicate_plan]).is_err());
    }

    #[test]
    fn rejects_product_promotion_hidden_authority_and_bytes() {
        let upstream = upstream_address();
        let mut promoted = accepted_plan(upstream.clone());
        promoted.product_capability_promoted = true;
        assert!(build_set(upstream.clone(), vec![promoted]).is_err());

        let mut hidden = accepted_plan(upstream.clone());
        hidden.hidden_route_authority = true;
        assert!(build_set(upstream.clone(), vec![hidden]).is_err());

        let mut bytes = accepted_plan(upstream.clone());
        bytes.byte_ledger.index_bytes_loaded = 1;
        assert!(build_set(upstream, vec![bytes]).is_err());
    }
}
