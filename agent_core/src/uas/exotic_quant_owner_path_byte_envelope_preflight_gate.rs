//! Exotic quant owner path byte-envelope preflight gate.
//!
//! This primitive consumes the owner path-canonicalization preflight gate and
//! checks declared byte envelopes before any owner path, file access, command
//! envelope, runtime probe, or product-route claim can begin. It is
//! metadata-only: no owner manifest, path, model, runtime, source-tree,
//! provider, product, command, or benchmark bytes are loaded.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_owner_path_canonicalization_preflight_cards, expected_owner_path_manifest_model_ids,
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane,
    OwnerPathCanonicalizationPreflightCard, OwnerPathManifestByteEnvelope, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_CURSOR: &str =
    "exotic_quant_owner_path_byte_envelope_preflight_gate";
pub const EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR: &str =
    "exotic_quant_crash_safe_command_envelope_preflight_gate";

const UPSTREAM_CANONICALIZATION_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_owner_path_canonicalization_preflight_gate/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const BYTE_BUDGET_PREFIX: &str = "byte_budget:exotic-quant:";
const BYTE_ENVELOPE_PREFIX: &str = "byte_envelope:owner_path_preflight:exotic_quant:";
const HARDWARE_DENIAL_PREFIX: &str = "hardware_denial:m2pro_16gb:exotic_quant:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:unarmed:exotic_quant_byte_envelope:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_byte_envelope:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_byte_envelope:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_byte_envelope:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_byte_envelope:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_byte_envelope:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const M2_PRO_16GB_UMA_BYTES: u64 = 16 * 1024 * 1024 * 1024;

// UAS: uas:exotic-quant-owner-path-byte-envelope:state
// Plane: Verification
// Residency: byte-envelope state only; no local artifact bytes are trusted.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerPathByteEnvelopeState {
    CurrentM2Pro16GbEnvelopeBlocked,
    ServerOnlyByteEnvelopeDenied,
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:action
// Plane: Controller
// Residency: no command or runtime action can be armed from byte metadata.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerPathByteEnvelopeAction {
    CompileByteEnvelopePreflight,
    DenyMacByteEnvelopePreflight,
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:policy
// Plane: Controller + Verification
// Residency: declared byte math only; resident bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathByteEnvelopePolicy {
    pub selected_artifact_bytes_bound: bool,
    pub selected_support_bytes_bound: bool,
    pub runtime_workspace_budget_bound: bool,
    pub kv_cache_floor_bound: bool,
    pub app_headroom_bound: bool,
    pub minimum_uma_bound: bool,
    pub minimum_uma_recomputed: bool,
    pub current_m2pro_16gb_denied: bool,
    pub mac_24_to_32gb_required: bool,
    pub server_gpu_row_denied: bool,
    pub resident_bytes_equal_zero: bool,
    pub file_access_blocked: bool,
    pub byte_hashing_blocked: bool,
    pub runtime_probe_blocked: bool,
}

impl OwnerPathByteEnvelopePolicy {
    pub fn mac_current_hardware_blocked() -> Self {
        Self {
            selected_artifact_bytes_bound: true,
            selected_support_bytes_bound: true,
            runtime_workspace_budget_bound: true,
            kv_cache_floor_bound: true,
            app_headroom_bound: true,
            minimum_uma_bound: true,
            minimum_uma_recomputed: true,
            current_m2pro_16gb_denied: true,
            mac_24_to_32gb_required: true,
            server_gpu_row_denied: false,
            resident_bytes_equal_zero: true,
            file_access_blocked: true,
            byte_hashing_blocked: true,
            runtime_probe_blocked: true,
        }
    }

    pub fn server_denied() -> Self {
        Self {
            selected_artifact_bytes_bound: true,
            selected_support_bytes_bound: true,
            runtime_workspace_budget_bound: true,
            kv_cache_floor_bound: true,
            app_headroom_bound: true,
            minimum_uma_bound: true,
            minimum_uma_recomputed: true,
            current_m2pro_16gb_denied: true,
            mac_24_to_32gb_required: false,
            server_gpu_row_denied: true,
            resident_bytes_equal_zero: true,
            file_access_blocked: true,
            byte_hashing_blocked: true,
            runtime_probe_blocked: true,
        }
    }

