//! Small-model runtime harness safety plan.
//!
//! This metadata-only witness sits at `small_model_runtime_harness_safety_plan`.
//! It does not run MLX, load model bytes, mutate route policy, or promote L2/L3.
//! It proves the next local small-model harness work has abort, rollback,
//! RunEventLog, AnswerPacket, admission, MAS/Pro, and owner-approval fences
//! before any runtime probe is allowed.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR: &str =
    "small_model_runtime_harness_safety_plan";
pub const SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR: &str =
    "small_model_runtime_harness_dry_run_witness";

const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const SERIAL_EXECUTOR_PREFIX: &str = "serialized_executor:";
const CANCELLATION_PREFIX: &str = "cancel:";
const PRIVACY_PREFIX: &str = "privacy:";
const REQUIRED_LANES: [&str; 3] = [
    "qwen3_small_catalog_smoke",
    "local_agent_notes_research_smoke",
    "coding_tool_dry_run_smoke",
];
const MIN_SURFACE_TEXT_BYTES: usize = 256;
const MAX_CONTEXT_TOKENS: u32 = 40_960;
const MAX_PROMPT_TOKENS: u32 = 8_192;
const MAX_DECODE_TOKENS: u32 = 512;
const MAX_MEMORY_BUDGET_BYTES: u64 = 8 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u32 = 300;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-safety:stage
// Plane: Controller + Verification
// Residency: metadata-only harness stage declaration.
pub enum SmallModelHarnessStage {
    CatalogInventory,
    DryRunWitness,
    OwnerApprovalGate,
    AbortableRuntimeProbe,
    EvidenceReview,
}

