//! TurboVec real-adapter source-inspection policy probe.
//!
//! This primitive makes the next TurboVec research step explicit: source
//! inspection may only happen through manifest-bound quarantine policy, with
//! paraphrased API/test/behavior motifs and clean-room notes. It is still
//! metadata-only: it does not read raw source content, clone the repo, import
//! code, build adapters, probe native links, open indexes, load models, or
//! grant route authority.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecSourceManifestDisposition, UasAddress,
    UasKind,
};

pub const TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_CURSOR: &str =
    "turbovec_quarantine_real_adapter_source_inspection_policy_probe";
pub const TURBOVEC_REAL_ADAPTER_SOURCE_INSPECTION_POLICY_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_motif_extraction_card_probe";

const SOURCE_BYTE_MANIFEST_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_source_byte_manifest_probe:result";
const SOURCE_BYTE_MANIFEST_PREFIX: &str = "turbovec_real_adapter_source_byte_manifest_probe:";
const POLICY_REF_PREFIX: &str = "source_inspection_policy:turbovec:";
const PROVENANCE_REF_PREFIX: &str = "provenance:turbovec-source-inspection:";
const CLEAN_ROOM_REF_PREFIX: &str = "clean_room:turbovec-source-inspection:";
const SOURCE_CARD_REF_PREFIX: &str = "source_card:turbovec-source-inspection:";
const FORK_SWEEP_REF_PREFIX: &str = "fork_sweep:turbovec-source-inspection:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-source-inspection:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-source-inspection:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-source-inspection:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-source-inspection:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-source-inspection:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-source-inspection:";
const BENCHMARK_CAVEAT_REF_PREFIX: &str = "benchmark_caveat:turbovec-source-inspection:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const TREE_API_URL: &str =
    "https://api.github.com/repos/RyanCodrai/turbovec/git/trees/efe29a184986cbf562a9847c2ac52a2990bfaca2?recursive=1";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const EXPECTED_POLICY_ROW_COUNT: usize = 22;
const MIN_FUTURE_READ_ROW_COUNT: u64 = 15;
const MIN_BLOCKED_ROW_COUNT: u64 = 6;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 420;
const MAX_FUTURE_RAW_SOURCE_BYTES_READ: u64 = 196_608;
const CURRENT_POLICY_METADATA_BYTES_READ: u64 = 64 * 1024;

// UAS: uas:turbovec-real-adapter-source-inspection-policy:status
// Plane: Verification
// Residency: metadata-only source-inspection policy status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourceInspectionStatus {
    PolicyOnly,
    SourceContentReadByLaterWitness,
    Blocked,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:tier
// Plane: Verification
// Residency: source-inspection policy promotion boundary.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourceInspectionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:action
// Plane: Controller + Verification
// Residency: permitted future inspection action for a manifest row.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecInspectionAction {
    ReadProvenanceMetadata,
    ReadDocumentationSummary,
    ReadApiShape,
    ReadBehaviorSpec,
    ReadDependencyMetadata,
    ReadTestIntent,
    ReadBenchmarkHarnessMetadata,
    BlockNativeLink,
    BlockBinaryAsset,
    BlockSymlink,
    BlockIntegration,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:output-mode
// Plane: Verification
// Residency: allowed future output shape after quarantine source inspection.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecInspectionOutputMode {
    ProvenanceCard,
    DocumentationSummary,
    ApiSignatureOnly,
    BehaviorSpecOnly,
    DependencyRiskNote,
    FixtureIntentOnly,
    BenchmarkCaveatOnly,
    Blocked,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:row
// Plane: State + Controller + Verification
// Residency: per-manifest-row inspection policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceInspectionPolicyRow {
    pub path: String,
    pub manifest_disposition: TurboVecSourceManifestDisposition,
    pub action: TurboVecInspectionAction,
    pub output_mode: TurboVecInspectionOutputMode,
    pub future_source_read_allowed_by_later_witness: bool,
    pub verbatim_code_allowed: bool,
    pub product_copy_allowed: bool,
    pub product_import_allowed: bool,
    pub product_dependency_allowed: bool,
    pub native_link_probe_allowed: bool,
    pub benchmark_authority_allowed: bool,
    pub route_authority_allowed: bool,
    pub clean_room_note_required: bool,
    pub answer_packet_caveat_required: bool,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:policy
