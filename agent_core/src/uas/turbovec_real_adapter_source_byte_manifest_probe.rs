//! TurboVec real-adapter source-byte manifest probe.
//!
//! This primitive records a GitHub tree-metadata manifest for the pinned
//! TurboVec revision after the fetch-lease gate. It is metadata-only: it does
//! not clone the repo, fetch source archives, read raw source content, import
//! code, build adapters, probe native links, open indexes, load models, or
//! grant route authority.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_CURSOR: &str =
    "turbovec_quarantine_real_adapter_source_byte_manifest_probe";
pub const TURBOVEC_REAL_ADAPTER_SOURCE_BYTE_MANIFEST_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_source_inspection_policy_probe";

const FETCH_LEASE_WITNESS_REF: &str = "artifact:turbovec_real_adapter_fetch_lease_probe:result";
const FETCH_LEASE_PREFIX: &str = "turbovec_real_adapter_fetch_lease_probe:";
const SOURCE_REF_PREFIX: &str = "source_manifest:turbovec:";
const PROVENANCE_REF_PREFIX: &str = "provenance:turbovec-source-manifest:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-source-manifest:";
const CLEANUP_REF_PREFIX: &str = "cleanup:turbovec-source-manifest:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-source-manifest:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-source-manifest:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-source-manifest:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-source-manifest:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-source-manifest:";
const BENCHMARK_CAVEAT_PREFIX: &str = "benchmark_caveat:turbovec-source-manifest:";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const TREE_API_URL: &str =
    "https://api.github.com/repos/RyanCodrai/turbovec/git/trees/efe29a184986cbf562a9847c2ac52a2990bfaca2?recursive=1";
const CODELOAD_URL: &str =
    "https://codeload.github.com/RyanCodrai/turbovec/tar.gz/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const QUARANTINE_ROOT: &str =
    ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const EXPECTED_TREE_ENTRY_COUNT: u64 = 207;
const EXPECTED_BLOB_COUNT: u64 = 180;
const EXPECTED_TREE_NODE_COUNT: u64 = 27;
const EXPECTED_TOTAL_BLOB_BYTES: u64 = 1_615_603;
const MAX_TREE_METADATA_BYTES_READ: u64 = 192 * 1024;
const MIN_REQUIRED_ENTRY_COUNT: usize = 22;
const MIN_ROOT_BUCKET_COUNT: usize = 15;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 360;

// UAS: uas:turbovec-real-adapter-source-byte-manifest:status
// Plane: Verification
// Residency: metadata-only source-byte manifest status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourceManifestStatus {
    MetadataOnlyManifest,
    Blocked,
    SourceFetchedByLaterWitness,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:tier
// Plane: Verification
// Residency: T1-only promotion boundary for the source manifest.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourceManifestTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:kind
// Plane: State + Verification
// Residency: manifest source class; only Git tree metadata is allowed here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourceManifestKind {
    GitHubTreeMetadataOnly,
    CodeloadArchiveDigestByLaterWitness,
    LocalQuarantineSnapshotByLaterWitness,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:disposition
// Plane: State + Verification
// Residency: allowed use of a manifest row before source inspection.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourceManifestDisposition {
    ProvenanceOnly,
    RustCoreCandidate,
    PythonBindingCandidate,
    TestFixtureCandidate,
    BenchmarkClaimOnly,
    DocumentationOnly,
    NativeLinkBlocked,
    IntegrationBlocked,
    BinaryAssetBlocked,
    SymlinkBlocked,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:source
// Plane: State + Verification
// Residency: upstream source tree identity; no raw content is read here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceManifestSource {
    pub source_ref: String,
    pub source_url: String,
    pub tree_api_url: String,
    pub codeload_url: String,
    pub pinned_revision: String,
    pub current_head_revision: String,
    pub tree_truncated: bool,
    pub tree_entry_count: u64,
    pub blob_count: u64,
    pub tree_node_count: u64,
    pub total_blob_bytes: u64,
    pub quarantine_root: String,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:entry
// Plane: State + Verification
// Residency: required manifest row; Git blob metadata only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceManifestEntry {
    pub path: String,
    pub mode: String,
    pub git_blob_sha: String,
    pub byte_len: u64,
    pub disposition: TurboVecSourceManifestDisposition,
    pub raw_content_read: bool,
    pub source_inspection_allowed_now: bool,
    pub product_import_allowed: bool,
    pub native_link_probe_allowed: bool,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:root-bucket
// Plane: State + Verification
// Residency: aggregate root coverage from upstream tree metadata.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceManifestRootBucket {
    pub root: String,
    pub blob_count: u64,
    pub required_for_manifest: bool,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:policy
// Plane: Controller + Verification
// Residency: fail-closed source-byte manifest policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceManifestPolicy {
    pub github_tree_metadata_only: bool,
    pub source_bytes_fetched: bool,
    pub raw_content_read: bool,
    pub codeload_archive_opened: bool,
    pub local_quarantine_files_written: bool,
    pub source_inspection_allowed_now: bool,
    pub product_import_allowed: bool,
    pub product_dependency_allowed: bool,
    pub native_link_probe_allowed: bool,
    pub runtime_execution_allowed: bool,
    pub index_or_model_bytes_allowed: bool,
    pub symlink_targets_blocked: bool,
    pub binary_assets_blocked: bool,
    pub benchmark_claims_non_authoritative: bool,
    pub source_inspection_requires_later_witness: bool,
    pub cleanup_replay_required: bool,
    pub answer_packet_required: bool,
}

