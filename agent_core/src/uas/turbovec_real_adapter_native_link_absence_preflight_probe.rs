//! TurboVec real-adapter native-link absence preflight.
//!
//! This primitive keeps the TurboVec/QAT research-to-build ladder fail-closed
//! before native linking. It records known native-link and build-script risk
//! surfaces, binds them to upstream product-graph and dependency-envelope
//! witnesses, and rejects any adapter build, linker invocation, dynamic-library
//! load, product dependency insertion, route mutation, or large-model promotion.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_native_link_absence_preflight_probe";
pub const TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_owner_approved_native_dry_run_probe";

const PRODUCT_GRAPH_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_product_graph_no_contamination_probe:result";
const PRODUCT_GRAPH_ARTIFACT_REF_PREFIX: &str =
    "artifact:turbovec_real_adapter_product_graph_no_contamination_probe:";
const PRODUCT_GRAPH_ADDRESS_PREFIX: &str =
    "turbovec_real_adapter_product_graph_no_contamination_probe:";
const DEPENDENCY_ENVELOPE_REF_PREFIX: &str =
    "artifact:turbovec_real_adapter_dependency_envelope_probe:";
const SOURCE_MANIFEST_REF_PREFIX: &str =
    "artifact:turbovec_real_adapter_source_byte_manifest_probe:";
const SOURCE_INSPECTION_REF_PREFIX: &str =
    "artifact:turbovec_real_adapter_source_inspection_policy_probe:";
const PRODUCT_GRAPH_REF_PREFIX: &str = "product_graph:turbovec-no-contamination:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-preflight:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-native-link:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-native-link:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-native-link:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-native-link:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const MAX_PREFLIGHT_METADATA_BYTES: u64 = 2 * 1024 * 1024;
const MIN_RISK_ROWS: usize = 9;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 280;

// UAS: uas:turbovec-native-link-preflight:status
// Plane: Verification.
// Residency: metadata-only native-link absence preflight status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeLinkPreflightStatus {
    MetadataOnlyNoNativeLink,
    NativeDryRunPendingOwnerApproval,
    RuntimeCandidate,
}

// UAS: uas:turbovec-native-link-preflight:tier
// Plane: Verification.
// Residency: promotion tier for this preflight; only T1 is valid here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeLinkPreflightTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-native-link-preflight:surface
// Plane: State + Assembly + Controller + Verification.
// Residency: native-link/build risk surface class.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeLinkSurface {
    RustBuildScript,
    TargetSpecificBlas,
    PythonExtension,
    PythonBuildBackend,
    PythonRuntimePackage,
    CargoConfig,
    DownstreamSmoke,
    BenchmarkSurface,
    ProductManifest,
    ProductRouteSurface,
}

// UAS: uas:turbovec-native-link-preflight:action
// Plane: Controller + Verification.
// Residency: allowed action at this rung; all rows are metadata-only or denied.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeLinkAction {
    MetadataOnly,
    DenyBuildScript,
    DenyNativeLink,
    DenyDynamicLoad,
    DenyProductDependency,
    DenyRouteMutation,
}

// UAS: uas:turbovec-native-link-preflight:row
// Plane: State + Verification.
// Residency: single native-link/build risk record.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeLinkPreflightRow {
    pub risk_id: String,
    pub surface: TurboVecNativeLinkSurface,
    pub target_scope: String,
    pub source_refs: Vec<String>,
    pub native_link_ref: String,
    pub product_graph_ref: String,
    pub allowed_action: TurboVecNativeLinkAction,
    pub owner_approval_required: bool,
    pub native_link_absent: bool,
    pub build_script_exec_count: u64,
    pub cargo_build_invocation_count: u64,
    pub linker_invocation_count: u64,
    pub dynamic_library_load_count: u64,
    pub python_build_invocation_count: u64,
    pub environment_mutation_count: u64,
    pub product_dependency_count: u64,
    pub product_route_mutation_count: u64,
    pub benchmark_authority_claim_count: u64,
}

