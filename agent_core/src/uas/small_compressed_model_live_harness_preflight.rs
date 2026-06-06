//! Small compressed-model live-harness preflight.
//!
//! This primitive turns compressed-route dry-run packets into a constrained
//! owner-approval lease for the first tiny compressed-model runtime probe. It
//! is metadata-only: no model/runtime bytes are opened, resident, or loaded.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, QatRouteRuntimeLane, UasAddress, UasKind};

pub const SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_CURSOR: &str =
    "small_compressed_model_live_harness_preflight";
pub const SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_NEXT_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe";

const UPSTREAM_PACKET_SET_PREFIX: &str = "artifact:compressed_route_answer_packet_dry_run:";
const UPSTREAM_PACKET_PREFIX: &str = "answer_packet:compressed_route_dry_run:";
const SOURCE_CARD_PREFIX: &str = "source:";
const RUNTIME_DOC_PREFIX: &str = "source:web:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:";
const COMMAND_LEDGER_PREFIX: &str = "command_ledger:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const CANCELLATION_PREFIX: &str = "cancel:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:";
const BLOCKED_LANE_PREFIX: &str = "blocked_lane:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CANDIDATE_METADATA_BYTES: u64 = 96 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 128;

// UAS: uas:small-compressed-model-live-harness-preflight:admission
// Plane: Controller + Verification
// Residency: metadata-only approval state before any runtime probe.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedHarnessAdmission {
    ReadyForOwnerApproval,
    AlternateDeferred,
    BlockedLoaderCaveat,
    RejectedUnsafe,
}

// UAS: uas:small-compressed-model-live-harness-preflight:tier
// Plane: Verification
// Residency: preflight permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedHarnessPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:small-compressed-model-live-harness-preflight:byte-plan
// Plane: Verification
// Residency: planned probe byte ceilings; all live-byte counters stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedHarnessBytePlan {
    pub declared_file_bytes: u64,
    pub planned_model_bytes: u64,
    pub planned_kv_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub planned_route_bytes: u64,
    pub max_context_tokens: u64,
    pub retained_token_budget: u64,
    pub timeout_ms: u64,
    pub cancellation_deadline_ms: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub metadata_bytes_read: u64,
}

impl SmallCompressedHarnessBytePlan {
    pub fn metadata_only(
        declared_file_bytes: u64,
        planned_model_bytes: u64,
        planned_kv_bytes: u64,
        planned_scratch_bytes: u64,
        max_context_tokens: u64,
        retained_token_budget: u64,
        timeout_ms: u64,
        cancellation_deadline_ms: u64,
        metadata_bytes_read: u64,
    ) -> Self {
        let planned_route_bytes = planned_model_bytes
            .saturating_add(planned_kv_bytes)
            .saturating_add(planned_scratch_bytes);
        Self {
            declared_file_bytes,
            planned_model_bytes,
            planned_kv_bytes,
            planned_scratch_bytes,
            planned_route_bytes,
            max_context_tokens,
            retained_token_budget,
            timeout_ms,
            cancellation_deadline_ms,
            opened_model_bytes: 0,
            opened_runtime_bytes: 0,
            resident_model_bytes: 0,
            resident_runtime_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            metadata_bytes_read,
        }
    }
}

// UAS: uas:small-compressed-model-live-harness-preflight:proof-refs
// Plane: Verification
// Residency: proof handles required before any owner-approved runtime probe.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedHarnessProofRefs {
    pub upstream_packet_ref: String,
    pub source_card_ref: String,
    pub runtime_doc_ref: String,
    pub owner_approval_ref: String,
    pub command_ledger_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub memory_ledger_ref: String,
    pub compatibility_fence_ref: String,
    pub route_caveat_ref: String,
    pub blocked_lane_refs: Vec<String>,
}

// UAS: uas:small-compressed-model-live-harness-preflight:candidate
// Plane: Controller + Verification
// Residency: metadata-only candidate lease; no live execution.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelLiveHarnessPreflightCandidate {
    pub candidate_id: String,
    pub model_id: String,
    pub runtime_lane: QatRouteRuntimeLane,
    pub admission: SmallCompressedHarnessAdmission,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: SmallCompressedHarnessPromotionTier,
    pub selected_for_probe: bool,
    pub fallback_order: u64,
    pub bytes: SmallCompressedHarnessBytePlan,
    pub refs: SmallCompressedHarnessProofRefs,
    pub user_visible_summary: String,
    pub selected_model_visible: bool,
    pub rejected_candidates_visible: bool,
    pub runtime_lane_visible: bool,
    pub byte_plan_visible: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub runtime_probe_deferred: bool,
    pub live_execution_performed: bool,
    pub first_token_claimed: bool,
    pub retained_token_digest_recorded: bool,
    pub quality_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub cancellation_required: bool,
    pub route_policy_mutated: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:small-compressed-model-live-harness-preflight:set
