//! Small-model runtime harness first-token runtime probe.
//!
//! This L1 witness sits at
//! `small_model_runtime_harness_first_token_runtime_probe`. It proves a
//! retained, redacted, owner-approved small local MLX probe reached exactly one
//! first token through a bounded harness and visible proof packet. It is not a
//! product-route, MAS, 70B, or long-context-shard promotion.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR: &str =
    "small_model_runtime_harness_first_token_runtime_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_answer_packet_runtime_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const LOGGED_SMOKE_PREFIX: &str = "artifact:small_model_runtime_harness_logged_runtime_smoke:";
const LIVE_PROBE_SIDECAR_PREFIX: &str =
    "artifact:small_model_runtime_harness_first_token_runtime_probe:live_probe:";
const MODEL_CATALOG_PREFIX: &str = "model_catalog:";
const MODEL_SNAPSHOT_PREFIX: &str = "model_snapshot:local:";
const MODEL_CONFIG_PREFIX: &str = "model_config:";
const TOKENIZER_PREFIX: &str = "tokenizer:";
const PROMPT_ENVELOPE_PREFIX: &str = "prompt_envelope:";
const TOKEN_SHA_PREFIX: &str = "token_sha256:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CANCELLATION_PREFIX: &str = "cancel:";
const PRIVACY_PREFIX: &str = "privacy:";
const BUDGET_PREFIX: &str = "budget:";
const MIN_SURFACE_TEXT_BYTES: usize = 256;
const MAX_CONTEXT_TOKENS: u32 = 65_536;
const MAX_PROMPT_TOKENS: u32 = 256;
const MAX_DECODE_TOKENS: u32 = 1;
const MAX_MEMORY_BUDGET_BYTES: u64 = 6 * 1024 * 1024 * 1024;
const MAX_MODEL_BYTES_LOADED: u64 = 4 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u32 = 180;
const MAX_LOAD_MS: u32 = 60_000;
const MAX_FIRST_TOKEN_MS: u32 = 60_000;
const MAX_TOTAL_MS: u32 = 180_000;
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MIN_TOKEN_SHA_LEN: usize = 71;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:phase
// Plane: Controller + Verification
// Residency: retained small-model runtime proof phase.
pub enum SmallModelFirstTokenRuntimeProbePhase {
    LoggedSmokeArtifactBound,
    LocalSnapshotVerified,
    ConfigAndTokenizerVerified,
    OwnerApprovalConfirmed,
    PromptEnvelopeCompiled,
    AdmissionChecked,
    SerializedExecutorEntered,
    RuntimeStarted,
    FirstTokenObserved,
    TokenRedacted,
    RuntimeCompleted,
    RollbackVerified,
    RunEventLogged,
    AnswerPacketDrafted,
    MutationReviewPassed,
    EvidenceReviewPending,
}

impl SmallModelFirstTokenRuntimeProbePhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::LoggedSmokeArtifactBound => "logged_smoke_artifact_bound",
            Self::LocalSnapshotVerified => "local_snapshot_verified",
            Self::ConfigAndTokenizerVerified => "config_and_tokenizer_verified",
            Self::OwnerApprovalConfirmed => "owner_approval_confirmed",
            Self::PromptEnvelopeCompiled => "prompt_envelope_compiled",
            Self::AdmissionChecked => "admission_checked",
            Self::SerializedExecutorEntered => "serialized_executor_entered",
            Self::RuntimeStarted => "runtime_started",
            Self::FirstTokenObserved => "first_token_observed",
            Self::TokenRedacted => "token_redacted",
            Self::RuntimeCompleted => "runtime_completed",
            Self::RollbackVerified => "rollback_verified",
            Self::RunEventLogged => "run_event_logged",
            Self::AnswerPacketDrafted => "answer_packet_drafted",
            Self::MutationReviewPassed => "mutation_review_passed",
            Self::EvidenceReviewPending => "evidence_review_pending",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:error
