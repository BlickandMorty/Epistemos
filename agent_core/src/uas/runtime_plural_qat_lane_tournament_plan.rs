//! Runtime-plural QAT lane tournament plan.
//!
//! This primitive turns the June 6 large-local-model research into a
//! metadata-only tournament contract. It source-cards GGUF/llama.cpp,
//! LiteRT-LM, MLX Swift, and MLX-LM lanes under one future redacted fixture
//! before any runtime can claim a winner, speed, quality, MAS readiness, or
//! product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_CURSOR: &str =
    "runtime_plural_qat_lane_tournament_plan";
pub const RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_NEXT_CURSOR: &str =
    "runtime_plural_qat_lane_tournament_owner_approval_gate";

const HTTPS_PREFIX: &str = "https://";
const UPSTREAM_LITERT_PREFIX: &str = "artifact:litertlm_native_swift_admission:";
const UPSTREAM_MTP_PREFIX: &str = "artifact:gemma4_mtp_drafter_compatibility_card:";
const UPSTREAM_QAT_PREFLIGHT_PREFIX: &str = "artifact:qat_model_route_card_memory_preflight:";
const UPSTREAM_PACKET_PREFIX: &str = "artifact:compressed_route_answer_packet_dry_run:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const FIXTURE_PREFIX: &str = "fixture:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const CANCEL_PREFIX: &str = "cancel:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:";
const QUALITY_LEDGER_PREFIX: &str = "quality_ledger:";
const LATENCY_LEDGER_PREFIX: &str = "latency_ledger:";
const TOOL_JSON_LEDGER_PREFIX: &str = "tool_json_ledger:";
const COMPATIBILITY_PREFIX: &str = "compat:";
const ABSTENTION_PREFIX: &str = "abstain:";
const LOADER_CAVEAT_PREFIX: &str = "loader_caveat:";
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAX_SET_METADATA_BYTES: u64 = 384 * 1024;

// UAS: uas:runtime-plural-qat-tournament:lane
// Plane: Controller
// Residency: candidate runtime lane only; no runtime is opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePluralQatLane {
    GgufLlamaCpp,
    LiteRtLmSwift,
    MlxSwiftCandidate,
    MlxLmPythonResearch,
    NoRuntime,
}

// UAS: uas:runtime-plural-qat-tournament:lane-status
// Plane: Controller + Verification
// Residency: future participation status; not a product route verdict.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePluralQatLaneStatus {
    FutureProbeCandidate,
    DeferredAbstention,
    BlockedUntilAdmission,
    ResearchOnly,
}

// UAS: uas:runtime-plural-qat-tournament:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePluralQatPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:runtime-plural-qat-tournament:bytes
// Plane: Verification
// Residency: planned-byte ledger; opened/loaded/runtime bytes must remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePluralQatByteLedger {
    pub declared_model_bytes: u64,
    pub planned_resident_floor_bytes: u64,
    pub planned_kv_floor_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub metadata_bytes_read: u64,
    pub opened_model_bytes: u64,
    pub resident_model_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl RuntimePluralQatByteLedger {
    pub fn metadata_only(
        declared_model_bytes: u64,
        planned_resident_floor_bytes: u64,
        planned_kv_floor_bytes: u64,
        planned_scratch_bytes: u64,
        metadata_bytes_read: u64,
    ) -> Self {
        Self {
            declared_model_bytes,
            planned_resident_floor_bytes,
            planned_kv_floor_bytes,
            planned_scratch_bytes,
            metadata_bytes_read,
            opened_model_bytes: 0,
            resident_model_bytes: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            product_files_copied: 0,
            command_executions: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:runtime-plural-qat-tournament:proof-refs
// Plane: Verification
// Residency: visible proof handles required before any lane comparison runs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePluralQatProofRefs {
    pub upstream_litert_admission_ref: String,
    pub upstream_mtp_compatibility_ref: String,
    pub upstream_qat_route_preflight_ref: String,
    pub upstream_compressed_route_packet_ref: String,
    pub falsifier_ref: String,
    pub fixture_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub cancellation_ref: String,
    pub memory_ledger_ref: String,
    pub quality_ledger_ref: String,
    pub latency_ledger_ref: String,
    pub tool_json_ledger_ref: String,
    pub compatibility_fence_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:runtime-plural-qat-tournament:lane-card
// Plane: State + Controller + Verification
// Residency: source-carded future lane; not a loadability or winner proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePluralQatLaneCard {
    pub lane_id: String,
    pub runtime_lane: RuntimePluralQatLane,
    pub lane_status: RuntimePluralQatLaneStatus,
    pub model_id: String,
    pub model_url: String,
    pub model_revision: String,
    pub model_license_spdx: String,
    pub quant_or_format: String,
    pub runtime_repo_url: String,
    pub runtime_repo_commit: String,
    pub runtime_release_tag: String,
    pub runtime_license_spdx: String,
    pub runtime_source_classification: String,
    pub same_fixture_id: String,
    pub same_fixture_hash_ref: String,
    pub fixture_redacted: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: RuntimePluralQatPromotionTier,
    pub byte_ledger: RuntimePluralQatByteLedger,
    pub proof_refs: RuntimePluralQatProofRefs,
    pub loader_caveat_ref: Option<String>,
    pub user_visible_route_caveat: String,
    pub same_fixture_required: bool,
    pub byte_ledger_required: bool,
    pub memory_preflight_required: bool,
    pub cancellation_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub quality_metric_required: bool,
    pub latency_metric_required: bool,
    pub tool_json_metric_required: bool,
    pub abstention_required: bool,
    pub future_probe_candidate: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub package_resolved: bool,
    pub product_dependency_imported: bool,
    pub runtime_loaded: bool,
    pub model_loaded: bool,
    pub command_executed: bool,
    pub benchmark_executed: bool,
    pub first_token_claimed: bool,
    pub product_winner_declared: bool,
    pub speed_claimed: bool,
    pub quality_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub server_sidecar_default_allowed: bool,
}

// UAS: uas:runtime-plural-qat-tournament:set
// Plane: State + Controller + Verification
// Residency: metadata-only tournament contract for future runtime proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePluralQatLaneTournamentPlan {
    pub plan_address: UasAddress,
    pub cards: Vec<RuntimePluralQatLaneCard>,
    pub metadata_bytes: u64,
    pub same_fixture_id: String,
    pub same_fixture_hash_ref: String,
    pub explicit_local_endpoint_default_denied: bool,
    pub runtime_plural_not_runtime_monopoly: bool,
    pub no_runtime_execution: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub hidden_authority_blocked: bool,
}

// UAS: uas:runtime-plural-qat-tournament:metrics
// Plane: Verification
// Residency: derived counters for metadata-only tournament artifacts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePluralQatTournamentMetrics {
    pub lane_card_count: u64,
    pub runtime_lane_count: u64,
    pub model_count: u64,
    pub future_probe_candidate_count: u64,
    pub deferred_abstention_count: u64,
    pub blocked_until_admission_count: u64,
    pub research_only_count: u64,
    pub fixture_count: u64,
    pub declared_model_bytes_total: u64,
    pub planned_resident_floor_bytes_total: u64,
    pub planned_kv_floor_bytes_total: u64,
    pub planned_scratch_bytes_total: u64,
    pub metadata_bytes_read: u64,
    pub opened_model_bytes: u64,
    pub resident_model_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
    pub package_resolved_count: u64,
    pub product_dependency_imported_count: u64,
    pub runtime_loaded_count: u64,
    pub model_loaded_count: u64,
    pub command_executed_count: u64,
    pub benchmark_executed_count: u64,
    pub first_token_claim_count: u64,
    pub product_winner_declared_count: u64,
    pub speed_claim_count: u64,
    pub quality_claim_count: u64,
    pub mas_readiness_claim_count: u64,
    pub l2_capability_claim_count: u64,
    pub l3_wrv_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
    pub hidden_cloud_fallback_count: u64,
    pub hidden_route_authority_count: u64,
    pub server_sidecar_default_count: u64,
}

