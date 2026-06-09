//! Gemma direct harness first runtime proof command card.
//!
//! This primitive narrows the first owner-approved Gemma runtime proof to a
//! local GGUF `llama-cli -m <approved-file>` command card. It is metadata-only:
//! no command card is written, no process starts, no model path is opened, no
//! prompt/output bytes are retained, and no route/default is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID: &str =
    "F-GemmaDirectHarnessFirstRuntimeProofCommandCard";
pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_CURSOR: &str =
    "gemma_direct_harness_first_runtime_proof_command_card";
pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_NEXT_CURSOR: &str =
    "gemma_direct_harness_first_runtime_proof_receipt_gate";
pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate/result.json#F-GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate";

const UPSTREAM_ADMISSION_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_command_card/";
const COMMAND_CARD_ID: &str = "gemma-direct-harness-first-runtime-proof-command-card-v1";
const FUTURE_COMMAND_CARD_NAME: &str = "gemma-first-runtime-proof-local-gguf-command-card-v1";
const RUNTIME_LANE: &str = "gemma-direct-harness-llama-cpp-gguf-pro-gated";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const MAX_METADATA_BYTES: u64 = 384 * 1024;
const MAX_CTX_SIZE: u64 = 8_192;
const MAX_PREDICT_TOKENS: u64 = 512;
const MAX_STDIO_CAPTURE_BYTES: u64 = 64 * 1024;

const REQUIRED_COMMAND_CARD_FIELDS: &[&str] = &[
    "upstream_admission_packet_digest",
    "owner_approval_digest",
    "selected_model_uas_address",
    "model_file_sha256",
    "model_file_byte_count",
    "redacted_model_path_digest",
    "llama_cli_binary_sha256",
    "llama_cli_version_digest",
    "runtime_lane_digest",
    "argv_vector_digest",
    "local_model_flag_digest",
    "single_turn_flag_digest",
    "no_display_prompt_flag_digest",
    "show_timings_flag_digest",
    "ctx_size_bound_digest",
    "predict_bound_digest",
    "seed_digest",
    "optional_grammar_or_json_digest",
    "prompt_sha256",
    "prompt_template_digest",
    "timeout_ms_digest",
    "cancellation_digest",
    "teardown_digest",
    "stdout_stderr_cap_digest",
    "redaction_map_digest",
    "first_token_digest_policy",
    "memory_sampler_digest",
    "scope_rex_ref",
    "sovereign_gate_ref",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "no_route_mutation_digest",
    "no_default_mutation_digest",
    "non_promotion_digest",
];

const ALLOWED_ARGV_FLAGS: &[&str] = &[
    "llama-cli",
    "-m",
    "--single-turn",
    "--no-display-prompt",
    "--show-timings",
    "--ctx-size",
    "--predict",
    "--seed",
    "--grammar-file",
    "--json-schema",
    "--temp",
    "--top-p",
    "--top-k",
    "--repeat-penalty",
    "--threads",
    "--n-gpu-layers",
];

const DENIED_ARGV_FLAGS: &[&str] = &[
    "-hf",
    "--hf-repo",
    "--hf-file",
    "--model-url",
    "--url",
    "--host",
    "--port",
    "llama-server",
    "--server",
    "--endpoint",
    "--api-key",
    "--predict=-1",
    "--ignore-eos",
    "--draft-model",
    "--draft",
    "--mtp",
    "--lora",
    "--control-vector",
    "MODEL_ENDPOINT",
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
];

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "command_card_digest",
    "exit_status_digest",
    "termination_reason_digest",
    "timeout_or_cancel_digest",
    "teardown_digest",
    "timing_digest",
    "memory_sample_digest",
    "stdout_digest",
    "stderr_digest",
    "first_token_digest",
    "prompt_digest",
    "redaction_proof_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "non_promotion_digest",
];

// UAS: uas:gemma-direct-harness-first-runtime-proof-command-card:status
// Plane: Controller + Verification.
// Residency: command-card contract only; zero runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessFirstRuntimeProofCommandCardStatus {
    CommandCardContractOnly,
}

