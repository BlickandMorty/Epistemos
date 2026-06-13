//! Gemma owner-approved receipt emitter dry-run gate.
//!
//! This metadata-only gate defines the dry-run emitter shape for a future
//! owner-approved Gemma local artifact receipt. It does not read owner paths,
//! open files, hash model bytes, execute tools, load runtime bytes, mutate
//! routes, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_ID,
};

pub const GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_ID: &str =
    "F-GemmaOwnerApprovedReceiptEmitterDryRunGate";
pub const GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_CURSOR: &str =
    "gemma_owner_approved_receipt_emitter_dry_run_gate";
pub const GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_owner_approved_local_artifact_receipt_intake_gate/result.json#F-GemmaOwnerApprovedLocalArtifactReceiptIntakeGate";

const UPSTREAM_PREFIX: &str =
    "artifact:falsifiers/gemma_owner_approved_local_artifact_receipt_intake_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_owner_approved_receipt_emitter_dry_run_gate/";
const GATE_ID: &str = "gemma-owner-approved-receipt-emitter-dry-run-gate-v1";
const CREATED_AT_MS: u64 = 1_780_200_000_000;
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_EMITTER_SECTIONS: &[&str] = &[
    "symbolic_owner_input",
    "redacted_identity_projection",
    "digest_slot_plan",
    "byte_count_slot_plan",
    "tool_identity_slot_plan",
    "reviewer_visible_summary",
    "non_promotion_and_abstention",
];

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "receipt_schema_version",
    "receipt_kind",
    "owner_approval_phrase_digest",
    "selected_model_id",
    "source_revision",
    "expected_filename",
    "expected_byte_count",
    "observed_byte_count_slot",
    "local_file_sha256_slot",
    "redacted_path_digest_slot",
    "raw_path_absent",
    "runtime_lane",
    "llama_cli_version_digest_slot",
    "llama_cli_help_digest_slot",
    "offline_flag_required",
    "source_license_ref",
    "provenance_mode",
    "hardware_profile_ref",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary",
    "non_promotion_ref",
];

const ALLOWED_RECEIPT_KINDS: &[&str] = &[
    "gemma_e2b_qat_gguf_direct_file",
    "gemma_e4b_qat_gguf_direct_file",
    "gemma_e4b_mlx_manifest_file",
    "gemma_12b_litert_lm_bundle",
];

const REQUIRED_DRY_RUN_OUTPUTS: &[&str] = &[
    "receipt_template_digest",
    "redaction_policy_digest",
    "symbolic_path_policy_digest",
    "owner_approval_policy_digest",
    "runtime_lane_policy_digest",
    "tool_identity_policy_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
];

