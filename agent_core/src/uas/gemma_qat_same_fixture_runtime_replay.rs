//! Gemma QAT same-fixture runtime replay envelope.
//!
//! This primitive consumes the Gemma redacted first-token preflight contract and
//! binds E2B/E4B GGUF/LiteRT lanes to one replay fixture before any runtime,
//! quality, cache, route, or product comparison can count.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    canonical_gemma_qat_redacted_first_token_cards, GemmaFamilyRuntimeLane, ProStatus,
    ProductBuild, UasAddress, UasKind,
};

pub const GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_ID: &str = "F-GemmaQATSameFixtureRuntimeReplay";
pub const GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_CURSOR: &str =
    "gemma_qat_same_fixture_runtime_replay";
pub const GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_NEXT_CURSOR: &str =
    "gemma_qat_held_out_quality_replay_packet";

pub const GEMMA_QAT_SAME_FIXTURE_ID: &str = "gemma_qat_same_fixture_replay_v1";
pub const GEMMA_QAT_SAME_FIXTURE_DIGEST: &str = "fixture:sha256:gemma-qat-same-fixture-replay-v1";
pub const GEMMA_QAT_CANONICAL_REPLAY_DIGEST: &str =
    "sha256:canonical-gemma-qat-same-fixture-replay-v1";

const UPSTREAM_FIRST_TOKEN_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_redacted_first_token_probe/";
const SHA256_PREFIX: &str = "sha256:";
const FIXTURE_PREFIX: &str = "fixture:sha256:";
const BODY_REF_PREFIX: &str = "artifact:falsifiers/body_read_checksum_release_blocker_card/";
const SOURCE_SEARCH_REF_PREFIX: &str = "source_search_freshness:";
const PROMPT_REF_PREFIX: &str = "prompt_digest:";
const TOKENIZER_REF_PREFIX: &str = "tokenizer_digest:";
const CHAT_TEMPLATE_REF_PREFIX: &str = "chat_template_digest:";
const TOOL_SCHEMA_REF_PREFIX: &str = "tool_schema_digest:";
const MEMORY_SAMPLE_REF_PREFIX: &str = "memory_sample:";
const CANCELLATION_REF_PREFIX: &str = "cancellation:";
const ROLLBACK_REF_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:";
const ABSTENTION_REF_PREFIX: &str = "abstention:";
const NO_PROMOTION_REF_PREFIX: &str = "non_promotion:";
const MAX_CARD_METADATA_BYTES: u64 = 72 * 1024;
const MAX_LEDGER_METADATA_BYTES: u64 = 256 * 1024;

// UAS: uas:gemma-qat-same-fixture-runtime-replay:state
// Plane: Verification.
// Residency: same-fixture replay contract only; no runtime lane is opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatReplayState {
    MetadataOnlyReplayDeferred,
}

// UAS: uas:gemma-qat-same-fixture-runtime-replay:proof-refs
// Plane: Verification.
// Residency: proof handles for future owner-approved runtime replay.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSameFixtureReplayProofRefs {
    pub upstream_first_token_ref: String,
    pub upstream_first_token_card_id: String,
    pub body_read_checksum_ref: String,
    pub source_search_freshness_ref: String,
    pub prompt_digest_ref: String,
    pub tokenizer_digest_ref: String,
    pub chat_template_digest_ref: String,
    pub tool_schema_digest_ref: String,
    pub memory_sample_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub no_promotion_ref: String,
}

// UAS: uas:gemma-qat-same-fixture-runtime-replay:byte-ledger
// Plane: Verification.
// Residency: byte ledger; runtime/model/prompt/token/cache bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSameFixtureReplayByteLedger {
    pub metadata_bytes_read: u64,
    pub fixture_descriptor_bytes: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_token_bytes_captured: u64,
    pub tool_json_bytes_captured: u64,
    pub local_file_bytes_read: u64,
    pub cache_bytes_reused: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub command_execution_count: u64,
    pub benchmark_runs: u64,
}

impl GemmaQatSameFixtureReplayByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64, fixture_descriptor_bytes: u64) -> Self {
        Self {
            metadata_bytes_read,
            fixture_descriptor_bytes,
            raw_prompt_bytes_captured: 0,
            raw_token_bytes_captured: 0,
            tool_json_bytes_captured: 0,
            local_file_bytes_read: 0,
            cache_bytes_reused: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            command_execution_count: 0,
            benchmark_runs: 0,
        }
    }

    fn live_bytes_or_actions_observed(&self) -> bool {
        self.raw_prompt_bytes_captured != 0
            || self.raw_token_bytes_captured != 0
            || self.tool_json_bytes_captured != 0
            || self.local_file_bytes_read != 0
            || self.cache_bytes_reused != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.command_execution_count != 0
            || self.benchmark_runs != 0
    }
}

// UAS: uas:gemma-qat-same-fixture-runtime-replay:card
// Plane: State + Controller + Verification.
// Residency: metadata-only replay card; no first token or quality run occurs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSameFixtureReplayCard {
    pub card_id: String,
    pub upstream_first_token_ref: String,
    pub upstream_first_token_card_id: String,
    pub model_id: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub state: GemmaQatReplayState,
    pub fixture_id: String,
    pub fixture_digest: String,
    pub canonical_replay_digest: String,
    pub source_search_freshness_bound: bool,
    pub body_read_checksum_bound: bool,
    pub redacted_prompt_digest_bound: bool,
    pub tokenizer_digest_bound: bool,
    pub chat_template_digest_bound: bool,
    pub tool_schema_digest_bound: bool,
    pub memory_sample_bound: bool,
    pub one_token_replay_bound: bool,
    pub cancellation_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub raw_prompt_denied: bool,
    pub raw_token_denied: bool,
    pub hidden_chain_denied: bool,
    pub cache_reuse_denied_until_lineage: bool,
    pub runtime_replay_deferred: bool,
    pub quality_comparison_deferred: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub l1_architecture_effect: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub route_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub product_route_green: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub byte_ledger: GemmaQatSameFixtureReplayByteLedger,
    pub proof_refs: GemmaQatSameFixtureReplayProofRefs,
    pub next_cursor: String,
}

// UAS: uas:gemma-qat-same-fixture-runtime-replay:ledger
// Plane: State + Verification.
// Residency: same-fixture replay ledger; metadata-only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSameFixtureReplayLedger {
    pub ledger_address: UasAddress,
    pub upstream_first_token_ref: String,
    pub fixture_id: String,
    pub fixture_digest: String,
    pub canonical_replay_digest: String,
    pub cards: Vec<GemmaQatSameFixtureReplayCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub same_fixture_for_all_cards: bool,
    pub runtime_replay_deferred: bool,
    pub quality_comparison_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-same-fixture-runtime-replay:metrics
// Plane: Verification.
// Residency: derived same-fixture metadata counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSameFixtureReplayMetrics {
    pub card_count: u64,
    pub e2b_card_count: u64,
    pub e4b_card_count: u64,
    pub gguf_lane_count: u64,
    pub litert_lane_count: u64,
    pub fixture_count: u64,
    pub prompt_digest_bound_count: u64,
    pub tokenizer_digest_bound_count: u64,
    pub chat_template_digest_bound_count: u64,
    pub tool_schema_digest_bound_count: u64,
    pub memory_sample_bound_count: u64,
    pub runtime_replay_deferred_count: u64,
    pub quality_comparison_deferred_count: u64,
    pub raw_prompt_bytes_captured_total: u64,
    pub raw_token_bytes_captured_total: u64,
    pub tool_json_bytes_captured_total: u64,
    pub local_file_bytes_read_total: u64,
    pub cache_bytes_reused_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub command_execution_count_total: u64,
    pub benchmark_runs_total: u64,
    pub l2_effect_count: u64,
    pub l3_effect_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub quality_claim_count: u64,
    pub metadata_bytes_read_total: u64,
}

