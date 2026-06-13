//! Gemma direct harness owner-approved receipt preflight packet gate.
//!
//! This primitive consumes the owner-approved runbook contract and freezes the
//! preflight packet shape required before a future bounded Gemma `llama-cli`
//! receipt attempt can approach execution. It is metadata-only: no preflight
//! packet is read or written, no owner/model/runtime path is opened, no command
//! is armed, and no model bytes load.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_receipt_preflight_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_command_envelope_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_direct_harness_owner_approved_receipt_runbook_gate/result.json#F-GemmaDirectHarnessOwnerApprovedReceiptRunbookGate";

const UPSTREAM_RUNBOOK_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_receipt_runbook_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_preflight_packet_gate/";
const PREFLIGHT_CARD_ID: &str =
    "gemma-direct-harness-owner-approved-receipt-preflight-packet-gate-v1";
const FUTURE_PREFLIGHT_PACKET_NAME: &str =
    "owner-approved-gemma-direct-harness-receipt-preflight-packet-v1";
const MAX_METADATA_BYTES: u64 = 240 * 1024;

const REQUIRED_PREFLIGHT_FIELDS: &[&str] = &[
    "upstream_runbook_artifact_digest",
    "preflight_schema_version",
    "owner_approval_digest",
    "owner_path_manifest_digest",
    "canonical_path_digest",
    "model_file_sha256_required",
    "llama_cli_binary_sha256_required",
    "llama_cli_version_digest_required",
    "hardware_profile_digest",
    "available_memory_sample_digest",
    "predicted_model_bytes",
    "predicted_kv_bytes",
    "predicted_runtime_workspace_bytes",
    "predicted_app_headroom_bytes",
    "memory_fit_verdict",
    "command_template_digest",
    "argv_allowlist_digest",
    "environment_allowlist_digest",
    "prompt_digest_policy",
    "grammar_digest",
    "timeout_cancel_teardown_digest",
    "stdio_redaction_digest",
    "memory_timing_sampler_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "human_visible_confirmation_digest",
    "no_command_arm_digest",
    "no_promotion_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_runbook",
    "missing_owner_approval",
    "missing_owner_path_manifest",
    "missing_canonical_path_digest",
    "missing_model_file_sha256",
    "missing_llama_cli_binary_sha256",
    "missing_llama_cli_version_digest",
    "missing_hardware_profile",
    "missing_memory_sample",
    "missing_model_byte_estimate",
    "missing_kv_byte_estimate",
    "missing_workspace_byte_estimate",
    "missing_app_headroom",
    "missing_memory_fit_verdict",
    "missing_command_template",
    "missing_argv_allowlist",
    "missing_environment_allowlist",
    "missing_prompt_digest_policy",
    "missing_grammar_digest",
    "missing_timeout_cancel_teardown",
    "missing_stdio_redaction",
    "missing_memory_timing_sampler",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_abstention",
    "missing_human_visible_confirmation",
    "missing_no_command_arm",
    "missing_no_promotion",
    "preflight_packet_written",
    "preflight_packet_read",
    "owner_path_opened",
    "model_file_opened",
    "llama_cli_opened",
    "command_armed",
    "command_executed",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "raw_path_retained",
    "raw_prompt_retained",
    "runtime_router_mutation",
    "hidden_authority",
    "l2_l3_t4_claim",
    "live_gemma_claim",
];

// UAS: uas:gemma-direct-harness-owner-approved-receipt-preflight-packet-gate:status
// Plane: Verification.
// Residency: metadata-only preflight packet contract; no packet/model bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateStatus {
    PreflightPacketContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-preflight-packet-gate:spec
