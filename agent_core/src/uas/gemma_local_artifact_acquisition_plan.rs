//! Gemma local artifact acquisition plan.
//!
//! This primitive turns "no local Gemma file found" into a fail-closed
//! acquisition contract. It is metadata-only: no download starts, no HF cache is
//! trusted as local proof, no model file is opened, no command is armed, no
//! server starts, and no Gemma capability is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_ID,
};

pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_ID: &str = "F-GemmaLocalArtifactAcquisitionPlan";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_CURSOR: &str =
    "gemma_local_artifact_acquisition_plan";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_first_runtime_proof_receipt_gate/result.json#F-GemmaDirectHarnessFirstRuntimeProofReceiptGate";

const UPSTREAM_RECEIPT_GATE_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_first_runtime_proof_receipt_gate/";
const ARTIFACT_ROOT_PREFIX: &str = "artifacts/falsifiers/gemma_local_artifact_acquisition_plan/";
const PLAN_ID: &str = "gemma-local-artifact-acquisition-plan-v1";
const MAX_METADATA_BYTES: u64 = 192 * 1024;
const CREATED_AT_MS: u64 = 1_779_845_000_000;

const REQUIRED_SOURCE_FIELDS: &[&str] = &[
    "model_id",
    "source_revision",
    "filename",
    "artifact_kind",
    "expected_file_size_bytes",
    "source_url",
    "etag_or_xet_hash",
    "license_or_terms_ref",
    "intended_lane",
    "pro_status",
    "sha256_pending_until_local_file",
];

const REQUIRED_PLAN_FIELDS: &[&str] = &[
    "upstream_receipt_gate_digest",
    "llama_cli_version_digest",
    "owner_approval_required",
    "allowed_acquisition_modes",
    "denied_proof_shortcuts",
    "download_or_copy_receipt_digest",
    "local_file_sha256_required_after_acquisition",
    "local_file_byte_count_required_after_acquisition",
    "owner_path_manifest_required_after_acquisition",
    "no_runtime_execution_before_receipt",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "non_promotion_digest",
];

const ALLOWED_ACQUISITION_MODES: &[&str] = &[
    "owner_provides_existing_local_file",
    "owner_approved_hf_snapshot_download_to_quarantine",
    "owner_approved_browser_download_to_quarantine",
    "owner_approved_litert_import_to_quarantine",
];

const DENIED_PROOF_SHORTCUTS: &[&str] = &[
    "llama_cli_hf_as_runtime_proof",
    "llama_server_as_product_proof",
    "hf_cache_path_as_owner_manifest",
    "model_card_as_local_file",
    "repo_revision_as_file_hash",
    "download_completion_as_runtime_proof",
    "server_endpoint_as_system_g_admission",
    "hidden_cloud_or_provider_fallback",
    "auto_default_model_selection",
    "mas_or_l2_l3_t4_promotion",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_receipt_gate",
    "missing_source_field",
    "duplicate_source_card",
    "wrong_e2b_revision",
    "wrong_e4b_revision",
    "wrong_litert_revision",
    "wrong_filename",
    "wrong_expected_file_size",
    "sha256_claimed_before_local_file",
    "owner_approval_laundered",
    "acquisition_mode_unapproved",
    "llama_cli_hf_treated_as_proof",
    "llama_server_treated_as_proof",
    "hf_cache_treated_as_manifest",
    "download_started",
    "file_opened",
    "file_hashed",
    "path_canonicalized",
    "command_armed",
    "command_executed",
    "server_started",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "runtime_router_mutation",
    "system_g_mutation",
    "settings_default_mutation",
    "hidden_authority",
    "quality_claim",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-local-artifact-acquisition-plan:source
// Plane: State + Verification.
// Residency: source-card metadata only; no artifact bytes resident.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactSourceCard {
    pub model_id: String,
    pub source_revision: String,
    pub filename: String,
    pub artifact_kind: String,
    pub expected_file_size_bytes: u64,
    pub source_url: String,
    pub etag_or_xet_hash: String,
    pub intended_lane: String,
    pub pro_status: ProStatus,
    pub sha256_pending_until_local_file: bool,
}

// UAS: uas:gemma-local-artifact-acquisition-plan:status
// Plane: Controller + Verification.
// Residency: acquisition plan only; zero download/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaLocalArtifactAcquisitionPlanStatus {
    PlanOnly,
}