    fn proves_metadata_only_denial(&self) -> bool {
        self.selected_artifact_bytes_bound
            && self.selected_support_bytes_bound
            && self.runtime_workspace_budget_bound
            && self.kv_cache_floor_bound
            && self.app_headroom_bound
            && self.minimum_uma_bound
            && self.minimum_uma_recomputed
            && self.current_m2pro_16gb_denied
            && self.resident_bytes_equal_zero
            && self.file_access_blocked
            && self.byte_hashing_blocked
            && self.runtime_probe_blocked
    }
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:byte-ledger
// Plane: Verification
// Residency: every live byte counter stays zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathByteEnvelopeLedgerBytes {
    pub metadata_bytes_read: u64,
    pub owner_manifest_bytes_read: u64,
    pub owner_path_bytes_read: u64,
    pub local_file_bytes_read: u64,
    pub byte_hash_attempts: u64,
    pub local_path_open_attempts: u64,
    pub file_stat_calls: u64,
    pub symlink_resolution_attempts: u64,
    pub command_execution_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_bytes_copied: u64,
    pub benchmark_runs: u64,
}

impl OwnerPathByteEnvelopeLedgerBytes {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            owner_manifest_bytes_read: 0,
            owner_path_bytes_read: 0,
            local_file_bytes_read: 0,
            byte_hash_attempts: 0,
            local_path_open_attempts: 0,
            file_stat_calls: 0,
            symlink_resolution_attempts: 0,
            command_execution_count: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            source_tree_bytes_read: 0,
            product_bytes_copied: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:refs
// Plane: Verification
// Residency: visible proof refs required before runtime work can promote.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathByteEnvelopeProofRefs {
    pub upstream_canonicalization_ref: String,
    pub source_pin_card_ref: String,
    pub byte_budget_ref: String,
    pub byte_envelope_ref: String,
    pub hardware_denial_ref: String,
    pub command_envelope_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:card
// Plane: Controller + Verification
// Residency: per-row byte envelope card; never local file availability.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathByteEnvelopePreflightCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub state: OwnerPathByteEnvelopeState,
    pub action: OwnerPathByteEnvelopeAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub envelope: OwnerPathManifestByteEnvelope,
    pub policy: OwnerPathByteEnvelopePolicy,
    pub byte_ledger: OwnerPathByteEnvelopeLedgerBytes,
    pub proof_refs: OwnerPathByteEnvelopeProofRefs,
    pub user_visible_summary: String,
    pub byte_envelope_preflight_compiled: bool,
    pub minimum_uma_recomputed: bool,
    pub current_m2pro_16gb_denied: bool,
    pub mac_24_to_32gb_required: bool,
    pub server_only_denied_on_mac: bool,
    pub selected_bytes_become_resident_claim: bool,
    pub owner_manifest_present: bool,
    pub owner_supplied_path_present: bool,
    pub local_artifact_verified: bool,
    pub local_path_open_allowed: bool,
    pub file_stat_allowed: bool,
    pub file_hash_allowed: bool,
    pub symlink_follow_allowed: bool,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub runtime_probe_allowed: bool,
    pub runtime_deferred: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub abstention_required: bool,
    pub mas_allowed: bool,
    pub product_route_enabled: bool,
    pub app_default_claim: bool,
    pub product_winner_claim: bool,
    pub route_policy_mutated: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub patternboost_live_authority: bool,
    pub lattice_live_authority: bool,
    pub eidos_live_authority: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub l2_l3_promotion_claim: bool,
    pub source_import_allowed: bool,
    pub benchmark_as_fit_proof: bool,
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:ledger
// Plane: Controller + Verification
// Residency: metadata-only byte envelope bound to canonicalization proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathByteEnvelopePreflightLedger {
    pub ledger_address: UasAddress,
    pub upstream_canonicalization_gate_address: UasAddress,
    pub upstream_canonicalization_gate_ref: String,
    pub cards: Vec<OwnerPathByteEnvelopePreflightCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub byte_envelope_preflight_compiled: bool,
    pub current_m2pro_16gb_denied: bool,
    pub owner_path_bytes_loaded: bool,
    pub file_access_deferred: bool,
    pub runtime_deferred: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:metrics
// Plane: Verification
// Residency: derived byte-envelope counts and zero-byte counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathByteEnvelopePreflightMetrics {
    pub gate_card_count: u64,
    pub mac_current_hardware_denied_count: u64,
    pub mac_24_to_32gb_required_count: u64,
    pub server_only_denied_count: u64,
    pub byte_envelope_preflight_compiled_count: u64,
    pub minimum_uma_recomputed_count: u64,
    pub selected_artifact_bytes_sum: u64,
    pub selected_support_bytes_sum: u64,
    pub runtime_workspace_budget_bytes_sum: u64,
    pub kv_cache_floor_bytes_sum: u64,
    pub app_headroom_bytes_sum: u64,
    pub minimum_uma_bytes_required_max: u64,
    pub current_m2pro_16gb_bytes: u64,
    pub owner_manifest_present_count: u64,
    pub owner_supplied_path_present_count: u64,
    pub local_artifact_verified_count: u64,
    pub selected_bytes_resident_claim_count: u64,
    pub local_path_open_allowed_count: u64,
    pub file_hash_allowed_count: u64,
    pub command_envelope_unarmed_count: u64,
    pub owner_manifest_bytes_read_total: u64,
    pub owner_path_bytes_read_total: u64,
    pub local_file_bytes_read_total: u64,
    pub byte_hash_attempts_total: u64,
    pub local_path_open_attempts_total: u64,
    pub file_stat_calls_total: u64,
    pub symlink_resolution_attempts_total: u64,
    pub command_execution_count_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub source_tree_bytes_read_total: u64,
    pub product_bytes_copied_total: u64,
    pub benchmark_runs_total: u64,
}

impl OwnerPathByteEnvelopePreflightLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_canonicalization_gate_address: UasAddress,
        upstream_canonicalization_gate_ref: impl Into<String>,
        mut cards: Vec<OwnerPathByteEnvelopePreflightCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        byte_envelope_preflight_compiled: bool,
        current_m2pro_16gb_denied: bool,
        owner_path_bytes_loaded: bool,
        file_access_deferred: bool,
        runtime_deferred: bool,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, OwnerPathByteEnvelopePreflightError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_canonicalization_gate_ref = upstream_canonicalization_gate_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger(
            &upstream_canonicalization_gate_address,
            &upstream_canonicalization_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            byte_envelope_preflight_compiled,
            current_m2pro_16gb_denied,
            owner_path_bytes_loaded,
            file_access_deferred,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_canonicalization_gate_address,
            &upstream_canonicalization_gate_ref,
            &cards,
            metadata_bytes,
            byte_envelope_preflight_compiled,
            current_m2pro_16gb_denied,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_canonicalization_gate_address,
            upstream_canonicalization_gate_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            byte_envelope_preflight_compiled,
            current_m2pro_16gb_denied,
            owner_path_bytes_loaded,
            file_access_deferred,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> OwnerPathByteEnvelopePreflightMetrics {
        let mut metrics = OwnerPathByteEnvelopePreflightMetrics {
            gate_card_count: self.cards.len() as u64,
            mac_current_hardware_denied_count: 0,
            mac_24_to_32gb_required_count: 0,
            server_only_denied_count: 0,
            byte_envelope_preflight_compiled_count: 0,
            minimum_uma_recomputed_count: 0,
            selected_artifact_bytes_sum: 0,
            selected_support_bytes_sum: 0,
            runtime_workspace_budget_bytes_sum: 0,
            kv_cache_floor_bytes_sum: 0,
            app_headroom_bytes_sum: 0,
            minimum_uma_bytes_required_max: 0,
            current_m2pro_16gb_bytes: M2_PRO_16GB_UMA_BYTES,
            owner_manifest_present_count: 0,
            owner_supplied_path_present_count: 0,
            local_artifact_verified_count: 0,
            selected_bytes_resident_claim_count: 0,
            local_path_open_allowed_count: 0,
            file_hash_allowed_count: 0,
            command_envelope_unarmed_count: 0,
            owner_manifest_bytes_read_total: 0,
            owner_path_bytes_read_total: 0,
            local_file_bytes_read_total: 0,
            byte_hash_attempts_total: 0,
            local_path_open_attempts_total: 0,
            file_stat_calls_total: 0,
            symlink_resolution_attempts_total: 0,
            command_execution_count_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            source_tree_bytes_read_total: 0,
            product_bytes_copied_total: 0,
            benchmark_runs_total: 0,
        };
        for card in &self.cards {
            if card.current_m2pro_16gb_denied {
                metrics.mac_current_hardware_denied_count += 1;
            }
            if card.mac_24_to_32gb_required {
                metrics.mac_24_to_32gb_required_count += 1;
            }
            if card.server_only_denied_on_mac {
                metrics.server_only_denied_count += 1;
            }
            if card.byte_envelope_preflight_compiled {
                metrics.byte_envelope_preflight_compiled_count += 1;
            }
            if card.minimum_uma_recomputed {
                metrics.minimum_uma_recomputed_count += 1;
            }
            metrics.selected_artifact_bytes_sum += card.envelope.selected_artifact_bytes;
            metrics.selected_support_bytes_sum += card.envelope.selected_support_bytes;
            metrics.runtime_workspace_budget_bytes_sum +=
                card.envelope.runtime_workspace_budget_bytes;
            metrics.kv_cache_floor_bytes_sum += card.envelope.kv_cache_floor_bytes;
            metrics.app_headroom_bytes_sum += card.envelope.app_headroom_bytes;
            metrics.minimum_uma_bytes_required_max = metrics
                .minimum_uma_bytes_required_max
                .max(card.envelope.minimum_uma_bytes_required);
            if card.owner_manifest_present {
                metrics.owner_manifest_present_count += 1;
            }
            if card.owner_supplied_path_present {
                metrics.owner_supplied_path_present_count += 1;
            }
            if card.local_artifact_verified {
                metrics.local_artifact_verified_count += 1;
            }
            if card.selected_bytes_become_resident_claim {
                metrics.selected_bytes_resident_claim_count += 1;
            }
            if card.local_path_open_allowed {
                metrics.local_path_open_allowed_count += 1;
            }
            if card.file_hash_allowed {
                metrics.file_hash_allowed_count += 1;
            }
            if card.command_envelope_visible && !card.command_armed {
                metrics.command_envelope_unarmed_count += 1;
            }
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
            metrics.owner_path_bytes_read_total += card.byte_ledger.owner_path_bytes_read;
            metrics.local_file_bytes_read_total += card.byte_ledger.local_file_bytes_read;
            metrics.byte_hash_attempts_total += card.byte_ledger.byte_hash_attempts;
            metrics.local_path_open_attempts_total += card.byte_ledger.local_path_open_attempts;
            metrics.file_stat_calls_total += card.byte_ledger.file_stat_calls;
            metrics.symlink_resolution_attempts_total +=
                card.byte_ledger.symlink_resolution_attempts;
            metrics.command_execution_count_total += card.byte_ledger.command_execution_count;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.source_tree_bytes_read_total += card.byte_ledger.source_tree_bytes_read;
            metrics.product_bytes_copied_total += card.byte_ledger.product_bytes_copied;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
        }
        metrics
    }
}

