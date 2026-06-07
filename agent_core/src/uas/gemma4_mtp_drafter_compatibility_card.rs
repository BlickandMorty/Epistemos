//! Gemma 4 MTP drafter compatibility card.
//!
//! This primitive source-cards Gemma 4 multi-token-prediction (MTP)
//! target/drafter pairs before any runtime lane can claim speedup. It is
//! metadata-only: no target model, drafter model, runtime, package, provider,
//! or product bytes are downloaded, linked, loaded, or run here.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const GEMMA4_MTP_DRAFTER_COMPATIBILITY_CARD_CURSOR: &str =
    "gemma4_mtp_drafter_compatibility_card";
pub const GEMMA4_MTP_DRAFTER_COMPATIBILITY_CARD_NEXT_CURSOR: &str =
    "runtime_plural_qat_lane_tournament_plan";

const HTTPS_PREFIX: &str = "https://";
const LITERT_ADMISSION_PREFIX: &str = "artifact:litertlm_native_swift_admission:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_PREFIX: &str = "compat:";
const QUALITY_LEDGER_PREFIX: &str = "quality_ledger:";
const ACCEPTANCE_METRIC_PREFIX: &str = "acceptance_metric:";
const LATENCY_BUDGET_PREFIX: &str = "latency_budget:";
const EXTRA_MEMORY_BUDGET_PREFIX: &str = "extra_memory_budget:";
const ABSTENTION_PREFIX: &str = "abstain:";
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAX_SET_METADATA_BYTES: u64 = 256 * 1024;

// UAS: uas:gemma4-mtp-drafter:runtime-lane
// Plane: Controller
// Residency: candidate lane only; no runtime is opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Gemma4MtpRuntimeLane {
    LiteRtLm,
    GgufLlamaCpp,
    MlxSwiftCandidate,
    TransformersResearch,
    NoRuntime,
}

// UAS: uas:gemma4-mtp-drafter:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Gemma4MtpPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:gemma4-mtp-drafter:byte-scope
// Plane: Verification
// Residency: metadata-only accounting for target/drafter source cards.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Gemma4MtpByteScope {
    pub metadata_bytes_read: u64,
    pub target_model_bytes_loaded: u64,
    pub drafter_model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
}

impl Gemma4MtpByteScope {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            target_model_bytes_loaded: 0,
            drafter_model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            product_files_copied: 0,
        }
    }
}

// UAS: uas:gemma4-mtp-drafter:proof-refs
// Plane: Verification
// Residency: visible proof handles before any speedup route can cite MTP.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Gemma4MtpProofRefs {
    pub litert_admission_ref: String,
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub quality_ledger_ref: String,
    pub acceptance_metric_ref: String,
    pub latency_budget_ref: String,
    pub extra_memory_budget_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:gemma4-mtp-drafter:card
// Plane: State + Assembly + Controller + Verification
// Residency: MTP compatibility source card; no runtime or product speed claim.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Gemma4MtpDrafterCompatibilityCard {
    pub card_id: String,
    pub target_model_id: String,
    pub target_model_url: String,
    pub target_revision: String,
    pub drafter_model_id: String,
    pub drafter_model_url: String,
    pub drafter_revision: String,
    pub license_spdx: String,
    pub mtp_source_url: String,
    pub mtp_source_summary_ref: String,
    pub runtime_lane: Gemma4MtpRuntimeLane,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: Gemma4MtpPromotionTier,
    pub reported_speedup_upper_bound_bps: u64,
    pub target_verifies_draft_tokens: bool,
    pub accepted_tokens_visible: bool,
    pub rejected_tokens_visible: bool,
    pub final_output_from_target_only: bool,
    pub hidden_alternate_text_blocked: bool,
    pub hidden_chain_blocked: bool,
    pub quality_metric_required: bool,
    pub acceptance_metric_required: bool,
    pub latency_budget_required: bool,
    pub extra_memory_budget_required: bool,
    pub abstention_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub runtime_deferred: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub proof_refs: Gemma4MtpProofRefs,
    pub byte_scope: Gemma4MtpByteScope,
    pub first_token_claimed: bool,
    pub product_speedup_claimed: bool,
    pub quality_improvement_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub hidden_route_authority_allowed: bool,
    pub hidden_cloud_fallback_allowed: bool,
}