impl TurboVecNativeLinkPreflightRow {
    pub fn is_blocked_metadata_only(&self) -> bool {
        !self.risk_id.trim().is_empty()
            && !self.target_scope.trim().is_empty()
            && !self.source_refs.is_empty()
            && self.source_refs.iter().all(|value| {
                value.starts_with(DEPENDENCY_ENVELOPE_REF_PREFIX)
                    || value.starts_with(SOURCE_MANIFEST_REF_PREFIX)
                    || value.starts_with(SOURCE_INSPECTION_REF_PREFIX)
                    || value.starts_with(PRODUCT_GRAPH_ARTIFACT_REF_PREFIX)
            })
            && self.native_link_ref.starts_with(NATIVE_LINK_REF_PREFIX)
            && self.product_graph_ref.starts_with(PRODUCT_GRAPH_REF_PREFIX)
            && matches!(
                self.allowed_action,
                TurboVecNativeLinkAction::MetadataOnly
                    | TurboVecNativeLinkAction::DenyBuildScript
                    | TurboVecNativeLinkAction::DenyNativeLink
                    | TurboVecNativeLinkAction::DenyDynamicLoad
                    | TurboVecNativeLinkAction::DenyProductDependency
                    | TurboVecNativeLinkAction::DenyRouteMutation
            )
            && self.owner_approval_required
            && self.native_link_absent
            && self.build_script_exec_count == 0
            && self.cargo_build_invocation_count == 0
            && self.linker_invocation_count == 0
            && self.dynamic_library_load_count == 0
            && self.python_build_invocation_count == 0
            && self.environment_mutation_count == 0
            && self.product_dependency_count == 0
            && self.product_route_mutation_count == 0
            && self.benchmark_authority_claim_count == 0
    }
}

// UAS: uas:turbovec-native-link-preflight:policy
// Plane: Controller + Verification.
// Residency: fail-closed policy before any native-link dry run.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeLinkPreflightPolicy {
    pub product_graph_no_contamination_required: bool,
    pub dependency_envelope_required: bool,
    pub source_manifest_required: bool,
    pub source_inspection_policy_required: bool,
    pub owner_approval_required_for_any_dry_run: bool,
    pub build_script_execution_denied: bool,
    pub cargo_build_denied: bool,
    pub linker_invocation_denied: bool,
    pub dynamic_library_load_denied: bool,
    pub python_extension_build_denied: bool,
    pub environment_mutation_denied: bool,
    pub product_dependency_insertion_denied: bool,
    pub product_route_mutation_denied: bool,
    pub benchmark_authority_denied: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub no_runtime_or_model_bytes: bool,
    pub no_product_capability_promotion: bool,
}

impl TurboVecNativeLinkPreflightPolicy {
    pub fn fail_closed() -> Self {
        Self {
            product_graph_no_contamination_required: true,
            dependency_envelope_required: true,
            source_manifest_required: true,
            source_inspection_policy_required: true,
            owner_approval_required_for_any_dry_run: true,
            build_script_execution_denied: true,
            cargo_build_denied: true,
            linker_invocation_denied: true,
            dynamic_library_load_denied: true,
            python_extension_build_denied: true,
            environment_mutation_denied: true,
            product_dependency_insertion_denied: true,
            product_route_mutation_denied: true,
            benchmark_authority_denied: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            no_runtime_or_model_bytes: true,
            no_product_capability_promotion: true,
        }
    }
}

