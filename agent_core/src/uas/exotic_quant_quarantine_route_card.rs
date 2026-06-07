//! Exotic quant quarantine route cards.
//!
//! This primitive lets ambitious compression research enter canon without
//! becoming hidden route authority. TQ3_4S, HLWQ, APEX, NVFP4, AutoRound, and
//! similar rows must remain source-carded, provenance-gated, runtime-deferred,
//! rollbackable, and AnswerPacket-visible before any downstream route can use
//! them.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogFormat, ModelCatalogRuntimeLane,
    ProStatus, ProductBuild, UasAddress, UasKind,
};

pub const EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_CURSOR: &str = "exotic_quant_quarantine_route_card";
pub const EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_NEXT_CURSOR: &str =
    "exotic_quant_source_pin_and_byte_budget_preflight";

const UPSTREAM_HARDWARE_CATALOG_PREFIX: &str =
    "artifact:falsifiers/hardware_tiered_model_catalog_source_card/result.json";
const UPSTREAM_MOE_MEMORY_TRUTH_PREFIX: &str =
    "artifact:falsifiers/moe_active_params_memory_truth/result.json";
const FALSIFIER_PREFIX: &str = "falsifier:";
const SOURCE_CARD_PREFIX: &str = "source_card:";
const PROVENANCE_PREFIX: &str = "provenance:";
const CLEAN_ROOM_PREFIX: &str = "clean_room:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPAT_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const ABSTENTION_PREFIX: &str = "abstention:";
const MAX_LEDGER_METADATA_BYTES: u64 = 768 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

const ACCEPTED_EXOTIC_MODEL_IDS: &[&str] = &[
    "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
    "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
    "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
    "nvidia/Gemma-4-31B-IT-NVFP4",
    "Intel/gemma-4-31B-it-int4-AutoRound",
];

// UAS: uas:exotic-quant-quarantine:class
// Plane: State + Controller
// Residency: why the row is quarantined before route use.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantQuarantineClass {
    TurboQuantLikeGguf,
    HlwqKvCompressed,
    ApexMoeGguf,
    Nvfp4Blackwell,
    AutoRoundServerInt4,
}

// UAS: uas:exotic-quant-quarantine:import-mode
// Plane: Verification
// Residency: how third-party code or logic may be studied without product contamination.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantImportMode {
    QuarantineReference,
    CleanRoomRewrite,
    AdapterWrapAfterApproval,
    ResearchOnly,
}

// UAS: uas:exotic-quant-quarantine:allowed-action
// Plane: Controller + Verification
// Residency: the only action allowed while the row remains T1/L1.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantAllowedAction {
    SourceCardOnly,
    ByteBudgetPreflightOnly,
    NoMacRuntime,
    ServerResearchOnly,
}

// UAS: uas:exotic-quant-quarantine:byte-scope
// Plane: Verification
// Residency: metadata-only byte accounting; all runtime/model/source bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantQuarantineByteScope {
    pub metadata_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub declared_source_card_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl ExoticQuantQuarantineByteScope {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        local_research_bytes_read: u64,
        declared_source_card_bytes: u64,
    ) -> Self {
        Self {
            metadata_bytes_read,
            local_research_bytes_read,
            declared_source_card_bytes,
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

// UAS: uas:exotic-quant-quarantine:proof-refs
// Plane: Verification
// Residency: visible proof handles required before downstream use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantQuarantineProofRefs {
    pub upstream_catalog_ref: String,
    pub upstream_moe_memory_truth_ref: String,
    pub falsifier_ref: String,
    pub source_card_ref: String,
    pub provenance_ref: String,
    pub clean_room_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_policy_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:exotic-quant-quarantine:card
// Plane: State + Controller + Verification
// Residency: source-carded row that cannot route or load bytes yet.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantQuarantineRouteCard {
    pub card_id: String,
    pub model_id: String,
    pub source_url: String,
    pub source_sha: String,
    pub hardware_tier: HardwareTier,
    pub format: ModelCatalogFormat,
    pub candidate_runtime_lane: ModelCatalogRuntimeLane,
    pub quarantine_class: ExoticQuantQuarantineClass,
    pub import_mode: ExoticQuantImportMode,
    pub allowed_action: ExoticQuantAllowedAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub provenance_gate_required: bool,
    pub clean_room_or_adapter_path_required: bool,
    pub source_card_required: bool,
    pub runtime_deferred: bool,
    pub route_authority_denied: bool,
    pub mac_default_denied: bool,
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
    pub source_tree_import_allowed: bool,
    pub benchmark_as_fit_proof: bool,
    pub runtime_lane_enabled: bool,
    pub app_headroom_claim: bool,
    pub byte_scope: ExoticQuantQuarantineByteScope,
    pub proof_refs: ExoticQuantQuarantineProofRefs,
}

// UAS: uas:exotic-quant-quarantine:ledger
// Plane: State + Controller + Verification
// Residency: metadata-only quarantine ledger for exotic compression rows.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantQuarantineRouteLedger {
    pub ledger_address: UasAddress,
    pub upstream_catalog_artifact_ref: String,
    pub upstream_moe_memory_truth_ref: String,
    pub cards: Vec<ExoticQuantQuarantineRouteCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub quarantine_before_route: bool,
    pub runtime_deferred: bool,
    pub no_hidden_authority: bool,
    pub no_mac_default_or_winner: bool,
}

