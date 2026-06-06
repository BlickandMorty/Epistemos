//! TurboVec real-adapter dependency-envelope probe.
//!
//! This primitive records the dependency/build envelope for the pinned
//! TurboVec source revision as metadata-only proof. It permits manifest
//! inspection and dependency planning, but still forbids clone/fetch,
//! product dependency insertion, source import, adapter builds, route
//! mutation, index/model bytes, and provider calls.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_CURSOR: &str =
    "turbovec_quarantine_real_adapter_dependency_envelope_probe";
pub const TURBOVEC_REAL_ADAPTER_DEPENDENCY_ENVELOPE_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_sandbox_layout_probe";

const SOURCE_PIN_WITNESS_REF: &str = "artifact:turbovec_real_adapter_source_pin_probe:result";
const SOURCE_PIN_PREFIX: &str = "source_pin:pinned_metadata_only:";
const MANIFEST_REF_PREFIX: &str = "github_manifest:turbovec:";
const DEPENDENCY_REF_PREFIX: &str = "dependency_manifest:turbovec-envelope:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-envelope:";
const QUARANTINE_REF_PREFIX: &str = "quarantine_path:turbovec-envelope:";
const PROVENANCE_REF_PREFIX: &str = "provenance:turbovec-envelope:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-envelope:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-envelope:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-envelope:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-envelope:";
const BENCHMARK_CAVEAT_PREFIX: &str = "benchmark_caveat:turbovec-envelope:";
const MAX_METADATA_BYTES: u64 = 2 * 1024 * 1024;
const MIN_MANIFESTS: usize = 8;
const MIN_DEPENDENCIES: usize = 18;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 260;

// UAS: uas:turbovec-real-adapter-dependency-envelope:status
// Plane: Controller + Verification
// Residency: metadata-only source/dependency envelope status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecDependencyEnvelopeStatus {
    MetadataOnly,
    Blocked,
    RuntimeApprovedByLaterWitness,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:tier
// Plane: Verification
// Residency: L1-only promotion boundary for the dependency envelope.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecDependencyEnvelopeTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:action
// Plane: Controller + Verification
// Residency: allowed future action, fail-closed to metadata-only here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecDependencyEnvelopeAction {
    MetadataOnly,
    FetchQuarantineBytes,
    AddProductDependency,
    BuildAdapter,
    RuntimeRoute,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:manifest-kind
// Plane: State + Verification
// Residency: pinned manifest class for future quarantine planning.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecManifestKind {
    RootWorkspaceCargo,
    RustCoreCargo,
    RustBuildScript,
    PythonCargo,
    PythonPyProject,
    CargoConfig,
    CargoLock,
    DownstreamSmokeCargo,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:dependency-class
// Plane: State + Assembly + Verification
// Residency: dependency/native-link/codegen class, metadata-only here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecDependencyClass {
    RustCoreCrate,
    TargetSpecificRustCrate,
    NativeLink,
    PythonBuildBackend,
    PythonBindingCrate,
    PythonRuntimePackage,
    PythonOptionalIntegration,
    DownstreamSmokePath,
    CodegenConfig,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:manifest
// Plane: State + Verification
// Residency: SHA-bound external manifest metadata; no source bytes fetched.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecDependencyManifest {
    pub manifest_id: String,
    pub kind: TurboVecManifestKind,
    pub path: String,
    pub sha: String,
    pub size_bytes: u64,
    pub manifest_ref: String,
    pub required: bool,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:dependency-record
// Plane: State + Assembly + Verification
// Residency: dependency record metadata; no product dependency insertion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecDependencyRecord {
    pub dependency_id: String,
    // UAS-EXEMPT: field belongs to the parent dependency-record UAS shape.
    pub class: TurboVecDependencyClass,
    pub package_name: String,
    pub version_req: String,
    pub manifest_id: String,
    pub target_scope: String,
    pub optional: bool,
    pub feature_refs: Vec<String>,
    pub risk_ref: String,
    pub allowed_action: TurboVecDependencyEnvelopeAction,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:byte-ledger
// Plane: Verification
// Residency: metadata/read-only ledger; runtime and product bytes remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecDependencyEnvelopeByteLedger {
    pub github_manifest_metadata_bytes_read: u64,
    pub raw_manifest_bytes_read: u64,
    pub planned_quarantine_bytes: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
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

