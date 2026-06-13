//! Gemma direct harness owner-approved receipt emitter gate.
//!
//! This primitive consumes the digest-only receipt-map witness and defines the
//! fail-closed emitter contract for a future owner-approved Gemma `llama-cli`
//! run. It is metadata-only in the default loop: no receipt is written or read,
//! no model or runtime file is opened, and no command is armed or executed.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind, GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedReceiptEmitterGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_receipt_emitter_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_receipt_emitter_dry_run_artifact_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_direct_harness_artifact_receipt_map/result.json#F-GemmaDirectHarnessArtifactReceiptMap";

const UPSTREAM_RECEIPT_MAP_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_artifact_receipt_map/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/";
const EMITTER_CARD_ID: &str = "gemma-direct-harness-owner-approved-receipt-emitter-gate-v1";
const FUTURE_RECEIPT_NAME: &str = "owner-approved-gemma-direct-harness-receipt-v1";
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_EMITTER_FIELDS: &[&str] = &[
    "upstream_receipt_map_artifact_digest",
    "receipt_schema_version",
    "owner_approval_digest",
    "owner_path_manifest_digest",
    "model_uas_address",
    "model_file_sha256",
    "llama_cli_binary_sha256",
    "llama_cli_version_digest",
    "command_template_digest",
    "resolved_argv_digest",
    "environment_allowlist_digest",
    "working_directory_digest",
    "prompt_file_digest",
    "grammar_or_json_schema_digest",
    "pid_policy_digest",
    "exit_code_capture_policy",
    "termination_reason_policy",
    "timeout_budget_digest",
    "cancel_result_policy_digest",
    "teardown_policy_digest",
    "stdout_digest_policy",
    "stderr_digest_policy",
    "first_token_redaction_digest",
    "timing_sampler_digest",
    "memory_sampler_digest",
    "temp_receipt_path_policy_digest",
    "atomic_write_policy_digest",
    "cleanup_policy_digest",
    "run_event_log_ref",
    "answer_packet_ref",
    "rollback_ref",
    "abstention_ref",
    "no_promotion_digest",
];

const REQUIRED_ABORT_CONDITIONS: &[&str] = &[
    "missing_upstream_receipt_map",
    "missing_owner_approval",
    "missing_owner_path_manifest",
    "raw_owner_path_retained",
    "raw_prompt_retained",
    "raw_output_retained",
    "raw_stdout_retained",
    "raw_stderr_retained",
    "raw_token_retained",
    "model_file_opened_in_gate",
    "llama_cli_opened_in_gate",
    "command_armed_in_gate",
    "command_executed_in_gate",
    "receipt_written_in_gate",
    "receipt_read_in_gate",
    "non_digest_receipt_field",
    "missing_process_exit_policy",
    "missing_timeout_policy",
    "missing_cancel_policy",
    "missing_teardown_policy",
    "missing_timing_sampler",
    "missing_memory_sampler",
    "missing_atomic_write_policy",
    "missing_cleanup_policy",
    "run_event_log_missing",
    "answer_packet_missing",
    "rollback_missing",
    "abstention_missing",
    "runtime_router_mutation",
    "system_g_mutation",
    "settings_default_mutation",
    "parallel_ladder_authority",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "l2_l3_t4_claim",
    "live_gemma_default_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
    "quality_claim_from_emitter",
];

// UAS: uas:gemma-direct-harness-owner-approved-receipt-emitter-gate:status
// Plane: Verification.
// Residency: metadata-only emitter contract; no receipt/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedReceiptEmitterGateStatus {
    EmitterContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-emitter-gate:spec
