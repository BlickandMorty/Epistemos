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
}
