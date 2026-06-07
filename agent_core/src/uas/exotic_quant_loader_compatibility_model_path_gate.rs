//! Exotic quant loader compatibility + model-path gate.
//!
//! This primitive consumes the runtime-lane owner-approval gate and binds each
//! exotic quant row to a loader compatibility class plus a fail-closed model
//! path state. It does not open paths, hash files, arm commands, import source,
//! run loaders, or promote product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const EXOTIC_QUANT_LOADER_COMPATIBILITY_MODEL_PATH_GATE_CURSOR: &str =
    "exotic_quant_loader_compatibility_model_path_gate";
pub const EXOTIC_QUANT_LOADER_COMPATIBILITY_MODEL_PATH_GATE_NEXT_CURSOR: &str =
    "exotic_quant_local_artifact_availability_owner_gate";

const UPSTREAM_OWNER_GATE_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_runtime_lane_owner_approval_gate/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const LOADER_CLASS_PREFIX: &str = "loader_compat:class_bound:exotic_quant:";
const MODEL_PATH_MANIFEST_PREFIX: &str = "model_path_manifest:required_or_denied:exotic_quant:";
const DIRECTORY_SCAN_PREFIX: &str = "directory_entry_scan:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:unarmed:exotic_quant_loader_path:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_loader_path:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_loader_path:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_loader_path:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_loader_path:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_loader_path:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:exotic-quant-loader-path:loader-class
// Plane: Controller + Verification
// Residency: compatibility class only; no loader has executed here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantLoaderCompatibilityClass {
    GgufLlamaCppMetadataOnly,
    TransformersLocalDirectoryMetadataOnly,
    CudaBlackwellServerOnlyDenied,
    AutoRoundTransformersServerResearchDenied,
}

// UAS: uas:exotic-quant-loader-path:path-state
// Plane: Verification
// Residency: local path state stays fail-closed until owner artifact proof.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantModelPathState {
    OwnerPathManifestRequiredNoLocalFileSeen,
    ServerOnlyMacPathDenied,
}

// UAS: uas:exotic-quant-loader-path:action
// Plane: Controller
// Residency: path/loader classification is not runtime authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExoticQuantLoaderPathAction {
    HoldForOwnerArtifactAvailability,
    DenyMacPathAndLoaderProbe,
}

#[derive(Clone, Copy)]
struct ExpectedLoaderPathProfile {
    model_id: &'static str,
    source_pin_card_id: &'static str,
    selected_artifact_path: &'static str,
    hardware_tier: HardwareTier,
    runtime_lane: ModelCatalogRuntimeLane,
    loader_class: ExoticQuantLoaderCompatibilityClass,
    path_state: ExoticQuantModelPathState,
    action: ExoticQuantLoaderPathAction,
    owner_approval_required: bool,
}

