//! Fresh product-runtime live probe for the small-model harness.
//!
//! This L1 witness consumes a bounded one-token local MLX sidecar from the
//! product path. It proves fresh Qwen3-4B runtime/model bytes can open under
//! the prior safety lease, while keeping the token redacted and L2/L3 red.

use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    fresh_product_runtime_safety_lease_max_model_budget_bytes,
    fresh_product_runtime_safety_lease_max_runtime_budget_bytes, ProStatus, ProductBuild,
};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_live_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const SAFETY_LEASE_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_safety_lease:";
const EXPECTED_SCOPE: &str = "fresh_product_runtime_live_probe_l1_only";
const EXPECTED_HELPER: &str = "manual_mlx_lm_stream_generate_product_lease_helper";
const EXPECTED_MODEL_REPO: &str = "Qwen/Qwen3-4B-MLX-4bit";
const EXPECTED_MODEL_PATH_PREFIX: &str = "/Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--Qwen--Qwen3-4B-MLX-4bit/snapshots/";
const EXPECTED_MODEL_TYPE: &str = "qwen3";
const EXPECTED_PRODUCT_SURFACE: &str = "note_chat_fresh_product_runtime";
const EXPECTED_PROMPT_LABEL: &str = "synthetic_one_safe_word_ok_product_path";
const EXPECTED_RUNTIME_ROUTE_SCOPE: &str = "product_path_l1_falsifier_only";
const SHA256_PREFIX: &str = "sha256:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const CANCELLATION_PREFIX: &str = "cancel:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const PRIVACY_PREFIX: &str = "privacy:";
const BUDGET_PREFIX: &str = "budget:";
const MAX_LOAD_MS: u64 = 60_000;
const MAX_FIRST_TOKEN_MS: u64 = 60_000;
const MAX_TOTAL_MS: u64 = 180_000;
const MAX_TOKEN_UTF8_LEN: u64 = 64;
const MAX_METADATA_BYTES: u64 = 768 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:phase
// Plane: Controller + Verification
// Residency: bounded fresh product-path runtime evidence.
pub enum SmallModelFreshProductRuntimeLiveProbePhase {
    SafetyLeaseBound,
    GuardCursorBound,
    CapabilityRedBound,
    LocalModelResolved,
    SyntheticPromptBound,
    FirstTokenObserved,
    TokenRedacted,
    RuntimeBytesBudgeted,
    ModelBytesBudgeted,
    AnswerPacketQueued,
    MasProHonestyBound,
    HeavyRoutesDeferred,
}

impl SmallModelFreshProductRuntimeLiveProbePhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::SafetyLeaseBound => "safety_lease_bound",
            Self::GuardCursorBound => "guard_cursor_bound",
            Self::CapabilityRedBound => "capability_red_bound",
            Self::LocalModelResolved => "local_model_resolved",
            Self::SyntheticPromptBound => "synthetic_prompt_bound",
            Self::FirstTokenObserved => "first_token_observed",
            Self::TokenRedacted => "token_redacted",
            Self::RuntimeBytesBudgeted => "runtime_bytes_budgeted",
            Self::ModelBytesBudgeted => "model_bytes_budgeted",
            Self::AnswerPacketQueued => "answer_packet_queued",
            Self::MasProHonestyBound => "mas_pro_honesty_bound",
            Self::HeavyRoutesDeferred => "heavy_routes_deferred",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:error