impl GemmaQatSameFixtureReplayLedger {
    pub fn new(
        upstream_first_token_ref: impl Into<String>,
        mut cards: Vec<GemmaQatSameFixtureReplayCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatSameFixtureReplayError> {
        let upstream_first_token_ref = upstream_first_token_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_CURSOR.to_string()),
                replay_preimage(&upstream_first_token_ref, &cards, metadata_bytes).as_bytes(),
                created_at_ms,
            ),
            upstream_first_token_ref,
            fixture_id: GEMMA_QAT_SAME_FIXTURE_ID.to_string(),
            fixture_digest: GEMMA_QAT_SAME_FIXTURE_DIGEST.to_string(),
            canonical_replay_digest: GEMMA_QAT_CANONICAL_REPLAY_DIGEST.to_string(),
            cards,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            metadata_only: true,
            same_fixture_for_all_cards: true,
            runtime_replay_deferred: true,
            quality_comparison_deferred: true,
            product_promotion_blocked: true,
            metadata_bytes,
        };
        ledger.validate()?;
        Ok(ledger)
    }

    pub fn validate(&self) -> Result<(), GemmaQatSameFixtureReplayError> {
        if !self
            .upstream_first_token_ref
            .starts_with(UPSTREAM_FIRST_TOKEN_PREFIX)
        {
            return Err(GemmaQatSameFixtureReplayError::BadUpstreamRef);
        }
        if self.cards.is_empty() {
            return Err(GemmaQatSameFixtureReplayError::EmptyCardSet);
        }
        if self.metadata_bytes == 0 || self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatSameFixtureReplayError::MetadataBudgetExceeded);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || !self.metadata_only
            || !self.same_fixture_for_all_cards
            || !self.runtime_replay_deferred
            || !self.quality_comparison_deferred
            || !self.product_promotion_blocked
        {
            return Err(GemmaQatSameFixtureReplayError::UnsafeLedgerState);
        }

        let mut ids = HashSet::new();
        let mut model_lanes = HashSet::new();
        let mut fixtures = BTreeSet::new();
        for card in &self.cards {
            validate_card(card, &self.upstream_first_token_ref)?;
            if !ids.insert(card.card_id.as_str()) {
                return Err(GemmaQatSameFixtureReplayError::DuplicateCardId(
                    card.card_id.clone(),
                ));
            }
            if !model_lanes.insert((card.model_id.as_str(), card.runtime_lane)) {
                return Err(GemmaQatSameFixtureReplayError::DuplicateModelLane(
                    card.model_id.clone(),
                ));
            }
            fixtures.insert((
                card.fixture_id.as_str(),
                card.fixture_digest.as_str(),
                card.canonical_replay_digest.as_str(),
            ));
        }
        let metrics = self.metrics();
        if metrics.card_count != 4
            || metrics.e2b_card_count != 2
            || metrics.e4b_card_count != 2
            || metrics.gguf_lane_count != 2
            || metrics.litert_lane_count != 2
            || fixtures.len() != 1
        {
            return Err(GemmaQatSameFixtureReplayError::ExpectedPackMismatch);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatSameFixtureReplayMetrics {
        let mut fixtures = BTreeSet::new();
        let mut metrics = GemmaQatSameFixtureReplayMetrics {
            card_count: self.cards.len() as u64,
            e2b_card_count: 0,
            e4b_card_count: 0,
            gguf_lane_count: 0,
            litert_lane_count: 0,
            fixture_count: 0,
            prompt_digest_bound_count: 0,
            tokenizer_digest_bound_count: 0,
            chat_template_digest_bound_count: 0,
            tool_schema_digest_bound_count: 0,
            memory_sample_bound_count: 0,
            runtime_replay_deferred_count: 0,
            quality_comparison_deferred_count: 0,
            raw_prompt_bytes_captured_total: 0,
            raw_token_bytes_captured_total: 0,
            tool_json_bytes_captured_total: 0,
            local_file_bytes_read_total: 0,
            cache_bytes_reused_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            command_execution_count_total: 0,
            benchmark_runs_total: 0,
            l2_effect_count: 0,
            l3_effect_count: 0,
            hidden_authority_count: 0,
            promotion_claim_count: 0,
            quality_claim_count: 0,
            metadata_bytes_read_total: self.metadata_bytes,
        };
        for card in &self.cards {
            fixtures.insert(card.fixture_digest.clone());
            metrics.e2b_card_count += u64::from(card.model_id.contains("E2B"));
            metrics.e4b_card_count += u64::from(card.model_id.contains("E4B"));
            metrics.gguf_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp);
            metrics.litert_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm);
            metrics.prompt_digest_bound_count += u64::from(card.redacted_prompt_digest_bound);
            metrics.tokenizer_digest_bound_count += u64::from(card.tokenizer_digest_bound);
            metrics.chat_template_digest_bound_count += u64::from(card.chat_template_digest_bound);
            metrics.tool_schema_digest_bound_count += u64::from(card.tool_schema_digest_bound);
            metrics.memory_sample_bound_count += u64::from(card.memory_sample_bound);
            metrics.runtime_replay_deferred_count += u64::from(card.runtime_replay_deferred);
            metrics.quality_comparison_deferred_count +=
                u64::from(card.quality_comparison_deferred);
            metrics.raw_prompt_bytes_captured_total += card.byte_ledger.raw_prompt_bytes_captured;
            metrics.raw_token_bytes_captured_total += card.byte_ledger.raw_token_bytes_captured;
            metrics.tool_json_bytes_captured_total += card.byte_ledger.tool_json_bytes_captured;
            metrics.local_file_bytes_read_total += card.byte_ledger.local_file_bytes_read;
            metrics.cache_bytes_reused_total += card.byte_ledger.cache_bytes_reused;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.command_execution_count_total += card.byte_ledger.command_execution_count;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
            metrics.l2_effect_count += u64::from(card.l2_capability_effect);
            metrics.l3_effect_count += u64::from(card.l3_wrv_effect);
            metrics.hidden_authority_count += u64::from(
                card.hidden_route_authority
                    || card.hidden_eidos_authority
                    || card.hidden_lattice_authority
                    || card.hidden_patternboost_authority
                    || card.hidden_cloud_fallback,
            );
            metrics.promotion_claim_count += u64::from(
                card.mas_promoted
                    || card.product_route_green
                    || card.live_dense_70b_claim
                    || card.ssd_as_ram_claim,
            );
            metrics.quality_claim_count +=
                u64::from(card.quality_claimed || card.benchmark_claimed_as_fit);
            metrics.metadata_bytes_read_total += card.byte_ledger.metadata_bytes_read;
        }
        metrics.fixture_count = fixtures.len() as u64;
        metrics
    }
}

