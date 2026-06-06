//! TurboVec real-adapter source-pin probe.
//!
//! This primitive pins the first upstream TurboVec source revision and fork
//! survey as metadata-only proof. It does not fetch, clone, import, build,
//! run, route, or load any repository/index/model bytes.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_SOURCE_PIN_CURSOR: &str =
    "turbovec_quarantine_real_adapter_source_pin_probe";
pub const TURBOVEC_REAL_ADAPTER_SOURCE_PIN_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_dependency_envelope_probe";

const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_real_adapter_owner_approval_probe:result";
const OWNER_SELECTION_PREFIX: &str = "owner_selection:metadata_pin_only:";
const SOURCE_PIN_PREFIX: &str = "source_pin:pinned_metadata_only:";
const FORK_SWEEP_PREFIX: &str = "fork_sweep:turbovec:";
const API_REF_PREFIX: &str = "github_api:turbovec:";
const CONTENT_REF_PREFIX: &str = "github_content:turbovec:";
const ISSUE_REF_PREFIX: &str = "github_issue:turbovec:";
const RELEASE_CAVEAT_PREFIX: &str = "release_caveat:turbovec:";
const PROVENANCE_PREFIX: &str = "provenance:turbovec-source-pin:";
const DEPENDENCY_PREFIX: &str = "dependency_manifest:turbovec-source-pin:";
const ROLLBACK_PREFIX: &str = "rollback:turbovec-source-pin:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:turbovec-source-pin:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:turbovec-source-pin:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:turbovec-source-pin:";
const MAX_METADATA_BYTES: u64 = 768 * 1024;
const MIN_FORK_RECORDS: usize = 10;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 220;

// UAS: uas:turbovec-real-adapter-source-pin:status
// Plane: Controller + Verification
// Residency: metadata-only pinned source; quarantine bytes remain forbidden.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterSourcePinStatus {
    PinnedMetadataOnly,
    Blocked,
    RuntimeApprovedByLaterWitness,
}

// UAS: uas:turbovec-real-adapter-source-pin:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterSourcePinTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-source-pin:fork-disposition
// Plane: State + Verification
// Residency: fork state used for later quarantine source selection.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecForkDisposition {
    MatchesPinnedUpstream,
    LaggingKnownUpstreamCommit,
    DivergedFromSampledHistory,
}

// UAS: uas:turbovec-real-adapter-source-pin:allowed-action
// Plane: Controller + Verification
// Residency: this witness allows only source metadata citation.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecSourcePinAllowedAction {
    PinnedMetadataOnly,
    FetchQuarantineBytes,
    AdapterWrap,
    DirectImport,
    ProductIntegration,
}