// Plane: Controller + Verification
// Residency: fail-closed inspection policy before source reading.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceInspectionPolicy {
    pub manifest_bound: bool,
    pub source_bytes_read_now: bool,
    pub raw_content_read_now: bool,
    pub future_source_read_requires_owner_approval: bool,
    pub future_source_read_requires_quarantine: bool,
    pub future_source_read_requires_manifest_row: bool,
    pub verbatim_code_forbidden: bool,
    pub paraphrase_or_behavior_spec_only: bool,
    pub product_import_allowed: bool,
    pub product_dependency_allowed: bool,
    pub native_link_probe_allowed: bool,
    pub benchmark_authority_allowed: bool,
    pub runtime_execution_allowed: bool,
    pub route_authority_allowed: bool,
    pub clean_room_notes_required: bool,
    pub source_cards_required: bool,
    pub rollback_required: bool,
    pub answer_packet_required: bool,
    pub blocked_rows_remain_unread: bool,
}

impl TurboVecSourceInspectionPolicy {
    pub fn fail_closed() -> Self {
        Self {
            manifest_bound: true,
            source_bytes_read_now: false,
            raw_content_read_now: false,
            future_source_read_requires_owner_approval: true,
            future_source_read_requires_quarantine: true,
            future_source_read_requires_manifest_row: true,
            verbatim_code_forbidden: true,
            paraphrase_or_behavior_spec_only: true,
            product_import_allowed: false,
            product_dependency_allowed: false,
            native_link_probe_allowed: false,
            benchmark_authority_allowed: false,
            runtime_execution_allowed: false,
            route_authority_allowed: false,
            clean_room_notes_required: true,
            source_cards_required: true,
            rollback_required: true,
            answer_packet_required: true,
            blocked_rows_remain_unread: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:byte-ledger
// Plane: Verification
// Residency: zero-current-byte and future-inspection byte ceilings.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceInspectionByteLedger {
    pub policy_metadata_bytes_read: u64,
    pub max_future_raw_source_bytes_read: u64,
    pub current_raw_source_bytes_read: u64,
    pub source_archive_bytes_fetched: u64,
    pub quarantine_source_bytes_written: u64,
    pub product_files_copied: u64,
    pub product_dependencies_added: u64,
    pub native_link_probe_count: u64,
    pub adapter_build_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl TurboVecSourceInspectionByteLedger {
    pub fn metadata_only() -> Self {
        Self {
            policy_metadata_bytes_read: CURRENT_POLICY_METADATA_BYTES_READ,
            max_future_raw_source_bytes_read: MAX_FUTURE_RAW_SOURCE_BYTES_READ,
            current_raw_source_bytes_read: 0,
            source_archive_bytes_fetched: 0,
            quarantine_source_bytes_written: 0,
            product_files_copied: 0,
            product_dependencies_added: 0,
            native_link_probe_count: 0,
            adapter_build_count: 0,
            index_bytes_opened: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:proof-refs
// Plane: Verification
// Residency: proof surfaces for quarantine source inspection.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourceInspectionProofRefs {
    pub source_byte_manifest_ref: String,
    pub provenance_ref: String,
    pub clean_room_ref: String,
    pub source_card_ref: String,
    pub fork_sweep_ref: String,
    pub no_product_graph_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub native_link_block_ref: String,
    pub benchmark_caveat_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:set
// Plane: State + Assembly + Controller + Verification
// Residency: complete source-inspection policy witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterSourceInspectionPolicyProbeSet {
    pub set_address: UasAddress,
    pub upstream_source_byte_manifest_address: UasAddress,
    pub upstream_source_byte_manifest_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecSourceInspectionStatus,
    pub promotion_tier: TurboVecSourceInspectionTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub source_url: String,
    pub tree_api_url: String,
    pub pinned_revision: String,
    pub policy_rows: Vec<TurboVecSourceInspectionPolicyRow>,
    pub policy: TurboVecSourceInspectionPolicy,
    pub proof_refs: TurboVecSourceInspectionProofRefs,
    pub byte_ledger: TurboVecSourceInspectionByteLedger,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:metrics
// Plane: Verification
// Residency: aggregate inspection-policy counters.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecSourceInspectionMetrics {
    pub policy_row_count: u64,
    pub future_read_row_count: u64,
    pub blocked_row_count: u64,
    pub rust_core_row_count: u64,
    pub test_intent_row_count: u64,
    pub benchmark_metadata_row_count: u64,
    pub native_link_blocked_row_count: u64,
    pub symlink_blocked_row_count: u64,
    pub binary_blocked_row_count: u64,
    pub integration_blocked_row_count: u64,
    pub clean_room_note_count: u64,
    pub policy_metadata_bytes_read: u64,
    pub current_raw_source_bytes_read: u64,
    pub max_future_raw_source_bytes_read: u64,
    pub source_archive_bytes_fetched: u64,
    pub quarantine_source_bytes_written: u64,
    pub product_files_copied: u64,
    pub product_dependencies_added: u64,
    pub native_link_probe_count: u64,
    pub adapter_build_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
}

impl TurboVecRealAdapterSourceInspectionPolicyProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_source_byte_manifest_address: UasAddress,
        mut policy_rows: Vec<TurboVecSourceInspectionPolicyRow>,
        policy: TurboVecSourceInspectionPolicy,
        proof_refs: TurboVecSourceInspectionProofRefs,
        byte_ledger: TurboVecSourceInspectionByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecSourceInspectionStatus,
        promotion_tier: TurboVecSourceInspectionTier,
        organs: Vec<TurboVecIndexOrgan>,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecSourceInspectionError> {
        policy_rows.sort_by(|left, right| left.path.cmp(&right.path));
        validate_set_inputs(
            &upstream_source_byte_manifest_address,
            &policy_rows,
            &policy,
            &proof_refs,
            &byte_ledger,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?;
        let set_address = deterministic_set_address(&policy_rows);
        Ok(Self {
            set_address,
            upstream_source_byte_manifest_address,
            upstream_source_byte_manifest_witness_ref: SOURCE_BYTE_MANIFEST_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            source_url: SOURCE_URL.to_string(),
            tree_api_url: TREE_API_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            policy_rows,
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

    pub fn metrics(&self) -> TurboVecSourceInspectionMetrics {
        TurboVecSourceInspectionMetrics {
            policy_row_count: self.policy_rows.len() as u64,
            future_read_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.future_source_read_allowed_by_later_witness)
                .count() as u64,
            blocked_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.is_blocked())
                .count() as u64,
            rust_core_row_count: self
                .policy_rows
                .iter()
                .filter(|row| {
                    row.manifest_disposition == TurboVecSourceManifestDisposition::RustCoreCandidate
                })
                .count() as u64,
            test_intent_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.action == TurboVecInspectionAction::ReadTestIntent)
                .count() as u64,
            benchmark_metadata_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.action == TurboVecInspectionAction::ReadBenchmarkHarnessMetadata)
                .count() as u64,
            native_link_blocked_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.action == TurboVecInspectionAction::BlockNativeLink)
                .count() as u64,
            symlink_blocked_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.action == TurboVecInspectionAction::BlockSymlink)
                .count() as u64,
            binary_blocked_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.action == TurboVecInspectionAction::BlockBinaryAsset)
                .count() as u64,
            integration_blocked_row_count: self
                .policy_rows
                .iter()
                .filter(|row| row.action == TurboVecInspectionAction::BlockIntegration)
                .count() as u64,
            clean_room_note_count: self
                .policy_rows
                .iter()
                .filter(|row| row.clean_room_note_required)
                .count() as u64,
            policy_metadata_bytes_read: self.byte_ledger.policy_metadata_bytes_read,
            current_raw_source_bytes_read: self.byte_ledger.current_raw_source_bytes_read,
            max_future_raw_source_bytes_read: self.byte_ledger.max_future_raw_source_bytes_read,
            source_archive_bytes_fetched: self.byte_ledger.source_archive_bytes_fetched,
            quarantine_source_bytes_written: self.byte_ledger.quarantine_source_bytes_written,
            product_files_copied: self.byte_ledger.product_files_copied,
            product_dependencies_added: self.byte_ledger.product_dependencies_added,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            adapter_build_count: self.byte_ledger.adapter_build_count,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
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

impl TurboVecSourceInspectionPolicyRow {
    pub fn is_blocked(&self) -> bool {
        matches!(
            self.action,
            TurboVecInspectionAction::BlockNativeLink
                | TurboVecInspectionAction::BlockBinaryAsset
                | TurboVecInspectionAction::BlockSymlink
                | TurboVecInspectionAction::BlockIntegration
        )
    }
}

// UAS: uas:turbovec-real-adapter-source-inspection-policy:error
// Plane: Verification
// Residency: validation failures for unsafe inspection-policy states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecSourceInspectionError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecSourceInspectionStatus),
    BadPromotionTier(TurboVecSourceInspectionTier),
    InvalidOrgans,
    InvalidPolicyRow(String),
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

impl fmt::Display for TurboVecSourceInspectionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "upstream source-byte manifest cursor mismatch"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad inspection status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad inspection tier: {tier:?}"),
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidPolicyRow(reason) => write!(f, "invalid policy row: {reason}"),
            Self::InvalidPolicy(reason) => write!(f, "invalid policy: {reason}"),
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

impl std::error::Error for TurboVecSourceInspectionError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_source_byte_manifest_address: &UasAddress,
    policy_rows: &[TurboVecSourceInspectionPolicyRow],
    policy: &TurboVecSourceInspectionPolicy,
    proof_refs: &TurboVecSourceInspectionProofRefs,
    byte_ledger: &TurboVecSourceInspectionByteLedger,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecSourceInspectionStatus,
    promotion_tier: &TurboVecSourceInspectionTier,
    organs: &[TurboVecIndexOrgan],
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<(), TurboVecSourceInspectionError> {
    if !upstream_source_byte_manifest_address
        .to_string()
        .starts_with(SOURCE_BYTE_MANIFEST_PREFIX)
    {
        return Err(TurboVecSourceInspectionError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecSourceInspectionError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecSourceInspectionError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if status != &TurboVecSourceInspectionStatus::PolicyOnly {
        return Err(TurboVecSourceInspectionError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecSourceInspectionTier::T1L1Metadata {
        return Err(TurboVecSourceInspectionError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    if product_capability_promoted {
        return Err(TurboVecSourceInspectionError::ProductPromotionAllowed);
    }
    if route_mutation_allowed
        || model_context_injected
        || hidden_route_authority
        || hidden_cloud_fallback_allowed
        || live_large_model_claimed
        || ssd_as_ram_claimed
    {
        return Err(TurboVecSourceInspectionError::ForbiddenAuthority(
            "route/context/hidden/cloud/large-model claim attempted".to_string(),
        ));
    }
    validate_organs(organs)?;
    validate_rows(policy_rows)?;
    validate_policy(policy)?;
    validate_proof_refs(proof_refs)?;
    validate_byte_ledger(byte_ledger)?;
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecSourceInspectionError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let seen: HashSet<_> = organs.iter().copied().collect();
    if seen.len() != organs.len() || required.iter().any(|organ| !seen.contains(organ)) {
        return Err(TurboVecSourceInspectionError::InvalidOrgans);
    }
    Ok(())
}

fn validate_rows(
    rows: &[TurboVecSourceInspectionPolicyRow],
) -> Result<(), TurboVecSourceInspectionError> {
    if rows.len() != EXPECTED_POLICY_ROW_COUNT {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(
            "unexpected policy row count".to_string(),
        ));
    }
    let mut paths = BTreeSet::new();
    for row in rows {
        validate_row(row)?;
        if !paths.insert(row.path.clone()) {
            return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
                "duplicate row path {}",
                row.path
            )));
        }
    }
    for required in required_policy_paths() {
        if !paths.contains(*required) {
            return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
                "missing required path {required}"
            )));
        }
    }
    let future_read_count = rows
        .iter()
        .filter(|row| row.future_source_read_allowed_by_later_witness)
        .count() as u64;
    let blocked_count = rows.iter().filter(|row| row.is_blocked()).count() as u64;
    if future_read_count < MIN_FUTURE_READ_ROW_COUNT || blocked_count < MIN_BLOCKED_ROW_COUNT {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(
            "future-read or blocked-row coverage below floor".to_string(),
        ));
    }
    Ok(())
}

fn validate_row(
    row: &TurboVecSourceInspectionPolicyRow,
) -> Result<(), TurboVecSourceInspectionError> {
    validate_path(&row.path)?;
    if row.verbatim_code_allowed
        || row.product_copy_allowed
        || row.product_import_allowed
        || row.product_dependency_allowed
        || row.native_link_probe_allowed
        || row.benchmark_authority_allowed
        || row.route_authority_allowed
    {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
            "forbidden authority flag on {}",
            row.path
        )));
    }
    if !row.answer_packet_caveat_required {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
            "missing AnswerPacket caveat on {}",
            row.path
        )));
    }
    if row.is_blocked() {
        if row.future_source_read_allowed_by_later_witness
            || row.clean_room_note_required
            || row.output_mode != TurboVecInspectionOutputMode::Blocked
        {
            return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
                "blocked row {} allows read or output",
                row.path
            )));
        }
    } else if !row.future_source_read_allowed_by_later_witness || !row.clean_room_note_required {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
            "inspectable row {} lacks future-read or clean-room requirement",
            row.path
        )));
    }

    let expected_output = expected_output_mode(row.action);
    if row.output_mode != expected_output {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
            "bad output mode for {}",
            row.path
        )));
    }
    if !action_matches_disposition(row.action, row.manifest_disposition) {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
            "action/disposition mismatch for {}",
            row.path
        )));
    }
    Ok(())
}

