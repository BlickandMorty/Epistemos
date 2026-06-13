//! Gemma QAT E2B owner path manifest digest gate.
//!
//! This primitive binds the digest-only contract for a future owner-approved
//! local Gemma E2B GGUF path manifest. It keeps the manifest absent in the
//! default loop: no raw path is stored, no canonical path bytes are retained,
//! no file is opened or hashed, no command is armed, and no Gemma capability is
//! promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_ID: &str =
    "F-GemmaQATE2BOwnerPathManifestDigestGate";
pub const GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_CURSOR: &str =
    "gemma_qat_e2b_owner_path_manifest_digest_gate";
pub const GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_model_file_and_llama_cpp_digest_gate";
pub const GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_gate/result.json#F-GemmaQATE2BFirstTokenRuntimeArtifactReviewGate";

pub const GEMMA_QAT_E2B_SOURCE_REVISION: &str = "1894d1fc0a19d86697abd40483f5983c867df03f";
pub const GEMMA_QAT_E2B_EXPECTED_FILE_BYTES: u64 = 3_349_514_112;

const UPSTREAM_REVIEW_GATE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_owner_path_manifest_digest_gate/";
const DIGEST_CARD_ID: &str = "gemma-e2b-gguf-owner-path-manifest-digest-contract";
const OWNER_APPROVAL_PHRASE: &str = "APPROVE_GEMMA_E2B_GGUF_PATH_MANIFEST_DIGEST_V1";
const MAX_METADATA_BYTES: u64 = 192 * 1024;

const REQUIRED_MANIFEST_DIGEST_FIELDS: &[&str] = &[
    "manifest_schema_version",
    "manifest_id",
    "upstream_review_gate_digest",
    "owner_approval_phrase_digest",
    "owner_approval_timestamp_digest",
    "owner_device_profile_digest",
    "owner_manifest_digest",
    "owner_manifest_signature_digest",
    "local_model_path_digest",
    "canonical_path_digest",
    "canonical_parent_digest",
    "path_policy_digest",
    "symlink_policy_digest",
    "model_id",
    "source_revision",
    "required_filename",
    "expected_file_size_bytes",
    "model_file_sha256_pending",
    "llama_cpp_binary_path_digest",
    "llama_cpp_binary_sha256_pending",
    "llama_cpp_version_digest_pending",
    "privacy_redaction_policy_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "abstention_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_review_gate",
    "missing_owner_approval_phrase",
    "owner_approval_laundered",
    "owner_manifest_present_in_default_loop",
    "owner_manifest_signature_present_in_default_loop",
    "raw_path_retained",
    "canonical_path_retained",
    "path_canonicalization_attempted",
    "path_outside_owner_manifest",
    "parent_traversal_path",
    "hidden_or_temp_path",
    "symlink_resolution_attempted",
    "file_stat_attempted",
    "file_hash_attempted",
    "model_file_opened",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_calls_made",
    "command_armed",
    "command_executed",
    "wrong_model_id",
    "wrong_filename",
    "wrong_expected_file_bytes",
    "wrong_source_revision",
    "llama_cpp_digest_claimed_without_file_gate",
    "runtime_router_mutation",
    "system_g_mutation",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "mas_l2_l3_promotion",
    "gemma_default_promotion",
    "e4b_or_12b_bypass",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-qat-e2b-owner-path-manifest-digest-gate:status
// Plane: Verification.
// Residency: digest contract only; owner manifest bytes are absent.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bOwnerPathManifestDigestGateStatus {
    DigestContractOnly,
}

