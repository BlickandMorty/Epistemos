//! Gemma direct harness artifact receipt map.
//!
//! This primitive maps a future bounded `llama-cli` Gemma E2B/E4B run into the
//! existing Gemma artifact-review ladder. It is metadata-only: no model path,
//! runtime artifact, prompt, token, stdout, stderr, or provider bytes are
//! opened, retained, or executed.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID,
    GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
};

pub const GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_ID: &str =
    "F-GemmaDirectHarnessArtifactReceiptMap";
pub const GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_CURSOR: &str =
    "gemma_direct_harness_artifact_receipt_map";
pub const GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_receipt_emitter_gate";

const DIRECT_HARNESS_RAIL_REF: &str =
    "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md#Pass-211-Gemma-Direct-Harness-Admission-Rail";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_artifact_receipt_map/";
const RECEIPT_CARD_ID: &str = "gemma-direct-harness-artifact-receipt-map-v1";
const FUTURE_RECEIPT_NAME: &str = "owner-approved-gemma-direct-harness-receipt-v1";
const MAX_METADATA_BYTES: u64 = 176 * 1024;

const REQUIRED_RECEIPT_SECTIONS: &[&str] = &[
    "subject",
    "materials",
    "invocation",
    "process",
    "observations",
    "joins",
    "promotion",
];

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "subject.model_uas_address",
    "subject.receipt_digest",
    "materials.model_file_sha256",
    "materials.llama_cli_binary_sha256",
    "materials.prompt_file_digest",
    "materials.grammar_or_json_schema_digest",
    "invocation.argv_digest",
    "invocation.environment_digest",
    "invocation.working_directory_digest",
    "invocation.owner_approval_digest",
    "process.pid_policy_digest",
    "process.exit_code",
    "process.termination_reason",
    "process.timeout_result",
    "process.cancel_result",
    "process.teardown_digest",
    "observations.redacted_first_token_digest",
    "observations.stdout_digest",
    "observations.stderr_digest",
    "observations.timing_digest",
    "observations.memory_sample_digest",
    "joins.run_event_log_ref",
    "joins.answer_packet_ref",
    "joins.rollback_ref",
    "joins.abstention_ref",
    "promotion.no_quality_no_route_no_settings_no_default_no_l2_l3",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "raw_prompt_bytes_present",
    "raw_output_bytes_present",
    "raw_stdout_bytes_present",
    "raw_stderr_bytes_present",
    "raw_token_bytes_present",
    "raw_path_bytes_present",
    "subject_digest_missing",
    "materials_digest_missing",
    "argv_digest_missing",
    "environment_digest_missing",
    "owner_approval_digest_missing",
    "process_exit_status_missing",
    "termination_reason_missing",
    "timeout_result_missing",
    "cancel_result_missing",
    "teardown_digest_missing",
    "redaction_policy_missing",
    "timing_digest_missing",
    "memory_sample_digest_missing",
    "run_event_log_missing",
    "answer_packet_missing",
    "rollback_missing",
    "abstention_missing",
    "runtime_router_mutation",
    "system_g_mutation",
    "settings_or_default_mutation",
    "quality_claim_from_receipt",
    "l2_l3_or_t4_claim",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "model_or_runtime_bytes_loaded",
    "command_armed_or_executed",
    "receipt_artifact_read_in_default_loop",
    "parallel_ladder_authority",
];

// UAS: uas:gemma-direct-harness-artifact-receipt-map:status
// Plane: Verification.
// Residency: metadata-only receipt contract; zero model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessArtifactReceiptMapStatus {
    ReceiptMapContractOnly,
}

