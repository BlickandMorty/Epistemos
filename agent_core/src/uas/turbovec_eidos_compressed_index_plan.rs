//! TurboVec Eidos compressed-index plan.
//!
//! This primitive folds TurboVec/QAT compression research into an Epistemos
//! contract for Eidos/AppColdStore. It is metadata-only: it does not import
//! TurboVec code, build an index, score retrieval, choose routes, or promote
//! product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_CURSOR: &str =
    "turbovec_eidos_compressed_index_plan";
pub const TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_NEXT_CURSOR: &str =
    "turbovec_stable_external_id_registry_plan";

const SOURCE_CARD_PREFIX: &str = "compressed_model_source_card:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_LEDGER_METADATA_BYTES: u64 = 96 * 1024;
const MAX_DIMENSION_COUNT: u64 = 1_000_000;

// UAS: uas:turbovec-eidos-index:organ
// Plane: State + Assembly + Controller + Verification
// Residency: organ allowed to cite the compressed cache after later proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecIndexOrgan {
    Eidos,
    AppColdStore,
    SemanticWorkingSetPlan,
    AnswerPacket,
}

// UAS: uas:turbovec-eidos-index:status
// Plane: Verification
// Residency: planning status only; no index bytes are built or loaded here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecIndexPlanStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-eidos-index:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecIndexPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-eidos-index:byte-ledger
// Plane: Verification
// Residency: declared index math and zero-byte runtime boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecIndexByteLedger {
    pub dimension_count: u64,
    pub float32_vector_bytes: u64,
    pub q4_coordinate_payload_bytes: u64,
    pub q2_coordinate_payload_bytes: u64,
    pub side_table_budget_bytes: u64,
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecIndexByteLedger {
    pub fn metadata_only(
        dimension_count: u64,
        side_table_budget_bytes: u64,
        metadata_bytes_read: u64,
        manifest_bytes_read: u64,
    ) -> Result<Self, TurboVecIndexPlanError> {
        if dimension_count == 0 || dimension_count > MAX_DIMENSION_COUNT {
            return Err(TurboVecIndexPlanError::InvalidByteLedger {
                plan_id: "byte_ledger".to_string(),
                reason: "dimension_count out of accepted range",
            });
        }
        let Some(float32_vector_bytes) = dimension_count.checked_mul(4) else {
            return Err(TurboVecIndexPlanError::InvalidByteLedger {
                plan_id: "byte_ledger".to_string(),
                reason: "float32 byte math overflow",
            });
        };
        Ok(Self {
            dimension_count,
            float32_vector_bytes,
            q4_coordinate_payload_bytes: dimension_count / 2,
            q2_coordinate_payload_bytes: dimension_count / 4,
            side_table_budget_bytes,
            metadata_bytes_read,
            manifest_bytes_read,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        })
    }
}

// UAS: uas:turbovec-eidos-index:external-id-policy
// Plane: State + Verification
// Residency: identity contract for compressed cache rows.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecExternalIdPolicy {
    pub uas_address_is_truth: bool,
    pub sqlite_rowid_allowed: bool,
    pub stable_u64_registry_required: bool,
    pub tombstone_or_generation_required: bool,
    pub collision_ledger_required: bool,
    pub external_id_rewrite_requires_rebuild: bool,
}

impl TurboVecExternalIdPolicy {
    pub fn uas_truth() -> Self {
        Self {
            uas_address_is_truth: true,
            sqlite_rowid_allowed: false,
            stable_u64_registry_required: true,
            tombstone_or_generation_required: true,
            collision_ledger_required: true,
            external_id_rewrite_requires_rebuild: true,
        }
    }
}

// UAS: uas:turbovec-eidos-index:privacy-policy
// Plane: Controller + Verification
// Residency: privacy gate before approximate rank/search.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAllowlistPrivacyPolicy {
    pub allowlist_before_rank_required: bool,
    pub post_filtering_allowed: bool,
    pub empty_allowlist_answer_packet_required: bool,
    pub unknown_allowlist_id_rejected: bool,
    pub forbidden_id_scoring_allowed: bool,
    pub private_vector_payload_scoring_allowed: bool,
}

