//! Small compressed-model owner-approved runtime probe.
//!
//! Successor to `small_compressed_model_runtime_probe_proof_envelope`. The proof
//! envelope fixed the command template + proof phases while owner approval, the
//! model path, download, command execution, and runtime bytes stayed fail-closed.
//! This unit models the *owner-approval-gated* runtime probe itself: the gate
//! that, once the owner explicitly approves and binds a real local model path,
//! would arm and run the visible `/opt/homebrew/bin/llama-cli` one-token E2B
//! probe — but whose CANONICAL witness is fail-closed (approval pending, command
//! unarmed, execution and first-token blocked), exactly like the parallel
//! `gemma_qat_e2b_owner_approved_first_token_runtime_probe`.
//!
//! It is a metadata-only T1/L1 witness: it loads zero model/runtime bytes, makes
//! zero provider calls, executes no command, and promotes nothing to L2/L3/MAS.
//! The actual first-token execution + receipt is the owner-gated frontier
//! (`NEXT_CURSOR`), which needs real on-device bytes and a signed run.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, SmallCompressedHarnessPromotionTier, UasAddress, UasKind,
};

pub const SMALL_COMPRESSED_MODEL_OWNER_APPROVED_RUNTIME_PROBE_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe";
/// The actual first-token execution + retained-token receipt is the owner-gated
/// frontier: it needs explicit owner approval, a real local model path, and a
/// signed on-device run that produces real (redacted) bytes. Intentionally
/// unbuilt until those exist.
pub const SMALL_COMPRESSED_MODEL_OWNER_APPROVED_RUNTIME_PROBE_NEXT_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe_first_token_owner_gated_frontier";

const UPSTREAM_ENVELOPE_PREFIX: &str =
    "artifact:small_compressed_model_runtime_probe_proof_envelope:";
const COMMAND_TEMPLATE_PREFIX: &str = "command_template:small_compressed_owner_approved_probe:";
const SOURCE_MODEL_PREFIX: &str = "source:model:gemma4-e2b-qat-gguf:";
const MODEL_PATH_PREFIX: &str = "model_path:owner_approval_required:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:";
const PROMPT_HASH_PREFIX: &str = "prompt_hash:synthetic_non_user:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:small_compressed_owner_approved_probe:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:small_compressed_owner_approved_probe:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:small_compressed_owner_approved_probe:";
const ROLLBACK_PREFIX: &str = "rollback:small_compressed_owner_approved_probe:";
const CANCELLATION_PREFIX: &str = "cancel:small_compressed_owner_approved_probe:";
const ABSTENTION_PREFIX: &str = "abstention:small_compressed_owner_approved_probe:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:small_compressed_owner_approved_probe:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:small_compressed_owner_approved_probe:";
const SCALING_LADDER_PREFIX: &str = "scaling_ladder:gemma_qat_local:";

const MAX_SET_METADATA_BYTES: u64 = 128 * 1024;
const MAX_PROBE_METADATA_BYTES: u64 = 64 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 240;
const SELECTED_E2B_CANDIDATE: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const E2B_MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const REQUIRED_FILENAME: &str = "gemma-4-E2B_q4_0-it.gguf";
const LLAMA_CLI_PATH: &str = "/opt/homebrew/bin/llama-cli";
const MODEL_PATH_PLACEHOLDER: &str = "<OWNER_APPROVED_MODEL_PATH>";
const PROMPT_PLACEHOLDER: &str = "<SYNTHETIC_NON_USER_PROMPT>";
/// The exact phrase the owner must supply to flip approval; absent in the
/// canonical fail-closed witness.
const OWNER_APPROVAL_PHRASE: &str = "APPROVE_SMALL_COMPRESSED_E2B_LLAMA_CLI_ONE_TOKEN_PROBE_V0";

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

// UAS: uas:small-compressed-owner-approved-probe:status
// Plane: Controller + Verification
// Residency: fail-closed owner-approval-gated probe status; execution deferred.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedOwnerApprovedProbeStatus {
    /// Canonical state: owner approval not granted, command unarmed, run blocked.
    OwnerApprovalPending,
    /// Only a separate on-device runtime witness (the owner-gated frontier) may
    /// record an armed/executed probe; never this metadata gate.
    ApprovedOnlyBySeparateOnDeviceWitness,
    Blocked,
}