// UAS: uas:gemma-local-artifact-acquisition-plan:spec
// Plane: State + Controller + Verification.
// Residency: no local artifact is claimed by this witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactAcquisitionPlan {
    pub upstream_receipt_gate_ref: String,
    pub upstream_receipt_gate_id: String,
    pub artifact_root_prefix: String,
    pub plan_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub source_cards: Vec<GemmaLocalArtifactSourceCard>,
    pub required_source_fields: Vec<String>,
    pub required_plan_fields: Vec<String>,
    pub allowed_acquisition_modes: Vec<String>,
    pub denied_proof_shortcuts: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub local_artifact_present: bool,
    pub local_artifact_sha256_present: bool,
    pub local_artifact_byte_count_verified: bool,
    pub owner_path_manifest_required_after_acquisition: bool,
    pub download_started_count: u64,
    pub bytes_downloaded: u64,
    pub file_open_count: u64,
    pub file_hash_count: u64,
    pub path_canonicalization_count: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
    pub server_started: bool,
    pub network_route_authorized_for_runtime: bool,
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
    pub status: GemmaLocalArtifactAcquisitionPlanStatus,
    pub next_cursor: String,
}

impl GemmaLocalArtifactAcquisitionPlan {
    pub fn canonical() -> Self {
        Self {
            upstream_receipt_gate_ref: GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_UPSTREAM_REF
                .to_string(),
            upstream_receipt_gate_id: GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            plan_id: PLAN_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            source_cards: canonical_source_cards(),
            required_source_fields: REQUIRED_SOURCE_FIELDS
                .iter()
                .map(|v| v.to_string())
                .collect(),
            required_plan_fields: REQUIRED_PLAN_FIELDS.iter().map(|v| v.to_string()).collect(),
            allowed_acquisition_modes: ALLOWED_ACQUISITION_MODES
                .iter()
                .map(|v| v.to_string())
                .collect(),
            denied_proof_shortcuts: DENIED_PROOF_SHORTCUTS
                .iter()
                .map(|v| v.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|v| v.to_string())
                .collect(),
            owner_approval_required: true,
            owner_approval_granted: false,
            local_artifact_present: false,
            local_artifact_sha256_present: false,
            local_artifact_byte_count_verified: false,
            owner_path_manifest_required_after_acquisition: true,
            download_started_count: 0,
            bytes_downloaded: 0,
            file_open_count: 0,
            file_hash_count: 0,
            path_canonicalization_count: 0,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
            server_started: false,
            network_route_authorized_for_runtime: false,
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
            rollback_ref: "rollback:gemma-local-artifact-acquisition-plan-v1".to_string(),
            run_event_log_ref: "run_event_log:gemma-local-artifact-acquisition-plan-v1".to_string(),
            answer_packet_ref: "answer_packet:gemma-local-artifact-acquisition-plan-v1".to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            status: GemmaLocalArtifactAcquisitionPlanStatus::PlanOnly,
            next_cursor: GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaLocalArtifactAcquisitionPlanError> {
        validate_clean("upstream_receipt_gate_ref", &self.upstream_receipt_gate_ref)?;
        validate_prefix(
            &self.upstream_receipt_gate_ref,
            UPSTREAM_RECEIPT_GATE_PREFIX,
            "upstream_receipt_gate_ref",
        )?;
        if self.upstream_receipt_gate_id != GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_ID
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadUpstreamId);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadArtifactRoot);
        }
        if self.plan_id != PLAN_ID {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadPlanId);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadBuildStatus);
        }
        validate_unique_required(
            "source_field",
            &self.required_source_fields,
            REQUIRED_SOURCE_FIELDS,
        )?;
        validate_unique_required(
            "plan_field",
            &self.required_plan_fields,
            REQUIRED_PLAN_FIELDS,
        )?;
        validate_unique_required(
            "allowed_acquisition_mode",
            &self.allowed_acquisition_modes,
            ALLOWED_ACQUISITION_MODES,
        )?;
        validate_unique_required(
            "denied_proof_shortcut",
            &self.denied_proof_shortcuts,
            DENIED_PROOF_SHORTCUTS,
        )?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        validate_source_cards(&self.source_cards)?;
        if !self.owner_approval_required || self.owner_approval_granted {
            return Err(GemmaLocalArtifactAcquisitionPlanError::OwnerApprovalBypass);
        }
        if self.local_artifact_present
            || self.local_artifact_sha256_present
            || self.local_artifact_byte_count_verified
            || !self.owner_path_manifest_required_after_acquisition
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::LocalArtifactClaim);
        }
        if self.download_started_count != 0
            || self.bytes_downloaded != 0
            || self.file_open_count != 0
            || self.file_hash_count != 0
            || self.path_canonicalization_count != 0
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::FileOrDownloadAction);
        }
        if self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.server_started
            || self.network_route_authorized_for_runtime
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaLocalArtifactAcquisitionPlanError::PromotionClaim);
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
            return Err(GemmaLocalArtifactAcquisitionPlanError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaLocalArtifactAcquisitionPlanError::MetadataTooLarge);
        }
        if self.status != GemmaLocalArtifactAcquisitionPlanStatus::PlanOnly {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadStatus);
        }
        if self.next_cursor != GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_CURSOR.to_string()),
            self.plan_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaLocalArtifactAcquisitionPlanMetrics {
        GemmaLocalArtifactAcquisitionPlanMetrics {
            source_card_count: self.source_cards.len() as u64,
            required_source_field_count: self.required_source_fields.len() as u64,
            required_plan_field_count: self.required_plan_fields.len() as u64,
            allowed_acquisition_mode_count: self.allowed_acquisition_modes.len() as u64,
            denied_proof_shortcut_count: self.denied_proof_shortcuts.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_granted_count: u64::from(self.owner_approval_granted),
            local_artifact_present_count: u64::from(self.local_artifact_present),
            download_started_count: self.download_started_count,
            bytes_downloaded: self.bytes_downloaded,
            file_open_count: self.file_open_count,
            file_hash_count: self.file_hash_count,
            path_canonicalization_count: self.path_canonicalization_count,
            command_armed_count: u64::from(self.command_armed),
            command_executed_count: u64::from(self.command_executed),
            process_spawned_count: u64::from(self.process_spawned),
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
            total_source_artifact_bytes: self
                .source_cards
                .iter()
                .map(|card| card.expected_file_size_bytes)
                .sum(),
            max_source_artifact_bytes: self
                .source_cards
                .iter()
                .map(|card| card.expected_file_size_bytes)
                .max()
                .unwrap_or(0),
            metadata_bytes: self.metadata_bytes,
        }
    }
}

