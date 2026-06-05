//! Small-model runtime harness dry-run witness.
//!
//! This L1 witness sits at `small_model_runtime_harness_dry_run_witness`.
//! It is still non-executing: no MLX runtime, model bytes, transport bytes,
//! route mutation, subprocess, or product promotion. It proves the harness can
//! replay a runtime-shaped transcript with admission, serialized executor,
//! cancellation, rollback, RunEventLog, AnswerPacket, and privacy fences before
//! any owner-approved runtime probe is considered.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR: &str =
    "small_model_runtime_harness_dry_run_witness";
pub const SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR: &str =
    "small_model_runtime_harness_owner_approved_probe";

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
const SAFETY_PLAN_PREFIX: &str = "artifact:small_model_runtime_harness_safety_plan:";
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
const MAX_METADATA_BYTES: u64 = 320 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-dry-run:phase
// Plane: Controller + Verification
// Residency: metadata-only dry-run phase.
pub enum SmallModelDryRunPhase {
    CatalogResolved,
    PromptEnvelopeCompiled,
    AdmissionChecked,
    ExecutorReserved,
    CancellationArmed,
    RollbackCheckpointRecorded,
    RunEventLogged,
    AnswerPacketDrafted,
    DryRunCompleted,
    EvidenceReviewed,
}

