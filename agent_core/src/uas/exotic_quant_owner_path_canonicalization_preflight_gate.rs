//! Exotic quant owner path-canonicalization preflight gate.
//!
//! This primitive consumes the owner path-manifest intake gate and compiles the
//! fail-closed path policy required before any owner-supplied model path can be
//! canonicalized. It does not read owner manifests, store raw paths, expand
//! paths, follow symlinks, open files, stat files, hash artifacts, arm commands,
//! run loaders, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_owner_path_manifest_intake_cards, expected_owner_path_manifest_model_ids,
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane,
    OwnerPathManifestByteEnvelope, OwnerPathManifestIntakeCard, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const EXOTIC_QUANT_OWNER_PATH_CANONICALIZATION_PREFLIGHT_GATE_CURSOR: &str =
    "exotic_quant_owner_path_canonicalization_preflight_gate";
pub const EXOTIC_QUANT_OWNER_PATH_CANONICALIZATION_PREFLIGHT_GATE_NEXT_CURSOR: &str =
    "exotic_quant_owner_path_byte_envelope_preflight_gate";

const UPSTREAM_MANIFEST_INTAKE_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_owner_path_manifest_intake_gate/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const BYTE_BUDGET_PREFIX: &str = "byte_budget:exotic-quant:";
const PATH_POLICY_PREFIX: &str = "path_policy:canonicalization_preflight:exotic_quant:";
const CANONICALIZATION_PREFLIGHT_PREFIX: &str =
    "path_canonicalization:preflight_no_file_access:exotic_quant:";
const ALLOWED_ROOTS_POLICY_PREFIX: &str = "allowed_roots:owner_model_artifact:exotic_quant:";
const COMMAND_ENVELOPE_PREFIX: &str =
    "command_envelope:unarmed:exotic_quant_path_canonicalization:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_path_canonicalization:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_path_canonicalization:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_path_canonicalization:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_path_canonicalization:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_path_canonicalization:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:exotic-quant-owner-path-canonicalization:state
// Plane: Verification
// Residency: canonicalization state only; no owner path bytes are trusted.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerPathCanonicalizationState {
    OwnerManifestMissingCanonicalizationBlocked,
    ServerOnlyCanonicalizationDenied,
}

// UAS: uas:exotic-quant-owner-path-canonicalization:action
// Plane: Controller
// Residency: no filesystem or runtime action can be armed from preflight.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerPathCanonicalizationAction {
    CompileFailClosedPathPolicy,
    DenyMacCanonicalizationPreflight,
}

// UAS: uas:exotic-quant-owner-path-canonicalization:policy
// Plane: Controller + Verification
// Residency: path policy is metadata; raw owner paths stay absent.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathCanonicalizationPolicy {
    pub owner_manifest_required: bool,
    pub owner_absolute_path_required: bool,
    pub relative_path_rejected: bool,
    pub tilde_expansion_rejected: bool,
    pub environment_expansion_rejected: bool,
    pub parent_traversal_rejected: bool,
    pub unicode_control_rejected: bool,
    pub nul_byte_rejected: bool,
    pub symlink_follow_rejected: bool,
    pub allowed_roots_policy_required: bool,
    pub sandbox_boundary_required: bool,
    pub canonical_digest_deferred: bool,
    pub path_bytes_redacted: bool,
    pub file_access_blocked: bool,
}

impl OwnerPathCanonicalizationPolicy {
    pub fn mac_manifest_missing() -> Self {
        Self {
            owner_manifest_required: true,
            owner_absolute_path_required: true,
            relative_path_rejected: true,
            tilde_expansion_rejected: true,
            environment_expansion_rejected: true,
            parent_traversal_rejected: true,
            unicode_control_rejected: true,
            nul_byte_rejected: true,
            symlink_follow_rejected: true,
            allowed_roots_policy_required: true,
            sandbox_boundary_required: true,
            canonical_digest_deferred: true,
            path_bytes_redacted: true,
            file_access_blocked: true,
        }
    }

