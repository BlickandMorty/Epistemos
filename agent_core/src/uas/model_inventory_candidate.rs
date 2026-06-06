//! Zero-byte model inventory candidate cards.
//!
//! This primitive binds model/package/cache metadata to an already validated
//! `SourceSignalGraph`. It deliberately does not open model blobs, hash large
//! files, start a runtime, choose a route, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{ProStatus, ProductBuild, SourceSignalGraph, UasAddress, UasKind};

pub const MODEL_INVENTORY_ZERO_BYTE_CANDIDATE_CARDS_CURSOR: &str =
    "model_inventory_zero_byte_candidate_cards";
pub const MODEL_INVENTORY_ZERO_BYTE_CANDIDATE_CARDS_NEXT_CURSOR: &str =
    "proprietary_compression_provenance_gate";

const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const APP_SUPPORT_MARKER: &str = "Application Support";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_SIDECAR_BYTES: u64 = 256 * 1024;

// UAS: uas:model-inventory:evidence-kind
// Plane: State + Verification
// Residency: metadata-only evidence taxonomy; no model bytes are opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelInventoryEvidenceKind {
    CatalogDescriptor,
    InstallManifest,
    HubSnapshot,
    MissingHubSnapshot,
    SidecarJson,
    PackageManifest,
    LfsPointer,
    FalsifierRef,
    RuntimePreferenceHint,
}

// UAS: uas:model-inventory:metadata-status
// Plane: State + Verification
// Residency: metadata-only source status; never runtime/loadability proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelInventoryMetadataStatus {
    CatalogOnly,
    InstalledChecksumUnverified,
    SnapshotPresent,
    SnapshotMissing,
    LoaderBlocked,
    DeferredOwnerProbeRequired,
    DependencyProvenanceOnly,
    RouteHintOnly,
}

// UAS: uas:model-inventory:claim-limit
// Plane: Controller + Verification
// Residency: metadata-only claim boundary before byte/runtime/WRV witnesses.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelInventoryClaimLimit {
    CatalogEvidenceOnly,
    InstallationEvidenceOnly,
    CacheRevisionEvidenceOnly,
    SidecarMetadataOnly,
    DependencyProvenanceOnly,
    PointerMetadataOnly,
    RouteHintOnly,
    RequiresByteWitness,
    RequiresRuntimeWitness,
    RequiresWrvWitness,
}

// UAS: uas:model-inventory:hash-claim
// Plane: Verification
// Residency: metadata-only hash claim class; large local blob hashes are deferred.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelInventoryHashClaim {
    None,
    SourceCardBlake3,
    ExternalLfsOidSha256,
    ManifestChecksumSha256,
    SidecarJsonSha256,
    DeferredLargeBlobHash,
    VerifiedLocalWeightBlobHash,
}

// UAS: uas:model-inventory:sidecar-policy
// Plane: Verification
// Residency: capped metadata sidecars only; referenced weights stay unopened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelInventorySidecarPolicy {
    pub allowed_sidecar_names: Vec<String>,
    pub max_sidecar_bytes: u64,
    pub malformed_json_rejected: bool,
}

// UAS: uas:model-inventory:byte-scope
// Plane: Verification
// Residency: byte accounting for metadata-only gates; runtime/model/index bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelInventoryByteScope {
    pub metadata_bytes_read: u64,
    pub sidecar_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub weight_blob_open_attempted: bool,
    pub weight_blob_hash_attempted: bool,
}

impl ModelInventoryByteScope {
    pub fn metadata_only(metadata_bytes_read: u64, sidecar_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            sidecar_bytes_read,
            model_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            weight_blob_open_attempted: false,
            weight_blob_hash_attempted: false,
        }
    }
}

// UAS: uas:model-inventory:proof-refs
// Plane: Verification
// Residency: metadata-only proof references to rollback, RunEventLog, and AnswerPacket.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelInventoryProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:model-inventory:candidate-card
// Plane: State + Controller + Verification
// Residency: source-card-bound metadata candidate; not model loadability or route authority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelInventoryCandidateCard {
    pub candidate_id: String,
    pub source_id: String,
    pub source_digest: String,
    pub model_or_package_id: String,
    pub evidence_kind: ModelInventoryEvidenceKind,
    pub metadata_status: ModelInventoryMetadataStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub claim_limit: ModelInventoryClaimLimit,
    pub evidence_locator: String,
    pub revision_ref: Option<String>,
    pub hash_claim: ModelInventoryHashClaim,
    pub loader_caveat_ref: Option<String>,
    pub route_hint_ref: Option<String>,
    pub sidecar_policy: Option<ModelInventorySidecarPolicy>,
    pub byte_scope: ModelInventoryByteScope,
    pub proof_refs: ModelInventoryProofRefs,
    pub source_observed_at_utc: Option<String>,
}

// UAS: uas:model-inventory:candidate-set
// Plane: State + Assembly + Verification
// Residency: metadata-only inventory witness; no model/index/runtime/provider bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelInventoryCandidateSet {
    pub inventory_address: UasAddress,
    pub source_graph_address: UasAddress,
    pub cards: Vec<ModelInventoryCandidateCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub route_authority_blocked: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:model-inventory:metrics
