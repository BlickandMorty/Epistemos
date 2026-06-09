//! Gemma direct harness receipt-emitter dry-run artifact gate.
//!
//! This primitive consumes the owner-approved receipt-emitter contract and
//! freezes the digest-only shape of a future dry-run receipt artifact. It is
//! metadata-only in the default loop: no artifact or receipt is written or
//! read, no model/runtime file is opened, and no command is armed or executed.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_ID: &str =
    "F-GemmaDirectHarnessReceiptEmitterDryRunArtifactGate";
pub const GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_CURSOR: &str =
    "gemma_direct_harness_receipt_emitter_dry_run_artifact_gate";
pub const GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_receipt_runbook_gate";
pub const GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/result.json#F-GemmaDirectHarnessOwnerApprovedReceiptEmitterGate";

const UPSTREAM_EMITTER_GATE_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_receipt_emitter_dry_run_artifact_gate/";
const DRY_RUN_ARTIFACT_CARD_ID: &str =
    "gemma-direct-harness-receipt-emitter-dry-run-artifact-gate-v1";
const FUTURE_DRY_RUN_ARTIFACT_NAME: &str =
    "gemma-direct-harness-owner-approved-receipt-dry-run-artifact-v1";
const FUTURE_EXECUTION_RECEIPT_NAME: &str = "owner-approved-gemma-direct-harness-receipt-v1";
const MAX_METADATA_BYTES: u64 = 224 * 1024;

const REQUIRED_DRY_RUN_ARTIFACT_FIELDS: &[&str] = &[
    "upstream_emitter_gate_artifact_digest",
    "dry_run_schema_version",
    "dry_run_artifact_id",
    "dry_run_artifact_digest",
    "owner_approval_digest_placeholder",
    "owner_path_manifest_digest_placeholder",
    "model_file_sha256_placeholder",
    "llama_cli_binary_sha256_placeholder",
    "llama_cli_version_digest_placeholder",
    "command_template_digest",
    "resolved_argv_digest_placeholder",
    "environment_allowlist_digest",
    "working_directory_digest_placeholder",
    "prompt_file_digest_placeholder",
    "grammar_or_json_schema_digest",
    "process_policy_digest",
    "timeout_budget_digest",
    "cancel_teardown_policy_digest",
    "stdout_digest_policy",
    "stderr_digest_policy",
    "first_token_redaction_policy_digest",
    "memory_sampler_plan_digest",
    "timing_sampler_plan_digest",
    "temp_receipt_path_policy_digest",
    "atomic_write_plan_digest",
    "cleanup_plan_digest",
    "run_event_log_ref",
    "answer_packet_ref",
    "rollback_ref",
    "abstention_ref",
    "receipt_non_promotion_digest",
    "dry_run_kind",
    "future_execution_receipt_name",
    "artifact_reader_policy_digest",
    "artifact_retention_policy_digest",
    "no_route_mutation_digest",
];

const REQUIRED_DRY_RUN_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_emitter_gate",
    "missing_schema_version",
    "missing_dry_run_artifact_id",
    "missing_dry_run_artifact_digest",
    "missing_owner_approval_placeholder",
    "missing_owner_path_manifest_placeholder",
    "missing_model_digest_placeholder",
    "missing_llama_cli_digest_placeholder",
    "missing_llama_cli_version_placeholder",
    "missing_command_template",
    "missing_argv_placeholder",
    "missing_environment_allowlist",
    "missing_workdir_placeholder",
    "missing_prompt_placeholder",
    "missing_grammar_digest",
    "missing_process_policy",
    "missing_timeout_budget",
    "missing_cancel_teardown",
    "missing_stdio_policy",
    "missing_token_redaction",
    "missing_memory_sampler_plan",
    "missing_timing_sampler_plan",
    "missing_temp_receipt_path_policy",
    "missing_atomic_write_plan",
    "missing_cleanup_plan",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_rollback",
    "missing_abstention",
    "missing_non_promotion",
    "dry_run_artifact_written",
    "dry_run_artifact_read",
    "receipt_written",
    "receipt_read",
    "command_armed",
    "command_executed",
    "model_file_opened",
    "llama_cli_opened",
    "raw_path_retained",
    "raw_prompt_retained",
    "raw_output_retained",
    "runtime_router_mutation",
    "system_g_mutation",
    "hidden_authority",
    "live_gemma_claim",
    "l2_l3_t4_claim",
];

