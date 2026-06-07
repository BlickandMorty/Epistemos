//! Exotic quant runtime-lane owner-approval gate.
//!
//! This primitive consumes the source-pin byte-budget preflight and records the
//! first fail-closed runtime-lane decision for exotic quant rows. It keeps all
//! commands unarmed, all model paths unopened, all runtime bytes at zero, and
//! all product claims blocked until a later explicit owner-approved witness.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const EXOTIC_QUANT_RUNTIME_LANE_OWNER_APPROVAL_GATE_CURSOR: &str =
    "exotic_quant_runtime_lane_owner_approval_gate";
pub const EXOTIC_QUANT_RUNTIME_LANE_OWNER_APPROVAL_GATE_NEXT_CURSOR: &str =
    "exotic_quant_loader_compatibility_model_path_gate";

const UPSTREAM_PREFLIGHT_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_source_pin_byte_budget_preflight/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:exotic_quant:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:unarmed:exotic_quant:";
const MODEL_PATH_PREFIX: &str = "model_path:pending_owner_approval:exotic_quant:";
const LOADER_COMPAT_PREFIX: &str = "loader_compat:pending_or_denied:exotic_quant:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_owner_gate:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_owner_gate:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_owner_gate:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_owner_gate:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_owner_gate:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;
const MAC_18_GIB_BYTES: u64 = 18 * 1_073_741_824;

// UAS: uas:exotic-quant-owner-gate:decision
// Plane: Controller + Verification
// Residency: fail-closed decision before any runtime bytes may open.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantRuntimeOwnerDecision {
    PendingOwnerApproval,
    DenyServerOnlyOnMac,
}

// UAS: uas:exotic-quant-owner-gate:loader-gate
// Plane: Controller + Verification
// Residency: loader support is a required later proof, not assumed here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantRuntimeLoaderGate {
    PendingCompatibilityProof,
    UnsupportedOnMacServerOnly,
}

// UAS: uas:exotic-quant-owner-gate:action
// Plane: Controller
// Residency: no runtime action is armed by this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantRuntimeOwnerAction {
    HoldUnarmedCommandEnvelope,
    DenyMacRuntimeProbe,
}

#[derive(Clone, Copy)]
struct ExpectedRuntimeLaneProfile {
    model_id: &'static str,
    source_pin_card_id: &'static str,
    hardware_tier: HardwareTier,
    runtime_lane: ModelCatalogRuntimeLane,
    decision: ExoticQuantRuntimeOwnerDecision,
    loader_gate: ExoticQuantRuntimeLoaderGate,
    action: ExoticQuantRuntimeOwnerAction,
    owner_approval_required: bool,
}

const EXPECTED_PROFILES: &[ExpectedRuntimeLaneProfile] = &[
    ExpectedRuntimeLaneProfile {
        model_id: "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
        source_pin_card_id: "qwopus27b_tq3_4s",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        decision: ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval,
        loader_gate: ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof,
        action: ExoticQuantRuntimeOwnerAction::HoldUnarmedCommandEnvelope,
        owner_approval_required: true,
    },
    ExpectedRuntimeLaneProfile {
        model_id: "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
        source_pin_card_id: "qwopus27b_hlwq_q5",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        decision: ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval,
        loader_gate: ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof,
        action: ExoticQuantRuntimeOwnerAction::HoldUnarmedCommandEnvelope,
        owner_approval_required: true,
    },
    ExpectedRuntimeLaneProfile {
        model_id: "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
        source_pin_card_id: "qwopus_moe_35b_a3b_apex_mini",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        decision: ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval,
        loader_gate: ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof,
        action: ExoticQuantRuntimeOwnerAction::HoldUnarmedCommandEnvelope,
        owner_approval_required: true,
    },
    ExpectedRuntimeLaneProfile {
        model_id: "nvidia/Gemma-4-31B-IT-NVFP4",
        source_pin_card_id: "gemma4_31b_nvfp4",
        hardware_tier: HardwareTier::CudaBlackwellOnly,
        runtime_lane: ModelCatalogRuntimeLane::CudaBlackwell,
        decision: ExoticQuantRuntimeOwnerDecision::DenyServerOnlyOnMac,
        loader_gate: ExoticQuantRuntimeLoaderGate::UnsupportedOnMacServerOnly,
        action: ExoticQuantRuntimeOwnerAction::DenyMacRuntimeProbe,
        owner_approval_required: false,
    },
    ExpectedRuntimeLaneProfile {
        model_id: "Intel/gemma-4-31B-it-int4-AutoRound",
        source_pin_card_id: "gemma4_31b_int4_autoround",
        hardware_tier: HardwareTier::ServerGpuResearch,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        decision: ExoticQuantRuntimeOwnerDecision::DenyServerOnlyOnMac,
        loader_gate: ExoticQuantRuntimeLoaderGate::UnsupportedOnMacServerOnly,
        action: ExoticQuantRuntimeOwnerAction::DenyMacRuntimeProbe,
        owner_approval_required: false,
    },
];

