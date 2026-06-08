//! Gemma preferred-family policy source cards.
//!
//! This primitive turns the Gemma 4 QAT "main model family" ambition into a
//! metadata-only policy packet. It permits Gemma to become the preferred source
//! family under RuntimeRouter/System G while rejecting any live default,
//! runtime, MAS, L2/L3, or 70B-style capability claim before later witnesses.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const GEMMA_MAIN_FAMILY_POLICY_SOURCE_CARD_CURSOR: &str =
    "gemma_main_family_policy_source_card";
pub const GEMMA_MAIN_FAMILY_POLICY_SOURCE_CARD_NEXT_CURSOR: &str =
    "gemma_qat_small_lane_owner_path_manifest";

const ARTIFACT_REF_PREFIX: &str = "artifact:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 80 * 1024;

// UAS: uas:gemma-main-family-policy:band
// Plane: Assembly + Controller
// Residency: preferred-family policy band, not model residency proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaFamilyPolicyBand {
    SmallWarmup,
    ProFlagship,
    VaultResearch,
    BlockedNativeLane,
}

// UAS: uas:gemma-main-family-policy:runtime-lane
// Plane: Controller
// Residency: lane policy only; no runtime bytes are loaded.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaFamilyRuntimeLane {
    GgufLlamaCpp,
    LiteRtLm,
    MlxSwift,
    MlxPythonResearch,
    NoRuntimeAbstention,
}

// UAS: uas:gemma-main-family-policy:status
// Plane: Verification
// Residency: policy status; `RuntimeLive` is forbidden in this L1 witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaFamilyPolicyStatus {
    PreferredSourceFamily,
    SmallLaneProbePending,
    ProFlagshipReplayPending,
    VaultOnly,
    BlockedLoader,
    RuntimeLive,
}

// UAS: uas:gemma-main-family-policy:proof-refs
// Plane: Verification
// Residency: visible proof handles required before later route work.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFamilyPolicyProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:gemma-main-family-policy:model-card
// Plane: State + Assembly + Controller + Verification
// Residency: model-family policy card only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaMainFamilyPolicyCard {
    pub card_id: String,
    pub upstream_candidate_ref: String,
    pub model_id: String,
    pub source_refs: Vec<String>,
    pub runtime_lanes: Vec<GemmaFamilyRuntimeLane>,
    pub policy_band: GemmaFamilyPolicyBand,
    pub policy_status: GemmaFamilyPolicyStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub proof_refs: GemmaFamilyPolicyProofRefs,
    pub required_next_falsifiers: Vec<String>,
    pub metadata_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub command_executions: u64,
    pub owner_path_manifest_required: bool,
    pub byte_kv_app_envelope_required: bool,
    pub redacted_first_token_required: bool,
    pub same_fixture_replay_required: bool,
    pub quality_replay_required: bool,
    pub settings_visibility_required: bool,
    pub answer_packet_route_explanation_required: bool,
    pub abstention_when_missing_proof: bool,
    pub runtime_deferred: bool,
    pub swift_mlx_loader_proven: bool,
    pub hardcoded_default_claimed: bool,
    pub live_default_claimed: bool,
    pub product_capability_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub l2_route_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
}

// UAS: uas:gemma-main-family-policy:set
// Plane: State + Assembly + Controller + Verification
// Residency: policy packet for later owner-path and runtime witnesses.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaMainFamilyPolicySet {
    pub set_address: UasAddress,
    pub upstream_candidate_witness_ref: String,
    pub upstream_gguf_admission_ref: String,
    pub upstream_litert_admission_ref: String,
    pub cards: Vec<GemmaMainFamilyPolicyCard>,
    pub family_preferred: bool,
    pub hardcoded_default_blocked: bool,
    pub smallest_verified_lane_first: bool,
    pub abstention_required: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-main-family-policy:metrics
// Plane: Verification
// Residency: derived metadata-only counts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaMainFamilyPolicyMetrics {
    pub card_count: u64,
    pub small_warmup_count: u64,
    pub pro_flagship_count: u64,
    pub vault_research_count: u64,
    pub blocked_loader_count: u64,
    pub runtime_lane_count: u64,
    pub required_falsifier_count: u64,
    pub metadata_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub command_executions: u64,
}

