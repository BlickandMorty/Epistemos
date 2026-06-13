//! Gemma local artifact acquisition command card.
//!
//! This is the metadata-only bridge between source-card acquisition planning
//! and a future owner-approved local file. It defines allowed acquisition
//! command-card shapes, but starts no download, opens no file, hashes no model,
//! arms no command, and promotes no Gemma route.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind, GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_ID,
};

pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_ID: &str =
    "F-GemmaLocalArtifactAcquisitionCommandCard";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_CURSOR: &str =
    "gemma_local_artifact_acquisition_command_card";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR: &str =
    "gemma_local_artifact_acquisition_receipt_gate";
pub const GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_local_artifact_acquisition_plan/result.json#F-GemmaLocalArtifactAcquisitionPlan";

const UPSTREAM_PREFIX: &str = "artifact:falsifiers/gemma_local_artifact_acquisition_plan/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_command_card/";
const CARD_SET_ID: &str = "gemma-local-artifact-acquisition-command-card-v1";
const QUARANTINE_ROOT: &str = ".epistemos-quarantine/gemma-local-artifacts/";
const MAX_METADATA_BYTES: u64 = 160 * 1024;
const CREATED_AT_MS: u64 = 1_779_848_000_000;

const REQUIRED_RECEIPT_FIELDS: &[&str] = &[
    "owner_approval_ref",
    "selected_model_id",
    "selected_filename",
    "source_revision",
    "expected_source_bytes",
    "local_path_digest",
    "local_file_sha256",
    "local_file_byte_count",
    "quarantine_or_owner_path_root",
    "acquisition_mode",
    "tool_version_digest",
    "network_or_manual_boundary",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "non_promotion_ref",
];

const DENIED_SHORTCUTS: &[&str] = &[
    "llama_cli_hf_as_local_file",
    "llama_server_as_acquisition",
    "hf_cache_path_without_owner_manifest",
    "repo_revision_as_file_hash",
    "etag_as_sha256",
    "download_completion_as_runtime_proof",
    "litert_serve_as_app_route",
    "raw_owner_path_in_artifact",
    "auto_default_model_after_acquisition",
    "system_g_admission_from_acquisition",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_plan",
    "missing_owner_approval",
    "missing_selected_model",
    "unknown_model",
    "wrong_filename",
    "wrong_source_revision",
    "wrong_expected_bytes",
    "duplicate_command_card",
    "raw_path_leak",
    "missing_receipt_field",
    "duplicate_receipt_field",
    "missing_denied_shortcut",
    "unapproved_acquisition_mode",
    "command_armed",
    "command_executed",
    "download_started",
    "file_opened",
    "file_hashed",
    "path_canonicalized",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "server_started",
    "provider_called",
    "route_mutated",
    "hidden_authority",
    "quality_claim",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-local-artifact-acquisition-command-card:mode
// Plane: Controller + Verification.
// Residency: command-card metadata only; no command execution.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaArtifactAcquisitionMode {
    OwnerProvidesExistingLocalFile,
    OwnerApprovedHfSnapshotDownloadToQuarantine,
    OwnerApprovedBrowserDownloadToQuarantine,
    OwnerApprovedLitertImportToQuarantine,
}

impl GemmaArtifactAcquisitionMode {
    fn as_str(self) -> &'static str {
        match self {
            Self::OwnerProvidesExistingLocalFile => "owner_provides_existing_local_file",
            Self::OwnerApprovedHfSnapshotDownloadToQuarantine => {
                "owner_approved_hf_snapshot_download_to_quarantine"
            }
            Self::OwnerApprovedBrowserDownloadToQuarantine => {
                "owner_approved_browser_download_to_quarantine"
            }
            Self::OwnerApprovedLitertImportToQuarantine => {
                "owner_approved_litert_import_to_quarantine"
            }
        }
    }
}

// UAS: uas:gemma-local-artifact-acquisition-command-card:card
// Plane: State + Controller + Verification.
// Residency: source/action metadata only; no artifact bytes resident.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaArtifactAcquisitionCommandCard {
    pub card_id: String,
    pub model_id: String,
    pub filename: String,
    pub source_revision: String,
    pub expected_file_size_bytes: u64,
    pub mode: GemmaArtifactAcquisitionMode,
    pub command_template: String,
    pub quarantine_root: String,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub download_started: bool,
    pub file_opened: bool,
    pub file_hashed: bool,
    pub path_canonicalized: bool,
    pub stores_raw_owner_path: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub server_started: bool,
    pub provider_calls_made: u64,
}

