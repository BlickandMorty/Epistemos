//! Gemma QAT byte/KV/app envelope preflight.
//!
//! This primitive consumes the Gemma E2B/E4B owner path-manifest contract and
//! binds conservative byte, KV cache, runtime workspace, app headroom, rollback,
//! RunEventLog, AnswerPacket, and abstention requirements before any local
//! Gemma warmup probe can run. It is metadata-only: no owner path, local file,
//! model, runtime, provider, command, benchmark, or product-route bytes are
//! loaded.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_gemma_qat_small_lane_owner_path_manifest_cards, GemmaFamilyRuntimeLane, ProStatus,
    ProductBuild, UasAddress, UasKind,
};

pub const GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_ID: &str =
    "F-GemmaQATByteKVAppEnvelopePreflight";
pub const GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_CURSOR: &str =
    "gemma_qat_byte_kv_app_envelope_preflight";
pub const GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_NEXT_CURSOR: &str =
    "gemma_qat_redacted_first_token_probe";

const UPSTREAM_MANIFEST_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_small_lane_owner_path_manifest/";
const BYTE_ENVELOPE_PREFIX: &str = "byte_envelope:gemma_qat:";
const KV_CACHE_PREFIX: &str = "kv_cache_floor:gemma_qat:";
const RUNTIME_WORKSPACE_PREFIX: &str = "runtime_workspace:gemma_qat:";
const APP_HEADROOM_PREFIX: &str = "app_headroom:gemma_qat:";
const CANCELLATION_PREFIX: &str = "cancellation:gemma_qat:";
const ROLLBACK_PREFIX: &str = "rollback:gemma_qat:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:gemma_qat:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:gemma_qat:";
const ABSTENTION_PREFIX: &str = "abstention:gemma_qat:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:gemma_qat:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:gemma_qat:";
const MAX_LEDGER_METADATA_BYTES: u64 = 320 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
pub const M2_PRO_16GB_UMA_BYTES: u64 = 16 * 1024 * 1024 * 1024;

// UAS: uas:gemma-qat-byte-kv-app-envelope:state
// Plane: Verification.
// Residency: probe-candidate state only; no runtime residency is implied.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatEnvelopeState {
    ProbeCandidateAfterOwnerApproval,
    TightProbeCandidateNeedsFreshMemorySample,
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:action
// Plane: Controller.
// Residency: action stays preflight-only until owner-approved runtime proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatEnvelopeAction {
    CompileByteKvAppEnvelopePreflight,
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:byte-plan
// Plane: Verification.
// Residency: declared byte math only; selected bytes are not resident bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatEnvelopeBytePlan {
    pub declared_file_bytes: u64,
    pub selected_artifact_bytes: u64,
    pub kv_cache_floor_bytes: u64,
    pub runtime_workspace_bytes: u64,
    pub app_headroom_bytes: u64,
    pub metadata_side_table_bytes: u64,
    pub planned_total_envelope_bytes: u64,
    pub m2pro_16gb_uma_bytes: u64,
    pub remaining_uma_after_envelope_bytes: u64,
    pub current_m2pro_16gb_probe_candidate: bool,
    pub tight_candidate_requires_fresh_memory_sample: bool,
}

impl GemmaQatEnvelopeBytePlan {
    pub fn new(
        declared_file_bytes: u64,
        kv_cache_floor_bytes: u64,
        runtime_workspace_bytes: u64,
        app_headroom_bytes: u64,
        metadata_side_table_bytes: u64,
        tight_candidate_requires_fresh_memory_sample: bool,
    ) -> Self {
        let planned_total_envelope_bytes = declared_file_bytes
            .saturating_add(kv_cache_floor_bytes)
            .saturating_add(runtime_workspace_bytes)
            .saturating_add(app_headroom_bytes)
            .saturating_add(metadata_side_table_bytes);
        let remaining_uma_after_envelope_bytes =
            M2_PRO_16GB_UMA_BYTES.saturating_sub(planned_total_envelope_bytes);
        Self {
            declared_file_bytes,
            selected_artifact_bytes: declared_file_bytes,
            kv_cache_floor_bytes,
            runtime_workspace_bytes,
            app_headroom_bytes,
            metadata_side_table_bytes,
            planned_total_envelope_bytes,
            m2pro_16gb_uma_bytes: M2_PRO_16GB_UMA_BYTES,
            remaining_uma_after_envelope_bytes,
            current_m2pro_16gb_probe_candidate: planned_total_envelope_bytes
                <= M2_PRO_16GB_UMA_BYTES,
            tight_candidate_requires_fresh_memory_sample,
        }
    }

