//! Gemma QAT owner-approved runtime replay transcript gate.
//!
//! This primitive consumes the held-out quality replay packet and defines the
//! fail-closed transcript template required before any Gemma runtime replay can
//! be attempted. It records no runtime output and opens no model paths.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_gemma_qat_held_out_quality_replay_cards, GemmaFamilyRuntimeLane, ProStatus,
    ProductBuild, UasAddress, UasKind,
};

pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_ID: &str =
    "F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_CURSOR: &str =
    "gemma_qat_owner_approved_runtime_replay_transcript_gate";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_NEXT_CURSOR: &str =
    "gemma_qat_owner_approved_runtime_replay_probe";

const UPSTREAM_HELD_OUT_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_held_out_quality_replay_packet/";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:gemma_qat_runtime_replay:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:unarmed:gemma_qat_runtime_replay:";
const MODEL_PATH_PREFIX: &str = "model_path:pending_owner_manifest:gemma_qat_runtime_replay:";
const RUNTIME_LANE_PREFIX: &str = "runtime_lane:gemma_qat_runtime_replay:";
const MEMORY_SAMPLE_PREFIX: &str = "memory_sample:required_before_runtime:";
const PROMPT_DIGEST_PREFIX: &str = "prompt_digest_policy:redacted:";
const OUTPUT_DIGEST_PREFIX: &str = "output_digest_policy:redacted:";
const CANCELLATION_PREFIX: &str = "cancellation:required:";
const ROLLBACK_PREFIX: &str = "rollback:required:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:required:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:required:";
const ABSTENTION_PREFIX: &str = "abstention:required:";
const NO_PROMOTION_PREFIX: &str = "non_promotion:";
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAX_LEDGER_METADATA_BYTES: u64 = 384 * 1024;

// UAS: uas:gemma-qat-runtime-replay-transcript:state
// Plane: Controller + Verification.
// Residency: transcript gate only; approved runtime is a later witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatRuntimeReplayTranscriptState {
    OwnerApprovalPendingTranscriptGate,
}

// UAS: uas:gemma-qat-runtime-replay-transcript:byte-ledger
// Plane: Verification.
// Residency: planned transcript metadata; all live/runtime counters stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRuntimeReplayTranscriptByteLedger {
    pub metadata_bytes_read: u64,
    pub transcript_template_bytes: u64,
    pub memory_sample_descriptor_bytes: u64,
    pub opened_model_file_bytes: u64,
    pub opened_runtime_file_bytes: u64,
    pub captured_raw_prompt_bytes: u64,
    pub captured_raw_output_bytes: u64,
    pub captured_stdout_bytes: u64,
    pub captured_stderr_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub command_execution_count: u64,
    pub scorer_execution_count: u64,
}

impl GemmaQatRuntimeReplayTranscriptByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        transcript_template_bytes: u64,
        memory_sample_descriptor_bytes: u64,
    ) -> Self {
        Self {
            metadata_bytes_read,
            transcript_template_bytes,
            memory_sample_descriptor_bytes,
            opened_model_file_bytes: 0,
            opened_runtime_file_bytes: 0,
            captured_raw_prompt_bytes: 0,
            captured_raw_output_bytes: 0,
            captured_stdout_bytes: 0,
            captured_stderr_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            command_execution_count: 0,
            scorer_execution_count: 0,
        }
    }

    fn live_bytes_or_actions_observed(&self) -> bool {
        self.opened_model_file_bytes != 0
            || self.opened_runtime_file_bytes != 0
            || self.captured_raw_prompt_bytes != 0
            || self.captured_raw_output_bytes != 0
            || self.captured_stdout_bytes != 0
            || self.captured_stderr_bytes != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.command_execution_count != 0
            || self.scorer_execution_count != 0
    }
}

// UAS: uas:gemma-qat-runtime-replay-transcript:proof-refs
// Plane: Verification.
// Residency: proof handles only; no command or model path is opened here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRuntimeReplayTranscriptProofRefs {
    pub upstream_held_out_ref: String,
    pub upstream_held_out_card_id: String,
    pub owner_approval_ref: String,
    pub command_envelope_ref: String,
    pub model_path_ref: String,
    pub runtime_lane_ref: String,
    pub memory_sample_ref: String,
    pub prompt_digest_policy_ref: String,
    pub output_digest_policy_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub no_promotion_ref: String,
}

