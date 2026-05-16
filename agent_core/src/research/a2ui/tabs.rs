//! Wave I Tabs component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TabPane {
    pub key: String,
    pub label: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TabsProps {
    pub panes: Vec<TabPane>,
    pub active_key: String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TabsError {
    NoPanes,
    DuplicateKey,
    EmptyKey { index: usize },
    ActiveKeyNotFound,
}

impl TabsProps {
    pub fn validate(&self) -> Result<(), TabsError> {
        if self.panes.is_empty() {
            return Err(TabsError::NoPanes);
        }
        let mut seen: std::collections::HashSet<&str> = std::collections::HashSet::new();
        for (i, p) in self.panes.iter().enumerate() {
            if p.key.is_empty() {
                return Err(TabsError::EmptyKey { index: i });
            }
            if !seen.insert(&p.key) {
                return Err(TabsError::DuplicateKey);
            }
        }
        if !self.panes.iter().any(|p| p.key == self.active_key) {
            return Err(TabsError::ActiveKeyNotFound);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pane(k: &str, l: &str) -> TabPane {
        TabPane { key: k.into(), label: l.into() }
    }

    #[test]
    fn no_panes_rejected() {
        let t = TabsProps { panes: vec![], active_key: String::new() };
        assert_eq!(t.validate().unwrap_err(), TabsError::NoPanes);
    }

    #[test]
    fn valid_passes() {
        let t = TabsProps {
            panes: vec![pane("a", "A"), pane("b", "B")],
            active_key: "a".into(),
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn duplicate_key_rejected() {
        let t = TabsProps {
            panes: vec![pane("a", "A"), pane("a", "A2")],
            active_key: "a".into(),
        };
        assert_eq!(t.validate().unwrap_err(), TabsError::DuplicateKey);
    }

    #[test]
    fn empty_key_rejected() {
        let t = TabsProps {
            panes: vec![pane("", "X")],
            active_key: String::new(),
        };
        assert!(matches!(t.validate().unwrap_err(), TabsError::EmptyKey { .. }));
    }

    #[test]
    fn active_not_found_rejected() {
        let t = TabsProps {
            panes: vec![pane("a", "A")],
            active_key: "z".into(),
        };
        assert_eq!(t.validate().unwrap_err(), TabsError::ActiveKeyNotFound);
    }

    #[test]
    fn serde_json_roundtrip() {
        let t = TabsProps { panes: vec![pane("a", "A")], active_key: "a".into() };
        let json = serde_json::to_string(&t).unwrap();
        let back: TabsProps = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }
}