pub fn canonical_gemma_qat_same_fixture_replay_cards(
    upstream_first_token_ref: &str,
) -> Vec<GemmaQatSameFixtureReplayCard> {
    canonical_gemma_qat_redacted_first_token_cards(upstream_first_token_ref)
        .into_iter()
        .map(|card| {
            let model_slug = model_slug(&card.model_id);
            let lane_slug = runtime_lane_slug(card.runtime_lane);
            let card_id = format!("gemma4_{model_slug}_{lane_slug}_same_fixture_replay");
            GemmaQatSameFixtureReplayCard {
                card_id: card_id.clone(),
                upstream_first_token_ref: upstream_first_token_ref.to_string(),
                upstream_first_token_card_id: card.card_id,
                model_id: card.model_id,
                runtime_lane: card.runtime_lane,
                state: GemmaQatReplayState::MetadataOnlyReplayDeferred,
                fixture_id: GEMMA_QAT_SAME_FIXTURE_ID.to_string(),
                fixture_digest: GEMMA_QAT_SAME_FIXTURE_DIGEST.to_string(),
                canonical_replay_digest: GEMMA_QAT_CANONICAL_REPLAY_DIGEST.to_string(),
                source_search_freshness_bound: true,
                body_read_checksum_bound: true,
                redacted_prompt_digest_bound: true,
                tokenizer_digest_bound: true,
                chat_template_digest_bound: true,
                tool_schema_digest_bound: true,
                memory_sample_bound: true,
                one_token_replay_bound: true,
                cancellation_bound: true,
                rollback_bound: true,
                run_event_log_bound: true,
                answer_packet_bound: true,
                abstention_bound: true,
                raw_prompt_denied: true,
                raw_token_denied: true,
                hidden_chain_denied: true,
                cache_reuse_denied_until_lineage: true,
                runtime_replay_deferred: true,
                quality_comparison_deferred: true,
                product_build: ProductBuild::Pro,
                pro_status: ProStatus::Gated,
                l1_architecture_effect: true,
                l2_capability_effect: false,
                l3_wrv_effect: false,
                route_mutation_allowed: false,
                hidden_route_authority: false,
                hidden_eidos_authority: false,
                hidden_lattice_authority: false,
                hidden_patternboost_authority: false,
                hidden_cloud_fallback: false,
                mas_promoted: false,
                product_route_green: false,
                live_dense_70b_claim: false,
                ssd_as_ram_claim: false,
                quality_claimed: false,
                benchmark_claimed_as_fit: false,
                byte_ledger: GemmaQatSameFixtureReplayByteLedger::metadata_only(20_480, 8_192),
                proof_refs: proof_refs(upstream_first_token_ref, &card_id),
                next_cursor: GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_NEXT_CURSOR.to_string(),
            }
        })
        .collect()
}

