//! Exotic quant source-pin and byte-budget preflight.
//!
//! This primitive turns quarantined exotic quant rows into exact source pins,
//! manifest digests, and byte envelopes before any runtime lane may be
//! considered. It is metadata-only: no model, runtime, source-tree, product,
//! command, provider, or benchmark bytes are loaded.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, ExoticQuantQuarantineClass, HardwareTier, ModelCatalogFormat,
    ModelCatalogRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
};

pub const EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_CURSOR: &str =
    "exotic_quant_source_pin_and_byte_budget_preflight";
pub const EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_NEXT_CURSOR: &str =
    "exotic_quant_runtime_lane_owner_approval_gate";

const UPSTREAM_QUARANTINE_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_quarantine_route_card/result.json";
const SOURCE_CARD_PREFIX: &str = "source_card:hf:";
const SOURCE_PIN_PREFIX: &str = "source_pin:hf:";
const MANIFEST_PREFIX: &str = "manifest:hf:";
const BYTE_BUDGET_PREFIX: &str = "byte_budget:exotic-quant:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPAT_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const ABSTENTION_PREFIX: &str = "abstention:";
const MAX_LEDGER_METADATA_BYTES: u64 = 768 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAC_18_GIB_BYTES: u64 = 18 * 1024 * 1024 * 1024;
const MAC_32_GIB_BYTES: u64 = 32 * 1024 * 1024 * 1024;

const ACCEPTED_MODEL_IDS: &[&str] = &[
    "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
    "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
    "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
    "nvidia/Gemma-4-31B-IT-NVFP4",
    "Intel/gemma-4-31B-it-int4-AutoRound",
];

// UAS: uas:exotic-quant-source-pin-byte-budget:mac-tier
// Plane: Controller + Verification
// Residency: preflight tier, not a runtime-fit proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantMacBudgetTier {
    Mac24To32GbCandidate,
    Mac32GbPlusCandidate,
    ServerOnlyDeniedOnMac,
}

// UAS: uas:exotic-quant-source-pin-byte-budget:admission-action
// Plane: Controller
// Residency: allowed action while this remains T1/L1.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantPreflightAction {
    ByteBudgetPreflightOnly,
    ServerResearchOnly,
}

