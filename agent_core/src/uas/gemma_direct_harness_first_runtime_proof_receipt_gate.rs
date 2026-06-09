//! Gemma direct harness first runtime proof receipt gate.
//!
//! This primitive consumes the first-runtime command-card contract and freezes
//! the digest-only receipt shape required before a future owner-approved local
//! Gemma execution probe can count as evidence. It is metadata-only: no receipt
//! is written or read, no command is armed, no process starts, no model path is
//! opened, no raw prompt/output/token bytes are retained, and no route/default
//! is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID,
};

pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_ID: &str =
    "F-GemmaDirectHarnessFirstRuntimeProofReceiptGate";
pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_CURSOR: &str =
    "gemma_direct_harness_first_runtime_proof_receipt_gate";
pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_first_runtime_proof_command_card/result.json#F-GemmaDirectHarnessFirstRuntimeProofCommandCard";

const UPSTREAM_COMMAND_CARD_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_first_runtime_proof_command_card/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_receipt_gate/";
const RECEIPT_GATE_ID: &str = "gemma-direct-harness-first-runtime-proof-receipt-gate-v1";
const FUTURE_RECEIPT_NAME: &str = "gemma-first-runtime-proof-redacted-receipt-v1";
const RUNTIME_LANE: &str = "gemma-direct-harness-llama-cpp-gguf-pro-gated";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const REVIEW_PREFIX: &str = "reviewer_summary:";
const MAX_METADATA_BYTES: u64 = 384 * 1024;
const MAX_STDIO_CAPTURE_BYTES: u64 = 64 * 1024;

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "upstream_command_card_artifact_digest",
    "receipt_schema_version",
    "command_card_digest",
    "owner_approval_digest",
    "selected_model_uas_address",
    "model_file_sha256",
    "model_file_byte_count",
    "redacted_model_path_digest",
    "llama_cli_binary_sha256",
    "llama_cli_version_digest",
    "argv_vector_digest",
    "environment_digest",
    "working_directory_digest",
    "exit_status_digest",
    "termination_reason_digest",
    "timeout_or_cancel_digest",
    "teardown_digest",
    "timing_digest",
    "memory_sample_digest",
    "stdout_digest",
    "stderr_digest",
    "first_token_digest",
    "redacted_output_digest",
    "prompt_digest",
    "redaction_proof_digest",
    "stdout_stderr_cap_digest",
    "raw_byte_zero_proof_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary_digest",
    "no_quality_claim_digest",
    "no_route_admission_digest",
    "non_promotion_digest",
];

const REQUIRED_TERMINATION_CLASSES: &[&str] = &[
    "completed_success",
    "completed_nonzero_exit",
    "timed_out",
    "cancelled_by_owner",
    "terminated_by_signal",
    "teardown_failed",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_command_card",
    "missing_receipt_schema_version",
    "missing_command_card_digest",
    "missing_owner_approval",
    "missing_selected_model_uas_address",
    "missing_model_file_sha256",
    "missing_model_file_byte_count",
    "missing_redacted_model_path_digest",
    "missing_llama_cli_binary_sha256",
    "missing_llama_cli_version_digest",
    "missing_argv_vector_digest",
    "missing_environment_digest",
    "missing_working_directory_digest",
    "missing_exit_status_digest",
    "missing_termination_reason_digest",
    "missing_timeout_or_cancel_digest",
    "missing_teardown_digest",
    "missing_timing_digest",
    "missing_memory_sample_digest",
    "missing_stdout_digest",
    "missing_stderr_digest",
    "missing_first_token_digest",
    "missing_redacted_output_digest",
    "missing_prompt_digest",
    "missing_redaction_proof_digest",
    "missing_stdout_stderr_cap_digest",
    "missing_raw_byte_zero_proof_digest",
    "missing_rollback_ref",
    "missing_run_event_log_ref",
    "missing_answer_packet_ref",
    "missing_abstention_ref",
    "missing_reviewer_visible_summary",
    "missing_no_quality_claim",
    "missing_no_route_admission",
    "missing_non_promotion",
    "receipt_written",
    "receipt_read",
    "owner_path_opened",
    "model_file_opened",
    "llama_cli_opened",
    "command_card_read",
    "command_armed",
    "command_executed",
    "process_spawned",
    "server_started",
    "network_allowed",
    "hub_download_allowed",
    "remote_endpoint_allowed",
    "raw_model_path_retained",
    "raw_prompt_retained",
    "raw_output_retained",
    "raw_stdout_retained",
    "raw_stderr_retained",
    "raw_token_retained",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "runtime_router_mutation",
    "system_g_mutation",
    "settings_default_mutation",
    "hidden_authority",
    "quality_claim",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-direct-harness-first-runtime-proof-receipt-gate:status
// Plane: Verification.
// Residency: metadata-only receipt contract; zero runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessFirstRuntimeProofReceiptGateStatus {
    ReceiptContractOnly,
}