// UAS: uas:gemma-direct-harness-first-runtime-proof-command-card:spec
// Plane: Controller + Verification.
// Residency: future owner-approved local GGUF command card only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessFirstRuntimeProofCommandCard {
    pub upstream_admission_ref: String,
    pub upstream_admission_id: String,
    pub artifact_root_prefix: String,
    pub command_card_id: String,
    pub future_command_card_name: String,
    pub runtime_lane: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_command_card_fields: Vec<String>,
    pub allowed_argv_flags: Vec<String>,
    pub denied_argv_flags: Vec<String>,
    pub required_receipt_fields: Vec<String>,
    pub owner_approval_required: bool,
    pub selected_model_uas_address_required: bool,
    pub local_model_file_required: bool,
    pub model_path_redacted: bool,
    pub llama_cli_identity_required: bool,
    pub local_m_flag_required: bool,
    pub single_turn_required: bool,
    pub no_display_prompt_required: bool,
    pub show_timings_required: bool,
    pub ctx_size_bound: u64,
    pub predict_token_bound: u64,
    pub fixed_seed_required: bool,
    pub prompt_digest_required: bool,
    pub grammar_or_json_digest_only: bool,
    pub timeout_cancel_teardown_required: bool,
    pub stdio_capture_cap_bytes: u64,
    pub raw_stdio_denied: bool,
    pub first_token_digest_only: bool,
    pub memory_sampler_required: bool,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_required: bool,
    pub command_card_written_count: u64,
    pub command_card_bytes_written: u64,
    pub command_card_bytes_read: u64,
    pub owner_path_open_count: u64,
    pub model_file_opened: bool,
    pub llama_cli_opened: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
    pub server_started: bool,
    pub network_allowed: bool,
    pub hub_download_allowed: bool,
    pub remote_endpoint_allowed: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_model_path_bytes: u64,
    pub raw_prompt_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_or_default_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub quality_claimed: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub t4_build_green_effect: bool,
    pub live_gemma_default_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub status: GemmaDirectHarnessFirstRuntimeProofCommandCardStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessFirstRuntimeProofCommandCard {
    pub fn canonical() -> Self {
        Self {
            upstream_admission_ref:
                GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_UPSTREAM_REF.to_string(),
            upstream_admission_id:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID
                    .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            command_card_id: COMMAND_CARD_ID.to_string(),
            future_command_card_name: FUTURE_COMMAND_CARD_NAME.to_string(),
            runtime_lane: RUNTIME_LANE.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_command_card_fields: REQUIRED_COMMAND_CARD_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            allowed_argv_flags: ALLOWED_ARGV_FLAGS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            denied_argv_flags: DENIED_ARGV_FLAGS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_required: true,
            selected_model_uas_address_required: true,
            local_model_file_required: true,
            model_path_redacted: true,
            llama_cli_identity_required: true,
            local_m_flag_required: true,
            single_turn_required: true,
            no_display_prompt_required: true,
            show_timings_required: true,
            ctx_size_bound: MAX_CTX_SIZE,
            predict_token_bound: MAX_PREDICT_TOKENS,
            fixed_seed_required: true,
            prompt_digest_required: true,
            grammar_or_json_digest_only: true,
            timeout_cancel_teardown_required: true,
            stdio_capture_cap_bytes: MAX_STDIO_CAPTURE_BYTES,
            raw_stdio_denied: true,
            first_token_digest_only: true,
            memory_sampler_required: true,
            scope_rex_ref: "scope_rex:gemma_first_runtime_proof_command_card".to_string(),
            sovereign_gate_ref: "sovereign_gate:gemma_first_runtime_proof_command_card".to_string(),
            rollback_ref: "rollback:gemma_first_runtime_proof_command_card".to_string(),
            run_event_log_ref: "run_event_log:gemma_first_runtime_proof_command_card".to_string(),
            answer_packet_ref: "answer_packet:gemma_first_runtime_proof_command_card".to_string(),
            abstention_required: true,
            command_card_written_count: 0,
            command_card_bytes_written: 0,
            command_card_bytes_read: 0,
            owner_path_open_count: 0,
            model_file_opened: false,
            llama_cli_opened: false,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
            server_started: false,
            network_allowed: false,
            hub_download_allowed: false,
            remote_endpoint_allowed: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_model_path_bytes: 0,
            raw_prompt_bytes: 0,
            raw_stdout_bytes: 0,
            raw_stderr_bytes: 0,
            raw_token_bytes: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_or_default_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            quality_claimed: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            t4_build_green_effect: false,
            live_gemma_default_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: 288_000,
            status: GemmaDirectHarnessFirstRuntimeProofCommandCardStatus::CommandCardContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessFirstRuntimeProofCommandCardError> {
        if !self
            .upstream_admission_ref
            .starts_with(UPSTREAM_ADMISSION_PREFIX)
            || self.upstream_admission_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("command_card_id", &self.command_card_id, COMMAND_CARD_ID)?;
        validate_exact(
            "future_command_card_name",
            &self.future_command_card_name,
            FUTURE_COMMAND_CARD_NAME,
        )?;
        validate_exact("runtime_lane", &self.runtime_lane, RUNTIME_LANE)?;
        validate_unique_exact_set(
            "required_command_card_fields",
            &self.required_command_card_fields,
            REQUIRED_COMMAND_CARD_FIELDS,
        )?;
        validate_unique_exact_set(
            "allowed_argv_flags",
            &self.allowed_argv_flags,
            ALLOWED_ARGV_FLAGS,
        )?;
        validate_unique_exact_set(
            "denied_argv_flags",
            &self.denied_argv_flags,
            DENIED_ARGV_FLAGS,
        )?;
        validate_unique_exact_set(
            "required_receipt_fields",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessFirstRuntimeProofCommandCardStatus::CommandCardContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::UnsafeState);
        }
        if !self.owner_approval_required
            || !self.selected_model_uas_address_required
            || !self.local_model_file_required
            || !self.model_path_redacted
            || !self.llama_cli_identity_required
            || !self.local_m_flag_required
            || !self.single_turn_required
            || !self.no_display_prompt_required
            || !self.show_timings_required
            || self.ctx_size_bound == 0
            || self.ctx_size_bound > MAX_CTX_SIZE
            || self.predict_token_bound == 0
            || self.predict_token_bound > MAX_PREDICT_TOKENS
            || !self.fixed_seed_required
            || !self.prompt_digest_required
            || !self.grammar_or_json_digest_only
            || !self.timeout_cancel_teardown_required
            || self.stdio_capture_cap_bytes == 0
            || self.stdio_capture_cap_bytes > MAX_STDIO_CAPTURE_BYTES
            || !self.raw_stdio_denied
            || !self.first_token_digest_only
            || !self.memory_sampler_required
            || !self.abstention_required
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::ProofBoundaryBroken);
        }
        validate_prefix("scope_rex_ref", &self.scope_rex_ref, SCOPE_REX_PREFIX)?;
        validate_prefix(
            "sovereign_gate_ref",
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
        )?;
        validate_prefix("rollback_ref", &self.rollback_ref, ROLLBACK_PREFIX)?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )?;
        if self.command_card_written_count != 0
            || self.command_card_bytes_written != 0
            || self.command_card_bytes_read != 0
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::CommandCardActionLeak);
        }
        if self.owner_path_open_count != 0
            || self.model_file_opened
            || self.llama_cli_opened
            || self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.server_started
            || self.network_allowed
            || self.hub_download_allowed
            || self.remote_endpoint_allowed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::RuntimeActionLeak);
        }
        if self.raw_model_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::PrivacyLeak);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_or_default_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.quality_claimed
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.t4_build_green_effect
            || self.live_gemma_default_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessFirstRuntimeProofCommandCardMetrics {
        GemmaDirectHarnessFirstRuntimeProofCommandCardMetrics {
            required_command_card_field_count: self.required_command_card_fields.len() as u64,
            allowed_argv_flag_count: self.allowed_argv_flags.len() as u64,
            denied_argv_flag_count: self.denied_argv_flags.len() as u64,
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            ctx_size_bound: self.ctx_size_bound,
            predict_token_bound: self.predict_token_bound,
            stdio_capture_cap_bytes: self.stdio_capture_cap_bytes,
            command_card_written_count: self.command_card_written_count,
            command_card_bytes_written: self.command_card_bytes_written,
            command_card_bytes_read: self.command_card_bytes_read,
            owner_path_open_count: self.owner_path_open_count,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
            server_started_count: self.server_started as u64,
            network_or_hub_or_endpoint_count: (self.network_allowed
                || self.hub_download_allowed
                || self.remote_endpoint_allowed)
                as u64,
            file_open_count: (self.model_file_opened || self.llama_cli_opened) as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_private_bytes: self.raw_model_path_bytes
                + self.raw_prompt_bytes
                + self.raw_stdout_bytes
                + self.raw_stderr_bytes
                + self.raw_token_bytes,
            mutation_count: (self.runtime_router_mutation_allowed
                || self.system_g_mutation_allowed
                || self.settings_or_default_mutation_allowed) as u64,
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.quality_claimed
                || self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.t4_build_green_effect
                || self.live_gemma_default_claim
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn command_card_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_command_card_fields.clone();
        fields.sort();
        let mut allowed = self.allowed_argv_flags.clone();
        allowed.sort();
        let mut denied = self.denied_argv_flags.clone();
        denied.sort();
        let mut receipt = self.required_receipt_fields.clone();
        receipt.sort();
        format!(
            "gemma-first-runtime-proof-command-card:v1:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_admission_ref,
            self.upstream_admission_id,
            self.runtime_lane,
            fields.join(","),
            allowed.join(","),
            denied.join(","),
            receipt.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-first-runtime-proof-command-card:metrics
// Plane: Verification.
// Residency: zero-action command-card counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessFirstRuntimeProofCommandCardMetrics {
    pub required_command_card_field_count: u64,
    pub allowed_argv_flag_count: u64,
    pub denied_argv_flag_count: u64,
    pub required_receipt_field_count: u64,
    pub ctx_size_bound: u64,
    pub predict_token_bound: u64,
    pub stdio_capture_cap_bytes: u64,
    pub command_card_written_count: u64,
    pub command_card_bytes_written: u64,
    pub command_card_bytes_read: u64,
    pub owner_path_open_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub server_started_count: u64,
    pub network_or_hub_or_endpoint_count: u64,
    pub file_open_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_private_bytes: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_first_runtime_proof_command_card_fields() -> Vec<String> {
    REQUIRED_COMMAND_CARD_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn allowed_gemma_direct_harness_first_runtime_proof_argv_flags() -> Vec<String> {
    ALLOWED_ARGV_FLAGS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn denied_gemma_direct_harness_first_runtime_proof_argv_flags() -> Vec<String> {
    DENIED_ARGV_FLAGS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_first_runtime_proof_receipt_fields() -> Vec<String> {
    REQUIRED_RECEIPT_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-first-runtime-proof-command-card:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessFirstRuntimeProofCommandCardError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    CommandCardActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessFirstRuntimeProofCommandCardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream admission packet reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe first runtime proof command-card state"),
            Self::ProofBoundaryBroken => f.write_str("first runtime proof boundary broken"),
            Self::CommandCardActionLeak => f.write_str("command-card action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessFirstRuntimeProofCommandCardError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessFirstRuntimeProofCommandCardError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessFirstRuntimeProofCommandCardError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessFirstRuntimeProofCommandCardError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    Ok(())
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaDirectHarnessFirstRuntimeProofCommandCardError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::BadField(field_name))
    }
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    prefix: &str,
) -> Result<(), GemmaDirectHarnessFirstRuntimeProofCommandCardError> {
    if actual.starts_with(prefix) {
        Ok(())
    } else {
        Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_840_000_000;

    #[test]
    fn canonical_command_card_validates_zero_actions() {
        let card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.validate()
            .expect("canonical first runtime proof command card should validate");
        let metrics = card.metrics();
        assert_eq!(metrics.required_command_card_field_count, 36);
        assert_eq!(metrics.allowed_argv_flag_count, 16);
        assert_eq!(metrics.denied_argv_flag_count, 21);
        assert_eq!(metrics.required_receipt_field_count, 16);
        assert_eq!(metrics.ctx_size_bound, MAX_CTX_SIZE);
        assert_eq!(metrics.predict_token_bound, MAX_PREDICT_TOKENS);
        assert_eq!(metrics.command_card_written_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.process_spawned_count, 0);
        assert_eq!(metrics.network_or_hub_or_endpoint_count, 0);
        assert_eq!(metrics.raw_private_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_allowlist_and_denylist_items_are_rejected() {
        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.allowed_argv_flags[0] = card.allowed_argv_flags[1].clone();
        assert!(matches!(
            card.validate(),
            Err(
                GemmaDirectHarnessFirstRuntimeProofCommandCardError::DuplicateOrMissingField(
                    "allowed_argv_flags"
                )
            )
        ));

        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.denied_argv_flags[0] = card.denied_argv_flags[1].clone();
        assert!(matches!(
            card.validate(),
            Err(
                GemmaDirectHarnessFirstRuntimeProofCommandCardError::DuplicateOrMissingField(
                    "denied_argv_flags"
                )
            )
        ));
    }

    #[test]
    fn unbounded_or_remote_runtime_policy_is_rejected() {
        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.predict_token_bound = 0;
        assert!(matches!(
            card.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::ProofBoundaryBroken)
        ));

        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.hub_download_allowed = true;
        assert!(matches!(
            card.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn command_or_private_bytes_or_promotion_are_rejected() {
        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.command_card_bytes_written = 1;
        assert!(matches!(
            card.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::CommandCardActionLeak)
        ));

        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.raw_stdout_bytes = 1;
        assert!(matches!(
            card.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::PrivacyLeak)
        ));

        let mut card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        card.live_gemma_default_claim = true;
        assert!(matches!(
            card.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofCommandCardError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
        let reversed = GemmaDirectHarnessFirstRuntimeProofCommandCard {
            required_command_card_fields: card
                .required_command_card_fields
                .iter()
                .cloned()
                .rev()
                .collect(),
            allowed_argv_flags: card.allowed_argv_flags.iter().cloned().rev().collect(),
            denied_argv_flags: card.denied_argv_flags.iter().cloned().rev().collect(),
            required_receipt_fields: card.required_receipt_fields.iter().cloned().rev().collect(),
            ..card.clone()
        };
        assert_eq!(
            card.command_card_address(CREATED_AT_MS),
            reversed.command_card_address(CREATED_AT_MS)
        );
    }
}