// UAS: uas:exotic-quant-quarantine:metrics
// Plane: Verification
// Residency: derived counters for artifact axes and red-fixture proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantQuarantineRouteMetrics {
    pub card_count: u64,
    pub hardware_tier_count: u64,
    pub runtime_lane_count: u64,
    pub format_count: u64,
    pub quarantine_class_count: u64,
    pub import_mode_count: u64,
    pub server_only_count: u64,
    pub source_card_required_count: u64,
    pub provenance_gate_count: u64,
    pub clean_room_or_adapter_path_count: u64,
    pub route_authority_denied_count: u64,
    pub mac_default_denied_count: u64,
    pub abstention_ref_count: u64,
    pub metadata_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub declared_source_card_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl ExoticQuantQuarantineRouteLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_catalog_artifact_ref: impl Into<String>,
        upstream_moe_memory_truth_ref: impl Into<String>,
        mut cards: Vec<ExoticQuantQuarantineRouteCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        quarantine_before_route: bool,
        runtime_deferred: bool,
        no_hidden_authority: bool,
        no_mac_default_or_winner: bool,
        created_at_ms: u64,
    ) -> Result<Self, ExoticQuantQuarantineRouteError> {
        let upstream_catalog_artifact_ref = upstream_catalog_artifact_ref.into();
        let upstream_moe_memory_truth_ref = upstream_moe_memory_truth_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        validate_ledger_inputs(
            &upstream_catalog_artifact_ref,
            &upstream_moe_memory_truth_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            quarantine_before_route,
            runtime_deferred,
            no_hidden_authority,
            no_mac_default_or_winner,
        )?;
        let ledger_address = ledger_address(
            &upstream_catalog_artifact_ref,
            &upstream_moe_memory_truth_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            quarantine_before_route,
            runtime_deferred,
            no_hidden_authority,
            no_mac_default_or_winner,
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_catalog_artifact_ref,
            upstream_moe_memory_truth_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            quarantine_before_route,
            runtime_deferred,
            no_hidden_authority,
            no_mac_default_or_winner,
        })
    }

    pub fn metrics(&self) -> ExoticQuantQuarantineRouteMetrics {
        let mut hardware_tiers = BTreeSet::new();
        let mut runtime_lanes = BTreeSet::new();
        let mut formats = BTreeSet::new();
        let mut quarantine_classes = BTreeSet::new();
        let mut import_modes = BTreeSet::new();
        for card in &self.cards {
            hardware_tiers.insert(card.hardware_tier);
            runtime_lanes.insert(card.candidate_runtime_lane);
            formats.insert(card.format);
            quarantine_classes.insert(card.quarantine_class);
            import_modes.insert(card.import_mode);
        }
        ExoticQuantQuarantineRouteMetrics {
            card_count: self.cards.len() as u64,
            hardware_tier_count: hardware_tiers.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            format_count: formats.len() as u64,
            quarantine_class_count: quarantine_classes.len() as u64,
            import_mode_count: import_modes.len() as u64,
            server_only_count: self
                .cards
                .iter()
                .filter(|card| {
                    matches!(
                        card.quarantine_class,
                        ExoticQuantQuarantineClass::Nvfp4Blackwell
                            | ExoticQuantQuarantineClass::AutoRoundServerInt4
                    )
                })
                .count() as u64,
            source_card_required_count: self
                .cards
                .iter()
                .filter(|card| card.source_card_required)
                .count() as u64,
            provenance_gate_count: self
                .cards
                .iter()
                .filter(|card| card.provenance_gate_required)
                .count() as u64,
            clean_room_or_adapter_path_count: self
                .cards
                .iter()
                .filter(|card| card.clean_room_or_adapter_path_required)
                .count() as u64,
            route_authority_denied_count: self
                .cards
                .iter()
                .filter(|card| card.route_authority_denied)
                .count() as u64,
            mac_default_denied_count: self
                .cards
                .iter()
                .filter(|card| card.mac_default_denied)
                .count() as u64,
            abstention_ref_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.proof_refs
                        .abstention_ref
                        .starts_with(ABSTENTION_PREFIX)
                })
                .count() as u64,
            metadata_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.metadata_bytes_read)
                .sum(),
            local_research_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.local_research_bytes_read)
                .sum(),
            declared_source_card_bytes: self
                .cards
                .iter()
                .map(|card| card.byte_scope.declared_source_card_bytes)
                .sum(),
            model_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_scope.model_bytes_loaded)
                .sum(),
            runtime_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_scope.runtime_bytes_loaded)
                .sum(),
            provider_calls_made: self
                .cards
                .iter()
                .map(|card| card.byte_scope.provider_calls_made)
                .sum(),
            source_tree_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.source_tree_bytes_read)
                .sum(),
            product_files_copied: self
                .cards
                .iter()
                .map(|card| card.byte_scope.product_files_copied)
                .sum(),
            command_executions: self
                .cards
                .iter()
                .map(|card| card.byte_scope.command_executions)
                .sum(),
            benchmark_runs: self
                .cards
                .iter()
                .map(|card| card.byte_scope.benchmark_runs)
                .sum(),
        }
    }
}