// Plane: Verification
// Residency: live sidecar rejection taxonomy.
pub enum SmallModelFreshProductRuntimeLiveProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    FieldValueMismatch(&'static str),
    InvalidSha256(&'static str),
    MissingSafetyLeaseArtifact(String),
    GuardCursorMismatch,
    CapabilityStatusMismatch,
    ProductStatusMismatch,
    RouteAuthorityMismatch,
    EmptyPhase,
    MissingPhase(&'static str),
    PromptUserDataRetained,
    FirstTokenMissing,
    ChunkCountMismatch,
    OutputTokenCountMismatch,
    TokenUtf8LengthOutOfRange,
    RawTokenTextRetained,
    LoadLatencyOutOfRange,
    FirstTokenLatencyOutOfRange,
    TotalLatencyOutOfRange,
    RuntimeBytesOutOfRange,
    ModelBytesOutOfRange,
    MissingAnswerPacketRef,
    MissingRunEventLogRef,
    MissingRollbackRef,
    MissingCancellationRef,
    MissingAdmissionRef,
    MissingScopeRexRef,
    MissingSovereignGateRef,
    MissingPrivacyRef,
    MissingBudgetRef,
    ProductRoutePromotionAttempted,
    MasClaimPromotionAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    HiddenCloudFallback,
    HiddenChainExposure,
    RoutePolicyMutation,
    AppPathSubprocessSpawn,
    AutogenousKernelAttempt,
    SeventyBProbeAttempt,
    LongContextShardProbeAttempt,
    L1L2L3NotSeparated,
    MasFloorNotPreserved,
    NextCursorMismatch,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelFreshProductRuntimeLiveProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::FieldValueMismatch(field) => write!(f, "field `{field}` has the wrong value"),
            Self::InvalidSha256(field) => write!(f, "field `{field}` is not a sha256 digest"),
            Self::MissingSafetyLeaseArtifact(id) => {
                write!(f, "witness `{id}` missing safety lease artifact")
            }
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::RouteAuthorityMismatch => write!(f, "route authority mismatch"),
            Self::EmptyPhase => write!(f, "missing live-probe phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::PromptUserDataRetained => write!(f, "prompt retained user data"),
            Self::FirstTokenMissing => write!(f, "first token was not observed"),
            Self::ChunkCountMismatch => write!(f, "chunk count was not exactly one"),
            Self::OutputTokenCountMismatch => write!(f, "output token count was not exactly one"),
            Self::TokenUtf8LengthOutOfRange => write!(f, "token utf8 length out of range"),
            Self::RawTokenTextRetained => write!(f, "raw token text was retained"),
            Self::LoadLatencyOutOfRange => write!(f, "model load latency out of range"),
            Self::FirstTokenLatencyOutOfRange => write!(f, "first token latency out of range"),
            Self::TotalLatencyOutOfRange => write!(f, "total latency out of range"),
            Self::RuntimeBytesOutOfRange => write!(f, "runtime bytes out of lease budget"),
            Self::ModelBytesOutOfRange => write!(f, "model bytes out of lease budget"),
            Self::MissingAnswerPacketRef => write!(f, "missing AnswerPacket ref"),
            Self::MissingRunEventLogRef => write!(f, "missing RunEventLog ref"),
            Self::MissingRollbackRef => write!(f, "missing rollback ref"),
            Self::MissingCancellationRef => write!(f, "missing cancellation ref"),
            Self::MissingAdmissionRef => write!(f, "missing admission ref"),
            Self::MissingScopeRexRef => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGateRef => write!(f, "missing SovereignGate ref"),
            Self::MissingPrivacyRef => write!(f, "missing privacy ref"),
            Self::MissingBudgetRef => write!(f, "missing budget ref"),
            Self::ProductRoutePromotionAttempted => write!(f, "product route promotion attempted"),
            Self::MasClaimPromotionAttempted => write!(f, "MAS claim promotion attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::HiddenCloudFallback => write!(f, "hidden cloud fallback allowed"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposed"),
            Self::RoutePolicyMutation => write!(f, "route policy mutated"),
            Self::AppPathSubprocessSpawn => write!(f, "app-path subprocess spawned"),
            Self::AutogenousKernelAttempt => write!(f, "autogenous kernel attempted"),
            Self::SeventyBProbeAttempt => write!(f, "70B probe attempted"),
            Self::LongContextShardProbeAttempt => write!(f, "long-context shard probe attempted"),
            Self::L1L2L3NotSeparated => write!(f, "L1/L2/L3 were not separated"),
            Self::MasFloorNotPreserved => write!(f, "MAS floor not preserved"),
            Self::NextCursorMismatch => write!(f, "next cursor mismatch"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelFreshProductRuntimeLiveProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:record
// Plane: State + Verification
// Residency: redacted one-token live sidecar.
pub struct SmallModelFreshProductRuntimeLiveProbeRecord {
    pub probe_id: String,
    pub generated_at_utc: String,
    pub scope: String,
    pub helper: String,
    pub model_repo: String,
    pub model_path: String,
    pub model_type: String,
    pub quantization_bits: u64,
    pub max_position_embeddings: u64,
    pub product_surface: String,
    pub safety_lease_ref: String,
    pub prompt_label: String,
    pub prompt_sha256: String,
    pub prompt_contains_user_data: bool,
    pub first_token_observed: bool,
    pub chunks_observed: u64,
    pub output_token_count: u64,
    pub first_token_utf8_len: u64,
    pub first_token_sha256: String,
    pub raw_token_text_retained: bool,
    pub load_ms: u64,
    pub first_token_ms: u64,
    pub total_ms: u64,
    pub fresh_product_model_bytes_loaded: u64,
    pub fresh_product_runtime_bytes_loaded: u64,
    pub runtime_route_scope: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub product_route_promoted: bool,
    pub mas_claim_promoted: bool,
    pub l2_claim_promoted: bool,
    pub l3_claim_promoted: bool,
    pub seventy_b_probe_attempted: bool,
    pub long_context_shard_probe_attempted: bool,
    pub autogenous_kernel_attempted: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_chain_exposed: bool,
    pub route_policy_mutated: bool,
    pub app_path_subprocess_spawned: bool,
}

impl SmallModelFreshProductRuntimeLiveProbeRecord {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        probe_id: impl Into<String>,
        generated_at_utc: impl Into<String>,
        scope: impl Into<String>,
        helper: impl Into<String>,
        model_repo: impl Into<String>,
        model_path: impl Into<String>,
        model_type: impl Into<String>,
        quantization_bits: u64,
        max_position_embeddings: u64,
        product_surface: impl Into<String>,
        safety_lease_ref: impl Into<String>,
        prompt_label: impl Into<String>,
        prompt_sha256: impl Into<String>,
        prompt_contains_user_data: bool,
        first_token_observed: bool,
        chunks_observed: u64,
        output_token_count: u64,
        first_token_utf8_len: u64,
        first_token_sha256: impl Into<String>,
        raw_token_text_retained: bool,
        load_ms: u64,
        first_token_ms: u64,
        total_ms: u64,
        fresh_product_model_bytes_loaded: u64,
        fresh_product_runtime_bytes_loaded: u64,
        runtime_route_scope: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        privacy_ref: impl Into<String>,
        budget_ref: impl Into<String>,
        product_route_promoted: bool,
        mas_claim_promoted: bool,
        l2_claim_promoted: bool,
        l3_claim_promoted: bool,
        seventy_b_probe_attempted: bool,
        long_context_shard_probe_attempted: bool,
        autogenous_kernel_attempted: bool,
        hidden_cloud_fallback_allowed: bool,
        hidden_chain_exposed: bool,
        route_policy_mutated: bool,
        app_path_subprocess_spawned: bool,
    ) -> Result<Self, SmallModelFreshProductRuntimeLiveProbeError> {
        let record = Self {
            probe_id: probe_id.into(),
            generated_at_utc: generated_at_utc.into(),
            scope: scope.into(),
            helper: helper.into(),
            model_repo: model_repo.into(),
            model_path: model_path.into(),
            model_type: model_type.into(),
            quantization_bits,
            max_position_embeddings,
            product_surface: product_surface.into(),
            safety_lease_ref: safety_lease_ref.into(),
            prompt_label: prompt_label.into(),
            prompt_sha256: prompt_sha256.into(),
            prompt_contains_user_data,
            first_token_observed,
            chunks_observed,
            output_token_count,
            first_token_utf8_len,
            first_token_sha256: first_token_sha256.into(),
            raw_token_text_retained,
            load_ms,
            first_token_ms,
            total_ms,
            fresh_product_model_bytes_loaded,
            fresh_product_runtime_bytes_loaded,
            runtime_route_scope: runtime_route_scope.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            privacy_ref: privacy_ref.into(),
            budget_ref: budget_ref.into(),
            product_route_promoted,
            mas_claim_promoted,
            l2_claim_promoted,
            l3_claim_promoted,
            seventy_b_probe_attempted,
            long_context_shard_probe_attempted,
            autogenous_kernel_attempted,
            hidden_cloud_fallback_allowed,
            hidden_chain_exposed,
            route_policy_mutated,
            app_path_subprocess_spawned,
        };
        record.validate()?;
        Ok(record)
    }

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
        validate_clean("probe_id", &self.probe_id)?;
        validate_clean("generated_at_utc", &self.generated_at_utc)?;
        validate_exact("scope", &self.scope, EXPECTED_SCOPE)?;
        validate_exact("helper", &self.helper, EXPECTED_HELPER)?;
        validate_exact("model_repo", &self.model_repo, EXPECTED_MODEL_REPO)?;
        validate_clean("model_path", &self.model_path)?;
        if !self.model_path.starts_with(EXPECTED_MODEL_PATH_PREFIX) {
            return Err(
                SmallModelFreshProductRuntimeLiveProbeError::FieldValueMismatch("model_path"),
            );
        }
        validate_exact("model_type", &self.model_type, EXPECTED_MODEL_TYPE)?;
        if self.quantization_bits != 4 {
            return Err(
                SmallModelFreshProductRuntimeLiveProbeError::FieldValueMismatch(
                    "quantization_bits",
                ),
            );
        }
        if self.max_position_embeddings != 65_536 {
            return Err(
                SmallModelFreshProductRuntimeLiveProbeError::FieldValueMismatch(
                    "max_position_embeddings",
                ),
            );
        }
        validate_exact(
            "product_surface",
            &self.product_surface,
            EXPECTED_PRODUCT_SURFACE,
        )?;
        validate_prefixed_clean(
            "safety_lease_ref",
            &self.safety_lease_ref,
            SAFETY_LEASE_ARTIFACT_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeLiveProbeError::MissingSafetyLeaseArtifact(
                self.probe_id.clone(),
            )
        })?;
        validate_exact("prompt_label", &self.prompt_label, EXPECTED_PROMPT_LABEL)?;
        validate_sha256("prompt_sha256", &self.prompt_sha256)?;
        if self.prompt_contains_user_data {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::PromptUserDataRetained);
        }
        if !self.first_token_observed {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::FirstTokenMissing);
        }
        if self.chunks_observed != 1 {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::ChunkCountMismatch);
        }
        if self.output_token_count != 1 {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::OutputTokenCountMismatch);
        }
        if self.first_token_utf8_len == 0 || self.first_token_utf8_len > MAX_TOKEN_UTF8_LEN {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::TokenUtf8LengthOutOfRange);
        }
        validate_sha256("first_token_sha256", &self.first_token_sha256)?;
        if self.raw_token_text_retained {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::RawTokenTextRetained);
        }
        if self.load_ms == 0 || self.load_ms > MAX_LOAD_MS {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::LoadLatencyOutOfRange);
        }
        if self.first_token_ms == 0 || self.first_token_ms > MAX_FIRST_TOKEN_MS {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::FirstTokenLatencyOutOfRange);
        }
        if self.total_ms == 0 || self.total_ms > MAX_TOTAL_MS || self.total_ms < self.first_token_ms
        {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::TotalLatencyOutOfRange);
        }
        if self.fresh_product_runtime_bytes_loaded == 0
            || self.fresh_product_runtime_bytes_loaded
                > fresh_product_runtime_safety_lease_max_runtime_budget_bytes()
        {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::RuntimeBytesOutOfRange);
        }
        if self.fresh_product_model_bytes_loaded == 0
            || self.fresh_product_model_bytes_loaded
                > fresh_product_runtime_safety_lease_max_model_budget_bytes()
        {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::ModelBytesOutOfRange);
        }
        validate_exact(
            "runtime_route_scope",
            &self.runtime_route_scope,
            EXPECTED_RUNTIME_ROUTE_SCOPE,
        )?;
        validate_prefixed_clean(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )
        .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingAnswerPacketRef)?;
        validate_prefixed_clean(
            "run_event_log_ref",
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )
        .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingRunEventLogRef)?;
        validate_prefixed_clean("rollback_ref", &self.rollback_ref, ROLLBACK_PREFIX)
            .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingRollbackRef)?;
        validate_prefixed_clean(
            "cancellation_ref",
            &self.cancellation_ref,
            CANCELLATION_PREFIX,
        )
        .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingCancellationRef)?;
        validate_prefixed_clean("admission_ref", &self.admission_ref, ADMISSION_PREFIX)
            .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingAdmissionRef)?;
        validate_prefixed_clean("scope_rex_ref", &self.scope_rex_ref, SCOPE_REX_PREFIX)
            .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingScopeRexRef)?;
        validate_prefixed_clean(
            "sovereign_gate_ref",
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
        )
        .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingSovereignGateRef)?;
        validate_prefixed_clean("privacy_ref", &self.privacy_ref, PRIVACY_PREFIX)
            .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingPrivacyRef)?;
        validate_prefixed_clean("budget_ref", &self.budget_ref, BUDGET_PREFIX)
            .map_err(|_| SmallModelFreshProductRuntimeLiveProbeError::MissingBudgetRef)?;
        if self.product_route_promoted {
            return Err(
                SmallModelFreshProductRuntimeLiveProbeError::ProductRoutePromotionAttempted,
            );
        }
        if self.mas_claim_promoted {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::MasClaimPromotionAttempted);
        }
        if self.l2_claim_promoted {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::L2GreenClaimAttempted);
        }
        if self.l3_claim_promoted {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::L3GreenClaimAttempted);
        }
        if self.hidden_cloud_fallback_allowed {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::HiddenCloudFallback);
        }
        if self.hidden_chain_exposed {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::HiddenChainExposure);
        }
        if self.route_policy_mutated {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::RoutePolicyMutation);
        }
        if self.app_path_subprocess_spawned {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::AppPathSubprocessSpawn);
        }
        if self.autogenous_kernel_attempted {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::AutogenousKernelAttempt);
        }
        if self.seventy_b_probe_attempted {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::SeventyBProbeAttempt);
        }
        if self.long_context_shard_probe_attempted {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::LongContextShardProbeAttempt);
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:metrics
// Plane: Verification
// Residency: byte/timing accounting for the fresh one-token sidecar.
pub struct SmallModelFreshProductRuntimeLiveProbeMetrics {
    pub phase_count: u64,
    pub chunks_observed: u64,
    pub output_token_count: u64,
    pub first_token_utf8_len: u64,
    pub load_ms: u64,
    pub first_token_ms: u64,
    pub total_ms: u64,
    pub fresh_runtime_bytes_loaded: u64,
    pub fresh_model_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:witness
// Plane: Controller + Verification
// Residency: L1-only product-path runtime proof; product promotion still red.
pub struct SmallModelFreshProductRuntimeLiveProbeWitness {
    pub witness_id: String,
    pub safety_lease_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub live_probe: SmallModelFreshProductRuntimeLiveProbeRecord,
    pub phases: Vec<SmallModelFreshProductRuntimeLiveProbePhase>,
    pub l1_l2_l3_separated: bool,
    pub mas_floor_preserved: bool,
    pub next_cursor: String,
    pub metadata_bytes: u64,
}

impl SmallModelFreshProductRuntimeLiveProbeWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        safety_lease_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        live_probe: SmallModelFreshProductRuntimeLiveProbeRecord,
        phases: Vec<SmallModelFreshProductRuntimeLiveProbePhase>,
        l1_l2_l3_separated: bool,
        mas_floor_preserved: bool,
        next_cursor: impl Into<String>,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelFreshProductRuntimeLiveProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            safety_lease_artifact_ref: safety_lease_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            live_probe,
            phases,
            l1_l2_l3_separated,
            mas_floor_preserved,
            next_cursor: next_cursor.into(),
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed_clean(
            "safety_lease_artifact_ref",
            &self.safety_lease_artifact_ref,
            SAFETY_LEASE_ARTIFACT_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeLiveProbeError::MissingSafetyLeaseArtifact(
                self.witness_id.clone(),
            )
        })?;
        if !matches!(
            self.guard_next_existing_work.as_str(),
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR
                | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR
                | ADVANCED_RELEASE_AUDIT_CURSOR
        ) {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::GuardCursorMismatch);
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
        {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::CapabilityStatusMismatch);
        }
        if !matches!(
            self.capability_next_bottleneck.as_str(),
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR
                | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR
                | ADVANCED_RELEASE_AUDIT_CURSOR
        ) {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::ProductStatusMismatch);
        }
        if self.route_authority != EXPECTED_SCOPE {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::RouteAuthorityMismatch);
        }
        self.live_probe.validate()?;
        validate_phases(&self.phases)?;
        if !self.l1_l2_l3_separated {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::L1L2L3NotSeparated);
        }
        if !self.mas_floor_preserved {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::MasFloorNotPreserved);
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeLiveProbeMetrics {
        SmallModelFreshProductRuntimeLiveProbeMetrics {
            phase_count: self.phases.len() as u64,
            chunks_observed: self.live_probe.chunks_observed,
            output_token_count: self.live_probe.output_token_count,
            first_token_utf8_len: self.live_probe.first_token_utf8_len,
            load_ms: self.live_probe.load_ms,
            first_token_ms: self.live_probe.first_token_ms,
            total_ms: self.live_probe.total_ms,
            fresh_runtime_bytes_loaded: self.live_probe.fresh_product_runtime_bytes_loaded,
            fresh_model_bytes_loaded: self.live_probe.fresh_product_model_bytes_loaded,
            metadata_bytes: self.metadata_bytes,
        }
    }

    pub fn address(&self) -> String {
        let mut payload = String::with_capacity(512);
        payload.push_str(&self.witness_id);
        payload.push('|');
        payload.push_str(&self.safety_lease_artifact_ref);
        payload.push('|');
        payload.push_str(&self.live_probe.probe_id);
        payload.push('|');
        payload.push_str(&self.live_probe.model_repo);
        payload.push('|');
        payload.push_str(&self.live_probe.prompt_sha256);
        payload.push('|');
        payload.push_str(&self.live_probe.first_token_sha256);
        payload.push('|');
        payload.push_str(&self.next_cursor);
        sha256_hex(payload.as_bytes())
    }
}

