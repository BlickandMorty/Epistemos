//! Exotic quant owner path-manifest intake gate.
//!
//! This primitive defines the owner-provided manifest contract required before
//! path canonicalization, byte-envelope checking, command envelopes, or runtime
//! probes can begin. It does not read owner manifests, open paths, stat files,
//! hash artifacts, follow symlinks, arm commands, or promote product claims.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane, ProStatus, ProductBuild,
    UasAddress, UasKind,
};

pub const EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_CURSOR: &str =
    "exotic_quant_owner_path_manifest_intake_gate";
pub const EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR: &str =
    "exotic_quant_owner_path_canonicalization_preflight_gate";

const UPSTREAM_AVAILABILITY_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_local_artifact_availability_owner_gate/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const BYTE_BUDGET_PREFIX: &str = "byte_budget:exotic-quant:";
const MANIFEST_SCHEMA_PREFIX: &str = "owner_manifest_schema:exotic_quant:";
const PATH_POLICY_PREFIX: &str = "path_policy:owner_absolute_no_expansion:exotic_quant:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:unarmed:exotic_quant_owner_manifest:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_owner_manifest:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_owner_manifest:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_owner_manifest:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_owner_manifest:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_owner_manifest:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 180;
const MAX_LEDGER_METADATA_BYTES: u64 = 512 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:exotic-quant-owner-manifest-intake:state
// Plane: Verification
// Residency: manifest state only; no owner path or artifact bytes are trusted.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerPathManifestIntakeState {
    SchemaRequiredOwnerManifestMissing,
    ServerOnlyManifestIntakeDenied,
}

// UAS: uas:exotic-quant-owner-manifest-intake:action
// Plane: Controller
// Residency: no runtime action can be armed from manifest-intake metadata.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OwnerPathManifestIntakeAction {
    DefineOwnerManifestContract,
    DenyMacManifestIntake,
}

// UAS: uas:exotic-quant-owner-manifest-intake:expected-profile
// Plane: Verification
// Residency: fixed metadata profile for later owner-manifest proof.
#[derive(Clone, Copy)]
struct ExpectedManifestProfile {
    model_id: &'static str,
    source_pin_card_id: &'static str,
    selected_artifact_path: &'static str,
    selected_artifact_bytes: u64,
    selected_support_bytes: u64,
    runtime_workspace_budget_bytes: u64,
    kv_cache_floor_bytes: u64,
    app_headroom_bytes: u64,
    hardware_tier: HardwareTier,
    runtime_lane: ModelCatalogRuntimeLane,
    state: OwnerPathManifestIntakeState,
    action: OwnerPathManifestIntakeAction,
    owner_manifest_schema_required: bool,
}

