//! Small compressed-model runtime-probe proof envelope.
//!
//! This primitive turns model-path readiness into a no-runtime proof envelope
//! for the future owner-approved one-token E2B probe. It defines the exact
//! command template and proof phases that must exist before execution can be
//! attempted, while keeping owner approval, model path, download, command
//! execution, and runtime bytes fail-closed.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, SmallCompressedHarnessPromotionTier, UasAddress, UasKind,
};

pub const SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_CURSOR: &str =
    "small_compressed_model_runtime_probe_proof_envelope";
pub const SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_NEXT_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe";

const UPSTREAM_MODEL_PATH_PREFIX: &str =
    "artifact:small_compressed_model_model_path_readiness_card:";
const COMMAND_TEMPLATE_PREFIX: &str = "command_template:small_compressed_runtime_probe:";
const SOURCE_MODEL_PREFIX: &str = "source:model:gemma4-e2b-qat-gguf:";
const MODEL_PATH_PREFIX: &str = "model_path:owner_approval_required:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:";
const PROMPT_HASH_PREFIX: &str = "prompt_hash:synthetic_non_user:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:small_compressed_runtime_probe:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:small_compressed_runtime_probe:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:small_compressed_runtime_probe:";
const ROLLBACK_PREFIX: &str = "rollback:small_compressed_runtime_probe:";
const CANCELLATION_PREFIX: &str = "cancel:small_compressed_runtime_probe:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:small_compressed_runtime_probe:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:small_compressed_runtime_probe:";
const SCALING_LADDER_PREFIX: &str = "scaling_ladder:gemma_qat_local:";
const MAX_SET_METADATA_BYTES: u64 = 128 * 1024;
const MAX_ENVELOPE_METADATA_BYTES: u64 = 64 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 220;
const SELECTED_E2B_CANDIDATE: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const E2B_MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const REQUIRED_FILENAME: &str = "gemma-4-E2B_q4_0-it.gguf";
const LLAMA_CLI_PATH: &str = "/opt/homebrew/bin/llama-cli";
const MODEL_PATH_PLACEHOLDER: &str = "<OWNER_APPROVED_MODEL_PATH>";
const PROMPT_PLACEHOLDER: &str = "<SYNTHETIC_NON_USER_PROMPT>";

const REQUIRED_FLAGS: &[&str] = &[
    "--offline",
    "--model",
    MODEL_PATH_PLACEHOLDER,
    "--prompt",
    PROMPT_PLACEHOLDER,
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
    "--no-mmap",
    "--log-disable",
];

const FORBIDDEN_FLAGS: &[&str] = &[
    "--hf-repo",
    "-hf",
    "-hfr",
    "--hf-file",
    "-hff",
    "--model-url",
    "-mu",
    "--docker-repo",
    "-dr",
    "--hf-token",
    "-hft",
    "--server",
    "--conversation",
    "--mmap",
    "--mlock",
];

// UAS: uas:small-compressed-runtime-probe-envelope:status
// Plane: Controller + Verification
// Residency: no-runtime envelope status; execution remains a later witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedRuntimeProbeEnvelopeStatus {
    PendingOwnerApprovalAndPath,
    ApprovedOnlyBySeparateRuntimeWitness,
    Blocked,
}

// UAS: uas:small-compressed-runtime-probe-envelope:phase
// Plane: Verification
// Residency: required proof phases before and during a future one-token run.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedRuntimeProbePhase {
    OwnerApprovalTokenBound,
    ModelPathBound,
    CommandCardBound,
    OfflineModeBound,
    SyntheticPromptHashBound,
    OneTokenBudgetBound,
    ContextAndBatchCapsBound,
    MemoryBeforeSampleRequired,
    RuntimeStartSampleRequired,
    FirstTokenRedactionRequired,
    CancellationDeadlineBound,
    RollbackBound,
    RunEventLogBound,
    AnswerPacketBound,
    NonPromotionBound,
    LargerModelEscalationBlocked,
}

// UAS: uas:small-compressed-runtime-probe-envelope:byte-ledger
// Plane: Verification
// Residency: command/help metadata only; all runtime/model byte counters zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedRuntimeProbeByteLedger {
    pub command_template_metadata_bytes: u64,
    pub cli_help_metadata_bytes_read: u64,
    pub downloaded_model_bytes: u64,
    pub opened_model_bytes: u64,
    pub hashed_model_bytes: u64,
    pub resident_model_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub retained_token_budget: u64,
    pub max_context_tokens: u64,
    pub timeout_ms: u64,
    pub cancellation_deadline_ms: u64,
}

