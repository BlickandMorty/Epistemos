//! HELIOS V5 — SCOPE-Rex Omega `OntologyValidator` trait.
//!
//! HELIOS-ONTOLOGY guard
//!
//! Per HELIOS v4 preservation `source_docs/scope_rex_omega.md` — the
//! ontology layer of SCOPE-Rex validates extracted claims against a
//! shared semantic ontology, returning a structured verification
//! report.
//!
//! Used by the constrained action-selection objective:
//!
//! ```text
//! a_t* = argmin λ_v V(a) + λ_p P(a) + λ_d D(a) + λ_c C(a)
//!              - λ_i I(a) - λ_f F(a)
//! ```
//!
//! where `V(a)` is the ontology violation cost (the OntologyValidator
//! supplies this signal).
//!
//! Lane 1 MAS-add. Default implementations are no-op stubs that
//! return clean reports — real ontology backends (e.g. SHACL,
//! OWL-RL, CMS-X v3 constitutive field) live behind feature flags
//! per a Lane 3 follow-up.

use serde::{Deserialize, Serialize};

use crate::provenance::ledger::{Claim, ClaimId};

/// Severity of a single ontology violation. Maps to the WARN /
/// QUARANTINE / DEGRADE / HALT taxonomy used by H1-H17 invariants.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OntologyViolationSeverity {
    Warn,
    Degrade,
    Quarantine,
    Halt,
}

/// One ontology violation finding. The `claim_id` points at the
/// specific claim that failed the check; `rule_id` identifies the
/// ontology rule violated.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OntologyViolation {
    pub claim_id: ClaimId,
    pub rule_id: String,
    pub severity: OntologyViolationSeverity,
    pub message: String,
}

/// Verification report returned by [`OntologyValidator::validate`].
/// `violations` is empty when the claim set is fully consistent
/// with the ontology.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VerificationReport {
    pub violations: Vec<OntologyViolation>,
}

impl VerificationReport {
    pub fn clean() -> Self {
        Self::default()
    }

    pub fn is_clean(&self) -> bool {
        self.violations.is_empty()
    }

    /// Highest-severity violation in the report, if any.
    pub fn worst_severity(&self) -> Option<OntologyViolationSeverity> {
        self.violations.iter().map(|v| v.severity).max_by_key(|s| {
            // Order: Warn < Degrade < Quarantine < Halt
            match s {
                OntologyViolationSeverity::Warn => 0u8,
                OntologyViolationSeverity::Degrade => 1,
                OntologyViolationSeverity::Quarantine => 2,
                OntologyViolationSeverity::Halt => 3,
            }
        })
    }
}

/// Ontology validator trait. Real backends (SHACL/OWL-RL/CMS-X v3)
/// implement this; the default no-op implementation accepts all
/// claims as clean.
pub trait OntologyValidator {
    fn validate(&self, claims: &[Claim]) -> VerificationReport;
}

/// No-op default validator. Always returns a clean report. Useful
/// as a placeholder until a real backend lands per Lane 3 follow-up.
#[derive(Debug, Clone, Copy, Default)]
pub struct NoOpOntologyValidator;

impl OntologyValidator for NoOpOntologyValidator {
    fn validate(&self, _claims: &[Claim]) -> VerificationReport {
        VerificationReport::clean()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clean_report_has_no_violations() {
        let r = VerificationReport::clean();
        assert!(r.is_clean());
        assert_eq!(r.worst_severity(), None);
    }

    #[test]
    fn worst_severity_picks_halt_over_warn() {
        let r = VerificationReport {
            violations: vec![
                OntologyViolation {
                    claim_id: ClaimId::new("c1"),
                    rule_id: "r1".into(),
                    severity: OntologyViolationSeverity::Warn,
                    message: "advisory".into(),
                },
                OntologyViolation {
                    claim_id: ClaimId::new("c2"),
                    rule_id: "r2".into(),
                    severity: OntologyViolationSeverity::Halt,
                    message: "halt-required".into(),
                },
            ],
        };
        assert_eq!(r.worst_severity(), Some(OntologyViolationSeverity::Halt));
    }

    #[test]
    fn no_op_validator_returns_clean() {
        let v = NoOpOntologyValidator;
        let report = v.validate(&[]);
        assert!(report.is_clean());
    }

    #[test]
    fn severity_serializes_in_snake_case() {
        for (s, expected) in [
            (OntologyViolationSeverity::Warn, "\"warn\""),
            (OntologyViolationSeverity::Degrade, "\"degrade\""),
            (OntologyViolationSeverity::Quarantine, "\"quarantine\""),
            (OntologyViolationSeverity::Halt, "\"halt\""),
        ] {
            assert_eq!(serde_json::to_string(&s).unwrap(), expected);
        }
    }
}
