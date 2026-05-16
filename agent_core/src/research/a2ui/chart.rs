//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Chart`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Chart`].
//!
//! # Wave I — Chart component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ChartKind {
    Line,
    Bar,
    Scatter,
    Area,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ChartProps {
    pub kind: ChartKind,
    pub x_values: Vec<f32>,
    pub y_values: Vec<f32>,
    pub x_label: String,
    pub y_label: String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ChartError {
    LengthMismatch { x: usize, y: usize },
    EmptyData,
    NonFiniteValue { index: usize, axis: &'static str },
}

impl ChartProps {
    pub fn validate(&self) -> Result<(), ChartError> {
        if self.x_values.is_empty() || self.y_values.is_empty() {
            return Err(ChartError::EmptyData);
        }
        if self.x_values.len() != self.y_values.len() {
            return Err(ChartError::LengthMismatch {
                x: self.x_values.len(),
                y: self.y_values.len(),
            });
        }
        for (i, &v) in self.x_values.iter().enumerate() {
            if !v.is_finite() {
                return Err(ChartError::NonFiniteValue { index: i, axis: "x" });
            }
        }
        for (i, &v) in self.y_values.iter().enumerate() {
            if !v.is_finite() {
                return Err(ChartError::NonFiniteValue { index: i, axis: "y" });
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_kinds() {
        let s: std::collections::HashSet<_> =
            [ChartKind::Line, ChartKind::Bar, ChartKind::Scatter, ChartKind::Area]
                .iter()
                .copied()
                .collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn matching_lengths_validates() {
        let c = ChartProps {
            kind: ChartKind::Line,
            x_values: vec![1.0, 2.0],
            y_values: vec![3.0, 4.0],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        assert!(c.validate().is_ok());
    }

    #[test]
    fn empty_data_rejected() {
        let c = ChartProps {
            kind: ChartKind::Bar,
            x_values: vec![],
            y_values: vec![],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        assert_eq!(c.validate().unwrap_err(), ChartError::EmptyData);
    }

    #[test]
    fn length_mismatch_errors() {
        let c = ChartProps {
            kind: ChartKind::Line,
            x_values: vec![1.0],
            y_values: vec![3.0, 4.0],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        assert_eq!(c.validate().unwrap_err(), ChartError::LengthMismatch { x: 1, y: 2 });
    }

    #[test]
    fn non_finite_x_rejected() {
        let c = ChartProps {
            kind: ChartKind::Line,
            x_values: vec![f32::NAN],
            y_values: vec![0.0],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        assert!(matches!(c.validate().unwrap_err(), ChartError::NonFiniteValue { axis: "x", .. }));
    }

    #[test]
    fn serde_json_roundtrip() {
        let c = ChartProps {
            kind: ChartKind::Area,
            x_values: vec![1.0],
            y_values: vec![2.0],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        let json = serde_json::to_string(&c).unwrap();
        let back: ChartProps = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }
}
