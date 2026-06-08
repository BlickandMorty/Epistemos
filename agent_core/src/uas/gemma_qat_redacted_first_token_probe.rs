//! Gemma QAT redacted first-token probe contract.
//!
//! This primitive consumes the Gemma E2B/E4B byte/KV/app envelope and defines
//! the metadata-only privacy/runtime contract for a future owner-approved,
//! one-token, redacted first-token probe. It does not open owner paths, execute
//! commands, capture raw prompts/tokens/stdout/stderr, allocate KV/workspace
//! bytes, load model/runtime/provider bytes, or promote Gemma to a product
//! route.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_gemma_qat_byte_kv_app_envelope_cards, GemmaFamilyRuntimeLane, ProStatus,
    ProductBuild, UasAddress, UasKind,
};

pub const GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_ID: &str = "F-GemmaQATRedactedFirstTokenProbe";
pub const GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_CURSOR: &str =
    "gemma_qat_redacted_first_token_probe";
pub const GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_NEXT_CURSOR: &str =
    "gemma_qat_same_fixture_runtime_replay";

const UPSTREAM_ENVELOPE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_byte_kv_app_envelope_preflight/";
const OWNER_LEASE_PREFIX: &str = "owner_lease:gemma_qat_redacted_first_token:";
const PROMPT_TEMPLATE_PREFIX: &str = "prompt_template:gemma_qat_synthetic_redacted:";
const PROMPT_DIGEST_PREFIX: &str = "prompt_digest:sha256_descriptor_only:gemma_qat:";
const TOKEN_DIGEST_PREFIX: &str = "token_digest:sha256_future_first_token_only:gemma_qat:";
const OUTPUT_REDACTION_PREFIX: &str = "redaction:no_stdout_stderr_raw_token:gemma_qat:";
const ONE_TOKEN_PREFIX: &str = "one_token_bound:max_new_tokens_1:gemma_qat:";
const CONTEXT_BATCH_PREFIX: &str = "context_batch_bound:ctx2048_batch1:gemma_qat:";
const MEMORY_SAMPLING_PREFIX: &str = "memory_sampling:preflight_slots_4:gemma_qat:";
const CANCELLATION_PREFIX: &str = "cancellation:gemma_qat_first_token:";
const TEARDOWN_PREFIX: &str = "teardown:gemma_qat_first_token:";
const ROLLBACK_PREFIX: &str = "rollback:gemma_qat_first_token:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:gemma_qat_first_token:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:gemma_qat_first_token:";
const LANE_CAVEAT_PREFIX: &str = "lane_caveat:gemma_qat_runtime_not_proven:";
const NON_PROMOTION_PREFIX: &str = "non_promotion:t1_metadata_only:gemma_qat:";
const MAX_LEDGER_METADATA_BYTES: u64 = 256 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 72 * 1024;
pub const GEMMA_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT: usize = 4;

// UAS: uas:gemma-qat-redacted-first-token:surface
// Plane: Controller.
// Residency: runtime-lane preflight surface only; no runtime is opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatFirstTokenSurface {
    GgufLlamaCppOneTokenPreflight,
    LiteRtLmOneTokenPreflight,
}

// UAS: uas:gemma-qat-redacted-first-token:state
// Plane: Verification.
// Residency: owner-approval pending state; no first token exists yet.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatFirstTokenState {
    OwnerApprovalPendingRedactedFirstTokenPreflight,
    TightCandidateFreshMemoryRequiredRedactedFirstTokenPreflight,
}

// UAS: uas:gemma-qat-redacted-first-token:policy
// Plane: Controller + Verification.
// Residency: privacy and execution policy before any runtime residency.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatFirstTokenPolicy {
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub fresh_memory_sample_required: bool,
    pub raw_prompt_text_denied: bool,
    pub raw_user_prompt_denied: bool,
    pub prompt_digest_required: bool,
    pub prompt_digest_descriptor_only: bool,
    pub raw_token_text_denied: bool,
    pub first_token_digest_required: bool,
    pub first_token_digest_future_only: bool,
    pub stdout_stderr_capture_allowed: bool,
    pub stdout_stderr_redaction_bound: bool,
    pub one_token_bound: bool,
    pub predict_greater_than_one_denied: bool,
    pub context_batch_bounds_required: bool,
    pub memory_samples_required: bool,
    pub cancellation_required: bool,
    pub teardown_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub no_runtime_execution: bool,
    pub no_model_bytes: bool,
    pub no_product_promotion: bool,
    pub no_hidden_authority: bool,
}