// UAS: uas:turbovec-native-link-preflight:byte-ledger
// Plane: Verification.
// Residency: preflight metadata ledger; no native/runtime/model bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeLinkPreflightByteLedger {
    pub upstream_product_graph_artifact_bytes_read: u64,
    pub dependency_metadata_bytes_read: u64,
    pub preflight_metadata_bytes_written: u64,
    pub raw_turbovec_source_bytes_read: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
    pub copied_product_file_count: u64,
    pub product_dependency_count: u64,
    pub build_script_exec_count: u64,
    pub cargo_build_invocation_count: u64,
    pub linker_invocation_count: u64,
    pub dynamic_library_load_count: u64,
    pub python_build_invocation_count: u64,
    pub environment_mutation_count: u64,
    pub benchmark_run_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl TurboVecNativeLinkPreflightByteLedger {
    pub fn metadata_only(
        upstream_product_graph_artifact_bytes_read: u64,
        dependency_metadata_bytes_read: u64,
        preflight_metadata_bytes_written: u64,
    ) -> Result<Self, TurboVecNativeLinkPreflightError> {
        if upstream_product_graph_artifact_bytes_read
            + dependency_metadata_bytes_read
            + preflight_metadata_bytes_written
            > MAX_PREFLIGHT_METADATA_BYTES
        {
            return Err(TurboVecNativeLinkPreflightError::MetadataBudgetExceeded);
        }
        Ok(Self {
            upstream_product_graph_artifact_bytes_read,
            dependency_metadata_bytes_read,
            preflight_metadata_bytes_written,
            raw_turbovec_source_bytes_read: 0,
            fetched_repo_bytes: 0,
            cloned_repo_bytes: 0,
            copied_product_file_count: 0,
            product_dependency_count: 0,
            build_script_exec_count: 0,
            cargo_build_invocation_count: 0,
            linker_invocation_count: 0,
            dynamic_library_load_count: 0,
            python_build_invocation_count: 0,
            environment_mutation_count: 0,
            benchmark_run_count: 0,
            index_bytes_opened: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
        })
    }
}

// UAS: uas:turbovec-native-link-preflight:proof-refs
// Plane: Verification.
// Residency: visible proof handles for native-link absence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeLinkPreflightProofRefs {
    pub product_graph_ref: String,
    pub dependency_envelope_ref: String,
    pub source_manifest_ref: String,
    pub source_inspection_policy_ref: String,
    pub native_link_absence_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-native-link-preflight:set
// Plane: State + Assembly + Controller + Verification.
// Residency: complete deterministic native-link absence preflight witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet {
    pub upstream_product_graph_witness_ref: String,
    pub upstream_product_graph_address: UasAddress,
    pub source_url: String,
    pub pinned_revision: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecNativeLinkPreflightStatus,
    pub tier: TurboVecNativeLinkPreflightTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub rows: Vec<TurboVecNativeLinkPreflightRow>,
    pub policy: TurboVecNativeLinkPreflightPolicy,
    pub proof_refs: TurboVecNativeLinkPreflightProofRefs,
    pub byte_ledger: TurboVecNativeLinkPreflightByteLedger,
    pub product_capability_promoted: bool,
    pub native_dry_run_approved: bool,
    pub route_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub set_address: UasAddress,
}

