//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `NavigationRail`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::NavigationRail`].
//!
//! # Wave I — NavigationRail component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NavigationRailItem {
    pub key: String,
    pub label: String,
    pub icon_name: String,
    pub badge_count: Option<u32>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NavigationRailProps {
    pub items: Vec<NavigationRailItem>,
    pub active_key: String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum NavigationRailError {
    NoItems,
    DuplicateKey,
    EmptyKey { index: usize },
    EmptyIcon { index: usize },
    ActiveNotFound,
    BadgeOverflow { index: usize, count: u32 },
}

impl NavigationRailProps {
    pub fn validate(&self) -> Result<(), NavigationRailError> {
        if self.items.is_empty() {
            return Err(NavigationRailError::NoItems);
        }
        let mut seen: std::collections::HashSet<&str> = std::collections::HashSet::new();
        for (i, it) in self.items.iter().enumerate() {
            if it.key.is_empty() {
                return Err(NavigationRailError::EmptyKey { index: i });
            }
            if !seen.insert(&it.key) {
                return Err(NavigationRailError::DuplicateKey);
            }
            if it.icon_name.is_empty() {
                return Err(NavigationRailError::EmptyIcon { index: i });
            }
            if let Some(c) = it.badge_count {
                if c > 999 {
                    return Err(NavigationRailError::BadgeOverflow { index: i, count: c });
                }
            }
        }
        if !self.items.iter().any(|i| i.key == self.active_key) {
            return Err(NavigationRailError::ActiveNotFound);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(k: &str, icon: &str, badge: Option<u32>) -> NavigationRailItem {
        NavigationRailItem {
            key: k.into(),
            label: k.into(),
            icon_name: icon.into(),
            badge_count: badge,
        }
    }

    #[test]
    fn no_items_rejected() {
        let n = NavigationRailProps { items: vec![], active_key: String::new() };
        assert_eq!(n.validate().unwrap_err(), NavigationRailError::NoItems);
    }

    #[test]
    fn valid_passes() {
        let n = NavigationRailProps {
            items: vec![item("home", "house", None), item("inbox", "tray", Some(3))],
            active_key: "home".into(),
        };
        assert!(n.validate().is_ok());
    }

    #[test]
    fn duplicate_key_rejected() {
        let n = NavigationRailProps {
            items: vec![item("home", "h", None), item("home", "h", None)],
            active_key: "home".into(),
        };
        assert_eq!(n.validate().unwrap_err(), NavigationRailError::DuplicateKey);
    }

    #[test]
    fn empty_key_rejected() {
        let n = NavigationRailProps {
            items: vec![item("", "h", None)],
            active_key: String::new(),
        };
        assert!(matches!(n.validate().unwrap_err(), NavigationRailError::EmptyKey { .. }));
    }

    #[test]
    fn empty_icon_rejected() {
        let n = NavigationRailProps {
            items: vec![item("home", "", None)],
            active_key: "home".into(),
        };
        assert!(matches!(n.validate().unwrap_err(), NavigationRailError::EmptyIcon { .. }));
    }

    #[test]
    fn active_not_found_rejected() {
        let n = NavigationRailProps {
            items: vec![item("home", "h", None)],
            active_key: "missing".into(),
        };
        assert_eq!(n.validate().unwrap_err(), NavigationRailError::ActiveNotFound);
    }

    #[test]
    fn badge_overflow_rejected() {
        let n = NavigationRailProps {
            items: vec![item("home", "h", Some(1000))],
            active_key: "home".into(),
        };
        assert!(matches!(n.validate().unwrap_err(), NavigationRailError::BadgeOverflow { .. }));
    }

    #[test]
    fn badge_at_cap_passes() {
        let n = NavigationRailProps {
            items: vec![item("home", "h", Some(999))],
            active_key: "home".into(),
        };
        assert!(n.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let n = NavigationRailProps {
            items: vec![item("home", "h", Some(1))],
            active_key: "home".into(),
        };
        let json = serde_json::to_string(&n).unwrap();
        let back: NavigationRailProps = serde_json::from_str(&json).unwrap();
        assert_eq!(n, back);
    }
}
