//! TurboVec real-adapter product-graph no-contamination probe.
//!
//! This primitive proves that the TurboVec real-adapter research ladder remains
//! outside the product graph after exact-baseline shadow replay. It permits
//! architecture falsifier/canon references, but rejects product imports,
//! dependencies, native-link probes, route policy, model-context injection,
//! user-facing green copy, runtime bytes, provider calls, and live large-model
//! claims.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_CURSOR: &str =
    "turbovec_quarantine_real_adapter_product_graph_no_contamination_probe";
pub const TURBOVEC_REAL_ADAPTER_PRODUCT_GRAPH_NO_CONTAMINATION_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_native_link_absence_preflight_probe";

const SHADOW_REPLAY_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_exact_baseline_shadow_replay_probe:result";
const SHADOW_REPLAY_ADDRESS_PREFIX: &str =
    "turbovec_real_adapter_exact_baseline_shadow_replay_probe:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const PRODUCT_GRAPH_REF_PREFIX: &str = "product_graph:turbovec-no-contamination:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-product-graph:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-product-graph:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-product-graph:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-product-graph:";
const MAX_SCANNED_PRODUCT_BYTES: u64 = 16 * 1024 * 1024;
const MAX_SCANNED_MANIFEST_BYTES: u64 = 2 * 1024 * 1024;
const MAX_ARCHITECTURE_METADATA_BYTES: u64 = 8 * 1024 * 1024;

// UAS: uas:turbovec-product-graph:status
// Plane: Verification
// Residency: product graph audit status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecProductGraphStatus {
    MetadataOnlyNoContamination,
    ProductCandidate,
    RuntimeCandidate,
}

// UAS: uas:turbovec-product-graph:tier
// Plane: Verification
// Residency: T1/L1 proof only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecProductGraphTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-product-graph:surface
// Plane: State + Controller + Verification
// Residency: surface class checked for contamination.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecProductGraphSurface {
    SwiftProductSource,
    SwiftUserFacingCopy,
    SwiftRuntimeRouting,
    RustRuntimeRouting,
    ProductManifest,
    ArchitectureFalsifierGraph,
    CanonSurface,
}

impl TurboVecProductGraphSurface {
    pub fn allows_canon_mentions(self) -> bool {
        matches!(self, Self::ArchitectureFalsifierGraph | Self::CanonSurface)
    }
}

// UAS: uas:turbovec-product-graph:row
// Plane: Verification
// Residency: single scanned product/canon surface.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecProductGraphAuditRow {
    pub surface_id: String,
    pub surface: TurboVecProductGraphSurface,
    pub path_glob: String,
    pub scanned_file_count: u64,
    pub scanned_bytes: u64,
    pub allowed_architecture_mentions: u64,
    pub forbidden_turbovec_mentions: u64,
    pub product_import_mentions: u64,
    pub product_dependency_mentions: u64,
    pub native_link_mentions: u64,
    pub route_policy_mentions: u64,
    pub model_context_mentions: u64,
    pub user_facing_green_copy_mentions: u64,
    pub hidden_cloud_or_provider_fallback_mentions: u64,
    pub live_large_model_claim_mentions: u64,
    pub ssd_as_ram_claim_mentions: u64,
    pub product_files_copied: u64,
    pub product_graph_mutation_count: u64,
    pub proof_ref: String,
}

impl TurboVecProductGraphAuditRow {
    pub fn is_clean(&self) -> bool {
        self.scanned_file_count > 0
            && self.scanned_bytes > 0
            && self.forbidden_turbovec_mentions == 0
            && self.product_import_mentions == 0
            && self.product_dependency_mentions == 0
            && self.native_link_mentions == 0
            && self.route_policy_mentions == 0
            && self.model_context_mentions == 0
            && self.user_facing_green_copy_mentions == 0
            && self.hidden_cloud_or_provider_fallback_mentions == 0
            && self.live_large_model_claim_mentions == 0
            && self.ssd_as_ram_claim_mentions == 0
            && self.product_files_copied == 0
            && self.product_graph_mutation_count == 0
            && self
                .proof_ref
                .starts_with(&format!("{PRODUCT_GRAPH_REF_PREFIX}{}", self.surface_id))
    }

