//! Gemma direct harness owner-approved command envelope gate.
//!
//! This primitive consumes the owner-approved preflight packet gate and freezes
//! the inert command envelope contract required before a future bounded Gemma
//! `llama-cli` dry-run receipt can approach execution. It is metadata-only: no
//! command is armed, no process starts, no owner/model/runtime path is opened,
//! no prompt/output bytes are retained, and no route is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_command_envelope_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_receipt_preflight_packet_gate/result.json#F-GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate";

const UPSTREAM_PREFLIGHT_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_receipt_preflight_packet_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_command_envelope_gate/";
const COMMAND_ENVELOPE_ID: &str = "gemma-direct-harness-owner-approved-command-envelope-gate-v1";
const FUTURE_COMMAND_ENVELOPE_NAME: &str =
    "owner-approved-gemma-direct-harness-command-envelope-v1";
const MAX_METADATA_BYTES: u64 = 256 * 1024;

const REQUIRED_COMMAND_ENVELOPE_FIELDS: &[&str] = &[
    "upstream_preflight_artifact_digest",
    "command_envelope_schema_version",
    "owner_approval_digest",
    "owner_path_manifest_digest",
    "canonical_path_digest",
    "model_file_sha256",
    "llama_cli_binary_sha256",
    "llama_cli_version_digest",
    "hardware_profile_digest",
    "memory_fit_verdict_digest",
    "command_template_digest",
    "argv_vector_digest",
    "argv_allowlist_digest",
    "environment_allowlist_digest",
    "workdir_digest_policy",
    "no_shell_string_digest",
    "no_network_digest",
    "no_hub_download_digest",
    "prompt_digest_policy",
    "grammar_digest",
    "timeout_ms_digest",
    "cancellation_digest",
    "teardown_digest",
    "stdout_redaction_digest",
    "stderr_redaction_digest",
    "output_byte_cap_digest",
    "token_digest_policy",
    "memory_sampler_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "human_visible_confirmation_digest",
    "no_execution_digest",
    "no_promotion_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_preflight_packet",
    "missing_owner_approval",
    "missing_owner_path_manifest",
    "missing_canonical_path_digest",
    "missing_model_file_sha256",
    "missing_llama_cli_binary_sha256",
    "missing_llama_cli_version_digest",
    "missing_hardware_profile",
    "missing_memory_fit_verdict",
    "missing_command_template",
    "missing_argv_vector",
    "missing_argv_allowlist",
    "missing_environment_allowlist",
    "missing_workdir_policy",
    "shell_string_present",
    "network_allowed",
    "hub_download_allowed",
    "missing_prompt_digest_policy",
    "missing_grammar_digest",
    "missing_timeout",
    "missing_cancellation",
    "missing_teardown",
    "missing_stdout_redaction",
    "missing_stderr_redaction",
    "missing_output_byte_cap",
    "missing_token_digest_policy",
    "missing_memory_sampler",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_abstention",
    "missing_human_visible_confirmation",
    "missing_no_execution",
    "missing_no_promotion",
    "command_envelope_written",
    "command_envelope_read",
    "owner_path_opened",
    "model_file_opened",
    "llama_cli_opened",
    "command_armed",
    "command_executed",
    "process_spawned",
    "stdout_captured_raw",
    "stderr_captured_raw",
    "prompt_retained_raw",
    "output_retained_raw",
    "token_retained_raw",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "runtime_router_mutation",
    "system_g_mutation",
    "settings_default_mutation",
    "hidden_authority",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-direct-harness-owner-approved-command-envelope-gate:status
// Plane: Verification.
// Residency: metadata-only command envelope contract; no command bytes execute.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateStatus {
    CommandEnvelopeContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-command-envelope-gate:spec
// Plane: Controller + Verification.
// Residency: future owner-approved unarmed command envelope only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate {
    pub upstream_preflight_ref: String,
    pub upstream_preflight_id: String,
    pub artifact_root_prefix: String,
    pub command_envelope_id: String,
    pub future_command_envelope_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_command_envelope_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_and_path_digests_required: bool,
    pub model_and_llama_digests_required: bool,
    pub hardware_and_memory_verdict_required: bool,
    pub argv_and_env_allowlists_required: bool,
    pub shell_string_denied: bool,
    pub network_and_hub_download_denied: bool,
    pub prompt_and_grammar_digest_required: bool,
    pub timeout_cancel_teardown_required: bool,
    pub stdio_redaction_required: bool,
    pub output_byte_cap_required: bool,
    pub token_digest_policy_required: bool,
    pub memory_sampler_required: bool,
    pub rollback_log_packet_abstention_required: bool,
    pub human_confirmation_required: bool,
    pub no_execution_bound: bool,
    pub no_promotion_bound: bool,
    pub future_command_envelope_written_count: u64,
    pub future_command_envelope_bytes_written: u64,
    pub future_command_envelope_bytes_read: u64,
    pub owner_path_open_count: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
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
    pub status: GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate {
    pub fn canonical() -> Self {
        Self {
            upstream_preflight_ref: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_UPSTREAM_REF.to_string(),
            upstream_preflight_id:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            command_envelope_id: COMMAND_ENVELOPE_ID.to_string(),
            future_command_envelope_name: FUTURE_COMMAND_ENVELOPE_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_command_envelope_fields: REQUIRED_COMMAND_ENVELOPE_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_and_path_digests_required: true,
            model_and_llama_digests_required: true,
            hardware_and_memory_verdict_required: true,
            argv_and_env_allowlists_required: true,
            shell_string_denied: true,
            network_and_hub_download_denied: true,
            prompt_and_grammar_digest_required: true,
            timeout_cancel_teardown_required: true,
            stdio_redaction_required: true,
            output_byte_cap_required: true,
            token_digest_policy_required: true,
            memory_sampler_required: true,
            rollback_log_packet_abstention_required: true,
            human_confirmation_required: true,
            no_execution_bound: true,
            no_promotion_bound: true,
            future_command_envelope_written_count: 0,
            future_command_envelope_bytes_written: 0,
            future_command_envelope_bytes_read: 0,
            owner_path_open_count: 0,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
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
            metadata_bytes: 204_000,
            status:
                GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateStatus::CommandEnvelopeContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError> {
        if !self
            .upstream_preflight_ref
            .starts_with(UPSTREAM_PREFLIGHT_PREFIX)
            || self.upstream_preflight_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_ID
        {
            return Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "command_envelope_id",
            &self.command_envelope_id,
            COMMAND_ENVELOPE_ID,
        )?;
        validate_exact(
            "future_command_envelope_name",
            &self.future_command_envelope_name,
            FUTURE_COMMAND_ENVELOPE_NAME,
        )?;
        validate_unique_exact_set(
            "required_command_envelope_fields",
            &self.required_command_envelope_fields,
            REQUIRED_COMMAND_ENVELOPE_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateStatus::CommandEnvelopeContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::UnsafeState);
        }
        if !self.owner_and_path_digests_required
            || !self.model_and_llama_digests_required
            || !self.hardware_and_memory_verdict_required
            || !self.argv_and_env_allowlists_required
            || !self.shell_string_denied
            || !self.network_and_hub_download_denied
            || !self.prompt_and_grammar_digest_required
            || !self.timeout_cancel_teardown_required
            || !self.stdio_redaction_required
            || !self.output_byte_cap_required
            || !self.token_digest_policy_required
            || !self.memory_sampler_required
            || !self.rollback_log_packet_abstention_required
            || !self.human_confirmation_required
            || !self.no_execution_bound
            || !self.no_promotion_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::ProofBoundaryBroken,
            );
        }
        if self.future_command_envelope_written_count != 0
            || self.future_command_envelope_bytes_written != 0
            || self.future_command_envelope_bytes_read != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::CommandEnvelopeActionLeak,
            );
        }
        if self.owner_path_open_count != 0
            || self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.model_file_opened
            || self.llama_cli_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::RuntimeActionLeak);
        }
        if self.raw_owner_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::PrivacyLeak);
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
            return Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateMetrics {
        GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateMetrics {
            required_command_envelope_field_count: self.required_command_envelope_fields.len()
                as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            future_command_envelope_written_count: self.future_command_envelope_written_count,
            future_command_envelope_bytes_written: self.future_command_envelope_bytes_written,
            future_command_envelope_bytes_read: self.future_command_envelope_bytes_read,
            owner_path_open_count: self.owner_path_open_count,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
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

    pub fn command_envelope_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_command_envelope_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-owner-approved-command-envelope-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_preflight_ref,
            self.upstream_preflight_id,
            self.future_command_envelope_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-command-envelope-gate:metrics
// Plane: Verification.
// Residency: zero-action command envelope counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateMetrics {
    pub required_command_envelope_field_count: u64,
    pub required_abort_condition_count: u64,
    pub future_command_envelope_written_count: u64,
    pub future_command_envelope_bytes_written: u64,
    pub future_command_envelope_bytes_read: u64,
    pub owner_path_open_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
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

pub fn required_gemma_direct_harness_owner_approved_command_envelope_fields() -> Vec<String> {
    REQUIRED_COMMAND_ENVELOPE_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_owner_approved_command_envelope_abort_conditions(
) -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-owner-approved-command-envelope-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    CommandEnvelopeActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream preflight packet reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe command envelope gate state"),
            Self::ProofBoundaryBroken => f.write_str("command envelope proof boundary broken"),
            Self::CommandEnvelopeActionLeak => f.write_str("command envelope action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_754_400_000;

    #[test]
    fn canonical_command_envelope_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        gate.validate()
            .expect("canonical command envelope gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_command_envelope_field_count, 35);
        assert_eq!(metrics.required_abort_condition_count, 58);
        assert_eq!(metrics.future_command_envelope_bytes_written, 0);
        assert_eq!(metrics.future_command_envelope_bytes_read, 0);
        assert_eq!(metrics.owner_path_open_count, 0);
        assert_eq!(metrics.command_armed_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.process_spawned_count, 0);
        assert_eq!(metrics.file_open_count, 0);
        assert_eq!(metrics.raw_owner_path_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_command_envelope_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        gate.required_command_envelope_fields[0] = gate.required_command_envelope_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::DuplicateOrMissingField(
                    "required_command_envelope_fields"
                )
            )
        ));
    }

    #[test]
    fn command_or_process_action_is_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        gate.future_command_envelope_bytes_read = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::CommandEnvelopeActionLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        gate.process_spawned = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_bytes_or_route_mutation_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        gate.raw_stdout_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        gate.system_g_mutation_allowed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedCommandEnvelopeGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate {
            required_command_envelope_fields: gate
                .required_command_envelope_fields
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
            gate.command_envelope_gate_address(CREATED_AT_MS),
            reversed.command_envelope_gate_address(CREATED_AT_MS)
        );
    }
}