// UAS: uas:gemma-qat-runtime-replay-transcript:card
// Plane: Controller + Verification.
// Residency: owner-approval transcript template, not runtime evidence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayTranscriptCard {
    pub card_id: String,
    pub upstream_held_out_ref: String,
    pub upstream_held_out_card_id: String,
    pub model_id: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub state: GemmaQatRuntimeReplayTranscriptState,
    pub selected_first_probe_candidate: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
    pub transcript_template_visible: bool,
    pub memory_sample_required_before_runtime: bool,
    pub memory_sample_freshness_bound: bool,
    pub prompt_digest_policy_bound: bool,
    pub output_digest_policy_bound: bool,
    pub raw_prompt_denied: bool,
    pub raw_output_denied: bool,
    pub stdout_stderr_denied: bool,
    pub cancellation_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub l1_architecture_effect: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub product_route_green: bool,
    pub live_gemma_default_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub byte_ledger: GemmaQatRuntimeReplayTranscriptByteLedger,
    pub proof_refs: GemmaQatRuntimeReplayTranscriptProofRefs,
    pub next_cursor: String,
}

// UAS: uas:gemma-qat-runtime-replay-transcript:ledger
// Plane: State + Controller + Verification.
// Residency: metadata-only transcript gate ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger {
    pub ledger_address: UasAddress,
    pub upstream_held_out_ref: String,
    pub cards: Vec<GemmaQatOwnerApprovedRuntimeReplayTranscriptCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub owner_approval_pending: bool,
    pub runtime_replay_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-runtime-replay-transcript:metrics
// Plane: Verification.
// Residency: derived metadata-only counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayTranscriptMetrics {
    pub card_count: u64,
    pub e2b_card_count: u64,
    pub e4b_card_count: u64,
    pub gguf_lane_count: u64,
    pub litert_lane_count: u64,
    pub selected_first_probe_candidate_count: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub command_envelope_visible_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub runtime_replay_performed_count: u64,
    pub transcript_template_visible_count: u64,
    pub memory_sample_required_count: u64,
    pub prompt_digest_policy_bound_count: u64,
    pub output_digest_policy_bound_count: u64,
    pub opened_model_file_bytes_total: u64,
    pub opened_runtime_file_bytes_total: u64,
    pub captured_raw_prompt_bytes_total: u64,
    pub captured_raw_output_bytes_total: u64,
    pub captured_stdout_bytes_total: u64,
    pub captured_stderr_bytes_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub scorer_execution_count_total: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub quality_claim_count: u64,
    pub metadata_bytes_read_total: u64,
}

