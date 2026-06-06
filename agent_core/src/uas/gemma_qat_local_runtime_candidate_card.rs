//! Gemma QAT local runtime candidate cards.
//!
//! This primitive narrows the June 6 Gemma 4 QAT research into metadata-only
//! runtime candidate cards. It records which model cards may be handed to
//! later memory-preflight and runtime witnesses without loading model bytes,
//! choosing a route, proving Swift MLX support, or promoting product truth.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const GEMMA_QAT_LOCAL_RUNTIME_CANDIDATE_CARD_CURSOR: &str =
    "gemma_qat_local_runtime_candidate_card";
pub const GEMMA_QAT_LOCAL_RUNTIME_CANDIDATE_CARD_NEXT_CURSOR: &str =
    "qat_model_route_card_memory_preflight";

const SOURCE_CARD_PREFIX: &str = "compressed_model_source_card:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 80 * 1024;

// UAS: uas:gemma-qat-candidate:model-size
// Plane: State + Assembly
// Residency: candidate-card model scale; not loadability proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatModelSize {
    E2B,
    E4B,
    TwelveB,
    TwentySixB,
    ThirtyOneB,
}

// UAS: uas:gemma-qat-candidate:format
// Plane: State + Controller
// Residency: declared model-card format; no model file is opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatFormat {
    GgufQ4_0,
    LiteRtPreview,
    MlxFourBitPreview,
    SafetensorsQat,
}

// UAS: uas:gemma-qat-candidate:runtime-lane
// Plane: Controller
// Residency: lane candidate only; System G may cite it after later proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatRuntimeLane {
    GgufLlamaCpp,
    LiteRtLm,
    MlxSwiftCandidate,
    MlxSwiftBlocked,
    TransformersResearch,
    NoRuntime,
}

// UAS: uas:gemma-qat-candidate:band
// Plane: Assembly + Controller
// Residency: planning band, not a user capability.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatCandidateBand {
    SmallHarnessCandidate,
    FlagshipProGatedTarget,
    VaultResearchOnly,
    LoaderBlockedPreview,
    SourceOnlyBaseline,
}

