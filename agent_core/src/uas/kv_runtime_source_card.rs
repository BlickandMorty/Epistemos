//! KV runtime source-card intake.
//!
//! This primitive source-cards KV/page/offload/cache runtime ideas before they
//! can influence `RuntimeRouter` / System G. It is metadata-only: no model,
//! KV, index, runtime, provider, server, daemon, or prompt-cache bytes are
//! opened here.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{
    CompressedModelPromotionTier, ProStatus, ProductBuild, ProprietaryCompressionAllowedAction,
    ProprietaryCompressionImportMode, SourceSignalGraph, UasAddress, UasKind,
};

pub const KV_RUNTIME_SOURCE_CARD_CURSOR: &str = "kv_runtime_source_card";
pub const KV_RUNTIME_SOURCE_CARD_NEXT_CURSOR: &str = "kv_source_card_fork_and_daemon_boundary";

const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const PRIVACY_POLICY_PREFIX: &str = "privacy:";
const QUALITY_CAVEAT_PREFIX: &str = "quality:";
const MAS_PRO_BOUNDARY_PREFIX: &str = "mas_pro:";
const COMPRESSED_MODEL_INTAKE_PREFIX: &str = "compressed_model_source_card_intake:";
const MAX_SET_METADATA_BYTES: u64 = 768 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:kv-runtime-source-card:mechanism
// Plane: Assembly + Controller
// Residency: source-carded cache/offload mechanism; no live authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvRuntimeMechanism {
    VirtualBlockTable,
    PrefixTreeReuse,
    HierarchicalKvCache,
    KvQuantization,
    HeterogeneousPlacement,
    OffloadPolicyOptimizer,
    ActivationLocality,
    PromptCacheFile,
}

// UAS: uas:kv-runtime-source-card:runtime-shape
// Plane: Controller
// Residency: shape of the upstream project; not an Epistemos route claim.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvRuntimeShape {
    InProcessLibrary,
    CliCommand,
    ServerFramework,
    DaemonCacheLayer,
    DistributedCluster,
    PythonRuntime,
    CppRuntime,
    SwiftPackage,
    MetadataOnly,
}

// UAS: uas:kv-runtime-source-card:deployment-shape
// Plane: Controller + Verification
// Residency: promotion boundary for the source motif.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvDefaultDeploymentShape {
    ProductEligibleInProcess,
    ProGatedCommand,
    ProResearchServer,
    ProResearchDaemon,
    ProVaultDistributed,
    ResearchOnly,
}

// UAS: uas:kv-runtime-source-card:storage-tier
// Plane: State + Assembly
// Residency: declared storage tier; remote tiers are source-only here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvRuntimeStorageTier {
    GpuMemory,
    AppleUmaMemory,
    CpuMemory,
    LocalSsd,
    RemoteObjectStore,
    DistributedKvStore,
    PromptCacheFile,
    None,
}

// UAS: uas:kv-runtime-source-card:apple-silicon-status
// Plane: Verification
// Residency: Apple-local evidence state; non-Apple evidence cannot promote.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvAppleSiliconStatus {
    Unsupported,
    SourceOnly,
    RequiresLocalWitness,
    SupportedByLocalWitness,
}

// UAS: uas:kv-runtime-source-card:mas-status
// Plane: Verification
// Residency: MAS boundary for server/daemon/subprocess/remote assumptions.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvMasStatus {
    DeniedServerOrDaemon,
    DeniedRemoteStorage,
    RequiresBoundaryReview,
    MasEligibleMetadataOnly,
}

// UAS: uas:kv-runtime-source-card:byte-scope
// Plane: Verification
// Residency: metadata-only source-card accounting.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvRuntimeByteScope {
    pub metadata_bytes_read: u64,
    pub source_tree_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
}

impl KvRuntimeByteScope {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            source_tree_bytes_read: 0,
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            product_files_copied: 0,
        }
    }
}

// UAS: uas:kv-runtime-source-card:proof-refs
// Plane: Verification
// Residency: visible proof handles before downstream route influence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvRuntimeProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_policy_ref: String,
    pub quality_caveat_ref: String,
    pub mas_pro_boundary_ref: String,
}

// UAS: uas:kv-runtime-source-card:card
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only source card for KV/runtime motifs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvRuntimeSourceCard {
    pub card_id: String,
    pub source_id: String,
    pub source_digest: String,
    pub compressed_model_source_card_ref: Option<String>,
    pub project_ref: String,
    pub mechanism: KvRuntimeMechanism,
    pub runtime_shape: KvRuntimeShape,
    pub default_deployment_shape: KvDefaultDeploymentShape,
    pub storage_tiers: Vec<KvRuntimeStorageTier>,
    pub cache_identity_fields: Vec<String>,
    pub compatibility_fields: Vec<String>,
    pub byte_ledger_fields: Vec<String>,
    pub cache_policy_fields: Vec<String>,
    pub quality_caveat_ref: String,
    pub server_daemon_boundary: String,
    pub remote_storage_boundary: String,
    pub apple_silicon_status: KvAppleSiliconStatus,
    pub mas_status: KvMasStatus,
    pub import_mode: ProprietaryCompressionImportMode,
    pub allowed_action: ProprietaryCompressionAllowedAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub proof_refs: KvRuntimeProofRefs,
    pub byte_scope: KvRuntimeByteScope,
    pub hidden_route_authority: bool,
    pub hidden_cache_authority: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub l2_l3_promotion_claim: bool,
}

