//! MoE active-parameters memory truth ledger.
//!
//! This primitive keeps sparse/MoE large-model ambition honest: active
//! parameters are compute evidence, not resident-memory proof. It consumes the
//! hardware-tiered model catalog and requires full-weight, KV, expert
//! residency, router/runtime, app-headroom, rollback, and visible-packet
//! ledgers before MoE rows can influence routing.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogFormat, ModelCatalogRuntimeLane,
    ProStatus, ProductBuild, UasAddress, UasKind,
};

pub const MOE_ACTIVE_PARAMS_MEMORY_TRUTH_CURSOR: &str = "moe_active_params_memory_truth";
pub const MOE_ACTIVE_PARAMS_MEMORY_TRUTH_NEXT_CURSOR: &str = "exotic_quant_quarantine_route_card";

const UPSTREAM_HARDWARE_CATALOG_PREFIX: &str =
    "artifact:falsifiers/hardware_tiered_model_catalog_source_card/result.json";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPAT_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const PROVENANCE_PREFIX: &str = "provenance:";
const HARDWARE_PREFIX: &str = "hardware:";
const ABSTENTION_PREFIX: &str = "abstention:";
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAC_16_18_HEADROOM_BYTES: u64 = 4 * 1024 * 1024 * 1024;

const ACCEPTED_MOE_MODEL_IDS: &[&str] = &[
    "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF",
    "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
];

// UAS: uas:moe-active-params-memory-truth:residency-policy
// Plane: Assembly + Controller
// Residency: describes proof obligations before any MoE expert can be hot.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MoeExpertResidencyPolicy {
    FullWeightsResidentRequired,
    ExpertLeaseRequired,
    ColdExpertPrefetchRequired,
    RouteAbstainsUntilRuntimeProof,
}

