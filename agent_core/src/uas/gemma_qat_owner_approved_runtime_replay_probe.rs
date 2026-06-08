//! Gemma QAT owner-approved runtime replay probe envelope.
//!
//! This primitive consumes the Gemma runtime transcript gate and defines the
//! exact smallest E2B GGUF replay probe envelope that may later run only after
//! explicit owner approval. It is still metadata-only: no model path is opened,
//! no command is armed, no token is captured, and no Gemma default-model claim
//! is promoted.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards, GemmaFamilyRuntimeLane,
    ProStatus, ProductBuild, UasAddress, UasKind,
};

pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_ID: &str =
    "F-GemmaQATOwnerApprovedRuntimeReplayProbe";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_CURSOR: &str =
    "gemma_qat_owner_approved_runtime_replay_probe";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR: &str =
    "gemma_qat_runtime_replay_execution_artifact_gate";

pub const GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
pub const GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME: &str = "gemma-4-E2B_q4_0-it.gguf";
pub const GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH: &str = "/opt/homebrew/bin/llama-cli";

const UPSTREAM_TRANSCRIPT_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_transcript_gate/";
const SELECTED_TRANSCRIPT_CARD_ID: &str =
    "gemma4_e2b_gguf_llama_cpp_runtime_replay_transcript_gate";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:gemma_qat_runtime_replay_probe:";
const COMMAND_TEMPLATE_PREFIX: &str = "command_template:unarmed:gemma_qat_runtime_replay_probe:";
const MODEL_PATH_PREFIX: &str = "model_path:pending_owner_manifest:gemma_qat_runtime_replay_probe:";
const MEMORY_SAMPLE_PREFIX: &str = "memory_sample:fresh_required:gemma_qat_runtime_replay_probe:";
const PROMPT_DIGEST_PREFIX: &str = "prompt_digest:redacted:gemma_qat_runtime_replay_probe:";
const OUTPUT_DIGEST_PREFIX: &str = "output_digest:redacted:gemma_qat_runtime_replay_probe:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:required:gemma_qat_runtime_replay_probe:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:required:gemma_qat_runtime_replay_probe:";
const ROLLBACK_PREFIX: &str = "rollback:required:gemma_qat_runtime_replay_probe:";
const CANCELLATION_PREFIX: &str = "cancellation:required:gemma_qat_runtime_replay_probe:";
const ABSTENTION_PREFIX: &str = "abstention:required:gemma_qat_runtime_replay_probe:";
const NO_PROMOTION_PREFIX: &str = "non_promotion:gemma_qat_runtime_replay_probe:";
const MAX_LEDGER_METADATA_BYTES: u64 = 256 * 1024;
const MAX_PROBE_METADATA_BYTES: u64 = 96 * 1024;

const REQUIRED_COMMAND_ARGS: &[&str] = &[
    "--offline",
    "--model",
    "<OWNER_APPROVED_MODEL_PATH>",
    "--prompt",
    "<SYNTHETIC_NON_USER_PROMPT>",
    "--predict",
    "1",
    "--ctx-size",
    "512",
    "--batch-size",
    "32",
    "--ubatch-size",
    "32",
    "--temp",
    "0",
    "--seed",
    "0",
    "--no-conversation",
    "--single-turn",
    "--simple-io",
    "--no-display-prompt",
    "--log-disable",
];

const FORBIDDEN_COMMAND_ARGS: &[&str] = &[
    "--hf-repo",
    "--hf-file",
    "--model-url",
    "--hf-token",
    "--server",
    "--conversation",
    "--mmap",
    "--mlock",
];

// UAS: uas:gemma-qat-runtime-replay-probe:state
// Plane: Controller + Verification.
// Residency: proof envelope only; execution belongs to a later witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatRuntimeReplayProbeState {
    PendingOwnerApprovalProbeEnvelope,
}

// UAS: uas:gemma-qat-runtime-replay-probe:phase
// Plane: Verification.
// Residency: phases required before and during a later one-token replay.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatRuntimeReplayProbePhase {
    OwnerApprovalTokenBound,
    OwnerModelPathManifestBound,
    CommandTemplateBound,
    OfflineOnlyBound,
    SyntheticPromptDigestBound,
    OneTokenBudgetBound,
    ContextAndBatchCapsBound,
    FreshMemoryBeforeSampleRequired,
    RuntimeStartSampleRequired,
    RedactedOutputDigestRequired,
    CancellationDeadlineBound,
    RollbackBound,
    RunEventLogBound,
    AnswerPacketBound,
    AbstentionBound,
    NonPromotionBound,
}