impl SmallCompressedRuntimeProbeByteLedger {
    pub fn metadata_only(
        command_template_metadata_bytes: u64,
        cli_help_metadata_bytes_read: u64,
        retained_token_budget: u64,
        max_context_tokens: u64,
        timeout_ms: u64,
        cancellation_deadline_ms: u64,
    ) -> Self {
        Self {
            command_template_metadata_bytes,
            cli_help_metadata_bytes_read,
            downloaded_model_bytes: 0,
            opened_model_bytes: 0,
            hashed_model_bytes: 0,
            resident_model_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            retained_token_budget,
            max_context_tokens,
            timeout_ms,
            cancellation_deadline_ms,
        }
    }
}

// UAS: uas:small-compressed-runtime-probe-envelope:refs
// Plane: Verification
// Residency: proof refs required before the future runtime witness can run.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedRuntimeProbeRefs {
    pub upstream_model_path_ref: String,
    pub command_template_ref: String,
    pub source_model_ref: String,
    pub model_path_ref: String,
    pub owner_approval_ref: String,
    pub prompt_hash_ref: String,
    pub memory_ledger_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub compatibility_fence_ref: String,
    pub route_caveat_ref: String,
    pub scaling_ladder_ref: String,
}

// UAS: uas:small-compressed-runtime-probe-envelope:card
// Plane: Controller + Verification
// Residency: no-runtime proof envelope, not the approved runtime itself.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedRuntimeProbeProofEnvelope {
    pub envelope_id: String,
    pub selected_candidate_id: String,
    pub model_id: String,
    pub required_filename: String,
    pub command_path: String,
    pub command_template_args: Vec<String>,
    pub forbidden_flags: Vec<String>,
    pub required_phases: Vec<SmallCompressedRuntimeProbePhase>,
    pub status: SmallCompressedRuntimeProbeEnvelopeStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: SmallCompressedHarnessPromotionTier,
    pub bytes: SmallCompressedRuntimeProbeByteLedger,
    pub refs: SmallCompressedRuntimeProbeRefs,
    pub user_visible_summary: String,
    pub command_template_visible: bool,
    pub cli_help_surface_visible: bool,
    pub model_path_status_visible: bool,
    pub memory_sampling_plan_visible: bool,
    pub answer_packet_schema_visible: bool,
    pub scaling_ladder_visible: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub download_executed: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub inference_executed: bool,
    pub first_token_claimed: bool,
    pub retained_token_digest_recorded: bool,
    pub quality_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub cancellation_required: bool,
    pub memory_ledger_required: bool,
    pub route_policy_mutated: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub provider_fallback_allowed: bool,
    pub server_sidecar_default_allowed: bool,
    pub hf_or_url_download_allowed: bool,
    pub multi_token_or_unbounded_generation_allowed: bool,
    pub e4b_requires_new_envelope: bool,
    pub twelve_b_requires_memory_repreflight: bool,
    pub thirty_one_b_vault_only: bool,
    pub seventy_b_cold_assembly_only: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:small-compressed-runtime-probe-envelope:set
// Plane: Controller + Verification
// Residency: proof envelope set bound to model-path readiness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedRuntimeProbeProofEnvelopeSet {
    pub set_address: UasAddress,
    pub upstream_model_path_set_address: UasAddress,
    pub upstream_model_path_witness_ref: String,
    pub selected_envelope_id: String,
    pub envelopes: Vec<SmallCompressedRuntimeProbeProofEnvelope>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:small-compressed-runtime-probe-envelope:metrics
// Plane: Verification
// Residency: derived envelope counts and zero-byte counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedRuntimeProbeEnvelopeMetrics {
    pub envelope_count: u64,
    pub required_phase_count: u64,
    pub required_flag_count: u64,
    pub forbidden_flag_count: u64,
    pub downloaded_model_bytes: u64,
    pub opened_model_bytes: u64,
    pub hashed_model_bytes: u64,
    pub resident_model_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub retained_token_budget: u64,
    pub max_context_tokens: u64,
}

