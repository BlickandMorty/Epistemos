//! Small-model runtime harness abortable runtime probe.
//!
//! This L1 witness sits at `small_model_runtime_harness_abortable_runtime_probe`.
//! It proves the owner-approved small-model smoke path can be cancelled before
//! runtime/model bytes are opened, with rollback, RunEventLog, AnswerPacket,
//! privacy, budget, and admission evidence bound. It is not an MLX runtime
//! success claim and does not promote L2/L3.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR: &str =
    "small_model_runtime_harness_abortable_runtime_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_logged_runtime_smoke";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const OWNER_PROBE_PREFIX: &str = "artifact:small_model_runtime_harness_owner_approved_probe:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const SERIAL_EXECUTOR_PREFIX: &str = "serialized_executor:";
const CANCELLATION_PREFIX: &str = "cancel:";
const DEADLINE_PREFIX: &str = "deadline:";
const PRIVACY_PREFIX: &str = "privacy:";
const PROMPT_ENVELOPE_PREFIX: &str = "prompt_envelope:";
const BUDGET_PREFIX: &str = "budget:";
const MODEL_CATALOG_PREFIX: &str = "model_catalog:";
const MODEL_SNAPSHOT_PREFIX: &str = "model_snapshot:local:";
const ABORT_REASON_PREFIX: &str = "abort_reason:";
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
const MAX_DEADLINE_MS: u32 = 1_000;
const MAX_OBSERVED_ELAPSED_MS: u32 = 1_000;
const MAX_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:phase
// Plane: Controller + Verification
// Residency: metadata-only abort-path probe phase.
pub enum SmallModelAbortableRuntimeProbePhase {
    OwnerProbeArtifactBound,
    LocalSnapshotPinned,
    PromptEnvelopeCompiled,
    AdmissionChecked,
    SerializedExecutorEntered,
    CancellationTokenArmed,
    DeadlineArmed,
    AbortSignalObserved,
    RuntimeStartSuppressed,
    RollbackVerified,
    RunEventLogged,
    AnswerPacketDrafted,
    EvidenceReviewPending,
}

