//! TurboVec crash-safe persistent index plan.
//!
//! This primitive hardens the first persistent compressed-cache step after
//! UAS-stable IDs and filter-before-rank privacy. It proves that `.tvim` /
//! manifest persistence is cache material only: atomically written, digest
//! bound, rollback capable, rebuildable from AppColdStore truth, and never a
//! source of hidden route authority or product capability by itself.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_CURSOR: &str =
    "turbovec_crash_safe_persistent_index_plan";
pub const TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_NEXT_CURSOR: &str =
    "turbovec_recall_quality_exact_baseline_plan";

const SOURCE_API_PREFIX: &str = "https://github.com/RyanCodrai/turbovec";
const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_filter_before_rank_privacy_gate:result";
const SOURCE_CARD_PREFIX: &str = "compressed_model_source_card:";
const APP_COLD_STORE_PREFIX: &str = "app_cold_store:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_MANIFEST_BYTES: u64 = 128 * 1024;

// UAS: uas:turbovec-persistent-index:status
// Plane: Verification
// Residency: metadata-only persistence planning status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecPersistentIndexStatus {
    MetadataOnlyPlan,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-persistent-index:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecPersistentIndexPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-persistent-index:file-kind
// Plane: State + Verification
// Residency: file roles in the cache-manifest plan.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecPersistentFileKind {
    IdMapTvim,
    PositionalTv,
    ManifestJson,
    TempFile,
    PreviousManifestPointer,
}

// UAS: uas:turbovec-persistent-index:failure-kind
// Plane: Verification
// Residency: crash/corruption cases that must fail closed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecPersistenceFailureKind {
    CleanCommit,
    PartialWrite,
    CorruptMagic,
    VersionMismatch,
    DigestMismatch,
    DuplicateExternalId,
    MissingAppColdStoreSource,
    PermissionDenied,
    StaleManifestPointer,
}

// UAS: uas:turbovec-persistent-index:recovery
// Plane: Controller + Verification
// Residency: allowed outcomes for cache persistence failures.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecPersistenceRecoveryDecision {
    AcceptNewManifest,
    RollBackToPreviousManifest,
    RebuildFromAppColdStore,
    RefuseAndEmitAnswerPacket,
}

// UAS: uas:turbovec-persistent-index:file-plan
// Plane: State + Verification
// Residency: planned persistent file; no bytes opened in this witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecPersistentIndexFilePlan {
    pub file_id: String,
    pub file_kind: TurboVecPersistentFileKind,
    pub logical_path: String,
    pub temp_path: String,
    pub final_path: String,
    pub expected_magic: String,
    pub format_version: u32,
    pub manifest_digest: String,
    pub planned_file_bytes: u64,
    pub opened_file_bytes: u64,
    pub written_file_bytes: u64,
    pub loaded_index_bytes: u64,
    pub source_card_ref: String,
    pub app_cold_store_ref: String,
    pub stable_external_ids: Vec<u64>,
    pub duplicate_external_id_present: bool,
    pub path_is_content_addressed: bool,
    pub temp_write_required: bool,
    pub fsync_file_required: bool,
    pub fsync_parent_dir_required: bool,
    pub atomic_rename_required: bool,
    pub previous_manifest_retained: bool,
}

// UAS: uas:turbovec-persistent-index:failure-scenario
// Plane: Verification
// Residency: tiny synthetic crash/corruption fixture.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecPersistenceFailureScenario {
    pub scenario_id: String,
    pub failure_kind: TurboVecPersistenceFailureKind,
    pub recovery_decision: TurboVecPersistenceRecoveryDecision,
    pub corrupt_index_detected: bool,
    pub old_manifest_still_usable: bool,
    pub rebuild_from_app_cold_store: bool,
    pub new_manifest_promoted: bool,
    pub quarantine_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

// UAS: uas:turbovec-persistent-index:policy
// Plane: Controller + Verification
// Residency: fail-closed persistence wrapper before any live cache.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecCrashSafePersistentIndexPolicy {
    pub app_cold_store_is_truth: bool,
    pub persistent_index_is_cache: bool,
    pub privacy_gate_required: bool,
    pub stable_external_ids_required: bool,
    pub manifest_digest_required: bool,
    pub magic_version_check_required: bool,
    pub duplicate_external_ids_rejected: bool,
    pub temp_write_required: bool,
    pub fsync_file_required: bool,
    pub fsync_parent_dir_required: bool,
    pub atomic_rename_required: bool,
    pub previous_manifest_retained: bool,
    pub corrupt_index_rebuild_required: bool,
    pub stale_pointer_rejected: bool,
    pub permission_denial_refuses_promotion: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub eidos_score_can_select_route: bool,
}

impl TurboVecCrashSafePersistentIndexPolicy {
    pub fn fail_closed_cache_persistence() -> Self {
        Self {
            app_cold_store_is_truth: true,
            persistent_index_is_cache: true,
            privacy_gate_required: true,
            stable_external_ids_required: true,
            manifest_digest_required: true,
            magic_version_check_required: true,
            duplicate_external_ids_rejected: true,
            temp_write_required: true,
            fsync_file_required: true,
            fsync_parent_dir_required: true,
            atomic_rename_required: true,
            previous_manifest_retained: true,
            corrupt_index_rebuild_required: true,
            stale_pointer_rejected: true,
            permission_denial_refuses_promotion: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            eidos_score_can_select_route: false,
        }
    }
}