impl SmallCompressedRuntimeProbeProofEnvelopeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_model_path_readiness(
        upstream_model_path_set_address: UasAddress,
        upstream_model_path_witness_ref: impl Into<String>,
        selected_envelope_id: impl Into<String>,
        mut envelopes: Vec<SmallCompressedRuntimeProbeProofEnvelope>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, SmallCompressedRuntimeProbeEnvelopeError> {
        envelopes.sort_by(|a, b| a.envelope_id.cmp(&b.envelope_id));
        let witness_ref = upstream_model_path_witness_ref.into();
        let selected_envelope_id = selected_envelope_id.into();
        validate_set_inputs(
            &upstream_model_path_set_address,
            &witness_ref,
            &selected_envelope_id,
            &envelopes,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = envelope_set_preimage(
            &upstream_model_path_set_address,
            &witness_ref,
            &selected_envelope_id,
            &envelopes,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_model_path_set_address,
            upstream_model_path_witness_ref: witness_ref,
            selected_envelope_id,
            envelopes,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> SmallCompressedRuntimeProbeEnvelopeMetrics {
        let mut phases = HashSet::new();
        let mut flags = HashSet::new();
        let mut forbidden = HashSet::new();
        let mut metrics = SmallCompressedRuntimeProbeEnvelopeMetrics {
            envelope_count: self.envelopes.len() as u64,
            required_phase_count: 0,
            required_flag_count: 0,
            forbidden_flag_count: 0,
            downloaded_model_bytes: 0,
            opened_model_bytes: 0,
            hashed_model_bytes: 0,
            resident_model_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            retained_token_budget: 0,
            max_context_tokens: 0,
        };
        for envelope in &self.envelopes {
            for phase in &envelope.required_phases {
                phases.insert(*phase);
            }
            for flag in &envelope.command_template_args {
                flags.insert(flag.clone());
            }
            for flag in &envelope.forbidden_flags {
                forbidden.insert(flag.clone());
            }
            metrics.downloaded_model_bytes = metrics
                .downloaded_model_bytes
                .saturating_add(envelope.bytes.downloaded_model_bytes);
            metrics.opened_model_bytes = metrics
                .opened_model_bytes
                .saturating_add(envelope.bytes.opened_model_bytes);
            metrics.hashed_model_bytes = metrics
                .hashed_model_bytes
                .saturating_add(envelope.bytes.hashed_model_bytes);
            metrics.resident_model_bytes = metrics
                .resident_model_bytes
                .saturating_add(envelope.bytes.resident_model_bytes);
            metrics.model_bytes_loaded = metrics
                .model_bytes_loaded
                .saturating_add(envelope.bytes.model_bytes_loaded);
            metrics.runtime_bytes_loaded = metrics
                .runtime_bytes_loaded
                .saturating_add(envelope.bytes.runtime_bytes_loaded);
            metrics.provider_calls_made = metrics
                .provider_calls_made
                .saturating_add(envelope.bytes.provider_calls_made);
            metrics.retained_token_budget = metrics
                .retained_token_budget
                .saturating_add(envelope.bytes.retained_token_budget);
            metrics.max_context_tokens = metrics
                .max_context_tokens
                .max(envelope.bytes.max_context_tokens);
        }
        metrics.required_phase_count = phases.len() as u64;
        metrics.required_flag_count = REQUIRED_FLAGS
            .iter()
            .filter(|flag| flags.contains(**flag))
            .count() as u64;
        metrics.forbidden_flag_count = forbidden.len() as u64;
        metrics
    }
}

// UAS: uas:small-compressed-runtime-probe-envelope:error
// Plane: Verification
// Residency: validation error only; no model bytes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SmallCompressedRuntimeProbeEnvelopeError {
    InvalidSet(String),
    InvalidEnvelope(String),
}

impl fmt::Display for SmallCompressedRuntimeProbeEnvelopeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidSet(message) => write!(f, "invalid runtime-probe envelope set: {message}"),
            Self::InvalidEnvelope(message) => {
                write!(f, "invalid runtime-probe envelope: {message}")
            }
        }
    }
}