impl TurboVecDependencyEnvelopeByteLedger {
    pub fn metadata_only(
        github_manifest_metadata_bytes_read: u64,
        raw_manifest_bytes_read: u64,
        planned_quarantine_bytes: u64,
    ) -> Self {
        Self {
            github_manifest_metadata_bytes_read,
            raw_manifest_bytes_read,
            planned_quarantine_bytes,
            fetched_repo_bytes: 0,
            cloned_repo_bytes: 0,
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

// UAS: uas:turbovec-real-adapter-dependency-envelope:policy
// Plane: Controller + Verification
// Residency: fail-closed policy before any sandbox, import, build, or route.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecDependencyEnvelopePolicy {
    pub source_pin_required: bool,
    pub all_manifests_sha_bound: bool,
    pub dependency_records_required: bool,
    pub cargo_lock_record_required: bool,
    pub native_link_boundary_required: bool,
    pub downstream_smoke_visible_required: bool,
    pub python_binding_boundary_required: bool,
    pub optional_integrations_denied_product_default: bool,
    pub quarantine_path_required: bool,
    pub clean_room_provenance_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub benchmark_caveat_required: bool,
    pub no_fetch_clone_import_build_or_route: bool,
    pub no_product_dependency_insertion: bool,
    pub no_model_or_provider_bytes: bool,
}

impl TurboVecDependencyEnvelopePolicy {
    pub fn fail_closed() -> Self {
        Self {
            source_pin_required: true,
            all_manifests_sha_bound: true,
            dependency_records_required: true,
            cargo_lock_record_required: true,
            native_link_boundary_required: true,
            downstream_smoke_visible_required: true,
            python_binding_boundary_required: true,
            optional_integrations_denied_product_default: true,
            quarantine_path_required: true,
            clean_room_provenance_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            benchmark_caveat_required: true,
            no_fetch_clone_import_build_or_route: true,
            no_product_dependency_insertion: true,
            no_model_or_provider_bytes: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:proof-refs
// Plane: Verification
// Residency: visible rollback/log/AnswerPacket/provenance references.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecDependencyEnvelopeProofRefs {
    pub source_pin_ref: String,
    pub dependency_manifest_ref: String,
    pub native_link_ref: String,
    pub quarantine_path_ref: String,
    pub provenance_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub benchmark_caveat_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:set
// Plane: State + Assembly + Controller + Verification
// Residency: complete metadata-only dependency envelope witness set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterDependencyEnvelopeProbeSet {
    pub set_address: UasAddress,
    pub upstream_source_pin_address: UasAddress,
    pub upstream_source_pin_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecDependencyEnvelopeStatus,
    pub promotion_tier: TurboVecDependencyEnvelopeTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecDependencyEnvelopePolicy,
    pub manifests: Vec<TurboVecDependencyManifest>,
    pub dependencies: Vec<TurboVecDependencyRecord>,
    pub proof_refs: TurboVecDependencyEnvelopeProofRefs,
    pub byte_ledger: TurboVecDependencyEnvelopeByteLedger,
    pub metadata_bytes_read: u64,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:metrics
// Plane: Verification
// Residency: aggregate counters for metadata-only witness axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecDependencyEnvelopeMetrics {
    pub manifest_count: u64,
    pub dependency_record_count: u64,
    pub rust_core_dependency_count: u64,
    pub target_specific_dependency_count: u64,
    pub native_link_count: u64,
    pub python_boundary_count: u64,
    pub optional_python_integration_count: u64,
    pub downstream_smoke_count: u64,
    pub unique_manifest_sha_count: u64,
    pub planned_quarantine_bytes: u64,
    pub raw_manifest_bytes_read: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
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

impl TurboVecRealAdapterDependencyEnvelopeProbeSet {
    pub fn from_parts(
        upstream_source_pin_address: UasAddress,
        mut manifests: Vec<TurboVecDependencyManifest>,
        mut dependencies: Vec<TurboVecDependencyRecord>,
        proof_refs: TurboVecDependencyEnvelopeProofRefs,
        byte_ledger: TurboVecDependencyEnvelopeByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecDependencyEnvelopeStatus,
        promotion_tier: TurboVecDependencyEnvelopeTier,
        organs: Vec<TurboVecIndexOrgan>,
        policy: TurboVecDependencyEnvelopePolicy,
        metadata_bytes_read: u64,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecDependencyEnvelopeError> {
        manifests.sort_by(|left, right| left.manifest_id.cmp(&right.manifest_id));
        dependencies.sort_by(|left, right| left.dependency_id.cmp(&right.dependency_id));
        validate_set_inputs(
            &upstream_source_pin_address,
            &manifests,
            &dependencies,
            &proof_refs,
            &byte_ledger,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            &policy,
            metadata_bytes_read,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?;
        validate_manifests(&manifests)?;
        validate_dependencies(&dependencies, &manifests)?;
        validate_proof_refs(&proof_refs)?;
        validate_byte_ledger(&byte_ledger)?;
        let set_address = deterministic_set_address(&manifests, &dependencies, metadata_bytes_read);
        Ok(Self {
            set_address,
            upstream_source_pin_address,
            upstream_source_pin_witness_ref: SOURCE_PIN_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            policy,
            manifests,
            dependencies,
            proof_refs,
            byte_ledger,
            metadata_bytes_read,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        })
    }

    pub fn metrics(&self) -> TurboVecDependencyEnvelopeMetrics {
        let mut unique_manifest_shas = HashSet::new();
        let mut metrics = TurboVecDependencyEnvelopeMetrics {
            manifest_count: self.manifests.len() as u64,
            dependency_record_count: self.dependencies.len() as u64,
            planned_quarantine_bytes: self.byte_ledger.planned_quarantine_bytes,
            raw_manifest_bytes_read: self.byte_ledger.raw_manifest_bytes_read,
            fetched_repo_bytes: self.byte_ledger.fetched_repo_bytes,
            cloned_repo_bytes: self.byte_ledger.cloned_repo_bytes,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            product_dependency_count: self.byte_ledger.product_dependency_count,
            imported_external_crate_count: self.byte_ledger.imported_external_crate_count,
            built_external_binary_count: self.byte_ledger.built_external_binary_count,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            opened_product_index_bytes: self.byte_ledger.opened_product_index_bytes,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            ..TurboVecDependencyEnvelopeMetrics::default()
        };
        for manifest in &self.manifests {
            unique_manifest_shas.insert(manifest.sha.clone());
            if manifest.kind == TurboVecManifestKind::DownstreamSmokeCargo {
                metrics.downstream_smoke_count += 1;
            }
        }
        for dep in &self.dependencies {
            match dep.class {
                TurboVecDependencyClass::RustCoreCrate => metrics.rust_core_dependency_count += 1,
                TurboVecDependencyClass::TargetSpecificRustCrate => {
                    metrics.target_specific_dependency_count += 1;
                }
                TurboVecDependencyClass::NativeLink => metrics.native_link_count += 1,
                TurboVecDependencyClass::PythonBuildBackend
                | TurboVecDependencyClass::PythonBindingCrate
                | TurboVecDependencyClass::PythonRuntimePackage => {
                    metrics.python_boundary_count += 1;
                }
                TurboVecDependencyClass::PythonOptionalIntegration => {
                    metrics.optional_python_integration_count += 1;
                }
                TurboVecDependencyClass::DownstreamSmokePath
                | TurboVecDependencyClass::CodegenConfig => {}
            }
        }
        metrics.unique_manifest_sha_count = unique_manifest_shas.len() as u64;
        if self.route_mutation_allowed {
            metrics.route_mutation_count += 1;
        }
        if self.model_context_injected {
            metrics.model_context_injection_count += 1;
        }
        if self.hidden_route_authority || self.hidden_cloud_fallback_allowed {
            metrics.hidden_authority_count += 1;
        }
        metrics
    }
}

// UAS: uas:turbovec-real-adapter-dependency-envelope:error
// Plane: Verification
// Residency: validation failures for unsafe dependency-envelope states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecDependencyEnvelopeError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecDependencyEnvelopeStatus),
    BadPromotionTier(TurboVecDependencyEnvelopeTier),
    MetadataBudgetExceeded(u64),
    InvalidOrgans,
    InvalidPolicy(String),
    ProductPromotionAllowed,
    ForbiddenAuthority(String),
    MissingManifest(&'static str),
    BadManifest(String),
    DuplicateManifest(String),
    TooFewManifests(usize),
    MissingDependency(&'static str),
    BadDependency(String),
    DuplicateDependency(String),
    TooFewDependencies(usize),
    MissingField(&'static str),
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    ExternalBytesTouched(String),
}

impl fmt::Display for TurboVecDependencyEnvelopeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "upstream source-pin cursor mismatch"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad dependency-envelope status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad dependency-envelope tier: {tier:?}"),
            Self::MetadataBudgetExceeded(bytes) => {
                write!(f, "metadata budget exceeded: {bytes}")
            }
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidPolicy(reason) => {
                write!(f, "invalid dependency-envelope policy: {reason}")
            }
            Self::ProductPromotionAllowed => write!(f, "product promotion attempted"),
            Self::ForbiddenAuthority(reason) => write!(f, "forbidden authority: {reason}"),
            Self::MissingManifest(manifest) => write!(f, "missing manifest: {manifest}"),
            Self::BadManifest(reason) => write!(f, "bad manifest: {reason}"),
            Self::DuplicateManifest(id) => write!(f, "duplicate manifest: {id}"),
            Self::TooFewManifests(count) => write!(f, "too few manifests: {count}"),
            Self::MissingDependency(dep) => write!(f, "missing dependency: {dep}"),
            Self::BadDependency(reason) => write!(f, "bad dependency: {reason}"),
            Self::DuplicateDependency(id) => write!(f, "duplicate dependency: {id}"),
            Self::TooFewDependencies(count) => write!(f, "too few dependencies: {count}"),
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

impl std::error::Error for TurboVecDependencyEnvelopeError {}

fn validate_set_inputs(
    upstream_source_pin_address: &UasAddress,
    manifests: &[TurboVecDependencyManifest],
    dependencies: &[TurboVecDependencyRecord],
    proof_refs: &TurboVecDependencyEnvelopeProofRefs,
    byte_ledger: &TurboVecDependencyEnvelopeByteLedger,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecDependencyEnvelopeStatus,
    promotion_tier: &TurboVecDependencyEnvelopeTier,
    organs: &[TurboVecIndexOrgan],
    policy: &TurboVecDependencyEnvelopePolicy,
    metadata_bytes_read: u64,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<(), TurboVecDependencyEnvelopeError> {
    if !upstream_source_pin_address
        .to_string()
        .starts_with("turbovec_real_adapter_source_pin_probe:")
    {
        return Err(TurboVecDependencyEnvelopeError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecDependencyEnvelopeError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecDependencyEnvelopeError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if status != &TurboVecDependencyEnvelopeStatus::MetadataOnly {
        return Err(TurboVecDependencyEnvelopeError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecDependencyEnvelopeTier::T1L1Metadata {
        return Err(TurboVecDependencyEnvelopeError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    if metadata_bytes_read == 0 || metadata_bytes_read > MAX_METADATA_BYTES {
        return Err(TurboVecDependencyEnvelopeError::MetadataBudgetExceeded(
            metadata_bytes_read,
        ));
    }
    validate_organs(organs)?;
    validate_policy(policy)?;
    if manifests.len() < MIN_MANIFESTS {
        return Err(TurboVecDependencyEnvelopeError::TooFewManifests(
            manifests.len(),
        ));
    }
    if dependencies.len() < MIN_DEPENDENCIES {
        return Err(TurboVecDependencyEnvelopeError::TooFewDependencies(
            dependencies.len(),
        ));
    }
    if product_capability_promoted {
        return Err(TurboVecDependencyEnvelopeError::ProductPromotionAllowed);
    }
    if route_mutation_allowed
        || model_context_injected
        || hidden_route_authority
        || hidden_cloud_fallback_allowed
        || live_large_model_claimed
        || ssd_as_ram_claimed
    {
        return Err(TurboVecDependencyEnvelopeError::ForbiddenAuthority(
            "route/context/cloud/large-model authority attempted".to_string(),
        ));
    }
    if byte_ledger.raw_manifest_bytes_read == 0 {
        return Err(TurboVecDependencyEnvelopeError::MissingField(
            "raw_manifest_bytes_read",
        ));
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(TurboVecDependencyEnvelopeError::MissingField(
            "visible_summary",
        ));
    }
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecDependencyEnvelopeError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let set: HashSet<_> = organs.iter().copied().collect();
    if organs.len() != required.len() || required.iter().any(|organ| !set.contains(organ)) {
        return Err(TurboVecDependencyEnvelopeError::InvalidOrgans);
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecDependencyEnvelopePolicy,
) -> Result<(), TurboVecDependencyEnvelopeError> {
    let required = [
        (
            policy.source_pin_required,
            "source pin must remain required",
        ),
        (
            policy.all_manifests_sha_bound,
            "all manifests must be SHA-bound",
        ),
        (
            policy.dependency_records_required,
            "dependency records must be required",
        ),
        (
            policy.cargo_lock_record_required,
            "Cargo.lock record must be required",
        ),
        (
            policy.native_link_boundary_required,
            "native link boundary must be required",
        ),
        (
            policy.downstream_smoke_visible_required,
            "downstream smoke must be visible",
        ),
        (
            policy.python_binding_boundary_required,
            "Python binding boundary must be required",
        ),
        (
            policy.optional_integrations_denied_product_default,
            "optional integrations must be denied by default",
        ),
        (
            policy.quarantine_path_required,
            "quarantine path must be required",
        ),
        (
            policy.clean_room_provenance_required,
            "clean-room provenance must be required",
        ),
        (policy.rollback_required, "rollback must be required"),
        (
            policy.run_event_log_required,
            "RunEventLog must be required",
        ),
        (
            policy.answer_packet_required,
            "AnswerPacket must be required",
        ),
        (
            policy.compatibility_fence_required,
            "compatibility fence must be required",
        ),
        (
            policy.benchmark_caveat_required,
            "benchmark caveat must be required",
        ),
        (
            policy.no_fetch_clone_import_build_or_route,
            "fetch/clone/import/build/route must be forbidden",
        ),
        (
            policy.no_product_dependency_insertion,
            "product dependency insertion must be forbidden",
        ),
        (
            policy.no_model_or_provider_bytes,
            "model/provider bytes must be forbidden",
        ),
    ];
    for (ok, reason) in required {
        if !ok {
            return Err(TurboVecDependencyEnvelopeError::InvalidPolicy(
                reason.to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_manifests(
    manifests: &[TurboVecDependencyManifest],
) -> Result<(), TurboVecDependencyEnvelopeError> {
    let mut ids = HashSet::new();
    for manifest in manifests {
        if !ids.insert(manifest.manifest_id.clone()) {
            return Err(TurboVecDependencyEnvelopeError::DuplicateManifest(
                manifest.manifest_id.clone(),
            ));
        }
        required_nonempty("manifest_id", &manifest.manifest_id)?;
        required_nonempty("path", &manifest.path)?;
        validate_revision(&manifest.sha)?;
        require_prefix("manifest_ref", &manifest.manifest_ref, MANIFEST_REF_PREFIX)?;
        if manifest.size_bytes == 0 || !manifest.required {
            return Err(TurboVecDependencyEnvelopeError::BadManifest(format!(
                "manifest `{}` must be required and non-empty",
                manifest.manifest_id
            )));
        }
    }
    for (id, kind, sha) in [
        (
            "root_cargo_toml",
            TurboVecManifestKind::RootWorkspaceCargo,
            "9bf15f9f5eba2de42db231e9235c4181f620277f",
        ),
        (
            "rust_core_cargo_toml",
            TurboVecManifestKind::RustCoreCargo,
            "b48103b6c8b826501d13cfde926d9e9d3f118953",
        ),
        (
            "rust_build_rs",
            TurboVecManifestKind::RustBuildScript,
            "7695df94659cbdacbf2915956c18e29bea9a917d",
        ),
        (
            "python_cargo_toml",
            TurboVecManifestKind::PythonCargo,
            "9cc4a980cfb37e6aaec85c30c8d36f1cdd5919b2",
        ),
        (
            "python_pyproject_toml",
            TurboVecManifestKind::PythonPyProject,
            "166cd434a337d3d861649b0aa7471b8920cec99c",
        ),
        (
            "cargo_config_toml",
            TurboVecManifestKind::CargoConfig,
            "530c5b457b211df82dcab3d6a8751c33b514f1ba",
        ),
        (
            "cargo_lock",
            TurboVecManifestKind::CargoLock,
            "54548a61cb58347074bbbd78537439d75ab24a69",
        ),
        (
            "downstream_smoke_cargo_toml",
            TurboVecManifestKind::DownstreamSmokeCargo,
            "76ada77fc7c563a952d090e9e5d4302444eecb7a",
        ),
    ] {
        let manifest = manifests
            .iter()
            .find(|candidate| candidate.manifest_id == id)
            .ok_or(TurboVecDependencyEnvelopeError::MissingManifest(id))?;
        if manifest.kind != kind || manifest.sha != sha {
            return Err(TurboVecDependencyEnvelopeError::BadManifest(format!(
                "manifest `{id}` kind/SHA mismatch"
            )));
        }
    }
    Ok(())
}

fn validate_dependencies(
    dependencies: &[TurboVecDependencyRecord],
    manifests: &[TurboVecDependencyManifest],
) -> Result<(), TurboVecDependencyEnvelopeError> {
    let manifest_ids: HashSet<_> = manifests
        .iter()
        .map(|manifest| &manifest.manifest_id)
        .collect();
    let mut ids = HashSet::new();
    for dependency in dependencies {
        if !ids.insert(dependency.dependency_id.clone()) {
            return Err(TurboVecDependencyEnvelopeError::DuplicateDependency(
                dependency.dependency_id.clone(),
            ));
        }
        required_nonempty("dependency_id", &dependency.dependency_id)?;
        required_nonempty("package_name", &dependency.package_name)?;
        required_nonempty("version_req", &dependency.version_req)?;
        required_nonempty("target_scope", &dependency.target_scope)?;
        if !manifest_ids.contains(&dependency.manifest_id) {
            return Err(TurboVecDependencyEnvelopeError::BadDependency(format!(
                "dependency `{}` points at unknown manifest",
                dependency.dependency_id
            )));
        }
        if !matches!(
            dependency.allowed_action,
            TurboVecDependencyEnvelopeAction::MetadataOnly
        ) {
            return Err(TurboVecDependencyEnvelopeError::ForbiddenAuthority(
                "dependency action must stay metadata-only".to_string(),
            ));
        }
        if dependency.class == TurboVecDependencyClass::NativeLink {
            require_prefix("risk_ref", &dependency.risk_ref, NATIVE_LINK_REF_PREFIX)?;
        } else {
            require_prefix("risk_ref", &dependency.risk_ref, DEPENDENCY_REF_PREFIX)?;
        }
        if dependency.class == TurboVecDependencyClass::PythonOptionalIntegration {
            if !dependency.optional {
                return Err(TurboVecDependencyEnvelopeError::BadDependency(
                    "optional Python integrations must stay optional".to_string(),
                ));
            }
        } else if dependency.optional {
            return Err(TurboVecDependencyEnvelopeError::BadDependency(format!(
                "dependency `{}` must not be optional",
                dependency.dependency_id
            )));
        }
    }
    for required in [
        "rust_ndarray",
        "rust_rayon",
        "rust_ordered_float",
        "rust_rand",
        "rust_rand_chacha",
        "rust_rand_distr",
        "rust_statrs",
        "rust_faer",
        "target_macos_ndarray_blas",
        "target_linux_ndarray_blas",
        "native_macos_accelerate",
        "native_linux_openblas",
        "python_pyo3",
        "python_numpy_crate",
        "python_maturin",
        "python_numpy_runtime",
        "python_langchain_optional",
        "python_llama_index_optional",
        "python_haystack_optional",
        "python_agno_optional",
        "downstream_smoke_path_dep",
        "x86_64_v3_rustflags",
    ] {
        if !dependencies
            .iter()
            .any(|dependency| dependency.dependency_id == required)
        {
            return Err(TurboVecDependencyEnvelopeError::MissingDependency(required));
        }
    }
    let optional_count = dependencies
        .iter()
        .filter(|dependency| dependency.class == TurboVecDependencyClass::PythonOptionalIntegration)
        .count();
    if optional_count != 4 {
        return Err(TurboVecDependencyEnvelopeError::BadDependency(
            "expected exactly four optional Python integrations".to_string(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &TurboVecDependencyEnvelopeProofRefs,
) -> Result<(), TurboVecDependencyEnvelopeError> {
    require_prefix("source_pin_ref", &refs.source_pin_ref, SOURCE_PIN_PREFIX)?;
    require_prefix(
        "dependency_manifest_ref",
        &refs.dependency_manifest_ref,
        DEPENDENCY_REF_PREFIX,
    )?;
    require_prefix(
        "native_link_ref",
        &refs.native_link_ref,
        NATIVE_LINK_REF_PREFIX,
    )?;
    require_prefix(
        "quarantine_path_ref",
        &refs.quarantine_path_ref,
        QUARANTINE_REF_PREFIX,
    )?;
    require_prefix(
        "provenance_ref",
        &refs.provenance_ref,
        PROVENANCE_REF_PREFIX,
    )?;
    require_prefix("rollback_ref", &refs.rollback_ref, ROLLBACK_REF_PREFIX)?;
    require_prefix(
        "run_event_log_ref",
        &refs.run_event_log_ref,
        RUN_EVENT_LOG_REF_PREFIX,
    )?;
    require_prefix(
        "answer_packet_ref",
        &refs.answer_packet_ref,
        ANSWER_PACKET_REF_PREFIX,
    )?;
    require_prefix(
        "compatibility_fence_ref",
        &refs.compatibility_fence_ref,
        COMPATIBILITY_REF_PREFIX,
    )?;
    require_prefix(
        "benchmark_caveat_ref",
        &refs.benchmark_caveat_ref,
        BENCHMARK_CAVEAT_PREFIX,
    )
}

fn validate_byte_ledger(
    ledger: &TurboVecDependencyEnvelopeByteLedger,
) -> Result<(), TurboVecDependencyEnvelopeError> {
    if ledger.fetched_repo_bytes == 0
        && ledger.cloned_repo_bytes == 0
        && ledger.copied_product_file_count == 0
        && ledger.product_dependency_count == 0
        && ledger.imported_external_crate_count == 0
        && ledger.built_external_binary_count == 0
        && ledger.native_link_probe_count == 0
        && ledger.opened_product_index_bytes == 0
        && ledger.model_bytes_loaded == 0
        && ledger.runtime_model_bytes_loaded == 0
        && ledger.provider_calls_made == 0
    {
        Ok(())
    } else {
        Err(TurboVecDependencyEnvelopeError::ExternalBytesTouched(
            "dependency envelope must not fetch/clone/import/build/route/load bytes".to_string(),
        ))
    }
}

fn validate_revision(rev: &str) -> Result<(), TurboVecDependencyEnvelopeError> {
    if rev.len() == 40 && rev.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        Ok(())
    } else {
        Err(TurboVecDependencyEnvelopeError::BadManifest(format!(
            "bad SHA `{rev}`"
        )))
    }
}

fn require_prefix(
    field: &'static str,
    value: &str,
    expected: &'static str,
) -> Result<(), TurboVecDependencyEnvelopeError> {
    if value.starts_with(expected) {
        Ok(())
    } else {
        Err(TurboVecDependencyEnvelopeError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        })
    }
}

fn required_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), TurboVecDependencyEnvelopeError> {
    if value.trim().is_empty() {
        Err(TurboVecDependencyEnvelopeError::MissingField(field))
    } else {
        Ok(())
    }
}

fn deterministic_set_address(
    manifests: &[TurboVecDependencyManifest],
    dependencies: &[TurboVecDependencyRecord],
    metadata_bytes_read: u64,
) -> UasAddress {
    let mut payload = Vec::new();
    payload.extend_from_slice(metadata_bytes_read.to_string().as_bytes());
    for manifest in manifests {
        payload.extend_from_slice(manifest.manifest_id.as_bytes());
        payload.extend_from_slice(manifest.sha.as_bytes());
    }
    for dependency in dependencies {
        payload.extend_from_slice(dependency.dependency_id.as_bytes());
        payload.extend_from_slice(dependency.package_name.as_bytes());
        payload.extend_from_slice(dependency.version_req.as_bytes());
        payload.extend_from_slice(format!("{:?}", dependency.class).as_bytes());
    }
    let digest = sha256_hex(&payload);
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_dependency_envelope_probe".to_string()),
        digest.as_bytes(),
        1_779_040_900_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_source_pin_probe".to_string()),
            b"source-pin",
            1_779_040_900_000,
        )
    }

    fn manifest(
        id: &str,
        kind: TurboVecManifestKind,
        path: &str,
        sha: &str,
        size: u64,
    ) -> TurboVecDependencyManifest {
        TurboVecDependencyManifest {
            manifest_id: id.to_string(),
            kind,
            path: path.to_string(),
            sha: sha.to_string(),
            size_bytes: size,
            manifest_ref: format!("github_manifest:turbovec:{path}:{sha}"),
            required: true,
        }
    }

    fn manifests() -> Vec<TurboVecDependencyManifest> {
        vec![
            manifest(
                "root_cargo_toml",
                TurboVecManifestKind::RootWorkspaceCargo,
                "Cargo.toml",
                "9bf15f9f5eba2de42db231e9235c4181f620277f",
                366,
            ),
            manifest(
                "rust_core_cargo_toml",
                TurboVecManifestKind::RustCoreCargo,
                "turbovec/Cargo.toml",
                "b48103b6c8b826501d13cfde926d9e9d3f118953",
                1003,
            ),
            manifest(
                "rust_build_rs",
                TurboVecManifestKind::RustBuildScript,
                "turbovec/build.rs",
                "7695df94659cbdacbf2915956c18e29bea9a917d",
                917,
            ),
            manifest(
                "python_cargo_toml",
                TurboVecManifestKind::PythonCargo,
                "turbovec-python/Cargo.toml",
                "9cc4a980cfb37e6aaec85c30c8d36f1cdd5919b2",
                314,
            ),
            manifest(
                "python_pyproject_toml",
                TurboVecManifestKind::PythonPyProject,
                "turbovec-python/pyproject.toml",
                "166cd434a337d3d861649b0aa7471b8920cec99c",
                1684,
            ),
            manifest(
                "cargo_config_toml",
                TurboVecManifestKind::CargoConfig,
                ".cargo/config.toml",
                "530c5b457b211df82dcab3d6a8751c33b514f1ba",
                980,
            ),
            manifest(
                "cargo_lock",
                TurboVecManifestKind::CargoLock,
                "Cargo.lock",
                "54548a61cb58347074bbbd78537439d75ab24a69",
                30548,
            ),
            manifest(
                "downstream_smoke_cargo_toml",
                TurboVecManifestKind::DownstreamSmokeCargo,
                "examples/downstream-smoke/Cargo.toml",
                "76ada77fc7c563a952d090e9e5d4302444eecb7a",
                522,
            ),
        ]
    }

    fn dep(
        id: &str,
        // UAS-EXEMPT: test helper parameter materializes TurboVecDependencyRecord::class.
        class: TurboVecDependencyClass,
        package: &str,
        version: &str,
        manifest_id: &str,
        target: &str,
        optional: bool,
    ) -> TurboVecDependencyRecord {
        let prefix = if class == TurboVecDependencyClass::NativeLink {
            "native_link:turbovec-envelope:"
        } else {
            "dependency_manifest:turbovec-envelope:"
        };
        TurboVecDependencyRecord {
            dependency_id: id.to_string(),
            class,
            package_name: package.to_string(),
            version_req: version.to_string(),
            manifest_id: manifest_id.to_string(),
            target_scope: target.to_string(),
            optional,
            feature_refs: Vec::new(),
            risk_ref: format!("{prefix}{id}"),
            allowed_action: TurboVecDependencyEnvelopeAction::MetadataOnly,
        }
    }

    fn dependencies() -> Vec<TurboVecDependencyRecord> {
        vec![
            dep(
                "rust_ndarray",
                TurboVecDependencyClass::RustCoreCrate,
                "ndarray",
                "0.17",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_rayon",
                TurboVecDependencyClass::RustCoreCrate,
                "rayon",
                "1.10",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_ordered_float",
                TurboVecDependencyClass::RustCoreCrate,
                "ordered-float",
                "4",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_rand",
                TurboVecDependencyClass::RustCoreCrate,
                "rand",
                "0.8",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_rand_chacha",
                TurboVecDependencyClass::RustCoreCrate,
                "rand_chacha",
                "0.3",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_rand_distr",
                TurboVecDependencyClass::RustCoreCrate,
                "rand_distr",
                "0.4",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_statrs",
                TurboVecDependencyClass::RustCoreCrate,
                "statrs",
                "0.17",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "rust_faer",
                TurboVecDependencyClass::RustCoreCrate,
                "faer",
                "0.20",
                "rust_core_cargo_toml",
                "all",
                false,
            ),
            dep(
                "target_macos_ndarray_blas",
                TurboVecDependencyClass::TargetSpecificRustCrate,
                "ndarray",
                "0.17+blas",
                "rust_core_cargo_toml",
                "macos",
                false,
            ),
            dep(
                "target_linux_ndarray_blas",
                TurboVecDependencyClass::TargetSpecificRustCrate,
                "ndarray",
                "0.17+blas",
                "rust_core_cargo_toml",
                "linux",
                false,
            ),
            dep(
                "native_macos_accelerate",
                TurboVecDependencyClass::NativeLink,
                "Accelerate.framework",
                "system",
                "rust_build_rs",
                "macos",
                false,
            ),
            dep(
                "native_linux_openblas",
                TurboVecDependencyClass::NativeLink,
                "openblas",
                "system",
                "rust_build_rs",
                "linux",
                false,
            ),
            dep(
                "python_pyo3",
                TurboVecDependencyClass::PythonBindingCrate,
                "pyo3",
                "0.27.0+extension-module+abi3-py39",
                "python_cargo_toml",
                "python",
                false,
            ),
            dep(
                "python_numpy_crate",
                TurboVecDependencyClass::PythonBindingCrate,
                "numpy",
                "0.27.0",
                "python_cargo_toml",
                "python",
                false,
            ),
            dep(
                "python_maturin",
                TurboVecDependencyClass::PythonBuildBackend,
                "maturin",
                ">=1.12,<2.0",
                "python_pyproject_toml",
                "python",
                false,
            ),
            dep(
                "python_numpy_runtime",
                TurboVecDependencyClass::PythonRuntimePackage,
                "numpy",
                ">=1.20",
                "python_pyproject_toml",
                "python",
                false,
            ),
            dep(
                "python_langchain_optional",
                TurboVecDependencyClass::PythonOptionalIntegration,
                "langchain-core",
                ">=0.3",
                "python_pyproject_toml",
                "python-extra",
                true,
            ),
            dep(
                "python_llama_index_optional",
                TurboVecDependencyClass::PythonOptionalIntegration,
                "llama-index-core",
                ">=0.11",
                "python_pyproject_toml",
                "python-extra",
                true,
            ),
            dep(
                "python_haystack_optional",
                TurboVecDependencyClass::PythonOptionalIntegration,
                "haystack-ai",
                ">=2.0",
                "python_pyproject_toml",
                "python-extra",
                true,
            ),
            dep(
                "python_agno_optional",
                TurboVecDependencyClass::PythonOptionalIntegration,
                "agno",
                ">=2.0",
                "python_pyproject_toml",
                "python-extra",
                true,
            ),
            dep(
                "downstream_smoke_path_dep",
                TurboVecDependencyClass::DownstreamSmokePath,
                "turbovec",
                "../../turbovec",
                "downstream_smoke_cargo_toml",
                "downstream-smoke",
                false,
            ),
            dep(
                "x86_64_v3_rustflags",
                TurboVecDependencyClass::CodegenConfig,
                "rustflags",
                "target-cpu=x86-64-v3",
                "cargo_config_toml",
                "x86_64",
                false,
            ),
        ]
    }

    fn proof_refs() -> TurboVecDependencyEnvelopeProofRefs {
        TurboVecDependencyEnvelopeProofRefs {
            source_pin_ref:
                "source_pin:pinned_metadata_only:efe29a184986cbf562a9847c2ac52a2990bfaca2"
                    .to_string(),
            dependency_manifest_ref: "dependency_manifest:turbovec-envelope:metadata-only".to_string(),
            native_link_ref: "native_link:turbovec-envelope:accelerate-openblas-no-probe".to_string(),
            quarantine_path_ref: "quarantine_path:turbovec-envelope:pending-sandbox-layout".to_string(),
            provenance_ref: "provenance:turbovec-envelope:clean-room-source-card".to_string(),
            rollback_ref: "rollback:turbovec-envelope:drop-dependency-card".to_string(),
            run_event_log_ref: "run_event_log:turbovec-envelope:metadata-only".to_string(),
            answer_packet_ref: "answer_packet:turbovec-envelope:visible-non-promotion".to_string(),
            compatibility_fence_ref: "compat:turbovec-envelope:no-product-deps".to_string(),
            benchmark_caveat_ref: "benchmark_caveat:turbovec-envelope:no-upstream-laundering".to_string(),
            visible_summary: "TurboVec dependency metadata is envelope-planned only: Rust core deps, target-specific BLAS behavior, Python/maturin/numpy bindings, optional Python integrations, Cargo.lock, x86 config, and downstream smoke-test shape are recorded without fetching, cloning, adding dependencies, importing code, building adapters, opening indexes, loading model bytes, or mutating routes.".to_string(),
        }
    }

    fn set(
        manifests: Vec<TurboVecDependencyManifest>,
        dependencies: Vec<TurboVecDependencyRecord>,
    ) -> Result<TurboVecRealAdapterDependencyEnvelopeProbeSet, TurboVecDependencyEnvelopeError>
    {
        TurboVecRealAdapterDependencyEnvelopeProbeSet::from_parts(
            upstream(),
            manifests,
            dependencies,
            proof_refs(),
            TurboVecDependencyEnvelopeByteLedger::metadata_only(146_000, 33_000, 8 * 1024 * 1024),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecDependencyEnvelopeStatus::MetadataOnly,
            TurboVecDependencyEnvelopeTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            TurboVecDependencyEnvelopePolicy::fail_closed(),
            160_000,
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
    fn accepts_metadata_only_dependency_envelope() {
        let accepted = set(manifests(), dependencies()).expect("valid dependency envelope");
        let metrics = accepted.metrics();
        assert_eq!(metrics.manifest_count, 8);
        assert_eq!(metrics.dependency_record_count, 22);
        assert_eq!(metrics.native_link_count, 2);
        assert_eq!(metrics.optional_python_integration_count, 4);
        assert_eq!(metrics.product_dependency_count, 0);
    }

    #[test]
    fn rejects_missing_manifest_or_bad_sha() {
        let mut missing = manifests();
        missing.retain(|manifest| manifest.manifest_id != "cargo_lock");
        assert!(matches!(
            set(missing, dependencies()),
            Err(TurboVecDependencyEnvelopeError::TooFewManifests(7))
                | Err(TurboVecDependencyEnvelopeError::MissingManifest(
                    "cargo_lock"
                ))
        ));

        let mut bad = manifests();
        bad[0].sha = "short".to_string();
        assert!(matches!(
            set(bad, dependencies()),
            Err(TurboVecDependencyEnvelopeError::BadManifest(_))
        ));
    }

    #[test]
    fn rejects_missing_dependency_or_product_action() {
        let mut missing = dependencies();
        missing.retain(|dep| dep.dependency_id != "native_macos_accelerate");
        assert!(matches!(
            set(manifests(), missing),
            Err(TurboVecDependencyEnvelopeError::MissingDependency(
                "native_macos_accelerate"
            ))
        ));

        let mut bad = dependencies();
        bad[0].allowed_action = TurboVecDependencyEnvelopeAction::AddProductDependency;
        assert!(matches!(
            set(manifests(), bad),
            Err(TurboVecDependencyEnvelopeError::ForbiddenAuthority(_))
        ));
    }

    #[test]
    fn rejects_runtime_or_hidden_authority_shortcuts() {
        let err = TurboVecRealAdapterDependencyEnvelopeProbeSet::from_parts(
            upstream(),
            manifests(),
            dependencies(),
            proof_refs(),
            TurboVecDependencyEnvelopeByteLedger {
                built_external_binary_count: 1,
                ..TurboVecDependencyEnvelopeByteLedger::metadata_only(
                    146_000,
                    33_000,
                    8 * 1024 * 1024,
                )
            },
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecDependencyEnvelopeStatus::MetadataOnly,
            TurboVecDependencyEnvelopeTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            TurboVecDependencyEnvelopePolicy::fail_closed(),
            160_000,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(matches!(
            err,
            Err(TurboVecDependencyEnvelopeError::ExternalBytesTouched(_))
        ));
    }
}