impl TurboVecAllowlistPrivacyPolicy {
    pub fn filter_before_rank() -> Self {
        Self {
            allowlist_before_rank_required: true,
            post_filtering_allowed: false,
            empty_allowlist_answer_packet_required: true,
            unknown_allowlist_id_rejected: true,
            forbidden_id_scoring_allowed: false,
            private_vector_payload_scoring_allowed: false,
        }
    }
}

// UAS: uas:turbovec-eidos-index:rebuild-policy
// Plane: Assembly + Verification
// Residency: AppColdStore remains truth; compressed index is rebuildable cache.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRebuildPolicy {
    pub app_cold_store_is_truth: bool,
    pub compressed_index_is_cache: bool,
    pub exact_source_check_required: bool,
    pub corrupt_cache_rebuild_required: bool,
    pub atomic_manifest_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
}

impl TurboVecRebuildPolicy {
    pub fn rebuildable_cache() -> Self {
        Self {
            app_cold_store_is_truth: true,
            compressed_index_is_cache: true,
            exact_source_check_required: true,
            corrupt_cache_rebuild_required: true,
            atomic_manifest_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
        }
    }
}

// UAS: uas:turbovec-eidos-index:proof-refs
// Plane: Verification
// Residency: visible proof handles required before build/runtime promotion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecIndexProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-eidos-index:plan
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only plan for a rebuildable compressed Eidos cache.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecEidosCompressedIndexPlan {
    pub plan_id: String,
    pub upstream_turbovec_source_card_ref: String,
    pub source_locator: String,
    pub source_revision_ref: String,
    pub source_api_ref: String,
    pub license_ref: String,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub plan_status: TurboVecIndexPlanStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: TurboVecIndexPromotionTier,
    pub byte_ledger: TurboVecIndexByteLedger,
    pub external_id_policy: TurboVecExternalIdPolicy,
    pub privacy_policy: TurboVecAllowlistPrivacyPolicy,
    pub rebuild_policy: TurboVecRebuildPolicy,
    pub proof_refs: TurboVecIndexProofRefs,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub index_build_deferred: bool,
    pub eidos_score_can_select_route: bool,
    pub route_mutation_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub live_recall_quality_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub product_capability_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
}

// UAS: uas:turbovec-eidos-index:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only plan pack that later byte/runtime witnesses may cite.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecEidosCompressedIndexPlanSet {
    pub set_address: UasAddress,
    pub upstream_intake_address: UasAddress,
    pub upstream_intake_witness_ref: String,
    pub plans: Vec<TurboVecEidosCompressedIndexPlan>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:turbovec-eidos-index:metrics
