//! TurboVec real-adapter quarantine sandbox-layout probe.
//!
//! This primitive defines the allowed filesystem layout for future
//! quarantine-only TurboVec adapter research. It makes the large-local-model
//! compression path more buildable without fetching, cloning, importing,
//! building, routing, or loading repository, index, model, runtime, or provider
//! bytes.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_sandbox_layout_probe";
pub const TURBOVEC_REAL_ADAPTER_SANDBOX_LAYOUT_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_fetch_lease_probe";

const DEPENDENCY_ENVELOPE_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_dependency_envelope_probe:result";
const DEPENDENCY_ENVELOPE_PREFIX: &str = "turbovec_real_adapter_dependency_envelope_probe:";
const QUARANTINE_ROOT_PREFIX: &str = "quarantine_root:turbovec-sandbox:";
const SLOT_REF_PREFIX: &str = "quarantine_slot:turbovec-sandbox:";
const CLEANUP_REF_PREFIX: &str = "cleanup:turbovec-sandbox:";
const PROVENANCE_REF_PREFIX: &str = "provenance:turbovec-sandbox:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-sandbox:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-sandbox:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-sandbox:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-sandbox:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-sandbox:";
const BENCHMARK_CAVEAT_PREFIX: &str = "benchmark_caveat:turbovec-sandbox:";
const MAX_LAYOUT_METADATA_BYTES: u64 = 2 * 1024 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 280;
const MIN_LAYOUT_SLOTS: usize = 10;
const MIN_CLEANUP_PHASES: usize = 5;

// UAS: uas:turbovec-real-adapter-sandbox-layout:status
// Plane: Controller + Verification
// Residency: metadata-only sandbox-layout status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSandboxLayoutStatus {
    MetadataOnly,
    Blocked,
    RuntimeApprovedByLaterWitness,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:tier
// Plane: Verification
// Residency: L1-only promotion boundary for quarantine layout.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSandboxLayoutTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:action
// Plane: Controller + Verification
// Residency: allowed slot action; this witness accepts metadata-only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSandboxLayoutAction {
    MetadataOnly,
    FetchQuarantineBytes,
    CloneRepo,
    CopyProductSource,
    AddProductDependency,
    BuildAdapter,
    NativeLinkProbe,
    RuntimeRoute,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:slot-kind
// Plane: State + Assembly + Verification
// Residency: future quarantine slot class, no bytes present in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSandboxSlotKind {
    SourceTreeSnapshot,
    ForkSweepSnapshot,
    ManifestSnapshot,
    ExtractedApiNotes,
    ExtractedTestSpecs,
    BenchmarkTranscripts,
    FailureReports,
    CleanRoomRewriteNotes,
    NativeLinkNotes,
    CleanupTombstones,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:cleanup-phase
// Plane: Controller + Verification
// Residency: cleanup/rollback phases for future quarantine byte leases.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSandboxCleanupPhase {
    PreflightSnapshot,
    FetchLeaseExpiry,
    BuildOutputScrub,
    ProductGraphAudit,
    TombstoneCommit,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:path-policy
// Plane: Controller + Verification
// Residency: fail-closed path policy before any quarantine byte fetch.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSandboxPathPolicy {
    pub quarantine_root_ref: String,
    pub quarantine_root: String,
    pub forbidden_product_roots: Vec<String>,
    pub reject_absolute_paths: bool,
    pub reject_traversal: bool,
    pub reject_symlink_slots: bool,
    pub reject_executable_slots: bool,
    pub reject_product_writable_slots: bool,
    pub deny_build_graph_membership: bool,
    pub deny_runtime_route_membership: bool,
    pub require_cleanup_ledger: bool,
    pub require_answer_packet: bool,
}