impl GemmaQatFirstTokenPolicy {
    pub fn pending(fresh_memory_sample_required: bool) -> Self {
        Self {
            owner_approval_required: true,
            owner_approval_granted: false,
            fresh_memory_sample_required,
            raw_prompt_text_denied: true,
            raw_user_prompt_denied: true,
            prompt_digest_required: true,
            prompt_digest_descriptor_only: true,
            raw_token_text_denied: true,
            first_token_digest_required: true,
            first_token_digest_future_only: true,
            stdout_stderr_capture_allowed: false,
            stdout_stderr_redaction_bound: true,
            one_token_bound: true,
            predict_greater_than_one_denied: true,
            context_batch_bounds_required: true,
            memory_samples_required: true,
            cancellation_required: true,
            teardown_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            no_runtime_execution: true,
            no_model_bytes: true,
            no_product_promotion: true,
            no_hidden_authority: true,
        }
    }

    fn complete(&self) -> bool {
        self.owner_approval_required
            && !self.owner_approval_granted
            && self.fresh_memory_sample_required
            && self.raw_prompt_text_denied
            && self.raw_user_prompt_denied
            && self.prompt_digest_required
            && self.prompt_digest_descriptor_only
            && self.raw_token_text_denied
            && self.first_token_digest_required
            && self.first_token_digest_future_only
            && !self.stdout_stderr_capture_allowed
            && self.stdout_stderr_redaction_bound
            && self.one_token_bound
            && self.predict_greater_than_one_denied
            && self.context_batch_bounds_required
            && self.memory_samples_required
            && self.cancellation_required
            && self.teardown_required
            && self.rollback_required
            && self.run_event_log_required
            && self.answer_packet_required
            && self.no_runtime_execution
            && self.no_model_bytes
            && self.no_product_promotion
            && self.no_hidden_authority
    }
}

// UAS: uas:gemma-qat-redacted-first-token:byte-ledger
// Plane: Verification.
// Residency: byte ledger; raw prompt/token/runtime/model counters stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatFirstTokenByteLedger {
    pub metadata_bytes_read: u64,
    pub schema_bytes_serialized: u64,
    pub prompt_template_descriptor_bytes: u64,
    pub raw_prompt_bytes_captured: u64,
    pub prompt_digest_bytes_captured: u64,
    pub raw_token_bytes_captured: u64,
    pub first_token_digest_bytes_captured: u64,
    pub stdout_bytes_captured: u64,
    pub stderr_bytes_captured: u64,
    pub owner_manifest_bytes_read: u64,
    pub owner_path_bytes_read: u64,
    pub local_file_bytes_read: u64,
    pub kv_cache_bytes_allocated: u64,
    pub runtime_workspace_bytes_allocated: u64,
    pub command_execution_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub network_bytes_read: u64,
    pub benchmark_runs: u64,
    pub product_surface_bytes_written: u64,
}

impl GemmaQatFirstTokenByteLedger {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        schema_bytes_serialized: u64,
        prompt_template_descriptor_bytes: u64,
    ) -> Self {
        Self {
            metadata_bytes_read,
            schema_bytes_serialized,
            prompt_template_descriptor_bytes,
            raw_prompt_bytes_captured: 0,
            prompt_digest_bytes_captured: 0,
            raw_token_bytes_captured: 0,
            first_token_digest_bytes_captured: 0,
            stdout_bytes_captured: 0,
            stderr_bytes_captured: 0,
            owner_manifest_bytes_read: 0,
            owner_path_bytes_read: 0,
            local_file_bytes_read: 0,
            kv_cache_bytes_allocated: 0,
            runtime_workspace_bytes_allocated: 0,
            command_execution_count: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            network_bytes_read: 0,
            benchmark_runs: 0,
            product_surface_bytes_written: 0,
        }
    }

    fn live_bytes_or_actions_observed(&self) -> bool {
        self.raw_prompt_bytes_captured != 0
            || self.prompt_digest_bytes_captured != 0
            || self.raw_token_bytes_captured != 0
            || self.first_token_digest_bytes_captured != 0
            || self.stdout_bytes_captured != 0
            || self.stderr_bytes_captured != 0
            || self.owner_manifest_bytes_read != 0
            || self.owner_path_bytes_read != 0
            || self.local_file_bytes_read != 0
            || self.kv_cache_bytes_allocated != 0
            || self.runtime_workspace_bytes_allocated != 0
            || self.command_execution_count != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.network_bytes_read != 0
            || self.benchmark_runs != 0
            || self.product_surface_bytes_written != 0
    }
}

// UAS: uas:gemma-qat-redacted-first-token:proof-refs
// Plane: Verification.
// Residency: visible proof anchors for future owner-approved runtime probing.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatFirstTokenProofRefs {
    pub upstream_envelope_ref: String,
    pub upstream_envelope_card_id: String,
    pub owner_lease_ref: String,
    pub prompt_template_ref: String,
    pub prompt_digest_policy_ref: String,
    pub token_digest_policy_ref: String,
    pub output_redaction_ref: String,
    pub one_token_bound_ref: String,
    pub context_batch_bound_ref: String,
    pub memory_sampling_ref: String,
    pub cancellation_ref: String,
    pub teardown_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub lane_caveat_ref: String,
    pub non_promotion_ref: String,
}