// Plane: Verification
// Residency: retained first-token runtime rejection taxonomy.
pub enum SmallModelRuntimeHarnessFirstTokenProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyRun,
    EmptySurface,
    EmptyPhase,
    DuplicateRun(String),
    DuplicateSurface(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingPhase(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingLoggedSmokeArtifact(String),
    MissingLiveProbeSidecar(String),
    MissingModelCatalog(String),
    MissingModelSnapshot(String),
    MissingModelConfig(String),
    MissingTokenizer(String),
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
    MissingTokenDigest(String),
    MissingLayerSeparation,
    OwnerApprovalMissing(String),
    SnapshotMissing(String),
    RuntimeNotStarted(String),
    RuntimeNotCompleted(String),
    FirstTokenMissing(String),
    OutputTokenCountMismatch(String),
    TokenDigestMalformed(String),
    TokenTextRetained(String),
    PromptUserData(String),
    MutationCommitted(String),
    RoutePolicyMutation(String),
    GateBypass(String),
    AnswerPacketSuppression(String),
    HiddenRouteAuthority(String),
    HiddenChainExposure(String),
    HiddenCloudFallback(String),
    AppPathSubprocessSpawn(String),
    AutogenousKernelAttempt(String),
    SeventyBProbeAttempt(String),
    LongContextShardProbeAttempt(String),
    RuntimeBytesNotLoaded(String),
    ModelBytesNotLoaded(String),
    RuntimeBytesOverBudget(String),
    ModelBytesOverBudget(String),
    BudgetExceeded(&'static str),
    MasOverclaimAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelRuntimeHarnessFirstTokenProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyRun => write!(f, "missing first-token runtime run"),
            Self::EmptySurface => write!(f, "missing first-token runtime surface"),
            Self::EmptyPhase => write!(f, "missing first-token runtime phase"),
            Self::DuplicateRun(id) => write!(f, "duplicate first-token run `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingLoggedSmokeArtifact(id) => {
                write!(f, "run `{id}` missing logged-smoke artifact ref")
            }
            Self::MissingLiveProbeSidecar(id) => write!(f, "run `{id}` missing sidecar ref"),
            Self::MissingModelCatalog(id) => write!(f, "run `{id}` missing model catalog ref"),
            Self::MissingModelSnapshot(id) => write!(f, "run `{id}` missing model snapshot ref"),
            Self::MissingModelConfig(id) => write!(f, "run `{id}` missing model config ref"),
            Self::MissingTokenizer(id) => write!(f, "run `{id}` missing tokenizer ref"),
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
            Self::MissingTokenDigest(id) => write!(f, "run `{id}` missing token digest"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::OwnerApprovalMissing(id) => write!(f, "run `{id}` missing owner approval"),
            Self::SnapshotMissing(id) => write!(f, "run `{id}` missing local snapshot"),
            Self::RuntimeNotStarted(id) => write!(f, "run `{id}` did not start runtime"),
            Self::RuntimeNotCompleted(id) => write!(f, "run `{id}` did not complete runtime"),
            Self::FirstTokenMissing(id) => write!(f, "run `{id}` did not observe first token"),
            Self::OutputTokenCountMismatch(id) => {
                write!(f, "run `{id}` did not observe exactly one output token")
            }
            Self::TokenDigestMalformed(id) => write!(f, "run `{id}` has malformed token digest"),
            Self::TokenTextRetained(id) => write!(f, "run `{id}` retained raw token text"),
            Self::PromptUserData(id) => write!(f, "run `{id}` used user data in prompt"),
            Self::MutationCommitted(id) => write!(f, "run `{id}` committed mutation"),
            Self::RoutePolicyMutation(id) => write!(f, "run `{id}` mutated route policy"),
            Self::GateBypass(id) => write!(f, "run `{id}` bypassed gate"),
            Self::AnswerPacketSuppression(id) => write!(f, "run `{id}` suppressed AnswerPacket"),
            Self::HiddenRouteAuthority(id) => write!(f, "run `{id}` attempted hidden authority"),
            Self::HiddenChainExposure(id) => write!(f, "run `{id}` exposed hidden chain"),
            Self::HiddenCloudFallback(id) => write!(f, "run `{id}` allowed hidden cloud"),
            Self::AppPathSubprocessSpawn(id) => write!(f, "run `{id}` spawned in app path"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "run `{id}` attempted autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "run `{id}` attempted 70B probe"),
            Self::LongContextShardProbeAttempt(id) => {
                write!(f, "run `{id}` attempted long-context shard probe")
            }
            Self::RuntimeBytesNotLoaded(id) => write!(f, "run `{id}` did not load runtime bytes"),
            Self::ModelBytesNotLoaded(id) => write!(f, "run `{id}` did not load model bytes"),
            Self::RuntimeBytesOverBudget(id) => write!(f, "run `{id}` runtime bytes over budget"),
            Self::ModelBytesOverBudget(id) => write!(f, "run `{id}` model bytes over budget"),
            Self::BudgetExceeded(budget) => write!(f, "budget `{budget}` exceeded"),
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelRuntimeHarnessFirstTokenProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:surface
// Plane: State + Verification
// Residency: visible canon/source surface evidence.
pub struct SmallModelFirstTokenRuntimeProbeSurface {
    pub surface_id: String,
    pub source_ref: String,
    pub observed_text: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
}

impl SmallModelFirstTokenRuntimeProbeSurface {
    pub fn new(
        surface_id: impl Into<String>,
        source_ref: impl Into<String>,
        observed_text: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessFirstTokenProbeError> {
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
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::EmptySurface);
        }
        for marker in &surface.required_markers {
            validate_clean("required_marker", marker)?;
            if !surface.observed_text.contains(marker) {
                return Err(
                    SmallModelRuntimeHarnessFirstTokenProbeError::MissingRequiredMarker(
                        marker.clone(),
                    ),
                );
            }
        }
        for marker in &surface.forbidden_markers {
            validate_clean("forbidden_marker", marker)?;
            if surface.observed_text.contains(marker) {
                return Err(
                    SmallModelRuntimeHarnessFirstTokenProbeError::ForbiddenMarker(marker.clone()),
                );
            }
        }
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:run
// Plane: Controller + Verification
// Residency: retained first-token runtime run.
pub struct SmallModelFirstTokenRuntimeProbeRun {
    pub run_id: String,
    pub lane_id: String,
    pub logged_smoke_artifact_ref: String,
    pub live_probe_sidecar_ref: String,
    pub model_catalog_ref: String,
    pub model_snapshot_ref: String,
    pub model_config_ref: String,
    pub tokenizer_ref: String,
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
    pub token_digest_ref: String,
    pub phases: Vec<SmallModelFirstTokenRuntimeProbePhase>,
    pub context_tokens: u32,
    pub prompt_tokens: u32,
    pub decode_tokens: u32,
    pub memory_budget_bytes: u64,
    pub runtime_budget_seconds: u32,
    pub load_ms: u32,
    pub first_token_ms: u32,
    pub total_ms: u32,
    pub chunks_observed: u32,
    pub first_token_utf8_len: u32,
    pub output_token_count: u32,
    pub owner_approved: bool,
    pub local_snapshot_exists: bool,
    pub runtime_started: bool,
    pub runtime_completed: bool,
    pub first_token_observed: bool,
    pub raw_token_text_retained: bool,
    pub prompt_contains_user_data: bool,
    pub committed_mutation: bool,
    pub route_policy_mutation_attempted: bool,
    pub gate_bypass_attempted: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_route_authority_attempted: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub subprocess_spawned_in_app_path: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub long_context_shard_probe_attempted: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
}

impl SmallModelFirstTokenRuntimeProbeRun {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        lane_id: impl Into<String>,
        logged_smoke_artifact_ref: impl Into<String>,
        live_probe_sidecar_ref: impl Into<String>,
        model_catalog_ref: impl Into<String>,
        model_snapshot_ref: impl Into<String>,
        model_config_ref: impl Into<String>,
        tokenizer_ref: impl Into<String>,
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
        token_digest_ref: impl Into<String>,
        phases: Vec<SmallModelFirstTokenRuntimeProbePhase>,
    ) -> Result<Self, SmallModelRuntimeHarnessFirstTokenProbeError> {
        let run = Self {
            run_id: run_id.into(),
            lane_id: lane_id.into(),
            logged_smoke_artifact_ref: logged_smoke_artifact_ref.into(),
            live_probe_sidecar_ref: live_probe_sidecar_ref.into(),
            model_catalog_ref: model_catalog_ref.into(),
            model_snapshot_ref: model_snapshot_ref.into(),
            model_config_ref: model_config_ref.into(),
            tokenizer_ref: tokenizer_ref.into(),
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
            token_digest_ref: token_digest_ref.into(),
            phases,
            context_tokens: 65_536,
            prompt_tokens: 8,
            decode_tokens: 1,
            memory_budget_bytes: 4 * 1024 * 1024 * 1024,
            runtime_budget_seconds: 180,
            load_ms: 1_525,
            first_token_ms: 737,
            total_ms: 2_261,
            chunks_observed: 1,
            first_token_utf8_len: 1,
            output_token_count: 1,
            owner_approved: true,
            local_snapshot_exists: true,
            runtime_started: true,
            runtime_completed: true,
            first_token_observed: true,
            raw_token_text_retained: false,
            prompt_contains_user_data: false,
            committed_mutation: false,
            route_policy_mutation_attempted: false,
            gate_bypass_attempted: false,
            answer_packet_suppressed: false,
            hidden_route_authority_attempted: false,
            hidden_chain_exposed: false,
            hidden_cloud_fallback_allowed: false,
            subprocess_spawned_in_app_path: false,
            autogenous_kernel_attempted: false,
            seventy_b_probe_attempted: false,
            long_context_shard_probe_attempted: false,
            runtime_bytes_loaded: 2_153_272_351,
            model_bytes_loaded: 2_153_272_351,
        };
        run.validate()?;
        Ok(run)
    }

    pub fn validate(&self) -> Result<(), SmallModelRuntimeHarnessFirstTokenProbeError> {
        validate_clean("run_id", &self.run_id)?;
        validate_clean("lane_id", &self.lane_id)?;
        validate_prefixed(
            &self.run_id,
            &self.logged_smoke_artifact_ref,
            LOGGED_SMOKE_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingLoggedSmokeArtifact,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.live_probe_sidecar_ref,
            LIVE_PROBE_SIDECAR_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingLiveProbeSidecar,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.model_catalog_ref,
            MODEL_CATALOG_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingModelCatalog,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.model_snapshot_ref,
            MODEL_SNAPSHOT_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingModelSnapshot,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.model_config_ref,
            MODEL_CONFIG_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingModelConfig,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.tokenizer_ref,
            TOKENIZER_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingTokenizer,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.prompt_envelope_ref,
            PROMPT_ENVELOPE_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingPromptEnvelope,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.admission_ref,
            ADMISSION_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingAdmission,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.scope_rex_ref,
            SCOPE_REX_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingScopeRex,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingSovereignGate,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingCompatibilityFence,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.cancellation_ref,
            CANCELLATION_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingCancellation,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.rollback_ref,
            ROLLBACK_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingRollback,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingRunEventLog,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingAnswerPacket,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.privacy_ref,
            PRIVACY_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingPrivacyFence,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.budget_ref,
            BUDGET_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingBudget,
        )?;
        validate_prefixed(
            &self.run_id,
            &self.token_digest_ref,
            TOKEN_SHA_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingTokenDigest,
        )?;
        if self.token_digest_ref.len() < MIN_TOKEN_SHA_LEN {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::TokenDigestMalformed(
                    self.run_id.clone(),
                ),
            );
        }
        if self.phases.is_empty() {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::EmptyPhase);
        }
        let phase_tags: BTreeSet<&str> = self.phases.iter().map(|phase| phase.tag()).collect();
        for phase in required_phases() {
            if !phase_tags.contains(phase.tag()) {
                return Err(SmallModelRuntimeHarnessFirstTokenProbeError::MissingPhase(
                    phase.tag(),
                ));
            }
        }
        if !self.owner_approved {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::OwnerApprovalMissing(
                    self.run_id.clone(),
                ),
            );
        }
        if !self.local_snapshot_exists {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::SnapshotMissing(self.run_id.clone()),
            );
        }
        if !self.runtime_started {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::RuntimeNotStarted(
                    self.run_id.clone(),
                ),
            );
        }
        if !self.runtime_completed {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::RuntimeNotCompleted(
                    self.run_id.clone(),
                ),
            );
        }
        if !self.first_token_observed || self.chunks_observed == 0 || self.first_token_utf8_len == 0
        {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::FirstTokenMissing(
                    self.run_id.clone(),
                ),
            );
        }
        if self.output_token_count != 1 || self.decode_tokens != MAX_DECODE_TOKENS {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::OutputTokenCountMismatch(
                    self.run_id.clone(),
                ),
            );
        }
        if self.raw_token_text_retained {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::TokenTextRetained(
                    self.run_id.clone(),
                ),
            );
        }
        if self.prompt_contains_user_data {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::PromptUserData(self.run_id.clone()),
            );
        }
        if self.committed_mutation {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::MutationCommitted(
                    self.run_id.clone(),
                ),
            );
        }
        if self.route_policy_mutation_attempted {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::RoutePolicyMutation(
                    self.run_id.clone(),
                ),
            );
        }
        if self.gate_bypass_attempted {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::GateBypass(
                self.run_id.clone(),
            ));
        }
        if self.answer_packet_suppressed {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::AnswerPacketSuppression(
                    self.run_id.clone(),
                ),
            );
        }
        if self.hidden_route_authority_attempted {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::HiddenRouteAuthority(
                    self.run_id.clone(),
                ),
            );
        }
        if self.hidden_chain_exposed {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::HiddenChainExposure(
                    self.run_id.clone(),
                ),
            );
        }
        if self.hidden_cloud_fallback_allowed {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::HiddenCloudFallback(
                    self.run_id.clone(),
                ),
            );
        }
        if self.subprocess_spawned_in_app_path {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::AppPathSubprocessSpawn(
                    self.run_id.clone(),
                ),
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::AutogenousKernelAttempt(
                    self.run_id.clone(),
                ),
            );
        }
        if self.seventy_b_probe_attempted {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::SeventyBProbeAttempt(
                    self.run_id.clone(),
                ),
            );
        }
        if self.long_context_shard_probe_attempted {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::LongContextShardProbeAttempt(
                    self.run_id.clone(),
                ),
            );
        }
        if self.runtime_bytes_loaded == 0 {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::RuntimeBytesNotLoaded(
                    self.run_id.clone(),
                ),
            );
        }
        if self.model_bytes_loaded == 0 {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::ModelBytesNotLoaded(
                    self.run_id.clone(),
                ),
            );
        }
        if self.runtime_bytes_loaded > MAX_MODEL_BYTES_LOADED {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::RuntimeBytesOverBudget(
                    self.run_id.clone(),
                ),
            );
        }
        if self.model_bytes_loaded > MAX_MODEL_BYTES_LOADED {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::ModelBytesOverBudget(
                    self.run_id.clone(),
                ),
            );
        }
        if self.context_tokens > MAX_CONTEXT_TOKENS {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded("context_tokens"),
            );
        }
        if self.prompt_tokens > MAX_PROMPT_TOKENS {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded("prompt_tokens"),
            );
        }
        if self.memory_budget_bytes > MAX_MEMORY_BUDGET_BYTES {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded("memory_budget_bytes"),
            );
        }
        if self.runtime_budget_seconds > MAX_RUNTIME_SECONDS {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded(
                    "runtime_budget_seconds",
                ),
            );
        }
        if self.load_ms > MAX_LOAD_MS {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded("load_ms"));
        }
        if self.first_token_ms > MAX_FIRST_TOKEN_MS {
            return Err(
                SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded("first_token_ms"),
            );
        }
        if self.total_ms > MAX_TOTAL_MS || self.total_ms < self.first_token_ms {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::BudgetExceeded("total_ms"));
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:metrics
// Plane: Verification
// Residency: aggregate retained first-token runtime metrics.
pub struct SmallModelRuntimeHarnessFirstTokenProbeMetrics {
    pub run_count: u64,
    pub surface_count: u64,
    pub phase_count: u64,
    pub first_token_observed_count: u64,
    pub output_token_count: u64,
    pub max_load_ms: u32,
    pub max_first_token_ms: u32,
    pub max_total_ms: u32,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:witness
// Plane: Controller + Verification
// Residency: complete retained first-token runtime witness.
pub struct SmallModelRuntimeHarnessFirstTokenProbeWitness {
    pub witness_id: String,
    pub logged_smoke_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub runs: Vec<SmallModelFirstTokenRuntimeProbeRun>,
    pub surfaces: Vec<SmallModelFirstTokenRuntimeProbeSurface>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
}

impl SmallModelRuntimeHarnessFirstTokenProbeWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        logged_smoke_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        runs: Vec<SmallModelFirstTokenRuntimeProbeRun>,
        surfaces: Vec<SmallModelFirstTokenRuntimeProbeSurface>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessFirstTokenProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            logged_smoke_artifact_ref: logged_smoke_artifact_ref.into(),
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

