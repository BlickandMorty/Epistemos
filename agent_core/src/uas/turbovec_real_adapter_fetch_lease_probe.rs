//! TurboVec real-adapter quarantine fetch-lease probe.
//!
//! This primitive records the lease contract for a future bounded TurboVec
//! source fetch into the already-approved quarantine sandbox. It is
//! metadata-only: no repository, index, model, runtime, provider, or product
//! bytes are fetched, cloned, written, imported, built, or routed here.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_FETCH_LEASE_CURSOR: &str =
    "turbovec_quarantine_real_adapter_fetch_lease_probe";
pub const TURBOVEC_REAL_ADAPTER_FETCH_LEASE_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_source_byte_manifest_probe";

const SANDBOX_LAYOUT_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_sandbox_layout_probe:result";
const SANDBOX_LAYOUT_PREFIX: &str = "turbovec_real_adapter_sandbox_layout_probe:";
const SOURCE_REF_PREFIX: &str = "source:turbovec-fetch-lease:";
const FETCH_URL_PREFIX: &str = "https://codeload.github.com/RyanCodrai/turbovec/tar.gz/";
const CLONE_URL: &str = "https://github.com/RyanCodrai/turbovec.git";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const QUARANTINE_ROOT: &str =
    ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2";
const PROVENANCE_REF_PREFIX: &str = "provenance:turbovec-fetch-lease:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-fetch-lease:";
const CLEANUP_REF_PREFIX: &str = "cleanup:turbovec-fetch-lease:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-fetch-lease:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-fetch-lease:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-fetch-lease:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-fetch-lease:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-fetch-lease:";
const BENCHMARK_CAVEAT_PREFIX: &str = "benchmark_caveat:turbovec-fetch-lease:";
const MAX_LEASE_METADATA_BYTES: u64 = 2 * 1024 * 1024;
const MAX_PLANNED_DOWNLOAD_BYTES: u64 = 8 * 1024 * 1024;
const MAX_PLANNED_UNPACKED_BYTES: u64 = 32 * 1024 * 1024;
const MAX_PLANNED_FILE_COUNT: u64 = 2_000;
const MAX_LEASE_SECONDS: u64 = 30 * 60;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 300;

// UAS: uas:turbovec-real-adapter-fetch-lease:status
// Plane: Controller + Verification
// Residency: metadata-only fetch-lease status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFetchLeaseStatus {
    MetadataOnlyLease,
    Blocked,
    ExecutedByLaterWitness,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:tier
// Plane: Verification
// Residency: L1-only promotion boundary for the fetch lease.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFetchLeaseTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:transport
// Plane: Controller + Verification
// Residency: future source transport class, not executed here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFetchTransport {
    GitHubCodeloadTarball,
    GitHttpsClone,
    SshClone,
    LocalPathCopy,
    PackageRegistry,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:action
// Plane: Controller + Verification
// Residency: action declared by this witness; execution requires a later gate.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFetchLeaseAction {
    DeclareLeaseOnly,
    FetchArchiveByLaterWitness,
    GitCloneByLaterWitness,
    CopyIntoProduct,
    AddProductDependency,
    BuildAdapter,
    NativeLinkProbe,
    RuntimeRoute,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:phase
// Plane: Controller + Verification
// Residency: required future fetch-lease proof phases.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecFetchLeasePhase {
    LeaseDeclaration,
    OwnerApprovalPending,
    ByteCapPreflight,
    NoProductGraphAudit,
    CleanupReplay,
    AnswerPacketDryRun,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:source
// Plane: State + Verification
// Residency: source identity and fetch URL metadata; no network execution here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFetchLeaseSource {
    pub source_ref: String,
    pub source_url: String,
    pub clone_url: String,
    pub fetch_url: String,
    pub pinned_revision: String,
    pub current_head_revision: String,
    pub license_ref: String,
    pub commit_ref: String,
    pub transport: TurboVecFetchTransport,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:target
// Plane: State + Verification
// Residency: future quarantine paths; no files or dirs are created here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFetchLeaseTarget {
    pub quarantine_root: String,
    pub source_tree_path: String,
    pub temp_download_path: String,
    pub source_manifest_path: String,
    pub cleanup_tombstone_path: String,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:policy
