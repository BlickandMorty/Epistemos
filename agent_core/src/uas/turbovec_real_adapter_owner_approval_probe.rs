//! TurboVec real-adapter owner-approval probe.
//!
//! This primitive is still metadata-only. It turns the synthetic quarantine
//! microbench into a fail-closed source/provenance gate for the first real
//! TurboVec/fork adapter probe. It may name candidate sources, but it cannot
//! fetch, clone, import, build, run, or route through them.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_CURSOR: &str =
    "turbovec_quarantine_real_adapter_owner_approval_probe";
pub const TURBOVEC_REAL_ADAPTER_OWNER_APPROVAL_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_source_pin_probe";

const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_quarantine_adapter_microbench_probe:result";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:turbovec-real-adapter:";
const SOURCE_PIN_PREFIX: &str = "source_pin:pending_owner_selection:";
const QUARANTINE_PATH_PREFIX: &str = "quarantine_path:pending:";
const PROVENANCE_PREFIX: &str = "provenance:turbovec-real-adapter:";
const DEPENDENCY_PREFIX: &str = "dependency_manifest:quarantine-only:";
const BENCHMARK_CAVEAT_PREFIX: &str = "benchmark_caveat:upstream-not-product-proof:";
const API_PREFIX: &str = "api:turbovec:";
const ROLLBACK_PREFIX: &str = "rollback:turbovec-real-adapter:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:turbovec-real-adapter:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:turbovec-real-adapter:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:turbovec-real-adapter:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_SOURCE_CARDS: usize = 4;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;

// UAS: uas:turbovec-real-adapter-owner:status
// Plane: Controller + Verification
// Residency: owner approval remains pending in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterOwnerApprovalStatus {
    PendingOwnerApproval,
    OwnerApprovedForLaterWitness,
    Blocked,
}

// UAS: uas:turbovec-real-adapter-owner:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterOwnerApprovalTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-owner:source-kind
// Plane: State + Verification
// Residency: source class for future quarantine selection.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterSourceKind {
    UpstreamGithubRepo,
    ForkGithubRepo,
    LocalQuarantineMirror,
}

// UAS: uas:turbovec-real-adapter-owner:allowed-action
// Plane: Controller + Verification
// Residency: only quarantine reference is allowed in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecRealAdapterAllowedAction {
    QuarantineReferenceOnly,
    AdapterWrap,
    DirectImport,
    ProductIntegration,
}

// UAS: uas:turbovec-real-adapter-owner:byte-ledger
// Plane: Verification
// Residency: future quarantine planning bytes plus zero actual source/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterOwnerByteLedger {
    pub metadata_bytes_read: u64,
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