impl std::error::Error for SmallCompressedRuntimeProbeEnvelopeError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_model_path_set_address: &UasAddress,
    upstream_model_path_witness_ref: &str,
    selected_envelope_id: &str,
    envelopes: &[SmallCompressedRuntimeProbeProofEnvelope],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), SmallCompressedRuntimeProbeEnvelopeError> {
    if upstream_model_path_set_address.to_string().is_empty() {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "upstream model-path address is empty".to_string(),
        ));
    }
    if !upstream_model_path_witness_ref.starts_with(UPSTREAM_MODEL_PATH_PREFIX) {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "upstream model-path witness ref must bind path-readiness".to_string(),
        ));
    }
    if selected_envelope_id.is_empty() {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "selected envelope id is empty".to_string(),
        ));
    }
    if envelopes.len() != 1 {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "expected exactly one selected E2B runtime-probe envelope".to_string(),
        ));
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "runtime-probe envelope set must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "set metadata budget is invalid".to_string(),
        ));
    }
    if !l1_l2_l3_separated || !runtime_deferred || !product_promotion_blocked {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "L1/L2/L3 separation, runtime deferral, and product block are required".to_string(),
        ));
    }
    let envelope = &envelopes[0];
    validate_envelope(envelope)?;
    if envelope.envelope_id != selected_envelope_id {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidSet(
            "selected envelope is missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_envelope(
    envelope: &SmallCompressedRuntimeProbeProofEnvelope,
) -> Result<(), SmallCompressedRuntimeProbeEnvelopeError> {
    if envelope.envelope_id.trim().is_empty() {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "envelope id is empty".to_string(),
        ));
    }
    if envelope.selected_candidate_id != SELECTED_E2B_CANDIDATE
        || envelope.model_id != E2B_MODEL_ID
        || envelope.required_filename != REQUIRED_FILENAME
        || envelope.command_path != LLAMA_CLI_PATH
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "only the selected E2B QAT GGUF llama-cli envelope is allowed".to_string(),
        ));
    }
    if !required_flags_present(&envelope.command_template_args)
        || forbidden_flags_present(&envelope.command_template_args)
        || envelope.forbidden_flags.len() < FORBIDDEN_FLAGS.len()
        || !FORBIDDEN_FLAGS
            .iter()
            .all(|flag| envelope.forbidden_flags.iter().any(|value| value == flag))
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "command template must be offline, one-token, capped, local-path only, and network-free".to_string(),
        ));
    }
    if arg_value(&envelope.command_template_args, "--predict") != Some("1")
        || arg_value(&envelope.command_template_args, "--ctx-size") != Some("512")
        || arg_value(&envelope.command_template_args, "--batch-size") != Some("32")
        || arg_value(&envelope.command_template_args, "--ubatch-size") != Some("32")
        || arg_value(&envelope.command_template_args, "--temp") != Some("0")
        || arg_value(&envelope.command_template_args, "--seed") != Some("0")
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "command value caps are invalid".to_string(),
        ));
    }
    if !all_phases_present(&envelope.required_phases) {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "all runtime-probe proof phases are required".to_string(),
        ));
    }
    if envelope.status != SmallCompressedRuntimeProbeEnvelopeStatus::PendingOwnerApprovalAndPath
        || envelope.product_build != ProductBuild::Pro
        || envelope.pro_status != ProStatus::ResearchCandidate
        || envelope.promotion_tier != SmallCompressedHarnessPromotionTier::T1L1Metadata
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "runtime-probe envelope must remain pending T1/L1 Pro ResearchCandidate".to_string(),
        ));
    }
    if envelope.bytes.command_template_metadata_bytes == 0
        || envelope.bytes.cli_help_metadata_bytes_read == 0
        || envelope.bytes.command_template_metadata_bytes > MAX_ENVELOPE_METADATA_BYTES
        || envelope.bytes.cli_help_metadata_bytes_read > MAX_ENVELOPE_METADATA_BYTES
        || envelope.bytes.downloaded_model_bytes != 0
        || envelope.bytes.opened_model_bytes != 0
        || envelope.bytes.hashed_model_bytes != 0
        || envelope.bytes.resident_model_bytes != 0
        || envelope.bytes.model_bytes_loaded != 0
        || envelope.bytes.runtime_bytes_loaded != 0
        || envelope.bytes.provider_calls_made != 0
        || envelope.bytes.retained_token_budget != 1
        || envelope.bytes.max_context_tokens != 512
        || envelope.bytes.timeout_ms == 0
        || envelope.bytes.cancellation_deadline_ms == 0
        || envelope.bytes.cancellation_deadline_ms > envelope.bytes.timeout_ms
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "runtime-probe envelope must be metadata-only with bounded one-token budgets"
                .to_string(),
        ));
    }
    if !envelope
        .refs
        .upstream_model_path_ref
        .starts_with(UPSTREAM_MODEL_PATH_PREFIX)
        || !envelope
            .refs
            .command_template_ref
            .starts_with(COMMAND_TEMPLATE_PREFIX)
        || !envelope
            .refs
            .source_model_ref
            .starts_with(SOURCE_MODEL_PREFIX)
        || !envelope.refs.model_path_ref.starts_with(MODEL_PATH_PREFIX)
        || !envelope
            .refs
            .owner_approval_ref
            .starts_with(OWNER_APPROVAL_PREFIX)
        || !envelope
            .refs
            .prompt_hash_ref
            .starts_with(PROMPT_HASH_PREFIX)
        || !envelope
            .refs
            .memory_ledger_ref
            .starts_with(MEMORY_LEDGER_PREFIX)
        || !envelope
            .refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !envelope
            .refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !envelope.refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !envelope
            .refs
            .cancellation_ref
            .starts_with(CANCELLATION_PREFIX)
        || !envelope
            .refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_FENCE_PREFIX)
        || !envelope
            .refs
            .route_caveat_ref
            .starts_with(ROUTE_CAVEAT_PREFIX)
        || !envelope
            .refs
            .scaling_ladder_ref
            .starts_with(SCALING_LADDER_PREFIX)
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "proof refs must use runtime-probe envelope prefixes".to_string(),
        ));
    }
    if envelope.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
        || !envelope.command_template_visible
        || !envelope.cli_help_surface_visible
        || !envelope.model_path_status_visible
        || !envelope.memory_sampling_plan_visible
        || !envelope.answer_packet_schema_visible
        || !envelope.scaling_ladder_visible
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "command, help, path, memory, AnswerPacket, and scaling visibility are required"
                .to_string(),
        ));
    }
    if !envelope.owner_approval_required
        || envelope.owner_approval_granted
        || envelope.download_executed
        || envelope.command_armed
        || envelope.command_executed
        || envelope.inference_executed
        || envelope.first_token_claimed
        || envelope.retained_token_digest_recorded
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "approval must remain pending and runtime execution must remain blocked".to_string(),
        ));
    }
    if !envelope.answer_packet_required
        || !envelope.run_event_log_required
        || !envelope.rollback_required
        || !envelope.cancellation_required
        || !envelope.memory_ledger_required
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "proof surfaces are required before any runtime probe".to_string(),
        ));
    }
    if envelope.quality_claimed
        || envelope.l2_capability_claimed
        || envelope.l3_wrv_claimed
        || envelope.mas_readiness_claimed
        || envelope.route_policy_mutated
        || envelope.hidden_cloud_fallback_allowed
        || envelope.hidden_route_authority_allowed
        || envelope.provider_fallback_allowed
        || envelope.server_sidecar_default_allowed
        || envelope.hf_or_url_download_allowed
        || envelope.multi_token_or_unbounded_generation_allowed
        || !envelope.e4b_requires_new_envelope
        || !envelope.twelve_b_requires_memory_repreflight
        || !envelope.thirty_one_b_vault_only
        || !envelope.seventy_b_cold_assembly_only
        || envelope.live_dense_70b_claimed
        || envelope.ssd_as_ram_claimed
    {
        return Err(SmallCompressedRuntimeProbeEnvelopeError::InvalidEnvelope(
            "product promotion, hidden authority, downloads, sidecars, and larger-model overclaims are forbidden".to_string(),
        ));
    }
    Ok(())
}