// Plane: Controller + Verification
// Residency: fail-closed policy for future quarantine source fetch.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFetchLeasePolicy {
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub network_fetch_allowed_now: bool,
    pub future_fetch_requires_later_witness: bool,
    pub source_byte_manifest_required_after_fetch: bool,
    pub no_product_graph_membership: bool,
    pub no_product_dependency_insertion: bool,
    pub no_native_link_probe: bool,
    pub no_runtime_execution: bool,
    pub no_index_or_model_bytes: bool,
    pub cleanup_replay_required: bool,
    pub answer_packet_required: bool,
    pub max_download_bytes: u64,
    pub max_unpacked_bytes: u64,
    pub max_file_count: u64,
    pub lease_expires_after_seconds: u64,
    pub allowed_action: TurboVecFetchLeaseAction,
}

impl TurboVecFetchLeasePolicy {
    pub fn fail_closed() -> Self {
        Self {
            owner_approval_required: true,
            owner_approval_granted: false,
            network_fetch_allowed_now: false,
            future_fetch_requires_later_witness: true,
            source_byte_manifest_required_after_fetch: true,
            no_product_graph_membership: true,
            no_product_dependency_insertion: true,
            no_native_link_probe: true,
            no_runtime_execution: true,
            no_index_or_model_bytes: true,
            cleanup_replay_required: true,
            answer_packet_required: true,
            max_download_bytes: MAX_PLANNED_DOWNLOAD_BYTES,
            max_unpacked_bytes: MAX_PLANNED_UNPACKED_BYTES,
            max_file_count: MAX_PLANNED_FILE_COUNT,
            lease_expires_after_seconds: MAX_LEASE_SECONDS,
            allowed_action: TurboVecFetchLeaseAction::DeclareLeaseOnly,
        }
    }
}

// UAS: uas:turbovec-real-adapter-fetch-lease:byte-ledger
// Plane: Verification
// Residency: declared future byte caps; actual bytes remain zero here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFetchLeaseByteLedger {
    pub lease_metadata_bytes_read: u64,
    pub planned_download_bytes: u64,
    pub planned_unpacked_bytes: u64,
    pub downloaded_repo_bytes: u64,
    pub unpacked_repo_bytes: u64,
    pub written_quarantine_file_count: u64,
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

