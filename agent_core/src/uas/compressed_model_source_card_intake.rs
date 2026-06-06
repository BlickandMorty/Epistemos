//! Compressed model source-card intake.
//!
//! This primitive is the metadata-only bridge from TurboVec/QAT/runtime
//! research into typed source cards that later route-card, byte, runtime, and
//! WRV witnesses may cite. It does not load model/index/runtime bytes, choose
//! a route, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{
    ModelInventoryCandidateSet, ModelInventoryClaimLimit, ModelInventoryMetadataStatus, ProStatus,
    ProductBuild, ProprietaryCompressionAllowedAction, ProprietaryCompressionImportMode,
    ProprietaryCompressionProvenanceGate, SourceSignalGraph, UasAddress, UasKind,
};

pub const COMPRESSED_MODEL_SOURCE_CARD_INTAKE_CURSOR: &str = "compressed_model_source_card_intake";
pub const COMPRESSED_MODEL_SOURCE_CARD_INTAKE_NEXT_CURSOR: &str =
    "gemma_qat_local_runtime_candidate_card";

const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_INTAKE_METADATA_BYTES: u64 = 640 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:compressed-model-source-card:kind
// Plane: State + Assembly
// Residency: metadata-only card taxonomy; not runtime availability.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedModelSourceCardKind {
    QuantizedModel,
    MobileQatModel,
    RuntimePackage,
    CompressedIndex,
    CodecLibrary,
    BenchmarkCorpus,
    LocalCanon,
}

// UAS: uas:compressed-model-source-card:format
// Plane: State + Controller
// Residency: source-carded artifact shape; no file bytes are opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedModelFormat {
    Gguf,
    Mlx,
    Safetensors,
    LiteRt,
    TurboVecIndex,
    PackageManifest,
    LocalCanon,
}

// UAS: uas:compressed-model-source-card:runtime-lane
// Plane: Controller
// Residency: lane candidate only; no route authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedModelRuntimeLane {
    MlxSwift,
    MlxPython,
    GgufLlamaCpp,
    LiteRtLm,
    Transformers,
    TurboVecEidosCache,
    CustomMetal,
    NoRuntime,
}

// UAS: uas:compressed-model-source-card:organ
// Plane: State + Assembly + Controller
// Residency: Epistemos organ that may cite the card after later witnesses.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedModelOrgan {
    Uas,
    AppColdStore,
    ActiveAssembly,
    Eidos,
    ColdStream,
    RuntimeRouter,
    SovereignGate,
    AnswerPacket,
}

// UAS: uas:compressed-model-source-card:tier
// Plane: Verification
// Residency: promotion tier; this witness accepts T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedModelPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:compressed-model-source-card:byte-scope
// Plane: Verification
// Residency: declared facts are metadata; loaded bytes must stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedModelSourceByteScope {
    pub metadata_bytes_read: u64,
    pub sidecar_bytes_read: u64,
    pub declared_artifact_bytes: Option<u64>,
    pub declared_runtime_memory_floor_bytes: Option<u64>,
    pub model_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
    pub weight_blob_open_attempted: bool,
    pub weight_blob_hash_attempted: bool,
}

impl CompressedModelSourceByteScope {
    pub fn metadata_only(
        metadata_bytes_read: u64,
        sidecar_bytes_read: u64,
        declared_artifact_bytes: Option<u64>,
        declared_runtime_memory_floor_bytes: Option<u64>,
    ) -> Self {
        Self {
            metadata_bytes_read,
            sidecar_bytes_read,
            declared_artifact_bytes,
            declared_runtime_memory_floor_bytes,
            model_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
            weight_blob_open_attempted: false,
            weight_blob_hash_attempted: false,
        }
    }
}

// UAS: uas:compressed-model-source-card:proof-refs
// Plane: Verification
// Residency: visible proof handles required before later route/runtime use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedModelSourceProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:compressed-model-source-card:card
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only card; never hidden route authority or product proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedModelSourceCard {
    pub card_id: String,
    pub source_id: String,
    pub source_digest: String,
    pub model_inventory_candidate_ref: Option<String>,
    pub provenance_overlay_ref: Option<String>,
    pub model_or_package_id: String,
    pub card_kind: CompressedModelSourceCardKind,
    pub format: CompressedModelFormat,
    pub runtime_lane: CompressedModelRuntimeLane,
    pub organ: CompressedModelOrgan,
    pub quantization_ref: Option<String>,
    pub context_window_ref: Option<String>,
    pub license_ref: String,
    pub loader_caveat_ref: Option<String>,
    pub route_caveat_ref: Option<String>,
    pub source_locator: String,
    pub import_mode: ProprietaryCompressionImportMode,
    pub allowed_action: ProprietaryCompressionAllowedAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub claim_limit: ModelInventoryClaimLimit,
    pub metadata_status: ModelInventoryMetadataStatus,
    pub byte_scope: CompressedModelSourceByteScope,
    pub proof_refs: CompressedModelSourceProofRefs,
}

// UAS: uas:compressed-model-source-card:intake
// Plane: State + Assembly + Controller + Verification
// Residency: source-card intake over compressed model/runtime/index candidates.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedModelSourceCardIntake {
    pub intake_address: UasAddress,
    pub source_graph_address: UasAddress,
    pub model_inventory_address: UasAddress,
    pub provenance_gate_address: UasAddress,
    pub cards: Vec<CompressedModelSourceCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub route_authority_blocked: bool,
    pub product_promotion_blocked: bool,
    pub rowid_identity_blocked: bool,
}

// UAS: uas:compressed-model-source-card:metrics
// Plane: Verification
// Residency: derived counters for metadata-only falsifier artifacts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedModelSourceCardMetrics {
    pub card_count: u64,
    pub card_kind_count: u64,
    pub format_count: u64,
    pub runtime_lane_count: u64,
    pub organ_count: u64,
    pub quantized_card_count: u64,
    pub runtime_package_card_count: u64,
    pub compressed_index_card_count: u64,
    pub model_inventory_binding_count: u64,
    pub provenance_overlay_binding_count: u64,
    pub loader_caveat_count: u64,
    pub route_caveat_count: u64,
    pub declared_artifact_bytes_total: u64,
    pub declared_runtime_memory_floor_bytes_total: u64,
    pub metadata_bytes_read: u64,
    pub sidecar_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
    pub weight_blob_open_attempt_count: u64,
    pub weight_blob_hash_attempt_count: u64,
}