impl RuntimePluralQatLaneTournamentPlan {
    pub fn new(
        mut cards: Vec<RuntimePluralQatLaneCard>,
        metadata_bytes: u64,
        same_fixture_id: impl Into<String>,
        same_fixture_hash_ref: impl Into<String>,
        explicit_local_endpoint_default_denied: bool,
        created_at_ms: u64,
    ) -> Result<Self, RuntimePluralQatTournamentError> {
        let same_fixture_id = same_fixture_id.into();
        let same_fixture_hash_ref = same_fixture_hash_ref.into();
        validate_plan_inputs(
            &cards,
            metadata_bytes,
            &same_fixture_id,
            &same_fixture_hash_ref,
            explicit_local_endpoint_default_denied,
        )?;
        cards.sort_by(|a, b| a.lane_id.cmp(&b.lane_id));
        let preimage = plan_preimage(
            &cards,
            metadata_bytes,
            &same_fixture_id,
            &same_fixture_hash_ref,
            explicit_local_endpoint_default_denied,
        );
        Ok(Self {
            plan_address: UasAddress::new(
                UasKind::Other(RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            cards,
            metadata_bytes,
            same_fixture_id,
            same_fixture_hash_ref,
            explicit_local_endpoint_default_denied,
            runtime_plural_not_runtime_monopoly: true,
            no_runtime_execution: true,
            l1_l2_l3_separated: true,
            product_promotion_blocked: true,
            hidden_authority_blocked: true,
        })
    }

    pub fn metrics(&self) -> RuntimePluralQatTournamentMetrics {
        let mut runtime_lanes = HashSet::new();
        let mut models = HashSet::new();
        let mut fixtures = BTreeSet::new();
        let mut metrics = RuntimePluralQatTournamentMetrics {
            lane_card_count: self.cards.len() as u64,
            runtime_lane_count: 0,
            model_count: 0,
            future_probe_candidate_count: 0,
            deferred_abstention_count: 0,
            blocked_until_admission_count: 0,
            research_only_count: 0,
            fixture_count: 0,
            declared_model_bytes_total: 0,
            planned_resident_floor_bytes_total: 0,
            planned_kv_floor_bytes_total: 0,
            planned_scratch_bytes_total: 0,
            metadata_bytes_read: 0,
            opened_model_bytes: 0,
            resident_model_bytes: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            product_files_copied: 0,
            command_executions: 0,
            benchmark_runs: 0,
            package_resolved_count: 0,
            product_dependency_imported_count: 0,
            runtime_loaded_count: 0,
            model_loaded_count: 0,
            command_executed_count: 0,
            benchmark_executed_count: 0,
            first_token_claim_count: 0,
            product_winner_declared_count: 0,
            speed_claim_count: 0,
            quality_claim_count: 0,
            mas_readiness_claim_count: 0,
            l2_capability_claim_count: 0,
            l3_wrv_claim_count: 0,
            live_dense_70b_claim_count: 0,
            ssd_as_ram_claim_count: 0,
            hidden_cloud_fallback_count: 0,
            hidden_route_authority_count: 0,
            server_sidecar_default_count: 0,
        };

        for card in &self.cards {
            runtime_lanes.insert(card.runtime_lane);
            models.insert(card.model_id.clone());
            fixtures.insert(card.same_fixture_id.clone());
            match card.lane_status {
                RuntimePluralQatLaneStatus::FutureProbeCandidate => {
                    metrics.future_probe_candidate_count += 1
                }
                RuntimePluralQatLaneStatus::DeferredAbstention => {
                    metrics.deferred_abstention_count += 1
                }
                RuntimePluralQatLaneStatus::BlockedUntilAdmission => {
                    metrics.blocked_until_admission_count += 1
                }
                RuntimePluralQatLaneStatus::ResearchOnly => metrics.research_only_count += 1,
            }
            metrics.declared_model_bytes_total = metrics
                .declared_model_bytes_total
                .saturating_add(card.byte_ledger.declared_model_bytes);
            metrics.planned_resident_floor_bytes_total = metrics
                .planned_resident_floor_bytes_total
                .saturating_add(card.byte_ledger.planned_resident_floor_bytes);
            metrics.planned_kv_floor_bytes_total = metrics
                .planned_kv_floor_bytes_total
                .saturating_add(card.byte_ledger.planned_kv_floor_bytes);
            metrics.planned_scratch_bytes_total = metrics
                .planned_scratch_bytes_total
                .saturating_add(card.byte_ledger.planned_scratch_bytes);
            metrics.metadata_bytes_read = metrics
                .metadata_bytes_read
                .saturating_add(card.byte_ledger.metadata_bytes_read);
            metrics.opened_model_bytes = metrics
                .opened_model_bytes
                .saturating_add(card.byte_ledger.opened_model_bytes);
            metrics.resident_model_bytes = metrics
                .resident_model_bytes
                .saturating_add(card.byte_ledger.resident_model_bytes);
            metrics.runtime_bytes_loaded = metrics
                .runtime_bytes_loaded
                .saturating_add(card.byte_ledger.runtime_bytes_loaded);
            metrics.model_bytes_loaded = metrics
                .model_bytes_loaded
                .saturating_add(card.byte_ledger.model_bytes_loaded);
            metrics.provider_calls_made = metrics
                .provider_calls_made
                .saturating_add(card.byte_ledger.provider_calls_made);
            metrics.product_files_copied = metrics
                .product_files_copied
                .saturating_add(card.byte_ledger.product_files_copied);
            metrics.command_executions = metrics
                .command_executions
                .saturating_add(card.byte_ledger.command_executions);
            metrics.benchmark_runs = metrics
                .benchmark_runs
                .saturating_add(card.byte_ledger.benchmark_runs);
            if card.package_resolved {
                metrics.package_resolved_count += 1;
            }
            if card.product_dependency_imported {
                metrics.product_dependency_imported_count += 1;
            }
            if card.runtime_loaded {
                metrics.runtime_loaded_count += 1;
            }
            if card.model_loaded {
                metrics.model_loaded_count += 1;
            }
            if card.command_executed {
                metrics.command_executed_count += 1;
            }
            if card.benchmark_executed {
                metrics.benchmark_executed_count += 1;
            }
            if card.first_token_claimed {
                metrics.first_token_claim_count += 1;
            }
            if card.product_winner_declared {
                metrics.product_winner_declared_count += 1;
            }
            if card.speed_claimed {
                metrics.speed_claim_count += 1;
            }
            if card.quality_claimed {
                metrics.quality_claim_count += 1;
            }
            if card.mas_readiness_claimed {
                metrics.mas_readiness_claim_count += 1;
            }
            if card.l2_capability_claimed {
                metrics.l2_capability_claim_count += 1;
            }
            if card.l3_wrv_claimed {
                metrics.l3_wrv_claim_count += 1;
            }
            if card.live_dense_70b_claimed {
                metrics.live_dense_70b_claim_count += 1;
            }
            if card.ssd_as_ram_claimed {
                metrics.ssd_as_ram_claim_count += 1;
            }
            if card.hidden_cloud_fallback_allowed {
                metrics.hidden_cloud_fallback_count += 1;
            }
            if card.hidden_route_authority_allowed {
                metrics.hidden_route_authority_count += 1;
            }
            if card.server_sidecar_default_allowed {
                metrics.server_sidecar_default_count += 1;
            }
        }

        metrics.runtime_lane_count = runtime_lanes.len() as u64;
        metrics.model_count = models.len() as u64;
        metrics.fixture_count = fixtures.len() as u64;
        metrics
    }
}

// UAS: uas:runtime-plural-qat-tournament:error
// Plane: Verification
// Residency: validation failure only; no runtime side effects.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimePluralQatTournamentError {
    EmptyCards,
    MetadataBudget,
    InvalidSet(String),
    InvalidCard(String),
    DuplicateLaneId(String),
    DuplicateLaneModel(String),
}

impl fmt::Display for RuntimePluralQatTournamentError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCards => write!(f, "runtime-plural tournament has no cards"),
            Self::MetadataBudget => write!(f, "runtime-plural tournament metadata budget invalid"),
            Self::InvalidSet(reason) => {
                write!(f, "invalid runtime-plural tournament set: {reason}")
            }
            Self::InvalidCard(reason) => {
                write!(f, "invalid runtime-plural tournament card: {reason}")
            }
            Self::DuplicateLaneId(id) => write!(f, "duplicate runtime-plural lane id: {id}"),
            Self::DuplicateLaneModel(id) => {
                write!(f, "duplicate runtime-plural lane/model pair: {id}")
            }
        }
    }
}