    fn recomputed_total(&self) -> u64 {
        self.selected_artifact_bytes
            .saturating_add(self.kv_cache_floor_bytes)
            .saturating_add(self.runtime_workspace_bytes)
            .saturating_add(self.app_headroom_bytes)
            .saturating_add(self.metadata_side_table_bytes)
    }
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:proof-refs
// Plane: Verification.
// Residency: visible proof handles for later runtime gates.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatEnvelopeProofRefs {
    pub upstream_manifest_ref: String,
    pub byte_envelope_ref: String,
    pub kv_cache_ref: String,
    pub runtime_workspace_ref: String,
    pub app_headroom_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:policy
// Plane: Controller + Verification.
// Residency: blocks file/runtime residency until redacted first-token proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatEnvelopePolicy {
    pub selected_artifact_bytes_bound: bool,
    pub kv_cache_floor_bound: bool,
    pub runtime_workspace_bound: bool,
    pub app_headroom_bound: bool,
    pub metadata_side_table_bound: bool,
    pub m2pro_16gb_recomputed: bool,
    pub current_m2pro_16gb_probe_candidate_not_fit_claim: bool,
    pub owner_approval_required: bool,
    pub fresh_memory_sample_required: bool,
    pub redacted_first_token_probe_required: bool,
    pub cancellation_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub abstention_required: bool,
    pub file_access_blocked: bool,
    pub command_blocked: bool,
    pub runtime_probe_blocked: bool,
    pub route_mutation_blocked: bool,
}

impl GemmaQatEnvelopePolicy {
    pub fn warmup_candidate(tight: bool) -> Self {
        Self {
            selected_artifact_bytes_bound: true,
            kv_cache_floor_bound: true,
            runtime_workspace_bound: true,
            app_headroom_bound: true,
            metadata_side_table_bound: true,
            m2pro_16gb_recomputed: true,
            current_m2pro_16gb_probe_candidate_not_fit_claim: true,
            owner_approval_required: true,
            fresh_memory_sample_required: true,
            redacted_first_token_probe_required: true,
            cancellation_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            abstention_required: true,
            file_access_blocked: true,
            command_blocked: true,
            runtime_probe_blocked: true,
            route_mutation_blocked: true,
        }
        .with_tightness(tight)
    }

    fn with_tightness(mut self, tight: bool) -> Self {
        self.fresh_memory_sample_required = tight || self.fresh_memory_sample_required;
        self
    }

    fn complete(&self) -> bool {
        self.selected_artifact_bytes_bound
            && self.kv_cache_floor_bound
            && self.runtime_workspace_bound
            && self.app_headroom_bound
            && self.metadata_side_table_bound
            && self.m2pro_16gb_recomputed
            && self.current_m2pro_16gb_probe_candidate_not_fit_claim
            && self.owner_approval_required
            && self.fresh_memory_sample_required
            && self.redacted_first_token_probe_required
            && self.cancellation_required
            && self.rollback_required
            && self.run_event_log_required
            && self.answer_packet_required
            && self.abstention_required
            && self.file_access_blocked
            && self.command_blocked
            && self.runtime_probe_blocked
            && self.route_mutation_blocked
    }
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:byte-ledger
// Plane: Verification.
// Residency: every live byte counter stays zero for this metadata witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatEnvelopeByteLedger {
    pub metadata_bytes_read: u64,
    pub owner_manifest_bytes_read: u64,
    pub owner_path_bytes_read: u64,
    pub local_file_bytes_read: u64,
    pub selected_artifact_bytes_resident: u64,
    pub kv_cache_bytes_allocated: u64,
    pub runtime_workspace_bytes_allocated: u64,
    pub app_memory_bytes_reserved: u64,
    pub path_canonicalization_attempts: u64,
    pub file_stat_calls: u64,
    pub file_hash_attempts: u64,
    pub symlink_resolution_attempts: u64,
    pub command_execution_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub first_token_attempts: u64,
    pub benchmark_runs: u64,
}

impl GemmaQatEnvelopeByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            owner_manifest_bytes_read: 0,
            owner_path_bytes_read: 0,
            local_file_bytes_read: 0,
            selected_artifact_bytes_resident: 0,
            kv_cache_bytes_allocated: 0,
            runtime_workspace_bytes_allocated: 0,
            app_memory_bytes_reserved: 0,
            path_canonicalization_attempts: 0,
            file_stat_calls: 0,
            file_hash_attempts: 0,
            symlink_resolution_attempts: 0,
            command_execution_count: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            first_token_attempts: 0,
            benchmark_runs: 0,
        }
    }

    fn live_bytes_or_actions_observed(&self) -> bool {
        self.owner_manifest_bytes_read != 0
            || self.owner_path_bytes_read != 0
            || self.local_file_bytes_read != 0
            || self.selected_artifact_bytes_resident != 0
            || self.kv_cache_bytes_allocated != 0
            || self.runtime_workspace_bytes_allocated != 0
            || self.app_memory_bytes_reserved != 0
            || self.path_canonicalization_attempts != 0
            || self.file_stat_calls != 0
            || self.file_hash_attempts != 0
            || self.symlink_resolution_attempts != 0
            || self.command_execution_count != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.first_token_attempts != 0
            || self.benchmark_runs != 0
    }
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:card
// Plane: State + Assembly + Controller + Verification.
// Residency: per-Gemma warmup card; no local file or runtime residency.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatByteKvAppEnvelopeCard {
    pub card_id: String,
    pub upstream_manifest_ref: String,
    pub upstream_manifest_card_id: String,
    pub model_id: String,
    pub selected_filename_ref: String,
    pub runtime_lanes: Vec<GemmaFamilyRuntimeLane>,
    pub state: GemmaQatEnvelopeState,
    pub action: GemmaQatEnvelopeAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub byte_plan: GemmaQatEnvelopeBytePlan,
    pub policy: GemmaQatEnvelopePolicy,
    pub byte_ledger: GemmaQatEnvelopeByteLedger,
    pub proof_refs: GemmaQatEnvelopeProofRefs,
    pub owner_approval_granted: bool,
    pub owner_manifest_present: bool,
    pub owner_path_present: bool,
    pub local_artifact_verified: bool,
    pub path_canonicalization_allowed: bool,
    pub file_access_allowed: bool,
    pub file_hash_allowed: bool,
    pub command_envelope_armed: bool,
    pub runtime_probe_allowed: bool,
    pub route_mutation_allowed: bool,
    pub selected_bytes_become_resident_claim: bool,
    pub first_token_claimed: bool,
    pub quality_claimed: bool,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_capability_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:ledger