// UAS: uas:gemma-qat-redacted-first-token:card
// Plane: Controller + Verification.
// Residency: first-token contract only; no model path or token exists yet.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRedactedFirstTokenCard {
    pub card_id: String,
    pub upstream_envelope_ref: String,
    pub upstream_envelope_card_id: String,
    pub model_id: String,
    pub selected_filename_ref: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub surface: GemmaQatFirstTokenSurface,
    pub state: GemmaQatFirstTokenState,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub fresh_memory_sample_required: bool,
    pub prompt_template_visible: bool,
    pub prompt_digest_policy_bound: bool,
    pub raw_prompt_text_present: bool,
    pub raw_user_prompt_present: bool,
    pub first_token_digest_policy_bound: bool,
    pub first_token_observed: bool,
    pub first_token_digest_present: bool,
    pub raw_token_text_present: bool,
    pub stdout_stderr_capture_allowed: bool,
    pub max_new_tokens: u32,
    pub context_cap_tokens: u32,
    pub batch_cap: u32,
    pub memory_sample_slots: Vec<String>,
    pub command_envelope_armed: bool,
    pub command_execution_allowed: bool,
    pub runtime_probe_allowed: bool,
    pub model_path_opened: bool,
    pub local_artifact_verified: bool,
    pub lane_caveat_bound: bool,
    pub policy: GemmaQatFirstTokenPolicy,
    pub byte_ledger: GemmaQatFirstTokenByteLedger,
    pub proof_refs: GemmaQatFirstTokenProofRefs,
    pub route_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub product_route_green: bool,
    pub l2_capability_green: bool,
    pub l3_wrv_green: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub next_cursor: String,
    pub user_visible_summary: String,
}

// UAS: uas:gemma-qat-redacted-first-token:ledger
// Plane: State + Verification.
// Residency: metadata-only first-token preflight ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRedactedFirstTokenLedger {
    pub ledger_address: UasAddress,
    pub upstream_envelope_address: String,
    pub upstream_envelope_ref: String,
    pub cards: Vec<GemmaQatRedactedFirstTokenCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub owner_approval_required: bool,
    pub first_token_probe_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-redacted-first-token:metrics
// Plane: Verification.
// Residency: derived metadata-only counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRedactedFirstTokenMetrics {
    pub card_count: u64,
    pub e2b_card_count: u64,
    pub e4b_card_count: u64,
    pub gguf_lane_count: u64,
    pub litert_lane_count: u64,
    pub owner_approval_granted_count: u64,
    pub fresh_memory_sample_required_count: u64,
    pub prompt_digest_policy_bound_count: u64,
    pub first_token_digest_policy_bound_count: u64,
    pub raw_prompt_text_present_count: u64,
    pub raw_token_text_present_count: u64,
    pub first_token_observed_count: u64,
    pub first_token_digest_present_count: u64,
    pub memory_sample_slot_total_count: u64,
    pub command_envelope_armed_count: u64,
    pub runtime_probe_allowed_count: u64,
    pub local_artifact_verified_count: u64,
    pub raw_prompt_bytes_captured_total: u64,
    pub raw_token_bytes_captured_total: u64,
    pub stdout_bytes_captured_total: u64,
    pub stderr_bytes_captured_total: u64,
    pub owner_manifest_bytes_read_total: u64,
    pub local_file_bytes_read_total: u64,
    pub kv_cache_bytes_allocated_total: u64,
    pub runtime_workspace_bytes_allocated_total: u64,
    pub command_execution_count_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub network_bytes_read_total: u64,
    pub benchmark_runs_total: u64,
    pub product_surface_bytes_written_total: u64,
    pub metadata_bytes_read_total: u64,
    pub route_mutation_allowed_count: u64,
    pub hidden_authority_count: u64,
    pub mas_promotion_count: u64,
    pub product_green_count: u64,
    pub l2_green_count: u64,
    pub l3_green_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
    pub quality_claim_count: u64,
}