impl TurboVecSandboxPathPolicy {
    pub fn fail_closed(quarantine_root: impl Into<String>) -> Self {
        Self {
            quarantine_root_ref: format!(
                "{QUARANTINE_ROOT_PREFIX}{}",
                "efe29a184986cbf562a9847c2ac52a2990bfaca2"
            ),
            quarantine_root: quarantine_root.into(),
            forbidden_product_roots: vec![
                "agent_core".to_string(),
                "Epistemos".to_string(),
                "graph-engine".to_string(),
                "graph-engine-bridge".to_string(),
                "Tools".to_string(),
                "docs".to_string(),
                "artifacts/falsifiers".to_string(),
                "benchmarks/results".to_string(),
                "target".to_string(),
                ".git".to_string(),
            ],
            reject_absolute_paths: true,
            reject_traversal: true,
            reject_symlink_slots: true,
            reject_executable_slots: true,
            reject_product_writable_slots: true,
            deny_build_graph_membership: true,
            deny_runtime_route_membership: true,
            require_cleanup_ledger: true,
            require_answer_packet: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:slot
// Plane: State + Verification
// Residency: typed quarantine slot; this witness records layout only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSandboxSlot {
    pub slot_id: String,
    pub kind: TurboVecSandboxSlotKind,
    pub relative_path: String,
    pub slot_ref: String,
    pub purpose_ref: String,
    pub read_only: bool,
    pub symlink_allowed: bool,
    pub executable_allowed: bool,
    pub writes_product_path: bool,
    pub build_graph_member: bool,
    pub runtime_route_member: bool,
    pub allowed_action: TurboVecSandboxLayoutAction,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:byte-ledger
// Plane: Verification
// Residency: zero-byte runtime/product ledger for layout-only proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSandboxByteLedger {
    pub layout_metadata_bytes_read: u64,
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

impl TurboVecSandboxByteLedger {
    pub fn metadata_only(layout_metadata_bytes_read: u64, planned_quarantine_bytes: u64) -> Self {
        Self {
            layout_metadata_bytes_read,
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

// UAS: uas:turbovec-real-adapter-sandbox-layout:cleanup-ledger
// Plane: Controller + Verification
// Residency: cleanup proof plan for future quarantine byte leases.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSandboxCleanupLedger {
    pub phases: Vec<TurboVecSandboxCleanupPhase>,
    pub cleanup_ref: String,
    pub tombstone_ref: String,
    pub rollback_ref: String,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:proof-refs
// Plane: Verification
// Residency: visible provenance, rollback, log, and AnswerPacket refs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSandboxProofRefs {
    pub dependency_envelope_ref: String,
    pub provenance_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub native_link_block_ref: String,
    pub benchmark_caveat_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:set
// Plane: State + Assembly + Controller + Verification
// Residency: complete metadata-only sandbox layout witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterSandboxLayoutProbeSet {
    pub set_address: UasAddress,
    pub upstream_dependency_envelope_address: UasAddress,
    pub upstream_dependency_envelope_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecSandboxLayoutStatus,
    pub promotion_tier: TurboVecSandboxLayoutTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecSandboxPathPolicy,
    pub slots: Vec<TurboVecSandboxSlot>,
    pub cleanup_ledger: TurboVecSandboxCleanupLedger,
    pub proof_refs: TurboVecSandboxProofRefs,
    pub byte_ledger: TurboVecSandboxByteLedger,
    pub layout_metadata_bytes_read: u64,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:metrics
// Plane: Verification
// Residency: aggregate counters for sandbox-layout axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecSandboxLayoutMetrics {
    pub layout_slot_count: u64,
    pub unique_slot_path_count: u64,
    pub forbidden_root_count: u64,
    pub cleanup_phase_count: u64,
    pub planned_quarantine_bytes: u64,
    pub layout_metadata_bytes_read: u64,
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

impl TurboVecRealAdapterSandboxLayoutProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_dependency_envelope_address: UasAddress,
        mut slots: Vec<TurboVecSandboxSlot>,
        cleanup_ledger: TurboVecSandboxCleanupLedger,
        proof_refs: TurboVecSandboxProofRefs,
        byte_ledger: TurboVecSandboxByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecSandboxLayoutStatus,
        promotion_tier: TurboVecSandboxLayoutTier,
        organs: Vec<TurboVecIndexOrgan>,
        policy: TurboVecSandboxPathPolicy,
        layout_metadata_bytes_read: u64,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecSandboxLayoutError> {
        slots.sort_by(|left, right| left.slot_id.cmp(&right.slot_id));
        validate_set_inputs(
            &upstream_dependency_envelope_address,
            &slots,
            &cleanup_ledger,
            &proof_refs,
            &byte_ledger,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            &policy,
            layout_metadata_bytes_read,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?;
        validate_policy(&policy)?;
        validate_slots(&slots, &policy)?;
        validate_cleanup_ledger(&cleanup_ledger)?;
        validate_proof_refs(&proof_refs)?;
        validate_byte_ledger(&byte_ledger)?;
        let set_address =
            deterministic_set_address(&slots, &policy, &cleanup_ledger, layout_metadata_bytes_read);
        Ok(Self {
            set_address,
            upstream_dependency_envelope_address,
            upstream_dependency_envelope_witness_ref: DEPENDENCY_ENVELOPE_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            policy,
            slots,
            cleanup_ledger,
            proof_refs,
            byte_ledger,
            layout_metadata_bytes_read,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        })
    }

    pub fn metrics(&self) -> TurboVecSandboxLayoutMetrics {
        let mut slot_paths = HashSet::new();
        for slot in &self.slots {
            slot_paths.insert(slot.relative_path.clone());
        }
        TurboVecSandboxLayoutMetrics {
            layout_slot_count: self.slots.len() as u64,
            unique_slot_path_count: slot_paths.len() as u64,
            forbidden_root_count: self.policy.forbidden_product_roots.len() as u64,
            cleanup_phase_count: self.cleanup_ledger.phases.len() as u64,
            planned_quarantine_bytes: self.byte_ledger.planned_quarantine_bytes,
            layout_metadata_bytes_read: self.byte_ledger.layout_metadata_bytes_read,
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
            route_mutation_count: u64::from(self.route_mutation_allowed),
            model_context_injection_count: u64::from(self.model_context_injected),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
        }
    }
}

// UAS: uas:turbovec-real-adapter-sandbox-layout:error
// Plane: Verification
// Residency: validation failures for unsafe quarantine layouts.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecSandboxLayoutError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecSandboxLayoutStatus),
    BadPromotionTier(TurboVecSandboxLayoutTier),
    MetadataBudgetExceeded(u64),
    InvalidOrgans,
    InvalidPolicy(String),
    ProductPromotionAllowed,
    ForbiddenAuthority(String),
    MissingSlot(TurboVecSandboxSlotKind),
    BadSlot(String),
    DuplicateSlot(String),
    TooFewSlots(usize),
    BadCleanup(String),
    MissingField(&'static str),
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    ExternalBytesTouched(String),
}

impl fmt::Display for TurboVecSandboxLayoutError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "upstream dependency-envelope cursor mismatch"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad sandbox-layout status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad sandbox-layout tier: {tier:?}"),
            Self::MetadataBudgetExceeded(bytes) => {
                write!(f, "metadata budget exceeded: {bytes}")
            }
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidPolicy(reason) => write!(f, "invalid sandbox-layout policy: {reason}"),
            Self::ProductPromotionAllowed => write!(f, "product promotion attempted"),
            Self::ForbiddenAuthority(reason) => write!(f, "forbidden authority: {reason}"),
            Self::MissingSlot(kind) => write!(f, "missing sandbox slot: {kind:?}"),
            Self::BadSlot(reason) => write!(f, "bad sandbox slot: {reason}"),
            Self::DuplicateSlot(id) => write!(f, "duplicate sandbox slot: {id}"),
            Self::TooFewSlots(count) => write!(f, "too few sandbox slots: {count}"),
            Self::BadCleanup(reason) => write!(f, "bad cleanup ledger: {reason}"),
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

impl std::error::Error for TurboVecSandboxLayoutError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_dependency_envelope_address: &UasAddress,
    slots: &[TurboVecSandboxSlot],
    cleanup_ledger: &TurboVecSandboxCleanupLedger,
    proof_refs: &TurboVecSandboxProofRefs,
    byte_ledger: &TurboVecSandboxByteLedger,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecSandboxLayoutStatus,
    promotion_tier: &TurboVecSandboxLayoutTier,
    organs: &[TurboVecIndexOrgan],
    policy: &TurboVecSandboxPathPolicy,
    layout_metadata_bytes_read: u64,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<(), TurboVecSandboxLayoutError> {
    if !upstream_dependency_envelope_address
        .to_string()
        .starts_with(DEPENDENCY_ENVELOPE_PREFIX)
    {
        return Err(TurboVecSandboxLayoutError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecSandboxLayoutError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecSandboxLayoutError::BadProStatus(pro_status.clone()));
    }
    if status != &TurboVecSandboxLayoutStatus::MetadataOnly {
        return Err(TurboVecSandboxLayoutError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecSandboxLayoutTier::T1L1Metadata {
        return Err(TurboVecSandboxLayoutError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    if layout_metadata_bytes_read > MAX_LAYOUT_METADATA_BYTES {
        return Err(TurboVecSandboxLayoutError::MetadataBudgetExceeded(
            layout_metadata_bytes_read,
        ));
    }
    if slots.len() < MIN_LAYOUT_SLOTS {
        return Err(TurboVecSandboxLayoutError::TooFewSlots(slots.len()));
    }
    if cleanup_ledger.phases.len() < MIN_CLEANUP_PHASES {
        return Err(TurboVecSandboxLayoutError::BadCleanup(
            "cleanup phase floor not met".to_string(),
        ));
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(TurboVecSandboxLayoutError::MissingField("visible_summary"));
    }
    if byte_ledger.layout_metadata_bytes_read != layout_metadata_bytes_read {
        return Err(TurboVecSandboxLayoutError::ExternalBytesTouched(
            "layout metadata ledger mismatch".to_string(),
        ));
    }
    if product_capability_promoted {
        return Err(TurboVecSandboxLayoutError::ProductPromotionAllowed);
    }
    if route_mutation_allowed
        || model_context_injected
        || hidden_route_authority
        || hidden_cloud_fallback_allowed
        || live_large_model_claimed
        || ssd_as_ram_claimed
    {
        return Err(TurboVecSandboxLayoutError::ForbiddenAuthority(
            "route/context/hidden/cloud/large-model claim attempted".to_string(),
        ));
    }
    validate_organs(organs)?;
    validate_policy(policy)?;
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecSandboxLayoutError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let seen: HashSet<_> = organs.iter().copied().collect();
    if seen.len() != organs.len() || required.iter().any(|organ| !seen.contains(organ)) {
        return Err(TurboVecSandboxLayoutError::InvalidOrgans);
    }
    Ok(())
}

fn validate_policy(policy: &TurboVecSandboxPathPolicy) -> Result<(), TurboVecSandboxLayoutError> {
    if !policy
        .quarantine_root_ref
        .starts_with(QUARANTINE_ROOT_PREFIX)
    {
        return Err(TurboVecSandboxLayoutError::BadPrefix {
            field: "quarantine_root_ref",
            value: policy.quarantine_root_ref.clone(),
            expected: QUARANTINE_ROOT_PREFIX,
        });
    }
    if !valid_relative_path(&policy.quarantine_root) {
        return Err(TurboVecSandboxLayoutError::InvalidPolicy(
            "quarantine root must be a normalized relative path".to_string(),
        ));
    }
    for required_root in [
        "agent_core",
        "Epistemos",
        "graph-engine",
        "Tools",
        "docs",
        "artifacts/falsifiers",
        "benchmarks/results",
    ] {
        if !policy
            .forbidden_product_roots
            .iter()
            .any(|root| root == required_root)
        {
            return Err(TurboVecSandboxLayoutError::InvalidPolicy(format!(
                "missing forbidden root {required_root}"
            )));
        }
    }
    let flags = [
        policy.reject_absolute_paths,
        policy.reject_traversal,
        policy.reject_symlink_slots,
        policy.reject_executable_slots,
        policy.reject_product_writable_slots,
        policy.deny_build_graph_membership,
        policy.deny_runtime_route_membership,
        policy.require_cleanup_ledger,
        policy.require_answer_packet,
    ];
    if flags.iter().any(|flag| !flag) {
        return Err(TurboVecSandboxLayoutError::InvalidPolicy(
            "all fail-closed policy flags must be true".to_string(),
        ));
    }
    Ok(())
}

fn validate_slots(
    slots: &[TurboVecSandboxSlot],
    policy: &TurboVecSandboxPathPolicy,
) -> Result<(), TurboVecSandboxLayoutError> {
    let mut ids = HashSet::new();
    let mut paths = HashSet::new();
    for required in [
        TurboVecSandboxSlotKind::SourceTreeSnapshot,
        TurboVecSandboxSlotKind::ForkSweepSnapshot,
        TurboVecSandboxSlotKind::ManifestSnapshot,
        TurboVecSandboxSlotKind::ExtractedApiNotes,
        TurboVecSandboxSlotKind::ExtractedTestSpecs,
        TurboVecSandboxSlotKind::BenchmarkTranscripts,
        TurboVecSandboxSlotKind::FailureReports,
        TurboVecSandboxSlotKind::CleanRoomRewriteNotes,
        TurboVecSandboxSlotKind::NativeLinkNotes,
        TurboVecSandboxSlotKind::CleanupTombstones,
    ] {
        if !slots.iter().any(|slot| slot.kind == required) {
            return Err(TurboVecSandboxLayoutError::MissingSlot(required));
        }
    }
    for slot in slots {
        if slot.slot_id.trim().is_empty() {
            return Err(TurboVecSandboxLayoutError::MissingField("slot_id"));
        }
        if !ids.insert(slot.slot_id.clone()) {
            return Err(TurboVecSandboxLayoutError::DuplicateSlot(
                slot.slot_id.clone(),
            ));
        }
        if !paths.insert(slot.relative_path.clone()) {
            return Err(TurboVecSandboxLayoutError::DuplicateSlot(
                slot.relative_path.clone(),
            ));
        }
        validate_slot_path(slot, policy)?;
        if !slot.slot_ref.starts_with(SLOT_REF_PREFIX) {
            return Err(TurboVecSandboxLayoutError::BadPrefix {
                field: "slot_ref",
                value: slot.slot_ref.clone(),
                expected: SLOT_REF_PREFIX,
            });
        }
        if slot.purpose_ref.trim().is_empty() {
            return Err(TurboVecSandboxLayoutError::MissingField("purpose_ref"));
        }
        if !slot.read_only
            || slot.symlink_allowed
            || slot.executable_allowed
            || slot.writes_product_path
            || slot.build_graph_member
            || slot.runtime_route_member
            || slot.allowed_action != TurboVecSandboxLayoutAction::MetadataOnly
        {
            return Err(TurboVecSandboxLayoutError::BadSlot(format!(
                "slot {} attempted writable, executable, product, build, route, or nonmetadata action",
                slot.slot_id
            )));
        }
    }
    Ok(())
}

fn validate_slot_path(
    slot: &TurboVecSandboxSlot,
    policy: &TurboVecSandboxPathPolicy,
) -> Result<(), TurboVecSandboxLayoutError> {
    if !valid_relative_path(&slot.relative_path) {
        return Err(TurboVecSandboxLayoutError::BadSlot(format!(
            "slot {} path is not normalized relative path",
            slot.slot_id
        )));
    }
    if !slot.relative_path.starts_with(&policy.quarantine_root)
        || slot.relative_path == policy.quarantine_root
    {
        return Err(TurboVecSandboxLayoutError::BadSlot(format!(
            "slot {} is outside quarantine root",
            slot.slot_id
        )));
    }
    for forbidden_root in &policy.forbidden_product_roots {
        if path_has_root(&slot.relative_path, forbidden_root) {
            return Err(TurboVecSandboxLayoutError::BadSlot(format!(
                "slot {} touches forbidden root {}",
                slot.slot_id, forbidden_root
            )));
        }
    }
    Ok(())
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

fn validate_cleanup_ledger(
    cleanup_ledger: &TurboVecSandboxCleanupLedger,
) -> Result<(), TurboVecSandboxLayoutError> {
    let required = [
        TurboVecSandboxCleanupPhase::PreflightSnapshot,
        TurboVecSandboxCleanupPhase::FetchLeaseExpiry,
        TurboVecSandboxCleanupPhase::BuildOutputScrub,
        TurboVecSandboxCleanupPhase::ProductGraphAudit,
        TurboVecSandboxCleanupPhase::TombstoneCommit,
    ];
    let seen: HashSet<_> = cleanup_ledger.phases.iter().copied().collect();
    if seen.len() != cleanup_ledger.phases.len() || required.iter().any(|r| !seen.contains(r)) {
        return Err(TurboVecSandboxLayoutError::BadCleanup(
            "cleanup phases missing or duplicated".to_string(),
        ));
    }
    for (field, value, expected) in [
        (
            "cleanup_ref",
            &cleanup_ledger.cleanup_ref,
            CLEANUP_REF_PREFIX,
        ),
        (
            "tombstone_ref",
            &cleanup_ledger.tombstone_ref,
            CLEANUP_REF_PREFIX,
        ),
        (
            "rollback_ref",
            &cleanup_ledger.rollback_ref,
            ROLLBACK_REF_PREFIX,
        ),
    ] {
        if !value.starts_with(expected) {
            return Err(TurboVecSandboxLayoutError::BadPrefix {
                field,
                value: value.clone(),
                expected,
            });
        }
    }
    Ok(())
}

fn validate_proof_refs(
    proof_refs: &TurboVecSandboxProofRefs,
) -> Result<(), TurboVecSandboxLayoutError> {
    for (field, value, expected) in [
        (
            "dependency_envelope_ref",
            &proof_refs.dependency_envelope_ref,
            DEPENDENCY_ENVELOPE_WITNESS_REF,
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
        if field == "dependency_envelope_ref" {
            if value != expected {
                return Err(TurboVecSandboxLayoutError::BadPrefix {
                    field,
                    value: value.clone(),
                    expected,
                });
            }
        } else if !value.starts_with(expected) {
            return Err(TurboVecSandboxLayoutError::BadPrefix {
                field,
                value: value.clone(),
                expected,
            });
        }
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(TurboVecSandboxLayoutError::MissingField("visible_summary"));
    }
    Ok(())
}

fn validate_byte_ledger(
    byte_ledger: &TurboVecSandboxByteLedger,
) -> Result<(), TurboVecSandboxLayoutError> {
    if byte_ledger.layout_metadata_bytes_read > MAX_LAYOUT_METADATA_BYTES {
        return Err(TurboVecSandboxLayoutError::MetadataBudgetExceeded(
            byte_ledger.layout_metadata_bytes_read,
        ));
    }
    for (name, value) in [
        ("fetched_repo_bytes", byte_ledger.fetched_repo_bytes),
        ("cloned_repo_bytes", byte_ledger.cloned_repo_bytes),
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
            return Err(TurboVecSandboxLayoutError::ExternalBytesTouched(
                name.to_string(),
            ));
        }
    }
    Ok(())
}

fn deterministic_set_address(
    slots: &[TurboVecSandboxSlot],
    policy: &TurboVecSandboxPathPolicy,
    cleanup_ledger: &TurboVecSandboxCleanupLedger,
    layout_metadata_bytes_read: u64,
) -> UasAddress {
    let mut parts = Vec::with_capacity(slots.len() + cleanup_ledger.phases.len() + 4);
    parts.push(policy.quarantine_root.clone());
    parts.push(policy.quarantine_root_ref.clone());
    for slot in slots {
        parts.push(format!(
            "{}|{:?}|{}|{}",
            slot.slot_id, slot.kind, slot.relative_path, slot.slot_ref
        ));
    }
    for phase in &cleanup_ledger.phases {
        parts.push(format!("cleanup:{phase:?}"));
    }
    parts.push(cleanup_ledger.cleanup_ref.clone());
    parts.push(cleanup_ledger.tombstone_ref.clone());
    parts.push(format!("metadata_bytes:{layout_metadata_bytes_read}"));
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_sandbox_layout_probe".to_string()),
        parts.join("\n").as_bytes(),
        1_779_040_900_000,
    )
}

pub fn sandbox_layout_digest(set: &TurboVecRealAdapterSandboxLayoutProbeSet) -> String {
    let mut lines = Vec::with_capacity(set.slots.len() + 8);
    lines.push(set.set_address.to_string());
    lines.push(set.policy.quarantine_root.clone());
    for slot in &set.slots {
        lines.push(format!(
            "{}:{}:{}",
            slot.slot_id, slot.relative_path, slot.slot_ref
        ));
    }
    sha256_hex(lines.join("\n").as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::str::FromStr;

    const UPSTREAM: &str = "turbovec_real_adapter_dependency_envelope_probe:f59dcce8a5c6691d3cf9c132f99e80c44a42b85c784d9b49745d1d435d26d2f5@1779040900000";

    fn upstream() -> UasAddress {
        UasAddress::from_str(UPSTREAM).expect("valid upstream test address")
    }

    fn organs() -> Vec<TurboVecIndexOrgan> {
        vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ]
    }

    fn policy() -> TurboVecSandboxPathPolicy {
        TurboVecSandboxPathPolicy::fail_closed(
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2",
        )
    }

    fn slot(slot_id: &str, kind: TurboVecSandboxSlotKind, leaf: &str) -> TurboVecSandboxSlot {
        let root = policy().quarantine_root;
        TurboVecSandboxSlot {
            slot_id: slot_id.to_string(),
            kind,
            relative_path: format!("{root}/{leaf}"),
            slot_ref: format!("{SLOT_REF_PREFIX}{slot_id}"),
            purpose_ref: format!("purpose:turbovec-sandbox:{slot_id}"),
            read_only: true,
            symlink_allowed: false,
            executable_allowed: false,
            writes_product_path: false,
            build_graph_member: false,
            runtime_route_member: false,
            allowed_action: TurboVecSandboxLayoutAction::MetadataOnly,
        }
    }

    fn slots() -> Vec<TurboVecSandboxSlot> {
        vec![
            slot(
                "source_tree_snapshot",
                TurboVecSandboxSlotKind::SourceTreeSnapshot,
                "source-tree",
            ),
            slot(
                "fork_sweep_snapshot",
                TurboVecSandboxSlotKind::ForkSweepSnapshot,
                "fork-sweep",
            ),
            slot(
                "manifest_snapshot",
                TurboVecSandboxSlotKind::ManifestSnapshot,
                "manifest-snapshot",
            ),
            slot(
                "extracted_api_notes",
                TurboVecSandboxSlotKind::ExtractedApiNotes,
                "extracted-api-notes",
            ),
            slot(
                "extracted_test_specs",
                TurboVecSandboxSlotKind::ExtractedTestSpecs,
                "extracted-test-specs",
            ),
            slot(
                "benchmark_transcripts",
                TurboVecSandboxSlotKind::BenchmarkTranscripts,
                "benchmark-transcripts",
            ),
            slot(
                "failure_reports",
                TurboVecSandboxSlotKind::FailureReports,
                "failure-reports",
            ),
            slot(
                "clean_room_rewrite_notes",
                TurboVecSandboxSlotKind::CleanRoomRewriteNotes,
                "clean-room-rewrite-notes",
            ),
            slot(
                "native_link_notes",
                TurboVecSandboxSlotKind::NativeLinkNotes,
                "native-link-notes",
            ),
            slot(
                "cleanup_tombstones",
                TurboVecSandboxSlotKind::CleanupTombstones,
                "cleanup-tombstones",
            ),
        ]
    }

    fn cleanup() -> TurboVecSandboxCleanupLedger {
        TurboVecSandboxCleanupLedger {
            phases: vec![
                TurboVecSandboxCleanupPhase::PreflightSnapshot,
                TurboVecSandboxCleanupPhase::FetchLeaseExpiry,
                TurboVecSandboxCleanupPhase::BuildOutputScrub,
                TurboVecSandboxCleanupPhase::ProductGraphAudit,
                TurboVecSandboxCleanupPhase::TombstoneCommit,
            ],
            cleanup_ref: format!("{CLEANUP_REF_PREFIX}phase-ledger"),
            tombstone_ref: format!("{CLEANUP_REF_PREFIX}tombstone-ledger"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}quarantine-delete"),
        }
    }

    fn proof_refs() -> TurboVecSandboxProofRefs {
        TurboVecSandboxProofRefs {
            dependency_envelope_ref: DEPENDENCY_ENVELOPE_WITNESS_REF.to_string(),
            provenance_ref: format!("{PROVENANCE_REF_PREFIX}source-card-clean-room"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}quarantine-delete"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}layout-dry-run"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}visible-no-runtime-scope"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}mas-pro-excluded"),
            native_link_block_ref: format!("{NATIVE_LINK_REF_PREFIX}blocked-until-fetch-lease"),
            benchmark_caveat_ref: format!("{BENCHMARK_CAVEAT_PREFIX}no-quality-or-speed-claim"),
            visible_summary: "TurboVec adapter research may be studied in quarantine for APIs, tests, benchmarks, dependencies, failure cases, and clean-room motifs, but this layout proof contains no fetched repository bytes, no product source, no dependency insertion, no native link probe, no index/model/runtime/provider bytes, no route authority, and no L2 or L3 promotion.".to_string(),
        }
    }

    fn byte_ledger() -> TurboVecSandboxByteLedger {
        TurboVecSandboxByteLedger::metadata_only(96_000, 8 * 1024 * 1024)
    }

    fn set_with(
        slots: Vec<TurboVecSandboxSlot>,
    ) -> Result<TurboVecRealAdapterSandboxLayoutProbeSet, TurboVecSandboxLayoutError> {
        TurboVecRealAdapterSandboxLayoutProbeSet::from_parts(
            upstream(),
            slots,
            cleanup(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSandboxLayoutStatus::MetadataOnly,
            TurboVecSandboxLayoutTier::T1L1Metadata,
            organs(),
            policy(),
            96_000,
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
    fn accepts_metadata_only_sandbox_layout() {
        let set = set_with(slots()).expect("accepted sandbox layout");
        let metrics = set.metrics();
        assert_eq!(metrics.layout_slot_count, 10);
        assert_eq!(metrics.planned_quarantine_bytes, 8 * 1024 * 1024);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(sandbox_layout_digest(&set).starts_with("sha256:"));
    }

    #[test]
    fn address_is_deterministic_when_slots_are_reordered() {
        let accepted = set_with(slots()).expect("accepted sandbox layout");
        let mut reversed = slots();
        reversed.reverse();
        let reordered = set_with(reversed).expect("reordered sandbox layout");
        assert_eq!(accepted.set_address, reordered.set_address);
    }

    #[test]
    fn rejects_product_roots_and_path_traversal() {
        let mut product_path = slots();
        product_path[0].relative_path = "agent_core/src/uas/turbovec.rs".to_string();
        assert!(set_with(product_path).is_err());

        let mut traversal = slots();
        traversal[0].relative_path =
            ".epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/../agent_core"
                .to_string();
        assert!(set_with(traversal).is_err());
    }

    #[test]
    fn rejects_duplicate_or_mutating_slots() {
        let mut duplicate = slots();
        duplicate[1].slot_id = duplicate[0].slot_id.clone();
        assert!(set_with(duplicate).is_err());

        let mut executable = slots();
        executable[0].executable_allowed = true;
        assert!(set_with(executable).is_err());

        let mut action = slots();
        action[0].allowed_action = TurboVecSandboxLayoutAction::BuildAdapter;
        assert!(set_with(action).is_err());
    }

    #[test]
    fn rejects_bytes_and_claim_promotion() {
        let mut ledger = byte_ledger();
        ledger.model_bytes_loaded = 1;
        let rejected = TurboVecRealAdapterSandboxLayoutProbeSet::from_parts(
            upstream(),
            slots(),
            cleanup(),
            proof_refs(),
            ledger,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSandboxLayoutStatus::MetadataOnly,
            TurboVecSandboxLayoutTier::T1L1Metadata,
            organs(),
            policy(),
            96_000,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(rejected.is_err());

        let promoted = TurboVecRealAdapterSandboxLayoutProbeSet::from_parts(
            upstream(),
            slots(),
            cleanup(),
            proof_refs(),
            byte_ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSandboxLayoutStatus::MetadataOnly,
            TurboVecSandboxLayoutTier::T1L1Metadata,
            organs(),
            policy(),
            96_000,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(promoted.is_err());
    }
}