impl TurboVecFetchLeaseByteLedger {
    pub fn metadata_only(
        lease_metadata_bytes_read: u64,
        planned_download_bytes: u64,
        planned_unpacked_bytes: u64,
    ) -> Self {
        Self {
            lease_metadata_bytes_read,
            planned_download_bytes,
            planned_unpacked_bytes,
            downloaded_repo_bytes: 0,
            unpacked_repo_bytes: 0,
            written_quarantine_file_count: 0,
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

// UAS: uas:turbovec-real-adapter-fetch-lease:proof-refs
// Plane: Verification
// Residency: visible provenance, no-product-graph, rollback, and packet refs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecFetchLeaseProofRefs {
    pub sandbox_layout_ref: String,
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

// UAS: uas:turbovec-real-adapter-fetch-lease:set
// Plane: State + Assembly + Controller + Verification
// Residency: complete metadata-only fetch-lease witness set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterFetchLeaseProbeSet {
    pub set_address: UasAddress,
    pub upstream_sandbox_layout_address: UasAddress,
    pub upstream_sandbox_layout_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecFetchLeaseStatus,
    pub promotion_tier: TurboVecFetchLeaseTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub source: TurboVecFetchLeaseSource,
    pub target: TurboVecFetchLeaseTarget,
    pub phases: Vec<TurboVecFetchLeasePhase>,
    pub policy: TurboVecFetchLeasePolicy,
    pub proof_refs: TurboVecFetchLeaseProofRefs,
    pub byte_ledger: TurboVecFetchLeaseByteLedger,
    pub lease_metadata_bytes_read: u64,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-fetch-lease:metrics
// Plane: Verification
// Residency: aggregate counters for fetch-lease axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecFetchLeaseMetrics {
    pub phase_count: u64,
    pub planned_download_bytes: u64,
    pub planned_unpacked_bytes: u64,
    pub max_file_count: u64,
    pub lease_expires_after_seconds: u64,
    pub lease_metadata_bytes_read: u64,
    pub downloaded_repo_bytes: u64,
    pub unpacked_repo_bytes: u64,
    pub written_quarantine_file_count: u64,
    pub copied_product_file_count: u64,
    pub product_dependency_count: u64,
    pub imported_external_crate_count: u64,
    pub built_external_binary_count: u64,
    pub native_link_probe_count: u64,
    pub opened_product_index_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
}

impl TurboVecRealAdapterFetchLeaseProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_sandbox_layout_address: UasAddress,
        source: TurboVecFetchLeaseSource,
        target: TurboVecFetchLeaseTarget,
        mut phases: Vec<TurboVecFetchLeasePhase>,
        policy: TurboVecFetchLeasePolicy,
        proof_refs: TurboVecFetchLeaseProofRefs,
        byte_ledger: TurboVecFetchLeaseByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecFetchLeaseStatus,
        promotion_tier: TurboVecFetchLeaseTier,
        organs: Vec<TurboVecIndexOrgan>,
        lease_metadata_bytes_read: u64,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecFetchLeaseError> {
        phases.sort();
        validate_set_inputs(
            &upstream_sandbox_layout_address,
            &source,
            &target,
            &phases,
            &policy,
            &proof_refs,
            &byte_ledger,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            lease_metadata_bytes_read,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?;
        let set_address = deterministic_set_address(&source, &target, &phases, &policy);
        Ok(Self {
            set_address,
            upstream_sandbox_layout_address,
            upstream_sandbox_layout_witness_ref: SANDBOX_LAYOUT_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            source,
            target,
            phases,
            policy,
            proof_refs,
            byte_ledger,
            lease_metadata_bytes_read,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        })
    }

    pub fn metrics(&self) -> TurboVecFetchLeaseMetrics {
        TurboVecFetchLeaseMetrics {
            phase_count: self.phases.len() as u64,
            planned_download_bytes: self.byte_ledger.planned_download_bytes,
            planned_unpacked_bytes: self.byte_ledger.planned_unpacked_bytes,
            max_file_count: self.policy.max_file_count,
            lease_expires_after_seconds: self.policy.lease_expires_after_seconds,
            lease_metadata_bytes_read: self.byte_ledger.lease_metadata_bytes_read,
            downloaded_repo_bytes: self.byte_ledger.downloaded_repo_bytes,
            unpacked_repo_bytes: self.byte_ledger.unpacked_repo_bytes,
            written_quarantine_file_count: self.byte_ledger.written_quarantine_file_count,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            product_dependency_count: self.byte_ledger.product_dependency_count,
            imported_external_crate_count: self.byte_ledger.imported_external_crate_count,
            built_external_binary_count: self.byte_ledger.built_external_binary_count,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            opened_product_index_bytes: self.byte_ledger.opened_product_index_bytes,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            route_mutation_count: u64::from(self.route_mutation_allowed),
            model_context_injection_count: u64::from(self.model_context_injected),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
        }
    }
}

// UAS: uas:turbovec-real-adapter-fetch-lease:error
// Plane: Verification
// Residency: validation failures for unsafe fetch-lease states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecFetchLeaseError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecFetchLeaseStatus),
    BadPromotionTier(TurboVecFetchLeaseTier),
    MetadataBudgetExceeded(u64),
    InvalidOrgans,
    InvalidSource(String),
    InvalidTarget(String),
    InvalidPhase(String),
    InvalidPolicy(String),
    ProductPromotionAllowed,
    ForbiddenAuthority(String),
    MissingField(&'static str),
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    ExternalBytesTouched(String),
}

impl fmt::Display for TurboVecFetchLeaseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "upstream sandbox-layout cursor mismatch"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad fetch-lease status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad fetch-lease tier: {tier:?}"),
            Self::MetadataBudgetExceeded(bytes) => write!(f, "metadata budget exceeded: {bytes}"),
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidSource(reason) => write!(f, "invalid fetch-lease source: {reason}"),
            Self::InvalidTarget(reason) => write!(f, "invalid fetch-lease target: {reason}"),
            Self::InvalidPhase(reason) => write!(f, "invalid fetch-lease phase: {reason}"),
            Self::InvalidPolicy(reason) => write!(f, "invalid fetch-lease policy: {reason}"),
            Self::ProductPromotionAllowed => write!(f, "product promotion attempted"),
            Self::ForbiddenAuthority(reason) => write!(f, "forbidden authority: {reason}"),
            Self::MissingField(field) => write!(f, "missing field: {field}"),
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(f, "{field} `{value}` must start with `{expected}`"),
            Self::ExternalBytesTouched(reason) => write!(f, "external bytes touched: {reason}"),
        }
    }
}