// UAS: uas:gemma-local-artifact-acquisition-plan:metrics
// Plane: Verification.
// Residency: metadata counters only; zero model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaLocalArtifactAcquisitionPlanMetrics {
    pub source_card_count: u64,
    pub required_source_field_count: u64,
    pub required_plan_field_count: u64,
    pub allowed_acquisition_mode_count: u64,
    pub denied_proof_shortcut_count: u64,
    pub required_rejection_policy_count: u64,
    pub owner_approval_granted_count: u64,
    pub local_artifact_present_count: u64,
    pub download_started_count: u64,
    pub bytes_downloaded: u64,
    pub file_open_count: u64,
    pub file_hash_count: u64,
    pub path_canonicalization_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub server_started_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub total_source_artifact_bytes: u64,
    pub max_source_artifact_bytes: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-local-artifact-acquisition-plan:error
// Plane: Verification.
// Residency: validation error only; no external bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaLocalArtifactAcquisitionPlanError {
    EmptyField(&'static str),
    ControlCharacter(&'static str),
    BadPrefix(&'static str),
    MissingRequired(&'static str, &'static str),
    DuplicateValue(&'static str, String),
    DuplicateSourceCard(String),
    BadSourceCard(String),
    BadUpstreamId,
    BadArtifactRoot,
    BadPlanId,
    BadBuildStatus,
    OwnerApprovalBypass,
    LocalArtifactClaim,
    FileOrDownloadAction,
    RuntimeAction,
    RuntimeBytesLoaded,
    RouteMutation,
    HiddenAuthority,
    PromotionClaim,
    AbstentionMissing,
    MetadataTooLarge,
    BadStatus,
    BadNextCursor,
}

impl fmt::Display for GemmaLocalArtifactAcquisitionPlanError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyField(field) => write!(f, "{field} is empty"),
            Self::ControlCharacter(field) => write!(f, "{field} contains control character"),
            Self::BadPrefix(field) => write!(f, "{field} has bad prefix"),
            Self::MissingRequired(kind, value) => write!(f, "{kind} missing {value}"),
            Self::DuplicateValue(kind, value) => write!(f, "{kind} duplicate {value}"),
            Self::DuplicateSourceCard(value) => write!(f, "duplicate source card {value}"),
            Self::BadSourceCard(value) => write!(f, "bad source card {value}"),
            Self::BadUpstreamId => write!(f, "bad upstream id"),
            Self::BadArtifactRoot => write!(f, "bad artifact root"),
            Self::BadPlanId => write!(f, "bad plan id"),
            Self::BadBuildStatus => write!(f, "bad build status"),
            Self::OwnerApprovalBypass => write!(f, "owner approval bypass"),
            Self::LocalArtifactClaim => write!(f, "local artifact claimed"),
            Self::FileOrDownloadAction => write!(f, "file or download action occurred"),
            Self::RuntimeAction => write!(f, "runtime action occurred"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::RouteMutation => write!(f, "route mutation allowed"),
            Self::HiddenAuthority => write!(f, "hidden authority allowed"),
            Self::PromotionClaim => write!(f, "promotion claim present"),
            Self::AbstentionMissing => write!(f, "abstention missing"),
            Self::MetadataTooLarge => write!(f, "metadata too large"),
            Self::BadStatus => write!(f, "bad status"),
            Self::BadNextCursor => write!(f, "bad next cursor"),
        }
    }
}

impl std::error::Error for GemmaLocalArtifactAcquisitionPlanError {}

pub fn required_gemma_local_artifact_source_fields() -> &'static [&'static str] {
    REQUIRED_SOURCE_FIELDS
}

