//! Same-fixture runtime replay envelope.
//!
//! This primitive is the minimal metadata-only packet that future runtime
//! lanes cite before any GGUF, LiteRT-LM, MLX Swift, MLX-LM, vLLM/LMCache, or
//! custom Metal lane can be compared. It opens no model files, resolves no
//! packages, executes no commands, and promotes no product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, RuntimePluralQatPromotionTier, UasAddress, UasKind};

pub const SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_CURSOR: &str =
    "same_fixture_runtime_replay_envelope";
pub const SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_NEXT_CURSOR: &str =
    "same_fixture_runtime_replay_envelope_invalid_fixture_matrix";

const ARTIFACT_PREFIX: &str = "artifact:falsifiers/";
const SHA256_PREFIX: &str = "sha256:";
const FIXTURE_PREFIX: &str = "fixture:sha256:";
const HTTPS_PREFIX: &str = "https://";
const POLICY_PREFIX: &str = "policy:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:";
const LOADER_CAVEAT_PREFIX: &str = "loader_caveat:";
const CANCEL_PREFIX: &str = "cancel:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const QUALITY_PREFIX: &str = "quality_metric:";
const ABSTENTION_PREFIX: &str = "abstain:";
const MAX_CARD_METADATA_BYTES: u64 = 64 * 1024;
const MAX_ENVELOPE_METADATA_BYTES: u64 = 256 * 1024;

// UAS: uas:same-fixture-runtime-replay:lane
// Plane: Controller
// Residency: candidate runtime lane only; no runtime is opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SameFixtureRuntimeLane {
    GgufLlamaCpp,
    LiteRtLmSwift,
    MlxSwiftCandidate,
    MlxLmPythonResearch,
    NoRuntimeAbstention,
}

// UAS: uas:same-fixture-runtime-replay:lane-status
// Plane: Controller + Verification
// Residency: future participation status; not a route verdict.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SameFixtureRuntimeLaneStatus {
    FutureProbeCandidate,
    BlockedUntilAdmission,
    BlockedUntilLoader,
    QuarantineReference,
    DeferredAbstention,
}