    pub fn validate(&self) -> Result<(), SmallModelRuntimeHarnessFirstTokenProbeError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.logged_smoke_artifact_ref,
            LOGGED_SMOKE_PREFIX,
            SmallModelRuntimeHarnessFirstTokenProbeError::MissingLoggedSmokeArtifact,
        )?;
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::GuardCursorMismatch);
        }
        if self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR
                && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.route_authority != "retained_small_model_first_token_probe_only"
        {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::ProductStatusMismatch);
        }
        if self.runs.is_empty() {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::EmptyRun);
        }
        if self.surfaces.is_empty() {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::EmptySurface);
        }
        let mut run_ids = HashSet::new();
        for run in &self.runs {
            run.validate()?;
            if !run_ids.insert(run.run_id.clone()) {
                return Err(SmallModelRuntimeHarnessFirstTokenProbeError::DuplicateRun(
                    run.run_id.clone(),
                ));
            }
        }
        let mut surface_ids = HashSet::new();
        for surface in &self.surfaces {
            if !surface_ids.insert(surface.surface_id.clone()) {
                return Err(
                    SmallModelRuntimeHarnessFirstTokenProbeError::DuplicateSurface(
                        surface.surface_id.clone(),
                    ),
                );
            }
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::MissingLayerSeparation);
        }
        if self.mas_overclaim_attempted {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::MasOverclaimAttempted);
        }
        if self.l2_green_claimed {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::L3GreenClaimAttempted);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelRuntimeHarnessFirstTokenProbeError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelRuntimeHarnessFirstTokenProbeMetrics {
        let phase_count = self
            .runs
            .iter()
            .flat_map(|run| run.phases.iter().map(|phase| phase.tag()))
            .collect::<BTreeSet<_>>()
            .len() as u64;
        SmallModelRuntimeHarnessFirstTokenProbeMetrics {
            run_count: self.runs.len() as u64,
            surface_count: self.surfaces.len() as u64,
            phase_count,
            first_token_observed_count: self
                .runs
                .iter()
                .filter(|run| run.first_token_observed)
                .count() as u64,
            output_token_count: self
                .runs
                .iter()
                .map(|run| u64::from(run.output_token_count))
                .sum(),
            max_load_ms: self.runs.iter().map(|run| run.load_ms).max().unwrap_or(0),
            max_first_token_ms: self
                .runs
                .iter()
                .map(|run| run.first_token_ms)
                .max()
                .unwrap_or(0),
            max_total_ms: self.runs.iter().map(|run| run.total_ms).max().unwrap_or(0),
            runtime_bytes_loaded: self.runs.iter().map(|run| run.runtime_bytes_loaded).sum(),
            model_bytes_loaded: self.runs.iter().map(|run| run.model_bytes_loaded).sum(),
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.logged_smoke_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
        ];
        for run in &self.runs {
            parts.push(run.run_id.clone());
            parts.push(run.lane_id.clone());
            parts.push(run.model_catalog_ref.clone());
            parts.push(run.model_snapshot_ref.clone());
            parts.push(run.prompt_envelope_ref.clone());
            parts.push(run.token_digest_ref.clone());
            parts.push(run.answer_packet_ref.clone());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_phases() -> [SmallModelFirstTokenRuntimeProbePhase; 16] {
    [
        SmallModelFirstTokenRuntimeProbePhase::LoggedSmokeArtifactBound,
        SmallModelFirstTokenRuntimeProbePhase::LocalSnapshotVerified,
        SmallModelFirstTokenRuntimeProbePhase::ConfigAndTokenizerVerified,
        SmallModelFirstTokenRuntimeProbePhase::OwnerApprovalConfirmed,
        SmallModelFirstTokenRuntimeProbePhase::PromptEnvelopeCompiled,
        SmallModelFirstTokenRuntimeProbePhase::AdmissionChecked,
        SmallModelFirstTokenRuntimeProbePhase::SerializedExecutorEntered,
        SmallModelFirstTokenRuntimeProbePhase::RuntimeStarted,
        SmallModelFirstTokenRuntimeProbePhase::FirstTokenObserved,
        SmallModelFirstTokenRuntimeProbePhase::TokenRedacted,
        SmallModelFirstTokenRuntimeProbePhase::RuntimeCompleted,
        SmallModelFirstTokenRuntimeProbePhase::RollbackVerified,
        SmallModelFirstTokenRuntimeProbePhase::RunEventLogged,
        SmallModelFirstTokenRuntimeProbePhase::AnswerPacketDrafted,
        SmallModelFirstTokenRuntimeProbePhase::MutationReviewPassed,
        SmallModelFirstTokenRuntimeProbePhase::EvidenceReviewPending,
    ]
}

fn validate_prefixed(
    run_id: &str,
    value: &str,
    prefix: &str,
    error: fn(String) -> SmallModelRuntimeHarnessFirstTokenProbeError,
) -> Result<(), SmallModelRuntimeHarnessFirstTokenProbeError> {
    validate_clean("prefixed_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(error(run_id.to_string()));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessFirstTokenProbeError> {
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessFirstTokenProbeError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(
            SmallModelRuntimeHarnessFirstTokenProbeError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(
            SmallModelRuntimeHarnessFirstTokenProbeError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn phases() -> Vec<SmallModelFirstTokenRuntimeProbePhase> {
        required_phases().to_vec()
    }

    fn run(id: &str) -> SmallModelFirstTokenRuntimeProbeRun {
        SmallModelFirstTokenRuntimeProbeRun::new(
            id,
            "qwen3_4b_first_token_runtime_probe",
            "artifact:small_model_runtime_harness_logged_runtime_smoke:result",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:live_probe:sha256:test",
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:snapshot:52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495",
            "model_config:qwen3:max_position_embeddings=65536:quantized=4bit",
            "tokenizer:Qwen/Qwen3-4B-MLX-4bit:tokenizer.json",
            "prompt_envelope:synthetic-one-word-ok:sha256:test",
            "admission:qwen3_4b:scope-rex",
            "scope_rex:qwen3_4b:first-token",
            "sovereign_gate:qwen3_4b:research-candidate",
            "compat:qwen3_4b:mlx-small-first-token-v1",
            "cancel:qwen3_4b:bounded-runtime-lease",
            "rollback:qwen3_4b:no-mutation",
            "run_event_log:qwen3_4b:first-token-observed-redacted",
            "answer_packet:qwen3_4b:first-token-visible-proof",
            "privacy:qwen3_4b:local-only-redacted-token",
            "budget:qwen3_4b:4gb-180s-one-token",
            "token_sha256:d03502c43d74a30b936740a9517dc4ea2b2ad7168caa0a774cefe793ce0b33e7",
            phases(),
        )
        .expect("valid first-token run")
    }

    fn surface(id: &str) -> SmallModelFirstTokenRuntimeProbeSurface {
        SmallModelFirstTokenRuntimeProbeSurface::new(
            id,
            format!("surface:{id}"),
            "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. small_model_runtime_harness_first_token_runtime_probe retained small-model first-token probe vault_research_route_with_packetized_mitigation token redacted AnswerPacket RunEventLog rollback not product-live not 70B not long-context shard",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "small_model_runtime_harness_first_token_runtime_probe".to_string(),
                "vault_research_route_with_packetized_mitigation".to_string(),
            ],
            vec!["small model runtime is product-live".to_string()],
        )
        .expect("valid surface")
    }

    fn witness() -> SmallModelRuntimeHarnessFirstTokenProbeWitness {
        SmallModelRuntimeHarnessFirstTokenProbeWitness::new(
            "first-token-witness",
            "artifact:small_model_runtime_harness_logged_runtime_smoke:result",
            SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "retained_small_model_first_token_probe_only",
            vec![run("run-a")],
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
    fn deterministic_address_and_runtime_metrics() {
        let good = witness();
        assert!(!good.address().is_empty());
        let metrics = good.metrics();
        assert_eq!(metrics.run_count, 1);
        assert_eq!(metrics.phase_count, 16);
        assert_eq!(metrics.first_token_observed_count, 1);
        assert_eq!(metrics.output_token_count, 1);
        assert!(metrics.runtime_bytes_loaded > 0);
        assert!(metrics.model_bytes_loaded > 0);
    }

    #[test]
    fn duplicate_run_is_rejected() {
        let mut good = witness();
        good.runs.push(good.runs[0].clone());
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::DuplicateRun(
                _
            ))
        ));
    }

    #[test]
    fn missing_first_token_is_rejected() {
        let mut good = run("run-a");
        good.first_token_observed = false;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::FirstTokenMissing(_))
        ));
    }

    #[test]
    fn token_text_retention_is_rejected() {
        let mut good = run("run-a");
        good.raw_token_text_retained = true;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::TokenTextRetained(_))
        ));
    }

    #[test]
    fn more_than_one_output_token_is_rejected() {
        let mut good = run("run-a");
        good.output_token_count = 2;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::OutputTokenCountMismatch(_))
        ));
    }

    #[test]
    fn zero_runtime_bytes_are_rejected_for_live_probe() {
        let mut good = run("run-a");
        good.runtime_bytes_loaded = 0;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::RuntimeBytesNotLoaded(_))
        ));
    }

    #[test]
    fn hidden_cloud_and_70b_are_rejected() {
        let mut cloud = run("run-a");
        cloud.hidden_cloud_fallback_allowed = true;
        assert!(matches!(
            cloud.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::HiddenCloudFallback(_))
        ));

        let mut seventy_b = run("run-a");
        seventy_b.seventy_b_probe_attempted = true;
        assert!(matches!(
            seventy_b.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::SeventyBProbeAttempt(_))
        ));
    }

    #[test]
    fn long_context_shard_and_l2_claims_are_rejected() {
        let mut shard = run("run-a");
        shard.long_context_shard_probe_attempted = true;
        assert!(matches!(
            shard.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::LongContextShardProbeAttempt(_))
        ));

        let mut good = witness();
        good.l2_green_claimed = true;
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessFirstTokenProbeError::L2GreenClaimAttempted)
        ));
    }
}