// UAS: uas:gemma4-mtp-drafter:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only MTP compatibility set for lane-tournament planning.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Gemma4MtpDrafterCompatibilitySet {
    pub set_address: UasAddress,
    pub cards: Vec<Gemma4MtpDrafterCompatibilityCard>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub hidden_authority_blocked: bool,
}

// UAS: uas:gemma4-mtp-drafter:metrics
// Plane: Verification
// Residency: derived counters for metadata-only artifacts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Gemma4MtpDrafterCompatibilityMetrics {
    pub card_count: u64,
    pub target_model_count: u64,
    pub drafter_model_count: u64,
    pub runtime_lane_count: u64,
    pub max_reported_speedup_upper_bound_bps: u64,
    pub metadata_bytes_read: u64,
    pub target_model_bytes_loaded: u64,
    pub drafter_model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
    pub first_token_claim_count: u64,
    pub product_speedup_claim_count: u64,
    pub quality_improvement_claim_count: u64,
    pub mas_readiness_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub hidden_route_authority_count: u64,
    pub hidden_cloud_fallback_count: u64,
}

impl Gemma4MtpDrafterCompatibilitySet {
    pub fn new(
        mut cards: Vec<Gemma4MtpDrafterCompatibilityCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, Gemma4MtpDrafterCompatibilityError> {
        validate_cards(&cards, metadata_bytes)?;
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let preimage = set_preimage(&cards, metadata_bytes);
        Ok(Self {
            set_address: UasAddress::new(
                UasKind::Other(GEMMA4_MTP_DRAFTER_COMPATIBILITY_CARD_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            cards,
            metadata_bytes,
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            product_promotion_blocked: true,
            hidden_authority_blocked: true,
        })
    }

    pub fn metrics(&self) -> Gemma4MtpDrafterCompatibilityMetrics {
        let mut target_models = HashSet::new();
        let mut drafter_models = HashSet::new();
        let mut runtime_lanes = HashSet::new();
        let mut max_reported_speedup_upper_bound_bps = 0_u64;
        let mut metadata_bytes_read = 0_u64;
        let mut target_model_bytes_loaded = 0_u64;
        let mut drafter_model_bytes_loaded = 0_u64;
        let mut runtime_bytes_loaded = 0_u64;
        let mut provider_calls_made = 0_u64;
        let mut product_files_copied = 0_u64;
        let mut first_token_claim_count = 0_u64;
        let mut product_speedup_claim_count = 0_u64;
        let mut quality_improvement_claim_count = 0_u64;
        let mut mas_readiness_claim_count = 0_u64;
        let mut live_dense_70b_claim_count = 0_u64;
        let mut hidden_route_authority_count = 0_u64;
        let mut hidden_cloud_fallback_count = 0_u64;

        for card in &self.cards {
            target_models.insert(card.target_model_id.clone());
            drafter_models.insert(card.drafter_model_id.clone());
            runtime_lanes.insert(card.runtime_lane);
            max_reported_speedup_upper_bound_bps =
                max_reported_speedup_upper_bound_bps.max(card.reported_speedup_upper_bound_bps);
            metadata_bytes_read += card.byte_scope.metadata_bytes_read;
            target_model_bytes_loaded += card.byte_scope.target_model_bytes_loaded;
            drafter_model_bytes_loaded += card.byte_scope.drafter_model_bytes_loaded;
            runtime_bytes_loaded += card.byte_scope.runtime_bytes_loaded;
            provider_calls_made += card.byte_scope.provider_calls_made;
            product_files_copied += card.byte_scope.product_files_copied;
            first_token_claim_count += card.first_token_claimed as u64;
            product_speedup_claim_count += card.product_speedup_claimed as u64;
            quality_improvement_claim_count += card.quality_improvement_claimed as u64;
            mas_readiness_claim_count += card.mas_readiness_claimed as u64;
            live_dense_70b_claim_count += card.live_dense_70b_claimed as u64;
            hidden_route_authority_count += card.hidden_route_authority_allowed as u64;
            hidden_cloud_fallback_count += card.hidden_cloud_fallback_allowed as u64;
        }

        Gemma4MtpDrafterCompatibilityMetrics {
            card_count: self.cards.len() as u64,
            target_model_count: target_models.len() as u64,
            drafter_model_count: drafter_models.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            max_reported_speedup_upper_bound_bps,
            metadata_bytes_read,
            target_model_bytes_loaded,
            drafter_model_bytes_loaded,
            runtime_bytes_loaded,
            provider_calls_made,
            product_files_copied,
            first_token_claim_count,
            product_speedup_claim_count,
            quality_improvement_claim_count,
            mas_readiness_claim_count,
            live_dense_70b_claim_count,
            hidden_route_authority_count,
            hidden_cloud_fallback_count,
        }
    }
}

// UAS: uas:gemma4-mtp-drafter:error
// Plane: Verification
// Residency: fail-closed MTP source-card validation diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Gemma4MtpDrafterCompatibilityError {
    EmptyCardSet,
    MetadataBudgetExceeded,
    DuplicateCardId(String),
    MissingField(&'static str),
    FieldWhitespace(&'static str),
    NonHttpsUrl(String),
    UnsupportedLicense(String),
    BadRevision(String),
    TargetDrafterSizeMismatch(String),
    DrafterNotAssistant(String),
    UnsupportedRuntimeLane,
    ProductBuildNotPro,
    ProStatusNotResearchCandidate,
    PromotionTierNotT1,
    SpeedupSourceUnbounded,
    TargetVerificationMissing,
    TokenVisibilityMissing,
    FinalOutputNotTargetOnly,
    HiddenAlternateTextNotBlocked,
    HiddenChainNotBlocked,
    QualityMetricMissing,
    AcceptanceMetricMissing,
    LatencyBudgetMissing,
    ExtraMemoryBudgetMissing,
    AbstentionMissing,
    RollbackMissing,
    RunEventLogMissing,
    AnswerPacketMissing,
    RuntimeNotDeferred,
    LayerSeparationMissing,
    ProductPromotionNotBlocked,
    BadProofRefPrefix(&'static str),
    TargetModelBytesLoaded,
    DrafterModelBytesLoaded,
    RuntimeBytesLoaded,
    ProviderCallMade,
    ProductFileCopied,
    FirstTokenClaim,
    ProductSpeedupClaim,
    QualityImprovementClaim,
    MasReadinessClaim,
    LiveDense70BClaim,
    HiddenRouteAuthority,
    HiddenCloudFallback,
}

impl fmt::Display for Gemma4MtpDrafterCompatibilityError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "MTP compatibility set is empty"),
            Self::MetadataBudgetExceeded => write!(f, "MTP compatibility metadata budget exceeded"),
            Self::DuplicateCardId(id) => write!(f, "duplicate MTP compatibility card id: {id}"),
            Self::MissingField(field) => write!(f, "missing MTP compatibility field: {field}"),
            Self::FieldWhitespace(field) => {
                write!(f, "MTP compatibility field has edge whitespace: {field}")
            }
            Self::NonHttpsUrl(url) => write!(f, "MTP compatibility URL is not HTTPS: {url}"),
            Self::UnsupportedLicense(license) => {
                write!(f, "unsupported MTP compatibility license: {license}")
            }
            Self::BadRevision(revision) => write!(f, "bad model revision: {revision}"),
            Self::TargetDrafterSizeMismatch(id) => {
                write!(f, "target and drafter size class mismatch: {id}")
            }
            Self::DrafterNotAssistant(id) => write!(f, "drafter is not an assistant model: {id}"),
            Self::UnsupportedRuntimeLane => write!(f, "unsupported MTP runtime lane"),
            Self::ProductBuildNotPro => write!(f, "MTP compatibility card must stay Pro"),
            Self::ProStatusNotResearchCandidate => {
                write!(f, "MTP compatibility card must stay Pro ResearchCandidate")
            }
            Self::PromotionTierNotT1 => write!(f, "MTP compatibility card must stay T1/L1"),
            Self::SpeedupSourceUnbounded => write!(f, "MTP speedup source is unbounded or absent"),
            Self::TargetVerificationMissing => {
                write!(f, "target-token verification requirement missing")
            }
            Self::TokenVisibilityMissing => write!(f, "draft-token visibility requirement missing"),
            Self::FinalOutputNotTargetOnly => write!(f, "final output is not target-only"),
            Self::HiddenAlternateTextNotBlocked => write!(f, "hidden alternate text not blocked"),
            Self::HiddenChainNotBlocked => write!(f, "hidden chain not blocked"),
            Self::QualityMetricMissing => write!(f, "quality metric requirement missing"),
            Self::AcceptanceMetricMissing => write!(f, "acceptance metric requirement missing"),
            Self::LatencyBudgetMissing => write!(f, "latency budget requirement missing"),
            Self::ExtraMemoryBudgetMissing => write!(f, "extra memory budget requirement missing"),
            Self::AbstentionMissing => write!(f, "MTP abstention requirement missing"),
            Self::RollbackMissing => write!(f, "MTP rollback requirement missing"),
            Self::RunEventLogMissing => write!(f, "MTP RunEventLog requirement missing"),
            Self::AnswerPacketMissing => write!(f, "MTP AnswerPacket requirement missing"),
            Self::RuntimeNotDeferred => write!(f, "MTP runtime is not deferred"),
            Self::LayerSeparationMissing => write!(f, "MTP L1/L2/L3 separation missing"),
            Self::ProductPromotionNotBlocked => write!(f, "MTP product promotion not blocked"),
            Self::BadProofRefPrefix(field) => write!(f, "bad proof ref prefix: {field}"),
            Self::TargetModelBytesLoaded => write!(f, "target model bytes loaded"),
            Self::DrafterModelBytesLoaded => write!(f, "drafter model bytes loaded"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::ProviderCallMade => write!(f, "provider call made"),
            Self::ProductFileCopied => write!(f, "product file copied"),
            Self::FirstTokenClaim => write!(f, "first-token claim made"),
            Self::ProductSpeedupClaim => write!(f, "product speedup claim made"),
            Self::QualityImprovementClaim => write!(f, "quality improvement claim made"),
            Self::MasReadinessClaim => write!(f, "MAS readiness claim made"),
            Self::LiveDense70BClaim => write!(f, "live dense 70B claim made"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority allowed"),
            Self::HiddenCloudFallback => write!(f, "hidden cloud fallback allowed"),
        }
    }
}

impl std::error::Error for Gemma4MtpDrafterCompatibilityError {}

fn validate_cards(
    cards: &[Gemma4MtpDrafterCompatibilityCard],
    metadata_bytes: u64,
) -> Result<(), Gemma4MtpDrafterCompatibilityError> {
    if cards.is_empty() {
        return Err(Gemma4MtpDrafterCompatibilityError::EmptyCardSet);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(Gemma4MtpDrafterCompatibilityError::MetadataBudgetExceeded);
    }

    let mut ids = HashSet::new();
    for card in cards {
        if !ids.insert(card.card_id.clone()) {
            return Err(Gemma4MtpDrafterCompatibilityError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        validate_card(card)?;
    }
    Ok(())
}

fn validate_card(
    card: &Gemma4MtpDrafterCompatibilityCard,
) -> Result<(), Gemma4MtpDrafterCompatibilityError> {
    require_clean("card_id", &card.card_id)?;
    require_clean("target_model_id", &card.target_model_id)?;
    require_clean("target_revision", &card.target_revision)?;
    require_clean("drafter_model_id", &card.drafter_model_id)?;
    require_clean("drafter_revision", &card.drafter_revision)?;
    require_clean("license_spdx", &card.license_spdx)?;
    require_clean("mtp_source_summary_ref", &card.mtp_source_summary_ref)?;

    for url in [
        &card.target_model_url,
        &card.drafter_model_url,
        &card.mtp_source_url,
    ] {
        if !url.starts_with(HTTPS_PREFIX) {
            return Err(Gemma4MtpDrafterCompatibilityError::NonHttpsUrl(url.clone()));
        }
    }

    if card.license_spdx != "Apache-2.0" {
        return Err(Gemma4MtpDrafterCompatibilityError::UnsupportedLicense(
            card.license_spdx.clone(),
        ));
    }
    if !is_hex_revision(&card.target_revision) {
        return Err(Gemma4MtpDrafterCompatibilityError::BadRevision(
            card.target_revision.clone(),
        ));
    }
    if !is_hex_revision(&card.drafter_revision) {
        return Err(Gemma4MtpDrafterCompatibilityError::BadRevision(
            card.drafter_revision.clone(),
        ));
    }
    if !card.drafter_model_id.ends_with("-assistant") {
        return Err(Gemma4MtpDrafterCompatibilityError::DrafterNotAssistant(
            card.drafter_model_id.clone(),
        ));
    }
    if model_size_class(&card.target_model_id) != model_size_class(&card.drafter_model_id) {
        return Err(
            Gemma4MtpDrafterCompatibilityError::TargetDrafterSizeMismatch(card.card_id.clone()),
        );
    }

    if card.runtime_lane == Gemma4MtpRuntimeLane::NoRuntime {
        return Err(Gemma4MtpDrafterCompatibilityError::UnsupportedRuntimeLane);
    }
    if card.product_build != ProductBuild::Pro {
        return Err(Gemma4MtpDrafterCompatibilityError::ProductBuildNotPro);
    }
    if card.pro_status != ProStatus::ResearchCandidate {
        return Err(Gemma4MtpDrafterCompatibilityError::ProStatusNotResearchCandidate);
    }
    if card.promotion_tier != Gemma4MtpPromotionTier::T1L1Metadata {
        return Err(Gemma4MtpDrafterCompatibilityError::PromotionTierNotT1);
    }
    if card.reported_speedup_upper_bound_bps == 0 || card.reported_speedup_upper_bound_bps > 30_000
    {
        return Err(Gemma4MtpDrafterCompatibilityError::SpeedupSourceUnbounded);
    }
    if !card.target_verifies_draft_tokens {
        return Err(Gemma4MtpDrafterCompatibilityError::TargetVerificationMissing);
    }
    if !card.accepted_tokens_visible || !card.rejected_tokens_visible {
        return Err(Gemma4MtpDrafterCompatibilityError::TokenVisibilityMissing);
    }
    if !card.final_output_from_target_only {
        return Err(Gemma4MtpDrafterCompatibilityError::FinalOutputNotTargetOnly);
    }
    if !card.hidden_alternate_text_blocked {
        return Err(Gemma4MtpDrafterCompatibilityError::HiddenAlternateTextNotBlocked);
    }
    if !card.hidden_chain_blocked {
        return Err(Gemma4MtpDrafterCompatibilityError::HiddenChainNotBlocked);
    }
    if !card.quality_metric_required {
        return Err(Gemma4MtpDrafterCompatibilityError::QualityMetricMissing);
    }
    if !card.acceptance_metric_required {
        return Err(Gemma4MtpDrafterCompatibilityError::AcceptanceMetricMissing);
    }
    if !card.latency_budget_required {
        return Err(Gemma4MtpDrafterCompatibilityError::LatencyBudgetMissing);
    }
    if !card.extra_memory_budget_required {
        return Err(Gemma4MtpDrafterCompatibilityError::ExtraMemoryBudgetMissing);
    }
    if !card.abstention_required {
        return Err(Gemma4MtpDrafterCompatibilityError::AbstentionMissing);
    }
    if !card.rollback_required {
        return Err(Gemma4MtpDrafterCompatibilityError::RollbackMissing);
    }
    if !card.run_event_log_required {
        return Err(Gemma4MtpDrafterCompatibilityError::RunEventLogMissing);
    }
    if !card.answer_packet_required {
        return Err(Gemma4MtpDrafterCompatibilityError::AnswerPacketMissing);
    }
    if !card.runtime_deferred {
        return Err(Gemma4MtpDrafterCompatibilityError::RuntimeNotDeferred);
    }
    if !card.l1_l2_l3_separated {
        return Err(Gemma4MtpDrafterCompatibilityError::LayerSeparationMissing);
    }
    if !card.product_promotion_blocked {
        return Err(Gemma4MtpDrafterCompatibilityError::ProductPromotionNotBlocked);
    }
    validate_proof_refs(&card.proof_refs)?;
    validate_byte_scope(&card.byte_scope)?;

    if card.first_token_claimed {
        return Err(Gemma4MtpDrafterCompatibilityError::FirstTokenClaim);
    }
    if card.product_speedup_claimed {
        return Err(Gemma4MtpDrafterCompatibilityError::ProductSpeedupClaim);
    }
    if card.quality_improvement_claimed {
        return Err(Gemma4MtpDrafterCompatibilityError::QualityImprovementClaim);
    }
    if card.mas_readiness_claimed {
        return Err(Gemma4MtpDrafterCompatibilityError::MasReadinessClaim);
    }
    if card.live_dense_70b_claimed {
        return Err(Gemma4MtpDrafterCompatibilityError::LiveDense70BClaim);
    }
    if card.hidden_route_authority_allowed {
        return Err(Gemma4MtpDrafterCompatibilityError::HiddenRouteAuthority);
    }
    if card.hidden_cloud_fallback_allowed {
        return Err(Gemma4MtpDrafterCompatibilityError::HiddenCloudFallback);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &Gemma4MtpProofRefs,
) -> Result<(), Gemma4MtpDrafterCompatibilityError> {
    for (field, value, prefix) in [
        (
            "litert_admission_ref",
            &refs.litert_admission_ref,
            LITERT_ADMISSION_PREFIX,
        ),
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
            COMPATIBILITY_PREFIX,
        ),
        (
            "quality_ledger_ref",
            &refs.quality_ledger_ref,
            QUALITY_LEDGER_PREFIX,
        ),
        (
            "acceptance_metric_ref",
            &refs.acceptance_metric_ref,
            ACCEPTANCE_METRIC_PREFIX,
        ),
        (
            "latency_budget_ref",
            &refs.latency_budget_ref,
            LATENCY_BUDGET_PREFIX,
        ),
        (
            "extra_memory_budget_ref",
            &refs.extra_memory_budget_ref,
            EXTRA_MEMORY_BUDGET_PREFIX,
        ),
        ("abstention_ref", &refs.abstention_ref, ABSTENTION_PREFIX),
    ] {
        require_clean(field, value)?;
        if !value.starts_with(prefix) {
            return Err(Gemma4MtpDrafterCompatibilityError::BadProofRefPrefix(field));
        }
    }
    Ok(())
}

fn validate_byte_scope(
    scope: &Gemma4MtpByteScope,
) -> Result<(), Gemma4MtpDrafterCompatibilityError> {
    if scope.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(Gemma4MtpDrafterCompatibilityError::MetadataBudgetExceeded);
    }
    if scope.target_model_bytes_loaded > 0 {
        return Err(Gemma4MtpDrafterCompatibilityError::TargetModelBytesLoaded);
    }
    if scope.drafter_model_bytes_loaded > 0 {
        return Err(Gemma4MtpDrafterCompatibilityError::DrafterModelBytesLoaded);
    }
    if scope.runtime_bytes_loaded > 0 {
        return Err(Gemma4MtpDrafterCompatibilityError::RuntimeBytesLoaded);
    }
    if scope.provider_calls_made > 0 {
        return Err(Gemma4MtpDrafterCompatibilityError::ProviderCallMade);
    }
    if scope.product_files_copied > 0 {
        return Err(Gemma4MtpDrafterCompatibilityError::ProductFileCopied);
    }
    Ok(())
}

fn require_clean(
    field: &'static str,
    value: &str,
) -> Result<(), Gemma4MtpDrafterCompatibilityError> {
    if value.is_empty() {
        return Err(Gemma4MtpDrafterCompatibilityError::MissingField(field));
    }
    if value.trim() != value {
        return Err(Gemma4MtpDrafterCompatibilityError::FieldWhitespace(field));
    }
    Ok(())
}

fn is_hex_revision(value: &str) -> bool {
    value.len() == 40 && value.chars().all(|ch| ch.is_ascii_hexdigit())
}

fn model_size_class(model_id: &str) -> Option<&'static str> {
    if model_id.contains("E2B") {
        Some("e2b")
    } else if model_id.contains("E4B") {
        Some("e4b")
    } else if model_id.contains("12B") {
        Some("12b")
    } else if model_id.contains("31B") {
        Some("31b")
    } else {
        None
    }
}

fn set_preimage(cards: &[Gemma4MtpDrafterCompatibilityCard], metadata_bytes: u64) -> String {
    let mut parts = vec![GEMMA4_MTP_DRAFTER_COMPATIBILITY_CARD_CURSOR.to_string()];
    parts.push(format!("metadata_bytes={metadata_bytes}"));
    for card in cards {
        parts.push(format!(
            "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
            card.card_id,
            card.target_model_id,
            card.target_revision,
            card.drafter_model_id,
            card.drafter_revision,
            card.license_spdx,
            card.mtp_source_url,
            card.reported_speedup_upper_bound_bps,
            runtime_lane_preimage(card.runtime_lane),
            product_build_preimage(&card.product_build),
            pro_status_preimage(&card.pro_status),
            promotion_tier_preimage(card.promotion_tier),
            card.proof_refs.litert_admission_ref,
        ));
    }
    parts.join("\n")
}

fn runtime_lane_preimage(lane: Gemma4MtpRuntimeLane) -> &'static str {
    match lane {
        Gemma4MtpRuntimeLane::LiteRtLm => "litert_lm",
        Gemma4MtpRuntimeLane::GgufLlamaCpp => "gguf_llama_cpp",
        Gemma4MtpRuntimeLane::MlxSwiftCandidate => "mlx_swift_candidate",
        Gemma4MtpRuntimeLane::TransformersResearch => "transformers_research",
        Gemma4MtpRuntimeLane::NoRuntime => "no_runtime",
    }
}

fn promotion_tier_preimage(tier: Gemma4MtpPromotionTier) -> &'static str {
    match tier {
        Gemma4MtpPromotionTier::T0Research => "t0_research",
        Gemma4MtpPromotionTier::T1L1Metadata => "t1_l1_metadata",
        Gemma4MtpPromotionTier::T2L2Route => "t2_l2_route",
        Gemma4MtpPromotionTier::T3L3Wrv => "t3_l3_wrv",
        Gemma4MtpPromotionTier::T4BuildGreen => "t4_build_green",
        Gemma4MtpPromotionTier::T5FullSegment => "t5_full_segment",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn proof_refs() -> Gemma4MtpProofRefs {
        Gemma4MtpProofRefs {
            litert_admission_ref: "artifact:litertlm_native_swift_admission:result_json_pass"
                .to_string(),
            falsifier_ref: "falsifier:F-Gemma4-MTP-DrafterCompatibilityCard".to_string(),
            rollback_ref: "rollback:gemma4-mtp-source-card-only".to_string(),
            run_event_log_ref: "run_event_log:gemma4-mtp-draft-visibility".to_string(),
            answer_packet_ref: "answer_packet:gemma4-mtp-visible-caveat".to_string(),
            compatibility_fence_ref: "compat:gemma4-mtp-target-drafter-pair".to_string(),
            quality_ledger_ref: "quality_ledger:gemma4-mtp-target-verification".to_string(),
            acceptance_metric_ref: "acceptance_metric:gemma4-mtp-draft-token-rate".to_string(),
            latency_budget_ref: "latency_budget:gemma4-mtp-same-fixture".to_string(),
            extra_memory_budget_ref: "extra_memory_budget:gemma4-mtp-drafter".to_string(),
            abstention_ref: "abstain:gemma4-mtp-incompatible-or-over-budget".to_string(),
        }
    }

    fn accepted_card() -> Gemma4MtpDrafterCompatibilityCard {
        Gemma4MtpDrafterCompatibilityCard {
            card_id: "gemma4_12b_mtp_drafter_compatibility".to_string(),
            target_model_id: "google/gemma-4-12B-it".to_string(),
            target_model_url: "https://huggingface.co/google/gemma-4-12B-it".to_string(),
            target_revision: "5926caa4ec0cac5cbfadaf4077420520de1d5205".to_string(),
            drafter_model_id: "google/gemma-4-12B-it-assistant".to_string(),
            drafter_model_url: "https://huggingface.co/google/gemma-4-12B-it-assistant"
                .to_string(),
            drafter_revision: "3cb659f134dcc4c9c00c98b121c07e16dd3daf42".to_string(),
            license_spdx: "Apache-2.0".to_string(),
            mtp_source_url:
                "https://blog.google/innovation-and-ai/technology/developers-tools/multi-token-prediction-gemma-4/"
                    .to_string(),
            mtp_source_summary_ref: "source_summary:google-mtp-gemma-4".to_string(),
            runtime_lane: Gemma4MtpRuntimeLane::LiteRtLm,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: Gemma4MtpPromotionTier::T1L1Metadata,
            reported_speedup_upper_bound_bps: 30_000,
            target_verifies_draft_tokens: true,
            accepted_tokens_visible: true,
            rejected_tokens_visible: true,
            final_output_from_target_only: true,
            hidden_alternate_text_blocked: true,
            hidden_chain_blocked: true,
            quality_metric_required: true,
            acceptance_metric_required: true,
            latency_budget_required: true,
            extra_memory_budget_required: true,
            abstention_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            runtime_deferred: true,
            l1_l2_l3_separated: true,
            product_promotion_blocked: true,
            proof_refs: proof_refs(),
            byte_scope: Gemma4MtpByteScope::metadata_only(44_000),
            first_token_claimed: false,
            product_speedup_claimed: false,
            quality_improvement_claimed: false,
            mas_readiness_claimed: false,
            live_dense_70b_claimed: false,
            hidden_route_authority_allowed: false,
            hidden_cloud_fallback_allowed: false,
        }
    }

    #[test]
    fn accepted_card_builds_metadata_only_set() {
        let set = Gemma4MtpDrafterCompatibilitySet::new(vec![accepted_card()], 88_000, 1).unwrap();
        let metrics = set.metrics();
        assert_eq!(metrics.card_count, 1);
        assert_eq!(metrics.target_model_bytes_loaded, 0);
        assert_eq!(metrics.drafter_model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
    }

    #[test]
    fn mismatched_drafter_rejects() {
        let mut card = accepted_card();
        card.drafter_model_id = "google/gemma-4-E2B-it-assistant".to_string();
        let err = Gemma4MtpDrafterCompatibilitySet::new(vec![card], 88_000, 1).unwrap_err();
        assert_eq!(
            err,
            Gemma4MtpDrafterCompatibilityError::TargetDrafterSizeMismatch(
                "gemma4_12b_mtp_drafter_compatibility".to_string()
            )
        );
    }

    #[test]
    fn missing_quality_metric_rejects() {
        let mut card = accepted_card();
        card.quality_metric_required = false;
        let err = Gemma4MtpDrafterCompatibilitySet::new(vec![card], 88_000, 1).unwrap_err();
        assert_eq!(
            err,
            Gemma4MtpDrafterCompatibilityError::QualityMetricMissing
        );
    }

    #[test]
    fn runtime_bytes_reject() {
        let mut card = accepted_card();
        card.byte_scope.runtime_bytes_loaded = 1;
        let err = Gemma4MtpDrafterCompatibilitySet::new(vec![card], 88_000, 1).unwrap_err();
        assert_eq!(err, Gemma4MtpDrafterCompatibilityError::RuntimeBytesLoaded);
    }

    #[test]
    fn product_speedup_claim_rejects() {
        let mut card = accepted_card();
        card.product_speedup_claimed = true;
        let err = Gemma4MtpDrafterCompatibilitySet::new(vec![card], 88_000, 1).unwrap_err();
        assert_eq!(err, Gemma4MtpDrafterCompatibilityError::ProductSpeedupClaim);
    }
}