// UAS: uas:exotic-quant-owner-path-byte-envelope:error
// Plane: Verification
// Residency: every error fails closed before file or runtime access.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OwnerPathByteEnvelopePreflightError {
    EmptyLedger,
    BadUpstreamCanonicalizationRef,
    BadLedgerState,
    BadNextCursor,
    MetadataBudgetExceeded,
    DuplicateGateId(String),
    DuplicateModelId(String),
    DuplicateSourcePinCardId(String),
    MissingExpectedModel(&'static str),
    UnknownModelId(String),
    BadExpectedPolicy(String),
    BadByteEnvelope(String),
    BadByteLedger(String),
    BadText(String),
    BadPrefix(String),
    RuntimeAuthority(String),
    ProductPromotion(String),
    HiddenAuthority(String),
    SourceContamination(String),
    MissingProofSurface(String),
}

impl fmt::Display for OwnerPathByteEnvelopePreflightError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "owner path byte-envelope ledger is empty"),
            Self::BadUpstreamCanonicalizationRef => {
                write!(f, "bad upstream canonicalization preflight ref")
            }
            Self::BadLedgerState => write!(f, "byte-envelope preflight ledger state is invalid"),
            Self::BadNextCursor => write!(f, "byte-envelope preflight ledger has bad cursor"),
            Self::MetadataBudgetExceeded => {
                write!(f, "byte-envelope preflight metadata budget exceeded")
            }
            Self::DuplicateGateId(id) => write!(f, "duplicate gate id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id `{id}`"),
            Self::DuplicateSourcePinCardId(id) => write!(f, "duplicate source-pin id `{id}`"),
            Self::MissingExpectedModel(id) => write!(f, "missing expected model `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown model `{id}`"),
            Self::BadExpectedPolicy(id) => write!(f, "bad byte-envelope policy on `{id}`"),
            Self::BadByteEnvelope(id) => write!(f, "bad byte envelope on `{id}`"),
            Self::BadByteLedger(id) => write!(f, "bad byte ledger on `{id}`"),
            Self::BadText(id) => write!(f, "bad text field on `{id}`"),
            Self::BadPrefix(id) => write!(f, "bad proof-ref prefix on `{id}`"),
            Self::RuntimeAuthority(id) => write!(f, "runtime authority attempted by `{id}`"),
            Self::ProductPromotion(id) => write!(f, "product promotion attempted by `{id}`"),
            Self::HiddenAuthority(id) => write!(f, "hidden authority attempted by `{id}`"),
            Self::SourceContamination(id) => write!(f, "source contamination attempted by `{id}`"),
            Self::MissingProofSurface(id) => write!(f, "missing proof surface on `{id}`"),
        }
    }
}