    pub fn is_allowed_architecture_surface(&self) -> bool {
        self.surface.allows_canon_mentions()
            && self.allowed_architecture_mentions > 0
            && self.forbidden_turbovec_mentions == 0
            && self.product_import_mentions == 0
            && self.product_dependency_mentions == 0
            && self.native_link_mentions == 0
            && self.route_policy_mentions == 0
            && self.model_context_mentions == 0
            && self.user_facing_green_copy_mentions == 0
            && self.hidden_cloud_or_provider_fallback_mentions == 0
            && self.live_large_model_claim_mentions == 0
            && self.ssd_as_ram_claim_mentions == 0
            && self.product_files_copied == 0
            && self.product_graph_mutation_count == 0
            && self
                .proof_ref
                .starts_with(&format!("{PRODUCT_GRAPH_REF_PREFIX}{}", self.surface_id))
    }
}

// UAS: uas:turbovec-product-graph:policy
// Plane: Controller + Verification
// Residency: fail-closed non-contamination policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecProductGraphPolicy {
    pub exact_baseline_shadow_replay_required: bool,
    pub product_source_scan_required: bool,
    pub product_manifest_scan_required: bool,
    pub runtime_route_scan_required: bool,
    pub model_context_scan_required: bool,
    pub user_copy_scan_required: bool,
    pub architecture_mentions_quarantined: bool,
    pub no_product_import: bool,
    pub no_product_dependency: bool,
    pub no_native_link_probe: bool,
    pub no_adapter_build: bool,
    pub no_runtime_execution: bool,
    pub no_route_policy_mutation: bool,
    pub no_model_context_injection: bool,
    pub no_user_facing_green_copy: bool,
    pub no_hidden_cloud_fallback: bool,
    pub no_live_large_model_claim: bool,
    pub no_ssd_as_ram_claim: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
}

impl TurboVecProductGraphPolicy {
    pub fn fail_closed() -> Self {
        Self {
            exact_baseline_shadow_replay_required: true,
            product_source_scan_required: true,
            product_manifest_scan_required: true,
            runtime_route_scan_required: true,
            model_context_scan_required: true,
            user_copy_scan_required: true,
            architecture_mentions_quarantined: true,
            no_product_import: true,
            no_product_dependency: true,
            no_native_link_probe: true,
            no_adapter_build: true,
            no_runtime_execution: true,
            no_route_policy_mutation: true,
            no_model_context_injection: true,
            no_user_facing_green_copy: true,
            no_hidden_cloud_fallback: true,
            no_live_large_model_claim: true,
            no_ssd_as_ram_claim: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
        }
    }
}

// UAS: uas:turbovec-product-graph:byte-ledger
// Plane: Verification
// Residency: metadata/source-scan byte accounting; no runtime/model bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecProductGraphByteLedger {
    pub scanned_product_bytes: u64,
    pub scanned_manifest_bytes: u64,
    pub scanned_architecture_metadata_bytes: u64,
    pub additional_turbovec_raw_source_bytes_inspected: u64,
    pub copied_product_file_count: u64,
    pub product_dependencies_added: u64,
    pub native_link_probe_count: u64,
    pub adapter_build_count: u64,
    pub benchmark_run_count: u64,
    pub exact_baseline_bytes_opened: u64,
    pub index_bytes_opened: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_model_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl TurboVecProductGraphByteLedger {
    pub fn metadata_only(
        scanned_product_bytes: u64,
        scanned_manifest_bytes: u64,
        scanned_architecture_metadata_bytes: u64,
    ) -> Result<Self, TurboVecProductGraphError> {
        if scanned_product_bytes > MAX_SCANNED_PRODUCT_BYTES
            || scanned_manifest_bytes > MAX_SCANNED_MANIFEST_BYTES
            || scanned_architecture_metadata_bytes > MAX_ARCHITECTURE_METADATA_BYTES
        {
            return Err(TurboVecProductGraphError::MetadataBudgetExceeded);
        }
        Ok(Self {
            scanned_product_bytes,
            scanned_manifest_bytes,
            scanned_architecture_metadata_bytes,
            additional_turbovec_raw_source_bytes_inspected: 0,
            copied_product_file_count: 0,
            product_dependencies_added: 0,
            native_link_probe_count: 0,
            adapter_build_count: 0,
            benchmark_run_count: 0,
            exact_baseline_bytes_opened: 0,
            index_bytes_opened: 0,
            allocated_runtime_bytes: 0,
            runtime_model_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
        })
    }
}

