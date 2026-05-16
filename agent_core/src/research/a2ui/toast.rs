//! Wave I Toast component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ToastSeverity {
    Info,
    Success,
    Warning,
    Error,
}

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

impl ToastProps {
    pub fn validate(&self) -> Result<(), ToastError> {
        if self.message.trim().is_empty() {
            return Err(ToastError::EmptyMessage);
        }
        if let Some(ms) = self.auto_dismiss_ms {
            if ms < 500 {
                return Err(ToastError::DismissTooFast { ms });
            }
        }
        Ok(())
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
}
