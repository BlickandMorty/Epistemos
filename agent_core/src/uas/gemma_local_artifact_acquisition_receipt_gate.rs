//! Gemma local artifact acquisition receipt gate.
//!
//! This gate freezes the receipt contract required after a future owner-approved
//! Gemma artifact acquisition. It is metadata-only: no receipt is read or
//! written, no model file is opened, no hash is computed, no command runs, and
//! no runtime route is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind, GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_ID,
};

pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_ID: &str =
    "F-GemmaLocalArtifactAcquisitionReceiptGate";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_CURSOR: &str =
    "gemma_local_artifact_acquisition_receipt_gate";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_local_artifact_acquisition_command_card/result.json#F-GemmaLocalArtifactAcquisitionCommandCard";

const UPSTREAM_PREFIX: &str = "artifact:falsifiers/gemma_local_artifact_acquisition_command_card/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_receipt_gate/";
const GATE_ID: &str = "gemma-local-artifact-acquisition-receipt-gate-v1";
const MAX_METADATA_BYTES: u64 = 160 * 1024;
const CREATED_AT_MS: u64 = 1_779_852_000_000;

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "owner_approval_ref",
    "selected_command_card_id",
    "selected_model_id",
    "selected_filename",
    "source_revision",
    "expected_source_bytes",
    "acquisition_mode",
    "quarantine_or_owner_path_root",
    "local_path_digest",
    "local_file_sha256",
    "local_file_byte_count",
    "file_size_matches_source",
    "sha256_computed_after_file_present",
    "tool_version_digest",
    "network_or_manual_boundary",
    "receipt_created_at_utc",
    "disk_space_observation_digest",
    "no_runtime_execution_ref",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "non_promotion_ref",
    "reviewer_visible_summary",
];

const ALLOWED_SELECTED_CARD_IDS: &[&str] = &[
    "gemma-e2b-owner-local-file",
    "gemma-e2b-hf-snapshot-quarantine",
    "gemma-e4b-hf-snapshot-quarantine",
    "gemma-12b-litert-import-quarantine",
];