// UAS: uas:turbovec-product-graph:proof-refs
// Plane: Verification
// Residency: visible proof handles for non-contamination.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecProductGraphProofRefs {
    pub product_graph_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-product-graph:set
// Plane: State + Controller + Verification
// Residency: deterministic product-graph no-contamination witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterProductGraphNoContaminationProbeSet {
    pub upstream_shadow_replay_witness_ref: String,
    pub upstream_shadow_replay_address: UasAddress,
    pub source_url: String,
    pub pinned_revision: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecProductGraphStatus,
    pub tier: TurboVecProductGraphTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub rows: Vec<TurboVecProductGraphAuditRow>,
    pub policy: TurboVecProductGraphPolicy,
    pub proof_refs: TurboVecProductGraphProofRefs,
    pub byte_ledger: TurboVecProductGraphByteLedger,
    pub product_capability_promoted: bool,
    pub product_graph_mutated: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub set_address: UasAddress,
}

impl TurboVecRealAdapterProductGraphNoContaminationProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_shadow_replay_address: UasAddress,
        rows: Vec<TurboVecProductGraphAuditRow>,
        policy: TurboVecProductGraphPolicy,
        proof_refs: TurboVecProductGraphProofRefs,
        byte_ledger: TurboVecProductGraphByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecProductGraphStatus,
        tier: TurboVecProductGraphTier,
        product_capability_promoted: bool,
        product_graph_mutated: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecProductGraphError> {
        let mut sorted_rows = rows;
        sorted_rows.sort_by(|left, right| left.surface_id.cmp(&right.surface_id));
        let organs = vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ];
        let mut set = Self {
            upstream_shadow_replay_witness_ref: SHADOW_REPLAY_WITNESS_REF.to_string(),
            upstream_shadow_replay_address,
            source_url: SOURCE_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            product_build,
            pro_status,
            status,
            tier,
            organs,
            rows: sorted_rows,
            policy,
            proof_refs,
            byte_ledger,
            product_capability_promoted,
            product_graph_mutated,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
            set_address: UasAddress::new(
                UasKind::Other(
                    "turbovec_real_adapter_product_graph_no_contamination_probe".to_string(),
                ),
                b"pending",
                1_779_040_907_000,
            ),
        };
        set.validate()?;
        let digest = product_graph_no_contamination_digest(&set);
        set.set_address = UasAddress::new(
            UasKind::Other(
                "turbovec_real_adapter_product_graph_no_contamination_probe".to_string(),
            ),
            digest.as_bytes(),
            1_779_040_907_000,
        );
        Ok(set)
    }

    pub fn metrics(&self) -> TurboVecProductGraphMetrics {
        let mut metrics = TurboVecProductGraphMetrics {
            row_count: self.rows.len() as u64,
            scanned_file_count: 0,
            scanned_product_bytes: self.byte_ledger.scanned_product_bytes,
            scanned_manifest_bytes: self.byte_ledger.scanned_manifest_bytes,
            scanned_architecture_metadata_bytes: self
                .byte_ledger
                .scanned_architecture_metadata_bytes,
            additional_turbovec_raw_source_bytes_inspected: self
                .byte_ledger
                .additional_turbovec_raw_source_bytes_inspected,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            product_dependencies_added: self.byte_ledger.product_dependencies_added,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            adapter_build_count: self.byte_ledger.adapter_build_count,
            benchmark_run_count: self.byte_ledger.benchmark_run_count,
            exact_baseline_bytes_opened: self.byte_ledger.exact_baseline_bytes_opened,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
            allocated_runtime_bytes: self.byte_ledger.allocated_runtime_bytes,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            product_capability_promoted_count: u64::from(self.product_capability_promoted),
            product_graph_mutation_count: u64::from(self.product_graph_mutated),
            route_mutation_count: u64::from(self.route_mutation_allowed),
            model_context_injection_count: u64::from(self.model_context_injected),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
            live_large_model_claim_count: u64::from(self.live_large_model_claimed),
            ssd_as_ram_claim_count: u64::from(self.ssd_as_ram_claimed),
            ..TurboVecProductGraphMetrics::default()
        };
        for row in &self.rows {
            metrics.scanned_file_count += row.scanned_file_count;
            if row.surface == TurboVecProductGraphSurface::SwiftProductSource {
                metrics.swift_product_source_rows += 1;
            }
            if row.surface == TurboVecProductGraphSurface::SwiftUserFacingCopy {
                metrics.user_facing_copy_rows += 1;
            }
            if matches!(
                row.surface,
                TurboVecProductGraphSurface::SwiftRuntimeRouting
                    | TurboVecProductGraphSurface::RustRuntimeRouting
            ) {
                metrics.runtime_route_rows += 1;
            }
            if row.surface == TurboVecProductGraphSurface::ProductManifest {
                metrics.product_manifest_rows += 1;
            }
            if row.surface.allows_canon_mentions() {
                metrics.quarantined_architecture_rows += 1;
            }
            metrics.allowed_architecture_mentions += row.allowed_architecture_mentions;
            metrics.forbidden_turbovec_mentions += row.forbidden_turbovec_mentions;
            metrics.product_import_mentions += row.product_import_mentions;
            metrics.product_dependency_mentions += row.product_dependency_mentions;
            metrics.native_link_mentions += row.native_link_mentions;
            metrics.route_policy_mentions += row.route_policy_mentions;
            metrics.model_context_mentions += row.model_context_mentions;
            metrics.user_facing_green_copy_mentions += row.user_facing_green_copy_mentions;
            metrics.hidden_cloud_or_provider_fallback_mentions +=
                row.hidden_cloud_or_provider_fallback_mentions;
            metrics.live_large_model_claim_mentions += row.live_large_model_claim_mentions;
            metrics.ssd_as_ram_claim_mentions += row.ssd_as_ram_claim_mentions;
            metrics.row_product_files_copied += row.product_files_copied;
            metrics.row_product_graph_mutations += row.product_graph_mutation_count;
        }
        metrics
    }

    fn validate(&self) -> Result<(), TurboVecProductGraphError> {
        if self.upstream_shadow_replay_witness_ref != SHADOW_REPLAY_WITNESS_REF
            || !self
                .upstream_shadow_replay_address
                .to_string()
                .starts_with(SHADOW_REPLAY_ADDRESS_PREFIX)
        {
            return Err(TurboVecProductGraphError::UpstreamShadowReplayNotBound);
        }
        if self.source_url != SOURCE_URL || self.pinned_revision != PINNED_REVISION {
            return Err(TurboVecProductGraphError::BadSourceIdentity);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.status != TurboVecProductGraphStatus::MetadataOnlyNoContamination
            || self.tier != TurboVecProductGraphTier::T1L1Metadata
        {
            return Err(TurboVecProductGraphError::PromotionBoundaryViolation);
        }
        validate_policy(&self.policy)?;
        validate_rows(&self.rows)?;
        validate_proofs(&self.proof_refs)?;
        validate_bytes(&self.byte_ledger)?;
        if self.product_capability_promoted
            || self.product_graph_mutated
            || self.route_mutation_allowed
            || self.model_context_injected
            || self.hidden_route_authority
            || self.hidden_cloud_fallback_allowed
            || self.live_large_model_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(TurboVecProductGraphError::ClaimBoundaryViolation);
        }
        Ok(())
    }
}