// Plane: State + Verification.
// Residency: metadata-only envelope ledger for E2B/E4B warmup lanes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatByteKvAppEnvelopeLedger {
    pub ledger_address: UasAddress,
    pub upstream_manifest_address: String,
    pub upstream_manifest_ref: String,
    pub cards: Vec<GemmaQatByteKvAppEnvelopeCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub owner_approval_required: bool,
    pub redacted_first_token_probe_required: bool,
    pub runtime_probe_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:metrics
// Plane: Verification.
// Residency: derived counters; no runtime residency.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatByteKvAppEnvelopeMetrics {
    pub card_count: u64,
    pub gguf_lane_count: u64,
    pub litert_lane_count: u64,
    pub selected_artifact_bytes_total: u64,
    pub kv_cache_floor_bytes_total: u64,
    pub runtime_workspace_bytes_total: u64,
    pub app_headroom_bytes_total: u64,
    pub metadata_side_table_bytes_total: u64,
    pub planned_total_envelope_bytes: u64,
    pub probe_candidate_count: u64,
    pub tight_candidate_count: u64,
    pub owner_approval_granted_count: u64,
    pub owner_manifest_present_count: u64,
    pub local_artifact_verified_count: u64,
    pub path_canonicalization_allowed_count: u64,
    pub file_access_allowed_count: u64,
    pub file_hash_allowed_count: u64,
    pub command_envelope_armed_count: u64,
    pub runtime_probe_allowed_count: u64,
    pub route_mutation_allowed_count: u64,
    pub selected_bytes_become_resident_claim_count: u64,
    pub first_token_claim_count: u64,
    pub quality_claim_count: u64,
    pub owner_manifest_bytes_read_total: u64,
    pub owner_path_bytes_read_total: u64,
    pub local_file_bytes_read_total: u64,
    pub selected_artifact_bytes_resident_total: u64,
    pub kv_cache_bytes_allocated_total: u64,
    pub runtime_workspace_bytes_allocated_total: u64,
    pub app_memory_bytes_reserved_total: u64,
    pub file_hash_attempts_total: u64,
    pub command_execution_count_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub first_token_attempts_total: u64,
    pub benchmark_runs_total: u64,
    pub metadata_bytes_read_total: u64,
    pub mas_promotion_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub product_capability_claim_count: u64,
    pub hidden_cloud_fallback_count: u64,
    pub hidden_route_authority_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

