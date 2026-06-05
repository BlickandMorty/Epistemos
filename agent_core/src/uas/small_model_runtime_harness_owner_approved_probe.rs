//! Small-model runtime harness owner-approval probe lease.
//!
//! This L1 witness sits at `small_model_runtime_harness_owner_approved_probe`.
//! It still does not run MLX, load model bytes, mutate route policy, or
//! promote L2/L3. It proves the first local small-model runtime probe is bound
//! to an explicit owner-approval lease, the prior dry-run artifact, selected
//! local catalog entries, admission, serialized execution, cancellation,
//! rollback, RunEventLog, AnswerPacket, privacy, and budgets before a live
//! abortable runtime probe can execute.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR: &str =
    "small_model_runtime_harness_owner_approved_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_abortable_runtime_probe";

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
const PROMPT_ENVELOPE_PREFIX: &str = "prompt_envelope:";
const BUDGET_PREFIX: &str = "budget:";
const MODEL_CATALOG_PREFIX: &str = "model_catalog:";
const MODEL_SNAPSHOT_PREFIX: &str = "model_snapshot:local:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:";
const DRY_RUN_PREFIX: &str = "artifact:small_model_runtime_harness_dry_run_witness:";
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
const MAX_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-owner-probe:phase
// Plane: Controller + Verification
// Residency: metadata-only owner-approved probe phase.
pub enum SmallModelOwnerProbePhase {
    DryRunArtifactBound,
    OwnerApprovalLeaseBound,
    ModelCatalogBound,
    PromptEnvelopeCompiled,
    AdmissionChecked,
    ExecutorReserved,
    CancellationArmed,
    RollbackCheckpointRecorded,
    RuntimeProbeArmed,
    RuntimeExecutionDeferred,
    RunEventLogged,
    AnswerPacketDrafted,
    EvidenceReviewPending,
}