// UAS: uas:gemma-local-artifact-acquisition-command-card:set
// Plane: Controller + Verification.
// Residency: acquisition card set only; zero external bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaArtifactAcquisitionCommandCardSet {
    pub upstream_plan_ref: String,
    pub upstream_plan_id: String,
    pub artifact_root_prefix: String,
    pub card_set_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub cards: Vec<GemmaArtifactAcquisitionCommandCard>,
    pub required_receipt_fields: Vec<String>,
    pub denied_shortcuts: Vec<String>,
    pub required_rejection_policies: Vec<String>,
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

impl GemmaArtifactAcquisitionCommandCardSet {
    pub fn canonical() -> Self {
        Self {
            upstream_plan_ref: GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_UPSTREAM_REF
                .to_string(),
            upstream_plan_id: GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            card_set_id: CARD_SET_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            cards: canonical_cards(),
            required_receipt_fields: REQUIRED_RECEIPT_FIELDS
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
            rollback_ref: "rollback:gemma-local-artifact-acquisition-command-card-v1".to_string(),
            run_event_log_ref: "run_event_log:gemma-local-artifact-acquisition-command-card-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-local-artifact-acquisition-command-card-v1"
                .to_string(),
            abstention_required: true,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaArtifactAcquisitionCommandCardError> {
        validate_prefix(
            &self.upstream_plan_ref,
            UPSTREAM_PREFIX,
            "upstream_plan_ref",
        )?;
        if self.upstream_plan_id != GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_ID {
            return Err(GemmaArtifactAcquisitionCommandCardError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.card_set_id != CARD_SET_ID {
            return Err(GemmaArtifactAcquisitionCommandCardError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaArtifactAcquisitionCommandCardError::BadBuildStatus);
        }
        validate_unique_required(
            "receipt_field",
            &self.required_receipt_fields,
            REQUIRED_RECEIPT_FIELDS,
        )?;
        validate_unique_required("denied_shortcut", &self.denied_shortcuts, DENIED_SHORTCUTS)?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        validate_cards(&self.cards)?;
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaArtifactAcquisitionCommandCardError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaArtifactAcquisitionCommandCardError::HiddenAuthority);
        }
        if self.quality_claim
            || self.live_gemma_claim
            || self.l2_l3_t4_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaArtifactAcquisitionCommandCardError::PromotionClaim);
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
            return Err(GemmaArtifactAcquisitionCommandCardError::AbstentionMissing);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaArtifactAcquisitionCommandCardError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR {
            return Err(GemmaArtifactAcquisitionCommandCardError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_CURSOR.to_string()),
            self.card_set_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaArtifactAcquisitionCommandCardMetrics {
        GemmaArtifactAcquisitionCommandCardMetrics {
            command_card_count: self.cards.len() as u64,
            acquisition_mode_count: self
                .cards
                .iter()
                .map(|card| card.mode.as_str())
                .collect::<BTreeSet<_>>()
                .len() as u64,
            required_receipt_field_count: self.required_receipt_fields.len() as u64,
            denied_shortcut_count: self.denied_shortcuts.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            owner_approval_granted_count: self
                .cards
                .iter()
                .filter(|card| card.owner_approval_granted)
                .count() as u64,
            command_armed_count: self.cards.iter().filter(|card| card.command_armed).count() as u64,
            command_executed_count: self
                .cards
                .iter()
                .filter(|card| card.command_executed)
                .count() as u64,
            download_started_count: self
                .cards
                .iter()
                .filter(|card| card.download_started)
                .count() as u64,
            file_open_count: self.cards.iter().filter(|card| card.file_opened).count() as u64,
            file_hash_count: self.cards.iter().filter(|card| card.file_hashed).count() as u64,
            path_canonicalization_count: self
                .cards
                .iter()
                .filter(|card| card.path_canonicalized)
                .count() as u64,
            raw_path_storage_count: self
                .cards
                .iter()
                .filter(|card| card.stores_raw_owner_path)
                .count() as u64,
            model_bytes_loaded: self.cards.iter().map(|card| card.model_bytes_loaded).sum(),
            runtime_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.runtime_bytes_loaded)
                .sum(),
            server_started_count: self.cards.iter().filter(|card| card.server_started).count()
                as u64,
            provider_calls_made: self.cards.iter().map(|card| card.provider_calls_made).sum(),
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
            total_planned_artifact_bytes: self
                .cards
                .iter()
                .map(|card| card.expected_file_size_bytes)
                .sum(),
            metadata_bytes: self.metadata_bytes,
        }
    }
}

// UAS: uas:gemma-local-artifact-acquisition-command-card:metrics
// Plane: Verification.
// Residency: counters only; zero model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaArtifactAcquisitionCommandCardMetrics {
    pub command_card_count: u64,
    pub acquisition_mode_count: u64,
    pub required_receipt_field_count: u64,
    pub denied_shortcut_count: u64,
    pub required_rejection_policy_count: u64,
    pub owner_approval_granted_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub download_started_count: u64,
    pub file_open_count: u64,
    pub file_hash_count: u64,
    pub path_canonicalization_count: u64,
    pub raw_path_storage_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub server_started_count: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub total_planned_artifact_bytes: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-local-artifact-acquisition-command-card:error
// Plane: Verification.
// Residency: validation error only; no external bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaArtifactAcquisitionCommandCardError {
    EmptyField(&'static str),
    ControlCharacter(&'static str),
    BadPrefix(&'static str),
    MissingRequired(&'static str, &'static str),
    DuplicateValue(&'static str, String),
    BadUpstream,
    BadIdentity,
    BadBuildStatus,
    BadCard(String),
    DuplicateCard(String),
    OwnerApprovalBypass,
    ActionOccurred,
    RuntimeBytesLoaded,
    RawPathLeak,
    RouteMutation,
    HiddenAuthority,
    PromotionClaim,
    AbstentionMissing,
    MetadataTooLarge,
    BadNextCursor,
}

impl fmt::Display for GemmaArtifactAcquisitionCommandCardError {
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
            Self::BadCard(card) => write!(f, "bad command card {card}"),
            Self::DuplicateCard(card) => write!(f, "duplicate command card {card}"),
            Self::OwnerApprovalBypass => write!(f, "owner approval bypass"),
            Self::ActionOccurred => write!(f, "action occurred"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::RawPathLeak => write!(f, "raw path leak"),
            Self::RouteMutation => write!(f, "route mutation"),
            Self::HiddenAuthority => write!(f, "hidden authority"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::AbstentionMissing => write!(f, "abstention missing"),
            Self::MetadataTooLarge => write!(f, "metadata too large"),
            Self::BadNextCursor => write!(f, "bad next cursor"),
        }
    }
}

impl std::error::Error for GemmaArtifactAcquisitionCommandCardError {}

pub fn required_gemma_acquisition_command_receipt_fields() -> &'static [&'static str] {
    REQUIRED_RECEIPT_FIELDS
}

pub fn denied_gemma_acquisition_command_shortcuts() -> &'static [&'static str] {
    DENIED_SHORTCUTS
}

pub fn required_gemma_acquisition_command_rejection_policies() -> &'static [&'static str] {
    REQUIRED_REJECTION_POLICIES
}

fn canonical_cards() -> Vec<GemmaArtifactAcquisitionCommandCard> {
    vec![
        card(
            "gemma-e2b-owner-local-file",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "gemma-4-E2B_q4_0-it.gguf",
            "1894d1fc0a19d86697abd40483f5983c867df03f",
            3_349_514_112,
            GemmaArtifactAcquisitionMode::OwnerProvidesExistingLocalFile,
            "manual:owner-provides-existing-local-file; record path digest only",
        ),
        card(
            "gemma-e2b-hf-snapshot-quarantine",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "gemma-4-E2B_q4_0-it.gguf",
            "1894d1fc0a19d86697abd40483f5983c867df03f",
            3_349_514_112,
            GemmaArtifactAcquisitionMode::OwnerApprovedHfSnapshotDownloadToQuarantine,
            "hf:download-to-quarantine --repo google/gemma-4-E2B-it-qat-q4_0-gguf --revision 1894d1fc0a19d86697abd40483f5983c867df03f --include gemma-4-E2B_q4_0-it.gguf",
        ),
        card(
            "gemma-e4b-hf-snapshot-quarantine",
            "google/gemma-4-E4B-it-qat-q4_0-gguf",
            "gemma-4-E4B_q4_0-it.gguf",
            "bb3b92e6f031fa438b409f898dd9f14f499a0cb0",
            5_154_939_136,
            GemmaArtifactAcquisitionMode::OwnerApprovedHfSnapshotDownloadToQuarantine,
            "hf:download-to-quarantine --repo google/gemma-4-E4B-it-qat-q4_0-gguf --revision bb3b92e6f031fa438b409f898dd9f14f499a0cb0 --include gemma-4-E4B_q4_0-it.gguf",
        ),
        card(
            "gemma-12b-litert-import-quarantine",
            "litert-community/gemma-4-12B-it-litert-lm",
            "gemma-4-12B-it.litertlm",
            "44cf85a326f79b814fa86a60af414c042755b43a",
            6_547_589_312,
            GemmaArtifactAcquisitionMode::OwnerApprovedLitertImportToQuarantine,
            "litert-lm:import-to-quarantine --repo litert-community/gemma-4-12B-it-litert-lm --revision 44cf85a326f79b814fa86a60af414c042755b43a --file gemma-4-12B-it.litertlm",
        ),
    ]
}

fn card(
    card_id: &str,
    model_id: &str,
    filename: &str,
    source_revision: &str,
    expected_file_size_bytes: u64,
    mode: GemmaArtifactAcquisitionMode,
    command_template: &str,
) -> GemmaArtifactAcquisitionCommandCard {
    GemmaArtifactAcquisitionCommandCard {
        card_id: card_id.to_string(),
        model_id: model_id.to_string(),
        filename: filename.to_string(),
        source_revision: source_revision.to_string(),
        expected_file_size_bytes,
        mode,
        command_template: command_template.to_string(),
        quarantine_root: QUARANTINE_ROOT.to_string(),
        owner_approval_required: true,
        owner_approval_granted: false,
        command_armed: false,
        command_executed: false,
        download_started: false,
        file_opened: false,
        file_hashed: false,
        path_canonicalized: false,
        stores_raw_owner_path: false,
        model_bytes_loaded: 0,
        runtime_bytes_loaded: 0,
        server_started: false,
        provider_calls_made: 0,
    }
}

fn validate_cards(
    cards: &[GemmaArtifactAcquisitionCommandCard],
) -> Result<(), GemmaArtifactAcquisitionCommandCardError> {
    if cards.len() != 4 {
        return Err(GemmaArtifactAcquisitionCommandCardError::BadCard(
            "expected four cards".to_string(),
        ));
    }
    let mut ids = BTreeSet::new();
    let mut modes = BTreeSet::new();
    for card in cards {
        validate_clean("card_id", &card.card_id)?;
        validate_clean("model_id", &card.model_id)?;
        validate_clean("filename", &card.filename)?;
        validate_clean("source_revision", &card.source_revision)?;
        validate_clean("command_template", &card.command_template)?;
        validate_prefix(&card.quarantine_root, QUARANTINE_ROOT, "quarantine_root")?;
        if !ids.insert(card.card_id.clone()) {
            return Err(GemmaArtifactAcquisitionCommandCardError::DuplicateCard(
                card.card_id.clone(),
            ));
        }
        modes.insert(card.mode.as_str());
        if !card.owner_approval_required || card.owner_approval_granted {
            return Err(GemmaArtifactAcquisitionCommandCardError::OwnerApprovalBypass);
        }
        if card.command_armed
            || card.command_executed
            || card.download_started
            || card.file_opened
            || card.file_hashed
            || card.path_canonicalized
            || card.server_started
            || card.provider_calls_made != 0
        {
            return Err(GemmaArtifactAcquisitionCommandCardError::ActionOccurred);
        }
        if card.model_bytes_loaded != 0 || card.runtime_bytes_loaded != 0 {
            return Err(GemmaArtifactAcquisitionCommandCardError::RuntimeBytesLoaded);
        }
        if card.stores_raw_owner_path {
            return Err(GemmaArtifactAcquisitionCommandCardError::RawPathLeak);
        }
        if !card_matches_source(card) {
            return Err(GemmaArtifactAcquisitionCommandCardError::BadCard(
                card.card_id.clone(),
            ));
        }
        if card.command_template.contains("llama-server")
            || card.command_template.contains("llama-cli -hf")
            || card.command_template.contains("http://")
            || card.command_template.contains("https://")
        {
            return Err(GemmaArtifactAcquisitionCommandCardError::BadCard(
                card.card_id.clone(),
            ));
        }
    }
    if !modes.contains("owner_provides_existing_local_file")
        || !modes.contains("owner_approved_hf_snapshot_download_to_quarantine")
        || !modes.contains("owner_approved_litert_import_to_quarantine")
    {
        return Err(GemmaArtifactAcquisitionCommandCardError::BadCard(
            "missing acquisition mode".to_string(),
        ));
    }
    Ok(())
}

fn card_matches_source(card: &GemmaArtifactAcquisitionCommandCard) -> bool {
    match card.model_id.as_str() {
        "google/gemma-4-E2B-it-qat-q4_0-gguf" => {
            card.filename == "gemma-4-E2B_q4_0-it.gguf"
                && card.source_revision == "1894d1fc0a19d86697abd40483f5983c867df03f"
                && card.expected_file_size_bytes == 3_349_514_112
        }
        "google/gemma-4-E4B-it-qat-q4_0-gguf" => {
            card.filename == "gemma-4-E4B_q4_0-it.gguf"
                && card.source_revision == "bb3b92e6f031fa438b409f898dd9f14f499a0cb0"
                && card.expected_file_size_bytes == 5_154_939_136
        }
        "litert-community/gemma-4-12B-it-litert-lm" => {
            card.filename == "gemma-4-12B-it.litertlm"
                && card.source_revision == "44cf85a326f79b814fa86a60af414c042755b43a"
                && card.expected_file_size_bytes == 6_547_589_312
        }
        _ => false,
    }
}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaArtifactAcquisitionCommandCardError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GemmaArtifactAcquisitionCommandCardError::DuplicateValue(
                kind,
                value.clone(),
            ));
        }
        if !required.contains(&value.as_str()) {
            return Err(GemmaArtifactAcquisitionCommandCardError::DuplicateValue(
                kind,
                value.clone(),
            ));
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(GemmaArtifactAcquisitionCommandCardError::MissingRequired(
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
) -> Result<(), GemmaArtifactAcquisitionCommandCardError> {
    if value.trim().is_empty() {
        return Err(GemmaArtifactAcquisitionCommandCardError::EmptyField(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaArtifactAcquisitionCommandCardError::ControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaArtifactAcquisitionCommandCardError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaArtifactAcquisitionCommandCardError::BadPrefix(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_set_validates() {
        let set = GemmaArtifactAcquisitionCommandCardSet::canonical();
        set.validate().expect("canonical command-card set");
        assert_eq!(set.metrics().command_card_count, 4);
        assert_eq!(set.metrics().command_executed_count, 0);
    }

    #[test]
    fn rejects_owner_approval_bypass() {
        let mut set = GemmaArtifactAcquisitionCommandCardSet::canonical();
        set.cards[0].owner_approval_granted = true;
        assert_eq!(
            set.validate().unwrap_err(),
            GemmaArtifactAcquisitionCommandCardError::OwnerApprovalBypass
        );
    }

    #[test]
    fn rejects_raw_path_storage() {
        let mut set = GemmaArtifactAcquisitionCommandCardSet::canonical();
        set.cards[0].stores_raw_owner_path = true;
        assert_eq!(
            set.validate().unwrap_err(),
            GemmaArtifactAcquisitionCommandCardError::RawPathLeak
        );
    }

    #[test]
    fn rejects_server_template() {
        let mut set = GemmaArtifactAcquisitionCommandCardSet::canonical();
        set.cards[0].command_template = "llama-server -hf google/gemma".to_string();
        assert!(matches!(
            set.validate().unwrap_err(),
            GemmaArtifactAcquisitionCommandCardError::BadCard(_)
        ));
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaArtifactAcquisitionCommandCardSet::canonical().address(),
            GemmaArtifactAcquisitionCommandCardSet::canonical().address()
        );
    }
}