// UAS: uas:moe-active-params-memory-truth:byte-ledger
// Plane: Verification
// Residency: byte accounting is metadata-only; loaded bytes must stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MoeMemoryByteLedger {
    pub metadata_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub full_weight_artifact_bytes_declared: u64,
    pub active_compute_params_declared: u64,
    pub kv_cache_budget_bytes: u64,
    pub expert_residency_lease_bytes: u64,
    pub router_workspace_bytes: u64,
    pub runtime_workspace_bytes: u64,
    pub app_headroom_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl MoeMemoryByteLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn metadata_only(
        metadata_bytes_read: u64,
        local_research_bytes_read: u64,
        full_weight_artifact_bytes_declared: u64,
        active_compute_params_declared: u64,
        kv_cache_budget_bytes: u64,
        expert_residency_lease_bytes: u64,
        router_workspace_bytes: u64,
        runtime_workspace_bytes: u64,
        app_headroom_bytes: u64,
    ) -> Self {
        Self {
            metadata_bytes_read,
            local_research_bytes_read,
            full_weight_artifact_bytes_declared,
            active_compute_params_declared,
            kv_cache_budget_bytes,
            expert_residency_lease_bytes,
            router_workspace_bytes,
            runtime_workspace_bytes,
            app_headroom_bytes,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            source_tree_bytes_read: 0,
            product_files_copied: 0,
            command_executions: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:moe-active-params-memory-truth:proof-refs
// Plane: Verification
// Residency: visible proof handles required before downstream route use.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MoeMemoryProofRefs {
    pub upstream_catalog_ref: String,
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_policy_ref: String,
    pub provenance_ref: String,
    pub hardware_tier_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:moe-active-params-memory-truth:card
// Plane: State + Assembly + Controller + Verification
// Residency: MoE memory ledger row; never product or hidden route authority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MoeActiveParamsMemoryTruthCard {
    pub card_id: String,
    pub model_id: String,
    pub source_sha: String,
    pub hardware_tier: HardwareTier,
    pub format: ModelCatalogFormat,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub total_params_declared: u64,
    pub active_params_declared: u64,
    pub routed_expert_count_total: u64,
    pub active_experts_per_token: u64,
    pub shared_expert_count: u64,
    pub expert_residency_policy: MoeExpertResidencyPolicy,
    pub active_compute_not_memory_fit: bool,
    pub full_weight_bytes_required: bool,
    pub kv_budget_required: bool,
    pub expert_residency_lease_required: bool,
    pub router_overhead_required: bool,
    pub app_headroom_required: bool,
    pub source_card_required: bool,
    pub runtime_deferred: bool,
    pub route_authority_denied: bool,
    pub product_route_enabled: bool,
    pub product_default_model_claim: bool,
    pub product_winner_claim: bool,
    pub active_params_as_fit_claim: bool,
    pub fits_target_hardware_claim: bool,
    pub server_benchmark_as_local_fit_proof: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_l3_promotion_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub apex_provenance_required: bool,
    pub provenance_gate_ref: Option<String>,
    pub headroom_caveat_ref: Option<String>,
    pub byte_ledger: MoeMemoryByteLedger,
    pub proof_refs: MoeMemoryProofRefs,
}

// UAS: uas:moe-active-params-memory-truth:ledger
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only MoE truth ledger for future gated runtime proofs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MoeActiveParamsMemoryTruthLedger {
    pub ledger_address: UasAddress,
    pub upstream_catalog_artifact_ref: String,
    pub cards: Vec<MoeActiveParamsMemoryTruthCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub active_params_compute_only: bool,
    pub product_promotion_blocked: bool,
    pub route_authority_blocked: bool,
    pub runtime_deferred: bool,
    pub no_default_model_or_winner: bool,
    pub no_hidden_authority: bool,
}

// UAS: uas:moe-active-params-memory-truth:metrics
// Plane: Verification
// Residency: derived counters for artifact axes and red-fixture proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MoeActiveParamsMemoryTruthMetrics {
    pub card_count: u64,
    pub hardware_tier_count: u64,
    pub runtime_lane_count: u64,
    pub format_count: u64,
    pub active_compute_only_count: u64,
    pub full_weight_ledger_count: u64,
    pub kv_budget_count: u64,
    pub expert_residency_lease_count: u64,
    pub router_workspace_count: u64,
    pub app_headroom_count: u64,
    pub apex_provenance_count: u64,
    pub abstention_ref_count: u64,
    pub total_params_declared_sum: u64,
    pub active_params_declared_sum: u64,
    pub full_weight_artifact_bytes_declared_sum: u64,
    pub kv_cache_budget_bytes_sum: u64,
    pub expert_residency_lease_bytes_sum: u64,
    pub router_workspace_bytes_sum: u64,
    pub runtime_workspace_bytes_sum: u64,
    pub app_headroom_bytes_sum: u64,
    pub metadata_bytes_read: u64,
    pub local_research_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl MoeActiveParamsMemoryTruthLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_catalog_artifact_ref: impl Into<String>,
        mut cards: Vec<MoeActiveParamsMemoryTruthCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        active_params_compute_only: bool,
        product_promotion_blocked: bool,
        route_authority_blocked: bool,
        runtime_deferred: bool,
        no_default_model_or_winner: bool,
        no_hidden_authority: bool,
        created_at_ms: u64,
    ) -> Result<Self, MoeActiveParamsMemoryTruthError> {
        let upstream_catalog_artifact_ref = upstream_catalog_artifact_ref.into();
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        validate_ledger_inputs(
            &upstream_catalog_artifact_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            active_params_compute_only,
            product_promotion_blocked,
            route_authority_blocked,
            runtime_deferred,
            no_default_model_or_winner,
            no_hidden_authority,
        )?;
        let ledger_address = ledger_address(
            &upstream_catalog_artifact_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            active_params_compute_only,
            product_promotion_blocked,
            route_authority_blocked,
            runtime_deferred,
            no_default_model_or_winner,
            no_hidden_authority,
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_catalog_artifact_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            active_params_compute_only,
            product_promotion_blocked,
            route_authority_blocked,
            runtime_deferred,
            no_default_model_or_winner,
            no_hidden_authority,
        })
    }

    pub fn metrics(&self) -> MoeActiveParamsMemoryTruthMetrics {
        let mut hardware_tiers = BTreeSet::new();
        let mut runtime_lanes = BTreeSet::new();
        let mut formats = BTreeSet::new();
        for card in &self.cards {
            hardware_tiers.insert(card.hardware_tier);
            runtime_lanes.insert(card.runtime_lane);
            formats.insert(card.format);
        }
        MoeActiveParamsMemoryTruthMetrics {
            card_count: self.cards.len() as u64,
            hardware_tier_count: hardware_tiers.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            format_count: formats.len() as u64,
            active_compute_only_count: self
                .cards
                .iter()
                .filter(|card| card.active_compute_not_memory_fit)
                .count() as u64,
            full_weight_ledger_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.full_weight_bytes_required
                        && card.byte_ledger.full_weight_artifact_bytes_declared > 0
                })
                .count() as u64,
            kv_budget_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.kv_budget_required && card.byte_ledger.kv_cache_budget_bytes > 0
                })
                .count() as u64,
            expert_residency_lease_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.expert_residency_lease_required
                        && card.byte_ledger.expert_residency_lease_bytes > 0
                })
                .count() as u64,
            router_workspace_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.router_overhead_required && card.byte_ledger.router_workspace_bytes > 0
                })
                .count() as u64,
            app_headroom_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.app_headroom_required && card.byte_ledger.app_headroom_bytes > 0
                })
                .count() as u64,
            apex_provenance_count: self
                .cards
                .iter()
                .filter(|card| card.apex_provenance_required)
                .count() as u64,
            abstention_ref_count: self
                .cards
                .iter()
                .filter(|card| {
                    card.proof_refs
                        .abstention_ref
                        .starts_with(ABSTENTION_PREFIX)
                })
                .count() as u64,
            total_params_declared_sum: self
                .cards
                .iter()
                .map(|card| card.total_params_declared)
                .sum(),
            active_params_declared_sum: self
                .cards
                .iter()
                .map(|card| card.active_params_declared)
                .sum(),
            full_weight_artifact_bytes_declared_sum: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.full_weight_artifact_bytes_declared)
                .sum(),
            kv_cache_budget_bytes_sum: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.kv_cache_budget_bytes)
                .sum(),
            expert_residency_lease_bytes_sum: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.expert_residency_lease_bytes)
                .sum(),
            router_workspace_bytes_sum: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.router_workspace_bytes)
                .sum(),
            runtime_workspace_bytes_sum: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.runtime_workspace_bytes)
                .sum(),
            app_headroom_bytes_sum: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.app_headroom_bytes)
                .sum(),
            metadata_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.metadata_bytes_read)
                .sum(),
            local_research_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.local_research_bytes_read)
                .sum(),
            model_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.model_bytes_loaded)
                .sum(),
            runtime_bytes_loaded: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.runtime_bytes_loaded)
                .sum(),
            provider_calls_made: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.provider_calls_made)
                .sum(),
            source_tree_bytes_read: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.source_tree_bytes_read)
                .sum(),
            product_files_copied: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.product_files_copied)
                .sum(),
            command_executions: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.command_executions)
                .sum(),
            benchmark_runs: self
                .cards
                .iter()
                .map(|card| card.byte_ledger.benchmark_runs)
                .sum(),
        }
    }
}