// UAS: uas:exotic-quant-quarantine:error
// Plane: Verification
// Residency: fail-closed reason for rejecting unsafe exotic quant claims.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExoticQuantQuarantineRouteError {
    BadUpstreamCatalogRef,
    BadUpstreamMoeMemoryTruthRef,
    EmptyLedger,
    MetadataBudgetExceeded,
    MissingLayerSeparation,
    PromotionBoundaryMissing,
    DuplicateCardId(String),
    DuplicateModelId(String),
    UnknownOrNonExoticModelId(String),
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    BadSourceUrl(String),
    BadSourceSha(String),
    ProductPromotionFromResearch(String),
    MissingSourceCard(String),
    MissingProvenanceGate(String),
    MissingCleanRoomPath(String),
    RuntimeNotDeferred(String),
    RouteAuthorityEnabled(String),
    MacDefaultAllowed(String),
    ProductRouteEnabled(String),
    ProductDefaultClaim(String),
    ProductWinnerClaim(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    L2L3PromotionClaim(String),
    LiveDense70BClaim(String),
    SsdAsRamClaim(String),
    HiddenPatternBoostAuthority(String),
    HiddenLatticeAuthority(String),
    HiddenEidosAuthority(String),
    SourceTreeImportAllowed(String),
    BenchmarkAsFitProof(String),
    RuntimeLaneEnabled(String),
    AppHeadroomClaim(String),
    NonzeroModelBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    SourceTreeBytesRead(String),
    ProductFileCopied(String),
    CommandExecuted(String),
    BenchmarkRun(String),
    BadProofRefPrefix {
        field: &'static str,
        value: String,
        prefix: &'static str,
    },
    FormatClassMismatch(String),
}

