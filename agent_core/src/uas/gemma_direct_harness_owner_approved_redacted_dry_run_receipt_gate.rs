//! Gemma direct harness owner-approved redacted dry-run receipt gate.
//!
//! This primitive consumes the owner-approved command envelope gate and freezes
//! the digest-only receipt contract for a future bounded Gemma dry-run. It is
//! metadata-only: no receipt is written or read, no command is armed, no
//! process starts, no prompt/stdout/stderr/token bytes are retained, and no
//! model/runtime bytes load.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_token_digest_review_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_command_envelope_gate/result.json#F-GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate";

const UPSTREAM_COMMAND_ENVELOPE_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_command_envelope_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate/";
const RECEIPT_CARD_ID: &str =
    "gemma-direct-harness-owner-approved-redacted-dry-run-receipt-gate-v1";
const FUTURE_RECEIPT_NAME: &str = "owner-approved-gemma-direct-harness-redacted-dry-run-receipt-v1";
const MAX_METADATA_BYTES: u64 = 256 * 1024;

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "upstream_command_envelope_artifact_digest",
    "receipt_schema_version",
    "owner_approval_digest",
    "command_envelope_digest",
    "model_identity_digest",
    "llama_cli_identity_digest",
    "exit_status_digest_policy",
    "timeout_cancel_teardown_digest",
    "stdout_digest_policy",
    "stderr_digest_policy",
    "first_token_digest_policy",
    "prompt_digest_policy",
    "redaction_map_digest",
    "output_byte_cap_digest",
    "token_byte_cap_digest",
    "memory_sample_digest",
    "timing_sample_digest",
    "temp_path_digest_policy",
    "atomic_write_policy_digest",
    "cleanup_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "human_visible_confirmation_digest",
    "no_route_mutation_digest",
    "no_quality_claim_digest",
    "no_l2_l3_t4_or_default_claim_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_command_envelope",
    "missing_owner_approval",
    "missing_command_envelope_digest",
    "missing_model_identity_digest",
    "missing_llama_cli_identity_digest",
    "missing_exit_status_policy",
    "missing_timeout_cancel_teardown",
    "missing_stdout_digest_policy",
    "missing_stderr_digest_policy",
    "missing_first_token_digest_policy",
    "missing_prompt_digest_policy",
    "missing_redaction_map",
    "missing_output_byte_cap",
    "missing_token_byte_cap",
    "missing_memory_sample",
    "missing_timing_sample",
    "missing_temp_path_policy",
    "missing_atomic_write_policy",
    "missing_cleanup",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_abstention",
    "missing_human_visible_confirmation",
    "missing_no_route_mutation",
    "missing_no_quality_claim",
    "missing_no_l2_l3_t4_or_default_claim",
    "receipt_written",
    "receipt_read",
    "temp_path_opened",
    "owner_path_opened",
    "model_file_opened",
    "llama_cli_opened",
    "command_armed",
    "command_executed",
    "process_spawned",
    "raw_prompt_retained",
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
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-direct-harness-owner-approved-redacted-dry-run-receipt-gate:status
// Plane: Verification.
// Residency: metadata-only receipt contract; no receipt/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateStatus {
    RedactedReceiptContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-redacted-dry-run-receipt-gate:spec
