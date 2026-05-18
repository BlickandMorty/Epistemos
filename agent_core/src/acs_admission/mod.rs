//! ACS admission field.
//!
//! ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
//! admission is a policy boundary above SCOPE-Rex. It is intentionally
//! pure-data: it does not call cloud providers, run inference, or apply
//! durable state changes directly.

use serde::{Deserialize, Serialize};

use crate::{
    effect::receipt::Capability, mutations::MutationEnvelope,
    scope_rex::answer_packet::AnswerPacket,
};

/// Risk vector evaluated by ACS admission before a request can become
/// durable or promote into a stronger runtime lane.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ACSRiskVector {
    pub truth_risk: f32,
    pub safety_risk: f32,
    pub privacy_risk: f32,
    pub capability_risk: f32,
    pub durability_risk: f32,
    pub scope_rex_risk: f32,
    pub kernel_promotion_risk: f32,
    pub model_adaptation_risk: f32,
    pub evidence_present: bool,
}

impl ACSRiskVector {
    pub const fn neutral() -> Self {
        Self {
            truth_risk: 0.0,
            safety_risk: 0.0,
            privacy_risk: 0.0,
            capability_risk: 0.0,
            durability_risk: 0.0,
            scope_rex_risk: 0.0,
            kernel_promotion_risk: 0.0,
            model_adaptation_risk: 0.0,
            evidence_present: true,
        }
    }

    pub fn validate(&self) -> Result<(), ACSRiskVectorError> {
        for (field, value) in self.fields() {
            if !value.is_finite() {
                return Err(ACSRiskVectorError::NonFinite { field });
            }
            if !(0.0..=1.0).contains(&value) {
                return Err(ACSRiskVectorError::OutOfRange { field });
            }
        }
        Ok(())
    }

    pub fn max_axis(&self) -> f32 {
        self.fields()
            .into_iter()
            .map(|(_, value)| value)
            .fold(0.0, f32::max)
    }

    fn fields(&self) -> [(&'static str, f32); 8] {
        [
            ("truth_risk", self.truth_risk),
            ("safety_risk", self.safety_risk),
            ("privacy_risk", self.privacy_risk),
            ("capability_risk", self.capability_risk),
            ("durability_risk", self.durability_risk),
            ("scope_rex_risk", self.scope_rex_risk),
            ("kernel_promotion_risk", self.kernel_promotion_risk),
            ("model_adaptation_risk", self.model_adaptation_risk),
        ]
    }
}

/// Defensive validation failures for [`ACSRiskVector`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSRiskVectorError {
    NonFinite { field: &'static str },
    OutOfRange { field: &'static str },
}

impl ACSRiskVectorError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::NonFinite { .. } => "non_finite_risk_axis",
            Self::OutOfRange { .. } => "risk_axis_out_of_range",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::NonFinite { field } | Self::OutOfRange { field } => field,
        }
    }
}

/// Admission operation family used by policy capability rules.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ACSOperationKind {
    MutationEnvelope,
    ActiveAssemblyPacket,
    AnswerPacket,
    MemoryWrite,
    ToolAction,
    KernelPromotion,
    ModelAdaptation,
}

