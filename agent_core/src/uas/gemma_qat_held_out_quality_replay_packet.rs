//! Gemma QAT held-out quality replay packet.
//!
//! This primitive consumes the Gemma same-fixture replay contract and binds the
//! held-out task/scorer/failure-taxonomy packet required before any Gemma
//! quality or route-improvement claim can count. It does not run evals, invoke
//! judges, open fixture payloads, load models, or promote product routes.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    canonical_gemma_qat_same_fixture_replay_cards, GemmaFamilyRuntimeLane, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_ID: &str =
    "F-GemmaQATHeldOutQualityReplayPacket";
pub const GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_CURSOR: &str =
    "gemma_qat_held_out_quality_replay_packet";
pub const GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_NEXT_CURSOR: &str =
    "gemma_qat_owner_approved_runtime_replay_transcript_gate";

pub const GEMMA_QAT_QUALITY_FIXTURE_PACK_ID: &str = "gemma_qat_held_out_quality_pack_v0";
pub const GEMMA_QAT_QUALITY_FIXTURE_PACK_DIGEST: &str =
    "fixture_pack:sha256:gemma-qat-held-out-quality-pack-v0";
pub const GEMMA_QAT_SCORER_BUNDLE_DIGEST: &str =
    "scorer_bundle:sha256:gemma-qat-held-out-scorer-bundle-v0";

const UPSTREAM_SAME_FIXTURE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_same_fixture_runtime_replay/";
const FIXTURE_PACK_PREFIX: &str = "fixture_pack:sha256:";
const SCORER_BUNDLE_PREFIX: &str = "scorer_bundle:sha256:";
const TASK_DIGEST_PREFIX: &str = "task_family_digest:";
const VERIFIER_DIGEST_PREFIX: &str = "verifier_digest:";
const SCORER_DIGEST_PREFIX: &str = "scorer_digest:";
const FINAL_OUTPUT_POLICY_PREFIX: &str = "final_output_digest_policy:";
const FAILURE_TAXONOMY_PREFIX: &str = "failure_taxonomy:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstention:";
const NO_PROMOTION_PREFIX: &str = "non_promotion:";
const SOURCE_REF_PREFIX: &str = "source_ref:";
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAX_LEDGER_METADATA_BYTES: u64 = 320 * 1024;

// UAS: uas:gemma-qat-held-out-quality-replay:task-family
// Plane: Verification.
// Residency: task family metadata; fixture payloads are not opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatQualityTaskFamily {
    NoteSynthesis,
    CitationGroundedResearch,
    StructuredToolJson,
    CacheDeletionReuse,
    WritingEdit,
    CodingPatch,
    RefusalAbstention,
}

pub const GEMMA_QAT_QUALITY_TASK_FAMILIES: &[GemmaQatQualityTaskFamily] = &[
    GemmaQatQualityTaskFamily::NoteSynthesis,
    GemmaQatQualityTaskFamily::CitationGroundedResearch,
    GemmaQatQualityTaskFamily::StructuredToolJson,
    GemmaQatQualityTaskFamily::CacheDeletionReuse,
    GemmaQatQualityTaskFamily::WritingEdit,
    GemmaQatQualityTaskFamily::CodingPatch,
    GemmaQatQualityTaskFamily::RefusalAbstention,
];

// UAS: uas:gemma-qat-held-out-quality-replay:state
// Plane: Verification.
// Residency: quality packet is a metadata contract only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatQualityReplayState {
    MetadataOnlyQualityReplayDeferred,
}

// UAS: uas:gemma-qat-held-out-quality-replay:proof-refs
// Plane: Verification.
// Residency: proof handles only; no eval framework is imported or run.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatQualityReplayProofRefs {
    pub upstream_same_fixture_ref: String,
    pub upstream_same_fixture_card_id: String,
    pub fixture_pack_ref: String,
    pub task_family_digest_ref: String,
    pub verifier_digest_ref: String,
    pub scorer_digest_ref: String,
    pub final_output_digest_policy_ref: String,
    pub failure_taxonomy_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub no_promotion_ref: String,
    pub external_eval_source_refs: Vec<String>,
}