    pub fn server_denied() -> Self {
        Self {
            owner_manifest_required: false,
            owner_absolute_path_required: false,
            relative_path_rejected: true,
            tilde_expansion_rejected: true,
            environment_expansion_rejected: true,
            parent_traversal_rejected: true,
            unicode_control_rejected: true,
            nul_byte_rejected: true,
            symlink_follow_rejected: true,
            allowed_roots_policy_required: false,
            sandbox_boundary_required: true,
            canonical_digest_deferred: true,
            path_bytes_redacted: true,
            file_access_blocked: true,
        }
    }

    pub fn rejects_all_unsafe_path_shapes(&self) -> bool {
        self.relative_path_rejected
            && self.tilde_expansion_rejected
            && self.environment_expansion_rejected
            && self.parent_traversal_rejected
            && self.unicode_control_rejected
            && self.nul_byte_rejected
            && self.symlink_follow_rejected
            && self.sandbox_boundary_required
            && self.canonical_digest_deferred
            && self.path_bytes_redacted
            && self.file_access_blocked
    }
}

// UAS: uas:exotic-quant-owner-path-canonicalization:byte-ledger
// Plane: Verification
// Residency: every path/file/model/runtime counter stays zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathCanonicalizationByteLedger {
    pub metadata_bytes_read: u64,
    pub owner_manifest_bytes_read: u64,
    pub owner_path_bytes_read: u64,
    pub raw_path_bytes_stored: u64,
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
    pub source_tree_bytes_read: u64,
    pub product_bytes_copied: u64,
    pub benchmark_runs: u64,
}

impl OwnerPathCanonicalizationByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            owner_manifest_bytes_read: 0,
            owner_path_bytes_read: 0,
            raw_path_bytes_stored: 0,
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
            source_tree_bytes_read: 0,
            product_bytes_copied: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:exotic-quant-owner-path-canonicalization:refs
// Plane: Verification
// Residency: visible proof refs required before any path can promote.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathCanonicalizationProofRefs {
    pub upstream_manifest_intake_ref: String,
    pub source_pin_card_ref: String,
    pub byte_budget_ref: String,
    pub path_policy_ref: String,
    pub canonicalization_preflight_ref: String,
    pub allowed_roots_policy_ref: String,
    pub command_envelope_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
}

// UAS: uas:exotic-quant-owner-path-canonicalization:card
// Plane: Controller + Verification
// Residency: per-row path preflight card; never local file availability.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathCanonicalizationPreflightCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub state: OwnerPathCanonicalizationState,
    pub action: OwnerPathCanonicalizationAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub envelope: OwnerPathManifestByteEnvelope,
    pub path_policy: OwnerPathCanonicalizationPolicy,
    pub byte_ledger: OwnerPathCanonicalizationByteLedger,
    pub proof_refs: OwnerPathCanonicalizationProofRefs,
    pub user_visible_summary: String,
    pub canonicalization_policy_compiled: bool,
    pub owner_manifest_present: bool,
    pub owner_supplied_path_present: bool,
    pub raw_path_stored: bool,
    pub canonical_path_bound: bool,
    pub path_canonicalization_attempted: bool,
    pub path_normalized: bool,
    pub path_digest_bound: bool,
    pub file_open_allowed: bool,
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

// UAS: uas:exotic-quant-owner-path-canonicalization:ledger
// Plane: Controller + Verification
// Residency: metadata-only path policy bound to manifest-intake proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathCanonicalizationPreflightLedger {
    pub ledger_address: UasAddress,
    pub upstream_manifest_intake_gate_address: UasAddress,
    pub upstream_manifest_intake_gate_ref: String,
    pub cards: Vec<OwnerPathCanonicalizationPreflightCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub path_policy_compiled: bool,
    pub owner_path_bytes_loaded: bool,
    pub file_access_deferred: bool,
    pub runtime_deferred: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-owner-path-canonicalization:metrics
