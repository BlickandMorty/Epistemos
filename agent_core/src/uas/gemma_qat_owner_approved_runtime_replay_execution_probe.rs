//! Gemma QAT owner-approved runtime replay execution probe.
//!
//! This primitive defines the next owner-approved E2B GGUF execution-proof
//! envelope after the execution artifact gate. It remains metadata-only in the
//! default loop: no command is armed, no model path is opened, no token is
//! observed, and no Gemma product/default claim is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID: &str =
    "F-GemmaQATOwnerApprovedRuntimeReplayExecutionProbe";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_CURSOR: &str =
    "gemma_qat_owner_approved_runtime_replay_execution_probe";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_first_token_runtime_artifact_review_gate";
pub const GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/result.json#F-GemmaQATRuntimeReplayExecutionArtifactGate";

const UPSTREAM_EXECUTION_ARTIFACT_GATE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_execution_probe/";
const PROBE_CARD_ID: &str = "gemma-e2b-gguf-owner-approved-one-token-execution-probe";
const MAX_METADATA_BYTES: u64 = 224 * 1024;

const REQUIRED_EXECUTION_PROOF_FIELDS: &[&str] = &[
    "upstream_execution_artifact_gate_digest",
    "owner_approval_digest",
    "owner_path_manifest_digest",
    "canonical_path_digest",
    "model_file_digest",
    "model_file_size_bytes",
    "llama_cpp_binary_digest",
    "llama_cpp_version_digest",
    "command_template_digest",
    "resolved_command_argv_digest",
    "working_directory_digest",
    "environment_allowlist_digest",
    "redacted_prompt_digest",
    "redacted_output_digest",
    "first_token_digest",
    "first_token_utf8_shape_digest",
    "memory_before_digest",
    "memory_start_digest",
    "memory_first_token_digest",
    "memory_after_digest",
    "duration_digest",
    "exit_status_digest",
    "timeout_or_cancel_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "rollback_digest",
    "abstention_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_explicit_owner_approval",
    "missing_owner_path_manifest",
    "model_path_outside_owner_manifest",
    "model_digest_mismatch",
    "llama_cpp_binary_digest_mismatch",
    "llama_cpp_version_unrecorded",
    "forbidden_network_flag",
    "forbidden_server_flag",
    "forbidden_download_flag",
    "forbidden_mmap_or_prefill_stress_flag",
    "raw_prompt_output_or_stdio_retained",
    "memory_sample_missing",
    "timeout_without_cancel",
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

// UAS: uas:gemma-qat-owner-approved-runtime-replay-execution-probe:status
// Plane: Verification.
// Residency: owner-approval-pending execution probe envelope; no live bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatOwnerApprovedRuntimeReplayExecutionProbeStatus {
    OwnerApprovalPending,
}

// UAS: uas:gemma-qat-owner-approved-runtime-replay-execution-probe:spec
// Plane: Controller + Verification.
// Residency: future one-token E2B GGUF execution probe contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayExecutionProbe {
    pub upstream_execution_artifact_gate_ref: String,
    pub upstream_gate_id: String,
    pub artifact_root_prefix: String,
    pub probe_card_id: String,
    pub selected_model_id: String,
    pub required_filename: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_execution_proof_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub owner_model_path_manifest_required: bool,
    pub canonical_path_digest_required: bool,
    pub raw_path_retention_allowed: bool,
    pub raw_prompt_retention_allowed: bool,
    pub raw_output_retention_allowed: bool,
    pub stdout_stderr_retention_allowed: bool,
    pub command_template_visible: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
    pub first_token_observed: bool,
    pub first_token_digest_required_after_success: bool,
    pub model_file_opened: bool,
    pub model_digest_required: bool,
    pub llama_cpp_binary_digest_required: bool,
    pub llama_cpp_version_digest_required: bool,
    pub network_access_allowed: bool,
    pub server_mode_allowed: bool,
    pub download_allowed: bool,
    pub mmap_or_prefill_stress_allowed: bool,
    pub memory_before_required: bool,
    pub memory_start_required: bool,
    pub memory_first_token_required: bool,
    pub memory_after_required: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub provider_calls_allowed: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub product_route_green: bool,
    pub live_gemma_default_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub larger_model_probe_allowed: bool,
    pub opened_model_file_bytes: u64,
    pub opened_runtime_file_bytes: u64,
    pub captured_raw_prompt_bytes: u64,
    pub captured_raw_output_bytes: u64,
    pub captured_stdout_bytes: u64,
    pub captured_stderr_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub metadata_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaQatOwnerApprovedRuntimeReplayExecutionProbeStatus,
    pub next_cursor: String,
}

