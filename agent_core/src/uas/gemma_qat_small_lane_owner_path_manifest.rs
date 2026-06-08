//! Gemma QAT small-lane owner path manifest gate.
//!
//! This primitive defines the owner-provided path manifest contract for the
//! Gemma 4 E2B/E4B QAT warmup lanes. It does not read an owner manifest, store
//! a raw path, canonicalize a path, stat/hash a file, load model/runtime bytes,
//! arm a command, or promote Gemma to a live product route.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind};

pub const GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_ID: &str =
    "F-GemmaQATSmallLaneOwnerPathManifest";
pub const GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_CURSOR: &str =
    "gemma_qat_small_lane_owner_path_manifest";
pub const GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_NEXT_CURSOR: &str =
    "gemma_qat_byte_kv_app_envelope_preflight";

const UPSTREAM_POLICY_PREFIX: &str = "artifact:falsifiers/gemma_main_family_policy_source_card/";
const CANDIDATE_REF_PREFIX: &str = "gemma_qat_candidate:";
const SOURCE_REVISION_PREFIX: &str = "hf_revision:";
const SOURCE_FILE_PREFIX: &str = "hf_file:";
const XET_OR_LFS_PREFIX: &str = "hf_xet_or_lfs:";
const MANIFEST_SCHEMA_PREFIX: &str = "owner_manifest_schema:gemma_qat_small_lane:";
const PATH_POLICY_PREFIX: &str = "path_policy:owner_absolute_no_expansion:gemma_qat:";
const BYTE_PLAN_PREFIX: &str = "byte_plan:gemma_qat_small_lane:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:unarmed:gemma_qat_small_lane:";
const ROLLBACK_PREFIX: &str = "rollback:gemma_qat_small_lane:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:gemma_qat_small_lane:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:gemma_qat_small_lane:";
const ABSTENTION_PREFIX: &str = "abstention:gemma_qat_small_lane:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:gemma_qat_small_lane:";
const MAX_LEDGER_METADATA_BYTES: u64 = 256 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 80 * 1024;

// UAS: uas:gemma-qat-small-lane-owner-manifest:state
// Plane: Verification.
// Residency: manifest state only; no owner path bytes are read.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatSmallLaneManifestState {
    SchemaRequiredOwnerManifestMissing,
    OwnerManifestApproved,
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:action
// Plane: Controller.
// Residency: admission action stays unarmed until later owner-approved probes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatSmallLaneManifestAction {
    DefineOwnerManifestContract,
    AllowRuntimeProbe,
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:required-fields
// Plane: Verification.
// Residency: future manifest schema, not current local-path evidence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSmallLaneManifestRequiredFields {
    pub model_id: bool,
    pub source_revision: bool,
    pub selected_filename: bool,
    pub declared_file_bytes: bool,
    pub owner_path_digest: bool,
    pub canonical_path_digest: bool,
    pub file_hash_after_owner_approval: bool,
    pub no_raw_path_storage: bool,
    pub no_symlink_follow_without_gate: bool,
    pub byte_kv_app_envelope_ref: bool,
    pub cancellation_ref: bool,
    pub rollback_ref: bool,
    pub run_event_log_ref: bool,
    pub answer_packet_ref: bool,
    pub abstention_ref: bool,
    pub compatibility_fence_ref: bool,
    pub no_promotion: bool,
}

impl GemmaQatSmallLaneManifestRequiredFields {
    pub fn all_required() -> Self {
        Self {
            model_id: true,
            source_revision: true,
            selected_filename: true,
            declared_file_bytes: true,
            owner_path_digest: true,
            canonical_path_digest: true,
            file_hash_after_owner_approval: true,
            no_raw_path_storage: true,
            no_symlink_follow_without_gate: true,
            byte_kv_app_envelope_ref: true,
            cancellation_ref: true,
            rollback_ref: true,
            run_event_log_ref: true,
            answer_packet_ref: true,
            abstention_ref: true,
            compatibility_fence_ref: true,
            no_promotion: true,
        }
    }