// UAS: uas:kv-runtime-source-card:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only card set; feeds narrower KV/offload gates.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvRuntimeSourceCardSet {
    pub set_address: UasAddress,
    pub source_graph_address: UasAddress,
    pub compressed_model_source_card_intake_ref: String,
    pub cards: Vec<KvRuntimeSourceCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub server_daemon_product_blocked: bool,
    pub remote_storage_product_blocked: bool,
    pub hidden_authority_blocked: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:kv-runtime-source-card:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvRuntimeSourceCardMetrics {
    pub card_count: u64,
    pub mechanism_count: u64,
    pub runtime_shape_count: u64,
    pub deployment_shape_count: u64,
    pub storage_tier_count: u64,
    pub server_framework_count: u64,
    pub daemon_cache_layer_count: u64,
    pub distributed_cluster_count: u64,
    pub remote_storage_source_count: u64,
    pub local_only_source_count: u64,
    pub kv_quantization_source_count: u64,
    pub offload_policy_source_count: u64,
    pub activation_locality_source_count: u64,
    pub prompt_cache_source_count: u64,
    pub compatibility_fence_ref_count: u64,
    pub quality_caveat_ref_count: u64,
    pub mas_pro_boundary_ref_count: u64,
    pub metadata_bytes_read: u64,
    pub source_tree_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
}

impl KvRuntimeSourceCardSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_source_graph(
        graph: &SourceSignalGraph,
        compressed_model_source_card_intake_ref: impl Into<String>,
        mut cards: Vec<KvRuntimeSourceCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        server_daemon_product_blocked: bool,
        remote_storage_product_blocked: bool,
        hidden_authority_blocked: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, KvRuntimeSourceCardError> {
        let compressed_model_source_card_intake_ref =
            compressed_model_source_card_intake_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        validate_set_inputs(
            graph,
            &compressed_model_source_card_intake_ref,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            server_daemon_product_blocked,
            remote_storage_product_blocked,
            hidden_authority_blocked,
            product_promotion_blocked,
        )?;
        let set_address = set_address(
            &graph.graph_address,
            &compressed_model_source_card_intake_ref,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            server_daemon_product_blocked,
            remote_storage_product_blocked,
            hidden_authority_blocked,
            product_promotion_blocked,
            created_at_ms,
        );
        Ok(Self {
            set_address,
            source_graph_address: graph.graph_address.clone(),
            compressed_model_source_card_intake_ref,
            cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            server_daemon_product_blocked,
            remote_storage_product_blocked,
            hidden_authority_blocked,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> KvRuntimeSourceCardMetrics {
        let mut mechanisms = BTreeSet::new();
        let mut runtime_shapes = BTreeSet::new();
        let mut deployment_shapes = BTreeSet::new();
        let mut storage_tiers = BTreeSet::new();
        for card in &self.cards {
            mechanisms.insert(card.mechanism);
            runtime_shapes.insert(card.runtime_shape);
            deployment_shapes.insert(card.default_deployment_shape);
            for tier in &card.storage_tiers {
                storage_tiers.insert(*tier);
            }
        }

        KvRuntimeSourceCardMetrics {
            card_count: self.cards.len() as u64,
            mechanism_count: mechanisms.len() as u64,
            runtime_shape_count: runtime_shapes.len() as u64,
            deployment_shape_count: deployment_shapes.len() as u64,
            storage_tier_count: storage_tiers.len() as u64,
            server_framework_count: self
                .cards
                .iter()
                .filter(|card| card.runtime_shape == KvRuntimeShape::ServerFramework)
                .count() as u64,
            daemon_cache_layer_count: self
                .cards
                .iter()
                .filter(|card| card.runtime_shape == KvRuntimeShape::DaemonCacheLayer)
                .count() as u64,
            distributed_cluster_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.runtime_shape == KvRuntimeShape::DistributedCluster
                        || card.default_deployment_shape
                            == KvDefaultDeploymentShape::ProVaultDistributed
                })
                .count() as u64,
            remote_storage_source_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.storage_tiers.iter().any(|tier| {
                        matches!(
                            tier,
                            KvRuntimeStorageTier::RemoteObjectStore
                                | KvRuntimeStorageTier::DistributedKvStore
                        )
                    })
                })
                .count() as u64,
            local_only_source_count: self
                .cards
                .iter()
                .filter(|card| {
                    !card.storage_tiers.iter().any(|tier| {
                        matches!(
                            tier,
                            KvRuntimeStorageTier::RemoteObjectStore
                                | KvRuntimeStorageTier::DistributedKvStore
                        )
                    })
                })
                .count() as u64,
            kv_quantization_source_count: self
                .cards
                .iter()
                .filter(|card| card.mechanism == KvRuntimeMechanism::KvQuantization)
                .count() as u64,
            offload_policy_source_count: self
                .cards
                .iter()
                .filter(|card| card.mechanism == KvRuntimeMechanism::OffloadPolicyOptimizer)
                .count() as u64,
            activation_locality_source_count: self
                .cards
                .iter()
                .filter(|card| card.mechanism == KvRuntimeMechanism::ActivationLocality)
                .count() as u64,
            prompt_cache_source_count: self
                .cards
                .iter()
                .filter(|card| card.mechanism == KvRuntimeMechanism::PromptCacheFile)
                .count() as u64,
            compatibility_fence_ref_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.proof_refs
                        .compatibility_fence_ref
                        .starts_with(COMPATIBILITY_FENCE_PREFIX)
                })
                .count() as u64,
            quality_caveat_ref_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.quality_caveat_ref.starts_with(QUALITY_CAVEAT_PREFIX)
                        && card
                            .proof_refs
                            .quality_caveat_ref
                            .starts_with(QUALITY_CAVEAT_PREFIX)
                })
                .count() as u64,
            mas_pro_boundary_ref_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.proof_refs
                        .mas_pro_boundary_ref
                        .starts_with(MAS_PRO_BOUNDARY_PREFIX)
                })
                .count() as u64,
            metadata_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.metadata_bytes_read)
                .sum(),
            source_tree_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_scope.source_tree_bytes_read)
                .sum(),
            model_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_scope.model_bytes_loaded)
                .sum(),
            kv_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_scope.kv_bytes_loaded)
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
            product_files_copied: self
                .cards
                .iter()
                .map(|card| card.byte_scope.product_files_copied)
                .sum(),
        }
    }

    pub fn address(&self) -> String {
        self.set_address.to_string()
    }
}