// Plane: Controller + Verification
// Residency: metadata-only lease set for a future owner-approved probe.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelLiveHarnessPreflightSet {
    pub set_address: UasAddress,
    pub upstream_packet_set_address: UasAddress,
    pub upstream_packet_witness_ref: String,
    pub selected_candidate_id: String,
    pub candidates: Vec<SmallCompressedModelLiveHarnessPreflightCandidate>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub mlx_swift_loader_caveat_visible: bool,
    pub litert_requires_later_package_proof: bool,
}

// UAS: uas:small-compressed-model-live-harness-preflight:metrics
// Plane: Verification
// Residency: derived preflight counts and byte totals.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedHarnessPreflightMetrics {
    pub candidate_count: u64,
    pub selected_count: u64,
    pub runtime_lane_count: u64,
    pub admission_count: u64,
    pub planned_route_bytes_total: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub metadata_bytes_read: u64,
}

impl SmallCompressedModelLiveHarnessPreflightSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_packet_set(
        upstream_packet_set_address: UasAddress,
        upstream_packet_witness_ref: impl Into<String>,
        selected_candidate_id: impl Into<String>,
        mut candidates: Vec<SmallCompressedModelLiveHarnessPreflightCandidate>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        mlx_swift_loader_caveat_visible: bool,
        litert_requires_later_package_proof: bool,
        created_at_ms: u64,
    ) -> Result<Self, SmallCompressedHarnessPreflightError> {
        candidates.sort_by(|a, b| a.candidate_id.cmp(&b.candidate_id));
        let witness_ref = upstream_packet_witness_ref.into();
        let selected_candidate_id = selected_candidate_id.into();
        validate_set_inputs(
            &upstream_packet_set_address,
            &witness_ref,
            &selected_candidate_id,
            &candidates,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            mlx_swift_loader_caveat_visible,
            litert_requires_later_package_proof,
        )?;
        let preimage = preflight_set_preimage(
            &upstream_packet_set_address,
            &witness_ref,
            &selected_candidate_id,
            &candidates,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            mlx_swift_loader_caveat_visible,
            litert_requires_later_package_proof,
        );
        let set_address = UasAddress::new(
            UasKind::Other(SMALL_COMPRESSED_MODEL_LIVE_HARNESS_PREFLIGHT_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_packet_set_address,
            upstream_packet_witness_ref: witness_ref,
            selected_candidate_id,
            candidates,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            mlx_swift_loader_caveat_visible,
            litert_requires_later_package_proof,
        })
    }

    pub fn metrics(&self) -> SmallCompressedHarnessPreflightMetrics {
        let mut runtime_lanes = BTreeSet::new();
        let mut admissions = BTreeSet::new();
        let mut selected_count = 0;
        let mut planned_route_bytes_total = 0;
        let mut opened_model_bytes = 0;
        let mut opened_runtime_bytes = 0;
        let mut resident_model_bytes = 0;
        let mut resident_runtime_bytes = 0;
        let mut model_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut provider_calls_made = 0;
        let mut metadata_bytes_read = self.metadata_bytes;

        for candidate in &self.candidates {
            runtime_lanes.insert(candidate.runtime_lane);
            admissions.insert(candidate.admission);
            if candidate.selected_for_probe {
                selected_count += 1;
            }
            planned_route_bytes_total += candidate.bytes.planned_route_bytes;
            opened_model_bytes += candidate.bytes.opened_model_bytes;
            opened_runtime_bytes += candidate.bytes.opened_runtime_bytes;
            resident_model_bytes += candidate.bytes.resident_model_bytes;
            resident_runtime_bytes += candidate.bytes.resident_runtime_bytes;
            model_bytes_loaded += candidate.bytes.model_bytes_loaded;
            runtime_bytes_loaded += candidate.bytes.runtime_bytes_loaded;
            provider_calls_made += candidate.bytes.provider_calls_made;
            metadata_bytes_read += candidate.bytes.metadata_bytes_read;
        }

        SmallCompressedHarnessPreflightMetrics {
            candidate_count: self.candidates.len() as u64,
            selected_count,
            runtime_lane_count: runtime_lanes.len() as u64,
            admission_count: admissions.len() as u64,
            planned_route_bytes_total,
            opened_model_bytes,
            opened_runtime_bytes,
            resident_model_bytes,
            resident_runtime_bytes,
            model_bytes_loaded,
            runtime_bytes_loaded,
            provider_calls_made,
            metadata_bytes_read,
        }
    }
}

