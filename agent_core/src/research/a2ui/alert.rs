//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Alert`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Alert`].
//!
//! # Wave I — Alert component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum AlertSeverity {
    Info,
    Success,
    Warning,
    Error,
}

impl AlertSeverity {
    pub const ALL: [AlertSeverity; 4] = [
        AlertSeverity::Info,
        AlertSeverity::Success,
        AlertSeverity::Warning,
        AlertSeverity::Error,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            AlertSeverity::Info => "info",
            AlertSeverity::Success => "success",
            AlertSeverity::Warning => "warning",
            AlertSeverity::Error => "error",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|s| s.code() == code)
    }

    /// Predicate: this severity indicates a problem the user should
    /// react to (Warning or Error). Cross-surface invariant:
    /// `is_problem XOR is_informational` partitions all variants.
    pub const fn is_problem(self) -> bool {
        matches!(self, AlertSeverity::Warning | AlertSeverity::Error)
    }

    /// Predicate: this severity is informational (Info or Success).
    pub const fn is_informational(self) -> bool {
        matches!(self, AlertSeverity::Info | AlertSeverity::Success)
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AlertAction {
    pub key: String,
    pub label: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AlertProps {
    pub severity: AlertSeverity,
    pub title: String,
    pub body: String,
    pub actions: Vec<AlertAction>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AlertError {
    EmptyTitle,
    DuplicateActionKey,
    EmptyActionKey { index: usize },
}

impl AlertError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            AlertError::EmptyTitle => "empty_title",
            AlertError::DuplicateActionKey => "duplicate_action_key",
            AlertError::EmptyActionKey { .. } => "empty_action_key",
        }
    }

    pub const fn is_title_error(&self) -> bool {
        matches!(self, AlertError::EmptyTitle)
    }

    pub const fn is_action_error(&self) -> bool {
        matches!(
            self,
            AlertError::DuplicateActionKey | AlertError::EmptyActionKey { .. }
        )
    }
}

impl AlertProps {
    pub fn validate(&self) -> Result<(), AlertError> {
        if self.title.trim().is_empty() {
            return Err(AlertError::EmptyTitle);
        }
        let mut seen: std::collections::HashSet<&str> = std::collections::HashSet::new();
        for (i, a) in self.actions.iter().enumerate() {
            if a.key.is_empty() {
                return Err(AlertError::EmptyActionKey { index: i });
            }
            if !seen.insert(&a.key) {
                return Err(AlertError::DuplicateActionKey);
            }
        }
        Ok(())
    }

    /// Predicate alias for `validate().is_ok()`. The "is this alert
    /// safe to render?" check without unwrapping the error reason.
    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of attached actions.
    pub fn action_count(&self) -> usize {
        self.actions.len()
    }

    /// Predicate: alert has zero actions — the user can only
    /// acknowledge / dismiss. Cross-surface invariant:
    /// `is_dismissible_only iff action_count == 0`.
    pub fn is_dismissible_only(&self) -> bool {
        self.actions.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn action(k: &str) -> AlertAction {
        AlertAction { key: k.into(), label: k.into() }
    }

    #[test]
    fn valid_passes() {
        let a = AlertProps {
            severity: AlertSeverity::Warning,
            title: "Heads up".into(),
            body: "body".into(),
            actions: vec![action("ok")],
        };
        assert!(a.validate().is_ok());
    }

    #[test]
    fn empty_title_rejected() {
        let a = AlertProps {
            severity: AlertSeverity::Info,
            title: "  ".into(),
            body: "x".into(),
            actions: vec![],
        };
        assert_eq!(a.validate().unwrap_err(), AlertError::EmptyTitle);
    }

    #[test]
    fn duplicate_action_key_rejected() {
        let a = AlertProps {
            severity: AlertSeverity::Info,
            title: "x".into(),
            body: "y".into(),
            actions: vec![action("k"), action("k")],
        };
        assert_eq!(a.validate().unwrap_err(), AlertError::DuplicateActionKey);
    }

    #[test]
    fn empty_action_key_rejected() {
        let a = AlertProps {
            severity: AlertSeverity::Info,
            title: "x".into(),
            body: "y".into(),
            actions: vec![action("")],
        };
        assert!(matches!(a.validate().unwrap_err(), AlertError::EmptyActionKey { .. }));
    }

    #[test]
    fn zero_actions_allowed() {
        let a = AlertProps {
            severity: AlertSeverity::Info,
            title: "x".into(),
            body: "y".into(),
            actions: vec![],
        };
        assert!(a.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let a = AlertProps {
            severity: AlertSeverity::Error,
            title: "x".into(),
            body: "y".into(),
            actions: vec![action("ok")],
        };
        let json = serde_json::to_string(&a).unwrap();
        let back: AlertProps = serde_json::from_str(&json).unwrap();
        assert_eq!(a, back);
    }

    // ── diagnostic surface (iter 197) ────────────────────────────────────────

    #[test]
    fn severity_from_code_roundtrips_all() {
        for s in AlertSeverity::ALL.iter().copied() {
            assert_eq!(AlertSeverity::from_code(s.code()), Some(s));
        }
        assert_eq!(AlertSeverity::from_code("Info"), None);
    }

    #[test]
    fn severity_problem_xor_informational_partition() {
        // Cross-surface invariant.
        for s in AlertSeverity::ALL.iter().copied() {
            assert_ne!(s.is_problem(), s.is_informational());
        }
        assert!(AlertSeverity::Warning.is_problem());
        assert!(AlertSeverity::Error.is_problem());
        assert!(AlertSeverity::Info.is_informational());
        assert!(AlertSeverity::Success.is_informational());
    }

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            AlertError::EmptyTitle,
            AlertError::DuplicateActionKey,
            AlertError::EmptyActionKey { index: 0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_title_error XOR is_action_error.
        for e in [
            AlertError::EmptyTitle,
            AlertError::DuplicateActionKey,
            AlertError::EmptyActionKey { index: 0 },
        ] {
            assert_ne!(e.is_title_error(), e.is_action_error());
        }
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        // Cross-surface invariant.
        let good = AlertProps {
            severity: AlertSeverity::Info,
            title: "x".into(),
            body: "y".into(),
            actions: vec![],
        };
        assert!(good.is_valid());
        assert_eq!(good.is_valid(), good.validate().is_ok());

        let bad = AlertProps {
            severity: AlertSeverity::Info,
            title: "".into(),
            body: "y".into(),
            actions: vec![],
        };
        assert!(!bad.is_valid());
        assert_eq!(bad.is_valid(), bad.validate().is_ok());
    }

    #[test]
    fn is_dismissible_only_aligned_with_action_count() {
        // Cross-surface invariant: is_dismissible_only iff action_count == 0.
        let a = AlertProps {
            severity: AlertSeverity::Info,
            title: "x".into(),
            body: "y".into(),
            actions: vec![],
        };
        assert!(a.is_dismissible_only());
        assert_eq!(a.action_count(), 0);

        let a = AlertProps {
            severity: AlertSeverity::Info,
            title: "x".into(),
            body: "y".into(),
            actions: vec![action("ok"), action("cancel")],
        };
        assert!(!a.is_dismissible_only());
        assert_eq!(a.action_count(), 2);
    }
}