// UAS: uas:turbovec-product-graph:metrics
// Plane: Verification
// Residency: artifact axes for non-contamination proof.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecProductGraphMetrics {
    pub row_count: u64,
    pub swift_product_source_rows: u64,
    pub user_facing_copy_rows: u64,
    pub runtime_route_rows: u64,
    pub product_manifest_rows: u64,
    pub quarantined_architecture_rows: u64,
    pub scanned_file_count: u64,
    pub scanned_product_bytes: u64,
    pub scanned_manifest_bytes: u64,
    pub scanned_architecture_metadata_bytes: u64,
    pub allowed_architecture_mentions: u64,
    pub forbidden_turbovec_mentions: u64,
    pub product_import_mentions: u64,
    pub product_dependency_mentions: u64,
    pub native_link_mentions: u64,
    pub route_policy_mentions: u64,
    pub model_context_mentions: u64,
    pub user_facing_green_copy_mentions: u64,
    pub hidden_cloud_or_provider_fallback_mentions: u64,
    pub live_large_model_claim_mentions: u64,
    pub ssd_as_ram_claim_mentions: u64,
    pub row_product_files_copied: u64,
    pub row_product_graph_mutations: u64,
    pub additional_turbovec_raw_source_bytes_inspected: u64,
    pub copied_product_file_count: u64,
    pub product_dependencies_added: u64,
    pub native_link_probe_count: u64,
    pub adapter_build_count: u64,
    pub benchmark_run_count: u64,
    pub exact_baseline_bytes_opened: u64,
    pub index_bytes_opened: u64,
    pub allocated_runtime_bytes: u64,
    pub runtime_model_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_capability_promoted_count: u64,
    pub product_graph_mutation_count: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
    pub live_large_model_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