// UAS: uas:exotic-quant-owner-gate:byte-ledger
// Plane: Verification
// Residency: planned byte envelopes are metadata; all live counters are zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantRuntimeOwnerByteLedger {
    pub selected_total_bytes: u64,
    pub minimum_uma_bytes_required: u64,
    pub command_envelope_bytes: u64,
    pub loader_metadata_bytes: u64,
    pub model_path_metadata_bytes: u64,
    pub metadata_api_bytes_read: u64,
    pub model_path_open_attempts: u64,
    pub command_execution_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_bytes_copied: u64,
    pub benchmark_runs: u64,
}

impl ExoticQuantRuntimeOwnerByteLedger {
    pub fn metadata_only(
        selected_total_bytes: u64,
        minimum_uma_bytes_required: u64,
        command_envelope_bytes: u64,
        loader_metadata_bytes: u64,
        model_path_metadata_bytes: u64,
        metadata_api_bytes_read: u64,
    ) -> Self {
        Self {
            selected_total_bytes,
            minimum_uma_bytes_required,
            command_envelope_bytes,
            loader_metadata_bytes,
            model_path_metadata_bytes,
            metadata_api_bytes_read,
            model_path_open_attempts: 0,
            command_execution_count: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            source_tree_bytes_read: 0,
            product_bytes_copied: 0,
            benchmark_runs: 0,
        }
    }

    pub fn metadata_bytes(&self) -> u64 {
        self.command_envelope_bytes
            .saturating_add(self.loader_metadata_bytes)
            .saturating_add(self.model_path_metadata_bytes)
            .saturating_add(self.metadata_api_bytes_read)
    }
}

// UAS: uas:exotic-quant-owner-gate:refs
// Plane: Verification
// Residency: visible proof handles required before any runtime gate can open.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantRuntimeOwnerProofRefs {
    pub upstream_preflight_ref: String,
    pub source_pin_card_ref: String,
    pub owner_approval_ref: String,
    pub command_envelope_ref: String,
    pub model_path_readiness_ref: String,
    pub loader_compatibility_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
}

// UAS: uas:exotic-quant-owner-gate:card
// Plane: Controller + Verification
// Residency: per-row owner gate; never a runtime permission by itself.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantRuntimeOwnerGateCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub decision: ExoticQuantRuntimeOwnerDecision,
    pub loader_gate: ExoticQuantRuntimeLoaderGate,
    pub action: ExoticQuantRuntimeOwnerAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub byte_ledger: ExoticQuantRuntimeOwnerByteLedger,
    pub proof_refs: ExoticQuantRuntimeOwnerProofRefs,
    pub user_visible_summary: String,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub model_path_visible: bool,
    pub model_path_opened: bool,
    pub loader_compatibility_required: bool,
    pub loader_compatibility_proven: bool,
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

// UAS: uas:exotic-quant-owner-gate:ledger
// Plane: Controller + Verification
// Residency: metadata-only runtime owner gate bound to source-pin preflight.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantRuntimeOwnerGateLedger {
    pub ledger_address: UasAddress,
    pub upstream_source_pin_preflight_address: UasAddress,
    pub upstream_preflight_ref: String,
    pub cards: Vec<ExoticQuantRuntimeOwnerGateCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-owner-gate:metrics
// Plane: Verification
// Residency: derived owner gate counts and zero-byte counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantRuntimeOwnerGateMetrics {
    pub gate_card_count: u64,
    pub pending_owner_approval_count: u64,
    pub server_only_denied_count: u64,
    pub unarmed_command_envelope_count: u64,
    pub visible_model_path_envelope_count: u64,
    pub loader_compatibility_pending_count: u64,
    pub denied_16_to_18gb_mac_count: u64,
    pub selected_total_bytes_sum: u64,
    pub maximum_minimum_uma_bytes_required: u64,
    pub command_execution_count_total: u64,
    pub model_path_open_attempts_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub source_tree_bytes_read_total: u64,
    pub product_bytes_copied_total: u64,
    pub benchmark_runs_total: u64,
    pub metadata_bytes_read_total: u64,
}

impl ExoticQuantRuntimeOwnerGateLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_source_pin_preflight_address: UasAddress,
        upstream_preflight_ref: impl Into<String>,
        mut cards: Vec<ExoticQuantRuntimeOwnerGateCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, ExoticQuantRuntimeOwnerGateError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_preflight_ref = upstream_preflight_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger_inputs(
            &upstream_source_pin_preflight_address,
            &upstream_preflight_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_source_pin_preflight_address,
            &upstream_preflight_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(EXOTIC_QUANT_RUNTIME_LANE_OWNER_APPROVAL_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_source_pin_preflight_address,
            upstream_preflight_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> ExoticQuantRuntimeOwnerGateMetrics {
        let mut pending_owner_approval_count = 0;
        let mut server_only_denied_count = 0;
        let mut unarmed_command_envelope_count = 0;
        let mut visible_model_path_envelope_count = 0;
        let mut loader_compatibility_pending_count = 0;
        let mut denied_16_to_18gb_mac_count = 0;
        let mut selected_total_bytes_sum = 0;
        let mut maximum_minimum_uma_bytes_required = 0;
        let mut command_execution_count_total = 0;
        let mut model_path_open_attempts_total = 0;
        let mut model_bytes_loaded_total = 0;
        let mut runtime_bytes_loaded_total = 0;
        let mut provider_calls_made_total = 0;
        let mut source_tree_bytes_read_total = 0;
        let mut product_bytes_copied_total = 0;
        let mut benchmark_runs_total = 0;
        let mut metadata_bytes_read_total = self.metadata_bytes;

        for card in &self.cards {
            if card.decision == ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval {
                pending_owner_approval_count += 1;
            }
            if card.decision == ExoticQuantRuntimeOwnerDecision::DenyServerOnlyOnMac {
                server_only_denied_count += 1;
            }
            if card.command_envelope_visible && !card.command_armed {
                unarmed_command_envelope_count += 1;
            }
            if card.model_path_visible && !card.model_path_opened {
                visible_model_path_envelope_count += 1;
            }
            if card.loader_gate == ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof {
                loader_compatibility_pending_count += 1;
            }
            if card.byte_ledger.minimum_uma_bytes_required > MAC_18_GIB_BYTES {
                denied_16_to_18gb_mac_count += 1;
            }
            selected_total_bytes_sum += card.byte_ledger.selected_total_bytes;
            maximum_minimum_uma_bytes_required =
                maximum_minimum_uma_bytes_required.max(card.byte_ledger.minimum_uma_bytes_required);
            command_execution_count_total += card.byte_ledger.command_execution_count;
            model_path_open_attempts_total += card.byte_ledger.model_path_open_attempts;
            model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            provider_calls_made_total += card.byte_ledger.provider_calls_made;
            source_tree_bytes_read_total += card.byte_ledger.source_tree_bytes_read;
            product_bytes_copied_total += card.byte_ledger.product_bytes_copied;
            benchmark_runs_total += card.byte_ledger.benchmark_runs;
            metadata_bytes_read_total += card.byte_ledger.metadata_bytes();
        }

        ExoticQuantRuntimeOwnerGateMetrics {
            gate_card_count: self.cards.len() as u64,
            pending_owner_approval_count,
            server_only_denied_count,
            unarmed_command_envelope_count,
            visible_model_path_envelope_count,
            loader_compatibility_pending_count,
            denied_16_to_18gb_mac_count,
            selected_total_bytes_sum,
            maximum_minimum_uma_bytes_required,
            command_execution_count_total,
            model_path_open_attempts_total,
            model_bytes_loaded_total,
            runtime_bytes_loaded_total,
            provider_calls_made_total,
            source_tree_bytes_read_total,
            product_bytes_copied_total,
            benchmark_runs_total,
            metadata_bytes_read_total,
        }
    }
}

// UAS: uas:exotic-quant-owner-gate:error
// Plane: Verification
// Residency: every error fails closed before a runtime lane can be armed.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExoticQuantRuntimeOwnerGateError {
    EmptyLedger,
    BadUpstreamPreflightRef,
    BadLedgerState,
    BadNextCursor,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicateGateId(String),
    DuplicateModelId(String),
    DuplicateSourcePinCardId(String),
    MissingExpectedModel(&'static str),
    UnknownModelId(String),
    BadExpectedProfile(String),
    MissingField {
        gate_id: String,
        field: &'static str,
    },
    FieldHasSurroundingWhitespace {
        gate_id: String,
        field: &'static str,
    },
    FieldContainsControlCharacter {
        gate_id: String,
        field: &'static str,
    },
    BadPrefix {
        gate_id: String,
        field: &'static str,
        expected: &'static str,
    },
    BadByteLedger {
        gate_id: String,
        reason: &'static str,
    },
    RuntimeAuthority(String),
    ProductPromotion(String),
    HiddenAuthority(String),
    SourceContamination(String),
    MissingProofSurface(String),
}

impl fmt::Display for ExoticQuantRuntimeOwnerGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "exotic quant owner gate ledger is empty"),
            Self::BadUpstreamPreflightRef => write!(f, "bad upstream source-pin preflight ref"),
            Self::BadLedgerState => write!(f, "ledger attempted product/runtime promotion"),
            Self::BadNextCursor => write!(f, "ledger has incorrect next cursor"),
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicateGateId(id) => write!(f, "duplicate gate id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id `{id}`"),
            Self::DuplicateSourcePinCardId(id) => {
                write!(f, "duplicate source-pin card id `{id}`")
            }
            Self::MissingExpectedModel(id) => write!(f, "missing expected model `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown exotic quant model `{id}`"),
            Self::BadExpectedProfile(id) => write!(f, "bad expected profile for `{id}`"),
            Self::MissingField { gate_id, field } => {
                write!(f, "gate `{gate_id}` missing `{field}`")
            }
            Self::FieldHasSurroundingWhitespace { gate_id, field } => {
                write!(
                    f,
                    "gate `{gate_id}` field `{field}` has surrounding whitespace"
                )
            }
            Self::FieldContainsControlCharacter { gate_id, field } => {
                write!(
                    f,
                    "gate `{gate_id}` field `{field}` contains a control character"
                )
            }
            Self::BadPrefix {
                gate_id,
                field,
                expected,
            } => write!(
                f,
                "gate `{gate_id}` field `{field}` must start with `{expected}`"
            ),
            Self::BadByteLedger { gate_id, reason } => {
                write!(f, "gate `{gate_id}` has bad byte ledger: {reason}")
            }
            Self::RuntimeAuthority(id) => write!(f, "gate `{id}` attempted runtime authority"),
            Self::ProductPromotion(id) => write!(f, "gate `{id}` attempted product promotion"),
            Self::HiddenAuthority(id) => write!(f, "gate `{id}` enabled hidden authority"),
            Self::SourceContamination(id) => write!(f, "gate `{id}` allowed source contamination"),
            Self::MissingProofSurface(id) => write!(f, "gate `{id}` missing proof surface"),
        }
    }
}