impl GemmaQatRedactedFirstTokenLedger {
    pub fn new(
        upstream_envelope_address: impl Into<String>,
        upstream_envelope_ref: impl Into<String>,
        mut cards: Vec<GemmaQatRedactedFirstTokenCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatRedactedFirstTokenError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let upstream_envelope_address = upstream_envelope_address.into();
        let upstream_envelope_ref = upstream_envelope_ref.into();
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_CURSOR.to_string()),
                ledger_preimage(
                    &upstream_envelope_address,
                    &upstream_envelope_ref,
                    &cards,
                    metadata_bytes,
                )
                .as_bytes(),
                created_at_ms,
            ),
            upstream_envelope_address,
            upstream_envelope_ref,
            cards,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            metadata_only: true,
            owner_approval_required: true,
            first_token_probe_deferred: true,
            product_promotion_blocked: true,
            metadata_bytes,
        };
        ledger.validate()?;
        Ok(ledger)
    }

    pub fn validate(&self) -> Result<(), GemmaQatRedactedFirstTokenError> {
        if self.upstream_envelope_address.trim().is_empty()
            || !self
                .upstream_envelope_ref
                .starts_with(UPSTREAM_ENVELOPE_PREFIX)
        {
            return Err(GemmaQatRedactedFirstTokenError::BadUpstreamEnvelopeRef);
        }
        if self.cards.is_empty() {
            return Err(GemmaQatRedactedFirstTokenError::EmptyCardSet);
        }
        if self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatRedactedFirstTokenError::MetadataBudgetExceeded);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || !self.metadata_only
            || !self.owner_approval_required
            || !self.first_token_probe_deferred
            || !self.product_promotion_blocked
        {
            return Err(GemmaQatRedactedFirstTokenError::UnsafeLedgerState);
        }

        let mut card_ids = HashSet::new();
        let mut model_lane_pairs = HashSet::new();
        for card in &self.cards {
            validate_card(card)?;
            if !card_ids.insert(card.card_id.as_str()) {
                return Err(GemmaQatRedactedFirstTokenError::DuplicateCardId(
                    card.card_id.clone(),
                ));
            }
            if !model_lane_pairs.insert((card.model_id.as_str(), card.runtime_lane)) {
                return Err(GemmaQatRedactedFirstTokenError::DuplicateModelLane(
                    card.model_id.clone(),
                ));
            }
        }
        if self.metrics().card_count != 4
            || self.metrics().e2b_card_count != 2
            || self.metrics().e4b_card_count != 2
            || self.metrics().gguf_lane_count != 2
            || self.metrics().litert_lane_count != 2
        {
            return Err(GemmaQatRedactedFirstTokenError::ExpectedPackMismatch);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatRedactedFirstTokenMetrics {
        let mut metrics = GemmaQatRedactedFirstTokenMetrics {
            card_count: self.cards.len() as u64,
            e2b_card_count: 0,
            e4b_card_count: 0,
            gguf_lane_count: 0,
            litert_lane_count: 0,
            owner_approval_granted_count: 0,
            fresh_memory_sample_required_count: 0,
            prompt_digest_policy_bound_count: 0,
            first_token_digest_policy_bound_count: 0,
            raw_prompt_text_present_count: 0,
            raw_token_text_present_count: 0,
            first_token_observed_count: 0,
            first_token_digest_present_count: 0,
            memory_sample_slot_total_count: 0,
            command_envelope_armed_count: 0,
            runtime_probe_allowed_count: 0,
            local_artifact_verified_count: 0,
            raw_prompt_bytes_captured_total: 0,
            raw_token_bytes_captured_total: 0,
            stdout_bytes_captured_total: 0,
            stderr_bytes_captured_total: 0,
            owner_manifest_bytes_read_total: 0,
            local_file_bytes_read_total: 0,
            kv_cache_bytes_allocated_total: 0,
            runtime_workspace_bytes_allocated_total: 0,
            command_execution_count_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            network_bytes_read_total: 0,
            benchmark_runs_total: 0,
            product_surface_bytes_written_total: 0,
            metadata_bytes_read_total: self.metadata_bytes,
            route_mutation_allowed_count: 0,
            hidden_authority_count: 0,
            mas_promotion_count: 0,
            product_green_count: 0,
            l2_green_count: 0,
            l3_green_count: 0,
            live_dense_70b_claim_count: 0,
            ssd_as_ram_claim_count: 0,
            quality_claim_count: 0,
        };
        for card in &self.cards {
            metrics.e2b_card_count += u64::from(card.model_id.contains("E2B"));
            metrics.e4b_card_count += u64::from(card.model_id.contains("E4B"));
            metrics.gguf_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp);
            metrics.litert_lane_count +=
                u64::from(card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm);
            metrics.owner_approval_granted_count += u64::from(card.owner_approval_granted);
            metrics.fresh_memory_sample_required_count +=
                u64::from(card.fresh_memory_sample_required);
            metrics.prompt_digest_policy_bound_count += u64::from(card.prompt_digest_policy_bound);
            metrics.first_token_digest_policy_bound_count +=
                u64::from(card.first_token_digest_policy_bound);
            metrics.raw_prompt_text_present_count += u64::from(card.raw_prompt_text_present);
            metrics.raw_token_text_present_count += u64::from(card.raw_token_text_present);
            metrics.first_token_observed_count += u64::from(card.first_token_observed);
            metrics.first_token_digest_present_count += u64::from(card.first_token_digest_present);
            metrics.memory_sample_slot_total_count += card.memory_sample_slots.len() as u64;
            metrics.command_envelope_armed_count += u64::from(card.command_envelope_armed);
            metrics.runtime_probe_allowed_count += u64::from(card.runtime_probe_allowed);
            metrics.local_artifact_verified_count += u64::from(card.local_artifact_verified);
            metrics.raw_prompt_bytes_captured_total += card.byte_ledger.raw_prompt_bytes_captured;
            metrics.raw_token_bytes_captured_total += card.byte_ledger.raw_token_bytes_captured;
            metrics.stdout_bytes_captured_total += card.byte_ledger.stdout_bytes_captured;
            metrics.stderr_bytes_captured_total += card.byte_ledger.stderr_bytes_captured;
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
            metrics.local_file_bytes_read_total += card.byte_ledger.local_file_bytes_read;
            metrics.kv_cache_bytes_allocated_total += card.byte_ledger.kv_cache_bytes_allocated;
            metrics.runtime_workspace_bytes_allocated_total +=
                card.byte_ledger.runtime_workspace_bytes_allocated;
            metrics.command_execution_count_total += card.byte_ledger.command_execution_count;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.network_bytes_read_total += card.byte_ledger.network_bytes_read;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
            metrics.product_surface_bytes_written_total +=
                card.byte_ledger.product_surface_bytes_written;
            metrics.metadata_bytes_read_total += card.byte_ledger.metadata_bytes_read;
            metrics.route_mutation_allowed_count += u64::from(card.route_mutation_allowed);
            metrics.hidden_authority_count += u64::from(
                card.hidden_route_authority
                    || card.hidden_patternboost_authority
                    || card.hidden_lattice_authority
                    || card.hidden_eidos_authority
                    || card.hidden_cloud_fallback,
            );
            metrics.mas_promotion_count += u64::from(card.mas_promoted);
            metrics.product_green_count += u64::from(card.product_route_green);
            metrics.l2_green_count += u64::from(card.l2_capability_green);
            metrics.l3_green_count += u64::from(card.l3_wrv_green);
            metrics.live_dense_70b_claim_count += u64::from(card.live_dense_70b_claim);
            metrics.ssd_as_ram_claim_count += u64::from(card.ssd_as_ram_claim);
            metrics.quality_claim_count += u64::from(card.quality_claimed);
        }
        metrics
    }
}