// UAS: uas:small-compressed-owner-approved-probe:phase
// Plane: Verification
// Residency: required proof phases for the owner-approved one-token run.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedOwnerApprovedProbePhase {
    EnvelopeBound,
    OwnerApprovalPhraseRequired,
    RealModelPathRequired,
    SmallestModelFirst,
    OfflineModeBound,
    SyntheticPromptHashBound,
    OneTokenBudgetBound,
    ContextAndBatchCapsBound,
    MemoryBeforeSampleRequired,
    MemoryAfterSampleRequired,
    FirstTokenRedactionRequired,
    CancellationDeadlineBound,
    AbstentionBound,
    RollbackBound,
    RunEventLogBound,
    AnswerPacketBound,
    NonPromotionBound,
    LargerModelEscalationBlocked,
}

// UAS: uas:small-compressed-owner-approved-probe:byte-ledger
// Plane: Verification
// Residency: command/help metadata only; all runtime/model byte counters zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovedProbeByteLedger {
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

impl SmallCompressedOwnerApprovedProbeByteLedger {
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

// UAS: uas:small-compressed-owner-approved-probe:refs
// Plane: Verification
// Residency: proof refs required before the owner-gated runtime frontier runs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovedProbeRefs {
    pub upstream_envelope_ref: String,
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
    pub abstention_ref: String,
    pub compatibility_fence_ref: String,
    pub route_caveat_ref: String,
    pub scaling_ladder_ref: String,
}

// UAS: uas:small-compressed-owner-approved-probe:card
// Plane: Controller + Verification
// Residency: fail-closed owner-approval-gated probe, not the approved runtime.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovedRuntimeProbe {
    pub probe_id: String,
    pub selected_candidate_id: String,
    pub model_id: String,
    pub required_filename: String,
    pub command_path: String,
    pub command_template_args: Vec<String>,
    pub forbidden_flags: Vec<String>,
    pub required_phases: Vec<SmallCompressedOwnerApprovedProbePhase>,
    pub owner_approval_phrase: String,
    pub status: SmallCompressedOwnerApprovedProbeStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: SmallCompressedHarnessPromotionTier,
    pub bytes: SmallCompressedOwnerApprovedProbeByteLedger,
    pub refs: SmallCompressedOwnerApprovedProbeRefs,
    pub user_visible_summary: String,
    pub command_template_visible: bool,
    pub cli_help_surface_visible: bool,
    pub model_path_status_visible: bool,
    pub memory_sampling_plan_visible: bool,
    pub answer_packet_schema_visible: bool,
    pub scaling_ladder_visible: bool,
    // Approval + execution state. Canonical witness keeps every one fail-closed.
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub real_model_path_bound: bool,
    pub download_executed: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub inference_executed: bool,
    pub first_token_observed: bool,
    pub retained_token_digest_recorded: bool,
    pub memory_before_sample_recorded: bool,
    pub memory_after_sample_recorded: bool,
    // Proof surfaces that must be required before any run.
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub cancellation_required: bool,
    pub abstention_required: bool,
    pub memory_ledger_required: bool,
    // Forbidden overclaims / escalations.
    pub quality_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub route_policy_mutated: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub provider_fallback_allowed: bool,
    pub server_sidecar_default_allowed: bool,
    pub hf_or_url_download_allowed: bool,
    pub multi_token_or_unbounded_generation_allowed: bool,
    pub e4b_requires_new_probe: bool,
    pub twelve_b_requires_memory_repreflight: bool,
    pub thirty_one_b_vault_only: bool,
    pub seventy_b_cold_assembly_only: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:small-compressed-owner-approved-probe:set
// Plane: Controller + Verification
// Residency: probe set bound to the upstream runtime-probe proof envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovedRuntimeProbeSet {
    pub set_address: UasAddress,
    pub upstream_envelope_set_address: UasAddress,
    pub upstream_envelope_witness_ref: String,
    pub selected_probe_id: String,
    pub probes: Vec<SmallCompressedOwnerApprovedRuntimeProbe>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:small-compressed-owner-approved-probe:metrics
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovedProbeMetrics {
    pub probe_count: u64,
    pub required_phase_count: u64,
    pub required_flag_count: u64,
    pub forbidden_flag_count: u64,
    pub downloaded_model_bytes: u64,
    pub opened_model_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub retained_token_budget: u64,
    pub max_context_tokens: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SmallCompressedOwnerApprovedProbeError {
    InvalidProbe(String),
    InvalidSet(String),
}

impl fmt::Display for SmallCompressedOwnerApprovedProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidProbe(reason) => write!(f, "invalid owner-approved probe: {reason}"),
            Self::InvalidSet(reason) => write!(f, "invalid owner-approved probe set: {reason}"),
        }
    }
}