impl fmt::Display for ExoticQuantQuarantineRouteError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCatalogRef => write!(f, "upstream hardware catalog ref is invalid"),
            Self::BadUpstreamMoeMemoryTruthRef => {
                write!(f, "upstream MoE memory truth ref is invalid")
            }
            Self::EmptyLedger => write!(f, "exotic quant quarantine ledger cannot be empty"),
            Self::MetadataBudgetExceeded => write!(f, "exotic quant metadata budget exceeded"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation must be explicit"),
            Self::PromotionBoundaryMissing => {
                write!(f, "promotion and quarantine boundary missing")
            }
            Self::DuplicateCardId(id) => write!(f, "duplicate exotic quant card id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate exotic quant model id `{id}`"),
            Self::UnknownOrNonExoticModelId(id) => {
                write!(f, "model `{id}` is not an accepted exotic quant row")
            }
            Self::MissingField(field) => write!(f, "field `{field}` cannot be empty"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains control characters")
            }
            Self::BadSourceUrl(id) => write!(f, "card `{id}` has invalid source URL"),
            Self::BadSourceSha(id) => write!(f, "card `{id}` has invalid source SHA"),
            Self::ProductPromotionFromResearch(id) => {
                write!(f, "card `{id}` attempted product promotion")
            }
            Self::MissingSourceCard(id) => write!(f, "card `{id}` missing source-card gate"),
            Self::MissingProvenanceGate(id) => write!(f, "card `{id}` missing provenance gate"),
            Self::MissingCleanRoomPath(id) => write!(f, "card `{id}` missing clean-room path"),
            Self::RuntimeNotDeferred(id) => write!(f, "card `{id}` does not defer runtime"),
            Self::RouteAuthorityEnabled(id) => write!(f, "card `{id}` enables route authority"),
            Self::MacDefaultAllowed(id) => write!(f, "card `{id}` allows Mac default use"),
            Self::ProductRouteEnabled(id) => write!(f, "card `{id}` enables product route"),
            Self::ProductDefaultClaim(id) => write!(f, "card `{id}` claims product default"),
            Self::ProductWinnerClaim(id) => write!(f, "card `{id}` claims product winner"),
            Self::HiddenRouteAuthority(id) => write!(f, "card `{id}` has hidden route authority"),
            Self::HiddenCloudFallback(id) => write!(f, "card `{id}` has hidden cloud fallback"),
            Self::L2L3PromotionClaim(id) => write!(f, "card `{id}` claims L2/L3 promotion"),
            Self::LiveDense70BClaim(id) => write!(f, "card `{id}` claims live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "card `{id}` claims SSD as RAM"),
            Self::HiddenPatternBoostAuthority(id) => {
                write!(f, "card `{id}` gives PatternBoost hidden live authority")
            }
            Self::HiddenLatticeAuthority(id) => {
                write!(f, "card `{id}` gives lattice hidden live authority")
            }
            Self::HiddenEidosAuthority(id) => {
                write!(f, "card `{id}` gives Eidos hidden live authority")
            }
            Self::SourceTreeImportAllowed(id) => write!(f, "card `{id}` allows source import"),
            Self::BenchmarkAsFitProof(id) => write!(f, "card `{id}` treats benchmark as fit proof"),
            Self::RuntimeLaneEnabled(id) => write!(f, "card `{id}` enables runtime lane"),
            Self::AppHeadroomClaim(id) => write!(f, "card `{id}` claims app headroom"),
            Self::NonzeroModelBytes(id) => write!(f, "card `{id}` loaded model bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "card `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "card `{id}` made provider calls"),
            Self::SourceTreeBytesRead(id) => write!(f, "card `{id}` read source-tree bytes"),
            Self::ProductFileCopied(id) => write!(f, "card `{id}` copied product files"),
            Self::CommandExecuted(id) => write!(f, "card `{id}` executed commands"),
            Self::BenchmarkRun(id) => write!(f, "card `{id}` ran benchmarks"),
            Self::BadProofRefPrefix {
                field,
                value,
                prefix,
            } => write!(
                f,
                "proof ref `{field}` value `{value}` must start with `{prefix}`"
            ),
            Self::FormatClassMismatch(id) => {
                write!(f, "card `{id}` format, class, or runtime lane mismatches")
            }
        }
    }
}

impl std::error::Error for ExoticQuantQuarantineRouteError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger_inputs(
    upstream_catalog_ref: &str,
    upstream_moe_ref: &str,
    cards: &[ExoticQuantQuarantineRouteCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    quarantine_before_route: bool,
    runtime_deferred: bool,
    no_hidden_authority: bool,
    no_mac_default_or_winner: bool,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    if !upstream_catalog_ref.starts_with(UPSTREAM_HARDWARE_CATALOG_PREFIX) {
        return Err(ExoticQuantQuarantineRouteError::BadUpstreamCatalogRef);
    }
    if !upstream_moe_ref.starts_with(UPSTREAM_MOE_MEMORY_TRUTH_PREFIX) {
        return Err(ExoticQuantQuarantineRouteError::BadUpstreamMoeMemoryTruthRef);
    }
    if cards.is_empty() {
        return Err(ExoticQuantQuarantineRouteError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(ExoticQuantQuarantineRouteError::MetadataBudgetExceeded);
    }
    if !l1_l2_l3_separated {
        return Err(ExoticQuantQuarantineRouteError::MissingLayerSeparation);
    }
    if *product_build != ProductBuild::Pro
        || *pro_status == ProStatus::Live
        || *promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        || !product_promotion_blocked
        || !quarantine_before_route
        || !runtime_deferred
        || !no_hidden_authority
        || !no_mac_default_or_winner
    {
        return Err(ExoticQuantQuarantineRouteError::PromotionBoundaryMissing);
    }

    let mut card_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    for card in cards {
        if !card_ids.insert(card.card_id.as_str()) {
            return Err(ExoticQuantQuarantineRouteError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.as_str()) {
            return Err(ExoticQuantQuarantineRouteError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        validate_card(card)?;
    }
    Ok(())
}

fn validate_card(
    card: &ExoticQuantQuarantineRouteCard,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    validate_text("card_id", &card.card_id)?;
    validate_text("model_id", &card.model_id)?;
    validate_text("source_url", &card.source_url)?;
    validate_text("source_sha", &card.source_sha)?;
    if !ACCEPTED_EXOTIC_MODEL_IDS.contains(&card.model_id.as_str()) {
        return Err(ExoticQuantQuarantineRouteError::UnknownOrNonExoticModelId(
            card.model_id.clone(),
        ));
    }
    if card.source_url != format!("https://huggingface.co/{}", card.model_id) {
        return Err(ExoticQuantQuarantineRouteError::BadSourceUrl(
            card.card_id.clone(),
        ));
    }
    if !is_lower_hex_sha(&card.source_sha) {
        return Err(ExoticQuantQuarantineRouteError::BadSourceSha(
            card.card_id.clone(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status == ProStatus::Live
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
    {
        return Err(
            ExoticQuantQuarantineRouteError::ProductPromotionFromResearch(card.card_id.clone()),
        );
    }
    validate_format_class(card)?;
    validate_quarantine(card)?;
    validate_claim_boundaries(card)?;
    validate_byte_scope(card)?;
    validate_proof_refs(card)?;
    Ok(())
}

fn validate_format_class(
    card: &ExoticQuantQuarantineRouteCard,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    let expected = match card.format {
        ModelCatalogFormat::Tq3_4s => (
            ExoticQuantQuarantineClass::TurboQuantLikeGguf,
            ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
        ),
        ModelCatalogFormat::HlwqQ5 => (
            ExoticQuantQuarantineClass::HlwqKvCompressed,
            ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
        ),
        ModelCatalogFormat::ApexGguf => (
            ExoticQuantQuarantineClass::ApexMoeGguf,
            ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
        ),
        ModelCatalogFormat::Nvfp4 => (
            ExoticQuantQuarantineClass::Nvfp4Blackwell,
            ExoticQuantAllowedAction::ServerResearchOnly,
        ),
        ModelCatalogFormat::AutoRoundInt4 => (
            ExoticQuantQuarantineClass::AutoRoundServerInt4,
            ExoticQuantAllowedAction::ServerResearchOnly,
        ),
        _ => {
            return Err(ExoticQuantQuarantineRouteError::FormatClassMismatch(
                card.card_id.clone(),
            ))
        }
    };
    if card.quarantine_class != expected.0 || card.allowed_action != expected.1 {
        return Err(ExoticQuantQuarantineRouteError::FormatClassMismatch(
            card.card_id.clone(),
        ));
    }
    if matches!(
        card.quarantine_class,
        ExoticQuantQuarantineClass::Nvfp4Blackwell
            | ExoticQuantQuarantineClass::AutoRoundServerInt4
    ) && (!card.mac_default_denied
        || !matches!(
            card.hardware_tier,
            HardwareTier::CudaBlackwellOnly | HardwareTier::ServerGpuResearch
        ))
    {
        return Err(ExoticQuantQuarantineRouteError::MacDefaultAllowed(
            card.card_id.clone(),
        ));
    }
    if card.quarantine_class == ExoticQuantQuarantineClass::ApexMoeGguf
        && card.candidate_runtime_lane != ModelCatalogRuntimeLane::NoRuntime
    {
        return Err(ExoticQuantQuarantineRouteError::FormatClassMismatch(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_quarantine(
    card: &ExoticQuantQuarantineRouteCard,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    if !card.source_card_required {
        return Err(ExoticQuantQuarantineRouteError::MissingSourceCard(
            card.card_id.clone(),
        ));
    }
    if !card.provenance_gate_required {
        return Err(ExoticQuantQuarantineRouteError::MissingProvenanceGate(
            card.card_id.clone(),
        ));
    }
    if !card.clean_room_or_adapter_path_required
        || matches!(
            card.import_mode,
            ExoticQuantImportMode::AdapterWrapAfterApproval
        )
    {
        return Err(ExoticQuantQuarantineRouteError::MissingCleanRoomPath(
            card.card_id.clone(),
        ));
    }
    if !card.runtime_deferred {
        return Err(ExoticQuantQuarantineRouteError::RuntimeNotDeferred(
            card.card_id.clone(),
        ));
    }
    if !card.route_authority_denied {
        return Err(ExoticQuantQuarantineRouteError::RouteAuthorityEnabled(
            card.card_id.clone(),
        ));
    }
    if !card.mac_default_denied {
        return Err(ExoticQuantQuarantineRouteError::MacDefaultAllowed(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_claim_boundaries(
    card: &ExoticQuantQuarantineRouteCard,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    if card.product_route_enabled {
        return Err(ExoticQuantQuarantineRouteError::ProductRouteEnabled(
            card.card_id.clone(),
        ));
    }
    if card.product_default_model_claim {
        return Err(ExoticQuantQuarantineRouteError::ProductDefaultClaim(
            card.card_id.clone(),
        ));
    }
    if card.product_winner_claim {
        return Err(ExoticQuantQuarantineRouteError::ProductWinnerClaim(
            card.card_id.clone(),
        ));
    }
    if card.hidden_route_authority {
        return Err(ExoticQuantQuarantineRouteError::HiddenRouteAuthority(
            card.card_id.clone(),
        ));
    }
    if card.hidden_cloud_fallback {
        return Err(ExoticQuantQuarantineRouteError::HiddenCloudFallback(
            card.card_id.clone(),
        ));
    }
    if card.l2_l3_promotion_claim {
        return Err(ExoticQuantQuarantineRouteError::L2L3PromotionClaim(
            card.card_id.clone(),
        ));
    }
    if card.live_dense_70b_claim {
        return Err(ExoticQuantQuarantineRouteError::LiveDense70BClaim(
            card.card_id.clone(),
        ));
    }
    if card.ssd_as_ram_claim {
        return Err(ExoticQuantQuarantineRouteError::SsdAsRamClaim(
            card.card_id.clone(),
        ));
    }
    if card.patternboost_live_authority_claim {
        return Err(
            ExoticQuantQuarantineRouteError::HiddenPatternBoostAuthority(card.card_id.clone()),
        );
    }
    if card.lattice_live_authority_claim {
        return Err(ExoticQuantQuarantineRouteError::HiddenLatticeAuthority(
            card.card_id.clone(),
        ));
    }
    if card.eidos_live_authority_claim {
        return Err(ExoticQuantQuarantineRouteError::HiddenEidosAuthority(
            card.card_id.clone(),
        ));
    }
    if card.source_tree_import_allowed {
        return Err(ExoticQuantQuarantineRouteError::SourceTreeImportAllowed(
            card.card_id.clone(),
        ));
    }
    if card.benchmark_as_fit_proof {
        return Err(ExoticQuantQuarantineRouteError::BenchmarkAsFitProof(
            card.card_id.clone(),
        ));
    }
    if card.runtime_lane_enabled {
        return Err(ExoticQuantQuarantineRouteError::RuntimeLaneEnabled(
            card.card_id.clone(),
        ));
    }
    if card.app_headroom_claim {
        return Err(ExoticQuantQuarantineRouteError::AppHeadroomClaim(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_scope(
    card: &ExoticQuantQuarantineRouteCard,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    let bytes = &card.byte_scope;
    if bytes.metadata_bytes_read == 0
        || bytes.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || bytes.local_research_bytes_read == 0
        || bytes.declared_source_card_bytes == 0
    {
        return Err(ExoticQuantQuarantineRouteError::MetadataBudgetExceeded);
    }
    if bytes.model_bytes_loaded > 0 {
        return Err(ExoticQuantQuarantineRouteError::NonzeroModelBytes(
            card.card_id.clone(),
        ));
    }
    if bytes.runtime_bytes_loaded > 0 {
        return Err(ExoticQuantQuarantineRouteError::NonzeroRuntimeBytes(
            card.card_id.clone(),
        ));
    }
    if bytes.provider_calls_made > 0 {
        return Err(ExoticQuantQuarantineRouteError::ProviderCallMade(
            card.card_id.clone(),
        ));
    }
    if bytes.source_tree_bytes_read > 0 {
        return Err(ExoticQuantQuarantineRouteError::SourceTreeBytesRead(
            card.card_id.clone(),
        ));
    }
    if bytes.product_files_copied > 0 {
        return Err(ExoticQuantQuarantineRouteError::ProductFileCopied(
            card.card_id.clone(),
        ));
    }
    if bytes.command_executions > 0 {
        return Err(ExoticQuantQuarantineRouteError::CommandExecuted(
            card.card_id.clone(),
        ));
    }
    if bytes.benchmark_runs > 0 {
        return Err(ExoticQuantQuarantineRouteError::BenchmarkRun(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    card: &ExoticQuantQuarantineRouteCard,
) -> Result<(), ExoticQuantQuarantineRouteError> {
    let proof = &card.proof_refs;
    for (field, value, prefix) in [
        (
            "upstream_catalog_ref",
            proof.upstream_catalog_ref.as_str(),
            UPSTREAM_HARDWARE_CATALOG_PREFIX,
        ),
        (
            "upstream_moe_memory_truth_ref",
            proof.upstream_moe_memory_truth_ref.as_str(),
            UPSTREAM_MOE_MEMORY_TRUTH_PREFIX,
        ),
        (
            "falsifier_ref",
            proof.falsifier_ref.as_str(),
            FALSIFIER_PREFIX,
        ),
        (
            "source_card_ref",
            proof.source_card_ref.as_str(),
            SOURCE_CARD_PREFIX,
        ),
        (
            "provenance_ref",
            proof.provenance_ref.as_str(),
            PROVENANCE_PREFIX,
        ),
        (
            "clean_room_ref",
            proof.clean_room_ref.as_str(),
            CLEAN_ROOM_PREFIX,
        ),
        ("rollback_ref", proof.rollback_ref.as_str(), ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            proof.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof.compatibility_fence_ref.as_str(),
            COMPAT_PREFIX,
        ),
        (
            "privacy_policy_ref",
            proof.privacy_policy_ref.as_str(),
            PRIVACY_PREFIX,
        ),
        (
            "abstention_ref",
            proof.abstention_ref.as_str(),
            ABSTENTION_PREFIX,
        ),
    ] {
        validate_text(field, value)?;
        if !value.starts_with(prefix) {
            return Err(ExoticQuantQuarantineRouteError::BadProofRefPrefix {
                field,
                value: value.to_string(),
                prefix,
            });
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn ledger_address(
    upstream_catalog_ref: &str,
    upstream_moe_ref: &str,
    cards: &[ExoticQuantQuarantineRouteCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    quarantine_before_route: bool,
    runtime_deferred: bool,
    no_hidden_authority: bool,
    no_mac_default_or_winner: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_CURSOR);
    preimage.push('\n');
    preimage.push_str(upstream_catalog_ref);
    preimage.push('\n');
    preimage.push_str(upstream_moe_ref);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{product_build:?}\n{pro_status:?}\n{promotion_tier:?}\n{metadata_bytes}\n"
    ));
    for flag in [
        l1_l2_l3_separated,
        product_promotion_blocked,
        quarantine_before_route,
        runtime_deferred,
        no_hidden_authority,
        no_mac_default_or_winner,
    ] {
        preimage.push_str(if flag { "true" } else { "false" });
        preimage.push('\n');
    }
    for card in cards {
        push_card_preimage(&mut preimage, card);
    }
    UasAddress::new(
        UasKind::Other(EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_card_preimage(preimage: &mut String, card: &ExoticQuantQuarantineRouteCard) {
    preimage.push_str(&card.card_id);
    preimage.push('|');
    preimage.push_str(&card.model_id);
    preimage.push('|');
    preimage.push_str(&card.source_sha);
    preimage.push('|');
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}\n",
        card.hardware_tier,
        card.format,
        card.candidate_runtime_lane,
        card.quarantine_class,
        card.import_mode,
        card.allowed_action,
        card.provenance_gate_required,
        card.clean_room_or_adapter_path_required,
        card.runtime_deferred,
        card.route_authority_denied,
        card.mac_default_denied,
        card.product_route_enabled,
        card.hidden_route_authority,
        card.byte_scope.declared_source_card_bytes,
    ));
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ExoticQuantQuarantineRouteError> {
    if value.is_empty() {
        return Err(ExoticQuantQuarantineRouteError::MissingField(field));
    }
    if value.trim() != value {
        return Err(ExoticQuantQuarantineRouteError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(ExoticQuantQuarantineRouteError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn is_lower_hex_sha(value: &str) -> bool {
    value.len() == 40
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    const CATALOG_REF: &str =
        "artifact:falsifiers/hardware_tiered_model_catalog_source_card/result.json#F-HardwareTieredModelCatalog-SourceCard";
    const MOE_REF: &str =
        "artifact:falsifiers/moe_active_params_memory_truth/result.json#F-MoEActiveParamsMemoryTruth";
    const CREATED_AT_MS: u64 = 1_779_240_000_000;

    fn build_ledger(
        cards: Vec<ExoticQuantQuarantineRouteCard>,
    ) -> Result<ExoticQuantQuarantineRouteLedger, ExoticQuantQuarantineRouteError> {
        ExoticQuantQuarantineRouteLedger::new(
            CATALOG_REF,
            MOE_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            220_000,
            true,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn fixture_cards() -> Vec<ExoticQuantQuarantineRouteCard> {
        vec![
            fixture_card(
                "qwopus27b_tq3_4s",
                "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
                "d1f4ed7d1c610cfac430c244d456af6aeac442ce",
                HardwareTier::Mac16To18Gb,
                ModelCatalogFormat::Tq3_4s,
                ModelCatalogRuntimeLane::NoRuntime,
                ExoticQuantQuarantineClass::TurboQuantLikeGguf,
                ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
            ),
            fixture_card(
                "gemma4_31b_nvfp4",
                "nvidia/Gemma-4-31B-IT-NVFP4",
                "e5ef03afa233c35cb000323ff098d4291e1dd07c",
                HardwareTier::CudaBlackwellOnly,
                ModelCatalogFormat::Nvfp4,
                ModelCatalogRuntimeLane::CudaBlackwell,
                ExoticQuantQuarantineClass::Nvfp4Blackwell,
                ExoticQuantAllowedAction::ServerResearchOnly,
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
        allowed_action: ExoticQuantAllowedAction,
    ) -> ExoticQuantQuarantineRouteCard {
        ExoticQuantQuarantineRouteCard {
            card_id: card_id.to_string(),
            model_id: model_id.to_string(),
            source_url: format!("https://huggingface.co/{model_id}"),
            source_sha: source_sha.to_string(),
            hardware_tier,
            format,
            candidate_runtime_lane,
            quarantine_class,
            import_mode: ExoticQuantImportMode::CleanRoomRewrite,
            allowed_action,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            provenance_gate_required: true,
            clean_room_or_adapter_path_required: true,
            source_card_required: true,
            runtime_deferred: true,
            route_authority_denied: true,
            mac_default_denied: true,
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
            source_tree_import_allowed: false,
            benchmark_as_fit_proof: false,
            runtime_lane_enabled: false,
            app_headroom_claim: false,
            byte_scope: ExoticQuantQuarantineByteScope::metadata_only(8_000, 4_000, 1),
            proof_refs: ExoticQuantQuarantineProofRefs {
                upstream_catalog_ref: CATALOG_REF.to_string(),
                upstream_moe_memory_truth_ref: MOE_REF.to_string(),
                falsifier_ref: "falsifier:F-ExoticQuantQuarantineRouteCard".to_string(),
                source_card_ref: "source_card:exact-hf-row-required".to_string(),
                provenance_ref: "provenance:quarantine-before-import".to_string(),
                clean_room_ref: "clean_room:motif-only-before-product-code".to_string(),
                rollback_ref: "rollback:abstain-from-exotic-quant-route".to_string(),
                run_event_log_ref: "run_event_log:exotic-quant-quarantine".to_string(),
                answer_packet_ref: "answer_packet:exotic-quant-visible-caveat".to_string(),
                compatibility_fence_ref: "compat:runtime-loader-proof-required".to_string(),
                privacy_policy_ref: "privacy:no-provider-no-hidden-route".to_string(),
                abstention_ref: "abstention:missing-exotic-quant-runtime-proof".to_string(),
            },
        }
    }

    fn reject_card(
        card_id: &str,
        mutate: impl FnOnce(&mut ExoticQuantQuarantineRouteCard),
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
        let ledger_reversed = build_ledger(reversed).expect("reversed ledger");
        assert_eq!(ledger.ledger_address, ledger_reversed.ledger_address);
        assert_eq!(ledger.metrics().card_count, 2);
    }

    #[test]
    fn rejects_empty_duplicate_and_unknown_rows() {
        assert!(build_ledger(Vec::new()).is_err());
        let mut duplicate = fixture_cards();
        duplicate.push(duplicate[0].clone());
        assert!(build_ledger(duplicate).is_err());
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
        }));
    }

    #[test]
    fn rejects_runtime_hidden_authority_and_import_claims() {
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.runtime_lane_enabled = true;
        }));
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.hidden_route_authority = true;
        }));
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.source_tree_import_allowed = true;
        }));
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.byte_scope.runtime_bytes_loaded = 1;
        }));
    }
}
