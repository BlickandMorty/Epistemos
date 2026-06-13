//! TurboVec UAS-address stable external ID registry plan.
//!
//! This primitive hardens the next compressed-retrieval step before any
//! TurboVec index bytes exist. It proves that Eidos/AppColdStore compressed
//! cache adapters must map UAS addresses to stable `u64` external IDs with a
//! tombstone/generation ledger and collision ledger, instead of using SQLite
//! row IDs, insert order, or mutable vector slots as evidence identity.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashSet};
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind,
    TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_NEXT_CURSOR,
};

pub const TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_CURSOR: &str =
    "turbovec_stable_external_id_registry_plan";
pub const TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_NEXT_CURSOR: &str =
    "turbovec_filter_before_rank_privacy_gate_plan";

const APP_COLD_STORE_PREFIX: &str = "app_cold_store:";
const SOURCE_CARD_PREFIX: &str = "compressed_model_source_card:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_MANIFEST_BYTES: u64 = 128 * 1024;

// UAS: uas:turbovec-stable-id:status
// Plane: Verification
// Residency: registry planning status only; no index bytes are loaded here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecStableExternalIdRegistryStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-stable-id:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecStableExternalIdPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-stable-id:source
// Plane: State + Verification
// Residency: identity derivation source for TurboVec external IDs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecStableExternalIdSource {
    UasAddressDeterministicHash,
    SqliteRowid,
    InsertOrder,
    MutableVectorSlot,
}

// UAS: uas:turbovec-stable-id:lifecycle
// Plane: State + Verification
// Residency: tombstone/generation state for source identities.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecStableExternalIdLifecycle {
    Active,
    Tombstoned,
    ReinsertedNewGeneration,
}

// UAS: uas:turbovec-stable-id:collision-resolution
// Plane: Verification
// Residency: collision handling for deterministic external IDs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecStableExternalIdCollisionResolution {
    RejectAliasAndAllocateDeterministicId,
    ReuseAlias,
    TrustRowid,
}

// UAS: uas:turbovec-stable-id:entry
// Plane: State + Verification
// Residency: stable adapter identity, not durable source truth.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdEntry {
    pub entry_id: String,
    pub logical_source_key: String,
    pub uas_address: UasAddress,
    pub external_id: u64,
    pub generation: u64,
    pub lifecycle: TurboVecStableExternalIdLifecycle,
    pub external_id_source: TurboVecStableExternalIdSource,
    pub app_cold_store_ref: String,
    pub source_card_ref: String,
    pub sqlite_rowid_used: bool,
    pub insert_order_used: bool,
    pub mutable_vector_slot_used: bool,
}

// UAS: uas:turbovec-stable-id:collision-ledger
// Plane: Verification
// Residency: explicit alias rejection before compressed retrieval can cite IDs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdCollisionLedgerEntry {
    pub collision_id: String,
    pub left_uas_address: UasAddress,
    pub right_uas_address: UasAddress,
    pub candidate_external_id: u64,
    pub resolved_external_id: u64,
    pub resolution: TurboVecStableExternalIdCollisionResolution,
    pub alias_rejected: bool,
    pub registry_rebuild_required: bool,
}

// UAS: uas:turbovec-stable-id:policy
// Plane: Controller + Verification
// Residency: fail-closed manifest policy before compressed index bytes exist.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdRegistryPolicy {
    pub app_cold_store_is_truth: bool,
    pub registry_is_cache_manifest: bool,
    pub sqlite_rowid_forbidden: bool,
    pub insert_order_forbidden: bool,
    pub mutable_slot_forbidden: bool,
    pub stable_uas_hash_required: bool,
    pub tombstone_retention_required: bool,
    pub generation_counter_required: bool,
    pub collision_ledger_required: bool,
    pub allowlist_ids_compile_from_uas: bool,
    pub export_import_roundtrip_required: bool,
    pub atomic_manifest_required: bool,
    pub corrupt_manifest_rebuild_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
}

impl TurboVecStableExternalIdRegistryPolicy {
    pub fn fail_closed_cache_manifest() -> Self {
        Self {
            app_cold_store_is_truth: true,
            registry_is_cache_manifest: true,
            sqlite_rowid_forbidden: true,
            insert_order_forbidden: true,
            mutable_slot_forbidden: true,
            stable_uas_hash_required: true,
            tombstone_retention_required: true,
            generation_counter_required: true,
            collision_ledger_required: true,
            allowlist_ids_compile_from_uas: true,
            export_import_roundtrip_required: true,
            atomic_manifest_required: true,
            corrupt_manifest_rebuild_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
        }
    }
}