impl GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger {
    pub fn new(
        upstream_held_out_ref: impl Into<String>,
        mut cards: Vec<GemmaQatOwnerApprovedRuntimeReplayTranscriptCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatOwnerApprovedRuntimeReplayTranscriptError> {
        let upstream_held_out_ref = upstream_held_out_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(
                    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_CURSOR.to_string(),
                ),
                transcript_preimage(&upstream_held_out_ref, &cards, metadata_bytes).as_bytes(),
                created_at_ms,
            ),
            upstream_held_out_ref,
            cards,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            metadata_only: true,
            owner_approval_pending: true,
            runtime_replay_deferred: true,
            product_promotion_blocked: true,
            metadata_bytes,
        };
        ledger.validate()?;
        Ok(ledger)
    }

    pub fn validate(&self) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayTranscriptError> {
        if !self
            .upstream_held_out_ref
            .starts_with(UPSTREAM_HELD_OUT_PREFIX)
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::BadUpstreamRef);
        }
        if self.cards.is_empty() {
            return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::EmptyCardSet);
        }
        if self.metadata_bytes == 0 || self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::MetadataBudgetExceeded);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || !self.metadata_only
            || !self.owner_approval_pending
            || !self.runtime_replay_deferred
            || !self.product_promotion_blocked
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::UnsafeLedgerState);
        }

        let mut ids = HashSet::new();
        let mut model_lanes = HashSet::new();
        for card in &self.cards {
            validate_card(card, &self.upstream_held_out_ref)?;
            if !ids.insert(card.card_id.as_str()) {
                return Err(
                    GemmaQatOwnerApprovedRuntimeReplayTranscriptError::DuplicateCardId(
                        card.card_id.clone(),
                    ),
                );
            }
            if !model_lanes.insert((card.model_id.as_str(), card.runtime_lane)) {
                return Err(
                    GemmaQatOwnerApprovedRuntimeReplayTranscriptError::DuplicateModelLane(
                        card.model_id.clone(),
                    ),
                );
            }
        }
        let metrics = self.metrics();
        if metrics.card_count != 4
            || metrics.e2b_card_count != 2
            || metrics.e4b_card_count != 2
            || metrics.gguf_lane_count != 2
            || metrics.litert_lane_count != 2
            || metrics.selected_first_probe_candidate_count != 1
            || metrics.owner_approval_granted_count != 0
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::ExpectedPackMismatch);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatOwnerApprovedRuntimeReplayTranscriptMetrics {
        let mut metrics = GemmaQatOwnerApprovedRuntimeReplayTranscriptMetrics {
            card_count: self.cards.len() as u64,
            e2b_card_count: 0,
            e4b_card_count: 0,
            gguf_lane_count: 0,
            litert_lane_count: 0,
            selected_first_probe_candidate_count: 0,
            owner_approval_required_count: 0,
            owner_approval_granted_count: 0,
            command_envelope_visible_count: 0,
            command_armed_count: 0,
            command_executed_count: 0,
            runtime_replay_performed_count: 0,
            transcript_template_visible_count: 0,
            memory_sample_required_count: 0,
            prompt_digest_policy_bound_count: 0,
            output_digest_policy_bound_count: 0,
            opened_model_file_bytes_total: 0,
            opened_runtime_file_bytes_total: 0,
            captured_raw_prompt_bytes_total: 0,
            captured_raw_output_bytes_total: 0,
            captured_stdout_bytes_total: 0,
            captured_stderr_bytes_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            scorer_execution_count_total: 0,
            hidden_authority_count: 0,
            promotion_claim_count: 0,
            quality_claim_count: 0,
            metadata_bytes_read_total: self.metadata_bytes,
        };
        for card in &self.cards {
            metrics.e2b_card_count += u64::from(card.model_id.contains("E2B"));
            metrics.e4b_card_count += u64::from(card.model_id.contains("E4B"));
            metrics.gguf_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp);
            metrics.litert_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm);
            metrics.selected_first_probe_candidate_count +=
                u64::from(card.selected_first_probe_candidate);
            metrics.owner_approval_required_count += u64::from(card.owner_approval_required);
            metrics.owner_approval_granted_count += u64::from(card.owner_approval_granted);
            metrics.command_envelope_visible_count += u64::from(card.command_envelope_visible);
            metrics.command_armed_count += u64::from(card.command_armed);
            metrics.command_executed_count += u64::from(card.command_executed);
            metrics.runtime_replay_performed_count += u64::from(card.runtime_replay_performed);
            metrics.transcript_template_visible_count +=
                u64::from(card.transcript_template_visible);
            metrics.memory_sample_required_count +=
                u64::from(card.memory_sample_required_before_runtime);
            metrics.prompt_digest_policy_bound_count += u64::from(card.prompt_digest_policy_bound);
            metrics.output_digest_policy_bound_count += u64::from(card.output_digest_policy_bound);
            metrics.opened_model_file_bytes_total += card.byte_ledger.opened_model_file_bytes;
            metrics.opened_runtime_file_bytes_total += card.byte_ledger.opened_runtime_file_bytes;
            metrics.captured_raw_prompt_bytes_total += card.byte_ledger.captured_raw_prompt_bytes;
            metrics.captured_raw_output_bytes_total += card.byte_ledger.captured_raw_output_bytes;
            metrics.captured_stdout_bytes_total += card.byte_ledger.captured_stdout_bytes;
            metrics.captured_stderr_bytes_total += card.byte_ledger.captured_stderr_bytes;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.scorer_execution_count_total += card.byte_ledger.scorer_execution_count;
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
                    || card.live_gemma_default_claim
                    || card.live_dense_70b_claim
                    || card.ssd_as_ram_claim,
            );
            metrics.quality_claim_count +=
                u64::from(card.quality_claimed || card.benchmark_claimed_as_fit);
            metrics.metadata_bytes_read_total += card.byte_ledger.metadata_bytes_read;
        }
        metrics
    }
}