// UAS: uas:gemma-direct-harness-receipt-emitter-dry-run-artifact-gate:status
// Plane: Verification.
// Residency: metadata-only dry-run artifact contract; no artifact bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessReceiptEmitterDryRunArtifactGateStatus {
    DryRunArtifactContractOnly,
}

// UAS: uas:gemma-direct-harness-receipt-emitter-dry-run-artifact-gate:spec
// Plane: Controller + Verification.
// Residency: future dry-run artifact shape; no write/read/command action.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessReceiptEmitterDryRunArtifactGate {
    pub upstream_emitter_gate_ref: String,
    pub upstream_emitter_gate_id: String,
    pub artifact_root_prefix: String,
    pub dry_run_artifact_card_id: String,
    pub future_dry_run_artifact_name: String,
    pub future_execution_receipt_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_dry_run_artifact_fields: Vec<String>,
    pub required_dry_run_abort_conditions: Vec<String>,
    pub upstream_emitter_gate_digest_required: bool,
    pub dry_run_schema_version_required: bool,
    pub dry_run_artifact_digest_required: bool,
    pub owner_approval_placeholder_required: bool,
    pub owner_path_manifest_placeholder_required: bool,
    pub model_file_digest_placeholder_required: bool,
    pub llama_cli_binary_digest_placeholder_required: bool,
    pub llama_cli_version_digest_placeholder_required: bool,
    pub command_template_digest_required: bool,
    pub argv_placeholder_digest_required: bool,
    pub environment_allowlist_digest_required: bool,
    pub working_directory_placeholder_digest_required: bool,
    pub prompt_file_placeholder_digest_required: bool,
    pub grammar_or_json_schema_digest_required: bool,
    pub process_policy_digest_required: bool,
    pub timeout_budget_digest_required: bool,
    pub cancel_teardown_policy_digest_required: bool,
    pub stdout_stderr_digest_policy_required: bool,
    pub first_token_redaction_policy_required: bool,
    pub memory_sampler_plan_required: bool,
    pub timing_sampler_plan_required: bool,
    pub temp_receipt_path_policy_required: bool,
    pub atomic_write_plan_required: bool,
    pub cleanup_plan_required: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub rollback_bound: bool,
    pub abstention_bound: bool,
    pub non_promotion_bound: bool,
    pub future_dry_run_artifact_written_count: u64,
    pub future_dry_run_artifact_bytes_written: u64,
    pub future_dry_run_artifact_bytes_read: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub model_file_opened: bool,
    pub llama_cli_opened: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_owner_path_bytes: u64,
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
    pub status: GemmaDirectHarnessReceiptEmitterDryRunArtifactGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessReceiptEmitterDryRunArtifactGate {
    pub fn canonical() -> Self {
        Self {
            upstream_emitter_gate_ref:
                GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_UPSTREAM_REF.to_string(),
            upstream_emitter_gate_id: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            dry_run_artifact_card_id: DRY_RUN_ARTIFACT_CARD_ID.to_string(),
            future_dry_run_artifact_name: FUTURE_DRY_RUN_ARTIFACT_NAME.to_string(),
            future_execution_receipt_name: FUTURE_EXECUTION_RECEIPT_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_dry_run_artifact_fields: REQUIRED_DRY_RUN_ARTIFACT_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_dry_run_abort_conditions: REQUIRED_DRY_RUN_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_emitter_gate_digest_required: true,
            dry_run_schema_version_required: true,
            dry_run_artifact_digest_required: true,
            owner_approval_placeholder_required: true,
            owner_path_manifest_placeholder_required: true,
            model_file_digest_placeholder_required: true,
            llama_cli_binary_digest_placeholder_required: true,
            llama_cli_version_digest_placeholder_required: true,
            command_template_digest_required: true,
            argv_placeholder_digest_required: true,
            environment_allowlist_digest_required: true,
            working_directory_placeholder_digest_required: true,
            prompt_file_placeholder_digest_required: true,
            grammar_or_json_schema_digest_required: true,
            process_policy_digest_required: true,
            timeout_budget_digest_required: true,
            cancel_teardown_policy_digest_required: true,
            stdout_stderr_digest_policy_required: true,
            first_token_redaction_policy_required: true,
            memory_sampler_plan_required: true,
            timing_sampler_plan_required: true,
            temp_receipt_path_policy_required: true,
            atomic_write_plan_required: true,
            cleanup_plan_required: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            rollback_bound: true,
            abstention_bound: true,
            non_promotion_bound: true,
            future_dry_run_artifact_written_count: 0,
            future_dry_run_artifact_bytes_written: 0,
            future_dry_run_artifact_bytes_read: 0,
            future_receipt_bytes_written: 0,
            future_receipt_bytes_read: 0,
            command_armed: false,
            command_executed: false,
            model_file_opened: false,
            llama_cli_opened: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_owner_path_bytes: 0,
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
            metadata_bytes: 176_000,
            status:
                GemmaDirectHarnessReceiptEmitterDryRunArtifactGateStatus::DryRunArtifactContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError> {
        if !self
            .upstream_emitter_gate_ref
            .starts_with(UPSTREAM_EMITTER_GATE_PREFIX)
            || self.upstream_emitter_gate_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_ID
        {
            return Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "dry_run_artifact_card_id",
            &self.dry_run_artifact_card_id,
            DRY_RUN_ARTIFACT_CARD_ID,
        )?;
        validate_exact(
            "future_dry_run_artifact_name",
            &self.future_dry_run_artifact_name,
            FUTURE_DRY_RUN_ARTIFACT_NAME,
        )?;
        validate_exact(
            "future_execution_receipt_name",
            &self.future_execution_receipt_name,
            FUTURE_EXECUTION_RECEIPT_NAME,
        )?;
        validate_unique_exact_set(
            "required_dry_run_artifact_fields",
            &self.required_dry_run_artifact_fields,
            REQUIRED_DRY_RUN_ARTIFACT_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_dry_run_abort_conditions",
            &self.required_dry_run_abort_conditions,
            REQUIRED_DRY_RUN_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessReceiptEmitterDryRunArtifactGateStatus::DryRunArtifactContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::UnsafeState);
        }
        if !self.upstream_emitter_gate_digest_required
            || !self.dry_run_schema_version_required
            || !self.dry_run_artifact_digest_required
            || !self.owner_approval_placeholder_required
            || !self.owner_path_manifest_placeholder_required
            || !self.model_file_digest_placeholder_required
            || !self.llama_cli_binary_digest_placeholder_required
            || !self.llama_cli_version_digest_placeholder_required
            || !self.command_template_digest_required
            || !self.argv_placeholder_digest_required
            || !self.environment_allowlist_digest_required
            || !self.working_directory_placeholder_digest_required
            || !self.prompt_file_placeholder_digest_required
            || !self.grammar_or_json_schema_digest_required
            || !self.process_policy_digest_required
            || !self.timeout_budget_digest_required
            || !self.cancel_teardown_policy_digest_required
            || !self.stdout_stderr_digest_policy_required
            || !self.first_token_redaction_policy_required
            || !self.memory_sampler_plan_required
            || !self.timing_sampler_plan_required
            || !self.temp_receipt_path_policy_required
            || !self.atomic_write_plan_required
            || !self.cleanup_plan_required
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.rollback_bound
            || !self.abstention_bound
            || !self.non_promotion_bound
        {
            return Err(
                GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::ProofBoundaryBroken,
            );
        }
        if self.future_dry_run_artifact_written_count != 0
            || self.future_dry_run_artifact_bytes_written != 0
            || self.future_dry_run_artifact_bytes_read != 0
            || self.future_receipt_bytes_written != 0
            || self.future_receipt_bytes_read != 0
        {
            return Err(
                GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::ArtifactActionLeak,
            );
        }
        if self.command_armed
            || self.command_executed
            || self.model_file_opened
            || self.llama_cli_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::RuntimeActionLeak);
        }
        if self.raw_owner_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::PrivacyLeak);
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
            return Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessReceiptEmitterDryRunArtifactGateMetrics {
        GemmaDirectHarnessReceiptEmitterDryRunArtifactGateMetrics {
            required_dry_run_artifact_field_count: self.required_dry_run_artifact_fields.len()
                as u64,
            required_dry_run_abort_condition_count: self.required_dry_run_abort_conditions.len()
                as u64,
            future_dry_run_artifact_written_count: self.future_dry_run_artifact_written_count,
            future_dry_run_artifact_bytes_written: self.future_dry_run_artifact_bytes_written,
            future_dry_run_artifact_bytes_read: self.future_dry_run_artifact_bytes_read,
            future_receipt_bytes_written: self.future_receipt_bytes_written,
            future_receipt_bytes_read: self.future_receipt_bytes_read,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            file_open_count: (self.model_file_opened || self.llama_cli_opened) as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_owner_path_bytes: self.raw_owner_path_bytes,
            raw_prompt_bytes: self.raw_prompt_bytes,
            raw_output_bytes: self.raw_output_bytes,
            raw_stdout_bytes: self.raw_stdout_bytes,
            raw_stderr_bytes: self.raw_stderr_bytes,
            raw_token_bytes: self.raw_token_bytes,
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

    pub fn dry_run_artifact_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_dry_run_artifact_fields.clone();
        fields.sort();
        let mut aborts = self.required_dry_run_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-receipt-emitter-dry-run-artifact-gate:v1:{}:{}:{}:{}:{}:{}",
            self.upstream_emitter_gate_ref,
            self.upstream_emitter_gate_id,
            self.future_dry_run_artifact_name,
            self.future_execution_receipt_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-receipt-emitter-dry-run-artifact-gate:metrics
// Plane: Verification.
// Residency: zero-action dry-run artifact counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessReceiptEmitterDryRunArtifactGateMetrics {
    pub required_dry_run_artifact_field_count: u64,
    pub required_dry_run_abort_condition_count: u64,
    pub future_dry_run_artifact_written_count: u64,
    pub future_dry_run_artifact_bytes_written: u64,
    pub future_dry_run_artifact_bytes_read: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub file_open_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_owner_path_bytes: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_dry_run_artifact_fields() -> Vec<String> {
    REQUIRED_DRY_RUN_ARTIFACT_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_dry_run_abort_conditions() -> Vec<String> {
    REQUIRED_DRY_RUN_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-receipt-emitter-dry-run-artifact-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ArtifactActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream receipt-emitter gate reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe dry-run artifact gate state"),
            Self::ProofBoundaryBroken => f.write_str("dry-run artifact proof boundary broken"),
            Self::ArtifactActionLeak => f.write_str("dry-run artifact or receipt action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_581_600_000;

    #[test]
    fn canonical_dry_run_artifact_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        gate.validate()
            .expect("canonical dry-run artifact gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_dry_run_artifact_field_count, 36);
        assert_eq!(metrics.required_dry_run_abort_condition_count, 46);
        assert_eq!(metrics.future_dry_run_artifact_bytes_written, 0);
        assert_eq!(metrics.future_dry_run_artifact_bytes_read, 0);
        assert_eq!(metrics.future_receipt_bytes_written, 0);
        assert_eq!(metrics.future_receipt_bytes_read, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.file_open_count, 0);
        assert_eq!(metrics.raw_owner_path_bytes, 0);
        assert_eq!(metrics.raw_token_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_required_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        gate.required_dry_run_artifact_fields[0] = gate.required_dry_run_artifact_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::DuplicateOrMissingField(
                    "required_dry_run_artifact_fields"
                )
            )
        ));
    }

    #[test]
    fn artifact_write_or_command_execution_is_rejected() {
        let mut gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        gate.future_dry_run_artifact_bytes_written = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::ArtifactActionLeak)
        ));
        let mut gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        gate.command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_bytes_and_route_mutation_are_rejected() {
        let mut gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        gate.raw_owner_path_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        gate.runtime_router_mutation_allowed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessReceiptEmitterDryRunArtifactGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate::canonical();
        let reversed = GemmaDirectHarnessReceiptEmitterDryRunArtifactGate {
            required_dry_run_artifact_fields: gate
                .required_dry_run_artifact_fields
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_dry_run_abort_conditions: gate
                .required_dry_run_abort_conditions
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        reversed.validate().expect("reversed sets remain canonical");
        assert_eq!(
            gate.dry_run_artifact_gate_address(CREATED_AT_MS),
            reversed.dry_run_artifact_gate_address(CREATED_AT_MS)
        );
    }
}