// UAS: uas:turbovec-persistent-index:byte-ledger
// Plane: Verification
// Residency: metadata-only proof boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecPersistentIndexByteLedger {
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub index_bytes_opened: u64,
    pub index_bytes_written: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecPersistentIndexByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        manifest_bytes_read: u64,
    ) -> Result<Self, TurboVecCrashSafePersistentIndexError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || manifest_bytes_read > MAX_MANIFEST_BYTES {
            return Err(
                TurboVecCrashSafePersistentIndexError::MetadataBudgetExceeded {
                    metadata_bytes_read,
                    manifest_bytes_read,
                },
            );
        }
        Ok(Self {
            metadata_bytes_read,
            manifest_bytes_read,
            index_bytes_opened: 0,
            index_bytes_written: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        })
    }
}

// UAS: uas:turbovec-persistent-index:proof-refs
// Plane: Verification
// Residency: visible proof handles required before live cache persistence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecPersistentIndexProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:turbovec-persistent-index:plan
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only crash-safe persistent-index plan.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecCrashSafePersistentIndexPlan {
    pub plan_id: String,
    pub upstream_privacy_gate_address: UasAddress,
    pub upstream_privacy_gate_witness_ref: String,
    pub source_api_ref: String,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub files: Vec<TurboVecPersistentIndexFilePlan>,
    pub failure_scenarios: Vec<TurboVecPersistenceFailureScenario>,
    pub policy: TurboVecCrashSafePersistentIndexPolicy,
    pub byte_ledger: TurboVecPersistentIndexByteLedger,
    pub proof_refs: TurboVecPersistentIndexProofRefs,
    pub index_status: TurboVecPersistentIndexStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: TurboVecPersistentIndexPromotionTier,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub index_build_deferred: bool,
    pub product_promotion_blocked: bool,
    pub hidden_route_authority_allowed: bool,
    pub route_mutation_allowed: bool,
    pub live_recall_quality_claimed: bool,
    pub persistent_index_claimed_as_truth: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
}

// UAS: uas:turbovec-persistent-index:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only persistent-index pack.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecCrashSafePersistentIndexPlanSet {
    pub set_address: UasAddress,
    pub upstream_privacy_gate_address: UasAddress,
    pub upstream_privacy_gate_witness_ref: String,
    pub plans: Vec<TurboVecCrashSafePersistentIndexPlan>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub index_status: TurboVecPersistentIndexStatus,
    pub promotion_tier: TurboVecPersistentIndexPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:turbovec-persistent-index:metrics
// Plane: Verification
// Residency: counters for metadata-only persistence witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecCrashSafePersistentIndexMetrics {
    pub plan_count: u64,
    pub file_count: u64,
    pub idmap_tvim_file_count: u64,
    pub manifest_file_count: u64,
    pub temp_file_count: u64,
    pub scenario_count: u64,
    pub rollback_scenario_count: u64,
    pub rebuild_scenario_count: u64,
    pub answer_packet_scenario_count: u64,
    pub duplicate_external_id_count: u64,
    pub metadata_bytes_read: u64,
    pub manifest_bytes_read: u64,
    pub planned_file_bytes: u64,
    pub index_bytes_opened: u64,
    pub index_bytes_written: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
}