impl SmallModelOwnerProbePhase {
    fn tag(&self) -> &'static str {
        match self {
            Self::DryRunArtifactBound => "dry_run_artifact_bound",
            Self::OwnerApprovalLeaseBound => "owner_approval_lease_bound",
            Self::ModelCatalogBound => "model_catalog_bound",
            Self::PromptEnvelopeCompiled => "prompt_envelope_compiled",
            Self::AdmissionChecked => "admission_checked",
            Self::ExecutorReserved => "executor_reserved",
            Self::CancellationArmed => "cancellation_armed",
            Self::RollbackCheckpointRecorded => "rollback_checkpoint_recorded",
            Self::RuntimeProbeArmed => "runtime_probe_armed",
            Self::RuntimeExecutionDeferred => "runtime_execution_deferred",
            Self::RunEventLogged => "run_event_logged",
            Self::AnswerPacketDrafted => "answer_packet_drafted",
            Self::EvidenceReviewPending => "evidence_review_pending",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-owner-probe:error
// Plane: Verification
// Residency: metadata-only owner-probe rejection taxonomy.
pub enum SmallModelRuntimeHarnessOwnerProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyLease,
    EmptySurface,
    EmptyPhase,
    DuplicateLease(String),
    DuplicateSurface(String),
    MissingRequiredLane(&'static str),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingPhase(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingDryRunArtifact(String),
    MissingOwnerApproval(String),
    OwnerApprovalNotBound(String),
    MissingModelCatalog(String),
    MissingModelSnapshot(String),
    MissingPromptEnvelope(String),
    MissingAdmission(String),
    MissingScopeRex(String),
    MissingSovereignGate(String),
    MissingCompatibilityFence(String),
    MissingSerializedExecutor(String),
    MissingCancellation(String),
    MissingRollback(String),
    MissingRunEventLog(String),
    MissingAnswerPacket(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    MissingLayerSeparation,
    RuntimeProbeNotArmed(String),
    RuntimeProbeExecuted(String),
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

impl fmt::Display for SmallModelRuntimeHarnessOwnerProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyLease => write!(f, "missing owner-probe lease"),
            Self::EmptySurface => write!(f, "missing owner-probe surface"),
            Self::EmptyPhase => write!(f, "missing owner-probe phase"),
            Self::DuplicateLease(id) => write!(f, "duplicate owner-probe lease `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::MissingRequiredLane(id) => write!(f, "missing required lane `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingDryRunArtifact(id) => {
                write!(f, "lease `{id}` missing dry-run artifact ref")
            }
            Self::MissingOwnerApproval(id) => {
                write!(f, "lease `{id}` missing owner approval ref")
            }
            Self::OwnerApprovalNotBound(id) => {
                write!(f, "lease `{id}` owner approval is not dry-run-bound")
            }
            Self::MissingModelCatalog(id) => write!(f, "lease `{id}` missing model catalog ref"),
            Self::MissingModelSnapshot(id) => write!(f, "lease `{id}` missing model snapshot ref"),
            Self::MissingPromptEnvelope(id) => {
                write!(f, "lease `{id}` missing prompt envelope")
            }
            Self::MissingAdmission(id) => write!(f, "lease `{id}` missing admission ref"),
            Self::MissingScopeRex(id) => write!(f, "lease `{id}` missing SCOPE-Rex ref"),
            Self::MissingSovereignGate(id) => {
                write!(f, "lease `{id}` missing SovereignGate ref")
            }
            Self::MissingCompatibilityFence(id) => {
                write!(f, "lease `{id}` missing compatibility fence")
            }
            Self::MissingSerializedExecutor(id) => {
                write!(f, "lease `{id}` missing serialized executor")
            }
            Self::MissingCancellation(id) => write!(f, "lease `{id}` missing cancellation ref"),
            Self::MissingRollback(id) => write!(f, "lease `{id}` missing rollback ref"),
            Self::MissingRunEventLog(id) => write!(f, "lease `{id}` missing RunEventLog"),
            Self::MissingAnswerPacket(id) => write!(f, "lease `{id}` missing AnswerPacket"),
            Self::MissingPrivacyFence(id) => write!(f, "lease `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "lease `{id}` missing budget ref"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::RuntimeProbeNotArmed(id) => write!(f, "lease `{id}` did not arm probe"),
            Self::RuntimeProbeExecuted(id) => write!(f, "lease `{id}` executed runtime probe"),
            Self::MutationCommitted(id) => write!(f, "lease `{id}` committed mutation"),
            Self::RoutePolicyMutation(id) => {
                write!(f, "lease `{id}` attempted route policy mutation")
            }
            Self::GateBypass(id) => write!(f, "lease `{id}` attempted gate bypass"),
            Self::AnswerPacketSuppression(id) => {
                write!(f, "lease `{id}` suppressed AnswerPacket")
            }
            Self::HiddenRouteAuthority(id) => {
                write!(f, "lease `{id}` attempted hidden route authority")
            }
            Self::HiddenChainExposure(id) => write!(f, "lease `{id}` exposed hidden chain"),
            Self::HiddenCloudFallback(id) => write!(f, "lease `{id}` allowed hidden cloud"),
            Self::SubprocessSpawn(id) => write!(f, "lease `{id}` spawned subprocess"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "lease `{id}` attempted autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "lease `{id}` attempted 70B probe"),
            Self::BudgetExceeded(budget) => write!(f, "budget `{budget}` exceeded"),
            Self::RuntimeBytesLoaded(id) => write!(f, "lease `{id}` loaded runtime bytes"),
            Self::ModelBytesLoaded(id) => write!(f, "lease `{id}` loaded model bytes"),
            Self::TransportRuntimeBytesLoaded(id) => {
                write!(f, "lease `{id}` loaded transport runtime bytes")
            }
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelRuntimeHarnessOwnerProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-owner-probe:surface
// Plane: State + Verification
// Residency: local documentation surface scan; no runtime bytes.
pub struct SmallModelOwnerProbeSurface {
    pub surface_id: String,
    pub path: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
    pub observed_text: String,
}

impl SmallModelOwnerProbeSurface {
    pub fn new(
        surface_id: impl Into<String>,
        path: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
        observed_text: impl Into<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessOwnerProbeError> {
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
// UAS: uas:small-model-runtime-harness-owner-probe:lease
// Plane: Controller + Verification
// Residency: metadata-only owner-approved runtime probe lease.
pub struct SmallModelOwnerProbeLease {
    pub lease_id: String,
    pub lane_id: String,
    pub model_role: String,
    pub dry_run_artifact_ref: String,
    pub owner_approval_ref: String,
    pub model_catalog_ref: String,
    pub model_snapshot_ref: String,
    pub prompt_envelope_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub serialized_executor_ref: String,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub phases: BTreeSet<SmallModelOwnerProbePhase>,
    pub max_context_tokens: u32,
    pub prompt_tokens: u32,
    pub max_decode_tokens: u32,
    pub memory_budget_bytes: u64,
    pub runtime_budget_seconds: u32,
    pub approval_bound_to_dry_run: bool,
    pub runtime_probe_armed: bool,
    pub runtime_probe_executed: bool,
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

impl SmallModelOwnerProbeLease {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        lease_id: impl Into<String>,
        lane_id: impl Into<String>,
        model_role: impl Into<String>,
        dry_run_artifact_ref: impl Into<String>,
        owner_approval_ref: impl Into<String>,
        model_catalog_ref: impl Into<String>,
        model_snapshot_ref: impl Into<String>,
        prompt_envelope_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        serialized_executor_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        privacy_ref: impl Into<String>,
        budget_ref: impl Into<String>,
        phases: BTreeSet<SmallModelOwnerProbePhase>,
        max_context_tokens: u32,
        prompt_tokens: u32,
        max_decode_tokens: u32,
        memory_budget_bytes: u64,
        runtime_budget_seconds: u32,
        approval_bound_to_dry_run: bool,
        runtime_probe_armed: bool,
        runtime_probe_executed: bool,
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
    ) -> Result<Self, SmallModelRuntimeHarnessOwnerProbeError> {
        let lease = Self {
            lease_id: lease_id.into(),
            lane_id: lane_id.into(),
            model_role: model_role.into(),
            dry_run_artifact_ref: dry_run_artifact_ref.into(),
            owner_approval_ref: owner_approval_ref.into(),
            model_catalog_ref: model_catalog_ref.into(),
            model_snapshot_ref: model_snapshot_ref.into(),
            prompt_envelope_ref: prompt_envelope_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            serialized_executor_ref: serialized_executor_ref.into(),
            cancellation_ref: cancellation_ref.into(),
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
            approval_bound_to_dry_run,
            runtime_probe_armed,
            runtime_probe_executed,
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
        validate_lease(&lease)?;
        Ok(lease)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-owner-probe:metrics
// Plane: Verification
// Residency: metadata-only metric rollup.
pub struct SmallModelRuntimeHarnessOwnerProbeMetrics {
    pub lease_count: u64,
    pub surface_count: u64,
    pub required_lane_count: u64,
    pub phase_count: u64,
    pub max_context_tokens: u64,
    pub max_prompt_tokens: u64,
    pub max_decode_tokens: u64,
    pub max_memory_budget_bytes: u64,
    pub max_runtime_seconds: u64,
    pub runtime_probe_armed_count: u64,
    pub runtime_probe_executed_count: u64,
    pub mutation_committed_count: u64,
    pub cloud_fallback_count: u64,
    pub subprocess_spawn_count: u64,
    pub seventy_b_probe_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-owner-probe:witness
// Plane: Controller + Verification
// Residency: metadata-only owner-approved probe witness.
pub struct SmallModelRuntimeHarnessOwnerProbeWitness {
    pub witness_id: String,
    pub dry_run_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub leases: Vec<SmallModelOwnerProbeLease>,
    pub surfaces: Vec<SmallModelOwnerProbeSurface>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
}

impl SmallModelRuntimeHarnessOwnerProbeWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        dry_run_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        leases: Vec<SmallModelOwnerProbeLease>,
        surfaces: Vec<SmallModelOwnerProbeSurface>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessOwnerProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            dry_run_artifact_ref: dry_run_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            leases,
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

    pub fn metrics(&self) -> SmallModelRuntimeHarnessOwnerProbeMetrics {
        let mut lanes = HashSet::new();
        let mut phases = BTreeSet::new();
        let mut max_context_tokens = 0_u64;
        let mut max_prompt_tokens = 0_u64;
        let mut max_decode_tokens = 0_u64;
        let mut max_memory_budget_bytes = 0_u64;
        let mut max_runtime_seconds = 0_u64;
        let mut runtime_probe_armed_count = 0_u64;
        let mut runtime_probe_executed_count = 0_u64;
        let mut mutation_committed_count = 0_u64;
        let mut cloud_fallback_count = 0_u64;
        let mut subprocess_spawn_count = 0_u64;
        let mut seventy_b_probe_count = 0_u64;
        let mut runtime_bytes_loaded = 0_u64;
        let mut model_bytes_loaded = 0_u64;
        let mut transport_runtime_bytes_loaded = 0_u64;

        for lease in &self.leases {
            lanes.insert(lease.lane_id.as_str());
            phases.extend(lease.phases.iter().cloned());
            max_context_tokens = max_context_tokens.max(lease.max_context_tokens as u64);
            max_prompt_tokens = max_prompt_tokens.max(lease.prompt_tokens as u64);
            max_decode_tokens = max_decode_tokens.max(lease.max_decode_tokens as u64);
            max_memory_budget_bytes = max_memory_budget_bytes.max(lease.memory_budget_bytes);
            max_runtime_seconds = max_runtime_seconds.max(lease.runtime_budget_seconds as u64);
            runtime_probe_armed_count += u64::from(lease.runtime_probe_armed);
            runtime_probe_executed_count += u64::from(lease.runtime_probe_executed);
            mutation_committed_count += u64::from(lease.mutation_committed);
            cloud_fallback_count += u64::from(lease.hidden_cloud_fallback);
            subprocess_spawn_count += u64::from(lease.subprocess_spawned);
            seventy_b_probe_count += u64::from(lease.seventy_b_probe_attempted);
            runtime_bytes_loaded = runtime_bytes_loaded.saturating_add(lease.runtime_bytes_loaded);
            model_bytes_loaded = model_bytes_loaded.saturating_add(lease.model_bytes_loaded);
            transport_runtime_bytes_loaded = transport_runtime_bytes_loaded
                .saturating_add(lease.transport_runtime_bytes_loaded);
        }

        SmallModelRuntimeHarnessOwnerProbeMetrics {
            lease_count: self.leases.len() as u64,
            surface_count: self.surfaces.len() as u64,
            required_lane_count: REQUIRED_LANES
                .iter()
                .filter(|lane| lanes.contains(**lane))
                .count() as u64,
            phase_count: phases.len() as u64,
            max_context_tokens,
            max_prompt_tokens,
            max_decode_tokens,
            max_memory_budget_bytes,
            max_runtime_seconds,
            runtime_probe_armed_count,
            runtime_probe_executed_count,
            mutation_committed_count,
            cloud_fallback_count,
            subprocess_spawn_count,
            seventy_b_probe_count,
            runtime_bytes_loaded,
            model_bytes_loaded,
            transport_runtime_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut leases = self
            .leases
            .iter()
            .map(|lease| {
                let phases: Vec<&str> = lease
                    .phases
                    .iter()
                    .map(SmallModelOwnerProbePhase::tag)
                    .collect();
                serde_json::json!({
                    "lease_id": lease.lease_id,
                    "lane_id": lease.lane_id,
                    "model_catalog_ref": lease.model_catalog_ref,
                    "model_snapshot_ref": lease.model_snapshot_ref,
                    "dry_run_artifact_ref": lease.dry_run_artifact_ref,
                    "owner_approval_ref": lease.owner_approval_ref,
                    "phases": phases,
                    "max_context_tokens": lease.max_context_tokens,
                    "prompt_tokens": lease.prompt_tokens,
                    "max_decode_tokens": lease.max_decode_tokens,
                    "memory_budget_bytes": lease.memory_budget_bytes,
                    "runtime_budget_seconds": lease.runtime_budget_seconds,
                    "runtime_probe_armed": lease.runtime_probe_armed,
                    "runtime_probe_executed": lease.runtime_probe_executed,
                    "runtime_bytes_loaded": lease.runtime_bytes_loaded,
                    "model_bytes_loaded": lease.model_bytes_loaded,
                    "transport_runtime_bytes_loaded": lease.transport_runtime_bytes_loaded,
                })
            })
            .collect::<Vec<_>>();
        leases.sort_by(|a, b| {
            a["lease_id"]
                .as_str()
                .unwrap_or_default()
                .cmp(b["lease_id"].as_str().unwrap_or_default())
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
            "dry_run_artifact_ref": self.dry_run_artifact_ref,
            "route_authority": self.route_authority,
            "leases": leases,
            "surfaces": surfaces,
            "metadata_bytes": self.metadata_bytes,
        });
        let bytes = serde_json::to_vec(&payload).unwrap_or_default();
        sha256_hex(&bytes)
    }
}

fn validate_witness(
    witness: &SmallModelRuntimeHarnessOwnerProbeWitness,
) -> Result<(), SmallModelRuntimeHarnessOwnerProbeError> {
    validate_clean("witness_id", &witness.witness_id)?;
    validate_clean("dry_run_artifact_ref", &witness.dry_run_artifact_ref)?;
    validate_clean("guard_next_existing_work", &witness.guard_next_existing_work)?;
    validate_clean("capability_route_status", &witness.capability_route_status)?;
    validate_clean("capability_next_bottleneck", &witness.capability_next_bottleneck)?;
    validate_clean("route_authority", &witness.route_authority)?;
    validate_prefix(
        &witness.dry_run_artifact_ref,
        DRY_RUN_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingDryRunArtifact("witness".to_string()),
    )?;
    if witness.guard_next_existing_work != SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR
        && witness.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::GuardCursorMismatch);
    }
    if witness.capability_route_status != "vault_research_route_with_packetized_mitigation" {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::CapabilityStatusMismatch);
    }
    if witness.capability_next_bottleneck != SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR
        && witness.capability_next_bottleneck
            != SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::CapabilityStatusMismatch);
    }
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "small_model_runtime_harness_owner_approval_only"
    {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::ProductStatusMismatch);
    }
    if witness.leases.is_empty() {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::EmptyLease);
    }
    if witness.surfaces.is_empty() {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::EmptySurface);
    }
    let mut lease_ids = HashSet::with_capacity(witness.leases.len());
    let mut lane_ids = HashSet::with_capacity(witness.leases.len());
    for lease in &witness.leases {
        validate_lease(lease)?;
        if !lease_ids.insert(lease.lease_id.as_str()) {
            return Err(SmallModelRuntimeHarnessOwnerProbeError::DuplicateLease(
                lease.lease_id.clone(),
            ));
        }
        lane_ids.insert(lease.lane_id.as_str());
    }
    for required_lane in REQUIRED_LANES {
        if !lane_ids.contains(required_lane) {
            return Err(SmallModelRuntimeHarnessOwnerProbeError::MissingRequiredLane(
                required_lane,
            ));
        }
    }
    let mut surface_ids = HashSet::with_capacity(witness.surfaces.len());
    for surface in &witness.surfaces {
        if !surface_ids.insert(surface.surface_id.as_str()) {
            return Err(SmallModelRuntimeHarnessOwnerProbeError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    if witness.metadata_bytes > MAX_METADATA_BYTES {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::MetadataBudgetExceeded);
    }
    if !witness.l1_l2_l3_separated {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::MissingLayerSeparation);
    }
    if witness.mas_overclaim_attempted {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::MasOverclaimAttempted);
    }
    if witness.l2_green_claimed {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::L2GreenClaimAttempted);
    }
    if witness.l3_green_claimed {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::L3GreenClaimAttempted);
    }
    Ok(())
}

fn validate_surface(
    surface: &SmallModelOwnerProbeSurface,
) -> Result<(), SmallModelRuntimeHarnessOwnerProbeError> {
    validate_clean("surface_id", &surface.surface_id)?;
    validate_clean("path", &surface.path)?;
    if surface.observed_text.trim().len() < MIN_SURFACE_TEXT_BYTES {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::EmptySurface);
    }
    for marker in &surface.required_markers {
        validate_clean("required_marker", marker)?;
        if !surface.observed_text.contains(marker) {
            return Err(SmallModelRuntimeHarnessOwnerProbeError::MissingRequiredMarker(
                marker.clone(),
            ));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_clean("forbidden_marker", marker)?;
        if surface.observed_text.contains(marker) {
            return Err(SmallModelRuntimeHarnessOwnerProbeError::ForbiddenMarker(
                marker.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_lease(
    lease: &SmallModelOwnerProbeLease,
) -> Result<(), SmallModelRuntimeHarnessOwnerProbeError> {
    validate_clean("lease_id", &lease.lease_id)?;
    validate_clean("lane_id", &lease.lane_id)?;
    validate_clean("model_role", &lease.model_role)?;
    validate_clean("dry_run_artifact_ref", &lease.dry_run_artifact_ref)?;
    validate_clean("owner_approval_ref", &lease.owner_approval_ref)?;
    validate_clean("model_catalog_ref", &lease.model_catalog_ref)?;
    validate_clean("model_snapshot_ref", &lease.model_snapshot_ref)?;
    validate_clean("prompt_envelope_ref", &lease.prompt_envelope_ref)?;
    validate_clean("admission_ref", &lease.admission_ref)?;
    validate_clean("scope_rex_ref", &lease.scope_rex_ref)?;
    validate_clean("sovereign_gate_ref", &lease.sovereign_gate_ref)?;
    validate_clean("compatibility_fence", &lease.compatibility_fence)?;
    validate_clean("serialized_executor_ref", &lease.serialized_executor_ref)?;
    validate_clean("cancellation_ref", &lease.cancellation_ref)?;
    validate_clean("rollback_ref", &lease.rollback_ref)?;
    validate_clean("run_event_log_ref", &lease.run_event_log_ref)?;
    validate_clean("answer_packet_ref", &lease.answer_packet_ref)?;
    validate_clean("privacy_ref", &lease.privacy_ref)?;
    validate_clean("budget_ref", &lease.budget_ref)?;

    let id = lease.lease_id.clone();
    validate_prefix(
        &lease.dry_run_artifact_ref,
        DRY_RUN_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingDryRunArtifact(id.clone()),
    )?;
    validate_prefix(
        &lease.owner_approval_ref,
        OWNER_APPROVAL_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingOwnerApproval(id.clone()),
    )?;
    validate_prefix(
        &lease.model_catalog_ref,
        MODEL_CATALOG_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingModelCatalog(id.clone()),
    )?;
    validate_prefix(
        &lease.model_snapshot_ref,
        MODEL_SNAPSHOT_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingModelSnapshot(id.clone()),
    )?;
    validate_prefix(
        &lease.prompt_envelope_ref,
        PROMPT_ENVELOPE_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingPromptEnvelope(id.clone()),
    )?;
    validate_prefix(
        &lease.admission_ref,
        ADMISSION_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingAdmission(id.clone()),
    )?;
    validate_prefix(
        &lease.scope_rex_ref,
        SCOPE_REX_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingScopeRex(id.clone()),
    )?;
    validate_prefix(
        &lease.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingSovereignGate(id.clone()),
    )?;
    validate_prefix(
        &lease.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingCompatibilityFence(id.clone()),
    )?;
    validate_prefix(
        &lease.serialized_executor_ref,
        SERIAL_EXECUTOR_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingSerializedExecutor(id.clone()),
    )?;
    validate_prefix(
        &lease.cancellation_ref,
        CANCELLATION_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingCancellation(id.clone()),
    )?;
    validate_prefix(
        &lease.rollback_ref,
        ROLLBACK_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingRollback(id.clone()),
    )?;
    validate_prefix(
        &lease.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingRunEventLog(id.clone()),
    )?;
    validate_prefix(
        &lease.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingAnswerPacket(id.clone()),
    )?;
    validate_prefix(
        &lease.privacy_ref,
        PRIVACY_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingPrivacyFence(id.clone()),
    )?;
    validate_prefix(
        &lease.budget_ref,
        BUDGET_PREFIX,
        SmallModelRuntimeHarnessOwnerProbeError::MissingBudget(id.clone()),
    )?;
    if lease.phases.is_empty() {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::EmptyPhase);
    }
    for phase in required_phases() {
        if !lease.phases.contains(&phase) {
            return Err(SmallModelRuntimeHarnessOwnerProbeError::MissingPhase(
                phase.tag(),
            ));
        }
    }
    if !lease.approval_bound_to_dry_run {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::OwnerApprovalNotBound(
            id,
        ));
    }
    if !lease.runtime_probe_armed {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::RuntimeProbeNotArmed(
            lease.lease_id.clone(),
        ));
    }
    if lease.runtime_probe_executed {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::RuntimeProbeExecuted(
            lease.lease_id.clone(),
        ));
    }
    if lease.mutation_committed {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::MutationCommitted(
            lease.lease_id.clone(),
        ));
    }
    if lease.route_policy_mutated {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::RoutePolicyMutation(
            lease.lease_id.clone(),
        ));
    }
    if lease.gate_bypass {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::GateBypass(
            lease.lease_id.clone(),
        ));
    }
    if lease.answer_packet_suppressed {
        return Err(
            SmallModelRuntimeHarnessOwnerProbeError::AnswerPacketSuppression(lease.lease_id.clone()),
        );
    }
    if lease.hidden_route_authority {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::HiddenRouteAuthority(
            lease.lease_id.clone(),
        ));
    }
    if lease.hidden_chain_exposed {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::HiddenChainExposure(
            lease.lease_id.clone(),
        ));
    }
    if lease.hidden_cloud_fallback {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::HiddenCloudFallback(
            lease.lease_id.clone(),
        ));
    }
    if lease.subprocess_spawned {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::SubprocessSpawn(
            lease.lease_id.clone(),
        ));
    }
    if lease.autogenous_kernel_attempted {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::AutogenousKernelAttempt(
            lease.lease_id.clone(),
        ));
    }
    if lease.seventy_b_probe_attempted {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::SeventyBProbeAttempt(
            lease.lease_id.clone(),
        ));
    }
    if lease.max_context_tokens > MAX_CONTEXT_TOKENS {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::BudgetExceeded(
            "context_tokens",
        ));
    }
    if lease.prompt_tokens > MAX_PROMPT_TOKENS {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::BudgetExceeded(
            "prompt_tokens",
        ));
    }
    if lease.max_decode_tokens > MAX_DECODE_TOKENS {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::BudgetExceeded(
            "decode_tokens",
        ));
    }
    if lease.memory_budget_bytes > MAX_MEMORY_BUDGET_BYTES {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::BudgetExceeded(
            "memory_budget_bytes",
        ));
    }
    if lease.runtime_budget_seconds > MAX_RUNTIME_SECONDS {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::BudgetExceeded(
            "runtime_seconds",
        ));
    }
    if lease.runtime_bytes_loaded != 0 {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::RuntimeBytesLoaded(
            lease.lease_id.clone(),
        ));
    }
    if lease.model_bytes_loaded != 0 {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::ModelBytesLoaded(
            lease.lease_id.clone(),
        ));
    }
    if lease.transport_runtime_bytes_loaded != 0 {
        return Err(
            SmallModelRuntimeHarnessOwnerProbeError::TransportRuntimeBytesLoaded(
                lease.lease_id.clone(),
            ),
        );
    }
    Ok(())
}