    fn all_present(&self) -> bool {
        self.model_id
            && self.source_revision
            && self.selected_filename
            && self.declared_file_bytes
            && self.owner_path_digest
            && self.canonical_path_digest
            && self.file_hash_after_owner_approval
            && self.no_raw_path_storage
            && self.no_symlink_follow_without_gate
            && self.byte_kv_app_envelope_ref
            && self.cancellation_ref
            && self.rollback_ref
            && self.run_event_log_ref
            && self.answer_packet_ref
            && self.abstention_ref
            && self.compatibility_fence_ref
            && self.no_promotion
    }
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:proof-refs
// Plane: Verification.
// Residency: visible proof handles only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSmallLaneManifestProofRefs {
    pub manifest_schema_ref: String,
    pub path_policy_ref: String,
    pub byte_plan_ref: String,
    pub command_envelope_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:byte-ledger
// Plane: Verification.
// Residency: all live owner-path/model/runtime counters stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSmallLaneManifestByteLedger {
    pub metadata_bytes_read: u64,
    pub owner_manifest_bytes_read: u64,
    pub raw_owner_path_bytes_stored: u64,
    pub canonical_path_bytes_stored: u64,
    pub path_canonicalization_attempts: u64,
    pub local_path_open_attempts: u64,
    pub file_stat_calls: u64,
    pub file_hash_attempts: u64,
    pub symlink_resolution_attempts: u64,
    pub command_execution_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl GemmaQatSmallLaneManifestByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            owner_manifest_bytes_read: 0,
            raw_owner_path_bytes_stored: 0,
            canonical_path_bytes_stored: 0,
            path_canonicalization_attempts: 0,
            local_path_open_attempts: 0,
            file_stat_calls: 0,
            file_hash_attempts: 0,
            symlink_resolution_attempts: 0,
            command_execution_count: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }

    fn live_bytes_or_actions_observed(&self) -> bool {
        self.owner_manifest_bytes_read != 0
            || self.raw_owner_path_bytes_stored != 0
            || self.canonical_path_bytes_stored != 0
            || self.path_canonicalization_attempts != 0
            || self.local_path_open_attempts != 0
            || self.file_stat_calls != 0
            || self.file_hash_attempts != 0
            || self.symlink_resolution_attempts != 0
            || self.command_execution_count != 0
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
    }
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:card
// Plane: State + Assembly + Controller + Verification.
// Residency: small-lane manifest contract only; no model path is trusted.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSmallLaneOwnerPathManifestCard {
    pub card_id: String,
    pub upstream_policy_ref: String,
    pub upstream_candidate_ref: String,
    pub model_id: String,
    pub source_locator: String,
    pub source_revision_ref: String,
    pub selected_filename_ref: String,
    pub xet_or_lfs_ref: String,
    pub declared_file_bytes: u64,
    pub context_window_tokens: u64,
    pub runtime_lanes: Vec<GemmaFamilyRuntimeLane>,
    pub state: GemmaQatSmallLaneManifestState,
    pub action: GemmaQatSmallLaneManifestAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_fields: GemmaQatSmallLaneManifestRequiredFields,
    pub proof_refs: GemmaQatSmallLaneManifestProofRefs,
    pub byte_ledger: GemmaQatSmallLaneManifestByteLedger,
    pub owner_manifest_present: bool,
    pub owner_signature_present: bool,
    pub owner_approval_granted: bool,
    pub raw_owner_path_stored: bool,
    pub canonical_path_bound: bool,
    pub file_open_allowed: bool,
    pub file_hash_allowed: bool,
    pub command_envelope_armed: bool,
    pub runtime_probe_allowed: bool,
    pub route_mutation_allowed: bool,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_capability_claimed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:ledger
// Plane: State + Verification.
// Residency: metadata-only set of small-lane manifest contracts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSmallLaneOwnerPathManifestLedger {
    pub ledger_address: UasAddress,
    pub upstream_policy_address: String,
    pub upstream_policy_ref: String,
    pub cards: Vec<GemmaQatSmallLaneOwnerPathManifestCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_only: bool,
    pub owner_manifest_absent: bool,
    pub path_canonicalization_deferred: bool,
    pub file_access_disallowed: bool,
    pub runtime_probe_deferred: bool,
    pub product_promotion_blocked: bool,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-qat-small-lane-owner-manifest:metrics