impl GemmaMainFamilyPolicySet {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_candidate_witness_ref: impl Into<String>,
        upstream_gguf_admission_ref: impl Into<String>,
        upstream_litert_admission_ref: impl Into<String>,
        mut cards: Vec<GemmaMainFamilyPolicyCard>,
        family_preferred: bool,
        hardcoded_default_blocked: bool,
        smallest_verified_lane_first: bool,
        abstention_required: bool,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaMainFamilyPolicyError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let upstream_candidate_witness_ref = upstream_candidate_witness_ref.into();
        let upstream_gguf_admission_ref = upstream_gguf_admission_ref.into();
        let upstream_litert_admission_ref = upstream_litert_admission_ref.into();
        let set = Self {
            set_address: UasAddress::new(
                UasKind::Other(GEMMA_MAIN_FAMILY_POLICY_SOURCE_CARD_CURSOR.to_string()),
                policy_set_preimage(
                    &upstream_candidate_witness_ref,
                    &upstream_gguf_admission_ref,
                    &upstream_litert_admission_ref,
                    &cards,
                    family_preferred,
                    hardcoded_default_blocked,
                    smallest_verified_lane_first,
                    abstention_required,
                    &product_build,
                    &pro_status,
                    metadata_bytes,
                )
                .as_bytes(),
                created_at_ms,
            ),
            upstream_candidate_witness_ref,
            upstream_gguf_admission_ref,
            upstream_litert_admission_ref,
            cards,
            family_preferred,
            hardcoded_default_blocked,
            smallest_verified_lane_first,
            abstention_required,
            product_build,
            pro_status,
            metadata_bytes,
        };
        set.validate()?;
        Ok(set)
    }

    pub fn validate(&self) -> Result<(), GemmaMainFamilyPolicyError> {
        if !self
            .upstream_candidate_witness_ref
            .starts_with(ARTIFACT_REF_PREFIX)
            || !self.upstream_candidate_witness_ref.contains("gemma_qat")
        {
            return Err(GemmaMainFamilyPolicyError::BadUpstreamRef(
                "candidate witness".to_string(),
            ));
        }
        if !self
            .upstream_gguf_admission_ref
            .starts_with(ARTIFACT_REF_PREFIX)
            || !self.upstream_gguf_admission_ref.contains("gguf")
        {
            return Err(GemmaMainFamilyPolicyError::BadUpstreamRef(
                "gguf admission".to_string(),
            ));
        }
        if !self
            .upstream_litert_admission_ref
            .starts_with(ARTIFACT_REF_PREFIX)
            || !self.upstream_litert_admission_ref.contains("litertlm")
        {
            return Err(GemmaMainFamilyPolicyError::BadUpstreamRef(
                "litert admission".to_string(),
            ));
        }
        if self.cards.is_empty() {
            return Err(GemmaMainFamilyPolicyError::EmptyCardSet);
        }
        if self.metadata_bytes == 0 || self.metadata_bytes > MAX_SET_METADATA_BYTES {
            return Err(GemmaMainFamilyPolicyError::MetadataBudgetExceeded);
        }
        if !self.family_preferred
            || !self.hardcoded_default_blocked
            || !self.smallest_verified_lane_first
            || !self.abstention_required
        {
            return Err(GemmaMainFamilyPolicyError::MissingPolicyInvariant);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status == ProStatus::Live {
            return Err(GemmaMainFamilyPolicyError::PromotionClaim);
        }

        let mut ids = HashSet::with_capacity(self.cards.len());
        let mut models = HashSet::with_capacity(self.cards.len());
        for card in &self.cards {
            validate_card(card)?;
            if !ids.insert(card.card_id.as_str()) {
                return Err(GemmaMainFamilyPolicyError::DuplicateCardId(
                    card.card_id.clone(),
                ));
            }
            if !models.insert(card.model_id.as_str()) {
                return Err(GemmaMainFamilyPolicyError::DuplicateModelId(
                    card.model_id.clone(),
                ));
            }
        }

        let metrics = self.metrics();
        if metrics.small_warmup_count < 2
            || metrics.pro_flagship_count < 1
            || metrics.vault_research_count < 2
            || metrics.blocked_loader_count < 1
        {
            return Err(GemmaMainFamilyPolicyError::MissingRequiredBand);
        }
        if metrics.model_bytes_loaded != 0
            || metrics.runtime_bytes_loaded != 0
            || metrics.provider_calls_made != 0
            || metrics.command_executions != 0
        {
            return Err(GemmaMainFamilyPolicyError::BytesOrCommandsObserved);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaMainFamilyPolicyMetrics {
        let mut lanes = BTreeSet::new();
        let mut falsifiers = BTreeSet::new();
        let mut small_warmup_count = 0;
        let mut pro_flagship_count = 0;
        let mut vault_research_count = 0;
        let mut blocked_loader_count = 0;
        let mut metadata_bytes_read = self.metadata_bytes;
        let mut model_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut provider_calls_made = 0;
        let mut command_executions = 0;

        for card in &self.cards {
            match card.policy_band {
                GemmaFamilyPolicyBand::SmallWarmup => small_warmup_count += 1,
                GemmaFamilyPolicyBand::ProFlagship => pro_flagship_count += 1,
                GemmaFamilyPolicyBand::VaultResearch => vault_research_count += 1,
                GemmaFamilyPolicyBand::BlockedNativeLane => blocked_loader_count += 1,
            }
            for lane in &card.runtime_lanes {
                lanes.insert(*lane);
            }
            for falsifier in &card.required_next_falsifiers {
                falsifiers.insert(falsifier.as_str());
            }
            metadata_bytes_read += card.metadata_bytes_read;
            model_bytes_loaded += card.model_bytes_loaded;
            runtime_bytes_loaded += card.runtime_bytes_loaded;
            provider_calls_made += card.provider_calls_made;
            command_executions += card.command_executions;
        }

        GemmaMainFamilyPolicyMetrics {
            card_count: self.cards.len() as u64,
            small_warmup_count,
            pro_flagship_count,
            vault_research_count,
            blocked_loader_count,
            runtime_lane_count: lanes.len() as u64,
            required_falsifier_count: falsifiers.len() as u64,
            metadata_bytes_read,
            model_bytes_loaded,
            runtime_bytes_loaded,
            provider_calls_made,
            command_executions,
        }
    }
}

fn validate_card(card: &GemmaMainFamilyPolicyCard) -> Result<(), GemmaMainFamilyPolicyError> {
    if card.card_id.trim().is_empty() || !card.card_id.is_ascii() {
        return Err(GemmaMainFamilyPolicyError::BadCardId);
    }
    if !card
        .upstream_candidate_ref
        .starts_with("gemma_qat_candidate:")
        && !card.upstream_candidate_ref.starts_with(ARTIFACT_REF_PREFIX)
    {
        return Err(GemmaMainFamilyPolicyError::BadUpstreamRef(
            card.card_id.clone(),
        ));
    }
    if !card.model_id.starts_with("google/") && !card.model_id.starts_with("mlx-community/") {
        return Err(GemmaMainFamilyPolicyError::BadModelId(
            card.model_id.clone(),
        ));
    }
    if card.source_refs.is_empty()
        || card
            .source_refs
            .iter()
            .any(|source| !source.starts_with("https://"))
    {
        return Err(GemmaMainFamilyPolicyError::BadSourceRef(
            card.card_id.clone(),
        ));
    }
    if card.runtime_lanes.is_empty() {
        return Err(GemmaMainFamilyPolicyError::MissingRuntimeLane(
            card.card_id.clone(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status == ProStatus::Live
        || card.policy_status == GemmaFamilyPolicyStatus::RuntimeLive
    {
        return Err(GemmaMainFamilyPolicyError::PromotionClaim);
    }
    if card.metadata_bytes_read == 0 || card.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(GemmaMainFamilyPolicyError::MetadataBudgetExceeded);
    }
    if !proof_refs_valid(&card.proof_refs) {
        return Err(GemmaMainFamilyPolicyError::BadProofRef(
            card.card_id.clone(),
        ));
    }
    if card.required_next_falsifiers.is_empty()
        || card
            .required_next_falsifiers
            .iter()
            .any(|id| !id.starts_with("F-"))
    {
        return Err(GemmaMainFamilyPolicyError::MissingNextFalsifier(
            card.card_id.clone(),
        ));
    }
    if !card.owner_path_manifest_required
        || !card.byte_kv_app_envelope_required
        || !card.redacted_first_token_required
        || !card.same_fixture_replay_required
        || !card.quality_replay_required
        || !card.settings_visibility_required
        || !card.answer_packet_route_explanation_required
        || !card.abstention_when_missing_proof
        || !card.runtime_deferred
    {
        return Err(GemmaMainFamilyPolicyError::MissingProofInvariant(
            card.card_id.clone(),
        ));
    }
    if card.swift_mlx_loader_proven
        || card.hardcoded_default_claimed
        || card.live_default_claimed
        || card.product_capability_claimed
        || card.mas_readiness_claimed
        || card.l2_route_claimed
        || card.l3_wrv_claimed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
    {
        return Err(GemmaMainFamilyPolicyError::PromotionClaim);
    }
    if card.model_bytes_loaded != 0
        || card.runtime_bytes_loaded != 0
        || card.provider_calls_made != 0
        || card.command_executions != 0
    {
        return Err(GemmaMainFamilyPolicyError::BytesOrCommandsObserved);
    }
    Ok(())
}

fn proof_refs_valid(proof_refs: &GemmaFamilyPolicyProofRefs) -> bool {
    proof_refs.falsifier_ref.starts_with(FALSIFIER_PREFIX)
        && proof_refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        && proof_refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        && proof_refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        && proof_refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_FENCE_PREFIX)
}

// UAS: uas:gemma-main-family-policy-source-card:error
// Plane: Verification.
// Residency: fail-closed Gemma family policy rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaMainFamilyPolicyError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelId(String),
    BadCardId,
    BadModelId(String),
    BadSourceRef(String),
    BadUpstreamRef(String),
    BadProofRef(String),
    MissingRuntimeLane(String),
    MissingNextFalsifier(String),
    MissingProofInvariant(String),
    MissingPolicyInvariant,
    MissingRequiredBand,
    MetadataBudgetExceeded,
    BytesOrCommandsObserved,
    PromotionClaim,
}

impl fmt::Display for GemmaMainFamilyPolicyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "Gemma policy set is empty"),
            Self::DuplicateCardId(id) => write!(f, "duplicate Gemma policy card id {id}"),
            Self::DuplicateModelId(id) => write!(f, "duplicate Gemma policy model id {id}"),
            Self::BadCardId => write!(f, "invalid Gemma policy card id"),
            Self::BadModelId(id) => write!(f, "invalid Gemma policy model id {id}"),
            Self::BadSourceRef(id) => write!(f, "invalid Gemma policy source ref for {id}"),
            Self::BadUpstreamRef(id) => write!(f, "invalid Gemma policy upstream ref {id}"),
            Self::BadProofRef(id) => write!(f, "invalid Gemma policy proof ref for {id}"),
            Self::MissingRuntimeLane(id) => write!(f, "missing runtime lane for {id}"),
            Self::MissingNextFalsifier(id) => write!(f, "missing next falsifier for {id}"),
            Self::MissingProofInvariant(id) => write!(f, "missing proof invariant for {id}"),
            Self::MissingPolicyInvariant => write!(f, "missing Gemma family policy invariant"),
            Self::MissingRequiredBand => write!(f, "missing required Gemma family policy band"),
            Self::MetadataBudgetExceeded => write!(f, "Gemma policy metadata budget exceeded"),
            Self::BytesOrCommandsObserved => write!(f, "Gemma policy observed bytes or commands"),
            Self::PromotionClaim => write!(f, "Gemma policy tried to promote product capability"),
        }
    }
}