impl GemmaQatByteKvAppEnvelopeLedger {
    pub fn new(
        upstream_manifest_address: impl Into<String>,
        upstream_manifest_ref: impl Into<String>,
        mut cards: Vec<GemmaQatByteKvAppEnvelopeCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatByteKvAppEnvelopeError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let upstream_manifest_address = upstream_manifest_address.into();
        let upstream_manifest_ref = upstream_manifest_ref.into();
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_CURSOR.to_string()),
                envelope_ledger_preimage(
                    &upstream_manifest_address,
                    &upstream_manifest_ref,
                    &cards,
                    metadata_bytes,
                )
                .as_bytes(),
                created_at_ms,
            ),
            upstream_manifest_address,
            upstream_manifest_ref,
            cards,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            metadata_only: true,
            owner_approval_required: true,
            redacted_first_token_probe_required: true,
            runtime_probe_deferred: true,
            product_promotion_blocked: true,
            metadata_bytes,
        };
        ledger.validate()?;
        Ok(ledger)
    }

    pub fn validate(&self) -> Result<(), GemmaQatByteKvAppEnvelopeError> {
        if self.upstream_manifest_address.trim().is_empty()
            || !self
                .upstream_manifest_ref
                .starts_with(UPSTREAM_MANIFEST_PREFIX)
        {
            return Err(GemmaQatByteKvAppEnvelopeError::BadUpstreamManifestRef);
        }
        if self.cards.is_empty() {
            return Err(GemmaQatByteKvAppEnvelopeError::EmptyCardSet);
        }
        if self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatByteKvAppEnvelopeError::MetadataBudgetExceeded);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaQatByteKvAppEnvelopeError::PromotionClaim);
        }
        if !self.metadata_only
            || !self.owner_approval_required
            || !self.redacted_first_token_probe_required
            || !self.runtime_probe_deferred
            || !self.product_promotion_blocked
        {
            return Err(GemmaQatByteKvAppEnvelopeError::UnsafeLedgerState);
        }

        let mut card_ids = HashSet::new();
        let mut model_ids = HashSet::new();
        for card in &self.cards {
            validate_card(card)?;
            if !card_ids.insert(card.card_id.as_str()) {
                return Err(GemmaQatByteKvAppEnvelopeError::DuplicateCardId(
                    card.card_id.clone(),
                ));
            }
            if !model_ids.insert(card.model_id.as_str()) {
                return Err(GemmaQatByteKvAppEnvelopeError::DuplicateModelId(
                    card.model_id.clone(),
                ));
            }
        }
        if !model_ids.contains("google/gemma-4-E2B-it-qat-q4_0-gguf")
            || !model_ids.contains("google/gemma-4-E4B-it-qat-q4_0-gguf")
            || model_ids.len() != 2
        {
            return Err(GemmaQatByteKvAppEnvelopeError::SmallLanePackMismatch);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatByteKvAppEnvelopeMetrics {
        let mut metrics = GemmaQatByteKvAppEnvelopeMetrics {
            card_count: self.cards.len() as u64,
            gguf_lane_count: 0,
            litert_lane_count: 0,
            selected_artifact_bytes_total: 0,
            kv_cache_floor_bytes_total: 0,
            runtime_workspace_bytes_total: 0,
            app_headroom_bytes_total: 0,
            metadata_side_table_bytes_total: 0,
            planned_total_envelope_bytes: 0,
            probe_candidate_count: 0,
            tight_candidate_count: 0,
            owner_approval_granted_count: 0,
            owner_manifest_present_count: 0,
            local_artifact_verified_count: 0,
            path_canonicalization_allowed_count: 0,
            file_access_allowed_count: 0,
            file_hash_allowed_count: 0,
            command_envelope_armed_count: 0,
            runtime_probe_allowed_count: 0,
            route_mutation_allowed_count: 0,
            selected_bytes_become_resident_claim_count: 0,
            first_token_claim_count: 0,
            quality_claim_count: 0,
            owner_manifest_bytes_read_total: 0,
            owner_path_bytes_read_total: 0,
            local_file_bytes_read_total: 0,
            selected_artifact_bytes_resident_total: 0,
            kv_cache_bytes_allocated_total: 0,
            runtime_workspace_bytes_allocated_total: 0,
            app_memory_bytes_reserved_total: 0,
            file_hash_attempts_total: 0,
            command_execution_count_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            first_token_attempts_total: 0,
            benchmark_runs_total: 0,
            metadata_bytes_read_total: self.metadata_bytes,
            mas_promotion_count: 0,
            l2_green_claim_count: 0,
            l3_green_claim_count: 0,
            product_capability_claim_count: 0,
            hidden_cloud_fallback_count: 0,
            hidden_route_authority_count: 0,
            live_dense_70b_claim_count: 0,
            ssd_as_ram_claim_count: 0,
        };
        for card in &self.cards {
            metrics.gguf_lane_count += u64::from(
                card.runtime_lanes
                    .contains(&GemmaFamilyRuntimeLane::GgufLlamaCpp),
            );
            metrics.litert_lane_count += u64::from(
                card.runtime_lanes
                    .contains(&GemmaFamilyRuntimeLane::LiteRtLm),
            );
            metrics.selected_artifact_bytes_total += card.byte_plan.selected_artifact_bytes;
            metrics.kv_cache_floor_bytes_total += card.byte_plan.kv_cache_floor_bytes;
            metrics.runtime_workspace_bytes_total += card.byte_plan.runtime_workspace_bytes;
            metrics.app_headroom_bytes_total += card.byte_plan.app_headroom_bytes;
            metrics.metadata_side_table_bytes_total += card.byte_plan.metadata_side_table_bytes;
            metrics.planned_total_envelope_bytes += card.byte_plan.planned_total_envelope_bytes;
            metrics.probe_candidate_count +=
                u64::from(card.byte_plan.current_m2pro_16gb_probe_candidate);
            metrics.tight_candidate_count +=
                u64::from(card.byte_plan.tight_candidate_requires_fresh_memory_sample);
            metrics.owner_approval_granted_count += u64::from(card.owner_approval_granted);
            metrics.owner_manifest_present_count += u64::from(card.owner_manifest_present);
            metrics.local_artifact_verified_count += u64::from(card.local_artifact_verified);
            metrics.path_canonicalization_allowed_count +=
                u64::from(card.path_canonicalization_allowed);
            metrics.file_access_allowed_count += u64::from(card.file_access_allowed);
            metrics.file_hash_allowed_count += u64::from(card.file_hash_allowed);
            metrics.command_envelope_armed_count += u64::from(card.command_envelope_armed);
            metrics.runtime_probe_allowed_count += u64::from(card.runtime_probe_allowed);
            metrics.route_mutation_allowed_count += u64::from(card.route_mutation_allowed);
            metrics.selected_bytes_become_resident_claim_count +=
                u64::from(card.selected_bytes_become_resident_claim);
            metrics.first_token_claim_count += u64::from(card.first_token_claimed);
            metrics.quality_claim_count += u64::from(card.quality_claimed);
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
            metrics.owner_path_bytes_read_total += card.byte_ledger.owner_path_bytes_read;
            metrics.local_file_bytes_read_total += card.byte_ledger.local_file_bytes_read;
            metrics.selected_artifact_bytes_resident_total +=
                card.byte_ledger.selected_artifact_bytes_resident;
            metrics.kv_cache_bytes_allocated_total += card.byte_ledger.kv_cache_bytes_allocated;
            metrics.runtime_workspace_bytes_allocated_total +=
                card.byte_ledger.runtime_workspace_bytes_allocated;
            metrics.app_memory_bytes_reserved_total += card.byte_ledger.app_memory_bytes_reserved;
            metrics.file_hash_attempts_total += card.byte_ledger.file_hash_attempts;
            metrics.command_execution_count_total += card.byte_ledger.command_execution_count;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.first_token_attempts_total += card.byte_ledger.first_token_attempts;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
            metrics.metadata_bytes_read_total += card.byte_ledger.metadata_bytes_read;
            metrics.mas_promotion_count += u64::from(card.mas_promoted);
            metrics.l2_green_claim_count += u64::from(card.l2_green_claimed);
            metrics.l3_green_claim_count += u64::from(card.l3_green_claimed);
            metrics.product_capability_claim_count += u64::from(card.product_capability_claimed);
            metrics.hidden_cloud_fallback_count += u64::from(card.hidden_cloud_fallback_allowed);
            metrics.hidden_route_authority_count += u64::from(card.hidden_route_authority_allowed);
            metrics.live_dense_70b_claim_count += u64::from(card.live_dense_70b_claimed);
            metrics.ssd_as_ram_claim_count += u64::from(card.ssd_as_ram_claimed);
        }
        metrics
    }
}