const DENIED_EMITTER_SHORTCUTS: &[&str] = &[
    "raw_path_output",
    "owner_phrase_plaintext_output",
    "hf_cache_identity_output",
    "download_completion_output",
    "etag_as_sha256_output",
    "repo_revision_as_file_hash_output",
    "llama_cli_hf_output",
    "server_endpoint_output",
    "settings_default_output",
    "route_admission_output",
    "quality_score_output",
    "token_output",
    "stdout_stderr_raw_output",
    "model_picker_claim_output",
    "live_gemma_claim_output",
    "live_70b_claim_output",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_intake_gate",
    "missing_emitter_section",
    "duplicate_emitter_section",
    "missing_receipt_field",
    "duplicate_receipt_field",
    "missing_receipt_kind",
    "unknown_receipt_kind",
    "missing_dry_run_output",
    "duplicate_dry_run_output",
    "missing_denied_shortcut",
    "duplicate_denied_shortcut",
    "owner_approval_granted_in_dry_run",
    "receipt_payload_written",
    "receipt_payload_read",
    "raw_owner_path_stored",
    "owner_phrase_plaintext_stored",
    "path_canonicalized",
    "file_opened",
    "file_hashed",
    "byte_count_verified",
    "llama_cli_executed",
    "command_armed",
    "command_executed",
    "server_started",
    "network_probe_allowed",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "runtime_router_mutated",
    "system_g_mutated",
    "settings_default_mutated",
    "hidden_authority",
    "quality_claim",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-owner-approved-receipt-emitter-dry-run-gate:spec
// Plane: Controller + Verification.
// Residency: emitter schema only; zero owner/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedReceiptEmitterDryRunGate {
    pub upstream_intake_gate_ref: String,
    pub upstream_intake_gate_id: String,
    pub artifact_root_prefix: String,
    pub gate_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_emitter_sections: Vec<String>,
    pub required_receipt_fields: Vec<String>,
    pub allowed_receipt_kinds: Vec<String>,
    pub required_dry_run_outputs: Vec<String>,
    pub denied_emitter_shortcuts: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub receipt_payload_bytes_written: u64,
    pub receipt_payload_bytes_read: u64,
    pub stores_raw_owner_path: bool,
    pub stores_owner_phrase_plaintext: bool,
    pub path_canonicalization_count: u64,
    pub file_open_count: u64,
    pub file_hash_count: u64,
    pub byte_count_verified: bool,
    pub llama_cli_executed: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub server_started: bool,
    pub network_probe_allowed: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_default_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_required: bool,
    pub metadata_bytes: u64,
    pub next_cursor: String,
}

