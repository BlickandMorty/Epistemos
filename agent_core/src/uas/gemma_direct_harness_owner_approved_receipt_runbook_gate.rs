//! Gemma direct harness owner-approved receipt runbook gate.
//!
//! This primitive consumes the dry-run receipt artifact contract and freezes
//! the owner-approved runbook shape for a future bounded Gemma `llama-cli`
//! receipt attempt. It is metadata-only: no runbook is read or written, no
//! owner path is opened, no command is armed, and no model/runtime bytes load.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedReceiptRunbookGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_receipt_runbook_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_receipt_preflight_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_direct_harness_receipt_emitter_dry_run_artifact_gate/result.json#F-GemmaDirectHarnessReceiptEmitterDryRunArtifactGate";

const UPSTREAM_DRY_RUN_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_receipt_emitter_dry_run_artifact_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_runbook_gate/";
const RUNBOOK_CARD_ID: &str = "gemma-direct-harness-owner-approved-receipt-runbook-gate-v1";
const FUTURE_RUNBOOK_NAME: &str = "owner-approved-gemma-direct-harness-receipt-runbook-v1";
const MAX_METADATA_BYTES: u64 = 224 * 1024;

const REQUIRED_RUNBOOK_FIELDS: &[&str] = &[
    "upstream_dry_run_artifact_digest",
    "runbook_schema_version",
    "owner_approval_phrase_digest",
    "owner_identity_scope_digest",
    "owner_path_manifest_digest_required",
    "model_file_sha256_required",
    "llama_cli_binary_sha256_required",
    "llama_cli_version_digest_required",
    "command_template_digest",
    "argv_allowlist_digest",
    "environment_allowlist_digest",
    "working_directory_policy_digest",
    "prompt_source_digest_policy",
    "grammar_or_json_schema_digest",
    "max_context_tokens",
    "max_predict_tokens",
    "seed_policy_digest",
    "timeout_budget_digest",
    "cancellation_channel_digest",
    "teardown_policy_digest",
    "stdout_digest_policy",
    "stderr_digest_policy",
    "first_token_redaction_policy",
    "memory_sampler_plan_digest",
    "timing_sampler_plan_digest",
    "temp_receipt_path_policy_digest",
    "atomic_write_policy_digest",
    "cleanup_policy_digest",
    "run_event_log_ref",
    "answer_packet_ref",
    "rollback_ref",
    "abstention_ref",
    "human_visible_confirmation_digest",
    "no_promotion_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_dry_run_artifact",
    "missing_owner_approval_phrase",
    "missing_owner_identity_scope",
    "missing_owner_path_manifest_digest",
    "missing_model_file_sha256",
    "missing_llama_cli_binary_sha256",
    "missing_llama_cli_version_digest",
    "missing_command_template",
    "missing_argv_allowlist",
    "missing_environment_allowlist",
    "missing_working_directory_policy",
    "missing_prompt_source_digest_policy",
    "missing_grammar_digest",
    "context_tokens_unbounded",
    "predict_tokens_unbounded",
    "missing_seed_policy",
    "missing_timeout_budget",
    "missing_cancellation_channel",
    "missing_teardown_policy",
    "missing_stdout_digest_policy",
    "missing_stderr_digest_policy",
    "missing_first_token_redaction",
    "missing_memory_sampler_plan",
    "missing_timing_sampler_plan",
    "missing_temp_receipt_path_policy",
    "missing_atomic_write_policy",
    "missing_cleanup_policy",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_rollback",
    "missing_abstention",
    "missing_human_visible_confirmation",
    "missing_no_promotion",
    "runbook_written",
    "runbook_read",
    "owner_path_opened",
    "model_file_opened",
    "llama_cli_opened",
    "command_armed",
    "command_executed",
    "raw_path_retained",
    "raw_prompt_retained",
    "runtime_router_mutation",
    "hidden_authority",
    "l2_l3_t4_claim",
    "live_gemma_claim",
];

