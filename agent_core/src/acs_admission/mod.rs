//! ACS admission field.
//!
//! ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
//! admission is a policy boundary above SCOPE-Rex. It is intentionally
//! pure-data: it does not call cloud providers, run inference, or apply
//! durable state changes directly.

use serde::{Deserialize, Serialize};

use crate::effect::receipt::Capability;

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

/// Data-only ACS request envelope. It carries the caller's declared operation,
/// risk vector, and already-granted capabilities without applying any state.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ACSAdmissionInput {
    pub request_id: String,
    pub operation: ACSOperationKind,
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
            .map_err(|_| ACSAdmissionInputError::Forged { field: "risk" })
    }
}

/// Defensive request validation failures.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ACSAdmissionInputError {
    Forged { field: &'static str },
}

impl ACSAdmissionInputError {
    pub const fn cause(&self) -> &'static str {
        match self {
            Self::Forged { .. } => "forged_admission_input",
        }
    }

    pub const fn field(&self) -> &'static str {
        match self {
            Self::Forged { field } => field,
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
            operation: ACSOperationKind::ToolAction,
            submitted_at_ms: 1_000,
            risk: ACSRiskVector::neutral(),
            granted_capabilities: Vec::new(),
        };

        let err = input.validate().unwrap_err();

        assert_eq!(err.cause(), "forged_admission_input");
        assert_eq!(err.field(), "request_id");
    }
}