// UAS: uas:same-fixture-runtime-replay:proof-refs
// Plane: Verification
// Residency: proof handles only; no bytes are opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SameFixtureRuntimeReplayProofRefs {
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub quality_metric_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:same-fixture-runtime-replay:byte-boundary
// Plane: Verification
// Residency: byte ledger; loaded/runtime/provider bytes must remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SameFixtureRuntimeReplayByteBoundary {
    pub selected_model_bytes: u64,
    pub resident_weight_budget: u64,
    pub kv_cache_budget: u64,
    pub runtime_workspace_budget: u64,
    pub app_headroom_budget: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl SameFixtureRuntimeReplayByteBoundary {
    pub fn metadata_only(
        selected_model_bytes: u64,
        resident_weight_budget: u64,
        kv_cache_budget: u64,
        runtime_workspace_budget: u64,
        app_headroom_budget: u64,
    ) -> Self {
        Self {
            selected_model_bytes,
            resident_weight_budget,
            kv_cache_budget,
            runtime_workspace_budget,
            app_headroom_budget,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:same-fixture-runtime-replay:lane-card
// Plane: State + Controller + Verification
// Residency: metadata-only lane card for future same-fixture replay.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SameFixtureRuntimeReplayLaneCard {
    pub lane_id: String,
    pub runtime_lane: SameFixtureRuntimeLane,
    pub lane_status: SameFixtureRuntimeLaneStatus,
    pub fixture_id: String,
    pub fixture_digest: String,
    pub canonical_serialization_digest: String,
    pub body_read_checksum_ref: String,
    pub search_index_freshness_ref: String,
    pub search_index_abstention_reason: String,
    pub source_revision_map_digest: String,
    pub retrieval_packet_digest: String,
    pub source_deleted_or_tombstoned_count: u64,
    pub redacted_prompt_digest: String,
    pub system_prompt_digest: String,
    pub tool_schema_digest: String,
    pub tokenizer_digest: String,
    pub chat_template_digest: String,
    pub tool_parser_policy: String,
    pub hidden_chain_denied: bool,
    pub raw_prompt_bytes_retained: bool,
    pub raw_tool_json_bytes_retained: bool,
    pub model_id: String,
    pub model_revision: String,
    pub selected_file_manifest_digest: String,
    pub declared_selected_file_bytes: u64,
    pub local_owner_manifest_ref: String,
    pub modality_subset: String,
    pub context_window_claim: u64,
    pub runtime_repo_url: String,
    pub runtime_revision_or_release: String,
    pub runtime_license_spdx: String,
    pub direct_cli_or_in_process: bool,
    pub server_sidecar_denied: bool,
    pub explicit_local_endpoint_default_denied: bool,
    pub command_envelope_ref: String,
    pub owner_approval_ref: String,
    pub loader_caveat_ref: String,
    pub cache_policy: String,
    pub cache_salt_digest: String,
    pub cache_hash_algorithm: String,
    pub cache_reuse_allowed: bool,
    pub cache_reuse_visible: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: RuntimePluralQatPromotionTier,
    pub l1_architecture_effect: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub t4_build_green_effect: bool,
    pub still_red: bool,
    pub mas_copy_allowed: bool,
    pub pro_copy_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub metadata_bytes: u64,
    pub byte_boundary: SameFixtureRuntimeReplayByteBoundary,
    pub proof_refs: SameFixtureRuntimeReplayProofRefs,
}

// UAS: uas:same-fixture-runtime-replay:envelope
// Plane: State + Controller + Verification
// Residency: metadata-only envelope; no runtime/model bytes load.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SameFixtureRuntimeReplayEnvelope {
    pub envelope_address: UasAddress,
    pub cards: Vec<SameFixtureRuntimeReplayLaneCard>,
    pub fixture_id: String,
    pub fixture_digest: String,
    pub canonical_serialization_digest: String,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub same_fixture_for_all_lanes: bool,
    pub no_runtime_execution: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub hidden_authority_blocked: bool,
}

// UAS: uas:same-fixture-runtime-replay:metrics
// Plane: Verification
// Residency: derived counters for same-fixture metadata witnesses.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SameFixtureRuntimeReplayMetrics {
    pub lane_card_count: u64,
    pub runtime_lane_count: u64,
    pub abstention_count: u64,
    pub future_probe_candidate_count: u64,
    pub blocked_until_admission_count: u64,
    pub blocked_until_loader_count: u64,
    pub quarantine_reference_count: u64,
    pub fixture_count: u64,
    pub prompt_digest_count: u64,
    pub tokenizer_digest_count: u64,
    pub chat_template_digest_count: u64,
    pub selected_model_bytes_total: u64,
    pub resident_weight_budget_total: u64,
    pub kv_cache_budget_total: u64,
    pub runtime_workspace_budget_total: u64,
    pub app_headroom_budget_total: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub l2_capability_effect_count: u64,
    pub l3_wrv_effect_count: u64,
    pub t4_build_green_effect_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
    pub server_sidecar_allowed_count: u64,
    pub local_endpoint_default_allowed_count: u64,
    pub raw_prompt_retention_count: u64,
    pub raw_tool_json_retention_count: u64,
}