// UAS: uas:turbovec-real-adapter-source-pin:byte-ledger
// Plane: Verification
// Residency: zero actual source/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourcePinByteLedger {
    pub github_metadata_bytes_read: u64,
    pub planned_quarantine_bytes: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
    pub copied_product_file_count: u64,
    pub imported_external_crate_count: u64,
    pub built_external_binary_count: u64,
    pub opened_product_index_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl TurboVecSourcePinByteLedger {
    pub fn metadata_only(github_metadata_bytes_read: u64, planned_quarantine_bytes: u64) -> Self {
        Self {
            github_metadata_bytes_read,
            planned_quarantine_bytes,
            fetched_repo_bytes: 0,
            cloned_repo_bytes: 0,
            copied_product_file_count: 0,
            imported_external_crate_count: 0,
            built_external_binary_count: 0,
            opened_product_index_bytes: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-pin:source-card
// Plane: State + Assembly + Verification
// Residency: pinned source metadata for future quarantine planning.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecPinnedSourceCard {
    pub source_card_id: String,
    pub source_url: String,
    pub owner_repo: String,
    pub default_branch: String,
    pub pinned_revision: String,
    pub branch_protected: bool,
    pub license_id: String,
    pub stargazers_count: u64,
    pub fork_count: u64,
    pub open_issue_count: u64,
    pub release_count: u64,
    pub repo_size_kib: u64,
    pub pushed_at_utc: String,
    pub updated_at_utc: String,
    pub readme_sha: String,
    pub license_sha: String,
    pub cargo_toml_sha: String,
    pub api_refs: Vec<String>,
    pub issue_refs: Vec<String>,
    pub release_caveat_ref: String,
    pub owner_selection_ref: String,
    pub source_pin_ref: String,
    pub fork_sweep_ref: String,
    pub provenance_ref: String,
    pub dependency_manifest_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub visible_summary: String,
    pub allowed_action: TurboVecSourcePinAllowedAction,
    pub byte_ledger: TurboVecSourcePinByteLedger,
    pub source_pin_is_metadata_only: bool,
    pub owner_runtime_approval_granted: bool,
    pub repo_fetched_or_cloned: bool,
    pub dependency_added_to_product: bool,
    pub source_copied_to_product: bool,
    pub adapter_built_or_run: bool,
    pub upstream_benchmark_claimed_as_product_proof: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub product_capability_promoted: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-source-pin:fork-record
// Plane: State + Verification
// Residency: fork metadata only; no fork bytes fetched.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecForkSweepRecord {
    pub fork_repo: String,
    pub fork_url: String,
    pub default_branch: String,
    pub branch_sha: String,
    pub license_id: String,
    pub stargazers_count: u64,
    pub open_issue_count: u64,
    pub repo_size_kib: u64,
    pub pushed_at_utc: String,
    pub archived: bool,
    pub disabled: bool,
    pub branch_protected: bool,
    pub disposition: TurboVecForkDisposition,
}

// UAS: uas:turbovec-real-adapter-source-pin:policy
// Plane: Controller + Verification
// Residency: fail-closed pin/fork policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecSourcePinPolicy {
    pub owner_gate_required: bool,
    pub pinned_revision_required: bool,
    pub branch_protection_required: bool,
    pub fork_sweep_required: bool,
    pub fork_disposition_diversity_required: bool,
    pub github_api_refs_required: bool,
    pub content_sha_refs_required: bool,
    pub swift_issue_visibility_required: bool,
    pub benchmark_issue_visibility_required: bool,
    pub release_absence_caveat_required: bool,
    pub clean_room_provenance_required: bool,
    pub dependency_manifest_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub no_fetch_clone_import_build_or_run: bool,
    pub no_route_or_context_authority: bool,
}

impl TurboVecSourcePinPolicy {
    pub fn fail_closed() -> Self {
        Self {
            owner_gate_required: true,
            pinned_revision_required: true,
            branch_protection_required: true,
            fork_sweep_required: true,
            fork_disposition_diversity_required: true,
            github_api_refs_required: true,
            content_sha_refs_required: true,
            swift_issue_visibility_required: true,
            benchmark_issue_visibility_required: true,
            release_absence_caveat_required: true,
            clean_room_provenance_required: true,
            dependency_manifest_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            no_fetch_clone_import_build_or_run: true,
            no_route_or_context_authority: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-source-pin:probe-set
// Plane: Controller + Verification
// Residency: deterministic metadata-only source-pin set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterSourcePinProbeSet {
    pub set_address: UasAddress,
    pub upstream_owner_gate_address: UasAddress,
    pub upstream_owner_gate_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecRealAdapterSourcePinStatus,
    pub promotion_tier: TurboVecRealAdapterSourcePinTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecSourcePinPolicy,
    pub source_card: TurboVecPinnedSourceCard,
    pub fork_records: Vec<TurboVecForkSweepRecord>,
    pub metadata_bytes_read: u64,
    pub product_capability_promoted: bool,
}

// UAS: uas:turbovec-real-adapter-source-pin:metrics
// Plane: Verification
// Residency: derived axes for artifact emission.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecRealAdapterSourcePinMetrics {
    pub source_card_count: u64,
    pub fork_record_count: u64,
    pub matching_upstream_fork_count: u64,
    pub lagging_fork_count: u64,
    pub diverged_fork_count: u64,
    pub unarchived_enabled_fork_count: u64,
    pub unique_fork_sha_count: u64,
    pub github_api_ref_count: u64,
    pub issue_ref_count: u64,
    pub content_sha_ref_count: u64,
    pub release_count: u64,
    pub max_planned_quarantine_bytes: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
    pub copied_product_file_count: u64,
    pub imported_external_crate_count: u64,
    pub built_external_binary_count: u64,
    pub opened_product_index_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
}

impl TurboVecRealAdapterSourcePinProbeSet {
    pub fn from_parts(
        upstream_owner_gate_address: UasAddress,
        source_card: TurboVecPinnedSourceCard,
        mut fork_records: Vec<TurboVecForkSweepRecord>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecRealAdapterSourcePinStatus,
        promotion_tier: TurboVecRealAdapterSourcePinTier,
        organs: Vec<TurboVecIndexOrgan>,
        policy: TurboVecSourcePinPolicy,
        metadata_bytes_read: u64,
        product_capability_promoted: bool,
    ) -> Result<Self, TurboVecRealAdapterSourcePinError> {
        fork_records.sort_by(|left, right| left.fork_repo.cmp(&right.fork_repo));
        validate_set_inputs(
            &upstream_owner_gate_address,
            &source_card,
            &fork_records,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            &policy,
            metadata_bytes_read,
            product_capability_promoted,
        )?;
        validate_source_card(&source_card)?;
        validate_fork_records(&fork_records, &source_card.pinned_revision)?;
        let set_address =
            deterministic_set_address(&source_card, &fork_records, metadata_bytes_read);
        Ok(Self {
            set_address,
            upstream_owner_gate_address,
            upstream_owner_gate_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            policy,
            source_card,
            fork_records,
            metadata_bytes_read,
            product_capability_promoted,
        })
    }

    pub fn metrics(&self) -> TurboVecRealAdapterSourcePinMetrics {
        let mut unique_shas = HashSet::new();
        let mut metrics = TurboVecRealAdapterSourcePinMetrics {
            source_card_count: 1,
            fork_record_count: self.fork_records.len() as u64,
            github_api_ref_count: self.source_card.api_refs.len() as u64,
            issue_ref_count: self.source_card.issue_refs.len() as u64,
            content_sha_ref_count: 3,
            release_count: self.source_card.release_count,
            max_planned_quarantine_bytes: self.source_card.byte_ledger.planned_quarantine_bytes,
            fetched_repo_bytes: self.source_card.byte_ledger.fetched_repo_bytes,
            cloned_repo_bytes: self.source_card.byte_ledger.cloned_repo_bytes,
            copied_product_file_count: self.source_card.byte_ledger.copied_product_file_count,
            imported_external_crate_count: self
                .source_card
                .byte_ledger
                .imported_external_crate_count,
            built_external_binary_count: self.source_card.byte_ledger.built_external_binary_count,
            opened_product_index_bytes: self.source_card.byte_ledger.opened_product_index_bytes,
            model_bytes_loaded: self.source_card.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.source_card.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.source_card.byte_ledger.provider_calls_made,
            ..TurboVecRealAdapterSourcePinMetrics::default()
        };
        for fork in &self.fork_records {
            unique_shas.insert(fork.branch_sha.clone());
            if !fork.archived && !fork.disabled {
                metrics.unarchived_enabled_fork_count += 1;
            }
            match fork.disposition {
                TurboVecForkDisposition::MatchesPinnedUpstream => {
                    metrics.matching_upstream_fork_count += 1;
                }
                TurboVecForkDisposition::LaggingKnownUpstreamCommit => {
                    metrics.lagging_fork_count += 1;
                }
                TurboVecForkDisposition::DivergedFromSampledHistory => {
                    metrics.diverged_fork_count += 1;
                }
            }
        }
        metrics.unique_fork_sha_count = unique_shas.len() as u64;
        if self.source_card.route_mutation_allowed {
            metrics.route_mutation_count += 1;
        }
        if self.source_card.model_context_injected {
            metrics.model_context_injection_count += 1;
        }
        if self.source_card.hidden_route_authority || self.source_card.hidden_cloud_fallback_allowed
        {
            metrics.hidden_authority_count += 1;
        }
        metrics
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: TurboVecRealAdapterSourcePinProbe validation error.
// Plane: Verification.
// Residency: Metadata-only diagnostic; no source/runtime/model bytes.
pub enum TurboVecRealAdapterSourcePinError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecRealAdapterSourcePinStatus),
    BadPromotionTier(TurboVecRealAdapterSourcePinTier),
    MetadataBudgetExceeded(u64),
    ProductPromotionAllowed,
    InvalidOrgans,
    InvalidPolicy(String),
    BadSource(String),
    BadRevision(String),
    MissingField(&'static str),
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    EmptyForkSweep,
    TooFewForks(usize),
    DuplicateFork(String),
    BadFork(String),
    MissingForkDisposition(&'static str),
    ExternalBytesTouched(String),
    ForbiddenAuthority(String),
}

impl fmt::Display for TurboVecRealAdapterSourcePinError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "upstream owner gate cursor mismatch"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad source-pin status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad source-pin tier: {tier:?}"),
            Self::MetadataBudgetExceeded(bytes) => {
                write!(f, "metadata budget exceeded: {bytes}")
            }
            Self::ProductPromotionAllowed => write!(f, "product promotion attempted"),
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidPolicy(reason) => write!(f, "invalid source-pin policy: {reason}"),
            Self::BadSource(reason) => write!(f, "bad pinned source: {reason}"),
            Self::BadRevision(rev) => write!(f, "bad revision: {rev}"),
            Self::MissingField(field) => write!(f, "missing field: {field}"),
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(f, "{field} `{value}` must start with `{expected}`"),
            Self::EmptyForkSweep => write!(f, "fork sweep is empty"),
            Self::TooFewForks(count) => write!(f, "too few fork records: {count}"),
            Self::DuplicateFork(repo) => write!(f, "duplicate fork record: {repo}"),
            Self::BadFork(reason) => write!(f, "bad fork record: {reason}"),
            Self::MissingForkDisposition(kind) => write!(f, "missing fork disposition: {kind}"),
            Self::ExternalBytesTouched(reason) => write!(f, "external bytes touched: {reason}"),
            Self::ForbiddenAuthority(reason) => write!(f, "forbidden authority: {reason}"),
        }
    }
}

impl std::error::Error for TurboVecRealAdapterSourcePinError {}

fn validate_set_inputs(
    upstream_owner_gate_address: &UasAddress,
    source_card: &TurboVecPinnedSourceCard,
    fork_records: &[TurboVecForkSweepRecord],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecRealAdapterSourcePinStatus,
    promotion_tier: &TurboVecRealAdapterSourcePinTier,
    organs: &[TurboVecIndexOrgan],
    policy: &TurboVecSourcePinPolicy,
    metadata_bytes_read: u64,
    product_capability_promoted: bool,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    if !upstream_owner_gate_address
        .to_string()
        .starts_with("turbovec_real_adapter_owner_approval_probe:")
    {
        return Err(TurboVecRealAdapterSourcePinError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecRealAdapterSourcePinError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecRealAdapterSourcePinError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if status != &TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly {
        return Err(TurboVecRealAdapterSourcePinError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecRealAdapterSourcePinTier::T1L1Metadata {
        return Err(TurboVecRealAdapterSourcePinError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    if metadata_bytes_read == 0 || metadata_bytes_read > MAX_METADATA_BYTES {
        return Err(TurboVecRealAdapterSourcePinError::MetadataBudgetExceeded(
            metadata_bytes_read,
        ));
    }
    if product_capability_promoted || source_card.product_capability_promoted {
        return Err(TurboVecRealAdapterSourcePinError::ProductPromotionAllowed);
    }
    validate_organs(organs)?;
    validate_policy(policy)?;
    if fork_records.is_empty() {
        return Err(TurboVecRealAdapterSourcePinError::EmptyForkSweep);
    }
    if fork_records.len() < MIN_FORK_RECORDS {
        return Err(TurboVecRealAdapterSourcePinError::TooFewForks(
            fork_records.len(),
        ));
    }
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecRealAdapterSourcePinError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let set: HashSet<_> = organs.iter().copied().collect();
    if organs.len() != required.len() || required.iter().any(|organ| !set.contains(organ)) {
        return Err(TurboVecRealAdapterSourcePinError::InvalidOrgans);
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecSourcePinPolicy,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    let required = [
        (
            policy.owner_gate_required,
            "owner gate must remain required",
        ),
        (
            policy.pinned_revision_required,
            "pinned revision must be required",
        ),
        (
            policy.branch_protection_required,
            "branch protection must be recorded",
        ),
        (policy.fork_sweep_required, "fork sweep must be required"),
        (
            policy.fork_disposition_diversity_required,
            "fork disposition diversity must be required",
        ),
        (
            policy.github_api_refs_required,
            "GitHub API refs must be required",
        ),
        (
            policy.content_sha_refs_required,
            "content SHA refs must be required",
        ),
        (
            policy.swift_issue_visibility_required,
            "Swift issue visibility must be required",
        ),
        (
            policy.benchmark_issue_visibility_required,
            "benchmark issue visibility must be required",
        ),
        (
            policy.release_absence_caveat_required,
            "release caveat must be required",
        ),
        (
            policy.clean_room_provenance_required,
            "clean-room provenance must be required",
        ),
        (
            policy.dependency_manifest_required,
            "dependency manifest must be required",
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
            policy.no_fetch_clone_import_build_or_run,
            "fetch/clone/import/build/run must be forbidden",
        ),
        (
            policy.no_route_or_context_authority,
            "route/context authority must be forbidden",
        ),
    ];
    for (ok, reason) in required {
        if !ok {
            return Err(TurboVecRealAdapterSourcePinError::InvalidPolicy(
                reason.to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_source_card(
    card: &TurboVecPinnedSourceCard,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    required_nonempty("source_card_id", &card.source_card_id)?;
    if card.source_url != "https://github.com/RyanCodrai/turbovec" {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "source URL must be RyanCodrai/turbovec".to_string(),
        ));
    }
    if card.owner_repo != "RyanCodrai/turbovec" || card.default_branch != "main" {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "owner repo/default branch mismatch".to_string(),
        ));
    }
    validate_revision(&card.pinned_revision)?;
    if !card.branch_protected {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "upstream branch protection must be recorded true".to_string(),
        ));
    }
    if card.license_id != "MIT" {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "license must be MIT".to_string(),
        ));
    }
    if card.stargazers_count == 0
        || card.fork_count < 10
        || card.open_issue_count == 0
        || card.repo_size_kib == 0
    {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "repo stats must be nonzero and fork-rich".to_string(),
        ));
    }
    if card.release_count != 0 {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "release count must remain zero with caveat".to_string(),
        ));
    }
    for (field, value) in [
        ("readme_sha", &card.readme_sha),
        ("license_sha", &card.license_sha),
        ("cargo_toml_sha", &card.cargo_toml_sha),
    ] {
        validate_revision(value)
            .map_err(|_| TurboVecRealAdapterSourcePinError::MissingField(field))?;
    }
    require_prefix(
        "release_caveat_ref",
        &card.release_caveat_ref,
        RELEASE_CAVEAT_PREFIX,
    )?;
    require_prefix(
        "owner_selection_ref",
        &card.owner_selection_ref,
        OWNER_SELECTION_PREFIX,
    )?;
    require_prefix("source_pin_ref", &card.source_pin_ref, SOURCE_PIN_PREFIX)?;
    require_prefix("fork_sweep_ref", &card.fork_sweep_ref, FORK_SWEEP_PREFIX)?;
    require_prefix("provenance_ref", &card.provenance_ref, PROVENANCE_PREFIX)?;
    require_prefix(
        "dependency_manifest_ref",
        &card.dependency_manifest_ref,
        DEPENDENCY_PREFIX,
    )?;
    require_prefix("rollback_ref", &card.rollback_ref, ROLLBACK_PREFIX)?;
    require_prefix(
        "run_event_log_ref",
        &card.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        "answer_packet_ref",
        &card.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        "compatibility_fence_ref",
        &card.compatibility_fence_ref,
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    if !card
        .api_refs
        .iter()
        .all(|ref_| ref_.starts_with(API_REF_PREFIX) || ref_.starts_with(CONTENT_REF_PREFIX))
    {
        return Err(TurboVecRealAdapterSourcePinError::BadSource(
            "all source refs must use approved github_api/github_content prefixes".to_string(),
        ));
    }
    let github_api_refs: Vec<_> = card
        .api_refs
        .iter()
        .filter(|ref_| ref_.starts_with(API_REF_PREFIX))
        .collect();
    let required_api_refs = ["repo", "branch", "commits", "forks", "issues", "contents"];
    for required in required_api_refs {
        if !github_api_refs.iter().any(|ref_| ref_.contains(required)) {
            return Err(TurboVecRealAdapterSourcePinError::MissingField(
                "required_api_ref",
            ));
        }
    }
    if !card
        .api_refs
        .iter()
        .any(|ref_| ref_.starts_with(CONTENT_REF_PREFIX))
    {
        return Err(TurboVecRealAdapterSourcePinError::MissingField(
            "content_sha_ref",
        ));
    }
    if !card
        .issue_refs
        .iter()
        .all(|ref_| ref_.starts_with(ISSUE_REF_PREFIX))
        || !card.issue_refs.iter().any(|ref_| ref_.contains(":86:"))
        || !card.issue_refs.iter().any(|ref_| ref_.contains(":65:"))
    {
        return Err(TurboVecRealAdapterSourcePinError::MissingField(
            "required_issue_refs",
        ));
    }
    if !matches!(
        card.allowed_action,
        TurboVecSourcePinAllowedAction::PinnedMetadataOnly
    ) {
        return Err(TurboVecRealAdapterSourcePinError::ForbiddenAuthority(
            "allowed action must stay pinned metadata only".to_string(),
        ));
    }
    if card.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(TurboVecRealAdapterSourcePinError::MissingField(
            "visible_summary",
        ));
    }
    if !card.source_pin_is_metadata_only
        || card.owner_runtime_approval_granted
        || card.repo_fetched_or_cloned
        || card.dependency_added_to_product
        || card.source_copied_to_product
        || card.adapter_built_or_run
        || card.upstream_benchmark_claimed_as_product_proof
    {
        return Err(TurboVecRealAdapterSourcePinError::ExternalBytesTouched(
            "source pin attempted runtime/import/product behavior".to_string(),
        ));
    }
    if card.route_mutation_allowed
        || card.model_context_injected
        || card.hidden_route_authority
        || card.hidden_cloud_fallback_allowed
        || card.live_large_model_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(TurboVecRealAdapterSourcePinError::ForbiddenAuthority(
            "route/context/cloud/large-model authority attempted".to_string(),
        ));
    }
    validate_zero_bytes(&card.byte_ledger)
}

