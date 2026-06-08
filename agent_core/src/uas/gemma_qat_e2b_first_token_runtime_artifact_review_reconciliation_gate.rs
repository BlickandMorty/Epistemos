//! Gemma QAT E2B first-token artifact reconciliation gate.
//!
//! This primitive consumes the owner-approved first-token runtime probe
//! contract and defines the fail-closed reconciliation contract for a future
//! one-token artifact. It is metadata-only: no runtime artifact is read, no
//! local path is opened, no command is armed or executed, no token is observed,
//! and no Gemma product capability is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_ID,
    GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
    GEMMA_QAT_E2B_SOURCE_REVISION, GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_ID: &str =
    "F-GemmaQATE2BFirstTokenRuntimeArtifactReviewReconciliationGate";
pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_CURSOR: &str =
    "gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate";
pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_same_fixture_quality_replay_packet_gate";
pub const GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_e2b_owner_approved_first_token_runtime_probe/result.json#F-GemmaQATE2BOwnerApprovedFirstTokenRuntimeProbe";

const UPSTREAM_OWNER_APPROVED_PROBE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_owner_approved_first_token_runtime_probe/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate/";
const RECONCILIATION_CARD_ID: &str = "gemma-e2b-gguf-first-token-artifact-review-reconciliation";
const FUTURE_RUNTIME_ARTIFACT_NAME: &str =
    "owner-approved-e2b-gguf-first-token-runtime-artifact-v1";
const MAX_METADATA_BYTES: u64 = 256 * 1024;

