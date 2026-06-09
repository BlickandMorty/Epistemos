//! Gemma local artifact discovery runbook gate.
//!
//! This metadata-only gate defines how future sessions may look for an existing
//! Gemma artifact without leaking raw paths, opening model bytes, hashing files,
//! running commands, or treating discovery as runtime proof.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_ID,
};

pub const GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_ID: &str =
    "F-GemmaLocalArtifactDiscoveryRunbookGate";
pub const GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_CURSOR: &str =
    "gemma_local_artifact_discovery_runbook_gate";
pub const GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR: &str =
    "gemma_owner_approved_local_artifact_receipt_probe";
pub const GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_official_convenience_command_denylist_gate/result.json#F-GemmaOfficialConvenienceCommandDenylistGate";

const UPSTREAM_PREFIX: &str =
    "artifact:falsifiers/gemma_official_convenience_command_denylist_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_local_artifact_discovery_runbook_gate/";
const GATE_ID: &str = "gemma-local-artifact-discovery-runbook-gate-v1";
const CREATED_AT_MS: u64 = 1_779_938_400_001;
const MAX_METADATA_BYTES: u64 = 96 * 1024;

const SYMBOLIC_SEARCH_ROOTS: &[&str] = &[
    "owner_downloads_root",
    "repo_models_quarantine_root",
    "huggingface_cache_root",
    "litert_import_root",
];

const EXPECTED_ARTIFACT_PATTERNS: &[&str] = &[
    "gemma-4-E2B-it-qat-q4_0-gguf",
    "gemma-4-E4B-it-qat-q4_0-gguf",
    "gemma-4-12B-it-litert-lm",
    "gemma-4-12B-it-qat-q4_0-gguf",
];

const REQUIRED_DISCOVERY_RULES: &[&str] = &[
    "owner_approval_before_scan",
    "symbolic_roots_only",
    "bounded_depth",
    "extension_allowlist",
    "filename_pattern_allowlist",
    "path_digest_only",
    "raw_path_redaction",
    "no_file_open",
    "no_file_hash_until_receipt",
    "no_runtime_command",
    "no_server_or_endpoint",
    "receipt_required_after_candidate",
    "abstain_if_multiple_candidates",
    "abstain_if_source_card_mismatch",
    "rollback_ref_required",
    "run_event_log_ref_required",
    "answer_packet_ref_required",
    "non_promotion_required",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_denylist_gate",
    "missing_symbolic_root",
    "duplicate_symbolic_root",
    "missing_artifact_pattern",
    "duplicate_artifact_pattern",
    "missing_discovery_rule",
    "duplicate_discovery_rule",
    "missing_rejection_policy",
    "owner_approval_granted_in_gate",
    "raw_path_stored",
    "path_canonicalized",
    "file_opened",
    "file_hashed",
    "byte_count_verified",
    "command_armed",
    "command_executed",
    "server_started",
    "network_probe_allowed",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "route_mutated",
    "hidden_authority",
    "candidate_found_promotes_receipt",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "l2_l3_t4_or_live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-local-artifact-discovery-runbook-gate:spec
// Plane: Controller + Verification.
// Residency: symbolic discovery plan only; zero filesystem/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactDiscoveryRunbookGate {
    pub upstream_denylist_gate_ref: String,
    pub upstream_denylist_gate_id: String,
    pub artifact_root_prefix: String,
    pub gate_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub symbolic_search_roots: Vec<String>,
    pub expected_artifact_patterns: Vec<String>,
    pub required_discovery_rules: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_granted: bool,
    pub raw_path_stored: bool,
    pub path_canonicalization_count: u64,
    pub file_open_count: u64,
    pub file_hash_count: u64,
    pub byte_count_verified: bool,
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
    pub candidate_found_promotes_receipt: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_required: bool,
    pub l2_l3_t4_claim: bool,
    pub live_gemma_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub next_cursor: String,
}