impl std::error::Error for GemmaMainFamilyPolicyError {}

fn policy_set_preimage(
    upstream_candidate_witness_ref: &str,
    upstream_gguf_admission_ref: &str,
    upstream_litert_admission_ref: &str,
    cards: &[GemmaMainFamilyPolicyCard],
    family_preferred: bool,
    hardcoded_default_blocked: bool,
    smallest_verified_lane_first: bool,
    abstention_required: bool,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
) -> String {
    let mut preimage = format!(
        "gemma_main_family_policy_source_card_v1\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{:?}\n{:?}\n{}\n",
        upstream_candidate_witness_ref,
        upstream_gguf_admission_ref,
        upstream_litert_admission_ref,
        family_preferred,
        hardcoded_default_blocked,
        smallest_verified_lane_first,
        abstention_required,
        product_build,
        pro_status,
        metadata_bytes
    );
    for card in cards {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.card_id,
            card.upstream_candidate_ref,
            card.model_id,
            card.runtime_lanes,
            card.policy_band,
            card.policy_status,
            card.product_build,
            card.pro_status,
            card.source_refs.join("|"),
            card.required_next_falsifiers.join("|"),
            card.proof_refs.falsifier_ref,
            card.proof_refs.rollback_ref,
            card.proof_refs.run_event_log_ref,
            card.proof_refs.answer_packet_ref,
            card.proof_refs.compatibility_fence_ref,
            card.metadata_bytes_read,
            card.model_bytes_loaded,
            card.runtime_bytes_loaded,
            card.provider_calls_made,
            card.command_executions,
            card.owner_path_manifest_required,
            card.byte_kv_app_envelope_required,
            card.redacted_first_token_required,
            card.same_fixture_replay_required,
            card.quality_replay_required,
            card.settings_visibility_required,
            card.answer_packet_route_explanation_required,
            card.abstention_when_missing_proof,
            card.runtime_deferred,
            card.swift_mlx_loader_proven,
            card.hardcoded_default_claimed,
            card.live_default_claimed,
            card.product_capability_claimed,
            card.mas_readiness_claimed,
            card.l2_route_claimed,
            card.l3_wrv_claimed,
            card.live_dense_70b_claimed,
            card.hidden_route_authority_allowed
        ));
    }
    preimage
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_207_200_000;

    fn proof_refs(id: &str) -> GemmaFamilyPolicyProofRefs {
        GemmaFamilyPolicyProofRefs {
            falsifier_ref: format!("falsifier:F-GemmaMainFamilyPolicySourceCard:{id}"),
            rollback_ref: format!("rollback:gemma_main_family_policy:{id}"),
            run_event_log_ref: format!("run_event_log:gemma_main_family_policy:{id}"),
            answer_packet_ref: format!("answer_packet:gemma_main_family_policy:{id}"),
            compatibility_fence_ref: format!("compat:gemma_main_family_policy:{id}"),
        }
    }

    fn card(
        id: &str,
        model_id: &str,
        band: GemmaFamilyPolicyBand,
        status: GemmaFamilyPolicyStatus,
    ) -> GemmaMainFamilyPolicyCard {
        GemmaMainFamilyPolicyCard {
            card_id: id.to_string(),
            upstream_candidate_ref: format!("gemma_qat_candidate:{id}"),
            model_id: model_id.to_string(),
            source_refs: vec![format!("https://huggingface.co/{model_id}")],
            runtime_lanes: match band {
                GemmaFamilyPolicyBand::BlockedNativeLane => {
                    vec![GemmaFamilyRuntimeLane::MlxSwift]
                }
                GemmaFamilyPolicyBand::VaultResearch => {
                    vec![GemmaFamilyRuntimeLane::NoRuntimeAbstention]
                }
                _ => vec![
                    GemmaFamilyRuntimeLane::GgufLlamaCpp,
                    GemmaFamilyRuntimeLane::LiteRtLm,
                ],
            },
            policy_band: band,
            policy_status: status,
            product_build: ProductBuild::Pro,
            pro_status: match band {
                GemmaFamilyPolicyBand::VaultResearch => ProStatus::VaultPreserved,
                GemmaFamilyPolicyBand::BlockedNativeLane => ProStatus::Blocked,
                _ => ProStatus::Gated,
            },
            proof_refs: proof_refs(id),
            required_next_falsifiers: vec![
                "F-GemmaQATSmallLaneOwnerPathManifest".to_string(),
                "F-GemmaQATByteKVAppEnvelopePreflight".to_string(),
                "F-GemmaQATRedactedFirstTokenProbe".to_string(),
                "F-GemmaQATSameFixtureRuntimeReplay".to_string(),
            ],
            metadata_bytes_read: 12_000,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            command_executions: 0,
            owner_path_manifest_required: true,
            byte_kv_app_envelope_required: true,
            redacted_first_token_required: true,
            same_fixture_replay_required: true,
            quality_replay_required: true,
            settings_visibility_required: true,
            answer_packet_route_explanation_required: true,
            abstention_when_missing_proof: true,
            runtime_deferred: true,
            swift_mlx_loader_proven: false,
            hardcoded_default_claimed: false,
            live_default_claimed: false,
            product_capability_claimed: false,
            mas_readiness_claimed: false,
            l2_route_claimed: false,
            l3_wrv_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
        }
    }

    fn valid_cards() -> Vec<GemmaMainFamilyPolicyCard> {
        vec![
            card(
                "gemma4_e2b_qat_warmup_policy",
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                GemmaFamilyPolicyBand::SmallWarmup,
                GemmaFamilyPolicyStatus::SmallLaneProbePending,
            ),
            card(
                "gemma4_e4b_qat_warmup_policy",
                "google/gemma-4-E4B-it-qat-q4_0-gguf",
                GemmaFamilyPolicyBand::SmallWarmup,
                GemmaFamilyPolicyStatus::SmallLaneProbePending,
            ),
            card(
                "gemma4_12b_qat_pro_flagship_policy",
                "google/gemma-4-12B-it-qat-q4_0-gguf",
                GemmaFamilyPolicyBand::ProFlagship,
                GemmaFamilyPolicyStatus::ProFlagshipReplayPending,
            ),
            card(
                "gemma4_26b_a4b_qat_vault_policy",
                "google/gemma-4-26B-A4B-it-qat-q4_0-gguf",
                GemmaFamilyPolicyBand::VaultResearch,
                GemmaFamilyPolicyStatus::VaultOnly,
            ),
            card(
                "gemma4_31b_qat_vault_policy",
                "google/gemma-4-31B-it-qat-q4_0-gguf",
                GemmaFamilyPolicyBand::VaultResearch,
                GemmaFamilyPolicyStatus::VaultOnly,
            ),
            card(
                "gemma4_mlx_swift_loader_blocked_policy",
                "mlx-community/gemma-4-12B-it-qat-4bit",
                GemmaFamilyPolicyBand::BlockedNativeLane,
                GemmaFamilyPolicyStatus::BlockedLoader,
            ),
        ]
    }

    fn policy_set(
        cards: Vec<GemmaMainFamilyPolicyCard>,
    ) -> Result<GemmaMainFamilyPolicySet, GemmaMainFamilyPolicyError> {
        GemmaMainFamilyPolicySet::new(
            "artifact:gemma_qat_local_runtime_candidate_card:result",
            "artifact:gguf_in_process_runtime_admission_packet:result",
            "artifact:litertlm_native_swift_admission:result",
            cards,
            true,
            true,
            true,
            true,
            ProductBuild::Pro,
            ProStatus::Gated,
            64_000,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_order_stable_gemma_family_policy() {
        let mut cards = valid_cards();
        let set = policy_set(cards.clone()).expect("policy should validate");
        cards.reverse();
        let reversed = policy_set(cards).expect("policy should validate");
        assert_eq!(set.set_address, reversed.set_address);
        assert_eq!(set.metrics().small_warmup_count, 2);
        assert_eq!(set.metrics().pro_flagship_count, 1);
        assert_eq!(set.metrics().vault_research_count, 2);
        assert_eq!(set.metrics().blocked_loader_count, 1);
        assert_eq!(set.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_hardcoded_live_default_claim() {
        let mut cards = valid_cards();
        cards[2].hardcoded_default_claimed = true;
        cards[2].live_default_claimed = true;
        assert!(policy_set(cards).is_err());
    }

    #[test]
    fn rejects_mas_or_l2_l3_promotion() {
        let mut cards = valid_cards();
        cards[0].product_build = ProductBuild::Mas;
        cards[0].l2_route_claimed = true;
        cards[0].l3_wrv_claimed = true;
        assert!(policy_set(cards).is_err());
    }

    #[test]
    fn rejects_swift_mlx_loader_bypass() {
        let mut cards = valid_cards();
        cards[5].swift_mlx_loader_proven = true;
        assert!(policy_set(cards).is_err());
    }

    #[test]
    fn rejects_missing_abstention_or_answer_packet() {
        let mut cards = valid_cards();
        cards[0].abstention_when_missing_proof = false;
        assert!(policy_set(cards.clone()).is_err());
        cards[0].abstention_when_missing_proof = true;
        cards[0].answer_packet_route_explanation_required = false;
        assert!(policy_set(cards).is_err());
    }

    #[test]
    fn rejects_runtime_bytes_or_commands() {
        let mut cards = valid_cards();
        cards[0].runtime_bytes_loaded = 1;
        cards[0].command_executions = 1;
        assert!(policy_set(cards).is_err());
    }
}