pub fn canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(
    upstream_held_out_ref: &str,
) -> Vec<GemmaQatOwnerApprovedRuntimeReplayTranscriptCard> {
    canonical_gemma_qat_held_out_quality_replay_cards(upstream_held_out_ref)
        .into_iter()
        .map(|card| {
            let model_slug = model_slug(&card.model_id);
            let lane_slug = runtime_lane_slug(card.runtime_lane);
            let selected_first_probe_candidate =
                model_slug == "e2b" && lane_slug == "gguf_llama_cpp";
            let card_id = format!("gemma4_{model_slug}_{lane_slug}_runtime_replay_transcript_gate");
            GemmaQatOwnerApprovedRuntimeReplayTranscriptCard {
                card_id: card_id.clone(),
                upstream_held_out_ref: upstream_held_out_ref.to_string(),
                upstream_held_out_card_id: card.card_id,
                model_id: card.model_id,
                runtime_lane: card.runtime_lane,
                state: GemmaQatRuntimeReplayTranscriptState::OwnerApprovalPendingTranscriptGate,
                selected_first_probe_candidate,
                owner_approval_required: true,
                owner_approval_granted: false,
                command_envelope_visible: true,
                command_armed: false,
                command_executed: false,
                runtime_replay_performed: false,
                transcript_template_visible: true,
                memory_sample_required_before_runtime: true,
                memory_sample_freshness_bound: true,
                prompt_digest_policy_bound: true,
                output_digest_policy_bound: true,
                raw_prompt_denied: true,
                raw_output_denied: true,
                stdout_stderr_denied: true,
                cancellation_bound: true,
                rollback_bound: true,
                run_event_log_bound: true,
                answer_packet_bound: true,
                abstention_bound: true,
                product_build: ProductBuild::Pro,
                pro_status: ProStatus::Gated,
                l1_architecture_effect: true,
                l2_capability_effect: false,
                l3_wrv_effect: false,
                runtime_router_mutation_allowed: false,
                system_g_mutation_allowed: false,
                hidden_route_authority: false,
                hidden_eidos_authority: false,
                hidden_lattice_authority: false,
                hidden_patternboost_authority: false,
                hidden_cloud_fallback: false,
                mas_promoted: false,
                product_route_green: false,
                live_gemma_default_claim: false,
                live_dense_70b_claim: false,
                ssd_as_ram_claim: false,
                quality_claimed: false,
                benchmark_claimed_as_fit: false,
                byte_ledger: GemmaQatRuntimeReplayTranscriptByteLedger::metadata_only(
                    24_576, 16_384, 4_096,
                ),
                proof_refs: proof_refs(upstream_held_out_ref, &card_id, lane_slug),
                next_cursor: GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_NEXT_CURSOR
                    .to_string(),
            }
        })
        .collect()
}