fn validate_fork_records(
    records: &[TurboVecForkSweepRecord],
    pinned_revision: &str,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    let mut repos = HashSet::new();
    let mut matching = 0;
    let mut lagging = 0;
    let mut diverged = 0;
    for record in records {
        if !repos.insert(record.fork_repo.clone()) {
            return Err(TurboVecRealAdapterSourcePinError::DuplicateFork(
                record.fork_repo.clone(),
            ));
        }
        if !record.fork_url.starts_with("https://github.com/") {
            return Err(TurboVecRealAdapterSourcePinError::BadFork(
                "fork URL must be GitHub HTTPS".to_string(),
            ));
        }
        if record.default_branch != "main" || record.license_id != "MIT" {
            return Err(TurboVecRealAdapterSourcePinError::BadFork(
                "fork default branch/license mismatch".to_string(),
            ));
        }
        validate_revision(&record.branch_sha)?;
        if record.archived || record.disabled {
            return Err(TurboVecRealAdapterSourcePinError::BadFork(
                "fork must not be archived or disabled".to_string(),
            ));
        }
        match record.disposition {
            TurboVecForkDisposition::MatchesPinnedUpstream => {
                if record.branch_sha != pinned_revision {
                    return Err(TurboVecRealAdapterSourcePinError::BadFork(
                        "matching fork SHA must equal pinned upstream".to_string(),
                    ));
                }
                matching += 1;
            }
            TurboVecForkDisposition::LaggingKnownUpstreamCommit => {
                if record.branch_sha == pinned_revision {
                    return Err(TurboVecRealAdapterSourcePinError::BadFork(
                        "lagging fork cannot equal pinned upstream".to_string(),
                    ));
                }
                lagging += 1;
            }
            TurboVecForkDisposition::DivergedFromSampledHistory => {
                if record.branch_sha == pinned_revision {
                    return Err(TurboVecRealAdapterSourcePinError::BadFork(
                        "diverged fork cannot equal pinned upstream".to_string(),
                    ));
                }
                diverged += 1;
            }
        }
    }
    if matching == 0 {
        return Err(TurboVecRealAdapterSourcePinError::MissingForkDisposition(
            "matches_pinned_upstream",
        ));
    }
    if lagging == 0 {
        return Err(TurboVecRealAdapterSourcePinError::MissingForkDisposition(
            "lagging_known_upstream_commit",
        ));
    }
    if diverged == 0 {
        return Err(TurboVecRealAdapterSourcePinError::MissingForkDisposition(
            "diverged_from_sampled_history",
        ));
    }
    Ok(())
}