impl GemmaOwnerApprovedReceiptEmitterDryRunGate {
    pub fn canonical() -> Self {
        Self {
            upstream_intake_gate_ref:
                GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_UPSTREAM_REF.to_string(),
            upstream_intake_gate_id: GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            gate_id: GATE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_emitter_sections: REQUIRED_EMITTER_SECTIONS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            allowed_receipt_kinds: ALLOWED_RECEIPT_KINDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_dry_run_outputs: REQUIRED_DRY_RUN_OUTPUTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            denied_emitter_shortcuts: DENIED_EMITTER_SHORTCUTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            owner_approval_required: true,
            owner_approval_granted: false,
            receipt_payload_bytes_written: 0,
            receipt_payload_bytes_read: 0,
            stores_raw_owner_path: false,
            stores_owner_phrase_plaintext: false,
            path_canonicalization_count: 0,
            file_open_count: 0,
            file_hash_count: 0,
            byte_count_verified: false,
            llama_cli_executed: false,
            command_armed: false,
            command_executed: false,
            server_started: false,
            network_probe_allowed: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_default_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            quality_claim: false,
            live_gemma_claim: false,
            l2_l3_t4_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            rollback_ref: "rollback:gemma-owner-approved-receipt-emitter-dry-run-gate-v1"
                .to_string(),
            run_event_log_ref: "run_event_log:gemma-owner-approved-receipt-emitter-dry-run-gate-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-owner-approved-receipt-emitter-dry-run-gate-v1"
                .to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaOwnerApprovedReceiptEmitterDryRunGateError> {
        validate_prefix(
            &self.upstream_intake_gate_ref,
            UPSTREAM_PREFIX,
            "upstream_intake_gate_ref",
        )?;
        if self.upstream_intake_gate_id
            != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_ID
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.gate_id != GATE_ID {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::BadBuildStatus);
        }
        validate_unique_required(
            "section",
            &self.required_emitter_sections,
            REQUIRED_EMITTER_SECTIONS,
        )?;
        validate_unique_required(
            "field",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_required(
            "receipt_kind",
            &self.allowed_receipt_kinds,
            ALLOWED_RECEIPT_KINDS,
        )?;
        validate_unique_required(
            "dry_run_output",
            &self.required_dry_run_outputs,
            REQUIRED_DRY_RUN_OUTPUTS,
        )?;
        validate_unique_required(
            "shortcut",
            &self.denied_emitter_shortcuts,
            DENIED_EMITTER_SHORTCUTS,
        )?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if !self.owner_approval_required {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::OwnerApprovalMissing);
        }
        if self.owner_approval_granted
            || self.receipt_payload_bytes_written != 0
            || self.receipt_payload_bytes_read != 0
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::ReceiptAction);
        }
        if self.stores_raw_owner_path || self.stores_owner_phrase_plaintext {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::PrivacyLeak);
        }
        if self.path_canonicalization_count != 0
            || self.file_open_count != 0
            || self.file_hash_count != 0
            || self.byte_count_verified
            || self.llama_cli_executed
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::LocalAction);
        }
        if self.command_armed
            || self.command_executed
            || self.server_started
            || self.network_probe_allowed
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::PromotionClaim);
        }
        validate_prefix(&self.rollback_ref, "rollback:", "rollback_ref")?;
        validate_prefix(
            &self.run_event_log_ref,
            "run_event_log:",
            "run_event_log_ref",
        )?;
        validate_prefix(
            &self.answer_packet_ref,
            "answer_packet:",
            "answer_packet_ref",
        )?;
        if !self.abstention_required {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_NEXT_CURSOR {
            return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_CURSOR.to_string()),
            self.gate_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaOwnerApprovedReceiptEmitterDryRunGateMetrics {
        GemmaOwnerApprovedReceiptEmitterDryRunGateMetrics {
            emitter_section_count: self.required_emitter_sections.len() as u64,
            receipt_field_count: self.required_receipt_fields.len() as u64,
            allowed_receipt_kind_count: self.allowed_receipt_kinds.len() as u64,
            dry_run_output_count: self.required_dry_run_outputs.len() as u64,
            denied_shortcut_count: self.denied_emitter_shortcuts.len() as u64,
            rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_required_count: u64::from(self.owner_approval_required),
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            receipt_payload_bytes_written: self.receipt_payload_bytes_written,
            receipt_payload_bytes_read: self.receipt_payload_bytes_read,
            privacy_leak_count: u64::from(self.stores_raw_owner_path)
                + u64::from(self.stores_owner_phrase_plaintext),
            local_action_count: self.path_canonicalization_count
                + self.file_open_count
                + self.file_hash_count
                + u64::from(self.byte_count_verified)
                + u64::from(self.llama_cli_executed),
            runtime_action_count: u64::from(self.command_armed)
                + u64::from(self.command_executed)
                + u64::from(self.server_started)
                + u64::from(self.network_probe_allowed),
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            route_mutation_count: u64::from(self.runtime_router_mutation_allowed)
                + u64::from(self.system_g_mutation_allowed)
                + u64::from(self.settings_default_mutation_allowed),
            hidden_authority_count: u64::from(self.hidden_route_authority)
                + u64::from(self.hidden_eidos_authority)
                + u64::from(self.hidden_lattice_authority)
                + u64::from(self.hidden_patternboost_authority)
                + u64::from(self.hidden_cloud_fallback),
            promotion_claim_count: u64::from(self.quality_claim)
                + u64::from(self.live_gemma_claim)
                + u64::from(self.l2_l3_t4_claim)
                + u64::from(self.live_dense_70b_claim)
                + u64::from(self.ssd_as_ram_claim),
            metadata_bytes: self.metadata_bytes,
        }
    }
}

// UAS: uas:gemma-owner-approved-receipt-emitter-dry-run-gate:metrics
// Plane: Verification.
// Residency: counters only; no receipt/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedReceiptEmitterDryRunGateMetrics {
    pub emitter_section_count: u64,
    pub receipt_field_count: u64,
    pub allowed_receipt_kind_count: u64,
    pub dry_run_output_count: u64,
    pub denied_shortcut_count: u64,
    pub rejection_policy_count: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub receipt_payload_bytes_written: u64,
    pub receipt_payload_bytes_read: u64,
    pub privacy_leak_count: u64,
    pub local_action_count: u64,
    pub runtime_action_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-owner-approved-receipt-emitter-dry-run-gate:error