// Plane: Verification.
// Residency: derived metadata-only counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatSmallLaneOwnerPathManifestMetrics {
    pub card_count: u64,
    pub gguf_lane_count: u64,
    pub litert_lane_count: u64,
    pub owner_manifest_present_count: u64,
    pub owner_signature_present_count: u64,
    pub owner_approval_granted_count: u64,
    pub raw_owner_path_stored_count: u64,
    pub canonical_path_bound_count: u64,
    pub file_open_allowed_count: u64,
    pub file_hash_allowed_count: u64,
    pub command_envelope_armed_count: u64,
    pub runtime_probe_allowed_count: u64,
    pub route_mutation_allowed_count: u64,
    pub owner_manifest_bytes_read_total: u64,
    pub raw_owner_path_bytes_stored_total: u64,
    pub canonical_path_bytes_stored_total: u64,
    pub path_canonicalization_attempts_total: u64,
    pub local_path_open_attempts_total: u64,
    pub file_stat_calls_total: u64,
    pub file_hash_attempts_total: u64,
    pub symlink_resolution_attempts_total: u64,
    pub command_execution_count_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub declared_file_bytes_total: u64,
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

impl GemmaQatSmallLaneOwnerPathManifestLedger {
    pub fn new(
        upstream_policy_address: impl Into<String>,
        upstream_policy_ref: impl Into<String>,
        mut cards: Vec<GemmaQatSmallLaneOwnerPathManifestCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GemmaQatSmallLaneOwnerPathManifestError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let upstream_policy_address = upstream_policy_address.into();
        let upstream_policy_ref = upstream_policy_ref.into();
        let ledger = Self {
            ledger_address: UasAddress::new(
                UasKind::Other(GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_CURSOR.to_string()),
                manifest_ledger_preimage(
                    &upstream_policy_address,
                    &upstream_policy_ref,
                    &cards,
                    metadata_bytes,
                )
                .as_bytes(),
                created_at_ms,
            ),
            upstream_policy_address,
            upstream_policy_ref,
            cards,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            metadata_only: true,
            owner_manifest_absent: true,
            path_canonicalization_deferred: true,
            file_access_disallowed: true,
            runtime_probe_deferred: true,
            product_promotion_blocked: true,
            metadata_bytes,
        };
        ledger.validate()?;
        Ok(ledger)
    }

    pub fn validate(&self) -> Result<(), GemmaQatSmallLaneOwnerPathManifestError> {
        if self.upstream_policy_address.trim().is_empty()
            || !self.upstream_policy_ref.starts_with(UPSTREAM_POLICY_PREFIX)
        {
            return Err(GemmaQatSmallLaneOwnerPathManifestError::BadUpstreamPolicyRef);
        }
        if self.cards.is_empty() {
            return Err(GemmaQatSmallLaneOwnerPathManifestError::EmptyCardSet);
        }
        if self.metadata_bytes > MAX_LEDGER_METADATA_BYTES {
            return Err(GemmaQatSmallLaneOwnerPathManifestError::MetadataBudgetExceeded);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaQatSmallLaneOwnerPathManifestError::PromotionClaim);
        }
        if !self.metadata_only
            || !self.owner_manifest_absent
            || !self.path_canonicalization_deferred
            || !self.file_access_disallowed
            || !self.runtime_probe_deferred
            || !self.product_promotion_blocked
        {
            return Err(GemmaQatSmallLaneOwnerPathManifestError::UnsafeLedgerState);
        }