fn validate_card(
    card: &GemmaQatSameFixtureReplayCard,
    upstream_first_token_ref: &str,
) -> Result<(), GemmaQatSameFixtureReplayError> {
    if card.card_id.trim().is_empty()
        || card.upstream_first_token_ref != upstream_first_token_ref
        || card.upstream_first_token_card_id.trim().is_empty()
    {
        return Err(GemmaQatSameFixtureReplayError::BadCard);
    }
    if !(card.model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
        || card.model_id == "google/gemma-4-E4B-it-qat-q4_0-gguf")
    {
        return Err(GemmaQatSameFixtureReplayError::ExpectedPackMismatch);
    }
    if !(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp
        || card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm)
    {
        return Err(GemmaQatSameFixtureReplayError::BadRuntimeLane);
    }
    if card.state != GemmaQatReplayState::MetadataOnlyReplayDeferred
        || card.fixture_id != GEMMA_QAT_SAME_FIXTURE_ID
        || !card.fixture_digest.starts_with(FIXTURE_PREFIX)
        || card.fixture_digest != GEMMA_QAT_SAME_FIXTURE_DIGEST
        || !card.canonical_replay_digest.starts_with(SHA256_PREFIX)
        || card.canonical_replay_digest != GEMMA_QAT_CANONICAL_REPLAY_DIGEST
    {
        return Err(GemmaQatSameFixtureReplayError::FixtureBoundaryBroken);
    }
    if !card.source_search_freshness_bound
        || !card.body_read_checksum_bound
        || !card.redacted_prompt_digest_bound
        || !card.tokenizer_digest_bound
        || !card.chat_template_digest_bound
        || !card.tool_schema_digest_bound
        || !card.memory_sample_bound
        || !card.one_token_replay_bound
    {
        return Err(GemmaQatSameFixtureReplayError::ReplayBoundaryBroken);
    }
    if !card.cancellation_bound
        || !card.rollback_bound
        || !card.run_event_log_bound
        || !card.answer_packet_bound
        || !card.abstention_bound
    {
        return Err(GemmaQatSameFixtureReplayError::ProofBoundaryBroken);
    }
    if !card.raw_prompt_denied
        || !card.raw_token_denied
        || !card.hidden_chain_denied
        || !card.cache_reuse_denied_until_lineage
        || !card.runtime_replay_deferred
        || !card.quality_comparison_deferred
    {
        return Err(GemmaQatSameFixtureReplayError::PrivacyBoundaryBroken);
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::Gated
        || !card.l1_architecture_effect
        || card.l2_capability_effect
        || card.l3_wrv_effect
        || card.route_mutation_allowed
        || card.hidden_route_authority
        || card.hidden_eidos_authority
        || card.hidden_lattice_authority
        || card.hidden_patternboost_authority
        || card.hidden_cloud_fallback
        || card.mas_promoted
        || card.product_route_green
        || card.live_dense_70b_claim
        || card.ssd_as_ram_claim
        || card.quality_claimed
        || card.benchmark_claimed_as_fit
    {
        return Err(GemmaQatSameFixtureReplayError::PromotionClaim);
    }
    if card.byte_ledger.metadata_bytes_read == 0
        || card.byte_ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.byte_ledger.fixture_descriptor_bytes == 0
        || card.byte_ledger.live_bytes_or_actions_observed()
    {
        return Err(GemmaQatSameFixtureReplayError::BytesOrCommandsObserved);
    }
    validate_proof_refs(&card.proof_refs)?;
    if card.next_cursor != GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_NEXT_CURSOR {
        return Err(GemmaQatSameFixtureReplayError::WrongNextCursor);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatSameFixtureReplayProofRefs,
) -> Result<(), GemmaQatSameFixtureReplayError> {
    let ok = refs
        .upstream_first_token_ref
        .starts_with(UPSTREAM_FIRST_TOKEN_PREFIX)
        && !refs.upstream_first_token_card_id.trim().is_empty()
        && refs.body_read_checksum_ref.starts_with(BODY_REF_PREFIX)
        && refs
            .source_search_freshness_ref
            .starts_with(SOURCE_SEARCH_REF_PREFIX)
        && refs.prompt_digest_ref.starts_with(PROMPT_REF_PREFIX)
        && refs.tokenizer_digest_ref.starts_with(TOKENIZER_REF_PREFIX)
        && refs
            .chat_template_digest_ref
            .starts_with(CHAT_TEMPLATE_REF_PREFIX)
        && refs
            .tool_schema_digest_ref
            .starts_with(TOOL_SCHEMA_REF_PREFIX)
        && refs.memory_sample_ref.starts_with(MEMORY_SAMPLE_REF_PREFIX)
        && refs.cancellation_ref.starts_with(CANCELLATION_REF_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_REF_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_REF_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_REF_PREFIX)
        && refs.abstention_ref.starts_with(ABSTENTION_REF_PREFIX)
        && refs.no_promotion_ref.starts_with(NO_PROMOTION_REF_PREFIX);
    if ok {
        Ok(())
    } else {
        Err(GemmaQatSameFixtureReplayError::BadProofRef)
    }
}

fn proof_refs(upstream_first_token_ref: &str, card_id: &str) -> GemmaQatSameFixtureReplayProofRefs {
    GemmaQatSameFixtureReplayProofRefs {
        upstream_first_token_ref: upstream_first_token_ref.to_string(),
        upstream_first_token_card_id: card_id
            .replace("_same_fixture_replay", "_redacted_first_token_preflight"),
        body_read_checksum_ref: format!(
            "{BODY_REF_PREFIX}result.json#F-BodyReadChecksum-ReleaseBlockerCard"
        ),
        source_search_freshness_ref: format!("{SOURCE_SEARCH_REF_PREFIX}{card_id}"),
        prompt_digest_ref: format!("{PROMPT_REF_PREFIX}{card_id}"),
        tokenizer_digest_ref: format!("{TOKENIZER_REF_PREFIX}{card_id}"),
        chat_template_digest_ref: format!("{CHAT_TEMPLATE_REF_PREFIX}{card_id}"),
        tool_schema_digest_ref: format!("{TOOL_SCHEMA_REF_PREFIX}{card_id}"),
        memory_sample_ref: format!("{MEMORY_SAMPLE_REF_PREFIX}{card_id}"),
        cancellation_ref: format!("{CANCELLATION_REF_PREFIX}{card_id}"),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}{card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}{card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}{card_id}"),
        abstention_ref: format!("{ABSTENTION_REF_PREFIX}{card_id}"),
        no_promotion_ref: format!("{NO_PROMOTION_REF_PREFIX}{card_id}"),
    }
}

fn replay_preimage(
    upstream_first_token_ref: &str,
    cards: &[GemmaQatSameFixtureReplayCard],
    metadata_bytes: u64,
) -> String {
    serde_json::json!({
        "cursor": GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_CURSOR,
        "upstream_first_token_ref": upstream_first_token_ref,
        "fixture_id": GEMMA_QAT_SAME_FIXTURE_ID,
        "fixture_digest": GEMMA_QAT_SAME_FIXTURE_DIGEST,
        "canonical_replay_digest": GEMMA_QAT_CANONICAL_REPLAY_DIGEST,
        "cards": cards,
        "metadata_bytes": metadata_bytes,
    })
    .to_string()
}

fn model_slug(model_id: &str) -> &'static str {
    if model_id.contains("E2B") {
        "e2b"
    } else if model_id.contains("E4B") {
        "e4b"
    } else {
        "unknown"
    }
}

