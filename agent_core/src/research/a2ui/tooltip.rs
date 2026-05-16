//! Wave I Tooltip component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum TooltipPlacement {
    Top,
    Right,
    Bottom,
    Left,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TooltipProps {
    pub text: String,
    pub placement: TooltipPlacement,
    pub delay_ms: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TooltipError {
    EmptyText,
    DelayTooLong { ms: u32 },
}

impl TooltipProps {
    pub fn validate(&self) -> Result<(), TooltipError> {
        if self.text.trim().is_empty() {
            return Err(TooltipError::EmptyText);
        }
        if self.delay_ms > 5_000 {
            return Err(TooltipError::DelayTooLong { ms: self.delay_ms });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_placements() {
        let s: std::collections::HashSet<_> = [
            TooltipPlacement::Top,
            TooltipPlacement::Right,
            TooltipPlacement::Bottom,
            TooltipPlacement::Left,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn valid_passes() {
        let t = TooltipProps {
            text: "hint".into(),
            placement: TooltipPlacement::Top,
            delay_ms: 300,
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn empty_text_rejected() {
        let t = TooltipProps {
            text: "  ".into(),
            placement: TooltipPlacement::Top,
            delay_ms: 0,
        };
        assert_eq!(t.validate().unwrap_err(), TooltipError::EmptyText);
    }

    #[test]
    fn delay_too_long_rejected() {
        let t = TooltipProps {
            text: "x".into(),
            placement: TooltipPlacement::Top,
            delay_ms: 6_000,
        };
        assert!(matches!(t.validate().unwrap_err(), TooltipError::DelayTooLong { .. }));
    }

    #[test]
    fn zero_delay_allowed() {
        let t = TooltipProps {
            text: "x".into(),
            placement: TooltipPlacement::Top,
            delay_ms: 0,
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let t = TooltipProps {
            text: "x".into(),
            placement: TooltipPlacement::Bottom,
            delay_ms: 500,
        };
        let json = serde_json::to_string(&t).unwrap();
        let back: TooltipProps = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }
}