impl ACSOperationKind {
    pub const fn lane(self) -> ACSLane {
        match self {
            Self::MutationEnvelope | Self::AnswerPacket | Self::MemoryWrite => ACSLane::L0,
            Self::ToolAction | Self::ActiveAssemblyPacket => ACSLane::L1,
            Self::KernelPromotion | Self::ModelAdaptation => ACSLane::L2,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ACSLane {
    L0,
    L1,
    L2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum ACSAdmissionPayload {
    MutationEnvelope { envelope: Box<MutationEnvelope> },
    ActiveAssemblyPacket { packet: ActiveAssemblyPacket },
    AnswerPacket { packet: Box<AnswerPacket> },
    MemoryWrite { request: ACSMemoryWriteRequest },
    ToolAction { request: ACSToolActionRequest },
    KernelPromotion { request: ACSKernelPromotionRequest },
    ModelAdaptation { request: ACSModelAdaptationRequest },
}

impl ACSAdmissionPayload {
    pub const fn operation(&self) -> ACSOperationKind {
        match self {
            Self::MutationEnvelope { .. } => ACSOperationKind::MutationEnvelope,
            Self::ActiveAssemblyPacket { .. } => ACSOperationKind::ActiveAssemblyPacket,
            Self::AnswerPacket { .. } => ACSOperationKind::AnswerPacket,
            Self::MemoryWrite { .. } => ACSOperationKind::MemoryWrite,
            Self::ToolAction { .. } => ACSOperationKind::ToolAction,
            Self::KernelPromotion { .. } => ACSOperationKind::KernelPromotion,
            Self::ModelAdaptation { .. } => ACSOperationKind::ModelAdaptation,
        }
    }

    pub const fn lane(&self) -> ACSLane {
        self.operation().lane()
    }

    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        match self {
            Self::MutationEnvelope { envelope } => {
                require_non_empty(&envelope.mutation_id, "mutation_envelope.mutation_id")
            }
            Self::ActiveAssemblyPacket { packet } => packet.validate(),
            Self::AnswerPacket { packet } => {
                require_non_empty(&packet.id.0, "answer_packet.id")?;
                require_non_empty(
                    &packet.mutation_envelope_ref.0,
                    "answer_packet.mutation_envelope_ref",
                )
            }
            Self::MemoryWrite { request } => request.validate(),
            Self::ToolAction { request } => request.validate(),
            Self::KernelPromotion { request } => request.validate(),
            Self::ModelAdaptation { request } => request.validate(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActiveAssemblyPacket {
    pub assembly_id: String,
    #[serde(default)]
    pub active_support_ids: Vec<String>,
    pub witness_hash: String,
}

impl ActiveAssemblyPacket {
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.assembly_id, "active_assembly.assembly_id")?;
        require_non_empty(&self.witness_hash, "active_assembly.witness_hash")?;
        if self.active_support_ids.is_empty() {
            return Err(ACSAdmissionInputError::Forged {
                field: "active_assembly.active_support_ids",
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ACSMemoryWriteRequest {
    pub address: String,
    pub content_hash: String,
    pub durable: bool,
    pub mutation_envelope_id: Option<String>,
}

impl ACSMemoryWriteRequest {
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.address, "memory_write.address")?;
        require_non_empty(&self.content_hash, "memory_write.content_hash")?;
        if self.durable && missing_or_blank(self.mutation_envelope_id.as_deref()) {
            return Err(ACSAdmissionInputError::DurableWriteBypass {
                field: "memory_write.mutation_envelope_id",
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ACSToolActionRequest {
    pub tool_name: String,
    pub target: String,
    pub mutation_envelope_id: Option<String>,
}

impl ACSToolActionRequest {
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.tool_name, "tool_action.tool_name")?;
        require_non_empty(&self.target, "tool_action.target")
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ACSKernelPromotionRequest {
    pub kernel_id: String,
    pub signed_plan_hash: String,
    pub mutation_envelope_id: Option<String>,
}

impl ACSKernelPromotionRequest {
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.kernel_id, "kernel_promotion.kernel_id")?;
        require_non_empty(&self.signed_plan_hash, "kernel_promotion.signed_plan_hash")?;
        if missing_or_blank(self.mutation_envelope_id.as_deref()) {
            return Err(ACSAdmissionInputError::KernelPromotionBypass {
                field: "kernel_promotion.mutation_envelope_id",
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ACSModelAdaptationRequest {
    pub adapter_id: String,
    pub model_id: String,
    pub checkpoint_hash: String,
    pub mutation_envelope_id: Option<String>,
}

impl ACSModelAdaptationRequest {
    fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        require_non_empty(&self.adapter_id, "model_adaptation.adapter_id")?;
        require_non_empty(&self.model_id, "model_adaptation.model_id")?;
        require_non_empty(&self.checkpoint_hash, "model_adaptation.checkpoint_hash")?;
        if missing_or_blank(self.mutation_envelope_id.as_deref()) {
            return Err(ACSAdmissionInputError::ModelAdaptationBypass {
                field: "model_adaptation.mutation_envelope_id",
            });
        }
        Ok(())
    }
}

fn require_non_empty(value: &str, field: &'static str) -> Result<(), ACSAdmissionInputError> {
    if value.trim().is_empty() {
        Err(ACSAdmissionInputError::Forged { field })
    } else {
        Ok(())
    }
}

fn missing_or_blank(value: Option<&str>) -> bool {
    match value {
        Some(value) => value.trim().is_empty(),
        None => true,
    }
}

/// Data-only ACS request envelope. It carries the caller's declared operation,
/// risk vector, and already-granted capabilities without applying any state.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ACSAdmissionInput {
    pub request_id: String,
    pub payload: ACSAdmissionPayload,
    pub submitted_at_ms: i64,
    pub risk: ACSRiskVector,
    #[serde(default)]
    pub granted_capabilities: Vec<Capability>,
}

impl ACSAdmissionInput {
    pub fn validate(&self) -> Result<(), ACSAdmissionInputError> {
        if self.request_id.trim().is_empty() {
            return Err(ACSAdmissionInputError::Forged {
                field: "request_id",
            });
        }
        if self.submitted_at_ms < 0 {
            return Err(ACSAdmissionInputError::Forged {
                field: "submitted_at_ms",
            });
        }
        self.risk
            .validate()
            .map_err(|_| ACSAdmissionInputError::Forged { field: "risk" })?;
        self.payload.validate()
    }

    pub const fn operation(&self) -> ACSOperationKind {
        self.payload.operation()
    }
}

/// Defensive request validation failures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAdmissionInputError {
    Forged { field: &'static str },
    DurableWriteBypass { field: &'static str },
    KernelPromotionBypass { field: &'static str },
    ModelAdaptationBypass { field: &'static str },
}

impl ACSAdmissionInputError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Forged { .. } => "forged_admission_input",
            Self::DurableWriteBypass { .. } => "durable_write_bypass_attempt",
            Self::KernelPromotionBypass { .. } => "kernel_promotion_bypass_attempt",
            Self::ModelAdaptationBypass { .. } => "model_adaptation_bypass_attempt",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::Forged { field }
            | Self::DurableWriteBypass { field }
            | Self::KernelPromotionBypass { field }
            | Self::ModelAdaptationBypass { field } => field,
        }
    }
}

/// Pure-data ACS admission outcome. The caller decides how to render or
/// enforce it; ACS only classifies the request.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ACSAdmissionVerdict {
    Allow,
    AllowWithWarning,
    Defer,
    Quarantine,
    Reject,
}

impl ACSAdmissionVerdict {
    pub fn from_risk(risk: &ACSRiskVector, thresholds: ACSRiskThresholds) -> Self {
        let max_axis = risk.max_axis();
        if max_axis >= thresholds.reject_at {
            Self::Reject
        } else if max_axis >= thresholds.quarantine_at {
            Self::Quarantine
        } else if max_axis >= thresholds.defer_at {
            Self::Defer
        } else if max_axis >= thresholds.warn_at || !risk.evidence_present {
            Self::AllowWithWarning
        } else {
            Self::Allow
        }
    }

    pub const fn allows_durable_commit(self) -> bool {
        matches!(self, Self::Allow | Self::AllowWithWarning)
    }

    pub const fn is_terminal(self) -> bool {
        matches!(self, Self::Quarantine | Self::Reject)
    }

    pub const fn retry_limit(self) -> Option<u8> {
        match self {
            Self::Defer => Some(3),
            Self::Allow | Self::AllowWithWarning | Self::Quarantine | Self::Reject => None,
        }
    }

    pub const fn allows_retry(self, prior_attempts: u8) -> bool {
        match self.retry_limit() {
            Some(limit) => prior_attempts < limit,
            None => false,
        }
    }

    pub const fn severity_rank(self) -> u8 {
        match self {
            Self::Allow => 0,
            Self::AllowWithWarning => 1,
            Self::Defer => 2,
            Self::Quarantine => 3,
            Self::Reject => 4,
        }
    }

    pub const fn code(self) -> &'static str {
        match self {
            Self::Allow => "allow",
            Self::AllowWithWarning => "allow_with_warning",
            Self::Defer => "defer",
            Self::Quarantine => "quarantine",
            Self::Reject => "reject",
        }
    }
}

/// One emitted admission record. This is the audit artifact for ACS verdicts;
/// callers can persist or attach it without ACS mutating durable state itself.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ACSAuditRecord {
    pub record_id: String,
    pub request_id: String,
    pub policy_id: String,
    pub policy_version: u32,
    pub operation: ACSOperationKind,
    pub verdict: ACSAdmissionVerdict,
    pub reason: String,
    pub risk_max: f32,
    pub emitted_at_ms: i64,
}

impl ACSAuditRecord {
    pub fn validate(&self) -> Result<(), ACSAuditRecordError> {
        if self.record_id.trim().is_empty() {
            return Err(ACSAuditRecordError::Corrupt { field: "record_id" });
        }
        if !self.record_id.starts_with("acs:") {
            return Err(ACSAuditRecordError::Corrupt { field: "record_id" });
        }
        if self.request_id.trim().is_empty() {
            return Err(ACSAuditRecordError::Corrupt {
                field: "request_id",
            });
        }
        if self.policy_id.trim().is_empty() {
            return Err(ACSAuditRecordError::Corrupt { field: "policy_id" });
        }
        if self.policy_version == 0 {
            return Err(ACSAuditRecordError::Corrupt {
                field: "policy_version",
            });
        }
        if self.reason.trim().is_empty() {
            return Err(ACSAuditRecordError::Corrupt { field: "reason" });
        }
        if !self.risk_max.is_finite() || !(0.0..=1.0).contains(&self.risk_max) {
            return Err(ACSAuditRecordError::Corrupt { field: "risk_max" });
        }
        if self.emitted_at_ms < 0 {
            return Err(ACSAuditRecordError::Corrupt {
                field: "emitted_at_ms",
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAuditRecordError {
    Corrupt { field: &'static str },
}

impl ACSAuditRecordError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Corrupt { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::Corrupt { field } => field,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AuditRecordId(pub String);

impl AuditRecordId {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    fn validate(&self) -> Result<(), ACSAdmissionProofError> {
        if self.0.trim().is_empty() {
            Err(ACSAdmissionProofError::MissingRecordId)
        } else if !self.0.starts_with("acs:") {
            Err(ACSAdmissionProofError::InvalidRecordId)
        } else {
            Ok(())
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct CapabilitySignature(pub String);

impl CapabilitySignature {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    fn validate(&self) -> Result<(), ACSAdmissionProofError> {
        if self.0.trim().is_empty() {
            Err(ACSAdmissionProofError::MissingCapabilitySignature)
        } else {
            Ok(())
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SCOPERexAdmissionProof {
    pub verdict: ACSAdmissionVerdict,
    pub record_id: AuditRecordId,
    pub signature: CapabilitySignature,
}

impl SCOPERexAdmissionProof {
    pub fn new(
        verdict: ACSAdmissionVerdict,
        record_id: AuditRecordId,
        signature: CapabilitySignature,
    ) -> Result<Self, ACSAdmissionProofError> {
        record_id.validate()?;
        signature.validate()?;
        Ok(Self {
            verdict,
            record_id,
            signature,
        })
    }

    pub fn from_record(
        record: &ACSAuditRecord,
        signature: CapabilitySignature,
    ) -> Result<Self, ACSAdmissionProofError> {
        record
            .validate()
            .map_err(|err| ACSAdmissionProofError::CorruptAuditRecord { field: err.field() })?;
        Self::new(
            record.verdict,
            AuditRecordId::new(record.record_id.clone()),
            signature,
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAdmissionProofError {
    MissingRecordId,
    InvalidRecordId,
    MissingCapabilitySignature,
    CorruptAuditRecord { field: &'static str },
}

impl ACSAdmissionProofError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MissingRecordId => "missing_audit_record_id",
            Self::InvalidRecordId => "invalid_audit_record_id",
            Self::MissingCapabilitySignature => "missing_capability_signature",
            Self::CorruptAuditRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptAuditRecord { field } => Some(field),
            Self::MissingRecordId | Self::InvalidRecordId | Self::MissingCapabilitySignature => {
                None
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ACSAdmissionDecision {
    pub verdict: ACSAdmissionVerdict,
    pub audit_record: ACSAuditRecord,
}

pub trait ACSAuditSink {
    fn record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAuditError {
    SinkUnavailable,
    CorruptRecord { field: &'static str },
}

impl ACSAuditError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::SinkUnavailable => "acs_audit_sink_unavailable",
            Self::CorruptRecord { .. } => "corrupt_acs_audit_record",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptRecord { field } => Some(field),
            Self::SinkUnavailable => None,
        }
    }
}

#[derive(Debug, Default)]
pub struct InMemoryACSAuditSink {
    records: std::sync::Mutex<Vec<ACSAuditRecord>>,
}

impl InMemoryACSAuditSink {
    pub fn records(&self) -> Result<Vec<ACSAuditRecord>, ACSAuditError> {
        self.records
            .lock()
            .map(|records| records.clone())
            .map_err(|_| ACSAuditError::SinkUnavailable)
    }
}

impl ACSAuditSink for InMemoryACSAuditSink {
    fn record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError> {
        record
            .validate()
            .map_err(|err| ACSAuditError::CorruptRecord { field: err.field() })?;
        self.records
            .lock()
            .map(|mut records| records.push(record))
            .map_err(|_| ACSAuditError::SinkUnavailable)
    }
}

pub fn admit_and_log(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    audit_log: &mut Vec<ACSAuditRecord>,
) -> ACSAdmissionDecision {
    let decision = admit(input, policy, now_ms);
    audit_log.push(decision.audit_record.clone());
    decision
}

pub fn admit_and_record<S: ACSAuditSink + ?Sized>(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    sink: &S,
) -> Result<ACSAdmissionDecision, ACSAuditError> {
    let decision = admit(input, policy, now_ms);
    sink.record(decision.audit_record.clone())?;
    Ok(decision)
}

pub fn admit(input: &ACSAdmissionInput, policy: &ACSPolicy, now_ms: i64) -> ACSAdmissionDecision {
    if now_ms < 0 {
        return decision(
            input,
            policy,
            0,
            ACSAdmissionVerdict::Reject,
            "invalid_admission_time",
        );
    }

    if let Err(err) = policy.validate_at(now_ms) {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            err.cause(),
        );
    }

    if let Err(err) = input.validate() {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            err.cause(),
        );
    }

    if input.submitted_at_ms > now_ms {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "future_admission_input",
        );
    }

    if policy
        .required_for(input.operation())
        .iter()
        .any(|capability| !input.granted_capabilities.contains(capability))
    {
        return decision(
            input,
            policy,
            now_ms,
            ACSAdmissionVerdict::Reject,
            "missing_capability",
        );
    }

    let verdict =
        ACSAdmissionVerdict::from_risk(&input.risk, policy.thresholds_for(input.operation()));
    decision(input, policy, now_ms, verdict, verdict.code())
}

pub fn guard_durable_commit(record: Option<&ACSAuditRecord>) -> Result<(), ACSDurableCommitError> {
    let record = record.ok_or(ACSDurableCommitError::MissingAuditRecord)?;
    record
        .validate()
        .map_err(|err| ACSDurableCommitError::CorruptAuditRecord { field: err.field() })?;
    if record.verdict.allows_durable_commit() {
        Ok(())
    } else {
        Err(ACSDurableCommitError::BlockedByVerdict {
            verdict: record.verdict,
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSDurableCommitError {
    MissingAuditRecord,
    CorruptAuditRecord { field: &'static str },
    BlockedByVerdict { verdict: ACSAdmissionVerdict },
}

impl ACSDurableCommitError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::MissingAuditRecord => "missing_acs_audit_record",
            Self::CorruptAuditRecord { .. } => "corrupt_acs_audit_record",
            Self::BlockedByVerdict { .. } => "acs_verdict_blocks_durable_commit",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::CorruptAuditRecord { field } => Some(field),
            Self::MissingAuditRecord | Self::BlockedByVerdict { .. } => None,
        }
    }

    pub const fn verdict(&self) -> Option<ACSAdmissionVerdict> {
        match self {
            Self::BlockedByVerdict { verdict } => Some(*verdict),
            Self::MissingAuditRecord | Self::CorruptAuditRecord { .. } => None,
        }
    }
}

fn decision(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    verdict: ACSAdmissionVerdict,
    reason: &str,
) -> ACSAdmissionDecision {
    let request_id = audit_text(&input.request_id, "malformed_request");
    let policy_id = audit_text(&policy.policy_id, "malformed_policy");
    ACSAdmissionDecision {
        verdict,
        audit_record: ACSAuditRecord {
            record_id: format!("acs:{}:{}", request_id, now_ms),
            request_id,
            policy_id,
            policy_version: policy.version,
            operation: input.operation(),
            verdict,
            reason: reason.to_string(),
            risk_max: audit_risk_max(&input.risk),
            emitted_at_ms: now_ms,
        },
    }
}

fn audit_text(value: &str, fallback: &'static str) -> String {
    if value.trim().is_empty() {
        fallback.to_string()
    } else {
        value.to_string()
    }
}

fn audit_risk_max(risk: &ACSRiskVector) -> f32 {
    if risk.validate().is_ok() {
        risk.max_axis()
    } else {
        1.0
    }
}

/// Risk thresholds for policy verdict selection.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ACSRiskThresholds {
    pub warn_at: f32,
    pub defer_at: f32,
    pub quarantine_at: f32,
    pub reject_at: f32,
}

impl ACSRiskThresholds {
    pub const fn standard() -> Self {
        Self {
            warn_at: 0.35,
            defer_at: 0.55,
            quarantine_at: 0.75,
            reject_at: 0.9,
        }
    }

    fn validate(&self) -> Result<(), ACSPolicyError> {
        for (field, value) in [
            ("warn_at", self.warn_at),
            ("defer_at", self.defer_at),
            ("quarantine_at", self.quarantine_at),
            ("reject_at", self.reject_at),
        ] {
            if !value.is_finite() || !(0.0..=1.0).contains(&value) {
                return Err(ACSPolicyError::Malformed { field });
            }
        }

        if !(self.warn_at <= self.defer_at
            && self.defer_at <= self.quarantine_at
            && self.quarantine_at <= self.reject_at)
        {
            return Err(ACSPolicyError::Malformed {
                field: "risk_threshold_order",
            });
        }

        Ok(())
    }
}

/// One capability requirement bound to an ACS operation family.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ACSCapabilityRule {
    pub operation: ACSOperationKind,
    pub capability: Capability,
}

impl ACSCapabilityRule {
    pub fn new(operation: ACSOperationKind, capability: Capability) -> Self {
        Self {
            operation,
            capability,
        }
    }

    fn validate(&self) -> Result<(), ACSPolicyError> {
        validate_required_capability(&self.capability)
    }
}

fn validate_required_capability(capability: &Capability) -> Result<(), ACSPolicyError> {
    match capability {
        Capability::VaultPath { path, verb } => {
            if path.trim().is_empty() {
                return Err(ACSPolicyError::Malformed {
                    field: "required_capabilities.vault_path.path",
                });
            }
            if verb.trim().is_empty() {
                return Err(ACSPolicyError::Malformed {
                    field: "required_capabilities.vault_path.verb",
                });
            }
        }
        Capability::NetworkHost { host } => {
            if host.trim().is_empty() {
                return Err(ACSPolicyError::Malformed {
                    field: "required_capabilities.network_host.host",
                });
            }
        }
        Capability::BiometricSession { ttl_secs } => {
            if *ttl_secs == 0 {
                return Err(ACSPolicyError::Malformed {
                    field: "required_capabilities.biometric_session.ttl_secs",
                });
            }
        }
        Capability::Other { name } => {
            if name.trim().is_empty() {
                return Err(ACSPolicyError::Malformed {
                    field: "required_capabilities.other.name",
                });
            }
        }
    }

    Ok(())
}

/// Operation-specific threshold override for default ACS policy matrices.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ACSOperationThresholdRule {
    pub operation: ACSOperationKind,
    pub thresholds: ACSRiskThresholds,
}

impl ACSOperationThresholdRule {
    pub const fn new(operation: ACSOperationKind, thresholds: ACSRiskThresholds) -> Self {
        Self {
            operation,
            thresholds,
        }
    }
}

/// Policy carried into ACS admission. It is data-only and request-scoped.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ACSPolicy {
    pub policy_id: String,
    pub version: u32,
    pub valid_from_ms: i64,
    pub expires_at_ms: Option<i64>,
    pub thresholds: ACSRiskThresholds,
    #[serde(default)]
    pub required_capabilities: Vec<ACSCapabilityRule>,
    #[serde(default)]
    pub operation_thresholds: Vec<ACSOperationThresholdRule>,
}

impl ACSPolicy {
    pub fn strict(policy_id: impl Into<String>, valid_from_ms: i64) -> Self {
        Self {
            policy_id: policy_id.into(),
            version: 1,
            valid_from_ms,
            expires_at_ms: Some(valid_from_ms + 60_000),
            thresholds: ACSRiskThresholds::standard(),
            required_capabilities: Vec::new(),
            operation_thresholds: Vec::new(),
        }
    }

    pub fn strict_default(valid_from_ms: i64) -> Self {
        let mut policy = Self::strict("acs-strict-default", valid_from_ms)
            .require_capability(
                ACSOperationKind::MemoryWrite,
                named_capability("VaultWrite"),
            )
            .require_capability(ACSOperationKind::ToolAction, named_capability("ToolExec"))
            .require_capability(
                ACSOperationKind::ActiveAssemblyPacket,
                named_capability("Assembly"),
            )
            .require_capability(
                ACSOperationKind::KernelPromotion,
                named_capability("KernelPromote"),
            )
            .require_capability(
                ACSOperationKind::ModelAdaptation,
                named_capability("ModelAdapt"),
            );

        policy.operation_thresholds = vec![
            ACSOperationThresholdRule::new(
                ACSOperationKind::MemoryWrite,
                ACSRiskThresholds {
                    quarantine_at: 0.75,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ToolAction,
                ACSRiskThresholds {
                    quarantine_at: 0.65,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ActiveAssemblyPacket,
                ACSRiskThresholds {
                    defer_at: 0.55,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::KernelPromotion,
                ACSRiskThresholds {
                    quarantine_at: 0.6,
                    reject_at: 0.6,
                    ..ACSRiskThresholds::standard()
                },
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ModelAdaptation,
                ACSRiskThresholds {
                    defer_at: 0.5,
                    quarantine_at: 0.5,
                    reject_at: 0.5,
                    ..ACSRiskThresholds::standard()
                },
            ),
        ];
        policy
    }

    pub fn validate_at(&self, now_ms: i64) -> Result<(), ACSPolicyError> {
        if self.policy_id.trim().is_empty() {
            return Err(ACSPolicyError::Malformed { field: "policy_id" });
        }
        if self.version == 0 {
            return Err(ACSPolicyError::Malformed { field: "version" });
        }
        if self
            .expires_at_ms
            .is_some_and(|expires_at_ms| expires_at_ms <= self.valid_from_ms)
        {
            return Err(ACSPolicyError::Malformed {
                field: "expires_at_ms",
            });
        }
        if now_ms < self.valid_from_ms {
            return Err(ACSPolicyError::NotYetValid);
        }
        if self
            .expires_at_ms
            .is_some_and(|expires_at_ms| now_ms > expires_at_ms)
        {
            return Err(ACSPolicyError::Expired);
        }
        self.thresholds.validate()?;
        let mut threshold_operations = std::collections::HashSet::new();
        for rule in &self.operation_thresholds {
            if !threshold_operations.insert(rule.operation) {
                return Err(ACSPolicyError::Malformed {
                    field: "operation_thresholds.duplicate_operation",
                });
            }
            rule.thresholds.validate()?;
        }
        for rule in &self.required_capabilities {
            rule.validate()?;
        }
        Ok(())
    }

    pub fn require_capability(
        mut self,
        operation: ACSOperationKind,
        capability: Capability,
    ) -> Self {
        self.required_capabilities
            .push(ACSCapabilityRule::new(operation, capability));
        self
    }

    pub fn required_for(&self, operation: ACSOperationKind) -> Vec<Capability> {
        self.required_capabilities
            .iter()
            .filter(|rule| rule.operation == operation)
            .map(|rule| rule.capability.clone())
            .collect()
    }

    pub fn thresholds_for(&self, operation: ACSOperationKind) -> ACSRiskThresholds {
        self.operation_thresholds
            .iter()
            .find(|rule| rule.operation == operation)
            .map(|rule| rule.thresholds)
            .unwrap_or(self.thresholds)
    }
}

fn named_capability(name: impl Into<String>) -> Capability {
    Capability::Other { name: name.into() }
}

/// Defensive policy validation failures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSPolicyError {
    Expired,
    NotYetValid,
    Malformed { field: &'static str },
}

impl ACSPolicyError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Expired => "expired_policy",
            Self::NotYetValid => "policy_not_yet_valid",
            Self::Malformed { .. } => "malformed_policy",
        }
    }

    pub const fn field(&self) -> Option<&'static str> {
        match self {
            Self::Malformed { field } => Some(field),
            Self::Expired | Self::NotYetValid => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        mutations::types::{MutationActor, Reversibility, Sensitivity, SourceOp},
        scope_rex::answer_packet::{AnswerPacketId, MutationEnvelopeId, WitnessedStateId},
    };

    #[test]
    fn acs_admission_forged_risk_vector_is_rejected() {
        let mut forged = ACSRiskVector::neutral();
        forged.durability_risk = f32::NAN;

        let err = forged.validate().unwrap_err();
        assert_eq!(err.cause(), "non_finite_risk_axis");
        assert_eq!(err.field(), "durability_risk");

        forged.durability_risk = 1.01;
        let err = forged.validate().unwrap_err();
        assert_eq!(err.cause(), "risk_axis_out_of_range");
        assert_eq!(err.field(), "durability_risk");
    }

    #[test]
    fn acs_admission_neutral_risk_vector_is_well_formed() {
        let risk = ACSRiskVector::neutral();
        assert!(risk.validate().is_ok());
        assert_eq!(risk.max_axis(), 0.0);
        assert!(risk.evidence_present);
    }

    #[test]
    fn acs_admission_expired_policy_is_denied() {
        let policy = ACSPolicy::strict("policy-expired", 1_000);
        let err = policy.validate_at(61_001).unwrap_err();

        assert_eq!(err.cause(), "expired_policy");
        assert_eq!(err.field(), None);
    }

    #[test]
    fn acs_admission_policy_time_bounds_are_inclusive() {
        let policy = ACSPolicy::strict("policy-bounds", 1_000);

        assert!(policy.validate_at(1_000).is_ok());
        assert!(policy.validate_at(61_000).is_ok());
    }

    #[test]
    fn acs_admission_strict_default_policy_matches_operation_matrix() {
        let policy = ACSPolicy::strict_default(1_000);
        let cases = [
            (
                ACSOperationKind::MemoryWrite,
                "VaultWrite",
                ("quarantine_at", 0.75),
            ),
            (
                ACSOperationKind::ToolAction,
                "ToolExec",
                ("quarantine_at", 0.65),
            ),
            (
                ACSOperationKind::ActiveAssemblyPacket,
                "Assembly",
                ("defer_at", 0.55),
            ),
            (
                ACSOperationKind::KernelPromotion,
                "KernelPromote",
                ("reject_at", 0.6),
            ),
            (
                ACSOperationKind::ModelAdaptation,
                "ModelAdapt",
                ("reject_at", 0.5),
            ),
        ];

        for (operation, capability_name, (threshold_field, expected_value)) in cases {
            assert!(policy
                .required_for(operation)
                .contains(&named_capability(capability_name)));
            let thresholds = policy.thresholds_for(operation);
            let actual_value = match threshold_field {
                "defer_at" => thresholds.defer_at,
                "quarantine_at" => thresholds.quarantine_at,
                "reject_at" => thresholds.reject_at,
                _ => unreachable!("test fixture only names supported fields"),
            };
            assert_eq!(actual_value, expected_value);
        }

        assert!(ACSAdmissionVerdict::Reject.is_terminal());
        assert!(ACSAdmissionVerdict::Quarantine.is_terminal());
        assert_eq!(ACSAdmissionVerdict::Defer.retry_limit(), Some(3));
    }

    #[test]
    fn acs_admission_lanes_map_operations_and_l2_requires_strict_capabilities() {
        let policy = ACSPolicy::strict_default(1_000);
        let lane_cases = [
            (ACSOperationKind::MutationEnvelope, ACSLane::L0),
            (ACSOperationKind::MemoryWrite, ACSLane::L0),
            (ACSOperationKind::AnswerPacket, ACSLane::L0),
            (ACSOperationKind::ToolAction, ACSLane::L1),
            (ACSOperationKind::ActiveAssemblyPacket, ACSLane::L1),
            (ACSOperationKind::KernelPromotion, ACSLane::L2),
            (ACSOperationKind::ModelAdaptation, ACSLane::L2),
        ];

        for (operation, expected_lane) in lane_cases {
            assert_eq!(operation.lane(), expected_lane);
        }

        let lower_lane_operations = [
            ACSOperationKind::MutationEnvelope,
            ACSOperationKind::MemoryWrite,
            ACSOperationKind::AnswerPacket,
            ACSOperationKind::ToolAction,
            ACSOperationKind::ActiveAssemblyPacket,
        ];
        let l2_cases = [
            (
                ACSOperationKind::KernelPromotion,
                named_capability("KernelPromote"),
            ),
            (
                ACSOperationKind::ModelAdaptation,
                named_capability("ModelAdapt"),
            ),
        ];

        for (operation, l2_capability) in l2_cases {
            assert_eq!(operation.lane(), ACSLane::L2);
            assert!(policy.required_for(operation).contains(&l2_capability));

            for lower_lane_operation in lower_lane_operations {
                assert_ne!(lower_lane_operation.lane(), ACSLane::L2);
                assert!(!policy
                    .required_for(lower_lane_operation)
                    .contains(&l2_capability));
                assert!(
                    policy.thresholds_for(operation).reject_at
                        < policy.thresholds_for(lower_lane_operation).reject_at
                );
            }
        }
    }

    #[test]
    fn acs_admission_defer_retry_budget_is_only_retryable_path() {
        for verdict in [
            ACSAdmissionVerdict::Allow,
            ACSAdmissionVerdict::AllowWithWarning,
            ACSAdmissionVerdict::Quarantine,
            ACSAdmissionVerdict::Reject,
        ] {
            assert_eq!(verdict.retry_limit(), None);
            assert!(!verdict.allows_retry(0));
            assert!(!verdict.allows_retry(3));
        }

        assert_eq!(ACSAdmissionVerdict::Defer.retry_limit(), Some(3));
        assert!(ACSAdmissionVerdict::Defer.allows_retry(0));
        assert!(ACSAdmissionVerdict::Defer.allows_retry(1));
        assert!(ACSAdmissionVerdict::Defer.allows_retry(2));
        assert!(!ACSAdmissionVerdict::Defer.allows_retry(3));
    }

    #[test]
    fn acs_admission_malformed_policy_is_denied() {
        let mut policy = ACSPolicy::strict("policy-malformed", 1_000);
        policy.thresholds.quarantine_at = 0.4;
        policy.thresholds.reject_at = 0.3;

        let err = policy.validate_at(1_001).unwrap_err();
        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("risk_threshold_order"));
    }

    #[test]
    fn acs_admission_blank_required_capability_makes_policy_malformed() {
        let policy = ACSPolicy::strict("policy-blank-capability", 1_000).require_capability(
            ACSOperationKind::ToolAction,
            Capability::Other {
                name: " ".to_string(),
            },
        );

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("required_capabilities.other.name"));
    }

    #[test]
    fn acs_admission_duplicate_operation_threshold_is_malformed_policy() {
        let mut policy = ACSPolicy::strict("policy-duplicate-threshold", 1_000);
        policy.operation_thresholds = vec![
            ACSOperationThresholdRule::new(
                ACSOperationKind::ToolAction,
                ACSRiskThresholds::standard(),
            ),
            ACSOperationThresholdRule::new(
                ACSOperationKind::ToolAction,
                ACSRiskThresholds::standard(),
            ),
        ];

        let err = policy.validate_at(1_001).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(
            err.field(),
            Some("operation_thresholds.duplicate_operation")
        );
    }

    #[test]
    fn acs_admission_malformed_policy_window_is_denied() {
        let mut policy = ACSPolicy::strict("policy-window", 1_000);
        policy.expires_at_ms = Some(1_000);

        let err = policy.validate_at(1_000).unwrap_err();

        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("expires_at_ms"));
    }

    #[test]
    fn acs_admission_high_risk_rejects() {
        let mut risk = ACSRiskVector::neutral();
        risk.safety_risk = 0.95;

        let verdict = ACSAdmissionVerdict::from_risk(&risk, ACSRiskThresholds::standard());

        assert_eq!(verdict, ACSAdmissionVerdict::Reject);
    }

    #[test]
    fn acs_admission_threshold_boundaries_are_inclusive() {
        let thresholds = ACSRiskThresholds::standard();
        let cases = [
            (thresholds.warn_at, ACSAdmissionVerdict::AllowWithWarning),
            (thresholds.defer_at, ACSAdmissionVerdict::Defer),
            (thresholds.quarantine_at, ACSAdmissionVerdict::Quarantine),
            (thresholds.reject_at, ACSAdmissionVerdict::Reject),
        ];

        for (axis_value, expected) in cases {
            let mut risk = ACSRiskVector::neutral();
            risk.safety_risk = axis_value;

            assert_eq!(ACSAdmissionVerdict::from_risk(&risk, thresholds), expected);
        }
    }

    #[test]
    fn acs_admission_verdict_wire_format_is_snake_case() {
        let cases = [
            (ACSAdmissionVerdict::Allow, "\"allow\""),
            (
                ACSAdmissionVerdict::AllowWithWarning,
                "\"allow_with_warning\"",
            ),
            (ACSAdmissionVerdict::Defer, "\"defer\""),
            (ACSAdmissionVerdict::Quarantine, "\"quarantine\""),
            (ACSAdmissionVerdict::Reject, "\"reject\""),
        ];

        for (verdict, expected_json) in cases {
            assert_eq!(serde_json::to_string(&verdict).unwrap(), expected_json);
        }
    }

    #[test]
    fn acs_admission_operation_kind_wire_format_is_snake_case() {
        let cases = [
            (ACSOperationKind::MutationEnvelope, "\"mutation_envelope\""),
            (
                ACSOperationKind::ActiveAssemblyPacket,
                "\"active_assembly_packet\"",
            ),
            (ACSOperationKind::AnswerPacket, "\"answer_packet\""),
            (ACSOperationKind::MemoryWrite, "\"memory_write\""),
            (ACSOperationKind::ToolAction, "\"tool_action\""),
            (ACSOperationKind::KernelPromotion, "\"kernel_promotion\""),
            (ACSOperationKind::ModelAdaptation, "\"model_adaptation\""),
        ];

        for (operation, expected_json) in cases {
            assert_eq!(serde_json::to_string(&operation).unwrap(), expected_json);
        }
    }

    #[test]
    fn acs_admission_forged_input_is_rejected() {
        let input = ACSAdmissionInput {
            request_id: "   ".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let err = input.validate().unwrap_err();

        assert_eq!(err.cause(), "forged_admission_input");
        assert_eq!(err.field(), "request_id");
    }

    #[test]
    fn acs_admission_forged_request_id_logs_valid_audit() {
        let input = ACSAdmissionInput {
            request_id: " ".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-forged-request", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(decision.audit_record.request_id, "malformed_request");
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_forged_risk_still_emits_valid_audit_record() {
        let mut risk = ACSRiskVector::neutral();
        risk.durability_risk = 1.01;
        let input = ACSAdmissionInput {
            request_id: "req-forged-risk".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-forged-risk", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(decision.audit_record.risk_max, 1.0);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_missing_capability_is_denied_and_logged() {
        let required = Capability::Other {
            name: "vault.write".to_string(),
        };
        let policy = ACSPolicy::strict("policy-capability", 1_000)
            .require_capability(ACSOperationKind::ToolAction, required);
        let input = ACSAdmissionInput {
            request_id: "req-tool-1".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "missing_capability");
        assert_eq!(audit_log.len(), 1);
        assert_eq!(audit_log[0].verdict, ACSAdmissionVerdict::Reject);
    }

    #[test]
    fn acs_admission_requires_every_policy_capability() {
        let write = Capability::Other {
            name: "vault.write".to_string(),
        };
        let sign = Capability::Other {
            name: "witness.sign".to_string(),
        };
        let policy = ACSPolicy::strict("policy-two-capabilities", 1_000)
            .require_capability(ACSOperationKind::ToolAction, write.clone())
            .require_capability(ACSOperationKind::ToolAction, sign);
        let input = ACSAdmissionInput {
            request_id: "req-two-capabilities".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![write],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "missing_capability");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_matching_capability_allows_and_logs() {
        let required = Capability::Other {
            name: "vault.write".to_string(),
        };
        let policy = ACSPolicy::strict("policy-capability-allow", 1_000)
            .require_capability(ACSOperationKind::ToolAction, required.clone());
        let input = ACSAdmissionInput {
            request_id: "req-tool-allow".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![required],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(audit_log.len(), 1);
        assert_eq!(audit_log[0].reason, "allow");
    }

    #[test]
    fn acs_admission_all_policy_capabilities_present_allows() {
        let write = Capability::Other {
            name: "vault.write".to_string(),
        };
        let sign = Capability::Other {
            name: "witness.sign".to_string(),
        };
        let policy = ACSPolicy::strict("policy-all-capabilities", 1_000)
            .require_capability(ACSOperationKind::ToolAction, write.clone())
            .require_capability(ACSOperationKind::ToolAction, sign.clone());
        let input = ACSAdmissionInput {
            request_id: "req-all-capabilities".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: vec![sign, write],
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(audit_log[0].reason, "allow");
    }

    #[test]
    fn acs_admission_capability_rules_are_operation_scoped() {
        let promotion_capability = Capability::Other {
            name: "kernel.promote".to_string(),
        };
        let policy = ACSPolicy::strict("policy-operation-scope", 1_000)
            .require_capability(ACSOperationKind::KernelPromotion, promotion_capability);
        let input = ACSAdmissionInput {
            request_id: "req-tool-operation-scope".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(audit_log[0].operation, ACSOperationKind::ToolAction);
    }

    #[test]
    fn acs_admission_input_accepts_all_canonical_payloads() {
        let payloads = vec![
            ACSAdmissionPayload::MutationEnvelope {
                envelope: Box::new(mutation_envelope_fixture()),
            },
            ACSAdmissionPayload::ActiveAssemblyPacket {
                packet: ActiveAssemblyPacket {
                    assembly_id: "assembly-1".to_string(),
                    active_support_ids: vec!["note-1".to_string()],
                    witness_hash: "witness-hash".to_string(),
                },
            },
            ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(AnswerPacket::new(
                    AnswerPacketId::new("answer-1"),
                    WitnessedStateId::new("state-1"),
                    MutationEnvelopeId::new("mutation-1"),
                )),
            },
            ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/1".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            tool_action_payload(),
            ACSAdmissionPayload::KernelPromotion {
                request: ACSKernelPromotionRequest {
                    kernel_id: "kernel-1".to_string(),
                    signed_plan_hash: "plan-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            ACSAdmissionPayload::ModelAdaptation {
                request: ACSModelAdaptationRequest {
                    adapter_id: "adapter-1".to_string(),
                    model_id: "local-helper-1".to_string(),
                    checkpoint_hash: "checkpoint-hash".to_string(),
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
        ];
        let expected = [
            ACSOperationKind::MutationEnvelope,
            ACSOperationKind::ActiveAssemblyPacket,
            ACSOperationKind::AnswerPacket,
            ACSOperationKind::MemoryWrite,
            ACSOperationKind::ToolAction,
            ACSOperationKind::KernelPromotion,
            ACSOperationKind::ModelAdaptation,
        ];

        for (idx, payload) in payloads.into_iter().enumerate() {
            let input = ACSAdmissionInput {
                request_id: format!("req-{idx}"),
                payload,
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            assert!(input.validate().is_ok());
            assert_eq!(input.operation(), expected[idx]);
        }
    }

    #[test]
    fn acs_admission_input_round_trips_with_payload_operation() {
        let input = ACSAdmissionInput {
            request_id: "req-round-trip".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/round-trip".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: true,
                    mutation_envelope_id: Some("mutation-1".to_string()),
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let json = serde_json::to_string(&input).expect("input must serialize");
        let decoded: ACSAdmissionInput =
            serde_json::from_str(&json).expect("input must deserialize");

        assert_eq!(decoded.operation(), ACSOperationKind::MemoryWrite);
        assert_eq!(decoded, input);
    }

    #[test]
    fn acs_admission_property_no_durable_write_bypasses_acs() {
        for mutation_envelope_id in [None, Some(String::new()), Some("  ".to_string())] {
            let input = ACSAdmissionInput {
                request_id: "req-durable-write".to_string(),
                payload: ACSAdmissionPayload::MemoryWrite {
                    request: ACSMemoryWriteRequest {
                        address: "uas://note/1".to_string(),
                        content_hash: "content-hash".to_string(),
                        durable: true,
                        mutation_envelope_id,
                    },
                },
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-durable-write", 1_000);
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(decision.audit_record.reason, "durable_write_bypass_attempt");
            assert_eq!(audit_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_kernel_promotion_bypass_attempt_is_rejected() {
        for mutation_envelope_id in [None, Some(String::new()), Some("  ".to_string())] {
            let input = ACSAdmissionInput {
                request_id: "req-kernel-promotion".to_string(),
                payload: ACSAdmissionPayload::KernelPromotion {
                    request: ACSKernelPromotionRequest {
                        kernel_id: "kernel-1".to_string(),
                        signed_plan_hash: "plan-hash".to_string(),
                        mutation_envelope_id,
                    },
                },
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-kernel-promotion", 1_000);
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(
                decision.audit_record.reason,
                "kernel_promotion_bypass_attempt"
            );
            assert_eq!(audit_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_doc_pins_scope_rex_placement_and_layers() {
        let doc = include_str!("../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

        for needle in [
            "ACS (Anchored Cognitive Substrate",
            "Autopoietic Cognitive Stack",
            "above SCOPE-Rex",
            "MutationEnvelope",
            "pure-data verdict",
            "No ACS admission path calls cloud services",
            "runs model inference",
            "applies durable state directly",
            "guard_durable_commit",
            "ACS-L0",
            "ACS-L1",
            "ACS-L2",
            "MASTER_FUSION §3.8",
        ] {
            assert!(doc.contains(needle), "missing doc anchor: {needle}");
        }
    }

    #[test]
    fn acs_admission_doc_pins_all_verdicts_logged() {
        let doc = include_str!("../../../docs/ACS_ADMISSION_FIELD_2026_05_18.md");

        for needle in [
            "allow",
            "allow-with-warning",
            "defer",
            "quarantine",
            "reject",
            "ACSAuditRecord",
            "Every ACSAdmissionVerdict emits",
        ] {
            assert!(doc.contains(needle), "missing doc verdict anchor: {needle}");
        }
    }

    #[test]
    fn acs_admission_all_verdict_paths_are_logged() {
        let cases = [
            (0.1, ACSAdmissionVerdict::Allow),
            (0.4, ACSAdmissionVerdict::AllowWithWarning),
            (0.6, ACSAdmissionVerdict::Defer),
            (0.8, ACSAdmissionVerdict::Quarantine),
            (0.95, ACSAdmissionVerdict::Reject),
        ];
        let policy = ACSPolicy::strict("policy-verdicts", 1_000);

        for (idx, (risk_value, expected)) in cases.into_iter().enumerate() {
            let mut risk = ACSRiskVector::neutral();
            risk.truth_risk = risk_value;
            let input = ACSAdmissionInput {
                request_id: format!("req-verdict-{idx}"),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk,
                granted_capabilities: Vec::new(),
            };
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, expected);
            assert_eq!(audit_log.len(), 1);
            assert_eq!(audit_log[0].verdict, expected);
            assert_eq!(audit_log[0].reason, expected.code());
        }
    }

    #[test]
    fn acs_admission_emitted_audit_records_validate() {
        let policy = ACSPolicy::strict("policy-audit-validity", 1_000);

        for risk_value in [0.0, 0.4, 0.6, 0.8, 0.95] {
            let mut risk = ACSRiskVector::neutral();
            risk.safety_risk = risk_value;
            let input = ACSAdmissionInput {
                request_id: format!("req-audit-validity-{risk_value}"),
                payload: tool_action_payload(),
                submitted_at_ms: 1_001,
                risk,
                granted_capabilities: Vec::new(),
            };
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert!(decision.audit_record.validate().is_ok());
            assert!(audit_log[0].validate().is_ok());
        }
    }

    #[test]
    fn acs_admission_audit_record_preserves_max_risk_axis() {
        let mut risk = ACSRiskVector::neutral();
        risk.truth_risk = 0.2;
        risk.privacy_risk = 0.64;
        risk.durability_risk = 0.41;
        let input = ACSAdmissionInput {
            request_id: "req-risk-max".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-risk-max", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.audit_record.risk_max, 0.64);
        assert_eq!(audit_log[0].risk_max, 0.64);
    }

    #[test]
    fn acs_admission_audit_record_preserves_policy_version() {
        let mut policy = ACSPolicy::strict("policy-versioned", 1_000);
        policy.version = 7;
        let input = ACSAdmissionInput {
            request_id: "req-policy-version".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.audit_record.policy_version, 7);
        assert_eq!(audit_log[0].policy_version, 7);
    }

    #[test]
    fn acs_admission_audit_record_preserves_request_and_policy_ids() {
        let policy = ACSPolicy::strict("policy-identity", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-identity".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.audit_record.request_id, "req-identity");
        assert_eq!(decision.audit_record.policy_id, "policy-identity");
        assert_eq!(audit_log[0].request_id, "req-identity");
        assert_eq!(audit_log[0].policy_id, "policy-identity");
    }

    #[test]
    fn acs_admission_audit_record_round_trips() {
        let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);

        let json = serde_json::to_string(&record).expect("audit record must serialize");
        let decoded: ACSAuditRecord =
            serde_json::from_str(&json).expect("audit record must deserialize");

        assert_eq!(decoded, record);
        assert_eq!(decoded.operation, ACSOperationKind::MemoryWrite);
        assert_eq!(decoded.verdict, ACSAdmissionVerdict::AllowWithWarning);
        assert!(decoded.validate().is_ok());
    }

    #[test]
    fn acs_admission_scope_rex_proof_carries_verdict_record_ref_and_signature() {
        let record = audit_record_fixture(ACSAdmissionVerdict::AllowWithWarning);

        let proof = SCOPERexAdmissionProof::from_record(
            &record,
            CapabilitySignature::new("capability-signature"),
        )
        .expect("valid audit record and signature produce proof");

        assert_eq!(proof.verdict, ACSAdmissionVerdict::AllowWithWarning);
        assert_eq!(proof.record_id.0, record.record_id);
        assert_eq!(proof.signature.0, "capability-signature");

        let err = SCOPERexAdmissionProof::from_record(&record, CapabilitySignature::new(" "))
            .unwrap_err();
        assert_eq!(err.cause(), "missing_capability_signature");

        let err = SCOPERexAdmissionProof::new(
            ACSAdmissionVerdict::Allow,
            AuditRecordId::new("run-event:external-record"),
            CapabilitySignature::new("capability-signature"),
        )
        .unwrap_err();
        assert_eq!(err.cause(), "invalid_audit_record_id");
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_records_decisions() {
        let sink = InMemoryACSAuditSink::default();
        let input = ACSAdmissionInput {
            request_id: "req-sink".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-sink", 1_000);

        let decision =
            admit_and_record(&input, &policy, 1_001, &sink).expect("in-memory sink records");

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
        assert_eq!(sink.records().unwrap(), vec![decision.audit_record]);
    }

    #[test]
    fn acs_admission_in_memory_audit_sink_rejects_corrupt_records() {
        let sink = InMemoryACSAuditSink::default();
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = " ".to_string();

        let err = sink.record(record).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("record_id"));
        assert!(sink.records().unwrap().is_empty());
    }

    #[test]
    fn acs_admission_verdict_monotonicity_property() {
        let thresholds = ACSRiskThresholds::standard();

        for lower in 0..=100 {
            for higher in lower..=100 {
                let mut lower_risk = ACSRiskVector::neutral();
                let mut higher_risk = ACSRiskVector::neutral();
                lower_risk.truth_risk = lower as f32 / 100.0;
                higher_risk.truth_risk = higher as f32 / 100.0;

                let lower_verdict = ACSAdmissionVerdict::from_risk(&lower_risk, thresholds);
                let higher_verdict = ACSAdmissionVerdict::from_risk(&higher_risk, thresholds);

                assert!(
                    higher_verdict.severity_rank() >= lower_verdict.severity_rank(),
                    "{higher_verdict:?} must not be weaker than {lower_verdict:?}"
                );
            }
        }
    }

    #[test]
    fn acs_admission_concurrent_admissions_are_deterministic() {
        let policy = ACSPolicy::strict("policy-concurrent", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-concurrent".to_string(),
            payload: ACSAdmissionPayload::MemoryWrite {
                request: ACSMemoryWriteRequest {
                    address: "uas://note/concurrent".to_string(),
                    content_hash: "content-hash".to_string(),
                    durable: false,
                    mutation_envelope_id: None,
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let handles: Vec<_> = (0..16)
            .map(|_| {
                let policy = policy.clone();
                let input = input.clone();
                std::thread::spawn(move || {
                    let mut audit_log = Vec::new();
                    let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);
                    (decision, audit_log)
                })
            })
            .collect();

        for handle in handles {
            let (decision, audit_log) = handle.join().expect("admission thread must not panic");
            assert_eq!(decision.verdict, ACSAdmissionVerdict::Allow);
            assert_eq!(audit_log.len(), 1);
            assert_eq!(audit_log[0].record_id, "acs:req-concurrent:1001");
        }
    }

    #[test]
    fn acs_admission_missing_risk_axis_is_rejected_on_decode() {
        let malformed = serde_json::json!({
            "truth_risk": 0.0,
            "safety_risk": 0.0,
            "privacy_risk": 0.0,
            "capability_risk": 0.0,
            "durability_risk": 0.0,
            "scope_rex_risk": 0.0,
            "kernel_promotion_risk": 0.0,
            "evidence_present": true
        });

        let decoded = serde_json::from_value::<ACSRiskVector>(malformed);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_audit_corruption_rejects_unknown_verdict() {
        let record = ACSAuditRecord {
            record_id: "acs:req:1001".to_string(),
            request_id: "req".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::ToolAction,
            verdict: ACSAdmissionVerdict::Allow,
            reason: "allow".to_string(),
            risk_max: 0.0,
            emitted_at_ms: 1_001,
        };
        let mut value = serde_json::to_value(record).expect("audit record must serialize");
        value["verdict"] = serde_json::json!("silently_allow");

        let decoded = serde_json::from_value::<ACSAuditRecord>(value);

        assert!(decoded.is_err());
    }

    #[test]
    fn acs_admission_malformed_policy_rejects_and_logs() {
        let mut policy = ACSPolicy::strict("policy-nonfinite", 1_000);
        policy.thresholds.warn_at = f32::NAN;
        let input = ACSAdmissionInput {
            request_id: "req-malformed-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_empty_policy_id_rejects_and_logs_valid_audit() {
        let policy = ACSPolicy::strict(" ", 1_000);
        let input = ACSAdmissionInput {
            request_id: "req-empty-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "malformed_policy");
        assert!(decision.audit_record.validate().is_ok());
        assert_eq!(decision.audit_record.policy_id, "malformed_policy");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_future_policy_rejects_and_logs() {
        let policy = ACSPolicy::strict("policy-future", 2_000);
        let input = ACSAdmissionInput {
            request_id: "req-future-policy".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "policy_not_yet_valid");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_future_input_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-future-input".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 2_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-future-input", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "future_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_negative_submission_time_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-negative-input-time".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: -1,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-negative-input-time", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_negative_admission_clock_rejects_with_valid_audit() {
        let input = ACSAdmissionInput {
            request_id: "req-negative-clock".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 0,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-negative-clock", 0);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, -1, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "invalid_admission_time");
        assert_eq!(decision.audit_record.emitted_at_ms, 0);
        assert_eq!(audit_log.len(), 1);
        assert!(decision.audit_record.validate().is_ok());
    }

    #[test]
    fn acs_admission_missing_evidence_warns_and_logs() {
        let mut risk = ACSRiskVector::neutral();
        risk.evidence_present = false;
        let input = ACSAdmissionInput {
            request_id: "req-missing-evidence".to_string(),
            payload: tool_action_payload(),
            submitted_at_ms: 1_001,
            risk,
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-missing-evidence", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::AllowWithWarning);
        assert_eq!(decision.audit_record.reason, "allow_with_warning");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_malformed_active_assembly_rejects_and_logs() {
        let input = ACSAdmissionInput {
            request_id: "req-bad-assembly".to_string(),
            payload: ACSAdmissionPayload::ActiveAssemblyPacket {
                packet: ActiveAssemblyPacket {
                    assembly_id: "assembly-1".to_string(),
                    active_support_ids: Vec::new(),
                    witness_hash: "witness-hash".to_string(),
                },
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-bad-assembly", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_answer_packet_requires_mutation_reference() {
        let input = ACSAdmissionInput {
            request_id: "req-answer-packet".to_string(),
            payload: ACSAdmissionPayload::AnswerPacket {
                packet: Box::new(AnswerPacket::new(
                    AnswerPacketId::new("answer-1"),
                    WitnessedStateId::new("state-1"),
                    MutationEnvelopeId::new("  "),
                )),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-answer-packet", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_mutation_envelope_requires_mutation_id() {
        let mut envelope = mutation_envelope_fixture();
        envelope.mutation_id = " ".to_string();
        let input = ACSAdmissionInput {
            request_id: "req-mutation-envelope".to_string(),
            payload: ACSAdmissionPayload::MutationEnvelope {
                envelope: Box::new(envelope),
            },
            submitted_at_ms: 1_001,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };
        let policy = ACSPolicy::strict("policy-mutation-envelope", 1_000);
        let mut audit_log = Vec::new();

        let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

        assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
        assert_eq!(decision.audit_record.reason, "forged_admission_input");
        assert_eq!(audit_log.len(), 1);
    }

    #[test]
    fn acs_admission_model_adaptation_bypass_attempt_is_rejected() {
        for mutation_envelope_id in [None, Some(String::new()), Some("  ".to_string())] {
            let input = ACSAdmissionInput {
                request_id: "req-model-adaptation".to_string(),
                payload: ACSAdmissionPayload::ModelAdaptation {
                    request: ACSModelAdaptationRequest {
                        adapter_id: "adapter-1".to_string(),
                        model_id: "local-helper-1".to_string(),
                        checkpoint_hash: "checkpoint-hash".to_string(),
                        mutation_envelope_id,
                    },
                },
                submitted_at_ms: 1_001,
                risk: ACSRiskVector::neutral(),
                granted_capabilities: Vec::new(),
            };
            let policy = ACSPolicy::strict("policy-model-adaptation", 1_000);
            let mut audit_log = Vec::new();

            let decision = admit_and_log(&input, &policy, 1_001, &mut audit_log);

            assert_eq!(decision.verdict, ACSAdmissionVerdict::Reject);
            assert_eq!(
                decision.audit_record.reason,
                "model_adaptation_bypass_attempt"
            );
            assert_eq!(audit_log.len(), 1);
        }
    }

    #[test]
    fn acs_admission_durable_commit_guard_requires_allowing_audit_record() {
        assert_eq!(
            guard_durable_commit(None).unwrap_err().cause(),
            "missing_acs_audit_record"
        );

        for verdict in [
            ACSAdmissionVerdict::Allow,
            ACSAdmissionVerdict::AllowWithWarning,
        ] {
            let record = audit_record_fixture(verdict);
            assert!(guard_durable_commit(Some(&record)).is_ok());
        }

        for verdict in [
            ACSAdmissionVerdict::Defer,
            ACSAdmissionVerdict::Quarantine,
            ACSAdmissionVerdict::Reject,
        ] {
            let record = audit_record_fixture(verdict);
            let err = guard_durable_commit(Some(&record)).unwrap_err();
            assert_eq!(err.cause(), "acs_verdict_blocks_durable_commit");
            assert_eq!(err.verdict(), Some(verdict));
        }
    }

    #[test]
    fn acs_admission_durable_commit_guard_rejects_corrupt_audit_record() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.risk_max = f32::NAN;

        let err = guard_durable_commit(Some(&record)).unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), Some("risk_max"));
    }

    #[test]
    fn acs_admission_audit_record_rejects_blank_reason() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.reason = " ".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "reason");
    }

    #[test]
    fn acs_admission_audit_record_rejects_non_acs_record_id() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.record_id = "run-event:external-record".to_string();

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "record_id");
    }

    #[test]
    fn acs_admission_audit_record_rejects_negative_emitted_time() {
        let mut record = audit_record_fixture(ACSAdmissionVerdict::Allow);
        record.emitted_at_ms = -1;

        let err = record.validate().unwrap_err();

        assert_eq!(err.cause(), "corrupt_acs_audit_record");
        assert_eq!(err.field(), "emitted_at_ms");
    }

    fn tool_action_payload() -> ACSAdmissionPayload {
        ACSAdmissionPayload::ToolAction {
            request: ACSToolActionRequest {
                tool_name: "vault.write".to_string(),
                target: "uas://note/1".to_string(),
                mutation_envelope_id: Some("mutation-1".to_string()),
            },
        }
    }

    fn mutation_envelope_fixture() -> MutationEnvelope {
        MutationEnvelope::pending(
            "mutation-1".to_string(),
            1,
            MutationActor::User,
            SourceOp::ArtifactUpdate {
                artifact_id: "artifact-1".to_string(),
            },
            Sensitivity::Internal,
            Reversibility::Reversible,
            1_000,
        )
    }

    fn audit_record_fixture(verdict: ACSAdmissionVerdict) -> ACSAuditRecord {
        ACSAuditRecord {
            record_id: format!("acs:req:{}", verdict.code()),
            request_id: "req".to_string(),
            policy_id: "policy".to_string(),
            policy_version: 1,
            operation: ACSOperationKind::MemoryWrite,
            verdict,
            reason: verdict.code().to_string(),
            risk_max: 0.0,
            emitted_at_ms: 1_001,
        }
    }
}
