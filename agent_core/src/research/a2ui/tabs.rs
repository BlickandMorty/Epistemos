//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Tabs`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Tabs`].
//!
//! # Wave I — Tabs component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

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

impl TabsError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            TabsError::NoPanes => "no_panes",
            TabsError::DuplicateKey => "duplicate_key",
            TabsError::EmptyKey { .. } => "empty_key",
            TabsError::ActiveKeyNotFound => "active_key_not_found",
        }
    }

    /// Predicate: error pertains to the pane collection
    /// (NoPanes / DuplicateKey / EmptyKey).
    pub const fn is_pane_error(&self) -> bool {
        matches!(
            self,
            TabsError::NoPanes | TabsError::DuplicateKey | TabsError::EmptyKey { .. }
        )
    }

    /// Predicate: error pertains to the active_key reference.
    /// Cross-surface invariant: `is_pane_error XOR is_active_key_error`
    /// partitions all variants.
    pub const fn is_active_key_error(&self) -> bool {
        matches!(self, TabsError::ActiveKeyNotFound)
    }
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

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of panes.
    pub fn pane_count(&self) -> usize {
        self.panes.len()
    }

    /// Index of the active pane within `panes`, or `None` if the
    /// active_key doesn't match any pane. Cross-surface invariant:
    /// in a valid TabsProps, `active_index().is_some()`.
    pub fn active_index(&self) -> Option<usize> {
        self.panes.iter().position(|p| p.key == self.active_key)
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

    // ── diagnostic surface (iter 202) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            TabsError::NoPanes,
            TabsError::DuplicateKey,
            TabsError::EmptyKey { index: 0 },
            TabsError::ActiveKeyNotFound,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn error_classifiers_partition() {
        let variants = [
            TabsError::NoPanes,
            TabsError::DuplicateKey,
            TabsError::EmptyKey { index: 0 },
            TabsError::ActiveKeyNotFound,
        ];
        // Cross-surface invariant: is_pane_error XOR is_active_key_error.
        for e in variants {
            assert_ne!(e.is_pane_error(), e.is_active_key_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_pane_error()).count(), 3);
        assert_eq!(variants.iter().filter(|e| e.is_active_key_error()).count(), 1);
    }

    #[test]
    fn pane_count_matches_panes_len() {
        let t = TabsProps {
            panes: vec![pane("a", "A"), pane("b", "B"), pane("c", "C")],
            active_key: "a".into(),
        };
        assert_eq!(t.pane_count(), 3);
        assert_eq!(t.pane_count(), t.panes.len());
    }

    #[test]
    fn active_index_some_in_valid_tabs() {
        // Cross-surface invariant: valid TabsProps → active_index.is_some().
        let t = TabsProps {
            panes: vec![pane("a", "A"), pane("b", "B")],
            active_key: "b".into(),
        };
        assert!(t.is_valid());
        assert_eq!(t.active_index(), Some(1));
    }

    #[test]
    fn active_index_none_when_active_missing() {
        let t = TabsProps {
            panes: vec![pane("a", "A")],
            active_key: "z".into(),
        };
        assert_eq!(t.active_index(), None);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = TabsProps {
            panes: vec![pane("a", "A")],
            active_key: "a".into(),
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
