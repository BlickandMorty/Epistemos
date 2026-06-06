//! Small compressed-model model-path readiness card.
//!
//! This primitive binds the selected E2B QAT GGUF source metadata to the local
//! path state required before an owner-approved one-token probe can run.
//! It is metadata-only: no model file is downloaded, opened, hashed, loaded, or
//! used to arm a runtime command.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, SmallCompressedHarnessPromotionTier, UasAddress, UasKind,
};

pub const SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_CURSOR: &str =
    "small_compressed_model_model_path_readiness_card";
pub const SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_NEXT_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe";

const UPSTREAM_COMMAND_CARD_PREFIX: &str =
    "artifact:small_compressed_model_local_runtime_command_card:";
const SOURCE_MODEL_PREFIX: &str = "source:model:gemma4-e2b-qat-gguf:";
const MODEL_PATH_PREFIX: &str = "model_path:missing_or_unverified:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:";
const DOWNLOAD_APPROVAL_PREFIX: &str = "download_approval:pending:";
const COMMAND_CARD_PREFIX: &str = "command_card:small_compressed_local_runtime:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:small_compressed_model_path:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:small_compressed_model_path:";
const ROLLBACK_PREFIX: &str = "rollback:small_compressed_model_path:";
const CANCELLATION_PREFIX: &str = "cancel:small_compressed_model_path:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:small_compressed_model_path:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:small_compressed_model_path:";
const MAX_SET_METADATA_BYTES: u64 = 128 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 64 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const SELECTED_E2B_CANDIDATE: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const E2B_MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const REQUIRED_FILENAME: &str = "gemma-4-E2B_q4_0-it.gguf";

// UAS: uas:small-compressed-model-path-readiness:status
// Plane: Verification
// Residency: path state only; no model bytes are opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedModelPathStatus {
    MissingOrUnverified,
    PresentButUnapproved,
    ApprovedForSeparateRuntimeWitness,
}