// Plane: Controller + Verification.
// Residency: future redacted receipt contract only; no execution.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate {
    pub upstream_command_envelope_ref: String,
    pub upstream_command_envelope_id: String,
    pub artifact_root_prefix: String,
    pub receipt_card_id: String,
    pub future_receipt_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_receipt_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_and_identity_digests_required: bool,
    pub exit_timeout_teardown_required: bool,
    pub stdout_stderr_digest_policy_required: bool,
    pub first_token_digest_policy_required: bool,
    pub prompt_digest_policy_required: bool,
    pub redaction_and_byte_caps_required: bool,
    pub memory_and_timing_samples_required: bool,
    pub temp_atomic_cleanup_required: bool,
    pub rollback_log_packet_abstention_required: bool,
    pub human_confirmation_required: bool,
    pub no_route_mutation_bound: bool,
    pub no_quality_claim_bound: bool,
    pub no_l2_l3_t4_default_claim_bound: bool,
    pub future_receipt_written_count: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub temp_path_open_count: u64,
    pub owner_path_open_count: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
    pub model_file_opened: bool,
    pub llama_cli_opened: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
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
    pub status: GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate {
    pub fn canonical() -> Self {
        Self {
            upstream_command_envelope_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_UPSTREAM_REF
                    .to_string(),
            upstream_command_envelope_id:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            receipt_card_id: RECEIPT_CARD_ID.to_string(),
            future_receipt_name: FUTURE_RECEIPT_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_and_identity_digests_required: true,
            exit_timeout_teardown_required: true,
            stdout_stderr_digest_policy_required: true,
            first_token_digest_policy_required: true,
            prompt_digest_policy_required: true,
            redaction_and_byte_caps_required: true,
            memory_and_timing_samples_required: true,
            temp_atomic_cleanup_required: true,
            rollback_log_packet_abstention_required: true,
            human_confirmation_required: true,
            no_route_mutation_bound: true,
            no_quality_claim_bound: true,
            no_l2_l3_t4_default_claim_bound: true,
            future_receipt_written_count: 0,
            future_receipt_bytes_written: 0,
            future_receipt_bytes_read: 0,
            temp_path_open_count: 0,
            owner_path_open_count: 0,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
            model_file_opened: false,
            llama_cli_opened: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
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
            metadata_bytes: 208_000,
            status:
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateStatus::RedactedReceiptContractOnly,
            next_cursor:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_NEXT_CURSOR
                    .to_string(),
        }
    }

    pub fn validate(
        &self,
    ) -> Result<(), GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError> {
        if !self
            .upstream_command_envelope_ref
            .starts_with(UPSTREAM_COMMAND_ENVELOPE_PREFIX)
            || self.upstream_command_envelope_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_COMMAND_ENVELOPE_GATE_ID
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::BadUpstreamRef,
            );
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("receipt_card_id", &self.receipt_card_id, RECEIPT_CARD_ID)?;
        validate_exact(
            "future_receipt_name",
            &self.future_receipt_name,
            FUTURE_RECEIPT_NAME,
        )?;
        validate_unique_exact_set(
            "required_receipt_fields",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateStatus::RedactedReceiptContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::UnsafeState);
        }
        if !self.owner_and_identity_digests_required
            || !self.exit_timeout_teardown_required
            || !self.stdout_stderr_digest_policy_required
            || !self.first_token_digest_policy_required
            || !self.prompt_digest_policy_required
            || !self.redaction_and_byte_caps_required
            || !self.memory_and_timing_samples_required
            || !self.temp_atomic_cleanup_required
            || !self.rollback_log_packet_abstention_required
            || !self.human_confirmation_required
            || !self.no_route_mutation_bound
            || !self.no_quality_claim_bound
            || !self.no_l2_l3_t4_default_claim_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::ProofBoundaryBroken,
            );
        }
        if self.future_receipt_written_count != 0
            || self.future_receipt_bytes_written != 0
            || self.future_receipt_bytes_read != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::ReceiptActionLeak,
            );
        }
        if self.temp_path_open_count != 0
            || self.owner_path_open_count != 0
            || self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.model_file_opened
            || self.llama_cli_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::RuntimeActionLeak,
            );
        }
        if self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::PrivacyLeak);
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
            return Err(
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::PromotionClaim,
            );
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateMetrics {
        GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateMetrics {
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            future_receipt_written_count: self.future_receipt_written_count,
            future_receipt_bytes_written: self.future_receipt_bytes_written,
            future_receipt_bytes_read: self.future_receipt_bytes_read,
            temp_path_open_count: self.temp_path_open_count,
            owner_path_open_count: self.owner_path_open_count,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
            file_open_count: (self.model_file_opened || self.llama_cli_opened) as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
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

    pub fn redacted_receipt_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_CURSOR
                    .to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_receipt_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-owner-approved-redacted-dry-run-receipt-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_command_envelope_ref,
            self.upstream_command_envelope_id,
            self.future_receipt_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-redacted-dry-run-receipt-gate:metrics
// Plane: Verification.
// Residency: zero-action redacted receipt counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateMetrics {
    pub required_receipt_field_count: u64,
    pub required_abort_condition_count: u64,
    pub future_receipt_written_count: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub temp_path_open_count: u64,
    pub owner_path_open_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub file_open_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_owner_approved_redacted_receipt_fields() -> Vec<String> {
    REQUIRED_RECEIPT_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_owner_approved_redacted_receipt_abort_conditions(
) -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-owner-approved-redacted-dry-run-receipt-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError {
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

impl fmt::Display for GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream command envelope reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe redacted dry-run receipt gate state"),
            Self::ProofBoundaryBroken => f.write_str("redacted receipt proof boundary broken"),
            Self::ReceiptActionLeak => f.write_str("receipt action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_754_400_000;

    #[test]
    fn canonical_redacted_receipt_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        gate.validate()
            .expect("canonical redacted receipt gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_receipt_field_count, 28);
        assert_eq!(metrics.required_abort_condition_count, 51);
        assert_eq!(metrics.future_receipt_bytes_written, 0);
        assert_eq!(metrics.future_receipt_bytes_read, 0);
        assert_eq!(metrics.temp_path_open_count, 0);
        assert_eq!(metrics.owner_path_open_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.process_spawned_count, 0);
        assert_eq!(metrics.raw_stdout_bytes, 0);
        assert_eq!(metrics.raw_token_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_receipt_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        gate.required_receipt_fields[0] = gate.required_receipt_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::DuplicateOrMissingField(
                    "required_receipt_fields"
                )
            )
        ));
    }

    #[test]
    fn receipt_or_runtime_actions_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        gate.future_receipt_bytes_written = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::ReceiptActionLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        gate.command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_bytes_or_promotion_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        gate.raw_token_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        gate.l2_capability_effect = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate {
            required_receipt_fields: gate.required_receipt_fields.iter().cloned().rev().collect(),
            required_abort_conditions: gate
                .required_abort_conditions
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        assert_eq!(
            gate.redacted_receipt_gate_address(CREATED_AT_MS),
            reversed.redacted_receipt_gate_address(CREATED_AT_MS)
        );
    }
}
