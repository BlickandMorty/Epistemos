//! Gemma QAT E2B first-token runtime artifact review gate.
//!
//! This primitive is a metadata-only review contract for the first future
//! owner-approved Gemma E2B GGUF/llama.cpp first-token runtime artifact. It
//! proves what the artifact must contain before System G or any user-facing
//! surface may cite it. It does not read an artifact, arm a command, open a
//! model path, observe a token, or promote Gemma as a product default.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID: &str =
    "F-GemmaQATE2BFirstTokenRuntimeArtifactReviewGate";
pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_CURSOR: &str =
    "gemma_qat_e2b_first_token_runtime_artifact_review_gate";
pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_owner_path_manifest_digest_gate";
pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_execution_probe/result.json#F-GemmaQATOwnerApprovedRuntimeReplayExecutionProbe";

const UPSTREAM_EXECUTION_PROBE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_execution_probe/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_gate/";
const REVIEW_CARD_ID: &str = "gemma-e2b-gguf-first-token-runtime-artifact-review-contract";
const FUTURE_RUNTIME_ARTIFACT_NAME: &str =
    "owner-approved-e2b-gguf-first-token-runtime-artifact-v1";
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_REVIEW_FIELDS: &[&str] = &[
    "upstream_execution_probe_digest",
    "artifact_schema_version",
    "runtime_artifact_id",
    "owner_approval_digest",
    "owner_path_manifest_digest",
    "canonical_path_digest",
    "model_file_digest",
    "model_file_size_bytes",
    "llama_cpp_binary_digest",
    "llama_cpp_version_digest",
    "resolved_command_argv_digest",
    "working_directory_digest",
    "environment_allowlist_digest",
    "prompt_fixture_id",
    "prompt_digest",
    "output_token_digest",
    "first_token_utf8_len",
    "first_token_utf8_class",
    "first_token_latency_ms",
    "load_latency_ms",
    "memory_before_bytes",
    "memory_at_load_bytes",
    "memory_at_first_token_bytes",
    "memory_after_teardown_bytes",
    "exit_status",
    "stdout_digest",
    "stderr_digest",
    "timeout_or_cancel_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "abstention_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_execution_probe",
    "missing_explicit_owner_approval",
    "missing_owner_path_manifest",
    "raw_model_path_retained",
    "raw_prompt_retained",
    "raw_output_retained",
    "raw_stdout_retained",
    "raw_stderr_retained",
    "model_digest_mismatch",
    "llama_cpp_digest_mismatch",
    "command_digest_mismatch",
    "environment_not_allowlisted",
    "first_token_missing",
    "first_token_unredacted",
    "first_token_used_as_quality_proof",
    "memory_samples_missing",
    "timeout_without_cancel",
    "nonzero_exit_without_abstention",
    "rollback_missing",
    "run_event_log_missing",
    "answer_packet_missing",
    "runtime_router_mutation",
    "system_g_mutation",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "mas_l2_l3_promotion",
    "gemma_default_promotion",
    "larger_model_bypass",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-gate:status
// Plane: Verification.
// Residency: review contract only; no runtime artifact is read.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bFirstTokenRuntimeArtifactReviewGateStatus {
    ReviewContractOnly,
}

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-gate:spec
// Plane: Controller + Verification.
// Residency: future E2B GGUF first-token artifact review contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bFirstTokenRuntimeArtifactReviewGate {
    pub upstream_execution_probe_ref: String,
    pub upstream_probe_id: String,
    pub upstream_owner_probe_ref: String,
    pub artifact_root_prefix: String,
    pub review_card_id: String,
    pub future_runtime_artifact_name: String,
    pub selected_model_id: String,
    pub required_filename: String,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_review_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_must_be_in_artifact: bool,
    pub owner_path_manifest_must_be_in_artifact: bool,
    pub canonical_path_digest_must_be_in_artifact: bool,
    pub raw_path_allowed: bool,
    pub raw_prompt_allowed: bool,
    pub raw_output_allowed: bool,
    pub raw_stdout_allowed: bool,
    pub raw_stderr_allowed: bool,
    pub first_token_digest_required: bool,
    pub first_token_raw_text_allowed: bool,
    pub first_token_quality_authority: bool,
    pub memory_samples_required: bool,
    pub runtime_artifact_present: bool,
    pub runtime_artifact_bytes_read: u64,
    pub accepted_runtime_artifact_count: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub model_file_opened: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_allowed: bool,
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
    pub larger_model_probe_allowed: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub metadata_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaQatE2bFirstTokenRuntimeArtifactReviewGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bFirstTokenRuntimeArtifactReviewGate {
    pub fn canonical(upstream_execution_probe_ref: impl Into<String>) -> Self {
        Self {
            upstream_execution_probe_ref: upstream_execution_probe_ref.into(),
            upstream_probe_id: GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID
                .to_string(),
            upstream_owner_probe_ref:
                GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            review_card_id: REVIEW_CARD_ID.to_string(),
            future_runtime_artifact_name: FUTURE_RUNTIME_ARTIFACT_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_review_fields: REQUIRED_REVIEW_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_must_be_in_artifact: true,
            owner_path_manifest_must_be_in_artifact: true,
            canonical_path_digest_must_be_in_artifact: true,
            raw_path_allowed: false,
            raw_prompt_allowed: false,
            raw_output_allowed: false,
            raw_stdout_allowed: false,
            raw_stderr_allowed: false,
            first_token_digest_required: true,
            first_token_raw_text_allowed: false,
            first_token_quality_authority: false,
            memory_samples_required: true,
            runtime_artifact_present: false,
            runtime_artifact_bytes_read: 0,
            accepted_runtime_artifact_count: 0,
            command_armed: false,
            command_executed: false,
            model_file_opened: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            route_mutation_allowed: false,
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
            larger_model_probe_allowed: false,
            timeout_bound: true,
            cancellation_bound: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            metadata_bytes: 92_000,
            rollback_ref: "rollback:gemma_qat_e2b_first_token_runtime_artifact_review_gate"
                .to_string(),
            run_event_log_ref:
                "run_event_log:gemma_qat_e2b_first_token_runtime_artifact_review_gate".to_string(),
            answer_packet_ref:
                "answer_packet:gemma_qat_e2b_first_token_runtime_artifact_review_gate".to_string(),
            abstention_ref: "abstention:gemma_qat_e2b_first_token_runtime_artifact_review_gate"
                .to_string(),
            status: GemmaQatE2bFirstTokenRuntimeArtifactReviewGateStatus::ReviewContractOnly,
            next_cursor: GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError> {
        if !self
            .upstream_execution_probe_ref
            .starts_with(UPSTREAM_EXECUTION_PROBE_PREFIX)
            || self.upstream_probe_id != GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID
        {
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_owner_probe_ref",
            &self.upstream_owner_probe_ref,
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        )?;
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("review_card_id", &self.review_card_id, REVIEW_CARD_ID)?;
        validate_exact(
            "future_runtime_artifact_name",
            &self.future_runtime_artifact_name,
            FUTURE_RUNTIME_ARTIFACT_NAME,
        )?;
        validate_unique_exact_set(
            "required_review_fields",
            &self.required_review_fields,
            REQUIRED_REVIEW_FIELDS,
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
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bFirstTokenRuntimeArtifactReviewGateStatus::ReviewContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::UnsafeState);
        }
        if !self.owner_approval_must_be_in_artifact
            || !self.owner_path_manifest_must_be_in_artifact
            || !self.canonical_path_digest_must_be_in_artifact
            || self.raw_path_allowed
            || self.raw_prompt_allowed
            || self.raw_output_allowed
            || self.raw_stdout_allowed
            || self.raw_stderr_allowed
        {
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::PrivacyBroken);
        }
        if !self.first_token_digest_required
            || self.first_token_raw_text_allowed
            || self.first_token_quality_authority
            || !self.memory_samples_required
            || !self.timeout_bound
            || !self.cancellation_bound
            || !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::ProofBoundaryBroken);
        }
        if self.runtime_artifact_present
            || self.runtime_artifact_bytes_read != 0
            || self.accepted_runtime_artifact_count != 0
            || self.command_armed
            || self.command_executed
            || self.model_file_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::ExecutionLeak);
        }
        if self.route_mutation_allowed
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
            || self.larger_model_probe_allowed
        {
            return Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::PromotionClaim);
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
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bFirstTokenRuntimeArtifactReviewGateMetrics {
        GemmaQatE2bFirstTokenRuntimeArtifactReviewGateMetrics {
            required_review_field_count: self.required_review_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            runtime_artifact_present_count: self.runtime_artifact_present as u64,
            runtime_artifact_bytes_read: self.runtime_artifact_bytes_read,
            accepted_runtime_artifact_count: self.accepted_runtime_artifact_count,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            model_file_opened_count: self.model_file_opened as u64,
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
                || self.larger_model_probe_allowed) as u64,
        }
    }

    pub fn review_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_review_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-first-token-runtime-artifact-review-gate:v1:{}:{}:{}:{:?}:{}:{}:{}:{}:{}",
            self.upstream_execution_probe_ref,
            self.selected_model_id,
            self.required_filename,
            self.runtime_lane,
            fields.join(","),
            policies.join(","),
            self.runtime_artifact_bytes_read,
            self.product_route_green,
            self.next_cursor
        )
    }
}

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-gate:metrics
// Plane: Verification.
// Residency: review contract counts and zero-byte ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bFirstTokenRuntimeArtifactReviewGateMetrics {
    pub required_review_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub runtime_artifact_present_count: u64,
    pub runtime_artifact_bytes_read: u64,
    pub accepted_runtime_artifact_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub model_file_opened_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_first_token_runtime_artifact_review_fields() -> Vec<String> {
    REQUIRED_REVIEW_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_first_token_runtime_artifact_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-gate:error
// Plane: Verification.
// Residency: fail-closed review-contract diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    PrivacyBroken,
    ProofBoundaryBroken,
    ExecutionLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream execution-probe reference"),
            Self::BadSelectedLane => f.write_str("bad selected Gemma E2B GGUF lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe review-gate state"),
            Self::PrivacyBroken => f.write_str("privacy boundary broken"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::ExecutionLeak => f.write_str("execution or byte leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::BadField(field_name))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_392_000_000;

    #[test]
    fn canonical_review_contract_validates_and_stays_zero_byte() {
        let gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate::canonical(
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
        );
        gate.validate().unwrap();
        let metrics = gate.metrics();

        assert_eq!(metrics.required_review_field_count, 32);
        assert_eq!(metrics.required_rejection_policy_count, 33);
        assert_eq!(metrics.runtime_artifact_present_count, 0);
        assert_eq!(metrics.runtime_artifact_bytes_read, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.provider_calls_made, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_or_missing_review_fields_are_rejected() {
        let mut gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate::canonical(
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
        );
        gate.required_review_fields.pop();

        assert_eq!(
            gate.validate(),
            Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewGateError::DuplicateOrMissingField(
                    "required_review_fields"
                )
            )
        );
    }

    #[test]
    fn raw_token_quality_or_promotion_are_rejected() {
        for mutate in [
            |gate: &mut GemmaQatE2bFirstTokenRuntimeArtifactReviewGate| {
                gate.first_token_raw_text_allowed = true
            },
            |gate: &mut GemmaQatE2bFirstTokenRuntimeArtifactReviewGate| {
                gate.first_token_quality_authority = true
            },
            |gate: &mut GemmaQatE2bFirstTokenRuntimeArtifactReviewGate| {
                gate.product_route_green = true
            },
            |gate: &mut GemmaQatE2bFirstTokenRuntimeArtifactReviewGate| {
                gate.runtime_artifact_bytes_read = 1
            },
        ] {
            let mut gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate::canonical(
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
            );
            mutate(&mut gate);
            assert!(gate.validate().is_err());
        }
    }

    #[test]
    fn review_gate_address_is_order_deterministic() {
        let gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate::canonical(
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate {
            required_review_fields: gate.required_review_fields.iter().cloned().rev().collect(),
            required_rejection_policies: gate
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };

        assert_eq!(
            gate.review_gate_address(CREATED_AT_MS),
            reversed.review_gate_address(CREATED_AT_MS)
        );
    }
}