const EXPECTED_PROFILES: &[ExpectedManifestProfile] = &[
    ExpectedManifestProfile {
        model_id: "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
        source_pin_card_id: "qwopus27b_tq3_4s",
        selected_artifact_path: "Qwopus3.5-27B-v3-TQ3_4S.gguf",
        selected_artifact_bytes: 13_954_954_592,
        selected_support_bytes: 931_146_304,
        runtime_workspace_budget_bytes: 1_073_741_824,
        kv_cache_floor_bytes: 2_147_483_648,
        app_headroom_bytes: 4_294_967_296,
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        state: OwnerPathManifestIntakeState::SchemaRequiredOwnerManifestMissing,
        action: OwnerPathManifestIntakeAction::DefineOwnerManifestContract,
        owner_manifest_schema_required: true,
    },
    ExpectedManifestProfile {
        model_id: "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
        source_pin_card_id: "qwopus27b_hlwq_q5",
        selected_artifact_path: "model_int4.pt",
        selected_artifact_bytes: 16_160_373_833,
        selected_support_bytes: 19_997_618,
        runtime_workspace_budget_bytes: 1_073_741_824,
        kv_cache_floor_bytes: 4_294_967_296,
        app_headroom_bytes: 4_294_967_296,
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        state: OwnerPathManifestIntakeState::SchemaRequiredOwnerManifestMissing,
        action: OwnerPathManifestIntakeAction::DefineOwnerManifestContract,
        owner_manifest_schema_required: true,
    },
    ExpectedManifestProfile {
        model_id: "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
        source_pin_card_id: "qwopus_moe_35b_a3b_apex_mini",
        selected_artifact_path: "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
        selected_artifact_bytes: 14_316_566_624,
        selected_support_bytes: 0,
        runtime_workspace_budget_bytes: 2_147_483_648,
        kv_cache_floor_bytes: 4_294_967_296,
        app_headroom_bytes: 4_294_967_296,
        hardware_tier: HardwareTier::Mac24To32Gb,
        runtime_lane: ModelCatalogRuntimeLane::GgufLlamaCpp,
        state: OwnerPathManifestIntakeState::SchemaRequiredOwnerManifestMissing,
        action: OwnerPathManifestIntakeAction::DefineOwnerManifestContract,
        owner_manifest_schema_required: true,
    },
    ExpectedManifestProfile {
        model_id: "nvidia/Gemma-4-31B-IT-NVFP4",
        source_pin_card_id: "gemma4_31b_nvfp4",
        selected_artifact_path: "model.safetensors.index.json",
        selected_artifact_bytes: 32_665_856_087,
        selected_support_bytes: 0,
        runtime_workspace_budget_bytes: 2_147_483_648,
        kv_cache_floor_bytes: 4_294_967_296,
        app_headroom_bytes: 0,
        hardware_tier: HardwareTier::CudaBlackwellOnly,
        runtime_lane: ModelCatalogRuntimeLane::CudaBlackwell,
        state: OwnerPathManifestIntakeState::ServerOnlyManifestIntakeDenied,
        action: OwnerPathManifestIntakeAction::DenyMacManifestIntake,
        owner_manifest_schema_required: false,
    },
    ExpectedManifestProfile {
        model_id: "Intel/gemma-4-31B-it-int4-AutoRound",
        source_pin_card_id: "gemma4_31b_int4_autoround",
        selected_artifact_path: "model.safetensors.index.json",
        selected_artifact_bytes: 19_220_750_927,
        selected_support_bytes: 0,
        runtime_workspace_budget_bytes: 2_147_483_648,
        kv_cache_floor_bytes: 4_294_967_296,
        app_headroom_bytes: 0,
        hardware_tier: HardwareTier::ServerGpuResearch,
        runtime_lane: ModelCatalogRuntimeLane::Transformers,
        state: OwnerPathManifestIntakeState::ServerOnlyManifestIntakeDenied,
        action: OwnerPathManifestIntakeAction::DenyMacManifestIntake,
        owner_manifest_schema_required: false,
    },
];

// UAS: uas:exotic-quant-owner-manifest-intake:byte-envelope
// Plane: Verification
// Residency: byte envelope is planned evidence, not resident model proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestByteEnvelope {
    pub selected_artifact_bytes: u64,
    pub selected_support_bytes: u64,
    pub runtime_workspace_budget_bytes: u64,
    pub kv_cache_floor_bytes: u64,
    pub app_headroom_bytes: u64,
    pub minimum_uma_bytes_required: u64,
}

impl OwnerPathManifestByteEnvelope {
    pub fn new(
        selected_artifact_bytes: u64,
        selected_support_bytes: u64,
        runtime_workspace_budget_bytes: u64,
        kv_cache_floor_bytes: u64,
        app_headroom_bytes: u64,
    ) -> Self {
        Self {
            selected_artifact_bytes,
            selected_support_bytes,
            runtime_workspace_budget_bytes,
            kv_cache_floor_bytes,
            app_headroom_bytes,
            minimum_uma_bytes_required: selected_artifact_bytes
                + selected_support_bytes
                + runtime_workspace_budget_bytes
                + kv_cache_floor_bytes
                + app_headroom_bytes,
        }
    }
}

// UAS: uas:exotic-quant-owner-manifest-intake:byte-ledger
// Plane: Verification
// Residency: all live owner-manifest/path/model/runtime counters stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestIntakeByteLedger {
    pub metadata_bytes_read: u64,
    pub owner_manifest_bytes_read: u64,
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

impl OwnerPathManifestIntakeByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            owner_manifest_bytes_read: 0,
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

// UAS: uas:exotic-quant-owner-manifest-intake:required-fields
// Plane: Verification
// Residency: manifest schema requirements before any local path is touched.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestRequiredFields {
    pub model_id: bool,
    pub selected_artifact_path: bool,
    pub owner_supplied_absolute_path: bool,
    pub expected_byte_envelope: bool,
    pub runtime_lane: bool,
    pub source_pin_card_id: bool,
    pub rollback: bool,
    pub run_event_log: bool,
    pub answer_packet: bool,
    pub abstention: bool,
    pub no_promotion: bool,
}

