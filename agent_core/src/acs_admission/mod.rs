//! ACS admission field.
//!
//! ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
//! admission is a policy boundary above SCOPE-Rex. It is intentionally
//! pure-data: it does not call cloud providers, run inference, or apply
//! durable state changes directly.

use serde::{Deserialize, Serialize};

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
}