// UAS: uas:gemma-qat-held-out-quality-replay:byte-ledger
// Plane: Verification.
// Residency: byte ledger; fixture/model/runtime/judge bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatQualityReplayByteLedger {
    pub metadata_bytes_read: u64,
    pub fixture_descriptor_bytes: u64,
    pub fixture_payload_bytes_opened: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub raw_judge_bytes_captured: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub benchmark_runs: u64,
    pub scorer_executions: u64,
}

impl GemmaQatQualityReplayByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64, fixture_descriptor_bytes: u64) -> Self {
        Self {
            metadata_bytes_read,
            fixture_descriptor_bytes,
            fixture_payload_bytes_opened: 0,
            raw_prompt_bytes_captured: 0,
            raw_output_bytes_captured: 0,
            raw_judge_bytes_captured: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            benchmark_runs: 0,
            scorer_executions: 0,
        }
    }

    fn live_bytes_or_actions_observed(&self) -> bool {
        self.fixture_payload_bytes_opened != 0
            || self.raw_prompt_bytes_captured != 0
            || self.raw_output_bytes_captured != 0
            || self.raw_judge_bytes_captured != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.benchmark_runs != 0
            || self.scorer_executions != 0
    }
}

// UAS: uas:gemma-qat-held-out-quality-replay:card
// Plane: State + Controller + Verification.
// Residency: quality replay contract only; no output or score exists yet.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatHeldOutQualityReplayCard {
    pub card_id: String,
    pub upstream_same_fixture_ref: String,
    pub upstream_same_fixture_card_id: String,
    pub model_id: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub state: GemmaQatQualityReplayState,
    pub fixture_pack_id: String,
    pub fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub task_families: Vec<GemmaQatQualityTaskFamily>,
    pub held_out_split_bound: bool,
    pub synthetic_safe_fixture_policy_bound: bool,
    pub task_family_digest_bound: bool,
    pub verifier_digest_bound: bool,
    pub scorer_digest_bound: bool,
    pub final_output_digest_policy_bound: bool,
    pub failure_taxonomy_bound: bool,
    pub refusal_tool_cache_taxonomy_bound: bool,
    pub deterministic_scoring_required: bool,
    pub model_graded_primary_denied: bool,
    pub hidden_judge_denied: bool,
    pub raw_prompt_denied: bool,
    pub raw_output_denied: bool,
    pub runtime_quality_replay_deferred: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
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
    pub byte_ledger: GemmaQatQualityReplayByteLedger,
    pub proof_refs: GemmaQatQualityReplayProofRefs,
    pub next_cursor: String,
}

// UAS: uas:gemma-qat-held-out-quality-replay:ledger
// Plane: State + Verification.
// Residency: held-out quality packet ledger; metadata-only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatHeldOutQualityReplayLedger {
    pub ledger_address: UasAddress,
    pub upstream_same_fixture_ref: String,
    pub fixture_pack_id: String,
    pub fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub cards: Vec<GemmaQatHeldOutQualityReplayCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub runtime_quality_replay_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-held-out-quality-replay:metrics
// Plane: Verification.
// Residency: derived metadata-only counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatHeldOutQualityReplayMetrics {
    pub card_count: u64,
    pub e2b_card_count: u64,
    pub e4b_card_count: u64,
    pub gguf_lane_count: u64,
    pub litert_lane_count: u64,
    pub fixture_pack_count: u64,
    pub scorer_bundle_count: u64,
    pub task_family_total_count: u64,
    pub unique_task_family_count: u64,
    pub held_out_split_bound_count: u64,
    pub verifier_digest_bound_count: u64,
    pub scorer_digest_bound_count: u64,
    pub final_output_digest_policy_bound_count: u64,
    pub failure_taxonomy_bound_count: u64,
    pub runtime_quality_replay_deferred_count: u64,
    pub fixture_payload_bytes_opened_total: u64,
    pub raw_prompt_bytes_captured_total: u64,
    pub raw_output_bytes_captured_total: u64,
    pub raw_judge_bytes_captured_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub benchmark_runs_total: u64,
    pub scorer_executions_total: u64,
    pub l2_effect_count: u64,
    pub l3_effect_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub quality_claim_count: u64,
    pub metadata_bytes_read_total: u64,
}

