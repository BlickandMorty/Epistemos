//! Gemma owner-approved local artifact receipt intake gate.
//!
//! This metadata-only gate defines the typed intake boundary for a future
//! owner-approved Gemma artifact receipt. It intentionally performs no owner
//! approval, file scan, path canonicalization, file open, hash, command
//! execution, model load, route mutation, or product promotion.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_ID,
};

pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_ID: &str =
    "F-GemmaOwnerApprovedLocalArtifactReceiptIntakeGate";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_CURSOR: &str =
    "gemma_owner_approved_local_artifact_receipt_intake_gate";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_owner_approved_local_artifact_receipt_probe/result.json#F-GemmaOwnerApprovedLocalArtifactReceiptProbe";

const UPSTREAM_PREFIX: &str =
    "artifact:falsifiers/gemma_owner_approved_local_artifact_receipt_probe/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_intake_gate/";
const GATE_ID: &str = "gemma-owner-approved-local-artifact-receipt-intake-gate-v1";
const CREATED_AT_MS: u64 = 1_780_113_600_000;
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_INTAKE_SECTIONS: &[&str] = &[
    "owner_approval",
    "artifact_identity",
    "file_integrity",
    "runtime_lane",
    "tool_identity",
    "privacy_redaction",
    "proof_surfaces",
    "non_promotion",
];

const REQUIRED_CANONICAL_FIELDS: &[&str] = &[
    "schema_version",
    "owner_approval_phrase_digest",
    "owner_approval_timestamp_utc",
    "selected_model_id",
    "model_family",
    "source_repo",
    "source_revision",
    "expected_filename",
    "expected_byte_count",
    "observed_byte_count",
    "observed_byte_count_matches_expected",
    "local_file_sha256",
    "redacted_path_digest",
    "raw_path_absent",
    "file_type",
    "runtime_lane",
    "selected_command_card_id",
    "llama_cli_version_digest",
    "llama_cli_help_digest",
    "offline_flag_present",
    "source_license_ref",
    "provenance_mode",
    "hardware_profile_ref",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary",
    "non_promotion_ref",
    "receipt_digest",
];

const ALLOWED_RECEIPT_KINDS: &[&str] = &[
    "gemma_e2b_qat_gguf_direct_file",
    "gemma_e4b_qat_gguf_direct_file",
    "gemma_e4b_mlx_manifest_file",
    "gemma_12b_litert_lm_bundle",
];

const REQUIRED_PRIVACY_RULES: &[&str] = &[
    "raw_owner_path_absent",
    "path_digest_only",
    "owner_phrase_plaintext_absent",
    "raw_prompt_absent",
    "raw_output_absent",
    "stdout_stderr_digest_only",
    "token_digest_only_before_review",
    "allowlist_before_rank",
    "no_hidden_cache_identity",
    "reviewer_summary_visible",
];

