//! Gemma QAT E2B owner-approved first-token runtime probe contract.
//!
//! This primitive consumes the E2B model-file and llama.cpp digest gate and
//! defines the next fail-closed contract for a future one-token local probe. It
//! is still metadata-only: owner approval is pending, no local path is opened,
//! no command is armed or executed, no token is observed, and no Gemma product
//! capability is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_ID,
    GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF, GEMMA_QAT_E2B_SOURCE_REVISION,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH, GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME,
    GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_ID: &str =
    "F-GemmaQATE2BOwnerApprovedFirstTokenRuntimeProbe";
pub const GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_CURSOR: &str =
    "gemma_qat_e2b_owner_approved_first_token_runtime_probe";
pub const GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate";
pub const GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_e2b_model_file_and_llama_cpp_digest_gate/result.json#F-GemmaQATE2BModelFileAndLlamaCppDigestGate";

const UPSTREAM_MODEL_FILE_DIGEST_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_model_file_and_llama_cpp_digest_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_owner_approved_first_token_runtime_probe/";
const PROBE_CARD_ID: &str = "gemma-e2b-gguf-owner-approved-first-token-runtime-probe";
const MAX_METADATA_BYTES: u64 = 256 * 1024;

const REQUIRED_PROBE_FIELDS: &[&str] = &[
    "upstream_model_file_llama_cpp_digest_gate",
    "owner_approval_digest",
    "owner_manifest_digest",
    "canonical_path_digest",
    "model_file_sha256",
    "model_file_size_bytes",
    "llama_cpp_binary_sha256",
    "llama_cpp_version_digest",
    "command_template_digest",
    "resolved_argv_digest",
    "working_directory_digest",
    "environment_allowlist_digest",
    "synthetic_prompt_digest",
    "prompt_redaction_policy_digest",
    "first_token_digest_after_success",
    "first_token_shape_digest_after_success",
    "stdout_stderr_digest_after_success",
    "memory_before_digest",
    "memory_load_start_digest",
    "memory_first_token_digest",
    "memory_teardown_digest",
    "duration_digest",
    "exit_status_digest",
    "timeout_cancel_digest",
    "teardown_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "abstention_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "owner_approval_missing",
    "owner_manifest_digest_missing",
    "canonical_path_digest_missing",
    "model_digest_missing_or_mismatch",
    "model_file_size_mismatch",
    "llama_cpp_binary_digest_missing_or_mismatch",
    "llama_cpp_version_digest_missing",
    "command_template_digest_missing",
    "forbidden_network_flag_present",
    "forbidden_server_flag_present",
    "forbidden_download_flag_present",
    "forbidden_mmap_or_prefill_stress_present",
    "raw_path_prompt_output_or_stdio_retained",
    "memory_sample_missing",
    "timeout_without_cancel",
    "teardown_missing",
    "nonzero_exit_without_abstention",
    "first_token_missing_after_success",
    "run_event_log_missing",
    "answer_packet_missing",
    "rollback_missing",
    "route_mutation_detected",
    "hidden_cloud_or_provider_detected",
    "gemma_default_promotion_attempted",
    "larger_model_bypass_attempted",
    "live_dense_70b_claim_attempted",
    "ssd_as_ram_claim_attempted",
];

const REQUIRED_COMMAND_ARGS: &[&str] = &[
    "/opt/homebrew/bin/llama-cli",
    "model:<OWNER_APPROVED_E2B_GGUF_PATH>",
    "prompt:<SYNTHETIC_NON_USER_PROMPT>",
    "predict:1",
    "ctx-size:512",
    "batch-size:32",
    "ubatch-size:32",
    "temp:0",
    "seed:0",
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
    "--host",
    "--port",
    "--conversation",
    "--mmap",
    "--ctx-size 8192",
    "--predict -1",
];

// UAS: uas:gemma-qat-e2b-owner-approved-first-token-runtime-probe:status
// Plane: Verification.
// Residency: owner approval pending; no runtime bytes are loaded.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeStatus {
    OwnerApprovalPending,
}