// Plane: Verification
// Residency: derived counters for the metadata witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecIndexPlanMetrics {
    pub plan_count: u64,
    pub organ_count: u64,
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub dimension_count: u64,
    pub float32_vector_bytes: u64,
    pub q4_coordinate_payload_bytes: u64,
    pub q2_coordinate_payload_bytes: u64,
    pub side_table_budget_bytes: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecEidosCompressedIndexPlanSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_source_cards(
        upstream_intake_address: UasAddress,
        upstream_intake_witness_ref: impl Into<String>,
        mut plans: Vec<TurboVecEidosCompressedIndexPlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, TurboVecIndexPlanError> {
        plans.sort_by(|a, b| a.plan_id.cmp(&b.plan_id));
        let witness_ref = upstream_intake_witness_ref.into();
        validate_set_inputs(
            &upstream_intake_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = plan_set_preimage(
            &upstream_intake_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_intake_address,
            upstream_intake_witness_ref: witness_ref,
            plans,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> TurboVecIndexPlanMetrics {
        let mut organs = BTreeSet::new();
        let mut metadata_bytes_read = self.metadata_bytes;
        let mut manifest_bytes_read = 0;
        let mut dimension_count = 0;
        let mut float32_vector_bytes = 0;
        let mut q4_coordinate_payload_bytes = 0;
        let mut q2_coordinate_payload_bytes = 0;
        let mut side_table_budget_bytes = 0;
        let mut index_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut model_bytes_loaded = 0;
        let mut provider_calls_made = 0;
        let mut copied_product_file_count = 0;

        for plan in &self.plans {
            for organ in &plan.organs {
                organs.insert(*organ);
            }
            let ledger = &plan.byte_ledger;
            metadata_bytes_read += ledger.metadata_bytes_read;
            manifest_bytes_read += ledger.manifest_bytes_read;
            dimension_count += ledger.dimension_count;
            float32_vector_bytes += ledger.float32_vector_bytes;
            q4_coordinate_payload_bytes += ledger.q4_coordinate_payload_bytes;
            q2_coordinate_payload_bytes += ledger.q2_coordinate_payload_bytes;
            side_table_budget_bytes += ledger.side_table_budget_bytes;
            index_bytes_loaded += ledger.index_bytes_loaded;
            runtime_bytes_loaded += ledger.runtime_bytes_loaded;
            model_bytes_loaded += ledger.model_bytes_loaded;
            provider_calls_made += ledger.provider_calls_made;
            copied_product_file_count += ledger.copied_product_file_count;
        }

        TurboVecIndexPlanMetrics {
            plan_count: self.plans.len() as u64,
            organ_count: organs.len() as u64,
            metadata_bytes_read,
            manifest_bytes_read,
            dimension_count,
            float32_vector_bytes,
            q4_coordinate_payload_bytes,
            q2_coordinate_payload_bytes,
            side_table_budget_bytes,
            index_bytes_loaded,
            runtime_bytes_loaded,
            model_bytes_loaded,
            provider_calls_made,
            copied_product_file_count,
        }
    }
}

// UAS: uas:turbovec-eidos-index:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy for compressed-index planning.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecIndexPlanError {
    MissingUpstreamIntake,
    MissingUpstreamWitness,
    EmptyPlans,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicatePlanId(String),
    MissingField {
        plan_id: String,
        field: &'static str,
    },
    BadPrefix {
        plan_id: String,
        field: &'static str,
        expected: &'static str,
    },
    BadSourceLocator(String),
    BadProductBuild(String),
    BadProStatus(String),
    BadPromotionTier(String),
    InvalidOrgans(String),
    InvalidByteLedger {
        plan_id: String,
        reason: &'static str,
    },
    InvalidExternalIdPolicy(String),
    InvalidPrivacyPolicy(String),
    InvalidRebuildPolicy(String),
    RuntimeOrIndexNotDeferred(String),
    HiddenAuthority(String),
    ProductPromotionAllowed(String),
    SetPromotionAllowed,
}

impl fmt::Display for TurboVecIndexPlanError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamIntake => write!(f, "missing upstream source-card intake address"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream source-card witness ref"),
            Self::EmptyPlans => write!(f, "TurboVec Eidos compressed-index plan set is empty"),
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicatePlanId(id) => write!(f, "duplicate TurboVec index plan id `{id}`"),
            Self::MissingField { plan_id, field } => {
                write!(f, "TurboVec index plan `{plan_id}` missing `{field}`")
            }
            Self::BadPrefix {
                plan_id,
                field,
                expected,
            } => write!(
                f,
                "TurboVec index plan `{plan_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadSourceLocator(id) => {
                write!(
                    f,
                    "TurboVec index plan `{id}` source locator must be official GitHub"
                )
            }
            Self::BadProductBuild(id) => write!(f, "TurboVec index plan `{id}` leaked to MAS"),
            Self::BadProStatus(id) => {
                write!(f, "TurboVec index plan `{id}` has forbidden Pro status")
            }
            Self::BadPromotionTier(id) => {
                write!(f, "TurboVec index plan `{id}` promoted beyond T1")
            }
            Self::InvalidOrgans(id) => write!(f, "TurboVec index plan `{id}` has invalid organs"),
            Self::InvalidByteLedger { plan_id, reason } => {
                write!(
                    f,
                    "TurboVec index plan `{plan_id}` invalid byte ledger: {reason}"
                )
            }
            Self::InvalidExternalIdPolicy(id) => {
                write!(
                    f,
                    "TurboVec index plan `{id}` has unsafe external-id policy"
                )
            }
            Self::InvalidPrivacyPolicy(id) => {
                write!(f, "TurboVec index plan `{id}` has unsafe privacy policy")
            }
            Self::InvalidRebuildPolicy(id) => {
                write!(f, "TurboVec index plan `{id}` has unsafe rebuild policy")
            }
            Self::RuntimeOrIndexNotDeferred(id) => {
                write!(f, "TurboVec index plan `{id}` tried to build or run")
            }
            Self::HiddenAuthority(id) => {
                write!(f, "TurboVec index plan `{id}` enabled hidden authority")
            }
            Self::ProductPromotionAllowed(id) => {
                write!(f, "TurboVec index plan `{id}` promoted product truth")
            }
            Self::SetPromotionAllowed => {
                write!(f, "TurboVec index plan set promoted product truth")
            }
        }
    }
}