impl TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_product_graph_address: UasAddress,
        rows: Vec<TurboVecNativeLinkPreflightRow>,
        policy: TurboVecNativeLinkPreflightPolicy,
        proof_refs: TurboVecNativeLinkPreflightProofRefs,
        byte_ledger: TurboVecNativeLinkPreflightByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecNativeLinkPreflightStatus,
        tier: TurboVecNativeLinkPreflightTier,
        product_capability_promoted: bool,
        native_dry_run_approved: bool,
        route_mutation_allowed: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecNativeLinkPreflightError> {
        let mut sorted_rows = rows;
        sorted_rows.sort_by(|left, right| left.risk_id.cmp(&right.risk_id));
        let mut set = Self {
            upstream_product_graph_witness_ref: PRODUCT_GRAPH_WITNESS_REF.to_string(),
            upstream_product_graph_address,
            source_url: SOURCE_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            product_build,
            pro_status,
            status,
            tier,
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            rows: sorted_rows,
            policy,
            proof_refs,
            byte_ledger,
            product_capability_promoted,
            native_dry_run_approved,
            route_mutation_allowed,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
            set_address: UasAddress::new(
                UasKind::Other(
                    "turbovec_real_adapter_native_link_absence_preflight_probe".to_string(),
                ),
                b"pending",
                1_779_041_511_000,
            ),
        };
        set.validate()?;
        let digest = native_link_absence_preflight_digest(&set);
        set.set_address = UasAddress::new(
            UasKind::Other("turbovec_real_adapter_native_link_absence_preflight_probe".to_string()),
            digest.as_bytes(),
            1_779_041_511_000,
        );
        Ok(set)
    }

    pub fn metrics(&self) -> TurboVecNativeLinkPreflightMetrics {
        let mut metrics = TurboVecNativeLinkPreflightMetrics {
            row_count: self.rows.len() as u64,
            upstream_product_graph_artifact_bytes_read: self
                .byte_ledger
                .upstream_product_graph_artifact_bytes_read,
            dependency_metadata_bytes_read: self.byte_ledger.dependency_metadata_bytes_read,
            preflight_metadata_bytes_written: self.byte_ledger.preflight_metadata_bytes_written,
            raw_turbovec_source_bytes_read: self.byte_ledger.raw_turbovec_source_bytes_read,
            fetched_repo_bytes: self.byte_ledger.fetched_repo_bytes,
            cloned_repo_bytes: self.byte_ledger.cloned_repo_bytes,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            product_dependency_count: self.byte_ledger.product_dependency_count,
            build_script_exec_count: self.byte_ledger.build_script_exec_count,
            cargo_build_invocation_count: self.byte_ledger.cargo_build_invocation_count,
            linker_invocation_count: self.byte_ledger.linker_invocation_count,
            dynamic_library_load_count: self.byte_ledger.dynamic_library_load_count,
            python_build_invocation_count: self.byte_ledger.python_build_invocation_count,
            environment_mutation_count: self.byte_ledger.environment_mutation_count,
            benchmark_run_count: self.byte_ledger.benchmark_run_count,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            product_capability_promoted_count: u64::from(self.product_capability_promoted),
            native_dry_run_approved_count: u64::from(self.native_dry_run_approved),
            route_mutation_count: u64::from(self.route_mutation_allowed),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
            live_large_model_claim_count: u64::from(self.live_large_model_claimed),
            ssd_as_ram_claim_count: u64::from(self.ssd_as_ram_claimed),
            ..TurboVecNativeLinkPreflightMetrics::default()
        };
        for row in &self.rows {
            if row.native_link_absent {
                metrics.native_link_absent_row_count += 1;
            }
            if row.owner_approval_required {
                metrics.owner_approval_required_count += 1;
            }
            if matches!(row.surface, TurboVecNativeLinkSurface::TargetSpecificBlas) {
                metrics.target_specific_native_link_count += 1;
            }
            if matches!(
                row.surface,
                TurboVecNativeLinkSurface::PythonExtension
                    | TurboVecNativeLinkSurface::PythonBuildBackend
                    | TurboVecNativeLinkSurface::PythonRuntimePackage
            ) {
                metrics.python_native_boundary_count += 1;
            }
            if matches!(
                row.surface,
                TurboVecNativeLinkSurface::ProductManifest
                    | TurboVecNativeLinkSurface::ProductRouteSurface
            ) {
                metrics.product_surface_preflight_count += 1;
            }
            metrics.row_build_script_exec_count += row.build_script_exec_count;
            metrics.row_cargo_build_invocation_count += row.cargo_build_invocation_count;
            metrics.row_linker_invocation_count += row.linker_invocation_count;
            metrics.row_dynamic_library_load_count += row.dynamic_library_load_count;
            metrics.row_python_build_invocation_count += row.python_build_invocation_count;
            metrics.row_environment_mutation_count += row.environment_mutation_count;
            metrics.row_product_dependency_count += row.product_dependency_count;
            metrics.row_product_route_mutation_count += row.product_route_mutation_count;
            metrics.row_benchmark_authority_claim_count += row.benchmark_authority_claim_count;
        }
        metrics
    }

    fn validate(&self) -> Result<(), TurboVecNativeLinkPreflightError> {
        if self.upstream_product_graph_witness_ref != PRODUCT_GRAPH_WITNESS_REF
            || !self
                .upstream_product_graph_address
                .to_string()
                .starts_with(PRODUCT_GRAPH_ADDRESS_PREFIX)
        {
            return Err(TurboVecNativeLinkPreflightError::UpstreamProductGraphNotBound);
        }
        if self.source_url != SOURCE_URL || self.pinned_revision != PINNED_REVISION {
            return Err(TurboVecNativeLinkPreflightError::BadSourceIdentity);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.status != TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink
            || self.tier != TurboVecNativeLinkPreflightTier::T1L1Metadata
        {
            return Err(TurboVecNativeLinkPreflightError::PromotionBoundaryViolation);
        }
        validate_rows(&self.rows)?;
        validate_policy(&self.policy)?;
        validate_proofs(&self.proof_refs)?;
        validate_byte_ledger(&self.byte_ledger)?;
        if self.product_capability_promoted
            || self.native_dry_run_approved
            || self.route_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_cloud_fallback_allowed
            || self.live_large_model_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(TurboVecNativeLinkPreflightError::PromotionBoundaryViolation);
        }
        let metrics = self.metrics();
        if metrics.row_build_script_exec_count > 0
            || metrics.row_cargo_build_invocation_count > 0
            || metrics.row_linker_invocation_count > 0
            || metrics.row_dynamic_library_load_count > 0
            || metrics.row_python_build_invocation_count > 0
            || metrics.row_environment_mutation_count > 0
            || metrics.row_product_dependency_count > 0
            || metrics.row_product_route_mutation_count > 0
            || metrics.row_benchmark_authority_claim_count > 0
        {
            return Err(TurboVecNativeLinkPreflightError::NativeLinkExecutionDetected);
        }
        Ok(())
    }
}

