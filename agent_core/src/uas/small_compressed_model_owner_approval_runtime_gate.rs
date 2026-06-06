//! Small compressed-model owner-approval runtime gate.
//!
//! This primitive turns the compressed-model live-harness preflight into a
//! fail-closed runtime command gate. It records the exact future one-token probe
//! shape while proving that owner approval is still pending and no model,
//! runtime, provider, or product bytes are opened.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, QatRouteRuntimeLane, SmallCompressedHarnessPromotionTier, UasAddress,
    UasKind,
};

pub const SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_CURSOR: &str =
    "small_compressed_model_owner_approval_runtime_gate";
pub const SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_NEXT_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe";

const UPSTREAM_PREFLIGHT_PREFIX: &str = "artifact:small_compressed_model_live_harness_preflight:";
const CANDIDATE_PREFIX: &str = "candidate:small_compressed_model_live_harness_preflight:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:";
const COMMAND_LEDGER_PREFIX: &str = "command_ledger:small_compressed_owner_gate:";
const MODEL_PATH_PREFIX: &str = "model_path:pending_owner_approval:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:small_compressed_owner_gate:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:small_compressed_owner_gate:";
const ROLLBACK_PREFIX: &str = "rollback:small_compressed_owner_gate:";
const CANCELLATION_PREFIX: &str = "cancel:small_compressed_owner_gate:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:small_compressed_owner_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:small_compressed_owner_gate:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:small_compressed_owner_gate:";
const DENIED_ROUTE_PREFIX: &str = "denied_route:";
const MAX_SET_METADATA_BYTES: u64 = 512 * 1024;
const MAX_GATE_METADATA_BYTES: u64 = 128 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 160;
const SELECTED_E2B_CANDIDATE: &str = "gemma4_e2b_qat_gguf_harness_preflight";

const REQUIRED_DENIED_ROUTES: &[&str] = &[
    "denied_route:gemma4_12b_default",
    "denied_route:gemma4_31b_default",
    "denied_route:mlx_swift_loader_unproven",
    "denied_route:litert_package_proof_required",
    "denied_route:kv_direct_128k_shard",
    "denied_route:mmap_or_ssd_stress",
    "denied_route:provider_fallback",
    "denied_route:dense_70b_runtime",
];

// UAS: uas:small-compressed-owner-gate:approval-status
// Plane: Controller + Verification
// Residency: pending approval only; approved execution is a later witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedOwnerApprovalStatus {
    PendingOwnerApproval,
    OwnerApprovedForSeparateRuntimeWitness,
    Blocked,
}

// UAS: uas:small-compressed-owner-gate:byte-ledger
// Plane: Verification
// Residency: planned future byte ceilings; every live-byte counter remains zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovalByteLedger {
    pub declared_file_bytes: u64,
    pub planned_model_bytes: u64,
    pub planned_kv_bytes: u64,
    pub planned_scratch_bytes: u64,
    pub planned_route_bytes: u64,
    pub max_context_tokens: u64,
    pub retained_token_budget: u64,
    pub timeout_ms: u64,
    pub cancellation_deadline_ms: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub metadata_bytes_read: u64,
}

impl SmallCompressedOwnerApprovalByteLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn metadata_only(
        declared_file_bytes: u64,
        planned_model_bytes: u64,
        planned_kv_bytes: u64,
        planned_scratch_bytes: u64,
        max_context_tokens: u64,
        retained_token_budget: u64,
        timeout_ms: u64,
        cancellation_deadline_ms: u64,
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
            max_context_tokens,
            retained_token_budget,
            timeout_ms,
            cancellation_deadline_ms,
            opened_model_bytes: 0,
            opened_runtime_bytes: 0,
            resident_model_bytes: 0,
            resident_runtime_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            metadata_bytes_read,
        }
    }
}

// UAS: uas:small-compressed-owner-gate:refs
// Plane: Verification
// Residency: proof handles needed before a runtime command can be armed.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovalRefs {
    pub upstream_preflight_ref: String,
    pub selected_candidate_ref: String,
    pub owner_approval_ref: String,
    pub command_ledger_ref: String,
    pub model_path_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub memory_ledger_ref: String,
    pub compatibility_fence_ref: String,
    pub route_caveat_ref: String,
    pub denied_route_refs: Vec<String>,
}