// UAS: uas:small-compressed-model-live-harness-preflight:error
// Plane: Verification
// Residency: fail-closed validation for the pre-runtime harness lease.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SmallCompressedHarnessPreflightError {
    MissingUpstreamPacketSet,
    MissingUpstreamWitness,
    EmptySelectedCandidate,
    EmptyCandidates,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicateCandidateId(String),
    DuplicateModelRuntime {
        model_id: String,
        lane: QatRouteRuntimeLane,
    },
    EmptyField {
        candidate_id: String,
        field: &'static str,
    },
    BadPrefix {
        candidate_id: String,
        field: &'static str,
        expected: &'static str,
    },
    MissingBlockedLaneRef(String),
    MissingVisibility(String),
    BadProductBuild(String),
    BadProStatus(String),
    BadPromotionTier(String),
    InvalidBytePlan {
        candidate_id: String,
        reason: &'static str,
    },
    ByteLoadAttempt(String),
    RuntimeAttempt(String),
    ProductPromotionAttempt(String),
    HiddenAuthority(String),
    AdmissionContradiction {
        candidate_id: String,
        reason: &'static str,
    },
    SelectedCandidateMissing(String),
    SelectedCandidateUnsafe(String),
    SetPromotionAllowed,
    MlxSwiftCaveatMissing,
    LiteRtProofMissing,
}

impl fmt::Display for SmallCompressedHarnessPreflightError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamPacketSet => write!(f, "missing upstream packet set address"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream packet witness"),
            Self::EmptySelectedCandidate => write!(f, "missing selected candidate id"),
            Self::EmptyCandidates => {
                write!(f, "small compressed harness preflight requires candidates")
            }
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicateCandidateId(id) => write!(f, "duplicate preflight candidate `{id}`"),
            Self::DuplicateModelRuntime { model_id, lane } => {
                write!(f, "duplicate candidate for `{model_id}` on lane `{lane:?}`")
            }
            Self::EmptyField {
                candidate_id,
                field,
            } => write!(f, "candidate `{candidate_id}` has empty `{field}`"),
            Self::BadPrefix {
                candidate_id,
                field,
                expected,
            } => write!(
                f,
                "candidate `{candidate_id}` field `{field}` must start with `{expected}`"
            ),
            Self::MissingBlockedLaneRef(id) => {
                write!(f, "candidate `{id}` missing blocked-lane refs")
            }
            Self::MissingVisibility(id) => write!(f, "candidate `{id}` missing visible proof"),
            Self::BadProductBuild(id) => write!(f, "candidate `{id}` cannot promote to MAS"),
            Self::BadProStatus(id) => write!(f, "candidate `{id}` has forbidden Pro status"),
            Self::BadPromotionTier(id) => write!(f, "candidate `{id}` cannot promote beyond T1"),
            Self::InvalidBytePlan {
                candidate_id,
                reason,
            } => write!(f, "candidate `{candidate_id}` invalid byte plan: {reason}"),
            Self::ByteLoadAttempt(id) => write!(f, "candidate `{id}` attempted byte/provider use"),
            Self::RuntimeAttempt(id) => write!(f, "candidate `{id}` attempted live runtime"),
            Self::ProductPromotionAttempt(id) => {
                write!(f, "candidate `{id}` attempted product promotion")
            }
            Self::HiddenAuthority(id) => write!(f, "candidate `{id}` enabled hidden authority"),
            Self::AdmissionContradiction {
                candidate_id,
                reason,
            } => write!(
                f,
                "candidate `{candidate_id}` admission contradiction: {reason}"
            ),
            Self::SelectedCandidateMissing(id) => {
                write!(f, "selected candidate `{id}` missing from preflight set")
            }
            Self::SelectedCandidateUnsafe(id) => {
                write!(
                    f,
                    "selected candidate `{id}` is not the safe tiny GGUF candidate"
                )
            }
            Self::SetPromotionAllowed => {
                write!(
                    f,
                    "small compressed harness preflight tried to promote product truth"
                )
            }
            Self::MlxSwiftCaveatMissing => write!(f, "MLX Swift loader caveat missing"),
            Self::LiteRtProofMissing => write!(f, "LiteRT package proof requirement missing"),
        }
    }
}

