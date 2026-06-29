//! Small-model runtime harness logged runtime smoke.
//!
//! This L1 witness sits at `small_model_runtime_harness_logged_runtime_smoke`.
//! It proves the owner-approved/abortable small-model smoke path reaches the
//! runtime harness logging layer, records missing local snapshots visibly, and
//! rolls back without opening model bytes, mutating route policy, or promoting
//! L2/L3. It is not a successful MLX inference claim.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR: &str =
    "small_model_runtime_harness_logged_runtime_smoke";
pub const SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_first_token_runtime_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const ABORTABLE_PROBE_PREFIX: &str =
    "artifact:small_model_runtime_harness_abortable_runtime_probe:";
const SWIFT_RUNTIME_PREFIX: &str = "source:Epistemos/Engine/MLXInferenceService.swift:";
const SERIAL_CONTROLLER_PREFIX: &str =
    "source:Epistemos/Engine/LocalInferenceSerialController.swift:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CANCELLATION_PREFIX: &str = "cancel:";
const PRIVACY_PREFIX: &str = "privacy:";
const PROMPT_ENVELOPE_PREFIX: &str = "prompt_envelope:";
const BUDGET_PREFIX: &str = "budget:";
const MODEL_CATALOG_PREFIX: &str = "model_catalog:";
const MODEL_SNAPSHOT_PREFIX: &str = "model_snapshot:local:";
const FAILURE_REASON_PREFIX: &str = "failure_reason:missing_local_snapshot:";
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
const MAX_OBSERVED_ELAPSED_MS: u32 = 1_000;
const MAX_METADATA_BYTES: u64 = 448 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:phase
// Plane: Controller + Verification
// Residency: metadata-only logged smoke-attempt phase.
pub enum SmallModelLoggedRuntimeSmokePhase {
    AbortableArtifactBound,
    SwiftRuntimeSurfaceBound,
    SerialControllerBound,
    LocalSnapshotAvailabilityChecked,
    RuntimeAttemptLogged,
    MissingSnapshotFailureLogged,
    RollbackVerified,
    RunEventLogged,
    AnswerPacketDrafted,
    MutationReviewPassed,
    EvidenceReviewPending,
}

impl SmallModelLoggedRuntimeSmokePhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::AbortableArtifactBound => "abortable_artifact_bound",
            Self::SwiftRuntimeSurfaceBound => "swift_runtime_surface_bound",
            Self::SerialControllerBound => "serial_controller_bound",
            Self::LocalSnapshotAvailabilityChecked => "local_snapshot_availability_checked",
            Self::RuntimeAttemptLogged => "runtime_attempt_logged",
            Self::MissingSnapshotFailureLogged => "missing_snapshot_failure_logged",
            Self::RollbackVerified => "rollback_verified",
            Self::RunEventLogged => "run_event_logged",
            Self::AnswerPacketDrafted => "answer_packet_drafted",
            Self::MutationReviewPassed => "mutation_review_passed",
            Self::EvidenceReviewPending => "evidence_review_pending",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:error
