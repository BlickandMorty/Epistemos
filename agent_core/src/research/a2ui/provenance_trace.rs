//! Wave I ProvenanceTrace component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProvenanceTraceStep {
    pub claim_id: String,
    pub evidence_uri: String,
    pub confidence: f32,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProvenanceTraceProps {
    pub steps: Vec<ProvenanceTraceStep>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ProvenanceTraceError {
    EmptySteps,
    EmptyClaimId { index: usize },
    EmptyEvidenceUri { index: usize },
    ConfidenceOutOfRange { index: usize, value: f32 },
}

impl ProvenanceTraceProps {
    pub fn validate(&self) -> Result<(), ProvenanceTraceError> {
        if self.steps.is_empty() {
            return Err(ProvenanceTraceError::EmptySteps);
        }
        for (i, s) in self.steps.iter().enumerate() {
            if s.claim_id.is_empty() {
                return Err(ProvenanceTraceError::EmptyClaimId { index: i });
            }
            if s.evidence_uri.is_empty() {
                return Err(ProvenanceTraceError::EmptyEvidenceUri { index: i });
            }
            if !(0.0..=1.0).contains(&s.confidence) || !s.confidence.is_finite() {
                return Err(ProvenanceTraceError::ConfidenceOutOfRange {
                    index: i,
                    value: s.confidence,
                });
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn step(c: &str, e: &str, conf: f32) -> ProvenanceTraceStep {
        ProvenanceTraceStep {
            claim_id: c.into(),
            evidence_uri: e.into(),
            confidence: conf,
        }
    }

    #[test]
    fn empty_steps_rejected() {
        let p = ProvenanceTraceProps { steps: vec![] };
        assert_eq!(p.validate().unwrap_err(), ProvenanceTraceError::EmptySteps);
    }

    #[test]
    fn valid_steps_pass() {
        let p = ProvenanceTraceProps {
            steps: vec![step("c1", "vault://x", 0.9)],
        };
        assert!(p.validate().is_ok());
    }

    #[test]
    fn empty_claim_id_rejected() {
        let p = ProvenanceTraceProps {
            steps: vec![step("", "x", 0.9)],
        };
        assert!(matches!(p.validate().unwrap_err(), ProvenanceTraceError::EmptyClaimId { .. }));
    }

    #[test]
    fn empty_evidence_uri_rejected() {
        let p = ProvenanceTraceProps {
            steps: vec![step("c", "", 0.9)],
        };
        assert!(matches!(p.validate().unwrap_err(), ProvenanceTraceError::EmptyEvidenceUri { .. }));
    }

    #[test]
    fn confidence_out_of_range_rejected() {
        let p = ProvenanceTraceProps {
            steps: vec![step("c", "x", 1.5)],
        };
        assert!(matches!(p.validate().unwrap_err(), ProvenanceTraceError::ConfidenceOutOfRange { .. }));
    }

    #[test]
    fn serde_json_roundtrip() {
        let p = ProvenanceTraceProps {
            steps: vec![step("c", "x", 0.5)],
        };
        let json = serde_json::to_string(&p).unwrap();
        let back: ProvenanceTraceProps = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }
}