impl SmallModelHarnessStage {
    fn tag(&self) -> &'static str {
        match self {
            Self::CatalogInventory => "catalog_inventory",
            Self::DryRunWitness => "dry_run_witness",
            Self::OwnerApprovalGate => "owner_approval_gate",
            Self::AbortableRuntimeProbe => "abortable_runtime_probe",
            Self::EvidenceReview => "evidence_review",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-safety:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum SmallModelRuntimeHarnessSafetyError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyLane,
    EmptySurface,
    EmptyStage,
    DuplicateLane(String),
    DuplicateSurface(String),
    MissingRequiredLane(&'static str),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingStage(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence,
    MissingRunEventLog,
    MissingRollback(String),
    MissingAnswerPacket(String),
    MissingSerializedExecutor(String),
    MissingCancellation(String),
    MissingPrivacyFence(String),
    MissingLayerSeparation,
    OwnerApprovalMissing,
    DryRunFirstMissing,
    RuntimeProbeEnabledBeforeDryRun(String),
    BudgetExceeded(&'static str),
    MasOverclaimAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    HiddenRouteAuthority,
    RoutePolicyMutation,
    GateBypass,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudFallback,
    SubprocessSpawn,
    AutogenousKernelAttempt,
    SeventyBProbeAttempt,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    TransportRuntimeBytesLoaded,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelRuntimeHarnessSafetyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyLane => write!(f, "missing small-model harness lane"),
            Self::EmptySurface => write!(f, "missing safety-plan surface"),
            Self::EmptyStage => write!(f, "missing safety-plan stage"),
            Self::DuplicateLane(id) => write!(f, "duplicate harness lane `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::MissingRequiredLane(id) => write!(f, "missing required lane `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingStage(stage) => write!(f, "missing stage `{stage}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence => write!(f, "missing compatibility fence"),
            Self::MissingRunEventLog => write!(f, "missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "lane `{id}` missing rollback ref"),
            Self::MissingAnswerPacket(id) => write!(f, "lane `{id}` missing AnswerPacket"),
            Self::MissingSerializedExecutor(id) => {
                write!(f, "lane `{id}` missing serialized executor")
            }
            Self::MissingCancellation(id) => write!(f, "lane `{id}` missing cancellation ref"),
            Self::MissingPrivacyFence(id) => write!(f, "lane `{id}` missing privacy fence"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::OwnerApprovalMissing => write!(f, "owner approval is not required"),
            Self::DryRunFirstMissing => write!(f, "dry-run-first gate is missing"),
            Self::RuntimeProbeEnabledBeforeDryRun(id) => {
                write!(f, "lane `{id}` enables runtime before dry-run witness")
            }
            Self::BudgetExceeded(budget) => write!(f, "budget `{budget}` exceeded"),
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "gate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudFallback => write!(f, "hidden cloud fallback attempted"),
            Self::SubprocessSpawn => write!(f, "subprocess spawn attempted"),
            Self::AutogenousKernelAttempt => {
                write!(f, "autogenous kernel attempt escaped research gate")
            }
            Self::SeventyBProbeAttempt => write!(f, "70B probe attempted in small-model plan"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::TransportRuntimeBytesLoaded => {
                write!(f, "metadata witness loaded transport runtime bytes")
            }
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelRuntimeHarnessSafetyError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-safety:lane
// Plane: Controller + Verification
// Residency: metadata-only local-model harness lane card.
pub struct SmallModelHarnessLane {
    pub lane_id: String,
    pub model_role: String,
    pub catalog_ref: String,
    pub max_context_tokens: u32,
    pub max_prompt_tokens: u32,
    pub max_decode_tokens: u32,
    pub memory_budget_bytes: u64,
    pub runtime_budget_seconds: u32,
    pub serialized_executor_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub privacy_ref: String,
    pub dry_run_first: bool,
    pub owner_approval_required: bool,
    pub runtime_probe_enabled: bool,
    pub mutations_allowed: bool,
    pub route_policy_mutation_allowed: bool,
    pub cloud_fallback_allowed: bool,
    pub subprocess_spawn_allowed: bool,
    pub seventy_b_probe_allowed: bool,
}

impl SmallModelHarnessLane {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        lane_id: impl Into<String>,
        model_role: impl Into<String>,
        catalog_ref: impl Into<String>,
        max_context_tokens: u32,
        max_prompt_tokens: u32,
        max_decode_tokens: u32,
        memory_budget_bytes: u64,
        runtime_budget_seconds: u32,
        serialized_executor_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        privacy_ref: impl Into<String>,
        dry_run_first: bool,
        owner_approval_required: bool,
        runtime_probe_enabled: bool,
        mutations_allowed: bool,
        route_policy_mutation_allowed: bool,
        cloud_fallback_allowed: bool,
        subprocess_spawn_allowed: bool,
        seventy_b_probe_allowed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessSafetyError> {
        let lane = Self {
            lane_id: lane_id.into(),
            model_role: model_role.into(),
            catalog_ref: catalog_ref.into(),
            max_context_tokens,
            max_prompt_tokens,
            max_decode_tokens,
            memory_budget_bytes,
            runtime_budget_seconds,
            serialized_executor_ref: serialized_executor_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            rollback_ref: rollback_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            privacy_ref: privacy_ref.into(),
            dry_run_first,
            owner_approval_required,
            runtime_probe_enabled,
            mutations_allowed,
            route_policy_mutation_allowed,
            cloud_fallback_allowed,
            subprocess_spawn_allowed,
            seventy_b_probe_allowed,
        };
        validate_lane(&lane)?;
        Ok(lane)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-safety:surface
// Plane: State + Verification
// Residency: local documentation surface scan; no runtime bytes.
pub struct SmallModelHarnessSafetySurface {
    pub surface_id: String,
    pub path: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
    pub observed_text: String,
}

impl SmallModelHarnessSafetySurface {
    pub fn new(
        surface_id: impl Into<String>,
        path: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
        observed_text: impl Into<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessSafetyError> {
        let surface = Self {
            surface_id: surface_id.into(),
            path: path.into(),
            required_markers,
            forbidden_markers,
            observed_text: observed_text.into(),
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-safety:plan
// Plane: Controller + Verification
// Residency: metadata-only safety plan.
pub struct SmallModelRuntimeHarnessSafetyPlan {
    pub plan_id: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub stages: BTreeSet<SmallModelHarnessStage>,
    pub surfaces: Vec<SmallModelHarnessSafetySurface>,
    pub lanes: Vec<SmallModelHarnessLane>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
    pub gate_bypass: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback: bool,
    pub subprocess_spawn_attempted: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

impl SmallModelRuntimeHarnessSafetyPlan {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        plan_id: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        stages: BTreeSet<SmallModelHarnessStage>,
        surfaces: Vec<SmallModelHarnessSafetySurface>,
        lanes: Vec<SmallModelHarnessLane>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        hidden_route_authority: bool,
        route_policy_mutated: bool,
        gate_bypass: bool,
        answer_packet_suppressed: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_fallback: bool,
        subprocess_spawn_attempted: bool,
        autogenous_kernel_attempted: bool,
        seventy_b_probe_attempted: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        transport_runtime_bytes_loaded: u64,
    ) -> Result<Self, SmallModelRuntimeHarnessSafetyError> {
        let plan = Self {
            plan_id: plan_id.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            stages,
            surfaces,
            lanes,
            metadata_bytes,
            l1_l2_l3_separated,
            mas_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
            hidden_route_authority,
            route_policy_mutated,
            gate_bypass,
            answer_packet_suppressed,
            hidden_chain_exposed,
            hidden_cloud_fallback,
            subprocess_spawn_attempted,
            autogenous_kernel_attempted,
            seventy_b_probe_attempted,
            runtime_bytes_loaded,
            model_bytes_loaded,
            transport_runtime_bytes_loaded,
        };
        validate_plan(&plan)?;
        Ok(plan)
    }

    pub fn metrics(&self) -> SmallModelRuntimeHarnessSafetyMetrics {
        let lane_ids = self
            .lanes
            .iter()
            .map(|lane| lane.lane_id.as_str())
            .collect::<HashSet<_>>();
        SmallModelRuntimeHarnessSafetyMetrics {
            stage_count: self.stages.len() as u64,
            lane_count: self.lanes.len() as u64,
            surface_count: self.surfaces.len() as u64,
            required_lane_count: REQUIRED_LANES
                .iter()
                .filter(|id| lane_ids.contains(**id))
                .count() as u64,
            max_context_tokens: self
                .lanes
                .iter()
                .map(|lane| lane.max_context_tokens)
                .max()
                .unwrap_or(0),
            max_prompt_tokens: self
                .lanes
                .iter()
                .map(|lane| lane.max_prompt_tokens)
                .max()
                .unwrap_or(0),
            max_decode_tokens: self
                .lanes
                .iter()
                .map(|lane| lane.max_decode_tokens)
                .max()
                .unwrap_or(0),
            max_memory_budget_bytes: self
                .lanes
                .iter()
                .map(|lane| lane.memory_budget_bytes)
                .max()
                .unwrap_or(0),
            max_runtime_seconds: self
                .lanes
                .iter()
                .map(|lane| lane.runtime_budget_seconds)
                .max()
                .unwrap_or(0),
            runtime_probe_enabled_count: self
                .lanes
                .iter()
                .map(|lane| u64::from(lane.runtime_probe_enabled))
                .sum(),
            mutation_allowed_count: self
                .lanes
                .iter()
                .map(|lane| u64::from(lane.mutations_allowed))
                .sum(),
            cloud_fallback_allowed_count: self
                .lanes
                .iter()
                .map(|lane| u64::from(lane.cloud_fallback_allowed))
                .sum(),
            subprocess_spawn_allowed_count: self
                .lanes
                .iter()
                .map(|lane| u64::from(lane.subprocess_spawn_allowed))
                .sum(),
            seventy_b_probe_allowed_count: self
                .lanes
                .iter()
                .map(|lane| u64::from(lane.seventy_b_probe_allowed))
                .sum(),
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            model_bytes_loaded: self.model_bytes_loaded,
            transport_runtime_bytes_loaded: self.transport_runtime_bytes_loaded,
            metadata_bytes: self.metadata_bytes,
        }
    }

    pub fn address(&self) -> String {
        let mut lane_parts = self
            .lanes
            .iter()
            .map(|lane| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}",
                    lane.lane_id,
                    lane.model_role,
                    lane.catalog_ref,
                    lane.max_context_tokens,
                    lane.max_decode_tokens,
                    lane.serialized_executor_ref,
                    lane.answer_packet_ref
                )
            })
            .collect::<Vec<_>>();
        lane_parts.sort();
        let mut surface_parts = self
            .surfaces
            .iter()
            .map(|surface| format!("{}|{}", surface.surface_id, surface.path))
            .collect::<Vec<_>>();
        surface_parts.sort();
        let mut stage_parts = self
            .stages
            .iter()
            .map(SmallModelHarnessStage::tag)
            .collect::<Vec<_>>();
        stage_parts.sort();
        let preimage = format!(
            "{}|{}|{}|{}|{}|{}",
            self.plan_id,
            self.guard_next_existing_work,
            self.capability_route_status,
            lane_parts.join(";"),
            surface_parts.join(";"),
            stage_parts.join(";")
        );
        let digest = sha256_hex(preimage.as_bytes());
        format!("uas:small-model-runtime-harness-safety:sha256:{digest}")
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-safety:metrics
// Plane: Verification
// Residency: metadata-only safety metrics.
pub struct SmallModelRuntimeHarnessSafetyMetrics {
    pub stage_count: u64,
    pub lane_count: u64,
    pub surface_count: u64,
    pub required_lane_count: u64,
    pub max_context_tokens: u32,
    pub max_prompt_tokens: u32,
    pub max_decode_tokens: u32,
    pub max_memory_budget_bytes: u64,
    pub max_runtime_seconds: u32,
    pub runtime_probe_enabled_count: u64,
    pub mutation_allowed_count: u64,
    pub cloud_fallback_allowed_count: u64,
    pub subprocess_spawn_allowed_count: u64,
    pub seventy_b_probe_allowed_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

fn validate_plan(
    plan: &SmallModelRuntimeHarnessSafetyPlan,
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    validate_token("plan_id", &plan.plan_id)?;
    validate_token("guard_next_existing_work", &plan.guard_next_existing_work)?;
    validate_token("capability_route_status", &plan.capability_route_status)?;
    validate_token(
        "capability_next_bottleneck",
        &plan.capability_next_bottleneck,
    )?;
    validate_token("route_authority", &plan.route_authority)?;
    validate_prefixed("admission_ref", &plan.admission_ref, ADMISSION_PREFIX)
        .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingAdmission)?;
    validate_prefixed("scope_rex_ref", &plan.scope_rex_ref, SCOPE_REX_PREFIX)
        .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingScopeRex)?;
    validate_prefixed(
        "sovereign_gate_ref",
        &plan.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingSovereignGate)?;
    validate_prefixed(
        "compatibility_fence",
        &plan.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingCompatibilityFence)?;
    if plan.guard_next_existing_work != SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR
        && plan.guard_next_existing_work != SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessSafetyError::GuardCursorMismatch);
    }
    if plan.capability_next_bottleneck != SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR
        && plan.capability_next_bottleneck != SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessSafetyError::CapabilityStatusMismatch);
    }
    if plan.capability_route_status != "vault_research_route_with_packetized_mitigation" {
        return Err(SmallModelRuntimeHarnessSafetyError::CapabilityStatusMismatch);
    }
    if plan.product_build != ProductBuild::Pro || plan.pro_status != ProStatus::ResearchCandidate {
        return Err(SmallModelRuntimeHarnessSafetyError::ProductStatusMismatch);
    }
    if plan.route_authority != "small_model_runtime_harness_safety_plan_only" {
        return Err(SmallModelRuntimeHarnessSafetyError::ProductStatusMismatch);
    }
    if plan.stages.is_empty() {
        return Err(SmallModelRuntimeHarnessSafetyError::EmptyStage);
    }
    require_stage(plan, SmallModelHarnessStage::CatalogInventory)?;
    require_stage(plan, SmallModelHarnessStage::DryRunWitness)?;
    require_stage(plan, SmallModelHarnessStage::OwnerApprovalGate)?;
    require_stage(plan, SmallModelHarnessStage::AbortableRuntimeProbe)?;
    require_stage(plan, SmallModelHarnessStage::EvidenceReview)?;
    validate_surfaces(&plan.surfaces)?;
    validate_lanes(&plan.lanes)?;
    if !plan.l1_l2_l3_separated {
        return Err(SmallModelRuntimeHarnessSafetyError::MissingLayerSeparation);
    }
    if !plan.lanes.iter().all(|lane| lane.owner_approval_required) {
        return Err(SmallModelRuntimeHarnessSafetyError::OwnerApprovalMissing);
    }
    if !plan.lanes.iter().all(|lane| lane.dry_run_first) {
        return Err(SmallModelRuntimeHarnessSafetyError::DryRunFirstMissing);
    }
    if plan.lanes.iter().any(|lane| lane.runtime_probe_enabled) {
        let id = plan
            .lanes
            .iter()
            .find(|lane| lane.runtime_probe_enabled)
            .map(|lane| lane.lane_id.clone())
            .unwrap_or_else(|| "unknown".to_string());
        return Err(SmallModelRuntimeHarnessSafetyError::RuntimeProbeEnabledBeforeDryRun(id));
    }
    if plan.mas_overclaim_attempted {
        return Err(SmallModelRuntimeHarnessSafetyError::MasOverclaimAttempted);
    }
    if plan.l2_green_claimed {
        return Err(SmallModelRuntimeHarnessSafetyError::L2GreenClaimAttempted);
    }
    if plan.l3_green_claimed {
        return Err(SmallModelRuntimeHarnessSafetyError::L3GreenClaimAttempted);
    }
    if plan.hidden_route_authority {
        return Err(SmallModelRuntimeHarnessSafetyError::HiddenRouteAuthority);
    }
    if plan.route_policy_mutated {
        return Err(SmallModelRuntimeHarnessSafetyError::RoutePolicyMutation);
    }
    if plan.gate_bypass {
        return Err(SmallModelRuntimeHarnessSafetyError::GateBypass);
    }
    if plan.answer_packet_suppressed {
        return Err(SmallModelRuntimeHarnessSafetyError::AnswerPacketSuppression);
    }
    if plan.hidden_chain_exposed {
        return Err(SmallModelRuntimeHarnessSafetyError::HiddenChainExposure);
    }
    if plan.hidden_cloud_fallback {
        return Err(SmallModelRuntimeHarnessSafetyError::HiddenCloudFallback);
    }
    if plan.subprocess_spawn_attempted {
        return Err(SmallModelRuntimeHarnessSafetyError::SubprocessSpawn);
    }
    if plan.autogenous_kernel_attempted {
        return Err(SmallModelRuntimeHarnessSafetyError::AutogenousKernelAttempt);
    }
    if plan.seventy_b_probe_attempted {
        return Err(SmallModelRuntimeHarnessSafetyError::SeventyBProbeAttempt);
    }
    if plan.runtime_bytes_loaded > 0 {
        return Err(SmallModelRuntimeHarnessSafetyError::RuntimeBytesLoaded);
    }
    if plan.model_bytes_loaded > 0 {
        return Err(SmallModelRuntimeHarnessSafetyError::ModelBytesLoaded);
    }
    if plan.transport_runtime_bytes_loaded > 0 {
        return Err(SmallModelRuntimeHarnessSafetyError::TransportRuntimeBytesLoaded);
    }
    if plan.metadata_bytes > MAX_METADATA_BYTES {
        return Err(SmallModelRuntimeHarnessSafetyError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn require_stage(
    plan: &SmallModelRuntimeHarnessSafetyPlan,
    stage: SmallModelHarnessStage,
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    if plan.stages.contains(&stage) {
        return Ok(());
    }
    Err(SmallModelRuntimeHarnessSafetyError::MissingStage(
        stage.tag(),
    ))
}

fn validate_surfaces(
    surfaces: &[SmallModelHarnessSafetySurface],
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    if surfaces.is_empty() {
        return Err(SmallModelRuntimeHarnessSafetyError::EmptySurface);
    }
    let mut ids = HashSet::with_capacity(surfaces.len());
    for surface in surfaces {
        validate_surface(surface)?;
        if !ids.insert(surface.surface_id.as_str()) {
            return Err(SmallModelRuntimeHarnessSafetyError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(
    surface: &SmallModelHarnessSafetySurface,
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    validate_token("surface_id", &surface.surface_id)?;
    validate_path("path", &surface.path)?;
    if surface.observed_text.len() < MIN_SURFACE_TEXT_BYTES {
        return Err(SmallModelRuntimeHarnessSafetyError::MissingField(
            "observed_text",
        ));
    }
    for marker in &surface.required_markers {
        validate_marker(marker)?;
        if !surface.observed_text.contains(marker) {
            return Err(SmallModelRuntimeHarnessSafetyError::MissingRequiredMarker(
                marker.clone(),
            ));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_marker(marker)?;
        if surface.observed_text.contains(marker) {
            return Err(SmallModelRuntimeHarnessSafetyError::ForbiddenMarker(
                marker.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_lanes(
    lanes: &[SmallModelHarnessLane],
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    if lanes.is_empty() {
        return Err(SmallModelRuntimeHarnessSafetyError::EmptyLane);
    }
    let mut ids = HashSet::with_capacity(lanes.len());
    for lane in lanes {
        validate_lane(lane)?;
        if !ids.insert(lane.lane_id.as_str()) {
            return Err(SmallModelRuntimeHarnessSafetyError::DuplicateLane(
                lane.lane_id.clone(),
            ));
        }
    }
    for required in REQUIRED_LANES {
        if !ids.contains(required) {
            return Err(SmallModelRuntimeHarnessSafetyError::MissingRequiredLane(
                required,
            ));
        }
    }
    Ok(())
}

fn validate_lane(lane: &SmallModelHarnessLane) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    validate_token("lane_id", &lane.lane_id)?;
    validate_token("model_role", &lane.model_role)?;
    validate_prefixed("catalog_ref", &lane.catalog_ref, "model_catalog:")?;
    validate_prefixed(
        "serialized_executor_ref",
        &lane.serialized_executor_ref,
        SERIAL_EXECUTOR_PREFIX,
    )
    .map_err(|_| {
        SmallModelRuntimeHarnessSafetyError::MissingSerializedExecutor(lane.lane_id.clone())
    })?;
    validate_prefixed(
        "cancellation_ref",
        &lane.cancellation_ref,
        CANCELLATION_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingCancellation(lane.lane_id.clone()))?;
    validate_prefixed("rollback_ref", &lane.rollback_ref, ROLLBACK_PREFIX)
        .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingRollback(lane.lane_id.clone()))?;
    validate_prefixed(
        "answer_packet_ref",
        &lane.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingAnswerPacket(lane.lane_id.clone()))?;
    validate_prefixed(
        "run_event_log_ref",
        &lane.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessSafetyError::MissingRunEventLog)?;
    validate_prefixed("privacy_ref", &lane.privacy_ref, PRIVACY_PREFIX).map_err(|_| {
        SmallModelRuntimeHarnessSafetyError::MissingPrivacyFence(lane.lane_id.clone())
    })?;
    if lane.max_context_tokens == 0 || lane.max_context_tokens > MAX_CONTEXT_TOKENS {
        return Err(SmallModelRuntimeHarnessSafetyError::BudgetExceeded(
            "max_context_tokens",
        ));
    }
    if lane.max_prompt_tokens == 0
        || lane.max_prompt_tokens > MAX_PROMPT_TOKENS
        || lane.max_prompt_tokens > lane.max_context_tokens
    {
        return Err(SmallModelRuntimeHarnessSafetyError::BudgetExceeded(
            "max_prompt_tokens",
        ));
    }
    if lane.max_decode_tokens == 0 || lane.max_decode_tokens > MAX_DECODE_TOKENS {
        return Err(SmallModelRuntimeHarnessSafetyError::BudgetExceeded(
            "max_decode_tokens",
        ));
    }
    if lane.memory_budget_bytes == 0 || lane.memory_budget_bytes > MAX_MEMORY_BUDGET_BYTES {
        return Err(SmallModelRuntimeHarnessSafetyError::BudgetExceeded(
            "memory_budget_bytes",
        ));
    }
    if lane.runtime_budget_seconds == 0 || lane.runtime_budget_seconds > MAX_RUNTIME_SECONDS {
        return Err(SmallModelRuntimeHarnessSafetyError::BudgetExceeded(
            "runtime_budget_seconds",
        ));
    }
    if !lane.owner_approval_required {
        return Err(SmallModelRuntimeHarnessSafetyError::OwnerApprovalMissing);
    }
    if !lane.dry_run_first {
        return Err(SmallModelRuntimeHarnessSafetyError::DryRunFirstMissing);
    }
    if lane.runtime_probe_enabled {
        return Err(
            SmallModelRuntimeHarnessSafetyError::RuntimeProbeEnabledBeforeDryRun(
                lane.lane_id.clone(),
            ),
        );
    }
    if lane.mutations_allowed {
        return Err(SmallModelRuntimeHarnessSafetyError::RoutePolicyMutation);
    }
    if lane.route_policy_mutation_allowed {
        return Err(SmallModelRuntimeHarnessSafetyError::RoutePolicyMutation);
    }
    if lane.cloud_fallback_allowed {
        return Err(SmallModelRuntimeHarnessSafetyError::HiddenCloudFallback);
    }
    if lane.subprocess_spawn_allowed {
        return Err(SmallModelRuntimeHarnessSafetyError::SubprocessSpawn);
    }
    if lane.seventy_b_probe_allowed {
        return Err(SmallModelRuntimeHarnessSafetyError::SeventyBProbeAttempt);
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    if value.trim() != value {
        return Err(SmallModelRuntimeHarnessSafetyError::FieldHasSurroundingWhitespace(field));
    }
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessSafetyError::MissingField(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SmallModelRuntimeHarnessSafetyError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn validate_marker(value: &str) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    if value.trim() != value || value.is_empty() {
        return Err(SmallModelRuntimeHarnessSafetyError::MissingField("marker"));
    }
    if value.chars().any(char::is_control) {
        return Err(SmallModelRuntimeHarnessSafetyError::FieldContainsControlCharacter("marker"));
    }
    Ok(())
}

fn validate_path(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    validate_token(field, value)?;
    if value.starts_with('/') || value.contains("..") {
        return Err(SmallModelRuntimeHarnessSafetyError::MissingField(field));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelRuntimeHarnessSafetyError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelRuntimeHarnessSafetyError::MissingField(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lane(id: &str) -> SmallModelHarnessLane {
        SmallModelHarnessLane::new(
            id,
            "notes_research_coding",
            format!("model_catalog:{id}:mlx-small"),
            40960,
            4096,
            384,
            4 * 1024 * 1024 * 1024,
            180,
            format!("serialized_executor:{id}:mlx"),
            format!("cancel:{id}:owner-abort"),
            format!("rollback:{id}:no-state-mutation"),
            format!("answer_packet:{id}:harness-plan"),
            format!("run_event_log:{id}:harness-plan"),
            format!("privacy:{id}:local-only"),
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("valid lane")
    }

    fn surface() -> SmallModelHarnessSafetySurface {
        SmallModelHarnessSafetySurface::new(
            "living_index",
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR.to_string(),
            ],
            vec!["small model runtime is product-green".to_string()],
            format!(
                "Epistemos is a local cognitive substrate. {}. no claim promotes without visible proof. {}",
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR,
                "x".repeat(320)
            ),
        )
        .expect("valid surface")
    }

    fn plan_with_lanes(
        lanes: Vec<SmallModelHarnessLane>,
    ) -> Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError> {
        SmallModelRuntimeHarnessSafetyPlan::new(
            "small_model_runtime_harness_safety_plan_2026_06_05",
            SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "small_model_runtime_harness_safety_plan_only",
            "admission:scope-rex-sovereign-gate:small-model-harness",
            "scope_rex:small-model-harness",
            "sovereign_gate:small-model-harness",
            "compat:small-model-harness:v1",
            BTreeSet::from([
                SmallModelHarnessStage::CatalogInventory,
                SmallModelHarnessStage::DryRunWitness,
                SmallModelHarnessStage::OwnerApprovalGate,
                SmallModelHarnessStage::AbortableRuntimeProbe,
                SmallModelHarnessStage::EvidenceReview,
            ]),
            vec![surface()],
            lanes,
            96 * 1024,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            0,
        )
    }

    fn valid_plan() -> SmallModelRuntimeHarnessSafetyPlan {
        plan_with_lanes(vec![
            lane("qwen3_small_catalog_smoke"),
            lane("local_agent_notes_research_smoke"),
            lane("coding_tool_dry_run_smoke"),
        ])
        .expect("valid plan")
    }

    #[test]
    fn valid_plan_preserves_safety_before_runtime() {
        let plan = valid_plan();
        let metrics = plan.metrics();
        assert_eq!(metrics.required_lane_count, 3);
        assert_eq!(metrics.runtime_probe_enabled_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(plan
            .address()
            .starts_with("uas:small-model-runtime-harness-safety:sha256:"));
    }

    #[test]
    fn rejects_missing_duplicate_and_runtime_enabled_lanes() {
        assert!(matches!(
            plan_with_lanes(vec![lane("qwen3_small_catalog_smoke")]),
            Err(SmallModelRuntimeHarnessSafetyError::MissingRequiredLane(_))
        ));
        assert!(matches!(
            plan_with_lanes(vec![
                lane("qwen3_small_catalog_smoke"),
                lane("qwen3_small_catalog_smoke"),
                lane("coding_tool_dry_run_smoke")
            ]),
            Err(SmallModelRuntimeHarnessSafetyError::DuplicateLane(_))
        ));
        let mut runtime_lane = lane("qwen3_small_catalog_smoke");
        runtime_lane.runtime_probe_enabled = true;
        assert!(matches!(
            SmallModelHarnessLane::new(
                runtime_lane.lane_id,
                runtime_lane.model_role,
                runtime_lane.catalog_ref,
                runtime_lane.max_context_tokens,
                runtime_lane.max_prompt_tokens,
                runtime_lane.max_decode_tokens,
                runtime_lane.memory_budget_bytes,
                runtime_lane.runtime_budget_seconds,
                runtime_lane.serialized_executor_ref,
                runtime_lane.cancellation_ref,
                runtime_lane.rollback_ref,
                runtime_lane.answer_packet_ref,
                runtime_lane.run_event_log_ref,
                runtime_lane.privacy_ref,
                true,
                true,
                true,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(SmallModelRuntimeHarnessSafetyError::RuntimeProbeEnabledBeforeDryRun(_))
        ));
    }

    #[test]
    fn rejects_missing_refs_budgets_and_forbidden_authority() {
        assert!(matches!(
            SmallModelHarnessLane::new(
                "qwen3_small_catalog_smoke",
                "notes_research_coding",
                "model_catalog:qwen3:mlx-small",
                MAX_CONTEXT_TOKENS + 1,
                4096,
                384,
                4 * 1024 * 1024 * 1024,
                180,
                "serialized_executor:qwen3:mlx",
                "cancel:qwen3",
                "rollback:qwen3",
                "answer_packet:qwen3",
                "run_event_log:qwen3",
                "privacy:qwen3",
                true,
                true,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(SmallModelRuntimeHarnessSafetyError::BudgetExceeded(
                "max_context_tokens"
            ))
        ));
        assert!(matches!(
            SmallModelHarnessLane::new(
                "qwen3_small_catalog_smoke",
                "notes_research_coding",
                "model_catalog:qwen3:mlx-small",
                40960,
                4096,
                384,
                4 * 1024 * 1024 * 1024,
                180,
                "executor:qwen3",
                "cancel:qwen3",
                "rollback:qwen3",
                "answer_packet:qwen3",
                "run_event_log:qwen3",
                "privacy:qwen3",
                true,
                true,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(SmallModelRuntimeHarnessSafetyError::MissingSerializedExecutor(_))
        ));
        let mut plan = valid_plan();
        plan.hidden_route_authority = true;
        assert!(matches!(
            validate_plan(&plan),
            Err(SmallModelRuntimeHarnessSafetyError::HiddenRouteAuthority)
        ));
    }

    #[test]
    fn deterministic_address_ignores_lane_order() {
        let first = valid_plan();
        let mut reversed = first.lanes.clone();
        reversed.reverse();
        let second = plan_with_lanes(reversed).expect("valid reversed plan");
        assert_eq!(first.address(), second.address());
    }
}