impl GemmaLocalArtifactDiscoveryRunbookGate {
    pub fn canonical() -> Self {
        Self {
            upstream_denylist_gate_ref: GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_UPSTREAM_REF
                .to_string(),
            upstream_denylist_gate_id: GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            gate_id: GATE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            symbolic_search_roots: SYMBOLIC_SEARCH_ROOTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            expected_artifact_patterns: EXPECTED_ARTIFACT_PATTERNS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_discovery_rules: REQUIRED_DISCOVERY_RULES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            owner_approval_granted: false,
            raw_path_stored: false,
            path_canonicalization_count: 0,
            file_open_count: 0,
            file_hash_count: 0,
            byte_count_verified: false,
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
            candidate_found_promotes_receipt: false,
            rollback_ref: "rollback:gemma-local-artifact-discovery-runbook-gate-v1".to_string(),
            run_event_log_ref: "run_event_log:gemma-local-artifact-discovery-runbook-gate-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-local-artifact-discovery-runbook-gate-v1"
                .to_string(),
            abstention_required: true,
            l2_l3_t4_claim: false,
            live_gemma_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaLocalArtifactDiscoveryRunbookGateError> {
        validate_prefix(
            &self.upstream_denylist_gate_ref,
            UPSTREAM_PREFIX,
            "upstream_denylist_gate_ref",
        )?;
        if self.upstream_denylist_gate_id != GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_ID {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.gate_id != GATE_ID {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::BadBuildStatus);
        }
        validate_unique_required(
            "symbolic_root",
            &self.symbolic_search_roots,
            SYMBOLIC_SEARCH_ROOTS,
        )?;
        validate_unique_required(
            "artifact_pattern",
            &self.expected_artifact_patterns,
            EXPECTED_ARTIFACT_PATTERNS,
        )?;
        validate_unique_required(
            "discovery_rule",
            &self.required_discovery_rules,
            REQUIRED_DISCOVERY_RULES,
        )?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.owner_approval_granted {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::OwnerApprovalAction);
        }
        if self.raw_path_stored {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::RawPathLeak);
        }
        if self.path_canonicalization_count != 0
            || self.file_open_count != 0
            || self.file_hash_count != 0
            || self.byte_count_verified
        {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::FileAction);
        }
        if self.command_armed
            || self.command_executed
            || self.server_started
            || self.network_probe_allowed
        {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::HiddenAuthority);
        }
        if self.candidate_found_promotes_receipt {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::CandidatePromotion);
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
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::AbstentionMissing);
        }
        if self.l2_l3_t4_claim
            || self.live_gemma_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::PromotionClaim);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_NEXT_CURSOR {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_LOCAL_ARTIFACT_DISCOVERY_RUNBOOK_GATE_CURSOR.to_string()),
            self.gate_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaLocalArtifactDiscoveryRunbookGateMetrics {
        GemmaLocalArtifactDiscoveryRunbookGateMetrics {
            symbolic_search_root_count: self.symbolic_search_roots.len() as u64,
            expected_artifact_pattern_count: self.expected_artifact_patterns.len() as u64,
            discovery_rule_count: self.required_discovery_rules.len() as u64,
            rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            raw_path_storage_count: u64::from(self.raw_path_stored),
            file_action_count: self.path_canonicalization_count
                + self.file_open_count
                + self.file_hash_count
                + u64::from(self.byte_count_verified),
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
            candidate_promotion_count: u64::from(self.candidate_found_promotes_receipt),
            promotion_claim_count: u64::from(self.l2_l3_t4_claim)
                + u64::from(self.live_gemma_claim)
                + u64::from(self.live_dense_70b_claim)
                + u64::from(self.ssd_as_ram_claim),
            metadata_bytes: self.metadata_bytes,
        }
    }
}

