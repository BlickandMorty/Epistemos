//! Exotic quant local-artifact availability owner gate.
//!
//! This primitive consumes the loader/path gate and records that promising
//! exotic quant rows still have no owner-approved local artifact availability.
//! It refuses to open paths, stat files, hash weights, arm commands, or treat a
//! filename as runtime proof until a later owner path-manifest witness exists.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_CURSOR: &str =
    "exotic_quant_local_artifact_availability_owner_gate";
pub const EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR: &str =
    "exotic_quant_owner_path_manifest_intake_gate";

const UPSTREAM_LOADER_PATH_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_loader_compatibility_model_path_gate/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const OWNER_MANIFEST_PREFIX: &str = "owner_manifest:required_or_denied:exotic_quant:";
const ARTIFACT_AVAILABILITY_PREFIX: &str = "artifact_availability:not_proven:exotic_quant:";
const PATH_CANONICALIZATION_PREFIX: &str = "path_canonicalization:required_or_denied:exotic_quant:";
const COMMAND_ENVELOPE_PREFIX: &str =
    "command_envelope:unarmed:exotic_quant_artifact_availability:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_artifact_availability:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_artifact_availability:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_artifact_availability:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_artifact_availability:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_artifact_availability:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:exotic-quant-artifact-availability:state
// Plane: Verification
// Residency: local artifact availability remains unproved by this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantArtifactAvailabilityState {
    OwnerManifestMissingNoLocalArtifactVerified,
    ServerOnlyMacArtifactDenied,
}

// UAS: uas:exotic-quant-artifact-availability:action
// Plane: Controller
// Residency: no runtime action can be armed from availability metadata.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantArtifactAvailabilityAction {
    RequireOwnerPathManifest,
    DenyMacArtifactProbe,
}

#[derive(Clone, Copy)]
struct ExpectedArtifactAvailabilityProfile {
    model_id: &'static str,
    source_pin_card_id: &'static str,
    selected_artifact_path: &'static str,
    hardware_tier: HardwareTier,
    runtime_lane: ModelCatalogRuntimeLane,
    availability_state: ExoticQuantArtifactAvailabilityState,
    action: ExoticQuantArtifactAvailabilityAction,
    owner_manifest_required: bool,
}

const EXPECTED_PROFILES: &[ExpectedArtifactAvailabilityProfile] = &[
    ExpectedArtifactAvailabilityProfile {
        model_id: "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
        source_pin_card_id: "qwopus27b_tq3_4s",
        selected_artifact_path: "Qwopus3.5-27B-v3-TQ3_4S.gguf",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        availability_state:
            ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
        action: ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
        owner_manifest_required: true,
    },
    ExpectedArtifactAvailabilityProfile {
        model_id: "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
        source_pin_card_id: "qwopus27b_hlwq_q5",
        selected_artifact_path: "model_int4.pt",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        availability_state:
            ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
        action: ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
        owner_manifest_required: true,
    },
    ExpectedArtifactAvailabilityProfile {
        model_id: "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
        source_pin_card_id: "qwopus_moe_35b_a3b_apex_mini",
        selected_artifact_path: "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        availability_state:
            ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
        action: ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
        owner_manifest_required: true,
    },
    ExpectedArtifactAvailabilityProfile {
        model_id: "nvidia/Gemma-4-31B-IT-NVFP4",
        source_pin_card_id: "gemma4_31b_nvfp4",
        selected_artifact_path: "aggregate:nvfp4-safetensors",
        hardware_tier: HardwareTier::CudaBlackwellOnly,
        runtime_lane: ModelCatalogRuntimeLane::CudaBlackwell,
        availability_state: ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied,
        action: ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe,
        owner_manifest_required: false,
    },
    ExpectedArtifactAvailabilityProfile {
        model_id: "Intel/gemma-4-31B-it-int4-AutoRound",
        source_pin_card_id: "gemma4_31b_int4_autoround",
        selected_artifact_path: "aggregate:autoround-int4",
        hardware_tier: HardwareTier::ServerGpuResearch,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        availability_state: ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied,
        action: ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe,
        owner_manifest_required: false,
    },
];