impl OwnerPathManifestRequiredFields {
    pub fn all_required() -> Self {
        Self {
            model_id: true,
            selected_artifact_path: true,
            owner_supplied_absolute_path: true,
            expected_byte_envelope: true,
            runtime_lane: true,
            source_pin_card_id: true,
            rollback: true,
            run_event_log: true,
            answer_packet: true,
            abstention: true,
            no_promotion: true,
        }
    }

    fn is_complete(&self) -> bool {
        self.model_id
            && self.selected_artifact_path
            && self.owner_supplied_absolute_path
            && self.expected_byte_envelope
            && self.runtime_lane
            && self.source_pin_card_id
            && self.rollback
            && self.run_event_log
            && self.answer_packet
            && self.abstention
            && self.no_promotion
    }
}

// UAS: uas:exotic-quant-owner-manifest-intake:refs
// Plane: Verification
// Residency: visible proof handles required before any owner path can promote.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestIntakeProofRefs {
    pub upstream_availability_gate_ref: String,
    pub source_pin_card_ref: String,
    pub byte_budget_ref: String,
    pub manifest_schema_ref: String,
    pub path_policy_ref: String,
    pub command_envelope_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
}

// UAS: uas:exotic-quant-owner-manifest-intake:card
// Plane: Controller + Verification
// Residency: per-row manifest intake card; never path or runtime permission.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestIntakeCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub state: OwnerPathManifestIntakeState,
    pub action: OwnerPathManifestIntakeAction,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub envelope: OwnerPathManifestByteEnvelope,
    pub required_fields: OwnerPathManifestRequiredFields,
    pub byte_ledger: OwnerPathManifestIntakeByteLedger,
    pub proof_refs: OwnerPathManifestIntakeProofRefs,
    pub user_visible_summary: String,
    pub owner_manifest_schema_required: bool,
    pub owner_manifest_present: bool,
    pub owner_signature_present: bool,
    pub owner_manifest_digest_bound: bool,
    pub path_canonicalization_allowed: bool,
    pub path_canonicalized: bool,
    pub file_open_allowed: bool,
    pub file_stat_allowed: bool,
    pub file_hash_allowed: bool,
    pub symlink_resolution_allowed: bool,
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

// UAS: uas:exotic-quant-owner-manifest-intake:ledger
// Plane: Controller + Verification
// Residency: metadata-only manifest contract bound to availability proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestIntakeLedger {
    pub ledger_address: UasAddress,
    pub upstream_availability_gate_address: UasAddress,
    pub upstream_availability_gate_ref: String,
    pub cards: Vec<OwnerPathManifestIntakeCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub manifest_contract_defined: bool,
    pub owner_manifest_bytes_loaded: bool,
    pub path_canonicalization_deferred: bool,
    pub runtime_deferred: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-owner-manifest-intake:metrics
// Plane: Verification
// Residency: derived manifest-intake counts and zero-byte counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct OwnerPathManifestIntakeMetrics {
    pub gate_card_count: u64,
    pub owner_manifest_schema_required_count: u64,
    pub owner_manifest_present_count: u64,
    pub owner_signature_present_count: u64,
    pub owner_manifest_digest_bound_count: u64,
    pub path_canonicalization_allowed_count: u64,
    pub path_canonicalized_count: u64,
    pub file_open_allowed_count: u64,
    pub file_hash_allowed_count: u64,
    pub server_only_manifest_denied_count: u64,
    pub command_envelope_unarmed_count: u64,
    pub selected_artifact_bytes_sum: u64,
    pub minimum_uma_bytes_required_max: u64,
    pub owner_manifest_bytes_read_total: u64,
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

impl OwnerPathManifestIntakeLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_availability_gate_address: UasAddress,
        upstream_availability_gate_ref: impl Into<String>,
        mut cards: Vec<OwnerPathManifestIntakeCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        manifest_contract_defined: bool,
        owner_manifest_bytes_loaded: bool,
        path_canonicalization_deferred: bool,
        runtime_deferred: bool,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, OwnerPathManifestIntakeError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_availability_gate_ref = upstream_availability_gate_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger(
            &upstream_availability_gate_address,
            &upstream_availability_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            manifest_contract_defined,
            owner_manifest_bytes_loaded,
            path_canonicalization_deferred,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_availability_gate_address,
            &upstream_availability_gate_ref,
            &cards,
            metadata_bytes,
            manifest_contract_defined,
            path_canonicalization_deferred,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_availability_gate_address,
            upstream_availability_gate_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            manifest_contract_defined,
            owner_manifest_bytes_loaded,
            path_canonicalization_deferred,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> OwnerPathManifestIntakeMetrics {
        let mut metrics = OwnerPathManifestIntakeMetrics {
            gate_card_count: self.cards.len() as u64,
            owner_manifest_schema_required_count: 0,
            owner_manifest_present_count: 0,
            owner_signature_present_count: 0,
            owner_manifest_digest_bound_count: 0,
            path_canonicalization_allowed_count: 0,
            path_canonicalized_count: 0,
            file_open_allowed_count: 0,
            file_hash_allowed_count: 0,
            server_only_manifest_denied_count: 0,
            command_envelope_unarmed_count: 0,
            selected_artifact_bytes_sum: 0,
            minimum_uma_bytes_required_max: 0,
            owner_manifest_bytes_read_total: 0,
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
            if card.owner_manifest_schema_required {
                metrics.owner_manifest_schema_required_count += 1;
            }
            if card.owner_manifest_present {
                metrics.owner_manifest_present_count += 1;
            }
            if card.owner_signature_present {
                metrics.owner_signature_present_count += 1;
            }
            if card.owner_manifest_digest_bound {
                metrics.owner_manifest_digest_bound_count += 1;
            }
            if card.path_canonicalization_allowed {
                metrics.path_canonicalization_allowed_count += 1;
            }
            if card.path_canonicalized {
                metrics.path_canonicalized_count += 1;
            }
            if card.file_open_allowed {
                metrics.file_open_allowed_count += 1;
            }
            if card.file_hash_allowed {
                metrics.file_hash_allowed_count += 1;
            }
            if card.state == OwnerPathManifestIntakeState::ServerOnlyManifestIntakeDenied {
                metrics.server_only_manifest_denied_count += 1;
            }
            if card.command_envelope_visible && !card.command_armed {
                metrics.command_envelope_unarmed_count += 1;
            }
            metrics.selected_artifact_bytes_sum += card.envelope.selected_artifact_bytes;
            metrics.minimum_uma_bytes_required_max = metrics
                .minimum_uma_bytes_required_max
                .max(card.envelope.minimum_uma_bytes_required);
            metrics.owner_manifest_bytes_read_total += card.byte_ledger.owner_manifest_bytes_read;
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

// UAS: uas:exotic-quant-owner-manifest-intake:error
// Plane: Verification
// Residency: every error fails closed before path canonicalization can begin.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OwnerPathManifestIntakeError {
    EmptyLedger,
    BadUpstreamAvailabilityGateRef,
    BadLedgerState,
    BadNextCursor,
    MetadataBudgetExceeded,
    DuplicateGateId(String),
    DuplicateModelId(String),
    DuplicateSourcePinCardId(String),
    MissingExpectedModel(&'static str),
    UnknownModelId(String),
    BadExpectedProfile(String),
    MissingField(String),
    BadText(String),
    BadPrefix(String),
    BadByteEnvelope(String),
    BadByteLedger(String),
    RuntimeAuthority(String),
    ProductPromotion(String),
    HiddenAuthority(String),
    SourceContamination(String),
    MissingProofSurface(String),
}

impl fmt::Display for OwnerPathManifestIntakeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "owner path manifest intake ledger is empty"),
            Self::BadUpstreamAvailabilityGateRef => write!(f, "bad upstream availability ref"),
            Self::BadLedgerState => write!(f, "manifest intake ledger state is invalid"),
            Self::BadNextCursor => write!(f, "manifest intake ledger has bad next cursor"),
            Self::MetadataBudgetExceeded => write!(f, "manifest intake metadata budget exceeded"),
            Self::DuplicateGateId(id) => write!(f, "duplicate gate id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id `{id}`"),
            Self::DuplicateSourcePinCardId(id) => write!(f, "duplicate source-pin id `{id}`"),
            Self::MissingExpectedModel(id) => write!(f, "missing expected model `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown model `{id}`"),
            Self::BadExpectedProfile(id) => write!(f, "bad expected manifest profile `{id}`"),
            Self::MissingField(id) => write!(f, "missing required manifest field on `{id}`"),
            Self::BadText(id) => write!(f, "bad text field on `{id}`"),
            Self::BadPrefix(id) => write!(f, "bad proof-ref prefix on `{id}`"),
            Self::BadByteEnvelope(id) => write!(f, "bad byte envelope on `{id}`"),
            Self::BadByteLedger(id) => write!(f, "bad byte ledger on `{id}`"),
            Self::RuntimeAuthority(id) => write!(f, "runtime authority attempted by `{id}`"),
            Self::ProductPromotion(id) => write!(f, "product promotion attempted by `{id}`"),
            Self::HiddenAuthority(id) => write!(f, "hidden authority attempted by `{id}`"),
            Self::SourceContamination(id) => write!(f, "source contamination attempted by `{id}`"),
            Self::MissingProofSurface(id) => write!(f, "missing proof surface on `{id}`"),
        }
    }
}