// UAS: uas:turbovec-native-link-preflight:metrics
// Plane: Verification.
// Residency: derived counts for falsifier axes.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeLinkPreflightMetrics {
    pub row_count: u64,
    pub native_link_absent_row_count: u64,
    pub owner_approval_required_count: u64,
    pub target_specific_native_link_count: u64,
    pub python_native_boundary_count: u64,
    pub product_surface_preflight_count: u64,
    pub upstream_product_graph_artifact_bytes_read: u64,
    pub dependency_metadata_bytes_read: u64,
    pub preflight_metadata_bytes_written: u64,
    pub raw_turbovec_source_bytes_read: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
    pub copied_product_file_count: u64,
    pub product_dependency_count: u64,
    pub build_script_exec_count: u64,
    pub cargo_build_invocation_count: u64,
    pub linker_invocation_count: u64,
    pub dynamic_library_load_count: u64,
    pub python_build_invocation_count: u64,
    pub environment_mutation_count: u64,
    pub benchmark_run_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub row_build_script_exec_count: u64,
    pub row_cargo_build_invocation_count: u64,
    pub row_linker_invocation_count: u64,
    pub row_dynamic_library_load_count: u64,
    pub row_python_build_invocation_count: u64,
    pub row_environment_mutation_count: u64,
    pub row_product_dependency_count: u64,
    pub row_product_route_mutation_count: u64,
    pub row_benchmark_authority_claim_count: u64,
    pub product_capability_promoted_count: u64,
    pub native_dry_run_approved_count: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub live_large_model_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

// UAS: uas:turbovec-native-link-preflight:error
// Plane: Verification.
// Residency: fail-closed validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecNativeLinkPreflightError {
    UpstreamProductGraphNotBound,
    BadSourceIdentity,
    PromotionBoundaryViolation,
    MissingRiskRows,
    DuplicateRiskId,
    BadRiskRow(String),
    PolicyNotFailClosed,
    ProofRefsMissing,
    MetadataBudgetExceeded,
    RuntimeOrModelBytesDetected,
    NativeLinkExecutionDetected,
}

impl fmt::Display for TurboVecNativeLinkPreflightError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UpstreamProductGraphNotBound => {
                write!(formatter, "upstream product graph witness not bound")
            }
            Self::BadSourceIdentity => write!(formatter, "bad TurboVec source identity"),
            Self::PromotionBoundaryViolation => write!(formatter, "promotion boundary violation"),
            Self::MissingRiskRows => write!(formatter, "missing native-link risk rows"),
            Self::DuplicateRiskId => write!(formatter, "duplicate native-link risk id"),
            Self::BadRiskRow(id) => write!(formatter, "bad native-link risk row {id}"),
            Self::PolicyNotFailClosed => write!(formatter, "native-link policy is not fail-closed"),
            Self::ProofRefsMissing => write!(formatter, "native-link proof refs are missing"),
            Self::MetadataBudgetExceeded => write!(formatter, "metadata budget exceeded"),
            Self::RuntimeOrModelBytesDetected => {
                write!(formatter, "runtime/model/provider bytes detected")
            }
            Self::NativeLinkExecutionDetected => {
                write!(formatter, "native-link execution detected")
            }
        }
    }
}