// Plane: Verification
// Residency: metadata-only logged smoke rejection taxonomy.
pub enum SmallModelRuntimeHarnessLoggedSmokeError {
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
    MissingAbortableProbeArtifact(String),
    MissingSwiftRuntimeSurface(String),
    MissingSerialController(String),
    MissingModelCatalog(String),
    MissingModelSnapshot(String),
    MissingPromptEnvelope(String),
    MissingAdmission(String),
    MissingScopeRex(String),
    MissingSovereignGate(String),
    MissingCompatibilityFence(String),
    MissingCancellation(String),
    MissingRollback(String),
    MissingRunEventLog(String),
    MissingAnswerPacket(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    MissingFailureReason(String),
    MissingLayerSeparation,
    RuntimeAttemptNotLogged(String),
    MissingSnapshotNotLogged(String),
    SnapshotAvailabilityOverclaimed(String),
    ModelOpenAttempted(String),
    RuntimeStarted(String),
    RuntimeCompleted(String),
    FirstTokenObserved(String),
    OutputTokensObserved(String),
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
    RuntimeBytesLoaded(String),
    ModelBytesLoaded(String),
    TransportRuntimeBytesLoaded(String),
    MasOverclaimAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelRuntimeHarnessLoggedSmokeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyRun => write!(f, "missing logged smoke run"),
            Self::EmptySurface => write!(f, "missing logged smoke surface"),
            Self::EmptyPhase => write!(f, "missing logged smoke phase"),
            Self::DuplicateRun(id) => write!(f, "duplicate logged smoke run `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::MissingRequiredLane(id) => write!(f, "missing required lane `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingAbortableProbeArtifact(id) => {
                write!(f, "run `{id}` missing abortable-probe artifact ref")
            }
            Self::MissingSwiftRuntimeSurface(id) => {
                write!(f, "run `{id}` missing Swift MLX runtime source ref")
            }
            Self::MissingSerialController(id) => {
                write!(f, "run `{id}` missing serialized controller ref")
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
            Self::MissingCancellation(id) => write!(f, "run `{id}` missing cancellation ref"),
            Self::MissingRollback(id) => write!(f, "run `{id}` missing rollback ref"),
            Self::MissingRunEventLog(id) => write!(f, "run `{id}` missing RunEventLog"),
            Self::MissingAnswerPacket(id) => write!(f, "run `{id}` missing AnswerPacket"),
            Self::MissingPrivacyFence(id) => write!(f, "run `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "run `{id}` missing budget ref"),
            Self::MissingFailureReason(id) => write!(f, "run `{id}` missing failure reason"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::RuntimeAttemptNotLogged(id) => write!(f, "run `{id}` did not log attempt"),
            Self::MissingSnapshotNotLogged(id) => {
                write!(f, "run `{id}` did not log missing snapshot")
            }
            Self::SnapshotAvailabilityOverclaimed(id) => {
                write!(f, "run `{id}` overclaimed local snapshot availability")
            }
            Self::ModelOpenAttempted(id) => write!(f, "run `{id}` attempted model open"),
            Self::RuntimeStarted(id) => write!(f, "run `{id}` started runtime"),
            Self::RuntimeCompleted(id) => write!(f, "run `{id}` completed runtime"),
            Self::FirstTokenObserved(id) => write!(f, "run `{id}` observed first token"),
            Self::OutputTokensObserved(id) => write!(f, "run `{id}` observed output tokens"),
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

impl std::error::Error for SmallModelRuntimeHarnessLoggedSmokeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:surface
// Plane: Verification
// Residency: visible canon/product-copy surface evidence.
pub struct SmallModelLoggedRuntimeSmokeSurface {
    pub surface_id: String,
    pub source_ref: String,
    pub observed_text: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
}

impl SmallModelLoggedRuntimeSmokeSurface {
    pub fn new(
        surface_id: impl Into<String>,
        source_ref: impl Into<String>,
        observed_text: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessLoggedSmokeError> {
        let surface = Self {
            surface_id: surface_id.into(),
            source_ref: source_ref.into(),
            observed_text: observed_text.into(),
            required_markers,
            forbidden_markers,
        };
        validate_clean("surface_id", &surface.surface_id)?;
        validate_clean("source_ref", &surface.source_ref)?;
        if surface.observed_text.trim().len() < MIN_SURFACE_TEXT_BYTES {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::EmptySurface);
        }
        for marker in &surface.required_markers {
            validate_clean("required_marker", marker)?;
            if !surface.observed_text.contains(marker) {
                return Err(
                    SmallModelRuntimeHarnessLoggedSmokeError::MissingRequiredMarker(marker.clone()),
                );
            }
        }
        for marker in &surface.forbidden_markers {
            validate_clean("forbidden_marker", marker)?;
            if surface.observed_text.contains(marker) {
                return Err(SmallModelRuntimeHarnessLoggedSmokeError::ForbiddenMarker(
                    marker.clone(),
                ));
            }
        }
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:run
// Plane: Controller + Verification
// Residency: logged failed smoke attempt for absent local model snapshots.
pub struct SmallModelLoggedRuntimeSmokeRun {
    pub run_id: String,
    pub lane_id: String,
    pub abortable_probe_artifact_ref: String,
    pub swift_runtime_surface_ref: String,
    pub serial_controller_ref: String,
    pub model_catalog_ref: String,
    pub model_snapshot_ref: String,
    pub prompt_envelope_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub failure_reason_ref: String,
    pub phases: Vec<SmallModelLoggedRuntimeSmokePhase>,
    pub context_tokens: u32,
    pub prompt_tokens: u32,
    pub decode_tokens: u32,
    pub memory_budget_bytes: u64,
    pub runtime_budget_seconds: u32,
    pub observed_elapsed_ms: u32,
    pub runtime_attempt_logged: bool,
    pub model_snapshot_available: bool,
    pub missing_snapshot_logged: bool,
    pub model_open_attempted: bool,
    pub runtime_started: bool,
    pub runtime_completed: bool,
    pub first_token_observed: bool,
    pub output_token_count: u32,
    pub committed_mutation: bool,
    pub route_policy_mutation_attempted: bool,
    pub gate_bypass_attempted: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_route_authority_attempted: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub subprocess_spawned: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

impl SmallModelLoggedRuntimeSmokeRun {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        lane_id: impl Into<String>,
        abortable_probe_artifact_ref: impl Into<String>,
        swift_runtime_surface_ref: impl Into<String>,
        serial_controller_ref: impl Into<String>,
        model_catalog_ref: impl Into<String>,
        model_snapshot_ref: impl Into<String>,
        prompt_envelope_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        privacy_ref: impl Into<String>,
        budget_ref: impl Into<String>,
        failure_reason_ref: impl Into<String>,
        phases: Vec<SmallModelLoggedRuntimeSmokePhase>,
    ) -> Result<Self, SmallModelRuntimeHarnessLoggedSmokeError> {
        let run = Self {
            run_id: run_id.into(),
            lane_id: lane_id.into(),
            abortable_probe_artifact_ref: abortable_probe_artifact_ref.into(),
            swift_runtime_surface_ref: swift_runtime_surface_ref.into(),
            serial_controller_ref: serial_controller_ref.into(),
            model_catalog_ref: model_catalog_ref.into(),
            model_snapshot_ref: model_snapshot_ref.into(),
            prompt_envelope_ref: prompt_envelope_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence_ref: compatibility_fence_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            rollback_ref: rollback_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            privacy_ref: privacy_ref.into(),
            budget_ref: budget_ref.into(),
            failure_reason_ref: failure_reason_ref.into(),
            phases,
            context_tokens: 2_048,
            prompt_tokens: 256,
            decode_tokens: 64,
            memory_budget_bytes: 2 * 1024 * 1024 * 1024,
            runtime_budget_seconds: 45,
            observed_elapsed_ms: 34,
            runtime_attempt_logged: true,
            model_snapshot_available: false,
            missing_snapshot_logged: true,
            model_open_attempted: false,
            runtime_started: false,
            runtime_completed: false,
            first_token_observed: false,
            output_token_count: 0,
            committed_mutation: false,
            route_policy_mutation_attempted: false,
            gate_bypass_attempted: false,
            answer_packet_suppressed: false,
            hidden_route_authority_attempted: false,
            hidden_chain_exposed: false,
            hidden_cloud_fallback_allowed: false,
            subprocess_spawned: false,
            autogenous_kernel_attempted: false,
            seventy_b_probe_attempted: false,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            transport_runtime_bytes_loaded: 0,
        };
        run.validate()?;
        Ok(run)
    }

    pub fn validate(&self) -> Result<(), SmallModelRuntimeHarnessLoggedSmokeError> {
        validate_clean("run_id", &self.run_id)?;
        validate_clean("lane_id", &self.lane_id)?;
        validate_prefixed(
            &self.run_id,
            &self.abortable_probe_artifact_ref,
            ABORTABLE_PROBE_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingAbortableProbeArtifact,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.swift_runtime_surface_ref,
            SWIFT_RUNTIME_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingSwiftRuntimeSurface,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.serial_controller_ref,
            SERIAL_CONTROLLER_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingSerialController,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.model_catalog_ref,
            MODEL_CATALOG_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingModelCatalog,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.model_snapshot_ref,
            MODEL_SNAPSHOT_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingModelSnapshot,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.prompt_envelope_ref,
            PROMPT_ENVELOPE_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingPromptEnvelope,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.admission_ref,
            ADMISSION_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingAdmission,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.scope_rex_ref,
            SCOPE_REX_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingScopeRex,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingSovereignGate,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingCompatibilityFence,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.cancellation_ref,
            CANCELLATION_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingCancellation,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.rollback_ref,
            ROLLBACK_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingRollback,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingRunEventLog,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingAnswerPacket,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.privacy_ref,
            PRIVACY_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingPrivacyFence,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.budget_ref,
            BUDGET_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingBudget,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.failure_reason_ref,
            FAILURE_REASON_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingFailureReason,
        )?;
        if self.phases.is_empty() {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::EmptyPhase);
        }
        let phase_tags: BTreeSet<&str> = self.phases.iter().map(|phase| phase.tag()).collect();
        for phase in required_phases() {
            if !phase_tags.contains(phase.tag()) {
                return Err(SmallModelRuntimeHarnessLoggedSmokeError::MissingPhase(
                    phase.tag(),
                ));
            }
        }
        if !self.runtime_attempt_logged {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::RuntimeAttemptNotLogged(
                    self.run_id.clone(),
                ),
            );
        }
        if !self.missing_snapshot_logged {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::MissingSnapshotNotLogged(
                    self.run_id.clone(),
                ),
            );
        }
        if self.model_snapshot_available {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::SnapshotAvailabilityOverclaimed(
                    self.run_id.clone(),
                ),
            );
        }
        if self.model_open_attempted {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::ModelOpenAttempted(self.run_id.clone()),
            );
        }
        if self.runtime_started {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::RuntimeStarted(
                self.run_id.clone(),
            ));
        }
        if self.runtime_completed {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::RuntimeCompleted(
                self.run_id.clone(),
            ));
        }
        if self.first_token_observed {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::FirstTokenObserved(self.run_id.clone()),
            );
        }
        if self.output_token_count > 0 {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::OutputTokensObserved(self.run_id.clone()),
            );
        }
        if self.committed_mutation {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::MutationCommitted(
                self.run_id.clone(),
            ));
        }
        if self.route_policy_mutation_attempted {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::RoutePolicyMutation(self.run_id.clone()),
            );
        }
        if self.gate_bypass_attempted {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::GateBypass(
                self.run_id.clone(),
            ));
        }
        if self.answer_packet_suppressed {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::AnswerPacketSuppression(
                    self.run_id.clone(),
                ),
            );
        }
        if self.hidden_route_authority_attempted {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::HiddenRouteAuthority(self.run_id.clone()),
            );
        }
        if self.hidden_chain_exposed {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::HiddenChainExposure(self.run_id.clone()),
            );
        }
        if self.hidden_cloud_fallback_allowed {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::HiddenCloudFallback(self.run_id.clone()),
            );
        }
        if self.subprocess_spawned {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::SubprocessSpawn(
                self.run_id.clone(),
            ));
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::AutogenousKernelAttempt(
                    self.run_id.clone(),
                ),
            );
        }
        if self.seventy_b_probe_attempted {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::SeventyBProbeAttempt(self.run_id.clone()),
            );
        }
        if self.runtime_bytes_loaded > 0 {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::RuntimeBytesLoaded(self.run_id.clone()),
            );
        }
        if self.model_bytes_loaded > 0 {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::ModelBytesLoaded(
                self.run_id.clone(),
            ));
        }
        if self.transport_runtime_bytes_loaded > 0 {
            return Err(
                SmallModelRuntimeHarnessLoggedSmokeError::TransportRuntimeBytesLoaded(
                    self.run_id.clone(),
                ),
            );
        }
        if self.context_tokens > MAX_CONTEXT_TOKENS {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::BudgetExceeded(
                "context_tokens",
            ));
        }
        if self.prompt_tokens > MAX_PROMPT_TOKENS {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::BudgetExceeded(
                "prompt_tokens",
            ));
        }
        if self.decode_tokens > MAX_DECODE_TOKENS {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::BudgetExceeded(
                "decode_tokens",
            ));
        }
        if self.memory_budget_bytes > MAX_MEMORY_BUDGET_BYTES {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::BudgetExceeded(
                "memory_budget_bytes",
            ));
        }
        if self.runtime_budget_seconds > MAX_RUNTIME_SECONDS {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::BudgetExceeded(
                "runtime_budget_seconds",
            ));
        }
        if self.observed_elapsed_ms > MAX_OBSERVED_ELAPSED_MS {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::BudgetExceeded(
                "observed_elapsed_ms",
            ));
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:metrics
// Plane: Verification
// Residency: aggregate logged smoke-attempt metrics.
pub struct SmallModelRuntimeHarnessLoggedSmokeMetrics {
    pub run_count: u64,
    pub surface_count: u64,
    pub required_lane_count: u64,
    pub phase_count: u64,
    pub runtime_attempt_logged_count: u64,
    pub missing_snapshot_logged_count: u64,
    pub unavailable_snapshot_count: u64,
    pub max_observed_elapsed_ms: u32,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:witness
// Plane: Controller + Verification
// Residency: complete logged failed-smoke witness.
pub struct SmallModelRuntimeHarnessLoggedSmokeWitness {
    pub witness_id: String,
    pub abortable_probe_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub runs: Vec<SmallModelLoggedRuntimeSmokeRun>,
    pub surfaces: Vec<SmallModelLoggedRuntimeSmokeSurface>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
}

impl SmallModelRuntimeHarnessLoggedSmokeWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        abortable_probe_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        runs: Vec<SmallModelLoggedRuntimeSmokeRun>,
        surfaces: Vec<SmallModelLoggedRuntimeSmokeSurface>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessLoggedSmokeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            abortable_probe_artifact_ref: abortable_probe_artifact_ref.into(),
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
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelRuntimeHarnessLoggedSmokeError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_clean(
            "abortable_probe_artifact_ref",
            &self.abortable_probe_artifact_ref,
        )?;
        validate_prefixed(
            &self.witness_id,
            &self.abortable_probe_artifact_ref,
            ABORTABLE_PROBE_PREFIX,
            SmallModelRuntimeHarnessLoggedSmokeError::MissingAbortableProbeArtifact,
        )?;
        if self.guard_next_existing_work != SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::GuardCursorMismatch);
        }
        if self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR
                && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
        {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::ProductStatusMismatch);
        }
        if self.route_authority != "small_model_runtime_harness_logged_failure_only" {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::ProductStatusMismatch);
        }
        if self.runs.is_empty() {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::EmptyRun);
        }
        if self.surfaces.is_empty() {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::EmptySurface);
        }
        let mut run_ids = HashSet::new();
        let mut lanes = BTreeSet::new();
        for run in &self.runs {
            run.validate()?;
            if !run_ids.insert(run.run_id.clone()) {
                return Err(SmallModelRuntimeHarnessLoggedSmokeError::DuplicateRun(
                    run.run_id.clone(),
                ));
            }
            lanes.insert(run.lane_id.as_str());
        }
        for lane in REQUIRED_LANES {
            if !lanes.contains(lane) {
                return Err(SmallModelRuntimeHarnessLoggedSmokeError::MissingRequiredLane(lane));
            }
        }
        let mut surface_ids = HashSet::new();
        for surface in &self.surfaces {
            if !surface_ids.insert(surface.surface_id.clone()) {
                return Err(SmallModelRuntimeHarnessLoggedSmokeError::DuplicateSurface(
                    surface.surface_id.clone(),
                ));
            }
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::MissingLayerSeparation);
        }
        if self.mas_overclaim_attempted {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::MasOverclaimAttempted);
        }
        if self.l2_green_claimed {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::L3GreenClaimAttempted);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelRuntimeHarnessLoggedSmokeError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelRuntimeHarnessLoggedSmokeMetrics {
        let phase_count = self
            .runs
            .iter()
            .flat_map(|run| run.phases.iter().map(|phase| phase.tag()))
            .collect::<BTreeSet<_>>()
            .len() as u64;
        SmallModelRuntimeHarnessLoggedSmokeMetrics {
            run_count: self.runs.len() as u64,
            surface_count: self.surfaces.len() as u64,
            required_lane_count: self
                .runs
                .iter()
                .map(|run| run.lane_id.as_str())
                .collect::<BTreeSet<_>>()
                .len() as u64,
            phase_count,
            runtime_attempt_logged_count: self
                .runs
                .iter()
                .filter(|run| run.runtime_attempt_logged)
                .count() as u64,
            missing_snapshot_logged_count: self
                .runs
                .iter()
                .filter(|run| run.missing_snapshot_logged)
                .count() as u64,
            unavailable_snapshot_count: self
                .runs
                .iter()
                .filter(|run| !run.model_snapshot_available)
                .count() as u64,
            max_observed_elapsed_ms: self
                .runs
                .iter()
                .map(|run| run.observed_elapsed_ms)
                .max()
                .unwrap_or(0),
            runtime_bytes_loaded: self.runs.iter().map(|run| run.runtime_bytes_loaded).sum(),
            model_bytes_loaded: self.runs.iter().map(|run| run.model_bytes_loaded).sum(),
            transport_runtime_bytes_loaded: self
                .runs
                .iter()
                .map(|run| run.transport_runtime_bytes_loaded)
                .sum(),
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.abortable_probe_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
        ];
        for run in &self.runs {
            parts.push(run.run_id.clone());
            parts.push(run.lane_id.clone());
            parts.push(run.failure_reason_ref.clone());
            parts.push(run.run_event_log_ref.clone());
            parts.push(run.answer_packet_ref.clone());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

fn required_phases() -> [SmallModelLoggedRuntimeSmokePhase; 11] {
    [
        SmallModelLoggedRuntimeSmokePhase::AbortableArtifactBound,
        SmallModelLoggedRuntimeSmokePhase::SwiftRuntimeSurfaceBound,
        SmallModelLoggedRuntimeSmokePhase::SerialControllerBound,
        SmallModelLoggedRuntimeSmokePhase::LocalSnapshotAvailabilityChecked,
        SmallModelLoggedRuntimeSmokePhase::RuntimeAttemptLogged,
        SmallModelLoggedRuntimeSmokePhase::MissingSnapshotFailureLogged,
        SmallModelLoggedRuntimeSmokePhase::RollbackVerified,
        SmallModelLoggedRuntimeSmokePhase::RunEventLogged,
        SmallModelLoggedRuntimeSmokePhase::AnswerPacketDrafted,
        SmallModelLoggedRuntimeSmokePhase::MutationReviewPassed,
        SmallModelLoggedRuntimeSmokePhase::EvidenceReviewPending,
    ]
}

fn validate_prefixed(
    run_id: &str,
    value: &str,
    prefix: &str,
    error: fn(String) -> SmallModelRuntimeHarnessLoggedSmokeError,
) -> Result<(), SmallModelRuntimeHarnessLoggedSmokeError> {
    validate_clean("prefixed_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(error(run_id.to_string()));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessLoggedSmokeError> {
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessLoggedSmokeError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(SmallModelRuntimeHarnessLoggedSmokeError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(SmallModelRuntimeHarnessLoggedSmokeError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn phases() -> Vec<SmallModelLoggedRuntimeSmokePhase> {
        required_phases().to_vec()
    }

    fn run(id: &str, lane: &str) -> SmallModelLoggedRuntimeSmokeRun {
        SmallModelLoggedRuntimeSmokeRun::new(
            id,
            lane,
            "artifact:small_model_runtime_harness_abortable_runtime_probe:sha256:test",
            "source:Epistemos/Engine/MLXInferenceService.swift:LocalMLXRuntime",
            "source:Epistemos/Engine/LocalInferenceSerialController.swift:beginTurn",
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:missing",
            format!("prompt_envelope:{lane}:smoke"),
            format!("admission:{lane}:scope-rex"),
            format!("scope_rex:{lane}:admit"),
            format!("sovereign_gate:{lane}:research-candidate"),
            format!("compat:{lane}:mlx-small-smoke-v1"),
            format!("cancel:{lane}:token"),
            format!("rollback:{lane}:no-mutation"),
            format!("run_event_log:{lane}:missing-snapshot"),
            format!("answer_packet:{lane}:visible-missing-snapshot"),
            format!("privacy:{lane}:local-only-no-prompt-retention"),
            format!("budget:{lane}:2gb-45s"),
            format!("failure_reason:missing_local_snapshot:{lane}"),
            phases(),
        )
        .expect("valid logged smoke run")
    }

    fn surface(id: &str) -> SmallModelLoggedRuntimeSmokeSurface {
        SmallModelLoggedRuntimeSmokeSurface::new(
            id,
            format!("surface:{id}"),
            "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. small_model_runtime_harness_logged_runtime_smoke vault_research_route_with_packetized_mitigation missing_local_snapshot AnswerPacket rollback RunEventLog no product promotion no live 70B",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "small_model_runtime_harness_logged_runtime_smoke".to_string(),
                "vault_research_route_with_packetized_mitigation".to_string(),
            ],
            vec!["MAS ships live local agent runtime".to_string()],
        )
        .expect("valid surface")
    }

    fn witness() -> SmallModelRuntimeHarnessLoggedSmokeWitness {
        SmallModelRuntimeHarnessLoggedSmokeWitness::new(
            "logged-smoke-witness",
            "artifact:small_model_runtime_harness_abortable_runtime_probe:sha256:test",
            SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "small_model_runtime_harness_logged_failure_only",
            vec![
                run("run-a", "qwen3_small_catalog_smoke"),
                run("run-b", "local_agent_notes_research_smoke"),
                run("run-c", "coding_tool_dry_run_smoke"),
            ],
            vec![surface("living_index"), surface("lattice_html")],
            4096,
            true,
            false,
            false,
            false,
        )
        .expect("valid witness")
    }

    #[test]
    fn deterministic_address_and_metrics() {
        let good = witness();
        let mut reversed = good.runs.clone();
        reversed.reverse();
        let other = SmallModelRuntimeHarnessLoggedSmokeWitness::new(
            good.witness_id.clone(),
            good.abortable_probe_artifact_ref.clone(),
            good.guard_next_existing_work.clone(),
            good.capability_route_status.clone(),
            good.capability_next_bottleneck.clone(),
            good.product_build.clone(),
            good.pro_status.clone(),
            good.route_authority.clone(),
            reversed,
            good.surfaces.clone(),
            good.metadata_bytes,
            good.l1_l2_l3_separated,
            good.mas_overclaim_attempted,
            good.l2_green_claimed,
            good.l3_green_claimed,
        )
        .expect("valid reversed witness");
        assert_eq!(good.address(), other.address());
        let metrics = good.metrics();
        assert_eq!(metrics.run_count, 3);
        assert_eq!(metrics.required_lane_count, 3);
        assert_eq!(metrics.phase_count, 11);
        assert_eq!(metrics.runtime_attempt_logged_count, 3);
        assert_eq!(metrics.unavailable_snapshot_count, 3);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
    }

    #[test]
    fn duplicate_run_is_rejected() {
        let mut good = witness();
        good.runs[1].run_id = good.runs[0].run_id.clone();
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessLoggedSmokeError::DuplicateRun(_))
        ));
    }

    #[test]
    fn missing_runtime_log_is_rejected() {
        let mut good = run("run-a", "qwen3_small_catalog_smoke");
        good.runtime_attempt_logged = false;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessLoggedSmokeError::RuntimeAttemptNotLogged(_))
        ));
    }

    #[test]
    fn snapshot_availability_overclaim_is_rejected() {
        let mut good = run("run-a", "qwen3_small_catalog_smoke");
        good.model_snapshot_available = true;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessLoggedSmokeError::SnapshotAvailabilityOverclaimed(_))
        ));
    }

    #[test]
    fn model_open_is_rejected() {
        let mut good = run("run-a", "qwen3_small_catalog_smoke");
        good.model_open_attempted = true;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessLoggedSmokeError::ModelOpenAttempted(_))
        ));
    }

    #[test]
    fn runtime_bytes_are_rejected() {
        let mut good = run("run-a", "qwen3_small_catalog_smoke");
        good.runtime_bytes_loaded = 1;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessLoggedSmokeError::RuntimeBytesLoaded(_))
        ));
    }
}