// UAS: uas:turbovec-product-graph:error
// Plane: Verification
// Residency: no-contamination validation failures.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecProductGraphError {
    UpstreamShadowReplayNotBound,
    BadSourceIdentity,
    PromotionBoundaryViolation,
    UnsafePolicy,
    MissingSurface(TurboVecProductGraphSurface),
    DuplicateSurfaceId(String),
    ContaminatedRow(String),
    RuntimeOrProductBytesNotDeferred,
    BadProofRef(String),
    WeakVisibleSummary,
    MetadataBudgetExceeded,
    ClaimBoundaryViolation,
}

impl fmt::Display for TurboVecProductGraphError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UpstreamShadowReplayNotBound => {
                write!(f, "upstream exact-baseline shadow replay not bound")
            }
            Self::BadSourceIdentity => write!(f, "source URL or pinned revision mismatch"),
            Self::PromotionBoundaryViolation => write!(f, "product graph attempted promotion"),
            Self::UnsafePolicy => write!(f, "product graph policy is not fail-closed"),
            Self::MissingSurface(surface) => write!(f, "missing required surface {surface:?}"),
            Self::DuplicateSurfaceId(id) => write!(f, "duplicate surface id {id}"),
            Self::ContaminatedRow(id) => write!(f, "contaminated product graph row {id}"),
            Self::RuntimeOrProductBytesNotDeferred => {
                write!(f, "runtime/product bytes were not deferred")
            }
            Self::BadProofRef(value) => write!(f, "bad proof ref {value}"),
            Self::WeakVisibleSummary => write!(f, "visible summary lacks required caveats"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::ClaimBoundaryViolation => {
                write!(f, "hidden authority or product claim attempted")
            }
        }
    }
}