const DENIED_SHORTCUTS: &[&str] = &[
    "raw_owner_path_in_receipt",
    "hf_cache_path_as_receipt",
    "download_completion_as_runtime_proof",
    "etag_as_sha256",
    "repo_revision_as_file_hash",
    "missing_owner_approval",
    "missing_local_sha256",
    "missing_local_byte_count",
    "llama_cli_hf_as_runtime_proof",
    "server_endpoint_as_receipt",
    "auto_default_model_after_receipt",
    "system_g_admission_from_receipt",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_command_card",
    "missing_receipt_field",
    "duplicate_receipt_field",
    "missing_selected_card",
    "unknown_selected_card",
    "missing_denied_shortcut",
    "duplicate_denied_shortcut",
    "missing_rejection_policy",
    "owner_approval_granted_in_gate",
    "receipt_present_in_gate",
    "receipt_bytes_written",
    "receipt_bytes_read",
    "raw_path_stored",
    "local_file_present",
    "local_file_opened",
    "local_file_hashed",
    "path_canonicalized",
    "byte_count_verified",
    "command_armed",
    "command_executed",
    "download_started",
    "server_started",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "route_mutated",
    "hidden_authority",
    "quality_claim",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-local-artifact-acquisition-receipt-gate:spec
// Plane: Controller + Verification.
// Residency: receipt contract only; zero file/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactAcquisitionReceiptGate {
    pub upstream_command_card_ref: String,
    pub upstream_command_card_id: String,
    pub artifact_root_prefix: String,
    pub gate_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_receipt_fields: Vec<String>,
    pub allowed_selected_card_ids: Vec<String>,
    pub denied_shortcuts: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_granted: bool,
    pub future_receipt_present: bool,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub stores_raw_owner_path: bool,
    pub local_file_present: bool,
    pub local_file_open_count: u64,
    pub local_file_hash_count: u64,
    pub path_canonicalization_count: u64,
    pub local_file_sha256_present: bool,
    pub local_file_byte_count_verified: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub download_started_count: u64,
    pub server_started: bool,
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

impl GemmaLocalArtifactAcquisitionReceiptGate {
    pub fn canonical() -> Self {
        Self {
            upstream_command_card_ref: GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_UPSTREAM_REF
                .to_string(),
            upstream_command_card_id: GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            gate_id: GATE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            allowed_selected_card_ids: ALLOWED_SELECTED_CARD_IDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            denied_shortcuts: DENIED_SHORTCUTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            owner_approval_granted: false,
            future_receipt_present: false,
            future_receipt_bytes_written: 0,
            future_receipt_bytes_read: 0,
            stores_raw_owner_path: false,
            local_file_present: false,
            local_file_open_count: 0,
            local_file_hash_count: 0,
            path_canonicalization_count: 0,
            local_file_sha256_present: false,
            local_file_byte_count_verified: false,
            command_armed: false,
            command_executed: false,
            download_started_count: 0,
            server_started: false,
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
            rollback_ref: "rollback:gemma-local-artifact-acquisition-receipt-gate-v1".to_string(),
            run_event_log_ref: "run_event_log:gemma-local-artifact-acquisition-receipt-gate-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-local-artifact-acquisition-receipt-gate-v1"
                .to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaLocalArtifactAcquisitionReceiptGateError> {
        validate_prefix(
            &self.upstream_command_card_ref,
            UPSTREAM_PREFIX,
            "upstream_command_card_ref",
        )?;
        if self.upstream_command_card_id != GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_ID {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.gate_id != GATE_ID {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::BadBuildStatus);
        }
        validate_unique_required(
            "receipt_field",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_required(
            "selected_card",
            &self.allowed_selected_card_ids,
            ALLOWED_SELECTED_CARD_IDS,
        )?;
        validate_unique_required("denied_shortcut", &self.denied_shortcuts, DENIED_SHORTCUTS)?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.owner_approval_granted
            || self.future_receipt_present
            || self.future_receipt_bytes_written != 0
            || self.future_receipt_bytes_read != 0
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::ReceiptAction);
        }
        if self.stores_raw_owner_path {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::RawPathLeak);
        }
        if self.local_file_present
            || self.local_file_open_count != 0
            || self.local_file_hash_count != 0
            || self.path_canonicalization_count != 0
            || self.local_file_sha256_present
            || self.local_file_byte_count_verified
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::LocalFileAction);
        }
        if self.command_armed
            || self.command_executed
            || self.download_started_count != 0
            || self.server_started
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::PromotionClaim);
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
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR {
            return Err(GemmaLocalArtifactAcquisitionReceiptGateError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_CURSOR.to_string()),
            self.gate_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaLocalArtifactAcquisitionReceiptGateMetrics {
        GemmaLocalArtifactAcquisitionReceiptGateMetrics {
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            allowed_selected_card_count: self.allowed_selected_card_ids.len() as u64,
            denied_shortcut_count: self.denied_shortcuts.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            future_receipt_present_count: u64::from(self.future_receipt_present),
            future_receipt_bytes_written: self.future_receipt_bytes_written,
            future_receipt_bytes_read: self.future_receipt_bytes_read,
            raw_path_storage_count: u64::from(self.stores_raw_owner_path),
            local_file_present_count: u64::from(self.local_file_present),
            local_file_open_count: self.local_file_open_count,
            local_file_hash_count: self.local_file_hash_count,
            path_canonicalization_count: self.path_canonicalization_count,
            local_file_sha256_present_count: u64::from(self.local_file_sha256_present),
            local_file_byte_count_verified_count: u64::from(self.local_file_byte_count_verified),
            command_armed_count: u64::from(self.command_armed),
            command_executed_count: u64::from(self.command_executed),
            download_started_count: self.download_started_count,
            server_started_count: u64::from(self.server_started),
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

// UAS: uas:gemma-local-artifact-acquisition-receipt-gate:metrics
// Plane: Verification.
// Residency: counters only; no receipt/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactAcquisitionReceiptGateMetrics {
    pub required_receipt_field_count: u64,
    pub allowed_selected_card_count: u64,
    pub denied_shortcut_count: u64,
    pub required_rejection_policy_count: u64,
    pub owner_approval_granted_count: u64,
    pub future_receipt_present_count: u64,
    pub future_receipt_bytes_written: u64,
    pub future_receipt_bytes_read: u64,
    pub raw_path_storage_count: u64,
    pub local_file_present_count: u64,
    pub local_file_open_count: u64,
    pub local_file_hash_count: u64,
    pub path_canonicalization_count: u64,
    pub local_file_sha256_present_count: u64,
    pub local_file_byte_count_verified_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub download_started_count: u64,
    pub server_started_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-local-artifact-acquisition-receipt-gate:error
// Plane: Verification.
// Residency: validation error only; no external bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaLocalArtifactAcquisitionReceiptGateError {
    EmptyField(&'static str),
    ControlCharacter(&'static str),
    BadPrefix(&'static str),
    MissingRequired(&'static str, &'static str),
    DuplicateValue(&'static str, String),
    BadUpstream,
    BadIdentity,
    BadBuildStatus,
    ReceiptAction,
    RawPathLeak,
    LocalFileAction,
    RuntimeAction,
    RuntimeBytesLoaded,
    RouteMutation,
    HiddenAuthority,
    PromotionClaim,
    AbstentionMissing,
    MetadataTooLarge,
    BadNextCursor,
}

impl fmt::Display for GemmaLocalArtifactAcquisitionReceiptGateError {
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
            Self::ReceiptAction => write!(f, "receipt action occurred"),
            Self::RawPathLeak => write!(f, "raw path leaked"),
            Self::LocalFileAction => write!(f, "local file action occurred"),
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

impl std::error::Error for GemmaLocalArtifactAcquisitionReceiptGateError {}

pub fn required_gemma_acquisition_receipt_gate_fields() -> &'static [&'static str] {
    REQUIRED_RECEIPT_FIELDS
}

pub fn allowed_gemma_acquisition_receipt_selected_card_ids() -> &'static [&'static str] {
    ALLOWED_SELECTED_CARD_IDS
}

pub fn denied_gemma_acquisition_receipt_shortcuts() -> &'static [&'static str] {
    DENIED_SHORTCUTS
}

pub fn required_gemma_acquisition_receipt_rejection_policies() -> &'static [&'static str] {
    REQUIRED_REJECTION_POLICIES
}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaLocalArtifactAcquisitionReceiptGateError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GemmaLocalArtifactAcquisitionReceiptGateError::DuplicateValue(kind, value.clone()),
            );
        }
        if !required.contains(&value.as_str()) {
            return Err(
                GemmaLocalArtifactAcquisitionReceiptGateError::DuplicateValue(kind, value.clone()),
            );
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaLocalArtifactAcquisitionReceiptGateError::MissingRequired(
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
) -> Result<(), GemmaLocalArtifactAcquisitionReceiptGateError> {
    if value.trim().is_empty() {
        return Err(GemmaLocalArtifactAcquisitionReceiptGateError::EmptyField(
            field,
        ));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaLocalArtifactAcquisitionReceiptGateError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaLocalArtifactAcquisitionReceiptGateError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaLocalArtifactAcquisitionReceiptGateError::BadPrefix(
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
        let gate = GemmaLocalArtifactAcquisitionReceiptGate::canonical();
        gate.validate().expect("canonical receipt gate");
        assert_eq!(gate.metrics().required_receipt_field_count, 24);
        assert_eq!(gate.metrics().future_receipt_present_count, 0);
    }

    #[test]
    fn rejects_receipt_presence() {
        let mut gate = GemmaLocalArtifactAcquisitionReceiptGate::canonical();
        gate.future_receipt_present = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaLocalArtifactAcquisitionReceiptGateError::ReceiptAction
        );
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut gate = GemmaLocalArtifactAcquisitionReceiptGate::canonical();
        gate.stores_raw_owner_path = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaLocalArtifactAcquisitionReceiptGateError::RawPathLeak
        );
    }

    #[test]
    fn rejects_local_file_hashing() {
        let mut gate = GemmaLocalArtifactAcquisitionReceiptGate::canonical();
        gate.local_file_hash_count = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaLocalArtifactAcquisitionReceiptGateError::LocalFileAction
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaLocalArtifactAcquisitionReceiptGate::canonical().address(),
            GemmaLocalArtifactAcquisitionReceiptGate::canonical().address()
        );
    }
}