// Plane: Controller + Verification.
// Residency: future emitter gate only; no write/read/command action.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedReceiptEmitterGate {
    pub upstream_receipt_map_ref: String,
    pub upstream_receipt_map_id: String,
    pub artifact_root_prefix: String,
    pub emitter_card_id: String,
    pub future_receipt_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_emitter_fields: Vec<String>,
    pub required_abort_conditions: Vec<String>,
    pub upstream_receipt_map_digest_required: bool,
    pub owner_approval_required: bool,
    pub owner_path_manifest_digest_required: bool,
    pub model_file_digest_required: bool,
    pub llama_cli_binary_digest_required: bool,
    pub llama_cli_version_digest_required: bool,
    pub command_template_digest_required: bool,
    pub argv_environment_workdir_digests_required: bool,
    pub prompt_and_grammar_digests_required: bool,
    pub process_exit_policy_bound: bool,
    pub timeout_cancel_teardown_policy_bound: bool,
    pub stdout_stderr_digest_policy_bound: bool,
    pub first_token_redaction_bound: bool,
    pub timing_sampler_bound: bool,
    pub memory_sampler_bound: bool,
    pub atomic_write_policy_bound: bool,
    pub cleanup_policy_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub rollback_bound: bool,
    pub abstention_bound: bool,
    pub future_receipt_written_count: u64,
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
    pub non_digest_receipt_field_count: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_or_default_mutation_allowed: bool,
    pub parallel_ladder_authority_allowed: bool,
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
    pub status: GemmaDirectHarnessOwnerApprovedReceiptEmitterGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedReceiptEmitterGate {
    pub fn canonical() -> Self {
        Self {
            upstream_receipt_map_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_UPSTREAM_REF.to_string(),
            upstream_receipt_map_id: GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            emitter_card_id: EMITTER_CARD_ID.to_string(),
            future_receipt_name: FUTURE_RECEIPT_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_emitter_fields: REQUIRED_EMITTER_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_abort_conditions: REQUIRED_ABORT_CONDITIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_receipt_map_digest_required: true,
            owner_approval_required: true,
            owner_path_manifest_digest_required: true,
            model_file_digest_required: true,
            llama_cli_binary_digest_required: true,
            llama_cli_version_digest_required: true,
            command_template_digest_required: true,
            argv_environment_workdir_digests_required: true,
            prompt_and_grammar_digests_required: true,
            process_exit_policy_bound: true,
            timeout_cancel_teardown_policy_bound: true,
            stdout_stderr_digest_policy_bound: true,
            first_token_redaction_bound: true,
            timing_sampler_bound: true,
            memory_sampler_bound: true,
            atomic_write_policy_bound: true,
            cleanup_policy_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            rollback_bound: true,
            abstention_bound: true,
            future_receipt_written_count: 0,
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
            non_digest_receipt_field_count: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_or_default_mutation_allowed: false,
            parallel_ladder_authority_allowed: false,
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
            metadata_bytes: 152_000,
            status: GemmaDirectHarnessOwnerApprovedReceiptEmitterGateStatus::EmitterContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError> {
        if !self
            .upstream_receipt_map_ref
            .starts_with(UPSTREAM_RECEIPT_MAP_PREFIX)
            || self.upstream_receipt_map_id != GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_ID
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("emitter_card_id", &self.emitter_card_id, EMITTER_CARD_ID)?;
        validate_exact(
            "future_receipt_name",
            &self.future_receipt_name,
            FUTURE_RECEIPT_NAME,
        )?;
        validate_unique_exact_set(
            "required_emitter_fields",
            &self.required_emitter_fields,
            REQUIRED_EMITTER_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_abort_conditions",
            &self.required_abort_conditions,
            REQUIRED_ABORT_CONDITIONS,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedReceiptEmitterGateStatus::EmitterContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::UnsafeState);
        }
        if !self.upstream_receipt_map_digest_required
            || !self.owner_approval_required
            || !self.owner_path_manifest_digest_required
            || !self.model_file_digest_required
            || !self.llama_cli_binary_digest_required
            || !self.llama_cli_version_digest_required
            || !self.command_template_digest_required
            || !self.argv_environment_workdir_digests_required
            || !self.prompt_and_grammar_digests_required
            || !self.process_exit_policy_bound
            || !self.timeout_cancel_teardown_policy_bound
            || !self.stdout_stderr_digest_policy_bound
            || !self.first_token_redaction_bound
            || !self.timing_sampler_bound
            || !self.memory_sampler_bound
            || !self.atomic_write_policy_bound
            || !self.cleanup_policy_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.rollback_bound
            || !self.abstention_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::ProofBoundaryBroken,
            );
        }
        if self.future_receipt_written_count != 0
            || self.future_receipt_bytes_written != 0
            || self.future_receipt_bytes_read != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::ReceiptActionLeak);
        }
        if self.command_armed
            || self.command_executed
            || self.model_file_opened
            || self.llama_cli_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::RuntimeActionLeak);
        }
        if self.raw_owner_path_bytes != 0
            || self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
            || self.non_digest_receipt_field_count != 0
        {
            return Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::PrivacyLeak);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_or_default_mutation_allowed
            || self.parallel_ladder_authority_allowed
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
            return Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedReceiptEmitterGateMetrics {
        GemmaDirectHarnessOwnerApprovedReceiptEmitterGateMetrics {
            required_emitter_field_count: self.required_emitter_fields.len() as u64,
            required_abort_condition_count: self.required_abort_conditions.len() as u64,
            future_receipt_written_count: self.future_receipt_written_count,
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
            non_digest_receipt_field_count: self.non_digest_receipt_field_count,
            mutation_count: (self.runtime_router_mutation_allowed
                || self.system_g_mutation_allowed
                || self.settings_or_default_mutation_allowed
                || self.parallel_ladder_authority_allowed) as u64,
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

    pub fn emitter_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_CURSOR.to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_emitter_fields.clone();
        fields.sort();
        let mut aborts = self.required_abort_conditions.clone();
        aborts.sort();
        format!(
            "gemma-direct-harness-owner-approved-receipt-emitter-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_receipt_map_ref,
            self.upstream_receipt_map_id,
            self.future_receipt_name,
            fields.join(","),
            aborts.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-emitter-gate:metrics
// Plane: Verification.
// Residency: zero-action emitter counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedReceiptEmitterGateMetrics {
    pub required_emitter_field_count: u64,
    pub required_abort_condition_count: u64,
    pub future_receipt_written_count: u64,
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
    pub non_digest_receipt_field_count: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_receipt_emitter_fields() -> Vec<String> {
    REQUIRED_EMITTER_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_receipt_emitter_abort_conditions() -> Vec<String> {
    REQUIRED_ABORT_CONDITIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-owner-approved-receipt-emitter-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError {
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

impl fmt::Display for GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream receipt-map reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe receipt-emitter gate state"),
            Self::ProofBoundaryBroken => f.write_str("receipt-emitter proof boundary broken"),
            Self::ReceiptActionLeak => f.write_str("receipt action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_495_200_000;

    #[test]
    fn canonical_emitter_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        gate.validate()
            .expect("canonical receipt-emitter gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_emitter_field_count, 33);
        assert_eq!(metrics.required_abort_condition_count, 42);
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
    fn duplicate_required_emitter_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        gate.required_emitter_fields[0] = gate.required_emitter_fields[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::DuplicateOrMissingField(
                    "required_emitter_fields"
                )
            )
        ));
    }

    #[test]
    fn receipt_write_or_command_execution_is_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        gate.future_receipt_bytes_written = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::ReceiptActionLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        gate.command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::RuntimeActionLeak)
        ));
    }

    #[test]
    fn raw_bytes_and_non_digest_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        gate.raw_owner_path_bytes = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::PrivacyLeak)
        ));
        let mut gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        gate.non_digest_receipt_field_count = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedReceiptEmitterGateError::PrivacyLeak)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate {
            required_emitter_fields: gate.required_emitter_fields.iter().cloned().rev().collect(),
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
            gate.emitter_gate_address(CREATED_AT_MS),
            reversed.emitter_gate_address(CREATED_AT_MS)
        );
    }
}