const REQUIRED_RECONCILIATION_FIELDS: &[&str] = &[
    "upstream_owner_approved_probe_digest",
    "artifact_schema_version_digest",
    "runtime_artifact_id_digest",
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
    "first_token_digest",
    "first_token_shape_digest",
    "first_token_utf8_class_digest",
    "stdout_digest",
    "stderr_digest",
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
    "reconciliation_decision_digest",
    "rejection_reason_digest",
    "no_promotion_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_owner_approved_probe",
    "missing_explicit_owner_approval",
    "missing_owner_manifest_digest",
    "missing_canonical_path_digest",
    "model_file_digest_mismatch",
    "model_file_size_mismatch",
    "llama_cpp_binary_digest_mismatch",
    "llama_cpp_version_digest_mismatch",
    "command_template_digest_mismatch",
    "resolved_argv_digest_mismatch",
    "environment_allowlist_mismatch",
    "synthetic_prompt_digest_mismatch",
    "raw_path_retained",
    "raw_prompt_retained",
    "raw_output_retained",
    "raw_stdout_retained",
    "raw_stderr_retained",
    "raw_token_retained",
    "first_token_missing",
    "first_token_unredacted",
    "first_token_used_as_quality_proof",
    "memory_samples_missing",
    "timeout_without_cancel",
    "teardown_missing",
    "nonzero_exit_without_abstention",
    "rollback_missing",
    "run_event_log_missing",
    "answer_packet_missing",
    "artifact_read_in_default_loop",
    "runtime_replay_attempted_in_reconciliation",
    "runtime_router_mutation",
    "system_g_mutation",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "mas_l2_l3_t4_promotion",
    "gemma_default_promotion",
    "e4b_12b_bypass",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-reconciliation-gate:status
// Plane: Verification.
// Residency: reconciliation contract only; no runtime artifact is read.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateStatus {
    ReconciliationContractOnly,
}

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-reconciliation-gate:spec
// Plane: Controller + Verification.
// Residency: future first-token artifact reconciliation contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate {
    pub upstream_owner_approved_probe_ref: String,
    pub upstream_probe_id: String,
    pub upstream_model_file_digest_gate_ref: String,
    pub artifact_root_prefix: String,
    pub reconciliation_card_id: String,
    pub future_runtime_artifact_name: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_reconciliation_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_digest_required: bool,
    pub owner_manifest_digest_required: bool,
    pub canonical_path_digest_required: bool,
    pub model_file_digest_match_required: bool,
    pub model_file_size_match_required: bool,
    pub llama_cpp_binary_digest_match_required: bool,
    pub llama_cpp_version_digest_match_required: bool,
    pub command_template_digest_match_required: bool,
    pub resolved_argv_digest_match_required: bool,
    pub environment_allowlist_match_required: bool,
    pub synthetic_prompt_digest_match_required: bool,
    pub first_token_digest_required: bool,
    pub first_token_redacted: bool,
    pub first_token_quality_authority: bool,
    pub memory_samples_required: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub teardown_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub future_runtime_artifact_present: bool,
    pub future_runtime_artifact_bytes_read: u64,
    pub accepted_runtime_artifact_count: u64,
    pub reconciliation_performed_count: u64,
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
    pub captured_raw_path_bytes: u64,
    pub captured_raw_prompt_bytes: u64,
    pub captured_raw_output_bytes: u64,
    pub captured_stdout_bytes: u64,
    pub captured_stderr_bytes: u64,
    pub captured_raw_token_bytes: u64,
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
    pub t4_build_green_effect: bool,
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
    pub status: GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate {
    pub fn canonical(upstream_owner_approved_probe_ref: impl Into<String>) -> Self {
        Self {
            upstream_owner_approved_probe_ref: upstream_owner_approved_probe_ref.into(),
            upstream_probe_id: GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_ID
                .to_string(),
            upstream_model_file_digest_gate_ref:
                GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            reconciliation_card_id: RECONCILIATION_CARD_ID.to_string(),
            future_runtime_artifact_name: FUTURE_RUNTIME_ARTIFACT_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_reconciliation_fields: REQUIRED_RECONCILIATION_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_digest_required: true,
            owner_manifest_digest_required: true,
            canonical_path_digest_required: true,
            model_file_digest_match_required: true,
            model_file_size_match_required: true,
            llama_cpp_binary_digest_match_required: true,
            llama_cpp_version_digest_match_required: true,
            command_template_digest_match_required: true,
            resolved_argv_digest_match_required: true,
            environment_allowlist_match_required: true,
            synthetic_prompt_digest_match_required: true,
            first_token_digest_required: true,
            first_token_redacted: true,
            first_token_quality_authority: false,
            memory_samples_required: true,
            timeout_bound: true,
            cancellation_bound: true,
            teardown_bound: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            future_runtime_artifact_present: false,
            future_runtime_artifact_bytes_read: 0,
            accepted_runtime_artifact_count: 0,
            reconciliation_performed_count: 0,
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
            captured_raw_path_bytes: 0,
            captured_raw_prompt_bytes: 0,
            captured_raw_output_bytes: 0,
            captured_stdout_bytes: 0,
            captured_stderr_bytes: 0,
            captured_raw_token_bytes: 0,
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
            t4_build_green_effect: false,
            product_route_green: false,
            live_gemma_default_claim: false,
            e4b_or_12b_bypass_allowed: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            metadata_bytes: 144_000,
            rollback_ref:
                "rollback:gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate"
                    .to_string(),
            run_event_log_ref:
                "run_event_log:gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate"
                    .to_string(),
            answer_packet_ref:
                "answer_packet:gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate"
                    .to_string(),
            abstention_ref:
                "abstention:gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate"
                    .to_string(),
            status:
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateStatus::ReconciliationContractOnly,
            next_cursor:
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_NEXT_CURSOR
                    .to_string(),
        }
    }

    pub fn validate(
        &self,
    ) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError> {
        if !self
            .upstream_owner_approved_probe_ref
            .starts_with(UPSTREAM_OWNER_APPROVED_PROBE_PREFIX)
            || self.upstream_probe_id != GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_ID
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::BadUpstreamRef,
            );
        }
        validate_exact(
            "upstream_model_file_digest_gate_ref",
            &self.upstream_model_file_digest_gate_ref,
            GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
        )?;
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "reconciliation_card_id",
            &self.reconciliation_card_id,
            RECONCILIATION_CARD_ID,
        )?;
        validate_exact(
            "future_runtime_artifact_name",
            &self.future_runtime_artifact_name,
            FUTURE_RUNTIME_ARTIFACT_NAME,
        )?;
        validate_unique_exact_set(
            "required_reconciliation_fields",
            &self.required_reconciliation_fields,
            REQUIRED_RECONCILIATION_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.source_revision != GEMMA_QAT_E2B_SOURCE_REVISION
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.expected_file_size_bytes != GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
            || self.command_path != GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::BadSelectedLane,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateStatus::ReconciliationContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::UnsafeState,
            );
        }
        if !self.owner_approval_digest_required
            || !self.owner_manifest_digest_required
            || !self.canonical_path_digest_required
            || !self.model_file_digest_match_required
            || !self.model_file_size_match_required
            || !self.llama_cpp_binary_digest_match_required
            || !self.llama_cpp_version_digest_match_required
            || !self.command_template_digest_match_required
            || !self.resolved_argv_digest_match_required
            || !self.environment_allowlist_match_required
            || !self.synthetic_prompt_digest_match_required
            || !self.first_token_digest_required
            || !self.first_token_redacted
            || self.first_token_quality_authority
            || !self.memory_samples_required
            || !self.timeout_bound
            || !self.cancellation_bound
            || !self.teardown_bound
            || !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::ProofBoundaryBroken,
            );
        }
        if self.future_runtime_artifact_present
            || self.future_runtime_artifact_bytes_read != 0
            || self.accepted_runtime_artifact_count != 0
            || self.reconciliation_performed_count != 0
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::ArtifactActionLeak,
            );
        }
        if self.path_canonicalization_attempts != 0
            || self.file_stat_attempts != 0
            || self.file_hash_attempts != 0
            || self.model_file_opened
            || self.llama_cpp_binary_opened
            || self.llama_cpp_version_executions != 0
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::FileActionLeak,
            );
        }
        if self.command_armed
            || self.command_executed
            || self.runtime_replay_performed
            || self.first_token_observed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::RuntimeActionLeak,
            );
        }
        if self.captured_raw_path_bytes != 0
            || self.captured_raw_prompt_bytes != 0
            || self.captured_raw_output_bytes != 0
            || self.captured_stdout_bytes != 0
            || self.captured_stderr_bytes != 0
            || self.captured_raw_token_bytes != 0
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::PrivacyLeak,
            );
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
            || self.t4_build_green_effect
            || self.product_route_green
            || self.live_gemma_default_claim
            || self.e4b_or_12b_bypass_allowed
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
            || self.quality_claimed
            || self.benchmark_claimed_as_fit
        {
            return Err(
                GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::PromotionClaim,
            );
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
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateMetrics {
        GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateMetrics {
            required_reconciliation_field_count: self.required_reconciliation_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            future_runtime_artifact_present_count: self.future_runtime_artifact_present as u64,
            future_runtime_artifact_bytes_read: self.future_runtime_artifact_bytes_read,
            accepted_runtime_artifact_count: self.accepted_runtime_artifact_count,
            reconciliation_performed_count: self.reconciliation_performed_count,
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
            captured_raw_token_bytes: self.captured_raw_token_bytes,
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
                || self.t4_build_green_effect
                || self.product_route_green
                || self.live_gemma_default_claim
                || self.e4b_or_12b_bypass_allowed
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim
                || self.quality_claimed
                || self.benchmark_claimed_as_fit) as u64,
        }
    }

    pub fn reconciliation_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_CURSOR
                    .to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_reconciliation_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-first-token-artifact-review-reconciliation:v1:{}:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_owner_approved_probe_ref,
            self.selected_model_id,
            self.source_revision,
            self.required_filename,
            self.expected_file_size_bytes,
            self.command_path,
            fields.join(","),
            policies.join(","),
            self.next_cursor,
        )
    }
}

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-reconciliation-gate:metrics
// Plane: Verification.
// Residency: reconciliation counters and zero-action ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateMetrics {
    pub required_reconciliation_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub future_runtime_artifact_present_count: u64,
    pub future_runtime_artifact_bytes_read: u64,
    pub accepted_runtime_artifact_count: u64,
    pub reconciliation_performed_count: u64,
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
    pub captured_raw_token_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_fields(
) -> Vec<String> {
    REQUIRED_RECONCILIATION_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_first_token_runtime_artifact_review_rejection_policies() -> Vec<String>
{
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-first-token-runtime-artifact-review-reconciliation-gate:error
// Plane: Verification.
// Residency: fail-closed reconciliation diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ArtifactActionLeak,
    FileActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream owner-approved probe reference"),
            Self::BadSelectedLane => f.write_str("bad selected Gemma E2B reconciliation lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe artifact reconciliation state"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::ArtifactActionLeak => f.write_str("artifact action leak"),
            Self::FileActionLeak => f.write_str("file action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::BadField(field_name))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_402_000_000;

    #[test]
    fn canonical_reconciliation_gate_validates_zero_actions() {
        let gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate::canonical(
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
        );
        gate.validate().expect("canonical gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_reconciliation_field_count, 36);
        assert_eq!(metrics.required_rejection_policy_count, 42);
        assert_eq!(metrics.future_runtime_artifact_present_count, 0);
        assert_eq!(metrics.future_runtime_artifact_bytes_read, 0);
        assert_eq!(metrics.reconciliation_performed_count, 0);
        assert_eq!(metrics.file_action_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.first_token_observed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn missing_required_reconciliation_fields_are_rejected() {
        let mut gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate::canonical(
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
        );
        gate.required_reconciliation_fields.pop();
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGateError::DuplicateOrMissingField(
                "required_reconciliation_fields"
            ))
        ));
    }

    #[test]
    fn artifact_runtime_privacy_and_promotion_actions_are_rejected() {
        let mutations: Vec<
            Box<dyn Fn(&mut GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate)>,
        > = vec![
            Box::new(|gate| gate.future_runtime_artifact_present = true),
            Box::new(|gate| gate.future_runtime_artifact_bytes_read = 1),
            Box::new(|gate| gate.reconciliation_performed_count = 1),
            Box::new(|gate| gate.model_file_opened = true),
            Box::new(|gate| gate.command_armed = true),
            Box::new(|gate| gate.runtime_replay_performed = true),
            Box::new(|gate| gate.first_token_observed = true),
            Box::new(|gate| gate.captured_raw_token_bytes = 1),
            Box::new(|gate| gate.first_token_quality_authority = true),
            Box::new(|gate| gate.product_route_green = true),
        ];
        for mutate in mutations {
            let mut gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate::canonical(
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
            );
            mutate(&mut gate);
            assert!(gate.validate().is_err());
        }
    }

    #[test]
    fn reconciliation_gate_address_is_order_deterministic() {
        let gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate::canonical(
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate {
            required_reconciliation_fields: gate
                .required_reconciliation_fields
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_rejection_policies: gate
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        gate.validate().expect("canonical gate should validate");
        reversed.validate().expect("reversed sets should validate");
        assert_eq!(
            gate.reconciliation_gate_address(CREATED_AT_MS),
            reversed.reconciliation_gate_address(CREATED_AT_MS)
        );
    }
}