pub fn required_gemma_local_artifact_plan_fields() -> &'static [&'static str] {
    REQUIRED_PLAN_FIELDS
}

pub fn allowed_gemma_local_artifact_acquisition_modes() -> &'static [&'static str] {
    ALLOWED_ACQUISITION_MODES
}

pub fn denied_gemma_local_artifact_proof_shortcuts() -> &'static [&'static str] {
    DENIED_PROOF_SHORTCUTS
}

pub fn required_gemma_local_artifact_rejection_policies() -> &'static [&'static str] {
    REQUIRED_REJECTION_POLICIES
}

fn canonical_source_cards() -> Vec<GemmaLocalArtifactSourceCard> {
    vec![
        GemmaLocalArtifactSourceCard {
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
            source_revision: "1894d1fc0a19d86697abd40483f5983c867df03f".to_string(),
            filename: "gemma-4-E2B_q4_0-it.gguf".to_string(),
            artifact_kind: "gguf_qat_q4_0".to_string(),
            expected_file_size_bytes: 3_349_514_112,
            source_url: "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/gemma-4-E2B_q4_0-it.gguf".to_string(),
            etag_or_xet_hash:
                "x-linked-etag:3646b4c147cd235a44d91df1546d3b7d8e29b547dbe4e1f80856419aa455e6fd".to_string(),
            intended_lane: "gemma-direct-harness-llama-cpp-gguf-pro-gated".to_string(),
            pro_status: ProStatus::Gated,
            sha256_pending_until_local_file: true,
        },
        GemmaLocalArtifactSourceCard {
            model_id: "google/gemma-4-E4B-it-qat-q4_0-gguf".to_string(),
            source_revision: "bb3b92e6f031fa438b409f898dd9f14f499a0cb0".to_string(),
            filename: "gemma-4-E4B_q4_0-it.gguf".to_string(),
            artifact_kind: "gguf_qat_q4_0".to_string(),
            expected_file_size_bytes: 5_154_939_136,
            source_url: "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf".to_string(),
            etag_or_xet_hash:
                "x-linked-etag:e8b6a059ba86947a44ace84d6e5679795bc41862c25c30513142588f0e9dba1d".to_string(),
            intended_lane: "gemma-direct-harness-llama-cpp-gguf-pro-gated".to_string(),
            pro_status: ProStatus::Gated,
            sha256_pending_until_local_file: true,
        },
        GemmaLocalArtifactSourceCard {
            model_id: "litert-community/gemma-4-12B-it-litert-lm".to_string(),
            source_revision: "44cf85a326f79b814fa86a60af414c042755b43a".to_string(),
            filename: "gemma-4-12B-it.litertlm".to_string(),
            artifact_kind: "litert_lm_package".to_string(),
            expected_file_size_bytes: 6_547_589_312,
            source_url: "https://huggingface.co/litert-community/gemma-4-12B-it-litert-lm/resolve/main/gemma-4-12B-it.litertlm".to_string(),
            etag_or_xet_hash:
                "x-linked-etag:74fc29a10c20eb5b3ced6c389471a7994a0ffd657255b2a1c764262fb9054aef".to_string(),
            intended_lane: "gemma-12b-litert-lm-pro-gated".to_string(),
            pro_status: ProStatus::Gated,
            sha256_pending_until_local_file: true,
        },
    ]
}