fn required_phases() -> BTreeSet<SmallModelOwnerProbePhase> {
    [
        SmallModelOwnerProbePhase::DryRunArtifactBound,
        SmallModelOwnerProbePhase::OwnerApprovalLeaseBound,
        SmallModelOwnerProbePhase::ModelCatalogBound,
        SmallModelOwnerProbePhase::PromptEnvelopeCompiled,
        SmallModelOwnerProbePhase::AdmissionChecked,
        SmallModelOwnerProbePhase::ExecutorReserved,
        SmallModelOwnerProbePhase::CancellationArmed,
        SmallModelOwnerProbePhase::RollbackCheckpointRecorded,
        SmallModelOwnerProbePhase::RuntimeProbeArmed,
        SmallModelOwnerProbePhase::RuntimeExecutionDeferred,
        SmallModelOwnerProbePhase::RunEventLogged,
        SmallModelOwnerProbePhase::AnswerPacketDrafted,
        SmallModelOwnerProbePhase::EvidenceReviewPending,
    ]
    .into_iter()
    .collect()
}

fn validate_prefix(
    value: &str,
    prefix: &str,
    error: SmallModelRuntimeHarnessOwnerProbeError,
) -> Result<(), SmallModelRuntimeHarnessOwnerProbeError> {
    if value.starts_with(prefix) {
        Ok(())
    } else {
        Err(error)
    }
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessOwnerProbeError> {
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(SmallModelRuntimeHarnessOwnerProbeError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lease(id: &str, lane: &str) -> SmallModelOwnerProbeLease {
        SmallModelOwnerProbeLease::new(
            id,
            lane,
            "notes_research",
            "artifact:small_model_runtime_harness_dry_run_witness:result",
            "owner_approval:2026-06-05:small_model_runtime_probe_before_70b",
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:52a5ab",
            format!("prompt_envelope:{lane}"),
            format!("admission:{lane}"),
            format!("scope_rex:{lane}"),
            format!("sovereign_gate:{lane}"),
            format!("compat:{lane}:mlx-small-smoke-v1"),
            format!("serialized_executor:{lane}:single-flight"),
            format!("cancel:{lane}:owner-probe"),
            format!("rollback:{lane}:no-mutation"),
            format!("run_event_log:{lane}:dry-to-live-bridge"),
            format!("answer_packet:{lane}:visible-summary"),
            format!("privacy:{lane}:local-only-no-cloud"),
            format!("budget:{lane}:small-smoke"),
            required_phases(),
            4096,
            512,
            128,
            2 * 1024 * 1024 * 1024,
            60,
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
            0,
            0,
            0,
        )
        .unwrap()
    }

    fn surface(id: &str) -> SmallModelOwnerProbeSurface {
        SmallModelOwnerProbeSurface::new(
            id,
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR.to_string(),
            ],
            vec!["live 70B is done".to_string()],
            format!(
                "{} {} no claim promotes without visible proof. {}",
                "Epistemos is a local cognitive substrate.".repeat(12),
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR,
                "vault_research_route_with_packetized_mitigation"
            ),
        )
        .unwrap()
    }

    fn witness() -> SmallModelRuntimeHarnessOwnerProbeWitness {
        SmallModelRuntimeHarnessOwnerProbeWitness::new(
            "small_model_runtime_harness_owner_approved_probe_2026_06_05",
            "artifact:small_model_runtime_harness_dry_run_witness:result",
            SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "small_model_runtime_harness_owner_approval_only",
            vec![
                lease("lease-a", "qwen3_small_catalog_smoke"),
                lease("lease-b", "local_agent_notes_research_smoke"),
                lease("lease-c", "coding_tool_dry_run_smoke"),
            ],
            vec![surface("living_index"), surface("lattice_html")],
            2048,
            true,
            false,
            false,
            false,
        )
        .unwrap()
    }

    #[test]
    fn owner_probe_witness_metrics_and_address_are_deterministic() {
        let base = witness();
        let mut reversed_leases = base.leases.clone();
        reversed_leases.reverse();
        let reordered = SmallModelRuntimeHarnessOwnerProbeWitness::new(
            base.witness_id.clone(),
            base.dry_run_artifact_ref.clone(),
            base.guard_next_existing_work.clone(),
            base.capability_route_status.clone(),
            base.capability_next_bottleneck.clone(),
            base.product_build.clone(),
            base.pro_status.clone(),
            base.route_authority.clone(),
            reversed_leases,
            base.surfaces.clone(),
            base.metadata_bytes,
            base.l1_l2_l3_separated,
            base.mas_overclaim_attempted,
            base.l2_green_claimed,
            base.l3_green_claimed,
        )
        .unwrap();
        assert_eq!(base.metrics().lease_count, 3);
        assert_eq!(base.metrics().runtime_probe_armed_count, 3);
        assert_eq!(base.metrics().runtime_probe_executed_count, 0);
        assert_eq!(base.address(), reordered.address());
    }

    #[test]
    fn duplicate_lease_is_rejected() {
        let mut base = witness();
        base.leases[1] = base.leases[0].clone();
        assert!(matches!(
            SmallModelRuntimeHarnessOwnerProbeWitness::new(
                base.witness_id,
                base.dry_run_artifact_ref,
                base.guard_next_existing_work,
                base.capability_route_status,
                base.capability_next_bottleneck,
                base.product_build,
                base.pro_status,
                base.route_authority,
                base.leases,
                base.surfaces,
                base.metadata_bytes,
                base.l1_l2_l3_separated,
                base.mas_overclaim_attempted,
                base.l2_green_claimed,
                base.l3_green_claimed,
            ),
            Err(SmallModelRuntimeHarnessOwnerProbeError::DuplicateLease(_))
        ));
    }

    #[test]
    fn missing_owner_approval_is_rejected() {
        let result = SmallModelOwnerProbeLease::new(
            "lease-missing-owner",
            "qwen3_small_catalog_smoke",
            "notes_research",
            "artifact:small_model_runtime_harness_dry_run_witness:result",
            "chat:loose-approval",
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:52a5ab",
            "prompt_envelope:qwen3_small_catalog_smoke",
            "admission:qwen3_small_catalog_smoke",
            "scope_rex:qwen3_small_catalog_smoke",
            "sovereign_gate:qwen3_small_catalog_smoke",
            "compat:qwen3_small_catalog_smoke:mlx-small-smoke-v1",
            "serialized_executor:qwen3_small_catalog_smoke:single-flight",
            "cancel:qwen3_small_catalog_smoke:owner-probe",
            "rollback:qwen3_small_catalog_smoke:no-mutation",
            "run_event_log:qwen3_small_catalog_smoke:dry-to-live-bridge",
            "answer_packet:qwen3_small_catalog_smoke:visible-summary",
            "privacy:qwen3_small_catalog_smoke:local-only-no-cloud",
            "budget:qwen3_small_catalog_smoke:small-smoke",
            required_phases(),
            4096,
            512,
            128,
            2 * 1024 * 1024 * 1024,
            60,
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
            0,
            0,
            0,
        );
        assert!(matches!(
            result,
            Err(SmallModelRuntimeHarnessOwnerProbeError::MissingOwnerApproval(_))
        ));
    }

    #[test]
    fn runtime_execution_and_bytes_are_rejected() {
        let mut good = lease("lease-runtime", "qwen3_small_catalog_smoke");
        good.runtime_probe_executed = true;
        assert!(matches!(
            validate_lease(&good),
            Err(SmallModelRuntimeHarnessOwnerProbeError::RuntimeProbeExecuted(_))
        ));
        good.runtime_probe_executed = false;
        good.model_bytes_loaded = 1;
        assert!(matches!(
            validate_lease(&good),
            Err(SmallModelRuntimeHarnessOwnerProbeError::ModelBytesLoaded(_))
        ));
    }

    #[test]
    fn seventy_b_probe_is_rejected() {
        let mut good = lease("lease-70b", "qwen3_small_catalog_smoke");
        good.seventy_b_probe_attempted = true;
        assert!(matches!(
            validate_lease(&good),
            Err(SmallModelRuntimeHarnessOwnerProbeError::SeventyBProbeAttempt(_))
        ));
    }
}