impl std::error::Error for RuntimePluralQatTournamentError {}

fn validate_plan_inputs(
    cards: &[RuntimePluralQatLaneCard],
    metadata_bytes: u64,
    same_fixture_id: &str,
    same_fixture_hash_ref: &str,
    explicit_local_endpoint_default_denied: bool,
) -> Result<(), RuntimePluralQatTournamentError> {
    if cards.is_empty() {
        return Err(RuntimePluralQatTournamentError::EmptyCards);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(RuntimePluralQatTournamentError::MetadataBudget);
    }
    if !is_clean_id(same_fixture_id) || !same_fixture_hash_ref.starts_with(FIXTURE_PREFIX) {
        return Err(RuntimePluralQatTournamentError::InvalidSet(
            "same fixture id/hash missing".to_string(),
        ));
    }
    if !explicit_local_endpoint_default_denied {
        return Err(RuntimePluralQatTournamentError::InvalidSet(
            "explicit local endpoints must be denied by default".to_string(),
        ));
    }

    let mut lane_ids = HashSet::new();
    let mut lane_models = HashSet::new();
    let mut statuses = HashSet::new();
    let mut lanes = HashSet::new();
    for card in cards {
        validate_card(card, same_fixture_id, same_fixture_hash_ref)?;
        if !lane_ids.insert(card.lane_id.clone()) {
            return Err(RuntimePluralQatTournamentError::DuplicateLaneId(
                card.lane_id.clone(),
            ));
        }
        let lane_model = format!("{:?}:{}", card.runtime_lane, card.model_id);
        if !lane_models.insert(lane_model.clone()) {
            return Err(RuntimePluralQatTournamentError::DuplicateLaneModel(
                lane_model,
            ));
        }
        statuses.insert(card.lane_status);
        lanes.insert(card.runtime_lane);
    }

    for required in [
        RuntimePluralQatLane::GgufLlamaCpp,
        RuntimePluralQatLane::LiteRtLmSwift,
        RuntimePluralQatLane::MlxSwiftCandidate,
        RuntimePluralQatLane::MlxLmPythonResearch,
    ] {
        if !lanes.contains(&required) {
            return Err(RuntimePluralQatTournamentError::InvalidSet(format!(
                "missing runtime lane {required:?}"
            )));
        }
    }
    for required in [
        RuntimePluralQatLaneStatus::FutureProbeCandidate,
        RuntimePluralQatLaneStatus::DeferredAbstention,
        RuntimePluralQatLaneStatus::BlockedUntilAdmission,
        RuntimePluralQatLaneStatus::ResearchOnly,
    ] {
        if !statuses.contains(&required) {
            return Err(RuntimePluralQatTournamentError::InvalidSet(format!(
                "missing lane status {required:?}"
            )));
        }
    }
    Ok(())
}