        let mut card_ids = HashSet::new();
        let mut model_ids = HashSet::new();
        for card in &self.cards {
            validate_card(card)?;
            if !card_ids.insert(card.card_id.as_str()) {
                return Err(GemmaQatSmallLaneOwnerPathManifestError::DuplicateCardId(
                    card.card_id.clone(),
                ));
            }
            if !model_ids.insert(card.model_id.as_str()) {
                return Err(GemmaQatSmallLaneOwnerPathManifestError::DuplicateModelId(
                    card.model_id.clone(),
                ));
            }
        }
        if !model_ids.contains("google/gemma-4-E2B-it-qat-q4_0-gguf")
            || !model_ids.contains("google/gemma-4-E4B-it-qat-q4_0-gguf")
            || model_ids.len() != 2
        {
            return Err(GemmaQatSmallLaneOwnerPathManifestError::SmallLanePackMismatch);
        }
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatSmallLaneOwnerPathManifestMetrics {
        let mut metrics = GemmaQatSmallLaneOwnerPathManifestMetrics {
            card_count: self.cards.len() as u64,
            gguf_lane_count: 0,
            litert_lane_count: 0,
            owner_manifest_present_count: 0,
            owner_signature_present_count: 0,
            owner_approval_granted_count: 0,
            raw_owner_path_stored_count: 0,
            canonical_path_bound_count: 0,
            file_open_allowed_count: 0,
            file_hash_allowed_count: 0,
            command_envelope_armed_count: 0,
            runtime_probe_allowed_count: 0,
            route_mutation_allowed_count: 0,
            owner_manifest_bytes_read_total: 0,
            raw_owner_path_bytes_stored_total: 0,
            canonical_path_bytes_stored_total: 0,
            path_canonicalization_attempts_total: 0,
            local_path_open_attempts_total: 0,
            file_stat_calls_total: 0,
            file_hash_attempts_total: 0,
            symlink_resolution_attempts_total: 0,
            command_execution_count_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            declared_file_bytes_total: 0,
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
            metrics.owner_manifest_present_count += u64::from(card.owner_manifest_present);
            metrics.owner_signature_present_count += u64::from(card.owner_signature_present);
            metrics.owner_approval_granted_count += u64::from(card.owner_approval_granted);
            metrics.raw_owner_path_stored_count += u64::from(card.raw_owner_path_stored);
            metrics.canonical_path_bound_count += u64::from(card.canonical_path_bound);
            metrics.file_open_allowed_count += u64::from(card.file_open_allowed);
            metrics.file_hash_allowed_count += u64::from(card.file_hash_allowed);
            metrics.command_envelope_armed_count += u64::from(card.command_envelope_armed);
            metrics.runtime_probe_allowed_count += u64::from(card.runtime_probe_allowed);
            metrics.route_mutation_allowed_count += u64::from(card.route_mutation_allowed);
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
            metrics.raw_owner_path_bytes_stored_total +=
                card.byte_ledger.raw_owner_path_bytes_stored;
            metrics.canonical_path_bytes_stored_total +=
                card.byte_ledger.canonical_path_bytes_stored;
            metrics.path_canonicalization_attempts_total +=
                card.byte_ledger.path_canonicalization_attempts;
            metrics.local_path_open_attempts_total += card.byte_ledger.local_path_open_attempts;
            metrics.file_stat_calls_total += card.byte_ledger.file_stat_calls;
            metrics.file_hash_attempts_total += card.byte_ledger.file_hash_attempts;
            metrics.symlink_resolution_attempts_total +=
                card.byte_ledger.symlink_resolution_attempts;
            metrics.command_execution_count_total += card.byte_ledger.command_execution_count;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.declared_file_bytes_total += card.declared_file_bytes;
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

pub fn canonical_gemma_qat_small_lane_owner_path_manifest_cards(
    upstream_policy_ref: &str,
) -> Vec<GemmaQatSmallLaneOwnerPathManifestCard> {
    vec![
        manifest_card(
            SmallLaneSpec {
                card_id: "gemma4_e2b_qat_owner_path_manifest",
                upstream_candidate_ref: "gemma_qat_candidate:gemma4_e2b_qat_gguf_candidate",
                model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
                source_revision: "1894d1fc0a19d86697abd40483f5983c867df03f",
                selected_filename: "gemma-4-E2B_q4_0-it.gguf",
                xet_or_lfs: "hf_xet_or_lfs:gemma4-e2b-q4_0-source-card",
                declared_file_bytes: 4_628_569_635,
                context_window_tokens: 131_072,
                metadata_bytes: 18_000,
            },
            upstream_policy_ref,
        ),
        manifest_card(
            SmallLaneSpec {
                card_id: "gemma4_e4b_qat_owner_path_manifest",
                upstream_candidate_ref: "gemma_qat_candidate:gemma4_e4b_qat_gguf_candidate",
                model_id: "google/gemma-4-E4B-it-qat-q4_0-gguf",
                source_revision: "99ef3d9bbf819591699ffa9084c4be12db1fbe6c",
                selected_filename: "gemma-4-E4B_q4_0-it.gguf",
                xet_or_lfs: "hf_xet_or_lfs:gemma4-e4b-q4_0-source-card",
                declared_file_bytes: 7_463_013_674,
                context_window_tokens: 131_072,
                metadata_bytes: 18_000,
            },
            upstream_policy_ref,
        ),
    ]
}

#[derive(Clone, Copy)]
// UAS: uas:gemma-qat-small-lane-owner-manifest:small-lane-spec
// Plane: State.
// Residency: canonical source-card construction helper; no runtime residency.
struct SmallLaneSpec {
    card_id: &'static str,
    upstream_candidate_ref: &'static str,
    model_id: &'static str,
    source_revision: &'static str,
    selected_filename: &'static str,
    xet_or_lfs: &'static str,
    declared_file_bytes: u64,
    context_window_tokens: u64,
    metadata_bytes: u64,
}

fn manifest_card(
    spec: SmallLaneSpec,
    upstream_policy_ref: &str,
) -> GemmaQatSmallLaneOwnerPathManifestCard {
    GemmaQatSmallLaneOwnerPathManifestCard {
        card_id: spec.card_id.to_string(),
        upstream_policy_ref: upstream_policy_ref.to_string(),
        upstream_candidate_ref: spec.upstream_candidate_ref.to_string(),
        model_id: spec.model_id.to_string(),
        source_locator: format!("https://huggingface.co/{}", spec.model_id),
        source_revision_ref: format!("{SOURCE_REVISION_PREFIX}{}", spec.source_revision),
        selected_filename_ref: format!("{SOURCE_FILE_PREFIX}{}", spec.selected_filename),
        xet_or_lfs_ref: spec.xet_or_lfs.to_string(),
        declared_file_bytes: spec.declared_file_bytes,
        context_window_tokens: spec.context_window_tokens,
        runtime_lanes: vec![
            GemmaFamilyRuntimeLane::GgufLlamaCpp,
            GemmaFamilyRuntimeLane::LiteRtLm,
        ],
        state: GemmaQatSmallLaneManifestState::SchemaRequiredOwnerManifestMissing,
        action: GemmaQatSmallLaneManifestAction::DefineOwnerManifestContract,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::Gated,
        required_fields: GemmaQatSmallLaneManifestRequiredFields::all_required(),
        proof_refs: proof_refs(spec.card_id),
        byte_ledger: GemmaQatSmallLaneManifestByteLedger::metadata_only(spec.metadata_bytes),
        owner_manifest_present: false,
        owner_signature_present: false,
        owner_approval_granted: false,
        raw_owner_path_stored: false,
        canonical_path_bound: false,
        file_open_allowed: false,
        file_hash_allowed: false,
        command_envelope_armed: false,
        runtime_probe_allowed: false,
        route_mutation_allowed: false,
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

fn proof_refs(card_id: &str) -> GemmaQatSmallLaneManifestProofRefs {
    GemmaQatSmallLaneManifestProofRefs {
        manifest_schema_ref: format!("{MANIFEST_SCHEMA_PREFIX}{card_id}"),
        path_policy_ref: format!("{PATH_POLICY_PREFIX}{card_id}"),
        byte_plan_ref: format!("{BYTE_PLAN_PREFIX}{card_id}"),
        command_envelope_ref: format!("{COMMAND_ENVELOPE_PREFIX}{card_id}"),
        rollback_ref: format!("{ROLLBACK_PREFIX}{card_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{card_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{card_id}"),
        abstention_ref: format!("{ABSTENTION_PREFIX}{card_id}"),
        compatibility_fence_ref: format!("{COMPATIBILITY_FENCE_PREFIX}{card_id}"),
    }
}

fn validate_card(
    card: &GemmaQatSmallLaneOwnerPathManifestCard,
) -> Result<(), GemmaQatSmallLaneOwnerPathManifestError> {
    if card.card_id.trim().is_empty() {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BadCardId);
    }
    if !card.upstream_policy_ref.starts_with(UPSTREAM_POLICY_PREFIX)
        || !card
            .upstream_policy_ref
            .contains("F-GemmaMainFamilyPolicySourceCard")
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BadUpstreamPolicyRef);
    }
    if !card
        .upstream_candidate_ref
        .starts_with(CANDIDATE_REF_PREFIX)
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BadCandidateRef(
            card.upstream_candidate_ref.clone(),
        ));
    }
    if !card.model_id.starts_with("google/gemma-4-")
        || !(card.model_id.contains("E2B") || card.model_id.contains("E4B"))
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::SmallLanePackMismatch);
    }
    if !card
        .source_locator
        .starts_with("https://huggingface.co/google/gemma-4-")
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BadSourceRef(
            card.source_locator.clone(),
        ));
    }
    if !card.source_revision_ref.starts_with(SOURCE_REVISION_PREFIX)
        || card.source_revision_ref.len() < SOURCE_REVISION_PREFIX.len() + 12
        || !card.selected_filename_ref.starts_with(SOURCE_FILE_PREFIX)
        || !card.selected_filename_ref.ends_with(".gguf")
        || !card.xet_or_lfs_ref.starts_with(XET_OR_LFS_PREFIX)
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BadSourceRef(
            card.model_id.clone(),
        ));
    }
    if card.declared_file_bytes == 0 || card.context_window_tokens < 8_192 {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BadByteOrContext);
    }
    if !card
        .runtime_lanes
        .contains(&GemmaFamilyRuntimeLane::GgufLlamaCpp)
        || !card
            .runtime_lanes
            .contains(&GemmaFamilyRuntimeLane::LiteRtLm)
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::MissingRuntimeLane);
    }
    if card.state != GemmaQatSmallLaneManifestState::SchemaRequiredOwnerManifestMissing
        || card.action != GemmaQatSmallLaneManifestAction::DefineOwnerManifestContract
        || card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::Gated
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::PromotionClaim);
    }
    if !card.required_fields.all_present() {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::MissingRequiredManifestField);
    }
    validate_proof_refs(&card.proof_refs)?;
    if card.byte_ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::MetadataBudgetExceeded);
    }
    if card.byte_ledger.live_bytes_or_actions_observed() {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::BytesOrCommandsObserved);
    }
    if card.owner_manifest_present
        || card.owner_signature_present
        || card.owner_approval_granted
        || card.raw_owner_path_stored
        || card.canonical_path_bound
        || card.file_open_allowed
        || card.file_hash_allowed
        || card.command_envelope_armed
        || card.runtime_probe_allowed
        || card.route_mutation_allowed
    {
        return Err(GemmaQatSmallLaneOwnerPathManifestError::UnsafeManifestState);
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
        return Err(GemmaQatSmallLaneOwnerPathManifestError::PromotionClaim);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &GemmaQatSmallLaneManifestProofRefs,
) -> Result<(), GemmaQatSmallLaneOwnerPathManifestError> {
    let ok = refs.manifest_schema_ref.starts_with(MANIFEST_SCHEMA_PREFIX)
        && refs.path_policy_ref.starts_with(PATH_POLICY_PREFIX)
        && refs.byte_plan_ref.starts_with(BYTE_PLAN_PREFIX)
        && refs
            .command_envelope_ref
            .starts_with(COMMAND_ENVELOPE_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX)
        && refs.abstention_ref.starts_with(ABSTENTION_PREFIX)
        && refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_FENCE_PREFIX);
    if ok {
        Ok(())
    } else {
        Err(GemmaQatSmallLaneOwnerPathManifestError::BadProofRef)
    }
}