// UAS: uas:kv-runtime-source-card:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy for KV runtime source cards.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KvRuntimeSourceCardError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyCardSet,
    BadCompressedModelSourceCardIntakeRef,
    UnknownSourceId(String),
    BlockedSourceId(String),
    SourceDigestMismatch(String),
    DuplicateCardId(String),
    DuplicateSourceId(String),
    MissingCompressedModelSourceCardRef(String),
    BadProofRefPrefix {
        card_id: String,
        field: &'static str,
    },
    MissingCacheIdentity(String),
    MissingCompatibilityField(String),
    MissingByteLedger(String),
    MissingCachePolicy(String),
    MissingQualityCaveat(String),
    MissingServerDaemonBoundary(String),
    MissingRemoteStorageBoundary(String),
    ServerAsProduct(String),
    DaemonAsProduct(String),
    RemoteStorageAsLocal(String),
    PromptCacheCompatibilityGap(String),
    KvQuantizationCaveatGap(String),
    OffloadLatencyThroughputGap(String),
    ActivationLocalityFallbackGap(String),
    UnsupportedApplePromotion(String),
    MasLiveFromServerDaemon(String),
    HiddenRouteAuthority(String),
    HiddenCacheAuthority(String),
    NonzeroModelBytes(String),
    NonzeroKvBytes(String),
    NonzeroIndexBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    SourceTreeBytesImported(String),
    ProductFileCopied(String),
    LiveDense70BClaim(String),
    SsdAsRamClaim(String),
    ProductPromotionFromResearch(String),
    MissingLayerSeparation,
    MetadataBudgetExceeded,
}