// Plane: Verification
// Residency: derived path-policy counts and zero-byte counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathCanonicalizationPreflightMetrics {
    pub gate_card_count: u64,
    pub mac_policy_compiled_count: u64,
    pub server_only_denied_count: u64,
    pub owner_manifest_present_count: u64,
    pub owner_supplied_path_present_count: u64,
    pub raw_path_stored_count: u64,
    pub canonical_path_bound_count: u64,
    pub path_canonicalization_attempted_count: u64,
    pub path_normalized_count: u64,
    pub path_digest_bound_count: u64,
    pub file_open_allowed_count: u64,
    pub file_hash_allowed_count: u64,
    pub command_envelope_unarmed_count: u64,
    pub selected_artifact_bytes_sum: u64,
    pub minimum_uma_bytes_required_max: u64,
    pub owner_manifest_bytes_read_total: u64,
    pub owner_path_bytes_read_total: u64,
    pub raw_path_bytes_stored_total: u64,
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
    pub source_tree_bytes_read_total: u64,
    pub product_bytes_copied_total: u64,
    pub benchmark_runs_total: u64,
}

impl OwnerPathCanonicalizationPreflightLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_manifest_intake_gate_address: UasAddress,
        upstream_manifest_intake_gate_ref: impl Into<String>,
        mut cards: Vec<OwnerPathCanonicalizationPreflightCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        path_policy_compiled: bool,
        owner_path_bytes_loaded: bool,
        file_access_deferred: bool,
        runtime_deferred: bool,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, OwnerPathCanonicalizationPreflightError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_manifest_intake_gate_ref = upstream_manifest_intake_gate_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger(
            &upstream_manifest_intake_gate_address,
            &upstream_manifest_intake_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            path_policy_compiled,
            owner_path_bytes_loaded,
            file_access_deferred,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_manifest_intake_gate_address,
            &upstream_manifest_intake_gate_ref,
            &cards,
            metadata_bytes,
            path_policy_compiled,
            file_access_deferred,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(
                EXOTIC_QUANT_OWNER_PATH_CANONICALIZATION_PREFLIGHT_GATE_CURSOR.to_string(),
            ),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_manifest_intake_gate_address,
            upstream_manifest_intake_gate_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            path_policy_compiled,
            owner_path_bytes_loaded,
            file_access_deferred,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> OwnerPathCanonicalizationPreflightMetrics {
        let mut metrics = OwnerPathCanonicalizationPreflightMetrics {
            gate_card_count: self.cards.len() as u64,
            mac_policy_compiled_count: 0,
            server_only_denied_count: 0,
            owner_manifest_present_count: 0,
            owner_supplied_path_present_count: 0,
            raw_path_stored_count: 0,
            canonical_path_bound_count: 0,
            path_canonicalization_attempted_count: 0,
            path_normalized_count: 0,
            path_digest_bound_count: 0,
            file_open_allowed_count: 0,
            file_hash_allowed_count: 0,
            command_envelope_unarmed_count: 0,
            selected_artifact_bytes_sum: 0,
            minimum_uma_bytes_required_max: 0,
            owner_manifest_bytes_read_total: 0,
            owner_path_bytes_read_total: 0,
            raw_path_bytes_stored_total: 0,
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
            source_tree_bytes_read_total: 0,
            product_bytes_copied_total: 0,
            benchmark_runs_total: 0,
        };
        for card in &self.cards {
            if card.canonicalization_policy_compiled
                && card.state
                    == OwnerPathCanonicalizationState::OwnerManifestMissingCanonicalizationBlocked
            {
                metrics.mac_policy_compiled_count += 1;
            }
            if card.state == OwnerPathCanonicalizationState::ServerOnlyCanonicalizationDenied {
                metrics.server_only_denied_count += 1;
            }
            if card.owner_manifest_present {
                metrics.owner_manifest_present_count += 1;
            }
            if card.owner_supplied_path_present {
                metrics.owner_supplied_path_present_count += 1;
            }
            if card.raw_path_stored {
                metrics.raw_path_stored_count += 1;
            }
            if card.canonical_path_bound {
                metrics.canonical_path_bound_count += 1;
            }
            if card.path_canonicalization_attempted {
                metrics.path_canonicalization_attempted_count += 1;
            }
            if card.path_normalized {
                metrics.path_normalized_count += 1;
            }
            if card.path_digest_bound {
                metrics.path_digest_bound_count += 1;
            }
            if card.file_open_allowed {
                metrics.file_open_allowed_count += 1;
            }
            if card.file_hash_allowed {
                metrics.file_hash_allowed_count += 1;
            }
            if card.command_envelope_visible && !card.command_armed {
                metrics.command_envelope_unarmed_count += 1;
            }
            metrics.selected_artifact_bytes_sum += card.envelope.selected_artifact_bytes;
            metrics.minimum_uma_bytes_required_max = metrics
                .minimum_uma_bytes_required_max
                .max(card.envelope.minimum_uma_bytes_required);
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
            metrics.owner_path_bytes_read_total += card.byte_ledger.owner_path_bytes_read;
            metrics.raw_path_bytes_stored_total += card.byte_ledger.raw_path_bytes_stored;
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
            metrics.source_tree_bytes_read_total += card.byte_ledger.source_tree_bytes_read;
            metrics.product_bytes_copied_total += card.byte_ledger.product_bytes_copied;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
        }
        metrics
    }
}

