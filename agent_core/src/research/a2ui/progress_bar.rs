//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `ProgressBar`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::ProgressBar`].
//!
//! # Wave I — ProgressBar component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProgressBarProps {
    pub value: f32,
    pub max: f32,
    pub label: String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ProgressBarError {
    NonPositiveMax { max: f32 },
    ValueOutOfRange { value: f32, max: f32 },
    NonFiniteValue { value: f32 },
}

impl ProgressBarError {
    pub const fn cause(&self) -> &'static str {
        match self {
            ProgressBarError::NonPositiveMax { .. } => "non_positive_max",
            ProgressBarError::ValueOutOfRange { .. } => "value_out_of_range",
            ProgressBarError::NonFiniteValue { .. } => "non_finite_value",
        }
    }

    /// Predicate: error pertains to the `max` configuration
    /// (NonPositiveMax). Cross-surface invariant: `is_max_error XOR
    /// is_value_error` partitions all variants.
    pub const fn is_max_error(&self) -> bool {
        matches!(self, ProgressBarError::NonPositiveMax { .. })
    }

    /// Predicate: error pertains to the `value` field
    /// (ValueOutOfRange / NonFiniteValue).
    pub const fn is_value_error(&self) -> bool {
        matches!(
            self,
            ProgressBarError::ValueOutOfRange { .. } | ProgressBarError::NonFiniteValue { .. }
        )
    }
}

impl ProgressBarProps {
    pub fn validate(&self) -> Result<(), ProgressBarError> {
        if !self.max.is_finite() || self.max <= 0.0 {
            return Err(ProgressBarError::NonPositiveMax { max: self.max });
        }
        if !self.value.is_finite() {
            return Err(ProgressBarError::NonFiniteValue { value: self.value });
        }
        if self.value < 0.0 || self.value > self.max {
            return Err(ProgressBarError::ValueOutOfRange { value: self.value, max: self.max });
        }
        Ok(())
    }

    pub fn fraction(&self) -> f32 {
        if self.max == 0.0 { 0.0 } else { self.value / self.max }
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Predicate: progress is at 0%. Cross-surface invariant:
    /// `is_at_start iff fraction() == 0.0` for valid props.
    pub fn is_at_start(&self) -> bool {
        self.value == 0.0
    }

    /// Predicate: progress is at 100%. Cross-surface invariant:
    /// `is_complete iff fraction() == 1.0` for valid props.
    pub fn is_complete(&self) -> bool {
        self.value >= self.max
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn in_range_validates() {
        let p = ProgressBarProps { value: 5.0, max: 10.0, label: "x".into() };
        assert!(p.validate().is_ok());
        assert!((p.fraction() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn zero_max_rejected() {
        let p = ProgressBarProps { value: 0.0, max: 0.0, label: "x".into() };
        assert!(matches!(p.validate().unwrap_err(), ProgressBarError::NonPositiveMax { .. }));
    }

    #[test]
    fn negative_max_rejected() {
        let p = ProgressBarProps { value: 0.0, max: -1.0, label: "x".into() };
        assert!(matches!(p.validate().unwrap_err(), ProgressBarError::NonPositiveMax { .. }));
    }

    #[test]
    fn value_over_max_rejected() {
        let p = ProgressBarProps { value: 11.0, max: 10.0, label: "x".into() };
        assert!(matches!(p.validate().unwrap_err(), ProgressBarError::ValueOutOfRange { .. }));
    }

    #[test]
    fn nan_value_rejected() {
        let p = ProgressBarProps { value: f32::NAN, max: 10.0, label: "x".into() };
        assert!(matches!(p.validate().unwrap_err(), ProgressBarError::NonFiniteValue { .. }));
    }

    #[test]
    fn at_max_validates() {
        let p = ProgressBarProps { value: 10.0, max: 10.0, label: "x".into() };
        assert!(p.validate().is_ok());
        assert!((p.fraction() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn serde_json_roundtrip() {
        let p = ProgressBarProps { value: 1.0, max: 2.0, label: "x".into() };
        let json = serde_json::to_string(&p).unwrap();
        let back: ProgressBarProps = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    // ── diagnostic surface (iter 208) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            ProgressBarError::NonPositiveMax { max: 0.0 },
            ProgressBarError::ValueOutOfRange { value: 11.0, max: 10.0 },
            ProgressBarError::NonFiniteValue { value: f32::NAN },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_max_error XOR is_value_error.
        for e in [
            ProgressBarError::NonPositiveMax { max: 0.0 },
            ProgressBarError::ValueOutOfRange { value: 11.0, max: 10.0 },
            ProgressBarError::NonFiniteValue { value: f32::NAN },
        ] {
            assert_ne!(e.is_max_error(), e.is_value_error());
        }
    }

    #[test]
    fn is_at_start_iff_fraction_zero() {
        let p = ProgressBarProps { value: 0.0, max: 10.0, label: "x".into() };
        assert!(p.is_at_start());
        assert!((p.fraction() - 0.0).abs() < 1e-9);
        let p = ProgressBarProps { value: 1.0, max: 10.0, label: "x".into() };
        assert!(!p.is_at_start());
    }

    #[test]
    fn is_complete_iff_value_at_or_above_max() {
        let p = ProgressBarProps { value: 10.0, max: 10.0, label: "x".into() };
        assert!(p.is_complete());
        let p = ProgressBarProps { value: 5.0, max: 10.0, label: "x".into() };
        assert!(!p.is_complete());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = ProgressBarProps { value: 5.0, max: 10.0, label: "x".into() };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