impl SameFixtureRuntimeReplayEnvelope {
    pub fn new(
        mut cards: Vec<SameFixtureRuntimeReplayLaneCard>,
        metadata_bytes: u64,
        fixture_id: impl Into<String>,
        fixture_digest: impl Into<String>,
        canonical_serialization_digest: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, SameFixtureRuntimeReplayError> {
        let fixture_id = fixture_id.into();
        let fixture_digest = fixture_digest.into();
        let canonical_serialization_digest = canonical_serialization_digest.into();
        validate_envelope_inputs(
            &cards,
            metadata_bytes,
            &fixture_id,
            &fixture_digest,
            &canonical_serialization_digest,
        )?;
        cards.sort_by(|a, b| a.lane_id.cmp(&b.lane_id));
        let preimage = envelope_preimage(
            &cards,
            metadata_bytes,
            &fixture_id,
            &fixture_digest,
            &canonical_serialization_digest,
        );
        Ok(Self {
            envelope_address: UasAddress::new(
                UasKind::Other(SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            cards,
            fixture_id,
            fixture_digest,
            canonical_serialization_digest,
            metadata_bytes,
            metadata_only: true,
            same_fixture_for_all_lanes: true,
            no_runtime_execution: true,
            l1_l2_l3_separated: true,
            product_promotion_blocked: true,
            hidden_authority_blocked: true,
        })
    }

    pub fn metrics(&self) -> SameFixtureRuntimeReplayMetrics {
        let mut runtime_lanes = HashSet::new();
        let mut fixtures = BTreeSet::new();
        let mut prompt_digests = BTreeSet::new();
        let mut tokenizer_digests = BTreeSet::new();
        let mut template_digests = BTreeSet::new();
        let mut metrics = SameFixtureRuntimeReplayMetrics {
            lane_card_count: self.cards.len() as u64,
            runtime_lane_count: 0,
            abstention_count: 0,
            future_probe_candidate_count: 0,
            blocked_until_admission_count: 0,
            blocked_until_loader_count: 0,
            quarantine_reference_count: 0,
            fixture_count: 0,
            prompt_digest_count: 0,
            tokenizer_digest_count: 0,
            chat_template_digest_count: 0,
            selected_model_bytes_total: 0,
            resident_weight_budget_total: 0,
            kv_cache_budget_total: 0,
            runtime_workspace_budget_total: 0,
            app_headroom_budget_total: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            l2_capability_effect_count: 0,
            l3_wrv_effect_count: 0,
            t4_build_green_effect_count: 0,
            live_dense_70b_claim_count: 0,
            ssd_as_ram_claim_count: 0,
            server_sidecar_allowed_count: 0,
            local_endpoint_default_allowed_count: 0,
            raw_prompt_retention_count: 0,
            raw_tool_json_retention_count: 0,
        };

        for card in &self.cards {
            runtime_lanes.insert(card.runtime_lane);
            fixtures.insert(card.fixture_digest.clone());
            prompt_digests.insert(card.redacted_prompt_digest.clone());
            tokenizer_digests.insert(card.tokenizer_digest.clone());
            template_digests.insert(card.chat_template_digest.clone());
            match card.lane_status {
                SameFixtureRuntimeLaneStatus::FutureProbeCandidate => {
                    metrics.future_probe_candidate_count += 1
                }
                SameFixtureRuntimeLaneStatus::BlockedUntilAdmission => {
                    metrics.blocked_until_admission_count += 1
                }
                SameFixtureRuntimeLaneStatus::BlockedUntilLoader => {
                    metrics.blocked_until_loader_count += 1
                }
                SameFixtureRuntimeLaneStatus::QuarantineReference => {
                    metrics.quarantine_reference_count += 1
                }
                SameFixtureRuntimeLaneStatus::DeferredAbstention => metrics.abstention_count += 1,
            }
            metrics.selected_model_bytes_total = metrics
                .selected_model_bytes_total
                .saturating_add(card.byte_boundary.selected_model_bytes);
            metrics.resident_weight_budget_total = metrics
                .resident_weight_budget_total
                .saturating_add(card.byte_boundary.resident_weight_budget);
            metrics.kv_cache_budget_total = metrics
                .kv_cache_budget_total
                .saturating_add(card.byte_boundary.kv_cache_budget);
            metrics.runtime_workspace_budget_total = metrics
                .runtime_workspace_budget_total
                .saturating_add(card.byte_boundary.runtime_workspace_budget);
            metrics.app_headroom_budget_total = metrics
                .app_headroom_budget_total
                .saturating_add(card.byte_boundary.app_headroom_budget);
            metrics.runtime_bytes_loaded = metrics
                .runtime_bytes_loaded
                .saturating_add(card.byte_boundary.runtime_bytes_loaded);
            metrics.model_bytes_loaded = metrics
                .model_bytes_loaded
                .saturating_add(card.byte_boundary.model_bytes_loaded);
            metrics.provider_calls_made = metrics
                .provider_calls_made
                .saturating_add(card.byte_boundary.provider_calls_made);
            if card.l2_capability_effect {
                metrics.l2_capability_effect_count += 1;
            }
            if card.l3_wrv_effect {
                metrics.l3_wrv_effect_count += 1;
            }
            if card.t4_build_green_effect {
                metrics.t4_build_green_effect_count += 1;
            }
            if card.live_dense_70b_claimed {
                metrics.live_dense_70b_claim_count += 1;
            }
            if card.ssd_as_ram_claimed {
                metrics.ssd_as_ram_claim_count += 1;
            }
            if !card.server_sidecar_denied {
                metrics.server_sidecar_allowed_count += 1;
            }
            if !card.explicit_local_endpoint_default_denied {
                metrics.local_endpoint_default_allowed_count += 1;
            }
            if card.raw_prompt_bytes_retained {
                metrics.raw_prompt_retention_count += 1;
            }
            if card.raw_tool_json_bytes_retained {
                metrics.raw_tool_json_retention_count += 1;
            }
        }

        metrics.runtime_lane_count = runtime_lanes.len() as u64;
        metrics.fixture_count = fixtures.len() as u64;
        metrics.prompt_digest_count = prompt_digests.len() as u64;
        metrics.tokenizer_digest_count = tokenizer_digests.len() as u64;
        metrics.chat_template_digest_count = template_digests.len() as u64;
        metrics
    }
}

// UAS: uas:same-fixture-runtime-replay:error
// Plane: Verification
// Residency: validation failure only; no runtime side effects.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SameFixtureRuntimeReplayError {
    EmptyCards,
    MetadataBudget,
    InvalidEnvelope(String),
    InvalidCard(String),
    DuplicateLaneId(String),
}

impl fmt::Display for SameFixtureRuntimeReplayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCards => write!(f, "same-fixture envelope has no cards"),
            Self::MetadataBudget => write!(f, "same-fixture envelope metadata budget invalid"),
            Self::InvalidEnvelope(reason) => write!(f, "invalid same-fixture envelope: {reason}"),
            Self::InvalidCard(reason) => write!(f, "invalid same-fixture card: {reason}"),
            Self::DuplicateLaneId(id) => write!(f, "duplicate same-fixture lane id: {id}"),
        }
    }
}