impl std::error::Error for TurboVecNativeLinkPreflightError {}

fn validate_rows(
    rows: &[TurboVecNativeLinkPreflightRow],
) -> Result<(), TurboVecNativeLinkPreflightError> {
    if rows.len() < MIN_RISK_ROWS {
        return Err(TurboVecNativeLinkPreflightError::MissingRiskRows);
    }
    let mut ids = BTreeSet::new();
    let mut surfaces = BTreeSet::new();
    for row in rows {
        if !ids.insert(row.risk_id.as_str()) {
            return Err(TurboVecNativeLinkPreflightError::DuplicateRiskId);
        }
        surfaces.insert(row.surface);
        if !row.is_blocked_metadata_only() {
            return Err(TurboVecNativeLinkPreflightError::BadRiskRow(
                row.risk_id.clone(),
            ));
        }
    }
    for required in [
        TurboVecNativeLinkSurface::RustBuildScript,
        TurboVecNativeLinkSurface::TargetSpecificBlas,
        TurboVecNativeLinkSurface::PythonExtension,
        TurboVecNativeLinkSurface::PythonBuildBackend,
        TurboVecNativeLinkSurface::CargoConfig,
        TurboVecNativeLinkSurface::DownstreamSmoke,
        TurboVecNativeLinkSurface::BenchmarkSurface,
        TurboVecNativeLinkSurface::ProductManifest,
        TurboVecNativeLinkSurface::ProductRouteSurface,
    ] {
        if !surfaces.contains(&required) {
            return Err(TurboVecNativeLinkPreflightError::MissingRiskRows);
        }
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecNativeLinkPreflightPolicy,
) -> Result<(), TurboVecNativeLinkPreflightError> {
    if policy.product_graph_no_contamination_required
        && policy.dependency_envelope_required
        && policy.source_manifest_required
        && policy.source_inspection_policy_required
        && policy.owner_approval_required_for_any_dry_run
        && policy.build_script_execution_denied
        && policy.cargo_build_denied
        && policy.linker_invocation_denied
        && policy.dynamic_library_load_denied
        && policy.python_extension_build_denied
        && policy.environment_mutation_denied
        && policy.product_dependency_insertion_denied
        && policy.product_route_mutation_denied
        && policy.benchmark_authority_denied
        && policy.rollback_required
        && policy.run_event_log_required
        && policy.answer_packet_required
        && policy.compatibility_fence_required
        && policy.no_runtime_or_model_bytes
        && policy.no_product_capability_promotion
    {
        Ok(())
    } else {
        Err(TurboVecNativeLinkPreflightError::PolicyNotFailClosed)
    }
}

fn validate_proofs(
    refs: &TurboVecNativeLinkPreflightProofRefs,
) -> Result<(), TurboVecNativeLinkPreflightError> {
    if refs.product_graph_ref.starts_with(PRODUCT_GRAPH_REF_PREFIX)
        && refs
            .dependency_envelope_ref
            .starts_with(DEPENDENCY_ENVELOPE_REF_PREFIX)
        && refs
            .source_manifest_ref
            .starts_with(SOURCE_MANIFEST_REF_PREFIX)
        && refs
            .source_inspection_policy_ref
            .starts_with(SOURCE_INSPECTION_REF_PREFIX)
        && refs
            .native_link_absence_ref
            .starts_with(NATIVE_LINK_REF_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_REF_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_REF_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_REF_PREFIX)
        && refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_REF_PREFIX)
        && refs.visible_summary.len() >= MIN_VISIBLE_SUMMARY_BYTES
        && refs.visible_summary.contains("no native-link")
        && refs.visible_summary.contains("AnswerPacket")
        && refs.visible_summary.contains("L2/L3")
    {
        Ok(())
    } else {
        Err(TurboVecNativeLinkPreflightError::ProofRefsMissing)
    }
}