// UAS: uas:gemma-qat-e2b-owner-approved-first-token-runtime-probe:spec
// Plane: Controller + Verification.
// Residency: future one-token local runtime probe contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe {
    pub upstream_model_file_digest_gate_ref: String,
    pub upstream_gate_id: String,
    pub upstream_owner_manifest_digest_ref: String,
    pub artifact_root_prefix: String,
    pub probe_card_id: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_probe_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub required_command_args: Vec<String>,
    pub forbidden_command_args: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub owner_manifest_digest_bound: bool,
    pub canonical_path_digest_bound: bool,
    pub model_file_digest_bound: bool,
    pub model_file_size_bound: bool,
    pub llama_cpp_binary_digest_bound: bool,
    pub llama_cpp_version_digest_bound: bool,
    pub command_template_digest_bound: bool,
    pub command_template_visible: bool,
    pub offline_mode_required: bool,
    pub synthetic_prompt_required: bool,
    pub raw_path_retention_allowed: bool,
    pub raw_prompt_retention_allowed: bool,
    pub raw_output_retention_allowed: bool,
    pub stdout_stderr_retention_allowed: bool,
    pub memory_before_required: bool,
    pub memory_load_start_required: bool,
    pub memory_first_token_required: bool,
    pub memory_teardown_required: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub teardown_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub path_canonicalization_attempts: u64,
    pub file_stat_attempts: u64,
    pub file_hash_attempts: u64,
    pub model_file_opened: bool,
    pub llama_cpp_binary_opened: bool,
    pub llama_cpp_version_executions: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
    pub first_token_observed: bool,
    pub network_access_allowed: bool,
    pub server_mode_allowed: bool,
    pub download_allowed: bool,
    pub mmap_or_prefill_stress_allowed: bool,
    pub provider_route_enabled: bool,
    pub captured_raw_path_bytes: u64,
    pub captured_raw_prompt_bytes: u64,
    pub captured_raw_output_bytes: u64,
    pub captured_stdout_bytes: u64,
    pub captured_stderr_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub product_route_green: bool,
    pub live_gemma_default_claim: bool,
    pub e4b_or_12b_bypass_allowed: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub metadata_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe {
    pub fn canonical(upstream_model_file_digest_gate_ref: impl Into<String>) -> Self {
        Self {
            upstream_model_file_digest_gate_ref: upstream_model_file_digest_gate_ref.into(),
            upstream_gate_id: GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_ID.to_string(),
            upstream_owner_manifest_digest_ref:
                GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            probe_card_id: PROBE_CARD_ID.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_probe_fields: REQUIRED_PROBE_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_command_args: REQUIRED_COMMAND_ARGS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            forbidden_command_args: FORBIDDEN_COMMAND_ARGS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_required: true,
            owner_approval_granted: false,
            owner_manifest_digest_bound: true,
            canonical_path_digest_bound: true,
            model_file_digest_bound: true,
            model_file_size_bound: true,
            llama_cpp_binary_digest_bound: true,
            llama_cpp_version_digest_bound: true,
            command_template_digest_bound: true,
            command_template_visible: true,
            offline_mode_required: true,
            synthetic_prompt_required: true,
            raw_path_retention_allowed: false,
            raw_prompt_retention_allowed: false,
            raw_output_retention_allowed: false,
            stdout_stderr_retention_allowed: false,
            memory_before_required: true,
            memory_load_start_required: true,
            memory_first_token_required: true,
            memory_teardown_required: true,
            timeout_bound: true,
            cancellation_bound: true,
            teardown_bound: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            path_canonicalization_attempts: 0,
            file_stat_attempts: 0,
            file_hash_attempts: 0,
            model_file_opened: false,
            llama_cpp_binary_opened: false,
            llama_cpp_version_executions: 0,
            command_armed: false,
            command_executed: false,
            runtime_replay_performed: false,
            first_token_observed: false,
            network_access_allowed: false,
            server_mode_allowed: false,
            download_allowed: false,
            mmap_or_prefill_stress_allowed: false,
            provider_route_enabled: false,
            captured_raw_path_bytes: 0,
            captured_raw_prompt_bytes: 0,
            captured_raw_output_bytes: 0,
            captured_stdout_bytes: 0,
            captured_stderr_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            product_route_green: false,
            live_gemma_default_claim: false,
            e4b_or_12b_bypass_allowed: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            metadata_bytes: 128_000,
            rollback_ref: "rollback:gemma_qat_e2b_owner_approved_first_token_runtime_probe"
                .to_string(),
            run_event_log_ref:
                "run_event_log:gemma_qat_e2b_owner_approved_first_token_runtime_probe".to_string(),
            answer_packet_ref:
                "answer_packet:gemma_qat_e2b_owner_approved_first_token_runtime_probe".to_string(),
            abstention_ref: "abstention:gemma_qat_e2b_owner_approved_first_token_runtime_probe"
                .to_string(),
            status: GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeStatus::OwnerApprovalPending,
            next_cursor: GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError> {
        if !self
            .upstream_model_file_digest_gate_ref
            .starts_with(UPSTREAM_MODEL_FILE_DIGEST_PREFIX)
            || self.upstream_gate_id != GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_ID
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_owner_manifest_digest_ref",
            &self.upstream_owner_manifest_digest_ref,
            GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
        )?;
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("probe_card_id", &self.probe_card_id, PROBE_CARD_ID)?;
        validate_unique_exact_set(
            "required_probe_fields",
            &self.required_probe_fields,
            REQUIRED_PROBE_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        validate_unique_exact_set(
            "required_command_args",
            &self.required_command_args,
            REQUIRED_COMMAND_ARGS,
        )?;
        validate_unique_exact_set(
            "forbidden_command_args",
            &self.forbidden_command_args,
            FORBIDDEN_COMMAND_ARGS,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.source_revision != GEMMA_QAT_E2B_SOURCE_REVISION
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.expected_file_size_bytes != GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
            || self.command_path != GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeStatus::OwnerApprovalPending
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::UnsafeState);
        }
        if !self.owner_approval_required
            || self.owner_approval_granted
            || !self.owner_manifest_digest_bound
            || !self.canonical_path_digest_bound
            || !self.model_file_digest_bound
            || !self.model_file_size_bound
            || !self.llama_cpp_binary_digest_bound
            || !self.llama_cpp_version_digest_bound
            || !self.command_template_digest_bound
            || !self.command_template_visible
            || !self.offline_mode_required
            || !self.synthetic_prompt_required
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::ProofBoundaryBroken);
        }
        if self.raw_path_retention_allowed
            || self.raw_prompt_retention_allowed
            || self.raw_output_retention_allowed
            || self.stdout_stderr_retention_allowed
            || self.captured_raw_path_bytes != 0
            || self.captured_raw_prompt_bytes != 0
            || self.captured_raw_output_bytes != 0
            || self.captured_stdout_bytes != 0
            || self.captured_stderr_bytes != 0
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::PrivacyLeak);
        }
        if !self.memory_before_required
            || !self.memory_load_start_required
            || !self.memory_first_token_required
            || !self.memory_teardown_required
            || !self.timeout_bound
            || !self.cancellation_bound
            || !self.teardown_bound
            || !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::ProofBoundaryBroken);
        }
        if self.path_canonicalization_attempts != 0
            || self.file_stat_attempts != 0
            || self.file_hash_attempts != 0
            || self.model_file_opened
            || self.llama_cpp_binary_opened
            || self.llama_cpp_version_executions != 0
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::FileActionLeak);
        }
        if self.command_armed
            || self.command_executed
            || self.runtime_replay_performed
            || self.first_token_observed
            || self.network_access_allowed
            || self.server_mode_allowed
            || self.download_allowed
            || self.mmap_or_prefill_stress_allowed
            || self.provider_route_enabled
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::RuntimeActionLeak);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.product_route_green
            || self.live_gemma_default_claim
            || self.e4b_or_12b_bypass_allowed
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
            || self.quality_claimed
            || self.benchmark_claimed_as_fit
        {
            return Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::PromotionClaim);
        }
        validate_prefix("rollback_ref", &self.rollback_ref, "rollback:")?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            "run_event_log:",
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            "answer_packet:",
        )?;
        validate_prefix("abstention_ref", &self.abstention_ref, "abstention:")?;
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeMetrics {
        GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeMetrics {
            required_probe_field_count: self.required_probe_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            required_command_arg_count: self.required_command_args.len() as u64,
            forbidden_command_arg_count: self.forbidden_command_args.len() as u64,
            owner_approval_granted_count: self.owner_approval_granted as u64,
            file_action_count: self.path_canonicalization_attempts
                + self.file_stat_attempts
                + self.file_hash_attempts
                + self.model_file_opened as u64
                + self.llama_cpp_binary_opened as u64
                + self.llama_cpp_version_executions,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            runtime_replay_performed_count: self.runtime_replay_performed as u64,
            first_token_observed_count: self.first_token_observed as u64,
            captured_raw_path_bytes: self.captured_raw_path_bytes,
            captured_raw_prompt_bytes: self.captured_raw_prompt_bytes,
            captured_raw_output_bytes: self.captured_raw_output_bytes,
            captured_stdout_bytes: self.captured_stdout_bytes,
            captured_stderr_bytes: self.captured_stderr_bytes,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            forbidden_runtime_surface_count: (self.network_access_allowed as u64)
                + (self.server_mode_allowed as u64)
                + (self.download_allowed as u64)
                + (self.mmap_or_prefill_stress_allowed as u64)
                + (self.provider_route_enabled as u64),
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.product_route_green
                || self.live_gemma_default_claim
                || self.e4b_or_12b_bypass_allowed
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim
                || self.quality_claimed
                || self.benchmark_claimed_as_fit) as u64,
        }
    }

    pub fn probe_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_probe_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        let mut args = self.required_command_args.clone();
        args.sort();
        format!(
            "gemma-e2b-owner-approved-first-token-runtime-probe:v1:{}:{}:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_model_file_digest_gate_ref,
            self.selected_model_id,
            self.source_revision,
            self.required_filename,
            self.expected_file_size_bytes,
            self.command_path,
            fields.join(","),
            aborts.join(","),
            args.join(","),
            self.next_cursor,
        )
    }
}