impl GemmaQatRuntimeReplayProbePhase {
    fn all_required() -> Vec<Self> {
        vec![
            Self::OwnerApprovalTokenBound,
            Self::OwnerModelPathManifestBound,
            Self::CommandTemplateBound,
            Self::OfflineOnlyBound,
            Self::SyntheticPromptDigestBound,
            Self::OneTokenBudgetBound,
            Self::ContextAndBatchCapsBound,
            Self::FreshMemoryBeforeSampleRequired,
            Self::RuntimeStartSampleRequired,
            Self::RedactedOutputDigestRequired,
            Self::CancellationDeadlineBound,
            Self::RollbackBound,
            Self::RunEventLogBound,
            Self::AnswerPacketBound,
            Self::AbstentionBound,
            Self::NonPromotionBound,
        ]
    }
}

// UAS: uas:gemma-qat-runtime-replay-probe:byte-ledger
// Plane: Verification.
// Residency: metadata-only command/proof envelope; live counters remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRuntimeReplayProbeByteLedger {
    pub command_template_metadata_bytes: u64,
    pub proof_phase_metadata_bytes: u64,
    pub retained_token_budget: u64,
    pub max_context_tokens: u64,
    pub max_batch_tokens: u64,
    pub timeout_ms: u64,
    pub cancellation_deadline_ms: u64,
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
    pub first_token_observed_count: u64,
}

impl GemmaQatRuntimeReplayProbeByteLedger {
    pub fn metadata_only(
        command_template_metadata_bytes: u64,
        proof_phase_metadata_bytes: u64,
        retained_token_budget: u64,
        max_context_tokens: u64,
        max_batch_tokens: u64,
        timeout_ms: u64,
        cancellation_deadline_ms: u64,
    ) -> Self {
        Self {
            command_template_metadata_bytes,
            proof_phase_metadata_bytes,
            retained_token_budget,
            max_context_tokens,
            max_batch_tokens,
            timeout_ms,
            cancellation_deadline_ms,
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
            first_token_observed_count: 0,
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
            || self.first_token_observed_count != 0
    }
}

// UAS: uas:gemma-qat-runtime-replay-probe:proof-refs
// Plane: Verification.
// Residency: proof handles only; no model path or command is opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRuntimeReplayProbeProofRefs {
    pub upstream_transcript_ref: String,
    pub selected_transcript_card_ref: String,
    pub owner_approval_ref: String,
    pub command_template_ref: String,
    pub model_path_ref: String,
    pub memory_sample_ref: String,
    pub prompt_digest_ref: String,
    pub output_digest_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub no_promotion_ref: String,
}

// UAS: uas:gemma-qat-runtime-replay-probe:card
// Plane: Controller + Verification.
// Residency: selected E2B GGUF proof envelope, not execution evidence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayProbeCard {
    pub probe_id: String,
    pub upstream_transcript_ref: String,
    pub selected_transcript_card_id: String,
    pub model_id: String,
    pub required_filename: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub command_template_args: Vec<String>,
    pub forbidden_command_args: Vec<String>,
    pub required_phases: Vec<GemmaQatRuntimeReplayProbePhase>,
    pub state: GemmaQatRuntimeReplayProbeState,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub model_path_pending: bool,
    pub model_path_opened: bool,
    pub command_template_visible: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
    pub synthetic_prompt_only: bool,
    pub prompt_digest_bound: bool,
    pub output_digest_bound: bool,
    pub raw_prompt_denied: bool,
    pub raw_output_denied: bool,
    pub stdout_stderr_denied: bool,
    pub memory_sample_required_before_runtime: bool,
    pub runtime_start_memory_sample_required: bool,
    pub cancellation_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
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
    pub twelve_b_or_larger_probe_allowed: bool,
    pub byte_ledger: GemmaQatRuntimeReplayProbeByteLedger,
    pub proof_refs: GemmaQatRuntimeReplayProbeProofRefs,
    pub next_cursor: String,
}