impl GemmaQatHeldOutQualityReplayLedger {
    pub fn new(
        upstream_same_fixture_ref: impl Into<String>,
        mut cards: Vec<GemmaQatHeldOutQualityReplayCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatHeldOutQualityReplayError> {
        let upstream_same_fixture_ref = upstream_same_fixture_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_CURSOR.to_string()),
                quality_preimage(&upstream_same_fixture_ref, &cards, metadata_bytes).as_bytes(),
                created_at_ms,
            ),
            upstream_same_fixture_ref,
            fixture_pack_id: GEMMA_QAT_QUALITY_FIXTURE_PACK_ID.to_string(),
            fixture_pack_digest: GEMMA_QAT_QUALITY_FIXTURE_PACK_DIGEST.to_string(),
            scorer_bundle_digest: GEMMA_QAT_SCORER_BUNDLE_DIGEST.to_string(),
            cards,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            metadata_only: true,
            runtime_quality_replay_deferred: true,
            product_promotion_blocked: true,
            metadata_bytes,
        };
        ledger.validate()?;
        Ok(ledger)
    }

    pub fn validate(&self) -> Result<(), GemmaQatHeldOutQualityReplayError> {
        if !self
            .upstream_same_fixture_ref
            .starts_with(UPSTREAM_SAME_FIXTURE_PREFIX)
        {
            return Err(GemmaQatHeldOutQualityReplayError::BadUpstreamRef);
        }
        if self.cards.is_empty() {
            return Err(GemmaQatHeldOutQualityReplayError::EmptyCardSet);
        }
        if self.metadata_bytes == 0 || self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatHeldOutQualityReplayError::MetadataBudgetExceeded);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || !self.metadata_only
            || !self.runtime_quality_replay_deferred
            || !self.product_promotion_blocked
        {
            return Err(GemmaQatHeldOutQualityReplayError::UnsafeLedgerState);
        }

        let mut ids = HashSet::new();
        let mut model_lanes = HashSet::new();
        for card in &self.cards {
            validate_card(card, &self.upstream_same_fixture_ref)?;
            if !ids.insert(card.card_id.as_str()) {
                return Err(GemmaQatHeldOutQualityReplayError::DuplicateCardId(
                    card.card_id.clone(),
                ));
            }
            if !model_lanes.insert((card.model_id.as_str(), card.runtime_lane)) {
                return Err(GemmaQatHeldOutQualityReplayError::DuplicateModelLane(
                    card.model_id.clone(),
                ));
            }
        }
        let metrics = self.metrics();
        if metrics.card_count != 4
            || metrics.e2b_card_count != 2
            || metrics.e4b_card_count != 2
            || metrics.gguf_lane_count != 2
            || metrics.litert_lane_count != 2
            || metrics.unique_task_family_count != GEMMA_QAT_QUALITY_TASK_FAMILIES.len() as u64
        {
            return Err(GemmaQatHeldOutQualityReplayError::ExpectedPackMismatch);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatHeldOutQualityReplayMetrics {
        let mut fixture_packs = BTreeSet::new();
        let mut scorer_bundles = BTreeSet::new();
        let mut task_families = BTreeSet::new();
        let mut metrics = GemmaQatHeldOutQualityReplayMetrics {
            card_count: self.cards.len() as u64,
            e2b_card_count: 0,
            e4b_card_count: 0,
            gguf_lane_count: 0,
            litert_lane_count: 0,
            fixture_pack_count: 0,
            scorer_bundle_count: 0,
            task_family_total_count: 0,
            unique_task_family_count: 0,
            held_out_split_bound_count: 0,
            verifier_digest_bound_count: 0,
            scorer_digest_bound_count: 0,
            final_output_digest_policy_bound_count: 0,
            failure_taxonomy_bound_count: 0,
            runtime_quality_replay_deferred_count: 0,
            fixture_payload_bytes_opened_total: 0,
            raw_prompt_bytes_captured_total: 0,
            raw_output_bytes_captured_total: 0,
            raw_judge_bytes_captured_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            benchmark_runs_total: 0,
            scorer_executions_total: 0,
            l2_effect_count: 0,
            l3_effect_count: 0,
            hidden_authority_count: 0,
            promotion_claim_count: 0,
            quality_claim_count: 0,
            metadata_bytes_read_total: self.metadata_bytes,
        };
        for card in &self.cards {
            fixture_packs.insert(card.fixture_pack_digest.clone());
            scorer_bundles.insert(card.scorer_bundle_digest.clone());
            for family in &card.task_families {
                task_families.insert(*family);
            }
            metrics.e2b_card_count += u64::from(card.model_id.contains("E2B"));
            metrics.e4b_card_count += u64::from(card.model_id.contains("E4B"));
            metrics.gguf_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp);
            metrics.litert_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm);
            metrics.task_family_total_count += card.task_families.len() as u64;
            metrics.held_out_split_bound_count += u64::from(card.held_out_split_bound);
            metrics.verifier_digest_bound_count += u64::from(card.verifier_digest_bound);
            metrics.scorer_digest_bound_count += u64::from(card.scorer_digest_bound);
            metrics.final_output_digest_policy_bound_count +=
                u64::from(card.final_output_digest_policy_bound);
            metrics.failure_taxonomy_bound_count += u64::from(card.failure_taxonomy_bound);
            metrics.runtime_quality_replay_deferred_count +=
                u64::from(card.runtime_quality_replay_deferred);
            metrics.fixture_payload_bytes_opened_total +=
                card.byte_ledger.fixture_payload_bytes_opened;
            metrics.raw_prompt_bytes_captured_total += card.byte_ledger.raw_prompt_bytes_captured;
            metrics.raw_output_bytes_captured_total += card.byte_ledger.raw_output_bytes_captured;
            metrics.raw_judge_bytes_captured_total += card.byte_ledger.raw_judge_bytes_captured;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
            metrics.scorer_executions_total += card.byte_ledger.scorer_executions;
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
        metrics.fixture_pack_count = fixture_packs.len() as u64;
        metrics.scorer_bundle_count = scorer_bundles.len() as u64;
        metrics.unique_task_family_count = task_families.len() as u64;
        metrics
    }
}

