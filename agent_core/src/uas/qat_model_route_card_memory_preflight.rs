//! QAT model route-card memory preflight.
//!
//! This primitive turns source-backed Gemma QAT candidate cards into
//! metadata-only route cards. It decides whether a compressed local model may
//! proceed to a dry-run preflight on a declared Apple Silicon memory profile
//! without loading model bytes, starting a runtime, or promoting product truth.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const QAT_MODEL_ROUTE_CARD_MEMORY_PREFLIGHT_CURSOR: &str =
    "qat_model_route_card_memory_preflight";
pub const QAT_MODEL_ROUTE_CARD_MEMORY_PREFLIGHT_NEXT_CURSOR: &str =
    "compressed_route_answer_packet_dry_run";

const CANDIDATE_CARD_PREFIX: &str = "gemma_qat_candidate:";
const CANDIDATE_SET_ARTIFACT_PREFIX: &str = "artifact:gemma_qat_local_runtime_candidate_card:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const HARDWARE_PROFILE_PREFIX: &str = "hardware:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:";
const ABSTENTION_PREFIX: &str = "abstain:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_ROUTE_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:qat-route-preflight:runtime-lane
// Plane: Controller
// Residency: candidate lane only; no runtime is opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QatRouteRuntimeLane {
    GgufLlamaCpp,
    LiteRtLm,
    MlxSwiftCandidate,
    TransformersResearch,
    NoRuntime,
}

// UAS: uas:qat-route-preflight:admission
// Plane: Controller + Verification
// Residency: dry-run permission, abstention, or vault preservation.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QatRouteAdmission {
    AdmitForDryRun,
    AbstainInsufficientHeadroom,
    VaultOnly,
    BlockedMissingLoader,
    BlockedUnsupportedLane,
}

// UAS: uas:qat-route-preflight:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QatRoutePromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:qat-route-preflight:memory-budget
// Plane: Verification
// Residency: byte accounting for a proposed dry-run; all loaded bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct QatRouteMemoryBudget {
    pub declared_file_bytes: u64,
    pub predicted_resident_bytes: u64,
    pub predicted_kv_cache_bytes: u64,
    pub predicted_scratch_bytes: u64,
    pub total_predicted_route_bytes: u64,
    pub uma_budget_bytes: u64,
    pub reserved_system_bytes: u64,
    pub available_for_route_bytes: u64,
    pub headroom_bytes: i64,
    pub timeout_ms: u64,
    pub cancellation_deadline_ms: u64,
    pub metadata_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl QatRouteMemoryBudget {
    #[allow(clippy::too_many_arguments)]
    pub fn metadata_only(
        declared_file_bytes: u64,
        predicted_resident_bytes: u64,
        predicted_kv_cache_bytes: u64,
        predicted_scratch_bytes: u64,
        uma_budget_bytes: u64,
        reserved_system_bytes: u64,
        timeout_ms: u64,
        cancellation_deadline_ms: u64,
        metadata_bytes_read: u64,
    ) -> Self {
        let total_predicted_route_bytes = predicted_resident_bytes
            .saturating_add(predicted_kv_cache_bytes)
            .saturating_add(predicted_scratch_bytes);
        let available_for_route_bytes = uma_budget_bytes.saturating_sub(reserved_system_bytes);
        let headroom_bytes = available_for_route_bytes as i64 - total_predicted_route_bytes as i64;
        Self {
            declared_file_bytes,
            predicted_resident_bytes,
            predicted_kv_cache_bytes,
            predicted_scratch_bytes,
            total_predicted_route_bytes,
            uma_budget_bytes,
            reserved_system_bytes,
            available_for_route_bytes,
            headroom_bytes,
            timeout_ms,
            cancellation_deadline_ms,
            metadata_bytes_read,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }

    fn has_positive_headroom(&self) -> bool {
        self.headroom_bytes >= 0
    }
}

// UAS: uas:qat-route-preflight:proof-refs
// Plane: Verification
// Residency: visible proof handles required before any runtime attempt.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct QatRouteProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:qat-route-preflight:card
// Plane: State + Assembly + Controller + Verification
// Residency: route-card preflight only; no runtime or product route.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct QatModelRouteCardMemoryPreflight {
    pub route_card_id: String,
    pub upstream_candidate_card_ref: String,
    pub model_id: String,
    pub runtime_lane: QatRouteRuntimeLane,
    pub admission: QatRouteAdmission,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: QatRoutePromotionTier,
    pub hardware_profile_ref: String,
    pub route_caveat_ref: String,
    pub abstention_reason_ref: Option<String>,
    pub memory: QatRouteMemoryBudget,
    pub proof_refs: QatRouteProofRefs,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub file_size_treated_as_resident_memory: bool,
    pub first_token_claimed: bool,
    pub quality_claimed: bool,
    pub swift_mlx_loader_proven: bool,
    pub mtp_speedup_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
}