impl std::error::Error for SmallCompressedOwnerApprovedProbeError {}

impl SmallCompressedOwnerApprovedRuntimeProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_proof_envelope(
        upstream_envelope_set_address: UasAddress,
        upstream_envelope_witness_ref: impl Into<String>,
        selected_probe_id: impl Into<String>,
        mut probes: Vec<SmallCompressedOwnerApprovedRuntimeProbe>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, SmallCompressedOwnerApprovedProbeError> {
        probes.sort_by(|a, b| a.probe_id.cmp(&b.probe_id));
        let witness_ref = upstream_envelope_witness_ref.into();
        let selected_probe_id = selected_probe_id.into();
        validate_set_inputs(
            &upstream_envelope_set_address,
            &witness_ref,
            &selected_probe_id,
            &probes,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = set_preimage(
            &upstream_envelope_set_address,
            &witness_ref,
            &selected_probe_id,
            &probes,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(SMALL_COMPRESSED_MODEL_OWNER_APPROVED_RUNTIME_PROBE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_envelope_set_address,
            upstream_envelope_witness_ref: witness_ref,
            selected_probe_id,
            probes,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> SmallCompressedOwnerApprovedProbeMetrics {
        let probe = &self.probes[0];
        SmallCompressedOwnerApprovedProbeMetrics {
            probe_count: self.probes.len() as u64,
            required_phase_count: probe.required_phases.len() as u64,
            required_flag_count: REQUIRED_FLAGS.len() as u64,
            forbidden_flag_count: FORBIDDEN_FLAGS.len() as u64,
            downloaded_model_bytes: probe.bytes.downloaded_model_bytes,
            opened_model_bytes: probe.bytes.opened_model_bytes,
            model_bytes_loaded: probe.bytes.model_bytes_loaded,
            runtime_bytes_loaded: probe.bytes.runtime_bytes_loaded,
            provider_calls_made: probe.bytes.provider_calls_made,
            retained_token_budget: probe.bytes.retained_token_budget,
            max_context_tokens: probe.bytes.max_context_tokens,
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_envelope_set_address: &UasAddress,
    upstream_envelope_witness_ref: &str,
    selected_probe_id: &str,
    probes: &[SmallCompressedOwnerApprovedRuntimeProbe],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), SmallCompressedOwnerApprovedProbeError> {
    if upstream_envelope_set_address.to_string().is_empty() {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "upstream envelope address is empty".to_string(),
        ));
    }
    if !upstream_envelope_witness_ref.starts_with(UPSTREAM_ENVELOPE_PREFIX) {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "upstream witness ref must bind the runtime-probe proof envelope".to_string(),
        ));
    }
    if selected_probe_id.is_empty() {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "selected probe id is empty".to_string(),
        ));
    }
    if probes.len() != 1 {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "expected exactly one selected E2B owner-approved probe".to_string(),
        ));
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "owner-approved probe set must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "set metadata budget is invalid".to_string(),
        ));
    }
    if !l1_l2_l3_separated || !runtime_deferred || !product_promotion_blocked {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "L1/L2/L3 separation, runtime deferral, and product block are required".to_string(),
        ));
    }
    let probe = &probes[0];
    validate_probe(probe)?;
    if probe.probe_id != selected_probe_id {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidSet(
            "selected probe is missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_probe(
    probe: &SmallCompressedOwnerApprovedRuntimeProbe,
) -> Result<(), SmallCompressedOwnerApprovedProbeError> {
    if probe.probe_id.trim().is_empty() {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "probe id is empty".to_string(),
        ));
    }
    if probe.selected_candidate_id != SELECTED_E2B_CANDIDATE
        || probe.model_id != E2B_MODEL_ID
        || probe.required_filename != REQUIRED_FILENAME
        || probe.command_path != LLAMA_CLI_PATH
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "only the selected E2B QAT GGUF llama-cli probe is allowed".to_string(),
        ));
    }
    if probe.owner_approval_phrase != OWNER_APPROVAL_PHRASE {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "owner-approval phrase must match the canonical gate phrase".to_string(),
        ));
    }
    if !required_flags_present(&probe.command_template_args)
        || forbidden_flags_present(&probe.command_template_args)
        || probe.forbidden_flags.len() < FORBIDDEN_FLAGS.len()
        || !FORBIDDEN_FLAGS
            .iter()
            .all(|flag| probe.forbidden_flags.iter().any(|value| value == flag))
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "command template must be offline, one-token, capped, local-path only, and network-free"
                .to_string(),
        ));
    }
    if arg_value(&probe.command_template_args, "--predict") != Some("1")
        || arg_value(&probe.command_template_args, "--ctx-size") != Some("512")
        || arg_value(&probe.command_template_args, "--batch-size") != Some("32")
        || arg_value(&probe.command_template_args, "--ubatch-size") != Some("32")
        || arg_value(&probe.command_template_args, "--temp") != Some("0")
        || arg_value(&probe.command_template_args, "--seed") != Some("0")
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "command value caps are invalid".to_string(),
        ));
    }
    if !all_phases_present(&probe.required_phases) {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "all owner-approved runtime-probe proof phases are required".to_string(),
        ));
    }
    if probe.status != SmallCompressedOwnerApprovedProbeStatus::OwnerApprovalPending
        || probe.product_build != ProductBuild::Pro
        || probe.pro_status != ProStatus::ResearchCandidate
        || probe.promotion_tier != SmallCompressedHarnessPromotionTier::T1L1Metadata
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "owner-approved probe must remain pending T1/L1 Pro ResearchCandidate".to_string(),
        ));
    }
    if probe.bytes.command_template_metadata_bytes == 0
        || probe.bytes.cli_help_metadata_bytes_read == 0
        || probe.bytes.command_template_metadata_bytes > MAX_PROBE_METADATA_BYTES
        || probe.bytes.cli_help_metadata_bytes_read > MAX_PROBE_METADATA_BYTES
        || probe.bytes.downloaded_model_bytes != 0
        || probe.bytes.opened_model_bytes != 0
        || probe.bytes.hashed_model_bytes != 0
        || probe.bytes.resident_model_bytes != 0
        || probe.bytes.model_bytes_loaded != 0
        || probe.bytes.runtime_bytes_loaded != 0
        || probe.bytes.provider_calls_made != 0
        || probe.bytes.retained_token_budget != 1
        || probe.bytes.max_context_tokens != 512
        || probe.bytes.timeout_ms == 0
        || probe.bytes.cancellation_deadline_ms == 0
        || probe.bytes.cancellation_deadline_ms > probe.bytes.timeout_ms
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "owner-approved probe must be metadata-only with bounded one-token budgets".to_string(),
        ));
    }
    if !probe
        .refs
        .upstream_envelope_ref
        .starts_with(UPSTREAM_ENVELOPE_PREFIX)
        || !probe
            .refs
            .command_template_ref
            .starts_with(COMMAND_TEMPLATE_PREFIX)
        || !probe.refs.source_model_ref.starts_with(SOURCE_MODEL_PREFIX)
        || !probe.refs.model_path_ref.starts_with(MODEL_PATH_PREFIX)
        || !probe
            .refs
            .owner_approval_ref
            .starts_with(OWNER_APPROVAL_PREFIX)
        || !probe.refs.prompt_hash_ref.starts_with(PROMPT_HASH_PREFIX)
        || !probe
            .refs
            .memory_ledger_ref
            .starts_with(MEMORY_LEDGER_PREFIX)
        || !probe
            .refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !probe
            .refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !probe.refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !probe.refs.cancellation_ref.starts_with(CANCELLATION_PREFIX)
        || !probe.refs.abstention_ref.starts_with(ABSTENTION_PREFIX)
        || !probe
            .refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_FENCE_PREFIX)
        || !probe.refs.route_caveat_ref.starts_with(ROUTE_CAVEAT_PREFIX)
        || !probe
            .refs
            .scaling_ladder_ref
            .starts_with(SCALING_LADDER_PREFIX)
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "proof refs must use owner-approved probe prefixes".to_string(),
        ));
    }
    if probe.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
        || !probe.command_template_visible
        || !probe.cli_help_surface_visible
        || !probe.model_path_status_visible
        || !probe.memory_sampling_plan_visible
        || !probe.answer_packet_schema_visible
        || !probe.scaling_ladder_visible
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "command, help, path, memory, AnswerPacket, and scaling visibility are required"
                .to_string(),
        ));
    }
    // Fail-closed: approval pending, no real path bound, command unarmed, no run.
    if !probe.owner_approval_required
        || probe.owner_approval_granted
        || probe.real_model_path_bound
        || probe.download_executed
        || probe.command_armed
        || probe.command_executed
        || probe.inference_executed
        || probe.first_token_observed
        || probe.retained_token_digest_recorded
        || probe.memory_before_sample_recorded
        || probe.memory_after_sample_recorded
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "approval must remain pending and every execution surface must stay fail-closed"
                .to_string(),
        ));
    }
    if !probe.answer_packet_required
        || !probe.run_event_log_required
        || !probe.rollback_required
        || !probe.cancellation_required
        || !probe.abstention_required
        || !probe.memory_ledger_required
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "proof surfaces are required before any runtime probe".to_string(),
        ));
    }
    if probe.quality_claimed
        || probe.l2_capability_claimed
        || probe.l3_wrv_claimed
        || probe.mas_readiness_claimed
        || probe.route_policy_mutated
        || probe.hidden_cloud_fallback_allowed
        || probe.hidden_route_authority_allowed
        || probe.provider_fallback_allowed
        || probe.server_sidecar_default_allowed
        || probe.hf_or_url_download_allowed
        || probe.multi_token_or_unbounded_generation_allowed
        || !probe.e4b_requires_new_probe
        || !probe.twelve_b_requires_memory_repreflight
        || !probe.thirty_one_b_vault_only
        || !probe.seventy_b_cold_assembly_only
        || probe.live_dense_70b_claimed
        || probe.ssd_as_ram_claimed
    {
        return Err(SmallCompressedOwnerApprovedProbeError::InvalidProbe(
            "product promotion, hidden authority, downloads, sidecars, and larger-model overclaims are forbidden"
                .to_string(),
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
    args.iter()
        .position(|value| value == flag)
        .and_then(|index| args.get(index + 1))
        .map(|value| value.as_str())
}

fn all_phases_present(phases: &[SmallCompressedOwnerApprovedProbePhase]) -> bool {
    use SmallCompressedOwnerApprovedProbePhase::*;
    let required = [
        EnvelopeBound,
        OwnerApprovalPhraseRequired,
        RealModelPathRequired,
        SmallestModelFirst,
        OfflineModeBound,
        SyntheticPromptHashBound,
        OneTokenBudgetBound,
        ContextAndBatchCapsBound,
        MemoryBeforeSampleRequired,
        MemoryAfterSampleRequired,
        FirstTokenRedactionRequired,
        CancellationDeadlineBound,
        AbstentionBound,
        RollbackBound,
        RunEventLogBound,
        AnswerPacketBound,
        NonPromotionBound,
        LargerModelEscalationBlocked,
    ];
    let present: HashSet<_> = phases.iter().copied().collect();
    required.iter().all(|phase| present.contains(phase))
}

fn product_build_preimage(product_build: &ProductBuild) -> &'static str {
    match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    }
}