const EXPECTED_PROFILES: &[ExpectedLoaderPathProfile] = &[
    ExpectedLoaderPathProfile {
        model_id: "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
        source_pin_card_id: "qwopus27b_tq3_4s",
        selected_artifact_path: "Qwopus3.5-27B-v3-TQ3_4S.gguf",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        loader_class: ExoticQuantLoaderCompatibilityClass::GgufLlamaCppMetadataOnly,
        path_state: ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen,
        action: ExoticQuantLoaderPathAction::HoldForOwnerArtifactAvailability,
        owner_approval_required: true,
    },
    ExpectedLoaderPathProfile {
        model_id: "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
        source_pin_card_id: "qwopus27b_hlwq_q5",
        selected_artifact_path: "model_int4.pt",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        loader_class: ExoticQuantLoaderCompatibilityClass::TransformersLocalDirectoryMetadataOnly,
        path_state: ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen,
        action: ExoticQuantLoaderPathAction::HoldForOwnerArtifactAvailability,
        owner_approval_required: true,
    },
    ExpectedLoaderPathProfile {
        model_id: "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
        source_pin_card_id: "qwopus_moe_35b_a3b_apex_mini",
        selected_artifact_path: "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        loader_class: ExoticQuantLoaderCompatibilityClass::GgufLlamaCppMetadataOnly,
        path_state: ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen,
        action: ExoticQuantLoaderPathAction::HoldForOwnerArtifactAvailability,
        owner_approval_required: true,
    },
    ExpectedLoaderPathProfile {
        model_id: "nvidia/Gemma-4-31B-IT-NVFP4",
        source_pin_card_id: "gemma4_31b_nvfp4",
        selected_artifact_path: "aggregate:nvfp4-safetensors",
        hardware_tier: HardwareTier::CudaBlackwellOnly,
        runtime_lane: ModelCatalogRuntimeLane::CudaBlackwell,
        loader_class: ExoticQuantLoaderCompatibilityClass::CudaBlackwellServerOnlyDenied,
        path_state: ExoticQuantModelPathState::ServerOnlyMacPathDenied,
        action: ExoticQuantLoaderPathAction::DenyMacPathAndLoaderProbe,
        owner_approval_required: false,
    },
    ExpectedLoaderPathProfile {
        model_id: "Intel/gemma-4-31B-it-int4-AutoRound",
        source_pin_card_id: "gemma4_31b_int4_autoround",
        selected_artifact_path: "aggregate:autoround-int4",
        hardware_tier: HardwareTier::ServerGpuResearch,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        loader_class:
            ExoticQuantLoaderCompatibilityClass::AutoRoundTransformersServerResearchDenied,
        path_state: ExoticQuantModelPathState::ServerOnlyMacPathDenied,
        action: ExoticQuantLoaderPathAction::DenyMacPathAndLoaderProbe,
        owner_approval_required: false,
    },
];

// UAS: uas:exotic-quant-loader-path:byte-ledger
// Plane: Verification
// Residency: directory-entry checks are metadata; all file/runtime bytes are zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantLoaderPathByteLedger {
    pub metadata_bytes_read: u64,
    pub directory_entry_scan_count: u64,
    pub local_path_open_attempts: u64,
    pub file_stat_calls: u64,
    pub file_hash_attempts: u64,
    pub command_execution_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_bytes_copied: u64,
    pub benchmark_runs: u64,
}

impl ExoticQuantLoaderPathByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64, directory_entry_scan_count: u64) -> Self {
        Self {
            metadata_bytes_read,
            directory_entry_scan_count,
            local_path_open_attempts: 0,
            file_stat_calls: 0,
            file_hash_attempts: 0,
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

// UAS: uas:exotic-quant-loader-path:refs
// Plane: Verification
// Residency: visible proof handles before local artifacts may be opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantLoaderPathProofRefs {
    pub upstream_owner_gate_ref: String,
    pub source_pin_card_ref: String,
    pub loader_class_ref: String,
    pub model_path_manifest_ref: String,
    pub directory_scan_ref: String,
    pub command_envelope_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
}

// UAS: uas:exotic-quant-loader-path:card
// Plane: Controller + Verification
// Residency: loader/path classifier, not runtime permission.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantLoaderPathGateCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub loader_class: ExoticQuantLoaderCompatibilityClass,
    pub path_state: ExoticQuantModelPathState,
    pub action: ExoticQuantLoaderPathAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub byte_ledger: ExoticQuantLoaderPathByteLedger,
    pub proof_refs: ExoticQuantLoaderPathProofRefs,
    pub user_visible_summary: String,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub loader_class_bound: bool,
    pub loader_runtime_proven: bool,
    pub loader_import_attempted: bool,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub model_path_manifest_required: bool,
    pub path_directory_entry_seen: bool,
    pub local_path_verified: bool,
    pub local_path_opened: bool,
    pub file_hash_attempted: bool,
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

// UAS: uas:exotic-quant-loader-path:ledger
// Plane: Controller + Verification
// Residency: metadata-only loader/path gate bound to owner approval gate.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantLoaderPathGateLedger {
    pub ledger_address: UasAddress,
    pub upstream_owner_gate_address: UasAddress,
    pub upstream_owner_gate_ref: String,
    pub cards: Vec<ExoticQuantLoaderPathGateCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub local_artifact_availability_proven: bool,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-loader-path:metrics
// Plane: Verification
// Residency: derived fail-closed loader/path counts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExoticQuantLoaderPathGateMetrics {
    pub gate_card_count: u64,
    pub loader_class_bound_count: u64,
    pub loader_runtime_proven_count: u64,
    pub owner_path_manifest_required_count: u64,
    pub directory_entry_scan_count_total: u64,
    pub path_directory_entry_seen_count: u64,
    pub local_path_verified_count: u64,
    pub server_only_path_denied_count: u64,
    pub command_envelope_unarmed_count: u64,
    pub local_path_open_attempts_total: u64,
    pub file_stat_calls_total: u64,
    pub file_hash_attempts_total: u64,
    pub command_execution_count_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub source_tree_bytes_read_total: u64,
    pub product_bytes_copied_total: u64,
    pub benchmark_runs_total: u64,
}

impl ExoticQuantLoaderPathGateLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_owner_gate_address: UasAddress,
        upstream_owner_gate_ref: impl Into<String>,
        mut cards: Vec<ExoticQuantLoaderPathGateCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        local_artifact_availability_proven: bool,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, ExoticQuantLoaderPathGateError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_owner_gate_ref = upstream_owner_gate_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger_inputs(
            &upstream_owner_gate_address,
            &upstream_owner_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            local_artifact_availability_proven,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_owner_gate_address,
            &upstream_owner_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            local_artifact_availability_proven,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(EXOTIC_QUANT_LOADER_COMPATIBILITY_MODEL_PATH_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_owner_gate_address,
            upstream_owner_gate_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            local_artifact_availability_proven,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> ExoticQuantLoaderPathGateMetrics {
        let mut metrics = ExoticQuantLoaderPathGateMetrics {
            gate_card_count: self.cards.len() as u64,
            loader_class_bound_count: 0,
            loader_runtime_proven_count: 0,
            owner_path_manifest_required_count: 0,
            directory_entry_scan_count_total: 0,
            path_directory_entry_seen_count: 0,
            local_path_verified_count: 0,
            server_only_path_denied_count: 0,
            command_envelope_unarmed_count: 0,
            local_path_open_attempts_total: 0,
            file_stat_calls_total: 0,
            file_hash_attempts_total: 0,
            command_execution_count_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            source_tree_bytes_read_total: 0,
            product_bytes_copied_total: 0,
            benchmark_runs_total: 0,
        };
        for card in &self.cards {
            if card.loader_class_bound {
                metrics.loader_class_bound_count += 1;
            }
            if card.loader_runtime_proven {
                metrics.loader_runtime_proven_count += 1;
            }
            if card.model_path_manifest_required {
                metrics.owner_path_manifest_required_count += 1;
            }
            if card.path_directory_entry_seen {
                metrics.path_directory_entry_seen_count += 1;
            }
            if card.local_path_verified {
                metrics.local_path_verified_count += 1;
            }
            if card.path_state == ExoticQuantModelPathState::ServerOnlyMacPathDenied {
                metrics.server_only_path_denied_count += 1;
            }
            if card.command_envelope_visible && !card.command_armed {
                metrics.command_envelope_unarmed_count += 1;
            }
            metrics.directory_entry_scan_count_total += card.byte_ledger.directory_entry_scan_count;
            metrics.local_path_open_attempts_total += card.byte_ledger.local_path_open_attempts;
            metrics.file_stat_calls_total += card.byte_ledger.file_stat_calls;
            metrics.file_hash_attempts_total += card.byte_ledger.file_hash_attempts;
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

// UAS: uas:exotic-quant-loader-path:error
// Plane: Verification
// Residency: every error fails closed before path bytes can open.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExoticQuantLoaderPathGateError {
    EmptyLedger,
    BadUpstreamOwnerGateRef,
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

impl fmt::Display for ExoticQuantLoaderPathGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "exotic quant loader/path ledger is empty"),
            Self::BadUpstreamOwnerGateRef => write!(f, "bad upstream owner-gate ref"),
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

impl std::error::Error for ExoticQuantLoaderPathGateError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger_inputs(
    upstream_owner_gate_address: &UasAddress,
    upstream_owner_gate_ref: &str,
    cards: &[ExoticQuantLoaderPathGateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    local_artifact_availability_proven: bool,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    if upstream_owner_gate_address.to_string().trim().is_empty()
        || !upstream_owner_gate_ref.starts_with(UPSTREAM_OWNER_GATE_PREFIX)
    {
        return Err(ExoticQuantLoaderPathGateError::BadUpstreamOwnerGateRef);
    }
    if cards.is_empty() {
        return Err(ExoticQuantLoaderPathGateError::EmptyLedger);
    }
    if metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(ExoticQuantLoaderPathGateError::MetadataBudgetExceeded {
            bytes: metadata_bytes,
            max_bytes: MAX_LEDGER_METADATA_BYTES,
        });
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || local_artifact_availability_proven
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(ExoticQuantLoaderPathGateError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_LOADER_COMPATIBILITY_MODEL_PATH_GATE_NEXT_CURSOR {
        return Err(ExoticQuantLoaderPathGateError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(ExoticQuantLoaderPathGateError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(ExoticQuantLoaderPathGateError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(ExoticQuantLoaderPathGateError::DuplicateSourcePinCardId(
                card.source_pin_card_id.clone(),
            ));
        }
    }
    for expected in EXPECTED_PROFILES {
        if !model_ids.contains(expected.model_id) {
            return Err(ExoticQuantLoaderPathGateError::MissingExpectedModel(
                expected.model_id,
            ));
        }
    }
    Ok(())
}

fn validate_card(
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
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
        return Err(ExoticQuantLoaderPathGateError::MissingProofSurface(
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
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    let expected = expected_profile(&card.model_id)
        .ok_or_else(|| ExoticQuantLoaderPathGateError::UnknownModelId(card.model_id.clone()))?;
    if card.source_pin_card_id != expected.source_pin_card_id
        || card.selected_artifact_path != expected.selected_artifact_path
        || card.hardware_tier != expected.hardware_tier
        || card.runtime_lane != expected.runtime_lane
        || card.loader_class != expected.loader_class
        || card.path_state != expected.path_state
        || card.action != expected.action
        || card.owner_approval_required != expected.owner_approval_required
    {
        return Err(ExoticQuantLoaderPathGateError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    match expected.path_state {
        ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen => {
            if !card.model_path_manifest_required
                || card.path_directory_entry_seen
                || card.local_path_verified
            {
                return Err(ExoticQuantLoaderPathGateError::BadExpectedProfile(
                    card.model_id.clone(),
                ));
            }
        }
        ExoticQuantModelPathState::ServerOnlyMacPathDenied => {
            if card.model_path_manifest_required
                || card.path_directory_entry_seen
                || card.local_path_verified
            {
                return Err(ExoticQuantLoaderPathGateError::BadExpectedProfile(
                    card.model_id.clone(),
                ));
            }
        }
    }
    Ok(())
}

fn validate_refs(
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    let refs = &card.proof_refs;
    require_prefix(
        &refs.upstream_owner_gate_ref,
        &card.gate_id,
        "upstream_owner_gate_ref",
        UPSTREAM_OWNER_GATE_PREFIX,
    )?;
    require_prefix(
        &refs.source_pin_card_ref,
        &card.gate_id,
        "source_pin_card_ref",
        SOURCE_PIN_CARD_PREFIX,
    )?;
    if !refs.source_pin_card_ref.ends_with(&card.source_pin_card_id) {
        return Err(ExoticQuantLoaderPathGateError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    require_prefix(
        &refs.loader_class_ref,
        &card.gate_id,
        "loader_class_ref",
        LOADER_CLASS_PREFIX,
    )?;
    require_prefix(
        &refs.model_path_manifest_ref,
        &card.gate_id,
        "model_path_manifest_ref",
        MODEL_PATH_MANIFEST_PREFIX,
    )?;
    require_prefix(
        &refs.directory_scan_ref,
        &card.gate_id,
        "directory_scan_ref",
        DIRECTORY_SCAN_PREFIX,
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
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    let bytes = &card.byte_ledger;
    if bytes.metadata_bytes_read == 0 || bytes.metadata_bytes_read > MAX_CARD_METADATA_BYTES {
        return Err(ExoticQuantLoaderPathGateError::MetadataBudgetExceeded {
            bytes: bytes.metadata_bytes_read,
            max_bytes: MAX_CARD_METADATA_BYTES,
        });
    }
    if card.path_state == ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen
        && bytes.directory_entry_scan_count == 0
    {
        return Err(ExoticQuantLoaderPathGateError::BadByteLedger {
            gate_id: card.gate_id.clone(),
            reason: "Mac candidates need directory-entry scan evidence, even when no file is seen",
        });
    }
    if bytes.local_path_open_attempts != 0
        || bytes.file_stat_calls != 0
        || bytes.file_hash_attempts != 0
        || bytes.command_execution_count != 0
        || bytes.model_bytes_loaded != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.provider_calls_made != 0
        || bytes.source_tree_bytes_read != 0
        || bytes.product_bytes_copied != 0
        || bytes.benchmark_runs != 0
    {
        return Err(ExoticQuantLoaderPathGateError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_runtime_boundary(
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    if card.owner_approval_granted
        || !card.loader_class_bound
        || card.loader_runtime_proven
        || card.loader_import_attempted
        || card.command_armed
        || card.command_executed
        || card.local_path_opened
        || card.file_hash_attempted
        || card.runtime_probe_allowed
        || !card.runtime_deferred
    {
        return Err(ExoticQuantLoaderPathGateError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_product_boundary(
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
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
        return Err(ExoticQuantLoaderPathGateError::ProductPromotion(
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
        return Err(ExoticQuantLoaderPathGateError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.source_import_allowed || card.benchmark_as_fit_proof {
        return Err(ExoticQuantLoaderPathGateError::SourceContamination(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &ExoticQuantLoaderPathGateCard,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    if !card.command_envelope_visible
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(ExoticQuantLoaderPathGateError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn expected_profile(model_id: &str) -> Option<ExpectedLoaderPathProfile> {
    EXPECTED_PROFILES
        .iter()
        .copied()
        .find(|profile| profile.model_id == model_id)
}

fn validate_text(
    value: &str,
    gate_id: &str,
    field: &'static str,
) -> Result<(), ExoticQuantLoaderPathGateError> {
    if value.is_empty() {
        return Err(ExoticQuantLoaderPathGateError::MissingField {
            gate_id: gate_id.to_string(),
            field,
        });
    }
    if value.trim() != value {
        return Err(
            ExoticQuantLoaderPathGateError::FieldHasSurroundingWhitespace {
                gate_id: gate_id.to_string(),
                field,
            },
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            ExoticQuantLoaderPathGateError::FieldContainsControlCharacter {
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
) -> Result<(), ExoticQuantLoaderPathGateError> {
    validate_text(value, gate_id, field)?;
    if !value.starts_with(expected) {
        return Err(ExoticQuantLoaderPathGateError::BadPrefix {
            gate_id: gate_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn ledger_preimage(
    upstream_owner_gate_address: &UasAddress,
    upstream_owner_gate_ref: &str,
    cards: &[ExoticQuantLoaderPathGateCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    local_artifact_availability_proven: bool,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "exotic_quant_loader_compatibility_model_path_gate_v1\n{}\n{}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n",
        upstream_owner_gate_address,
        upstream_owner_gate_ref,
        product_build_preimage(product_build),
        pro_status,
        promotion_tier,
        metadata_bytes,
        local_artifact_availability_proven,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
    );
    preimage.push_str(next_cursor);
    preimage.push('\n');
    for card in cards {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            card.gate_id,
            card.model_id,
            card.source_pin_card_id,
            card.selected_artifact_path,
            card.hardware_tier,
            card.runtime_lane,
            card.loader_class,
            card.path_state,
            card.action,
            product_build_preimage(&card.product_build),
            card.pro_status,
            format!("{:?}", card.promotion_tier),
            card.byte_ledger.metadata_bytes_read,
            card.byte_ledger.directory_entry_scan_count,
            card.byte_ledger.local_path_open_attempts,
            card.byte_ledger.file_stat_calls,
            card.byte_ledger.file_hash_attempts,
            card.byte_ledger.command_execution_count,
            card.byte_ledger.model_bytes_loaded,
            card.byte_ledger.runtime_bytes_loaded,
            card.byte_ledger.provider_calls_made,
            card.byte_ledger.source_tree_bytes_read,
            card.byte_ledger.product_bytes_copied,
            card.byte_ledger.benchmark_runs,
            card.proof_refs.upstream_owner_gate_ref,
            card.proof_refs.source_pin_card_ref,
            card.proof_refs.loader_class_ref,
            card.proof_refs.model_path_manifest_ref,
            card.proof_refs.directory_scan_ref,
            card.proof_refs.command_envelope_ref,
            card.proof_refs.rollback_ref,
            card.proof_refs.run_event_log_ref,
            card.proof_refs.answer_packet_ref,
            card.proof_refs.abstention_ref,
            card.proof_refs.sovereign_gate_ref,
            card.user_visible_summary,
            card.owner_approval_required,
            card.owner_approval_granted,
            card.loader_class_bound,
            card.loader_runtime_proven,
            card.loader_import_attempted,
            card.command_envelope_visible,
            card.command_armed,
            card.command_executed,
            card.model_path_manifest_required,
            card.path_directory_entry_seen,
            card.local_path_verified,
            card.local_path_opened,
            card.file_hash_attempted,
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
            card.hidden_route_authority,
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

pub fn expected_loader_path_model_ids() -> BTreeSet<&'static str> {
    EXPECTED_PROFILES
        .iter()
        .map(|profile| profile.model_id)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_413_200_000;
    const UPSTREAM_REF: &str =
        "artifact:falsifiers/exotic_quant_runtime_lane_owner_approval_gate/result.json#F-ExoticQuantRuntimeLaneOwnerApprovalGate";

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("exotic_quant_runtime_lane_owner_approval_gate".to_string()),
            b"owner-gate-test",
            CREATED_AT_MS,
        )
    }

    fn ledger(
        cards: Vec<ExoticQuantLoaderPathGateCard>,
    ) -> Result<ExoticQuantLoaderPathGateLedger, ExoticQuantLoaderPathGateError> {
        ExoticQuantLoaderPathGateLedger::new(
            upstream_address(),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            240_000,
            false,
            true,
            true,
            true,
            EXOTIC_QUANT_LOADER_COMPATIBILITY_MODEL_PATH_GATE_NEXT_CURSOR,
            CREATED_AT_MS,
        )
    }

    fn fixture_cards() -> Vec<ExoticQuantLoaderPathGateCard> {
        vec![
            card(
                "qwopus27b_tq3_4s_loader_path_gate",
                "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
                "qwopus27b_tq3_4s",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                ExoticQuantLoaderCompatibilityClass::GgufLlamaCppMetadataOnly,
                ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen,
                ExoticQuantLoaderPathAction::HoldForOwnerArtifactAvailability,
                true,
                1,
            ),
            card(
                "qwopus27b_hlwq_q5_loader_path_gate",
                "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
                "qwopus27b_hlwq_q5",
                "model_int4.pt",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::Transformers,
                ExoticQuantLoaderCompatibilityClass::TransformersLocalDirectoryMetadataOnly,
                ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen,
                ExoticQuantLoaderPathAction::HoldForOwnerArtifactAvailability,
                true,
                1,
            ),
            card(
                "qwopus_moe_apex_loader_path_gate",
                "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
                "qwopus_moe_35b_a3b_apex_mini",
                "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
                HardwareTier::Mac24To32Gb,
                ModelCatalogRuntimeLane::GgufLlamaCpp,
                ExoticQuantLoaderCompatibilityClass::GgufLlamaCppMetadataOnly,
                ExoticQuantModelPathState::OwnerPathManifestRequiredNoLocalFileSeen,
                ExoticQuantLoaderPathAction::HoldForOwnerArtifactAvailability,
                true,
                1,
            ),
            card(
                "gemma4_31b_nvfp4_loader_path_gate",
                "nvidia/Gemma-4-31B-IT-NVFP4",
                "gemma4_31b_nvfp4",
                "aggregate:nvfp4-safetensors",
                HardwareTier::CudaBlackwellOnly,
                ModelCatalogRuntimeLane::CudaBlackwell,
                ExoticQuantLoaderCompatibilityClass::CudaBlackwellServerOnlyDenied,
                ExoticQuantModelPathState::ServerOnlyMacPathDenied,
                ExoticQuantLoaderPathAction::DenyMacPathAndLoaderProbe,
                false,
                0,
            ),
            card(
                "gemma4_31b_autoround_loader_path_gate",
                "Intel/gemma-4-31B-it-int4-AutoRound",
                "gemma4_31b_int4_autoround",
                "aggregate:autoround-int4",
                HardwareTier::ServerGpuResearch,
                ModelCatalogRuntimeLane::Transformers,
                ExoticQuantLoaderCompatibilityClass::AutoRoundTransformersServerResearchDenied,
                ExoticQuantModelPathState::ServerOnlyMacPathDenied,
                ExoticQuantLoaderPathAction::DenyMacPathAndLoaderProbe,
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
        loader_class: ExoticQuantLoaderCompatibilityClass,
        path_state: ExoticQuantModelPathState,
        action: ExoticQuantLoaderPathAction,
        owner_approval_required: bool,
        directory_entry_scan_count: u64,
    ) -> ExoticQuantLoaderPathGateCard {
        ExoticQuantLoaderPathGateCard {
            gate_id: gate_id.to_string(),
            model_id: model_id.to_string(),
            source_pin_card_id: source_pin_card_id.to_string(),
            selected_artifact_path: selected_artifact_path.to_string(),
            hardware_tier,
            runtime_lane,
            loader_class,
            path_state,
            action,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            byte_ledger: ExoticQuantLoaderPathByteLedger::metadata_only(
                8192,
                directory_entry_scan_count,
            ),
            proof_refs: refs(gate_id, source_pin_card_id),
            user_visible_summary: format!(
                "{gate_id} binds {model_id} to a metadata-only loader compatibility class and a fail-closed model-path state; no local path is verified, no loader imports or commands run, and rollback, RunEventLog, AnswerPacket, abstention, and SovereignGate refs remain mandatory before any runtime path can open."
            ),
            owner_approval_required,
            owner_approval_granted: false,
            loader_class_bound: true,
            loader_runtime_proven: false,
            loader_import_attempted: false,
            command_envelope_visible: true,
            command_armed: false,
            command_executed: false,
            model_path_manifest_required: owner_approval_required,
            path_directory_entry_seen: false,
            local_path_verified: false,
            local_path_opened: false,
            file_hash_attempted: false,
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

    fn refs(gate_id: &str, source_pin_card_id: &str) -> ExoticQuantLoaderPathProofRefs {
        ExoticQuantLoaderPathProofRefs {
            upstream_owner_gate_ref: UPSTREAM_REF.to_string(),
            source_pin_card_ref: format!("source_pin_card:exotic_quant:{source_pin_card_id}"),
            loader_class_ref: format!("loader_compat:class_bound:exotic_quant:{gate_id}"),
            model_path_manifest_ref: format!(
                "model_path_manifest:required_or_denied:exotic_quant:{gate_id}"
            ),
            directory_scan_ref: format!("directory_entry_scan:no_match:downloads:{gate_id}"),
            command_envelope_ref: format!(
                "command_envelope:unarmed:exotic_quant_loader_path:{gate_id}"
            ),
            rollback_ref: format!("rollback:exotic_quant_loader_path:{gate_id}"),
            run_event_log_ref: format!("run_event_log:exotic_quant_loader_path:{gate_id}"),
            answer_packet_ref: format!("answer_packet:exotic_quant_loader_path:{gate_id}"),
            abstention_ref: format!("abstention:exotic_quant_loader_path:{gate_id}"),
            sovereign_gate_ref: format!("sovereign_gate:exotic_quant_loader_path:{gate_id}"),
        }
    }

    #[test]
    fn ledger_accepts_fail_closed_loader_path_cards() {
        let ledger = ledger(fixture_cards()).expect("ledger");
        let metrics = ledger.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.loader_class_bound_count, 5);
        assert_eq!(metrics.local_path_verified_count, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
    }

    #[test]
    fn local_path_verified_without_directory_evidence_is_rejected() {
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