// UAS: uas:small-compressed-owner-gate:gate
// Plane: Controller + Verification
// Residency: metadata-only command gate, not runtime approval.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelOwnerApprovalRuntimeGate {
    pub gate_id: String,
    pub selected_candidate_id: String,
    pub model_id: String,
    pub runtime_lane: QatRouteRuntimeLane,
    pub approval_status: SmallCompressedOwnerApprovalStatus,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: SmallCompressedHarnessPromotionTier,
    pub bytes: SmallCompressedOwnerApprovalByteLedger,
    pub refs: SmallCompressedOwnerApprovalRefs,
    pub user_visible_summary: String,
    pub command_visible: bool,
    pub selected_model_visible: bool,
    pub denied_routes_visible: bool,
    pub byte_plan_visible: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub runtime_command_armed: bool,
    pub runtime_command_executed: bool,
    pub live_execution_performed: bool,
    pub first_token_claimed: bool,
    pub retained_token_digest_recorded: bool,
    pub quality_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub cancellation_required: bool,
    pub memory_ledger_required: bool,
    pub route_policy_mutated: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub twelve_b_or_thirty_one_b_probe_allowed: bool,
    pub mlx_swift_loader_allowed: bool,
    pub litert_without_package_proof_allowed: bool,
    pub kv_direct_128k_shard_allowed: bool,
    pub mmap_or_ssd_stress_allowed: bool,
}

// UAS: uas:small-compressed-owner-gate:set
// Plane: Controller + Verification
// Residency: metadata-only gate set bound to the upstream preflight witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelOwnerApprovalRuntimeGateSet {
    pub set_address: UasAddress,
    pub upstream_preflight_set_address: UasAddress,
    pub upstream_preflight_witness_ref: String,
    pub selected_gate_id: String,
    pub gates: Vec<SmallCompressedModelOwnerApprovalRuntimeGate>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:small-compressed-owner-gate:metrics
// Plane: Verification
// Residency: derived gate counts and byte totals.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedOwnerApprovalGateMetrics {
    pub gate_count: u64,
    pub pending_owner_approval_count: u64,
    pub runtime_lane_count: u64,
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

