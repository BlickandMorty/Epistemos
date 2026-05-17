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

impl ChartKind {
    pub const ALL: [ChartKind; 4] = [
        ChartKind::Line,
        ChartKind::Bar,
        ChartKind::Scatter,
        ChartKind::Area,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            ChartKind::Line => "line",
            ChartKind::Bar => "bar",
            ChartKind::Scatter => "scatter",
            ChartKind::Area => "area",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|k| k.code() == code)
    }

    /// Predicate: this chart kind shows continuous trends across the
    /// x-axis (Line or Area). Distinct from discrete-bar / scatter
    /// plot kinds, which the Swift dispatcher renders differently.
    pub const fn is_continuous(self) -> bool {
        matches!(self, ChartKind::Line | ChartKind::Area)
    }

    /// Predicate: this chart kind shows discrete points / bars
    /// (Bar or Scatter). Cross-surface invariant:
    /// `is_continuous XOR is_discrete` partitions all 4 kinds.
    pub const fn is_discrete(self) -> bool {
        matches!(self, ChartKind::Bar | ChartKind::Scatter)
    }
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

impl ChartError {
    pub const fn cause(&self) -> &'static str {
        match self {
            ChartError::LengthMismatch { .. } => "length_mismatch",
            ChartError::EmptyData => "empty_data",
            ChartError::NonFiniteValue { .. } => "non_finite_value",
        }
    }

    /// Axis label for NonFiniteValue, `None` for other variants.
    pub const fn axis(&self) -> Option<&'static str> {
        match self {
            ChartError::NonFiniteValue { axis, .. } => Some(*axis),
            _ => None,
        }
    }
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

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of (x, y) data points. Cross-surface invariant: in a
    /// valid Chart, `point_count == x_values.len() == y_values.len()`.
    pub fn point_count(&self) -> usize {
        self.x_values.len().min(self.y_values.len())
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

    // ── diagnostic surface (iter 207) ────────────────────────────────────────

    #[test]
    fn kind_from_code_roundtrips_all() {
        for k in ChartKind::ALL.iter().copied() {
            assert_eq!(ChartKind::from_code(k.code()), Some(k));
        }
        assert_eq!(ChartKind::from_code("Line"), None);
    }

    #[test]
    fn kind_continuous_xor_discrete_partition() {
        // Cross-surface invariant.
        for k in ChartKind::ALL.iter().copied() {
            assert_ne!(k.is_continuous(), k.is_discrete());
        }
        assert!(ChartKind::Line.is_continuous());
        assert!(ChartKind::Area.is_continuous());
        assert!(ChartKind::Bar.is_discrete());
        assert!(ChartKind::Scatter.is_discrete());
    }

    #[test]
    fn error_cause_distinct() {
        let variants = [
            ChartError::LengthMismatch { x: 1, y: 2 },
            ChartError::EmptyData,
            ChartError::NonFiniteValue { index: 0, axis: "x" },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_axis_extracts_for_non_finite() {
        assert_eq!(
            ChartError::NonFiniteValue { index: 0, axis: "y" }.axis(),
            Some("y"),
        );
        assert_eq!(ChartError::EmptyData.axis(), None);
        assert_eq!(
            ChartError::LengthMismatch { x: 1, y: 2 }.axis(),
            None,
        );
    }

    #[test]
    fn point_count_matches_min_axis_len() {
        let c = ChartProps {
            kind: ChartKind::Line,
            x_values: vec![1.0, 2.0, 3.0],
            y_values: vec![1.0, 2.0, 3.0],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        assert_eq!(c.point_count(), 3);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = ChartProps {
            kind: ChartKind::Line,
            x_values: vec![1.0],
            y_values: vec![2.0],
            x_label: "x".into(),
            y_label: "y".into(),
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