fn validate_byte_ledger(
    ledger: &TurboVecNativeLinkPreflightByteLedger,
) -> Result<(), TurboVecNativeLinkPreflightError> {
    if ledger.upstream_product_graph_artifact_bytes_read
        + ledger.dependency_metadata_bytes_read
        + ledger.preflight_metadata_bytes_written
        > MAX_PREFLIGHT_METADATA_BYTES
    {
        return Err(TurboVecNativeLinkPreflightError::MetadataBudgetExceeded);
    }
    if ledger.raw_turbovec_source_bytes_read > 0
        || ledger.fetched_repo_bytes > 0
        || ledger.cloned_repo_bytes > 0
        || ledger.index_bytes_opened > 0
        || ledger.model_bytes_loaded > 0
        || ledger.runtime_model_bytes_loaded > 0
        || ledger.provider_calls_made > 0
    {
        return Err(TurboVecNativeLinkPreflightError::RuntimeOrModelBytesDetected);
    }
    if ledger.copied_product_file_count > 0
        || ledger.product_dependency_count > 0
        || ledger.build_script_exec_count > 0
        || ledger.cargo_build_invocation_count > 0
        || ledger.linker_invocation_count > 0
        || ledger.dynamic_library_load_count > 0
        || ledger.python_build_invocation_count > 0
        || ledger.environment_mutation_count > 0
        || ledger.benchmark_run_count > 0
    {
        return Err(TurboVecNativeLinkPreflightError::NativeLinkExecutionDetected);
    }
    Ok(())
}