// UAS: uas:moe-active-params-memory-truth:error
// Plane: Verification
// Residency: fail-closed reason for rejecting unsafe MoE memory claims.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MoeActiveParamsMemoryTruthError {
    BadUpstreamCatalogRef,
    EmptyLedger,
    MetadataBudgetExceeded,
    MissingLayerSeparation,
    ActiveParamsNotComputeOnly,
    ProductPromotionFromResearch(String),
    HiddenAuthorityNotBlocked,
    DuplicateCardId(String),
    DuplicateModelId(String),
    UnknownOrNonMoeModelId(String),
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    BadSourceSha(String),
    BadProofRefPrefix {
        field: &'static str,
        value: String,
        prefix: &'static str,
    },
    ActiveParamsAsFitClaim(String),
    ActiveParamsNotLessThanTotal(String),
    MissingFullWeightBytes(String),
    MissingKvBudget(String),
    MissingExpertResidencyLease(String),
    MissingRouterWorkspace(String),
    MissingRuntimeWorkspace(String),
    MissingAppHeadroom(String),
    Mac16To18MoeOverclaim(String),
    ApexWithoutProvenanceGate(String),
    ServerBenchmarkAsLocalProof(String),
    NonzeroModelBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    SourceTreeBytesRead(String),
    ProductFileCopied(String),
    CommandExecuted(String),
    BenchmarkRun(String),
    ProductDefaultClaim(String),
    ProductWinnerClaim(String),
    ProductRouteEnabled(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    L2L3PromotionClaim(String),
    LiveDense70BClaim(String),
    SsdAsRamClaim(String),
}

