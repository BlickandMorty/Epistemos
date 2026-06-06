//! Compressed-route AnswerPacket dry-run.
//!
//! This primitive packetizes QAT route-card memory preflights into visible
//! AnswerPacket dry-run surfaces. It proves route caveats, planned/opened/
//! resident byte placeholders, fallback, rollback, cancellation, and no-mutation
//! visibility without opening model/runtime bytes or proving live inference.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, QatRouteRuntimeLane, UasAddress, UasKind};

pub const COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_CURSOR: &str =
    "compressed_route_answer_packet_dry_run";
pub const COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_NEXT_CURSOR: &str =
    "small_compressed_model_live_harness";

const PREFLIGHT_CARD_PREFIX: &str = "qat_route_preflight:";
const PREFLIGHT_SET_ARTIFACT_PREFIX: &str = "artifact:qat_model_route_card_memory_preflight:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const FALLBACK_PREFIX: &str = "fallback:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const CANCELLATION_PREFIX: &str = "cancel:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:";
const VISIBLE_SUMMARY_PREFIX: &str = "visible_summary:";
const REJECTED_CANDIDATE_PREFIX: &str = "rejected_candidate:";
const ABSTENTION_PREFIX: &str = "abstain:";
const VAULT_PREFIX: &str = "vault:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_PACKET_METADATA_BYTES: u64 = 96 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 128;

// UAS: uas:compressed-route-answer-packet-dry-run:status
// Plane: Controller + Verification
// Residency: dry-run packet state only; no runtime route authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedRoutePacketStatus {
    PacketizedDryRun,
    CarriedAbstention,
    CarriedVaultOnly,
    Blocked,
}

// UAS: uas:compressed-route-answer-packet-dry-run:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompressedRoutePromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:compressed-route-answer-packet-dry-run:byte-ledger
// Plane: Verification
// Residency: planned/opened/resident placeholders; loaded bytes remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedRouteByteLedger {
    pub declared_file_bytes: u64,
    pub planned_model_bytes: u64,
    pub planned_kv_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub planned_route_bytes: u64,
    pub fallback_reserved_bytes: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub observed_peak_rss_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub metadata_bytes_read: u64,
}

impl CompressedRouteByteLedger {
    pub fn metadata_only(
        declared_file_bytes: u64,
        planned_model_bytes: u64,
        planned_kv_bytes: u64,
        planned_scratch_bytes: u64,
        fallback_reserved_bytes: u64,
        metadata_bytes_read: u64,
    ) -> Self {
        let planned_route_bytes = planned_model_bytes
            .saturating_add(planned_kv_bytes)
            .saturating_add(planned_scratch_bytes);
        Self {
            declared_file_bytes,
            planned_model_bytes,
            planned_kv_bytes,
            planned_scratch_bytes,
            planned_route_bytes,
            fallback_reserved_bytes,
            opened_model_bytes: 0,
            opened_runtime_bytes: 0,
            resident_model_bytes: 0,
            resident_runtime_bytes: 0,
            observed_peak_rss_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            metadata_bytes_read,
        }
    }
}

// UAS: uas:compressed-route-answer-packet-dry-run:proof-refs
// Plane: Verification
// Residency: visible proof handles required before live runtime proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedRouteAnswerPacketRefs {
    pub upstream_preflight_card_ref: String,
    pub falsifier_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub fallback_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub cancellation_ref: String,
    pub compatibility_fence_ref: String,
    pub route_caveat_ref: String,
    pub visible_summary_ref: String,
    pub abstention_reason_ref: Option<String>,
    pub vault_preservation_ref: Option<String>,
    pub rejected_candidate_refs: Vec<String>,
}

// UAS: uas:compressed-route-answer-packet-dry-run:packet
// Plane: State + Controller + Verification
// Residency: visible dry-run packet; no model/runtime execution.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedRouteAnswerPacketDryRun {
    pub packet_id: String,
    pub model_id: String,
    pub runtime_lane: QatRouteRuntimeLane,
    pub packet_status: CompressedRoutePacketStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedRoutePromotionTier,
    pub bytes: CompressedRouteByteLedger,
    pub refs: CompressedRouteAnswerPacketRefs,
    pub user_visible_summary: String,
    pub selected_model_visible: bool,
    pub rejected_candidates_visible: bool,
    pub route_caveat_visible: bool,
    pub byte_ledger_visible: bool,
    pub fallback_visible: bool,
    pub rollback_visible: bool,
    pub cancellation_visible: bool,
    pub no_mutation_envelope_visible: bool,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
    pub first_token_claimed: bool,
    pub quality_claimed: bool,
    pub runtime_parity_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub route_policy_mutated: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:compressed-route-answer-packet-dry-run:set
