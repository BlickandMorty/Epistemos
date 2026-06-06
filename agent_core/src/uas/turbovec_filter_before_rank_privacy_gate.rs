//! TurboVec filter-before-rank privacy gate.
//!
//! This primitive turns the TurboVec stable external-ID registry into a
//! fail-closed retrieval privacy rule: Scope/Sovereign allowlists must compile
//! to UAS-derived external `u64` IDs before a TurboVec adapter may rank, score,
//! or expose any candidate. The witness is metadata-only; no TurboVec crate,
//! index bytes, model bytes, runtime bytes, or live recall claims are involved.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    stable_external_id_for_uas, ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind,
};

pub const TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_CURSOR: &str =
    "turbovec_filter_before_rank_privacy_gate_plan";
pub const TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_NEXT_CURSOR: &str =
    "turbovec_crash_safe_persistent_index_plan";

const SOURCE_API_PREFIX: &str = "https://github.com/RyanCodrai/turbovec";
const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_uas_address_stable_external_ids:result";
const FORBIDDEN_HIT_AUDIT_PREFIX: &str = "forbidden_hit_audit:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_MANIFEST_BYTES: u64 = 128 * 1024;

// UAS: uas:turbovec-filter-before-rank:status
// Plane: Verification
// Residency: metadata-only privacy gate status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFilterBeforeRankStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-filter-before-rank:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFilterBeforeRankPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-filter-before-rank:access-decision
// Plane: Controller + Verification
// Residency: admission result before adapter scoring.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecAccessDecision {
    Allowed,
    ForbiddenPlane,
    PrivateScope,
    UnknownExternalId,
}

// UAS: uas:turbovec-filter-before-rank:fixture-kind
// Plane: Verification
// Residency: synthetic privacy fixture coverage.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFilterFixtureKind {
    OneAllowed,
    AllDenied,
    DuplicateAllowedIds,
    UnknownIdProbe,
    ForbiddenPlaneProbe,
}

// UAS: uas:turbovec-filter-before-rank:candidate
// Plane: State + Verification
// Residency: candidate evidence before and after allowlist compilation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecCandidateEvidence {
    pub candidate_id: String,
    pub uas_address: UasAddress,
    pub external_id: u64,
    pub access_decision: TurboVecAccessDecision,
    pub raw_score_rank: u64,
    pub compiled_allowlist_contains: bool,
    pub scored_by_adapter: bool,
    pub exposed_in_results: bool,
    pub exact_source_check_passed: bool,
}

// UAS: uas:turbovec-filter-before-rank:allowlist
// Plane: Controller + Verification
// Residency: compiled ID set supplied to the adapter before scoring.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAllowlistCompilation {
    pub raw_allowed_external_ids: Vec<u64>,
    pub compiled_allowed_external_ids: Vec<u64>,
    pub unknown_external_ids: Vec<u64>,
    pub duplicate_input_count: u64,
    pub compiled_before_rank: bool,
    pub post_filter_after_rank_used: bool,
    pub unknown_ids_rejected: bool,
    pub empty_allowlist_answer_packet_emitted: bool,
}

// UAS: uas:turbovec-filter-before-rank:scenario
// Plane: Controller + Verification
// Residency: tiny synthetic fixtures; no index or vector bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankScenario {
    pub scenario_id: String,
    pub kind: TurboVecFilterFixtureKind,
    pub candidates: Vec<TurboVecCandidateEvidence>,
    pub allowlist: TurboVecAllowlistCompilation,
    pub forbidden_hit_audit_ref: String,
    pub answer_packet_ref: String,
}

// UAS: uas:turbovec-filter-before-rank:policy
// Plane: Controller + Verification
// Residency: fail-closed privacy policy before compressed retrieval can run.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankPolicy {
    pub scope_rex_gate_required: bool,
    pub sovereign_gate_required: bool,
    pub allowlist_compiled_before_rank: bool,
    pub post_filter_after_rank_allowed: bool,
    pub forbidden_id_scoring_allowed: bool,
    pub private_vector_scoring_allowed: bool,
    pub unknown_external_id_rejected: bool,
    pub duplicate_allowed_ids_deduplicated: bool,
    pub empty_allowlist_answer_packet_required: bool,
    pub exact_source_check_after_rank_required: bool,
    pub forbidden_hit_audit_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub rollback_required: bool,
    pub compatibility_fence_required: bool,
    pub eidos_score_can_select_route: bool,
}

impl TurboVecFilterBeforeRankPolicy {
    pub fn fail_closed_privacy_gate() -> Self {
        Self {
            scope_rex_gate_required: true,
            sovereign_gate_required: true,
            allowlist_compiled_before_rank: true,
            post_filter_after_rank_allowed: false,
            forbidden_id_scoring_allowed: false,
            private_vector_scoring_allowed: false,
            unknown_external_id_rejected: true,
            duplicate_allowed_ids_deduplicated: true,
            empty_allowlist_answer_packet_required: true,
            exact_source_check_after_rank_required: true,
            forbidden_hit_audit_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            rollback_required: true,
            compatibility_fence_required: true,
            eidos_score_can_select_route: false,
        }
    }
}