// UAS: uas:gemma-qat-runtime-replay-probe:ledger
// Plane: State + Controller + Verification.
// Residency: one selected metadata-only probe envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayProbeLedger {
    pub ledger_address: UasAddress,
    pub upstream_transcript_ref: String,
    pub probes: Vec<GemmaQatOwnerApprovedRuntimeReplayProbeCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub owner_approval_pending: bool,
    pub runtime_replay_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-runtime-replay-probe:metrics
// Plane: Verification.
// Residency: derived metadata-only counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayProbeMetrics {
    pub probe_count: u64,
    pub e2b_probe_count: u64,
    pub gguf_lane_count: u64,
    pub required_phase_count_total: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub command_template_visible_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub runtime_replay_performed_count: u64,
    pub prompt_digest_bound_count: u64,
    pub output_digest_bound_count: u64,
    pub memory_sample_required_count: u64,
    pub opened_model_file_bytes_total: u64,
    pub opened_runtime_file_bytes_total: u64,
    pub captured_raw_prompt_bytes_total: u64,
    pub captured_raw_output_bytes_total: u64,
    pub captured_stdout_bytes_total: u64,
    pub captured_stderr_bytes_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub first_token_observed_count_total: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub larger_model_probe_allowed_count: u64,
}

impl GemmaQatOwnerApprovedRuntimeReplayProbeLedger {
    pub fn new(
        upstream_transcript_ref: impl Into<String>,
        mut probes: Vec<GemmaQatOwnerApprovedRuntimeReplayProbeCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatOwnerApprovedRuntimeReplayProbeError> {
        let upstream_transcript_ref = upstream_transcript_ref.into();
        probes.sort_by(|a, b| a.probe_id.cmp(&b.probe_id));
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_CURSOR.to_string()),
                probe_preimage(&upstream_transcript_ref, &probes, metadata_bytes).as_bytes(),
                created_at_ms,
            ),
            upstream_transcript_ref,
            probes,
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