impl std::error::Error for SameFixtureRuntimeReplayError {}

fn validate_envelope_inputs(
    cards: &[SameFixtureRuntimeReplayLaneCard],
    metadata_bytes: u64,
    fixture_id: &str,
    fixture_digest: &str,
    canonical_serialization_digest: &str,
) -> Result<(), SameFixtureRuntimeReplayError> {
    if cards.is_empty() {
        return Err(SameFixtureRuntimeReplayError::EmptyCards);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_ENVELOPE_METADATA_BYTES {
        return Err(SameFixtureRuntimeReplayError::MetadataBudget);
    }
    if !is_clean_id(fixture_id)
        || !fixture_digest.starts_with(FIXTURE_PREFIX)
        || !canonical_serialization_digest.starts_with(SHA256_PREFIX)
    {
        return Err(SameFixtureRuntimeReplayError::InvalidEnvelope(
            "fixture identity is not canonical".to_string(),
        ));
    }

    let mut lane_ids = HashSet::new();
    let mut lanes = HashSet::new();
    let mut statuses = HashSet::new();
    let mut has_abstention = false;
    for card in cards {
        validate_card(
            card,
            fixture_id,
            fixture_digest,
            canonical_serialization_digest,
        )?;
        if !lane_ids.insert(card.lane_id.clone()) {
            return Err(SameFixtureRuntimeReplayError::DuplicateLaneId(
                card.lane_id.clone(),
            ));
        }
        lanes.insert(card.runtime_lane);
        statuses.insert(card.lane_status);
        has_abstention |= card.runtime_lane == SameFixtureRuntimeLane::NoRuntimeAbstention
            && card.lane_status == SameFixtureRuntimeLaneStatus::DeferredAbstention;
    }

    if lanes.len() < 2 || !has_abstention {
        return Err(SameFixtureRuntimeReplayError::InvalidEnvelope(
            "runtime lane coverage or abstention card missing".to_string(),
        ));
    }
    if !statuses.contains(&SameFixtureRuntimeLaneStatus::FutureProbeCandidate)
        || !statuses.contains(&SameFixtureRuntimeLaneStatus::DeferredAbstention)
    {
        return Err(SameFixtureRuntimeReplayError::InvalidEnvelope(
            "future-probe and abstention statuses are required".to_string(),
        ));
    }
    Ok(())
}

fn validate_card(
    card: &SameFixtureRuntimeReplayLaneCard,
    fixture_id: &str,
    fixture_digest: &str,
    canonical_serialization_digest: &str,
) -> Result<(), SameFixtureRuntimeReplayError> {
    if !is_clean_id(&card.lane_id) || card.metadata_bytes == 0 {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "lane id or metadata bytes invalid".to_string(),
        ));
    }
    if !lane_status_matches(card.runtime_lane, card.lane_status) {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "runtime lane/status mismatch".to_string(),
        ));
    }
    if card.metadata_bytes > MAX_CARD_METADATA_BYTES {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "lane metadata budget exceeded".to_string(),
        ));
    }
    if card.fixture_id != fixture_id
        || card.fixture_digest != fixture_digest
        || card.canonical_serialization_digest != canonical_serialization_digest
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "same fixture identity drifted across lanes".to_string(),
        ));
    }
    if !card.body_read_checksum_ref.starts_with(ARTIFACT_PREFIX) {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "body-read checksum ref missing".to_string(),
        ));
    }
    if card.search_index_freshness_ref.is_empty()
        && !card
            .search_index_abstention_reason
            .starts_with(ABSTENTION_PREFIX)
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "search freshness requires artifact ref or abstention reason".to_string(),
        ));
    }
    for (label, digest) in [
        ("source revision map", &card.source_revision_map_digest),
        ("retrieval packet", &card.retrieval_packet_digest),
        ("redacted prompt", &card.redacted_prompt_digest),
        ("system prompt", &card.system_prompt_digest),
        ("tool schema", &card.tool_schema_digest),
        ("tokenizer", &card.tokenizer_digest),
        ("chat template", &card.chat_template_digest),
        (
            "selected file manifest",
            &card.selected_file_manifest_digest,
        ),
        ("cache salt", &card.cache_salt_digest),
    ] {
        if !digest.starts_with(SHA256_PREFIX) {
            return Err(SameFixtureRuntimeReplayError::InvalidCard(format!(
                "{label} digest missing"
            )));
        }
    }
    if !card.tool_parser_policy.starts_with(POLICY_PREFIX)
        || !card.hidden_chain_denied
        || card.raw_prompt_bytes_retained
        || card.raw_tool_json_bytes_retained
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "prompt/tool boundary invalid".to_string(),
        ));
    }
    if !card.runtime_repo_url.starts_with(HTTPS_PREFIX)
        || card.runtime_revision_or_release.is_empty()
        || !matches!(card.runtime_license_spdx.as_str(), "MIT" | "Apache-2.0")
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "runtime source metadata invalid".to_string(),
        ));
    }
    if card.runtime_lane != SameFixtureRuntimeLane::NoRuntimeAbstention
        && !card.direct_cli_or_in_process
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "runtime lane must declare direct CLI or in-process shape".to_string(),
        ));
    }
    if !card.server_sidecar_denied
        || !card.explicit_local_endpoint_default_denied
        || !card
            .command_envelope_ref
            .starts_with(COMMAND_ENVELOPE_PREFIX)
        || !card.owner_approval_ref.starts_with(OWNER_APPROVAL_PREFIX)
        || !card.loader_caveat_ref.starts_with(LOADER_CAVEAT_PREFIX)
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "runtime lane boundary invalid".to_string(),
        ));
    }
    if card.model_id.is_empty()
        || card.model_revision.is_empty()
        || card.local_owner_manifest_ref.is_empty()
        || card.modality_subset.is_empty()
        || card.context_window_claim == 0
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "model artifact boundary invalid".to_string(),
        ));
    }
    if card.runtime_lane != SameFixtureRuntimeLane::NoRuntimeAbstention
        && card.declared_selected_file_bytes == 0
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "selected model bytes missing".to_string(),
        ));
    }
    if card.cache_policy.is_empty()
        || card.cache_hash_algorithm.is_empty()
        || (card.cache_reuse_allowed && !card.cache_reuse_visible)
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "cache boundary invalid".to_string(),
        ));
    }
    if card.byte_boundary.runtime_bytes_loaded != 0
        || card.byte_boundary.model_bytes_loaded != 0
        || card.byte_boundary.provider_calls_made != 0
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "metadata-only envelope loaded runtime/model/provider bytes".to_string(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || matches!(card.pro_status, ProStatus::Live | ProStatus::Omega)
        || !matches!(
            card.promotion_tier,
            RuntimePluralQatPromotionTier::T0Research | RuntimePluralQatPromotionTier::T1L1Metadata
        )
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "product build or tier promotion invalid".to_string(),
        ));
    }
    if !card.l1_architecture_effect
        || card.l2_capability_effect
        || card.l3_wrv_effect
        || card.t4_build_green_effect
        || !card.still_red
        || card.mas_copy_allowed
        || !card.pro_copy_allowed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "promotion boundary invalid".to_string(),
        ));
    }
    validate_proof_refs(&card.proof_refs)
}