// UAS: uas:qat-route-preflight:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only route-card set for future dry-run witnesses.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct QatModelRouteCardMemoryPreflightSet {
    pub set_address: UasAddress,
    pub upstream_candidate_set_address: UasAddress,
    pub upstream_candidate_witness_ref: String,
    pub route_cards: Vec<QatModelRouteCardMemoryPreflight>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:qat-route-preflight:metrics
// Plane: Verification
// Residency: derived counts for the metadata-only preflight artifact.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct QatRoutePreflightMetrics {
    pub route_card_count: u64,
    pub runtime_lane_count: u64,
    pub admission_count: u64,
    pub dry_run_admission_count: u64,
    pub abstention_count: u64,
    pub vault_only_count: u64,
    pub blocked_count: u64,
    pub declared_file_bytes_total: u64,
    pub predicted_resident_bytes_total: u64,
    pub total_predicted_route_bytes: u64,
    pub admitted_total_predicted_route_bytes: u64,
    pub minimum_headroom_bytes: i64,
    pub metadata_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl QatModelRouteCardMemoryPreflightSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_candidate_set(
        upstream_candidate_set_address: UasAddress,
        upstream_candidate_witness_ref: impl Into<String>,
        mut route_cards: Vec<QatModelRouteCardMemoryPreflight>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, QatRoutePreflightError> {
        route_cards.sort_by(|a, b| a.route_card_id.cmp(&b.route_card_id));
        let witness_ref = upstream_candidate_witness_ref.into();
        validate_set_inputs(
            &upstream_candidate_set_address,
            &witness_ref,
            &route_cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = route_preflight_set_preimage(
            &upstream_candidate_set_address,
            &witness_ref,
            &route_cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(QAT_MODEL_ROUTE_CARD_MEMORY_PREFLIGHT_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_candidate_set_address,
            upstream_candidate_witness_ref: witness_ref,
            route_cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> QatRoutePreflightMetrics {
        let mut runtime_lanes = BTreeSet::new();
        let mut admissions = BTreeSet::new();
        let mut dry_run_admission_count = 0;
        let mut abstention_count = 0;
        let mut vault_only_count = 0;
        let mut blocked_count = 0;
        let mut declared_file_bytes_total = 0;
        let mut predicted_resident_bytes_total = 0;
        let mut total_predicted_route_bytes = 0;
        let mut admitted_total_predicted_route_bytes = 0;
        let mut minimum_headroom_bytes = i64::MAX;
        let mut metadata_bytes_read = self.metadata_bytes;
        let mut model_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut provider_calls_made = 0;

        for card in &self.route_cards {
            runtime_lanes.insert(card.runtime_lane);
            admissions.insert(card.admission);
            match card.admission {
                QatRouteAdmission::AdmitForDryRun => {
                    dry_run_admission_count += 1;
                    admitted_total_predicted_route_bytes += card.memory.total_predicted_route_bytes;
                }
                QatRouteAdmission::AbstainInsufficientHeadroom => abstention_count += 1,
                QatRouteAdmission::VaultOnly => vault_only_count += 1,
                QatRouteAdmission::BlockedMissingLoader
                | QatRouteAdmission::BlockedUnsupportedLane => blocked_count += 1,
            }
            declared_file_bytes_total += card.memory.declared_file_bytes;
            predicted_resident_bytes_total += card.memory.predicted_resident_bytes;
            total_predicted_route_bytes += card.memory.total_predicted_route_bytes;
            minimum_headroom_bytes = minimum_headroom_bytes.min(card.memory.headroom_bytes);
            metadata_bytes_read += card.memory.metadata_bytes_read;
            model_bytes_loaded += card.memory.model_bytes_loaded;
            runtime_bytes_loaded += card.memory.runtime_bytes_loaded;
            provider_calls_made += card.memory.provider_calls_made;
        }

        QatRoutePreflightMetrics {
            route_card_count: self.route_cards.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            admission_count: admissions.len() as u64,
            dry_run_admission_count,
            abstention_count,
            vault_only_count,
            blocked_count,
            declared_file_bytes_total,
            predicted_resident_bytes_total,
            total_predicted_route_bytes,
            admitted_total_predicted_route_bytes,
            minimum_headroom_bytes: if self.route_cards.is_empty() {
                0
            } else {
                minimum_headroom_bytes
            },
            metadata_bytes_read,
            model_bytes_loaded,
            runtime_bytes_loaded,
            provider_calls_made,
        }
    }
}

// UAS: uas:qat-route-preflight:error
// Plane: Verification
// Residency: fail-closed validation surface for route-card preflight.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum QatRoutePreflightError {
    MissingUpstreamCandidateSet,
    MissingUpstreamWitness,
    EmptyRouteCards,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicateRouteCardId(String),
    DuplicateModelRuntime {
        model_id: String,
        lane: QatRouteRuntimeLane,
    },
    EmptyField {
        route_card_id: String,
        field: &'static str,
    },
    BadPrefix {
        route_card_id: String,
        field: &'static str,
        expected: &'static str,
    },
    BadProductBuild {
        route_card_id: String,
    },
    BadProStatus {
        route_card_id: String,
    },
    BadPromotionTier {
        route_card_id: String,
    },
    MissingAbstentionReason {
        route_card_id: String,
    },
    MissingProofSurface {
        route_card_id: String,
    },
    RuntimeNotDeferred {
        route_card_id: String,
    },
    ProductPromotionAllowed {
        route_card_id: String,
    },
    HiddenAuthority {
        route_card_id: String,
    },
    ByteLoadAttempt {
        route_card_id: String,
    },
    InvalidMemoryBudget {
        route_card_id: String,
        reason: &'static str,
    },
    AdmissionContradiction {
        route_card_id: String,
        reason: &'static str,
    },
    SetPromotionAllowed,
}

impl fmt::Display for QatRoutePreflightError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamCandidateSet => write!(f, "missing upstream candidate set"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream candidate witness ref"),
            Self::EmptyRouteCards => write!(f, "QAT route preflight requires route cards"),
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicateRouteCardId(id) => write!(f, "duplicate QAT route-card id `{id}`"),
            Self::DuplicateModelRuntime { model_id, lane } => {
                write!(f, "duplicate route for `{model_id}` on lane `{lane:?}`")
            }
            Self::EmptyField {
                route_card_id,
                field,
            } => write!(f, "QAT route-card `{route_card_id}` has empty `{field}`"),
            Self::BadPrefix {
                route_card_id,
                field,
                expected,
            } => write!(
                f,
                "QAT route-card `{route_card_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadProductBuild { route_card_id } => {
                write!(f, "QAT route-card `{route_card_id}` cannot promote to MAS")
            }
            Self::BadProStatus { route_card_id } => {
                write!(
                    f,
                    "QAT route-card `{route_card_id}` has forbidden Pro status"
                )
            }
            Self::BadPromotionTier { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` cannot promote beyond T1"
            ),
            Self::MissingAbstentionReason { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` needs an abstention reason"
            ),
            Self::MissingProofSurface { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` is missing rollback/log/AnswerPacket proof"
            ),
            Self::RuntimeNotDeferred { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` tried to make runtime live"
            ),
            Self::ProductPromotionAllowed { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` tried to promote product truth"
            ),
            Self::HiddenAuthority { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` enabled hidden authority"
            ),
            Self::ByteLoadAttempt { route_card_id } => write!(
                f,
                "QAT route-card `{route_card_id}` attempted model/runtime/provider bytes"
            ),
            Self::InvalidMemoryBudget {
                route_card_id,
                reason,
            } => write!(
                f,
                "QAT route-card `{route_card_id}` invalid memory budget: {reason}"
            ),
            Self::AdmissionContradiction {
                route_card_id,
                reason,
            } => write!(
                f,
                "QAT route-card `{route_card_id}` admission contradiction: {reason}"
            ),
            Self::SetPromotionAllowed => write!(
                f,
                "QAT route preflight set tried to promote product/runtime truth"
            ),
        }
    }
}

impl std::error::Error for QatRoutePreflightError {}

fn validate_set_inputs(
    upstream_candidate_set_address: &UasAddress,
    upstream_candidate_witness_ref: &str,
    route_cards: &[QatModelRouteCardMemoryPreflight],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), QatRoutePreflightError> {
    if upstream_candidate_set_address.to_string().trim().is_empty() {
        return Err(QatRoutePreflightError::MissingUpstreamCandidateSet);
    }
    if upstream_candidate_witness_ref.trim().is_empty() {
        return Err(QatRoutePreflightError::MissingUpstreamWitness);
    }
    if !upstream_candidate_witness_ref.starts_with(CANDIDATE_SET_ARTIFACT_PREFIX) {
        return Err(QatRoutePreflightError::BadPrefix {
            route_card_id: "set".to_string(),
            field: "upstream_candidate_witness_ref",
            expected: CANDIDATE_SET_ARTIFACT_PREFIX,
        });
    }
    if route_cards.is_empty() {
        return Err(QatRoutePreflightError::EmptyRouteCards);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(QatRoutePreflightError::MetadataBudgetExceeded {
            bytes: metadata_bytes,
            max_bytes: MAX_SET_METADATA_BYTES,
        });
    }
    if product_build != &ProductBuild::Pro
        || matches!(pro_status, ProStatus::Live | ProStatus::Omega)
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(QatRoutePreflightError::SetPromotionAllowed);
    }

    let mut route_ids = HashSet::new();
    let mut model_lanes = HashSet::new();
    for card in route_cards {
        validate_route_card(card)?;
        if !route_ids.insert(card.route_card_id.clone()) {
            return Err(QatRoutePreflightError::DuplicateRouteCardId(
                card.route_card_id.clone(),
            ));
        }
        let model_lane = (card.model_id.clone(), card.runtime_lane);
        if !model_lanes.insert(model_lane.clone()) {
            return Err(QatRoutePreflightError::DuplicateModelRuntime {
                model_id: model_lane.0,
                lane: model_lane.1,
            });
        }
    }
    Ok(())
}