pub fn native_link_absence_preflight_digest(
    set: &TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet,
) -> String {
    let rows: Vec<_> = set
        .rows
        .iter()
        .map(|row| {
            (
                row.risk_id.as_str(),
                row.surface,
                row.target_scope.as_str(),
                &row.source_refs,
                row.native_link_ref.as_str(),
                row.product_graph_ref.as_str(),
                row.allowed_action,
                row.owner_approval_required,
                row.native_link_absent,
            )
        })
        .collect();
    let payload = serde_json::json!({
        "source_url": set.source_url,
        "pinned_revision": set.pinned_revision,
        "upstream_product_graph": set.upstream_product_graph_address.to_string(),
        "rows": rows,
        "policy": set.policy,
        "proof_refs": set.proof_refs,
        "byte_ledger": set.byte_ledger,
        "product_build": set.product_build,
        "pro_status": set.pro_status,
        "status": set.status,
        "tier": set.tier,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                "turbovec_real_adapter_product_graph_no_contamination_probe".to_string(),
            ),
            b"product-graph-clean",
            1,
        )
    }

    fn row(id: &str, surface: TurboVecNativeLinkSurface) -> TurboVecNativeLinkPreflightRow {
        TurboVecNativeLinkPreflightRow {
            risk_id: id.to_string(),
            surface,
            target_scope: "preflight".to_string(),
            source_refs: vec![
                "artifact:turbovec_real_adapter_dependency_envelope_probe:result".to_string(),
            ],
            native_link_ref: format!("native_link:turbovec-preflight:{id}"),
            product_graph_ref: format!("product_graph:turbovec-no-contamination:{id}"),
            allowed_action: TurboVecNativeLinkAction::DenyNativeLink,
            owner_approval_required: true,
            native_link_absent: true,
            build_script_exec_count: 0,
            cargo_build_invocation_count: 0,
            linker_invocation_count: 0,
            dynamic_library_load_count: 0,
            python_build_invocation_count: 0,
            environment_mutation_count: 0,
            product_dependency_count: 0,
            product_route_mutation_count: 0,
            benchmark_authority_claim_count: 0,
        }
    }

    fn rows() -> Vec<TurboVecNativeLinkPreflightRow> {
        vec![
            row("build_rs", TurboVecNativeLinkSurface::RustBuildScript),
            row("macos_blas", TurboVecNativeLinkSurface::TargetSpecificBlas),
            row("linux_blas", TurboVecNativeLinkSurface::TargetSpecificBlas),
            row("pyo3", TurboVecNativeLinkSurface::PythonExtension),
            row("maturin", TurboVecNativeLinkSurface::PythonBuildBackend),
            row("numpy", TurboVecNativeLinkSurface::PythonRuntimePackage),
            row("cargo_cfg", TurboVecNativeLinkSurface::CargoConfig),
            row("smoke", TurboVecNativeLinkSurface::DownstreamSmoke),
            row("bench", TurboVecNativeLinkSurface::BenchmarkSurface),
            row("manifest", TurboVecNativeLinkSurface::ProductManifest),
            row("route", TurboVecNativeLinkSurface::ProductRouteSurface),
        ]
    }

    fn proof_refs() -> TurboVecNativeLinkPreflightProofRefs {
        TurboVecNativeLinkPreflightProofRefs {
            product_graph_ref: "product_graph:turbovec-no-contamination:native-link-preflight"
                .to_string(),
            dependency_envelope_ref: "artifact:turbovec_real_adapter_dependency_envelope_probe:result"
                .to_string(),
            source_manifest_ref:
                "artifact:turbovec_real_adapter_source_byte_manifest_probe:result".to_string(),
            source_inspection_policy_ref:
                "artifact:turbovec_real_adapter_source_inspection_policy_probe:result".to_string(),
            native_link_absence_ref: "native_link:turbovec-preflight:no-link-no-load"
                .to_string(),
            rollback_ref: "rollback:turbovec-native-link:drop-preflight-card".to_string(),
            run_event_log_ref: "run_event_log:turbovec-native-link:metadata-only".to_string(),
            answer_packet_ref: "answer_packet:turbovec-native-link:visible-non-promotion"
                .to_string(),
            compatibility_fence_ref: "compat:turbovec-native-link:no-product-deps".to_string(),
            visible_summary: "TurboVec native-link preflight is no native-link metadata only: build.rs, target BLAS, PyO3/maturin/numpy, cargo config, smoke tests, benchmark claims, product manifests, and route surfaces are blocked until owner-approved dry-run witnesses exist; AnswerPacket must show the L2/L3 non-promotion.".to_string(),
        }
    }

    fn set_with_rows(
        rows: Vec<TurboVecNativeLinkPreflightRow>,
    ) -> Result<
        TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet,
        TurboVecNativeLinkPreflightError,
    > {
        TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet::from_parts(
            upstream(),
            rows,
            TurboVecNativeLinkPreflightPolicy::fail_closed(),
            proof_refs(),
            TurboVecNativeLinkPreflightByteLedger::metadata_only(512, 512, 256)?,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
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
    fn accepts_metadata_only_preflight() {
        let set = set_with_rows(rows()).expect("metadata-only preflight should pass");
        let metrics = set.metrics();
        assert_eq!(metrics.row_count, 11);
        assert_eq!(metrics.linker_invocation_count, 0);
        assert_eq!(metrics.row_linker_invocation_count, 0);
    }

    #[test]
    fn address_is_deterministic_when_rows_reordered() {
        let forward = set_with_rows(rows()).expect("forward rows should pass");
        let mut reversed = rows();
        reversed.reverse();
        let reversed = set_with_rows(reversed).expect("reversed rows should pass");
        assert_eq!(forward.set_address, reversed.set_address);
    }

    #[test]
    fn rejects_native_link_execution() {
        let mut rows = rows();
        rows[0].build_script_exec_count = 1;
        assert!(matches!(
            set_with_rows(rows),
            Err(TurboVecNativeLinkPreflightError::BadRiskRow(_))
        ));
    }

    #[test]
    fn rejects_product_promotion_and_runtime_bytes() {
        let result = TurboVecRealAdapterNativeLinkAbsencePreflightProbeSet::from_parts(
            upstream(),
            rows(),
            TurboVecNativeLinkPreflightPolicy::fail_closed(),
            proof_refs(),
            TurboVecNativeLinkPreflightByteLedger {
                model_bytes_loaded: 1,
                ..TurboVecNativeLinkPreflightByteLedger::metadata_only(512, 512, 256)
                    .expect("ledger")
            },
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeLinkPreflightStatus::MetadataOnlyNoNativeLink,
            TurboVecNativeLinkPreflightTier::T1L1Metadata,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(result.is_err());
    }
}