fn validate_card(
    card: &GemmaQatOwnerApprovedRuntimeReplayTranscriptCard,
    upstream_held_out_ref: &str,
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayTranscriptError> {
    if card.card_id.trim().is_empty()
        || card.upstream_held_out_ref != upstream_held_out_ref
        || card.upstream_held_out_card_id.trim().is_empty()
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::BadCard);
    }
    if !(card.model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
        || card.model_id == "google/gemma-4-E4B-it-qat-q4_0-gguf")
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::ExpectedPackMismatch);
    }
    if !(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp
        || card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm)
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::BadRuntimeLane);
    }
    if card.state != GemmaQatRuntimeReplayTranscriptState::OwnerApprovalPendingTranscriptGate
        || !card.owner_approval_required
        || card.owner_approval_granted
        || !card.command_envelope_visible
        || card.command_armed
        || card.command_executed
        || card.runtime_replay_performed
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::OwnerApprovalBoundaryBroken);
    }
    if !card.transcript_template_visible
        || !card.memory_sample_required_before_runtime
        || !card.memory_sample_freshness_bound
        || !card.prompt_digest_policy_bound
        || !card.output_digest_policy_bound
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::TranscriptBoundaryBroken);
    }
    if !card.raw_prompt_denied || !card.raw_output_denied || !card.stdout_stderr_denied {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::PrivacyBoundaryBroken);
    }
    if !card.cancellation_bound
        || !card.rollback_bound
        || !card.run_event_log_bound
        || !card.answer_packet_bound
        || !card.abstention_bound
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::ProofBoundaryBroken);
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::Gated
        || !card.l1_architecture_effect
        || card.l2_capability_effect
        || card.l3_wrv_effect
        || card.runtime_router_mutation_allowed
        || card.system_g_mutation_allowed
        || card.hidden_route_authority
        || card.hidden_eidos_authority
        || card.hidden_lattice_authority
        || card.hidden_patternboost_authority
        || card.hidden_cloud_fallback
        || card.mas_promoted
        || card.product_route_green
        || card.live_gemma_default_claim
        || card.live_dense_70b_claim
        || card.ssd_as_ram_claim
        || card.quality_claimed
        || card.benchmark_claimed_as_fit
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::PromotionClaim);
    }
    if card.byte_ledger.metadata_bytes_read == 0
        || card.byte_ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.byte_ledger.transcript_template_bytes == 0
        || card.byte_ledger.memory_sample_descriptor_bytes == 0
        || card.byte_ledger.live_bytes_or_actions_observed()
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::BytesOrActionsObserved);
    }
    validate_proof_refs(&card.proof_refs)?;
    if card.next_cursor != GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_NEXT_CURSOR {
        return Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::WrongNextCursor);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatRuntimeReplayTranscriptProofRefs,
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayTranscriptError> {
    let ok = refs
        .upstream_held_out_ref
        .starts_with(UPSTREAM_HELD_OUT_PREFIX)
        && !refs.upstream_held_out_card_id.trim().is_empty()
        && refs.owner_approval_ref.starts_with(OWNER_APPROVAL_PREFIX)
        && refs
            .command_envelope_ref
            .starts_with(COMMAND_ENVELOPE_PREFIX)
        && refs.model_path_ref.starts_with(MODEL_PATH_PREFIX)
        && refs.runtime_lane_ref.starts_with(RUNTIME_LANE_PREFIX)
        && refs.memory_sample_ref.starts_with(MEMORY_SAMPLE_PREFIX)
        && refs
            .prompt_digest_policy_ref
            .starts_with(PROMPT_DIGEST_PREFIX)
        && refs
            .output_digest_policy_ref
            .starts_with(OUTPUT_DIGEST_PREFIX)
        && refs.cancellation_ref.starts_with(CANCELLATION_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
        && refs.abstention_ref.starts_with(ABSTENTION_PREFIX)
        && refs.no_promotion_ref.starts_with(NO_PROMOTION_PREFIX);
    if ok {
        Ok(())
    } else {
        Err(GemmaQatOwnerApprovedRuntimeReplayTranscriptError::BadProofRef)
    }
}

fn proof_refs(
    upstream_held_out_ref: &str,
    card_id: &str,
    lane_slug: &str,
) -> GemmaQatRuntimeReplayTranscriptProofRefs {
    GemmaQatRuntimeReplayTranscriptProofRefs {
        upstream_held_out_ref: upstream_held_out_ref.to_string(),
        upstream_held_out_card_id: card_id.replace(
            "_runtime_replay_transcript_gate",
            "_held_out_quality_replay",
        ),
        owner_approval_ref: format!("{OWNER_APPROVAL_PREFIX}{card_id}"),
        command_envelope_ref: format!("{COMMAND_ENVELOPE_PREFIX}{card_id}"),
        model_path_ref: format!("{MODEL_PATH_PREFIX}{card_id}"),
        runtime_lane_ref: format!("{RUNTIME_LANE_PREFIX}{lane_slug}:{card_id}"),
        memory_sample_ref: format!("{MEMORY_SAMPLE_PREFIX}{card_id}"),
        prompt_digest_policy_ref: format!("{PROMPT_DIGEST_PREFIX}{card_id}"),
        output_digest_policy_ref: format!("{OUTPUT_DIGEST_PREFIX}{card_id}"),
        cancellation_ref: format!("{CANCELLATION_PREFIX}{card_id}"),
        rollback_ref: format!("{ROLLBACK_PREFIX}{card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{card_id}"),
        abstention_ref: format!("{ABSTENTION_PREFIX}{card_id}"),
        no_promotion_ref: format!("{NO_PROMOTION_PREFIX}{card_id}"),
    }
}

fn transcript_preimage(
    upstream_held_out_ref: &str,
    cards: &[GemmaQatOwnerApprovedRuntimeReplayTranscriptCard],
    metadata_bytes: u64,
) -> String {
    serde_json::json!({
        "cursor": GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_CURSOR,
        "upstream_held_out_ref": upstream_held_out_ref,
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

// UAS: uas:gemma-qat-runtime-replay-transcript:error
// Plane: Verification.
// Residency: fail-closed transcript gate rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatOwnerApprovedRuntimeReplayTranscriptError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelLane(String),
    BadCard,
    BadUpstreamRef,
    BadRuntimeLane,
    ExpectedPackMismatch,
    UnsafeLedgerState,
    OwnerApprovalBoundaryBroken,
    TranscriptBoundaryBroken,
    PrivacyBoundaryBroken,
    ProofBoundaryBroken,
    BadProofRef,
    BytesOrActionsObserved,
    PromotionClaim,
    MetadataBudgetExceeded,
    WrongNextCursor,
}

impl fmt::Display for GemmaQatOwnerApprovedRuntimeReplayTranscriptError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "empty card set"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id {id}"),
            Self::DuplicateModelLane(id) => write!(f, "duplicate model/runtime lane {id}"),
            Self::BadCard => write!(f, "bad card"),
            Self::BadUpstreamRef => write!(f, "bad upstream ref"),
            Self::BadRuntimeLane => write!(f, "bad runtime lane"),
            Self::ExpectedPackMismatch => write!(f, "expected Gemma transcript pack mismatch"),
            Self::UnsafeLedgerState => write!(f, "unsafe ledger state"),
            Self::OwnerApprovalBoundaryBroken => write!(f, "owner approval boundary broken"),
            Self::TranscriptBoundaryBroken => write!(f, "transcript boundary broken"),
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

impl std::error::Error for GemmaQatOwnerApprovedRuntimeReplayTranscriptError {}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_held_out_quality_replay_packet/result.json#F-GemmaQATHeldOutQualityReplayPacket";

    fn ledger() -> Result<
        GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger,
        GemmaQatOwnerApprovedRuntimeReplayTranscriptError,
    > {
        GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
            UPSTREAM_REF,
            canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(UPSTREAM_REF),
            144_000,
            1_779_215_200_000,
        )
    }

    #[test]
    fn canonical_transcript_gate_validates_without_runtime_or_model_bytes() {
        let Ok(ledger) = ledger() else {
            panic!("canonical Gemma transcript gate should validate");
        };
        let metrics = ledger.metrics();
        assert_eq!(metrics.card_count, 4);
        assert_eq!(metrics.selected_first_probe_candidate_count, 1);
        assert_eq!(metrics.owner_approval_granted_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
    }

    #[test]
    fn rejects_owner_approval_or_execution_laundering() {
        let mut cards =
            canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(UPSTREAM_REF);
        cards[0].owner_approval_granted = true;
        assert!(GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
            UPSTREAM_REF,
            cards,
            144_000,
            1_779_215_200_000,
        )
        .is_err());

        let mut cards =
            canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(UPSTREAM_REF);
        cards[0].command_executed = true;
        assert!(GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
            UPSTREAM_REF,
            cards,
            144_000,
            1_779_215_200_000,
        )
        .is_err());
    }

    #[test]
    fn rejects_raw_output_runtime_bytes_or_product_promotion() {
        let mut cards =
            canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(UPSTREAM_REF);
        cards[0].byte_ledger.captured_raw_output_bytes = 1;
        assert!(GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
            UPSTREAM_REF,
            cards,
            144_000,
            1_779_215_200_000,
        )
        .is_err());

        let mut cards =
            canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(UPSTREAM_REF);
        cards[0].live_gemma_default_claim = true;
        assert!(GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
            UPSTREAM_REF,
            cards,
            144_000,
            1_779_215_200_000,
        )
        .is_err());
    }
}