// UAS: uas:gemma-qat-candidate:tier
// Plane: Verification
// Residency: T0/T1 only in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:gemma-qat-candidate:memory-envelope
// Plane: Verification
// Residency: source-backed metadata and estimates; loaded bytes must be zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatMemoryEnvelope {
    pub declared_file_bytes: u64,
    pub context_window_tokens: u64,
    pub estimated_resident_floor_bytes: u64,
    pub estimated_kv_floor_bytes: u64,
    pub estimated_scratch_floor_bytes: u64,
    pub metadata_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl GemmaQatMemoryEnvelope {
    pub fn metadata_only(
        declared_file_bytes: u64,
        context_window_tokens: u64,
        estimated_resident_floor_bytes: u64,
        estimated_kv_floor_bytes: u64,
        estimated_scratch_floor_bytes: u64,
        metadata_bytes_read: u64,
    ) -> Self {
        Self {
            declared_file_bytes,
            context_window_tokens,
            estimated_resident_floor_bytes,
            estimated_kv_floor_bytes,
            estimated_scratch_floor_bytes,
            metadata_bytes_read,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:gemma-qat-candidate:proof-refs
// Plane: Verification
// Residency: visible proof handles required before runtime work.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:gemma-qat-candidate:card
// Plane: State + Assembly + Controller + Verification
// Residency: candidate card only; no runtime, route, or product claim.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatLocalRuntimeCandidateCard {
    pub card_id: String,
    pub upstream_source_card_ref: String,
    pub model_id: String,
    pub model_size: GemmaQatModelSize,
    pub format: GemmaQatFormat,
    pub runtime_lane: GemmaQatRuntimeLane,
    pub candidate_band: GemmaQatCandidateBand,
    pub source_locator: String,
    pub source_revision_ref: String,
    pub license_ref: String,
    pub loader_caveat_ref: Option<String>,
    pub route_caveat_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: GemmaQatPromotionTier,
    pub memory: GemmaQatMemoryEnvelope,
    pub proof_refs: GemmaQatProofRefs,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub swift_mlx_loader_proven: bool,
    pub mtp_speedup_claimed: bool,
    pub file_size_treated_as_resident_memory: bool,
    pub mas_readiness_claimed: bool,
    pub product_capability_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
}

// UAS: uas:gemma-qat-candidate:set
// Plane: State + Assembly + Controller + Verification
// Residency: source-carded candidate pack for future memory preflight.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatLocalRuntimeCandidateSet {
    pub set_address: UasAddress,
    pub upstream_intake_address: UasAddress,
    pub upstream_intake_witness_ref: String,
    pub cards: Vec<GemmaQatLocalRuntimeCandidateCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:gemma-qat-candidate:metrics
// Plane: Verification
// Residency: derived counts for metadata-only artifacts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatCandidateMetrics {
    pub card_count: u64,
    pub model_size_count: u64,
    pub format_count: u64,
    pub runtime_lane_count: u64,
    pub small_harness_candidate_count: u64,
    pub flagship_target_count: u64,
    pub vault_research_count: u64,
    pub loader_blocked_count: u64,
    pub declared_file_bytes_total: u64,
    pub estimated_resident_floor_bytes_total: u64,
    pub estimated_kv_floor_bytes_total: u64,
    pub estimated_scratch_floor_bytes_total: u64,
    pub metadata_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl GemmaQatLocalRuntimeCandidateSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_source_cards(
        upstream_intake_address: UasAddress,
        upstream_intake_witness_ref: impl Into<String>,
        mut cards: Vec<GemmaQatLocalRuntimeCandidateCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatCandidateError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let witness_ref = upstream_intake_witness_ref.into();
        validate_set_inputs(
            &upstream_intake_address,
            &witness_ref,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = candidate_set_preimage(
            &upstream_intake_address,
            &witness_ref,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(GEMMA_QAT_LOCAL_RUNTIME_CANDIDATE_CARD_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_intake_address,
            upstream_intake_witness_ref: witness_ref,
            cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> GemmaQatCandidateMetrics {
        let mut model_sizes = BTreeSet::new();
        let mut formats = BTreeSet::new();
        let mut runtime_lanes = BTreeSet::new();
        let mut small_harness_candidate_count = 0;
        let mut flagship_target_count = 0;
        let mut vault_research_count = 0;
        let mut loader_blocked_count = 0;
        let mut declared_file_bytes_total = 0;
        let mut estimated_resident_floor_bytes_total = 0;
        let mut estimated_kv_floor_bytes_total = 0;
        let mut estimated_scratch_floor_bytes_total = 0;
        let mut metadata_bytes_read = self.metadata_bytes;
        let mut model_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut provider_calls_made = 0;

        for card in &self.cards {
            model_sizes.insert(card.model_size);
            formats.insert(card.format);
            runtime_lanes.insert(card.runtime_lane);
            match card.candidate_band {
                GemmaQatCandidateBand::SmallHarnessCandidate => small_harness_candidate_count += 1,
                GemmaQatCandidateBand::FlagshipProGatedTarget => flagship_target_count += 1,
                GemmaQatCandidateBand::VaultResearchOnly => vault_research_count += 1,
                GemmaQatCandidateBand::LoaderBlockedPreview => loader_blocked_count += 1,
                GemmaQatCandidateBand::SourceOnlyBaseline => {}
            }
            declared_file_bytes_total += card.memory.declared_file_bytes;
            estimated_resident_floor_bytes_total += card.memory.estimated_resident_floor_bytes;
            estimated_kv_floor_bytes_total += card.memory.estimated_kv_floor_bytes;
            estimated_scratch_floor_bytes_total += card.memory.estimated_scratch_floor_bytes;
            metadata_bytes_read += card.memory.metadata_bytes_read;
            model_bytes_loaded += card.memory.model_bytes_loaded;
            runtime_bytes_loaded += card.memory.runtime_bytes_loaded;
            provider_calls_made += card.memory.provider_calls_made;
        }

        GemmaQatCandidateMetrics {
            card_count: self.cards.len() as u64,
            model_size_count: model_sizes.len() as u64,
            format_count: formats.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            small_harness_candidate_count,
            flagship_target_count,
            vault_research_count,
            loader_blocked_count,
            declared_file_bytes_total,
            estimated_resident_floor_bytes_total,
            estimated_kv_floor_bytes_total,
            estimated_scratch_floor_bytes_total,
            metadata_bytes_read,
            model_bytes_loaded,
            runtime_bytes_loaded,
            provider_calls_made,
        }
    }
}

// UAS: uas:gemma-qat-candidate:error
// Plane: Verification
// Residency: fail-closed validation surface for metadata-only candidate cards.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatCandidateError {
    MissingUpstreamIntake,
    MissingUpstreamWitness,
    EmptyCards,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicateCardId(String),
    DuplicateModelId(String),
    EmptyField {
        card_id: String,
        field: &'static str,
    },
    BadPrefix {
        card_id: String,
        field: &'static str,
        expected: &'static str,
    },
    BadSourceLocator(String),
    BadProductBuild {
        card_id: String,
    },
    BadProStatus {
        card_id: String,
    },
    BadPromotionTier {
        card_id: String,
    },
    BadCandidateBand {
        card_id: String,
    },
    MissingLoaderCaveat {
        card_id: String,
    },
    RuntimeNotDeferred {
        card_id: String,
    },
    ProductPromotionAllowed {
        card_id: String,
    },
    HiddenAuthority {
        card_id: String,
    },
    ByteLoadAttempt {
        card_id: String,
    },
    InvalidMemoryEnvelope {
        card_id: String,
        reason: &'static str,
    },
    SetPromotionAllowed,
}

impl fmt::Display for GemmaQatCandidateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamIntake => write!(f, "missing upstream source-card intake address"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream source-card witness ref"),
            Self::EmptyCards => write!(f, "Gemma QAT candidate set requires cards"),
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicateCardId(id) => write!(f, "duplicate Gemma QAT card id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate Gemma QAT model id `{id}`"),
            Self::EmptyField { card_id, field } => {
                write!(f, "Gemma QAT card `{card_id}` has empty `{field}`")
            }
            Self::BadPrefix {
                card_id,
                field,
                expected,
            } => write!(
                f,
                "Gemma QAT card `{card_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadSourceLocator(card_id) => {
                write!(f, "Gemma QAT card `{card_id}` source locator must be https")
            }
            Self::BadProductBuild { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` cannot promote to MAS")
            }
            Self::BadProStatus { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` has forbidden Pro status")
            }
            Self::BadPromotionTier { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` cannot promote beyond T1")
            }
            Self::BadCandidateBand { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` has invalid candidate band")
            }
            Self::MissingLoaderCaveat { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` needs an MLX loader caveat")
            }
            Self::RuntimeNotDeferred { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` tried to make runtime live")
            }
            Self::ProductPromotionAllowed { card_id } => {
                write!(
                    f,
                    "Gemma QAT card `{card_id}` tried to promote product truth"
                )
            }
            Self::HiddenAuthority { card_id } => {
                write!(f, "Gemma QAT card `{card_id}` enabled hidden authority")
            }
            Self::ByteLoadAttempt { card_id } => {
                write!(
                    f,
                    "Gemma QAT card `{card_id}` attempted model/runtime/provider bytes"
                )
            }
            Self::InvalidMemoryEnvelope { card_id, reason } => {
                write!(
                    f,
                    "Gemma QAT card `{card_id}` invalid memory envelope: {reason}"
                )
            }
            Self::SetPromotionAllowed => {
                write!(
                    f,
                    "Gemma QAT candidate set tried to promote product/runtime truth"
                )
            }
        }
    }
}

impl std::error::Error for GemmaQatCandidateError {}

fn validate_set_inputs(
    upstream_intake_address: &UasAddress,
    upstream_witness_ref: &str,
    cards: &[GemmaQatLocalRuntimeCandidateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), GemmaQatCandidateError> {
    if upstream_intake_address.to_string().trim().is_empty() {
        return Err(GemmaQatCandidateError::MissingUpstreamIntake);
    }
    if upstream_witness_ref.trim().is_empty() {
        return Err(GemmaQatCandidateError::MissingUpstreamWitness);
    }
    if cards.is_empty() {
        return Err(GemmaQatCandidateError::EmptyCards);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(GemmaQatCandidateError::MetadataBudgetExceeded {
            bytes: metadata_bytes,
            max_bytes: MAX_SET_METADATA_BYTES,
        });
    }
    if product_build != &ProductBuild::Pro
        || pro_status == &ProStatus::Live
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(GemmaQatCandidateError::SetPromotionAllowed);
    }

    let mut card_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !card_ids.insert(card.card_id.clone()) {
            return Err(GemmaQatCandidateError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(GemmaQatCandidateError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_card(card: &GemmaQatLocalRuntimeCandidateCard) -> Result<(), GemmaQatCandidateError> {
    require_nonempty(&card.card_id, &card.card_id, "card_id")?;
    require_nonempty(&card.model_id, &card.card_id, "model_id")?;
    require_nonempty(
        &card.upstream_source_card_ref,
        &card.card_id,
        "upstream_source_card_ref",
    )?;
    require_nonempty(&card.source_locator, &card.card_id, "source_locator")?;
    require_nonempty(
        &card.source_revision_ref,
        &card.card_id,
        "source_revision_ref",
    )?;
    require_nonempty(&card.license_ref, &card.card_id, "license_ref")?;
    require_nonempty(&card.route_caveat_ref, &card.card_id, "route_caveat_ref")?;
    require_prefix(
        &card.upstream_source_card_ref,
        &card.card_id,
        "upstream_source_card_ref",
        SOURCE_CARD_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.falsifier_ref,
        &card.card_id,
        "falsifier_ref",
        FALSIFIER_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.rollback_ref,
        &card.card_id,
        "rollback_ref",
        ROLLBACK_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.run_event_log_ref,
        &card.card_id,
        "run_event_log_ref",
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.answer_packet_ref,
        &card.card_id,
        "answer_packet_ref",
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        &card.proof_refs.compatibility_fence_ref,
        &card.card_id,
        "compatibility_fence_ref",
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    if !card.source_locator.starts_with("https://") {
        return Err(GemmaQatCandidateError::BadSourceLocator(
            card.card_id.clone(),
        ));
    }
    if !card.source_revision_ref.starts_with("revision:") {
        return Err(GemmaQatCandidateError::BadPrefix {
            card_id: card.card_id.clone(),
            field: "source_revision_ref",
            expected: "revision:",
        });
    }
    if !card.license_ref.starts_with("license:") {
        return Err(GemmaQatCandidateError::BadPrefix {
            card_id: card.card_id.clone(),
            field: "license_ref",
            expected: "license:",
        });
    }
    if !card.route_caveat_ref.starts_with("route_caveat:") {
        return Err(GemmaQatCandidateError::BadPrefix {
            card_id: card.card_id.clone(),
            field: "route_caveat_ref",
            expected: "route_caveat:",
        });
    }
    if card.product_build != ProductBuild::Pro {
        return Err(GemmaQatCandidateError::BadProductBuild {
            card_id: card.card_id.clone(),
        });
    }
    if matches!(card.pro_status, ProStatus::Live | ProStatus::Omega) {
        return Err(GemmaQatCandidateError::BadProStatus {
            card_id: card.card_id.clone(),
        });
    }
    if matches!(
        card.promotion_tier,
        GemmaQatPromotionTier::T2L2Route
            | GemmaQatPromotionTier::T3L3Wrv
            | GemmaQatPromotionTier::T4BuildGreen
            | GemmaQatPromotionTier::T5FullSegment
    ) {
        return Err(GemmaQatCandidateError::BadPromotionTier {
            card_id: card.card_id.clone(),
        });
    }
    if matches!(
        card.runtime_lane,
        GemmaQatRuntimeLane::MlxSwiftCandidate | GemmaQatRuntimeLane::MlxSwiftBlocked
    ) && card
        .loader_caveat_ref
        .as_deref()
        .unwrap_or_default()
        .trim()
        .is_empty()
    {
        return Err(GemmaQatCandidateError::MissingLoaderCaveat {
            card_id: card.card_id.clone(),
        });
    }
    validate_band(card)?;
    validate_memory(card)?;
    if !card.l1_l2_l3_separated || !card.runtime_deferred || card.swift_mlx_loader_proven {
        return Err(GemmaQatCandidateError::RuntimeNotDeferred {
            card_id: card.card_id.clone(),
        });
    }
    if card.product_capability_claimed
        || card.mas_readiness_claimed
        || card.mtp_speedup_claimed
        || card.file_size_treated_as_resident_memory
    {
        return Err(GemmaQatCandidateError::ProductPromotionAllowed {
            card_id: card.card_id.clone(),
        });
    }
    if card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
    {
        return Err(GemmaQatCandidateError::HiddenAuthority {
            card_id: card.card_id.clone(),
        });
    }
    Ok(())
}

fn validate_band(card: &GemmaQatLocalRuntimeCandidateCard) -> Result<(), GemmaQatCandidateError> {
    match (card.model_size, card.candidate_band, &card.pro_status) {
        (GemmaQatModelSize::E2B | GemmaQatModelSize::E4B, _, _) => Ok(()),
        (
            GemmaQatModelSize::TwelveB,
            GemmaQatCandidateBand::FlagshipProGatedTarget,
            ProStatus::Gated | ProStatus::ResearchCandidate,
        ) => Ok(()),
        (
            GemmaQatModelSize::TwentySixB | GemmaQatModelSize::ThirtyOneB,
            GemmaQatCandidateBand::VaultResearchOnly,
            ProStatus::VaultPreserved | ProStatus::ResearchCandidate,
        ) => Ok(()),
        (_, GemmaQatCandidateBand::LoaderBlockedPreview, ProStatus::Blocked) => Ok(()),
        _ => Err(GemmaQatCandidateError::BadCandidateBand {
            card_id: card.card_id.clone(),
        }),
    }
}

fn validate_memory(card: &GemmaQatLocalRuntimeCandidateCard) -> Result<(), GemmaQatCandidateError> {
    let memory = &card.memory;
    if memory.declared_file_bytes == 0 {
        return Err(GemmaQatCandidateError::InvalidMemoryEnvelope {
            card_id: card.card_id.clone(),
            reason: "declared_file_bytes must be nonzero",
        });
    }
    if memory.context_window_tokens == 0 {
        return Err(GemmaQatCandidateError::InvalidMemoryEnvelope {
            card_id: card.card_id.clone(),
            reason: "context_window_tokens must be nonzero",
        });
    }
    if memory.estimated_resident_floor_bytes <= memory.declared_file_bytes {
        return Err(GemmaQatCandidateError::InvalidMemoryEnvelope {
            card_id: card.card_id.clone(),
            reason: "resident floor must exceed declared file bytes",
        });
    }
    if memory.estimated_kv_floor_bytes == 0 || memory.estimated_scratch_floor_bytes == 0 {
        return Err(GemmaQatCandidateError::InvalidMemoryEnvelope {
            card_id: card.card_id.clone(),
            reason: "kv and scratch byte floors must be nonzero",
        });
    }
    if memory.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(GemmaQatCandidateError::MetadataBudgetExceeded {
            bytes: memory.metadata_bytes_read,
            max_bytes: MAX_CARD_METADATA_BYTES,
        });
    }
    if memory.model_bytes_loaded != 0
        || memory.runtime_bytes_loaded != 0
        || memory.provider_calls_made != 0
    {
        return Err(GemmaQatCandidateError::ByteLoadAttempt {
            card_id: card.card_id.clone(),
        });
    }
    Ok(())
}

fn require_nonempty(
    value: &str,
    card_id: &str,
    field: &'static str,
) -> Result<(), GemmaQatCandidateError> {
    if value.trim().is_empty() {
        return Err(GemmaQatCandidateError::EmptyField {
            card_id: card_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    card_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), GemmaQatCandidateError> {
    if !value.starts_with(expected) {
        return Err(GemmaQatCandidateError::BadPrefix {
            card_id: card_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn candidate_set_preimage(
    upstream_intake_address: &UasAddress,
    upstream_witness_ref: &str,
    cards: &[GemmaQatLocalRuntimeCandidateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "gemma_qat_local_runtime_candidate_card_v1\n{}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_intake_address,
        upstream_witness_ref,
        product_build,
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for card in cards {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{:?}\n{:?}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{:?}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.card_id,
            card.upstream_source_card_ref,
            card.model_id,
            card.model_size,
            card.format,
            card.runtime_lane,
            card.candidate_band,
            card.source_locator,
            card.source_revision_ref,
            card.license_ref,
            card.loader_caveat_ref.as_deref().unwrap_or(""),
            card.route_caveat_ref,
            product_build_preimage(&card.product_build),
            card.pro_status,
            card.promotion_tier,
            card.memory.declared_file_bytes,
            card.memory.context_window_tokens,
            card.memory.estimated_resident_floor_bytes,
            card.memory.estimated_kv_floor_bytes,
            card.memory.estimated_scratch_floor_bytes,
            card.memory.metadata_bytes_read,
            card.memory.model_bytes_loaded,
            card.memory.runtime_bytes_loaded,
            card.memory.provider_calls_made,
            card.proof_refs.falsifier_ref,
            card.proof_refs.rollback_ref,
            card.proof_refs.run_event_log_ref,
            card.proof_refs.answer_packet_ref,
            card.proof_refs.compatibility_fence_ref,
            card.l1_l2_l3_separated,
            card.runtime_deferred,
            card.swift_mlx_loader_proven,
            card.mtp_speedup_claimed,
            card.file_size_treated_as_resident_memory,
            card.mas_readiness_claimed
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

    const CREATED_AT_MS: u64 = 1_779_034_600_000;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("compressed_model_source_card_intake".to_string()),
            b"compressed-source-card-upstream",
            CREATED_AT_MS,
        )
    }

    fn proof_refs(id: &str) -> GemmaQatProofRefs {
        GemmaQatProofRefs {
            falsifier_ref: format!("falsifier:F-GemmaQAT-LocalRuntimeCandidateCard:{id}"),
            rollback_ref: format!("rollback:gemma_qat_candidate:{id}"),
            run_event_log_ref: format!("run_event_log:gemma_qat_candidate:{id}"),
            answer_packet_ref: format!("answer_packet:gemma_qat_candidate:{id}"),
            compatibility_fence_ref: format!("compat:gemma_qat_candidate:{id}"),
        }
    }

    fn card(
        id: &str,
        model_id: &str,
        size: GemmaQatModelSize,
    ) -> GemmaQatLocalRuntimeCandidateCard {
        GemmaQatLocalRuntimeCandidateCard {
            card_id: id.to_string(),
            upstream_source_card_ref: format!("compressed_model_source_card:{id}"),
            model_id: model_id.to_string(),
            model_size: size,
            format: GemmaQatFormat::GgufQ4_0,
            runtime_lane: GemmaQatRuntimeLane::GgufLlamaCpp,
            candidate_band: GemmaQatCandidateBand::SmallHarnessCandidate,
            source_locator: format!("https://huggingface.co/{model_id}"),
            source_revision_ref: "revision:abc123".to_string(),
            license_ref: "license:apache-2.0".to_string(),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:metadata_only_no_runtime".to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: GemmaQatPromotionTier::T1L1Metadata,
            memory: GemmaQatMemoryEnvelope::metadata_only(
                4_628_569_635,
                131_072,
                5_368_709_120,
                536_870_912,
                268_435_456,
                16_000,
            ),
            proof_refs: proof_refs(id),
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            swift_mlx_loader_proven: false,
            mtp_speedup_claimed: false,
            file_size_treated_as_resident_memory: false,
            mas_readiness_claimed: false,
            product_capability_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
        }
    }

    fn candidate_set(
        cards: Vec<GemmaQatLocalRuntimeCandidateCard>,
    ) -> Result<GemmaQatLocalRuntimeCandidateSet, GemmaQatCandidateError> {
        GemmaQatLocalRuntimeCandidateSet::from_source_cards(
            upstream_address(),
            "artifact:compressed_model_source_card_intake:result",
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            40_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_order_stable_metadata_only_candidate_pack() {
        let mut cards = vec![
            card(
                "gemma4_e4b_qat_gguf_candidate",
                "google/gemma-4-E4B-it-qat-q4_0-gguf",
                GemmaQatModelSize::E4B,
            ),
            card(
                "gemma4_e2b_qat_gguf_candidate",
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                GemmaQatModelSize::E2B,
            ),
        ];
        let set = candidate_set(cards.clone()).expect("candidate pack should validate");
        cards.reverse();
        let reversed = candidate_set(cards).expect("candidate pack should validate");
        assert_eq!(set.set_address, reversed.set_address);
        assert_eq!(set.metrics().card_count, 2);
        assert_eq!(set.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_swift_mlx_loader_claim_without_later_witness() {
        let mut candidate = card(
            "gemma4_12b_mlx_preview_candidate",
            "google/gemma-4-12B-it-qat-q4_0-mlx-preview",
            GemmaQatModelSize::TwelveB,
        );
        candidate.runtime_lane = GemmaQatRuntimeLane::MlxSwiftCandidate;
        candidate.candidate_band = GemmaQatCandidateBand::FlagshipProGatedTarget;
        candidate.pro_status = ProStatus::Gated;
        candidate.loader_caveat_ref = Some("loader_caveat:swift_mlx_gemma4_unproven".to_string());
        candidate.swift_mlx_loader_proven = true;
        assert!(candidate_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_file_size_as_memory_claim() {
        let mut candidate = card(
            "gemma4_e2b_bad_memory",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            GemmaQatModelSize::E2B,
        );
        candidate.file_size_treated_as_resident_memory = true;
        assert!(candidate_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_large_candidate_outside_vault_band() {
        let candidate = card(
            "gemma4_31b_wrong_band",
            "google/gemma-4-31B-it-qat-q4_0-gguf",
            GemmaQatModelSize::ThirtyOneB,
        );
        assert!(candidate_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_product_promotion_and_mas() {
        let mut candidate = card(
            "gemma4_e2b_mas",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            GemmaQatModelSize::E2B,
        );
        candidate.product_build = ProductBuild::Mas;
        candidate.product_capability_claimed = true;
        assert!(candidate_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_hidden_cloud_fallback() {
        let mut candidate = card(
            "gemma4_e2b_hidden_cloud",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            GemmaQatModelSize::E2B,
        );
        candidate.hidden_cloud_fallback_allowed = true;
        assert!(candidate_set(vec![candidate]).is_err());
    }
}
