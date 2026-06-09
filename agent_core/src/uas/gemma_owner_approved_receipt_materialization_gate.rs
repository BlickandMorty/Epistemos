//! Gemma owner-approved receipt materialization gate.
//!
//! This metadata-only gate defines the contract for a future owner-guided
//! receipt materializer. It does not materialize a receipt, read owner paths,
//! open or hash files, execute tools, load model bytes, mutate routes, or
//! promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_ID,
};

pub const GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_ID: &str =
    "F-GemmaOwnerApprovedReceiptMaterializationGate";
pub const GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_CURSOR: &str =
    "gemma_owner_approved_receipt_materialization_gate";
pub const GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_owner_approved_receipt_emitter_dry_run_gate/result.json#F-GemmaOwnerApprovedReceiptEmitterDryRunGate";

const UPSTREAM_PREFIX: &str =
    "artifact:falsifiers/gemma_owner_approved_receipt_emitter_dry_run_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_owner_approved_receipt_materialization_gate/";
const GATE_ID: &str = "gemma-owner-approved-receipt-materialization-gate-v1";
const CREATED_AT_MS: u64 = 1_780_286_400_000;
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_MATERIALIZATION_FIELDS: &[&str] = &[
    "owner_approval_phrase_digest",
    "symbolic_owner_artifact_ref",
    "redacted_path_digest_slot",
    "selected_model_id",
    "source_revision",
    "expected_filename",
    "expected_byte_count",
    "observed_byte_count_slot",
    "local_file_sha256_slot",
    "runtime_lane",
    "tool_identity_slot",
    "offline_flag_required",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary",
    "non_promotion_ref",
];

const ALLOWED_MATERIALIZATION_MODES: &[&str] = &[
    "e2b_qat_gguf_direct_file_receipt",
    "e4b_qat_gguf_direct_file_receipt",
    "e4b_mlx_manifest_reconciliation_receipt",
    "gemma_12b_litert_bundle_receipt",
];

const REQUIRED_SAFETY_CHECKS: &[&str] = &[
    "owner_approval_required",
    "raw_path_redaction_required",
    "symbolic_input_only",
    "single_artifact_only",
    "digest_slots_only",
    "byte_count_slots_only",
    "tool_identity_slots_only",
    "no_runtime_execution",
    "no_route_mutation",
    "reviewer_summary_required",
    "rollback_required",
    "answer_packet_required",
];

const DENIED_SHORTCUTS: &[&str] = &[
    "hf_cache_as_artifact",
    "download_completion_as_receipt",
    "source_card_as_receipt",
    "model_picker_as_receipt",
    "settings_toggle_as_receipt",
    "server_endpoint_as_receipt",
    "etag_as_sha256",
    "repo_revision_as_file_hash",
    "raw_path_in_artifact",
    "owner_phrase_plaintext",
    "quality_score_as_receipt",
    "route_admission_as_receipt",
];

// UAS: uas:gemma-owner-approved-receipt-materialization-gate:spec
// Plane: Controller + Verification.
// Residency: materialization contract only; zero receipt/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedReceiptMaterializationGate {
    pub upstream_emitter_dry_run_ref: String,
    pub upstream_emitter_dry_run_id: String,
    pub artifact_root_prefix: String,
    pub gate_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_materialization_fields: Vec<String>,
    pub allowed_materialization_modes: Vec<String>,
    pub required_safety_checks: Vec<String>,
    pub denied_shortcuts: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub materialized_receipt_bytes: u64,
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