// UAS: uas:exotic-quant-source-pin-byte-budget:byte-envelope
// Plane: Verification
// Residency: declared bytes only; loaded bytes must stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantByteBudgetEnvelope {
    pub declared_tree_file_count: u64,
    pub declared_tree_bytes: u64,
    pub source_manifest_digest: String,
    pub largest_file_path: String,
    pub largest_file_bytes: u64,
    pub largest_file_oid: String,
    pub selected_artifact_path: String,
    pub selected_artifact_bytes: u64,
    pub selected_artifact_oid: String,
    pub selected_support_bytes: u64,
    pub selected_total_bytes: u64,
    pub runtime_workspace_budget_bytes: u64,
    pub kv_cache_floor_bytes: u64,
    pub app_headroom_bytes: u64,
    pub minimum_uma_bytes_required: u64,
    pub metadata_api_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl ExoticQuantByteBudgetEnvelope {
    #[allow(clippy::too_many_arguments)]
    pub fn metadata_only(
        declared_tree_file_count: u64,
        declared_tree_bytes: u64,
        source_manifest_digest: impl Into<String>,
        largest_file_path: impl Into<String>,
        largest_file_bytes: u64,
        largest_file_oid: impl Into<String>,
        selected_artifact_path: impl Into<String>,
        selected_artifact_bytes: u64,
        selected_artifact_oid: impl Into<String>,
        selected_support_bytes: u64,
        runtime_workspace_budget_bytes: u64,
        kv_cache_floor_bytes: u64,
        app_headroom_bytes: u64,
        metadata_api_bytes_read: u64,
        local_research_bytes_read: u64,
    ) -> Self {
        let selected_total_bytes = selected_artifact_bytes + selected_support_bytes;
        Self {
            declared_tree_file_count,
            declared_tree_bytes,
            source_manifest_digest: source_manifest_digest.into(),
            largest_file_path: largest_file_path.into(),
            largest_file_bytes,
            largest_file_oid: largest_file_oid.into(),
            selected_artifact_path: selected_artifact_path.into(),
            selected_artifact_bytes,
            selected_artifact_oid: selected_artifact_oid.into(),
            selected_support_bytes,
            selected_total_bytes,
            runtime_workspace_budget_bytes,
            kv_cache_floor_bytes,
            app_headroom_bytes,
            minimum_uma_bytes_required: selected_total_bytes
                + runtime_workspace_budget_bytes
                + kv_cache_floor_bytes
                + app_headroom_bytes,
            metadata_api_bytes_read,
            local_research_bytes_read,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            source_tree_bytes_read: 0,
            product_files_copied: 0,
            command_executions: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:exotic-quant-source-pin-byte-budget:proof-refs
// Plane: Verification
// Residency: visible handles required before downstream runtime work.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantSourcePinProofRefs {
    pub upstream_quarantine_ref: String,
    pub source_card_ref: String,
    pub source_pin_ref: String,
    pub manifest_ref: String,
    pub byte_budget_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_policy_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:exotic-quant-source-pin-byte-budget:card
// Plane: State + Controller + Verification
// Residency: exact source pin and byte envelope for a quarantined row.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantSourcePinByteBudgetCard {
    pub card_id: String,
    pub model_id: String,
    pub source_url: String,
    pub source_sha: String,
    pub license_ref: String,
    pub hardware_tier: HardwareTier,
    pub format: ModelCatalogFormat,
    pub candidate_runtime_lane: ModelCatalogRuntimeLane,
    pub quarantine_class: ExoticQuantQuarantineClass,
    pub mac_budget_tier: ExoticQuantMacBudgetTier,
    pub action: ExoticQuantPreflightAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub source_pin_bound: bool,
    pub file_manifest_bound: bool,
    pub byte_budget_bound: bool,
    pub selected_artifact_not_whole_repo_claim: bool,
    pub denies_16_to_18gb_mac: bool,
    pub mac_runtime_preflight_allowed: bool,
    pub server_only_denied_on_mac: bool,
    pub runtime_deferred: bool,
    pub route_authority_denied: bool,
    pub product_route_enabled: bool,
    pub product_default_model_claim: bool,
    pub product_winner_claim: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_l3_promotion_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub patternboost_live_authority_claim: bool,
    pub lattice_live_authority_claim: bool,
    pub eidos_live_authority_claim: bool,
    pub app_headroom_claim: bool,
    pub benchmark_as_fit_proof: bool,
    pub runtime_lane_enabled: bool,
    pub envelope: ExoticQuantByteBudgetEnvelope,
    pub proof_refs: ExoticQuantSourcePinProofRefs,
}

// UAS: uas:exotic-quant-source-pin-byte-budget:ledger
// Plane: State + Controller + Verification
// Residency: deterministic preflight set for exotic quant rows.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantSourcePinByteBudgetLedger {
    pub ledger_address: UasAddress,
    pub upstream_quarantine_ref: String,
    pub cards: Vec<ExoticQuantSourcePinByteBudgetCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub runtime_deferred: bool,
    pub no_hidden_authority: bool,
}

// UAS: uas:exotic-quant-source-pin-byte-budget:metrics
// Plane: Verification
// Residency: derived counts for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantSourcePinByteBudgetMetrics {
    pub card_count: u64,
    pub mac_preflight_candidate_count: u64,
    pub server_only_count: u64,
    pub distinct_manifest_digest_count: u64,
    pub selected_artifact_count: u64,
    pub denied_16_to_18gb_mac_count: u64,
    pub declared_tree_bytes_total: u64,
    pub selected_total_bytes_sum: u64,
    pub minimum_uma_bytes_required_max: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl ExoticQuantSourcePinByteBudgetLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_quarantine_ref: impl Into<String>,
        mut cards: Vec<ExoticQuantSourcePinByteBudgetCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        runtime_deferred: bool,
        no_hidden_authority: bool,
        created_at_ms: u64,
    ) -> Result<Self, ExoticQuantSourcePinByteBudgetError> {
        let upstream_quarantine_ref = upstream_quarantine_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        validate_ledger_inputs(
            &upstream_quarantine_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            runtime_deferred,
            no_hidden_authority,
        )?;
        let ledger_address = ledger_address(
            &upstream_quarantine_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            runtime_deferred,
            no_hidden_authority,
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_quarantine_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            runtime_deferred,
            no_hidden_authority,
        })
    }

    pub fn metrics(&self) -> ExoticQuantSourcePinByteBudgetMetrics {
        let mut manifest_digests = BTreeSet::new();
        let mut max_minimum_uma = 0;
        for card in &self.cards {
            manifest_digests.insert(card.envelope.source_manifest_digest.as_str());
            max_minimum_uma = max_minimum_uma.max(card.envelope.minimum_uma_bytes_required);
        }
        ExoticQuantSourcePinByteBudgetMetrics {
            card_count: self.cards.len() as u64,
            mac_preflight_candidate_count: self
                .cards
                .iter()
                .filter(|card| card.mac_runtime_preflight_allowed)
                .count() as u64,
            server_only_count: self
                .cards
                .iter()
                .filter(|card| card.server_only_denied_on_mac)
                .count() as u64,
            distinct_manifest_digest_count: manifest_digests.len() as u64,
            selected_artifact_count: self
                .cards
                .iter()
                .filter(|card| card.envelope.selected_artifact_bytes > 0)
                .count() as u64,
            denied_16_to_18gb_mac_count: self
                .cards
                .iter()
                .filter(|card| card.denies_16_to_18gb_mac)
                .count() as u64,
            declared_tree_bytes_total: self
                .cards
                .iter()
                .map(|card| card.envelope.declared_tree_bytes)
                .sum(),
            selected_total_bytes_sum: self
                .cards
                .iter()
                .map(|card| card.envelope.selected_total_bytes)
                .sum(),
            minimum_uma_bytes_required_max: max_minimum_uma,
            model_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.envelope.model_bytes_loaded)
                .sum(),
            runtime_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.envelope.runtime_bytes_loaded)
                .sum(),
            provider_calls_made: self
                .cards
                .iter()
                .map(|card| card.envelope.provider_calls_made)
                .sum(),
            source_tree_bytes_read: self
                .cards
                .iter()
                .map(|card| card.envelope.source_tree_bytes_read)
                .sum(),
            product_files_copied: self
                .cards
                .iter()
                .map(|card| card.envelope.product_files_copied)
                .sum(),
            command_executions: self
                .cards
                .iter()
                .map(|card| card.envelope.command_executions)
                .sum(),
            benchmark_runs: self
                .cards
                .iter()
                .map(|card| card.envelope.benchmark_runs)
                .sum(),
        }
    }
}