// UAS: uas:gemma-qat-e2b-owner-path-manifest-digest-gate:spec
// Plane: State + Controller + Verification.
// Residency: future owner path manifest digest contract; no local path read.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bOwnerPathManifestDigestGate {
    pub upstream_review_gate_ref: String,
    pub upstream_gate_id: String,
    pub upstream_execution_probe_ref: String,
    pub artifact_root_prefix: String,
    pub digest_card_id: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub owner_approval_phrase_digest_required: bool,
    pub owner_approval_phrase_visible: String,
    pub owner_approval_granted: bool,
    pub owner_manifest_required: bool,
    pub owner_manifest_present: bool,
    pub owner_manifest_digest_required: bool,
    pub owner_manifest_bytes_read: u64,
    pub raw_path_retention_allowed: bool,
    pub raw_path_bytes_stored: u64,
    pub canonical_path_digest_required: bool,
    pub canonical_path_bytes_stored: u64,
    pub path_canonicalization_attempts: u64,
    pub path_policy_fail_closed: bool,
    pub symlink_resolution_attempts: u64,
    pub file_stat_attempts: u64,
    pub file_hash_attempts: u64,
    pub model_file_opened: bool,
    pub llama_cpp_binary_digest_deferred: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub required_manifest_digest_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub route_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub product_route_green: bool,
    pub live_gemma_default_claim: bool,
    pub e4b_or_12b_bypass_allowed: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub metadata_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaQatE2bOwnerPathManifestDigestGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bOwnerPathManifestDigestGate {
    pub fn canonical(upstream_review_gate_ref: impl Into<String>) -> Self {
        Self {
            upstream_review_gate_ref: upstream_review_gate_ref.into(),
            upstream_gate_id: GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID.to_string(),
            upstream_execution_probe_ref:
                GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            digest_card_id: DIGEST_CARD_ID.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            owner_approval_phrase_digest_required: true,
            owner_approval_phrase_visible: OWNER_APPROVAL_PHRASE.to_string(),
            owner_approval_granted: false,
            owner_manifest_required: true,
            owner_manifest_present: false,
            owner_manifest_digest_required: true,
            owner_manifest_bytes_read: 0,
            raw_path_retention_allowed: false,
            raw_path_bytes_stored: 0,
            canonical_path_digest_required: true,
            canonical_path_bytes_stored: 0,
            path_canonicalization_attempts: 0,
            path_policy_fail_closed: true,
            symlink_resolution_attempts: 0,
            file_stat_attempts: 0,
            file_hash_attempts: 0,
            model_file_opened: false,
            llama_cpp_binary_digest_deferred: true,
            command_armed: false,
            command_executed: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            required_manifest_digest_fields: REQUIRED_MANIFEST_DIGEST_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            route_mutation_allowed: false,
            system_g_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            product_route_green: false,
            live_gemma_default_claim: false,
            e4b_or_12b_bypass_allowed: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            metadata_bytes: 96_000,
            rollback_ref: "rollback:gemma_qat_e2b_owner_path_manifest_digest_gate".to_string(),
            run_event_log_ref: "run_event_log:gemma_qat_e2b_owner_path_manifest_digest_gate"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma_qat_e2b_owner_path_manifest_digest_gate"
                .to_string(),
            abstention_ref: "abstention:gemma_qat_e2b_owner_path_manifest_digest_gate".to_string(),
            status: GemmaQatE2bOwnerPathManifestDigestGateStatus::DigestContractOnly,
            next_cursor: GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bOwnerPathManifestDigestGateError> {
        if !self
            .upstream_review_gate_ref
            .starts_with(UPSTREAM_REVIEW_GATE_PREFIX)
            || self.upstream_gate_id != GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_execution_probe_ref",
            &self.upstream_execution_probe_ref,
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
        )?;
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("digest_card_id", &self.digest_card_id, DIGEST_CARD_ID)?;
        validate_unique_exact_set(
            "required_manifest_digest_fields",
            &self.required_manifest_digest_fields,
            REQUIRED_MANIFEST_DIGEST_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.source_revision != GEMMA_QAT_E2B_SOURCE_REVISION
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.expected_file_size_bytes != GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::BadSelectedArtifact);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status != GemmaQatE2bOwnerPathManifestDigestGateStatus::DigestContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::UnsafeState);
        }
        if !self.owner_approval_phrase_digest_required
            || self.owner_approval_phrase_visible != OWNER_APPROVAL_PHRASE
            || self.owner_approval_granted
            || !self.owner_manifest_required
            || self.owner_manifest_present
            || !self.owner_manifest_digest_required
            || self.owner_manifest_bytes_read != 0
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::OwnerBoundaryBroken);
        }
        if self.raw_path_retention_allowed
            || self.raw_path_bytes_stored != 0
            || !self.canonical_path_digest_required
            || self.canonical_path_bytes_stored != 0
            || self.path_canonicalization_attempts != 0
            || !self.path_policy_fail_closed
            || self.symlink_resolution_attempts != 0
            || self.file_stat_attempts != 0
            || self.file_hash_attempts != 0
            || self.model_file_opened
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::PathOrFileLeak);
        }
        if !self.llama_cpp_binary_digest_deferred
            || self.command_armed
            || self.command_executed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::ExecutionLeak);
        }
        if self.route_mutation_allowed
            || self.system_g_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.product_route_green
            || self.live_gemma_default_claim
            || self.e4b_or_12b_bypass_allowed
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::PromotionClaim);
        }
        if !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(GemmaQatE2bOwnerPathManifestDigestGateError::ProofBoundaryBroken);
        }
        validate_prefix("rollback_ref", &self.rollback_ref, "rollback:")?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            "run_event_log:",
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            "answer_packet:",
        )?;
        validate_prefix("abstention_ref", &self.abstention_ref, "abstention:")?;
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bOwnerPathManifestDigestGateMetrics {
        GemmaQatE2bOwnerPathManifestDigestGateMetrics {
            required_manifest_digest_field_count: self.required_manifest_digest_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_granted_count: self.owner_approval_granted as u64,
            owner_manifest_present_count: self.owner_manifest_present as u64,
            owner_manifest_bytes_read: self.owner_manifest_bytes_read,
            raw_path_bytes_stored: self.raw_path_bytes_stored,
            canonical_path_bytes_stored: self.canonical_path_bytes_stored,
            path_canonicalization_attempts: self.path_canonicalization_attempts,
            symlink_resolution_attempts: self.symlink_resolution_attempts,
            file_stat_attempts: self.file_stat_attempts,
            file_hash_attempts: self.file_hash_attempts,
            model_file_opened_count: self.model_file_opened as u64,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.product_route_green
                || self.live_gemma_default_claim
                || self.e4b_or_12b_bypass_allowed
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn digest_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_manifest_digest_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-owner-path-manifest-digest-gate:v1:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_review_gate_ref,
            self.selected_model_id,
            self.source_revision,
            self.required_filename,
            self.expected_file_size_bytes,
            fields.join(","),
            policies.join(","),
            self.next_cursor
        )
    }
}

