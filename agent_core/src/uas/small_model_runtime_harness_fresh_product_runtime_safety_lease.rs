//! Fresh product-runtime safety lease for the small-model harness.
//!
//! This L1 witness is the safety interlock between retained small-model
//! AnswerPacket evidence and any future fresh app-path runtime probe. It is
//! metadata-only: no runtime/model bytes may open here.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_safety_lease";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_live_probe";

const PRODUCT_ROUTE_RECHECK_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_product_route_capability_recheck:";
const LEASE_PREFIX: &str = "lease:";
const SURFACE_PREFIX: &str = "surface:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:";
const DRY_RUN_PREFIX: &str = "dry_run:";
const SAFETY_PLAN_PREFIX: &str = "safety_plan:";
const SERIALIZED_EXECUTOR_PREFIX: &str = "serialized_executor:";
const CANCELLATION_PREFIX: &str = "cancel:";
const DEADLINE_PREFIX: &str = "deadline:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const BUDGET_PREFIX: &str = "budget:";
const ROUTE_AUTHORITY: &str = "fresh_product_runtime_safety_lease_no_route_authority";
const MAX_DEADLINE_MS: u64 = 6_000;
const MAX_RUNTIME_BUDGET_BYTES: u64 = 96 * 1024 * 1024;
const MAX_MODEL_BUDGET_BYTES: u64 = 3 * 1024 * 1024 * 1024;
const MAX_METADATA_BYTES: u64 = 640 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:phase
// Plane: Controller + Verification
// Residency: safety interlock before fresh product runtime bytes.
pub enum SmallModelFreshProductRuntimeSafetyLeasePhase {
    ProductRouteRecheckBound,
    GuardCursorBound,
    CapabilityRedBound,
    OwnerApprovalBound,
    DryRunFallbackBound,
    SerializedExecutorBound,
    CancellationDeadlineBound,
    RollbackBound,
    RunEventLogBound,
    AnswerPacketBound,
    PrivacyFenceBound,
    FreshRuntimeProbeQueued,
}

impl SmallModelFreshProductRuntimeSafetyLeasePhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::ProductRouteRecheckBound => "product_route_recheck_bound",
            Self::GuardCursorBound => "guard_cursor_bound",
            Self::CapabilityRedBound => "capability_red_bound",
            Self::OwnerApprovalBound => "owner_approval_bound",
            Self::DryRunFallbackBound => "dry_run_fallback_bound",
            Self::SerializedExecutorBound => "serialized_executor_bound",
            Self::CancellationDeadlineBound => "cancellation_deadline_bound",
            Self::RollbackBound => "rollback_bound",
            Self::RunEventLogBound => "run_event_log_bound",
            Self::AnswerPacketBound => "answer_packet_bound",
            Self::PrivacyFenceBound => "privacy_fence_bound",
            Self::FreshRuntimeProbeQueued => "fresh_runtime_probe_queued",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:error