// Plane: State + Controller + Verification
// Residency: metadata-only packet set for future runtime harness work.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedRouteAnswerPacketDryRunSet {
    pub set_address: UasAddress,
    pub upstream_preflight_set_address: UasAddress,
    pub upstream_preflight_witness_ref: String,
    pub packets: Vec<CompressedRouteAnswerPacketDryRun>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:compressed-route-answer-packet-dry-run:metrics
// Plane: Verification
// Residency: derived counts for metadata-only packet artifacts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CompressedRouteAnswerPacketMetrics {
    pub packet_count: u64,
    pub runtime_lane_count: u64,
    pub status_count: u64,
    pub packetized_dry_run_count: u64,
    pub abstention_packet_count: u64,
    pub vault_packet_count: u64,
    pub planned_route_bytes_total: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub metadata_bytes_read: u64,
}

impl CompressedRouteAnswerPacketDryRunSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_preflight(
        upstream_preflight_set_address: UasAddress,
        upstream_preflight_witness_ref: impl Into<String>,
        mut packets: Vec<CompressedRouteAnswerPacketDryRun>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, CompressedRouteAnswerPacketError> {
        packets.sort_by(|a, b| a.packet_id.cmp(&b.packet_id));
        let witness_ref = upstream_preflight_witness_ref.into();
        validate_set_inputs(
            &upstream_preflight_set_address,
            &witness_ref,
            &packets,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = packet_set_preimage(
            &upstream_preflight_set_address,
            &witness_ref,
            &packets,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_preflight_set_address,
            upstream_preflight_witness_ref: witness_ref,
            packets,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> CompressedRouteAnswerPacketMetrics {
        let mut runtime_lanes = BTreeSet::new();
        let mut statuses = BTreeSet::new();
        let mut packetized_dry_run_count = 0;
        let mut abstention_packet_count = 0;
        let mut vault_packet_count = 0;
        let mut planned_route_bytes_total = 0;
        let mut opened_model_bytes = 0;
        let mut opened_runtime_bytes = 0;
        let mut resident_model_bytes = 0;
        let mut resident_runtime_bytes = 0;
        let mut model_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut provider_calls_made = 0;
        let mut metadata_bytes_read = self.metadata_bytes;

        for packet in &self.packets {
            runtime_lanes.insert(packet.runtime_lane);
            statuses.insert(packet.packet_status);
            match packet.packet_status {
                CompressedRoutePacketStatus::PacketizedDryRun => packetized_dry_run_count += 1,
                CompressedRoutePacketStatus::CarriedAbstention => abstention_packet_count += 1,
                CompressedRoutePacketStatus::CarriedVaultOnly => vault_packet_count += 1,
                CompressedRoutePacketStatus::Blocked => {}
            }
            planned_route_bytes_total += packet.bytes.planned_route_bytes;
            opened_model_bytes += packet.bytes.opened_model_bytes;
            opened_runtime_bytes += packet.bytes.opened_runtime_bytes;
            resident_model_bytes += packet.bytes.resident_model_bytes;
            resident_runtime_bytes += packet.bytes.resident_runtime_bytes;
            model_bytes_loaded += packet.bytes.model_bytes_loaded;
            runtime_bytes_loaded += packet.bytes.runtime_bytes_loaded;
            provider_calls_made += packet.bytes.provider_calls_made;
            metadata_bytes_read += packet.bytes.metadata_bytes_read;
        }

        CompressedRouteAnswerPacketMetrics {
            packet_count: self.packets.len() as u64,
            runtime_lane_count: runtime_lanes.len() as u64,
            status_count: statuses.len() as u64,
            packetized_dry_run_count,
            abstention_packet_count,
            vault_packet_count,
            planned_route_bytes_total,
            opened_model_bytes,
            opened_runtime_bytes,
            resident_model_bytes,
            resident_runtime_bytes,
            model_bytes_loaded,
            runtime_bytes_loaded,
            provider_calls_made,
            metadata_bytes_read,
        }
    }
}

// UAS: uas:compressed-route-answer-packet-dry-run:error
// Plane: Verification
// Residency: fail-closed validation for visible dry-run packets.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CompressedRouteAnswerPacketError {
    MissingUpstreamPreflightSet,
    MissingUpstreamWitness,
    EmptyPackets,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicatePacketId(String),
    DuplicateModelRuntime {
        model_id: String,
        lane: QatRouteRuntimeLane,
    },
    EmptyField {
        packet_id: String,
        field: &'static str,
    },
    BadPrefix {
        packet_id: String,
        field: &'static str,
        expected: &'static str,
    },
    MissingRejectedCandidate(String),
    MissingAbstentionReason(String),
    MissingVaultRef(String),
    MissingVisibility(String),
    BadProductBuild(String),
    BadProStatus(String),
    BadPromotionTier(String),
    RuntimeNotDeferred(String),
    ProductPromotionAllowed(String),
    HiddenAuthority(String),
    ByteLoadAttempt(String),
    InvalidByteLedger {
        packet_id: String,
        reason: &'static str,
    },
    StatusContradiction {
        packet_id: String,
        reason: &'static str,
    },
    SetPromotionAllowed,
}

impl fmt::Display for CompressedRouteAnswerPacketError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamPreflightSet => write!(f, "missing upstream route-preflight set"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream route-preflight witness"),
            Self::EmptyPackets => write!(f, "compressed route dry-run requires packets"),
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicatePacketId(id) => write!(f, "duplicate dry-run packet id `{id}`"),
            Self::DuplicateModelRuntime { model_id, lane } => {
                write!(f, "duplicate packet for `{model_id}` on lane `{lane:?}`")
            }
            Self::EmptyField { packet_id, field } => {
                write!(f, "packet `{packet_id}` has empty `{field}`")
            }
            Self::BadPrefix {
                packet_id,
                field,
                expected,
            } => write!(
                f,
                "packet `{packet_id}` field `{field}` must start with `{expected}`"
            ),
            Self::MissingRejectedCandidate(id) => {
                write!(f, "packet `{id}` missing rejected-candidate visibility")
            }
            Self::MissingAbstentionReason(id) => {
                write!(f, "packet `{id}` missing abstention reason")
            }
            Self::MissingVaultRef(id) => write!(f, "packet `{id}` missing vault ref"),
            Self::MissingVisibility(id) => write!(f, "packet `{id}` missing visible proof surface"),
            Self::BadProductBuild(id) => write!(f, "packet `{id}` cannot promote to MAS"),
            Self::BadProStatus(id) => write!(f, "packet `{id}` has forbidden Pro status"),
            Self::BadPromotionTier(id) => write!(f, "packet `{id}` cannot promote beyond T1"),
            Self::RuntimeNotDeferred(id) => write!(f, "packet `{id}` tried to make runtime live"),
            Self::ProductPromotionAllowed(id) => {
                write!(f, "packet `{id}` tried to promote product truth")
            }
            Self::HiddenAuthority(id) => write!(f, "packet `{id}` enabled hidden authority"),
            Self::ByteLoadAttempt(id) => write!(f, "packet `{id}` attempted byte/provider use"),
            Self::InvalidByteLedger { packet_id, reason } => {
                write!(f, "packet `{packet_id}` invalid byte ledger: {reason}")
            }
            Self::StatusContradiction { packet_id, reason } => {
                write!(f, "packet `{packet_id}` status contradiction: {reason}")
            }
            Self::SetPromotionAllowed => {
                write!(
                    f,
                    "compressed route dry-run set tried to promote product truth"
                )
            }
        }
    }
}