#[allow(clippy::too_many_arguments)]
fn set_preimage(
    upstream_envelope_set_address: &UasAddress,
    upstream_envelope_witness_ref: &str,
    selected_probe_id: &str,
    probes: &[SmallCompressedOwnerApprovedRuntimeProbe],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = String::new();
    preimage.push_str("small_compressed_model_owner_approved_runtime_probe\n");
    preimage.push_str(&upstream_envelope_set_address.to_string());
    preimage.push('\n');
    preimage.push_str(upstream_envelope_witness_ref);
    preimage.push('\n');
    preimage.push_str(selected_probe_id);
    preimage.push('\n');
    preimage.push_str(product_build_preimage(product_build));
    preimage.push('\n');
    preimage.push_str(&format!("{pro_status:?}"));
    preimage.push('\n');
    preimage.push_str(&metadata_bytes.to_string());
    preimage.push('\n');
    preimage.push_str(&l1_l2_l3_separated.to_string());
    preimage.push('\n');
    preimage.push_str(&runtime_deferred.to_string());
    preimage.push('\n');
    preimage.push_str(&product_promotion_blocked.to_string());
    preimage.push('\n');
    for probe in probes {
        let fields = [
            probe.probe_id.clone(),
            probe.selected_candidate_id.clone(),
            probe.model_id.clone(),
            probe.required_filename.clone(),
            probe.command_path.clone(),
            probe.command_template_args.join(" "),
            probe.forbidden_flags.join(" "),
            format!("{:?}", probe.required_phases),
            probe.owner_approval_phrase.clone(),
            format!("{:?}", probe.status),
            product_build_preimage(&probe.product_build).to_string(),
            format!("{:?}", probe.pro_status),
            format!("{:?}", probe.promotion_tier),
            probe.bytes.command_template_metadata_bytes.to_string(),
            probe.bytes.cli_help_metadata_bytes_read.to_string(),
            probe.bytes.downloaded_model_bytes.to_string(),
            probe.bytes.opened_model_bytes.to_string(),
            probe.bytes.hashed_model_bytes.to_string(),
            probe.bytes.resident_model_bytes.to_string(),
            probe.bytes.model_bytes_loaded.to_string(),
            probe.bytes.runtime_bytes_loaded.to_string(),
            probe.bytes.provider_calls_made.to_string(),
            probe.bytes.retained_token_budget.to_string(),
            probe.bytes.max_context_tokens.to_string(),
            probe.bytes.timeout_ms.to_string(),
            probe.bytes.cancellation_deadline_ms.to_string(),
            probe.refs.upstream_envelope_ref.clone(),
            probe.refs.command_template_ref.clone(),
            probe.refs.source_model_ref.clone(),
            probe.refs.model_path_ref.clone(),
            probe.refs.owner_approval_ref.clone(),
            probe.refs.prompt_hash_ref.clone(),
            probe.refs.memory_ledger_ref.clone(),
            probe.refs.answer_packet_ref.clone(),
            probe.refs.run_event_log_ref.clone(),
            probe.refs.rollback_ref.clone(),
            probe.refs.cancellation_ref.clone(),
            probe.refs.abstention_ref.clone(),
            probe.refs.compatibility_fence_ref.clone(),
            probe.refs.route_caveat_ref.clone(),
            probe.refs.scaling_ladder_ref.clone(),
            probe.command_template_visible.to_string(),
            probe.cli_help_surface_visible.to_string(),
            probe.model_path_status_visible.to_string(),
            probe.memory_sampling_plan_visible.to_string(),
            probe.answer_packet_schema_visible.to_string(),
            probe.scaling_ladder_visible.to_string(),
            probe.owner_approval_required.to_string(),
            probe.owner_approval_granted.to_string(),
            probe.real_model_path_bound.to_string(),
            probe.download_executed.to_string(),
            probe.command_armed.to_string(),
            probe.command_executed.to_string(),
            probe.inference_executed.to_string(),
            probe.first_token_observed.to_string(),
            probe.retained_token_digest_recorded.to_string(),
            probe.memory_before_sample_recorded.to_string(),
            probe.memory_after_sample_recorded.to_string(),
            probe.answer_packet_required.to_string(),
            probe.run_event_log_required.to_string(),
            probe.rollback_required.to_string(),
            probe.cancellation_required.to_string(),
            probe.abstention_required.to_string(),
            probe.memory_ledger_required.to_string(),
            probe.quality_claimed.to_string(),
            probe.l2_capability_claimed.to_string(),
            probe.l3_wrv_claimed.to_string(),
            probe.mas_readiness_claimed.to_string(),
            probe.route_policy_mutated.to_string(),
            probe.hidden_cloud_fallback_allowed.to_string(),
            probe.hidden_route_authority_allowed.to_string(),
            probe.provider_fallback_allowed.to_string(),
            probe.server_sidecar_default_allowed.to_string(),
            probe.hf_or_url_download_allowed.to_string(),
            probe
                .multi_token_or_unbounded_generation_allowed
                .to_string(),
            probe.e4b_requires_new_probe.to_string(),
            probe.twelve_b_requires_memory_repreflight.to_string(),
            probe.thirty_one_b_vault_only.to_string(),
            probe.seventy_b_cold_assembly_only.to_string(),
            probe.live_dense_70b_claimed.to_string(),
            probe.ssd_as_ram_claimed.to_string(),
            probe.user_visible_summary.clone(),
        ];
        preimage.push_str(&fields.join("\n"));
        preimage.push('\n');
    }
    preimage
}