impl GemmaOwnerApprovedReceiptMaterializationGate {
    pub fn canonical() -> Self {
        Self {
            upstream_emitter_dry_run_ref:
                GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_UPSTREAM_REF.to_string(),
            upstream_emitter_dry_run_id: GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            gate_id: GATE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_materialization_fields: strings(REQUIRED_MATERIALIZATION_FIELDS),
            allowed_materialization_modes: strings(ALLOWED_MATERIALIZATION_MODES),
            required_safety_checks: strings(REQUIRED_SAFETY_CHECKS),
            denied_shortcuts: strings(DENIED_SHORTCUTS),
            owner_approval_required: true,
            owner_approval_granted: false,
            materialized_receipt_bytes: 0,
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
            rollback_ref: "rollback:gemma-owner-approved-receipt-materialization-gate-v1"
                .to_string(),
            run_event_log_ref: "run_event_log:gemma-owner-approved-receipt-materialization-gate-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-owner-approved-receipt-materialization-gate-v1"
                .to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaOwnerApprovedReceiptMaterializationGateError> {
        validate_prefix(
            &self.upstream_emitter_dry_run_ref,
            UPSTREAM_PREFIX,
            "upstream_emitter_dry_run_ref",
        )?;
        if self.upstream_emitter_dry_run_id != GEMMA_OWNER_APPROVED_RECEIPT_EMITTER_DRY_RUN_GATE_ID
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.gate_id != GATE_ID {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::BadBuildStatus);
        }
        validate_unique_required(
            "field",
            &self.required_materialization_fields,
            REQUIRED_MATERIALIZATION_FIELDS,
        )?;
        validate_unique_required(
            "mode",
            &self.allowed_materialization_modes,
            ALLOWED_MATERIALIZATION_MODES,
        )?;
        validate_unique_required(
            "safety",
            &self.required_safety_checks,
            REQUIRED_SAFETY_CHECKS,
        )?;
        validate_unique_required("shortcut", &self.denied_shortcuts, DENIED_SHORTCUTS)?;
        if !self.owner_approval_required {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::OwnerApprovalMissing);
        }
        if self.owner_approval_granted
            || self.materialized_receipt_bytes != 0
            || self.receipt_payload_bytes_read != 0
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::ReceiptAction);
        }
        if self.stores_raw_owner_path || self.stores_owner_phrase_plaintext {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::PrivacyLeak);
        }
        if self.path_canonicalization_count != 0
            || self.file_open_count != 0
            || self.file_hash_count != 0
            || self.byte_count_verified
            || self.llama_cli_executed
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::LocalAction);
        }
        if self.command_armed
            || self.command_executed
            || self.server_started
            || self.network_probe_allowed
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::PromotionClaim);
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
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_NEXT_CURSOR {
            return Err(GemmaOwnerApprovedReceiptMaterializationGateError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_OWNER_APPROVED_RECEIPT_MATERIALIZATION_GATE_CURSOR.to_string()),
            self.gate_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaOwnerApprovedReceiptMaterializationGateMetrics {
        GemmaOwnerApprovedReceiptMaterializationGateMetrics {
            materialization_field_count: self.required_materialization_fields.len() as u64,
            materialization_mode_count: self.allowed_materialization_modes.len() as u64,
            safety_check_count: self.required_safety_checks.len() as u64,
            denied_shortcut_count: self.denied_shortcuts.len() as u64,
            owner_approval_required_count: u64::from(self.owner_approval_required),
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            materialized_receipt_bytes: self.materialized_receipt_bytes,
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

// UAS: uas:gemma-owner-approved-receipt-materialization-gate:metrics
// Plane: Verification.
// Residency: counters only; no receipt/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOwnerApprovedReceiptMaterializationGateMetrics {
    pub materialization_field_count: u64,
    pub materialization_mode_count: u64,
    pub safety_check_count: u64,
    pub denied_shortcut_count: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub materialized_receipt_bytes: u64,
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

// UAS: uas:gemma-owner-approved-receipt-materialization-gate:error
// Plane: Verification.
// Residency: validation error only; no receipt/model/runtime bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaOwnerApprovedReceiptMaterializationGateError {
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

impl fmt::Display for GemmaOwnerApprovedReceiptMaterializationGateError {
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

impl std::error::Error for GemmaOwnerApprovedReceiptMaterializationGateError {}

fn strings(values: &[&str]) -> Vec<String> {
    values.iter().map(|value| value.to_string()).collect()
}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaOwnerApprovedReceiptMaterializationGateError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GemmaOwnerApprovedReceiptMaterializationGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
        if !required.contains(&value.as_str()) {
            return Err(
                GemmaOwnerApprovedReceiptMaterializationGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaOwnerApprovedReceiptMaterializationGateError::MissingRequired(
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
) -> Result<(), GemmaOwnerApprovedReceiptMaterializationGateError> {
    if value.trim().is_empty() {
        return Err(GemmaOwnerApprovedReceiptMaterializationGateError::EmptyField(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaOwnerApprovedReceiptMaterializationGateError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaOwnerApprovedReceiptMaterializationGateError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaOwnerApprovedReceiptMaterializationGateError::BadPrefix(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        let gate = GemmaOwnerApprovedReceiptMaterializationGate::canonical();
        gate.validate().expect("canonical materialization gate");
        assert_eq!(gate.metrics().materialization_field_count, 18);
        assert_eq!(gate.metrics().materialization_mode_count, 4);
    }

    #[test]
    fn rejects_receipt_materialization() {
        let mut gate = GemmaOwnerApprovedReceiptMaterializationGate::canonical();
        gate.materialized_receipt_bytes = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptMaterializationGateError::ReceiptAction
        );
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut gate = GemmaOwnerApprovedReceiptMaterializationGate::canonical();
        gate.stores_raw_owner_path = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptMaterializationGateError::PrivacyLeak
        );
    }

    #[test]
    fn rejects_file_open() {
        let mut gate = GemmaOwnerApprovedReceiptMaterializationGate::canonical();
        gate.file_open_count = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptMaterializationGateError::LocalAction
        );
    }

    #[test]
    fn rejects_route_mutation() {
        let mut gate = GemmaOwnerApprovedReceiptMaterializationGate::canonical();
        gate.runtime_router_mutation_allowed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOwnerApprovedReceiptMaterializationGateError::RouteMutation
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaOwnerApprovedReceiptMaterializationGate::canonical().address(),
            GemmaOwnerApprovedReceiptMaterializationGate::canonical().address()
        );
    }
}