pub fn canonical_gemma_qat_byte_kv_app_envelope_cards(
    upstream_manifest_ref: &str,
) -> Vec<GemmaQatByteKvAppEnvelopeCard> {
    canonical_gemma_qat_small_lane_owner_path_manifest_cards(upstream_manifest_ref)
        .into_iter()
        .map(|manifest| {
            let spec = envelope_spec(&manifest.card_id, manifest.declared_file_bytes);
            envelope_card(
                upstream_manifest_ref,
                &manifest.card_id,
                &manifest.model_id,
                &manifest.selected_filename_ref,
                manifest.runtime_lanes,
                spec,
            )
        })
        .collect()
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:spec
// Plane: State.
// Residency: static envelope construction helper; no runtime residency.
#[derive(Clone, Copy)]
struct EnvelopeSpec {
    card_suffix: &'static str,
    kv_cache_floor_bytes: u64,
    runtime_workspace_bytes: u64,
    app_headroom_bytes: u64,
    metadata_side_table_bytes: u64,
    tight_candidate: bool,
    metadata_bytes: u64,
}

fn envelope_spec(manifest_card_id: &str, declared_file_bytes: u64) -> EnvelopeSpec {
    match (manifest_card_id, declared_file_bytes) {
        ("gemma4_e2b_qat_owner_path_manifest", 4_628_569_635) => EnvelopeSpec {
            card_suffix: "e2b",
            kv_cache_floor_bytes: 512 * 1024 * 1024,
            runtime_workspace_bytes: 768 * 1024 * 1024,
            app_headroom_bytes: 4 * 1024 * 1024 * 1024,
            metadata_side_table_bytes: 64 * 1024 * 1024,
            tight_candidate: false,
            metadata_bytes: 22_000,
        },
        ("gemma4_e4b_qat_owner_path_manifest", 7_463_013_674) => EnvelopeSpec {
            card_suffix: "e4b",
            kv_cache_floor_bytes: 768 * 1024 * 1024,
            runtime_workspace_bytes: 1024 * 1024 * 1024,
            app_headroom_bytes: 4 * 1024 * 1024 * 1024,
            metadata_side_table_bytes: 128 * 1024 * 1024,
            tight_candidate: true,
            metadata_bytes: 22_000,
        },
        _ => EnvelopeSpec {
            card_suffix: "invalid",
            kv_cache_floor_bytes: 0,
            runtime_workspace_bytes: 0,
            app_headroom_bytes: 0,
            metadata_side_table_bytes: 0,
            tight_candidate: true,
            metadata_bytes: MAX_CARD_METADATA_BYTES + 1,
        },
    }
}

fn envelope_card(
    upstream_manifest_ref: &str,
    upstream_manifest_card_id: &str,
    model_id: &str,
    selected_filename_ref: &str,
    runtime_lanes: Vec<GemmaFamilyRuntimeLane>,
    spec: EnvelopeSpec,
) -> GemmaQatByteKvAppEnvelopeCard {
    let card_id = format!("gemma4_{}_qat_byte_kv_app_envelope", spec.card_suffix);
    let state = if spec.tight_candidate {
        GemmaQatEnvelopeState::TightProbeCandidateNeedsFreshMemorySample
    } else {
        GemmaQatEnvelopeState::ProbeCandidateAfterOwnerApproval
    };
    GemmaQatByteKvAppEnvelopeCard {
        card_id: card_id.clone(),
        upstream_manifest_ref: upstream_manifest_ref.to_string(),
        upstream_manifest_card_id: upstream_manifest_card_id.to_string(),
        model_id: model_id.to_string(),
        selected_filename_ref: selected_filename_ref.to_string(),
        runtime_lanes,
        state,
        action: GemmaQatEnvelopeAction::CompileByteKvAppEnvelopePreflight,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::Gated,
        byte_plan: GemmaQatEnvelopeBytePlan::new(
            selected_file_bytes(model_id),
            spec.kv_cache_floor_bytes,
            spec.runtime_workspace_bytes,
            spec.app_headroom_bytes,
            spec.metadata_side_table_bytes,
            spec.tight_candidate,
        ),
        policy: GemmaQatEnvelopePolicy::warmup_candidate(spec.tight_candidate),
        byte_ledger: GemmaQatEnvelopeByteLedger::metadata_only(spec.metadata_bytes),
        proof_refs: proof_refs(upstream_manifest_ref, &card_id),
        owner_approval_granted: false,
        owner_manifest_present: false,
        owner_path_present: false,
        local_artifact_verified: false,
        path_canonicalization_allowed: false,
        file_access_allowed: false,
        file_hash_allowed: false,
        command_envelope_armed: false,
        runtime_probe_allowed: false,
        route_mutation_allowed: false,
        selected_bytes_become_resident_claim: false,
        first_token_claimed: false,
        quality_claimed: false,
        mas_promoted: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        product_capability_claimed: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

fn selected_file_bytes(model_id: &str) -> u64 {
    match model_id {
        "google/gemma-4-E2B-it-qat-q4_0-gguf" => 4_628_569_635,
        "google/gemma-4-E4B-it-qat-q4_0-gguf" => 7_463_013_674,
        _ => 0,
    }
}

fn proof_refs(upstream_manifest_ref: &str, card_id: &str) -> GemmaQatEnvelopeProofRefs {
    GemmaQatEnvelopeProofRefs {
        upstream_manifest_ref: upstream_manifest_ref.to_string(),
        byte_envelope_ref: format!("{BYTE_ENVELOPE_PREFIX}{card_id}"),
        kv_cache_ref: format!("{KV_CACHE_PREFIX}{card_id}"),
        runtime_workspace_ref: format!("{RUNTIME_WORKSPACE_PREFIX}{card_id}"),
        app_headroom_ref: format!("{APP_HEADROOM_PREFIX}{card_id}"),
        cancellation_ref: format!("{CANCELLATION_PREFIX}{card_id}"),
        rollback_ref: format!("{ROLLBACK_PREFIX}{card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{card_id}"),
        abstention_ref: format!("{ABSTENTION_PREFIX}{card_id}"),
        sovereign_gate_ref: format!("{SOVEREIGN_GATE_PREFIX}{card_id}"),
        compatibility_fence_ref: format!("{COMPATIBILITY_FENCE_PREFIX}{card_id}"),
    }
}

fn validate_card(
    card: &GemmaQatByteKvAppEnvelopeCard,
) -> Result<(), GemmaQatByteKvAppEnvelopeError> {
    if card.card_id.trim().is_empty() {
        return Err(GemmaQatByteKvAppEnvelopeError::BadCardId);
    }
    if !card
        .upstream_manifest_ref
        .starts_with(UPSTREAM_MANIFEST_PREFIX)
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadUpstreamManifestRef);
    }
    if !card
        .upstream_manifest_card_id
        .ends_with("_owner_path_manifest")
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadUpstreamManifestCard);
    }
    if !card.model_id.starts_with("google/gemma-4-")
        || !(card.model_id.contains("E2B") || card.model_id.contains("E4B"))
    {
        return Err(GemmaQatByteKvAppEnvelopeError::SmallLanePackMismatch);
    }
    if !card.selected_filename_ref.starts_with("hf_file:")
        || !card.selected_filename_ref.ends_with(".gguf")
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadSourceRef);
    }
    if !card
        .runtime_lanes
        .contains(&GemmaFamilyRuntimeLane::GgufLlamaCpp)
        || !card
            .runtime_lanes
            .contains(&GemmaFamilyRuntimeLane::LiteRtLm)
    {
        return Err(GemmaQatByteKvAppEnvelopeError::MissingRuntimeLane);
    }
    if card.action != GemmaQatEnvelopeAction::CompileByteKvAppEnvelopePreflight
        || card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::Gated
    {
        return Err(GemmaQatByteKvAppEnvelopeError::PromotionClaim);
    }
    validate_byte_plan(card)?;
    if !card.policy.complete() {
        return Err(GemmaQatByteKvAppEnvelopeError::IncompletePolicy);
    }
    validate_proof_refs(&card.proof_refs)?;
    if card.byte_ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(GemmaQatByteKvAppEnvelopeError::MetadataBudgetExceeded);
    }
    if card.byte_ledger.live_bytes_or_actions_observed() {
        return Err(GemmaQatByteKvAppEnvelopeError::BytesOrCommandsObserved);
    }
    if card.owner_approval_granted
        || card.owner_manifest_present
        || card.owner_path_present
        || card.local_artifact_verified
        || card.path_canonicalization_allowed
        || card.file_access_allowed
        || card.file_hash_allowed
        || card.command_envelope_armed
        || card.runtime_probe_allowed
        || card.route_mutation_allowed
        || card.selected_bytes_become_resident_claim
        || card.first_token_claimed
        || card.quality_claimed
    {
        return Err(GemmaQatByteKvAppEnvelopeError::UnsafeEnvelopeState);
    }
    if card.mas_promoted
        || card.l2_green_claimed
        || card.l3_green_claimed
        || card.product_capability_claimed
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(GemmaQatByteKvAppEnvelopeError::PromotionClaim);
    }
    Ok(())
}

