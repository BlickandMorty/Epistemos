//! Gemma owner-approved local artifact receipt probe.
//!
//! This metadata-only probe freezes the receipt shape required before a local
//! Gemma artifact can feed a runtime proof. It stores no raw owner paths, opens
//! no files, computes no hashes, arms no commands, and promotes no route.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind, GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_ID,
};

pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_ID: &str =
    "F-GemmaOwnerApprovedLocalArtifactReceiptProbe";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_CURSOR: &str =
    "gemma_owner_approved_local_artifact_receipt_probe";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_local_artifact_discovery_runbook_gate/result.json#F-GemmaLocalArtifactDiscoveryRunbookGate";

const UPSTREAM_PREFIX: &str = "artifact:falsifiers/gemma_local_artifact_discovery_runbook_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_probe/";
const PROBE_ID: &str = "gemma-owner-approved-local-artifact-receipt-probe-v1";
const CREATED_AT_MS: u64 = 1_780_027_200_000;
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "owner_approval_phrase_digest",
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
    "receipt_created_at_utc",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary",
    "non_promotion_ref",
];

const ALLOWED_MODEL_IDS: &[&str] = &[
    "google/gemma-4-E2B-it-qat-q4_0-gguf",
    "google/gemma-4-E4B-it-qat-q4_0-gguf",
    "mlx-community/gemma-4-e4b-it-4bit",
    "litert-community/gemma-4-12B-it-litert-lm",
];

const ALLOWED_RUNTIME_LANES: &[&str] = &[
    "gguf_llama_cpp_offline",
    "mlx_manifest_loader_pending",
    "litert_lm_pro_admission_pending",
];