// Plane: Verification.
// Residency: validation error only; no receipt/model/runtime bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaOwnerApprovedReceiptEmitterDryRunGateError {
    EmptyField(&'static str),
    ControlCharacter(&'static str),
    BadPrefix(&'static str),
    MissingRequired(&'static str, &'static str),
    DuplicateValue(&'static str, String),
    BadUpstream,
    BadIdentity,
    BadBuildStatus,
    OwnerApprovalMissing,
    ReceiptAction,
    PrivacyLeak,
    LocalAction,
    RuntimeAction,
    RuntimeBytesLoaded,
    RouteMutation,
    HiddenAuthority,
    PromotionClaim,
    AbstentionMissing,
    MetadataTooLarge,
    BadNextCursor,
}

impl fmt::Display for GemmaOwnerApprovedReceiptEmitterDryRunGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyField(field) => write!(f, "{field} is empty"),
            Self::ControlCharacter(field) => write!(f, "{field} contains control character"),
            Self::BadPrefix(field) => write!(f, "{field} has bad prefix"),
            Self::MissingRequired(kind, value) => write!(f, "{kind} missing {value}"),
            Self::DuplicateValue(kind, value) => write!(f, "{kind} duplicate {value}"),
            Self::BadUpstream => write!(f, "bad upstream"),
            Self::BadIdentity => write!(f, "bad identity"),
            Self::BadBuildStatus => write!(f, "bad build status"),
            Self::OwnerApprovalMissing => write!(f, "owner approval missing"),
            Self::ReceiptAction => write!(f, "receipt action occurred"),
            Self::PrivacyLeak => write!(f, "privacy leak"),
            Self::LocalAction => write!(f, "local action occurred"),
            Self::RuntimeAction => write!(f, "runtime action occurred"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::RouteMutation => write!(f, "route mutation"),
            Self::HiddenAuthority => write!(f, "hidden authority"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::AbstentionMissing => write!(f, "abstention missing"),
            Self::MetadataTooLarge => write!(f, "metadata too large"),
            Self::BadNextCursor => write!(f, "bad next cursor"),
        }
    }
}

impl std::error::Error for GemmaOwnerApprovedReceiptEmitterDryRunGateError {}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaOwnerApprovedReceiptEmitterDryRunGateError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GemmaOwnerApprovedReceiptEmitterDryRunGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
        if !required.contains(&value.as_str()) {
            return Err(
                GemmaOwnerApprovedReceiptEmitterDryRunGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaOwnerApprovedReceiptEmitterDryRunGateError::MissingRequired(
                    kind,
                    required_value,
                ),
            );
        }
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), GemmaOwnerApprovedReceiptEmitterDryRunGateError> {
    if value.trim().is_empty() {
        return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::EmptyField(
            field,
        ));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaOwnerApprovedReceiptEmitterDryRunGateError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaOwnerApprovedReceiptEmitterDryRunGateError::BadPrefix(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        let gate = GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical();
        gate.validate()
            .expect("canonical receipt emitter dry run gate");
        assert_eq!(gate.metrics().emitter_section_count, 7);
        assert_eq!(gate.metrics().receipt_field_count, 24);
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut gate = GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical();
        gate.stores_raw_owner_path = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptEmitterDryRunGateError::PrivacyLeak
        );
    }

    #[test]
    fn rejects_receipt_payload_write() {
        let mut gate = GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical();
        gate.receipt_payload_bytes_written = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptEmitterDryRunGateError::ReceiptAction
        );
    }

    #[test]
    fn rejects_file_hashing() {
        let mut gate = GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical();
        gate.file_hash_count = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptEmitterDryRunGateError::LocalAction
        );
    }

    #[test]
    fn rejects_command_execution() {
        let mut gate = GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical();
        gate.command_executed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptEmitterDryRunGateError::RuntimeAction
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical().address(),
            GemmaOwnerApprovedReceiptEmitterDryRunGate::canonical().address()
        );
    }
}