pub fn required_fresh_product_runtime_live_probe_phases(
) -> Vec<SmallModelFreshProductRuntimeLiveProbePhase> {
    vec![
        SmallModelFreshProductRuntimeLiveProbePhase::SafetyLeaseBound,
        SmallModelFreshProductRuntimeLiveProbePhase::GuardCursorBound,
        SmallModelFreshProductRuntimeLiveProbePhase::CapabilityRedBound,
        SmallModelFreshProductRuntimeLiveProbePhase::LocalModelResolved,
        SmallModelFreshProductRuntimeLiveProbePhase::SyntheticPromptBound,
        SmallModelFreshProductRuntimeLiveProbePhase::FirstTokenObserved,
        SmallModelFreshProductRuntimeLiveProbePhase::TokenRedacted,
        SmallModelFreshProductRuntimeLiveProbePhase::RuntimeBytesBudgeted,
        SmallModelFreshProductRuntimeLiveProbePhase::ModelBytesBudgeted,
        SmallModelFreshProductRuntimeLiveProbePhase::AnswerPacketQueued,
        SmallModelFreshProductRuntimeLiveProbePhase::MasProHonestyBound,
        SmallModelFreshProductRuntimeLiveProbePhase::HeavyRoutesDeferred,
    ]
}

pub fn fresh_product_runtime_live_probe_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