fn validate_card(
    card: &RuntimePluralQatLaneCard,
    same_fixture_id: &str,
    same_fixture_hash_ref: &str,
) -> Result<(), RuntimePluralQatTournamentError> {
    let clean_fields = [
        card.lane_id.as_str(),
        card.model_id.as_str(),
        card.model_revision.as_str(),
        card.model_license_spdx.as_str(),
        card.quant_or_format.as_str(),
        card.runtime_repo_commit.as_str(),
        card.runtime_release_tag.as_str(),
        card.runtime_license_spdx.as_str(),
        card.runtime_source_classification.as_str(),
        card.same_fixture_id.as_str(),
        card.same_fixture_hash_ref.as_str(),
        card.user_visible_route_caveat.as_str(),
    ];
    if clean_fields.iter().any(|field| !is_clean_id(field)) {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has an empty or unsafe field",
            card.lane_id
        )));
    }
    if !is_https(&card.model_url) || !is_https(&card.runtime_repo_url) {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has a non-HTTPS source",
            card.lane_id
        )));
    }
    if !is_hex_sha(&card.model_revision) || !is_hex_sha(&card.runtime_repo_commit) {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has an invalid source revision",
            card.lane_id
        )));
    }
    if card.model_license_spdx != "Apache-2.0" {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} must bind Apache-2.0 model metadata",
            card.lane_id
        )));
    }
    if !matches!(card.runtime_license_spdx.as_str(), "MIT" | "Apache-2.0") {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has an unsupported runtime license",
            card.lane_id
        )));
    }
    if card.runtime_lane == RuntimePluralQatLane::NoRuntime {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has no runtime lane",
            card.lane_id
        )));
    }
    if card.same_fixture_id != same_fixture_id
        || card.same_fixture_hash_ref != same_fixture_hash_ref
        || !card.same_fixture_required
        || !card.fixture_redacted
    {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} is not bound to the redacted fixture",
            card.lane_id
        )));
    }
    if card.product_build != ProductBuild::Pro {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} must remain Pro-only research",
            card.lane_id
        )));
    }
    if matches!(card.pro_status, ProStatus::Live | ProStatus::Omega) {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} overclaims Pro status",
            card.lane_id
        )));
    }
    if !matches!(
        card.promotion_tier,
        RuntimePluralQatPromotionTier::T0Research | RuntimePluralQatPromotionTier::T1L1Metadata
    ) {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} overclaims promotion tier",
            card.lane_id
        )));
    }
    if !card.byte_ledger_required
        || !card.memory_preflight_required
        || !card.cancellation_required
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.quality_metric_required
        || !card.latency_metric_required
        || !card.tool_json_metric_required
        || !card.abstention_required
    {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} missing required proof surfaces",
            card.lane_id
        )));
    }
    validate_proof_refs(card)?;
    validate_byte_ledger(card)?;
    validate_status_specifics(card)?;
    if !card.runtime_deferred || !card.product_promotion_blocked {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} permits runtime/product promotion",
            card.lane_id
        )));
    }
    if card.package_resolved
        || card.product_dependency_imported
        || card.runtime_loaded
        || card.model_loaded
        || card.command_executed
        || card.benchmark_executed
        || card.first_token_claimed
        || card.product_winner_declared
        || card.speed_claimed
        || card.quality_claimed
        || card.mas_readiness_claimed
        || card.l2_capability_claimed
        || card.l3_wrv_claimed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
        || card.server_sidecar_default_allowed
    {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} contains a runtime or product claim",
            card.lane_id
        )));
    }
    Ok(())
}