pub fn canonical_gemma_qat_held_out_quality_replay_cards(
    upstream_same_fixture_ref: &str,
) -> Vec<GemmaQatHeldOutQualityReplayCard> {
    canonical_gemma_qat_same_fixture_replay_cards(upstream_same_fixture_ref)
        .into_iter()
        .map(|card| {
            let model_slug = model_slug(&card.model_id);
            let lane_slug = runtime_lane_slug(card.runtime_lane);
            let card_id = format!("gemma4_{model_slug}_{lane_slug}_held_out_quality_replay");
            GemmaQatHeldOutQualityReplayCard {
                card_id: card_id.clone(),
                upstream_same_fixture_ref: upstream_same_fixture_ref.to_string(),
                upstream_same_fixture_card_id: card.card_id,
                model_id: card.model_id,
                runtime_lane: card.runtime_lane,
                state: GemmaQatQualityReplayState::MetadataOnlyQualityReplayDeferred,
                fixture_pack_id: GEMMA_QAT_QUALITY_FIXTURE_PACK_ID.to_string(),
                fixture_pack_digest: GEMMA_QAT_QUALITY_FIXTURE_PACK_DIGEST.to_string(),
                scorer_bundle_digest: GEMMA_QAT_SCORER_BUNDLE_DIGEST.to_string(),
                task_families: GEMMA_QAT_QUALITY_TASK_FAMILIES.to_vec(),
                held_out_split_bound: true,
                synthetic_safe_fixture_policy_bound: true,
                task_family_digest_bound: true,
                verifier_digest_bound: true,
                scorer_digest_bound: true,
                final_output_digest_policy_bound: true,
                failure_taxonomy_bound: true,
                refusal_tool_cache_taxonomy_bound: true,
                deterministic_scoring_required: true,
                model_graded_primary_denied: true,
                hidden_judge_denied: true,
                raw_prompt_denied: true,
                raw_output_denied: true,
                runtime_quality_replay_deferred: true,
                rollback_bound: true,
                run_event_log_bound: true,
                answer_packet_bound: true,
                abstention_bound: true,
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
                byte_ledger: GemmaQatQualityReplayByteLedger::metadata_only(24_576, 12_288),
                proof_refs: proof_refs(upstream_same_fixture_ref, &card_id),
                next_cursor: GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_NEXT_CURSOR.to_string(),
            }
        })
        .collect()
}