pub fn canonical_gemma_qat_redacted_first_token_cards(
    upstream_envelope_ref: &str,
) -> Vec<GemmaQatRedactedFirstTokenCard> {
    let envelope_cards = canonical_gemma_qat_byte_kv_app_envelope_cards(upstream_envelope_ref);
    let mut cards = Vec::with_capacity(envelope_cards.len() * 2);
    for envelope in envelope_cards {
        cards.push(first_token_card(
            upstream_envelope_ref,
            &envelope.upstream_manifest_card_id,
            &envelope.model_id,
            &envelope.selected_filename_ref,
            GemmaFamilyRuntimeLane::GgufLlamaCpp,
            envelope
                .byte_plan
                .tight_candidate_requires_fresh_memory_sample,
        ));
        cards.push(first_token_card(
            upstream_envelope_ref,
            &envelope.upstream_manifest_card_id,
            &envelope.model_id,
            &envelope.selected_filename_ref,
            GemmaFamilyRuntimeLane::LiteRtLm,
            envelope
                .byte_plan
                .tight_candidate_requires_fresh_memory_sample,
        ));
    }
    cards
}

fn first_token_card(
    upstream_envelope_ref: &str,
    upstream_envelope_card_id: &str,
    model_id: &str,
    selected_filename_ref: &str,
    runtime_lane: GemmaFamilyRuntimeLane,
    tight_candidate: bool,
) -> GemmaQatRedactedFirstTokenCard {
    let lane = runtime_lane_slug(runtime_lane);
    let model_slug = model_slug(model_id);
    let card_id = format!("gemma4_{model_slug}_{lane}_redacted_first_token_preflight");
    let state = if tight_candidate {
        GemmaQatFirstTokenState::TightCandidateFreshMemoryRequiredRedactedFirstTokenPreflight
    } else {
        GemmaQatFirstTokenState::OwnerApprovalPendingRedactedFirstTokenPreflight
    };
    let surface = match runtime_lane {
        GemmaFamilyRuntimeLane::GgufLlamaCpp => {
            GemmaQatFirstTokenSurface::GgufLlamaCppOneTokenPreflight
        }
        GemmaFamilyRuntimeLane::LiteRtLm => GemmaQatFirstTokenSurface::LiteRtLmOneTokenPreflight,
        _ => GemmaQatFirstTokenSurface::GgufLlamaCppOneTokenPreflight,
    };
    let memory_sample_slots = (0..GEMMA_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT)
        .map(|slot| format!("memory_sample_slot:{slot}:gemma_qat:{model_slug}:{lane}"))
        .collect::<Vec<_>>();
    GemmaQatRedactedFirstTokenCard {
        card_id: card_id.clone(),
        upstream_envelope_ref: upstream_envelope_ref.to_string(),
        upstream_envelope_card_id: upstream_envelope_card_id.to_string(),
        model_id: model_id.to_string(),
        selected_filename_ref: selected_filename_ref.to_string(),
        runtime_lane,
        surface,
        state,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::Gated,
        owner_approval_required: true,
        owner_approval_granted: false,
        fresh_memory_sample_required: true,
        prompt_template_visible: true,
        prompt_digest_policy_bound: true,
        raw_prompt_text_present: false,
        raw_user_prompt_present: false,
        first_token_digest_policy_bound: true,
        first_token_observed: false,
        first_token_digest_present: false,
        raw_token_text_present: false,
        stdout_stderr_capture_allowed: false,
        max_new_tokens: 1,
        context_cap_tokens: 2_048,
        batch_cap: 1,
        memory_sample_slots,
        command_envelope_armed: false,
        command_execution_allowed: false,
        runtime_probe_allowed: false,
        model_path_opened: false,
        local_artifact_verified: false,
        lane_caveat_bound: true,
        policy: GemmaQatFirstTokenPolicy::pending(true),
        byte_ledger: GemmaQatFirstTokenByteLedger::metadata_only(18_432, 8_192, 4_096),
        proof_refs: proof_refs(upstream_envelope_ref, upstream_envelope_card_id, &card_id),
        route_mutation_allowed: false,
        hidden_route_authority: false,
        hidden_patternboost_authority: false,
        hidden_lattice_authority: false,
        hidden_eidos_authority: false,
        hidden_cloud_fallback: false,
        mas_promoted: false,
        product_route_green: false,
        l2_capability_green: false,
        l3_wrv_green: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        quality_claimed: false,
        benchmark_claimed_as_fit: false,
        next_cursor: GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_NEXT_CURSOR.to_string(),
        user_visible_summary: format!(
            "Gemma {model_slug} {lane} redacted first-token preflight defines only a future owner-approved one-token contract with prompt digest, future token digest, memory sampling, cancellation, teardown, rollback, RunEventLog, and AnswerPacket. It captures no raw prompt, raw token, stdout, stderr, model bytes, or runtime bytes."
        ),
    }
}