// UAS: uas:exotic-quant-source-pin-byte-budget:error
// Plane: Verification
// Residency: fail-closed rejection reason.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExoticQuantSourcePinByteBudgetError {
    BadUpstreamQuarantineRef,
    EmptyLedger,
    MetadataBudgetExceeded,
    MissingLayerSeparation,
    PromotionBoundaryMissing,
    DuplicateCardId(String),
    DuplicateModelId(String),
    UnknownModelId(String),
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    BadSourceUrl(String),
    BadSourceSha(String),
    BadSourcePin(String),
    BadManifest(String),
    BadByteBudget(String),
    BadMacTier(String),
    ProductPromotion(String),
    RuntimeAuthority(String),
    HiddenAuthority(String),
    NonzeroBytes(String),
    BadProofRefPrefix {
        field: &'static str,
        value: String,
        prefix: &'static str,
    },
}

impl fmt::Display for ExoticQuantSourcePinByteBudgetError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamQuarantineRef => write!(f, "upstream quarantine ref is invalid"),
            Self::EmptyLedger => write!(f, "source-pin byte-budget ledger cannot be empty"),
            Self::MetadataBudgetExceeded => write!(f, "source-pin metadata budget exceeded"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation must be explicit"),
            Self::PromotionBoundaryMissing => write!(f, "promotion boundary missing"),
            Self::DuplicateCardId(id) => write!(f, "duplicate source-pin card id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate source-pin model id `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown exotic quant model `{id}`"),
            Self::MissingField(field) => write!(f, "field `{field}` cannot be empty"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains control characters")
            }
            Self::BadSourceUrl(id) => write!(f, "card `{id}` has invalid source URL"),
            Self::BadSourceSha(id) => write!(f, "card `{id}` has invalid source SHA"),
            Self::BadSourcePin(id) => write!(f, "card `{id}` has invalid source pin"),
            Self::BadManifest(id) => write!(f, "card `{id}` has invalid manifest"),
            Self::BadByteBudget(id) => write!(f, "card `{id}` has invalid byte budget"),
            Self::BadMacTier(id) => write!(f, "card `{id}` has invalid Mac tier decision"),
            Self::ProductPromotion(id) => write!(f, "card `{id}` attempted product promotion"),
            Self::RuntimeAuthority(id) => write!(f, "card `{id}` attempted runtime authority"),
            Self::HiddenAuthority(id) => write!(f, "card `{id}` attempted hidden authority"),
            Self::NonzeroBytes(id) => write!(f, "card `{id}` loaded forbidden bytes"),
            Self::BadProofRefPrefix {
                field,
                value,
                prefix,
            } => write!(
                f,
                "proof ref `{field}` value `{value}` must start with `{prefix}`"
            ),
        }
    }
}