fn validate_proof_refs(
    refs: &SameFixtureRuntimeReplayProofRefs,
) -> Result<(), SameFixtureRuntimeReplayError> {
    if !refs.cancellation_ref.starts_with(CANCEL_PREFIX)
        || !refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        || !refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
        || !refs.quality_metric_ref.starts_with(QUALITY_PREFIX)
        || !refs.abstention_ref.starts_with(ABSTENTION_PREFIX)
    {
        return Err(SameFixtureRuntimeReplayError::InvalidCard(
            "proof refs invalid".to_string(),
        ));
    }
    Ok(())
}

fn envelope_preimage(
    cards: &[SameFixtureRuntimeReplayLaneCard],
    metadata_bytes: u64,
    fixture_id: &str,
    fixture_digest: &str,
    canonical_serialization_digest: &str,
) -> String {
    let mut sorted = cards.to_vec();
    sorted.sort_by(|a, b| a.lane_id.cmp(&b.lane_id));
    let lane_ids = sorted
        .iter()
        .map(|card| card.lane_id.as_str())
        .collect::<Vec<_>>()
        .join("|");
    format!(
        "same_fixture_runtime_replay_envelope_v1\n{metadata_bytes}\n{fixture_id}\n{fixture_digest}\n{canonical_serialization_digest}\n{lane_ids}"
    )
}