fn validate_path(path: &str) -> Result<(), TurboVecSourceInspectionError> {
    if path.is_empty()
        || path == "."
        || path.starts_with('/')
        || path.contains("..")
        || path.contains('\\')
        || path.contains("//")
    {
        return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
            "unsafe path {path}"
        )));
    }
    for forbidden in [
        "agent_core/",
        "Epistemos/",
        "graph-engine/",
        "Tools/",
        "artifacts/",
        "target/",
    ] {
        if path.starts_with(forbidden) {
            return Err(TurboVecSourceInspectionError::InvalidPolicyRow(format!(
                "product path {path}"
            )));
        }
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecSourceInspectionPolicy,
) -> Result<(), TurboVecSourceInspectionError> {
    let invalid = !policy.manifest_bound
        || policy.source_bytes_read_now
        || policy.raw_content_read_now
        || !policy.future_source_read_requires_owner_approval
        || !policy.future_source_read_requires_quarantine
        || !policy.future_source_read_requires_manifest_row
        || !policy.verbatim_code_forbidden
        || !policy.paraphrase_or_behavior_spec_only
        || policy.product_import_allowed
        || policy.product_dependency_allowed
        || policy.native_link_probe_allowed
        || policy.benchmark_authority_allowed
        || policy.runtime_execution_allowed
        || policy.route_authority_allowed
        || !policy.clean_room_notes_required
        || !policy.source_cards_required
        || !policy.rollback_required
        || !policy.answer_packet_required
        || !policy.blocked_rows_remain_unread;
    if invalid {
        return Err(TurboVecSourceInspectionError::InvalidPolicy(
            "source-inspection policy must stay fail-closed".to_string(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    proof_refs: &TurboVecSourceInspectionProofRefs,
) -> Result<(), TurboVecSourceInspectionError> {
    for (field, value, expected) in [
        (
            "source_byte_manifest_ref",
            proof_refs.source_byte_manifest_ref.as_str(),
            SOURCE_BYTE_MANIFEST_WITNESS_REF,
        ),
        (
            "provenance_ref",
            proof_refs.provenance_ref.as_str(),
            PROVENANCE_REF_PREFIX,
        ),
        (
            "clean_room_ref",
            proof_refs.clean_room_ref.as_str(),
            CLEAN_ROOM_REF_PREFIX,
        ),
        (
            "source_card_ref",
            proof_refs.source_card_ref.as_str(),
            SOURCE_CARD_REF_PREFIX,
        ),
        (
            "fork_sweep_ref",
            proof_refs.fork_sweep_ref.as_str(),
            FORK_SWEEP_REF_PREFIX,
        ),
        (
            "no_product_graph_ref",
            proof_refs.no_product_graph_ref.as_str(),
            NO_PRODUCT_GRAPH_REF_PREFIX,
        ),
        (
            "rollback_ref",
            proof_refs.rollback_ref.as_str(),
            ROLLBACK_REF_PREFIX,
        ),
        (
            "run_event_log_ref",
            proof_refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_REF_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof_refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_REF_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof_refs.compatibility_fence_ref.as_str(),
            COMPATIBILITY_REF_PREFIX,
        ),
        (
            "native_link_block_ref",
            proof_refs.native_link_block_ref.as_str(),
            NATIVE_LINK_REF_PREFIX,
        ),
        (
            "benchmark_caveat_ref",
            proof_refs.benchmark_caveat_ref.as_str(),
            BENCHMARK_CAVEAT_REF_PREFIX,
        ),
    ] {
        if field == "source_byte_manifest_ref" {
            if value != expected {
                return Err(TurboVecSourceInspectionError::MissingField(field));
            }
        } else if !value.starts_with(expected) {
            return Err(TurboVecSourceInspectionError::BadPrefix {
                field,
                value: value.to_string(),
                expected,
            });
        }
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
        || !proof_refs.visible_summary.contains("large local model")
        || !proof_refs
            .visible_summary
            .contains("no hidden route authority")
        || !proof_refs.visible_summary.contains("no live dense 70B")
        || !proof_refs.visible_summary.contains("clean-room")
    {
        return Err(TurboVecSourceInspectionError::MissingField(
            "visible_summary",
        ));
    }
    Ok(())
}

fn validate_byte_ledger(
    byte_ledger: &TurboVecSourceInspectionByteLedger,
) -> Result<(), TurboVecSourceInspectionError> {
    if byte_ledger.policy_metadata_bytes_read != CURRENT_POLICY_METADATA_BYTES_READ {
        return Err(TurboVecSourceInspectionError::InvalidByteLedger(
            "policy_metadata_bytes_read".to_string(),
        ));
    }
    if byte_ledger.max_future_raw_source_bytes_read == 0
        || byte_ledger.max_future_raw_source_bytes_read > MAX_FUTURE_RAW_SOURCE_BYTES_READ
    {
        return Err(TurboVecSourceInspectionError::InvalidByteLedger(
            "max_future_raw_source_bytes_read".to_string(),
        ));
    }
    for (name, value) in [
        (
            "current_raw_source_bytes_read",
            byte_ledger.current_raw_source_bytes_read,
        ),
        (
            "source_archive_bytes_fetched",
            byte_ledger.source_archive_bytes_fetched,
        ),
        (
            "quarantine_source_bytes_written",
            byte_ledger.quarantine_source_bytes_written,
        ),
        ("product_files_copied", byte_ledger.product_files_copied),
        (
            "product_dependencies_added",
            byte_ledger.product_dependencies_added,
        ),
        (
            "native_link_probe_count",
            byte_ledger.native_link_probe_count,
        ),
        ("adapter_build_count", byte_ledger.adapter_build_count),
        ("index_bytes_opened", byte_ledger.index_bytes_opened),
        ("model_bytes_loaded", byte_ledger.model_bytes_loaded),
        (
            "runtime_model_bytes_loaded",
            byte_ledger.runtime_model_bytes_loaded,
        ),
        ("provider_calls_made", byte_ledger.provider_calls_made),
    ] {
        if value != 0 {
            return Err(TurboVecSourceInspectionError::InvalidByteLedger(
                name.to_string(),
            ));
        }
    }
    Ok(())
}

fn action_matches_disposition(
    action: TurboVecInspectionAction,
    disposition: TurboVecSourceManifestDisposition,
) -> bool {
    use TurboVecInspectionAction::*;
    use TurboVecSourceManifestDisposition::*;
    match action {
        ReadProvenanceMetadata | ReadDependencyMetadata => disposition == ProvenanceOnly,
        ReadDocumentationSummary | ReadApiShape => {
            disposition == DocumentationOnly || disposition == RustCoreCandidate
        }
        ReadBehaviorSpec => disposition == RustCoreCandidate,
        ReadTestIntent => disposition == TestFixtureCandidate,
        ReadBenchmarkHarnessMetadata => disposition == BenchmarkClaimOnly,
        BlockNativeLink => disposition == NativeLinkBlocked,
        BlockBinaryAsset => disposition == BinaryAssetBlocked,
        BlockSymlink => disposition == SymlinkBlocked,
        BlockIntegration => disposition == IntegrationBlocked,
    }
}

fn expected_output_mode(action: TurboVecInspectionAction) -> TurboVecInspectionOutputMode {
    use TurboVecInspectionAction::*;
    match action {
        ReadProvenanceMetadata => TurboVecInspectionOutputMode::ProvenanceCard,
        ReadDocumentationSummary => TurboVecInspectionOutputMode::DocumentationSummary,
        ReadApiShape => TurboVecInspectionOutputMode::ApiSignatureOnly,
        ReadBehaviorSpec => TurboVecInspectionOutputMode::BehaviorSpecOnly,
        ReadDependencyMetadata => TurboVecInspectionOutputMode::DependencyRiskNote,
        ReadTestIntent => TurboVecInspectionOutputMode::FixtureIntentOnly,
        ReadBenchmarkHarnessMetadata => TurboVecInspectionOutputMode::BenchmarkCaveatOnly,
        BlockNativeLink | BlockBinaryAsset | BlockSymlink | BlockIntegration => {
            TurboVecInspectionOutputMode::Blocked
        }
    }
}

fn deterministic_set_address(rows: &[TurboVecSourceInspectionPolicyRow]) -> UasAddress {
    let mut parts = Vec::with_capacity(rows.len() + 8);
    parts.push(POLICY_REF_PREFIX.to_string());
    parts.push(SOURCE_URL.to_string());
    parts.push(TREE_API_URL.to_string());
    parts.push(PINNED_REVISION.to_string());
    parts.push(format!("rows:{}", rows.len()));
    for row in rows {
        parts.push(format!(
            "{}:{:?}:{:?}:{:?}:read={}",
            row.path,
            row.manifest_disposition,
            row.action,
            row.output_mode,
            row.future_source_read_allowed_by_later_witness
        ));
    }
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_source_inspection_policy_probe".to_string()),
        parts.join("\n").as_bytes(),
        1_779_040_903_000,
    )
}

pub fn source_inspection_policy_digest(
    set: &TurboVecRealAdapterSourceInspectionPolicyProbeSet,
) -> String {
    sha256_hex(
        format!(
            "{}\n{}\n{}\n{}",
            set.set_address,
            set.pinned_revision,
            set.policy_rows.len(),
            set.byte_ledger.max_future_raw_source_bytes_read
        )
        .as_bytes(),
    )
}

fn required_policy_paths() -> &'static [&'static str] {
    &[
        ".cargo/config.toml",
        "Cargo.lock",
        "Cargo.toml",
        "LICENSE",
        "README.md",
        "benchmarks/rabitq_poc/recall_grid.png",
        "benchmarks/suite/recall_d1536_4bit.py",
        "benchmarks/suite/speed_d1536_4bit_arm_mt.py",
        "docs/api.md",
        "examples/downstream-smoke/Cargo.toml",
        "turbovec-python/Cargo.toml",
        "turbovec-python/README.md",
        "turbovec-python/pyproject.toml",
        "turbovec-python/python/turbovec/llama_index.py",
        "turbovec/Cargo.toml",
        "turbovec/build.rs",
        "turbovec/src/id_map.rs",
        "turbovec/src/io.rs",
        "turbovec/src/lib.rs",
        "turbovec/src/search.rs",
        "turbovec/tests/filtering.rs",
        "turbovec/tests/input_validation.rs",
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_source_byte_manifest_probe".to_string()),
            b"test-upstream",
            1,
        )
    }

    fn row(
        path: &str,
        disposition: TurboVecSourceManifestDisposition,
        action: TurboVecInspectionAction,
    ) -> TurboVecSourceInspectionPolicyRow {
        let blocked = matches!(
            action,
            TurboVecInspectionAction::BlockNativeLink
                | TurboVecInspectionAction::BlockBinaryAsset
                | TurboVecInspectionAction::BlockSymlink
                | TurboVecInspectionAction::BlockIntegration
        );
        TurboVecSourceInspectionPolicyRow {
            path: path.to_string(),
            manifest_disposition: disposition,
            action,
            output_mode: expected_output_mode(action),
            future_source_read_allowed_by_later_witness: !blocked,
            verbatim_code_allowed: false,
            product_copy_allowed: false,
            product_import_allowed: false,
            product_dependency_allowed: false,
            native_link_probe_allowed: false,
            benchmark_authority_allowed: false,
            route_authority_allowed: false,
            clean_room_note_required: !blocked,
            answer_packet_caveat_required: true,
        }
    }

    fn rows() -> Vec<TurboVecSourceInspectionPolicyRow> {
        use TurboVecInspectionAction::*;
        use TurboVecSourceManifestDisposition::*;
        vec![
            row("LICENSE", ProvenanceOnly, ReadProvenanceMetadata),
            row("README.md", DocumentationOnly, ReadDocumentationSummary),
            row("Cargo.toml", ProvenanceOnly, ReadDependencyMetadata),
            row("Cargo.lock", ProvenanceOnly, ReadDependencyMetadata),
            row(".cargo/config.toml", NativeLinkBlocked, BlockNativeLink),
            row("docs/api.md", DocumentationOnly, ReadApiShape),
            row(
                "examples/downstream-smoke/Cargo.toml",
                IntegrationBlocked,
                BlockIntegration,
            ),
            row(
                "turbovec/Cargo.toml",
                ProvenanceOnly,
                ReadDependencyMetadata,
            ),
            row("turbovec/build.rs", NativeLinkBlocked, BlockNativeLink),
            row("turbovec/src/lib.rs", RustCoreCandidate, ReadApiShape),
            row(
                "turbovec/src/search.rs",
                RustCoreCandidate,
                ReadBehaviorSpec,
            ),
            row(
                "turbovec/src/id_map.rs",
                RustCoreCandidate,
                ReadBehaviorSpec,
            ),
            row("turbovec/src/io.rs", RustCoreCandidate, ReadBehaviorSpec),
            row(
                "turbovec/tests/filtering.rs",
                TestFixtureCandidate,
                ReadTestIntent,
            ),
            row(
                "turbovec/tests/input_validation.rs",
                TestFixtureCandidate,
                ReadTestIntent,
            ),
            row(
                "benchmarks/rabitq_poc/recall_grid.png",
                BinaryAssetBlocked,
                BlockBinaryAsset,
            ),
            row(
                "benchmarks/suite/recall_d1536_4bit.py",
                BenchmarkClaimOnly,
                ReadBenchmarkHarnessMetadata,
            ),
            row(
                "benchmarks/suite/speed_d1536_4bit_arm_mt.py",
                BenchmarkClaimOnly,
                ReadBenchmarkHarnessMetadata,
            ),
            row(
                "turbovec-python/Cargo.toml",
                ProvenanceOnly,
                ReadDependencyMetadata,
            ),
            row("turbovec-python/README.md", SymlinkBlocked, BlockSymlink),
            row(
                "turbovec-python/pyproject.toml",
                ProvenanceOnly,
                ReadDependencyMetadata,
            ),
            row(
                "turbovec-python/python/turbovec/llama_index.py",
                IntegrationBlocked,
                BlockIntegration,
            ),
        ]
    }

    fn proof_refs() -> TurboVecSourceInspectionProofRefs {
        TurboVecSourceInspectionProofRefs {
            source_byte_manifest_ref: SOURCE_BYTE_MANIFEST_WITNESS_REF.to_string(),
            provenance_ref: "provenance:turbovec-source-inspection:pinned-mit".to_string(),
            clean_room_ref: "clean_room:turbovec-source-inspection:paraphrase-only".to_string(),
            source_card_ref: "source_card:turbovec-source-inspection:future-cards".to_string(),
            fork_sweep_ref: "fork_sweep:turbovec-source-inspection:460-forks".to_string(),
            no_product_graph_ref: "no_product_graph:turbovec-source-inspection:deny".to_string(),
            rollback_ref: "rollback:turbovec-source-inspection:policy-tombstone".to_string(),
            run_event_log_ref: "run_event_log:turbovec-source-inspection:policy".to_string(),
            answer_packet_ref: "answer_packet:turbovec-source-inspection:policy".to_string(),
            compatibility_fence_ref: "compat:turbovec-source-inspection:apple-silicon".to_string(),
            native_link_block_ref: "native_link:turbovec-source-inspection:block-blas-build-rs"
                .to_string(),
            benchmark_caveat_ref: "benchmark_caveat:turbovec-source-inspection:non-authority"
                .to_string(),
            visible_summary: "large local model source inspection policy for TurboVec: clean-room paraphrase-only API/test/behavior motifs, no hidden route authority, no live dense 70B, no product import, no dependency insertion, no native-link build, no benchmark authority, no route mutation, no model-context injection, no raw source bytes in this witness, and AnswerPacket-visible rollback before any compressed retrieval route can cite source material for Gemma/QAT or 70B-class cold assembly.".to_string(),
        }
    }

    fn accepted(
    ) -> Result<TurboVecRealAdapterSourceInspectionPolicyProbeSet, TurboVecSourceInspectionError>
    {
        TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
            upstream(),
            rows(),
            TurboVecSourceInspectionPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceInspectionByteLedger::metadata_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T1L1Metadata,
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
    fn accepts_policy_only_fixture() {
        let set = accepted().expect("accepted source-inspection policy");
        let metrics = set.metrics();
        assert_eq!(metrics.policy_row_count, 22);
        assert!(metrics.future_read_row_count >= MIN_FUTURE_READ_ROW_COUNT);
        assert!(metrics.blocked_row_count >= MIN_BLOCKED_ROW_COUNT);
        assert_eq!(metrics.current_raw_source_bytes_read, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
    }

    #[test]
    fn address_is_deterministic_when_rows_are_reordered() {
        let mut reversed = rows();
        reversed.reverse();
        let left = accepted().expect("accepted source-inspection policy");
        let right = TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
            upstream(),
            reversed,
            TurboVecSourceInspectionPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceInspectionByteLedger::metadata_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T1L1Metadata,
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
        .expect("reordered source-inspection policy");
        assert_eq!(left.set_address, right.set_address);
        assert_eq!(
            source_inspection_policy_digest(&left),
            source_inspection_policy_digest(&right)
        );
    }

    #[test]
    fn rejects_product_import_and_route_authority() {
        let rejected = TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
            upstream(),
            rows(),
            TurboVecSourceInspectionPolicy::fail_closed(),
            proof_refs(),
            TurboVecSourceInspectionByteLedger::metadata_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecSourceInspectionStatus::PolicyOnly,
            TurboVecSourceInspectionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            true,
            true,
            true,
            true,
            true,
            true,
            true,
        );
        assert!(rejected.is_err());
    }

    #[test]
    fn rejects_blocked_row_read_and_verbatim_code() {
        let mut bad_rows = rows();
        let blocked = bad_rows
            .iter_mut()
            .find(|row| row.path == "turbovec/build.rs")
            .expect("build.rs row");
        blocked.future_source_read_allowed_by_later_witness = true;
        assert!(
            TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
                upstream(),
                bad_rows,
                TurboVecSourceInspectionPolicy::fail_closed(),
                proof_refs(),
                TurboVecSourceInspectionByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecSourceInspectionStatus::PolicyOnly,
                TurboVecSourceInspectionTier::T1L1Metadata,
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
            .is_err()
        );

        let mut bad_rows = rows();
        bad_rows[0].verbatim_code_allowed = true;
        assert!(
            TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
                upstream(),
                bad_rows,
                TurboVecSourceInspectionPolicy::fail_closed(),
                proof_refs(),
                TurboVecSourceInspectionByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecSourceInspectionStatus::PolicyOnly,
                TurboVecSourceInspectionTier::T1L1Metadata,
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
            .is_err()
        );
    }

    #[test]
    fn rejects_missing_required_path_and_current_source_bytes() {
        let mut bad_rows = rows();
        bad_rows.retain(|row| row.path != "docs/api.md");
        assert!(
            TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
                upstream(),
                bad_rows,
                TurboVecSourceInspectionPolicy::fail_closed(),
                proof_refs(),
                TurboVecSourceInspectionByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecSourceInspectionStatus::PolicyOnly,
                TurboVecSourceInspectionTier::T1L1Metadata,
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
            .is_err()
        );

        let mut ledger = TurboVecSourceInspectionByteLedger::metadata_only();
        ledger.current_raw_source_bytes_read = 1;
        assert!(
            TurboVecRealAdapterSourceInspectionPolicyProbeSet::from_parts(
                upstream(),
                rows(),
                TurboVecSourceInspectionPolicy::fail_closed(),
                proof_refs(),
                ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecSourceInspectionStatus::PolicyOnly,
                TurboVecSourceInspectionTier::T1L1Metadata,
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
            .is_err()
        );
    }
}