fn validate_byte_plan(
    card: &GemmaQatByteKvAppEnvelopeCard,
) -> Result<(), GemmaQatByteKvAppEnvelopeError> {
    let expected_selected_bytes = selected_file_bytes(&card.model_id);
    if expected_selected_bytes == 0
        || card.byte_plan.declared_file_bytes != expected_selected_bytes
        || card.byte_plan.selected_artifact_bytes != expected_selected_bytes
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadBytePlan);
    }
    if card.byte_plan.kv_cache_floor_bytes == 0
        || card.byte_plan.runtime_workspace_bytes == 0
        || card.byte_plan.app_headroom_bytes < 4 * 1024 * 1024 * 1024
        || card.byte_plan.metadata_side_table_bytes == 0
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadBytePlan);
    }
    if card.byte_plan.planned_total_envelope_bytes != card.byte_plan.recomputed_total() {
        return Err(GemmaQatByteKvAppEnvelopeError::TotalEnvelopeMismatch);
    }
    if card.byte_plan.m2pro_16gb_uma_bytes != M2_PRO_16GB_UMA_BYTES {
        return Err(GemmaQatByteKvAppEnvelopeError::BadHardwareEnvelope);
    }
    if card.byte_plan.current_m2pro_16gb_probe_candidate
        != (card.byte_plan.planned_total_envelope_bytes <= M2_PRO_16GB_UMA_BYTES)
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadHardwareEnvelope);
    }
    if card.model_id.contains("E4B")
        && (!card.byte_plan.tight_candidate_requires_fresh_memory_sample
            || card.state != GemmaQatEnvelopeState::TightProbeCandidateNeedsFreshMemorySample)
    {
        return Err(GemmaQatByteKvAppEnvelopeError::TightCandidateMissingFreshSample);
    }
    if card.model_id.contains("E2B")
        && (card.byte_plan.tight_candidate_requires_fresh_memory_sample
            || card.state != GemmaQatEnvelopeState::ProbeCandidateAfterOwnerApproval)
    {
        return Err(GemmaQatByteKvAppEnvelopeError::BadHardwareEnvelope);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatEnvelopeProofRefs,
) -> Result<(), GemmaQatByteKvAppEnvelopeError> {
    let ok = refs
        .upstream_manifest_ref
        .starts_with(UPSTREAM_MANIFEST_PREFIX)
        && refs.byte_envelope_ref.starts_with(BYTE_ENVELOPE_PREFIX)
        && refs.kv_cache_ref.starts_with(KV_CACHE_PREFIX)
        && refs
            .runtime_workspace_ref
            .starts_with(RUNTIME_WORKSPACE_PREFIX)
        && refs.app_headroom_ref.starts_with(APP_HEADROOM_PREFIX)
        && refs.cancellation_ref.starts_with(CANCELLATION_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
        && refs.abstention_ref.starts_with(ABSTENTION_PREFIX)
        && refs.sovereign_gate_ref.starts_with(SOVEREIGN_GATE_PREFIX)
        && refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_FENCE_PREFIX);
    if ok {
        Ok(())
    } else {
        Err(GemmaQatByteKvAppEnvelopeError::BadProofRef)
    }
}

