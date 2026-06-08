//! Gemma QAT runtime replay execution artifact gate.
//!
//! This primitive consumes the owner-approved runtime replay probe envelope and
//! defines the manifest contract that a later one-token Gemma E2B GGUF run must
//! produce. It does not execute llama.cpp, open model paths, retain raw prompt
//! or output, observe tokens, or promote Gemma as the app default.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID: &str =
    "F-GemmaQATRuntimeReplayExecutionArtifactGate";
pub const GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_CURSOR: &str =
    "gemma_qat_runtime_replay_execution_artifact_gate";
pub const GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR: &str =
    "gemma_qat_owner_approved_runtime_replay_execution_probe";
pub const GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_probe/result.json#F-GemmaQATOwnerApprovedRuntimeReplayProbe";

const UPSTREAM_PROBE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_probe/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/";
const FUTURE_MANIFEST_NAME: &str = "owner-approved-e2b-gguf-one-token-runtime-artifact.json";
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_EXECUTION_MANIFEST_FIELDS: &[&str] = &[
    "source_commit_sha",
    "upstream_probe_artifact_digest",
    "upstream_probe_address",
    "owner_approval_digest",
    "owner_model_path_manifest_digest",
    "canonical_model_path_digest",
    "model_file_digest",
    "model_file_size_bytes",
    "resolved_command_path_digest",
    "llama_cpp_version_digest",
    "command_template_digest",
    "redacted_prompt_digest",
    "redacted_output_digest",
    "first_token_digest",
    "memory_before_sample_digest",
    "memory_runtime_start_sample_digest",
    "memory_after_sample_digest",
    "exit_status_digest",
    "timeout_or_cancel_status_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "rollback_digest",
    "abstention_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_owner_approval",
    "missing_owner_model_path_manifest",
    "raw_model_path_retained",
    "raw_prompt_retained",
    "raw_output_retained",
    "stdout_or_stderr_retained",
    "model_file_digest_missing",
    "command_digest_mismatch",
    "llama_cpp_version_missing",
    "memory_sample_missing",
    "first_token_digest_missing_after_execution",
    "nonzero_exit_without_abstention",
    "timeout_without_cancellation",
    "route_mutation",
    "hidden_cloud_fallback",
    "hidden_eidos_lattice_patternboost_authority",
    "gemma_default_promotion",
    "larger_model_bypass",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-qat-runtime-replay-execution-artifact-gate:status
// Plane: Verification.
// Residency: manifest parser contract only; no runtime execution.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatRuntimeReplayExecutionArtifactStatus {
    ParserContractOnly,
}

// UAS: uas:gemma-qat-runtime-replay-execution-artifact-gate:spec
// Plane: Controller + Verification.
// Residency: future one-token execution artifact schema; no live bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRuntimeReplayExecutionArtifactGate {
    pub upstream_probe_ref: String,
    pub artifact_root_prefix: String,
    pub future_manifest_name: String,
    pub selected_model_id: String,
    pub required_filename: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_execution_manifest_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub parser_dry_run_only: bool,
    pub metadata_only: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub owner_model_path_manifest_required: bool,
    pub raw_model_path_retention_allowed: bool,
    pub raw_prompt_retention_allowed: bool,
    pub raw_output_retention_allowed: bool,
    pub stdout_stderr_retention_allowed: bool,
    pub command_execution_allowed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
    pub first_token_observed: bool,
    pub future_first_token_digest_required: bool,
    pub model_file_opened: bool,
    pub model_file_digest_required: bool,
    pub command_digest_required: bool,
    pub llama_cpp_version_digest_required: bool,
    pub memory_before_sample_required: bool,
    pub memory_runtime_start_sample_required: bool,
    pub memory_after_sample_required: bool,
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
    pub status: GemmaQatRuntimeReplayExecutionArtifactStatus,
    pub next_cursor: String,
}

