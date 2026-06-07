//! Hardware-tiered model catalog source cards.
//!
//! This primitive folds the June 6 TurboVec/QAT and local model research into a
//! typed, metadata-only catalog. It does not load models, open weight blobs,
//! execute runtimes, select a product default, or promote L2/L3 capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{CompressedModelPromotionTier, ProStatus, ProductBuild, UasAddress, UasKind};

pub const HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_CURSOR: &str =
    "hardware_tiered_model_catalog_source_card";
pub const HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_NEXT_CURSOR: &str =
    "moe_active_params_memory_truth";

const UPSTREAM_KV_BOUNDARY_PREFIX: &str =
    "artifact:falsifiers/kv_source_card_fork_and_daemon_boundary/result.json";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPAT_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const PROVENANCE_PREFIX: &str = "provenance:";
const HARDWARE_PREFIX: &str = "hardware:";
const LOCAL_DOWNLOADS_PREFIX: &str = "local_downloads:";
const MAX_CATALOG_METADATA_BYTES: u64 = 640 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

const ACCEPTED_MODEL_IDS: &[&str] = &[
    "google/gemma-4-E2B-it-qat-q4_0-gguf",
    "google/gemma-4-12B-it-qat-q4_0-gguf",
    "Jackrong/Qwopus3.5-27B-v3-GGUF",
    "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
    "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
    "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF",
    "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
    "nvidia/Gemma-4-31B-IT-NVFP4",
    "Intel/gemma-4-31B-it-int4-AutoRound",
];

// UAS: uas:hardware-tiered-model-catalog:hardware-tier
// Plane: State + Assembly
// Residency: candidate hardware placement; not a runtime-fit proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HardwareTier {
    Mac16To18Gb,
    Mac24To32Gb,
    Mac64GbPlus,
    CudaBlackwellOnly,
    ServerGpuResearch,
    VaultColdAssemblyOnly,
}

// UAS: uas:hardware-tiered-model-catalog:role
// Plane: State + Controller
// Residency: candidate model role; not a default-model or winner claim.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelCatalogRole {
    SmallHarness,
    ProGatedFlagship,
    CodingReasoningCandidate,
    GeneralMultimodalCandidate,
    MoeAgenticCandidate,
    ExoticQuantCandidate,
    GpuServerOnly,
    ColdAssemblySeventyBClass,
}

// UAS: uas:hardware-tiered-model-catalog:format
// Plane: State + Controller
// Residency: source-carded artifact format; no artifact bytes opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelCatalogFormat {
    Gguf,
    Safetensors,
    LiteRt,
    Mlx,
    Nvfp4,
    AutoRoundInt4,
    Tq3_4s,
    HlwqQ5,
    ApexGguf,
}

// UAS: uas:hardware-tiered-model-catalog:runtime-lane
// Plane: Controller
// Residency: deferred runtime lane candidate; no execution authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelCatalogRuntimeLane {
    GgufLlamaCpp,
    LiteRtLm,
    MlxSwift,
    MlxLmPython,
    Transformers,
    VllmServer,
    CudaBlackwell,
    NoRuntime,
}

// UAS: uas:hardware-tiered-model-catalog:source-authority
// Plane: Verification
// Residency: provenance strength for catalog metadata; not product truth.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelCatalogSourceAuthority {
    CurrentHfMetadata,
    QuarantineForkMetadata,
    LocalDownloadsResearchClaim,
    ResearchOnlyExternalMetadata,
}

// UAS: uas:hardware-tiered-model-catalog:byte-scope
// Plane: Verification
// Residency: metadata-only byte accounting; loaded bytes must stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelCatalogByteScope {
    pub metadata_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub declared_artifact_bytes: Option<u64>,
    pub declared_uma_floor_bytes: Option<u64>,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl ModelCatalogByteScope {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        local_research_bytes_read: u64,
        declared_artifact_bytes: Option<u64>,
        declared_uma_floor_bytes: Option<u64>,
    ) -> Self {
        Self {
            metadata_bytes_read,
            local_research_bytes_read,
            declared_artifact_bytes,
            declared_uma_floor_bytes,
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

// UAS: uas:hardware-tiered-model-catalog:proof-refs
// Plane: Verification
// Residency: visible proof handles required before downstream route use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelCatalogProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_policy_ref: String,
    pub provenance_ref: String,
    pub hardware_tier_ref: String,
}

// UAS: uas:hardware-tiered-model-catalog:card
// Plane: State + Assembly + Controller + Verification
// Residency: source-carded hardware-tier row; never hidden route authority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HardwareTieredModelCatalogCard {
    pub card_id: String,
    pub model_id: String,
    pub source_url: String,
    pub source_sha: String,
    pub license_ref: String,
    pub local_research_ref: Option<String>,
    pub hardware_tier: HardwareTier,
    pub role: ModelCatalogRole,
    pub format: ModelCatalogFormat,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub source_authority: ModelCatalogSourceAuthority,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub loader_caveat_ref: Option<String>,
    pub headroom_caveat_ref: Option<String>,
    pub kv_caveat_ref: Option<String>,
    pub active_params_truth_required: bool,
    pub exotic_quant_provenance_required: bool,
    pub gpu_only: bool,
    pub mac_default_denied: bool,
    pub local_research_claim_only: bool,
    pub source_card_required: bool,
    pub runtime_deferred: bool,
    pub product_route_enabled: bool,
    pub product_default_model_claim: bool,
    pub product_winner_claim: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_l3_promotion_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub byte_scope: ModelCatalogByteScope,
    pub proof_refs: ModelCatalogProofRefs,
}