impl SmallModelAbortableRuntimeProbePhase {
    fn tag(&self) -> &'static str {
        match self {
            Self::OwnerProbeArtifactBound => "owner_probe_artifact_bound",
            Self::LocalSnapshotPinned => "local_snapshot_pinned",
            Self::PromptEnvelopeCompiled => "prompt_envelope_compiled",
            Self::AdmissionChecked => "admission_checked",
            Self::SerializedExecutorEntered => "serialized_executor_entered",
            Self::CancellationTokenArmed => "cancellation_token_armed",
            Self::DeadlineArmed => "deadline_armed",
            Self::AbortSignalObserved => "abort_signal_observed",
            Self::RuntimeStartSuppressed => "runtime_start_suppressed",
            Self::RollbackVerified => "rollback_verified",
            Self::RunEventLogged => "run_event_logged",
            Self::AnswerPacketDrafted => "answer_packet_drafted",
            Self::EvidenceReviewPending => "evidence_review_pending",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:error
// Plane: Verification
// Residency: metadata-only abort-path rejection taxonomy.
pub enum SmallModelRuntimeHarnessAbortableProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyRun,
    EmptySurface,
    EmptyPhase,
    DuplicateRun(String),
    DuplicateSurface(String),
    MissingRequiredLane(&'static str),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingPhase(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingOwnerProbeArtifact(String),
    MissingModelCatalog(String),
    MissingModelSnapshot(String),
    MissingPromptEnvelope(String),
    MissingAdmission(String),
    MissingScopeRex(String),
    MissingSovereignGate(String),
    MissingCompatibilityFence(String),
    MissingSerializedExecutor(String),
    MissingCancellation(String),
    MissingDeadline(String),
    MissingAbortReason(String),
    MissingRollback(String),
    MissingRunEventLog(String),
    MissingAnswerPacket(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    MissingLayerSeparation,
    ProbeNotAttempted(String),
    CancellationNotArmed(String),
    AbortNotObserved(String),
    RuntimeStartNotSuppressed(String),
    RuntimeCompleted(String),
    ModelOpenAttempted(String),
    MutationCommitted(String),
    RoutePolicyMutation(String),
    GateBypass(String),
    AnswerPacketSuppression(String),
    HiddenRouteAuthority(String),
    HiddenChainExposure(String),
    HiddenCloudFallback(String),
    SubprocessSpawn(String),
    AutogenousKernelAttempt(String),
    SeventyBProbeAttempt(String),
    BudgetExceeded(&'static str),
    DeadlineExceeded(String),
    RuntimeBytesLoaded(String),
    ModelBytesLoaded(String),
    TransportRuntimeBytesLoaded(String),
    MasOverclaimAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelRuntimeHarnessAbortableProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyRun => write!(f, "missing abortable probe run"),
            Self::EmptySurface => write!(f, "missing abortable probe surface"),
            Self::EmptyPhase => write!(f, "missing abortable probe phase"),
            Self::DuplicateRun(id) => write!(f, "duplicate abortable probe run `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::MissingRequiredLane(id) => write!(f, "missing required lane `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingOwnerProbeArtifact(id) => {
                write!(f, "run `{id}` missing owner-probe artifact ref")
            }
            Self::MissingModelCatalog(id) => write!(f, "run `{id}` missing model catalog ref"),
            Self::MissingModelSnapshot(id) => write!(f, "run `{id}` missing model snapshot ref"),
            Self::MissingPromptEnvelope(id) => write!(f, "run `{id}` missing prompt envelope"),
            Self::MissingAdmission(id) => write!(f, "run `{id}` missing admission ref"),
            Self::MissingScopeRex(id) => write!(f, "run `{id}` missing SCOPE-Rex ref"),
            Self::MissingSovereignGate(id) => write!(f, "run `{id}` missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "run `{id}` missing compatibility fence")
            }
            Self::MissingSerializedExecutor(id) => {
                write!(f, "run `{id}` missing serialized executor")
            }
            Self::MissingCancellation(id) => write!(f, "run `{id}` missing cancellation ref"),
            Self::MissingDeadline(id) => write!(f, "run `{id}` missing deadline ref"),
            Self::MissingAbortReason(id) => write!(f, "run `{id}` missing abort reason"),
            Self::MissingRollback(id) => write!(f, "run `{id}` missing rollback ref"),
            Self::MissingRunEventLog(id) => write!(f, "run `{id}` missing RunEventLog"),
            Self::MissingAnswerPacket(id) => write!(f, "run `{id}` missing AnswerPacket"),
            Self::MissingPrivacyFence(id) => write!(f, "run `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "run `{id}` missing budget ref"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::ProbeNotAttempted(id) => write!(f, "run `{id}` did not attempt probe"),
            Self::CancellationNotArmed(id) => write!(f, "run `{id}` did not arm cancellation"),
            Self::AbortNotObserved(id) => write!(f, "run `{id}` did not observe abort"),
            Self::RuntimeStartNotSuppressed(id) => {
                write!(f, "run `{id}` did not suppress runtime start")
            }
            Self::RuntimeCompleted(id) => write!(f, "run `{id}` completed runtime"),
            Self::ModelOpenAttempted(id) => write!(f, "run `{id}` attempted model open"),
            Self::MutationCommitted(id) => write!(f, "run `{id}` committed mutation"),
            Self::RoutePolicyMutation(id) => write!(f, "run `{id}` attempted route mutation"),
            Self::GateBypass(id) => write!(f, "run `{id}` attempted gate bypass"),
            Self::AnswerPacketSuppression(id) => write!(f, "run `{id}` suppressed AnswerPacket"),
            Self::HiddenRouteAuthority(id) => write!(f, "run `{id}` attempted hidden authority"),
            Self::HiddenChainExposure(id) => write!(f, "run `{id}` exposed hidden chain"),
            Self::HiddenCloudFallback(id) => write!(f, "run `{id}` allowed hidden cloud"),
            Self::SubprocessSpawn(id) => write!(f, "run `{id}` spawned subprocess"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "run `{id}` attempted autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "run `{id}` attempted 70B probe"),
            Self::BudgetExceeded(budget) => write!(f, "budget `{budget}` exceeded"),
            Self::DeadlineExceeded(id) => write!(f, "run `{id}` exceeded deadline"),
            Self::RuntimeBytesLoaded(id) => write!(f, "run `{id}` loaded runtime bytes"),
            Self::ModelBytesLoaded(id) => write!(f, "run `{id}` loaded model bytes"),
            Self::TransportRuntimeBytesLoaded(id) => {
                write!(f, "run `{id}` loaded transport runtime bytes")
            }
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelRuntimeHarnessAbortableProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:surface
// Plane: State + Verification
// Residency: local documentation surface scan; no runtime bytes.
pub struct SmallModelAbortableRuntimeProbeSurface {
    pub surface_id: String,
    pub path: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
    pub observed_text: String,
}

impl SmallModelAbortableRuntimeProbeSurface {
    pub fn new(
        surface_id: impl Into<String>,
        path: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
        observed_text: impl Into<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessAbortableProbeError> {
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
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:run
// Plane: Controller + Verification
// Residency: metadata-only abortable runtime probe run.
pub struct SmallModelAbortableRuntimeProbeRun {
    pub run_id: String,
    pub lane_id: String,
    pub model_role: String,
    pub owner_probe_artifact_ref: String,
    pub model_catalog_ref: String,
    pub model_snapshot_ref: String,
    pub prompt_envelope_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub serialized_executor_ref: String,
    pub cancellation_ref: String,
    pub deadline_ref: String,
    pub abort_reason_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub phases: BTreeSet<SmallModelAbortableRuntimeProbePhase>,
    pub max_context_tokens: u32,
    pub prompt_tokens: u32,
    pub max_decode_tokens: u32,
    pub memory_budget_bytes: u64,
    pub runtime_budget_seconds: u32,
    pub deadline_ms: u32,
    pub observed_elapsed_ms: u32,
    pub probe_attempted: bool,
    pub cancellation_armed: bool,
    pub abort_signal_observed: bool,
    pub runtime_start_suppressed: bool,
    pub runtime_completed: bool,
    pub model_open_attempted: bool,
    pub mutation_committed: bool,
    pub route_policy_mutated: bool,
    pub gate_bypass: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_route_authority: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback: bool,
    pub subprocess_spawned: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

impl SmallModelAbortableRuntimeProbeRun {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        lane_id: impl Into<String>,
        model_role: impl Into<String>,
        owner_probe_artifact_ref: impl Into<String>,
        model_catalog_ref: impl Into<String>,
        model_snapshot_ref: impl Into<String>,
        prompt_envelope_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        serialized_executor_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        deadline_ref: impl Into<String>,
        abort_reason_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        privacy_ref: impl Into<String>,
        budget_ref: impl Into<String>,
        phases: BTreeSet<SmallModelAbortableRuntimeProbePhase>,
        max_context_tokens: u32,
        prompt_tokens: u32,
        max_decode_tokens: u32,
        memory_budget_bytes: u64,
        runtime_budget_seconds: u32,
        deadline_ms: u32,
        observed_elapsed_ms: u32,
        probe_attempted: bool,
        cancellation_armed: bool,
        abort_signal_observed: bool,
        runtime_start_suppressed: bool,
        runtime_completed: bool,
        model_open_attempted: bool,
        mutation_committed: bool,
        route_policy_mutated: bool,
        gate_bypass: bool,
        answer_packet_suppressed: bool,
        hidden_route_authority: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_fallback: bool,
        subprocess_spawned: bool,
        autogenous_kernel_attempted: bool,
        seventy_b_probe_attempted: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        transport_runtime_bytes_loaded: u64,
    ) -> Result<Self, SmallModelRuntimeHarnessAbortableProbeError> {
        let run = Self {
            run_id: run_id.into(),
            lane_id: lane_id.into(),
            model_role: model_role.into(),
            owner_probe_artifact_ref: owner_probe_artifact_ref.into(),
            model_catalog_ref: model_catalog_ref.into(),
            model_snapshot_ref: model_snapshot_ref.into(),
            prompt_envelope_ref: prompt_envelope_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            serialized_executor_ref: serialized_executor_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            deadline_ref: deadline_ref.into(),
            abort_reason_ref: abort_reason_ref.into(),
            rollback_ref: rollback_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            privacy_ref: privacy_ref.into(),
            budget_ref: budget_ref.into(),
            phases,
            max_context_tokens,
            prompt_tokens,
            max_decode_tokens,
            memory_budget_bytes,
            runtime_budget_seconds,
            deadline_ms,
            observed_elapsed_ms,
            probe_attempted,
            cancellation_armed,
            abort_signal_observed,
            runtime_start_suppressed,
            runtime_completed,
            model_open_attempted,
            mutation_committed,
            route_policy_mutated,
            gate_bypass,
            answer_packet_suppressed,
            hidden_route_authority,
            hidden_chain_exposed,
            hidden_cloud_fallback,
            subprocess_spawned,
            autogenous_kernel_attempted,
            seventy_b_probe_attempted,
            runtime_bytes_loaded,
            model_bytes_loaded,
            transport_runtime_bytes_loaded,
        };
        validate_run(&run)?;
        Ok(run)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:metrics
// Plane: Verification
// Residency: metadata-only abort-path metric rollup.
pub struct SmallModelRuntimeHarnessAbortableProbeMetrics {
    pub run_count: u64,
    pub surface_count: u64,
    pub required_lane_count: u64,
    pub phase_count: u64,
    pub probe_attempted_count: u64,
    pub cancellation_armed_count: u64,
    pub abort_observed_count: u64,
    pub runtime_start_suppressed_count: u64,
    pub runtime_completed_count: u64,
    pub model_open_attempted_count: u64,
    pub mutation_committed_count: u64,
    pub cloud_fallback_count: u64,
    pub subprocess_spawn_count: u64,
    pub seventy_b_probe_count: u64,
    pub max_context_tokens: u64,
    pub max_prompt_tokens: u64,
    pub max_decode_tokens: u64,
    pub max_memory_budget_bytes: u64,
    pub max_runtime_seconds: u64,
    pub max_deadline_ms: u64,
    pub max_observed_elapsed_ms: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:witness
// Plane: Controller + Verification
// Residency: metadata-only abortable runtime probe witness.
pub struct SmallModelRuntimeHarnessAbortableProbeWitness {
    pub witness_id: String,
    pub owner_probe_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub runs: Vec<SmallModelAbortableRuntimeProbeRun>,
    pub surfaces: Vec<SmallModelAbortableRuntimeProbeSurface>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
}

impl SmallModelRuntimeHarnessAbortableProbeWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        owner_probe_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        runs: Vec<SmallModelAbortableRuntimeProbeRun>,
        surfaces: Vec<SmallModelAbortableRuntimeProbeSurface>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessAbortableProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            owner_probe_artifact_ref: owner_probe_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            runs,
            surfaces,
            metadata_bytes,
            l1_l2_l3_separated,
            mas_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> SmallModelRuntimeHarnessAbortableProbeMetrics {
        let mut lanes = HashSet::new();
        let mut phases = BTreeSet::new();
        let mut metrics = SmallModelRuntimeHarnessAbortableProbeMetrics {
            run_count: self.runs.len() as u64,
            surface_count: self.surfaces.len() as u64,
            required_lane_count: 0,
            phase_count: 0,
            probe_attempted_count: 0,
            cancellation_armed_count: 0,
            abort_observed_count: 0,
            runtime_start_suppressed_count: 0,
            runtime_completed_count: 0,
            model_open_attempted_count: 0,
            mutation_committed_count: 0,
            cloud_fallback_count: 0,
            subprocess_spawn_count: 0,
            seventy_b_probe_count: 0,
            max_context_tokens: 0,
            max_prompt_tokens: 0,
            max_decode_tokens: 0,
            max_memory_budget_bytes: 0,
            max_runtime_seconds: 0,
            max_deadline_ms: 0,
            max_observed_elapsed_ms: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            transport_runtime_bytes_loaded: 0,
        };

        for run in &self.runs {
            lanes.insert(run.lane_id.as_str());
            phases.extend(run.phases.iter().cloned());
            metrics.probe_attempted_count += u64::from(run.probe_attempted);
            metrics.cancellation_armed_count += u64::from(run.cancellation_armed);
            metrics.abort_observed_count += u64::from(run.abort_signal_observed);
            metrics.runtime_start_suppressed_count += u64::from(run.runtime_start_suppressed);
            metrics.runtime_completed_count += u64::from(run.runtime_completed);
            metrics.model_open_attempted_count += u64::from(run.model_open_attempted);
            metrics.mutation_committed_count += u64::from(run.mutation_committed);
            metrics.cloud_fallback_count += u64::from(run.hidden_cloud_fallback);
            metrics.subprocess_spawn_count += u64::from(run.subprocess_spawned);
            metrics.seventy_b_probe_count += u64::from(run.seventy_b_probe_attempted);
            metrics.max_context_tokens = metrics
                .max_context_tokens
                .max(run.max_context_tokens as u64);
            metrics.max_prompt_tokens = metrics.max_prompt_tokens.max(run.prompt_tokens as u64);
            metrics.max_decode_tokens = metrics.max_decode_tokens.max(run.max_decode_tokens as u64);
            metrics.max_memory_budget_bytes =
                metrics.max_memory_budget_bytes.max(run.memory_budget_bytes);
            metrics.max_runtime_seconds = metrics
                .max_runtime_seconds
                .max(run.runtime_budget_seconds as u64);
            metrics.max_deadline_ms = metrics.max_deadline_ms.max(run.deadline_ms as u64);
            metrics.max_observed_elapsed_ms = metrics
                .max_observed_elapsed_ms
                .max(run.observed_elapsed_ms as u64);
            metrics.runtime_bytes_loaded = metrics
                .runtime_bytes_loaded
                .saturating_add(run.runtime_bytes_loaded);
            metrics.model_bytes_loaded = metrics
                .model_bytes_loaded
                .saturating_add(run.model_bytes_loaded);
            metrics.transport_runtime_bytes_loaded = metrics
                .transport_runtime_bytes_loaded
                .saturating_add(run.transport_runtime_bytes_loaded);
        }
        metrics.required_lane_count = REQUIRED_LANES
            .iter()
            .filter(|lane| lanes.contains(**lane))
            .count() as u64;
        metrics.phase_count = phases.len() as u64;
        metrics
    }

    pub fn address(&self) -> String {
        let mut runs = self
            .runs
            .iter()
            .map(|run| {
                let phases: Vec<&str> = run
                    .phases
                    .iter()
                    .map(SmallModelAbortableRuntimeProbePhase::tag)
                    .collect();
                serde_json::json!({
                    "run_id": run.run_id,
                    "lane_id": run.lane_id,
                    "owner_probe_artifact_ref": run.owner_probe_artifact_ref,
                    "model_catalog_ref": run.model_catalog_ref,
                    "model_snapshot_ref": run.model_snapshot_ref,
                    "phases": phases,
                    "deadline_ms": run.deadline_ms,
                    "observed_elapsed_ms": run.observed_elapsed_ms,
                    "probe_attempted": run.probe_attempted,
                    "cancellation_armed": run.cancellation_armed,
                    "abort_signal_observed": run.abort_signal_observed,
                    "runtime_start_suppressed": run.runtime_start_suppressed,
                    "runtime_completed": run.runtime_completed,
                    "model_open_attempted": run.model_open_attempted,
                    "runtime_bytes_loaded": run.runtime_bytes_loaded,
                    "model_bytes_loaded": run.model_bytes_loaded,
                    "transport_runtime_bytes_loaded": run.transport_runtime_bytes_loaded,
                })
            })
            .collect::<Vec<_>>();
        runs.sort_by(|a, b| {
            a["run_id"]
                .as_str()
                .unwrap_or_default()
                .cmp(b["run_id"].as_str().unwrap_or_default())
        });
        let surfaces = self
            .surfaces
            .iter()
            .map(|surface| {
                serde_json::json!({
                    "surface_id": surface.surface_id,
                    "path": surface.path,
                    "observed_digest": sha256_hex(surface.observed_text.as_bytes()),
                })
            })
            .collect::<Vec<_>>();
        let payload = serde_json::json!({
            "witness_id": self.witness_id,
            "owner_probe_artifact_ref": self.owner_probe_artifact_ref,
            "route_authority": self.route_authority,
            "runs": runs,
            "surfaces": surfaces,
            "metadata_bytes": self.metadata_bytes,
        });
        let bytes = serde_json::to_vec(&payload).unwrap_or_default();
        sha256_hex(&bytes)
    }
}

fn validate_witness(
    witness: &SmallModelRuntimeHarnessAbortableProbeWitness,
) -> Result<(), SmallModelRuntimeHarnessAbortableProbeError> {
    validate_clean("witness_id", &witness.witness_id)?;
    validate_clean(
        "owner_probe_artifact_ref",
        &witness.owner_probe_artifact_ref,
    )?;
    validate_clean(
        "guard_next_existing_work",
        &witness.guard_next_existing_work,
    )?;
    validate_clean("capability_route_status", &witness.capability_route_status)?;
    validate_clean(
        "capability_next_bottleneck",
        &witness.capability_next_bottleneck,
    )?;
    validate_clean("route_authority", &witness.route_authority)?;
    validate_prefix(
        &witness.owner_probe_artifact_ref,
        OWNER_PROBE_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingOwnerProbeArtifact(
            "witness".to_string(),
        ),
    )?;
    if witness.guard_next_existing_work
        != SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR
        && witness.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR
        && witness.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::GuardCursorMismatch);
    }
    if witness.capability_route_status != "vault_research_route_with_packetized_mitigation" {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::CapabilityStatusMismatch);
    }
    if witness.capability_next_bottleneck
        != SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR
        && witness.capability_next_bottleneck
            != SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR
        && witness.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::CapabilityStatusMismatch);
    }
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "small_model_runtime_harness_abortable_probe_only"
    {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::ProductStatusMismatch);
    }
    if witness.runs.is_empty() {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::EmptyRun);
    }
    if witness.surfaces.is_empty() {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::EmptySurface);
    }
    let mut run_ids = HashSet::with_capacity(witness.runs.len());
    let mut lane_ids = HashSet::with_capacity(witness.runs.len());
    for run in &witness.runs {
        validate_run(run)?;
        if !run_ids.insert(run.run_id.as_str()) {
            return Err(SmallModelRuntimeHarnessAbortableProbeError::DuplicateRun(
                run.run_id.clone(),
            ));
        }
        lane_ids.insert(run.lane_id.as_str());
    }
    for required_lane in REQUIRED_LANES {
        if !lane_ids.contains(required_lane) {
            return Err(
                SmallModelRuntimeHarnessAbortableProbeError::MissingRequiredLane(required_lane),
            );
        }
    }
    let mut surface_ids = HashSet::with_capacity(witness.surfaces.len());
    for surface in &witness.surfaces {
        if !surface_ids.insert(surface.surface_id.as_str()) {
            return Err(
                SmallModelRuntimeHarnessAbortableProbeError::DuplicateSurface(
                    surface.surface_id.clone(),
                ),
            );
        }
    }
    if witness.metadata_bytes > MAX_METADATA_BYTES {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::MetadataBudgetExceeded);
    }
    if !witness.l1_l2_l3_separated {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::MissingLayerSeparation);
    }
    if witness.mas_overclaim_attempted {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::MasOverclaimAttempted);
    }
    if witness.l2_green_claimed {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::L2GreenClaimAttempted);
    }
    if witness.l3_green_claimed {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::L3GreenClaimAttempted);
    }
    Ok(())
}