fn validate_proof_refs(
    card: &RuntimePluralQatLaneCard,
) -> Result<(), RuntimePluralQatTournamentError> {
    let refs = &card.proof_refs;
    let checks = [
        (
            refs.upstream_litert_admission_ref.as_str(),
            UPSTREAM_LITERT_PREFIX,
        ),
        (
            refs.upstream_mtp_compatibility_ref.as_str(),
            UPSTREAM_MTP_PREFIX,
        ),
        (
            refs.upstream_qat_route_preflight_ref.as_str(),
            UPSTREAM_QAT_PREFLIGHT_PREFIX,
        ),
        (
            refs.upstream_compressed_route_packet_ref.as_str(),
            UPSTREAM_PACKET_PREFIX,
        ),
        (refs.falsifier_ref.as_str(), FALSIFIER_PREFIX),
        (refs.fixture_ref.as_str(), FIXTURE_PREFIX),
        (refs.rollback_ref.as_str(), ROLLBACK_PREFIX),
        (refs.run_event_log_ref.as_str(), RUN_EVENT_LOG_PREFIX),
        (refs.answer_packet_ref.as_str(), ANSWER_PACKET_PREFIX),
        (refs.cancellation_ref.as_str(), CANCEL_PREFIX),
        (refs.memory_ledger_ref.as_str(), MEMORY_LEDGER_PREFIX),
        (refs.quality_ledger_ref.as_str(), QUALITY_LEDGER_PREFIX),
        (refs.latency_ledger_ref.as_str(), LATENCY_LEDGER_PREFIX),
        (refs.tool_json_ledger_ref.as_str(), TOOL_JSON_LEDGER_PREFIX),
        (refs.compatibility_fence_ref.as_str(), COMPATIBILITY_PREFIX),
        (refs.abstention_ref.as_str(), ABSTENTION_PREFIX),
    ];
    if checks
        .iter()
        .any(|(value, prefix)| !value.starts_with(prefix))
    {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has a bad proof ref",
            card.lane_id
        )));
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &RuntimePluralQatLaneCard,
) -> Result<(), RuntimePluralQatTournamentError> {
    let bytes = &card.byte_ledger;
    if bytes.metadata_bytes_read == 0 || bytes.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} metadata bytes out of range",
            card.lane_id
        )));
    }
    if matches!(
        card.lane_status,
        RuntimePluralQatLaneStatus::FutureProbeCandidate
            | RuntimePluralQatLaneStatus::DeferredAbstention
    ) && (bytes.declared_model_bytes == 0
        || bytes.planned_resident_floor_bytes <= bytes.declared_model_bytes
        || bytes.planned_kv_floor_bytes == 0
        || bytes.planned_scratch_bytes == 0)
    {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} lacks planned byte accounting",
            card.lane_id
        )));
    }
    if bytes.opened_model_bytes != 0
        || bytes.resident_model_bytes != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.model_bytes_loaded != 0
        || bytes.provider_calls_made != 0
        || bytes.product_files_copied != 0
        || bytes.command_executions != 0
        || bytes.benchmark_runs != 0
    {
        return Err(RuntimePluralQatTournamentError::InvalidCard(format!(
            "{} has nonzero runtime/model/provider bytes",
            card.lane_id
        )));
    }
    Ok(())
}

fn validate_status_specifics(
    card: &RuntimePluralQatLaneCard,
) -> Result<(), RuntimePluralQatTournamentError> {
    match card.runtime_lane {
        RuntimePluralQatLane::MlxSwiftCandidate => {
            let Some(caveat) = &card.loader_caveat_ref else {
                return Err(RuntimePluralQatTournamentError::InvalidCard(
                    "MLX Swift lane missing loader caveat".to_string(),
                ));
            };
            if !caveat.starts_with(LOADER_CAVEAT_PREFIX)
                || card.lane_status != RuntimePluralQatLaneStatus::BlockedUntilAdmission
                || card.future_probe_candidate
            {
                return Err(RuntimePluralQatTournamentError::InvalidCard(
                    "MLX Swift lane must stay blocked until loader proof".to_string(),
                ));
            }
        }
        RuntimePluralQatLane::LiteRtLmSwift => {
            if card.lane_status != RuntimePluralQatLaneStatus::BlockedUntilAdmission
                || card.future_probe_candidate
            {
                return Err(RuntimePluralQatTournamentError::InvalidCard(
                    "LiteRT-LM lane must stay blocked until local package proof".to_string(),
                ));
            }
        }
        RuntimePluralQatLane::MlxLmPythonResearch => {
            if card.lane_status != RuntimePluralQatLaneStatus::ResearchOnly
                || card.promotion_tier != RuntimePluralQatPromotionTier::T0Research
            {
                return Err(RuntimePluralQatTournamentError::InvalidCard(
                    "MLX-LM lane must remain research-only".to_string(),
                ));
            }
        }
        RuntimePluralQatLane::GgufLlamaCpp => {
            if card.lane_status == RuntimePluralQatLaneStatus::FutureProbeCandidate
                && !card.future_probe_candidate
            {
                return Err(RuntimePluralQatTournamentError::InvalidCard(
                    "GGUF future probe lane is not marked as future candidate".to_string(),
                ));
            }
        }
        RuntimePluralQatLane::NoRuntime => {
            return Err(RuntimePluralQatTournamentError::InvalidCard(
                "NoRuntime lane is not allowed".to_string(),
            ));
        }
    }
    Ok(())
}