impl fmt::Display for KvRuntimeSourceCardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyCardSet => write!(f, "missing KV runtime source cards"),
            Self::BadCompressedModelSourceCardIntakeRef => {
                write!(f, "bad compressed model source-card intake ref")
            }
            Self::UnknownSourceId(id) => write!(f, "unknown source id `{id}`"),
            Self::BlockedSourceId(id) => write!(f, "blocked source id `{id}`"),
            Self::SourceDigestMismatch(id) => write!(f, "source digest mismatch for `{id}`"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id `{id}`"),
            Self::DuplicateSourceId(id) => write!(f, "duplicate source id `{id}`"),
            Self::MissingCompressedModelSourceCardRef(id) => {
                write!(f, "card `{id}` missing compressed model source-card ref")
            }
            Self::BadProofRefPrefix { card_id, field } => {
                write!(f, "card `{card_id}` has bad proof ref prefix `{field}`")
            }
            Self::MissingCacheIdentity(id) => write!(f, "card `{id}` missing cache identity"),
            Self::MissingCompatibilityField(id) => {
                write!(f, "card `{id}` missing compatibility field")
            }
            Self::MissingByteLedger(id) => write!(f, "card `{id}` missing byte ledger"),
            Self::MissingCachePolicy(id) => write!(f, "card `{id}` missing cache policy"),
            Self::MissingQualityCaveat(id) => write!(f, "card `{id}` missing quality caveat"),
            Self::MissingServerDaemonBoundary(id) => {
                write!(f, "card `{id}` missing server/daemon boundary")
            }
            Self::MissingRemoteStorageBoundary(id) => {
                write!(f, "card `{id}` missing remote-storage boundary")
            }
            Self::ServerAsProduct(id) => write!(f, "card `{id}` laundered server as product"),
            Self::DaemonAsProduct(id) => write!(f, "card `{id}` laundered daemon as product"),
            Self::RemoteStorageAsLocal(id) => write!(f, "card `{id}` treated remote as local"),
            Self::PromptCacheCompatibilityGap(id) => {
                write!(f, "card `{id}` has prompt-cache compatibility gap")
            }
            Self::KvQuantizationCaveatGap(id) => {
                write!(f, "card `{id}` has KV quantization caveat gap")
            }
            Self::OffloadLatencyThroughputGap(id) => {
                write!(f, "card `{id}` lacks latency/throughput boundary")
            }
            Self::ActivationLocalityFallbackGap(id) => {
                write!(f, "card `{id}` lacks activation-locality fallback")
            }
            Self::UnsupportedApplePromotion(id) => {
                write!(f, "card `{id}` promoted unsupported Apple status")
            }
            Self::MasLiveFromServerDaemon(id) => {
                write!(f, "card `{id}` leaked server/daemon into MAS")
            }
            Self::HiddenRouteAuthority(id) => write!(f, "card `{id}` hid route authority"),
            Self::HiddenCacheAuthority(id) => write!(f, "card `{id}` hid cache authority"),
            Self::NonzeroModelBytes(id) => write!(f, "card `{id}` loaded model bytes"),
            Self::NonzeroKvBytes(id) => write!(f, "card `{id}` loaded KV bytes"),
            Self::NonzeroIndexBytes(id) => write!(f, "card `{id}` loaded index bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "card `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "card `{id}` made provider calls"),
            Self::SourceTreeBytesImported(id) => write!(f, "card `{id}` imported source bytes"),
            Self::ProductFileCopied(id) => write!(f, "card `{id}` copied product files"),
            Self::LiveDense70BClaim(id) => write!(f, "card `{id}` claimed live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "card `{id}` claimed SSD as RAM"),
            Self::ProductPromotionFromResearch(id) => {
                write!(f, "card `{id}` promoted research to product")
            }
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for KvRuntimeSourceCardError {}

fn validate_set_inputs(
    graph: &SourceSignalGraph,
    compressed_model_source_card_intake_ref: &str,
    cards: &[KvRuntimeSourceCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    server_daemon_product_blocked: bool,
    remote_storage_product_blocked: bool,
    hidden_authority_blocked: bool,
    product_promotion_blocked: bool,
) -> Result<(), KvRuntimeSourceCardError> {
    if cards.is_empty() {
        return Err(KvRuntimeSourceCardError::EmptyCardSet);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(KvRuntimeSourceCardError::MetadataBudgetExceeded);
    }
    if !compressed_model_source_card_intake_ref.starts_with(COMPRESSED_MODEL_INTAKE_PREFIX) {
        return Err(KvRuntimeSourceCardError::BadCompressedModelSourceCardIntakeRef);
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(KvRuntimeSourceCardError::ProductPromotionFromResearch(
            "set".to_string(),
        ));
    }
    if !l1_l2_l3_separated
        || !server_daemon_product_blocked
        || !remote_storage_product_blocked
        || !hidden_authority_blocked
        || !product_promotion_blocked
    {
        return Err(KvRuntimeSourceCardError::MissingLayerSeparation);
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

    let mut card_ids = HashSet::new();
    let mut source_ids = HashSet::new();
    for card in cards {
        validate_card_common(card)?;
        if !card_ids.insert(card.card_id.clone()) {
            return Err(KvRuntimeSourceCardError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !source_ids.insert(card.source_id.clone()) {
            return Err(KvRuntimeSourceCardError::DuplicateSourceId(
                card.source_id.clone(),
            ));
        }
        if rejected_sources.contains(card.source_id.as_str()) {
            return Err(KvRuntimeSourceCardError::BlockedSourceId(
                card.source_id.clone(),
            ));
        }
        let Some(expected_digest) = accepted_sources.get(card.source_id.as_str()) else {
            return Err(KvRuntimeSourceCardError::UnknownSourceId(
                card.source_id.clone(),
            ));
        };
        if *expected_digest != card.source_digest {
            return Err(KvRuntimeSourceCardError::SourceDigestMismatch(
                card.source_id.clone(),
            ));
        }
        validate_card_shape(card)?;
        validate_byte_scope(card)?;
        reject_forbidden_claims(card)?;
    }
    Ok(())
}

fn validate_card_common(card: &KvRuntimeSourceCard) -> Result<(), KvRuntimeSourceCardError> {
    for (field, value) in [
        ("card_id", card.card_id.as_str()),
        ("source_id", card.source_id.as_str()),
        ("source_digest", card.source_digest.as_str()),
        ("project_ref", card.project_ref.as_str()),
        ("quality_caveat_ref", card.quality_caveat_ref.as_str()),
        (
            "server_daemon_boundary",
            card.server_daemon_boundary.as_str(),
        ),
        (
            "remote_storage_boundary",
            card.remote_storage_boundary.as_str(),
        ),
    ] {
        validate_nonempty(field, value)?;
    }
    validate_optional_text(
        "compressed_model_source_card_ref",
        card.compressed_model_source_card_ref.as_deref(),
    )?;
    validate_string_vec("cache_identity_fields", &card.cache_identity_fields)?;
    validate_string_vec("compatibility_fields", &card.compatibility_fields)?;
    validate_string_vec("byte_ledger_fields", &card.byte_ledger_fields)?;
    validate_string_vec("cache_policy_fields", &card.cache_policy_fields)?;
    if card.storage_tiers.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingByteLedger(
            card.card_id.clone(),
        ));
    }
    if !matches!(
        card.promotion_tier,
        CompressedModelPromotionTier::T0Research | CompressedModelPromotionTier::T1L1Metadata
    ) || card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
    {
        return Err(KvRuntimeSourceCardError::ProductPromotionFromResearch(
            card.card_id.clone(),
        ));
    }
    validate_proof_refs(&card.card_id, &card.proof_refs)?;
    Ok(())
}

fn validate_card_shape(card: &KvRuntimeSourceCard) -> Result<(), KvRuntimeSourceCardError> {
    if card.compressed_model_source_card_ref.is_none() {
        return Err(
            KvRuntimeSourceCardError::MissingCompressedModelSourceCardRef(card.card_id.clone()),
        );
    }
    if card.cache_identity_fields.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingCacheIdentity(
            card.card_id.clone(),
        ));
    }
    if card.compatibility_fields.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingCompatibilityField(
            card.card_id.clone(),
        ));
    }
    if card.byte_ledger_fields.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingByteLedger(
            card.card_id.clone(),
        ));
    }
    if card.cache_policy_fields.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingCachePolicy(
            card.card_id.clone(),
        ));
    }
    if !card.quality_caveat_ref.starts_with(QUALITY_CAVEAT_PREFIX) {
        return Err(KvRuntimeSourceCardError::MissingQualityCaveat(
            card.card_id.clone(),
        ));
    }
    if !card.server_daemon_boundary.starts_with("boundary:") {
        return Err(KvRuntimeSourceCardError::MissingServerDaemonBoundary(
            card.card_id.clone(),
        ));
    }
    if !card.remote_storage_boundary.starts_with("boundary:") {
        return Err(KvRuntimeSourceCardError::MissingRemoteStorageBoundary(
            card.card_id.clone(),
        ));
    }
    if matches!(
        card.runtime_shape,
        KvRuntimeShape::ServerFramework | KvRuntimeShape::DistributedCluster
    ) && matches!(
        card.default_deployment_shape,
        KvDefaultDeploymentShape::ProductEligibleInProcess
            | KvDefaultDeploymentShape::ProGatedCommand
    ) {
        return Err(KvRuntimeSourceCardError::ServerAsProduct(
            card.card_id.clone(),
        ));
    }
    if card.runtime_shape == KvRuntimeShape::DaemonCacheLayer
        && matches!(
            card.default_deployment_shape,
            KvDefaultDeploymentShape::ProductEligibleInProcess
                | KvDefaultDeploymentShape::ProGatedCommand
        )
    {
        return Err(KvRuntimeSourceCardError::DaemonAsProduct(
            card.card_id.clone(),
        ));
    }
    let has_remote_storage = card.storage_tiers.iter().any(|tier| {
        matches!(
            tier,
            KvRuntimeStorageTier::RemoteObjectStore | KvRuntimeStorageTier::DistributedKvStore
        )
    });
    if has_remote_storage
        && matches!(
            card.default_deployment_shape,
            KvDefaultDeploymentShape::ProductEligibleInProcess
                | KvDefaultDeploymentShape::ProGatedCommand
        )
    {
        return Err(KvRuntimeSourceCardError::RemoteStorageAsLocal(
            card.card_id.clone(),
        ));
    }
    if card.mechanism == KvRuntimeMechanism::PromptCacheFile {
        require_fields(
            &card.compatibility_fields,
            &[
                "model_id",
                "tokenizer_id",
                "prompt_digest",
                "context_window",
                "mode_compatibility",
            ],
            || KvRuntimeSourceCardError::PromptCacheCompatibilityGap(card.card_id.clone()),
        )?;
    }
    if card.mechanism == KvRuntimeMechanism::KvQuantization {
        require_fields(
            &card.compatibility_fields,
            &["backend", "nbits", "axis", "group_size", "residual_length"],
            || KvRuntimeSourceCardError::KvQuantizationCaveatGap(card.card_id.clone()),
        )?;
    }
    if card.mechanism == KvRuntimeMechanism::OffloadPolicyOptimizer
        && !card
            .cache_policy_fields
            .iter()
            .any(|field| field == "latency_throughput_boundary")
    {
        return Err(KvRuntimeSourceCardError::OffloadLatencyThroughputGap(
            card.card_id.clone(),
        ));
    }
    if card.mechanism == KvRuntimeMechanism::ActivationLocality
        && (!card
            .cache_identity_fields
            .iter()
            .any(|field| field == "predictor_ref")
            || !card
                .cache_policy_fields
                .iter()
                .any(|field| field == "fallback"))
    {
        return Err(KvRuntimeSourceCardError::ActivationLocalityFallbackGap(
            card.card_id.clone(),
        ));
    }
    if card.apple_silicon_status == KvAppleSiliconStatus::SupportedByLocalWitness
        && matches!(
            card.runtime_shape,
            KvRuntimeShape::ServerFramework
                | KvRuntimeShape::DaemonCacheLayer
                | KvRuntimeShape::DistributedCluster
                | KvRuntimeShape::PythonRuntime
        )
    {
        return Err(KvRuntimeSourceCardError::UnsupportedApplePromotion(
            card.card_id.clone(),
        ));
    }
    if matches!(card.mas_status, KvMasStatus::MasEligibleMetadataOnly)
        && matches!(
            card.runtime_shape,
            KvRuntimeShape::ServerFramework
                | KvRuntimeShape::DaemonCacheLayer
                | KvRuntimeShape::DistributedCluster
        )
    {
        return Err(KvRuntimeSourceCardError::MasLiveFromServerDaemon(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_scope(card: &KvRuntimeSourceCard) -> Result<(), KvRuntimeSourceCardError> {
    if card.byte_scope.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(KvRuntimeSourceCardError::MetadataBudgetExceeded);
    }
    if card.byte_scope.source_tree_bytes_read != 0 {
        return Err(KvRuntimeSourceCardError::SourceTreeBytesImported(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.model_bytes_loaded != 0 {
        return Err(KvRuntimeSourceCardError::NonzeroModelBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.kv_bytes_loaded != 0 {
        return Err(KvRuntimeSourceCardError::NonzeroKvBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.index_bytes_loaded != 0 {
        return Err(KvRuntimeSourceCardError::NonzeroIndexBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.runtime_bytes_loaded != 0 {
        return Err(KvRuntimeSourceCardError::NonzeroRuntimeBytes(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.provider_calls_made != 0 {
        return Err(KvRuntimeSourceCardError::ProviderCallMade(
            card.card_id.clone(),
        ));
    }
    if card.byte_scope.product_files_copied != 0 {
        return Err(KvRuntimeSourceCardError::ProductFileCopied(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn reject_forbidden_claims(card: &KvRuntimeSourceCard) -> Result<(), KvRuntimeSourceCardError> {
    if card.hidden_route_authority {
        return Err(KvRuntimeSourceCardError::HiddenRouteAuthority(
            card.card_id.clone(),
        ));
    }
    if card.hidden_cache_authority {
        return Err(KvRuntimeSourceCardError::HiddenCacheAuthority(
            card.card_id.clone(),
        ));
    }
    if card.live_dense_70b_claim {
        return Err(KvRuntimeSourceCardError::LiveDense70BClaim(
            card.card_id.clone(),
        ));
    }
    if card.ssd_as_ram_claim {
        return Err(KvRuntimeSourceCardError::SsdAsRamClaim(
            card.card_id.clone(),
        ));
    }
    if card.l2_l3_promotion_claim {
        return Err(KvRuntimeSourceCardError::ProductPromotionFromResearch(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    card_id: &str,
    proof_refs: &KvRuntimeProofRefs,
) -> Result<(), KvRuntimeSourceCardError> {
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
        (
            "privacy_policy_ref",
            proof_refs.privacy_policy_ref.as_str(),
            PRIVACY_POLICY_PREFIX,
        ),
        (
            "quality_caveat_ref",
            proof_refs.quality_caveat_ref.as_str(),
            QUALITY_CAVEAT_PREFIX,
        ),
        (
            "mas_pro_boundary_ref",
            proof_refs.mas_pro_boundary_ref.as_str(),
            MAS_PRO_BOUNDARY_PREFIX,
        ),
    ] {
        validate_nonempty(field, value)?;
        if !value.starts_with(prefix) {
            return Err(KvRuntimeSourceCardError::BadProofRefPrefix {
                card_id: card_id.to_string(),
                field,
            });
        }
    }
    Ok(())
}

fn set_address(
    graph_address: &UasAddress,
    compressed_model_source_card_intake_ref: &str,
    cards: &[KvRuntimeSourceCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    server_daemon_product_blocked: bool,
    remote_storage_product_blocked: bool,
    hidden_authority_blocked: bool,
    product_promotion_blocked: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(KV_RUNTIME_SOURCE_CARD_CURSOR);
    preimage.push('\n');
    preimage.push_str(&graph_address.to_string());
    preimage.push('\n');
    preimage.push_str(compressed_model_source_card_intake_ref);
    preimage.push('\n');
    preimage.push_str(product_build_preimage(product_build));
    preimage.push('\n');
    preimage.push_str(pro_status_preimage(pro_status));
    preimage.push('\n');
    preimage.push_str(&metadata_bytes.to_string());
    preimage.push('\n');
    for flag in [
        l1_l2_l3_separated,
        server_daemon_product_blocked,
        remote_storage_product_blocked,
        hidden_authority_blocked,
        product_promotion_blocked,
    ] {
        preimage.push_str(if flag { "true" } else { "false" });
        preimage.push('\n');
    }
    for card in cards {
        push_card_preimage(&mut preimage, card);
    }
    UasAddress::new(
        UasKind::Other(KV_RUNTIME_SOURCE_CARD_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_card_preimage(preimage: &mut String, card: &KvRuntimeSourceCard) {
    preimage.push_str(&card.card_id);
    preimage.push('|');
    preimage.push_str(&card.source_id);
    preimage.push('|');
    preimage.push_str(&card.source_digest);
    preimage.push('|');
    preimage.push_str(&card.project_ref);
    preimage.push('|');
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
        card.mechanism,
        card.runtime_shape,
        card.default_deployment_shape,
        card.apple_silicon_status,
        card.mas_status,
        card.promotion_tier
    ));
    preimage.push('|');
    for tier in &card.storage_tiers {
        preimage.push_str(&format!("{tier:?},"));
    }
    preimage.push('|');
    for field in [
        &card.cache_identity_fields,
        &card.compatibility_fields,
        &card.byte_ledger_fields,
        &card.cache_policy_fields,
    ] {
        for value in field {
            preimage.push_str(value);
            preimage.push(',');
        }
        preimage.push('|');
    }
    preimage.push_str(&card.quality_caveat_ref);
    preimage.push('|');
    preimage.push_str(&card.server_daemon_boundary);
    preimage.push('|');
    preimage.push_str(&card.remote_storage_boundary);
    preimage.push('\n');
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), KvRuntimeSourceCardError> {
    if value.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingField(field));
    }
    if value.trim() != value {
        return Err(KvRuntimeSourceCardError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(KvRuntimeSourceCardError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_optional_text(
    field: &'static str,
    value: Option<&str>,
) -> Result<(), KvRuntimeSourceCardError> {
    if let Some(value) = value {
        validate_nonempty(field, value)?;
    }
    Ok(())
}

fn validate_string_vec(
    field: &'static str,
    values: &[String],
) -> Result<(), KvRuntimeSourceCardError> {
    if values.is_empty() {
        return Err(KvRuntimeSourceCardError::MissingField(field));
    }
    let mut seen = HashSet::new();
    for value in values {
        validate_nonempty(field, value)?;
        if !seen.insert(value) {
            return Err(KvRuntimeSourceCardError::FieldHasSurroundingWhitespace(
                field,
            ));
        }
    }
    Ok(())
}

fn require_fields(
    fields: &[String],
    required: &[&str],
    error: impl FnOnce() -> KvRuntimeSourceCardError,
) -> Result<(), KvRuntimeSourceCardError> {
    let field_set = fields.iter().map(String::as_str).collect::<HashSet<_>>();
    if required.iter().all(|field| field_set.contains(field)) {
        Ok(())
    } else {
        Err(error())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{PrivacyClass, SourceCard, SourceNoPoisonStatus, SourceSignalType};

    const CREATED_AT_MS: u64 = 1_779_040_000_000;

    #[test]
    fn deterministic_under_reversed_order() {
        let graph = graph();
        let cards = fixture_cards(&graph);
        let set = build_set(&graph, cards.clone()).expect("valid cards");
        let reversed = build_set(&graph, cards.into_iter().rev().collect()).expect("valid cards");
        assert_eq!(set.set_address, reversed.set_address);
    }

    #[test]
    fn rejects_server_as_product() {
        let graph = graph();
        let mut cards = fixture_cards(&graph);
        cards[0].default_deployment_shape = KvDefaultDeploymentShape::ProductEligibleInProcess;
        let error = build_set(&graph, cards).expect_err("server-as-product must reject");
        assert!(matches!(
            error,
            KvRuntimeSourceCardError::ServerAsProduct(_)
        ));
    }

    #[test]
    fn rejects_nonzero_kv_bytes() {
        let graph = graph();
        let mut cards = fixture_cards(&graph);
        cards[1].byte_scope.kv_bytes_loaded = 1;
        let error = build_set(&graph, cards).expect_err("KV byte load must reject");
        assert!(matches!(error, KvRuntimeSourceCardError::NonzeroKvBytes(_)));
    }

    #[test]
    fn rejects_quantization_without_residual_caveat() {
        let graph = graph();
        let mut cards = fixture_cards(&graph);
        cards[2]
            .compatibility_fields
            .retain(|field| field != "residual_length");
        let error = build_set(&graph, cards).expect_err("missing residual length must reject");
        assert!(matches!(
            error,
            KvRuntimeSourceCardError::KvQuantizationCaveatGap(_)
        ));
    }

    fn graph() -> SourceSignalGraph {
        SourceSignalGraph::intake(
            vec![
                source_card(
                    "source:repo:sglang",
                    "https://github.com/sgl-project/sglang",
                ),
                source_card("source:repo:lmcache", "https://github.com/LMCache/LMCache"),
                source_card(
                    "source:repo:transformers",
                    "https://github.com/huggingface/transformers",
                ),
            ],
            Vec::new(),
            CREATED_AT_MS,
        )
        .expect("source graph")
    }

    fn source_card(source_id: &str, locator: &str) -> SourceCard {
        SourceCard::new(
            source_id,
            SourceSignalType::Repo,
            locator,
            digest(source_id),
            90,
            "Apache-2.0; source-card fixture only",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            vec!["kv_runtime_source_card".to_string()],
        )
        .expect("source card")
    }

    fn fixture_cards(graph: &SourceSignalGraph) -> Vec<KvRuntimeSourceCard> {
        vec![
            card(
                graph,
                "sglang_hicache",
                "source:repo:sglang",
                KvRuntimeMechanism::HierarchicalKvCache,
                KvRuntimeShape::ServerFramework,
                KvDefaultDeploymentShape::ProResearchServer,
                vec![
                    KvRuntimeStorageTier::GpuMemory,
                    KvRuntimeStorageTier::CpuMemory,
                    KvRuntimeStorageTier::RemoteObjectStore,
                ],
                vec!["token_span", "prefix_digest"],
                vec!["model_id", "tokenizer_id", "page_size"],
                vec!["kv_bytes", "stall_ms"],
                vec!["prefetch_timeout", "write_policy"],
                KvAppleSiliconStatus::RequiresLocalWitness,
                KvMasStatus::DeniedServerOrDaemon,
            ),
            card(
                graph,
                "lmcache_lineage",
                "source:repo:lmcache",
                KvRuntimeMechanism::PrefixTreeReuse,
                KvRuntimeShape::DaemonCacheLayer,
                KvDefaultDeploymentShape::ProResearchDaemon,
                vec![
                    KvRuntimeStorageTier::CpuMemory,
                    KvRuntimeStorageTier::LocalSsd,
                    KvRuntimeStorageTier::DistributedKvStore,
                ],
                vec!["source_span_id", "prompt_digest"],
                vec!["model_id", "tokenizer_id", "adapter_set"],
                vec!["cache_hit_tokens", "cache_miss_tokens"],
                vec!["privacy_purge_policy", "visible_abstention"],
                KvAppleSiliconStatus::SourceOnly,
                KvMasStatus::DeniedServerOrDaemon,
            ),
            card(
                graph,
                "transformers_quantized_cache",
                "source:repo:transformers",
                KvRuntimeMechanism::KvQuantization,
                KvRuntimeShape::PythonRuntime,
                KvDefaultDeploymentShape::ResearchOnly,
                vec![KvRuntimeStorageTier::CpuMemory],
                vec!["cache_layer_id", "token_span"],
                vec!["backend", "nbits", "axis", "group_size", "residual_length"],
                vec!["kv_bytes", "quality_delta"],
                vec!["quality_cliff_test", "fallback"],
                KvAppleSiliconStatus::RequiresLocalWitness,
                KvMasStatus::RequiresBoundaryReview,
            ),
        ]
    }

    fn card(
        graph: &SourceSignalGraph,
        card_id: &str,
        source_id: &str,
        mechanism: KvRuntimeMechanism,
        runtime_shape: KvRuntimeShape,
        default_deployment_shape: KvDefaultDeploymentShape,
        storage_tiers: Vec<KvRuntimeStorageTier>,
        cache_identity_fields: Vec<&str>,
        compatibility_fields: Vec<&str>,
        byte_ledger_fields: Vec<&str>,
        cache_policy_fields: Vec<&str>,
        apple_silicon_status: KvAppleSiliconStatus,
        mas_status: KvMasStatus,
    ) -> KvRuntimeSourceCard {
        KvRuntimeSourceCard {
            card_id: card_id.to_string(),
            source_id: source_id.to_string(),
            source_digest: digest_for(graph, source_id),
            compressed_model_source_card_ref: Some(format!(
                "compressed_model_source_card:{card_id}"
            )),
            project_ref: format!("project:{card_id}"),
            mechanism,
            runtime_shape,
            default_deployment_shape,
            storage_tiers,
            cache_identity_fields: cache_identity_fields
                .into_iter()
                .map(str::to_string)
                .collect(),
            compatibility_fields: compatibility_fields
                .into_iter()
                .map(str::to_string)
                .collect(),
            byte_ledger_fields: byte_ledger_fields.into_iter().map(str::to_string).collect(),
            cache_policy_fields: cache_policy_fields
                .into_iter()
                .map(str::to_string)
                .collect(),
            quality_caveat_ref: format!("quality:{card_id}"),
            server_daemon_boundary: format!("boundary:server-daemon:{card_id}"),
            remote_storage_boundary: format!("boundary:remote-storage:{card_id}"),
            apple_silicon_status,
            mas_status,
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            proof_refs: KvRuntimeProofRefs {
                falsifier_ref: format!("falsifier:{card_id}"),
                rollback_ref: format!("rollback:{card_id}"),
                run_event_log_ref: format!("run_event_log:{card_id}"),
                answer_packet_ref: format!("answer_packet:{card_id}"),
                compatibility_fence_ref: format!("compat:{card_id}"),
                privacy_policy_ref: format!("privacy:{card_id}"),
                quality_caveat_ref: format!("quality:{card_id}"),
                mas_pro_boundary_ref: format!("mas_pro:{card_id}"),
            },
            byte_scope: KvRuntimeByteScope::metadata_only(1_024),
            hidden_route_authority: false,
            hidden_cache_authority: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            l2_l3_promotion_claim: false,
        }
    }

    fn build_set(
        graph: &SourceSignalGraph,
        cards: Vec<KvRuntimeSourceCard>,
    ) -> Result<KvRuntimeSourceCardSet, KvRuntimeSourceCardError> {
        KvRuntimeSourceCardSet::from_source_graph(
            graph,
            "compressed_model_source_card_intake:fixture@1779040000000",
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            32_000,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
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