fn validate_surface(
    surface: &SmallModelAbortableRuntimeProbeSurface,
) -> Result<(), SmallModelRuntimeHarnessAbortableProbeError> {
    validate_clean("surface_id", &surface.surface_id)?;
    validate_clean("path", &surface.path)?;
    if surface.observed_text.trim().len() < MIN_SURFACE_TEXT_BYTES {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::EmptySurface);
    }
    for marker in &surface.required_markers {
        validate_clean("required_marker", marker)?;
        if !surface.observed_text.contains(marker) {
            return Err(
                SmallModelRuntimeHarnessAbortableProbeError::MissingRequiredMarker(marker.clone()),
            );
        }
    }
    for marker in &surface.forbidden_markers {
        validate_clean("forbidden_marker", marker)?;
        if surface.observed_text.contains(marker) {
            return Err(
                SmallModelRuntimeHarnessAbortableProbeError::ForbiddenMarker(marker.clone()),
            );
        }
    }
    Ok(())
}

fn validate_run(
    run: &SmallModelAbortableRuntimeProbeRun,
) -> Result<(), SmallModelRuntimeHarnessAbortableProbeError> {
    validate_clean("run_id", &run.run_id)?;
    validate_clean("lane_id", &run.lane_id)?;
    validate_clean("model_role", &run.model_role)?;
    validate_clean("owner_probe_artifact_ref", &run.owner_probe_artifact_ref)?;
    validate_clean("model_catalog_ref", &run.model_catalog_ref)?;
    validate_clean("model_snapshot_ref", &run.model_snapshot_ref)?;
    validate_clean("prompt_envelope_ref", &run.prompt_envelope_ref)?;
    validate_clean("admission_ref", &run.admission_ref)?;
    validate_clean("scope_rex_ref", &run.scope_rex_ref)?;
    validate_clean("sovereign_gate_ref", &run.sovereign_gate_ref)?;
    validate_clean("compatibility_fence", &run.compatibility_fence)?;
    validate_clean("serialized_executor_ref", &run.serialized_executor_ref)?;
    validate_clean("cancellation_ref", &run.cancellation_ref)?;
    validate_clean("deadline_ref", &run.deadline_ref)?;
    validate_clean("abort_reason_ref", &run.abort_reason_ref)?;
    validate_clean("rollback_ref", &run.rollback_ref)?;
    validate_clean("run_event_log_ref", &run.run_event_log_ref)?;
    validate_clean("answer_packet_ref", &run.answer_packet_ref)?;
    validate_clean("privacy_ref", &run.privacy_ref)?;
    validate_clean("budget_ref", &run.budget_ref)?;

    let id = run.run_id.clone();
    validate_prefix(
        &run.owner_probe_artifact_ref,
        OWNER_PROBE_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingOwnerProbeArtifact(id.clone()),
    )?;
    validate_prefix(
        &run.model_catalog_ref,
        MODEL_CATALOG_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingModelCatalog(id.clone()),
    )?;
    validate_prefix(
        &run.model_snapshot_ref,
        MODEL_SNAPSHOT_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingModelSnapshot(id.clone()),
    )?;
    validate_prefix(
        &run.prompt_envelope_ref,
        PROMPT_ENVELOPE_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingPromptEnvelope(id.clone()),
    )?;
    validate_prefix(
        &run.admission_ref,
        ADMISSION_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingAdmission(id.clone()),
    )?;
    validate_prefix(
        &run.scope_rex_ref,
        SCOPE_REX_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingScopeRex(id.clone()),
    )?;
    validate_prefix(
        &run.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingSovereignGate(id.clone()),
    )?;
    validate_prefix(
        &run.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingCompatibilityFence(id.clone()),
    )?;
    validate_prefix(
        &run.serialized_executor_ref,
        SERIAL_EXECUTOR_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingSerializedExecutor(id.clone()),
    )?;
    validate_prefix(
        &run.cancellation_ref,
        CANCELLATION_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingCancellation(id.clone()),
    )?;
    validate_prefix(
        &run.deadline_ref,
        DEADLINE_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingDeadline(id.clone()),
    )?;
    validate_prefix(
        &run.abort_reason_ref,
        ABORT_REASON_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingAbortReason(id.clone()),
    )?;
    validate_prefix(
        &run.rollback_ref,
        ROLLBACK_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingRollback(id.clone()),
    )?;
    validate_prefix(
        &run.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingRunEventLog(id.clone()),
    )?;
    validate_prefix(
        &run.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingAnswerPacket(id.clone()),
    )?;
    validate_prefix(
        &run.privacy_ref,
        PRIVACY_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingPrivacyFence(id.clone()),
    )?;
    validate_prefix(
        &run.budget_ref,
        BUDGET_PREFIX,
        SmallModelRuntimeHarnessAbortableProbeError::MissingBudget(id.clone()),
    )?;
    if run.phases.is_empty() {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::EmptyPhase);
    }
    for phase in required_phases() {
        if !run.phases.contains(&phase) {
            return Err(SmallModelRuntimeHarnessAbortableProbeError::MissingPhase(
                phase.tag(),
            ));
        }
    }
    if !run.probe_attempted {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::ProbeNotAttempted(id));
    }
    if !run.cancellation_armed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::CancellationNotArmed(run.run_id.clone()),
        );
    }
    if !run.abort_signal_observed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::AbortNotObserved(run.run_id.clone()),
        );
    }
    if !run.runtime_start_suppressed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::RuntimeStartNotSuppressed(
                run.run_id.clone(),
            ),
        );
    }
    if run.runtime_completed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::RuntimeCompleted(run.run_id.clone()),
        );
    }
    if run.model_open_attempted {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::ModelOpenAttempted(run.run_id.clone()),
        );
    }
    if run.mutation_committed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::MutationCommitted(run.run_id.clone()),
        );
    }
    if run.route_policy_mutated {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::RoutePolicyMutation(run.run_id.clone()),
        );
    }
    if run.gate_bypass {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::GateBypass(
            run.run_id.clone(),
        ));
    }
    if run.answer_packet_suppressed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::AnswerPacketSuppression(
                run.run_id.clone(),
            ),
        );
    }
    if run.hidden_route_authority {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::HiddenRouteAuthority(run.run_id.clone()),
        );
    }
    if run.hidden_chain_exposed {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::HiddenChainExposure(run.run_id.clone()),
        );
    }
    if run.hidden_cloud_fallback {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::HiddenCloudFallback(run.run_id.clone()),
        );
    }
    if run.subprocess_spawned {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::SubprocessSpawn(run.run_id.clone()),
        );
    }
    if run.autogenous_kernel_attempted {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::AutogenousKernelAttempt(
                run.run_id.clone(),
            ),
        );
    }
    if run.seventy_b_probe_attempted {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::SeventyBProbeAttempt(run.run_id.clone()),
        );
    }
    if run.max_context_tokens > MAX_CONTEXT_TOKENS {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::BudgetExceeded(
            "context_tokens",
        ));
    }
    if run.prompt_tokens > MAX_PROMPT_TOKENS {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::BudgetExceeded(
            "prompt_tokens",
        ));
    }
    if run.max_decode_tokens > MAX_DECODE_TOKENS {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::BudgetExceeded(
            "decode_tokens",
        ));
    }
    if run.memory_budget_bytes > MAX_MEMORY_BUDGET_BYTES {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::BudgetExceeded(
            "memory_budget_bytes",
        ));
    }
    if run.runtime_budget_seconds > MAX_RUNTIME_SECONDS {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::BudgetExceeded(
            "runtime_seconds",
        ));
    }
    if run.deadline_ms > MAX_DEADLINE_MS || run.observed_elapsed_ms > MAX_OBSERVED_ELAPSED_MS {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::DeadlineExceeded(run.run_id.clone()),
        );
    }
    if run.observed_elapsed_ms > run.deadline_ms {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::DeadlineExceeded(run.run_id.clone()),
        );
    }
    if run.runtime_bytes_loaded != 0 {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::RuntimeBytesLoaded(run.run_id.clone()),
        );
    }
    if run.model_bytes_loaded != 0 {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::ModelBytesLoaded(run.run_id.clone()),
        );
    }
    if run.transport_runtime_bytes_loaded != 0 {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::TransportRuntimeBytesLoaded(
                run.run_id.clone(),
            ),
        );
    }
    Ok(())
}