const DENIED_INTAKE_SHORTCUTS: &[&str] = &[
    "hf_cache_path_as_identity",
    "llama_cli_hf_as_identity",
    "llama_server_endpoint_as_identity",
    "litert_serve_endpoint_as_identity",
    "download_completion_as_identity",
    "etag_as_file_hash",
    "repo_revision_as_file_hash",
    "raw_path_as_receipt",
    "candidate_discovery_as_receipt",
    "source_card_as_receipt",
    "settings_toggle_as_receipt",
    "route_admission_as_receipt",
    "quality_score_as_receipt",
    "model_picker_row_as_receipt",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_receipt_probe",
    "missing_intake_section",
    "duplicate_intake_section",
    "missing_canonical_field",
    "duplicate_canonical_field",
    "missing_receipt_kind",
    "unknown_receipt_kind",
    "missing_privacy_rule",
    "duplicate_privacy_rule",
    "missing_denied_shortcut",
    "duplicate_denied_shortcut",
    "receipt_payload_present_in_metadata_gate",
    "owner_approval_granted_in_metadata_gate",
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
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "quality_claim",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-owner-approved-local-artifact-receipt-intake-gate:spec
// Plane: Controller + Verification.
// Residency: intake schema only; zero receipt/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedLocalArtifactReceiptIntakeGate {
    pub upstream_receipt_probe_ref: String,
    pub upstream_receipt_probe_id: String,
    pub artifact_root_prefix: String,
    pub gate_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_intake_sections: Vec<String>,
    pub required_canonical_fields: Vec<String>,
    pub allowed_receipt_kinds: Vec<String>,
    pub required_privacy_rules: Vec<String>,
    pub denied_intake_shortcuts: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub receipt_payload_present: bool,
    pub receipt_payload_bytes_read: u64,
    pub receipt_payload_bytes_written: u64,
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

impl GemmaOwnerApprovedLocalArtifactReceiptIntakeGate {
    pub fn canonical() -> Self {
        Self {
            upstream_receipt_probe_ref:
                GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_UPSTREAM_REF.to_string(),
            upstream_receipt_probe_id: GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            gate_id: GATE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_intake_sections: REQUIRED_INTAKE_SECTIONS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_canonical_fields: REQUIRED_CANONICAL_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            allowed_receipt_kinds: ALLOWED_RECEIPT_KINDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_privacy_rules: REQUIRED_PRIVACY_RULES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            denied_intake_shortcuts: DENIED_INTAKE_SHORTCUTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            owner_approval_required: true,
            owner_approval_granted: false,
            receipt_payload_present: false,
            receipt_payload_bytes_read: 0,
            receipt_payload_bytes_written: 0,
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
            rollback_ref: "rollback:gemma-owner-approved-local-artifact-receipt-intake-gate-v1"
                .to_string(),
            run_event_log_ref:
                "run_event_log:gemma-owner-approved-local-artifact-receipt-intake-gate-v1"
                    .to_string(),
            answer_packet_ref:
                "answer_packet:gemma-owner-approved-local-artifact-receipt-intake-gate-v1"
                    .to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError> {
        validate_prefix(
            &self.upstream_receipt_probe_ref,
            UPSTREAM_PREFIX,
            "upstream_receipt_probe_ref",
        )?;
        if self.upstream_receipt_probe_id != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_ID {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.gate_id != GATE_ID {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::BadBuildStatus);
        }
        validate_unique_required(
            "section",
            &self.required_intake_sections,
            REQUIRED_INTAKE_SECTIONS,
        )?;
        validate_unique_required(
            "field",
            &self.required_canonical_fields,
            REQUIRED_CANONICAL_FIELDS,
        )?;
        validate_unique_required(
            "receipt_kind",
            &self.allowed_receipt_kinds,
            ALLOWED_RECEIPT_KINDS,
        )?;
        validate_unique_required(
            "privacy_rule",
            &self.required_privacy_rules,
            REQUIRED_PRIVACY_RULES,
        )?;
        validate_unique_required(
            "shortcut",
            &self.denied_intake_shortcuts,
            DENIED_INTAKE_SHORTCUTS,
        )?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if !self.owner_approval_required {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::OwnerApprovalMissing,
            );
        }
        if self.owner_approval_granted
            || self.receipt_payload_present
            || self.receipt_payload_bytes_read != 0
            || self.receipt_payload_bytes_written != 0
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::ReceiptAction);
        }
        if self.stores_raw_owner_path || self.stores_owner_phrase_plaintext {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::PrivacyLeak);
        }
        if self.path_canonicalization_count != 0
            || self.file_open_count != 0
            || self.file_hash_count != 0
            || self.byte_count_verified
            || self.llama_cli_executed
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::LocalAction);
        }
        if self.command_armed
            || self.command_executed
            || self.server_started
            || self.network_probe_allowed
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::PromotionClaim);
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
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_NEXT_CURSOR {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_INTAKE_GATE_CURSOR.to_string(),
            ),
            self.gate_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaOwnerApprovedLocalArtifactReceiptIntakeGateMetrics {
        GemmaOwnerApprovedLocalArtifactReceiptIntakeGateMetrics {
            intake_section_count: self.required_intake_sections.len() as u64,
            canonical_field_count: self.required_canonical_fields.len() as u64,
            allowed_receipt_kind_count: self.allowed_receipt_kinds.len() as u64,
            privacy_rule_count: self.required_privacy_rules.len() as u64,
            denied_shortcut_count: self.denied_intake_shortcuts.len() as u64,
            rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_required_count: u64::from(self.owner_approval_required),
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            receipt_payload_present_count: u64::from(self.receipt_payload_present),
            receipt_payload_bytes_read: self.receipt_payload_bytes_read,
            receipt_payload_bytes_written: self.receipt_payload_bytes_written,
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

// UAS: uas:gemma-owner-approved-local-artifact-receipt-intake-gate:metrics
// Plane: Verification.
// Residency: counters only; no owner receipt or model bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedLocalArtifactReceiptIntakeGateMetrics {
    pub intake_section_count: u64,
    pub canonical_field_count: u64,
    pub allowed_receipt_kind_count: u64,
    pub privacy_rule_count: u64,
    pub denied_shortcut_count: u64,
    pub rejection_policy_count: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub receipt_payload_present_count: u64,
    pub receipt_payload_bytes_read: u64,
    pub receipt_payload_bytes_written: u64,
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

// UAS: uas:gemma-owner-approved-local-artifact-receipt-intake-gate:error
// Plane: Verification.
// Residency: validation error only; no receipt/model/runtime bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError {
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

impl fmt::Display for GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError {
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

impl std::error::Error for GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError {}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
        if !required.contains(&value.as_str()) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::MissingRequired(
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
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError> {
    if value.trim().is_empty() {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::EmptyField(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::BadPrefix(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        let gate = GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical();
        gate.validate().expect("canonical receipt intake gate");
        assert_eq!(gate.metrics().canonical_field_count, 30);
        assert_eq!(gate.metrics().allowed_receipt_kind_count, 4);
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut gate = GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical();
        gate.stores_raw_owner_path = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::PrivacyLeak
        );
    }

    #[test]
    fn rejects_owner_phrase_plaintext_storage() {
        let mut gate = GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical();
        gate.stores_owner_phrase_plaintext = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::PrivacyLeak
        );
    }

    #[test]
    fn rejects_receipt_payload_presence() {
        let mut gate = GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical();
        gate.receipt_payload_present = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::ReceiptAction
        );
    }

    #[test]
    fn rejects_file_open() {
        let mut gate = GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical();
        gate.file_open_count = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptIntakeGateError::LocalAction
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical().address(),
            GemmaOwnerApprovedLocalArtifactReceiptIntakeGate::canonical().address()
        );
    }
}