impl std::error::Error for ExoticQuantRuntimeOwnerGateError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger_inputs(
    upstream_source_pin_preflight_address: &UasAddress,
    upstream_preflight_ref: &str,
    cards: &[ExoticQuantRuntimeOwnerGateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    if upstream_source_pin_preflight_address
        .to_string()
        .trim()
        .is_empty()
        || !upstream_preflight_ref.starts_with(UPSTREAM_PREFLIGHT_PREFIX)
    {
        return Err(ExoticQuantRuntimeOwnerGateError::BadUpstreamPreflightRef);
    }
    if cards.is_empty() {
        return Err(ExoticQuantRuntimeOwnerGateError::EmptyLedger);
    }
    if metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(ExoticQuantRuntimeOwnerGateError::MetadataBudgetExceeded {
            bytes: metadata_bytes,
            max_bytes: MAX_LEDGER_METADATA_BYTES,
        });
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(ExoticQuantRuntimeOwnerGateError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_RUNTIME_LANE_OWNER_APPROVAL_GATE_NEXT_CURSOR {
        return Err(ExoticQuantRuntimeOwnerGateError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(ExoticQuantRuntimeOwnerGateError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(ExoticQuantRuntimeOwnerGateError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(ExoticQuantRuntimeOwnerGateError::DuplicateSourcePinCardId(
                card.source_pin_card_id.clone(),
            ));
        }
    }

    for expected in EXPECTED_PROFILES {
        if !model_ids.contains(expected.model_id) {
            return Err(ExoticQuantRuntimeOwnerGateError::MissingExpectedModel(
                expected.model_id,
            ));
        }
    }
    Ok(())
}

fn validate_card(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    validate_text(&card.gate_id, &card.gate_id, "gate_id")?;
    validate_text(&card.model_id, &card.gate_id, "model_id")?;
    validate_text(
        &card.source_pin_card_id,
        &card.gate_id,
        "source_pin_card_id",
    )?;
    validate_text(
        &card.selected_artifact_path,
        &card.gate_id,
        "selected_artifact_path",
    )?;
    validate_text(
        &card.user_visible_summary,
        &card.gate_id,
        "user_visible_summary",
    )?;
    if card.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(ExoticQuantRuntimeOwnerGateError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    validate_expected_profile(card)?;
    validate_refs(card)?;
    validate_byte_ledger(card)?;
    validate_runtime_boundary(card)?;
    validate_product_boundary(card)?;
    validate_proof_surfaces(card)?;
    Ok(())
}

fn validate_expected_profile(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    let expected = expected_profile(&card.model_id)
        .ok_or_else(|| ExoticQuantRuntimeOwnerGateError::UnknownModelId(card.model_id.clone()))?;
    if card.source_pin_card_id != expected.source_pin_card_id
        || card.hardware_tier != expected.hardware_tier
        || card.runtime_lane != expected.runtime_lane
        || card.decision != expected.decision
        || card.loader_gate != expected.loader_gate
        || card.action != expected.action
        || card.owner_approval_required != expected.owner_approval_required
    {
        return Err(ExoticQuantRuntimeOwnerGateError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    if expected.decision == ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval {
        if !card.loader_compatibility_required || card.loader_compatibility_proven {
            return Err(ExoticQuantRuntimeOwnerGateError::BadExpectedProfile(
                card.model_id.clone(),
            ));
        }
    }
    if expected.decision == ExoticQuantRuntimeOwnerDecision::DenyServerOnlyOnMac {
        if card.loader_compatibility_required || card.loader_compatibility_proven {
            return Err(ExoticQuantRuntimeOwnerGateError::BadExpectedProfile(
                card.model_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_refs(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    let refs = &card.proof_refs;
    require_prefix(
        &refs.upstream_preflight_ref,
        &card.gate_id,
        "upstream_preflight_ref",
        UPSTREAM_PREFLIGHT_PREFIX,
    )?;
    require_prefix(
        &refs.source_pin_card_ref,
        &card.gate_id,
        "source_pin_card_ref",
        SOURCE_PIN_CARD_PREFIX,
    )?;
    if !refs.source_pin_card_ref.ends_with(&card.source_pin_card_id) {
        return Err(ExoticQuantRuntimeOwnerGateError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    require_prefix(
        &refs.owner_approval_ref,
        &card.gate_id,
        "owner_approval_ref",
        OWNER_APPROVAL_PREFIX,
    )?;
    require_prefix(
        &refs.command_envelope_ref,
        &card.gate_id,
        "command_envelope_ref",
        COMMAND_ENVELOPE_PREFIX,
    )?;
    require_prefix(
        &refs.model_path_readiness_ref,
        &card.gate_id,
        "model_path_readiness_ref",
        MODEL_PATH_PREFIX,
    )?;
    require_prefix(
        &refs.loader_compatibility_ref,
        &card.gate_id,
        "loader_compatibility_ref",
        LOADER_COMPAT_PREFIX,
    )?;
    require_prefix(
        &refs.rollback_ref,
        &card.gate_id,
        "rollback_ref",
        ROLLBACK_PREFIX,
    )?;
    require_prefix(
        &refs.run_event_log_ref,
        &card.gate_id,
        "run_event_log_ref",
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        &refs.answer_packet_ref,
        &card.gate_id,
        "answer_packet_ref",
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        &refs.abstention_ref,
        &card.gate_id,
        "abstention_ref",
        ABSTENTION_PREFIX,
    )?;
    require_prefix(
        &refs.sovereign_gate_ref,
        &card.gate_id,
        "sovereign_gate_ref",
        SOVEREIGN_GATE_PREFIX,
    )?;
    Ok(())
}

fn validate_byte_ledger(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    let bytes = &card.byte_ledger;
    if bytes.selected_total_bytes == 0
        || bytes.minimum_uma_bytes_required <= bytes.selected_total_bytes
        || bytes.minimum_uma_bytes_required <= MAC_18_GIB_BYTES
        || bytes.command_envelope_bytes == 0
        || bytes.loader_metadata_bytes == 0
        || bytes.model_path_metadata_bytes == 0
        || bytes.metadata_api_bytes_read == 0
    {
        return Err(ExoticQuantRuntimeOwnerGateError::BadByteLedger {
            gate_id: card.gate_id.clone(),
            reason: "declared selected bytes, minimum UMA, and metadata envelopes must be nonzero and 16-18 GB Mac denied",
        });
    }
    if bytes.metadata_bytes() > MAX_CARD_METADATA_BYTES {
        return Err(ExoticQuantRuntimeOwnerGateError::MetadataBudgetExceeded {
            bytes: bytes.metadata_bytes(),
            max_bytes: MAX_CARD_METADATA_BYTES,
        });
    }
    if bytes.model_path_open_attempts != 0
        || bytes.command_execution_count != 0
        || bytes.model_bytes_loaded != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.provider_calls_made != 0
        || bytes.source_tree_bytes_read != 0
        || bytes.product_bytes_copied != 0
        || bytes.benchmark_runs != 0
    {
        return Err(ExoticQuantRuntimeOwnerGateError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_runtime_boundary(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    if card.owner_approval_granted
        || card.command_armed
        || card.command_executed
        || card.model_path_opened
        || card.runtime_probe_allowed
        || !card.runtime_deferred
    {
        return Err(ExoticQuantRuntimeOwnerGateError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_product_boundary(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        || card.mas_allowed
        || card.product_route_enabled
        || card.app_default_claim
        || card.product_winner_claim
        || card.l2_l3_promotion_claim
        || card.live_dense_70b_claim
        || card.ssd_as_ram_claim
    {
        return Err(ExoticQuantRuntimeOwnerGateError::ProductPromotion(
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
        return Err(ExoticQuantRuntimeOwnerGateError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.source_import_allowed || card.benchmark_as_fit_proof {
        return Err(ExoticQuantRuntimeOwnerGateError::SourceContamination(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &ExoticQuantRuntimeOwnerGateCard,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    if !card.command_envelope_visible
        || !card.model_path_visible
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(ExoticQuantRuntimeOwnerGateError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn expected_profile(model_id: &str) -> Option<ExpectedRuntimeLaneProfile> {
    EXPECTED_PROFILES
        .iter()
        .copied()
        .find(|profile| profile.model_id == model_id)
}

fn validate_text(
    value: &str,
    gate_id: &str,
    field: &'static str,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    if value.is_empty() {
        return Err(ExoticQuantRuntimeOwnerGateError::MissingField {
            gate_id: gate_id.to_string(),
            field,
        });
    }
    if value.trim() != value {
        return Err(
            ExoticQuantRuntimeOwnerGateError::FieldHasSurroundingWhitespace {
                gate_id: gate_id.to_string(),
                field,
            },
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            ExoticQuantRuntimeOwnerGateError::FieldContainsControlCharacter {
                gate_id: gate_id.to_string(),
                field,
            },
        );
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    gate_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), ExoticQuantRuntimeOwnerGateError> {
    validate_text(value, gate_id, field)?;
    if !value.starts_with(expected) {
        return Err(ExoticQuantRuntimeOwnerGateError::BadPrefix {
            gate_id: gate_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn ledger_preimage(
    upstream_source_pin_preflight_address: &UasAddress,
    upstream_preflight_ref: &str,
    cards: &[ExoticQuantRuntimeOwnerGateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "exotic_quant_runtime_lane_owner_approval_gate_v1\n{}\n{}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_source_pin_preflight_address,
        upstream_preflight_ref,
        product_build_preimage(product_build),
        pro_status,
        promotion_tier,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
    );
    preimage.push_str(next_cursor);
    preimage.push('\n');

    for card in cards {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.gate_id,
            card.model_id,
            card.source_pin_card_id,
            card.selected_artifact_path,
            card.hardware_tier,
            card.runtime_lane,
            card.decision,
            card.loader_gate,
            card.action,
            product_build_preimage(&card.product_build),
            card.pro_status,
            card.promotion_tier,
            card.byte_ledger.selected_total_bytes,
            card.byte_ledger.minimum_uma_bytes_required,
            card.byte_ledger.command_envelope_bytes,
            card.byte_ledger.loader_metadata_bytes,
            card.byte_ledger.model_path_metadata_bytes,
            card.byte_ledger.metadata_api_bytes_read,
            card.byte_ledger.model_path_open_attempts,
            card.byte_ledger.command_execution_count,
            card.byte_ledger.model_bytes_loaded,
            card.byte_ledger.runtime_bytes_loaded,
            card.byte_ledger.provider_calls_made,
            card.byte_ledger.source_tree_bytes_read,
            card.byte_ledger.product_bytes_copied,
            card.byte_ledger.benchmark_runs,
            card.proof_refs.upstream_preflight_ref,
            card.proof_refs.source_pin_card_ref,
            card.proof_refs.owner_approval_ref,
            card.proof_refs.command_envelope_ref,
            card.proof_refs.model_path_readiness_ref,
            card.proof_refs.loader_compatibility_ref,
            card.proof_refs.rollback_ref,
            card.proof_refs.run_event_log_ref,
            card.proof_refs.answer_packet_ref,
            card.proof_refs.abstention_ref,
            card.proof_refs.sovereign_gate_ref,
            card.user_visible_summary,
            card.owner_approval_required,
            card.owner_approval_granted,
            card.command_envelope_visible,
            card.command_armed,
            card.command_executed,
            card.model_path_visible,
            card.model_path_opened,
            card.loader_compatibility_required,
            card.loader_compatibility_proven,
            card.runtime_probe_allowed,
            card.runtime_deferred,
            card.rollback_required,
            card.run_event_log_required,
            card.answer_packet_required,
            card.abstention_required,
            card.mas_allowed,
            card.product_route_enabled,
            card.app_default_claim,
            card.product_winner_claim,
            card.route_policy_mutated,
            card.hidden_route_authority,
        ));
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.hidden_cloud_fallback,
            card.patternboost_live_authority,
            card.lattice_live_authority,
            card.eidos_live_authority,
            card.live_dense_70b_claim,
            card.ssd_as_ram_claim,
            card.l2_l3_promotion_claim,
            card.source_import_allowed,
            card.benchmark_as_fit_proof,
        ));
    }
    preimage
}

fn product_build_preimage(product_build: &ProductBuild) -> &'static str {
    match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    }
}

pub fn expected_model_ids() -> BTreeSet<&'static str> {
    EXPECTED_PROFILES
        .iter()
        .map(|profile| profile.model_id)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_327_200_000;
    const UPSTREAM_REF: &str =
        "artifact:falsifiers/exotic_quant_source_pin_byte_budget_preflight/result.json#F-ExoticQuantSourcePinAndByteBudgetPreflight";

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("exotic_quant_source_pin_byte_budget_preflight".to_string()),
            b"source-pin-preflight-test",
            CREATED_AT_MS,
        )
    }

    fn fixture_cards() -> Vec<ExoticQuantRuntimeOwnerGateCard> {
        vec![
            card(
                "qwopus27b_tq3_4s_owner_gate",
                "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
                "qwopus27b_tq3_4s",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval,
                ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof,
                ExoticQuantRuntimeOwnerAction::HoldUnarmedCommandEnvelope,
                true,
            ),
            card(
                "qwopus27b_hlwq_q5_owner_gate",
                "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
                "qwopus27b_hlwq_q5",
                "model_int4.pt",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::Transformers,
                ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval,
                ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof,
                ExoticQuantRuntimeOwnerAction::HoldUnarmedCommandEnvelope,
                true,
            ),
            card(
                "qwopus_moe_apex_owner_gate",
                "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
                "qwopus_moe_35b_a3b_apex_mini",
                "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                ExoticQuantRuntimeOwnerDecision::PendingOwnerApproval,
                ExoticQuantRuntimeLoaderGate::PendingCompatibilityProof,
                ExoticQuantRuntimeOwnerAction::HoldUnarmedCommandEnvelope,
                true,
            ),
            card(
                "gemma4_31b_nvfp4_owner_gate",
                "nvidia/Gemma-4-31B-IT-NVFP4",
                "gemma4_31b_nvfp4",
                "aggregate:nvfp4-safetensors",
                HardwareTier::CudaBlackwellOnly,
                ModelCatalogRuntimeLane::CudaBlackwell,
                ExoticQuantRuntimeOwnerDecision::DenyServerOnlyOnMac,
                ExoticQuantRuntimeLoaderGate::UnsupportedOnMacServerOnly,
                ExoticQuantRuntimeOwnerAction::DenyMacRuntimeProbe,
                false,
            ),
            card(
                "gemma4_31b_autoround_owner_gate",
                "Intel/gemma-4-31B-it-int4-AutoRound",
                "gemma4_31b_int4_autoround",
                "aggregate:autoround-int4",
                HardwareTier::ServerGpuResearch,
                ModelCatalogRuntimeLane::Transformers,
                ExoticQuantRuntimeOwnerDecision::DenyServerOnlyOnMac,
                ExoticQuantRuntimeLoaderGate::UnsupportedOnMacServerOnly,
                ExoticQuantRuntimeOwnerAction::DenyMacRuntimeProbe,
                false,
            ),
        ]
    }

    fn ledger(
        cards: Vec<ExoticQuantRuntimeOwnerGateCard>,
    ) -> Result<ExoticQuantRuntimeOwnerGateLedger, ExoticQuantRuntimeOwnerGateError> {
        ExoticQuantRuntimeOwnerGateLedger::new(
            upstream_address(),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            240_000,
            true,
            true,
            true,
            EXOTIC_QUANT_RUNTIME_LANE_OWNER_APPROVAL_GATE_NEXT_CURSOR,
            CREATED_AT_MS,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn card(
        gate_id: &str,
        model_id: &str,
        source_pin_card_id: &str,
        artifact_path: &str,
        hardware_tier: HardwareTier,
        runtime_lane: ModelCatalogRuntimeLane,
        decision: ExoticQuantRuntimeOwnerDecision,
        loader_gate: ExoticQuantRuntimeLoaderGate,
        action: ExoticQuantRuntimeOwnerAction,
        owner_approval_required: bool,
    ) -> ExoticQuantRuntimeOwnerGateCard {
        ExoticQuantRuntimeOwnerGateCard {
            gate_id: gate_id.to_string(),
            model_id: model_id.to_string(),
            source_pin_card_id: source_pin_card_id.to_string(),
            selected_artifact_path: artifact_path.to_string(),
            hardware_tier,
            runtime_lane,
            decision,
            loader_gate,
            action,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            byte_ledger: ExoticQuantRuntimeOwnerByteLedger::metadata_only(
                14_000_000_000,
                28_000_000_000,
                1024,
                2048,
                2048,
                4096,
            ),
            proof_refs: refs(gate_id, source_pin_card_id),
            user_visible_summary: format!(
                "{gate_id} is a metadata-only exotic quant owner gate with visible command, loader, model-path, rollback, RunEventLog, AnswerPacket, abstention, and no live runtime authority."
            ),
            owner_approval_required,
            owner_approval_granted: false,
            command_envelope_visible: true,
            command_armed: false,
            command_executed: false,
            model_path_visible: true,
            model_path_opened: false,
            loader_compatibility_required: owner_approval_required,
            loader_compatibility_proven: false,
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

    fn refs(gate_id: &str, source_pin_card_id: &str) -> ExoticQuantRuntimeOwnerProofRefs {
        ExoticQuantRuntimeOwnerProofRefs {
            upstream_preflight_ref: UPSTREAM_REF.to_string(),
            source_pin_card_ref: format!("source_pin_card:exotic_quant:{source_pin_card_id}"),
            owner_approval_ref: format!("owner_approval:pending:exotic_quant:{gate_id}"),
            command_envelope_ref: format!("command_envelope:unarmed:exotic_quant:{gate_id}"),
            model_path_readiness_ref: format!(
                "model_path:pending_owner_approval:exotic_quant:{gate_id}"
            ),
            loader_compatibility_ref: format!(
                "loader_compat:pending_or_denied:exotic_quant:{gate_id}"
            ),
            rollback_ref: format!("rollback:exotic_quant_owner_gate:{gate_id}"),
            run_event_log_ref: format!("run_event_log:exotic_quant_owner_gate:{gate_id}"),
            answer_packet_ref: format!("answer_packet:exotic_quant_owner_gate:{gate_id}"),
            abstention_ref: format!("abstention:exotic_quant_owner_gate:{gate_id}"),
            sovereign_gate_ref: format!("sovereign_gate:exotic_quant_owner_gate:{gate_id}"),
        }
    }

    #[test]
    fn accepted_cards_are_deterministic_and_counted() {
        let cards = fixture_cards();
        let witness = ledger(cards.clone()).expect("ledger");
        let reversed = ledger(cards.into_iter().rev().collect()).expect("reversed");
        assert_eq!(witness.ledger_address, reversed.ledger_address);
        let metrics = witness.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.pending_owner_approval_count, 3);
        assert_eq!(metrics.server_only_denied_count, 2);
        assert_eq!(metrics.command_execution_count_total, 0);
    }

    #[test]
    fn rejects_approval_command_runtime_and_hidden_authority() {
        for mutate in [
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.owner_approval_granted = true,
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.command_armed = true,
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.command_executed = true,
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.model_path_opened = true,
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.runtime_probe_allowed = true,
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.hidden_route_authority = true,
            |card: &mut ExoticQuantRuntimeOwnerGateCard| card.live_dense_70b_claim = true,
        ] {
            let mut cards = fixture_cards();
            mutate(&mut cards[0]);
            assert!(ledger(cards).is_err());
        }
    }

    #[test]
    fn rejects_duplicates_bad_profile_and_bad_refs() {
        let mut cards = fixture_cards();
        cards[1] = cards[0].clone();
        cards[1].gate_id = "duplicate_model_gate".to_string();
        assert!(matches!(
            ledger(cards).unwrap_err(),
            ExoticQuantRuntimeOwnerGateError::DuplicateModelId(_)
        ));

        let mut cards = fixture_cards();
        cards[0].hardware_tier = HardwareTier::Mac16To18Gb;
        assert!(matches!(
            ledger(cards).unwrap_err(),
            ExoticQuantRuntimeOwnerGateError::BadExpectedProfile(_)
        ));

        let mut cards = fixture_cards();
        cards[0].proof_refs.owner_approval_ref = "owner:yes".to_string();
        assert!(matches!(
            ledger(cards).unwrap_err(),
            ExoticQuantRuntimeOwnerGateError::BadPrefix { .. }
        ));
    }
}