fn required_phases() -> BTreeSet<SmallModelAbortableRuntimeProbePhase> {
    [
        SmallModelAbortableRuntimeProbePhase::OwnerProbeArtifactBound,
        SmallModelAbortableRuntimeProbePhase::LocalSnapshotPinned,
        SmallModelAbortableRuntimeProbePhase::PromptEnvelopeCompiled,
        SmallModelAbortableRuntimeProbePhase::AdmissionChecked,
        SmallModelAbortableRuntimeProbePhase::SerializedExecutorEntered,
        SmallModelAbortableRuntimeProbePhase::CancellationTokenArmed,
        SmallModelAbortableRuntimeProbePhase::DeadlineArmed,
        SmallModelAbortableRuntimeProbePhase::AbortSignalObserved,
        SmallModelAbortableRuntimeProbePhase::RuntimeStartSuppressed,
        SmallModelAbortableRuntimeProbePhase::RollbackVerified,
        SmallModelAbortableRuntimeProbePhase::RunEventLogged,
        SmallModelAbortableRuntimeProbePhase::AnswerPacketDrafted,
        SmallModelAbortableRuntimeProbePhase::EvidenceReviewPending,
    ]
    .into_iter()
    .collect()
}

fn validate_prefix(
    value: &str,
    prefix: &str,
    error: SmallModelRuntimeHarnessAbortableProbeError,
) -> Result<(), SmallModelRuntimeHarnessAbortableProbeError> {
    if value.starts_with(prefix) {
        Ok(())
    } else {
        Err(error)
    }
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessAbortableProbeError> {
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessAbortableProbeError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(
            SmallModelRuntimeHarnessAbortableProbeError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(id: &str, lane: &str) -> SmallModelAbortableRuntimeProbeRun {
        SmallModelAbortableRuntimeProbeRun::new(
            id,
            lane,
            "notes_research",
            "artifact:small_model_runtime_harness_owner_approved_probe:result",
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:52a5ab",
            format!("prompt_envelope:{lane}"),
            format!("admission:{lane}"),
            format!("scope_rex:{lane}"),
            format!("sovereign_gate:{lane}"),
            format!("compat:{lane}:mlx-small-smoke-v1"),
            format!("serialized_executor:{lane}:single-flight"),
            format!("cancel:{lane}:abort-token"),
            format!("deadline:{lane}:pre-runtime-100ms"),
            format!("abort_reason:{lane}:owner-cancel-pre-runtime"),
            format!("rollback:{lane}:no-mutation"),
            format!("run_event_log:{lane}:abortable-probe"),
            format!("answer_packet:{lane}:visible-abort"),
            format!("privacy:{lane}:local-only-no-cloud"),
            format!("budget:{lane}:small-smoke"),
            required_phases(),
            4096,
            512,
            128,
            2 * 1024 * 1024 * 1024,
            60,
            100,
            37,
            true,
            true,
            true,
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
        .unwrap()
    }

    fn surface(id: &str) -> SmallModelAbortableRuntimeProbeSurface {
        SmallModelAbortableRuntimeProbeSurface::new(
            id,
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR.to_string(),
                "vault_research_route_with_packetized_mitigation".to_string(),
            ],
            vec!["small model runtime is product-live".to_string()],
            format!(
                "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness. {} vault_research_route_with_packetized_mitigation no claim promotes without visible proof. {}",
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR,
                "x".repeat(260)
            ),
        )
        .unwrap()
    }

    fn witness() -> SmallModelRuntimeHarnessAbortableProbeWitness {
        SmallModelRuntimeHarnessAbortableProbeWitness::new(
            "abortable_probe_witness",
            "artifact:small_model_runtime_harness_owner_approved_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "small_model_runtime_harness_abortable_probe_only",
            vec![
                run("run_a", "qwen3_small_catalog_smoke"),
                run("run_b", "local_agent_notes_research_smoke"),
                run("run_c", "coding_tool_dry_run_smoke"),
            ],
            vec![surface("living_index"), surface("lattice_html")],
            12_000,
            true,
            false,
            false,
            false,
        )
        .unwrap()
    }

    #[test]
    fn deterministic_address_and_metrics() {
        let witness = witness();
        let metrics = witness.metrics();
        assert_eq!(metrics.required_lane_count, 3);
        assert_eq!(metrics.abort_observed_count, 3);
        assert_eq!(metrics.runtime_start_suppressed_count, 3);
        let address = witness.address();
        let mut reversed = witness.runs.clone();
        reversed.reverse();
        let reversed = SmallModelRuntimeHarnessAbortableProbeWitness::new(
            witness.witness_id,
            witness.owner_probe_artifact_ref,
            witness.guard_next_existing_work,
            witness.capability_route_status,
            witness.capability_next_bottleneck,
            witness.product_build,
            witness.pro_status,
            witness.route_authority,
            reversed,
            witness.surfaces,
            witness.metadata_bytes,
            witness.l1_l2_l3_separated,
            witness.mas_overclaim_attempted,
            witness.l2_green_claimed,
            witness.l3_green_claimed,
        )
        .unwrap();
        assert_eq!(address, reversed.address());
    }

    #[test]
    fn duplicate_run_is_rejected() {
        let mut witness = witness();
        witness.runs[1] = witness.runs[0].clone();
        assert!(matches!(
            SmallModelRuntimeHarnessAbortableProbeWitness::new(
                witness.witness_id,
                witness.owner_probe_artifact_ref,
                witness.guard_next_existing_work,
                witness.capability_route_status,
                witness.capability_next_bottleneck,
                witness.product_build,
                witness.pro_status,
                witness.route_authority,
                witness.runs,
                witness.surfaces,
                witness.metadata_bytes,
                witness.l1_l2_l3_separated,
                witness.mas_overclaim_attempted,
                witness.l2_green_claimed,
                witness.l3_green_claimed,
            )
            .unwrap_err(),
            SmallModelRuntimeHarnessAbortableProbeError::DuplicateRun(_)
        ));
    }

    #[test]
    fn missing_abort_is_rejected() {
        let mut bad = run("bad", "qwen3_small_catalog_smoke");
        bad.abort_signal_observed = false;
        assert!(matches!(
            validate_run(&bad).unwrap_err(),
            SmallModelRuntimeHarnessAbortableProbeError::AbortNotObserved(_)
        ));
    }

    #[test]
    fn runtime_completion_is_rejected() {
        let mut bad = run("bad", "qwen3_small_catalog_smoke");
        bad.runtime_completed = true;
        assert!(matches!(
            validate_run(&bad).unwrap_err(),
            SmallModelRuntimeHarnessAbortableProbeError::RuntimeCompleted(_)
        ));
    }

    #[test]
    fn runtime_bytes_are_rejected() {
        let mut bad = run("bad", "qwen3_small_catalog_smoke");
        bad.runtime_bytes_loaded = 1;
        assert!(matches!(
            validate_run(&bad).unwrap_err(),
            SmallModelRuntimeHarnessAbortableProbeError::RuntimeBytesLoaded(_)
        ));
    }

    #[test]
    fn deadline_overrun_is_rejected() {
        let mut bad = run("bad", "qwen3_small_catalog_smoke");
        bad.observed_elapsed_ms = bad.deadline_ms + 1;
        assert!(matches!(
            validate_run(&bad).unwrap_err(),
            SmallModelRuntimeHarnessAbortableProbeError::DeadlineExceeded(_)
        ));
    }
}