pub fn fresh_product_runtime_live_probe_max_load_ms() -> u64 {
    MAX_LOAD_MS
}

pub fn fresh_product_runtime_live_probe_max_first_token_ms() -> u64 {
    MAX_FIRST_TOKEN_MS
}

pub fn fresh_product_runtime_live_probe_max_total_ms() -> u64 {
    MAX_TOTAL_MS
}

pub fn fresh_product_runtime_live_probe_route_authority() -> &'static str {
    EXPECTED_SCOPE
}

fn validate_phases(
    phases: &[SmallModelFreshProductRuntimeLiveProbePhase],
) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
    if phases.is_empty() {
        return Err(SmallModelFreshProductRuntimeLiveProbeError::EmptyPhase);
    }
    let provided: BTreeSet<&'static str> = phases.iter().map(|phase| phase.tag()).collect();
    for required in required_fresh_product_runtime_live_probe_phases() {
        if !provided.contains(required.tag()) {
            return Err(SmallModelFreshProductRuntimeLiveProbeError::MissingPhase(
                required.tag(),
            ));
        }
    }
    Ok(())
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
    validate_clean(field, value)?;
    if value != expected {
        return Err(SmallModelFreshProductRuntimeLiveProbeError::FieldValueMismatch(field));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeLiveProbeError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.is_empty() {
        return Err(SmallModelFreshProductRuntimeLiveProbeError::MissingField(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeLiveProbeError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

fn validate_prefixed_clean(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelFreshProductRuntimeLiveProbeError::FieldValueMismatch(field));
    }
    Ok(())
}

fn validate_sha256(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeLiveProbeError> {
    validate_prefixed_clean(field, value, SHA256_PREFIX)?;
    let hex = &value[SHA256_PREFIX.len()..];
    if hex.len() != 64 || !hex.as_bytes().iter().all(u8::is_ascii_hexdigit) {
        return Err(SmallModelFreshProductRuntimeLiveProbeError::InvalidSha256(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_record() -> SmallModelFreshProductRuntimeLiveProbeRecord {
        SmallModelFreshProductRuntimeLiveProbeRecord::new(
            "small_model_runtime_harness_fresh_product_runtime_live_probe_2026_06_05_qwen3_4b_product_path",
            "2026-06-05T14:43:34Z",
            EXPECTED_SCOPE,
            EXPECTED_HELPER,
            EXPECTED_MODEL_REPO,
            format!("{EXPECTED_MODEL_PATH_PREFIX}52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495"),
            EXPECTED_MODEL_TYPE,
            4,
            65_536,
            EXPECTED_PRODUCT_SURFACE,
            "artifact:small_model_runtime_harness_fresh_product_runtime_safety_lease:result",
            EXPECTED_PROMPT_LABEL,
            "sha256:fb5e5ea2da88bd278450eaa46897f685d5d180d5e112abfd647773904d7e5643",
            false,
            true,
            1,
            1,
            2,
            "sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070",
            false,
            1_305,
            700,
            2_006,
            2_137_326_367,
            16_777_216,
            EXPECTED_RUNTIME_ROUTE_SCOPE,
            "answer_packet:fresh-product-runtime-live-probe:qwen3-4b:redacted",
            "run_event_log:fresh-product-runtime-live-probe:qwen3-4b:redacted",
            "rollback:fresh-product-runtime-live-probe:discard-output",
            "cancel:fresh-product-runtime-live-probe:one-token-deadline",
            "admission:scope-rex-sovereign-gate:fresh-product-runtime-live-probe",
            "scope_rex:fresh-product-runtime-live-probe:synthetic-only",
            "sovereign_gate:fresh-product-runtime-live-probe:local-only",
            "privacy:synthetic-prompt-redacted-token-no-user-data",
            "budget:fresh-product-runtime-live-probe:one-token",
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
        )
        .expect("valid live probe record")
    }

    fn valid_witness() -> SmallModelFreshProductRuntimeLiveProbeWitness {
        SmallModelFreshProductRuntimeLiveProbeWitness::new(
            "small-model-fresh-product-runtime-live-probe:v1",
            "artifact:small_model_runtime_harness_fresh_product_runtime_safety_lease:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            EXPECTED_SCOPE,
            valid_record(),
            required_fresh_product_runtime_live_probe_phases(),
            true,
            true,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
            4_096,
        )
        .expect("valid witness")
    }

    #[test]
    fn valid_live_probe_witness_is_deterministic() {
        let witness = valid_witness();
        let again = valid_witness();
        assert_eq!(witness.address(), again.address());
        assert_eq!(witness.metrics().output_token_count, 1);
    }

    #[test]
    fn rejects_raw_token_text_retention() {
        let mut record = valid_record();
        record.raw_token_text_retained = true;
        assert!(matches!(
            record.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::RawTokenTextRetained)
        ));
    }

    #[test]
    fn rejects_prompt_user_data() {
        let mut record = valid_record();
        record.prompt_contains_user_data = true;
        assert!(matches!(
            record.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::PromptUserDataRetained)
        ));
    }

    #[test]
    fn rejects_zero_or_multi_token_outputs() {
        let mut record = valid_record();
        record.output_token_count = 0;
        assert!(matches!(
            record.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::OutputTokenCountMismatch)
        ));
        let mut record = valid_record();
        record.chunks_observed = 2;
        assert!(matches!(
            record.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::ChunkCountMismatch)
        ));
    }

    #[test]
    fn rejects_byte_budget_overflow_and_hidden_authority() {
        let mut record = valid_record();
        record.fresh_product_runtime_bytes_loaded =
            fresh_product_runtime_safety_lease_max_runtime_budget_bytes() + 1;
        assert!(matches!(
            record.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::RuntimeBytesOutOfRange)
        ));
        let mut record = valid_record();
        record.hidden_cloud_fallback_allowed = true;
        assert!(matches!(
            record.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::HiddenCloudFallback)
        ));
    }

    #[test]
    fn rejects_false_promotion_and_next_cursor_drift() {
        let mut witness = valid_witness();
        witness.live_probe.l2_claim_promoted = true;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::L2GreenClaimAttempted)
        ));
        let mut witness = valid_witness();
        witness.next_cursor = "done".to_string();
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeLiveProbeError::NextCursorMismatch)
        ));
    }
}