impl std::error::Error for TurboVecFetchLeaseError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_sandbox_layout_address: &UasAddress,
    source: &TurboVecFetchLeaseSource,
    target: &TurboVecFetchLeaseTarget,
    phases: &[TurboVecFetchLeasePhase],
    policy: &TurboVecFetchLeasePolicy,
    proof_refs: &TurboVecFetchLeaseProofRefs,
    byte_ledger: &TurboVecFetchLeaseByteLedger,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecFetchLeaseStatus,
    promotion_tier: &TurboVecFetchLeaseTier,
    organs: &[TurboVecIndexOrgan],
    lease_metadata_bytes_read: u64,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<(), TurboVecFetchLeaseError> {
    if !upstream_sandbox_layout_address
        .to_string()
        .starts_with(SANDBOX_LAYOUT_PREFIX)
    {
        return Err(TurboVecFetchLeaseError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecFetchLeaseError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecFetchLeaseError::BadProStatus(pro_status.clone()));
    }
    if status != &TurboVecFetchLeaseStatus::MetadataOnlyLease {
        return Err(TurboVecFetchLeaseError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecFetchLeaseTier::T1L1Metadata {
        return Err(TurboVecFetchLeaseError::BadPromotionTier(*promotion_tier));
    }
    if lease_metadata_bytes_read > MAX_LEASE_METADATA_BYTES {
        return Err(TurboVecFetchLeaseError::MetadataBudgetExceeded(
            lease_metadata_bytes_read,
        ));
    }
    if byte_ledger.lease_metadata_bytes_read != lease_metadata_bytes_read {
        return Err(TurboVecFetchLeaseError::ExternalBytesTouched(
            "lease metadata ledger mismatch".to_string(),
        ));
    }
    if product_capability_promoted {
        return Err(TurboVecFetchLeaseError::ProductPromotionAllowed);
    }
    if route_mutation_allowed
        || model_context_injected
        || hidden_route_authority
        || hidden_cloud_fallback_allowed
        || live_large_model_claimed
        || ssd_as_ram_claimed
    {
        return Err(TurboVecFetchLeaseError::ForbiddenAuthority(
            "route/context/hidden/cloud/large-model claim attempted".to_string(),
        ));
    }
    validate_organs(organs)?;
    validate_source(source)?;
    validate_target(target)?;
    validate_phases(phases)?;
    validate_policy(policy)?;
    validate_proof_refs(proof_refs)?;
    validate_byte_ledger(byte_ledger)?;
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecFetchLeaseError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let seen: HashSet<_> = organs.iter().copied().collect();
    if seen.len() != organs.len() || required.iter().any(|organ| !seen.contains(organ)) {
        return Err(TurboVecFetchLeaseError::InvalidOrgans);
    }
    Ok(())
}

fn validate_source(source: &TurboVecFetchLeaseSource) -> Result<(), TurboVecFetchLeaseError> {
    if !source.source_ref.starts_with(SOURCE_REF_PREFIX) {
        return Err(TurboVecFetchLeaseError::BadPrefix {
            field: "source_ref",
            value: source.source_ref.clone(),
            expected: SOURCE_REF_PREFIX,
        });
    }
    if source.source_url != SOURCE_URL {
        return Err(TurboVecFetchLeaseError::InvalidSource(
            "source URL must be the pinned upstream GitHub repo".to_string(),
        ));
    }
    if source.clone_url != CLONE_URL {
        return Err(TurboVecFetchLeaseError::InvalidSource(
            "clone URL must be the HTTPS upstream clone URL".to_string(),
        ));
    }
    if !source.fetch_url.starts_with(FETCH_URL_PREFIX)
        || !source.fetch_url.ends_with(PINNED_REVISION)
    {
        return Err(TurboVecFetchLeaseError::BadPrefix {
            field: "fetch_url",
            value: source.fetch_url.clone(),
            expected: FETCH_URL_PREFIX,
        });
    }
    if source.pinned_revision != PINNED_REVISION || !is_full_lower_hex_sha(&source.pinned_revision)
    {
        return Err(TurboVecFetchLeaseError::InvalidSource(
            "pinned revision must be full 40-char lowercase SHA".to_string(),
        ));
    }
    if source.current_head_revision != source.pinned_revision {
        return Err(TurboVecFetchLeaseError::InvalidSource(
            "current head must match pinned revision in this metadata fixture".to_string(),
        ));
    }
    if !source.license_ref.starts_with("license:turbovec:mit:") {
        return Err(TurboVecFetchLeaseError::BadPrefix {
            field: "license_ref",
            value: source.license_ref.clone(),
            expected: "license:turbovec:mit:",
        });
    }
    if !source.commit_ref.starts_with("github_commit:turbovec:") {
        return Err(TurboVecFetchLeaseError::BadPrefix {
            field: "commit_ref",
            value: source.commit_ref.clone(),
            expected: "github_commit:turbovec:",
        });
    }
    if source.transport != TurboVecFetchTransport::GitHubCodeloadTarball {
        return Err(TurboVecFetchLeaseError::InvalidSource(
            "only GitHub codeload tarball is lease-declared here".to_string(),
        ));
    }
    Ok(())
}

fn validate_target(target: &TurboVecFetchLeaseTarget) -> Result<(), TurboVecFetchLeaseError> {
    for (field, path) in [
        ("quarantine_root", &target.quarantine_root),
        ("source_tree_path", &target.source_tree_path),
        ("temp_download_path", &target.temp_download_path),
        ("source_manifest_path", &target.source_manifest_path),
        ("cleanup_tombstone_path", &target.cleanup_tombstone_path),
    ] {
        if !valid_relative_path(path) {
            return Err(TurboVecFetchLeaseError::InvalidTarget(format!(
                "{field} must be normalized relative path"
            )));
        }
    }
    if target.quarantine_root != QUARANTINE_ROOT {
        return Err(TurboVecFetchLeaseError::InvalidTarget(
            "quarantine root must match sandbox-layout root".to_string(),
        ));
    }
    for path in [
        &target.source_tree_path,
        &target.temp_download_path,
        &target.source_manifest_path,
        &target.cleanup_tombstone_path,
    ] {
        if !path.starts_with(&format!("{QUARANTINE_ROOT}/")) {
            return Err(TurboVecFetchLeaseError::InvalidTarget(
                "target path outside quarantine root".to_string(),
            ));
        }
        for forbidden in [
            "agent_core",
            "Epistemos",
            "graph-engine",
            "Tools",
            "docs",
            "artifacts/falsifiers",
            "benchmarks/results",
            "target",
            ".git",
        ] {
            if path_has_root(path, forbidden) {
                return Err(TurboVecFetchLeaseError::InvalidTarget(format!(
                    "target touches forbidden root {forbidden}"
                )));
            }
        }
    }
    let mut unique = HashSet::new();
    for path in [
        &target.source_tree_path,
        &target.temp_download_path,
        &target.source_manifest_path,
        &target.cleanup_tombstone_path,
    ] {
        if !unique.insert(path.clone()) {
            return Err(TurboVecFetchLeaseError::InvalidTarget(
                "target paths must be unique".to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_phases(phases: &[TurboVecFetchLeasePhase]) -> Result<(), TurboVecFetchLeaseError> {
    let required = [
        TurboVecFetchLeasePhase::LeaseDeclaration,
        TurboVecFetchLeasePhase::OwnerApprovalPending,
        TurboVecFetchLeasePhase::ByteCapPreflight,
        TurboVecFetchLeasePhase::NoProductGraphAudit,
        TurboVecFetchLeasePhase::CleanupReplay,
        TurboVecFetchLeasePhase::AnswerPacketDryRun,
    ];
    let seen: HashSet<_> = phases.iter().copied().collect();
    if seen.len() != phases.len() || required.iter().any(|phase| !seen.contains(phase)) {
        return Err(TurboVecFetchLeaseError::InvalidPhase(
            "fetch-lease phases missing or duplicated".to_string(),
        ));
    }
    Ok(())
}

fn validate_policy(policy: &TurboVecFetchLeasePolicy) -> Result<(), TurboVecFetchLeaseError> {
    let required_true = [
        policy.owner_approval_required,
        policy.future_fetch_requires_later_witness,
        policy.source_byte_manifest_required_after_fetch,
        policy.no_product_graph_membership,
        policy.no_product_dependency_insertion,
        policy.no_native_link_probe,
        policy.no_runtime_execution,
        policy.no_index_or_model_bytes,
        policy.cleanup_replay_required,
        policy.answer_packet_required,
    ];
    if required_true.iter().any(|flag| !flag) {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "all fail-closed true flags must be set".to_string(),
        ));
    }
    if policy.owner_approval_granted || policy.network_fetch_allowed_now {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "owner approval and network fetch must remain false in this witness".to_string(),
        ));
    }
    if policy.max_download_bytes == 0 || policy.max_download_bytes > MAX_PLANNED_DOWNLOAD_BYTES {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "download byte cap is outside accepted range".to_string(),
        ));
    }
    if policy.max_unpacked_bytes < policy.max_download_bytes
        || policy.max_unpacked_bytes > MAX_PLANNED_UNPACKED_BYTES
    {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "unpacked byte cap is outside accepted range".to_string(),
        ));
    }
    if policy.max_file_count == 0 || policy.max_file_count > MAX_PLANNED_FILE_COUNT {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "file-count cap is outside accepted range".to_string(),
        ));
    }
    if policy.lease_expires_after_seconds == 0
        || policy.lease_expires_after_seconds > MAX_LEASE_SECONDS
    {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "lease expiry is outside accepted range".to_string(),
        ));
    }
    if policy.allowed_action != TurboVecFetchLeaseAction::DeclareLeaseOnly {
        return Err(TurboVecFetchLeaseError::InvalidPolicy(
            "this witness may declare only, not execute fetch/build/runtime actions".to_string(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    proof_refs: &TurboVecFetchLeaseProofRefs,
) -> Result<(), TurboVecFetchLeaseError> {
    for (field, value, expected) in [
        (
            "sandbox_layout_ref",
            &proof_refs.sandbox_layout_ref,
            SANDBOX_LAYOUT_WITNESS_REF,
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
        if field == "sandbox_layout_ref" {
            if value != expected {
                return Err(TurboVecFetchLeaseError::BadPrefix {
                    field,
                    value: value.clone(),
                    expected,
                });
            }
        } else if !value.starts_with(expected) {
            return Err(TurboVecFetchLeaseError::BadPrefix {
                field,
                value: value.clone(),
                expected,
            });
        }
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(TurboVecFetchLeaseError::MissingField("visible_summary"));
    }
    Ok(())
}

fn validate_byte_ledger(
    byte_ledger: &TurboVecFetchLeaseByteLedger,
) -> Result<(), TurboVecFetchLeaseError> {
    if byte_ledger.lease_metadata_bytes_read > MAX_LEASE_METADATA_BYTES {
        return Err(TurboVecFetchLeaseError::MetadataBudgetExceeded(
            byte_ledger.lease_metadata_bytes_read,
        ));
    }
    if byte_ledger.planned_download_bytes == 0
        || byte_ledger.planned_download_bytes > MAX_PLANNED_DOWNLOAD_BYTES
    {
        return Err(TurboVecFetchLeaseError::ExternalBytesTouched(
            "planned download bytes outside cap".to_string(),
        ));
    }
    if byte_ledger.planned_unpacked_bytes < byte_ledger.planned_download_bytes
        || byte_ledger.planned_unpacked_bytes > MAX_PLANNED_UNPACKED_BYTES
    {
        return Err(TurboVecFetchLeaseError::ExternalBytesTouched(
            "planned unpacked bytes outside cap".to_string(),
        ));
    }
    for (name, value) in [
        ("downloaded_repo_bytes", byte_ledger.downloaded_repo_bytes),
        ("unpacked_repo_bytes", byte_ledger.unpacked_repo_bytes),
        (
            "written_quarantine_file_count",
            byte_ledger.written_quarantine_file_count,
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
            return Err(TurboVecFetchLeaseError::ExternalBytesTouched(
                name.to_string(),
            ));
        }
    }
    Ok(())
}

fn deterministic_set_address(
    source: &TurboVecFetchLeaseSource,
    target: &TurboVecFetchLeaseTarget,
    phases: &[TurboVecFetchLeasePhase],
    policy: &TurboVecFetchLeasePolicy,
) -> UasAddress {
    let mut parts = Vec::with_capacity(phases.len() + 12);
    parts.push(source.source_ref.clone());
    parts.push(source.fetch_url.clone());
    parts.push(source.pinned_revision.clone());
    parts.push(target.quarantine_root.clone());
    parts.push(target.source_tree_path.clone());
    parts.push(target.temp_download_path.clone());
    parts.push(target.source_manifest_path.clone());
    for phase in phases {
        parts.push(format!("phase:{phase:?}"));
    }
    parts.push(format!("max_download:{}", policy.max_download_bytes));
    parts.push(format!("max_unpacked:{}", policy.max_unpacked_bytes));
    parts.push(format!("expires:{}", policy.lease_expires_after_seconds));
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_fetch_lease_probe".to_string()),
        parts.join("\n").as_bytes(),
        1_779_040_901_000,
    )
}

pub fn fetch_lease_digest(set: &TurboVecRealAdapterFetchLeaseProbeSet) -> String {
    sha256_hex(
        format!(
            "{}\n{}\n{}\n{}",
            set.set_address,
            set.source.fetch_url,
            set.target.source_tree_path,
            set.policy.max_download_bytes
        )
        .as_bytes(),
    )
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
        "turbovec_real_adapter_sandbox_layout_probe:ade4603f6f4bd86da82abff1e5332957033d0e1b1d00142924736a12b68fd69f@1779040900000";

    fn upstream() -> UasAddress {
        UasAddress::from_str(UPSTREAM).expect("valid upstream test address")
    }

    fn source() -> TurboVecFetchLeaseSource {
        TurboVecFetchLeaseSource {
            source_ref: format!("{SOURCE_REF_PREFIX}{PINNED_REVISION}"),
            source_url: SOURCE_URL.to_string(),
            clone_url: CLONE_URL.to_string(),
            fetch_url: format!("{FETCH_URL_PREFIX}{PINNED_REVISION}"),
            pinned_revision: PINNED_REVISION.to_string(),
            current_head_revision: PINNED_REVISION.to_string(),
            license_ref: format!("license:turbovec:mit:{PINNED_REVISION}"),
            commit_ref: format!("github_commit:turbovec:{PINNED_REVISION}"),
            transport: TurboVecFetchTransport::GitHubCodeloadTarball,
        }
    }

    fn target() -> TurboVecFetchLeaseTarget {
        TurboVecFetchLeaseTarget {
            quarantine_root: QUARANTINE_ROOT.to_string(),
            source_tree_path: format!("{QUARANTINE_ROOT}/source-tree"),
            temp_download_path: format!("{QUARANTINE_ROOT}/source-tree.tmp"),
            source_manifest_path: format!("{QUARANTINE_ROOT}/source-manifest.json"),
            cleanup_tombstone_path: format!("{QUARANTINE_ROOT}/cleanup-tombstones/fetch-lease"),
        }
    }

    fn phases() -> Vec<TurboVecFetchLeasePhase> {
        vec![
            TurboVecFetchLeasePhase::LeaseDeclaration,
            TurboVecFetchLeasePhase::OwnerApprovalPending,
            TurboVecFetchLeasePhase::ByteCapPreflight,
            TurboVecFetchLeasePhase::NoProductGraphAudit,
            TurboVecFetchLeasePhase::CleanupReplay,
            TurboVecFetchLeasePhase::AnswerPacketDryRun,
        ]
    }

    fn proof_refs() -> TurboVecFetchLeaseProofRefs {
        TurboVecFetchLeaseProofRefs {
            sandbox_layout_ref: SANDBOX_LAYOUT_WITNESS_REF.to_string(),
            provenance_ref: format!("{PROVENANCE_REF_PREFIX}source-card-clean-room"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}delete-quarantine-fetch"),
            cleanup_ref: format!("{CLEANUP_REF_PREFIX}replay-before-any-import"),
            no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}cargo-build-route-excluded"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}fetch-lease-dry-run"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}visible-fetch-not-executed"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}mas-pro-excluded"),
            native_link_block_ref: format!("{NATIVE_LINK_REF_PREFIX}blocked-until-source-manifest"),
            benchmark_caveat_ref: format!("{BENCHMARK_CAVEAT_PREFIX}no-speed-quality-claim"),
            visible_summary: "This fetch lease records a future bounded TurboVec source archive fetch into quarantine only. Owner approval is pending, network fetch is not allowed by this witness, product graphs stay excluded, cleanup replay and AnswerPacket proof are required, native-link/build/runtime actions remain blocked, and no model/index/runtime/provider bytes or route authority are granted.".to_string(),
        }
    }

    fn byte_ledger() -> TurboVecFetchLeaseByteLedger {
        TurboVecFetchLeaseByteLedger::metadata_only(
            112_000,
            MAX_PLANNED_DOWNLOAD_BYTES,
            MAX_PLANNED_UNPACKED_BYTES,
        )
    }

    fn organs() -> Vec<TurboVecIndexOrgan> {
        vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ]
    }

    fn accepted() -> Result<TurboVecRealAdapterFetchLeaseProbeSet, TurboVecFetchLeaseError> {
        TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            target(),
            phases(),
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
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
    fn accepts_metadata_only_fetch_lease() {
        let set = accepted().expect("accepted fetch lease");
        let metrics = set.metrics();
        assert_eq!(metrics.phase_count, 6);
        assert_eq!(metrics.downloaded_repo_bytes, 0);
        assert!(fetch_lease_digest(&set).starts_with("sha256:"));
    }

    #[test]
    fn address_is_deterministic_when_phases_are_reordered() {
        let accepted = accepted().expect("accepted fetch lease");
        let mut reversed = phases();
        reversed.reverse();
        let reordered = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            target(),
            reversed,
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("reordered fetch lease");
        assert_eq!(accepted.set_address, reordered.set_address);
    }

    #[test]
    fn rejects_bad_source_and_target() {
        let mut bad_source = source();
        bad_source.fetch_url = "https://github.com/RyanCodrai/turbovec/archive/main.tar.gz".into();
        let rejected = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            bad_source,
            target(),
            phases(),
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());

        let mut bad_target = target();
        bad_target.source_tree_path = "agent_core/src/turbovec".into();
        let rejected = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            bad_target,
            phases(),
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
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
    fn rejects_network_execution_and_bytes() {
        let mut policy = TurboVecFetchLeasePolicy::fail_closed();
        policy.network_fetch_allowed_now = true;
        let rejected = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            target(),
            phases(),
            policy,
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());

        let mut ledger = byte_ledger();
        ledger.downloaded_repo_bytes = 1;
        let rejected = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            target(),
            phases(),
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            ledger,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
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
        let rejected = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            target(),
            phases(),
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());

        let rejected = TurboVecRealAdapterFetchLeaseProbeSet::from_parts(
            upstream(),
            source(),
            target(),
            phases(),
            TurboVecFetchLeasePolicy::fail_closed(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecFetchLeaseStatus::MetadataOnlyLease,
            TurboVecFetchLeaseTier::T1L1Metadata,
            organs(),
            112_000,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());
    }
}
