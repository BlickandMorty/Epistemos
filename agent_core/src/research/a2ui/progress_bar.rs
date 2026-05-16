//! Wave I ProgressBar component.

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
}