fn proof_refs(
    upstream_envelope_ref: &str,
    upstream_envelope_card_id: &str,
    card_id: &str,
) -> GemmaQatFirstTokenProofRefs {
    GemmaQatFirstTokenProofRefs {
        upstream_envelope_ref: upstream_envelope_ref.to_string(),
        upstream_envelope_card_id: upstream_envelope_card_id.to_string(),
        owner_lease_ref: format!("{OWNER_LEASE_PREFIX}{card_id}"),
        prompt_template_ref: format!("{PROMPT_TEMPLATE_PREFIX}{card_id}"),
        prompt_digest_policy_ref: format!("{PROMPT_DIGEST_PREFIX}{card_id}"),
        token_digest_policy_ref: format!("{TOKEN_DIGEST_PREFIX}{card_id}"),
        output_redaction_ref: format!("{OUTPUT_REDACTION_PREFIX}{card_id}"),
        one_token_bound_ref: format!("{ONE_TOKEN_PREFIX}{card_id}"),
        context_batch_bound_ref: format!("{CONTEXT_BATCH_PREFIX}{card_id}"),
        memory_sampling_ref: format!("{MEMORY_SAMPLING_PREFIX}{card_id}"),
        cancellation_ref: format!("{CANCELLATION_PREFIX}{card_id}"),
        teardown_ref: format!("{TEARDOWN_PREFIX}{card_id}"),
        rollback_ref: format!("{ROLLBACK_PREFIX}{card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{card_id}"),
        lane_caveat_ref: format!("{LANE_CAVEAT_PREFIX}{card_id}"),
        non_promotion_ref: format!("{NON_PROMOTION_PREFIX}{card_id}"),
    }
}