impl TurboVecSourceManifestPolicy {
    pub fn fail_closed() -> Self {
        Self {
            github_tree_metadata_only: true,
            source_bytes_fetched: false,
            raw_content_read: false,
            codeload_archive_opened: false,
            local_quarantine_files_written: false,
            source_inspection_allowed_now: false,
            product_import_allowed: false,
            product_dependency_allowed: false,
            native_link_probe_allowed: false,
            runtime_execution_allowed: false,
            index_or_model_bytes_allowed: false,
            symlink_targets_blocked: true,
            binary_assets_blocked: true,
            benchmark_claims_non_authoritative: true,
            source_inspection_requires_later_witness: true,
            cleanup_replay_required: true,
            answer_packet_required: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:byte-ledger
// Plane: Verification
// Residency: byte accounting for manifest metadata vs source/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceManifestByteLedger {
    pub github_tree_metadata_bytes_read: u64,
    pub declared_total_blob_bytes: u64,
    pub raw_source_bytes_read: u64,
    pub source_archive_bytes_fetched: u64,
    pub local_quarantine_bytes_written: u64,
    pub copied_product_file_count: u64,
    pub product_dependency_count: u64,
    pub imported_external_crate_count: u64,
    pub built_external_binary_count: u64,
    pub native_link_probe_count: u64,
    pub opened_product_index_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl TurboVecSourceManifestByteLedger {
    pub fn metadata_only(github_tree_metadata_bytes_read: u64) -> Self {
        Self {
            github_tree_metadata_bytes_read,
            declared_total_blob_bytes: EXPECTED_TOTAL_BLOB_BYTES,
            raw_source_bytes_read: 0,
            source_archive_bytes_fetched: 0,
            local_quarantine_bytes_written: 0,
            copied_product_file_count: 0,
            product_dependency_count: 0,
            imported_external_crate_count: 0,
            built_external_binary_count: 0,
            native_link_probe_count: 0,
            opened_product_index_bytes: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:proof-refs
// Plane: Verification
// Residency: visible proof refs for no-product-graph manifesting.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceManifestProofRefs {
    pub fetch_lease_ref: String,
    pub provenance_ref: String,
    pub rollback_ref: String,
    pub cleanup_ref: String,
    pub no_product_graph_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub native_link_block_ref: String,
    pub benchmark_caveat_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:set
// Plane: State + Assembly + Controller + Verification
// Residency: complete metadata-only source-byte manifest witness set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterSourceByteManifestProbeSet {
    pub set_address: UasAddress,
    pub upstream_fetch_lease_address: UasAddress,
    pub upstream_fetch_lease_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecSourceManifestStatus,
    pub promotion_tier: TurboVecSourceManifestTier,
    pub manifest_kind: TurboVecSourceManifestKind,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub source: TurboVecSourceManifestSource,
    pub required_entries: Vec<TurboVecSourceManifestEntry>,
    pub root_buckets: Vec<TurboVecSourceManifestRootBucket>,
    pub policy: TurboVecSourceManifestPolicy,
    pub proof_refs: TurboVecSourceManifestProofRefs,
    pub byte_ledger: TurboVecSourceManifestByteLedger,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:metrics
// Plane: Verification
// Residency: aggregate counters for source-manifest axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecSourceManifestMetrics {
    pub required_entry_count: u64,
    pub root_bucket_count: u64,
    pub total_tree_entry_count: u64,
    pub blob_count: u64,
    pub tree_node_count: u64,
    pub total_blob_bytes: u64,
    pub git_tree_metadata_bytes_read: u64,
    pub raw_source_bytes_read: u64,
    pub source_archive_bytes_fetched: u64,
    pub local_quarantine_bytes_written: u64,
    pub product_dependency_count: u64,
    pub copied_product_file_count: u64,
    pub native_link_probe_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub blocked_symlink_count: u64,
    pub blocked_binary_asset_count: u64,
    pub benchmark_claim_only_count: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
}

impl TurboVecRealAdapterSourceByteManifestProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_fetch_lease_address: UasAddress,
        source: TurboVecSourceManifestSource,
        mut required_entries: Vec<TurboVecSourceManifestEntry>,
        mut root_buckets: Vec<TurboVecSourceManifestRootBucket>,
        policy: TurboVecSourceManifestPolicy,
        proof_refs: TurboVecSourceManifestProofRefs,
        byte_ledger: TurboVecSourceManifestByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecSourceManifestStatus,
        promotion_tier: TurboVecSourceManifestTier,
        manifest_kind: TurboVecSourceManifestKind,
        organs: Vec<TurboVecIndexOrgan>,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecSourceManifestError> {
        required_entries.sort_by(|left, right| left.path.cmp(&right.path));
        root_buckets.sort_by(|left, right| left.root.cmp(&right.root));
        validate_set_inputs(
            &upstream_fetch_lease_address,
            &source,
            &required_entries,
            &root_buckets,
            &policy,
            &proof_refs,
            &byte_ledger,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &manifest_kind,
            &organs,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?;
        let set_address = deterministic_set_address(&source, &required_entries, &root_buckets);
        Ok(Self {
            set_address,
            upstream_fetch_lease_address,
            upstream_fetch_lease_witness_ref: FETCH_LEASE_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            manifest_kind,
            organs,
            source,
            required_entries,
            root_buckets,
            policy,
            proof_refs,
            byte_ledger,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        })
    }

    pub fn metrics(&self) -> TurboVecSourceManifestMetrics {
        TurboVecSourceManifestMetrics {
            required_entry_count: self.required_entries.len() as u64,
            root_bucket_count: self.root_buckets.len() as u64,
            total_tree_entry_count: self.source.tree_entry_count,
            blob_count: self.source.blob_count,
            tree_node_count: self.source.tree_node_count,
            total_blob_bytes: self.source.total_blob_bytes,
            git_tree_metadata_bytes_read: self.byte_ledger.github_tree_metadata_bytes_read,
            raw_source_bytes_read: self.byte_ledger.raw_source_bytes_read,
            source_archive_bytes_fetched: self.byte_ledger.source_archive_bytes_fetched,
            local_quarantine_bytes_written: self.byte_ledger.local_quarantine_bytes_written,
            product_dependency_count: self.byte_ledger.product_dependency_count,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            blocked_symlink_count: self
                .required_entries
                .iter()
                .filter(|entry| {
                    entry.disposition == TurboVecSourceManifestDisposition::SymlinkBlocked
                })
                .count() as u64,
            blocked_binary_asset_count: self
                .required_entries
                .iter()
                .filter(|entry| {
                    entry.disposition == TurboVecSourceManifestDisposition::BinaryAssetBlocked
                })
                .count() as u64,
            benchmark_claim_only_count: self
                .required_entries
                .iter()
                .filter(|entry| {
                    entry.disposition == TurboVecSourceManifestDisposition::BenchmarkClaimOnly
                })
                .count() as u64,
            route_mutation_count: u64::from(self.route_mutation_allowed),
            model_context_injection_count: u64::from(self.model_context_injected),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-byte-manifest:error
// Plane: Verification
// Residency: validation failures for unsafe manifest states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecSourceManifestError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecSourceManifestStatus),
    BadPromotionTier(TurboVecSourceManifestTier),
    BadManifestKind(TurboVecSourceManifestKind),
    InvalidOrgans,
    InvalidSource(String),
    InvalidEntry(String),
    InvalidRootBucket(String),
    InvalidPolicy(String),
    InvalidByteLedger(String),
    ProductPromotionAllowed,
    ForbiddenAuthority(String),
    MissingField(&'static str),
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
}

impl fmt::Display for TurboVecSourceManifestError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "upstream fetch-lease cursor mismatch"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad manifest status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad manifest tier: {tier:?}"),
            Self::BadManifestKind(kind) => write!(f, "bad manifest kind: {kind:?}"),
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidSource(reason) => write!(f, "invalid manifest source: {reason}"),
            Self::InvalidEntry(reason) => write!(f, "invalid manifest entry: {reason}"),
            Self::InvalidRootBucket(reason) => {
                write!(f, "invalid manifest root bucket: {reason}")
            }
            Self::InvalidPolicy(reason) => write!(f, "invalid manifest policy: {reason}"),
            Self::InvalidByteLedger(reason) => write!(f, "invalid byte ledger: {reason}"),
            Self::ProductPromotionAllowed => write!(f, "product promotion attempted"),
            Self::ForbiddenAuthority(reason) => write!(f, "forbidden authority: {reason}"),
            Self::MissingField(field) => write!(f, "missing field: {field}"),
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(f, "{field} `{value}` must start with `{expected}`"),
        }
    }
}

impl std::error::Error for TurboVecSourceManifestError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_fetch_lease_address: &UasAddress,
    source: &TurboVecSourceManifestSource,
    required_entries: &[TurboVecSourceManifestEntry],
    root_buckets: &[TurboVecSourceManifestRootBucket],
    policy: &TurboVecSourceManifestPolicy,
    proof_refs: &TurboVecSourceManifestProofRefs,
    byte_ledger: &TurboVecSourceManifestByteLedger,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecSourceManifestStatus,
    promotion_tier: &TurboVecSourceManifestTier,
    manifest_kind: &TurboVecSourceManifestKind,
    organs: &[TurboVecIndexOrgan],
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<(), TurboVecSourceManifestError> {
    if !upstream_fetch_lease_address
        .to_string()
        .starts_with(FETCH_LEASE_PREFIX)
    {
        return Err(TurboVecSourceManifestError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecSourceManifestError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecSourceManifestError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if status != &TurboVecSourceManifestStatus::MetadataOnlyManifest {
        return Err(TurboVecSourceManifestError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecSourceManifestTier::T1L1Metadata {
        return Err(TurboVecSourceManifestError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    if manifest_kind != &TurboVecSourceManifestKind::GitHubTreeMetadataOnly {
        return Err(TurboVecSourceManifestError::BadManifestKind(*manifest_kind));
    }
    if product_capability_promoted {
        return Err(TurboVecSourceManifestError::ProductPromotionAllowed);
    }
    if route_mutation_allowed
        || model_context_injected
        || hidden_route_authority
        || hidden_cloud_fallback_allowed
        || live_large_model_claimed
        || ssd_as_ram_claimed
    {
        return Err(TurboVecSourceManifestError::ForbiddenAuthority(
            "route/context/hidden/cloud/large-model claim attempted".to_string(),
        ));
    }
    validate_organs(organs)?;
    validate_source(source)?;
    validate_entries(required_entries)?;
    validate_root_buckets(root_buckets)?;
    validate_policy(policy)?;
    validate_proof_refs(proof_refs)?;
    validate_byte_ledger(byte_ledger, source)?;
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecSourceManifestError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let seen: HashSet<_> = organs.iter().copied().collect();
    if seen.len() != organs.len() || required.iter().any(|organ| !seen.contains(organ)) {
        return Err(TurboVecSourceManifestError::InvalidOrgans);
    }
    Ok(())
}

fn validate_source(
    source: &TurboVecSourceManifestSource,
) -> Result<(), TurboVecSourceManifestError> {
    if !source.source_ref.starts_with(SOURCE_REF_PREFIX) {
        return Err(TurboVecSourceManifestError::BadPrefix {
            field: "source_ref",
            value: source.source_ref.clone(),
            expected: SOURCE_REF_PREFIX,
        });
    }
    if source.source_url != SOURCE_URL {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "source URL must be pinned upstream".to_string(),
        ));
    }
    if source.tree_api_url != TREE_API_URL {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "tree API URL must bind the pinned revision".to_string(),
        ));
    }
    if source.codeload_url != CODELOAD_URL {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "codeload URL must bind the pinned revision".to_string(),
        ));
    }
    if source.pinned_revision != PINNED_REVISION || !is_full_lower_hex_sha(&source.pinned_revision)
    {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "pinned revision must be a 40-char lowercase SHA".to_string(),
        ));
    }
    if source.current_head_revision != source.pinned_revision {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "current head must match pinned revision in this fixture".to_string(),
        ));
    }
    if source.tree_truncated {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "GitHub tree metadata must not be truncated".to_string(),
        ));
    }
    if source.tree_entry_count != EXPECTED_TREE_ENTRY_COUNT
        || source.blob_count != EXPECTED_BLOB_COUNT
        || source.tree_node_count != EXPECTED_TREE_NODE_COUNT
        || source.total_blob_bytes != EXPECTED_TOTAL_BLOB_BYTES
    {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "tree count or byte totals drifted".to_string(),
        ));
    }
    if source.quarantine_root != QUARANTINE_ROOT {
        return Err(TurboVecSourceManifestError::InvalidSource(
            "quarantine root must match fetch lease".to_string(),
        ));
    }
    Ok(())
}