impl GemmaQatRuntimeReplayExecutionArtifactGate {
    pub fn canonical(upstream_probe_ref: impl Into<String>) -> Self {
        Self {
            upstream_probe_ref: upstream_probe_ref.into(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            future_manifest_name: FUTURE_MANIFEST_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_execution_manifest_fields: REQUIRED_EXECUTION_MANIFEST_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            parser_dry_run_only: true,
            metadata_only: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            owner_model_path_manifest_required: true,
            raw_model_path_retention_allowed: false,
            raw_prompt_retention_allowed: false,
            raw_output_retention_allowed: false,
            stdout_stderr_retention_allowed: false,
            command_execution_allowed: false,
            command_executed: false,
            runtime_replay_performed: false,
            first_token_observed: false,
            future_first_token_digest_required: true,
            model_file_opened: false,
            model_file_digest_required: true,
            command_digest_required: true,
            llama_cpp_version_digest_required: true,
            memory_before_sample_required: true,
            memory_runtime_start_sample_required: true,
            memory_after_sample_required: true,
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
            metadata_bytes: 72_000,
            rollback_ref: "rollback:gemma_qat_runtime_replay_execution_artifact_gate".to_string(),
            run_event_log_ref: "run_event_log:gemma_qat_runtime_replay_execution_artifact_gate"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma_qat_runtime_replay_execution_artifact_gate"
                .to_string(),
            abstention_ref: "abstention:gemma_qat_runtime_replay_execution_artifact_gate"
                .to_string(),
            status: GemmaQatRuntimeReplayExecutionArtifactStatus::ParserContractOnly,
            next_cursor: GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatRuntimeReplayExecutionArtifactGateError> {
        if !self.upstream_probe_ref.starts_with(UPSTREAM_PROBE_PREFIX) {
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::BadUpstreamRef);
        }
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "future_manifest_name",
            &self.future_manifest_name,
            FUTURE_MANIFEST_NAME,
        )?;
        validate_unique_exact_set(
            "required_execution_manifest_fields",
            &self.required_execution_manifest_fields,
            REQUIRED_EXECUTION_MANIFEST_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
        {
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status != GemmaQatRuntimeReplayExecutionArtifactStatus::ParserContractOnly
            || !self.parser_dry_run_only
            || !self.metadata_only
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::UnsafeState);
        }
        if !self.owner_approval_required
            || self.owner_approval_granted
            || !self.owner_model_path_manifest_required
            || self.raw_model_path_retention_allowed
            || self.raw_prompt_retention_allowed
            || self.raw_output_retention_allowed
            || self.stdout_stderr_retention_allowed
        {
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ApprovalOrPrivacyBroken);
        }
        if self.command_execution_allowed
            || self.command_executed
            || self.runtime_replay_performed
            || self.first_token_observed
            || self.model_file_opened
        {
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ExecutionLeak);
        }
        if !self.future_first_token_digest_required
            || !self.model_file_digest_required
            || !self.command_digest_required
            || !self.llama_cpp_version_digest_required
            || !self.memory_before_sample_required
            || !self.memory_runtime_start_sample_required
            || !self.memory_after_sample_required
            || !self.cancellation_bound
            || !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ProofBoundaryBroken);
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
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::PromotionClaim);
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
            return Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ByteLeak);
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
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatRuntimeReplayExecutionArtifactMetrics {
        GemmaQatRuntimeReplayExecutionArtifactMetrics {
            required_manifest_field_count: self.required_execution_manifest_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_granted_count: self.owner_approval_granted as u64,
            command_execution_allowed_count: self.command_execution_allowed as u64,
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

    pub fn gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut manifest_fields = self.required_execution_manifest_fields.clone();
        manifest_fields.sort();
        let mut rejection_policies = self.required_rejection_policies.clone();
        rejection_policies.sort();
        format!(
            "gemma-runtime-execution-artifact-gate:v1:{}:{}:{}:{:?}:{}:{}:{}:{}:{}",
            self.upstream_probe_ref,
            self.selected_model_id,
            self.required_filename,
            self.runtime_lane,
            manifest_fields.join(","),
            rejection_policies.join(","),
            self.command_executed,
            self.model_bytes_loaded,
            self.next_cursor
        )
    }
}

// UAS: uas:gemma-qat-runtime-replay-execution-artifact-gate:metrics
// Plane: Verification.
// Residency: parser contract counts and zero-byte ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatRuntimeReplayExecutionArtifactMetrics {
    pub required_manifest_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub owner_approval_granted_count: u64,
    pub command_execution_allowed_count: u64,
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
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_runtime_replay_execution_manifest_fields() -> Vec<String> {
    REQUIRED_EXECUTION_MANIFEST_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_runtime_replay_execution_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), GemmaQatRuntimeReplayExecutionArtifactGateError> {
    if value.starts_with(prefix) {
        Ok(())
    } else {
        Err(GemmaQatRuntimeReplayExecutionArtifactGateError::BadField(
            field,
        ))
    }
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GemmaQatRuntimeReplayExecutionArtifactGateError> {
    if value == expected {
        Ok(())
    } else {
        Err(GemmaQatRuntimeReplayExecutionArtifactGateError::BadField(
            field,
        ))
    }
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatRuntimeReplayExecutionArtifactGateError> {
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = expected.iter().copied().collect::<BTreeSet<_>>();
    if actual == expected && values.len() == actual.len() {
        Ok(())
    } else {
        Err(GemmaQatRuntimeReplayExecutionArtifactGateError::BadField(
            field,
        ))
    }
}

// UAS: uas:gemma-qat-runtime-replay-execution-artifact-gate:error
// Plane: Verification.
// Residency: validation failures only; no runtime bytes are represented.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatRuntimeReplayExecutionArtifactGateError {
    BadUpstreamRef,
    BadField(&'static str),
    BadSelectedLane,
    UnsafeState,
    ApprovalOrPrivacyBroken,
    ExecutionLeak,
    ProofBoundaryBroken,
    PromotionClaim,
    ByteLeak,
}

impl fmt::Display for GemmaQatRuntimeReplayExecutionArtifactGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for GemmaQatRuntimeReplayExecutionArtifactGateError {}

#[cfg(test)]
mod tests {
    use super::{
        GemmaQatRuntimeReplayExecutionArtifactGate,
        GemmaQatRuntimeReplayExecutionArtifactGateError,
        GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
    };

    #[test]
    fn canonical_gate_validates_without_execution_or_model_bytes() {
        let gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        );
        gate.validate().expect("canonical gate validates");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_manifest_field_count, 23);
        assert_eq!(metrics.required_rejection_policy_count, 20);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.first_token_observed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(
            gate.next_cursor,
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_owner_approval_execution_or_raw_output_laundering() {
        let mut gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        );
        gate.owner_approval_granted = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ApprovalOrPrivacyBroken)
        );

        let mut gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        );
        gate.command_executed = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ExecutionLeak)
        );

        let mut gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        );
        gate.raw_output_retention_allowed = true;
        gate.captured_raw_output_bytes = 1;
        assert_eq!(
            gate.validate(),
            Err(GemmaQatRuntimeReplayExecutionArtifactGateError::ApprovalOrPrivacyBroken)
        );
    }

    #[test]
    fn rejects_missing_manifest_fields_or_product_promotion() {
        let mut gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        );
        gate.required_execution_manifest_fields.pop();
        assert!(gate.validate().is_err());

        let mut gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        );
        gate.live_gemma_default_claim = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaQatRuntimeReplayExecutionArtifactGateError::PromotionClaim)
        );
    }
}