fn validate_source_cards(
    source_cards: &[GemmaLocalArtifactSourceCard],
) -> Result<(), GemmaLocalArtifactAcquisitionPlanError> {
    if source_cards.len() != 3 {
        return Err(GemmaLocalArtifactAcquisitionPlanError::BadSourceCard(
            "expected three source cards".to_string(),
        ));
    }
    let mut ids = BTreeSet::new();
    for card in source_cards {
        validate_clean("model_id", &card.model_id)?;
        validate_clean("source_revision", &card.source_revision)?;
        validate_clean("filename", &card.filename)?;
        validate_clean("artifact_kind", &card.artifact_kind)?;
        validate_clean("source_url", &card.source_url)?;
        validate_clean("etag_or_xet_hash", &card.etag_or_xet_hash)?;
        validate_clean("intended_lane", &card.intended_lane)?;
        if !ids.insert(card.model_id.clone()) {
            return Err(GemmaLocalArtifactAcquisitionPlanError::DuplicateSourceCard(
                card.model_id.clone(),
            ));
        }
        let valid = match card.model_id.as_str() {
            "google/gemma-4-E2B-it-qat-q4_0-gguf" => {
                card.source_revision == "1894d1fc0a19d86697abd40483f5983c867df03f"
                    && card.filename == "gemma-4-E2B_q4_0-it.gguf"
                    && card.expected_file_size_bytes == 3_349_514_112
                    && card.artifact_kind == "gguf_qat_q4_0"
                    && card
                        .source_url
                        .starts_with("https://huggingface.co/google/")
            }
            "google/gemma-4-E4B-it-qat-q4_0-gguf" => {
                card.source_revision == "bb3b92e6f031fa438b409f898dd9f14f499a0cb0"
                    && card.filename == "gemma-4-E4B_q4_0-it.gguf"
                    && card.expected_file_size_bytes == 5_154_939_136
                    && card.artifact_kind == "gguf_qat_q4_0"
                    && card
                        .source_url
                        .starts_with("https://huggingface.co/google/")
            }
            "litert-community/gemma-4-12B-it-litert-lm" => {
                card.source_revision == "44cf85a326f79b814fa86a60af414c042755b43a"
                    && card.filename == "gemma-4-12B-it.litertlm"
                    && card.expected_file_size_bytes == 6_547_589_312
                    && card.artifact_kind == "litert_lm_package"
                    && card
                        .source_url
                        .starts_with("https://huggingface.co/litert-community/")
            }
            _ => false,
        };
        if !valid || !card.sha256_pending_until_local_file || card.pro_status != ProStatus::Gated {
            return Err(GemmaLocalArtifactAcquisitionPlanError::BadSourceCard(
                card.model_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaLocalArtifactAcquisitionPlanError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GemmaLocalArtifactAcquisitionPlanError::DuplicateValue(
                kind,
                value.clone(),
            ));
        }
        if !required.contains(&value.as_str()) {
            return Err(GemmaLocalArtifactAcquisitionPlanError::DuplicateValue(
                kind,
                value.clone(),
            ));
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(GemmaLocalArtifactAcquisitionPlanError::MissingRequired(
                kind,
                required_value,
            ));
        }
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), GemmaLocalArtifactAcquisitionPlanError> {
    if value.trim().is_empty() {
        return Err(GemmaLocalArtifactAcquisitionPlanError::EmptyField(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaLocalArtifactAcquisitionPlanError::ControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaLocalArtifactAcquisitionPlanError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaLocalArtifactAcquisitionPlanError::BadPrefix(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_plan_validates() {
        let plan = GemmaLocalArtifactAcquisitionPlan::canonical();
        plan.validate().expect("canonical plan should validate");
        assert_eq!(plan.metrics().source_card_count, 3);
        assert_eq!(plan.metrics().bytes_downloaded, 0);
    }

    #[test]
    fn rejects_download_or_file_action() {
        let mut plan = GemmaLocalArtifactAcquisitionPlan::canonical();
        plan.download_started_count = 1;
        assert_eq!(
            plan.validate().unwrap_err(),
            GemmaLocalArtifactAcquisitionPlanError::FileOrDownloadAction
        );
    }

    #[test]
    fn rejects_hf_cache_as_local_artifact_claim() {
        let mut plan = GemmaLocalArtifactAcquisitionPlan::canonical();
        plan.local_artifact_present = true;
        assert_eq!(
            plan.validate().unwrap_err(),
            GemmaLocalArtifactAcquisitionPlanError::LocalArtifactClaim
        );
    }

    #[test]
    fn rejects_bad_source_revision() {
        let mut plan = GemmaLocalArtifactAcquisitionPlan::canonical();
        plan.source_cards[0].source_revision = "latest".to_string();
        assert!(matches!(
            plan.validate().unwrap_err(),
            GemmaLocalArtifactAcquisitionPlanError::BadSourceCard(_)
        ));
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaLocalArtifactAcquisitionPlan::canonical().address(),
            GemmaLocalArtifactAcquisitionPlan::canonical().address()
        );
    }
}