fn validate_card(
    card: &GemmaQatRedactedFirstTokenCard,
) -> Result<(), GemmaQatRedactedFirstTokenError> {
    if card.card_id.trim().is_empty()
        || card.model_id.trim().is_empty()
        || card.upstream_envelope_card_id.trim().is_empty()
    {
        return Err(GemmaQatRedactedFirstTokenError::BadCard);
    }
    if !card
        .upstream_envelope_ref
        .starts_with(UPSTREAM_ENVELOPE_PREFIX)
    {
        return Err(GemmaQatRedactedFirstTokenError::BadUpstreamEnvelopeRef);
    }
    if !(card.model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
        || card.model_id == "google/gemma-4-E4B-it-qat-q4_0-gguf")
    {
        return Err(GemmaQatRedactedFirstTokenError::ExpectedPackMismatch);
    }
    if !card.selected_filename_ref.starts_with("hf_file:")
        || !card.selected_filename_ref.ends_with(".gguf")
    {
        return Err(GemmaQatRedactedFirstTokenError::BadSourceRef);
    }
    if !(card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp
        || card.runtime_lane == GemmaFamilyRuntimeLane::LiteRtLm)
    {
        return Err(GemmaQatRedactedFirstTokenError::BadRuntimeLane);
    }
    if card.product_build != ProductBuild::Pro || card.pro_status != ProStatus::Gated {
        return Err(GemmaQatRedactedFirstTokenError::PromotionClaim);
    }
    if card.next_cursor != GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_NEXT_CURSOR {
        return Err(GemmaQatRedactedFirstTokenError::WrongNextCursor);
    }
    if !card.owner_approval_required
        || card.owner_approval_granted
        || !card.fresh_memory_sample_required
        || !card.prompt_template_visible
        || !card.prompt_digest_policy_bound
        || card.raw_prompt_text_present
        || card.raw_user_prompt_present
        || !card.first_token_digest_policy_bound
        || card.first_token_observed
        || card.first_token_digest_present
        || card.raw_token_text_present
        || card.stdout_stderr_capture_allowed
    {
        return Err(GemmaQatRedactedFirstTokenError::PrivacyBoundaryBroken);
    }
    if card.max_new_tokens != 1
        || card.context_cap_tokens == 0
        || card.context_cap_tokens > 4_096
        || card.batch_cap != 1
        || card.memory_sample_slots.len() != GEMMA_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT
        || card.command_envelope_armed
        || card.command_execution_allowed
        || card.runtime_probe_allowed
        || card.model_path_opened
        || card.local_artifact_verified
        || !card.lane_caveat_bound
    {
        return Err(GemmaQatRedactedFirstTokenError::RuntimeBoundaryBroken);
    }
    let mut seen_slots = HashSet::new();
    for slot in &card.memory_sample_slots {
        if !slot.starts_with("memory_sample_slot:") || !seen_slots.insert(slot.as_str()) {
            return Err(GemmaQatRedactedFirstTokenError::MemorySampleSlotsInvalid);
        }
    }
    if !card.policy.complete() {
        return Err(GemmaQatRedactedFirstTokenError::PolicyBroken);
    }
    validate_proof_refs(&card.proof_refs)?;
    if card.byte_ledger.metadata_bytes_read == 0
        || card.byte_ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.byte_ledger.schema_bytes_serialized == 0
        || card.byte_ledger.prompt_template_descriptor_bytes == 0
        || card.byte_ledger.live_bytes_or_actions_observed()
    {
        return Err(GemmaQatRedactedFirstTokenError::BytesOrCommandsObserved);
    }
    if card.route_mutation_allowed
        || card.hidden_route_authority
        || card.hidden_patternboost_authority
        || card.hidden_lattice_authority
        || card.hidden_eidos_authority
        || card.hidden_cloud_fallback
        || card.mas_promoted
        || card.product_route_green
        || card.l2_capability_green
        || card.l3_wrv_green
        || card.live_dense_70b_claim
        || card.ssd_as_ram_claim
        || card.quality_claimed
        || card.benchmark_claimed_as_fit
    {
        return Err(GemmaQatRedactedFirstTokenError::PromotionClaim);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatFirstTokenProofRefs,
) -> Result<(), GemmaQatRedactedFirstTokenError> {
    let ok = refs
        .upstream_envelope_ref
        .starts_with(UPSTREAM_ENVELOPE_PREFIX)
        && !refs.upstream_envelope_card_id.trim().is_empty()
        && refs.owner_lease_ref.starts_with(OWNER_LEASE_PREFIX)
        && refs.prompt_template_ref.starts_with(PROMPT_TEMPLATE_PREFIX)
        && refs
            .prompt_digest_policy_ref
            .starts_with(PROMPT_DIGEST_PREFIX)
        && refs
            .token_digest_policy_ref
            .starts_with(TOKEN_DIGEST_PREFIX)
        && refs
            .output_redaction_ref
            .starts_with(OUTPUT_REDACTION_PREFIX)
        && refs.one_token_bound_ref.starts_with(ONE_TOKEN_PREFIX)
        && refs
            .context_batch_bound_ref
            .starts_with(CONTEXT_BATCH_PREFIX)
        && refs.memory_sampling_ref.starts_with(MEMORY_SAMPLING_PREFIX)
        && refs.cancellation_ref.starts_with(CANCELLATION_PREFIX)
        && refs.teardown_ref.starts_with(TEARDOWN_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
        && refs.lane_caveat_ref.starts_with(LANE_CAVEAT_PREFIX)
        && refs.non_promotion_ref.starts_with(NON_PROMOTION_PREFIX);
    if ok {
        Ok(())
    } else {
        Err(GemmaQatRedactedFirstTokenError::BadProofRef)
    }
}

fn ledger_preimage(
    upstream_envelope_address: &str,
    upstream_envelope_ref: &str,
    cards: &[GemmaQatRedactedFirstTokenCard],
    metadata_bytes: u64,
) -> String {
    serde_json::json!({
        "cursor": GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_CURSOR,
        "upstream_envelope_address": upstream_envelope_address,
        "upstream_envelope_ref": upstream_envelope_ref,
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

// UAS: uas:gemma-qat-redacted-first-token:error
// Plane: Verification.
// Residency: fail-closed first-token preflight rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatRedactedFirstTokenError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelLane(String),
    BadCard,
    BadUpstreamEnvelopeRef,
    BadSourceRef,
    BadRuntimeLane,
    ExpectedPackMismatch,
    UnsafeLedgerState,
    PrivacyBoundaryBroken,
    RuntimeBoundaryBroken,
    MemorySampleSlotsInvalid,
    PolicyBroken,
    BadProofRef,
    BytesOrCommandsObserved,
    PromotionClaim,
    MetadataBudgetExceeded,
    WrongNextCursor,
}

impl fmt::Display for GemmaQatRedactedFirstTokenError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "empty card set"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id {id}"),
            Self::DuplicateModelLane(id) => write!(f, "duplicate model/runtime lane {id}"),
            Self::BadCard => write!(f, "bad card"),
            Self::BadUpstreamEnvelopeRef => write!(f, "bad upstream envelope ref"),
            Self::BadSourceRef => write!(f, "bad source ref"),
            Self::BadRuntimeLane => write!(f, "bad runtime lane"),
            Self::ExpectedPackMismatch => write!(f, "expected Gemma E2B/E4B lane pack mismatch"),
            Self::UnsafeLedgerState => write!(f, "unsafe ledger state"),
            Self::PrivacyBoundaryBroken => write!(f, "privacy boundary broken"),
            Self::RuntimeBoundaryBroken => write!(f, "runtime boundary broken"),
            Self::MemorySampleSlotsInvalid => write!(f, "memory sample slots invalid"),
            Self::PolicyBroken => write!(f, "policy broken"),
            Self::BadProofRef => write!(f, "bad proof ref"),
            Self::BytesOrCommandsObserved => write!(f, "bytes or commands observed"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::WrongNextCursor => write!(f, "wrong next cursor"),
        }
    }
}

impl std::error::Error for GemmaQatRedactedFirstTokenError {}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_byte_kv_app_envelope_preflight/result.json#F-GemmaQATByteKVAppEnvelopePreflight";

    fn ledger() -> Result<GemmaQatRedactedFirstTokenLedger, GemmaQatRedactedFirstTokenError> {
        GemmaQatRedactedFirstTokenLedger::new(
            "uas:gemma-byte-envelope:test",
            UPSTREAM_REF,
            canonical_gemma_qat_redacted_first_token_cards(UPSTREAM_REF),
            96_000,
            1_779_212_800_000,
        )
    }

    #[test]
    fn canonical_first_token_preflight_validates_without_runtime_bytes() {
        let Ok(ledger) = ledger() else {
            panic!("canonical Gemma first-token ledger should validate");
        };
        let metrics = ledger.metrics();
        assert_eq!(metrics.card_count, 4);
        assert_eq!(metrics.e2b_card_count, 2);
        assert_eq!(metrics.e4b_card_count, 2);
        assert_eq!(metrics.gguf_lane_count, 2);
        assert_eq!(metrics.litert_lane_count, 2);
        assert_eq!(metrics.memory_sample_slot_total_count, 16);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
        assert_eq!(metrics.raw_prompt_bytes_captured_total, 0);
        assert_eq!(metrics.raw_token_bytes_captured_total, 0);
        assert_eq!(metrics.l2_green_count, 0);
    }

    #[test]
    fn rejects_runtime_execution_or_prompt_capture() {
        let mut cards = canonical_gemma_qat_redacted_first_token_cards(UPSTREAM_REF);
        cards[0].runtime_probe_allowed = true;
        assert!(GemmaQatRedactedFirstTokenLedger::new(
            "uas:gemma-byte-envelope:test",
            UPSTREAM_REF,
            cards,
            96_000,
            1_779_212_800_000,
        )
        .is_err());

        let mut cards = canonical_gemma_qat_redacted_first_token_cards(UPSTREAM_REF);
        cards[0].raw_prompt_text_present = true;
        assert!(GemmaQatRedactedFirstTokenLedger::new(
            "uas:gemma-byte-envelope:test",
            UPSTREAM_REF,
            cards,
            96_000,
            1_779_212_800_000,
        )
        .is_err());
    }

    #[test]
    fn rejects_product_or_quality_promotion() {
        let mut cards = canonical_gemma_qat_redacted_first_token_cards(UPSTREAM_REF);
        cards[0].product_route_green = true;
        assert!(GemmaQatRedactedFirstTokenLedger::new(
            "uas:gemma-byte-envelope:test",
            UPSTREAM_REF,
            cards,
            96_000,
            1_779_212_800_000,
        )
        .is_err());

        let mut cards = canonical_gemma_qat_redacted_first_token_cards(UPSTREAM_REF);
        cards[0].quality_claimed = true;
        assert!(GemmaQatRedactedFirstTokenLedger::new(
            "uas:gemma-byte-envelope:test",
            UPSTREAM_REF,
            cards,
            96_000,
            1_779_212_800_000,
        )
        .is_err());
    }
}
