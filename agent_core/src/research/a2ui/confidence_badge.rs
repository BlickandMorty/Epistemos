//! Wave I ConfidenceBadge component.

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

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ConfidenceTier {
    High,
    Medium,
    Low,
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
        if self.confidence >= 0.85 {
            ConfidenceTier::High
        } else if self.confidence >= 0.7 {
            ConfidenceTier::Medium
        } else {
            ConfidenceTier::Low
        }
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
}