impl fmt::Display for MoeActiveParamsMemoryTruthError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCatalogRef => {
                write!(f, "upstream hardware catalog artifact ref is invalid")
            }
            Self::EmptyLedger => write!(f, "MoE memory truth ledger cannot be empty"),
            Self::MetadataBudgetExceeded => write!(f, "MoE memory truth metadata budget exceeded"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation must be explicit"),
            Self::ActiveParamsNotComputeOnly => {
                write!(
                    f,
                    "active params must be marked compute-only, not memory fit"
                )
            }
            Self::ProductPromotionFromResearch(id) => {
                write!(
                    f,
                    "MoE memory truth card `{id}` attempted product promotion"
                )
            }
            Self::HiddenAuthorityNotBlocked => write!(f, "hidden route authority must be blocked"),
            Self::DuplicateCardId(id) => write!(f, "duplicate MoE memory truth card id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate MoE memory truth model id `{id}`"),
            Self::UnknownOrNonMoeModelId(id) => {
                write!(f, "model `{id}` is not an accepted MoE catalog row")
            }
            Self::MissingField(field) => write!(f, "field `{field}` cannot be empty"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains control characters")
            }
            Self::BadSourceSha(id) => write!(f, "card `{id}` has invalid source SHA"),
            Self::BadProofRefPrefix {
                field,
                value,
                prefix,
            } => write!(
                f,
                "proof ref `{field}` value `{value}` must start with `{prefix}`"
            ),
            Self::ActiveParamsAsFitClaim(id) => {
                write!(f, "card `{id}` treats active params as memory-fit proof")
            }
            Self::ActiveParamsNotLessThanTotal(id) => {
                write!(
                    f,
                    "card `{id}` active params must be smaller than total params"
                )
            }
            Self::MissingFullWeightBytes(id) => write!(f, "card `{id}` missing full-weight bytes"),
            Self::MissingKvBudget(id) => write!(f, "card `{id}` missing KV cache budget"),
            Self::MissingExpertResidencyLease(id) => {
                write!(f, "card `{id}` missing expert residency lease")
            }
            Self::MissingRouterWorkspace(id) => write!(f, "card `{id}` missing router workspace"),
            Self::MissingRuntimeWorkspace(id) => write!(f, "card `{id}` missing runtime workspace"),
            Self::MissingAppHeadroom(id) => write!(f, "card `{id}` missing app headroom"),
            Self::Mac16To18MoeOverclaim(id) => {
                write!(f, "card `{id}` overclaims MoE fit on 16-18 GB Mac tier")
            }
            Self::ApexWithoutProvenanceGate(id) => {
                write!(f, "card `{id}` APEX format lacks provenance gate")
            }
            Self::ServerBenchmarkAsLocalProof(id) => {
                write!(f, "card `{id}` treats server benchmark as local fit proof")
            }
            Self::NonzeroModelBytes(id) => write!(f, "card `{id}` loaded model bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "card `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "card `{id}` made provider calls"),
            Self::SourceTreeBytesRead(id) => write!(f, "card `{id}` read source-tree bytes"),
            Self::ProductFileCopied(id) => write!(f, "card `{id}` copied product files"),
            Self::CommandExecuted(id) => write!(f, "card `{id}` executed commands"),
            Self::BenchmarkRun(id) => write!(f, "card `{id}` ran benchmarks"),
            Self::ProductDefaultClaim(id) => write!(f, "card `{id}` claims product default model"),
            Self::ProductWinnerClaim(id) => write!(f, "card `{id}` claims product winner"),
            Self::ProductRouteEnabled(id) => write!(f, "card `{id}` enables product route"),
            Self::HiddenRouteAuthority(id) => write!(f, "card `{id}` has hidden route authority"),
            Self::HiddenCloudFallback(id) => write!(f, "card `{id}` has hidden cloud fallback"),
            Self::L2L3PromotionClaim(id) => write!(f, "card `{id}` claims L2/L3 promotion"),
            Self::LiveDense70BClaim(id) => write!(f, "card `{id}` claims live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "card `{id}` claims SSD as RAM"),
        }
    }
}

impl std::error::Error for MoeActiveParamsMemoryTruthError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger_inputs(
    upstream_ref: &str,
    cards: &[MoeActiveParamsMemoryTruthCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    active_params_compute_only: bool,
    product_promotion_blocked: bool,
    route_authority_blocked: bool,
    runtime_deferred: bool,
    no_default_model_or_winner: bool,
    no_hidden_authority: bool,
) -> Result<(), MoeActiveParamsMemoryTruthError> {
    if !upstream_ref.starts_with(UPSTREAM_HARDWARE_CATALOG_PREFIX) {
        return Err(MoeActiveParamsMemoryTruthError::BadUpstreamCatalogRef);
    }
    if cards.is_empty() {
        return Err(MoeActiveParamsMemoryTruthError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(MoeActiveParamsMemoryTruthError::MetadataBudgetExceeded);
    }
    if product_build != &ProductBuild::Pro
        || pro_status == &ProStatus::Live
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
    {
        return Err(
            MoeActiveParamsMemoryTruthError::ProductPromotionFromResearch("ledger".to_string()),
        );
    }
    if !l1_l2_l3_separated {
        return Err(MoeActiveParamsMemoryTruthError::MissingLayerSeparation);
    }
    if !active_params_compute_only {
        return Err(MoeActiveParamsMemoryTruthError::ActiveParamsNotComputeOnly);
    }
    if !product_promotion_blocked || !runtime_deferred || !no_default_model_or_winner {
        return Err(
            MoeActiveParamsMemoryTruthError::ProductPromotionFromResearch("ledger".to_string()),
        );
    }
    if !route_authority_blocked || !no_hidden_authority {
        return Err(MoeActiveParamsMemoryTruthError::HiddenAuthorityNotBlocked);
    }

    let mut seen_card_ids = HashSet::with_capacity(cards.len());
    let mut seen_model_ids = HashSet::with_capacity(cards.len());
    for card in cards {
        validate_card(card)?;
        if !seen_card_ids.insert(card.card_id.as_str()) {
            return Err(MoeActiveParamsMemoryTruthError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        if !seen_model_ids.insert(card.model_id.as_str()) {
            return Err(MoeActiveParamsMemoryTruthError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_card(
    card: &MoeActiveParamsMemoryTruthCard,
) -> Result<(), MoeActiveParamsMemoryTruthError> {
    validate_text("card_id", &card.card_id)?;
    validate_text("model_id", &card.model_id)?;
    validate_text("source_sha", &card.source_sha)?;
    if !ACCEPTED_MOE_MODEL_IDS.contains(&card.model_id.as_str()) {
        return Err(MoeActiveParamsMemoryTruthError::UnknownOrNonMoeModelId(
            card.model_id.clone(),
        ));
    }
    if !is_lower_hex_sha(&card.source_sha) {
        return Err(MoeActiveParamsMemoryTruthError::BadSourceSha(
            card.card_id.clone(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status == ProStatus::Live
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
    {
        return Err(
            MoeActiveParamsMemoryTruthError::ProductPromotionFromResearch(card.card_id.clone()),
        );
    }
    validate_compute_vs_residency(card)?;
    validate_byte_ledger(card)?;
    validate_claim_boundaries(card)?;
    validate_proof_refs(card)?;
    Ok(())
}

fn validate_compute_vs_residency(
    card: &MoeActiveParamsMemoryTruthCard,
) -> Result<(), MoeActiveParamsMemoryTruthError> {
    if !card.active_compute_not_memory_fit || card.active_params_as_fit_claim {
        return Err(MoeActiveParamsMemoryTruthError::ActiveParamsAsFitClaim(
            card.card_id.clone(),
        ));
    }
    if card.total_params_declared == 0
        || card.active_params_declared == 0
        || card.active_params_declared >= card.total_params_declared
    {
        return Err(
            MoeActiveParamsMemoryTruthError::ActiveParamsNotLessThanTotal(card.card_id.clone()),
        );
    }
    if card.routed_expert_count_total <= card.active_experts_per_token
        || card.active_experts_per_token == 0
    {
        return Err(MoeActiveParamsMemoryTruthError::ActiveParamsAsFitClaim(
            card.card_id.clone(),
        ));
    }
    if card.hardware_tier == HardwareTier::Mac16To18Gb {
        return Err(MoeActiveParamsMemoryTruthError::Mac16To18MoeOverclaim(
            card.card_id.clone(),
        ));
    }
    if card.format == ModelCatalogFormat::ApexGguf
        && (!card.apex_provenance_required
            || card
                .provenance_gate_ref
                .as_deref()
                .is_none_or(|value| !value.starts_with(PROVENANCE_PREFIX)))
    {
        return Err(MoeActiveParamsMemoryTruthError::ApexWithoutProvenanceGate(
            card.card_id.clone(),
        ));
    }
    if card.server_benchmark_as_local_fit_proof {
        return Err(
            MoeActiveParamsMemoryTruthError::ServerBenchmarkAsLocalProof(card.card_id.clone()),
        );
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &MoeActiveParamsMemoryTruthCard,
) -> Result<(), MoeActiveParamsMemoryTruthError> {
    let ledger = &card.byte_ledger;
    if ledger.metadata_bytes_read == 0
        || ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || ledger.local_research_bytes_read == 0
    {
        return Err(MoeActiveParamsMemoryTruthError::MetadataBudgetExceeded);
    }
    if !card.full_weight_bytes_required || ledger.full_weight_artifact_bytes_declared == 0 {
        return Err(MoeActiveParamsMemoryTruthError::MissingFullWeightBytes(
            card.card_id.clone(),
        ));
    }
    if !card.kv_budget_required || ledger.kv_cache_budget_bytes == 0 {
        return Err(MoeActiveParamsMemoryTruthError::MissingKvBudget(
            card.card_id.clone(),
        ));
    }
    if !card.expert_residency_lease_required || ledger.expert_residency_lease_bytes == 0 {
        return Err(
            MoeActiveParamsMemoryTruthError::MissingExpertResidencyLease(card.card_id.clone()),
        );
    }
    if !card.router_overhead_required || ledger.router_workspace_bytes == 0 {
        return Err(MoeActiveParamsMemoryTruthError::MissingRouterWorkspace(
            card.card_id.clone(),
        ));
    }
    if ledger.runtime_workspace_bytes == 0 {
        return Err(MoeActiveParamsMemoryTruthError::MissingRuntimeWorkspace(
            card.card_id.clone(),
        ));
    }
    if !card.app_headroom_required || ledger.app_headroom_bytes < MAC_16_18_HEADROOM_BYTES {
        return Err(MoeActiveParamsMemoryTruthError::MissingAppHeadroom(
            card.card_id.clone(),
        ));
    }
    if ledger.model_bytes_loaded > 0 {
        return Err(MoeActiveParamsMemoryTruthError::NonzeroModelBytes(
            card.card_id.clone(),
        ));
    }
    if ledger.runtime_bytes_loaded > 0 {
        return Err(MoeActiveParamsMemoryTruthError::NonzeroRuntimeBytes(
            card.card_id.clone(),
        ));
    }
    if ledger.provider_calls_made > 0 {
        return Err(MoeActiveParamsMemoryTruthError::ProviderCallMade(
            card.card_id.clone(),
        ));
    }
    if ledger.source_tree_bytes_read > 0 {
        return Err(MoeActiveParamsMemoryTruthError::SourceTreeBytesRead(
            card.card_id.clone(),
        ));
    }
    if ledger.product_files_copied > 0 {
        return Err(MoeActiveParamsMemoryTruthError::ProductFileCopied(
            card.card_id.clone(),
        ));
    }
    if ledger.command_executions > 0 {
        return Err(MoeActiveParamsMemoryTruthError::CommandExecuted(
            card.card_id.clone(),
        ));
    }
    if ledger.benchmark_runs > 0 {
        return Err(MoeActiveParamsMemoryTruthError::BenchmarkRun(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_claim_boundaries(
    card: &MoeActiveParamsMemoryTruthCard,
) -> Result<(), MoeActiveParamsMemoryTruthError> {
    if !card.source_card_required || !card.runtime_deferred || !card.route_authority_denied {
        return Err(
            MoeActiveParamsMemoryTruthError::ProductPromotionFromResearch(card.card_id.clone()),
        );
    }
    if card.product_default_model_claim {
        return Err(MoeActiveParamsMemoryTruthError::ProductDefaultClaim(
            card.card_id.clone(),
        ));
    }
    if card.product_winner_claim {
        return Err(MoeActiveParamsMemoryTruthError::ProductWinnerClaim(
            card.card_id.clone(),
        ));
    }
    if card.product_route_enabled {
        return Err(MoeActiveParamsMemoryTruthError::ProductRouteEnabled(
            card.card_id.clone(),
        ));
    }
    if card.fits_target_hardware_claim {
        return Err(MoeActiveParamsMemoryTruthError::ActiveParamsAsFitClaim(
            card.card_id.clone(),
        ));
    }
    if card.hidden_route_authority {
        return Err(MoeActiveParamsMemoryTruthError::HiddenRouteAuthority(
            card.card_id.clone(),
        ));
    }
    if card.hidden_cloud_fallback {
        return Err(MoeActiveParamsMemoryTruthError::HiddenCloudFallback(
            card.card_id.clone(),
        ));
    }
    if card.l2_l3_promotion_claim {
        return Err(MoeActiveParamsMemoryTruthError::L2L3PromotionClaim(
            card.card_id.clone(),
        ));
    }
    if card.live_dense_70b_claim {
        return Err(MoeActiveParamsMemoryTruthError::LiveDense70BClaim(
            card.card_id.clone(),
        ));
    }
    if card.ssd_as_ram_claim {
        return Err(MoeActiveParamsMemoryTruthError::SsdAsRamClaim(
            card.card_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    card: &MoeActiveParamsMemoryTruthCard,
) -> Result<(), MoeActiveParamsMemoryTruthError> {
    let proof = &card.proof_refs;
    for (field, value, prefix) in [
        (
            "upstream_catalog_ref",
            proof.upstream_catalog_ref.as_str(),
            UPSTREAM_HARDWARE_CATALOG_PREFIX,
        ),
        (
            "falsifier_ref",
            proof.falsifier_ref.as_str(),
            FALSIFIER_PREFIX,
        ),
        ("rollback_ref", proof.rollback_ref.as_str(), ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            proof.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof.compatibility_fence_ref.as_str(),
            COMPAT_PREFIX,
        ),
        (
            "privacy_policy_ref",
            proof.privacy_policy_ref.as_str(),
            PRIVACY_PREFIX,
        ),
        (
            "provenance_ref",
            proof.provenance_ref.as_str(),
            PROVENANCE_PREFIX,
        ),
        (
            "hardware_tier_ref",
            proof.hardware_tier_ref.as_str(),
            HARDWARE_PREFIX,
        ),
        (
            "abstention_ref",
            proof.abstention_ref.as_str(),
            ABSTENTION_PREFIX,
        ),
    ] {
        validate_text(field, value)?;
        if !value.starts_with(prefix) {
            return Err(MoeActiveParamsMemoryTruthError::BadProofRefPrefix {
                field,
                value: value.to_string(),
                prefix,
            });
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn ledger_address(
    upstream_ref: &str,
    cards: &[MoeActiveParamsMemoryTruthCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    active_params_compute_only: bool,
    product_promotion_blocked: bool,
    route_authority_blocked: bool,
    runtime_deferred: bool,
    no_default_model_or_winner: bool,
    no_hidden_authority: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(MOE_ACTIVE_PARAMS_MEMORY_TRUTH_CURSOR);
    preimage.push('\n');
    preimage.push_str(upstream_ref);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{product_build:?}\n{pro_status:?}\n{promotion_tier:?}\n{metadata_bytes}\n"
    ));
    for flag in [
        l1_l2_l3_separated,
        active_params_compute_only,
        product_promotion_blocked,
        route_authority_blocked,
        runtime_deferred,
        no_default_model_or_winner,
        no_hidden_authority,
    ] {
        preimage.push_str(if flag { "true" } else { "false" });
        preimage.push('\n');
    }
    for card in cards {
        push_card_preimage(&mut preimage, card);
    }
    UasAddress::new(
        UasKind::Other(MOE_ACTIVE_PARAMS_MEMORY_TRUTH_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_card_preimage(preimage: &mut String, card: &MoeActiveParamsMemoryTruthCard) {
    preimage.push_str(&card.card_id);
    preimage.push('|');
    preimage.push_str(&card.model_id);
    preimage.push('|');
    preimage.push_str(&card.source_sha);
    preimage.push('|');
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
        card.hardware_tier,
        card.format,
        card.runtime_lane,
        card.total_params_declared,
        card.active_params_declared,
        card.routed_expert_count_total,
        card.active_experts_per_token,
        card.shared_expert_count,
        card.byte_ledger.full_weight_artifact_bytes_declared,
        card.byte_ledger.kv_cache_budget_bytes,
        card.byte_ledger.expert_residency_lease_bytes,
        card.byte_ledger.router_workspace_bytes,
        card.byte_ledger.runtime_workspace_bytes,
        card.byte_ledger.app_headroom_bytes,
        card.active_compute_not_memory_fit,
        card.active_params_as_fit_claim,
        card.fits_target_hardware_claim,
        card.hidden_route_authority,
        card.hidden_cloud_fallback,
        card.l2_l3_promotion_claim,
    ));
}

fn validate_text(field: &'static str, value: &str) -> Result<(), MoeActiveParamsMemoryTruthError> {
    if value.is_empty() {
        return Err(MoeActiveParamsMemoryTruthError::MissingField(field));
    }
    if value.trim() != value {
        return Err(MoeActiveParamsMemoryTruthError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(MoeActiveParamsMemoryTruthError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn is_lower_hex_sha(value: &str) -> bool {
    value.len() == 40
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str =
        "artifact:falsifiers/hardware_tiered_model_catalog_source_card/result.json#F-HardwareTieredModelCatalog-SourceCard";
    const CREATED_AT_MS: u64 = 1_779_230_000_000;

    fn build_ledger(
        cards: Vec<MoeActiveParamsMemoryTruthCard>,
    ) -> Result<MoeActiveParamsMemoryTruthLedger, MoeActiveParamsMemoryTruthError> {
        MoeActiveParamsMemoryTruthLedger::new(
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            180_000,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn reject_cards(mutate: impl FnOnce(&mut Vec<MoeActiveParamsMemoryTruthCard>)) -> bool {
        let mut cards = fixture_cards();
        mutate(&mut cards);
        build_ledger(cards).is_err()
    }

    fn reject_card(
        card_id: &str,
        mutate: impl FnOnce(&mut MoeActiveParamsMemoryTruthCard),
    ) -> bool {
        let mut cards = fixture_cards();
        if let Some(card) = cards.iter_mut().find(|card| card.card_id == card_id) {
            mutate(card);
        }
        build_ledger(cards).is_err()
    }

    fn fixture_cards() -> Vec<MoeActiveParamsMemoryTruthCard> {
        vec![
            card(
                "qwopus_moe_35b_a3b_gguf",
                "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF",
                "19f9e6fa8065b2f1e42aaa16d4adafac1e9a9a01",
                ModelCatalogFormat::Gguf,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                false,
            ),
            card(
                "qwopus_moe_35b_a3b_apex_gguf",
                "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
                "724281f1f6af99158ae89cba4196f39ccc4e039e",
                ModelCatalogFormat::ApexGguf,
                ModelCatalogRuntimeLane::NoRuntime,
                true,
            ),
        ]
    }

    fn card(
        card_id: &str,
        model_id: &str,
        source_sha: &str,
        format: ModelCatalogFormat,
        runtime_lane: ModelCatalogRuntimeLane,
        apex: bool,
    ) -> MoeActiveParamsMemoryTruthCard {
        MoeActiveParamsMemoryTruthCard {
            card_id: card_id.to_string(),
            model_id: model_id.to_string(),
            source_sha: source_sha.to_string(),
            hardware_tier: HardwareTier::Mac24To32Gb,
            format,
            runtime_lane,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            total_params_declared: 35_000_000_000,
            active_params_declared: 3_000_000_000,
            routed_expert_count_total: 256,
            active_experts_per_token: 8,
            shared_expert_count: 1,
            expert_residency_policy: MoeExpertResidencyPolicy::RouteAbstainsUntilRuntimeProof,
            active_compute_not_memory_fit: true,
            full_weight_bytes_required: true,
            kv_budget_required: true,
            expert_residency_lease_required: true,
            router_overhead_required: true,
            app_headroom_required: true,
            source_card_required: true,
            runtime_deferred: true,
            route_authority_denied: true,
            product_route_enabled: false,
            product_default_model_claim: false,
            product_winner_claim: false,
            active_params_as_fit_claim: false,
            fits_target_hardware_claim: false,
            server_benchmark_as_local_fit_proof: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_l3_promotion_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            apex_provenance_required: apex,
            provenance_gate_ref: apex.then(|| "provenance:apex-import-mode-required".to_string()),
            headroom_caveat_ref: Some("hardware:moe-not-16gb-default".to_string()),
            byte_ledger: MoeMemoryByteLedger::metadata_only(
                12_000,
                6_000,
                20_000_000_000,
                3_000_000_000,
                2_000_000_000,
                20_000_000_000,
                256_000_000,
                512_000_000,
                MAC_16_18_HEADROOM_BYTES,
            ),
            proof_refs: MoeMemoryProofRefs {
                upstream_catalog_ref: UPSTREAM_REF.to_string(),
                falsifier_ref: "falsifier:F-MoEActiveParamsMemoryTruth".to_string(),
                rollback_ref: "rollback:abstain-from-moe-route-card".to_string(),
                run_event_log_ref: "run_event_log:moe-memory-truth-metadata".to_string(),
                answer_packet_ref: "answer_packet:moe-memory-truth-visible-caveat".to_string(),
                compatibility_fence_ref: "compat:moe-runtime-proof-required".to_string(),
                privacy_policy_ref: "privacy:no-provider-no-hidden-route".to_string(),
                provenance_ref: "provenance:source-card-before-runtime".to_string(),
                hardware_tier_ref: "hardware:24gb-plus-candidate-not-fit-proof".to_string(),
                abstention_ref: "abstention:missing-runtime-memory-proof".to_string(),
            },
        }
    }

    #[test]
    fn accepts_two_moe_rows_with_separate_byte_ledgers() {
        let ledger = build_ledger(fixture_cards()).expect("fixture must validate");
        let metrics = ledger.metrics();
        assert_eq!(metrics.card_count, 2);
        assert_eq!(metrics.active_compute_only_count, 2);
        assert_eq!(metrics.full_weight_ledger_count, 2);
        assert_eq!(metrics.kv_budget_count, 2);
        assert_eq!(metrics.expert_residency_lease_count, 2);
        assert_eq!(metrics.model_bytes_loaded, 0);
    }

    #[test]
    fn deterministic_address_ignores_input_order() {
        let forward = build_ledger(fixture_cards()).expect("forward ledger");
        let reverse =
            build_ledger(fixture_cards().into_iter().rev().collect()).expect("reverse ledger");
        assert_eq!(forward.ledger_address, reverse.ledger_address);
    }

    #[test]
    fn rejects_non_moe_or_duplicate_rows() {
        assert!(reject_cards(|cards| cards.push(cards[0].clone())));
        assert!(reject_cards(
            |cards| cards[0].model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()
        ));
    }

    #[test]
    fn rejects_active_params_as_memory_fit() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.active_params_as_fit_claim = true;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.active_compute_not_memory_fit = false;
        }));
    }

    #[test]
    fn rejects_missing_weight_kv_expert_and_headroom_budgets() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.full_weight_artifact_bytes_declared = 0;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.kv_cache_budget_bytes = 0;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.expert_residency_lease_bytes = 0;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.app_headroom_bytes = 1;
        }));
    }

    #[test]
    fn rejects_runtime_product_and_hidden_authority_claims() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.product_route_enabled = true;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.hidden_route_authority = true;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.hidden_cloud_fallback = true;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.l2_l3_promotion_claim = true;
        }));
    }

    #[test]
    fn rejects_loaded_bytes_commands_and_benchmarks() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.model_bytes_loaded = 1;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.runtime_bytes_loaded = 1;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.command_executions = 1;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.byte_ledger.benchmark_runs = 1;
        }));
    }

    #[test]
    fn rejects_16gb_moe_and_apex_without_provenance() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.hardware_tier = HardwareTier::Mac16To18Gb;
        }));
        assert!(reject_card("qwopus_moe_35b_a3b_apex_gguf", |card| {
            card.apex_provenance_required = false;
        }));
    }

    #[test]
    fn rejects_bad_proof_refs_and_bad_upstream() {
        assert!(reject_card("qwopus_moe_35b_a3b_gguf", |card| {
            card.proof_refs.answer_packet_ref = "hidden:packet".to_string();
        }));
        assert!(MoeActiveParamsMemoryTruthLedger::new(
            "artifact:falsifiers/other/result.json",
            fixture_cards(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            180_000,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err());
    }
}