impl GemmaQatOwnerApprovedRuntimeReplayExecutionProbe {
    pub fn canonical(upstream_execution_artifact_gate_ref: impl Into<String>) -> Self {
        Self {
            upstream_execution_artifact_gate_ref: upstream_execution_artifact_gate_ref.into(),
            upstream_gate_id: GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            probe_card_id: PROBE_CARD_ID.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_execution_proof_fields: REQUIRED_EXECUTION_PROOF_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_required: true,
            owner_approval_granted: false,
            owner_model_path_manifest_required: true,
            canonical_path_digest_required: true,
            raw_path_retention_allowed: false,
            raw_prompt_retention_allowed: false,
            raw_output_retention_allowed: false,
            stdout_stderr_retention_allowed: false,
            command_template_visible: true,
            command_armed: false,
            command_executed: false,
            runtime_replay_performed: false,
            first_token_observed: false,
            first_token_digest_required_after_success: true,
            model_file_opened: false,
            model_digest_required: true,
            llama_cpp_binary_digest_required: true,
            llama_cpp_version_digest_required: true,
            network_access_allowed: false,
            server_mode_allowed: false,
            download_allowed: false,
            mmap_or_prefill_stress_allowed: false,
            memory_before_required: true,
            memory_start_required: true,
            memory_first_token_required: true,
            memory_after_required: true,
            timeout_bound: true,
            cancellation_bound: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            provider_calls_allowed: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            product_route_green: false,
            live_gemma_default_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            larger_model_probe_allowed: false,
            opened_model_file_bytes: 0,
            opened_runtime_file_bytes: 0,
            captured_raw_prompt_bytes: 0,
            captured_raw_output_bytes: 0,
            captured_stdout_bytes: 0,
            captured_stderr_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            metadata_bytes: 88_000,
            rollback_ref: "rollback:gemma_qat_owner_approved_runtime_replay_execution_probe"
                .to_string(),
            run_event_log_ref:
                "run_event_log:gemma_qat_owner_approved_runtime_replay_execution_probe".to_string(),
            answer_packet_ref:
                "answer_packet:gemma_qat_owner_approved_runtime_replay_execution_probe".to_string(),
            abstention_ref: "abstention:gemma_qat_owner_approved_runtime_replay_execution_probe"
                .to_string(),
            status: GemmaQatOwnerApprovedRuntimeReplayExecutionProbeStatus::OwnerApprovalPending,
            next_cursor: GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError> {
        if !self
            .upstream_execution_artifact_gate_ref
            .starts_with(UPSTREAM_EXECUTION_ARTIFACT_GATE_PREFIX)
            || self.upstream_gate_id != GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::BadUpstreamRef);
        }
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("probe_card_id", &self.probe_card_id, PROBE_CARD_ID)?;
        validate_unique_exact_set(
            "required_execution_proof_fields",
            &self.required_execution_proof_fields,
            REQUIRED_EXECUTION_PROOF_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatOwnerApprovedRuntimeReplayExecutionProbeStatus::OwnerApprovalPending
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::UnsafeState);
        }
        if !self.owner_approval_required
            || self.owner_approval_granted
            || !self.owner_model_path_manifest_required
            || !self.canonical_path_digest_required
            || self.raw_path_retention_allowed
            || self.raw_prompt_retention_allowed
            || self.raw_output_retention_allowed
            || self.stdout_stderr_retention_allowed
        {
            return Err(
                GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ApprovalOrPrivacyBroken,
            );
        }
        if !self.command_template_visible
            || self.command_armed
            || self.command_executed
            || self.runtime_replay_performed
            || self.first_token_observed
            || self.model_file_opened
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ExecutionLeak);
        }
        if !self.first_token_digest_required_after_success
            || !self.model_digest_required
            || !self.llama_cpp_binary_digest_required
            || !self.llama_cpp_version_digest_required
            || !self.memory_before_required
            || !self.memory_start_required
            || !self.memory_first_token_required
            || !self.memory_after_required
            || !self.timeout_bound
            || !self.cancellation_bound
            || !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ProofBoundaryBroken);
        }
        if self.network_access_allowed
            || self.server_mode_allowed
            || self.download_allowed
            || self.mmap_or_prefill_stress_allowed
            || self.provider_calls_allowed
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ForbiddenRoute);
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
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
            || self.quality_claimed
            || self.benchmark_claimed_as_fit
            || self.larger_model_probe_allowed
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::PromotionClaim);
        }
        if self.opened_model_file_bytes != 0
            || self.opened_runtime_file_bytes != 0
            || self.captured_raw_prompt_bytes != 0
            || self.captured_raw_output_bytes != 0
            || self.captured_stdout_bytes != 0
            || self.captured_stderr_bytes != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ByteLeak);
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
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatOwnerApprovedRuntimeReplayExecutionProbeMetrics {
        GemmaQatOwnerApprovedRuntimeReplayExecutionProbeMetrics {
            required_execution_proof_field_count: self.required_execution_proof_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            owner_approval_granted_count: self.owner_approval_granted as u64,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            runtime_replay_performed_count: self.runtime_replay_performed as u64,
            first_token_observed_count: self.first_token_observed as u64,
            opened_model_file_bytes: self.opened_model_file_bytes,
            opened_runtime_file_bytes: self.opened_runtime_file_bytes,
            captured_raw_prompt_bytes: self.captured_raw_prompt_bytes,
            captured_raw_output_bytes: self.captured_raw_output_bytes,
            captured_stdout_bytes: self.captured_stdout_bytes,
            captured_stderr_bytes: self.captured_stderr_bytes,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            forbidden_route_count: (self.network_access_allowed
                || self.server_mode_allowed
                || self.download_allowed
                || self.mmap_or_prefill_stress_allowed
                || self.provider_calls_allowed) as u64,
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
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim
                || self.quality_claimed
                || self.benchmark_claimed_as_fit
                || self.larger_model_probe_allowed) as u64,
        }
    }

    pub fn probe_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut proof_fields = self.required_execution_proof_fields.clone();
        proof_fields.sort();
        let mut abort_conditions = self.required_abort_conditions.clone();
        abort_conditions.sort();
        format!(
            "gemma-owner-approved-runtime-replay-execution-probe:v1:{}:{}:{}:{:?}:{}:{}:{}:{}:{}",
            self.upstream_execution_artifact_gate_ref,
            self.selected_model_id,
            self.required_filename,
            self.runtime_lane,
            proof_fields.join(","),
            abort_conditions.join(","),
            self.command_armed,
            self.model_bytes_loaded,
            self.next_cursor
        )
    }
}