fn manifest_ledger_preimage(
    upstream_policy_address: &str,
    upstream_policy_ref: &str,
    cards: &[GemmaQatSmallLaneOwnerPathManifestCard],
    metadata_bytes: u64,
) -> String {
    serde_json::json!({
        "cursor": GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_CURSOR,
        "upstream_policy_address": upstream_policy_address,
        "upstream_policy_ref": upstream_policy_ref,
        "cards": cards,
        "metadata_bytes": metadata_bytes,
    })
    .to_string()
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:gemma-qat-small-lane-owner-manifest:error
// Plane: Verification.
// Residency: fail-closed manifest contract rejection taxonomy.
pub enum GemmaQatSmallLaneOwnerPathManifestError {
    EmptyCardSet,
    DuplicateCardId(String),
    DuplicateModelId(String),
    BadCardId,
    BadUpstreamPolicyRef,
    BadCandidateRef(String),
    BadSourceRef(String),
    BadByteOrContext,
    MissingRuntimeLane,
    MissingRequiredManifestField,
    BadProofRef,
    SmallLanePackMismatch,
    UnsafeLedgerState,
    UnsafeManifestState,
    BytesOrCommandsObserved,
    PromotionClaim,
    MetadataBudgetExceeded,
}

impl fmt::Display for GemmaQatSmallLaneOwnerPathManifestError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "empty card set"),
            Self::DuplicateCardId(id) => write!(f, "duplicate card id {id}"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id {id}"),
            Self::BadCardId => write!(f, "bad card id"),
            Self::BadUpstreamPolicyRef => write!(f, "bad upstream policy ref"),
            Self::BadCandidateRef(id) => write!(f, "bad candidate ref {id}"),
            Self::BadSourceRef(id) => write!(f, "bad source ref {id}"),
            Self::BadByteOrContext => write!(f, "bad byte or context metadata"),
            Self::MissingRuntimeLane => write!(f, "missing required runtime lane"),
            Self::MissingRequiredManifestField => write!(f, "missing required manifest field"),
            Self::BadProofRef => write!(f, "bad proof ref"),
            Self::SmallLanePackMismatch => write!(f, "small lane pack mismatch"),
            Self::UnsafeLedgerState => write!(f, "unsafe ledger state"),
            Self::UnsafeManifestState => write!(f, "unsafe manifest state"),
            Self::BytesOrCommandsObserved => write!(f, "bytes or commands observed"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for GemmaQatSmallLaneOwnerPathManifestError {}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str =
        "artifact:falsifiers/gemma_main_family_policy_source_card/result.json#F-GemmaMainFamilyPolicySourceCard";

    fn ledger() -> GemmaQatSmallLaneOwnerPathManifestLedger {
        GemmaQatSmallLaneOwnerPathManifestLedger::new(
            "gemma_main_family_policy_source_card:fixture",
            UPSTREAM_REF,
            canonical_gemma_qat_small_lane_owner_path_manifest_cards(UPSTREAM_REF),
            72_000,
            1_779_210_800_000,
        )
        .expect("canonical ledger")
    }

    #[test]
    fn accepts_order_stable_small_lane_manifest_pack() {
        let good = ledger();
        let mut reversed_cards =
            canonical_gemma_qat_small_lane_owner_path_manifest_cards(UPSTREAM_REF);
        reversed_cards.reverse();
        let reversed = GemmaQatSmallLaneOwnerPathManifestLedger::new(
            "gemma_main_family_policy_source_card:fixture",
            UPSTREAM_REF,
            reversed_cards,
            72_000,
            1_779_210_800_000,
        )
        .expect("reversed ledger");
        assert_eq!(good.ledger_address, reversed.ledger_address);
        assert_eq!(good.metrics().card_count, 2);
        assert_eq!(good.metrics().declared_file_bytes_total, 12_091_583_309);
    }

    #[test]
    fn rejects_owner_approval_or_raw_path_laundering() {
        let mut bad = ledger();
        bad.cards[0].owner_approval_granted = true;
        bad.cards[0].raw_owner_path_stored = true;
        assert!(bad.validate().is_err());
    }

    #[test]
    fn rejects_file_access_or_hashing() {
        let mut bad = ledger();
        bad.cards[0].file_open_allowed = true;
        bad.cards[0].byte_ledger.file_hash_attempts = 1;
        assert!(bad.validate().is_err());
    }

    #[test]
    fn rejects_runtime_or_command_execution() {
        let mut bad = ledger();
        bad.cards[0].command_envelope_armed = true;
        bad.cards[0].byte_ledger.runtime_bytes_loaded = 1;
        assert!(bad.validate().is_err());
    }

    #[test]
    fn rejects_12b_or_duplicate_small_lane_pack() {
        let mut bad = ledger();
        bad.cards[1].model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
        assert!(bad.validate().is_err());

        let mut duplicate = ledger();
        duplicate.cards[1].model_id = duplicate.cards[0].model_id.clone();
        assert!(duplicate.validate().is_err());
    }

    #[test]
    fn rejects_product_or_hidden_authority_claims() {
        let mut bad = ledger();
        bad.cards[0].l2_green_claimed = true;
        bad.cards[0].hidden_route_authority_allowed = true;
        assert!(bad.validate().is_err());
    }
}