// UAS: uas:exotic-quant-owner-path-canonicalization:error
// Plane: Verification
// Residency: every error fails closed before file access can begin.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OwnerPathCanonicalizationPreflightError {
    EmptyLedger,
    BadUpstreamManifestIntakeRef,
    BadLedgerState,
    BadNextCursor,
    MetadataBudgetExceeded,
    DuplicateGateId(String),
    DuplicateModelId(String),
    DuplicateSourcePinCardId(String),
    MissingExpectedModel(&'static str),
    UnknownModelId(String),
    BadExpectedPolicy(String),
    BadText(String),
    BadPrefix(String),
    BadByteLedger(String),
    PathShortcut(String),
    RuntimeAuthority(String),
    ProductPromotion(String),
    HiddenAuthority(String),
    SourceContamination(String),
    MissingProofSurface(String),
}

impl fmt::Display for OwnerPathCanonicalizationPreflightError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "owner path canonicalization ledger is empty"),
            Self::BadUpstreamManifestIntakeRef => write!(f, "bad upstream manifest intake ref"),
            Self::BadLedgerState => write!(f, "canonicalization preflight ledger state is invalid"),
            Self::BadNextCursor => write!(f, "canonicalization preflight ledger has bad cursor"),
            Self::MetadataBudgetExceeded => {
                write!(f, "canonicalization preflight metadata budget exceeded")
            }
            Self::DuplicateGateId(id) => write!(f, "duplicate gate id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id `{id}`"),
            Self::DuplicateSourcePinCardId(id) => write!(f, "duplicate source-pin id `{id}`"),
            Self::MissingExpectedModel(id) => write!(f, "missing expected model `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown model `{id}`"),
            Self::BadExpectedPolicy(id) => write!(f, "bad path policy on `{id}`"),
            Self::BadText(id) => write!(f, "bad text field on `{id}`"),
            Self::BadPrefix(id) => write!(f, "bad proof-ref prefix on `{id}`"),
            Self::BadByteLedger(id) => write!(f, "bad byte ledger on `{id}`"),
            Self::PathShortcut(id) => write!(f, "path shortcut attempted by `{id}`"),
            Self::RuntimeAuthority(id) => write!(f, "runtime authority attempted by `{id}`"),
            Self::ProductPromotion(id) => write!(f, "product promotion attempted by `{id}`"),
            Self::HiddenAuthority(id) => write!(f, "hidden authority attempted by `{id}`"),
            Self::SourceContamination(id) => write!(f, "source contamination attempted by `{id}`"),
            Self::MissingProofSurface(id) => write!(f, "missing proof surface on `{id}`"),
        }
    }
}

