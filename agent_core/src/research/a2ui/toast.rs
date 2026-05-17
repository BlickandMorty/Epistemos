//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Toast`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Toast`].
//!
//! # Wave I — Toast component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ToastSeverity {
    Info,
    Success,
    Warning,
    Error,
}

impl ToastSeverity {
    pub const ALL: [ToastSeverity; 4] = [
        ToastSeverity::Info,
        ToastSeverity::Success,
        ToastSeverity::Warning,
        ToastSeverity::Error,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            ToastSeverity::Info => "info",
            ToastSeverity::Success => "success",
            ToastSeverity::Warning => "warning",
            ToastSeverity::Error => "error",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|s| s.code() == code)
    }
}

/// Minimum auto-dismiss duration per the §5 substrate rule.
/// Toasts dismissing faster than 500ms violate accessibility (the
/// user can't read them).
pub const TOAST_MIN_DISMISS_MS: u32 = 500;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToastProps {
    pub severity: ToastSeverity,
    pub message: String,
    pub auto_dismiss_ms: Option<u32>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ToastError {
    EmptyMessage,
    DismissTooFast { ms: u32 },
}

impl ToastError {
    pub const fn cause(&self) -> &'static str {
        match self {
            ToastError::EmptyMessage => "empty_message",
            ToastError::DismissTooFast { .. } => "dismiss_too_fast",
        }
    }
}

impl ToastProps {
    pub fn validate(&self) -> Result<(), ToastError> {
        if self.message.trim().is_empty() {
            return Err(ToastError::EmptyMessage);
        }
        if let Some(ms) = self.auto_dismiss_ms {
            if ms < TOAST_MIN_DISMISS_MS {
                return Err(ToastError::DismissTooFast { ms });
            }
        }
        Ok(())
    }

    /// Predicate alias for `validate().is_ok()`.
    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Predicate: toast persists until manually dismissed (no auto-
    /// dismiss timer). Cross-surface invariant: `is_persistent iff
    /// auto_dismiss_ms.is_none()`.
    pub const fn is_persistent(&self) -> bool {
        self.auto_dismiss_ms.is_none()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_severities() {
        let s: std::collections::HashSet<_> = [
            ToastSeverity::Info,
            ToastSeverity::Success,
            ToastSeverity::Warning,
            ToastSeverity::Error,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn empty_message_rejected() {
        let t = ToastProps {
            severity: ToastSeverity::Info,
            message: "   ".into(),
            auto_dismiss_ms: None,
        };
        assert_eq!(t.validate().unwrap_err(), ToastError::EmptyMessage);
    }

    #[test]
    fn valid_passes() {
        let t = ToastProps {
            severity: ToastSeverity::Success,
            message: "saved".into(),
            auto_dismiss_ms: Some(3000),
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn dismiss_too_fast_rejected() {
        let t = ToastProps {
            severity: ToastSeverity::Info,
            message: "x".into(),
            auto_dismiss_ms: Some(100),
        };
        assert!(matches!(t.validate().unwrap_err(), ToastError::DismissTooFast { .. }));
    }

    #[test]
    fn dismiss_at_floor_passes() {
        let t = ToastProps {
            severity: ToastSeverity::Info,
            message: "x".into(),
            auto_dismiss_ms: Some(500),
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let t = ToastProps {
            severity: ToastSeverity::Error,
            message: "boom".into(),
            auto_dismiss_ms: None,
        };
        let json = serde_json::to_string(&t).unwrap();
        let back: ToastProps = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }

    // ── diagnostic surface (iter 198) ────────────────────────────────────────

    #[test]
    fn severity_from_code_roundtrips_all() {
        for s in ToastSeverity::ALL.iter().copied() {
            assert_eq!(ToastSeverity::from_code(s.code()), Some(s));
        }
        assert_eq!(ToastSeverity::from_code("Info"), None);
    }

    #[test]
    fn min_dismiss_pinned_at_500() {
        assert_eq!(TOAST_MIN_DISMISS_MS, 500);
    }

    #[test]
    fn error_cause_distinct() {
        let variants = [
            ToastError::EmptyMessage,
            ToastError::DismissTooFast { ms: 100 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 2);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = ToastProps {
            severity: ToastSeverity::Info,
            message: "x".into(),
            auto_dismiss_ms: None,
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }

    #[test]
    fn is_persistent_aligned_with_none_dismiss() {
        // Cross-surface invariant: is_persistent iff auto_dismiss_ms.is_none().
        let persistent = ToastProps {
            severity: ToastSeverity::Info,
            message: "x".into(),
            auto_dismiss_ms: None,
        };
        assert!(persistent.is_persistent());

        let ephemeral = ToastProps {
            severity: ToastSeverity::Info,
            message: "x".into(),
            auto_dismiss_ms: Some(2000),
        };
        assert!(!ephemeral.is_persistent());
    }
}