impl std::error::Error for TurboVecIndexPlanError {}

fn validate_set_inputs(
    upstream_intake_address: &UasAddress,
    upstream_witness_ref: &str,
    plans: &[TurboVecEidosCompressedIndexPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), TurboVecIndexPlanError> {
    if upstream_intake_address.to_string().trim().is_empty() {
        return Err(TurboVecIndexPlanError::MissingUpstreamIntake);
    }
    if upstream_witness_ref.trim().is_empty() {
        return Err(TurboVecIndexPlanError::MissingUpstreamWitness);
    }
    if plans.is_empty() {
        return Err(TurboVecIndexPlanError::EmptyPlans);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(TurboVecIndexPlanError::MetadataBudgetExceeded {
            bytes: metadata_bytes,
            max_bytes: MAX_SET_METADATA_BYTES,
        });
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(TurboVecIndexPlanError::SetPromotionAllowed);
    }

    let mut ids = HashSet::new();
    for plan in plans {
        validate_plan(plan)?;
        if !ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecIndexPlanError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(plan: &TurboVecEidosCompressedIndexPlan) -> Result<(), TurboVecIndexPlanError> {
    require_nonempty(&plan.plan_id, &plan.plan_id, "plan_id")?;
    require_nonempty(
        &plan.upstream_turbovec_source_card_ref,
        &plan.plan_id,
        "upstream_turbovec_source_card_ref",
    )?;
    require_nonempty(&plan.source_locator, &plan.plan_id, "source_locator")?;
    require_nonempty(
        &plan.source_revision_ref,
        &plan.plan_id,
        "source_revision_ref",
    )?;
    require_nonempty(&plan.source_api_ref, &plan.plan_id, "source_api_ref")?;
    require_nonempty(&plan.license_ref, &plan.plan_id, "license_ref")?;
    require_prefix(
        &plan.upstream_turbovec_source_card_ref,
        &plan.plan_id,
        "upstream_turbovec_source_card_ref",
        SOURCE_CARD_PREFIX,
    )?;
    require_prefix(
        &plan.source_revision_ref,
        &plan.plan_id,
        "source_revision_ref",
        "revision:",
    )?;
    require_prefix(&plan.license_ref, &plan.plan_id, "license_ref", "license:")?;
    require_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if !plan
        .source_locator
        .starts_with("https://github.com/RyanCodrai/turbovec")
    {
        return Err(TurboVecIndexPlanError::BadSourceLocator(
            plan.plan_id.clone(),
        ));
    }
    if !plan
        .source_api_ref
        .starts_with("https://github.com/RyanCodrai/turbovec")
    {
        return Err(TurboVecIndexPlanError::BadSourceLocator(
            plan.plan_id.clone(),
        ));
    }
    if plan.product_build != ProductBuild::Pro {
        return Err(TurboVecIndexPlanError::BadProductBuild(
            plan.plan_id.clone(),
        ));
    }
    if plan.pro_status != ProStatus::ResearchCandidate {
        return Err(TurboVecIndexPlanError::BadProStatus(plan.plan_id.clone()));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecIndexPromotionTier::T0Research | TurboVecIndexPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecIndexPlanError::BadPromotionTier(
            plan.plan_id.clone(),
        ));
    }
    validate_organs(plan)?;
    validate_byte_ledger(plan)?;
    validate_external_id_policy(plan)?;
    validate_privacy_policy(plan)?;
    validate_rebuild_policy(plan)?;
    if !plan.l1_l2_l3_separated || !plan.runtime_deferred || !plan.index_build_deferred {
        return Err(TurboVecIndexPlanError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    if plan.eidos_score_can_select_route
        || plan.route_mutation_allowed
        || plan.hidden_route_authority_allowed
        || plan.hidden_cloud_fallback_allowed
    {
        return Err(TurboVecIndexPlanError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_recall_quality_claimed
        || plan.mas_readiness_claimed
        || plan.product_capability_claimed
        || plan.live_dense_70b_claimed
        || plan.ssd_as_ram_claimed
    {
        return Err(TurboVecIndexPlanError::ProductPromotionAllowed(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_organs(plan: &TurboVecEidosCompressedIndexPlan) -> Result<(), TurboVecIndexPlanError> {
    if plan.organs.is_empty() {
        return Err(TurboVecIndexPlanError::InvalidOrgans(plan.plan_id.clone()));
    }
    let organs = plan.organs.iter().collect::<BTreeSet<_>>();
    if !organs.contains(&TurboVecIndexOrgan::Eidos)
        || !organs.contains(&TurboVecIndexOrgan::AppColdStore)
        || organs.contains(&TurboVecIndexOrgan::AnswerPacket)
            && !organs.contains(&TurboVecIndexOrgan::SemanticWorkingSetPlan)
    {
        return Err(TurboVecIndexPlanError::InvalidOrgans(plan.plan_id.clone()));
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecEidosCompressedIndexPlan,
) -> Result<(), TurboVecIndexPlanError> {
    let ledger = &plan.byte_ledger;
    if ledger.dimension_count == 0
        || ledger.dimension_count > MAX_DIMENSION_COUNT
        || ledger.dimension_count % 8 != 0
    {
        return Err(TurboVecIndexPlanError::InvalidByteLedger {
            plan_id: plan.plan_id.clone(),
            reason: "dimension_count must be nonzero, bounded, and divisible by 8",
        });
    }
    let Some(expected_float32) = ledger.dimension_count.checked_mul(4) else {
        return Err(TurboVecIndexPlanError::InvalidByteLedger {
            plan_id: plan.plan_id.clone(),
            reason: "float32 byte math overflow",
        });
    };
    if ledger.float32_vector_bytes != expected_float32 {
        return Err(TurboVecIndexPlanError::InvalidByteLedger {
            plan_id: plan.plan_id.clone(),
            reason: "float32 vector byte math mismatch",
        });
    }
    if ledger.q4_coordinate_payload_bytes != ledger.dimension_count / 2
        || ledger.q2_coordinate_payload_bytes != ledger.dimension_count / 4
    {
        return Err(TurboVecIndexPlanError::InvalidByteLedger {
            plan_id: plan.plan_id.clone(),
            reason: "q4/q2 coordinate byte math mismatch",
        });
    }
    if ledger.metadata_bytes_read > MAX_LEDGER_METADATA_BYTES {
        return Err(TurboVecIndexPlanError::MetadataBudgetExceeded {
            bytes: ledger.metadata_bytes_read,
            max_bytes: MAX_LEDGER_METADATA_BYTES,
        });
    }
    if ledger.index_bytes_loaded != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.model_bytes_loaded != 0
        || ledger.provider_calls_made != 0
        || ledger.copied_product_file_count != 0
    {
        return Err(TurboVecIndexPlanError::RuntimeOrIndexNotDeferred(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_external_id_policy(
    plan: &TurboVecEidosCompressedIndexPlan,
) -> Result<(), TurboVecIndexPlanError> {
    let policy = &plan.external_id_policy;
    if !policy.uas_address_is_truth
        || policy.sqlite_rowid_allowed
        || !policy.stable_u64_registry_required
        || !policy.tombstone_or_generation_required
        || !policy.collision_ledger_required
        || !policy.external_id_rewrite_requires_rebuild
    {
        return Err(TurboVecIndexPlanError::InvalidExternalIdPolicy(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_privacy_policy(
    plan: &TurboVecEidosCompressedIndexPlan,
) -> Result<(), TurboVecIndexPlanError> {
    let policy = &plan.privacy_policy;
    if !policy.allowlist_before_rank_required
        || policy.post_filtering_allowed
        || !policy.empty_allowlist_answer_packet_required
        || !policy.unknown_allowlist_id_rejected
        || policy.forbidden_id_scoring_allowed
        || policy.private_vector_payload_scoring_allowed
    {
        return Err(TurboVecIndexPlanError::InvalidPrivacyPolicy(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_rebuild_policy(
    plan: &TurboVecEidosCompressedIndexPlan,
) -> Result<(), TurboVecIndexPlanError> {
    let policy = &plan.rebuild_policy;
    if !policy.app_cold_store_is_truth
        || !policy.compressed_index_is_cache
        || !policy.exact_source_check_required
        || !policy.corrupt_cache_rebuild_required
        || !policy.atomic_manifest_required
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
    {
        return Err(TurboVecIndexPlanError::InvalidRebuildPolicy(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn require_proof_refs(
    plan_id: &str,
    refs: &TurboVecIndexProofRefs,
) -> Result<(), TurboVecIndexPlanError> {
    for (field, value, prefix) in [
        (
            "falsifier_ref",
            refs.falsifier_ref.as_str(),
            FALSIFIER_PREFIX,
        ),
        ("rollback_ref", refs.rollback_ref.as_str(), ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            refs.compatibility_fence_ref.as_str(),
            COMPATIBILITY_FENCE_PREFIX,
        ),
    ] {
        require_prefix(value, plan_id, field, prefix)?;
    }
    Ok(())
}

fn require_nonempty(
    value: &str,
    plan_id: &str,
    field: &'static str,
) -> Result<(), TurboVecIndexPlanError> {
    if value.trim().is_empty()
        || value.trim() != value
        || value.chars().any(char::is_control)
        || value.to_ascii_lowercase().contains("rowid")
    {
        return Err(TurboVecIndexPlanError::MissingField {
            plan_id: plan_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    plan_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), TurboVecIndexPlanError> {
    require_nonempty(value, plan_id, field)?;
    if !value.starts_with(expected) {
        return Err(TurboVecIndexPlanError::BadPrefix {
            plan_id: plan_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn plan_set_preimage(
    upstream_intake_address: &UasAddress,
    upstream_witness_ref: &str,
    plans: &[TurboVecEidosCompressedIndexPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_CURSOR);
    preimage.push('\n');
    preimage.push_str(&upstream_intake_address.to_string());
    preimage.push('\n');
    preimage.push_str(upstream_witness_ref);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{product_build:?}|{pro_status:?}|{metadata_bytes}|{l1_l2_l3_separated}|{runtime_deferred}|{product_promotion_blocked}\n"
    ));
    for plan in plans {
        push_plan_preimage(&mut preimage, plan);
    }
    preimage
}

fn push_plan_preimage(preimage: &mut String, plan: &TurboVecEidosCompressedIndexPlan) {
    for field in [
        plan.plan_id.as_str(),
        plan.upstream_turbovec_source_card_ref.as_str(),
        plan.source_locator.as_str(),
        plan.source_revision_ref.as_str(),
        plan.source_api_ref.as_str(),
        plan.license_ref.as_str(),
        plan.proof_refs.falsifier_ref.as_str(),
        plan.proof_refs.rollback_ref.as_str(),
        plan.proof_refs.run_event_log_ref.as_str(),
        plan.proof_refs.answer_packet_ref.as_str(),
        plan.proof_refs.compatibility_fence_ref.as_str(),
    ] {
        preimage.push_str(field);
        preimage.push('\n');
    }
    for organ in &plan.organs {
        preimage.push_str(&format!("{organ:?}|"));
    }
    preimage.push('\n');
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
        plan.plan_status,
        plan.product_build,
        plan.pro_status,
        plan.promotion_tier,
        plan.byte_ledger.dimension_count,
        plan.byte_ledger.float32_vector_bytes,
        plan.byte_ledger.q4_coordinate_payload_bytes,
        plan.byte_ledger.q2_coordinate_payload_bytes,
        plan.byte_ledger.side_table_budget_bytes,
        plan.byte_ledger.metadata_bytes_read,
        plan.byte_ledger.manifest_bytes_read,
        plan.byte_ledger.index_bytes_loaded,
        plan.byte_ledger.runtime_bytes_loaded,
        plan.byte_ledger.model_bytes_loaded,
        plan.byte_ledger.provider_calls_made,
        plan.byte_ledger.copied_product_file_count,
        plan.external_id_policy.uas_address_is_truth,
        plan.external_id_policy.sqlite_rowid_allowed,
        plan.external_id_policy.stable_u64_registry_required,
        plan.external_id_policy.tombstone_or_generation_required,
        plan.external_id_policy.collision_ledger_required,
        plan.external_id_policy.external_id_rewrite_requires_rebuild,
        plan.privacy_policy.allowlist_before_rank_required,
        plan.privacy_policy.post_filtering_allowed,
        plan.rebuild_policy.app_cold_store_is_truth,
        plan.rebuild_policy.compressed_index_is_cache,
        plan.l1_l2_l3_separated,
    ));
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_038_600_000;

    #[test]
    fn accepts_metadata_only_plan_with_deterministic_address_and_byte_math() {
        let set = valid_set();
        let reversed = match TurboVecEidosCompressedIndexPlanSet::from_source_cards(
            upstream_address(),
            "artifact:compressed_model_source_card_intake:result",
            set.plans.iter().cloned().rev().collect(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            42_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        ) {
            Ok(value) => value,
            Err(error) => panic!("{error}"),
        };

        assert_eq!(set.set_address, reversed.set_address);
        let metrics = set.metrics();
        assert_eq!(metrics.plan_count, 1);
        assert_eq!(metrics.dimension_count, 1_536);
        assert_eq!(metrics.float32_vector_bytes, 6_144);
        assert_eq!(metrics.q4_coordinate_payload_bytes, 768);
        assert_eq!(metrics.q2_coordinate_payload_bytes, 384);
        assert_eq!(metrics.index_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_rowid_post_filtering_and_hidden_authority() {
        let err = mutate_plan(|plan| {
            plan.external_id_policy.sqlite_rowid_allowed = true;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::InvalidExternalIdPolicy(_)
        ));

        let err = mutate_plan(|plan| {
            plan.privacy_policy.post_filtering_allowed = true;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::InvalidPrivacyPolicy(_)
        ));

        let err = mutate_plan(|plan| {
            plan.eidos_score_can_select_route = true;
        });
        assert!(matches!(err, TurboVecIndexPlanError::HiddenAuthority(_)));
    }

    #[test]
    fn rejects_byte_math_regressions() {
        let err = mutate_plan(|plan| {
            plan.byte_ledger.q4_coordinate_payload_bytes = 384;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::InvalidByteLedger { .. }
        ));

        let err = mutate_plan(|plan| {
            plan.byte_ledger.dimension_count = 1_537;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::InvalidByteLedger { .. }
        ));
    }

    #[test]
    fn rejects_runtime_index_bytes_and_product_promotion() {
        let err = mutate_plan(|plan| {
            plan.byte_ledger.index_bytes_loaded = 1;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::RuntimeOrIndexNotDeferred(_)
        ));

        let err = mutate_plan(|plan| {
            plan.promotion_tier = TurboVecIndexPromotionTier::T4BuildGreen;
        });
        assert!(matches!(err, TurboVecIndexPlanError::BadPromotionTier(_)));

        let err = mutate_plan(|plan| {
            plan.product_capability_claimed = true;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::ProductPromotionAllowed(_)
        ));
    }

    #[test]
    fn rejects_missing_rebuild_proof_and_allowlist_contracts() {
        let err = mutate_plan(|plan| {
            plan.rebuild_policy.answer_packet_required = false;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::InvalidRebuildPolicy(_)
        ));

        let err = mutate_plan(|plan| {
            plan.privacy_policy.allowlist_before_rank_required = false;
        });
        assert!(matches!(
            err,
            TurboVecIndexPlanError::InvalidPrivacyPolicy(_)
        ));

        let err = mutate_plan(|plan| {
            plan.proof_refs.answer_packet_ref = "packet:bad".to_string();
        });
        assert!(matches!(err, TurboVecIndexPlanError::BadPrefix { .. }));
    }

    fn valid_set() -> TurboVecEidosCompressedIndexPlanSet {
        match TurboVecEidosCompressedIndexPlanSet::from_source_cards(
            upstream_address(),
            "artifact:compressed_model_source_card_intake:result",
            vec![valid_plan()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            42_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        ) {
            Ok(value) => value,
            Err(error) => panic!("{error}"),
        }
    }

    fn mutate_plan(
        mutate: impl FnOnce(&mut TurboVecEidosCompressedIndexPlan),
    ) -> TurboVecIndexPlanError {
        let mut plan = valid_plan();
        mutate(&mut plan);
        match TurboVecEidosCompressedIndexPlanSet::from_source_cards(
            upstream_address(),
            "artifact:compressed_model_source_card_intake:result",
            vec![plan],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            42_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        ) {
            Ok(_) => panic!("mutated plan should fail"),
            Err(error) => error,
        }
    }

    fn valid_plan() -> TurboVecEidosCompressedIndexPlan {
        TurboVecEidosCompressedIndexPlan {
            plan_id: "turbovec_eidos_cache_plan".to_string(),
            upstream_turbovec_source_card_ref: "compressed_model_source_card:turbovec_eidos_cache"
                .to_string(),
            source_locator: "https://github.com/RyanCodrai/turbovec".to_string(),
            source_revision_ref: "revision:main".to_string(),
            source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md"
                .to_string(),
            license_ref: "license:quarantine_adapter_or_clean_room".to_string(),
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            plan_status: TurboVecIndexPlanStatus::MetadataOnlyPlan,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: TurboVecIndexPromotionTier::T1L1Metadata,
            byte_ledger: match TurboVecIndexByteLedger::metadata_only(1_536, 32_768, 18_000, 4_096)
            {
                Ok(value) => value,
                Err(error) => panic!("{error}"),
            },
            external_id_policy: TurboVecExternalIdPolicy::uas_truth(),
            privacy_policy: TurboVecAllowlistPrivacyPolicy::filter_before_rank(),
            rebuild_policy: TurboVecRebuildPolicy::rebuildable_cache(),
            proof_refs: TurboVecIndexProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-Eidos-CompressedIndex-Plan".to_string(),
                rollback_ref: "rollback:turbovec_eidos_cache_plan".to_string(),
                run_event_log_ref: "run_event_log:turbovec_eidos_cache_plan".to_string(),
                answer_packet_ref: "answer_packet:turbovec_eidos_cache_plan".to_string(),
                compatibility_fence_ref: "compat:turbovec_eidos_cache_plan".to_string(),
            },
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            index_build_deferred: true,
            eidos_score_can_select_route: false,
            route_mutation_allowed: false,
            hidden_route_authority_allowed: false,
            live_recall_quality_claimed: false,
            mas_readiness_claimed: false,
            product_capability_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
        }
    }

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("compressed_model_source_card_intake".to_string()),
            b"test-upstream-intake",
            1_779_034_000_000,
        )
    }
}