fn is_clean_id(value: &str) -> bool {
    let trimmed = value.trim();
    !trimmed.is_empty()
        && trimmed == value
        && !value.contains('\n')
        && !value.contains('\r')
        && !value.contains('\t')
}

fn is_https(value: &str) -> bool {
    value.starts_with(HTTPS_PREFIX)
}

fn is_hex_sha(value: &str) -> bool {
    value.len() == 40 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn plan_preimage(
    cards: &[RuntimePluralQatLaneCard],
    metadata_bytes: u64,
    same_fixture_id: &str,
    same_fixture_hash_ref: &str,
    explicit_local_endpoint_default_denied: bool,
) -> String {
    let mut lines = Vec::with_capacity(cards.len() + 4);
    lines.push(format!(
        "runtime_plural_qat_lane_tournament_plan_v1\n{metadata_bytes}\n{same_fixture_id}\n{same_fixture_hash_ref}\n{explicit_local_endpoint_default_denied}"
    ));
    for card in cards {
        lines.push(format!(
            "{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}",
            card.lane_id,
            card.runtime_lane,
            card.lane_status,
            card.model_id,
            card.model_revision,
            card.quant_or_format,
            card.runtime_repo_url,
            card.runtime_repo_commit,
            card.runtime_release_tag,
            card.byte_ledger.declared_model_bytes,
            card.user_visible_route_caveat
        ));
    }
    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE_ID: &str = "redacted_large_local_agentic_fixture_v1";
    const FIXTURE_HASH: &str = "fixture:sha256:runtime-plural-redacted-agentic-fixture-v1";

    #[test]
    fn accepted_plan_is_deterministic_and_metadata_only() {
        let cards = accepted_cards();
        let plan = RuntimePluralQatLaneTournamentPlan::new(
            cards.clone(),
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        )
        .expect("accepted cards should pass");
        let reversed = RuntimePluralQatLaneTournamentPlan::new(
            cards.into_iter().rev().collect(),
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        )
        .expect("accepted reversed cards should pass");
        let metrics = plan.metrics();
        assert_eq!(plan.plan_address, reversed.plan_address);
        assert_eq!(metrics.lane_card_count, 5);
        assert_eq!(metrics.runtime_lane_count, 4);
        assert_eq!(metrics.fixture_count, 1);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.product_winner_declared_count, 0);
    }

    #[test]
    fn duplicate_lane_model_rejects() {
        let mut cards = accepted_cards();
        cards[1].model_id = cards[0].model_id.clone();
        cards[1].runtime_lane = cards[0].runtime_lane;
        let result = RuntimePluralQatLaneTournamentPlan::new(
            cards,
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        );
        assert!(matches!(
            result,
            Err(RuntimePluralQatTournamentError::DuplicateLaneModel(_))
        ));
    }

    #[test]
    fn fixture_drift_rejects() {
        let mut cards = accepted_cards();
        cards[0].same_fixture_id = "other_fixture".to_string();
        let result = RuntimePluralQatLaneTournamentPlan::new(
            cards,
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        );
        assert!(result.is_err());
    }

    #[test]
    fn runtime_bytes_reject() {
        let mut cards = accepted_cards();
        cards[0].byte_ledger.runtime_bytes_loaded = 1;
        let result = RuntimePluralQatLaneTournamentPlan::new(
            cards,
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        );
        assert!(result.is_err());
    }

    #[test]
    fn product_winner_rejects() {
        let mut cards = accepted_cards();
        cards[0].product_winner_declared = true;
        let result = RuntimePluralQatLaneTournamentPlan::new(
            cards,
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        );
        assert!(result.is_err());
    }

    #[test]
    fn mlx_loader_caveat_required() {
        let mut cards = accepted_cards();
        let card = cards
            .iter_mut()
            .find(|card| card.runtime_lane == RuntimePluralQatLane::MlxSwiftCandidate)
            .expect("MLX Swift card exists");
        card.loader_caveat_ref = None;
        let result = RuntimePluralQatLaneTournamentPlan::new(
            cards,
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            true,
            1_779_061_300_000,
        );
        assert!(result.is_err());
    }

    #[test]
    fn local_endpoint_must_be_default_denied() {
        let result = RuntimePluralQatLaneTournamentPlan::new(
            accepted_cards(),
            160_000,
            FIXTURE_ID,
            FIXTURE_HASH,
            false,
            1_779_061_300_000,
        );
        assert!(result.is_err());
    }

    fn accepted_cards() -> Vec<RuntimePluralQatLaneCard> {
        vec![
            lane_card(CardSpec {
                lane_id: "gguf_e2b_qat_llama_cpp_future_probe",
                runtime_lane: RuntimePluralQatLane::GgufLlamaCpp,
                lane_status: RuntimePluralQatLaneStatus::FutureProbeCandidate,
                model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
                model_revision: "1894d1fc0a19d86697abd40483f5983c867df03f",
                model_url: "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf",
                quant_or_format: "gguf:q4_0",
                runtime_repo_url: "https://github.com/ggml-org/llama.cpp",
                runtime_repo_commit: "98d5e8ba8a2642710c9871d05ac1033a3328b884",
                runtime_release_tag: "b9544",
                runtime_license_spdx: "MIT",
                runtime_source_classification: "adapter_wrap",
                declared_model_bytes: 4_628_569_635,
                planned_resident_floor_bytes: 5 * 1024 * 1024 * 1024,
                planned_kv_floor_bytes: 512 * 1024 * 1024,
                planned_scratch_bytes: 256 * 1024 * 1024,
                pro_status: ProStatus::ResearchCandidate,
                promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
                loader_caveat_ref: None,
                future_probe_candidate: true,
            }),
            lane_card(CardSpec {
                lane_id: "gguf_12b_qat_llama_cpp_flagship_abstain",
                runtime_lane: RuntimePluralQatLane::GgufLlamaCpp,
                lane_status: RuntimePluralQatLaneStatus::DeferredAbstention,
                model_id: "google/gemma-4-12B-it-qat-q4_0-gguf",
                model_revision: "f6e7774e6148da3b7f201e42ba37cf084c1db35f",
                model_url: "https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf",
                quant_or_format: "gguf:q4_0",
                runtime_repo_url: "https://github.com/ggml-org/llama.cpp",
                runtime_repo_commit: "98d5e8ba8a2642710c9871d05ac1033a3328b884",
                runtime_release_tag: "b9544",
                runtime_license_spdx: "MIT",
                runtime_source_classification: "adapter_wrap",
                declared_model_bytes: 11_907_350_576,
                planned_resident_floor_bytes: 13 * 1024 * 1024 * 1024,
                planned_kv_floor_bytes: 1024 * 1024 * 1024,
                planned_scratch_bytes: 512 * 1024 * 1024,
                pro_status: ProStatus::Gated,
                promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
                loader_caveat_ref: None,
                future_probe_candidate: false,
            }),
            lane_card(CardSpec {
                lane_id: "litert_e2b_mtp_swift_blocked_until_package_proof",
                runtime_lane: RuntimePluralQatLane::LiteRtLmSwift,
                lane_status: RuntimePluralQatLaneStatus::BlockedUntilAdmission,
                model_id: "google/gemma-4-E2B-it",
                model_revision: "70af34e20bd4b7a91f0de6b22675850c43922a03",
                model_url: "https://huggingface.co/google/gemma-4-E2B-it",
                quant_or_format: "litert:model-card-plus-mtp",
                runtime_repo_url: "https://github.com/google-ai-edge/LiteRT-LM",
                runtime_repo_commit: "b9d59eb5610c1116fd6896cf71a19eb61355a707",
                runtime_release_tag: "v0.13.1",
                runtime_license_spdx: "Apache-2.0",
                runtime_source_classification: "adapter_wrap",
                declared_model_bytes: 0,
                planned_resident_floor_bytes: 0,
                planned_kv_floor_bytes: 0,
                planned_scratch_bytes: 0,
                pro_status: ProStatus::ResearchCandidate,
                promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
                loader_caveat_ref: Some("loader_caveat:litert_local_package_proof_pending"),
                future_probe_candidate: false,
            }),
            lane_card(CardSpec {
                lane_id: "mlx_swift_gemma4_loader_blocked",
                runtime_lane: RuntimePluralQatLane::MlxSwiftCandidate,
                lane_status: RuntimePluralQatLaneStatus::BlockedUntilAdmission,
                model_id: "google/gemma-4-E2B-it",
                model_revision: "70af34e20bd4b7a91f0de6b22675850c43922a03",
                model_url: "https://huggingface.co/google/gemma-4-E2B-it",
                quant_or_format: "mlx-swift:loader-unproven",
                runtime_repo_url: "https://github.com/ml-explore/mlx-swift",
                runtime_repo_commit: "dc43e62d7055353c7f99fa071a4e71d29dfddc44",
                runtime_release_tag: "0.31.4",
                runtime_license_spdx: "MIT",
                runtime_source_classification: "research_only",
                declared_model_bytes: 0,
                planned_resident_floor_bytes: 0,
                planned_kv_floor_bytes: 0,
                planned_scratch_bytes: 0,
                pro_status: ProStatus::Blocked,
                promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
                loader_caveat_ref: Some("loader_caveat:swift_mlx_gemma4_loader_unproven"),
                future_probe_candidate: false,
            }),
            lane_card(CardSpec {
                lane_id: "mlxlm_python_12b_research_reference",
                runtime_lane: RuntimePluralQatLane::MlxLmPythonResearch,
                lane_status: RuntimePluralQatLaneStatus::ResearchOnly,
                model_id: "google/gemma-4-12B-it",
                model_revision: "5926caa4ec0cac5cbfadaf4077420520de1d5205",
                model_url: "https://huggingface.co/google/gemma-4-12B-it",
                quant_or_format: "mlx-lm:python-research-reference",
                runtime_repo_url: "https://github.com/ml-explore/mlx-lm",
                runtime_repo_commit: "e476a22246b86fb6e2a8d35c81953293ebf86a0f",
                runtime_release_tag: "v0.31.3",
                runtime_license_spdx: "MIT",
                runtime_source_classification: "research_only",
                declared_model_bytes: 0,
                planned_resident_floor_bytes: 0,
                planned_kv_floor_bytes: 0,
                planned_scratch_bytes: 0,
                pro_status: ProStatus::ResearchCandidate,
                promotion_tier: RuntimePluralQatPromotionTier::T0Research,
                loader_caveat_ref: Some("loader_caveat:python_research_not_product_lane"),
                future_probe_candidate: false,
            }),
        ]
    }

    // UAS: runtime-plural QAT lane tournament fixture card.
    // Plane: Verification.
    // Residency: metadata-only candidate; no runtime, model, or provider bytes.
    struct CardSpec {
        lane_id: &'static str,
        runtime_lane: RuntimePluralQatLane,
        lane_status: RuntimePluralQatLaneStatus,
        model_id: &'static str,
        model_revision: &'static str,
        model_url: &'static str,
        quant_or_format: &'static str,
        runtime_repo_url: &'static str,
        runtime_repo_commit: &'static str,
        runtime_release_tag: &'static str,
        runtime_license_spdx: &'static str,
        runtime_source_classification: &'static str,
        declared_model_bytes: u64,
        planned_resident_floor_bytes: u64,
        planned_kv_floor_bytes: u64,
        planned_scratch_bytes: u64,
        pro_status: ProStatus,
        promotion_tier: RuntimePluralQatPromotionTier,
        loader_caveat_ref: Option<&'static str>,
        future_probe_candidate: bool,
    }

    fn lane_card(spec: CardSpec) -> RuntimePluralQatLaneCard {
        RuntimePluralQatLaneCard {
            lane_id: spec.lane_id.to_string(),
            runtime_lane: spec.runtime_lane,
            lane_status: spec.lane_status,
            model_id: spec.model_id.to_string(),
            model_url: spec.model_url.to_string(),
            model_revision: spec.model_revision.to_string(),
            model_license_spdx: "Apache-2.0".to_string(),
            quant_or_format: spec.quant_or_format.to_string(),
            runtime_repo_url: spec.runtime_repo_url.to_string(),
            runtime_repo_commit: spec.runtime_repo_commit.to_string(),
            runtime_release_tag: spec.runtime_release_tag.to_string(),
            runtime_license_spdx: spec.runtime_license_spdx.to_string(),
            runtime_source_classification: spec.runtime_source_classification.to_string(),
            same_fixture_id: FIXTURE_ID.to_string(),
            same_fixture_hash_ref: FIXTURE_HASH.to_string(),
            fixture_redacted: true,
            product_build: ProductBuild::Pro,
            pro_status: spec.pro_status,
            promotion_tier: spec.promotion_tier,
            byte_ledger: RuntimePluralQatByteLedger::metadata_only(
                spec.declared_model_bytes,
                spec.planned_resident_floor_bytes,
                spec.planned_kv_floor_bytes,
                spec.planned_scratch_bytes,
                24_000,
            ),
            proof_refs: proof_refs(spec.lane_id),
            loader_caveat_ref: spec.loader_caveat_ref.map(str::to_string),
            user_visible_route_caveat:
                "route_caveat:metadata_only_no_runtime_no_winner_no_product_claim".to_string(),
            same_fixture_required: true,
            byte_ledger_required: true,
            memory_preflight_required: true,
            cancellation_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            quality_metric_required: true,
            latency_metric_required: true,
            tool_json_metric_required: true,
            abstention_required: true,
            future_probe_candidate: spec.future_probe_candidate,
            runtime_deferred: true,
            product_promotion_blocked: true,
            package_resolved: false,
            product_dependency_imported: false,
            runtime_loaded: false,
            model_loaded: false,
            command_executed: false,
            benchmark_executed: false,
            first_token_claimed: false,
            product_winner_declared: false,
            speed_claimed: false,
            quality_claimed: false,
            mas_readiness_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            server_sidecar_default_allowed: false,
        }
    }

    fn proof_refs(id: &str) -> RuntimePluralQatProofRefs {
        RuntimePluralQatProofRefs {
            upstream_litert_admission_ref: "artifact:litertlm_native_swift_admission:result"
                .to_string(),
            upstream_mtp_compatibility_ref: "artifact:gemma4_mtp_drafter_compatibility_card:result"
                .to_string(),
            upstream_qat_route_preflight_ref:
                "artifact:qat_model_route_card_memory_preflight:result".to_string(),
            upstream_compressed_route_packet_ref:
                "artifact:compressed_route_answer_packet_dry_run:result".to_string(),
            falsifier_ref: format!("falsifier:F-RuntimePlural-QATLaneTournamentPlan:{id}"),
            fixture_ref: format!("fixture:{FIXTURE_ID}:{id}"),
            rollback_ref: format!("rollback:runtime_plural_qat_tournament:{id}"),
            run_event_log_ref: format!("run_event_log:runtime_plural_qat_tournament:{id}"),
            answer_packet_ref: format!("answer_packet:runtime_plural_qat_tournament:{id}"),
            cancellation_ref: format!("cancel:runtime_plural_qat_tournament:{id}"),
            memory_ledger_ref: format!("memory_ledger:runtime_plural_qat_tournament:{id}"),
            quality_ledger_ref: format!("quality_ledger:runtime_plural_qat_tournament:{id}"),
            latency_ledger_ref: format!("latency_ledger:runtime_plural_qat_tournament:{id}"),
            tool_json_ledger_ref: format!("tool_json_ledger:runtime_plural_qat_tournament:{id}"),
            compatibility_fence_ref: format!("compat:runtime_plural_qat_tournament:{id}"),
            abstention_ref: format!("abstain:runtime_plural_qat_tournament:{id}"),
        }
    }
}
