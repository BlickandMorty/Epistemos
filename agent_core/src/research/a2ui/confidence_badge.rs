//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `ConfidenceBadge`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::ConfidenceBadge`].
//!
//! # Wave I — ConfidenceBadge component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. 3-tier classifier (High ≥0.85, Medium ≥0.7,
//! Low otherwise). Substrate floor only; Swift A2UI dispatcher owns
//! the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ConfidenceBadgeProps {
    pub confidence: f32,
    pub label: String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ConfidenceBadgeError {
    OutOfRange { value: f32 },
    NonFinite { value: f32 },
}

impl ConfidenceBadgeError {
    pub const fn cause(&self) -> &'static str {
        match self {
            ConfidenceBadgeError::OutOfRange { .. } => "out_of_range",
            ConfidenceBadgeError::NonFinite { .. } => "non_finite",
        }
    }

    /// `value` carried by either variant.
    pub const fn value(&self) -> f32 {
        match self {
            ConfidenceBadgeError::OutOfRange { value }
            | ConfidenceBadgeError::NonFinite { value } => *value,
        }
    }
}

/// The High-tier threshold per §5 doctrine.
pub const CONFIDENCE_HIGH_THRESHOLD: f32 = 0.85;
/// The Medium-tier threshold per §5 doctrine.
pub const CONFIDENCE_MEDIUM_THRESHOLD: f32 = 0.7;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ConfidenceTier {
    High,
    Medium,
    Low,
}

impl ConfidenceTier {
    pub const ALL: [ConfidenceTier; 3] = [
        ConfidenceTier::High,
        ConfidenceTier::Medium,
        ConfidenceTier::Low,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            ConfidenceTier::High => "high",
            ConfidenceTier::Medium => "medium",
            ConfidenceTier::Low => "low",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|t| t.code() == code)
    }

    pub const fn is_high(self) -> bool {
        matches!(self, ConfidenceTier::High)
    }

    pub const fn is_medium(self) -> bool {
        matches!(self, ConfidenceTier::Medium)
    }

    /// Cross-surface invariant: exactly one of `is_high / is_medium /
    /// is_low` is true per ConfidenceTier (3-way partition).
    pub const fn is_low(self) -> bool {
        matches!(self, ConfidenceTier::Low)
    }
}

impl ConfidenceBadgeProps {
    pub fn validate(&self) -> Result<(), ConfidenceBadgeError> {
        if !self.confidence.is_finite() {
            return Err(ConfidenceBadgeError::NonFinite { value: self.confidence });
        }
        if !(0.0..=1.0).contains(&self.confidence) {
            return Err(ConfidenceBadgeError::OutOfRange { value: self.confidence });
        }
        Ok(())
    }

    pub fn tier(&self) -> ConfidenceTier {
        if self.confidence >= CONFIDENCE_HIGH_THRESHOLD {
            ConfidenceTier::High
        } else if self.confidence >= CONFIDENCE_MEDIUM_THRESHOLD {
            ConfidenceTier::Medium
        } else {
            ConfidenceTier::Low
        }
    }

    /// Predicate alias for `validate().is_ok()`.
    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn high_at_0_85() {
        let b = ConfidenceBadgeProps { confidence: 0.85, label: "x".into() };
        assert!(b.validate().is_ok());
        assert_eq!(b.tier(), ConfidenceTier::High);
    }

    #[test]
    fn medium_at_0_75() {
        let b = ConfidenceBadgeProps { confidence: 0.75, label: "x".into() };
        assert_eq!(b.tier(), ConfidenceTier::Medium);
    }

    #[test]
    fn low_below_0_7() {
        let b = ConfidenceBadgeProps { confidence: 0.5, label: "x".into() };
        assert_eq!(b.tier(), ConfidenceTier::Low);
    }

    #[test]
    fn out_of_range_rejected() {
        let b = ConfidenceBadgeProps { confidence: 1.5, label: "x".into() };
        assert!(matches!(b.validate().unwrap_err(), ConfidenceBadgeError::OutOfRange { .. }));
    }

    #[test]
    fn nan_rejected() {
        let b = ConfidenceBadgeProps { confidence: f32::NAN, label: "x".into() };
        assert!(matches!(b.validate().unwrap_err(), ConfidenceBadgeError::NonFinite { .. }));
    }

    #[test]
    fn serde_json_roundtrip() {
        let b = ConfidenceBadgeProps { confidence: 0.9, label: "x".into() };
        let json = serde_json::to_string(&b).unwrap();
        let back: ConfidenceBadgeProps = serde_json::from_str(&json).unwrap();
        assert_eq!(b, back);
    }

    // ── diagnostic surface (iter 199) ────────────────────────────────────────

    #[test]
    fn tier_thresholds_pinned() {
        assert!((CONFIDENCE_HIGH_THRESHOLD - 0.85).abs() < 1e-9);
        assert!((CONFIDENCE_MEDIUM_THRESHOLD - 0.7).abs() < 1e-9);
    }

    #[test]
    fn tier_from_code_roundtrips_all() {
        for t in ConfidenceTier::ALL.iter().copied() {
            assert_eq!(ConfidenceTier::from_code(t.code()), Some(t));
        }
        assert_eq!(ConfidenceTier::from_code("High"), None);
    }

    #[test]
    fn tier_3way_classifier_partition() {
        // Cross-surface invariant: is_high XOR is_medium XOR is_low.
        for t in ConfidenceTier::ALL.iter().copied() {
            let trio = [t.is_high(), t.is_medium(), t.is_low()];
            assert_eq!(trio.iter().filter(|x| **x).count(), 1, "{:?}", t);
        }
    }

    #[test]
    fn tier_aligned_with_thresholds() {
        // Cross-surface invariant: tier() output aligned with constants.
        let b = ConfidenceBadgeProps { confidence: CONFIDENCE_HIGH_THRESHOLD, label: "x".into() };
        assert!(b.tier().is_high());

        let b = ConfidenceBadgeProps { confidence: CONFIDENCE_MEDIUM_THRESHOLD, label: "x".into() };
        assert!(b.tier().is_medium());

        let b = ConfidenceBadgeProps { confidence: 0.0, label: "x".into() };
        assert!(b.tier().is_low());
    }

    #[test]
    fn error_cause_distinct() {
        let variants = [
            ConfidenceBadgeError::OutOfRange { value: 1.5 },
            ConfidenceBadgeError::NonFinite { value: f32::NAN },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 2);
    }

    #[test]
    fn error_value_accessor_total() {
        // Cross-surface: both variants carry a value.
        assert!((ConfidenceBadgeError::OutOfRange { value: 1.5 }.value() - 1.5).abs() < 1e-9);
        assert!(ConfidenceBadgeError::NonFinite { value: f32::NAN }.value().is_nan());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        // Cross-surface invariant.
        let good = ConfidenceBadgeProps { confidence: 0.9, label: "x".into() };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        let bad = ConfidenceBadgeProps { confidence: 1.5, label: "x".into() };
        assert_eq!(bad.is_valid(), bad.validate().is_ok());
    }
}