impl std::error::Error for CompressedRouteAnswerPacketError {}

fn validate_set_inputs(
    upstream_preflight_set_address: &UasAddress,
    upstream_preflight_witness_ref: &str,
    packets: &[CompressedRouteAnswerPacketDryRun],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), CompressedRouteAnswerPacketError> {
    if upstream_preflight_set_address.to_string().trim().is_empty() {
        return Err(CompressedRouteAnswerPacketError::MissingUpstreamPreflightSet);
    }
    if upstream_preflight_witness_ref.trim().is_empty() {
        return Err(CompressedRouteAnswerPacketError::MissingUpstreamWitness);
    }
    if !upstream_preflight_witness_ref.starts_with(PREFLIGHT_SET_ARTIFACT_PREFIX) {
        return Err(CompressedRouteAnswerPacketError::BadPrefix {
            packet_id: "set".to_string(),
            field: "upstream_preflight_witness_ref",
            expected: PREFLIGHT_SET_ARTIFACT_PREFIX,
        });
    }
    if packets.is_empty() {
        return Err(CompressedRouteAnswerPacketError::EmptyPackets);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(CompressedRouteAnswerPacketError::MetadataBudgetExceeded {
            bytes: metadata_bytes,
            max_bytes: MAX_SET_METADATA_BYTES,
        });
    }
    if product_build != &ProductBuild::Pro
        || matches!(pro_status, ProStatus::Live | ProStatus::Omega)
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(CompressedRouteAnswerPacketError::SetPromotionAllowed);
    }

    let mut packet_ids = HashSet::new();
    let mut model_lanes = HashSet::new();
    for packet in packets {
        validate_packet(packet)?;
        if !packet_ids.insert(packet.packet_id.clone()) {
            return Err(CompressedRouteAnswerPacketError::DuplicatePacketId(
                packet.packet_id.clone(),
            ));
        }
        let model_lane = (packet.model_id.clone(), packet.runtime_lane);
        if !model_lanes.insert(model_lane.clone()) {
            return Err(CompressedRouteAnswerPacketError::DuplicateModelRuntime {
                model_id: model_lane.0,
                lane: model_lane.1,
            });
        }
    }
    Ok(())
}