// UAS: uas:turbovec-filter-before-rank:byte-ledger
// Plane: Verification
// Residency: metadata-only proof boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankByteLedger {
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub search_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecFilterBeforeRankByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        manifest_bytes_read: u64,
    ) -> Result<Self, TurboVecFilterBeforeRankError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || manifest_bytes_read > MAX_MANIFEST_BYTES {
            return Err(TurboVecFilterBeforeRankError::MetadataBudgetExceeded {
                metadata_bytes_read,
                manifest_bytes_read,
            });
        }
        Ok(Self {
            metadata_bytes_read,
            manifest_bytes_read,
            search_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        })
    }
}

// UAS: uas:turbovec-filter-before-rank:proof-refs
// Plane: Verification
// Residency: visible proof handles required before live compressed retrieval.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-filter-before-rank:plan
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only privacy gate plan.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankPlan {
    pub plan_id: String,
    pub upstream_registry_address: UasAddress,
    pub upstream_registry_witness_ref: String,
    pub source_api_ref: String,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub scenarios: Vec<TurboVecFilterBeforeRankScenario>,
    pub policy: TurboVecFilterBeforeRankPolicy,
    pub byte_ledger: TurboVecFilterBeforeRankByteLedger,
    pub proof_refs: TurboVecFilterBeforeRankProofRefs,
    pub filter_status: TurboVecFilterBeforeRankStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: TurboVecFilterBeforeRankPromotionTier,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub index_build_deferred: bool,
    pub product_promotion_blocked: bool,
    pub hidden_route_authority_allowed: bool,
    pub route_mutation_allowed: bool,
    pub live_recall_quality_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
}

// UAS: uas:turbovec-filter-before-rank:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only privacy gate pack.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankPlanSet {
    pub set_address: UasAddress,
    pub upstream_registry_address: UasAddress,
    pub upstream_registry_witness_ref: String,
    pub plans: Vec<TurboVecFilterBeforeRankPlan>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub filter_status: TurboVecFilterBeforeRankStatus,
    pub promotion_tier: TurboVecFilterBeforeRankPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:turbovec-filter-before-rank:metrics