fn validate_entries(
    entries: &[TurboVecSourceManifestEntry],
) -> Result<(), TurboVecSourceManifestError> {
    if entries.len() < MIN_REQUIRED_ENTRY_COUNT {
        return Err(TurboVecSourceManifestError::InvalidEntry(
            "required manifest entry floor not met".to_string(),
        ));
    }
    let mut paths = BTreeSet::new();
    let mut required_paths: HashMap<&str, (&str, u64, &str, TurboVecSourceManifestDisposition)> =
        required_entry_expectations().into_iter().collect();
    for entry in entries {
        if !valid_relative_path(&entry.path) {
            return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                "{} has invalid path",
                entry.path
            )));
        }
        if !paths.insert(entry.path.clone()) {
            return Err(TurboVecSourceManifestError::InvalidEntry(
                "duplicate path".to_string(),
            ));
        }
        for forbidden in [
            "agent_core",
            "Epistemos",
            "graph-engine",
            "Tools",
            "artifacts",
            "benchmarks/results",
            "target",
            ".git",
        ] {
            if path_has_root(&entry.path, forbidden) {
                return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                    "{} touches forbidden product root {forbidden}",
                    entry.path
                )));
            }
        }
        if !is_full_lower_hex_sha(&entry.git_blob_sha) {
            return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                "{} has invalid blob SHA",
                entry.path
            )));
        }
        if entry.byte_len == 0 {
            return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                "{} has zero byte length",
                entry.path
            )));
        }
        if entry.raw_content_read
            || entry.source_inspection_allowed_now
            || entry.product_import_allowed
            || entry.native_link_probe_allowed
        {
            return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                "{} attempts source/import/native-link authority",
                entry.path
            )));
        }
        if entry.mode == "120000"
            && entry.disposition != TurboVecSourceManifestDisposition::SymlinkBlocked
        {
            return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                "{} symlink must be blocked",
                entry.path
            )));
        }
        if entry.mode != "100644" && entry.mode != "120000" {
            return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                "{} has unsupported mode {}",
                entry.path, entry.mode
            )));
        }
        match required_paths.remove(entry.path.as_str()) {
            Some((expected_sha, expected_size, expected_mode, expected_disposition)) => {
                if entry.git_blob_sha != expected_sha
                    || entry.byte_len != expected_size
                    || entry.mode != expected_mode
                    || entry.disposition != expected_disposition
                {
                    return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                        "{} metadata drifted",
                        entry.path
                    )));
                }
            }
            None => {
                return Err(TurboVecSourceManifestError::InvalidEntry(format!(
                    "{} is not an expected required entry",
                    entry.path
                )));
            }
        }
    }
    if !required_paths.is_empty() {
        return Err(TurboVecSourceManifestError::InvalidEntry(
            "one or more required entries missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_root_buckets(
    root_buckets: &[TurboVecSourceManifestRootBucket],
) -> Result<(), TurboVecSourceManifestError> {
    if root_buckets.len() < MIN_ROOT_BUCKET_COUNT {
        return Err(TurboVecSourceManifestError::InvalidRootBucket(
            "root bucket floor not met".to_string(),
        ));
    }
    let mut seen = BTreeSet::new();
    let mut expected: HashMap<&str, u64> = required_root_buckets().into_iter().collect();
    for bucket in root_buckets {
        if bucket.root.is_empty() || !seen.insert(bucket.root.clone()) {
            return Err(TurboVecSourceManifestError::InvalidRootBucket(
                "empty or duplicate root".to_string(),
            ));
        }
        match expected.remove(bucket.root.as_str()) {
            Some(count) => {
                if bucket.blob_count != count || !bucket.required_for_manifest {
                    return Err(TurboVecSourceManifestError::InvalidRootBucket(format!(
                        "{} count or requirement drifted",
                        bucket.root
                    )));
                }
            }
            None => {
                return Err(TurboVecSourceManifestError::InvalidRootBucket(format!(
                    "{} is not expected",
                    bucket.root
                )));
            }
        }
    }
    if !expected.is_empty() {
        return Err(TurboVecSourceManifestError::InvalidRootBucket(
            "one or more required roots missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecSourceManifestPolicy,
) -> Result<(), TurboVecSourceManifestError> {
    if !policy.github_tree_metadata_only
        || !policy.symlink_targets_blocked
        || !policy.binary_assets_blocked
        || !policy.benchmark_claims_non_authoritative
        || !policy.source_inspection_requires_later_witness
        || !policy.cleanup_replay_required
        || !policy.answer_packet_required
    {
        return Err(TurboVecSourceManifestError::InvalidPolicy(
            "all fail-closed true flags must hold".to_string(),
        ));
    }
    if policy.source_bytes_fetched
        || policy.raw_content_read
        || policy.codeload_archive_opened
        || policy.local_quarantine_files_written
        || policy.source_inspection_allowed_now
        || policy.product_import_allowed
        || policy.product_dependency_allowed
        || policy.native_link_probe_allowed
        || policy.runtime_execution_allowed
        || policy.index_or_model_bytes_allowed
    {
        return Err(TurboVecSourceManifestError::InvalidPolicy(
            "source/import/native-link/runtime authority attempted".to_string(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    proof_refs: &TurboVecSourceManifestProofRefs,
) -> Result<(), TurboVecSourceManifestError> {
    for (field, value, expected) in [
        (
            "fetch_lease_ref",
            &proof_refs.fetch_lease_ref,
            FETCH_LEASE_WITNESS_REF,
        ),
        (
            "provenance_ref",
            &proof_refs.provenance_ref,
            PROVENANCE_REF_PREFIX,
        ),
        (
            "rollback_ref",
            &proof_refs.rollback_ref,
            ROLLBACK_REF_PREFIX,
        ),
        ("cleanup_ref", &proof_refs.cleanup_ref, CLEANUP_REF_PREFIX),
        (
            "no_product_graph_ref",
            &proof_refs.no_product_graph_ref,
            NO_PRODUCT_GRAPH_REF_PREFIX,
        ),
        (
            "run_event_log_ref",
            &proof_refs.run_event_log_ref,
            RUN_EVENT_LOG_REF_PREFIX,
        ),
        (
            "answer_packet_ref",
            &proof_refs.answer_packet_ref,
            ANSWER_PACKET_REF_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            &proof_refs.compatibility_fence_ref,
            COMPATIBILITY_REF_PREFIX,
        ),
        (
            "native_link_block_ref",
            &proof_refs.native_link_block_ref,
            NATIVE_LINK_REF_PREFIX,
        ),
        (
            "benchmark_caveat_ref",
            &proof_refs.benchmark_caveat_ref,
            BENCHMARK_CAVEAT_PREFIX,
        ),
    ] {
        if field == "fetch_lease_ref" {
            if value != expected {
                return Err(TurboVecSourceManifestError::BadPrefix {
                    field,
                    value: value.clone(),
                    expected,
                });
            }
        } else if !value.starts_with(expected) {
            return Err(TurboVecSourceManifestError::BadPrefix {
                field,
                value: value.clone(),
                expected,
            });
        }
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(TurboVecSourceManifestError::MissingField("visible_summary"));
    }
    Ok(())
}

fn validate_byte_ledger(
    byte_ledger: &TurboVecSourceManifestByteLedger,
    source: &TurboVecSourceManifestSource,
) -> Result<(), TurboVecSourceManifestError> {
    if byte_ledger.github_tree_metadata_bytes_read == 0
        || byte_ledger.github_tree_metadata_bytes_read > MAX_TREE_METADATA_BYTES_READ
    {
        return Err(TurboVecSourceManifestError::InvalidByteLedger(
            "Git tree metadata bytes outside budget".to_string(),
        ));
    }
    if byte_ledger.declared_total_blob_bytes != source.total_blob_bytes {
        return Err(TurboVecSourceManifestError::InvalidByteLedger(
            "declared total blob bytes mismatch".to_string(),
        ));
    }
    for (name, value) in [
        ("raw_source_bytes_read", byte_ledger.raw_source_bytes_read),
        (
            "source_archive_bytes_fetched",
            byte_ledger.source_archive_bytes_fetched,
        ),
        (
            "local_quarantine_bytes_written",
            byte_ledger.local_quarantine_bytes_written,
        ),
        (
            "copied_product_file_count",
            byte_ledger.copied_product_file_count,
        ),
        (
            "product_dependency_count",
            byte_ledger.product_dependency_count,
        ),
        (
            "imported_external_crate_count",
            byte_ledger.imported_external_crate_count,
        ),
        (
            "built_external_binary_count",
            byte_ledger.built_external_binary_count,
        ),
        (
            "native_link_probe_count",
            byte_ledger.native_link_probe_count,
        ),
        (
            "opened_product_index_bytes",
            byte_ledger.opened_product_index_bytes,
        ),
        ("model_bytes_loaded", byte_ledger.model_bytes_loaded),
        (
            "runtime_model_bytes_loaded",
            byte_ledger.runtime_model_bytes_loaded,
        ),
        ("provider_calls_made", byte_ledger.provider_calls_made),
    ] {
        if value != 0 {
            return Err(TurboVecSourceManifestError::InvalidByteLedger(
                name.to_string(),
            ));
        }
    }
    Ok(())
}

fn deterministic_set_address(
    source: &TurboVecSourceManifestSource,
    entries: &[TurboVecSourceManifestEntry],
    buckets: &[TurboVecSourceManifestRootBucket],
) -> UasAddress {
    let mut parts = Vec::with_capacity(entries.len() + buckets.len() + 8);
    parts.push(source.source_ref.clone());
    parts.push(source.tree_api_url.clone());
    parts.push(source.pinned_revision.clone());
    parts.push(format!("entries:{}", source.tree_entry_count));
    parts.push(format!("blobs:{}", source.blob_count));
    parts.push(format!("bytes:{}", source.total_blob_bytes));
    for entry in entries {
        parts.push(format!(
            "{}:{}:{}:{}:{:?}",
            entry.path, entry.mode, entry.git_blob_sha, entry.byte_len, entry.disposition
        ));
    }
    for bucket in buckets {
        parts.push(format!("bucket:{}:{}", bucket.root, bucket.blob_count));
    }
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_source_byte_manifest_probe".to_string()),
        parts.join("\n").as_bytes(),
        1_779_040_902_000,
    )
}

pub fn source_byte_manifest_digest(set: &TurboVecRealAdapterSourceByteManifestProbeSet) -> String {
    sha256_hex(
        format!(
            "{}\n{}\n{}\n{}",
            set.set_address,
            set.source.tree_api_url,
            set.source.blob_count,
            set.source.total_blob_bytes
        )
        .as_bytes(),
    )
}

fn required_entry_expectations() -> Vec<(
    &'static str,
    (
        &'static str,
        u64,
        &'static str,
        TurboVecSourceManifestDisposition,
    ),
)> {
    use TurboVecSourceManifestDisposition::*;
    vec![
        (
            "LICENSE",
            (
                "e62ad7c6028ad9b2f9b4c1776dc7d4a9c942fced",
                1068,
                "100644",
                ProvenanceOnly,
            ),
        ),
        (
            "README.md",
            (
                "1bcd3121da5c5da47e2259adf1959f9df6af06ef",
                13593,
                "100644",
                DocumentationOnly,
            ),
        ),
        (
            "Cargo.toml",
            (
                "9bf15f9f5eba2de42db231e9235c4181f620277f",
                366,
                "100644",
                ProvenanceOnly,
            ),
        ),
        (
            "Cargo.lock",
            (
                "54548a61cb58347074bbbd78537439d75ab24a69",
                30548,
                "100644",
                ProvenanceOnly,
            ),
        ),
        (
            ".cargo/config.toml",
            (
                "530c5b457b211df82dcab3d6a8751c33b514f1ba",
                980,
                "100644",
                NativeLinkBlocked,
            ),
        ),
        (
            "benchmarks/rabitq_poc/recall_grid.png",
            (
                "39d79d4f328c4d6d1cfcb8588fb5b01220d95532",
                181829,
                "100644",
                BinaryAssetBlocked,
            ),
        ),
        (
            "benchmarks/suite/recall_d1536_4bit.py",
            (
                "d82cc28657b6348e7d60d19ddd9c889d7dec2d54",
                2737,
                "100644",
                BenchmarkClaimOnly,
            ),
        ),
        (
            "benchmarks/suite/speed_d1536_4bit_arm_mt.py",
            (
                "357e10e413956b86edf7276cf6fdcdd65a519acd",
                1662,
                "100644",
                BenchmarkClaimOnly,
            ),
        ),
        (
            "docs/api.md",
            (
                "a6f603985f39e8db9f917c55a3cef8903340ee82",
                8703,
                "100644",
                DocumentationOnly,
            ),
        ),
        (
            "examples/downstream-smoke/Cargo.toml",
            (
                "76ada77fc7c563a952d090e9e5d4302444eecb7a",
                522,
                "100644",
                TestFixtureCandidate,
            ),
        ),
        (
            "turbovec/Cargo.toml",
            (
                "b48103b6c8b826501d13cfde926d9e9d3f118953",
                1003,
                "100644",
                RustCoreCandidate,
            ),
        ),
        (
            "turbovec/build.rs",
            (
                "7695df94659cbdacbf2915956c18e29bea9a917d",
                917,
                "100644",
                NativeLinkBlocked,
            ),
        ),
        (
            "turbovec/src/lib.rs",
            (
                "46aa6d0e0ece49b37d9b3e2559f3657fe11dcbc0",
                31155,
                "100644",
                RustCoreCandidate,
            ),
        ),
        (
            "turbovec/src/search.rs",
            (
                "4fda9433ad90c55fb6fe339d75ccacbac9596140",
                75676,
                "100644",
                RustCoreCandidate,
            ),
        ),
        (
            "turbovec/src/id_map.rs",
            (
                "96e2444718c2f4d1f588bc2cc2f6623efef91de2",
                11984,
                "100644",
                RustCoreCandidate,
            ),
        ),
        (
            "turbovec/src/io.rs",
            (
                "452dcb433f6524ccb8837e6e7e1dc87fde4d3f06",
                9855,
                "100644",
                RustCoreCandidate,
            ),
        ),
        (
            "turbovec/tests/filtering.rs",
            (
                "c923e7c0af84641d8acfdba1f1ad68ef5fb8c8d2",
                16986,
                "100644",
                TestFixtureCandidate,
            ),
        ),
        (
            "turbovec/tests/input_validation.rs",
            (
                "664b8749f8eaeba961850d33fae432facf0356e5",
                7686,
                "100644",
                TestFixtureCandidate,
            ),
        ),
        (
            "turbovec-python/Cargo.toml",
            (
                "9cc4a980cfb37e6aaec85c30c8d36f1cdd5919b2",
                314,
                "100644",
                PythonBindingCandidate,
            ),
        ),
        (
            "turbovec-python/README.md",
            (
                "32d46ee883b58d6a383eed06eb98f33aa6530ded",
                12,
                "120000",
                SymlinkBlocked,
            ),
        ),
        (
            "turbovec-python/pyproject.toml",
            (
                "166cd434a337d3d861649b0aa7471b8920cec99c",
                1684,
                "100644",
                PythonBindingCandidate,
            ),
        ),
        (
            "turbovec-python/python/turbovec/llama_index.py",
            (
                "c259150dddd428d1e39046aa8d9b50f637c6e6a6",
                27928,
                "100644",
                IntegrationBlocked,
            ),
        ),
    ]
}

fn required_root_buckets() -> Vec<(&'static str, u64)> {
    vec![
        (".cargo", 1),
        (".claude", 1),
        (".github", 5),
        (".gitignore", 1),
        ("CHANGELOG.md", 1),
        ("CONTRIBUTING.md", 1),
        ("Cargo.lock", 1),
        ("Cargo.toml", 1),
        ("LICENSE", 1),
        ("README.md", 1),
        ("benchmarks", 106),
        ("docs", 14),
        ("examples", 3),
        ("turbovec", 27),
        ("turbovec-python", 16),
    ]
}

fn is_full_lower_hex_sha(value: &str) -> bool {
    value.len() == 40 && value.chars().all(|ch| matches!(ch, '0'..='9' | 'a'..='f'))
}

fn valid_relative_path(path: &str) -> bool {
    !path.is_empty()
        && !path.starts_with('/')
        && !path.contains('\\')
        && !path.contains('\0')
        && path
            .split('/')
            .all(|part| !part.is_empty() && part != "." && part != "..")
}

fn path_has_root(path: &str, root: &str) -> bool {
    path == root || path.starts_with(&format!("{root}/"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::str::FromStr;

    const UPSTREAM: &str =
        "turbovec_real_adapter_fetch_lease_probe:50f480573a411e7160b379655938b9185d6c192d062ee485ee01acbc85cb4b68@1779040901000";

    fn upstream() -> UasAddress {
        UasAddress::from_str(UPSTREAM).expect("valid upstream test address")
    }

    fn source() -> TurboVecSourceManifestSource {
        TurboVecSourceManifestSource {
            source_ref: format!("{SOURCE_REF_PREFIX}{PINNED_REVISION}"),
            source_url: SOURCE_URL.to_string(),
            tree_api_url: TREE_API_URL.to_string(),
            codeload_url: CODELOAD_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            current_head_revision: PINNED_REVISION.to_string(),
            tree_truncated: false,
            tree_entry_count: EXPECTED_TREE_ENTRY_COUNT,
            blob_count: EXPECTED_BLOB_COUNT,
            tree_node_count: EXPECTED_TREE_NODE_COUNT,
            total_blob_bytes: EXPECTED_TOTAL_BLOB_BYTES,
            quarantine_root: QUARANTINE_ROOT.to_string(),
        }
    }

    fn entries() -> Vec<TurboVecSourceManifestEntry> {
        required_entry_expectations()
            .into_iter()
            .map(
                |(path, (sha, byte_len, mode, disposition))| TurboVecSourceManifestEntry {
                    path: path.to_string(),
                    mode: mode.to_string(),
                    git_blob_sha: sha.to_string(),
                    byte_len,
                    disposition,
                    raw_content_read: false,
                    source_inspection_allowed_now: false,
                    product_import_allowed: false,
                    native_link_probe_allowed: false,
                },
            )
            .collect()
    }

    fn buckets() -> Vec<TurboVecSourceManifestRootBucket> {
        required_root_buckets()
            .into_iter()
            .map(|(root, blob_count)| TurboVecSourceManifestRootBucket {
                root: root.to_string(),
                blob_count,
                required_for_manifest: true,
            })
            .collect()
    }

    fn proof_refs() -> TurboVecSourceManifestProofRefs {
        TurboVecSourceManifestProofRefs {
            fetch_lease_ref: FETCH_LEASE_WITNESS_REF.to_string(),
            provenance_ref: format!("{PROVENANCE_REF_PREFIX}github-tree-metadata"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}delete-manifest-and-quarantine"),
            cleanup_ref: format!("{CLEANUP_REF_PREFIX}tree-manifest-expiry"),
            no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}no-cargo-or-build-membership"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}tree-metadata-only"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}visible-no-source-inspection"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}mas-pro-quarantine-only"),
            native_link_block_ref: format!("{NATIVE_LINK_REF_PREFIX}build-rs-and-cargo-config-blocked"),
            benchmark_caveat_ref: format!("{BENCHMARK_CAVEAT_PREFIX}benchmarks-non-authoritative"),
            visible_summary: "This source-byte manifest records GitHub tree metadata for the pinned TurboVec revision only. It binds file paths, modes, blob SHAs, aggregate counts, root buckets, and selected critical rows while leaving raw source content unread, source archives unfetched, quarantine files unwritten, product graphs untouched, native-link/build/runtime actions blocked, benchmark claims non-authoritative, model/index/runtime/provider bytes at zero, route authority absent, no hidden cloud fallback, no live dense 70B claim, and no SSD-as-RAM claim.".to_string(),
        }
    }

    fn accepted(
    ) -> Result<TurboVecRealAdapterSourceByteManifestProbeSet, TurboVecSourceManifestError> {
        TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source(),
            entries(),
            buckets(),
            TurboVecSourceManifestPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceManifestByteLedger::metadata_only(128_000),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
    }

    #[test]
    fn accepts_metadata_only_manifest() {
        let set = accepted().expect("accepted manifest");
        assert_eq!(set.metrics().required_entry_count, 22);
        assert_eq!(set.metrics().blob_count, 180);
        assert_eq!(set.metrics().raw_source_bytes_read, 0);
    }

    #[test]
    fn address_is_deterministic_when_inputs_are_reordered() {
        let accepted = accepted().expect("accepted manifest");
        let reordered = TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source(),
            entries().into_iter().rev().collect(),
            buckets().into_iter().rev().collect(),
            TurboVecSourceManifestPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceManifestByteLedger::metadata_only(128_000),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("reordered manifest");
        assert_eq!(accepted.set_address, reordered.set_address);
        assert_eq!(
            source_byte_manifest_digest(&accepted),
            source_byte_manifest_digest(&reordered)
        );
    }

    #[test]
    fn rejects_source_drift_and_missing_entry() {
        let mut source_card = source();
        source_card.blob_count = 179;
        let rejected = TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source_card,
            entries(),
            buckets(),
            TurboVecSourceManifestPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceManifestByteLedger::metadata_only(128_000),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());

        let mut entries = entries();
        entries.pop();
        let rejected = TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source(),
            entries,
            buckets(),
            TurboVecSourceManifestPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceManifestByteLedger::metadata_only(128_000),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());
    }

    #[test]
    fn rejects_source_bytes_and_policy_bypass() {
        let mut policy = TurboVecSourceManifestPolicy::fail_closed();
        policy.raw_content_read = true;
        let rejected = TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source(),
            entries(),
            buckets(),
            policy,
            proof_refs(),
            TurboVecSourceManifestByteLedger::metadata_only(128_000),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());

        let mut ledger = TurboVecSourceManifestByteLedger::metadata_only(128_000);
        ledger.raw_source_bytes_read = 1;
        let rejected = TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source(),
            entries(),
            buckets(),
            TurboVecSourceManifestPolicy::fail_closed(),
            proof_refs(),
            ledger,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());
    }

    #[test]
    fn rejects_product_promotion_and_route_authority() {
        let promoted = TurboVecRealAdapterSourceByteManifestProbeSet::from_parts(
            upstream(),
            source(),
            entries(),
            buckets(),
            TurboVecSourceManifestPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceManifestByteLedger::metadata_only(128_000),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceManifestStatus::MetadataOnlyManifest,
            TurboVecSourceManifestTier::T1L1Metadata,
            TurboVecSourceManifestKind::GitHubTreeMetadataOnly,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            true,
            true,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(promoted.is_err());
    }
}