    pub fn validate(&self) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayProbeError> {
        if !self
            .upstream_transcript_ref
            .starts_with(UPSTREAM_TRANSCRIPT_PREFIX)
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadUpstreamRef);
        }
        if self.probes.is_empty() {
            return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::EmptyProbeSet);
        }
        if self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::MetadataBudgetExceeded);
        }
        if !self.metadata_only
            || !self.owner_approval_pending
            || !self.runtime_replay_deferred
            || !self.product_promotion_blocked
            || self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::UnsafeLedgerState);
        }

        let mut probe_ids = HashSet::new();
        for probe in &self.probes {
            if !probe_ids.insert(probe.probe_id.as_str()) {
                return Err(
                    GemmaQatOwnerApprovedRuntimeReplayProbeError::DuplicateProbeId(
                        probe.probe_id.clone(),
                    ),
                );
            }
            validate_probe(probe, &self.upstream_transcript_ref)?;
        }

        let metrics = self.metrics();
        if metrics.probe_count != 1 || metrics.e2b_probe_count != 1 || metrics.gguf_lane_count != 1
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::ExpectedProbeMismatch);
        }

        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatOwnerApprovedRuntimeReplayProbeMetrics {
        let mut metrics = GemmaQatOwnerApprovedRuntimeReplayProbeMetrics {
            probe_count: self.probes.len() as u64,
            e2b_probe_count: 0,
            gguf_lane_count: 0,
            required_phase_count_total: 0,
            owner_approval_required_count: 0,
            owner_approval_granted_count: 0,
            command_template_visible_count: 0,
            command_armed_count: 0,
            command_executed_count: 0,
            runtime_replay_performed_count: 0,
            prompt_digest_bound_count: 0,
            output_digest_bound_count: 0,
            memory_sample_required_count: 0,
            opened_model_file_bytes_total: 0,
            opened_runtime_file_bytes_total: 0,
            captured_raw_prompt_bytes_total: 0,
            captured_raw_output_bytes_total: 0,
            captured_stdout_bytes_total: 0,
            captured_stderr_bytes_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            first_token_observed_count_total: 0,
            hidden_authority_count: 0,
            promotion_claim_count: 0,
            larger_model_probe_allowed_count: 0,
        };

        for probe in &self.probes {
            if probe.model_id == GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID {
                metrics.e2b_probe_count += 1;
            }
            if probe.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp {
                metrics.gguf_lane_count += 1;
            }
            metrics.required_phase_count_total += probe.required_phases.len() as u64;
            metrics.owner_approval_required_count += probe.owner_approval_required as u64;
            metrics.owner_approval_granted_count += probe.owner_approval_granted as u64;
            metrics.command_template_visible_count += probe.command_template_visible as u64;
            metrics.command_armed_count += probe.command_armed as u64;
            metrics.command_executed_count += probe.command_executed as u64;
            metrics.runtime_replay_performed_count += probe.runtime_replay_performed as u64;
            metrics.prompt_digest_bound_count += probe.prompt_digest_bound as u64;
            metrics.output_digest_bound_count += probe.output_digest_bound as u64;
            metrics.memory_sample_required_count +=
                probe.memory_sample_required_before_runtime as u64;
            metrics.opened_model_file_bytes_total += probe.byte_ledger.opened_model_file_bytes;
            metrics.opened_runtime_file_bytes_total += probe.byte_ledger.opened_runtime_file_bytes;
            metrics.captured_raw_prompt_bytes_total += probe.byte_ledger.captured_raw_prompt_bytes;
            metrics.captured_raw_output_bytes_total += probe.byte_ledger.captured_raw_output_bytes;
            metrics.captured_stdout_bytes_total += probe.byte_ledger.captured_stdout_bytes;
            metrics.captured_stderr_bytes_total += probe.byte_ledger.captured_stderr_bytes;
            metrics.model_bytes_loaded_total += probe.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += probe.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += probe.byte_ledger.provider_calls_made;
            metrics.first_token_observed_count_total +=
                probe.byte_ledger.first_token_observed_count;
            metrics.hidden_authority_count += (probe.hidden_route_authority
                || probe.hidden_eidos_authority
                || probe.hidden_lattice_authority
                || probe.hidden_patternboost_authority
                || probe.hidden_cloud_fallback)
                as u64;
            metrics.promotion_claim_count += (probe.mas_promoted
                || probe.product_route_green
                || probe.live_gemma_default_claim
                || probe.live_dense_70b_claim
                || probe.ssd_as_ram_claim
                || probe.quality_claimed
                || probe.benchmark_claimed_as_fit
                || probe.l2_capability_effect
                || probe.l3_wrv_effect) as u64;
            metrics.larger_model_probe_allowed_count +=
                probe.twelve_b_or_larger_probe_allowed as u64;
        }
        metrics
    }
}

pub fn canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(
    upstream_transcript_ref: &str,
) -> Vec<GemmaQatOwnerApprovedRuntimeReplayProbeCard> {
    let transcript_cards =
        canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(upstream_transcript_ref);
    let selected = transcript_cards
        .iter()
        .find(|card| card.selected_first_probe_candidate)
        .expect("canonical transcript gate has one selected first probe candidate");

    vec![GemmaQatOwnerApprovedRuntimeReplayProbeCard {
        probe_id: "gemma4_e2b_gguf_llama_cpp_owner_approved_runtime_replay_probe".to_string(),
        upstream_transcript_ref: upstream_transcript_ref.to_string(),
        selected_transcript_card_id: selected.card_id.clone(),
        model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
        required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
        runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
        command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
        command_template_args: REQUIRED_COMMAND_ARGS
            .iter()
            .map(|arg| (*arg).to_string())
            .collect(),
        forbidden_command_args: FORBIDDEN_COMMAND_ARGS
            .iter()
            .map(|arg| (*arg).to_string())
            .collect(),
        required_phases: GemmaQatRuntimeReplayProbePhase::all_required(),
        state: GemmaQatRuntimeReplayProbeState::PendingOwnerApprovalProbeEnvelope,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::Gated,
        owner_approval_required: true,
        owner_approval_granted: false,
        model_path_pending: true,
        model_path_opened: false,
        command_template_visible: true,
        command_armed: false,
        command_executed: false,
        runtime_replay_performed: false,
        synthetic_prompt_only: true,
        prompt_digest_bound: true,
        output_digest_bound: true,
        raw_prompt_denied: true,
        raw_output_denied: true,
        stdout_stderr_denied: true,
        memory_sample_required_before_runtime: true,
        runtime_start_memory_sample_required: true,
        cancellation_bound: true,
        rollback_bound: true,
        run_event_log_bound: true,
        answer_packet_bound: true,
        abstention_bound: true,
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
        twelve_b_or_larger_probe_allowed: false,
        byte_ledger: GemmaQatRuntimeReplayProbeByteLedger::metadata_only(
            20_480, 16_384, 1, 512, 32, 30_000, 5_000,
        ),
        proof_refs: proof_refs(upstream_transcript_ref, selected.card_id.as_str()),
        next_cursor: GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR.to_string(),
    }]
}