// UAS: uas:small-compressed-model-path-readiness:byte-ledger
// Plane: Verification
// Residency: source/path metadata only; live byte counters stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelPathByteLedger {
    pub expected_model_file_bytes: u64,
    pub source_metadata_bytes_read: u64,
    pub local_path_metadata_bytes_read: u64,
    pub downloaded_model_bytes: u64,
    pub opened_model_bytes: u64,
    pub hashed_model_bytes: u64,
    pub resident_model_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl SmallCompressedModelPathByteLedger {
    pub fn missing_metadata_only(
        expected_model_file_bytes: u64,
        source_metadata_bytes_read: u64,
        local_path_metadata_bytes_read: u64,
    ) -> Self {
        Self {
            expected_model_file_bytes,
            source_metadata_bytes_read,
            local_path_metadata_bytes_read,
            downloaded_model_bytes: 0,
            opened_model_bytes: 0,
            hashed_model_bytes: 0,
            resident_model_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:small-compressed-model-path-readiness:refs
// Plane: Verification
// Residency: proof handles required before path can feed a runtime probe.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelPathRefs {
    pub upstream_command_card_ref: String,
    pub source_model_ref: String,
    pub model_path_ref: String,
    pub owner_approval_ref: String,
    pub download_approval_ref: String,
    pub command_card_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub memory_ledger_ref: String,
    pub route_caveat_ref: String,
}

// UAS: uas:small-compressed-model-path-readiness:card
// Plane: Controller + Verification
// Residency: source/path readiness only, not an approved runtime route.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelModelPathReadinessCard {
    pub card_id: String,
    pub selected_candidate_id: String,
    pub model_id: String,
    pub required_filename: String,
    pub source_revision: String,
    pub source_xet_hash: String,
    pub source_etag: String,
    pub local_path_status: SmallCompressedModelPathStatus,
    pub local_model_path: Option<String>,
    pub local_search_scopes: Vec<String>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: SmallCompressedHarnessPromotionTier,
    pub bytes: SmallCompressedModelPathByteLedger,
    pub refs: SmallCompressedModelPathRefs,
    pub user_visible_summary: String,
    pub source_metadata_visible: bool,
    pub local_path_status_visible: bool,
    pub command_card_visible: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub download_approval_required: bool,
    pub download_approval_granted: bool,
    pub download_executed: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub inference_executed: bool,
    pub first_token_claimed: bool,
    pub quality_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub cancellation_required: bool,
    pub memory_ledger_required: bool,
    pub route_policy_mutated: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub provider_fallback_allowed: bool,
    pub server_sidecar_default_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:small-compressed-model-path-readiness:set
// Plane: Controller + Verification
// Residency: model-path readiness set bound to local command-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelModelPathReadinessCardSet {
    pub set_address: UasAddress,
    pub upstream_command_card_set_address: UasAddress,
    pub upstream_command_card_witness_ref: String,
    pub selected_card_id: String,
    pub cards: Vec<SmallCompressedModelModelPathReadinessCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:small-compressed-model-path-readiness:metrics
// Plane: Verification
// Residency: derived path and byte counts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelPathMetrics {
    pub card_count: u64,
    pub missing_or_unverified_count: u64,
    pub local_path_present_count: u64,
    pub local_search_scope_count: u64,
    pub expected_model_file_bytes: u64,
    pub source_metadata_bytes_read: u64,
    pub local_path_metadata_bytes_read: u64,
    pub downloaded_model_bytes: u64,
    pub opened_model_bytes: u64,
    pub hashed_model_bytes: u64,
    pub resident_model_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl SmallCompressedModelModelPathReadinessCardSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_command_card(
        upstream_command_card_set_address: UasAddress,
        upstream_command_card_witness_ref: impl Into<String>,
        selected_card_id: impl Into<String>,
        mut cards: Vec<SmallCompressedModelModelPathReadinessCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, SmallCompressedModelPathReadinessError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let witness_ref = upstream_command_card_witness_ref.into();
        let selected_card_id = selected_card_id.into();
        validate_set_inputs(
            &upstream_command_card_set_address,
            &witness_ref,
            &selected_card_id,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = model_path_set_preimage(
            &upstream_command_card_set_address,
            &witness_ref,
            &selected_card_id,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_command_card_set_address,
            upstream_command_card_witness_ref: witness_ref,
            selected_card_id,
            cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> SmallCompressedModelPathMetrics {
        let mut metrics = SmallCompressedModelPathMetrics {
            card_count: self.cards.len() as u64,
            missing_or_unverified_count: 0,
            local_path_present_count: 0,
            local_search_scope_count: 0,
            expected_model_file_bytes: 0,
            source_metadata_bytes_read: 0,
            local_path_metadata_bytes_read: 0,
            downloaded_model_bytes: 0,
            opened_model_bytes: 0,
            hashed_model_bytes: 0,
            resident_model_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        };
        let mut scopes = HashSet::new();
        for card in &self.cards {
            if card.local_path_status == SmallCompressedModelPathStatus::MissingOrUnverified {
                metrics.missing_or_unverified_count += 1;
            }
            if card.local_model_path.is_some() {
                metrics.local_path_present_count += 1;
            }
            for scope in &card.local_search_scopes {
                scopes.insert(scope);
            }
            metrics.expected_model_file_bytes = metrics
                .expected_model_file_bytes
                .saturating_add(card.bytes.expected_model_file_bytes);
            metrics.source_metadata_bytes_read = metrics
                .source_metadata_bytes_read
                .saturating_add(card.bytes.source_metadata_bytes_read);
            metrics.local_path_metadata_bytes_read = metrics
                .local_path_metadata_bytes_read
                .saturating_add(card.bytes.local_path_metadata_bytes_read);
            metrics.downloaded_model_bytes = metrics
                .downloaded_model_bytes
                .saturating_add(card.bytes.downloaded_model_bytes);
            metrics.opened_model_bytes = metrics
                .opened_model_bytes
                .saturating_add(card.bytes.opened_model_bytes);
            metrics.hashed_model_bytes = metrics
                .hashed_model_bytes
                .saturating_add(card.bytes.hashed_model_bytes);
            metrics.resident_model_bytes = metrics
                .resident_model_bytes
                .saturating_add(card.bytes.resident_model_bytes);
            metrics.model_bytes_loaded = metrics
                .model_bytes_loaded
                .saturating_add(card.bytes.model_bytes_loaded);
            metrics.runtime_bytes_loaded = metrics
                .runtime_bytes_loaded
                .saturating_add(card.bytes.runtime_bytes_loaded);
            metrics.provider_calls_made = metrics
                .provider_calls_made
                .saturating_add(card.bytes.provider_calls_made);
        }
        metrics.local_search_scope_count = scopes.len() as u64;
        metrics
    }
}

// UAS: uas:small-compressed-model-path-readiness:error
// Plane: Verification
// Residency: validation error only; no model bytes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SmallCompressedModelPathReadinessError {
    InvalidSet(String),
    InvalidCard(String),
}

impl fmt::Display for SmallCompressedModelPathReadinessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidSet(message) => write!(f, "invalid model-path set: {message}"),
            Self::InvalidCard(message) => write!(f, "invalid model-path card: {message}"),
        }
    }
}