fn validate_packet(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    require_nonempty(&packet.packet_id, &packet.packet_id, "packet_id")?;
    require_nonempty(&packet.model_id, &packet.packet_id, "model_id")?;
    require_nonempty(
        &packet.user_visible_summary,
        &packet.packet_id,
        "user_visible_summary",
    )?;
    if packet.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(CompressedRouteAnswerPacketError::MissingVisibility(
            packet.packet_id.clone(),
        ));
    }
    validate_refs(packet)?;
    validate_product(packet)?;
    validate_byte_ledger(packet)?;
    validate_status(packet)?;
    validate_visibility(packet)?;
    validate_no_promotion(packet)?;
    Ok(())
}

fn validate_refs(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    let refs = &packet.refs;
    require_prefix(
        &refs.upstream_preflight_card_ref,
        &packet.packet_id,
        "upstream_preflight_card_ref",
        PREFLIGHT_CARD_PREFIX,
    )?;
    require_prefix(
        &refs.falsifier_ref,
        &packet.packet_id,
        "falsifier_ref",
        FALSIFIER_PREFIX,
    )?;
    require_prefix(
        &refs.answer_packet_ref,
        &packet.packet_id,
        "answer_packet_ref",
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        &refs.run_event_log_ref,
        &packet.packet_id,
        "run_event_log_ref",
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        &refs.fallback_ref,
        &packet.packet_id,
        "fallback_ref",
        FALLBACK_PREFIX,
    )?;
    require_prefix(
        &refs.rollback_ref,
        &packet.packet_id,
        "rollback_ref",
        ROLLBACK_PREFIX,
    )?;
    require_prefix(
        &refs.admission_ref,
        &packet.packet_id,
        "admission_ref",
        ADMISSION_PREFIX,
    )?;
    require_prefix(
        &refs.cancellation_ref,
        &packet.packet_id,
        "cancellation_ref",
        CANCELLATION_PREFIX,
    )?;
    require_prefix(
        &refs.compatibility_fence_ref,
        &packet.packet_id,
        "compatibility_fence_ref",
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    require_prefix(
        &refs.route_caveat_ref,
        &packet.packet_id,
        "route_caveat_ref",
        ROUTE_CAVEAT_PREFIX,
    )?;
    require_prefix(
        &refs.visible_summary_ref,
        &packet.packet_id,
        "visible_summary_ref",
        VISIBLE_SUMMARY_PREFIX,
    )?;
    if refs.rejected_candidate_refs.is_empty() {
        return Err(CompressedRouteAnswerPacketError::MissingRejectedCandidate(
            packet.packet_id.clone(),
        ));
    }
    for rejected in &refs.rejected_candidate_refs {
        require_prefix(
            rejected,
            &packet.packet_id,
            "rejected_candidate_refs",
            REJECTED_CANDIDATE_PREFIX,
        )?;
    }
    Ok(())
}

fn validate_product(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    if packet.product_build != ProductBuild::Pro {
        return Err(CompressedRouteAnswerPacketError::BadProductBuild(
            packet.packet_id.clone(),
        ));
    }
    if matches!(packet.pro_status, ProStatus::Live | ProStatus::Omega) {
        return Err(CompressedRouteAnswerPacketError::BadProStatus(
            packet.packet_id.clone(),
        ));
    }
    if matches!(
        packet.promotion_tier,
        CompressedRoutePromotionTier::T2L2Route
            | CompressedRoutePromotionTier::T3L3Wrv
            | CompressedRoutePromotionTier::T4BuildGreen
            | CompressedRoutePromotionTier::T5FullSegment
    ) {
        return Err(CompressedRouteAnswerPacketError::BadPromotionTier(
            packet.packet_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_ledger(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    let bytes = &packet.bytes;
    if bytes.declared_file_bytes == 0
        || bytes.planned_model_bytes == 0
        || bytes.planned_kv_bytes == 0
        || bytes.planned_scratch_bytes == 0
        || bytes.fallback_reserved_bytes == 0
    {
        return Err(invalid_bytes(
            packet,
            "declared/planned/fallback bytes must be nonzero",
        ));
    }
    if bytes.planned_model_bytes <= bytes.declared_file_bytes {
        return Err(invalid_bytes(
            packet,
            "planned model bytes must exceed declared file bytes",
        ));
    }
    let expected_route_bytes = bytes
        .planned_model_bytes
        .checked_add(bytes.planned_kv_bytes)
        .and_then(|value| value.checked_add(bytes.planned_scratch_bytes))
        .ok_or_else(|| invalid_bytes(packet, "planned route bytes overflowed"))?;
    if bytes.planned_route_bytes != expected_route_bytes {
        return Err(invalid_bytes(
            packet,
            "planned_route_bytes must equal model + kv + scratch",
        ));
    }
    if bytes.opened_model_bytes != 0
        || bytes.opened_runtime_bytes != 0
        || bytes.resident_model_bytes != 0
        || bytes.resident_runtime_bytes != 0
        || bytes.observed_peak_rss_bytes != 0
        || bytes.model_bytes_loaded != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.provider_calls_made != 0
    {
        return Err(CompressedRouteAnswerPacketError::ByteLoadAttempt(
            packet.packet_id.clone(),
        ));
    }
    if bytes.metadata_bytes_read > MAX_PACKET_METADATA_BYTES {
        return Err(CompressedRouteAnswerPacketError::MetadataBudgetExceeded {
            bytes: bytes.metadata_bytes_read,
            max_bytes: MAX_PACKET_METADATA_BYTES,
        });
    }
    Ok(())
}

fn validate_status(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    match packet.packet_status {
        CompressedRoutePacketStatus::PacketizedDryRun => {
            if packet.refs.abstention_reason_ref.is_some()
                || packet.refs.vault_preservation_ref.is_some()
            {
                return Err(status_error(
                    packet,
                    "packetized dry-run cannot carry abstention or vault refs",
                ));
            }
            if matches!(
                packet.pro_status,
                ProStatus::VaultPreserved | ProStatus::Blocked
            ) {
                return Err(status_error(
                    packet,
                    "packetized dry-run cannot be vault or blocked",
                ));
            }
        }
        CompressedRoutePacketStatus::CarriedAbstention => {
            require_optional_prefix(
                packet,
                packet.refs.abstention_reason_ref.as_deref(),
                "abstention_reason_ref",
                ABSTENTION_PREFIX,
                CompressedRouteAnswerPacketError::MissingAbstentionReason(packet.packet_id.clone()),
            )?;
        }
        CompressedRoutePacketStatus::CarriedVaultOnly => {
            require_optional_prefix(
                packet,
                packet.refs.vault_preservation_ref.as_deref(),
                "vault_preservation_ref",
                VAULT_PREFIX,
                CompressedRouteAnswerPacketError::MissingVaultRef(packet.packet_id.clone()),
            )?;
            if packet.pro_status != ProStatus::VaultPreserved {
                return Err(status_error(packet, "vault packet must be VaultPreserved"));
            }
        }
        CompressedRoutePacketStatus::Blocked => {
            if packet.refs.abstention_reason_ref.is_none() {
                return Err(CompressedRouteAnswerPacketError::MissingAbstentionReason(
                    packet.packet_id.clone(),
                ));
            }
        }
    }
    if packet.model_id.contains("-12B-")
        && packet.packet_status == CompressedRoutePacketStatus::PacketizedDryRun
    {
        return Err(status_error(
            packet,
            "12B cannot be packetized for dry-run yet",
        ));
    }
    if packet.model_id.contains("-31B-")
        && packet.packet_status != CompressedRoutePacketStatus::CarriedVaultOnly
    {
        return Err(status_error(packet, "31B must remain vault-only"));
    }
    Ok(())
}

fn validate_visibility(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    if !packet.selected_model_visible
        || !packet.rejected_candidates_visible
        || !packet.route_caveat_visible
        || !packet.byte_ledger_visible
        || !packet.fallback_visible
        || !packet.rollback_visible
        || !packet.cancellation_visible
        || !packet.no_mutation_envelope_visible
    {
        return Err(CompressedRouteAnswerPacketError::MissingVisibility(
            packet.packet_id.clone(),
        ));
    }
    Ok(())
}

fn validate_no_promotion(
    packet: &CompressedRouteAnswerPacketDryRun,
) -> Result<(), CompressedRouteAnswerPacketError> {
    if !packet.l1_l2_l3_separated || !packet.runtime_deferred {
        return Err(CompressedRouteAnswerPacketError::RuntimeNotDeferred(
            packet.packet_id.clone(),
        ));
    }
    if !packet.product_promotion_blocked
        || packet.first_token_claimed
        || packet.quality_claimed
        || packet.runtime_parity_claimed
        || packet.mas_readiness_claimed
    {
        return Err(CompressedRouteAnswerPacketError::ProductPromotionAllowed(
            packet.packet_id.clone(),
        ));
    }
    if packet.route_policy_mutated
        || packet.answer_packet_suppressed
        || packet.hidden_chain_exposed
        || packet.hidden_cloud_fallback_allowed
        || packet.hidden_route_authority_allowed
        || packet.live_dense_70b_claimed
        || packet.ssd_as_ram_claimed
    {
        return Err(CompressedRouteAnswerPacketError::HiddenAuthority(
            packet.packet_id.clone(),
        ));
    }
    Ok(())
}

fn invalid_bytes(
    packet: &CompressedRouteAnswerPacketDryRun,
    reason: &'static str,
) -> CompressedRouteAnswerPacketError {
    CompressedRouteAnswerPacketError::InvalidByteLedger {
        packet_id: packet.packet_id.clone(),
        reason,
    }
}

fn status_error(
    packet: &CompressedRouteAnswerPacketDryRun,
    reason: &'static str,
) -> CompressedRouteAnswerPacketError {
    CompressedRouteAnswerPacketError::StatusContradiction {
        packet_id: packet.packet_id.clone(),
        reason,
    }
}

fn require_nonempty(
    value: &str,
    packet_id: &str,
    field: &'static str,
) -> Result<(), CompressedRouteAnswerPacketError> {
    if value.trim().is_empty() {
        return Err(CompressedRouteAnswerPacketError::EmptyField {
            packet_id: packet_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    packet_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), CompressedRouteAnswerPacketError> {
    if !value.starts_with(expected) {
        return Err(CompressedRouteAnswerPacketError::BadPrefix {
            packet_id: packet_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

fn require_optional_prefix(
    packet: &CompressedRouteAnswerPacketDryRun,
    value: Option<&str>,
    field: &'static str,
    expected: &'static str,
    missing_error: CompressedRouteAnswerPacketError,
) -> Result<(), CompressedRouteAnswerPacketError> {
    let value = value.unwrap_or_default();
    if value.trim().is_empty() {
        return Err(missing_error);
    }
    require_prefix(value, &packet.packet_id, field, expected)
}

#[allow(clippy::too_many_arguments)]
fn packet_set_preimage(
    upstream_preflight_set_address: &UasAddress,
    upstream_preflight_witness_ref: &str,
    packets: &[CompressedRouteAnswerPacketDryRun],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "compressed_route_answer_packet_dry_run_v1\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_preflight_set_address,
        upstream_preflight_witness_ref,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for packet in packets {
        preimage.push_str(&format!(
            "{}\n{}\n{:?}\n{:?}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            packet.packet_id,
            packet.model_id,
            packet.runtime_lane,
            packet.packet_status,
            product_build_preimage(&packet.product_build),
            packet.pro_status,
            packet.promotion_tier,
            packet.bytes.declared_file_bytes,
            packet.bytes.planned_model_bytes,
            packet.bytes.planned_kv_bytes,
            packet.bytes.planned_scratch_bytes,
            packet.bytes.planned_route_bytes,
            packet.bytes.fallback_reserved_bytes,
            packet.bytes.opened_model_bytes,
            packet.bytes.opened_runtime_bytes,
            packet.bytes.resident_model_bytes,
            packet.bytes.resident_runtime_bytes,
            packet.bytes.observed_peak_rss_bytes,
            packet.bytes.model_bytes_loaded,
            packet.bytes.runtime_bytes_loaded,
            packet.bytes.provider_calls_made,
            packet.bytes.metadata_bytes_read,
            packet.refs.upstream_preflight_card_ref,
            packet.refs.falsifier_ref,
            packet.refs.answer_packet_ref,
            packet.refs.run_event_log_ref,
            packet.refs.fallback_ref,
            packet.refs.rollback_ref,
            packet.refs.admission_ref,
            packet.refs.cancellation_ref,
            packet.refs.compatibility_fence_ref,
            packet.refs.route_caveat_ref,
            packet.refs.visible_summary_ref,
            packet.refs.abstention_reason_ref.as_deref().unwrap_or(""),
            packet.refs.vault_preservation_ref.as_deref().unwrap_or(""),
            packet.refs.rejected_candidate_refs.join(","),
            packet.selected_model_visible,
            packet.rejected_candidates_visible,
            packet.route_caveat_visible,
            packet.byte_ledger_visible,
            packet.fallback_visible,
            packet.rollback_visible,
            packet.cancellation_visible,
            packet.no_mutation_envelope_visible,
            packet.l1_l2_l3_separated,
            packet.runtime_deferred,
            packet.product_promotion_blocked,
            packet.user_visible_summary
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

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_034_800_000;
    const GIB: u64 = 1_073_741_824;
    const MIB: u64 = 1_048_576;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("qat_model_route_card_memory_preflight".to_string()),
            b"qat-route-preflight-upstream",
            CREATED_AT_MS,
        )
    }

    fn refs(id: &str, status: CompressedRoutePacketStatus) -> CompressedRouteAnswerPacketRefs {
        CompressedRouteAnswerPacketRefs {
            upstream_preflight_card_ref: format!("qat_route_preflight:{id}"),
            falsifier_ref: format!("falsifier:F-CompressedRoute-AnswerPacket-DryRun:{id}"),
            answer_packet_ref: format!("answer_packet:compressed_route_dry_run:{id}"),
            run_event_log_ref: format!("run_event_log:compressed_route_dry_run:{id}"),
            fallback_ref: format!("fallback:compressed_route_dry_run:{id}"),
            rollback_ref: format!("rollback:compressed_route_dry_run:{id}"),
            admission_ref: format!("admission:compressed_route_dry_run:{id}"),
            cancellation_ref: format!("cancel:compressed_route_dry_run:{id}"),
            compatibility_fence_ref: format!("compat:compressed_route_dry_run:{id}"),
            route_caveat_ref: format!("route_caveat:compressed_route_dry_run:{id}"),
            visible_summary_ref: format!("visible_summary:compressed_route_dry_run:{id}"),
            abstention_reason_ref: (status == CompressedRoutePacketStatus::CarriedAbstention)
                .then(|| format!("abstain:compressed_route_dry_run:{id}")),
            vault_preservation_ref: (status == CompressedRoutePacketStatus::CarriedVaultOnly)
                .then(|| format!("vault:compressed_route_dry_run:{id}")),
            rejected_candidate_refs: vec![
                "rejected_candidate:gemma4_12b_insufficient_headroom".to_string(),
                "rejected_candidate:gemma4_31b_vault_only".to_string(),
            ],
        }
    }

    fn packet(
        id: &str,
        model_id: &str,
        status: CompressedRoutePacketStatus,
        resident_gib: u64,
    ) -> CompressedRouteAnswerPacketDryRun {
        let declared_file_bytes = if model_id.contains("-12B-") {
            11_907_350_576
        } else if model_id.contains("-31B-") {
            30_697_345_596
        } else {
            4_628_569_635
        };
        CompressedRouteAnswerPacketDryRun {
            packet_id: id.to_string(),
            model_id: model_id.to_string(),
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            packet_status: status,
            product_build: ProductBuild::Pro,
            pro_status: match status {
                CompressedRoutePacketStatus::CarriedVaultOnly => ProStatus::VaultPreserved,
                CompressedRoutePacketStatus::Blocked => ProStatus::Blocked,
                _ => ProStatus::ResearchCandidate,
            },
            promotion_tier: CompressedRoutePromotionTier::T1L1Metadata,
            bytes: CompressedRouteByteLedger::metadata_only(
                declared_file_bytes,
                resident_gib * GIB,
                512 * MIB,
                256 * MIB,
                128 * MIB,
                24_000,
            ),
            refs: refs(id, status),
            user_visible_summary: format!(
                "Compressed route dry-run packet {id} is visible, reversible, cancellable, byte-accounted, and explicitly not live inference or product capability."
            ),
            selected_model_visible: true,
            rejected_candidates_visible: true,
            route_caveat_visible: true,
            byte_ledger_visible: true,
            fallback_visible: true,
            rollback_visible: true,
            cancellation_visible: true,
            no_mutation_envelope_visible: true,
            l1_l2_l3_separated: true,
            runtime_deferred: true,
            product_promotion_blocked: true,
            first_token_claimed: false,
            quality_claimed: false,
            runtime_parity_claimed: false,
            mas_readiness_claimed: false,
            route_policy_mutated: false,
            answer_packet_suppressed: false,
            hidden_chain_exposed: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn packet_set(
        packets: Vec<CompressedRouteAnswerPacketDryRun>,
    ) -> Result<CompressedRouteAnswerPacketDryRunSet, CompressedRouteAnswerPacketError> {
        CompressedRouteAnswerPacketDryRunSet::from_preflight(
            upstream_address(),
            "artifact:qat_model_route_card_memory_preflight:result",
            packets,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            64_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_order_stable_visible_dry_run_packets() {
        let mut packets = vec![
            packet(
                "gemma4_e4b_compressed_route_packet",
                "google/gemma-4-E4B-it-qat-q4_0-gguf",
                CompressedRoutePacketStatus::PacketizedDryRun,
                8,
            ),
            packet(
                "gemma4_e2b_compressed_route_packet",
                "google/gemma-4-E2B-it-qat-q4_0-gguf",
                CompressedRoutePacketStatus::PacketizedDryRun,
                5,
            ),
        ];
        let set = packet_set(packets.clone()).expect("packet set should validate");
        packets.reverse();
        let reversed = packet_set(packets).expect("packet set should validate");
        assert_eq!(set.set_address, reversed.set_address);
        assert_eq!(set.metrics().packetized_dry_run_count, 2);
        assert_eq!(set.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_12b_or_31b_packetized_as_dry_run() {
        let twelve_b = packet(
            "gemma4_12b_bad_packet",
            "google/gemma-4-12B-it-qat-q4_0-gguf",
            CompressedRoutePacketStatus::PacketizedDryRun,
            13,
        );
        assert!(packet_set(vec![twelve_b]).is_err());
        let thirty_one_b = packet(
            "gemma4_31b_bad_packet",
            "google/gemma-4-31B-it-qat-q4_0-gguf",
            CompressedRoutePacketStatus::PacketizedDryRun,
            32,
        );
        assert!(packet_set(vec![thirty_one_b]).is_err());
    }

    #[test]
    fn rejects_opened_or_resident_bytes() {
        let mut candidate = packet(
            "gemma4_e2b_loaded_packet",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            CompressedRoutePacketStatus::PacketizedDryRun,
            5,
        );
        candidate.bytes.opened_model_bytes = 1;
        assert!(packet_set(vec![candidate.clone()]).is_err());
        candidate.bytes.opened_model_bytes = 0;
        candidate.bytes.resident_model_bytes = 1;
        assert!(packet_set(vec![candidate.clone()]).is_err());
        candidate.bytes.resident_model_bytes = 0;
        candidate.bytes.runtime_bytes_loaded = 1;
        assert!(packet_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_missing_visibility_or_suppressed_packet() {
        let mut candidate = packet(
            "gemma4_e2b_invisible_packet",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            CompressedRoutePacketStatus::PacketizedDryRun,
            5,
        );
        candidate.byte_ledger_visible = false;
        assert!(packet_set(vec![candidate.clone()]).is_err());
        candidate.byte_ledger_visible = true;
        candidate.answer_packet_suppressed = true;
        assert!(packet_set(vec![candidate]).is_err());
    }

    #[test]
    fn rejects_product_promotion_and_hidden_authority() {
        let mut candidate = packet(
            "gemma4_e2b_claim_packet",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            CompressedRoutePacketStatus::PacketizedDryRun,
            5,
        );
        candidate.product_build = ProductBuild::Mas;
        assert!(packet_set(vec![candidate.clone()]).is_err());
        candidate.product_build = ProductBuild::Pro;
        candidate.first_token_claimed = true;
        assert!(packet_set(vec![candidate.clone()]).is_err());
        candidate.first_token_claimed = false;
        candidate.hidden_cloud_fallback_allowed = true;
        assert!(packet_set(vec![candidate]).is_err());
    }
}