fn validate_probe(
    probe: &GemmaQatOwnerApprovedRuntimeReplayProbeCard,
    upstream_transcript_ref: &str,
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayProbeError> {
    if probe.upstream_transcript_ref != upstream_transcript_ref
        || !probe
            .upstream_transcript_ref
            .starts_with(UPSTREAM_TRANSCRIPT_PREFIX)
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadUpstreamRef);
    }
    if probe.probe_id.is_empty()
        || probe.model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
        || probe.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
        || probe.selected_transcript_card_id != SELECTED_TRANSCRIPT_CARD_ID
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadProbe);
    }
    if probe.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadRuntimeLane);
    }
    if probe.command_path != GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
        || !required_args_present(&probe.command_template_args)
        || forbidden_args_absent(&probe.command_template_args, &probe.forbidden_command_args)
            .is_err()
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadCommandTemplate);
    }
    if probe.required_phases.len() != GemmaQatRuntimeReplayProbePhase::all_required().len()
        || !all_required_phases_present(&probe.required_phases)
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::MissingProofPhase);
    }
    if probe.state != GemmaQatRuntimeReplayProbeState::PendingOwnerApprovalProbeEnvelope
        || probe.product_build != ProductBuild::Pro
        || probe.pro_status != ProStatus::Gated
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::UnsafeProbeState);
    }
    if !probe.owner_approval_required
        || probe.owner_approval_granted
        || !probe.model_path_pending
        || probe.model_path_opened
        || !probe.command_template_visible
        || probe.command_armed
        || probe.command_executed
        || probe.runtime_replay_performed
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::ExecutionBoundaryBroken);
    }
    if !probe.synthetic_prompt_only
        || !probe.prompt_digest_bound
        || !probe.output_digest_bound
        || !probe.raw_prompt_denied
        || !probe.raw_output_denied
        || !probe.stdout_stderr_denied
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::PrivacyBoundaryBroken);
    }
    if !probe.memory_sample_required_before_runtime
        || !probe.runtime_start_memory_sample_required
        || !probe.cancellation_bound
        || !probe.rollback_bound
        || !probe.run_event_log_bound
        || !probe.answer_packet_bound
        || !probe.abstention_bound
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::ProofBoundaryBroken);
    }
    if !probe.l1_architecture_effect
        || probe.l2_capability_effect
        || probe.l3_wrv_effect
        || probe.runtime_router_mutation_allowed
        || probe.system_g_mutation_allowed
        || probe.hidden_route_authority
        || probe.hidden_eidos_authority
        || probe.hidden_lattice_authority
        || probe.hidden_patternboost_authority
        || probe.hidden_cloud_fallback
        || probe.mas_promoted
        || probe.product_route_green
        || probe.live_gemma_default_claim
        || probe.live_dense_70b_claim
        || probe.ssd_as_ram_claim
        || probe.quality_claimed
        || probe.benchmark_claimed_as_fit
        || probe.twelve_b_or_larger_probe_allowed
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::PromotionClaim);
    }
    if probe.byte_ledger.live_bytes_or_actions_observed()
        || probe.byte_ledger.command_template_metadata_bytes > MAX_PROBE_METADATA_BYTES
        || probe.byte_ledger.proof_phase_metadata_bytes > MAX_PROBE_METADATA_BYTES
        || probe.byte_ledger.retained_token_budget != 1
        || probe.byte_ledger.max_context_tokens > 512
        || probe.byte_ledger.max_batch_tokens > 32
        || probe.byte_ledger.timeout_ms > 30_000
        || probe.byte_ledger.cancellation_deadline_ms > 5_000
    {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BytesOrActionsObserved);
    }
    validate_proof_refs(&probe.proof_refs)?;
    if probe.next_cursor != GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR {
        return Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::WrongNextCursor);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatRuntimeReplayProbeProofRefs,
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayProbeError> {
    let checks = [
        refs.upstream_transcript_ref
            .starts_with(UPSTREAM_TRANSCRIPT_PREFIX),
        refs.selected_transcript_card_ref
            .contains(SELECTED_TRANSCRIPT_CARD_ID),
        refs.owner_approval_ref.starts_with(OWNER_APPROVAL_PREFIX),
        refs.command_template_ref
            .starts_with(COMMAND_TEMPLATE_PREFIX),
        refs.model_path_ref.starts_with(MODEL_PATH_PREFIX),
        refs.memory_sample_ref.starts_with(MEMORY_SAMPLE_PREFIX),
        refs.prompt_digest_ref.starts_with(PROMPT_DIGEST_PREFIX),
        refs.output_digest_ref.starts_with(OUTPUT_DIGEST_PREFIX),
        refs.cancellation_ref.starts_with(CANCELLATION_PREFIX),
        refs.rollback_ref.starts_with(ROLLBACK_PREFIX),
        refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX),
        refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX),
        refs.abstention_ref.starts_with(ABSTENTION_PREFIX),
        refs.no_promotion_ref.starts_with(NO_PROMOTION_PREFIX),
    ];
    if checks.iter().all(|passed| *passed) {
        Ok(())
    } else {
        Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadProofRef)
    }
}