impl CompressedModelSourceCardIntake {
    #[allow(clippy::too_many_arguments)]
    pub fn from_provenance(
        graph: &SourceSignalGraph,
        inventory: &ModelInventoryCandidateSet,
        provenance_gate: &ProprietaryCompressionProvenanceGate,
        mut cards: Vec<CompressedModelSourceCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        route_authority_blocked: bool,
        product_promotion_blocked: bool,
        rowid_identity_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, CompressedModelSourceCardError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        validate_intake_inputs(
            graph,
            inventory,
            provenance_gate,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            rowid_identity_blocked,
        )?;
        let intake_address = intake_address(
            &graph.graph_address,
            &inventory.inventory_address,
            &provenance_gate.gate_address,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            rowid_identity_blocked,
            created_at_ms,
        );
        Ok(Self {
            intake_address,
            source_graph_address: graph.graph_address.clone(),
            model_inventory_address: inventory.inventory_address.clone(),
            provenance_gate_address: provenance_gate.gate_address.clone(),
            cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            rowid_identity_blocked,
        })
    }

    pub fn metrics(&self) -> CompressedModelSourceCardMetrics {
        let mut kinds = BTreeSet::new();
        let mut formats = BTreeSet::new();
        let mut lanes = BTreeSet::new();
        let mut organs = BTreeSet::new();

        for card in &self.cards {
            kinds.insert(card.card_kind);
            formats.insert(card.format);
            lanes.insert(card.runtime_lane);
            organs.insert(card.organ);
        }

        CompressedModelSourceCardMetrics {
            card_count: self.cards.len() as u64,
            card_kind_count: kinds.len() as u64,
            format_count: formats.len() as u64,
            runtime_lane_count: lanes.len() as u64,
            organ_count: organs.len() as u64,
            quantized_card_count: self
                .cards
                .iter()
                .filter(|card| {
                    matches!(
                        card.card_kind,
                        CompressedModelSourceCardKind::QuantizedModel
                            | CompressedModelSourceCardKind::MobileQatModel
                    )
                })
                .count() as u64,
            runtime_package_card_count: self
                .cards
                .iter()
                .filter(|card| card.card_kind == CompressedModelSourceCardKind::RuntimePackage)
                .count() as u64,
            compressed_index_card_count: self
                .cards
                .iter()
                .filter(|card| card.card_kind == CompressedModelSourceCardKind::CompressedIndex)
                .count() as u64,
            model_inventory_binding_count: self
                .cards
                .iter()
                .filter(|card| card.model_inventory_candidate_ref.is_some())
                .count() as u64,
            provenance_overlay_binding_count: self
                .cards
                .iter()
                .filter(|card| card.provenance_overlay_ref.is_some())
                .count() as u64,
            loader_caveat_count: self
                .cards
                .iter()
                .filter(|card| card.loader_caveat_ref.is_some())
                .count() as u64,
            route_caveat_count: self
                .cards
                .iter()
                .filter(|card| card.route_caveat_ref.is_some())
                .count() as u64,
            declared_artifact_bytes_total: self
                .cards
                .iter()
                .filter_map(|card| card.byte_scope.declared_artifact_bytes)
                .sum(),
            declared_runtime_memory_floor_bytes_total: self
                .cards
                .iter()
                .filter_map(|card| card.byte_scope.declared_runtime_memory_floor_bytes)
                .sum(),
            metadata_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.metadata_bytes_read)
                .sum(),
            sidecar_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.sidecar_bytes_read)
                .sum(),
            model_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_scope.model_bytes_loaded)
                .sum(),
            index_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_scope.index_bytes_loaded)
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
            copied_product_file_count: self
                .cards
                .iter()
                .map(|card| card.byte_scope.copied_product_file_count)
                .sum(),
            weight_blob_open_attempt_count: self
                .cards
                .iter()
                .map(|card| u64::from(card.byte_scope.weight_blob_open_attempted))
                .sum(),
            weight_blob_hash_attempt_count: self
                .cards
                .iter()
                .map(|card| u64::from(card.byte_scope.weight_blob_hash_attempted))
                .sum(),
        }
    }

    pub fn address(&self) -> String {
        self.intake_address.to_string()
    }
}

// UAS: uas:compressed-model-source-card:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy before source cards feed routes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CompressedModelSourceCardError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyCardSet,
    GraphInventoryMismatch,
    GraphProvenanceMismatch,
    InventoryProvenanceMismatch,
    DuplicateCardId(String),
    DuplicateSourceId(String),
    DuplicateInventoryCandidateRef(String),
    UnknownSourceId(String),
    BlockedSourceId(String),
    SourceDigestMismatch(String),
    UnknownInventoryCandidate(String),
    InventorySourceMismatch(String),
    UnknownProvenanceOverlay(String),
    ProvenanceSourceMismatch(String),
    ProvenanceImportMismatch(String),
    MissingProofRef {
        card_id: String,
        field: &'static str,
    },
    BadProofRefPrefix {
        card_id: String,
        field: &'static str,
    },
    MissingLicenseRef(String),
    MissingDeclaredArtifactBytes(String),
    MissingRouteCaveat(String),
    MissingGemma4LoaderCaveat(String),
    PackageManifestAsLoaderProof(String),
    TurboVecNotEidosCache(String),
    GgufLaneMismatch(String),
    LiteRtLaneMismatch(String),
    MlxGemma4LoaderClaim(String),
    RuntimeRouteAuthority(String),
    ProductFileCopied(String),
    WeightBlobOpened(String),
    WeightBlobHashAttempted(String),
    NonzeroModelBytes(String),
    NonzeroIndexBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    RowIdIdentity(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    Dense70BLiveClaim(String),
    SsdAsRamClaim(String),
    ProductGreenFromResearch(String),
    MasLiveFromResearch(String),
    TierPromotionFromResearch(String),
    MissingLayerSeparation,
    MetadataBudgetExceeded,
}