impl std::error::Error for ExoticQuantSourcePinByteBudgetError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger_inputs(
    upstream_quarantine_ref: &str,
    cards: &[ExoticQuantSourcePinByteBudgetCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    runtime_deferred: bool,
    no_hidden_authority: bool,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    if !upstream_quarantine_ref.starts_with(UPSTREAM_QUARANTINE_PREFIX) {
        return Err(ExoticQuantSourcePinByteBudgetError::BadUpstreamQuarantineRef);
    }
    if cards.is_empty() {
        return Err(ExoticQuantSourcePinByteBudgetError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(ExoticQuantSourcePinByteBudgetError::MetadataBudgetExceeded);
    }
    if !l1_l2_l3_separated {
        return Err(ExoticQuantSourcePinByteBudgetError::MissingLayerSeparation);
    }
    if *product_build != ProductBuild::Pro
        || *pro_status == ProStatus::Live
        || *promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        || !product_promotion_blocked
        || !runtime_deferred
        || !no_hidden_authority
    {
        return Err(ExoticQuantSourcePinByteBudgetError::PromotionBoundaryMissing);
    }

    let mut card_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    for card in cards {
        if !card_ids.insert(card.card_id.as_str()) {
            return Err(ExoticQuantSourcePinByteBudgetError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.as_str()) {
            return Err(ExoticQuantSourcePinByteBudgetError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        validate_card(card)?;
    }
    Ok(())
}

fn validate_card(
    card: &ExoticQuantSourcePinByteBudgetCard,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    for (field, value) in [
        ("card_id", card.card_id.as_str()),
        ("model_id", card.model_id.as_str()),
        ("source_url", card.source_url.as_str()),
        ("source_sha", card.source_sha.as_str()),
        ("license_ref", card.license_ref.as_str()),
    ] {
        validate_text(field, value)?;
    }
    if !ACCEPTED_MODEL_IDS.contains(&card.model_id.as_str()) {
        return Err(ExoticQuantSourcePinByteBudgetError::UnknownModelId(
            card.model_id.clone(),
        ));
    }
    if card.source_url != format!("https://huggingface.co/{}", card.model_id) {
        return Err(ExoticQuantSourcePinByteBudgetError::BadSourceUrl(
            card.card_id.clone(),
        ));
    }
    if !is_lower_hex_sha(&card.source_sha) {
        return Err(ExoticQuantSourcePinByteBudgetError::BadSourceSha(
            card.card_id.clone(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status == ProStatus::Live
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
    {
        return Err(ExoticQuantSourcePinByteBudgetError::ProductPromotion(
            card.card_id.clone(),
        ));
    }
    validate_manifest_and_budget(card)?;
    validate_mac_tier(card)?;
    validate_claim_boundaries(card)?;
    validate_proof_refs(card)?;
    Ok(())
}

fn validate_manifest_and_budget(
    card: &ExoticQuantSourcePinByteBudgetCard,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    let envelope = &card.envelope;
    for (field, value) in [
        (
            "source_manifest_digest",
            envelope.source_manifest_digest.as_str(),
        ),
        ("largest_file_path", envelope.largest_file_path.as_str()),
        ("largest_file_oid", envelope.largest_file_oid.as_str()),
        (
            "selected_artifact_path",
            envelope.selected_artifact_path.as_str(),
        ),
        (
            "selected_artifact_oid",
            envelope.selected_artifact_oid.as_str(),
        ),
    ] {
        validate_text(field, value)?;
    }
    if envelope.declared_tree_file_count == 0
        || envelope.declared_tree_bytes == 0
        || envelope.largest_file_bytes == 0
        || envelope.selected_artifact_bytes == 0
        || envelope.metadata_api_bytes_read == 0
        || envelope.metadata_api_bytes_read > MAX_CARD_METADATA_BYTES
        || envelope.local_research_bytes_read == 0
        || !is_lower_hex_digest(&envelope.source_manifest_digest)
        || !is_lower_hex_sha(&envelope.largest_file_oid)
        || !is_lower_hex_sha(&envelope.selected_artifact_oid)
    {
        return Err(ExoticQuantSourcePinByteBudgetError::BadManifest(
            card.card_id.clone(),
        ));
    }
    if envelope.selected_total_bytes
        != envelope.selected_artifact_bytes + envelope.selected_support_bytes
        || envelope.minimum_uma_bytes_required
            != envelope.selected_total_bytes
                + envelope.runtime_workspace_budget_bytes
                + envelope.kv_cache_floor_bytes
                + envelope.app_headroom_bytes
        || envelope.declared_tree_bytes < envelope.selected_total_bytes
        || envelope.largest_file_bytes > envelope.declared_tree_bytes
        || !card.source_pin_bound
        || !card.file_manifest_bound
        || !card.byte_budget_bound
        || !card.selected_artifact_not_whole_repo_claim
    {
        return Err(ExoticQuantSourcePinByteBudgetError::BadByteBudget(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_mac_tier(
    card: &ExoticQuantSourcePinByteBudgetCard,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    let min_uma = card.envelope.minimum_uma_bytes_required;
    if !card.denies_16_to_18gb_mac || min_uma <= MAC_18_GIB_BYTES {
        return Err(ExoticQuantSourcePinByteBudgetError::BadMacTier(
            card.card_id.clone(),
        ));
    }
    match card.mac_budget_tier {
        ExoticQuantMacBudgetTier::Mac24To32GbCandidate
        | ExoticQuantMacBudgetTier::Mac32GbPlusCandidate => {
            if !card.mac_runtime_preflight_allowed
                || card.server_only_denied_on_mac
                || min_uma > MAC_32_GIB_BYTES
                || matches!(
                    card.hardware_tier,
                    HardwareTier::CudaBlackwellOnly | HardwareTier::ServerGpuResearch
                )
            {
                return Err(ExoticQuantSourcePinByteBudgetError::BadMacTier(
                    card.card_id.clone(),
                ));
            }
        }
        ExoticQuantMacBudgetTier::ServerOnlyDeniedOnMac => {
            if card.mac_runtime_preflight_allowed
                || !card.server_only_denied_on_mac
                || !matches!(
                    card.hardware_tier,
                    HardwareTier::CudaBlackwellOnly | HardwareTier::ServerGpuResearch
                )
            {
                return Err(ExoticQuantSourcePinByteBudgetError::BadMacTier(
                    card.card_id.clone(),
                ));
            }
        }
    }
    if matches!(card.action, ExoticQuantPreflightAction::ServerResearchOnly)
        != card.server_only_denied_on_mac
    {
        return Err(ExoticQuantSourcePinByteBudgetError::BadMacTier(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_claim_boundaries(
    card: &ExoticQuantSourcePinByteBudgetCard,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    if !card.runtime_deferred
        || !card.route_authority_denied
        || card.runtime_lane_enabled
        || card.app_headroom_claim
        || card.benchmark_as_fit_proof
    {
        return Err(ExoticQuantSourcePinByteBudgetError::RuntimeAuthority(
            card.card_id.clone(),
        ));
    }
    if card.product_route_enabled
        || card.product_default_model_claim
        || card.product_winner_claim
        || card.l2_l3_promotion_claim
        || card.live_dense_70b_claim
        || card.ssd_as_ram_claim
    {
        return Err(ExoticQuantSourcePinByteBudgetError::ProductPromotion(
            card.card_id.clone(),
        ));
    }
    if card.hidden_route_authority
        || card.hidden_cloud_fallback
        || card.patternboost_live_authority_claim
        || card.lattice_live_authority_claim
        || card.eidos_live_authority_claim
    {
        return Err(ExoticQuantSourcePinByteBudgetError::HiddenAuthority(
            card.card_id.clone(),
        ));
    }
    let envelope = &card.envelope;
    if envelope.model_bytes_loaded > 0
        || envelope.runtime_bytes_loaded > 0
        || envelope.provider_calls_made > 0
        || envelope.source_tree_bytes_read > 0
        || envelope.product_files_copied > 0
        || envelope.command_executions > 0
        || envelope.benchmark_runs > 0
    {
        return Err(ExoticQuantSourcePinByteBudgetError::NonzeroBytes(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    card: &ExoticQuantSourcePinByteBudgetCard,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    let refs = &card.proof_refs;
    for (field, value, prefix) in [
        (
            "upstream_quarantine_ref",
            refs.upstream_quarantine_ref.as_str(),
            UPSTREAM_QUARANTINE_PREFIX,
        ),
        (
            "source_card_ref",
            refs.source_card_ref.as_str(),
            SOURCE_CARD_PREFIX,
        ),
        (
            "source_pin_ref",
            refs.source_pin_ref.as_str(),
            SOURCE_PIN_PREFIX,
        ),
        ("manifest_ref", refs.manifest_ref.as_str(), MANIFEST_PREFIX),
        (
            "byte_budget_ref",
            refs.byte_budget_ref.as_str(),
            BYTE_BUDGET_PREFIX,
        ),
        ("rollback_ref", refs.rollback_ref.as_str(), ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            refs.compatibility_fence_ref.as_str(),
            COMPAT_PREFIX,
        ),
        (
            "privacy_policy_ref",
            refs.privacy_policy_ref.as_str(),
            PRIVACY_PREFIX,
        ),
        (
            "abstention_ref",
            refs.abstention_ref.as_str(),
            ABSTENTION_PREFIX,
        ),
    ] {
        validate_text(field, value)?;
        if !value.starts_with(prefix) {
            return Err(ExoticQuantSourcePinByteBudgetError::BadProofRefPrefix {
                field,
                value: value.to_string(),
                prefix,
            });
        }
    }
    if !refs.source_pin_ref.ends_with(&card.source_sha) {
        return Err(ExoticQuantSourcePinByteBudgetError::BadSourcePin(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn ledger_address(
    upstream_quarantine_ref: &str,
    cards: &[ExoticQuantSourcePinByteBudgetCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    runtime_deferred: bool,
    no_hidden_authority: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_CURSOR);
    preimage.push('\n');
    preimage.push_str(upstream_quarantine_ref);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{product_build:?}\n{pro_status:?}\n{promotion_tier:?}\n{metadata_bytes}\n"
    ));
    for flag in [
        l1_l2_l3_separated,
        product_promotion_blocked,
        runtime_deferred,
        no_hidden_authority,
    ] {
        preimage.push_str(if flag { "true" } else { "false" });
        preimage.push('\n');
    }
    for card in cards {
        preimage.push_str(&card.card_id);
        preimage.push('|');
        preimage.push_str(&card.model_id);
        preimage.push('|');
        preimage.push_str(&card.source_sha);
        preimage.push('|');
        preimage.push_str(&card.envelope.source_manifest_digest);
        preimage.push('|');
        preimage.push_str(&card.envelope.selected_artifact_path);
        preimage.push('|');
        preimage.push_str(&card.envelope.selected_total_bytes.to_string());
        preimage.push('|');
        preimage.push_str(&card.envelope.minimum_uma_bytes_required.to_string());
        preimage.push('|');
        preimage.push_str(&format!(
            "{:?}|{:?}|{:?}|{:?}|{}\n",
            card.hardware_tier,
            card.format,
            card.mac_budget_tier,
            card.action,
            card.server_only_denied_on_mac
        ));
    }
    UasAddress::new(
        UasKind::Other(EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn validate_text(
    field: &'static str,
    value: &str,
) -> Result<(), ExoticQuantSourcePinByteBudgetError> {
    if value.is_empty() {
        return Err(ExoticQuantSourcePinByteBudgetError::MissingField(field));
    }
    if value.trim() != value {
        return Err(ExoticQuantSourcePinByteBudgetError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(ExoticQuantSourcePinByteBudgetError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn is_lower_hex_sha(value: &str) -> bool {
    value.len() == 40
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

fn is_lower_hex_digest(value: &str) -> bool {
    value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str =
        "artifact:falsifiers/exotic_quant_quarantine_route_card/result.json#F-ExoticQuantQuarantineRouteCard";
    const CREATED_AT_MS: u64 = 1_779_326_400_000;

    fn build_ledger(
        cards: Vec<ExoticQuantSourcePinByteBudgetCard>,
    ) -> Result<ExoticQuantSourcePinByteBudgetLedger, ExoticQuantSourcePinByteBudgetError> {
        ExoticQuantSourcePinByteBudgetLedger::new(
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            260_000,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn fixture_cards() -> Vec<ExoticQuantSourcePinByteBudgetCard> {
        vec![
            fixture_card(
                "qwopus27b_tq3_4s",
                "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
                "d1f4ed7d1c610cfac430c244d456af6aeac442ce",
                HardwareTier::Mac16To18Gb,
                ModelCatalogFormat::Tq3_4s,
                ModelCatalogRuntimeLane::NoRuntime,
                ExoticQuantQuarantineClass::TurboQuantLikeGguf,
                ExoticQuantMacBudgetTier::Mac24To32GbCandidate,
                ExoticQuantPreflightAction::ByteBudgetPreflightOnly,
                false,
            ),
            fixture_card(
                "gemma4_31b_nvfp4",
                "nvidia/Gemma-4-31B-IT-NVFP4",
                "e5ef03afa233c35cb000323ff098d4291e1dd07c",
                HardwareTier::CudaBlackwellOnly,
                ModelCatalogFormat::Nvfp4,
                ModelCatalogRuntimeLane::CudaBlackwell,
                ExoticQuantQuarantineClass::Nvfp4Blackwell,
                ExoticQuantMacBudgetTier::ServerOnlyDeniedOnMac,
                ExoticQuantPreflightAction::ServerResearchOnly,
                true,
            ),
        ]
    }

    #[allow(clippy::too_many_arguments)]
    fn fixture_card(
        card_id: &str,
        model_id: &str,
        source_sha: &str,
        hardware_tier: HardwareTier,
        format: ModelCatalogFormat,
        candidate_runtime_lane: ModelCatalogRuntimeLane,
        quarantine_class: ExoticQuantQuarantineClass,
        mac_budget_tier: ExoticQuantMacBudgetTier,
        action: ExoticQuantPreflightAction,
        server_only: bool,
    ) -> ExoticQuantSourcePinByteBudgetCard {
        ExoticQuantSourcePinByteBudgetCard {
            card_id: card_id.to_string(),
            model_id: model_id.to_string(),
            source_url: format!("https://huggingface.co/{model_id}"),
            source_sha: source_sha.to_string(),
            license_ref: "license:metadata-only".to_string(),
            hardware_tier,
            format,
            candidate_runtime_lane,
            quarantine_class,
            mac_budget_tier,
            action,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            source_pin_bound: true,
            file_manifest_bound: true,
            byte_budget_bound: true,
            selected_artifact_not_whole_repo_claim: true,
            denies_16_to_18gb_mac: true,
            mac_runtime_preflight_allowed: !server_only,
            server_only_denied_on_mac: server_only,
            runtime_deferred: true,
            route_authority_denied: true,
            product_route_enabled: false,
            product_default_model_claim: false,
            product_winner_claim: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_l3_promotion_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            patternboost_live_authority_claim: false,
            lattice_live_authority_claim: false,
            eidos_live_authority_claim: false,
            app_headroom_claim: false,
            benchmark_as_fit_proof: false,
            runtime_lane_enabled: false,
            envelope: ExoticQuantByteBudgetEnvelope::metadata_only(
                5,
                14_886_372_874,
                "90f23e959caeb23fad3a157912cfe5a9d8dcf427d1de79314fa231dc2456e717",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                13_954_954_592,
                "18ba8c8a96b97ee397417eb87b866218fe21b642",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                13_954_954_592,
                "18ba8c8a96b97ee397417eb87b866218fe21b642",
                931_146_304,
                1_073_741_824,
                2_147_483_648,
                4_294_967_296,
                12_000,
                4_000,
            ),
            proof_refs: ExoticQuantSourcePinProofRefs {
                upstream_quarantine_ref: UPSTREAM_REF.to_string(),
                source_card_ref: format!("source_card:hf:{model_id}@{source_sha}"),
                source_pin_ref: format!("source_pin:hf:{model_id}@{source_sha}"),
                manifest_ref: format!("manifest:hf:{model_id}@{source_sha}"),
                byte_budget_ref: format!("byte_budget:exotic-quant:{card_id}"),
                rollback_ref: "rollback:abstain-from-exotic-runtime-lane".to_string(),
                run_event_log_ref: "run_event_log:exotic-quant-byte-preflight".to_string(),
                answer_packet_ref: "answer_packet:exotic-quant-byte-caveat".to_string(),
                compatibility_fence_ref: "compat:loader-and-runtime-proof-required".to_string(),
                privacy_policy_ref: "privacy:no-provider-no-hidden-route".to_string(),
                abstention_ref: "abstention:missing-owner-approved-runtime-proof".to_string(),
            },
        }
    }

    fn reject_card(
        card_id: &str,
        mutate: impl FnOnce(&mut ExoticQuantSourcePinByteBudgetCard),
    ) -> bool {
        let mut cards = fixture_cards();
        if let Some(card) = cards.iter_mut().find(|card| card.card_id == card_id) {
            mutate(card);
        }
        build_ledger(cards).is_err()
    }

    #[test]
    fn accepted_cards_produce_deterministic_address() {
        let cards = fixture_cards();
        let reversed = cards.iter().cloned().rev().collect();
        let ledger = build_ledger(cards).expect("ledger");
        let reversed = build_ledger(reversed).expect("reversed ledger");
        assert_eq!(ledger.ledger_address, reversed.ledger_address);
        assert_eq!(ledger.metrics().card_count, 2);
    }

    #[test]
    fn rejects_empty_duplicate_and_bad_manifest() {
        assert!(build_ledger(Vec::new()).is_err());
        let mut duplicate = fixture_cards();
        duplicate.push(duplicate[0].clone());
        assert!(build_ledger(duplicate).is_err());
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.envelope.source_manifest_digest = "bad".to_string();
        }));
    }

    #[test]
    fn rejects_runtime_product_and_hidden_authority() {
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.runtime_lane_enabled = true;
        }));
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.product_route_enabled = true;
        }));
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.hidden_route_authority = true;
        }));
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.envelope.model_bytes_loaded = 1;
        }));
    }
}