fn envelope_ledger_preimage(
    upstream_manifest_address: &str,
    upstream_manifest_ref: &str,
    cards: &[GemmaQatByteKvAppEnvelopeCard],
    metadata_bytes: u64,
) -> String {
    serde_json::json!({
        "cursor": GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_CURSOR,
        "upstream_manifest_address": upstream_manifest_address,
        "upstream_manifest_ref": upstream_manifest_ref,
        "cards": cards,
        "metadata_bytes": metadata_bytes,
    })
    .to_string()
}

// UAS: uas:gemma-qat-byte-kv-app-envelope:error
// Plane: Verification.
// Residency: fail-closed rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatByteKvAppEnvelopeError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelId(String),
    BadCardId,
    BadUpstreamManifestRef,
    BadUpstreamManifestCard,
    BadSourceRef,
    MissingRuntimeLane,
    BadBytePlan,
    TotalEnvelopeMismatch,
    BadHardwareEnvelope,
    TightCandidateMissingFreshSample,
    IncompletePolicy,
    BadProofRef,
    SmallLanePackMismatch,
    UnsafeLedgerState,
    UnsafeEnvelopeState,
    BytesOrCommandsObserved,
    PromotionClaim,
    MetadataBudgetExceeded,
}

impl fmt::Display for GemmaQatByteKvAppEnvelopeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "empty card set"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id {id}"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id {id}"),
            Self::BadCardId => write!(f, "bad card id"),
            Self::BadUpstreamManifestRef => write!(f, "bad upstream manifest ref"),
            Self::BadUpstreamManifestCard => write!(f, "bad upstream manifest card"),
            Self::BadSourceRef => write!(f, "bad source ref"),
            Self::MissingRuntimeLane => write!(f, "missing runtime lane"),
            Self::BadBytePlan => write!(f, "bad byte plan"),
            Self::TotalEnvelopeMismatch => write!(f, "total envelope mismatch"),
            Self::BadHardwareEnvelope => write!(f, "bad hardware envelope"),
            Self::TightCandidateMissingFreshSample => {
                write!(f, "tight candidate missing fresh memory sample")
            }
            Self::IncompletePolicy => write!(f, "incomplete policy"),
            Self::BadProofRef => write!(f, "bad proof ref"),
            Self::SmallLanePackMismatch => write!(f, "small lane pack mismatch"),
            Self::UnsafeLedgerState => write!(f, "unsafe ledger state"),
            Self::UnsafeEnvelopeState => write!(f, "unsafe envelope state"),
            Self::BytesOrCommandsObserved => write!(f, "bytes or commands observed"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for GemmaQatByteKvAppEnvelopeError {}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_small_lane_owner_path_manifest/result.json#F-GemmaQATSmallLaneOwnerPathManifest";

    fn ledger() -> Result<GemmaQatByteKvAppEnvelopeLedger, GemmaQatByteKvAppEnvelopeError> {
        GemmaQatByteKvAppEnvelopeLedger::new(
            "uas:gemma-qatsmall-manifest:test",
            UPSTREAM_REF,
            canonical_gemma_qat_byte_kv_app_envelope_cards(UPSTREAM_REF),
            84_000,
            1_779_211_000_000,
        )
    }

    #[test]
    fn canonical_envelope_validates_and_stays_metadata_only() {
        let Ok(ledger) = ledger() else {
            panic!("canonical ledger should validate");
        };
        let metrics = ledger.metrics();
        assert_eq!(metrics.card_count, 2);
        assert_eq!(metrics.selected_artifact_bytes_total, 12_091_583_309);
        assert_eq!(metrics.kv_cache_floor_bytes_total, 1_342_177_280);
        assert_eq!(metrics.runtime_workspace_bytes_total, 1_879_048_192);
        assert_eq!(metrics.app_headroom_bytes_total, 8_589_934_592);
        assert_eq!(metrics.probe_candidate_count, 2);
        assert_eq!(metrics.tight_candidate_count, 1);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
        assert_eq!(metrics.first_token_attempts_total, 0);
        assert_eq!(metrics.product_capability_claim_count, 0);
    }

    #[test]
    fn rejects_twelve_b_or_duplicate_ids() {
        let mut cards = canonical_gemma_qat_byte_kv_app_envelope_cards(UPSTREAM_REF);
        cards[0].model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
        assert!(GemmaQatByteKvAppEnvelopeLedger::new(
            "uas:gemma-qatsmall-manifest:test",
            UPSTREAM_REF,
            cards,
            84_000,
            1_779_211_000_000,
        )
        .is_err());

        let mut cards = canonical_gemma_qat_byte_kv_app_envelope_cards(UPSTREAM_REF);
        cards[1].model_id = cards[0].model_id.clone();
        assert!(GemmaQatByteKvAppEnvelopeLedger::new(
            "uas:gemma-qatsmall-manifest:test",
            UPSTREAM_REF,
            cards,
            84_000,
            1_779_211_000_000,
        )
        .is_err());
    }

    #[test]
    fn rejects_runtime_or_product_shortcuts() {
        let mut cards = canonical_gemma_qat_byte_kv_app_envelope_cards(UPSTREAM_REF);
        cards[0].runtime_probe_allowed = true;
        assert!(GemmaQatByteKvAppEnvelopeLedger::new(
            "uas:gemma-qatsmall-manifest:test",
            UPSTREAM_REF,
            cards,
            84_000,
            1_779_211_000_000,
        )
        .is_err());

        let mut cards = canonical_gemma_qat_byte_kv_app_envelope_cards(UPSTREAM_REF);
        cards[0].l2_green_claimed = true;
        assert!(GemmaQatByteKvAppEnvelopeLedger::new(
            "uas:gemma-qatsmall-manifest:test",
            UPSTREAM_REF,
            cards,
            84_000,
            1_779_211_000_000,
        )
        .is_err());
    }
}