// UAS: uas:gemma-qat-e2b-owner-path-manifest-digest-gate:metrics
// Plane: Verification.
// Residency: digest-contract counters and zero-byte ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bOwnerPathManifestDigestGateMetrics {
    pub required_manifest_digest_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub owner_approval_granted_count: u64,
    pub owner_manifest_present_count: u64,
    pub owner_manifest_bytes_read: u64,
    pub raw_path_bytes_stored: u64,
    pub canonical_path_bytes_stored: u64,
    pub path_canonicalization_attempts: u64,
    pub symlink_resolution_attempts: u64,
    pub file_stat_attempts: u64,
    pub file_hash_attempts: u64,
    pub model_file_opened_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_owner_path_manifest_digest_fields() -> Vec<String> {
    REQUIRED_MANIFEST_DIGEST_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_owner_path_manifest_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-owner-path-manifest-digest-gate:error
// Plane: Verification.
// Residency: fail-closed digest-contract diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bOwnerPathManifestDigestGateError {
    BadUpstreamRef,
    BadSelectedArtifact,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    OwnerBoundaryBroken,
    PathOrFileLeak,
    ExecutionLeak,
    PromotionClaim,
    ProofBoundaryBroken,
}

impl fmt::Display for GemmaQatE2bOwnerPathManifestDigestGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream review-gate reference"),
            Self::BadSelectedArtifact => f.write_str("bad selected Gemma E2B artifact"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe digest-gate state"),
            Self::OwnerBoundaryBroken => f.write_str("owner boundary broken"),
            Self::PathOrFileLeak => f.write_str("path or file leak"),
            Self::ExecutionLeak => f.write_str("execution leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
        }
    }
}