// UAS: uas:gemma-qat-e2b-owner-approved-first-token-runtime-probe:metrics
// Plane: Verification.
// Residency: future probe counters and zero-action ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeMetrics {
    pub required_probe_field_count: u64,
    pub required_abort_condition_count: u64,
    pub required_command_arg_count: u64,
    pub forbidden_command_arg_count: u64,
    pub owner_approval_granted_count: u64,
    pub file_action_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub runtime_replay_performed_count: u64,
    pub first_token_observed_count: u64,
    pub captured_raw_path_bytes: u64,
    pub captured_raw_prompt_bytes: u64,
    pub captured_raw_output_bytes: u64,
    pub captured_stdout_bytes: u64,
    pub captured_stderr_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub forbidden_runtime_surface_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_owner_approved_first_token_runtime_probe_fields() -> Vec<String> {
    REQUIRED_PROBE_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_owner_approved_first_token_abort_conditions() -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-owner-approved-first-token-runtime-probe:error
// Plane: Verification.
// Residency: fail-closed probe diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    PrivacyLeak,
    FileActionLeak,
    RuntimeActionLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream model-file digest gate reference"),
            Self::BadSelectedLane => f.write_str("bad selected Gemma E2B runtime lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe first-token probe state"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::FileActionLeak => f.write_str("file action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    Ok(())
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    expected_prefix: &str,
) -> Result<(), GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::BadField(field_name))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_401_000_000;

    #[test]
    fn canonical_probe_validates_zero_runtime_actions() {
        let probe = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe::canonical(
            GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
        );
        probe.validate().expect("canonical probe should validate");
        let metrics = probe.metrics();
        assert_eq!(metrics.required_probe_field_count, 29);
        assert_eq!(metrics.required_abort_condition_count, 27);
        assert_eq!(metrics.required_command_arg_count, 14);
        assert_eq!(metrics.forbidden_command_arg_count, 11);
        assert_eq!(metrics.file_action_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.first_token_observed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn missing_required_fields_are_rejected() {
        let mut probe = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe::canonical(
            GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
        );
        probe.required_probe_fields.pop();
        assert!(matches!(
            probe.validate(),
            Err(
                GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbeError::DuplicateOrMissingField(
                    "required_probe_fields"
                )
            )
        ));
    }

    #[test]
    fn runtime_file_privacy_and_promotion_actions_are_rejected() {
        let mutations: Vec<Box<dyn Fn(&mut GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe)>> = vec![
            Box::new(|probe| probe.owner_approval_granted = true),
            Box::new(|probe| probe.model_file_opened = true),
            Box::new(|probe| probe.command_armed = true),
            Box::new(|probe| probe.runtime_replay_performed = true),
            Box::new(|probe| probe.first_token_observed = true),
            Box::new(|probe| probe.captured_raw_output_bytes = 1),
            Box::new(|probe| probe.product_route_green = true),
        ];
        for mutate in mutations {
            let mut probe = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe::canonical(
                GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
            );
            mutate(&mut probe);
            assert!(probe.validate().is_err());
        }
    }

    #[test]
    fn probe_gate_address_is_order_deterministic() {
        let probe = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe::canonical(
            GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe {
            required_probe_fields: probe.required_probe_fields.iter().cloned().rev().collect(),
            required_abort_conditions: probe
                .required_abort_conditions
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_command_args: probe.required_command_args.iter().cloned().rev().collect(),
            forbidden_command_args: probe.forbidden_command_args.iter().cloned().rev().collect(),
            ..probe.clone()
        };
        probe.validate().expect("canonical probe should validate");
        reversed.validate().expect("reversed sets should validate");
        assert_eq!(
            probe.probe_gate_address(CREATED_AT_MS),
            reversed.probe_gate_address(CREATED_AT_MS)
        );
    }
}