fn proof_refs(
    upstream_transcript_ref: &str,
    selected_card_id: &str,
) -> GemmaQatRuntimeReplayProbeProofRefs {
    GemmaQatRuntimeReplayProbeProofRefs {
        upstream_transcript_ref: upstream_transcript_ref.to_string(),
        selected_transcript_card_ref: format!(
            "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_transcript_gate/result.json#{selected_card_id}"
        ),
        owner_approval_ref: format!("{OWNER_APPROVAL_PREFIX}{selected_card_id}"),
        command_template_ref: format!("{COMMAND_TEMPLATE_PREFIX}{selected_card_id}"),
        model_path_ref: format!("{MODEL_PATH_PREFIX}{selected_card_id}"),
        memory_sample_ref: format!("{MEMORY_SAMPLE_PREFIX}{selected_card_id}"),
        prompt_digest_ref: format!("{PROMPT_DIGEST_PREFIX}{selected_card_id}"),
        output_digest_ref: format!("{OUTPUT_DIGEST_PREFIX}{selected_card_id}"),
        cancellation_ref: format!("{CANCELLATION_PREFIX}{selected_card_id}"),
        rollback_ref: format!("{ROLLBACK_PREFIX}{selected_card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{selected_card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{selected_card_id}"),
        abstention_ref: format!("{ABSTENTION_PREFIX}{selected_card_id}"),
        no_promotion_ref: format!("{NO_PROMOTION_PREFIX}{selected_card_id}"),
    }
}

fn required_args_present(args: &[String]) -> bool {
    REQUIRED_COMMAND_ARGS
        .iter()
        .all(|required| args.iter().any(|arg| arg == required))
}