// UAS: uas:gemma-qat-owner-approved-runtime-replay-execution-probe:metrics
// Plane: Verification.
// Residency: execution envelope counts and zero-byte ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatOwnerApprovedRuntimeReplayExecutionProbeMetrics {
    pub required_execution_proof_field_count: u64,
    pub required_abort_condition_count: u64,
    pub owner_approval_granted_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub runtime_replay_performed_count: u64,
    pub first_token_observed_count: u64,
    pub opened_model_file_bytes: u64,
    pub opened_runtime_file_bytes: u64,
    pub captured_raw_prompt_bytes: u64,
    pub captured_raw_output_bytes: u64,
    pub captured_stdout_bytes: u64,
    pub captured_stderr_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub forbidden_route_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_owner_approved_runtime_replay_execution_proof_fields() -> Vec<String> {
    REQUIRED_EXECUTION_PROOF_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_owner_approved_runtime_replay_abort_conditions() -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError> {
    if value.starts_with(prefix) {
        Ok(())
    } else {
        Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::BadField(field))
    }
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError> {
    if value == expected {
        Ok(())
    } else {
        Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::BadField(field))
    }
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError> {
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = expected.iter().copied().collect::<BTreeSet<_>>();
    if actual == expected && values.len() == actual.len() {
        Ok(())
    } else {
        Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::BadField(field))
    }
}

// UAS: uas:gemma-qat-owner-approved-runtime-replay-execution-probe:error
// Plane: Verification.
// Residency: validation failures only; no runtime bytes are represented.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError {
    BadUpstreamRef,
    BadField(&'static str),
    BadSelectedLane,
    UnsafeState,
    ApprovalOrPrivacyBroken,
    ExecutionLeak,
    ProofBoundaryBroken,
    ForbiddenRoute,
    PromotionClaim,
    ByteLeak,
}

impl fmt::Display for GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError {}

#[cfg(test)]
mod tests {
    use super::{
        GemmaQatOwnerApprovedRuntimeReplayExecutionProbe,
        GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError,
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR,
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
    };

    #[test]
    fn canonical_probe_validates_without_execution_or_model_bytes() {
        let probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.validate().expect("canonical probe validates");
        let metrics = probe.metrics();
        assert_eq!(metrics.required_execution_proof_field_count, 27);
        assert_eq!(metrics.required_abort_condition_count, 24);
        assert_eq!(metrics.owner_approval_granted_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.first_token_observed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(
            probe.next_cursor,
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_approval_laundering_command_arming_and_raw_output() {
        let mut probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.owner_approval_granted = true;
        assert_eq!(
            probe.validate(),
            Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ApprovalOrPrivacyBroken)
        );

        let mut probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.command_armed = true;
        assert_eq!(
            probe.validate(),
            Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ExecutionLeak)
        );

        let mut probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.raw_output_retention_allowed = true;
        probe.captured_raw_output_bytes = 1;
        assert_eq!(
            probe.validate(),
            Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::ApprovalOrPrivacyBroken)
        );
    }

    #[test]
    fn rejects_hidden_route_product_claim_and_missing_fields() {
        let mut probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.hidden_cloud_fallback = true;
        assert_eq!(
            probe.validate(),
            Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::PromotionClaim)
        );

        let mut probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.live_gemma_default_claim = true;
        assert_eq!(
            probe.validate(),
            Err(GemmaQatOwnerApprovedRuntimeReplayExecutionProbeError::PromotionClaim)
        );

        let mut probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        );
        probe.required_execution_proof_fields.pop();
        assert!(probe.validate().is_err());
    }
}