// UAS: uas:turbovec-stable-id:byte-ledger
// Plane: Verification
// Residency: metadata-only registry proof boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdByteLedger {
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub registry_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecStableExternalIdByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        manifest_bytes_read: u64,
    ) -> Result<Self, TurboVecStableExternalIdRegistryError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || manifest_bytes_read > MAX_MANIFEST_BYTES {
            return Err(
                TurboVecStableExternalIdRegistryError::MetadataBudgetExceeded {
                    metadata_bytes_read,
                    manifest_bytes_read,
                },
            );
        }
        Ok(Self {
            metadata_bytes_read,
            manifest_bytes_read,
            registry_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        })
    }
}

// UAS: uas:turbovec-stable-id:proof-refs
// Plane: Verification
// Residency: visible proof handles required before any live compressed cache.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-stable-id:registry-plan
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only plan for a stable external-ID adapter.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdRegistryPlan {
    pub plan_id: String,
    pub upstream_plan_address: UasAddress,
    pub upstream_plan_witness_ref: String,
    pub source_api_ref: String,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub entries: Vec<TurboVecStableExternalIdEntry>,
    pub collision_ledger: Vec<TurboVecStableExternalIdCollisionLedgerEntry>,
    pub policy: TurboVecStableExternalIdRegistryPolicy,
    pub byte_ledger: TurboVecStableExternalIdByteLedger,
    pub proof_refs: TurboVecStableExternalIdProofRefs,
    pub registry_status: TurboVecStableExternalIdRegistryStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: TurboVecStableExternalIdPromotionTier,
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

// UAS: uas:turbovec-stable-id:registry-set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only registry pack for later byte/runtime witnesses.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdRegistryPlanSet {
    pub set_address: UasAddress,
    pub upstream_index_plan_address: UasAddress,
    pub upstream_index_plan_witness_ref: String,
    pub plans: Vec<TurboVecStableExternalIdRegistryPlan>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub registry_status: TurboVecStableExternalIdRegistryStatus,
    pub promotion_tier: TurboVecStableExternalIdPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:turbovec-stable-id:metrics
// Plane: Verification
// Residency: counters for the metadata-only registry witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecStableExternalIdRegistryMetrics {
    pub plan_count: u64,
    pub active_entry_count: u64,
    pub tombstoned_entry_count: u64,
    pub reinserted_entry_count: u64,
    pub collision_ledger_count: u64,
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub registry_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecStableExternalIdRegistryPlanSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_plans(
        upstream_index_plan_address: UasAddress,
        upstream_index_plan_witness_ref: impl Into<String>,
        mut plans: Vec<TurboVecStableExternalIdRegistryPlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        registry_status: TurboVecStableExternalIdRegistryStatus,
        promotion_tier: TurboVecStableExternalIdPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, TurboVecStableExternalIdRegistryError> {
        plans.sort_by(|a, b| a.plan_id.cmp(&b.plan_id));
        let witness_ref = upstream_index_plan_witness_ref.into();
        validate_set_inputs(
            &upstream_index_plan_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            &registry_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = set_preimage(
            &upstream_index_plan_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            &registry_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_index_plan_address,
            upstream_index_plan_witness_ref: witness_ref,
            plans,
            product_build,
            pro_status,
            registry_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> TurboVecStableExternalIdRegistryMetrics {
        let mut metrics = TurboVecStableExternalIdRegistryMetrics {
            plan_count: self.plans.len() as u64,
            active_entry_count: 0,
            tombstoned_entry_count: 0,
            reinserted_entry_count: 0,
            collision_ledger_count: 0,
            metadata_bytes_read: self.metadata_bytes,
            manifest_bytes_read: 0,
            registry_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        };

        for plan in &self.plans {
            metrics.collision_ledger_count += plan.collision_ledger.len() as u64;
            metrics.metadata_bytes_read += plan.byte_ledger.metadata_bytes_read;
            metrics.manifest_bytes_read += plan.byte_ledger.manifest_bytes_read;
            metrics.registry_bytes_loaded += plan.byte_ledger.registry_bytes_loaded;
            metrics.index_bytes_loaded += plan.byte_ledger.index_bytes_loaded;
            metrics.runtime_bytes_loaded += plan.byte_ledger.runtime_bytes_loaded;
            metrics.model_bytes_loaded += plan.byte_ledger.model_bytes_loaded;
            metrics.provider_calls_made += plan.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += plan.byte_ledger.copied_product_file_count;

            for entry in &plan.entries {
                match entry.lifecycle {
                    TurboVecStableExternalIdLifecycle::Active => metrics.active_entry_count += 1,
                    TurboVecStableExternalIdLifecycle::Tombstoned => {
                        metrics.tombstoned_entry_count += 1
                    }
                    TurboVecStableExternalIdLifecycle::ReinsertedNewGeneration => {
                        metrics.reinserted_entry_count += 1
                    }
                }
            }
        }
        metrics
    }
}

// UAS: uas:turbovec-stable-id:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy for registry planning.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecStableExternalIdRegistryError {
    MissingUpstreamIndexPlan,
    MissingUpstreamWitness,
    EmptyPlans,
    EmptyEntries(String),
    DuplicatePlanId(String),
    DuplicateEntryId(String),
    DuplicateUasAddress(String),
    DuplicateActiveExternalId(u64),
    DuplicateLogicalGeneration(String),
    MissingField {
        plan_id: String,
        field: &'static str,
    },
    BadPrefix {
        plan_id: String,
        field: &'static str,
        expected: &'static str,
    },
    BadUpstreamCursor,
    BadProductBuild(String),
    BadProStatus(String),
    BadRegistryStatus(String),
    BadPromotionTier(String),
    InvalidOrgans(String),
    InvalidExternalId {
        entry_id: String,
        reason: &'static str,
    },
    InvalidTombstoneGeneration(String),
    InvalidCollisionLedger(String),
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

impl fmt::Display for TurboVecStableExternalIdRegistryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamIndexPlan => write!(f, "missing upstream TurboVec index plan"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream index plan witness"),
            Self::EmptyPlans => write!(f, "TurboVec stable-ID registry plan set is empty"),
            Self::EmptyEntries(id) => write!(f, "TurboVec stable-ID plan `{id}` has no entries"),
            Self::DuplicatePlanId(id) => write!(f, "duplicate TurboVec stable-ID plan `{id}`"),
            Self::DuplicateEntryId(id) => write!(f, "duplicate stable-ID entry `{id}`"),
            Self::DuplicateUasAddress(id) => write!(f, "duplicate UAS address `{id}`"),
            Self::DuplicateActiveExternalId(id) => {
                write!(f, "duplicate active external ID `{id}`")
            }
            Self::DuplicateLogicalGeneration(key) => {
                write!(f, "duplicate logical source generation `{key}`")
            }
            Self::MissingField { plan_id, field } => {
                write!(f, "TurboVec stable-ID plan `{plan_id}` missing `{field}`")
            }
            Self::BadPrefix {
                plan_id,
                field,
                expected,
            } => write!(
                f,
                "TurboVec stable-ID plan `{plan_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadUpstreamCursor => write!(
                f,
                "upstream TurboVec index plan did not point at stable-ID registry cursor"
            ),
            Self::BadProductBuild(id) => write!(f, "TurboVec stable-ID plan `{id}` leaked to MAS"),
            Self::BadProStatus(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` has forbidden Pro status")
            }
            Self::BadRegistryStatus(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` has forbidden status")
            }
            Self::BadPromotionTier(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` promoted beyond T1")
            }
            Self::InvalidOrgans(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` has invalid organs")
            }
            Self::InvalidExternalId { entry_id, reason } => {
                write!(f, "TurboVec stable-ID entry `{entry_id}` invalid: {reason}")
            }
            Self::InvalidTombstoneGeneration(id) => {
                write!(
                    f,
                    "TurboVec stable-ID plan `{id}` has unsafe tombstone/generation state"
                )
            }
            Self::InvalidCollisionLedger(id) => {
                write!(
                    f,
                    "TurboVec stable-ID plan `{id}` has unsafe collision ledger"
                )
            }
            Self::InvalidPolicy(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` has unsafe policy")
            }
            Self::InvalidProofRefs(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` has unsafe proof refs")
            }
            Self::MetadataBudgetExceeded {
                metadata_bytes_read,
                manifest_bytes_read,
            } => write!(
                f,
                "TurboVec stable-ID metadata budget exceeded: metadata={metadata_bytes_read}, manifest={manifest_bytes_read}"
            ),
            Self::RuntimeOrIndexNotDeferred(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` tried to build or run")
            }
            Self::HiddenAuthority(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` enabled hidden authority")
            }
            Self::ProductPromotionAllowed(id) => {
                write!(f, "TurboVec stable-ID plan `{id}` promoted product truth")
            }
            Self::SetPromotionAllowed => write!(f, "TurboVec stable-ID set promoted product truth"),
        }
    }
}

impl std::error::Error for TurboVecStableExternalIdRegistryError {}

pub fn stable_external_id_for_uas(address: &UasAddress) -> u64 {
    let bytes = address.hash.as_bytes();
    let mut first_eight = [0_u8; 8];
    first_eight.copy_from_slice(&bytes[..8]);
    let id = u64::from_le_bytes(first_eight);
    if id == 0 {
        1
    } else {
        id
    }
}

fn validate_set_inputs(
    upstream_index_plan_address: &UasAddress,
    upstream_witness_ref: &str,
    plans: &[TurboVecStableExternalIdRegistryPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    registry_status: &TurboVecStableExternalIdRegistryStatus,
    promotion_tier: &TurboVecStableExternalIdPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    if upstream_index_plan_address.to_string().trim().is_empty() {
        return Err(TurboVecStableExternalIdRegistryError::MissingUpstreamIndexPlan);
    }
    if upstream_witness_ref.trim().is_empty() {
        return Err(TurboVecStableExternalIdRegistryError::MissingUpstreamWitness);
    }
    if !matches!(
        upstream_index_plan_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_eidos_compressed_index_plan"
    ) {
        return Err(TurboVecStableExternalIdRegistryError::BadUpstreamCursor);
    }
    if plans.is_empty() {
        return Err(TurboVecStableExternalIdRegistryError::EmptyPlans);
    }
    if metadata_bytes > MAX_METADATA_BYTES {
        return Err(
            TurboVecStableExternalIdRegistryError::MetadataBudgetExceeded {
                metadata_bytes_read: metadata_bytes,
                manifest_bytes_read: 0,
            },
        );
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || registry_status != &TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan
        || !matches!(
            promotion_tier,
            TurboVecStableExternalIdPromotionTier::T0Research
                | TurboVecStableExternalIdPromotionTier::T1L1Metadata
        )
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(TurboVecStableExternalIdRegistryError::SetPromotionAllowed);
    }

    let mut plan_ids = HashSet::new();
    for plan in plans {
        if plan.upstream_plan_address != *upstream_index_plan_address {
            return Err(TurboVecStableExternalIdRegistryError::MissingUpstreamIndexPlan);
        }
        validate_plan(plan)?;
        if !plan_ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecStableExternalIdRegistryError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(
    plan: &TurboVecStableExternalIdRegistryPlan,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    require_nonempty(&plan.plan_id, &plan.plan_id, "plan_id")?;
    require_nonempty(
        &plan.upstream_plan_witness_ref,
        &plan.plan_id,
        "upstream_plan_witness_ref",
    )?;
    require_nonempty(&plan.source_api_ref, &plan.plan_id, "source_api_ref")?;
    require_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if plan.upstream_plan_witness_ref != "artifact:turbovec_eidos_compressed_index_plan:result" {
        return Err(TurboVecStableExternalIdRegistryError::MissingUpstreamWitness);
    }
    if !plan
        .source_api_ref
        .starts_with("https://github.com/RyanCodrai/turbovec")
    {
        return Err(TurboVecStableExternalIdRegistryError::BadPrefix {
            plan_id: plan.plan_id.clone(),
            field: "source_api_ref",
            expected: "https://github.com/RyanCodrai/turbovec",
        });
    }
    if plan.product_build != ProductBuild::Pro {
        return Err(TurboVecStableExternalIdRegistryError::BadProductBuild(
            plan.plan_id.clone(),
        ));
    }
    if plan.pro_status != ProStatus::ResearchCandidate {
        return Err(TurboVecStableExternalIdRegistryError::BadProStatus(
            plan.plan_id.clone(),
        ));
    }
    if plan.registry_status != TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan {
        return Err(TurboVecStableExternalIdRegistryError::BadRegistryStatus(
            plan.plan_id.clone(),
        ));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecStableExternalIdPromotionTier::T0Research
            | TurboVecStableExternalIdPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecStableExternalIdRegistryError::BadPromotionTier(
            plan.plan_id.clone(),
        ));
    }
    validate_organs(plan)?;
    validate_policy(plan)?;
    validate_entries(plan)?;
    validate_collision_ledger(plan)?;
    validate_byte_ledger(plan)?;
    if !plan.l1_l2_l3_separated
        || !plan.runtime_deferred
        || !plan.index_build_deferred
        || !plan.product_promotion_blocked
    {
        return Err(
            TurboVecStableExternalIdRegistryError::RuntimeOrIndexNotDeferred(plan.plan_id.clone()),
        );
    }
    if plan.hidden_route_authority_allowed
        || plan.route_mutation_allowed
        || plan.hidden_cloud_fallback_allowed
    {
        return Err(TurboVecStableExternalIdRegistryError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_recall_quality_claimed || plan.live_dense_70b_claimed || plan.ssd_as_ram_claimed {
        return Err(
            TurboVecStableExternalIdRegistryError::ProductPromotionAllowed(plan.plan_id.clone()),
        );
    }
    Ok(())
}

fn validate_organs(
    plan: &TurboVecStableExternalIdRegistryPlan,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    let organs = plan.organs.iter().collect::<HashSet<_>>();
    if !organs.contains(&TurboVecIndexOrgan::Eidos)
        || !organs.contains(&TurboVecIndexOrgan::AppColdStore)
        || !organs.contains(&TurboVecIndexOrgan::AnswerPacket)
    {
        return Err(TurboVecStableExternalIdRegistryError::InvalidOrgans(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_policy(
    plan: &TurboVecStableExternalIdRegistryPlan,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    let policy = &plan.policy;
    if !policy.app_cold_store_is_truth
        || !policy.registry_is_cache_manifest
        || !policy.sqlite_rowid_forbidden
        || !policy.insert_order_forbidden
        || !policy.mutable_slot_forbidden
        || !policy.stable_uas_hash_required
        || !policy.tombstone_retention_required
        || !policy.generation_counter_required
        || !policy.collision_ledger_required
        || !policy.allowlist_ids_compile_from_uas
        || !policy.export_import_roundtrip_required
        || !policy.atomic_manifest_required
        || !policy.corrupt_manifest_rebuild_required
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.compatibility_fence_required
    {
        return Err(TurboVecStableExternalIdRegistryError::InvalidPolicy(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_entries(
    plan: &TurboVecStableExternalIdRegistryPlan,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    if plan.entries.is_empty() {
        return Err(TurboVecStableExternalIdRegistryError::EmptyEntries(
            plan.plan_id.clone(),
        ));
    }

    let mut entry_ids = HashSet::new();
    let mut uas_addresses = HashSet::new();
    let mut active_external_ids = HashSet::new();
    let mut logical_generations = HashSet::new();
    let mut logical_generation_max = BTreeMap::<String, u64>::new();
    let mut tombstone_count = 0_u64;
    let mut reinsert_count = 0_u64;

    for entry in &plan.entries {
        validate_entry(plan, entry)?;
        if !entry_ids.insert(entry.entry_id.clone()) {
            return Err(TurboVecStableExternalIdRegistryError::DuplicateEntryId(
                entry.entry_id.clone(),
            ));
        }
        let address_string = entry.uas_address.to_string();
        if !uas_addresses.insert(address_string.clone()) {
            return Err(TurboVecStableExternalIdRegistryError::DuplicateUasAddress(
                address_string,
            ));
        }
        if !matches!(
            entry.lifecycle,
            TurboVecStableExternalIdLifecycle::Tombstoned
        ) && !active_external_ids.insert(entry.external_id)
        {
            return Err(
                TurboVecStableExternalIdRegistryError::DuplicateActiveExternalId(entry.external_id),
            );
        }
        let logical_generation = format!("{}:{}", entry.logical_source_key, entry.generation);
        if !logical_generations.insert(logical_generation.clone()) {
            return Err(
                TurboVecStableExternalIdRegistryError::DuplicateLogicalGeneration(
                    logical_generation,
                ),
            );
        }
        let max_generation = logical_generation_max
            .entry(entry.logical_source_key.clone())
            .or_insert(0);
        if entry.generation > *max_generation {
            *max_generation = entry.generation;
        }
        match entry.lifecycle {
            TurboVecStableExternalIdLifecycle::Tombstoned => tombstone_count += 1,
            TurboVecStableExternalIdLifecycle::ReinsertedNewGeneration => reinsert_count += 1,
            TurboVecStableExternalIdLifecycle::Active => {}
        }
    }

    if tombstone_count == 0 || reinsert_count == 0 {
        return Err(
            TurboVecStableExternalIdRegistryError::InvalidTombstoneGeneration(plan.plan_id.clone()),
        );
    }
    for entry in &plan.entries {
        if matches!(
            entry.lifecycle,
            TurboVecStableExternalIdLifecycle::ReinsertedNewGeneration
        ) && entry.generation <= 1
        {
            return Err(
                TurboVecStableExternalIdRegistryError::InvalidTombstoneGeneration(
                    entry.entry_id.clone(),
                ),
            );
        }
    }
    Ok(())
}

fn validate_entry(
    plan: &TurboVecStableExternalIdRegistryPlan,
    entry: &TurboVecStableExternalIdEntry,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    require_nonempty(&entry.entry_id, &plan.plan_id, "entry_id")?;
    require_nonempty(
        &entry.logical_source_key,
        &plan.plan_id,
        "logical_source_key",
    )?;
    require_prefix(
        &entry.app_cold_store_ref,
        &plan.plan_id,
        "app_cold_store_ref",
        APP_COLD_STORE_PREFIX,
    )?;
    require_prefix(
        &entry.source_card_ref,
        &plan.plan_id,
        "source_card_ref",
        SOURCE_CARD_PREFIX,
    )?;
    if entry.external_id == 0 {
        return Err(TurboVecStableExternalIdRegistryError::InvalidExternalId {
            entry_id: entry.entry_id.clone(),
            reason: "external_id 0 is reserved",
        });
    }
    if entry.external_id != stable_external_id_for_uas(&entry.uas_address) {
        return Err(TurboVecStableExternalIdRegistryError::InvalidExternalId {
            entry_id: entry.entry_id.clone(),
            reason: "external_id must derive from UAS address, not registry row",
        });
    }
    if entry.external_id_source != TurboVecStableExternalIdSource::UasAddressDeterministicHash
        || entry.sqlite_rowid_used
        || entry.insert_order_used
        || entry.mutable_vector_slot_used
    {
        return Err(TurboVecStableExternalIdRegistryError::InvalidExternalId {
            entry_id: entry.entry_id.clone(),
            reason: "forbidden identity source",
        });
    }
    if entry.generation == 0 {
        return Err(
            TurboVecStableExternalIdRegistryError::InvalidTombstoneGeneration(
                entry.entry_id.clone(),
            ),
        );
    }
    Ok(())
}

fn validate_collision_ledger(
    plan: &TurboVecStableExternalIdRegistryPlan,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    if plan.collision_ledger.is_empty() {
        return Err(
            TurboVecStableExternalIdRegistryError::InvalidCollisionLedger(plan.plan_id.clone()),
        );
    }
    let mut ids = HashSet::new();
    for row in &plan.collision_ledger {
        require_nonempty(&row.collision_id, &plan.plan_id, "collision_id")?;
        if !ids.insert(row.collision_id.clone()) {
            return Err(
                TurboVecStableExternalIdRegistryError::InvalidCollisionLedger(
                    row.collision_id.clone(),
                ),
            );
        }
        if row.left_uas_address == row.right_uas_address
            || row.candidate_external_id == 0
            || row.resolved_external_id == 0
            || row.candidate_external_id == row.resolved_external_id
            || row.resolved_external_id != stable_external_id_for_uas(&row.right_uas_address)
            || row.resolution
                != TurboVecStableExternalIdCollisionResolution::RejectAliasAndAllocateDeterministicId
            || !row.alias_rejected
            || !row.registry_rebuild_required
        {
            return Err(TurboVecStableExternalIdRegistryError::InvalidCollisionLedger(
                row.collision_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecStableExternalIdRegistryPlan,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    let ledger = &plan.byte_ledger;
    if ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || ledger.manifest_bytes_read > MAX_MANIFEST_BYTES
    {
        return Err(
            TurboVecStableExternalIdRegistryError::MetadataBudgetExceeded {
                metadata_bytes_read: ledger.metadata_bytes_read,
                manifest_bytes_read: ledger.manifest_bytes_read,
            },
        );
    }
    if ledger.registry_bytes_loaded != 0
        || ledger.index_bytes_loaded != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.model_bytes_loaded != 0
        || ledger.provider_calls_made != 0
        || ledger.copied_product_file_count != 0
    {
        return Err(
            TurboVecStableExternalIdRegistryError::RuntimeOrIndexNotDeferred(plan.plan_id.clone()),
        );
    }
    Ok(())
}

fn require_proof_refs(
    plan_id: &str,
    refs: &TurboVecStableExternalIdProofRefs,
) -> Result<(), TurboVecStableExternalIdRegistryError> {
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
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    let lower = value.to_ascii_lowercase();
    if value.trim().is_empty()
        || value.trim() != value
        || value.chars().any(char::is_control)
        || lower.contains("rowid")
        || lower.contains("insert_order")
        || lower.contains("mutable_slot")
    {
        return Err(TurboVecStableExternalIdRegistryError::MissingField {
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
) -> Result<(), TurboVecStableExternalIdRegistryError> {
    require_nonempty(value, plan_id, field)?;
    if !value.starts_with(expected) {
        return Err(TurboVecStableExternalIdRegistryError::BadPrefix {
            plan_id: plan_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn set_preimage(
    upstream_index_plan_address: &UasAddress,
    upstream_witness_ref: &str,
    plans: &[TurboVecStableExternalIdRegistryPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    registry_status: &TurboVecStableExternalIdRegistryStatus,
    promotion_tier: &TurboVecStableExternalIdPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_CURSOR);
    preimage.push('\n');
    preimage.push_str(TURBOVEC_EIDOS_COMPRESSED_INDEX_PLAN_NEXT_CURSOR);
    preimage.push('\n');
    preimage.push_str(&upstream_index_plan_address.to_string());
    preimage.push('\n');
    preimage.push_str(upstream_witness_ref);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{product_build:?}|{pro_status:?}|{registry_status:?}|{promotion_tier:?}|{metadata_bytes}|{l1_l2_l3_separated}|{runtime_deferred}|{product_promotion_blocked}\n"
    ));
    for plan in plans {
        push_plan_preimage(&mut preimage, plan);
    }
    preimage
}

fn push_plan_preimage(preimage: &mut String, plan: &TurboVecStableExternalIdRegistryPlan) {
    for field in [
        plan.plan_id.as_str(),
        plan.upstream_plan_witness_ref.as_str(),
        plan.source_api_ref.as_str(),
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
    let mut entries = plan.entries.clone();
    entries.sort_by(|a, b| a.entry_id.cmp(&b.entry_id));
    for entry in entries {
        preimage.push_str(&format!(
            "{}|{}|{}|{}|{}|{:?}|{:?}|{}|{}\n",
            entry.entry_id,
            entry.logical_source_key,
            entry.uas_address,
            entry.external_id,
            entry.generation,
            entry.lifecycle,
            entry.external_id_source,
            entry.app_cold_store_ref,
            entry.source_card_ref,
        ));
    }
    let mut collisions = plan.collision_ledger.clone();
    collisions.sort_by(|a, b| a.collision_id.cmp(&b.collision_id));
    for row in collisions {
        preimage.push_str(&format!(
            "{}|{}|{}|{}|{}|{:?}|{}|{}\n",
            row.collision_id,
            row.left_uas_address,
            row.right_uas_address,
            row.candidate_external_id,
            row.resolved_external_id,
            row.resolution,
            row.alias_rejected,
            row.registry_rebuild_required,
        ));
    }
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
        plan.registry_status,
        plan.product_build,
        plan.pro_status,
        plan.promotion_tier,
        plan.policy.app_cold_store_is_truth,
        plan.policy.registry_is_cache_manifest,
        plan.policy.sqlite_rowid_forbidden,
        plan.policy.insert_order_forbidden,
        plan.policy.mutable_slot_forbidden,
        plan.policy.stable_uas_hash_required,
        plan.policy.tombstone_retention_required,
        plan.policy.generation_counter_required,
        plan.policy.collision_ledger_required,
        plan.policy.allowlist_ids_compile_from_uas,
        plan.policy.export_import_roundtrip_required,
        plan.policy.atomic_manifest_required,
        plan.policy.corrupt_manifest_rebuild_required,
        plan.policy.rollback_required,
        plan.policy.run_event_log_required,
        plan.policy.answer_packet_required,
    ));
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_039_100_000;

    #[test]
    fn accepts_stable_registry_and_deterministic_rebuild_address() {
        let set = valid_set();
        let mut plans = set.plans.clone();
        plans[0].entries.reverse();
        plans[0].collision_ledger.reverse();
        let reversed = match build_set(plans) {
            Ok(value) => value,
            Err(error) => panic!("{error}"),
        };

        assert_eq!(set.set_address, reversed.set_address);
        let metrics = set.metrics();
        assert_eq!(metrics.plan_count, 1);
        assert_eq!(metrics.active_entry_count, 2);
        assert_eq!(metrics.tombstoned_entry_count, 1);
        assert_eq!(metrics.reinserted_entry_count, 1);
        assert_eq!(metrics.collision_ledger_count, 1);
        assert_eq!(metrics.registry_bytes_loaded, 0);
        assert_eq!(metrics.index_bytes_loaded, 0);

        let entry = &set.plans[0].entries[0];
        assert_eq!(
            entry.external_id,
            stable_external_id_for_uas(&entry.uas_address)
        );
    }

    #[test]
    fn rejects_rowid_insert_order_mutable_slots_and_zero_ids() {
        let err = mutate_entry(|entry| entry.sqlite_rowid_used = true);
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::InvalidExternalId { .. }
        ));

        let err = mutate_entry(|entry| {
            entry.external_id_source = TurboVecStableExternalIdSource::InsertOrder;
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::InvalidExternalId { .. }
        ));

        let err = mutate_entry(|entry| entry.mutable_vector_slot_used = true);
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::InvalidExternalId { .. }
        ));

        let err = mutate_entry(|entry| entry.external_id = 0);
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::InvalidExternalId { .. }
        ));
    }

    #[test]
    fn rejects_duplicate_uas_duplicate_active_external_id_and_generation_alias() {
        let err = mutate_plan(|plan| {
            let duplicate = plan.entries[0].clone();
            plan.entries.push(duplicate);
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::DuplicateUasAddress(_)
                | TurboVecStableExternalIdRegistryError::DuplicateEntryId(_)
        ));

        let err = mutate_plan(|plan| {
            plan.entries[1].external_id = plan.entries[0].external_id;
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::DuplicateActiveExternalId(_)
                | TurboVecStableExternalIdRegistryError::InvalidExternalId { .. }
        ));

        let err = mutate_plan(|plan| {
            plan.entries[2].generation = 1;
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::DuplicateLogicalGeneration(_)
                | TurboVecStableExternalIdRegistryError::InvalidTombstoneGeneration(_)
        ));
    }

    #[test]
    fn rejects_missing_collision_ledger_policy_runtime_and_promotion() {
        let err = mutate_plan(|plan| plan.collision_ledger.clear());
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::InvalidCollisionLedger(_)
        ));

        let err = mutate_plan(|plan| {
            plan.policy.allowlist_ids_compile_from_uas = false;
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::InvalidPolicy(_)
        ));

        let err = mutate_plan(|plan| {
            plan.byte_ledger.index_bytes_loaded = 1;
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::RuntimeOrIndexNotDeferred(_)
        ));

        let err = mutate_plan(|plan| {
            plan.promotion_tier = TurboVecStableExternalIdPromotionTier::T2L2Route;
        });
        assert!(matches!(
            err,
            TurboVecStableExternalIdRegistryError::BadPromotionTier(_)
        ));
    }

    fn mutate_entry(
        mutate: impl FnOnce(&mut TurboVecStableExternalIdEntry),
    ) -> TurboVecStableExternalIdRegistryError {
        mutate_plan(|plan| mutate(&mut plan.entries[0]))
    }

    fn mutate_plan(
        mutate: impl FnOnce(&mut TurboVecStableExternalIdRegistryPlan),
    ) -> TurboVecStableExternalIdRegistryError {
        let mut plans = valid_set().plans;
        mutate(&mut plans[0]);
        match build_set(plans) {
            Ok(_) => panic!("mutation unexpectedly passed"),
            Err(error) => error,
        }
    }

    fn valid_set() -> TurboVecStableExternalIdRegistryPlanSet {
        match build_set(vec![valid_plan()]) {
            Ok(value) => value,
            Err(error) => panic!("{error}"),
        }
    }

    fn build_set(
        plans: Vec<TurboVecStableExternalIdRegistryPlan>,
    ) -> Result<TurboVecStableExternalIdRegistryPlanSet, TurboVecStableExternalIdRegistryError>
    {
        TurboVecStableExternalIdRegistryPlanSet::from_plans(
            upstream_address(),
            "artifact:turbovec_eidos_compressed_index_plan:result",
            plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan,
            TurboVecStableExternalIdPromotionTier::T1L1Metadata,
            18_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn valid_plan() -> TurboVecStableExternalIdRegistryPlan {
        let alpha = entry(
            "alpha",
            "note_alpha",
            1,
            TurboVecStableExternalIdLifecycle::Active,
        );
        let beta_old = entry(
            "beta_old",
            "note_beta",
            1,
            TurboVecStableExternalIdLifecycle::Tombstoned,
        );
        let beta_new = entry(
            "beta_new",
            "note_beta",
            2,
            TurboVecStableExternalIdLifecycle::ReinsertedNewGeneration,
        );
        let gamma = entry(
            "gamma",
            "code_gamma",
            1,
            TurboVecStableExternalIdLifecycle::Active,
        );
        let collision = TurboVecStableExternalIdCollisionLedgerEntry {
            collision_id: "collision_left_alpha_right_gamma".to_string(),
            left_uas_address: alpha.uas_address.clone(),
            right_uas_address: gamma.uas_address.clone(),
            candidate_external_id: alpha.external_id,
            resolved_external_id: gamma.external_id,
            resolution:
                TurboVecStableExternalIdCollisionResolution::RejectAliasAndAllocateDeterministicId,
            alias_rejected: true,
            registry_rebuild_required: true,
        };

        TurboVecStableExternalIdRegistryPlan {
            plan_id: "turbovec_stable_external_id_registry".to_string(),
            upstream_plan_address: upstream_address(),
            upstream_plan_witness_ref: "artifact:turbovec_eidos_compressed_index_plan:result"
                .to_string(),
            source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md"
                .to_string(),
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            entries: vec![alpha, beta_old, beta_new, gamma],
            collision_ledger: vec![collision],
            policy: TurboVecStableExternalIdRegistryPolicy::fail_closed_cache_manifest(),
            byte_ledger: match TurboVecStableExternalIdByteLedger::metadata_only(12_000, 4_096) {
                Ok(value) => value,
                Err(error) => panic!("{error}"),
            },
            proof_refs: proof_refs("turbovec_stable_external_id_registry"),
            registry_status: TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: TurboVecStableExternalIdPromotionTier::T1L1Metadata,
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

    fn entry(
        salt: &str,
        logical_source_key: &str,
        generation: u64,
        lifecycle: TurboVecStableExternalIdLifecycle,
    ) -> TurboVecStableExternalIdEntry {
        let uas_address = UasAddress::new(
            UasKind::Other("eidos_source_chunk".to_string()),
            format!("{salt}:{logical_source_key}:{generation}").as_bytes(),
            CREATED_AT_MS,
        );
        TurboVecStableExternalIdEntry {
            entry_id: format!("entry_{salt}_{generation}"),
            logical_source_key: logical_source_key.to_string(),
            external_id: stable_external_id_for_uas(&uas_address),
            generation,
            lifecycle,
            external_id_source: TurboVecStableExternalIdSource::UasAddressDeterministicHash,
            app_cold_store_ref: format!("app_cold_store:eidos:{salt}:{generation}"),
            source_card_ref: "compressed_model_source_card:turbovec_eidos_cache".to_string(),
            uas_address,
            sqlite_rowid_used: false,
            insert_order_used: false,
            mutable_vector_slot_used: false,
        }
    }

    fn proof_refs(id: &str) -> TurboVecStableExternalIdProofRefs {
        TurboVecStableExternalIdProofRefs {
            falsifier_ref: format!("falsifier:F-TurboVec-UASAddressStableExternalIds:{id}"),
            rollback_ref: format!("rollback:turbovec_stable_id:{id}"),
            run_event_log_ref: format!("run_event_log:turbovec_stable_id:{id}"),
            answer_packet_ref: format!("answer_packet:turbovec_stable_id:{id}"),
            compatibility_fence_ref: format!("compat:turbovec_stable_id:{id}"),
        }
    }

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_eidos_compressed_index_plan".to_string()),
            b"upstream-turbovec-eidos-index-plan",
            CREATED_AT_MS,
        )
    }
}