impl std::error::Error for SmallCompressedModelPathReadinessError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_command_card_set_address: &UasAddress,
    upstream_command_card_witness_ref: &str,
    selected_card_id: &str,
    cards: &[SmallCompressedModelModelPathReadinessCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), SmallCompressedModelPathReadinessError> {
    if upstream_command_card_set_address.to_string().is_empty() {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "upstream command-card address is empty".to_string(),
        ));
    }
    if !upstream_command_card_witness_ref.starts_with(UPSTREAM_COMMAND_CARD_PREFIX) {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "upstream command-card witness ref must bind the local command card".to_string(),
        ));
    }
    if selected_card_id.is_empty() {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "selected model-path card id is empty".to_string(),
        ));
    }
    if cards.len() != 1 {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "expected exactly one selected E2B model-path card".to_string(),
        ));
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "model-path set must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "set metadata budget is invalid".to_string(),
        ));
    }
    if !l1_l2_l3_separated || !runtime_deferred || !product_promotion_blocked {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "L1/L2/L3 separation, runtime deferral, and product block are required".to_string(),
        ));
    }
    let card = &cards[0];
    validate_card(card)?;
    if card.card_id != selected_card_id {
        return Err(SmallCompressedModelPathReadinessError::InvalidSet(
            "selected model-path card is missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_card(
    card: &SmallCompressedModelModelPathReadinessCard,
) -> Result<(), SmallCompressedModelPathReadinessError> {
    if card.card_id.trim().is_empty() {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "card id is empty".to_string(),
        ));
    }
    if card.selected_candidate_id != SELECTED_E2B_CANDIDATE
        || card.model_id != E2B_MODEL_ID
        || card.required_filename != REQUIRED_FILENAME
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "only the selected E2B QAT GGUF model file is allowed".to_string(),
        ));
    }
    if card.source_revision.len() < 40
        || card.source_xet_hash.len() < 40
        || card.source_etag.len() < 40
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "source revision, Xet hash, and ETag must be recorded".to_string(),
        ));
    }
    if card.local_path_status != SmallCompressedModelPathStatus::MissingOrUnverified
        || card.local_model_path.is_some()
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "local model path must remain missing or unverified until a separate approved witness"
                .to_string(),
        ));
    }
    if card.local_search_scopes.len() < 4
        || !card
            .local_search_scopes
            .iter()
            .any(|scope| scope.contains("/Users/jojo/Downloads"))
        || !card
            .local_search_scopes
            .iter()
            .any(|scope| scope.contains(".cache/huggingface"))
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "local search scopes must include Downloads and Hugging Face cache".to_string(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
        || card.promotion_tier != SmallCompressedHarnessPromotionTier::T1L1Metadata
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "model-path card must remain T1/L1 Pro ResearchCandidate".to_string(),
        ));
    }
    if card.bytes.expected_model_file_bytes < 3_000_000_000
        || card.bytes.source_metadata_bytes_read == 0
        || card.bytes.local_path_metadata_bytes_read == 0
        || card.bytes.source_metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.bytes.local_path_metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.bytes.downloaded_model_bytes != 0
        || card.bytes.opened_model_bytes != 0
        || card.bytes.hashed_model_bytes != 0
        || card.bytes.resident_model_bytes != 0
        || card.bytes.model_bytes_loaded != 0
        || card.bytes.runtime_bytes_loaded != 0
        || card.bytes.provider_calls_made != 0
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "model-path witness must be source/path metadata-only with zero model/runtime/provider bytes".to_string(),
        ));
    }
    if !card
        .refs
        .upstream_command_card_ref
        .starts_with(UPSTREAM_COMMAND_CARD_PREFIX)
        || !card.refs.source_model_ref.starts_with(SOURCE_MODEL_PREFIX)
        || !card.refs.model_path_ref.starts_with(MODEL_PATH_PREFIX)
        || !card
            .refs
            .owner_approval_ref
            .starts_with(OWNER_APPROVAL_PREFIX)
        || !card
            .refs
            .download_approval_ref
            .starts_with(DOWNLOAD_APPROVAL_PREFIX)
        || !card.refs.command_card_ref.starts_with(COMMAND_CARD_PREFIX)
        || !card
            .refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !card
            .refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !card.refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !card.refs.cancellation_ref.starts_with(CANCELLATION_PREFIX)
        || !card
            .refs
            .memory_ledger_ref
            .starts_with(MEMORY_LEDGER_PREFIX)
        || !card.refs.route_caveat_ref.starts_with(ROUTE_CAVEAT_PREFIX)
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "proof refs must use model-path readiness prefixes".to_string(),
        ));
    }
    if card.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
        || !card.source_metadata_visible
        || !card.local_path_status_visible
        || !card.command_card_visible
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "source metadata, local path status, and command card visibility are required"
                .to_string(),
        ));
    }
    if !card.owner_approval_required
        || card.owner_approval_granted
        || !card.download_approval_required
        || card.download_approval_granted
        || card.download_executed
        || card.command_armed
        || card.command_executed
        || card.inference_executed
        || card.first_token_claimed
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "owner/download approval must remain pending and runtime execution must remain blocked"
                .to_string(),
        ));
    }
    if !card.answer_packet_required
        || !card.run_event_log_required
        || !card.rollback_required
        || !card.cancellation_required
        || !card.memory_ledger_required
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "proof surfaces are required before any runtime probe".to_string(),
        ));
    }
    if card.quality_claimed
        || card.l2_capability_claimed
        || card.l3_wrv_claimed
        || card.mas_readiness_claimed
        || card.route_policy_mutated
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
        || card.provider_fallback_allowed
        || card.server_sidecar_default_allowed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(SmallCompressedModelPathReadinessError::InvalidCard(
            "product promotion, hidden authority, provider fallback, sidecar default, and 70B overclaim are forbidden".to_string(),
        ));
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn model_path_set_preimage(
    upstream_command_card_set_address: &UasAddress,
    upstream_command_card_witness_ref: &str,
    selected_card_id: &str,
    cards: &[SmallCompressedModelModelPathReadinessCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "{}\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_command_card_set_address,
        upstream_command_card_witness_ref,
        selected_card_id,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for card in cards {
        let fields = [
            card.card_id.clone(),
            card.selected_candidate_id.clone(),
            card.model_id.clone(),
            card.required_filename.clone(),
            card.source_revision.clone(),
            card.source_xet_hash.clone(),
            card.source_etag.clone(),
            format!("{:?}", card.local_path_status),
            card.local_model_path.clone().unwrap_or_default(),
            card.local_search_scopes.join(","),
            product_build_preimage(&card.product_build).to_string(),
            format!("{:?}", card.pro_status),
            format!("{:?}", card.promotion_tier),
            card.bytes.expected_model_file_bytes.to_string(),
            card.bytes.source_metadata_bytes_read.to_string(),
            card.bytes.local_path_metadata_bytes_read.to_string(),
            card.bytes.downloaded_model_bytes.to_string(),
            card.bytes.opened_model_bytes.to_string(),
            card.bytes.hashed_model_bytes.to_string(),
            card.bytes.resident_model_bytes.to_string(),
            card.bytes.model_bytes_loaded.to_string(),
            card.bytes.runtime_bytes_loaded.to_string(),
            card.bytes.provider_calls_made.to_string(),
            card.refs.upstream_command_card_ref.clone(),
            card.refs.source_model_ref.clone(),
            card.refs.model_path_ref.clone(),
            card.refs.owner_approval_ref.clone(),
            card.refs.download_approval_ref.clone(),
            card.refs.command_card_ref.clone(),
            card.refs.answer_packet_ref.clone(),
            card.refs.run_event_log_ref.clone(),
            card.refs.rollback_ref.clone(),
            card.refs.cancellation_ref.clone(),
            card.refs.memory_ledger_ref.clone(),
            card.refs.route_caveat_ref.clone(),
            card.source_metadata_visible.to_string(),
            card.local_path_status_visible.to_string(),
            card.command_card_visible.to_string(),
            card.owner_approval_required.to_string(),
            card.owner_approval_granted.to_string(),
            card.download_approval_required.to_string(),
            card.download_approval_granted.to_string(),
            card.download_executed.to_string(),
            card.command_armed.to_string(),
            card.command_executed.to_string(),
            card.inference_executed.to_string(),
            card.first_token_claimed.to_string(),
            card.quality_claimed.to_string(),
            card.l2_capability_claimed.to_string(),
            card.l3_wrv_claimed.to_string(),
            card.mas_readiness_claimed.to_string(),
            card.answer_packet_required.to_string(),
            card.run_event_log_required.to_string(),
            card.rollback_required.to_string(),
            card.cancellation_required.to_string(),
            card.memory_ledger_required.to_string(),
            card.route_policy_mutated.to_string(),
            card.hidden_cloud_fallback_allowed.to_string(),
            card.hidden_route_authority_allowed.to_string(),
            card.provider_fallback_allowed.to_string(),
            card.server_sidecar_default_allowed.to_string(),
            card.live_dense_70b_claimed.to_string(),
            card.ssd_as_ram_claimed.to_string(),
            card.user_visible_summary.clone(),
        ];
        preimage.push_str(&fields.join("\n"));
        preimage.push('\n');
    }
    preimage
}

fn product_build_preimage(product_build: &ProductBuild) -> &'static str {
    match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_036_800_000;
    const EXPECTED_BYTES: u64 = 3_349_514_112;
    const SOURCE_REVISION: &str = "1894d1fc0a19d86697abd40483f5983c867df03f";
    const XET_HASH: &str = "f9eedc0d3f769aa9c59341e9b230f2d6b4726cc355b1f0101b60a524a6584a30";

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("small_compressed_model_local_runtime_command_card".to_string()),
            b"small-compressed-model-path-readiness-upstream",
            CREATED_AT_MS,
        )
    }

    fn refs(id: &str) -> SmallCompressedModelPathRefs {
        SmallCompressedModelPathRefs {
            upstream_command_card_ref:
                "artifact:small_compressed_model_local_runtime_command_card:result".to_string(),
            source_model_ref: format!("source:model:gemma4-e2b-qat-gguf:{SOURCE_REVISION}"),
            model_path_ref: format!("model_path:missing_or_unverified:{id}"),
            owner_approval_ref: format!("owner_approval:pending:{id}"),
            download_approval_ref: format!("download_approval:pending:{id}"),
            command_card_ref: format!("command_card:small_compressed_local_runtime:{id}"),
            answer_packet_ref: format!("answer_packet:small_compressed_model_path:{id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_model_path:{id}"),
            rollback_ref: format!("rollback:small_compressed_model_path:{id}"),
            cancellation_ref: format!("cancel:small_compressed_model_path:{id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_model_path:{id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_model_path:{id}"),
        }
    }

    fn card() -> SmallCompressedModelModelPathReadinessCard {
        SmallCompressedModelModelPathReadinessCard {
            card_id: "gemma4_e2b_qat_gguf_model_path_readiness".to_string(),
            selected_candidate_id: SELECTED_E2B_CANDIDATE.to_string(),
            model_id: E2B_MODEL_ID.to_string(),
            required_filename: REQUIRED_FILENAME.to_string(),
            source_revision: SOURCE_REVISION.to_string(),
            source_xet_hash: XET_HASH.to_string(),
            source_etag: XET_HASH.to_string(),
            local_path_status: SmallCompressedModelPathStatus::MissingOrUnverified,
            local_model_path: None,
            local_search_scopes: vec![
                "/Users/jojo/Downloads".to_string(),
                "/Users/jojo/.cache/huggingface/hub".to_string(),
                "/Users/jojo/.cache/lm-studio".to_string(),
                "/Users/jojo/.ollama".to_string(),
            ],
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
            bytes: SmallCompressedModelPathByteLedger::missing_metadata_only(
                EXPECTED_BYTES,
                8_192,
                4_096,
            ),
            refs: refs("gemma4_e2b_qat_gguf_model_path_readiness"),
            user_visible_summary: "Gemma 4 E2B QAT GGUF source metadata is recorded, but the local model path is missing or unverified. No download, model open, hash, runtime command, provider fallback, first token, L2, or L3 claim is permitted until owner approval and a separate runtime witness exist.".to_string(),
            source_metadata_visible: true,
            local_path_status_visible: true,
            command_card_visible: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            download_approval_required: true,
            download_approval_granted: false,
            download_executed: false,
            command_armed: false,
            command_executed: false,
            inference_executed: false,
            first_token_claimed: false,
            quality_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            mas_readiness_claimed: false,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            cancellation_required: true,
            memory_ledger_required: true,
            route_policy_mutated: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            provider_fallback_allowed: false,
            server_sidecar_default_allowed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn card_set(
        cards: Vec<SmallCompressedModelModelPathReadinessCard>,
    ) -> Result<SmallCompressedModelModelPathReadinessCardSet, SmallCompressedModelPathReadinessError>
    {
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream_address(),
            "artifact:small_compressed_model_local_runtime_command_card:result",
            "gemma4_e2b_qat_gguf_model_path_readiness",
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            24_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_missing_path_readiness_card_deterministically() {
        let first = card_set(vec![card()]).expect("path readiness should validate");
        let second = card_set(vec![card()]).expect("path readiness should validate");
        assert_eq!(first.set_address, second.set_address);
        assert_eq!(first.metrics().missing_or_unverified_count, 1);
        assert_eq!(first.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_present_path_or_download_attempt() {
        let mut bad = card();
        bad.local_model_path = Some("/Users/jojo/Downloads/gemma-4-E2B_q4_0-it.gguf".to_string());
        assert!(card_set(vec![bad]).is_err());

        let mut bad = card();
        bad.download_executed = true;
        assert!(card_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_owner_approval_command_and_token_claims() {
        let mut bad = card();
        bad.owner_approval_granted = true;
        assert!(card_set(vec![bad]).is_err());

        let mut bad = card();
        bad.command_executed = true;
        assert!(card_set(vec![bad]).is_err());

        let mut bad = card();
        bad.first_token_claimed = true;
        assert!(card_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_byte_loads_and_provider_fallback() {
        let mut bad = card();
        bad.bytes.opened_model_bytes = 1;
        assert!(card_set(vec![bad]).is_err());

        let mut bad = card();
        bad.bytes.hashed_model_bytes = 1;
        assert!(card_set(vec![bad]).is_err());

        let mut bad = card();
        bad.provider_fallback_allowed = true;
        assert!(card_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_product_promotion_and_missing_refs() {
        let mut bad = card();
        bad.l2_capability_claimed = true;
        assert!(card_set(vec![bad]).is_err());

        let mut bad = card();
        bad.refs.source_model_ref = "source:model:wrong".to_string();
        assert!(card_set(vec![bad]).is_err());
    }
}
