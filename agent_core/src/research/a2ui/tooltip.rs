//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Tooltip`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Tooltip`].
//!
//! # Wave I — Tooltip component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum TooltipPlacement {
    Top,
    Right,
    Bottom,
    Left,
}

impl TooltipPlacement {
    pub const ALL: [TooltipPlacement; 4] = [
        TooltipPlacement::Top,
        TooltipPlacement::Right,
        TooltipPlacement::Bottom,
        TooltipPlacement::Left,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            TooltipPlacement::Top => "top",
            TooltipPlacement::Right => "right",
            TooltipPlacement::Bottom => "bottom",
            TooltipPlacement::Left => "left",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }

    /// Predicate: vertical placement (Top or Bottom). Cross-surface
    /// invariant: `is_vertical XOR is_horizontal` partitions all 4.
    pub const fn is_vertical(self) -> bool {
        matches!(self, TooltipPlacement::Top | TooltipPlacement::Bottom)
    }

    /// Predicate: horizontal placement (Left or Right).
    pub const fn is_horizontal(self) -> bool {
        matches!(self, TooltipPlacement::Left | TooltipPlacement::Right)
    }

    /// Opposite placement (Top↔Bottom, Left↔Right). Useful when
    /// auto-flipping a tooltip that doesn't fit on its preferred side.
    pub const fn opposite(self) -> TooltipPlacement {
        match self {
            TooltipPlacement::Top => TooltipPlacement::Bottom,
            TooltipPlacement::Bottom => TooltipPlacement::Top,
            TooltipPlacement::Left => TooltipPlacement::Right,
            TooltipPlacement::Right => TooltipPlacement::Left,
        }
    }
}

/// Maximum tooltip delay in ms per the §5 substrate rule. Above
/// this the tooltip never appears for normal hover patterns.
pub const TOOLTIP_MAX_DELAY_MS: u32 = 5_000;

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

impl TooltipError {
    pub const fn cause(&self) -> &'static str {
        match self {
            TooltipError::EmptyText => "empty_text",
            TooltipError::DelayTooLong { .. } => "delay_too_long",
        }
    }
}

impl TooltipProps {
    pub fn validate(&self) -> Result<(), TooltipError> {
        if self.text.trim().is_empty() {
            return Err(TooltipError::EmptyText);
        }
        if self.delay_ms > TOOLTIP_MAX_DELAY_MS {
            return Err(TooltipError::DelayTooLong { ms: self.delay_ms });
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
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

    // ── diagnostic surface (iter 198) ────────────────────────────────────────

    #[test]
    fn placement_from_code_roundtrips_all() {
        for p in TooltipPlacement::ALL.iter().copied() {
            assert_eq!(TooltipPlacement::from_code(p.code()), Some(p));
        }
        assert_eq!(TooltipPlacement::from_code("Top"), None);
    }

    #[test]
    fn placement_vertical_xor_horizontal_partition() {
        // Cross-surface invariant.
        for p in TooltipPlacement::ALL.iter().copied() {
            assert_ne!(p.is_vertical(), p.is_horizontal());
        }
    }

    #[test]
    fn placement_opposite_involutive() {
        // Cross-surface invariant: opposite(opposite(p)) == p.
        for p in TooltipPlacement::ALL.iter().copied() {
            assert_eq!(p.opposite().opposite(), p);
        }
        assert_eq!(TooltipPlacement::Top.opposite(), TooltipPlacement::Bottom);
        assert_eq!(TooltipPlacement::Left.opposite(), TooltipPlacement::Right);
    }

    #[test]
    fn max_delay_pinned_at_5000() {
        assert_eq!(TOOLTIP_MAX_DELAY_MS, 5_000);
    }

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            TooltipError::EmptyText.cause(),
            TooltipError::DelayTooLong { ms: 6000 }.cause(),
        );
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = TooltipProps {
            text: "x".into(),
            placement: TooltipPlacement::Top,
            delay_ms: 500,
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