fn runtime_lane_slug(lane: GemmaFamilyRuntimeLane) -> &'static str {
    match lane {
        GemmaFamilyRuntimeLane::GgufLlamaCpp => "gguf_llama_cpp",
        GemmaFamilyRuntimeLane::LiteRtLm => "litert_lm",
        _ => "unsupported",
    }
}

// UAS: uas:gemma-qat-same-fixture-runtime-replay:error
// Plane: Verification.
// Residency: fail-closed same-fixture replay rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatSameFixtureReplayError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelLane(String),
    BadCard,
    BadUpstreamRef,
    BadRuntimeLane,
    ExpectedPackMismatch,
    UnsafeLedgerState,
    FixtureBoundaryBroken,
    ReplayBoundaryBroken,
    ProofBoundaryBroken,
    PrivacyBoundaryBroken,
    BadProofRef,
    BytesOrCommandsObserved,
    PromotionClaim,
    MetadataBudgetExceeded,
    WrongNextCursor,
}

impl fmt::Display for GemmaQatSameFixtureReplayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "empty card set"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id {id}"),
            Self::DuplicateModelLane(id) => write!(f, "duplicate model/runtime lane {id}"),
            Self::BadCard => write!(f, "bad card"),
            Self::BadUpstreamRef => write!(f, "bad upstream ref"),
            Self::BadRuntimeLane => write!(f, "bad runtime lane"),
            Self::ExpectedPackMismatch => write!(f, "expected Gemma same-fixture pack mismatch"),
            Self::UnsafeLedgerState => write!(f, "unsafe ledger state"),
            Self::FixtureBoundaryBroken => write!(f, "fixture boundary broken"),
            Self::ReplayBoundaryBroken => write!(f, "replay boundary broken"),
            Self::ProofBoundaryBroken => write!(f, "proof boundary broken"),
            Self::PrivacyBoundaryBroken => write!(f, "privacy boundary broken"),
            Self::BadProofRef => write!(f, "bad proof ref"),
            Self::BytesOrCommandsObserved => write!(f, "bytes or commands observed"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::WrongNextCursor => write!(f, "wrong next cursor"),
        }
    }
}

