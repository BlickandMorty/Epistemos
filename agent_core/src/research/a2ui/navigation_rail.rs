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

impl NavigationRailError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            NavigationRailError::NoItems => "no_items",
            NavigationRailError::DuplicateKey => "duplicate_key",
            NavigationRailError::EmptyKey { .. } => "empty_key",
            NavigationRailError::EmptyIcon { .. } => "empty_icon",
            NavigationRailError::ActiveNotFound => "active_not_found",
            NavigationRailError::BadgeOverflow { .. } => "badge_overflow",
        }
    }

    /// Predicate: error pertains to the item collection
    /// (NoItems / DuplicateKey / EmptyKey / EmptyIcon).
    pub const fn is_item_error(&self) -> bool {
        matches!(
            self,
            NavigationRailError::NoItems
                | NavigationRailError::DuplicateKey
                | NavigationRailError::EmptyKey { .. }
                | NavigationRailError::EmptyIcon { .. }
        )
    }

    /// Predicate: error pertains to the badge count
    /// (BadgeOverflow).
    pub const fn is_badge_error(&self) -> bool {
        matches!(self, NavigationRailError::BadgeOverflow { .. })
    }

    /// Predicate: error pertains to the active_key reference
    /// (ActiveNotFound). Cross-surface invariant: exactly one of
    /// `is_item_error / is_badge_error / is_active_error` is true
    /// per variant (3-way partition).
    pub const fn is_active_error(&self) -> bool {
        matches!(self, NavigationRailError::ActiveNotFound)
    }
}

/// Maximum displayed badge count per §5 doctrine. Counts above
/// this typically render as "999+" in the UI; the substrate
/// rejects them so the Swift layer's badge format never has to
/// truncate.
pub const NAV_RAIL_MAX_BADGE: u32 = 999;

impl NavigationRailItem {
    /// Predicate: this item has a non-None badge_count.
    pub const fn has_badge(&self) -> bool {
        self.badge_count.is_some()
    }
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
                if c > NAV_RAIL_MAX_BADGE {
                    return Err(NavigationRailError::BadgeOverflow { index: i, count: c });
                }
            }
        }
        if !self.items.iter().any(|i| i.key == self.active_key) {
            return Err(NavigationRailError::ActiveNotFound);
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Index of the active item, or `None` if active_key doesn't
    /// match. Cross-surface invariant: valid NavigationRailProps →
    /// `active_index().is_some()`.
    pub fn active_index(&self) -> Option<usize> {
        self.items.iter().position(|i| i.key == self.active_key)
    }

    /// Number of items with a badge attached.
    pub fn badge_count(&self) -> usize {
        self.items.iter().filter(|it| it.has_badge()).count()
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

    // ── diagnostic surface (iter 203) ────────────────────────────────────────

    #[test]
    fn max_badge_pinned_at_999() {
        assert_eq!(NAV_RAIL_MAX_BADGE, 999);
    }

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            NavigationRailError::NoItems,
            NavigationRailError::DuplicateKey,
            NavigationRailError::EmptyKey { index: 0 },
            NavigationRailError::EmptyIcon { index: 0 },
            NavigationRailError::ActiveNotFound,
            NavigationRailError::BadgeOverflow { index: 0, count: 1000 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 6);
    }

    #[test]
    fn error_3way_classifier_partition() {
        let variants = [
            NavigationRailError::NoItems,
            NavigationRailError::DuplicateKey,
            NavigationRailError::EmptyKey { index: 0 },
            NavigationRailError::EmptyIcon { index: 0 },
            NavigationRailError::ActiveNotFound,
            NavigationRailError::BadgeOverflow { index: 0, count: 1000 },
        ];
        // Cross-surface invariant: exactly one of is_item_error /
        // is_badge_error / is_active_error per variant.
        for e in variants {
            let trio = [e.is_item_error(), e.is_badge_error(), e.is_active_error()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
        assert_eq!(variants.iter().filter(|e| e.is_item_error()).count(), 4);
        assert_eq!(variants.iter().filter(|e| e.is_badge_error()).count(), 1);
        assert_eq!(variants.iter().filter(|e| e.is_active_error()).count(), 1);
    }

    #[test]
    fn item_has_badge_aligned_with_option() {
        let with_badge = item("a", "h", Some(5));
        let no_badge = item("b", "h", None);
        assert!(with_badge.has_badge());
        assert!(!no_badge.has_badge());
    }

    #[test]
    fn active_index_some_in_valid_props() {
        // Cross-surface invariant: valid → active_index Some.
        let n = NavigationRailProps {
            items: vec![item("home", "h", None), item("inbox", "i", None)],
            active_key: "inbox".into(),
        };
        assert!(n.is_valid());
        assert_eq!(n.active_index(), Some(1));
    }

    #[test]
    fn badge_count_matches_items_with_badge() {
        let n = NavigationRailProps {
            items: vec![
                item("a", "h", Some(1)),
                item("b", "h", None),
                item("c", "h", Some(5)),
            ],
            active_key: "a".into(),
        };
        assert_eq!(n.badge_count(), 2);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = NavigationRailProps {
            items: vec![item("home", "h", None)],
            active_key: "home".into(),
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