// Plane: Verification
// Residency: counters for this metadata-only privacy witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFilterBeforeRankMetrics {
    pub plan_count: u64,
    pub scenario_count: u64,
    pub allowed_candidate_count: u64,
    pub forbidden_candidate_count: u64,
    pub private_candidate_count: u64,
    pub unknown_candidate_count: u64,
    pub scored_candidate_count: u64,
    pub forbidden_scored_count: u64,
    pub exposed_forbidden_count: u64,
    pub empty_allowlist_packet_count: u64,
    pub duplicate_allowlist_input_count: u64,
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub search_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecFilterBeforeRankPlanSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_plans(
        upstream_registry_address: UasAddress,
        upstream_registry_witness_ref: impl Into<String>,
        mut plans: Vec<TurboVecFilterBeforeRankPlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        filter_status: TurboVecFilterBeforeRankStatus,
        promotion_tier: TurboVecFilterBeforeRankPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, TurboVecFilterBeforeRankError> {
        plans.sort_by(|a, b| a.plan_id.cmp(&b.plan_id));
        let witness_ref = upstream_registry_witness_ref.into();
        validate_set_inputs(
            &upstream_registry_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            &filter_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = set_preimage(
            &upstream_registry_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            &filter_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_registry_address,
            upstream_registry_witness_ref: witness_ref,
            plans,
            product_build,
            pro_status,
            filter_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> TurboVecFilterBeforeRankMetrics {
        let mut metrics = TurboVecFilterBeforeRankMetrics {
            plan_count: self.plans.len() as u64,
            scenario_count: 0,
            allowed_candidate_count: 0,
            forbidden_candidate_count: 0,
            private_candidate_count: 0,
            unknown_candidate_count: 0,
            scored_candidate_count: 0,
            forbidden_scored_count: 0,
            exposed_forbidden_count: 0,
            empty_allowlist_packet_count: 0,
            duplicate_allowlist_input_count: 0,
            metadata_bytes_read: self.metadata_bytes,
            manifest_bytes_read: 0,
            search_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        };
        for plan in &self.plans {
            metrics.metadata_bytes_read += plan.byte_ledger.metadata_bytes_read;
            metrics.manifest_bytes_read += plan.byte_ledger.manifest_bytes_read;
            metrics.search_bytes_loaded += plan.byte_ledger.search_bytes_loaded;
            metrics.index_bytes_loaded += plan.byte_ledger.index_bytes_loaded;
            metrics.runtime_bytes_loaded += plan.byte_ledger.runtime_bytes_loaded;
            metrics.model_bytes_loaded += plan.byte_ledger.model_bytes_loaded;
            metrics.provider_calls_made += plan.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += plan.byte_ledger.copied_product_file_count;
            for scenario in &plan.scenarios {
                metrics.scenario_count += 1;
                metrics.duplicate_allowlist_input_count += scenario.allowlist.duplicate_input_count;
                if scenario.allowlist.empty_allowlist_answer_packet_emitted {
                    metrics.empty_allowlist_packet_count += 1;
                }
                for candidate in &scenario.candidates {
                    match candidate.access_decision {
                        TurboVecAccessDecision::Allowed => metrics.allowed_candidate_count += 1,
                        TurboVecAccessDecision::ForbiddenPlane => {
                            metrics.forbidden_candidate_count += 1
                        }
                        TurboVecAccessDecision::PrivateScope => {
                            metrics.private_candidate_count += 1
                        }
                        TurboVecAccessDecision::UnknownExternalId => {
                            metrics.unknown_candidate_count += 1
                        }
                    }
                    if candidate.scored_by_adapter {
                        metrics.scored_candidate_count += 1;
                    }
                    if candidate.scored_by_adapter
                        && candidate.access_decision != TurboVecAccessDecision::Allowed
                    {
                        metrics.forbidden_scored_count += 1;
                    }
                    if candidate.exposed_in_results
                        && candidate.access_decision != TurboVecAccessDecision::Allowed
                    {
                        metrics.exposed_forbidden_count += 1;
                    }
                }
            }
        }
        metrics
    }
}

// UAS: uas:turbovec-filter-before-rank:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy for privacy planning.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecFilterBeforeRankError {
    MissingUpstreamRegistry,
    MissingUpstreamWitness,
    BadUpstreamCursor,
    EmptyPlans,
    DuplicatePlanId(String),
    DuplicateScenarioId(String),
    MissingField {
        plan_id: String,
        field: &'static str,
    },
    BadPrefix {
        plan_id: String,
        field: &'static str,
        expected: &'static str,
    },
    BadProductBuild(String),
    BadProStatus(String),
    BadFilterStatus(String),
    BadPromotionTier(String),
    InvalidOrgans(String),
    MissingScenarioCoverage(String),
    InvalidScenario(String),
    InvalidCandidate {
        candidate_id: String,
        reason: &'static str,
    },
    InvalidAllowlist(String),
    InvalidPolicy(String),
    InvalidProofRefs(String),
    MetadataBudgetExceeded {
        metadata_bytes_read: u64,
        manifest_bytes_read: u64,
    },
    RuntimeOrIndexNotDeferred(String),
    HiddenAuthority(String),
    ProductPromotionAllowed(String),
    SetPromotionAllowed,
}

impl fmt::Display for TurboVecFilterBeforeRankError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamRegistry => write!(f, "missing upstream stable-ID registry"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream stable-ID witness"),
            Self::BadUpstreamCursor => write!(
                f,
                "upstream stable-ID registry did not point at filter-before-rank cursor"
            ),
            Self::EmptyPlans => write!(f, "TurboVec filter-before-rank plan set is empty"),
            Self::DuplicatePlanId(id) => write!(f, "duplicate TurboVec privacy plan `{id}`"),
            Self::DuplicateScenarioId(id) => write!(f, "duplicate TurboVec privacy scenario `{id}`"),
            Self::MissingField { plan_id, field } => {
                write!(f, "TurboVec privacy plan `{plan_id}` missing `{field}`")
            }
            Self::BadPrefix {
                plan_id,
                field,
                expected,
            } => write!(
                f,
                "TurboVec privacy plan `{plan_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadProductBuild(id) => write!(f, "TurboVec privacy plan `{id}` leaked to MAS"),
            Self::BadProStatus(id) => {
                write!(f, "TurboVec privacy plan `{id}` has forbidden Pro status")
            }
            Self::BadFilterStatus(id) => {
                write!(f, "TurboVec privacy plan `{id}` has forbidden status")
            }
            Self::BadPromotionTier(id) => {
                write!(f, "TurboVec privacy plan `{id}` promoted beyond T1")
            }
            Self::InvalidOrgans(id) => write!(f, "TurboVec privacy plan `{id}` has invalid organs"),
            Self::MissingScenarioCoverage(id) => {
                write!(f, "TurboVec privacy plan `{id}` lacks required red/green scenarios")
            }
            Self::InvalidScenario(id) => write!(f, "TurboVec privacy scenario `{id}` is unsafe"),
            Self::InvalidCandidate {
                candidate_id,
                reason,
            } => write!(f, "TurboVec privacy candidate `{candidate_id}` invalid: {reason}"),
            Self::InvalidAllowlist(id) => write!(f, "TurboVec privacy scenario `{id}` has unsafe allowlist"),
            Self::InvalidPolicy(id) => write!(f, "TurboVec privacy plan `{id}` has unsafe policy"),
            Self::InvalidProofRefs(id) => {
                write!(f, "TurboVec privacy plan `{id}` has unsafe proof refs")
            }
            Self::MetadataBudgetExceeded {
                metadata_bytes_read,
                manifest_bytes_read,
            } => write!(
                f,
                "TurboVec privacy metadata budget exceeded: metadata={metadata_bytes_read}, manifest={manifest_bytes_read}"
            ),
            Self::RuntimeOrIndexNotDeferred(id) => {
                write!(f, "TurboVec privacy plan `{id}` tried to build or run")
            }
            Self::HiddenAuthority(id) => {
                write!(f, "TurboVec privacy plan `{id}` enabled hidden authority")
            }
            Self::ProductPromotionAllowed(id) => {
                write!(f, "TurboVec privacy plan `{id}` promoted product truth")
            }
            Self::SetPromotionAllowed => write!(f, "TurboVec privacy set promoted product truth"),
        }
    }
}

impl std::error::Error for TurboVecFilterBeforeRankError {}

fn validate_set_inputs(
    upstream_registry_address: &UasAddress,
    upstream_witness_ref: &str,
    plans: &[TurboVecFilterBeforeRankPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    filter_status: &TurboVecFilterBeforeRankStatus,
    promotion_tier: &TurboVecFilterBeforeRankPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if upstream_registry_address.to_string().trim().is_empty() {
        return Err(TurboVecFilterBeforeRankError::MissingUpstreamRegistry);
    }
    if upstream_witness_ref.trim().is_empty() {
        return Err(TurboVecFilterBeforeRankError::MissingUpstreamWitness);
    }
    if upstream_witness_ref != UPSTREAM_WITNESS_REF {
        return Err(TurboVecFilterBeforeRankError::MissingUpstreamWitness);
    }
    if !matches!(
        upstream_registry_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_stable_external_id_registry_plan"
    ) {
        return Err(TurboVecFilterBeforeRankError::BadUpstreamCursor);
    }
    if plans.is_empty() {
        return Err(TurboVecFilterBeforeRankError::EmptyPlans);
    }
    if metadata_bytes > MAX_METADATA_BYTES {
        return Err(TurboVecFilterBeforeRankError::MetadataBudgetExceeded {
            metadata_bytes_read: metadata_bytes,
            manifest_bytes_read: 0,
        });
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || filter_status != &TurboVecFilterBeforeRankStatus::MetadataOnlyPlan
        || !matches!(
            promotion_tier,
            TurboVecFilterBeforeRankPromotionTier::T0Research
                | TurboVecFilterBeforeRankPromotionTier::T1L1Metadata
        )
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(TurboVecFilterBeforeRankError::SetPromotionAllowed);
    }

    let mut plan_ids = HashSet::new();
    for plan in plans {
        if plan.upstream_registry_address != *upstream_registry_address {
            return Err(TurboVecFilterBeforeRankError::MissingUpstreamRegistry);
        }
        validate_plan(plan)?;
        if !plan_ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecFilterBeforeRankError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(plan: &TurboVecFilterBeforeRankPlan) -> Result<(), TurboVecFilterBeforeRankError> {
    require_nonempty(&plan.plan_id, &plan.plan_id, "plan_id")?;
    require_nonempty(
        &plan.upstream_registry_witness_ref,
        &plan.plan_id,
        "upstream_registry_witness_ref",
    )?;
    require_nonempty(&plan.source_api_ref, &plan.plan_id, "source_api_ref")?;
    require_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if plan.upstream_registry_witness_ref != UPSTREAM_WITNESS_REF {
        return Err(TurboVecFilterBeforeRankError::MissingUpstreamWitness);
    }
    if !plan.source_api_ref.starts_with(SOURCE_API_PREFIX) {
        return Err(TurboVecFilterBeforeRankError::BadPrefix {
            plan_id: plan.plan_id.clone(),
            field: "source_api_ref",
            expected: SOURCE_API_PREFIX,
        });
    }
    if plan.product_build != ProductBuild::Pro {
        return Err(TurboVecFilterBeforeRankError::BadProductBuild(
            plan.plan_id.clone(),
        ));
    }
    if plan.pro_status != ProStatus::ResearchCandidate {
        return Err(TurboVecFilterBeforeRankError::BadProStatus(
            plan.plan_id.clone(),
        ));
    }
    if plan.filter_status != TurboVecFilterBeforeRankStatus::MetadataOnlyPlan {
        return Err(TurboVecFilterBeforeRankError::BadFilterStatus(
            plan.plan_id.clone(),
        ));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecFilterBeforeRankPromotionTier::T0Research
            | TurboVecFilterBeforeRankPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecFilterBeforeRankError::BadPromotionTier(
            plan.plan_id.clone(),
        ));
    }
    validate_organs(plan)?;
    validate_policy(plan)?;
    validate_scenarios(plan)?;
    validate_byte_ledger(plan)?;
    if !plan.l1_l2_l3_separated
        || !plan.runtime_deferred
        || !plan.index_build_deferred
        || !plan.product_promotion_blocked
    {
        return Err(TurboVecFilterBeforeRankError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    if plan.hidden_route_authority_allowed
        || plan.route_mutation_allowed
        || plan.hidden_cloud_fallback_allowed
    {
        return Err(TurboVecFilterBeforeRankError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_recall_quality_claimed || plan.live_dense_70b_claimed || plan.ssd_as_ram_claimed {
        return Err(TurboVecFilterBeforeRankError::ProductPromotionAllowed(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_organs(
    plan: &TurboVecFilterBeforeRankPlan,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if !plan.organs.contains(&TurboVecIndexOrgan::Eidos)
        || !plan.organs.contains(&TurboVecIndexOrgan::AppColdStore)
        || !plan
            .organs
            .contains(&TurboVecIndexOrgan::SemanticWorkingSetPlan)
        || !plan.organs.contains(&TurboVecIndexOrgan::AnswerPacket)
    {
        return Err(TurboVecFilterBeforeRankError::InvalidOrgans(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_policy(
    plan: &TurboVecFilterBeforeRankPlan,
) -> Result<(), TurboVecFilterBeforeRankError> {
    let policy = &plan.policy;
    if !policy.scope_rex_gate_required
        || !policy.sovereign_gate_required
        || !policy.allowlist_compiled_before_rank
        || policy.post_filter_after_rank_allowed
        || policy.forbidden_id_scoring_allowed
        || policy.private_vector_scoring_allowed
        || !policy.unknown_external_id_rejected
        || !policy.duplicate_allowed_ids_deduplicated
        || !policy.empty_allowlist_answer_packet_required
        || !policy.exact_source_check_after_rank_required
        || !policy.forbidden_hit_audit_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.rollback_required
        || !policy.compatibility_fence_required
        || policy.eidos_score_can_select_route
    {
        return Err(TurboVecFilterBeforeRankError::InvalidPolicy(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_scenarios(
    plan: &TurboVecFilterBeforeRankPlan,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if plan.scenarios.is_empty() {
        return Err(TurboVecFilterBeforeRankError::MissingScenarioCoverage(
            plan.plan_id.clone(),
        ));
    }
    let mut scenario_ids = HashSet::new();
    let mut coverage = HashSet::new();
    for scenario in &plan.scenarios {
        if !scenario_ids.insert(scenario.scenario_id.clone()) {
            return Err(TurboVecFilterBeforeRankError::DuplicateScenarioId(
                scenario.scenario_id.clone(),
            ));
        }
        coverage.insert(scenario.kind);
        validate_scenario(scenario)?;
    }
    for required in [
        TurboVecFilterFixtureKind::OneAllowed,
        TurboVecFilterFixtureKind::AllDenied,
        TurboVecFilterFixtureKind::DuplicateAllowedIds,
        TurboVecFilterFixtureKind::UnknownIdProbe,
        TurboVecFilterFixtureKind::ForbiddenPlaneProbe,
    ] {
        if !coverage.contains(&required) {
            return Err(TurboVecFilterBeforeRankError::MissingScenarioCoverage(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_scenario(
    scenario: &TurboVecFilterBeforeRankScenario,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if scenario.scenario_id.trim().is_empty() {
        return Err(TurboVecFilterBeforeRankError::InvalidScenario(
            scenario.scenario_id.clone(),
        ));
    }
    if !scenario
        .forbidden_hit_audit_ref
        .starts_with(FORBIDDEN_HIT_AUDIT_PREFIX)
        || !scenario.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
    {
        return Err(TurboVecFilterBeforeRankError::InvalidScenario(
            scenario.scenario_id.clone(),
        ));
    }
    validate_allowlist(scenario)?;
    let compiled_ids = scenario
        .allowlist
        .compiled_allowed_external_ids
        .iter()
        .copied()
        .collect::<HashSet<_>>();
    for candidate in &scenario.candidates {
        validate_candidate(candidate, &compiled_ids)?;
    }
    if matches!(
        scenario.kind,
        TurboVecFilterFixtureKind::DuplicateAllowedIds
    ) && scenario.allowlist.duplicate_input_count == 0
    {
        return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
            scenario.scenario_id.clone(),
        ));
    }
    if matches!(scenario.kind, TurboVecFilterFixtureKind::UnknownIdProbe)
        && scenario.allowlist.unknown_external_ids.is_empty()
    {
        return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
            scenario.scenario_id.clone(),
        ));
    }
    if matches!(scenario.kind, TurboVecFilterFixtureKind::AllDenied)
        && scenario
            .candidates
            .iter()
            .any(|candidate| candidate.access_decision == TurboVecAccessDecision::Allowed)
    {
        return Err(TurboVecFilterBeforeRankError::InvalidScenario(
            scenario.scenario_id.clone(),
        ));
    }
    Ok(())
}

fn validate_allowlist(
    scenario: &TurboVecFilterBeforeRankScenario,
) -> Result<(), TurboVecFilterBeforeRankError> {
    let allowlist = &scenario.allowlist;
    if !allowlist.compiled_before_rank
        || allowlist.post_filter_after_rank_used
        || !allowlist.unknown_ids_rejected
    {
        return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
            scenario.scenario_id.clone(),
        ));
    }
    if allowlist.raw_allowed_external_ids.is_empty()
        && !allowlist.empty_allowlist_answer_packet_emitted
    {
        return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
            scenario.scenario_id.clone(),
        ));
    }
    if allowlist.raw_allowed_external_ids.iter().any(|id| *id == 0)
        || allowlist
            .compiled_allowed_external_ids
            .iter()
            .any(|id| *id == 0)
    {
        return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
            scenario.scenario_id.clone(),
        ));
    }
    let mut compiled_unique = HashSet::new();
    for id in &allowlist.compiled_allowed_external_ids {
        if !compiled_unique.insert(*id) {
            return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
                scenario.scenario_id.clone(),
            ));
        }
    }
    let mut raw_seen = HashSet::new();
    let duplicate_count = allowlist
        .raw_allowed_external_ids
        .iter()
        .filter(|id| !raw_seen.insert(**id))
        .count() as u64;
    if duplicate_count != allowlist.duplicate_input_count {
        return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
            scenario.scenario_id.clone(),
        ));
    }
    for unknown in &allowlist.unknown_external_ids {
        if compiled_unique.contains(unknown) {
            return Err(TurboVecFilterBeforeRankError::InvalidAllowlist(
                scenario.scenario_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_candidate(
    candidate: &TurboVecCandidateEvidence,
    compiled_ids: &HashSet<u64>,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if candidate.candidate_id.trim().is_empty() {
        return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
            candidate_id: candidate.candidate_id.clone(),
            reason: "empty candidate ID",
        });
    }
    if candidate.external_id == 0 {
        return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
            candidate_id: candidate.candidate_id.clone(),
            reason: "zero external ID",
        });
    }
    if candidate.external_id != stable_external_id_for_uas(&candidate.uas_address) {
        return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
            candidate_id: candidate.candidate_id.clone(),
            reason: "external ID is not UAS-derived",
        });
    }
    let compiled_contains = compiled_ids.contains(&candidate.external_id);
    if candidate.compiled_allowlist_contains != compiled_contains {
        return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
            candidate_id: candidate.candidate_id.clone(),
            reason: "candidate allowlist flag mismatches compiled IDs",
        });
    }
    match candidate.access_decision {
        TurboVecAccessDecision::Allowed => {
            if !compiled_contains || !candidate.scored_by_adapter {
                return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
                    candidate_id: candidate.candidate_id.clone(),
                    reason: "allowed candidate did not pass pre-rank allowlist scoring",
                });
            }
            if candidate.exposed_in_results && !candidate.exact_source_check_passed {
                return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
                    candidate_id: candidate.candidate_id.clone(),
                    reason: "exposed candidate lacks exact source check",
                });
            }
        }
        TurboVecAccessDecision::ForbiddenPlane
        | TurboVecAccessDecision::PrivateScope
        | TurboVecAccessDecision::UnknownExternalId => {
            if compiled_contains || candidate.scored_by_adapter || candidate.exposed_in_results {
                return Err(TurboVecFilterBeforeRankError::InvalidCandidate {
                    candidate_id: candidate.candidate_id.clone(),
                    reason: "forbidden/private/unknown candidate reached adapter scoring",
                });
            }
        }
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecFilterBeforeRankPlan,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if plan.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || plan.byte_ledger.manifest_bytes_read > MAX_MANIFEST_BYTES
    {
        return Err(TurboVecFilterBeforeRankError::MetadataBudgetExceeded {
            metadata_bytes_read: plan.byte_ledger.metadata_bytes_read,
            manifest_bytes_read: plan.byte_ledger.manifest_bytes_read,
        });
    }
    if plan.byte_ledger.search_bytes_loaded != 0
        || plan.byte_ledger.index_bytes_loaded != 0
        || plan.byte_ledger.runtime_bytes_loaded != 0
        || plan.byte_ledger.model_bytes_loaded != 0
        || plan.byte_ledger.provider_calls_made != 0
        || plan.byte_ledger.copied_product_file_count != 0
    {
        return Err(TurboVecFilterBeforeRankError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn require_nonempty(
    value: &str,
    plan_id: &str,
    field: &'static str,
) -> Result<(), TurboVecFilterBeforeRankError> {
    if value.trim().is_empty() {
        return Err(TurboVecFilterBeforeRankError::MissingField {
            plan_id: plan_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_proof_refs(
    plan_id: &str,
    refs: &TurboVecFilterBeforeRankProofRefs,
) -> Result<(), TurboVecFilterBeforeRankError> {
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
        if !value.starts_with(prefix) {
            return Err(TurboVecFilterBeforeRankError::BadPrefix {
                plan_id: plan_id.to_string(),
                field,
                expected: prefix,
            });
        }
    }
    Ok(())
}

fn set_preimage(
    upstream_registry_address: &UasAddress,
    witness_ref: &str,
    plans: &[TurboVecFilterBeforeRankPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    filter_status: &TurboVecFilterBeforeRankStatus,
    promotion_tier: &TurboVecFilterBeforeRankPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut parts = vec![
        upstream_registry_address.to_string(),
        witness_ref.to_string(),
        format!("{product_build:?}"),
        format!("{pro_status:?}"),
        format!("{filter_status:?}"),
        format!("{promotion_tier:?}"),
        metadata_bytes.to_string(),
        l1_l2_l3_separated.to_string(),
        runtime_deferred.to_string(),
        product_promotion_blocked.to_string(),
    ];
    for plan in plans {
        parts.push(plan.plan_id.clone());
        parts.push(plan.upstream_registry_address.to_string());
        parts.push(plan.upstream_registry_witness_ref.clone());
        parts.push(plan.source_api_ref.clone());
        for organ in &plan.organs {
            parts.push(format!("{organ:?}"));
        }
        let mut scenarios = plan.scenarios.clone();
        scenarios.sort_by(|a, b| a.scenario_id.cmp(&b.scenario_id));
        for scenario in scenarios {
            parts.push(scenario.scenario_id);
            parts.push(format!("{:?}", scenario.kind));
            parts.push(format!("{:?}", scenario.allowlist.raw_allowed_external_ids));
            parts.push(format!(
                "{:?}",
                scenario.allowlist.compiled_allowed_external_ids
            ));
            parts.push(format!("{:?}", scenario.allowlist.unknown_external_ids));
            let mut candidates = scenario.candidates;
            candidates.sort_by(|a, b| a.candidate_id.cmp(&b.candidate_id));
            for candidate in candidates {
                parts.push(candidate.candidate_id);
                parts.push(candidate.uas_address.to_string());
                parts.push(candidate.external_id.to_string());
                parts.push(format!("{:?}", candidate.access_decision));
                parts.push(candidate.raw_score_rank.to_string());
                parts.push(candidate.compiled_allowlist_contains.to_string());
                parts.push(candidate.scored_by_adapter.to_string());
                parts.push(candidate.exposed_in_results.to_string());
                parts.push(candidate.exact_source_check_passed.to_string());
            }
        }
    }
    parts.join("|")
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_039_200_000;

    #[test]
    fn accepts_filter_before_rank_fixture_and_deterministic_address() {
        let upstream = upstream_address();
        let plans = vec![accepted_plan(upstream.clone())];
        let set = build_set(upstream.clone(), plans.clone()).expect("accepted fixture should pass");
        let mut reversed = plans;
        reversed[0].scenarios.reverse();
        reversed[0].scenarios[0].candidates.reverse();
        let reversed_set = build_set(upstream, reversed).expect("reordered fixture should pass");
        assert_eq!(set.set_address, reversed_set.set_address);
        assert_eq!(set.metrics().forbidden_scored_count, 0);
        assert_eq!(set.metrics().exposed_forbidden_count, 0);
    }

    #[test]
    fn rejects_post_filter_and_forbidden_scoring() {
        let upstream = upstream_address();
        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].scenarios[0].allowlist.post_filter_after_rank_used = true;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].scenarios[0].candidates[1].scored_by_adapter = true;
        assert!(build_set(upstream, plans).is_err());
    }

    #[test]
    fn rejects_unknown_and_empty_allowlist_bypasses() {
        let upstream = upstream_address();
        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].scenarios[3].allowlist.unknown_ids_rejected = false;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].scenarios[1]
            .allowlist
            .empty_allowlist_answer_packet_emitted = false;
        assert!(build_set(upstream, plans).is_err());
    }

    #[test]
    fn rejects_runtime_bytes_product_promotion_and_hidden_authority() {
        let upstream = upstream_address();
        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].byte_ledger.index_bytes_loaded = 1;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].promotion_tier = TurboVecFilterBeforeRankPromotionTier::T2L2Route;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].hidden_route_authority_allowed = true;
        assert!(build_set(upstream, plans).is_err());
    }

    fn build_set(
        upstream: UasAddress,
        plans: Vec<TurboVecFilterBeforeRankPlan>,
    ) -> Result<TurboVecFilterBeforeRankPlanSet, TurboVecFilterBeforeRankError> {
        TurboVecFilterBeforeRankPlanSet::from_plans(
            upstream,
            UPSTREAM_WITNESS_REF,
            plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFilterBeforeRankStatus::MetadataOnlyPlan,
            TurboVecFilterBeforeRankPromotionTier::T1L1Metadata,
            12_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn accepted_plan(upstream: UasAddress) -> TurboVecFilterBeforeRankPlan {
        let alpha = candidate(
            "alpha",
            TurboVecAccessDecision::Allowed,
            1,
            true,
            true,
            true,
        );
        let beta = candidate(
            "beta_private",
            TurboVecAccessDecision::PrivateScope,
            0,
            false,
            false,
            false,
        );
        let gamma = candidate(
            "gamma_forbidden",
            TurboVecAccessDecision::ForbiddenPlane,
            0,
            false,
            false,
            false,
        );
        let unknown = candidate(
            "unknown",
            TurboVecAccessDecision::UnknownExternalId,
            0,
            false,
            false,
            false,
        );
        TurboVecFilterBeforeRankPlan {
            plan_id: "turbovec_filter_before_rank_privacy_gate".to_string(),
            upstream_registry_address: upstream,
            upstream_registry_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md"
                .to_string(),
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            scenarios: vec![
                scenario(
                    "one_allowed",
                    TurboVecFilterFixtureKind::OneAllowed,
                    vec![alpha.clone(), beta.clone()],
                    vec![alpha.external_id],
                    vec![alpha.external_id],
                    vec![],
                    0,
                    false,
                ),
                scenario(
                    "all_denied",
                    TurboVecFilterFixtureKind::AllDenied,
                    vec![beta.clone(), gamma.clone()],
                    vec![],
                    vec![],
                    vec![],
                    0,
                    true,
                ),
                scenario(
                    "duplicate_allowed_ids",
                    TurboVecFilterFixtureKind::DuplicateAllowedIds,
                    vec![alpha.clone()],
                    vec![alpha.external_id, alpha.external_id],
                    vec![alpha.external_id],
                    vec![],
                    1,
                    false,
                ),
                scenario(
                    "unknown_id_probe",
                    TurboVecFilterFixtureKind::UnknownIdProbe,
                    vec![unknown],
                    vec![],
                    vec![],
                    vec![u64::MAX - 7],
                    0,
                    true,
                ),
                scenario(
                    "forbidden_plane_probe",
                    TurboVecFilterFixtureKind::ForbiddenPlaneProbe,
                    vec![gamma],
                    vec![],
                    vec![],
                    vec![],
                    0,
                    true,
                ),
            ],
            policy: TurboVecFilterBeforeRankPolicy::fail_closed_privacy_gate(),
            byte_ledger: TurboVecFilterBeforeRankByteLedger::metadata_only(9_600, 3_200).unwrap_or(
                TurboVecFilterBeforeRankByteLedger {
                    metadata_bytes_read: 0,
                    manifest_bytes_read: 0,
                    search_bytes_loaded: 0,
                    index_bytes_loaded: 0,
                    runtime_bytes_loaded: 0,
                    model_bytes_loaded: 0,
                    provider_calls_made: 0,
                    copied_product_file_count: 0,
                },
            ),
            proof_refs: TurboVecFilterBeforeRankProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-FilterBeforeRankPrivacyGate:test".to_string(),
                rollback_ref: "rollback:turbovec_filter:test".to_string(),
                run_event_log_ref: "run_event_log:turbovec_filter:test".to_string(),
                answer_packet_ref: "answer_packet:turbovec_filter:test".to_string(),
                compatibility_fence_ref: "compat:turbovec_filter:test".to_string(),
            },
            filter_status: TurboVecFilterBeforeRankStatus::MetadataOnlyPlan,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: TurboVecFilterBeforeRankPromotionTier::T1L1Metadata,
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            index_build_deferred: true,
            product_promotion_blocked: true,
            hidden_route_authority_allowed: false,
            route_mutation_allowed: false,
            live_recall_quality_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
        }
    }

    fn scenario(
        id: &str,
        kind: TurboVecFilterFixtureKind,
        candidates: Vec<TurboVecCandidateEvidence>,
        raw: Vec<u64>,
        compiled: Vec<u64>,
        unknown: Vec<u64>,
        duplicate_count: u64,
        empty_packet: bool,
    ) -> TurboVecFilterBeforeRankScenario {
        TurboVecFilterBeforeRankScenario {
            scenario_id: id.to_string(),
            kind,
            candidates,
            allowlist: TurboVecAllowlistCompilation {
                raw_allowed_external_ids: raw,
                compiled_allowed_external_ids: compiled,
                unknown_external_ids: unknown,
                duplicate_input_count: duplicate_count,
                compiled_before_rank: true,
                post_filter_after_rank_used: false,
                unknown_ids_rejected: true,
                empty_allowlist_answer_packet_emitted: empty_packet,
            },
            forbidden_hit_audit_ref: format!("forbidden_hit_audit:{id}"),
            answer_packet_ref: format!("answer_packet:{id}"),
        }
    }

    fn candidate(
        id: &str,
        decision: TurboVecAccessDecision,
        rank: u64,
        in_allowlist: bool,
        scored: bool,
        exposed: bool,
    ) -> TurboVecCandidateEvidence {
        let uas_address = UasAddress::new(
            UasKind::Other("eidos_source_chunk".to_string()),
            id.as_bytes(),
            CREATED_AT_MS,
        );
        TurboVecCandidateEvidence {
            candidate_id: id.to_string(),
            external_id: stable_external_id_for_uas(&uas_address),
            uas_address,
            access_decision: decision,
            raw_score_rank: rank,
            compiled_allowlist_contains: in_allowlist,
            scored_by_adapter: scored,
            exposed_in_results: exposed,
            exact_source_check_passed: exposed,
        }
    }

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_stable_external_id_registry_plan".to_string()),
            b"upstream-stable-registry",
            CREATED_AT_MS,
        )
    }
}