impl TurboVecCrashSafePersistentIndexPlanSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_plans(
        upstream_privacy_gate_address: UasAddress,
        upstream_privacy_gate_witness_ref: impl Into<String>,
        mut plans: Vec<TurboVecCrashSafePersistentIndexPlan>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        index_status: TurboVecPersistentIndexStatus,
        promotion_tier: TurboVecPersistentIndexPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, TurboVecCrashSafePersistentIndexError> {
        plans.sort_by(|a, b| a.plan_id.cmp(&b.plan_id));
        let witness_ref = upstream_privacy_gate_witness_ref.into();
        validate_set_inputs(
            &upstream_privacy_gate_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            &index_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = set_preimage(
            &upstream_privacy_gate_address,
            &witness_ref,
            &plans,
            &product_build,
            &pro_status,
            &index_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_privacy_gate_address,
            upstream_privacy_gate_witness_ref: witness_ref,
            plans,
            product_build,
            pro_status,
            index_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> TurboVecCrashSafePersistentIndexMetrics {
        let mut metrics = TurboVecCrashSafePersistentIndexMetrics {
            plan_count: self.plans.len() as u64,
            file_count: 0,
            idmap_tvim_file_count: 0,
            manifest_file_count: 0,
            temp_file_count: 0,
            scenario_count: 0,
            rollback_scenario_count: 0,
            rebuild_scenario_count: 0,
            answer_packet_scenario_count: 0,
            duplicate_external_id_count: 0,
            metadata_bytes_read: self.metadata_bytes,
            manifest_bytes_read: 0,
            planned_file_bytes: 0,
            index_bytes_opened: 0,
            index_bytes_written: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
        };
        for plan in &self.plans {
            metrics.metadata_bytes_read += plan.byte_ledger.metadata_bytes_read;
            metrics.manifest_bytes_read += plan.byte_ledger.manifest_bytes_read;
            metrics.index_bytes_opened += plan.byte_ledger.index_bytes_opened;
            metrics.index_bytes_written += plan.byte_ledger.index_bytes_written;
            metrics.index_bytes_loaded += plan.byte_ledger.index_bytes_loaded;
            metrics.runtime_bytes_loaded += plan.byte_ledger.runtime_bytes_loaded;
            metrics.model_bytes_loaded += plan.byte_ledger.model_bytes_loaded;
            metrics.provider_calls_made += plan.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += plan.byte_ledger.copied_product_file_count;
            for file in &plan.files {
                metrics.file_count += 1;
                metrics.planned_file_bytes += file.planned_file_bytes;
                metrics.index_bytes_opened += file.opened_file_bytes;
                metrics.index_bytes_written += file.written_file_bytes;
                metrics.index_bytes_loaded += file.loaded_index_bytes;
                if file.duplicate_external_id_present {
                    metrics.duplicate_external_id_count += 1;
                }
                match file.file_kind {
                    TurboVecPersistentFileKind::IdMapTvim => metrics.idmap_tvim_file_count += 1,
                    TurboVecPersistentFileKind::ManifestJson => metrics.manifest_file_count += 1,
                    TurboVecPersistentFileKind::TempFile => metrics.temp_file_count += 1,
                    TurboVecPersistentFileKind::PositionalTv
                    | TurboVecPersistentFileKind::PreviousManifestPointer => {}
                }
            }
            for scenario in &plan.failure_scenarios {
                metrics.scenario_count += 1;
                match scenario.recovery_decision {
                    TurboVecPersistenceRecoveryDecision::RollBackToPreviousManifest => {
                        metrics.rollback_scenario_count += 1;
                    }
                    TurboVecPersistenceRecoveryDecision::RebuildFromAppColdStore => {
                        metrics.rebuild_scenario_count += 1;
                    }
                    TurboVecPersistenceRecoveryDecision::RefuseAndEmitAnswerPacket => {
                        metrics.answer_packet_scenario_count += 1;
                    }
                    TurboVecPersistenceRecoveryDecision::AcceptNewManifest => {}
                }
                if !scenario.answer_packet_ref.is_empty() {
                    metrics.answer_packet_scenario_count += 1;
                }
            }
        }
        metrics
    }
}

// UAS: uas:turbovec-persistent-index:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy for persistent cache planning.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecCrashSafePersistentIndexError {
    MissingUpstreamPrivacyGate,
    MissingUpstreamWitness,
    BadUpstreamCursor,
    EmptyPlans,
    DuplicatePlanId(String),
    DuplicateFileId(String),
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
    BadIndexStatus(String),
    BadPromotionTier(String),
    InvalidOrgans(String),
    MissingFileCoverage(String),
    MissingScenarioCoverage(String),
    InvalidFile(String),
    InvalidScenario(String),
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

impl fmt::Display for TurboVecCrashSafePersistentIndexError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamPrivacyGate => write!(f, "missing upstream TurboVec privacy gate"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream privacy witness"),
            Self::BadUpstreamCursor => write!(
                f,
                "upstream TurboVec privacy gate did not point at persistent index cursor"
            ),
            Self::EmptyPlans => write!(f, "TurboVec persistent-index plan set is empty"),
            Self::DuplicatePlanId(id) => write!(f, "duplicate persistent-index plan `{id}`"),
            Self::DuplicateFileId(id) => write!(f, "duplicate persistent-index file `{id}`"),
            Self::DuplicateScenarioId(id) => {
                write!(f, "duplicate persistent-index scenario `{id}`")
            }
            Self::MissingField { plan_id, field } => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{plan_id}` missing `{field}`"
                )
            }
            Self::BadPrefix {
                plan_id,
                field,
                expected,
            } => write!(
                f,
                "TurboVec persistent-index plan `{plan_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadProductBuild(id) => {
                write!(f, "TurboVec persistent-index plan `{id}` leaked to MAS")
            }
            Self::BadProStatus(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` has forbidden Pro status"
                )
            }
            Self::BadIndexStatus(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` has forbidden status"
                )
            }
            Self::BadPromotionTier(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` promoted beyond T1"
                )
            }
            Self::InvalidOrgans(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` has invalid organs"
                )
            }
            Self::MissingFileCoverage(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` lacks required files"
                )
            }
            Self::MissingScenarioCoverage(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` lacks crash scenarios"
                )
            }
            Self::InvalidFile(id) => write!(f, "TurboVec persistent-index file `{id}` is unsafe"),
            Self::InvalidScenario(id) => {
                write!(f, "TurboVec persistent-index scenario `{id}` is unsafe")
            }
            Self::InvalidPolicy(id) => {
                write!(f, "TurboVec persistent-index plan `{id}` has unsafe policy")
            }
            Self::InvalidProofRefs(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` has unsafe proof refs"
                )
            }
            Self::MetadataBudgetExceeded {
                metadata_bytes_read,
                manifest_bytes_read,
            } => write!(
                f,
                "TurboVec persistent-index metadata budget exceeded: metadata={metadata_bytes_read}, manifest={manifest_bytes_read}"
            ),
            Self::RuntimeOrIndexNotDeferred(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` tried to build or run"
                )
            }
            Self::HiddenAuthority(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` enabled hidden authority"
                )
            }
            Self::ProductPromotionAllowed(id) => {
                write!(
                    f,
                    "TurboVec persistent-index plan `{id}` promoted product truth"
                )
            }
            Self::SetPromotionAllowed => write!(f, "TurboVec persistent-index set promoted truth"),
        }
    }
}

impl std::error::Error for TurboVecCrashSafePersistentIndexError {}

pub fn persistent_file_digest(
    file_id: &str,
    file_kind: TurboVecPersistentFileKind,
    expected_magic: &str,
    format_version: u32,
    planned_file_bytes: u64,
    stable_external_ids: &[u64],
) -> String {
    let mut ids = stable_external_ids.to_vec();
    ids.sort_unstable();
    sha256_hex(
        format!(
            "{file_id}|{file_kind:?}|{expected_magic}|{format_version}|{planned_file_bytes}|{ids:?}"
        )
        .as_bytes(),
    )
}

fn validate_set_inputs(
    upstream_privacy_gate_address: &UasAddress,
    upstream_witness_ref: &str,
    plans: &[TurboVecCrashSafePersistentIndexPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    index_status: &TurboVecPersistentIndexStatus,
    promotion_tier: &TurboVecPersistentIndexPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if upstream_privacy_gate_address.to_string().trim().is_empty() {
        return Err(TurboVecCrashSafePersistentIndexError::MissingUpstreamPrivacyGate);
    }
    if upstream_witness_ref != UPSTREAM_WITNESS_REF {
        return Err(TurboVecCrashSafePersistentIndexError::MissingUpstreamWitness);
    }
    if !matches!(
        upstream_privacy_gate_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_filter_before_rank_privacy_gate_plan"
    ) {
        return Err(TurboVecCrashSafePersistentIndexError::BadUpstreamCursor);
    }
    if plans.is_empty() {
        return Err(TurboVecCrashSafePersistentIndexError::EmptyPlans);
    }
    if metadata_bytes > MAX_METADATA_BYTES {
        return Err(
            TurboVecCrashSafePersistentIndexError::MetadataBudgetExceeded {
                metadata_bytes_read: metadata_bytes,
                manifest_bytes_read: 0,
            },
        );
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || index_status != &TurboVecPersistentIndexStatus::MetadataOnlyPlan
        || !matches!(
            promotion_tier,
            TurboVecPersistentIndexPromotionTier::T0Research
                | TurboVecPersistentIndexPromotionTier::T1L1Metadata
        )
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(TurboVecCrashSafePersistentIndexError::SetPromotionAllowed);
    }

    let mut plan_ids = HashSet::new();
    for plan in plans {
        if plan.upstream_privacy_gate_address != *upstream_privacy_gate_address {
            return Err(TurboVecCrashSafePersistentIndexError::MissingUpstreamPrivacyGate);
        }
        validate_plan(plan)?;
        if !plan_ids.insert(plan.plan_id.clone()) {
            return Err(TurboVecCrashSafePersistentIndexError::DuplicatePlanId(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_plan(
    plan: &TurboVecCrashSafePersistentIndexPlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    require_nonempty(&plan.plan_id, &plan.plan_id, "plan_id")?;
    require_nonempty(
        &plan.upstream_privacy_gate_witness_ref,
        &plan.plan_id,
        "upstream_privacy_gate_witness_ref",
    )?;
    require_nonempty(&plan.source_api_ref, &plan.plan_id, "source_api_ref")?;
    require_proof_refs(&plan.plan_id, &plan.proof_refs)?;
    if plan.upstream_privacy_gate_witness_ref != UPSTREAM_WITNESS_REF {
        return Err(TurboVecCrashSafePersistentIndexError::MissingUpstreamWitness);
    }
    if !plan.source_api_ref.starts_with(SOURCE_API_PREFIX) {
        return Err(TurboVecCrashSafePersistentIndexError::BadPrefix {
            plan_id: plan.plan_id.clone(),
            field: "source_api_ref",
            expected: SOURCE_API_PREFIX,
        });
    }
    if plan.product_build != ProductBuild::Pro {
        return Err(TurboVecCrashSafePersistentIndexError::BadProductBuild(
            plan.plan_id.clone(),
        ));
    }
    if plan.pro_status != ProStatus::ResearchCandidate {
        return Err(TurboVecCrashSafePersistentIndexError::BadProStatus(
            plan.plan_id.clone(),
        ));
    }
    if plan.index_status != TurboVecPersistentIndexStatus::MetadataOnlyPlan {
        return Err(TurboVecCrashSafePersistentIndexError::BadIndexStatus(
            plan.plan_id.clone(),
        ));
    }
    if !matches!(
        plan.promotion_tier,
        TurboVecPersistentIndexPromotionTier::T0Research
            | TurboVecPersistentIndexPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecCrashSafePersistentIndexError::BadPromotionTier(
            plan.plan_id.clone(),
        ));
    }
    validate_organs(plan)?;
    validate_policy(plan)?;
    validate_files(plan)?;
    validate_scenarios(plan)?;
    validate_byte_ledger(plan)?;
    if !plan.l1_l2_l3_separated
        || !plan.runtime_deferred
        || !plan.index_build_deferred
        || !plan.product_promotion_blocked
    {
        return Err(
            TurboVecCrashSafePersistentIndexError::RuntimeOrIndexNotDeferred(plan.plan_id.clone()),
        );
    }
    if plan.hidden_route_authority_allowed
        || plan.route_mutation_allowed
        || plan.hidden_cloud_fallback_allowed
    {
        return Err(TurboVecCrashSafePersistentIndexError::HiddenAuthority(
            plan.plan_id.clone(),
        ));
    }
    if plan.live_recall_quality_claimed
        || plan.persistent_index_claimed_as_truth
        || plan.live_dense_70b_claimed
        || plan.ssd_as_ram_claimed
    {
        return Err(
            TurboVecCrashSafePersistentIndexError::ProductPromotionAllowed(plan.plan_id.clone()),
        );
    }
    Ok(())
}

fn validate_organs(
    plan: &TurboVecCrashSafePersistentIndexPlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if !plan.organs.contains(&TurboVecIndexOrgan::Eidos)
        || !plan.organs.contains(&TurboVecIndexOrgan::AppColdStore)
        || !plan
            .organs
            .contains(&TurboVecIndexOrgan::SemanticWorkingSetPlan)
        || !plan.organs.contains(&TurboVecIndexOrgan::AnswerPacket)
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidOrgans(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_policy(
    plan: &TurboVecCrashSafePersistentIndexPlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    let policy = &plan.policy;
    if !policy.app_cold_store_is_truth
        || !policy.persistent_index_is_cache
        || !policy.privacy_gate_required
        || !policy.stable_external_ids_required
        || !policy.manifest_digest_required
        || !policy.magic_version_check_required
        || !policy.duplicate_external_ids_rejected
        || !policy.temp_write_required
        || !policy.fsync_file_required
        || !policy.fsync_parent_dir_required
        || !policy.atomic_rename_required
        || !policy.previous_manifest_retained
        || !policy.corrupt_index_rebuild_required
        || !policy.stale_pointer_rejected
        || !policy.permission_denial_refuses_promotion
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.compatibility_fence_required
        || policy.eidos_score_can_select_route
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidPolicy(
            plan.plan_id.clone(),
        ));
    }
    Ok(())
}

fn validate_files(
    plan: &TurboVecCrashSafePersistentIndexPlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if plan.files.is_empty() {
        return Err(TurboVecCrashSafePersistentIndexError::MissingFileCoverage(
            plan.plan_id.clone(),
        ));
    }
    let mut file_ids = HashSet::new();
    let mut file_kinds = HashSet::new();
    for file in &plan.files {
        if !file_ids.insert(file.file_id.clone()) {
            return Err(TurboVecCrashSafePersistentIndexError::DuplicateFileId(
                file.file_id.clone(),
            ));
        }
        file_kinds.insert(file.file_kind);
        validate_file(file)?;
    }
    for required in [
        TurboVecPersistentFileKind::IdMapTvim,
        TurboVecPersistentFileKind::ManifestJson,
        TurboVecPersistentFileKind::TempFile,
        TurboVecPersistentFileKind::PreviousManifestPointer,
    ] {
        if !file_kinds.contains(&required) {
            return Err(TurboVecCrashSafePersistentIndexError::MissingFileCoverage(
                plan.plan_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_file(
    file: &TurboVecPersistentIndexFilePlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    for value in [
        file.file_id.as_str(),
        file.logical_path.as_str(),
        file.temp_path.as_str(),
        file.final_path.as_str(),
        file.expected_magic.as_str(),
        file.manifest_digest.as_str(),
        file.source_card_ref.as_str(),
        file.app_cold_store_ref.as_str(),
    ] {
        if value.trim().is_empty() {
            return Err(TurboVecCrashSafePersistentIndexError::InvalidFile(
                file.file_id.clone(),
            ));
        }
    }
    if !file.source_card_ref.starts_with(SOURCE_CARD_PREFIX)
        || !file.app_cold_store_ref.starts_with(APP_COLD_STORE_PREFIX)
        || !file
            .final_path
            .starts_with("app_cold_store/turbovec/eidos/")
        || !file.temp_path.contains(".tmp")
        || !file.temp_path.starts_with("app_cold_store/turbovec/eidos/")
        || !file.final_path.contains("sha256-")
        || !file.path_is_content_addressed
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidFile(
            file.file_id.clone(),
        ));
    }
    if file.format_version == 0
        || file.planned_file_bytes == 0
        || file.opened_file_bytes != 0
        || file.written_file_bytes != 0
        || file.loaded_index_bytes != 0
        || file.duplicate_external_id_present
        || !file.temp_write_required
        || !file.fsync_file_required
        || !file.fsync_parent_dir_required
        || !file.atomic_rename_required
        || !file.previous_manifest_retained
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidFile(
            file.file_id.clone(),
        ));
    }
    if !matches!(
        file.file_kind,
        TurboVecPersistentFileKind::PreviousManifestPointer
    ) && file.stable_external_ids.is_empty()
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidFile(
            file.file_id.clone(),
        ));
    }
    let mut ids = HashSet::new();
    for id in &file.stable_external_ids {
        if *id == 0 || !ids.insert(*id) {
            return Err(TurboVecCrashSafePersistentIndexError::InvalidFile(
                file.file_id.clone(),
            ));
        }
    }
    if file.manifest_digest
        != persistent_file_digest(
            &file.file_id,
            file.file_kind,
            &file.expected_magic,
            file.format_version,
            file.planned_file_bytes,
            &file.stable_external_ids,
        )
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidFile(
            file.file_id.clone(),
        ));
    }
    Ok(())
}

fn validate_scenarios(
    plan: &TurboVecCrashSafePersistentIndexPlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if plan.failure_scenarios.is_empty() {
        return Err(
            TurboVecCrashSafePersistentIndexError::MissingScenarioCoverage(plan.plan_id.clone()),
        );
    }
    let mut scenario_ids = HashSet::new();
    let mut failure_kinds = HashSet::new();
    for scenario in &plan.failure_scenarios {
        if !scenario_ids.insert(scenario.scenario_id.clone()) {
            return Err(TurboVecCrashSafePersistentIndexError::DuplicateScenarioId(
                scenario.scenario_id.clone(),
            ));
        }
        failure_kinds.insert(scenario.failure_kind);
        validate_scenario(scenario)?;
    }
    for required in [
        TurboVecPersistenceFailureKind::CleanCommit,
        TurboVecPersistenceFailureKind::PartialWrite,
        TurboVecPersistenceFailureKind::CorruptMagic,
        TurboVecPersistenceFailureKind::VersionMismatch,
        TurboVecPersistenceFailureKind::DigestMismatch,
        TurboVecPersistenceFailureKind::DuplicateExternalId,
        TurboVecPersistenceFailureKind::MissingAppColdStoreSource,
        TurboVecPersistenceFailureKind::PermissionDenied,
        TurboVecPersistenceFailureKind::StaleManifestPointer,
    ] {
        if !failure_kinds.contains(&required) {
            return Err(
                TurboVecCrashSafePersistentIndexError::MissingScenarioCoverage(
                    plan.plan_id.clone(),
                ),
            );
        }
    }
    Ok(())
}

fn validate_scenario(
    scenario: &TurboVecPersistenceFailureScenario,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if scenario.scenario_id.trim().is_empty()
        || !scenario.quarantine_ref.starts_with("quarantine:turbovec:")
        || !scenario.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !scenario.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        || !scenario.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
    {
        return Err(TurboVecCrashSafePersistentIndexError::InvalidScenario(
            scenario.scenario_id.clone(),
        ));
    }
    match scenario.failure_kind {
        TurboVecPersistenceFailureKind::CleanCommit => {
            if scenario.recovery_decision != TurboVecPersistenceRecoveryDecision::AcceptNewManifest
                || scenario.corrupt_index_detected
                || !scenario.new_manifest_promoted
                || !scenario.old_manifest_still_usable
            {
                return Err(TurboVecCrashSafePersistentIndexError::InvalidScenario(
                    scenario.scenario_id.clone(),
                ));
            }
        }
        TurboVecPersistenceFailureKind::PartialWrite
        | TurboVecPersistenceFailureKind::PermissionDenied
        | TurboVecPersistenceFailureKind::StaleManifestPointer => {
            if scenario.recovery_decision
                != TurboVecPersistenceRecoveryDecision::RollBackToPreviousManifest
                || !scenario.old_manifest_still_usable
                || scenario.new_manifest_promoted
            {
                return Err(TurboVecCrashSafePersistentIndexError::InvalidScenario(
                    scenario.scenario_id.clone(),
                ));
            }
        }
        TurboVecPersistenceFailureKind::CorruptMagic
        | TurboVecPersistenceFailureKind::VersionMismatch
        | TurboVecPersistenceFailureKind::DigestMismatch
        | TurboVecPersistenceFailureKind::DuplicateExternalId => {
            if scenario.recovery_decision
                != TurboVecPersistenceRecoveryDecision::RebuildFromAppColdStore
                || !scenario.corrupt_index_detected
                || !scenario.rebuild_from_app_cold_store
                || scenario.new_manifest_promoted
            {
                return Err(TurboVecCrashSafePersistentIndexError::InvalidScenario(
                    scenario.scenario_id.clone(),
                ));
            }
        }
        TurboVecPersistenceFailureKind::MissingAppColdStoreSource => {
            if scenario.recovery_decision
                != TurboVecPersistenceRecoveryDecision::RefuseAndEmitAnswerPacket
                || scenario.new_manifest_promoted
                || scenario.rebuild_from_app_cold_store
            {
                return Err(TurboVecCrashSafePersistentIndexError::InvalidScenario(
                    scenario.scenario_id.clone(),
                ));
            }
        }
    }
    Ok(())
}

fn validate_byte_ledger(
    plan: &TurboVecCrashSafePersistentIndexPlan,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if plan.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || plan.byte_ledger.manifest_bytes_read > MAX_MANIFEST_BYTES
    {
        return Err(
            TurboVecCrashSafePersistentIndexError::MetadataBudgetExceeded {
                metadata_bytes_read: plan.byte_ledger.metadata_bytes_read,
                manifest_bytes_read: plan.byte_ledger.manifest_bytes_read,
            },
        );
    }
    if plan.byte_ledger.index_bytes_opened != 0
        || plan.byte_ledger.index_bytes_written != 0
        || plan.byte_ledger.index_bytes_loaded != 0
        || plan.byte_ledger.runtime_bytes_loaded != 0
        || plan.byte_ledger.model_bytes_loaded != 0
        || plan.byte_ledger.provider_calls_made != 0
        || plan.byte_ledger.copied_product_file_count != 0
    {
        return Err(
            TurboVecCrashSafePersistentIndexError::RuntimeOrIndexNotDeferred(plan.plan_id.clone()),
        );
    }
    Ok(())
}

fn require_nonempty(
    value: &str,
    plan_id: &str,
    field: &'static str,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
    if value.trim().is_empty() {
        return Err(TurboVecCrashSafePersistentIndexError::MissingField {
            plan_id: plan_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_proof_refs(
    plan_id: &str,
    refs: &TurboVecPersistentIndexProofRefs,
) -> Result<(), TurboVecCrashSafePersistentIndexError> {
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
            return Err(TurboVecCrashSafePersistentIndexError::BadPrefix {
                plan_id: plan_id.to_string(),
                field,
                expected: prefix,
            });
        }
    }
    Ok(())
}

fn set_preimage(
    upstream_privacy_gate_address: &UasAddress,
    witness_ref: &str,
    plans: &[TurboVecCrashSafePersistentIndexPlan],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    index_status: &TurboVecPersistentIndexStatus,
    promotion_tier: &TurboVecPersistentIndexPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut parts = vec![
        upstream_privacy_gate_address.to_string(),
        witness_ref.to_string(),
        format!("{product_build:?}"),
        format!("{pro_status:?}"),
        format!("{index_status:?}"),
        format!("{promotion_tier:?}"),
        metadata_bytes.to_string(),
        l1_l2_l3_separated.to_string(),
        runtime_deferred.to_string(),
        product_promotion_blocked.to_string(),
    ];
    for plan in plans {
        parts.push(plan.plan_id.clone());
        parts.push(plan.upstream_privacy_gate_address.to_string());
        parts.push(plan.source_api_ref.clone());
        let mut files = plan.files.clone();
        files.sort_by(|a, b| a.file_id.cmp(&b.file_id));
        for file in files {
            parts.push(file.file_id);
            parts.push(format!("{:?}", file.file_kind));
            parts.push(file.logical_path);
            parts.push(file.temp_path);
            parts.push(file.final_path);
            parts.push(file.expected_magic);
            parts.push(file.format_version.to_string());
            parts.push(file.manifest_digest);
            parts.push(file.planned_file_bytes.to_string());
            parts.push(format!("{:?}", file.stable_external_ids));
        }
        let mut scenarios = plan.failure_scenarios.clone();
        scenarios.sort_by(|a, b| a.scenario_id.cmp(&b.scenario_id));
        for scenario in scenarios {
            parts.push(scenario.scenario_id);
            parts.push(format!("{:?}", scenario.failure_kind));
            parts.push(format!("{:?}", scenario.recovery_decision));
            parts.push(scenario.corrupt_index_detected.to_string());
            parts.push(scenario.old_manifest_still_usable.to_string());
            parts.push(scenario.rebuild_from_app_cold_store.to_string());
            parts.push(scenario.new_manifest_promoted.to_string());
        }
    }
    parts.join("|")
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_039_300_000;

    #[test]
    fn accepts_persistent_index_plan_and_deterministic_address() {
        let upstream = upstream_address();
        let plans = vec![accepted_plan(upstream.clone())];
        let set = build_set(upstream.clone(), plans.clone()).expect("accepted fixture should pass");
        let mut reversed = plans;
        reversed[0].files.reverse();
        reversed[0].failure_scenarios.reverse();
        let reversed_set = build_set(upstream, reversed).expect("reordered fixture should pass");
        assert_eq!(set.set_address, reversed_set.set_address);
        assert_eq!(set.metrics().index_bytes_loaded, 0);
        assert_eq!(set.metrics().duplicate_external_id_count, 0);
    }

    #[test]
    fn rejects_non_atomic_or_unsafe_persistence() {
        let upstream = upstream_address();
        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].files[0].atomic_rename_required = false;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream)];
        plans[0].policy.previous_manifest_retained = false;
        assert!(build_set(upstream_address(), plans).is_err());
    }

    #[test]
    fn rejects_digest_duplicate_id_and_byte_loads() {
        let upstream = upstream_address();
        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].files[0].manifest_digest = "sha256:bad".to_string();
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream.clone())];
        let id = plans[0].files[0].stable_external_ids[0];
        plans[0].files[0].stable_external_ids.push(id);
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream)];
        plans[0].byte_ledger.index_bytes_loaded = 1;
        assert!(build_set(upstream_address(), plans).is_err());
    }

    #[test]
    fn rejects_product_promotion_hidden_authority_and_truth_claims() {
        let upstream = upstream_address();
        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].promotion_tier = TurboVecPersistentIndexPromotionTier::T2L2Route;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream.clone())];
        plans[0].hidden_route_authority_allowed = true;
        assert!(build_set(upstream.clone(), plans).is_err());

        let mut plans = vec![accepted_plan(upstream)];
        plans[0].persistent_index_claimed_as_truth = true;
        assert!(build_set(upstream_address(), plans).is_err());
    }

    fn build_set(
        upstream: UasAddress,
        plans: Vec<TurboVecCrashSafePersistentIndexPlan>,
    ) -> Result<TurboVecCrashSafePersistentIndexPlanSet, TurboVecCrashSafePersistentIndexError>
    {
        TurboVecCrashSafePersistentIndexPlanSet::from_plans(
            upstream,
            UPSTREAM_WITNESS_REF,
            plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecPersistentIndexStatus::MetadataOnlyPlan,
            TurboVecPersistentIndexPromotionTier::T1L1Metadata,
            18_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn accepted_plan(upstream: UasAddress) -> TurboVecCrashSafePersistentIndexPlan {
        TurboVecCrashSafePersistentIndexPlan {
            plan_id: "turbovec_crash_safe_persistent_index".to_string(),
            upstream_privacy_gate_address: upstream,
            upstream_privacy_gate_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md"
                .to_string(),
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            files: accepted_files(),
            failure_scenarios: accepted_scenarios(),
            policy: TurboVecCrashSafePersistentIndexPolicy::fail_closed_cache_persistence(),
            byte_ledger: TurboVecPersistentIndexByteLedger::metadata_only(10_000, 4_000)
                .expect("metadata budget should pass"),
            proof_refs: TurboVecPersistentIndexProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-CrashSafePersistentIndex:test".to_string(),
                rollback_ref: "rollback:turbovec_persist:test".to_string(),
                run_event_log_ref: "run_event_log:turbovec_persist:test".to_string(),
                answer_packet_ref: "answer_packet:turbovec_persist:test".to_string(),
                compatibility_fence_ref: "compat:turbovec_persist:test".to_string(),
            },
            index_status: TurboVecPersistentIndexStatus::MetadataOnlyPlan,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: TurboVecPersistentIndexPromotionTier::T1L1Metadata,
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            index_build_deferred: true,
            product_promotion_blocked: true,
            hidden_route_authority_allowed: false,
            route_mutation_allowed: false,
            live_recall_quality_claimed: false,
            persistent_index_claimed_as_truth: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
        }
    }

    fn accepted_files() -> Vec<TurboVecPersistentIndexFilePlan> {
        vec![
            file(
                "idmap_tvim",
                TurboVecPersistentFileKind::IdMapTvim,
                "TVIM",
                1,
                12_288,
                vec![11, 22, 33],
            ),
            file(
                "manifest_json",
                TurboVecPersistentFileKind::ManifestJson,
                "JSON",
                1,
                2_048,
                vec![11, 22, 33],
            ),
            file(
                "temp_file",
                TurboVecPersistentFileKind::TempFile,
                "TVIM",
                1,
                12_288,
                vec![11, 22, 33],
            ),
            file(
                "previous_manifest",
                TurboVecPersistentFileKind::PreviousManifestPointer,
                "JSON",
                1,
                512,
                vec![11],
            ),
        ]
    }

    fn file(
        id: &str,
        kind: TurboVecPersistentFileKind,
        magic: &str,
        version: u32,
        bytes: u64,
        ids: Vec<u64>,
    ) -> TurboVecPersistentIndexFilePlan {
        let digest = persistent_file_digest(id, kind, magic, version, bytes, &ids);
        TurboVecPersistentIndexFilePlan {
            file_id: id.to_string(),
            file_kind: kind,
            logical_path: format!("app_cold_store/turbovec/eidos/{id}.logical"),
            temp_path: format!("app_cold_store/turbovec/eidos/{id}.tmp"),
            final_path: format!(
                "app_cold_store/turbovec/eidos/sha256-{}/{}",
                digest.trim_start_matches("sha256:"),
                if matches!(
                    kind,
                    TurboVecPersistentFileKind::IdMapTvim | TurboVecPersistentFileKind::TempFile
                ) {
                    "index.tvim"
                } else {
                    "manifest.json"
                }
            ),
            expected_magic: magic.to_string(),
            format_version: version,
            manifest_digest: digest,
            planned_file_bytes: bytes,
            opened_file_bytes: 0,
            written_file_bytes: 0,
            loaded_index_bytes: 0,
            source_card_ref: "compressed_model_source_card:turbovec_eidos_cache".to_string(),
            app_cold_store_ref: format!("app_cold_store:turbovec:eidos:{id}"),
            stable_external_ids: ids,
            duplicate_external_id_present: false,
            path_is_content_addressed: true,
            temp_write_required: true,
            fsync_file_required: true,
            fsync_parent_dir_required: true,
            atomic_rename_required: true,
            previous_manifest_retained: true,
        }
    }

    fn accepted_scenarios() -> Vec<TurboVecPersistenceFailureScenario> {
        use TurboVecPersistenceFailureKind as F;
        use TurboVecPersistenceRecoveryDecision as R;
        vec![
            scenario(
                "clean_commit",
                F::CleanCommit,
                R::AcceptNewManifest,
                false,
                true,
                false,
                true,
            ),
            scenario(
                "partial_write",
                F::PartialWrite,
                R::RollBackToPreviousManifest,
                true,
                true,
                false,
                false,
            ),
            scenario(
                "corrupt_magic",
                F::CorruptMagic,
                R::RebuildFromAppColdStore,
                true,
                true,
                true,
                false,
            ),
            scenario(
                "version_mismatch",
                F::VersionMismatch,
                R::RebuildFromAppColdStore,
                true,
                true,
                true,
                false,
            ),
            scenario(
                "digest_mismatch",
                F::DigestMismatch,
                R::RebuildFromAppColdStore,
                true,
                true,
                true,
                false,
            ),
            scenario(
                "duplicate_external_id",
                F::DuplicateExternalId,
                R::RebuildFromAppColdStore,
                true,
                true,
                true,
                false,
            ),
            scenario(
                "missing_source",
                F::MissingAppColdStoreSource,
                R::RefuseAndEmitAnswerPacket,
                false,
                true,
                false,
                false,
            ),
            scenario(
                "permission_denied",
                F::PermissionDenied,
                R::RollBackToPreviousManifest,
                true,
                true,
                false,
                false,
            ),
            scenario(
                "stale_pointer",
                F::StaleManifestPointer,
                R::RollBackToPreviousManifest,
                true,
                true,
                false,
                false,
            ),
        ]
    }

    fn scenario(
        id: &str,
        failure: TurboVecPersistenceFailureKind,
        recovery: TurboVecPersistenceRecoveryDecision,
        corrupt: bool,
        old_usable: bool,
        rebuild: bool,
        promoted: bool,
    ) -> TurboVecPersistenceFailureScenario {
        TurboVecPersistenceFailureScenario {
            scenario_id: id.to_string(),
            failure_kind: failure,
            recovery_decision: recovery,
            corrupt_index_detected: corrupt,
            old_manifest_still_usable: old_usable,
            rebuild_from_app_cold_store: rebuild,
            new_manifest_promoted: promoted,
            quarantine_ref: format!("quarantine:turbovec:{id}"),
            rollback_ref: format!("rollback:turbovec_persist:{id}"),
            run_event_log_ref: format!("run_event_log:turbovec_persist:{id}"),
            answer_packet_ref: format!("answer_packet:turbovec_persist:{id}"),
        }
    }

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_filter_before_rank_privacy_gate_plan".to_string()),
            b"upstream-privacy-gate",
            CREATED_AT_MS,
        )
    }
}