fn forbidden_args_absent(
    args: &[String],
    forbidden_args: &[String],
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayProbeError> {
    if FORBIDDEN_COMMAND_ARGS
        .iter()
        .all(|forbidden| forbidden_args.iter().any(|arg| arg == forbidden))
        && FORBIDDEN_COMMAND_ARGS
            .iter()
            .all(|forbidden| args.iter().all(|arg| arg != forbidden))
    {
        Ok(())
    } else {
        Err(GemmaQatOwnerApprovedRuntimeReplayProbeError::BadCommandTemplate)
    }
}

fn all_required_phases_present(phases: &[GemmaQatRuntimeReplayProbePhase]) -> bool {
    let set = phases.iter().copied().collect::<HashSet<_>>();
    GemmaQatRuntimeReplayProbePhase::all_required()
        .iter()
        .all(|phase| set.contains(phase))
}

fn probe_preimage(
    upstream_ref: &str,
    probes: &[GemmaQatOwnerApprovedRuntimeReplayProbeCard],
    metadata_bytes: u64,
) -> String {
    let ids = probes
        .iter()
        .map(|probe| {
            format!(
                "{}:{}:{:?}:{}:{}:{}:{}:{}:{}",
                probe.probe_id,
                probe.model_id,
                probe.runtime_lane,
                probe.selected_transcript_card_id,
                probe.owner_approval_required,
                probe.owner_approval_granted,
                probe.command_armed,
                probe.command_executed,
                probe.byte_ledger.model_bytes_loaded
            )
        })
        .collect::<Vec<_>>()
        .join("|");
    format!(
        "gemma-runtime-replay-probe:v1:{upstream_ref}:{metadata_bytes}:{ids}:{}",
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR
    )
}

// UAS: uas:gemma-qat-runtime-replay-probe:error
// Plane: Verification.
// Residency: validation failures only; no runtime bytes are represented.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatOwnerApprovedRuntimeReplayProbeError {
    BadUpstreamRef,
    EmptyProbeSet,
    DuplicateProbeId(String),
    ExpectedProbeMismatch,
    BadProbe,
    BadRuntimeLane,
    BadCommandTemplate,
    MissingProofPhase,
    UnsafeLedgerState,
    UnsafeProbeState,
    ExecutionBoundaryBroken,
    PrivacyBoundaryBroken,
    ProofBoundaryBroken,
    PromotionClaim,
    BytesOrActionsObserved,
    BadProofRef,
    MetadataBudgetExceeded,
    WrongNextCursor,
}

impl fmt::Display for GemmaQatOwnerApprovedRuntimeReplayProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for GemmaQatOwnerApprovedRuntimeReplayProbeError {}

#[cfg(test)]
mod tests {
    use super::{
        canonical_gemma_qat_owner_approved_runtime_replay_probe_cards,
        GemmaQatOwnerApprovedRuntimeReplayProbeLedger,
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR,
    };

    const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_transcript_gate/result.json#F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate";

    fn ledger() -> GemmaQatOwnerApprovedRuntimeReplayProbeLedger {
        GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
            UPSTREAM_REF,
            canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF),
            96_000,
            1_779_301_600_000,
        )
        .expect("canonical Gemma runtime replay probe should validate")
    }

    #[test]
    fn canonical_probe_validates_without_runtime_or_model_bytes() {
        let ledger = ledger();
        let metrics = ledger.metrics();
        assert_eq!(metrics.probe_count, 1);
        assert_eq!(metrics.e2b_probe_count, 1);
        assert_eq!(metrics.gguf_lane_count, 1);
        assert_eq!(metrics.owner_approval_granted_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.first_token_observed_count_total, 0);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(
            ledger.probes[0].next_cursor,
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_owner_approval_or_execution_laundering() {
        let mut probes =
            canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF);
        probes[0].owner_approval_granted = true;
        assert!(GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
            UPSTREAM_REF,
            probes,
            96_000,
            1_779_301_600_000,
        )
        .is_err());

        let mut probes =
            canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF);
        probes[0].command_executed = true;
        probes[0].byte_ledger.command_execution_count = 1;
        assert!(GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
            UPSTREAM_REF,
            probes,
            96_000,
            1_779_301_600_000,
        )
        .is_err());
    }

    #[test]
    fn rejects_raw_output_bytes_runtime_bytes_or_default_promotion() {
        let mut probes =
            canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF);
        probes[0].raw_output_denied = false;
        probes[0].byte_ledger.captured_raw_output_bytes = 1;
        assert!(GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
            UPSTREAM_REF,
            probes,
            96_000,
            1_779_301_600_000,
        )
        .is_err());

        let mut probes =
            canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF);
        probes[0].byte_ledger.model_bytes_loaded = 1;
        assert!(GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
            UPSTREAM_REF,
            probes,
            96_000,
            1_779_301_600_000,
        )
        .is_err());

        let mut probes =
            canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF);
        probes[0].live_gemma_default_claim = true;
        assert!(GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
            UPSTREAM_REF,
            probes,
            96_000,
            1_779_301_600_000,
        )
        .is_err());
    }
}