fn required_flags_present(args: &[String]) -> bool {
    REQUIRED_FLAGS
        .iter()
        .all(|flag| args.iter().any(|value| value == flag))
}

fn forbidden_flags_present(args: &[String]) -> bool {
    args.iter()
        .any(|arg| FORBIDDEN_FLAGS.iter().any(|flag| arg == flag))
}

fn arg_value<'a>(args: &'a [String], flag: &str) -> Option<&'a str> {
    args.windows(2)
        .find(|window| window[0] == flag)
        .map(|window| window[1].as_str())
}

fn all_phases_present(phases: &[SmallCompressedRuntimeProbePhase]) -> bool {
    let set: HashSet<_> = phases.iter().copied().collect();
    required_phases().iter().all(|phase| set.contains(phase))
}

pub fn required_phases() -> [SmallCompressedRuntimeProbePhase; 16] {
    [
        SmallCompressedRuntimeProbePhase::OwnerApprovalTokenBound,
        SmallCompressedRuntimeProbePhase::ModelPathBound,
        SmallCompressedRuntimeProbePhase::CommandCardBound,
        SmallCompressedRuntimeProbePhase::OfflineModeBound,
        SmallCompressedRuntimeProbePhase::SyntheticPromptHashBound,
        SmallCompressedRuntimeProbePhase::OneTokenBudgetBound,
        SmallCompressedRuntimeProbePhase::ContextAndBatchCapsBound,
        SmallCompressedRuntimeProbePhase::MemoryBeforeSampleRequired,
        SmallCompressedRuntimeProbePhase::RuntimeStartSampleRequired,
        SmallCompressedRuntimeProbePhase::FirstTokenRedactionRequired,
        SmallCompressedRuntimeProbePhase::CancellationDeadlineBound,
        SmallCompressedRuntimeProbePhase::RollbackBound,
        SmallCompressedRuntimeProbePhase::RunEventLogBound,
        SmallCompressedRuntimeProbePhase::AnswerPacketBound,
        SmallCompressedRuntimeProbePhase::NonPromotionBound,
        SmallCompressedRuntimeProbePhase::LargerModelEscalationBlocked,
    ]
}