impl SmallCompressedModelOwnerApprovalRuntimeGateSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_preflight(
        upstream_preflight_set_address: UasAddress,
        upstream_preflight_witness_ref: impl Into<String>,
        selected_gate_id: impl Into<String>,
        mut gates: Vec<SmallCompressedModelOwnerApprovalRuntimeGate>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, SmallCompressedOwnerApprovalGateError> {
        gates.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let witness_ref = upstream_preflight_witness_ref.into();
        let selected_gate_id = selected_gate_id.into();
        validate_set_inputs(
            &upstream_preflight_set_address,
            &witness_ref,
            &selected_gate_id,
            &gates,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = gate_set_preimage(
            &upstream_preflight_set_address,
            &witness_ref,
            &selected_gate_id,
            &gates,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(SMALL_COMPRESSED_MODEL_OWNER_APPROVAL_RUNTIME_GATE_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_preflight_set_address,
            upstream_preflight_witness_ref: witness_ref,
            selected_gate_id,
            gates,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> SmallCompressedOwnerApprovalGateMetrics {
        let mut runtime_lanes = HashSet::new();
        let mut pending_owner_approval_count = 0;
        let mut planned_route_bytes_total = 0;
        let mut opened_model_bytes = 0;
        let mut opened_runtime_bytes = 0;
        let mut resident_model_bytes = 0;
        let mut resident_runtime_bytes = 0;
        let mut model_bytes_loaded = 0;
        let mut runtime_bytes_loaded = 0;
        let mut provider_calls_made = 0;
        let mut metadata_bytes_read = self.metadata_bytes;

        for gate in &self.gates {
            runtime_lanes.insert(gate.runtime_lane);
            if gate.approval_status == SmallCompressedOwnerApprovalStatus::PendingOwnerApproval {
                pending_owner_approval_count += 1;
            }
            planned_route_bytes_total += gate.bytes.planned_route_bytes;
            opened_model_bytes += gate.bytes.opened_model_bytes;
            opened_runtime_bytes += gate.bytes.opened_runtime_bytes;
            resident_model_bytes += gate.bytes.resident_model_bytes;
            resident_runtime_bytes += gate.bytes.resident_runtime_bytes;
            model_bytes_loaded += gate.bytes.model_bytes_loaded;
            runtime_bytes_loaded += gate.bytes.runtime_bytes_loaded;
            provider_calls_made += gate.bytes.provider_calls_made;
            metadata_bytes_read += gate.bytes.metadata_bytes_read;
        }

        SmallCompressedOwnerApprovalGateMetrics {
            gate_count: self.gates.len() as u64,
            pending_owner_approval_count,
            runtime_lane_count: runtime_lanes.len() as u64,
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

// UAS: uas:small-compressed-owner-gate:error
// Plane: Verification
// Residency: fail-closed validation for the owner-approval runtime gate.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SmallCompressedOwnerApprovalGateError {
    MissingUpstreamPreflight,
    MissingUpstreamWitness,
    EmptySelectedGate,
    EmptyGateSet,
    MetadataBudgetExceeded {
        bytes: u64,
        max_bytes: u64,
    },
    DuplicateGateId(String),
    DuplicateCandidate(String),
    SelectedGateMissing(String),
    BadSetProductState,
    EmptyField {
        gate_id: String,
        field: &'static str,
    },
    BadPrefix {
        gate_id: String,
        field: &'static str,
        expected: &'static str,
    },
    MissingDeniedRoute {
        gate_id: String,
        route: &'static str,
    },
    MissingVisibility(String),
    BadProductBuild(String),
    BadProStatus(String),
    BadPromotionTier(String),
    BadSelectedCandidate(String),
    BadRuntimeLane(String),
    InvalidByteLedger {
        gate_id: String,
        reason: &'static str,
    },
    ByteLoadAttempt(String),
    RuntimeAttempt(String),
    ProductPromotionAttempt(String),
    HiddenAuthority(String),
    ForbiddenRouteAllowed(String),
}

impl fmt::Display for SmallCompressedOwnerApprovalGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingUpstreamPreflight => write!(f, "missing upstream preflight address"),
            Self::MissingUpstreamWitness => write!(f, "missing upstream preflight witness ref"),
            Self::EmptySelectedGate => write!(f, "missing selected owner-approval gate id"),
            Self::EmptyGateSet => write!(f, "owner-approval gate set is empty"),
            Self::MetadataBudgetExceeded { bytes, max_bytes } => {
                write!(f, "metadata budget exceeded: {bytes} > {max_bytes}")
            }
            Self::DuplicateGateId(id) => write!(f, "duplicate owner-approval gate `{id}`"),
            Self::DuplicateCandidate(id) => write!(f, "duplicate selected candidate `{id}`"),
            Self::SelectedGateMissing(id) => write!(f, "selected gate `{id}` missing"),
            Self::BadSetProductState => {
                write!(f, "owner-approval gate set tried to promote product state")
            }
            Self::EmptyField { gate_id, field } => {
                write!(f, "gate `{gate_id}` has empty field `{field}`")
            }
            Self::BadPrefix {
                gate_id,
                field,
                expected,
            } => write!(
                f,
                "gate `{gate_id}` field `{field}` must start with `{expected}`"
            ),
            Self::MissingDeniedRoute { gate_id, route } => {
                write!(f, "gate `{gate_id}` missing denied route `{route}`")
            }
            Self::MissingVisibility(id) => write!(f, "gate `{id}` missing visible proof"),
            Self::BadProductBuild(id) => write!(f, "gate `{id}` cannot promote to MAS"),
            Self::BadProStatus(id) => write!(f, "gate `{id}` has forbidden Pro status"),
            Self::BadPromotionTier(id) => write!(f, "gate `{id}` cannot promote beyond T1"),
            Self::BadSelectedCandidate(id) => {
                write!(f, "gate `{id}` is not bound to the selected E2B preflight")
            }
            Self::BadRuntimeLane(id) => write!(f, "gate `{id}` is not the GGUF/llama.cpp lane"),
            Self::InvalidByteLedger { gate_id, reason } => {
                write!(f, "gate `{gate_id}` invalid byte ledger: {reason}")
            }
            Self::ByteLoadAttempt(id) => write!(f, "gate `{id}` attempted byte/provider use"),
            Self::RuntimeAttempt(id) => write!(f, "gate `{id}` attempted runtime execution"),
            Self::ProductPromotionAttempt(id) => {
                write!(f, "gate `{id}` attempted product promotion")
            }
            Self::HiddenAuthority(id) => write!(f, "gate `{id}` enabled hidden authority"),
            Self::ForbiddenRouteAllowed(id) => write!(f, "gate `{id}` allowed a forbidden route"),
        }
    }
}

impl std::error::Error for SmallCompressedOwnerApprovalGateError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_preflight_set_address: &UasAddress,
    upstream_preflight_witness_ref: &str,
    selected_gate_id: &str,
    gates: &[SmallCompressedModelOwnerApprovalRuntimeGate],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if upstream_preflight_set_address.to_string().trim().is_empty() {
        return Err(SmallCompressedOwnerApprovalGateError::MissingUpstreamPreflight);
    }
    if upstream_preflight_witness_ref.trim().is_empty() {
        return Err(SmallCompressedOwnerApprovalGateError::MissingUpstreamWitness);
    }
    if !upstream_preflight_witness_ref.starts_with(UPSTREAM_PREFLIGHT_PREFIX) {
        return Err(SmallCompressedOwnerApprovalGateError::BadPrefix {
            gate_id: "set".to_string(),
            field: "upstream_preflight_witness_ref",
            expected: UPSTREAM_PREFLIGHT_PREFIX,
        });
    }
    if selected_gate_id.trim().is_empty() {
        return Err(SmallCompressedOwnerApprovalGateError::EmptySelectedGate);
    }
    if gates.is_empty() {
        return Err(SmallCompressedOwnerApprovalGateError::EmptyGateSet);
    }
    if metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(
            SmallCompressedOwnerApprovalGateError::MetadataBudgetExceeded {
                bytes: metadata_bytes,
                max_bytes: MAX_SET_METADATA_BYTES,
            },
        );
    }
    if product_build != &ProductBuild::Pro
        || matches!(pro_status, ProStatus::Live | ProStatus::Omega)
        || !l1_l2_l3_separated
        || !runtime_deferred
        || !product_promotion_blocked
    {
        return Err(SmallCompressedOwnerApprovalGateError::BadSetProductState);
    }

    let mut gate_ids = HashSet::new();
    let mut candidate_ids = HashSet::new();
    let mut selected_gate = None;
    for gate in gates {
        validate_gate(gate)?;
        if !gate_ids.insert(gate.gate_id.clone()) {
            return Err(SmallCompressedOwnerApprovalGateError::DuplicateGateId(
                gate.gate_id.clone(),
            ));
        }
        if !candidate_ids.insert(gate.selected_candidate_id.clone()) {
            return Err(SmallCompressedOwnerApprovalGateError::DuplicateCandidate(
                gate.selected_candidate_id.clone(),
            ));
        }
        if gate.gate_id == selected_gate_id {
            selected_gate = Some(gate);
        }
    }

    let gate = selected_gate.ok_or_else(|| {
        SmallCompressedOwnerApprovalGateError::SelectedGateMissing(selected_gate_id.to_string())
    })?;
    if gate.selected_candidate_id != SELECTED_E2B_CANDIDATE
        || !gate.model_id.contains("-E2B-")
        || gate.approval_status != SmallCompressedOwnerApprovalStatus::PendingOwnerApproval
    {
        return Err(SmallCompressedOwnerApprovalGateError::BadSelectedCandidate(
            gate.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_gate(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    require_nonempty(&gate.gate_id, &gate.gate_id, "gate_id")?;
    require_nonempty(
        &gate.selected_candidate_id,
        &gate.gate_id,
        "selected_candidate_id",
    )?;
    require_nonempty(&gate.model_id, &gate.gate_id, "model_id")?;
    require_nonempty(
        &gate.user_visible_summary,
        &gate.gate_id,
        "user_visible_summary",
    )?;
    if gate.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(SmallCompressedOwnerApprovalGateError::MissingVisibility(
            gate.gate_id.clone(),
        ));
    }
    validate_refs(gate)?;
    validate_product(gate)?;
    validate_byte_ledger(gate)?;
    validate_selection(gate)?;
    validate_visibility(gate)?;
    validate_no_runtime_or_promotion(gate)?;
    validate_forbidden_routes(gate)?;
    Ok(())
}

fn validate_refs(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    let refs = &gate.refs;
    require_prefix(
        &refs.upstream_preflight_ref,
        &gate.gate_id,
        "upstream_preflight_ref",
        UPSTREAM_PREFLIGHT_PREFIX,
    )?;
    require_prefix(
        &refs.selected_candidate_ref,
        &gate.gate_id,
        "selected_candidate_ref",
        CANDIDATE_PREFIX,
    )?;
    require_prefix(
        &refs.owner_approval_ref,
        &gate.gate_id,
        "owner_approval_ref",
        OWNER_APPROVAL_PREFIX,
    )?;
    require_prefix(
        &refs.command_ledger_ref,
        &gate.gate_id,
        "command_ledger_ref",
        COMMAND_LEDGER_PREFIX,
    )?;
    require_prefix(
        &refs.model_path_ref,
        &gate.gate_id,
        "model_path_ref",
        MODEL_PATH_PREFIX,
    )?;
    require_prefix(
        &refs.answer_packet_ref,
        &gate.gate_id,
        "answer_packet_ref",
        ANSWER_PACKET_PREFIX,
    )?;
    require_prefix(
        &refs.run_event_log_ref,
        &gate.gate_id,
        "run_event_log_ref",
        RUN_EVENT_LOG_PREFIX,
    )?;
    require_prefix(
        &refs.rollback_ref,
        &gate.gate_id,
        "rollback_ref",
        ROLLBACK_PREFIX,
    )?;
    require_prefix(
        &refs.cancellation_ref,
        &gate.gate_id,
        "cancellation_ref",
        CANCELLATION_PREFIX,
    )?;
    require_prefix(
        &refs.memory_ledger_ref,
        &gate.gate_id,
        "memory_ledger_ref",
        MEMORY_LEDGER_PREFIX,
    )?;
    require_prefix(
        &refs.compatibility_fence_ref,
        &gate.gate_id,
        "compatibility_fence_ref",
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    require_prefix(
        &refs.route_caveat_ref,
        &gate.gate_id,
        "route_caveat_ref",
        ROUTE_CAVEAT_PREFIX,
    )?;
    for denied in &refs.denied_route_refs {
        require_prefix(
            denied,
            &gate.gate_id,
            "denied_route_refs",
            DENIED_ROUTE_PREFIX,
        )?;
    }
    for required in REQUIRED_DENIED_ROUTES {
        if !refs.denied_route_refs.iter().any(|route| route == required) {
            return Err(SmallCompressedOwnerApprovalGateError::MissingDeniedRoute {
                gate_id: gate.gate_id.clone(),
                route: required,
            });
        }
    }
    Ok(())
}

fn validate_product(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if gate.product_build != ProductBuild::Pro {
        return Err(SmallCompressedOwnerApprovalGateError::BadProductBuild(
            gate.gate_id.clone(),
        ));
    }
    if gate.pro_status != ProStatus::ResearchCandidate {
        return Err(SmallCompressedOwnerApprovalGateError::BadProStatus(
            gate.gate_id.clone(),
        ));
    }
    if gate.promotion_tier != SmallCompressedHarnessPromotionTier::T1L1Metadata {
        return Err(SmallCompressedOwnerApprovalGateError::BadPromotionTier(
            gate.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_byte_ledger(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    let bytes = &gate.bytes;
    if bytes.declared_file_bytes == 0
        || bytes.planned_model_bytes == 0
        || bytes.planned_kv_bytes == 0
        || bytes.planned_scratch_bytes == 0
        || bytes.max_context_tokens == 0
        || bytes.retained_token_budget != 1
        || bytes.timeout_ms == 0
        || bytes.cancellation_deadline_ms == 0
    {
        return Err(invalid_bytes(
            gate,
            "declared/planned/context/token/timeout bytes must be nonzero and token budget must be one",
        ));
    }
    if bytes.cancellation_deadline_ms > bytes.timeout_ms {
        return Err(invalid_bytes(
            gate,
            "cancellation deadline must not exceed timeout",
        ));
    }
    if bytes.planned_model_bytes <= bytes.declared_file_bytes {
        return Err(invalid_bytes(
            gate,
            "planned model bytes must exceed declared file bytes",
        ));
    }
    let expected_route_bytes = bytes
        .planned_model_bytes
        .checked_add(bytes.planned_kv_bytes)
        .and_then(|value| value.checked_add(bytes.planned_scratch_bytes))
        .ok_or_else(|| invalid_bytes(gate, "planned route bytes overflowed"))?;
    if bytes.planned_route_bytes != expected_route_bytes {
        return Err(invalid_bytes(
            gate,
            "planned_route_bytes must equal model + kv + scratch",
        ));
    }
    if bytes.opened_model_bytes != 0
        || bytes.opened_runtime_bytes != 0
        || bytes.resident_model_bytes != 0
        || bytes.resident_runtime_bytes != 0
        || bytes.model_bytes_loaded != 0
        || bytes.runtime_bytes_loaded != 0
        || bytes.provider_calls_made != 0
    {
        return Err(SmallCompressedOwnerApprovalGateError::ByteLoadAttempt(
            gate.gate_id.clone(),
        ));
    }
    if bytes.metadata_bytes_read > MAX_GATE_METADATA_BYTES {
        return Err(
            SmallCompressedOwnerApprovalGateError::MetadataBudgetExceeded {
                bytes: bytes.metadata_bytes_read,
                max_bytes: MAX_GATE_METADATA_BYTES,
            },
        );
    }
    Ok(())
}

fn validate_selection(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if gate.selected_candidate_id != SELECTED_E2B_CANDIDATE || !gate.model_id.contains("-E2B-") {
        return Err(SmallCompressedOwnerApprovalGateError::BadSelectedCandidate(
            gate.gate_id.clone(),
        ));
    }
    if gate.runtime_lane != QatRouteRuntimeLane::GgufLlamaCpp {
        return Err(SmallCompressedOwnerApprovalGateError::BadRuntimeLane(
            gate.gate_id.clone(),
        ));
    }
    if gate.model_id.contains("-12B-") || gate.model_id.contains("-31B-") {
        return Err(
            SmallCompressedOwnerApprovalGateError::ForbiddenRouteAllowed(gate.gate_id.clone()),
        );
    }
    Ok(())
}

fn validate_visibility(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if !gate.command_visible
        || !gate.selected_model_visible
        || !gate.denied_routes_visible
        || !gate.byte_plan_visible
        || !gate.answer_packet_required
        || !gate.run_event_log_required
        || !gate.rollback_required
        || !gate.cancellation_required
        || !gate.memory_ledger_required
    {
        return Err(SmallCompressedOwnerApprovalGateError::MissingVisibility(
            gate.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_no_runtime_or_promotion(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if !gate.owner_approval_required
        || gate.owner_approval_granted
        || gate.approval_status != SmallCompressedOwnerApprovalStatus::PendingOwnerApproval
        || gate.runtime_command_armed
        || gate.runtime_command_executed
        || gate.live_execution_performed
        || gate.first_token_claimed
        || gate.retained_token_digest_recorded
    {
        return Err(SmallCompressedOwnerApprovalGateError::RuntimeAttempt(
            gate.gate_id.clone(),
        ));
    }
    if gate.quality_claimed
        || gate.l2_capability_claimed
        || gate.l3_wrv_claimed
        || gate.mas_readiness_claimed
    {
        return Err(
            SmallCompressedOwnerApprovalGateError::ProductPromotionAttempt(gate.gate_id.clone()),
        );
    }
    if gate.route_policy_mutated
        || gate.hidden_cloud_fallback_allowed
        || gate.hidden_route_authority_allowed
        || gate.live_dense_70b_claimed
        || gate.ssd_as_ram_claimed
    {
        return Err(SmallCompressedOwnerApprovalGateError::HiddenAuthority(
            gate.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_forbidden_routes(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if gate.twelve_b_or_thirty_one_b_probe_allowed
        || gate.mlx_swift_loader_allowed
        || gate.litert_without_package_proof_allowed
        || gate.kv_direct_128k_shard_allowed
        || gate.mmap_or_ssd_stress_allowed
    {
        return Err(
            SmallCompressedOwnerApprovalGateError::ForbiddenRouteAllowed(gate.gate_id.clone()),
        );
    }
    Ok(())
}

fn invalid_bytes(
    gate: &SmallCompressedModelOwnerApprovalRuntimeGate,
    reason: &'static str,
) -> SmallCompressedOwnerApprovalGateError {
    SmallCompressedOwnerApprovalGateError::InvalidByteLedger {
        gate_id: gate.gate_id.clone(),
        reason,
    }
}

fn require_nonempty(
    value: &str,
    gate_id: &str,
    field: &'static str,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if value.trim().is_empty() {
        return Err(SmallCompressedOwnerApprovalGateError::EmptyField {
            gate_id: gate_id.to_string(),
            field,
        });
    }
    Ok(())
}

fn require_prefix(
    value: &str,
    gate_id: &str,
    field: &'static str,
    expected: &'static str,
) -> Result<(), SmallCompressedOwnerApprovalGateError> {
    if !value.starts_with(expected) {
        return Err(SmallCompressedOwnerApprovalGateError::BadPrefix {
            gate_id: gate_id.to_string(),
            field,
            expected,
        });
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn gate_set_preimage(
    upstream_preflight_set_address: &UasAddress,
    upstream_preflight_witness_ref: &str,
    selected_gate_id: &str,
    gates: &[SmallCompressedModelOwnerApprovalRuntimeGate],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "small_compressed_model_owner_approval_runtime_gate_v1\n{}\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_preflight_set_address,
        upstream_preflight_witness_ref,
        selected_gate_id,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for gate in gates {
        preimage.push_str(&format!(
            "{}\n{}\n{}\n{:?}\n{:?}\n{}\n{:?}\n{:?}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            gate.gate_id,
            gate.selected_candidate_id,
            gate.model_id,
            gate.runtime_lane,
            gate.approval_status,
            product_build_preimage(&gate.product_build),
            gate.pro_status,
            gate.promotion_tier,
            gate.bytes.declared_file_bytes,
            gate.bytes.planned_model_bytes,
            gate.bytes.planned_kv_bytes,
            gate.bytes.planned_scratch_bytes,
            gate.bytes.planned_route_bytes,
            gate.bytes.max_context_tokens,
            gate.bytes.retained_token_budget,
            gate.bytes.timeout_ms,
            gate.bytes.cancellation_deadline_ms,
            gate.bytes.opened_model_bytes,
            gate.bytes.opened_runtime_bytes,
            gate.bytes.resident_model_bytes,
            gate.bytes.resident_runtime_bytes,
            gate.bytes.model_bytes_loaded,
            gate.bytes.runtime_bytes_loaded,
            gate.bytes.provider_calls_made,
            gate.bytes.metadata_bytes_read,
            gate.refs.upstream_preflight_ref,
            gate.refs.selected_candidate_ref,
            gate.refs.owner_approval_ref,
            gate.refs.command_ledger_ref,
            gate.refs.model_path_ref,
            gate.refs.answer_packet_ref,
            gate.refs.run_event_log_ref,
            gate.refs.rollback_ref,
            gate.refs.cancellation_ref,
            gate.refs.memory_ledger_ref,
            gate.refs.compatibility_fence_ref,
            gate.refs.route_caveat_ref,
            gate.refs.denied_route_refs.join(","),
            gate.command_visible,
            gate.selected_model_visible,
            gate.denied_routes_visible,
            gate.byte_plan_visible,
            gate.owner_approval_required,
            gate.owner_approval_granted,
            gate.runtime_command_armed,
            gate.runtime_command_executed,
            gate.live_execution_performed,
            gate.first_token_claimed,
            gate.retained_token_digest_recorded,
            gate.answer_packet_required,
            gate.run_event_log_required,
            gate.rollback_required,
            gate.cancellation_required,
            gate.memory_ledger_required,
            gate.user_visible_summary
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

    const CREATED_AT_MS: u64 = 1_779_034_900_000;
    const GIB: u64 = 1_073_741_824;
    const MIB: u64 = 1_048_576;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("small_compressed_model_live_harness_preflight".to_string()),
            b"small-compressed-owner-gate-upstream",
            CREATED_AT_MS,
        )
    }

    fn refs(id: &str) -> SmallCompressedOwnerApprovalRefs {
        SmallCompressedOwnerApprovalRefs {
            upstream_preflight_ref: "artifact:small_compressed_model_live_harness_preflight:result"
                .to_string(),
            selected_candidate_ref: format!(
                "candidate:small_compressed_model_live_harness_preflight:{SELECTED_E2B_CANDIDATE}"
            ),
            owner_approval_ref: format!("owner_approval:pending:{id}"),
            command_ledger_ref: format!("command_ledger:small_compressed_owner_gate:{id}"),
            model_path_ref: format!("model_path:pending_owner_approval:{id}"),
            answer_packet_ref: format!("answer_packet:small_compressed_owner_gate:{id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_owner_gate:{id}"),
            rollback_ref: format!("rollback:small_compressed_owner_gate:{id}"),
            cancellation_ref: format!("cancel:small_compressed_owner_gate:{id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_owner_gate:{id}"),
            compatibility_fence_ref: format!("compat:small_compressed_owner_gate:{id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_owner_gate:{id}"),
            denied_route_refs: REQUIRED_DENIED_ROUTES
                .iter()
                .map(|route| route.to_string())
                .collect(),
        }
    }

    fn gate() -> SmallCompressedModelOwnerApprovalRuntimeGate {
        SmallCompressedModelOwnerApprovalRuntimeGate {
            gate_id: "gemma4_e2b_qat_gguf_owner_approval_runtime_gate".to_string(),
            selected_candidate_id: SELECTED_E2B_CANDIDATE.to_string(),
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            approval_status: SmallCompressedOwnerApprovalStatus::PendingOwnerApproval,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
            bytes: SmallCompressedOwnerApprovalByteLedger::metadata_only(
                4_628_569_635,
                5 * GIB,
                512 * MIB,
                256 * MIB,
                2048,
                1,
                120_000,
                5_000,
                24_000,
            ),
            refs: refs("gemma4_e2b_qat_gguf_owner_approval_runtime_gate"),
            user_visible_summary: "Gemma 4 E2B QAT GGUF is the only selected tiny compressed-model future runtime probe candidate. This gate is pending explicit owner approval, visible command ledger, cancellation, rollback, memory ledger, RunEventLog, and AnswerPacket proof; no bytes open and no product capability promotes.".to_string(),
            command_visible: true,
            selected_model_visible: true,
            denied_routes_visible: true,
            byte_plan_visible: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            runtime_command_armed: false,
            runtime_command_executed: false,
            live_execution_performed: false,
            first_token_claimed: false,
            retained_token_digest_recorded: false,
            quality_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            mas_readiness_claimed: false,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            cancellation_required: true,
            memory_ledger_required: true,
            route_policy_mutated: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            twelve_b_or_thirty_one_b_probe_allowed: false,
            mlx_swift_loader_allowed: false,
            litert_without_package_proof_allowed: false,
            kv_direct_128k_shard_allowed: false,
            mmap_or_ssd_stress_allowed: false,
        }
    }

    fn gate_set(
        gates: Vec<SmallCompressedModelOwnerApprovalRuntimeGate>,
    ) -> Result<
        SmallCompressedModelOwnerApprovalRuntimeGateSet,
        SmallCompressedOwnerApprovalGateError,
    > {
        SmallCompressedModelOwnerApprovalRuntimeGateSet::from_preflight(
            upstream_address(),
            "artifact:small_compressed_model_live_harness_preflight:result",
            "gemma4_e2b_qat_gguf_owner_approval_runtime_gate",
            gates,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            72_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_pending_owner_approval_gate_deterministically() {
        let first = gate_set(vec![gate()]).expect("gate should validate");
        let second = gate_set(vec![gate()]).expect("gate should validate");
        assert_eq!(first.set_address, second.set_address);
        assert_eq!(first.metrics().pending_owner_approval_count, 1);
        assert_eq!(first.metrics().model_bytes_loaded, 0);
        assert_eq!(first.metrics().provider_calls_made, 0);
    }

    #[test]
    fn rejects_owner_approval_or_runtime_execution() {
        let mut bad = gate();
        bad.owner_approval_granted = true;
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.runtime_command_armed = true;
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.first_token_claimed = true;
        assert!(gate_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_non_e2b_or_non_gguf_lane() {
        let mut bad = gate();
        bad.selected_candidate_id = "gemma4_e4b_qat_gguf_harness_alternate".to_string();
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.runtime_lane = QatRouteRuntimeLane::MlxSwiftCandidate;
        assert!(gate_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_loaded_bytes_provider_calls_and_bad_budget() {
        let mut bad = gate();
        bad.bytes.opened_model_bytes = 1;
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.bytes.provider_calls_made = 1;
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.bytes.planned_route_bytes += 1;
        assert!(gate_set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_product_promotion_hidden_authority_and_missing_denials() {
        let mut bad = gate();
        bad.l2_capability_claimed = true;
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.hidden_cloud_fallback_allowed = true;
        assert!(gate_set(vec![bad]).is_err());

        let mut bad = gate();
        bad.refs.denied_route_refs.pop();
        assert!(gate_set(vec![bad]).is_err());
    }
}