impl std::error::Error for SmallCompressedHarnessPreflightError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_packet_set_address: &UasAddress,
    upstream_packet_witness_ref: &str,
    selected_candidate_id: &str,
    candidates: &[SmallCompressedModelLiveHarnessPreflightCandidate],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    mlx_swift_loader_caveat_visible: bool,
    litert_requires_later_package_proof: bool,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    if upstream_packet_set_address.to_string().trim().is_empty() {
        return Err(SmallCompressedHarnessPreflightError::MissingUpstreamPacketSet);
    }
    if upstream_packet_witness_ref.trim().is_empty() {
        return Err(SmallCompressedHarnessPreflightError::MissingUpstreamWitness);
    }
    if !upstream_packet_witness_ref.starts_with(UPSTREAM_PACKET_SET_PREFIX) {
        return Err(SmallCompressedHarnessPreflightError::BadPrefix {
            candidate_id: "set".to_string(),
            field: "upstream_packet_witness_ref",
            expected: UPSTREAM_PACKET_SET_PREFIX,
        });
    }
    if selected_candidate_id.trim().is_empty() {
        return Err(SmallCompressedHarnessPreflightError::EmptySelectedCandidate);
    }
    if candidates.is_empty() {
        return Err(SmallCompressedHarnessPreflightError::EmptyCandidates);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(
            SmallCompressedHarnessPreflightError::MetadataBudgetExceeded {
                bytes: metadata_bytes,
                max_bytes: MAX_SET_METADATA_BYTES,
            },
        );
    }
    if product_build != &ProductBuild::Pro
        || matches!(pro_status, ProStatus::Live | ProStatus::Omega)
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(SmallCompressedHarnessPreflightError::SetPromotionAllowed);
    }
    if !mlx_swift_loader_caveat_visible {
        return Err(SmallCompressedHarnessPreflightError::MlxSwiftCaveatMissing);
    }
    if !litert_requires_later_package_proof {
        return Err(SmallCompressedHarnessPreflightError::LiteRtProofMissing);
    }

    let mut candidate_ids = HashSet::new();
    let mut model_lanes = HashSet::new();
    let mut selected_candidate = None;
    for candidate in candidates {
        validate_candidate(candidate)?;
        if !candidate_ids.insert(candidate.candidate_id.clone()) {
            return Err(SmallCompressedHarnessPreflightError::DuplicateCandidateId(
                candidate.candidate_id.clone(),
            ));
        }
        let model_lane = (candidate.model_id.clone(), candidate.runtime_lane);
        if !model_lanes.insert(model_lane.clone()) {
            return Err(
                SmallCompressedHarnessPreflightError::DuplicateModelRuntime {
                    model_id: model_lane.0,
                    lane: model_lane.1,
                },
            );
        }
        if candidate.candidate_id == selected_candidate_id {
            selected_candidate = Some(candidate);
        }
    }

    let selected = selected_candidate.ok_or_else(|| {
        SmallCompressedHarnessPreflightError::SelectedCandidateMissing(
            selected_candidate_id.to_string(),
        )
    })?;
    if !selected.selected_for_probe
        || selected.admission != SmallCompressedHarnessAdmission::ReadyForOwnerApproval
        || selected.runtime_lane != QatRouteRuntimeLane::GgufLlamaCpp
        || !selected.model_id.contains("-E2B-")
        || selected.fallback_order != 1
    {
        return Err(
            SmallCompressedHarnessPreflightError::SelectedCandidateUnsafe(
                selected_candidate_id.to_string(),
            ),
        );
    }
    Ok(())
}

fn validate_candidate(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    require_nonempty(
        &candidate.candidate_id,
        &candidate.candidate_id,
        "candidate_id",
    )?;
    require_nonempty(&candidate.model_id, &candidate.candidate_id, "model_id")?;
    require_nonempty(
        &candidate.user_visible_summary,
        &candidate.candidate_id,
        "user_visible_summary",
    )?;
    if candidate.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(SmallCompressedHarnessPreflightError::MissingVisibility(
            candidate.candidate_id.clone(),
        ));
    }
    validate_refs(candidate)?;
    validate_product(candidate)?;
    validate_byte_plan(candidate)?;
    validate_admission(candidate)?;
    validate_visibility(candidate)?;
    validate_no_runtime_or_promotion(candidate)?;
    Ok(())
}