impl std::error::Error for OwnerPathManifestIntakeError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger(
    upstream_availability_gate_address: &UasAddress,
    upstream_availability_gate_ref: &str,
    cards: &[OwnerPathManifestIntakeCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    manifest_contract_defined: bool,
    owner_manifest_bytes_loaded: bool,
    path_canonicalization_deferred: bool,
    runtime_deferred: bool,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), OwnerPathManifestIntakeError> {
    if upstream_availability_gate_address
        .to_string()
        .trim()
        .is_empty()
        || !upstream_availability_gate_ref.starts_with(UPSTREAM_AVAILABILITY_PREFIX)
    {
        return Err(OwnerPathManifestIntakeError::BadUpstreamAvailabilityGateRef);
    }
    if cards.is_empty() {
        return Err(OwnerPathManifestIntakeError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(OwnerPathManifestIntakeError::MetadataBudgetExceeded);
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || !manifest_contract_defined
        || owner_manifest_bytes_loaded
        || !path_canonicalization_deferred
        || !runtime_deferred
        || !l1_l2_l3_separated
        || !product_promotion_blocked
    {
        return Err(OwnerPathManifestIntakeError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR {
        return Err(OwnerPathManifestIntakeError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(OwnerPathManifestIntakeError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(OwnerPathManifestIntakeError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(OwnerPathManifestIntakeError::DuplicateSourcePinCardId(
                card.source_pin_card_id.clone(),
            ));
        }
    }
    for expected in EXPECTED_PROFILES {
        if !model_ids.contains(expected.model_id) {
            return Err(OwnerPathManifestIntakeError::MissingExpectedModel(
                expected.model_id,
            ));
        }
    }
    Ok(())
}

fn validate_card(card: &OwnerPathManifestIntakeCard) -> Result<(), OwnerPathManifestIntakeError> {
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
        return Err(OwnerPathManifestIntakeError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    validate_expected_profile(card)?;
    validate_refs(card)?;
    validate_byte_envelope(card)?;
    validate_byte_ledger(card)?;
    validate_boundaries(card)?;
    validate_proof_surfaces(card)?;
    Ok(())
}

fn validate_expected_profile(
    card: &OwnerPathManifestIntakeCard,
) -> Result<(), OwnerPathManifestIntakeError> {
    let expected = expected_profile(&card.model_id)
        .ok_or_else(|| OwnerPathManifestIntakeError::UnknownModelId(card.model_id.clone()))?;
    if card.source_pin_card_id != expected.source_pin_card_id
        || card.selected_artifact_path != expected.selected_artifact_path
        || card.hardware_tier != expected.hardware_tier
        || card.runtime_lane != expected.runtime_lane
        || card.state != expected.state
        || card.action != expected.action
        || card.owner_manifest_schema_required != expected.owner_manifest_schema_required
    {
        return Err(OwnerPathManifestIntakeError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    if expected.owner_manifest_schema_required {
        if !card.required_fields.is_complete()
            || card.owner_manifest_present
            || card.owner_signature_present
            || card.owner_manifest_digest_bound
            || card.path_canonicalization_allowed
            || card.path_canonicalized
            || card.file_open_allowed
            || card.file_stat_allowed
            || card.file_hash_allowed
            || card.symlink_resolution_allowed
        {
            return Err(OwnerPathManifestIntakeError::BadExpectedProfile(
                card.model_id.clone(),
            ));
        }
    } else if card.required_fields.is_complete()
        || card.owner_manifest_present
        || card.owner_signature_present
        || card.owner_manifest_digest_bound
        || card.path_canonicalization_allowed
        || card.path_canonicalized
        || card.file_open_allowed
        || card.file_stat_allowed
        || card.file_hash_allowed
        || card.symlink_resolution_allowed
    {
        return Err(OwnerPathManifestIntakeError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    Ok(())
}

fn validate_refs(card: &OwnerPathManifestIntakeCard) -> Result<(), OwnerPathManifestIntakeError> {
    let refs = &card.proof_refs;
    for (value, prefix) in [
        (
            refs.upstream_availability_gate_ref.as_str(),
            UPSTREAM_AVAILABILITY_PREFIX,
        ),
        (refs.source_pin_card_ref.as_str(), SOURCE_PIN_CARD_PREFIX),
        (refs.byte_budget_ref.as_str(), BYTE_BUDGET_PREFIX),
        (refs.manifest_schema_ref.as_str(), MANIFEST_SCHEMA_PREFIX),
        (refs.path_policy_ref.as_str(), PATH_POLICY_PREFIX),
        (refs.command_envelope_ref.as_str(), COMMAND_ENVELOPE_PREFIX),
        (refs.rollback_ref.as_str(), ROLLBACK_PREFIX),
        (refs.run_event_log_ref.as_str(), RUN_EVENT_LOG_PREFIX),
        (refs.answer_packet_ref.as_str(), ANSWER_PACKET_PREFIX),
        (refs.abstention_ref.as_str(), ABSTENTION_PREFIX),
        (refs.sovereign_gate_ref.as_str(), SOVEREIGN_GATE_PREFIX),
    ] {
        if !value.starts_with(prefix) {
            return Err(OwnerPathManifestIntakeError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    if !refs.source_pin_card_ref.ends_with(&card.source_pin_card_id)
        || !refs.byte_budget_ref.ends_with(&card.source_pin_card_id)
        || !refs.manifest_schema_ref.ends_with(&card.source_pin_card_id)
        || !refs.path_policy_ref.ends_with(&card.source_pin_card_id)
    {
        return Err(OwnerPathManifestIntakeError::BadExpectedProfile(
            card.model_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_envelope(
    card: &OwnerPathManifestIntakeCard,
) -> Result<(), OwnerPathManifestIntakeError> {
    let expected = expected_profile(&card.model_id)
        .ok_or_else(|| OwnerPathManifestIntakeError::UnknownModelId(card.model_id.clone()))?;
    let envelope = &card.envelope;
    if envelope.selected_artifact_bytes != expected.selected_artifact_bytes
        || envelope.selected_support_bytes != expected.selected_support_bytes
        || envelope.runtime_workspace_budget_bytes != expected.runtime_workspace_budget_bytes
        || envelope.kv_cache_floor_bytes != expected.kv_cache_floor_bytes
        || envelope.app_headroom_bytes != expected.app_headroom_bytes
        || envelope.minimum_uma_bytes_required
            != envelope.selected_artifact_bytes
                + envelope.selected_support_bytes
                + envelope.runtime_workspace_budget_bytes
                + envelope.kv_cache_floor_bytes
                + envelope.app_headroom_bytes
    {
        return Err(OwnerPathManifestIntakeError::BadByteEnvelope(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &OwnerPathManifestIntakeCard,
) -> Result<(), OwnerPathManifestIntakeError> {
    let ledger = &card.byte_ledger;
    if ledger.metadata_bytes_read == 0
        || ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || ledger.owner_manifest_bytes_read > 0
        || ledger.path_canonicalization_attempts > 0
        || ledger.local_path_open_attempts > 0
        || ledger.file_stat_calls > 0
        || ledger.file_hash_attempts > 0
        || ledger.symlink_resolution_attempts > 0
        || ledger.command_execution_count > 0
        || ledger.model_bytes_loaded > 0
        || ledger.runtime_bytes_loaded > 0
        || ledger.provider_calls_made > 0
        || ledger.source_tree_bytes_read > 0
        || ledger.product_bytes_copied > 0
        || ledger.benchmark_runs > 0
    {
        return Err(OwnerPathManifestIntakeError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_boundaries(
    card: &OwnerPathManifestIntakeCard,
) -> Result<(), OwnerPathManifestIntakeError> {
    if card.command_armed || card.runtime_probe_allowed || !card.runtime_deferred {
        return Err(OwnerPathManifestIntakeError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.mas_allowed
        || card.product_route_enabled
        || card.app_default_claim
        || card.product_winner_claim
        || card.l2_l3_promotion_claim
        || card.live_dense_70b_claim
        || card.ssd_as_ram_claim
    {
        return Err(OwnerPathManifestIntakeError::ProductPromotion(
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
        return Err(OwnerPathManifestIntakeError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.source_import_allowed || card.benchmark_as_fit_proof {
        return Err(OwnerPathManifestIntakeError::SourceContamination(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &OwnerPathManifestIntakeCard,
) -> Result<(), OwnerPathManifestIntakeError> {
    if !card.command_envelope_visible
        || !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(OwnerPathManifestIntakeError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_text(value: &str, gate_id: &str) -> Result<(), OwnerPathManifestIntakeError> {
    if value.is_empty() {
        return Err(OwnerPathManifestIntakeError::MissingField(
            gate_id.to_string(),
        ));
    }
    if value.trim() != value || value.chars().any(char::is_control) {
        return Err(OwnerPathManifestIntakeError::BadText(gate_id.to_string()));
    }
    Ok(())
}

fn expected_profile(model_id: &str) -> Option<&'static ExpectedManifestProfile> {
    EXPECTED_PROFILES
        .iter()
        .find(|profile| profile.model_id == model_id)
}

fn ledger_preimage(
    upstream_availability_gate_address: &UasAddress,
    upstream_availability_gate_ref: &str,
    cards: &[OwnerPathManifestIntakeCard],
    metadata_bytes: u64,
    manifest_contract_defined: bool,
    path_canonicalization_deferred: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "{upstream_availability_gate_address}\n{upstream_availability_gate_ref}\n{metadata_bytes}\n{manifest_contract_defined}\n{path_canonicalization_deferred}\n{next_cursor}\n"
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

pub fn expected_owner_path_manifest_model_ids() -> Vec<&'static str> {
    EXPECTED_PROFILES
        .iter()
        .map(|profile| profile.model_id)
        .collect()
}

pub fn canonical_owner_path_manifest_intake_cards(
    upstream_availability_gate_ref: &str,
) -> Vec<OwnerPathManifestIntakeCard> {
    EXPECTED_PROFILES
        .iter()
        .map(|profile| canonical_card(profile, upstream_availability_gate_ref))
        .collect()
}

fn canonical_card(
    profile: &ExpectedManifestProfile,
    upstream_availability_gate_ref: &str,
) -> OwnerPathManifestIntakeCard {
    let mac_candidate =
        profile.state == OwnerPathManifestIntakeState::SchemaRequiredOwnerManifestMissing;
    OwnerPathManifestIntakeCard {
        gate_id: format!("{}_owner_path_manifest_intake", profile.source_pin_card_id),
        model_id: profile.model_id.to_string(),
        source_pin_card_id: profile.source_pin_card_id.to_string(),
        selected_artifact_path: profile.selected_artifact_path.to_string(),
        hardware_tier: profile.hardware_tier,
        runtime_lane: profile.runtime_lane,
        state: profile.state,
        action: profile.action,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        envelope: OwnerPathManifestByteEnvelope::new(
            profile.selected_artifact_bytes,
            profile.selected_support_bytes,
            profile.runtime_workspace_budget_bytes,
            profile.kv_cache_floor_bytes,
            profile.app_headroom_bytes,
        ),
        required_fields: if mac_candidate {
            OwnerPathManifestRequiredFields::all_required()
        } else {
            OwnerPathManifestRequiredFields {
                model_id: false,
                selected_artifact_path: false,
                owner_supplied_absolute_path: false,
                expected_byte_envelope: false,
                runtime_lane: false,
                source_pin_card_id: false,
                rollback: false,
                run_event_log: false,
                answer_packet: false,
                abstention: false,
                no_promotion: false,
            }
        },
        byte_ledger: OwnerPathManifestIntakeByteLedger::metadata_only(44_000),
        proof_refs: OwnerPathManifestIntakeProofRefs {
            upstream_availability_gate_ref: upstream_availability_gate_ref.to_string(),
            source_pin_card_ref: format!("{SOURCE_PIN_CARD_PREFIX}{}", profile.source_pin_card_id),
            byte_budget_ref: format!("{BYTE_BUDGET_PREFIX}{}", profile.source_pin_card_id),
            manifest_schema_ref: format!(
                "{MANIFEST_SCHEMA_PREFIX}{}",
                profile.source_pin_card_id
            ),
            path_policy_ref: format!("{PATH_POLICY_PREFIX}{}", profile.source_pin_card_id),
            command_envelope_ref: format!(
                "{COMMAND_ENVELOPE_PREFIX}{}",
                profile.source_pin_card_id
            ),
            rollback_ref: format!("{ROLLBACK_PREFIX}{}", profile.source_pin_card_id),
            run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{}", profile.source_pin_card_id),
            answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{}", profile.source_pin_card_id),
            abstention_ref: format!("{ABSTENTION_PREFIX}{}", profile.source_pin_card_id),
            sovereign_gate_ref: format!("{SOVEREIGN_GATE_PREFIX}{}", profile.source_pin_card_id),
        },
        user_visible_summary: format!(
            "Owner path manifest intake contract for {}. This is metadata-only: it requires a future owner-supplied absolute path, byte envelope, rollback, RunEventLog, AnswerPacket, abstention, and no-promotion fields before any path canonicalization, file read, hash, command, or runtime proof can begin.",
            profile.model_id
        ),
        owner_manifest_schema_required: profile.owner_manifest_schema_required,
        owner_manifest_present: false,
        owner_signature_present: false,
        owner_manifest_digest_bound: false,
        path_canonicalization_allowed: false,
        path_canonicalized: false,
        file_open_allowed: false,
        file_stat_allowed: false,
        file_hash_allowed: false,
        symlink_resolution_allowed: false,
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

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str =
        "artifact:falsifiers/exotic_quant_local_artifact_availability_owner_gate/result.json#F-ExoticQuantLocalArtifactAvailabilityOwnerGate";
    const CREATED_AT_MS: u64 = 1_779_421_800_000;

    fn ledger(
        cards: Vec<OwnerPathManifestIntakeCard>,
    ) -> Result<OwnerPathManifestIntakeLedger, OwnerPathManifestIntakeError> {
        OwnerPathManifestIntakeLedger::new(
            UasAddress::new(UasKind::Other("test-upstream".to_string()), b"upstream", 1),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            260_000,
            true,
            false,
            true,
            true,
            true,
            true,
            EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR,
            CREATED_AT_MS,
        )
    }

    fn fixture_cards() -> Vec<OwnerPathManifestIntakeCard> {
        canonical_owner_path_manifest_intake_cards(UPSTREAM_REF)
    }

    #[test]
    fn accepts_manifest_contract_without_manifest_bytes() {
        let ledger = ledger(fixture_cards()).expect("ledger");
        let metrics = ledger.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.owner_manifest_schema_required_count, 3);
        assert_eq!(metrics.owner_manifest_present_count, 0);
        assert_eq!(metrics.owner_manifest_bytes_read_total, 0);
        assert_eq!(metrics.path_canonicalization_attempts_total, 0);
        assert_eq!(metrics.server_only_manifest_denied_count, 2);
    }

    #[test]
    fn rejects_manifest_or_path_shortcuts() {
        let mut cards = fixture_cards();
        cards[0].owner_manifest_present = true;
        assert!(ledger(cards).is_err());

        let mut cards = fixture_cards();
        cards[0].path_canonicalization_allowed = true;
        assert!(ledger(cards).is_err());

        let mut cards = fixture_cards();
        cards[0].file_hash_allowed = true;
        assert!(ledger(cards).is_err());
    }

    #[test]
    fn deterministic_address_after_sorting() {
        let forward = ledger(fixture_cards()).expect("forward");
        let mut reversed = fixture_cards();
        reversed.reverse();
        let reverse = ledger(reversed).expect("reverse");
        assert_eq!(forward.ledger_address, reverse.ledger_address);
    }
}