// UAS: uas:gemma-direct-harness-artifact-receipt-map:spec
// Plane: Controller + Verification.
// Residency: future receipt-map contract only; no artifact reads or commands.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessArtifactReceiptMap {
    pub direct_harness_rail_ref: String,
    pub execution_artifact_gate_ref: String,
    pub execution_artifact_gate_id: String,
    pub owner_approved_execution_probe_ref: String,
    pub owner_approved_execution_probe_id: String,
    pub first_token_artifact_review_gate_ref: String,
    pub first_token_artifact_review_gate_id: String,
    pub artifact_root_prefix: String,
    pub receipt_card_id: String,
    pub future_receipt_name: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_receipt_sections: Vec<String>,
    pub required_receipt_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub subject_digest_required: bool,
    pub material_digests_required: bool,
    pub invocation_digests_required: bool,
    pub process_exit_bound: bool,
    pub termination_reason_bound: bool,
    pub timeout_cancel_teardown_bound: bool,
    pub observation_digests_required: bool,
    pub redaction_policy_bound: bool,
    pub timing_memory_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub rollback_bound: bool,
    pub abstention_bound: bool,
    pub future_receipt_present: bool,
    pub future_receipt_bytes_read: u64,
    pub accepted_receipt_count: u64,
    pub receipt_reconciliation_performed_count: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub raw_path_bytes: u64,
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
    pub status: GemmaDirectHarnessArtifactReceiptMapStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessArtifactReceiptMap {
    pub fn canonical() -> Self {
        Self {
            direct_harness_rail_ref: DIRECT_HARNESS_RAIL_REF.to_string(),
            execution_artifact_gate_ref:
                GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF.to_string(),
            execution_artifact_gate_id: GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID
                .to_string(),
            owner_approved_execution_probe_ref:
                GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF.to_string(),
            owner_approved_execution_probe_id:
                GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID.to_string(),
            first_token_artifact_review_gate_ref:
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF.to_string(),
            first_token_artifact_review_gate_id:
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            receipt_card_id: RECEIPT_CARD_ID.to_string(),
            future_receipt_name: FUTURE_RECEIPT_NAME.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_receipt_sections: REQUIRED_RECEIPT_SECTIONS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            subject_digest_required: true,
            material_digests_required: true,
            invocation_digests_required: true,
            process_exit_bound: true,
            termination_reason_bound: true,
            timeout_cancel_teardown_bound: true,
            observation_digests_required: true,
            redaction_policy_bound: true,
            timing_memory_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            rollback_bound: true,
            abstention_bound: true,
            future_receipt_present: false,
            future_receipt_bytes_read: 0,
            accepted_receipt_count: 0,
            receipt_reconciliation_performed_count: 0,
            command_armed: false,
            command_executed: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_prompt_bytes: 0,
            raw_output_bytes: 0,
            raw_stdout_bytes: 0,
            raw_stderr_bytes: 0,
            raw_token_bytes: 0,
            raw_path_bytes: 0,
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
            metadata_bytes: 144_000,
            status: GemmaDirectHarnessArtifactReceiptMapStatus::ReceiptMapContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessArtifactReceiptMapError> {
        validate_exact(
            "direct_harness_rail_ref",
            &self.direct_harness_rail_ref,
            DIRECT_HARNESS_RAIL_REF,
        )?;
        validate_exact(
            "execution_artifact_gate_ref",
            &self.execution_artifact_gate_ref,
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        )?;
        validate_exact(
            "execution_artifact_gate_id",
            &self.execution_artifact_gate_id,
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID,
        )?;
        validate_exact(
            "owner_approved_execution_probe_ref",
            &self.owner_approved_execution_probe_ref,
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        )?;
        validate_exact(
            "owner_approved_execution_probe_id",
            &self.owner_approved_execution_probe_id,
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID,
        )?;
        validate_exact(
            "first_token_artifact_review_gate_ref",
            &self.first_token_artifact_review_gate_ref,
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
        )?;
        validate_exact(
            "first_token_artifact_review_gate_id",
            &self.first_token_artifact_review_gate_id,
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID,
        )?;
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
            "required_receipt_sections",
            &self.required_receipt_sections,
            REQUIRED_RECEIPT_SECTIONS,
        )?;
        validate_unique_exact_set(
            "required_receipt_fields",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status != GemmaDirectHarnessArtifactReceiptMapStatus::ReceiptMapContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessArtifactReceiptMapError::UnsafeState);
        }
        if !self.subject_digest_required
            || !self.material_digests_required
            || !self.invocation_digests_required
            || !self.process_exit_bound
            || !self.termination_reason_bound
            || !self.timeout_cancel_teardown_bound
            || !self.observation_digests_required
            || !self.redaction_policy_bound
            || !self.timing_memory_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.rollback_bound
            || !self.abstention_bound
        {
            return Err(GemmaDirectHarnessArtifactReceiptMapError::ProofBoundaryBroken);
        }
        if self.future_receipt_present
            || self.future_receipt_bytes_read != 0
            || self.accepted_receipt_count != 0
            || self.receipt_reconciliation_performed_count != 0
        {
            return Err(GemmaDirectHarnessArtifactReceiptMapError::ReceiptActionLeak);
        }
        if self.command_armed
            || self.command_executed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessArtifactReceiptMapError::RuntimeActionLeak);
        }
        if self.raw_prompt_bytes != 0
            || self.raw_output_bytes != 0
            || self.raw_stdout_bytes != 0
            || self.raw_stderr_bytes != 0
            || self.raw_token_bytes != 0
            || self.raw_path_bytes != 0
        {
            return Err(GemmaDirectHarnessArtifactReceiptMapError::PrivacyLeak);
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
            return Err(GemmaDirectHarnessArtifactReceiptMapError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessArtifactReceiptMapMetrics {
        GemmaDirectHarnessArtifactReceiptMapMetrics {
            required_receipt_section_count: self.required_receipt_sections.len() as u64,
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            future_receipt_present_count: self.future_receipt_present as u64,
            future_receipt_bytes_read: self.future_receipt_bytes_read,
            accepted_receipt_count: self.accepted_receipt_count,
            receipt_reconciliation_performed_count: self.receipt_reconciliation_performed_count,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_prompt_bytes: self.raw_prompt_bytes,
            raw_output_bytes: self.raw_output_bytes,
            raw_stdout_bytes: self.raw_stdout_bytes,
            raw_stderr_bytes: self.raw_stderr_bytes,
            raw_token_bytes: self.raw_token_bytes,
            raw_path_bytes: self.raw_path_bytes,
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

    pub fn receipt_map_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut sections = self.required_receipt_sections.clone();
        sections.sort();
        let mut fields = self.required_receipt_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-direct-harness-artifact-receipt-map:v1:{}:{}:{}:{}:{}:{}",
            self.direct_harness_rail_ref,
            self.execution_artifact_gate_id,
            self.owner_approved_execution_probe_id,
            self.first_token_artifact_review_gate_id,
            sections.join(","),
            [fields.join(","), policies.join(",")].join("|"),
        )
    }
}

// UAS: uas:gemma-direct-harness-artifact-receipt-map:metrics
// Plane: Verification.
// Residency: zero-action receipt-map counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessArtifactReceiptMapMetrics {
    pub required_receipt_section_count: u64,
    pub required_receipt_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub future_receipt_present_count: u64,
    pub future_receipt_bytes_read: u64,
    pub accepted_receipt_count: u64,
    pub receipt_reconciliation_performed_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub raw_stdout_bytes: u64,
    pub raw_stderr_bytes: u64,
    pub raw_token_bytes: u64,
    pub raw_path_bytes: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_receipt_sections() -> Vec<String> {
    REQUIRED_RECEIPT_SECTIONS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_receipt_fields() -> Vec<String> {
    REQUIRED_RECEIPT_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_direct_harness_receipt_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-artifact-receipt-map:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessArtifactReceiptMapError {
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ReceiptActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessArtifactReceiptMapError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe receipt-map state"),
            Self::ProofBoundaryBroken => f.write_str("receipt proof boundary broken"),
            Self::ReceiptActionLeak => f.write_str("receipt action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessArtifactReceiptMapError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessArtifactReceiptMapError> {
    if actual.len() != expected.len() {
        return Err(GemmaDirectHarnessArtifactReceiptMapError::DuplicateOrMissingField(field_name));
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(GemmaDirectHarnessArtifactReceiptMapError::DuplicateOrMissingField(field_name));
    }
    Ok(())
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaDirectHarnessArtifactReceiptMapError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessArtifactReceiptMapError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_491_600_000;

    #[test]
    fn canonical_receipt_map_validates_zero_actions() {
        let map = GemmaDirectHarnessArtifactReceiptMap::canonical();
        map.validate()
            .expect("canonical receipt map should validate");
        let metrics = map.metrics();
        assert_eq!(metrics.required_receipt_section_count, 7);
        assert_eq!(metrics.required_receipt_field_count, 26);
        assert_eq!(metrics.required_rejection_policy_count, 37);
        assert_eq!(metrics.future_receipt_bytes_read, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.raw_prompt_bytes, 0);
        assert_eq!(metrics.raw_path_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_required_receipt_fields_are_rejected() {
        let mut map = GemmaDirectHarnessArtifactReceiptMap::canonical();
        map.required_receipt_fields[0] = map.required_receipt_fields[1].clone();
        assert!(matches!(
            map.validate(),
            Err(
                GemmaDirectHarnessArtifactReceiptMapError::DuplicateOrMissingField(
                    "required_receipt_fields"
                )
            )
        ));
    }

    #[test]
    fn raw_bytes_are_rejected() {
        let mut map = GemmaDirectHarnessArtifactReceiptMap::canonical();
        map.raw_stdout_bytes = 1;
        assert!(matches!(
            map.validate(),
            Err(GemmaDirectHarnessArtifactReceiptMapError::PrivacyLeak)
        ));
    }

    #[test]
    fn route_or_promotion_claims_are_rejected() {
        let mut map = GemmaDirectHarnessArtifactReceiptMap::canonical();
        map.runtime_router_mutation_allowed = true;
        assert!(matches!(
            map.validate(),
            Err(GemmaDirectHarnessArtifactReceiptMapError::PromotionClaim)
        ));
        let mut map = GemmaDirectHarnessArtifactReceiptMap::canonical();
        map.l2_capability_effect = true;
        assert!(matches!(
            map.validate(),
            Err(GemmaDirectHarnessArtifactReceiptMapError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let map = GemmaDirectHarnessArtifactReceiptMap::canonical();
        let reversed = GemmaDirectHarnessArtifactReceiptMap {
            required_receipt_sections: map
                .required_receipt_sections
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_receipt_fields: map.required_receipt_fields.iter().cloned().rev().collect(),
            required_rejection_policies: map
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..map.clone()
        };
        reversed.validate().expect("reversed sets remain canonical");
        assert_eq!(
            map.receipt_map_address(CREATED_AT_MS),
            reversed.receipt_map_address(CREATED_AT_MS)
        );
    }
}