const DENIED_SHORTCUTS: &[&str] = &[
    "source_card_as_local_receipt",
    "candidate_discovery_as_receipt",
    "hf_cache_path_as_receipt",
    "download_completion_as_receipt",
    "llama_cli_hf_as_receipt",
    "llama_server_as_receipt",
    "litert_serve_as_receipt",
    "raw_owner_path_in_artifact",
    "etag_as_sha256",
    "repo_revision_as_file_hash",
    "missing_owner_approval",
    "missing_local_sha256",
    "missing_byte_count",
    "auto_route_after_receipt",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_discovery_runbook",
    "missing_receipt_field",
    "duplicate_receipt_field",
    "missing_model_id",
    "unknown_model_id",
    "missing_runtime_lane",
    "unknown_runtime_lane",
    "missing_denied_shortcut",
    "duplicate_denied_shortcut",
    "missing_rejection_policy",
    "owner_approval_granted_in_metadata_gate",
    "receipt_present_in_metadata_gate",
    "receipt_bytes_written",
    "receipt_bytes_read",
    "raw_path_stored",
    "path_canonicalized",
    "local_file_opened",
    "local_file_hashed",
    "byte_count_verified",
    "sha256_materialized",
    "llama_cli_version_executed",
    "llama_cli_help_executed",
    "command_armed",
    "command_executed",
    "server_started",
    "network_probe_allowed",
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

// UAS: uas:gemma-owner-approved-local-artifact-receipt-probe:spec
// Plane: Controller + Verification.
// Residency: receipt schema only; zero filesystem/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedLocalArtifactReceiptProbe {
    pub upstream_discovery_runbook_ref: String,
    pub upstream_discovery_runbook_id: String,
    pub artifact_root_prefix: String,
    pub probe_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_receipt_fields: Vec<String>,
    pub allowed_model_ids: Vec<String>,
    pub allowed_runtime_lanes: Vec<String>,
    pub denied_shortcuts: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub receipt_fixture_present: bool,
    pub receipt_bytes_written: u64,
    pub receipt_bytes_read: u64,
    pub stores_raw_owner_path: bool,
    pub path_canonicalization_count: u64,
    pub local_file_open_count: u64,
    pub local_file_hash_count: u64,
    pub local_file_sha256_materialized: bool,
    pub byte_count_verified: bool,
    pub llama_cli_version_executed: bool,
    pub llama_cli_help_executed: bool,
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

impl GemmaOwnerApprovedLocalArtifactReceiptProbe {
    pub fn canonical() -> Self {
        Self {
            upstream_discovery_runbook_ref:
                GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_UPSTREAM_REF.to_string(),
            upstream_discovery_runbook_id: GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            probe_id: PROBE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            allowed_model_ids: ALLOWED_MODEL_IDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            allowed_runtime_lanes: ALLOWED_RUNTIME_LANES
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
            owner_approval_required: true,
            owner_approval_granted: false,
            receipt_fixture_present: false,
            receipt_bytes_written: 0,
            receipt_bytes_read: 0,
            stores_raw_owner_path: false,
            path_canonicalization_count: 0,
            local_file_open_count: 0,
            local_file_hash_count: 0,
            local_file_sha256_materialized: false,
            byte_count_verified: false,
            llama_cli_version_executed: false,
            llama_cli_help_executed: false,
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
            rollback_ref: "rollback:gemma-owner-approved-local-artifact-receipt-probe-v1"
                .to_string(),
            run_event_log_ref: "run_event_log:gemma-owner-approved-local-artifact-receipt-probe-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-owner-approved-local-artifact-receipt-probe-v1"
                .to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptProbeError> {
        validate_prefix(
            &self.upstream_discovery_runbook_ref,
            UPSTREAM_PREFIX,
            "upstream_discovery_runbook_ref",
        )?;
        if self.upstream_discovery_runbook_id != GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_ID {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.probe_id != PROBE_ID {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::BadBuildStatus);
        }
        validate_unique_required(
            "receipt_field",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_required("model_id", &self.allowed_model_ids, ALLOWED_MODEL_IDS)?;
        validate_unique_required(
            "runtime_lane",
            &self.allowed_runtime_lanes,
            ALLOWED_RUNTIME_LANES,
        )?;
        validate_unique_required("denied_shortcut", &self.denied_shortcuts, DENIED_SHORTCUTS)?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if !self.owner_approval_required {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::OwnerApprovalMissing);
        }
        if self.owner_approval_granted
            || self.receipt_fixture_present
            || self.receipt_bytes_written != 0
            || self.receipt_bytes_read != 0
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::ReceiptAction);
        }
        if self.stores_raw_owner_path {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::RawPathLeak);
        }
        if self.path_canonicalization_count != 0
            || self.local_file_open_count != 0
            || self.local_file_hash_count != 0
            || self.local_file_sha256_materialized
            || self.byte_count_verified
            || self.llama_cli_version_executed
            || self.llama_cli_help_executed
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::LocalFileAction);
        }
        if self.command_armed
            || self.command_executed
            || self.server_started
            || self.network_probe_allowed
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::PromotionClaim);
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
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR {
            return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_CURSOR.to_string()),
            self.probe_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaOwnerApprovedLocalArtifactReceiptProbeMetrics {
        GemmaOwnerApprovedLocalArtifactReceiptProbeMetrics {
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            allowed_model_id_count: self.allowed_model_ids.len() as u64,
            allowed_runtime_lane_count: self.allowed_runtime_lanes.len() as u64,
            denied_shortcut_count: self.denied_shortcuts.len() as u64,
            rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_required_count: u64::from(self.owner_approval_required),
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            receipt_fixture_present_count: u64::from(self.receipt_fixture_present),
            receipt_bytes_written: self.receipt_bytes_written,
            receipt_bytes_read: self.receipt_bytes_read,
            raw_path_storage_count: u64::from(self.stores_raw_owner_path),
            local_file_action_count: self.path_canonicalization_count
                + self.local_file_open_count
                + self.local_file_hash_count
                + u64::from(self.local_file_sha256_materialized)
                + u64::from(self.byte_count_verified)
                + u64::from(self.llama_cli_version_executed)
                + u64::from(self.llama_cli_help_executed),
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

// UAS: uas:gemma-owner-approved-local-artifact-receipt-probe:metrics
// Plane: Verification.
// Residency: counters only; no receipt/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedLocalArtifactReceiptProbeMetrics {
    pub required_receipt_field_count: u64,
    pub allowed_model_id_count: u64,
    pub allowed_runtime_lane_count: u64,
    pub denied_shortcut_count: u64,
    pub rejection_policy_count: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub receipt_fixture_present_count: u64,
    pub receipt_bytes_written: u64,
    pub receipt_bytes_read: u64,
    pub raw_path_storage_count: u64,
    pub local_file_action_count: u64,
    pub runtime_action_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-owner-approved-local-artifact-receipt-probe:error
// Plane: Verification.
// Residency: validation error only; no external bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaOwnerApprovedLocalArtifactReceiptProbeError {
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

impl fmt::Display for GemmaOwnerApprovedLocalArtifactReceiptProbeError {
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

impl std::error::Error for GemmaOwnerApprovedLocalArtifactReceiptProbeError {}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptProbeError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptProbeError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
        if !required.contains(&value.as_str()) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptProbeError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaOwnerApprovedLocalArtifactReceiptProbeError::MissingRequired(
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
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptProbeError> {
    if value.trim().is_empty() {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::EmptyField(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaOwnerApprovedLocalArtifactReceiptProbeError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaOwnerApprovedLocalArtifactReceiptProbeError::BadPrefix(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_probe_validates() {
        let probe = GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical();
        probe.validate().expect("canonical artifact receipt probe");
        assert_eq!(probe.metrics().required_receipt_field_count, 28);
        assert_eq!(probe.metrics().allowed_model_id_count, 4);
        assert_eq!(probe.metrics().allowed_runtime_lane_count, 3);
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut probe = GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical();
        probe.stores_raw_owner_path = true;
        assert_eq!(
            probe.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptProbeError::RawPathLeak
        );
    }

    #[test]
    fn rejects_file_hashing() {
        let mut probe = GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical();
        probe.local_file_hash_count = 1;
        assert_eq!(
            probe.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptProbeError::LocalFileAction
        );
    }

    #[test]
    fn rejects_cli_version_execution() {
        let mut probe = GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical();
        probe.llama_cli_version_executed = true;
        assert_eq!(
            probe.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptProbeError::LocalFileAction
        );
    }

    #[test]
    fn rejects_receipt_fixture_presence() {
        let mut probe = GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical();
        probe.receipt_fixture_present = true;
        assert_eq!(
            probe.validate().unwrap_err(),
            GemmaOwnerApprovedLocalArtifactReceiptProbeError::ReceiptAction
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical().address(),
            GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical().address()
        );
    }
}
