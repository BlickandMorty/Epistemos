//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `ProvenanceTrace`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::ProvenanceTrace`].
//!
//! # Wave I — ProvenanceTrace component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

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

impl ProvenanceTraceError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            ProvenanceTraceError::EmptySteps => "empty_steps",
            ProvenanceTraceError::EmptyClaimId { .. } => "empty_claim_id",
            ProvenanceTraceError::EmptyEvidenceUri { .. } => "empty_evidence_uri",
            ProvenanceTraceError::ConfidenceOutOfRange { .. } => "confidence_out_of_range",
        }
    }

    /// Predicate: error pertains to the step collection
    /// (EmptySteps / EmptyClaimId / EmptyEvidenceUri).
    pub const fn is_step_error(&self) -> bool {
        matches!(
            self,
            ProvenanceTraceError::EmptySteps
                | ProvenanceTraceError::EmptyClaimId { .. }
                | ProvenanceTraceError::EmptyEvidenceUri { .. }
        )
    }

    /// Predicate: error pertains to a confidence-channel violation.
    /// Cross-surface invariant: `is_step_error XOR is_confidence_error`
    /// partitions all variants.
    pub const fn is_confidence_error(&self) -> bool {
        matches!(self, ProvenanceTraceError::ConfidenceOutOfRange { .. })
    }
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

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of trace steps.
    pub fn step_count(&self) -> usize {
        self.steps.len()
    }

    /// Mean confidence across all steps. Returns `None` for empty trace
    /// (mean undefined).
    pub fn mean_confidence(&self) -> Option<f32> {
        if self.steps.is_empty() {
            return None;
        }
        let sum: f32 = self.steps.iter().map(|s| s.confidence).sum();
        Some(sum / self.steps.len() as f32)
    }

    /// Minimum confidence across all steps (the weakest link).
    /// Returns `None` for empty trace.
    pub fn min_confidence(&self) -> Option<f32> {
        self.steps
            .iter()
            .map(|s| s.confidence)
            .fold(None, |acc, c| match acc {
                None => Some(c),
                Some(a) => Some(if c < a { c } else { a }),
            })
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

    // ── diagnostic surface (iter 205) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            ProvenanceTraceError::EmptySteps,
            ProvenanceTraceError::EmptyClaimId { index: 0 },
            ProvenanceTraceError::EmptyEvidenceUri { index: 0 },
            ProvenanceTraceError::ConfidenceOutOfRange { index: 0, value: 1.5 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn error_classifiers_partition() {
        let variants = [
            ProvenanceTraceError::EmptySteps,
            ProvenanceTraceError::EmptyClaimId { index: 0 },
            ProvenanceTraceError::EmptyEvidenceUri { index: 0 },
            ProvenanceTraceError::ConfidenceOutOfRange { index: 0, value: 1.5 },
        ];
        // Cross-surface invariant: is_step_error XOR is_confidence_error.
        for e in variants {
            assert_ne!(e.is_step_error(), e.is_confidence_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_step_error()).count(), 3);
        assert_eq!(variants.iter().filter(|e| e.is_confidence_error()).count(), 1);
    }

    #[test]
    fn step_count_matches_steps_len() {
        let p = ProvenanceTraceProps {
            steps: vec![step("a", "u1", 0.9), step("b", "u2", 0.7)],
        };
        assert_eq!(p.step_count(), 2);
    }

    #[test]
    fn mean_confidence_none_on_empty() {
        let p = ProvenanceTraceProps { steps: vec![] };
        assert_eq!(p.mean_confidence(), None);
    }

    #[test]
    fn mean_confidence_arithmetic() {
        let p = ProvenanceTraceProps {
            steps: vec![step("a", "u", 0.9), step("b", "u", 0.7), step("c", "u", 0.5)],
        };
        assert!((p.mean_confidence().unwrap() - 0.7).abs() < 1e-6);
    }

    #[test]
    fn min_confidence_picks_smallest() {
        let p = ProvenanceTraceProps {
            steps: vec![step("a", "u", 0.9), step("b", "u", 0.3), step("c", "u", 0.7)],
        };
        assert!((p.min_confidence().unwrap() - 0.3).abs() < 1e-6);
    }

    #[test]
    fn min_leq_mean_invariant() {
        // Cross-surface invariant: min ≤ mean for non-empty trace.
        let p = ProvenanceTraceProps {
            steps: vec![step("a", "u", 0.9), step("b", "u", 0.4)],
        };
        assert!(p.min_confidence().unwrap() <= p.mean_confidence().unwrap());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = ProvenanceTraceProps { steps: vec![step("c", "x", 0.8)] };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