impl SmallModelDryRunPhase {
    fn tag(&self) -> &'static str {
        match self {
            Self::CatalogResolved => "catalog_resolved",
            Self::PromptEnvelopeCompiled => "prompt_envelope_compiled",
            Self::AdmissionChecked => "admission_checked",
            Self::ExecutorReserved => "executor_reserved",
            Self::CancellationArmed => "cancellation_armed",
            Self::RollbackCheckpointRecorded => "rollback_checkpoint_recorded",
            Self::RunEventLogged => "run_event_logged",
            Self::AnswerPacketDrafted => "answer_packet_drafted",
            Self::DryRunCompleted => "dry_run_completed",
            Self::EvidenceReviewed => "evidence_reviewed",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-dry-run:error
// Plane: Verification
// Residency: metadata-only dry-run rejection taxonomy.
pub enum SmallModelRuntimeHarnessDryRunError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyRecord,
    EmptySurface,
    EmptyPhase,
    DuplicateRecord(String),
    DuplicateSurface(String),
    MissingRequiredRecord(&'static str),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingPhase(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingSafetyPlanArtifact,
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
    MissingPromptEnvelope(String),
    MissingBudget(String),
    MissingLayerSeparation,
    DryRunOnlyMissing(String),
    RuntimeProbeEnabled(String),
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

impl fmt::Display for SmallModelRuntimeHarnessDryRunError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyRecord => write!(f, "missing dry-run record"),
            Self::EmptySurface => write!(f, "missing dry-run surface"),
            Self::EmptyPhase => write!(f, "missing dry-run phase"),
            Self::DuplicateRecord(id) => write!(f, "duplicate dry-run record `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate dry-run surface `{id}`"),
            Self::MissingRequiredRecord(id) => write!(f, "missing required dry-run record `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingSafetyPlanArtifact => write!(f, "missing safety-plan artifact ref"),
            Self::MissingAdmission(id) => write!(f, "record `{id}` missing admission ref"),
            Self::MissingScopeRex(id) => write!(f, "record `{id}` missing SCOPE-Rex ref"),
            Self::MissingSovereignGate(id) => {
                write!(f, "record `{id}` missing SovereignGate ref")
            }
            Self::MissingCompatibilityFence(id) => {
                write!(f, "record `{id}` missing compatibility fence")
            }
            Self::MissingSerializedExecutor(id) => {
                write!(f, "record `{id}` missing serialized executor")
            }
            Self::MissingCancellation(id) => write!(f, "record `{id}` missing cancellation ref"),
            Self::MissingRollback(id) => write!(f, "record `{id}` missing rollback ref"),
            Self::MissingRunEventLog(id) => write!(f, "record `{id}` missing RunEventLog"),
            Self::MissingAnswerPacket(id) => write!(f, "record `{id}` missing AnswerPacket"),
            Self::MissingPrivacyFence(id) => write!(f, "record `{id}` missing privacy fence"),
            Self::MissingPromptEnvelope(id) => write!(f, "record `{id}` missing prompt envelope"),
            Self::MissingBudget(id) => write!(f, "record `{id}` missing budget ref"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::DryRunOnlyMissing(id) => write!(f, "record `{id}` is not dry-run only"),
            Self::RuntimeProbeEnabled(id) => write!(f, "record `{id}` enabled runtime probe"),
            Self::MutationCommitted(id) => write!(f, "record `{id}` committed mutation"),
            Self::RoutePolicyMutation(id) => {
                write!(f, "record `{id}` attempted route policy mutation")
            }
            Self::GateBypass(id) => write!(f, "record `{id}` attempted gate bypass"),
            Self::AnswerPacketSuppression(id) => {
                write!(f, "record `{id}` suppressed AnswerPacket")
            }
            Self::HiddenRouteAuthority(id) => {
                write!(f, "record `{id}` attempted hidden route authority")
            }
            Self::HiddenChainExposure(id) => write!(f, "record `{id}` exposed hidden chain"),
            Self::HiddenCloudFallback(id) => write!(f, "record `{id}` allowed hidden cloud"),
            Self::SubprocessSpawn(id) => write!(f, "record `{id}` spawned subprocess"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "record `{id}` attempted autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "record `{id}` attempted 70B probe"),
            Self::BudgetExceeded(budget) => write!(f, "budget `{budget}` exceeded"),
            Self::RuntimeBytesLoaded(id) => write!(f, "record `{id}` loaded runtime bytes"),
            Self::ModelBytesLoaded(id) => write!(f, "record `{id}` loaded model bytes"),
            Self::TransportRuntimeBytesLoaded(id) => {
                write!(f, "record `{id}` loaded transport runtime bytes")
            }
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelRuntimeHarnessDryRunError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-dry-run:surface
// Plane: State + Verification
// Residency: local documentation surface scan; no runtime bytes.
pub struct SmallModelDryRunSurface {
    pub surface_id: String,
    pub path: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
    pub observed_text: String,
}

impl SmallModelDryRunSurface {
    pub fn new(
        surface_id: impl Into<String>,
        path: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
        observed_text: impl Into<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessDryRunError> {
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
// UAS: uas:small-model-runtime-harness-dry-run:record
// Plane: Controller + Verification
// Residency: metadata-only runtime-shaped transcript.
pub struct SmallModelDryRunRecord {
    pub run_id: String,
    pub lane_id: String,
    pub model_role: String,
    pub catalog_ref: String,
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
    pub phases: BTreeSet<SmallModelDryRunPhase>,
    pub max_context_tokens: u32,
    pub prompt_tokens: u32,
    pub max_decode_tokens: u32,
    pub memory_budget_bytes: u64,
    pub runtime_budget_seconds: u32,
    pub dry_run_only: bool,
    pub runtime_probe_enabled: bool,
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
    pub outcome: String,
}

impl SmallModelDryRunRecord {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        lane_id: impl Into<String>,
        model_role: impl Into<String>,
        catalog_ref: impl Into<String>,
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
        phases: BTreeSet<SmallModelDryRunPhase>,
        max_context_tokens: u32,
        prompt_tokens: u32,
        max_decode_tokens: u32,
        memory_budget_bytes: u64,
        runtime_budget_seconds: u32,
        dry_run_only: bool,
        runtime_probe_enabled: bool,
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
        outcome: impl Into<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessDryRunError> {
        let record = Self {
            run_id: run_id.into(),
            lane_id: lane_id.into(),
            model_role: model_role.into(),
            catalog_ref: catalog_ref.into(),
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
            dry_run_only,
            runtime_probe_enabled,
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
            outcome: outcome.into(),
        };
        validate_record(&record)?;
        Ok(record)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-dry-run:witness
// Plane: Controller + Verification
// Residency: metadata-only dry-run witness.
pub struct SmallModelRuntimeHarnessDryRunWitness {
    pub witness_id: String,
    pub safety_plan_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub records: Vec<SmallModelDryRunRecord>,
    pub surfaces: Vec<SmallModelDryRunSurface>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
}

impl SmallModelRuntimeHarnessDryRunWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        safety_plan_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        records: Vec<SmallModelDryRunRecord>,
        surfaces: Vec<SmallModelDryRunSurface>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessDryRunError> {
        let witness = Self {
            witness_id: witness_id.into(),
            safety_plan_artifact_ref: safety_plan_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            records,
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

    pub fn metrics(&self) -> SmallModelRuntimeHarnessDryRunMetrics {
        let lane_ids = self
            .records
            .iter()
            .map(|record| record.lane_id.as_str())
            .collect::<HashSet<_>>();
        let runtime_bytes_loaded = self
            .records
            .iter()
            .map(|record| record.runtime_bytes_loaded)
            .sum();
        let model_bytes_loaded = self
            .records
            .iter()
            .map(|record| record.model_bytes_loaded)
            .sum();
        let transport_runtime_bytes_loaded = self
            .records
            .iter()
            .map(|record| record.transport_runtime_bytes_loaded)
            .sum();
        SmallModelRuntimeHarnessDryRunMetrics {
            record_count: self.records.len() as u64,
            surface_count: self.surfaces.len() as u64,
            required_record_count: REQUIRED_LANES
                .iter()
                .filter(|id| lane_ids.contains(**id))
                .count() as u64,
            phase_count: self
                .records
                .iter()
                .map(|record| record.phases.len() as u64)
                .min()
                .unwrap_or(0),
            max_context_tokens: self
                .records
                .iter()
                .map(|record| record.max_context_tokens)
                .max()
                .unwrap_or(0),
            max_prompt_tokens: self
                .records
                .iter()
                .map(|record| record.prompt_tokens)
                .max()
                .unwrap_or(0),
            max_decode_tokens: self
                .records
                .iter()
                .map(|record| record.max_decode_tokens)
                .max()
                .unwrap_or(0),
            max_memory_budget_bytes: self
                .records
                .iter()
                .map(|record| record.memory_budget_bytes)
                .max()
                .unwrap_or(0),
            max_runtime_seconds: self
                .records
                .iter()
                .map(|record| record.runtime_budget_seconds)
                .max()
                .unwrap_or(0),
            runtime_probe_enabled_count: self
                .records
                .iter()
                .map(|record| u64::from(record.runtime_probe_enabled))
                .sum(),
            mutation_committed_count: self
                .records
                .iter()
                .map(|record| u64::from(record.mutation_committed))
                .sum(),
            route_policy_mutation_count: self
                .records
                .iter()
                .map(|record| u64::from(record.route_policy_mutated))
                .sum(),
            runtime_bytes_loaded,
            model_bytes_loaded,
            transport_runtime_bytes_loaded,
            metadata_bytes: self.metadata_bytes,
        }
    }

    pub fn address(&self) -> String {
        let mut record_parts = self
            .records
            .iter()
            .map(|record| {
                let mut phase_parts = record
                    .phases
                    .iter()
                    .map(SmallModelDryRunPhase::tag)
                    .collect::<Vec<_>>();
                phase_parts.sort();
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}",
                    record.run_id,
                    record.lane_id,
                    record.catalog_ref,
                    record.prompt_envelope_ref,
                    record.serialized_executor_ref,
                    record.answer_packet_ref,
                    record.outcome,
                    phase_parts.join(",")
                )
            })
            .collect::<Vec<_>>();
        record_parts.sort();
        let mut surface_parts = self
            .surfaces
            .iter()
            .map(|surface| format!("{}|{}", surface.surface_id, surface.path))
            .collect::<Vec<_>>();
        surface_parts.sort();
        let preimage = format!(
            "{}|{}|{}|{}|{}|{}",
            self.witness_id,
            self.safety_plan_artifact_ref,
            self.guard_next_existing_work,
            self.capability_route_status,
            record_parts.join(";"),
            surface_parts.join(";")
        );
        let digest = sha256_hex(preimage.as_bytes());
        format!("uas:small-model-runtime-harness-dry-run:sha256:{digest}")
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-dry-run:metrics
// Plane: Verification
// Residency: metadata-only dry-run metrics.
pub struct SmallModelRuntimeHarnessDryRunMetrics {
    pub record_count: u64,
    pub surface_count: u64,
    pub required_record_count: u64,
    pub phase_count: u64,
    pub max_context_tokens: u32,
    pub max_prompt_tokens: u32,
    pub max_decode_tokens: u32,
    pub max_memory_budget_bytes: u64,
    pub max_runtime_seconds: u32,
    pub runtime_probe_enabled_count: u64,
    pub mutation_committed_count: u64,
    pub route_policy_mutation_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

fn validate_witness(
    witness: &SmallModelRuntimeHarnessDryRunWitness,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    validate_token("witness_id", &witness.witness_id)?;
    validate_prefixed(
        "safety_plan_artifact_ref",
        &witness.safety_plan_artifact_ref,
        SAFETY_PLAN_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingSafetyPlanArtifact)?;
    validate_token(
        "guard_next_existing_work",
        &witness.guard_next_existing_work,
    )?;
    validate_token("capability_route_status", &witness.capability_route_status)?;
    validate_token(
        "capability_next_bottleneck",
        &witness.capability_next_bottleneck,
    )?;
    validate_token("route_authority", &witness.route_authority)?;
    if witness.guard_next_existing_work != SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR
        && witness.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessDryRunError::GuardCursorMismatch);
    }
    if witness.capability_next_bottleneck != SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR
        && witness.capability_next_bottleneck
            != SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR
    {
        return Err(SmallModelRuntimeHarnessDryRunError::CapabilityStatusMismatch);
    }
    if witness.capability_route_status != "vault_research_route_with_packetized_mitigation" {
        return Err(SmallModelRuntimeHarnessDryRunError::CapabilityStatusMismatch);
    }
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
    {
        return Err(SmallModelRuntimeHarnessDryRunError::ProductStatusMismatch);
    }
    if witness.route_authority != "small_model_runtime_harness_dry_run_witness_only" {
        return Err(SmallModelRuntimeHarnessDryRunError::ProductStatusMismatch);
    }
    validate_records(&witness.records)?;
    validate_surfaces(&witness.surfaces)?;
    if !witness.l1_l2_l3_separated {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingLayerSeparation);
    }
    if witness.mas_overclaim_attempted {
        return Err(SmallModelRuntimeHarnessDryRunError::MasOverclaimAttempted);
    }
    if witness.l2_green_claimed {
        return Err(SmallModelRuntimeHarnessDryRunError::L2GreenClaimAttempted);
    }
    if witness.l3_green_claimed {
        return Err(SmallModelRuntimeHarnessDryRunError::L3GreenClaimAttempted);
    }
    if witness.metadata_bytes > MAX_METADATA_BYTES {
        return Err(SmallModelRuntimeHarnessDryRunError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_surfaces(
    surfaces: &[SmallModelDryRunSurface],
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    if surfaces.is_empty() {
        return Err(SmallModelRuntimeHarnessDryRunError::EmptySurface);
    }
    let mut ids = HashSet::with_capacity(surfaces.len());
    for surface in surfaces {
        validate_surface(surface)?;
        if !ids.insert(surface.surface_id.as_str()) {
            return Err(SmallModelRuntimeHarnessDryRunError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(
    surface: &SmallModelDryRunSurface,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    validate_token("surface_id", &surface.surface_id)?;
    validate_path("path", &surface.path)?;
    if surface.observed_text.len() < MIN_SURFACE_TEXT_BYTES {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingField(
            "observed_text",
        ));
    }
    for marker in &surface.required_markers {
        validate_marker(marker)?;
        if !surface.observed_text.contains(marker) {
            return Err(SmallModelRuntimeHarnessDryRunError::MissingRequiredMarker(
                marker.clone(),
            ));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_marker(marker)?;
        if surface.observed_text.contains(marker) {
            return Err(SmallModelRuntimeHarnessDryRunError::ForbiddenMarker(
                marker.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_records(
    records: &[SmallModelDryRunRecord],
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    if records.is_empty() {
        return Err(SmallModelRuntimeHarnessDryRunError::EmptyRecord);
    }
    let mut run_ids = HashSet::with_capacity(records.len());
    let mut lane_ids = HashSet::with_capacity(records.len());
    for record in records {
        validate_record(record)?;
        if !run_ids.insert(record.run_id.as_str()) {
            return Err(SmallModelRuntimeHarnessDryRunError::DuplicateRecord(
                record.run_id.clone(),
            ));
        }
        lane_ids.insert(record.lane_id.as_str());
    }
    for required in REQUIRED_LANES {
        if !lane_ids.contains(required) {
            return Err(SmallModelRuntimeHarnessDryRunError::MissingRequiredRecord(
                required,
            ));
        }
    }
    Ok(())
}

fn validate_record(
    record: &SmallModelDryRunRecord,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    validate_token("run_id", &record.run_id)?;
    validate_token("lane_id", &record.lane_id)?;
    validate_token("model_role", &record.model_role)?;
    validate_token("outcome", &record.outcome)?;
    validate_prefixed("catalog_ref", &record.catalog_ref, "model_catalog:")?;
    validate_prefixed(
        "prompt_envelope_ref",
        &record.prompt_envelope_ref,
        PROMPT_ENVELOPE_PREFIX,
    )
    .map_err(|_| {
        SmallModelRuntimeHarnessDryRunError::MissingPromptEnvelope(record.run_id.clone())
    })?;
    validate_prefixed("admission_ref", &record.admission_ref, ADMISSION_PREFIX).map_err(|_| {
        SmallModelRuntimeHarnessDryRunError::MissingAdmission(record.run_id.clone())
    })?;
    validate_prefixed("scope_rex_ref", &record.scope_rex_ref, SCOPE_REX_PREFIX)
        .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingScopeRex(record.run_id.clone()))?;
    validate_prefixed(
        "sovereign_gate_ref",
        &record.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
    )
    .map_err(|_| {
        SmallModelRuntimeHarnessDryRunError::MissingSovereignGate(record.run_id.clone())
    })?;
    validate_prefixed(
        "compatibility_fence",
        &record.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
    )
    .map_err(|_| {
        SmallModelRuntimeHarnessDryRunError::MissingCompatibilityFence(record.run_id.clone())
    })?;
    validate_prefixed(
        "serialized_executor_ref",
        &record.serialized_executor_ref,
        SERIAL_EXECUTOR_PREFIX,
    )
    .map_err(|_| {
        SmallModelRuntimeHarnessDryRunError::MissingSerializedExecutor(record.run_id.clone())
    })?;
    validate_prefixed(
        "cancellation_ref",
        &record.cancellation_ref,
        CANCELLATION_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingCancellation(record.run_id.clone()))?;
    validate_prefixed("rollback_ref", &record.rollback_ref, ROLLBACK_PREFIX)
        .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingRollback(record.run_id.clone()))?;
    validate_prefixed(
        "run_event_log_ref",
        &record.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingRunEventLog(record.run_id.clone()))?;
    validate_prefixed(
        "answer_packet_ref",
        &record.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
    )
    .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingAnswerPacket(record.run_id.clone()))?;
    validate_prefixed("privacy_ref", &record.privacy_ref, PRIVACY_PREFIX).map_err(|_| {
        SmallModelRuntimeHarnessDryRunError::MissingPrivacyFence(record.run_id.clone())
    })?;
    validate_prefixed("budget_ref", &record.budget_ref, BUDGET_PREFIX)
        .map_err(|_| SmallModelRuntimeHarnessDryRunError::MissingBudget(record.run_id.clone()))?;
    require_phase(record, SmallModelDryRunPhase::CatalogResolved)?;
    require_phase(record, SmallModelDryRunPhase::PromptEnvelopeCompiled)?;
    require_phase(record, SmallModelDryRunPhase::AdmissionChecked)?;
    require_phase(record, SmallModelDryRunPhase::ExecutorReserved)?;
    require_phase(record, SmallModelDryRunPhase::CancellationArmed)?;
    require_phase(record, SmallModelDryRunPhase::RollbackCheckpointRecorded)?;
    require_phase(record, SmallModelDryRunPhase::RunEventLogged)?;
    require_phase(record, SmallModelDryRunPhase::AnswerPacketDrafted)?;
    require_phase(record, SmallModelDryRunPhase::DryRunCompleted)?;
    require_phase(record, SmallModelDryRunPhase::EvidenceReviewed)?;
    if record.max_context_tokens == 0 || record.max_context_tokens > MAX_CONTEXT_TOKENS {
        return Err(SmallModelRuntimeHarnessDryRunError::BudgetExceeded(
            "max_context_tokens",
        ));
    }
    if record.prompt_tokens == 0
        || record.prompt_tokens > MAX_PROMPT_TOKENS
        || record.prompt_tokens > record.max_context_tokens
    {
        return Err(SmallModelRuntimeHarnessDryRunError::BudgetExceeded(
            "prompt_tokens",
        ));
    }
    if record.max_decode_tokens == 0 || record.max_decode_tokens > MAX_DECODE_TOKENS {
        return Err(SmallModelRuntimeHarnessDryRunError::BudgetExceeded(
            "max_decode_tokens",
        ));
    }
    if record.memory_budget_bytes == 0 || record.memory_budget_bytes > MAX_MEMORY_BUDGET_BYTES {
        return Err(SmallModelRuntimeHarnessDryRunError::BudgetExceeded(
            "memory_budget_bytes",
        ));
    }
    if record.runtime_budget_seconds == 0 || record.runtime_budget_seconds > MAX_RUNTIME_SECONDS {
        return Err(SmallModelRuntimeHarnessDryRunError::BudgetExceeded(
            "runtime_budget_seconds",
        ));
    }
    if !record.dry_run_only {
        return Err(SmallModelRuntimeHarnessDryRunError::DryRunOnlyMissing(
            record.run_id.clone(),
        ));
    }
    if record.runtime_probe_enabled {
        return Err(SmallModelRuntimeHarnessDryRunError::RuntimeProbeEnabled(
            record.run_id.clone(),
        ));
    }
    if record.mutation_committed {
        return Err(SmallModelRuntimeHarnessDryRunError::MutationCommitted(
            record.run_id.clone(),
        ));
    }
    if record.route_policy_mutated {
        return Err(SmallModelRuntimeHarnessDryRunError::RoutePolicyMutation(
            record.run_id.clone(),
        ));
    }
    if record.gate_bypass {
        return Err(SmallModelRuntimeHarnessDryRunError::GateBypass(
            record.run_id.clone(),
        ));
    }
    if record.answer_packet_suppressed {
        return Err(
            SmallModelRuntimeHarnessDryRunError::AnswerPacketSuppression(record.run_id.clone()),
        );
    }
    if record.hidden_route_authority {
        return Err(SmallModelRuntimeHarnessDryRunError::HiddenRouteAuthority(
            record.run_id.clone(),
        ));
    }
    if record.hidden_chain_exposed {
        return Err(SmallModelRuntimeHarnessDryRunError::HiddenChainExposure(
            record.run_id.clone(),
        ));
    }
    if record.hidden_cloud_fallback {
        return Err(SmallModelRuntimeHarnessDryRunError::HiddenCloudFallback(
            record.run_id.clone(),
        ));
    }
    if record.subprocess_spawned {
        return Err(SmallModelRuntimeHarnessDryRunError::SubprocessSpawn(
            record.run_id.clone(),
        ));
    }
    if record.autogenous_kernel_attempted {
        return Err(
            SmallModelRuntimeHarnessDryRunError::AutogenousKernelAttempt(record.run_id.clone()),
        );
    }
    if record.seventy_b_probe_attempted {
        return Err(SmallModelRuntimeHarnessDryRunError::SeventyBProbeAttempt(
            record.run_id.clone(),
        ));
    }
    if record.runtime_bytes_loaded > 0 {
        return Err(SmallModelRuntimeHarnessDryRunError::RuntimeBytesLoaded(
            record.run_id.clone(),
        ));
    }
    if record.model_bytes_loaded > 0 {
        return Err(SmallModelRuntimeHarnessDryRunError::ModelBytesLoaded(
            record.run_id.clone(),
        ));
    }
    if record.transport_runtime_bytes_loaded > 0 {
        return Err(
            SmallModelRuntimeHarnessDryRunError::TransportRuntimeBytesLoaded(record.run_id.clone()),
        );
    }
    if record.outcome != "dry_run_passed_no_runtime" {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingField("outcome"));
    }
    Ok(())
}

fn require_phase(
    record: &SmallModelDryRunRecord,
    phase: SmallModelDryRunPhase,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    if record.phases.contains(&phase) {
        return Ok(());
    }
    Err(SmallModelRuntimeHarnessDryRunError::MissingPhase(
        phase.tag(),
    ))
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    if value.trim() != value {
        return Err(SmallModelRuntimeHarnessDryRunError::FieldHasSurroundingWhitespace(field));
    }
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingField(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SmallModelRuntimeHarnessDryRunError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn validate_marker(value: &str) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    if value.trim() != value || value.is_empty() {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingField("marker"));
    }
    if value.chars().any(char::is_control) {
        return Err(SmallModelRuntimeHarnessDryRunError::FieldContainsControlCharacter("marker"));
    }
    Ok(())
}

fn validate_path(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    validate_token(field, value)?;
    if value.starts_with('/') || value.contains("..") {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingField(field));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelRuntimeHarnessDryRunError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelRuntimeHarnessDryRunError::MissingField(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn phases() -> BTreeSet<SmallModelDryRunPhase> {
        BTreeSet::from([
            SmallModelDryRunPhase::CatalogResolved,
            SmallModelDryRunPhase::PromptEnvelopeCompiled,
            SmallModelDryRunPhase::AdmissionChecked,
            SmallModelDryRunPhase::ExecutorReserved,
            SmallModelDryRunPhase::CancellationArmed,
            SmallModelDryRunPhase::RollbackCheckpointRecorded,
            SmallModelDryRunPhase::RunEventLogged,
            SmallModelDryRunPhase::AnswerPacketDrafted,
            SmallModelDryRunPhase::DryRunCompleted,
            SmallModelDryRunPhase::EvidenceReviewed,
        ])
    }

    fn record(id: &str) -> SmallModelDryRunRecord {
        SmallModelDryRunRecord::new(
            format!("dry_run:{id}"),
            id,
            "notes_research_coding",
            format!("model_catalog:{id}:mlx-small"),
            format!("prompt_envelope:{id}:dry-run"),
            format!("admission:{id}:dry-run"),
            format!("scope_rex:{id}:dry-run"),
            format!("sovereign_gate:{id}:dry-run"),
            format!("compat:{id}:dry-run:v1"),
            format!("serialized_executor:{id}:mlx"),
            format!("cancel:{id}:owner-abort"),
            format!("rollback:{id}:no-state-mutation"),
            format!("run_event_log:{id}:dry-run"),
            format!("answer_packet:{id}:dry-run"),
            format!("privacy:{id}:local-only"),
            format!("budget:{id}:dry-run"),
            phases(),
            40960,
            4096,
            384,
            4 * 1024 * 1024 * 1024,
            180,
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
            "dry_run_passed_no_runtime",
        )
        .expect("valid dry-run record")
    }

    fn surface() -> SmallModelDryRunSurface {
        SmallModelDryRunSurface::new(
            "living_index",
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR.to_string(),
            ],
            vec!["MLX runtime probe executed".to_string()],
            format!(
                "Epistemos is a local cognitive substrate. {}. no claim promotes without visible proof. {}",
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR,
                "x".repeat(320)
            ),
        )
        .expect("valid surface")
    }

    fn witness_with_records(
        records: Vec<SmallModelDryRunRecord>,
    ) -> Result<SmallModelRuntimeHarnessDryRunWitness, SmallModelRuntimeHarnessDryRunError> {
        SmallModelRuntimeHarnessDryRunWitness::new(
            "small_model_runtime_harness_dry_run_witness_2026_06_05",
            "artifact:small_model_runtime_harness_safety_plan:result",
            SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "small_model_runtime_harness_dry_run_witness_only",
            records,
            vec![surface()],
            128 * 1024,
            true,
            false,
            false,
            false,
        )
    }

    #[test]
    fn valid_dry_run_witness_preserves_zero_runtime() {
        let witness = witness_with_records(vec![
            record("qwen3_small_catalog_smoke"),
            record("local_agent_notes_research_smoke"),
            record("coding_tool_dry_run_smoke"),
        ])
        .expect("valid witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.required_record_count, 3);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.transport_runtime_bytes_loaded, 0);
        assert_eq!(
            witness.guard_next_existing_work,
            SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR
        );
    }

    #[test]
    fn rejects_missing_duplicate_and_runtime_records() {
        let missing = witness_with_records(vec![
            record("qwen3_small_catalog_smoke"),
            record("local_agent_notes_research_smoke"),
        ]);
        assert!(matches!(
            missing,
            Err(SmallModelRuntimeHarnessDryRunError::MissingRequiredRecord(
                "coding_tool_dry_run_smoke"
            ))
        ));

        let duplicate = witness_with_records(vec![
            record("qwen3_small_catalog_smoke"),
            record("qwen3_small_catalog_smoke"),
            record("coding_tool_dry_run_smoke"),
        ]);
        assert!(matches!(
            duplicate,
            Err(SmallModelRuntimeHarnessDryRunError::DuplicateRecord(_))
        ));

        let mut live = record("coding_tool_dry_run_smoke");
        live.runtime_probe_enabled = true;
        let live = witness_with_records(vec![
            record("qwen3_small_catalog_smoke"),
            record("local_agent_notes_research_smoke"),
            live,
        ]);
        assert!(matches!(
            live,
            Err(SmallModelRuntimeHarnessDryRunError::RuntimeProbeEnabled(_))
        ));
    }

    #[test]
    fn rejects_missing_refs_bytes_and_mutations() {
        let mut missing_packet = record("coding_tool_dry_run_smoke");
        missing_packet.answer_packet_ref = "missing".to_string();
        assert!(matches!(
            witness_with_records(vec![
                record("qwen3_small_catalog_smoke"),
                record("local_agent_notes_research_smoke"),
                missing_packet,
            ]),
            Err(SmallModelRuntimeHarnessDryRunError::MissingAnswerPacket(_))
        ));

        let mut bytes = record("coding_tool_dry_run_smoke");
        bytes.model_bytes_loaded = 1;
        assert!(matches!(
            witness_with_records(vec![
                record("qwen3_small_catalog_smoke"),
                record("local_agent_notes_research_smoke"),
                bytes,
            ]),
            Err(SmallModelRuntimeHarnessDryRunError::ModelBytesLoaded(_))
        ));

        let mut mutation = record("coding_tool_dry_run_smoke");
        mutation.mutation_committed = true;
        assert!(matches!(
            witness_with_records(vec![
                record("qwen3_small_catalog_smoke"),
                record("local_agent_notes_research_smoke"),
                mutation,
            ]),
            Err(SmallModelRuntimeHarnessDryRunError::MutationCommitted(_))
        ));
    }

    #[test]
    fn deterministic_address_ignores_record_order() {
        let forward = witness_with_records(vec![
            record("qwen3_small_catalog_smoke"),
            record("local_agent_notes_research_smoke"),
            record("coding_tool_dry_run_smoke"),
        ])
        .expect("forward witness");
        let reversed = witness_with_records(vec![
            record("coding_tool_dry_run_smoke"),
            record("local_agent_notes_research_smoke"),
            record("qwen3_small_catalog_smoke"),
        ])
        .expect("reversed witness");
        assert_eq!(forward.address(), reversed.address());
    }
}