fn validate_revision(rev: &str) -> Result<(), TurboVecRealAdapterSourcePinError> {
    if rev.len() == 40 && rev.bytes().all(|b| b.is_ascii_hexdigit()) {
        Ok(())
    } else {
        Err(TurboVecRealAdapterSourcePinError::BadRevision(
            rev.to_string(),
        ))
    }
}

fn validate_zero_bytes(
    ledger: &TurboVecSourcePinByteLedger,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    if ledger.fetched_repo_bytes == 0
        && ledger.cloned_repo_bytes == 0
        && ledger.copied_product_file_count == 0
        && ledger.imported_external_crate_count == 0
        && ledger.built_external_binary_count == 0
        && ledger.opened_product_index_bytes == 0
        && ledger.model_bytes_loaded == 0
        && ledger.runtime_model_bytes_loaded == 0
        && ledger.provider_calls_made == 0
    {
        Ok(())
    } else {
        Err(TurboVecRealAdapterSourcePinError::ExternalBytesTouched(
            "source pin byte ledger must stay zero".to_string(),
        ))
    }
}

fn require_prefix(
    field: &'static str,
    value: &str,
    expected: &'static str,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    if value.starts_with(expected) {
        Ok(())
    } else {
        Err(TurboVecRealAdapterSourcePinError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        })
    }
}