impl std::error::Error for GemmaQatSameFixtureReplayError {}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_redacted_first_token_probe/result.json#F-GemmaQATRedactedFirstTokenProbe";

    fn ledger() -> Result<GemmaQatSameFixtureReplayLedger, GemmaQatSameFixtureReplayError> {
        GemmaQatSameFixtureReplayLedger::new(
            UPSTREAM_REF,
            canonical_gemma_qat_same_fixture_replay_cards(UPSTREAM_REF),
            112_000,
            1_779_213_600_000,
        )
    }

    #[test]
    fn canonical_replay_pack_validates_without_runtime_or_quality_bytes() {
        let Ok(ledger) = ledger() else {
            panic!("canonical Gemma same-fixture ledger should validate");
        };
        let metrics = ledger.metrics();
        assert_eq!(metrics.card_count, 4);
        assert_eq!(metrics.fixture_count, 1);
        assert_eq!(metrics.e2b_card_count, 2);
        assert_eq!(metrics.e4b_card_count, 2);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
        assert_eq!(metrics.raw_prompt_bytes_captured_total, 0);
        assert_eq!(metrics.quality_claim_count, 0);
    }

    #[test]
    fn rejects_fixture_drift_or_raw_capture() {
        let mut cards = canonical_gemma_qat_same_fixture_replay_cards(UPSTREAM_REF);
        cards[0].fixture_digest = "fixture:sha256:other".to_string();
        assert!(GemmaQatSameFixtureReplayLedger::new(
            UPSTREAM_REF,
            cards,
            112_000,
            1_779_213_600_000
        )
        .is_err());

        let mut cards = canonical_gemma_qat_same_fixture_replay_cards(UPSTREAM_REF);
        cards[0].byte_ledger.raw_prompt_bytes_captured = 1;
        assert!(GemmaQatSameFixtureReplayLedger::new(
            UPSTREAM_REF,
            cards,
            112_000,
            1_779_213_600_000
        )
        .is_err());
    }

    #[test]
    fn rejects_product_quality_or_route_promotion() {
        let mut cards = canonical_gemma_qat_same_fixture_replay_cards(UPSTREAM_REF);
        cards[0].quality_claimed = true;
        assert!(GemmaQatSameFixtureReplayLedger::new(
            UPSTREAM_REF,
            cards,
            112_000,
            1_779_213_600_000
        )
        .is_err());

        let mut cards = canonical_gemma_qat_same_fixture_replay_cards(UPSTREAM_REF);
        cards[0].l2_capability_effect = true;
        assert!(GemmaQatSameFixtureReplayLedger::new(
            UPSTREAM_REF,
            cards,
            112_000,
            1_779_213_600_000
        )
        .is_err());
    }
}