impl fmt::Display for CompressedModelSourceCardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyCardSet => write!(f, "missing compressed model source cards"),
            Self::GraphInventoryMismatch => write!(f, "inventory is not bound to source graph"),
            Self::GraphProvenanceMismatch => write!(f, "provenance gate is not bound to graph"),
            Self::InventoryProvenanceMismatch => {
                write!(f, "provenance gate is not bound to inventory")
            }
            Self::DuplicateCardId(id) => write!(f, "duplicate card id `{id}`"),
            Self::DuplicateSourceId(id) => write!(f, "duplicate source id `{id}`"),
            Self::DuplicateInventoryCandidateRef(id) => {
                write!(f, "duplicate inventory candidate ref `{id}`")
            }
            Self::UnknownSourceId(id) => write!(f, "unknown source id `{id}`"),
            Self::BlockedSourceId(id) => write!(f, "blocked source id `{id}`"),
            Self::SourceDigestMismatch(id) => write!(f, "source digest mismatch for `{id}`"),
            Self::UnknownInventoryCandidate(id) => {
                write!(f, "unknown inventory candidate `{id}`")
            }
            Self::InventorySourceMismatch(id) => {
                write!(f, "inventory source mismatch for `{id}`")
            }
            Self::UnknownProvenanceOverlay(id) => {
                write!(f, "unknown provenance overlay `{id}`")
            }
            Self::ProvenanceSourceMismatch(id) => {
                write!(f, "provenance source mismatch for `{id}`")
            }
            Self::ProvenanceImportMismatch(id) => {
                write!(f, "provenance import mismatch for `{id}`")
            }
            Self::MissingProofRef { card_id, field } => {
                write!(f, "card `{card_id}` missing proof ref `{field}`")
            }
            Self::BadProofRefPrefix { card_id, field } => {
                write!(f, "card `{card_id}` has bad proof ref prefix `{field}`")
            }
            Self::MissingLicenseRef(id) => write!(f, "card `{id}` missing license ref"),
            Self::MissingDeclaredArtifactBytes(id) => {
                write!(f, "card `{id}` missing declared artifact bytes")
            }
            Self::MissingRouteCaveat(id) => write!(f, "card `{id}` missing route caveat"),
            Self::MissingGemma4LoaderCaveat(id) => {
                write!(f, "card `{id}` missing Gemma 4 loader caveat")
            }
            Self::PackageManifestAsLoaderProof(id) => {
                write!(f, "card `{id}` used package manifest as loader proof")
            }
            Self::TurboVecNotEidosCache(id) => {
                write!(f, "card `{id}` treated TurboVec as non-Eidos cache")
            }
            Self::GgufLaneMismatch(id) => write!(f, "card `{id}` has GGUF lane mismatch"),
            Self::LiteRtLaneMismatch(id) => write!(f, "card `{id}` has LiteRT lane mismatch"),
            Self::MlxGemma4LoaderClaim(id) => {
                write!(f, "card `{id}` claimed MLX Gemma 4 loader readiness")
            }
            Self::RuntimeRouteAuthority(id) => {
                write!(f, "card `{id}` became runtime route authority")
            }
            Self::ProductFileCopied(id) => write!(f, "card `{id}` copied product files"),
            Self::WeightBlobOpened(id) => write!(f, "card `{id}` opened a weight blob"),
            Self::WeightBlobHashAttempted(id) => {
                write!(f, "card `{id}` attempted weight blob hashing")
            }
            Self::NonzeroModelBytes(id) => write!(f, "card `{id}` loaded model bytes"),
            Self::NonzeroIndexBytes(id) => write!(f, "card `{id}` loaded index bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "card `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "card `{id}` made provider calls"),
            Self::RowIdIdentity(id) => write!(f, "card `{id}` used rowid as identity"),
            Self::HiddenRouteAuthority(id) => write!(f, "card `{id}` hid route authority"),
            Self::HiddenCloudFallback(id) => write!(f, "card `{id}` hid cloud fallback"),
            Self::Dense70BLiveClaim(id) => write!(f, "card `{id}` claimed live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "card `{id}` claimed SSD as RAM"),
            Self::ProductGreenFromResearch(id) => {
                write!(f, "card `{id}` promoted research to product green")
            }
            Self::MasLiveFromResearch(id) => write!(f, "card `{id}` leaked into MAS Live"),
            Self::TierPromotionFromResearch(id) => {
                write!(f, "card `{id}` promoted beyond T1 from research")
            }
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for CompressedModelSourceCardError {}

fn validate_intake_inputs(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: &[CompressedModelSourceCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
    rowid_identity_blocked: bool,
) -> Result<(), CompressedModelSourceCardError> {
    if cards.is_empty() {
        return Err(CompressedModelSourceCardError::EmptyCardSet);
    }
    if metadata_bytes > MAX_INTAKE_METADATA_BYTES {
        return Err(CompressedModelSourceCardError::MetadataBudgetExceeded);
    }
    if inventory.source_graph_address != graph.graph_address {
        return Err(CompressedModelSourceCardError::GraphInventoryMismatch);
    }
    if provenance_gate.source_graph_address != graph.graph_address {
        return Err(CompressedModelSourceCardError::GraphProvenanceMismatch);
    }
    if provenance_gate.model_inventory_address != inventory.inventory_address {
        return Err(CompressedModelSourceCardError::InventoryProvenanceMismatch);
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(CompressedModelSourceCardError::ProductGreenFromResearch(
            "intake".to_string(),
        ));
    }
    if !l1_l2_l3_separated
        || !route_authority_blocked
        || !product_promotion_blocked
        || !rowid_identity_blocked
    {
        return Err(CompressedModelSourceCardError::MissingLayerSeparation);
    }

    let accepted_sources = graph
        .source_cards
        .iter()
        .map(|card| (card.source_id.as_str(), card.digest.as_str()))
        .collect::<HashMap<_, _>>();
    let rejected_sources = graph
        .rejected_source_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let inventory_candidates = inventory
        .cards
        .iter()
        .map(|card| (card.candidate_id.as_str(), card.source_id.as_str()))
        .collect::<HashMap<_, _>>();
    let overlays = provenance_gate
        .overlays
        .iter()
        .map(|overlay| {
            (
                overlay.overlay_id.as_str(),
                (
                    overlay.source_id.as_str(),
                    overlay.import_mode,
                    overlay.allowed_action,
                ),
            )
        })
        .collect::<HashMap<_, _>>();

    let mut card_ids = HashSet::new();
    let mut source_ids = HashSet::new();
    let mut inventory_refs = HashSet::new();

    for card in cards {
        validate_card_common(card)?;
        if !card_ids.insert(card.card_id.as_str()) {
            return Err(CompressedModelSourceCardError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !source_ids.insert(card.source_id.as_str()) {
            return Err(CompressedModelSourceCardError::DuplicateSourceId(
                card.source_id.clone(),
            ));
        }
        if let Some(candidate_ref) = card.model_inventory_candidate_ref.as_deref() {
            if !inventory_refs.insert(candidate_ref) {
                return Err(
                    CompressedModelSourceCardError::DuplicateInventoryCandidateRef(
                        candidate_ref.to_string(),
                    ),
                );
            }
        }
        if rejected_sources.contains(card.source_id.as_str()) {
            return Err(CompressedModelSourceCardError::BlockedSourceId(
                card.source_id.clone(),
            ));
        }
        let Some(expected_digest) = accepted_sources.get(card.source_id.as_str()) else {
            return Err(CompressedModelSourceCardError::UnknownSourceId(
                card.source_id.clone(),
            ));
        };
        if *expected_digest != card.source_digest {
            return Err(CompressedModelSourceCardError::SourceDigestMismatch(
                card.card_id.clone(),
            ));
        }
        if let Some(candidate_ref) = card.model_inventory_candidate_ref.as_deref() {
            let Some(source_id) = inventory_candidates.get(candidate_ref) else {
                return Err(CompressedModelSourceCardError::UnknownInventoryCandidate(
                    candidate_ref.to_string(),
                ));
            };
            if *source_id != card.source_id {
                return Err(CompressedModelSourceCardError::InventorySourceMismatch(
                    card.card_id.clone(),
                ));
            }
        }
        if let Some(overlay_ref) = card.provenance_overlay_ref.as_deref() {
            let Some((source_id, import_mode, allowed_action)) = overlays.get(overlay_ref) else {
                return Err(CompressedModelSourceCardError::UnknownProvenanceOverlay(
                    overlay_ref.to_string(),
                ));
            };
            if *source_id != card.source_id {
                return Err(CompressedModelSourceCardError::ProvenanceSourceMismatch(
                    card.card_id.clone(),
                ));
            }
            if *import_mode != card.import_mode || *allowed_action != card.allowed_action {
                return Err(CompressedModelSourceCardError::ProvenanceImportMismatch(
                    card.card_id.clone(),
                ));
            }
        }
        validate_card_shape(card)?;
        validate_byte_scope(card)?;
        reject_forbidden_claims(card)?;
    }

    Ok(())
}

fn validate_card_common(
    card: &CompressedModelSourceCard,
) -> Result<(), CompressedModelSourceCardError> {
    for (field, value) in [
        ("card_id", card.card_id.as_str()),
        ("source_id", card.source_id.as_str()),
        ("source_digest", card.source_digest.as_str()),
        ("model_or_package_id", card.model_or_package_id.as_str()),
        ("license_ref", card.license_ref.as_str()),
        ("source_locator", card.source_locator.as_str()),
    ] {
        validate_nonempty(field, value)?;
        reject_rowid_identity(&card.card_id, value)?;
    }
    validate_optional_text(
        "model_inventory_candidate_ref",
        card.model_inventory_candidate_ref.as_deref(),
    )?;
    validate_optional_text(
        "provenance_overlay_ref",
        card.provenance_overlay_ref.as_deref(),
    )?;
    validate_optional_text("quantization_ref", card.quantization_ref.as_deref())?;
    validate_optional_text("context_window_ref", card.context_window_ref.as_deref())?;
    validate_optional_text("loader_caveat_ref", card.loader_caveat_ref.as_deref())?;
    validate_optional_text("route_caveat_ref", card.route_caveat_ref.as_deref())?;
    if card.license_ref.trim().is_empty() {
        return Err(CompressedModelSourceCardError::MissingLicenseRef(
            card.card_id.clone(),
        ));
    }
    if card.product_build != ProductBuild::Pro {
        return Err(CompressedModelSourceCardError::MasLiveFromResearch(
            card.card_id.clone(),
        ));
    }
    if card.pro_status != ProStatus::ResearchCandidate {
        return Err(CompressedModelSourceCardError::ProductGreenFromResearch(
            card.card_id.clone(),
        ));
    }
    if !matches!(
        card.promotion_tier,
        CompressedModelPromotionTier::T0Research | CompressedModelPromotionTier::T1L1Metadata
    ) {
        return Err(CompressedModelSourceCardError::TierPromotionFromResearch(
            card.card_id.clone(),
        ));
    }
    validate_proof_refs(&card.card_id, &card.proof_refs)?;
    Ok(())
}

fn validate_card_shape(
    card: &CompressedModelSourceCard,
) -> Result<(), CompressedModelSourceCardError> {
    if matches!(
        card.card_kind,
        CompressedModelSourceCardKind::QuantizedModel
            | CompressedModelSourceCardKind::MobileQatModel
    ) && card.byte_scope.declared_artifact_bytes.is_none()
    {
        return Err(
            CompressedModelSourceCardError::MissingDeclaredArtifactBytes(card.card_id.clone()),
        );
    }
    if card.runtime_lane != CompressedModelRuntimeLane::NoRuntime && card.route_caveat_ref.is_none()
    {
        return Err(CompressedModelSourceCardError::MissingRouteCaveat(
            card.card_id.clone(),
        ));
    }

    match card.format {
        CompressedModelFormat::Gguf => {
            if !matches!(
                card.runtime_lane,
                CompressedModelRuntimeLane::GgufLlamaCpp | CompressedModelRuntimeLane::NoRuntime
            ) {
                return Err(CompressedModelSourceCardError::GgufLaneMismatch(
                    card.card_id.clone(),
                ));
            }
        }
        CompressedModelFormat::LiteRt => {
            if !matches!(
                card.runtime_lane,
                CompressedModelRuntimeLane::LiteRtLm | CompressedModelRuntimeLane::NoRuntime
            ) {
                return Err(CompressedModelSourceCardError::LiteRtLaneMismatch(
                    card.card_id.clone(),
                ));
            }
        }
        CompressedModelFormat::TurboVecIndex => {
            if card.runtime_lane != CompressedModelRuntimeLane::TurboVecEidosCache
                || !matches!(
                    card.organ,
                    CompressedModelOrgan::Eidos | CompressedModelOrgan::AppColdStore
                )
                || card.claim_limit == ModelInventoryClaimLimit::RequiresRuntimeWitness
            {
                return Err(CompressedModelSourceCardError::TurboVecNotEidosCache(
                    card.card_id.clone(),
                ));
            }
        }
        CompressedModelFormat::PackageManifest => {
            if card.claim_limit != ModelInventoryClaimLimit::DependencyProvenanceOnly {
                return Err(
                    CompressedModelSourceCardError::PackageManifestAsLoaderProof(
                        card.card_id.clone(),
                    ),
                );
            }
        }
        CompressedModelFormat::Mlx => {
            let model_id = card.model_or_package_id.to_ascii_lowercase();
            if model_id.contains("gemma-4") {
                let Some(caveat) = card.loader_caveat_ref.as_deref() else {
                    return Err(CompressedModelSourceCardError::MissingGemma4LoaderCaveat(
                        card.card_id.clone(),
                    ));
                };
                if !caveat.contains("loader_caveat:") {
                    return Err(CompressedModelSourceCardError::MlxGemma4LoaderClaim(
                        card.card_id.clone(),
                    ));
                }
            }
        }
        CompressedModelFormat::Safetensors | CompressedModelFormat::LocalCanon => {}
    }

    if matches!(
        card.claim_limit,
        ModelInventoryClaimLimit::RouteHintOnly | ModelInventoryClaimLimit::RequiresWrvWitness
    ) && card.runtime_lane != CompressedModelRuntimeLane::NoRuntime
        && card.route_caveat_ref.as_deref().is_some_and(|caveat| {
            caveat.contains("route_authority") || caveat.contains("live_route")
        })
    {
        return Err(CompressedModelSourceCardError::RuntimeRouteAuthority(
            card.card_id.clone(),
        ));
    }

    Ok(())
}

fn validate_byte_scope(
    card: &CompressedModelSourceCard,
) -> Result<(), CompressedModelSourceCardError> {
    if card.byte_scope.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(CompressedModelSourceCardError::MetadataBudgetExceeded);
    }
    if card.byte_scope.copied_product_file_count > 0 {
        return Err(CompressedModelSourceCardError::ProductFileCopied(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.weight_blob_open_attempted {
        return Err(CompressedModelSourceCardError::WeightBlobOpened(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.weight_blob_hash_attempted {
        return Err(CompressedModelSourceCardError::WeightBlobHashAttempted(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.model_bytes_loaded > 0 {
        return Err(CompressedModelSourceCardError::NonzeroModelBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.index_bytes_loaded > 0 {
        return Err(CompressedModelSourceCardError::NonzeroIndexBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.runtime_bytes_loaded > 0 {
        return Err(CompressedModelSourceCardError::NonzeroRuntimeBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.provider_calls_made > 0 {
        return Err(CompressedModelSourceCardError::ProviderCallMade(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    card_id: &str,
    proof_refs: &CompressedModelSourceProofRefs,
) -> Result<(), CompressedModelSourceCardError> {
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
            COMPATIBILITY_FENCE_PREFIX,
        ),
    ] {
        validate_nonempty(field, value).map_err(|_| {
            CompressedModelSourceCardError::MissingProofRef {
                card_id: card_id.to_string(),
                field,
            }
        })?;
        if !value.starts_with(prefix) {
            return Err(CompressedModelSourceCardError::BadProofRefPrefix {
                card_id: card_id.to_string(),
                field,
            });
        }
    }
    Ok(())
}

fn reject_forbidden_claims(
    card: &CompressedModelSourceCard,
) -> Result<(), CompressedModelSourceCardError> {
    let mut fields = vec![
        card.card_id.as_str(),
        card.source_id.as_str(),
        card.model_or_package_id.as_str(),
        card.license_ref.as_str(),
        card.source_locator.as_str(),
    ];
    fields.extend(card.model_inventory_candidate_ref.as_deref());
    fields.extend(card.provenance_overlay_ref.as_deref());
    fields.extend(card.quantization_ref.as_deref());
    fields.extend(card.context_window_ref.as_deref());
    fields.extend(card.loader_caveat_ref.as_deref());
    fields.extend(card.route_caveat_ref.as_deref());
    fields.push(card.proof_refs.falsifier_ref.as_str());
    fields.push(card.proof_refs.rollback_ref.as_str());
    fields.push(card.proof_refs.run_event_log_ref.as_str());
    fields.push(card.proof_refs.answer_packet_ref.as_str());
    fields.push(card.proof_refs.compatibility_fence_ref.as_str());

    for field in fields {
        let lower = field.to_ascii_lowercase();
        if lower.contains("rowid") {
            return Err(CompressedModelSourceCardError::RowIdIdentity(
                card.card_id.clone(),
            ));
        }
        if lower.contains("live-dense-70b") || lower.contains("dense-70b-live") {
            return Err(CompressedModelSourceCardError::Dense70BLiveClaim(
                card.card_id.clone(),
            ));
        }
        if lower.contains("ssd-as-ram") {
            return Err(CompressedModelSourceCardError::SsdAsRamClaim(
                card.card_id.clone(),
            ));
        }
        if lower.contains("hidden-cloud") || lower.contains("cloud-fallback-default") {
            return Err(CompressedModelSourceCardError::HiddenCloudFallback(
                card.card_id.clone(),
            ));
        }
        if lower.contains("hidden-route-authority")
            || lower.contains("default-live-router")
            || lower.contains("live-router-authority")
            || lower.contains("live_route_authority")
            || lower.contains("route_authority")
        {
            return Err(CompressedModelSourceCardError::HiddenRouteAuthority(
                card.card_id.clone(),
            ));
        }
        if lower.contains("product-green") || lower.contains("green-product") {
            return Err(CompressedModelSourceCardError::ProductGreenFromResearch(
                card.card_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_optional_text(
    field: &'static str,
    value: Option<&str>,
) -> Result<(), CompressedModelSourceCardError> {
    if let Some(value) = value {
        validate_nonempty(field, value)?;
    }
    Ok(())
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), CompressedModelSourceCardError> {
    if value.is_empty() {
        return Err(CompressedModelSourceCardError::MissingField(field));
    }
    if value.trim() != value {
        return Err(CompressedModelSourceCardError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(CompressedModelSourceCardError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn reject_rowid_identity(card_id: &str, value: &str) -> Result<(), CompressedModelSourceCardError> {
    let lower = value.to_ascii_lowercase();
    if lower.contains("rowid") {
        return Err(CompressedModelSourceCardError::RowIdIdentity(
            card_id.to_string(),
        ));
    }
    Ok(())
}

fn intake_address(
    graph_address: &UasAddress,
    inventory_address: &UasAddress,
    provenance_gate_address: &UasAddress,
    cards: &[CompressedModelSourceCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
    rowid_identity_blocked: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(COMPRESSED_MODEL_SOURCE_CARD_INTAKE_CURSOR);
    preimage.push('\n');
    preimage.push_str(&graph_address.to_string());
    preimage.push('\n');
    preimage.push_str(&inventory_address.to_string());
    preimage.push('\n');
    preimage.push_str(&provenance_gate_address.to_string());
    preimage.push('\n');
    preimage.push_str(product_build_preimage(product_build));
    preimage.push('\n');
    preimage.push_str(pro_status_preimage(pro_status));
    preimage.push('\n');
    preimage.push_str(&metadata_bytes.to_string());
    preimage.push('\n');
    preimage.push_str(if l1_l2_l3_separated { "l123" } else { "mixed" });
    preimage.push('\n');
    preimage.push_str(if route_authority_blocked {
        "route-blocked"
    } else {
        "route-open"
    });
    preimage.push('\n');
    preimage.push_str(if product_promotion_blocked {
        "promotion-blocked"
    } else {
        "promotion-open"
    });
    preimage.push('\n');
    preimage.push_str(if rowid_identity_blocked {
        "rowid-blocked"
    } else {
        "rowid-open"
    });
    preimage.push('\n');
    for card in cards {
        push_card_preimage(&mut preimage, card);
    }
    UasAddress::new(
        UasKind::Other(COMPRESSED_MODEL_SOURCE_CARD_INTAKE_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_card_preimage(preimage: &mut String, card: &CompressedModelSourceCard) {
    for field in [
        card.card_id.as_str(),
        card.source_id.as_str(),
        card.source_digest.as_str(),
        card.model_inventory_candidate_ref
            .as_deref()
            .unwrap_or("none"),
        card.provenance_overlay_ref.as_deref().unwrap_or("none"),
        card.model_or_package_id.as_str(),
        card.quantization_ref.as_deref().unwrap_or("none"),
        card.context_window_ref.as_deref().unwrap_or("none"),
        card.license_ref.as_str(),
        card.loader_caveat_ref.as_deref().unwrap_or("none"),
        card.route_caveat_ref.as_deref().unwrap_or("none"),
        card.source_locator.as_str(),
        card.proof_refs.falsifier_ref.as_str(),
        card.proof_refs.rollback_ref.as_str(),
        card.proof_refs.run_event_log_ref.as_str(),
        card.proof_refs.answer_packet_ref.as_str(),
        card.proof_refs.compatibility_fence_ref.as_str(),
    ] {
        preimage.push_str(field);
        preimage.push('\n');
    }
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{}|{}|{:?}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
        card.card_kind,
        card.format,
        card.runtime_lane,
        card.organ,
        card.import_mode,
        card.allowed_action,
        product_build_preimage(&card.product_build),
        pro_status_preimage(&card.pro_status),
        card.promotion_tier,
        card.claim_limit,
        card.byte_scope.metadata_bytes_read,
        card.byte_scope.sidecar_bytes_read,
        card.byte_scope.declared_artifact_bytes.unwrap_or(0),
        card.byte_scope
            .declared_runtime_memory_floor_bytes
            .unwrap_or(0),
        card.byte_scope.model_bytes_loaded,
        card.byte_scope.index_bytes_loaded,
        card.byte_scope.runtime_bytes_loaded,
        card.byte_scope.provider_calls_made,
        card.byte_scope.copied_product_file_count
    ));
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        ModelInventoryByteScope, ModelInventoryCandidateCard, ModelInventoryEvidenceKind,
        ModelInventoryHashClaim, ModelInventoryProofRefs, PrivacyClass,
        ProprietaryCompressionBehaviorKind, ProprietaryCompressionByteScope,
        ProprietaryCompressionExtractedBehavior, ProprietaryCompressionLicenseClass,
        ProprietaryCompressionProofRefs, ProprietaryCompressionSourceKind,
        ProprietaryCompressionSourceOverlay, SourceCard, SourceNoPoisonStatus, SourceSignalType,
    };

    const CREATED_AT_MS: u64 = 1_779_034_000_000;

    #[test]
    fn accepted_intake_is_order_stable_and_metadata_only() {
        let graph = graph();
        let inventory = inventory(&graph);
        let gate = provenance_gate(&graph, &inventory);
        let cards = cards(&graph);
        let intake = build(&graph, &inventory, &gate, cards.clone()).expect("valid intake");
        let reversed = build(&graph, &inventory, &gate, cards.into_iter().rev().collect())
            .expect("valid reversed intake");

        assert_eq!(intake.intake_address, reversed.intake_address);
        let metrics = intake.metrics();
        assert_eq!(metrics.card_count, 4);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.index_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.provider_calls_made, 0);
    }

    #[test]
    fn rejects_gemma4_mlx_without_loader_caveat() {
        let (graph, inventory, gate, mut cards) = fixture();
        let card = cards
            .iter_mut()
            .find(|card| card.card_id == "gemma4_mlx_loader_blocked")
            .expect("fixture card");
        card.loader_caveat_ref = None;

        let error = build(&graph, &inventory, &gate, cards).unwrap_err();

        assert!(matches!(
            error,
            CompressedModelSourceCardError::MissingGemma4LoaderCaveat(_)
        ));
    }

    #[test]
    fn rejects_turbovec_as_runtime_router_authority() {
        let (graph, inventory, gate, mut cards) = fixture();
        let card = cards
            .iter_mut()
            .find(|card| card.card_id == "turbovec_eidos_cache")
            .expect("fixture card");
        card.organ = CompressedModelOrgan::RuntimeRouter;

        let error = build(&graph, &inventory, &gate, cards).unwrap_err();

        assert!(matches!(
            error,
            CompressedModelSourceCardError::TurboVecNotEidosCache(_)
        ));
    }

    #[test]
    fn rejects_rowid_identity() {
        let (graph, inventory, gate, mut cards) = fixture();
        cards[0].source_locator = "sqlite:rowid:42".to_string();

        let error = build(&graph, &inventory, &gate, cards).unwrap_err();

        assert!(matches!(
            error,
            CompressedModelSourceCardError::RowIdIdentity(_)
        ));
    }

    #[test]
    fn rejects_inventory_source_mismatch() {
        let (graph, inventory, gate, mut cards) = fixture();
        cards[0].model_inventory_candidate_ref = Some("inventory:turbovec".to_string());

        let error = build(&graph, &inventory, &gate, cards).unwrap_err();

        assert!(matches!(
            error,
            CompressedModelSourceCardError::InventorySourceMismatch(_)
        ));
    }

    #[test]
    fn rejects_product_promotion() {
        let (graph, inventory, gate, mut cards) = fixture();
        cards[0].promotion_tier = CompressedModelPromotionTier::T4BuildGreen;

        let error = build(&graph, &inventory, &gate, cards).unwrap_err();

        assert!(matches!(
            error,
            CompressedModelSourceCardError::TierPromotionFromResearch(_)
        ));
    }

    fn fixture() -> (
        SourceSignalGraph,
        ModelInventoryCandidateSet,
        ProprietaryCompressionProvenanceGate,
        Vec<CompressedModelSourceCard>,
    ) {
        let graph = graph();
        let inventory = inventory(&graph);
        let gate = provenance_gate(&graph, &inventory);
        let cards = cards(&graph);
        (graph, inventory, gate, cards)
    }

    fn build(
        graph: &SourceSignalGraph,
        inventory: &ModelInventoryCandidateSet,
        gate: &ProprietaryCompressionProvenanceGate,
        cards: Vec<CompressedModelSourceCard>,
    ) -> Result<CompressedModelSourceCardIntake, CompressedModelSourceCardError> {
        CompressedModelSourceCardIntake::from_provenance(
            graph,
            inventory,
            gate,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            32_000,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn graph() -> SourceSignalGraph {
        SourceSignalGraph::intake(
            [
                "source:model:gemma4-12b-qat-gguf",
                "source:model:gemma4-mlx-preview",
                "source:index:turbovec",
                "source:runtime:llama-cpp",
            ]
            .into_iter()
            .map(|source_id| source_card(source_id, SourceNoPoisonStatus::Clear))
            .chain(std::iter::once(source_card(
                "source:blocked:bad-card",
                SourceNoPoisonStatus::Blocked,
            )))
            .collect::<Vec<_>>(),
            Vec::new(),
            CREATED_AT_MS,
        )
        .expect("source graph")
    }

    fn source_card(source_id: &str, no_poison_status: SourceNoPoisonStatus) -> SourceCard {
        SourceCard::new(
            source_id,
            SourceSignalType::Repo,
            format!("fixture://{source_id}"),
            digest(source_id),
            1,
            "fixture source card; source prior only",
            PrivacyClass::PublicResearch,
            no_poison_status,
            vec!["compressed_model_source_card".to_string()],
        )
        .expect("source card")
    }

    fn inventory(graph: &SourceSignalGraph) -> ModelInventoryCandidateSet {
        ModelInventoryCandidateSet::from_source_graph(
            graph,
            vec![
                inventory_card(
                    graph,
                    "inventory:gemma4-12b-gguf",
                    "source:model:gemma4-12b-qat-gguf",
                    "google/gemma-4-12B-it-qat-q4_0-gguf",
                ),
                inventory_card(
                    graph,
                    "inventory:gemma4-mlx-preview",
                    "source:model:gemma4-mlx-preview",
                    "mlx-community/gemma-4-12B-it-qat-4bit",
                ),
                inventory_card(
                    graph,
                    "inventory:turbovec",
                    "source:index:turbovec",
                    "RyanCodrai/turbovec",
                ),
                inventory_card(
                    graph,
                    "inventory:llama-cpp",
                    "source:runtime:llama-cpp",
                    "ggerganov/llama.cpp",
                ),
            ],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            24_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect("inventory")
    }

    fn inventory_card(
        graph: &SourceSignalGraph,
        candidate_id: &str,
        source_id: &str,
        model_or_package_id: &str,
    ) -> ModelInventoryCandidateCard {
        ModelInventoryCandidateCard {
            candidate_id: candidate_id.to_string(),
            source_id: source_id.to_string(),
            source_digest: digest_for(graph, source_id),
            model_or_package_id: model_or_package_id.to_string(),
            evidence_kind: ModelInventoryEvidenceKind::PackageManifest,
            metadata_status: ModelInventoryMetadataStatus::DependencyProvenanceOnly,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            claim_limit: ModelInventoryClaimLimit::DependencyProvenanceOnly,
            evidence_locator: format!("fixture://{source_id}/package"),
            revision_ref: None,
            hash_claim: ModelInventoryHashClaim::None,
            loader_caveat_ref: None,
            route_hint_ref: None,
            sidecar_policy: None,
            byte_scope: ModelInventoryByteScope::metadata_only(512, 0),
            proof_refs: ModelInventoryProofRefs {
                falsifier_ref: format!("falsifier:inventory:{candidate_id}"),
                rollback_ref: format!("rollback:inventory:{candidate_id}"),
                run_event_log_ref: format!("run_event_log:inventory:{candidate_id}"),
                answer_packet_ref: format!("answer_packet:inventory:{candidate_id}"),
                compatibility_fence_ref: format!("compat:inventory:{candidate_id}"),
            },
            source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
        }
    }

    fn provenance_gate(
        graph: &SourceSignalGraph,
        inventory: &ModelInventoryCandidateSet,
    ) -> ProprietaryCompressionProvenanceGate {
        ProprietaryCompressionProvenanceGate::from_sources(
            graph,
            inventory,
            vec![
                overlay(
                    graph,
                    "overlay:gemma4-12b-gguf",
                    "source:model:gemma4-12b-qat-gguf",
                    Some("inventory:gemma4-12b-gguf"),
                    ProprietaryCompressionSourceKind::ModelCard,
                    ProprietaryCompressionImportMode::ResearchOnly,
                    ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                ),
                overlay(
                    graph,
                    "overlay:gemma4-mlx-preview",
                    "source:model:gemma4-mlx-preview",
                    Some("inventory:gemma4-mlx-preview"),
                    ProprietaryCompressionSourceKind::ModelCard,
                    ProprietaryCompressionImportMode::ResearchOnly,
                    ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                ),
                overlay(
                    graph,
                    "overlay:turbovec",
                    "source:index:turbovec",
                    Some("inventory:turbovec"),
                    ProprietaryCompressionSourceKind::Repo,
                    ProprietaryCompressionImportMode::AdapterWrap,
                    ProprietaryCompressionAllowedAction::AdapterOnly,
                ),
                overlay(
                    graph,
                    "overlay:llama-cpp",
                    "source:runtime:llama-cpp",
                    Some("inventory:llama-cpp"),
                    ProprietaryCompressionSourceKind::RuntimePackage,
                    ProprietaryCompressionImportMode::ResearchOnly,
                    ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                ),
            ],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            32_000,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect("provenance gate")
    }

    fn overlay(
        graph: &SourceSignalGraph,
        overlay_id: &str,
        source_id: &str,
        model_inventory_candidate_ref: Option<&str>,
        source_kind: ProprietaryCompressionSourceKind,
        import_mode: ProprietaryCompressionImportMode,
        allowed_action: ProprietaryCompressionAllowedAction,
    ) -> ProprietaryCompressionSourceOverlay {
        ProprietaryCompressionSourceOverlay {
            overlay_id: overlay_id.to_string(),
            source_id: source_id.to_string(),
            source_digest: digest_for(graph, source_id),
            source_kind,
            source_locator: format!("fixture://{source_id}"),
            observed_at_utc: "2026-06-06T00:00:00Z".to_string(),
            license_class: ProprietaryCompressionLicenseClass::Permissive,
            import_mode,
            allowed_action,
            dependency_count: 1,
            transitive_unknown_dependency_count: 0,
            benchmark_claim_count: 0,
            extracted_behaviors: vec![ProprietaryCompressionExtractedBehavior {
                behavior_id: format!("behavior:{overlay_id}"),
                kind: ProprietaryCompressionBehaviorKind::ApiShape,
                summary_ref: format!("summary:{overlay_id}"),
                evidence_ref: format!("evidence:{overlay_id}"),
                uses_verbatim_code: false,
            }],
            local_test_plan_ref: Some(format!("local_test_plan:{overlay_id}")),
            quarantine_ref: None,
            clean_room_note_ref: None,
            attribution_ref: Some(format!("attribution:{overlay_id}")),
            model_inventory_candidate_ref: model_inventory_candidate_ref.map(str::to_string),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            byte_scope: ProprietaryCompressionByteScope::metadata_only(1_024, 0),
            proof_refs: ProprietaryCompressionProofRefs {
                falsifier_ref: format!("falsifier:provenance:{overlay_id}"),
                rollback_ref: format!("rollback:provenance:{overlay_id}"),
                run_event_log_ref: format!("run_event_log:provenance:{overlay_id}"),
                answer_packet_ref: format!("answer_packet:provenance:{overlay_id}"),
                compatibility_fence_ref: format!("compat:provenance:{overlay_id}"),
            },
        }
    }

    fn cards(graph: &SourceSignalGraph) -> Vec<CompressedModelSourceCard> {
        vec![
            card(
                graph,
                "gemma4_12b_qat_gguf",
                "source:model:gemma4-12b-qat-gguf",
                Some("inventory:gemma4-12b-gguf"),
                Some("overlay:gemma4-12b-gguf"),
                "google/gemma-4-12B-it-qat-q4_0-gguf",
                CompressedModelSourceCardKind::QuantizedModel,
                CompressedModelFormat::Gguf,
                CompressedModelRuntimeLane::GgufLlamaCpp,
                CompressedModelOrgan::ActiveAssembly,
                Some("qat:q4_0"),
                None,
                Some("route_caveat:gguf-runtime-unproven"),
                ProprietaryCompressionImportMode::ResearchOnly,
                ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            ),
            card(
                graph,
                "gemma4_mlx_loader_blocked",
                "source:model:gemma4-mlx-preview",
                Some("inventory:gemma4-mlx-preview"),
                Some("overlay:gemma4-mlx-preview"),
                "mlx-community/gemma-4-12B-it-qat-4bit",
                CompressedModelSourceCardKind::QuantizedModel,
                CompressedModelFormat::Mlx,
                CompressedModelRuntimeLane::MlxSwift,
                CompressedModelOrgan::RuntimeRouter,
                Some("qat:4bit"),
                Some("loader_caveat:swift-mlx-gemma4-preview-blocked"),
                Some("route_caveat:mlx-gemma4-loader-blocked"),
                ProprietaryCompressionImportMode::ResearchOnly,
                ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            ),
            card(
                graph,
                "turbovec_eidos_cache",
                "source:index:turbovec",
                Some("inventory:turbovec"),
                Some("overlay:turbovec"),
                "RyanCodrai/turbovec",
                CompressedModelSourceCardKind::CompressedIndex,
                CompressedModelFormat::TurboVecIndex,
                CompressedModelRuntimeLane::TurboVecEidosCache,
                CompressedModelOrgan::Eidos,
                Some("vector:q4"),
                None,
                Some("route_caveat:eidos-cache-prior-only"),
                ProprietaryCompressionImportMode::AdapterWrap,
                ProprietaryCompressionAllowedAction::AdapterOnly,
            ),
            card(
                graph,
                "llama_cpp_runtime_package",
                "source:runtime:llama-cpp",
                Some("inventory:llama-cpp"),
                Some("overlay:llama-cpp"),
                "ggerganov/llama.cpp",
                CompressedModelSourceCardKind::RuntimePackage,
                CompressedModelFormat::PackageManifest,
                CompressedModelRuntimeLane::GgufLlamaCpp,
                CompressedModelOrgan::RuntimeRouter,
                None,
                None,
                Some("route_caveat:runtime-package-not-loader-proof"),
                ProprietaryCompressionImportMode::ResearchOnly,
                ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            ),
        ]
    }

    #[allow(clippy::too_many_arguments)]
    fn card(
        graph: &SourceSignalGraph,
        card_id: &str,
        source_id: &str,
        model_inventory_candidate_ref: Option<&str>,
        provenance_overlay_ref: Option<&str>,
        model_or_package_id: &str,
        card_kind: CompressedModelSourceCardKind,
        format: CompressedModelFormat,
        runtime_lane: CompressedModelRuntimeLane,
        organ: CompressedModelOrgan,
        quantization_ref: Option<&str>,
        loader_caveat_ref: Option<&str>,
        route_caveat_ref: Option<&str>,
        import_mode: ProprietaryCompressionImportMode,
        allowed_action: ProprietaryCompressionAllowedAction,
    ) -> CompressedModelSourceCard {
        CompressedModelSourceCard {
            card_id: card_id.to_string(),
            source_id: source_id.to_string(),
            source_digest: digest_for(graph, source_id),
            model_inventory_candidate_ref: model_inventory_candidate_ref.map(str::to_string),
            provenance_overlay_ref: provenance_overlay_ref.map(str::to_string),
            model_or_package_id: model_or_package_id.to_string(),
            card_kind,
            format,
            runtime_lane,
            organ,
            quantization_ref: quantization_ref.map(str::to_string),
            context_window_ref: Some("context_window:source-card-only".to_string()),
            license_ref: "license:source-card-fixture".to_string(),
            loader_caveat_ref: loader_caveat_ref.map(str::to_string),
            route_caveat_ref: route_caveat_ref.map(str::to_string),
            source_locator: format!("fixture://{source_id}"),
            import_mode,
            allowed_action,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            claim_limit: match card_kind {
                CompressedModelSourceCardKind::RuntimePackage => {
                    ModelInventoryClaimLimit::DependencyProvenanceOnly
                }
                CompressedModelSourceCardKind::CompressedIndex => {
                    ModelInventoryClaimLimit::RequiresByteWitness
                }
                _ => ModelInventoryClaimLimit::RequiresRuntimeWitness,
            },
            metadata_status: ModelInventoryMetadataStatus::DependencyProvenanceOnly,
            byte_scope: CompressedModelSourceByteScope::metadata_only(
                1_024,
                0,
                Some(256 * 1024 * 1024),
                Some(512 * 1024 * 1024),
            ),
            proof_refs: CompressedModelSourceProofRefs {
                falsifier_ref: format!("falsifier:compressed-model:{card_id}"),
                rollback_ref: format!("rollback:compressed-model:{card_id}"),
                run_event_log_ref: format!("run_event_log:compressed-model:{card_id}"),
                answer_packet_ref: format!("answer_packet:compressed-model:{card_id}"),
                compatibility_fence_ref: format!("compat:compressed-model:{card_id}"),
            },
        }
    }

    fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
        graph
            .source_cards
            .iter()
            .find(|card| card.source_id == source_id)
            .map(|card| card.digest.clone())
            .expect("source present")
    }

    fn digest(input: &str) -> String {
        format!("blake3:{}", blake3::hash(input.as_bytes()).to_hex())
    }
}