fn validate_refs(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    let refs = &candidate.refs;
    require_prefix(
        &refs.upstream_packet_ref,
        &candidate.candidate_id,
        "upstream_packet_ref",
        UPSTREAM_PACKET_PREFIX,
    )?;
    require_prefix(
        &refs.source_card_ref,
        &candidate.candidate_id,
        "source_card_ref",
        SOURCE_CARD_PREFIX,
    )?;
    require_prefix(
        &refs.runtime_doc_ref,
        &candidate.candidate_id,
        "runtime_doc_ref",
        RUNTIME_DOC_PREFIX,
    )?;
    require_prefix(
        &refs.owner_approval_ref,
        &candidate.candidate_id,
        "owner_approval_ref",
        OWNER_APPROVAL_PREFIX,
    )?;
    require_prefix(
        &refs.command_ledger_ref,
        &candidate.candidate_id,
        "command_ledger_ref",
        COMMAND_LEDGER_PREFIX,
    )?;
    require_prefix(
        &refs.answer_packet_ref,
        &candidate.candidate_id,
        "answer_packet_ref",
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        &refs.run_event_log_ref,
        &candidate.candidate_id,
        "run_event_log_ref",
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        &refs.rollback_ref,
        &candidate.candidate_id,
        "rollback_ref",
        ROLLBACK_PREFIX,
    )?;
    require_prefix(
        &refs.cancellation_ref,
        &candidate.candidate_id,
        "cancellation_ref",
        CANCELLATION_PREFIX,
    )?;
    require_prefix(
        &refs.memory_ledger_ref,
        &candidate.candidate_id,
        "memory_ledger_ref",
        MEMORY_LEDGER_PREFIX,
    )?;
    require_prefix(
        &refs.compatibility_fence_ref,
        &candidate.candidate_id,
        "compatibility_fence_ref",
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    require_prefix(
        &refs.route_caveat_ref,
        &candidate.candidate_id,
        "route_caveat_ref",
        ROUTE_CAVEAT_PREFIX,
    )?;
    if refs.blocked_lane_refs.is_empty() {
        return Err(SmallCompressedHarnessPreflightError::MissingBlockedLaneRef(
            candidate.candidate_id.clone(),
        ));
    }
    for blocked in &refs.blocked_lane_refs {
        require_prefix(
            blocked,
            &candidate.candidate_id,
            "blocked_lane_refs",
            BLOCKED_LANE_PREFIX,
        )?;
    }
    Ok(())
}

fn validate_product(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    if candidate.product_build != ProductBuild::Pro {
        return Err(SmallCompressedHarnessPreflightError::BadProductBuild(
            candidate.candidate_id.clone(),
        ));
    }
    if matches!(candidate.pro_status, ProStatus::Live | ProStatus::Omega) {
        return Err(SmallCompressedHarnessPreflightError::BadProStatus(
            candidate.candidate_id.clone(),
        ));
    }
    if matches!(
        candidate.promotion_tier,
        SmallCompressedHarnessPromotionTier::T2L2Route
            | SmallCompressedHarnessPromotionTier::T3L3Wrv
            | SmallCompressedHarnessPromotionTier::T4BuildGreen
            | SmallCompressedHarnessPromotionTier::T5FullSegment
    ) {
        return Err(SmallCompressedHarnessPreflightError::BadPromotionTier(
            candidate.candidate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_plan(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    let bytes = &candidate.bytes;
    if bytes.declared_file_bytes == 0
        || bytes.planned_model_bytes == 0
        || bytes.planned_kv_bytes == 0
        || bytes.planned_scratch_bytes == 0
        || bytes.max_context_tokens == 0
        || bytes.retained_token_budget != 1
        || bytes.timeout_ms == 0
        || bytes.cancellation_deadline_ms == 0
    {
        return Err(invalid_bytes(
            candidate,
            "declared/planned/context/token/timeout bytes must be nonzero and token budget must be one",
        ));
    }
    if bytes.cancellation_deadline_ms > bytes.timeout_ms {
        return Err(invalid_bytes(
            candidate,
            "cancellation deadline must not exceed timeout",
        ));
    }
    if bytes.planned_model_bytes <= bytes.declared_file_bytes {
        return Err(invalid_bytes(
            candidate,
            "planned model bytes must exceed declared file bytes",
        ));
    }
    let expected_route_bytes = bytes
        .planned_model_bytes
        .checked_add(bytes.planned_kv_bytes)
        .and_then(|value| value.checked_add(bytes.planned_scratch_bytes))
        .ok_or_else(|| invalid_bytes(candidate, "planned route bytes overflowed"))?;
    if bytes.planned_route_bytes != expected_route_bytes {
        return Err(invalid_bytes(
            candidate,
            "planned_route_bytes must equal model + kv + scratch",
        ));
    }
    if bytes.opened_model_bytes != 0
        || bytes.opened_runtime_bytes != 0
        || bytes.resident_model_bytes != 0
        || bytes.resident_runtime_bytes != 0
        || bytes.model_bytes_loaded != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.provider_calls_made != 0
    {
        return Err(SmallCompressedHarnessPreflightError::ByteLoadAttempt(
            candidate.candidate_id.clone(),
        ));
    }
    if bytes.metadata_bytes_read > MAX_CANDIDATE_METADATA_BYTES {
        return Err(
            SmallCompressedHarnessPreflightError::MetadataBudgetExceeded {
                bytes: bytes.metadata_bytes_read,
                max_bytes: MAX_CANDIDATE_METADATA_BYTES,
            },
        );
    }
    Ok(())
}

fn validate_admission(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    match candidate.admission {
        SmallCompressedHarnessAdmission::ReadyForOwnerApproval => {
            if !candidate.selected_for_probe || candidate.fallback_order != 1 {
                return Err(admission_error(
                    candidate,
                    "ready candidate must be selected with fallback order one",
                ));
            }
            if candidate.runtime_lane != QatRouteRuntimeLane::GgufLlamaCpp {
                return Err(admission_error(
                    candidate,
                    "ready candidate must use GGUF/llama.cpp lane",
                ));
            }
            if !candidate.model_id.contains("-E2B-") {
                return Err(admission_error(
                    candidate,
                    "only E2B can be selected for the first tiny probe",
                ));
            }
        }
        SmallCompressedHarnessAdmission::AlternateDeferred => {
            if candidate.selected_for_probe || candidate.fallback_order <= 1 {
                return Err(admission_error(
                    candidate,
                    "alternate must be deferred and ordered after primary",
                ));
            }
        }
        SmallCompressedHarnessAdmission::BlockedLoaderCaveat => {
            if candidate.selected_for_probe {
                return Err(admission_error(
                    candidate,
                    "blocked lane cannot be selected",
                ));
            }
        }
        SmallCompressedHarnessAdmission::RejectedUnsafe => {
            if candidate.selected_for_probe {
                return Err(admission_error(candidate, "unsafe lane cannot be selected"));
            }
        }
    }
    if candidate.model_id.contains("-12B-") || candidate.model_id.contains("-31B-") {
        return Err(admission_error(
            candidate,
            "12B and 31B cannot enter this first small harness preflight",
        ));
    }
    Ok(())
}

fn validate_visibility(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    if !candidate.selected_model_visible
        || !candidate.rejected_candidates_visible
        || !candidate.runtime_lane_visible
        || !candidate.byte_plan_visible
        || !candidate.answer_packet_required
        || !candidate.run_event_log_required
        || !candidate.rollback_required
        || !candidate.cancellation_required
    {
        return Err(SmallCompressedHarnessPreflightError::MissingVisibility(
            candidate.candidate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_no_runtime_or_promotion(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    if !candidate.owner_approval_required
        || candidate.owner_approval_granted
        || !candidate.runtime_probe_deferred
        || candidate.live_execution_performed
    {
        return Err(SmallCompressedHarnessPreflightError::RuntimeAttempt(
            candidate.candidate_id.clone(),
        ));
    }
    if candidate.first_token_claimed || candidate.retained_token_digest_recorded {
        return Err(SmallCompressedHarnessPreflightError::RuntimeAttempt(
            candidate.candidate_id.clone(),
        ));
    }
    if candidate.quality_claimed
        || candidate.l2_capability_claimed
        || candidate.l3_wrv_claimed
        || candidate.mas_readiness_claimed
    {
        return Err(
            SmallCompressedHarnessPreflightError::ProductPromotionAttempt(
                candidate.candidate_id.clone(),
            ),
        );
    }
    if candidate.route_policy_mutated
        || candidate.hidden_cloud_fallback_allowed
        || candidate.hidden_route_authority_allowed
        || candidate.live_dense_70b_claimed
        || candidate.ssd_as_ram_claimed
    {
        return Err(SmallCompressedHarnessPreflightError::HiddenAuthority(
            candidate.candidate_id.clone(),
        ));
    }
    Ok(())
}

fn invalid_bytes(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
    reason: &'static str,
) -> SmallCompressedHarnessPreflightError {
    SmallCompressedHarnessPreflightError::InvalidBytePlan {
        candidate_id: candidate.candidate_id.clone(),
        reason,
    }
}

fn admission_error(
    candidate: &SmallCompressedModelLiveHarnessPreflightCandidate,
    reason: &'static str,
) -> SmallCompressedHarnessPreflightError {
    SmallCompressedHarnessPreflightError::AdmissionContradiction {
        candidate_id: candidate.candidate_id.clone(),
        reason,
    }
}

fn require_nonempty(
    value: &str,
    candidate_id: &str,
    field: &'static str,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    if value.trim().is_empty() {
        return Err(SmallCompressedHarnessPreflightError::EmptyField {
            candidate_id: candidate_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    candidate_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), SmallCompressedHarnessPreflightError> {
    if !value.starts_with(expected) {
        return Err(SmallCompressedHarnessPreflightError::BadPrefix {
            candidate_id: candidate_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn preflight_set_preimage(
    upstream_packet_set_address: &UasAddress,
    upstream_packet_witness_ref: &str,
    selected_candidate_id: &str,
    candidates: &[SmallCompressedModelLiveHarnessPreflightCandidate],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    mlx_swift_loader_caveat_visible: bool,
    litert_requires_later_package_proof: bool,
) -> String {
    let mut preimage = format!(
        "small_compressed_model_live_harness_preflight_v1\n{}\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n",
        upstream_packet_set_address,
        upstream_packet_witness_ref,
        selected_candidate_id,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        mlx_swift_loader_caveat_visible,
        litert_requires_later_package_proof
    );
    for candidate in candidates {
        preimage.push_str(&format!(
            "{}\n{}\n{:?}\n{:?}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            candidate.candidate_id,
            candidate.model_id,
            candidate.runtime_lane,
            candidate.admission,
            product_build_preimage(&candidate.product_build),
            candidate.pro_status,
            candidate.promotion_tier,
            candidate.selected_for_probe,
            candidate.fallback_order,
            candidate.bytes.declared_file_bytes,
            candidate.bytes.planned_model_bytes,
            candidate.bytes.planned_kv_bytes,
            candidate.bytes.planned_scratch_bytes,
            candidate.bytes.planned_route_bytes,
            candidate.bytes.max_context_tokens,
            candidate.bytes.retained_token_budget,
            candidate.bytes.timeout_ms,
            candidate.bytes.cancellation_deadline_ms,
            candidate.bytes.opened_model_bytes,
            candidate.bytes.opened_runtime_bytes,
            candidate.bytes.resident_model_bytes,
            candidate.bytes.resident_runtime_bytes,
            candidate.bytes.model_bytes_loaded,
            candidate.bytes.runtime_bytes_loaded,
            candidate.bytes.provider_calls_made,
            candidate.bytes.metadata_bytes_read,
            candidate.refs.upstream_packet_ref,
            candidate.refs.source_card_ref,
            candidate.refs.runtime_doc_ref,
            candidate.refs.owner_approval_ref,
            candidate.refs.command_ledger_ref,
            candidate.refs.answer_packet_ref,
            candidate.refs.run_event_log_ref,
            candidate.refs.rollback_ref,
            candidate.refs.cancellation_ref,
            candidate.refs.memory_ledger_ref,
            candidate.refs.compatibility_fence_ref,
            candidate.refs.route_caveat_ref,
            candidate.refs.blocked_lane_refs.join(","),
            candidate.selected_model_visible,
            candidate.rejected_candidates_visible,
            candidate.runtime_lane_visible,
            candidate.byte_plan_visible,
            candidate.owner_approval_required,
            candidate.owner_approval_granted,
            candidate.runtime_probe_deferred,
            candidate.live_execution_performed,
            candidate.answer_packet_required,
            candidate.run_event_log_required,
            candidate.user_visible_summary
        ));
    }
    preimage
}

fn product_build_preimage(product_build: &ProductBuild) -> &'static str {
    match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_034_900_000;
    const GIB: u64 = 1_073_741_824;
    const MIB: u64 = 1_048_576;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("compressed_route_answer_packet_dry_run".to_string()),
            b"small-compressed-preflight-upstream",
            CREATED_AT_MS,
        )
    }

    fn refs(id: &str) -> SmallCompressedHarnessProofRefs {
        SmallCompressedHarnessProofRefs {
            upstream_packet_ref: format!("answer_packet:compressed_route_dry_run:{id}"),
            source_card_ref: format!("source:model:{id}"),
            runtime_doc_ref: "source:web:google_gemma4_qat_gguf_llamacpp".to_string(),
            owner_approval_ref: format!("owner_approval:pending:{id}"),
            command_ledger_ref: format!("command_ledger:small_compressed_preflight:{id}"),
            answer_packet_ref: format!("answer_packet:small_compressed_preflight:{id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_preflight:{id}"),
            rollback_ref: format!("rollback:small_compressed_preflight:{id}"),
            cancellation_ref: format!("cancel:small_compressed_preflight:{id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_preflight:{id}"),
            compatibility_fence_ref: format!("compat:small_compressed_preflight:{id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_preflight:{id}"),
            blocked_lane_refs: vec![
                "blocked_lane:mlx_swift_loader_unproven".to_string(),
                "blocked_lane:litert_package_proof_required".to_string(),
            ],
        }
    }

    fn candidate(
        id: &str,
        model_id: &str,
        admission: SmallCompressedHarnessAdmission,
        selected: bool,
        order: u64,
    ) -> SmallCompressedModelLiveHarnessPreflightCandidate {
        let planned_model_bytes = if model_id.contains("-E4B-") {
            8 * GIB
        } else {
            5 * GIB
        };
        let declared_file_bytes = if model_id.contains("-E4B-") {
            7_463_013_674
        } else {
            4_628_569_635
        };
        SmallCompressedModelLiveHarnessPreflightCandidate {
            candidate_id: id.to_string(),
            model_id: model_id.to_string(),
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            admission,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
            selected_for_probe: selected,
            fallback_order: order,
            bytes: SmallCompressedHarnessBytePlan::metadata_only(
                declared_file_bytes,
                planned_model_bytes,
                512 * MIB,
                256 * MIB,
                2048,
                1,
                120_000,
                5_000,
                24_000,
            ),
            refs: refs(id),
            user_visible_summary: format!(
                "{id} is a small compressed-model live-harness preflight candidate with visible owner approval, byte plan, runtime lane caveat, rollback, cancellation, RunEventLog, and AnswerPacket requirements; no live runtime is executed."
            ),
            selected_model_visible: true,
            rejected_candidates_visible: true,
            runtime_lane_visible: true,
            byte_plan_visible: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            runtime_probe_deferred: true,
            live_execution_performed: false,
            first_token_claimed: false,
            retained_token_digest_recorded: false,
            quality_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            mas_readiness_claimed: false,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            cancellation_required: true,
            route_policy_mutated: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn candidate_set(
        candidates: Vec<SmallCompressedModelLiveHarnessPreflightCandidate>,
    ) -> Result<SmallCompressedModelLiveHarnessPreflightSet, SmallCompressedHarnessPreflightError>
    {
        SmallCompressedModelLiveHarnessPreflightSet::from_packet_set(
            upstream_address(),
            "artifact:compressed_route_answer_packet_dry_run:result",
            "gemma4_e2b_qat_gguf_harness_preflight",
            candidates,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            64_000,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn valid_candidates() -> Vec<SmallCompressedModelLiveHarnessPreflightCandidate> {
        vec![
            candidate(
                "gemma4_e2b_qat_gguf_harness_preflight",
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                SmallCompressedHarnessAdmission::ReadyForOwnerApproval,
                true,
                1,
            ),
            candidate(
                "gemma4_e4b_qat_gguf_harness_alternate",
                "google/gemma-4-E4B-it-qat-q4_0-gguf",
                SmallCompressedHarnessAdmission::AlternateDeferred,
                false,
                2,
            ),
        ]
    }

    #[test]
    fn accepts_smallest_visible_preflight() {
        let mut candidates = valid_candidates();
        let set = candidate_set(candidates.clone()).expect("preflight should validate");
        candidates.reverse();
        let reversed = candidate_set(candidates).expect("preflight should validate");
        assert_eq!(set.set_address, reversed.set_address);
        assert_eq!(set.metrics().selected_count, 1);
        assert_eq!(set.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_e4b_or_mlx_as_selected_primary() {
        let mut candidates = valid_candidates();
        candidates[0].selected_for_probe = false;
        candidates[0].admission = SmallCompressedHarnessAdmission::AlternateDeferred;
        candidates[0].fallback_order = 2;
        candidates[1].selected_for_probe = true;
        candidates[1].admission = SmallCompressedHarnessAdmission::ReadyForOwnerApproval;
        candidates[1].fallback_order = 1;
        assert!(candidate_set(candidates).is_err());

        let mut candidates = valid_candidates();
        candidates[0].runtime_lane = QatRouteRuntimeLane::MlxSwiftCandidate;
        assert!(candidate_set(candidates).is_err());
    }

    #[test]
    fn rejects_owner_approval_or_live_runtime_in_preflight() {
        let mut candidates = valid_candidates();
        candidates[0].owner_approval_granted = true;
        assert!(candidate_set(candidates.clone()).is_err());
        candidates[0].owner_approval_granted = false;
        candidates[0].live_execution_performed = true;
        assert!(candidate_set(candidates.clone()).is_err());
        candidates[0].live_execution_performed = false;
        candidates[0].first_token_claimed = true;
        assert!(candidate_set(candidates).is_err());
    }

    #[test]
    fn rejects_loaded_bytes_and_provider_calls() {
        let mut candidates = valid_candidates();
        candidates[0].bytes.opened_model_bytes = 1;
        assert!(candidate_set(candidates.clone()).is_err());
        candidates[0].bytes.opened_model_bytes = 0;
        candidates[0].bytes.model_bytes_loaded = 1;
        assert!(candidate_set(candidates.clone()).is_err());
        candidates[0].bytes.model_bytes_loaded = 0;
        candidates[0].bytes.provider_calls_made = 1;
        assert!(candidate_set(candidates).is_err());
    }

    #[test]
    fn rejects_missing_visibility_and_hidden_authority() {
        let mut candidates = valid_candidates();
        candidates[0].answer_packet_required = false;
        assert!(candidate_set(candidates.clone()).is_err());
        candidates[0].answer_packet_required = true;
        candidates[0].hidden_cloud_fallback_allowed = true;
        assert!(candidate_set(candidates.clone()).is_err());
        candidates[0].hidden_cloud_fallback_allowed = false;
        candidates[0].l2_capability_claimed = true;
        assert!(candidate_set(candidates).is_err());
    }
}