impl std::error::Error for OwnerPathByteEnvelopePreflightError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger(
    upstream_canonicalization_gate_address: &UasAddress,
    upstream_canonicalization_gate_ref: &str,
    cards: &[OwnerPathByteEnvelopePreflightCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    byte_envelope_preflight_compiled: bool,
    current_m2pro_16gb_denied: bool,
    owner_path_bytes_loaded: bool,
    file_access_deferred: bool,
    runtime_deferred: bool,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    if upstream_canonicalization_gate_address
        .to_string()
        .trim()
        .is_empty()
        || !upstream_canonicalization_gate_ref.starts_with(UPSTREAM_CANONICALIZATION_PREFIX)
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadUpstreamCanonicalizationRef);
    }
    if cards.is_empty() {
        return Err(OwnerPathByteEnvelopePreflightError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(OwnerPathByteEnvelopePreflightError::MetadataBudgetExceeded);
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || !byte_envelope_preflight_compiled
        || !current_m2pro_16gb_denied
        || owner_path_bytes_loaded
        || !file_access_deferred
        || !runtime_deferred
        || !l1_l2_l3_separated
        || !product_promotion_blocked
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR {
        return Err(OwnerPathByteEnvelopePreflightError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(OwnerPathByteEnvelopePreflightError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(OwnerPathByteEnvelopePreflightError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(
                OwnerPathByteEnvelopePreflightError::DuplicateSourcePinCardId(
                    card.source_pin_card_id.clone(),
                ),
            );
        }
    }
    for expected in expected_owner_path_manifest_model_ids() {
        if !model_ids.contains(expected) {
            return Err(OwnerPathByteEnvelopePreflightError::MissingExpectedModel(
                expected,
            ));
        }
    }
    Ok(())
}

fn validate_card(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    for text in [
        &card.gate_id,
        &card.model_id,
        &card.source_pin_card_id,
        &card.selected_artifact_path,
        &card.user_visible_summary,
    ] {
        validate_text(text, &card.gate_id)?;
    }
    if card.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(OwnerPathByteEnvelopePreflightError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    if !expected_owner_path_manifest_model_ids()
        .iter()
        .any(|expected| expected == &card.model_id)
    {
        return Err(OwnerPathByteEnvelopePreflightError::UnknownModelId(
            card.model_id.clone(),
        ));
    }
    validate_refs(card)?;
    validate_expected_policy(card)?;
    validate_byte_envelope(card)?;
    validate_byte_ledger(card)?;
    validate_boundaries(card)?;
    validate_proof_surfaces(card)?;
    Ok(())
}

fn validate_expected_policy(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    let mac_candidate = is_mac_candidate_source_pin(&card.source_pin_card_id);
    if mac_candidate {
        if card.state != OwnerPathByteEnvelopeState::CurrentM2Pro16GbEnvelopeBlocked
            || card.action != OwnerPathByteEnvelopeAction::CompileByteEnvelopePreflight
            || card.policy != OwnerPathByteEnvelopePolicy::mac_current_hardware_blocked()
            || !card.byte_envelope_preflight_compiled
            || !card.mac_24_to_32gb_required
            || card.server_only_denied_on_mac
        {
            return Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(
                card.gate_id.clone(),
            ));
        }
    } else if card.state != OwnerPathByteEnvelopeState::ServerOnlyByteEnvelopeDenied
        || card.action != OwnerPathByteEnvelopeAction::DenyMacByteEnvelopePreflight
        || card.policy != OwnerPathByteEnvelopePolicy::server_denied()
        || card.byte_envelope_preflight_compiled
        || card.mac_24_to_32gb_required
        || !card.server_only_denied_on_mac
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(
            card.gate_id.clone(),
        ));
    }
    if !card.policy.proves_metadata_only_denial()
        || !card.current_m2pro_16gb_denied
        || card.envelope.minimum_uma_bytes_required <= M2_PRO_16GB_UMA_BYTES
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(
            card.gate_id.clone(),
        ));
    }
    if card.owner_manifest_present
        || card.owner_supplied_path_present
        || card.local_artifact_verified
        || card.selected_bytes_become_resident_claim
        || card.local_path_open_allowed
        || card.file_stat_allowed
        || card.file_hash_allowed
        || card.symlink_follow_allowed
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_envelope(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    let expected_minimum = card.envelope.selected_artifact_bytes
        + card.envelope.selected_support_bytes
        + card.envelope.runtime_workspace_budget_bytes
        + card.envelope.kv_cache_floor_bytes
        + card.envelope.app_headroom_bytes;
    if card.envelope.selected_artifact_bytes == 0
        || card.envelope.runtime_workspace_budget_bytes == 0
        || card.envelope.kv_cache_floor_bytes == 0
        || card.envelope.minimum_uma_bytes_required != expected_minimum
        || !card.minimum_uma_recomputed
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadByteEnvelope(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_refs(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    let expected_refs = [
        (
            &card.proof_refs.upstream_canonicalization_ref,
            UPSTREAM_CANONICALIZATION_PREFIX,
        ),
        (&card.proof_refs.source_pin_card_ref, SOURCE_PIN_CARD_PREFIX),
        (&card.proof_refs.byte_budget_ref, BYTE_BUDGET_PREFIX),
        (&card.proof_refs.byte_envelope_ref, BYTE_ENVELOPE_PREFIX),
        (&card.proof_refs.hardware_denial_ref, HARDWARE_DENIAL_PREFIX),
        (
            &card.proof_refs.command_envelope_ref,
            COMMAND_ENVELOPE_PREFIX,
        ),
        (&card.proof_refs.rollback_ref, ROLLBACK_PREFIX),
        (&card.proof_refs.run_event_log_ref, RUN_EVENT_LOG_PREFIX),
        (&card.proof_refs.answer_packet_ref, ANSWER_PACKET_PREFIX),
        (&card.proof_refs.abstention_ref, ABSTENTION_PREFIX),
        (&card.proof_refs.sovereign_gate_ref, SOVEREIGN_GATE_PREFIX),
    ];
    for (value, prefix) in expected_refs {
        if !value.starts_with(prefix) {
            return Err(OwnerPathByteEnvelopePreflightError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    for value in [
        &card.proof_refs.source_pin_card_ref,
        &card.proof_refs.byte_budget_ref,
        &card.proof_refs.byte_envelope_ref,
        &card.proof_refs.hardware_denial_ref,
        &card.proof_refs.command_envelope_ref,
        &card.proof_refs.rollback_ref,
        &card.proof_refs.run_event_log_ref,
        &card.proof_refs.answer_packet_ref,
        &card.proof_refs.abstention_ref,
        &card.proof_refs.sovereign_gate_ref,
    ] {
        if !value.ends_with(&card.source_pin_card_id) {
            return Err(OwnerPathByteEnvelopePreflightError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    let ledger = &card.byte_ledger;
    if ledger.metadata_bytes_read == 0 || ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(OwnerPathByteEnvelopePreflightError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    if ledger.owner_manifest_bytes_read != 0
        || ledger.owner_path_bytes_read != 0
        || ledger.local_file_bytes_read != 0
        || ledger.byte_hash_attempts != 0
        || ledger.local_path_open_attempts != 0
        || ledger.file_stat_calls != 0
        || ledger.symlink_resolution_attempts != 0
        || ledger.command_execution_count != 0
        || ledger.model_bytes_loaded != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.provider_calls_made != 0
        || ledger.source_tree_bytes_read != 0
        || ledger.product_bytes_copied != 0
        || ledger.benchmark_runs != 0
    {
        return Err(OwnerPathByteEnvelopePreflightError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_boundaries(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        || card.mas_allowed
        || card.product_route_enabled
        || card.app_default_claim
        || card.product_winner_claim
        || card.l2_l3_promotion_claim
    {
        return Err(OwnerPathByteEnvelopePreflightError::ProductPromotion(
            card.gate_id.clone(),
        ));
    }
    if card.route_policy_mutated
        || card.hidden_route_authority
        || card.hidden_cloud_fallback
        || card.patternboost_live_authority
        || card.lattice_live_authority
        || card.eidos_live_authority
    {
        return Err(OwnerPathByteEnvelopePreflightError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.live_dense_70b_claim
        || card.ssd_as_ram_claim
        || card.source_import_allowed
        || card.benchmark_as_fit_proof
    {
        return Err(OwnerPathByteEnvelopePreflightError::SourceContamination(
            card.gate_id.clone(),
        ));
    }
    if card.command_armed || card.runtime_probe_allowed || !card.runtime_deferred {
        return Err(OwnerPathByteEnvelopePreflightError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &OwnerPathByteEnvelopePreflightCard,
) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    if !card.command_envelope_visible
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(OwnerPathByteEnvelopePreflightError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_text(value: &str, gate_id: &str) -> Result<(), OwnerPathByteEnvelopePreflightError> {
    if value.trim().is_empty() || value.contains('\0') || value.chars().any(char::is_control) {
        return Err(OwnerPathByteEnvelopePreflightError::BadText(
            gate_id.to_string(),
        ));
    }
    Ok(())
}

fn ledger_preimage(
    upstream_canonicalization_gate_address: &UasAddress,
    upstream_canonicalization_gate_ref: &str,
    cards: &[OwnerPathByteEnvelopePreflightCard],
    metadata_bytes: u64,
    byte_envelope_preflight_compiled: bool,
    current_m2pro_16gb_denied: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "{upstream_canonicalization_gate_address}\n{upstream_canonicalization_gate_ref}\n{metadata_bytes}\n{byte_envelope_preflight_compiled}\n{current_m2pro_16gb_denied}\n{next_cursor}\n"
    );
    for card in cards {
        preimage.push_str(&card.gate_id);
        preimage.push('|');
        preimage.push_str(&card.model_id);
        preimage.push('|');
        preimage.push_str(&card.source_pin_card_id);
        preimage.push('|');
        preimage.push_str(&card.envelope.selected_artifact_bytes.to_string());
        preimage.push('|');
        preimage.push_str(&card.envelope.selected_support_bytes.to_string());
        preimage.push('|');
        preimage.push_str(&card.envelope.minimum_uma_bytes_required.to_string());
        preimage.push('|');
        preimage.push_str(&format!("{:?}|{:?}\n", card.state, card.action));
    }
    preimage
}

pub fn canonical_owner_path_byte_envelope_preflight_cards(
    upstream_canonicalization_ref: &str,
) -> Vec<OwnerPathByteEnvelopePreflightCard> {
    canonical_owner_path_canonicalization_preflight_cards(upstream_canonicalization_ref)
        .into_iter()
        .map(|card| canonical_card_from_canonicalization(&card, upstream_canonicalization_ref))
        .collect()
}

fn canonical_card_from_canonicalization(
    canonicalization_card: &OwnerPathCanonicalizationPreflightCard,
    upstream_canonicalization_ref: &str,
) -> OwnerPathByteEnvelopePreflightCard {
    let mac_candidate = is_mac_candidate_source_pin(&canonicalization_card.source_pin_card_id);
    let source_pin = &canonicalization_card.source_pin_card_id;
    OwnerPathByteEnvelopePreflightCard {
        gate_id: format!("{source_pin}_owner_path_byte_envelope_preflight"),
        model_id: canonicalization_card.model_id.clone(),
        source_pin_card_id: source_pin.clone(),
        selected_artifact_path: canonicalization_card.selected_artifact_path.clone(),
        hardware_tier: canonicalization_card.hardware_tier,
        runtime_lane: canonicalization_card.runtime_lane,
        state: if mac_candidate {
            OwnerPathByteEnvelopeState::CurrentM2Pro16GbEnvelopeBlocked
        } else {
            OwnerPathByteEnvelopeState::ServerOnlyByteEnvelopeDenied
        },
        action: if mac_candidate {
            OwnerPathByteEnvelopeAction::CompileByteEnvelopePreflight
        } else {
            OwnerPathByteEnvelopeAction::DenyMacByteEnvelopePreflight
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        envelope: canonicalization_card.envelope.clone(),
        policy: if mac_candidate {
            OwnerPathByteEnvelopePolicy::mac_current_hardware_blocked()
        } else {
            OwnerPathByteEnvelopePolicy::server_denied()
        },
        byte_ledger: OwnerPathByteEnvelopeLedgerBytes::metadata_only(48_000),
        proof_refs: OwnerPathByteEnvelopeProofRefs {
            upstream_canonicalization_ref: upstream_canonicalization_ref.to_string(),
            source_pin_card_ref: format!("{SOURCE_PIN_CARD_PREFIX}{source_pin}"),
            byte_budget_ref: format!("{BYTE_BUDGET_PREFIX}{source_pin}"),
            byte_envelope_ref: format!("{BYTE_ENVELOPE_PREFIX}{source_pin}"),
            hardware_denial_ref: format!("{HARDWARE_DENIAL_PREFIX}{source_pin}"),
            command_envelope_ref: format!("{COMMAND_ENVELOPE_PREFIX}{source_pin}"),
            rollback_ref: format!("{ROLLBACK_PREFIX}{source_pin}"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{source_pin}"),
            answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{source_pin}"),
            abstention_ref: format!("{ABSTENTION_PREFIX}{source_pin}"),
            sovereign_gate_ref: format!("{SOVEREIGN_GATE_PREFIX}{source_pin}"),
        },
        user_visible_summary: format!(
            "Byte-envelope preflight for {} recomputes selected artifact, support, runtime workspace, KV cache, and app headroom bytes, denies Jojo M2 Pro 16 GB current-hardware admission, keeps owner path and file bytes absent, commands unarmed, runtime deferred, and no MAS/L2/L3/product promotion.",
            canonicalization_card.model_id
        ),
        byte_envelope_preflight_compiled: mac_candidate,
        minimum_uma_recomputed: true,
        current_m2pro_16gb_denied: true,
        mac_24_to_32gb_required: mac_candidate,
        server_only_denied_on_mac: !mac_candidate,
        selected_bytes_become_resident_claim: false,
        owner_manifest_present: false,
        owner_supplied_path_present: false,
        local_artifact_verified: false,
        local_path_open_allowed: false,
        file_stat_allowed: false,
        file_hash_allowed: false,
        symlink_follow_allowed: false,
        command_envelope_visible: true,
        command_armed: false,
        runtime_probe_allowed: false,
        runtime_deferred: true,
        rollback_required: true,
        run_event_log_required: true,
        answer_packet_required: true,
        abstention_required: true,
        mas_allowed: false,
        product_route_enabled: false,
        app_default_claim: false,
        product_winner_claim: false,
        route_policy_mutated: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        patternboost_live_authority: false,
        lattice_live_authority: false,
        eidos_live_authority: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        l2_l3_promotion_claim: false,
        source_import_allowed: false,
        benchmark_as_fit_proof: false,
    }
}

fn is_mac_candidate_source_pin(source_pin: &str) -> bool {
    matches!(
        source_pin,
        "qwopus27b_tq3_4s" | "qwopus27b_hlwq_q5" | "qwopus_moe_35b_a3b_apex_mini"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/exotic_quant_owner_path_canonicalization_preflight_gate/result.json#F-ExoticQuantOwnerPathCanonicalizationPreflightGate";

    fn ledger_from_cards(
        cards: Vec<OwnerPathByteEnvelopePreflightCard>,
    ) -> Result<OwnerPathByteEnvelopePreflightLedger, OwnerPathByteEnvelopePreflightError> {
        OwnerPathByteEnvelopePreflightLedger::new(
            UasAddress::new(
                UasKind::Other("upstream_canonicalization_gate".to_string()),
                b"owner_path_canonicalization",
                1_779_550_000_000,
            ),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            288_000,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
            1_779_550_000_000,
        )
    }

    #[test]
    fn accepts_byte_envelope_without_runtime_bytes() {
        let cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
        let ledger = ledger_from_cards(cards).expect("canonical ledger should validate");
        let metrics = ledger.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.mac_current_hardware_denied_count, 5);
        assert_eq!(metrics.mac_24_to_32gb_required_count, 3);
        assert_eq!(metrics.server_only_denied_count, 2);
        assert_eq!(metrics.selected_artifact_bytes_sum, 96_318_502_063);
        assert_eq!(metrics.minimum_uma_bytes_required_max, 39_108_307_031);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(
            ledger.next_cursor,
            EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_current_hardware_bypass_and_bad_envelope_math() {
        let mut cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
        cards[0].current_m2pro_16gb_denied = false;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(_))
        ));

        let mut cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
        cards[0].envelope.minimum_uma_bytes_required = 1;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(_))
                | Err(OwnerPathByteEnvelopePreflightError::BadByteEnvelope(_))
        ));
    }

    #[test]
    fn rejects_file_or_residency_shortcuts() {
        let mut cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
        cards[0].local_artifact_verified = true;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathByteEnvelopePreflightError::BadExpectedPolicy(_))
        ));

        let mut cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
        cards[0].byte_ledger.local_file_bytes_read = 1;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathByteEnvelopePreflightError::BadByteLedger(_))
        ));
    }

    #[test]
    fn deterministic_address_after_sorting() {
        let cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
        let mut reversed = cards.clone();
        reversed.reverse();
        let first = ledger_from_cards(cards).expect("first ledger");
        let second = ledger_from_cards(reversed).expect("second ledger");
        assert_eq!(first.ledger_address, second.ledger_address);
    }
}