impl TurboVecRealAdapterOwnerByteLedger {
    pub fn pending(metadata_bytes_read: u64, planned_quarantine_bytes: u64) -> Self {
        Self {
            metadata_bytes_read,
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

// UAS: uas:turbovec-real-adapter-owner:source-card
// Plane: State + Assembly + Verification
// Residency: source card for future real-adapter quarantine.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterSourceCard {
    pub source_card_id: String,
    pub source_kind: TurboVecRealAdapterSourceKind,
    pub source_url: String,
    pub owner_repo: String,
    pub license_id: String,
    pub declared_language_refs: Vec<String>,
    pub expected_api_refs: Vec<String>,
    pub allowed_action: TurboVecRealAdapterAllowedAction,
    pub owner_approval_ref: String,
    pub source_pin_ref: String,
    pub quarantine_path_ref: String,
    pub provenance_ref: String,
    pub dependency_manifest_ref: String,
    pub benchmark_caveat_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub visible_summary: String,
    pub byte_ledger: TurboVecRealAdapterOwnerByteLedger,
    pub fork_sweep_required_before_source_pin: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub source_revision_pinned: bool,
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

// UAS: uas:turbovec-real-adapter-owner:policy
// Plane: Controller + Verification
// Residency: fail-closed source/provenance policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterOwnerApprovalPolicy {
    pub upstream_microbench_required: bool,
    pub owner_approval_required: bool,
    pub owner_approval_must_be_pending: bool,
    pub source_pin_pending_until_owner_selection: bool,
    pub quarantine_reference_only: bool,
    pub fork_sweep_required_before_source_pin: bool,
    pub clean_room_provenance_required: bool,
    pub dependency_manifest_required: bool,
    pub upstream_benchmark_caveat_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub no_product_copy: bool,
    pub no_dependency_import: bool,
    pub no_adapter_build_or_run: bool,
    pub no_route_or_context_authority: bool,
}

impl TurboVecRealAdapterOwnerApprovalPolicy {
    pub fn fail_closed() -> Self {
        Self {
            upstream_microbench_required: true,
            owner_approval_required: true,
            owner_approval_must_be_pending: true,
            source_pin_pending_until_owner_selection: true,
            quarantine_reference_only: true,
            fork_sweep_required_before_source_pin: true,
            clean_room_provenance_required: true,
            dependency_manifest_required: true,
            upstream_benchmark_caveat_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            no_product_copy: true,
            no_dependency_import: true,
            no_adapter_build_or_run: true,
            no_route_or_context_authority: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-owner:probe-set
// Plane: Controller + Verification
// Residency: deterministic owner-approval source gate set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterOwnerApprovalProbeSet {
    pub set_address: UasAddress,
    pub upstream_microbench_address: UasAddress,
    pub upstream_microbench_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecRealAdapterOwnerApprovalStatus,
    pub promotion_tier: TurboVecRealAdapterOwnerApprovalTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecRealAdapterOwnerApprovalPolicy,
    pub source_cards: Vec<TurboVecRealAdapterSourceCard>,
    pub metadata_bytes_read: u64,
    pub product_capability_promoted: bool,
}

// UAS: uas:turbovec-real-adapter-owner:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecRealAdapterOwnerApprovalMetrics {
    pub source_card_count: u64,
    pub pending_owner_approval_count: u64,
    pub pending_source_pin_count: u64,
    pub quarantine_reference_count: u64,
    pub upstream_repo_count: u64,
    pub fork_sweep_required_count: u64,
    pub visible_summary_count: u64,
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
    pub owner_approval_granted_count: u64,
    pub source_revision_pinned_count: u64,
    pub repo_fetched_or_cloned_count: u64,
    pub dependency_added_to_product_count: u64,
    pub source_copied_to_product_count: u64,
    pub adapter_built_or_run_count: u64,
    pub benchmark_laundering_count: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
}

impl TurboVecRealAdapterOwnerApprovalProbeSet {
    pub fn from_cards(
        upstream_microbench_address: UasAddress,
        mut source_cards: Vec<TurboVecRealAdapterSourceCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecRealAdapterOwnerApprovalStatus,
        promotion_tier: TurboVecRealAdapterOwnerApprovalTier,
        organs: Vec<TurboVecIndexOrgan>,
        policy: TurboVecRealAdapterOwnerApprovalPolicy,
        metadata_bytes_read: u64,
        product_capability_promoted: bool,
    ) -> Result<Self, TurboVecRealAdapterOwnerApprovalError> {
        source_cards.sort_by(|left, right| left.source_card_id.cmp(&right.source_card_id));
        validate_set_inputs(
            &upstream_microbench_address,
            &source_cards,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            &policy,
            metadata_bytes_read,
            product_capability_promoted,
        )?;
        for card in &source_cards {
            validate_card(card)?;
        }
        let set_address = deterministic_set_address(&source_cards, metadata_bytes_read);
        Ok(Self {
            set_address,
            upstream_microbench_address,
            upstream_microbench_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            policy,
            source_cards,
            metadata_bytes_read,
            product_capability_promoted,
        })
    }

    pub fn metrics(&self) -> TurboVecRealAdapterOwnerApprovalMetrics {
        let mut metrics = TurboVecRealAdapterOwnerApprovalMetrics {
            source_card_count: self.source_cards.len() as u64,
            ..TurboVecRealAdapterOwnerApprovalMetrics::default()
        };
        for card in &self.source_cards {
            if card.owner_approval_required && !card.owner_approval_granted {
                metrics.pending_owner_approval_count += 1;
            }
            if !card.source_revision_pinned {
                metrics.pending_source_pin_count += 1;
            }
            if matches!(
                card.allowed_action,
                TurboVecRealAdapterAllowedAction::QuarantineReferenceOnly
            ) {
                metrics.quarantine_reference_count += 1;
            }
            if matches!(
                card.source_kind,
                TurboVecRealAdapterSourceKind::UpstreamGithubRepo
            ) {
                metrics.upstream_repo_count += 1;
            }
            if card.fork_sweep_required_before_source_pin {
                metrics.fork_sweep_required_count += 1;
            }
            if card.visible_summary.len() >= MIN_VISIBLE_SUMMARY_BYTES {
                metrics.visible_summary_count += 1;
            }
            metrics.max_planned_quarantine_bytes = metrics
                .max_planned_quarantine_bytes
                .max(card.byte_ledger.planned_quarantine_bytes);
            metrics.fetched_repo_bytes += card.byte_ledger.fetched_repo_bytes;
            metrics.cloned_repo_bytes += card.byte_ledger.cloned_repo_bytes;
            metrics.copied_product_file_count += card.byte_ledger.copied_product_file_count;
            metrics.imported_external_crate_count += card.byte_ledger.imported_external_crate_count;
            metrics.built_external_binary_count += card.byte_ledger.built_external_binary_count;
            metrics.opened_product_index_bytes += card.byte_ledger.opened_product_index_bytes;
            metrics.model_bytes_loaded += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_model_bytes_loaded += card.byte_ledger.runtime_model_bytes_loaded;
            metrics.provider_calls_made += card.byte_ledger.provider_calls_made;
            if card.owner_approval_granted {
                metrics.owner_approval_granted_count += 1;
            }
            if card.source_revision_pinned {
                metrics.source_revision_pinned_count += 1;
            }
            if card.repo_fetched_or_cloned {
                metrics.repo_fetched_or_cloned_count += 1;
            }
            if card.dependency_added_to_product {
                metrics.dependency_added_to_product_count += 1;
            }
            if card.source_copied_to_product {
                metrics.source_copied_to_product_count += 1;
            }
            if card.adapter_built_or_run {
                metrics.adapter_built_or_run_count += 1;
            }
            if card.upstream_benchmark_claimed_as_product_proof {
                metrics.benchmark_laundering_count += 1;
            }
            if card.route_mutation_allowed {
                metrics.route_mutation_count += 1;
            }
            if card.model_context_injected {
                metrics.model_context_injection_count += 1;
            }
            if card.hidden_route_authority || card.hidden_cloud_fallback_allowed {
                metrics.hidden_authority_count += 1;
            }
        }
        metrics
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: TurboVecRealAdapterOwnerApprovalProbe validation error.
// Plane: Verification.
// Residency: Metadata-only diagnostic; no source/runtime/model bytes.
pub enum TurboVecRealAdapterOwnerApprovalError {
    BadUpstreamCursor,
    EmptySourceCards,
    TooManySourceCards(usize),
    DuplicateSourceCard(String),
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecRealAdapterOwnerApprovalStatus),
    BadPromotionTier(TurboVecRealAdapterOwnerApprovalTier),
    MetadataBudgetExceeded(u64),
    ProductPromotionAllowed,
    InvalidOrgans,
    InvalidPolicy(String),
    MissingField {
        field: &'static str,
        source_card_id: String,
    },
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    BadSourceUrl(String),
    BadLicense(String),
    BadAllowedAction(String),
    InvalidSourceCard {
        source_card_id: String,
        reason: String,
    },
    ExternalBytesTouched(String),
    HiddenAuthority(String),
    ProductOrLargeModelClaim(String),
}

impl fmt::Display for TurboVecRealAdapterOwnerApprovalError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "bad upstream quarantine microbench cursor"),
            Self::EmptySourceCards => write!(f, "real-adapter source-card set is empty"),
            Self::TooManySourceCards(count) => {
                write!(f, "too many real-adapter source cards: {count}")
            }
            Self::DuplicateSourceCard(id) => write!(f, "duplicate source card `{id}`"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad ProStatus: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad owner approval status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad owner approval tier: {tier:?}"),
            Self::MetadataBudgetExceeded(bytes) => write!(f, "metadata budget exceeded: {bytes}"),
            Self::ProductPromotionAllowed => write!(f, "set promoted product capability"),
            Self::InvalidOrgans => write!(f, "missing required organs"),
            Self::InvalidPolicy(reason) => write!(f, "invalid policy: {reason}"),
            Self::MissingField {
                field,
                source_card_id,
            } => write!(f, "source card `{source_card_id}` missing field `{field}`"),
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(
                f,
                "field `{field}` value `{value}` must start with `{expected}`"
            ),
            Self::BadSourceUrl(url) => write!(f, "bad source URL `{url}`"),
            Self::BadLicense(license) => write!(f, "bad license `{license}`"),
            Self::BadAllowedAction(id) => write!(f, "bad allowed action for `{id}`"),
            Self::InvalidSourceCard {
                source_card_id,
                reason,
            } => write!(f, "invalid source card `{source_card_id}`: {reason}"),
            Self::ExternalBytesTouched(id) => {
                write!(
                    f,
                    "source card `{id}` touched external/product/runtime bytes"
                )
            }
            Self::HiddenAuthority(id) => write!(f, "source card `{id}` allows hidden authority"),
            Self::ProductOrLargeModelClaim(id) => {
                write!(f, "source card `{id}` made a product or large-model claim")
            }
        }
    }
}

impl std::error::Error for TurboVecRealAdapterOwnerApprovalError {}

fn validate_set_inputs(
    upstream_microbench_address: &UasAddress,
    source_cards: &[TurboVecRealAdapterSourceCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecRealAdapterOwnerApprovalStatus,
    promotion_tier: &TurboVecRealAdapterOwnerApprovalTier,
    organs: &[TurboVecIndexOrgan],
    policy: &TurboVecRealAdapterOwnerApprovalPolicy,
    metadata_bytes_read: u64,
    product_capability_promoted: bool,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    if !matches!(
        upstream_microbench_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_quarantine_adapter_microbench_probe"
    ) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadUpstreamCursor);
    }
    if source_cards.is_empty() {
        return Err(TurboVecRealAdapterOwnerApprovalError::EmptySourceCards);
    }
    if source_cards.len() > MAX_SOURCE_CARDS {
        return Err(TurboVecRealAdapterOwnerApprovalError::TooManySourceCards(
            source_cards.len(),
        ));
    }
    if metadata_bytes_read > MAX_METADATA_BYTES {
        return Err(
            TurboVecRealAdapterOwnerApprovalError::MetadataBudgetExceeded(metadata_bytes_read),
        );
    }
    if product_capability_promoted {
        return Err(TurboVecRealAdapterOwnerApprovalError::ProductPromotionAllowed);
    }
    if !matches!(product_build, ProductBuild::Pro) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if !matches!(pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if !matches!(
        status,
        TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval
    ) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadStatus(*status));
    }
    if !matches!(
        promotion_tier,
        TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata
    ) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    validate_organs(organs)?;
    validate_policy(policy)?;
    let mut ids = HashSet::with_capacity(source_cards.len());
    for card in source_cards {
        if !ids.insert(card.source_card_id.clone()) {
            return Err(TurboVecRealAdapterOwnerApprovalError::DuplicateSourceCard(
                card.source_card_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_organs(
    organs: &[TurboVecIndexOrgan],
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    let organs: HashSet<TurboVecIndexOrgan> = organs.iter().copied().collect();
    for required in [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ] {
        if !organs.contains(&required) {
            return Err(TurboVecRealAdapterOwnerApprovalError::InvalidOrgans);
        }
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecRealAdapterOwnerApprovalPolicy,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    if !policy.upstream_microbench_required
        || !policy.owner_approval_required
        || !policy.owner_approval_must_be_pending
        || !policy.source_pin_pending_until_owner_selection
        || !policy.quarantine_reference_only
        || !policy.fork_sweep_required_before_source_pin
        || !policy.clean_room_provenance_required
        || !policy.dependency_manifest_required
        || !policy.upstream_benchmark_caveat_required
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.compatibility_fence_required
        || !policy.no_product_copy
        || !policy.no_dependency_import
        || !policy.no_adapter_build_or_run
        || !policy.no_route_or_context_authority
    {
        return Err(TurboVecRealAdapterOwnerApprovalError::InvalidPolicy(
            "required fail-closed policy bit missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_card(
    card: &TurboVecRealAdapterSourceCard,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    require_nonempty(&card.source_card_id, "source_card_id", &card.source_card_id)?;
    if !card.source_url.starts_with("https://github.com/") {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadSourceUrl(
            card.source_url.clone(),
        ));
    }
    if card.owner_repo.trim().is_empty() || !card.source_url.contains(&card.owner_repo) {
        return invalid_card(card, "owner_repo must match the source URL");
    }
    if card.license_id != "MIT" {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadLicense(
            card.license_id.clone(),
        ));
    }
    if !matches!(
        card.allowed_action,
        TurboVecRealAdapterAllowedAction::QuarantineReferenceOnly
    ) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadAllowedAction(
            card.source_card_id.clone(),
        ));
    }
    if !matches!(
        card.source_kind,
        TurboVecRealAdapterSourceKind::UpstreamGithubRepo
            | TurboVecRealAdapterSourceKind::ForkGithubRepo
    ) {
        return invalid_card(card, "only GitHub source cards may enter this owner gate");
    }
    if !card
        .declared_language_refs
        .iter()
        .any(|language| language == "language:rust")
        || !card
            .declared_language_refs
            .iter()
            .any(|language| language == "language:python")
    {
        return invalid_card(card, "Rust and Python language refs are required");
    }
    if card.expected_api_refs.len() < 4
        || !card
            .expected_api_refs
            .iter()
            .all(|api| api.starts_with(API_PREFIX))
    {
        return invalid_card(card, "expected API refs are missing or unprefixed");
    }
    for (field, value, prefix) in [
        (
            "owner_approval_ref",
            &card.owner_approval_ref,
            OWNER_APPROVAL_PREFIX,
        ),
        ("source_pin_ref", &card.source_pin_ref, SOURCE_PIN_PREFIX),
        (
            "quarantine_path_ref",
            &card.quarantine_path_ref,
            QUARANTINE_PATH_PREFIX,
        ),
        ("provenance_ref", &card.provenance_ref, PROVENANCE_PREFIX),
        (
            "dependency_manifest_ref",
            &card.dependency_manifest_ref,
            DEPENDENCY_PREFIX,
        ),
        (
            "benchmark_caveat_ref",
            &card.benchmark_caveat_ref,
            BENCHMARK_CAVEAT_PREFIX,
        ),
        ("rollback_ref", &card.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &card.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &card.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            &card.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
        ),
    ] {
        require_prefix(field, value, prefix)?;
    }
    if card.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return invalid_card(card, "visible summary is too short");
    }
    if !card.fork_sweep_required_before_source_pin
        || !card.owner_approval_required
        || card.owner_approval_granted
        || card.source_revision_pinned
    {
        return invalid_card(card, "owner approval and source pin must remain pending");
    }
    validate_byte_ledger(card)?;
    if card.repo_fetched_or_cloned
        || card.dependency_added_to_product
        || card.source_copied_to_product
        || card.adapter_built_or_run
    {
        return Err(TurboVecRealAdapterOwnerApprovalError::ExternalBytesTouched(
            card.source_card_id.clone(),
        ));
    }
    if card.route_mutation_allowed
        || card.model_context_injected
        || card.hidden_route_authority
        || card.hidden_cloud_fallback_allowed
    {
        return Err(TurboVecRealAdapterOwnerApprovalError::HiddenAuthority(
            card.source_card_id.clone(),
        ));
    }
    if card.product_capability_promoted
        || card.live_large_model_claimed
        || card.ssd_as_ram_claimed
        || card.upstream_benchmark_claimed_as_product_proof
    {
        return Err(
            TurboVecRealAdapterOwnerApprovalError::ProductOrLargeModelClaim(
                card.source_card_id.clone(),
            ),
        );
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &TurboVecRealAdapterSourceCard,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    if card.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES {
        return Err(
            TurboVecRealAdapterOwnerApprovalError::MetadataBudgetExceeded(
                card.byte_ledger.metadata_bytes_read,
            ),
        );
    }
    if card.byte_ledger.fetched_repo_bytes > 0
        || card.byte_ledger.cloned_repo_bytes > 0
        || card.byte_ledger.copied_product_file_count > 0
        || card.byte_ledger.imported_external_crate_count > 0
        || card.byte_ledger.built_external_binary_count > 0
        || card.byte_ledger.opened_product_index_bytes > 0
        || card.byte_ledger.model_bytes_loaded > 0
        || card.byte_ledger.runtime_model_bytes_loaded > 0
        || card.byte_ledger.provider_calls_made > 0
    {
        return Err(TurboVecRealAdapterOwnerApprovalError::ExternalBytesTouched(
            card.source_card_id.clone(),
        ));
    }
    Ok(())
}

fn invalid_card(
    card: &TurboVecRealAdapterSourceCard,
    reason: &str,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    Err(TurboVecRealAdapterOwnerApprovalError::InvalidSourceCard {
        source_card_id: card.source_card_id.clone(),
        reason: reason.to_string(),
    })
}

fn require_nonempty(
    value: &str,
    field: &'static str,
    source_card_id: &str,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    if value.trim().is_empty() {
        return Err(TurboVecRealAdapterOwnerApprovalError::MissingField {
            field,
            source_card_id: source_card_id.to_string(),
        });
    }
    Ok(())
}

fn require_prefix(
    field: &'static str,
    value: &str,
    expected: &'static str,
) -> Result<(), TurboVecRealAdapterOwnerApprovalError> {
    if !value.starts_with(expected) {
        return Err(TurboVecRealAdapterOwnerApprovalError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        });
    }
    Ok(())
}

fn deterministic_set_address(
    source_cards: &[TurboVecRealAdapterSourceCard],
    metadata_bytes_read: u64,
) -> UasAddress {
    let mut parts = Vec::with_capacity(source_cards.len() + 1);
    parts.push(format!("metadata={metadata_bytes_read}"));
    for card in source_cards {
        parts.push(format!(
            "{}:{}:{}:{}",
            card.source_card_id,
            card.source_url,
            card.owner_repo,
            card.byte_ledger.planned_quarantine_bytes
        ));
    }
    parts.sort();
    let digest = sha256_hex(parts.join("|").as_bytes());
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_owner_approval_probe".to_string()),
        digest.as_bytes(),
        1_779_040_800_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_quarantine_adapter_microbench_probe".to_string()),
            b"upstream",
            1_779_040_800_000,
        )
    }

    fn card() -> TurboVecRealAdapterSourceCard {
        TurboVecRealAdapterSourceCard {
            source_card_id: "ryancodrai_turbovec_upstream_pending".to_string(),
            source_kind: TurboVecRealAdapterSourceKind::UpstreamGithubRepo,
            source_url: "https://github.com/RyanCodrai/turbovec".to_string(),
            owner_repo: "RyanCodrai/turbovec".to_string(),
            license_id: "MIT".to_string(),
            declared_language_refs: vec!["language:rust".to_string(), "language:python".to_string()],
            expected_api_refs: vec![
                "api:turbovec:stable_external_ids".to_string(),
                "api:turbovec:allowlist_search".to_string(),
                "api:turbovec:persistence".to_string(),
                "api:turbovec:python_bindings".to_string(),
            ],
            allowed_action: TurboVecRealAdapterAllowedAction::QuarantineReferenceOnly,
            owner_approval_ref: "owner_approval:pending:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
            source_pin_ref: "source_pin:pending_owner_selection:ryancodrai_turbovec".to_string(),
            quarantine_path_ref: "quarantine_path:pending:/Users/jojo/Downloads/Epistemos/.research-quarantine/turbovec".to_string(),
            provenance_ref: "provenance:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
            dependency_manifest_ref: "dependency_manifest:quarantine-only:turbovec".to_string(),
            benchmark_caveat_ref: "benchmark_caveat:upstream-not-product-proof:turbovec".to_string(),
            rollback_ref: "rollback:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
            run_event_log_ref: "run_event_log:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
            answer_packet_ref: "answer_packet:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
            compatibility_fence_ref: "compat:turbovec-real-adapter:ryancodrai_turbovec".to_string(),
            visible_summary: "TurboVec upstream is recorded only as a future quarantine reference. Owner approval, source pinning, fork sweep, dependency isolation, rollback, RunEventLog, AnswerPacket, and clean-room provenance must pass before any bytes are fetched.".to_string(),
            byte_ledger: TurboVecRealAdapterOwnerByteLedger::pending(42_000, 8 * 1024 * 1024),
            fork_sweep_required_before_source_pin: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            source_revision_pinned: false,
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

    fn set(
        cards: Vec<TurboVecRealAdapterSourceCard>,
    ) -> Result<TurboVecRealAdapterOwnerApprovalProbeSet, TurboVecRealAdapterOwnerApprovalError>
    {
        TurboVecRealAdapterOwnerApprovalProbeSet::from_cards(
            upstream(),
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterOwnerApprovalStatus::PendingOwnerApproval,
            TurboVecRealAdapterOwnerApprovalTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            TurboVecRealAdapterOwnerApprovalPolicy::fail_closed(),
            48_000,
            false,
        )
    }

    #[test]
    fn accepts_pending_owner_approval_source_card() {
        let first = set(vec![card()]).unwrap();
        let second = set(vec![card()]).unwrap();
        assert_eq!(first.set_address, second.set_address);
        let metrics = first.metrics();
        assert_eq!(metrics.source_card_count, 1);
        assert_eq!(metrics.pending_owner_approval_count, 1);
        assert_eq!(metrics.quarantine_reference_count, 1);
    }

    #[test]
    fn rejects_approval_or_source_pin_before_later_witness() {
        let mut bad = card();
        bad.owner_approval_granted = true;
        assert!(set(vec![bad]).is_err());

        let mut bad = card();
        bad.source_revision_pinned = true;
        assert!(set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_external_bytes_or_product_dependency() {
        let mut bad = card();
        bad.byte_ledger.cloned_repo_bytes = 1;
        assert!(set(vec![bad]).is_err());

        let mut bad = card();
        bad.dependency_added_to_product = true;
        assert!(set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_hidden_authority_and_benchmark_laundering() {
        let mut bad = card();
        bad.route_mutation_allowed = true;
        assert!(set(vec![bad]).is_err());

        let mut bad = card();
        bad.upstream_benchmark_claimed_as_product_proof = true;
        assert!(set(vec![bad]).is_err());
    }
}