impl std::error::Error for GemmaQatE2bOwnerPathManifestDigestGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bOwnerPathManifestDigestGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bOwnerPathManifestDigestGateError::DuplicateOrMissingField(field_name),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bOwnerPathManifestDigestGateError::DuplicateOrMissingField(field_name),
        );
    }
    Ok(())
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    expected_prefix: &str,
) -> Result<(), GemmaQatE2bOwnerPathManifestDigestGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bOwnerPathManifestDigestGateError::BadField(
            field_name,
        ))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bOwnerPathManifestDigestGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bOwnerPathManifestDigestGateError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_395_000_000;

    #[test]
    fn canonical_digest_gate_validates_zero_path_and_runtime_bytes() {
        let gate = GemmaQatE2bOwnerPathManifestDigestGate::canonical(
            GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
        );
        gate.validate().unwrap();
        let metrics = gate.metrics();

        assert_eq!(metrics.required_manifest_digest_field_count, 26);
        assert_eq!(metrics.required_rejection_policy_count, 37);
        assert_eq!(
            gate.expected_file_size_bytes,
            GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
        );
        assert_eq!(metrics.owner_manifest_bytes_read, 0);
        assert_eq!(metrics.raw_path_bytes_stored, 0);
        assert_eq!(metrics.canonical_path_bytes_stored, 0);
        assert_eq!(metrics.file_hash_attempts, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.provider_calls_made, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn missing_digest_fields_are_rejected() {
        let mut gate = GemmaQatE2bOwnerPathManifestDigestGate::canonical(
            GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
        );
        gate.required_manifest_digest_fields.pop();

        assert_eq!(
            gate.validate(),
            Err(
                GemmaQatE2bOwnerPathManifestDigestGateError::DuplicateOrMissingField(
                    "required_manifest_digest_fields"
                )
            )
        );
    }

    #[test]
    fn raw_paths_file_actions_and_model_bypass_are_rejected() {
        for mutate in [
            |gate: &mut GemmaQatE2bOwnerPathManifestDigestGate| gate.raw_path_bytes_stored = 1,
            |gate: &mut GemmaQatE2bOwnerPathManifestDigestGate| {
                gate.path_canonicalization_attempts = 1
            },
            |gate: &mut GemmaQatE2bOwnerPathManifestDigestGate| gate.file_hash_attempts = 1,
            |gate: &mut GemmaQatE2bOwnerPathManifestDigestGate| gate.command_armed = true,
            |gate: &mut GemmaQatE2bOwnerPathManifestDigestGate| {
                gate.e4b_or_12b_bypass_allowed = true
            },
        ] {
            let mut gate = GemmaQatE2bOwnerPathManifestDigestGate::canonical(
                GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
            );
            mutate(&mut gate);
            assert!(gate.validate().is_err());
        }
    }

    #[test]
    fn digest_gate_address_is_order_deterministic() {
        let gate = GemmaQatE2bOwnerPathManifestDigestGate::canonical(
            GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bOwnerPathManifestDigestGate {
            required_manifest_digest_fields: gate
                .required_manifest_digest_fields
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_rejection_policies: gate
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };

        assert_eq!(
            gate.digest_gate_address(CREATED_AT_MS),
            reversed.digest_gate_address(CREATED_AT_MS)
        );
    }
}