// UAS: uas:gemma-direct-harness-owner-approved-receipt-runbook-gate:status
// Plane: Verification.
// Residency: metadata-only runbook contract; no runbook/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedReceiptRunbookGateStatus {
    RunbookContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-runbook-gate:spec
// Plane: Controller + Verification.
// Residency: future owner-approved runbook only; no write/read/command action.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedReceiptRunbookGate {
    pub upstream_dry_run_artifact_ref: String,
    pub upstream_dry_run_artifact_id: String,
    pub artifact_root_prefix: String,
    pub runbook_card_id: String,
    pub future_runbook_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_runbook_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_approval_phrase_digest_required: bool,
    pub owner_identity_scope_digest_required: bool,
    pub owner_path_manifest_digest_required: bool,
    pub model_file_sha256_required: bool,
    pub llama_cli_binary_sha256_required: bool,
    pub llama_cli_version_digest_required: bool,
    pub command_template_digest_required: bool,
    pub argv_environment_workdir_policy_required: bool,
    pub prompt_and_grammar_digest_policy_required: bool,
    pub context_and_predict_caps_required: bool,
    pub seed_timeout_cancel_teardown_required: bool,
    pub stdout_stderr_redaction_policy_required: bool,
    pub memory_and_timing_sampler_required: bool,
    pub temp_atomic_cleanup_policy_required: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub rollback_bound: bool,
    pub abstention_bound: bool,
    pub human_visible_confirmation_required: bool,
    pub no_promotion_bound: bool,
    pub future_runbook_written_count: u64,
    pub future_runbook_bytes_written: u64,
    pub future_runbook_bytes_read: u64,
    pub owner_path_open_count: u64,
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
    pub status: GemmaDirectHarnessOwnerApprovedReceiptRunbookGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedReceiptRunbookGate {
    pub fn canonical() -> Self {
        Self {
            upstream_dry_run_artifact_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_UPSTREAM_REF.to_string(),
            upstream_dry_run_artifact_id:
                GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            runbook_card_id: RUNBOOK_CARD_ID.to_string(),
            future_runbook_name: FUTURE_RUNBOOK_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_runbook_fields: REQUIRED_RUNBOOK_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_phrase_digest_required: true,
            owner_identity_scope_digest_required: true,
            owner_path_manifest_digest_required: true,
            model_file_sha256_required: true,
            llama_cli_binary_sha256_required: true,
            llama_cli_version_digest_required: true,
            command_template_digest_required: true,
            argv_environment_workdir_policy_required: true,
            prompt_and_grammar_digest_policy_required: true,
            context_and_predict_caps_required: true,
            seed_timeout_cancel_teardown_required: true,
            stdout_stderr_redaction_policy_required: true,
            memory_and_timing_sampler_required: true,
            temp_atomic_cleanup_policy_required: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            rollback_bound: true,
            abstention_bound: true,
            human_visible_confirmation_required: true,
            no_promotion_bound: true,
            future_runbook_written_count: 0,
            future_runbook_bytes_written: 0,
            future_runbook_bytes_read: 0,
            owner_path_open_count: 0,
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
            metadata_bytes: 188_000,
            status: GemmaDirectHarnessOwnerApprovedReceiptRunbookGateStatus::RunbookContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError> {
        if !self
            .upstream_dry_run_artifact_ref
            .starts_with(UPSTREAM_DRY_RUN_PREFIX)
            || self.upstream_dry_run_artifact_id
                != GEMMA_DIRECT_HARNESS_RECEIPT_EMITTER_DRY_RUN_ARTIFACT_GATE_ID
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("runbook_card_id", &self.runbook_card_id, RUNBOOK_CARD_ID)?;
        validate_exact(
            "future_runbook_name",
            &self.future_runbook_name,
            FUTURE_RUNBOOK_NAME,
        )?;
        validate_unique_exact_set(
            "required_runbook_fields",
            &self.required_runbook_fields,
            REQUIRED_RUNBOOK_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedReceiptRunbookGateStatus::RunbookContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::UnsafeState);
        }
        if !self.owner_approval_phrase_digest_required
            || !self.owner_identity_scope_digest_required
            || !self.owner_path_manifest_digest_required
            || !self.model_file_sha256_required
            || !self.llama_cli_binary_sha256_required
            || !self.llama_cli_version_digest_required
            || !self.command_template_digest_required
            || !self.argv_environment_workdir_policy_required
            || !self.prompt_and_grammar_digest_policy_required
            || !self.context_and_predict_caps_required
            || !self.seed_timeout_cancel_teardown_required
            || !self.stdout_stderr_redaction_policy_required
            || !self.memory_and_timing_sampler_required
            || !self.temp_atomic_cleanup_policy_required
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.rollback_bound
            || !self.abstention_bound
            || !self.human_visible_confirmation_required
            || !self.no_promotion_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::ProofBoundaryBroken,
            );
        }
        if self.future_runbook_written_count != 0
            || self.future_runbook_bytes_written != 0
            || self.future_runbook_bytes_read != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::RunbookActionLeak);
        }
        if self.owner_path_open_count != 0
            || self.command_armed
            || self.command_executed
            || self.model_file_opened
            || self.llama_cli_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::RuntimeActionLeak);
        }
        if self.raw_owner_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::PrivacyLeak);
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
            return Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedReceiptRunbookGateMetrics {
        GemmaDirectHarnessOwnerApprovedReceiptRunbookGateMetrics {
            required_runbook_field_count: self.required_runbook_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            future_runbook_written_count: self.future_runbook_written_count,
            future_runbook_bytes_written: self.future_runbook_bytes_written,
            future_runbook_bytes_read: self.future_runbook_bytes_read,
            owner_path_open_count: self.owner_path_open_count,
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

    pub fn runbook_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_runbook_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-owner-approved-receipt-runbook-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_dry_run_artifact_ref,
            self.upstream_dry_run_artifact_id,
            self.future_runbook_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-runbook-gate:metrics
// Plane: Verification.
// Residency: zero-action runbook counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedReceiptRunbookGateMetrics {
    pub required_runbook_field_count: u64,
    pub required_abort_condition_count: u64,
    pub future_runbook_written_count: u64,
    pub future_runbook_bytes_written: u64,
    pub future_runbook_bytes_read: u64,
    pub owner_path_open_count: u64,
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

pub fn required_gemma_direct_harness_owner_approved_runbook_fields() -> Vec<String> {
    REQUIRED_RUNBOOK_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_owner_approved_runbook_abort_conditions() -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-runbook-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    RunbookActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream dry-run artifact reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe runbook gate state"),
            Self::ProofBoundaryBroken => f.write_str("runbook proof boundary broken"),
            Self::RunbookActionLeak => f.write_str("runbook action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_668_000_000;

    #[test]
    fn canonical_runbook_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        gate.validate()
            .expect("canonical runbook gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_runbook_field_count, 34);
        assert_eq!(metrics.required_abort_condition_count, 46);
        assert_eq!(metrics.future_runbook_bytes_written, 0);
        assert_eq!(metrics.future_runbook_bytes_read, 0);
        assert_eq!(metrics.owner_path_open_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.file_open_count, 0);
        assert_eq!(metrics.raw_owner_path_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_required_runbook_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        gate.required_runbook_fields[0] = gate.required_runbook_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::DuplicateOrMissingField(
                    "required_runbook_fields"
                )
            )
        ));
    }

    #[test]
    fn runbook_or_command_action_is_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        gate.future_runbook_bytes_read = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::RunbookActionLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        gate.command_armed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_path_or_route_mutation_is_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        gate.raw_owner_path_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        gate.system_g_mutation_allowed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptRunbookGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedReceiptRunbookGate {
            required_runbook_fields: gate.required_runbook_fields.iter().cloned().rev().collect(),
            required_abort_conditions: gate
                .required_abort_conditions
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        reversed.validate().expect("reversed sets remain canonical");
        assert_eq!(
            gate.runbook_gate_address(CREATED_AT_MS),
            reversed.runbook_gate_address(CREATED_AT_MS)
        );
    }
}