// Plane: Verification
// Residency: derived metadata-only counters for the falsifier artifact.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelInventoryMetrics {
    pub candidate_count: u64,
    pub evidence_kind_count: u64,
    pub metadata_status_count: u64,
    pub metadata_bytes: u64,
    pub sidecar_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub weight_blob_open_attempt_count: u64,
    pub weight_blob_hash_attempt_count: u64,
}

impl ModelInventoryCandidateSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_source_graph(
        graph: &SourceSignalGraph,
        cards: Vec<ModelInventoryCandidateCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        route_authority_blocked: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, ModelInventoryValidationError> {
        validate_set_inputs(
            graph,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
        )?;
        let inventory_address = inventory_address(
            &graph.graph_address,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            created_at_ms,
        );
        Ok(Self {
            inventory_address,
            source_graph_address: graph.graph_address.clone(),
            cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> ModelInventoryMetrics {
        let evidence_kinds = self
            .cards
            .iter()
            .map(|card| card.evidence_kind)
            .collect::<BTreeSet<_>>();
        let metadata_statuses = self
            .cards
            .iter()
            .map(|card| card.metadata_status)
            .collect::<BTreeSet<_>>();
        ModelInventoryMetrics {
            candidate_count: self.cards.len() as u64,
            evidence_kind_count: evidence_kinds.len() as u64,
            metadata_status_count: metadata_statuses.len() as u64,
            metadata_bytes: self.metadata_bytes,
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
        self.inventory_address.to_string()
    }
}

// UAS: uas:model-inventory:validation-error
// Plane: Verification
// Residency: metadata-only rejection taxonomy; fail closed before runtime.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ModelInventoryValidationError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyCandidateSet,
    DuplicateCandidateId(String),
    DuplicateAuthoritativeSource(String),
    UnknownSourceId(String),
    BlockedSourceId(String),
    SourceDigestMismatch(String),
    MissingSourceObservedAt(String),
    MissingProofRef {
        candidate_id: String,
        field: &'static str,
    },
    BadProofRefPrefix {
        candidate_id: String,
        field: &'static str,
    },
    SnapshotRevisionAsFileHash(String),
    LfsOidAsVerifiedLocalHash(String),
    WeightBlobOpened(String),
    WeightBlobHashAttempted(String),
    NonzeroModelBytes(String),
    NonzeroIndexBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    ActiveDirRuntimeProof(String),
    ManifestChecksumPromoted(String),
    PackageManifestLoaderProof(String),
    Gemma4LoaderCaveatMissing(String),
    RuntimePreferenceRouteAuthority(String),
    FilesystemPathAsUasAddress(String),
    SidecarSizeCapMissing(String),
    SidecarCapExceeded(String),
    MalformedSidecarTrusted(String),
    ProductGreenFromMetadata(String),
    MasLiveFromResearch(String),
    Dense70BLiveClaim(String),
    SsdAsRamClaim(String),
    HiddenCloudFallback(String),
    HiddenRouteAuthority(String),
    MissingLayerSeparation,
    MetadataBudgetExceeded,
}

impl fmt::Display for ModelInventoryValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyCandidateSet => write!(f, "missing model inventory candidate cards"),
            Self::DuplicateCandidateId(id) => write!(f, "duplicate candidate id `{id}`"),
            Self::DuplicateAuthoritativeSource(id) => {
                write!(f, "duplicate authoritative source id `{id}`")
            }
            Self::UnknownSourceId(id) => write!(f, "unknown source id `{id}`"),
            Self::BlockedSourceId(id) => write!(f, "blocked source id `{id}`"),
            Self::SourceDigestMismatch(id) => write!(f, "source digest mismatch for `{id}`"),
            Self::MissingSourceObservedAt(id) => {
                write!(f, "candidate `{id}` missing source observation timestamp")
            }
            Self::MissingProofRef {
                candidate_id,
                field,
            } => {
                write!(f, "candidate `{candidate_id}` missing proof ref `{field}`")
            }
            Self::BadProofRefPrefix {
                candidate_id,
                field,
            } => {
                write!(
                    f,
                    "candidate `{candidate_id}` has bad proof ref prefix `{field}`"
                )
            }
            Self::SnapshotRevisionAsFileHash(id) => {
                write!(f, "candidate `{id}` treated snapshot revision as file hash")
            }
            Self::LfsOidAsVerifiedLocalHash(id) => {
                write!(f, "candidate `{id}` treated LFS oid as verified local hash")
            }
            Self::WeightBlobOpened(id) => write!(f, "candidate `{id}` opened a weight blob"),
            Self::WeightBlobHashAttempted(id) => {
                write!(f, "candidate `{id}` attempted weight blob hashing")
            }
            Self::NonzeroModelBytes(id) => write!(f, "candidate `{id}` loaded model bytes"),
            Self::NonzeroIndexBytes(id) => write!(f, "candidate `{id}` loaded index bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "candidate `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "candidate `{id}` made provider call"),
            Self::ActiveDirRuntimeProof(id) => {
                write!(f, "candidate `{id}` used active dir as runtime proof")
            }
            Self::ManifestChecksumPromoted(id) => {
                write!(f, "candidate `{id}` promoted unverified manifest checksum")
            }
            Self::PackageManifestLoaderProof(id) => {
                write!(f, "candidate `{id}` used package manifest as loader proof")
            }
            Self::Gemma4LoaderCaveatMissing(id) => {
                write!(f, "candidate `{id}` removed Gemma 4 loader caveat")
            }
            Self::RuntimePreferenceRouteAuthority(id) => {
                write!(f, "candidate `{id}` turned preference into route authority")
            }
            Self::FilesystemPathAsUasAddress(id) => {
                write!(f, "candidate `{id}` used filesystem path as UAS identity")
            }
            Self::SidecarSizeCapMissing(id) => {
                write!(f, "candidate `{id}` missing sidecar size cap")
            }
            Self::SidecarCapExceeded(id) => write!(f, "candidate `{id}` sidecar cap exceeded"),
            Self::MalformedSidecarTrusted(id) => {
                write!(f, "candidate `{id}` trusted malformed sidecar JSON")
            }
            Self::ProductGreenFromMetadata(id) => {
                write!(
                    f,
                    "candidate `{id}` promoted metadata to green product proof"
                )
            }
            Self::MasLiveFromResearch(id) => write!(f, "candidate `{id}` leaked into MAS Live"),
            Self::Dense70BLiveClaim(id) => write!(f, "candidate `{id}` claimed live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "candidate `{id}` claimed SSD as RAM"),
            Self::HiddenCloudFallback(id) => write!(f, "candidate `{id}` hid cloud fallback"),
            Self::HiddenRouteAuthority(id) => write!(f, "candidate `{id}` hid route authority"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for ModelInventoryValidationError {}

fn validate_set_inputs(
    graph: &SourceSignalGraph,
    cards: &[ModelInventoryCandidateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
) -> Result<(), ModelInventoryValidationError> {
    if cards.is_empty() {
        return Err(ModelInventoryValidationError::EmptyCandidateSet);
    }
    if metadata_bytes > MAX_METADATA_BYTES {
        return Err(ModelInventoryValidationError::MetadataBudgetExceeded);
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(ModelInventoryValidationError::ProductGreenFromMetadata(
            "candidate_set".to_string(),
        ));
    }
    if !l1_l2_l3_separated || !route_authority_blocked || !product_promotion_blocked {
        return Err(ModelInventoryValidationError::MissingLayerSeparation);
    }

    let accepted = graph
        .source_cards
        .iter()
        .map(|card| (card.source_id.as_str(), card.digest.as_str()))
        .collect::<std::collections::HashMap<_, _>>();
    let rejected = graph
        .rejected_source_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let mut candidate_ids = HashSet::new();
    let mut authoritative_sources = HashSet::new();

    for card in cards {
        validate_card_common(card)?;
        if !candidate_ids.insert(card.candidate_id.as_str()) {
            return Err(ModelInventoryValidationError::DuplicateCandidateId(
                card.candidate_id.clone(),
            ));
        }
        if !authoritative_sources.insert(card.source_id.as_str()) {
            return Err(ModelInventoryValidationError::DuplicateAuthoritativeSource(
                card.source_id.clone(),
            ));
        }
        if rejected.contains(card.source_id.as_str()) {
            return Err(ModelInventoryValidationError::BlockedSourceId(
                card.source_id.clone(),
            ));
        }
        let Some(source_digest) = accepted.get(card.source_id.as_str()) else {
            return Err(ModelInventoryValidationError::UnknownSourceId(
                card.source_id.clone(),
            ));
        };
        if *source_digest != card.source_digest {
            return Err(ModelInventoryValidationError::SourceDigestMismatch(
                card.candidate_id.clone(),
            ));
        }
        validate_card_evidence(card)?;
    }
    Ok(())
}

fn validate_card_common(
    card: &ModelInventoryCandidateCard,
) -> Result<(), ModelInventoryValidationError> {
    for (field, value) in [
        ("candidate_id", card.candidate_id.as_str()),
        ("source_id", card.source_id.as_str()),
        ("source_digest", card.source_digest.as_str()),
        ("model_or_package_id", card.model_or_package_id.as_str()),
        ("evidence_locator", card.evidence_locator.as_str()),
    ] {
        validate_nonempty(field, value)?;
        reject_filesystem_identity(&card.candidate_id, field, value)?;
    }
    validate_optional_text("revision_ref", card.revision_ref.as_deref())?;
    validate_optional_text("loader_caveat_ref", card.loader_caveat_ref.as_deref())?;
    validate_optional_text("route_hint_ref", card.route_hint_ref.as_deref())?;
    let Some(source_observed_at_utc) = card.source_observed_at_utc.as_deref() else {
        return Err(ModelInventoryValidationError::MissingSourceObservedAt(
            card.candidate_id.clone(),
        ));
    };
    validate_nonempty("source_observed_at_utc", source_observed_at_utc)?;
    validate_proof_refs(&card.candidate_id, &card.proof_refs)?;
    validate_byte_scope(&card.candidate_id, &card.byte_scope)?;
    if card.product_build != ProductBuild::Pro {
        return Err(ModelInventoryValidationError::MasLiveFromResearch(
            card.candidate_id.clone(),
        ));
    }
    if card.pro_status != ProStatus::ResearchCandidate {
        return Err(ModelInventoryValidationError::ProductGreenFromMetadata(
            card.candidate_id.clone(),
        ));
    }
    if card.hash_claim == ModelInventoryHashClaim::VerifiedLocalWeightBlobHash {
        return Err(ModelInventoryValidationError::LfsOidAsVerifiedLocalHash(
            card.candidate_id.clone(),
        ));
    }
    if let Some(policy) = &card.sidecar_policy {
        validate_sidecar_policy(&card.candidate_id, policy, &card.byte_scope)?;
    }
    Ok(())
}

fn validate_card_evidence(
    card: &ModelInventoryCandidateCard,
) -> Result<(), ModelInventoryValidationError> {
    match card.evidence_kind {
        ModelInventoryEvidenceKind::CatalogDescriptor => {
            if card.metadata_status != ModelInventoryMetadataStatus::CatalogOnly
                || card.claim_limit != ModelInventoryClaimLimit::CatalogEvidenceOnly
            {
                return Err(ModelInventoryValidationError::ProductGreenFromMetadata(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::InstallManifest => {
            if card.metadata_status == ModelInventoryMetadataStatus::InstalledChecksumUnverified
                && card.hash_claim == ModelInventoryHashClaim::ManifestChecksumSha256
            {
                return Err(ModelInventoryValidationError::ManifestChecksumPromoted(
                    card.candidate_id.clone(),
                ));
            }
            if card.claim_limit != ModelInventoryClaimLimit::InstallationEvidenceOnly {
                return Err(ModelInventoryValidationError::ActiveDirRuntimeProof(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::HubSnapshot
        | ModelInventoryEvidenceKind::MissingHubSnapshot => {
            if card.claim_limit != ModelInventoryClaimLimit::CacheRevisionEvidenceOnly {
                return Err(ModelInventoryValidationError::SnapshotRevisionAsFileHash(
                    card.candidate_id.clone(),
                ));
            }
            if matches!(
                card.hash_claim,
                ModelInventoryHashClaim::ManifestChecksumSha256
                    | ModelInventoryHashClaim::SidecarJsonSha256
                    | ModelInventoryHashClaim::ExternalLfsOidSha256
            ) {
                return Err(ModelInventoryValidationError::SnapshotRevisionAsFileHash(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::SidecarJson => {
            if card.claim_limit != ModelInventoryClaimLimit::SidecarMetadataOnly
                || card.sidecar_policy.is_none()
            {
                return Err(ModelInventoryValidationError::SidecarSizeCapMissing(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::PackageManifest => {
            if card.claim_limit != ModelInventoryClaimLimit::DependencyProvenanceOnly
                || card.metadata_status != ModelInventoryMetadataStatus::DependencyProvenanceOnly
            {
                return Err(ModelInventoryValidationError::PackageManifestLoaderProof(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::LfsPointer => {
            if card.hash_claim != ModelInventoryHashClaim::ExternalLfsOidSha256
                || card.claim_limit != ModelInventoryClaimLimit::PointerMetadataOnly
            {
                return Err(ModelInventoryValidationError::LfsOidAsVerifiedLocalHash(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::FalsifierRef => {
            if !matches!(
                card.claim_limit,
                ModelInventoryClaimLimit::RequiresByteWitness
                    | ModelInventoryClaimLimit::RequiresRuntimeWitness
                    | ModelInventoryClaimLimit::RequiresWrvWitness
            ) {
                return Err(ModelInventoryValidationError::ProductGreenFromMetadata(
                    card.candidate_id.clone(),
                ));
            }
        }
        ModelInventoryEvidenceKind::RuntimePreferenceHint => {
            if card.claim_limit != ModelInventoryClaimLimit::RouteHintOnly
                || card.metadata_status != ModelInventoryMetadataStatus::RouteHintOnly
                || card.route_hint_ref.is_none()
            {
                return Err(
                    ModelInventoryValidationError::RuntimePreferenceRouteAuthority(
                        card.candidate_id.clone(),
                    ),
                );
            }
        }
    }

    if card.metadata_status == ModelInventoryMetadataStatus::LoaderBlocked
        && card.loader_caveat_ref.is_none()
    {
        return Err(ModelInventoryValidationError::Gemma4LoaderCaveatMissing(
            card.candidate_id.clone(),
        ));
    }
    if contains_forbidden_claim(&card.model_or_package_id)
        || contains_forbidden_claim(&card.evidence_locator)
    {
        return Err(ModelInventoryValidationError::Dense70BLiveClaim(
            card.candidate_id.clone(),
        ));
    }
    if card.evidence_locator.contains("ssd-as-ram") {
        return Err(ModelInventoryValidationError::SsdAsRamClaim(
            card.candidate_id.clone(),
        ));
    }
    if card.evidence_locator.contains("hidden-cloud") {
        return Err(ModelInventoryValidationError::HiddenCloudFallback(
            card.candidate_id.clone(),
        ));
    }
    if card.evidence_locator.contains("hidden-route-authority") {
        return Err(ModelInventoryValidationError::HiddenRouteAuthority(
            card.candidate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_scope(
    candidate_id: &str,
    scope: &ModelInventoryByteScope,
) -> Result<(), ModelInventoryValidationError> {
    if scope.metadata_bytes_read > MAX_METADATA_BYTES {
        return Err(ModelInventoryValidationError::MetadataBudgetExceeded);
    }
    if scope.model_bytes_loaded > 0 {
        return Err(ModelInventoryValidationError::NonzeroModelBytes(
            candidate_id.to_string(),
        ));
    }
    if scope.index_bytes_loaded > 0 {
        return Err(ModelInventoryValidationError::NonzeroIndexBytes(
            candidate_id.to_string(),
        ));
    }
    if scope.runtime_bytes_loaded > 0 {
        return Err(ModelInventoryValidationError::NonzeroRuntimeBytes(
            candidate_id.to_string(),
        ));
    }
    if scope.provider_calls_made > 0 {
        return Err(ModelInventoryValidationError::ProviderCallMade(
            candidate_id.to_string(),
        ));
    }
    if scope.weight_blob_open_attempted {
        return Err(ModelInventoryValidationError::WeightBlobOpened(
            candidate_id.to_string(),
        ));
    }
    if scope.weight_blob_hash_attempted {
        return Err(ModelInventoryValidationError::WeightBlobHashAttempted(
            candidate_id.to_string(),
        ));
    }
    Ok(())
}

fn validate_sidecar_policy(
    candidate_id: &str,
    policy: &ModelInventorySidecarPolicy,
    scope: &ModelInventoryByteScope,
) -> Result<(), ModelInventoryValidationError> {
    if policy.max_sidecar_bytes == 0 || policy.allowed_sidecar_names.is_empty() {
        return Err(ModelInventoryValidationError::SidecarSizeCapMissing(
            candidate_id.to_string(),
        ));
    }
    if policy.max_sidecar_bytes > MAX_SIDECAR_BYTES
        || scope.sidecar_bytes_read > policy.max_sidecar_bytes
    {
        return Err(ModelInventoryValidationError::SidecarCapExceeded(
            candidate_id.to_string(),
        ));
    }
    if !policy.malformed_json_rejected {
        return Err(ModelInventoryValidationError::MalformedSidecarTrusted(
            candidate_id.to_string(),
        ));
    }
    for name in &policy.allowed_sidecar_names {
        validate_nonempty("allowed_sidecar_name", name)?;
    }
    Ok(())
}

fn validate_proof_refs(
    candidate_id: &str,
    refs: &ModelInventoryProofRefs,
) -> Result<(), ModelInventoryValidationError> {
    validate_prefixed(
        candidate_id,
        "falsifier_ref",
        &refs.falsifier_ref,
        FALSIFIER_PREFIX,
    )?;
    validate_prefixed(
        candidate_id,
        "rollback_ref",
        &refs.rollback_ref,
        ROLLBACK_PREFIX,
    )?;
    validate_prefixed(
        candidate_id,
        "run_event_log_ref",
        &refs.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
    )?;
    validate_prefixed(
        candidate_id,
        "answer_packet_ref",
        &refs.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
    )?;
    validate_prefixed(
        candidate_id,
        "compatibility_fence_ref",
        &refs.compatibility_fence_ref,
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    Ok(())
}

fn validate_prefixed(
    candidate_id: &str,
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), ModelInventoryValidationError> {
    validate_nonempty(field, value).map_err(|_| {
        ModelInventoryValidationError::MissingProofRef {
            candidate_id: candidate_id.to_string(),
            field,
        }
    })?;
    if !value.starts_with(prefix) {
        return Err(ModelInventoryValidationError::BadProofRefPrefix {
            candidate_id: candidate_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn validate_optional_text(
    field: &'static str,
    value: Option<&str>,
) -> Result<(), ModelInventoryValidationError> {
    if let Some(value) = value {
        validate_nonempty(field, value)?;
    }
    Ok(())
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), ModelInventoryValidationError> {
    if value.trim().is_empty() {
        return Err(ModelInventoryValidationError::MissingField(field));
    }
    if value != value.trim() {
        return Err(ModelInventoryValidationError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|c| c.is_control()) {
        return Err(ModelInventoryValidationError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn reject_filesystem_identity(
    candidate_id: &str,
    field: &'static str,
    value: &str,
) -> Result<(), ModelInventoryValidationError> {
    if field == "evidence_locator" {
        return Ok(());
    }
    if value.starts_with('/') || value.contains(APP_SUPPORT_MARKER) {
        return Err(ModelInventoryValidationError::FilesystemPathAsUasAddress(
            candidate_id.to_string(),
        ));
    }
    Ok(())
}

fn contains_forbidden_claim(value: &str) -> bool {
    value.contains("live-dense-70b") || value.contains("dense-70b-live")
}

fn inventory_address(
    source_graph_address: &UasAddress,
    cards: &[ModelInventoryCandidateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut card_parts = cards.iter().map(card_preimage).collect::<Vec<_>>();
    card_parts.sort();
    let preimage = format!(
        "model_inventory_candidate_set_v1\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}",
        source_graph_address,
        product_build_preimage(product_build),
        pro_status_preimage(pro_status),
        metadata_bytes,
        l1_l2_l3_separated,
        route_authority_blocked,
        product_promotion_blocked,
        card_parts.join("\n")
    );
    UasAddress::new(
        UasKind::Other("model_inventory_candidate_set".to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn card_preimage(card: &ModelInventoryCandidateCard) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        card.candidate_id,
        card.source_id,
        card.source_digest,
        card.model_or_package_id,
        evidence_kind_preimage(card.evidence_kind),
        metadata_status_preimage(card.metadata_status),
        product_build_preimage(&card.product_build),
        pro_status_preimage(&card.pro_status),
        claim_limit_preimage(card.claim_limit),
        card.evidence_locator,
        card.revision_ref.as_deref().unwrap_or(""),
        hash_claim_preimage(card.hash_claim),
        card.loader_caveat_ref.as_deref().unwrap_or(""),
        card.route_hint_ref.as_deref().unwrap_or(""),
        sidecar_policy_preimage(card.sidecar_policy.as_ref()),
        byte_scope_preimage(&card.byte_scope),
        card.proof_refs.falsifier_ref,
        card.proof_refs.rollback_ref,
        card.proof_refs.run_event_log_ref,
        card.proof_refs.answer_packet_ref,
        card.proof_refs.compatibility_fence_ref,
        card.source_observed_at_utc.as_deref().unwrap_or("")
    )
}

fn sidecar_policy_preimage(policy: Option<&ModelInventorySidecarPolicy>) -> String {
    let Some(policy) = policy else {
        return "none".to_string();
    };
    let mut names = policy.allowed_sidecar_names.clone();
    names.sort();
    format!(
        "names={};max={};malformed_rejected={}",
        names.join(","),
        policy.max_sidecar_bytes,
        policy.malformed_json_rejected
    )
}

fn byte_scope_preimage(scope: &ModelInventoryByteScope) -> String {
    format!(
        "metadata={};sidecar={};model={};index={};runtime={};providers={};open={};hash={}",
        scope.metadata_bytes_read,
        scope.sidecar_bytes_read,
        scope.model_bytes_loaded,
        scope.index_bytes_loaded,
        scope.runtime_bytes_loaded,
        scope.provider_calls_made,
        scope.weight_blob_open_attempted,
        scope.weight_blob_hash_attempted
    )
}

fn evidence_kind_preimage(value: ModelInventoryEvidenceKind) -> &'static str {
    match value {
        ModelInventoryEvidenceKind::CatalogDescriptor => "catalog_descriptor",
        ModelInventoryEvidenceKind::InstallManifest => "install_manifest",
        ModelInventoryEvidenceKind::HubSnapshot => "hub_snapshot",
        ModelInventoryEvidenceKind::MissingHubSnapshot => "missing_hub_snapshot",
        ModelInventoryEvidenceKind::SidecarJson => "sidecar_json",
        ModelInventoryEvidenceKind::PackageManifest => "package_manifest",
        ModelInventoryEvidenceKind::LfsPointer => "lfs_pointer",
        ModelInventoryEvidenceKind::FalsifierRef => "falsifier_ref",
        ModelInventoryEvidenceKind::RuntimePreferenceHint => "runtime_preference_hint",
    }
}

fn metadata_status_preimage(value: ModelInventoryMetadataStatus) -> &'static str {
    match value {
        ModelInventoryMetadataStatus::CatalogOnly => "catalog_only",
        ModelInventoryMetadataStatus::InstalledChecksumUnverified => {
            "installed_checksum_unverified"
        }
        ModelInventoryMetadataStatus::SnapshotPresent => "snapshot_present",
        ModelInventoryMetadataStatus::SnapshotMissing => "snapshot_missing",
        ModelInventoryMetadataStatus::LoaderBlocked => "loader_blocked",
        ModelInventoryMetadataStatus::DeferredOwnerProbeRequired => "deferred_owner_probe_required",
        ModelInventoryMetadataStatus::DependencyProvenanceOnly => "dependency_provenance_only",
        ModelInventoryMetadataStatus::RouteHintOnly => "route_hint_only",
    }
}

fn claim_limit_preimage(value: ModelInventoryClaimLimit) -> &'static str {
    match value {
        ModelInventoryClaimLimit::CatalogEvidenceOnly => "catalog_evidence_only",
        ModelInventoryClaimLimit::InstallationEvidenceOnly => "installation_evidence_only",
        ModelInventoryClaimLimit::CacheRevisionEvidenceOnly => "cache_revision_evidence_only",
        ModelInventoryClaimLimit::SidecarMetadataOnly => "sidecar_metadata_only",
        ModelInventoryClaimLimit::DependencyProvenanceOnly => "dependency_provenance_only",
        ModelInventoryClaimLimit::PointerMetadataOnly => "pointer_metadata_only",
        ModelInventoryClaimLimit::RouteHintOnly => "route_hint_only",
        ModelInventoryClaimLimit::RequiresByteWitness => "requires_byte_witness",
        ModelInventoryClaimLimit::RequiresRuntimeWitness => "requires_runtime_witness",
        ModelInventoryClaimLimit::RequiresWrvWitness => "requires_wrv_witness",
    }
}

fn hash_claim_preimage(value: ModelInventoryHashClaim) -> &'static str {
    match value {
        ModelInventoryHashClaim::None => "none",
        ModelInventoryHashClaim::SourceCardBlake3 => "source_card_blake3",
        ModelInventoryHashClaim::ExternalLfsOidSha256 => "external_lfs_oid_sha256",
        ModelInventoryHashClaim::ManifestChecksumSha256 => "manifest_checksum_sha256",
        ModelInventoryHashClaim::SidecarJsonSha256 => "sidecar_json_sha256",
        ModelInventoryHashClaim::DeferredLargeBlobHash => "deferred_large_blob_hash",
        ModelInventoryHashClaim::VerifiedLocalWeightBlobHash => "verified_local_weight_blob_hash",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{PrivacyClass, SourceCard, SourceNoPoisonStatus, SourceSignalType};

    const CREATED_AT_MS: u64 = 1_779_020_000_000;

    #[test]
    fn accepted_candidate_set_is_metadata_only_and_addressed() {
        let graph = source_graph();
        let set = ModelInventoryCandidateSet::from_source_graph(
            &graph,
            vec![
                catalog_card(&graph),
                install_manifest_card(&graph),
                sidecar_card(&graph),
                runtime_hint_card(&graph),
            ],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            24_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect("valid metadata-only inventory");
        let metrics = set.metrics();
        assert_eq!(metrics.candidate_count, 4);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert!(set.address().starts_with("model_inventory_candidate_set:"));
        assert!(set.address().contains('@'));
    }

    #[test]
    fn duplicate_candidate_ids_are_rejected() {
        let graph = source_graph();
        let first = catalog_card(&graph);
        let mut second = install_manifest_card(&graph);
        second.candidate_id = first.candidate_id.clone();
        let error = candidate_set_error(&graph, vec![first, second]);
        assert!(matches!(
            error,
            ModelInventoryValidationError::DuplicateCandidateId(_)
        ));
    }

    #[test]
    fn unknown_source_ids_are_rejected() {
        let graph = source_graph();
        let mut card = catalog_card(&graph);
        card.source_id = "source:missing".to_string();
        let error = candidate_set_error(&graph, vec![card]);
        assert!(matches!(
            error,
            ModelInventoryValidationError::UnknownSourceId(_)
        ));
    }

    #[test]
    fn verified_weight_blob_hash_is_rejected_in_metadata_gate() {
        let graph = source_graph();
        let mut card = catalog_card(&graph);
        card.hash_claim = ModelInventoryHashClaim::VerifiedLocalWeightBlobHash;
        let error = candidate_set_error(&graph, vec![card]);
        assert!(matches!(
            error,
            ModelInventoryValidationError::LfsOidAsVerifiedLocalHash(_)
        ));
    }

    #[test]
    fn model_bytes_loaded_are_rejected() {
        let graph = source_graph();
        let mut card = catalog_card(&graph);
        card.byte_scope.model_bytes_loaded = 1;
        let error = candidate_set_error(&graph, vec![card]);
        assert!(matches!(
            error,
            ModelInventoryValidationError::NonzeroModelBytes(_)
        ));
    }

    #[test]
    fn runtime_preference_cannot_be_route_authority() {
        let graph = source_graph();
        let mut card = runtime_hint_card(&graph);
        card.claim_limit = ModelInventoryClaimLimit::RequiresRuntimeWitness;
        let error = candidate_set_error(&graph, vec![card]);
        assert!(matches!(
            error,
            ModelInventoryValidationError::RuntimePreferenceRouteAuthority(_)
        ));
    }

    #[test]
    fn missing_source_observation_timestamp_is_rejected() {
        let graph = source_graph();
        let mut card = catalog_card(&graph);
        card.source_observed_at_utc = None;
        let error = candidate_set_error(&graph, vec![card]);
        assert!(matches!(
            error,
            ModelInventoryValidationError::MissingSourceObservedAt(_)
        ));
    }

    fn candidate_set_error(
        graph: &SourceSignalGraph,
        cards: Vec<ModelInventoryCandidateCard>,
    ) -> ModelInventoryValidationError {
        ModelInventoryCandidateSet::from_source_graph(
            graph,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            24_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect_err("candidate set should reject")
    }

    fn source_graph() -> SourceSignalGraph {
        SourceSignalGraph::intake(
            vec![
                source_card("source:model:catalog-qwen3-4b"),
                source_card("source:model:manifest-deepseek-r1"),
                source_card("source:model:sidecar-gemma4"),
                source_card("source:router:runtime-preference"),
            ],
            Vec::new(),
            CREATED_AT_MS,
        )
        .expect("source graph")
    }

    fn source_card(source_id: &str) -> SourceCard {
        SourceCard::new(
            source_id,
            SourceSignalType::Doc,
            format!("fixture://{source_id}"),
            format!("blake3:{}", blake3::hash(source_id.as_bytes()).to_hex()),
            1,
            "fixture-only source; no code import",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            vec!["model_inventory".to_string()],
        )
        .expect("source card")
    }

    fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
        graph
            .source_cards
            .iter()
            .find(|card| card.source_id == source_id)
            .expect("source card present")
            .digest
            .clone()
    }

    fn proof_refs(id: &str) -> ModelInventoryProofRefs {
        ModelInventoryProofRefs {
            falsifier_ref: format!("falsifier:F-ModelInventory-ZeroByteCandidateCards:{id}"),
            rollback_ref: format!("rollback:model-inventory:{id}"),
            run_event_log_ref: format!("run_event_log:model-inventory:{id}"),
            answer_packet_ref: format!("answer_packet:model-inventory:{id}"),
            compatibility_fence_ref: format!("compat:model-inventory:{id}"),
        }
    }

    fn catalog_card(graph: &SourceSignalGraph) -> ModelInventoryCandidateCard {
        ModelInventoryCandidateCard {
            candidate_id: "candidate:catalog:qwen3-4b".to_string(),
            source_id: "source:model:catalog-qwen3-4b".to_string(),
            source_digest: digest_for(graph, "source:model:catalog-qwen3-4b"),
            model_or_package_id: "Qwen/Qwen3-4B-MLX-4bit".to_string(),
            evidence_kind: ModelInventoryEvidenceKind::CatalogDescriptor,
            metadata_status: ModelInventoryMetadataStatus::CatalogOnly,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            claim_limit: ModelInventoryClaimLimit::CatalogEvidenceOnly,
            evidence_locator: "Epistemos/State/InferenceState.swift:LocalTextModelID".to_string(),
            revision_ref: Some("52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495".to_string()),
            hash_claim: ModelInventoryHashClaim::SourceCardBlake3,
            loader_caveat_ref: None,
            route_hint_ref: None,
            sidecar_policy: None,
            byte_scope: ModelInventoryByteScope::metadata_only(1_024, 0),
            proof_refs: proof_refs("catalog-qwen3-4b"),
            source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
        }
    }

    fn install_manifest_card(graph: &SourceSignalGraph) -> ModelInventoryCandidateCard {
        ModelInventoryCandidateCard {
            candidate_id: "candidate:manifest:deepseek-r1".to_string(),
            source_id: "source:model:manifest-deepseek-r1".to_string(),
            source_digest: digest_for(graph, "source:model:manifest-deepseek-r1"),
            model_or_package_id: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit".to_string(),
            evidence_kind: ModelInventoryEvidenceKind::InstallManifest,
            metadata_status: ModelInventoryMetadataStatus::InstalledChecksumUnverified,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            claim_limit: ModelInventoryClaimLimit::InstallationEvidenceOnly,
            evidence_locator: "/Users/jojo/Library/Application Support/Epistemos/Models/manifests/install-state.json".to_string(),
            revision_ref: Some("21848dbf533d2518a1ef895104820d5ee51317ea".to_string()),
            hash_claim: ModelInventoryHashClaim::None,
            loader_caveat_ref: None,
            route_hint_ref: None,
            sidecar_policy: None,
            byte_scope: ModelInventoryByteScope::metadata_only(821, 0),
            proof_refs: proof_refs("manifest-deepseek-r1"),
            source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
        }
    }

    fn sidecar_card(graph: &SourceSignalGraph) -> ModelInventoryCandidateCard {
        ModelInventoryCandidateCard {
            candidate_id: "candidate:sidecar:gemma4-loader-blocked".to_string(),
            source_id: "source:model:sidecar-gemma4".to_string(),
            source_digest: digest_for(graph, "source:model:sidecar-gemma4"),
            model_or_package_id: "mlx-community/gemma-4-e4b-it-4bit".to_string(),
            evidence_kind: ModelInventoryEvidenceKind::SidecarJson,
            metadata_status: ModelInventoryMetadataStatus::LoaderBlocked,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            claim_limit: ModelInventoryClaimLimit::SidecarMetadataOnly,
            evidence_locator: "model.safetensors.index.json".to_string(),
            revision_ref: Some("62b0e4e2d06c2f3baeeb0f8b7b18d7308c7786fc".to_string()),
            hash_claim: ModelInventoryHashClaim::SidecarJsonSha256,
            loader_caveat_ref: Some("loader_caveat:swift-mlx-gemma4-preview-blocked".to_string()),
            route_hint_ref: None,
            sidecar_policy: Some(ModelInventorySidecarPolicy {
                allowed_sidecar_names: vec!["model.safetensors.index.json".to_string()],
                max_sidecar_bytes: 64 * 1024,
                malformed_json_rejected: true,
            }),
            byte_scope: ModelInventoryByteScope::metadata_only(1_024, 4_096),
            proof_refs: proof_refs("sidecar-gemma4"),
            source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
        }
    }

    fn runtime_hint_card(graph: &SourceSignalGraph) -> ModelInventoryCandidateCard {
        ModelInventoryCandidateCard {
            candidate_id: "candidate:runtime-hint:qwen-coder".to_string(),
            source_id: "source:router:runtime-preference".to_string(),
            source_digest: digest_for(graph, "source:router:runtime-preference"),
            model_or_package_id: "mlx-community/Qwen3-Coder-Next-4bit".to_string(),
            evidence_kind: ModelInventoryEvidenceKind::RuntimePreferenceHint,
            metadata_status: ModelInventoryMetadataStatus::RouteHintOnly,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            claim_limit: ModelInventoryClaimLimit::RouteHintOnly,
            evidence_locator: "Epistemos/LocalAgent/RuntimeRouter.swift:modelPreferenceTable"
                .to_string(),
            revision_ref: Some("7b9321eabb85ce79625cac3f61ea691e4ea984b5".to_string()),
            hash_claim: ModelInventoryHashClaim::None,
            loader_caveat_ref: None,
            route_hint_ref: Some("route_hint:runtime-router-preference-only".to_string()),
            sidecar_policy: None,
            byte_scope: ModelInventoryByteScope::metadata_only(1_024, 0),
            proof_refs: proof_refs("runtime-hint-qwen-coder"),
            source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
        }
    }
}
