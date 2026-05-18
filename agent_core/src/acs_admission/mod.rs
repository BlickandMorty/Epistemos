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

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ACSAdmissionDecision {
    pub verdict: ACSAdmissionVerdict,
    pub audit_record: ACSAuditRecord,
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

pub fn admit(input: &ACSAdmissionInput, policy: &ACSPolicy, now_ms: i64) -> ACSAdmissionDecision {
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

    let verdict = ACSAdmissionVerdict::from_risk(&input.risk, policy.thresholds);
    decision(input, policy, now_ms, verdict, verdict.code())
}

fn decision(
    input: &ACSAdmissionInput,
    policy: &ACSPolicy,
    now_ms: i64,
    verdict: ACSAdmissionVerdict,
    reason: &str,
) -> ACSAdmissionDecision {
    ACSAdmissionDecision {
        verdict,
        audit_record: ACSAuditRecord {
            record_id: format!("acs:{}:{}", input.request_id, now_ms),
            request_id: input.request_id.clone(),
            policy_id: policy.policy_id.clone(),
            policy_version: policy.version,
            operation: input.operation(),
            verdict,
            reason: reason.to_string(),
            risk_max: input.risk.max_axis(),
            emitted_at_ms: now_ms,
        },
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
        }
    }

    pub fn validate_at(&self, now_ms: i64) -> Result<(), ACSPolicyError> {
        if self.policy_id.trim().is_empty() {
            return Err(ACSPolicyError::Malformed { field: "policy_id" });
        }
        if self.version == 0 {
            return Err(ACSPolicyError::Malformed { field: "version" });
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
        self.thresholds.validate()
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
    fn acs_admission_malformed_policy_is_denied() {
        let mut policy = ACSPolicy::strict("policy-malformed", 1_000);
        policy.thresholds.quarantine_at = 0.4;
        policy.thresholds.reject_at = 0.3;

        let err = policy.validate_at(1_001).unwrap_err();
        assert_eq!(err.cause(), "malformed_policy");
        assert_eq!(err.field(), Some("risk_threshold_order"));
    }

    #[test]
    fn acs_admission_high_risk_rejects() {
        let mut risk = ACSRiskVector::neutral();
        risk.safety_risk = 0.95;

        let verdict = ACSAdmissionVerdict::from_risk(&risk, ACSRiskThresholds::standard());

        assert_eq!(verdict, ACSAdmissionVerdict::Reject);
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
            "ACS-L0",
            "ACS-L1",
            "ACS-L2",
            "MASTER_FUSION §3.8",
        ] {
            assert!(doc.contains(needle), "missing doc anchor: {needle}");
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
}