// Plane: Controller + Verification.
// Residency: future owner-approved preflight packet only; no action.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate {
    pub upstream_runbook_ref: String,
    pub upstream_runbook_id: String,
    pub artifact_root_prefix: String,
    pub preflight_card_id: String,
    pub future_preflight_packet_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_preflight_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub owner_and_path_digests_required: bool,
    pub model_and_llama_digests_required: bool,
    pub hardware_profile_required: bool,
    pub memory_byte_envelope_required: bool,
    pub command_and_prompt_policies_required: bool,
    pub timeout_stdio_sampler_required: bool,
    pub rollback_log_packet_abstention_required: bool,
    pub human_confirmation_required: bool,
    pub no_command_arm_bound: bool,
    pub no_promotion_bound: bool,
    pub future_preflight_packet_written_count: u64,
    pub future_preflight_packet_bytes_written: u64,
    pub future_preflight_packet_bytes_read: u64,
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
    pub status: GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate {
    pub fn canonical() -> Self {
        Self {
            upstream_runbook_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_UPSTREAM_REF
                    .to_string(),
            upstream_runbook_id: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            preflight_card_id: PREFLIGHT_CARD_ID.to_string(),
            future_preflight_packet_name: FUTURE_PREFLIGHT_PACKET_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_preflight_fields: REQUIRED_PREFLIGHT_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_and_path_digests_required: true,
            model_and_llama_digests_required: true,
            hardware_profile_required: true,
            memory_byte_envelope_required: true,
            command_and_prompt_policies_required: true,
            timeout_stdio_sampler_required: true,
            rollback_log_packet_abstention_required: true,
            human_confirmation_required: true,
            no_command_arm_bound: true,
            no_promotion_bound: true,
            future_preflight_packet_written_count: 0,
            future_preflight_packet_bytes_written: 0,
            future_preflight_packet_bytes_read: 0,
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
            metadata_bytes: 192_000,
            status:
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateStatus::PreflightPacketContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(
        &self,
    ) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError> {
        if !self
            .upstream_runbook_ref
            .starts_with(UPSTREAM_RUNBOOK_PREFIX)
            || self.upstream_runbook_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_RUNBOOK_GATE_ID
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::BadUpstreamRef,
            );
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "preflight_card_id",
            &self.preflight_card_id,
            PREFLIGHT_CARD_ID,
        )?;
        validate_exact(
            "future_preflight_packet_name",
            &self.future_preflight_packet_name,
            FUTURE_PREFLIGHT_PACKET_NAME,
        )?;
        validate_unique_exact_set(
            "required_preflight_fields",
            &self.required_preflight_fields,
            REQUIRED_PREFLIGHT_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateStatus::PreflightPacketContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::UnsafeState);
        }
        if !self.owner_and_path_digests_required
            || !self.model_and_llama_digests_required
            || !self.hardware_profile_required
            || !self.memory_byte_envelope_required
            || !self.command_and_prompt_policies_required
            || !self.timeout_stdio_sampler_required
            || !self.rollback_log_packet_abstention_required
            || !self.human_confirmation_required
            || !self.no_command_arm_bound
            || !self.no_promotion_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::ProofBoundaryBroken,
            );
        }
        if self.future_preflight_packet_written_count != 0
            || self.future_preflight_packet_bytes_written != 0
            || self.future_preflight_packet_bytes_read != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::PacketActionLeak,
            );
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
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::RuntimeActionLeak,
            );
        }
        if self.raw_owner_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::PrivacyLeak,
            );
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
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::PromotionClaim,
            );
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateMetrics {
        GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateMetrics {
            required_preflight_field_count: self.required_preflight_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            future_preflight_packet_written_count: self.future_preflight_packet_written_count,
            future_preflight_packet_bytes_written: self.future_preflight_packet_bytes_written,
            future_preflight_packet_bytes_read: self.future_preflight_packet_bytes_read,
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

    pub fn preflight_packet_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_PREFLIGHT_PACKET_GATE_CURSOR
                    .to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_preflight_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-owner-approved-receipt-preflight-packet-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_runbook_ref,
            self.upstream_runbook_id,
            self.future_preflight_packet_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-preflight-packet-gate:metrics
// Plane: Verification.
// Residency: zero-action preflight packet counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateMetrics {
    pub required_preflight_field_count: u64,
    pub required_abort_condition_count: u64,
    pub future_preflight_packet_written_count: u64,
    pub future_preflight_packet_bytes_written: u64,
    pub future_preflight_packet_bytes_read: u64,
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

pub fn required_gemma_direct_harness_owner_approved_preflight_fields() -> Vec<String> {
    REQUIRED_PREFLIGHT_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_owner_approved_preflight_abort_conditions() -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-preflight-packet-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    PacketActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream runbook reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe preflight packet gate state"),
            Self::ProofBoundaryBroken => f.write_str("preflight proof boundary broken"),
            Self::PacketActionLeak => f.write_str("preflight packet action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_754_400_000;

    #[test]
    fn canonical_preflight_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        gate.validate()
            .expect("canonical preflight packet gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_preflight_field_count, 30);
        assert_eq!(metrics.required_abort_condition_count, 45);
        assert_eq!(metrics.future_preflight_packet_bytes_written, 0);
        assert_eq!(metrics.future_preflight_packet_bytes_read, 0);
        assert_eq!(metrics.owner_path_open_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.file_open_count, 0);
        assert_eq!(metrics.raw_owner_path_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_required_preflight_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        gate.required_preflight_fields[0] = gate.required_preflight_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::DuplicateOrMissingField(
                    "required_preflight_fields"
                )
            )
        ));
    }

    #[test]
    fn packet_or_command_action_is_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        gate.future_preflight_packet_bytes_read = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::PacketActionLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        gate.command_armed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_path_or_route_mutation_is_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        gate.raw_owner_path_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        gate.runtime_router_mutation_allowed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate {
            required_preflight_fields: gate
                .required_preflight_fields
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
        reversed.validate().expect("reversed sets remain canonical");
        assert_eq!(
            gate.preflight_packet_gate_address(CREATED_AT_MS),
            reversed.preflight_packet_gate_address(CREATED_AT_MS)
        );
    }
}