// UAS: uas:exotic-quant-artifact-availability:byte-ledger
// Plane: Verification
// Residency: owner manifest and path bytes remain zero until later approval.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantArtifactAvailabilityByteLedger {
    pub metadata_bytes_read: u64,
    pub directory_entry_scan_count: u64,
    pub owner_manifest_bytes_read: u64,
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

impl ExoticQuantArtifactAvailabilityByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64, directory_entry_scan_count: u64) -> Self {
        Self {
            metadata_bytes_read,
            directory_entry_scan_count,
            owner_manifest_bytes_read: 0,
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

// UAS: uas:exotic-quant-artifact-availability:refs
// Plane: Verification
// Residency: visible proof refs required before any path can become available.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantArtifactAvailabilityProofRefs {
    pub upstream_loader_path_gate_ref: String,
    pub source_pin_card_ref: String,
    pub owner_manifest_ref: String,
    pub artifact_availability_ref: String,
    pub path_canonicalization_ref: String,
    pub command_envelope_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
}

// UAS: uas:exotic-quant-artifact-availability:card
// Plane: Controller + Verification
// Residency: owner-gated availability card, never path/runtime authority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantArtifactAvailabilityGateCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub availability_state: ExoticQuantArtifactAvailabilityState,
    pub action: ExoticQuantArtifactAvailabilityAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub byte_ledger: ExoticQuantArtifactAvailabilityByteLedger,
    pub proof_refs: ExoticQuantArtifactAvailabilityProofRefs,
    pub user_visible_summary: String,
    pub owner_manifest_required: bool,
    pub owner_manifest_present: bool,
    pub owner_manifest_approved: bool,
    pub owner_manifest_digest_bound: bool,
    pub path_canonicalization_required: bool,
    pub path_canonicalized: bool,
    pub path_directory_entry_seen: bool,
    pub local_path_verified: bool,
    pub local_path_opened: bool,
    pub file_hash_attempted: bool,
    pub symlink_followed: bool,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub command_executed: bool,
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

// UAS: uas:exotic-quant-artifact-availability:ledger
// Plane: Controller + Verification
// Residency: metadata-only owner availability gate bound to loader/path gate.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantArtifactAvailabilityGateLedger {
    pub ledger_address: UasAddress,
    pub upstream_loader_path_gate_address: UasAddress,
    pub upstream_loader_path_gate_ref: String,
    pub cards: Vec<ExoticQuantArtifactAvailabilityGateCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub local_artifact_availability_proven: bool,
    pub owner_manifest_available: bool,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-artifact-availability:metrics
// Plane: Verification
// Residency: derived owner-availability counts and byte-zero counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantArtifactAvailabilityGateMetrics {
    pub gate_card_count: u64,
    pub owner_manifest_required_count: u64,
    pub owner_manifest_present_count: u64,
    pub owner_manifest_approved_count: u64,
    pub path_canonicalization_required_count: u64,
    pub path_canonicalized_count: u64,
    pub local_path_verified_count: u64,
    pub path_directory_entry_seen_count: u64,
    pub server_only_artifact_denied_count: u64,
    pub command_envelope_unarmed_count: u64,
    pub directory_entry_scan_count_total: u64,
    pub owner_manifest_bytes_read_total: u64,
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

impl ExoticQuantArtifactAvailabilityGateLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_loader_path_gate_address: UasAddress,
        upstream_loader_path_gate_ref: impl Into<String>,
        mut cards: Vec<ExoticQuantArtifactAvailabilityGateCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        local_artifact_availability_proven: bool,
        owner_manifest_available: bool,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, ExoticQuantArtifactAvailabilityGateError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_loader_path_gate_ref = upstream_loader_path_gate_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger_inputs(
            &upstream_loader_path_gate_address,
            &upstream_loader_path_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            local_artifact_availability_proven,
            owner_manifest_available,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_loader_path_gate_address,
            &upstream_loader_path_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            local_artifact_availability_proven,
            owner_manifest_available,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_loader_path_gate_address,
            upstream_loader_path_gate_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            local_artifact_availability_proven,
            owner_manifest_available,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> ExoticQuantArtifactAvailabilityGateMetrics {
        let mut metrics = ExoticQuantArtifactAvailabilityGateMetrics {
            gate_card_count: self.cards.len() as u64,
            owner_manifest_required_count: 0,
            owner_manifest_present_count: 0,
            owner_manifest_approved_count: 0,
            path_canonicalization_required_count: 0,
            path_canonicalized_count: 0,
            local_path_verified_count: 0,
            path_directory_entry_seen_count: 0,
            server_only_artifact_denied_count: 0,
            command_envelope_unarmed_count: 0,
            directory_entry_scan_count_total: 0,
            owner_manifest_bytes_read_total: 0,
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
            if card.owner_manifest_required {
                metrics.owner_manifest_required_count += 1;
            }
            if card.owner_manifest_present {
                metrics.owner_manifest_present_count += 1;
            }
            if card.owner_manifest_approved {
                metrics.owner_manifest_approved_count += 1;
            }
            if card.path_canonicalization_required {
                metrics.path_canonicalization_required_count += 1;
            }
            if card.path_canonicalized {
                metrics.path_canonicalized_count += 1;
            }
            if card.local_path_verified {
                metrics.local_path_verified_count += 1;
            }
            if card.path_directory_entry_seen {
                metrics.path_directory_entry_seen_count += 1;
            }
            if card.availability_state
                == ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied
            {
                metrics.server_only_artifact_denied_count += 1;
            }
            if card.command_envelope_visible && !card.command_armed {
                metrics.command_envelope_unarmed_count += 1;
            }
            metrics.directory_entry_scan_count_total += card.byte_ledger.directory_entry_scan_count;
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
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

// UAS: uas:exotic-quant-artifact-availability:error
// Plane: Verification
// Residency: every error fails closed before local artifact availability.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExoticQuantArtifactAvailabilityGateError {
    EmptyLedger,
    BadUpstreamLoaderPathGateRef,
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

impl fmt::Display for ExoticQuantArtifactAvailabilityGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "exotic quant artifact availability ledger is empty"),
            Self::BadUpstreamLoaderPathGateRef => write!(f, "bad upstream loader/path gate ref"),
            Self::BadLedgerState => write!(f, "ledger attempted runtime/product promotion"),
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

impl std::error::Error for ExoticQuantArtifactAvailabilityGateError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger_inputs(
    upstream_loader_path_gate_address: &UasAddress,
    upstream_loader_path_gate_ref: &str,
    cards: &[ExoticQuantArtifactAvailabilityGateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    local_artifact_availability_proven: bool,
    owner_manifest_available: bool,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    if upstream_loader_path_gate_address
        .to_string()
        .trim()
        .is_empty()
        || !upstream_loader_path_gate_ref.starts_with(UPSTREAM_LOADER_PATH_PREFIX)
    {
        return Err(ExoticQuantArtifactAvailabilityGateError::BadUpstreamLoaderPathGateRef);
    }
    if cards.is_empty() {
        return Err(ExoticQuantArtifactAvailabilityGateError::EmptyLedger);
    }
    if metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::MetadataBudgetExceeded {
                bytes: metadata_bytes,
                max_bytes: MAX_LEDGER_METADATA_BYTES,
            },
        );
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || local_artifact_availability_proven
        || owner_manifest_available
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(ExoticQuantArtifactAvailabilityGateError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR {
        return Err(ExoticQuantArtifactAvailabilityGateError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(ExoticQuantArtifactAvailabilityGateError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(ExoticQuantArtifactAvailabilityGateError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(
                ExoticQuantArtifactAvailabilityGateError::DuplicateSourcePinCardId(
                    card.source_pin_card_id.clone(),
                ),
            );
        }
    }
    for expected in EXPECTED_PROFILES {
        if !model_ids.contains(expected.model_id) {
            return Err(
                ExoticQuantArtifactAvailabilityGateError::MissingExpectedModel(expected.model_id),
            );
        }
    }
    Ok(())
}

fn validate_card(
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
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
        return Err(
            ExoticQuantArtifactAvailabilityGateError::MissingProofSurface(card.gate_id.clone()),
        );
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
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    let expected = expected_profile(&card.model_id).ok_or_else(|| {
        ExoticQuantArtifactAvailabilityGateError::UnknownModelId(card.model_id.clone())
    })?;
    if card.source_pin_card_id != expected.source_pin_card_id
        || card.selected_artifact_path != expected.selected_artifact_path
        || card.hardware_tier != expected.hardware_tier
        || card.runtime_lane != expected.runtime_lane
        || card.availability_state != expected.availability_state
        || card.action != expected.action
        || card.owner_manifest_required != expected.owner_manifest_required
    {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::BadExpectedProfile(card.model_id.clone()),
        );
    }
    match expected.availability_state {
        ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified => {
            if !card.path_canonicalization_required
                || card.owner_manifest_present
                || card.owner_manifest_approved
                || card.owner_manifest_digest_bound
                || card.path_canonicalized
                || card.path_directory_entry_seen
                || card.local_path_verified
            {
                return Err(
                    ExoticQuantArtifactAvailabilityGateError::BadExpectedProfile(
                        card.model_id.clone(),
                    ),
                );
            }
        }
        ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied => {
            if card.path_canonicalization_required
                || card.owner_manifest_present
                || card.owner_manifest_approved
                || card.owner_manifest_digest_bound
                || card.path_canonicalized
                || card.path_directory_entry_seen
                || card.local_path_verified
            {
                return Err(
                    ExoticQuantArtifactAvailabilityGateError::BadExpectedProfile(
                        card.model_id.clone(),
                    ),
                );
            }
        }
    }
    Ok(())
}

fn validate_refs(
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    let refs = &card.proof_refs;
    require_prefix(
        &refs.upstream_loader_path_gate_ref,
        &card.gate_id,
        "upstream_loader_path_gate_ref",
        UPSTREAM_LOADER_PATH_PREFIX,
    )?;
    require_prefix(
        &refs.source_pin_card_ref,
        &card.gate_id,
        "source_pin_card_ref",
        SOURCE_PIN_CARD_PREFIX,
    )?;
    if !refs.source_pin_card_ref.ends_with(&card.source_pin_card_id) {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::BadExpectedProfile(card.model_id.clone()),
        );
    }
    require_prefix(
        &refs.owner_manifest_ref,
        &card.gate_id,
        "owner_manifest_ref",
        OWNER_MANIFEST_PREFIX,
    )?;
    require_prefix(
        &refs.artifact_availability_ref,
        &card.gate_id,
        "artifact_availability_ref",
        ARTIFACT_AVAILABILITY_PREFIX,
    )?;
    require_prefix(
        &refs.path_canonicalization_ref,
        &card.gate_id,
        "path_canonicalization_ref",
        PATH_CANONICALIZATION_PREFIX,
    )?;
    require_prefix(
        &refs.command_envelope_ref,
        &card.gate_id,
        "command_envelope_ref",
        COMMAND_ENVELOPE_PREFIX,
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
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    let bytes = &card.byte_ledger;
    if bytes.metadata_bytes_read == 0 || bytes.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::MetadataBudgetExceeded {
                bytes: bytes.metadata_bytes_read,
                max_bytes: MAX_CARD_METADATA_BYTES,
            },
        );
    }
    if card.availability_state
        == ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified
        && bytes.directory_entry_scan_count == 0
    {
        return Err(ExoticQuantArtifactAvailabilityGateError::BadByteLedger {
            gate_id: card.gate_id.clone(),
            reason: "Mac candidates need directory-entry scan evidence even when no artifact is available",
        });
    }
    if bytes.owner_manifest_bytes_read != 0
        || bytes.local_path_open_attempts != 0
        || bytes.file_stat_calls != 0
        || bytes.file_hash_attempts != 0
        || bytes.symlink_resolution_attempts != 0
        || bytes.command_execution_count != 0
        || bytes.model_bytes_loaded != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.provider_calls_made != 0
        || bytes.source_tree_bytes_read != 0
        || bytes.product_bytes_copied != 0
        || bytes.benchmark_runs != 0
    {
        return Err(ExoticQuantArtifactAvailabilityGateError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_runtime_boundary(
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    if card.owner_manifest_present
        || card.owner_manifest_approved
        || card.owner_manifest_digest_bound
        || card.path_canonicalized
        || card.local_path_opened
        || card.file_hash_attempted
        || card.symlink_followed
        || card.command_armed
        || card.command_executed
        || card.runtime_probe_allowed
        || !card.runtime_deferred
    {
        return Err(ExoticQuantArtifactAvailabilityGateError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_product_boundary(
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
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
        return Err(ExoticQuantArtifactAvailabilityGateError::ProductPromotion(
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
        return Err(ExoticQuantArtifactAvailabilityGateError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.source_import_allowed || card.benchmark_as_fit_proof {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::SourceContamination(card.gate_id.clone()),
        );
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &ExoticQuantArtifactAvailabilityGateCard,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    if !card.command_envelope_visible
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::MissingProofSurface(card.gate_id.clone()),
        );
    }
    Ok(())
}

fn expected_profile(model_id: &str) -> Option<ExpectedArtifactAvailabilityProfile> {
    EXPECTED_PROFILES
        .iter()
        .copied()
        .find(|profile| profile.model_id == model_id)
}

fn validate_text(
    value: &str,
    gate_id: &str,
    field: &'static str,
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    if value.is_empty() {
        return Err(ExoticQuantArtifactAvailabilityGateError::MissingField {
            gate_id: gate_id.to_string(),
            field,
        });
    }
    if value.trim() != value {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::FieldHasSurroundingWhitespace {
                gate_id: gate_id.to_string(),
                field,
            },
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            ExoticQuantArtifactAvailabilityGateError::FieldContainsControlCharacter {
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
) -> Result<(), ExoticQuantArtifactAvailabilityGateError> {
    validate_text(value, gate_id, field)?;
    if !value.starts_with(expected) {
        return Err(ExoticQuantArtifactAvailabilityGateError::BadPrefix {
            gate_id: gate_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn ledger_preimage(
    upstream_loader_path_gate_address: &UasAddress,
    upstream_loader_path_gate_ref: &str,
    cards: &[ExoticQuantArtifactAvailabilityGateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    local_artifact_availability_proven: bool,
    owner_manifest_available: bool,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "exotic_quant_local_artifact_availability_owner_gate_v1\n{}\n{}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n",
        upstream_loader_path_gate_address,
        upstream_loader_path_gate_ref,
        product_build_preimage(product_build),
        pro_status,
        promotion_tier,
        metadata_bytes,
        local_artifact_availability_proven,
        owner_manifest_available,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
    );
    preimage.push_str(next_cursor);
    preimage.push('\n');
    for card in cards {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.gate_id,
            card.model_id,
            card.source_pin_card_id,
            card.selected_artifact_path,
            card.hardware_tier,
            card.runtime_lane,
            card.availability_state,
            card.action,
            product_build_preimage(&card.product_build),
            card.pro_status,
            format!("{:?}", card.promotion_tier),
            card.byte_ledger.metadata_bytes_read,
            card.byte_ledger.directory_entry_scan_count,
            card.byte_ledger.owner_manifest_bytes_read,
            card.byte_ledger.local_path_open_attempts,
            card.byte_ledger.file_stat_calls,
            card.byte_ledger.file_hash_attempts,
            card.byte_ledger.symlink_resolution_attempts,
            card.byte_ledger.command_execution_count,
            card.byte_ledger.model_bytes_loaded,
            card.byte_ledger.runtime_bytes_loaded,
            card.byte_ledger.provider_calls_made,
            card.byte_ledger.source_tree_bytes_read,
            card.byte_ledger.product_bytes_copied,
            card.byte_ledger.benchmark_runs,
            card.proof_refs.upstream_loader_path_gate_ref,
            card.proof_refs.source_pin_card_ref,
            card.proof_refs.owner_manifest_ref,
            card.proof_refs.artifact_availability_ref,
            card.proof_refs.path_canonicalization_ref,
            card.proof_refs.command_envelope_ref,
            card.proof_refs.rollback_ref,
            card.proof_refs.run_event_log_ref,
            card.proof_refs.answer_packet_ref,
            card.proof_refs.abstention_ref,
            card.proof_refs.sovereign_gate_ref,
            card.user_visible_summary,
            card.owner_manifest_required,
            card.owner_manifest_present,
            card.owner_manifest_approved,
            card.owner_manifest_digest_bound,
            card.path_canonicalization_required,
            card.path_canonicalized,
            card.path_directory_entry_seen,
            card.local_path_verified,
            card.local_path_opened,
            card.file_hash_attempted,
            card.symlink_followed,
            card.command_envelope_visible,
            card.command_armed,
            card.command_executed,
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
        ));
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.route_policy_mutated,
            card.hidden_route_authority,
            card.hidden_cloud_fallback,
            card.patternboost_live_authority,
            card.lattice_live_authority,
            card.eidos_live_authority,
            card.live_dense_70b_claim,
            card.ssd_as_ram_claim,
            card.l2_l3_promotion_claim,
            card.source_import_allowed,
        ));
        preimage.push_str(&format!("{}\n", card.benchmark_as_fit_proof));
    }
    preimage
}

fn product_build_preimage(product_build: &ProductBuild) -> &'static str {
    match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    }
}

pub fn expected_artifact_availability_model_ids() -> BTreeSet<&'static str> {
    EXPECTED_PROFILES
        .iter()
        .map(|profile| profile.model_id)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_417_200_000;
    const UPSTREAM_REF: &str = "artifact:falsifiers/exotic_quant_loader_compatibility_model_path_gate/result.json#F-ExoticQuantLoaderCompatibilityModelPathGate";

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("exotic_quant_loader_compatibility_model_path_gate".to_string()),
            b"loader-path-gate-test",
            CREATED_AT_MS,
        )
    }

    fn ledger(
        cards: Vec<ExoticQuantArtifactAvailabilityGateCard>,
    ) -> Result<ExoticQuantArtifactAvailabilityGateLedger, ExoticQuantArtifactAvailabilityGateError>
    {
        ExoticQuantArtifactAvailabilityGateLedger::new(
            upstream_address(),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            240_000,
            false,
            false,
            true,
            true,
            true,
            EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR,
            CREATED_AT_MS,
        )
    }

    fn fixture_cards() -> Vec<ExoticQuantArtifactAvailabilityGateCard> {
        vec![
            card(
                "qwopus27b_tq3_4s_artifact_availability_gate",
                "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
                "qwopus27b_tq3_4s",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
                ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
                true,
                1,
            ),
            card(
                "qwopus27b_hlwq_q5_artifact_availability_gate",
                "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
                "qwopus27b_hlwq_q5",
                "model_int4.pt",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::Transformers,
                ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
                ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
                true,
                1,
            ),
            card(
                "qwopus_moe_apex_artifact_availability_gate",
                "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
                "qwopus_moe_35b_a3b_apex_mini",
                "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
                ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
                true,
                1,
            ),
            card(
                "gemma4_31b_nvfp4_artifact_availability_gate",
                "nvidia/Gemma-4-31B-IT-NVFP4",
                "gemma4_31b_nvfp4",
                "aggregate:nvfp4-safetensors",
                HardwareTier::CudaBlackwellOnly,
                ModelCatalogRuntimeLane::CudaBlackwell,
                ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied,
                ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe,
                false,
                0,
            ),
            card(
                "gemma4_31b_autoround_artifact_availability_gate",
                "Intel/gemma-4-31B-it-int4-AutoRound",
                "gemma4_31b_int4_autoround",
                "aggregate:autoround-int4",
                HardwareTier::ServerGpuResearch,
                ModelCatalogRuntimeLane::Transformers,
                ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied,
                ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe,
                false,
                0,
            ),
        ]
    }

    #[allow(clippy::too_many_arguments)]
    fn card(
        gate_id: &str,
        model_id: &str,
        source_pin_card_id: &str,
        selected_artifact_path: &str,
        hardware_tier: HardwareTier,
        runtime_lane: ModelCatalogRuntimeLane,
        availability_state: ExoticQuantArtifactAvailabilityState,
        action: ExoticQuantArtifactAvailabilityAction,
        owner_manifest_required: bool,
        directory_entry_scan_count: u64,
    ) -> ExoticQuantArtifactAvailabilityGateCard {
        ExoticQuantArtifactAvailabilityGateCard {
            gate_id: gate_id.to_string(),
            model_id: model_id.to_string(),
            source_pin_card_id: source_pin_card_id.to_string(),
            selected_artifact_path: selected_artifact_path.to_string(),
            hardware_tier,
            runtime_lane,
            availability_state,
            action,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            byte_ledger: ExoticQuantArtifactAvailabilityByteLedger::metadata_only(
                8192,
                directory_entry_scan_count,
            ),
            proof_refs: refs(gate_id, source_pin_card_id),
            user_visible_summary: format!(
                "{gate_id} records that {model_id} still has no owner-approved local artifact availability. The card requires owner path-manifest intake for Mac candidates, denies server/GPU rows on Mac, keeps command envelopes unarmed, opens no paths, hashes no files, follows no symlinks, and preserves rollback, RunEventLog, AnswerPacket, abstention, and SovereignGate refs."
            ),
            owner_manifest_required,
            owner_manifest_present: false,
            owner_manifest_approved: false,
            owner_manifest_digest_bound: false,
            path_canonicalization_required: owner_manifest_required,
            path_canonicalized: false,
            path_directory_entry_seen: false,
            local_path_verified: false,
            local_path_opened: false,
            file_hash_attempted: false,
            symlink_followed: false,
            command_envelope_visible: true,
            command_armed: false,
            command_executed: false,
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

    fn refs(gate_id: &str, source_pin_card_id: &str) -> ExoticQuantArtifactAvailabilityProofRefs {
        ExoticQuantArtifactAvailabilityProofRefs {
            upstream_loader_path_gate_ref: UPSTREAM_REF.to_string(),
            source_pin_card_ref: format!("source_pin_card:exotic_quant:{source_pin_card_id}"),
            owner_manifest_ref: format!("owner_manifest:required_or_denied:exotic_quant:{gate_id}"),
            artifact_availability_ref: format!(
                "artifact_availability:not_proven:exotic_quant:{gate_id}"
            ),
            path_canonicalization_ref: format!(
                "path_canonicalization:required_or_denied:exotic_quant:{gate_id}"
            ),
            command_envelope_ref: format!(
                "command_envelope:unarmed:exotic_quant_artifact_availability:{gate_id}"
            ),
            rollback_ref: format!("rollback:exotic_quant_artifact_availability:{gate_id}"),
            run_event_log_ref: format!(
                "run_event_log:exotic_quant_artifact_availability:{gate_id}"
            ),
            answer_packet_ref: format!(
                "answer_packet:exotic_quant_artifact_availability:{gate_id}"
            ),
            abstention_ref: format!("abstention:exotic_quant_artifact_availability:{gate_id}"),
            sovereign_gate_ref: format!(
                "sovereign_gate:exotic_quant_artifact_availability:{gate_id}"
            ),
        }
    }

    #[test]
    fn ledger_accepts_owner_manifest_missing_state() {
        let ledger = ledger(fixture_cards()).expect("ledger");
        let metrics = ledger.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.owner_manifest_required_count, 3);
        assert_eq!(metrics.owner_manifest_present_count, 0);
        assert_eq!(metrics.local_path_verified_count, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
    }

    #[test]
    fn owner_manifest_or_path_availability_rejects_without_later_gate() {
        let mut cards = fixture_cards();
        cards[0].owner_manifest_present = true;
        assert!(ledger(cards).is_err());
        let mut cards = fixture_cards();
        cards[0].local_path_verified = true;
        assert!(ledger(cards).is_err());
    }

    #[test]
    fn ledger_address_is_deterministic_after_sorting() {
        let forward = ledger(fixture_cards()).expect("forward");
        let mut reversed = fixture_cards();
        reversed.reverse();
        let reverse = ledger(reversed).expect("reverse");
        assert_eq!(forward.ledger_address, reverse.ledger_address);
    }
}