impl std::error::Error for OwnerPathCanonicalizationPreflightError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger(
    upstream_manifest_intake_gate_address: &UasAddress,
    upstream_manifest_intake_gate_ref: &str,
    cards: &[OwnerPathCanonicalizationPreflightCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    path_policy_compiled: bool,
    owner_path_bytes_loaded: bool,
    file_access_deferred: bool,
    runtime_deferred: bool,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    if upstream_manifest_intake_gate_address
        .to_string()
        .trim()
        .is_empty()
        || !upstream_manifest_intake_gate_ref.starts_with(UPSTREAM_MANIFEST_INTAKE_PREFIX)
    {
        return Err(OwnerPathCanonicalizationPreflightError::BadUpstreamManifestIntakeRef);
    }
    if cards.is_empty() {
        return Err(OwnerPathCanonicalizationPreflightError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(OwnerPathCanonicalizationPreflightError::MetadataBudgetExceeded);
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || !path_policy_compiled
        || owner_path_bytes_loaded
        || !file_access_deferred
        || !runtime_deferred
        || !l1_l2_l3_separated
        || !product_promotion_blocked
    {
        return Err(OwnerPathCanonicalizationPreflightError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_OWNER_PATH_CANONICALIZATION_PREFLIGHT_GATE_NEXT_CURSOR {
        return Err(OwnerPathCanonicalizationPreflightError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(OwnerPathCanonicalizationPreflightError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(OwnerPathCanonicalizationPreflightError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(
                OwnerPathCanonicalizationPreflightError::DuplicateSourcePinCardId(
                    card.source_pin_card_id.clone(),
                ),
            );
        }
    }
    for expected in expected_owner_path_manifest_model_ids() {
        if !model_ids.contains(expected) {
            return Err(OwnerPathCanonicalizationPreflightError::MissingExpectedModel(expected));
        }
    }
    Ok(())
}

fn validate_card(
    card: &OwnerPathCanonicalizationPreflightCard,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
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
        return Err(
            OwnerPathCanonicalizationPreflightError::MissingProofSurface(card.gate_id.clone()),
        );
    }
    if !expected_owner_path_manifest_model_ids()
        .iter()
        .any(|expected| expected == &card.model_id)
    {
        return Err(OwnerPathCanonicalizationPreflightError::UnknownModelId(
            card.model_id.clone(),
        ));
    }
    validate_refs(card)?;
    validate_expected_policy(card)?;
    validate_byte_ledger(card)?;
    validate_boundaries(card)?;
    validate_proof_surfaces(card)?;
    Ok(())
}

fn validate_expected_policy(
    card: &OwnerPathCanonicalizationPreflightCard,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    let mac_candidate = is_mac_candidate_source_pin(&card.source_pin_card_id);
    if mac_candidate {
        if card.state != OwnerPathCanonicalizationState::OwnerManifestMissingCanonicalizationBlocked
            || card.action != OwnerPathCanonicalizationAction::CompileFailClosedPathPolicy
            || card.path_policy != OwnerPathCanonicalizationPolicy::mac_manifest_missing()
            || !card.canonicalization_policy_compiled
        {
            return Err(OwnerPathCanonicalizationPreflightError::BadExpectedPolicy(
                card.gate_id.clone(),
            ));
        }
    } else if card.state != OwnerPathCanonicalizationState::ServerOnlyCanonicalizationDenied
        || card.action != OwnerPathCanonicalizationAction::DenyMacCanonicalizationPreflight
        || card.path_policy != OwnerPathCanonicalizationPolicy::server_denied()
        || card.canonicalization_policy_compiled
    {
        return Err(OwnerPathCanonicalizationPreflightError::BadExpectedPolicy(
            card.gate_id.clone(),
        ));
    }
    if !card.path_policy.rejects_all_unsafe_path_shapes() {
        return Err(OwnerPathCanonicalizationPreflightError::BadExpectedPolicy(
            card.gate_id.clone(),
        ));
    }
    if card.owner_manifest_present
        || card.owner_supplied_path_present
        || card.raw_path_stored
        || card.canonical_path_bound
        || card.path_canonicalization_attempted
        || card.path_normalized
        || card.path_digest_bound
        || card.file_open_allowed
        || card.file_stat_allowed
        || card.file_hash_allowed
        || card.symlink_follow_allowed
    {
        return Err(OwnerPathCanonicalizationPreflightError::PathShortcut(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_refs(
    card: &OwnerPathCanonicalizationPreflightCard,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    let expected_refs = [
        (
            &card.proof_refs.upstream_manifest_intake_ref,
            UPSTREAM_MANIFEST_INTAKE_PREFIX,
        ),
        (&card.proof_refs.source_pin_card_ref, SOURCE_PIN_CARD_PREFIX),
        (&card.proof_refs.byte_budget_ref, BYTE_BUDGET_PREFIX),
        (&card.proof_refs.path_policy_ref, PATH_POLICY_PREFIX),
        (
            &card.proof_refs.canonicalization_preflight_ref,
            CANONICALIZATION_PREFLIGHT_PREFIX,
        ),
        (
            &card.proof_refs.allowed_roots_policy_ref,
            ALLOWED_ROOTS_POLICY_PREFIX,
        ),
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
            return Err(OwnerPathCanonicalizationPreflightError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    for value in [
        &card.proof_refs.source_pin_card_ref,
        &card.proof_refs.byte_budget_ref,
        &card.proof_refs.path_policy_ref,
        &card.proof_refs.canonicalization_preflight_ref,
        &card.proof_refs.allowed_roots_policy_ref,
        &card.proof_refs.command_envelope_ref,
        &card.proof_refs.rollback_ref,
        &card.proof_refs.run_event_log_ref,
        &card.proof_refs.answer_packet_ref,
        &card.proof_refs.abstention_ref,
        &card.proof_refs.sovereign_gate_ref,
    ] {
        if !value.ends_with(&card.source_pin_card_id) {
            return Err(OwnerPathCanonicalizationPreflightError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &OwnerPathCanonicalizationPreflightCard,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    let ledger = &card.byte_ledger;
    if ledger.metadata_bytes_read == 0 || ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(OwnerPathCanonicalizationPreflightError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    if ledger.owner_manifest_bytes_read != 0
        || ledger.owner_path_bytes_read != 0
        || ledger.raw_path_bytes_stored != 0
        || ledger.canonical_path_bytes_stored != 0
        || ledger.path_canonicalization_attempts != 0
        || ledger.local_path_open_attempts != 0
        || ledger.file_stat_calls != 0
        || ledger.file_hash_attempts != 0
        || ledger.symlink_resolution_attempts != 0
        || ledger.command_execution_count != 0
        || ledger.model_bytes_loaded != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.provider_calls_made != 0
        || ledger.source_tree_bytes_read != 0
        || ledger.product_bytes_copied != 0
        || ledger.benchmark_runs != 0
    {
        return Err(OwnerPathCanonicalizationPreflightError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_boundaries(
    card: &OwnerPathCanonicalizationPreflightCard,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        || card.mas_allowed
        || card.product_route_enabled
        || card.app_default_claim
        || card.product_winner_claim
        || card.l2_l3_promotion_claim
    {
        return Err(OwnerPathCanonicalizationPreflightError::ProductPromotion(
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
        return Err(OwnerPathCanonicalizationPreflightError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.live_dense_70b_claim
        || card.ssd_as_ram_claim
        || card.source_import_allowed
        || card.benchmark_as_fit_proof
    {
        return Err(
            OwnerPathCanonicalizationPreflightError::SourceContamination(card.gate_id.clone()),
        );
    }
    if card.command_armed || card.runtime_probe_allowed || !card.runtime_deferred {
        return Err(OwnerPathCanonicalizationPreflightError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &OwnerPathCanonicalizationPreflightCard,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    if !card.command_envelope_visible
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(
            OwnerPathCanonicalizationPreflightError::MissingProofSurface(card.gate_id.clone()),
        );
    }
    Ok(())
}

fn validate_text(
    value: &str,
    gate_id: &str,
) -> Result<(), OwnerPathCanonicalizationPreflightError> {
    if value.trim().is_empty() || value.contains('\0') || value.chars().any(char::is_control) {
        return Err(OwnerPathCanonicalizationPreflightError::BadText(
            gate_id.to_string(),
        ));
    }
    Ok(())
}

fn ledger_preimage(
    upstream_manifest_intake_gate_address: &UasAddress,
    upstream_manifest_intake_gate_ref: &str,
    cards: &[OwnerPathCanonicalizationPreflightCard],
    metadata_bytes: u64,
    path_policy_compiled: bool,
    file_access_deferred: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "{upstream_manifest_intake_gate_address}\n{upstream_manifest_intake_gate_ref}\n{metadata_bytes}\n{path_policy_compiled}\n{file_access_deferred}\n{next_cursor}\n"
    );
    for card in cards {
        preimage.push_str(&card.gate_id);
        preimage.push('|');
        preimage.push_str(&card.model_id);
        preimage.push('|');
        preimage.push_str(&card.source_pin_card_id);
        preimage.push('|');
        preimage.push_str(&card.selected_artifact_path);
        preimage.push('|');
        preimage.push_str(&card.envelope.selected_artifact_bytes.to_string());
        preimage.push('|');
        preimage.push_str(&card.envelope.minimum_uma_bytes_required.to_string());
        preimage.push('|');
        preimage.push_str(&format!("{:?}|{:?}\n", card.state, card.action));
    }
    preimage
}

pub fn canonical_owner_path_canonicalization_preflight_cards(
    upstream_manifest_intake_ref: &str,
) -> Vec<OwnerPathCanonicalizationPreflightCard> {
    canonical_owner_path_manifest_intake_cards(upstream_manifest_intake_ref)
        .into_iter()
        .map(|card| canonical_card_from_manifest_intake(&card, upstream_manifest_intake_ref))
        .collect()
}

fn canonical_card_from_manifest_intake(
    manifest_card: &OwnerPathManifestIntakeCard,
    upstream_manifest_intake_ref: &str,
) -> OwnerPathCanonicalizationPreflightCard {
    let mac_candidate = manifest_card.owner_manifest_schema_required;
    let source_pin = &manifest_card.source_pin_card_id;
    OwnerPathCanonicalizationPreflightCard {
        gate_id: format!("{source_pin}_owner_path_canonicalization_preflight"),
        model_id: manifest_card.model_id.clone(),
        source_pin_card_id: source_pin.clone(),
        selected_artifact_path: manifest_card.selected_artifact_path.clone(),
        hardware_tier: manifest_card.hardware_tier,
        runtime_lane: manifest_card.runtime_lane,
        state: if mac_candidate {
            OwnerPathCanonicalizationState::OwnerManifestMissingCanonicalizationBlocked
        } else {
            OwnerPathCanonicalizationState::ServerOnlyCanonicalizationDenied
        },
        action: if mac_candidate {
            OwnerPathCanonicalizationAction::CompileFailClosedPathPolicy
        } else {
            OwnerPathCanonicalizationAction::DenyMacCanonicalizationPreflight
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        envelope: manifest_card.envelope.clone(),
        path_policy: if mac_candidate {
            OwnerPathCanonicalizationPolicy::mac_manifest_missing()
        } else {
            OwnerPathCanonicalizationPolicy::server_denied()
        },
        byte_ledger: OwnerPathCanonicalizationByteLedger::metadata_only(48_000),
        proof_refs: OwnerPathCanonicalizationProofRefs {
            upstream_manifest_intake_ref: upstream_manifest_intake_ref.to_string(),
            source_pin_card_ref: format!("{SOURCE_PIN_CARD_PREFIX}{source_pin}"),
            byte_budget_ref: format!("{BYTE_BUDGET_PREFIX}{source_pin}"),
            path_policy_ref: format!("{PATH_POLICY_PREFIX}{source_pin}"),
            canonicalization_preflight_ref: format!(
                "{CANONICALIZATION_PREFLIGHT_PREFIX}{source_pin}"
            ),
            allowed_roots_policy_ref: format!("{ALLOWED_ROOTS_POLICY_PREFIX}{source_pin}"),
            command_envelope_ref: format!("{COMMAND_ENVELOPE_PREFIX}{source_pin}"),
            rollback_ref: format!("{ROLLBACK_PREFIX}{source_pin}"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{source_pin}"),
            answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{source_pin}"),
            abstention_ref: format!("{ABSTENTION_PREFIX}{source_pin}"),
            sovereign_gate_ref: format!("{SOVEREIGN_GATE_PREFIX}{source_pin}"),
        },
        user_visible_summary: format!(
            "Path canonicalization preflight for {} keeps owner manifest absent, owner path absent, raw path redacted, symlink following denied, file access blocked, commands unarmed, runtime deferred, and no MAS/L2/L3/product promotion while the selected artifact byte envelope remains metadata-only.",
            manifest_card.model_id
        ),
        canonicalization_policy_compiled: mac_candidate,
        owner_manifest_present: false,
        owner_supplied_path_present: false,
        raw_path_stored: false,
        canonical_path_bound: false,
        path_canonicalization_attempted: false,
        path_normalized: false,
        path_digest_bound: false,
        file_open_allowed: false,
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

    const UPSTREAM_REF: &str =
        "artifact:falsifiers/exotic_quant_owner_path_manifest_intake_gate/result.json#F-ExoticQuantOwnerPathManifestIntakeGate";

    fn ledger_from_cards(
        cards: Vec<OwnerPathCanonicalizationPreflightCard>,
    ) -> Result<OwnerPathCanonicalizationPreflightLedger, OwnerPathCanonicalizationPreflightError>
    {
        OwnerPathCanonicalizationPreflightLedger::new(
            UasAddress::new(
                UasKind::Other("upstream_manifest_intake_gate".to_string()),
                b"owner_manifest_intake",
                1_779_500_000_000,
            ),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            288_000,
            true,
            false,
            true,
            true,
            true,
            true,
            EXOTIC_QUANT_OWNER_PATH_CANONICALIZATION_PREFLIGHT_GATE_NEXT_CURSOR,
            1_779_500_000_000,
        )
    }

    #[test]
    fn accepts_fail_closed_policy_without_path_bytes() {
        let cards = canonical_owner_path_canonicalization_preflight_cards(UPSTREAM_REF);
        let ledger = ledger_from_cards(cards).expect("canonical ledger should validate");
        let metrics = ledger.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.mac_policy_compiled_count, 3);
        assert_eq!(metrics.server_only_denied_count, 2);
        assert_eq!(metrics.owner_supplied_path_present_count, 0);
        assert_eq!(metrics.path_canonicalization_attempted_count, 0);
        assert_eq!(metrics.local_path_open_attempts_total, 0);
        assert_eq!(metrics.file_hash_attempts_total, 0);
        assert_eq!(
            ledger.next_cursor,
            EXOTIC_QUANT_OWNER_PATH_CANONICALIZATION_PREFLIGHT_GATE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_path_shortcuts() {
        let mut cards = canonical_owner_path_canonicalization_preflight_cards(UPSTREAM_REF);
        cards[0].owner_supplied_path_present = true;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathCanonicalizationPreflightError::PathShortcut(_))
        ));

        let mut cards = canonical_owner_path_canonicalization_preflight_cards(UPSTREAM_REF);
        cards[0].byte_ledger.path_canonicalization_attempts = 1;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathCanonicalizationPreflightError::BadByteLedger(_))
        ));

        let mut cards = canonical_owner_path_canonicalization_preflight_cards(UPSTREAM_REF);
        cards[0].path_policy.symlink_follow_rejected = false;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(OwnerPathCanonicalizationPreflightError::BadExpectedPolicy(
                _
            ))
        ));
    }

    #[test]
    fn deterministic_address_after_sorting() {
        let cards = canonical_owner_path_canonicalization_preflight_cards(UPSTREAM_REF);
        let mut reversed = cards.clone();
        reversed.reverse();
        let first = ledger_from_cards(cards).expect("first ledger");
        let second = ledger_from_cards(reversed).expect("second ledger");
        assert_eq!(first.ledger_address, second.ledger_address);
    }
}