impl std::error::Error for TurboVecProductGraphError {}

fn validate_policy(policy: &TurboVecProductGraphPolicy) -> Result<(), TurboVecProductGraphError> {
    if policy.exact_baseline_shadow_replay_required
        && policy.product_source_scan_required
        && policy.product_manifest_scan_required
        && policy.runtime_route_scan_required
        && policy.model_context_scan_required
        && policy.user_copy_scan_required
        && policy.architecture_mentions_quarantined
        && policy.no_product_import
        && policy.no_product_dependency
        && policy.no_native_link_probe
        && policy.no_adapter_build
        && policy.no_runtime_execution
        && policy.no_route_policy_mutation
        && policy.no_model_context_injection
        && policy.no_user_facing_green_copy
        && policy.no_hidden_cloud_fallback
        && policy.no_live_large_model_claim
        && policy.no_ssd_as_ram_claim
        && policy.rollback_required
        && policy.run_event_log_required
        && policy.answer_packet_required
        && policy.compatibility_fence_required
    {
        Ok(())
    } else {
        Err(TurboVecProductGraphError::UnsafePolicy)
    }
}

fn validate_rows(rows: &[TurboVecProductGraphAuditRow]) -> Result<(), TurboVecProductGraphError> {
    if rows.len() < 7 {
        return Err(TurboVecProductGraphError::MissingSurface(
            TurboVecProductGraphSurface::SwiftProductSource,
        ));
    }
    let mut ids = BTreeSet::new();
    let surfaces = rows.iter().map(|row| row.surface).collect::<BTreeSet<_>>();
    for required in [
        TurboVecProductGraphSurface::SwiftProductSource,
        TurboVecProductGraphSurface::SwiftUserFacingCopy,
        TurboVecProductGraphSurface::SwiftRuntimeRouting,
        TurboVecProductGraphSurface::RustRuntimeRouting,
        TurboVecProductGraphSurface::ProductManifest,
        TurboVecProductGraphSurface::ArchitectureFalsifierGraph,
        TurboVecProductGraphSurface::CanonSurface,
    ] {
        if !surfaces.contains(&required) {
            return Err(TurboVecProductGraphError::MissingSurface(required));
        }
    }
    for row in rows {
        if row.surface_id.trim().is_empty() || row.path_glob.trim().is_empty() {
            return Err(TurboVecProductGraphError::ContaminatedRow(
                row.surface_id.clone(),
            ));
        }
        if !ids.insert(row.surface_id.clone()) {
            return Err(TurboVecProductGraphError::DuplicateSurfaceId(
                row.surface_id.clone(),
            ));
        }
        let clean = if row.surface.allows_canon_mentions() {
            row.is_allowed_architecture_surface()
        } else {
            row.allowed_architecture_mentions == 0 && row.is_clean()
        };
        if !clean {
            return Err(TurboVecProductGraphError::ContaminatedRow(
                row.surface_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_proofs(
    proofs: &TurboVecProductGraphProofRefs,
) -> Result<(), TurboVecProductGraphError> {
    for (name, value, prefix) in [
        (
            "product_graph_ref",
            &proofs.product_graph_ref,
            PRODUCT_GRAPH_REF_PREFIX,
        ),
        ("rollback_ref", &proofs.rollback_ref, ROLLBACK_REF_PREFIX),
        (
            "run_event_log_ref",
            &proofs.run_event_log_ref,
            RUN_EVENT_LOG_REF_PREFIX,
        ),
        (
            "answer_packet_ref",
            &proofs.answer_packet_ref,
            ANSWER_PACKET_REF_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            &proofs.compatibility_fence_ref,
            COMPATIBILITY_REF_PREFIX,
        ),
    ] {
        if !value.starts_with(prefix) {
            return Err(TurboVecProductGraphError::BadProofRef(format!(
                "{name}={value}"
            )));
        }
    }
    let summary = proofs.visible_summary.to_ascii_lowercase();
    for required in [
        "product graph no-contamination",
        "no product import",
        "no product dependency",
        "no hidden route authority",
        "no live dense 70b",
        "answerpacket",
        "l2/l3",
    ] {
        if !summary.contains(required) {
            return Err(TurboVecProductGraphError::WeakVisibleSummary);
        }
    }
    Ok(())
}

fn validate_bytes(
    ledger: &TurboVecProductGraphByteLedger,
) -> Result<(), TurboVecProductGraphError> {
    if ledger.scanned_product_bytes > MAX_SCANNED_PRODUCT_BYTES
        || ledger.scanned_manifest_bytes > MAX_SCANNED_MANIFEST_BYTES
        || ledger.scanned_architecture_metadata_bytes > MAX_ARCHITECTURE_METADATA_BYTES
    {
        return Err(TurboVecProductGraphError::MetadataBudgetExceeded);
    }
    if ledger.additional_turbovec_raw_source_bytes_inspected != 0
        || ledger.copied_product_file_count != 0
        || ledger.product_dependencies_added != 0
        || ledger.native_link_probe_count != 0
        || ledger.adapter_build_count != 0
        || ledger.benchmark_run_count != 0
        || ledger.exact_baseline_bytes_opened != 0
        || ledger.index_bytes_opened != 0
        || ledger.allocated_runtime_bytes != 0
        || ledger.runtime_model_bytes_loaded != 0
        || ledger.model_bytes_loaded != 0
        || ledger.provider_calls_made != 0
    {
        return Err(TurboVecProductGraphError::RuntimeOrProductBytesNotDeferred);
    }
    Ok(())
}

pub fn product_graph_no_contamination_digest(
    set: &TurboVecRealAdapterProductGraphNoContaminationProbeSet,
) -> String {
    let mut rows = set.rows.clone();
    rows.sort_by(|left, right| left.surface_id.cmp(&right.surface_id));
    let payload = serde_json::json!({
        "upstream": set.upstream_shadow_replay_address.to_string(),
        "source_url": set.source_url,
        "pinned_revision": set.pinned_revision,
        "product_build": set.product_build,
        "pro_status": set.pro_status,
        "status": set.status,
        "tier": set.tier,
        "organs": set.organs,
        "rows": rows,
        "policy": set.policy,
        "proof_refs": set.proof_refs,
        "byte_ledger": set.byte_ledger,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_exact_baseline_shadow_replay_probe".to_string()),
            b"accepted-shadow",
            1_779_040_906_000,
        )
    }

    fn row(id: &str, surface: TurboVecProductGraphSurface) -> TurboVecProductGraphAuditRow {
        TurboVecProductGraphAuditRow {
            surface_id: id.to_string(),
            surface,
            path_glob: format!("fixture/{id}"),
            scanned_file_count: 1,
            scanned_bytes: 256,
            allowed_architecture_mentions: if surface.allows_canon_mentions() {
                3
            } else {
                0
            },
            forbidden_turbovec_mentions: 0,
            product_import_mentions: 0,
            product_dependency_mentions: 0,
            native_link_mentions: 0,
            route_policy_mentions: 0,
            model_context_mentions: 0,
            user_facing_green_copy_mentions: 0,
            hidden_cloud_or_provider_fallback_mentions: 0,
            live_large_model_claim_mentions: 0,
            ssd_as_ram_claim_mentions: 0,
            product_files_copied: 0,
            product_graph_mutation_count: 0,
            proof_ref: format!("{PRODUCT_GRAPH_REF_PREFIX}{id}:accepted"),
        }
    }

    fn rows() -> Vec<TurboVecProductGraphAuditRow> {
        vec![
            row(
                "swift_product",
                TurboVecProductGraphSurface::SwiftProductSource,
            ),
            row(
                "swift_copy",
                TurboVecProductGraphSurface::SwiftUserFacingCopy,
            ),
            row(
                "swift_routes",
                TurboVecProductGraphSurface::SwiftRuntimeRouting,
            ),
            row(
                "rust_routes",
                TurboVecProductGraphSurface::RustRuntimeRouting,
            ),
            row("manifest", TurboVecProductGraphSurface::ProductManifest),
            row(
                "architecture",
                TurboVecProductGraphSurface::ArchitectureFalsifierGraph,
            ),
            row("canon", TurboVecProductGraphSurface::CanonSurface),
        ]
    }

    fn proofs() -> TurboVecProductGraphProofRefs {
        TurboVecProductGraphProofRefs {
            product_graph_ref: format!("{PRODUCT_GRAPH_REF_PREFIX}accepted"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}accepted"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}accepted"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}accepted"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}accepted"),
            visible_summary: "Product graph no-contamination proof: no product import, no product dependency, no native link, no hidden route authority, no live dense 70B, no SSD-as-RAM, and no L2/L3 promotion. AnswerPacket-visible caveats preserve TurboVec as architecture/canon evidence only."
                .to_string(),
        }
    }

    fn ledger() -> TurboVecProductGraphByteLedger {
        TurboVecProductGraphByteLedger::metadata_only(10_000, 2_000, 4_000)
            .expect("valid metadata ledger")
    }

    fn accepted() -> TurboVecRealAdapterProductGraphNoContaminationProbeSet {
        TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
            upstream(),
            rows(),
            TurboVecProductGraphPolicy::fail_closed(),
            proofs(),
            ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphStatus::MetadataOnlyNoContamination,
            TurboVecProductGraphTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("accepted no-contamination set")
    }

    #[test]
    fn accepts_product_graph_no_contamination() {
        let set = accepted();
        let metrics = set.metrics();
        assert_eq!(metrics.row_count, 7);
        assert_eq!(metrics.product_import_mentions, 0);
        assert!(metrics.allowed_architecture_mentions > 0);
    }

    #[test]
    fn address_is_deterministic_when_rows_reordered() {
        let set = accepted();
        let mut reversed = rows();
        reversed.reverse();
        let other = TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
            upstream(),
            reversed,
            TurboVecProductGraphPolicy::fail_closed(),
            proofs(),
            ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecProductGraphStatus::MetadataOnlyNoContamination,
            TurboVecProductGraphTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("reordered no-contamination set");
        assert_eq!(set.set_address, other.set_address);
    }

    #[test]
    fn rejects_product_dependency_and_green_copy() {
        let mut contaminated_rows = rows();
        contaminated_rows[0].product_dependency_mentions = 1;
        assert!(
            TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
                upstream(),
                contaminated_rows,
                TurboVecProductGraphPolicy::fail_closed(),
                proofs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err()
        );

        let mut contaminated_rows = rows();
        contaminated_rows[1].user_facing_green_copy_mentions = 1;
        assert!(
            TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
                upstream(),
                contaminated_rows,
                TurboVecProductGraphPolicy::fail_closed(),
                proofs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err()
        );
    }

    #[test]
    fn rejects_runtime_bytes_and_promotion() {
        let mut contaminated_ledger = ledger();
        contaminated_ledger.index_bytes_opened = 1;
        assert!(
            TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
                upstream(),
                rows(),
                TurboVecProductGraphPolicy::fail_closed(),
                proofs(),
                contaminated_ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err()
        );

        assert!(
            TurboVecRealAdapterProductGraphNoContaminationProbeSet::from_parts(
                upstream(),
                rows(),
                TurboVecProductGraphPolicy::fail_closed(),
                proofs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::Live,
                TurboVecProductGraphStatus::MetadataOnlyNoContamination,
                TurboVecProductGraphTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err()
        );
    }
}