fn validate_route_card(
    card: &QatModelRouteCardMemoryPreflight,
) -> Result<(), QatRoutePreflightError> {
    require_nonempty(&card.route_card_id, &card.route_card_id, "route_card_id")?;
    require_nonempty(&card.model_id, &card.route_card_id, "model_id")?;
    require_nonempty(
        &card.upstream_candidate_card_ref,
        &card.route_card_id,
        "upstream_candidate_card_ref",
    )?;
    require_nonempty(
        &card.hardware_profile_ref,
        &card.route_card_id,
        "hardware_profile_ref",
    )?;
    require_nonempty(
        &card.route_caveat_ref,
        &card.route_card_id,
        "route_caveat_ref",
    )?;
    require_prefix(
        &card.upstream_candidate_card_ref,
        &card.route_card_id,
        "upstream_candidate_card_ref",
        CANDIDATE_CARD_PREFIX,
    )?;
    require_prefix(
        &card.hardware_profile_ref,
        &card.route_card_id,
        "hardware_profile_ref",
        HARDWARE_PROFILE_PREFIX,
    )?;
    require_prefix(
        &card.route_caveat_ref,
        &card.route_card_id,
        "route_caveat_ref",
        ROUTE_CAVEAT_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.falsifier_ref,
        &card.route_card_id,
        "falsifier_ref",
        FALSIFIER_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.rollback_ref,
        &card.route_card_id,
        "rollback_ref",
        ROLLBACK_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.run_event_log_ref,
        &card.route_card_id,
        "run_event_log_ref",
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.answer_packet_ref,
        &card.route_card_id,
        "answer_packet_ref",
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.compatibility_fence_ref,
        &card.route_card_id,
        "compatibility_fence_ref",
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    if card.product_build != ProductBuild::Pro {
        return Err(QatRoutePreflightError::BadProductBuild {
            route_card_id: card.route_card_id.clone(),
        });
    }
    if matches!(card.pro_status, ProStatus::Live | ProStatus::Omega) {
        return Err(QatRoutePreflightError::BadProStatus {
            route_card_id: card.route_card_id.clone(),
        });
    }
    if matches!(
        card.promotion_tier,
        QatRoutePromotionTier::T2L2Route
            | QatRoutePromotionTier::T3L3Wrv
            | QatRoutePromotionTier::T4BuildGreen
            | QatRoutePromotionTier::T5FullSegment
    ) {
        return Err(QatRoutePreflightError::BadPromotionTier {
            route_card_id: card.route_card_id.clone(),
        });
    }
    validate_memory_budget(card)?;
    validate_admission(card)?;
    if !card.rollback_required || !card.run_event_log_required || !card.answer_packet_required {
        return Err(QatRoutePreflightError::MissingProofSurface {
            route_card_id: card.route_card_id.clone(),
        });
    }
    if !card.l1_l2_l3_separated || !card.runtime_deferred || card.swift_mlx_loader_proven {
        return Err(QatRoutePreflightError::RuntimeNotDeferred {
            route_card_id: card.route_card_id.clone(),
        });
    }
    if !card.product_promotion_blocked
        || card.file_size_treated_as_resident_memory
        || card.first_token_claimed
        || card.quality_claimed
        || card.mtp_speedup_claimed
        || card.mas_readiness_claimed
    {
        return Err(QatRoutePreflightError::ProductPromotionAllowed {
            route_card_id: card.route_card_id.clone(),
        });
    }
    if card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
    {
        return Err(QatRoutePreflightError::HiddenAuthority {
            route_card_id: card.route_card_id.clone(),
        });
    }
    Ok(())
}

fn validate_memory_budget(
    card: &QatModelRouteCardMemoryPreflight,
) -> Result<(), QatRoutePreflightError> {
    let memory = &card.memory;
    if memory.declared_file_bytes == 0 {
        return Err(invalid_memory(card, "declared_file_bytes must be nonzero"));
    }
    if memory.predicted_resident_bytes <= memory.declared_file_bytes {
        return Err(invalid_memory(
            card,
            "predicted resident bytes must exceed declared file bytes",
        ));
    }
    if memory.predicted_kv_cache_bytes == 0 || memory.predicted_scratch_bytes == 0 {
        return Err(invalid_memory(
            card,
            "kv-cache and scratch byte floors must be nonzero",
        ));
    }
    let expected_total = memory
        .predicted_resident_bytes
        .checked_add(memory.predicted_kv_cache_bytes)
        .and_then(|value| value.checked_add(memory.predicted_scratch_bytes))
        .ok_or_else(|| invalid_memory(card, "predicted route bytes overflowed"))?;
    if memory.total_predicted_route_bytes != expected_total {
        return Err(invalid_memory(
            card,
            "total_predicted_route_bytes must equal resident + kv + scratch",
        ));
    }
    if memory.uma_budget_bytes <= memory.reserved_system_bytes {
        return Err(invalid_memory(
            card,
            "uma budget must exceed reserved system bytes",
        ));
    }
    let expected_available = memory.uma_budget_bytes - memory.reserved_system_bytes;
    if memory.available_for_route_bytes != expected_available {
        return Err(invalid_memory(
            card,
            "available_for_route_bytes must equal uma - reserved",
        ));
    }
    let expected_headroom = expected_available as i64 - memory.total_predicted_route_bytes as i64;
    if memory.headroom_bytes != expected_headroom {
        return Err(invalid_memory(
            card,
            "headroom_bytes must equal available - predicted route bytes",
        ));
    }
    if memory.timeout_ms == 0 || memory.cancellation_deadline_ms == 0 {
        return Err(invalid_memory(
            card,
            "timeout and cancellation deadline must be nonzero",
        ));
    }
    if memory.cancellation_deadline_ms > memory.timeout_ms {
        return Err(invalid_memory(
            card,
            "cancellation deadline must not exceed timeout",
        ));
    }
    if memory.metadata_bytes_read > MAX_ROUTE_METADATA_BYTES {
        return Err(QatRoutePreflightError::MetadataBudgetExceeded {
            bytes: memory.metadata_bytes_read,
            max_bytes: MAX_ROUTE_METADATA_BYTES,
        });
    }
    if memory.model_bytes_loaded != 0
        || memory.runtime_bytes_loaded != 0
        || memory.provider_calls_made != 0
    {
        return Err(QatRoutePreflightError::ByteLoadAttempt {
            route_card_id: card.route_card_id.clone(),
        });
    }
    Ok(())
}

fn validate_admission(
    card: &QatModelRouteCardMemoryPreflight,
) -> Result<(), QatRoutePreflightError> {
    let fits = card.memory.has_positive_headroom();
    match card.admission {
        QatRouteAdmission::AdmitForDryRun => {
            if !fits {
                return Err(admission_error(
                    card,
                    "dry-run admission requires nonnegative headroom",
                ));
            }
            if matches!(
                card.runtime_lane,
                QatRouteRuntimeLane::MlxSwiftCandidate | QatRouteRuntimeLane::NoRuntime
            ) {
                return Err(admission_error(
                    card,
                    "dry-run admission requires a currently supported lane candidate",
                ));
            }
            if matches!(
                card.pro_status,
                ProStatus::VaultPreserved | ProStatus::Blocked
            ) {
                return Err(admission_error(
                    card,
                    "dry-run admission cannot use vault-only or blocked status",
                ));
            }
            if card.abstention_reason_ref.is_some() {
                return Err(admission_error(
                    card,
                    "admitted dry-run cards cannot carry abstention reasons",
                ));
            }
        }
        QatRouteAdmission::AbstainInsufficientHeadroom => {
            require_abstention_reason(card)?;
            if fits {
                return Err(admission_error(
                    card,
                    "insufficient-headroom abstention requires negative headroom",
                ));
            }
        }
        QatRouteAdmission::VaultOnly => {
            require_abstention_reason(card)?;
            if card.pro_status != ProStatus::VaultPreserved {
                return Err(admission_error(
                    card,
                    "vault-only cards must be VaultPreserved",
                ));
            }
        }
        QatRouteAdmission::BlockedMissingLoader => {
            require_abstention_reason(card)?;
            if !matches!(card.runtime_lane, QatRouteRuntimeLane::MlxSwiftCandidate) {
                return Err(admission_error(
                    card,
                    "missing-loader block is only valid for MLX Swift candidates",
                ));
            }
        }
        QatRouteAdmission::BlockedUnsupportedLane => {
            require_abstention_reason(card)?;
            if !matches!(card.runtime_lane, QatRouteRuntimeLane::NoRuntime) {
                return Err(admission_error(
                    card,
                    "unsupported-lane block requires NoRuntime",
                ));
            }
        }
    }

    if card.model_id.contains("-12B-")
        && matches!(card.admission, QatRouteAdmission::AdmitForDryRun)
    {
        return Err(admission_error(
            card,
            "12B QAT target must not bypass the 16 GB UMA headroom gate",
        ));
    }
    if card.model_id.contains("-31B-")
        && !matches!(
            card.admission,
            QatRouteAdmission::VaultOnly | QatRouteAdmission::AbstainInsufficientHeadroom
        )
    {
        return Err(admission_error(
            card,
            "31B QAT candidate must remain vault or abstained on this profile",
        ));
    }
    Ok(())
}

fn require_abstention_reason(
    card: &QatModelRouteCardMemoryPreflight,
) -> Result<(), QatRoutePreflightError> {
    let reason = card
        .abstention_reason_ref
        .as_deref()
        .unwrap_or_default()
        .trim();
    if reason.is_empty() {
        return Err(QatRoutePreflightError::MissingAbstentionReason {
            route_card_id: card.route_card_id.clone(),
        });
    }
    if !reason.starts_with(ABSTENTION_PREFIX) {
        return Err(QatRoutePreflightError::BadPrefix {
            route_card_id: card.route_card_id.clone(),
            field: "abstention_reason_ref",
            expected: ABSTENTION_PREFIX,
        });
    }
    Ok(())
}

fn invalid_memory(
    card: &QatModelRouteCardMemoryPreflight,
    reason: &'static str,
) -> QatRoutePreflightError {
    QatRoutePreflightError::InvalidMemoryBudget {
        route_card_id: card.route_card_id.clone(),
        reason,
    }
}

fn admission_error(
    card: &QatModelRouteCardMemoryPreflight,
    reason: &'static str,
) -> QatRoutePreflightError {
    QatRoutePreflightError::AdmissionContradiction {
        route_card_id: card.route_card_id.clone(),
        reason,
    }
}

fn require_nonempty(
    value: &str,
    route_card_id: &str,
    field: &'static str,
) -> Result<(), QatRoutePreflightError> {
    if value.trim().is_empty() {
        return Err(QatRoutePreflightError::EmptyField {
            route_card_id: route_card_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    route_card_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), QatRoutePreflightError> {
    if !value.starts_with(expected) {
        return Err(QatRoutePreflightError::BadPrefix {
            route_card_id: route_card_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn route_preflight_set_preimage(
    upstream_candidate_set_address: &UasAddress,
    upstream_candidate_witness_ref: &str,
    route_cards: &[QatModelRouteCardMemoryPreflight],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "qat_model_route_card_memory_preflight_v1\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_candidate_set_address,
        upstream_candidate_witness_ref,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for card in route_cards {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{:?}\n{:?}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.route_card_id,
            card.upstream_candidate_card_ref,
            card.model_id,
            card.runtime_lane,
            card.admission,
            product_build_preimage(&card.product_build),
            card.pro_status,
            card.promotion_tier,
            card.hardware_profile_ref,
            card.route_caveat_ref,
            card.abstention_reason_ref.as_deref().unwrap_or(""),
            card.memory.declared_file_bytes,
            card.memory.predicted_resident_bytes,
            card.memory.predicted_kv_cache_bytes,
            card.memory.predicted_scratch_bytes,
            card.memory.total_predicted_route_bytes,
            card.memory.uma_budget_bytes,
            card.memory.reserved_system_bytes,
            card.memory.available_for_route_bytes,
            card.memory.headroom_bytes,
            card.memory.timeout_ms,
            card.memory.cancellation_deadline_ms,
            card.memory.metadata_bytes_read,
            card.memory.model_bytes_loaded,
            card.memory.runtime_bytes_loaded,
            card.memory.provider_calls_made,
            card.proof_refs.falsifier_ref,
            card.proof_refs.rollback_ref,
            card.proof_refs.run_event_log_ref,
            card.proof_refs.answer_packet_ref,
            card.proof_refs.compatibility_fence_ref,
            card.rollback_required,
            card.run_event_log_required,
            card.answer_packet_required,
            card.l1_l2_l3_separated,
            card.runtime_deferred,
            card.product_promotion_blocked,
            card.file_size_treated_as_resident_memory,
            card.first_token_claimed,
            card.quality_claimed,
            card.swift_mlx_loader_proven,
            card.mtp_speedup_claimed
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

    const CREATED_AT_MS: u64 = 1_779_034_700_000;
    const GIB: u64 = 1_073_741_824;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("gemma_qat_local_runtime_candidate_card".to_string()),
            b"gemma-qat-candidate-upstream",
            CREATED_AT_MS,
        )
    }

    fn proof_refs(id: &str) -> QatRouteProofRefs {
        QatRouteProofRefs {
            falsifier_ref: format!("falsifier:F-QAT-ModelRouteCard-MemoryPreflight:{id}"),
            rollback_ref: format!("rollback:qat_route_preflight:{id}"),
            run_event_log_ref: format!("run_event_log:qat_route_preflight:{id}"),
            answer_packet_ref: format!("answer_packet:qat_route_preflight:{id}"),
            compatibility_fence_ref: format!("compat:qat_route_preflight:{id}"),
        }
    }

    fn route_card(
        route_card_id: &str,
        model_id: &str,
        admission: QatRouteAdmission,
        resident_gib: u64,
    ) -> QatModelRouteCardMemoryPreflight {
        let declared_file_bytes = if model_id.contains("-12B-") {
            11_907_350_576
        } else if model_id.contains("-31B-") {
            30_697_345_596
        } else {
            4_628_569_635
        };
        let abstention_reason_ref = match admission {
            QatRouteAdmission::AdmitForDryRun => None,
            QatRouteAdmission::AbstainInsufficientHeadroom => {
                Some("abstain:insufficient_uma_headroom_for_dry_run".to_string())
            }
            QatRouteAdmission::VaultOnly => {
                Some("abstain:vault_only_large_candidate_no_runtime_probe".to_string())
            }
            QatRouteAdmission::BlockedMissingLoader => {
                Some("abstain:swift_loader_not_proven".to_string())
            }
            QatRouteAdmission::BlockedUnsupportedLane => {
                Some("abstain:unsupported_runtime_lane".to_string())
            }
        };
        QatModelRouteCardMemoryPreflight {
            route_card_id: route_card_id.to_string(),
            upstream_candidate_card_ref: format!("gemma_qat_candidate:{route_card_id}"),
            model_id: model_id.to_string(),
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            admission,
            product_build: ProductBuild::Pro,
            pro_status: match admission {
                QatRouteAdmission::VaultOnly => ProStatus::VaultPreserved,
                QatRouteAdmission::BlockedMissingLoader
                | QatRouteAdmission::BlockedUnsupportedLane => ProStatus::Blocked,
                _ => ProStatus::ResearchCandidate,
            },
            promotion_tier: QatRoutePromotionTier::T1L1Metadata,
            hardware_profile_ref: "hardware:apple_silicon_m2_pro_16gb_uma".to_string(),
            route_caveat_ref: "route_caveat:metadata_preflight_no_runtime_bytes".to_string(),
            abstention_reason_ref,
            memory: QatRouteMemoryBudget::metadata_only(
                declared_file_bytes,
                resident_gib * GIB,
                512 * 1024 * 1024,
                256 * 1024 * 1024,
                16 * GIB,
                4 * GIB,
                30_000,
                5_000,
                20_000,
            ),
            proof_refs: proof_refs(route_card_id),
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            product_promotion_blocked: true,
            file_size_treated_as_resident_memory: false,
            first_token_claimed: false,
            quality_claimed: false,
            swift_mlx_loader_proven: false,
            mtp_speedup_claimed: false,
            mas_readiness_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
        }
    }

    fn preflight_set(
        route_cards: Vec<QatModelRouteCardMemoryPreflight>,
    ) -> Result<QatModelRouteCardMemoryPreflightSet, QatRoutePreflightError> {
        QatModelRouteCardMemoryPreflightSet::from_candidate_set(
            upstream_address(),
            "artifact:gemma_qat_local_runtime_candidate_card:result",
            route_cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            50_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_order_stable_metadata_only_route_cards() {
        let mut cards = vec![
            route_card(
                "gemma4_e4b_qat_gguf_route_preflight",
                "google/gemma-4-E4B-it-qat-q4_0-gguf",
                QatRouteAdmission::AdmitForDryRun,
                8,
            ),
            route_card(
                "gemma4_e2b_qat_gguf_route_preflight",
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                QatRouteAdmission::AdmitForDryRun,
                5,
            ),
        ];
        let set = preflight_set(cards.clone()).expect("route preflight should validate");
        cards.reverse();
        let reversed = preflight_set(cards).expect("route preflight should validate");
        assert_eq!(set.set_address, reversed.set_address);
        assert_eq!(set.metrics().dry_run_admission_count, 2);
        assert_eq!(set.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_dry_run_admission_with_negative_headroom() {
        let candidate = route_card(
            "gemma4_12b_qat_gguf_false_admit",
            "google/gemma-4-12B-it-qat-q4_0-gguf",
            QatRouteAdmission::AdmitForDryRun,
            13,
        );
        assert!(preflight_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_file_size_as_memory_and_bad_budget() {
        let mut candidate = route_card(
            "gemma4_e2b_qat_gguf_bad_memory",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            QatRouteAdmission::AdmitForDryRun,
            5,
        );
        candidate.file_size_treated_as_resident_memory = true;
        assert!(preflight_set(vec![candidate.clone()]).is_err());
        candidate.file_size_treated_as_resident_memory = false;
        candidate.memory.predicted_resident_bytes = candidate.memory.declared_file_bytes;
        assert!(preflight_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_loaded_bytes_and_provider_calls() {
        let mut candidate = route_card(
            "gemma4_e2b_qat_gguf_loaded",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            QatRouteAdmission::AdmitForDryRun,
            5,
        );
        candidate.memory.model_bytes_loaded = 1;
        assert!(preflight_set(vec![candidate.clone()]).is_err());
        candidate.memory.model_bytes_loaded = 0;
        candidate.memory.runtime_bytes_loaded = 1;
        assert!(preflight_set(vec![candidate.clone()]).is_err());
        candidate.memory.runtime_bytes_loaded = 0;
        candidate.memory.provider_calls_made = 1;
        assert!(preflight_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_product_promotion_and_hidden_authority() {
        let mut candidate = route_card(
            "gemma4_e2b_qat_gguf_claim",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            QatRouteAdmission::AdmitForDryRun,
            5,
        );
        candidate.product_build = ProductBuild::Mas;
        assert!(preflight_set(vec![candidate.clone()]).is_err());
        candidate.product_build = ProductBuild::Pro;
        candidate.promotion_tier = QatRoutePromotionTier::T2L2Route;
        assert!(preflight_set(vec![candidate.clone()]).is_err());
        candidate.promotion_tier = QatRoutePromotionTier::T1L1Metadata;
        candidate.hidden_cloud_fallback_allowed = true;
        assert!(preflight_set(vec![candidate]).is_err());
    }
}