/// The canonical fail-closed owner-approved runtime probe witness: owner
/// approval pending, no real path bound, command unarmed, execution and
/// first-token blocked, all proof surfaces required, zero runtime/model bytes.
pub fn canonical_small_compressed_owner_approved_runtime_probe(
) -> SmallCompressedOwnerApprovedRuntimeProbe {
    let command_template_args: Vec<String> = REQUIRED_FLAGS
        .iter()
        .map(|flag| (*flag).to_string())
        .collect();
    let forbidden_flags: Vec<String> = FORBIDDEN_FLAGS
        .iter()
        .map(|flag| (*flag).to_string())
        .collect();
    let required_phases = vec![
        SmallCompressedOwnerApprovedProbePhase::EnvelopeBound,
        SmallCompressedOwnerApprovedProbePhase::OwnerApprovalPhraseRequired,
        SmallCompressedOwnerApprovedProbePhase::RealModelPathRequired,
        SmallCompressedOwnerApprovedProbePhase::SmallestModelFirst,
        SmallCompressedOwnerApprovedProbePhase::OfflineModeBound,
        SmallCompressedOwnerApprovedProbePhase::SyntheticPromptHashBound,
        SmallCompressedOwnerApprovedProbePhase::OneTokenBudgetBound,
        SmallCompressedOwnerApprovedProbePhase::ContextAndBatchCapsBound,
        SmallCompressedOwnerApprovedProbePhase::MemoryBeforeSampleRequired,
        SmallCompressedOwnerApprovedProbePhase::MemoryAfterSampleRequired,
        SmallCompressedOwnerApprovedProbePhase::FirstTokenRedactionRequired,
        SmallCompressedOwnerApprovedProbePhase::CancellationDeadlineBound,
        SmallCompressedOwnerApprovedProbePhase::AbstentionBound,
        SmallCompressedOwnerApprovedProbePhase::RollbackBound,
        SmallCompressedOwnerApprovedProbePhase::RunEventLogBound,
        SmallCompressedOwnerApprovedProbePhase::AnswerPacketBound,
        SmallCompressedOwnerApprovedProbePhase::NonPromotionBound,
        SmallCompressedOwnerApprovedProbePhase::LargerModelEscalationBlocked,
    ];
    let id = "small_compressed_owner_approved_probe_e2b_v1";
    SmallCompressedOwnerApprovedRuntimeProbe {
        probe_id: id.to_string(),
        selected_candidate_id: SELECTED_E2B_CANDIDATE.to_string(),
        model_id: E2B_MODEL_ID.to_string(),
        required_filename: REQUIRED_FILENAME.to_string(),
        command_path: LLAMA_CLI_PATH.to_string(),
        command_template_args,
        forbidden_flags,
        required_phases,
        owner_approval_phrase: OWNER_APPROVAL_PHRASE.to_string(),
        status: SmallCompressedOwnerApprovedProbeStatus::OwnerApprovalPending,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
        bytes: SmallCompressedOwnerApprovedProbeByteLedger::metadata_only(
            4096, 2048, 1, 512, 8000, 4000,
        ),
        refs: SmallCompressedOwnerApprovedProbeRefs {
            upstream_envelope_ref:
                "artifact:small_compressed_model_runtime_probe_proof_envelope:result".to_string(),
            command_template_ref: format!(
                "command_template:small_compressed_owner_approved_probe:{id}"
            ),
            source_model_ref:
                "source:model:gemma4-e2b-qat-gguf:1894d1fc0a19d86697abd40483f5983c867df03f"
                    .to_string(),
            model_path_ref: "model_path:owner_approval_required:gemma-4-E2B_q4_0-it.gguf"
                .to_string(),
            owner_approval_ref: format!("owner_approval:pending:{id}"),
            prompt_hash_ref: "prompt_hash:synthetic_non_user:blake3:probe-e2b".to_string(),
            memory_ledger_ref: format!("memory_ledger:small_compressed_owner_approved_probe:{id}"),
            answer_packet_ref: format!("answer_packet:small_compressed_owner_approved_probe:{id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_owner_approved_probe:{id}"),
            rollback_ref: format!("rollback:small_compressed_owner_approved_probe:{id}"),
            cancellation_ref: format!("cancel:small_compressed_owner_approved_probe:{id}"),
            abstention_ref: format!("abstention:small_compressed_owner_approved_probe:{id}"),
            compatibility_fence_ref: format!("compat:small_compressed_owner_approved_probe:{id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_owner_approved_probe:{id}"),
            scaling_ladder_ref: "scaling_ladder:gemma_qat_local:e2b-e4b-12b".to_string(),
        },
        user_visible_summary:
            "Owner-approved E2B QAT GGUF one-token llama-cli probe, fail-closed: owner approval is \
             pending, no real model path is bound, the command is unarmed, and execution + \
             first-token are blocked. The visible /opt/homebrew/bin/llama-cli template stays \
             offline, one-token, context/batch capped, no-mmap, and network-free; memory \
             before/after sampling, first-token redaction, cancellation, abstention, rollback, \
             RunEventLog, and AnswerPacket are required before any run. Larger models stay gated \
             and no product/MAS promotion is claimed."
                .to_string(),
        command_template_visible: true,
        cli_help_surface_visible: true,
        model_path_status_visible: true,
        memory_sampling_plan_visible: true,
        answer_packet_schema_visible: true,
        scaling_ladder_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        real_model_path_bound: false,
        download_executed: false,
        command_armed: false,
        command_executed: false,
        inference_executed: false,
        first_token_observed: false,
        retained_token_digest_recorded: false,
        memory_before_sample_recorded: false,
        memory_after_sample_recorded: false,
        answer_packet_required: true,
        run_event_log_required: true,
        rollback_required: true,
        cancellation_required: true,
        abstention_required: true,
        memory_ledger_required: true,
        quality_claimed: false,
        l2_capability_claimed: false,
        l3_wrv_claimed: false,
        mas_readiness_claimed: false,
        route_policy_mutated: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        provider_fallback_allowed: false,
        server_sidecar_default_allowed: false,
        hf_or_url_download_allowed: false,
        multi_token_or_unbounded_generation_allowed: false,
        e4b_requires_new_probe: true,
        twelve_b_requires_memory_repreflight: true,
        thirty_one_b_vault_only: true,
        seventy_b_cold_assembly_only: true,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

/// The canonical fail-closed owner-approved probe set bound to the proof envelope.
pub fn canonical_small_compressed_owner_approved_runtime_probe_set(
    created_at_ms: u64,
) -> SmallCompressedOwnerApprovedRuntimeProbeSet {
    let probe = canonical_small_compressed_owner_approved_runtime_probe();
    let probe_id = probe.probe_id.clone();
    let upstream = UasAddress::new(
        UasKind::Other("small_compressed_model_runtime_probe_proof_envelope".to_string()),
        b"small-compressed-owner-approved-probe-upstream-envelope",
        created_at_ms,
    );
    SmallCompressedOwnerApprovedRuntimeProbeSet::from_proof_envelope(
        upstream,
        "artifact:small_compressed_model_runtime_probe_proof_envelope:result",
        probe_id,
        vec![probe],
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        8192,
        true,
        true,
        true,
        created_at_ms,
    )
    .expect("canonical owner-approved probe set is valid")
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_120_000_000;

    #[test]
    fn canonical_probe_set_is_valid_and_fail_closed() {
        let set = canonical_small_compressed_owner_approved_runtime_probe_set(CREATED_AT_MS);
        assert_eq!(set.probes.len(), 1);
        let probe = &set.probes[0];
        assert_eq!(
            probe.status,
            SmallCompressedOwnerApprovedProbeStatus::OwnerApprovalPending
        );
        assert!(!probe.owner_approval_granted);
        assert!(!probe.command_armed);
        assert!(!probe.command_executed);
        assert!(!probe.first_token_observed);
        assert_eq!(probe.pro_status, ProStatus::ResearchCandidate);
        assert_eq!(set.metrics().model_bytes_loaded, 0);
        assert_eq!(set.metrics().runtime_bytes_loaded, 0);
        assert_eq!(set.metrics().provider_calls_made, 0);
        assert_eq!(set.metrics().retained_token_budget, 1);
        assert!(!set.set_address.to_string().is_empty());
    }

    #[test]
    fn next_cursor_is_the_owner_gated_first_token_frontier() {
        assert_eq!(
            SMALL_COMPRESSED_MODEL_OWNER_APPROVED_RUNTIME_PROBE_NEXT_CURSOR,
            "small_compressed_model_owner_approved_runtime_probe_first_token_owner_gated_frontier"
        );
    }

    #[test]
    fn granting_approval_or_arming_is_rejected() {
        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.owner_approval_granted = true;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.command_armed = true;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.command_executed = true;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.first_token_observed = true;
        assert!(validate_probe(&probe).is_err());
    }

    #[test]
    fn loading_bytes_or_provider_calls_is_rejected() {
        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.bytes.model_bytes_loaded = 1;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.bytes.provider_calls_made = 1;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.bytes.retained_token_budget = 2;
        assert!(validate_probe(&probe).is_err());
    }

    #[test]
    fn forbidden_flags_or_promotion_overclaims_are_rejected() {
        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.command_template_args.push("--server".to_string());
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.hidden_cloud_fallback_allowed = true;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.l3_wrv_claimed = true;
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.live_dense_70b_claimed = true;
        assert!(validate_probe(&probe).is_err());
    }

    #[test]
    fn wrong_model_or_command_path_is_rejected() {
        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
        assert!(validate_probe(&probe).is_err());

        let mut probe = canonical_small_compressed_owner_approved_runtime_probe();
        probe.command_path = "/opt/homebrew/bin/llama-server".to_string();
        assert!(validate_probe(&probe).is_err());
    }
}