// UAS: uas:hardware-tiered-model-catalog:catalog
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only model catalog for future gated runtime proofs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HardwareTieredModelCatalog {
    pub catalog_address: UasAddress,
    pub upstream_kv_boundary_ref: String,
    pub cards: Vec<HardwareTieredModelCatalogCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub route_authority_blocked: bool,
    pub runtime_deferred: bool,
    pub source_card_required: bool,
    pub local_research_claims_quarantined: bool,
    pub no_default_model_or_winner: bool,
}

// UAS: uas:hardware-tiered-model-catalog:metrics
// Plane: Verification
// Residency: derived counters for artifact axes and red-fixture proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HardwareTieredModelCatalogMetrics {
    pub card_count: u64,
    pub hardware_tier_count: u64,
    pub runtime_lane_count: u64,
    pub format_count: u64,
    pub role_count: u64,
    pub mac_candidate_count: u64,
    pub gpu_only_count: u64,
    pub exotic_quant_count: u64,
    pub moe_truth_required_count: u64,
    pub local_research_claim_count: u64,
    pub headroom_caveat_count: u64,
    pub source_card_required_count: u64,
    pub runtime_deferred_count: u64,
    pub declared_artifact_bytes_total: u64,
    pub declared_uma_floor_bytes_total: u64,
    pub metadata_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl HardwareTieredModelCatalog {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_kv_boundary_ref: impl Into<String>,
        mut cards: Vec<HardwareTieredModelCatalogCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        route_authority_blocked: bool,
        runtime_deferred: bool,
        source_card_required: bool,
        local_research_claims_quarantined: bool,
        no_default_model_or_winner: bool,
        created_at_ms: u64,
    ) -> Result<Self, HardwareTieredModelCatalogError> {
        let upstream_kv_boundary_ref = upstream_kv_boundary_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        validate_catalog_inputs(
            &upstream_kv_boundary_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            route_authority_blocked,
            runtime_deferred,
            source_card_required,
            local_research_claims_quarantined,
            no_default_model_or_winner,
        )?;
        let catalog_address = catalog_address(
            &upstream_kv_boundary_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            route_authority_blocked,
            runtime_deferred,
            source_card_required,
            local_research_claims_quarantined,
            no_default_model_or_winner,
            created_at_ms,
        );
        Ok(Self {
            catalog_address,
            upstream_kv_boundary_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_promotion_blocked,
            route_authority_blocked,
            runtime_deferred,
            source_card_required,
            local_research_claims_quarantined,
            no_default_model_or_winner,
        })
    }

    pub fn metrics(&self) -> HardwareTieredModelCatalogMetrics {
        let mut hardware_tiers = BTreeSet::new();
        let mut runtime_lanes = BTreeSet::new();
        let mut formats = BTreeSet::new();
        let mut roles = BTreeSet::new();
        for card in &self.cards {
            hardware_tiers.insert(card.hardware_tier);
            runtime_lanes.insert(card.runtime_lane);
            formats.insert(card.format);
            roles.insert(card.role);
        }
        HardwareTieredModelCatalogMetrics {
            card_count: self.cards.len() as u64,
            hardware_tier_count: hardware_tiers.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            format_count: formats.len() as u64,
            role_count: roles.len() as u64,
            mac_candidate_count: self
                .cards
                .iter()
                .filter(|card| {
                    matches!(
                        card.hardware_tier,
                        HardwareTier::Mac16To18Gb
                            | HardwareTier::Mac24To32Gb
                            | HardwareTier::Mac64GbPlus
                    )
                })
                .count() as u64,
            gpu_only_count: self.cards.iter().filter(|card| card.gpu_only).count() as u64,
            exotic_quant_count: self
                .cards
                .iter()
                .filter(|card| card.exotic_quant_provenance_required)
                .count() as u64,
            moe_truth_required_count: self
                .cards
                .iter()
                .filter(|card| card.active_params_truth_required)
                .count() as u64,
            local_research_claim_count: self
                .cards
                .iter()
                .filter(|card| card.local_research_claim_only)
                .count() as u64,
            headroom_caveat_count: self
                .cards
                .iter()
                .filter(|card| card.headroom_caveat_ref.is_some())
                .count() as u64,
            source_card_required_count: self
                .cards
                .iter()
                .filter(|card| card.source_card_required)
                .count() as u64,
            runtime_deferred_count: self
                .cards
                .iter()
                .filter(|card| card.runtime_deferred)
                .count() as u64,
            declared_artifact_bytes_total: self
                .cards
                .iter()
                .filter_map(|card| card.byte_scope.declared_artifact_bytes)
                .sum(),
            declared_uma_floor_bytes_total: self
                .cards
                .iter()
                .filter_map(|card| card.byte_scope.declared_uma_floor_bytes)
                .sum(),
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

    pub fn address(&self) -> String {
        self.catalog_address.to_string()
    }
}

// UAS: uas:hardware-tiered-model-catalog:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy for catalog overclaims.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HardwareTieredModelCatalogError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    BadUpstreamArtifactRef,
    EmptyCatalog,
    DuplicateCardId(String),
    DuplicateModelId(String),
    UnknownModelId(String),
    ProductPromotionFromResearch(String),
    MissingLayerSeparation,
    MissingSourceCardRequirement(String),
    BadHfSource(String),
    BadSourceSha(String),
    MissingLocalResearchQuarantine(String),
    BadProofRefPrefix {
        card_id: String,
        field: &'static str,
    },
    SmallHarnessOverclaim(String),
    MacTierOverclaim(String),
    GpuOnlyNotDeniedOnMac(String),
    ExoticQuantWithoutGate(String),
    MoeWithoutActiveParamsTruth(String),
    ProductDefaultClaim(String),
    ProductWinnerClaim(String),
    ProductRouteEnabled(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    L2L3PromotionClaim(String),
    LiveDense70BClaim(String),
    SsdAsRamClaim(String),
    NonzeroModelBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    SourceTreeBytesRead(String),
    ProductFileCopied(String),
    CommandExecuted(String),
    BenchmarkRun(String),
    MetadataBudgetExceeded,
}

impl fmt::Display for HardwareTieredModelCatalogError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::BadUpstreamArtifactRef => write!(f, "bad upstream KV boundary artifact ref"),
            Self::EmptyCatalog => write!(f, "model catalog is empty"),
            Self::DuplicateCardId(id) => write!(f, "duplicate catalog card id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate catalog model id `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown model id `{id}`"),
            Self::ProductPromotionFromResearch(id) => {
                write!(f, "card `{id}` promoted research to product")
            }
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 catalog boundary flags"),
            Self::MissingSourceCardRequirement(id) => {
                write!(f, "card `{id}` is missing source-card requirement")
            }
            Self::BadHfSource(id) => write!(f, "card `{id}` has bad Hugging Face source"),
            Self::BadSourceSha(id) => write!(f, "card `{id}` has bad source sha"),
            Self::MissingLocalResearchQuarantine(id) => {
                write!(f, "card `{id}` failed to quarantine local research claims")
            }
            Self::BadProofRefPrefix { card_id, field } => {
                write!(f, "card `{card_id}` has bad proof ref `{field}`")
            }
            Self::SmallHarnessOverclaim(id) => write!(f, "card `{id}` overclaimed small harness"),
            Self::MacTierOverclaim(id) => write!(f, "card `{id}` overclaimed Mac hardware fit"),
            Self::GpuOnlyNotDeniedOnMac(id) => {
                write!(f, "card `{id}` failed to deny GPU-only Mac default")
            }
            Self::ExoticQuantWithoutGate(id) => {
                write!(f, "card `{id}` missing exotic quant provenance gate")
            }
            Self::MoeWithoutActiveParamsTruth(id) => {
                write!(f, "card `{id}` missing MoE active-params truth gate")
            }
            Self::ProductDefaultClaim(id) => write!(f, "card `{id}` claimed product default"),
            Self::ProductWinnerClaim(id) => write!(f, "card `{id}` claimed product winner"),
            Self::ProductRouteEnabled(id) => write!(f, "card `{id}` enabled product route"),
            Self::HiddenRouteAuthority(id) => write!(f, "card `{id}` hid route authority"),
            Self::HiddenCloudFallback(id) => write!(f, "card `{id}` hid cloud fallback"),
            Self::L2L3PromotionClaim(id) => write!(f, "card `{id}` claimed L2/L3 promotion"),
            Self::LiveDense70BClaim(id) => write!(f, "card `{id}` claimed live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "card `{id}` claimed SSD as RAM"),
            Self::NonzeroModelBytes(id) => write!(f, "card `{id}` loaded model bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "card `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "card `{id}` made provider calls"),
            Self::SourceTreeBytesRead(id) => write!(f, "card `{id}` read source tree bytes"),
            Self::ProductFileCopied(id) => write!(f, "card `{id}` copied product files"),
            Self::CommandExecuted(id) => write!(f, "card `{id}` executed commands"),
            Self::BenchmarkRun(id) => write!(f, "card `{id}` ran benchmarks"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for HardwareTieredModelCatalogError {}

#[allow(clippy::too_many_arguments)]
fn validate_catalog_inputs(
    upstream_ref: &str,
    cards: &[HardwareTieredModelCatalogCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    route_authority_blocked: bool,
    runtime_deferred: bool,
    source_card_required: bool,
    local_research_claims_quarantined: bool,
    no_default_model_or_winner: bool,
) -> Result<(), HardwareTieredModelCatalogError> {
    if !upstream_ref.starts_with(UPSTREAM_KV_BOUNDARY_PREFIX) {
        return Err(HardwareTieredModelCatalogError::BadUpstreamArtifactRef);
    }
    if cards.is_empty() {
        return Err(HardwareTieredModelCatalogError::EmptyCatalog);
    }
    if metadata_bytes > MAX_CATALOG_METADATA_BYTES {
        return Err(HardwareTieredModelCatalogError::MetadataBudgetExceeded);
    }
    if *product_build != ProductBuild::Pro
        || !matches!(
            pro_status,
            ProStatus::ResearchCandidate | ProStatus::Gated | ProStatus::VaultPreserved
        )
        || !matches!(
            promotion_tier,
            CompressedModelPromotionTier::T0Research | CompressedModelPromotionTier::T1L1Metadata
        )
    {
        return Err(
            HardwareTieredModelCatalogError::ProductPromotionFromResearch("catalog".to_string()),
        );
    }
    if !l1_l2_l3_separated
        || !product_promotion_blocked
        || !route_authority_blocked
        || !runtime_deferred
        || !source_card_required
        || !local_research_claims_quarantined
        || !no_default_model_or_winner
    {
        return Err(HardwareTieredModelCatalogError::MissingLayerSeparation);
    }

    let accepted = ACCEPTED_MODEL_IDS.iter().copied().collect::<HashSet<_>>();
    let mut card_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    for card in cards {
        validate_card_common(card)?;
        if !card_ids.insert(card.card_id.clone()) {
            return Err(HardwareTieredModelCatalogError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(HardwareTieredModelCatalogError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !accepted.contains(card.model_id.as_str()) {
            return Err(HardwareTieredModelCatalogError::UnknownModelId(
                card.model_id.clone(),
            ));
        }
        validate_model_tier(card)?;
        validate_source_and_claims(card)?;
        validate_proof_refs(&card.card_id, &card.proof_refs)?;
        validate_byte_scope(card)?;
        reject_forbidden_claims(card)?;
    }
    Ok(())
}

fn validate_card_common(
    card: &HardwareTieredModelCatalogCard,
) -> Result<(), HardwareTieredModelCatalogError> {
    for (field, value) in [
        ("card_id", card.card_id.as_str()),
        ("model_id", card.model_id.as_str()),
        ("source_url", card.source_url.as_str()),
        ("source_sha", card.source_sha.as_str()),
        ("license_ref", card.license_ref.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    if let Some(local_research_ref) = &card.local_research_ref {
        validate_nonempty("local_research_ref", local_research_ref)?;
    }
    for (field, value) in [
        ("loader_caveat_ref", card.loader_caveat_ref.as_deref()),
        ("headroom_caveat_ref", card.headroom_caveat_ref.as_deref()),
        ("kv_caveat_ref", card.kv_caveat_ref.as_deref()),
    ] {
        if let Some(value) = value {
            validate_nonempty(field, value)?;
        }
    }
    if card.product_build != ProductBuild::Pro
        || !matches!(
            card.pro_status,
            ProStatus::ResearchCandidate | ProStatus::Gated | ProStatus::VaultPreserved
        )
        || !matches!(
            card.promotion_tier,
            CompressedModelPromotionTier::T0Research | CompressedModelPromotionTier::T1L1Metadata
        )
    {
        return Err(
            HardwareTieredModelCatalogError::ProductPromotionFromResearch(card.card_id.clone()),
        );
    }
    if !card.source_card_required {
        return Err(
            HardwareTieredModelCatalogError::MissingSourceCardRequirement(card.card_id.clone()),
        );
    }
    if !card.runtime_deferred {
        return Err(
            HardwareTieredModelCatalogError::ProductPromotionFromResearch(card.card_id.clone()),
        );
    }
    Ok(())
}

fn validate_source_and_claims(
    card: &HardwareTieredModelCatalogCard,
) -> Result<(), HardwareTieredModelCatalogError> {
    if !card.source_url.starts_with("https://huggingface.co/") {
        return Err(HardwareTieredModelCatalogError::BadHfSource(
            card.card_id.clone(),
        ));
    }
    if !is_lower_hex_sha40(&card.source_sha) {
        return Err(HardwareTieredModelCatalogError::BadSourceSha(
            card.card_id.clone(),
        ));
    }
    let has_declared_local_size = card.byte_scope.declared_artifact_bytes.is_some()
        || card.byte_scope.declared_uma_floor_bytes.is_some();
    if has_declared_local_size || card.local_research_claim_only {
        let Some(local_research_ref) = card.local_research_ref.as_deref() else {
            return Err(
                HardwareTieredModelCatalogError::MissingLocalResearchQuarantine(
                    card.card_id.clone(),
                ),
            );
        };
        if !local_research_ref.starts_with(LOCAL_DOWNLOADS_PREFIX)
            || !card.local_research_claim_only
            || !card.source_card_required
            || card.product_route_enabled
        {
            return Err(
                HardwareTieredModelCatalogError::MissingLocalResearchQuarantine(
                    card.card_id.clone(),
                ),
            );
        }
    }
    Ok(())
}

fn validate_model_tier(
    card: &HardwareTieredModelCatalogCard,
) -> Result<(), HardwareTieredModelCatalogError> {
    if card.role == ModelCatalogRole::SmallHarness
        && card.model_id != "google/gemma-4-E2B-it-qat-q4_0-gguf"
    {
        return Err(HardwareTieredModelCatalogError::SmallHarnessOverclaim(
            card.card_id.clone(),
        ));
    }
    if card.model_id.contains("12B") && card.role == ModelCatalogRole::SmallHarness {
        return Err(HardwareTieredModelCatalogError::SmallHarnessOverclaim(
            card.card_id.clone(),
        ));
    }
    if card.model_id.contains("27B")
        && card.hardware_tier == HardwareTier::Mac16To18Gb
        && card.headroom_caveat_ref.is_none()
    {
        return Err(HardwareTieredModelCatalogError::MacTierOverclaim(
            card.card_id.clone(),
        ));
    }
    if (card.model_id.contains("31B") || card.model_id.contains("35B"))
        && card.hardware_tier == HardwareTier::Mac16To18Gb
    {
        return Err(HardwareTieredModelCatalogError::MacTierOverclaim(
            card.card_id.clone(),
        ));
    }
    if card.gpu_only && (!card.mac_default_denied || card.headroom_caveat_ref.is_none()) {
        return Err(HardwareTieredModelCatalogError::GpuOnlyNotDeniedOnMac(
            card.card_id.clone(),
        ));
    }
    if card.format == ModelCatalogFormat::Nvfp4
        && (!card.gpu_only
            || card.hardware_tier != HardwareTier::CudaBlackwellOnly
            || card.runtime_lane != ModelCatalogRuntimeLane::CudaBlackwell)
    {
        return Err(HardwareTieredModelCatalogError::GpuOnlyNotDeniedOnMac(
            card.card_id.clone(),
        ));
    }
    if card.format == ModelCatalogFormat::AutoRoundInt4
        && (!card.gpu_only
            || card.hardware_tier != HardwareTier::ServerGpuResearch
            || card.runtime_lane == ModelCatalogRuntimeLane::MlxSwift
            || card.runtime_lane == ModelCatalogRuntimeLane::GgufLlamaCpp)
    {
        return Err(HardwareTieredModelCatalogError::GpuOnlyNotDeniedOnMac(
            card.card_id.clone(),
        ));
    }
    let exotic = matches!(
        card.format,
        ModelCatalogFormat::Tq3_4s
            | ModelCatalogFormat::HlwqQ5
            | ModelCatalogFormat::ApexGguf
            | ModelCatalogFormat::Nvfp4
            | ModelCatalogFormat::AutoRoundInt4
    );
    if exotic && (!card.exotic_quant_provenance_required || !card.runtime_deferred) {
        return Err(HardwareTieredModelCatalogError::ExoticQuantWithoutGate(
            card.card_id.clone(),
        ));
    }
    if matches!(card.role, ModelCatalogRole::MoeAgenticCandidate)
        && (!card.active_params_truth_required || card.headroom_caveat_ref.is_none())
    {
        return Err(
            HardwareTieredModelCatalogError::MoeWithoutActiveParamsTruth(card.card_id.clone()),
        );
    }
    Ok(())
}

fn validate_byte_scope(
    card: &HardwareTieredModelCatalogCard,
) -> Result<(), HardwareTieredModelCatalogError> {
    if card.byte_scope.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(HardwareTieredModelCatalogError::MetadataBudgetExceeded);
    }
    if card.byte_scope.model_bytes_loaded != 0 {
        return Err(HardwareTieredModelCatalogError::NonzeroModelBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.runtime_bytes_loaded != 0 {
        return Err(HardwareTieredModelCatalogError::NonzeroRuntimeBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.provider_calls_made != 0 {
        return Err(HardwareTieredModelCatalogError::ProviderCallMade(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.source_tree_bytes_read != 0 {
        return Err(HardwareTieredModelCatalogError::SourceTreeBytesRead(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.product_files_copied != 0 {
        return Err(HardwareTieredModelCatalogError::ProductFileCopied(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.command_executions != 0 {
        return Err(HardwareTieredModelCatalogError::CommandExecuted(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.benchmark_runs != 0 {
        return Err(HardwareTieredModelCatalogError::BenchmarkRun(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn reject_forbidden_claims(
    card: &HardwareTieredModelCatalogCard,
) -> Result<(), HardwareTieredModelCatalogError> {
    if card.product_default_model_claim {
        return Err(HardwareTieredModelCatalogError::ProductDefaultClaim(
            card.card_id.clone(),
        ));
    }
    if card.product_winner_claim {
        return Err(HardwareTieredModelCatalogError::ProductWinnerClaim(
            card.card_id.clone(),
        ));
    }
    if card.product_route_enabled {
        return Err(HardwareTieredModelCatalogError::ProductRouteEnabled(
            card.card_id.clone(),
        ));
    }
    if card.hidden_route_authority {
        return Err(HardwareTieredModelCatalogError::HiddenRouteAuthority(
            card.card_id.clone(),
        ));
    }
    if card.hidden_cloud_fallback {
        return Err(HardwareTieredModelCatalogError::HiddenCloudFallback(
            card.card_id.clone(),
        ));
    }
    if card.l2_l3_promotion_claim {
        return Err(HardwareTieredModelCatalogError::L2L3PromotionClaim(
            card.card_id.clone(),
        ));
    }
    if card.live_dense_70b_claim {
        return Err(HardwareTieredModelCatalogError::LiveDense70BClaim(
            card.card_id.clone(),
        ));
    }
    if card.ssd_as_ram_claim {
        return Err(HardwareTieredModelCatalogError::SsdAsRamClaim(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    card_id: &str,
    proof_refs: &ModelCatalogProofRefs,
) -> Result<(), HardwareTieredModelCatalogError> {
    for (field, value, prefix) in [
        (
            "falsifier_ref",
            proof_refs.falsifier_ref.as_str(),
            FALSIFIER_PREFIX,
        ),
        (
            "rollback_ref",
            proof_refs.rollback_ref.as_str(),
            ROLLBACK_PREFIX,
        ),
        (
            "run_event_log_ref",
            proof_refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof_refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof_refs.compatibility_fence_ref.as_str(),
            COMPAT_PREFIX,
        ),
        (
            "privacy_policy_ref",
            proof_refs.privacy_policy_ref.as_str(),
            PRIVACY_PREFIX,
        ),
        (
            "provenance_ref",
            proof_refs.provenance_ref.as_str(),
            PROVENANCE_PREFIX,
        ),
        (
            "hardware_tier_ref",
            proof_refs.hardware_tier_ref.as_str(),
            HARDWARE_PREFIX,
        ),
    ] {
        validate_nonempty(field, value)?;
        if !value.starts_with(prefix) {
            return Err(HardwareTieredModelCatalogError::BadProofRefPrefix {
                card_id: card_id.to_string(),
                field,
            });
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn catalog_address(
    upstream_ref: &str,
    cards: &[HardwareTieredModelCatalogCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    route_authority_blocked: bool,
    runtime_deferred: bool,
    source_card_required: bool,
    local_research_claims_quarantined: bool,
    no_default_model_or_winner: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_CURSOR);
    preimage.push('\n');
    preimage.push_str(upstream_ref);
    preimage.push('\n');
    preimage.push_str(product_build_preimage(product_build));
    preimage.push('\n');
    preimage.push_str(pro_status_preimage(pro_status));
    preimage.push('\n');
    preimage.push_str(&format!("{promotion_tier:?}\n{metadata_bytes}\n"));
    for flag in [
        l1_l2_l3_separated,
        product_promotion_blocked,
        route_authority_blocked,
        runtime_deferred,
        source_card_required,
        local_research_claims_quarantined,
        no_default_model_or_winner,
    ] {
        preimage.push_str(if flag { "true" } else { "false" });
        preimage.push('\n');
    }
    for card in cards {
        push_card_preimage(&mut preimage, card);
    }
    UasAddress::new(
        UasKind::Other(HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_card_preimage(preimage: &mut String, card: &HardwareTieredModelCatalogCard) {
    preimage.push_str(&card.card_id);
    preimage.push('|');
    preimage.push_str(&card.model_id);
    preimage.push('|');
    preimage.push_str(&card.source_sha);
    preimage.push('|');
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
        card.hardware_tier,
        card.role,
        card.format,
        card.runtime_lane,
        card.source_authority,
        card.pro_status,
        card.promotion_tier
    ));
    preimage.push('|');
    preimage.push_str(card.local_research_ref.as_deref().unwrap_or("none"));
    preimage.push('|');
    for flag in [
        card.active_params_truth_required,
        card.exotic_quant_provenance_required,
        card.gpu_only,
        card.mac_default_denied,
        card.local_research_claim_only,
        card.source_card_required,
        card.runtime_deferred,
        card.product_route_enabled,
        card.product_default_model_claim,
        card.product_winner_claim,
        card.hidden_route_authority,
        card.hidden_cloud_fallback,
        card.l2_l3_promotion_claim,
        card.live_dense_70b_claim,
        card.ssd_as_ram_claim,
    ] {
        preimage.push_str(if flag { "true," } else { "false," });
    }
    preimage.push('\n');
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), HardwareTieredModelCatalogError> {
    if value.is_empty() {
        return Err(HardwareTieredModelCatalogError::MissingField(field));
    }
    if value.trim() != value {
        return Err(HardwareTieredModelCatalogError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(HardwareTieredModelCatalogError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn is_lower_hex_sha40(value: &str) -> bool {
    value.len() == 40
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_220_000_000;
    const UPSTREAM_REF: &str =
        "artifact:falsifiers/kv_source_card_fork_and_daemon_boundary/result.json#sha256:test";

    #[test]
    fn accepted_catalog_is_deterministic_metadata_only() {
        let cards = fixture_cards();
        let catalog = build_catalog(cards.clone()).expect("valid catalog");
        let reversed = build_catalog(cards.into_iter().rev().collect()).expect("valid catalog");
        let metrics = catalog.metrics();

        assert_eq!(catalog.catalog_address, reversed.catalog_address);
        assert_eq!(metrics.card_count, ACCEPTED_MODEL_IDS.len() as u64);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.provider_calls_made, 0);
        assert!(catalog
            .address()
            .starts_with("hardware_tiered_model_catalog_source_card:"));
    }

    #[test]
    fn duplicate_model_rejects() {
        assert!(reject_cards(|cards| {
            cards[1].model_id = cards[0].model_id.clone();
        }));
    }

    #[test]
    fn non_gemma_e2b_small_harness_rejects() {
        assert!(reject_card("gemma4_12b_qat_gguf", |card| {
            card.role = ModelCatalogRole::SmallHarness;
        }));
    }

    #[test]
    fn thirty_one_b_cannot_be_mac_18gb() {
        assert!(reject_card("gemma4_31b_nvfp4", |card| {
            card.hardware_tier = HardwareTier::Mac16To18Gb;
            card.gpu_only = false;
            card.mac_default_denied = false;
        }));
    }

    #[test]
    fn exotic_quant_requires_gate() {
        assert!(reject_card("qwopus27b_tq3_4s", |card| {
            card.exotic_quant_provenance_required = false;
        }));
    }

    #[test]
    fn moe_requires_active_param_truth() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.active_params_truth_required = false;
        }));
    }

    #[test]
    fn local_declared_bytes_need_quarantine_ref() {
        assert!(reject_card("qwopus27b_gguf", |card| {
            card.local_research_ref = None;
        }));
    }

    #[test]
    fn product_winner_claim_rejects() {
        assert!(reject_card("gemma4_12b_qat_gguf", |card| {
            card.product_winner_claim = true;
        }));
    }

    #[test]
    fn runtime_bytes_reject() {
        assert!(reject_card("gemma4_e2b_qat_gguf", |card| {
            card.byte_scope.runtime_bytes_loaded = 1;
        }));
    }

    fn build_catalog(
        cards: Vec<HardwareTieredModelCatalogCard>,
    ) -> Result<HardwareTieredModelCatalog, HardwareTieredModelCatalogError> {
        HardwareTieredModelCatalog::new(
            UPSTREAM_REF,
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
            true,
            CREATED_AT_MS,
        )
    }

    fn reject_cards(mutate: impl FnOnce(&mut Vec<HardwareTieredModelCatalogCard>)) -> bool {
        let mut cards = fixture_cards();
        mutate(&mut cards);
        build_catalog(cards).is_err()
    }

    fn reject_card(
        card_id: &str,
        mutate: impl FnOnce(&mut HardwareTieredModelCatalogCard),
    ) -> bool {
        let mut cards = fixture_cards();
        if let Some(card) = cards.iter_mut().find(|card| card.card_id == card_id) {
            mutate(card);
        }
        build_catalog(cards).is_err()
    }

    fn fixture_cards() -> Vec<HardwareTieredModelCatalogCard> {
        vec![
            card(
                "gemma4_e2b_qat_gguf",
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                "1894d1fc0a19d86697abd40483f5983c867df03f",
                HardwareTier::Mac16To18Gb,
                ModelCatalogRole::SmallHarness,
                ModelCatalogFormat::Gguf,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                false,
                false,
                false,
                false,
            ),
            card(
                "gemma4_12b_qat_gguf",
                "google/gemma-4-12B-it-qat-q4_0-gguf",
                "f6e7774e6148da3b7f201e42ba37cf084c1db35f",
                HardwareTier::Mac16To18Gb,
                ModelCatalogRole::ProGatedFlagship,
                ModelCatalogFormat::Gguf,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                false,
                false,
                false,
                true,
            ),
            card(
                "qwopus27b_gguf",
                "Jackrong/Qwopus3.5-27B-v3-GGUF",
                "f99664710e7bc973c877106217cbc600cea2facd",
                HardwareTier::Mac16To18Gb,
                ModelCatalogRole::CodingReasoningCandidate,
                ModelCatalogFormat::Gguf,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                false,
                false,
                false,
                true,
            ),
            card(
                "qwopus27b_tq3_4s",
                "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
                "d1f4ed7d1c610cfac430c244d456af6aeac442ce",
                HardwareTier::Mac16To18Gb,
                ModelCatalogRole::ExoticQuantCandidate,
                ModelCatalogFormat::Tq3_4s,
                ModelCatalogRuntimeLane::NoRuntime,
                false,
                true,
                false,
                true,
            ),
            card(
                "qwopus27b_hlwq_q5",
                "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
                "f744e234acfbf2a281eb916424bbaaf914e70329",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRole::ExoticQuantCandidate,
                ModelCatalogFormat::HlwqQ5,
                ModelCatalogRuntimeLane::NoRuntime,
                false,
                true,
                false,
                true,
            ),
            card(
                "qwopus_moe_35b_a3b_gguf",
                "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF",
                "19f9e6fa8065b2f1e42aaa16d4adafac1e9a9a01",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRole::MoeAgenticCandidate,
                ModelCatalogFormat::Gguf,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                true,
                false,
                false,
                true,
            ),
            card(
                "qwopus_moe_35b_a3b_apex_gguf",
                "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
                "724281f1f6af99158ae89cba4196f39ccc4e039e",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRole::MoeAgenticCandidate,
                ModelCatalogFormat::ApexGguf,
                ModelCatalogRuntimeLane::NoRuntime,
                true,
                true,
                false,
                true,
            ),
            card(
                "gemma4_31b_nvfp4",
                "nvidia/Gemma-4-31B-IT-NVFP4",
                "e5ef03afa233c35cb000323ff098d4291e1dd07c",
                HardwareTier::CudaBlackwellOnly,
                ModelCatalogRole::GpuServerOnly,
                ModelCatalogFormat::Nvfp4,
                ModelCatalogRuntimeLane::CudaBlackwell,
                false,
                true,
                true,
                true,
            ),
            card(
                "gemma4_31b_int4_autoround",
                "Intel/gemma-4-31B-it-int4-AutoRound",
                "a428c96a57976947b0f12735f0cf5fcae69019ad",
                HardwareTier::ServerGpuResearch,
                ModelCatalogRole::GpuServerOnly,
                ModelCatalogFormat::AutoRoundInt4,
                ModelCatalogRuntimeLane::VllmServer,
                false,
                true,
                true,
                true,
            ),
        ]
    }

    #[allow(clippy::too_many_arguments)]
    fn card(
        card_id: &str,
        model_id: &str,
        source_sha: &str,
        hardware_tier: HardwareTier,
        role: ModelCatalogRole,
        format: ModelCatalogFormat,
        runtime_lane: ModelCatalogRuntimeLane,
        active_params_truth_required: bool,
        exotic_quant_provenance_required: bool,
        gpu_only: bool,
        needs_headroom_caveat: bool,
    ) -> HardwareTieredModelCatalogCard {
        HardwareTieredModelCatalogCard {
            card_id: card_id.to_string(),
            model_id: model_id.to_string(),
            source_url: format!("https://huggingface.co/{model_id}"),
            source_sha: source_sha.to_string(),
            license_ref: "license:source-card-required".to_string(),
            local_research_ref: Some("local_downloads:locals.md+locals2.md".to_string()),
            hardware_tier,
            role,
            format,
            runtime_lane,
            source_authority: ModelCatalogSourceAuthority::CurrentHfMetadata,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            loader_caveat_ref: Some("compat:loader-proof-required".to_string()),
            headroom_caveat_ref: needs_headroom_caveat
                .then(|| "hardware:headroom-not-runtime-proof".to_string()),
            kv_caveat_ref: Some("compat:kv-budget-not-proven".to_string()),
            active_params_truth_required,
            exotic_quant_provenance_required,
            gpu_only,
            mac_default_denied: gpu_only,
            local_research_claim_only: true,
            source_card_required: true,
            runtime_deferred: true,
            product_route_enabled: false,
            product_default_model_claim: false,
            product_winner_claim: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_l3_promotion_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            byte_scope: ModelCatalogByteScope::metadata_only(10_000, 4_000, Some(1), Some(1)),
            proof_refs: ModelCatalogProofRefs {
                falsifier_ref: "falsifier:F-HardwareTieredModelCatalog-SourceCard".to_string(),
                rollback_ref: "rollback:remove-catalog-row-and-abstain".to_string(),
                run_event_log_ref: "run_event_log:catalog-metadata-only".to_string(),
                answer_packet_ref: "answer_packet:catalog-visible-proof-required".to_string(),
                compatibility_fence_ref: "compat:runtime-lane-proof-required".to_string(),
                privacy_policy_ref: "privacy:no-provider-call-no-cloud-fallback".to_string(),
                provenance_ref: "provenance:source-card-required-before-import".to_string(),
                hardware_tier_ref: "hardware:tier-is-candidate-not-fit-proof".to_string(),
            },
        }
    }
}