// UAS: uas:gemma-local-artifact-discovery-runbook-gate:metrics
// Plane: Verification.
// Residency: counters only; no filesystem/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactDiscoveryRunbookGateMetrics {
    pub symbolic_search_root_count: u64,
    pub expected_artifact_pattern_count: u64,
    pub discovery_rule_count: u64,
    pub rejection_policy_count: u64,
    pub owner_approval_granted_count: u64,
    pub raw_path_storage_count: u64,
    pub file_action_count: u64,
    pub runtime_action_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub candidate_promotion_count: u64,
    pub promotion_claim_count: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-local-artifact-discovery-runbook-gate:error
// Plane: Verification.
// Residency: validation error only; no external bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaLocalArtifactDiscoveryRunbookGateError {
    EmptyField(&'static str),
    ControlCharacter(&'static str),
    BadPrefix(&'static str),
    MissingRequired(&'static str, &'static str),
    DuplicateValue(&'static str, String),
    BadUpstream,
    BadIdentity,
    BadBuildStatus,
    OwnerApprovalAction,
    RawPathLeak,
    FileAction,
    RuntimeAction,
    RuntimeBytesLoaded,
    RouteMutation,
    HiddenAuthority,
    CandidatePromotion,
    AbstentionMissing,
    PromotionClaim,
    MetadataTooLarge,
    BadNextCursor,
}

impl fmt::Display for GemmaLocalArtifactDiscoveryRunbookGateError {
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
            Self::OwnerApprovalAction => write!(f, "owner approval action occurred"),
            Self::RawPathLeak => write!(f, "raw path leaked"),
            Self::FileAction => write!(f, "file action occurred"),
            Self::RuntimeAction => write!(f, "runtime action occurred"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::RouteMutation => write!(f, "route mutation"),
            Self::HiddenAuthority => write!(f, "hidden authority"),
            Self::CandidatePromotion => write!(f, "candidate promoted"),
            Self::AbstentionMissing => write!(f, "abstention missing"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataTooLarge => write!(f, "metadata too large"),
            Self::BadNextCursor => write!(f, "bad next cursor"),
        }
    }
}

impl std::error::Error for GemmaLocalArtifactDiscoveryRunbookGateError {}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaLocalArtifactDiscoveryRunbookGateError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::DuplicateValue(
                kind,
                value.clone(),
            ));
        }
        if !required.contains(&value.as_str()) {
            return Err(GemmaLocalArtifactDiscoveryRunbookGateError::DuplicateValue(
                kind,
                value.clone(),
            ));
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaLocalArtifactDiscoveryRunbookGateError::MissingRequired(kind, required_value),
            );
        }
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), GemmaLocalArtifactDiscoveryRunbookGateError> {
    if value.trim().is_empty() {
        return Err(GemmaLocalArtifactDiscoveryRunbookGateError::EmptyField(
            field,
        ));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaLocalArtifactDiscoveryRunbookGateError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaLocalArtifactDiscoveryRunbookGateError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaLocalArtifactDiscoveryRunbookGateError::BadPrefix(
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
        let gate = GemmaLocalArtifactDiscoveryRunbookGate::canonical();
        gate.validate().expect("canonical discovery runbook");
        assert_eq!(gate.metrics().symbolic_search_root_count, 4);
        assert_eq!(gate.metrics().expected_artifact_pattern_count, 4);
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut gate = GemmaLocalArtifactDiscoveryRunbookGate::canonical();
        gate.raw_path_stored = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaLocalArtifactDiscoveryRunbookGateError::RawPathLeak
        );
    }

    #[test]
    fn rejects_file_hashing() {
        let mut gate = GemmaLocalArtifactDiscoveryRunbookGate::canonical();
        gate.file_hash_count = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaLocalArtifactDiscoveryRunbookGateError::FileAction
        );
    }

    #[test]
    fn rejects_candidate_promotion() {
        let mut gate = GemmaLocalArtifactDiscoveryRunbookGate::canonical();
        gate.candidate_found_promotes_receipt = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaLocalArtifactDiscoveryRunbookGateError::CandidatePromotion
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaLocalArtifactDiscoveryRunbookGate::canonical().address(),
            GemmaLocalArtifactDiscoveryRunbookGate::canonical().address()
        );
    }
}