// UAS: uas:gemma-direct-harness-first-runtime-proof-receipt-gate:spec
// Plane: Controller + Verification.
// Residency: future redacted receipt only; no execution.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessFirstRuntimeProofReceiptGate {
    pub upstream_command_card_ref: String,
    pub upstream_command_card_id: String,
    pub artifact_root_prefix: String,
    pub receipt_gate_id: String,
    pub future_receipt_name: String,
    pub runtime_lane: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_receipt_fields: Vec<String>,
    pub required_termination_classes: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_and_model_identity_required: bool,
    pub command_card_digest_required: bool,
    pub llama_cli_identity_required: bool,
    pub argv_environment_workdir_digest_required: bool,
    pub exit_termination_timeout_teardown_required: bool,
    pub timing_and_memory_digests_required: bool,
    pub stdout_stderr_digest_only: bool,
    pub first_token_digest_only: bool,
    pub prompt_and_output_digest_only: bool,
    pub redaction_and_raw_zero_proof_required: bool,
    pub stdio_capture_cap_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_required: bool,
    pub reviewer_visible_summary_ref: String,
    pub no_quality_claim_bound: bool,
    pub no_route_admission_bound: bool,
    pub non_promotion_bound: bool,
    pub future_receipt_written_count: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
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
    pub raw_output_bytes: u64,
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
    pub status: GemmaDirectHarnessFirstRuntimeProofReceiptGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessFirstRuntimeProofReceiptGate {
    pub fn canonical() -> Self {
        Self {
            upstream_command_card_ref:
                GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_UPSTREAM_REF.to_string(),
            upstream_command_card_id: GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            receipt_gate_id: RECEIPT_GATE_ID.to_string(),
            future_receipt_name: FUTURE_RECEIPT_NAME.to_string(),
            runtime_lane: RUNTIME_LANE.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_termination_classes: REQUIRED_TERMINATION_CLASSES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_and_model_identity_required: true,
            command_card_digest_required: true,
            llama_cli_identity_required: true,
            argv_environment_workdir_digest_required: true,
            exit_termination_timeout_teardown_required: true,
            timing_and_memory_digests_required: true,
            stdout_stderr_digest_only: true,
            first_token_digest_only: true,
            prompt_and_output_digest_only: true,
            redaction_and_raw_zero_proof_required: true,
            stdio_capture_cap_bytes: MAX_STDIO_CAPTURE_BYTES,
            rollback_ref: "rollback:gemma_first_runtime_proof_receipt_gate".to_string(),
            run_event_log_ref: "run_event_log:gemma_first_runtime_proof_receipt_gate".to_string(),
            answer_packet_ref: "answer_packet:gemma_first_runtime_proof_receipt_gate".to_string(),
            abstention_required: true,
            reviewer_visible_summary_ref: "reviewer_summary:gemma_first_runtime_proof_receipt_gate"
                .to_string(),
            no_quality_claim_bound: true,
            no_route_admission_bound: true,
            non_promotion_bound: true,
            future_receipt_written_count: 0,
            future_receipt_bytes_written: 0,
            future_receipt_bytes_read: 0,
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
            raw_output_bytes: 0,
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
            metadata_bytes: 312_000,
            status: GemmaDirectHarnessFirstRuntimeProofReceiptGateStatus::ReceiptContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessFirstRuntimeProofReceiptGateError> {
        if !self
            .upstream_command_card_ref
            .starts_with(UPSTREAM_COMMAND_CARD_PREFIX)
            || self.upstream_command_card_id
                != GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("receipt_gate_id", &self.receipt_gate_id, RECEIPT_GATE_ID)?;
        validate_exact(
            "future_receipt_name",
            &self.future_receipt_name,
            FUTURE_RECEIPT_NAME,
        )?;
        validate_exact("runtime_lane", &self.runtime_lane, RUNTIME_LANE)?;
        validate_unique_exact_set(
            "required_receipt_fields",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_termination_classes",
            &self.required_termination_classes,
            REQUIRED_TERMINATION_CLASSES,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessFirstRuntimeProofReceiptGateStatus::ReceiptContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::UnsafeState);
        }
        if !self.owner_and_model_identity_required
            || !self.command_card_digest_required
            || !self.llama_cli_identity_required
            || !self.argv_environment_workdir_digest_required
            || !self.exit_termination_timeout_teardown_required
            || !self.timing_and_memory_digests_required
            || !self.stdout_stderr_digest_only
            || !self.first_token_digest_only
            || !self.prompt_and_output_digest_only
            || !self.redaction_and_raw_zero_proof_required
            || self.stdio_capture_cap_bytes == 0
            || self.stdio_capture_cap_bytes > MAX_STDIO_CAPTURE_BYTES
            || !self.abstention_required
            || !self.no_quality_claim_bound
            || !self.no_route_admission_bound
            || !self.non_promotion_bound
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::ProofBoundaryBroken);
        }
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
        validate_prefix(
            "reviewer_visible_summary_ref",
            &self.reviewer_visible_summary_ref,
            REVIEW_PREFIX,
        )?;
        if self.future_receipt_written_count != 0
            || self.future_receipt_bytes_written != 0
            || self.future_receipt_bytes_read != 0
            || self.command_card_bytes_read != 0
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::ReceiptActionLeak);
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
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::RuntimeActionLeak);
        }
        if self.raw_model_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::PrivacyLeak);
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
            return Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessFirstRuntimeProofReceiptGateMetrics {
        GemmaDirectHarnessFirstRuntimeProofReceiptGateMetrics {
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            required_termination_class_count: self.required_termination_classes.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            stdio_capture_cap_bytes: self.stdio_capture_cap_bytes,
            future_receipt_written_count: self.future_receipt_written_count,
            future_receipt_bytes_written: self.future_receipt_bytes_written,
            future_receipt_bytes_read: self.future_receipt_bytes_read,
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
                + self.raw_output_bytes
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

    pub fn receipt_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_receipt_fields.clone();
        fields.sort();
        let mut termination = self.required_termination_classes.clone();
        termination.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-first-runtime-proof-receipt-gate:v1:{}:{}:{}:{}:{}:{}",
            self.upstream_command_card_ref,
            self.upstream_command_card_id,
            self.runtime_lane,
            fields.join(","),
            termination.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-first-runtime-proof-receipt-gate:metrics
// Plane: Verification.
// Residency: zero-action receipt counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessFirstRuntimeProofReceiptGateMetrics {
    pub required_receipt_field_count: u64,
    pub required_termination_class_count: u64,
    pub required_abort_condition_count: u64,
    pub stdio_capture_cap_bytes: u64,
    pub future_receipt_written_count: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
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

pub fn required_gemma_direct_harness_first_runtime_proof_receipt_gate_fields() -> Vec<String> {
    REQUIRED_RECEIPT_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_first_runtime_proof_termination_classes() -> Vec<String> {
    REQUIRED_TERMINATION_CLASSES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_first_runtime_proof_receipt_abort_conditions() -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-first-runtime-proof-receipt-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessFirstRuntimeProofReceiptGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ReceiptActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessFirstRuntimeProofReceiptGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream command-card reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe first runtime proof receipt-gate state"),
            Self::ProofBoundaryBroken => f.write_str("first runtime proof receipt boundary broken"),
            Self::ReceiptActionLeak => f.write_str("receipt action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessFirstRuntimeProofReceiptGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessFirstRuntimeProofReceiptGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessFirstRuntimeProofReceiptGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessFirstRuntimeProofReceiptGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessFirstRuntimeProofReceiptGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::BadField(field_name))
    }
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    prefix: &str,
) -> Result<(), GemmaDirectHarnessFirstRuntimeProofReceiptGateError> {
    if actual.starts_with(prefix) {
        Ok(())
    } else {
        Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_840_000_000;

    #[test]
    fn canonical_receipt_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.validate()
            .expect("canonical first runtime proof receipt gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_receipt_field_count, 35);
        assert_eq!(metrics.required_termination_class_count, 6);
        assert_eq!(metrics.required_abort_condition_count, 66);
        assert_eq!(metrics.future_receipt_bytes_written, 0);
        assert_eq!(metrics.future_receipt_bytes_read, 0);
        assert_eq!(metrics.command_card_bytes_read, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.process_spawned_count, 0);
        assert_eq!(metrics.server_started_count, 0);
        assert_eq!(metrics.network_or_hub_or_endpoint_count, 0);
        assert_eq!(metrics.raw_private_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_receipt_termination_or_abort_sets_are_rejected() {
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.required_receipt_fields[0] = gate.required_receipt_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessFirstRuntimeProofReceiptGateError::DuplicateOrMissingField(
                    "required_receipt_fields"
                )
            )
        ));
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.required_termination_classes[0] = gate.required_termination_classes[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessFirstRuntimeProofReceiptGateError::DuplicateOrMissingField(
                    "required_termination_classes"
                )
            )
        ));
    }

    #[test]
    fn missing_digest_or_unbounded_stdio_is_rejected() {
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.first_token_digest_only = false;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::ProofBoundaryBroken)
        ));
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.stdio_capture_cap_bytes = MAX_STDIO_CAPTURE_BYTES + 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::ProofBoundaryBroken)
        ));
    }

    #[test]
    fn receipt_action_runtime_action_privacy_and_promotion_are_rejected() {
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.future_receipt_bytes_read = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::ReceiptActionLeak)
        ));
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.process_spawned = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::RuntimeActionLeak)
        ));
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.raw_token_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        gate.live_gemma_default_claim = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessFirstRuntimeProofReceiptGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
        let reversed = GemmaDirectHarnessFirstRuntimeProofReceiptGate {
            required_receipt_fields: gate.required_receipt_fields.iter().cloned().rev().collect(),
            required_termination_classes: gate
                .required_termination_classes
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_abort_conditions: gate
                .required_abort_conditions
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        assert_eq!(
            gate.receipt_gate_address(CREATED_AT_MS),
            reversed.receipt_gate_address(CREATED_AT_MS)
        );
    }
}
