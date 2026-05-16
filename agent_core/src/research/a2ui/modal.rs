//! Wave I Modal component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ModalSize {
    Small,
    Medium,
    Large,
    FullScreen,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ModalProps {
    pub title: String,
    pub body: String,
    pub size: ModalSize,
    pub dismissible: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ModalError {
    EmptyTitle,
    EmptyBody,
}

impl ModalProps {
    pub fn validate(&self) -> Result<(), ModalError> {
        if self.title.trim().is_empty() {
            return Err(ModalError::EmptyTitle);
        }
        if self.body.is_empty() {
            return Err(ModalError::EmptyBody);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_sizes() {
        let s: std::collections::HashSet<_> = [
            ModalSize::Small,
            ModalSize::Medium,
            ModalSize::Large,
            ModalSize::FullScreen,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn valid_passes() {
        let m = ModalProps {
            title: "T".into(),
            body: "B".into(),
            size: ModalSize::Medium,
            dismissible: true,
        };
        assert!(m.validate().is_ok());
    }

    #[test]
    fn empty_title_rejected() {
        let m = ModalProps {
            title: " ".into(),
            body: "B".into(),
            size: ModalSize::Small,
            dismissible: false,
        };
        assert_eq!(m.validate().unwrap_err(), ModalError::EmptyTitle);
    }

    #[test]
    fn empty_body_rejected() {
        let m = ModalProps {
            title: "T".into(),
            body: String::new(),
            size: ModalSize::Small,
            dismissible: false,
        };
        assert_eq!(m.validate().unwrap_err(), ModalError::EmptyBody);
    }

    #[test]
    fn serde_json_roundtrip() {
        let m = ModalProps {
            title: "T".into(),
            body: "B".into(),
            size: ModalSize::FullScreen,
            dismissible: false,
        };
        let json = serde_json::to_string(&m).unwrap();
        let back: ModalProps = serde_json::from_str(&json).unwrap();
        assert_eq!(m, back);
    }
}