fn required_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), TurboVecRealAdapterSourcePinError> {
    if value.trim().is_empty() {
        Err(TurboVecRealAdapterSourcePinError::MissingField(field))
    } else {
        Ok(())
    }
}

fn deterministic_set_address(
    source_card: &TurboVecPinnedSourceCard,
    fork_records: &[TurboVecForkSweepRecord],
    metadata_bytes_read: u64,
) -> UasAddress {
    let mut payload = Vec::new();
    payload.extend_from_slice(source_card.source_card_id.as_bytes());
    payload.extend_from_slice(source_card.pinned_revision.as_bytes());
    payload.extend_from_slice(metadata_bytes_read.to_string().as_bytes());
    for fork in fork_records {
        payload.extend_from_slice(fork.fork_repo.as_bytes());
        payload.extend_from_slice(fork.branch_sha.as_bytes());
        payload.extend_from_slice(format!("{:?}", fork.disposition).as_bytes());
    }
    let digest = sha256_hex(&payload);
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_source_pin_probe".to_string()),
        digest.as_bytes(),
        1_779_040_800_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_owner_approval_probe".to_string()),
            b"owner-gate",
            1_779_040_800_000,
        )
    }

    fn source_card() -> TurboVecPinnedSourceCard {
        TurboVecPinnedSourceCard {
            source_card_id: "ryancodrai_turbovec_upstream_source_pin".to_string(),
            source_url: "https://github.com/RyanCodrai/turbovec".to_string(),
            owner_repo: "RyanCodrai/turbovec".to_string(),
            default_branch: "main".to_string(),
            pinned_revision: "efe29a184986cbf562a9847c2ac52a2990bfaca2".to_string(),
            branch_protected: true,
            license_id: "MIT".to_string(),
            stargazers_count: 4711,
            fork_count: 453,
            open_issue_count: 5,
            release_count: 0,
            repo_size_kib: 4970,
            pushed_at_utc: "2026-05-30T13:12:07Z".to_string(),
            updated_at_utc: "2026-06-06T13:10:07Z".to_string(),
            readme_sha: "1bcd3121da5c5da47e2259adf1959f9df6af06ef".to_string(),
            license_sha: "e62ad7c6028ad9b2f9b4c1776dc7d4a9c942fced".to_string(),
            cargo_toml_sha: "9bf15f9f5eba2de42db231e9235c4181f620277f".to_string(),
            api_refs: vec![
                "github_api:turbovec:repo:RyanCodrai/turbovec".to_string(),
                "github_api:turbovec:branch:main:protected".to_string(),
                "github_api:turbovec:commits:latest5".to_string(),
                "github_api:turbovec:forks:top10".to_string(),
                "github_api:turbovec:issues:open".to_string(),
                "github_api:turbovec:contents:readme-license-cargo".to_string(),
                "github_content:turbovec:readme-license-cargo-sha".to_string(),
            ],
            issue_refs: vec![
                "github_issue:turbovec:86:swift-macos-binding".to_string(),
                "github_issue:turbovec:65:insertion-removal-benchmarks".to_string(),
            ],
            release_caveat_ref: "release_caveat:turbovec:no_github_releases_release_is_commit_message_not_runtime_proof".to_string(),
            owner_selection_ref: "owner_selection:metadata_pin_only:research_selected_upstream_not_runtime_approval".to_string(),
            source_pin_ref: "source_pin:pinned_metadata_only:efe29a184986cbf562a9847c2ac52a2990bfaca2".to_string(),
            fork_sweep_ref: "fork_sweep:turbovec:top10_public_forks_api_metadata_only".to_string(),
            provenance_ref: "provenance:turbovec-source-pin:clean-room-source-card".to_string(),
            dependency_manifest_ref: "dependency_manifest:turbovec-source-pin:no-product-dependency".to_string(),
            rollback_ref: "rollback:turbovec-source-pin:drop-pinned-source-card".to_string(),
            run_event_log_ref: "run_event_log:turbovec-source-pin:metadata-only".to_string(),
            answer_packet_ref: "answer_packet:turbovec-source-pin:visible-non-promotion".to_string(),
            compatibility_fence_ref: "compat:turbovec-source-pin:no-runtime-bytes".to_string(),
            visible_summary: "TurboVec upstream main is pinned as metadata-only source evidence after a fork sweep. This does not approve repository bytes, source import, adapter wrapping, model context mutation, product routing, or large-model runtime claims.".to_string(),
            allowed_action: TurboVecSourcePinAllowedAction::PinnedMetadataOnly,
            byte_ledger: TurboVecSourcePinByteLedger::metadata_only(96_000, 8_388_608),
            source_pin_is_metadata_only: true,
            owner_runtime_approval_granted: false,
            repo_fetched_or_cloned: false,
            dependency_added_to_product: false,
            source_copied_to_product: false,
            adapter_built_or_run: false,
            upstream_benchmark_claimed_as_product_proof: false,
            route_mutation_allowed: false,
            model_context_injected: false,
            hidden_route_authority: false,
            hidden_cloud_fallback_allowed: false,
            product_capability_promoted: false,
            live_large_model_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn fork(
        repo: &str,
        sha: &str,
        disposition: TurboVecForkDisposition,
    ) -> TurboVecForkSweepRecord {
        TurboVecForkSweepRecord {
            fork_repo: repo.to_string(),
            fork_url: format!("https://github.com/{repo}"),
            default_branch: "main".to_string(),
            branch_sha: sha.to_string(),
            license_id: "MIT".to_string(),
            stargazers_count: 1,
            open_issue_count: 0,
            repo_size_kib: 4970,
            pushed_at_utc: "2026-05-30T13:12:07Z".to_string(),
            archived: false,
            disabled: false,
            branch_protected: false,
            disposition,
        }
    }

    fn forks() -> Vec<TurboVecForkSweepRecord> {
        vec![
            fork(
                "manuelapetsi/turbovec",
                "efe29a184986cbf562a9847c2ac52a2990bfaca2",
                TurboVecForkDisposition::MatchesPinnedUpstream,
            ),
            fork(
                "MSAIGlobal/turbovec",
                "efe29a184986cbf562a9847c2ac52a2990bfaca2",
                TurboVecForkDisposition::MatchesPinnedUpstream,
            ),
            fork(
                "pellera9/turbovec",
                "efe29a184986cbf562a9847c2ac52a2990bfaca2",
                TurboVecForkDisposition::MatchesPinnedUpstream,
            ),
            fork(
                "wachirawit29/turbovec",
                "06155d9bf2219f0d23287d1d12b5598e676a27b1",
                TurboVecForkDisposition::LaggingKnownUpstreamCommit,
            ),
            fork(
                "Igorrmcastro1709/turbovec",
                "1aca71ca7e65951b6ed11cde29e904afe124291a",
                TurboVecForkDisposition::LaggingKnownUpstreamCommit,
            ),
            fork(
                "rohitg00/turbovec",
                "1aca71ca7e65951b6ed11cde29e904afe124291a",
                TurboVecForkDisposition::LaggingKnownUpstreamCommit,
            ),
            fork(
                "federicogrecobarragan-prog/turbovec",
                "3bde2c31c24ce23e3d85598f5fd7cae4f85e41a4",
                TurboVecForkDisposition::DivergedFromSampledHistory,
            ),
            fork(
                "NullLabTests/turbovec",
                "0c9758b9f4608db9818e4175ec2c29f742958869",
                TurboVecForkDisposition::DivergedFromSampledHistory,
            ),
            fork(
                "bab321-AI/turbovec",
                "3d0d6afb4edf79a1989ad7e225561d1c8e06e3f5",
                TurboVecForkDisposition::DivergedFromSampledHistory,
            ),
            fork(
                "AKHtun/turbovec-wecos",
                "4a4f2cd2db233f24405911b1ceaf1823fa23b4ac",
                TurboVecForkDisposition::DivergedFromSampledHistory,
            ),
        ]
    }

    fn set(
        card: TurboVecPinnedSourceCard,
        forks: Vec<TurboVecForkSweepRecord>,
    ) -> Result<TurboVecRealAdapterSourcePinProbeSet, TurboVecRealAdapterSourcePinError> {
        TurboVecRealAdapterSourcePinProbeSet::from_parts(
            upstream(),
            card,
            forks,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterSourcePinStatus::PinnedMetadataOnly,
            TurboVecRealAdapterSourcePinTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            TurboVecSourcePinPolicy::fail_closed(),
            128_000,
            false,
        )
    }

    #[test]
    fn accepts_metadata_only_source_pin_and_fork_sweep() {
        let accepted = set(source_card(), forks()).expect("valid source-pin set");
        let metrics = accepted.metrics();
        assert_eq!(metrics.source_card_count, 1);
        assert_eq!(metrics.fork_record_count, 10);
        assert_eq!(metrics.matching_upstream_fork_count, 3);
        assert_eq!(metrics.lagging_fork_count, 3);
        assert_eq!(metrics.diverged_fork_count, 4);
        assert_eq!(metrics.fetched_repo_bytes, 0);
    }

    #[test]
    fn rejects_bad_or_unpinned_source_revision() {
        let mut card = source_card();
        card.pinned_revision = "short-sha".to_string();
        assert!(matches!(
            set(card, forks()),
            Err(TurboVecRealAdapterSourcePinError::BadRevision(_))
        ));
    }

    #[test]
    fn rejects_incomplete_fork_sweep_or_duplicate_fork() {
        let mut too_few = forks();
        too_few.pop();
        assert!(matches!(
            set(source_card(), too_few),
            Err(TurboVecRealAdapterSourcePinError::TooFewForks(9))
        ));

        let mut duplicate = forks();
        duplicate[1].fork_repo = duplicate[0].fork_repo.clone();
        assert!(matches!(
            set(source_card(), duplicate),
            Err(TurboVecRealAdapterSourcePinError::DuplicateFork(_))
        ));
    }

    #[test]
    fn rejects_product_runtime_or_hidden_authority_shortcuts() {
        let mut card = source_card();
        card.repo_fetched_or_cloned = true;
        assert!(matches!(
            set(card, forks()),
            Err(TurboVecRealAdapterSourcePinError::ExternalBytesTouched(_))
        ));

        let mut card = source_card();
        card.route_mutation_allowed = true;
        assert!(matches!(
            set(card, forks()),
            Err(TurboVecRealAdapterSourcePinError::ForbiddenAuthority(_))
        ));
    }
}