fn lane_status_matches(lane: SameFixtureRuntimeLane, status: SameFixtureRuntimeLaneStatus) -> bool {
    matches!(
        (lane, status),
        (
            SameFixtureRuntimeLane::GgufLlamaCpp,
            SameFixtureRuntimeLaneStatus::FutureProbeCandidate
        ) | (
            SameFixtureRuntimeLane::LiteRtLmSwift,
            SameFixtureRuntimeLaneStatus::BlockedUntilAdmission
        ) | (
            SameFixtureRuntimeLane::MlxSwiftCandidate,
            SameFixtureRuntimeLaneStatus::BlockedUntilLoader
        ) | (
            SameFixtureRuntimeLane::MlxLmPythonResearch,
            SameFixtureRuntimeLaneStatus::QuarantineReference
        ) | (
            SameFixtureRuntimeLane::NoRuntimeAbstention,
            SameFixtureRuntimeLaneStatus::DeferredAbstention
        )
    )
}

fn is_clean_id(value: &str) -> bool {
    !value.is_empty()
        && value
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-')
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_072_000_000;
    const FIXTURE_ID: &str = "same_fixture_runtime_replay_minimal_v1";
    const FIXTURE_DIGEST: &str = "fixture:sha256:same-fixture-runtime-replay-minimal-v1";
    const CANONICAL_DIGEST: &str = "sha256:canonical-same-fixture-runtime-replay-minimal-v1";

    #[test]
    fn deterministic_address_ignores_card_order() {
        let cards = accepted_cards();
        let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
        let a = accepted_envelope(cards).unwrap();
        let b = accepted_envelope(reversed).unwrap();
        assert_eq!(a.envelope_address, b.envelope_address);
    }

    #[test]
    fn rejects_missing_abstention_card() {
        let cards = accepted_cards()
            .into_iter()
            .filter(|card| card.runtime_lane != SameFixtureRuntimeLane::NoRuntimeAbstention)
            .collect::<Vec<_>>();
        assert!(accepted_envelope(cards).is_err());
    }

    #[test]
    fn rejects_raw_prompt_retention() {
        let mut cards = accepted_cards();
        cards[0].raw_prompt_bytes_retained = true;
        assert!(accepted_envelope(cards).is_err());
    }

    #[test]
    fn rejects_runtime_bytes_in_metadata_scope() {
        let mut cards = accepted_cards();
        cards[0].byte_boundary.runtime_bytes_loaded = 1;
        assert!(accepted_envelope(cards).is_err());
    }

    fn accepted_envelope(
        cards: Vec<SameFixtureRuntimeReplayLaneCard>,
    ) -> Result<SameFixtureRuntimeReplayEnvelope, SameFixtureRuntimeReplayError> {
        SameFixtureRuntimeReplayEnvelope::new(
            cards,
            160_000,
            FIXTURE_ID,
            FIXTURE_DIGEST,
            CANONICAL_DIGEST,
            CREATED_AT_MS,
        )
    }

    fn accepted_cards() -> Vec<SameFixtureRuntimeReplayLaneCard> {
        vec![
            card(
                "gguf_llama_cpp",
                SameFixtureRuntimeLane::GgufLlamaCpp,
                SameFixtureRuntimeLaneStatus::FutureProbeCandidate,
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                3_100_000_000,
            ),
            card(
                "litert_lm_swift",
                SameFixtureRuntimeLane::LiteRtLmSwift,
                SameFixtureRuntimeLaneStatus::BlockedUntilAdmission,
                "litert-community/gemma-4-E2B-it-litert-lm",
                3_100_000_000,
            ),
            card(
                "mlx_swift_candidate",
                SameFixtureRuntimeLane::MlxSwiftCandidate,
                SameFixtureRuntimeLaneStatus::BlockedUntilLoader,
                "mlx-community/gemma-4-E2B-it-4bit",
                3_100_000_000,
            ),
            card(
                "mlx_lm_python_research",
                SameFixtureRuntimeLane::MlxLmPythonResearch,
                SameFixtureRuntimeLaneStatus::QuarantineReference,
                "mlx-community/gemma-4-12b-8bit",
                12_000_000_000,
            ),
            card(
                "no_runtime_abstention",
                SameFixtureRuntimeLane::NoRuntimeAbstention,
                SameFixtureRuntimeLaneStatus::DeferredAbstention,
                "no-runtime",
                0,
            ),
        ]
    }

    fn card(
        lane_id: &str,
        runtime_lane: SameFixtureRuntimeLane,
        lane_status: SameFixtureRuntimeLaneStatus,
        model_id: &str,
        selected_bytes: u64,
    ) -> SameFixtureRuntimeReplayLaneCard {
        SameFixtureRuntimeReplayLaneCard {
            lane_id: lane_id.to_string(),
            runtime_lane,
            lane_status,
            fixture_id: FIXTURE_ID.to_string(),
            fixture_digest: FIXTURE_DIGEST.to_string(),
            canonical_serialization_digest: CANONICAL_DIGEST.to_string(),
            body_read_checksum_ref:
                "artifact:falsifiers/body_read_checksum_release_blocker_card/result.json"
                    .to_string(),
            search_index_freshness_ref: String::new(),
            search_index_abstention_reason: "abstain:search-index-release-blocker-card-not-landed"
                .to_string(),
            source_revision_map_digest: "sha256:source-revision-map".to_string(),
            retrieval_packet_digest: "sha256:retrieval-packet".to_string(),
            source_deleted_or_tombstoned_count: 0,
            redacted_prompt_digest: "sha256:redacted-prompt".to_string(),
            system_prompt_digest: "sha256:system-prompt".to_string(),
            tool_schema_digest: "sha256:tool-schema".to_string(),
            tokenizer_digest: "sha256:tokenizer".to_string(),
            chat_template_digest: "sha256:chat-template".to_string(),
            tool_parser_policy: "policy:gemma4-tool-parser-caveated".to_string(),
            hidden_chain_denied: true,
            raw_prompt_bytes_retained: false,
            raw_tool_json_bytes_retained: false,
            model_id: model_id.to_string(),
            model_revision: "source-card-revision".to_string(),
            selected_file_manifest_digest: "sha256:selected-file-manifest".to_string(),
            declared_selected_file_bytes: selected_bytes,
            local_owner_manifest_ref: "owner_manifest:not-present".to_string(),
            modality_subset: "text".to_string(),
            context_window_claim: 32_768,
            runtime_repo_url: "https://github.com/example/runtime".to_string(),
            runtime_revision_or_release: "source-card-release".to_string(),
            runtime_license_spdx: "Apache-2.0".to_string(),
            direct_cli_or_in_process: runtime_lane != SameFixtureRuntimeLane::NoRuntimeAbstention,
            server_sidecar_denied: true,
            explicit_local_endpoint_default_denied: true,
            command_envelope_ref: "command_envelope:unarmed".to_string(),
            owner_approval_ref: "owner_approval:not-granted".to_string(),
            loader_caveat_ref: "loader_caveat:metadata-only".to_string(),
            cache_policy: "salted-visible-cache-only".to_string(),
            cache_salt_digest: "sha256:cache-salt".to_string(),
            cache_hash_algorithm: "sha256_cbor".to_string(),
            cache_reuse_allowed: false,
            cache_reuse_visible: true,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
            l1_architecture_effect: true,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            t4_build_green_effect: false,
            still_red: true,
            mas_copy_allowed: false,
            pro_copy_allowed: true,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            metadata_bytes: 16_000,
            byte_boundary: SameFixtureRuntimeReplayByteBoundary::metadata_only(
                selected_bytes,
                selected_bytes.saturating_add(1),
                512_000_000,
                256_000_000,
                2_000_000_000,
            ),
            proof_refs: SameFixtureRuntimeReplayProofRefs {
                cancellation_ref: "cancel:same-fixture-runtime-replay".to_string(),
                rollback_ref: "rollback:same-fixture-runtime-replay".to_string(),
                run_event_log_ref: "run_event_log:same-fixture-runtime-replay".to_string(),
                answer_packet_ref: "answer_packet:same-fixture-runtime-replay".to_string(),
                quality_metric_ref: "quality_metric:same-fixture-runtime-replay".to_string(),
                abstention_ref: "abstain:same-fixture-runtime-replay".to_string(),
            },
        }
    }
}