fn validate_card(
    card: &GemmaQatHeldOutQualityReplayCard,
    upstream_same_fixture_ref: &str,
) -> Result<(), GemmaQatHeldOutQualityReplayError> {
    if card.card_id.trim().is_empty()
        || card.upstream_same_fixture_ref != upstream_same_fixture_ref
        || card.upstream_same_fixture_card_id.trim().is_empty()
    {
        return Err(GemmaQatHeldOutQualityReplayError::BadCard);
    }
    if !(card.model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
        || card.model_id == "google/gemma-4-E4B-it-qat-q4_0-gguf")
    {
        return Err(GemmaQatHeldOutQualityReplayError::ExpectedPackMismatch);
    }
    if !(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp
        || card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm)
    {
        return Err(GemmaQatHeldOutQualityReplayError::BadRuntimeLane);
    }
    if card.state != GemmaQatQualityReplayState::MetadataOnlyQualityReplayDeferred
        || card.fixture_pack_id != GEMMA_QAT_QUALITY_FIXTURE_PACK_ID
        || !card.fixture_pack_digest.starts_with(FIXTURE_PACK_PREFIX)
        || card.fixture_pack_digest != GEMMA_QAT_QUALITY_FIXTURE_PACK_DIGEST
        || !card.scorer_bundle_digest.starts_with(SCORER_BUNDLE_PREFIX)
        || card.scorer_bundle_digest != GEMMA_QAT_SCORER_BUNDLE_DIGEST
    {
        return Err(GemmaQatHeldOutQualityReplayError::FixtureOrScorerBoundaryBroken);
    }
    if !has_all_task_families(&card.task_families) {
        return Err(GemmaQatHeldOutQualityReplayError::TaskFamilyBoundaryBroken);
    }
    if !card.held_out_split_bound
        || !card.synthetic_safe_fixture_policy_bound
        || !card.task_family_digest_bound
        || !card.verifier_digest_bound
        || !card.scorer_digest_bound
        || !card.final_output_digest_policy_bound
        || !card.failure_taxonomy_bound
        || !card.refusal_tool_cache_taxonomy_bound
        || !card.deterministic_scoring_required
    {
        return Err(GemmaQatHeldOutQualityReplayError::QualityBoundaryBroken);
    }
    if !card.model_graded_primary_denied
        || !card.hidden_judge_denied
        || !card.raw_prompt_denied
        || !card.raw_output_denied
        || !card.runtime_quality_replay_deferred
    {
        return Err(GemmaQatHeldOutQualityReplayError::PrivacyBoundaryBroken);
    }
    if !card.rollback_bound
        || !card.run_event_log_bound
        || !card.answer_packet_bound
        || !card.abstention_bound
    {
        return Err(GemmaQatHeldOutQualityReplayError::ProofBoundaryBroken);
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
        return Err(GemmaQatHeldOutQualityReplayError::PromotionClaim);
    }
    if card.byte_ledger.metadata_bytes_read == 0
        || card.byte_ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.byte_ledger.fixture_descriptor_bytes == 0
        || card.byte_ledger.live_bytes_or_actions_observed()
    {
        return Err(GemmaQatHeldOutQualityReplayError::BytesOrActionsObserved);
    }
    validate_proof_refs(&card.proof_refs)?;
    if card.next_cursor != GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_NEXT_CURSOR {
        return Err(GemmaQatHeldOutQualityReplayError::WrongNextCursor);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatQualityReplayProofRefs,
) -> Result<(), GemmaQatHeldOutQualityReplayError> {
    let ok = refs
        .upstream_same_fixture_ref
        .starts_with(UPSTREAM_SAME_FIXTURE_PREFIX)
        && !refs.upstream_same_fixture_card_id.trim().is_empty()
        && refs.fixture_pack_ref.starts_with(FIXTURE_PACK_PREFIX)
        && refs.task_family_digest_ref.starts_with(TASK_DIGEST_PREFIX)
        && refs.verifier_digest_ref.starts_with(VERIFIER_DIGEST_PREFIX)
        && refs.scorer_digest_ref.starts_with(SCORER_DIGEST_PREFIX)
        && refs
            .final_output_digest_policy_ref
            .starts_with(FINAL_OUTPUT_POLICY_PREFIX)
        && refs
            .failure_taxonomy_ref
            .starts_with(FAILURE_TAXONOMY_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
        && refs.abstention_ref.starts_with(ABSTENTION_PREFIX)
        && refs.no_promotion_ref.starts_with(NO_PROMOTION_PREFIX)
        && refs.external_eval_source_refs.len() >= 4
        && refs
            .external_eval_source_refs
            .iter()
            .all(|source| source.starts_with(SOURCE_REF_PREFIX));
    if ok {
        Ok(())
    } else {
        Err(GemmaQatHeldOutQualityReplayError::BadProofRef)
    }
}

fn proof_refs(upstream_same_fixture_ref: &str, card_id: &str) -> GemmaQatQualityReplayProofRefs {
    GemmaQatQualityReplayProofRefs {
        upstream_same_fixture_ref: upstream_same_fixture_ref.to_string(),
        upstream_same_fixture_card_id: card_id
            .replace("_held_out_quality_replay", "_same_fixture_replay"),
        fixture_pack_ref: format!("{FIXTURE_PACK_PREFIX}gemma-qat-held-out-quality-pack-v0"),
        task_family_digest_ref: format!("{TASK_DIGEST_PREFIX}{card_id}"),
        verifier_digest_ref: format!("{VERIFIER_DIGEST_PREFIX}{card_id}"),
        scorer_digest_ref: format!("{SCORER_DIGEST_PREFIX}{card_id}"),
        final_output_digest_policy_ref: format!("{FINAL_OUTPUT_POLICY_PREFIX}{card_id}"),
        failure_taxonomy_ref: format!("{FAILURE_TAXONOMY_PREFIX}{card_id}"),
        rollback_ref: format!("{ROLLBACK_PREFIX}{card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{card_id}"),
        abstention_ref: format!("{ABSTENTION_PREFIX}{card_id}"),
        no_promotion_ref: format!("{NO_PROMOTION_PREFIX}{card_id}"),
        external_eval_source_refs: vec![
            "source_ref:inspect_ai_standard_scorers".to_string(),
            "source_ref:huggingface_lighteval_custom_tasks_metrics".to_string(),
            "source_ref:eleutherai_lm_eval_task_metric_yaml".to_string(),
            "source_ref:terminal_bench_task_tests".to_string(),
        ],
    }
}

fn has_all_task_families(families: &[GemmaQatQualityTaskFamily]) -> bool {
    let found = families.iter().copied().collect::<BTreeSet<_>>();
    GEMMA_QAT_QUALITY_TASK_FAMILIES
        .iter()
        .all(|family| found.contains(family))
}

fn quality_preimage(
    upstream_same_fixture_ref: &str,
    cards: &[GemmaQatHeldOutQualityReplayCard],
    metadata_bytes: u64,
) -> String {
    serde_json::json!({
        "cursor": GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_CURSOR,
        "upstream_same_fixture_ref": upstream_same_fixture_ref,
        "fixture_pack_id": GEMMA_QAT_QUALITY_FIXTURE_PACK_ID,
        "fixture_pack_digest": GEMMA_QAT_QUALITY_FIXTURE_PACK_DIGEST,
        "scorer_bundle_digest": GEMMA_QAT_SCORER_BUNDLE_DIGEST,
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

// UAS: uas:gemma-qat-held-out-quality-replay:error
// Plane: Verification.
// Residency: fail-closed quality replay rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatHeldOutQualityReplayError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelLane(String),
    BadCard,
    BadUpstreamRef,
    BadRuntimeLane,
    ExpectedPackMismatch,
    UnsafeLedgerState,
    FixtureOrScorerBoundaryBroken,
    TaskFamilyBoundaryBroken,
    QualityBoundaryBroken,
    PrivacyBoundaryBroken,
    ProofBoundaryBroken,
    BadProofRef,
    BytesOrActionsObserved,
    PromotionClaim,
    MetadataBudgetExceeded,
    WrongNextCursor,
}

impl fmt::Display for GemmaQatHeldOutQualityReplayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "empty card set"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id {id}"),
            Self::DuplicateModelLane(id) => write!(f, "duplicate model/runtime lane {id}"),
            Self::BadCard => write!(f, "bad card"),
            Self::BadUpstreamRef => write!(f, "bad upstream ref"),
            Self::BadRuntimeLane => write!(f, "bad runtime lane"),
            Self::ExpectedPackMismatch => write!(f, "expected Gemma quality pack mismatch"),
            Self::UnsafeLedgerState => write!(f, "unsafe ledger state"),
            Self::FixtureOrScorerBoundaryBroken => write!(f, "fixture/scorer boundary broken"),
            Self::TaskFamilyBoundaryBroken => write!(f, "task family boundary broken"),
            Self::QualityBoundaryBroken => write!(f, "quality boundary broken"),
            Self::PrivacyBoundaryBroken => write!(f, "privacy boundary broken"),
            Self::ProofBoundaryBroken => write!(f, "proof boundary broken"),
            Self::BadProofRef => write!(f, "bad proof ref"),
            Self::BytesOrActionsObserved => write!(f, "bytes or actions observed"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::WrongNextCursor => write!(f, "wrong next cursor"),
        }
    }
}

impl std::error::Error for GemmaQatHeldOutQualityReplayError {}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_same_fixture_runtime_replay/result.json#F-GemmaQATSameFixtureRuntimeReplay";

    fn ledger() -> Result<GemmaQatHeldOutQualityReplayLedger, GemmaQatHeldOutQualityReplayError> {
        GemmaQatHeldOutQualityReplayLedger::new(
            UPSTREAM_REF,
            canonical_gemma_qat_held_out_quality_replay_cards(UPSTREAM_REF),
            128_000,
            1_779_214_400_000,
        )
    }

    #[test]
    fn canonical_quality_packet_validates_without_eval_or_model_bytes() {
        let Ok(ledger) = ledger() else {
            panic!("canonical Gemma quality replay ledger should validate");
        };
        let metrics = ledger.metrics();
        assert_eq!(metrics.card_count, 4);
        assert_eq!(metrics.unique_task_family_count, 7);
        assert_eq!(metrics.fixture_payload_bytes_opened_total, 0);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
        assert_eq!(metrics.benchmark_runs_total, 0);
        assert_eq!(metrics.quality_claim_count, 0);
    }

    #[test]
    fn rejects_missing_task_family_or_hidden_judge() {
        let mut cards = canonical_gemma_qat_held_out_quality_replay_cards(UPSTREAM_REF);
        let _ = cards[0].task_families.pop();
        assert!(GemmaQatHeldOutQualityReplayLedger::new(
            UPSTREAM_REF,
            cards,
            128_000,
            1_779_214_400_000,
        )
        .is_err());

        let mut cards = canonical_gemma_qat_held_out_quality_replay_cards(UPSTREAM_REF);
        cards[0].hidden_judge_denied = false;
        assert!(GemmaQatHeldOutQualityReplayLedger::new(
            UPSTREAM_REF,
            cards,
            128_000,
            1_779_214_400_000,
        )
        .is_err());
    }

    #[test]
    fn rejects_quality_runtime_or_product_promotion() {
        let mut cards = canonical_gemma_qat_held_out_quality_replay_cards(UPSTREAM_REF);
        cards[0].quality_claimed = true;
        assert!(GemmaQatHeldOutQualityReplayLedger::new(
            UPSTREAM_REF,
            cards,
            128_000,
            1_779_214_400_000,
        )
        .is_err());

        let mut cards = canonical_gemma_qat_held_out_quality_replay_cards(UPSTREAM_REF);
        cards[0].byte_ledger.benchmark_runs = 1;
        assert!(GemmaQatHeldOutQualityReplayLedger::new(
            UPSTREAM_REF,
            cards,
            128_000,
            1_779_214_400_000,
        )
        .is_err());
    }
}