// Plane: Verification
// Residency: lease rejection taxonomy.
pub enum SmallModelFreshProductRuntimeSafetyLeaseError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingProductRouteRecheckArtifact(String),
    GuardCursorMismatch,
    CapabilityStatusMismatch,
    ProductStatusMismatch,
    RouteAuthorityMismatch,
    EmptyLease,
    DuplicateLease(String),
    MissingRequiredLease(&'static str),
    EmptyPhase,
    MissingPhase(&'static str),
    MissingOwnerApproval(String),
    MissingDryRun(String),
    MissingSafetyPlan(String),
    MissingSerializedExecutor(String),
    MissingCancellation(String),
    MissingDeadline(String),
    MissingRollback(String),
    MissingRunEventLog(String),
    MissingAnswerPacket(String),
    MissingAdmission(String),
    MissingScopeRex(String),
    MissingSovereignGate(String),
    MissingCompatibilityFence(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    DeadlineOutOfRange(String),
    RuntimeBudgetOutOfRange(String),
    ModelBudgetOutOfRange(String),
    LeaseNotVisible(String),
    OwnerApprovalMissing(String),
    DryRunFirstMissing(String),
    SerializedExecutorMissing(String),
    CancellationMissing(String),
    RollbackMissing(String),
    RunEventLogMissing(String),
    AnswerPacketMissing(String),
    PrivacyFenceMissing(String),
    AdmissionMissing(String),
    HiddenRouteAuthority(String),
    RoutePolicyMutation(String),
    GateBypass(String),
    AnswerPacketSuppression(String),
    HiddenChainExposure(String),
    HiddenCloudFallback(String),
    AppPathSubprocessSpawn(String),
    AutogenousKernelAttempt(String),
    SeventyBProbeAttempt(String),
    LongContextShardProbeAttempt(String),
    FreshRuntimeBytesLoaded,
    FreshModelBytesLoaded,
    RuntimeProbeEnabledBeforeLease,
    L1L2L3NotSeparated,
    MasFloorNotPreserved,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    NextCursorMismatch,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelFreshProductRuntimeSafetyLeaseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingProductRouteRecheckArtifact(id) => {
                write!(f, "witness `{id}` missing product-route recheck artifact")
            }
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::RouteAuthorityMismatch => write!(f, "route authority mismatch"),
            Self::EmptyLease => write!(f, "missing safety lease"),
            Self::DuplicateLease(id) => write!(f, "duplicate safety lease `{id}`"),
            Self::MissingRequiredLease(id) => write!(f, "missing required safety lease `{id}`"),
            Self::EmptyPhase => write!(f, "missing safety-lease phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::MissingOwnerApproval(id) => write!(f, "lease `{id}` missing owner approval"),
            Self::MissingDryRun(id) => write!(f, "lease `{id}` missing dry-run ref"),
            Self::MissingSafetyPlan(id) => write!(f, "lease `{id}` missing safety-plan ref"),
            Self::MissingSerializedExecutor(id) => {
                write!(f, "lease `{id}` missing serialized executor")
            }
            Self::MissingCancellation(id) => write!(f, "lease `{id}` missing cancellation"),
            Self::MissingDeadline(id) => write!(f, "lease `{id}` missing deadline"),
            Self::MissingRollback(id) => write!(f, "lease `{id}` missing rollback"),
            Self::MissingRunEventLog(id) => write!(f, "lease `{id}` missing RunEventLog"),
            Self::MissingAnswerPacket(id) => write!(f, "lease `{id}` missing AnswerPacket"),
            Self::MissingAdmission(id) => write!(f, "lease `{id}` missing admission"),
            Self::MissingScopeRex(id) => write!(f, "lease `{id}` missing SCOPE-Rex"),
            Self::MissingSovereignGate(id) => {
                write!(f, "lease `{id}` missing SovereignGate")
            }
            Self::MissingCompatibilityFence(id) => {
                write!(f, "lease `{id}` missing compatibility fence")
            }
            Self::MissingPrivacyFence(id) => write!(f, "lease `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "lease `{id}` missing budget"),
            Self::DeadlineOutOfRange(id) => write!(f, "lease `{id}` has invalid deadline"),
            Self::RuntimeBudgetOutOfRange(id) => {
                write!(f, "lease `{id}` has invalid runtime byte budget")
            }
            Self::ModelBudgetOutOfRange(id) => {
                write!(f, "lease `{id}` has invalid model byte budget")
            }
            Self::LeaseNotVisible(id) => write!(f, "lease `{id}` is not visible"),
            Self::OwnerApprovalMissing(id) => write!(f, "lease `{id}` lacks owner approval"),
            Self::DryRunFirstMissing(id) => write!(f, "lease `{id}` lacks dry-run-first flag"),
            Self::SerializedExecutorMissing(id) => {
                write!(f, "lease `{id}` lacks serialized executor flag")
            }
            Self::CancellationMissing(id) => write!(f, "lease `{id}` lacks cancellation flag"),
            Self::RollbackMissing(id) => write!(f, "lease `{id}` lacks rollback flag"),
            Self::RunEventLogMissing(id) => write!(f, "lease `{id}` lacks RunEventLog flag"),
            Self::AnswerPacketMissing(id) => write!(f, "lease `{id}` lacks AnswerPacket flag"),
            Self::PrivacyFenceMissing(id) => write!(f, "lease `{id}` lacks privacy flag"),
            Self::AdmissionMissing(id) => write!(f, "lease `{id}` lacks admission flag"),
            Self::HiddenRouteAuthority(id) => write!(f, "lease `{id}` has hidden authority"),
            Self::RoutePolicyMutation(id) => write!(f, "lease `{id}` mutates route policy"),
            Self::GateBypass(id) => write!(f, "lease `{id}` bypasses a gate"),
            Self::AnswerPacketSuppression(id) => {
                write!(f, "lease `{id}` suppresses AnswerPacket")
            }
            Self::HiddenChainExposure(id) => write!(f, "lease `{id}` exposes hidden chain"),
            Self::HiddenCloudFallback(id) => write!(f, "lease `{id}` has hidden cloud fallback"),
            Self::AppPathSubprocessSpawn(id) => {
                write!(f, "lease `{id}` spawns an app-path subprocess")
            }
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "lease `{id}` attempts autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "lease `{id}` attempts 70B probe"),
            Self::LongContextShardProbeAttempt(id) => {
                write!(f, "lease `{id}` attempts a long-context shard")
            }
            Self::FreshRuntimeBytesLoaded => write!(f, "fresh product runtime bytes loaded"),
            Self::FreshModelBytesLoaded => write!(f, "fresh product model bytes loaded"),
            Self::RuntimeProbeEnabledBeforeLease => {
                write!(f, "fresh runtime probe enabled before lease handoff")
            }
            Self::L1L2L3NotSeparated => write!(f, "L1/L2/L3 separation missing"),
            Self::MasFloorNotPreserved => write!(f, "MAS floor not preserved"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::NextCursorMismatch => write!(f, "next cursor mismatch"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelFreshProductRuntimeSafetyLeaseError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:lease
// Plane: Controller + Verification
// Residency: visible lease card for one product runtime surface.
pub struct SmallModelFreshProductRuntimeSafetyLease {
    pub lease_id: String,
    pub product_surface_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub owner_approval_ref: String,
    pub dry_run_witness_ref: String,
    pub safety_plan_ref: String,
    pub serialized_executor_ref: String,
    pub cancellation_ref: String,
    pub deadline_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub route_authority: String,
    pub max_deadline_ms: u64,
    pub max_runtime_bytes_budget: u64,
    pub max_model_bytes_budget: u64,
    pub fresh_runtime_bytes_loaded: u64,
    pub fresh_model_bytes_loaded: u64,
    pub visible: bool,
    pub owner_approved: bool,
    pub dry_run_first: bool,
    pub serialized_executor: bool,
    pub cancellable: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_visible: bool,
    pub privacy_fenced: bool,
    pub admission_bound: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
    pub gate_bypassed: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback: bool,
    pub subprocess_spawned_in_app_path: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub long_context_shard_probe_attempted: bool,
}

impl SmallModelFreshProductRuntimeSafetyLease {
    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeSafetyLeaseError> {
        validate_prefixed_clean("lease_id", &self.lease_id, LEASE_PREFIX)?;
        validate_prefixed_clean(
            "product_surface_ref",
            &self.product_surface_ref,
            SURFACE_PREFIX,
        )?;
        validate_prefixed_clean(
            "owner_approval_ref",
            &self.owner_approval_ref,
            OWNER_APPROVAL_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingOwnerApproval(
                self.lease_id.clone(),
            )
        })?;
        validate_prefixed_clean(
            "dry_run_witness_ref",
            &self.dry_run_witness_ref,
            DRY_RUN_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingDryRun(self.lease_id.clone())
        })?;
        validate_prefixed_clean("safety_plan_ref", &self.safety_plan_ref, SAFETY_PLAN_PREFIX)
            .map_err(|_| {
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingSafetyPlan(
                    self.lease_id.clone(),
                )
            })?;
        validate_prefixed_clean(
            "serialized_executor_ref",
            &self.serialized_executor_ref,
            SERIALIZED_EXECUTOR_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingSerializedExecutor(
                self.lease_id.clone(),
            )
        })?;
        validate_prefixed_clean(
            "cancellation_ref",
            &self.cancellation_ref,
            CANCELLATION_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingCancellation(
                self.lease_id.clone(),
            )
        })?;
        validate_prefixed_clean("deadline_ref", &self.deadline_ref, DEADLINE_PREFIX).map_err(
            |_| {
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingDeadline(
                    self.lease_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean("rollback_ref", &self.rollback_ref, ROLLBACK_PREFIX).map_err(
            |_| {
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingRollback(
                    self.lease_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean(
            "run_event_log_ref",
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingRunEventLog(self.lease_id.clone())
        })?;
        validate_prefixed_clean(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingAnswerPacket(
                self.lease_id.clone(),
            )
        })?;
        validate_prefixed_clean("admission_ref", &self.admission_ref, ADMISSION_PREFIX).map_err(
            |_| {
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingAdmission(
                    self.lease_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean("scope_rex_ref", &self.scope_rex_ref, SCOPE_REX_PREFIX).map_err(
            |_| {
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingScopeRex(
                    self.lease_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean(
            "sovereign_gate_ref",
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingSovereignGate(
                self.lease_id.clone(),
            )
        })?;
        validate_prefixed_clean(
            "compatibility_fence_ref",
            &self.compatibility_fence_ref,
            COMPATIBILITY_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingCompatibilityFence(
                self.lease_id.clone(),
            )
        })?;
        validate_prefixed_clean("privacy_ref", &self.privacy_ref, PRIVACY_PREFIX).map_err(
            |_| {
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingPrivacyFence(
                    self.lease_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean("budget_ref", &self.budget_ref, BUDGET_PREFIX).map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingBudget(self.lease_id.clone())
        })?;
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::ProductStatusMismatch);
        }
        if self.route_authority != ROUTE_AUTHORITY {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::RouteAuthorityMismatch);
        }
        if self.max_deadline_ms == 0 || self.max_deadline_ms > MAX_DEADLINE_MS {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::DeadlineOutOfRange(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.max_runtime_bytes_budget == 0
            || self.max_runtime_bytes_budget > MAX_RUNTIME_BUDGET_BYTES
        {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::RuntimeBudgetOutOfRange(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.max_model_bytes_budget == 0 || self.max_model_bytes_budget > MAX_MODEL_BUDGET_BYTES
        {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::ModelBudgetOutOfRange(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.fresh_runtime_bytes_loaded > 0 {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::FreshRuntimeBytesLoaded);
        }
        if self.fresh_model_bytes_loaded > 0 {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::FreshModelBytesLoaded);
        }
        if !self.visible {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::LeaseNotVisible(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.owner_approved {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::OwnerApprovalMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.dry_run_first {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::DryRunFirstMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.serialized_executor {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::SerializedExecutorMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.cancellable {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::CancellationMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.rollback_bound {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::RollbackMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.run_event_log_bound {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::RunEventLogMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.answer_packet_visible {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::AnswerPacketMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.privacy_fenced {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::PrivacyFenceMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if !self.admission_bound {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::AdmissionMissing(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.hidden_route_authority {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::HiddenRouteAuthority(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.route_policy_mutated {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::RoutePolicyMutation(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.gate_bypassed {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::GateBypass(
                self.lease_id.clone(),
            ));
        }
        if self.answer_packet_suppressed {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::AnswerPacketSuppression(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.hidden_chain_exposed {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::HiddenChainExposure(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.hidden_cloud_fallback {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::HiddenCloudFallback(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.subprocess_spawned_in_app_path {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::AppPathSubprocessSpawn(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::AutogenousKernelAttempt(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.seventy_b_probe_attempted {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::SeventyBProbeAttempt(
                    self.lease_id.clone(),
                ),
            );
        }
        if self.long_context_shard_probe_attempted {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::LongContextShardProbeAttempt(
                    self.lease_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:metrics
// Plane: Verification
// Residency: lease counts, deadlines, budgets, and byte accounting.
pub struct SmallModelFreshProductRuntimeSafetyLeaseMetrics {
    pub lease_count: u64,
    pub phase_count: u64,
    pub max_deadline_ms: u64,
    pub max_runtime_bytes_budget: u64,
    pub max_model_bytes_budget: u64,
    pub fresh_runtime_bytes_loaded: u64,
    pub fresh_model_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:witness
// Plane: Controller + Verification
// Residency: metadata-only interlock before fresh product runtime probe.
pub struct SmallModelFreshProductRuntimeSafetyLeaseWitness {
    pub witness_id: String,
    pub product_route_recheck_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub leases: Vec<SmallModelFreshProductRuntimeSafetyLease>,
    pub phases: Vec<SmallModelFreshProductRuntimeSafetyLeasePhase>,
    pub l1_l2_l3_separated: bool,
    pub mas_floor_preserved: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub fresh_product_runtime_probe_enabled: bool,
    pub next_cursor: String,
    pub metadata_bytes: u64,
}

impl SmallModelFreshProductRuntimeSafetyLeaseWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        product_route_recheck_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        leases: Vec<SmallModelFreshProductRuntimeSafetyLease>,
        phases: Vec<SmallModelFreshProductRuntimeSafetyLeasePhase>,
        l1_l2_l3_separated: bool,
        mas_floor_preserved: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        fresh_product_runtime_probe_enabled: bool,
        next_cursor: impl Into<String>,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelFreshProductRuntimeSafetyLeaseError> {
        let witness = Self {
            witness_id: witness_id.into(),
            product_route_recheck_artifact_ref: product_route_recheck_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            leases,
            phases,
            l1_l2_l3_separated,
            mas_floor_preserved,
            l2_green_claimed,
            l3_green_claimed,
            fresh_product_runtime_probe_enabled,
            next_cursor: next_cursor.into(),
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeSafetyLeaseError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed_clean(
            "product_route_recheck_artifact_ref",
            &self.product_route_recheck_artifact_ref,
            PRODUCT_ROUTE_RECHECK_ARTIFACT_PREFIX,
        )
        .map_err(|_| {
            SmallModelFreshProductRuntimeSafetyLeaseError::MissingProductRouteRecheckArtifact(
                self.witness_id.clone(),
            )
        })?;
        if !matches!(
            self.guard_next_existing_work.as_str(),
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR
                | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR
        ) {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::GuardCursorMismatch);
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
        {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::CapabilityStatusMismatch);
        }
        if !matches!(
            self.capability_next_bottleneck.as_str(),
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR
                | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR
        ) {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::ProductStatusMismatch);
        }
        if self.route_authority != ROUTE_AUTHORITY {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::RouteAuthorityMismatch);
        }
        validate_leases(&self.leases)?;
        validate_phases(&self.phases)?;
        if !self.l1_l2_l3_separated {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::L1L2L3NotSeparated);
        }
        if !self.mas_floor_preserved {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::MasFloorNotPreserved);
        }
        if self.l2_green_claimed {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::L3GreenClaimAttempted);
        }
        if self.fresh_product_runtime_probe_enabled {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::RuntimeProbeEnabledBeforeLease,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeSafetyLeaseMetrics {
        SmallModelFreshProductRuntimeSafetyLeaseMetrics {
            lease_count: self.leases.len() as u64,
            phase_count: self.phases.len() as u64,
            max_deadline_ms: self
                .leases
                .iter()
                .map(|lease| lease.max_deadline_ms)
                .max()
                .unwrap_or(0),
            max_runtime_bytes_budget: self
                .leases
                .iter()
                .map(|lease| lease.max_runtime_bytes_budget)
                .max()
                .unwrap_or(0),
            max_model_bytes_budget: self
                .leases
                .iter()
                .map(|lease| lease.max_model_bytes_budget)
                .max()
                .unwrap_or(0),
            fresh_runtime_bytes_loaded: self
                .leases
                .iter()
                .map(|lease| lease.fresh_runtime_bytes_loaded)
                .sum(),
            fresh_model_bytes_loaded: self
                .leases
                .iter()
                .map(|lease| lease.fresh_model_bytes_loaded)
                .sum(),
            metadata_bytes: self.metadata_bytes,
        }
    }

    pub fn address(&self) -> String {
        let mut payload = String::with_capacity(512 + self.leases.len() * 160);
        payload.push_str(&self.witness_id);
        payload.push('|');
        payload.push_str(&self.product_route_recheck_artifact_ref);
        payload.push('|');
        payload.push_str(&self.next_cursor);
        for lease in &self.leases {
            payload.push('|');
            payload.push_str(&lease.lease_id);
            payload.push('|');
            payload.push_str(&lease.product_surface_ref);
            payload.push('|');
            payload.push_str(&lease.owner_approval_ref);
            payload.push('|');
            payload.push_str(&lease.answer_packet_ref);
            payload.push('|');
            payload.push_str(&lease.run_event_log_ref);
        }
        sha256_hex(payload.as_bytes())
    }
}

pub fn required_fresh_product_runtime_safety_lease_ids() -> Vec<&'static str> {
    vec![
        "lease:note_chat_fresh_product_runtime",
        "lease:settings_diagnostics_fresh_product_runtime",
        "lease:system_g_replay_fresh_product_runtime",
    ]
}

pub fn required_fresh_product_runtime_safety_lease_phases(
) -> Vec<SmallModelFreshProductRuntimeSafetyLeasePhase> {
    vec![
        SmallModelFreshProductRuntimeSafetyLeasePhase::ProductRouteRecheckBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::GuardCursorBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::CapabilityRedBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::OwnerApprovalBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::DryRunFallbackBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::SerializedExecutorBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::CancellationDeadlineBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::RollbackBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::RunEventLogBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::AnswerPacketBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::PrivacyFenceBound,
        SmallModelFreshProductRuntimeSafetyLeasePhase::FreshRuntimeProbeQueued,
    ]
}

pub fn fresh_product_runtime_safety_lease_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

pub fn fresh_product_runtime_safety_lease_max_deadline_ms() -> u64 {
    MAX_DEADLINE_MS
}

pub fn fresh_product_runtime_safety_lease_max_runtime_budget_bytes() -> u64 {
    MAX_RUNTIME_BUDGET_BYTES
}

pub fn fresh_product_runtime_safety_lease_max_model_budget_bytes() -> u64 {
    MAX_MODEL_BUDGET_BYTES
}

pub fn fresh_product_runtime_safety_lease_route_authority() -> &'static str {
    ROUTE_AUTHORITY
}

fn validate_leases(
    leases: &[SmallModelFreshProductRuntimeSafetyLease],
) -> Result<(), SmallModelFreshProductRuntimeSafetyLeaseError> {
    if leases.is_empty() {
        return Err(SmallModelFreshProductRuntimeSafetyLeaseError::EmptyLease);
    }
    let mut seen = HashSet::with_capacity(leases.len());
    for lease in leases {
        lease.validate()?;
        if !seen.insert(lease.lease_id.clone()) {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::DuplicateLease(
                    lease.lease_id.clone(),
                ),
            );
        }
    }
    for required in required_fresh_product_runtime_safety_lease_ids() {
        if !leases.iter().any(|lease| lease.lease_id == required) {
            return Err(
                SmallModelFreshProductRuntimeSafetyLeaseError::MissingRequiredLease(required),
            );
        }
    }
    Ok(())
}

fn validate_phases(
    phases: &[SmallModelFreshProductRuntimeSafetyLeasePhase],
) -> Result<(), SmallModelFreshProductRuntimeSafetyLeaseError> {
    if phases.is_empty() {
        return Err(SmallModelFreshProductRuntimeSafetyLeaseError::EmptyPhase);
    }
    let provided: BTreeSet<&'static str> = phases.iter().map(|phase| phase.tag()).collect();
    for required in required_fresh_product_runtime_safety_lease_phases() {
        if !provided.contains(required.tag()) {
            return Err(SmallModelFreshProductRuntimeSafetyLeaseError::MissingPhase(
                required.tag(),
            ));
        }
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeSafetyLeaseError> {
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeSafetyLeaseError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.is_empty() {
        return Err(SmallModelFreshProductRuntimeSafetyLeaseError::MissingField(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeSafetyLeaseError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

fn validate_prefixed_clean(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeSafetyLeaseError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelFreshProductRuntimeSafetyLeaseError::MissingField(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_lease(id: &str) -> SmallModelFreshProductRuntimeSafetyLease {
        SmallModelFreshProductRuntimeSafetyLease {
            lease_id: id.to_string(),
            product_surface_ref: format!("surface:{id}:product"),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            owner_approval_ref: "owner_approval:fresh-product-runtime:manual-gate".to_string(),
            dry_run_witness_ref: "dry_run:small-model-runtime-harness-dry-run".to_string(),
            safety_plan_ref: "safety_plan:small-model-runtime-harness-safety-plan".to_string(),
            serialized_executor_ref: "serialized_executor:mlx-single-flight".to_string(),
            cancellation_ref: "cancel:fresh-product-runtime:deadline-and-owner-abort".to_string(),
            deadline_ref: "deadline:fresh-product-runtime:6000ms".to_string(),
            rollback_ref: "rollback:fresh-product-runtime:no-route-promotion".to_string(),
            run_event_log_ref: "run_event_log:fresh-product-runtime:required".to_string(),
            answer_packet_ref: "answer_packet:fresh-product-runtime:required".to_string(),
            admission_ref: "admission:scope-rex-sovereign-gate".to_string(),
            scope_rex_ref: "scope_rex:fresh-product-runtime".to_string(),
            sovereign_gate_ref: "sovereign_gate:fresh-product-runtime".to_string(),
            compatibility_fence_ref: "compat:mas-pro-product-route-boundary".to_string(),
            privacy_ref: "privacy:redacted-visible-summary-no-hidden-chain".to_string(),
            budget_ref: "budget:fresh-product-runtime:bounded-qwen3-4b".to_string(),
            route_authority: ROUTE_AUTHORITY.to_string(),
            max_deadline_ms: MAX_DEADLINE_MS,
            max_runtime_bytes_budget: MAX_RUNTIME_BUDGET_BYTES,
            max_model_bytes_budget: MAX_MODEL_BUDGET_BYTES,
            fresh_runtime_bytes_loaded: 0,
            fresh_model_bytes_loaded: 0,
            visible: true,
            owner_approved: true,
            dry_run_first: true,
            serialized_executor: true,
            cancellable: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_visible: true,
            privacy_fenced: true,
            admission_bound: true,
            hidden_route_authority: false,
            route_policy_mutated: false,
            gate_bypassed: false,
            answer_packet_suppressed: false,
            hidden_chain_exposed: false,
            hidden_cloud_fallback: false,
            subprocess_spawned_in_app_path: false,
            autogenous_kernel_attempted: false,
            seventy_b_probe_attempted: false,
            long_context_shard_probe_attempted: false,
        }
    }

    fn valid_witness() -> SmallModelFreshProductRuntimeSafetyLeaseWitness {
        SmallModelFreshProductRuntimeSafetyLeaseWitness::new(
            "small-model-fresh-product-runtime-safety-lease:v1",
            "artifact:small_model_runtime_harness_product_route_capability_recheck:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            ROUTE_AUTHORITY,
            required_fresh_product_runtime_safety_lease_ids()
                .into_iter()
                .map(valid_lease)
                .collect(),
            required_fresh_product_runtime_safety_lease_phases(),
            true,
            true,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
            1,
        )
        .expect("valid witness")
    }

    #[test]
    fn required_leases_validate() {
        let witness = valid_witness();
        assert_eq!(
            witness.metrics().lease_count,
            required_fresh_product_runtime_safety_lease_ids().len() as u64
        );
        assert!(witness.validate().is_ok());
    }

    #[test]
    fn rejects_missing_required_lease() {
        let mut witness = valid_witness();
        witness.leases.pop();
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::MissingRequiredLease(_))
        ));
    }

    #[test]
    fn rejects_duplicate_lease() {
        let mut witness = valid_witness();
        witness.leases[1] = witness.leases[0].clone();
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::DuplicateLease(_))
        ));
    }

    #[test]
    fn rejects_deadline_zero_and_overflow() {
        let mut witness = valid_witness();
        witness.leases[0].max_deadline_ms = 0;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::DeadlineOutOfRange(_))
        ));
        let mut witness = valid_witness();
        witness.leases[0].max_deadline_ms = MAX_DEADLINE_MS + 1;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::DeadlineOutOfRange(_))
        ));
    }

    #[test]
    fn rejects_missing_rollback_and_answer_packet() {
        let mut witness = valid_witness();
        witness.leases[0].rollback_ref.clear();
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::MissingRollback(_))
        ));
        let mut witness = valid_witness();
        witness.leases[0].answer_packet_visible = false;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::AnswerPacketMissing(_))
        ));
    }

    #[test]
    fn rejects_hidden_authority_and_mutation() {
        let mut witness = valid_witness();
        witness.leases[0].hidden_route_authority = true;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::HiddenRouteAuthority(_))
        ));
        let mut witness = valid_witness();
        witness.leases[0].route_policy_mutated = true;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::RoutePolicyMutation(_))
        ));
    }

    #[test]
    fn rejects_fresh_bytes_and_runtime_probe_enablement() {
        let mut witness = valid_witness();
        witness.leases[0].fresh_runtime_bytes_loaded = 1;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::FreshRuntimeBytesLoaded)
        ));
        let mut witness = valid_witness();
        witness.leases[0].fresh_model_bytes_loaded = 1;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::FreshModelBytesLoaded)
        ));
        let mut witness = valid_witness();
        witness.fresh_product_runtime_probe_enabled = true;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::RuntimeProbeEnabledBeforeLease)
        ));
    }

    #[test]
    fn rejects_l2_l3_claims_and_next_cursor_drift() {
        let mut witness = valid_witness();
        witness.l2_green_claimed = true;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::L2GreenClaimAttempted)
        ));
        let mut witness = valid_witness();
        witness.l3_green_claimed = true;
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::L3GreenClaimAttempted)
        ));
        let mut witness = valid_witness();
        witness.next_cursor = "done".to_string();
        assert!(matches!(
            witness.validate(),
            Err(SmallModelFreshProductRuntimeSafetyLeaseError::NextCursorMismatch)
        ));
    }
}