#[allow(clippy::too_many_arguments)]
fn envelope_set_preimage(
    upstream_model_path_set_address: &UasAddress,
    upstream_model_path_witness_ref: &str,
    selected_envelope_id: &str,
    envelopes: &[SmallCompressedRuntimeProbeProofEnvelope],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "{}\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_model_path_set_address,
        upstream_model_path_witness_ref,
        selected_envelope_id,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for envelope in envelopes {
        let fields = [
            envelope.envelope_id.clone(),
            envelope.selected_candidate_id.clone(),
            envelope.model_id.clone(),
            envelope.required_filename.clone(),
            envelope.command_path.clone(),
            envelope.command_template_args.join(" "),
            envelope.forbidden_flags.join(" "),
            format!("{:?}", envelope.required_phases),
            format!("{:?}", envelope.status),
            product_build_preimage(&envelope.product_build).to_string(),
            format!("{:?}", envelope.pro_status),
            format!("{:?}", envelope.promotion_tier),
            envelope.bytes.command_template_metadata_bytes.to_string(),
            envelope.bytes.cli_help_metadata_bytes_read.to_string(),
            envelope.bytes.downloaded_model_bytes.to_string(),
            envelope.bytes.opened_model_bytes.to_string(),
            envelope.bytes.hashed_model_bytes.to_string(),
            envelope.bytes.resident_model_bytes.to_string(),
            envelope.bytes.model_bytes_loaded.to_string(),
            envelope.bytes.runtime_bytes_loaded.to_string(),
            envelope.bytes.provider_calls_made.to_string(),
            envelope.bytes.retained_token_budget.to_string(),
            envelope.bytes.max_context_tokens.to_string(),
            envelope.bytes.timeout_ms.to_string(),
            envelope.bytes.cancellation_deadline_ms.to_string(),
            envelope.refs.upstream_model_path_ref.clone(),
            envelope.refs.command_template_ref.clone(),
            envelope.refs.source_model_ref.clone(),
            envelope.refs.model_path_ref.clone(),
            envelope.refs.owner_approval_ref.clone(),
            envelope.refs.prompt_hash_ref.clone(),
            envelope.refs.memory_ledger_ref.clone(),
            envelope.refs.answer_packet_ref.clone(),
            envelope.refs.run_event_log_ref.clone(),
            envelope.refs.rollback_ref.clone(),
            envelope.refs.cancellation_ref.clone(),
            envelope.refs.compatibility_fence_ref.clone(),
            envelope.refs.route_caveat_ref.clone(),
            envelope.refs.scaling_ladder_ref.clone(),
            envelope.command_template_visible.to_string(),
            envelope.cli_help_surface_visible.to_string(),
            envelope.model_path_status_visible.to_string(),
            envelope.memory_sampling_plan_visible.to_string(),
            envelope.answer_packet_schema_visible.to_string(),
            envelope.scaling_ladder_visible.to_string(),
            envelope.owner_approval_required.to_string(),
            envelope.owner_approval_granted.to_string(),
            envelope.download_executed.to_string(),
            envelope.command_armed.to_string(),
            envelope.command_executed.to_string(),
            envelope.inference_executed.to_string(),
            envelope.first_token_claimed.to_string(),
            envelope.retained_token_digest_recorded.to_string(),
            envelope.quality_claimed.to_string(),
            envelope.l2_capability_claimed.to_string(),
            envelope.l3_wrv_claimed.to_string(),
            envelope.mas_readiness_claimed.to_string(),
            envelope.answer_packet_required.to_string(),
            envelope.run_event_log_required.to_string(),
            envelope.rollback_required.to_string(),
            envelope.cancellation_required.to_string(),
            envelope.memory_ledger_required.to_string(),
            envelope.route_policy_mutated.to_string(),
            envelope.hidden_cloud_fallback_allowed.to_string(),
            envelope.hidden_route_authority_allowed.to_string(),
            envelope.provider_fallback_allowed.to_string(),
            envelope.server_sidecar_default_allowed.to_string(),
            envelope.hf_or_url_download_allowed.to_string(),
            envelope
                .multi_token_or_unbounded_generation_allowed
                .to_string(),
            envelope.e4b_requires_new_envelope.to_string(),
            envelope.twelve_b_requires_memory_repreflight.to_string(),
            envelope.thirty_one_b_vault_only.to_string(),
            envelope.seventy_b_cold_assembly_only.to_string(),
            envelope.live_dense_70b_claimed.to_string(),
            envelope.ssd_as_ram_claimed.to_string(),
            envelope.user_visible_summary.clone(),
        ];
        preimage.push_str(&fields.join("\n"));
        preimage.push('\n');
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

    const CREATED_AT_MS: u64 = 1_779_037_300_000;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("small_compressed_model_model_path_readiness_card".to_string()),
            b"small-compressed-model-runtime-probe-proof-envelope-upstream",
            CREATED_AT_MS,
        )
    }

    fn args() -> Vec<String> {
        REQUIRED_FLAGS
            .iter()
            .map(|flag| (*flag).to_string())
            .collect()
    }

    fn refs(id: &str) -> SmallCompressedRuntimeProbeRefs {
        SmallCompressedRuntimeProbeRefs {
            upstream_model_path_ref:
                "artifact:small_compressed_model_model_path_readiness_card:result".to_string(),
            command_template_ref: format!("command_template:small_compressed_runtime_probe:{id}"),
            source_model_ref:
                "source:model:gemma4-e2b-qat-gguf:1894d1fc0a19d86697abd40483f5983c867df03f"
                    .to_string(),
            model_path_ref: format!("model_path:owner_approval_required:{id}"),
            owner_approval_ref: format!("owner_approval:pending:{id}"),
            prompt_hash_ref: format!("prompt_hash:synthetic_non_user:{id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_runtime_probe:{id}"),
            answer_packet_ref: format!("answer_packet:small_compressed_runtime_probe:{id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_runtime_probe:{id}"),
            rollback_ref: format!("rollback:small_compressed_runtime_probe:{id}"),
            cancellation_ref: format!("cancel:small_compressed_runtime_probe:{id}"),
            compatibility_fence_ref: format!("compat:small_compressed_runtime_probe:{id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_runtime_probe:{id}"),
            scaling_ladder_ref: format!("scaling_ladder:gemma_qat_local:{id}"),
        }
    }

    fn envelope() -> SmallCompressedRuntimeProbeProofEnvelope {
        SmallCompressedRuntimeProbeProofEnvelope {
            envelope_id: "gemma4_e2b_qat_gguf_runtime_probe_proof_envelope".to_string(),
            selected_candidate_id: SELECTED_E2B_CANDIDATE.to_string(),
            model_id: E2B_MODEL_ID.to_string(),
            required_filename: REQUIRED_FILENAME.to_string(),
            command_path: LLAMA_CLI_PATH.to_string(),
            command_template_args: args(),
            forbidden_flags: FORBIDDEN_FLAGS
                .iter()
                .map(|flag| (*flag).to_string())
                .collect(),
            required_phases: required_phases().to_vec(),
            status: SmallCompressedRuntimeProbeEnvelopeStatus::PendingOwnerApprovalAndPath,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
            bytes: SmallCompressedRuntimeProbeByteLedger::metadata_only(4_096, 16_384, 1, 512, 60_000, 45_000),
            refs: refs("gemma4_e2b_qat_gguf_runtime_probe_proof_envelope"),
            user_visible_summary: "The E2B runtime-probe proof envelope records a local-only llama-cli one-token template, synthetic prompt hash, memory sampling plan, cancellation deadline, rollback, RunEventLog, AnswerPacket, and larger-model escalation blockers. Owner approval and model path are still pending, so no download, command, inference, provider fallback, L2, L3, 12B, 31B, or 70B product claim is allowed.".to_string(),
            command_template_visible: true,
            cli_help_surface_visible: true,
            model_path_status_visible: true,
            memory_sampling_plan_visible: true,
            answer_packet_schema_visible: true,
            scaling_ladder_visible: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            download_executed: false,
            command_armed: false,
            command_executed: false,
            inference_executed: false,
            first_token_claimed: false,
            retained_token_digest_recorded: false,
            quality_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            mas_readiness_claimed: false,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            cancellation_required: true,
            memory_ledger_required: true,
            route_policy_mutated: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            provider_fallback_allowed: false,
            server_sidecar_default_allowed: false,
            hf_or_url_download_allowed: false,
            multi_token_or_unbounded_generation_allowed: false,
            e4b_requires_new_envelope: true,
            twelve_b_requires_memory_repreflight: true,
            thirty_one_b_vault_only: true,
            seventy_b_cold_assembly_only: true,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn envelope_set(
        envelopes: Vec<SmallCompressedRuntimeProbeProofEnvelope>,
    ) -> Result<SmallCompressedRuntimeProbeProofEnvelopeSet, SmallCompressedRuntimeProbeEnvelopeError>
    {
        SmallCompressedRuntimeProbeProofEnvelopeSet::from_model_path_readiness(
            upstream_address(),
            "artifact:small_compressed_model_model_path_readiness_card:result",
            "gemma4_e2b_qat_gguf_runtime_probe_proof_envelope",
            envelopes,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            32_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_probe_envelope_deterministically() {
        let first = envelope_set(vec![envelope()]);
        let second = envelope_set(vec![envelope()]);
        assert!(first.is_ok());
        assert!(second.is_ok());
        let first = match first {
            Ok(value) => value,
            Err(error) => panic!("{error}"),
        };
        let second = match second {
            Ok(value) => value,
            Err(error) => panic!("{error}"),
        };
        assert_eq!(first.set_address, second.set_address);
        assert_eq!(first.metrics().required_phase_count, 16);
        assert_eq!(first.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_network_and_unbounded_command_flags() {
        let mut bad = envelope();
        bad.command_template_args.push("--hf-repo".to_string());
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        let predict = bad.command_template_args.iter().position(|arg| arg == "1");
        assert!(predict.is_some());
        if let Some(index) = predict {
            bad.command_template_args[index] = "-1".to_string();
        }
        assert!(envelope_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_runtime_execution_and_byte_claims() {
        let mut bad = envelope();
        bad.command_executed = true;
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        bad.bytes.opened_model_bytes = 1;
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        bad.provider_fallback_allowed = true;
        assert!(envelope_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_missing_proof_surfaces_and_phases() {
        let mut bad = envelope();
        bad.required_phases.pop();
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        bad.answer_packet_required = false;
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        bad.refs.memory_ledger_ref = "memory:wrong".to_string();
        assert!(envelope_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_larger_model_and_product_promotion() {
        let mut bad = envelope();
        bad.twelve_b_requires_memory_repreflight = false;
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        bad.live_dense_70b_claimed = true;
        assert!(envelope_set(vec![bad]).is_err());

        let mut bad = envelope();
        bad.l2_capability_claimed = true;
        assert!(envelope_set(vec![bad]).is_err());
    }
}
